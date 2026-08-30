-- PakettiTyphoon.lua
-- Typhoon voice files (.O01) and 720K DOS floppy images for the Yamaha TX16W.
--
-- Companion to PakettiDWVW.lua, which handles the .C01 waves themselves. This
-- file adds the two things needed to actually get a Renoise drumkit into the
-- sampler:
--
--   1. A .O01 voice file, so the waves land on the keyboard as one playable
--      voice instead of as loose samples you re-map by hand on the front panel.
--   2. A 720K FAT12 floppy image, because Typhoon reads plain DOS 720K disks
--      (unlike the stock Yamaha OS, which needs MSX-DOS).
--
-- The voice format was reverse engineered from 266 real .O01 files across 65
-- TX16W library archives. Structure:
--
--   FORM <size> TYPV
--     VInf <16>   12-byte creator stamp + 4-byte unique object id
--     Grop <size> one keygroup / layer
--       Parm <64>   voice parameters
--       Mod  <6>    modulation routing, 8 of them in 595 of 596 real groups
--       Splt <..>   a key split: [Parm <2> = first key] + Wave <20>
--       ...         splits ascend by key; the FIRST split never carries a Parm
--       Splt <10>   Parm only, no Wave: closes the mapping
--
--   Wave <20> = 8-byte wave name, 4-byte wave id, 8 bytes of 0xFF.
--
-- The 4-byte wave id is the link: it matches the id in the wave's own
-- APPL/"stoc"/Typhoon/VInf chunk. Verified across the corpus - 1174 of 1209
-- wave references resolve to a real .C01 that way, and 1173 of those have a
-- filename equal to the wave name with spaces turned into underscores.

local floor = math.floor

--------------------------------------------------------------------------------
-- Byte helpers
--------------------------------------------------------------------------------

local function be(x, width)          -- big-endian, for IFF/AIFF chunks
  local out = {}
  for shift = width - 8, 0, -8 do out[#out + 1] = string.char(floor(x / 2 ^ shift) % 256) end
  return table.concat(out)
end

local function le(x, width)          -- little-endian, for FAT structures
  local out = {}
  for shift = 0, width - 8, 8 do out[#out + 1] = string.char(floor(x / 2 ^ shift) % 256) end
  return table.concat(out)
end

local function chunk(id, body)
  return id .. be(#body, 32) .. body .. ((#body % 2 == 1) and "\0" or "")
end

--------------------------------------------------------------------------------
-- Typhoon object ids
--------------------------------------------------------------------------------

-- Every Typhoon object carries a 16-byte VInf: a 12-byte creator stamp shared
-- by objects made in the same session, then a 4-byte id unique to the object.
-- 146 distinct stamps appear across the surveyed archives, so the exact value
-- does not matter - only that waves and the voice referencing them agree.

local id_counter = 0

function PakettiTyphoonNewStamp()
  local t = os.time()
  local parts = {}
  for i = 1, 12 do
    parts[i] = string.char((floor(t / 2 ^ ((i - 1) % 24)) + i * 37 + 91) % 256)
  end
  return table.concat(parts)
end

function PakettiTyphoonNewWaveId(stamp, name, seed)
  -- A stable, well-spread 4 bytes. Uniqueness within one kit is what matters,
  -- and the name plus a counter guarantees that.
  id_counter = id_counter + 1
  local h = 2166136261
  local s = tostring(name) .. "/" .. tostring(seed or id_counter) .. "/" .. tostring(stamp)
  for i = 1, #s do
    h = (h + s:byte(i) * 16777619) % 4294967296
    h = (h * 31 + 7) % 4294967296
  end
  return be(h, 32)
end

-- The APPL chunk a Typhoon wave carries, tying a .C01 to its id.
function PakettiTyphoonWaveAppl(stamp, waveid)
  return chunk("APPL", "stoc" .. "\007" .. "Typhoon" .. chunk("VInf", stamp .. waveid))
end

--------------------------------------------------------------------------------
-- Voice (.O01) writer
--------------------------------------------------------------------------------

-- Voice parameters and modulation routing taken verbatim from TR_808.O01, a
-- working factory drum voice. Designing these from scratch would be guesswork;
-- starting from a known-good drum voice is not.
PakettiTyphoonDefaultParm =
  "\000\096\000\127\000\000\003\000\032\096\255\000\050\005\254\001" ..
  "\000\000\003\000\000\007\000\000\127\127\127\127\000\000\255\000" ..
  "\003\255\000\127\255\000\000\205\000\127\127\127\000\061\000\000" ..
  "\000\061\127\000\127\000\000\000\000\004\000\000\000\000\127\000"

PakettiTyphoonDefaultMods = {
  "\005\000\000\015\002\000",
  "\004\007\000\015\000\100",
  "\013\007\000\015\000\000",
  "\011\000\000\015\002\000",
  "\011\001\000\015\000\000",
  "\002\005\001\015\000\000",
  "\000\004\001\015\000\000",
  "\012\003\000\015\000\000",
}

-- Pad or trim a wave name into the 8 bytes a Wave reference holds. The internal
-- name uses spaces where the DOS filename uses underscores.
function PakettiTyphoonWaveName(dosbasename)
  local n = tostring(dosbasename or ""):upper():gsub("_", " ")
  n = n:sub(1, 8)
  return n .. string.rep("\0", 8 - #n)
end

-- splits: array of { key = <first MIDI key>, name = <8.3 basename>, id = <4 bytes> },
--         which must be sorted ascending by key.
-- end_key: the key that closes the mapping (defaults to just past the last split).
-- Builds one Grop chunk: the group's 64-byte parameter block, its 8 modulation
-- entries, then its splits.
--
-- The first four bytes of the parameter block are the group's bottom key, top
-- key, minimum velocity and maximum velocity. That holds for all 36 groups in
-- the factory voices surveyed, and the one voice whose velocity range is not
-- 0-127 is NOISEWAV, which the Typhoon release notes describe as playing "only
-- at higher key velocities" -- it reads 90-127. Everything past byte 3 is left
-- at the known-good defaults, because it has not been decoded.
local function build_group(splits, range)
  local parm = PakettiTyphoonDefaultParm
  if range then
    parm = string.char(
      math.max(0, math.min(127, range.low_key or 0)),
      math.max(0, math.min(127, range.high_key or 96)),
      math.max(0, math.min(127, range.low_vel or 0)),
      math.max(0, math.min(127, range.high_vel or 127))
    ) .. parm:sub(5)
  end

  local parts = { chunk("Parm", parm) }
  for _, m in ipairs(PakettiTyphoonDefaultMods) do
    parts[#parts + 1] = chunk("Mod ", m)
  end

  for i, sp in ipairs(splits) do
    local body = ""
    -- The first split never carries a Parm: it starts at key 0.
    if i > 1 then body = body .. chunk("Parm", string.char(sp.key % 128) .. "\0") end
    -- The 8 bytes after the id are the name of the diskette the wave lives on.
    -- 0xFF means "unknown", which is legal -- real third-party voices use it --
    -- but a real name lets Typhoon ask for the right floppy by name.
    local disk = sp.disk and PakettiTyphoonWaveName(sp.disk) or string.rep("\255", 8)
    body = body .. chunk("Wave", PakettiTyphoonWaveName(sp.name) .. sp.id .. disk)
    parts[#parts + 1] = chunk("Splt", body)
  end

  -- Terminator: a Parm with no Wave, closing the mapping.
  local ek = (range and range.end_key) or math.min(127, splits[#splits].key + 1)
  parts[#parts + 1] = chunk("Splt", chunk("Parm", string.char(ek % 128) .. "\0"))

  return chunk("Grop", table.concat(parts))
end

-- splits: a flat list (one group), or a list of { splits = {...}, range = {...} }
-- when the voice needs several groups -- which is how velocity layers are done,
-- since a group carries the velocity range and a split does not.
function PakettiTyphoonBuildVoice(splits, stamp, voiceid, end_key)
  assert(#splits > 0, "a voice needs at least one split")

  local groups = {}
  if splits[1].splits then
    for _, g in ipairs(splits) do
      if #g.splits > 0 then groups[#groups + 1] = build_group(g.splits, g.range) end
    end
  else
    groups[#groups + 1] = build_group(splits, end_key and {end_key = end_key} or nil)
  end
  assert(#groups > 0, "a voice needs at least one group")

  local body = "TYPV" .. chunk("VInf", stamp .. voiceid) .. table.concat(groups)
  return "FORM" .. be(#body, 32) .. body
end

--------------------------------------------------------------------------------
-- 720K FAT12 floppy image
--------------------------------------------------------------------------------

-- Standard DOS 720K double density geometry, which is what the TX16W drive is:
-- 80 tracks, 2 heads, 9 sectors per track, 512 bytes per sector.
PAKETTI_TYPHOON_SECTOR       = 512
PAKETTI_TYPHOON_SECTORS      = 1440          -- 737280 bytes
PAKETTI_TYPHOON_CLUSTER      = 1024          -- 2 sectors per cluster
PAKETTI_TYPHOON_ROOT_ENTRIES = 112
PAKETTI_TYPHOON_RESERVED     = 1
PAKETTI_TYPHOON_FATS         = 2
PAKETTI_TYPHOON_FAT_SECTORS  = 3

local ROOT_SECTORS = PAKETTI_TYPHOON_ROOT_ENTRIES * 32 / PAKETTI_TYPHOON_SECTOR   -- 7
local DATA_START   = PAKETTI_TYPHOON_RESERVED
                   + PAKETTI_TYPHOON_FATS * PAKETTI_TYPHOON_FAT_SECTORS
                   + ROOT_SECTORS                                                  -- 14
PAKETTI_TYPHOON_CLUSTERS = floor((PAKETTI_TYPHOON_SECTORS - DATA_START) / 2)       -- 713
PAKETTI_TYPHOON_CAPACITY = PAKETTI_TYPHOON_CLUSTERS * PAKETTI_TYPHOON_CLUSTER      -- 730112

local function dos_name_field(name)
  local base, ext = name:match("^([^%.]*)%.?(.*)$")
  base = (base or ""):upper():sub(1, 8)
  ext = (ext or ""):upper():sub(1, 3)
  return base .. string.rep(" ", 8 - #base) .. ext .. string.rep(" ", 3 - #ext)
end

-- files: array of { name = "KICK.C01", data = <string> }
-- Returns the raw 737280-byte image.
function PakettiTyphoonBuildDiskImage(files, label, yield_every)
  local total_clusters = 0
  for _, f in ipairs(files) do
    total_clusters = total_clusters + math.max(1, math.ceil(#f.data / PAKETTI_TYPHOON_CLUSTER))
  end
  if total_clusters > PAKETTI_TYPHOON_CLUSTERS then
    error(string.format("contents need %d clusters, a 720K disk holds %d",
      total_clusters, PAKETTI_TYPHOON_CLUSTERS))
  end
  local entries_needed = #files + ((label and label ~= "") and 1 or 0)
  if entries_needed > PAKETTI_TYPHOON_ROOT_ENTRIES then
    error(string.format("%d root directory entries needed, a 720K disk holds %d",
      entries_needed, PAKETTI_TYPHOON_ROOT_ENTRIES))
  end

  -- Boot sector with the 720K BIOS parameter block.
  local vol_id = math.random(0, 65535) * 65536 + math.random(0, 65535)
  local boot = "\235\060\144" .. "PAKETTI "                     -- jump + OEM name
    .. le(PAKETTI_TYPHOON_SECTOR, 16) .. string.char(2)         -- bytes/sector, sectors/cluster
    .. le(PAKETTI_TYPHOON_RESERVED, 16) .. string.char(PAKETTI_TYPHOON_FATS)
    .. le(PAKETTI_TYPHOON_ROOT_ENTRIES, 16) .. le(PAKETTI_TYPHOON_SECTORS, 16)
    .. string.char(249)                                         -- media descriptor 0xF9 = 720K
    .. le(PAKETTI_TYPHOON_FAT_SECTORS, 16) .. le(9, 16) .. le(2, 16)
    .. le(0, 32) .. le(0, 32)                                   -- hidden, large total
    .. string.char(0, 0, 41) .. le(vol_id, 32)
    .. dos_name_field((label or "TYPHOON") .. " "):sub(1, 11)
    .. "FAT12   "
  boot = boot .. string.rep("\0", 510 - #boot) .. "\085\170"

  -- Allocate clusters and build the FAT.
  local fat = {}                              -- fat[n] = next cluster or 0xFFF
  local next_cluster = 2
  local placed = {}
  for _, f in ipairs(files) do
    local need = math.max(1, math.ceil(#f.data / PAKETTI_TYPHOON_CLUSTER))
    placed[#placed + 1] = { name = f.name, size = #f.data, first = next_cluster, data = f.data }
    for k = 1, need do
      local c = next_cluster + k - 1
      fat[c] = (k == need) and 4095 or (c + 1)
    end
    next_cluster = next_cluster + need
  end

  local fatbytes = { string.char(249, 255, 255) }   -- entries 0 and 1
  local n = 2
  while n < next_cluster do
    local e0 = fat[n] or 0
    local e1 = fat[n + 1] or 0
    fatbytes[#fatbytes + 1] = string.char(
      e0 % 256,
      floor(e0 / 256) % 16 + (e1 % 16) * 16,
      floor(e1 / 16) % 256)
    n = n + 2
  end
  local fatimg = table.concat(fatbytes)
  local fatsize = PAKETTI_TYPHOON_FAT_SECTORS * PAKETTI_TYPHOON_SECTOR
  fatimg = fatimg .. string.rep("\0", fatsize - #fatimg)

  -- Root directory. 1980-01-01 00:00 keeps it deterministic, and matches the
  -- timestamps the original library disks carry.
  local dirparts = {}
  if label and label ~= "" then
    dirparts[#dirparts + 1] = dos_name_field(label .. " "):sub(1, 11) .. string.char(8)
      .. string.rep("\0", 10) .. le(0, 16) .. le(33, 16) .. le(0, 16) .. le(0, 32)
  end
  for _, f in ipairs(placed) do
    dirparts[#dirparts + 1] = dos_name_field(f.name) .. string.char(32)
      .. string.rep("\0", 10) .. le(0, 16) .. le(33, 16)
      .. le(f.first, 16) .. le(f.size, 32)
  end
  local root = table.concat(dirparts)
  local rootsize = ROOT_SECTORS * PAKETTI_TYPHOON_SECTOR
  root = root .. string.rep("\0", rootsize - #root)

  -- Data area.
  local data = {}
  for i, f in ipairs(placed) do
    local pad = (-#f.data) % PAKETTI_TYPHOON_CLUSTER
    data[#data + 1] = f.data .. string.rep("\0", pad)
    if yield_every and i % yield_every == 0 then coroutine.yield() end
  end
  data = table.concat(data)
  local datasize = (PAKETTI_TYPHOON_SECTORS - DATA_START) * PAKETTI_TYPHOON_SECTOR
  data = data .. string.rep("\0", datasize - #data)

  return boot .. fatimg .. fatimg .. root .. data
end

-- First-fit-decreasing packing into 720K disks, honouring both limits that
-- actually bite: cluster space, and the 112-entry root directory. A 120-sample
-- kit hits the directory limit long before it fills a disk, so the number of
-- disks is worked out first and the files are then spread evenly over them -
-- otherwise the first disk takes 111 files and the last takes 9.
function PakettiTyphoonPackDisks(files, reserve_entries)
  reserve_entries = reserve_entries or 0

  local order = {}
  local total_clusters = 0
  for i, f in ipairs(files) do
    order[i] = f
    local need = math.max(1, math.ceil(#f.data / PAKETTI_TYPHOON_CLUSTER))
    if need > PAKETTI_TYPHOON_CLUSTERS then
      error(string.format("%s is %d bytes and cannot fit on any 720K disk", f.name, #f.data))
    end
    total_clusters = total_clusters + need
  end
  -- Largest-first packs tighter, but it scatters the kit: disk 1 ends up with
  -- whichever samples happen to be biggest. Try the instrument's own order
  -- first so disk 1 holds the first samples, and only fall back to
  -- largest-first if that genuinely will not fit.
  local by_size = {}
  for i, f in ipairs(order) do by_size[i] = f end
  table.sort(by_size, function(a, b)
    if #a.data ~= #b.data then return #a.data > #b.data end
    return a.name < b.name
  end)

  local usable_entries = PAKETTI_TYPHOON_ROOT_ENTRIES - 1   -- keep one for the volume label
  local ndisks = math.max(
    math.ceil(total_clusters / PAKETTI_TYPHOON_CLUSTERS),
    math.ceil((#order + reserve_entries) / usable_entries),
    1)

  -- Try to lay the files out over exactly ndisks; if the size distribution
  -- defeats an even split, allow one more disk and try again.
  for attempt = 0, 17 do
    -- Even attempts keep the kit's order; odd attempts retry the same disk
    -- count packed largest-first.
    local n = ndisks + floor(attempt / 2)
    local source = (attempt % 2 == 0) and order or by_size
    local per_disk = math.ceil((#order + reserve_entries) / n)
    local disks = {}
    for i = 1, n do
      disks[i] = { files = {}, clusters = 0,
                   reserve = (i == 1) and reserve_entries or 0 }
    end
    local ok = true
    for _, f in ipairs(source) do
      local need = math.max(1, math.ceil(#f.data / PAKETTI_TYPHOON_CLUSTER))
      local home
      for _, d in ipairs(disks) do
        if d.clusters + need <= PAKETTI_TYPHOON_CLUSTERS
           and #d.files + (d.reserve or 0) < math.min(per_disk, usable_entries) then
          home = d ; break
        end
      end
      if not home then ok = false break end
      home.files[#home.files + 1] = f
      home.clusters = home.clusters + need
    end
    if ok then
      -- drop any disk that ended up empty
      local out = {}
      for _, d in ipairs(disks) do
        if #d.files > 0 or (d.reserve or 0) > 0 then
          out[#out + 1] = d
        end
      end
      return out
    end
  end
  error("could not lay these files out onto 720K disks")
end


--------------------------------------------------------------------------------
-- Drumkit -> TX16W pipeline
--------------------------------------------------------------------------------

local function path_sep() return package.config:sub(1, 1) end

local function join(dir, name)
  return dir .. (dir:match("[/\\]$") and "" or path_sep()) .. name
end

-- Makes a directory, parents included. Safe to call on one that already exists.
local function ensure_dir(dir)
  if not dir or dir == "" then return end
  if io.exists(dir) then return end
  if path_sep() == "\\" then
    os.execute(string.format('mkdir "%s"', dir:gsub("/", "\\")))
  else
    os.execute(string.format('mkdir -p "%s"', dir))
  end
end

local function write_file(path, data)
  local f, err = io.open(path, "wb")
  if not f then
    -- Most likely the folder is not there yet: the export can be pointed at a
    -- name the user has only just invented. Make it and try once more.
    ensure_dir(path:match("^(.*)[/\\][^/\\]*$"))
    f, err = io.open(path, "wb")
  end
  if not f then error("cannot write " .. tostring(path) .. ": " .. tostring(err)) end
  f:write(data)
  f:close()
end

-- The TX16W measures its sample memory in 12-bit sample points: the Typhoon
-- manual defines "one sample point is a 12-bit value, and the number of bytes
-- is obtained by multiplying the value with 1.5". A stock machine has 1.5 MB
-- and it takes up to 6 MB.
PAKETTI_TX16W_RAM_OPTIONS = {
  {label = "1.5 MB (stock)", points = 1048576},
  {label = "3 MB",           points = 2097152},
  {label = "4.5 MB",         points = 3145728},
  {label = "6 MB (maximum)", points = 4194304},
}

function PakettiTyphoonInstalledPoints()
  local ok, v = pcall(function() return preferences.pakettiTX16WSamplePoints.value end)
  if ok and type(v) == "number" and v > 0 then return v end
  return 1048576
end

function PakettiTyphoonPointsToBytes(points) return points * 1.5 end

local function format_mb(points)
  return string.format("%.1f MB", PakettiTyphoonPointsToBytes(points) / 1048576)
end

-- What an instrument will occupy in the sampler's RAM once loaded. DWVW only
-- shrinks the copy on the floppy; the machine holds the decoded audio, so this
-- is deliberately counted in uncompressed sample points.
function PakettiTyphoonEstimatePoints(instrument, rate, force_mono)
  local total = 0
  for _, smp in ipairs(instrument.samples) do
    local buf = smp.sample_buffer
    if buf and buf.has_sample_data then
      local frames = PakettiDWVWLoopLimit(smp, buf) or buf.number_of_frames
      local out_rate = (rate and rate > 0) and rate or buf.sample_rate
      frames = math.max(1, floor(frames / (buf.sample_rate / out_rate)))
      local ch = (force_mono or buf.number_of_channels == 1) and 1 or buf.number_of_channels
      total = total + frames * ch
    end
  end
  return total
end

local typhoon_slicer = nil

-- Turns the selected instrument into a .O01 voice plus one .C01 per sample,
-- then lays them out on as many 720K disk images as they need.
local function typhoon_export_process(outdir, opts)
  local dialog, dvb = nil, nil
  if typhoon_slicer then dialog, dvb = typhoon_slicer:create_dialog("Paketti TX16W Export") end
  local slicer = typhoon_slicer

  local ok, err = pcall(function()
    local song = renoise.song()
    local instrument = song.selected_instrument
    local kitname = instrument.name
    if kitname == "" then kitname = "KIT" end

    local samples = {}
    for i, smp in ipairs(instrument.samples) do
      if smp.sample_buffer and smp.sample_buffer.has_sample_data then
        samples[#samples + 1] = { index = i, sample = smp }
      end
    end
    if #samples == 0 then error("the selected instrument has no sample data") end

    local stamp = PakettiTyphoonNewStamp()
    local used, files, splits = {}, {}, {}
    local oversize = 0
    -- Sample points the kit will occupy in the machine's RAM, counted
    -- uncompressed because that is how the sampler holds it.
    local total_points = 0

    for n, entry in ipairs(samples) do
      if slicer and slicer:was_cancelled() then error("cancelled") end
      if dvb then
        dvb.views.progress_text.text = string.format("Encoding %d/%d: %s",
          n, #samples, entry.sample.name)
      end
      coroutine.yield()

      local smp = entry.sample
      local buffer = smp.sample_buffer
      local rate = (opts.rate > 0) and opts.rate or buffer.sample_rate
      local dosname = PakettiDWVWDosName(
        (smp.name ~= "" and smp.name or ("SAMPLE" .. n)), used)
      local waveid = PakettiTyphoonNewWaveId(stamp, dosname, n)

      local channels, frames, nch = PakettiDWVWBufferToChannels(
        buffer, rate, opts.force_mono, opts.wordsize, 8192,
        PakettiDWVWLoopLimit(smp, buffer))
      if frames > PAKETTI_DWVW_MAX_FRAMES then oversize = oversize + 1 end
      total_points = total_points + frames * nch

      local meta = PakettiDWVWSampleMeta(smp, buffer, frames)
      meta.appl = PakettiTyphoonWaveAppl(stamp, waveid)
      local data = PakettiDWVWBuildFile(channels, frames, rate, opts.wordsize, 8192, meta)

      files[#files + 1] = { name = dosname, data = data }
      -- One sample per key. Renoise's own mapping is used when it is distinct,
      -- otherwise the samples are laid out in order from the base key.
      local key = opts.base_key + n - 1
      if opts.use_mapping then key = smp.sample_mapping.note_range[1] end
      local vr = smp.sample_mapping.velocity_range
      splits[#splits + 1] = { key = math.max(0, math.min(127, key)),
                              name = dosname:match("^[^%.]+"), id = waveid,
                              file = dosname,
                              low_vel = vr[1], high_vel = vr[2],
                              note_range = smp.sample_mapping.note_range }
    end

    -- Sorting and key de-duplication happen per velocity layer further down:
    -- two samples may legitimately share a key when they are on different
    -- velocity layers, and nudging them apart here would break that.

    if dvb then dvb.views.progress_text.text = "Packing 720K disks..." end
    coroutine.yield()

    -- Pack before building the voice, so each split can name the diskette its
    -- wave actually landed on. Typhoon uses that name to prompt for the right
    -- floppy when a wave is missing; without it the sampler only knows that
    -- something is absent, not where to send you.
    local labelbase = PakettiDWVWDosName(kitname, {}):match("^[^%.]+"):sub(1, 6)
    local disks = PakettiTyphoonPackDisks(files, 1)
    local disk_of = {}
    for i, d in ipairs(disks) do
      for _, f in ipairs(d.files) do
        disk_of[f.name] = string.format("%s%d", labelbase, i)
      end
    end
    for _, sp in ipairs(splits) do sp.disk = disk_of[sp.file] end

    if dvb then dvb.views.progress_text.text = "Building voice file..." end
    coroutine.yield()

    -- The TX16W carries the velocity range on the GROUP, not the split, so a
    -- velocity-layered instrument becomes one group per distinct range, each
    -- holding the splits that live in it. Instruments with a single range
    -- (the usual case) come out as one group exactly as before.
    local layers, layer_order = {}, {}
    for _, sp in ipairs(splits) do
      local lo = math.max(0, math.min(127, sp.low_vel or 0))
      local hi = math.max(lo, math.min(127, sp.high_vel or 127))
      local tag = lo .. ":" .. hi
      if not layers[tag] then
        layers[tag] = { splits = {}, range = { low_vel = lo, high_vel = hi } }
        layer_order[#layer_order + 1] = tag
      end
      local L = layers[tag].splits
      L[#L + 1] = sp
    end

    local voice_groups = {}
    for _, tag in ipairs(layer_order) do
      local L = layers[tag]
      table.sort(L.splits, function(a, b) return a.key < b.key end)
      -- Keys must be distinct within a group; nudge collisions up.
      for i = 2, #L.splits do
        if L.splits[i].key <= L.splits[i - 1].key then
          L.splits[i].key = math.min(127, L.splits[i - 1].key + 1)
        end
      end
      -- The group only needs to respond across the keys it actually covers.
      local lowk, highk = L.splits[1].key, 96
      for _, sp in ipairs(L.splits) do
        if sp.note_range and sp.note_range[2] then
          highk = math.max(highk, math.min(127, sp.note_range[2]))
        end
      end
      L.range.low_key = 0
      L.range.high_key = math.max(highk, L.splits[#L.splits].key)
      L.range.end_key = math.min(127, L.splits[#L.splits].key + 1)
      voice_groups[#voice_groups + 1] = L
    end

    local voicename = PakettiDWVWDosName(kitname, used, "O")
    local voice = PakettiTyphoonBuildVoice(voice_groups, stamp,
      PakettiTyphoonNewWaveId(stamp, voicename, 0))
    if #voice_groups > 1 then
      print(string.format("PakettiTyphoon: %d velocity layer(s) -> %d group(s)",
        #voice_groups, #voice_groups))
    end

    -- The voice goes on disk 1, where the sampler will look for it first.
    table.insert(disks[1].files, 1, { name = voicename, data = voice })

    -- What actually fits in the machine. DWVW shrinks the floppy copy only, so
    -- a kit can span disks correctly and still be too big to load.
    local installed = PakettiTyphoonInstalledPoints()
    local ram_warning = nil
    if total_points > installed then
      ram_warning = string.format(
        "needs %s of sample memory but the TX16W is set to %s - it will not all load",
        format_mb(total_points), format_mb(installed))
    end

    -- A manifest, so there is no guessing when the sampler asks for a disk.
    local manifest = {
      string.format("%s - Yamaha TX16W export", kitname),
      string.format("%d sample(s), %d disk(s)", #files, #disks),
      string.format("Sample memory needed: %s of the %s installed%s",
        format_mb(total_points), format_mb(installed),
        ram_warning and "   *** TOO BIG ***" or ""),
      "",
      "Insert the disks in this order. The voice is on disk 1; the sampler",
      "asks for the others by name as it needs them.",
      "",
    }
    for i, d in ipairs(disks) do
      manifest[#manifest + 1] = string.format("Disk %d  (label %s%d)", i, labelbase, i)
      for _, f in ipairs(d.files) do
        manifest[#manifest + 1] = string.format("    %-14s %8d bytes", f.name, #f.data)
      end
      manifest[#manifest + 1] = ""
    end

    local written = {}
    if opts.write_images then
      for i, d in ipairs(disks) do
        if dvb then dvb.views.progress_text.text = string.format("Writing disk %d/%d...", i, #disks) end
        coroutine.yield()
        local img = PakettiTyphoonBuildDiskImage(d.files,
          string.format("%s%d", labelbase, i), 8)
        local name = string.format("%s_DISK%d.img", labelbase, i)
        write_file(join(outdir, name), img)
        written[#written + 1] = name
      end
    end

    local manifest_name = string.format("%s_DISKS.txt", labelbase)
    write_file(join(outdir, manifest_name), table.concat(manifest, "\n") .. "\n")
    written[#written + 1] = manifest_name

    if opts.write_loose then
      local loose = join(outdir, "files")
      ensure_dir(loose)
      write_file(join(loose, voicename), voice)
      for _, f in ipairs(files) do write_file(join(loose, f.name), f.data) end
    end

    local msg = string.format(
      "Paketti TX16W: %s - %d samples, voice %s, %d disk image(s) in %s%s%s",
      kitname, #files, voicename, #disks, outdir,
      (#disks > 1) and " (the voice is on disk 1; the sampler will ask for the others)" or "",
      (oversize > 0) and string.format(", %d too long for the sampler", oversize) or "")
    if ram_warning then
      msg = msg .. " - WARNING: " .. ram_warning
    end
    PakettiTyphoonLastStatus = msg
    renoise.app():show_status(msg)
    print(msg)
    for _, w in ipairs(written) do print("  wrote " .. join(outdir, w)) end

    -- Show the results in the file browser. Without this the disk images are
    -- written and never seen, because nothing in Renoise points at the folder.
    if opts.reveal ~= false then
      local reveal_ok, reveal_err = pcall(function() renoise.app():open_path(outdir) end)
      if not reveal_ok then
        print("PakettiTyphoon: could not open " .. outdir .. ": " .. tostring(reveal_err))
      end
    end
  end)

  if dialog and dialog.visible then dialog:close() end
  typhoon_slicer = nil
  if not ok then
    PakettiTyphoonLastStatus = "failed: " .. tostring(err)
    renoise.app():show_status("Paketti TX16W export failed: " .. tostring(err))
    print("PakettiTyphoon error: " .. tostring(err))
  end
end

PakettiTyphoonLastStatus = "never run"

function PakettiTyphoonExportDrumkit(outdir, opts)
  if typhoon_slicer and typhoon_slicer:running() then
    renoise.app():show_status("Paketti TX16W: an export is already running")
    return false
  end
  local song = renoise.song()
  if #song.selected_instrument.samples == 0 then
    renoise.app():show_status("Paketti TX16W: the selected instrument has no samples")
    return false
  end
  if not outdir or outdir == "" then
    outdir = renoise.app():prompt_for_path("Where to write the TX16W disk images")
    if not outdir or outdir == "" then
      renoise.app():show_status("Paketti TX16W: export cancelled")
      return false
    end
  end
  opts = opts or {}
  local resolved = {
    rate = opts.rate or PakettiDWVWTargetRate(),
    wordsize = opts.wordsize or PakettiDWVWWordSize(),
    force_mono = (opts.force_mono ~= nil) and opts.force_mono or PakettiDWVWForceMono(),
    base_key = opts.base_key or 36,
    use_mapping = opts.use_mapping or false,
    write_images = (opts.write_images ~= false),
    write_loose = (opts.write_loose ~= false),
    reveal = (opts.reveal ~= false),
  }
  typhoon_slicer = ProcessSlicer(function() typhoon_export_process(outdir, resolved) end)
  typhoon_slicer:start()
  return true
end

--------------------------------------------------------------------------------
-- Export dialog
--------------------------------------------------------------------------------

local typhoon_export_dialog = nil

function PakettiTyphoonExportDialog()
  if typhoon_export_dialog and typhoon_export_dialog.visible then
    typhoon_export_dialog:close()
    typhoon_export_dialog = nil
    return
  end

  local song = renoise.song()
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("Paketti TX16W: the selected instrument has no samples")
    return
  end

  local vb = renoise.ViewBuilder()

  local rates = {"33333 Hz (TX16W standard)", "50000 Hz (TX16W high rate)",
                 "25000 Hz (TX16W mid rate)", "16666 Hz (TX16W low rate)",
                 "Keep each sample's own rate (no resampling)"}
  local rate_values = {33333, 50000, 25000, 16666, 0}
  local rate_index = 1
  for i, r in ipairs(rate_values) do
    if r == PakettiDWVWTargetRate() then rate_index = i end
  end

  local ram_labels = {}
  local ram_index = 1
  for i, o in ipairs(PAKETTI_TX16W_RAM_OPTIONS) do
    ram_labels[i] = o.label
    if o.points == PakettiTyphoonInstalledPoints() then ram_index = i end
  end

  local force_mono = PakettiDWVWForceMono()
  local use_mapping = false

  -- Recomputed whenever a setting that changes the size is touched, so the fit
  -- is visible before anything is written rather than discovered afterwards.
  local function refresh()
    local rate = rate_values[vb.views.tx_rate.value]
    local points = PakettiTyphoonEstimatePoints(
      song.selected_instrument, rate, vb.views.tx_mono.value)
    local installed = PAKETTI_TX16W_RAM_OPTIONS[vb.views.tx_ram.value].points
    local mb = PakettiTyphoonPointsToBytes(points) / 1048576
    local imb = PakettiTyphoonPointsToBytes(installed) / 1048576
    vb.views.tx_fit.text = string.format(
      "%d samples need %.2f MB of the %.1f MB installed  (%d%%)%s",
      #song.selected_instrument.samples, mb, imb,
      math.floor(points / installed * 100 + 0.5),
      (points > installed) and "   -- TOO BIG, it will not all load" or "")
    vb.views.tx_fit.style = (points > installed) and "strong" or "normal"
  end

  local content = vb:column{
    margin = 10, spacing = 6,
    vb:text{text = "Export \"" .. instrument.name .. "\" to a Yamaha TX16W running Typhoon",
            font = "bold"},

    vb:row{
      vb:text{text = "Sample rate", width = 110},
      vb:popup{id = "tx_rate", items = rates, value = rate_index, width = 260,
               notifier = function() refresh() end},
    },
    vb:row{
      vb:text{text = "Installed RAM", width = 110},
      vb:popup{id = "tx_ram", items = ram_labels, value = ram_index, width = 260,
               notifier = function() refresh() end},
    },
    vb:row{
      vb:text{text = "", width = 110},
      vb:checkbox{id = "tx_mono", value = force_mono,
                  notifier = function() refresh() end},
      vb:text{text = "Mix to mono (the TX16W is a mono sampler)"},
    },
    vb:row{
      vb:text{text = "", width = 110},
      vb:checkbox{id = "tx_mapping", value = use_mapping},
      vb:text{text = "Keep the instrument's own key mapping (otherwise one sample per key from C-2)"},
    },

    vb:space{height = 4},
    vb:text{id = "tx_fit", text = "", width = 480},
    vb:space{height = 4},

    vb:row{
      spacing = 6,
      vb:button{
        text = "Export...", width = 100,
        notifier = function()
          local rate = rate_values[vb.views.tx_rate.value]
          local ram = PAKETTI_TX16W_RAM_OPTIONS[vb.views.tx_ram.value].points
          preferences.pakettiDWVWSampleRate.value = rate
          preferences.pakettiDWVWForceMono.value = vb.views.tx_mono.value
          preferences.pakettiTX16WSamplePoints.value = ram
          preferences:save_as("preferences.xml")
          local opts = {
            rate = rate,
            force_mono = vb.views.tx_mono.value,
            use_mapping = vb.views.tx_mapping.value,
          }
          if typhoon_export_dialog and typhoon_export_dialog.visible then
            typhoon_export_dialog:close()
            typhoon_export_dialog = nil
          end
          PakettiTyphoonExportDrumkit(nil, opts)
        end,
      },
      vb:button{
        text = "Cancel", width = 80,
        notifier = function()
          if typhoon_export_dialog and typhoon_export_dialog.visible then
            typhoon_export_dialog:close()
            typhoon_export_dialog = nil
          end
        end,
      },
    },
  }

  typhoon_export_dialog = renoise.app():show_custom_dialog(
    "Export to Yamaha TX16W", content, my_keyhandler_func)
  refresh()
end

--------------------------------------------------------------------------------
-- Reading TX16W disks back in
--------------------------------------------------------------------------------

local function getle(s, pos, width)          -- little-endian, FAT structures
  local v = 0
  for i = width - 1, 0, -1 do v = v * 256 + (s:byte(pos + i) or 0) end
  return v
end

-- Reads a raw 720K FAT12 image. Returns a list of { name, data } plus the
-- volume label. Deliberately tolerant: TX16W disks are written by a 1993
-- sampler, so anything unreadable is skipped rather than fatal.
function PakettiTyphoonReadDiskImage(data, yield_every)
  if #data < 512 then error("file is too small to be a disk image") end

  local bps   = getle(data, 12, 2)
  local spc   = data:byte(14)
  local res   = getle(data, 15, 2)
  local nfat  = data:byte(17)
  local nroot = getle(data, 18, 2)
  local spf   = getle(data, 23, 2)

  -- A blank or non-DOS boot sector still usually sits on standard 720K
  -- geometry, so fall back to it rather than refusing the disk.
  if bps ~= 512 or spc < 1 or nfat < 1 or nroot < 1 or spf < 1 then
    bps, spc, res, nfat, nroot, spf = 512, 2, 1, 2, 112, 3
  end

  local rootoff = res * bps + nfat * spf * bps
  local dataoff = rootoff + nroot * 32
  local cluster = spc * bps
  if dataoff > #data then error("disk image is truncated") end

  local fatoff = res * bps
  local function fat_entry(n)
    local off = fatoff + floor(n * 3 / 2)
    if off + 1 > #data then return 0xFFF end
    local v = (data:byte(off + 1) or 0) + (data:byte(off + 2) or 0) * 256
    if n % 2 == 1 then return floor(v / 16) end
    return v % 4096
  end

  local files, label = {}, nil
  for i = 0, nroot - 1 do
    local e = rootoff + i * 32
    local first = data:byte(e + 1)
    if not first or first == 0 then break end
    local attr = data:byte(e + 12) or 0
    if first ~= 0xE5 and attr % 32 < 16 then      -- not deleted, not a subdir
      local base = data:sub(e + 1, e + 8):gsub("%s+$", "")
      local ext  = data:sub(e + 9, e + 11):gsub("%s+$", "")
      if attr % 16 >= 8 then
        label = (base .. ext):gsub("%s+$", "")    -- volume label
      else
        local name = (ext ~= "") and (base .. "." .. ext) or base
        local size = getle(data, e + 29, 4)
        local c    = getle(data, e + 27, 2)
        local parts, got, guard = {}, 0, 0
        while c >= 2 and c < 0xFF0 and got < size and guard < 4096 do
          local off = dataoff + (c - 2) * cluster
          if off + cluster > #data then break end
          parts[#parts + 1] = data:sub(off + 1, off + cluster)
          got = got + cluster
          c = fat_entry(c)
          guard = guard + 1
        end
        local body = table.concat(parts):sub(1, size)
        if #body > 0 then files[#files + 1] = { name = name, data = body } end
      end
    end
    if yield_every and i % yield_every == 0 then coroutine.yield() end
  end
  return files, label
end

-- Walks an IFF FORM, calling fn(id, body) for each chunk at the top level.
local function iff_walk(data, expect, fn)
  if #data < 12 or data:sub(1, 4) ~= "FORM" then return false end
  local formsize = 0
  for i = 5, 8 do formsize = formsize * 256 + data:byte(i) end
  if expect and data:sub(9, 12) ~= expect then return false end
  local p, stop = 13, math.min(#data, 8 + formsize)
  while p + 8 <= stop do
    local id = data:sub(p, p + 3)
    local size = 0
    for i = p + 4, p + 7 do size = size * 256 + data:byte(i) end
    if size < 0 or p + 8 + size - 1 > stop then break end
    fn(id, data:sub(p + 8, p + 8 + size - 1))
    p = p + 8 + size + (size % 2)
  end
  return true
end

-- Parses a .O01 voice. Returns { stamp, id, groups = { { parm, mods, splits } } }
-- where each split is { key = <first key or nil>, name, id, disk }.
function PakettiTyphoonParseVoice(data)
  local voice = { groups = {} }
  local ok = iff_walk(data, "TYPV", function(id, body)
    if id == "VInf" and #body >= 16 then
      voice.stamp = body:sub(1, 12)
      voice.id = body:sub(13, 16)
    elseif id == "Grop" then
      -- A Grop body is a bare chunk stream, not a nested FORM, so walk it directly.
      local group = { mods = {}, splits = {} }
      local p = 1
      while p + 8 <= #body do
        local cid = body:sub(p, p + 3)
        local csize = 0
        for i = p + 4, p + 7 do csize = csize * 256 + body:byte(i) end
        if csize < 0 or p + 8 + csize - 1 > #body then break end
        local cb = body:sub(p + 8, p + 8 + csize - 1)
        if cid == "Parm" then
          if #cb >= 64 then group.parm = cb end
        elseif cid == "Mod " then
          group.mods[#group.mods + 1] = cb
        elseif cid == "Splt" then
          local q, key, wave = 1, nil, nil
          while q + 8 <= #cb do
            local sid = cb:sub(q, q + 3)
            local ssize = 0
            for i = q + 4, q + 7 do ssize = ssize * 256 + cb:byte(i) end
            if ssize < 0 or q + 8 + ssize - 1 > #cb then break end
            local sb = cb:sub(q + 8, q + 8 + ssize - 1)
            if sid == "Parm" and #sb >= 1 then
              key = sb:byte(1)
            elseif sid == "Wave" and #sb >= 12 then
              wave = {
                name = sb:sub(1, 8):gsub("[%z%s]+$", ""),
                id = sb:sub(9, 12),
                disk = (#sb >= 20) and sb:sub(13, 20):gsub("[%z%s\255]+$", "") or nil,
              }
            end
            q = q + 8 + ssize + (ssize % 2)
          end
          -- A Splt carrying only a Parm is the terminator: it has no wave, but
          -- its key is where the last real split stops. Keep it.
          group.splits[#group.splits + 1] = wave
            and { name = wave.name, id = wave.id, disk = wave.disk, key = key }
            or { key = key, terminator = true }
        end
        p = p + 8 + csize + (csize % 2)
      end
      voice.groups[#voice.groups + 1] = group
    end
  end)
  if not ok then error("not a Typhoon voice file (no FORM/TYPV header)") end
  return voice
end

--------------------------------------------------------------------------------
-- Importing: disk images and voices become Renoise instruments
--------------------------------------------------------------------------------

local typhoon_import_slicer = nil

local function read_whole_file(path)
  local f, err = io.open(path, "rb")
  if not f then error("cannot open " .. tostring(path) .. ": " .. tostring(err)) end
  local data = f:read("*a")
  f:close()
  if not data or #data == 0 then error("file is empty: " .. tostring(path)) end
  return data
end

local function base_of(path)
  return (path:match("[^/\\]+$") or path)
end

local function strip_ext(name)
  return (name:gsub("%.[^%.]*$", ""))
end

-- A wave file on a Typhoon disk is a .C01-.C99; .A01-.A99 are plain AIFF.
local function is_wave_name(name)
  return name:upper():match("%.C%d%d$") ~= nil
end
local function is_voice_name(name)
  return name:upper():match("%.O%d%d$") ~= nil
end
local function is_aiff_name(name)
  return name:upper():match("%.A%d%d$") ~= nil
end

-- Decodes every wave in the file list once, keyed both by Typhoon wave id and
-- by uppercased base name, because a voice's Splt reference resolves by id when
-- the wave carries Typhoon's APPL stamp and by name when it does not.
local function decode_waves(files, progress)
  local by_id, by_name, order, failed = {}, {}, {}, {}
  for _, f in ipairs(files) do
    if is_wave_name(f.name) then
      if progress then progress("Decoding " .. f.name .. "...") end
      coroutine.yield()
      local ok, info = pcall(PakettiDWVWParseFile, f.data, 4096)
      if ok then
        local entry = { name = strip_ext(f.name), info = info, file = f.name }
        order[#order + 1] = entry
        by_name[strip_ext(f.name):upper()] = entry
        if info.typhoon_wave_id then by_id[info.typhoon_wave_id] = entry end
      else
        failed[#failed + 1] = f.name .. " (" .. tostring(info) .. ")"
      end
    end
  end
  return by_id, by_name, order, failed
end

-- Builds one Renoise instrument from a parsed voice. Splits become key zones:
-- a split's key is its FIRST key, and it runs up to the key before the next
-- split, which is exactly how Typhoon reads them.
local function build_instrument_from_voice(voice, vname, by_id, by_name, progress)
  local song = renoise.song()
  -- Insert first, then select. Setting the index past the end throws when the
  -- selected instrument is the last one in the song.
  local at = song.selected_instrument_index + 1
  song:insert_instrument_at(at)
  song.selected_instrument_index = at
  pakettiPreferencesDefaultInstrumentLoader()
  local instrument = song.selected_instrument
  -- Emptying an instrument clears its name in Renoise, so it gets named at the
  -- end, once the samples are in.
  while #instrument.samples > 0 do instrument:delete_sample_at(1) end

  local placed, missing = 0, {}
  for gi, group in ipairs(voice.groups) do
    local splits = group.splits
    for si, sp in ipairs(splits) do
      local entry = (not sp.terminator)
        and ((sp.id and by_id[sp.id]) or by_name[(sp.name or ""):upper()])
        or nil
      if sp.terminator then
        -- nothing to place; it only bounds the split before it
      elseif not entry then
        missing[#missing + 1] = sp.name or "?"
      else
        -- Typhoon stores a split by its FIRST key only. The first split has no
        -- key of its own and starts at note 0; every split runs up to the key
        -- below whichever split comes next -- including a Parm-only terminator,
        -- which exists precisely to close the last one.
        local lo = sp.key or 0
        local hi = 119
        for sj = si + 1, #splits do
          if splits[sj].key then
            hi = math.max(lo, splits[sj].key - 1)
            break
          end
        end

        instrument:insert_sample_at(#instrument.samples + 1)
        local sample = instrument.samples[#instrument.samples]
        PakettiDWVWApplyToSample(sample, entry.info, entry.name, 8192, progress)
        sample.sample_mapping.note_range = {
          math.max(0, math.min(119, lo)), math.max(0, math.min(119, hi))
        }
        -- A single-key split is a drum pad; centre the root on it so it plays
        -- at its recorded pitch rather than transposed.
        if lo == hi then sample.sample_mapping.base_note = lo end
        placed = placed + 1
        coroutine.yield()
      end
    end
    if gi < #voice.groups then coroutine.yield() end
  end
  instrument.name = vname
  return instrument, placed, missing
end

local function typhoon_import_process(sources, opts)
  local dialog, dvb = nil, nil
  local slicer = typhoon_import_slicer
  if slicer then dialog, dvb = slicer:create_dialog("Paketti TX16W Import") end
  local function progress(text)
    if dvb then dvb.views.progress_text.text = text end
  end

  local ok, err = pcall(function()
    local files, label = {}, nil

    for _, src in ipairs(sources) do
      progress("Reading " .. base_of(src) .. "...")
      coroutine.yield()
      local data = read_whole_file(src)
      if src:upper():match("%.IMG$") or src:upper():match("%.IMA$") then
        local got, lab = PakettiTyphoonReadDiskImage(data, 8)
        label = label or lab
        for _, f in ipairs(got) do files[#files + 1] = f end
        print(string.format("PakettiTyphoon: %s holds %d files, label %s",
          base_of(src), #got, tostring(lab)))
      else
        files[#files + 1] = { name = base_of(src), data = data }
        -- A loose voice needs its waves; take them from the same folder.
        local dir = src:match("^(.*)[/\\][^/\\]*$")
        if dir and is_voice_name(src) then
          for _, n in ipairs(os.filenames(dir, {"*.C0*", "*.C1*", "*.C2*",
              "*.C3*", "*.C4*", "*.C5*", "*.C6*", "*.C7*", "*.C8*", "*.C9*"})) do
            local f = io.open(dir .. package.config:sub(1, 1) .. n, "rb")
            if f then
              files[#files + 1] = { name = n, data = f:read("*a") }
              f:close()
            end
          end
        end
      end
    end

    if #files == 0 then error("nothing readable was found") end

    local by_id, by_name, order, failed = decode_waves(files, progress)

    local voices = {}
    for _, f in ipairs(files) do
      if is_voice_name(f.name) then
        local vok, v = pcall(PakettiTyphoonParseVoice, f.data)
        if vok then
          voices[#voices + 1] = { name = strip_ext(f.name), voice = v }
        else
          failed[#failed + 1] = f.name .. " (" .. tostring(v) .. ")"
        end
      end
    end

    local made, used, total_placed, all_missing = 0, {}, 0, {}
    for _, v in ipairs(voices) do
      progress("Building " .. v.name .. "...")
      coroutine.yield()
      local _, placed, missing = build_instrument_from_voice(
        v.voice, v.name, by_id, by_name, progress)
      made = made + 1
      total_placed = total_placed + placed
      for _, m in ipairs(missing) do all_missing[#all_missing + 1] = m end
      for _, g in ipairs(v.voice.groups) do
        for _, sp in ipairs(g.splits) do
          if not sp.terminator then
            local e = (sp.id and by_id[sp.id]) or by_name[(sp.name or ""):upper()]
            if e then used[e] = true end
          end
        end
      end
    end

    -- Waves no voice claimed still deserve to arrive; a disk of raw samples is
    -- a perfectly normal thing to hand this.
    local loose = {}
    for _, e in ipairs(order) do
      if not used[e] then loose[#loose + 1] = e end
    end
    if #loose > 0 and opts.loose_waves ~= false then
      local song = renoise.song()
      local at = song.selected_instrument_index + 1
      song:insert_instrument_at(at)
      song.selected_instrument_index = at
      pakettiPreferencesDefaultInstrumentLoader()
      local instrument = song.selected_instrument
      while #instrument.samples > 0 do instrument:delete_sample_at(1) end
      for i, e in ipairs(loose) do
        progress(string.format("Loading %s (%d/%d)...", e.name, i, #loose))
        instrument:insert_sample_at(#instrument.samples + 1)
        local sample = instrument.samples[#instrument.samples]
        PakettiDWVWApplyToSample(sample, e.info, e.name, 8192, progress)
        local key = math.min(119, 35 + i)
        sample.sample_mapping.note_range = {key, key}
        sample.sample_mapping.base_note = key
        coroutine.yield()
      end
      instrument.name = (label and label ~= "" and label or "TX16W") .. " waves"
      made = made + 1
    end

    local aiffs = 0
    for _, f in ipairs(files) do if is_aiff_name(f.name) then aiffs = aiffs + 1 end end

    local msg = string.format(
      "Paketti TX16W: %d instrument(s) from %d wave(s)%s%s",
      made, #order,
      (#voices > 0) and string.format(", %d voice(s), %d key zone(s)", #voices, total_placed) or "",
      (label and label ~= "") and (", disk '" .. label .. "'") or "")
    if #all_missing > 0 then
      msg = msg .. string.format(" - %d wave(s) referenced but not on the disk", #all_missing)
      print("PakettiTyphoon: missing waves: " .. table.concat(all_missing, ", "))
    end
    if #failed > 0 then
      msg = msg .. string.format(" - %d file(s) unreadable", #failed)
      print("PakettiTyphoon: unreadable: " .. table.concat(failed, ", "))
    end
    if aiffs > 0 then
      msg = msg .. string.format(" - %d uncompressed AIFF (.A##) file(s) skipped", aiffs)
    end
    renoise.app():show_status(msg)
    print("PakettiTyphoon: " .. msg)
    PakettiTyphoonLastStatus = msg
  end)

  if dialog and dialog.visible then dialog:close() end
  typhoon_import_slicer = nil
  if not ok then
    renoise.app():show_status("Paketti TX16W import failed: " .. tostring(err))
    print("PakettiTyphoon import error: " .. tostring(err))
    PakettiTyphoonLastStatus = "import failed: " .. tostring(err)
  end
end

function PakettiTyphoonImportFiles(sources, opts)
  if type(sources) == "string" then sources = {sources} end
  if not sources or #sources == 0 then return false end
  if typhoon_import_slicer and typhoon_import_slicer:running() then
    renoise.app():show_status("Paketti TX16W: an import is already running")
    return false
  end
  opts = opts or {}
  typhoon_import_slicer = ProcessSlicer(function()
    typhoon_import_process(sources, opts)
  end)
  typhoon_import_slicer:start()
  return true
end

function PakettiTyphoonImportDiskImage()
  local path = renoise.app():prompt_for_filename_to_read(
    {"*.img", "*.IMG", "*.ima", "*.IMA"}, "Open a TX16W 720K disk image")
  if not path or path == "" then return end
  PakettiTyphoonImportFiles({path})
end

function PakettiTyphoonImportVoiceFile()
  local path = renoise.app():prompt_for_filename_to_read(
    {"*.O01", "*.o01", "*.O0*", "*.O1*"}, "Open a Typhoon voice (.O01)")
  if not path or path == "" then return end
  PakettiTyphoonImportFiles({path})
end

-- Folder of loose .C01/.O01 files, which is what you get after unpacking a
-- disk image somewhere.
function PakettiTyphoonImportFolder()
  local dir = renoise.app():prompt_for_path("Choose a folder of TX16W files")
  if not dir or dir == "" then return end
  local sep = package.config:sub(1, 1)
  local names = os.filenames(dir, {"*.O0*", "*.O1*", "*.O2*", "*.O3*", "*.O4*",
    "*.O5*", "*.O6*", "*.O7*", "*.O8*", "*.O9*"})
  local sources = {}
  for _, n in ipairs(names) do sources[#sources + 1] = dir .. sep .. n end
  if #sources == 0 then
    -- No voices: fall back to every wave in the folder.
    for _, n in ipairs(os.filenames(dir, {"*.C0*", "*.C1*", "*.C2*", "*.C3*",
        "*.C4*", "*.C5*", "*.C6*", "*.C7*", "*.C8*", "*.C9*"})) do
      sources[#sources + 1] = dir .. sep .. n
    end
  end
  if #sources == 0 then
    renoise.app():show_status("Paketti TX16W: no .O01 or .C01 files in that folder")
    return
  end
  PakettiTyphoonImportFiles(sources)
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

PakettiAddMenuEntry{name = "Main Menu:File:Paketti Import:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDialog() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDialog() end}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Save:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDialog() end}
PakettiAddMenuEntry{name = "Sample Mappings:Paketti:Save:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDialog() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Save:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDialog() end}
PakettiAddMenuEntry{name = "Disk Browser:Paketti:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDialog() end}

renoise.tool():add_keybinding{name = "Global:Paketti:Export Instrument to Yamaha TX16W", invoke = function() PakettiTyphoonExportDialog() end}
renoise.tool():add_midi_mapping{name = "Paketti:Export Instrument to Yamaha TX16W", invoke = function(message) if message:is_trigger() then PakettiTyphoonExportDialog() end end}

-- The no-dialog variant, for when the settings are already right.
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Import:Export Instrument to Yamaha TX16W with Saved Settings...", invoke = function() PakettiTyphoonExportDrumkit() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:Export Instrument to Yamaha TX16W with Saved Settings...", invoke = function() PakettiTyphoonExportDrumkit() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Export Instrument to Yamaha TX16W with Saved Settings", invoke = function() PakettiTyphoonExportDrumkit() end}


--------------------------------------------------------------------------------
-- Import registration
--------------------------------------------------------------------------------

local IMPORT_LABEL = "Import TX16W Disk Image (.img)..."
local VOICE_LABEL  = "Import Typhoon Voice (.O01)..."
local FOLDER_LABEL = "Import TX16W Folder (.O01 + .C01)..."

for _, where in ipairs({
  "Main Menu:File:Paketti Import:",
  "Main Menu:Tools:Paketti:Instruments:File Formats:",
  "Instrument Box:Paketti:Load:",
  "Disk Browser Files:Paketti:Import/Export:",
}) do
  PakettiAddMenuEntry{name = where .. IMPORT_LABEL, invoke = function() PakettiTyphoonImportDiskImage() end}
  PakettiAddMenuEntry{name = where .. VOICE_LABEL, invoke = function() PakettiTyphoonImportVoiceFile() end}
  PakettiAddMenuEntry{name = where .. FOLDER_LABEL, invoke = function() PakettiTyphoonImportFolder() end}
end
PakettiAddMenuEntry{name = "Disk Browser:Paketti:" .. IMPORT_LABEL, invoke = function() PakettiTyphoonImportDiskImage() end}
PakettiAddMenuEntry{name = "Disk Browser:Paketti:" .. FOLDER_LABEL, invoke = function() PakettiTyphoonImportFolder() end}

renoise.tool():add_keybinding{name = "Global:Paketti:Import TX16W Disk Image", invoke = function() PakettiTyphoonImportDiskImage() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Import Typhoon Voice", invoke = function() PakettiTyphoonImportVoiceFile() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Import TX16W Folder", invoke = function() PakettiTyphoonImportFolder() end}
renoise.tool():add_midi_mapping{name = "Paketti:Import TX16W Disk Image", invoke = function(message) if message:is_trigger() then PakettiTyphoonImportDiskImage() end end}

-- Drag and drop. Renoise matches import-hook extensions case-sensitively, so
-- every extension has to be registered in both cases -- real TX16W files come
-- off the machine uppercase.
local function typhoon_drop(filename)
  PakettiTyphoonImportFiles({filename})
  return true
end

local typhoon_extensions = {"img", "IMG", "ima", "IMA"}
for n = 1, 99 do
  local nn = string.format("%02d", n)
  typhoon_extensions[#typhoon_extensions + 1] = "o" .. nn
  typhoon_extensions[#typhoon_extensions + 1] = "O" .. nn
end

for _, ext in ipairs(typhoon_extensions) do
  local ok, err = pcall(function()
    renoise.tool():add_file_import_hook{
      category = "instrument",
      extensions = {ext},
      invoke = typhoon_drop,
    }
  end)
  if not ok then
    print("PakettiTyphoon: could not register import hook for ." .. ext .. ": " .. tostring(err))
  end
end
