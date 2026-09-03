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

-- Does this instrument already have a key layout worth keeping? An instrument
-- someone has mapped -- a GM drum kit, a multisample -- has samples sitting on
-- distinct, narrow key ranges. A pile of samples that was never mapped has
-- every sample answering the whole keyboard, and is better laid out one per key
-- on export. Getting this right matters: silently replacing a GM layout with a
-- sequential one moves every drum.
function PakettiTyphoonHasKeyMapping(instrument)
  local n, narrow, seen = 0, 0, {}
  for _, smp in ipairs(instrument.samples) do
    if smp.sample_buffer and smp.sample_buffer.has_sample_data then
      n = n + 1
      local r = smp.sample_mapping.note_range
      if (r[2] - r[1]) < 119 then narrow = narrow + 1 end
      seen[r[1] .. ":" .. r[2]] = true
    end
  end
  if n < 2 then return false end
  local distinct = 0
  for _ in pairs(seen) do distinct = distinct + 1 end
  -- Both must hold: the samples are on narrow ranges, and they differ from each
  -- other. Ten identical one-key mappings are not a layout.
  return narrow == n and distinct > 1
end

-- General MIDI percussion key map, keyed by MIDI note. Renoise's own GM kit
-- template lays drums out on these keys, so when an instrument follows it the
-- exported waves can be named for what they actually are instead of DRUM_017.
-- Eight characters is all the sampler shows.
PakettiTyphoonGMDrumNames = {
  [35] = "KICK2",   [36] = "KICK1",    [37] = "RIMSHOT",  [38] = "SNARE1",
  [39] = "CLAP",    [40] = "SNARE2",   [41] = "LOWTOM2",  [42] = "HHCLOSED",
  [43] = "LOWTOM1", [44] = "HHPEDAL",  [45] = "MIDTOM2",  [46] = "HHOPEN",
  [47] = "MIDTOM1", [48] = "HITOM2",   [49] = "CRASH1",   [50] = "HITOM1",
  [51] = "RIDE1",   [52] = "CHINESE",  [53] = "RIDEBELL", [54] = "TAMBRIN",
  [55] = "SPLASH",  [56] = "COWBELL",  [57] = "CRASH2",   [58] = "VIBSLAP",
  [59] = "RIDE2",   [60] = "HIBONGO",  [61] = "LOBONGO",  [62] = "MTCONGA",
  [63] = "HICONGA", [64] = "LOCONGA",  [65] = "HITIMBAL", [66] = "LOTIMBAL",
  [67] = "HIAGOGO", [68] = "LOAGOGO",  [69] = "CABASA",   [70] = "MARACAS",
  [71] = "SWHISTLE",[72] = "LWHISTLE", [73] = "SGUIRO",   [74] = "LGUIRO",
  [75] = "CLAVES",  [76] = "HIWOOD",   [77] = "LOWOOD",   [78] = "MUCUICA",
  [79] = "OPCUICA", [80] = "MUTRIANG", [81] = "OPTRIANG",
}

-- The group parameter block, decoded from the factory voices. Only the fields
-- below are written; everything else keeps the value it has in the known-good
-- template, because it has not been decoded.
--
--   byte  0-3   bottom key, top key, min velocity, max velocity   [proven]
--   byte  4     pitch, semitones (signed)                         [strong]
--   byte  5     pitch, cents (signed)                             [strong]
--   byte  6     pitch, octaves (signed)                           [strong]
--   byte 13     filter table, 0 = none, 1-20 = a .T## table       [strong]
--   byte 18     output: 0 none 1 left 2 right 3 mono 4 stereo     [proven]
--   byte 22-27  AEG: attack, decay1, level1, decay2, level2, release  [likely]
--   byte 46     polyphony: 0 = poly on, 1 = poly off (monophonic)   [strong]
--
-- Byte 46 reads 0 on all 35 groups of the eight factory voices and the
-- third-party TR_808, and 1 on all four groups of UNISON -- the one voice the
-- release notes call "a monophonic analog type of lead sound". Byte 47 is
-- almost certainly the glide time (110 on UNISON, the only voice with
-- portamento, 0 everywhere else) but its scale is unknown, so it is left at 0.
--
-- Evidence, in short. Bytes 0-3 hold for all 36 factory groups and NOISEWAV,
-- the one voice the release notes call velocity-gated, reads 90-127. Byte 4:
-- ESQ1BELL's third group sits 12 keys lower and reads 12. Byte 5: UNISON's four
-- groups read -1/+4/-4/+2, the detune spread that makes it a unison patch.
-- Byte 6: 3 on the single-cycle-wave voices, 0 on the sampled ones. Byte 13:
-- ANA_STRS reads 0 and the release notes tell you to "try assigning the new
-- filter table 17:LOWPASS" to it. Byte 18: ANA_STRS and NOISEWAV read 1 then 2
-- for their documented left/right pairs, and FAIRLITE, "a single powerful
-- stereophonic wave", reads 4. Bytes 22-27 give ESQ1BELL a bell curve, FAIRLITE
-- a flat sustain, and the third-party TR_808 exactly 0,0,127,127,127,127 -- the
-- envelope that lets drum samples play out untouched.
PAKETTI_TYPHOON_OUTPUT_NONE   = 0
PAKETTI_TYPHOON_OUTPUT_LEFT   = 1
PAKETTI_TYPHOON_OUTPUT_RIGHT  = 2
PAKETTI_TYPHOON_OUTPUT_MONO   = 3
PAKETTI_TYPHOON_OUTPUT_STEREO = 4

-- The stock filter tables, in the order the sampler numbers them. 17 is the one
-- Typhoon 2000 added; 18-20 are free for tables of your own.
PakettiTyphoonFilterTables = {
  "None", "1 Q LPF", "2 Q HPF", "3 WIDE BPF", "4 NRRW BPF", "5 LOW LPF",
  "6 HIGH LPF", "7 LOW HPF", "8 HIGH HPF", "9 HPF LPF", "10 BPF BEF",
  "11 DIP", "12 PEAK", "13 LOSL LPF", "14 HISL LPF", "15 LOSL HPF",
  "16 HISL HPF", "17 LOWPASS", "18", "19", "20",
}

-- What a drum kit wants: let every sample play out exactly as recorded. Taken
-- from TR_808.O01, a real third-party drum voice.
PAKETTI_TYPHOON_AEG_ONESHOT = {0, 0, 127, 127, 127, 127}

local function signed_byte(v)
  v = math.max(-128, math.min(127, floor(v + 0.5)))
  if v < 0 then v = v + 256 end
  return v
end

local function set_byte(str, index, value)   -- index is 0-based
  return str:sub(1, index) .. string.char(math.max(0, math.min(255, value)))
       .. str:sub(index + 2)
end

-- Applies the decoded fields onto a 64-byte parameter block.
function PakettiTyphoonApplyParm(parm, f)
  if not f then return parm end
  if f.low_key then parm = set_byte(parm, 0, math.max(0, math.min(127, f.low_key))) end
  if f.high_key then parm = set_byte(parm, 1, math.max(0, math.min(127, f.high_key))) end
  if f.low_vel then parm = set_byte(parm, 2, math.max(0, math.min(127, f.low_vel))) end
  if f.high_vel then parm = set_byte(parm, 3, math.max(0, math.min(127, f.high_vel))) end
  if f.semitones then parm = set_byte(parm, 4, signed_byte(f.semitones)) end
  if f.cents then parm = set_byte(parm, 5, signed_byte(f.cents)) end
  if f.octaves then parm = set_byte(parm, 6, signed_byte(f.octaves)) end
  if f.filter then parm = set_byte(parm, 13, math.max(0, math.min(20, f.filter))) end
  if f.output then parm = set_byte(parm, 18, math.max(0, math.min(4, f.output))) end
  if f.mono ~= nil then parm = set_byte(parm, 46, f.mono and 1 or 0) end
  if f.aeg then
    for i = 1, 6 do
      parm = set_byte(parm, 21 + i, math.max(0, math.min(127, f.aeg[i] or 0)))
    end
  end
  return parm
end

-- Reads the instrument's own volume AHDSR, if it has one, as a TX16W AEG.
-- Renoise gives 0..1; the sampler wants 0..127. Renoise has one decay and one
-- sustain, so decay2 is left wide open and level2 tracks the sustain.
function PakettiTyphoonAEGFromInstrument(instrument)
  local ok, aeg = pcall(function()
    for _, set in ipairs(instrument.sample_modulation_sets) do
      for _, dev in ipairs(set.devices) do
        if dev.name and dev.name:find("AHDSR") then
          local function p(name)
            local okv, v = pcall(function() return dev:parameter(name).value end)
            return okv and v or nil
          end
          local attack  = p("Attack")  or (dev.parameters[1] and dev.parameters[1].value)
          local decay   = p("Decay")
          local sustain = p("Sustain")
          local release = p("Release")
          if attack and sustain then
            local function to127(v) return floor(math.max(0, math.min(1, v)) * 127 + 0.5) end
            return {
              to127(attack), to127(decay or 0), to127(sustain),
              127, to127(sustain), to127(release or 0),
            }
          end
        end
      end
    end
    return nil
  end)
  return ok and aeg or nil
end

-- The modulation table, decoded from the factory voices. Each Mod chunk is six
-- bytes: source, destination, freeze, 0x0F, then the amount.
--
--   byte 0  source index, 0-based (0-14, the 15 sources below)
--   byte 1  destination index, 0-based (0-12, the 13 destinations below)
--   byte 2  freeze flag: take the source's value at key-down and hold it
--   byte 3  always 0x0F in all 288 chunks surveyed
--   byte 4  amount; semitones when the destination is Pitch
--   byte 5  amount, low part; cents when the destination is Pitch
--
-- The 0-based reading is confirmed by the first entry of nearly every factory
-- voice being source 5 / destination 0 = pitch bend to pitch shifter, which is
-- also the only modulation the Typhoon import routine converts from the Yamaha
-- OS. All 288 chunks have byte 0 <= 14 and byte 1 <= 9.
PakettiTyphoonModSources = {
  "Velocity", "Velocity in range", "Key", "Key in range", "Mod wheel",
  "Pitch bend", "Pitch bend, held keys", "External controller 1",
  "External controller 2", "Aftertouch", "External input (front panel)",
  "LFO 1", "LFO 2", "Envelope 1", "Envelope 2",
}

PakettiTyphoonModDestinations = {
  "Pitch", "Volume", "Filter", "Pan", "AEG attack", "AEG time",
  "Glide time", "LFO 1 depth", "LFO 2 depth", "LFO 1 rate", "LFO 2 rate",
  "Envelope 1 depth", "Envelope 2 depth",
}

PAKETTI_TYPHOON_MOD_ENTRIES = 8

-- "src:dst:frz:a:b,..." -> a list of 6-byte Mod chunk bodies.
function PakettiTyphoonParseModMatrix(str)
  local mods = {}
  for entry in tostring(str or ""):gmatch("[^,]+") do
    local src, dst, frz, a, b = entry:match(
      "^%s*(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)%s*$")
    if src then
      local function clamp(v, hi) return math.max(0, math.min(hi, tonumber(v) or 0)) end
      mods[#mods + 1] = string.char(
        clamp(src, #PakettiTyphoonModSources - 1),
        clamp(dst, #PakettiTyphoonModDestinations - 1),
        clamp(frz, 1), 15, clamp(a, 255), clamp(b, 255))
    end
    if #mods >= PAKETTI_TYPHOON_MOD_ENTRIES then break end
  end
  return mods
end

function PakettiTyphoonFormatModMatrix(mods)
  local out = {}
  for _, m in ipairs(mods) do
    out[#out + 1] = string.format("%d:%d:%d:%d:%d",
      m:byte(1), m:byte(2), m:byte(3), m:byte(5), m:byte(6))
  end
  return table.concat(out, ",")
end

-- The routing written into exported voices. Falls back to the factory table.
function PakettiTyphoonModMatrix()
  local ok, v = pcall(function() return preferences.pakettiTX16WModMatrix.value end)
  if ok and type(v) == "string" and v ~= "" then
    local mods = PakettiTyphoonParseModMatrix(v)
    if #mods > 0 then
      while #mods < PAKETTI_TYPHOON_MOD_ENTRIES do
        mods[#mods + 1] = string.char(0, 0, 0, 15, 0, 0)
      end
      return mods
    end
  end
  return PakettiTyphoonDefaultMods
end

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
  local parm = PakettiTyphoonApplyParm(PakettiTyphoonDefaultParm, range)

  local parts = { chunk("Parm", parm) }
  for _, m in ipairs(PakettiTyphoonModMatrix()) do
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
-- Filter tables (.T##)
--------------------------------------------------------------------------------

-- 4096 bytes exactly:
--     0..15    "LM8953" + 10 NUL   (the TX16W's filter chip)
--    16..3887  121 kernels x 32 bytes, an 11 x 11 grid
--  3888..3903  two 8-character axis names
--  3904..4095  192 bytes, zero
--
-- Each 16-word kernel is one gain word followed by 15 FIR taps, big-endian.
-- That split is measured, not guessed: across the 17 factory tables every one
-- of the 30,855 taps in words 1-15 fits in 12-bit signed, while word 0 reaches
-- 14334.
--
-- The grid axes both run 0-100 in steps of 10, which is why the manual allows
-- only multiples of 10 on the static axis. Row and column 10 repeat row and
-- column 9.
PAKETTI_TYPHOON_FILTER_SIZE = 4096
PAKETTI_TYPHOON_FILTER_GRID = 11
PAKETTI_TYPHOON_FILTER_TAPS = 15

-- Axis names are 10 bytes each, space padded, back to back at 3888.
PAKETTI_TYPHOON_FILTER_AXIS_LEN = 10

local function filter_name_field(name)
  name = tostring(name or ""):sub(1, PAKETTI_TYPHOON_FILTER_AXIS_LEN)
  return name .. string.rep(" ", PAKETTI_TYPHOON_FILTER_AXIS_LEN - #name)
end

-- kernels[i] is a list of 15 taps plus a gain, as { gain = n, taps = {...} },
-- indexed 1..121 in row-major order (row = static axis, column = dynamic axis).
function PakettiTyphoonBuildFilterTable(kernels, axis1, axis2)
  local n = PAKETTI_TYPHOON_FILTER_GRID * PAKETTI_TYPHOON_FILTER_GRID
  assert(#kernels == n, string.format("a filter table needs %d kernels, got %d", n, #kernels))

  local parts = { "LM8953" .. string.rep("\000", 10) }
  for k = 1, n do
    local kern = kernels[k]
    parts[#parts + 1] = be(math.max(0, math.min(65535, floor(kern.gain or 1024))), 16)
    for t = 1, PAKETTI_TYPHOON_FILTER_TAPS do
      -- Taps are 12-bit signed two's complement in a 16-bit word.
      local v = floor((kern.taps[t] or 0) + 0.5)
      v = math.max(-2048, math.min(2047, v))
      if v < 0 then v = v + 4096 end
      parts[#parts + 1] = be(v, 16)
    end
  end
  parts[#parts + 1] = filter_name_field(axis1 or "freq")
  parts[#parts + 1] = filter_name_field(axis2 or "reson")
  -- The nine older factory tables repeat the axis names again at 4064. The one
  -- Typhoon 2000 wrote, LOWPASS.T17, leaves that area zero, so we do too.
  parts[#parts + 1] = string.rep("\000", 188)

  local data = table.concat(parts)
  assert(#data == PAKETTI_TYPHOON_FILTER_SIZE,
    string.format("filter table came out %d bytes, not %d", #data, PAKETTI_TYPHOON_FILTER_SIZE))
  return data
end

-- Designs one 15-tap linear-phase FIR. cut and res both run 0..1.
-- kind is "lowpass", "highpass", "bandpass" or "notch".
local function design_kernel(kind, cut, res)
  local N = PAKETTI_TYPHOON_FILTER_TAPS
  local mid = (N - 1) / 2
  -- Keep away from 0 and Nyquist, where a 15-tap FIR degenerates.
  local fc = 0.03 + cut * 0.44
  local taps = {}

  local function sinc(x)
    if math.abs(x) < 1e-9 then return 1 end
    return math.sin(math.pi * x) / (math.pi * x)
  end

  for i = 0, N - 1 do
    local d = i - mid
    -- Hamming window: a 15-tap rectangular design ripples badly.
    local w = 0.54 - 0.46 * math.cos(2 * math.pi * i / (N - 1))
    local h
    if kind == "highpass" then
      h = (sinc(d) - 2 * fc * sinc(2 * fc * d)) * w
    elseif kind == "bandpass" then
      local lo, hi = fc * 0.6, math.min(0.49, fc * 1.6)
      h = (2 * hi * sinc(2 * hi * d) - 2 * lo * sinc(2 * lo * d)) * w
    elseif kind == "notch" then
      local lo, hi = fc * 0.6, math.min(0.49, fc * 1.6)
      h = (sinc(d) - (2 * hi * sinc(2 * hi * d) - 2 * lo * sinc(2 * lo * d))) * w
    else
      h = 2 * fc * sinc(2 * fc * d) * w
    end
    -- Resonance: emphasise the cutoff band by adding a windowed cosine at fc.
    -- A 15-tap FIR cannot really resonate, so this is a peak, not a howl.
    h = h + res * 0.9 * math.cos(2 * math.pi * fc * d) * w / N
    taps[i + 1] = h
  end

  -- Scale into the range the factory tables actually use. LOWPASS.T17, the
  -- newest and cleanest table, peaks at 1822; staying under 1600 keeps a
  -- margin and never clips the 12-bit field.
  local peak = 0
  for _, v in ipairs(taps) do peak = math.max(peak, math.abs(v)) end
  if peak < 1e-9 then peak = 1 end
  local scale = 1500 / peak
  local out, dc = {}, 0
  for i, v in ipairs(taps) do
    out[i] = v * scale
    dc = dc + out[i]
  end
  -- Word 0 tracks the peak tap, as it does in LOWPASS.T17, and stays inside
  -- the 150..2047 band that table uses.
  local gain = math.max(150, math.min(2047, floor(math.abs(dc) + 0.5)))
  return { gain = gain, taps = out }
end

-- Builds a whole 11 x 11 table. The dynamic axis is cutoff, the static axis is
-- resonance (or level for the non-resonant shapes), matching how the factory
-- tables name their axes.
function PakettiTyphoonDesignFilterTable(kind)
  local kernels = {}
  local G = PAKETTI_TYPHOON_FILTER_GRID
  for row = 0, G - 1 do
    for col = 0, G - 1 do
      -- Row and column 10 repeat 9, exactly as the factory tables do.
      local r = math.min(row, G - 2) / (G - 2)
      local c = math.min(col, G - 2) / (G - 2)
      kernels[#kernels + 1] = design_kernel(kind, c, r)
    end
  end
  local axis2 = (kind == "lowpass" or kind == "highpass") and "reson" or "level"
  return PakettiTyphoonBuildFilterTable(kernels, "freq", axis2)
end

function PakettiTyphoonExportFilterTable()
  local kinds = {"lowpass", "highpass", "bandpass", "notch"}
  local labels = {"Low pass", "High pass", "Band pass", "Notch"}
  local vb = renoise.ViewBuilder()
  local dlg
  local content = vb:column{
    margin = 10, spacing = 6,
    vb:text{text = "Create a TX16W filter table (.T18)", font = "bold"},
    vb:text{text = "The sampler holds twenty filter tables and ships with seventeen, so 18, 19\n"
                .. "and 20 are free. Put the file on a disk with your kit and assign it as the\n"
                .. "group's filter."},
    vb:row{
      vb:text{text = "Shape", width = 60},
      vb:popup{id = "ft_kind", items = labels, value = 1, width = 200},
    },
    vb:row{
      vb:text{text = "Slot", width = 60},
      vb:popup{id = "ft_slot", items = {"18", "19", "20"}, value = 1, width = 200},
    },
    vb:text{text = "Untested on real hardware. The file's structure is verified against the\n"
                .. "seventeen factory tables, but how it sounds on a TX16W is not known."},
    vb:row{
      spacing = 6,
      vb:button{text = "Write...", width = 100, notifier = function()
        local kind = kinds[vb.views.ft_kind.value]
        local slot = ({"18", "19", "20"})[vb.views.ft_slot.value]
        local path = renoise.app():prompt_for_filename_to_write(
          "T" .. slot, "Save the filter table as")
        if not path or path == "" then return end
        if not path:upper():match("%.T%d%d$") then
          path = path:gsub("%.[^%.]*$", "") .. ".T" .. slot
        end
        local ok, err = pcall(function()
          write_file(path, PakettiTyphoonDesignFilterTable(kind))
        end)
        if ok then
          renoise.app():show_status("Paketti TX16W: wrote " .. path)
          print("PakettiTyphoon: wrote filter table " .. path)
          pcall(function() renoise.app():open_path(path:match("^(.*)[/\\][^/\\]*$")) end)
        else
          renoise.app():show_status("Paketti TX16W: could not write the filter table: " .. tostring(err))
        end
        if dlg and dlg.visible then dlg:close() end
      end},
      vb:button{text = "Cancel", width = 80, notifier = function()
        if dlg and dlg.visible then dlg:close() end
      end},
    },
  }
  dlg = renoise.app():show_custom_dialog("TX16W Filter Table", content, my_keyhandler_func)
end

--------------------------------------------------------------------------------
-- Performances (.P##) and setups (.X##)
--------------------------------------------------------------------------------

-- A performance is the multitimbral layer: a list of entries, each putting one
-- voice on one MIDI channel with its own volume and transposition, plus a
-- program change table.
--
--   FORM TYPP
--     VInf 16   creator stamp + item id
--     Parm  4   performance globals; every factory file reads 00 ff 04 0a
--     Entr 48   one per entry
--       Parm 12  byte 0 = MIDI channel 0-based (0xFF = any)
--                byte 1 = transpose, byte 2-3 = volume
--       Voic 20  reference chunk
--     PChg 38   one per program change
--       Parm  2  byte 0 = program number
--       Voic 20  reference chunk
--
-- Confirmed against MULTI.P01, where the three voices the release notes place
-- on MIDI channels 1, 2 and 10 read 0x00, 0x01 and 0x09, and the four program
-- changes documented as PCH 000-003 read 0x00-0x03.
PAKETTI_TYPHOON_PERF_GLOBALS = "\000\255\004\010"

-- entries: { name = "PIANO", id = <4 bytes>, disk = "DISK1",
--            channel = 0-15 or nil for any, transpose = 0, volume = 96 }
-- programs: { program = 0-127, name =, id =, disk = }
function PakettiTyphoonBuildPerformance(entries, stamp, perfid, programs)
  assert(#entries > 0, "a performance needs at least one entry")

  local function ref(e)
    local disk = e.disk and PakettiTyphoonWaveName(e.disk) or string.rep("\255", 8)
    return chunk("Voic", PakettiTyphoonWaveName(e.name) .. e.id .. disk)
  end

  local parts = { chunk("Parm", PAKETTI_TYPHOON_PERF_GLOBALS) }
  for _, e in ipairs(entries) do
    local ch = e.channel and math.max(0, math.min(15, e.channel)) or 255
    local vol = math.max(0, math.min(127, e.volume or 96))
    local body = chunk("Parm", string.char(ch, (e.transpose or 0) % 256)
      .. be(vol, 16) .. string.rep("\000", 4) .. "\000\007\002\000")
      .. ref(e)
    parts[#parts + 1] = chunk("Entr", body)
  end
  for _, pc in ipairs(programs or {}) do
    parts[#parts + 1] = chunk("PChg",
      chunk("Parm", string.char(math.max(0, math.min(127, pc.program)), 0)) .. ref(pc))
  end

  local body = "TYPP" .. chunk("VInf", stamp .. perfid) .. table.concat(parts)
  return "FORM" .. be(#body, 32) .. body
end

-- A setup is the whole machine: every performance, voice and wave in memory.
-- Loading one clears the sampler and rebuilds the lot.
--
--   FORM TYPS / VInf 16 / Parm 56 / then a flat list of Perf, Voic and Wave
--   reference chunks, 20 bytes each.
function PakettiTyphoonBuildSetup(name, stamp, setupid, perfs, voices, waves)
  local function ref(id, e)
    local disk = e.disk and PakettiTyphoonWaveName(e.disk) or string.rep("\255", 8)
    return chunk(id, PakettiTyphoonWaveName(e.name) .. e.id .. disk)
  end

  -- The 56-byte globals carry the setup's own name and the current disk name.
  -- The surrounding bytes are copied from DEMO.X01, which is a working setup.
  local parm = "\255\255\000\000\000\002\004\006\255\255\255\255\255\255\255\255\255"
    .. PakettiTyphoonWaveName(name) .. "\000\000\000\000"
    .. PakettiTyphoonWaveName("NONAME") .. "\000\000\000\001\000\001\000\002\001"
    .. "\061\105\000\000" .. "DUMP" .. string.rep("\000", 7) .. "\255"
  parm = parm:sub(1, 56) .. string.rep("\000", math.max(0, 56 - #parm))

  local parts = { chunk("Parm", parm) }
  for _, e in ipairs(perfs or {}) do parts[#parts + 1] = ref("Perf", e) end
  for _, e in ipairs(voices or {}) do parts[#parts + 1] = ref("Voic", e) end
  for _, e in ipairs(waves or {}) do parts[#parts + 1] = ref("Wave", e) end

  local body = "TYPS" .. chunk("VInf", stamp .. setupid) .. table.concat(parts)
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
-- Encodes one instrument into its .C01 waves plus the group list a voice is
-- built from. Shared by the single-instrument export and the whole-song export.
-- Returns files, voice_groups, total sample points, and how many samples are
-- too long for the machine.
local function encode_instrument(instrument, opts, stamp, used, progress, cancelled)
  local samples = {}
  for i, smp in ipairs(instrument.samples) do
    if smp.sample_buffer and smp.sample_buffer.has_sample_data then
      samples[#samples + 1] = { index = i, sample = smp }
    end
  end
  if #samples == 0 then error("the selected instrument has no sample data") end

  local files, splits = {}, {}
  local oversize = 0
  -- Sample points the kit will occupy in the machine's RAM, counted
  -- uncompressed because that is how the sampler holds it.
  local total_points = 0

  for n, entry in ipairs(samples) do
    if cancelled and cancelled() then error("cancelled") end
    if progress then
      progress(string.format("%s: encoding %d/%d, %s",
        instrument.name, n, #samples, entry.sample.name))
    end
    coroutine.yield()

    local smp = entry.sample
    local buffer = smp.sample_buffer
    local rate = (opts.rate > 0) and opts.rate or buffer.sample_rate
    local basename = (smp.name ~= "" and smp.name or ("SAMPLE" .. n))
    if opts.gm_names then
      -- Name it for the drum it sits on, when it sits on a GM percussion key.
      local key = opts.use_mapping and smp.sample_mapping.note_range[1]
                  or (opts.base_key + n - 1)
      local gm = PakettiTyphoonGMDrumNames[key]
      if gm then basename = gm end
    end
    local dosname = PakettiDWVWDosName(basename, used)
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

  return files, splits, total_points, oversize
end

-- Turns a flat split list into the voice's groups. The TX16W carries the
-- velocity range on the GROUP, not the split, so each distinct velocity range
-- becomes its own group. Instruments with a single range (the usual case) come
-- out as one group. Call this after the disks are packed, so every split
-- already knows which diskette its wave landed on.
local function build_voice_groups(instrument, splits, opts)
  -- The amplitude envelope written into every group. "One-shot" is the
  -- envelope a real drum voice uses: nothing is cut short, every sample plays
  -- out as recorded.
  local aeg = nil
  if opts.envelope == "oneshot" then
    aeg = PAKETTI_TYPHOON_AEG_ONESHOT
  elseif opts.envelope == "instrument" then
    aeg = PakettiTyphoonAEGFromInstrument(instrument)
    if not aeg then
      print("PakettiTyphoon: the instrument has no AHDSR envelope, keeping the template's")
    end
  end

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
    local highk = 96
    for _, sp in ipairs(L.splits) do
      if sp.note_range and sp.note_range[2] then
        highk = math.max(highk, math.min(127, sp.note_range[2]))
      end
    end
    L.range.low_key = 0
    L.range.high_key = math.max(highk, L.splits[#L.splits].key)
    L.range.end_key = math.min(127, L.splits[#L.splits].key + 1)
    L.range.filter = opts.filter_table
    L.range.output = opts.output
    L.range.aeg = aeg
    L.range.mono = opts.mono_voice
    voice_groups[#voice_groups + 1] = L
  end
  return voice_groups
end

local function typhoon_export_process(outdir, opts)
  local dialog, dvb = nil, nil
  if typhoon_slicer then dialog, dvb = typhoon_slicer:create_dialog("Paketti TX16W Export") end
  local slicer = typhoon_slicer

  local ok, err = pcall(function()
    local song = renoise.song()
    local instrument = song.selected_instrument
    local kitname = instrument.name
    if kitname == "" then kitname = "KIT" end

    local stamp = PakettiTyphoonNewStamp()
    local used = {}
    local files, splits, total_points, oversize = encode_instrument(
      instrument, opts, stamp, used,
      function(t) if dvb then dvb.views.progress_text.text = t end end,
      function() return slicer and slicer:was_cancelled() end)

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

    local voice_groups = build_voice_groups(instrument, splits, opts)

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
    use_mapping = (opts.use_mapping ~= nil) and opts.use_mapping
                  or PakettiTyphoonHasKeyMapping(renoise.song().selected_instrument),
    filter_table = opts.filter_table,
    output = opts.output,
    envelope = opts.envelope,
    gm_names = opts.gm_names or false,
    mono_voice = opts.mono_voice,
    write_images = (opts.write_images ~= false),
    write_loose = (opts.write_loose ~= false),
    reveal = (opts.reveal ~= false),
  }
  typhoon_slicer = ProcessSlicer(function() typhoon_export_process(outdir, resolved) end)
  typhoon_slicer:start()
  return true
end

--------------------------------------------------------------------------------
-- Whole-song export: every instrument as a voice, plus a performance and setup
--------------------------------------------------------------------------------

local function typhoon_song_process(outdir, opts)
  local dialog, dvb = nil, nil
  if typhoon_slicer then dialog, dvb = typhoon_slicer:create_dialog("Paketti TX16W Song Export") end
  local slicer = typhoon_slicer
  local function progress(t) if dvb then dvb.views.progress_text.text = t end end

  local ok, err = pcall(function()
    local song = renoise.song()

    -- Which instruments to send, and which MIDI channel each lands on. An
    -- instrument that a track plays takes that track's number as its channel,
    -- so the sampler's multitimbral layout mirrors the song's.
    local wanted = {}
    for i, ins in ipairs(song.instruments) do
      local has = false
      for _, smp in ipairs(ins.samples) do
        if smp.sample_buffer and smp.sample_buffer.has_sample_data then has = true break end
      end
      if has then wanted[#wanted + 1] = { index = i, instrument = ins } end
    end
    if #wanted == 0 then error("this song has no instruments with sample data") end
    -- The performance has 16 MIDI channels; past that the sampler cannot
    -- address them separately.
    if #wanted > 16 then
      print(string.format("PakettiTyphoon: %d instruments, only the first 16 get their own MIDI channel", #wanted))
    end

    local songname = song.name
    if songname == "" then songname = "SONG" end

    local stamp = PakettiTyphoonNewStamp()
    local used, files = {}, {}
    local per_instrument, total_points, oversize = {}, 0, 0

    for n, w in ipairs(wanted) do
      if slicer and slicer:was_cancelled() then error("cancelled") end
      progress(string.format("Instrument %d/%d: %s", n, #wanted, w.instrument.name))
      coroutine.yield()

      local f, splits, points, over = encode_instrument(
        w.instrument, opts, stamp, used, progress,
        function() return slicer and slicer:was_cancelled() end)
      total_points = total_points + points
      oversize = oversize + over
      for _, x in ipairs(f) do files[#files + 1] = x end

      local vname = PakettiDWVWDosName(
        (w.instrument.name ~= "" and w.instrument.name or ("VOICE" .. n)), used, "O")
      per_instrument[#per_instrument + 1] = {
        instrument = w.instrument, splits = splits, voicename = vname,
        voiceid = PakettiTyphoonNewWaveId(stamp, vname, n),
        channel = (n <= 16) and (n - 1) or nil,
      }
    end

    progress("Packing 720K disks...")
    coroutine.yield()

    -- One entry per voice and one for the setup, on top of the waves.
    local labelbase = PakettiDWVWDosName(songname, {}):match("^[^%.]+"):sub(1, 6)
    local disks = PakettiTyphoonPackDisks(files, #per_instrument + 2)
    local disk_of = {}
    for i, d in ipairs(disks) do
      for _, f in ipairs(d.files) do
        disk_of[f.name] = string.format("%s%d", labelbase, i)
      end
    end

    progress("Building voices...")
    coroutine.yield()

    local voice_refs = {}
    for _, pi in ipairs(per_instrument) do
      for _, sp in ipairs(pi.splits) do sp.disk = disk_of[sp.file] end
      local groups = build_voice_groups(pi.instrument, pi.splits, opts)
      pi.voice = PakettiTyphoonBuildVoice(groups, stamp, pi.voiceid)
      voice_refs[#voice_refs + 1] = {
        name = pi.voicename:match("^[^%.]+"), id = pi.voiceid,
        disk = string.format("%s1", labelbase),
      }
      coroutine.yield()
    end

    progress("Building performance and setup...")
    coroutine.yield()

    local entries = {}
    for i, pi in ipairs(per_instrument) do
      entries[#entries + 1] = {
        name = pi.voicename:match("^[^%.]+"), id = pi.voiceid,
        disk = string.format("%s1", labelbase),
        channel = pi.channel, volume = 96,
      }
      if i > 16 then entries[#entries].channel = nil end
    end
    -- Program changes let one MIDI channel step through the voices.
    local programs = {}
    for i, v in ipairs(voice_refs) do
      if i <= 128 then
        programs[#programs + 1] = { program = i - 1, name = v.name, id = v.id, disk = v.disk }
      end
    end

    local perfname = PakettiDWVWDosName(songname, used, "P")
    local perfid = PakettiTyphoonNewWaveId(stamp, perfname, 200)
    local perf = PakettiTyphoonBuildPerformance(entries, stamp, perfid, programs)

    local wave_refs = {}
    for _, pi in ipairs(per_instrument) do
      for _, sp in ipairs(pi.splits) do
        wave_refs[#wave_refs + 1] = { name = sp.name, id = sp.id, disk = sp.disk }
      end
    end
    local setupname = PakettiDWVWDosName(songname, used, "X")
    local setup = PakettiTyphoonBuildSetup(
      setupname:match("^[^%.]+"), stamp,
      PakettiTyphoonNewWaveId(stamp, setupname, 201),
      {{ name = perfname:match("^[^%.]+"), id = perfid, disk = labelbase .. "1" }},
      voice_refs, wave_refs)

    -- Setup, performance and every voice go on disk 1, which is the disk the
    -- sampler is asked for first.
    table.insert(disks[1].files, 1, { name = setupname, data = setup })
    table.insert(disks[1].files, 2, { name = perfname, data = perf })
    for i, pi in ipairs(per_instrument) do
      table.insert(disks[1].files, 2 + i, { name = pi.voicename, data = pi.voice })
    end

    local installed = PakettiTyphoonInstalledPoints()
    local ram_warning = (total_points > installed) and string.format(
      "needs %s of sample memory but the TX16W is set to %s - it will not all load",
      format_mb(total_points), format_mb(installed)) or nil

    local manifest = {
      string.format("%s - Yamaha TX16W song export", songname),
      string.format("%d instrument(s), %d sample(s), %d disk(s)",
        #per_instrument, #files, #disks),
      string.format("Sample memory needed: %s of the %s installed%s",
        format_mb(total_points), format_mb(installed),
        ram_warning and "   *** TOO BIG ***" or ""),
      "",
      "Load " .. setupname .. " to rebuild the whole song on the sampler, or load",
      perfname .. " for just the multitimbral setup.",
      "",
      "MIDI channels:",
    }
    for i, pi in ipairs(per_instrument) do
      manifest[#manifest + 1] = string.format("    %-2s  %-12s (program change %d)",
        pi.channel and tostring(pi.channel + 1) or "-", pi.voicename, i - 1)
    end
    manifest[#manifest + 1] = ""
    for i, d in ipairs(disks) do
      manifest[#manifest + 1] = string.format("Disk %d  (label %s%d)", i, labelbase, i)
      for _, f in ipairs(d.files) do
        manifest[#manifest + 1] = string.format("    %-14s %8d bytes", f.name, #f.data)
      end
      manifest[#manifest + 1] = ""
    end

    local written = {}
    if opts.write_images ~= false then
      for i, d in ipairs(disks) do
        progress(string.format("Writing disk %d/%d...", i, #disks))
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

    if opts.write_loose ~= false then
      local loose = join(outdir, "files")
      ensure_dir(loose)
      write_file(join(loose, setupname), setup)
      write_file(join(loose, perfname), perf)
      for _, pi in ipairs(per_instrument) do
        write_file(join(loose, pi.voicename), pi.voice)
      end
      for _, f in ipairs(files) do write_file(join(loose, f.name), f.data) end
    end

    local msg = string.format(
      "Paketti TX16W: %s - %d instruments, %d samples, setup %s, performance %s, %d disk(s) in %s%s",
      songname, #per_instrument, #files, setupname, perfname, #disks, outdir,
      (oversize > 0) and string.format(", %d too long for the sampler", oversize) or "")
    if ram_warning then msg = msg .. " - WARNING: " .. ram_warning end
    PakettiTyphoonLastStatus = msg
    renoise.app():show_status(msg)
    print(msg)

    if opts.reveal ~= false then
      pcall(function() renoise.app():open_path(outdir) end)
    end
  end)

  if dialog and dialog.visible then dialog:close() end
  typhoon_slicer = nil
  if not ok then
    renoise.app():show_status("Paketti TX16W song export failed: " .. tostring(err))
    print("PakettiTyphoon song export error: " .. tostring(err))
    PakettiTyphoonLastStatus = "song export failed: " .. tostring(err)
  end
end

function PakettiTyphoonExportSong(outdir, opts)
  if typhoon_slicer and typhoon_slicer:running() then
    renoise.app():show_status("Paketti TX16W: an export is already running")
    return false
  end
  if not outdir or outdir == "" then
    outdir = renoise.app():prompt_for_path("Where should the TX16W song export go?")
    if not outdir or outdir == "" then return false end
  end
  opts = opts or {}
  local resolved = {
    rate = opts.rate or PakettiDWVWTargetRate(),
    wordsize = opts.wordsize or PakettiDWVWWordSize(),
    force_mono = (opts.force_mono ~= nil) and opts.force_mono or PakettiDWVWForceMono(),
    base_key = opts.base_key or 36,
    use_mapping = (opts.use_mapping ~= false),
    gm_names = opts.gm_names or false,
    filter_table = opts.filter_table,
    output = opts.output,
    envelope = opts.envelope,
    write_images = (opts.write_images ~= false),
    write_loose = (opts.write_loose ~= false),
    reveal = (opts.reveal ~= false),
  }
  typhoon_slicer = ProcessSlicer(function() typhoon_song_process(outdir, resolved) end)
  typhoon_slicer:start()
  return true
end

--------------------------------------------------------------------------------
-- MIDI Sample Dump Standard: samples down a cable, no floppies
--------------------------------------------------------------------------------

-- Typhoon can receive a wave over MIDI (manual 4.9.7 "Dump"), using the MIDI
-- Sample Dump Standard. That means a sample can go straight from Renoise to the
-- sampler with no disk in between.
--
--   Header  F0 7E <ch> 01 <sample# 14bit> <bits> <period ns 21bit>
--                        <length 21bit> <loop start 21bit> <loop end 21bit>
--                        <loop type> F7
--   Packet  F0 7E <ch> 02 <packet# 0-127> <120 data bytes> <checksum> F7
--
-- Every multi-byte field is 7 bits per byte, least significant first. Sample
-- words are left-justified and packed MSB-first across the 7-bit bytes, so a
-- 12-bit sample occupies two bytes and a 16-bit sample three.
--
-- This sends open loop. The standard allows it: a sender that gets no ACK
-- within 20 ms carries on regardless, which is what happens here since Renoise
-- gives no practical way to block on a reply mid-send.

PAKETTI_SDS_LOOP_FORWARD = 0
PAKETTI_SDS_LOOP_BIDIR   = 1
PAKETTI_SDS_LOOP_NONE    = 127

local function sds_u21(v)
  v = math.max(0, floor(v))
  return v % 128, floor(v / 128) % 128, floor(v / 16384) % 128
end

function PakettiTyphoonSDSHeader(channel, sample_num, bits, rate, frames,
                                 loop_start, loop_end, loop_type)
  local period = floor(1000000000 / math.max(1, rate) + 0.5)   -- nanoseconds
  local b = { 0xF0, 0x7E, channel % 128, 0x01,
              sample_num % 128, floor(sample_num / 128) % 128,
              math.max(8, math.min(28, bits)) }
  local function push(v) local a, c, d = sds_u21(v); b[#b+1]=a; b[#b+1]=c; b[#b+1]=d end
  push(period) ; push(frames) ; push(loop_start) ; push(loop_end)
  b[#b + 1] = loop_type % 128
  b[#b + 1] = 0xF7
  return b
end

function PakettiTyphoonSDSRequest(channel, sample_num)
  return { 0xF0, 0x7E, channel % 128, 0x03,
           sample_num % 128, floor(sample_num / 128) % 128, 0xF7 }
end

-- ints are signed sample values at `bits` resolution. Returns a list of
-- complete SysEx packets.
function PakettiTyphoonSDSPackets(channel, ints, n, bits, yield_every)
  local bytes_per = math.ceil(bits / 7)
  local half = 2 ^ (bits - 1)
  -- Left-justify each word into the top of its byte group, which is what the
  -- standard means by "most significant bit first, left justified".
  local shift = bytes_per * 7 - bits

  local stream, si = {}, 0
  for i = 1, n do
    -- SDS words are unsigned with centre at half scale.
    local v = (ints[i] or 0) + half
    if v < 0 then v = 0 elseif v > half * 2 - 1 then v = half * 2 - 1 end
    v = v * (2 ^ shift)
    for k = bytes_per - 1, 0, -1 do
      si = si + 1
      stream[si] = floor(v / (128 ^ k)) % 128
    end
    if yield_every and i % yield_every == 0 then coroutine.yield() end
  end

  -- Lua 5.1 has no bitwise operators, so the checksum XOR is done by hand.
  local function bxor(a, b)
    local r, bit = 0, 1
    for _ = 1, 8 do
      local x, y = a % 2, b % 2
      if x ~= y then r = r + bit end
      a = floor(a / 2) ; b = floor(b / 2) ; bit = bit * 2
    end
    return r
  end

  local packets, pnum, pos = {}, 0, 1
  while pos <= si do
    local p = { 0xF0, 0x7E, channel % 128, 0x02, pnum % 128 }
    -- Checksum is the XOR of everything from the channel byte through the last
    -- data byte, which includes the 0x02 and the packet number.
    local xor = bxor(channel % 128, 0x02)
    xor = bxor(xor, pnum % 128)
    for k = 1, 120 do
      local v = (pos <= si) and stream[pos] or 0
      p[#p + 1] = v
      xor = bxor(xor, v)
      pos = pos + 1
    end
    p[#p + 1] = xor % 128
    p[#p + 1] = 0xF7
    packets[#packets + 1] = p
    pnum = pnum + 1
    if yield_every then coroutine.yield() end
  end
  return packets
end

local sds_timer = nil

local function sds_stop()
  if sds_timer then
    pcall(function() renoise.tool():remove_timer(sds_timer) end)
    sds_timer = nil
  end
end

-- Sends header then packets, paced. Pacing is not optional: MIDI runs at 31250
-- baud so a 127-byte packet needs ~41 ms on the wire, and firing the next one
-- early lets short messages overtake queued long ones.
function PakettiTyphoonSDSSend(device_name, channel, sample_num, sample, gap_ms)
  local buffer = sample and sample.sample_buffer
  if not buffer or not buffer.has_sample_data then
    renoise.app():show_status("Paketti SDS: that sample has no audio")
    return false
  end
  local ok_dev, dev = pcall(function() return renoise.Midi.create_output_device(device_name) end)
  if not ok_dev or not dev then
    renoise.app():show_status("Paketti SDS: could not open MIDI output '" .. tostring(device_name) .. "'")
    return false
  end

  local bits = PakettiDWVWWordSize()
  local rate = PakettiDWVWTargetRate()
  if rate <= 0 then rate = buffer.sample_rate end

  local channels, frames = PakettiDWVWBufferToChannels(
    buffer, rate, true, bits, nil, PakettiDWVWLoopLimit(sample, buffer))

  local ls, le, lt = 0, math.max(0, frames - 1), PAKETTI_SDS_LOOP_NONE
  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
    local meta = PakettiDWVWSampleMeta(sample, buffer, frames)
    if meta and meta.loop_start then
      ls, le = meta.loop_start - 1, meta.loop_end - 1
      lt = (sample.loop_mode == renoise.Sample.LOOP_MODE_PING_PONG)
           and PAKETTI_SDS_LOOP_BIDIR or PAKETTI_SDS_LOOP_FORWARD
    end
  end

  local msgs = { PakettiTyphoonSDSHeader(channel, sample_num, bits, rate, frames, ls, le, lt) }
  for _, p in ipairs(PakettiTyphoonSDSPackets(channel, channels[1], frames, bits)) do
    msgs[#msgs + 1] = p
  end

  sds_stop()
  local i, total = 0, #msgs
  gap_ms = gap_ms or 10

  local tick
  tick = function()
    -- Nothing here may throw: an error escaping a timer notifier makes Renoise
    -- disable every notifier this tool owns until Renoise is restarted.
    pcall(function()
      pcall(function() renoise.tool():remove_timer(tick) end)
      i = i + 1
      if i > total then
        sds_timer = nil
        pcall(function() dev:close() end)
        renoise.app():show_status(string.format(
          "Paketti SDS: sent sample %d - %d frames, %d-bit, %d Hz, %d messages",
          sample_num, frames, bits, rate, total))
        return
      end
      local m = msgs[i]
      pcall(function() dev:send(m) end)
      if i % 25 == 0 then
        renoise.app():show_status(string.format("Paketti SDS: sending %d/%d...", i, total))
      end
      local wait = math.ceil(#m * 0.32) + gap_ms
      sds_timer = tick
      renoise.tool():add_timer(tick, wait)
    end)
  end

  renoise.app():show_status(string.format(
    "Paketti SDS: sending %d frames as sample %d over '%s'...", frames, sample_num, device_name))
  sds_timer = tick
  renoise.tool():add_timer(tick, 5)
  return true
end

local sds_dialog = nil

function PakettiTyphoonSDSDialog()
  if sds_dialog and sds_dialog.visible then
    sds_dialog:close() ; sds_dialog = nil ; return
  end
  local song = renoise.song()
  local sample = song.selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Paketti SDS: select a sample with audio first")
    return
  end

  local outs = renoise.Midi.available_output_devices()
  if #outs == 0 then
    renoise.app():show_status("Paketti SDS: no MIDI output ports available")
    return
  end

  local vb = renoise.ViewBuilder()
  local content = vb:column{
    margin = 10, spacing = 6,
    vb:text{text = "Send \"" .. sample.name .. "\" to the sampler over MIDI", font = "bold"},
    vb:text{text = "Typhoon receives waves over MIDI, so this needs no floppy at all.\n"
                .. "On the sampler, be ready to receive before you start."},
    vb:row{ vb:text{text = "MIDI output", width = 90},
      vb:popup{id = "sds_port", items = outs, value = 1, width = 280} },
    vb:row{ vb:text{text = "Device channel", width = 90},
      vb:valuebox{id = "sds_chan", min = 0, max = 127, value = 0, width = 70},
      vb:text{text = "0 is usual; 127 means all devices"} },
    vb:row{ vb:text{text = "Sample number", width = 90},
      vb:valuebox{id = "sds_num", min = 0, max = 16383, value = 1, width = 70},
      vb:text{text = "which slot it lands in on the sampler"} },
    vb:row{ vb:text{text = "Extra gap", width = 90},
      vb:valuebox{id = "sds_gap", min = 0, max = 200, value = 10, width = 70},
      vb:text{text = "ms between messages; raise it if the sampler drops packets"} },
    vb:text{text = "Sent open loop: the sampler's replies are not waited on, which the\n"
                .. "standard permits. A long sample takes minutes at MIDI speed."},
    vb:row{ spacing = 6,
      vb:button{text = "Send", width = 90, notifier = function()
        local port = outs[vb.views.sds_port.value]
        local ch = vb.views.sds_chan.value
        local num = vb.views.sds_num.value
        local gap = vb.views.sds_gap.value
        if sds_dialog and sds_dialog.visible then sds_dialog:close() ; sds_dialog = nil end
        PakettiTyphoonSDSSend(port, ch, num, renoise.song().selected_sample, gap)
      end},
      vb:button{text = "Stop sending", width = 100, notifier = function()
        sds_stop()
        renoise.app():show_status("Paketti SDS: stopped")
      end},
      vb:button{text = "Close", width = 70, notifier = function()
        if sds_dialog and sds_dialog.visible then sds_dialog:close() ; sds_dialog = nil end
      end} },
  }
  sds_dialog = renoise.app():show_custom_dialog("Send Sample over MIDI (SDS)", content, my_keyhandler_func)
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
  -- Default to keeping the layout when the instrument actually has one, so a
  -- GM drum kit exports where you put it rather than being re-laid-out.
  local use_mapping = PakettiTyphoonHasKeyMapping(instrument)

  -- If several samples already sit on General MIDI drum keys, naming them after
  -- those drums is almost certainly wanted.
  local gm_default = false
  do
    local hits = 0
    for _, smp in ipairs(instrument.samples) do
      if PakettiTyphoonGMDrumNames[smp.sample_mapping.note_range[1]] then hits = hits + 1 end
    end
    gm_default = use_mapping and hits >= 3
  end

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

    -- Say plainly which keys the samples will land on, and point out a GM kit
    -- when we see one, since that is the case where the choice matters most.
    local ins = song.selected_instrument
    local gm = 0
    for _, smp in ipairs(ins.samples) do
      if PakettiTyphoonGMDrumNames[smp.sample_mapping.note_range[1]] then gm = gm + 1 end
    end
    if vb.views.tx_mapping.value then
      vb.views.tx_map_label.text = (gm >= 3)
        and string.format("Keep this instrument's key layout - %d sample(s) are on General MIDI drum keys", gm)
        or "Keep this instrument's key layout"
    else
      vb.views.tx_map_label.text = "Lay the samples out one per key from C-3 instead of using their mapping"
    end
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
      vb:text{text = "Filter", width = 110},
      vb:popup{id = "tx_filter", items = PakettiTyphoonFilterTables, value = 1, width = 260},
    },
    vb:row{
      vb:text{text = "Envelope", width = 110},
      vb:popup{id = "tx_env", width = 260, value = 1, items = {
        "Keep the template's envelope",
        "One-shot: let every sample play out (drum kits)",
        "Follow the instrument's own AHDSR",
      }},
    },
    vb:row{
      vb:text{text = "Output", width = 110},
      vb:popup{id = "tx_out", width = 260, value = 1, items = {
        "Keep the template's output", "None", "Left", "Right", "Mono", "Stereo",
      }},
    },
    vb:row{
      vb:text{text = "", width = 110},
      vb:checkbox{id = "tx_mapping", value = use_mapping,
                  notifier = function() refresh() end},
      vb:text{id = "tx_map_label", text = ""},
    },
    vb:row{
      vb:text{text = "", width = 110},
      vb:checkbox{id = "tx_voice_mono", value = false},
      vb:text{text = "Monophonic (one note at a time, for leads and basses)"},
    },
    vb:row{
      vb:text{text = "", width = 110},
      vb:checkbox{id = "tx_gm", value = gm_default},
      vb:text{text = "Name waves after the General MIDI drum on each key (KICK1, SNARE1, HHCLOSED)"},
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
          local envelopes = {nil, "oneshot", "instrument"}
          local opts = {
            rate = rate,
            force_mono = vb.views.tx_mono.value,
            use_mapping = vb.views.tx_mapping.value,
            gm_names = vb.views.tx_gm.value,
            mono_voice = vb.views.tx_voice_mono.value or nil,
            filter_table = (vb.views.tx_filter.value > 1)
              and (vb.views.tx_filter.value - 1) or nil,
            output = (vb.views.tx_out.value > 1)
              and (vb.views.tx_out.value - 2) or nil,
            envelope = envelopes[vb.views.tx_env.value],
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
-- Modulation matrix editor
--------------------------------------------------------------------------------

local typhoon_mod_dialog = nil

function PakettiTyphoonModMatrixDialog()
  if typhoon_mod_dialog and typhoon_mod_dialog.visible then
    typhoon_mod_dialog:close()
    typhoon_mod_dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local mods = PakettiTyphoonModMatrix()
  while #mods < PAKETTI_TYPHOON_MOD_ENTRIES do
    mods[#mods + 1] = string.char(0, 0, 0, 15, 0, 0)
  end

  local rows = vb:column{spacing = 2}
  rows:add_child(vb:row{
    vb:text{text = "#", width = 20, font = "bold"},
    vb:text{text = "Source", width = 170, font = "bold"},
    vb:text{text = "Destination", width = 140, font = "bold"},
    vb:text{text = "Amount", width = 120, font = "bold"},
    vb:text{text = "Hold", width = 40, font = "bold"},
  })

  for i = 1, PAKETTI_TYPHOON_MOD_ENTRIES do
    local m = mods[i]
    rows:add_child(vb:row{
      vb:text{text = tostring(i), width = 20},
      vb:popup{id = "mod_src_" .. i, items = PakettiTyphoonModSources,
               value = m:byte(1) + 1, width = 170},
      vb:popup{id = "mod_dst_" .. i, items = PakettiTyphoonModDestinations,
               value = m:byte(2) + 1, width = 140},
      vb:valuebox{id = "mod_a_" .. i, min = 0, max = 255, value = m:byte(5), width = 58},
      vb:valuebox{id = "mod_b_" .. i, min = 0, max = 255, value = m:byte(6), width = 58},
      vb:checkbox{id = "mod_f_" .. i, value = m:byte(3) == 1},
    })
  end

  local content = vb:column{
    margin = 10, spacing = 6,
    vb:text{text = "TX16W modulation table - written into every exported voice",
            font = "bold"},
    vb:text{text = "The two Amount boxes are semitones and cents when the destination is Pitch, "
                .. "and a coarse/fine pair otherwise. Hold freezes the source's value at key down."},
    vb:space{height = 4},
    rows,
    vb:space{height = 6},
    vb:text{text = "External controller 1 and 2 are the machine's only free MIDI CC slots, and "
                .. "which CC each one listens to is set on the sampler itself, under "
                .. "System Setup > X-Cntls - not per voice. So \"CC74 to cutoff\" means pointing "
                .. "XCtl1 at CC 74 there once, then routing External controller 1 to Filter here."},
    vb:text{text = "A group has only one modulatable filter axis, chosen on the sampler as "
                .. "D-Axis. Cutoff and resonance cannot both be modulated on the same group."},
    vb:space{height = 6},
    vb:row{
      spacing = 6,
      vb:button{text = "Save", width = 90, notifier = function()
        local out = {}
        for i = 1, PAKETTI_TYPHOON_MOD_ENTRIES do
          out[#out + 1] = string.format("%d:%d:%d:%d:%d",
            vb.views["mod_src_" .. i].value - 1,
            vb.views["mod_dst_" .. i].value - 1,
            vb.views["mod_f_" .. i].value and 1 or 0,
            vb.views["mod_a_" .. i].value,
            vb.views["mod_b_" .. i].value)
        end
        preferences.pakettiTX16WModMatrix.value = table.concat(out, ",")
        preferences:save_as("preferences.xml")
        renoise.app():show_status("Paketti TX16W: modulation table saved - it goes into every exported voice")
      end},
      vb:button{text = "Restore factory routing", width = 170, notifier = function()
        preferences.pakettiTX16WModMatrix.value =
          PakettiTyphoonFormatModMatrix(PakettiTyphoonDefaultMods)
        preferences:save_as("preferences.xml")
        if typhoon_mod_dialog and typhoon_mod_dialog.visible then
          typhoon_mod_dialog:close() ; typhoon_mod_dialog = nil
        end
        PakettiTyphoonModMatrixDialog()
      end},
      vb:button{text = "Close", width = 80, notifier = function()
        if typhoon_mod_dialog and typhoon_mod_dialog.visible then
          typhoon_mod_dialog:close() ; typhoon_mod_dialog = nil
        end
      end},
    },
  }

  typhoon_mod_dialog = renoise.app():show_custom_dialog(
    "TX16W Modulation Table", content, my_keyhandler_func)
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

-- The stock Yamaha OS wave format, .W## -- what a TX16W disk holds before
-- anyone installs Typhoon. Decoded 2026-08-31 from 220 files across ten
-- Yamaha-format library disks; see docs/TYPHOON-FORMATS.md for the evidence.
--
--    0..5    "LM8953"        the same magic the filter tables carry
--    6..15   zero
--   16..21   not identified
--   22       0x49 = looped, 0xC9 = not looped
--   23       documented elsewhere as the rate index, but on real factory disks
--            it holds 79 different values and only 27% are in the documented
--            1/2/3 range. It is not the rate. See below.
--   24..26   attack length, 17-bit little endian, bit 16 in byte 26 bit 0
--   27..29   loop length, same encoding -- but only BIT 0 of byte 29 belongs
--            to the length. Bits 1-7 are the SAMPLE RATE index.
--   30..31   not identified
--   32..     audio: 12-bit signed, two samples per three bytes
--              sample 1 = (b0 << 4) | (b1 & 0x0F)
--              sample 2 = (b2 << 4) | (b1 >> 4)
--
-- Total length is attack + loop, and the loop begins where the attack ends.
-- The format encodes the machine's own rule directly: a loop always runs to
-- the end of the wave, so a wave is an attack followed by a repeating tail.
PAKETTI_YAMAHA_WAVE_MAGIC = "LM8953"

-- Sample rate lives in the top 7 bits of byte 29, and these are the values it
-- actually takes. Established by pairing ten Yamaha-format library disks with
-- Typhoon conversions of the same libraries, where the rate is stated outright
-- in the AIFF header: across 219 waves the mapping is one-to-one with no
-- exceptions. The frame counts agreed 219 out of 219 too, which is what makes
-- the pairing trustworthy.
--
-- 33310 rather than 33333 is not a typo: it is what the machine actually ran
-- at, and what its own conversions record.
PAKETTI_YAMAHA_WAVE_RATES = {
  [40] = 33310, [41] = 33333, [73] = 44175, [127] = 49966,
}

function PakettiTyphoonParseYamahaWave(data)
  if #data < 48 or data:sub(1, 6) ~= PAKETTI_YAMAHA_WAVE_MAGIC then
    error("not a Yamaha TX16W wave (no LM8953 header)")
  end
  local function b(i) return data:byte(i + 1) or 0 end
  local function len17(o)
    return b(o) + b(o + 1) * 256 + (b(o + 2) % 2) * 65536
  end

  local attack = len17(24)
  local loop = len17(27)
  local frames = attack + loop
  if frames < 1 then error("wave header reports no audio") end
  -- Guard against a corrupt header claiming more than the file holds.
  local avail = floor((#data - 32) / 3) * 2
  if frames > avail then frames = avail end

  local ints, p = {}, 33
  for i = 1, frames, 2 do
    local b0, b1, b2 = data:byte(p), data:byte(p + 1), data:byte(p + 2)
    if not b2 then break end
    p = p + 3
    local s1 = b0 * 16 + (b1 % 16)
    local s2 = b2 * 16 + floor(b1 / 16)
    if s1 >= 2048 then s1 = s1 - 4096 end
    if s2 >= 2048 then s2 = s2 - 4096 end
    ints[i] = s1
    if i + 1 <= frames then ints[i + 1] = s2 end
  end

  return {
    nsamples = frames,
    nchannels = 1,
    wordsize = 12,
    rate = PAKETTI_YAMAHA_WAVE_RATES[floor(b(29) / 2)] or 33310,
    channels = { ints },
    attack = attack,
    loop_length = loop,
    looped = (b(22) == 0x49),
    -- The attack/loop split exists whether or not the wave loops, so the points
    -- are always reported and only the mode follows the flag. That keeps the
    -- loop switchable in Renoise on a sample the sampler marked non-looping --
    -- Typhoon's own conversions loop these anyway, at exactly this boundary.
    loop_start = (loop > 0) and (attack + 1) or nil,
    loop_end = (loop > 0) and frames or nil,
    loop_mode = (b(22) == 0x49 and loop > 0) and 1 or 0,
  }
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

-- Parses a .P01 performance. Returns
--   { stamp, id, entries = { { channel, transpose, volume, name, id, disk } },
--     programs = { { program, name, id, disk } } }
-- channel is nil when the entry answers any channel (stored as 0xFF).
function PakettiTyphoonParsePerformance(data)
  local perf = { entries = {}, programs = {} }

  local function ref(body)
    if #body < 12 then return nil end
    return {
      name = body:sub(1, 8):gsub("[%z%s]+$", ""),
      id = body:sub(9, 12),
      disk = (#body >= 20) and body:sub(13, 20):gsub("[%z%s\255]+$", "") or nil,
    }
  end

  -- Entr and PChg bodies are bare chunk streams, like Grop.
  local function inner(body)
    local out, p = {}, 1
    while p + 8 <= #body do
      local cid = body:sub(p, p + 3)
      local sz = 0
      for i = p + 4, p + 7 do sz = sz * 256 + body:byte(i) end
      if sz < 0 or p + 8 + sz - 1 > #body then break end
      out[cid] = body:sub(p + 8, p + 8 + sz - 1)
      p = p + 8 + sz + (sz % 2)
    end
    return out
  end

  local ok = iff_walk(data, "TYPP", function(id, body)
    if id == "VInf" and #body >= 16 then
      perf.stamp, perf.id = body:sub(1, 12), body:sub(13, 16)
    elseif id == "Entr" then
      local c = inner(body)
      local v = c["Voic"] and ref(c["Voic"])
      if v then
        local parm = c["Parm"] or ""
        local ch = parm:byte(1)
        v.channel = (ch and ch < 16) and ch or nil
        v.transpose = parm:byte(2) or 0
        if v.transpose > 127 then v.transpose = v.transpose - 256 end
        v.volume = (#parm >= 4) and (parm:byte(3) * 256 + parm:byte(4)) or 96
        perf.entries[#perf.entries + 1] = v
      end
    elseif id == "PChg" then
      local c = inner(body)
      local v = c["Voic"] and ref(c["Voic"])
      if v then
        v.program = (c["Parm"] and c["Parm"]:byte(1)) or 0
        perf.programs[#perf.programs + 1] = v
      end
    end
  end)
  if not ok then error("not a Typhoon performance file (no FORM/TYPP header)") end
  return perf
end

-- Parses a .X01 setup: a flat list of everything the machine had in memory.
function PakettiTyphoonParseSetup(data)
  local setup = { perfs = {}, voices = {}, waves = {} }
  local function ref(body)
    if #body < 12 then return nil end
    return {
      name = body:sub(1, 8):gsub("[%z%s]+$", ""),
      id = body:sub(9, 12),
      disk = (#body >= 20) and body:sub(13, 20):gsub("[%z%s\255]+$", "") or nil,
    }
  end
  local ok = iff_walk(data, "TYPS", function(id, body)
    if id == "VInf" and #body >= 16 then
      setup.stamp, setup.id = body:sub(1, 12), body:sub(13, 16)
    elseif id == "Parm" then
      -- The setup's own name sits inside the globals block.
      setup.name = body:sub(18, 25):gsub("[%z%s]+$", "")
    elseif id == "Perf" then
      local r = ref(body) ; if r then setup.perfs[#setup.perfs + 1] = r end
    elseif id == "Voic" then
      local r = ref(body) ; if r then setup.voices[#setup.voices + 1] = r end
    elseif id == "Wave" then
      local r = ref(body) ; if r then setup.waves[#setup.waves + 1] = r end
    end
  end)
  if not ok then error("not a Typhoon setup file (no FORM/TYPS header)") end
  return setup
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
-- The stock Yamaha OS wave, which a pre-Typhoon library disk is full of.
local function is_yamaha_wave_name(name)
  return name:upper():match("%.W%d%d$") ~= nil
end
local function is_voice_name(name)
  return name:upper():match("%.O%d%d$") ~= nil
end
local function is_aiff_name(name)
  return name:upper():match("%.A%d%d$") ~= nil
end
local function is_perf_name(name)
  return name:upper():match("%.P%d%d$") ~= nil
end
local function is_setup_name(name)
  return name:upper():match("%.X%d%d$") ~= nil
end

-- Item names may contain spaces ("808 BD 1"); DOS filenames may not, so the
-- same item is "ANA STRS" inside a performance and "ANA_STRS.O01" on the disk.
-- Match on a form where the two cannot differ.
local function name_key(n)
  return (tostring(n or ""):upper():gsub("[%s_]+", "_"):gsub("^_+", ""):gsub("_+$", ""))
end

-- Decodes every wave in the file list once, keyed both by Typhoon wave id and
-- by uppercased base name, because a voice's Splt reference resolves by id when
-- the wave carries Typhoon's APPL stamp and by name when it does not.
local function decode_waves(files, progress)
  local by_id, by_name, order, failed = {}, {}, {}, {}
  for _, f in ipairs(files) do
    if is_wave_name(f.name) or is_yamaha_wave_name(f.name) then
      if progress then progress("Decoding " .. f.name .. "...") end
      coroutine.yield()
      local parser = is_yamaha_wave_name(f.name)
        and PakettiTyphoonParseYamahaWave or PakettiDWVWParseFile
      local ok, info = pcall(parser, f.data, 4096)
      if ok then
        local entry = { name = strip_ext(f.name), info = info, file = f.name }
        order[#order + 1] = entry
        by_name[name_key(strip_ext(f.name))] = entry
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
        and ((sp.id and by_id[sp.id]) or by_name[name_key(sp.name)])
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
        if dir and (is_voice_name(src) or is_perf_name(src) or is_setup_name(src)) then
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

    -- Performances and setups carry the arrangement: which voice sits on which
    -- MIDI channel, and what the machine had loaded. They reference voices by
    -- name and id rather than containing them, so they are read for the layout
    -- and reported, and the voices themselves still become the instruments.
    local perfs, setups = {}, {}
    for _, f in ipairs(files) do
      if is_perf_name(f.name) then
        local pok, pf = pcall(PakettiTyphoonParsePerformance, f.data)
        if pok then perfs[#perfs + 1] = { name = strip_ext(f.name), perf = pf }
        else failed[#failed + 1] = f.name .. " (" .. tostring(pf) .. ")" end
      elseif is_setup_name(f.name) then
        local sok, st = pcall(PakettiTyphoonParseSetup, f.data)
        if sok then setups[#setups + 1] = { name = strip_ext(f.name), setup = st }
        else failed[#failed + 1] = f.name .. " (" .. tostring(st) .. ")" end
      end
    end

    -- A voice's MIDI channel, taken from the first performance that places it.
    local channel_of = {}
    for _, pw in ipairs(perfs) do
      for _, e in ipairs(pw.perf.entries) do
        local key = name_key(e.name)
        if e.channel and not channel_of[key] then channel_of[key] = e.channel end
      end
    end

    local made, used, total_placed, all_missing = 0, {}, 0, {}
    for _, v in ipairs(voices) do
      progress("Building " .. v.name .. "...")
      coroutine.yield()
      -- Carry the MIDI channel into the instrument name when a performance
      -- said where this voice belongs, so the arrangement is visible in Renoise.
      local ch = channel_of[name_key(v.name)]
      local label = ch and string.format("%s (MIDI %d)", v.name, ch + 1) or v.name
      local _, placed, missing = build_instrument_from_voice(
        v.voice, label, by_id, by_name, progress)
      made = made + 1
      total_placed = total_placed + placed
      for _, m in ipairs(missing) do all_missing[#all_missing + 1] = m end
      for _, g in ipairs(v.voice.groups) do
        for _, sp in ipairs(g.splits) do
          if not sp.terminator then
            local e = (sp.id and by_id[sp.id]) or by_name[name_key(sp.name)]
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

    -- Print the arrangement, which is the whole reason to read a performance.
    for _, pw in ipairs(perfs) do
      print(string.format("PakettiTyphoon: performance %s - %d entries, %d program changes",
        pw.name, #pw.perf.entries, #pw.perf.programs))
      for _, e in ipairs(pw.perf.entries) do
        print(string.format("    MIDI %-3s %-9s volume %d%s",
          e.channel and tostring(e.channel + 1) or "any", e.name or "?", e.volume or 96,
          (e.transpose ~= 0) and string.format(", transpose %+d", e.transpose) or ""))
      end
      for _, pc in ipairs(pw.perf.programs) do
        print(string.format("    program %-3d -> %s", pc.program, pc.name or "?"))
      end
    end
    for _, sw in ipairs(setups) do
      print(string.format("PakettiTyphoon: setup %s - %d performance(s), %d voice(s), %d wave(s)",
        sw.name, #sw.setup.perfs, #sw.setup.voices, #sw.setup.waves))
    end

    local msg = string.format(
      "Paketti TX16W: %d instrument(s) from %d wave(s)%s%s%s",
      made, #order,
      (#voices > 0) and string.format(", %d voice(s), %d key zone(s)", #voices, total_placed) or "",
      (#perfs > 0) and string.format(", %d performance(s) - MIDI channels are in the instrument names, full layout in the console", #perfs) or "",
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
  local pats = {}
  for _, letter in ipairs({"O", "P", "X", "W"}) do
    for d = 0, 9 do pats[#pats + 1] = string.format("*.%s%d*", letter, d) end
  end
  local names = os.filenames(dir, pats)
  local sources = {}
  for _, n in ipairs(names) do sources[#sources + 1] = dir .. sep .. n end
  if #sources == 0 then
    -- No voices: fall back to every wave in the folder.
    local wpats = {}
    for _, letter in ipairs({"C", "W"}) do
      for d = 0, 9 do wpats[#wpats + 1] = string.format("*.%s%d*", letter, d) end
    end
    for _, n in ipairs(os.filenames(dir, wpats)) do
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

PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDialog() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDialog() end}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Save:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDialog() end}
PakettiAddMenuEntry{name = "Sample Mappings:Paketti:Save:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDialog() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Save:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDialog() end}
PakettiAddMenuEntry{name = "Disk Browser:Paketti:Export Instrument to Yamaha TX16W (.C01+.O01+720K disks)...", invoke = function() PakettiTyphoonExportDialog() end}

renoise.tool():add_keybinding{name = "Global:Paketti:Export Instrument to Yamaha TX16W", invoke = function() PakettiTyphoonExportDialog() end}
renoise.tool():add_midi_mapping{name = "Paketti:Export Instrument to Yamaha TX16W", invoke = function(message) if message:is_trigger() then PakettiTyphoonExportDialog() end end}

-- The no-dialog variant, for when the settings are already right.
PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Instrument to Yamaha TX16W with Saved Settings...", invoke = function() PakettiTyphoonExportDrumkit() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:Export Instrument to Yamaha TX16W with Saved Settings...", invoke = function() PakettiTyphoonExportDrumkit() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Export Instrument to Yamaha TX16W with Saved Settings", invoke = function() PakettiTyphoonExportDrumkit() end}

PakettiAddMenuEntry{name = "Main Menu:File:Paketti Import:TX16W Modulation Table...", invoke = function() PakettiTyphoonModMatrixDialog() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:TX16W Modulation Table...", invoke = function() PakettiTyphoonModMatrixDialog() end}
renoise.tool():add_keybinding{name = "Global:Paketti:TX16W Modulation Table", invoke = function() PakettiTyphoonModMatrixDialog() end}

PakettiAddMenuEntry{name = "Main Menu:File:Paketti Export:Export Song to Yamaha TX16W (setup + performance + voices)...", invoke = function() PakettiTyphoonExportSong() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:Export Song to Yamaha TX16W (setup + performance + voices)...", invoke = function() PakettiTyphoonExportSong() end}
PakettiAddMenuEntry{name = "Disk Browser:Paketti:Export Song to Yamaha TX16W (setup + performance + voices)...", invoke = function() PakettiTyphoonExportSong() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Export Song to Yamaha TX16W", invoke = function() PakettiTyphoonExportSong() end}

PakettiAddMenuEntry{name = "Main Menu:File:Paketti Import:Create TX16W Filter Table (.T18)...", invoke = function() PakettiTyphoonExportFilterTable() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:Create TX16W Filter Table (.T18)...", invoke = function() PakettiTyphoonExportFilterTable() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Create TX16W Filter Table", invoke = function() PakettiTyphoonExportFilterTable() end}

PakettiAddMenuEntry{name = "Main Menu:File:Paketti Import:Send Sample to Sampler over MIDI (SDS)...", invoke = function() PakettiTyphoonSDSDialog() end}
PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:Send Sample to Sampler over MIDI (SDS)...", invoke = function() PakettiTyphoonSDSDialog() end}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Save:Send Sample to Sampler over MIDI (SDS)...", invoke = function() PakettiTyphoonSDSDialog() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Send Sample over MIDI SDS", invoke = function() PakettiTyphoonSDSDialog() end}
renoise.tool():add_midi_mapping{name = "Paketti:Send Sample over MIDI SDS", invoke = function(message) if message:is_trigger() then PakettiTyphoonSDSDialog() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Export Song to Yamaha TX16W", invoke = function(message) if message:is_trigger() then PakettiTyphoonExportSong() end end}


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
  for _, letter in ipairs({"o", "O", "p", "P", "x", "X", "w", "W"}) do
    typhoon_extensions[#typhoon_extensions + 1] = letter .. nn
  end
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
