--[[============================================================================
PakettiEXS24Parser.lua — Logic EXS24 sampler instrument file format parser

Pure-Lua binary parser for .exs files. No Renoise API dependencies; safe to
unit-test in plain Lua. Handles big- and little-endian variants of the format
(autodetected from the magic at offset 16: "TBOS"/"JBOS" little, "SOBT"/"SOBJ"
big). Parses Header, Instrument, Zone, and Sample chunks. Group chunks (type
2), Params (type 4), and binary plist (type 0xB) are recognised but skipped —
see PakettiEXS24Loader.lua header for the consequences.

Derived from matt-allan/renoise-exs24's exs.lua and bytes.lua (MIT, 2018) —
merged and adapted for Paketti (GPLv3). The MIT attribution below satisfies
the MIT requirement to retain copyright in substantial portions.

  MIT License — Copyright (c) 2018 Matt Allan and all contributors.
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction. The above copyright notice and this
  permission notice shall be included in all copies or substantial portions of
  the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
============================================================================]]--

pakettiEXS24Parser = {}

pakettiEXS24Parser.PLAY_MODE_FORWARD = 0
pakettiEXS24Parser.PLAY_MODE_REVERSE = 1
pakettiEXS24Parser.PLAY_MODE_ALTERNATE = 2

local HEADER_SIZE = 84

-- ---------------------------------------------------------------------------
-- Byte buffer (vendored from bytes.lua so this file has zero internal deps)
-- ---------------------------------------------------------------------------

local function tosigned(x, n)
  n = n or 8
  if bit.band(x, bit.lshift(1, (n - 1))) ~= 0 then
    return x - bit.lshift(1, n)
  end
  return x
end

local function low_byte(x) return bit.band(x, 0xF) end

local le = {}
function le.u16(buf)
  local b1, b2 = string.byte(buf, 1, 2)
  return bit.bor(b1, bit.lshift(b2, 8))
end
function le.u32(buf)
  local b1, b2, b3, b4 = string.byte(buf, 1, 4)
  return bit.bor(b1, bit.lshift(b2, 8), bit.lshift(b3, 16), bit.lshift(b4, 24))
end
function le.i16(buf) return tosigned(le.u16(buf), 16) end
function le.i32(buf) return tosigned(le.u32(buf), 32) end

local be = {}
function be.u16(buf) return bit.bswap(le.u16(buf)) end
function be.u32(buf) return bit.bswap(le.u32(buf)) end
function be.i16(buf) return tosigned(le.i16(buf), 16) end
function be.i32(buf) return tosigned(le.i32(buf), 32) end

local Buffer = {}
Buffer.__index = Buffer

local function buffer_new(buf)
  local b = { buf = buf or "", pos = 1, size = #buf, e = le }
  setmetatable(b, Buffer)
  return b
end

function Buffer:seek(whence, offset)
  whence = whence or "cur"; offset = offset or 0
  if whence == "cur" then self.pos = self.pos + offset
  elseif whence == "set" then self.pos = offset + 1
  elseif whence == "end" then self.pos = self.size
  else error("bad seek whence") end
  assert(self.pos >= 1)
  return self.pos - 1
end

function Buffer:read_byte()
  if self.pos > self.size then error("end of buffer") end
  local b = string.byte(self.buf, self.pos)
  self.pos = self.pos + 1
  return b
end

function Buffer:peek(whence, offset)
  whence = whence or "cur"; offset = offset or 0
  local pos = 1
  if whence == "cur" then pos = self.pos + offset
  elseif whence == "set" then pos = offset + 1
  elseif whence == "end" then pos = self.size
  else error("bad peek whence") end
  return string.byte(self.buf, pos)
end

function Buffer:read(n)
  if self.pos > self.size then error("end of buffer") end
  local b = string.sub(self.buf, self.pos, self.pos + (n - 1))
  self.pos = self.pos + #b
  return b
end

function Buffer:skip(n)
  self.pos = self.pos + (n or 1)
  return self.pos
end

function Buffer:remaining() return self.size - (self.pos - 1) end

function Buffer:endian(byte_order)
  if byte_order == "<" then self.e = le
  elseif byte_order == ">" then self.e = be
  else error("unknown byte order") end
end

function Buffer:u8() return self:read_byte() end
function Buffer:i8() return tosigned(self:read_byte(), 8) end
function Buffer:u16() return self.e.u16(self:read(2)) end
function Buffer:i16() return self.e.i16(self:read(2)) end
function Buffer:u32() return self.e.u32(self:read(4)) end
function Buffer:i32() return self.e.i32(self:read(4)) end

function Buffer:cstr(n)
  local s = self:read(n)
  local i = s:find("\00", 1, true)
  if i then return s:sub(1, i - 1) else return s end
end

-- ---------------------------------------------------------------------------
-- EXS24 chunk type definitions (LuaCATS — preserved from upstream)
-- ---------------------------------------------------------------------------

---@alias PlayMode
---| 0 # forward
---| 1 # reverse
---| 2 # alternate

---@class EXS24Header
---@field kind "header"
---@field offset integer
---@field signature string
---@field marker integer
---@field size integer
---@field index integer
---@field chunk_id string
---@field name string

---@class EXS24Instrument
---@field kind "instrument"
---@field offset integer
---@field header EXS24Header
---@field num_zones integer
---@field num_groups integer
---@field num_samples integer

---@class EXS24ZoneFlags
---@field oneshot boolean
---@field pitch boolean
---@field reverse boolean
---@field has_velocity_range boolean
---@field has_output boolean

---@class EXS24LoopFlags
---@field loop_on boolean
---@field equal_power boolean
---@field end_release boolean

---@class EXS24Zone
---@field kind "zone"
---@field offset integer
---@field header EXS24Header
---@field zone_flags EXS24ZoneFlags
---@field key integer
---@field fine_tuning integer
---@field pan integer
---@field volume integer
---@field key_low integer
---@field key_high integer
---@field velocity_low integer
---@field velocity_high integer
---@field sample_start integer
---@field sample_end integer
---@field loop_start integer
---@field loop_end integer
---@field loop_crossfade integer
---@field loop_flags EXS24LoopFlags
---@field play_mode PlayMode
---@field output integer
---@field group_index integer
---@field sample_index integer
---@field sample_fade integer?
---@field zone_offset integer?

---@class EXS24Sample
---@field kind "sample"
---@field offset integer
---@field header EXS24Header
---@field sample_length integer
---@field sample_rate integer
---@field bit_depth integer
---@field sample_type integer
---@field file_path string
---@field file_name string?

---@class EXS24File
---@field chunks table[]
---@field headers EXS24Header[]
---@field instruments EXS24Instrument[]
---@field zones EXS24Zone[]
---@field samples EXS24Sample[]

-- ---------------------------------------------------------------------------
-- Chunk parsers
-- ---------------------------------------------------------------------------

local function decode_size(buf)
  -- Single-byte sizes for old files; newer files OR in a second byte (with the
  -- high bit set as a continuation marker). Big-endian variants don't use this.
  local b1, b2 = string.byte(buf, 1, 2)
  return bit.bor(b1, bit.lshift(bit.band(0x7F, b2), 8))
end

local function parse_header(buf)
  return {
    ---@diagnostic disable: duplicate-index
    kind = "header",
    offset = buf:seek(),
    signature = buf:read(2),
    _ = buf:skip() and nil,
    marker = buf:read_byte(),
    size = decode_size(buf:read(2)),
    _ = buf:skip(2) and nil,
    index = buf:u32(),
    _ = buf:skip(4) and nil,
    chunk_id = buf:read(4),
    name = buf:cstr(64),
    ---@diagnostic enable: duplicate-index
  }
end

local function parse_instrument(buf)
  return {
    ---@diagnostic disable: duplicate-index
    kind = "instrument",
    offset = buf:seek(),
    _ = buf:skip(4) and nil,
    num_zones = buf:u32(),
    num_groups = buf:u32(),
    num_samples = buf:u32(),
    ---@diagnostic enable: duplicate-index
  }
end

local function parse_zone_flags(buf)
  local flags = buf:u8()
  return {
    oneshot = bit.band(flags, 1) ~= 0,
    pitch = bit.band(flags, 2) == 0,
    reverse = bit.band(flags, 4) ~= 0,
    has_velocity_range = bit.band(flags, 8) ~= 0,
    has_output = bit.band(flags, 64) ~= 0,
  }
end

local function parse_loop_flags(buf)
  local flags = buf:u8()
  return {
    loop_on = bit.band(flags, 1) ~= 0,
    equal_power = bit.band(flags, 2) ~= 0,
    end_release = bit.band(flags, 4) ~= 0,
  }
end

local function parse_zone(buf, size)
  return {
    ---@diagnostic disable: duplicate-index
    kind = "zone",
    offset = buf:seek(),
    zone_flags = parse_zone_flags(buf),
    key = buf:u8(),
    fine_tuning = buf:i8(),
    pan = buf:i8(),
    volume = buf:i8(),
    _ = buf:skip() and nil,
    key_low = buf:u8(),
    key_high = buf:u8(),
    _ = buf:skip() and nil,
    velocity_low = buf:u8(),
    velocity_high = buf:u8(),
    _ = buf:skip() and nil,
    sample_start = buf:u32(),
    sample_end = buf:u32(),
    loop_start = buf:u32(),
    loop_end = buf:u32(),
    loop_crossfade = buf:u32(),
    _ = buf:skip() and nil,
    loop_flags = parse_loop_flags(buf),
    play_mode = buf:u8(),
    _ = buf:skip(47) and nil,
    output = buf:read_byte(),
    _ = buf:skip(5) and nil,
    group_index = buf:u32(),
    sample_index = buf:u32(),
    _ = buf:skip(4) and nil,
    sample_fade = size >= 104 and buf:u32() or nil,
    zone_offset = size >= 108 and buf:u32() or nil,
    ---@diagnostic enable: duplicate-index
  }
end

local function parse_sample(buf, size)
  return {
    ---@diagnostic disable: duplicate-index
    kind = "sample",
    offset = buf:seek(),
    _ = buf:skip(4) and nil,
    sample_length = buf:u32(),
    sample_rate = buf:u32(),
    bit_depth = buf:u8(),
    _ = buf:skip(15) and nil,
    sample_type = buf:u32(),
    _ = buf:skip(48) and nil,
    file_path = buf:cstr(256),
    file_name = size >= 676 and buf:cstr(256) or nil,
    ---@diagnostic enable: duplicate-index
  }
end

---Parse a raw .exs byte string into an EXS24File table.
---@param data string
---@return EXS24File
function pakettiEXS24Parser.parse(data)
  local buf = buffer_new(data)

  -- The chunk ID starts at 16 and is normally "TBOS" or "JBOS"; for a big-
  -- endian file the byte order is swapped and the first letter is always "S".
  if buf:peek("set", 16) == string.byte("S") then
    buf:endian(">")
  else
    buf:endian("<")
  end

  ---@type EXS24File
  local exs_file = {
    chunks = {}, headers = {}, instruments = {}, zones = {}, samples = {},
  }

  while buf:seek() + HEADER_SIZE < buf.size do
    local header = parse_header(buf)

    local chunk_id = header.chunk_id
    if chunk_id ~= "TBOS" and chunk_id ~= "JBOS"
      and chunk_id ~= "SOBT" and chunk_id ~= "SOBJ" then
      error("bad header (chunk_id=" .. tostring(chunk_id) .. ")")
    end

    table.insert(exs_file.chunks, header)
    table.insert(exs_file.headers, header)

    local size = header.size
    if size > buf:remaining() then
      error("unexpected end of data (need " .. size .. ", have " .. buf:remaining() .. ")")
    end

    local chunk_type = low_byte(header.marker)
    if chunk_type == 0 then
      local instrument = parse_instrument(buf)
      instrument.header = header
      table.insert(exs_file.chunks, instrument)
      table.insert(exs_file.instruments, instrument)
    elseif chunk_type == 1 then
      local zone = parse_zone(buf, size)
      zone.header = header
      table.insert(exs_file.chunks, zone)
      table.insert(exs_file.zones, zone)
    elseif chunk_type == 3 then
      local sample = parse_sample(buf, size)
      sample.header = header
      table.insert(exs_file.chunks, sample)
      table.insert(exs_file.samples, sample)
    end
    -- chunk_type 2 (group), 4 (param), 0xB (binary plist) intentionally skipped

    buf:seek("set", header.offset + HEADER_SIZE + size)
  end

  return exs_file
end
