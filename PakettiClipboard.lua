-- PakettiClipboard.lua
-- Multi-slot clipboard system for Renoise with Cut, Copy, Paste, Flood Fill operations
-- Supports both Pattern Editor and Phrase Editor

local vb = renoise.ViewBuilder()
local clipboard_dialog = nil

-- Number of clipboard slots
local NUM_CLIPBOARD_SLOTS = 10

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

-- Detect which editor is currently active
local function get_active_editor()
  if renoise.app().window.active_middle_frame == 
     renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
    return "phrase"
  else
    return "pattern"
  end
end

-- Helper function to format slot index with leading zero
local function format_slot_index(index)
  return string.format("%02d", index)
end

-- Helper function to copy note column data
local function copy_note_column_data(note_column)
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

-- Helper function to write note column data
local function write_note_column_data(note_column, data)
  note_column.note_value = data.note_value
  note_column.instrument_value = data.instrument_value
  note_column.volume_value = data.volume_value
  note_column.panning_value = data.panning_value
  note_column.delay_value = data.delay_value
  note_column.effect_number_value = data.effect_number_value
  note_column.effect_amount_value = data.effect_amount_value
end

-- Helper function to copy effect column data
local function copy_effect_column_data(effect_column)
  return {
    number_value = effect_column.number_value,
    amount_value = effect_column.amount_value
  }
end

-- Helper function to write effect column data
local function write_effect_column_data(effect_column, data)
  effect_column.number_value = data.number_value
  effect_column.amount_value = data.amount_value
end

-- Helper function to clear a note column (set to empty, not OFF)
local function clear_note_column_to_empty(note_column)
  -- Use string setters to ensure proper empty state (not OFF)
  note_column.note_string = "---"  -- Empty note, not "OFF"
  note_column.instrument_string = ".."  -- Empty instrument
  note_column.volume_string = ".."  -- Empty volume
  note_column.panning_string = ".."  -- Empty panning
  note_column.delay_string = "00"  -- Zero delay
  note_column.effect_number_string = "00"  -- No sample effect
  note_column.effect_amount_string = "00"  -- No amount
end

-- Helper function to clear an effect column
local function clear_effect_column_to_empty(effect_column)
  effect_column.number_value = 0
  effect_column.amount_value = 0
end

-- Serialize clipboard data to string for preferences storage
local function serialize_clipboard_data(data)
  if not data or not data.rows or #data.rows == 0 then
    return ""
  end
  
  local lines = {}
  
  -- Header: source_type|num_rows|num_tracks
  table.insert(lines, string.format("%s|%d|%d", 
    data.source_type or "pattern", 
    data.num_rows or 0, 
    data.num_tracks or 1))
  
  -- Track info: track_idx:num_note_cols:num_effect_cols
  for track_idx, track_data in pairs(data.track_info or {}) do
    table.insert(lines, string.format("T%d:%d:%d", 
      track_idx, 
      track_data.num_note_columns or 0, 
      track_data.num_effect_columns or 0))
  end
  
  -- Row data separator
  table.insert(lines, "---")
  
  -- Row data: row_idx@track_idx:col_type:col_idx=data
  for row_idx, row_data in ipairs(data.rows) do
    for track_idx, track_data in pairs(row_data) do
      -- Note columns
      if track_data.note_columns then
        for col_idx, col_data in pairs(track_data.note_columns) do
          table.insert(lines, string.format("R%d@T%d:N%d=%d,%d,%d,%d,%d,%d,%d",
            row_idx, track_idx, col_idx,
            col_data.note_value or 121,
            col_data.instrument_value or 255,
            col_data.volume_value or 255,
            col_data.panning_value or 255,
            col_data.delay_value or 0,
            col_data.effect_number_value or 0,
            col_data.effect_amount_value or 0))
        end
      end
      -- Effect columns
      if track_data.effect_columns then
        for col_idx, col_data in pairs(track_data.effect_columns) do
          table.insert(lines, string.format("R%d@T%d:E%d=%d,%d",
            row_idx, track_idx, col_idx,
            col_data.number_value or 0,
            col_data.amount_value or 0))
        end
      end
    end
  end
  
  return table.concat(lines, "\n")
end

-- Deserialize clipboard data from string
local function deserialize_clipboard_data(str)
  if not str or str == "" then
    return nil
  end
  
  local data = {
    source_type = "pattern",
    num_rows = 0,
    num_tracks = 1,
    track_info = {},
    rows = {}
  }
  
  local in_rows = false
  
  for line in str:gmatch("[^\n]+") do
    if line == "---" then
      in_rows = true
    elseif not in_rows then
      -- Parse header
      local source_type, num_rows, num_tracks = line:match("^(%w+)|(%d+)|(%d+)$")
      if source_type then
        data.source_type = source_type
        data.num_rows = tonumber(num_rows)
        data.num_tracks = tonumber(num_tracks)
      else
        -- Parse track info
        local track_idx, num_note_cols, num_effect_cols = line:match("^T(%d+):(%d+):(%d+)$")
        if track_idx then
          data.track_info[tonumber(track_idx)] = {
            num_note_columns = tonumber(num_note_cols),
            num_effect_columns = tonumber(num_effect_cols)
          }
        end
      end
    else
      -- Parse row data
      local row_idx, track_idx, col_type, col_idx, values = 
        line:match("^R(%d+)@T(%d+):([NE])(%d+)=(.+)$")
      
      if row_idx then
        row_idx = tonumber(row_idx)
        track_idx = tonumber(track_idx)
        col_idx = tonumber(col_idx)
        
        -- Ensure row exists
        if not data.rows[row_idx] then
          data.rows[row_idx] = {}
        end
        if not data.rows[row_idx][track_idx] then
          data.rows[row_idx][track_idx] = {
            note_columns = {},
            effect_columns = {}
          }
        end
        
        if col_type == "N" then
          -- Note column
          local v1, v2, v3, v4, v5, v6, v7 = values:match("(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)")
          if v1 then
            data.rows[row_idx][track_idx].note_columns[col_idx] = {
              note_value = tonumber(v1),
              instrument_value = tonumber(v2),
              volume_value = tonumber(v3),
              panning_value = tonumber(v4),
              delay_value = tonumber(v5),
              effect_number_value = tonumber(v6),
              effect_amount_value = tonumber(v7)
            }
          end
        else
          -- Effect column
          local v1, v2 = values:match("(%d+),(%d+)")
          if v1 then
            data.rows[row_idx][track_idx].effect_columns[col_idx] = {
              number_value = tonumber(v1),
              amount_value = tonumber(v2)
            }
          end
        end
      end
    end
  end
  
  return data
end

-- Save clipboard slot to preferences
local function save_clipboard_to_preferences(slot_index, data)
  local slot_key = "Slot" .. format_slot_index(slot_index)
  local serialized = serialize_clipboard_data(data)
  preferences.PakettiClipboard[slot_key].value = serialized
  renoise.tool().preferences:save_as("preferences.xml")
end

-- Load clipboard slot from preferences
local function load_clipboard_from_preferences(slot_index)
  local slot_key = "Slot" .. format_slot_index(slot_index)
  local serialized = preferences.PakettiClipboard[slot_key].value
  return deserialize_clipboard_data(serialized)
end

-- Clear a clipboard slot
local function clear_clipboard_slot(slot_index)
  local slot_key = "Slot" .. format_slot_index(slot_index)
  preferences.PakettiClipboard[slot_key].value = ""
  renoise.tool().preferences:save_as("preferences.xml")
  renoise.app():show_status("Cleared Clipboard Slot " .. format_slot_index(slot_index))
end

-- Get slot name from preferences
local function get_slot_name(slot_index)
  local name_key = "Slot" .. format_slot_index(slot_index) .. "Name"
  if preferences.PakettiClipboard[name_key] then
    return preferences.PakettiClipboard[name_key].value or ""
  end
  return ""
end

-- Set slot name in preferences
local function set_slot_name(slot_index, name)
  local name_key = "Slot" .. format_slot_index(slot_index) .. "Name"
  if preferences.PakettiClipboard[name_key] then
    preferences.PakettiClipboard[name_key].value = name
    renoise.tool().preferences:save_as("preferences.xml")
  end
end

-- Public function to rename a slot
function PakettiClipboardRenameSlot(slot_index, name)
  set_slot_name(slot_index, name)
  renoise.app():show_status("Renamed Clipboard Slot " .. format_slot_index(slot_index) .. " to: " .. name)
end

--------------------------------------------------------------------------------
-- Pattern Editor Clipboard Operations
--------------------------------------------------------------------------------

-- Copy selection from Pattern Editor to clipboard
-- Uses selection_in_pattern_pro() for precise column selection
local function copy_pattern_selection(slot_index, clear_after_copy)
  local song = renoise.song()
  local selection = song.selection_in_pattern
  
  if not selection then
    renoise.app():show_status("No selection in pattern to copy.")
    return false
  end
  
  -- Use selection_in_pattern_pro() for precise column handling
  local selection_pro = selection_in_pattern_pro()
  if not selection_pro then
    renoise.app():show_status("No selection in pattern to copy.")
    return false
  end
  
  local pattern = song.selected_pattern
  local data = {
    source_type = "pattern",
    num_rows = selection.end_line - selection.start_line + 1,
    num_tracks = #selection_pro,
    track_info = {},
    rows = {}
  }
  
  -- Capture track info and data using selection_in_pattern_pro
  for relative_track_idx, track_info in ipairs(selection_pro) do
    local track_idx = track_info.track_index
    local track = song.tracks[track_idx]
    
    -- Store track column counts
    data.track_info[relative_track_idx] = {
      num_note_columns = #track_info.note_columns,
      num_effect_columns = #track_info.effect_columns
    }
    
    -- Capture row data
    for line_idx = selection.start_line, selection.end_line do
      local relative_row_idx = line_idx - selection.start_line + 1
      local pattern_line = pattern.tracks[track_idx].lines[line_idx]
      
      if not data.rows[relative_row_idx] then
        data.rows[relative_row_idx] = {}
      end
      
      data.rows[relative_row_idx][relative_track_idx] = {
        note_columns = {},
        effect_columns = {}
      }
      
      -- Copy note columns (only those in selection via selection_in_pattern_pro)
      for _, col_idx in ipairs(track_info.note_columns) do
        if col_idx <= #pattern_line.note_columns then
          local note_column = pattern_line.note_columns[col_idx]
          data.rows[relative_row_idx][relative_track_idx].note_columns[col_idx] = 
            copy_note_column_data(note_column)
          
          -- Clear after copy if cutting (use explicit empty, not clear() which may set OFF)
          if clear_after_copy then
            clear_note_column_to_empty(note_column)
          end
        end
      end
      
      -- Copy effect columns (only those in selection via selection_in_pattern_pro)
      for _, col_idx in ipairs(track_info.effect_columns) do
        if col_idx <= #pattern_line.effect_columns then
          local effect_column = pattern_line.effect_columns[col_idx]
          data.rows[relative_row_idx][relative_track_idx].effect_columns[col_idx] = 
            copy_effect_column_data(effect_column)
          
          -- Clear after copy if cutting
          if clear_after_copy then
            clear_effect_column_to_empty(effect_column)
          end
        end
      end
    end
  end
  
  -- Save to preferences
  save_clipboard_to_preferences(slot_index, data)
  
  local action = clear_after_copy and "Cut" or "Copied"
  renoise.app():show_status(string.format("%s %d rows to Clipboard Slot %s", 
    action, data.num_rows, format_slot_index(slot_index)))
  
  return true
end

-- Paste from clipboard to Pattern Editor at cursor position
-- Handles cross-editor paste: if data came from phrase, pastes to current track only
-- Pastes starting from current cursor position (line and column)
-- If there's a selection, uses selection_in_pattern_pro() for precise column targeting
local function paste_pattern_from_clipboard(slot_index)
  local song = renoise.song()
  local data = load_clipboard_from_preferences(slot_index)
  
  if not data or not data.rows or #data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty. Copy something first.")
    return false
  end
  
  local pattern = song.selected_pattern
  local selection = song.selection_in_pattern
  local pattern_length = pattern.number_of_lines
  local is_cross_editor = (data.source_type == "phrase")
  local rows_pasted = 0
  
  -- If there's a selection, use selection_in_pattern_pro for precise paste
  if selection then
    local selection_pro = selection_in_pattern_pro()
    if selection_pro then
      local clipboard_rows = #data.rows
      
      -- For each track in selection, determine if we need to squeeze
      -- Count max note columns in clipboard data
      local clipboard_max_note_col = 0
      for _, row_data in ipairs(data.rows) do
        for _, track_data in pairs(row_data) do
          if track_data.note_columns then
            for col_idx, _ in pairs(track_data.note_columns) do
              if col_idx > clipboard_max_note_col then
                clipboard_max_note_col = col_idx
              end
            end
          end
        end
      end
      
      -- Paste into selection (cycling clipboard if needed)
      for line_idx = selection.start_line, selection.end_line do
        if line_idx > pattern_length then break end
        
        local source_row_idx = ((line_idx - selection.start_line) % clipboard_rows) + 1
        local row_data = data.rows[source_row_idx]
        
        if row_data then
          for track_offset, track_info in ipairs(selection_pro) do
            local track_idx = track_info.track_index
            if track_idx > #song.tracks then break end
            
            local track = song.tracks[track_idx]
            if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
              local pattern_line = pattern.tracks[track_idx].lines[line_idx]
              
              -- Get source track data (cycle if clipboard has fewer tracks)
              local source_track_idx = ((track_offset - 1) % data.num_tracks) + 1
              local track_data = row_data[source_track_idx]
              
              if track_data then
                -- Use the SELECTION's column count for squeeze (respect user's selection)
                local selection_col_count = #track_info.note_columns
                
                -- Check if we need to squeeze (clipboard has more columns than selection)
                if clipboard_max_note_col > selection_col_count and selection_col_count > 0 then
                  -- SQUEEZE MODE: Remap clipboard columns to selection columns
                  -- Column 1 -> sel col 1, Column 2 -> sel col 2, Column 3 -> sel col 1 (wrap), etc.
                  -- ONLY write columns that have actual content (not empty)
                  if track_data.note_columns then
                    for col_idx, col_data in pairs(track_data.note_columns) do
                      -- Check if this column has any content (note, instrument, volume, etc)
                      local has_content = false
                      if col_data.note_value and col_data.note_value >= 0 and col_data.note_value <= 120 then
                        has_content = true  -- Has a note or OFF
                      elseif col_data.instrument_value and col_data.instrument_value ~= 255 then
                        has_content = true  -- Has instrument
                      elseif col_data.volume_value and col_data.volume_value ~= 255 then
                        has_content = true  -- Has volume
                      elseif col_data.panning_value and col_data.panning_value ~= 255 then
                        has_content = true  -- Has panning
                      elseif col_data.delay_value and col_data.delay_value ~= 0 then
                        has_content = true  -- Has delay
                      elseif col_data.effect_number_value and col_data.effect_number_value ~= 0 then
                        has_content = true  -- Has effect
                      end
                      
                      -- Only write if this column has actual content
                      if has_content then
                        -- Remap the clipboard column to a selection column using modulo
                        local sel_col_idx = ((col_idx - 1) % selection_col_count) + 1
                        local dest_col = track_info.note_columns[sel_col_idx]
                        
                        -- DEBUG: Show what's happening
                        local note_name = "data"
                        if col_data.note_value and col_data.note_value >= 0 and col_data.note_value <= 119 then
                          local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
                          local octave = math.floor(col_data.note_value / 12)
                          local note = (col_data.note_value % 12) + 1
                          note_name = note_names[note] .. octave
                        elseif col_data.note_value == 120 then
                          note_name = "OFF"
                        end
                        print(string.format("SQUEEZE Row %d Track %d: clipboard col %d (%s) -> sel_col_idx %d -> dest_col %d (sel_cols={%s})",
                          line_idx, track_idx, col_idx, note_name, sel_col_idx, dest_col or -1, 
                          table.concat(track_info.note_columns, ",")))
                        
                        if dest_col and dest_col <= #pattern_line.note_columns then
                          write_note_column_data(pattern_line.note_columns[dest_col], col_data)
                        end
                      end
                    end
                  end
                  
                  -- Also handle effect columns (no remapping, just direct paste to selected)
                  if track_data.effect_columns then
                    for col_idx, col_data in pairs(track_data.effect_columns) do
                      -- Check if this effect column is in selection
                      for _, sel_fx_col in ipairs(track_info.effect_columns) do
                        if col_idx == sel_fx_col and col_idx <= #pattern_line.effect_columns then
                          write_effect_column_data(pattern_line.effect_columns[col_idx], col_data)
                          break
                        end
                      end
                    end
                  end
                else
                  -- NORMAL MODE: Paste note columns directly (only those in selection)
                  if track_data.note_columns then
                    for _, col_idx in ipairs(track_info.note_columns) do
                      if col_idx <= #pattern_line.note_columns then
                        local col_data = track_data.note_columns[col_idx]
                        if col_data then
                          write_note_column_data(pattern_line.note_columns[col_idx], col_data)
                        end
                      end
                    end
                  end
                end
                
                -- Paste effect columns (only those in selection - no squeeze for effects)
                if track_data.effect_columns then
                  for _, col_idx in ipairs(track_info.effect_columns) do
                    if col_idx <= #pattern_line.effect_columns then
                      local col_data = track_data.effect_columns[col_idx]
                      if col_data then
                        write_effect_column_data(pattern_line.effect_columns[col_idx], col_data)
                      end
                    end
                  end
                end
              end
            end
          end
          rows_pasted = rows_pasted + 1
        end
      end
      
      local squeeze_msg = ""
      if clipboard_max_note_col > 0 then
        -- Check if any track needed squeezing (had fewer selected cols than clipboard)
        local min_selected_cols = 999
        for _, ti in ipairs(selection_pro) do
          local sel_cols = #ti.note_columns
          if sel_cols > 0 and sel_cols < min_selected_cols then
            min_selected_cols = sel_cols
          end
        end
        if min_selected_cols < 999 and clipboard_max_note_col > min_selected_cols then
          squeeze_msg = string.format(" (remapped %d cols to %d)", clipboard_max_note_col, min_selected_cols)
        end
      end
      
      renoise.app():show_status(string.format("Pasted %d rows into selection from Slot %s%s", 
        rows_pasted, format_slot_index(slot_index), squeeze_msg))
      return true
    end
  end
  
  -- No selection - paste at cursor position
  local start_line = song.selected_line_index
  local start_track = song.selected_track_index
  local start_note_column = song.selected_note_column_index or 1
  
  -- Check if target track is a sequencer track
  local target_track = song.tracks[start_track]
  if target_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Cannot paste to non-sequencer track (Send/Master/Group). Select a sequencer track.")
    return false
  end
  
  -- Find the min/max column indices in the clipboard data
  local min_clipboard_col = 999
  local max_clipboard_col = 0
  local max_clipboard_fx_col = 0
  for _, row_data in ipairs(data.rows) do
    for _, track_data in pairs(row_data) do
      if track_data.note_columns then
        for col_idx, _ in pairs(track_data.note_columns) do
          if col_idx < min_clipboard_col then
            min_clipboard_col = col_idx
          end
          if col_idx > max_clipboard_col then
            max_clipboard_col = col_idx
          end
        end
      end
      if track_data.effect_columns then
        for col_idx, _ in pairs(track_data.effect_columns) do
          if col_idx > max_clipboard_fx_col then
            max_clipboard_fx_col = col_idx
          end
        end
      end
    end
  end
  if min_clipboard_col == 999 then min_clipboard_col = 1 end
  
  -- Calculate column offset (paste starting from cursor column)
  local col_offset = start_note_column - min_clipboard_col
  
  -- Calculate required visible columns after applying offset
  local required_note_cols = max_clipboard_col + col_offset
  local required_fx_cols = max_clipboard_fx_col
  
  -- Expand visible columns on target tracks if needed (before pasting)
  for relative_track_idx = 1, data.num_tracks do
    local target_track_idx = start_track + relative_track_idx - 1
    if target_track_idx <= #song.tracks then
      local track = song.tracks[target_track_idx]
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        -- Expand note columns if needed (max 12)
        if required_note_cols > track.visible_note_columns then
          track.visible_note_columns = math.min(required_note_cols, 12)
        end
        -- Expand effect columns if needed (max 8)
        if required_fx_cols > track.visible_effect_columns then
          track.visible_effect_columns = math.min(required_fx_cols, 8)
        end
      end
    end
  end
  
  -- Paste data
  for row_idx, row_data in ipairs(data.rows) do
    local target_line = start_line + row_idx - 1
    if target_line > pattern_length then
      break
    end
    
    for relative_track_idx, track_data in pairs(row_data) do
      local target_track_idx = start_track + relative_track_idx - 1
      if target_track_idx > #song.tracks then
        break
      end
      
      local track = song.tracks[target_track_idx]
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local pattern_line = pattern.tracks[target_track_idx].lines[target_line]
        
        -- Paste note columns (with offset to start at cursor column)
        if track_data.note_columns then
          for col_idx, col_data in pairs(track_data.note_columns) do
            local target_col = col_idx + col_offset
            if target_col >= 1 and target_col <= track.visible_note_columns then
              write_note_column_data(pattern_line.note_columns[target_col], col_data)
            end
          end
        end
        
        -- Paste effect columns
        if track_data.effect_columns then
          for col_idx, col_data in pairs(track_data.effect_columns) do
            if col_idx <= track.visible_effect_columns then
              write_effect_column_data(pattern_line.effect_columns[col_idx], col_data)
            end
          end
        end
      end
    end
    
    rows_pasted = rows_pasted + 1
  end
  
  if rows_pasted == 0 then
    renoise.app():show_status("Paste failed - no data could be pasted to current position.")
    return false
  end
  
  -- Show appropriate status message
  if is_cross_editor then
    renoise.app():show_status(string.format("Pasted %d rows from Phrase to Pattern (Slot %s)", 
      rows_pasted, format_slot_index(slot_index)))
  else
    renoise.app():show_status(string.format("Pasted %d rows from Clipboard Slot %s", 
      rows_pasted, format_slot_index(slot_index)))
  end
  
  return true
end

-- Mix-Paste from clipboard to Pattern Editor (only paste into empty cells)
-- Uses selection_in_pattern_pro() for precise column selection
local function mix_paste_pattern_from_clipboard(slot_index)
  local song = renoise.song()
  local selection = song.selection_in_pattern
  
  if not selection then
    renoise.app():show_status("Mix-Paste needs a selection. Select rows first, then mix-paste.")
    return false
  end
  
  local data = load_clipboard_from_preferences(slot_index)
  
  if not data or not data.rows or #data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty. Copy something first.")
    return false
  end
  
  -- Use selection_in_pattern_pro() for precise column handling
  local selection_pro = selection_in_pattern_pro()
  if not selection_pro then
    renoise.app():show_status("Mix-Paste: No valid selection")
    return false
  end
  
  local pattern = song.selected_pattern
  local clipboard_rows = #data.rows
  local cells_pasted = 0
  local cells_skipped = 0
  
  -- Mix-paste into selection (cycling clipboard if needed)
  for line_idx = selection.start_line, selection.end_line do
    if line_idx > pattern.number_of_lines then break end
    
    local source_row_idx = ((line_idx - selection.start_line) % clipboard_rows) + 1
    local row_data = data.rows[source_row_idx]
    
    if row_data then
      for track_offset, track_info in ipairs(selection_pro) do
        local track_idx = track_info.track_index
        if track_idx > #song.tracks then break end
        
        local track = song.tracks[track_idx]
        if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          local pattern_line = pattern.tracks[track_idx].lines[line_idx]
          
          -- Get source track data (cycle if clipboard has fewer tracks)
          local source_track_idx = ((track_offset - 1) % data.num_tracks) + 1
          local track_data = row_data[source_track_idx]
          
          if track_data then
            -- Mix-paste note columns (only those in selection via selection_in_pattern_pro)
            if track_data.note_columns then
              for _, col_idx in ipairs(track_info.note_columns) do
                if col_idx <= #pattern_line.note_columns then
                  local note_col = pattern_line.note_columns[col_idx]
                  local col_data = track_data.note_columns[col_idx]
                  
                  if col_data then
                    -- Only paste into empty cells
                    if note_col.is_empty then
                      write_note_column_data(note_col, col_data)
                      cells_pasted = cells_pasted + 1
                    else
                      cells_skipped = cells_skipped + 1
                    end
                  end
                end
              end
            end
            
            -- Mix-paste effect columns (only those in selection)
            if track_data.effect_columns then
              for _, col_idx in ipairs(track_info.effect_columns) do
                if col_idx <= #pattern_line.effect_columns then
                  local fx_col = pattern_line.effect_columns[col_idx]
                  local col_data = track_data.effect_columns[col_idx]
                  
                  if col_data then
                    -- Only paste into empty cells
                    if fx_col.is_empty then
                      write_effect_column_data(fx_col, col_data)
                      cells_pasted = cells_pasted + 1
                    else
                      cells_skipped = cells_skipped + 1
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  
  renoise.app():show_status(string.format("Mix-Pasted from Slot %s: %d cells filled, %d skipped (not empty)", 
    format_slot_index(slot_index), cells_pasted, cells_skipped))
  
  return true
end

-- Flood fill selection with clipboard content
-- NOTE: This is different from "Replicate Into Selection" which uses content above the selection
-- Uses selection_in_pattern_pro() for precise column selection
local function flood_fill_pattern_from_clipboard(slot_index)
  local song = renoise.song()
  local selection = song.selection_in_pattern
  local pattern = song.selected_pattern
  
  local data = load_clipboard_from_preferences(slot_index)
  
  if not data or not data.rows or #data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty. Copy something to this slot first.")
    return false
  end
  
  local clipboard_rows = #data.rows
  local start_line, end_line
  local use_selection_pro = false
  local selection_pro = nil
  local single_track_idx = nil
  
  if selection then
    -- Use selection_in_pattern_pro() for precise column handling when there's a selection
    selection_pro = selection_in_pattern_pro()
    if not selection_pro then
      renoise.app():show_status("Flood Fill: No valid selection")
      return false
    end
    use_selection_pro = true
    start_line = selection.start_line
    end_line = selection.end_line
  else
    -- No selection: fill from cursor row to end of pattern on current track only
    start_line = song.selected_line_index
    end_line = pattern.number_of_lines
    single_track_idx = song.selected_track_index
    
    -- Check if target track is a sequencer track
    local target_track = song.tracks[single_track_idx]
    if target_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
      renoise.app():show_status("Cannot flood fill to non-sequencer track (Send/Master/Group). Select a sequencer track.")
      return false
    end
    
    -- Find max column indices in clipboard data and expand visible columns if needed
    local max_note_col = 0
    local max_fx_col = 0
    for _, row_data in ipairs(data.rows) do
      if row_data[1] then
        if row_data[1].note_columns then
          for col_idx, _ in pairs(row_data[1].note_columns) do
            if col_idx > max_note_col then max_note_col = col_idx end
          end
        end
        if row_data[1].effect_columns then
          for col_idx, _ in pairs(row_data[1].effect_columns) do
            if col_idx > max_fx_col then max_fx_col = col_idx end
          end
        end
      end
    end
    -- Expand visible columns if needed (max 12 note cols, max 8 fx cols)
    if max_note_col > target_track.visible_note_columns then
      target_track.visible_note_columns = math.min(max_note_col, 12)
    end
    if max_fx_col > target_track.visible_effect_columns then
      target_track.visible_effect_columns = math.min(max_fx_col, 8)
    end
  end
  
  -- Fill with clipboard content (cycling)
  for line_idx = start_line, end_line do
    if line_idx > pattern.number_of_lines then break end
    
    local source_row_idx = ((line_idx - start_line) % clipboard_rows) + 1
    local row_data = data.rows[source_row_idx]
    
    if row_data then
      if use_selection_pro then
        -- Selection mode: use selection_in_pattern_pro for precise columns
        for track_offset, track_info in ipairs(selection_pro) do
          local track_idx = track_info.track_index
          if track_idx > #song.tracks then break end
          
          local track = song.tracks[track_idx]
          if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
            local pattern_line = pattern.tracks[track_idx].lines[line_idx]
            
            -- Get source track data (cycle if clipboard has fewer tracks)
            local source_track_idx = ((track_offset - 1) % data.num_tracks) + 1
            local track_data = row_data[source_track_idx]
            
            if track_data then
              -- Determine selection column count for this track
              local selection_col_count = #track_info.note_columns
              
              -- Find max clipboard column index
              local clipboard_max_col = 0
              if track_data.note_columns then
                for col_idx, _ in pairs(track_data.note_columns) do
                  if col_idx > clipboard_max_col then
                    clipboard_max_col = col_idx
                  end
                end
              end
              
              -- Check if we need squeeze mode (clipboard has more columns than selection)
              if clipboard_max_col > selection_col_count and selection_col_count > 0 then
                -- SQUEEZE MODE: Remap clipboard columns to selection columns
                if track_data.note_columns then
                  for col_idx, col_data in pairs(track_data.note_columns) do
                    -- Check if this column has any content
                    local has_content = false
                    if col_data.note_value and col_data.note_value >= 0 and col_data.note_value <= 120 then
                      has_content = true
                    elseif col_data.instrument_value and col_data.instrument_value ~= 255 then
                      has_content = true
                    elseif col_data.volume_value and col_data.volume_value ~= 255 then
                      has_content = true
                    elseif col_data.panning_value and col_data.panning_value ~= 255 then
                      has_content = true
                    elseif col_data.delay_value and col_data.delay_value ~= 0 then
                      has_content = true
                    elseif col_data.effect_number_value and col_data.effect_number_value ~= 0 then
                      has_content = true
                    end
                    
                    if has_content then
                      local sel_col_idx = ((col_idx - 1) % selection_col_count) + 1
                      local dest_col = track_info.note_columns[sel_col_idx]
                      
                      if dest_col and dest_col <= #pattern_line.note_columns then
                        write_note_column_data(pattern_line.note_columns[dest_col], col_data)
                      end
                    end
                  end
                end
              else
                -- NORMAL MODE: Fill note columns directly (only those in selection)
                if track_data.note_columns then
                  for _, col_idx in ipairs(track_info.note_columns) do
                    if col_idx <= #pattern_line.note_columns then
                      local col_data = track_data.note_columns[col_idx]
                      if col_data then
                        write_note_column_data(pattern_line.note_columns[col_idx], col_data)
                      end
                    end
                  end
                end
              end
              
              -- Fill effect columns (only those in selection)
              if track_data.effect_columns then
                for _, col_idx in ipairs(track_info.effect_columns) do
                  if col_idx <= #pattern_line.effect_columns then
                    local col_data = track_data.effect_columns[col_idx]
                    if col_data then
                      write_effect_column_data(pattern_line.effect_columns[col_idx], col_data)
                    end
                  end
                end
              end
            end
          end
        end
      else
        -- No selection mode: fill current track from cursor to end
        local track = song.tracks[single_track_idx]
        local pattern_line = pattern.tracks[single_track_idx].lines[line_idx]
        
        -- Use first track's data from clipboard
        local track_data = row_data[1]
        
        if track_data then
          -- Fill all visible note columns
          if track_data.note_columns then
            for col_idx, col_data in pairs(track_data.note_columns) do
              if col_idx <= track.visible_note_columns then
                write_note_column_data(pattern_line.note_columns[col_idx], col_data)
              end
            end
          end
          
          -- Fill all visible effect columns
          if track_data.effect_columns then
            for col_idx, col_data in pairs(track_data.effect_columns) do
              if col_idx <= track.visible_effect_columns then
                write_effect_column_data(pattern_line.effect_columns[col_idx], col_data)
              end
            end
          end
        end
      end
    end
  end
  
  local filled_rows = end_line - start_line + 1
  if use_selection_pro then
    renoise.app():show_status(string.format("Flood filled %d rows with Clipboard Slot %s (%d row pattern)", 
      filled_rows, format_slot_index(slot_index), clipboard_rows))
  else
    renoise.app():show_status(string.format("Flood filled from row %d to %d with Clipboard Slot %s (%d row pattern)", 
      start_line, end_line, format_slot_index(slot_index), clipboard_rows))
  end
  
  return true
end

--------------------------------------------------------------------------------
-- Phrase Editor Clipboard Operations
--------------------------------------------------------------------------------

-- Copy selection from Phrase Editor to clipboard
local function copy_phrase_selection(slot_index, clear_after_copy)
  local song = renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected.")
    return false
  end
  
  local selection = song.selection_in_phrase
  
  if not selection then
    renoise.app():show_status("No selection in phrase to copy.")
    return false
  end
  
  local data = {
    source_type = "phrase",
    num_rows = selection.end_line - selection.start_line + 1,
    num_tracks = 1,  -- Phrases are single-track
    track_info = {
      [1] = {
        num_note_columns = phrase.visible_note_columns,
        num_effect_columns = phrase.visible_effect_columns
      }
    },
    rows = {}
  }
  
  local start_col = selection.start_column
  local end_col = selection.end_column
  
  -- Capture row data
  for line_idx = selection.start_line, selection.end_line do
    local relative_row_idx = line_idx - selection.start_line + 1
    local phrase_line = phrase:line(line_idx)
    
    data.rows[relative_row_idx] = {
      [1] = {
        note_columns = {},
        effect_columns = {}
      }
    }
    
    -- Copy note columns
    for col_idx = 1, phrase.visible_note_columns do
      if col_idx >= start_col and col_idx <= end_col then
        local note_column = phrase_line.note_columns[col_idx]
        data.rows[relative_row_idx][1].note_columns[col_idx] = 
          copy_note_column_data(note_column)
        
        -- Clear after copy if cutting (use explicit empty, not clear() which may set OFF)
        if clear_after_copy then
          clear_note_column_to_empty(note_column)
        end
      end
    end
    
    -- Copy effect columns
    for col_idx = 1, phrase.visible_effect_columns do
      local absolute_col = phrase.visible_note_columns + col_idx
      if absolute_col >= start_col and absolute_col <= end_col then
        local effect_column = phrase_line.effect_columns[col_idx]
        data.rows[relative_row_idx][1].effect_columns[col_idx] = 
          copy_effect_column_data(effect_column)
        
        -- Clear after copy if cutting
        if clear_after_copy then
          clear_effect_column_to_empty(effect_column)
        end
      end
    end
  end
  
  -- Save to preferences
  save_clipboard_to_preferences(slot_index, data)
  
  local action = clear_after_copy and "Cut" or "Copied"
  renoise.app():show_status(string.format("%s %d phrase rows to Clipboard Slot %s", 
    action, data.num_rows, format_slot_index(slot_index)))
  
  return true
end

-- Paste from clipboard to Phrase Editor at cursor position
-- Handles cross-editor paste: if data came from pattern (multi-track), uses first track only
local function paste_phrase_from_clipboard(slot_index)
  local song = renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected.")
    return false
  end
  
  local data = load_clipboard_from_preferences(slot_index)
  
  if not data or not data.rows or #data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty.")
    return false
  end
  
  local start_line = song.selected_line_index
  local phrase_length = phrase.number_of_lines
  local is_cross_editor = (data.source_type == "pattern")
  local rows_pasted = 0
  
  -- Paste data
  for row_idx, row_data in ipairs(data.rows) do
    local target_line = start_line + row_idx - 1
    if target_line > phrase_length then
      break
    end
    
    -- For cross-editor paste from pattern, use only first track's data
    -- Phrases are single-track, so we always target track 1
    local track_data = row_data[1]
    
    if track_data then
      local phrase_line = phrase:line(target_line)
      
      -- Paste note columns
      if track_data.note_columns then
        for col_idx, col_data in pairs(track_data.note_columns) do
          if col_idx <= phrase.visible_note_columns then
            write_note_column_data(phrase_line.note_columns[col_idx], col_data)
          end
        end
      end
      
      -- Paste effect columns
      if track_data.effect_columns then
        for col_idx, col_data in pairs(track_data.effect_columns) do
          if col_idx <= phrase.visible_effect_columns then
            write_effect_column_data(phrase_line.effect_columns[col_idx], col_data)
          end
        end
      end
      
      rows_pasted = rows_pasted + 1
    end
  end
  
  -- Show appropriate status message
  if is_cross_editor then
    local extra_info = ""
    if data.num_tracks > 1 then
      extra_info = " (used first track only from " .. data.num_tracks .. "-track pattern)"
    end
    renoise.app():show_status(string.format("Pasted %d rows from Pattern to Phrase (Slot %s)%s", 
      rows_pasted, format_slot_index(slot_index), extra_info))
  else
    renoise.app():show_status(string.format("Pasted %d rows to phrase from Clipboard Slot %s", 
      rows_pasted, format_slot_index(slot_index)))
  end
  
  return true
end

-- Mix-Paste from clipboard to Phrase Editor (only paste into empty cells)
local function mix_paste_phrase_from_clipboard(slot_index)
  local song = renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected.")
    return false
  end
  
  local selection = song.selection_in_phrase
  
  if not selection then
    renoise.app():show_status("Mix-Paste needs a selection. Select rows in phrase first, then mix-paste.")
    return false
  end
  
  local data = load_clipboard_from_preferences(slot_index)
  
  if not data or not data.rows or #data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty.")
    return false
  end
  
  local clipboard_rows = #data.rows
  local start_col = selection.start_column
  local end_col = selection.end_column
  local cells_pasted = 0
  local cells_skipped = 0
  
  -- Mix-paste into selection (cycling clipboard if needed)
  for line_idx = selection.start_line, selection.end_line do
    if line_idx > phrase.number_of_lines then break end
    
    local source_row_idx = ((line_idx - selection.start_line) % clipboard_rows) + 1
    local row_data = data.rows[source_row_idx]
    
    if row_data and row_data[1] then
      local track_data = row_data[1]
      local phrase_line = phrase:line(line_idx)
      
      -- Mix-paste note columns
      if track_data.note_columns then
        for col_idx, col_data in pairs(track_data.note_columns) do
          if col_idx <= phrase.visible_note_columns and
             col_idx >= start_col and col_idx <= end_col then
            local note_col = phrase_line.note_columns[col_idx]
            -- Only paste into empty cells
            if note_col.is_empty then
              write_note_column_data(note_col, col_data)
              cells_pasted = cells_pasted + 1
            else
              cells_skipped = cells_skipped + 1
            end
          end
        end
      end
      
      -- Mix-paste effect columns
      if track_data.effect_columns then
        for col_idx, col_data in pairs(track_data.effect_columns) do
          local absolute_col = phrase.visible_note_columns + col_idx
          if col_idx <= phrase.visible_effect_columns and
             absolute_col >= start_col and absolute_col <= end_col then
            local fx_col = phrase_line.effect_columns[col_idx]
            -- Only paste into empty cells
            if fx_col.is_empty then
              write_effect_column_data(fx_col, col_data)
              cells_pasted = cells_pasted + 1
            else
              cells_skipped = cells_skipped + 1
            end
          end
        end
      end
    end
  end
  
  renoise.app():show_status(string.format("Mix-Pasted to phrase from Slot %s: %d cells filled, %d skipped", 
    format_slot_index(slot_index), cells_pasted, cells_skipped))
  
  return true
end

-- Flood fill phrase selection with clipboard content
-- NOTE: This is different from "Replicate Into Selection" which uses content above the selection
local function flood_fill_phrase_from_clipboard(slot_index)
  local song = renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected. Select or create a phrase first.")
    return false
  end
  
  local selection = song.selection_in_phrase
  
  local data = load_clipboard_from_preferences(slot_index)
  
  if not data or not data.rows or #data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty. Copy something to this slot first.")
    return false
  end
  
  local clipboard_rows = #data.rows
  local start_line, end_line
  local start_col, end_col
  local has_selection = false
  
  if selection then
    -- Use selection bounds
    has_selection = true
    start_line = selection.start_line
    end_line = selection.end_line
    start_col = selection.start_column
    end_col = selection.end_column
  else
    -- No selection: fill from cursor row to end of phrase, all columns
    start_line = song.selected_line_index
    end_line = phrase.number_of_lines
    start_col = 1
    end_col = phrase.visible_note_columns + phrase.visible_effect_columns
  end
  
  -- Fill with clipboard content (cycling)
  for line_idx = start_line, end_line do
    if line_idx > phrase.number_of_lines then break end
    
    local source_row_idx = ((line_idx - start_line) % clipboard_rows) + 1
    local row_data = data.rows[source_row_idx]
    
    if row_data and row_data[1] then
      local track_data = row_data[1]
      local phrase_line = phrase:line(line_idx)
      
      -- Fill note columns
      if track_data.note_columns then
        for col_idx, col_data in pairs(track_data.note_columns) do
          if col_idx <= phrase.visible_note_columns and
             col_idx >= start_col and col_idx <= end_col then
            write_note_column_data(phrase_line.note_columns[col_idx], col_data)
          end
        end
      end
      
      -- Fill effect columns
      if track_data.effect_columns then
        for col_idx, col_data in pairs(track_data.effect_columns) do
          local absolute_col = phrase.visible_note_columns + col_idx
          if col_idx <= phrase.visible_effect_columns and
             absolute_col >= start_col and absolute_col <= end_col then
            write_effect_column_data(phrase_line.effect_columns[col_idx], col_data)
          end
        end
      end
    end
  end
  
  local filled_rows = end_line - start_line + 1
  if has_selection then
    renoise.app():show_status(string.format("Flood filled %d phrase rows with Clipboard Slot %s", 
      filled_rows, format_slot_index(slot_index)))
  else
    renoise.app():show_status(string.format("Flood filled phrase from row %d to %d with Clipboard Slot %s", 
      start_line, end_line, format_slot_index(slot_index)))
  end
  
  return true
end

--------------------------------------------------------------------------------
-- Replicate Into Selection Functions
--------------------------------------------------------------------------------

-- Pattern Editor: Replicate content above selection into selection
-- NOTE: This does NOT use the clipboard - it uses the rows ABOVE your selection
-- For clipboard-based filling, use Flood Fill instead
function PakettiClipboardReplicateIntoSelectionPattern()
  local song = renoise.song()
  local selection = song.selection_in_pattern
  
  if not selection then
    renoise.app():show_status("Replicate needs a selection. Select rows first.")
    return
  end
  
  local selection_start = selection.start_line
  
  if selection_start <= 1 then
    renoise.app():show_status("Replicate needs content ABOVE selection. Your selection starts at row 1. Use Flood Fill for clipboard data instead.")
    return
  end
  
  local source_length = selection_start - 1  -- rows 1 to selection_start-1
  local pattern = song.selected_pattern
  
  -- For each line in the selection, copy from source (cycling)
  for line_idx = selection.start_line, selection.end_line do
    local source_line = ((line_idx - selection_start) % source_length) + 1
    
    for track_idx = selection.start_track, selection.end_track do
      local track = song.tracks[track_idx]
      
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local source_pattern_line = pattern.tracks[track_idx].lines[source_line]
        local target_pattern_line = pattern.tracks[track_idx].lines[line_idx]
        
        -- Determine column range for this track
        local start_col = 1
        local end_col = track.visible_note_columns + track.visible_effect_columns
        
        if track_idx == selection.start_track then
          start_col = selection.start_column
        end
        if track_idx == selection.end_track then
          end_col = selection.end_column
        end
        
        -- Copy note columns
        for col_idx = 1, track.visible_note_columns do
          if col_idx >= start_col and col_idx <= end_col then
            local source_col = source_pattern_line.note_columns[col_idx]
            local target_col = target_pattern_line.note_columns[col_idx]
            write_note_column_data(target_col, copy_note_column_data(source_col))
          end
        end
        
        -- Copy effect columns
        for col_idx = 1, track.visible_effect_columns do
          local absolute_col = track.visible_note_columns + col_idx
          if absolute_col >= start_col and absolute_col <= end_col then
            local source_col = source_pattern_line.effect_columns[col_idx]
            local target_col = target_pattern_line.effect_columns[col_idx]
            write_effect_column_data(target_col, copy_effect_column_data(source_col))
          end
        end
      end
    end
  end
  
  local selection_rows = selection.end_line - selection.start_line + 1
  renoise.app():show_status(string.format("Replicated %d rows above into %d row selection", 
    source_length, selection_rows))
end

-- Phrase Editor: Replicate content above selection into selection
-- NOTE: This does NOT use the clipboard - it uses the rows ABOVE your selection
-- For clipboard-based filling, use Flood Fill instead
function PakettiClipboardReplicateIntoSelectionPhrase()
  local song = renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected. Select or create a phrase first.")
    return
  end
  
  local selection = song.selection_in_phrase
  
  if not selection then
    renoise.app():show_status("Replicate needs a selection in phrase. Select rows first.")
    return
  end
  
  local selection_start = selection.start_line
  
  if selection_start <= 1 then
    renoise.app():show_status("Replicate needs content ABOVE selection. Selection starts at row 1. Use Flood Fill for clipboard data instead.")
    return
  end
  
  local source_length = selection_start - 1
  local start_col = selection.start_column
  local end_col = selection.end_column
  
  -- For each line in the selection, copy from source (cycling)
  for line_idx = selection.start_line, selection.end_line do
    local source_line = ((line_idx - selection_start) % source_length) + 1
    
    local source_phrase_line = phrase:line(source_line)
    local target_phrase_line = phrase:line(line_idx)
    
    -- Copy note columns
    for col_idx = 1, phrase.visible_note_columns do
      if col_idx >= start_col and col_idx <= end_col then
        local source_col = source_phrase_line.note_columns[col_idx]
        local target_col = target_phrase_line.note_columns[col_idx]
        write_note_column_data(target_col, copy_note_column_data(source_col))
      end
    end
    
    -- Copy effect columns
    for col_idx = 1, phrase.visible_effect_columns do
      local absolute_col = phrase.visible_note_columns + col_idx
      if absolute_col >= start_col and absolute_col <= end_col then
        local source_col = source_phrase_line.effect_columns[col_idx]
        local target_col = target_phrase_line.effect_columns[col_idx]
        write_effect_column_data(target_col, copy_effect_column_data(source_col))
      end
    end
  end
  
  local selection_rows = selection.end_line - selection.start_line + 1
  renoise.app():show_status(string.format("Replicated %d rows above into %d row phrase selection", 
    source_length, selection_rows))
end

--------------------------------------------------------------------------------
-- Public API Functions (Auto-detect editor type)
--------------------------------------------------------------------------------

function PakettiClipboardCopy(slot_index)
  local editor = get_active_editor()
  if editor == "phrase" then
    copy_phrase_selection(slot_index, false)
  else
    copy_pattern_selection(slot_index, false)
  end
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

function PakettiClipboardCut(slot_index)
  local editor = get_active_editor()
  if editor == "phrase" then
    copy_phrase_selection(slot_index, true)
  else
    copy_pattern_selection(slot_index, true)
  end
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

function PakettiClipboardPaste(slot_index)
  local editor = get_active_editor()
  if editor == "phrase" then
    paste_phrase_from_clipboard(slot_index)
  else
    paste_pattern_from_clipboard(slot_index)
  end
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

function PakettiClipboardFloodFill(slot_index)
  local editor = get_active_editor()
  if editor == "phrase" then
    flood_fill_phrase_from_clipboard(slot_index)
  else
    flood_fill_pattern_from_clipboard(slot_index)
  end
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

function PakettiClipboardMixPaste(slot_index)
  local editor = get_active_editor()
  if editor == "phrase" then
    mix_paste_phrase_from_clipboard(slot_index)
  else
    mix_paste_pattern_from_clipboard(slot_index)
  end
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

function PakettiClipboardReplicateIntoSelection()
  local editor = get_active_editor()
  if editor == "phrase" then
    PakettiClipboardReplicateIntoSelectionPhrase()
  else
    PakettiClipboardReplicateIntoSelectionPattern()
  end
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

function PakettiClipboardClear(slot_index)
  clear_clipboard_slot(slot_index)
end

--------------------------------------------------------------------------------
-- Quick Operations (Default to Slot 01)
-- These provide simple Copy/Cut/Paste/Mix-Paste without specifying a slot
--------------------------------------------------------------------------------

function PakettiClipboardQuickCopy()
  PakettiClipboardCopy(1)
end

function PakettiClipboardQuickCut()
  PakettiClipboardCut(1)
end

function PakettiClipboardQuickPaste()
  PakettiClipboardPaste(1)
end

function PakettiClipboardQuickMixPaste()
  PakettiClipboardMixPaste(1)
end

function PakettiClipboardQuickFloodFill()
  PakettiClipboardFloodFill(1)
end

--------------------------------------------------------------------------------
-- Transform/Wonked Paste Functions
-- Applies transformations to clipboard data during paste
--------------------------------------------------------------------------------

-- Transform preset definitions (matching PakettiWonkify presets)
local CLIPBOARD_TRANSFORM_PRESETS = {
  {
    name = "Subtle Humanize",
    delay_enabled = true, delay_percentage = 25, delay_max = 16,
    velocity_enabled = true, velocity_percentage = 40, velocity_variation = 15,
    pitch_enabled = false, row_drift_enabled = false
  },
  {
    name = "Drunk Groove",
    delay_enabled = true, delay_percentage = 50, delay_max = 48,
    velocity_enabled = true, velocity_percentage = 30, velocity_variation = 25,
    pitch_enabled = false, row_drift_enabled = true, row_drift_percentage = 15, row_drift_max = 1
  },
  {
    name = "Lo-Fi Grit",
    delay_enabled = true, delay_percentage = 20, delay_max = 24,
    velocity_enabled = true, velocity_percentage = 60, velocity_variation = 40,
    pitch_enabled = false, row_drift_enabled = false
  },
  {
    name = "Glitchy",
    delay_enabled = false,
    velocity_enabled = false,
    pitch_enabled = false,
    row_drift_enabled = true, row_drift_percentage = 35, row_drift_max = 3
  },
  {
    name = "Chaos",
    delay_enabled = true, delay_percentage = 40, delay_max = 64,
    velocity_enabled = true, velocity_percentage = 50, velocity_variation = 35,
    pitch_enabled = true, pitch_percentage = 25, pitch_max = 3,
    row_drift_enabled = true, row_drift_percentage = 20, row_drift_max = 2
  },
  {
    name = "Jazz Feel",
    delay_enabled = true, delay_percentage = 30, delay_max = 20,
    velocity_enabled = true, velocity_percentage = 45, velocity_variation = 30,
    pitch_enabled = false, row_drift_enabled = false
  },
  {
    name = "Machine Tight",
    delay_enabled = true, delay_percentage = 100, delay_max = 8,
    velocity_enabled = false, pitch_enabled = false, row_drift_enabled = false
  }
}

-- Apply delay drift to a note column data table
local function apply_delay_drift(col_data, percentage, max_drift)
  if math.random(1, 100) <= percentage then
    local current_delay = col_data.delay_value or 0
    if current_delay == 255 then current_delay = 0 end  -- EMPTY_DELAY
    local drift = math.random(-max_drift, max_drift)
    col_data.delay_value = math.max(0, math.min(255, current_delay + drift))
  end
end

-- Apply velocity variation to a note column data table
local function apply_velocity_variation(col_data, percentage, variation)
  if math.random(1, 100) <= percentage then
    local current_vol = col_data.volume_value or 128
    if current_vol == 255 then current_vol = 128 end  -- EMPTY_VOLUME
    local var_amount = variation / 100
    local change = current_vol * var_amount * (math.random() * 2 - 1)
    col_data.volume_value = math.max(1, math.min(128, math.floor(current_vol + change)))
  end
end

-- Apply pitch drift to a note column data table
local function apply_pitch_drift(col_data, percentage, max_drift)
  if col_data.note_value and col_data.note_value >= 0 and col_data.note_value <= 119 then
    if math.random(1, 100) <= percentage then
      local drift = math.random(-max_drift, max_drift)
      col_data.note_value = math.max(0, math.min(119, col_data.note_value + drift))
    end
  end
end

-- Transform clipboard data with a preset
local function transform_clipboard_data(data, preset)
  if not data or not data.rows or #data.rows == 0 then
    return data
  end
  
  -- Seed random for variety
  math.randomseed(os.time() + os.clock() * 1000)
  
  -- Deep copy the data so we don't modify the original
  local transformed = {
    source_type = data.source_type,
    num_rows = data.num_rows,
    num_tracks = data.num_tracks,
    track_info = {},
    rows = {}
  }
  
  -- Copy track info
  for k, v in pairs(data.track_info) do
    transformed.track_info[k] = {
      num_note_columns = v.num_note_columns,
      num_effect_columns = v.num_effect_columns
    }
  end
  
  -- Transform each row
  for row_idx, row_data in ipairs(data.rows) do
    transformed.rows[row_idx] = {}
    
    for track_idx, track_data in pairs(row_data) do
      transformed.rows[row_idx][track_idx] = {
        note_columns = {},
        effect_columns = {}
      }
      
      -- Transform note columns
      if track_data.note_columns then
        for col_idx, col_data in pairs(track_data.note_columns) do
          -- Deep copy the column data
          local new_col = {
            note_value = col_data.note_value,
            instrument_value = col_data.instrument_value,
            volume_value = col_data.volume_value,
            panning_value = col_data.panning_value,
            delay_value = col_data.delay_value,
            effect_number_value = col_data.effect_number_value,
            effect_amount_value = col_data.effect_amount_value
          }
          
          -- Only transform actual notes (not empty or OFF)
          if new_col.note_value and new_col.note_value >= 0 and new_col.note_value <= 119 then
            -- Apply delay drift
            if preset.delay_enabled then
              apply_delay_drift(new_col, preset.delay_percentage, preset.delay_max)
            end
            
            -- Apply velocity variation
            if preset.velocity_enabled then
              apply_velocity_variation(new_col, preset.velocity_percentage, preset.velocity_variation)
            end
            
            -- Apply pitch drift
            if preset.pitch_enabled then
              apply_pitch_drift(new_col, preset.pitch_percentage or 25, preset.pitch_max or 2)
            end
          end
          
          transformed.rows[row_idx][track_idx].note_columns[col_idx] = new_col
        end
      end
      
      -- Copy effect columns (no transformation for now)
      if track_data.effect_columns then
        for col_idx, col_data in pairs(track_data.effect_columns) do
          transformed.rows[row_idx][track_idx].effect_columns[col_idx] = {
            number_value = col_data.number_value,
            amount_value = col_data.amount_value
          }
        end
      end
    end
  end
  
  -- Apply row drift (swap note positions) if enabled
  if preset.row_drift_enabled and preset.row_drift_percentage and preset.row_drift_max then
    local num_rows = #transformed.rows
    for row_idx = 1, num_rows do
      if math.random(1, 100) <= preset.row_drift_percentage then
        local drift = math.random(-preset.row_drift_max, preset.row_drift_max)
        local target_row = row_idx + drift
        if target_row >= 1 and target_row <= num_rows then
          -- Swap rows
          local temp = transformed.rows[row_idx]
          transformed.rows[row_idx] = transformed.rows[target_row]
          transformed.rows[target_row] = temp
        end
      end
    end
  end
  
  return transformed
end

-- Wonked paste to Pattern Editor with transformation
local function wonked_paste_pattern_from_clipboard(slot_index, preset_index)
  local song = renoise.song()
  local data = load_clipboard_from_preferences(slot_index)
  
  if not data or not data.rows or #data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty.")
    return false
  end
  
  local preset = CLIPBOARD_TRANSFORM_PRESETS[preset_index]
  if not preset then
    renoise.app():show_status("Invalid transform preset.")
    return false
  end
  
  -- Transform the clipboard data
  local transformed_data = transform_clipboard_data(data, preset)
  
  local pattern = song.selected_pattern
  local start_line = song.selected_line_index
  local start_track = song.selected_track_index
  local start_note_column = song.selected_note_column_index or 1
  local pattern_length = pattern.number_of_lines
  local rows_pasted = 0
  
  -- Check if target track is a sequencer track
  local target_track = song.tracks[start_track]
  if target_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Cannot paste to non-sequencer track.")
    return false
  end
  
  -- Make delay column visible if we're using delay drift
  if preset.delay_enabled then
    target_track.delay_column_visible = true
  end
  
  -- Make volume column visible if we're using velocity variation
  if preset.velocity_enabled then
    target_track.volume_column_visible = true
  end
  
  -- Find the minimum column index in the clipboard data to calculate offset
  local min_clipboard_col = 999
  for _, row_data in ipairs(transformed_data.rows) do
    for _, track_data in pairs(row_data) do
      if track_data.note_columns then
        for col_idx, _ in pairs(track_data.note_columns) do
          if col_idx < min_clipboard_col then
            min_clipboard_col = col_idx
          end
        end
      end
    end
  end
  if min_clipboard_col == 999 then min_clipboard_col = 1 end
  
  -- Calculate column offset
  local col_offset = start_note_column - min_clipboard_col
  
  -- Paste transformed data
  for row_idx, row_data in ipairs(transformed_data.rows) do
    local target_line = start_line + row_idx - 1
    if target_line > pattern_length then
      break
    end
    
    for relative_track_idx, track_data in pairs(row_data) do
      local target_track_idx = start_track + relative_track_idx - 1
      if target_track_idx > #song.tracks then
        break
      end
      
      local track = song.tracks[target_track_idx]
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local pattern_line = pattern.tracks[target_track_idx].lines[target_line]
        
        -- Paste note columns
        if track_data.note_columns then
          for col_idx, col_data in pairs(track_data.note_columns) do
            local target_col = col_idx + col_offset
            if target_col >= 1 and target_col <= track.visible_note_columns then
              write_note_column_data(pattern_line.note_columns[target_col], col_data)
            end
          end
        end
        
        -- Paste effect columns
        if track_data.effect_columns then
          for col_idx, col_data in pairs(track_data.effect_columns) do
            if col_idx <= track.visible_effect_columns then
              write_effect_column_data(pattern_line.effect_columns[col_idx], col_data)
            end
          end
        end
      end
    end
    
    rows_pasted = rows_pasted + 1
  end
  
  renoise.app():show_status(string.format("Wonked Paste (%s): %d rows from Slot %s", 
    preset.name, rows_pasted, format_slot_index(slot_index)))
  
  return true
end

-- Wonked paste to Phrase Editor with transformation
local function wonked_paste_phrase_from_clipboard(slot_index, preset_index)
  local song = renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected.")
    return false
  end
  
  local data = load_clipboard_from_preferences(slot_index)
  
  if not data or not data.rows or #data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty.")
    return false
  end
  
  local preset = CLIPBOARD_TRANSFORM_PRESETS[preset_index]
  if not preset then
    renoise.app():show_status("Invalid transform preset.")
    return false
  end
  
  -- Transform the clipboard data
  local transformed_data = transform_clipboard_data(data, preset)
  
  local start_line = song.selected_line_index
  local phrase_length = phrase.number_of_lines
  local rows_pasted = 0
  
  -- Paste transformed data
  for row_idx, row_data in ipairs(transformed_data.rows) do
    local target_line = start_line + row_idx - 1
    if target_line > phrase_length then
      break
    end
    
    local track_data = row_data[1]
    if track_data then
      local phrase_line = phrase:line(target_line)
      
      -- Paste note columns
      if track_data.note_columns then
        for col_idx, col_data in pairs(track_data.note_columns) do
          if col_idx <= phrase.visible_note_columns then
            write_note_column_data(phrase_line.note_columns[col_idx], col_data)
          end
        end
      end
      
      -- Paste effect columns
      if track_data.effect_columns then
        for col_idx, col_data in pairs(track_data.effect_columns) do
          if col_idx <= phrase.visible_effect_columns then
            write_effect_column_data(phrase_line.effect_columns[col_idx], col_data)
          end
        end
      end
      
      rows_pasted = rows_pasted + 1
    end
  end
  
  renoise.app():show_status(string.format("Wonked Paste (%s): %d rows to phrase from Slot %s", 
    preset.name, rows_pasted, format_slot_index(slot_index)))
  
  return true
end

-- Public Wonked Paste function (auto-detects editor)
function PakettiClipboardWonkedPaste(slot_index, preset_index)
  local editor = get_active_editor()
  if editor == "phrase" then
    wonked_paste_phrase_from_clipboard(slot_index, preset_index)
  else
    wonked_paste_pattern_from_clipboard(slot_index, preset_index)
  end
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Convenience functions for each preset
function PakettiClipboardPasteHumanized(slot_index)
  PakettiClipboardWonkedPaste(slot_index, 1)  -- Subtle Humanize
end

function PakettiClipboardPasteDrunk(slot_index)
  PakettiClipboardWonkedPaste(slot_index, 2)  -- Drunk Groove
end

function PakettiClipboardPasteLoFi(slot_index)
  PakettiClipboardWonkedPaste(slot_index, 3)  -- Lo-Fi Grit
end

function PakettiClipboardPasteGlitchy(slot_index)
  PakettiClipboardWonkedPaste(slot_index, 4)  -- Glitchy
end

function PakettiClipboardPasteChaos(slot_index)
  PakettiClipboardWonkedPaste(slot_index, 5)  -- Chaos
end

function PakettiClipboardPasteJazz(slot_index)
  PakettiClipboardWonkedPaste(slot_index, 6)  -- Jazz Feel
end

function PakettiClipboardPasteTight(slot_index)
  PakettiClipboardWonkedPaste(slot_index, 7)  -- Machine Tight
end

-- Quick Wonked Paste functions (default to Slot 01)
function PakettiClipboardQuickPasteHumanized()
  PakettiClipboardPasteHumanized(1)
end

function PakettiClipboardQuickPasteDrunk()
  PakettiClipboardPasteDrunk(1)
end

function PakettiClipboardQuickPasteLoFi()
  PakettiClipboardPasteLoFi(1)
end

function PakettiClipboardQuickPasteGlitchy()
  PakettiClipboardPasteGlitchy(1)
end

function PakettiClipboardQuickPasteChaos()
  PakettiClipboardPasteChaos(1)
end

function PakettiClipboardQuickPasteJazz()
  PakettiClipboardPasteJazz(1)
end

function PakettiClipboardQuickPasteTight()
  PakettiClipboardPasteTight(1)
end

--------------------------------------------------------------------------------
-- Transpose on Paste Functions
--------------------------------------------------------------------------------

-- Transpose clipboard data by semitones
local function transpose_clipboard_data(data, semitones)
  if not data or not data.rows or #data.rows == 0 then
    return data
  end
  
  -- Deep copy the data
  local transposed = {
    source_type = data.source_type,
    num_rows = data.num_rows,
    num_tracks = data.num_tracks,
    track_info = {},
    rows = {}
  }
  
  -- Copy track info
  for k, v in pairs(data.track_info) do
    transposed.track_info[k] = {
      num_note_columns = v.num_note_columns,
      num_effect_columns = v.num_effect_columns
    }
  end
  
  -- Transpose each row
  for row_idx, row_data in ipairs(data.rows) do
    transposed.rows[row_idx] = {}
    
    for track_idx, track_data in pairs(row_data) do
      transposed.rows[row_idx][track_idx] = {
        note_columns = {},
        effect_columns = {}
      }
      
      -- Transpose note columns
      if track_data.note_columns then
        for col_idx, col_data in pairs(track_data.note_columns) do
          local new_col = {
            note_value = col_data.note_value,
            instrument_value = col_data.instrument_value,
            volume_value = col_data.volume_value,
            panning_value = col_data.panning_value,
            delay_value = col_data.delay_value,
            effect_number_value = col_data.effect_number_value,
            effect_amount_value = col_data.effect_amount_value
          }
          
          -- Transpose actual notes (not empty 121 or OFF 120)
          if new_col.note_value and new_col.note_value >= 0 and new_col.note_value <= 119 then
            new_col.note_value = math.max(0, math.min(119, new_col.note_value + semitones))
          end
          
          transposed.rows[row_idx][track_idx].note_columns[col_idx] = new_col
        end
      end
      
      -- Copy effect columns unchanged
      if track_data.effect_columns then
        for col_idx, col_data in pairs(track_data.effect_columns) do
          transposed.rows[row_idx][track_idx].effect_columns[col_idx] = {
            number_value = col_data.number_value,
            amount_value = col_data.amount_value
          }
        end
      end
    end
  end
  
  return transposed
end

-- Transposed paste to Pattern Editor
local function transposed_paste_pattern_from_clipboard(slot_index, semitones)
  local song = renoise.song()
  local data = load_clipboard_from_preferences(slot_index)
  
  if not data or not data.rows or #data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty.")
    return false
  end
  
  -- Transpose the clipboard data
  local transposed_data = transpose_clipboard_data(data, semitones)
  
  local pattern = song.selected_pattern
  local start_line = song.selected_line_index
  local start_track = song.selected_track_index
  local start_note_column = song.selected_note_column_index or 1
  local pattern_length = pattern.number_of_lines
  local rows_pasted = 0
  
  -- Check if target track is a sequencer track
  local target_track = song.tracks[start_track]
  if target_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Cannot paste to non-sequencer track.")
    return false
  end
  
  -- Find the minimum column index
  local min_clipboard_col = 999
  for _, row_data in ipairs(transposed_data.rows) do
    for _, track_data in pairs(row_data) do
      if track_data.note_columns then
        for col_idx, _ in pairs(track_data.note_columns) do
          if col_idx < min_clipboard_col then
            min_clipboard_col = col_idx
          end
        end
      end
    end
  end
  if min_clipboard_col == 999 then min_clipboard_col = 1 end
  
  local col_offset = start_note_column - min_clipboard_col
  
  -- Paste transposed data
  for row_idx, row_data in ipairs(transposed_data.rows) do
    local target_line = start_line + row_idx - 1
    if target_line > pattern_length then break end
    
    for relative_track_idx, track_data in pairs(row_data) do
      local target_track_idx = start_track + relative_track_idx - 1
      if target_track_idx > #song.tracks then break end
      
      local track = song.tracks[target_track_idx]
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local pattern_line = pattern.tracks[target_track_idx].lines[target_line]
        
        if track_data.note_columns then
          for col_idx, col_data in pairs(track_data.note_columns) do
            local target_col = col_idx + col_offset
            if target_col >= 1 and target_col <= track.visible_note_columns then
              write_note_column_data(pattern_line.note_columns[target_col], col_data)
            end
          end
        end
        
        if track_data.effect_columns then
          for col_idx, col_data in pairs(track_data.effect_columns) do
            if col_idx <= track.visible_effect_columns then
              write_effect_column_data(pattern_line.effect_columns[col_idx], col_data)
            end
          end
        end
      end
    end
    rows_pasted = rows_pasted + 1
  end
  
  local direction = semitones >= 0 and "+" or ""
  renoise.app():show_status(string.format("Transposed Paste (%s%d semitones): %d rows from Slot %s", 
    direction, semitones, rows_pasted, format_slot_index(slot_index)))
  
  return true
end

-- Transposed paste to Phrase Editor
local function transposed_paste_phrase_from_clipboard(slot_index, semitones)
  local song = renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected.")
    return false
  end
  
  local data = load_clipboard_from_preferences(slot_index)
  
  if not data or not data.rows or #data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty.")
    return false
  end
  
  local transposed_data = transpose_clipboard_data(data, semitones)
  
  local start_line = song.selected_line_index
  local phrase_length = phrase.number_of_lines
  local rows_pasted = 0
  
  for row_idx, row_data in ipairs(transposed_data.rows) do
    local target_line = start_line + row_idx - 1
    if target_line > phrase_length then break end
    
    local track_data = row_data[1]
    if track_data then
      local phrase_line = phrase:line(target_line)
      
      if track_data.note_columns then
        for col_idx, col_data in pairs(track_data.note_columns) do
          if col_idx <= phrase.visible_note_columns then
            write_note_column_data(phrase_line.note_columns[col_idx], col_data)
          end
        end
      end
      
      if track_data.effect_columns then
        for col_idx, col_data in pairs(track_data.effect_columns) do
          if col_idx <= phrase.visible_effect_columns then
            write_effect_column_data(phrase_line.effect_columns[col_idx], col_data)
          end
        end
      end
      
      rows_pasted = rows_pasted + 1
    end
  end
  
  local direction = semitones >= 0 and "+" or ""
  renoise.app():show_status(string.format("Transposed Paste (%s%d): %d rows to phrase from Slot %s", 
    direction, semitones, rows_pasted, format_slot_index(slot_index)))
  
  return true
end

-- Public Transposed Paste function (auto-detects editor)
function PakettiClipboardTransposedPaste(slot_index, semitones)
  local editor = get_active_editor()
  if editor == "phrase" then
    transposed_paste_phrase_from_clipboard(slot_index, semitones)
  else
    transposed_paste_pattern_from_clipboard(slot_index, semitones)
  end
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Convenience functions for common transpositions
function PakettiClipboardPasteTransposeUp1(slot_index)
  PakettiClipboardTransposedPaste(slot_index, 1)
end

function PakettiClipboardPasteTransposeDown1(slot_index)
  PakettiClipboardTransposedPaste(slot_index, -1)
end

function PakettiClipboardPasteTransposeUp12(slot_index)
  PakettiClipboardTransposedPaste(slot_index, 12)  -- Octave up
end

function PakettiClipboardPasteTransposeDown12(slot_index)
  PakettiClipboardTransposedPaste(slot_index, -12)  -- Octave down
end

function PakettiClipboardPasteTransposeUp7(slot_index)
  PakettiClipboardTransposedPaste(slot_index, 7)  -- Perfect fifth up
end

function PakettiClipboardPasteTransposeDown7(slot_index)
  PakettiClipboardTransposedPaste(slot_index, -7)  -- Perfect fifth down
end

-- Quick Transpose Paste functions (default to Slot 01)
function PakettiClipboardQuickPasteTransposeUp1()
  PakettiClipboardPasteTransposeUp1(1)
end

function PakettiClipboardQuickPasteTransposeDown1()
  PakettiClipboardPasteTransposeDown1(1)
end

function PakettiClipboardQuickPasteTransposeUp12()
  PakettiClipboardPasteTransposeUp12(1)
end

function PakettiClipboardQuickPasteTransposeDown12()
  PakettiClipboardPasteTransposeDown12(1)
end

function PakettiClipboardQuickPasteTransposeUp7()
  PakettiClipboardPasteTransposeUp7(1)
end

function PakettiClipboardQuickPasteTransposeDown7()
  PakettiClipboardPasteTransposeDown7(1)
end

--------------------------------------------------------------------------------
-- Partial Column Copy/Paste Functions
-- Copy/paste only specific sub-columns (notes only, effects only)
--------------------------------------------------------------------------------

-- Copy mode constants
local COPY_MODE = {
  ALL = 1,           -- Everything (current behavior)
  NOTES_ONLY = 2,    -- Note + Instrument only
  EFFECTS_ONLY = 3,  -- Volume, Pan, Delay, SFX columns only
}

-- Copy only notes (note + instrument) from selection
local function copy_pattern_notes_only(slot_index, clear_after_copy)
  local song = renoise.song()
  local selection = song.selection_in_pattern
  
  if not selection then
    renoise.app():show_status("No selection in pattern to copy.")
    return false
  end
  
  local selection_pro = selection_in_pattern_pro()
  if not selection_pro then
    renoise.app():show_status("No selection in pattern to copy.")
    return false
  end
  
  local pattern = song.selected_pattern
  local data = {
    source_type = "pattern",
    num_rows = selection.end_line - selection.start_line + 1,
    num_tracks = #selection_pro,
    track_info = {},
    rows = {},
    copy_mode = COPY_MODE.NOTES_ONLY
  }
  
  for relative_track_idx, track_info in ipairs(selection_pro) do
    local track_idx = track_info.track_index
    local track = song.tracks[track_idx]
    
    data.track_info[relative_track_idx] = {
      num_note_columns = #track_info.note_columns,
      num_effect_columns = 0  -- No effect columns for notes-only
    }
    
    for line_idx = selection.start_line, selection.end_line do
      local relative_row_idx = line_idx - selection.start_line + 1
      local pattern_line = pattern.tracks[track_idx].lines[line_idx]
      
      if not data.rows[relative_row_idx] then
        data.rows[relative_row_idx] = {}
      end
      
      data.rows[relative_row_idx][relative_track_idx] = {
        note_columns = {},
        effect_columns = {}
      }
      
      for _, col_idx in ipairs(track_info.note_columns) do
        if col_idx <= #pattern_line.note_columns then
          local note_column = pattern_line.note_columns[col_idx]
          -- Copy only note and instrument, rest set to empty
          data.rows[relative_row_idx][relative_track_idx].note_columns[col_idx] = {
            note_value = note_column.note_value,
            instrument_value = note_column.instrument_value,
            volume_value = 255,  -- Empty
            panning_value = 255,  -- Empty
            delay_value = 0,
            effect_number_value = 0,
            effect_amount_value = 0
          }
          
          if clear_after_copy then
            -- Only clear note and instrument, keep effects
            note_column.note_string = "---"
            note_column.instrument_string = ".."
          end
        end
      end
    end
  end
  
  save_clipboard_to_preferences(slot_index, data)
  
  local action = clear_after_copy and "Cut" or "Copied"
  renoise.app():show_status(string.format("%s notes only (%d rows) to Clipboard Slot %s", 
    action, data.num_rows, format_slot_index(slot_index)))
  
  return true
end

-- Copy only effects (vol, pan, delay, sfx) from selection
local function copy_pattern_effects_only(slot_index, clear_after_copy)
  local song = renoise.song()
  local selection = song.selection_in_pattern
  
  if not selection then
    renoise.app():show_status("No selection in pattern to copy.")
    return false
  end
  
  local selection_pro = selection_in_pattern_pro()
  if not selection_pro then
    renoise.app():show_status("No selection in pattern to copy.")
    return false
  end
  
  local pattern = song.selected_pattern
  local data = {
    source_type = "pattern",
    num_rows = selection.end_line - selection.start_line + 1,
    num_tracks = #selection_pro,
    track_info = {},
    rows = {},
    copy_mode = COPY_MODE.EFFECTS_ONLY
  }
  
  for relative_track_idx, track_info in ipairs(selection_pro) do
    local track_idx = track_info.track_index
    local track = song.tracks[track_idx]
    
    data.track_info[relative_track_idx] = {
      num_note_columns = #track_info.note_columns,
      num_effect_columns = #track_info.effect_columns
    }
    
    for line_idx = selection.start_line, selection.end_line do
      local relative_row_idx = line_idx - selection.start_line + 1
      local pattern_line = pattern.tracks[track_idx].lines[line_idx]
      
      if not data.rows[relative_row_idx] then
        data.rows[relative_row_idx] = {}
      end
      
      data.rows[relative_row_idx][relative_track_idx] = {
        note_columns = {},
        effect_columns = {}
      }
      
      -- Copy note columns effects only (vol, pan, delay, sfx)
      for _, col_idx in ipairs(track_info.note_columns) do
        if col_idx <= #pattern_line.note_columns then
          local note_column = pattern_line.note_columns[col_idx]
          -- Copy only effects, note/instrument set to empty
          data.rows[relative_row_idx][relative_track_idx].note_columns[col_idx] = {
            note_value = 121,  -- Empty
            instrument_value = 255,  -- Empty
            volume_value = note_column.volume_value,
            panning_value = note_column.panning_value,
            delay_value = note_column.delay_value,
            effect_number_value = note_column.effect_number_value,
            effect_amount_value = note_column.effect_amount_value
          }
          
          if clear_after_copy then
            -- Only clear effects, keep note/instrument
            note_column.volume_string = ".."
            note_column.panning_string = ".."
            note_column.delay_value = 0
            note_column.effect_number_value = 0
            note_column.effect_amount_value = 0
          end
        end
      end
      
      -- Copy effect columns
      for _, col_idx in ipairs(track_info.effect_columns) do
        if col_idx <= #pattern_line.effect_columns then
          local effect_column = pattern_line.effect_columns[col_idx]
          data.rows[relative_row_idx][relative_track_idx].effect_columns[col_idx] = 
            copy_effect_column_data(effect_column)
          
          if clear_after_copy then
            clear_effect_column_to_empty(effect_column)
          end
        end
      end
    end
  end
  
  save_clipboard_to_preferences(slot_index, data)
  
  local action = clear_after_copy and "Cut" or "Copied"
  renoise.app():show_status(string.format("%s effects only (%d rows) to Clipboard Slot %s", 
    action, data.num_rows, format_slot_index(slot_index)))
  
  return true
end

-- Paste only notes (note + instrument) to pattern
local function paste_pattern_notes_only(slot_index)
  local song = renoise.song()
  local data = load_clipboard_from_preferences(slot_index)
  
  if not data or not data.rows or #data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty.")
    return false
  end
  
  local pattern = song.selected_pattern
  local start_line = song.selected_line_index
  local start_track = song.selected_track_index
  local start_note_column = song.selected_note_column_index or 1
  local pattern_length = pattern.number_of_lines
  local rows_pasted = 0
  
  local target_track = song.tracks[start_track]
  if target_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Cannot paste to non-sequencer track.")
    return false
  end
  
  -- Find min column for offset
  local min_clipboard_col = 999
  for _, row_data in ipairs(data.rows) do
    for _, track_data in pairs(row_data) do
      if track_data.note_columns then
        for col_idx, _ in pairs(track_data.note_columns) do
          if col_idx < min_clipboard_col then
            min_clipboard_col = col_idx
          end
        end
      end
    end
  end
  if min_clipboard_col == 999 then min_clipboard_col = 1 end
  
  local col_offset = start_note_column - min_clipboard_col
  
  for row_idx, row_data in ipairs(data.rows) do
    local target_line = start_line + row_idx - 1
    if target_line > pattern_length then break end
    
    for relative_track_idx, track_data in pairs(row_data) do
      local target_track_idx = start_track + relative_track_idx - 1
      if target_track_idx > #song.tracks then break end
      
      local track = song.tracks[target_track_idx]
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local pattern_line = pattern.tracks[target_track_idx].lines[target_line]
        
        if track_data.note_columns then
          for col_idx, col_data in pairs(track_data.note_columns) do
            local target_col = col_idx + col_offset
            if target_col >= 1 and target_col <= track.visible_note_columns then
              local note_col = pattern_line.note_columns[target_col]
              -- Only paste note and instrument
              note_col.note_value = col_data.note_value
              note_col.instrument_value = col_data.instrument_value
            end
          end
        end
      end
    end
    rows_pasted = rows_pasted + 1
  end
  
  renoise.app():show_status(string.format("Pasted notes only (%d rows) from Slot %s", 
    rows_pasted, format_slot_index(slot_index)))
  
  return true
end

-- Paste only effects (vol, pan, delay, sfx) to pattern
local function paste_pattern_effects_only(slot_index)
  local song = renoise.song()
  local data = load_clipboard_from_preferences(slot_index)
  
  if not data or not data.rows or #data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty.")
    return false
  end
  
  local pattern = song.selected_pattern
  local start_line = song.selected_line_index
  local start_track = song.selected_track_index
  local start_note_column = song.selected_note_column_index or 1
  local pattern_length = pattern.number_of_lines
  local rows_pasted = 0
  
  local target_track = song.tracks[start_track]
  if target_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Cannot paste to non-sequencer track.")
    return false
  end
  
  -- Find min column for offset
  local min_clipboard_col = 999
  for _, row_data in ipairs(data.rows) do
    for _, track_data in pairs(row_data) do
      if track_data.note_columns then
        for col_idx, _ in pairs(track_data.note_columns) do
          if col_idx < min_clipboard_col then
            min_clipboard_col = col_idx
          end
        end
      end
    end
  end
  if min_clipboard_col == 999 then min_clipboard_col = 1 end
  
  local col_offset = start_note_column - min_clipboard_col
  
  for row_idx, row_data in ipairs(data.rows) do
    local target_line = start_line + row_idx - 1
    if target_line > pattern_length then break end
    
    for relative_track_idx, track_data in pairs(row_data) do
      local target_track_idx = start_track + relative_track_idx - 1
      if target_track_idx > #song.tracks then break end
      
      local track = song.tracks[target_track_idx]
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local pattern_line = pattern.tracks[target_track_idx].lines[target_line]
        
        -- Paste note column effects only
        if track_data.note_columns then
          for col_idx, col_data in pairs(track_data.note_columns) do
            local target_col = col_idx + col_offset
            if target_col >= 1 and target_col <= track.visible_note_columns then
              local note_col = pattern_line.note_columns[target_col]
              -- Only paste effects, leave note/instrument untouched
              if col_data.volume_value ~= 255 then
                note_col.volume_value = col_data.volume_value
              end
              if col_data.panning_value ~= 255 then
                note_col.panning_value = col_data.panning_value
              end
              if col_data.delay_value ~= 0 then
                note_col.delay_value = col_data.delay_value
              end
              if col_data.effect_number_value ~= 0 or col_data.effect_amount_value ~= 0 then
                note_col.effect_number_value = col_data.effect_number_value
                note_col.effect_amount_value = col_data.effect_amount_value
              end
            end
          end
        end
        
        -- Paste effect columns
        if track_data.effect_columns then
          for col_idx, col_data in pairs(track_data.effect_columns) do
            if col_idx <= track.visible_effect_columns then
              write_effect_column_data(pattern_line.effect_columns[col_idx], col_data)
            end
          end
        end
      end
    end
    rows_pasted = rows_pasted + 1
  end
  
  renoise.app():show_status(string.format("Pasted effects only (%d rows) from Slot %s", 
    rows_pasted, format_slot_index(slot_index)))
  
  return true
end

-- Public partial copy functions
function PakettiClipboardCopyNotesOnly(slot_index)
  local editor = get_active_editor()
  if editor == "pattern" then
    copy_pattern_notes_only(slot_index, false)
  else
    renoise.app():show_status("Notes-only copy not yet supported in Phrase Editor")
  end
end

function PakettiClipboardCutNotesOnly(slot_index)
  local editor = get_active_editor()
  if editor == "pattern" then
    copy_pattern_notes_only(slot_index, true)
  else
    renoise.app():show_status("Notes-only cut not yet supported in Phrase Editor")
  end
end

function PakettiClipboardCopyEffectsOnly(slot_index)
  local editor = get_active_editor()
  if editor == "pattern" then
    copy_pattern_effects_only(slot_index, false)
  else
    renoise.app():show_status("Effects-only copy not yet supported in Phrase Editor")
  end
end

function PakettiClipboardCutEffectsOnly(slot_index)
  local editor = get_active_editor()
  if editor == "pattern" then
    copy_pattern_effects_only(slot_index, true)
  else
    renoise.app():show_status("Effects-only cut not yet supported in Phrase Editor")
  end
end

function PakettiClipboardPasteNotesOnly(slot_index)
  local editor = get_active_editor()
  if editor == "pattern" then
    paste_pattern_notes_only(slot_index)
  else
    renoise.app():show_status("Notes-only paste not yet supported in Phrase Editor")
  end
end

function PakettiClipboardPasteEffectsOnly(slot_index)
  local editor = get_active_editor()
  if editor == "pattern" then
    paste_pattern_effects_only(slot_index)
  else
    renoise.app():show_status("Effects-only paste not yet supported in Phrase Editor")
  end
end

-- Quick partial copy/paste (default to Slot 01)
function PakettiClipboardQuickCopyNotesOnly()
  PakettiClipboardCopyNotesOnly(1)
end

function PakettiClipboardQuickCutNotesOnly()
  PakettiClipboardCutNotesOnly(1)
end

function PakettiClipboardQuickCopyEffectsOnly()
  PakettiClipboardCopyEffectsOnly(1)
end

function PakettiClipboardQuickCutEffectsOnly()
  PakettiClipboardCutEffectsOnly(1)
end

function PakettiClipboardQuickPasteNotesOnly()
  PakettiClipboardPasteNotesOnly(1)
end

function PakettiClipboardQuickPasteEffectsOnly()
  PakettiClipboardPasteEffectsOnly(1)
end

--------------------------------------------------------------------------------
-- Swap Operation Functions
-- Exchange clipboard contents with current selection
--------------------------------------------------------------------------------

-- Internal function to capture selection data without saving to preferences
local function capture_pattern_selection_data()
  local song = renoise.song()
  local selection = song.selection_in_pattern
  
  if not selection then
    return nil
  end
  
  local selection_pro = selection_in_pattern_pro()
  if not selection_pro then
    return nil
  end
  
  local pattern = song.selected_pattern
  local data = {
    source_type = "pattern",
    num_rows = selection.end_line - selection.start_line + 1,
    num_tracks = #selection_pro,
    track_info = {},
    rows = {}
  }
  
  for relative_track_idx, track_info in ipairs(selection_pro) do
    local track_idx = track_info.track_index
    
    data.track_info[relative_track_idx] = {
      num_note_columns = #track_info.note_columns,
      num_effect_columns = #track_info.effect_columns
    }
    
    for line_idx = selection.start_line, selection.end_line do
      local relative_row_idx = line_idx - selection.start_line + 1
      local pattern_line = pattern.tracks[track_idx].lines[line_idx]
      
      if not data.rows[relative_row_idx] then
        data.rows[relative_row_idx] = {}
      end
      
      data.rows[relative_row_idx][relative_track_idx] = {
        note_columns = {},
        effect_columns = {}
      }
      
      for _, col_idx in ipairs(track_info.note_columns) do
        if col_idx <= #pattern_line.note_columns then
          local note_column = pattern_line.note_columns[col_idx]
          data.rows[relative_row_idx][relative_track_idx].note_columns[col_idx] = 
            copy_note_column_data(note_column)
        end
      end
      
      for _, col_idx in ipairs(track_info.effect_columns) do
        if col_idx <= #pattern_line.effect_columns then
          local effect_column = pattern_line.effect_columns[col_idx]
          data.rows[relative_row_idx][relative_track_idx].effect_columns[col_idx] = 
            copy_effect_column_data(effect_column)
        end
      end
    end
  end
  
  return data
end

-- Internal function to paste data to the current selection
local function paste_data_to_pattern_selection(data)
  local song = renoise.song()
  local selection = song.selection_in_pattern
  
  if not selection or not data or not data.rows or #data.rows == 0 then
    return false
  end
  
  local selection_pro = selection_in_pattern_pro()
  if not selection_pro then
    return false
  end
  
  local pattern = song.selected_pattern
  local clipboard_rows = #data.rows
  
  for line_idx = selection.start_line, selection.end_line do
    if line_idx > pattern.number_of_lines then break end
    
    local source_row_idx = ((line_idx - selection.start_line) % clipboard_rows) + 1
    local row_data = data.rows[source_row_idx]
    
    if row_data then
      for track_offset, track_info in ipairs(selection_pro) do
        local track_idx = track_info.track_index
        if track_idx > #song.tracks then break end
        
        local track = song.tracks[track_idx]
        if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          local pattern_line = pattern.tracks[track_idx].lines[line_idx]
          
          local source_track_idx = ((track_offset - 1) % data.num_tracks) + 1
          local track_data = row_data[source_track_idx]
          
          if track_data then
            if track_data.note_columns then
              for _, col_idx in ipairs(track_info.note_columns) do
                if col_idx <= #pattern_line.note_columns then
                  local col_data = track_data.note_columns[col_idx]
                  if col_data then
                    write_note_column_data(pattern_line.note_columns[col_idx], col_data)
                  end
                end
              end
            end
            
            if track_data.effect_columns then
              for _, col_idx in ipairs(track_info.effect_columns) do
                if col_idx <= #pattern_line.effect_columns then
                  local col_data = track_data.effect_columns[col_idx]
                  if col_data then
                    write_effect_column_data(pattern_line.effect_columns[col_idx], col_data)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  
  return true
end

-- Swap clipboard with selection in Pattern Editor
local function swap_pattern_selection_with_clipboard(slot_index)
  local song = renoise.song()
  local selection = song.selection_in_pattern
  
  if not selection then
    renoise.app():show_status("Swap needs a selection in pattern.")
    return false
  end
  
  -- Load clipboard data
  local clipboard_data = load_clipboard_from_preferences(slot_index)
  
  if not clipboard_data or not clipboard_data.rows or #clipboard_data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty. Nothing to swap.")
    return false
  end
  
  -- Capture current selection
  local selection_data = capture_pattern_selection_data()
  
  if not selection_data then
    renoise.app():show_status("Failed to capture selection data.")
    return false
  end
  
  -- Paste clipboard to selection
  if not paste_data_to_pattern_selection(clipboard_data) then
    renoise.app():show_status("Failed to paste clipboard data.")
    return false
  end
  
  -- Save captured selection to clipboard
  save_clipboard_to_preferences(slot_index, selection_data)
  
  renoise.app():show_status(string.format("Swapped selection with Clipboard Slot %s (%d rows)", 
    format_slot_index(slot_index), selection_data.num_rows))
  
  return true
end

-- Swap clipboard with selection in Phrase Editor
local function swap_phrase_selection_with_clipboard(slot_index)
  local song = renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected.")
    return false
  end
  
  local selection = song.selection_in_phrase
  
  if not selection then
    renoise.app():show_status("Swap needs a selection in phrase.")
    return false
  end
  
  -- Load clipboard data
  local clipboard_data = load_clipboard_from_preferences(slot_index)
  
  if not clipboard_data or not clipboard_data.rows or #clipboard_data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty. Nothing to swap.")
    return false
  end
  
  -- Capture current phrase selection
  local selection_data = {
    source_type = "phrase",
    num_rows = selection.end_line - selection.start_line + 1,
    num_tracks = 1,
    track_info = {
      [1] = {
        num_note_columns = phrase.visible_note_columns,
        num_effect_columns = phrase.visible_effect_columns
      }
    },
    rows = {}
  }
  
  local start_col = selection.start_column
  local end_col = selection.end_column
  
  -- Capture phrase selection data
  for line_idx = selection.start_line, selection.end_line do
    local relative_row_idx = line_idx - selection.start_line + 1
    local phrase_line = phrase:line(line_idx)
    
    selection_data.rows[relative_row_idx] = {
      [1] = {
        note_columns = {},
        effect_columns = {}
      }
    }
    
    for col_idx = 1, phrase.visible_note_columns do
      if col_idx >= start_col and col_idx <= end_col then
        local note_column = phrase_line.note_columns[col_idx]
        selection_data.rows[relative_row_idx][1].note_columns[col_idx] = 
          copy_note_column_data(note_column)
      end
    end
    
    for col_idx = 1, phrase.visible_effect_columns do
      local absolute_col = phrase.visible_note_columns + col_idx
      if absolute_col >= start_col and absolute_col <= end_col then
        local effect_column = phrase_line.effect_columns[col_idx]
        selection_data.rows[relative_row_idx][1].effect_columns[col_idx] = 
          copy_effect_column_data(effect_column)
      end
    end
  end
  
  -- Paste clipboard to phrase selection
  local clipboard_rows = #clipboard_data.rows
  
  for line_idx = selection.start_line, selection.end_line do
    if line_idx > phrase.number_of_lines then break end
    
    local source_row_idx = ((line_idx - selection.start_line) % clipboard_rows) + 1
    local row_data = clipboard_data.rows[source_row_idx]
    
    if row_data and row_data[1] then
      local track_data = row_data[1]
      local phrase_line = phrase:line(line_idx)
      
      if track_data.note_columns then
        for col_idx, col_data in pairs(track_data.note_columns) do
          if col_idx <= phrase.visible_note_columns and
             col_idx >= start_col and col_idx <= end_col then
            write_note_column_data(phrase_line.note_columns[col_idx], col_data)
          end
        end
      end
      
      if track_data.effect_columns then
        for col_idx, col_data in pairs(track_data.effect_columns) do
          local absolute_col = phrase.visible_note_columns + col_idx
          if col_idx <= phrase.visible_effect_columns and
             absolute_col >= start_col and absolute_col <= end_col then
            write_effect_column_data(phrase_line.effect_columns[col_idx], col_data)
          end
        end
      end
    end
  end
  
  -- Save captured selection to clipboard
  save_clipboard_to_preferences(slot_index, selection_data)
  
  renoise.app():show_status(string.format("Swapped phrase selection with Clipboard Slot %s (%d rows)", 
    format_slot_index(slot_index), selection_data.num_rows))
  
  return true
end

-- Public Swap function (auto-detects editor)
function PakettiClipboardSwap(slot_index)
  local editor = get_active_editor()
  if editor == "phrase" then
    swap_phrase_selection_with_clipboard(slot_index)
  else
    swap_pattern_selection_with_clipboard(slot_index)
  end
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Quick Swap (default to Slot 01)
function PakettiClipboardQuickSwap()
  PakettiClipboardSwap(1)
end

--------------------------------------------------------------------------------
-- Export/Import Functions
-- Save and load clipboard slots to/from external files
--------------------------------------------------------------------------------

-- File extension for clipboard files
local CLIPBOARD_FILE_EXTENSION = "pclip"

-- Export a clipboard slot to a file
function PakettiClipboardExport(slot_index)
  local data = load_clipboard_from_preferences(slot_index)
  
  if not data or not data.rows or #data.rows == 0 then
    renoise.app():show_status("Clipboard Slot " .. format_slot_index(slot_index) .. " is empty. Nothing to export.")
    return false
  end
  
  local slot_name = get_slot_name(slot_index)
  local default_filename = slot_name ~= "" and slot_name or ("clipboard_slot_" .. format_slot_index(slot_index))
  default_filename = default_filename:gsub("[^%w%s%-_]", "")  -- Remove invalid filename chars
  
  local filename = renoise.app():prompt_for_filename_to_write(
    CLIPBOARD_FILE_EXTENSION,
    "Export Clipboard Slot " .. format_slot_index(slot_index)
  )
  
  if not filename or filename == "" then
    return false  -- User cancelled
  end
  
  -- Ensure proper extension
  if not filename:match("%." .. CLIPBOARD_FILE_EXTENSION .. "$") then
    filename = filename .. "." .. CLIPBOARD_FILE_EXTENSION
  end
  
  -- Serialize the data with metadata header
  local content = serialize_clipboard_data(data)
  
  -- Add metadata header
  local slot_name_safe = slot_name:gsub("\n", " ")
  local header = string.format("PAKETTI_CLIPBOARD_v1|%s|%s\n", 
    format_slot_index(slot_index),
    slot_name_safe)
  content = header .. content
  
  -- Write to file
  local file, err = io.open(filename, "w")
  if not file then
    renoise.app():show_status("Failed to create file: " .. (err or "unknown error"))
    return false
  end
  
  file:write(content)
  file:close()
  
  renoise.app():show_status("Exported Clipboard Slot " .. format_slot_index(slot_index) .. " to: " .. filename)
  return true
end

-- Import a clipboard slot from a file
function PakettiClipboardImport(slot_index)
  local filename = renoise.app():prompt_for_filename_to_read(
    {CLIPBOARD_FILE_EXTENSION},
    "Import to Clipboard Slot " .. format_slot_index(slot_index)
  )
  
  if not filename or filename == "" then
    return false  -- User cancelled
  end
  
  -- Read file
  local file, err = io.open(filename, "r")
  if not file then
    renoise.app():show_status("Failed to open file: " .. (err or "unknown error"))
    return false
  end
  
  local content = file:read("*all")
  file:close()
  
  if not content or content == "" then
    renoise.app():show_status("File is empty.")
    return false
  end
  
  -- Parse header
  local header_line, rest = content:match("^([^\n]+)\n(.+)$")
  
  if not header_line then
    renoise.app():show_status("Invalid clipboard file format.")
    return false
  end
  
  local version, orig_slot, orig_name = header_line:match("^PAKETTI_CLIPBOARD_v(%d+)|(%d+)|(.*)$")
  
  if not version then
    -- Try to parse as raw clipboard data (no header)
    rest = content
  end
  
  -- Deserialize the clipboard data
  local data = deserialize_clipboard_data(rest)
  
  if not data or not data.rows or #data.rows == 0 then
    renoise.app():show_status("Failed to parse clipboard data from file.")
    return false
  end
  
  -- Save to the target slot
  save_clipboard_to_preferences(slot_index, data)
  
  -- Optionally import the name if the target slot has no name
  if orig_name and orig_name ~= "" then
    local current_name = get_slot_name(slot_index)
    if current_name == "" then
      set_slot_name(slot_index, orig_name)
    end
  end
  
  renoise.app():show_status(string.format("Imported %d rows to Clipboard Slot %s from: %s", 
    data.num_rows, format_slot_index(slot_index), filename))
  
  return true
end

-- Export all non-empty slots to a folder
function PakettiClipboardExportAll()
  local folder = renoise.app():prompt_for_path("Select folder for clipboard export")
  
  if not folder or folder == "" then
    return false
  end
  
  local exported_count = 0
  
  for i = 1, NUM_CLIPBOARD_SLOTS do
    local data = load_clipboard_from_preferences(i)
    
    if data and data.rows and #data.rows > 0 then
      local slot_name = get_slot_name(i)
      local base_name = slot_name ~= "" and slot_name or ("slot_" .. format_slot_index(i))
      base_name = base_name:gsub("[^%w%s%-_]", "")
      
      local filename = folder .. "/" .. base_name .. "." .. CLIPBOARD_FILE_EXTENSION
      
      local content = serialize_clipboard_data(data)
      local slot_name_safe = slot_name:gsub("\n", " ")
      local header = string.format("PAKETTI_CLIPBOARD_v1|%s|%s\n", 
        format_slot_index(i),
        slot_name_safe)
      content = header .. content
      
      local file = io.open(filename, "w")
      if file then
        file:write(content)
        file:close()
        exported_count = exported_count + 1
      end
    end
  end
  
  renoise.app():show_status("Exported " .. exported_count .. " clipboard slots to folder.")
  return true
end

-- Quick export/import (default to Slot 01)
function PakettiClipboardQuickExport()
  PakettiClipboardExport(1)
end

function PakettiClipboardQuickImport()
  PakettiClipboardImport(1)
end

--------------------------------------------------------------------------------
-- Preview Functions
-- Display clipboard contents in human-readable format
--------------------------------------------------------------------------------

-- Convert note value to note string
local function note_value_to_string(value)
  if value == nil or value == 121 then
    return "---"
  elseif value == 120 then
    return "OFF"
  elseif value >= 0 and value <= 119 then
    local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
    local octave = math.floor(value / 12)
    local note = (value % 12) + 1
    return note_names[note] .. octave
  else
    return "???"
  end
end

-- Convert instrument value to string
local function instrument_value_to_string(value)
  if value == nil or value == 255 then
    return ".."
  else
    return string.format("%02X", value)
  end
end

-- Convert volume value to string
local function volume_value_to_string(value)
  if value == nil or value == 255 then
    return ".."
  else
    return string.format("%02X", value)
  end
end

-- Generate preview text for a clipboard slot
local function generate_clipboard_preview(slot_index, max_rows)
  max_rows = max_rows or 8
  
  local data = load_clipboard_from_preferences(slot_index)
  
  if not data or not data.rows or #data.rows == 0 then
    return "Slot " .. format_slot_index(slot_index) .. " is empty."
  end
  
  local lines = {}
  local slot_name = get_slot_name(slot_index)
  
  -- Header
  table.insert(lines, string.format("=== Slot %s: %s ===", 
    format_slot_index(slot_index),
    slot_name ~= "" and slot_name or "(no name)"))
  table.insert(lines, string.format("Source: %s | Rows: %d | Tracks: %d",
    data.source_type or "pattern",
    data.num_rows or 0,
    data.num_tracks or 1))
  table.insert(lines, "")
  
  -- Preview rows
  local rows_to_show = math.min(#data.rows, max_rows)
  
  for row_idx = 1, rows_to_show do
    local row_data = data.rows[row_idx]
    local row_line = string.format("%02d: ", row_idx)
    
    for track_idx = 1, data.num_tracks do
      local track_data = row_data[track_idx]
      
      if track_data then
        -- Show first note column
        if track_data.note_columns then
          local first_col = nil
          for col_idx, col_data in pairs(track_data.note_columns) do
            if not first_col or col_idx < first_col then
              first_col = col_idx
            end
          end
          
          if first_col and track_data.note_columns[first_col] then
            local col = track_data.note_columns[first_col]
            row_line = row_line .. string.format("%s %s %s ",
              note_value_to_string(col.note_value),
              instrument_value_to_string(col.instrument_value),
              volume_value_to_string(col.volume_value))
          else
            row_line = row_line .. "--- .. .. "
          end
        else
          row_line = row_line .. "--- .. .. "
        end
        
        if track_idx < data.num_tracks then
          row_line = row_line .. "| "
        end
      end
    end
    
    table.insert(lines, row_line)
  end
  
  -- Show truncation notice
  if #data.rows > max_rows then
    table.insert(lines, string.format("... and %d more rows", #data.rows - max_rows))
  end
  
  return table.concat(lines, "\n")
end

-- Preview dialog for a slot
function PakettiClipboardPreview(slot_index)
  local preview_text = generate_clipboard_preview(slot_index, 16)
  
  local vb_preview = renoise.ViewBuilder()
  
  local dialog_content = vb_preview:column{
    margin = 10,
    spacing = 5,
    
    vb_preview:multiline_text{
      text = preview_text,
      width = 400,
      height = 300,
      font = "mono"
    },
    
    vb_preview:row{
      vb_preview:button{
        text = "Close",
        width = 80,
        notifier = function()
          -- Dialog will close automatically
        end
      }
    }
  }
  
  renoise.app():show_custom_prompt(
    "Clipboard Preview - Slot " .. format_slot_index(slot_index),
    dialog_content,
    {"Close"}
  )
end

-- Quick preview (default to Slot 01)
function PakettiClipboardQuickPreview()
  PakettiClipboardPreview(1)
end

--------------------------------------------------------------------------------
-- Explicit Cross-Editor Functions
--------------------------------------------------------------------------------

-- Copy from Pattern Editor selection (forces pattern source regardless of active editor)
function PakettiClipboardCopyFromPattern(slot_index)
  copy_pattern_selection(slot_index, false)
end

-- Copy from Phrase Editor selection (forces phrase source regardless of active editor)
function PakettiClipboardCopyFromPhrase(slot_index)
  copy_phrase_selection(slot_index, false)
end

-- Paste to Pattern Editor (forces pattern target regardless of active editor)
function PakettiClipboardPasteToPattern(slot_index)
  paste_pattern_from_clipboard(slot_index)
end

-- Paste to Phrase Editor (forces phrase target regardless of active editor)
function PakettiClipboardPasteToPhrase(slot_index)
  paste_phrase_from_clipboard(slot_index)
end

-- Explicit Pattern to Phrase: Copy from pattern, then paste to phrase
-- This is a convenience function that switches editors
function PakettiClipboardPatternToPhrase(slot_index)
  local song = renoise.song()
  
  -- First, copy from pattern (if there's a selection)
  local selection = song.selection_in_pattern
  if selection then
    copy_pattern_selection(slot_index, false)
  else
    -- Check if clipboard already has data
    local data = load_clipboard_from_preferences(slot_index)
    if not data or not data.rows or #data.rows == 0 then
      renoise.app():show_status("No selection in pattern and Clipboard Slot " .. format_slot_index(slot_index) .. " is empty.")
      return
    end
  end
  
  -- Check if we have a phrase to paste to
  local phrase = song.selected_phrase
  if not phrase then
    renoise.app():show_status("No phrase selected. Create or select a phrase first.")
    return
  end
  
  -- Switch to phrase editor and paste
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
  paste_phrase_from_clipboard(slot_index)
end

-- Explicit Phrase to Pattern: Copy from phrase, then paste to pattern
-- This is a convenience function that switches editors
function PakettiClipboardPhraseToPattern(slot_index)
  local song = renoise.song()
  
  -- First, copy from phrase (if there's a selection)
  local phrase = song.selected_phrase
  if phrase then
    local selection = song.selection_in_phrase
    if selection then
      copy_phrase_selection(slot_index, false)
    else
      -- Check if clipboard already has data
      local data = load_clipboard_from_preferences(slot_index)
      if not data or not data.rows or #data.rows == 0 then
        renoise.app():show_status("No selection in phrase and Clipboard Slot " .. format_slot_index(slot_index) .. " is empty.")
        return
      end
    end
  else
    -- No phrase, check if clipboard has data
    local data = load_clipboard_from_preferences(slot_index)
    if not data or not data.rows or #data.rows == 0 then
      renoise.app():show_status("No phrase selected and Clipboard Slot " .. format_slot_index(slot_index) .. " is empty.")
      return
    end
  end
  
  -- Switch to pattern editor and paste
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  paste_pattern_from_clipboard(slot_index)
end

--------------------------------------------------------------------------------
-- Dialog GUI
--------------------------------------------------------------------------------

-- Helper function to update slot info display
local function update_slot_info_display(vb_ref, slot_index)
  local data = load_clipboard_from_preferences(slot_index)
  local slot_name = get_slot_name(slot_index)
  local info_text
  
  if data and data.rows and #data.rows > 0 then
    info_text = string.format("%s: %d rows, %d tracks", 
      data.source_type or "pattern",
      data.num_rows or 0,
      data.num_tracks or 1)
  else
    info_text = "Empty"
  end
  
  if vb_ref.views["clipboard_info_" .. slot_index] then
    vb_ref.views["clipboard_info_" .. slot_index].text = info_text
  end
end

function PakettiClipboardDialog()
  if clipboard_dialog and clipboard_dialog.visible then
    clipboard_dialog:close()
    clipboard_dialog = nil
    return
  end
  
  vb = renoise.ViewBuilder()
  
  -- Selected slot for wonked paste and transpose operations
  local selected_slot = 1
  
  -- Wonked paste presets names for popup
  local wonked_presets = {
    "Subtle Humanize",
    "Drunk Groove", 
    "Lo-Fi Grit",
    "Glitchy",
    "Chaos",
    "Jazz Feel",
    "Machine Tight"
  }
  
  local rows = {}
  
  for i = 1, NUM_CLIPBOARD_SLOTS do
    local slot_data = load_clipboard_from_preferences(i)
    local slot_name = get_slot_name(i)
    local slot_info = "Empty"
    
    if slot_data and slot_data.rows and #slot_data.rows > 0 then
      slot_info = string.format("%s: %d rows, %d tracks", 
        slot_data.source_type or "pattern",
        slot_data.num_rows or 0,
        slot_data.num_tracks or 1)
    end
    
    local slot_idx = i  -- Capture for closures
    
    rows[#rows + 1] = vb:row{
      spacing = 2,
      
      -- Slot number
      vb:text{
        text = format_slot_index(i),
        width = 20,
        font = "bold"
      },
      
      -- Editable slot name
      vb:textfield{
        id = "clipboard_name_" .. i,
        text = slot_name,
        width = 100,
        notifier = function(text)
          set_slot_name(slot_idx, text)
        end
      },
      
      vb:button{
        text = "Copy",
        width = 45,
        notifier = function()
          PakettiClipboardCopy(slot_idx)
          update_slot_info_display(vb, slot_idx)
        end
      },
      vb:button{
        text = "Cut",
        width = 40,
        notifier = function()
          PakettiClipboardCut(slot_idx)
          update_slot_info_display(vb, slot_idx)
        end
      },
      vb:button{
        text = "Paste",
        width = 50,
        notifier = function()
          PakettiClipboardPaste(slot_idx)
        end
      },
      vb:button{
        text = "Flood",
        width = 45,
        notifier = function()
          PakettiClipboardFloodFill(slot_idx)
        end
      },
      vb:button{
        text = "Mix",
        width = 40,
        notifier = function()
          PakettiClipboardMixPaste(slot_idx)
        end
      },
      vb:text{
        id = "clipboard_info_" .. i,
        text = slot_info,
        width = 120
      },
      vb:button{
        text = "Swap",
        width = 40,
        notifier = function()
          PakettiClipboardSwap(slot_idx)
          update_slot_info_display(vb, slot_idx)
        end
      },
      vb:button{
        text = "X",
        width = 25,
        notifier = function()
          PakettiClipboardClear(slot_idx)
          vb.views["clipboard_info_" .. slot_idx].text = "Empty"
        end
      }
    }
  end
  
  local dialog_content = vb:column{
    margin = 5,
    spacing = 3,
    
    -- Header row
    vb:row{
      vb:button{
        text = "Replicate Into Selection",
        width = 160,
        notifier = function()
          PakettiClipboardReplicateIntoSelection()
        end
      },
      vb:text{
        text = "(Uses content above selection)",
        font = "italic"
      }
    },
    
    vb:space{height = 5},
    
    -- Slots table
    vb:column(rows),
    
    vb:space{height = 8},
    
    -- Wonked Paste section
    vb:row{
      vb:text{
        text = "Wonked Paste:",
        font = "bold",
        width = 90
      },
      vb:popup{
        id = "wonked_slot_selector",
        items = {"Slot 01", "Slot 02", "Slot 03", "Slot 04", "Slot 05", 
                 "Slot 06", "Slot 07", "Slot 08", "Slot 09", "Slot 10"},
        value = 1,
        width = 70,
        notifier = function(index)
          selected_slot = index
        end
      },
      vb:popup{
        id = "wonked_preset_selector",
        items = wonked_presets,
        value = 1,
        width = 110
      },
      vb:button{
        text = "Paste Wonked",
        width = 90,
        notifier = function()
          local preset = vb.views.wonked_preset_selector.value
          local slot = vb.views.wonked_slot_selector.value
          PakettiClipboardWonkedPaste(slot, preset)
        end
      }
    },
    
    -- Transpose section
    vb:row{
      vb:text{
        text = "Transpose Paste:",
        font = "bold",
        width = 90
      },
      vb:popup{
        id = "transpose_slot_selector",
        items = {"Slot 01", "Slot 02", "Slot 03", "Slot 04", "Slot 05", 
                 "Slot 06", "Slot 07", "Slot 08", "Slot 09", "Slot 10"},
        value = 1,
        width = 70
      },
      vb:button{
        text = "-12",
        width = 35,
        notifier = function()
          local slot = vb.views.transpose_slot_selector.value
          PakettiClipboardTransposedPaste(slot, -12)
        end
      },
      vb:button{
        text = "-7",
        width = 30,
        notifier = function()
          local slot = vb.views.transpose_slot_selector.value
          PakettiClipboardTransposedPaste(slot, -7)
        end
      },
      vb:button{
        text = "-1",
        width = 30,
        notifier = function()
          local slot = vb.views.transpose_slot_selector.value
          PakettiClipboardTransposedPaste(slot, -1)
        end
      },
      vb:button{
        text = "+1",
        width = 30,
        notifier = function()
          local slot = vb.views.transpose_slot_selector.value
          PakettiClipboardTransposedPaste(slot, 1)
        end
      },
      vb:button{
        text = "+7",
        width = 30,
        notifier = function()
          local slot = vb.views.transpose_slot_selector.value
          PakettiClipboardTransposedPaste(slot, 7)
        end
      },
      vb:button{
        text = "+12",
        width = 35,
        notifier = function()
          local slot = vb.views.transpose_slot_selector.value
          PakettiClipboardTransposedPaste(slot, 12)
        end
      }
    },
    
    vb:space{height = 5},
    
    -- Export/Import section
    vb:row{
      vb:text{
        text = "Export/Import:",
        font = "bold",
        width = 90
      },
      vb:popup{
        id = "export_slot_selector",
        items = {"Slot 01", "Slot 02", "Slot 03", "Slot 04", "Slot 05", 
                 "Slot 06", "Slot 07", "Slot 08", "Slot 09", "Slot 10"},
        value = 1,
        width = 70
      },
      vb:button{
        text = "Export",
        width = 55,
        notifier = function()
          local slot = vb.views.export_slot_selector.value
          PakettiClipboardExport(slot)
        end
      },
      vb:button{
        text = "Import",
        width = 55,
        notifier = function()
          local slot = vb.views.export_slot_selector.value
          PakettiClipboardImport(slot)
          update_slot_info_display(vb, slot)
        end
      },
      vb:button{
        text = "Export All",
        width = 70,
        notifier = function()
          PakettiClipboardExportAll()
        end
      }
    },
    
    -- Preview section
    vb:row{
      vb:text{
        text = "Preview:",
        font = "bold",
        width = 90
      },
      vb:popup{
        id = "preview_slot_selector",
        items = {"Slot 01", "Slot 02", "Slot 03", "Slot 04", "Slot 05", 
                 "Slot 06", "Slot 07", "Slot 08", "Slot 09", "Slot 10"},
        value = 1,
        width = 70
      },
      vb:button{
        text = "Preview Slot",
        width = 80,
        notifier = function()
          local slot = vb.views.preview_slot_selector.value
          PakettiClipboardPreview(slot)
        end
      }
    }
  }
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return clipboard_dialog end,
    function(value) clipboard_dialog = value end
  )
  
  clipboard_dialog = renoise.app():show_custom_dialog(
    "Paketti Clipboard", 
    dialog_content, 
    keyhandler
  )
end

--------------------------------------------------------------------------------
-- Keybindings
--------------------------------------------------------------------------------

-- Dialog
renoise.tool():add_keybinding{
  name = "Global:Paketti:Clipboard Dialog...",
  invoke = PakettiClipboardDialog
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Dialog...",
  invoke = PakettiClipboardDialog
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Dialog...",
  invoke = PakettiClipboardDialog
}

-- Replicate Into Selection
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Replicate Into Selection",
  invoke = PakettiClipboardReplicateIntoSelection
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Replicate Into Selection",
  invoke = PakettiClipboardReplicateIntoSelection
}

-- Quick Operations (default to Slot 01)
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Copy",
  invoke = PakettiClipboardQuickCopy
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Cut",
  invoke = PakettiClipboardQuickCut
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste",
  invoke = PakettiClipboardQuickPaste
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Mix-Paste",
  invoke = PakettiClipboardQuickMixPaste
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Flood Fill",
  invoke = PakettiClipboardQuickFloodFill
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Copy",
  invoke = PakettiClipboardQuickCopy
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Cut",
  invoke = PakettiClipboardQuickCut
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Paste",
  invoke = PakettiClipboardQuickPaste
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Mix-Paste",
  invoke = PakettiClipboardQuickMixPaste
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Flood Fill",
  invoke = PakettiClipboardQuickFloodFill
}

-- Quick Wonked Paste keybindings (Pattern Editor)
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Humanized",
  invoke = PakettiClipboardQuickPasteHumanized
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Drunk",
  invoke = PakettiClipboardQuickPasteDrunk
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Lo-Fi",
  invoke = PakettiClipboardQuickPasteLoFi
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Glitchy",
  invoke = PakettiClipboardQuickPasteGlitchy
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Chaos",
  invoke = PakettiClipboardQuickPasteChaos
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Jazz",
  invoke = PakettiClipboardQuickPasteJazz
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Tight",
  invoke = PakettiClipboardQuickPasteTight
}

-- Quick Wonked Paste keybindings (Phrase Editor)
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Paste Humanized",
  invoke = PakettiClipboardQuickPasteHumanized
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Paste Drunk",
  invoke = PakettiClipboardQuickPasteDrunk
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Paste Lo-Fi",
  invoke = PakettiClipboardQuickPasteLoFi
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Paste Glitchy",
  invoke = PakettiClipboardQuickPasteGlitchy
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Paste Chaos",
  invoke = PakettiClipboardQuickPasteChaos
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Paste Jazz",
  invoke = PakettiClipboardQuickPasteJazz
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Paste Tight",
  invoke = PakettiClipboardQuickPasteTight
}

-- Quick Transpose Paste keybindings (Pattern Editor)
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Transpose +1",
  invoke = PakettiClipboardQuickPasteTransposeUp1
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Transpose -1",
  invoke = PakettiClipboardQuickPasteTransposeDown1
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Transpose +12 (Octave Up)",
  invoke = PakettiClipboardQuickPasteTransposeUp12
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Transpose -12 (Octave Down)",
  invoke = PakettiClipboardQuickPasteTransposeDown12
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Transpose +7 (Fifth Up)",
  invoke = PakettiClipboardQuickPasteTransposeUp7
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Transpose -7 (Fifth Down)",
  invoke = PakettiClipboardQuickPasteTransposeDown7
}

-- Quick Transpose Paste keybindings (Phrase Editor)
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Paste Transpose +1",
  invoke = PakettiClipboardQuickPasteTransposeUp1
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Paste Transpose -1",
  invoke = PakettiClipboardQuickPasteTransposeDown1
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Paste Transpose +12 (Octave Up)",
  invoke = PakettiClipboardQuickPasteTransposeUp12
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Paste Transpose -12 (Octave Down)",
  invoke = PakettiClipboardQuickPasteTransposeDown12
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Paste Transpose +7 (Fifth Up)",
  invoke = PakettiClipboardQuickPasteTransposeUp7
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Paste Transpose -7 (Fifth Down)",
  invoke = PakettiClipboardQuickPasteTransposeDown7
}

-- Partial Copy/Paste keybindings (Pattern Editor)
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Copy Notes Only",
  invoke = PakettiClipboardQuickCopyNotesOnly
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Cut Notes Only",
  invoke = PakettiClipboardQuickCutNotesOnly
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Copy Effects Only",
  invoke = PakettiClipboardQuickCopyEffectsOnly
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Cut Effects Only",
  invoke = PakettiClipboardQuickCutEffectsOnly
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Notes Only",
  invoke = PakettiClipboardQuickPasteNotesOnly
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Paste Effects Only",
  invoke = PakettiClipboardQuickPasteEffectsOnly
}

-- Swap keybindings
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Clipboard Quick Swap",
  invoke = PakettiClipboardQuickSwap
}
renoise.tool():add_keybinding{
  name = "Phrase Editor:Paketti:Clipboard Quick Swap",
  invoke = PakettiClipboardQuickSwap
}

-- Export/Import keybindings
renoise.tool():add_keybinding{
  name = "Global:Paketti:Clipboard Quick Export",
  invoke = PakettiClipboardQuickExport
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Clipboard Quick Import",
  invoke = PakettiClipboardQuickImport
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Clipboard Export All",
  invoke = PakettiClipboardExportAll
}

-- Preview keybindings
renoise.tool():add_keybinding{
  name = "Global:Paketti:Clipboard Quick Preview",
  invoke = PakettiClipboardQuickPreview
}

-- Per-slot keybindings
for i = 1, NUM_CLIPBOARD_SLOTS do
  local slot_str = format_slot_index(i)
  
  -- Pattern Editor
  renoise.tool():add_keybinding{
    name = "Pattern Editor:Paketti:Clipboard Copy to Slot " .. slot_str,
    invoke = function() PakettiClipboardCopy(i) end
  }
  renoise.tool():add_keybinding{
    name = "Pattern Editor:Paketti:Clipboard Cut to Slot " .. slot_str,
    invoke = function() PakettiClipboardCut(i) end
  }
  renoise.tool():add_keybinding{
    name = "Pattern Editor:Paketti:Clipboard Paste from Slot " .. slot_str,
    invoke = function() PakettiClipboardPaste(i) end
  }
  renoise.tool():add_keybinding{
    name = "Pattern Editor:Paketti:Clipboard Flood Fill from Slot " .. slot_str,
    invoke = function() PakettiClipboardFloodFill(i) end
  }
  renoise.tool():add_keybinding{
    name = "Pattern Editor:Paketti:Clipboard Mix-Paste from Slot " .. slot_str,
    invoke = function() PakettiClipboardMixPaste(i) end
  }
  
  -- Phrase Editor
  renoise.tool():add_keybinding{
    name = "Phrase Editor:Paketti:Clipboard Copy to Slot " .. slot_str,
    invoke = function() PakettiClipboardCopy(i) end
  }
  renoise.tool():add_keybinding{
    name = "Phrase Editor:Paketti:Clipboard Cut to Slot " .. slot_str,
    invoke = function() PakettiClipboardCut(i) end
  }
  renoise.tool():add_keybinding{
    name = "Phrase Editor:Paketti:Clipboard Paste from Slot " .. slot_str,
    invoke = function() PakettiClipboardPaste(i) end
  }
  renoise.tool():add_keybinding{
    name = "Phrase Editor:Paketti:Clipboard Flood Fill from Slot " .. slot_str,
    invoke = function() PakettiClipboardFloodFill(i) end
  }
  renoise.tool():add_keybinding{
    name = "Phrase Editor:Paketti:Clipboard Mix-Paste from Slot " .. slot_str,
    invoke = function() PakettiClipboardMixPaste(i) end
  }
  
  -- Swap Operations
  renoise.tool():add_keybinding{
    name = "Pattern Editor:Paketti:Clipboard Swap with Slot " .. slot_str,
    invoke = function() PakettiClipboardSwap(i) end
  }
  renoise.tool():add_keybinding{
    name = "Phrase Editor:Paketti:Clipboard Swap with Slot " .. slot_str,
    invoke = function() PakettiClipboardSwap(i) end
  }
  
  -- Cross-Editor Operations
  -- Pattern to Phrase
  renoise.tool():add_keybinding{
    name = "Pattern Editor:Paketti:Clipboard Pattern to Phrase Slot " .. slot_str,
    invoke = function() PakettiClipboardPatternToPhrase(i) end
  }
  renoise.tool():add_keybinding{
    name = "Phrase Editor:Paketti:Clipboard Paste from Pattern Slot " .. slot_str,
    invoke = function() PakettiClipboardPasteToPhrase(i) end
  }
  
  -- Phrase to Pattern
  renoise.tool():add_keybinding{
    name = "Phrase Editor:Paketti:Clipboard Phrase to Pattern Slot " .. slot_str,
    invoke = function() PakettiClipboardPhraseToPattern(i) end
  }
  renoise.tool():add_keybinding{
    name = "Pattern Editor:Paketti:Clipboard Paste from Phrase Slot " .. slot_str,
    invoke = function() PakettiClipboardPasteToPattern(i) end
  }
end

--------------------------------------------------------------------------------
-- MIDI Mappings
--------------------------------------------------------------------------------

-- Replicate Into Selection
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Replicate Into Selection",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardReplicateIntoSelection()
    end
  end
}

-- Quick Operations (default to Slot 01)
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Copy",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickCopy()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Cut",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickCut()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPaste()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Mix-Paste",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickMixPaste()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Flood Fill",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickFloodFill()
    end
  end
}

-- Quick Wonked Paste MIDI mappings
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Humanized",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteHumanized()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Drunk",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteDrunk()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Lo-Fi",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteLoFi()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Glitchy",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteGlitchy()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Chaos",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteChaos()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Jazz",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteJazz()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Tight",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteTight()
    end
  end
}

-- Quick Transpose Paste MIDI mappings
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Transpose +1",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteTransposeUp1()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Transpose -1",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteTransposeDown1()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Transpose +12 (Octave Up)",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteTransposeUp12()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Transpose -12 (Octave Down)",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteTransposeDown12()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Transpose +7 (Fifth Up)",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteTransposeUp7()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Transpose -7 (Fifth Down)",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteTransposeDown7()
    end
  end
}

-- Partial Copy/Paste MIDI mappings
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Copy Notes Only",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickCopyNotesOnly()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Cut Notes Only",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickCutNotesOnly()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Copy Effects Only",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickCopyEffectsOnly()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Cut Effects Only",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickCutEffectsOnly()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Notes Only",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteNotesOnly()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Paste Effects Only",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPasteEffectsOnly()
    end
  end
}

-- Swap MIDI mapping
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Swap",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickSwap()
    end
  end
}

-- Export/Import MIDI mappings
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Export",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickExport()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Import",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickImport()
    end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Export All",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardExportAll()
    end
  end
}

-- Preview MIDI mapping
renoise.tool():add_midi_mapping{
  name = "Paketti:Clipboard Quick Preview",
  invoke = function(message)
    if message:is_trigger() then
      PakettiClipboardQuickPreview()
    end
  end
}

-- Per-slot MIDI mappings
for i = 1, NUM_CLIPBOARD_SLOTS do
  local slot_str = format_slot_index(i)
  
  renoise.tool():add_midi_mapping{
    name = "Paketti:Clipboard Copy to Slot " .. slot_str,
    invoke = function(message)
      if message:is_trigger() then
        PakettiClipboardCopy(i)
      end
    end
  }
  
  renoise.tool():add_midi_mapping{
    name = "Paketti:Clipboard Cut to Slot " .. slot_str,
    invoke = function(message)
      if message:is_trigger() then
        PakettiClipboardCut(i)
      end
    end
  }
  
  renoise.tool():add_midi_mapping{
    name = "Paketti:Clipboard Paste from Slot " .. slot_str,
    invoke = function(message)
      if message:is_trigger() then
        PakettiClipboardPaste(i)
      end
    end
  }
  
  renoise.tool():add_midi_mapping{
    name = "Paketti:Clipboard Flood Fill from Slot " .. slot_str,
    invoke = function(message)
      if message:is_trigger() then
        PakettiClipboardFloodFill(i)
      end
    end
  }
  
  renoise.tool():add_midi_mapping{
    name = "Paketti:Clipboard Mix-Paste from Slot " .. slot_str,
    invoke = function(message)
      if message:is_trigger() then
        PakettiClipboardMixPaste(i)
      end
    end
  }
  
  renoise.tool():add_midi_mapping{
    name = "Paketti:Clipboard Swap with Slot " .. slot_str,
    invoke = function(message)
      if message:is_trigger() then
        PakettiClipboardSwap(i)
      end
    end
  }
  
  -- Cross-Editor MIDI Mappings
  renoise.tool():add_midi_mapping{
    name = "Paketti:Clipboard Pattern to Phrase Slot " .. slot_str,
    invoke = function(message)
      if message:is_trigger() then
        PakettiClipboardPatternToPhrase(i)
      end
    end
  }
  
  renoise.tool():add_midi_mapping{
    name = "Paketti:Clipboard Phrase to Pattern Slot " .. slot_str,
    invoke = function(message)
      if message:is_trigger() then
        PakettiClipboardPhraseToPattern(i)
      end
    end
  }
  
  renoise.tool():add_midi_mapping{
    name = "Paketti:Clipboard Paste to Phrase from Slot " .. slot_str,
    invoke = function(message)
      if message:is_trigger() then
        PakettiClipboardPasteToPhrase(i)
      end
    end
  }
  
  renoise.tool():add_midi_mapping{
    name = "Paketti:Clipboard Paste to Pattern from Slot " .. slot_str,
    invoke = function(message)
      if message:is_trigger() then
        PakettiClipboardPasteToPattern(i)
      end
    end
  }
end

--------------------------------------------------------------------------------
-- Menu Entries
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Clipboard Dialog...",
  invoke = PakettiClipboardDialog
}

renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Replicate Into Selection",
  invoke = PakettiClipboardReplicateIntoSelection
}

-- Quick Operations menu entries
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Quick Copy (Slot 01)",
  invoke = PakettiClipboardQuickCopy
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Quick Cut (Slot 01)",
  invoke = PakettiClipboardQuickCut
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Quick Paste (Slot 01)",
  invoke = PakettiClipboardQuickPaste
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Quick Mix-Paste (Slot 01)",
  invoke = PakettiClipboardQuickMixPaste
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Quick Flood Fill (Slot 01)",
  invoke = PakettiClipboardQuickFloodFill
}

-- Quick Wonked Paste menu entries
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Wonked Paste:Quick Paste Humanized (Slot 01)",
  invoke = PakettiClipboardQuickPasteHumanized
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Wonked Paste:Quick Paste Drunk (Slot 01)",
  invoke = PakettiClipboardQuickPasteDrunk
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Wonked Paste:Quick Paste Lo-Fi (Slot 01)",
  invoke = PakettiClipboardQuickPasteLoFi
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Wonked Paste:Quick Paste Glitchy (Slot 01)",
  invoke = PakettiClipboardQuickPasteGlitchy
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Wonked Paste:Quick Paste Chaos (Slot 01)",
  invoke = PakettiClipboardQuickPasteChaos
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Wonked Paste:Quick Paste Jazz (Slot 01)",
  invoke = PakettiClipboardQuickPasteJazz
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Wonked Paste:Quick Paste Tight (Slot 01)",
  invoke = PakettiClipboardQuickPasteTight
}

-- Transpose Paste menu entries
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Transpose Paste:Quick Paste +1 Semitone (Slot 01)",
  invoke = PakettiClipboardQuickPasteTransposeUp1
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Transpose Paste:Quick Paste -1 Semitone (Slot 01)",
  invoke = PakettiClipboardQuickPasteTransposeDown1
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Transpose Paste:Quick Paste +12 Octave Up (Slot 01)",
  invoke = PakettiClipboardQuickPasteTransposeUp12
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Transpose Paste:Quick Paste -12 Octave Down (Slot 01)",
  invoke = PakettiClipboardQuickPasteTransposeDown12
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Transpose Paste:Quick Paste +7 Fifth Up (Slot 01)",
  invoke = PakettiClipboardQuickPasteTransposeUp7
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Transpose Paste:Quick Paste -7 Fifth Down (Slot 01)",
  invoke = PakettiClipboardQuickPasteTransposeDown7
}

-- Partial Copy/Paste menu entries
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Partial:Quick Copy Notes Only (Slot 01)",
  invoke = PakettiClipboardQuickCopyNotesOnly
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Partial:Quick Cut Notes Only (Slot 01)",
  invoke = PakettiClipboardQuickCutNotesOnly
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Partial:Quick Paste Notes Only (Slot 01)",
  invoke = PakettiClipboardQuickPasteNotesOnly
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Partial:Quick Copy Effects Only (Slot 01)",
  invoke = PakettiClipboardQuickCopyEffectsOnly
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Partial:Quick Cut Effects Only (Slot 01)",
  invoke = PakettiClipboardQuickCutEffectsOnly
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Partial:Quick Paste Effects Only (Slot 01)",
  invoke = PakettiClipboardQuickPasteEffectsOnly
}

-- Swap menu entry
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Quick Swap (Slot 01)",
  invoke = PakettiClipboardQuickSwap
}

-- Export/Import menu entries
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Export/Import:Quick Export (Slot 01)",
  invoke = PakettiClipboardQuickExport
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Export/Import:Quick Import (Slot 01)",
  invoke = PakettiClipboardQuickImport
}
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Export/Import:Export All Slots",
  invoke = PakettiClipboardExportAll
}

-- Preview menu entry
renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Clipboard:Quick Preview (Slot 01)",
  invoke = PakettiClipboardQuickPreview
}

for i = 1, NUM_CLIPBOARD_SLOTS do
  local slot_str = format_slot_index(i)
  
  renoise.tool():add_menu_entry{
    name = "Pattern Editor:Paketti:Clipboard:Copy to Slot " .. slot_str,
    invoke = function() PakettiClipboardCopy(i) end
  }
  renoise.tool():add_menu_entry{
    name = "Pattern Editor:Paketti:Clipboard:Cut to Slot " .. slot_str,
    invoke = function() PakettiClipboardCut(i) end
  }
  renoise.tool():add_menu_entry{
    name = "Pattern Editor:Paketti:Clipboard:Paste from Slot " .. slot_str,
    invoke = function() PakettiClipboardPaste(i) end
  }
  renoise.tool():add_menu_entry{
    name = "Pattern Editor:Paketti:Clipboard:Flood Fill from Slot " .. slot_str,
    invoke = function() PakettiClipboardFloodFill(i) end
  }
  renoise.tool():add_menu_entry{
    name = "Pattern Editor:Paketti:Clipboard:Mix-Paste from Slot " .. slot_str,
    invoke = function() PakettiClipboardMixPaste(i) end
  }
  renoise.tool():add_menu_entry{
    name = "Pattern Editor:Paketti:Clipboard:Swap with Slot " .. slot_str,
    invoke = function() PakettiClipboardSwap(i) end
  }
  
  -- Cross-Editor Menu Entries
  renoise.tool():add_menu_entry{
    name = "Pattern Editor:Paketti:Clipboard:Cross-Editor:Pattern to Phrase Slot " .. slot_str,
    invoke = function() PakettiClipboardPatternToPhrase(i) end
  }
  renoise.tool():add_menu_entry{
    name = "Pattern Editor:Paketti:Clipboard:Cross-Editor:Paste from Phrase Slot " .. slot_str,
    invoke = function() PakettiClipboardPasteToPattern(i) end
  }
end

