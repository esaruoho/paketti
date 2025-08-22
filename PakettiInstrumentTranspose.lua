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

-- Generate priority relative transpose MIDI mappings (once only)
for _, value in ipairs(priority_relative_values) do
  local sign = value >= 0 and "+" or ""
  local formatted_value = sign .. formatDigits(3, math.abs(value))
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

-- Generate priority relative transpose menu entries and keybindings per category
for _, category in ipairs(transpose_categories) do
  for _, value in ipairs(priority_relative_values) do
    local sign = value >= 0 and "+" or ""
    local formatted_value = sign .. formatDigits(3, math.abs(value))
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

-- Generate all relative transpose MIDI mappings (once only, excluding priority ones)
-- Negative values (-120 to -2)
for value = -120, -2 do
  if value ~= -1 then -- Skip -1 as it's already added in priority
    local formatted_value = "-" .. formatDigits(3, math.abs(value))
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
    local formatted_value = "+" .. formatDigits(3, value)
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

-- Generate all relative transpose menu entries and keybindings per category (-120 to +120, excluding priority ones)
for _, category in ipairs(transpose_categories) do
  -- Negative values (-120 to -2)
  for value = -120, -2 do
    if value ~= -1 then -- Skip -1 as it's already added in priority
      local formatted_value = "-" .. formatDigits(3, math.abs(value))
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
      local formatted_value = "+" .. formatDigits(3, value)
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

-- Generate absolute transpose MIDI mappings (once only)
for value = -120, 120 do
  local formatted_value = (value >= 0) and ("+" .. formatDigits(3, value)) or ("-" .. formatDigits(3, math.abs(value)))
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

-- Generate absolute transpose menu entries and keybindings per category (-120 to +120)
for _, category in ipairs(transpose_categories) do
  for value = -120, 120 do
    local sign = value > 0 and "+" or ""
    local formatted_value = (value >= 0) and ("+" .. formatDigits(3, value)) or ("-" .. formatDigits(3, math.abs(value)))
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

-- Add reset MIDI mapping (once only)
renoise.tool():add_midi_mapping{
  name = "Paketti:Instrument Transpose Reset (+000)",
  invoke = function(message)
    if message:is_trigger() then
      PakettiInstrumentTransposeAbsolute(0)
    end
  end
}

-- Add separator and reset option menu entries and keybindings per category
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




