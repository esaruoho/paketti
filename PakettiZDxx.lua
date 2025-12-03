-- Paketti ZDxx Pattern Delay Writer
-- ZDxx = Delay (pause) pattern for xx lines
-- xx is in hexadecimal, representing the number of lines to delay

local dialog = nil

-- Function to ensure effect columns are visible
local function ensure_effect_column_visible()
  local s = renoise.song()
  if s.selection_in_pattern then
    for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
      local track = s:track(t)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        track.visible_effect_columns = math.max(track.visible_effect_columns, 1)
      end
    end
  else
    local track = s.selected_track
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      track.visible_effect_columns = math.max(track.visible_effect_columns, 1)
    end
  end
end

-- Function to write ZDxx command with specified number of lines to delay
function write_zdxx(delay_lines)
  local s = renoise.song()
  
  -- Validate input (ZDxx can only handle 0x00 to 0xFF = 0 to 255 lines)
  if delay_lines < 0 then delay_lines = 0 end
  if delay_lines > 255 then delay_lines = 255 end
  
  -- Convert decimal to hex string
  local hex_value = string.format("%02X", delay_lines)
  
  ensure_effect_column_visible()
  
  if s.selection_in_pattern then
    -- Apply to selection
    local pattern = s:pattern(s.selected_pattern_index)
    for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
      local track = s:track(t)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local pattern_track = pattern:track(t)
        local note_columns_visible = track.visible_note_columns
        local effect_columns_visible = track.visible_effect_columns
        local total_columns_visible = note_columns_visible + effect_columns_visible
        
        local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or note_columns_visible + 1
        local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or total_columns_visible
        
        for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
          local line = pattern_track:line(i)
          for col = start_column, end_column do
            local column_index = col - note_columns_visible
            if column_index > 0 and column_index <= effect_columns_visible then
              local effect_column = line:effect_column(column_index)
              if effect_column then
                effect_column.number_string = "ZD"
                effect_column.amount_string = hex_value
              end
            end
          end
        end
      end
    end
  else
    -- Apply to current line
    local target_effect_column_index = 1
    
    if s.selected_note_column_index > 0 then
      target_effect_column_index = 1
    elseif s.selected_effect_column_index > 0 then
      target_effect_column_index = s.selected_effect_column_index
    end
    
    local line = s.selected_line
    if line and target_effect_column_index <= s.selected_track.visible_effect_columns then
      line.effect_columns[target_effect_column_index].number_string = "ZD"
      line.effect_columns[target_effect_column_index].amount_string = hex_value
    end
  end
  
  renoise.app():show_status(string.format("ZD%s - Delay pattern for %d lines (0x%s)", hex_value, delay_lines, hex_value))
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Preset functions for common delay values
function write_zdxx_01_line()
  write_zdxx(1)
end

function write_zdxx_02_lines()
  write_zdxx(2)
end

function write_zdxx_04_lines()
  write_zdxx(4)
end

function write_zdxx_08_lines()
  write_zdxx(8)
end

function write_zdxx_12_lines()
  write_zdxx(12)
end

function write_zdxx_16_lines()
  write_zdxx(16)
end

function write_zdxx_24_lines()
  write_zdxx(24)
end

function write_zdxx_32_lines()
  write_zdxx(32)
end

function write_zdxx_48_lines()
  write_zdxx(48)
end

function write_zdxx_64_lines()
  write_zdxx(64)
end

function write_zdxx_96_lines()
  write_zdxx(96)
end

function write_zdxx_128_lines()
  write_zdxx(128)
end

function write_zdxx_192_lines()
  write_zdxx(192)
end

function write_zdxx_255_lines()
  write_zdxx(255)
end

-- Dialog for ZDxx writer
function show_zdxx_dialog()
  local vb = renoise.ViewBuilder()
  
  if dialog and dialog.visible then
    dialog:close()
    return
  end
  
  local delay_value = 16  -- Default value
  
  local delay_text = vb:text{
    style = "strong",
    text = string.format("Delay: %d lines (0x%02X)", delay_value, delay_value)
  }
  
  local delay_slider = vb:slider{
    width = 500,
    min = 0,
    max = 255,
    value = delay_value,
    notifier = function(value)
      delay_value = math.floor(value + 0.5)
      delay_text.text = string.format("Delay: %d lines (0x%02X)", delay_value, delay_value)
    end
  }
  
  local apply_button = vb:button{
    text = "Apply ZD" .. string.format("%02X", delay_value),
    width = 200,
    notifier = function()
      write_zdxx(delay_value)
    end
  }
  
  -- Update button text when slider changes
  delay_slider.notifier = function(value)
    delay_value = math.floor(value + 0.5)
    delay_text.text = string.format("Delay: %d lines (0x%02X)", delay_value, delay_value)
    apply_button.text = "Apply ZD" .. string.format("%02X", delay_value)
  end
  
  local info_text = vb:column{
    style = "group",
    margin = 5,
    vb:text{style = "strong", text = "Pattern Delay (ZDxx):"},
    vb:text{text = "Pauses pattern playback for xx lines."},
    vb:text{text = "Use this to extend phrase durations or create timing effects."},
    vb:text{text = "Range: 0-255 lines (0x00-0xFF)."},
    vb:space{height = 5},
    vb:text{style = "strong", text = "Example:"},
    vb:text{text = "4-row phrase + ZD10 (16 lines) on each row = 64 rows total"},
    vb:text{text = "(each row plays, then delays 16 lines)"}
  }
  
  local main_preset_buttons = vb:column{
    style = "group",
    margin = 5,
    vb:text{style = "strong", text = "Main Presets:"},
    vb:row{
      vb:button{
        text = "ZD04 (4 Lines)",
        width = 120,
        height = 30,
        notifier = function() write_zdxx(4) end
      },
      vb:button{
        text = "ZD08 (8 Lines)",
        width = 120,
        height = 30,
        notifier = function() write_zdxx(8) end
      },
      vb:button{
        text = "ZD10 (16 Lines)",
        width = 120,
        height = 30,
        notifier = function() write_zdxx(16) end
      }
    },
    vb:row{
      vb:button{
        text = "ZD20 (32 Lines)",
        width = 120,
        height = 30,
        notifier = function() write_zdxx(32) end
      },
      vb:button{
        text = "ZD40 (64 Lines)",
        width = 120,
        height = 30,
        notifier = function() write_zdxx(64) end
      },
      vb:button{
        text = "ZD80 (128 Lines)",
        width = 120,
        height = 30,
        notifier = function() write_zdxx(128) end
      }
    }
  }
  
  local additional_presets = vb:column{
    style = "group",
    margin = 5,
    vb:text{style = "strong", text = "Additional Presets:"},
    vb:row{
      vb:button{text = "1", width = 40, tooltip = "ZD01 (1 Line)", notifier = function() write_zdxx(1) end},
      vb:button{text = "2", width = 40, tooltip = "ZD02 (2 Lines)", notifier = function() write_zdxx(2) end},
      vb:button{text = "12", width = 40, tooltip = "ZD0C (12 Lines)", notifier = function() write_zdxx(12) end},
      vb:button{text = "24", width = 40, tooltip = "ZD18 (24 Lines)", notifier = function() write_zdxx(24) end},
      vb:button{text = "48", width = 40, tooltip = "ZD30 (48 Lines)", notifier = function() write_zdxx(48) end},
      vb:button{text = "96", width = 40, tooltip = "ZD60 (96 Lines)", notifier = function() write_zdxx(96) end},
      vb:button{text = "192", width = 40, tooltip = "ZDC0 (192 Lines)", notifier = function() write_zdxx(192) end},
      vb:button{text = "255", width = 40, tooltip = "ZDFF (255 Lines)", notifier = function() write_zdxx(255) end}
    }
  }
  
  local custom_section = vb:column{
    style = "group",
    margin = 5,
    vb:text{style = "strong", text = "Custom Delay Value:"},
    vb:horizontal_aligner{
      mode = "center",
      delay_slider
    },
    vb:horizontal_aligner{
      mode = "center",
      delay_text
    },
    vb:horizontal_aligner{
      mode = "center",
      apply_button
    }
  }
  
  local dialog_content = vb:column{
    info_text,
    main_preset_buttons,
    additional_presets,
    custom_section,
    vb:horizontal_aligner{
      mode = "center",
      vb:button{
        text = "Close",
        width = 100,
        notifier = function()
          dialog:close()
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      }
    }
  }
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  
  dialog = renoise.app():show_custom_dialog("Paketti ZDxx Pattern Delay", dialog_content, keyhandler)
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Menu entries
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Pattern Editor:ZDxx Pattern Delay Dialog...", invoke = show_zdxx_dialog}

-- Keybindings
renoise.tool():add_keybinding{name = "Global:Paketti:ZDxx Pattern Delay Dialog", invoke = show_zdxx_dialog}
renoise.tool():add_keybinding{name = "Pattern Editor:Paketti:Write ZD04 (4 Lines Delay)", invoke = write_zdxx_04_lines}
renoise.tool():add_keybinding{name = "Pattern Editor:Paketti:Write ZD08 (8 Lines Delay)", invoke = write_zdxx_08_lines}
renoise.tool():add_keybinding{name = "Pattern Editor:Paketti:Write ZD10 (16 Lines Delay)", invoke = write_zdxx_16_lines}
renoise.tool():add_keybinding{name = "Pattern Editor:Paketti:Write ZD20 (32 Lines Delay)", invoke = write_zdxx_32_lines}
renoise.tool():add_keybinding{name = "Pattern Editor:Paketti:Write ZD40 (64 Lines Delay)", invoke = write_zdxx_64_lines}
renoise.tool():add_keybinding{name = "Pattern Editor:Paketti:Write ZD80 (128 Lines Delay)", invoke = write_zdxx_128_lines}

-- MIDI mappings for main presets
renoise.tool():add_midi_mapping{name = "Paketti:Write ZD04 (4 Lines Delay)", invoke = function(message) if message:is_trigger() then write_zdxx_04_lines() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Write ZD08 (8 Lines Delay)", invoke = function(message) if message:is_trigger() then write_zdxx_08_lines() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Write ZD10 (16 Lines Delay)", invoke = function(message) if message:is_trigger() then write_zdxx_16_lines() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Write ZD20 (32 Lines Delay)", invoke = function(message) if message:is_trigger() then write_zdxx_32_lines() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Write ZD40 (64 Lines Delay)", invoke = function(message) if message:is_trigger() then write_zdxx_64_lines() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Write ZD80 (128 Lines Delay)", invoke = function(message) if message:is_trigger() then write_zdxx_128_lines() end end}

