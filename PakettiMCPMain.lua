-- PakettiMCPMain.lua
-- Paketti × Renoise MCP — Streamable HTTP MCP server inside Renoise.
--
-- Lets Claude (or any MCP client) drive Renoise via JSON-RPC 2.0 over HTTP
-- on localhost:19714/mcp.
--
-- ATTRIBUTION:
-- The MCP server core (PakettiMCP/json.lua, router.lua, server.lua,
-- dialog.lua, tools/*.lua) is adapted from ReMCP by kraken@renoise.com
-- (https://github.com/renoise/xrnx, MIT licensed). Integrated into Paketti
-- with namespace adjustments (PakettiMCP/ subdir, require paths) so it
-- coexists with other Paketti modules.
--
-- Usage from bash:
--   curl -s http://localhost:19714/health
--   curl -s -X POST http://localhost:19714/mcp \
--     -H 'Content-Type: application/json' \
--     -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
--
-- Or use the rmcp helper from the remcp skill:
--   rmcp song_get_info
--   rmcp transport_set_bpm '{"bpm":174}'

local function show_dialog()
  -- Lazy-load so we don't pay the cost at tool startup
  local ok, dialog = pcall(require, "PakettiMCP.dialog")
  if not ok then
    renoise.app():show_status("PakettiMCP: failed to load dialog: " .. tostring(dialog))
    return
  end
  dialog.show()
end

local function start_server_silent()
  local ok_r, router = pcall(require, "PakettiMCP.router")
  local ok_s, server = pcall(require, "PakettiMCP.server")
  if not (ok_r and ok_s) then
    renoise.app():show_status("PakettiMCP: failed to load core: " .. tostring(router) .. " / " .. tostring(server))
    return
  end
  local loaded, errors = router.load_tools_dir(renoise.tool().bundle_path)
  if server.start then
    local started, err = server.start()
    if started then
      renoise.app():show_status(string.format("PakettiMCP: server started on :%d, %d tools loaded", server.port, loaded))
    else
      renoise.app():show_status("PakettiMCP: failed to start server: " .. tostring(err))
    end
  end
end

local function stop_server_silent()
  local ok, server = pcall(require, "PakettiMCP.server")
  if not ok then return end
  if server.stop and server.running then
    server.stop()
    renoise.app():show_status("PakettiMCP: server stopped")
  end
end

-- ============================================================
-- Auto-Start: keep the server alive across tool reloads, song loads,
-- and unexpected teardowns. When ON, a slow keepalive timer re-starts the
-- server whenever it is found not running — so external MCP clients (and the
-- MLX bridge) stay connected even after you edit code or load another song.
-- ============================================================
function PakettiMCPAutoStartEnabled()
  return preferences and preferences.PakettiMCPAutoStart
    and preferences.PakettiMCPAutoStart.value or false
end

-- Start the server iff Auto-Start is ON and it isn't already running.
local function paketti_mcp_autostart_ensure()
  if not PakettiMCPAutoStartEnabled() then return end
  local ok, server = pcall(require, "PakettiMCP.server")
  if ok and server and not server.running then
    start_server_silent()
  end
end

function PakettiMCPToggleAutoStart()
  local now = not PakettiMCPAutoStartEnabled()
  if preferences and preferences.PakettiMCPAutoStart then
    preferences.PakettiMCPAutoStart.value = now
    preferences:save_as("preferences.xml")
  end
  if now then
    start_server_silent()
    renoise.app():show_status("Auto-Start PakettiMCP: ON — server started + kept alive")
  else
    renoise.app():show_status("Auto-Start PakettiMCP: OFF (server left as-is)")
  end
end

PakettiAddMenuEntry{
  name = "Main Menu:Options:Auto-Start PakettiMCP",
  selected = function() return PakettiMCPAutoStartEnabled() end,
  invoke = function() PakettiMCPToggleAutoStart() end
}

-- Re-ensure on every song load (app_new_document fires at launch + each load).
if not renoise.tool().app_new_document_observable:has_notifier(paketti_mcp_autostart_ensure) then
  renoise.tool().app_new_document_observable:add_notifier(paketti_mcp_autostart_ensure)
end

-- Keepalive: slow timer that restarts the server whenever Auto-Start is ON and
-- it's down. Covers tool-reload (Lua state resets), song-load, and crashes.
if not renoise.tool():has_timer(paketti_mcp_autostart_ensure) then
  renoise.tool():add_timer(paketti_mcp_autostart_ensure, 5000)
end

-- And once shortly after load: the tool loads AFTER the song, so the
-- app_new_document notifier above missed the launch-time document event.
local paketti_mcp_autostart_boot
paketti_mcp_autostart_boot = function()
  renoise.tool():remove_timer(paketti_mcp_autostart_boot)
  paketti_mcp_autostart_ensure()
end
renoise.tool():add_timer(paketti_mcp_autostart_boot, 1200)

renoise.tool():add_keybinding{
  name = "Global:Paketti:MCP Server Dialog",
  invoke = show_dialog
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:MCP Server Start",
  invoke = start_server_silent
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:MCP Server Stop",
  invoke = stop_server_silent
}

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:!Preferences:MCP Server Dialog...",
  invoke = show_dialog
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:!Preferences:MCP Server Start",
  invoke = start_server_silent
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:!Preferences:MCP Server Stop",
  invoke = stop_server_silent
}
