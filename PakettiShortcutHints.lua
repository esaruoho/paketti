-- PakettiShortcutHints.lua
-- Matches menu entries to keybinding shortcuts using TWO methods:
--   1. Function code matching via autocomplete_cache.txt (connects different-named pairs)
--   2. Display name suffix matching (fallback for anything the cache misses)
-- Result: PakettiShortcutHintsTable[menu_entry_name] = " [Opt+K]"

PakettiShortcutHintsTable = {}

local function abbreviateModifiers(key_string)
  local result = key_string
  result = result:gsub("Command", "Cmd")
  result = result:gsub("Option", "Opt")
  result = result:gsub("Control", "Ctrl")
  result = result:gsub(" %+ ", "+")
  return result
end

local function getKeyBindingsPath()
  local os_name = os.platform()
  local renoise_version = renoise.RENOISE_VERSION:match("(%d+%.%d+%.%d+)")
  if os_name == "WINDOWS" then
    local home = os.getenv("USERPROFILE") or os.getenv("HOME")
    return home .. "\\AppData\\Roaming\\Renoise\\V" .. renoise_version .. "\\KeyBindings.xml"
  elseif os_name == "MACINTOSH" then
    local home = os.getenv("HOME")
    return home .. "/Library/Preferences/Renoise/V" .. renoise_version .. "/KeyBindings.xml"
  else
    local home = os.getenv("HOME")
    return home .. "/.config/Renoise/V" .. renoise_version .. "/KeyBindings.xml"
  end
end

-- Step 1: Parse KeyBindings.xml
-- Returns TWO tables:
--   kb_full_name_shortcuts: "Global:Paketti:Show Paketti Preferences..." -> "Shift+Cmd+,"
--   kb_display_shortcuts:   "Show Paketti Preferences..." -> "Shift+Cmd+,"
local function parseKeyBindings()
  local kb_full = {}
  local kb_display = {}

  local path = getKeyBindingsPath()
  if not path then return kb_full, kb_display end

  local file = io.open(path, "r")
  if not file then
    print("PakettiShortcutHints: Could not open " .. tostring(path))
    return kb_full, kb_display
  end

  local content = file:read("*all")
  file:close()

  for categorySection in content:gmatch("<Category>(.-)</Category>") do
    local identifier = categorySection:match("<Identifier>(.-)</Identifier>") or ""

    for kbSection in categorySection:gmatch("<KeyBinding>(.-)</KeyBinding>") do
      local topic = kbSection:match("<Topic>(.-)</Topic>")
      local binding = kbSection:match("<Binding>(.-)</Binding>")
      local key = kbSection:match("<Key>(.-)</Key>")

      if topic and topic:find("Paketti") and binding and key and key ~= "" then
        topic = topic:gsub("&amp;", "&")
        binding = binding:gsub("&amp;", "&")
        key = key:gsub("&amp;", "&")

        local display_name = binding:match("^∿ (.+)") or binding
        local full_name = identifier .. ":" .. topic .. ":" .. display_name
        local abbrev = abbreviateModifiers(key)

        kb_full[full_name] = abbrev
        kb_display[display_name] = abbrev
      end
    end
  end

  local count = 0
  for _ in pairs(kb_full) do count = count + 1 end
  print("PakettiShortcutHints: Parsed " .. count .. " keybinding shortcuts from KeyBindings.xml")
  return kb_full, kb_display
end

-- Step 2: Parse autocomplete_cache.txt, match menu entries to keybindings by function code
local function matchByFunctionCode(kb_full_shortcuts)
  local hints = {}

  local cache_path = renoise.tool().bundle_path .. "autocomplete_cache.txt"
  local file = io.open(cache_path, "r")
  if not file then
    print("PakettiShortcutHints: Could not open autocomplete_cache.txt")
    return hints
  end

  local content = file:read("*all")
  file:close()

  -- Join continuation lines (multiline function bodies) into single entries
  local entries = {}
  for line in content:gmatch("[^\n]+") do
    if line:match("^Menu Entry|||") or line:match("^Keybinding|||") or line:match("^MIDI Mapping|||") then
      table.insert(entries, line)
    elseif line:match("^CACHE_VERSION") or line:match("^SCAN_TIME") or line:match("^COMMAND_COUNT") then
      -- skip headers
    else
      if #entries > 0 then
        entries[#entries] = entries[#entries] .. " " .. line
      end
    end
  end

  -- Group by normalized function code
  local menu_by_func = {}   -- func_code -> { menu_name, ... }
  local kb_by_func = {}     -- func_code -> { keybinding_name, ... }

  for _, entry_line in ipairs(entries) do
    local entry_type, name, _, func_code = entry_line:match("^(.-)|||(.-)|||(.-)|||(.-)|||")
    if entry_type and name and func_code and func_code ~= "" then
      local normalized = func_code:gsub("%s+", " "):match("^%s*(.-)%s*$")
      if entry_type == "Menu Entry" then
        if not menu_by_func[normalized] then menu_by_func[normalized] = {} end
        table.insert(menu_by_func[normalized], name)
      elseif entry_type == "Keybinding" then
        if not kb_by_func[normalized] then kb_by_func[normalized] = {} end
        table.insert(kb_by_func[normalized], name)
      end
    end
  end

  -- For each function code that has both menu entries and keybindings,
  -- look up the keybinding's shortcut from KeyBindings.xml
  local matched = 0
  for func_code, menu_names in pairs(menu_by_func) do
    local kb_names = kb_by_func[func_code]
    if kb_names then
      -- Find the best shortcut from any of the keybinding names
      local best_shortcut = nil
      for _, kb_name in ipairs(kb_names) do
        local shortcut = kb_full_shortcuts[kb_name]
        if shortcut then
          best_shortcut = shortcut
          break
        end
      end

      if best_shortcut then
        for _, menu_name in ipairs(menu_names) do
          hints[menu_name] = " [" .. best_shortcut .. "]"
          matched = matched + 1
        end
      end
    end
  end

  print("PakettiShortcutHints: Function code matching found " .. matched .. " menu entries")
  return hints
end

-- Step 3: Display name suffix matching (fallback)
local function matchByDisplayName(kb_display_shortcuts, existing_hints)
  local added = 0

  -- Build the set of all menu entry names from the cache
  local cache_path = renoise.tool().bundle_path .. "autocomplete_cache.txt"
  local file = io.open(cache_path, "r")
  if not file then return added end

  for line in file:lines() do
    if line:match("^Menu Entry|||") then
      local name = line:match("^Menu Entry|||(.-)|||")
      if name and not existing_hints[name] then
        -- Try progressively shorter suffixes
        local pos = 0
        while true do
          pos = name:find(":", pos + 1)
          if not pos then break end
          local suffix = name:sub(pos + 1)
          local shortcut = kb_display_shortcuts[suffix]
          if shortcut then
            existing_hints[name] = " [" .. shortcut .. "]"
            added = added + 1
            break
          end
        end
      end
    end
  end
  file:close()

  print("PakettiShortcutHints: Display name matching added " .. added .. " more")
  return added
end

function PakettiGetMenuShortcutHint(menu_name)
  return PakettiShortcutHintsTable[menu_name] or ""
end

local function initShortcutHints()
  if preferences and preferences.pakettiShowShortcutHints
    and not preferences.pakettiShowShortcutHints.value then
    print("PakettiShortcutHints: Disabled by preference, skipping")
    return
  end

  -- Parse KeyBindings.xml (both full-name and display-name tables)
  local kb_full, kb_display = parseKeyBindings()

  -- Method 1: Match by function code via autocomplete cache
  PakettiShortcutHintsTable = matchByFunctionCode(kb_full)

  -- Method 2: Fill gaps with display name suffix matching
  matchByDisplayName(kb_display, PakettiShortcutHintsTable)

  local total = 0
  for _ in pairs(PakettiShortcutHintsTable) do total = total + 1 end
  print("PakettiShortcutHints: Total " .. total .. " menu entries will show shortcut hints")
end

initShortcutHints()
