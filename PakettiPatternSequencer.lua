-- Get preferences from the tool
local preferences = renoise.tool().preferences

-- Function to show the settings dialog
function pakettiSequencerSettingsDialog()
  local vb = renoise.ViewBuilder()
  local dialog = nil
  
  -- Define format options table
  local format_options = { "%d", "%02d", "%03d" }
  
  -- Define naming behavior options
  local naming_behavior_options = {
    "Use Settings (Prefix/Suffix)",
    "Clear Name",
    "Keep Original Name"
  }
  
  -- Function to find index in table
  local function find_in_table(tbl, val)
    for i, v in ipairs(tbl) do
      if v == val then return i end
    end
    return 1
  end
  
  local dialog_content = vb:column{width=250,
    margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
    spacing = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING,
    
    -- Naming options section
    vb:column{width=250,
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      
      vb:text{ text = "Naming Options", font = "bold", style="strong" },
      
      vb:row{
        vb:text{ text = "Naming Behavior", width = 100 },
        vb:popup{
          width = 120,
          items = naming_behavior_options,
          value = preferences.pakettiPatternSequencer.naming_behavior.value,
          notifier=function(idx)
            preferences.pakettiPatternSequencer.naming_behavior.value = idx
          end
        }
      },
      
      vb:row{
        vb:text{ text = "Prefix", width = 100 },
        vb:textfield{
          width = 120,
          value = preferences.pakettiPatternSequencer.clone_prefix.value,
          notifier=function(value)
            preferences.pakettiPatternSequencer.clone_prefix.value = value
          end
        }
      },
      
      vb:row{
        vb:text{ text = "Suffix", width = 100 },
        vb:textfield{
          width = 120,
          value = preferences.pakettiPatternSequencer.clone_suffix.value,
          notifier=function(value)
            preferences.pakettiPatternSequencer.clone_suffix.value = value
          end
        }
      },
      
      vb:row{
        vb:checkbox{
          value = preferences.pakettiPatternSequencer.use_numbering.value,
          notifier=function(value)
            preferences.pakettiPatternSequencer.use_numbering.value = value
          end
        },
        vb:text{ text = "Use Numbering" }
      },
      
      vb:row{
        vb:text{ text = "Number Format", width = 100 },
        vb:popup{
          width = 100,
          items = format_options,
          value = find_in_table(format_options, preferences.pakettiPatternSequencer.numbering_format.value),
          notifier=function(idx)
            preferences.pakettiPatternSequencer.numbering_format.value = format_options[idx]
          end
        }
      },
      
      vb:row{
        vb:text{ text = "Start From", width = 100 },
        vb:valuebox{
          min = 1,
          max = 999,
          value = preferences.pakettiPatternSequencer.numbering_start.value,
          notifier=function(value)
            preferences.pakettiPatternSequencer.numbering_start.value = value
          end
        }
      }
    },
    
    -- Behavior options section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width=250,
      
      vb:text{ text = "Behavior Options", font = "bold", style="strong" },
      
      vb:row{
        vb:checkbox{
          value = preferences.pakettiPatternSequencer.select_after_clone.value,
          notifier=function(value)
            preferences.pakettiPatternSequencer.select_after_clone.value = value
          end
        },
        vb:text{ text = "Select Cloned Pattern After Creation" }
      },
      
    },
    
    -- Buttons
    vb:horizontal_aligner{
      mode = "justify",
      vb:button{
        text = "OK",
        width = 100,
        notifier=function()
          dialog:close()
        end
      },
      vb:button{
        text = "Cancel",
        width = 100,
        notifier=function()
          -- Reload preferences from disk to discard changes
          preferences:load_from("preferences.xml")
          dialog:close()
        end
      }
    }
  }
  
  dialog = renoise.app():show_custom_dialog("Pattern Sequencer Settings",dialog_content, my_keyhandler_func)
end

-- Function to clone the currently selected pattern sequence row
function clone_current_sequence()
  -- Access the Renoise song
  local song = renoise.song()
  
  -- Retrieve the currently selected sequence index
  local current_sequence_pos = song.selected_sequence_index
  -- Get the total number of sequences
  local total_sequences = #song.sequencer.pattern_sequence

  -- Debug information
  print("Current Sequence Index:", current_sequence_pos)
  print("Total Sequences:", total_sequences)

  -- Clone the sequence range, appending it right after the current position
  if current_sequence_pos <= total_sequences then
    -- Store the original pattern index and name
    local original_pattern_index = song.sequencer.pattern_sequence[current_sequence_pos]
    local original_name = song.patterns[original_pattern_index].name
    local prefs = preferences.pakettiPatternSequencer
    
    -- Debug print
    print("Original name:", original_name)
    
    -- Clone the sequence
    song.sequencer:clone_range(current_sequence_pos, current_sequence_pos)
    
    -- Get the new pattern index
    local new_sequence_pos = current_sequence_pos + 1
    local new_pattern_index = song.sequencer.pattern_sequence[new_sequence_pos]
    
    -- Handle naming based on selected behavior
    local base_name = ""
    
    if prefs.naming_behavior.value == 1 then -- Use Settings
      -- Strip existing prefix if present
      local name_without_prefix = original_name
      if prefs.clone_prefix.value ~= "" then
        local prefix_pattern = "^" .. prefs.clone_prefix.value
        name_without_prefix = name_without_prefix:gsub(prefix_pattern, "")
      end
      
      -- Strip existing suffix and number if present
      base_name = name_without_prefix:match("^(.-)%s*" .. prefs.clone_suffix.value .. "%s*%d*$") or name_without_prefix
      local clone_number = name_without_prefix:match(prefs.clone_suffix.value .. "%s*(%d+)$")
      
      -- Add numbering based on preferences
      if prefs.use_numbering.value then
        if clone_number then
          base_name = base_name .. prefs.clone_suffix.value .. " " .. 
            string.format(prefs.numbering_format.value, tonumber(clone_number) + 1)
        else
          base_name = base_name .. prefs.clone_suffix.value .. " " .. 
            string.format(prefs.numbering_format.value, prefs.numbering_start.value)
        end
      else
        base_name = base_name .. prefs.clone_suffix.value
      end
    elseif prefs.naming_behavior.value == 2 then -- Clear Name
      base_name = "" -- Base name is empty, but we'll still add prefix/suffix
      if prefs.use_numbering.value then
        base_name = base_name .. prefs.clone_suffix.value .. " " .. 
          string.format(prefs.numbering_format.value, prefs.numbering_start.value)
      else
        base_name = base_name .. prefs.clone_suffix.value
      end
    else -- Keep Original Name
      base_name = original_name
    end
    
    -- Always add prefix if set (for both Use Settings and Clear Name)
    local new_name = base_name
    if prefs.clone_prefix.value ~= "" and prefs.naming_behavior.value ~= 3 then
      new_name = prefs.clone_prefix.value .. new_name
    end
    
    -- Debug print
    print("Generated new name:", new_name)
    
    -- Set the pattern name
    song.patterns[new_pattern_index].name = new_name
    
    -- Debug information
    print("Cloned Sequence Index:", current_sequence_pos)
    print("Final pattern name:", new_name)
    
    -- Select the newly created sequence if enabled
    if prefs.select_after_clone.value then
      song.selected_sequence_index = new_sequence_pos
    end
    
  else
    renoise.app():show_status("Cannot clone the sequence: The current sequence is the last one.")
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Clone Current Sequence",invoke=clone_current_sequence}
renoise.tool():add_midi_mapping{name="Paketti:Clone Current Sequence",invoke=clone_current_sequence}

---------
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Keep Sequence Sorted False",invoke=function() renoise.song().sequencer.keep_sequence_sorted=false end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Keep Sequence Sorted True",invoke=function() renoise.song().sequencer.keep_sequence_sorted=true end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Keep Sequence Sorted Toggle",invoke=function() 
if renoise.song().sequencer.keep_sequence_sorted==false then renoise.song().sequencer.keep_sequence_sorted=true else
renoise.song().sequencer.keep_sequence_sorted=false end end}

renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Keep Sequence Sorted False",invoke=function() renoise.song().sequencer.keep_sequence_sorted=false end}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Keep Sequence Sorted True",invoke=function() renoise.song().sequencer.keep_sequence_sorted=true end}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Keep Sequence Sorted Toggle",invoke=function() 
if renoise.song().sequencer.keep_sequence_sorted==false then renoise.song().sequencer.keep_sequence_sorted=true else
renoise.song().sequencer.keep_sequence_sorted=false end end}


---------
-- Function to duplicate selected sequence range
function duplicate_selected_sequence_range()
  local song = renoise.song()
  local selection = song.sequencer.selection_range
  local prefs = preferences.pakettiPatternSequencer
  
  -- Check if we have a valid selection
  if not selection or #selection ~= 2 then
    renoise.app():show_status("No sequence range selected")
    return
  end
  
  local start_pos = selection[1]
  local end_pos = selection[2]
  
  -- Check if selection is valid
  if start_pos > end_pos then
    renoise.app():show_status("Invalid selection range")
    return
  end
  
  -- Clone the range
  song.sequencer:clone_range(start_pos, end_pos)
  
  -- Handle pattern names in the cloned range
  local range_length = end_pos - start_pos + 1
  for i = 1, range_length do
    local original_pattern_index = song.sequencer.pattern_sequence[start_pos + i - 1]
    local cloned_pattern_index = song.sequencer.pattern_sequence[end_pos + i]
    
    -- Get original name
    local original_name = song.patterns[original_pattern_index].name
    
    -- Debug print
    print("Original name:", original_name)
    
    -- Handle naming based on selected behavior
    local base_name = ""
    
    if prefs.naming_behavior.value == 1 then -- Use Settings
      -- Strip existing prefix if present
      local name_without_prefix = original_name
      if prefs.clone_prefix.value ~= "" then
        local prefix_pattern = "^" .. prefs.clone_prefix.value
        name_without_prefix = name_without_prefix:gsub(prefix_pattern, "")
      end
      
      -- Strip existing suffix and number if present
      base_name = name_without_prefix:match("^(.-)%s*" .. prefs.clone_suffix.value .. "%s*%d*$") or name_without_prefix
      local clone_number = name_without_prefix:match(prefs.clone_suffix.value .. "%s*(%d+)$")
      
      -- Add numbering based on preferences
      if prefs.use_numbering.value then
        if clone_number then
          base_name = base_name .. prefs.clone_suffix.value .. " " .. 
            string.format(prefs.numbering_format.value, tonumber(clone_number) + 1)
        else
          base_name = base_name .. prefs.clone_suffix.value .. " " .. 
            string.format(prefs.numbering_format.value, prefs.numbering_start.value)
        end
      else
        base_name = base_name .. prefs.clone_suffix.value
      end
    elseif prefs.naming_behavior.value == 2 then -- Clear Name
      base_name = "" -- Base name is empty, but we'll still add prefix/suffix
      if prefs.use_numbering.value then
        base_name = base_name .. prefs.clone_suffix.value .. " " .. 
          string.format(prefs.numbering_format.value, prefs.numbering_start.value)
      else
        base_name = base_name .. prefs.clone_suffix.value
      end
    else -- Keep Original Name
      base_name = original_name
    end
    
    -- Always add prefix if set (for both Use Settings and Clear Name)
    local new_name = base_name
    if prefs.clone_prefix.value ~= "" and prefs.naming_behavior.value ~= 3 then
      new_name = prefs.clone_prefix.value .. new_name
    end
    
    -- Debug print
    print("Generated new name:", new_name)
    
    song.patterns[cloned_pattern_index].name = new_name
  end
  
  -- Select the newly created range if enabled
  if prefs.select_after_clone.value then
    song.sequencer.selection_range = {end_pos + 1, end_pos + range_length}
    -- Move cursor to start of new range
    song.selected_sequence_index = end_pos + 1
  end
  
  renoise.app():show_status(string.format("Duplicated sequence range %d-%d", start_pos, end_pos))
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Selected Sequence Range",invoke=duplicate_selected_sequence_range}

-- Function to create a section from the current selection
function create_section_from_selection()
  local song = renoise.song()
  local sequencer = song.sequencer
  local selection = sequencer.selection_range
  
  -- Check if we have a valid selection
  if not selection or #selection ~= 2 then
    renoise.app():show_status("Please select a range in the pattern sequencer first")
    return
  end
  
  local start_pos = selection[1]
  local end_pos = selection[2]
  
  -- Check if selection is valid
  if start_pos > end_pos then
    renoise.app():show_status("Invalid selection range")
    return
  end
  
  -- Check if start_pos is already part of a section
  if sequencer:sequence_is_part_of_section(start_pos) and not sequencer:sequence_is_start_of_section(start_pos) then
    renoise.app():show_status("Cannot create section: Selection start is already part of another section")
    return
  end
  
  -- Get existing section names to avoid duplicates
  local existing_names = {}
  for i = 1, #sequencer.pattern_sequence do
    if sequencer:sequence_is_start_of_section(i) then
      local name = sequencer:sequence_section_name(i)
      existing_names[name] = true
    end
  end
  
  -- Find next available section number
  local section_num = 1
  while existing_names[string.format("%02d", section_num)] do
    section_num = section_num + 1
  end
  
  -- Create new section name
  local new_section_name = string.format("%02d", section_num)
  
  -- Set the section start flag and name
  sequencer:set_sequence_is_start_of_section(start_pos, true)
  sequencer:set_sequence_section_name(start_pos, new_section_name)
  
  -- If there's a section right after our new section, make sure it starts properly
  if end_pos < #sequencer.pattern_sequence then
    local next_pos = end_pos + 1
    if not sequencer:sequence_is_start_of_section(next_pos) then
      sequencer:set_sequence_is_start_of_section(next_pos, true)
      -- If it doesn't have a name yet, give it one
      if sequencer:sequence_section_name(next_pos) == "" then
        sequencer:set_sequence_section_name(next_pos, string.format("%02d", section_num + 1))
      end
    end
  end
  
  renoise.app():show_status(string.format("Created section '%s' from selection", new_section_name))
end

renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Create Section From Selection",invoke=create_section_from_selection}

-- Function to navigate section sequences (next or previous)
function navigate_section_sequence(direction)
  local song = renoise.song()
  local sequencer = song.sequencer
  local selection = sequencer.selection_range
  
  -- If no selection exists, select current section
  if not selection or #selection ~= 2 then
    local current_pos = song.selected_sequence_index
    -- Find start of current section
    while current_pos > 1 and not sequencer:sequence_is_start_of_section(current_pos) do
      current_pos = current_pos - 1
    end
    -- Find end of current section
    local section_end = current_pos
    while section_end < #sequencer.pattern_sequence and not sequencer:sequence_is_start_of_section(section_end + 1) do
      section_end = section_end + 1
    end
    -- Select current section
    sequencer.selection_range = {current_pos, section_end}
    renoise.app():show_status("Selected current section")
    return
  end
  
  local start_pos = selection[1]
  local end_pos = selection[2]
  
  if direction == "next" then
    -- Find start of next section
    local next_section_start = end_pos + 1
    if next_section_start <= #sequencer.pattern_sequence then
      if not sequencer:sequence_is_start_of_section(next_section_start) then
        -- Find the next section start
        while next_section_start <= #sequencer.pattern_sequence and 
              not sequencer:sequence_is_start_of_section(next_section_start) do
          next_section_start = next_section_start + 1
        end
      end
      
      if next_section_start <= #sequencer.pattern_sequence then
        -- Find end of next section
        local next_section_end = next_section_start
        while next_section_end < #sequencer.pattern_sequence and 
              not sequencer:sequence_is_start_of_section(next_section_end + 1) do
          next_section_end = next_section_end + 1
        end
        
        -- Extend selection to include next section
        sequencer.selection_range = {start_pos, next_section_end}
        renoise.app():show_status("Extended selection to next section")
      else
        renoise.app():show_status("No next section available")
      end
    else
      renoise.app():show_status("No next section available")
    end
    
  else -- direction == "previous"
    -- Find the start positions of all sections in the current selection
    local section_starts = {}
    local pos = start_pos
    while pos <= end_pos do
      if sequencer:sequence_is_start_of_section(pos) then
        table.insert(section_starts, pos)
      end
      pos = pos + 1
    end
    
    -- If multiple sections are selected
    if #section_starts > 1 then
      -- Remove the last section from selection
      local new_end = section_starts[#section_starts] - 1
      sequencer.selection_range = {start_pos, new_end}
      renoise.app():show_status("Removed last section from selection")
      return
    end
    
    -- If only one section is selected, try to select previous section
    if start_pos > 1 then
      -- Find start of previous section
      local prev_start = start_pos - 1
      while prev_start > 1 and not sequencer:sequence_is_start_of_section(prev_start) do
        prev_start = prev_start - 1
      end
      
      if sequencer:sequence_is_start_of_section(prev_start) then
        -- Find end of previous section (which is start_pos - 1)
        sequencer.selection_range = {prev_start, start_pos - 1}
        renoise.app():show_status("Selected previous section")
      else
        renoise.app():show_status("No previous section available")
      end
    else
      renoise.app():show_status("No previous section available")
    end
  end
end

renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Show Paketti Sequencer Settings Dialog",invoke = pakettiSequencerSettingsDialog}