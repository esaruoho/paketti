--[[============================================================================
PakettiMODParser.lua — ProTracker / Soundtracker .MOD file format parser

Pure-Lua binary parser for .mod files. No Renoise API dependencies at load time
or inside any parse function, so it can be unit-tested with a plain Lua
interpreter (same arrangement as PakettiEXS24Parser.lua / PakettiEXS24Loader.lua).

Consumers:
  PakettiMODLoader.lua   — "Load Samples from .MOD" and the batch .MOD -> .WAV
                           converter.

Layout of a 31-sample module (all offsets 1-based, as Lua strings are):

  1   .. 20    song title (20 bytes, NUL padded)
  21  .. 950   31 sample headers, 30 bytes each:
                 +0  .. +21  name (22 bytes)
                 +22 .. +23  length in WORDS, big-endian (x2 = bytes)
                 +24         finetune (low nibble, signed 4-bit: 8..15 = -8..-1)
                 +25         volume 0..64
                 +26 .. +27  loop start in WORDS, big-endian
                 +28 .. +29  loop length in WORDS, big-endian
  951          song length (number of used order entries, 1..128)
  952          restart position / 127
  953 .. 1080  order table (128 bytes)
  1081 .. 1084 format tag ("M.K.", "8CHN", "6CHN", ...)
  1085 ..      pattern data (num_patterns * 64 * channels * 4 bytes)
  then         sample PCM, signed 8-bit, in sample order

15-sample (original Soundtracker) modules have no format tag and a shorter
header: song length sits at 471, the order table at 473..600, and pattern data
begins at 601.
============================================================================]]--

PakettiMODParser = {}

--------------------------------------------------------------------------------
-- byte helpers
--------------------------------------------------------------------------------

-- Big-endian unsigned 16-bit read. Returns 0 past the end of the string rather
-- than erroring, so a truncated file degrades instead of crashing (skill rule 21).
function PakettiMODParser.read_be_u16(str, pos)
  local b1, b2 = str:byte(pos, pos + 1)
  if not b1 or not b2 then return 0 end
  return b1 * 256 + b2
end

-- Truncates at the first NUL. Plain string.find so this works on both Lua 5.1
-- (Renoise) and newer interpreters used for offline testing, where the %z
-- pattern class no longer exists.
function PakettiMODParser.cstring(s)
  if type(s) ~= "string" then return "" end
  local nul = s:find("\0", 1, true)
  if nul then s = s:sub(1, nul - 1) end
  return s
end

function PakettiMODParser.le_u16(n)
  n = math.floor(n)
  return string.char(n % 256, math.floor(n / 256) % 256)
end

function PakettiMODParser.le_u32(n)
  n = math.floor(n)
  return string.char(
    n % 256,
    math.floor(n / 256) % 256,
    math.floor(n / 65536) % 256,
    math.floor(n / 16777216) % 256)
end

-- 256-entry lookup so the signed->unsigned conversion is a table gsub rather
-- than a Lua function call per byte (matters when converting thousands of
-- samples in a batch run).
local SIGN_FLIP = {}
for i = 0, 255 do
  SIGN_FLIP[string.char(i)] = string.char((i + 128) % 256)
end

-- .MOD PCM is signed 8-bit; RIFF/WAVE 8-bit PCM is unsigned. Convert.
function PakettiMODParser.sign_flip(raw)
  if not raw or raw == "" then return "" end
  return (raw:gsub(".", SIGN_FLIP))
end

--------------------------------------------------------------------------------
-- format tag -> channel count
--------------------------------------------------------------------------------

-- Table keys carrying dots/punctuation are always bracket-quoted (skill rule 19).
local TAG_CHANNELS = {
  ["M.K."] = 4, ["M!K!"] = 4, ["M&K!"] = 4, ["N.T."] = 4, ["FLT4"] = 4,
  ["LARD"] = 4, ["PATT"] = 4, ["EXO4"] = 4,
  ["FLT8"] = 8, ["EXO8"] = 8, ["CD81"] = 8, ["OKTA"] = 8, ["OCTA"] = 8,
}

--- Returns the channel count for a 4-character format tag, or nil when the tag
--- is not a known 31-sample signature (which means a 15-sample module).
function PakettiMODParser.channels_for_tag(tag)
  if not tag or #tag < 4 then return nil end

  local direct = TAG_CHANNELS[tag]
  if direct then return direct end

  -- "4CHN".."9CHN" and the TDZ1..TDZ3 variants
  local d = tag:match("^(%d)CHN$") or tag:match("^TDZ(%d)$")
  if d then
    local n = tonumber(d)
    if n and n >= 1 and n <= 9 then return n end
  end

  -- "10CH".."32CH", also the "..CN" spelling used by some trackers
  local dd = tag:match("^(%d%d)CH$") or tag:match("^(%d%d)CN$")
  if dd then
    local n = tonumber(dd)
    if n and n >= 10 and n <= 32 then return n end
  end

  -- StarTrekker "FA04"/"FA06"/"FA08"
  local fa = tag:match("^FA(%d%d)$")
  if fa then
    local n = tonumber(fa)
    if n and n >= 1 and n <= 32 then return n end
  end

  return nil
end

--------------------------------------------------------------------------------
-- finetune
--------------------------------------------------------------------------------

--- ProTracker finetune is a signed 4-bit value in 1/8th-semitone steps.
--- Returns the playback rate for a given base rate (8363 Hz = Amiga PAL C-3).
function PakettiMODParser.finetune_rate(base_rate, finetune)
  finetune = finetune or 0
  if finetune > 7 then finetune = finetune - 16 end
  if finetune == 0 then return base_rate end
  return math.floor(base_rate * 2 ^ (finetune / 96) + 0.5)
end

--------------------------------------------------------------------------------
-- parse
--------------------------------------------------------------------------------

--- Parses a whole .MOD file held in a string.
--- Returns a table on success, or nil plus an error message.
---
--- Result shape:
---   {
---     title        = string,     -- module title from the header
---     format       = string,     -- "M.K." etc, or "15-sample"
---     channels     = number,
---     song_length  = number,
---     num_patterns = number,
---     truncated    = boolean,    -- true when PCM ran past the end of file
---     samples      = {           -- only samples with length > 0 appear here
---       { index, name, length, loop_start, loop_length, finetune, volume,
---         data }                 -- data = raw SIGNED 8-bit PCM
---     }
---   }
function PakettiMODParser.parse(data)
  if type(data) ~= "string" then return nil, "no data" end
  if #data < 1084 then return nil, "file too small to be a .MOD" end

  local read_be_u16 = PakettiMODParser.read_be_u16

  local tag = data:sub(1081, 1084)
  local channels = PakettiMODParser.channels_for_tag(tag)

  local num_sample_slots, format_name, pattern_start
  if channels then
    num_sample_slots = 31
    format_name = tag
    pattern_start = 1085                      -- after the 4-byte tag
  else
    num_sample_slots = 15
    format_name = "15-sample"
    channels = 4
    pattern_start = 601                       -- no tag in old Soundtracker
  end

  local header_end = 20 + num_sample_slots * 30   -- last byte of sample headers
  local song_length_pos = header_end + 1
  local order_pos = header_end + 3

  -- sample headers
  local sample_infos = {}
  local total_pcm = 0
  local off = 21
  for i = 1, num_sample_slots do
    local raw_name = data:sub(off, off + 21)
    local name = PakettiMODParser.cstring(raw_name)
    local length     = read_be_u16(data, off + 22) * 2
    local finetune   = (data:byte(off + 24) or 0) % 16
    local volume     = data:byte(off + 25) or 64
    local loop_start = read_be_u16(data, off + 26) * 2
    local loop_len   = read_be_u16(data, off + 28) * 2

    sample_infos[i] = {
      index       = i,
      name        = name,
      length      = length,
      finetune    = finetune,
      volume      = volume,
      loop_start  = loop_start,
      loop_length = loop_len,
    }
    total_pcm = total_pcm + length
    off = off + 30
  end

  local song_length = data:byte(song_length_pos) or 0

  -- Pattern count. Modules disagree on whether unused order slots count: some
  -- store patterns past song_length that still occupy file space, others leave
  -- junk in the unused slots. Compute both candidates and pick whichever makes
  -- the file's actual size add up.
  local max_all, max_used = 0, 0
  for i = 0, 127 do
    local v = data:byte(order_pos + i) or 0
    if v < 128 then
      if v > max_all then max_all = v end
      if i < song_length and v > max_used then max_used = v end
    end
  end

  local pattern_bytes_per_pattern = 64 * channels * 4
  local function needed_for(count)
    return (pattern_start - 1) + count * pattern_bytes_per_pattern + total_pcm
  end

  local num_patterns = max_all + 1
  if needed_for(num_patterns) > #data then
    local fallback = max_used + 1
    if fallback < num_patterns and needed_for(fallback) <= #data then
      num_patterns = fallback
    end
  end

  -- carve out the PCM
  local sample_data_off = pattern_start + num_patterns * pattern_bytes_per_pattern
  local truncated = false
  local samples = {}
  for i = 1, num_sample_slots do
    local info = sample_infos[i]
    if info.length > 0 then
      local s0 = sample_data_off
      local s1 = s0 + info.length - 1
      if s0 > #data then
        truncated = true
        info.data = ""
        info.length = 0
      else
        if s1 > #data then
          truncated = true
          s1 = #data
        end
        info.data = data:sub(s0, s1)
        info.length = #info.data
      end
      sample_data_off = s1 + 1
      if info.length > 0 then table.insert(samples, info) end
    end
  end

  return {
    title        = PakettiMODParser.cstring(data:sub(1, 20)),
    format       = format_name,
    channels     = channels,
    song_length  = song_length,
    num_patterns = num_patterns,
    truncated    = truncated,
    samples      = samples,
  }
end

--------------------------------------------------------------------------------
-- WAV writing
--------------------------------------------------------------------------------

--- Builds a canonical 8-bit mono RIFF/WAVE file from UNSIGNED PCM.
--- Run raw .MOD PCM through PakettiMODParser.sign_flip() first.
function PakettiMODParser.build_wav(pcm_unsigned, sample_rate)
  local le_u16, le_u32 = PakettiMODParser.le_u16, PakettiMODParser.le_u32
  local sr   = math.floor(sample_rate or 8363)
  local nch  = 1
  local bits = 8

  local byte_rate   = sr * nch * (bits / 8)
  local block_align = nch * (bits / 8)
  local data_sz     = #pcm_unsigned
  local fmt_sz      = 16
  local riff_sz     = 4 + (8 + fmt_sz) + (8 + data_sz)

  return table.concat{
    "RIFF", le_u32(riff_sz), "WAVE",
    "fmt ", le_u32(fmt_sz),
    le_u16(1),              -- PCM
    le_u16(nch),
    le_u32(sr),
    le_u32(byte_rate),
    le_u16(block_align),
    le_u16(bits),
    "data", le_u32(data_sz),
    pcm_unsigned,
  }
end

--- Reads a whole file as a binary string. Returns nil plus a message on failure.
function PakettiMODParser.read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil, "could not open " .. tostring(path) end
  local data = f:read("*all")
  f:close()
  if not data or data == "" then return nil, "empty file: " .. tostring(path) end
  return data
end

--- Writes a binary string to a file. Returns true, or false plus a message.
function PakettiMODParser.write_file(path, contents)
  local f = io.open(path, "wb")
  if not f then return false, "could not write " .. tostring(path) end
  f:write(contents)
  f:close()
  return true
end
