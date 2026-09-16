--------------------------------------------------------------------------------
-- PakettiForeignFormatSupport.lua
--
-- Shared low-level helpers for the "foreign" hardware-sampler import loaders
-- ported into Paketti from Martin Bealby's 2011 "Additional File Formats" tool
-- (com.mxb.FileFormats): Korg Trinity/Triton (.ksf/.kmp/.ksc), Reason NN-XT
-- (.sxt) and Roland MV8000 (.mv0).
--
-- These are deliberately self-contained globals (Paketti* / PakettiFF* prefix)
-- so the vendor loaders can share one set of nil-checked binary readers and one
-- WAV temp-file writer. Loaded BEFORE the vendor files in main.lua.
--
-- Improvements over the 2011 originals:
--   * Every reader nil-checks its bytes (Paketti rules 20/21) instead of
--     assuming the file is long enough.
--   * No global `lsb_first` state machine — endianness is explicit per reader.
--   * Sample audio is written as a standard little-endian PCM WAV via
--     pakettiGetTempFilePath(), not an AIFF with the "10-bit float" sample-rate
--     hack that silently produced wrong rates below 32768 Hz.
--------------------------------------------------------------------------------

-- Load an entire file into memory. Returns the data string, or nil on failure.
function PakettiFFLoadFile(filename)
  if not filename or filename == "" then return nil end
  local f = io.open(filename, "rb")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  if not data or data == "" then return nil end
  return data
end

-- Unsigned byte at 1-based position (nil if out of range).
function PakettiFFReadU8(d, pos)
  if not d or not pos then return nil end
  return string.byte(d, pos)
end

-- Unsigned 16-bit, little-endian.
function PakettiFFReadU16LE(d, pos)
  if not d or not pos then return nil end
  local b1, b2 = string.byte(d, pos, pos + 1)
  if not b1 or not b2 then return nil end
  return b1 + b2 * 256
end

-- Unsigned 16-bit, big-endian.
function PakettiFFReadU16BE(d, pos)
  if not d or not pos then return nil end
  local b1, b2 = string.byte(d, pos, pos + 1)
  if not b1 or not b2 then return nil end
  return b1 * 256 + b2
end

-- Unsigned 32-bit, little-endian.
function PakettiFFReadU32LE(d, pos)
  if not d or not pos then return nil end
  local b1, b2, b3, b4 = string.byte(d, pos, pos + 3)
  if not b1 or not b2 or not b3 or not b4 then return nil end
  return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

-- Unsigned 32-bit, big-endian.
function PakettiFFReadU32BE(d, pos)
  if not d or not pos then return nil end
  local b1, b2, b3, b4 = string.byte(d, pos, pos + 3)
  if not b1 or not b2 or not b3 or not b4 then return nil end
  return b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
end

-- Fixed-length string at 1-based position ("" if out of range).
function PakettiFFReadStr(d, pos, len)
  if not d or not pos or not len then return "" end
  return string.sub(d, pos, pos + len - 1) or ""
end

-- Convert a raw byte to a signed two's-complement value (-128..127).
function PakettiFFByteToSigned(value)
  if not value then return 0 end
  if value < 128 then return value else return value - 256 end
end

-- Split a qualified filename into (path-with-trailing-separator, basename-no-ext).
function PakettiFFSplitFilename(filename)
  if not filename or filename == "" then return "", "" end
  local path = filename:match("^(.*[/\\])") or ""
  local base = filename:match("([^/\\]+)$") or filename
  local name = base:match("^(.*)%.[^.]+$") or base
  return path, name
end

-- Byte-swap 16-bit PCM (big-endian -> little-endian, or vice versa).
function PakettiFFSwap16(pcm)
  if not pcm or #pcm < 2 then return pcm end
  local out = {}
  local n = #pcm
  -- ignore a trailing odd byte if present
  local last = n - (n % 2)
  for i = 1, last - 1, 2 do
    out[#out + 1] = pcm:sub(i + 1, i + 1) .. pcm:sub(i, i)
  end
  return table.concat(out)
end

-- Intelligently locate the folder holding a patch's samples, or prompt the user.
-- Returns a path ending in "/", or nil if the user aborts.
function PakettiFFGetSamplesPath(instrument_name, instrument_path, sample_filename)
  if not instrument_path then instrument_path = "" end
  if not sample_filename then sample_filename = "" end
  local candidates = {
    instrument_path,
    instrument_path .. instrument_name .. "/",
    instrument_path .. "samples/",
    instrument_path .. "Samples/",
    instrument_path .. instrument_name .. "-samples/",
    instrument_path .. instrument_name .. "_samples/",
    instrument_path .. instrument_name .. " samples/",
  }
  for _, c in ipairs(candidates) do
    if io.exists(c .. sample_filename) then return c end
  end
  local chosen = renoise.app():prompt_for_path(
    "Location of samples for patch: " .. tostring(instrument_name))
  if not chosen or chosen == "" then return nil end
  if not chosen:match("[/\\]$") then chosen = chosen .. "/" end
  return chosen
end

-- Little-endian integer -> N raw bytes.
local function le_bytes(value, num_bytes)
  local t = {}
  for _ = 1, num_bytes do
    t[#t + 1] = string.char(value % 256)
    value = math.floor(value / 256)
  end
  return table.concat(t)
end

-- Write a standard 16-bit (or given bit-depth) little-endian PCM WAV to a Paketti
-- temp file and return its path, or nil on failure. `pcm_le` must already be
-- little-endian interleaved sample data.
function PakettiFFWriteWAV(channels, samplerate, bit_depth, pcm_le)
  if not pcm_le or pcm_le == "" then return nil end
  channels = channels or 1
  samplerate = samplerate or 44100
  bit_depth = bit_depth or 16

  local byte_rate = samplerate * channels * (bit_depth / 8)
  local block_align = channels * (bit_depth / 8)
  local data_len = #pcm_le

  local path = pakettiGetTempFilePath(".wav")
  local f = io.open(path, "wb")
  if not f then
    renoise.app():show_status("Could not create temporary WAV file for import.")
    return nil
  end

  f:write("RIFF")
  f:write(le_bytes(data_len + 36, 4)) -- ChunkSize = 36 + Subchunk2Size
  f:write("WAVE")

  f:write("fmt ")
  f:write(le_bytes(16, 4))            -- Subchunk1Size (PCM)
  f:write(le_bytes(1, 2))             -- AudioFormat = PCM
  f:write(le_bytes(channels, 2))
  f:write(le_bytes(samplerate, 4))
  f:write(le_bytes(byte_rate, 4))
  f:write(le_bytes(block_align, 2))
  f:write(le_bytes(bit_depth, 2))

  f:write("data")
  f:write(le_bytes(data_len, 4))
  f:write(pcm_le)

  f:flush()
  f:close()
  return path
end
