-- PakettiPatternDelayViewer.lua
-- Visual viewer for notes and delay values across multiple patterns
-- Shows patterns side-by-side for easy delay value comparison and standardization
--
-- FEATURES:
-- 1. Shows up to 4 patterns side-by-side from the pattern sequence
-- 2. Displays only lines with notes (compact view)
-- 3. Shows note name and delay value in hexadecimal (e.g., "C-4:A3")
-- 4. Color codes buttons by delay range:
--    - Black: No delay (00)
--    - Yellow: Low delay (01-40)
--    - Orange: Mid delay (41-80)
--    - Red: High delay (81-FF)
-- 5. Click any note to jump to that position in pattern editor
-- 6. Shows statistics of delay values used across all patterns
-- 7. Auto-refreshes when changing tracks or sequence position
--
-- UTILITY FUNCTIONS:
-- - Copy Delay to All Same Notes: Takes the delay from selected note and applies it to all instances of that note in the track
-- - Set Delay for All Same Notes: Prompts for a delay value and applies it to all instances of that note in the track
--
-- USAGE:
-- 1. Open the Pattern Delay Viewer dialog
-- 2. View your melodic patterns with their delay values
-- 3. Click notes to jump to them in the pattern editor
-- 4. Use the utility functions to standardize delay values across patterns

local vb = renoise.ViewBuilder()
local dialog = nil
local dialog_content = nil
local pattern_data_cache = {}
local notifiers = {}
local button_registry = {}  -- Track all buttons for keyboard navigation
local selected_button_index = 0  -- Currently selected button for keyboard nav

-- Color palette for notes (12 colors for 12 notes in octave)
local note_colors = {
  ["C"] = {0x30, 0x30, 0x50},
  ["C#"] = {0x40, 0x30, 0x50},
  ["D"] = {0x50, 0x30, 0x40},
  ["D#"] = {0x50, 0x30, 0x30},
  ["E"] = {0x50, 0x40, 0x30},
  ["F"] = {0x50, 0x50, 0x30},
  ["F#"] = {0x40, 0x50, 0x30},
  ["G"] = {0x30, 0x50, 0x30},
  ["G#"] = {0x30, 0x50, 0x40},
  ["A"] = {0x30, 0x50, 0x50},
  ["A#"] = {0x30, 0x40, 0x50},
  ["B"] = {0x30, 0x30, 0x50},
  ["OFF"] = {0x20, 0x20, 0x20}  -- Dark gray for all OFF notes
}

------------------------------------------------------------------------------
-- Data Gathering Functions
------------------------------------------------------------------------------

function PakettiPatternDelayViewerGatherPatternData()
  local song = renoise.song()
  local selected_track = song.selected_track_index
  local pattern_sequence = song.sequencer.pattern_sequence
  
  pattern_data_cache = {}
  
  -- Gather data from all patterns in sequence
  for seq_index = 1, #pattern_sequence do
    local pattern_index = pattern_sequence[seq_index]
    local pattern = song:pattern(pattern_index)
    local track = pattern:track(selected_track)
    local visible_note_columns = song.tracks[selected_track].visible_note_columns
    
    local pattern_info = {
      sequence_index = seq_index,
      pattern_index = pattern_index,
      num_lines = pattern.number_of_lines,
      columns = {}
    }
    
    -- Gather data for each visible note column
    for col = 1, visible_note_columns do
      local column_data = {}
      
      for line_index = 1, pattern.number_of_lines do
        local line = track:line(line_index)
        local note_col = line.note_columns[col]
        
        local line_info = {
          line = line_index,
          note_string = note_col.note_string,
          instrument = note_col.instrument_value,
          delay = note_col.delay_value,
          is_empty = note_col.is_empty
        }
        
        table.insert(column_data, line_info)
      end
      
      table.insert(pattern_info.columns, column_data)
    end
    
    table.insert(pattern_data_cache, pattern_info)
  end
end

------------------------------------------------------------------------------
-- UI Building Functions
------------------------------------------------------------------------------

function PakettiPatternDelayViewerJumpToPosition(seq_index, line_index, column_index)
  local song = renoise.song()
  song.selected_sequence_index = seq_index
  song.selected_line_index = line_index
  song.selected_note_column_index = column_index
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

function PakettiPatternDelayViewerBuildPatternColumn(pattern_info, column_index, max_patterns_to_show)
  local col_views = {}
  
  -- Pattern header with sequence and pattern number
  table.insert(col_views, vb:text {
    text = string.format("S%02d:P%02d", pattern_info.sequence_index, pattern_info.pattern_index),
    font = "bold",
    width = 80
  })
  
  -- Column headers for this pattern (compact)
  local column_header_views = {
    vb:text { text = "", width = 18 }  -- Line number spacer
  }
  for col = 1, #pattern_info.columns do
    table.insert(column_header_views, vb:text {
      text = string.format("C%d", col),
      font = "bold",
      width = 48,
      style = "strong",
      align = "center"
    })
  end
  table.insert(col_views, vb:row { views = column_header_views })
  
  -- Only show lines that have data (non-empty notes)
  local lines_with_data = {}
  for line_index = 1, pattern_info.num_lines do
    local has_data = false
    for col = 1, #pattern_info.columns do
      if not pattern_info.columns[col][line_index].is_empty then
        has_data = true
        break
      end
    end
    if has_data then
      table.insert(lines_with_data, line_index)
    end
  end
  
  -- Show only lines with notes (more compact)
  for _, line_index in ipairs(lines_with_data) do
    local line_row_views = {}
    
    -- Line number indicator
    table.insert(line_row_views, vb:text {
      text = string.format("%02d:", line_index - 1),
      width = 18,
      font = "mono"
    })
    
    for col = 1, #pattern_info.columns do
      local line_info = pattern_info.columns[col][line_index]
      
      local display_text = ""
      local button_color = {0x00, 0x00, 0x00}
      
      if not line_info.is_empty then
        local delay_hex = string.format("%02X", line_info.delay)
        display_text = string.format("%s:%s", line_info.note_string, delay_hex)
        
        -- Color by note name (first 1-2 chars before dash/number)
        local note_name = line_info.note_string:match("^([A-G]#?)") or line_info.note_string:match("^(OFF)")
        if note_name and note_colors[note_name] then
          button_color = note_colors[note_name]
        end
      else
        display_text = "  -  "
      end
      
      local line_button = vb:button {
        text = display_text,
        width = 48,
        height = 17,
        color = button_color,
        notifier = function()
          PakettiPatternDelayViewerJumpToPosition(pattern_info.sequence_index, line_index, col)
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      }
      
      -- Register button for keyboard navigation
      table.insert(button_registry, {
        button = line_button,
        seq_index = pattern_info.sequence_index,
        line_index = line_index,
        col_index = col,
        pattern_info = pattern_info,
        base_color = button_color,
        note_name = line_info.note_string
      })
      
      table.insert(line_row_views, line_button)
    end
    
    table.insert(col_views, vb:row { views = line_row_views })
  end
  
  -- If no data found, show message
  if #lines_with_data == 0 then
    table.insert(col_views, vb:text {
      text = "(empty)",
      style = "disabled"
    })
  end
  
  return vb:column { views = col_views }
end

function PakettiPatternDelayViewerBuildContent(max_patterns_to_show)
  max_patterns_to_show = max_patterns_to_show or 4
  
  -- Clear button registry and selection for rebuild
  button_registry = {}
  selected_button_index = 0
  
  local song = renoise.song()
  local current_seq = song.selected_sequence_index
  
  -- Gather fresh data
  PakettiPatternDelayViewerGatherPatternData()
  
  if #pattern_data_cache == 0 then
    return vb:column {
      views = {
        vb:text { text = "No patterns in sequence" }
      }
    }
  end
  
  -- Determine which patterns to show (centered around current sequence position)
  local start_seq = math.max(1, current_seq - math.floor(max_patterns_to_show / 2))
  local end_seq = math.min(#pattern_data_cache, start_seq + max_patterns_to_show - 1)
  
  -- Adjust start if we're near the end
  if end_seq - start_seq + 1 < max_patterns_to_show then
    start_seq = math.max(1, end_seq - max_patterns_to_show + 1)
  end
  
  -- Build the main row with pattern columns
  local pattern_column_views = {}
  
  for i = start_seq, end_seq do
    local pattern_info = pattern_data_cache[i]
    local pattern_col = PakettiPatternDelayViewerBuildPatternColumn(pattern_info, i, max_patterns_to_show)
    table.insert(pattern_column_views, pattern_col)
  end
  
  local pattern_columns = vb:row { views = pattern_column_views }
  
  -- Gather note+delay combinations
  local note_delay_combos = {}
  for _, pattern_info in ipairs(pattern_data_cache) do
    for _, column_data in ipairs(pattern_info.columns) do
      for _, line_info in ipairs(column_data) do
        if not line_info.is_empty and line_info.delay > 0 then
          local key = line_info.note_string .. ":" .. string.format("%02X", line_info.delay)
          note_delay_combos[key] = (note_delay_combos[key] or 0) + 1
        end
      end
    end
  end
  
  -- Build compact stats display
  local delay_stats_text = "Note+Delay: "
  local combo_list = {}
  for combo, count in pairs(note_delay_combos) do
    table.insert(combo_list, {combo = combo, count = count})
  end
  table.sort(combo_list, function(a, b) return a.combo < b.combo end)
  
  if #combo_list > 0 then
    local stats_parts = {}
    for _, item in ipairs(combo_list) do
      if item.count > 1 then
        table.insert(stats_parts, string.format("%s(%d)", item.combo, item.count))
      else
        table.insert(stats_parts, item.combo)
      end
    end
    delay_stats_text = delay_stats_text .. table.concat(stats_parts, " ")
  else
    delay_stats_text = delay_stats_text .. "None"
  end
  
  -- Build control panel
  local control_panel = vb:column {
    views = {
      vb:row {
        views = {
          vb:text { text = "Track: " .. song.tracks[song.selected_track_index].name, width = 300, font = "bold" },
          vb:button {
            text = "Close",
            width = 60,
            notifier = function()
              PakettiPatternDelayViewerCloseDialog()
            end
          }
        }
      },
      vb:row {
        views = {
          vb:text { text = delay_stats_text, style = "normal" }
        }
      },
      vb:row {
        views = {
          vb:text { text = "Colors: Each note (C,D,E,F,G,A,B) has unique color | OFF=Dark Gray", style = "disabled" }
        }
      },
      vb:row {
        views = {
          vb:text { text = "Cursor keys=Navigate | Enter=Jump to Pattern Editor", style = "disabled" }
        }
      }
    }
  }
  
  return vb:column {
    views = {
      control_panel,
      vb:horizontal_aligner {
        mode = "left",
        views = {
          pattern_columns
        }
      }
    }
  }
end

------------------------------------------------------------------------------
-- Dialog Management
------------------------------------------------------------------------------

function PakettiPatternDelayViewerRefreshDialog()
  if dialog and dialog.visible then
    dialog_content = PakettiPatternDelayViewerBuildContent(4)
    dialog:close()
    
    dialog = renoise.app():show_custom_dialog(
      "Pattern Delay Viewer - Track: " .. renoise.song().tracks[renoise.song().selected_track_index].name,
      dialog_content,
      PakettiPatternDelayViewerKeyHandler
    )
    
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end
end

function PakettiPatternDelayViewerCloseDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    dialog_content = nil
    pattern_data_cache = {}
    PakettiPatternDelayViewerRemoveNotifiers()
  end
end

function PakettiPatternDelayViewerRemoveNotifiers()
  for _, notifier_info in ipairs(notifiers) do
    if notifier_info.observable and notifier_info.notifier then
      if notifier_info.is_pattern then
        -- Pattern line notifiers use different methods
        if notifier_info.observable:has_line_notifier(notifier_info.notifier) then
          notifier_info.observable:remove_line_notifier(notifier_info.notifier)
        end
      else
        -- Regular observable notifiers
        if notifier_info.observable:has_notifier(notifier_info.notifier) then
          notifier_info.observable:remove_notifier(notifier_info.notifier)
        end
      end
    end
  end
  notifiers = {}
end

function PakettiPatternDelayViewerSetupNotifiers()
  PakettiPatternDelayViewerRemoveNotifiers()
  
  local song = renoise.song()
  
  -- Pattern line change notifier for auto-refresh
  local line_notifier = function()
    if dialog and dialog.visible then
      PakettiPatternDelayViewerRefreshDialog()
    end
  end
  
  -- Notifier for selected track changes
  local track_notifier = function()
    if dialog and dialog.visible then
      PakettiPatternDelayViewerRefreshDialog()
    end
  end
  
  -- Notifier for selected sequence changes  
  local seq_notifier = function()
    if dialog and dialog.visible then
      PakettiPatternDelayViewerRefreshDialog()
    end
  end
  
  -- Add line notifiers to all patterns in sequence
  local pattern_sequence = song.sequencer.pattern_sequence
  local added_patterns = {}
  for _, pattern_index in ipairs(pattern_sequence) do
    if not added_patterns[pattern_index] then
      added_patterns[pattern_index] = true
      local pattern = song:pattern(pattern_index)
      pattern:add_line_notifier(line_notifier)
      table.insert(notifiers, {
        observable = pattern,
        notifier = line_notifier,
        is_pattern = true
      })
    end
  end
  
  song.selected_track_index_observable:add_notifier(track_notifier)
  table.insert(notifiers, {
    observable = song.selected_track_index_observable,
    notifier = track_notifier
  })
  
  song.selected_sequence_index_observable:add_notifier(seq_notifier)
  table.insert(notifiers, {
    observable = song.selected_sequence_index_observable,
    notifier = seq_notifier
  })
end

-- Function to update visual selection state of buttons
function PakettiPatternDelayViewerUpdateButtonSelection()
  if #button_registry == 0 then return end
  
  for idx, btn_info in ipairs(button_registry) do
    if btn_info.button and btn_info.button.visible then
      local note_name = btn_info.note_name
      local base_color = btn_info.base_color or {0x00, 0x00, 0x00}
      
      if idx == selected_button_index then
        -- Selected: bright magenta
        btn_info.button.color = {0xFF, 0x00, 0xFF}
      else
        -- Not selected: use original color
        btn_info.button.color = base_color
      end
    end
  end
end

function PakettiPatternDelayViewerKeyHandler(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  
  if key.modifiers == "" and key.name == closer then
    PakettiPatternDelayViewerCloseDialog()
    return nil
  end
  
  -- Handle Enter key - jump to selected button position and shift focus
  if key.modifiers == "" and key.name == "return" then
    if selected_button_index > 0 and selected_button_index <= #button_registry then
      local btn_info = button_registry[selected_button_index]
      PakettiPatternDelayViewerJumpToPosition(btn_info.seq_index, btn_info.line_index, btn_info.col_index)
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
    return nil
  end
  
  -- Handle cursor keys for navigation
  if key.modifiers == "" and (key.name == "up" or key.name == "down" or key.name == "left" or key.name == "right") then
    if #button_registry == 0 then
      return nil
    end
    
    -- If no selection yet, find closest button to current pattern position
    if selected_button_index == 0 then
      local song = renoise.song()
      local current_seq = song.selected_sequence_index
      local current_line = song.selected_line_index
      local current_col = song.selected_note_column_index
      
      local best_idx = 1
      local best_distance = math.huge
      
      for idx, btn_info in ipairs(button_registry) do
        if btn_info.seq_index == current_seq then
          local distance = math.abs(btn_info.line_index - current_line) + math.abs(btn_info.col_index - current_col)
          if distance < best_distance then
            best_distance = distance
            best_idx = idx
          end
        end
      end
      
      selected_button_index = best_idx
      PakettiPatternDelayViewerUpdateButtonSelection()
      return nil
    end
    
    local current_btn = button_registry[selected_button_index]
    local new_idx = selected_button_index
    
    if key.name == "down" then
      -- Find next button with SAME column, higher line number (stay in same column)
      for idx = selected_button_index + 1, #button_registry do
        if button_registry[idx].col_index == current_btn.col_index and
           button_registry[idx].line_index > current_btn.line_index then
          new_idx = idx
          break
        end
      end
    elseif key.name == "up" then
      -- Find previous button with SAME column, lower line number (stay in same column)
      for idx = selected_button_index - 1, 1, -1 do
        if button_registry[idx].col_index == current_btn.col_index and
           button_registry[idx].line_index < current_btn.line_index then
          new_idx = idx
          break
        end
      end
    elseif key.name == "right" then
      -- Find next column in same line, same pattern
      -- If at last column, wrap to first column of next line
      local found = false
      for idx = selected_button_index + 1, #button_registry do
        if button_registry[idx].seq_index == current_btn.seq_index and
           button_registry[idx].line_index == current_btn.line_index and
           button_registry[idx].col_index > current_btn.col_index then
          new_idx = idx
          found = true
          break
        end
      end
      -- If not found in same line, go to first column of next line in same pattern
      if not found then
        for idx = selected_button_index + 1, #button_registry do
          if button_registry[idx].seq_index == current_btn.seq_index and
             button_registry[idx].line_index > current_btn.line_index then
            new_idx = idx
            found = true
            break
          end
        end
      end
      -- If still not found, go to first button of next pattern
      if not found then
        for idx = selected_button_index + 1, #button_registry do
          if button_registry[idx].seq_index > current_btn.seq_index then
            new_idx = idx
            break
          end
        end
      end
    elseif key.name == "left" then
      -- Find previous column in same line, same pattern
      -- If at first column, wrap to last column of previous line
      local found = false
      for idx = selected_button_index - 1, 1, -1 do
        if button_registry[idx].seq_index == current_btn.seq_index and
           button_registry[idx].line_index == current_btn.line_index and
           button_registry[idx].col_index < current_btn.col_index then
          new_idx = idx
          found = true
          break
        end
      end
      -- If not found in same line, go to last column of previous line in same pattern
      if not found then
        local target_line = nil
        local first_btn_of_target = nil
        -- Find the previous line
        for idx = selected_button_index - 1, 1, -1 do
          if button_registry[idx].seq_index == current_btn.seq_index and
             button_registry[idx].line_index < current_btn.line_index then
            target_line = button_registry[idx].line_index
            first_btn_of_target = idx
            break
          end
        end
        -- Now find the LAST button of that target line by going forward
        if target_line and first_btn_of_target then
          new_idx = first_btn_of_target
          for idx = first_btn_of_target + 1, #button_registry do
            if button_registry[idx].seq_index == current_btn.seq_index and
               button_registry[idx].line_index == target_line then
              new_idx = idx
            else
              break
            end
          end
          found = true
        end
      end
      -- If still not found, go to last button of previous pattern
      if not found then
        for idx = selected_button_index - 1, 1, -1 do
          if button_registry[idx].seq_index < current_btn.seq_index then
            new_idx = idx
            break
          end
        end
      end
    end
    
    if new_idx ~= selected_button_index then
      selected_button_index = new_idx
      PakettiPatternDelayViewerUpdateButtonSelection()
    end
    
    return nil
  end
  
  return key
end

function PakettiPatternDelayViewerShowDialog()
  if dialog and dialog.visible then
    dialog:show()
    return
  end
  
  vb = renoise.ViewBuilder()
  dialog_content = PakettiPatternDelayViewerBuildContent(4)
  
  dialog = renoise.app():show_custom_dialog(
    "Pattern Delay Viewer - Track: " .. renoise.song().tracks[renoise.song().selected_track_index].name,
    dialog_content,
    PakettiPatternDelayViewerKeyHandler
  )
  
  PakettiPatternDelayViewerSetupNotifiers()
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

------------------------------------------------------------------------------
-- Utility Functions for Delay Value Manipulation
------------------------------------------------------------------------------

function PakettiPatternDelayViewerSetDelayForNote(target_note_string, target_delay_value)
  local song = renoise.song()
  local selected_track = song.selected_track_index
  local pattern_sequence = song.sequencer.pattern_sequence
  
  local changes_count = 0
  
  for seq_index = 1, #pattern_sequence do
    local pattern_index = pattern_sequence[seq_index]
    local pattern = song:pattern(pattern_index)
    local track = pattern:track(selected_track)
    local visible_note_columns = song.tracks[selected_track].visible_note_columns
    
    for col = 1, visible_note_columns do
      for line_index = 1, pattern.number_of_lines do
        local line = track:line(line_index)
        local note_col = line.note_columns[col]
        
        if not note_col.is_empty and note_col.note_string == target_note_string then
          note_col.delay_value = target_delay_value
          changes_count = changes_count + 1
        end
      end
    end
  end
  
  renoise.app():show_status(string.format("Set delay to %02X for %d instances of note %s", target_delay_value, changes_count, target_note_string))
  
  if dialog and dialog.visible then
    PakettiPatternDelayViewerRefreshDialog()
  end
end

function PakettiPatternDelayViewerPromptSetDelayForNote()
  local song = renoise.song()
  local line = song.selected_line
  local note_col = line.note_columns[song.selected_note_column_index]
  
  if note_col.is_empty or note_col.note_value >= 120 then
    renoise.app():show_status("Please select a note in the pattern editor first")
    return
  end
  
  local current_note = note_col.note_string
  local current_delay = note_col.delay_value
  
  renoise.app():show_prompt(
    "Set Delay Value",
    string.format("Set delay for all '%s' notes in track (current: %02X hex / %d dec)?", current_note, current_delay, current_delay),
    function(result)
      if result ~= "" then
        local delay_value = tonumber(result, 16) or tonumber(result)
        if delay_value and delay_value >= 0 and delay_value <= 255 then
          PakettiPatternDelayViewerSetDelayForNote(current_note, delay_value)
        else
          renoise.app():show_status("Invalid delay value. Must be 0-255 (00-FF hex)")
        end
      end
    end
  )
end

function PakettiPatternDelayViewerCopyDelayFromSelectedNote()
  local song = renoise.song()
  local line = song.selected_line
  local note_col = line.note_columns[song.selected_note_column_index]
  
  if note_col.is_empty then
    renoise.app():show_status("Please select a note with a delay value first")
    return
  end
  
  local current_note = note_col.note_string
  local current_delay = note_col.delay_value
  
  if current_delay == 0 then
    renoise.app():show_status("Selected note has no delay (00)")
    return
  end
  
  local selected_track = song.selected_track_index
  local pattern_sequence = song.sequencer.pattern_sequence
  
  local changes_count = 0
  
  for seq_index = 1, #pattern_sequence do
    local pattern_index = pattern_sequence[seq_index]
    local pattern = song:pattern(pattern_index)
    local track = pattern:track(selected_track)
    local visible_note_columns = song.tracks[selected_track].visible_note_columns
    
    for col = 1, visible_note_columns do
      for line_index = 1, pattern.number_of_lines do
        local line_data = track:line(line_index)
        local note_col_data = line_data.note_columns[col]
        
        if not note_col_data.is_empty and note_col_data.note_string == current_note and note_col_data.delay_value ~= current_delay then
          note_col_data.delay_value = current_delay
          changes_count = changes_count + 1
        end
      end
    end
  end
  
  renoise.app():show_status(string.format("Applied delay %02X to %d other instances of note %s", current_delay, changes_count, current_note))
  
  if dialog and dialog.visible then
    PakettiPatternDelayViewerRefreshDialog()
  end
end

------------------------------------------------------------------------------
-- Menu Entries
------------------------------------------------------------------------------

-- Main Menu entries
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern:Pattern Delay Viewer...",invoke=function() PakettiPatternDelayViewerShowDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Pattern Delay Viewer...",invoke=function() PakettiPatternDelayViewerShowDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Pattern Delay Viewer...",invoke=function() PakettiPatternDelayViewerShowDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern:Copy Delay to All Same Notes in Track",invoke=function() PakettiPatternDelayViewerCopyDelayFromSelectedNote() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern:Set Delay for All Same Notes in Track...",invoke=function() PakettiPatternDelayViewerPromptSetDelayForNote() end}

-- Pattern Editor context menu entries
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Pattern Delay Viewer...",invoke=function() PakettiPatternDelayViewerShowDialog() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Pattern:Copy Delay to All Same Notes in Track",invoke=function() PakettiPatternDelayViewerCopyDelayFromSelectedNote() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Pattern:Set Delay for All Same Notes in Track...",invoke=function() PakettiPatternDelayViewerPromptSetDelayForNote() end}

-- Keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Show Pattern Delay Viewer...",invoke=function() PakettiPatternDelayViewerShowDialog() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Copy Delay to All Same Notes in Track",invoke=function() PakettiPatternDelayViewerCopyDelayFromSelectedNote() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set Delay for All Same Notes in Track...",invoke=function() PakettiPatternDelayViewerPromptSetDelayForNote() end}

