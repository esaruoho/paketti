-- localroom.lua — how many more chunk-level `local`s each Lua file can still hold.
--
-- Lua 5.1 (and LuaJIT, and Renoise) allow at most 200 local variables live at once in
-- any one function — and a .lua file IS a function (the "main chunk"), so every
-- top-level `local` in a Paketti module spends one of those 200. Cross the line and
-- the file does not compile at all: Renoise reports a brittle file and aborts the
-- whole tool load. There is no partial failure and no runtime warning.
--
-- This probe appends N dummy locals to each file and asks the real compiler whether
-- it still fits, so the number is the compiler's answer, not an estimate.
--
--   lua .spine/localroom.lua <repo_root> <threshold> <out.json>
--
-- Emits every file with less than <threshold> locals of headroom left.

local root, threshold, out = ..., select(2, ...), select(3, ...)
threshold = tonumber(threshold) or 25
local compile = loadstring or load

local function pad(n)
  local t = {}
  for i = 1, n do t[i] = "local __lr" .. i .. "=" .. i end
  return "\n" .. table.concat(t, "\n") .. "\n"
end

-- fits(src, n): does the chunk still compile with n extra chunk-level locals?
-- Only a "too many local variables" error counts as a miss. A file that ends in a
-- top-level `return` (base64.lua, the PakettiMCP modules, rx.lua) rejects ANY appended
-- statement with "'<eof>' expected" — that is the probe's own fault, not a real ceiling.
local function fits(src, n)
  local ok, err = compile(src .. pad(n))
  if ok then return true end
  err = tostring(err)
  --  Lua 5.1/5.4: "too many local variables (limit is 200) in main function"
  --  LuaJIT     : "main function has more than 200 local variables"
  local hit = err:find("too many local variables", 1, true)
             or err:find("more than 200 local variables", 1, true)
  return not hit
end

local function headroom(src)
  if fits(src, threshold) then return nil end          -- plenty of room; don't spend time
  local lo, hi = 0, threshold                          -- exact answer only for the tight ones
  while lo < hi do
    local mid = math.floor((lo + hi + 1) / 2)
    if fits(src, mid) then lo = mid else hi = mid - 1 end
  end
  return lo
end

local files = {}
local p = io.popen("find -L '" .. root .. "' -name '*.lua' -not -path '*/.git/*' -not -path '*/.spine/*'")
for line in p:lines() do files[#files + 1] = line end
p:close()

local rows = {}
for _, path in ipairs(files) do
  local f = io.open(path, "rb")
  if f then
    local src = f:read("*a"); f:close()
    if compile(src) then                                -- syntax errors are the harness's job
      local room = headroom(src)
      if room then
        rows[#rows + 1] = string.format('{"file":%q,"headroom":%d}',
          path:gsub("^" .. root:gsub("([^%w])", "%%%1") .. "/?", ""), room)
      end
    end
  end
end

table.sort(rows)
local o = io.open(out, "w")
o:write("[", table.concat(rows, ","), "]")
o:close()
