-- PakettiTreeStructure.lua
-- Tree Structure Navigator for Paketti Commands
-- Provides hierarchical navigation with numeric key shortcuts

-- Dialog state variables
local tree_dialog = nil
local tree_vb = nil
local current_expanded_branch = 0  -- 0 = none, 1-6 = branch numbers
local selected_item_index = 1

-- Tree structure data organized by categories
local tree_structure = {
  {
    id = 1,
    name = "Sample Processing",
    items = {
      "Wipe & Slice 1",
      "Wipe & Slice 2", 
      "Normalize Sample",
      "Reverse Sample",
      "Duplicate Sample +12",
      "Duplicate Sample +24",
      "Duplicate Sample +36",
      "Process All Samples",
      "Generate White Noise",
      "Import Sample"
    }
  },
  {
    id = 2,
    name = "Pattern Editor",
    items = {
      "Insert Note Off",
      "Delete Line",
      "Duplicate Track",
      "Double Pattern Length",
      "Halve Pattern Length",
      "Create Pattern Sequence",
      "Jazz Chord Generator",
      "Transpose Block +12",
      "Transpose Block -12",
      "Clear Track"
    }
  },
  {
    id = 3,
    name = "Automation & Control",
    items = {
      "Record Automation",
      "Clear Automation",
      "Smooth Automation",
      "BPM Automation",
      "Volume Automation",
      "Pan Automation",
      "Filter Automation",
      "LFO Reset All",
      "Randomize All Parameters",
      "Copy Automation"
    }
  },
  {
    id = 4,
    name = "Instrument & Effects",
    items = {
      "Load Random Plugin",
      "Load Device Chain",
      "Clear All Effects",
      "Randomize Plugin Parameters",
      "Save Instrument Preset",
      "Load Instrument Preset",
      "Create New Instrument",
      "Duplicate Current Instrument",
      "Reset All Plugin Parameters",
      "Bypass All Effects"
    }
  },
  {
    id = 5,
    name = "Playback & Recording", 
    items = {
      "Start/Stop Playback",
      "Record Pattern",
      "Metronome Toggle",
      "Loop Pattern",
      "Loop Selection",
      "Follow Song",
      "Record to Sample",
      "Render Selection",
      "Render Entire Song",
      "MIDI Clock Sync"
    }
  },
  {
    id = 6,
    name = "Utilities & Tools",
    items = {
      "Theme Selector",
      "Device Chain Loader",
      "Sample Browser",
      "Instrument Browser",
      "Paketti Gadgets",
      "Action Selector",
      "Autocomplete",
      "Key Bindings Editor",
      "MIDI Mappings",
      "Export Configuration"
    }
  }
}

-- Helper function to map tree items to actual Paketti commands
local function get_paketti_command_for_item(item_name)
  -- This is a simplified mapping - in real implementation, 
  -- you would reference the actual Paketti functions
  local command_map = {
    ["Wipe & Slice 1"] = "pakettiWipeSliceInstrumentSample001",
    ["Wipe & Slice 2"] = "pakettiWipeSliceInstrumentSample002",
    ["Normalize Sample"] = "pakettiProcessNormalize",
    ["Reverse Sample"] = "pakettiProcessReverse",
    ["Duplicate Sample +12"] = "pakettiDuplicateSample(12)",
    ["Duplicate Sample +24"] = "pakettiDuplicateSample(24)",
    ["Duplicate Sample +36"] = "pakettiDuplicateSample(36)",
    ["Process All Samples"] = "pakettiProcessAllSamples",
    ["Generate White Noise"] = "pakettiGenerateWhiteNoise",
    ["Import Sample"] = "pakettiImportSample",
    
    ["Insert Note Off"] = "pakettiInsertNoteOff",
    ["Delete Line"] = "pakettiDeleteLine", 
    ["Duplicate Track"] = "pakettiDuplicateTrack",
    ["Double Pattern Length"] = "pakettiDoublePatternLength",
    ["Halve Pattern Length"] = "pakettiHalvePatternLength",
    ["Create Pattern Sequence"] = "pakettiCreatePatternSequence",
    ["Jazz Chord Generator"] = "pakettiJazzChordGenerator",
    ["Transpose Block +12"] = "pakettiTransposeBlock(12)",
    ["Transpose Block -12"] = "pakettiTransposeBlock(-12)",
    ["Clear Track"] = "pakettiClearTrack",
    
    -- Add more mappings as needed...
    ["Theme Selector"] = "PakettiThemeSelector",
    ["Autocomplete"] = "PakettiAutocompleteShow",
    ["Paketti Gadgets"] = "PakettiGadgetsShow"
  }
  
  return command_map[item_name]
end

-- Function to execute a selected command
local function execute_tree_command(item_name)
  local command = get_paketti_command_for_item(item_name)
  if command then
    renoise.app():show_status("Executing: " .. item_name)
    
    -- Try to execute the command
    local success, error_msg = pcall(function()
      if _G[command] then
        if type(_G[command]) == "function" then
          _G[command]()
        else
          renoise.app():show_status("Error: " .. command .. " is not a function")
        end
      else
        -- Try to execute as a loadstring
        local func = loadstring(command)
        if func then
          func()
        else
          renoise.app():show_status("Error: Command not found - " .. command)
        end
      end
    end)
    
    if not success then
      renoise.app():show_status("Error executing " .. item_name .. ": " .. tostring(error_msg))
    end
  else
    renoise.app():show_status("No command mapped for: " .. item_name)
  end
end

-- Function to create tree content
local function create_tree_content()
  local content = tree_vb:column{
    spacing = 2,
    margin = 5
  }
  
  -- Add main branches
  for i, branch in ipairs(tree_structure) do
    local branch_color = {0x40, 0x40, 0x40} -- Default gray
    local branch_text = string.format("%d. %s", i, branch.name)
    
    if current_expanded_branch == i then
      branch_color = {0x80, 0x40, 0x00} -- Orange for expanded
      branch_text = string.format("%d. %s (EXPANDED)", i, branch.name)
    end
    
    -- Branch header button
    local branch_button = tree_vb:button{
      text = branch_text,
      width = 350,
      height = 25,
      color = branch_color,
      notifier = function()
        if current_expanded_branch == i then
          current_expanded_branch = 0  -- Collapse
          selected_item_index = 1
        else
          current_expanded_branch = i   -- Expand
          selected_item_index = 1
        end
        update_tree_display()
      end
    }
    
    content:add_child(branch_button)
    
    -- Add items if branch is expanded
    if current_expanded_branch == i then
      for j, item in ipairs(branch.items) do
        local item_color = {0x20, 0x20, 0x20} -- Dark gray for items
        local item_text = string.format("  %s", item)
        
        if j == selected_item_index then
          item_color = {0x00, 0x80, 0x00} -- Green for selected
          item_text = string.format("► %s", item)
        end
        
        local item_button = tree_vb:button{
          text = item_text,
          width = 330,
          height = 20,
          color = item_color,
          notifier = function()
            selected_item_index = j
            update_tree_display()
          end
        }
        
        content:add_child(item_button)
      end
      
      -- Add spacing after expanded section
      content:add_child(tree_vb:space{height = 10})
    end
  end
  
  return content
end

-- Function to update the tree display
local function update_tree_display()
  if not tree_dialog or not tree_dialog.visible then
    return
  end
  
  -- Close and recreate the dialog with updated content
  tree_dialog:close()
  PakettiTreeStructureShow()
end

-- Key handler function for tree navigation
local function tree_keyhandler_func(dialog, key)
  -- Check for dialog close first [[memory:5350415]]
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    tree_dialog:close()
    tree_dialog = nil
    tree_vb = nil
    current_expanded_branch = 0
    selected_item_index = 1
    return nil
  end
  
  -- Handle numeric keys 1-6 for branch navigation
  if key.modifiers == "" and tonumber(key.name) then
    local branch_num = tonumber(key.name)
    if branch_num >= 1 and branch_num <= 6 then
      if current_expanded_branch == branch_num then
        current_expanded_branch = 0  -- Collapse if already expanded
        selected_item_index = 1
      else
        current_expanded_branch = branch_num  -- Expand branch
        selected_item_index = 1
      end
      update_tree_display()
      return nil
    end
  end
  
  -- Handle navigation within expanded branch
  if current_expanded_branch > 0 then
    local current_branch = tree_structure[current_expanded_branch]
    
    -- Up/Down arrow navigation
    if key.modifiers == "" and key.name == "up" then
      selected_item_index = math.max(1, selected_item_index - 1)
      update_tree_display()
      return nil
    elseif key.modifiers == "" and key.name == "down" then
      selected_item_index = math.min(#current_branch.items, selected_item_index + 1)
      update_tree_display()
      return nil
    end
    
    -- Enter to execute selected item
    if key.modifiers == "" and key.name == "return" then
      local selected_item = current_branch.items[selected_item_index]
      if selected_item then
        execute_tree_command(selected_item)
        -- Close dialog after execution
        tree_dialog:close()
        tree_dialog = nil
        tree_vb = nil
        current_expanded_branch = 0
        selected_item_index = 1
      end
      return nil
    end
  end
  
  -- Pass other keys back to Renoise
  return key
end

-- Function to create and show the tree structure dialog
function PakettiTreeStructureShow()
  if tree_dialog and tree_dialog.visible then
    tree_dialog:show()
    return
  end
  
  -- Create ViewBuilder instance
  tree_vb = renoise.ViewBuilder()
  
  -- Create header
  local header = tree_vb:column{
    spacing = 5,
    margin = 5,
    tree_vb:text{
      text = "Paketti Tree Structure Navigator",
      font = "bold",
      style = "strong"
    },
    tree_vb:text{
      text = "Use numbers 1-6 to expand/collapse branches",
      style = "normal"
    },
    tree_vb:text{
      text = "Use arrow keys to navigate, Enter to execute",
      style = "normal"
    },
    tree_vb:space{height = 5}
  }
  
  -- Create tree content
  local tree_content = create_tree_content()
  
  -- Create main dialog content
  local dialog_content = tree_vb:column{
    width = 400,
    height = 500,
    spacing = 5,
    margin = 8,
    header,
    tree_content
  }
  
  -- Show dialog [[memory:4460994]]
  tree_dialog = renoise.app():show_custom_dialog("Paketti Tree Structure", dialog_content, tree_keyhandler_func)
  
  -- Set focus to Renoise window [[memory:4460994]]
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Function to close the tree structure dialog
function PakettiTreeStructureClose()
  if tree_dialog and tree_dialog.visible then
    tree_dialog:close()
    tree_dialog = nil
    tree_vb = nil
    current_expanded_branch = 0
    selected_item_index = 1
  end
end

-- Menu entries for tree structure
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Tree Structure Navigator",
  invoke = PakettiTreeStructureShow
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Tree Structure Navigator",
  invoke = PakettiTreeStructureShow
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Tree Structure Navigator",
  invoke = PakettiTreeStructureShow
}