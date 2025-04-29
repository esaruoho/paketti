local dialog = nil
local view_builder = nil
local is_updating_textfield = false
local debug_mode = true -- Set to true to see what's happening

local function debug_print(...)
  if debug_mode then
    print(...)
  end
end

-- Helper function to focus textfield
local function focus_textfield()
  if view_builder and view_builder.views.length_textfield then
    local textfield = view_builder.views.length_textfield
    -- First reset the state
    textfield.active = false
    textfield.edit_mode = false
    -- Then immediately set active and edit mode
    textfield.active = true
    textfield.edit_mode = true
    debug_print("Reset and set textfield focus")
  end
end

-- Helper function to check if we're in pattern editor
local function is_in_pattern_editor()
  return renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Helper function to check if we're in phrase editor with valid phrase
local function is_in_phrase_editor()
  if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
    local song=renoise.song()
    return song.selected_phrase_index > 0 and 
           song.selected_instrument and 
           song.selected_instrument.phrase_editor_visible and
           song.selected_phrase
  end
  return false
end

-- Helper function to get the appropriate LPB based on context
local function get_context_lpb()
  local song=renoise.song()
  
  -- Check if we're in phrase editor with valid phrase
  if is_in_phrase_editor() then
    -- Use phrase LPB
    return song.selected_phrase.lpb
  else
    -- Use transport LPB for pattern editor
    return song.transport.lpb
  end
end

-- Helper function to adjust pattern or phrase length by a relative amount
local function adjust_length_by(amount)
  local song=renoise.song()
  local current_length
  local new_length
  local is_pattern_editor = is_in_pattern_editor()
  
  -- If not in pattern editor, check if we're in phrase editor with valid phrase
  if not is_pattern_editor and not is_in_phrase_editor() then
    -- Not in either editor or no valid phrase, do nothing
    return
  end
  
  -- Get current length based on editor context
  if is_pattern_editor then
    current_length = song.selected_pattern.number_of_lines
  else
    current_length = song.selected_phrase.number_of_lines
  end
  
  -- If amount is 'lpb', get the appropriate LPB value based on context
  if type(amount) == "string" then
    if amount == "lpb" then
      amount = get_context_lpb()
    elseif amount == "-lpb" then
      amount = -get_context_lpb()
    end
  end
  
  -- Calculate new length based on direction
  if amount > 0 then
    -- When increasing, round up to next multiple
    new_length = math.ceil(current_length / amount) * amount
    -- If we're already at a multiple, go to next one
    if new_length == current_length then
      new_length = new_length + amount
    end
  else
    -- When decreasing, round down to previous multiple
    new_length = math.floor(current_length / math.abs(amount)) * math.abs(amount)
    -- If we're already at a multiple, go to previous one
    if new_length == current_length then
      new_length = new_length + amount
    end
  end
  
  -- Clamp within valid range (different max for patterns and phrases)
  local max_lines = is_pattern_editor and renoise.Pattern.MAX_NUMBER_OF_LINES or renoise.InstrumentPhrase.MAX_NUMBER_OF_LINES
  new_length = math.floor(math.min(math.max(new_length, 1), max_lines))
  
  -- Only apply if actually changed
  if new_length ~= current_length then
    if is_pattern_editor then
      song.selected_pattern.number_of_lines = new_length
      renoise.app():show_status("Pattern length set to " .. formatDigits(3,new_length))
    else
      song.selected_phrase.number_of_lines = new_length
      renoise.app():show_status("Phrase length set to " .. formatDigits(3,new_length))
    end
  end
end

-- Notifier for when the selected pattern/phrase changes
local function length_change_notifier()
  -- First check if we're already updating to prevent recursion
  if is_updating_textfield then
    debug_print("Length change notifier: Skipping due to is_updating_textfield flag")
    return
  end

  -- Basic validity checks
  if not dialog or not dialog.visible then
    debug_print("Length change notifier: Dialog not visible, skipping update")
    return
  end

  if not view_builder then
    debug_print("Length change notifier: No view builder, skipping update")
    return
  end

  if not view_builder.views or not view_builder.views.length_textfield then
    debug_print("Length change notifier: No length textfield view, skipping update")
    return
  end

  -- Mark start of programmatic update
  is_updating_textfield = true
  debug_print("Length change notifier: Starting textfield update")

  -- Get the new length based on editor context
  local song=renoise.song()
  local new_length
  local is_pattern_editor = is_in_pattern_editor()
  
  if is_pattern_editor then
    new_length = tostring(song.selected_pattern.number_of_lines)
  else
    new_length = tostring(song.selected_phrase.number_of_lines)
  end
  
  -- Update the textfield value
  local textfield = view_builder.views.length_textfield
  if textfield.value ~= new_length then
    debug_print(string.format("Length change notifier: Updating textfield from %s to %s", 
      textfield.value, new_length))
    -- Set value and focus to ensure it's selected
    textfield.value = new_length
    focus_textfield()
  else
    debug_print("Length change notifier: Value unchanged, skipping update")
  end

  -- End of programmatic update
  is_updating_textfield = false
  debug_print("Length change notifier: Update complete")
end

-- Apply and clamp the new length value
local function apply_length_value(value)
  local song=renoise.song()
  local is_pattern_editor = is_in_pattern_editor()
  
  -- If not in pattern editor, check if we're in phrase editor with valid phrase
  if not is_pattern_editor and not is_in_phrase_editor() then
    -- Not in either editor or no valid phrase, do nothing
    renoise.app():show_status("Please switch to Pattern Editor or Phrase Editor")
    return
  end

  -- Convert to number
  local new_length = tonumber(value)
  if not new_length then
    renoise.app():show_status("Please enter a valid number")
    debug_print("Apply length: Invalid number entered")
    return
  end

  -- Clamp within valid range
  local max_lines = is_pattern_editor and renoise.Pattern.MAX_NUMBER_OF_LINES or renoise.InstrumentPhrase.MAX_NUMBER_OF_LINES
  new_length = math.floor(math.min(math.max(new_length, 1), max_lines))

  -- Set the length based on context
  if is_pattern_editor then
    song.selected_pattern.number_of_lines = new_length
    renoise.app():show_status(string.format("Pattern length set to %d", new_length))
  else
    -- Double check that we still have a valid phrase
    if song.selected_phrase then
      song.selected_phrase.number_of_lines = new_length
      renoise.app():show_status(string.format("Phrase length set to %d", new_length))
    else
      renoise.app():show_status("No valid phrase selected")
      debug_print("Apply length: No valid phrase selected")
    end
  end
  
  debug_print(string.format("Apply length: Set %s length to %d", 
    is_pattern_editor and "pattern" or "phrase", new_length))
end

-- Notifier for the textfield (user edits only)
local function length_textfield_notifier(new_value)
  -- If we're in a programmatic update, do nothing
  if is_updating_textfield then
    debug_print("Textfield notifier: Skipping due to is_updating_textfield flag")
    return
  end

  if not new_value or new_value == "" then
    debug_print("Textfield notifier: Empty value, skipping")
    return
  end

  debug_print(string.format("Textfield notifier: Processing new value: %s", new_value))

  -- Apply the entered value
  apply_length_value(new_value)

  -- If "Close on Set" is checked, remove notifier and close
  if view_builder.views.close_on_set_checkbox.value then
    debug_print("Textfield notifier: Close on Set is checked, closing dialog")
    cleanup_dialog()
  else
    -- Otherwise, refocus the textfield for the next edit
    focus_textfield()
  end
end

-- Clean up function to remove notifiers and reset state
local function cleanup_dialog()
  if dialog and dialog.visible then
    debug_print("Cleanup: Starting dialog cleanup")
    local song=renoise.song()
    
    -- Remove pattern notifier if exists
    local pattern_observable = song.selected_pattern_observable
    if pattern_observable:has_notifier(length_change_notifier) then
      pattern_observable:remove_notifier(length_change_notifier)
      debug_print("Cleanup: Removed pattern change notifier")
    end
    
    -- Remove phrase notifier if exists
    if song.selected_phrase_observable:has_notifier(length_change_notifier) then
      song.selected_phrase_observable:remove_notifier(length_change_notifier)
      debug_print("Cleanup: Removed phrase change notifier")
    end
    
    dialog:close()
    dialog = nil
    view_builder = nil
    is_updating_textfield = false
    debug_print("Cleanup: Dialog cleanup complete")
  end
end

-- Show or toggle the Length dialog
function show_length_dialog()
  -- If already open, clean up and close
  if dialog and dialog.visible then
    debug_print("Show dialog: Dialog already open, cleaning up")
    cleanup_dialog()
    return
  end

  -- Check which editor we're in
  local is_pattern_editor = is_in_pattern_editor()
  
  -- If not in pattern editor, check if we're in phrase editor with valid phrase
  if not is_pattern_editor and not is_in_phrase_editor() then
    renoise.app():show_status("Please switch to Pattern Editor or Phrase Editor")
    return
  end

  debug_print("Show dialog: Creating new dialog")

  -- Build the UI
  view_builder = renoise.ViewBuilder()
  local song=renoise.song()
  
  -- Get initial value based on context
  local initial_value = is_pattern_editor and 
    tostring(song.selected_pattern.number_of_lines) or 
    tostring(song.selected_phrase.number_of_lines)

  local length_textfield = view_builder:textfield{
    width=60,
    id = "length_textfield",
    value = initial_value,
    edit_mode = true,
    notifier = length_textfield_notifier
  }

  local close_on_set_checkbox = view_builder:checkbox{
    id = "close_on_set_checkbox",
    value = false,  -- Default to false so dialog stays open
    notifier = function()
      -- Only refocus the textfield, don't trigger any value changes
      focus_textfield()
    end
  }

  -- "Cancel" button
  local cancel_button = view_builder:button{
    text="Cancel",
    notifier = function()
      debug_print("Cancel button: Cleaning up dialog")
      cleanup_dialog()
    end
  }

  -- "Set" button applies the value just like pressing Enter
  local set_button = view_builder:button{
    text="Set",
    notifier = function()
      if view_builder and view_builder.views.length_textfield then
        debug_print("Set button: Processing textfield value")
        local current_value = view_builder.views.length_textfield.value
        length_textfield_notifier(current_value)
      end
    end
  }

  -- Show the custom dialog with context-aware title
  dialog = renoise.app():show_custom_dialog(is_pattern_editor and "Set Pattern Length" or "Set Phrase Length",
    view_builder:column{
      --margin=10,
      --spacing=6,
      view_builder:row{ length_textfield, view_builder:text{ text=" lines" } },
      view_builder:row{ view_builder:text{ text="Close on Set" }, close_on_set_checkbox },
      view_builder:row{ cancel_button, set_button }
    }
  )

  -- Add appropriate change observer based on context
  if is_pattern_editor then
    local pattern_observable = song.selected_pattern_observable
    if not pattern_observable:has_notifier(length_change_notifier) then
      pattern_observable:add_notifier(length_change_notifier)
      debug_print("Show dialog: Added pattern change notifier")
    end
  else
    if not song.selected_phrase_observable:has_notifier(length_change_notifier) then
      song.selected_phrase_observable:add_notifier(length_change_notifier)
      debug_print("Show dialog: Added phrase change notifier")
    end
  end

  -- Initial focus
  focus_textfield()
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show Pattern Length Dialog...",invoke=function() show_length_dialog() end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Show Phrase Length Dialog...",invoke=function() show_length_dialog() end}
renoise.tool():add_keybinding{name="Global:Paketti:Show Pattern/Phrase Length Dialog...",invoke=function() show_length_dialog() end}
renoise.tool():add_midi_mapping{name="Paketti:Show Pattern/Phrase Length Dialog...",invoke=function(message) if message:is_trigger() then show_length_dialog() end end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern/Phrase Length Dialog...",invoke=function() show_length_dialog() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Pattern Editor..:Pattern Length Increase by 8",invoke=function() adjust_length_by(8) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Pattern Length Decrease by 8",invoke=function() adjust_length_by(-8) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Pattern Length Increase by LPB",invoke=function() adjust_length_by("lpb") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Pattern Length Decrease by LPB",invoke=function() adjust_length_by("-lpb") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Increase Pattern Length by 8",invoke=function() adjust_length_by(8) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Decrease Pattern Length by 8",invoke=function() adjust_length_by(-8) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Increase Pattern Length by LPB",invoke=function() adjust_length_by("lpb") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Decrease Pattern Length by LPB",invoke=function() adjust_length_by("-lpb") end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Phrase Editor..:Phrase Length Increase by 8",invoke=function() adjust_length_by(8) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Phrase Editor..:Phrase Length Decrease by 8",invoke=function() adjust_length_by(-8) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Phrase Editor..:Phrase Length Increase by LPB",invoke=function() adjust_length_by("lpb") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Phrase Editor..:Phrase Length Decrease by LPB",invoke=function() adjust_length_by("-lpb") end}
renoise.tool():add_keybinding{name="--Phrase Editor:Paketti:Increase Phrase Length by 8",invoke=function() adjust_length_by(8) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Decrease Phrase Length by 8",invoke=function() adjust_length_by(-8) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Increase Phrase Length by LPB",invoke=function() adjust_length_by("lpb") end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Decrease Phrase Length by LPB",invoke=function() adjust_length_by("-lpb") end}

