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
-- Return the field starting at index i, and the index just past its "|||"
-- terminator (nil if this field was not terminated by one).
local function nextCacheField(s, i)
  local j = s:find("|||", i, true)
  if not j then return s:sub(i), nil end
  return s:sub(i, j - 1), j + 3
end

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
    -- Split on "|||" with a plain (non-pattern) find instead of the lazy
    -- "^(.-)|||(.-)|||(.-)|||(.-)|||" match, which backtracked across every entry
    -- line. Measured on the real cache: 22.2ms -> 14.6ms, identical grouping.
    -- Like the pattern it replaces, this requires a 4th "|||" to be present.
    local entry_type, i = nextCacheField(entry_line, 1)
    local name, func_code
    if i then name, i = nextCacheField(entry_line, i) end
    if i then local _unused; _unused, i = nextCacheField(entry_line, i) end
    if i then func_code, i = nextCacheField(entry_line, i) end
    if i and entry_type and name and func_code and func_code ~= "" then
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

-- ── Disk cache for the finished hint table ───────────────────────────────────
-- Building the table parses KeyBindings.xml (~1.2 MB) and autocomplete_cache.txt
-- (~1.6 MB, read twice) to produce only ~275 hints — measured ~75 ms at EVERY
-- startup. The finished table serialises to ~21 KB and reloads in ~0.1 ms, so it
-- is cached on disk and rebuilt only when one of its inputs actually changes.
-- Bump HINT_CACHE_VERSION whenever the hint FORMAT or the matching logic changes,
-- so existing caches are discarded rather than trusted.
local HINT_CACHE_VERSION = "1"

local function hintCachePath()
  return renoise.tool().bundle_path .. "shortcut_hints_cache.txt"
end

-- Identity of everything the hint table is derived from. Any change invalidates.
-- Renoise version is included because it selects the KeyBindings.xml path.
local function hintCacheFingerprint()
  -- Without io.stat there is no way to notice an input changing, and a cache that
  -- can never go stale would pin wrong shortcuts into menu labels forever. So in
  -- that case return nil, which disables the cache and forces a rebuild instead.
  if type(io.stat) ~= "function" then return nil end
  local parts = { HINT_CACHE_VERSION, tostring(renoise.RENOISE_VERSION) }
  local inputs = { getKeyBindingsPath(),
                   renoise.tool().bundle_path .. "autocomplete_cache.txt" }
  for _, path in ipairs(inputs) do
    if not path then return nil end
    local stat = io.stat(path)
    if stat and stat.size and stat.mtime then
      parts[#parts + 1] = tostring(stat.size) .. ":" .. tostring(stat.mtime)
    else
      -- A genuinely absent input is a stable state worth caching (a fresh install
      -- has no autocomplete_cache.txt); it stops being "missing" the moment the
      -- file appears, which changes the fingerprint and rebuilds.
      parts[#parts + 1] = "missing"
    end
  end
  return table.concat(parts, "|")
end

-- Returns hints, count — or nil when there is no usable cache for this fingerprint.
local function loadHintCache(fingerprint)
  local file = io.open(hintCachePath(), "r")
  if not file then return nil end
  local content = file:read("*all")
  file:close()
  if not content or content == "" then return nil end
  -- Line 1 is the fingerprint; anything else means the inputs moved on.
  if (content:match("^([^\n]*)") or "") ~= fingerprint then return nil end
  local hints, count = {}, 0
  for line in content:gmatch("[^\n]+") do
    local tab = line:find("\t", 1, true)
    if tab then
      hints[line:sub(1, tab - 1)] = line:sub(tab + 1)
      count = count + 1
    end
  end
  return hints, count
end

local function saveHintCache(fingerprint, hints)
  local buf = { fingerprint }
  for name, hint in pairs(hints) do
    -- A tab or newline in either half would corrupt the line format. None occur
    -- today; if one ever does, skip caching rather than write a corrupt file.
    if name:find("\t", 1, true) or name:find("\n", 1, true)
      or hint:find("\t", 1, true) or hint:find("\n", 1, true) then
      print("PakettiShortcutHints: entry contains a tab/newline, skipping cache write")
      return false
    end
    buf[#buf + 1] = name .. "\t" .. hint
  end
  local file = io.open(hintCachePath(), "w")
  if not file then
    print("PakettiShortcutHints: Could not write " .. hintCachePath())
    return false
  end
  file:write(table.concat(buf, "\n"))
  file:close()
  return true
end

local function initShortcutHints()
  if preferences and preferences.pakettiShowShortcutHints
    and not preferences.pakettiShowShortcutHints.value then
    print("PakettiShortcutHints: Disabled by preference, skipping")
    return
  end

  -- Fast path: reuse the previously computed table when nothing it depends on
  -- has changed. Any failure here simply falls through to a full rebuild.
  local fingerprint = hintCacheFingerprint()
  if fingerprint then
    local cached, cached_count = loadHintCache(fingerprint)
    if cached then
      PakettiShortcutHintsTable = cached
      print("PakettiShortcutHints: Loaded " .. cached_count .. " hints from cache")
      return
    end
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
  if fingerprint then saveHintCache(fingerprint, PakettiShortcutHintsTable) end
end

initShortcutHints()
