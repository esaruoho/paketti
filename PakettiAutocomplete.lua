-- PakettiAutocomplete.lua
-- Autocomplete dialog system with real-time filtering and selection

-- Dialog and UI state variables
local autocomplete_dialog = nil
local autocomplete_vb = nil
local suggestion_buttons = {}
local search_textfield = nil
local status_text = nil
local current_filter = ""
local current_filtered_commands = {}
local selected_suggestion_index = 1

-- Predefined list of commands/actions
local autocomplete_commands = {
  "do this",
  "do nothing", 
  "do something amazing",
  "do not disturb",
  "do a barrel roll",
  "do the dishes",
  "do your homework", 
  "do it now",
  "do not pass go",
  "do the right thing",
  "process samples",
  "process audio", 
  "process selection",
  "create new instrument",
  "create new phrase",
  "create automation",
  "load random samples",
  "load drumkit",
  "load wavetable",
  "apply reverb",
  "apply delay",
  "apply distortion",
  "slice and dice", 
  "slice to pattern",
  "slice to phrases",
  "transpose up",
  "transpose down",
  "transpose octave",
  "pitch bend setup",
  "pitch correction",
  "volume normalize",
  "volume fade in",
  "volume fade out",
  "render to sample",
  "render to file",
  "render selection"
}

-- Function to filter commands based on input
local function filter_commands(filter_text)
  if not filter_text or filter_text == "" then
    return autocomplete_commands
  end
  
  local filtered = {}
  local filter_lower = string.lower(filter_text)
  
  for _, command in ipairs(autocomplete_commands) do
    if string.find(string.lower(command), filter_lower, 1, true) then
      table.insert(filtered, command)
    end
  end
  

  
  return filtered
end

-- Function to execute selected command
local function execute_command(command)
  if command == "do this" then
    renoise.app():show_error("Executing: " .. command .. " - This is where magic happens!")
  elseif command == "do nothing" then
    renoise.app():show_error("Executing: " .. command .. " - Successfully did absolutely nothing!")
  else
    renoise.app():show_error("Executing: " .. command .. " - Command executed successfully!")
  end
  
  -- Return focus to the dialog after command execution
  if autocomplete_dialog and autocomplete_dialog.visible then
    autocomplete_dialog:show()
  end
end

-- Function to handle button clicks
local function handle_suggestion_click(button_index)
  if current_filtered_commands[button_index] then
    -- Set selection to clicked button and execute
    selected_suggestion_index = button_index
    execute_command(current_filtered_commands[button_index])
  end
end

-- Function to execute selected suggestion (for Enter key)
local function execute_selected_suggestion()
  if #current_filtered_commands > 0 and selected_suggestion_index >= 1 and selected_suggestion_index <= #current_filtered_commands then
    execute_command(current_filtered_commands[selected_suggestion_index])
  end
end

-- Function to move selection up
local function move_selection_up()
  if #current_filtered_commands > 0 then
    if selected_suggestion_index == 1 then
      -- When at topmost suggestion, focus textfield instead of wrapping
      selected_suggestion_index = 0
      if search_textfield then
        search_textfield.edit_mode = true
      end
    else
      selected_suggestion_index = selected_suggestion_index - 1
      if selected_suggestion_index < 1 then
        selected_suggestion_index = math.min(#current_filtered_commands, 10) -- Wrap to bottom
      end
    end
    update_button_display()
  end
end

-- Function to move selection down  
local function move_selection_down()
  if #current_filtered_commands > 0 then
    if selected_suggestion_index == 0 then
      -- Moving from textfield to first suggestion
      selected_suggestion_index = 1
      if search_textfield then
        search_textfield.edit_mode = false
      end
    else
      selected_suggestion_index = selected_suggestion_index + 1
      local max_visible = math.min(#current_filtered_commands, 10)
      if selected_suggestion_index > max_visible then
        selected_suggestion_index = 1 -- Wrap to top
      end
    end
    update_button_display()
  end
end

-- Function to update button display (separated from update_suggestions)
function update_button_display()
  -- Update existing suggestion buttons
  for i = 1, 10 do
    if suggestion_buttons[i] then
      if i <= #current_filtered_commands then
        -- Show button with command text
        local button_text = current_filtered_commands[i]
        if i == selected_suggestion_index then
          -- Mark selected suggestion
          button_text = "► " .. button_text .. " ◄"
        end
        suggestion_buttons[i].text = button_text
        suggestion_buttons[i].visible = true
      else
        -- Hide unused buttons
        suggestion_buttons[i].visible = false
      end
    end
  end
end

-- Custom keyhandler for the dialog
local function autocomplete_keyhandler(dialog, key)
  if key.name == "return" then
    -- If we have suggestions, execute selected one. Otherwise let textfield handle it.
    if #current_filtered_commands > 0 and selected_suggestion_index > 0 then
      execute_selected_suggestion()
    end
    return key
  elseif key.name == "up" then
    move_selection_up()
    return nil  -- Consume the key
  elseif key.name == "down" then
    move_selection_down()
    return nil  -- Consume the key
  elseif key.name == "tab" then
    -- Force update suggestions when Tab is pressed
    if search_textfield then
      local current_text = search_textfield.text
      update_suggestions(current_text)
    end
    return key
  elseif key.name == "esc" then
    close_autocomplete_dialog()
    return key
  else
    -- Check if it's a typing key (letters, numbers, space, backspace, delete)
    local is_typing_key = false
    
    -- Single character keys (letters, numbers, symbols)
    if string.len(key.name) == 1 then
      is_typing_key = true
    -- Special typing keys
    elseif key.name == "space" or key.name == "backspace" or key.name == "delete" then
      is_typing_key = true
    end
    
    -- If it's a typing key, let it through and then update suggestions
    if is_typing_key then
      -- Use a timer to update suggestions after the textfield has been updated
      renoise.tool():add_timer(function()
        if search_textfield then
          local current_text = search_textfield.text
          update_suggestions(current_text)
        end
      end, 1)  -- 1ms delay to ensure textfield is updated first
      
      return key  -- Let the key pass through to the textfield
    else
      -- Let other keys pass through to Renoise
      return key
    end
  end
end

-- Function to update suggestions list
local function update_suggestions(filter_text)
  current_filter = filter_text or ""
  

  
  -- Get filtered commands
  current_filtered_commands = filter_commands(current_filter)
  
  -- Keep textfield focused when user is typing (don't auto-select first suggestion)
  selected_suggestion_index = 0
  
  -- Make sure selection is valid if user had previously navigated to suggestions
  if #current_filtered_commands == 0 then
    selected_suggestion_index = 0
  end
  
  -- Update status text
  if status_text then
    local status_msg = string.format("(%d matches)", #current_filtered_commands)
    if current_filter ~= "" then
      status_msg = string.format("'%s' - %d matches", current_filter, #current_filtered_commands)
    end
    if #current_filtered_commands > 0 and selected_suggestion_index > 0 then
      status_msg = status_msg .. string.format(" - Item %d selected", selected_suggestion_index)
    end
    status_text.text = status_msg
  end
  
  -- Update button display
  update_button_display()
end

-- Function to close autocomplete dialog
local function close_autocomplete_dialog()
  if autocomplete_dialog and autocomplete_dialog.visible then
    autocomplete_dialog:close()
    autocomplete_dialog = nil
    autocomplete_vb = nil
    search_textfield = nil
    status_text = nil
    suggestion_buttons = {}
    current_filtered_commands = {}
    current_filter = ""
    selected_suggestion_index = 1
  end
end

-- Main dialog function
function pakettiAutocompleteDialog()
  -- Close existing dialog if open
  close_autocomplete_dialog()
  
  -- Create fresh ViewBuilder instance
  autocomplete_vb = renoise.ViewBuilder()
  
  -- Initialize with all commands
  current_filtered_commands = autocomplete_commands
  
  -- Create fixed suggestion buttons (max 10)
  suggestion_buttons = {}
  local suggestion_views = {}
  
  for i = 1, 10 do
    local button_text = ""
    local button_visible = false
    
    if i <= #current_filtered_commands then
      button_text = current_filtered_commands[i]
      button_visible = true
    end
    
    suggestion_buttons[i] = autocomplete_vb:button{
      text = button_text,
      width = 380,
      height = 20,
      visible = button_visible,
      notifier = function()
        handle_suggestion_click(i)
      end
    }
    
    table.insert(suggestion_views, suggestion_buttons[i])
  end
  
  -- Create dialog content
  local dialog_content = autocomplete_vb:column{
    margin = 10,
    
    
    autocomplete_vb:row{
      autocomplete_vb:text{
        text = "Type command:",
        width = 80
      },
      (function()
        search_textfield = autocomplete_vb:textfield{
          width = 300,
          edit_mode = true,
          notifier = function(text)
            update_suggestions(text)
          end
        }
        return search_textfield
      end)()
    },
    
    --autocomplete_vb:space{height = 10},
    
    autocomplete_vb:row{
      autocomplete_vb:text{
        text = "Suggestions:",
        style = "strong",
        width = 200
      },
      (function()
        status_text = autocomplete_vb:text{
          text = string.format("(%d matches)", #autocomplete_commands),
          style = "disabled",
          width = 200
        }
        return status_text
      end)()
    },
    
    --autocomplete_vb:space{height = 5},
    
    -- Container for fixed suggestion buttons
    autocomplete_vb:column(suggestion_views),
    
    --autocomplete_vb:space{height = 10},
    
    --autocomplete_vb:space{height = 5},
    
    autocomplete_vb:text{
      text = "Type to filter • Use ↑/↓ to navigate • Enter to execute • Esc to close",
      style = "disabled",
      width = 400
    },
    
    --autocomplete_vb:space{height = 5},
    
    autocomplete_vb:row{
      autocomplete_vb:button{
        text = "Close",
        width = 100,
        notifier = close_autocomplete_dialog
      },
      autocomplete_vb:space{width = 280},
      autocomplete_vb:text{
        text = string.format("(%d commands available)", #autocomplete_commands),
        style = "disabled",
        width = 120
      }
    }
  }
  
  -- Create and show dialog
  autocomplete_dialog = renoise.app():show_custom_dialog(
    "Paketti Autocomplete", 
    dialog_content,
    autocomplete_keyhandler
  )
  
  -- Set initial selection and update display
  selected_suggestion_index = 1
  update_button_display()
  
  -- Set focus to Renoise after dialog opens
  --renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  return autocomplete_dialog
end

-- Function to toggle autocomplete dialog
function pakettiAutocompleteToggle()
  if autocomplete_dialog and autocomplete_dialog.visible then
    close_autocomplete_dialog()
  else
    pakettiAutocompleteDialog()
  end
end

-- Menu entries
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Paketti Autocomplete...", invoke=pakettiAutocompleteToggle}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti Gadgets:Paketti Autocomplete...", invoke=pakettiAutocompleteToggle}
renoise.tool():add_menu_entry{name="--Mixer:Paketti Gadgets:Paketti Autocomplete...", invoke=pakettiAutocompleteToggle}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti Gadgets:Paketti Autocomplete...", invoke=pakettiAutocompleteToggle}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti Gadgets:Paketti Autocomplete...", invoke=pakettiAutocompleteToggle}

-- Keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Autocomplete", invoke=pakettiAutocompleteToggle}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Paketti Autocomplete", invoke=pakettiAutocompleteToggle}
renoise.tool():add_keybinding{name="Mixer:Paketti:Paketti Autocomplete", invoke=pakettiAutocompleteToggle}

-- MIDI mappings  
renoise.tool():add_midi_mapping{name="Paketti:Paketti Autocomplete", invoke=function(message) if message:is_trigger() then pakettiAutocompleteToggle() end end} 