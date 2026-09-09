-- Pure file-level checks for the TX16W invariants that have previously
-- regressed in real Cyclone exports. Run with: lua tests/tx16w_export_regression.lua <folder>

local root = assert(arg[1], "usage: lua tests/tx16w_export_regression.lua <export-folder>")
local unknown_disk_refs = false
for i = 2, #arg do
  if arg[i] == "unknown-disk-refs" then unknown_disk_refs = true end
end

local function read(path)
  local f = assert(io.open(path, "rb"), "missing " .. path)
  local data = f:read("*a")
  f:close()
  return data
end

local function has(data, needle)
  return data:find(needle, 1, true) ~= nil
end

local function check(name, condition)
  assert(condition, "TX16W regression failed: " .. name)
  io.write("ok: " .. name .. "\n")
end

local function count(data, needle)
  local n = 0
  for _ in data:gmatch(needle) do n = n + 1 end
  return n
end

--------------------------------------------------------------------------------
-- The drumkit invariants. The failure these exist to prevent: a kit spread over
-- several disks where the voices and the performance all sat on disk 1 while
-- the waves were scattered by size, so disk 1's voices referenced waves on
-- disk 2 and disk 2 carried no voice or performance at all. Cyclone loaded
-- disk 1 fine, loaded disk 2 with zero performances, and could resolve neither.
--
-- Nothing in the Yamaha library corpus is built that way. Every disk must be
-- self-contained: its own voice, its own performance, and the waves that voice
-- plays, so it loads on its own with nothing missing.
--------------------------------------------------------------------------------

local function u16(d, o) return d:byte(o) + d:byte(o + 1) * 256 end
local function u32be(d, o)
  return ((d:byte(o) * 256 + d:byte(o + 1)) * 256 + d:byte(o + 2)) * 256 + d:byte(o + 3)
end

-- Root directory of a FAT12 720K image.
local function dir_of(img)
  local bps, spf = u16(img, 12), u16(img, 23)
  local base = (1 + 2 * spf) * bps
  local files, label, order = {}, nil, {}
  for i = 0, u16(img, 18) - 1 do
    local e = img:sub(base + i * 32 + 1, base + i * 32 + 32)
    if e:byte(1) == 0 then break end
    if e:byte(1) ~= 0xE5 then
      local stem = e:sub(1, 8):gsub(" +$", "")
      local ext  = e:sub(9, 11):gsub(" +$", "")
      if e:byte(12) % 16 >= 8 then label = (stem .. ext):gsub(" +$", "")
      else
        files[stem] = ext
        order[#order + 1] = stem .. "." .. ext
      end
    end
  end
  return files, label, order
end

-- Every 20-byte Wave/Voic/Perf reference: tag, name, disk field.
local function refs_of(data)
  local out, i = {}, 1
  while true do
    local j
    for _, tag in ipairs({ "Wave", "Voic", "Perf" }) do
      local k = data:find(tag, i, true)
      if k and (not j or k < j) then j = k end
    end
    if not j then break end
    if j + 27 <= #data and u32be(data, j + 4) == 20 then
      out[#out + 1] = {
        tag  = data:sub(j, j + 3),
        name = data:sub(j + 8, j + 15):gsub("%z+$", ""),
        disk = data:sub(j + 20, j + 27):gsub("%z+$", ""),
      }
    end
    i = j + 4
  end
  return out
end

-- Collect every disk image in the folder.
local images = {}
for i = 1, 99 do
  local f = io.open(string.format("%s/TX16W__DISK%d.img", root, i), "rb")
  if not f then break end
  local d = f:read("*a") ; f:close()
  images[i] = d
end
check("at least one disk image was written", #images >= 1)

local total_waves, total_splits = 0, 0
for i, img in ipairs(images) do
  local files, label, order = dir_of(img)
  local tag = "disk " .. i

  check(tag .. " is 720K", #img == 737280)
  check(tag .. " carries a volume label", label ~= nil and label ~= "")

  -- what kinds of file are on it
  local voices, perfs, waves = {}, {}, 0
  for _, entry in ipairs(order) do
    local stem, ext = entry:match("^([^%.]+)%.(.+)$")
    local kind = ext:sub(1, 1)
    if kind == "O" then voices[#voices + 1] = entry
    elseif kind == "P" then perfs[#perfs + 1] = entry
    elseif kind == "C" then waves = waves + 1 end
  end
  total_waves = total_waves + waves

  -- THE invariant: a disk that carries waves must be able to play them.
  check(tag .. " has at least one voice", #voices >= 1)
  check(tag .. " has at least one performance", #perfs >= 1)

  -- and every reference on it must resolve on this same disk
  for _, entry in ipairs(order) do
    local ext = entry:match("%.(.+)$")
    if ext:sub(1, 1) == "O" or ext:sub(1, 1) == "P" then
      local stem = entry:match("^([^%.]+)")
      local data = read(root .. "/files/" .. entry)
      local n = 0
      for _, r in ipairs(refs_of(data)) do
        n = n + 1
        check(tag .. " " .. entry .. " reference '" .. r.name .. "' has no space",
          not r.name:find(" ", 1, true))
        check(tag .. " " .. entry .. " reference '" .. r.name .. "' is on this disk",
          files[r.name] ~= nil)
        check(tag .. " " .. entry .. " reference '" .. r.name .. "' names this disk",
          r.disk == label)
      end
      if ext:sub(1, 1) == "O" then
        check(tag .. " " .. entry .. " has at most 40 splits", n <= 40)
        total_splits = total_splits + n
      end
    end
  end

  -- performance reaches both the Renoise channel and the percussion convention
  local perf = read(root .. "/files/" .. perfs[1])
  check(tag .. " performance answers on MIDI channel 1", perf:byte(65) == 0)
  check(tag .. " performance answers on MIDI channel 10", perf:byte(121) == 9)
  check(tag .. " performance has a program change", has(perf, "PChg"))
end

check("every wave is on some disk", total_waves == 120)
check("every wave is played by some voice", total_splits == 120)

-- Disk 1 carries the setup: the catalogue of the whole kit, every wave listed
-- against the disk it lives on. That is where the library disks put theirs.
local files1, label1 = dir_of(images[1])
check("disk 1 carries the setup", files1["TX16W_DR"] ~= nil)
local setup = read(root .. "/files/TX16W_DR.X01")
local catalogued, named = 0, {}
for _, r in ipairs(refs_of(setup)) do
  if r.tag == "Wave" then catalogued = catalogued + 1 ; named[r.name] = r.disk end
end
check("the setup catalogues all 120 waves", catalogued == 120)

for i, img in ipairs(images) do
  local files, label = dir_of(img)
  for stem, ext in pairs(files) do
    if ext:sub(1, 1) == "C" then
      check("the setup places " .. stem .. " on " .. label, named[stem] == label)
    end
  end
end

print("TX16W export regression checks passed")

local rx2 = arg[2]
if rx2 and rx2 ~= "unknown-disk-refs" then
  local rp = read(rx2 .. "/files/TX16W_RX.P01")
  local ro = read(rx2 .. "/files/TX16W_RX.O01")
  local ri = read(rx2 .. "/TX16W__DISK1.img")
  check("RX2 disk is 720K", #ri == 737280)
  check("RX2 performance has channel 1", rp:byte(65) == 0)
  check("RX2 performance has channel 10", rp:byte(121) == 9)
  check("RX2 performance has program 0", has(rp, "PChg"))
  check("RX2 voice has 24 wave splits", count(ro, "Wave") == 24)
  check("RX2 voice references disk 1 literally", has(ro, "TX16W_1"))
end

local melodic = arg[3]
if melodic and melodic ~= "unknown-disk-refs" then
  local mo = read(melodic .. "/files/TX16W_ME.O01")
  local mw = read(melodic .. "/files/SYNTHAAA.C01")
  local mi = read(melodic .. "/TX16W__DISK1.img")
  check("melodic voice starts at Typhoon key 1", has(mo, string.char(1, 120, 0, 127)))
  check("melodic voice terminates at Typhoon key 121", has(mo, string.char(121, 0)))
  check("melodic wave stem is NUL-terminated", has(mo, "SYNTH\0"))
  check("melodic DOS directory uses 8.3 filename", has(mi, "SYNTH   C01"))
  check("looped melodic wave has INST metadata", has(mw, "INST"))
  check("looped melodic wave has MARK metadata", has(mw, "MARK"))
end
