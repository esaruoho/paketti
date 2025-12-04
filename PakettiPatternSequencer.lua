-- Get preferences from the tool
local preferences = renoise.tool().preferences

-- Global dialog reference for Sequencer Settings toggle behavior
local dialog = nil

-- Function to show the settings dialog
function pakettiSequencerSettingsDialog()
  -- Check if dialog is already open and close it
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  
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
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Pattern Sequencer Settings",dialog_content, keyhandler)
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

for section_number = 1, 32 do
  renoise.tool():add_keybinding{name="Global:Paketti:Select and Loop Sequence Section " .. string.format("%02d", section_number),
    invoke=function() select_and_loop_section(section_number) end
  }
end
renoise.tool():add_keybinding{name="Global:Paketti:Add Current Sequence to Scheduled List",invoke=function() renoise.song().transport:add_scheduled_sequence(renoise.song().selected_sequence_index) end}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Clone Current Sequence",invoke=clone_current_sequence}

renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Select Next Section Sequence",invoke=function() navigate_section_sequence("next") end}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Select Previous Section Sequence",invoke=function() navigate_section_sequence("previous") end}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Duplicate Selected Sequence Range",invoke=duplicate_selected_sequence_range}

-------
function PakettiKeepSequenceSorted(state)
  -- Handle toggle case
  if state == "toggle" then
    if renoise.song().sequencer.keep_sequence_sorted == false then
      state = true
    else
      state = false
    end
  end
  
  -- Sets the Keep Sequence Sorted state to true(on) or false(off)
  renoise.song().sequencer.keep_sequence_sorted = state

  -- Depending on what the state was, show a different status message.
  if state == true then 
    renoise.app():show_status("Keep Sequence Sorted: Enabled")
  else
    renoise.app():show_status("Keep Sequence Sorted: Disabled")
  end
end

renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Keep Sequence Sorted On", invoke=function() PakettiKeepSequenceSorted(true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Keep Sequence Sorted Off", invoke=function() PakettiKeepSequenceSorted(false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Keep Sequence Sorted Toggle", invoke=function() PakettiKeepSequenceSorted("toggle") end}
renoise.tool():add_keybinding{name="Global:Paketti:Keep Sequence Sorted On", invoke=function() PakettiKeepSequenceSorted(true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Keep Sequence Sorted Off", invoke=function() PakettiKeepSequenceSorted(false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Keep Sequence Sorted Toggle", invoke=function() PakettiKeepSequenceSorted("toggle") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Keep Sequence Sorted Off", invoke=function() PakettiKeepSequenceSorted(false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Keep Sequence Sorted On", invoke=function() PakettiKeepSequenceSorted(true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Keep Sequence Sorted Toggle", invoke=function() PakettiKeepSequenceSorted("toggle") end}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Keep Sequence Sorted Off", invoke=function() PakettiKeepSequenceSorted(false) end}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Keep Sequence Sorted On", invoke=function() PakettiKeepSequenceSorted(true) end}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Keep Sequence Sorted Toggle", invoke=function() PakettiKeepSequenceSorted("toggle") end}

-- Function to wipe empty patterns from the end of the pattern sequencer
function PakettiWipeEmptyPatternsFromEnd()
  local song = renoise.song()
  local sequencer = song.sequencer
  local pattern_sequence = sequencer.pattern_sequence
  local total_sequences = #pattern_sequence
  
  if total_sequences == 0 then
    renoise.app():show_status("No patterns in sequencer")
    return
  end
  
  -- Find the last non-empty pattern by working backwards from the end
  local last_non_empty_pos = total_sequences
  local empty_count = 0
  
  -- Start from the end and work backwards to find continuous empty patterns
  for i = total_sequences, 1, -1 do
    local pattern_index = pattern_sequence[i]
    local pattern = song.patterns[pattern_index]
    
    if pattern.is_empty then
      empty_count = empty_count + 1
      last_non_empty_pos = i - 1
    else
      -- Found a non-empty pattern, stop here
      break
    end
  end
  
  -- If no empty patterns found at the end, show status and return
  if empty_count == 0 then
    renoise.app():show_status("No empty patterns found at the end of sequencer")
    return
  end
  
  -- Don't delete all patterns - keep at least one
  if last_non_empty_pos == 0 then
    renoise.app():show_status("Cannot delete all patterns - keeping at least one pattern")
    return
  end
  
  -- Delete empty patterns from the end
  for i = total_sequences, last_non_empty_pos + 1, -1 do
    sequencer:delete_sequence_at(i)
  end
  
  -- Show status message
  renoise.app():show_status(string.format("Wiped %d empty patterns from end of sequencer", empty_count))
end

renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Wipe Empty Patterns From End", invoke=PakettiWipeEmptyPatternsFromEnd}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Wipe Empty Patterns From End", invoke=PakettiWipeEmptyPatternsFromEnd}

-- Function to clear unused patterns (patterns not in the pattern sequencer)
function PakettiClearUnusedPatterns()
  local song = renoise.song()
  local sequencer = song.sequencer
  local pattern_sequence = sequencer.pattern_sequence
  local patterns = song.patterns
  
  -- Create a set of used pattern indices
  local used_patterns = {}
  for i = 1, #pattern_sequence do
    local pattern_index = pattern_sequence[i]
    used_patterns[pattern_index] = true
  end
  
  -- Clear unused patterns and count them
  local cleared_count = 0
  for pattern_index = 1, #patterns do
    if not used_patterns[pattern_index] then
      -- This pattern is not used in the sequencer
      if not patterns[pattern_index].is_empty then
        -- Only count non-empty patterns as "cleared"
        cleared_count = cleared_count + 1
      end
      -- Clear the pattern regardless of whether it was empty
      patterns[pattern_index]:clear()
    end
  end
  
  -- Show status message
  if cleared_count > 0 then
    renoise.app():show_status("Cleared " .. cleared_count .. " unused patterns")
  else
    renoise.app():show_status("No unused patterns found")
  end
end

renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Clear Unused Patterns", invoke=PakettiClearUnusedPatterns}
renoise.tool():add_keybinding{name="Global:Paketti:Clear Unused Patterns", invoke=PakettiClearUnusedPatterns}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Clear Unused Patterns", invoke=PakettiClearUnusedPatterns}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Clear Unused Patterns", invoke=PakettiClearUnusedPatterns}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Clear Unused Patterns", invoke=PakettiClearUnusedPatterns}
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Clear Unused Patterns", invoke=PakettiClearUnusedPatterns}

---------
-- Function to duplicate current pattern and insert it as next sequence entry
function PakettiDuplicatePatternAndInsertNext()
  local song = renoise.song()
  local sequencer = song.sequencer
  
  -- Step 1: Get current pattern and sequence position
  local current_pattern_index = song.selected_pattern_index
  local current_sequence_index = song.selected_sequence_index
  local current_pattern = song.patterns[current_pattern_index]
  
  -- Step 2: Insert a NEW pattern at the next sequence position
  -- This creates a brand new pattern automatically
  local new_sequence_index = current_sequence_index + 1
  local new_pattern_index = sequencer:insert_new_pattern_at(new_sequence_index)
  
  -- Step 3: Copy all data from current pattern to the new pattern
  -- This copies everything: tracks, lines, name, etc.
  song.patterns[new_pattern_index]:copy_from(current_pattern)
  
  -- Step 4: Copy the pattern name
  local original_name = current_pattern.name
  if original_name == "" then
    original_name = "Pattern " .. tostring(current_pattern_index)
  end
  song.patterns[new_pattern_index].name = original_name .. " (duplicate)"
  
  -- Step 5: Move the playhead/selection to the new sequence position
  song.selected_sequence_index = new_sequence_index
  
  -- Step 6: Copy track mute states from original sequence slot to new one
  for track_index = 1, #song.tracks do
    local is_muted = sequencer:track_sequence_slot_is_muted(track_index, current_sequence_index)
    sequencer:set_track_sequence_slot_is_muted(track_index, new_sequence_index, is_muted)
  end
  
  -- Step 7: Copy automation data explicitly to ensure full duplication
  for track_index = 1, #song.tracks do
    local original_track = song.patterns[current_pattern_index].tracks[track_index]
    local new_track = song.patterns[new_pattern_index].tracks[track_index]
    for _, automation in ipairs(original_track.automation) do
      local parameter = automation.dest_parameter
      local new_automation = new_track:find_automation(parameter)
      if not new_automation then
        new_automation = new_track:create_automation(parameter)
      end
      new_automation:copy_from(automation)
    end
  end
  
  -- Show confirmation
  renoise.app():show_status("Duplicated pattern below and jumped to it.")
end

renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Duplicate Pattern and Insert Next", invoke=PakettiDuplicatePatternAndInsertNext}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate Pattern and Insert Next", invoke=PakettiDuplicatePatternAndInsertNext}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Pattern and Insert Next", invoke=PakettiDuplicatePatternAndInsertNext}

---------
-- Function to play from the current pattern sequence
function PakettiPlayCurrentPatternSequence()
  local song = renoise.song()
  local transport = song.transport
  
  -- Get current selected sequence index
  local current_sequence = song.selected_sequence_index
  
  -- Set playback position to the first line of the selected sequence using SongPos
  transport.playback_pos = renoise.SongPos(current_sequence, 1)
  
  -- Start playback if not already playing
  if not transport.playing then
    transport:start(renoise.Transport.PLAYMODE_CONTINUE_PATTERN)
  end
  
  renoise.app():show_status("Playing from sequence " .. current_sequence)
end

renoise.tool():add_keybinding{name="Global:Paketti:Play Current Pattern Sequence", invoke=PakettiPlayCurrentPatternSequence}

---------
-- Helper function to check if there's a valid selection range in the sequencer
function PakettiHasValidSequencerSelection()
  local selection = renoise.song().sequencer.selection_range
  if selection and #selection == 2 and selection[1] > 0 and selection[2] > 0 then
    return true, selection[1], selection[2]
  end
  return false, nil, nil
end

-- Function to delete all sequences above the selected sequence or selection
function PakettiDeleteAllSequencesAbove()
  local song = renoise.song()
  local sequencer = song.sequencer
  
  -- Check if there's a valid selection range
  local has_selection, sel_start, sel_end = PakettiHasValidSequencerSelection()
  local reference_point = has_selection and sel_start or song.selected_sequence_index
  
  -- Check if we're already at the first sequence
  if reference_point <= 1 then
    renoise.app():show_status("No sequences above to delete")
    return
  end
  
  -- Count how many we're deleting
  local delete_count = reference_point - 1
  
  -- Delete sequences from (reference_point - 1) down to 1
  -- We delete backwards to avoid index shifting issues
  for i = reference_point - 1, 1, -1 do
    sequencer:delete_sequence_at(i)
  end
  
  -- After deletion, clear selection and move to first sequence
  sequencer.selection_range = {}
  song.selected_sequence_index = 1
  
  if has_selection then
    renoise.app():show_status(string.format("Deleted %d sequences above selection", delete_count))
  else
    renoise.app():show_status(string.format("Deleted %d sequences above", delete_count))
  end
end

-- Function to delete all sequences below the selected sequence or selection
function PakettiDeleteAllSequencesBelow()
  local song = renoise.song()
  local sequencer = song.sequencer
  local total_sequences = #sequencer.pattern_sequence
  
  -- Check if there's a valid selection range
  local has_selection, sel_start, sel_end = PakettiHasValidSequencerSelection()
  local reference_point = has_selection and sel_end or song.selected_sequence_index
  
  -- Check if we're already at the last sequence
  if reference_point >= total_sequences then
    renoise.app():show_status("No sequences below to delete")
    return
  end
  
  -- Count how many we're deleting
  local delete_count = total_sequences - reference_point
  
  -- Delete sequences from end down to (reference_point + 1)
  for i = total_sequences, reference_point + 1, -1 do
    sequencer:delete_sequence_at(i)
  end
  
  -- Clear selection after deletion
  sequencer.selection_range = {}
  
  if has_selection then
    renoise.app():show_status(string.format("Deleted %d sequences below selection", delete_count))
  else
    renoise.app():show_status(string.format("Deleted %d sequences below", delete_count))
  end
end

-- Function to delete all sequences above and below the selected sequence or selection (keep only selected/selection)
function PakettiDeleteAllSequencesAboveAndBelow()
  local song = renoise.song()
  local sequencer = song.sequencer
  local total_sequences = #sequencer.pattern_sequence
  
  -- Check if there's a valid selection range
  local has_selection, sel_start, sel_end = PakettiHasValidSequencerSelection()
  local keep_start = has_selection and sel_start or song.selected_sequence_index
  local keep_end = has_selection and sel_end or song.selected_sequence_index
  
  -- Check if there's only one sequence (or selection covers everything)
  if keep_start == 1 and keep_end == total_sequences then
    renoise.app():show_status("Nothing to delete - selection covers entire sequence")
    return
  end
  
  if total_sequences <= 1 then
    renoise.app():show_status("Only one sequence exists, nothing to delete")
    return
  end
  
  -- Count how many we're deleting
  local delete_above = keep_start - 1
  local delete_below = total_sequences - keep_end
  local total_delete = delete_above + delete_below
  
  -- First delete all sequences below (from end down to keep_end + 1)
  for i = total_sequences, keep_end + 1, -1 do
    sequencer:delete_sequence_at(i)
  end
  
  -- Then delete all sequences above (from keep_start - 1 down to 1)
  -- Note: after deleting below, keep_start index is still valid
  for i = keep_start - 1, 1, -1 do
    sequencer:delete_sequence_at(i)
  end
  
  -- After deletion, clear selection and move to first sequence
  sequencer.selection_range = {}
  song.selected_sequence_index = 1
  
  if has_selection then
    renoise.app():show_status(string.format("Deleted %d sequences (%d above, %d below selection)", total_delete, delete_above, delete_below))
  else
    renoise.app():show_status(string.format("Deleted %d sequences (%d above, %d below)", total_delete, delete_above, delete_below))
  end
end

-- Keybindings for Delete All Sequences Above
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Delete All Sequences Above", invoke=PakettiDeleteAllSequencesAbove}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Delete All Sequences Above", invoke=PakettiDeleteAllSequencesAbove}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Delete All Sequences Above", invoke=PakettiDeleteAllSequencesAbove}
renoise.tool():add_keybinding{name="Global:Paketti:Delete All Sequences Above", invoke=PakettiDeleteAllSequencesAbove}

-- Keybindings for Delete All Sequences Below
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Delete All Sequences Below", invoke=PakettiDeleteAllSequencesBelow}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Delete All Sequences Below", invoke=PakettiDeleteAllSequencesBelow}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Delete All Sequences Below", invoke=PakettiDeleteAllSequencesBelow}
renoise.tool():add_keybinding{name="Global:Paketti:Delete All Sequences Below", invoke=PakettiDeleteAllSequencesBelow}

-- Keybindings for Delete All Sequences Above and Below
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Delete All Sequences Above and Below", invoke=PakettiDeleteAllSequencesAboveAndBelow}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Delete All Sequences Above and Below", invoke=PakettiDeleteAllSequencesAboveAndBelow}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Delete All Sequences Above and Below", invoke=PakettiDeleteAllSequencesAboveAndBelow}
renoise.tool():add_keybinding{name="Global:Paketti:Delete All Sequences Above and Below", invoke=PakettiDeleteAllSequencesAboveAndBelow}

-- Menu entries for Delete All Sequences Above
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Delete All Sequences Above", invoke=PakettiDeleteAllSequencesAbove}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delete All Sequences Above", invoke=PakettiDeleteAllSequencesAbove}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delete All Sequences Above", invoke=PakettiDeleteAllSequencesAbove}

-- Menu entries for Delete All Sequences Below
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Delete All Sequences Below", invoke=PakettiDeleteAllSequencesBelow}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delete All Sequences Below", invoke=PakettiDeleteAllSequencesBelow}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delete All Sequences Below", invoke=PakettiDeleteAllSequencesBelow}

-- Menu entries for Delete All Sequences Above and Below
renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti:Delete All Sequences Above and Below", invoke=PakettiDeleteAllSequencesAboveAndBelow}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Delete All Sequences Above and Below", invoke=PakettiDeleteAllSequencesAboveAndBelow}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Delete All Sequences Above and Below", invoke=PakettiDeleteAllSequencesAboveAndBelow}
