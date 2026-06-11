-- tools/paketti.lua
-- Paketti-specific verbs for the Sal voice demo. Each tool calls a global
-- function defined elsewhere in Paketti (no MCP-side reimplementation).

local function text(s) return { content = {{ type = "text", text = tostring(s) }} } end
local function err(s)  return { content = {{ type = "text", text = tostring(s) }}, isError = true } end

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
}
