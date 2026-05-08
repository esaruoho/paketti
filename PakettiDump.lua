-- PakettiDump.lua
-- pdump(value, label) — global helper that dumps any Lua value to a text file
-- AND opens it in the system default editor (TextEdit on macOS, Notepad on Windows).
--
-- Use from the Renoise Scripting Terminal (>>> prompt):
--
--   pdump(renoise.song().selected_track.available_device_infos)
--   pdump(renoise.song().selected_track.available_device_infos, "devices")
--   pdump(renoise.song().selected_instrument)
--   pdump({1,2,3,foo="bar"})
--   pdump("anything works", "test")
--
-- Files land in /tmp/paketti-<label>-<timestamp>.txt and open immediately.
-- If you don't pass a label, default is "pdump".
--
-- Why this exists:
--   rprint() writes to the Scripting Terminal's stdout, not a file. To capture
--   its output we monkey-patch `print` for the duration of the rprint call,
--   then restore it. This lets us pipe the same recursive-table-walk that
--   rprint produces into a file we can grep, share, or commit.

local function _open_in_editor(path)
  local cmd
  if package.config:sub(1, 1) == '\\' then
    cmd = string.format('start "" "%s"', path)  -- Windows
  else
    cmd = string.format('open "%s"', path)       -- macOS / Linux (xdg-open works on most Linux too)
  end
  os.execute(cmd)
end

function pdump(value, label)
  label = label or "pdump"
  -- Sanitize label: only allow [a-zA-Z0-9._-]
  label = label:gsub("[^%w%.%-_]", "_")

  local stamp = os.date("%Y%m%d-%H%M%S")
  local path = "/tmp/paketti-" .. label .. "-" .. stamp .. ".txt"

  local f, err = io.open(path, "w")
  if not f then
    print("pdump: cannot open " .. path .. ": " .. tostring(err))
    return nil
  end

  f:write("-- pdump label: " .. label .. "\n")
  f:write("-- timestamp:   " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
  f:write("-- value type:  " .. type(value) .. "\n")
  f:write("-- =====================================\n")

  if type(value) == "table" then
    -- Hijack print so rprint's recursive walk writes into our file
    local original_print = print
    print = function(...)
      local args = { ... }
      for i, v in ipairs(args) do
        f:write(tostring(v))
        if i < #args then f:write("\t") end
      end
      f:write("\n")
    end
    local ok, perr = pcall(rprint, value)
    print = original_print
    if not ok then
      f:write("-- rprint error: " .. tostring(perr) .. "\n")
      f:write(tostring(value))
    end
  elseif type(value) == "userdata" then
    -- Renoise userdata: use oprint (object print) which dumps properties/methods
    local original_print = print
    print = function(...)
      local args = { ... }
      for i, v in ipairs(args) do
        f:write(tostring(v))
        if i < #args then f:write("\t") end
      end
      f:write("\n")
    end
    local ok, perr = pcall(oprint, value)
    print = original_print
    if not ok then
      f:write("-- oprint error: " .. tostring(perr) .. "\n")
      f:write(tostring(value))
    end
  else
    f:write(tostring(value))
  end

  f:close()

  print("pdump: wrote " .. path)
  _open_in_editor(path)
  return path
end

-- pdump_quiet(value, label) — like pdump but does NOT open the file in the editor.
-- Useful when you want to write a quick dump for Claude to read but don't want
-- TextEdit windows piling up.
function pdump_quiet(value, label)
  label = label or "pdump"
  label = label:gsub("[^%w%.%-_]", "_")
  local stamp = os.date("%Y%m%d-%H%M%S")
  local path = "/tmp/paketti-" .. label .. "-" .. stamp .. ".txt"

  local f = io.open(path, "w")
  if not f then return nil end
  f:write("-- pdump_quiet label: " .. label .. "\n")
  f:write("-- timestamp:         " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
  f:write("-- value type:        " .. type(value) .. "\n")
  f:write("-- =====================================\n")
  if type(value) == "table" then
    local p = print
    print = function(...)
      local a = { ... }
      for i, v in ipairs(a) do
        f:write(tostring(v))
        if i < #a then f:write("\t") end
      end
      f:write("\n")
    end
    pcall(rprint, value)
    print = p
  elseif type(value) == "userdata" then
    local p = print
    print = function(...)
      local a = { ... }
      for i, v in ipairs(a) do
        f:write(tostring(v))
        if i < #a then f:write("\t") end
      end
      f:write("\n")
    end
    pcall(oprint, value)
    print = p
  else
    f:write(tostring(value))
  end
  f:close()
  print("pdump_quiet: wrote " .. path)
  return path
end
