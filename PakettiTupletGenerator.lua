local function calculate_delay(position, total_notes, ticks_per_line)
  -- Calculate actual delay values (0-255)
  local delay = math.floor((position - 1) * 255 / total_notes)
  return delay
end

-- Dialog tracking variable
local dialog = nil

local function generate_pattern(note_count, row_count, delays_only)
  local pattern = {}
  
  -- Initialize empty pattern
  for i = 1, row_count do
    pattern[i] = "--- --"
  end
  
  if note_count == 1 then
    pattern[1] = delays_only and "-- --" or "C-4 --"
  
  elseif note_count == 2 then
    pattern[1] = delays_only and "-- --" or "C-4 --"
    pattern[math.floor(row_count/2) + 1] = delays_only and "-- --" or "C-4 --"
  
  elseif note_count == 3 then
    pattern[1] = delays_only and "-- --" or "C-4 --"
    local d1 = calculate_delay(3, 3, 12)
    local d2 = calculate_delay(2, 3, 12)
    pattern[3] = delays_only and string.format("-- %02X", d1) or string.format("C-4 %02X", d1)
    pattern[6] = delays_only and string.format("-- %02X", d2) or string.format("C-4 %02X", d2)
  
  elseif note_count == 4 then
    local spacing = math.floor(row_count/4)
    for i = 0, 3 do
      pattern[1 + (i * spacing)] = delays_only and "-- --" or "C-4 --"
    end
  
  elseif note_count == 5 then
    pattern[1] = delays_only and "-- --" or "C-4 --"
    for i = 2, 5 do
      local delay = calculate_delay(i, 5, 12)
      local row = math.floor((i-1) * row_count/5) + 1
      pattern[row] = delays_only and string.format("-- %02X", delay) or string.format("C-4 %02X", delay)
    end
  
  elseif note_count == 6 then
    pattern[1] = delays_only and "-- --" or "C-4 --"
    for i = 2, 3 do
      local delay = calculate_delay(i, 3, 12)
      pattern[i] = delays_only and string.format("-- %02X", delay) or string.format("C-4 %02X", delay)
    end
    pattern[5] = delays_only and "-- --" or "C-4 --"
    for i = 2, 3 do
      local delay = calculate_delay(i, 3, 12)
      pattern[i+4] = delays_only and string.format("-- %02X", delay) or string.format("C-4 %02X", delay)
    end
  
  elseif note_count == 7 then
    pattern[1] = delays_only and "-- --" or "C-4 --"
    for i = 2, 7 do
      local delay = calculate_delay(i, 7, 12)
      pattern[i] = delays_only and string.format("-- %02X", delay) or string.format("C-4 %02X", delay)
    end
  
  elseif note_count == 8 then
    local spacing = math.floor(row_count/8)
    for i = 0, 7 do
      pattern[1 + (i * spacing)] = delays_only and "-- --" or "C-4 --"
    end
  end
  
  return table.concat(pattern, "\n")
end

local function apply_to_pattern(pattern_text, row_count, views)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track = song.selected_track_index
  local line = song.selected_line_index
  local instrument = song.selected_instrument_index
  
  -- Ensure delay column is visible
  if not song.tracks[track].delay_column_visible then
    song.tracks[track].delay_column_visible = true
  end
  
  -- Set selection in pattern
  local end_line = math.min(line + (row_count - 1), 512)  -- Ensure we don't exceed 512
  song.selection_in_pattern = {
    start_track = track,
    end_track = track,
    start_column = 1,
    end_column = 1,
    start_line = line,
    end_line = end_line
  }
  
  -- Clear the selected area first
  for i = line, end_line do  -- Use end_line here too
    local note_col = pattern.tracks[track]:line(i).note_columns[1]
    note_col:clear()
  end
  
  -- Split pattern text into lines
  local lines = {}
  for s in pattern_text:gmatch("[^\r\n]+") do
    table.insert(lines, s)
  end
  
  -- Apply each line to the pattern
  for i, line_text in ipairs(lines) do
    local delay = line_text:match("C%-4%s+(%x+)") or line_text:match("%-%-+%s+(%x+)")
    local note_col = pattern.tracks[track]:line(line + i - 1).note_columns[1]
    
    if line_text:find("C%-4") then
      note_col.note_string = "C-4"
      note_col.instrument_value = instrument - 1
    end
    
    if delay then
      note_col.delay_value = tonumber(delay, 16)
    end
  end
  
  -- Jump to below selection if enabled, with wrapping
  if views.jump_below.value then
    local new_line = line + row_count
    -- Pattern lines are 1-based indexing, wrap if exceeding pattern length
    if new_line > pattern.number_of_lines then
      new_line = 1
    end
    song.selected_line_index = new_line
  end
  
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

function show_tuplet_dialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  
  local function validate_and_generate()
    local row_count = math.max(1, tonumber(vb.views.row_count.value) or 1)
    local note_count = math.max(1, tonumber(vb.views.note_count.value) or 1)
    local delays_only = vb.views.delays_only.value
    
    -- Cap note count between 1 and row count
    note_count = math.min(row_count, math.max(1, note_count))
    
    -- Update the displayed values if they were invalid
    vb.views.row_count.value = tostring(row_count)
    vb.views.note_count.value = tostring(note_count)
    
    -- Generate pattern with delays_only parameter
    local pattern = generate_pattern(note_count, row_count, delays_only)
    vb.views.pattern_view.text = pattern
    
    -- Auto-print if enabled and switch value changes
    if vb.views.auto_print.value then
      apply_to_pattern(pattern, row_count, vb.views)
    end
  end
  
  local dialog_content = vb:column {
    vb:horizontal_aligner {
      -- Left side inputs with aligned labels
      vb:column {
        vb:horizontal_aligner {
          vb:text { 
            text = "Note Count:",
            width = 100,
          },
          vb:textfield {
            id = "note_count",
            value = "3",
            width = 50,
            notifier = function(value)
              validate_and_generate()
              renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
            end
          }
        },
        vb:horizontal_aligner {
          vb:text { 
            text = "Row Count:",
            width = 100,
          },
          vb:textfield {
            id = "row_count",
            value = "8",
            width = 50,
            notifier = function(value)
              validate_and_generate()
              renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
            end
          }
        },
        vb:horizontal_aligner {
          vb:text { 
            text = "Ticks per Line:",
            width = 100,
          },
          vb:textfield {
            id = "ticks",
            value = "12",
            width = 50,
          }
        },
        vb:horizontal_aligner {
          vb:text { 
            text = "Highlight:",
            width = 100,
          },
          vb:textfield {
            id = "highlight",
            value = "8",
            width = 50,
          }
        }
      },
      
      -- Right side pattern view
      vb:column {
        vb:text {
          id = "pattern_view",
          font = "mono",
          text = generate_pattern(3, 8)
        }
      }
    },
    
    -- Bottom buttons
    vb:horizontal_aligner {
      vb:button {
        text = "Print",
        width = 60,
        notifier = function() 
          local row_count = tonumber(vb.views.row_count.value) or 8
          apply_to_pattern(vb.views.pattern_view.text, row_count, vb.views)
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      }
    },
    
    vb:horizontal_aligner {
      vb:checkbox {
        id = "auto_print",
        value = true,
        notifier = function()
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:text {
        text = "Print when switch changes"
      }
    },
    
    vb:switch {
      id = "tuplet_switch",
      width = 500,
      items = {"Single", "Quarter", "Triplets", "Eighth", "Quintuplets", "Sextuplets", "Septuplets", "Sixteenth"},
      value = 3,
      notifier = function(index)
        local note_counts = {1, 2, 3, 4, 5, 6, 7, 8}
        vb.views.note_count.value = tostring(note_counts[index])
        local row_count = math.max(1, tonumber(vb.views.row_count.value) or 1)
        local note_count = note_counts[index]
        local delays_only = vb.views.delays_only.value
        local pattern = generate_pattern(note_count, row_count, delays_only)
        vb.views.pattern_view.text = pattern
        
        -- Always update the selection
        local song = renoise.song()
        local line = song.selected_line_index
        local end_line = math.min(line + (row_count - 1), 512)  -- Ensure we don't exceed 512
        
        song.selection_in_pattern = {
          start_track = song.selected_track_index,
          end_track = song.selected_track_index,
          start_column = 1,
          end_column = 1,
          start_line = line,
          end_line = end_line
        }
        
        if vb.views.auto_print.value then
          apply_to_pattern(pattern, row_count, vb.views)
          if vb.views.auto_flood.value then
            floodfill_with_selection()
          end
        end
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end
    },
    
    vb:horizontal_aligner {
      vb:checkbox {
        id = "delays_only",
        value = false,
        notifier = function()
          -- Instead of trying to call the notifier directly,
          -- we should replicate the switch's logic here
          local note_counts = {1, 2, 3, 4, 5, 6, 7, 8}
          local current_switch_value = vb.views.tuplet_switch.value
          local note_count = note_counts[current_switch_value]
          local row_count = math.max(1, tonumber(vb.views.row_count.value) or 1)
          local delays_only = vb.views.delays_only.value
          
          local pattern = generate_pattern(note_count, row_count, delays_only)
          vb.views.pattern_view.text = pattern
          
          if vb.views.auto_print.value then
            apply_to_pattern(pattern, row_count, vb.views)
            if vb.views.auto_flood.value then
              floodfill_with_selection()
            end
          end
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:text {
        text = "Print Delay Values Only"
      }
    },
    
    vb:horizontal_aligner {
      vb:checkbox {
        id = "auto_flood",
        value = false,
        notifier = function()
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:text {
        text = "Auto flood fill after printing"
      }
    },
    
    vb:horizontal_aligner {
      vb:checkbox {
        id = "jump_below",
        value = false,
        notifier = function()
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:text {
        text = "Jump to below selection"
      }
    }
  }
    
  dialog = renoise.app():show_custom_dialog("Paketti Tuplet Writer",dialog_content,my_keyhandler_func)
  
  -- Set focus to note count field
  vb.views.note_count.active = true
  vb.views.note_count.edit_mode = true
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Xperimental/Work in Progress..:Paketti Tuplet Writer...",invoke=function() show_tuplet_dialog() end}
renoise.tool():add_keybinding{name="Global:Tools:Paketti Tuplet Writer",invoke=function() show_tuplet_dialog() end}