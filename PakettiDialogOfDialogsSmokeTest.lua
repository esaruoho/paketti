-- PakettiDialogOfDialogsSmokeTest.lua
-- Walks the Dialog of Dialogs button list, pcalls each entry, captures Lua
-- errors and Log.txt deltas (catches C++-side std::logic_error etc.), and
-- writes a markdown report next to preferences.xml.
--
-- Runs inside a ProcessSlicer coroutine so the UI stays responsive and the
-- user can cancel. After each button the partial report is flushed to disk
-- so a Renoise halt mid-run still preserves whatever ran up to that point.
--
-- For each button we call the function once (open), yield a few idle ticks,
-- then call it again to attempt a toggle-close. Most Paketti dialogs follow
-- the `if dialog and dialog.visible then dialog:close() else show() end`
-- pattern, so a second invocation closes them. Dialogs that don't follow the
-- pattern will pile up — that's why the SKIP_LIST exists.

-- Buttons to skip entirely. Add labels here for dialogs known to:
--   - require a file picker / native sheet (will stall Renoise)
--   - require specific selection state that we can't fake
--   - have known irreversible side effects
local SKIP_LIST = {
  -- Native macOS font download was triggered by one of these — likely a CJK
  -- glyph in a dialog title. Keep skip list empty by default; the user can
  -- add labels here after a first run identifies the troublemakers.
}

local function in_skip_list(label)
  for _, s in ipairs(SKIP_LIST) do
    if s == label then return true end
  end
  return false
end

local function platform_separator()
  return (os.platform() == "WINDOWS") and "\\" or "/"
end

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

local ERROR_PATTERNS = {
  "std::logic_error",
  "std::runtime_error",
  "std::exception",
  "ERROR:",
  "*** ",
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

-- Render the current results to the report file. Called after every button
-- so a halt mid-run still leaves a usable report on disk.
local function write_report(report_path, results, total_count, status_counts, started_at, finished, cancelled)
  local out = {}
  table.insert(out, "# Dialog of Dialogs Smoke Test")
  table.insert(out, "")
  table.insert(out, "Started: " .. started_at)
  table.insert(out, "Renoise: " .. (renoise.RENOISE_VERSION or "?"))
  table.insert(out, "Log.txt: `" .. log_path() .. "`")
  table.insert(out, "")
  if cancelled then
    table.insert(out, "**Status: CANCELLED after " .. #results .. " / " .. total_count .. " buttons.**")
  elseif finished then
    table.insert(out, "**Status: COMPLETE.**")
  else
    table.insert(out, "**Status: IN PROGRESS (" .. #results .. " / " .. total_count .. " — last button: `" ..
      (results[#results] and results[#results].label or "?") .. "`).**")
  end
  table.insert(out, "")
  table.insert(out, string.format("OK: %d   LUA_ERROR: %d   LOG_ERROR: %d   MISSING: %d   SKIPPED: %d",
    status_counts.OK, status_counts.LUA_ERROR, status_counts.LOG_ERROR, status_counts.MISSING, status_counts.SKIPPED))
  table.insert(out, "")

  local function dump_section(title, status)
    local any = false
    for _, r in ipairs(results) do
      if r.status == status then
        if not any then
          table.insert(out, "## " .. title)
          table.insert(out, "")
          any = true
        end
        table.insert(out, "### " .. r.label)
        if r.detail then
          table.insert(out, "```")
          table.insert(out, r.detail)
          table.insert(out, "```")
        end
        if r.log_lines and #r.log_lines > 0 then
          table.insert(out, "Log.txt:")
          table.insert(out, "```")
          for _, line in ipairs(r.log_lines) do
            table.insert(out, line)
          end
          table.insert(out, "```")
        end
        table.insert(out, "")
      end
    end
  end

  dump_section("LUA_ERROR", "LUA_ERROR")
  dump_section("LOG_ERROR (engine-side)", "LOG_ERROR")
  dump_section("MISSING (button references a global that does not exist)", "MISSING")
  dump_section("SKIPPED", "SKIPPED")

  table.insert(out, "## OK")
  table.insert(out, "")
  for _, r in ipairs(results) do
    if r.status == "OK" then
      table.insert(out, "- " .. r.label)
    end
  end

  local f = io.open(report_path, "w")
  if f then
    f:write(table.concat(out, "\n"))
    f:close()
  end
end

-- Try to close any dialog the just-invoked function opened. Most Paketti
-- dialogs follow a toggle pattern (call again -> close), so we re-invoke
-- with pcall after yielding. If the second call throws or opens a NEW
-- dialog, we just move on.
local function try_toggle_close(fn)
  pcall(fn)
end

local PakettiDialogOfDialogsSmokeTestSlicer = nil

function PakettiDialogOfDialogsSmokeTest()
  if PakettiDialogOfDialogsSmokeTestSlicer and PakettiDialogOfDialogsSmokeTestSlicer:running() then
    renoise.app():show_status("Dialog of Dialogs Smoke Test: already running. Use the Cancel button.")
    return
  end

  if type(create_button_list) ~= "function" then
    renoise.app():show_error("Dialog of Dialogs Smoke Test: create_button_list() not found. PakettiMainMenuEntries.lua must be loaded first.")
    return
  end

  local buttons = create_button_list()
  local log = log_path()
  local report_path = renoise.tool().bundle_path .. "DialogOfDialogs-SmokeTest.md"
  local started_at = os.date("%Y-%m-%d %H:%M:%S")

  local results = {}
  local counts = {OK = 0, LUA_ERROR = 0, LOG_ERROR = 0, MISSING = 0, SKIPPED = 0}

  -- Initial flush so the file exists immediately, even if we crash on the first button.
  write_report(report_path, results, #buttons, counts, started_at, false, false)

  local function process_func(progress_vb, get_dialog)
    for i, entry in ipairs(buttons) do
      if PakettiDialogOfDialogsSmokeTestSlicer:was_cancelled() then
        write_report(report_path, results, #buttons, counts, started_at, false, true)
        return
      end

      local label = entry[1] or ("<unnamed#" .. i .. ">")
      local target = entry[2]

      if progress_vb and progress_vb.views.progress_text then
        progress_vb.views.progress_text.text = string.format("[%d/%d] %s", i, #buttons, label)
      end

      if in_skip_list(label) then
        counts.SKIPPED = counts.SKIPPED + 1
        table.insert(results, {label = label, status = "SKIPPED", detail = "in SKIP_LIST"})
      else
        local fn = nil
        local resolution = nil

        if type(target) == "function" then
          fn = target
        elseif type(target) == "string" then
          -- rawget bypasses Renoise's strict-mode global metatable which
          -- otherwise raises "variable is not declared" for missing names.
          fn = rawget(_G, target)
          if type(fn) ~= "function" then
            resolution = "MISSING_GLOBAL(" .. target .. ")"
            fn = nil
          end
        else
          resolution = "UNKNOWN_TARGET_TYPE(" .. type(target) .. ")"
        end

        if not fn then
          counts.MISSING = counts.MISSING + 1
          table.insert(results, {label = label, status = "MISSING", detail = resolution})
        else
          local before = read_file_size(log)
          local pcall_ok, pcall_err = pcall(fn)
          -- Yield twice so the dialog actually renders before we attempt the toggle-close.
          coroutine.yield()
          coroutine.yield()

          -- Toggle-close attempt: re-invoke. Most Paketti dialogs close on second call.
          if pcall_ok then
            try_toggle_close(fn)
            coroutine.yield()
          end

          local after = read_file_size(log)
          local delta = (after > before) and read_log_since(log, before) or ""
          local err_lines = extract_error_lines(delta)
          local log_bad = log_has_error(delta)

          if not pcall_ok then
            counts.LUA_ERROR = counts.LUA_ERROR + 1
            table.insert(results, {label = label, status = "LUA_ERROR", detail = tostring(pcall_err), log_lines = err_lines})
          elseif log_bad then
            counts.LOG_ERROR = counts.LOG_ERROR + 1
            table.insert(results, {label = label, status = "LOG_ERROR", detail = "engine-side error in Log.txt delta", log_lines = err_lines})
          else
            counts.OK = counts.OK + 1
            table.insert(results, {label = label, status = "OK"})
          end
        end
      end

      -- Incremental flush after every button. If Renoise halts on the NEXT
      -- one, this state is on disk.
      write_report(report_path, results, #buttons, counts, started_at, false, false)

      -- Extra yield between buttons so the UI gets idle time.
      coroutine.yield()
    end

    write_report(report_path, results, #buttons, counts, started_at, true, false)

    local summary = string.format("Smoke Test done: OK=%d LUA_ERROR=%d LOG_ERROR=%d MISSING=%d SKIPPED=%d (report: %s)",
      counts.OK, counts.LUA_ERROR, counts.LOG_ERROR, counts.MISSING, counts.SKIPPED, report_path)
    renoise.app():show_status(summary)
    print(summary)
    if get_dialog and get_dialog() and get_dialog().visible then get_dialog():close() end
    renoise.app():open_path(report_path)
  end

  PakettiDialogOfDialogsSmokeTestSlicer = ProcessSlicer(process_func)
  local progress_dialog, progress_vb = PakettiDialogOfDialogsSmokeTestSlicer:create_dialog("Dialog of Dialogs Smoke Test")
  -- Re-bind process_func args so it can see the progress dialog.
  PakettiDialogOfDialogsSmokeTestSlicer.__process_func_args = {progress_vb, function() return progress_dialog end}
  PakettiDialogOfDialogsSmokeTestSlicer:start()
end

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Xperimental/WIP:Dialog of Dialogs Smoke Test",
  invoke = function() PakettiDialogOfDialogsSmokeTest() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Dialog of Dialogs Smoke Test",
  invoke = function() PakettiDialogOfDialogsSmokeTest() end
}
