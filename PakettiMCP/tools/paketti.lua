-- tools/paketti.lua
-- Paketti-specific verbs for the Sal voice demo. Each tool calls a global
-- function defined elsewhere in Paketti (no MCP-side reimplementation).

local json = require("PakettiMCP.json")

local function text(s) return { content = {{ type = "text", text = tostring(s) }} } end
local function err(s)  return { content = {{ type = "text", text = tostring(s) }}, isError = true } end

-- Capture a screenshot of the Renoise front window (a Paketti dialog, the pattern
-- editor, whatever is frontmost) to `path` using macOS screencapture. Tries to grab
-- just the Renoise front window's region (via System Events bounds); falls back to a
-- full-screen capture if the bounds can't be read. Returns true on success.
local function capture_renoise(path)
  -- Fire screencapture DETACHED (trailing &) so the tool handler returns INSTANTLY and
  -- never blocks Renoise's main thread. A blocking shell call here freezes Renoise long
  -- enough to trip its "tool not responding" guard, which pops a modal and stalls the
  -- whole tool + socket. Detached = the handler can't hang. The PNG appears ~200 ms
  -- later; the caller waits briefly then reads it. screencapture needs Screen-Recording
  -- permission (granted once). The caller should bring Renoise to the front first.
  os.execute(string.format('screencapture -x -o "%s" >/dev/null 2>&1 &', path))
  return true
end

local function call_global(fn_name)
  local fn = _G[fn_name]
  if type(fn) ~= "function" then
    return err("paketti function not loaded: " .. fn_name)
  end
  local ok, ret = pcall(fn)
  if not ok then return err(tostring(ret)) end
  return text("ok: " .. fn_name)
end

local function resize_selected_pattern(factor)
  local ok, song = pcall(renoise.song)
  if not ok or not song then return err("no song loaded") end
  local pat = song.selected_pattern
  if not pat then return err("no selected pattern") end
  if type(_G.resize_pattern) ~= "function" then
    return err("resize_pattern not loaded")
  end
  local new_lines = math.floor(pat.number_of_lines * factor + 0.5)
  if new_lines < 1 then new_lines = 1 end
  if new_lines > 512 then new_lines = 512 end
  local ok2, e = pcall(_G.resize_pattern, pat, new_lines, 0)
  if not ok2 then return err(tostring(e)) end
  return text(string.format("ok: pattern resized to %d lines (factor %.2f)", new_lines, factor))
end

return {
  {
    name = "paketti_pattern_preset_dialog",
    description = "Open (or close) the Paketti Pattern Preset Dialog — pick/put complete Pattern Matrix slots across 32 banks.",
    inputSchema = { type = "object", properties = {}, required = {} },
    handler = function(_) return call_global("PakettiPatternPresetDialog") end,
  },
  {
    name = "paketti_groovebox",
    description = "Open (or close) the Paketti Groovebox 8120 dialog.",
    inputSchema = { type = "object", properties = {}, required = {} },
    handler = function(_) return call_global("GrooveboxShowClose") end,
  },
  {
    name = "paketti_open_scala_tuning_map",
    description = "Open (or close) the Paketti Scala Tuning Map dialog.",
    inputSchema = { type = "object", properties = {}, required = {} },
    handler = function(_) return call_global("PakettiScalaTuningMapShow") end,
  },
  {
    name = "paketti_eval",
    description = "Evaluate a Lua string in Renoise's context (localhost dev tool only). Returns tostring of the return value, or the error.",
    inputSchema = { type = "object", properties = { code = { type = "string", description = "Lua code to run" } }, required = {"code"} },
    handler = function(args)
      local code = args and args.code
      if type(code) ~= "string" then return err("missing 'code' string") end
      local chunk, cerr = loadstring(code)
      if not chunk then return err("compile error: " .. tostring(cerr)) end
      local ok, ret = pcall(chunk)
      if not ok then return err("runtime error: " .. tostring(ret)) end
      return text("ok: " .. tostring(ret))
    end,
  },
  {
    name = "paketti_pattern_shrink",
    description = "Shrink the selected pattern to half length (dBlue Pattern Shrink).",
    inputSchema = { type = "object", properties = {}, required = {} },
    handler = function(_) return resize_selected_pattern(0.5) end,
  },
  {
    name = "paketti_pattern_expand",
    description = "Expand the selected pattern to double length (dBlue Pattern Expand).",
    inputSchema = { type = "object", properties = {}, required = {} },
    handler = function(_) return resize_selected_pattern(2.0) end,
  },
  {
    name = "paketti_reload",
    description = "Hot-reload PakettiMCP tool files in place (no server restart, no socket churn). Use after editing a file in PakettiMCP/tools/. Does NOT reload Paketti feature code — that needs a full Renoise tool reload.",
    inputSchema = { type = "object", properties = {}, required = {} },
    handler = function(_)
      if type(_G.PakettiMCPReloadTools) ~= "function" then return err("PakettiMCPReloadTools not loaded") end
      local n = _G.PakettiMCPReloadTools()
      return text(string.format("ok: reloaded %s MCP tools in place", tostring(n)))
    end,
  },
  {
    name = "paketti_eval_json",
    description = "Like paketti_eval but returns a structured JSON object {ok, type, value, stdout, error}. Captures print() output so you can see what the code logged.",
    inputSchema = { type = "object", properties = { code = { type = "string", description = "Lua code to run" } }, required = {"code"} },
    handler = function(args)
      local code = args and args.code
      if type(code) ~= "string" then return err("missing 'code' string") end
      local chunk, cerr = loadstring(code)
      if not chunk then return text(json.encode({ ok = false, error = "compile error: " .. tostring(cerr) })) end
      local out = {}
      local old_print = print
      _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
        out[#out + 1] = table.concat(parts, "\t")
      end
      local ok, ret = pcall(chunk)
      _G.print = old_print
      return text(json.encode({
        ok     = ok,
        type   = ok and type(ret) or json.null,
        value  = ok and tostring(ret) or json.null,
        error  = (not ok) and tostring(ret) or json.null,
        stdout = table.concat(out, "\n"),
      }))
    end,
  },
  {
    name = "paketti_screenshot",
    description = "Capture a screenshot of the Renoise front window (a Paketti dialog, the pattern editor, etc.) to a PNG path, so it can be shown/reviewed. Returns the path.",
    inputSchema = { type = "object", properties = { path = { type = "string", description = "Output PNG path (default /tmp/paketti_screenshot.png)" } }, required = {} },
    handler = function(args)
      local path = (args and args.path) or "/tmp/paketti_screenshot.png"
      capture_renoise(path)  -- fires detached; never blocks
      return text("ok: capture fired to " .. path .. " (ready in ~200ms; read the PNG after a short wait)")
    end,
  },
  {
    name = "paketti_read_file",
    description = "Read a file from disk and return its contents as text.",
    inputSchema = { type = "object", properties = { path = { type = "string" } }, required = {"path"} },
    handler = function(args)
      local p = args and args.path
      if type(p) ~= "string" then return err("missing 'path'") end
      local f = io.open(p, "rb")
      if not f then return err("cannot open: " .. p) end
      local data = f:read("*a"); f:close()
      return text(data)
    end,
  },
  {
    name = "paketti_write_file",
    description = "Write text to a file on disk (overwrites). Returns bytes written.",
    inputSchema = { type = "object", properties = { path = { type = "string" }, content = { type = "string" } }, required = {"path", "content"} },
    handler = function(args)
      local p = args and args.path
      local c = args and args.content
      if type(p) ~= "string" or type(c) ~= "string" then return err("need 'path' and 'content' strings") end
      local f = io.open(p, "wb")
      if not f then return err("cannot write: " .. p) end
      f:write(c); f:close()
      return text(string.format("ok: wrote %d bytes to %s", #c, p))
    end,
  },
}
