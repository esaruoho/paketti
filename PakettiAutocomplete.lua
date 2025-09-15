-- PakettiAutocomplete.lua
-- Autocomplete dialog system with real-time filtering and selection

-- Dialog width configuration
local DIALOG_WIDTH = 690
local SCROLLBAR_WIDTH = 20
local BUTTON_WIDTH = DIALOG_WIDTH - SCROLLBAR_WIDTH
local SEARCH_LABEL_WIDTH = 80
local SEARCH_FIELD_WIDTH = DIALOG_WIDTH - SEARCH_LABEL_WIDTH

-- Dialog and UI state variables
local autocomplete_dialog = nil
local autocomplete_vb = nil
local suggestion_buttons = {}
local search_display_text = nil
local status_text = nil
local current_filter = ""
local current_filtered_commands = {}
local selected_suggestion_index = 0
local create_abbrev_button = nil
local command_picker_dialog = nil
local suggestions_scrollbar = nil
local prev_page_button = nil
local next_page_button = nil
local show_only_with_shortcuts_checkbox = nil

-- Scrolling variables
local MAX_VISIBLE_BUTTONS = 40
local current_scroll_offset = 0

-- Real Paketti commands (dynamically loaded)
local paketti_commands = {}
local command_descriptions = {}
local user_abbreviations = {}

-- Performance optimization variables
local commands_cache = {}
local search_index = {}
local recent_commands = {}
local favorite_commands = {}
local command_usage_count = {}
local last_scan_time = 0
local current_context = "global"  -- global, pattern_editor, sample_editor, mixer, etc.

-- Shortcut mapping cache
local function_shortcut_mappings = {}
local shortcut_cache_file_path = renoise.tool().bundle_path .. "autocomplete_shortcuts.txt"

-- Autocomplete state (CP-style)
local current_search_text = ""

-- Cache file paths
local cache_file_path = renoise.tool().bundle_path .. "autocomplete_cache.txt"
local usage_file_path = renoise.tool().bundle_path .. "autocomplete_usage.txt"
local favorites_file_path = renoise.tool().bundle_path .. "autocomplete_favorites.txt"

-- Helper functions for KeyBindings.xml parsing (borrowed from PakettiKeyBindings.lua)
local function detectOSAndGetKeyBindingsPath()
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

local function decodeXMLString(value)
  local replacements = {
    ["&amp;"] = "&",
    -- Add more replacements if needed
  }
  return value:gsub("(&amp;)", replacements)
end

local function convert_key_name(key)
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
    -- Shorten modifier keys for cleaner display
    elseif part == "Command" then part = "CMD"
    elseif part == "Control" then part = "CTRL"
    elseif part == "Option" then part = "OPT"
    end
    table.insert(parts, part)
  end
  return table.concat(parts, " + ")
end

local function parseKeyBindingsXML(filePath, filter_type)
  local fileHandle = io.open(filePath, "r")
  if not fileHandle then
    print("Debug: Failed to open the file - " .. filePath)
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
      end
    end
  end

  return keybindings
end

-- Function to build function-shortcut mappings from KeyBindings.xml
local function build_function_shortcut_mappings()
  function_shortcut_mappings = {}
  shortcut_lookup_cache = {} -- Clear lookup cache when rebuilding mappings
  
  local keyBindingsPath = detectOSAndGetKeyBindingsPath()
  if not keyBindingsPath then
    print("PakettiAutocomplete: Could not detect KeyBindings.xml path for shortcut mapping")
    return
  end
  
  print("PakettiAutocomplete: Building function-shortcut mappings from " .. keyBindingsPath)
  
  -- Parse both Paketti and Renoise keybindings
  local pakettiBindings = parseKeyBindingsXML(keyBindingsPath, "paketti")
  local renoiseBindings = parseKeyBindingsXML(keyBindingsPath, "renoise")
  
  local mappings_added = 0
  
  -- Add Paketti bindings using Binding as the key (this is the actual function name!)
  for _, binding in ipairs(pakettiBindings) do
    if binding.Key and binding.Key ~= "<Shortcut not Assigned>" and binding.Binding then
      local binding_name = binding.Binding
      local readableKey = convert_key_name(binding.Key)
      
      -- Strip the "∿ " prefix from Binding
      -- Binding: "∿ Impulse Tracker F2 Pattern Editor" -> "Impulse Tracker F2 Pattern Editor"
      local function_name = binding_name:match("^∿ (.+)") or binding_name
      
      -- Add "Paketti:" prefix to match autocomplete format
      local autocomplete_name = "Paketti:" .. function_name
      
      -- Debug first few bindings
      if mappings_added < 5 then
        print("DEBUG: Paketti binding " .. (mappings_added + 1) .. ":")
        print("  Original Binding: " .. binding_name)
        print("  Function name: " .. function_name)
        print("  Autocomplete name: " .. autocomplete_name)
        print("  Key: " .. (binding.Key or "nil"))
        print("  Storing as: '" .. autocomplete_name .. "' -> '" .. readableKey .. "'")
      end
      
      -- Store the mapping using autocomplete format as key
      function_shortcut_mappings[autocomplete_name] = readableKey
      mappings_added = mappings_added + 1
    end
  end
  
  -- Add Renoise bindings using Binding as the key (this is the actual function name!)
  for _, binding in ipairs(renoiseBindings) do
    if binding.Key and binding.Key ~= "<Shortcut not Assigned>" and binding.Binding then
      local binding_name = binding.Binding
      local readableKey = convert_key_name(binding.Key)
      
      -- For Renoise bindings, use the Binding directly (no ∿ prefix to strip)
      local function_name = binding_name
      
      -- Debug first few bindings
      if mappings_added < 10 then
        print("DEBUG: Renoise binding " .. (mappings_added + 1) .. ":")
        print("  Binding: " .. binding_name)
        print("  Key: " .. (binding.Key or "nil"))
        print("  Storing as: '" .. function_name .. "' -> '" .. readableKey .. "'")
      end
      
      -- Store the mapping using Binding as key
      function_shortcut_mappings[function_name] = readableKey
      mappings_added = mappings_added + 1
    end
  end
  
  print("PakettiAutocomplete: Built " .. mappings_added .. " function-shortcut mappings")
end

-- Function to save shortcut mappings to cache
local function save_shortcut_mappings()
  -- Count before saving
  local count_before = 0
  for _ in pairs(function_shortcut_mappings) do
    count_before = count_before + 1
  end
  print("DEBUG: About to save " .. count_before .. " mappings")
  
  local file = io.open(shortcut_cache_file_path, "w")
  if file then
    file:write("SHORTCUT_CACHE_VERSION=1.0\n")
    local written_count = 0
    local error_count = 0
    
    for functionName, shortcut in pairs(function_shortcut_mappings) do
      -- Check for problematic characters that might cause write issues
      if functionName and shortcut and functionName ~= "" and shortcut ~= "" then
        -- Use ||| delimiter to avoid conflicts (same as main cache)
        local line = functionName .. "|||" .. shortcut .. "\n"
        local success, err = pcall(function() file:write(line) end)
        
        if success then
          written_count = written_count + 1
          -- Debug first few writes
          if written_count <= 3 then
            print("DEBUG: Writing mapping " .. written_count .. ": " .. functionName .. " -> " .. shortcut)
          end
        else
          error_count = error_count + 1
          if error_count <= 3 then
            print("DEBUG: Error writing mapping: " .. (err or "unknown error"))
          end
        end
      else
        error_count = error_count + 1
        if error_count <= 3 then
          print("DEBUG: Skipping invalid mapping: '" .. tostring(functionName) .. "' -> '" .. tostring(shortcut) .. "'")
        end
      end
    end
    file:close()
    print("PakettiAutocomplete: Saved " .. written_count .. " shortcut mappings to cache (" .. error_count .. " errors)")
  else
    print("PakettiAutocomplete: Failed to save shortcut mappings to cache")
  end
end

-- Function to load shortcut mappings from cache
local function load_shortcut_mappings()
  local file = io.open(shortcut_cache_file_path, "r")
  if not file then 
    print("PakettiAutocomplete: No shortcut cache file found")
    return false 
  end
  
  function_shortcut_mappings = {}
  shortcut_lookup_cache = {} -- Clear lookup cache when loading new mappings
  local version = file:read("*line")
  
  if not version or not version:match("SHORTCUT_CACHE_VERSION=1%.0") then
    file:close()
    print("PakettiAutocomplete: Invalid shortcut cache version")
    return false
  end
  
  local count = 0
  for line in file:lines() do
    local pos = string.find(line, "|||")
    if pos then
      local functionName = string.sub(line, 1, pos - 1)
      local shortcut = string.sub(line, pos + 3)
      function_shortcut_mappings[functionName] = shortcut
      count = count + 1
    end
  end
  file:close()
  
  print("PakettiAutocomplete: Loaded " .. count .. " shortcut mappings from cache")
  return true
end

-- Performance cache for shortcut lookups
local shortcut_lookup_cache = {}

-- Function to get shortcut for a command (OPTIMIZED - no loops!)
local function get_command_shortcut(command)
  if not command or not command.name then 
    return "" 
  end
  
  local command_name = command.name
  
  -- Check cache first for instant lookup
  if shortcut_lookup_cache[command_name] ~= nil then
    return shortcut_lookup_cache[command_name]
  end
  
  local result = ""
  
  -- Direct O(1) lookup: check if the command name matches any mapping
  local shortcut = function_shortcut_mappings[command_name]
  if shortcut then
    result = " [" .. shortcut .. "]"
  else
    -- Try without prefix (remove "Paketti:" or other prefixes)
    local command_without_prefix = command_name:match("^[^:]+:(.+)") or command_name
    if command_without_prefix ~= command_name then
      local shortcut_without_prefix = function_shortcut_mappings[command_without_prefix]
      if shortcut_without_prefix then
        result = " [" .. shortcut_without_prefix .. "]"
      end
    end
  end
  
  -- Cache the result for future lookups
  shortcut_lookup_cache[command_name] = result
  return result
end

-- Dynamic file scanning using main.lua helper - finds ALL .lua files in Paketti tool
local function get_all_paketti_files()
  -- Use the global helper function from main.lua for consistent file discovery
  local files = PakettiGetAllLuaFiles()
  
  -- If the helper function returns nothing, fall back to hardcoded list
  if #files == 0 then
    print("PakettiAutocomplete: Helper function returned no files, using fallback list")
    files = {
       "Paketti0G01_Loader", "PakettieSpeak", "PakettiPlayerProSuite", "PakettiChordsPlus",
       "PakettiLaunchApp", "PakettiSampleLoader", "PakettiCustomization", "PakettiDeviceChains",
       "base64float", "PakettiLoadDevices", "PakettiSandbox", "PakettiTupletGenerator",
       "PakettiLoadPlugins", "PakettiPatternSequencer", "PakettiPatternMatrix", "PakettiInstrumentBox",
       "PakettiYTDLP", "PakettiStretch", "PakettiBeatDetect", "PakettiStacker", "PakettiRecorder",
       "PakettiControls", "PakettiKeyBindings", "PakettiPhraseEditor", "PakettiOctaMEDSuite",
       "PakettiWavetabler", "PakettiAudioProcessing", "PakettiPatternEditorCheatSheet", "PakettiThemeSelector",
       "PakettiMidiPopulator", "PakettiImpulseTracker", "PakettiGater", "PakettiAutomation",
       "PakettiUnisonGenerator", "PakettiMainMenuEntries", "PakettiMidi", "PakettiDynamicViews",
       "PakettiEightOneTwenty", "PakettiExperimental_Verify", "PakettiLoaders", "PakettiPatternEditor",
       "PakettiTkna", "PakettiRequests", "PakettiSamples", "Paketti35", "PakettiAutocomplete", "PakettiMenuConfig",
       "Research/FormulaDeviceManual", "hotelsinus_stepseq/hotelsinus_stepseq", "Sononymph/AppMain"
     }
  end
  
  print(string.format("PakettiAutocomplete: Using %d .lua files for scanning", #files))
  return files
end

-- Function to scan preferences.xml for dynamic plugin/device loaders
local function scan_preferences_xml()
  local prefs_path = renoise.tool().bundle_path .. "preferences.xml"
  local file = io.open(prefs_path, "r")
  if not file then
    print("PakettiAutocomplete: preferences.xml not found")
    return {}
  end
  
  local content = file:read("*all")
  file:close()
  
  local dynamic_commands = {}
  local plugin_count = 0
  local device_count = 0
  
  -- Extract PakettiPluginLoaders
  for plugin_block in content:gmatch("<PakettiPluginLoader.-</PakettiPluginLoader>") do
    local path = plugin_block:match("<path>(.-)</path>")
    local name = plugin_block:match("<name>(.-)</name>")
    if path and name then
      plugin_count = plugin_count + 1
      table.insert(dynamic_commands, {
        type = "Dynamic Plugin Loader",
        name = "Load Plugin " .. name,
        category = "Dynamic Plugin Loaders",
        invoke = string.format("loadPlugin('%s')", path),
        abbreviations = {"plugin", "load", name:lower()},
        source_file = "preferences.xml"
      })
    end
  end
  
  -- Extract PakettiDeviceLoaders  
  for device_block in content:gmatch("<PakettiDeviceLoader.-</PakettiDeviceLoader>") do
    local path = device_block:match("<path>(.-)</path>")
    local name = device_block:match("<name>(.-)</name>")
    local device_type = device_block:match("<device_type>(.-)</device_type>")
    if path and name then
      device_count = device_count + 1
      local display_name = device_type and (name .. " (" .. device_type .. ")") or name
      table.insert(dynamic_commands, {
        type = "Dynamic Device Loader",
        name = "Load Device " .. display_name,
        category = "Dynamic Device Loaders", 
        invoke = string.format("pakettiLoadDevice('%s')", path),
        abbreviations = {"device", "load", name:lower()},
        source_file = "preferences.xml"
      })
    end
  end
  
  print(string.format("PakettiAutocomplete: Found %d dynamic plugin loaders, %d dynamic device loaders", 
    plugin_count, device_count))
  return dynamic_commands
end

-- Function to scan Paketti files for real commands (now uses dynamic file discovery)
local function scan_paketti_commands()
  paketti_commands = {}
  
  -- Get ALL .lua files dynamically
  local paketti_files = get_all_paketti_files()
  
  -- Helper function to extract category from menu path
  local function extract_category(menu_path)
    -- Remove -- prefix first
    local clean_path = menu_path:gsub("^%-%-%s*", "")
    
    -- Extract category from menu paths like "Main Menu:Tools:Paketti:Sample:..." or "Mixer:Paketti:..."
    local category = clean_path:match("Paketti:([^:]+):") or clean_path:match("([^:]+):Paketti") or clean_path:match("([^:]+)") or "General"
    
    -- Clean up the category (remove any remaining -- or extra spaces)
    category = category:gsub("^%-%-%s*", ""):gsub("^%s*", ""):gsub("%s*$", "")
    
    return category
  end
  
  -- Helper function to generate abbreviations
  local function generate_abbreviations(name)
    local abbrevs = {}
    
    -- Simple acronym (first letters)
    local acronym = ""
    for word in name:gmatch("%w+") do
      acronym = acronym .. word:sub(1,1):upper()
    end
    if #acronym > 1 then
      table.insert(abbrevs, acronym)
    end
    
    -- Number extraction (like "+36", "-12")
    for number in name:gmatch("[+-]%d+") do
      table.insert(abbrevs, number)
    end
    
    -- Key words
    for word in name:gmatch("%w+") do
      if #word > 3 then -- Only meaningful words
        table.insert(abbrevs, word:lower())
      end
    end
    
    return abbrevs
  end
  
  local files_scanned = 0
  local files_with_commands = 0
  
  -- Scan each Paketti file
  for _, filename in ipairs(paketti_files) do
    local full_path = renoise.tool().bundle_path .. filename .. ".lua"
    local file = io.open(full_path, "r")
    if file then
      files_scanned = files_scanned + 1
      local content = file:read("*all")
      file:close()
      
      local commands_in_file = 0
      
      -- Extract menu entries (use same pattern as PakettiActionSelector)
      for entry, invoke_func in content:gmatch('add_menu_entry%s*{%s*name%s*=%s*"([^"]+)"%s*,%s*invoke%s*=%s*([^}]-)}') do
        local clean_name = entry:gsub("^%-%-%s*", "")
        local category = extract_category(entry)
        local abbreviations = generate_abbreviations(clean_name)
        local cleaned_invoke = invoke_func:match("^%s*(.-)%s*$")
        

        
        table.insert(paketti_commands, {
          type = "Menu Entry",
          name = clean_name,
          category = category,
          invoke = cleaned_invoke,
          abbreviations = abbreviations,
          source_file = filename
        })
        

        
        commands_in_file = commands_in_file + 1
      end
      
      -- Extract keybindings
      for binding, invoke_func in content:gmatch('add_keybinding%s*{%s*name%s*=%s*"([^"]+)"%s*,%s*invoke%s*=%s*([^}]-)}') do
        local clean_name = binding:gsub("^%-%-%s*", "")
        local category = extract_category(binding)
        local abbreviations = generate_abbreviations(clean_name)
        
        table.insert(paketti_commands, {
          type = "Keybinding", 
          name = clean_name,
          category = category,
          invoke = invoke_func:match("^%s*(.-)%s*$"),
          abbreviations = abbreviations,
          source_file = filename
        })
        commands_in_file = commands_in_file + 1
      end
      
      -- Extract MIDI mappings too
      for mapping, invoke_func in content:gmatch('add_midi_mapping%s*{%s*name%s*=%s*"([^"]+)"%s*,%s*invoke%s*=%s*([^}]-)}') do
        local clean_name = mapping:gsub("^%-%-%s*", "")
        local category = extract_category(mapping)
        local abbreviations = generate_abbreviations(clean_name)
        
        table.insert(paketti_commands, {
          type = "MIDI Mapping",
          name = clean_name,
          category = category,
          invoke = invoke_func:match("^%s*(.-)%s*$"),
          abbreviations = abbreviations,
          source_file = filename
        })
        commands_in_file = commands_in_file + 1
      end
      
      if commands_in_file > 0 then
        files_with_commands = files_with_commands + 1
      end
    else
      print("PakettiAutocomplete: Could not open file: " .. full_path)
    end
  end
  
  -- Sort commands: Menu Entries first, then Keybindings, then MIDI, alphabetically within each type
  table.sort(paketti_commands, function(a,b) 
    if a.type ~= b.type then
      if a.type == "Menu Entry" then return true end
      if b.type == "Menu Entry" then return false end
      if a.type == "Keybinding" then return true end
      if b.type == "Keybinding" then return false end
      return a.type < b.type
    else
      return a.name < b.name 
    end
  end)
  
  -- Add dynamic commands from preferences.xml
  local dynamic_commands = scan_preferences_xml()
  for _, command in ipairs(dynamic_commands) do
    table.insert(paketti_commands, command)
  end
  
  -- Set scan timestamp
  last_scan_time = os.time()
  
  print(string.format("PakettiAutocomplete: Scanned %d files (%d with commands), loaded %d Lua commands + %d dynamic commands = %d total", 
    files_scanned, files_with_commands, #paketti_commands - #dynamic_commands, #dynamic_commands, #paketti_commands))
end

-- Forward declarations for functions used before they're defined
local update_suggestions
local calculate_command_score
local get_smart_ordered_commands
local is_context_relevant
local score_flip_and_reverse

-- Helper function to get display category (show [MIDI] for MIDI mappings)
local function get_display_category(command)
  if command.type == "MIDI Mapping" then
    return "MIDI"
  else
    return command.category
  end
end

-- Helper function to escape special pattern characters for safe pattern matching
local function escape_pattern(str)
  return str:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
end

-- Helper function to clean up redundant category prefixes from command names
local function get_clean_command_name(command)
  local name = command.name
  local category = command.category
  
  -- Remove "Main Menu:Tools:Paketti:" prefix first
  local cleaned_name = name:gsub("^Main Menu:Tools:Paketti:", "")
  
  -- Remove redundant category prefix (e.g., "Sample Editor:Paketti Gadgets:..." -> "Paketti Gadgets:...")
  local pattern = "^" .. category:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1") .. ":(.+)$"
  local cleaned = cleaned_name:match(pattern)
  
  if cleaned then
    return cleaned
  else
    return cleaned_name  -- Return name with Main Menu prefix removed
  end
end

-- Helper function to extract just the dialog name from gadget commands
local function get_gadget_dialog_name(command)
  local name = command.name
  
  -- Look for "Paketti Gadgets:" anywhere in the command name and extract what comes after
  local gadget_name = name:match("Paketti Gadgets:(.+)$")
  if gadget_name then
    return gadget_name
  end
  
  -- Fallback to cleaned name if no gadgets pattern found
  return get_clean_command_name(command)
end

-- Helper function to check if current search is gadgets-related
local function is_gadgets_search()
  local search_lower = current_search_text:lower()
  return search_lower:find("gadget") or search_lower:find("gad") or search_lower == "g"
end

-- Helper function to detect and fix doubled first letters (e.g., "eexpose" -> "expose")
local function detect_doubled_first_letter(text)
  if not text or #text < 2 then
    return nil
  end
  
  -- Check if first two characters are the same letter
  local first_char = text:sub(1, 1):lower()
  local second_char = text:sub(2, 2):lower()
  
  if first_char == second_char and first_char:match("[a-z]") then
    -- Return the corrected version without the doubled first letter
    return text:sub(2)
  end
  
  return nil
end

-- Test function for doubled letter detection (can be called from console for testing)
function test_doubled_letter_detection()
  local test_cases = {
    {"eexpose", "expose"},
    {"ssample", "sample"},
    {"ttranspose", "transpose"},
    {"expose", nil},  -- no doubled letter
    {"12", nil},      -- numbers
    {"e", nil},       -- too short
    {"", nil}         -- empty
  }
  
  print("Testing doubled letter detection:")
  for _, case in ipairs(test_cases) do
    local input, expected = case[1], case[2]
    local result = detect_doubled_first_letter(input)
    local status = (result == expected) and "PASS" or "FAIL"
    print(string.format("  %s: '%s' -> %s (expected %s)", status, input, tostring(result), tostring(expected)))
  end
end

-- CP-style: No autocomplete fill, just real-time filtering

-- Smart command grouping and numeric pattern detection
local function detect_numeric_pattern(search_text)
  -- Detect patterns like "+36", "-12", "36", etc.
  local sign, number = search_text:match("^([%+%-]?)(%d+)$")
  if number then
    local num = tonumber(number)
    if num then
      -- Return both original search and related patterns, but mark the original
      local result = {
        original = search_text,
        related = {}
      }
      
      -- Generate related numbers (common transpose values)
      local values = {12, 24, 36, 48}
      for _, val in ipairs(values) do
        if val ~= num then -- Don't duplicate the original number
          table.insert(result.related, "+" .. val)
          table.insert(result.related, "-" .. val)
          if sign == "" then -- If original had no sign, include unsigned version
            table.insert(result.related, tostring(val))
          end
        end
      end
      
      return result
    end
  end
  return nil
end

-- Group similar commands by base function name with context-aware representative selection
local function group_similar_commands(commands)
  local groups = {}
  local group_representatives = {} -- Store best representative for each group
  
  for _, command in ipairs(commands) do
    -- Extract base pattern (remove numeric values and category prefixes)
    local base_name = command.name
    -- Remove category prefixes like "Global:Paketti:", "Sample Navigator:Paketti:", etc.
    base_name = base_name:gsub("^[^:]+:Paketti:", "")
    -- Replace numeric patterns with placeholder
    base_name = base_name:gsub("[%+%-]?%d+", "X")
    
    if not groups[base_name] then
      groups[base_name] = {}
      group_representatives[base_name] = command -- First command becomes representative
    else
      -- Smart representative selection: prefer context-relevant, then Global
      local current_rep = group_representatives[base_name]
      local should_replace = false
      
      -- Priority 1: Context-relevant commands first
      local command_context_relevant = is_context_relevant(command)
      local current_context_relevant = is_context_relevant(current_rep)
      
      if command_context_relevant and not current_context_relevant then
        should_replace = true
        print("Replacing with context-relevant command: " .. command.name .. " over " .. current_rep.name)
      elseif not command_context_relevant and current_context_relevant then
        should_replace = false  -- Keep context-relevant
      else
        -- Priority 2: If both have same context relevance, prefer Global (works everywhere)
        if command.category == "Global" and current_rep.category ~= "Global" then
          should_replace = true
          print("Replacing with Global command: " .. command.name .. " over " .. current_rep.name)
        elseif command.category ~= "Global" and current_rep.category == "Global" then
          should_replace = false  -- Keep Global
        else
          -- Priority 3: Sample Editor in sample contexts (if both are equivalent)
          if current_context:find("sample") then
            if command.category:lower():find("sample editor") and not current_rep.category:lower():find("sample editor") then
              should_replace = true
            end
          end
        end
      end
      
      if should_replace then
        group_representatives[base_name] = command
        print("Updated representative for '" .. base_name .. "' from [" .. current_rep.category .. "] to [" .. command.category .. "] (context: " .. current_context .. ")")
      end
    end
    
    table.insert(groups[base_name], command)
  end
  
  return groups, group_representatives
end

-- "Flip it And Reverse It" scoring for numeric patterns (category-consistent)
function score_flip_and_reverse(command, numeric_info, exact_match_command, template_variants)
  local score = 0
  
  -- MASSIVE bonus for the exact match command
  if exact_match_command and command.name == exact_match_command.name then
    score = score + 10000  -- Highest priority for exact match
    -- print("Exact match bonus: " .. command.name .. " [" .. command.category .. "]")
    return score
  end
  
  -- LARGE bonus for template variants (same category as exact match)
  for _, variant in ipairs(template_variants) do
    if command.name == variant.name then
      score = score + 8000  -- Very high priority for template variants
      -- print("Template variant bonus: " .. command.name .. " [" .. command.category .. "]")
      return score
    end
  end
  
  -- Standard bonus for other numeric matches
  local name_lower = command.name:lower()
  for _, pattern in ipairs(numeric_info.related) do
    if string.find(name_lower, pattern:lower(), 1, true) then
      score = score + 500  -- Lower score for other numeric matches
      break
    end
  end
  
  return score
end

-- Optimized filtering with smart ranking, context awareness, and intelligent grouping
local function filter_commands(filter_text)
  print("filter_commands called with: '" .. (filter_text or "nil") .. "', context: " .. current_context)
  
  if not filter_text or filter_text == "" then
    -- Return context-filtered commands when no filter (not all commands)
    local result = get_smart_ordered_commands()
    print("Empty filter - returning " .. #result .. " context commands")
    return result
  end
  
  -- Get the base set of commands to search from
  local base_commands = paketti_commands  -- Always search all commands when typing
  
  local filtered = {}
  local filter_lower = string.lower(filter_text)
  local search_terms = {}
  
  -- Check for numeric pattern and expand search if found
  local numeric_info = detect_numeric_pattern(filter_text)
  if numeric_info then
    print("Detected numeric pattern for '" .. filter_text .. "', original: " .. numeric_info.original .. ", related: " .. table.concat(numeric_info.related, ", "))
    -- Start with original search term, then add related patterns
    search_terms = {numeric_info.original}
    for _, related in ipairs(numeric_info.related) do
      table.insert(search_terms, related)
    end
  else
    -- Split filter text into multiple terms for AND searching
    for term in filter_lower:gmatch("%S+") do
      table.insert(search_terms, term)
    end
  end
  
  -- Use search index for faster lookups, but only within base_commands
  local candidate_indices = {}
  
  if numeric_info then
    -- For numeric patterns, use OR logic to find all related transpose commands
    for _, term in ipairs(search_terms) do
      for i, command in ipairs(base_commands) do
        local name_lower = string.lower(command.name)
        local category_lower = string.lower(command.category)
        
        -- Direct name/category match
        if string.find(name_lower, term, 1, true) or string.find(category_lower, term, 1, true) then
          candidate_indices[i] = true
        else
          -- Try corrected version if original doesn't match (for doubled first letters)
          local corrected_term = detect_doubled_first_letter(term)
          if corrected_term then
            if string.find(name_lower, corrected_term, 1, true) or string.find(category_lower, corrected_term, 1, true) then
              candidate_indices[i] = true
            end
          end
        end
        
        -- Abbreviation match
        for _, abbrev in ipairs(command.abbreviations) do
          if string.find(abbrev:lower(), term, 1, true) then
            candidate_indices[i] = true
            break
          else
            -- Try corrected version for abbreviations too
            local corrected_term = detect_doubled_first_letter(term)
            if corrected_term and string.find(abbrev:lower(), corrected_term, 1, true) then
              candidate_indices[i] = true
              break
            end
          end
        end
      end
    end
  else
    -- Enhanced multi-word search with better AND logic
    print("DEBUG: Starting multi-word search for terms: [" .. table.concat(search_terms, ", ") .. "]")
    
    for term_idx, term in ipairs(search_terms) do
      local term_candidates = {}
      print("DEBUG: Processing term " .. term_idx .. ": '" .. term .. "'")
      
      -- Search within base_commands only
      for i, command in ipairs(base_commands) do
        local name_lower = string.lower(command.name)
        local category_lower = string.lower(command.category)
        local found_match = false
        
        -- Direct name/category match
        if string.find(name_lower, term, 1, true) then
          term_candidates[i] = true
          found_match = true
        elseif string.find(category_lower, term, 1, true) then
          term_candidates[i] = true
          found_match = true
        else
          -- Try corrected version if original doesn't match (for doubled first letters)
          local corrected_term = detect_doubled_first_letter(term)
          if corrected_term then
            if string.find(name_lower, corrected_term, 1, true) then
              term_candidates[i] = true
              found_match = true
            elseif string.find(category_lower, corrected_term, 1, true) then
              term_candidates[i] = true
              found_match = true
            end
          end
        end
        
        -- Abbreviation match (only if no direct match found)
        if not found_match then
          for _, abbrev in ipairs(command.abbreviations) do
            if string.find(abbrev:lower(), term, 1, true) then
              term_candidates[i] = true
              found_match = true
              break
            else
              -- Try corrected version for abbreviations too
              local corrected_term = detect_doubled_first_letter(term)
              if corrected_term and string.find(abbrev:lower(), corrected_term, 1, true) then
                term_candidates[i] = true
                found_match = true
                break
              end
            end
          end
        end
      end
      
      -- Check user abbreviations (exact match only to avoid duplicates)
      for abbrev, full_command in pairs(user_abbreviations) do
        if string.find(abbrev:lower(), term, 1, true) then
          for i, command in ipairs(base_commands) do
            if command.name:lower() == full_command:lower() then  -- Exact match only
              term_candidates[i] = true
            end
          end
        else
          -- Try corrected version for user abbreviations too
          local corrected_term = detect_doubled_first_letter(term)
          if corrected_term and string.find(abbrev:lower(), corrected_term, 1, true) then
            for i, command in ipairs(base_commands) do
              if command.name:lower() == full_command:lower() then  -- Exact match only
                term_candidates[i] = true
              end
            end
          end
        end
      end
      
      -- Count matches for this term and show some examples
      local term_match_count = 0
      local example_matches = {}
      for idx in pairs(term_candidates) do 
        term_match_count = term_match_count + 1
        if #example_matches < 3 then -- Show first 3 examples
          table.insert(example_matches, base_commands[idx].name)
        end
      end
      print("DEBUG: Term '" .. term .. "' matched " .. term_match_count .. " commands")
      if #example_matches > 0 then
        print("DEBUG: Examples: " .. table.concat(example_matches, " | "))
      end
      
      -- Apply intersection logic
      if term_idx == 1 then
        -- First term: use all matches as starting point
        candidate_indices = term_candidates
        print("DEBUG: First term - starting with " .. term_match_count .. " candidates")
      else
        -- Subsequent terms: intersect with previous results
        local intersection = {}
        local intersection_count = 0
        
        for idx in pairs(candidate_indices) do
          if term_candidates[idx] then
            intersection[idx] = true
            intersection_count = intersection_count + 1
          end
        end
        
        candidate_indices = intersection
        print("DEBUG: After intersection with term '" .. term .. "': " .. intersection_count .. " candidates remain")
        
        -- Show examples of what remains after intersection
        if intersection_count > 0 and intersection_count <= 5 then
          local remaining_examples = {}
          for idx in pairs(candidate_indices) do
            table.insert(remaining_examples, base_commands[idx].name)
          end
          print("DEBUG: Remaining after intersection: " .. table.concat(remaining_examples, " | "))
        end
        
        -- Early exit if no matches remain
        if intersection_count == 0 then
          print("DEBUG: No candidates remain after term '" .. term .. "' - breaking early")
          break
        end
      end
    end
    
    -- Final count
    local final_count = 0
    for _ in pairs(candidate_indices) do final_count = final_count + 1 end
    print("DEBUG: Final result: " .. final_count .. " commands match all terms")
  end
  
  -- Convert indices to commands and apply grouping logic
  local candidate_commands = {}
  for idx in pairs(candidate_indices) do
    local command = base_commands[idx]
    if command then
      table.insert(candidate_commands, command)
    end
  end
  
  -- Apply intelligent grouping and deduplication
  local groups, group_representatives = group_similar_commands(candidate_commands)
  
  -- For numeric patterns, implement "Flip it And Reverse It" logic
  local exact_match_command = nil
  local template_variants = {}
  
  if numeric_info then
    -- Step 1: Find the BEST exact match (prioritize Global, then context-relevant)
    local all_exact_matches = {}
    
    -- Collect all exact matches
    for _, command in ipairs(paketti_commands) do
      if string.find(command.name:lower(), numeric_info.original:lower(), 1, true) then
        table.insert(all_exact_matches, command)
        print("Found exact match candidate: " .. command.name .. " [" .. command.category .. "]")
      end
    end
    
    -- Choose the best exact match
    if #all_exact_matches > 0 then
      -- Priority 1: Global commands (work everywhere)
      for _, command in ipairs(all_exact_matches) do
        if command.category == "Global" then
          exact_match_command = command
          print("Selected GLOBAL exact match: " .. command.name)
          break
        end
      end
      
      -- Priority 2: Context-relevant commands
      if not exact_match_command then
        for _, command in ipairs(all_exact_matches) do
          if is_context_relevant(command) then
            exact_match_command = command
            print("Selected CONTEXT-RELEVANT exact match: " .. command.name .. " [" .. command.category .. "]")
            break
          end
        end
      end
      
      -- Priority 3: Any exact match
      if not exact_match_command then
        exact_match_command = all_exact_matches[1]
        print("Selected fallback exact match: " .. exact_match_command.name .. " [" .. exact_match_command.category .. "]")
      end
    end
    
    -- Step 2: INVERSE FUZZY SEARCH - Extract pattern around the number
    if exact_match_command then
      local exact_name = exact_match_command.name:lower()
      local target_category = exact_match_command.category
      
      -- Extract text BEFORE and AFTER the number for fuzzy matching
      -- Remove category prefix to make pattern more flexible
      local clean_name = exact_name:gsub("^[^:]+:paketti:", "paketti:")
      local before_pattern, number_part, after_pattern = clean_name:match("^(.-)([%+%-]?%d+)(.*)$")
      
      print("=== FLIP IT AND REVERSE IT DEBUG ===")
      print("Exact match: " .. exact_match_command.name)
      print("Lowercase name: " .. exact_name)
      print("Cleaned name: " .. clean_name)
      print("Before pattern: '" .. (before_pattern or "NIL") .. "'")
      print("Number part: '" .. (number_part or "NIL") .. "'")  
      print("After pattern: '" .. (after_pattern or "NIL") .. "'")
      print("Full pattern: '" .. (before_pattern or "") .. "' + [NUMBER] + '" .. (after_pattern or "") .. "'")
      
      -- Step 3: FUZZY SEARCH for variants using before/after patterns
      local same_category_variants = {}
      local global_variants = {}
      local context_variants = {}
      local other_variants = {}
      
      if before_pattern and after_pattern then
        for _, command in ipairs(paketti_commands) do
          if command.name ~= exact_match_command.name then
            local command_name_lower = command.name:lower()
            -- Clean the command name the same way for consistent pattern matching
            local clean_command_name = command_name_lower:gsub("^[^:]+:paketti:", "paketti:")
            
            -- Check if command matches the fuzzy pattern: before + [number] + after
            local has_before = before_pattern == "" or string.find(clean_command_name, before_pattern, 1, true)
            local has_after = after_pattern == "" or string.find(clean_command_name, after_pattern, 1, true)
            local has_number = string.find(clean_command_name, "[%+%-]?%d+")
            
                         if has_before and has_after and has_number then
               print("Found fuzzy match: " .. command.name .. " [" .. command.category .. "]")
              if command.category == target_category then
                table.insert(same_category_variants, command)
              elseif command.category == "Global" then
                table.insert(global_variants, command)
              elseif is_context_relevant(command) then
                table.insert(context_variants, command)
              else
                table.insert(other_variants, command)
              end
            else
              -- Debug why commands don't match
              if command.name:lower():find("duplicate") and command.name:lower():find("sample") then
                print("DEBUG: Command '" .. command.name .. "' failed pattern match:")
                print("  Original: " .. command_name_lower)
                print("  Cleaned: " .. clean_command_name)
                print("  has_before (" .. (before_pattern or "") .. "): " .. tostring(has_before))
                print("  has_after (" .. (after_pattern or "") .. "): " .. tostring(has_after))  
                print("  has_number: " .. tostring(has_number))
              end
            end
          end
        end
      end
      
      -- For "Flip it And Reverse it", add ALL variants from ALL categories
      -- Add same-category variants first (highest priority)
      for _, variant in ipairs(same_category_variants) do
        table.insert(template_variants, variant)
        print("Found SAME-CATEGORY variant: " .. variant.name .. " [" .. variant.category .. "]")
      end
      
      -- Add Global variants (second priority)
      for _, variant in ipairs(global_variants) do
        table.insert(template_variants, variant)
        print("Found GLOBAL variant: " .. variant.name .. " [" .. variant.category .. "]")
      end
      
      -- Add context-relevant variants (third priority)
      for _, variant in ipairs(context_variants) do
        table.insert(template_variants, variant)
        print("Found CONTEXT variant: " .. variant.name .. " [" .. variant.category .. "]")
      end
      
      -- Add all other variants (fourth priority)
      for _, variant in ipairs(other_variants) do
        table.insert(template_variants, variant)
        print("Found OTHER variant: " .. variant.name .. " [" .. variant.category .. "]")
      end
      
      print("VARIANT SUMMARY:")
      print("  Same category: " .. #same_category_variants)
      print("  Global: " .. #global_variants) 
      print("  Context: " .. #context_variants)
      print("  Other: " .. #other_variants)
      print("  Total template variants: " .. #template_variants)
      print("=== END FLIP IT AND REVERSE IT DEBUG ===")
    end
  end
  
  -- Convert to scored commands, preferring group representatives
  local scored_commands = {}
  local added_commands = {} -- Track which commands we've added to avoid duplicates
  
  for group_name, group_commands in pairs(groups) do
    local representative = group_representatives[group_name]
    
    if numeric_info then
      -- For numeric patterns with "Flip it And Reverse It" - include exact match + all template variants
      local all_commands_to_score = {}
      
      -- Add commands from the group
      for _, command in ipairs(group_commands) do
        table.insert(all_commands_to_score, command)
      end
      
      -- Add template variants (they might not be in the original search results)
      for _, variant in ipairs(template_variants) do
        local already_included = false
        for _, existing in ipairs(all_commands_to_score) do
          if existing.name == variant.name then
            already_included = true
            break
          end
        end
        if not already_included then
          table.insert(all_commands_to_score, variant)
        end
      end
      
      -- Sort commands by proximity to search term for "Flip it And Reverse it"
      table.sort(all_commands_to_score, function(a, b)
        local a_num = tonumber(a.name:match("([%+%-]?%d+)")) or 0
        local b_num = tonumber(b.name:match("([%+%-]?%d+)")) or 0
        local search_num = tonumber(numeric_info.original:match("([%+%-]?%d+)")) or 0
        
        -- Calculate distance from search term
        local a_distance = math.abs(a_num - search_num)
        local b_distance = math.abs(b_num - search_num)
        
        if a_distance ~= b_distance then
          return a_distance < b_distance  -- Closer numbers first (proximity-based)
        elseif a_num ~= b_num then
          return a_num > b_num  -- Same distance: prefer higher numbers
        else
          return a.name < b.name  -- Fallback to alphabetical
        end
      end)
      
      -- Score and add all commands (original group + template variants)
      for _, command in ipairs(all_commands_to_score) do
        if not added_commands[command.name] then
          local score = calculate_command_score(command, search_terms)
          
          -- Enhanced scoring for numeric patterns using "Flip it And Reverse It"
          score = score + score_flip_and_reverse(command, numeric_info, exact_match_command, template_variants)
          
          -- Prefer Global category
          if command.category == "Global" then
            score = score + 200
          end
          
          -- Check for exact abbreviation match and give massive priority bonus
          for abbrev, full_command in pairs(user_abbreviations) do
            if abbrev:lower() == filter_lower and command.name:lower() == full_command:lower() then
              score = score + 50000  -- MASSIVE bonus for exact abbreviation match
              print("ABBREVIATION MATCH BONUS: '" .. abbrev .. "' -> '" .. command.name .. "' (+50000)")
              break
            end
          end
          
          -- Set priority reason
          command.priority_reason = nil
          for _, fav_name in ipairs(favorite_commands) do
            if command.name == fav_name then
              command.priority_reason = "[FAVORITE]"
              break
            end
          end
          for _, recent_name in ipairs(recent_commands) do
            if command.name == recent_name then
              command.priority_reason = "[RECENTLY]"
              break
            end
          end
          
          table.insert(scored_commands, {command = command, score = score})
          added_commands[command.name] = true
        end
      end
    else
      -- For regular searches, check if this group should show all variants or just representative
      local should_show_all_variants = false
      
      -- Show all variants ONLY if this is actually a numeric pattern search
      -- Don't apply variant logic to regular text searches that happen to contain numbers
      if numeric_info then
        -- Only apply variant logic to actual numeric searches (like "+36")
        for _, command in ipairs(group_commands) do
          if command.name:lower():match("[%+%-]?%d+") then
            should_show_all_variants = true
            break
          end
        end
      end
      
      if should_show_all_variants and #group_commands > 1 then
        -- Show all variants in this group (like transpose commands)
        -- But also check for variants in OTHER categories with the same pattern
        local base_pattern = group_name:gsub("X", "[%+%-]?%d+") -- Convert placeholder back to regex
        local all_matching_commands = {}
        
        -- Find ALL commands across ALL categories that match this pattern
        for _, command in ipairs(paketti_commands) do
          local clean_name = command.name:gsub("^[^:]+:Paketti:", "")
          if clean_name:match("^" .. base_pattern .. "$") then
            table.insert(all_matching_commands, command)
          end
        end
        
        print("Found " .. #all_matching_commands .. " total variants for pattern: " .. base_pattern)
        
        -- Sort by numeric values (transpose order)
        table.sort(all_matching_commands, function(a, b)
          local a_num = tonumber(a.name:match("([%+%-]?%d+)")) or 0
          local b_num = tonumber(b.name:match("([%+%-]?%d+)")) or 0
          return a_num < b_num
        end)
        
        -- Add all variants with proper scoring
        for _, command in ipairs(all_matching_commands) do
          if not added_commands[command.name] then
            local score = calculate_command_score(command, search_terms)
            
            -- Prefer Global and context-relevant categories
            if command.category == "Global" then
              score = score + 300  -- Higher bonus for Global
            elseif is_context_relevant(command) then
              score = score + 200  -- High bonus for context-relevant  
            else
              score = score + 100  -- Some bonus for other categories
            end
            
            -- Check for exact abbreviation match and give massive priority bonus
            for abbrev, full_command in pairs(user_abbreviations) do
              if abbrev:lower() == filter_lower and command.name:lower() == full_command:lower() then
                score = score + 50000  -- MASSIVE bonus for exact abbreviation match
                print("ABBREVIATION MATCH BONUS: '" .. abbrev .. "' -> '" .. command.name .. "' (+50000)")
                break
              end
            end
            
            -- Set priority reason
            command.priority_reason = nil
            for _, fav_name in ipairs(favorite_commands) do
              if command.name == fav_name then
                command.priority_reason = "[FAVORITE]"
                break
              end
            end
            for _, recent_name in ipairs(recent_commands) do
              if command.name == recent_name then
                command.priority_reason = "[RECENTLY]"
                break
              end
            end
            
            table.insert(scored_commands, {command = command, score = score})
            added_commands[command.name] = true
            print("Added variant: " .. command.name .. " [" .. command.category .. "] (score: " .. score .. ")")
          end
        end
      else
        -- For multi-word searches, show all matching commands, not just representatives
        if #search_terms > 1 then
          -- Multi-word search: show all commands in this group
          for _, command in ipairs(group_commands) do
            if not added_commands[command.name] then
              local score = calculate_command_score(command, search_terms)
              
              -- Check for exact abbreviation match and give massive priority bonus
              for abbrev, full_command in pairs(user_abbreviations) do
                if abbrev:lower() == filter_lower and command.name:lower() == full_command:lower() then
                  score = score + 50000  -- MASSIVE bonus for exact abbreviation match
                  print("ABBREVIATION MATCH BONUS: '" .. abbrev .. "' -> '" .. command.name .. "' (+50000)")
                  break
                end
              end
              
              -- Set priority reason
              command.priority_reason = nil
              for _, fav_name in ipairs(favorite_commands) do
                if command.name == fav_name then
                  command.priority_reason = "[FAVORITE]"
                  break
                end
              end
              for _, recent_name in ipairs(recent_commands) do
                if command.name == recent_name then
                  command.priority_reason = "[RECENTLY]"
                  break
                end
              end
              
              table.insert(scored_commands, {command = command, score = score})
              added_commands[command.name] = true
              print("Added multi-word match: " .. command.name .. " [" .. command.category .. "] (score: " .. score .. ")")
            end
          end
        else
          -- Single-word search: prefer the group representative  
          if not added_commands[representative.name] then
            local score = calculate_command_score(representative, search_terms)
            
            -- Check for exact abbreviation match and give massive priority bonus
            for abbrev, full_command in pairs(user_abbreviations) do
              if abbrev:lower() == filter_lower and representative.name:lower() == full_command:lower() then
                score = score + 50000  -- MASSIVE bonus for exact abbreviation match
                print("ABBREVIATION MATCH BONUS: '" .. abbrev .. "' -> '" .. representative.name .. "' (+50000)")
                break
              end
            end
            
            -- Set priority reason
            representative.priority_reason = nil
            for _, fav_name in ipairs(favorite_commands) do
              if representative.name == fav_name then
                representative.priority_reason = "[FAVORITE]"
                break
              end
            end
            for _, recent_name in ipairs(recent_commands) do
              if representative.name == recent_name then
                representative.priority_reason = "[RECENTLY]"
                break
              end
            end
            
            table.insert(scored_commands, {command = representative, score = score})
            added_commands[representative.name] = true
          end
        end
      end
    end
  end
  
  -- Smart context-aware sorting with numeric proximity ordering
  table.sort(scored_commands, function(a, b) 
    -- TIER 1: Category priority (Global first, then context-relevant)
    local a_is_global = (a.command.category == "Global")
    local b_is_global = (b.command.category == "Global")
    
    if a_is_global ~= b_is_global then
      return a_is_global  -- Global commands always come first
    end
    
    -- TIER 2: Context priority (within same Global/non-Global tier)
    local a_priority = get_context_priority(a.command)
    local b_priority = get_context_priority(b.command)
    
    if a_priority ~= b_priority then
      return a_priority > b_priority
    end
    
    -- TIER 3: Score-based sorting (template variants get 8000+ points!)
    if a.score ~= b.score then
      return a.score > b.score
    end
    
    -- TIER 4: Smart numeric ordering for commands with numbers (within same score tier)
    local a_number = a.command.name:match("([%+%-]?%d+)")
    local b_number = b.command.name:match("([%+%-]?%d+)")
    
    if a_number and b_number then
      local a_num = tonumber(a_number) or 0
      local b_num = tonumber(b_number) or 0
      
      if numeric_info then
        -- For numeric searches (like "-36"), sort by proximity to search term
        local search_num = tonumber(numeric_info.original:match("([%+%-]?%d+)")) or 0
        local a_distance = math.abs(a_num - search_num)
        local b_distance = math.abs(b_num - search_num)
        
        if a_distance ~= b_distance then
          return a_distance < b_distance  -- Closer numbers first
        else
          -- Same distance: sort by numeric value consistently
          if a_num ~= b_num then
            return a_num > b_num  -- Higher numbers first when distance is equal
          else
            return false  -- Equal numbers - maintain stable sort
          end
        end
      else
        -- For text searches with numbers (like "duplicate all"), use smart default ordering
        -- Start from positive high numbers and work down: +36, +24, +12, -12, -24, -36
        local function get_order_priority(num)
          if num > 0 then
            return 1000 - num  -- +36=964, +24=976, +12=988
          else
            return 500 + num   -- -12=488, -24=476, -36=464
          end
        end
        
        local a_order = get_order_priority(a_num)
        local b_order = get_order_priority(b_num)
        
        if a_order ~= b_order then
          return a_order > b_order  -- Higher priority first
        else
          return a_num > b_num  -- Fallback to numeric order
        end
      end
    elseif a_number and not b_number then
      return true   -- Numbered commands before non-numbered
    elseif not a_number and b_number then
      return false  -- Numbered commands before non-numbered
    end
    
    -- TIER 5: Alphabetical fallback
    return a.command.name < b.command.name
  end)
  
  -- Extract just the commands with smart deduplication for recently used items
  local deduplicated = {}
  local command_names_seen = {}
  
  for _, scored in ipairs(scored_commands) do
    local cmd = scored.command
    local base_name = cmd.name
    
    -- If this command already exists without [RECENTLY] tag, skip the recently used version
    if cmd.priority_reason == "[RECENTLY]" and command_names_seen[base_name] then
      print("DEDUPE: Skipping recently used duplicate: " .. base_name)
    else
      table.insert(deduplicated, cmd)
      command_names_seen[base_name] = true
    end
  end
  
  -- Use deduplicated results
  filtered = deduplicated
  
  print("filter_commands returning " .. #filtered .. " commands for '" .. filter_text .. "'")
  if #filtered > 0 then
    print("First 3 results:")
    for i = 1, math.min(3, #filtered) do
      local cmd = filtered[i]
      local priority = get_context_priority(cmd)
      local priority_label = priority >= 1000 and "EXACT" or (priority >= 100 and "RELATED" or "OTHER")
      print("  " .. i .. ": [" .. priority_label .. ":" .. priority .. "] [" .. get_display_category(cmd) .. "] " .. get_clean_command_name(cmd))
    end
  end
  
  return filtered
end

-- Smart ordering for empty filter (favorites, recent, context-relevant)
get_smart_ordered_commands = function()
  local ordered = {}
  local added = {}
  
  -- Helper function to check if command has shortcuts (OPTIMIZED)
  local function has_shortcut(command)
    if not command or not command.name then return false end
    
    -- Check cache first for instant lookup
    local cached_result = shortcut_lookup_cache[command.name]
    if cached_result ~= nil then
      return cached_result ~= ""
    end
    
    -- Fall back to full lookup if not cached
    local shortcut_result = get_command_shortcut(command)
    return shortcut_result ~= ""
  end
  
  -- If we're in a specific context, ONLY show context-relevant commands
  if current_context ~= "global" then
    local context_count = 0
    local seen_invokes = {}
    -- Only add context-relevant commands
    for _, command in ipairs(paketti_commands) do
      local unique_key = command.category .. "|" .. command.name
      local invoke_key = command.invoke or ""
      local include_command = is_context_relevant(command) and not added[unique_key] and not seen_invokes[invoke_key]
      
      -- If checkbox is checked, only include commands with shortcuts
      if include_command and show_only_with_shortcuts_checkbox and show_only_with_shortcuts_checkbox.value then
        include_command = has_shortcut(command)
      end
      
      if include_command then
        context_count = context_count + 1
        seen_invokes[invoke_key] = true
        
        -- Still prioritize favorites/recent within context
        if command.name then
          for _, fav_name in ipairs(favorite_commands) do
            if command.name == fav_name then
              command.priority_reason = "[FAVORITE]"
              break
            end
          end
          
          for _, recent_name in ipairs(recent_commands) do
            if command.name == recent_name then
              command.priority_reason = "[RECENTLY]"
              break
            end
          end
          

        end
        
        table.insert(ordered, command)
        added[unique_key] = true
      end
    end
    
    -- Sort by context priority (highest priority first)
    print("Sorting " .. #ordered .. " commands by priority for context: " .. current_context)
    table.sort(ordered, function(a, b)
      local priority_a = get_context_priority(a)
      local priority_b = get_context_priority(b)
      if priority_a ~= priority_b then
        return priority_a > priority_b  -- Higher priority first
      end
      
      -- Same priority - check if these are numbered commands (like tab switchers)
      local a_number = a.name:match("%((%d+)%s")
      local b_number = b.name:match("%((%d+)%s")
      
      if a_number and b_number then
        -- Both have numbers - sort numerically
        return tonumber(a_number) < tonumber(b_number)
      elseif a_number and not b_number then
        -- Only 'a' has number - numbered commands come first
        return true
      elseif not a_number and b_number then
        -- Only 'b' has number - numbered commands come first  
        return false
      else
        -- Neither has numbers, sort alphabetically by category then name
        if a.category ~= b.category then
          return a.category < b.category
        end
        return a.name < b.name
      end
    end)
    
    -- Show first few sorted commands for debugging
    print("First 3 sorted commands:")
    for i = 1, math.min(3, #ordered) do
      local cmd = ordered[i]
      local priority = get_context_priority(cmd)
      print("  " .. i .. ": [Priority:" .. priority .. "] " .. cmd.category)
    end
    
    return ordered
  end
  
  -- Global context: show all commands with smart ordering
  local seen_invokes = {}
  
  -- 1. Add favorites first
  for _, fav_name in ipairs(favorite_commands) do
    for _, command in ipairs(paketti_commands) do
      local unique_key = command.category .. "|" .. command.name
      local invoke_key = command.invoke or ""
      local include_command = command.name == fav_name and not added[unique_key] and not seen_invokes[invoke_key]
      
      -- If checkbox is checked, only include commands with shortcuts
      if include_command and show_only_with_shortcuts_checkbox and show_only_with_shortcuts_checkbox.value then
        include_command = has_shortcut(command)
      end
      
      if include_command then
        command.priority_reason = "[FAVORITE]"
        table.insert(ordered, command)
        added[unique_key] = true
        seen_invokes[invoke_key] = true
        break
      end
    end
  end
  
  -- 2. Add recent commands
  for _, recent_name in ipairs(recent_commands) do
    for _, command in ipairs(paketti_commands) do
      local unique_key = command.category .. "|" .. command.name
      local invoke_key = command.invoke or ""
      local include_command = command.name == recent_name and not added[unique_key] and not seen_invokes[invoke_key]
      
      -- If checkbox is checked, only include commands with shortcuts
      if include_command and show_only_with_shortcuts_checkbox and show_only_with_shortcuts_checkbox.value then
        include_command = has_shortcut(command)
      end
      
      if include_command then
        command.priority_reason = "[RECENTLY]"
        table.insert(ordered, command)
        added[unique_key] = true
        seen_invokes[invoke_key] = true
        break
      end
    end
  end
  
  -- 3. Add context-relevant commands
  for _, command in ipairs(paketti_commands) do
    local unique_key = command.category .. "|" .. command.name
    local invoke_key = command.invoke or ""
    local include_command = not added[unique_key] and not seen_invokes[invoke_key] and is_context_relevant(command)
    
    -- If checkbox is checked, only include commands with shortcuts
    if include_command and show_only_with_shortcuts_checkbox and show_only_with_shortcuts_checkbox.value then
      include_command = has_shortcut(command)
    end
    
    if include_command then
      table.insert(ordered, command)
      added[unique_key] = true
      seen_invokes[invoke_key] = true
    end
  end
  
  -- 4. Add remaining commands
  for _, command in ipairs(paketti_commands) do
    local unique_key = command.category .. "|" .. command.name
    local invoke_key = command.invoke or ""
    local include_command = not added[unique_key] and not seen_invokes[invoke_key]
    
    -- If checkbox is checked, only include commands with shortcuts
    if include_command and show_only_with_shortcuts_checkbox and show_only_with_shortcuts_checkbox.value then
      include_command = has_shortcut(command)
    end
    
    if include_command then
      command.priority_reason = nil
      table.insert(ordered, command)
      added[unique_key] = true
      seen_invokes[invoke_key] = true
    end
  end
  
  print("Global context: Total " .. #ordered .. " commands")
  return ordered
end

-- Calculate relevance score for a command
calculate_command_score = function(command, search_terms)
  local score = 0
  
  -- Base score for exact matches
  for _, term in ipairs(search_terms) do
    local name_lower = command.name:lower()
    local category_lower = command.category:lower()
    
    -- Check if this is a numeric pattern (don't apply exact word bonuses to numeric searches)
    local is_numeric_search = detect_numeric_pattern(term)
    
    -- Exact name match (highest score)
    if name_lower == term then
      score = score + 1000
    elseif name_lower:match("^" .. escape_pattern(term)) then  -- Starts with term (escaped)
      score = score + 500
    elseif string.find(name_lower, term, 1, true) then  -- Contains term
      score = score + 100
      
      -- Extra bonus for exact word matches (only for non-numeric searches)
      if not is_numeric_search then
        -- Check if the term appears as a complete word (surrounded by word boundaries)
        if string.find(name_lower, "%f[%w]" .. escape_pattern(term) .. "%f[%W]") then
          score = score + 2000  -- MASSIVE bonus for exact word match like "dB"
        elseif string.find(name_lower, escape_pattern(term) .. "$") then
          score = score + 1500  -- Large bonus for term at end of name
        end
      end
    end
    
    -- Category match
    if string.find(category_lower, term, 1, true) then
      score = score + 50
    end
    
    -- Abbreviation match
    for _, abbrev in ipairs(command.abbreviations) do
      if abbrev:lower() == term then
        score = score + 200
      elseif string.find(abbrev:lower(), term, 1, true) then
        score = score + 75
      end
    end
  end
  
  -- Boost score for usage frequency
  local usage = command_usage_count[command.name] or 0
  score = score + math.min(usage * 10, 200)  -- Cap usage boost at 200
  
  -- Boost for favorites
  for _, fav_name in ipairs(favorite_commands) do
    if command.name == fav_name then
      score = score + 300
      break
    end
  end
  
  -- Boost for recent usage
  for i, recent_name in ipairs(recent_commands) do
    if command.name == recent_name then
      score = score + (50 - i)  -- More recent = higher score
      break
    end
  end
  
  -- Context relevance boost
  if is_context_relevant(command) then
    score = score + 150
  end
  
  return score
end

-- Get context priority with exact category matching (higher number = higher priority)
function get_context_priority(command)
  local category_lower = command.category:lower()
  local name_lower = command.name:lower()
  
  if current_context == "sample_editor" then
    -- TIER 1: Exact context match - highest priority
    if string.find(category_lower, "sample editor") then
      return 1000  -- Sample Editor commands first
    end
    
    -- TIER 2: Related sample contexts - medium priority  
    if string.find(category_lower, "sample navigator") then
      return 800   -- Sample Navigator second
    end
    if string.find(category_lower, "sample mappings") then
      return 700   -- Sample Mappings third
    end
    if string.find(category_lower, "sample fx mixer") then
      return 600   -- Sample FX Mixer fourth
    end
    if string.find(category_lower, "sample modulation") then
      return 500   -- Sample Modulation fifth
    end
    
    -- TIER 3: Any other sample-related - lower priority
    if string.find(category_lower, "sample") or string.find(name_lower, "sample") then
      return 100   -- Other sample commands last among relevant
    end
    
  elseif current_context == "sample_modulation" then
    -- TIER 1: Exact context match - highest priority
    if string.find(category_lower, "sample modulation") then
      return 1000  -- Sample Modulation commands first
    end
    
    -- TIER 2: Related sample contexts - medium priority  
    if string.find(category_lower, "sample editor") then
      return 800   -- Sample Editor second
    end
    if string.find(category_lower, "sample navigator") then
      return 700   -- Sample Navigator third
    end
    if string.find(category_lower, "sample mappings") then
      return 600   -- Sample Mappings fourth
    end
    if string.find(category_lower, "sample fx mixer") then
      return 500   -- Sample FX Mixer fifth
    end
    
        -- TIER 3: Any other sample-related - lower priority
    if string.find(category_lower, "sample") or string.find(name_lower, "sample") then
      return 100   -- Other sample commands last among relevant
    end
    
  elseif current_context == "sample_effects" then
    -- TIER 1: Exact context match - highest priority
    if string.find(category_lower, "sample fx mixer") or string.find(category_lower, "sample effects") then
      return 1000  -- Sample Effects commands first
    end
    
    -- TIER 2: Related sample contexts - medium priority  
    if string.find(category_lower, "sample editor") then
      return 800   -- Sample Editor second
    end
    if string.find(category_lower, "sample modulation") then
      return 700   -- Sample Modulation third
    end
    if string.find(category_lower, "sample navigator") then
      return 600   -- Sample Navigator fourth
    end
    if string.find(category_lower, "sample mappings") then
      return 500   -- Sample Mappings fifth
    end
    
        -- TIER 3: Any other sample-related - lower priority
    if string.find(category_lower, "sample") or string.find(name_lower, "sample") then
      return 100   -- Other sample commands last among relevant
    end
      
  elseif current_context == "sample_keyzones" then
    -- TIER 1: Exact context match - highest priority
    if string.find(category_lower, "sample mappings") or string.find(category_lower, "keyzone") then
      return 1000  -- Sample Keyzones/Mappings commands first
    end
    
    -- TIER 2: Related sample contexts - medium priority  
    if string.find(category_lower, "sample editor") then
      return 800   -- Sample Editor second
    end
    if string.find(category_lower, "sample modulation") then
      return 700   -- Sample Modulation third
    end
    if string.find(category_lower, "sample fx mixer") then
      return 600   -- Sample FX Mixer fourth
    end
    if string.find(category_lower, "sample navigator") then
      return 500   -- Sample Navigator fifth
    end
    
    -- TIER 3: Any other sample-related - lower priority
    if string.find(category_lower, "sample") or string.find(name_lower, "sample") or string.find(name_lower, "keyzone") then
      return 100   -- Other sample commands last among relevant
    end
      
  elseif current_context == "pattern_editor" then
    -- TIER 1: Exact context match
    if string.find(category_lower, "pattern editor") then
      return 1000
    end
    -- TIER 3: Related pattern commands
    if string.find(category_lower, "pattern") or string.find(name_lower, "pattern") then
      return 100
    end
    
  elseif current_context == "phrase_editor" then
    -- TIER 1: Exact context match
    if string.find(category_lower, "phrase editor") then
      return 1000
    end
    -- TIER 3: Related phrase commands
    if string.find(category_lower, "phrase") or string.find(name_lower, "phrase") then
      return 100
    end
  end
  
  -- TIER 4: Unrelated commands
  return 0
end

-- Check if command is relevant to current context
is_context_relevant = function(command)
  local category_lower = command.category:lower()
  local name_lower = command.name:lower()
  
  -- Removed verbose debug output for performance
  
  if current_context == "sample_editor" or current_context == "sample_modulation" or current_context == "sample_effects" or current_context == "sample_keyzones" then
    -- For sample editor, sample modulation, sample effects, and sample keyzones, match the ACTUAL category patterns used by Paketti
    
    -- Primary sample editor categories (these are the real ones!)
    if string.find(category_lower, "sample editor") or 
       string.find(category_lower, "sample navigator") or 
       string.find(category_lower, "sample mappings") or 
       string.find(category_lower, "sample fx mixer") or 
       string.find(category_lower, "sample modulation") or
       string.find(category_lower, "keyzone") then
      return true
    end
    
    -- Always include anything with "sample" or "keyzone" in name
    if string.find(name_lower, "sample") or string.find(name_lower, "keyzone") then
      return true
    end
    
    -- Include sample-related keywords
    local sample_keywords = {"process", "generate", "slice", "pitch", "volume", "normalize", "reverse", "loop", "import", "export", "zoom"}
    for _, keyword in ipairs(sample_keywords) do
      if string.find(name_lower, keyword) or string.find(category_lower, keyword) then
        return true
      end
    end
    
    return false
    
  elseif current_context == "pattern_editor" then
    -- For pattern editor, match the ACTUAL category patterns
    
    -- Primary pattern editor categories
    if string.find(category_lower, "pattern editor") or 
       string.find(category_lower, "pattern") then
      return true
    end
    
    -- Always include anything with "pattern" in name
    if string.find(name_lower, "pattern") then
      return true
    end
    
    -- Include pattern-related keywords
    local pattern_keywords = {"note", "track", "sequence", "edit", "cursor", "selection", "line", "column", "row", "effect", "command"}
    for _, keyword in ipairs(pattern_keywords) do
      if string.find(name_lower, keyword) or string.find(category_lower, keyword) then
        return true
      end
    end
    
    return false
    
  elseif current_context == "mixer" then
    if string.find(category_lower, "mixer") or string.find(name_lower, "mixer") then
      return true
    end
    
  elseif current_context == "phrase_editor" then
    -- For phrase editor, match both primary and secondary phrase commands
    
    -- Primary phrase editor categories (exact matches)
    if string.find(category_lower, "phrase editor") then
      return true
    end
    
    -- Secondary: other phrase-related categories and names
    if string.find(category_lower, "phrase") or string.find(name_lower, "phrase") then
      return true
    end
    

  end
  
  -- For other contexts, be permissive
  return false
end

-- Load user-defined abbreviations from file
local function load_user_abbreviations()
  user_abbreviations = {}
  local file = io.open(renoise.tool().bundle_path .. "autocomplete_abbreviations.txt", "r")
  if file then
    for line in file:lines() do
      local abbrev, full_command = line:match("^([^=]+)=(.+)$")
      if abbrev and full_command then
        user_abbreviations[string.lower(abbrev:match("^%s*(.-)%s*$"))] = full_command:match("^%s*(.-)%s*$")
      end
    end
    file:close()
  end
end

-- Save user-defined abbreviations to file
local function save_user_abbreviations()
  local file = io.open(renoise.tool().bundle_path .. "autocomplete_abbreviations.txt", "w")
  if file then
    for abbrev, full_command in pairs(user_abbreviations) do
      file:write(abbrev .. "=" .. full_command .. "\n")
    end
    file:close()
  end
end

-- Performance optimization functions
-- Cache management
local function save_commands_cache()
  local file = io.open(cache_file_path, "w")
  if file then
    file:write("CACHE_VERSION=1.0\n")
    file:write("SCAN_TIME=" .. last_scan_time .. "\n")
    file:write("COMMAND_COUNT=" .. #paketti_commands .. "\n")
    for _, command in ipairs(paketti_commands) do
      -- Serialize command data (using ||| as delimiter to avoid conflicts)
      local serialized = string.format("%s|||%s|||%s|||%s|||%s|||%s",
        command.type or "",
        command.name or "",
        command.category or "",
        command.invoke or "",
        table.concat(command.abbreviations or {}, ","),
        command.source_file or ""
      )
      file:write(serialized .. "\n")
    end
    file:close()
  end
end

local function load_commands_cache()
  local file = io.open(cache_file_path, "r")
  if not file then return false end
  
  paketti_commands = {}
  local version = file:read("*line")
  local scan_time_line = file:read("*line")
  local count_line = file:read("*line")
  
  if not version or not version:match("CACHE_VERSION=1%.0") then
    file:close()
    return false
  end
  
  last_scan_time = tonumber(scan_time_line:match("SCAN_TIME=(.+)")) or 0
  
  for line in file:lines() do
    -- Split on triple pipe delimiter
    local parts = {}
    local start = 1
    while true do
      local pos = string.find(line, "|||", start)
      if pos then
        table.insert(parts, string.sub(line, start, pos - 1))
        start = pos + 3
      else
        table.insert(parts, string.sub(line, start))
        break
      end
    end
    
    if #parts >= 6 then
      local abbreviations = {}
      if parts[5] and parts[5] ~= "" then
        for abbrev in parts[5]:gmatch("([^,]+)") do
          table.insert(abbreviations, abbrev)
        end
      end
      
      local command = {
        type = parts[1],
        name = parts[2],
        category = parts[3],
        invoke = parts[4],
        abbreviations = abbreviations,
        source_file = parts[6]
      }
      

      
      table.insert(paketti_commands, command)
    end
  end
  file:close()
  
  print(string.format("PakettiAutocomplete: Loaded %d commands from cache", #paketti_commands))
  return true
end

-- Usage tracking
local function load_usage_data()
  command_usage_count = {}
  recent_commands = {}
  
  local file = io.open(usage_file_path, "r")
  if file then
    for line in file:lines() do
      local command_name, count = line:match("^(.+):(%d+)$")
      if command_name and count then
        command_usage_count[command_name] = tonumber(count)
      end
    end
    file:close()
  end
  
  -- Load recent commands (last 50)
  for command_name, count in pairs(command_usage_count) do
    table.insert(recent_commands, {name = command_name, count = count})
  end
  
  -- Sort by usage count
  table.sort(recent_commands, function(a, b) return a.count > b.count end)
  
  -- Keep only last 50
  local temp = {}
  for i = 1, math.min(50, #recent_commands) do
    table.insert(temp, recent_commands[i].name)
  end
  recent_commands = temp
end

local function save_usage_data()
  local file = io.open(usage_file_path, "w")
  if file then
    for command_name, count in pairs(command_usage_count) do
      file:write(command_name .. ":" .. count .. "\n")
    end
    file:close()
  end
end

local function track_command_usage(command)
  if not command or not command.name then return end
  
  command_usage_count[command.name] = (command_usage_count[command.name] or 0) + 1
  
  -- Update recent commands
  for i, recent_name in ipairs(recent_commands) do
    if recent_name == command.name then
      table.remove(recent_commands, i)
      break
    end
  end
  table.insert(recent_commands, 1, command.name)
  
  -- Keep only last 50
  if #recent_commands > 50 then
    table.remove(recent_commands, #recent_commands)
  end
  
  save_usage_data()
end

-- Favorites management
local function load_favorites()
  favorite_commands = {}
  local file = io.open(favorites_file_path, "r")
  if file then
    for line in file:lines() do
      if line and line ~= "" then
        table.insert(favorite_commands, line)
      end
    end
    file:close()
  end
end

local function save_favorites()
  local file = io.open(favorites_file_path, "w")
  if file then
    for _, command_name in ipairs(favorite_commands) do
      file:write(command_name .. "\n")
    end
    file:close()
  end
end

local function toggle_favorite(command)
  if not command or not command.name then return end
  
  for i, fav_name in ipairs(favorite_commands) do
    if fav_name == command.name then
      table.remove(favorite_commands, i)
      save_favorites()
      renoise.app():show_status("Removed from favorites: " .. command.name)
      return
    end
  end
  
  table.insert(favorite_commands, command.name)
  save_favorites()
  renoise.app():show_status("Added to favorites: " .. command.name)
end

-- Context detection
local function detect_current_context()
  local app = renoise.app()
  local window = app.window
  
  print("CONTEXT DETECTION: middle_frame=" .. window.active_middle_frame .. ", SAMPLE_EDITOR=" .. renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR)
  
  -- MIDDLE FRAME (most important for context)
  if window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
    current_context = "pattern_editor"
  elseif window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_MIXER then
    current_context = "mixer"
  elseif window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
    current_context = "phrase_editor"
  elseif window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES then
    current_context = "sample_keyzones"
  elseif window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
    current_context = "sample_editor"
  elseif window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION then
    current_context = "sample_modulation"
  elseif window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS then
    current_context = "sample_effects"
  elseif window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR then
    current_context = "plugin_editor"
  elseif window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR then
    current_context = "midi_editor"
  else
    -- LOWER FRAME  
    if window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS then
      current_context = "track_dsps"
    elseif window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
      current_context = "track_automation"
    else
      current_context = "global"
    end
  end
  
  print("CONTEXT DETECTED: " .. current_context)
end

-- Build search index for fast searching
local function build_search_index()
  search_index = {}
  
  for i, command in ipairs(paketti_commands) do
    -- Index by name words
    for word in command.name:lower():gmatch("%w+") do
      if #word > 2 then  -- Only index meaningful words
        if not search_index[word] then
          search_index[word] = {}
        end
        table.insert(search_index[word], i)
      end
    end
    
    -- Index by category
    local category_lower = command.category:lower()
    if not search_index[category_lower] then
      search_index[category_lower] = {}
    end
    table.insert(search_index[category_lower], i)
    
    -- Index by abbreviations
    for _, abbrev in ipairs(command.abbreviations) do
      local abbrev_lower = abbrev:lower()
      if not search_index[abbrev_lower] then
        search_index[abbrev_lower] = {}
      end
      table.insert(search_index[abbrev_lower], i)
    end
  end
  
  -- Count search index terms
  local term_count = 0
  for _ in pairs(search_index) do term_count = term_count + 1 end
  print("PakettiAutocomplete: Built search index with " .. term_count .. " terms")
end

-- This function is now defined above in the new system

-- Function to execute selected command (now works with real Paketti commands and tracks usage)
local function execute_command(command)
  if not command then
    print("=== EXECUTE COMMAND DEBUG ===")
    print("ERROR: No command selected")
    print("=============================")
    renoise.app():show_status("No command selected")
    return
  end
  
  -- Print comprehensive debug information
  print("=== EXECUTE COMMAND DEBUG ===")
  print("CLICKED ON: " .. (command.name or "Unknown"))
  print("COMMAND TYPE: " .. (command.type or "Unknown"))
  print("COMMAND CATEGORY: " .. (command.category or "Unknown"))
  print("INVOKE FUNCTION: " .. (command.invoke or "Empty"))
  print("SOURCE FILE: " .. (command.source_file or "Unknown"))
  
  -- Check command validity
  if not command.invoke or command.invoke == "" then
    print("ERROR: No invoke function available")
    print("=============================")
    renoise.app():show_status("No invoke function for: " .. command.name)
    return
  end
  
  print("ATTEMPTING EXECUTION...")
  
  -- Track command usage
  track_command_usage(command)
  
  -- Try to execute the real Paketti function
  local success = false
  local error_msg = ""
  
  -- Method 1: Smart execution based on invoke string type
  print("METHOD 1: Analyzing invoke string type...")
  
  -- Check if it's a function definition or direct call
  if command.invoke:match("^function") then
    -- Function definition: needs "return" prefix to get the function, then call it
    print("DETECTED: Function definition - " .. command.invoke:sub(1, 50) .. "...")
    
    -- Special handling for MIDI mapping functions (they expect message parameter)
    if command.invoke:match("function%s*%(message%)") then
      print("DETECTED: MIDI mapping function - creating synthetic MIDI message with value 127")
      
      -- Create a fake MIDI message with value 127 to simulate a MIDI trigger
      local fake_message = {
        is_trigger = function() return true end,
        is_switch = function() return false end,
        is_rel_value = function() return false end,
        is_abs_value = function() return false end,
        int_value = 127,
        boolean_value = true
      }
      
      -- Execute the MIDI mapping function with the synthetic message
      local func = loadstring("return " .. command.invoke)
      if func then
        print("Successfully created MIDI function from invoke string")
        local ok, result = pcall(func)
        if ok and type(result) == "function" then
          print("MIDI function loaded successfully, executing with synthetic message...")
          local exec_ok, exec_err = pcall(result, fake_message)
          if exec_ok then
            success = true
            print("MIDI EXECUTION SUCCESSFUL!")
          else
            error_msg = "Error executing MIDI function: " .. tostring(exec_err)
            print("MIDI execution failed: " .. error_msg)
          end
        else
          print("MIDI function loading failed or result is not a function")
          if not ok then
            print("Error: " .. tostring(result))
          end
        end
      else
        print("Failed to create MIDI function from invoke string")
      end
    else
      -- Regular function definition - execute normally
      local func = loadstring("return " .. command.invoke)
      if func then
        print("Successfully created function from invoke string")
        local ok, result = pcall(func)
        if ok and type(result) == "function" then
          print("Function loaded successfully, executing...")
          local exec_ok, exec_err = pcall(result)
          if exec_ok then
            success = true
            print("EXECUTION SUCCESSFUL!")
          else
            error_msg = "Error executing: " .. tostring(exec_err)
            print("Execution failed: " .. error_msg)
          end
        else
          print("Function loading failed or result is not a function")
          if not ok then
            print("Error: " .. tostring(result))
          end
        end
      else
        print("Failed to create function from invoke string")
      end
    end
  else
    -- Direct function call: execute directly
    print("DETECTED: Direct function call")
    
    -- Handle backward compatibility for old pakettiLoadPlugin commands
    local invoke_string = command.invoke
    if invoke_string:match("pakettiLoadPlugin%(") then
      print("BACKWARD COMPATIBILITY: Converting pakettiLoadPlugin to loadPlugin")
      invoke_string = invoke_string:gsub("pakettiLoadPlugin%(", "loadPlugin(")
      print("CONVERTED: " .. invoke_string)
    end
    
    local func = loadstring(invoke_string)
    if func then
      print("Successfully created function from invoke string")
      local exec_ok, exec_err = pcall(func)
      if exec_ok then
        success = true
        print("EXECUTION SUCCESSFUL!")
      else
        error_msg = "Error executing: " .. tostring(exec_err)
        print("Execution failed: " .. error_msg)
      end
    else
      print("Failed to create function from invoke string")
    end
  end
  
  -- Method 2: Try global lookup (for simple function names only)
  if not success then
    print("METHOD 2: Trying global function lookup...")
    
    -- Only try global lookup for simple function names (no parentheses)
    if not command.invoke:match("[%(%)']") then
      print("CHECKING: Simple function name: " .. command.invoke)
      if _G[command.invoke] then
        if type(_G[command.invoke]) == "function" then
          print("Found global function: " .. command.invoke)
          local exec_ok, exec_err = pcall(_G[command.invoke])
          if exec_ok then
            success = true
            print("EXECUTION SUCCESSFUL!")
          else
            error_msg = "Error executing: " .. tostring(exec_err)
            print("Execution failed: " .. error_msg)
          end
        else
          print("Global " .. command.invoke .. " exists but is not a function (type: " .. type(_G[command.invoke]) .. ")")
        end
      else
        print("Global function " .. command.invoke .. " not found")
      end
    else
      print("SKIPPING: Complex invoke string, not suitable for global lookup: " .. command.invoke:sub(1, 50) .. "...")
    end
  end
  
  -- If execution failed, show error
  if not success then
    local final_error = error_msg ~= "" and error_msg or ("Failed to execute: " .. command.name)
    print("FINAL RESULT: FAILED")
    print("ERROR: " .. final_error)
    renoise.app():show_status(final_error)
  else
    print("FINAL RESULT: SUCCESS")
  end
  
  print("=============================")
  print("")
  
  -- Update the display to reflect new usage data
  if autocomplete_dialog and autocomplete_dialog.visible then
    -- Refresh the current filter to update rankings
    update_suggestions(current_search_text)
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

-- Function to update search display text
local function update_search_display()
  if search_display_text then
    search_display_text.text = "'" .. current_search_text .. "'"
  end
end

-- Function to update scrollbar properties based on current commands
local function update_scrollbar()
  if suggestions_scrollbar then
    local commands_count = #current_filtered_commands
    if commands_count <= MAX_VISIBLE_BUTTONS then
      -- No scrolling needed - hide scrollbar and page buttons
      suggestions_scrollbar.visible = false
      if prev_page_button then prev_page_button.visible = false end
      if next_page_button then next_page_button.visible = false end
    else
      -- Scrolling needed - show and configure scrollbar and page buttons
      suggestions_scrollbar.visible = true
      suggestions_scrollbar.min = 0
      suggestions_scrollbar.max = commands_count
      suggestions_scrollbar.pagestep = MAX_VISIBLE_BUTTONS
      suggestions_scrollbar.step = 1
      suggestions_scrollbar.value = current_scroll_offset
      
      -- Show/enable page buttons based on scroll position
      if prev_page_button then
        prev_page_button.visible = true
        prev_page_button.active = (current_scroll_offset > 0)
      end
      if next_page_button then
        next_page_button.visible = true
        next_page_button.active = (current_scroll_offset < commands_count - MAX_VISIBLE_BUTTONS)
      end
    end
  end
end

-- Function to go to previous page
local function go_to_previous_page()
  if #current_filtered_commands > MAX_VISIBLE_BUTTONS then
    current_scroll_offset = math.max(0, current_scroll_offset - MAX_VISIBLE_BUTTONS)
    update_scrollbar()
    update_button_display(true)
    -- Update selection to stay on screen
    if selected_suggestion_index > current_scroll_offset + MAX_VISIBLE_BUTTONS then
      selected_suggestion_index = current_scroll_offset + MAX_VISIBLE_BUTTONS
    end
  end
end

-- Function to go to next page
local function go_to_next_page()
  if #current_filtered_commands > MAX_VISIBLE_BUTTONS then
    local max_offset = #current_filtered_commands - MAX_VISIBLE_BUTTONS
    current_scroll_offset = math.min(max_offset, current_scroll_offset + MAX_VISIBLE_BUTTONS)
    update_scrollbar()
    update_button_display(true)
    -- Update selection to stay on screen
    if selected_suggestion_index <= current_scroll_offset then
      selected_suggestion_index = current_scroll_offset + 1
    end
  end
end

-- Function to ensure selected item is visible (auto-scroll)
local function ensure_selection_visible()
  if selected_suggestion_index <= 0 or #current_filtered_commands == 0 then
    local old_offset = current_scroll_offset
    current_scroll_offset = 0
    update_scrollbar()
    if old_offset ~= current_scroll_offset then
      update_button_display(true) -- Force full refresh if scroll changed
    end
    return
  end
  
  local old_scroll_offset = current_scroll_offset
  
  -- If selection is above visible area, scroll up
  if selected_suggestion_index <= current_scroll_offset then
    current_scroll_offset = selected_suggestion_index - 1
    if current_scroll_offset < 0 then
      current_scroll_offset = 0
    end
  end
  
  -- If selection is below visible area, scroll down
  if selected_suggestion_index > current_scroll_offset + MAX_VISIBLE_BUTTONS then
    current_scroll_offset = selected_suggestion_index - MAX_VISIBLE_BUTTONS
  end
  
  -- Update scrollbar to reflect new position
  update_scrollbar()
  
  -- Force full refresh if scroll position actually changed
  if old_scroll_offset ~= current_scroll_offset then
    update_button_display(true)
  end
end

-- Function to move selection up
local function move_selection_up()
  if #current_filtered_commands > 0 then
    if selected_suggestion_index == 1 then
      -- When at topmost suggestion, just stay at 1 (no textfield to focus)
      selected_suggestion_index = 0
    else
      selected_suggestion_index = selected_suggestion_index - 1
          if selected_suggestion_index < 1 then
      selected_suggestion_index = #current_filtered_commands -- Wrap to bottom
      end
    end
    ensure_selection_visible()
    update_button_display()
  end
end

-- Function to move selection down  
local function move_selection_down()
  if #current_filtered_commands > 0 then
    if selected_suggestion_index == 0 then
      -- Moving from top to first visible suggestion on current page
      selected_suggestion_index = current_scroll_offset + 1
    else
      selected_suggestion_index = selected_suggestion_index + 1
      if selected_suggestion_index > #current_filtered_commands then
        selected_suggestion_index = 1 -- Wrap to top
      end
    end
    ensure_selection_visible()
    update_button_display()
  end
end

-- Track previous selection to minimize updates
local previous_suggestion_index = 0
local last_commands_count = 0
local last_commands_hash = ""

-- Function to update button display (optimized to only update changed buttons)
function update_button_display(force_full_refresh)
  local commands_count = #current_filtered_commands
  print("update_button_display called - " .. commands_count .. " commands, force_full=" .. tostring(force_full_refresh or false))
  
  -- Generate hash of current command list to detect order changes
  local current_hash = ""
  for i = 1, math.min(10, commands_count) do -- Hash first 10 commands for efficiency
    if current_filtered_commands[i] then
      current_hash = current_hash .. current_filtered_commands[i].name .. "|"
    end
  end
  
  -- Check if this is a full refresh (commands changed, forced, order changed, or scroll position changed)
  local full_refresh = force_full_refresh or 
                      (commands_count ~= (last_commands_count or 0)) or 
                      (current_hash ~= (last_commands_hash or ""))
  last_commands_count = commands_count
  last_commands_hash = current_hash
  
  if full_refresh then
    print("Full refresh - updating all buttons")
    -- Full refresh: update all buttons
    for i = 1, MAX_VISIBLE_BUTTONS do
      if suggestion_buttons[i] then
        local command_index = i + current_scroll_offset
        if command_index <= commands_count then
          local command = current_filtered_commands[command_index]
          local button_text = ""
          
          -- Priority indicator removed - visual color coding is sufficient
          
          -- Add usage count indicator for frequently used commands
          local usage = command_usage_count[command.name] or 0
          local usage_indicator = ""
          if usage > 10 then
            usage_indicator = " (" .. usage .. "x)"
          end
          
          -- Build the display text
          if is_gadgets_search() and command.name:find("Paketti Gadgets:") then
            -- For gadgets search, show only the dialog name with status indicators
            local gadget_name = get_gadget_dialog_name(command)
            button_text = button_text .. gadget_name .. usage_indicator
          else
            -- Normal display format
            button_text = button_text .. string.format("[%s] %s%s%s", get_display_category(command), get_clean_command_name(command), get_command_shortcut(command), usage_indicator)
          end
          
          suggestion_buttons[i].text = button_text
          
          -- Set background color for selected button and priority states
          if command_index == selected_suggestion_index then
            suggestion_buttons[i].color = {0x80, 0x00, 0x80} -- Deep purple (selected) - highest priority
          elseif command.priority_reason == "[RECENTLY]" then
            suggestion_buttons[i].color = {0x80, 0x80, 0x80} -- Pale grey (recently used)
          elseif command.priority_reason == "[FAVORITE]" then
            suggestion_buttons[i].color = {0x80, 0x60, 0x00} -- Dark gold (favorite)
          elseif get_command_shortcut(command) ~= "" then
            suggestion_buttons[i].color = {0x00, 0x80, 0x00} -- Dark green (has shortcut)
          else
            suggestion_buttons[i].color = {0x00, 0x00, 0x00} -- Default (black/transparent)
          end
          suggestion_buttons[i].visible = true
        else
          suggestion_buttons[i].visible = false
        end
      end
    end
  else
    print("Selection change - updating only changed buttons")
    -- Selection change: only update the 2 affected buttons
    
    -- Update previously selected button (remove selection markers)
    local prev_button_index = previous_suggestion_index - current_scroll_offset
    if previous_suggestion_index > 0 and previous_suggestion_index <= commands_count and 
       prev_button_index >= 1 and prev_button_index <= MAX_VISIBLE_BUTTONS and 
       suggestion_buttons[prev_button_index] then
      local command = current_filtered_commands[previous_suggestion_index]
      local button_text = ""
      
      -- Priority indicator removed - visual color coding is sufficient
      
      local usage = command_usage_count[command.name] or 0
      local usage_indicator = ""
      if usage > 10 then
        usage_indicator = " (" .. usage .. "x)"
      end
      
      if is_gadgets_search() and command.name:find("Paketti Gadgets:") then
        -- For gadgets search, show only the dialog name with status indicators
        local gadget_name = get_gadget_dialog_name(command)
        button_text = button_text .. gadget_name .. usage_indicator
      else
        -- Normal display format
        button_text = button_text .. string.format("[%s] %s%s%s", get_display_category(command), get_clean_command_name(command), get_command_shortcut(command), usage_indicator)
      end
      
      print("Removing selection from command " .. previous_suggestion_index .. " (button " .. prev_button_index .. ")")
      suggestion_buttons[prev_button_index].text = button_text
      -- Reset color based on priority state
      if command.priority_reason == "[RECENTLY]" then
        suggestion_buttons[prev_button_index].color = {0x80, 0x80, 0x80} -- Pale grey (recently used)
      elseif command.priority_reason == "[FAVORITE]" then
        suggestion_buttons[prev_button_index].color = {0x80, 0x60, 0x00} -- Dark gold (favorite)
      elseif get_command_shortcut(command) ~= "" then
        suggestion_buttons[prev_button_index].color = {0x00, 0x80, 0x00} -- Dark green (has shortcut)
      else
        suggestion_buttons[prev_button_index].color = {0x00, 0x00, 0x00} -- Default color
      end
    end
    
    -- Update newly selected button (add selection markers)
    local curr_button_index = selected_suggestion_index - current_scroll_offset
    if selected_suggestion_index > 0 and selected_suggestion_index <= commands_count and
       curr_button_index >= 1 and curr_button_index <= MAX_VISIBLE_BUTTONS and
       suggestion_buttons[curr_button_index] then
      local command = current_filtered_commands[selected_suggestion_index]
      local button_text = ""
      
      -- Priority indicator removed - visual color coding is sufficient
      
      local usage = command_usage_count[command.name] or 0
      local usage_indicator = ""
      if usage > 10 then
        usage_indicator = " (" .. usage .. "x)"
      end
      
      if is_gadgets_search() and command.name:find("Paketti Gadgets:") then
        -- For gadgets search, show only the dialog name with status indicators
        local gadget_name = get_gadget_dialog_name(command)
        button_text = button_text .. gadget_name .. usage_indicator
      else
        -- Normal display format
        button_text = button_text .. string.format("[%s] %s%s%s", get_display_category(command), get_clean_command_name(command), get_command_shortcut(command), usage_indicator)
      end
      
      print("Adding selection to command " .. selected_suggestion_index .. " (button " .. curr_button_index .. ")")
      suggestion_buttons[curr_button_index].text = button_text
      suggestion_buttons[curr_button_index].color = {0x80, 0x00, 0x80} -- Deep purple (selected always overrides other colors)
    end
  end
  
  -- Update tracking variable
  previous_suggestion_index = selected_suggestion_index
  
  -- Show/hide the "create abbreviation" button based on match count and filter
  if create_abbrev_button then
    local should_show = (#current_filtered_commands == 0 and current_filter ~= "" and string.len(current_filter) > 1)
    create_abbrev_button.visible = should_show
    if should_show then
      create_abbrev_button.text = string.format("Create abbreviation '%s' →", current_filter)
    end
  end
end

-- TRUE Real-time keyhandler - captures every keystroke directly like Command Palette
local function autocomplete_keyhandler(dialog, key)
  -- Pass-through for '<' and '>' so Renoise can handle them
  if key and (key.name == "<" or key.name == ">") then
    return key
  end
  if key.name == "return" then
    print("Enter key pressed! current_search_text='" .. current_search_text .. "', selected_index=" .. selected_suggestion_index)
    
    -- FIRST: Check if this is an exact abbreviation match - if so, execute directly!
    local search_text = current_search_text:lower()
    if user_abbreviations[search_text] then
      local target_command_name = user_abbreviations[search_text]
      print("EXACT ABBREVIATION MATCH: '" .. current_search_text .. "' -> '" .. target_command_name .. "'")
      
      -- Find the actual command object
      for _, command in ipairs(paketti_commands) do
        if command.name == target_command_name then
          print("Found target command, executing directly...")
          execute_command(command)
          return nil
        end
      end
      
      -- If command not found, show error
      print("ERROR: Abbreviation target command not found: " .. target_command_name)
      renoise.app():show_status("Error: Command '" .. target_command_name .. "' not found")
      return nil
    end
    
    -- SECOND: Normal selection/search behavior
    -- If a command is selected, execute it
    if #current_filtered_commands > 0 and selected_suggestion_index > 0 then
      print("Executing selected command...")
      execute_selected_suggestion()
    else
      -- If no command selected but we have results, select first one
      if #current_filtered_commands > 0 then
        selected_suggestion_index = 1
        update_button_display()
        print("Auto-selected first command, press Enter again to execute")
      else
        -- No results - check if create abbreviation button is visible
        if create_abbrev_button and create_abbrev_button.visible and current_search_text ~= "" then
          print("No commands found, opening create abbreviation dialog for: '" .. current_search_text .. "'")
          show_command_picker(current_search_text)
        else
          -- Force search update if no results and no abbreviation creation
          print("No results, forcing search with: '" .. current_search_text .. "'")
          update_suggestions(current_search_text)
        end
      end
    end
    return nil  -- Consume the key
  elseif key.name == "up" then
    move_selection_up()
    return nil
  elseif key.name == "down" then
    move_selection_down()
    return nil
  elseif key.name == "prior" then
    -- Page Up: Use the same function as the Previous Page button
    go_to_previous_page()
    return nil
  elseif key.name == "next" then
    -- Page Down: Use the same function as the Next Page button
    go_to_next_page()
    return nil
  elseif key.name == "wheel_up" then
    -- Mouse wheel up: scroll up
    if #current_filtered_commands > MAX_VISIBLE_BUTTONS then
      current_scroll_offset = math.max(0, current_scroll_offset - 3)
      update_scrollbar()
      update_button_display(true) -- Force full refresh
    end
    return nil
  elseif key.name == "wheel_down" then
    -- Mouse wheel down: scroll down
    if #current_filtered_commands > MAX_VISIBLE_BUTTONS then
      current_scroll_offset = math.min(#current_filtered_commands - MAX_VISIBLE_BUTTONS, current_scroll_offset + 3)
      update_scrollbar()
      update_button_display(true) -- Force full refresh
    end
    return nil
  elseif key.name == "esc" then
    -- If there's text, wipe it
    if current_search_text ~= "" then
      current_search_text = ""
      update_search_display()
      update_suggestions(current_search_text)
      return nil
    end
    -- If no text, fall through to closer key check
  end
  
  -- Check for close key
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    dialog = nil
    return nil
  elseif key.name == "r" and key.modifiers and key.modifiers[1] == "shift" then
    -- Shift+R: Manual context refresh
    local old_context = current_context
    detect_current_context()
    current_search_text = ""
    update_search_display()
    update_suggestions(current_search_text)
    renoise.app():show_status("Refreshed context: " .. current_context)
    return nil
  elseif key.name == "back" then
    -- Remove last character (TRUE real-time like Command Palette)
    if #current_search_text > 0 then
      current_search_text = current_search_text:sub(1, #current_search_text - 1)
      update_search_display()
      update_suggestions(current_search_text)
    end
    return nil  -- Consume the key
  elseif key.name == "delete" then
    -- Clear all text (TRUE real-time)
    current_search_text = ""
    update_search_display()
    update_suggestions(current_search_text)
    return nil  -- Consume the key
  elseif key.name == "space" then
    -- Add space character (TRUE real-time)
    current_search_text = current_search_text .. " "
    update_search_display()
    update_suggestions(current_search_text)
    return nil  -- Consume the key
  elseif key.name == "f" and key.modifiers and key.modifiers[1] == "ctrl" then
    -- Ctrl+F: Toggle favorite for selected command
    if #current_filtered_commands > 0 and selected_suggestion_index > 0 then
      local command = current_filtered_commands[selected_suggestion_index]
      toggle_favorite(command)
      -- Force refresh to update priority reasons and display
      update_suggestions(current_search_text)
    end
    return nil
  elseif string.len(key.name) == 1 then
    -- Add typed character immediately (TRUE real-time like Command Palette)
    current_search_text = current_search_text .. key.name
    update_search_display()
    update_suggestions(current_search_text)
    return nil  -- Consume the key
  else
    -- Let other keys pass through
    return key
  end
end

-- Function to update suggestions list
update_suggestions = function(filter_text)
  current_filter = filter_text or ""
  
  -- Get filtered commands
  current_filtered_commands = filter_commands(current_filter)
  
  -- Reset scroll and selection when filter changes
  current_scroll_offset = 0
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
    if #current_filtered_commands > MAX_VISIBLE_BUTTONS then
      local showing_start = current_scroll_offset + 1
      local showing_end = math.min(current_scroll_offset + MAX_VISIBLE_BUTTONS, #current_filtered_commands)
      status_msg = status_msg .. string.format(" - Showing %d-%d (PgUp/PgDn to scroll)", showing_start, showing_end)
    end
    status_text.text = status_msg
  end
  
  -- Update button display and scrollbar
  update_button_display()
  update_scrollbar()
end

-- Function to close autocomplete dialog
function close_autocomplete_dialog()
  stop_context_monitoring()  -- Stop real-time context monitoring
  if autocomplete_dialog and autocomplete_dialog.visible then
    autocomplete_dialog:close()
    autocomplete_dialog = nil
    autocomplete_vb = nil
    search_display_text = nil
    status_text = nil
    suggestion_buttons = {}
    current_filtered_commands = {}
    current_filter = ""
    selected_suggestion_index = 0
    current_scroll_offset = 0
    create_abbrev_button = nil
    suggestions_scrollbar = nil
    prev_page_button = nil
    next_page_button = nil
  end
  
  -- Also close command picker if open
  if command_picker_dialog and command_picker_dialog.visible then
    command_picker_dialog:close()
    command_picker_dialog = nil
  end
end

-- Initialize commands ONLY when dialog opens (lazy loading)
local function initialize_paketti_commands()
  print("PakettiAutocomplete: Loading Paketti commands...")
  
  -- Try to load from cache first
  local cache_loaded = load_commands_cache()
  
  if not cache_loaded then
    print("PakettiAutocomplete: Cache not found or invalid, scanning files...")
    scan_paketti_commands()
    save_commands_cache()
  end
  
  -- Load user data
  load_user_abbreviations()
  load_usage_data()
  load_favorites()
  
  -- Load or build shortcut mappings
  local shortcuts_loaded = load_shortcut_mappings()
  if not shortcuts_loaded then
    print("PakettiAutocomplete: Shortcut cache not found, building from KeyBindings.xml...")
    build_function_shortcut_mappings()
    save_shortcut_mappings()
  end
  
  -- Build search index for fast filtering
  build_search_index()
  
  -- Detect current context
  detect_current_context()
end

-- Don't auto-initialize - only when dialog opens (lazy loading)

-- Real-time context monitoring using observable (much more efficient than timer)
local context_monitor_observable = nil
local context_notifier_func = nil

-- Function to start context monitoring
local function start_context_monitoring()
  -- Stop any existing monitoring
  stop_context_monitoring()
  
  -- Create the notifier function
  context_notifier_func = function()
    if not autocomplete_dialog or not autocomplete_dialog.visible then
      -- Dialog closed, stop monitoring
      stop_context_monitoring()
      return
    end
    
    local old_context = current_context
    detect_current_context()
    
    if current_context ~= old_context then
      -- Context changed - reload command list
      current_search_text = ""  -- Reset search
      update_search_display()
      update_suggestions(current_search_text)  -- This will use new context
      
      renoise.app():show_status("Autocomplete: " .. current_context .. " context")
    end
  end
  
  -- Monitor middle frame changes using observable
  context_monitor_observable = renoise.app().window.active_middle_frame_observable
  context_monitor_observable:add_notifier(context_notifier_func)
end

-- Function to stop context monitoring  
function stop_context_monitoring()
  if context_monitor_observable and context_notifier_func then
    if context_monitor_observable.has_notifier and context_monitor_observable:has_notifier(context_notifier_func) then
      context_monitor_observable:remove_notifier(context_notifier_func)
    end
    context_monitor_observable = nil
    context_notifier_func = nil
  end
end

-- Main dialog function
function pakettiAutocompleteDialog()
  -- Close existing dialog if open
  close_autocomplete_dialog()
  
  -- FIRST: Initialize commands (lazy loading - only when dialog opens)
  if #paketti_commands == 0 then
    initialize_paketti_commands()
  else
    -- Just detect context if commands already loaded
    detect_current_context()
  end
  
  -- DEBUG: Show sample categories to understand the data
  -- debug_show_sample_categories()
  
  -- Create fresh ViewBuilder instance
  autocomplete_vb = renoise.ViewBuilder()
  
  -- Initialize search text and load context-filtered commands
  current_search_text = ""
  current_filtered_commands = get_smart_ordered_commands()  -- This now filters by context
  
  -- Create fixed suggestion buttons (now supports 30)
  suggestion_buttons = {}
  local suggestion_views = {}
  
  for i = 1, MAX_VISIBLE_BUTTONS do
    local button_text = ""
    local button_visible = false
    
    local command_index = i + current_scroll_offset
    if command_index <= #current_filtered_commands then
      local command = current_filtered_commands[command_index]
      button_text = string.format("[%s] %s%s", get_display_category(command), get_clean_command_name(command), get_command_shortcut(command))
      button_visible = true
    end
    
    -- Determine button color based on whether command has shortcuts
    local button_color = {0x00, 0x00, 0x00} -- Default black
    if command_index <= #current_filtered_commands then
      local command = current_filtered_commands[command_index]
      if command and get_command_shortcut(command) ~= "" then
        button_color = {0x00, 0x80, 0x00} -- Dark green for commands with shortcuts
      end
    end
    
    suggestion_buttons[i] = autocomplete_vb:button{
      text = button_text,
      width = BUTTON_WIDTH,
      height = 18,
      align = "left",
      visible = button_visible,
      color = button_color,
      notifier = function()
        handle_suggestion_click(i + current_scroll_offset)
      end
    }
    
    table.insert(suggestion_views, suggestion_buttons[i])
  end
  
  -- Create the "create abbreviation" button (initially hidden)
  create_abbrev_button = autocomplete_vb:button{
    text = "Create abbreviation",
    width = BUTTON_WIDTH,
    height = 22,
    align = "left",
    visible = false,
    notifier = function()
      if current_filter and current_filter ~= "" then
        show_command_picker(current_filter)
      end
    end
  }
  
  -- Create dialog content
  local dialog_content = autocomplete_vb:column{    
    autocomplete_vb:row{
      autocomplete_vb:text{
        text = "Type command:",
        width = SEARCH_LABEL_WIDTH
      },
      (function()
        search_display_text = autocomplete_vb:text{
          width = SEARCH_FIELD_WIDTH,
          text = "'" .. current_search_text .. "'",
          style = "strong"
        }
        return search_display_text
      end)()
    },
    
    autocomplete_vb:row{
      autocomplete_vb:text{
        text = "Suggestions:",
        style = "strong",
        width = 200
      },
      (function()
        status_text = autocomplete_vb:text{
          text = string.format("(%d matches)", #paketti_commands),
          style = "disabled",
          width = 200
        }
        return status_text
      end)()
    },
    
    
    -- Container for suggestions with scrollbar and page buttons
    autocomplete_vb:row{
      -- Suggestions column
      autocomplete_vb:column(suggestion_views),
      -- Scrollbar and navigation column
      autocomplete_vb:column{
        spacing = 2,
        -- Previous page button
        (function()
          prev_page_button = autocomplete_vb:button{
            text = "▲",
            width = SCROLLBAR_WIDTH,
            height = 20,
            visible = false,
            active = false,
            notifier = go_to_previous_page
          }
          return prev_page_button
        end)(),
        -- Scrollbar
        (function()
          suggestions_scrollbar = autocomplete_vb:scrollbar{
            min = 0,
            max = 100,
            value = 0,
            pagestep = MAX_VISIBLE_BUTTONS,
            step = 1,
            width = SCROLLBAR_WIDTH,
            height = MAX_VISIBLE_BUTTONS * 18 - 44, -- Subtract button heights
            visible = false, -- Initially hidden
            notifier = function(new_value)
              current_scroll_offset = new_value
              update_button_display(true) -- Force full refresh when scrollbar moves
            end
          }
          return suggestions_scrollbar
        end)(),
        -- Next page button
        (function()
          next_page_button = autocomplete_vb:button{
            text = "▼",
            width = SCROLLBAR_WIDTH,
            height = 20,
            visible = false,
            active = false,
            notifier = go_to_next_page
          }
          return next_page_button
        end)()
      }
    },
    
    -- Create abbreviation button (shown when no matches)
    create_abbrev_button,

    autocomplete_vb:row{
      autocomplete_vb:button{
        text = "Rebuild Cache",
        width = 110,
        notifier = pakettiAutocompleteRebuildCache
      },
      autocomplete_vb:space{width = 5},
      autocomplete_vb:button{
        text = "Nuke Cache",
        width = 110,
        notifier = pakettiAutocompleteNukeCache
      },
      autocomplete_vb:space{width = 5},
      autocomplete_vb:button{
        text = "Reset Usage",
        width = 110,
        notifier = pakettiAutocompleteResetUsage
      },
      autocomplete_vb:space{width = 5},
      autocomplete_vb:button{
        text = "Close Window",
        width = 110,
        notifier = close_autocomplete_dialog
      },
      autocomplete_vb:space{width = 5},
      autocomplete_vb:text{
        text = string.format("(%d commands available)", #paketti_commands),
        style = "disabled",
        width = 120
      }
    },
    
    autocomplete_vb:row{
      (function()
        show_only_with_shortcuts_checkbox = autocomplete_vb:checkbox{
          value = false,
          notifier = function(value)
            -- Refresh the command list when checkbox changes
            current_filtered_commands = get_smart_ordered_commands()
            update_suggestions(current_search_text)
          end
        }
        return show_only_with_shortcuts_checkbox
      end)(),
      autocomplete_vb:space{width = 5},
      autocomplete_vb:text{
        text = "Show only commands with shortcuts",
        width = 250
      }
    }
  }
  
  -- Create and show dialog
  autocomplete_dialog = renoise.app():show_custom_dialog(
    "Paketti Function Search", 
    dialog_content,
    autocomplete_keyhandler
  )
  
  -- Start real-time context monitoring
  start_context_monitoring()
  
  -- Set initial selection and update display (no textfield, show initial results)
  selected_suggestion_index = 0
  update_search_display()  -- Initialize search display
  update_suggestions(current_search_text)  -- Show initial results
  
  -- Set focus to Renoise after dialog opens for key capture
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
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

-- Function to show command picker dialog for creating abbreviations (with real-time search)
function show_command_picker(abbreviation_text)
  if command_picker_dialog and command_picker_dialog.visible then
    command_picker_dialog:close()
    return
  end
  
  local picker_vb = renoise.ViewBuilder()
  local command_buttons = {}
  local filtered_picker_commands = paketti_commands
  local picker_search_text = ""
  local picker_selected_index = 0
  local picker_scroll_offset = 0
  local picker_search_display = nil
  local picker_status_text = nil
  local picker_scrollbar = nil
  local MAX_PICKER_BUTTONS = 20
  
  local function update_picker_display()
    for i = 1, MAX_PICKER_BUTTONS do
      if command_buttons[i] then
        local command_index = i + picker_scroll_offset
        if command_index <= #filtered_picker_commands then
          local command = filtered_picker_commands[command_index]
          local button_text = string.format("[%s] %s%s", get_display_category(command), get_clean_command_name(command), get_command_shortcut(command))
          
          command_buttons[i].text = button_text
          command_buttons[i].visible = true
          
          -- Use purple coloring for selected item, dark green for shortcuts
          if command_index == picker_selected_index then
            command_buttons[i].color = {0x80, 0x00, 0x80} -- Deep purple (selected) - highest priority
          elseif get_command_shortcut(command) ~= "" then
            command_buttons[i].color = {0x00, 0x80, 0x00} -- Dark green (has shortcut)
          else
            command_buttons[i].color = {0x00, 0x00, 0x00} -- Default color (unselected)
          end
        else
          command_buttons[i].visible = false
        end
      end
    end
    
    -- Update status
    if picker_status_text then
      local status_msg = string.format("(%d matches)", #filtered_picker_commands)
      if picker_search_text ~= "" then
        status_msg = string.format("'%s' - %d matches", picker_search_text, #filtered_picker_commands)
      end
      if #filtered_picker_commands > MAX_PICKER_BUTTONS then
        local showing_start = picker_scroll_offset + 1
        local showing_end = math.min(picker_scroll_offset + MAX_PICKER_BUTTONS, #filtered_picker_commands)
        status_msg = status_msg .. string.format(" - Showing %d-%d", showing_start, showing_end)
      end
      picker_status_text.text = status_msg
    end
  end
  
  local function filter_picker_commands(filter_text)
    if not filter_text or filter_text == "" then
      filtered_picker_commands = paketti_commands
    else
      filtered_picker_commands = {}
      local filter_lower = string.lower(filter_text)
      for _, command in ipairs(paketti_commands) do
        if string.find(string.lower(command.name), filter_lower, 1, true) or 
           string.find(string.lower(command.category), filter_lower, 1, true) then
          table.insert(filtered_picker_commands, command)
        end
      end
    end
    
    -- Reset selection and scroll
    picker_selected_index = 0
    picker_scroll_offset = 0
    update_picker_display()
    update_picker_scrollbar()
  end
  
  function update_picker_scrollbar()
    if picker_scrollbar then
      local commands_count = #filtered_picker_commands
      if commands_count <= MAX_PICKER_BUTTONS then
        -- No scrolling needed - hide scrollbar
        picker_scrollbar.visible = false
      else
        -- Scrolling needed - show and configure scrollbar
        picker_scrollbar.visible = true
        picker_scrollbar.min = 0
        picker_scrollbar.max = commands_count
        picker_scrollbar.pagestep = MAX_PICKER_BUTTONS
        picker_scrollbar.step = 1
        picker_scrollbar.value = picker_scroll_offset
      end
    end
  end
  
  local function ensure_picker_selection_visible()
    if picker_selected_index <= 0 or #filtered_picker_commands == 0 then
      picker_scroll_offset = 0
      update_picker_scrollbar()
      return
    end
    
    -- If selection is above visible area, scroll up
    if picker_selected_index <= picker_scroll_offset then
      picker_scroll_offset = picker_selected_index - 1
      if picker_scroll_offset < 0 then
        picker_scroll_offset = 0
      end
    end
    
    -- If selection is below visible area, scroll down
    if picker_selected_index > picker_scroll_offset + MAX_PICKER_BUTTONS then
      picker_scroll_offset = picker_selected_index - MAX_PICKER_BUTTONS
    end
    
    update_picker_scrollbar()
  end
  
  local function execute_picker_selection()
    if picker_selected_index > 0 and picker_selected_index <= #filtered_picker_commands then
      local selected_command = filtered_picker_commands[picker_selected_index]
      
      -- Create the abbreviation
      user_abbreviations[string.lower(abbreviation_text)] = selected_command.name
      save_user_abbreviations()
      
      renoise.app():show_status(string.format("Added abbreviation: '%s' → '%s'", 
        abbreviation_text, selected_command.name))
      
      -- Close picker dialog
      command_picker_dialog:close()
      command_picker_dialog = nil
      
      -- Update the autocomplete with the new abbreviation
      update_suggestions(current_search_text)
    end
  end
  
  -- Real-time keyhandler for picker dialog (like main autocomplete)
  local function picker_keyhandler(dialog, key)
    if key.name == "return" then
      if picker_selected_index > 0 then
        execute_picker_selection()
      elseif #filtered_picker_commands > 0 then
        picker_selected_index = 1
        ensure_picker_selection_visible()
        update_picker_display()
      end
      return nil
    elseif key.name == "up" then
      if #filtered_picker_commands > 0 then
        if picker_selected_index <= 1 then
          picker_selected_index = #filtered_picker_commands -- Wrap to bottom
        else
          picker_selected_index = picker_selected_index - 1
        end
        ensure_picker_selection_visible()
        update_picker_display()
      end
      return nil
    elseif key.name == "down" then
      if #filtered_picker_commands > 0 then
        if picker_selected_index == 0 then
          picker_selected_index = 1
        else
          picker_selected_index = picker_selected_index + 1
          if picker_selected_index > #filtered_picker_commands then
            picker_selected_index = 1 -- Wrap to top
          end
        end
        ensure_picker_selection_visible()
        update_picker_display()
      end
      return nil
    elseif key.name == "esc" then
      command_picker_dialog:close()
      command_picker_dialog = nil
      return nil
    elseif key.name == "wheel_up" then
      -- Mouse wheel up: scroll up
      if #filtered_picker_commands > MAX_PICKER_BUTTONS then
        picker_scroll_offset = math.max(0, picker_scroll_offset - 3)
        update_picker_scrollbar()
        update_picker_display() -- Picker always does full refresh
      end
      return nil
    elseif key.name == "wheel_down" then
      -- Mouse wheel down: scroll down
      if #filtered_picker_commands > MAX_PICKER_BUTTONS then
        picker_scroll_offset = math.min(#filtered_picker_commands - MAX_PICKER_BUTTONS, picker_scroll_offset + 3)
        update_picker_scrollbar()
        update_picker_display() -- Picker always does full refresh
      end
      return nil
    elseif key.name == "back" then
      -- Remove last character (real-time like main autocomplete)
      if #picker_search_text > 0 then
        picker_search_text = picker_search_text:sub(1, #picker_search_text - 1)
        picker_search_display.text = "'" .. picker_search_text .. "'"
        filter_picker_commands(picker_search_text)
      end
      return nil
    elseif key.name == "delete" then
      -- Clear all text
      picker_search_text = ""
      picker_search_display.text = "'" .. picker_search_text .. "'"
      filter_picker_commands(picker_search_text)
      return nil
    elseif key.name == "space" then
      -- Add space character
      picker_search_text = picker_search_text .. " "
      picker_search_display.text = "'" .. picker_search_text .. "'"
      filter_picker_commands(picker_search_text)
      return nil
    elseif string.len(key.name) == 1 then
      -- Add typed character immediately (real-time)
      picker_search_text = picker_search_text .. key.name
      picker_search_display.text = "'" .. picker_search_text .. "'"
      filter_picker_commands(picker_search_text)
      return nil
    else
      return key
    end
  end
  
  -- Create command selection buttons
  for i = 1, MAX_PICKER_BUTTONS do
    local button = picker_vb:button{
      text = "",
      width = BUTTON_WIDTH,
      height = 18,
      align = "left",
      visible = false,
      color = {0x00, 0x00, 0x00}, -- Default color (needed for dynamic color changes)
      notifier = function()
        local command_index = i + picker_scroll_offset
        if command_index <= #filtered_picker_commands then
          picker_selected_index = command_index
          execute_picker_selection()
        end
      end
    }
    table.insert(command_buttons, button)
  end
  
  -- Create the picker dialog content
  local picker_content = picker_vb:column{
    margin = 8,
    spacing = 4,
    picker_vb:text{
      text = string.format("Create abbreviation for '%s'", abbreviation_text),
      style = "strong",
      width = DIALOG_WIDTH
    },
    
    picker_vb:row{
      picker_vb:text{
        text = "Type to search:",
        width = 100
      },
      (function()
        picker_search_display = picker_vb:text{
          text = "''",
          style = "strong",
          width = DIALOG_WIDTH - 100
        }
        return picker_search_display
      end)()
    },
    
    (function()
      picker_status_text = picker_vb:text{
        text = string.format("(%d matches)", #paketti_commands),
        style = "disabled",
        width = DIALOG_WIDTH
      }
      return picker_status_text
    end)(),
    
    picker_vb:space{height = 8},
    -- Command buttons with scrollbar
    picker_vb:row{
      -- Commands column
      picker_vb:column{
        spacing = 2,
        unpack(command_buttons)
      },
      -- Scrollbar column
      (function()
        picker_scrollbar = picker_vb:scrollbar{
          min = 0,
          max = 100,
          value = 0,
          pagestep = MAX_PICKER_BUTTONS,
          step = 1,
          width = SCROLLBAR_WIDTH,
          height = MAX_PICKER_BUTTONS * 18, -- Match height of buttons
          visible = false, -- Initially hidden
          notifier = function(new_value)
            picker_scroll_offset = new_value
            update_picker_display() -- Picker always does full refresh
          end
        }
        return picker_scrollbar
      end)()
    },
    picker_vb:space{height = 8},
    picker_vb:row{
      picker_vb:button{
        text = "Cancel",
        width = 80,
        
        notifier = function()
          command_picker_dialog:close()
          command_picker_dialog = nil
        end
      }
    }
  }
  
  -- Initialize the display
  filter_picker_commands("")
  update_picker_scrollbar()
  
  -- Show the picker dialog with keyhandler
  command_picker_dialog = renoise.app():show_custom_dialog(
    "Select Command for Abbreviation",
    picker_content,
    picker_keyhandler
  )
  
  -- Set focus to Renoise for key capture
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Function to add a custom abbreviation
function pakettiAutocompleteAddAbbreviation()
  local result = renoise.app():show_prompt("Add Custom Abbreviation", 
    "Enter abbreviation=full_command\n(e.g., rts=render to sample, sst=Selected Sample +36 Transpose)", "")
  if result and result ~= "" then
    local abbrev, full_command = result:match("^([^=]+)=(.+)$")
    if abbrev and full_command then
      user_abbreviations[string.lower(abbrev:match("^%s*(.-)%s*$"))] = full_command:match("^%s*(.-)%s*$")
      save_user_abbreviations()
      renoise.app():show_status("Added abbreviation: " .. abbrev .. " = " .. full_command)
    else
      renoise.app():show_status("Invalid format. Use: abbreviation=full_command")
    end
  end
end

-- Function to nuke cache completely
function pakettiAutocompleteNukeCache()
  -- Remove cache files
  os.remove(cache_file_path)
  -- Clear in-memory commands to force fresh scan
  paketti_commands = {}
  -- Clear search index
  search_index = {}
  
  -- If dialog is open, update display
  if autocomplete_dialog and autocomplete_dialog.visible then
    current_filtered_commands = {}
    update_button_display(true)
    if status_text then
      status_text.text = "Cache nuked - commands cleared"
    end
  end
  
  renoise.app():show_status("Autocomplete cache nuked. Commands cleared.")
end

-- Function to rebuild cache from scratch
function pakettiAutocompleteRebuildCache()
  -- Clear everything first
  paketti_commands = {}
  search_index = {}
  function_shortcut_mappings = {}
  os.remove(cache_file_path)
  os.remove(shortcut_cache_file_path)
  
  -- Rebuild from scratch
  print("PakettiAutocomplete: Rebuilding cache from scratch...")
  scan_paketti_commands()
  save_commands_cache()
  build_function_shortcut_mappings()
  save_shortcut_mappings()
  build_search_index()
  
  -- If dialog is open, refresh display
  if autocomplete_dialog and autocomplete_dialog.visible then
    current_search_text = ""
    update_search_display()
    update_suggestions(current_search_text)
  end
  
  renoise.app():show_status("Autocomplete cache rebuilt: " .. #paketti_commands .. " commands loaded")
end

-- Function to reset usage statistics
function pakettiAutocompleteResetUsage()
  -- Clear usage data
  command_usage_count = {}
  recent_commands = {}
  favorite_commands = {}
  
  -- Remove usage files
  os.remove(usage_file_path)
  os.remove(favorites_file_path)
  
  -- If dialog is open, refresh the display
  if autocomplete_dialog and autocomplete_dialog.visible then
    current_search_text = ""
    update_search_display()
    update_suggestions(current_search_text)
  end
  
  renoise.app():show_status("Usage statistics reset. All commands now have equal priority.")
end

-- Debug function to show sample categories
function debug_show_sample_categories()
  print("=== SAMPLE OF ALL CATEGORIES ===")
  local categories_shown = {}
  local count = 0
  
  for _, command in ipairs(paketti_commands) do
    if not categories_shown[command.category] and count < 20 then
      print("Category: " .. command.category)
      categories_shown[command.category] = true
      count = count + 1
    end
  end
  print("=== END SAMPLE CATEGORIES ===")
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Paketti Function Search...", invoke=pakettiAutocompleteToggle}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Paketti Function Search...", invoke=pakettiAutocompleteToggle}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Function Search Debug:Add Autocomplete Abbreviation...", invoke=pakettiAutocompleteAddAbbreviation}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Function Search Debug:Reset Autocomplete Usage Statistics", invoke=pakettiAutocompleteResetUsage}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Function Search Debug:Nuke Autocomplete Cache", invoke=pakettiAutocompleteNukeCache}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Function Search Debug:Rebuild Autocomplete Cache", invoke=pakettiAutocompleteRebuildCache}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Function Search Debug:Debug Autocomplete Search", invoke=function() 
  local search_text = renoise.app():show_prompt("Debug Autocomplete", "Enter search text to debug:", "duplicate all")
  if search_text and search_text ~= "" then 
    debug_multi_word_search(search_text) 
  end 
end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti Gadgets:Paketti Function Search...", invoke=pakettiAutocompleteToggle}
renoise.tool():add_menu_entry{name="Mixer:Paketti Gadgets:Paketti Function Search...", invoke=pakettiAutocompleteToggle}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti Gadgets:Paketti Function Search...", invoke=pakettiAutocompleteToggle}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti Gadgets:Paketti Function Search...", invoke=pakettiAutocompleteToggle}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Function Search...", invoke=pakettiAutocompleteToggle}
renoise.tool():add_keybinding{name="Global:Paketti:Add Autocomplete Abbreviation", invoke=pakettiAutocompleteAddAbbreviation}
renoise.tool():add_keybinding{name="Global:Paketti:Reset Autocomplete Usage Statistics", invoke=pakettiAutocompleteResetUsage}
renoise.tool():add_keybinding{name="Global:Paketti:Nuke Autocomplete Cache", invoke=pakettiAutocompleteNukeCache}
renoise.tool():add_keybinding{name="Global:Paketti:Rebuild Autocomplete Cache", invoke=pakettiAutocompleteRebuildCache}
renoise.tool():add_keybinding{name="Global:Paketti:Debug Autocomplete Search", invoke=function() 
  local search_text = renoise.app():show_prompt("Debug Autocomplete", "Enter search text to debug:", "duplicate all")
  if search_text and search_text ~= "" then 
    debug_multi_word_search(search_text) 
  end 
end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Paketti Function Search...", invoke=pakettiAutocompleteToggle}
renoise.tool():add_keybinding{name="Mixer:Paketti:Paketti Function Search...", invoke=pakettiAutocompleteToggle}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Function Search...", invoke=function(message) if message:is_trigger() then pakettiAutocompleteToggle() end end}

-- Test function to show shortcut mappings are working
function pakettiTestShortcutMappings()
  -- Force load shortcut mappings if not already loaded
  if next(function_shortcut_mappings) == nil then
    local shortcuts_loaded = load_shortcut_mappings()
    if not shortcuts_loaded then
      build_function_shortcut_mappings()
      save_shortcut_mappings()
    end
  end
  
  -- Show some sample mappings
  local sample_count = 0
  local sample_text = "Sample function-shortcut mappings:\n\n"
  
  -- Show Paketti-related mappings first
  for functionName, shortcut in pairs(function_shortcut_mappings) do
    if sample_count < 15 and functionName:find("Paketti") then
      sample_text = sample_text .. functionName .. " -> " .. shortcut .. "\n"
      sample_count = sample_count + 1
    end
  end
  
  if sample_count == 0 then
    sample_text = "No shortcut mappings found. Try rebuilding the autocomplete cache."
  else
    local total_count = 0
    for _ in pairs(function_shortcut_mappings) do
      total_count = total_count + 1
    end
    sample_text = sample_text .. "\nTotal mappings: " .. total_count
    
    -- Also check what a sample autocomplete command looks like
    if #paketti_commands > 0 then
      sample_text = sample_text .. "\n\nSample autocomplete command names:\n"
      local cmd_count = 0
      for _, cmd in ipairs(paketti_commands) do
        if cmd_count < 5 and cmd.name and cmd.name:find("Function Search") then
          sample_text = sample_text .. "'" .. cmd.name .. "' (category: " .. (cmd.category or "nil") .. ")\n"
          
          -- Test the shortcut function
          local shortcut_result = get_command_shortcut(cmd)
          sample_text = sample_text .. "  -> get_command_shortcut result: '" .. shortcut_result .. "'\n"
          cmd_count = cmd_count + 1
        end
      end
    end
  end
  
  renoise.app():show_message(sample_text)
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Test Shortcut Mappings...", invoke=pakettiTestShortcutMappings}

-- Debug function to find what's causing the "Command + D" issue
function pakettiDebugCommandDMappings()
  -- Force load shortcut mappings if not already loaded
  if next(function_shortcut_mappings) == nil then
    local shortcuts_loaded = load_shortcut_mappings()
    if not shortcuts_loaded then
      build_function_shortcut_mappings()
      save_shortcut_mappings()
    end
  end
  
  local cmd_d_mappings = {}
  local all_shortcuts = {}
  local total_mappings = 0
  
  for mapping_key, shortcut in pairs(function_shortcut_mappings) do
    total_mappings = total_mappings + 1
    if shortcut:find("CMD + D") or shortcut:find("Command + D") or shortcut == "D" or shortcut:find(" D") then
      table.insert(cmd_d_mappings, {key = mapping_key, shortcut = shortcut})
    end
    
    -- Count all unique shortcuts
    if not all_shortcuts[shortcut] then
      all_shortcuts[shortcut] = 0
    end
    all_shortcuts[shortcut] = all_shortcuts[shortcut] + 1
  end
  
  -- Also show most common shortcuts
  local common_shortcuts = {}
  for shortcut, count in pairs(all_shortcuts) do
    if count > 5 then -- Show shortcuts that appear more than 5 times
      table.insert(common_shortcuts, {shortcut = shortcut, count = count})
    end
  end
  
  print("\n=== CMD+D MAPPINGS DEBUG ===")
  print("Mappings with 'CMD + D' or 'Command + D' shortcut (" .. #cmd_d_mappings .. " out of " .. total_mappings .. "):")
  
  for i, mapping in ipairs(cmd_d_mappings) do
    if i <= 10 then  -- Show first 10
      print(i .. ": " .. mapping.key .. " -> " .. mapping.shortcut)
    else
      print("... and " .. (#cmd_d_mappings - 10) .. " more")
      break
    end
  end
  
  -- Also show most common shortcuts
  if #common_shortcuts > 0 then
    print("\nMost common shortcuts:")
    for i, item in ipairs(common_shortcuts) do
      if i <= 10 then
        print(item.shortcut .. " (" .. item.count .. " times)")
      end
    end
  end
  
  print("=== END CMD+D DEBUG ===\n")
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Function Search Debug:Debug Command+D Mappings...", invoke=pakettiDebugCommandDMappings}

-- Debug function to trace the exact matching logic issue
function pakettiDebugMatchingLogic()
  -- Force load shortcut mappings and commands
  if next(function_shortcut_mappings) == nil then
    local shortcuts_loaded = load_shortcut_mappings()
    if not shortcuts_loaded then
      build_function_shortcut_mappings()
      save_shortcut_mappings()
    end
  end
  
  if #paketti_commands == 0 then
    renoise.app():show_message("No commands loaded yet. Open autocomplete first.")
    return
  end
  
  -- Test with a sample command
  local test_command = nil
  for _, cmd in ipairs(paketti_commands) do
    if cmd.name and cmd.name:find("BPM") then
      test_command = cmd
      break
    end
  end
  
  if not test_command then
    renoise.app():show_message("No BPM command found for testing")
    return
  end
  
  local debug_text = "Testing matching logic with command: '" .. test_command.name .. "'\n\n"
  
  -- Check what matches
  local matches = {}
  for mapping_key, shortcut in pairs(function_shortcut_mappings) do
    if mapping_key:find(test_command.name, 1, true) then
      table.insert(matches, {key = mapping_key, shortcut = shortcut})
      if #matches <= 5 then -- Show first 5 matches
        debug_text = debug_text .. "MATCH " .. #matches .. ": '" .. mapping_key .. "' -> " .. shortcut .. "\n"
      end
    end
  end
  
  debug_text = debug_text .. "\nTotal matches: " .. #matches .. "\n"
  
  if #matches > 0 then
    debug_text = debug_text .. "\nFirst match would return: [" .. matches[1].shortcut .. "]\n"
  else
    debug_text = debug_text .. "\nNo matches found\n"
  end
  
  -- Also show some sample mapping keys for reference
  debug_text = debug_text .. "\nSample mapping keys (first 5):\n"
  local count = 0
  for mapping_key, shortcut in pairs(function_shortcut_mappings) do
    if count < 5 then
      debug_text = debug_text .. (count + 1) .. ": '" .. mapping_key .. "' -> " .. shortcut .. "\n"
      count = count + 1
    else
      break
    end
  end
  
  renoise.app():show_message(debug_text)
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Function Search Debug:Debug Matching Logic...", invoke=pakettiDebugMatchingLogic}

-- Debug function to trace the ACTUAL autocomplete display issue
function pakettiDebugAutocompleteShortcuts()
  -- Make sure everything is loaded
  if #paketti_commands == 0 then
    renoise.app():show_message("No commands loaded yet. Open autocomplete first.")
    return
  end
  
  if next(function_shortcut_mappings) == nil then
    local shortcuts_loaded = load_shortcut_mappings()
    if not shortcuts_loaded then
      build_function_shortcut_mappings()
      save_shortcut_mappings()
    end
  end
  
  local debug_text = "AUTOCOMPLETE SHORTCUT DEBUG:\n\n"
  
  -- Test with actual commands from the autocomplete
  local test_commands = {}
  for i, cmd in ipairs(paketti_commands) do
    if i <= 5 and cmd.name then  -- Test with first 5 commands
      table.insert(test_commands, cmd)
    end
  end
  
  debug_text = debug_text .. "Testing with " .. #test_commands .. " sample commands:\n\n"
  
  for i, cmd in ipairs(test_commands) do
    debug_text = debug_text .. i .. ". Command: '" .. cmd.name .. "'\n"
    debug_text = debug_text .. "   Category: " .. (cmd.category or "nil") .. "\n"
    
    -- Call the actual function that autocomplete uses
    local shortcut_result = get_command_shortcut(cmd)
    debug_text = debug_text .. "   get_command_shortcut() returned: '" .. shortcut_result .. "'\n"
    
    -- Show what the button text would be
    local button_text = string.format("[%s] %s%s", cmd.category or "Unknown", cmd.name, shortcut_result)
    debug_text = debug_text .. "   Button text: " .. button_text .. "\n\n"
  end
  
  -- Show mapping count and some examples
  local mapping_count = 0
  for _ in pairs(function_shortcut_mappings) do mapping_count = mapping_count + 1 end
  debug_text = debug_text .. "Total shortcut mappings: " .. mapping_count .. "\n\n"
  
  -- Show first few mappings
  debug_text = debug_text .. "Sample mappings:\n"
  local shown = 0
  for mapping_key, shortcut in pairs(function_shortcut_mappings) do
    if shown < 5 then
      debug_text = debug_text .. (shown + 1) .. ": '" .. mapping_key .. "' -> '" .. shortcut .. "'\n"
      shown = shown + 1
    else
      break
    end
  end
  
  renoise.app():show_message(debug_text)
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Function Search Debug:Debug Autocomplete Shortcuts...", invoke=pakettiDebugAutocompleteShortcuts}

-- Debug function to show actual mapping contents
function pakettiShowMappingContents()
  if next(function_shortcut_mappings) == nil then
    local shortcuts_loaded = load_shortcut_mappings()
    if not shortcuts_loaded then
      build_function_shortcut_mappings()
      save_shortcut_mappings()
    end
  end
  
  print("\n=== MAPPING CONTENTS DEBUG ===")
  local count = 0
  local total = 0
  for _ in pairs(function_shortcut_mappings) do total = total + 1 end
  
  print("Total mappings: " .. total)
  print("\nFirst 20 mappings:")
  
  -- Show first 20 mappings with full details
  for mapping_key, shortcut in pairs(function_shortcut_mappings) do
    if count < 20 then
      print((count + 1) .. ": '" .. mapping_key .. "' -> '" .. shortcut .. "'")
      count = count + 1
    else
      break
    end
  end
  
  if count == 0 then
    print("No mappings found!")
  end
  
  print("=== END MAPPING CONTENTS ===\n")
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:!Preferences:Function Search Debug:Show Mapping Contents...", invoke=pakettiShowMappingContents}

-- Debug function to analyze multi-word search issues
function debug_multi_word_search(search_text)
  if not search_text or search_text == "" then
    print("DEBUG: Empty search text")
    return
  end
  
  print("=== DEBUG MULTI-WORD SEARCH ===")
  print("Search text: '" .. search_text .. "'")
  
  -- Split into terms like the real search does
  local search_terms = {}
  local filter_lower = string.lower(search_text)
  for term in filter_lower:gmatch("%S+") do
    table.insert(search_terms, term)
  end
  
  print("Split into " .. #search_terms .. " terms: [" .. table.concat(search_terms, ", ") .. "]")
  
  -- Check each term individually
  for term_idx, term in ipairs(search_terms) do
    print("\n--- TERM " .. term_idx .. ": '" .. term .. "' ---")
    local matches = {}
    
    for i, command in ipairs(paketti_commands) do
      local name_lower = string.lower(command.name)
      local category_lower = string.lower(command.category)
      
      -- Check name match
      if string.find(name_lower, term, 1, true) then
        table.insert(matches, {index = i, name = command.name, match_type = "name"})
      -- Check category match  
      elseif string.find(category_lower, term, 1, true) then
        table.insert(matches, {index = i, name = command.name, match_type = "category"})
      else
        -- Check abbreviation match
        for _, abbrev in ipairs(command.abbreviations) do
          if string.find(abbrev:lower(), term, 1, true) then
            table.insert(matches, {index = i, name = command.name, match_type = "abbreviation"})
            break
          end
        end
      end
    end
    
    print("Found " .. #matches .. " matches for '" .. term .. "':")
    for i = 1, math.min(10, #matches) do -- Show first 10 matches
      local match = matches[i]
      print("  " .. i .. ". [" .. match.match_type .. "] " .. match.name)
    end
    if #matches > 10 then
      print("  ... and " .. (#matches - 10) .. " more")
    end
  end
  
  -- Now show intersection logic
  if #search_terms > 1 then
    print("\n--- INTERSECTION ANALYSIS ---")
    local candidate_indices = {}
    
    for term_idx, term in ipairs(search_terms) do
      local term_candidates = {}
      
      for i, command in ipairs(paketti_commands) do
        local name_lower = string.lower(command.name)
        local category_lower = string.lower(command.category)
        
        if string.find(name_lower, term, 1, true) or string.find(category_lower, term, 1, true) then
          term_candidates[i] = true
        end
        
        for _, abbrev in ipairs(command.abbreviations) do
          if string.find(abbrev:lower(), term, 1, true) then
            term_candidates[i] = true
            break
          end
        end
      end
      
      print("Term '" .. term .. "' matches " .. table_length(term_candidates) .. " commands")
      
      -- Apply intersection
      if next(candidate_indices) then
        local intersection = {}
        for idx in pairs(candidate_indices) do
          if term_candidates[idx] then
            intersection[idx] = true
          end
        end
        candidate_indices = intersection
        print("After intersection with previous terms: " .. table_length(candidate_indices) .. " commands remain")
      else
        candidate_indices = term_candidates
        print("First term - using all matches")
      end
    end
    
    print("\nFINAL INTERSECTION: " .. table_length(candidate_indices) .. " commands")
    local final_matches = {}
    for idx in pairs(candidate_indices) do
      table.insert(final_matches, paketti_commands[idx])
    end
    
    for i = 1, math.min(5, #final_matches) do
      print("  " .. i .. ". " .. final_matches[i].name)
    end
  end
  
  print("=== END DEBUG ===")
end

-- Helper function to count table entries
function table_length(tbl)
  local count = 0
  for _ in pairs(tbl) do count = count + 1 end
  return count
end

-- Initialize commands when module loads
--initialize_paketti_commands()



