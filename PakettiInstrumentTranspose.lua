-- Paketti Instrument Transpose System
-- Comprehensive transpose functionality for selected instrument
-- Supports both relative and absolute transpose values from -120 to +120
-- All functions are global as per Paketti conventions [[memory:5821545]]
-- Function for relative transpose (add/subtract from current transpose)
function PakettiInstrumentTransposeRelative(amount)
  local instrument = renoise.song().selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local current_transpose = instrument.transpose
  local new_transpose = current_transpose + amount
  
  -- Check if already at limits and can't change
  if amount > 0 and current_transpose >= 120 then
    renoise.app():show_status("Instrument transpose already at maximum (+120)")
    return
  elseif amount < 0 and current_transpose <= -120 then
    renoise.app():show_status("Instrument transpose already at minimum (-120)")
    return
  end
  
  -- Clamp to valid range (-120 to +120) and detect if clamping occurred
  local was_clamped = false
  if new_transpose > 120 then
    new_transpose = 120
    was_clamped = true
  elseif new_transpose < -120 then
    new_transpose = -120
    was_clamped = true
  end
  
  instrument.transpose = new_transpose
  
  -- Show appropriate status message
  local direction = (amount > 0) and ("+" .. amount) or tostring(amount)
  if was_clamped then
    if new_transpose == 120 then
      renoise.app():show_status("Instrument transpose clamped to maximum: +120 (was " .. current_transpose .. ")")
    else
      renoise.app():show_status("Instrument transpose clamped to minimum: -120 (was " .. current_transpose .. ")")
    end
  else
    renoise.app():show_status("Instrument transpose: " .. current_transpose .. " " .. direction .. " = " .. new_transpose)
  end
end

-- Function for absolute transpose (set to specific value)
function PakettiInstrumentTransposeAbsolute(value)
  local instrument = renoise.song().selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local old_transpose = instrument.transpose
  local original_value = value
  
  -- Clamp to valid range (-120 to +120)
  local was_clamped = false
  if value > 120 then
    value = 120
    was_clamped = true
  elseif value < -120 then
    value = -120
    was_clamped = true
  end
  
  -- Check if no change would occur
  if value == old_transpose then
    renoise.app():show_status("Instrument transpose already at: " .. value)
    return
  end
  
  instrument.transpose = value
  
  -- Show appropriate status message
  if was_clamped then
    if value == 120 then
      renoise.app():show_status("Instrument transpose clamped to maximum: +120 (requested " .. original_value .. ", was " .. old_transpose .. ")")
    else
      renoise.app():show_status("Instrument transpose clamped to minimum: -120 (requested " .. original_value .. ", was " .. old_transpose .. ")")
    end
  else
    renoise.app():show_status("Instrument transpose set to: " .. value .. " (was " .. old_transpose .. ")")
  end
end

-- Generate relative transpose menu entries (-120 to +120)
local transpose_categories = {
  {name = "Instrument Box", prefix = "Instrument Box"},
  {name = "Sample Navigator", prefix = "Sample Navigator"},
  {name = "Sample Mappings", prefix = "Sample Mappings"},
  {name = "Global", prefix = "Global"}
}

-- Most important ones first as requested by user
local priority_relative_values = {-1, 1}

-- Generate priority relative transpose MIDI mappings (once only) - only if enabled
if preferences.PakettiInstrumentTransposeCommands.value then
  for _, value in ipairs(priority_relative_values) do
    local sign = value >= 0 and "+" or ""
    local formatted_value = sign .. formatDigits3( math.abs(value))
    local midi_name = "Paketti:Instrument Transpose Relative (" .. formatted_value .. ")"
    
    renoise.tool():add_midi_mapping{
      name = midi_name,
      invoke = function(message)
        if message:is_trigger() then
          PakettiInstrumentTransposeRelative(value)
        end
      end
    }
  end
end

-- Generate priority relative transpose menu entries and keybindings per category - only if enabled
if preferences.PakettiInstrumentTransposeCommands.value then
  for _, category in ipairs(transpose_categories) do
    for _, value in ipairs(priority_relative_values) do
      local sign = value >= 0 and "+" or ""
      local formatted_value = sign .. formatDigits3( math.abs(value))
      local menu_name = category.prefix .. ":Paketti:Transpose:Relative " .. formatted_value
      local keybinding_name = category.prefix .. ":Paketti:Set Selected Instrument Transpose (" .. sign .. value .. ")"
      
      renoise.tool():add_menu_entry{
        name = menu_name,
        invoke = function() PakettiInstrumentTransposeRelative(value) end
      }
      
      renoise.tool():add_keybinding{
        name = keybinding_name, 
        invoke = function() PakettiInstrumentTransposeRelative(value) end
      }
    end
  end
end

-- Generate all relative transpose MIDI mappings (once only, excluding priority ones) - only if enabled
if preferences.PakettiInstrumentTransposeCommands.value then
  -- Negative values (-120 to -2)
  for value = -120, -2 do
    if value ~= -1 then -- Skip -1 as it's already added in priority
      local formatted_value = "-" .. formatDigits3( math.abs(value))
      local midi_name = "Paketti:Instrument Transpose Relative (" .. formatted_value .. ")"
      
      renoise.tool():add_midi_mapping{
        name = midi_name,
        invoke = function(message)
          if message:is_trigger() then
            PakettiInstrumentTransposeRelative(value)
          end
        end
      }
    end
  end

  -- Positive values (+2 to +120)
  for value = 2, 120 do
    if value ~= 1 then -- Skip +1 as it's already added in priority
      local formatted_value = "+" .. formatDigits3( value)
      local midi_name = "Paketti:Instrument Transpose Relative (" .. formatted_value .. ")"
      
      renoise.tool():add_midi_mapping{
        name = midi_name,
        invoke = function(message)
          if message:is_trigger() then
            PakettiInstrumentTransposeRelative(value)
          end
        end
      }
    end
  end
end

-- Generate all relative transpose menu entries and keybindings per category (-120 to +120, excluding priority ones) - only if enabled
if preferences.PakettiInstrumentTransposeCommands.value then
  for _, category in ipairs(transpose_categories) do
    -- Negative values (-120 to -2)
    for value = -120, -2 do
      if value ~= -1 then -- Skip -1 as it's already added in priority
        local formatted_value = "-" .. formatDigits3( math.abs(value))
        local menu_name = category.prefix .. ":Paketti:Transpose:Relative " .. formatted_value
        local keybinding_name = category.prefix .. ":Paketti:Set Selected Instrument Transpose (" .. value .. ")"
        
        renoise.tool():add_menu_entry{
          name = menu_name,
          invoke = function() PakettiInstrumentTransposeRelative(value) end
        }
        
        renoise.tool():add_keybinding{
          name = keybinding_name,
          invoke = function() PakettiInstrumentTransposeRelative(value) end
        }
      end
    end
    
    -- Positive values (+2 to +120)
    for value = 2, 120 do
      if value ~= 1 then -- Skip +1 as it's already added in priority
        local formatted_value = "+" .. formatDigits3( value)
        local menu_name = category.prefix .. ":Paketti:Transpose:Relative " .. formatted_value
        local keybinding_name = category.prefix .. ":Paketti:Set Selected Instrument Transpose (+" .. value .. ")"
        
        renoise.tool():add_menu_entry{
          name = menu_name,
          invoke = function() PakettiInstrumentTransposeRelative(value) end
        }
        
        renoise.tool():add_keybinding{
          name = keybinding_name,
          invoke = function() PakettiInstrumentTransposeRelative(value) end
        }
      end
    end
  end
end

-- Generate absolute transpose MIDI mappings (once only) - only if enabled
if preferences.PakettiInstrumentTransposeCommands.value then
  for value = -120, 120 do
    local formatted_value = (value >= 0) and ("+" .. formatDigits3( value)) or ("-" .. formatDigits3( math.abs(value)))
    local midi_name = "Paketti:Instrument Transpose Absolute (" .. formatted_value .. ")"
    
    renoise.tool():add_midi_mapping{
      name = midi_name,
      invoke = function(message)
        if message:is_trigger() then
          PakettiInstrumentTransposeAbsolute(value)
        end
      end
    }
  end
end

-- Generate absolute transpose menu entries and keybindings per category (-120 to +120) - only if enabled
if preferences.PakettiInstrumentTransposeCommands.value then
  for _, category in ipairs(transpose_categories) do
    for value = -120, 120 do
      local sign = value > 0 and "+" or ""
      local formatted_value = (value >= 0) and ("+" .. formatDigits3( value)) or ("-" .. formatDigits3( math.abs(value)))
      local menu_name = category.prefix .. ":Paketti:Transpose:Absolute " .. formatted_value
      local keybinding_name = category.prefix .. ":Paketti:Set Selected Instrument Transpose to " .. sign .. value
      
      renoise.tool():add_menu_entry{
        name = menu_name,
        invoke = function() PakettiInstrumentTransposeAbsolute(value) end
      }
      
      renoise.tool():add_keybinding{
        name = keybinding_name,
        invoke = function() PakettiInstrumentTransposeAbsolute(value) end
      }
    end
  end
end

-- Add reset MIDI mapping (once only) - only if enabled
if preferences.PakettiInstrumentTransposeCommands.value then
  renoise.tool():add_midi_mapping{
    name = "Paketti:Instrument Transpose Reset (+000)",
    invoke = function(message)
      if message:is_trigger() then
        PakettiInstrumentTransposeAbsolute(0)
      end
    end
  }
end

-- Add separator and reset option menu entries and keybindings per category - only if enabled
if preferences.PakettiInstrumentTransposeCommands.value then
  for _, category in ipairs(transpose_categories) do
    local menu_name = "--" .. category.prefix .. ":Paketti:Transpose:Reset to +000"
    local keybinding_name = category.prefix .. ":Paketti:Set Selected Instrument Transpose to 0 (Reset)"
    
    renoise.tool():add_menu_entry{
      name = menu_name,
      invoke = function() PakettiInstrumentTransposeAbsolute(0) end
    }
    
    renoise.tool():add_keybinding{
      name = keybinding_name,
      invoke = function() PakettiInstrumentTransposeAbsolute(0) end
    }
  end
end

-- Dialog variables
local transpose_dialog = nil
local transpose_vb = nil
local transpose_value = 0
local apply_to_tracks = true
local selected_instrument_index = 1
local instrument_indices = {}


-- Build instrument list for dropdown (only instruments with samples or plugins)
function PakettiInstrumentTransposeDialogBuildInstrumentList()
  local instrument_list = {}
  local instrument_indices = {}
  local song = renoise.song()
  
  for i = 1, #song.instruments do
    local instrument = song.instruments[i]
    -- Only include instruments that have samples or plugins (transpose actually matters)
    if #instrument.samples > 0 or instrument.plugin_properties.plugin_loaded then
      local name = instrument.name ~= "" and instrument.name or "Unnamed"
      table.insert(instrument_list, string.format("%02d: %s", i, name))
      table.insert(instrument_indices, i)
    end
  end
  
  return instrument_list, instrument_indices
end

-- Update transpose slider value and label
function PakettiInstrumentTransposeDialogUpdateValue(new_value)
  if not transpose_vb then return end
  
  -- Ensure integer value and clamp to valid range (-64 to +64)
  transpose_value = math.max(-64, math.min(64, math.floor(new_value + 0.5)))
  
  -- Update slider
  if transpose_vb.views.transpose_slider then
    transpose_vb.views.transpose_slider.value = transpose_value + 64 -- Convert to 0-128 range for slider
  end
  
  -- Update label with instrument info
  if transpose_vb.views.transpose_label then
    local sign = transpose_value >= 0 and "+" or ""
    local apply_text = apply_to_tracks and " (+ All Tracks)" or " (Instrument Only)"
    transpose_vb.views.transpose_label.text = string.format("Set to: %s%d%s", 
      sign, transpose_value, apply_text)
  end
end

-- Apply the transpose value to the selected instrument and optionally all tracks
function PakettiInstrumentTransposeDialogApply()
  local song = renoise.song()
  local actual_instrument_index = instrument_indices[selected_instrument_index]
  local instrument = song.instruments[actual_instrument_index]
  if not instrument then
    renoise.app():show_status("No instrument found at index " .. actual_instrument_index)
    return
  end
  
  local old_transpose = instrument.transpose
  
  -- Apply to instrument directly
  instrument.transpose = math.max(-120, math.min(120, transpose_value))
  
  -- Apply to all tracks if enabled
  if apply_to_tracks then
    local tracks_changed = 0
    local transpose_diff = transpose_value - old_transpose
    
    for track_index = 1, #renoise.song().tracks do
      local track = renoise.song().tracks[track_index]
      local track_uses_instrument = false
      
      -- Check if track uses this instrument in any pattern
      for pattern_index = 1, #renoise.song().sequencer.pattern_sequence do
        local pattern = renoise.song().patterns[renoise.song().sequencer.pattern_sequence[pattern_index]]
        if pattern and pattern.tracks[track_index] then
          local track_in_pattern = pattern.tracks[track_index]
          
          -- Check all lines and all note columns for this instrument
          for line_index = 1, track_in_pattern.number_of_lines do
            local line = track_in_pattern:line(line_index)
            
            -- Check all note columns, not just the first one
            for note_column_index = 1, #line.note_columns do
              local note_column = line.note_columns[note_column_index]
              if note_column.instrument_value == actual_instrument_index - 1 then
                track_uses_instrument = true
                break
              end
            end
            
            if track_uses_instrument then
              break
            end
          end
          
          if track_uses_instrument then
            break
          end
        end
      end
      
      -- Apply transpose to track if it uses this instrument
      if track_uses_instrument then
        track.transpose = math.max(-127, math.min(127, track.transpose + transpose_diff))
        tracks_changed = tracks_changed + 1
      end
    end
    
    local instrument_name = (instrument.name ~= "") and instrument.name or "Unnamed"
    if tracks_changed > 0 then
      renoise.app():show_status(string.format("Applied transpose %+d to instrument %02d: %s and %d tracks", transpose_value, actual_instrument_index, instrument_name, tracks_changed))
    else
      renoise.app():show_status(string.format("Applied transpose %+d to instrument %02d: %s (no tracks found using this instrument)", transpose_value, actual_instrument_index, instrument_name))
    end
  else
    local instrument_name = (instrument.name ~= "") and instrument.name or "Unnamed"
    renoise.app():show_status(string.format("Applied transpose %+d to instrument %02d: %s", transpose_value, actual_instrument_index, instrument_name))
  end
end

-- Create the transpose dialog
function PakettiInstrumentTransposeDialog()
  -- Check if dialog is already open and close it
  if transpose_dialog and transpose_dialog.visible then
    transpose_dialog:close()
    transpose_dialog = nil
    transpose_vb = nil
    return
  end

  -- Initialize with instruments that have samples or plugins
  local song = renoise.song()
  local instrument_list, available_indices = PakettiInstrumentTransposeDialogBuildInstrumentList()
  instrument_indices = available_indices
  
  if #instrument_indices == 0 then
    renoise.app():show_status("No instruments with samples or plugins found")
    return
  end
  
  -- Find current selected instrument in our filtered list, or use first available
  selected_instrument_index = 1 -- Default to first in popup
  local current_selected = song.selected_instrument_index
  for i, actual_index in ipairs(instrument_indices) do
    if actual_index == current_selected then
      selected_instrument_index = i
      break
    end
  end
  
  -- Get the actual instrument
  local actual_instrument_index = instrument_indices[selected_instrument_index]
  local instrument = song.instruments[actual_instrument_index]

  -- Initialize transpose value to selected instrument transpose, clamped to dialog range
  transpose_value = math.max(-64, math.min(64, instrument.transpose))
  
  -- Create ViewBuilder
  transpose_vb = renoise.ViewBuilder()
  
  -- Create instrument selection dropdown
  local instrument_selector = transpose_vb:row{
    
    transpose_vb:text{
      text = "Instrument:",
      style = "strong",
      width = 80
    },
    transpose_vb:popup{
      id = "instrument_popup",
      items = instrument_list,
      value = selected_instrument_index,
      width = 300,
      notifier = function(value)
        selected_instrument_index = value
        local actual_instrument_index = instrument_indices[selected_instrument_index]
        local new_instrument = renoise.song().instruments[actual_instrument_index]
        if new_instrument then
          -- Update transpose value to match the newly selected instrument
          transpose_value = math.max(-64, math.min(64, new_instrument.transpose))
          PakettiInstrumentTransposeDialogUpdateValue(transpose_value)
        end
      end
    }
  }
  
  -- Create preset value buttons
  local preset_buttons = transpose_vb:column{
    
    -- Main preset buttons
    transpose_vb:row{
    
      transpose_vb:button{
        text = "-36",
        width = 40,
        notifier = function()
          PakettiInstrumentTransposeDialogUpdateValue(-36)
        end
      },
      transpose_vb:button{
        text = "-24",
        width = 40,
        notifier = function()
          PakettiInstrumentTransposeDialogUpdateValue(-24)
        end
      },
      transpose_vb:button{
        text = "-12",
        width = 40,
        notifier = function()
          PakettiInstrumentTransposeDialogUpdateValue(-12)
        end
      },
      transpose_vb:button{
        text = "0",
        width = 40,
        notifier = function()
          PakettiInstrumentTransposeDialogUpdateValue(0)
        end
      },
      transpose_vb:button{
        text = "+12",
        width = 40,
        notifier = function()
          PakettiInstrumentTransposeDialogUpdateValue(12)
        end
      },
      transpose_vb:button{
        text = "+24",
        width = 40,
        notifier = function()
          PakettiInstrumentTransposeDialogUpdateValue(24)
        end
      },
      transpose_vb:button{
        text = "+36",
        width = 40,
        notifier = function()
          PakettiInstrumentTransposeDialogUpdateValue(36)
        end
      }
    },
    -- Extreme value buttons
    transpose_vb:row{
      transpose_vb:button{
        text = "-127",
        width = 50,
        notifier = function()
          PakettiInstrumentTransposeDialogUpdateValue(-127)
        end
      },
      transpose_vb:button{
        text = "-60",
        width = 40,
        notifier = function()
          PakettiInstrumentTransposeDialogUpdateValue(-60)
        end
      },
      transpose_vb:button{
        text = "-48",
        width = 40,
        notifier = function()
          PakettiInstrumentTransposeDialogUpdateValue(-48)
        end
      },
      transpose_vb:button{
        text = "+48",
        width = 40,
        notifier = function()
          PakettiInstrumentTransposeDialogUpdateValue(48)
        end
      },
      transpose_vb:button{
        text = "+60",
        width = 40,
        notifier = function()
          PakettiInstrumentTransposeDialogUpdateValue(60)
        end
      },
      transpose_vb:button{
        text = "+127",
        width = 50,
        notifier = function()
          PakettiInstrumentTransposeDialogUpdateValue(127)
        end
      }
    }
  }
  
  -- Create checkbox row for track application
  local track_options = transpose_vb:row{

    transpose_vb:checkbox{
      id = "apply_to_tracks_checkbox",
      value = apply_to_tracks,
      notifier = function(value)
        apply_to_tracks = value
        PakettiInstrumentTransposeDialogUpdateValue(transpose_value) -- Update label
      end
    },
    transpose_vb:text{
      text = "Also apply transpose to all tracks using this instrument",
      style = "strong"
    }
  }
  
  -- Create slider and label row
  local slider_row = transpose_vb:row{
    
    transpose_vb:slider{
      id = "transpose_slider",
      min = 0,
      max = 128,
      value = transpose_value + 64, -- Convert -64 to +64 range to 0-128 range
      width = 300,
      notifier = function(value)
        local new_transpose = math.floor(value + 0.5) - 64 -- Convert back to -64 to +64 range and ensure integer
        PakettiInstrumentTransposeDialogUpdateValue(new_transpose)
      end
    },
    transpose_vb:text{
      id = "transpose_label",
      text = "Transpose: " .. (transpose_value >= 0 and "+" or "") .. transpose_value,
      font = "bold",
      width = 120
    }
  }
  
  -- Create action buttons
  local action_buttons = transpose_vb:row{
    
    transpose_vb:button{
      text = "Apply",
      width = 80,
      notifier = function()
        PakettiInstrumentTransposeDialogApply()
      end
    },
    transpose_vb:button{
      text = "OK",
      width = 80,
      notifier = function()
        PakettiInstrumentTransposeDialogApply()
        transpose_dialog:close()
        transpose_dialog = nil
        transpose_vb = nil
      end
    },
    transpose_vb:button{
      text = "Cancel",
      width = 80,
      notifier = function()
        transpose_dialog:close()
        transpose_dialog = nil
        transpose_vb = nil
      end
    }
  }
  
  -- Create main dialog content
  local dialog_content = transpose_vb:column{    
    instrument_selector,
    preset_buttons,
    track_options,
    slider_row,
    action_buttons
  }
  
  -- Create keyhandler
  local keyhandler = create_keyhandler_for_dialog(
    function() return transpose_dialog end,
    function(value) transpose_dialog = value end
  )
  
  -- Show dialog
  transpose_dialog = renoise.app():show_custom_dialog(
    "Paketti Instrument Transpose",
    dialog_content,
    keyhandler
  )
  
  -- Set focus back to Renoise after dialog opens
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  -- Update initial display
  PakettiInstrumentTransposeDialogUpdateValue(transpose_value)
end
