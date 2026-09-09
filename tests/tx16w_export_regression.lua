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

local p01 = read(root .. "/files/TX16W_DR.P01")
local o01 = read(root .. "/files/TX16W_DR.O01")
local o02 = read(root .. "/files/TX16W_DR.O02")
local o03 = read(root .. "/files/TX16W_DR.O03")
-- The images are named after their volume label, so discover them.
local imgs = {}
do
  local pipe = assert(io.popen('ls "' .. root .. '"/*.img 2>/dev/null'))
  for line in pipe:lines() do imgs[#imgs + 1] = line end
  pipe:close()
  table.sort(imgs)
end
check("two disk images were written", #imgs == 2)

-- Every IFF object must be exactly as long as its FORM header says. A file
-- whose last chunk is a 20-byte reference is where an off-by-one in any
-- rewriting step shows up, and a one-byte-short .P01 or .X01 looks fine in a
-- hex dump.
do
  local pipe = assert(io.popen('ls "' .. root .. '"/files/*.O?? "' .. root
    .. '"/files/*.P?? "' .. root .. '"/files/*.X?? 2>/dev/null'))
  local n = 0
  for line in pipe:lines() do
    local d = read(line)
    if d:sub(1, 4) == "FORM" then
      local declared = ((d:byte(5) * 256 + d:byte(6)) * 256 + d:byte(7)) * 256 + d:byte(8) + 8
      check(line:match("[^/]+$") .. " is exactly as long as its FORM header says",
        declared == #d)
      n = n + 1
    end
  end
  pipe:close()
  check("every voice, performance and setup was length-checked", n >= 4)
end
local disk1 = read(imgs[1])
local disk2 = read(imgs[2])

-- Cyclone has to find the disk a reference names. Every one of the 18 known-good
-- library images carries an ALPHANUMERIC volume label and lives in a file whose
-- name starts with that label. Paketti used to write label "TX16W_2" into
-- "TX16W__DISK2.img" - an underscore the corpus never uses, in a filename that
-- does not begin with the label.
do
  local function label_of(img)
    local bps = img:byte(12) + img:byte(13) * 256
    local spf = img:byte(23) + img:byte(24) * 256
    local base = (1 + 2 * spf) * bps
    for i = 0, (img:byte(18) + img:byte(19) * 256) - 1 do
      local e = img:sub(base + i * 32 + 1, base + i * 32 + 32)
      if e:byte(1) == 0 then break end
      if e:byte(1) ~= 0xE5 and e:byte(12) % 16 >= 8 then
        return (e:sub(1, 11):gsub(" +$", ""))
      end
    end
  end
  for i, img in ipairs({ disk1, disk2 }) do
    local lab = label_of(img)
    local file = imgs[i]:match("([^/]+)%.img$")
    check("disk " .. i .. " has a volume label", lab ~= nil and lab ~= "")
    check("disk " .. i .. " label '" .. tostring(lab) .. "' is alphanumeric",
      lab:match("^[A-Za-z0-9]+$") ~= nil)
    check("disk " .. i .. " image file '" .. file .. "' is named after its label",
      file:upper() == lab:upper())
  end
end

check("disk 1 is 720K", #disk1 == 737280)
check("disk 2 is 720K", #disk2 == 737280)
check("performance has channel 1", p01:byte(65) == 0)
check("performance has channel 10", p01:byte(121) == 9)
check("performance contains all three bounded voices", count(p01, "Entr") == 6)
check("performance has program 0", has(p01, "PChg"))
check("each bounded voice has at most 40 splits", count(o01, "Wave") <= 40
  and count(o02, "Wave") <= 40 and count(o03, "Wave") <= 40)
check("all 120 splits are present", count(o01, "Wave") + count(o02, "Wave")
  + count(o03, "Wave") == 120)
local voices = o01 .. o02 .. o03
if unknown_disk_refs then
  -- Known-good chained Cyclone/Typhoon images use FF in the wave and voice
  -- reference fields. The physical disk labels still identify the media.
  check("chained voices use unknown disk markers", not has(voices, "TX16W_1")
    and not has(voices, "TX16W_2")
    and has(voices, string.rep("\255", 8)))
  check("performance uses unknown disk markers", not has(p01, "TX16WD1")
    and not has(p01, "TX16WD2")
    and has(p01, string.rep("\255", 8)))
else
  check("disk 2 label is referenced literally", has(voices, "TX16WD2"))
  check("disk 2 reference is NUL-terminated", has(voices, "TX16WD2\0"))
end
check("disk 2 contains HIBONGO", has(disk2, "HIBONGO"))
check("short disk-2 wave name is NUL-terminated", has(voices, "HIBONGO\0"))
if not unknown_disk_refs then
  check("voice references disk 1 literally", has(voices, "TX16WD1"))
end

--------------------------------------------------------------------------------
-- Structural checks. These are the two invariants that made the 120-sample
-- drumkit fail in Cyclone with "Missing wave VIBSLAP" while every substring
-- check above still passed.
--
-- Both were established by measuring the known-good Typhoon library disks
-- (sd001-sd024, 859 reference chunks):
--   * 0 references contain a space, 273 contain an underscore, and no DOS
--     filename carries an embedded space -- the 8-byte reference name is
--     byte-identical to the DOS basename.
--   * 538 .O* and 417 .P* references carry the 0xFF unknown-disk marker; only
--     the .X01 setup ever names a diskette (78 references, "SD009".."SD012").
--     The setup is the disk catalogue: without it nothing on disk 2 resolves.
--------------------------------------------------------------------------------

local function u16(d, o) return d:byte(o) + d:byte(o + 1) * 256 end
local function u32be(d, o)
  return ((d:byte(o) * 256 + d:byte(o + 1)) * 256 + d:byte(o + 2)) * 256 + d:byte(o + 3)
end

-- Root directory of a FAT12 720K image: { ["NAME.EXT"] = true }, plus the label.
local function dir_of(img)
  local bps, spf = u16(img, 12), u16(img, 23)
  local root = (1 + 2 * spf) * bps
  local names, label = {}, nil
  for i = 0, u16(img, 18) - 1 do
    local e = img:sub(root + i * 32 + 1, root + i * 32 + 32)
    if e:byte(1) == 0 then break end
    if e:byte(1) ~= 0xE5 then
      local base = e:sub(1, 8):gsub(" +$", "")
      if e:byte(12) % 16 >= 8 then label = (base .. e:sub(9, 11)):gsub(" +$", "")
      else names[base .. "." .. e:sub(9, 11)] = true ; names[base] = true end
    end
  end
  return names, label
end

-- Every 20-byte Wave/Voic/Perf reference: name, 4-byte id, 8-byte disk field.
local function refs_of(data)
  local out, i = {}, 1
  while true do
    local j = data:find("Wave", i, true) or data:find("Voic", i, true)
    local k = data:find("Voic", i, true)
    if k and (not j or k < j) then j = k end
    local m = data:find("Perf", i, true)
    if m and (not j or m < j) then j = m end
    if not j then break end
    if j + 27 <= #data and u32be(data, j + 4) == 20 then
      out[#out + 1] = {
        tag  = data:sub(j, j + 3),
        name = data:sub(j + 8, j + 15):gsub("%z+$", ""),
        disk = data:sub(j + 20, j + 27),
      }
    end
    i = j + 4
  end
  return out
end

local d1names, d1label = dir_of(disk1)
local d2names, d2label = dir_of(disk2)

-- 1. Reference names must be real DOS filenames. The "_" -> " " conversion made
--    49 of the 120 drumkit references name a wave that exists on no disk.
local nospace, unresolved = true, {}
for _, src in ipairs({ o01, o02, o03, p01 }) do
  for _, r in ipairs(refs_of(src)) do
    if r.name:find(" ", 1, true) then nospace = false end
    if r.tag == "Wave" and not d1names[r.name] and not d2names[r.name] then
      unresolved[#unresolved + 1] = r.name
    end
  end
end
check("no reference name contains a space", nospace)
check("every wave reference names a file that exists on some disk",
  #unresolved == 0)

-- 2. The .X01 setup must exist and must name the diskette every wave lives on.
local setup = read(root .. "/files/TX16W_DR.X01")
check("the setup is on disk 1", d1names["TX16W_DR.X01"] ~= nil)
check("disk 1 carries a volume label", d1label ~= nil and d1label ~= "")
check("disk 2 carries a volume label", d2label ~= nil and d2label ~= "")

local named_for, setup_waves = {}, 0
for _, r in ipairs(refs_of(setup)) do
  if r.tag == "Wave" then
    setup_waves = setup_waves + 1
    named_for[r.name] = r.disk:gsub("%z+$", "")
  end
end
check("the setup catalogues all 120 waves", setup_waves == 120)

local mislabelled = {}
for name in pairs(d2names) do
  local base = name:match("^([^%.]+)%.C01$")
  if base and named_for[base] ~= d2label then
    mislabelled[#mislabelled + 1] = base .. "->" .. tostring(named_for[base])
  end
end
check("the setup points every disk-2 wave at disk 2 by name (was: VIBSLAP missing)",
  #mislabelled == 0)

for name in pairs(d1names) do
  local base = name:match("^([^%.]+)%.C01$")
  if base then
    check("the setup points " .. base .. " at disk 1", named_for[base] == d1label)
    break
  end
end

-- Wave invariants. Typhoon repairs a wave that does not meet these and says so
-- on load: "wave length / loop adjusted", then "data after loop will not be
-- loaded". All 38 drum waves on the known-good disk sd007 meet them: an exact
-- multiple of 64 frames, INST and MARK always present, and for a wave that does
-- not loop a dummy marker pair at the very end so no data sits after the loop.
local function u32be2(d, o)
  return ((d:byte(o) * 256 + d:byte(o + 1)) * 256 + d:byte(o + 2)) * 256 + d:byte(o + 3)
end
local waves_checked = 0
for _, disk in ipairs({ disk1, disk2 }) do
  local bps, spf = u16(disk, 12), u16(disk, 23)
  local base = (1 + 2 * spf) * bps
  for i = 0, u16(disk, 18) - 1 do
    local e = disk:sub(base + i * 32 + 1, base + i * 32 + 32)
    if e:byte(1) == 0 then break end
    if e:byte(1) ~= 0xE5 and e:byte(12) % 16 < 8 and e:sub(9, 9) == "C" then
      local name = e:sub(1, 8):gsub(" +$", "") .. "." .. e:sub(9, 11)
      local w = read(root .. "/files/" .. name)
      local seen, frames, loop_end, play = {}, nil, nil, nil
      local j = 13
      while j + 8 <= #w do
        local t, l = w:sub(j, j + 3), u32be2(w, j + 4)
        local b = w:sub(j + 8, j + 7 + l)
        seen[t] = true
        if t == "COMM" then frames = u32be2(b, 3) end
        if t == "INST" then play = b:byte(9) * 256 + b:byte(10) end
        if t == "MARK" then loop_end = u32be2(b, 23) end
        j = j + 8 + l + (l % 2)
      end
      check(name .. " carries INST and MARK", seen.INST and seen.MARK)
      check(name .. " length is a multiple of 64", frames % 64 == 0)
      if play == 0 then
        check(name .. " has no sample data after the loop", loop_end == frames)
      end
      waves_checked = waves_checked + 1
    end
  end
end
check("every wave was checked", waves_checked == 120)

-- ONE GROUP PER WAVE, ONE KEY PER GROUP.
-- 587 groups across the 188 voices on the Yamaha library disks; 538 hold
-- exactly one wave and the rest are empty terminators. Not one uses a second
-- split point. Paketti used to put 40 waves into a single group as split
-- points - legal per the manual, but with zero real-world examples - and a
-- whole stretch of the keyboard played one sample.
do
  local function u32b(d, o)
    return ((d:byte(o) * 256 + d:byte(o + 1)) * 256 + d:byte(o + 2)) * 256 + d:byte(o + 3)
  end
  local total_groups, total_waves = 0, 0
  for _, v in ipairs({ "O01", "O02", "O03" }) do
    local d = read(root .. "/files/TX16W_DR." .. v)
    local i = 13
    while i + 8 <= #d do
      local t, ln = d:sub(i, i + 3), u32b(d, i + 4)
      if t == "Grop" then
        total_groups = total_groups + 1
        local b, j, low, high, nw = d:sub(i + 8, i + 7 + ln), 1, nil, nil, 0
        while j + 8 <= #b do
          local tt, ll = b:sub(j, j + 3), u32b(b, j + 4)
          local bb = b:sub(j + 8, j + 7 + ll)
          if tt == "Parm" and not low and ll == 64 then low, high = bb:byte(1), bb:byte(2) end
          if tt == "Splt" then
            local k = 1
            while k + 8 <= #bb do
              local st, sl = bb:sub(k, k + 3), u32b(bb, k + 4)
              if st == "Wave" then nw = nw + 1 end
              k = k + 8 + sl + (sl % 2)
            end
          end
          j = j + 8 + ll + (ll % 2)
        end
        check(v .. " group at key " .. tostring(low) .. " holds exactly one wave", nw == 1)
        check(v .. " group at key " .. tostring(low) .. " covers exactly one key", low == high)
        total_waves = total_waves + nw
      end
      i = i + 8 + ln + (ln % 2)
    end
  end
  check("the kit is 120 groups", total_groups == 120)
  check("each group carries one wave", total_waves == 120)
end

-- Performance entry parameters. Byte 6 is never 0 in the 417 entries on the
-- library disks (it is 1, 2, 3 or 5) and the volume byte is 108 in all of them.
do
  local function u32b(d, o)
    return ((d:byte(o) * 256 + d:byte(o + 1)) * 256 + d:byte(o + 2)) * 256 + d:byte(o + 3)
  end
  local i, n = 1, 0
  while true do
    local j = p01:find("Entr", i, true)
    if not j then break end
    local body = p01:sub(j + 8, j + 7 + u32b(p01, j + 4))
    local parm = body:sub(9, 8 + u32b(body, 5))
    check("performance entry parm is 12 bytes", #parm == 12)
    check("performance entry byte 6 is a value the format uses (not 0)",
      parm:byte(7) >= 1 and parm:byte(7) <= 5)
    check("performance entry volume is 108", parm:byte(4) == 108)
    n = n + 1
    i = j + 4
  end
  check("every performance entry was checked", n == 6)
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
