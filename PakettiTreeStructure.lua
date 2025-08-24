-- PakettiTreeStructure.lua
-- Tree Structure Navigator for Paketti Commands
-- Provides hierarchical navigation with numeric key shortcuts

-- Dialog state variables
local tree_dialog = nil
local tree_vb = nil
local current_expanded_branch = 0  -- 0 = none, 1-6 = branch numbers
local selected_item_index = 1

-- Cache for discovered commands
local discovered_commands = {}
local commands_cached = false

-- Function to get all Paketti files (similar to PakettiAutocomplete system)
function PakettiTreeStructureGetAllPakettiFiles()
  local files = {}
  local findfiles = findfiles or getfiles -- Use existing helper from main.lua [[memory:5499473]]
  
  if findfiles then
    local lua_files = findfiles(renoise.tool().bundle_path, "*.lua")
    for _, filepath in ipairs(lua_files) do
      local filename = filepath:match("([^/\\]+)%.lua$")
      if filename and filename:match("^Paketti") then
        table.insert(files, filename)
      end
    end
  end
  
  return files
end

-- Function to discover real Paketti commands by scanning source files
function PakettiTreeStructureDiscoverCommands()
  if commands_cached then
    return discovered_commands
  end
  
  discovered_commands = {}
  local paketti_files = PakettiTreeStructureGetAllPakettiFiles()
  
  -- Helper function to extract category from menu path (aligned with PakettiMIDIMappingCategories)
  local function extract_category(menu_path)
    local clean_path = menu_path:gsub("^%-%-%s*", "")
    
    -- Extract category from menu paths using MIDI mapping category structure
    if clean_path:match("Sample Editor") then
      if clean_path:match("Process") or clean_path:match("Slice") or clean_path:match("Reverse") or clean_path:match("Normalize") then
        return "Sample Editor: Process"
      elseif clean_path:match("Selection") or clean_path:match("Buffer") then
        return "Sample Editor: Selection"
      else
        return "Sample Editor: Navigation"
      end
    elseif clean_path:match("Pattern Editor") then
      if clean_path:match("Edit") or clean_path:match("Insert") or clean_path:match("Delete") or clean_path:match("Clear") then
        return "Pattern Editor: Editing"
      elseif clean_path:match("Effect") or clean_path:match("Transpose") then
        return "Pattern Editor: Effects"
      else
        return "Pattern Editor: Navigation"
      end
    elseif clean_path:match("Automation") then
      if clean_path:match("Edit") or clean_path:match("Clear") or clean_path:match("Smooth") then
        return "Automation: Editing"
      else
        return "Automation: Control"
      end
    elseif clean_path:match("Track") then
      if clean_path:match("Effect") or clean_path:match("DSP") then
        return "Track: Effects"
      elseif clean_path:match("Control") or clean_path:match("Mute") or clean_path:match("Solo") then
        return "Track: Control"
      else
        return "Track: Navigation"
      end
    elseif clean_path:match("Instrument") then
      if clean_path:match("Load") or clean_path:match("Save") then
        return "Instrument: Loading"
      else
        return "Instrument: Control"
      end
    elseif clean_path:match("Playback") or clean_path:match("Transport") then
      if clean_path:match("Record") then
        return "Playback: Recording"
      else
        return "Playback: Control"
      end
    elseif clean_path:match("Sequencer") then
      if clean_path:match("Control") or clean_path:match("Start") or clean_path:match("Stop") then
        return "Sequencer: Control"
      else
        return "Sequencer: Navigation"
      end
    elseif clean_path:match("Mixer") then
      return "Mixer: Control"
    elseif clean_path:match("Gadgets") then
      if clean_path:match("Tools") then
        return "Paketti Gadgets: Tools"
      else
        return "Paketti Gadgets: General"
      end
    elseif clean_path:match("Experimental") or clean_path:match("Test") then
      return "Experimental: Test"
    else
      return "Utility: General"
    end
  end
  
  -- Scan each Paketti file
  for _, filename in ipairs(paketti_files) do
    local full_path = renoise.tool().bundle_path .. filename .. ".lua"
    local file = io.open(full_path, "r")
    if file then
      local content = file:read("*all")
      file:close()
      
      -- Extract menu entries
      for entry, invoke_func in content:gmatch('add_menu_entry%s*{%s*name%s*=%s*"([^"]+)"%s*,%s*invoke%s*=%s*([^}]-)}') do
        local clean_name = entry:gsub("^%-%-%s*", ""):gsub("Main Menu:Tools:", ""):gsub("Paketti:", "")
        local category = extract_category(entry)
        local cleaned_invoke = invoke_func:match("^%s*(.-)%s*$")
        
        -- Skip overly complex menu paths
        if not clean_name:match(":.*:.*:") then
          table.insert(discovered_commands, {
            type = "Menu Entry",
            name = clean_name,
            category = category,
            invoke = cleaned_invoke,
            source_file = filename
          })
        end
      end
      
      -- Extract keybindings
      for binding, invoke_func in content:gmatch('add_keybinding%s*{%s*name%s*=%s*"([^"]+)"%s*,%s*invoke%s*=%s*([^}]-)}') do
        local clean_name = binding:gsub("Global:", ""):gsub("Paketti:", "")
        local category = extract_category(binding)
        local cleaned_invoke = invoke_func:match("^%s*(.-)%s*$")
        
        table.insert(discovered_commands, {
          type = "Keybinding",
          name = clean_name,
          category = category,
          invoke = cleaned_invoke,
          source_file = filename
        })
      end
    end
  end
  
  commands_cached = true
  print("PakettiTreeStructure: Discovered " .. #discovered_commands .. " commands")
  return discovered_commands
end

-- Function to organize discovered commands into tree structure
function PakettiTreeStructureBuildDynamicTree()
  local commands = PakettiTreeStructureDiscoverCommands()
  local dynamic_tree = {}
  
  -- Create category map (aligned with PakettiMIDIMappingCategories)
  local categories = {
    "Pattern Editor: Navigation",
    "Pattern Editor: Editing", 
    "Pattern Editor: Effects",
    "Sample Editor: Process",
    "Sample Editor: Navigation",
    "Sample Editor: Selection",
    "Automation: Control",
    "Automation: Editing",
    "Playback: Control",
    "Playback: Recording",
    "Track: Navigation",
    "Track: Control",
    "Track: Effects",
    "Instrument: Control",
    "Instrument: Loading",
    "Sequencer: Control",
    "Sequencer: Navigation",
    "Mixer: Control",
    "Utility: General",
    "Paketti Gadgets: General",
    "Paketti Gadgets: Tools",
    "Experimental: Test"
  }
  
  -- Initialize tree structure
  for i, category in ipairs(categories) do
    table.insert(dynamic_tree, {
      id = i,
      name = category,
      items = {}
    })
  end
  
  -- Sort commands into categories
  for _, command in ipairs(commands) do
    for i, branch in ipairs(dynamic_tree) do
      if branch.name == command.category then
        -- Avoid duplicates by checking if command already exists
        local exists = false
        for _, existing_item in ipairs(branch.items) do
          if existing_item.name == command.name then
            exists = true
            break
          end
        end
        
        if not exists then
          table.insert(branch.items, {
            name = command.name,
            invoke = command.invoke,
            type = command.type
          })
        end
        break
      end
    end
  end
  
  -- Sort items within each category alphabetically and filter out empty categories
  local filtered_tree = {}
  for _, branch in ipairs(dynamic_tree) do
    if #branch.items > 0 then
      table.sort(branch.items, function(a, b) return a.name < b.name end)
      -- Update ID to reflect filtered position
      branch.id = #filtered_tree + 1
      table.insert(filtered_tree, branch)
    end
  end
  
  return filtered_tree
end

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

-- Helper function to get command data from dynamic tree
function PakettiTreeStructureGetCommandFromDynamicTree(item_name)
  local tree = PakettiTreeStructureBuildDynamicTree()
  
  for _, branch in ipairs(tree) do
    for _, item in ipairs(branch.items) do
      if item.name == item_name then
        return item
      end
    end
  end
  
  return nil
end

-- Function to execute a selected command using dynamic discovery
function PakettiTreeStructureExecuteTreeCommand(item_name)
  local command_data = PakettiTreeStructureGetCommandFromDynamicTree(item_name)
  if not command_data then
    renoise.app():show_status("No command found for: " .. item_name) [[memory:4430629]]
    return
  end
  
  local invoke_string = command_data.invoke
  if not invoke_string or invoke_string == "" then
    renoise.app():show_status("No invoke function for: " .. item_name) [[memory:4430629]]
    return
  end
  
  renoise.app():show_status("Executing: " .. item_name) [[memory:4430629]]
  
  -- Execute the command using improved method from PakettiAutocomplete
  local success, error_msg = pcall(function()
    -- Check if it's a simple function name in global scope
    if _G[invoke_string] and type(_G[invoke_string]) == "function" then
      _G[invoke_string]()
    else
      -- Try to execute as loadstring for more complex invoke strings
      local func, load_error = loadstring(invoke_string)
      if func then
        func()
      else
        -- If loadstring fails, try executing the invoke string directly
        local direct_func, direct_error = loadstring("return " .. invoke_string)
        if direct_func then
          local result = direct_func()
          if type(result) == "function" then
            result()
          else
            renoise.app():show_status("Error: " .. invoke_string .. " is not a function") [[memory:4430629]]
          end
        else
          renoise.app():show_status("Error: Cannot execute " .. invoke_string .. " - " .. (load_error or direct_error or "unknown error")) [[memory:4430629]]
        end
      end
    end
  end)
  
  if not success then
    renoise.app():show_status("Error executing " .. item_name .. ": " .. tostring(error_msg)) [[memory:4430629]]
  end
end

-- Function to update the tree display (global, defined before first use)
function PakettiTreeStructureUpdateDisplay()
  if not tree_dialog or not tree_dialog.visible then
    return
  end
  
  -- Close and recreate the dialog with updated content
  tree_dialog:close()
  PakettiTreeStructureShow()
end

-- Function to create tree content using dynamic discovery
function PakettiTreeStructureCreateTreeContent()
  local content = tree_vb:column{
    spacing = 2,
    margin = 5
  }
  
  -- Get dynamic tree structure
  local dynamic_tree = PakettiTreeStructureBuildDynamicTree()
  
  -- Add main branches
  for i, branch in ipairs(dynamic_tree) do
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
        PakettiTreeStructureUpdateDisplay()
      end
    }
    
    content:add_child(branch_button)
    
    -- Add items if branch is expanded
    if current_expanded_branch == i then
      for j, item in ipairs(branch.items) do
        local item_color = {0x20, 0x20, 0x20} -- Dark gray for items
        local item_text = string.format("  %s", item.name)
        
        if j == selected_item_index then
          item_color = {0x00, 0x80, 0x00} -- Green for selected
          item_text = string.format("► %s", item.name)
        end
        
        local item_button = tree_vb:button{
          text = item_text,
          width = 330,
          height = 20,
          color = item_color,
          notifier = function()
            selected_item_index = j
            PakettiTreeStructureUpdateDisplay()
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

-- Key handler function for tree navigation
function PakettiTreeStructureTreeKeyhandlerFunc(dialog, key)
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
  
  -- Handle numeric keys for branch navigation (support more branches now)
  if key.modifiers == "" and tonumber(key.name) then
    local branch_num = tonumber(key.name)
    local dynamic_tree = PakettiTreeStructureBuildDynamicTree()
    if branch_num >= 1 and branch_num <= math.min(9, #dynamic_tree) then
      if current_expanded_branch == branch_num then
        current_expanded_branch = 0  -- Collapse if already expanded
        selected_item_index = 1
      else
        current_expanded_branch = branch_num  -- Expand branch
        selected_item_index = 1
      end
      PakettiTreeStructureUpdateDisplay()
      return nil
    end
  end
  
  -- Handle navigation within expanded branch
  if current_expanded_branch > 0 then
    local dynamic_tree = PakettiTreeStructureBuildDynamicTree()
    local current_branch = dynamic_tree[current_expanded_branch]
    
    -- Up/Down arrow navigation
    if key.modifiers == "" and key.name == "up" then
      selected_item_index = math.max(1, selected_item_index - 1)
      PakettiTreeStructureUpdateDisplay()
      return nil
    elseif key.modifiers == "" and key.name == "down" then
      selected_item_index = math.min(#current_branch.items, selected_item_index + 1)
      PakettiTreeStructureUpdateDisplay()
      return nil
    end
    
    -- Enter to execute selected item
    if key.modifiers == "" and key.name == "return" then
      local selected_item = current_branch.items[selected_item_index]
      if selected_item then
        PakettiTreeStructureExecuteTreeCommand(selected_item.name)
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
      text = "Use numbers 1-9 to expand/collapse branches",
      style = "normal"
    },
    tree_vb:text{
      text = "Use arrow keys to navigate, Enter to execute",
      style = "normal"
    },
    tree_vb:space{height = 5}
  }
  
  -- Create tree content
  local tree_content = PakettiTreeStructureCreateTreeContent()
  
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
  tree_dialog = renoise.app():show_custom_dialog("Paketti Tree Structure", dialog_content, PakettiTreeStructureTreeKeyhandlerFunc)
  
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