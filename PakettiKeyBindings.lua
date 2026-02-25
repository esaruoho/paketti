
-- Define the mapping between menu names and their corresponding identifiers
local menu_to_identifier = {
  ["Track Automation"] = "Automation",
  ["Sample Mappings"] = "Sample Keyzones"
}

local function sortKeybindings(filteredKeybindings)
  table.sort(filteredKeybindings, function(a, b)
    -- First compare by Identifier
    if a.Identifier ~= b.Identifier then
      return a.Identifier < b.Identifier
    end

    -- Use pre-computed topic parts
    local a_parts = a._topic_parts
    local b_parts = b._topic_parts

    -- Compare each Topic part in order
    local min_len = #a_parts < #b_parts and #a_parts or #b_parts
    for i = 1, min_len do
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

-- Shared ViewBuilder and padding constants
local vb = renoise.ViewBuilder()
local padding_number_identifier = 5
local padding_identifier_topic = 25
local padding_topic_binding = 25

-- State table factory for each dialog instance
local function createDialogState(config)
  return {
    -- Data (populated at dialog open)
    keybindings = {},
    max_length = 0,
    by_identifier = {},
    total_count = 0,
    unassigned_count = 0,
    current_search_text = "",
    debug_log = "",
    suppress_debug_log = true,

    -- UI widget refs (set during dialog creation, nil until then)
    identifier_switch = nil,
    keybinding_list = nil,
    total_shortcuts_text = nil,
    selected_shortcuts_text = nil,
    show_shortcuts_switch = nil,
    show_script_filter_switch = nil,
    search_display_text = nil,
    dialog_ref = nil,

    -- Config (immutable)
    filter_type = config.filter_type,
    debug_log_path = config.debug_log_path,
    dialog_title_prefix = config.dialog_title_prefix,
    shortcuts_switch_items = config.shortcuts_switch_items,
    show_script_filter_in_dialog = config.show_script_filter_in_dialog,
    empty_status_message = config.empty_status_message,
  }
end

local paketti_state = createDialogState({
  filter_type = "paketti",
  debug_log_path = "KeyBindings/Debug_Paketti_KeyBindings.log",
  dialog_title_prefix = "Paketti",
  shortcuts_switch_items = {"Show All", "Show KeyBindings without Shortcuts", "Show KeyBindings with Shortcuts"},
  show_script_filter_in_dialog = false,
  empty_status_message = "No Paketti keybindings found.",
})

local renoise_state = createDialogState({
  filter_type = "renoise",
  debug_log_path = "KeyBindings/Debug_Renoise_KeyBindings.log",
  dialog_title_prefix = "Renoise",
  shortcuts_switch_items = {"Show All", "Show without Shortcuts", "Show with Shortcuts"},
  show_script_filter_in_dialog = true,
  empty_status_message = "No Renoise keybindings found.",
})

-- Function to replace XML encoded entities with their corresponding characters
local function decodeXMLString(value)
  local replacements = {
    ["&amp;"] = "&",
    -- Add more replacements if needed
  }
  return value:gsub("(&amp;)", replacements)
end

-- Pre-compute derived fields and caches for a keybindings array
local function precomputeBindingCaches(keybindings)
  local max_length = 0
  local by_identifier = {}
  local total_count = #keybindings
  local unassigned_count = 0

  for _, binding in ipairs(keybindings) do
    -- Pre-split topic words for sort comparator
    local parts = {}
    for part in binding.Topic:gmatch("%S+") do
      parts[#parts + 1] = part
    end
    binding._topic_parts = parts

    -- Pre-compute readable key and script-related fields
    binding._readable_key = convert_key_name(binding.Key)
    binding._is_script = binding.Binding:find("∿") ~= nil
    binding._length_adjustment = binding._is_script and 2 or 0

    -- Accumulate max_length
    local length = #(string.format("%04d", 0) .. ":" .. binding.Identifier .. ":" .. binding.Topic .. ": " .. binding.Binding) - binding._length_adjustment
    if length > max_length then max_length = length end

    -- Build by-identifier index
    local id = binding.Identifier
    if not by_identifier[id] then
      by_identifier[id] = {}
    end
    by_identifier[id][#by_identifier[id] + 1] = binding

    -- Count unassigned
    if binding.Key == "<Shortcut not Assigned>" then
      unassigned_count = unassigned_count + 1
    end
  end

  return max_length, by_identifier, total_count, unassigned_count
end

-- Fast keybinding search using pre-computed _lower fields and plain string.find
local function fastSearchKeybindings(keybindings, search_query)
  if not keybindings or #keybindings == 0 then return {} end
  if not search_query or search_query == "" then return keybindings end

  -- Split query words ONCE
  local words = {}
  for word in search_query:gmatch("%S+") do
    words[#words + 1] = word
  end
  if #words == 0 then return keybindings end

  local results = {}
  for _, binding in ipairs(keybindings) do
    local matched = true
    for _, word in ipairs(words) do
      -- Check all four pre-computed lowercase fields with plain find
      if not (string.find(binding._topic_lower, word, 1, true)
           or string.find(binding._binding_lower, word, 1, true)
           or string.find(binding._identifier_lower, word, 1, true)
           or string.find(binding._key_lower, word, 1, true)) then
        matched = false
        break
      end
    end
    if matched then
      results[#results + 1] = binding
    end
  end
  return results
end

-- Shared function to update search display text
local function updateSearchDisplay(state)
  if state.search_display_text then
    state.search_display_text.text = "'" .. state.current_search_text .. "'"
  end
end

-- Combined function to parse XML and find keybindings based on filter type
-- Returns keybindings table and debug log string
function parseKeyBindingsXML(filePath, filter_type)
  local parse_log = ""
  local fileHandle = io.open(filePath, "r")
  if not fileHandle then
    parse_log = parse_log .. "Debug: Failed to open the file - " .. filePath .. "\n"
    return {}, parse_log
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

        table.insert(keybindings, {
          Identifier = currentIdentifier, Topic = topic, Binding = binding, Key = key,
          _identifier_lower = currentIdentifier:lower(),
          _topic_lower = topic:lower(),
          _binding_lower = binding:lower(),
          _key_lower = key:lower()
        })

        parse_log = parse_log .. "Debug: Found " .. filter_type .. " keybinding - " .. currentIdentifier .. ":" .. topic .. ":" .. binding .. ":" .. key .. "\n"
      end
    end
  end

  return keybindings, parse_log
end

-- Shared function to save the debug log
local function saveDebugLog(state, filteredKeybindings, showUnassignedOnly)
  if not state.keybindings then return end

  local filePath = state.debug_log_path
  local fileHandle = io.open(filePath, "w")
  if fileHandle then
    local log_content = "Debug: Total " .. state.dialog_title_prefix .. " keybindings found - " .. #state.keybindings .. "\n"
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

-- Shared function to update the list view based on the filter
local function updateKeybindingsList(state)
  if not state.identifier_switch then return end

  local showUnassignedOnly = (state.show_shortcuts_switch.value == 2)
  local showAssignedOnly = (state.show_shortcuts_switch.value == 3)
  local scriptFilter = state.show_script_filter_switch.value
  local selectedIdentifier = state.identifier_switch.items[state.identifier_switch.value]
  local searchQuery = state.current_search_text:lower()
  local content = ""
  local selected_count = 0
  local selected_unassigned_count = 0

  local filteredKeybindings = {}

  -- Use pre-computed identifier index for O(1) lookup
  local selectedKeybindings = (selectedIdentifier == "All")
    and state.keybindings
    or (state.by_identifier[selectedIdentifier] or {})

  -- Apply fast search filtering
  local searchFilteredKeybindings = fastSearchKeybindings(selectedKeybindings, searchQuery)

  for _, binding in ipairs(searchFilteredKeybindings) do
    -- Use pre-computed _is_script
    local matchesScriptFilter = (scriptFilter == 1) or (scriptFilter == 2 and not binding._is_script) or (scriptFilter == 3 and binding._is_script)

    if matchesScriptFilter then
      if (showUnassignedOnly and binding.Key == "<Shortcut not Assigned>") or
         (showAssignedOnly and binding.Key ~= "<Shortcut not Assigned>") or
         (not showUnassignedOnly and not showAssignedOnly) then

        filteredKeybindings[#filteredKeybindings + 1] = binding

        if binding.Key == "<Shortcut not Assigned>" then
          selected_unassigned_count = selected_unassigned_count + 1
        end

        selected_count = selected_count + 1
      end
    end
  end

  sortKeybindings(filteredKeybindings)

  if #filteredKeybindings == 0 then
    content = "No KeyBindings available for this filter."
  else
    -- Use pre-computed max_length
    local max_length = state.max_length + 35

    -- Build content with table.concat for O(n) instead of O(n^2) string concatenation
    local content_parts = {}
    for index, binding in ipairs(filteredKeybindings) do
      local entry = string.format("%04d", index)
        .. string.rep(" ", padding_number_identifier) .. binding.Identifier
        .. string.rep(" ", padding_identifier_topic - #binding.Identifier)
        .. binding.Topic
        .. string.rep(" ", padding_topic_binding - #binding.Topic)
        .. binding.Binding

      -- Use pre-computed _length_adjustment and _readable_key
      local padded_entry = entry .. string.rep(" ", max_length - #entry + binding._length_adjustment) .. " " .. binding._readable_key
      content_parts[#content_parts + 1] = padded_entry
    end
    content = table.concat(content_parts, "\n")
  end

  state.keybinding_list.text = content

  local selectedText=""
  if selectedIdentifier == "All" then
    selectedText="For all sections, there are " .. selected_count .. " shortcuts and " .. selected_unassigned_count .. " are unassigned."
  else
    selectedText="For " .. selectedIdentifier .. ", there are " .. selected_count .. " shortcuts and " .. selected_unassigned_count .. " are unassigned."
  end

  state.selected_shortcuts_text.text = selectedText
  -- Use pre-computed totals
  state.total_shortcuts_text.text="Total: " .. state.total_count .. " shortcuts, " .. state.unassigned_count .. " unassigned."

  if not state.suppress_debug_log then
    saveDebugLog(state, filteredKeybindings, showUnassignedOnly)
  end
end

-- Factory for key handler closure
local function createKeyHandler(state)
  return function(dlg, key)
    local closer = preferences.pakettiDialogClose.value
    if key.modifiers == "" and key.name == closer then
      dlg:close()
      return nil
    elseif key.name == "esc" then
      state.current_search_text = ""
      updateSearchDisplay(state)
      updateKeybindingsList(state)
      return nil
    elseif key.name == "back" then
      if #state.current_search_text > 0 then
        state.current_search_text = state.current_search_text:sub(1, #state.current_search_text - 1)
        updateSearchDisplay(state)
        updateKeybindingsList(state)
      end
      return nil
    elseif key.name == "delete" then
      state.current_search_text = ""
      updateSearchDisplay(state)
      updateKeybindingsList(state)
      return nil
    elseif key.name == "space" then
      state.current_search_text = state.current_search_text .. " "
      updateSearchDisplay(state)
      updateKeybindingsList(state)
      return nil
    elseif string.len(key.name) == 1 then
      -- Ignore the '<' character altogether
      if key.name ~= "<" then
        state.current_search_text = state.current_search_text .. key.name
        updateSearchDisplay(state)
        updateKeybindingsList(state)
      end
      return nil
    else
      -- Let other keys pass through
      return key
    end
  end
end

-- Shared function to display a keybindings dialog
local function showKeybindingsDialog(state, selectedIdentifier)
  -- Check if the dialog is already visible and close it
  if state.dialog_ref and state.dialog_ref.visible then
    state.dialog_ref:close()
    return
  end

  -- Reset search state
  state.current_search_text = ""

  -- Map menu identifiers to their internal names
  if selectedIdentifier then
    selectedIdentifier = menu_to_identifier[selectedIdentifier] or selectedIdentifier
  end

  local keyBindingsPath = detectOSAndGetKeyBindingsPath()
  if not keyBindingsPath then
    renoise.app():show_status("Failed to detect OS and find KeyBindings.xml path.")
    return
  end

  state.debug_log = state.debug_log .. "Debug: Using KeyBindings path - " .. keyBindingsPath .. "\n"
  local keybindings, parse_log = parseKeyBindingsXML(keyBindingsPath, state.filter_type)
  state.keybindings = keybindings
  state.debug_log = state.debug_log .. parse_log

  if not state.keybindings or #state.keybindings == 0 then
    renoise.app():show_status(state.empty_status_message)
    state.debug_log = state.debug_log .. "Debug: Total " .. state.dialog_title_prefix .. " keybindings found - 0\n"
    saveDebugLog(state, state.keybindings, false)
    return
  end

  -- Print total found count at the start
  state.debug_log = "Debug: Total " .. state.dialog_title_prefix .. " keybindings found - " .. #state.keybindings .. "\n" .. state.debug_log

  -- Pre-compute caches for fast search/sort/display
  state.max_length, state.by_identifier, state.total_count, state.unassigned_count = precomputeBindingCaches(state.keybindings)

  -- Collect all unique Identifiers from the by_identifier index
  local identifier_items = { "All" }
  for id, _ in pairs(state.by_identifier) do
    identifier_items[#identifier_items + 1] = id
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

  state.identifier_switch = vb:popup{
    items = identifier_items,
    width=300,
    value = selected_index,
    notifier = function() updateKeybindingsList(state) end
  }

  -- Create the switch for showing/hiding shortcuts
  state.show_shortcuts_switch = vb:switch {
    items = state.shortcuts_switch_items,
    width=1100,
    value = 1, -- Default to "Show All"
    notifier = function() updateKeybindingsList(state) end
  }

  state.show_script_filter_switch = vb:switch {
    items = { "All", "Show without Tools", "Show Only Tools" },
    width=1100,
    value = 1,
    notifier=function(value)
      updateKeybindingsList(state)
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
  state.search_display_text = vb:text{
    width=300,
    text="'" .. state.current_search_text .. "'",
    style = "strong"
  }

  state.total_shortcuts_text = vb:text{
    text="Total: 0 shortcuts, 0 unassigned",
    font = "bold",
    width=1100,
    align="left"
  }

  state.selected_shortcuts_text = vb:text{
    text="For selected sections, there are 0 shortcuts and 0 are unassigned.",
    font = "bold",
    width=1100,
    align="left"
  }

  state.keybinding_list = vb:multiline_textfield { width=1100, height = 600, font = "mono" }

  -- Dialog title including Renoise version
  local dialog_title = state.dialog_title_prefix .. " KeyBindings for Renoise Version " .. renoise.RENOISE_VERSION

  -- Build column with conditional script filter switch placement
  local column = vb:column{ margin=10 }
  column:add_child(vb:text{
    text="NOTE: KeyBindings.xml is only saved when Renoise is closed - so this is not a realtime / updatable Dialog. Make changes, quit Renoise, and relaunch this Dialog.",
    font = "bold"
  })
  column:add_child(state.identifier_switch)
  if state.show_script_filter_in_dialog then
    column:add_child(state.show_script_filter_switch)
  end
  column:add_child(state.show_shortcuts_switch)
  column:add_child(vb:row{vb:button{text="Save as Textfile", notifier=function()
    local filename = renoise.app():prompt_for_filename_to_write("*.txt", "Available Plugins Saver")
    if filename then
      local file, err = io.open(filename, "w")
      if file then
        file:write(state.keybinding_list.text)
        file:close()
        renoise.app():show_status("File saved successfully")
      else
        renoise.app():show_status("Error saving file: " .. err)
      end
    end
  end}})
  column:add_child(vb:row{
    vb:text{
      text = "Type to search:",
      width = 100,
      font="bold",
      style="strong"
    },
    state.search_display_text
  })
  column:add_child(state.keybinding_list)
  column:add_child(state.selected_shortcuts_text)
  column:add_child(state.total_shortcuts_text)

  state.dialog_ref = renoise.app():show_custom_dialog(dialog_title, column, createKeyHandler(state))

  -- Initial list update
  updateKeybindingsList(state)

  -- Set focus to Renoise after dialog opens for key capture
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame

  -- Print total found count at the end
  state.debug_log = state.debug_log .. "Debug: Total " .. state.dialog_title_prefix .. " keybindings found - " .. #state.keybindings .. "\n"
  saveDebugLog(state, state.keybindings, false)
end

-- Public API wrappers (unchanged signatures)
function pakettiKeyBindingsDialog(selectedIdentifier)
  showKeybindingsDialog(paketti_state, selectedIdentifier)
end

function pakettiRenoiseKeyBindingsDialog(selectedIdentifier)
  showKeybindingsDialog(renoise_state, selectedIdentifier)
end

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

  renoise.tool():add_menu_entry{name="--" .. menu_name .. ":Paketti Gadgets:Paketti KeyBindings Dialog...",invoke=function() pakettiKeyBindingsDialog(identifier) end}
  renoise.tool():add_menu_entry{name=menu_name .. ":Paketti Gadgets:Renoise KeyBindings Dialog...",invoke=function() pakettiRenoiseKeyBindingsDialog(identifier) end}
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

-- Global dialog reference for toggle behavior
local dialog = nil

-- Function to show the free keybindings dialog
function pakettiFreeKeybindingsDialog()
  -- Check if dialog is already open and close it
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
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
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Free Keybindings Finder", dialog_content, keyhandler)

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
