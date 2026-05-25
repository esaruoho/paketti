-- PakettiDialogOfDialogsSmokeTest.lua
-- Walks the Dialog of Dialogs button list, pcalls each entry, captures Lua
-- errors and Log.txt deltas (catches C++-side std::logic_error etc.), and
-- writes a markdown report next to preferences.xml.

local function platform_separator()
  return (os.platform() == "WINDOWS") and "\\" or "/"
end

-- Strip "Scripts<sep>Tools<sep><toolname><sep>" off bundle_path to land on the
-- V<ver> root where Log.txt and KeyBindings.xml live. Mirrors the derivation
-- in the Preferences Email button.
local function renoise_user_root()
  local sep = platform_separator()
  local bundle = renoise.tool().bundle_path
  if bundle:sub(-1) == sep then bundle = bundle:sub(1, -2) end
  local root = bundle
  for _ = 1, 3 do
    local pos = root:reverse():find(sep, 1, true)
    if pos then root = root:sub(1, #root - pos) end
  end
  return root
end

local function log_path()
  return renoise_user_root() .. platform_separator() .. "Log.txt"
end

local function read_file_size(path)
  local f = io.open(path, "rb")
  if not f then return 0 end
  local size = f:seek("end") or 0
  f:close()
  return size
end

local function read_log_since(path, start_offset)
  local f = io.open(path, "rb")
  if not f then return "" end
  f:seek("set", start_offset)
  local data = f:read("*a") or ""
  f:close()
  return data
end

-- Patterns that signal real engine-side trouble in Log.txt deltas.
local ERROR_PATTERNS = {
  "std::logic_error",
  "std::runtime_error",
  "std::exception",
  "ERROR:",
  "*** ",        -- Renoise prefixes Lua errors with "*** "
  "exception",
  "assertion failed",
}

local function log_has_error(delta)
  for _, pat in ipairs(ERROR_PATTERNS) do
    if delta:find(pat, 1, true) then return true end
  end
  return false
end

local function extract_error_lines(delta)
  local lines = {}
  for line in delta:gmatch("[^\r\n]+") do
    for _, pat in ipairs(ERROR_PATTERNS) do
      if line:find(pat, 1, true) then
        table.insert(lines, line)
        break
      end
    end
  end
  return lines
end

function PakettiDialogOfDialogsSmokeTest()
  if type(create_button_list) ~= "function" then
    renoise.app():show_error("Dialog of Dialogs Smoke Test: create_button_list() not found. PakettiMainMenuEntries.lua must be loaded first.")
    return
  end

  local buttons = create_button_list()
  local log = log_path()
  local results = {}
  local missing, lua_errors, log_errors, ok = 0, 0, 0, 0

  renoise.app():show_status(string.format("Dialog of Dialogs Smoke Test: running %d buttons...", #buttons))

  for i, entry in ipairs(buttons) do
    local label = entry[1] or ("<unnamed#" .. i .. ">")
    local target = entry[2]
    local fn = nil
    local resolution = "OK"

    if type(target) == "function" then
      fn = target
    elseif type(target) == "string" then
      fn = _G[target]
      if type(fn) ~= "function" then
        resolution = "MISSING_GLOBAL(" .. target .. ")"
        fn = nil
      end
    else
      resolution = "UNKNOWN_TARGET_TYPE(" .. type(target) .. ")"
    end

    if not fn then
      missing = missing + 1
      table.insert(results, {label = label, status = "MISSING", detail = resolution})
    else
      local before = read_file_size(log)
      local pcall_ok, pcall_err = pcall(fn)
      local after = read_file_size(log)
      local delta = (after > before) and read_log_since(log, before) or ""
      local err_lines = extract_error_lines(delta)
      local log_bad = log_has_error(delta)

      if not pcall_ok then
        lua_errors = lua_errors + 1
        table.insert(results, {label = label, status = "LUA_ERROR", detail = tostring(pcall_err), log_lines = err_lines})
      elseif log_bad then
        log_errors = log_errors + 1
        table.insert(results, {label = label, status = "LOG_ERROR", detail = "engine-side error in Log.txt delta", log_lines = err_lines})
      else
        ok = ok + 1
        table.insert(results, {label = label, status = "OK", detail = nil})
      end
    end
  end

  -- Build markdown report
  local report = {}
  table.insert(report, "# Dialog of Dialogs Smoke Test")
  table.insert(report, "")
  table.insert(report, "Run: " .. os.date("%Y-%m-%d %H:%M:%S"))
  table.insert(report, "Renoise: " .. (renoise.RENOISE_VERSION or "?"))
  table.insert(report, "Log.txt: `" .. log .. "`")
  table.insert(report, "")
  table.insert(report, string.format("Total: %d   OK: %d   LUA_ERROR: %d   LOG_ERROR: %d   MISSING: %d",
    #buttons, ok, lua_errors, log_errors, missing))
  table.insert(report, "")

  local function dump_section(title, status)
    local any = false
    for _, r in ipairs(results) do
      if r.status == status then
        if not any then
          table.insert(report, "## " .. title)
          table.insert(report, "")
          any = true
        end
        table.insert(report, "### " .. r.label)
        if r.detail then
          table.insert(report, "```")
          table.insert(report, r.detail)
          table.insert(report, "```")
        end
        if r.log_lines and #r.log_lines > 0 then
          table.insert(report, "Log.txt:")
          table.insert(report, "```")
          for _, line in ipairs(r.log_lines) do
            table.insert(report, line)
          end
          table.insert(report, "```")
        end
        table.insert(report, "")
      end
    end
  end

  dump_section("LUA_ERROR", "LUA_ERROR")
  dump_section("LOG_ERROR (engine-side)", "LOG_ERROR")
  dump_section("MISSING (button references a global that does not exist)", "MISSING")

  table.insert(report, "## OK")
  table.insert(report, "")
  for _, r in ipairs(results) do
    if r.status == "OK" then
      table.insert(report, "- " .. r.label)
    end
  end

  local report_path = renoise.tool().bundle_path .. "DialogOfDialogs-SmokeTest.md"
  local f = io.open(report_path, "w")
  if f then
    f:write(table.concat(report, "\n"))
    f:close()
  end

  local summary = string.format("Smoke Test: OK=%d LUA_ERROR=%d LOG_ERROR=%d MISSING=%d (report: %s)",
    ok, lua_errors, log_errors, missing, report_path)
  renoise.app():show_status(summary)
  print(summary)
  renoise.app():open_path(report_path)
end

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Xperimental/WIP:Dialog of Dialogs Smoke Test",
  invoke = function() PakettiDialogOfDialogsSmokeTest() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Dialog of Dialogs Smoke Test",
  invoke = function() PakettiDialogOfDialogsSmokeTest() end
}
