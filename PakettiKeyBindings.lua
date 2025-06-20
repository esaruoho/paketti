-- Define the mapping between menu names and their corresponding identifiers
local menu_to_identifier = {
  ["Track Automation"] = "Automation",
  ["Sample Mappings"] = "Sample Keyzones"
}

local function sortKeybindings(filteredKeybindings)
  table.sort(filteredKeybindings, function(a, b)
    -- Split each Topic into its parts
    local a_parts = {}
    local b_parts = {}
    
    -- Split by spaces and store each part
    for part in a.Topic:gmatch("%S+") do
      table.insert(a_parts, part)
    end
    for part in b.Topic:gmatch("%S+") do
      table.insert(b_parts, part)
    end
    
    -- First compare by Identifier
    if a.Identifier ~= b.Identifier then
      return a.Identifier < b.Identifier
    end
    
    -- Then compare each Topic part in order
    for i = 1, math.min(#a_parts, #b_parts) do
      if a_parts[i] ~= b_parts[i] then
        return a_parts[i] < b_parts[i]
      end
    end
    
    -- If one has more parts than the other, shorter comes first
    if #a_parts ~= #b_parts then
      return #a_parts < #b_parts
    end
    
    -- If Topics are identical, sort by Binding
    return a.Binding < b.Binding
  end)
end

-- Variable declarations
local vb = renoise.ViewBuilder()
local dialog
local debug_log = ""
local suppress_debug_log
local pakettiKeybindings = {}
local identifier_switch
local keybinding_list
local total_shortcuts_text
local selected_shortcuts_text
local show_shortcuts_switch
local show_script_filter_switch  -- Add this line
local search_text
local search_textfield
local padding_number_identifier = 5  -- Padding between number and identifier
local padding_identifier_topic = 25  -- Padding between identifier and topic
local padding_topic_binding = 25  -- Padding between topic and binding

-- Renoise dialog variables
local renoise_dialog
local renoise_debug_log = ""
local renoise_suppress_debug_log
local renoiseKeybindings = {}
local renoise_identifier_dropdown
local renoise_keybinding_list
local renoise_total_shortcuts_text
local renoise_selected_shortcuts_text
local renoise_show_shortcuts_switch
local renoise_show_script_filter_switch
local renoise_search_text
local renoise_search_textfield

-- Function to replace XML encoded entities with their corresponding characters
local function decodeXMLString(value)
  local replacements = {
    ["&amp;"] = "&",
    -- Add more replacements if needed
  }
  return value:gsub("(&amp;)", replacements)
end

-- Combined function to parse XML and find keybindings based on filter type
function parseKeyBindingsXML(filePath, filter_type)
  local fileHandle = io.open(filePath, "r")
  if not fileHandle then
    if filter_type == "paketti" then
      debug_log = debug_log .. "Debug: Failed to open the file - " .. filePath .. "\n"
    else
      renoise_debug_log = renoise_debug_log .. "Debug: Failed to open the file - " .. filePath .. "\n"
    end
    return {}
  end

  local content = fileHandle:read("*all")
  fileHandle:close()

  local keybindings = {}
  local currentIdentifier = "nil"

  for categorySection in content:gmatch("<Category>(.-)</Category>") do
    local identifier = categorySection:match("<Identifier>(.-)</Identifier>") or "nil"
    if identifier ~= "nil" then
      currentIdentifier = identifier
    end

    for keyBindingSection in categorySection:gmatch("<KeyBinding>(.-)</KeyBinding>") do
      local topic = keyBindingSection:match("<Topic>(.-)</Topic>")
      
      -- Apply filter based on filter_type
      local should_include = false
      if filter_type == "paketti" then
        should_include = topic and topic:find("Paketti")
      elseif filter_type == "renoise" or filter_type == "all" then
        should_include = topic ~= nil
      end
      
      if should_include then
        local binding = keyBindingSection:match("<Binding>(.-)</Binding>") or "<No Binding>"
        local key = keyBindingSection:match("<Key>(.-)</Key>") or "<Shortcut not Assigned>"

        -- Decode XML entities
        topic = decodeXMLString(topic)
        binding = decodeXMLString(binding)
        key = decodeXMLString(key)

        table.insert(keybindings, { Identifier = currentIdentifier, Topic = topic, Binding = binding, Key = key })
        
        -- Log to appropriate debug log
        if filter_type == "paketti" then
          debug_log = debug_log .. "Debug: Found " .. filter_type .. " keybinding - " .. currentIdentifier .. ":" .. topic .. ":" .. binding .. ":" .. key .. "\n"
        else
          renoise_debug_log = renoise_debug_log .. "Debug: Found " .. filter_type .. " keybinding - " .. currentIdentifier .. ":" .. topic .. ":" .. binding .. ":" .. key .. "\n"
        end
      end
    end
  end

  return keybindings
end

-- Function to save the debug log
function pakettiKeyBindingsSaveDebugLog(filteredKeybindings, showUnassignedOnly)
  if not pakettiKeybindings then return end -- Ensure pakettiKeybindings is not nil

  local filePath = "KeyBindings/Debug_Paketti_KeyBindings.log"
  local fileHandle = io.open(filePath, "w")
  if fileHandle then
    local log_content = "Debug: Total Paketti keybindings found - " .. #pakettiKeybindings .. "\n"
    local count = 0
    for index, binding in ipairs(filteredKeybindings) do
      if not showUnassignedOnly or (showUnassignedOnly and binding.Key == "<Shortcut not Assigned>") then
        count = count + 1
        log_content = log_content .. string.format("%04d", count) .. ":" .. binding.Identifier .. ":" .. binding.Topic .. ": " .. binding.Binding .. ": " .. binding.Key .. "\n"
      end
    end
    fileHandle:write(log_content)
    fileHandle:close()
    renoise.app():show_status("Debug log saved to: " .. filePath)
  else
    renoise.app():show_status("Failed to save debug log.")
  end
end

-- Function to calculate the maximum length for entries
function pakettiCalculateMaxLength(entries)
  local max_length = 0
  for _, entry in ipairs(entries) do
    -- Account for the visual difference caused by the squiggle character
    local length_adjustment = entry.Binding:find("∿") and 2 or 0
    local length = #(string.format("%04d", 0) .. ":" .. entry.Identifier .. ":" .. entry.Topic .. ": " .. entry.Binding) - length_adjustment
    max_length = math.max(max_length, length)
  end
  return max_length
end

-- Function to update the list view based on the filter
function pakettiKeyBindingsUpdateList()
  if not identifier_switch then return end -- Ensure the switch is initialized

  local showUnassignedOnly = (show_shortcuts_switch.value == 2)
  local showAssignedOnly = (show_shortcuts_switch.value == 3)
  local scriptFilter = show_script_filter_switch.value  -- Get value from the switch
  local selectedIdentifier = identifier_switch.items[identifier_switch.value]
  local searchQuery = search_textfield.value:lower()
  local content = ""
  local count = 0
  local unassigned_count = 0
  local selected_count = 0
  local selected_unassigned_count = 0

  local filteredKeybindings = {}

  for _, binding in ipairs(pakettiKeybindings) do
    local isSelected = (selectedIdentifier == "All") or (binding.Identifier == selectedIdentifier)
    -- Normalize to lowercase for case-insensitive search
    local topic_lower = binding.Topic:lower()
    local binding_lower = binding.Binding:lower()
    local identifier_lower = binding.Identifier:lower()

    -- Display all entries if searchQuery is empty, otherwise match the query
    local matchesSearch = true
    for word in searchQuery:gmatch("%S+") do
      if not (topic_lower:find(word) or binding_lower:find(word) or identifier_lower:find(word) or binding.Key:lower():find(word)) then
        matchesSearch = false
        break
      end
    end

    -- Check if the entry should be included based on the scriptFilter
    local isScript = binding.Binding:find("∿") ~= nil
    local matchesScriptFilter = (scriptFilter == 1) or (scriptFilter == 2 and not isScript) or (scriptFilter == 3 and isScript)

    if isSelected and matchesSearch and matchesScriptFilter then
      -- Count unassigned regardless of show_unassigned_only
      if binding.Key == "<Shortcut not Assigned>" then
        unassigned_count = unassigned_count + 1
      end

      -- Filter based on the selected option (Show All, Show without Shortcuts, Show with Shortcuts)
      if (showUnassignedOnly and binding.Key == "<Shortcut not Assigned>") or
         (showAssignedOnly and binding.Key ~= "<Shortcut not Assigned>") or
         (not showUnassignedOnly and not showAssignedOnly) then

        table.insert(filteredKeybindings, binding)

        if binding.Key == "<Shortcut not Assigned>" then
          selected_unassigned_count = selected_unassigned_count + 1
        end

        selected_count = selected_count + 1
      end
    end
    count = count + 1
  end

  sortKeybindings(filteredKeybindings)

  if #filteredKeybindings == 0 then
    content = "No KeyBindings available for this filter."
  else
    -- Calculate max length across all entries
    local max_length = pakettiCalculateMaxLength(pakettiKeybindings) + 35

    -- Append the key, aligned right
    for index, binding in ipairs(filteredKeybindings) do
      local entry = string.format("%04d", index)
        .. string.rep(" ", padding_number_identifier) .. binding.Identifier
        .. string.rep(" ", padding_identifier_topic - #binding.Identifier)
        .. binding.Topic
        .. string.rep(" ", padding_topic_binding - #binding.Topic)
        .. binding.Binding

      -- Adjust the visual difference caused by the squiggle character
      local length_adjustment = binding.Binding:find("∿") and 2 or 0
      local readable_key = convert_key_name(binding.Key)
      local padded_entry = entry .. string.rep(" ", max_length - #entry + length_adjustment) .. " " .. readable_key
      content = content .. padded_entry .. "\n"
    end
  end

  keybinding_list.text = content

  local selectedText=""
  if selectedIdentifier == "All" then
    selectedText="For all sections, there are " .. selected_count .. " shortcuts and " .. selected_unassigned_count .. " are unassigned."
  else
    selectedText="For " .. selectedIdentifier .. ", there are " .. selected_count .. " shortcuts and " .. selected_unassigned_count .. " are unassigned."
  end

  selected_shortcuts_text.text = selectedText
  total_shortcuts_text.text="Total: " .. count .. " shortcuts, " .. unassigned_count .. " unassigned."

  if not suppress_debug_log then
    pakettiKeyBindingsSaveDebugLog(filteredKeybindings, showUnassignedOnly)
  end
end

-- Main function to display the Paketti keybindings dialog
function pakettiKeyBindingsDialog(selectedIdentifier)  -- Accept an optional parameter
  -- Check if the dialog is already visible and close it
  if dialog and dialog.visible then
    dialog:close()
    return
  end

  -- Map menu identifiers to their internal names
  if selectedIdentifier then
    selectedIdentifier = menu_to_identifier[selectedIdentifier] or selectedIdentifier
  end

  local keyBindingsPath = detectOSAndGetKeyBindingsPath()
  if not keyBindingsPath then
    renoise.app():show_status("Failed to detect OS and find KeyBindings.xml path.")
    return
  end

  debug_log = debug_log .. "Debug: Using KeyBindings path - " .. keyBindingsPath .. "\n"
  pakettiKeybindings = parseKeyBindingsXML(keyBindingsPath, "paketti")
  if not pakettiKeybindings or #pakettiKeybindings == 0 then
    renoise.app():show_status("No Paketti keybindings found.")
    debug_log = debug_log .. "Debug: Total Paketti keybindings found - 0\n"
    pakettiKeyBindingsSaveDebugLog(pakettiKeybindings, false)
    return
  end

  -- Print total found count at the start
  debug_log = "Debug: Total Paketti keybindings found - " .. #pakettiKeybindings .. "\n" .. debug_log

  -- Collect all unique Identifiers and sort them alphabetically
  local identifier_items = { "All" }
  local unique_identifiers = {}
  for _, binding in ipairs(pakettiKeybindings) do
    if not unique_identifiers[binding.Identifier] then
      unique_identifiers[binding.Identifier] = true
      table.insert(identifier_items, binding.Identifier)
    end
  end
  table.sort(identifier_items)

  -- Determine the index of the selectedIdentifier
  local selected_index = 1 -- Default to "All"
  if selectedIdentifier then
    -- Map the identifier before looking for its index
    local mapped_identifier = menu_to_identifier[selectedIdentifier] or selectedIdentifier
    for i, id in ipairs(identifier_items) do
      if id == mapped_identifier then
        selected_index = i
        break
      end
    end
  end

  identifier_switch = vb:popup{
    items = identifier_items,
    width=300,
    value = selected_index,
    notifier = pakettiKeyBindingsUpdateList
  }

  -- Create the switch for showing/hiding shortcuts
  show_shortcuts_switch = vb:switch {
    items = { "Show All", "Show KeyBindings without Shortcuts", "Show KeyBindings with Shortcuts" },
    width=1100,
    value = 1, -- Default to "Show All"
    notifier = pakettiKeyBindingsUpdateList
  }

  show_script_filter_switch = vb:switch {
    items = { "All", "Show without Tools", "Show Only Tools" },
    width=1100,
    value = 1,
    notifier=function(value)
      pakettiKeyBindingsUpdateList()
      if value == 1 then
        renoise.app():show_status("Now showing all KeyBindings")
      elseif value == 2 then
        renoise.app():show_status("Now showing KeyBindings without Tools")
      elseif value == 3 then
        renoise.app():show_status("Now showing KeyBindings with only Tools")
      end
    end
  }

  -- UI Elements
  search_textfield = vb:textfield {
    width=300,
    notifier = pakettiKeyBindingsUpdateList
  }

  total_shortcuts_text = vb:text{
    text="Total: 0 shortcuts, 0 unassigned",
    font = "bold",
    width=1100, -- Adjusted width to fit the dialog
    align="left"
  }

  selected_shortcuts_text = vb:text{
    text="For selected sections, there are 0 shortcuts and 0 are unassigned.",
    font = "bold",
    width=1100, -- Adjusted width to fit the dialog
    align="left"
  }

  search_text = vb:text{text="Filter with"}


  keybinding_list = vb:multiline_textfield { width=1100, height = 600, font = "mono" }

  -- Dialog title including Renoise version
  local dialog_title = "Paketti KeyBindings for Renoise Version v3.4.4" -- .. renoise.RENOISE_VERSION

  dialog = renoise.app():show_custom_dialog(dialog_title,
    vb:column{
      margin=10,
      vb:text{
        text="NOTE: KeyBindings.xml is only saved when Renoise is closed - so this is not a realtime / updatable Dialog. Make changes, quit Renoise, and relaunch this Dialog.",
        font = "bold"
      },
      identifier_switch,
      show_shortcuts_switch,
vb:row{vb:button{text="Save as Textfile", notifier=function()
    local filename = renoise.app():prompt_for_filename_to_write("*.txt", "Available Plugins Saver")
    if filename then
      local file, err = io.open(filename, "w")
      if file then
        file:write(keybinding_list.text)  -- Correct reference to multiline_field's text
        file:close()
        renoise.app():show_status("File saved successfully")
      else
        renoise.app():show_status("Error saving file: " .. err)
      end
    end
  end}},

      search_text,
      search_textfield,
      keybinding_list,
      selected_shortcuts_text,
      total_shortcuts_text
    },my_keyhandler_func)

  -- Initial list update
  pakettiKeyBindingsUpdateList()

  -- Print total found count at the end
  debug_log = debug_log .. "Debug: Total Paketti keybindings found - " .. #pakettiKeybindings .. "\n"
  pakettiKeyBindingsSaveDebugLog(pakettiKeybindings, false)
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:!Preferences..:Paketti KeyBindings...",invoke=function() pakettiKeyBindingsDialog() end}
-- Single list of valid menu locations (using correct menu paths)
local menu_entries = {
  "Track Automation",  -- This will map to "Automation"
  "Disk Browser",
  "DSP Chain",
  "Instrument Box",
  "Mixer",
  "Pattern Editor",
  "Pattern Matrix",
  "Pattern Sequencer",
  "Phrase Editor",
  "Phrase Map",
  "Sample Editor",
  "Sample FX Mixer",
  "Sample Mappings",  -- This will map to "Sample Keyzones"
  "Sample Modulation Matrix"
}

for _, menu_name in ipairs(menu_entries) do
  -- Get the correct identifier (handle special cases)
  local identifier = menu_to_identifier[menu_name] or menu_name
  
  renoise.tool():add_menu_entry{name="--" .. menu_name .. ":Paketti Gadgets..:Paketti KeyBindings Dialog...",invoke=function() pakettiKeyBindingsDialog(identifier) end}
  renoise.tool():add_menu_entry{name=menu_name .. ":Paketti Gadgets..:Renoise KeyBindings Dialog...",invoke=function() pakettiRenoiseKeyBindingsDialog(identifier) end}
end

renoise.tool():add_keybinding{name="Global:Paketti:Show Paketti KeyBindings Dialog...",invoke=function() pakettiKeyBindingsDialog() end}
renoise.tool():add_keybinding{name="Global:Paketti:Show Renoise KeyBindings Dialog...",invoke=function() pakettiRenoiseKeyBindingsDialog() end}
-------------------------------------------

-- Function to detect OS and construct the KeyBindings.xml path
function detectOSAndGetKeyBindingsPath()
  local os_name = os.platform() 
  local renoise_version = renoise.RENOISE_VERSION:match("(%d+%.%d+%.%d+)") -- This will grab just "3.5.0" from "3.5.0 b8"
  local key_bindings_path

  if os_name == "WINDOWS" then
    local home = os.getenv("USERPROFILE") or os.getenv("HOME")
    key_bindings_path = home .. "\\AppData\\Roaming\\Renoise\\V" .. renoise_version .. "\\KeyBindings.xml"
  elseif os_name == "MACINTOSH" then
    local home = os.getenv("HOME")
    key_bindings_path = home .. "/Library/Preferences/Renoise/V" .. renoise_version .. "/KeyBindings.xml"
  else -- Assume Linux
    local home = os.getenv("HOME")
    key_bindings_path = home .. "/.config/Renoise/V" .. renoise_version .. "/KeyBindings.xml"
  end

  return key_bindings_path
end

-- Function to parse XML for Renoise content using the combined parser
function renoiseKeyBindingsParseXML(filePath)
  return parseKeyBindingsXML(filePath, "renoise")
end

-- Function to save the debug log
function renoiseKeyBindingsSaveDebugLog(filteredKeybindings, showUnassignedOnly)
  if not renoiseKeybindings then return end -- Ensure renoiseKeybindings is not nil

  local filePath = "KeyBindings/Debug_Renoise_KeyBindings.log"
  local fileHandle = io.open(filePath, "w")
  if fileHandle then
    local log_content = "Debug: Total Renoise keybindings found - " .. #renoiseKeybindings .. "\n"
    local count = 0
    for index, binding in ipairs(filteredKeybindings) do
      if not showUnassignedOnly or (showUnassignedOnly and binding.Key == "<Shortcut not Assigned>") then
        count = count + 1
        log_content = log_content .. string.format("%04d", count) .. ":" .. binding.Identifier .. ":" .. binding.Topic .. ": " .. binding.Binding .. ": " .. binding.Key .. "\n"
      end
    end
    fileHandle:write(log_content)
    fileHandle:close()
    renoise.app():show_status("Debug log saved to: " .. filePath)
  else
    renoise.app():show_status("Failed to save debug log.")
  end
end

-- Function to calculate the maximum length for entries
function renoiseCalculateMaxLength(entries)
  local max_length = 0
  for _, entry in ipairs(entries) do
    -- Account for the visual difference caused by the squiggle character
    local length_adjustment = entry.Binding:find("∿") and 2 or 0
    local length = #(string.format("%04d", 0) .. ":" .. entry.Identifier .. ":" .. entry.Topic .. ": " .. entry.Binding) - length_adjustment
    max_length = math.max(max_length, length)
  end
  return max_length
end

-- Function to update the list view based on the filter
function renoiseKeyBindingsUpdateList()
  if not renoise_identifier_dropdown then return end -- Ensure the dropdown is initialized

  local showUnassignedOnly = (renoise_show_shortcuts_switch.value == 2)
  local showAssignedOnly = (renoise_show_shortcuts_switch.value == 3)
  local scriptFilter = renoise_show_script_filter_switch.value
  local selectedIdentifier = renoise_identifier_dropdown.items[renoise_identifier_dropdown.value]
  local searchQuery = renoise_search_textfield.value:lower()
  local content = ""
  local count = 0
  local unassigned_count = 0
  local selected_count = 0
  local selected_unassigned_count = 0

  local filteredKeybindings = {}

  for _, binding in ipairs(renoiseKeybindings) do
    local isSelected = (selectedIdentifier == "All") or (binding.Identifier == selectedIdentifier)
    -- Normalize to lowercase for case-insensitive search
    local topic_lower = binding.Topic:lower()
    local binding_lower = binding.Binding:lower()
    local identifier_lower = binding.Identifier:lower()

    -- Display all entries if searchQuery is empty, otherwise match the query
    local matchesSearch = true
    for word in searchQuery:gmatch("%S+") do
      if not (topic_lower:find(word) or binding_lower:find(word) or identifier_lower:find(word) or binding.Key:lower():find(word)) then
        matchesSearch = false
        break
      end
    end

    -- Check if the entry should be included based on the scriptFilter
    local isScript = binding.Binding:find("∿") ~= nil
    local matchesScriptFilter = (scriptFilter == 1) or (scriptFilter == 2 and not isScript) or (scriptFilter == 3 and isScript)

    if isSelected and matchesSearch and matchesScriptFilter then
      -- Count unassigned regardless of show_unassigned_only
      if binding.Key == "<Shortcut not Assigned>" then
        unassigned_count = unassigned_count + 1
      end

      -- Filter based on the selected option (Show All, Show without Shortcuts, Show with Shortcuts)
      if (showUnassignedOnly and binding.Key == "<Shortcut not Assigned>") or
         (showAssignedOnly and binding.Key ~= "<Shortcut not Assigned>") or
         (not showUnassignedOnly and not showAssignedOnly) then

        table.insert(filteredKeybindings, binding)

        if binding.Key == "<Shortcut not Assigned>" then
          selected_unassigned_count = selected_unassigned_count + 1
        end

        selected_count = selected_count + 1
      end
    end
    count = count + 1
  end

  sortKeybindings(filteredKeybindings)

  if #filteredKeybindings == 0 then
    content = "No KeyBindings available for this filter."
  else
    -- Calculate max length across all entries
    local max_length = renoiseCalculateMaxLength(renoiseKeybindings) + 35

    -- Append the key, aligned right
    for index, binding in ipairs(filteredKeybindings) do
      local entry = string.format("%04d", index)
        .. string.rep(" ", padding_number_identifier) .. binding.Identifier
        .. string.rep(" ", padding_identifier_topic - #binding.Identifier)
        .. binding.Topic
        .. string.rep(" ", padding_topic_binding - #binding.Topic)
        .. binding.Binding

      -- Adjust the visual difference caused by the squiggle character
      local length_adjustment = binding.Binding:find("∿") and 2 or 0
      local readable_key = convert_key_name(binding.Key)
      local padded_entry = entry .. string.rep(" ", max_length - #entry + length_adjustment) .. " " .. readable_key
      content = content .. padded_entry .. "\n"
    end
  end

  renoise_keybinding_list.text = content

  local selectedText=""
  if selectedIdentifier == "All" then
    selectedText="For all sections, there are " .. selected_count .. " shortcuts and " .. selected_unassigned_count .. " are unassigned."
  else
    selectedText="For " .. selectedIdentifier .. ", there are " .. selected_count .. " shortcuts and " .. selected_unassigned_count .. " are unassigned."
  end

  renoise_selected_shortcuts_text.text = selectedText
  renoise_total_shortcuts_text.text="Total: " .. count .. " shortcuts, " .. unassigned_count .. " unassigned."

  if not renoise_suppress_debug_log then
    renoiseKeyBindingsSaveDebugLog(filteredKeybindings, showUnassignedOnly)
  end
end


-- Main function to display the Renoise keybindings dialog
function pakettiRenoiseKeyBindingsDialog(selectedIdentifier)  -- Accept an optional parameter
  -- Check if the dialog is already visible and close it
  if renoise_dialog and renoise_dialog.visible then
    renoise_dialog:close()
    return
  end

  -- Map menu identifiers to their internal names
  if selectedIdentifier then
    selectedIdentifier = menu_to_identifier[selectedIdentifier] or selectedIdentifier
  end

  local keyBindingsPath = detectOSAndGetKeyBindingsPath()
  if not keyBindingsPath then
    renoise.app():show_status("Failed to detect OS and find KeyBindings.xml path.")
    return
  end

  renoise_debug_log = renoise_debug_log .. "Debug: Using KeyBindings path - " .. keyBindingsPath .. "\n"
  renoiseKeybindings = renoiseKeyBindingsParseXML(keyBindingsPath)
  if not renoiseKeybindings or #renoiseKeybindings == 0 then
    renoise.app():show_status("No Renoise keybindings found.")
    renoise_debug_log = renoise_debug_log .. "Debug: Total Renoise keybindings found - 0\n"
    renoiseKeyBindingsSaveDebugLog(renoiseKeybindings, false)
    return
  end

  -- Print total found count at the start
  renoise_debug_log = "Debug: Total Renoise keybindings found - " .. #renoiseKeybindings .. "\n" .. renoise_debug_log

  -- Collect all unique Identifiers and sort them alphabetically
  local identifier_items = { "All" }
  local unique_identifiers = {}
  for _, binding in ipairs(renoiseKeybindings) do
    if not unique_identifiers[binding.Identifier] then
      unique_identifiers[binding.Identifier] = true
      table.insert(identifier_items, binding.Identifier)
    end
  end
  table.sort(identifier_items)

  -- Determine the index of the selectedIdentifier
  local selected_index = 1 -- Default to "All"
  if selectedIdentifier then
    -- Map the identifier before looking for its index
    local mapped_identifier = menu_to_identifier[selectedIdentifier] or selectedIdentifier
    for i, id in ipairs(identifier_items) do
      if id == mapped_identifier then
        selected_index = i
        break
      end
    end
  end

  -- Create the dropdown menu for identifier selection
  renoise_identifier_dropdown = vb:popup{
    items = identifier_items,
    width=300,
    value = selected_index,  -- Set the dropdown to the selected identifier
    notifier = renoiseKeyBindingsUpdateList
  }

  -- Create the switch for showing/hiding shortcuts
  renoise_show_shortcuts_switch = vb:switch {
    items = { "Show All", "Show without Shortcuts", "Show with Shortcuts" },
    width=1100,
    value = 1, -- Default to "Show All"
    notifier = renoiseKeyBindingsUpdateList
  }

  -- Create the switch for showing/hiding tools/scripts
  renoise_show_script_filter_switch = vb:switch {
    items = { "All", "Show without Tools", "Show Only Tools" },
    width=1100,
    value = 1, -- Default to "All"
    notifier=function(value)
      renoiseKeyBindingsUpdateList()
      if value == 1 then
        renoise.app():show_status("Now showing all KeyBindings")
      elseif value == 2 then
        renoise.app():show_status("Now showing KeyBindings without Tools")
      elseif value == 3 then
        renoise.app():show_status("Now showing KeyBindings with only Tools")
      end
    end
  }

  -- UI Elements
  renoise_search_textfield = vb:textfield{width=300, notifier=renoiseKeyBindingsUpdateList}

  renoise_total_shortcuts_text = vb:text{
    text="Total: 0 shortcuts, 0 unassigned",
    font = "bold",
    width=1100, -- Adjusted width to fit the dialog
    align="left"
  }

  renoise_selected_shortcuts_text = vb:text{
    text="For selected sections, there are 0 shortcuts and 0 are unassigned.",
    font = "bold",
    width=1100, -- Adjusted width to fit the dialog
    align="left"
  }

  renoise_search_text = vb:text{text="Filter with"}

  renoise_keybinding_list = vb:multiline_textfield { width=1100, height = 600, font = "mono" }

  -- Dialog title including Renoise version
  local dialog_title = "Renoise KeyBindings for Renoise Version v3.4.4" -- .. renoise.RENOISE_VERSION

  renoise_dialog = renoise.app():show_custom_dialog(dialog_title,
    vb:column{
      margin=10,
      vb:text{
        text="NOTE: KeyBindings.xml is only saved when Renoise is closed - so this is not a realtime / updatable Dialog. Make changes, quit Renoise, and relaunch this Dialog.",
        font = "bold"
      },
      renoise_identifier_dropdown,
      renoise_show_script_filter_switch,
      renoise_show_shortcuts_switch,
      vb:row{
        vb:button{
          text="Save as Textfile",
          notifier=function()
            local filename = renoise.app():prompt_for_filename_to_write("*.txt", "Available Plugins Saver")
            if filename then
              local file, err = io.open(filename, "w")
              if file then
                file:write(renoise_keybinding_list.text)  -- Correct reference to multiline_field's text
                file:close()
                renoise.app():show_status("File saved successfully")
              else
                renoise.app():show_status("Error saving file: " .. err)
              end
            end
          end
        }
      },
      renoise_search_text,
      renoise_search_textfield,
      renoise_keybinding_list,
      renoise_selected_shortcuts_text,
      renoise_total_shortcuts_text},my_keyhandler_func)

  -- Initial list update
  renoiseKeyBindingsUpdateList()

  -- Print total found count at the end
  renoise_debug_log = renoise_debug_log .. "Debug: Total Renoise keybindings found - " .. #renoiseKeybindings .. "\n"
  renoiseKeyBindingsSaveDebugLog(renoiseKeybindings, false)
end


-- Add submenu entries under corresponding identifiers
local renoise_identifiers = {
  "Automation",
  "Disk Browser",
  "DSP Chain",
  "Instrument Box",
  "Mixer",
  "Pattern Editor",
  "Pattern Matrix",
  "Pattern Sequencer",
  "Phrase Editor",
  "Phrase Map",
  "Sample Editor",
  "Sample FX Mixer",
  "Sample Keyzones",
  "Sample Modulation Matrix",
}

for _, identifier in ipairs(renoise_identifiers) do
  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:!Preferences..:Renoise KeyBindings..:" .. identifier,
    invoke=function() pakettiRenoiseKeyBindingsDialog(identifier) end}
  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:!Preferences..:Paketti KeyBindings..:" .. identifier,
    invoke=function() pakettiKeyBindingsDialog(identifier) end}  
end





----------
-- Define possible keys that can be used in shortcuts
local possible_keys = {
  -- Letters
  "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
  "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
  
  -- Numbers (both number row and numpad)
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
  
  -- Special characters
  "!", "@", "#", "$", "%", "^", "&", "*", "(", ")",
  "+", "-", "=", "_", 
  "[", "]", "{", "}", 
  ";", ":", "'", "\"",
  ",", ".", "/", "?",
  "\\", "|",
  "<", ">",
  
  -- International characters
  "Å", "Ä", "Ö", "å", "ä", "ö",
  "É", "È", "Ê", "Ë", "é", "è", "ê", "ë",
  "Ñ", "ñ", "ß", "§", "¨", "´", "`", "~",
  
  -- Function keys
  "F1", "F2", "F3", "F4", "F5", "F6",
  "F7", "F8", "F9", "F10", "F11", "F12",
  
  -- Navigation keys
  "Left", "Right", "Up", "Down",
  "Home", "End", "PageUp", "PageDown",
  
  -- Editing keys
  "Space", "Tab", "Return", "Enter",
  "Backspace", "Delete", "Insert", "Escape",
  
  -- Numpad specific
  "Numpad0", "Numpad1", "Numpad2", "Numpad3", "Numpad4",
  "Numpad5", "Numpad6", "Numpad7", "Numpad8", "Numpad9",
  "NumpadMultiply", "NumpadDivide", "NumpadAdd", 
  "NumpadSubtract", "NumpadDecimal", "NumpadEnter"
}

-- Add mapping for special characters to their Renoise XML names
local key_xml_names = {
  ["<"] = "PeakedBracket",
  [">"] = "PeakedBracket",  -- Note: Shift + PeakedBracket
  ["{"] = "CurlyBracket",
  ["}"] = "CurlyBracket",
  ["["] = "SquareBracket",
  ["]"] = "SquareBracket",
  -- Add any other special character mappings here
}


-- Add this mapping for the correct modifier names as they appear in KeyBindings.xml
local modifier_xml_names = {
  -- macOS
  ["Ctrl"] = "Control",
  ["Cmd"] = "Command",
  ["Option"] = "Option",
  ["Shift"] = "Shift",
  -- Windows/Linux
  ["Alt"] = "Alt"
}



-- Cache for used combinations
local used_combinations_cache = nil

function get_used_combinations()
  if used_combinations_cache then
    return used_combinations_cache
  end
  
  local used_combinations = {}
  local keyBindingsPath = detectOSAndGetKeyBindingsPath()
  
  print("\nDEBUG: Reading from " .. keyBindingsPath)
  
  local file = io.open(keyBindingsPath, "r")
  if not file then
    print("ERROR: Could not open KeyBindings.xml")
    return used_combinations
  end
  
  local content = file:read("*all")
  file:close()
  
  -- Parse each line looking for key combinations
  for line in content:gmatch("[^\r\n]+") do
    local key = line:match("<Key>([^<]+)</Key>")
    if key and key ~= "<Shortcut not Assigned>" then
      print("DEBUG: Found XML key: '" .. key .. "'")
      used_combinations[key] = true
    end
  end
  
  print("\nDEBUG: All used combinations:")
  for combo in pairs(used_combinations) do
    print("  '" .. combo .. "'")
  end
  
  used_combinations_cache = used_combinations
  return used_combinations
end

-- Function to save results to a file
function save_combinations_to_file(combinations, filename)
  local file = io.open(filename, "w")
  if not file then
    print("Error: Could not open file for writing")
    return false
  end
  
  for _, combo in ipairs(combinations) do
    file:write(combo .. "\n")
  end
  
  file:close()
  return true
end


function check_free_combinations(selected_modifiers)
  local used_combinations = get_used_combinations()
  local free_combinations = {}
  
  -- First normalize the modifier order to match XML exactly
  local ordered_mods = normalize_modifier_order(selected_modifiers)
  print("\nDEBUG: Normalized modifiers:", table.concat(ordered_mods, ", "))
  
  for _, key in ipairs(possible_keys) do
    local xml_key = key_xml_names[key] or key
    local combo = #ordered_mods > 0 and 
      table.concat(ordered_mods, " + ") .. " + " .. xml_key or 
      xml_key
      
    print("\nDEBUG: Checking combo: '" .. combo .. "'")
    if used_combinations[combo] then
      print("  USED: '" .. combo .. "'")
    else
      print("  FREE: '" .. combo .. "'")
      table.insert(free_combinations, combo)
    end
  end
  
  return free_combinations
end

-- Also fix the print_free_combinations function to use correct names
function print_free_combinations()
  local os_name = os.platform()
  local modifiers = os_name == "MACINTOSH" and {
    {"Control"}, {"Command"}, {"Option"}, {"Shift"},
    {"Shift", "Option"}, {"Shift", "Command"}, {"Shift", "Control"},
    {"Option", "Command"}, {"Option", "Control"}, {"Command", "Control"},
    {"Shift", "Option", "Command"}, {"Shift", "Option", "Control"},
    {"Shift", "Command", "Control"}, {"Option", "Command", "Control"},
    {"Shift", "Option", "Command", "Control"}
  } or {
    {"Control"}, {"Alt"}, {"Shift"},
    {"Shift", "Alt"}, {"Shift", "Control"}, {"Alt", "Control"},
    {"Shift", "Alt", "Control"}
  }

  local all_results = {}
  print(string.format("Free combinations for %s:", os_name == "MACINTOSH" and "macOS" or "Windows/Linux"))
  
  for _, mod_set in ipairs(modifiers) do
    local mod_string = table.concat(mod_set, "+")
    local free = check_free_combinations(mod_set)
    print(string.format("\nThere are %d free combinations with %s:", #free, mod_string))
    
    -- Add section header to the file results
    table.insert(all_results, string.format("\nThere are %d free combinations with %s:", #free, mod_string))
    
    for _, combo in ipairs(free) do
      print("  " .. combo)
      -- Add each combination to the file results
      table.insert(all_results, "  " .. combo)
    end
  end  
  -- Save results to file
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local filename = "free_keybindings_" .. timestamp .. ".txt"
  if save_combinations_to_file(all_results, filename) then
    print("\nResults saved to: " .. filename)
  end
end

-- Function to show the free keybindings dialog
function pakettiFreeKeybindingsDialog()
  local vb = renoise.ViewBuilder()
  local dialog_content = vb:column{
    margin=renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
    spacing=renoise.ViewBuilder.DEFAULT_CONTROL_SPACING
  }
  
  -- Get OS name first
  local os_name = os.platform()
  
  -- Create modifier checkboxes based on OS
  local checkbox_row = vb:row{spacing=10}
  
  -- Declare modifier_checkboxes before assignment
  local modifier_checkboxes
  
  -- Declare results_view early as it's used in update_free_list
  local results_view = vb:multiline_textfield{
    width=400,
    height = 400,
    font = "mono",
    edit_mode = false
  }
  
  -- Function to update the free combinations list - declare before it's used in notifiers
  local function update_free_list()
    local selected_modifiers = {}
    if os_name == "MACINTOSH" then
      -- Add modifiers in the correct order
      if modifier_checkboxes.shift.box.value then table.insert(selected_modifiers, "Shift") end
      if modifier_checkboxes.option.box.value then table.insert(selected_modifiers, "Option") end
      if modifier_checkboxes.cmd.box.value then table.insert(selected_modifiers, "Command") end
      if modifier_checkboxes.ctrl.box.value then table.insert(selected_modifiers, "Control") end
    else
      if modifier_checkboxes.shift.box.value then table.insert(selected_modifiers, "Shift") end
      if modifier_checkboxes.alt.box.value then table.insert(selected_modifiers, "Alt") end
      if modifier_checkboxes.ctrl.box.value then table.insert(selected_modifiers, "Control") end
    end
    
    print("\nDEBUG: Selected modifiers:", table.concat(selected_modifiers, ", "))
    
    local free = check_free_combinations(selected_modifiers)
    local text = string.format("There are %d free combinations with %s:\n\n", 
      #free,
      #selected_modifiers > 0 and table.concat(selected_modifiers, " + ") or "no modifiers")
    
    for _, combo in ipairs(free) do
      text = text .. combo .. "\n"
    end
    
    results_view.text = text
  end

  if os_name == "MACINTOSH" then
    modifier_checkboxes = {
      ctrl = {
        box = vb:checkbox{notifier=function() update_free_list() end},
        label = vb:text{text="Control"}
      },
      cmd = {
        box = vb:checkbox{notifier=function() update_free_list() end},
        label = vb:text{text="Command"}
      },
      option = {
        box = vb:checkbox{notifier=function() update_free_list() end},
        label = vb:text{text="Option"}
      },
      shift = {
        box = vb:checkbox{notifier=function() update_free_list() end},
        label = vb:text{text="Shift"}
      }
    }
  else
    modifier_checkboxes = {
      ctrl = {
        box = vb:checkbox{notifier=function() update_free_list() end},
        label = vb:text{text="Control"}
      },
      alt = {
        box = vb:checkbox{notifier=function() update_free_list() end},
        label = vb:text{text="Alt"}
      },
      shift = {
        box = vb:checkbox{notifier=function() update_free_list() end},
        label = vb:text{text="Shift"}
      }
    }
  end
  
  -- Create rows with checkboxes and labels
  for _, mod in pairs(modifier_checkboxes) do
    local mod_row = vb:row{
      spacing=4,
      mod.box,
      mod.label
    }
    checkbox_row:add_child(mod_row)
  end

  -- Add the checkbox row to dialog_content
  dialog_content:add_child(checkbox_row)

  local save_button = vb:button{
    text="Save to File",
    notifier=function()
      local selected_modifiers = {}
      if os_name == "MACINTOSH" then
        if modifier_checkboxes.ctrl.box.value then table.insert(selected_modifiers, "Ctrl") end
        if modifier_checkboxes.cmd.box.value then table.insert(selected_modifiers, "Cmd") end
        if modifier_checkboxes.option.box.value then table.insert(selected_modifiers, "Option") end
        if modifier_checkboxes.shift.box.value then table.insert(selected_modifiers, "Shift") end
      else
        if modifier_checkboxes.ctrl.box.value then table.insert(selected_modifiers, "Ctrl") end
        if modifier_checkboxes.alt.box.value then table.insert(selected_modifiers, "Alt") end
        if modifier_checkboxes.shift.box.value then table.insert(selected_modifiers, "Shift") end
      end
      
      local free = check_free_combinations(selected_modifiers)
      local timestamp = os.date("%Y%m%d_%H%M%S")
      local filename = "free_keybindings_" .. timestamp .. ".txt"
      
      if save_combinations_to_file(free, filename) then
        renoise.app():show_message("Results saved to: " .. filename)
      else
        renoise.app():show_error("Failed to save results")
      end
    end
  }
  dialog_content:add_child(save_button)
  
  -- Add results view to dialog
  dialog_content:add_child(results_view)
  
  -- Show dialog
  renoise.app():show_custom_dialog("Free Keybindings Finder", dialog_content)
  
  -- Initial update
  update_free_list()
end
renoise.tool():add_keybinding{name="Global:Paketti:Show Free KeyBindings Dialog...",invoke=pakettiFreeKeybindingsDialog}

-- Function to normalize modifier order to match Renoise's XML format
function normalize_modifier_order(modifiers)
  -- Renoise's exact order: Shift, Option, Command, Control
  local ordered = {}
  local has = {
    Shift = false,
    Option = false,
    Command = false,
    Control = false,
    Alt = false  -- Windows version of Option
  }
  
  -- Mark which modifiers we have
  for _, mod in ipairs(modifiers) do
    has[mod] = true
  end
  
  -- Add them in Renoise's EXACT order
  if has.Shift then table.insert(ordered, "Shift") end
  if has.Option or has.Alt then table.insert(ordered, "Option") end
  if has.Command then table.insert(ordered, "Command") end
  if has.Control then table.insert(ordered, "Control") end
  
  return ordered
end

function generate_combinations(modifiers)
  local combinations = {}
  
  -- First normalize the modifier order to match XML exactly
  modifiers = normalize_modifier_order(modifiers)
  
  for _, key in ipairs(possible_keys) do
    local xml_key = key_xml_names[key] or key
    local combo = #modifiers > 0 and 
      table.concat(modifiers, " + ") .. " + " .. xml_key or  -- Note: spaces around + to match XML exactly
      xml_key
      
    table.insert(combinations, combo)
  end
  
  return combinations
end

-- Add this function near the top with other function definitions
function convert_key_name(key)
  -- Split the key combination into parts
  local parts = {}
  for part in key:gmatch("[^%+]+") do
    -- Trim spaces
    part = part:match("^%s*(.-)%s*$")
    -- Convert special keys
    if part == "Backslash" then part = "\\"
    elseif part == "Slash" then part = "/"
    elseif part == "Apostrophe" then part = "'"
    elseif part == "PeakedBracket" then part = "<"
    elseif part == "Capital" then part = "CapsLock"
    elseif part == "Grave" then part = "§"
    elseif part == "Comma" then part = ","
    end
    table.insert(parts, part)
  end
  return table.concat(parts, " + ")
end

