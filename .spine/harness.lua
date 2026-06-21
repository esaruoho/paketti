-- paketti-harness.lua — run Paketti's REAL registration code under a mocked Renoise
-- and capture every keybinding / menu entry / MIDI mapping with its FULLY-RESOLVED
-- name (for-loops expanded, concatenation done, wrappers honoured) — the truth a
-- text scan or stale XML can't give. Also records which files load (robust) vs
-- error (brittle). Run with luajit (Lua 5.1 semantics, like Renoise).
--
--   luajit paketti-harness.lua /Users/esaruoho/work/paketti  > out.json

local BUNDLE = (arg[1] or "/Users/esaruoho/work/paketti")
if BUNDLE:sub(-1) ~= "/" then BUNDLE = BUNDLE .. "/" end

-- ── capture sinks ────────────────────────────────────────────────────────────
local CAP = { keybinding = {}, menu_entry = {}, midi_mapping = {} }
local SEEN = { keybinding = {}, midi_mapping = {} }   -- Renoise THROWS on duplicate
local DUPS = { keybinding = {}, midi_mapping = {} }    -- names registered 2+ times
local FILES = {}            -- { {module=, ok=, err=} }

local function record(kind, name)
  if type(name) == "table" then name = tostring(name) end
  name = name or "(noname)"
  CAP[kind][#CAP[kind] + 1] = name
  -- Replicate Renoise's duplicate guard: add_keybinding / add_midi_mapping error on
  -- the 2nd registration of a name ("invalid ... entry: 'X' was already added") —
  -- fatal at load. (Menu entries may legitimately repeat, so we don't track those.)
  if SEEN[kind] then
    if SEEN[kind][name] then DUPS[kind][#DUPS[kind] + 1] = name
    else SEEN[kind][name] = true end
  end
end

-- ── permissive magic stub: indexes/calls/concats/etc. never crash ────────────
-- Lua 5.1/LuaJIT won't compare table<number even with __lt (both operands must
-- share the metamethod), so scalar-looking fields must return REAL numbers.
local SCALAR_KEYS = { value = true, count = true, size = true, length = true,
                      index = true, number_of_lines = true, line = true }
local function magic(name)
  return setmetatable({}, {
    __index = function(_, k)
      if k == "value" then
        -- a preference's .value: path/name-like → string (for :match/..), else number
        if name:match("[Pp]ath") or name:match("XRNI") or name:match("[Ff]older")
           or name:match("[Ff]ile") or name:match("[Dd]ir") or name:match("[Nn]ame")
           or name:match("[Tt]ext") or name:match("[Ss]tring") then
          return ""
        end
        return 0
      end
      if type(k) == "string" and (SCALAR_KEYS[k]
          or k:match("_index$") or k:match("_count$") or k:match("_size$")) then
        return 0                                  -- numeric so comparisons work
      end
      return magic(name .. "." .. tostring(k))
    end,
    __newindex = function() end,
    __call     = function(_, ...) return magic(name .. "()") end,
    __concat   = function(a, b) return tostring(a) .. tostring(b) end,
    __tostring = function() return name end,
    __add = function() return 0 end, __sub = function() return 0 end,
    __mul = function() return 0 end, __div = function() return 0 end,
    __mod = function() return 0 end, __pow = function() return 0 end,
    __unm = function() return 0 end, __len = function() return 0 end,
    __lt  = function() return false end, __le = function() return false end,
    __eq  = function() return false end,
  })
end

-- Renoise extends the `table` library; provide the ones Paketti uses at load time.
table.create   = table.create   or function(t) return t or {} end
table.copy      = table.copy     or function(t) local r = {} if type(t) == "table" then for k, v in pairs(t) do r[k] = v end end return r end
table.rcopy     = table.rcopy    or function(t) local function dc(x) if type(x) ~= "table" then return x end local r = {} for k, v in pairs(x) do r[k] = dc(v) end return r end return dc(t) end
table.clear     = table.clear    or function(t) if type(t) == "table" then for k in pairs(t) do t[k] = nil end end return t end
table.count     = table.count    or function(t) local n = 0 if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end return n end
table.find      = table.find     or function(t, v) if type(t) == "table" then for i, x in ipairs(t) do if x == v then return i end end end return nil end
table.is_empty  = table.is_empty or function(t) return type(t) ~= "table" or next(t) == nil end

-- ── the recording tool (what renoise.tool() returns) ─────────────────────────
local recording_tool = setmetatable({
  bundle_path = BUNDLE,
  add_keybinding   = function(self, a) record("keybinding",   a and a.name) ; return true end,
  add_menu_entry   = function(self, a) record("menu_entry",   a and a.name) ; return true end,
  add_midi_mapping = function(self, a) record("midi_mapping", a and a.name) ; return true end,
}, { __index = function(_, k) return magic("tool." .. tostring(k)) end })

-- ── the renoise mock ─────────────────────────────────────────────────────────
renoise = setmetatable({
  tool = function() return recording_tool end,
  API_VERSION = 6.2,                       -- numeric: version checks must compare
  RENOISE_VERSION = "3.5.0",               -- string: string.match() needs a string
  app = function() return magic("app") end,
  song = function() return magic("song") end,
  ApplicationWindow = magic("ApplicationWindow"),
}, { __index = function(_, k) return magic("renoise." .. tostring(k)) end })

-- Renoise OOP: `class "Foo"` then `function Foo:m()`. Make Foo a real table so
-- method assignment works, callable so Foo() instantiates.
function class(name)
  local c = setmetatable({}, {
    __index = function() return function() end end,
    __call  = function() return setmetatable({}, { __index = function() return function() end end }) end,
  })
  if type(name) == "string" then rawset(_G, name, c) end
  return function() return c end           -- supports `class "Foo"(Parent)`
end

-- Renoise extends os/io with functions standard Lua lacks (os.filenames,
-- os.dirnames, os.currentdir, …). Missing fields → magic (real ones stay real).
setmetatable(os, { __index = function(_, k) return magic("os." .. tostring(k)) end })
setmetatable(io, { __index = function(_, k) return magic("io." .. tostring(k)) end })
-- A magic stub can reach io.open as a "path"; treat non-string paths as "no file".
local _real_open = io.open
io.open = function(p, ...) if type(p) ~= "string" then return nil, "mock" end return _real_open(p, ...) end

-- Undefined globals → magic stub (instead of nil → "attempt to call nil").
setmetatable(_G, { __index = function(_, k) return magic(k) end })

-- ── isolate each module load: wrap dofile (timed_require calls it) ────────────
local real_loadfile = loadfile
local function isolated_dofile(path)
  local mod = tostring(path):match("([^/]+)%.lua$") or tostring(path)
  local chunk, lerr = real_loadfile(path)
  if not chunk then
    FILES[#FILES + 1] = { module = mod, ok = false, err = "load: " .. tostring(lerr) }
    return
  end
  local ok, rerr = pcall(chunk)
  FILES[#FILES + 1] = { module = mod, ok = ok, err = ok and nil or tostring(rerr) }
end
_G.dofile = isolated_dofile

-- ── run Paketti exactly as Renoise would: load main.lua ──────────────────────
isolated_dofile(BUNDLE .. "main.lua")

-- Flush any queued menu entries if Paketti didn't reach its own flush.
if type(_G.PakettiFlushMenuEntries) == "function" and _G.PakettiPendingMenuEntries
   and #_G.PakettiPendingMenuEntries > 0 then
  pcall(_G.PakettiFlushMenuEntries)
end

-- ── bucket by Paketti's OWN region taxonomy (PakettiMenuContextPrefKey) ───────
local function region_of(name)
  if type(_G.PakettiMenuContextPrefKey) == "function" then
    local ok, r = pcall(_G.PakettiMenuContextPrefKey, name)
    if ok and r then return r end
  end
  local seg = tostring(name):gsub("^%-%-", ""):match("^([^:]+):")
  return seg or "Uncategorized"
end

-- ── minimal JSON encoder ─────────────────────────────────────────────────────
local function jstr(s)
  s = tostring(s):gsub('[%z\1-\31\\"]', function(c)
    local map = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
    return map[c] or string.format('\\u%04x', c:byte())
  end)
  return '"' .. s .. '"'
end
local function jarr(t, f)
  local p = {}
  for i = 1, #t do p[i] = f(t[i]) end
  return '[' .. table.concat(p, ',') .. ']'
end

-- dedupe: a name registered twice is ONE binding (Renoise keys by name).
local function uniq(list)
  local seen, u = {}, {}
  for _, n in ipairs(list) do if not seen[n] then seen[n] = true; u[#u + 1] = n end end
  return u
end
local U = { keybinding = uniq(CAP.keybinding), menu_entry = uniq(CAP.menu_entry),
            midi_mapping = uniq(CAP.midi_mapping) }

-- per-region per-kind tallies from UNIQUE resolved names
local regions = {}
local function tally(kind)
  for _, name in ipairs(U[kind]) do
    local r = region_of(name)
    regions[r] = regions[r] or { keybinding = 0, menu_entry = 0, midi_mapping = 0 }
    regions[r][kind] = regions[r][kind] + 1
  end
end
tally("keybinding"); tally("menu_entry"); tally("midi_mapping")

-- assemble JSON
local out = {}
out[#out+1] = '{'
out[#out+1] = '"bundle":' .. jstr(BUNDLE) .. ','
out[#out+1] = '"totals":{"keybinding":' .. #CAP.keybinding ..
              ',"menu_entry":' .. #CAP.menu_entry ..
              ',"midi_mapping":' .. #CAP.midi_mapping .. '},'
out[#out+1] = '"unique":{"keybinding":' .. #U.keybinding ..
              ',"menu_entry":' .. #U.menu_entry ..
              ',"midi_mapping":' .. #U.midi_mapping .. '},'
-- Paketti's own runtime counters (ground truth it computed itself)
local par = _G.PakettiActualRegistrations or {}
out[#out+1] = '"paketti_self_counts":{"keybindings":' .. (tonumber(par.keybindings) or 0) ..
              ',"keybindings_skipped":' .. (tonumber(par.keybindings_skipped) or 0) ..
              ',"midi_mappings":' .. (tonumber(par.midi_mappings) or 0) ..
              ',"menu_tally_total":' .. (tonumber(_G.PakettiMenuEntryContextTally and _G.PakettiMenuEntryContextTally.__total) or 0) .. '},'
-- regions
local rparts = {}
for r, c in pairs(regions) do
  rparts[#rparts+1] = jstr(r) .. ':{"keybinding":' .. c.keybinding ..
                      ',"menu_entry":' .. c.menu_entry ..
                      ',"midi_mapping":' .. c.midi_mapping ..
                      ',"total":' .. (c.keybinding + c.menu_entry + c.midi_mapping) .. '}'
end
out[#out+1] = '"regions":{' .. table.concat(rparts, ',') .. '},'
-- the actual NAMES per orifice (for cross-orifice coverage analysis)
out[#out+1] = '"names":{"keybinding":' .. jarr(U.keybinding, jstr) ..
              ',"menu_entry":' .. jarr(U.menu_entry, jstr) ..
              ',"midi_mapping":' .. jarr(U.midi_mapping, jstr) .. '},'
-- files (robust vs brittle)
local fparts = {}
for _, f in ipairs(FILES) do
  fparts[#fparts+1] = '{"module":' .. jstr(f.module) .. ',"ok":' .. tostring(f.ok) ..
                      (f.err and (',"err":' .. jstr(f.err:sub(1, 240))) or '') .. '}'
end
out[#out+1] = '"files":[' .. table.concat(fparts, ',') .. '],'
local nok, nbad = 0, 0
for _, f in ipairs(FILES) do if f.ok then nok = nok + 1 else nbad = nbad + 1 end end
out[#out+1] = '"file_stats":{"loaded":' .. nok .. ',"errored":' .. nbad .. ',"total":' .. #FILES .. '},'
-- duplicate registrations (these THROW in real Renoise even though the mock dedups)
out[#out+1] = '"duplicates":{"keybinding":' .. jarr(DUPS.keybinding, jstr) ..
              ',"midi_mapping":' .. jarr(DUPS.midi_mapping, jstr) .. '}'
out[#out+1] = '}'
local fh = io.open(arg[2] or "/tmp/spine.json", "w")
fh:write(table.concat(out, "\n"))
fh:close()
