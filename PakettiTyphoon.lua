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
function PakettiTyphoonBuildVoice(splits, stamp, voiceid, end_key)
  assert(#splits > 0, "a voice needs at least one split")

  local parts = {}
  parts[#parts + 1] = chunk("Parm", PakettiTyphoonDefaultParm)
  for _, m in ipairs(PakettiTyphoonDefaultMods) do
    parts[#parts + 1] = chunk("Mod ", m)
  end

  for i, sp in ipairs(splits) do
    local body = ""
    -- The first split never carries a Parm: it starts at key 0.
    if i > 1 then body = body .. chunk("Parm", string.char(sp.key % 128) .. "\0") end
    body = body .. chunk("Wave", PakettiTyphoonWaveName(sp.name) .. sp.id .. string.rep("\255", 8))
    parts[#parts + 1] = chunk("Splt", body)
  end

  -- Terminator: a Parm with no Wave, closing the mapping.
  local last = splits[#splits].key
  local ek = end_key or math.min(127, last + 1)
  parts[#parts + 1] = chunk("Splt", chunk("Parm", string.char(ek % 128) .. "\0"))

  local body = "TYPV" .. chunk("VInf", stamp .. voiceid) .. chunk("Grop", table.concat(parts))
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
  table.sort(order, function(a, b)
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
  for attempt = 0, 8 do
    local n = ndisks + attempt
    local per_disk = math.ceil((#order + reserve_entries) / n)
    local disks = {}
    for i = 1, n do
      disks[i] = { files = {}, clusters = 0,
                   reserve = (i == 1) and reserve_entries or 0 }
    end
    local ok = true
    for _, f in ipairs(order) do
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
          table.sort(d.files, function(a, b) return a.name < b.name end)
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

local function write_file(path, data)
  local f, err = io.open(path, "wb")
  if not f then error("cannot write " .. tostring(path) .. ": " .. tostring(err)) end
  f:write(data)
  f:close()
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

      local channels, frames = PakettiDWVWBufferToChannels(
        buffer, rate, opts.force_mono, opts.wordsize, 8192)
      if frames > PAKETTI_DWVW_MAX_FRAMES then oversize = oversize + 1 end

      local meta = PakettiDWVWSampleMeta(smp, buffer, frames)
      meta.appl = PakettiTyphoonWaveAppl(stamp, waveid)
      local data = PakettiDWVWBuildFile(channels, frames, rate, opts.wordsize, 8192, meta)

      files[#files + 1] = { name = dosname, data = data }
      -- One sample per key. Renoise's own mapping is used when it is distinct,
      -- otherwise the samples are laid out in order from the base key.
      local key = opts.base_key + n - 1
      if opts.use_mapping then key = smp.sample_mapping.note_range[1] end
      splits[#splits + 1] = { key = math.max(0, math.min(127, key)),
                              name = dosname:match("^[^%.]+"), id = waveid }
    end

    table.sort(splits, function(a, b) return a.key < b.key end)
    -- Typhoon keys a split by where it starts, so two samples cannot share one
    -- key; nudge duplicates up rather than silently dropping them.
    for i = 2, #splits do
      if splits[i].key <= splits[i - 1].key then
        splits[i].key = math.min(127, splits[i - 1].key + 1)
      end
    end

    if dvb then dvb.views.progress_text.text = "Building voice file..." end
    coroutine.yield()

    local voicename = PakettiDWVWDosName(kitname, used, "O")
    local voice = PakettiTyphoonBuildVoice(splits, stamp,
      PakettiTyphoonNewWaveId(stamp, voicename, 0))

    if dvb then dvb.views.progress_text.text = "Packing 720K disks..." end
    coroutine.yield()

    local disks = PakettiTyphoonPackDisks(files, 1)
    -- The voice goes on disk 1, where the sampler will look for it first.
    table.insert(disks[1].files, 1, { name = voicename, data = voice })

    local written = {}
    if opts.write_images then
      for i, d in ipairs(disks) do
        if dvb then dvb.views.progress_text.text = string.format("Writing disk %d/%d...", i, #disks) end
        coroutine.yield()
        local label = PakettiDWVWDosName(kitname, {}):match("^[^%.]+"):sub(1, 6)
        local img = PakettiTyphoonBuildDiskImage(d.files,
          string.format("%s%d", label, i), 8)
        local name = string.format("%s_DISK%d.img", label, i)
        write_file(join(outdir, name), img)
        written[#written + 1] = name
      end
    end

    if opts.write_loose then
      local loose = join(outdir, "files")
      os.execute(string.format('mkdir -p "%s"', loose))
      write_file(join(loose, voicename), voice)
      for _, f in ipairs(files) do write_file(join(loose, f.name), f.data) end
    end

    local msg = string.format(
      "Paketti TX16W: %s - %d samples, voice %s, %d disk image(s)%s%s",
      kitname, #files, voicename, #disks,
      (#disks > 1) and " (the voice is on disk 1; the sampler will ask for the others)" or "",
      (oversize > 0) and string.format(", %d too long for the sampler", oversize) or "")
    PakettiTyphoonLastStatus = msg
    renoise.app():show_status(msg)
    print(msg)
    for _, w in ipairs(written) do print("  wrote " .. w) end
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
  }
  typhoon_slicer = ProcessSlicer(function() typhoon_export_process(outdir, resolved) end)
  typhoon_slicer:start()
  return true
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

PakettiAddMenuEntry{name = "Main Menu:File:Paketti Import:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDrumkit() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDrumkit() end}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Save:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDrumkit() end}
PakettiAddMenuEntry{name = "Sample Mappings:Paketti:Save:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDrumkit() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Save:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDrumkit() end}
PakettiAddMenuEntry{name = "Disk Browser:Paketti:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDrumkit() end}

renoise.tool():add_keybinding{name = "Global:Paketti:Export Instrument to Yamaha TX16W", invoke = function() PakettiTyphoonExportDrumkit() end}
renoise.tool():add_midi_mapping{name = "Paketti:Export Instrument to Yamaha TX16W", invoke = function(message) if message:is_trigger() then PakettiTyphoonExportDrumkit() end end}
