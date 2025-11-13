-- Control variable for showing debug dialog after drag & drop import
-- Set to true to show debug dialog when dragging .ot files into Renoise
-- Set to false to import silently (default behavior)
local show_debug_dialog_on_import = true

local header = { 
  0x46, 0x4F, 0x52, 0x4D, 
  0x00, 0x00, 0x00, 0x00, 
  0x44, 0x50, 0x53, 0x31, 
  0x53, 0x4D, 0x50, 0x41 };

local unknown = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00 };

function wb32(f, x)
  local b4 = string.char(x % 256) x = (x - x % 256) / 256
  local b3 = string.char(x % 256) x = (x - x % 256) / 256
  local b2 = string.char(x % 256) x = (x - x % 256) / 256
  local b1 = string.char(x % 256) x = (x - x % 256) / 256
  f:write(b1, b2, b3, b4)  -- Big-endian: MSB first
end

function wb16(f, x)
  local b2 = string.char(x % 256) x = (x - x % 256) / 256
  local b1 = string.char(x % 256) x = (x - x % 256) / 256
  f:write(b1, b2)  -- Big-endian: MSB first
end

-- Function to write 16-bit value with byte order reversal for checksum (DEPRECATED - not used anymore)
function wb16_reversed(f, x)
  local b2 = string.char(x % 256) x = (x - x % 256) / 256
  local b1 = string.char(x % 256) x = (x - x % 256) / 256
  f:write(b2, b1)  -- Reversed byte order for little-endian checksum
end

function wb(f, x)
  f:write(string.char(x))
end

function wb_table(f, data)
  for k, v in ipairs(data) do
      wb(f, v);
  end
end

function w_slices(f, slices)
  for k, slice in ipairs(slices) do
      wb32(f, slice.start_point);
      wb32(f, slice.end_point);
      wb32(f, slice.loop_point);
  end
end

-- Creates .ot file data table with correct Octatrack format specifications
-- Based on OctaChainer source code analysis for 100% compatibility
-- Key implementations matching OctaChainer exactly:
-- 1. Endianness: BIG-ENDIAN (MSB first) for all 16/32-bit values
-- 2. Tempo: BPM × 24 (matches OctaChainer tempo*6 where tempo=BPM*4)
-- 3. Trim/Loop Length: bars × 25, where bars = (BPM × frames) / (sampleRate × 60 × 4)
-- 4. Gain: User gain + 48 offset (48 = 0dB)  
-- 5. Slice positions: First slice MUST start at 0, others convert 1-based→0-based
-- 6. Checksum: Sum bytes 16-829 (OctaChainer method), 16-bit wrap only
-- 7. File size: Exactly 832 bytes
-- 8. Unknown bytes: {0x00,0x00,0x00,0x00,0x00,0x02,0x00} (matches OctaChainer)
function make_ot_table(sample)
  local sample_buffer = sample.sample_buffer
  local slice_count   = table.getn(sample.slice_markers)
  local sample_len    = sample_buffer.number_of_frames

  -- These variables need to be accessible for debug prints
  local sample_rate = sample.sample_buffer.sample_rate
  local bpm = renoise.song().transport.bpm

  -- Try to extract OT metadata from sample name first
  local tempo_value, trim_loop_value, loop_len_value, stretch_value, loop_value, gain_value, stored_slice_ends, trim_end_value
  
  print("PakettiOTExport: DEBUG - Sample name: '" .. sample.name .. "'")
  print("PakettiOTExport: DEBUG - Current song BPM: " .. bpm)
  
  -- Try newest format with TE (trim_end) field first
  local t_val, tl_val, ll_val, s_val, l_val, g_val, te_val, e_val = sample.name:match("OT%[T(%d+):TL(%d+):LL(%d+):S(%d+):L(%d+):G(%d+):TE(%d+):E=([%d,]*)%]")
  
  print("PakettiOTExport: DEBUG - Pattern match results (NEW with TE):")
  print("PakettiOTExport: DEBUG - t_val=" .. tostring(t_val))
  print("PakettiOTExport: DEBUG - tl_val=" .. tostring(tl_val))  
  print("PakettiOTExport: DEBUG - ll_val=" .. tostring(ll_val))
  print("PakettiOTExport: DEBUG - s_val=" .. tostring(s_val))
  print("PakettiOTExport: DEBUG - l_val=" .. tostring(l_val))
  print("PakettiOTExport: DEBUG - g_val=" .. tostring(g_val))
  print("PakettiOTExport: DEBUG - te_val=" .. tostring(te_val))
  print("PakettiOTExport: DEBUG - e_val=" .. tostring(e_val))
  
  -- Try format without TE field for backward compatibility  
  if not t_val then
    print("PakettiOTExport: DEBUG - NEW with TE failed, trying format without TE")
    t_val, tl_val, ll_val, s_val, l_val, g_val, e_val = sample.name:match("OT%[T(%d+):TL(%d+):LL(%d+):S(%d+):L(%d+):G(%d+):E=([%d,]*)%]")
    te_val = nil  -- No TE field in this format
    if t_val then
      print("PakettiOTExport: DEBUG - Found format without TE")
    end
  else
    print("PakettiOTExport: DEBUG - Found NEW format with TE field")
  end
  
  -- Try old format without slice ends for backward compatibility
  if not t_val then
    print("PakettiOTExport: DEBUG - Trying OLD format without slice ends")
    t_val, tl_val, ll_val, s_val, l_val, g_val = sample.name:match("OT%[T(%d+):TL(%d+):LL(%d+):S(%d+):L(%d+):G(%d+)%]")
    te_val = nil
    e_val = nil
    if t_val then
      print("PakettiOTExport: DEBUG - Found OLD format metadata")
      print("PakettiOTExport: DEBUG - OLD t_val=" .. tostring(t_val))
    end
  end
  
  if not t_val then
    print("PakettiOTExport: DEBUG - NO metadata found in sample name, using fallback")
  end
  
  if t_val then
    -- Use stored OT metadata from import
    tempo_value = tonumber(t_val)
    trim_loop_value = tonumber(tl_val)
    loop_len_value = tonumber(ll_val)
    stretch_value = tonumber(s_val)
    loop_value = tonumber(l_val)
    gain_value = tonumber(g_val)
    -- Always use current sample length for trim_end (don't trust stored values)
    trim_end_value = sample_len
    print("PakettiOTExport: Using current sample length for trim_end: " .. trim_end_value)
    
    -- Parse stored slice ends
    stored_slice_ends = {}
    if e_val and e_val ~= "" then
      for end_pos in e_val:gmatch("(%d+)") do
        table.insert(stored_slice_ends, tonumber(end_pos))
      end
    end
    
    print("PakettiOTExport: SUCCESSFULLY USING STORED OT METADATA")
    print(string.format("PakettiOTExport: Tempo=%d (BPM: %d), TrimLen=%d, LoopLen=%d, Stretch=%d, Loop=%d, Gain=%d", 
      tempo_value, math.floor(tempo_value/24), trim_loop_value, loop_len_value, stretch_value, loop_value, gain_value))
    print(string.format("PakettiOTExport: trim_end=%d, sample_len=%d", trim_end_value, sample_len))
    print(string.format("PakettiOTExport: Found %d stored slice ends", #stored_slice_ends))
    
    -- Show first few slice ends for verification
    if stored_slice_ends and #stored_slice_ends > 0 then
      local preview = {}
      for i = 1, math.min(5, #stored_slice_ends) do
        table.insert(preview, tostring(stored_slice_ends[i]))
      end
      if #stored_slice_ends > 5 then
        table.insert(preview, "...")
      end
      print(string.format("PakettiOTExport: Slice ends preview: %s", table.concat(preview, ", ")))
    end
  else
    -- Fallback: compute values from current Renoise state
    tempo_value = math.floor(bpm * 24)
    
    -- Calculate trim_len and loop_len using OctaChainer's bar-based formula
    -- bars = (BPM * totalSampleCount) / (sampleRate * 60.0 * 4) + 0.5 (rounded)
    -- stored_value = bars * 25
    local bars = math.floor(((bpm * sample_len) / (sample_rate * 60.0 * 4)) + 0.5)
    trim_loop_value = bars * 25
    loop_len_value = trim_loop_value  -- Default loop length = full sample length
    
    stretch_value = 0  -- Use stretch=0 (Off) like OctaChainer
    loop_value = 0     -- Use loop=0 (Off) like OctaChainer  
    gain_value = 48    -- 0dB gain (48 = 0dB offset)
    trim_end_value = sample_len  -- Use actual sample length when no metadata available
    stored_slice_ends = nil
    print("PakettiOTExport: Computing new OT values using OctaChainer method")
    print(string.format("PakettiOTExport: NEW SAMPLE - Tempo=%d (BPM: %d), TrimLen=%d, LoopLen=%d", 
      tempo_value, math.floor(tempo_value/24), trim_loop_value, loop_len_value))
    print(string.format("PakettiOTExport: NEW SAMPLE - Sample: %d frames, %.1fkHz → bars=%.2f → trim_len=%d", 
      sample_len, sample_rate, bars, trim_loop_value))
  end

  -- Limit slice count to 64 (Octatrack maximum)
  local export_slice_count = math.min(slice_count, 64)

  -- Final values check before creating .ot table
  print("=== FINAL VALUES FOR .OT EXPORT ===")
  print(string.format("FINAL tempo_value: %d (BPM: %d)", tempo_value, math.floor(tempo_value/24)))
  print(string.format("FINAL trim_loop_value: %d", trim_loop_value))
  print(string.format("FINAL trim_end_value: %d", trim_end_value))
  print("=====================================")

  -- Debug prints
  print("sample length: " .. sample_len .. " frames")
  print("sample rate: " .. sample_rate .. " Hz")
  print("tempo: " .. bpm .. " BPM (stored as " .. tempo_value .. ")")
  print("trim/loop length: " .. trim_loop_value .. " (OctaChainer bars × 25 method)")
  print("total slices: " .. slice_count .. ", exporting: " .. export_slice_count)
  
  -- Warn if there are more slices than the Octatrack can handle
  if slice_count > 64 then
    print("WARNING: Sample has " .. slice_count .. " slices, but .ot format only supports 64 slices maximum.")
    print("Only the first 64 slices will be exported to the .ot file.")
    renoise.app():show_status("Exporting first 64 of " .. slice_count .. " slices (.ot format limit)")
  elseif slice_count > 0 then
    print("Exporting all " .. slice_count .. " slices to .ot file.")
    renoise.app():show_status("Exporting " .. slice_count .. " slices to .ot file")
  else
    print("No slices found in sample - exporting .ot file without slice data.")
    renoise.app():show_status("No slices found - exporting .ot file without slice data")
  end

  local ot = {}

  -- Insert header and unknown
  for k, v in ipairs(header) do
    table.insert(ot, v)
  end
  for k, v in ipairs(unknown) do
    table.insert(ot, v)
  end

  -- tempo (32)
  table.insert(ot, tempo_value)
  -- trim_len (32)   (frames × 100 / sampleRate per OctaChainer spec)
  table.insert(ot, trim_loop_value)
  -- loop_len (32)   (frames × 100 / sampleRate per OctaChainer spec)
  table.insert(ot, loop_len_value)
  -- stretch (32)
  table.insert(ot, stretch_value)
  -- loop (32)      (0 = off)
  table.insert(ot, loop_value)
  -- gain (16)      (user_gain + 48, where 0 dB = 48)
  table.insert(ot, gain_value)
  -- quantize (8)
  table.insert(ot, 0xFF)
  -- trim_start (32)
  table.insert(ot, 0x00)
  -- trim_end (32)
  table.insert(ot, trim_end_value)
  -- loop_point (32)
  table.insert(ot, 0x00)

  -- Process only the first 64 slices (or fewer if less than 64 exist)
  for k = 1, export_slice_count do
    local v    = sample.slice_markers[k]
    local nxt  = (k < export_slice_count) and sample.slice_markers[k + 1] or sample_len

    print("slice " .. k .. ": " .. v .. ", next: " .. nxt)

    -- Convert from 1-based (Renoise) to 0-based (Octatrack) indexing
    -- CRITICAL: First slice must start at frame 0 for Octatrack
    local s_start = (k == 1) and 0 or (v - 1)   -- Octatrack demands start = 0
    
    -- Always calculate slice end from current sample, don't use stored positions
    -- (stored positions might be from different sample rate/length)
    local s_end
    if k < export_slice_count then
      s_end = sample.slice_markers[k + 1] - 2  -- next start - 1, converted to 0-based
    else
      s_end = sample_len - 1  -- last slice ends at sample end - 1
    end
    
    -- Ensure slice end is within sample bounds
    s_end = math.max(s_start, math.min(s_end, sample_len - 1))
    print("slice " .. k .. ": calculated end position " .. s_end .. " (bounds-checked)")

    -- start_point (32)
    table.insert(ot, s_start)
    -- end_point (32)
    table.insert(ot, s_end)
    -- loop_point (32)
    table.insert(ot, 0xFFFFFFFF)

    print("slice " .. k .. ": start=" .. s_start .. ", end=" .. s_end)
  end

  -- No empty slice filling - just write actual slices and pad the rest

  -- slice_count (32)
  table.insert(ot, export_slice_count)

  -- Checksum will be calculated and appended by write_ot_file on the actual byte stream
  print("OT table created, checksum will be calculated on byte stream")
  
  -- DEBUG: Show the ot table structure
  print("=== DEBUG: OT TABLE STRUCTURE ===")
  print("Total ot table size:", #ot)
  print("ot[24] (should be tempo):", ot[24])
  print("ot[25] (should be trim_len):", ot[25])
  print("ot[32] (should be trim_end):", ot[32])
  print("=================================")

  return ot
end

function write_ot_file(filename, ot)
  local ot_filename
  
  -- Check if filename already ends with .ot
  if filename:match("%.ot$") then
    ot_filename = filename
  else
    -- Extract base name without extension
    local name = filename:match("(.+)%..+$")
    -- Fallback if pattern match fails or filename has no extension
    if not name then
      name = filename
    end
    ot_filename = name .. ".ot"
  end
  
  -- Build complete byte array first (832 bytes exactly)
  local byte_array = {}
  
  -- Helper function to append bytes from integer (big-endian)
  local function append_be32(value)
    local b4 = value % 256; value = math.floor(value / 256)
    local b3 = value % 256; value = math.floor(value / 256)
    local b2 = value % 256; value = math.floor(value / 256)
    local b1 = value % 256
    table.insert(byte_array, b1)  -- MSB first
    table.insert(byte_array, b2)
    table.insert(byte_array, b3)
    table.insert(byte_array, b4)  -- LSB last
  end
  
  local function append_be16(value)
    local b2 = value % 256; value = math.floor(value / 256)
    local b1 = value % 256
    table.insert(byte_array, b1)  -- MSB first
    table.insert(byte_array, b2)  -- LSB last
  end
  
  local function append_byte(value)
    table.insert(byte_array, value)
  end
  
  -- Write header and unknown (bytes 1-23, single bytes)
  for i = 1, 23 do
    append_byte(ot[i])
  end
  
  -- Write main data section (starting at byte 24, offset 0x17)
  local data_start = 24  -- Start of checksummed region
  
  -- DEBUG: Show what values are actually being written
  print("=== DEBUG: ACTUAL VALUES BEING WRITTEN TO FILE ===")
  print("ot[24] (tempo):", ot[24], "(BPM:", math.floor(ot[24]/24) .. ")")
  print("ot[25] (trim_len):", ot[25])
  print("ot[26] (loop_len):", ot[26])
  print("ot[27] (stretch):", ot[27])
  print("ot[28] (loop):", ot[28])
  print("ot[29] (gain):", ot[29])
  print("ot[30] (quantize):", ot[30])
  print("ot[31] (trim_start):", ot[31])
  print("ot[32] (trim_end):", ot[32])
  print("ot[33] (loop_point):", ot[33])
  print("====================================================")
  
  append_be32(ot[24])  -- tempo
  append_be32(ot[25])  -- trim_len  
  append_be32(ot[26])  -- loop_len
  append_be32(ot[27])  -- stretch
  append_be32(ot[28])  -- loop
  append_be16(ot[29])  -- gain
  append_byte(ot[30])  -- quantize
  append_be32(ot[31])  -- trim_start
  append_be32(ot[32])  -- trim_end
  append_be32(ot[33])  -- loop_point
  
  -- Write actual slice data (variable number of slices)
  local slice_data_start = 34  -- First slice data in ot table
  local actual_slice_count = ot[#ot]  -- Last element is slice_count
  local slice_fields_written = 0
  
  print("=== SLICE DATA WRITING ===")
  print("Writing " .. actual_slice_count .. " slices")
  
  -- Write actual slices
  for i = slice_data_start, #ot - 1 do  -- -1 to exclude slice_count
    append_be32(ot[i])
    slice_fields_written = slice_fields_written + 1
    if (slice_fields_written % 3) == 0 then
      local slice_num = slice_fields_written / 3
      print("Wrote slice " .. slice_num .. " data")
    end
  end
  
  -- Pad remaining slice slots with zeros (up to 64 slices total)
  local max_slice_fields = 64 * 3  -- 64 slices × 3 fields each
  for i = slice_fields_written + 1, max_slice_fields do
    append_be32(0)
  end
  
  print("Total slice fields written: " .. slice_fields_written)
  print("Zero-padded fields: " .. (max_slice_fields - slice_fields_written))
  print("=== END SLICE DATA ===")
  
  -- Write slice_count  
  append_be32(actual_slice_count)
  
  -- Calculate checksum using OctaChainer method: sum bytes 16 to 829 (no adjustments)
  local checksum = 0
  local checksum_bytes = {}
  print("=== CHECKSUM CALCULATION DEBUG (OctaChainer method) ===")
  for i = 17, 830 do  -- Convert to 1-based indexing: C++ bytes 16-829 = Lua indices 17-830
    if byte_array[i] then
      checksum = checksum + byte_array[i]
      table.insert(checksum_bytes, byte_array[i])
      if i <= 25 or i >= 826 then  -- Show first few and last few bytes
        print(string.format("byte[%d] = 0x%02X (%d), running sum = %d", i-1, byte_array[i], byte_array[i], checksum))
      elseif i == 26 then
        print("... (omitting middle bytes for readability) ...")
      end
      if checksum > 0xFFFF then
        checksum = checksum % 0x10000  -- 16-bit wrap
      end
    end
  end
  print(string.format("OctaChainer checksum sum: %d (0x%04X)", checksum, checksum))
  print(string.format("Checksum range: C++ bytes 16 to 829 (%d bytes total)", #checksum_bytes))
  print("=== END CHECKSUM DEBUG ===")
  
  -- Show the actual checksum bytes that will be written
  local checksum_hi = math.floor(checksum / 256)
  local checksum_lo = checksum % 256
  print(string.format("Final checksum bytes: 0x%02X 0x%02X (big-endian %d)", checksum_hi, checksum_lo, checksum))
  
  -- Append checksum (16-bit big-endian)
  append_be16(checksum)
  
  -- Ensure exactly 832 bytes
  while #byte_array < 832 do
    append_byte(0)
  end
  
  -- Show complete hexdump of what we're writing (832 bytes)
  hexdump(byte_array, 0, 832, "COMPLETE EXPORTED .OT FILE (832 bytes)")
  
  -- Write to file
  local f = io.open(ot_filename, "wb")
  for i = 1, 832 do
    f:write(string.char(byte_array[i] or 0))
  end
  f:close()
  
  print("PakettiOTExport: .ot file written: " .. ot_filename)
  print("PakettiOTExport: .ot file size: 832 bytes (exactly as per OctaChainer spec)")
  print("PakettiOTExport: checksum calculated: " .. checksum)
end

-- Hexdump function for debugging
function hexdump(data, start_offset, length, label)
  print("=== HEXDUMP: " .. label .. " ===")
  local end_offset = math.min(start_offset + length - 1, #data - 1)
  
  for i = start_offset, end_offset, 16 do
    local hex_part = ""
    local ascii_part = ""
    local line_start = string.format("%08X: ", i)
    
    for j = 0, 15 do
      if i + j <= end_offset then
        local byte_val = type(data) == "string" and string.byte(data, i + j + 1) or data[i + j + 1]
        if byte_val then
          hex_part = hex_part .. string.format("%02X ", byte_val)
          ascii_part = ascii_part .. (byte_val >= 32 and byte_val <= 126 and string.char(byte_val) or ".")
        else
          hex_part = hex_part .. "   "
          ascii_part = ascii_part .. " "
        end
      else
        hex_part = hex_part .. "   "
        ascii_part = ascii_part .. " "
      end
    end
    
    print(line_start .. hex_part .. " |" .. ascii_part .. "|")
  end
  print("=== END HEXDUMP ===")
end

-- Binary reading functions for .ot import (BIG-ENDIAN format)
function rb32(f)
  local b1 = string.byte(f:read(1) or "\0")  -- MSB first
  local b2 = string.byte(f:read(1) or "\0")
  local b3 = string.byte(f:read(1) or "\0")
  local b4 = string.byte(f:read(1) or "\0")  -- LSB last
  return b1 * 256^3 + b2 * 256^2 + b3 * 256 + b4  -- BIG-ENDIAN
end

function rb16(f)
  local b1 = string.byte(f:read(1) or "\0")  -- MSB first
  local b2 = string.byte(f:read(1) or "\0")  -- LSB last
  return b1 * 256 + b2  -- BIG-ENDIAN
end

function rb(f)
  return string.byte(f:read(1) or "\0")
end

function rb_table(f, count)
  local data = {}
  for i = 1, count do
    table.insert(data, rb(f))
  end
  return data
end

-- Function to read and parse .ot file
function read_ot_file(filename)
  local f = io.open(filename, "rb")
  if not f then
    renoise.app():show_status("Could not open .ot file: " .. filename)
    print("PakettiOTImport: Could not open .ot file: " .. filename)
    return nil
  end
  
  print("PakettiOTImport: Reading .ot file: " .. filename)
  
  -- Read entire file for hexdump analysis
  f:seek("set", 0)  -- Reset to beginning
  local file_data = f:read("*all")
  f:close()
  
  -- Show complete hexdump of entire .ot file (832 bytes)
  hexdump(file_data, 0, 832, "COMPLETE IMPORTED .OT FILE (832 bytes)")
  
  -- Reopen file for normal parsing
  f = io.open(filename, "rb")
  if not f then
    print("PakettiOTImport: Could not reopen .ot file")
    return nil
  end
  
  -- Read header (16 bytes)
  local header_data = rb_table(f, 16)
  print("PakettiOTImport: Header read")
  
  -- Read unknown section (7 bytes)
  local unknown_data = rb_table(f, 7)
  print("PakettiOTImport: Unknown section read")
  
  -- Read main parameters
  local tempo = rb32(f)
  local trim_len = rb32(f)
  local loop_len = rb32(f)
  local stretch = rb32(f)
  local loop = rb32(f)
  local gain = rb16(f)
  local quantize = rb(f)
  local trim_start = rb32(f)
  local trim_end = rb32(f)
  local loop_point = rb32(f)
  
  print("PakettiOTImport: Main parameters - trim_len: " .. trim_len .. ", loop_len: " .. loop_len)
  
  -- Read slice data (64 slices max, 3 x 32-bit values each)
  local slices = {}
  for i = 1, 64 do
    local start_point = rb32(f)
    local end_point = rb32(f)  -- This is end_point, matching C struct
    local slice_loop_point = rb32(f)
    
    -- Only add slices that have actual data (not all zeros)
    if start_point > 0 or end_point > 0 then
      table.insert(slices, {
        start_point = start_point,
        end_point = end_point,  -- Store as end_point to match C struct
        loop_point = slice_loop_point
      })
      print("PakettiOTImport: Slice " .. i .. " - start: " .. start_point .. ", end: " .. end_point)
    end
  end
  
  -- Read slice count and checksum
  local slice_count = rb32(f)
  local checksum = rb16(f)
  
  f:close()
  
  -- Show imported checksum details
  print("=== IMPORTED CHECKSUM ANALYSIS ===")
  print(string.format("File checksum: %d (0x%04X)", checksum, checksum))
  local checksum_hi = math.floor(checksum / 256)
  local checksum_lo = checksum % 256
  print(string.format("Checksum bytes: 0x%02X 0x%02X (big-endian)", checksum_hi, checksum_lo))
  print("=== END IMPORTED CHECKSUM ===")
  
  print("PakettiOTImport: Found " .. slice_count .. " slices in .ot file")
  
  return {
    tempo = tempo,
    trim_len = trim_len,
    loop_len = loop_len,
    stretch = stretch,
    loop = loop,
    gain = gain,
    quantize = quantize,
    trim_start = trim_start,
    trim_end = trim_end,
    loop_point = loop_point,
    slices = slices,
    slice_count = slice_count,
    checksum = checksum
  }
end

-- Function to apply .ot slice data to a specific sample (direct)
function apply_ot_slices_to_sample_direct(ot_data, target_sample)
  if not target_sample or not target_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample provided to apply slices to")
    print("PakettiOTImport: No valid sample provided")
    return
  end
  
  local sample_length = target_sample.sample_buffer.number_of_frames
  print("PakettiOTImport: Sample length is " .. sample_length .. " frames")
  print("PakettiOTImport: Processing " .. #ot_data.slices .. " slices from .ot file")
  
  -- Clear existing slice markers (proper way: delete all existing markers first)
  local existing_markers = {}
  for _, marker in ipairs(target_sample.slice_markers) do
    table.insert(existing_markers, marker)
  end
  for _, marker in ipairs(existing_markers) do
    target_sample:delete_slice_marker(marker)
  end
  print("PakettiOTImport: Cleared " .. #existing_markers .. " existing slice markers")
  
  -- Apply slices from .ot data using proper API
  local applied_slices = 0
  local skipped_slices = 0
  
  for i, slice in ipairs(ot_data.slices) do
    -- Allow slice.start_point >= 0 and ensure it's within sample bounds
    if slice.start_point >= 0 and slice.start_point < sample_length then
      -- Convert from 0-based (Octatrack .ot) to 1-based (Renoise) indexing
      local slice_position = slice.start_point + 1
      
      -- Use proper API method to insert slice marker
      local success, error_msg = pcall(function()
        target_sample:insert_slice_marker(slice_position)
      end)
      
      if success then
        applied_slices = applied_slices + 1
        print("PakettiOTImport: Applied slice " .. applied_slices .. " at position " .. slice_position .. " (from start_point " .. slice.start_point .. ")")
      else
        print("PakettiOTImport: Error inserting slice marker at position " .. slice_position .. ": " .. tostring(error_msg))
        skipped_slices = skipped_slices + 1
      end
    else
      print("PakettiOTImport: Skipping slice " .. i .. " - start_point " .. slice.start_point .. " is out of bounds (sample length: " .. sample_length .. ")")
      skipped_slices = skipped_slices + 1
    end
  end
  
  if applied_slices > 0 then
    renoise.app():show_status("Applied " .. applied_slices .. " slices from .ot file")
    print("PakettiOTImport: Successfully applied " .. applied_slices .. " slices to sample")
  else
    renoise.app():show_status("No slices applied - all slice positions were out of bounds or at position 0")
    print("PakettiOTImport: No slices applied - " .. skipped_slices .. " slices were skipped")
  end
  
  if skipped_slices > 0 then
    print("PakettiOTImport: Total skipped slices: " .. skipped_slices)
  end
end

-- Function to apply .ot slice data to current sample
function apply_ot_slices_to_sample(ot_data)
  local song = renoise.song()
  local sample = song.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample selected to apply slices to")
    print("PakettiOTImport: No valid sample selected")
    return
  end
  
  local sample_length = sample.sample_buffer.number_of_frames
  local instrument = song.selected_instrument
  local sample_index = song.selected_sample_index
  
  print("PakettiOTImport: Working with instrument '" .. instrument.name .. "' (index " .. song.selected_instrument_index .. "), sample '" .. sample.name .. "' (index " .. sample_index .. ")")
  print("PakettiOTImport: Sample length is " .. sample_length .. " frames")
  print("PakettiOTImport: Processing " .. #ot_data.slices .. " slices from .ot file")
  
  -- Clear existing slice markers (proper way: delete all existing markers first)
  local existing_markers = {}
  for _, marker in ipairs(sample.slice_markers) do
    table.insert(existing_markers, marker)
  end
  for _, marker in ipairs(existing_markers) do
    sample:delete_slice_marker(marker)
  end
  print("PakettiOTImport: Cleared " .. #existing_markers .. " existing slice markers")
  
  -- Apply slices from .ot data using proper API
  local applied_slices = 0
  local skipped_slices = 0
  
  for i, slice in ipairs(ot_data.slices) do
    -- Allow slice.start_point >= 0 and ensure it's within sample bounds
    if slice.start_point >= 0 and slice.start_point < sample_length then
      -- Convert from 0-based (Octatrack .ot) to 1-based (Renoise) indexing
      local slice_position = slice.start_point + 1
      
      -- Use proper API method to insert slice marker
      local success, error_msg = pcall(function()
        sample:insert_slice_marker(slice_position)
      end)
      
      if success then
        applied_slices = applied_slices + 1
        print("PakettiOTImport: Applied slice " .. applied_slices .. " at position " .. slice_position .. " (from start_point " .. slice.start_point .. ")")
      else
        print("PakettiOTImport: Error inserting slice marker at position " .. slice_position .. ": " .. tostring(error_msg))
        skipped_slices = skipped_slices + 1
      end
    else
      print("PakettiOTImport: Skipping slice " .. i .. " - start_point " .. slice.start_point .. " is out of bounds (sample length: " .. sample_length .. ")")
      skipped_slices = skipped_slices + 1
    end
  end
  
  if applied_slices > 0 then
    renoise.app():show_status("Applied " .. applied_slices .. " slices from .ot file")
    print("PakettiOTImport: Successfully applied " .. applied_slices .. " slices to sample")
  else
    renoise.app():show_status("No slices applied - all slice positions were out of bounds or at position 0")
    print("PakettiOTImport: No slices applied - " .. skipped_slices .. " slices were skipped")
  end
  
  if skipped_slices > 0 then
    print("PakettiOTImport: Total skipped slices: " .. skipped_slices)
  end
end

-- Function to export only .ot file (no audio)
function PakettiOTExportOtOnly()
    -- Check if there's a song
    if not renoise.song() then
        renoise.app():show_status("No song loaded")
        print("PakettiOTExportOtOnly: No song loaded")
        return
    end
    
    -- Check if there are any instruments
    if not renoise.song().instruments or #renoise.song().instruments == 0 then
        renoise.app():show_status("No instruments in song")
        print("PakettiOTExportOtOnly: No instruments in song")
        return
    end
    
    -- Check if there's a selected instrument
    if not renoise.song().selected_instrument then
        renoise.app():show_status("No instrument selected")
        print("PakettiOTExportOtOnly: No instrument selected")
        return
    end
    
    -- Check if the selected instrument has samples
    if not renoise.song().selected_instrument.samples or #renoise.song().selected_instrument.samples == 0 then
        renoise.app():show_status("Selected instrument has no samples")
        print("PakettiOTExportOtOnly: Selected instrument has no samples")
        return
    end
    
    -- Check if there's a selected sample
    local sample = renoise.song().selected_sample
    if not sample then
        renoise.app():show_status("No sample selected")
        print("PakettiOTExportOtOnly: No sample selected")
        return
    end
    
    -- Check if the sample has a sample buffer
    if not sample.sample_buffer then
        renoise.app():show_status("Selected sample has no sample buffer")
        print("PakettiOTExportOtOnly: Selected sample has no sample buffer")
        return
    end
    
    -- Check if the sample buffer has frames
    if not sample.sample_buffer.number_of_frames or sample.sample_buffer.number_of_frames <= 0 then
        renoise.app():show_status("Selected sample has no audio data")
        print("PakettiOTExportOtOnly: Selected sample has no audio data")
        return
    end
    
    -- Check if slice_markers exists (initialize empty table if nil)
    if not sample.slice_markers then
        sample.slice_markers = {}
        print("PakettiOTExportOtOnly: No slice markers found, using empty table")
    end
    
    -- Check if sample has a name (provide default if needed)
    if not sample.name or sample.name == "" then
        sample.name = "Unknown Sample"
        print("PakettiOTExportOtOnly: Sample has no name, using default")
    end
    
    -- Check slice count and warn if over 64 (Octatrack limit)
    local slice_count = sample.slice_markers and #sample.slice_markers or 0
    if slice_count > 64 then
        local result = renoise.app():show_prompt("Slice Limit Warning", 
            "Sample has " .. slice_count .. " slices, but Octatrack only supports 64.\n" ..
            "Only the first 64 slices will be exported.\n\nContinue?", 
            {"Continue", "Cancel"})
        if result == "Cancel" then
            renoise.app():show_status("Export cancelled")
            print("PakettiOTExportOtOnly: Export cancelled due to slice count")
            return
        end
        print("PakettiOTExportOtOnly: Warning - Exporting only first 64 of " .. slice_count .. " slices")
    end
    
    print("PakettiOTExportOtOnly: All safety checks passed, proceeding with .ot export")
    
    -- Refresh sample reference in case it was changed by any preprocessing
    sample = renoise.song().selected_sample
    local ot = make_ot_table(sample)
    local filename = renoise.app():prompt_for_filename_to_write("*.ot", "Save .ot file...")
    
    -- Check if user cancelled the file dialog
    if not filename or filename == "" then
        renoise.app():show_status("Export cancelled")
        print("PakettiOTExportOtOnly: Export cancelled by user")
        return
    end
    
    write_ot_file(filename, ot)
    renoise.app():show_status(".ot file exported successfully")
    print("PakettiOTExportOtOnly: .ot file export completed successfully")
end

-- Function to import .ot file and apply slices
function PakettiOTImport()
    -- Check if there's a selected sample to apply slices to
    if not renoise.song() then
        renoise.app():show_status("No song loaded")
        print("PakettiOTImport: No song loaded")
        return
    end
    
    if not renoise.song().selected_sample or not renoise.song().selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("Please select a sample to apply .ot slices to")
        print("PakettiOTImport: No valid sample selected")
        return
    end
    
    local filename = renoise.app():prompt_for_filename_to_read({"*.ot"}, "Load .ot file...")
    
    -- Check if user cancelled the file dialog
    if not filename or filename == "" then
        renoise.app():show_status("Import cancelled")
        print("PakettiOTImport: Import cancelled by user")
        return
    end
    
    local ot_data = read_ot_file(filename)
    if ot_data then
        apply_ot_slices_to_sample(ot_data)
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    end
end


-- Reusable function to show .ot file debug information in a dialog
function show_ot_debug_dialog(ot_data, filename, extra_info, show_apply_button, apply_callback)
    -- Convert tempo back to BPM (tempo_value / 24 per Octatrack spec)
    local calculated_bpm = math.floor(ot_data.tempo / 24)
    
    -- Build debug info string
    local debug_info = string.format([[
File: %s%s

MAIN PARAMETERS:
- Tempo: %d (BPM: %d)
- Trim Length: %d (frames×100/sampleRate)
- Loop Length: %d (frames×100/sampleRate)
- Stretch: %d (0=Off, 2=Normal, 3=Beat)
- Loop: %d (0=Off, 1=Normal, 2=PingPong)
- Gain: %d (dB offset: %+d, where 48=0dB)
- Quantize: 0x%02X (0xFF=Direct, 0x00=Pattern)
- Trim Start: %d
- Trim End: %d
- Loop Point: %d
- Slice Count: %d
- Checksum: %d

SLICES (%d found):]], 
        filename:match("([^/\\]+)$") or filename,
        extra_info or "",
        ot_data.tempo, calculated_bpm,
        ot_data.trim_len, ot_data.loop_len,
        ot_data.stretch, ot_data.loop,
        ot_data.gain, ot_data.gain - 48, ot_data.quantize,
        ot_data.trim_start, ot_data.trim_end, ot_data.loop_point,
        ot_data.slice_count, ot_data.checksum,
        #ot_data.slices)
    
    -- Add ALL slice information (no truncation)
    for i, slice in ipairs(ot_data.slices) do
            debug_info = debug_info .. string.format("\n%2d: Start=%d, End=%d, Loop=0x%08X", 
                i, slice.start_point, slice.end_point, slice.loop_point)
    end
    
    -- Show in a custom dialog
    local vb = renoise.ViewBuilder()
    local debug_dialog = nil  -- Store dialog handle for proper closing
    
    -- Build button row
    local button_row = vb:horizontal_aligner {
        mode = show_apply_button and "distribute" or "right"
    }
    
    if show_apply_button and apply_callback then
        button_row:add_child(vb:button {
            text = "Apply Slices to Current Sample",
            width = 200,
            released = apply_callback
        })
    end
    
    button_row:add_child(vb:button {
        text = "Close",
        width = 100,
        released = function()
            if debug_dialog and debug_dialog.visible then
                debug_dialog:close()
            end
        end
    })
    
    local content = vb:column {
        margin = 10,
        vb:multiline_textfield {
            text = debug_info,
            width = 600,
            height = 700,
            font = "mono"
        },
        button_row
    }
    
    debug_dialog = renoise.app():show_custom_dialog("Octatrack .OT File Analysis", content)
end

-- Function to show .ot file debug information in a dialog
function PakettiOTDebugDialog()
    local filename = renoise.app():prompt_for_filename_to_read({"*.ot"}, "Load .ot file for analysis...")
    
    if not filename or filename == "" then
        return -- User cancelled
    end
    
    local ot_data = read_ot_file(filename)
    if not ot_data then
        renoise.app():show_error("OT Debug Error", "Could not read .ot file: " .. filename)
        return
    end
    
    show_ot_debug_dialog(ot_data, filename)
end

-- File import hook for .ot files (drag & drop support)
function ot_import_filehook(filename)
  if not filename then
    renoise.app():show_error("OT Import Error: No filename provided!")
    return false
  end

  print("Starting OT import via file hook for file:", filename)
  
  -- Extract base filename for naming
  local ot_basename = filename:match("([^/\\]+)$"):gsub("%.ot$", "")
  
  -- First, read and analyze the .ot file
  local ot_data = read_ot_file(filename)
  if not ot_data then
    renoise.app():show_error("OT Import Error", "Could not read .ot file: " .. filename)
    return false
  end
  
  -- Look for corresponding .wav file in the same directory
  local base_path = filename:match("(.+)%..+$")  -- Remove .ot extension
  local wav_filename = base_path .. ".wav"
  local wav_found = false
  
  -- Check if .wav file exists
  local function file_exists(name)
    local f = io.open(name, "rb")
    if f then f:close() end
    return f ~= nil
  end
  
  wav_found = file_exists(wav_filename)
  
  -- If .wav file found, load it into a new instrument
  local sample_loaded = false
  if wav_found then
    print("Found corresponding .wav file:", wav_filename)
    
    -- Create new instrument for the OT import
    local song = renoise.song()
    local current_index = song.selected_instrument_index
    song:insert_instrument_at(current_index + 1)
    song.selected_instrument_index = current_index + 1
    
    -- Load default Paketti instrument configuration if available
    if pakettiPreferencesDefaultInstrumentLoader then
      pakettiPreferencesDefaultInstrumentLoader()
      print("Injected Paketti default instrument configuration")
    end
    
    local instrument = song.selected_instrument
    local sample = instrument.samples[1]
    
    -- Set instrument and sample names based on .ot filename
      -- Store OT metadata in sample name for later export
      -- Also store slice end positions since Renoise can't store them
      local slice_ends = {}
      for i, slice in ipairs(ot_data.slices) do
        local slice_end = slice.end_point
        
        -- Fix overlapping slices: if this slice's end equals the next slice's start, subtract 1
        if i < #ot_data.slices then
          local next_slice = ot_data.slices[i + 1]
          if slice_end == next_slice.start_point then
            slice_end = slice_end - 1
            print("PakettiOTImport: Fixed overlap - slice " .. i .. " end: " .. slice.end_point .. " -> " .. slice_end)
          end
        end
        
        table.insert(slice_ends, slice_end)
      end
      local ends_string = table.concat(slice_ends, ",")
      
      local ot_metadata = string.format("OT[T%d:TL%d:LL%d:S%d:L%d:G%d:TE%d:E=%s]", 
        ot_data.tempo, ot_data.trim_len, ot_data.loop_len, 
        ot_data.stretch, ot_data.loop, ot_data.gain, ot_data.trim_end, ends_string)
    instrument.name = ot_basename
      sample.name = ot_basename .. " " .. ot_metadata
    
    -- Load the .wav file
    local load_success = pcall(function()
      sample.sample_buffer:load_from(wav_filename)
    end)
    
    if load_success and sample.sample_buffer.has_sample_data then
      print("Successfully loaded .wav file:", wav_filename)
      sample_loaded = true
      
      -- Debug: Show exactly which sample we're working with
      print("DEBUG: Applying slices to instrument '" .. instrument.name .. "', sample '" .. sample.name .. "' (index " .. song.selected_sample_index .. ")")
      print("DEBUG: Sample buffer has " .. sample.sample_buffer.number_of_frames .. " frames")
      print("DEBUG: Current slice_markers count: " .. #sample.slice_markers)
      
      -- Make sure we're still pointing to the correct sample after loading
      song.selected_sample_index = 1  -- Ensure we're on the first sample
      local current_sample = song.selected_sample
      
      -- Apply .ot slice data to the loaded sample (use current selected sample to be sure)
      apply_ot_slices_to_sample_direct(ot_data, current_sample)
      
      -- Debug: Verify slices were applied
      print("DEBUG: After applying slices, slice_markers count: " .. #current_sample.slice_markers)
      if #current_sample.slice_markers > 0 then
        print("DEBUG: First few slice markers: " .. table.concat(current_sample.slice_markers, ", ", 1, math.min(5, #current_sample.slice_markers)))
      end
      
      print("Applied", #ot_data.slices, "slices from .ot file")
      
      -- Set sample properties from preferences if available
      if preferences then
        sample.autofade = preferences.pakettiLoaderAutofade.value
        sample.autoseek = preferences.pakettiLoaderAutoseek.value
        sample.loop_mode = preferences.pakettiLoaderLoopMode.value
        sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
        sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
        sample.oneshot = preferences.pakettiLoaderOneshot.value
        sample.new_note_action = preferences.pakettiLoaderNNA.value
        sample.loop_release = preferences.pakettiLoaderLoopExit.value
      end
      
      -- Switch to sample editor to show the result
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    else
      print("Failed to load .wav file:", wav_filename)
      renoise.app():show_status("Failed to load corresponding .wav file")
    end
  else
    print("No corresponding .wav file found at:", wav_filename)
  end
  
  -- Build status for debug dialog
  local import_status = ""
  if wav_found and sample_loaded then
    import_status = "WAV FILE LOADED & SLICES APPLIED"
  elseif wav_found and not sample_loaded then
    import_status = "WAV FILE FOUND BUT FAILED TO LOAD"
  else
    import_status = "NO CORRESPONDING WAV FILE FOUND"
  end
  
  -- Show debug dialog conditionally based on control variable
  if show_debug_dialog_on_import then
    local extra_info = string.format("\nWAV File: %s\nStatus: %s", 
      wav_found and wav_filename:match("([^/\\]+)$") or "Not found",
      import_status)
    
    local apply_callback = nil
    if not sample_loaded then
      apply_callback = function()
            -- Check if there's a valid sample to apply slices to
            if not renoise.song() then
              renoise.app():show_status("No song loaded")
              return
            end
            
            if not renoise.song().selected_sample or not renoise.song().selected_sample.sample_buffer.has_sample_data then
              renoise.app():show_status("Please select a sample with audio data to apply slices to")
              return
            end
            
            apply_ot_slices_to_sample(ot_data)
            renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
            renoise.app():show_status("Applied " .. #ot_data.slices .. " slices from .ot file")
          end
    end
    
    show_ot_debug_dialog(ot_data, filename, extra_info, not sample_loaded, apply_callback)
  end
  
  if sample_loaded then
    renoise.app():show_status("OT Import: Loaded " .. ot_basename .. " with " .. #ot_data.slices .. " slices")
    print("OT Import: Successfully loaded .wav and applied .ot slices for:", filename)
  else
    renoise.app():show_status("OT Import: Analyzed .ot file (no corresponding .wav found)")
    print("OT Import: Successfully analyzed .ot file:", filename)
  end
  
  return true
end

-- Register the file import hook for .ot files
local ot_integration = {
  category = "sample",
  extensions = { "ot" },
  invoke = ot_import_filehook
}

if not renoise.tool():has_file_import_hook("sample", { "ot" }) then
  renoise.tool():add_file_import_hook(ot_integration)
end



-- Add consolidated Octatrack menu entries
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Octatrack:Export (.WAV+.ot)",invoke=function() PakettiOTExport() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Octatrack:Export (.ot only)",invoke=function() PakettiOTExportOtOnly() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Octatrack:Import (.ot)",invoke=function() PakettiOTImport() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Octatrack:Debug (.ot)",invoke=function() PakettiOTDebugDialog() end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Octatrack:Generate Drumkit (Smart Mono/Stereo)",invoke=function() PakettiOTDrumkitSmart() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Octatrack:Generate Drumkit (Force Mono)",invoke=function() PakettiOTDrumkitMono() end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Octatrack:Set Loop to Slice",invoke=function() PakettiOTSetLoopToSlice() end}

renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Octatrack:Export to Octatrack (.WAV+.OT)",invoke=function() PakettiOTExport() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Octatrack:Export to Octatrack (.ot only)",invoke=function() PakettiOTExportOtOnly() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Octatrack:Import Octatrack (.ot)",invoke=function() PakettiOTImport() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Octatrack:Debug Octatrack (.ot)",invoke=function() PakettiOTDebugDialog() end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Octatrack:Generate .ot Drumkit (Smart Mono/Stereo)",invoke=function() PakettiOTDrumkitSmart() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Octatrack:Generate .ot Drumkit (Force Mono)",invoke=function() PakettiOTDrumkitMono() end}
renoise.tool():add_menu_entry{name="--Sample Mappings:Paketti:Octatrack:Set .ot Loop to Slice",invoke=function() PakettiOTSetLoopToSlice() end}


renoise.tool():add_keybinding{name="Sample Editor:Paketti:Export to Octatrack (.WAV+.ot)",invoke=function() PakettiOTExport() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Export to Octatrack (.ot)",invoke=function() PakettiOTExportOtOnly() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Import Octatrack (.ot)",invoke=function() PakettiOTImport() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Debug Octatrack (.ot)",invoke=function() PakettiOTDebugDialog() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Octatrack Generate Drumkit (Smart Mono/Stereo)",invoke=function() PakettiOTDrumkitSmart() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Octatrack Generate Drumkit (Force Mono)",invoke=function() PakettiOTDrumkitMono() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Octatrack Set .ot Loop to Slice",invoke=function() PakettiOTSetLoopToSlice() end}


function PakettiOTExport()
    -- Temporarily disable AutoSamplify monitoring to prevent interference
    local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
    
    -- Check if there's a song
    if not renoise.song() then
        renoise.app():show_status("No song loaded")
        print("PakettiOTExport: No song loaded")
        return
    end
    
    -- Check if there are any instruments
    if not renoise.song().instruments or #renoise.song().instruments == 0 then
        renoise.app():show_status("No instruments in song")
        print("PakettiOTExport: No instruments in song")
        return
    end
    
    -- Check if there's a selected instrument
    if not renoise.song().selected_instrument then
        renoise.app():show_status("No instrument selected")
        print("PakettiOTExport: No instrument selected")
        return
    end
    
    -- Check if the selected instrument has samples
    if not renoise.song().selected_instrument.samples or #renoise.song().selected_instrument.samples == 0 then
        renoise.app():show_status("Selected instrument has no samples")
        print("PakettiOTExport: Selected instrument has no samples")
        return
    end
    
    -- Check if there's a selected sample
    local sample = renoise.song().selected_sample
    if not sample then
        renoise.app():show_status("No sample selected")
        print("PakettiOTExport: No sample selected")
        return
    end
    
    -- Check if the sample has a sample buffer
    if not sample.sample_buffer then
        renoise.app():show_status("Selected sample has no sample buffer")
        print("PakettiOTExport: Selected sample has no sample buffer")
        return
    end
    
    -- Check if the sample buffer has frames
    if not sample.sample_buffer.number_of_frames or sample.sample_buffer.number_of_frames <= 0 then
        renoise.app():show_status("Selected sample has no audio data")
        print("PakettiOTExport: Selected sample has no audio data")
        return
    end
    
    -- Check if slice_markers exists (initialize empty table if nil)
    if not sample.slice_markers then
        sample.slice_markers = {}
        print("PakettiOTExport: No slice markers found, using empty table")
    end
    
    -- Check if sample has a name (provide default if needed)
    if not sample.name or sample.name == "" then
        sample.name = "Unknown Sample"
        print("PakettiOTExport: Sample has no name, using default")
    end
    
    -- Check slice count and warn if over 64 (Octatrack limit)
    local slice_count = sample.slice_markers and #sample.slice_markers or 0
    if slice_count > 64 then
        local result = renoise.app():show_prompt("Slice Limit Warning", 
            "Sample has " .. slice_count .. " slices, but Octatrack only supports 64.\n" ..
            "Only the first 64 slices will be exported.\n\nContinue?", 
            {"Continue", "Cancel"})
        if result == "Cancel" then
            renoise.app():show_status("Export cancelled")
            print("PakettiOTExport: Export cancelled due to slice count")
            return
        end
        print("PakettiOTExport: Warning - Exporting only first 64 of " .. slice_count .. " slices")
    end
    
    -- Check audio format compatibility with Octatrack
    local sample_rate = sample.sample_buffer.sample_rate
    local bit_depth = sample.sample_buffer.bit_depth
    local format_warning = ""
    
    if sample_rate ~= 44100 then
        format_warning = format_warning .. "Sample rate: " .. sample_rate .. "Hz (Octatrack prefers 44.1kHz)\n"
    end
    
    if bit_depth ~= 16 and bit_depth ~= 24 then
        format_warning = format_warning .. "Bit depth: " .. bit_depth .. "-bit (Octatrack supports 16-bit or 24-bit)\n"
    end
    
    if format_warning ~= "" then
        renoise.app():show_status("Converting " .. sample_rate .. "Hz, " .. bit_depth .. "-bit to 44.1kHz, 16-bit for Octatrack compatibility...")
        print("PakettiOTExport: Converting " .. sample_rate .. "Hz, " .. bit_depth .. "-bit to 44.1kHz, 16-bit")
        
        if RenderSampleAtNewRate(44100, 16) then
            renoise.app():show_status("Sample converted to 44.1kHz, 16-bit")
            print("PakettiOTExport: Sample successfully converted to Octatrack format")
            -- Refresh sample reference after conversion
            sample = renoise.song().selected_sample
        else
            renoise.app():show_status("Conversion failed - exporting original format")
            print("PakettiOTExport: Conversion failed, proceeding with original format")
        end
    end
    
    print("PakettiOTExport: All safety checks passed, proceeding with export")
    
    local ot = make_ot_table(sample)
    local filename = renoise.app():prompt_for_filename_to_write("*.wav", "Save sample...")
    
    -- Check if user cancelled the file dialog
    if not filename or filename == "" then
        renoise.app():show_status("Export cancelled")
        print("PakettiOTExport: Export cancelled by user")
        return
    end
    
    -- Create .ot file (metadata only, few KB)
    write_ot_file(filename, ot)
    
    -- Ensure .wav file has .wav extension (audio data)
    local wav_filename = filename
    local base_name = filename:match("(.+)%..+$") or filename
    if not filename:match("%.wav$") then
        wav_filename = base_name .. ".wav"
    end
    
    sample.sample_buffer:save_as(wav_filename, "wav")
    
    -- Show full paths in status message
    local ot_path = base_name .. ".ot"
    renoise.app():show_status("Exported to: " .. ot_path .. " + " .. wav_filename)
    print("PakettiOTExport: Created .ot file: " .. ot_path)
    print("PakettiOTExport: Created .wav file: " .. wav_filename)
end

-- Utility function to copy sample settings
local function copy_sample_settings(from_sample, to_sample)
  to_sample.volume = from_sample.volume
  to_sample.panning = from_sample.panning
  to_sample.transpose = from_sample.transpose
  to_sample.fine_tune = from_sample.fine_tune
  to_sample.beat_sync_enabled = from_sample.beat_sync_enabled
  to_sample.beat_sync_lines = from_sample.beat_sync_lines
  to_sample.beat_sync_mode = from_sample.beat_sync_mode
  to_sample.oneshot = from_sample.oneshot
  to_sample.loop_release = from_sample.loop_release
  to_sample.loop_mode = from_sample.loop_mode
  to_sample.mute_group = from_sample.mute_group
  to_sample.new_note_action = from_sample.new_note_action
  to_sample.autoseek = from_sample.autoseek
  to_sample.autofade = from_sample.autofade
  to_sample.oversample_enabled = from_sample.oversample_enabled
  to_sample.interpolation_mode = from_sample.interpolation_mode
  to_sample.name = from_sample.name
end

-- Utility function to copy slice markers from one sample to another (with sample rate scaling)
local function copy_slice_markers(from_sample, to_sample, sample_rate_ratio)
  -- Clear any existing slice markers in the target sample
  local existing_markers = {}
  for _, marker in ipairs(to_sample.slice_markers) do
    table.insert(existing_markers, marker)
  end
  for _, marker in ipairs(existing_markers) do
    to_sample:delete_slice_marker(marker)
  end
  
  -- Copy slice markers from source sample, scaling positions for new sample rate
  for _, marker_pos in ipairs(from_sample.slice_markers) do
    local new_pos = math.floor(marker_pos * sample_rate_ratio)
    -- Ensure the position is within bounds of the new sample
    if new_pos > 0 and new_pos < to_sample.sample_buffer.number_of_frames then
      local success, error_msg = pcall(function()
        to_sample:insert_slice_marker(new_pos)
      end)
      if not success then
        print("Warning: Could not copy slice marker at position " .. new_pos .. ": " .. tostring(error_msg))
      end
    end
  end
  
  print("Copied " .. #from_sample.slice_markers .. " slice markers to converted sample")
end

-- Function to render the sample at a new sample rate without changing its sound
local function RenderSampleAtNewRate(target_sample_rate, target_bit_depth)
  local song = renoise.song()
  local instrument = song.selected_instrument
  local sample_index = song.selected_sample_index
  local sample = instrument:sample(sample_index)
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    local original_sample_rate = buffer.sample_rate
    local original_frame_count = buffer.number_of_frames
    local ratio = target_sample_rate / original_sample_rate
    local new_frame_count = math.floor(original_frame_count * ratio)
    
    -- Create a new sample with the target rate and bit depth
    local new_sample = instrument:insert_sample_at(sample_index + 1)
    copy_sample_settings(sample, new_sample)
    
    new_sample.sample_buffer:create_sample_data(target_sample_rate, target_bit_depth, buffer.number_of_channels, new_frame_count)
    local new_sample_buffer = new_sample.sample_buffer
    
    new_sample_buffer:prepare_sample_data_changes()
    
    -- Render the original sample into the new sample buffer, adjusting frame count
    for c = 1, buffer.number_of_channels do
      for i = 1, new_frame_count do
        local original_index = math.floor(i / ratio)
        original_index = math.max(1, math.min(original_frame_count, original_index))
        new_sample_buffer:set_sample_data(c, i, buffer:sample_data(c, original_index))
      end
    end
    
    new_sample_buffer:finalize_sample_data_changes()
    
    -- Copy slice markers from original sample to new sample (with scaling)
    copy_slice_markers(sample, new_sample, ratio)
    
    -- Delete the original sample and select the new one
    instrument:delete_sample_at(sample_index)
    song.selected_sample_index = #instrument.samples -- Select the new sample

    print("PakettiOTExport: Sample converted to " .. target_sample_rate .. "Hz, " .. target_bit_depth .. "-bit")
    return true
  else
    print("PakettiOTExport: Sample buffer is either not loaded or has no data")
    
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    
    return false
  end
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

--------------------------------------------------------------------------------
-- Octatrack Drumkit Generation Functions
-- Combines all samples in current instrument into a single sliced drumkit sample
-- Optimized for Octatrack: 64 slices max, 16-bit 44.1kHz, intelligent mono/stereo detection
--------------------------------------------------------------------------------



-- Worker function for ProcessSlicer (Smart version)
function PakettiOTDrumkitSmart_Worker(source_instrument, num_samples)
  local song = renoise.song()
  
  print("-- OT Drumkit Smart: Starting drumkit creation from instrument: " .. source_instrument.name)
  print(string.format("-- OT Drumkit Smart: Will process %d samples (max 64 for Octatrack)", num_samples))
  
  -- Detect if any sample is stereo
  local has_stereo = false
  local stereo_samples = {}
  for i = 1, num_samples do
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data and sample.sample_buffer.number_of_channels == 2 then
      has_stereo = true
      table.insert(stereo_samples, i)
    end
  end
  
  local target_channels = has_stereo and 2 or 1
  print(string.format("-- OT Drumkit Smart: Target format: %s, 44100Hz, 16-bit", target_channels == 2 and "Stereo" or "Mono"))
  
  -- Create new instrument for the drumkit
  local new_instrument_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local drumkit_instrument = song.selected_instrument
  drumkit_instrument.name = "OT Drumkit of " .. source_instrument.name
  
  -- Process samples with progress updates
  local processed_samples = {}
  local processed_count = 0
  local skipped_count = 0
  
  for i = 1, num_samples do
    -- Update progress with better visibility
    local progress_msg = string.format("OT Smart: Processing sample %d/%d...", i, num_samples)
    renoise.app():show_status(progress_msg)
    print(string.format("-- OT Drumkit Smart: Processing sample %d/%d (slot %02d)...", i, num_samples, i))
    
    -- Note: ProcessSlicer cancellation is handled automatically by the framework
    
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data then
      
      -- Create temporary instrument to hold processed sample
      local temp_instrument_index = song.selected_instrument_index + 1
      song:insert_instrument_at(temp_instrument_index)
      song.selected_instrument_index = temp_instrument_index
      local temp_instrument = song.selected_instrument
      
      -- Copy sample to temp instrument
      local temp_sample = temp_instrument:insert_sample_at(1)
      temp_sample.sample_buffer:create_sample_data(
        sample.sample_buffer.sample_rate,
        sample.sample_buffer.bit_depth,
        sample.sample_buffer.number_of_channels,
        sample.sample_buffer.number_of_frames
      )
      temp_sample.sample_buffer:prepare_sample_data_changes()
      
      -- Copy sample data (yield periodically for UI responsiveness)
      for ch = 1, sample.sample_buffer.number_of_channels do
        for frame = 1, sample.sample_buffer.number_of_frames do
          temp_sample.sample_buffer:set_sample_data(ch, frame, sample.sample_buffer:sample_data(ch, frame))
          -- Yield every 1000 frames to maintain UI responsiveness
          if frame % 1000 == 0 then
            coroutine.yield()
          end
        end
      end
      temp_sample.sample_buffer:finalize_sample_data_changes()
      
      -- Remove loops for clean drumkit sounds
      temp_sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
      
      -- Convert to 44.1kHz 16-bit if needed
      local original_rate = temp_sample.sample_buffer.sample_rate
      local original_bit = temp_sample.sample_buffer.bit_depth
      local needs_rate_bit_conversion = (original_rate ~= 44100) or (original_bit ~= 16)
      
      if needs_rate_bit_conversion then
        song.selected_sample_index = 1
        local success = pcall(function()
          local old_sample_count = #temp_instrument.samples
          RenderSampleAtNewRate(44100, 16)
          if #temp_instrument.samples == old_sample_count then
            temp_sample = temp_instrument.samples[1]
          end
        end)
        if not success then
          print(string.format("-- OT Drumkit Smart: Rate/bit conversion failed for slot %02d, using original", i))
        end
      end
      
      -- Store processed sample data (yield periodically)
      local processed_buffer = temp_sample.sample_buffer
      processed_samples[i] = {
        frames = processed_buffer.number_of_frames,
        channels = processed_buffer.number_of_channels,
        data = {}
      }
      
      -- Copy processed data with yielding for UI responsiveness
      for ch = 1, processed_buffer.number_of_channels do
        processed_samples[i].data[ch] = {}
        for frame = 1, processed_buffer.number_of_frames do
          processed_samples[i].data[ch][frame] = processed_buffer:sample_data(ch, frame)
          -- Yield every 500 frames during data copying
          if frame % 500 == 0 then
            coroutine.yield()
          end
        end
      end
      
      processed_count = processed_count + 1
      print(string.format("-- OT Drumkit Smart: Successfully processed slot %02d: %d frames, %d channels", i, processed_samples[i].frames, processed_samples[i].channels))
      
      -- Clean up temp instrument
      song:delete_instrument_at(temp_instrument_index)
      song.selected_instrument_index = new_instrument_index
    else
      skipped_count = skipped_count + 1
      print(string.format("-- OT Drumkit Smart: Skipping slot %02d: no sample data", i))
    end
    
    -- Yield after each sample to maintain UI responsiveness
    coroutine.yield()
  end
  
  -- Calculate total length and create combined sample
  renoise.app():show_status("OT Smart: Creating combined sample...")
  print(string.format("-- OT Drumkit Smart: Processing summary: %d processed, %d skipped", processed_count, skipped_count))
  
  local total_frames = 0
  local slice_positions = {}
  local valid_samples = {}
  
  for i = 1, num_samples do
    if processed_samples[i] then
      table.insert(valid_samples, processed_samples[i])
      table.insert(slice_positions, total_frames + 1)
      total_frames = total_frames + processed_samples[i].frames
    end
  end
  
  -- Create the combined sample buffer
  if drumkit_instrument.samples[1] then
    drumkit_instrument:delete_sample_at(1)
  end
  
  local combined_sample = drumkit_instrument:insert_sample_at(1)
  combined_sample.sample_buffer:create_sample_data(44100, 16, target_channels, total_frames)
  combined_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Copy all processed samples into the combined buffer (with yielding)
  renoise.app():show_status("OT Smart: Combining samples into drumkit...")
  local current_position = 1
  for i = 1, #valid_samples do
    local sample_data = valid_samples[i]
    for frame = 1, sample_data.frames do
      for ch = 1, target_channels do
        local source_value = 0.0
        if sample_data.channels == target_channels then
          source_value = sample_data.data[ch][frame]
        elseif sample_data.channels == 1 and target_channels == 2 then
          source_value = sample_data.data[1][frame]
        elseif sample_data.channels == 2 and target_channels == 1 then
          source_value = (sample_data.data[1][frame] + sample_data.data[2][frame]) / 2
        else
          if sample_data.channels >= 1 then
            source_value = sample_data.data[1][frame]
          else
            source_value = 0.0
          end
        end
        combined_sample.sample_buffer:set_sample_data(ch, current_position + frame - 1, source_value)
      end
      -- Yield every 1000 frames during combination
      if frame % 1000 == 0 then
        coroutine.yield()
      end
    end
    current_position = current_position + sample_data.frames
  end
  
  combined_sample.sample_buffer:finalize_sample_data_changes()
  combined_sample.name = drumkit_instrument.name
  
  -- Insert slice markers
  renoise.app():show_status("OT Smart: Creating slice markers...")
  for i = 1, #slice_positions do
    combined_sample:insert_slice_marker(slice_positions[i])
    -- Yield every 10 slices
    if i % 10 == 0 then
      coroutine.yield()
    end
  end
  
  song.selected_sample_index = 1
  
  renoise.app():show_status(string.format("OT Smart Drumkit created: %d slices, %s", #slice_positions, target_channels == 2 and "Stereo" or "Mono"))
  print("-- OT Drumkit Smart: Drumkit creation completed successfully")
  
  -- Prompt for export
  local export_result = renoise.app():show_prompt("Octatrack Drumkit Created", 
    string.format("Octatrack drumkit created successfully!\n\n• %d slices from %d samples\n• Format: %s, 44.1kHz, 16-bit\n\nExport to Octatrack files (.wav + .ot)?", 
      #slice_positions, num_samples, target_channels == 2 and "Stereo" or "Mono"),
    {"Export", "Keep Only"})
  
  if export_result == "Export" then
    PakettiOTExport()
  end
end

-- Worker function for ProcessSlicer (Mono version)
function PakettiOTDrumkitMono_Worker(source_instrument, num_samples)
  local song = renoise.song()
  
  print("-- OT Drumkit Mono: Starting mono drumkit creation from instrument: " .. source_instrument.name)
  print(string.format("-- OT Drumkit Mono: Will process %d samples (max 64 for Octatrack)", num_samples))
  
  -- Create new instrument for the drumkit
  local new_instrument_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local drumkit_instrument = song.selected_instrument
  drumkit_instrument.name = "OT Mono Drumkit of " .. source_instrument.name
  
  local target_channels = 1  -- Always mono for this version
  print("-- OT Drumkit Mono: Target format: Mono, 44100Hz, 16-bit")
  
  -- Process samples with progress updates
  local processed_samples = {}
  local processed_count = 0
  local skipped_count = 0
  
  for i = 1, num_samples do
    -- Update progress with better visibility
    local progress_msg = string.format("OT Mono: Processing sample %d/%d...", i, num_samples)
    renoise.app():show_status(progress_msg)
    print(string.format("-- OT Drumkit Mono: Processing sample %d/%d (slot %02d)...", i, num_samples, i))
    
    -- Note: ProcessSlicer cancellation is handled automatically by the framework
    
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data then
      
      -- Create temporary instrument to hold processed sample
      local temp_instrument_index = song.selected_instrument_index + 1
      song:insert_instrument_at(temp_instrument_index)
      song.selected_instrument_index = temp_instrument_index
      local temp_instrument = song.selected_instrument
      
      -- Copy sample to temp instrument
      local temp_sample = temp_instrument:insert_sample_at(1)
      temp_sample.sample_buffer:create_sample_data(
        sample.sample_buffer.sample_rate,
        sample.sample_buffer.bit_depth,
        sample.sample_buffer.number_of_channels,
        sample.sample_buffer.number_of_frames
      )
      temp_sample.sample_buffer:prepare_sample_data_changes()
      
      -- Copy sample data (yield periodically for UI responsiveness)
      for ch = 1, sample.sample_buffer.number_of_channels do
        for frame = 1, sample.sample_buffer.number_of_frames do
          temp_sample.sample_buffer:set_sample_data(ch, frame, sample.sample_buffer:sample_data(ch, frame))
          -- Yield every 1000 frames to maintain UI responsiveness
          if frame % 1000 == 0 then
            coroutine.yield()
          end
        end
      end
      temp_sample.sample_buffer:finalize_sample_data_changes()
      
      -- Remove loops for clean drumkit sounds
      temp_sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
      
      -- Convert to mono 44.1kHz 16-bit
      local original_rate = temp_sample.sample_buffer.sample_rate
      local original_bit = temp_sample.sample_buffer.bit_depth
      local original_channels = temp_sample.sample_buffer.number_of_channels
      local needs_conversion = (original_rate ~= 44100) or (original_bit ~= 16) or (original_channels ~= 1)
      
      if needs_conversion then
        song.selected_sample_index = 1
        local success = pcall(function()
          local old_sample_count = #temp_instrument.samples
          RenderSampleAtNewRate(44100, 16)
          if #temp_instrument.samples == old_sample_count then
            temp_sample = temp_instrument.samples[1]
          end
          
          -- Then convert to mono if needed using FAST BULK operations
          if temp_sample.sample_buffer.number_of_channels == 2 then
            -- Fast stereo to mono conversion using chunked operations
            local stereo_buffer = temp_sample.sample_buffer
            local mono_frames = stereo_buffer.number_of_frames
            
            -- Create new mono sample
            local mono_sample = temp_instrument:insert_sample_at(2)
            mono_sample.sample_buffer:create_sample_data(44100, 16, 1, mono_frames)
            mono_sample.sample_buffer:prepare_sample_data_changes()
            
            -- Mix stereo to mono in chunks
            local chunk_size = 10000
            local pos = 1
            while pos <= mono_frames do
              local this_chunk = math.min(chunk_size, mono_frames - pos + 1)
              for frame = 0, this_chunk - 1 do
                local left = stereo_buffer:sample_data(1, pos + frame)
                local right = stereo_buffer:sample_data(2, pos + frame)
                local mono_value = (left + right) / 2
                mono_sample.sample_buffer:set_sample_data(1, pos + frame, mono_value)
              end
              pos = pos + this_chunk
              -- Yield every chunk to keep UI responsive
              coroutine.yield()
            end
            
            mono_sample.sample_buffer:finalize_sample_data_changes()
            
            -- Replace stereo sample with mono sample
            temp_instrument:delete_sample_at(1)
            temp_sample = mono_sample
            song.selected_sample_index = 1
          end
        end)
        
        if not success then
          print(string.format("-- OT Drumkit Mono: Conversion failed for slot %02d, using original", i))
        end
      end
      
      -- Store processed sample data (yield periodically)
      local processed_buffer = temp_sample.sample_buffer
      processed_samples[i] = {
        frames = processed_buffer.number_of_frames,
        channels = processed_buffer.number_of_channels,
        data = {}
      }
      
      -- Copy processed data with yielding for UI responsiveness
      for ch = 1, processed_buffer.number_of_channels do
        processed_samples[i].data[ch] = {}
        for frame = 1, processed_buffer.number_of_frames do
          processed_samples[i].data[ch][frame] = processed_buffer:sample_data(ch, frame)
          -- Yield every 500 frames during data copying
          if frame % 500 == 0 then
            coroutine.yield()
          end
        end
      end
      
      processed_count = processed_count + 1
      print(string.format("-- OT Drumkit Mono: Successfully processed slot %02d: %d frames, %d channels", i, processed_samples[i].frames, processed_samples[i].channels))
      
      -- Clean up temp instrument
      song:delete_instrument_at(temp_instrument_index)
      song.selected_instrument_index = new_instrument_index
    else
      skipped_count = skipped_count + 1
      print(string.format("-- OT Drumkit Mono: Skipping slot %02d: no sample data", i))
    end
    
    -- Yield after each sample to maintain UI responsiveness
    coroutine.yield()
  end
  
  -- Calculate total length and create combined sample
  renoise.app():show_status("OT Mono: Creating combined sample...")
  print(string.format("-- OT Drumkit Mono: Processing summary: %d processed, %d skipped", processed_count, skipped_count))
  
  local total_frames = 0
  local slice_positions = {}
  local valid_samples = {}
  
  for i = 1, num_samples do
    if processed_samples[i] then
      table.insert(valid_samples, processed_samples[i])
      table.insert(slice_positions, total_frames + 1)
      total_frames = total_frames + processed_samples[i].frames
    end
  end
  
  -- Create the combined sample buffer
  if drumkit_instrument.samples[1] then
    drumkit_instrument:delete_sample_at(1)
  end
  
  local combined_sample = drumkit_instrument:insert_sample_at(1)
  combined_sample.sample_buffer:create_sample_data(44100, 16, target_channels, total_frames)
  combined_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Copy all processed samples into the combined buffer (with yielding)
  renoise.app():show_status("OT Mono: Combining samples into drumkit...")
  local current_position = 1
  for i = 1, #valid_samples do
    local sample_data = valid_samples[i]
    for frame = 1, sample_data.frames do
      -- For mono target, always use channel 1 (already converted to mono above)
      local source_value = sample_data.data[1][frame]
      combined_sample.sample_buffer:set_sample_data(1, current_position + frame - 1, source_value)
      -- Yield every 1000 frames during combination
      if frame % 1000 == 0 then
        coroutine.yield()
      end
    end
    current_position = current_position + sample_data.frames
  end
  
  combined_sample.sample_buffer:finalize_sample_data_changes()
  combined_sample.name = drumkit_instrument.name
  
  -- Insert slice markers
  renoise.app():show_status("OT Mono: Creating slice markers...")
  for i = 1, #slice_positions do
    combined_sample:insert_slice_marker(slice_positions[i])
    -- Yield every 10 slices
    if i % 10 == 0 then
      coroutine.yield()
    end
  end
  
  song.selected_sample_index = 1
  
  renoise.app():show_status(string.format("OT Mono: Drumkit created with %d slices", #slice_positions))
  print("-- OT Drumkit Mono: Mono drumkit creation completed successfully")
  
  -- Prompt for export
  local export_result = renoise.app():show_prompt("Octatrack Mono Drumkit Created", 
    string.format("Octatrack mono drumkit created successfully!\n\n• %d slices from %d samples\n• Format: Mono, 44.1kHz, 16-bit\n\nExport to Octatrack files (.wav + .ot)?", 
      #slice_positions, num_samples),
    {"Export", "Keep Only"})
  
  if export_result == "Export" then
    PakettiOTExport()
  end
end

-- Deprecated ProcessSlicer function (now integrated into main functions)
function PakettiOTDrumkitSmart_ProcessSlicer()
  -- Deprecated: Use PakettiOTDrumkitSmart() instead (now includes ProcessSlicer by default)
  PakettiOTDrumkitSmart()
end

-- Smart version - converts to stereo if any sample is stereo, otherwise mono (64 slices max)
function PakettiOTDrumkitSmart()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song = renoise.song()
  local source_instrument = song.selected_instrument
  
  -- Safety checks
  if not source_instrument then
    renoise.app():show_error("No instrument selected")
    return
  end
  
  if #source_instrument.samples == 0 then
    renoise.app():show_error("Selected instrument has no samples")
    return
  end
  
  if #source_instrument.samples[1].slice_markers > 0 then
    renoise.app():show_error("Cannot create drumkit from sliced instrument.\nPlease select an instrument with individual samples in separate slots.")
    return
  end
  
  -- Determine how many samples to process (max 64 for Octatrack)
  local num_samples = math.min(64, #source_instrument.samples)
  
  -- Warn if there are more than 64 samples
  if #source_instrument.samples > 64 then
    local result = renoise.app():show_prompt("Octatrack Slice Limit", 
        "Instrument has " .. #source_instrument.samples .. " samples, but Octatrack only supports 64 slices.\n" ..
        "Only the first 64 samples will be processed.\n\nContinue?", 
        {"Continue", "Cancel"})
    if result == "Cancel" then
      renoise.app():show_status("Drumkit creation cancelled")
      return
    end
  end
  
  local dialog, vb
  
  -- Create ProcessSlicer with worker function that has access to dialog and vb
  local process_slicer = ProcessSlicer(function()
    PakettiOTDrumkitSmart_Worker_Efficient(source_instrument, num_samples, dialog, vb)
  end)
  
  dialog, vb = process_slicer:create_dialog("Creating Octatrack Drumkit...")
  process_slicer:start()
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Efficient worker function for ProcessSlicer (Smart version) - yields every 20 samples
function PakettiOTDrumkitSmart_Worker_Efficient(source_instrument, num_samples, dialog, vb)
  local song = renoise.song()
  
  print("-- OT Drumkit Smart: Starting drumkit creation from instrument: " .. source_instrument.name)
  print(string.format("-- OT Drumkit Smart: Will process %d samples (max 64 for Octatrack)", num_samples))
  
  -- Detect if any sample is stereo
  local has_stereo = false
  local stereo_samples = {}
  for i = 1, num_samples do
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data and sample.sample_buffer.number_of_channels == 2 then
      has_stereo = true
      table.insert(stereo_samples, i)
    end
  end
  
  local target_channels = has_stereo and 2 or 1
  print(string.format("-- OT Drumkit Smart: Target format: %s, 44100Hz, 16-bit", target_channels == 2 and "Stereo" or "Mono"))
  
  -- Create new instrument for the drumkit
  local new_instrument_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local drumkit_instrument = song.selected_instrument
  drumkit_instrument.name = "OT Drumkit of " .. source_instrument.name
  
  -- Process samples with progress updates
  local processed_samples = {}
  local processed_count = 0
  local skipped_count = 0
  
  for i = 1, num_samples do
    -- Update progress dialog and status
    if dialog and dialog.visible then
      vb.views.progress_text.text = string.format("Processing sample %d/%d...", i, num_samples)
    end
    local progress_msg = string.format("OT Smart: Processing sample %d/%d...", i, num_samples)
    renoise.app():show_status(progress_msg)
    print(string.format("-- OT Drumkit Smart: Processing sample %d/%d (slot %02d)...", i, num_samples, i))
    
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data then
      
      -- Create temporary instrument to hold processed sample
      local temp_instrument_index = song.selected_instrument_index + 1
      song:insert_instrument_at(temp_instrument_index)
      song.selected_instrument_index = temp_instrument_index
      local temp_instrument = song.selected_instrument
      
      -- Copy sample to temp instrument
      local temp_sample = temp_instrument:insert_sample_at(1)
      temp_sample.sample_buffer:create_sample_data(
        sample.sample_buffer.sample_rate,
        sample.sample_buffer.bit_depth,
        sample.sample_buffer.number_of_channels,
        sample.sample_buffer.number_of_frames
      )
      temp_sample.sample_buffer:prepare_sample_data_changes()
      
      -- Copy sample data in efficient chunks
      for ch = 1, sample.sample_buffer.number_of_channels do
        local chunk_size = 10000
        local total_frames = sample.sample_buffer.number_of_frames
        local pos = 1
        while pos <= total_frames do
          local this_chunk = math.min(chunk_size, total_frames - pos + 1)
          for frame = 0, this_chunk - 1 do
            temp_sample.sample_buffer:set_sample_data(ch, pos + frame, sample.sample_buffer:sample_data(ch, pos + frame))
          end
          pos = pos + this_chunk
          -- Yield every chunk to keep UI responsive
          coroutine.yield()
        end
      end
      temp_sample.sample_buffer:finalize_sample_data_changes()
      
      -- Remove loops for clean drumkit sounds
      temp_sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
      
      -- Convert to 44.1kHz 16-bit if needed
      local original_rate = temp_sample.sample_buffer.sample_rate
      local original_bit = temp_sample.sample_buffer.bit_depth
      local needs_rate_bit_conversion = (original_rate ~= 44100) or (original_bit ~= 16)
      
      if needs_rate_bit_conversion then
        song.selected_sample_index = 1
        local success = pcall(function()
          local old_sample_count = #temp_instrument.samples
          RenderSampleAtNewRate(44100, 16)
          if #temp_instrument.samples == old_sample_count then
            temp_sample = temp_instrument.samples[1]
          end
        end)
        if not success then
          print(string.format("-- OT Drumkit Smart: Rate/bit conversion failed for slot %02d, using original", i))
        end
      end
      
      -- Store processed sample data
      local processed_buffer = temp_sample.sample_buffer
      processed_samples[i] = {
        frames = processed_buffer.number_of_frames,
        channels = processed_buffer.number_of_channels,
        data = {}
      }
      
      -- Copy processed data
      for ch = 1, processed_buffer.number_of_channels do
        processed_samples[i].data[ch] = {}
        for frame = 1, processed_buffer.number_of_frames do
          processed_samples[i].data[ch][frame] = processed_buffer:sample_data(ch, frame)
        end
      end
      
      processed_count = processed_count + 1
      print(string.format("-- OT Drumkit Smart: Successfully processed slot %02d: %d frames, %d channels", i, processed_samples[i].frames, processed_samples[i].channels))
      
      -- Clean up temp instrument
      song:delete_instrument_at(temp_instrument_index)
      song.selected_instrument_index = new_instrument_index
    else
      skipped_count = skipped_count + 1
      print(string.format("-- OT Drumkit Smart: Skipping slot %02d: no sample data", i))
    end
    
    -- Yield every 20 samples to keep UI responsive but still efficient
    if i % 20 == 0 then
      coroutine.yield()
    end
  end
  
  -- Calculate total length and create combined sample
  renoise.app():show_status("OT Smart: Creating combined sample...")
  print(string.format("-- OT Drumkit Smart: Processing summary: %d processed, %d skipped", processed_count, skipped_count))
  
  local total_frames = 0
  local slice_positions = {}
  local valid_samples = {}
  
  for i = 1, num_samples do
    if processed_samples[i] then
      table.insert(valid_samples, processed_samples[i])
      table.insert(slice_positions, total_frames + 1)
      total_frames = total_frames + processed_samples[i].frames
    end
  end
  
  -- Create the combined sample buffer
  if drumkit_instrument.samples[1] then
    drumkit_instrument:delete_sample_at(1)
  end
  
  local combined_sample = drumkit_instrument:insert_sample_at(1)
  combined_sample.sample_buffer:create_sample_data(44100, 16, target_channels, total_frames)
  combined_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Copy all processed samples into the combined buffer using FAST BULK operations
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Combining samples into drumkit..."
  end
  renoise.app():show_status("OT Smart: Fast bulk combining samples...")
  local start_time = os.clock()
  
  local current_position = 1
  for i = 1, #valid_samples do
    local sample_data = valid_samples[i]
    print(string.format("-- OT Drumkit Smart: Fast bulk combining sample %d/%d (%d frames)", i, #valid_samples, sample_data.frames))
    
    -- Copy frames in chunks of 10000 for efficiency
    local chunk_size = 10000
    local frames_to_copy = sample_data.frames
    local source_pos = 1
    local dest_pos = current_position
    
    while frames_to_copy > 0 do
      local this_chunk = math.min(chunk_size, frames_to_copy)
      
      -- Copy chunk data for all target channels
      for frame = 0, this_chunk - 1 do
        for ch = 1, target_channels do
          local source_value = 0.0
          if sample_data.channels == target_channels then
            source_value = sample_data.data[ch][source_pos + frame]
          elseif sample_data.channels == 1 and target_channels == 2 then
            source_value = sample_data.data[1][source_pos + frame]
          elseif sample_data.channels == 2 and target_channels == 1 then
            source_value = (sample_data.data[1][source_pos + frame] + sample_data.data[2][source_pos + frame]) / 2
          else
            if sample_data.channels >= 1 then
              source_value = sample_data.data[1][source_pos + frame]
            else
              source_value = 0.0
            end
          end
          combined_sample.sample_buffer:set_sample_data(ch, dest_pos + frame - 1, source_value)
        end
      end
      
      source_pos = source_pos + this_chunk
      dest_pos = dest_pos + this_chunk
      frames_to_copy = frames_to_copy - this_chunk
      
      -- Yield every chunk to keep UI responsive
      coroutine.yield()
    end
    
    current_position = current_position + sample_data.frames
    print(string.format("-- OT Drumkit Smart: Sample %d combined successfully", i))
  end
  
  local end_time = os.clock()
  print(string.format("-- OT Drumkit Smart: FAST bulk combining completed in %.2f seconds", end_time - start_time))
  
  combined_sample.sample_buffer:finalize_sample_data_changes()
  combined_sample.name = drumkit_instrument.name
  
  -- Insert slice markers
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Creating slice markers..."
  end
  renoise.app():show_status("OT Smart: Creating slice markers...")
  for i = 1, #slice_positions do
    combined_sample:insert_slice_marker(slice_positions[i])
  end
  
  song.selected_sample_index = 1
  
  -- Close dialog
  if dialog and dialog.visible then
    dialog:close()
  end
  
  renoise.app():show_status(string.format("OT Smart: Drumkit completed - %d slices, %s", #slice_positions, target_channels == 2 and "Stereo" or "Mono"))
  print("-- OT Drumkit Smart: Drumkit creation completed successfully")
  
  -- Show export dialog
  local export_result = renoise.app():show_prompt("Octatrack Drumkit Created", 
    string.format("Octatrack drumkit created successfully!\n\n• %d slices\n• Format: %s, 44.1kHz, 16-bit\n\nExport to Octatrack files (.wav + .ot)?", 
      #slice_positions, target_channels == 2 and "Stereo" or "Mono"),
    {"Export", "Keep Only"})
  
  if export_result == "Export" then
    PakettiOTExport()
  end
end

-- Efficient worker function for ProcessSlicer (Mono version) - yields every 20 samples
function PakettiOTDrumkitMono_Worker_Efficient(source_instrument, num_samples, dialog, vb)
  local song = renoise.song()
  
  print("-- OT Drumkit Mono: Starting mono drumkit creation from instrument: " .. source_instrument.name)
  print(string.format("-- OT Drumkit Mono: Will process %d samples (max 64 for Octatrack)", num_samples))
  
  -- Create new instrument for the drumkit
  local new_instrument_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local drumkit_instrument = song.selected_instrument
  drumkit_instrument.name = "OT Mono Drumkit of " .. source_instrument.name
  
  local target_channels = 1  -- Always mono for this version
  print("-- OT Drumkit Mono: Target format: Mono, 44100Hz, 16-bit")
  
  -- Process samples with progress updates
  local processed_samples = {}
  local processed_count = 0
  local skipped_count = 0
  
  for i = 1, num_samples do
    -- Update progress dialog and status
    if dialog and dialog.visible then
      vb.views.progress_text.text = string.format("Processing sample %d/%d...", i, num_samples)
    end
    local progress_msg = string.format("OT Mono: Processing sample %d/%d...", i, num_samples)
    renoise.app():show_status(progress_msg)
    print(string.format("-- OT Drumkit Mono: Processing sample %d/%d (slot %02d)...", i, num_samples, i))
    
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data then
      
      -- Create temporary instrument to hold processed sample
      local temp_instrument_index = song.selected_instrument_index + 1
      song:insert_instrument_at(temp_instrument_index)
      song.selected_instrument_index = temp_instrument_index
      local temp_instrument = song.selected_instrument
      
      -- Copy sample to temp instrument
      local temp_sample = temp_instrument:insert_sample_at(1)
      temp_sample.sample_buffer:create_sample_data(
        sample.sample_buffer.sample_rate,
        sample.sample_buffer.bit_depth,
        sample.sample_buffer.number_of_channels,
        sample.sample_buffer.number_of_frames
      )
      temp_sample.sample_buffer:prepare_sample_data_changes()
      
      -- Copy sample data
      for ch = 1, sample.sample_buffer.number_of_channels do
        for frame = 1, sample.sample_buffer.number_of_frames do
          temp_sample.sample_buffer:set_sample_data(ch, frame, sample.sample_buffer:sample_data(ch, frame))
        end
      end
      temp_sample.sample_buffer:finalize_sample_data_changes()
      
      -- Remove loops for clean drumkit sounds
      temp_sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
      
      -- Convert to mono 44.1kHz 16-bit
      local original_rate = temp_sample.sample_buffer.sample_rate
      local original_bit = temp_sample.sample_buffer.bit_depth
      local original_channels = temp_sample.sample_buffer.number_of_channels
      local needs_conversion = (original_rate ~= 44100) or (original_bit ~= 16) or (original_channels ~= 1)
      
      if needs_conversion then
        song.selected_sample_index = 1
        local success = pcall(function()
          local old_sample_count = #temp_instrument.samples
          RenderSampleAtNewRate(44100, 16)
          if #temp_instrument.samples == old_sample_count then
            temp_sample = temp_instrument.samples[1]
          end
          
          -- Then convert to mono if needed
          if temp_sample.sample_buffer.number_of_channels == 2 then
            -- Manual stereo to mono conversion
            local stereo_buffer = temp_sample.sample_buffer
            local mono_frames = stereo_buffer.number_of_frames
            
            -- Create new mono sample
            local mono_sample = temp_instrument:insert_sample_at(2)
            mono_sample.sample_buffer:create_sample_data(44100, 16, 1, mono_frames)
            mono_sample.sample_buffer:prepare_sample_data_changes()
            
            -- Mix stereo to mono
            for frame = 1, mono_frames do
              local left = stereo_buffer:sample_data(1, frame)
              local right = stereo_buffer:sample_data(2, frame)
              local mono_value = (left + right) / 2
              mono_sample.sample_buffer:set_sample_data(1, frame, mono_value)
            end
            
            mono_sample.sample_buffer:finalize_sample_data_changes()
            
            -- Replace stereo sample with mono sample
            temp_instrument:delete_sample_at(1)
            temp_sample = mono_sample
            song.selected_sample_index = 1
          end
        end)
        
        if not success then
          print(string.format("-- OT Drumkit Mono: Conversion failed for slot %02d, using original", i))
        end
      end
      
      -- Store processed sample data
      local processed_buffer = temp_sample.sample_buffer
      processed_samples[i] = {
        frames = processed_buffer.number_of_frames,
        channels = processed_buffer.number_of_channels,
        data = {}
      }
      
      -- Copy processed data
      for ch = 1, processed_buffer.number_of_channels do
        processed_samples[i].data[ch] = {}
        for frame = 1, processed_buffer.number_of_frames do
          processed_samples[i].data[ch][frame] = processed_buffer:sample_data(ch, frame)
        end
      end
      
      processed_count = processed_count + 1
      print(string.format("-- OT Drumkit Mono: Successfully processed slot %02d: %d frames, %d channels", i, processed_samples[i].frames, processed_samples[i].channels))
      
      -- Clean up temp instrument
      song:delete_instrument_at(temp_instrument_index)
      song.selected_instrument_index = new_instrument_index
    else
      skipped_count = skipped_count + 1
      print(string.format("-- OT Drumkit Mono: Skipping slot %02d: no sample data", i))
    end
    
    -- Yield every 20 samples to keep UI responsive but still efficient
    if i % 20 == 0 then
      coroutine.yield()
    end
  end
  
  -- Calculate total length and create combined sample
  renoise.app():show_status("OT Mono: Creating combined sample...")
  print(string.format("-- OT Drumkit Mono: Processing summary: %d processed, %d skipped", processed_count, skipped_count))
  
  local total_frames = 0
  local slice_positions = {}
  local valid_samples = {}
  
  for i = 1, num_samples do
    if processed_samples[i] then
      table.insert(valid_samples, processed_samples[i])
      table.insert(slice_positions, total_frames + 1)
      total_frames = total_frames + processed_samples[i].frames
    end
  end
  
  -- Create the combined sample buffer
  if drumkit_instrument.samples[1] then
    drumkit_instrument:delete_sample_at(1)
  end
  
  local combined_sample = drumkit_instrument:insert_sample_at(1)
  combined_sample.sample_buffer:create_sample_data(44100, 16, target_channels, total_frames)
  combined_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Copy all processed samples into the combined buffer using FAST BULK operations
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Combining samples into drumkit..."
  end
  renoise.app():show_status("OT Mono: Fast bulk combining samples...")
  local start_time = os.clock()
  
  local current_position = 1
  for i = 1, #valid_samples do
    local sample_data = valid_samples[i]
    print(string.format("-- OT Drumkit Mono: Fast bulk combining sample %d/%d (%d frames)", i, #valid_samples, sample_data.frames))
    
    -- Copy frames in chunks of 10000 for efficiency
    local chunk_size = 10000
    local frames_to_copy = sample_data.frames
    local source_pos = 1
    local dest_pos = current_position
    
    while frames_to_copy > 0 do
      local this_chunk = math.min(chunk_size, frames_to_copy)
      
      -- Copy chunk data for mono channel
      for frame = 0, this_chunk - 1 do
        -- For mono target, always use channel 1 (already converted to mono above)
        local source_value = sample_data.data[1][source_pos + frame]
        combined_sample.sample_buffer:set_sample_data(1, dest_pos + frame - 1, source_value)
      end
      
      source_pos = source_pos + this_chunk
      dest_pos = dest_pos + this_chunk
      frames_to_copy = frames_to_copy - this_chunk
      
      -- Yield every chunk to keep UI responsive
      coroutine.yield()
    end
    
    current_position = current_position + sample_data.frames
    print(string.format("-- OT Drumkit Mono: Sample %d combined successfully", i))
  end
  
  local end_time = os.clock()
  print(string.format("-- OT Drumkit Mono: FAST bulk combining completed in %.2f seconds", end_time - start_time))
  
  combined_sample.sample_buffer:finalize_sample_data_changes()
  combined_sample.name = drumkit_instrument.name
  
  -- Insert slice markers
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Creating slice markers..."
  end
  renoise.app():show_status("OT Mono: Creating slice markers...")
  for i = 1, #slice_positions do
    combined_sample:insert_slice_marker(slice_positions[i])
  end
  
  song.selected_sample_index = 1
  
  -- Close dialog
  if dialog and dialog.visible then
    dialog:close()
  end
  
  renoise.app():show_status(string.format("OT Mono: Drumkit completed - %d slices", #slice_positions))
  print("-- OT Drumkit Mono: Mono drumkit creation completed successfully")
  
  -- Show export dialog
  local export_result = renoise.app():show_prompt("Octatrack Mono Drumkit Created", 
    string.format("Octatrack mono drumkit created successfully!\n\n• %d slices\n• Format: Mono, 44.1kHz, 16-bit\n\nExport to Octatrack files (.wav + .ot)?", 
      #slice_positions),
    {"Export", "Keep Only"})
  
  if export_result == "Export" then
    PakettiOTExport()
  end
end

-- Legacy Smart version without ProcessSlicer (keeping for reference)
function PakettiOTDrumkitSmart_Legacy()
  local song = renoise.song()
  local source_instrument = song.selected_instrument
  
  -- Safety check: ensure we have an instrument
  if not source_instrument then
    renoise.app():show_error("No instrument selected")
    return
  end
  
  -- Safety check: ensure we have samples
  if #source_instrument.samples == 0 then
    renoise.app():show_error("Selected instrument has no samples")
    return
  end
  
  -- Safety check: abort if first sample has slices (indicates sliced instrument)
  if #source_instrument.samples[1].slice_markers > 0 then
    renoise.app():show_error("Cannot create drumkit from sliced instrument.\nPlease select an instrument with individual samples in separate slots.")
    return
  end
  
  print("-- OT Drumkit Smart: Starting drumkit creation from instrument: " .. source_instrument.name)
  
  -- Determine how many samples to process (max 64 for Octatrack)
  local num_samples = math.min(64, #source_instrument.samples)
  print(string.format("-- OT Drumkit Smart: Source instrument has %d total samples", #source_instrument.samples))
  print(string.format("-- OT Drumkit Smart: Will process %d samples (max 64 for Octatrack)", num_samples))
  
  -- Warn if there are more than 64 samples
  if #source_instrument.samples > 64 then
    local result = renoise.app():show_prompt("Octatrack Slice Limit", 
        "Instrument has " .. #source_instrument.samples .. " samples, but Octatrack only supports 64 slices.\n" ..
        "Only the first 64 samples will be processed.\n\nContinue?", 
        {"Continue", "Cancel"})
    if result == "Cancel" then
      renoise.app():show_status("Drumkit creation cancelled")
      return
    end
  end
  
  -- Debug: List all sample slots and their status with names
  print("-- OT Drumkit Smart: Sample Analysis:")
  for i = 1, num_samples do
    local sample = source_instrument.samples[i]
    if sample then
      if sample.sample_buffer.has_sample_data then
        print(string.format("-- OT Drumkit Smart: Slot %02d: '%s' - %d frames, %d channels, %.1fkHz, %dbit", 
          i, sample.name or "Unnamed", sample.sample_buffer.number_of_frames, sample.sample_buffer.number_of_channels, 
          sample.sample_buffer.sample_rate, sample.sample_buffer.bit_depth))
      else
        print(string.format("-- OT Drumkit Smart: Slot %02d: '%s' - EMPTY (no sample data)", i, sample.name or "Unnamed"))
      end
    else
      print(string.format("-- OT Drumkit Smart: Slot %02d: NULL - no sample object", i))
    end
  end
  
  -- Create new instrument for the drumkit
  local new_instrument_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local drumkit_instrument = song.selected_instrument
  
  -- Set drumkit instrument name
  drumkit_instrument.name = "OT Drumkit of " .. source_instrument.name
  print("-- OT Drumkit Smart: Created new instrument: " .. drumkit_instrument.name)
  
  -- Create working copies of samples and normalize them
  local processed_samples = {}
  local has_stereo = false
  
  -- First pass: detect if any sample is stereo
  local stereo_samples = {}
  for i = 1, num_samples do
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data and sample.sample_buffer.number_of_channels == 2 then
      has_stereo = true
      table.insert(stereo_samples, i)
    end
  end
  
  local target_channels = has_stereo and 2 or 1
  print(string.format("-- OT Drumkit Smart: Target format: %s, 44100Hz, 16-bit", target_channels == 2 and "Stereo" or "Mono"))
  if #stereo_samples > 0 then
    print(string.format("-- OT Drumkit Smart: Found stereo samples in slots: %s", table.concat(stereo_samples, ", ")))
  end
  
  -- Second pass: process and normalize all samples
  local processed_count = 0
  local skipped_count = 0
  
  for i = 1, num_samples do
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data then
      -- Update status with clear X/Y progress
      renoise.app():show_status(string.format("OT Smart: Processing sample %d/%d...", i, num_samples))
      print(string.format("-- OT Drumkit Smart: Processing slot %02d/%02d...", i, num_samples))
      
      -- Create temporary instrument to hold processed sample
      local temp_instrument_index = song.selected_instrument_index + 1
      song:insert_instrument_at(temp_instrument_index)
      song.selected_instrument_index = temp_instrument_index
      local temp_instrument = song.selected_instrument
      
      -- Copy sample to temp instrument
      local temp_sample = temp_instrument:insert_sample_at(1)
      temp_sample.sample_buffer:create_sample_data(
        sample.sample_buffer.sample_rate,
        sample.sample_buffer.bit_depth,
        sample.sample_buffer.number_of_channels,
        sample.sample_buffer.number_of_frames
      )
      temp_sample.sample_buffer:prepare_sample_data_changes()
      
      -- Copy sample data
      for ch = 1, sample.sample_buffer.number_of_channels do
        for frame = 1, sample.sample_buffer.number_of_frames do
          temp_sample.sample_buffer:set_sample_data(ch, frame, sample.sample_buffer:sample_data(ch, frame))
        end
      end
      temp_sample.sample_buffer:finalize_sample_data_changes()
      
      -- Remove loops for clean drumkit sounds
      temp_sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
      
      local original_rate = temp_sample.sample_buffer.sample_rate
      local original_bit = temp_sample.sample_buffer.bit_depth
      local original_channels = temp_sample.sample_buffer.number_of_channels
      
      print(string.format("-- OT Drumkit Smart: Processing slot %02d '%s': %d frames, %d channels, %.1fkHz, %dbit", 
        i, sample.name or "Unnamed", temp_sample.sample_buffer.number_of_frames, original_channels, 
        original_rate, original_bit))
      
      -- Convert to 44.1kHz 16-bit if needed
      local needs_rate_bit_conversion = (original_rate ~= 44100) or (original_bit ~= 16)
      
      if needs_rate_bit_conversion then
        print(string.format("-- OT Drumkit Smart: Converting slot %02d: %.1fkHz/%dbit → 44.1kHz/16bit (keeping %d channels)", 
          i, original_rate, original_bit, original_channels))
        song.selected_sample_index = 1
        
        -- Use RenderSampleAtNewRate for precise conversion
        local success = pcall(function()
          local old_sample_count = #temp_instrument.samples
          RenderSampleAtNewRate(44100, 16)
          -- After conversion, we should still have one sample (the converted one)
          if #temp_instrument.samples == old_sample_count then
            temp_sample = temp_instrument.samples[1]
          end
        end)
        
        if not success then
          print(string.format("-- OT Drumkit Smart: Rate/bit conversion failed for slot %02d, using original", i))
        else
          print(string.format("-- OT Drumkit Smart: After rate/bit conversion - slot %02d: %d frames, %d channels, %.1fkHz, %dbit", 
            i, temp_sample.sample_buffer.number_of_frames, temp_sample.sample_buffer.number_of_channels, 
            temp_sample.sample_buffer.sample_rate, temp_sample.sample_buffer.bit_depth))
        end
      else
        print(string.format("-- OT Drumkit Smart: No rate/bit conversion needed for slot %02d (already 44.1kHz/16bit)", i))
      end
      
      -- Store processed sample data
      local processed_buffer = temp_sample.sample_buffer
      processed_samples[i] = {
        frames = processed_buffer.number_of_frames,
        channels = processed_buffer.number_of_channels,
        data = {}
      }
      
      -- Copy processed data
      for ch = 1, processed_buffer.number_of_channels do
        processed_samples[i].data[ch] = {}
        for frame = 1, processed_buffer.number_of_frames do
          processed_samples[i].data[ch][frame] = processed_buffer:sample_data(ch, frame)
        end
      end
      
      processed_count = processed_count + 1
      print(string.format("-- OT Drumkit Smart: Successfully processed slot %02d: %d frames, %d channels", i, processed_samples[i].frames, processed_samples[i].channels))
      
      -- Clean up temp instrument
      song:delete_instrument_at(temp_instrument_index)
      song.selected_instrument_index = new_instrument_index
    else
      skipped_count = skipped_count + 1
      if sample then
        print(string.format("-- OT Drumkit Smart: Skipping slot %02d: no sample data", i))
      else
        print(string.format("-- OT Drumkit Smart: Skipping slot %02d: no sample object", i))
      end
    end
    

  end
  
  print(string.format("-- OT Drumkit Smart: Processing summary: %d processed, %d skipped", processed_count, skipped_count))
  
  -- Calculate total length for combined sample
  renoise.app():show_status("OT Smart: Creating combined sample...")
  local total_frames = 0
  local slice_positions = {}
  local valid_samples = {}
  
  -- Build array of only valid samples and calculate positions
  for i = 1, num_samples do
    if processed_samples[i] then
      table.insert(valid_samples, processed_samples[i])
      table.insert(slice_positions, total_frames + 1)  -- Slice at start of each sample (1-based)
      total_frames = total_frames + processed_samples[i].frames
    end
  end
  
  print(string.format("-- OT Drumkit Smart: Total combined length: %d frames (%.2f seconds)", total_frames, total_frames / 44100.0))
  print(string.format("-- OT Drumkit Smart: Will create %d slices", #slice_positions))
  
  -- Debug: Show slice positions
  for i = 1, math.min(10, #slice_positions) do
    local slice_time = (slice_positions[i] - 1) / 44100.0
    print(string.format("-- OT Drumkit Smart: Slice %02d at frame %d (%.3fs)", i, slice_positions[i], slice_time))
  end
  if #slice_positions > 10 then
    print(string.format("-- OT Drumkit Smart: ... and %d more slices", #slice_positions - 10))
  end
  
  -- Create the combined sample buffer
  if drumkit_instrument.samples[1] then
    drumkit_instrument:delete_sample_at(1)  -- Remove default empty sample
  end
  
  local combined_sample = drumkit_instrument:insert_sample_at(1)
  combined_sample.sample_buffer:create_sample_data(44100, 16, target_channels, total_frames)
  combined_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Copy all processed samples into the combined buffer using FAST BULK operations
  local start_time = os.clock()
  local current_position = 1
  for i = 1, #valid_samples do
    local sample_data = valid_samples[i]
    print(string.format("-- OT Drumkit Smart Legacy: Fast bulk combining sample %d/%d (%d frames)", i, #valid_samples, sample_data.frames))
    
    -- Copy frames in chunks of 10000 for efficiency
    local chunk_size = 10000
    local frames_to_copy = sample_data.frames
    local source_pos = 1
    local dest_pos = current_position
    
    while frames_to_copy > 0 do
      local this_chunk = math.min(chunk_size, frames_to_copy)
      
      -- Copy chunk data for all target channels
      for frame = 0, this_chunk - 1 do
        for ch = 1, target_channels do
          local source_value = 0.0
          if sample_data.channels == target_channels then
            -- Same channel count: direct copy
            source_value = sample_data.data[ch][source_pos + frame]
          elseif sample_data.channels == 1 and target_channels == 2 then
            -- Mono to stereo: copy mono data to both channels
            source_value = sample_data.data[1][source_pos + frame]
          elseif sample_data.channels == 2 and target_channels == 1 then
            -- Stereo to mono: mix both channels
            source_value = (sample_data.data[1][source_pos + frame] + sample_data.data[2][source_pos + frame]) / 2
          else
            -- Fallback: use channel 1 or zero
            if sample_data.channels >= 1 then
              source_value = sample_data.data[1][source_pos + frame]
            else
              source_value = 0.0
            end
          end
          combined_sample.sample_buffer:set_sample_data(ch, dest_pos + frame - 1, source_value)
        end
      end
      
      source_pos = source_pos + this_chunk
      dest_pos = dest_pos + this_chunk
      frames_to_copy = frames_to_copy - this_chunk
    end
    
    current_position = current_position + sample_data.frames
    print(string.format("-- OT Drumkit Smart Legacy: Sample %d combined successfully", i))
  end
  
  local end_time = os.clock()
  print(string.format("-- OT Drumkit Smart Legacy: FAST bulk combining completed in %.2f seconds", end_time - start_time))
  
  combined_sample.sample_buffer:finalize_sample_data_changes()
  
  -- Set sample name
  combined_sample.name = drumkit_instrument.name
  
  -- Insert slice markers
  renoise.app():show_status("OT Smart: Creating slice markers...")
  for i = 1, #slice_positions do
    combined_sample:insert_slice_marker(slice_positions[i])
  end
  
  -- Select the combined sample
  song.selected_sample_index = 1
  
  renoise.app():show_status(string.format("OT Drumkit created: %d slices, %s", #slice_positions, target_channels == 2 and "Stereo" or "Mono"))
  print("-- OT Drumkit Smart: Drumkit creation completed successfully")
  
  -- Prompt for export
  local export_result = renoise.app():show_prompt("Octatrack Drumkit Created", 
    string.format("Octatrack drumkit created successfully!\n\n• %d slices from %d samples\n• Format: %s, 44.1kHz, 16-bit\n\nExport to Octatrack files (.wav + .ot)?", 
      #slice_positions, num_samples, target_channels == 2 and "Stereo" or "Mono"),
    {"Export", "Keep Only"})
  
  if export_result == "Export" then
    PakettiOTExport()
  end
end

-- Mono version - converts all samples to mono (64 slices max)  
function PakettiOTDrumkitMono()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song = renoise.song()
  local source_instrument = song.selected_instrument
  
  -- Safety checks
  if not source_instrument then
    renoise.app():show_error("No instrument selected")
    return
  end
  
  if #source_instrument.samples == 0 then
    renoise.app():show_error("Selected instrument has no samples")
    return
  end
  
  if #source_instrument.samples[1].slice_markers > 0 then
    renoise.app():show_error("Cannot create drumkit from sliced instrument.\nPlease select an instrument with individual samples in separate slots.")
    return
  end
  
  -- Determine how many samples to process (max 64 for Octatrack)
  local num_samples = math.min(64, #source_instrument.samples)
  
  -- Warn if there are more than 64 samples
  if #source_instrument.samples > 64 then
    local result = renoise.app():show_prompt("Octatrack Slice Limit", 
        "Instrument has " .. #source_instrument.samples .. " samples, but Octatrack only supports 64 slices.\n" ..
        "Only the first 64 samples will be processed.\n\nContinue?", 
        {"Continue", "Cancel"})
    if result == "Cancel" then
      renoise.app():show_status("Drumkit creation cancelled")
      return
    end
  end
  
  local dialog, vb
  
  -- Create ProcessSlicer with worker function that has access to dialog and vb
  local process_slicer = ProcessSlicer(function()
    PakettiOTDrumkitMono_Worker_Efficient(source_instrument, num_samples, dialog, vb)
  end)
  
  dialog, vb = process_slicer:create_dialog("Creating Octatrack Mono Drumkit...")
  process_slicer:start()
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Legacy Mono version without ProcessSlicer (keeping for reference)  
function PakettiOTDrumkitMono_Legacy()
  local song = renoise.song()
  local source_instrument = song.selected_instrument
  
  -- Safety check: ensure we have an instrument
  if not source_instrument then
    renoise.app():show_error("No instrument selected")
    return
  end
  
  -- Safety check: ensure we have samples
  if #source_instrument.samples == 0 then
    renoise.app():show_error("Selected instrument has no samples")
    return
  end
  
  -- Safety check: abort if first sample has slices (indicates sliced instrument)
  if #source_instrument.samples[1].slice_markers > 0 then
    renoise.app():show_error("Cannot create drumkit from sliced instrument.\nPlease select an instrument with individual samples in separate slots.")
    return
  end
  
  print("-- OT Drumkit Mono: Starting mono drumkit creation from instrument: " .. source_instrument.name)
  
  -- Determine how many samples to process (max 64 for Octatrack)
  local num_samples = math.min(64, #source_instrument.samples)
  print(string.format("-- OT Drumkit Mono: Source instrument has %d total samples", #source_instrument.samples))
  print(string.format("-- OT Drumkit Mono: Will process %d samples (max 64 for Octatrack)", num_samples))
  
  -- Warn if there are more than 64 samples
  if #source_instrument.samples > 64 then
    local result = renoise.app():show_prompt("Octatrack Slice Limit", 
        "Instrument has " .. #source_instrument.samples .. " samples, but Octatrack only supports 64 slices.\n" ..
        "Only the first 64 samples will be processed.\n\nContinue?", 
        {"Continue", "Cancel"})
    if result == "Cancel" then
      renoise.app():show_status("Drumkit creation cancelled")
      return
    end
  end
  
  -- Debug: List all sample slots and their status with names
  print("-- OT Drumkit Mono: Sample Analysis:")
  for i = 1, num_samples do
    local sample = source_instrument.samples[i]
    if sample then
      if sample.sample_buffer.has_sample_data then
        print(string.format("-- OT Drumkit Mono: Slot %02d: '%s' - %d frames, %d channels, %.1fkHz, %dbit", 
          i, sample.name or "Unnamed", sample.sample_buffer.number_of_frames, sample.sample_buffer.number_of_channels, 
          sample.sample_buffer.sample_rate, sample.sample_buffer.bit_depth))
      else
        print(string.format("-- OT Drumkit Mono: Slot %02d: '%s' - EMPTY (no sample data)", i, sample.name or "Unnamed"))
      end
    else
      print(string.format("-- OT Drumkit Mono: Slot %02d: NULL - no sample object", i))
    end
  end
  
  -- Create new instrument for the drumkit
  local new_instrument_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local drumkit_instrument = song.selected_instrument
  
  -- Set drumkit instrument name
  drumkit_instrument.name = "OT Mono Drumkit of " .. source_instrument.name
  print("-- OT Drumkit Mono: Created new instrument: " .. drumkit_instrument.name)
  
  -- Create working copies of samples and normalize them
  local processed_samples = {}
  local target_channels = 1  -- Always mono for this version
  
  print("-- OT Drumkit Mono: Target format: Mono, 44100Hz, 16-bit")
  
  -- Process all samples
  local processed_count = 0
  local skipped_count = 0
  
  for i = 1, num_samples do
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data then
      -- Update status with clear X/Y progress
      renoise.app():show_status(string.format("OT Mono: Processing sample %d/%d...", i, num_samples))
      print(string.format("-- OT Drumkit Mono: Processing slot %02d/%02d...", i, num_samples))
      
      -- Create temporary instrument to hold processed sample
      local temp_instrument_index = song.selected_instrument_index + 1
      song:insert_instrument_at(temp_instrument_index)
      song.selected_instrument_index = temp_instrument_index
      local temp_instrument = song.selected_instrument
      
      -- Copy sample to temp instrument
      local temp_sample = temp_instrument:insert_sample_at(1)
      temp_sample.sample_buffer:create_sample_data(
        sample.sample_buffer.sample_rate,
        sample.sample_buffer.bit_depth,
        sample.sample_buffer.number_of_channels,
        sample.sample_buffer.number_of_frames
      )
      temp_sample.sample_buffer:prepare_sample_data_changes()
      
      -- Copy sample data
      for ch = 1, sample.sample_buffer.number_of_channels do
        for frame = 1, sample.sample_buffer.number_of_frames do
          temp_sample.sample_buffer:set_sample_data(ch, frame, sample.sample_buffer:sample_data(ch, frame))
        end
      end
      temp_sample.sample_buffer:finalize_sample_data_changes()
      
      -- Remove loops for clean drumkit sounds
      temp_sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
      
      local original_rate = temp_sample.sample_buffer.sample_rate
      local original_bit = temp_sample.sample_buffer.bit_depth
      local original_channels = temp_sample.sample_buffer.number_of_channels
      
      print(string.format("-- OT Drumkit Mono: Processing slot %02d '%s': %d frames, %d channels, %.1fkHz, %dbit", 
        i, sample.name or "Unnamed", temp_sample.sample_buffer.number_of_frames, original_channels, 
        original_rate, original_bit))
      
      -- Convert to mono 44.1kHz 16-bit
      local needs_conversion = (original_rate ~= 44100) or (original_bit ~= 16) or (original_channels ~= 1)
      
      if needs_conversion then
        print(string.format("-- OT Drumkit Mono: Converting slot %02d: %.1fkHz/%dbit/%dch → 44.1kHz/16bit/1ch", 
          i, original_rate, original_bit, original_channels))
        song.selected_sample_index = 1
        
        -- Use RenderSampleAtNewRate for precise conversion, then convert to mono
        local success = pcall(function()
          local old_sample_count = #temp_instrument.samples
          
          -- First convert rate and bit depth
          if (original_rate ~= 44100) or (original_bit ~= 16) then
            RenderSampleAtNewRate(44100, 16)
            if #temp_instrument.samples == old_sample_count then
              temp_sample = temp_instrument.samples[1]
            end
          end
          
          -- Then convert to mono if needed
          if temp_sample.sample_buffer.number_of_channels == 2 then
            -- Manual stereo to mono conversion
            local stereo_buffer = temp_sample.sample_buffer
            local mono_frames = stereo_buffer.number_of_frames
            
            -- Create new mono sample
            local mono_sample = temp_instrument:insert_sample_at(2)
            mono_sample.sample_buffer:create_sample_data(44100, 16, 1, mono_frames)
            mono_sample.sample_buffer:prepare_sample_data_changes()
            
            -- Mix stereo to mono
            for frame = 1, mono_frames do
              local left = stereo_buffer:sample_data(1, frame)
              local right = stereo_buffer:sample_data(2, frame)
              local mono_value = (left + right) / 2
              mono_sample.sample_buffer:set_sample_data(1, frame, mono_value)
            end
            
            mono_sample.sample_buffer:finalize_sample_data_changes()
            
            -- Replace stereo sample with mono sample
            temp_instrument:delete_sample_at(1)
            temp_sample = mono_sample
            song.selected_sample_index = 1
          end
        end)
        
        if not success then
          print(string.format("-- OT Drumkit Mono: Conversion failed for slot %02d, using original", i))
        else
          print(string.format("-- OT Drumkit Mono: After conversion - slot %02d: %d frames, %d channels, %.1fkHz, %dbit", 
            i, temp_sample.sample_buffer.number_of_frames, temp_sample.sample_buffer.number_of_channels, 
            temp_sample.sample_buffer.sample_rate, temp_sample.sample_buffer.bit_depth))
        end
      else
        print(string.format("-- OT Drumkit Mono: No conversion needed for slot %02d (already 44.1kHz/16bit/1ch)", i))
      end
      
      -- Store processed sample data
      local processed_buffer = temp_sample.sample_buffer
      processed_samples[i] = {
        frames = processed_buffer.number_of_frames,
        channels = processed_buffer.number_of_channels,
        data = {}
      }
      
      -- Copy processed data
      for ch = 1, processed_buffer.number_of_channels do
        processed_samples[i].data[ch] = {}
        for frame = 1, processed_buffer.number_of_frames do
          processed_samples[i].data[ch][frame] = processed_buffer:sample_data(ch, frame)
        end
      end
      
      processed_count = processed_count + 1
      print(string.format("-- OT Drumkit Mono: Successfully processed slot %02d: %d frames, %d channels", i, processed_samples[i].frames, processed_samples[i].channels))
      
      -- Clean up temp instrument
      song:delete_instrument_at(temp_instrument_index)
      song.selected_instrument_index = new_instrument_index
    else
      skipped_count = skipped_count + 1
      if sample then
        print(string.format("-- OT Drumkit Mono: Skipping slot %02d: no sample data", i))
      else
        print(string.format("-- OT Drumkit Mono: Skipping slot %02d: no sample object", i))
      end
    end
  end
  
  print(string.format("-- OT Drumkit Mono: Processing summary: %d processed, %d skipped", processed_count, skipped_count))
  
  -- Calculate total length for combined sample
  renoise.app():show_status("OT Mono: Creating combined sample...")
  local total_frames = 0
  local slice_positions = {}
  local valid_samples = {}
  
  -- Build array of only valid samples and calculate positions
  for i = 1, num_samples do
    if processed_samples[i] then
      table.insert(valid_samples, processed_samples[i])
      table.insert(slice_positions, total_frames + 1)  -- Slice at start of each sample (1-based)
      total_frames = total_frames + processed_samples[i].frames
    end
  end
  
  print(string.format("-- OT Drumkit Mono: Total combined length: %d frames (%.2f seconds)", total_frames, total_frames / 44100.0))
  print(string.format("-- OT Drumkit Mono: Will create %d slices", #slice_positions))
  
  -- Debug: Show slice positions
  for i = 1, math.min(10, #slice_positions) do
    local slice_time = (slice_positions[i] - 1) / 44100.0
    print(string.format("-- OT Drumkit Mono: Slice %02d at frame %d (%.3fs)", i, slice_positions[i], slice_time))
  end
  if #slice_positions > 10 then
    print(string.format("-- OT Drumkit Mono: ... and %d more slices", #slice_positions - 10))
  end
  
  -- Create the combined sample buffer
  if drumkit_instrument.samples[1] then
    drumkit_instrument:delete_sample_at(1)  -- Remove default empty sample
  end
  
  local combined_sample = drumkit_instrument:insert_sample_at(1)
  combined_sample.sample_buffer:create_sample_data(44100, 16, target_channels, total_frames)
  combined_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Copy all processed samples into the combined buffer using FAST BULK operations
  local start_time = os.clock()
  local current_position = 1
  for i = 1, #valid_samples do
    local sample_data = valid_samples[i]
    print(string.format("-- OT Drumkit Mono Legacy: Fast bulk combining sample %d/%d (%d frames)", i, #valid_samples, sample_data.frames))
    
    -- Copy frames in chunks of 10000 for efficiency
    local chunk_size = 10000
    local frames_to_copy = sample_data.frames
    local source_pos = 1
    local dest_pos = current_position
    
    while frames_to_copy > 0 do
      local this_chunk = math.min(chunk_size, frames_to_copy)
      
      -- Copy chunk data for mono channel
      for frame = 0, this_chunk - 1 do
        -- For mono target, always use channel 1 (already converted to mono above)
        local source_value = sample_data.data[1][source_pos + frame]
        combined_sample.sample_buffer:set_sample_data(1, dest_pos + frame - 1, source_value)
      end
      
      source_pos = source_pos + this_chunk
      dest_pos = dest_pos + this_chunk
      frames_to_copy = frames_to_copy - this_chunk
    end
    
    current_position = current_position + sample_data.frames
    print(string.format("-- OT Drumkit Mono Legacy: Sample %d combined successfully", i))
  end
  
  local end_time = os.clock()
  print(string.format("-- OT Drumkit Mono Legacy: FAST bulk combining completed in %.2f seconds", end_time - start_time))
  
  combined_sample.sample_buffer:finalize_sample_data_changes()
  
  -- Set sample name
  combined_sample.name = drumkit_instrument.name
  
  -- Insert slice markers
  renoise.app():show_status("OT Mono: Creating slice markers...")
  for i = 1, #slice_positions do
    combined_sample:insert_slice_marker(slice_positions[i])
  end
  
  -- Select the combined sample
  song.selected_sample_index = 1
  
  renoise.app():show_status(string.format("OT Mono Drumkit created: %d slices", #slice_positions))
  print("-- OT Drumkit Mono: Mono drumkit creation completed successfully")
  
  -- Prompt for export
  local export_result = renoise.app():show_prompt("Octatrack Mono Drumkit Created", 
    string.format("Octatrack mono drumkit created successfully!\n\n• %d slices from %d samples\n• Format: Mono, 44.1kHz, 16-bit\n\nExport to Octatrack files (.wav + .ot)?", 
      #slice_positions, num_samples),
    {"Export", "Keep Only"})
  
  if export_result == "Export" then
    PakettiOTExport()
  end
end

-- Function to set loop points to match a specific slice in a .ot file
function PakettiOTSetLoopToSlice()
    -- Get the .ot file to modify
    local filename = renoise.app():prompt_for_filename_to_read({"*.ot"}, "Select .ot file to modify loop points...")
    
    if not filename or filename == "" then
        return -- User cancelled
    end
    
    -- Read the .ot file
    local ot_data = read_ot_file(filename)
    if not ot_data then
        renoise.app():show_error("OT Loop Set Error", "Could not read .ot file: " .. filename)
        return
    end
    
    -- Check if there are any slices
    if #ot_data.slices == 0 then
        renoise.app():show_error("No Slices Found", "The .ot file contains no slices to loop.")
        return
    end
    
    -- Show slice selection dialog
    local vb = renoise.ViewBuilder()
    local slice_dialog = nil
    local selected_slice = 1
    
    -- Build slice list for popup
    local slice_items = {}
    for i = 1, #ot_data.slices do
        local slice = ot_data.slices[i]
        local start_time = slice.start_point / 44100.0
        local end_time = slice.end_point / 44100.0
        local duration = end_time - start_time
        table.insert(slice_items, string.format("Slice %02d: %.3fs-%.3fs (%.3fs)", 
            i, start_time, end_time, duration))
    end
    
    local content = vb:column {
        margin = 10,
        vb:text {
            text = "Set Loop Points to Slice",
            font = "big",
            style = "strong"
        },
        vb:space { height = 10 },
        vb:text {
            text = "File: " .. (filename:match("([^/\\]+)$") or filename),
            style = "strong"
        },
        vb:text {
            text = string.format("Found %d slices in .ot file", #ot_data.slices)
        },
        vb:space { height = 10 },
        vb:text {
            text = "Select slice to use for loop points:"
        },
        vb:popup {
            id = "slice_popup",
            items = slice_items,
            value = 1,
            width = 400,
            notifier = function(index)
                selected_slice = index
            end
        },
        vb:space { height = 10 },
        vb:text {
            text = "This will modify the .ot file to loop the selected slice.",
            style = "italic"
        },
        vb:text {
            text = "A backup (.ot.bak) will be created automatically.",
            style = "italic"
        },
        vb:space { height = 15 },
        vb:horizontal_aligner {
            mode = "distribute",
            vb:button {
                text = "Cancel",
                width = 80,
                released = function()
                    if slice_dialog and slice_dialog.visible then
                        slice_dialog:close()
                    end
                end
            },
            vb:button {
                text = "Set Loop",
                width = 80,
                released = function()
                    if slice_dialog and slice_dialog.visible then
                        slice_dialog:close()
                    end
                    
                    -- Create backup
                    local backup_filename = filename .. ".bak"
                    local success = pcall(function()
                        local source = io.open(filename, "rb")
                        local backup = io.open(backup_filename, "wb")
                        if source and backup then
                            backup:write(source:read("*all"))
                            source:close()
                            backup:close()
                            print("Created backup: " .. backup_filename)
                        else
                            error("Could not create backup file")
                        end
                    end)
                    
                    if not success then
                        renoise.app():show_error("Backup Error", "Could not create backup file. Operation cancelled.")
                        return
                    end
                    
                    -- Get selected slice data
                    local slice = ot_data.slices[selected_slice]
                    local slice_start = slice.start_point
                    local slice_end = slice.end_point
                    local slice_length = slice_end - slice_start
                    
                    print(string.format("Setting loop to slice %d: start=%d, end=%d, length=%d", 
                        selected_slice, slice_start, slice_end, slice_length))
                    
                    -- Modify the ot_data structure
                    ot_data.loop = 1  -- Enable loop
                    ot_data.loop_point = slice_start  -- Set loop start point
                    ot_data.trim_start = slice_start  -- Set trim start to slice start
                    ot_data.trim_end = slice_end      -- Set trim end to slice end
                    ot_data.trim_len = slice_length   -- Set trim length
                    ot_data.loop_len = slice_length   -- Set loop length
                    
                    -- Convert back to ot table format and write
                    local success_write = pcall(function()
                        -- Build the ot table manually since we're modifying existing data
                        local ot = {}
                        
                        -- Insert header and unknown
                        for k, v in ipairs(header) do
                            table.insert(ot, v)
                        end
                        for k, v in ipairs(unknown) do
                            table.insert(ot, v)
                        end
                        
                        -- Main parameters
                        table.insert(ot, ot_data.tempo)        -- tempo (32)
                        table.insert(ot, ot_data.trim_len)     -- trim_len (32)
                        table.insert(ot, ot_data.loop_len)     -- loop_len (32)
                        table.insert(ot, ot_data.stretch)      -- stretch (32)
                        table.insert(ot, ot_data.loop)         -- loop (32)
                        table.insert(ot, ot_data.gain)         -- gain (16)
                        table.insert(ot, ot_data.quantize)     -- quantize (8)
                        table.insert(ot, ot_data.trim_start)   -- trim_start (32)
                        table.insert(ot, ot_data.trim_end)     -- trim_end (32)
                        table.insert(ot, ot_data.loop_point)   -- loop_point (32)
                        
                        -- Add all slice data (64 slices)
                        local checksum = (16/8) + (8/8) + ((32/8) * 8)  -- Base checksum
                        
                        for i = 1, 64 do
                            if ot_data.slices[i] then
                                local slice = ot_data.slices[i]
                                table.insert(ot, slice.start_point)
                                table.insert(ot, slice.end_point)
                                table.insert(ot, slice.loop_point)
                            else
                                table.insert(ot, 0x00000000)
                                table.insert(ot, 0x00000000)
                                table.insert(ot, 0x00000000)
                            end
                            checksum = checksum + ((32/8) * 3)
                        end
                        
                        -- Add slice count and checksum
                        table.insert(ot, ot_data.slice_count)
                        checksum = checksum + (32/8)
                        table.insert(ot, checksum)
                        
                        -- Write the modified file
                        write_ot_file(filename, ot)
                    end)
                    
                    if success_write then
                        local slice_time = slice_start / 44100.0
                        local duration = slice_length / 44100.0
                        renoise.app():show_status(string.format("Loop set to slice %d (%.3fs, %.3fs duration)", 
                            selected_slice, slice_time, duration))
                        print(string.format("Successfully modified %s - loop now matches slice %d", 
                            filename:match("([^/\\]+)$") or filename, selected_slice))
                    else
                        renoise.app():show_error("Write Error", "Could not write modified .ot file.")
                        -- Try to restore backup
                        pcall(function()
                            local backup = io.open(backup_filename, "rb")
                            local original = io.open(filename, "wb")
                            if backup and original then
                                original:write(backup:read("*all"))
                                backup:close()
                                original:close()
                                print("Restored from backup due to write error")
                            end
                        end)
                    end
                end
            }
        }
    }
    
    slice_dialog = renoise.app():show_custom_dialog("Set OT Loop to Slice", content)
end

-- Function to restore .ot file from backup
function PakettiOTRestoreFromBackup()
    local filename = renoise.app():prompt_for_filename_to_read({"*.ot", "*.bak"}, "Select .ot file to restore from backup...")
    
    if not filename or filename == "" then
        return -- User cancelled
    end
    
    -- Determine backup and original filenames
    local original_filename, backup_filename
    if filename:match("%.bak$") then
        backup_filename = filename
        original_filename = filename:gsub("%.bak$", "")
    else
        original_filename = filename
        backup_filename = filename .. ".bak"
    end
    
    -- Check if backup exists
    local backup_file = io.open(backup_filename, "rb")
    if not backup_file then
        renoise.app():show_error("No Backup Found", "Backup file not found: " .. backup_filename)
        return
    end
    backup_file:close()
    
    -- Confirm restoration
    local result = renoise.app():show_prompt("Restore from Backup", 
        string.format("Restore %s from backup?\n\nThis will overwrite the current file.", 
            original_filename:match("([^/\\]+)$") or original_filename),
        {"Restore", "Cancel"})
    
    if result == "Cancel" then
        return
    end
    
    -- Perform restoration
    local success = pcall(function()
        local backup = io.open(backup_filename, "rb")
        local original = io.open(original_filename, "wb")
        if backup and original then
            original:write(backup:read("*all"))
            backup:close()
            original:close()
            -- Delete backup file after successful restoration
            os.remove(backup_filename)
        else
            error("Could not open files for restoration")
        end
    end)
    
    if success then
        renoise.app():show_status("Restored from backup: " .. (original_filename:match("([^/\\]+)$") or original_filename))
        print("Successfully restored " .. original_filename .. " from backup and deleted backup file")
    else
        renoise.app():show_error("Restoration Failed", "Could not restore file from backup.")
  end
end

-- Function to create drumkit where all slices play to the end of the full sample
function PakettiOTDrumkitPlayToEnd()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song = renoise.song()
  local source_instrument = song.selected_instrument
  
  -- Safety checks
  if not source_instrument then
    renoise.app():show_error("No instrument selected")
    return
  end
  
  if #source_instrument.samples == 0 then
    renoise.app():show_error("Selected instrument has no samples")
    return
  end
  
  if #source_instrument.samples[1].slice_markers > 0 then
    renoise.app():show_error("Cannot create drumkit from sliced instrument.\nPlease select an instrument with individual samples in separate slots.")
    return
  end
  
  -- Determine how many samples to process (max 64 for Octatrack)
  local num_samples = math.min(64, #source_instrument.samples)
  
  -- Warn if there are more than 64 samples
  if #source_instrument.samples > 64 then
    local result = renoise.app():show_prompt("Octatrack Slice Limit", 
        "Instrument has " .. #source_instrument.samples .. " samples, but Octatrack only supports 64 slices.\n" ..
        "Only the first 64 samples will be processed.\n\nContinue?", 
        {"Continue", "Cancel"})
    if result == "Cancel" then
      renoise.app():show_status("Drumkit creation cancelled")
      return
    end
  end
  
  local dialog, vb
  
  -- Create ProcessSlicer with worker function
  local process_slicer = ProcessSlicer(function()
    PakettiOTDrumkitPlayToEnd_Worker(source_instrument, num_samples, dialog, vb)
  end)
  
  dialog, vb = process_slicer:create_dialog("Creating Play-To-End Octatrack Drumkit...")
  process_slicer:start()
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Worker function for play-to-end drumkit generation
function PakettiOTDrumkitPlayToEnd_Worker(source_instrument, num_samples, dialog, vb)
  local song = renoise.song()
  
  print("-- OT Drumkit PlayToEnd: Starting play-to-end drumkit creation from instrument: " .. source_instrument.name)
  print(string.format("-- OT Drumkit PlayToEnd: Will process %d samples (all slices play to end)", num_samples))
  
  -- Detect if any sample is stereo
  local has_stereo = false
  local stereo_samples = {}
  for i = 1, num_samples do
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data and sample.sample_buffer.number_of_channels == 2 then
      has_stereo = true
      table.insert(stereo_samples, i)
    end
  end
  
  local target_channels = has_stereo and 2 or 1
  print(string.format("-- OT Drumkit PlayToEnd: Target format: %s, 44100Hz, 16-bit", target_channels == 2 and "Stereo" or "Mono"))
  
  -- Create new instrument for the drumkit
  local new_instrument_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local drumkit_instrument = song.selected_instrument
  drumkit_instrument.name = "OT PlayToEnd Drumkit of " .. source_instrument.name
  
  -- Process samples with progress updates
  local processed_samples = {}
  local processed_count = 0
  local skipped_count = 0
  
  for i = 1, num_samples do
    -- Update progress
    if dialog and dialog.visible then
      vb.views.progress_text.text = string.format("Processing sample %d/%d...", i, num_samples)
    end
    renoise.app():show_status(string.format("OT PlayToEnd: Processing sample %d/%d...", i, num_samples))
    print(string.format("-- OT Drumkit PlayToEnd: Processing slot %02d/%02d...", i, num_samples))
    
    local sample = source_instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data then
      
      -- Create temporary instrument to hold processed sample
      local temp_instrument_index = song.selected_instrument_index + 1
      song:insert_instrument_at(temp_instrument_index)
      song.selected_instrument_index = temp_instrument_index
      local temp_instrument = song.selected_instrument
      
      -- Copy sample to temp instrument
      local temp_sample = temp_instrument:insert_sample_at(1)
      temp_sample.sample_buffer:create_sample_data(
        sample.sample_buffer.sample_rate,
        sample.sample_buffer.bit_depth,
        sample.sample_buffer.number_of_channels,
        sample.sample_buffer.number_of_frames
      )
      temp_sample.sample_buffer:prepare_sample_data_changes()
      
      -- Copy sample data
      for ch = 1, sample.sample_buffer.number_of_channels do
        for frame = 1, sample.sample_buffer.number_of_frames do
          temp_sample.sample_buffer:set_sample_data(ch, frame, sample.sample_buffer:sample_data(ch, frame))
        end
      end
      temp_sample.sample_buffer:finalize_sample_data_changes()
      
      -- Remove loops for clean drumkit sounds
      temp_sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
      
      -- Convert to 44.1kHz 16-bit if needed
      local original_rate = temp_sample.sample_buffer.sample_rate
      local original_bit = temp_sample.sample_buffer.bit_depth
      local needs_conversion = (original_rate ~= 44100) or (original_bit ~= 16)
      
      if needs_conversion then
        song.selected_sample_index = 1
        local success = pcall(function()
          RenderSampleAtNewRate(44100, 16)
          temp_sample = temp_instrument.samples[1]
        end)
        if not success then
          print(string.format("-- OT Drumkit PlayToEnd: Conversion failed for slot %02d, using original", i))
        end
      end
      
      -- Store processed sample data
      local processed_buffer = temp_sample.sample_buffer
      processed_samples[i] = {
        frames = processed_buffer.number_of_frames,
        channels = processed_buffer.number_of_channels,
        data = {}
      }
      
      -- Copy processed data
      for ch = 1, processed_buffer.number_of_channels do
        processed_samples[i].data[ch] = {}
        for frame = 1, processed_buffer.number_of_frames do
          processed_samples[i].data[ch][frame] = processed_buffer:sample_data(ch, frame)
        end
      end
      
      processed_count = processed_count + 1
      print(string.format("-- OT Drumkit PlayToEnd: Successfully processed slot %02d: %d frames, %d channels", i, processed_samples[i].frames, processed_samples[i].channels))
      
      -- Clean up temp instrument
      song:delete_instrument_at(temp_instrument_index)
      song.selected_instrument_index = new_instrument_index
    else
      skipped_count = skipped_count + 1
      print(string.format("-- OT Drumkit PlayToEnd: Skipping slot %02d: no sample data", i))
    end
    
    -- Yield every 20 samples
    if i % 20 == 0 then
      coroutine.yield()
    end
  end
  
  -- Calculate total length and create combined sample (normal concatenation)
  renoise.app():show_status("OT PlayToEnd: Creating combined sample...")
  print(string.format("-- OT Drumkit PlayToEnd: Processing summary: %d processed, %d skipped", processed_count, skipped_count))
  
  local total_frames = 0
  local slice_positions = {}
  local valid_samples = {}
  
  -- Build array of only valid samples and calculate slice start positions
  for i = 1, num_samples do
    if processed_samples[i] then
      table.insert(valid_samples, processed_samples[i])
      table.insert(slice_positions, total_frames + 1)  -- Slice starts at beginning of each sample (1-based)
      total_frames = total_frames + processed_samples[i].frames
    end
  end
  
  print(string.format("-- OT Drumkit PlayToEnd: Total combined length: %d frames (%.2f seconds)", total_frames, total_frames / 44100.0))
  print(string.format("-- OT Drumkit PlayToEnd: Will create %d slices, all ending at frame %d", #slice_positions, total_frames))
  
  -- Create the combined sample buffer (normal concatenation)
  if drumkit_instrument.samples[1] then
    drumkit_instrument:delete_sample_at(1)
  end
  
  local combined_sample = drumkit_instrument:insert_sample_at(1)
  combined_sample.sample_buffer:create_sample_data(44100, 16, target_channels, total_frames)
  combined_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Copy all processed samples into the combined buffer using FAST BULK operations (normal concatenation)
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Combining samples into drumkit..."
  end
  renoise.app():show_status("OT PlayToEnd: Fast bulk combining samples...")
  local start_time = os.clock()
  
  local current_position = 1
  for i = 1, #valid_samples do
    local sample_data = valid_samples[i]
    print(string.format("-- OT Drumkit PlayToEnd: Fast bulk combining sample %d/%d (%d frames)", i, #valid_samples, sample_data.frames))
    
    -- Copy frames in chunks of 10000 for efficiency
    local chunk_size = 10000
    local frames_to_copy = sample_data.frames
    local source_pos = 1
    local dest_pos = current_position
    
    while frames_to_copy > 0 do
      local this_chunk = math.min(chunk_size, frames_to_copy)
      
      -- Copy chunk data for all target channels
      for frame = 0, this_chunk - 1 do
        for ch = 1, target_channels do
          local source_value = 0.0
          if sample_data.channels == target_channels then
            source_value = sample_data.data[ch][source_pos + frame]
          elseif sample_data.channels == 1 and target_channels == 2 then
            source_value = sample_data.data[1][source_pos + frame]
          elseif sample_data.channels == 2 and target_channels == 1 then
            source_value = (sample_data.data[1][source_pos + frame] + sample_data.data[2][source_pos + frame]) / 2
          else
            if sample_data.channels >= 1 then
              source_value = sample_data.data[1][source_pos + frame]
            else
              source_value = 0.0
            end
          end
          combined_sample.sample_buffer:set_sample_data(ch, dest_pos + frame - 1, source_value)
        end
      end
      
      source_pos = source_pos + this_chunk
      dest_pos = dest_pos + this_chunk
      frames_to_copy = frames_to_copy - this_chunk
      
      -- Yield every chunk to keep UI responsive
      coroutine.yield()
    end
    
    current_position = current_position + sample_data.frames
    print(string.format("-- OT Drumkit PlayToEnd: Sample %d combined successfully", i))
  end
  
  local end_time = os.clock()
  print(string.format("-- OT Drumkit PlayToEnd: FAST bulk combining completed in %.2f seconds", end_time - start_time))
  
  combined_sample.sample_buffer:finalize_sample_data_changes()
  combined_sample.name = drumkit_instrument.name
  
  -- Insert slice markers at normal positions (where each sample starts)
  if dialog and dialog.visible then
    vb.views.progress_text.text = "Creating slice markers..."
  end
  renoise.app():show_status("OT PlayToEnd: Creating slice markers...")
  for i = 1, #slice_positions do
    combined_sample:insert_slice_marker(slice_positions[i])
  end
  
  song.selected_sample_index = 1
  
  -- Store special metadata for play-to-end export behavior
  -- We'll modify the sample name to include a flag that the OT export should handle specially
  local original_name = combined_sample.name
  combined_sample.name = original_name .. " [PLAYTOEND]"
  
  -- Close dialog
  if dialog and dialog.visible then
    dialog:close()
  end
  
  renoise.app():show_status(string.format("OT PlayToEnd: Drumkit completed - %d slices, all play to end", #slice_positions))
  print("-- OT Drumkit PlayToEnd: Play-to-end drumkit creation completed successfully")
  print(string.format("-- OT Drumkit PlayToEnd: All slices will end at frame %d when exported to .ot", total_frames - 1))
  
  -- Show export dialog
  local export_result = renoise.app():show_prompt("Play-To-End Octatrack Drumkit Created", 
    string.format("Play-to-end Octatrack drumkit created!\n\n• %d slices\n• All slices play to the end of the sample\n• Format: %s, 44.1kHz, 16-bit\n• Total length: %.2f seconds\n\nExport to Octatrack files (.wav + .ot)?", 
      #slice_positions, target_channels == 2 and "Stereo" or "Mono", total_frames / 44100.0),
    {"Export", "Keep Only"})
  
  if export_result == "Export" then
    PakettiOTExportPlayToEnd()
  end
end

-- Modified export function for play-to-end drumkits
function PakettiOTExportPlayToEnd()
  local song = renoise.song()
  local sample = song.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_error("No valid sample selected")
    return
  end
  
  -- Check if this is a play-to-end drumkit
  if not sample.name:match("%[PLAYTOEND%]") then
    renoise.app():show_error("Selected sample is not a play-to-end drumkit.\nUse regular OT Export for normal samples.")
    return
  end
  
  print("-- OT Export PlayToEnd: Exporting play-to-end drumkit")
  
  -- Clean up the sample name for export
  local clean_name = sample.name:gsub(" %[PLAYTOEND%]", "")
  local temp_name = sample.name
  sample.name = clean_name
  
  -- Get the total sample length (this will be the end point for ALL slices)
  local total_frames = sample.sample_buffer.number_of_frames
  local slice_count = #sample.slice_markers
  
  print(string.format("-- OT Export PlayToEnd: Total frames: %d, Slice count: %d", total_frames, slice_count))
  print(string.format("-- OT Export PlayToEnd: All slices will end at frame %d (0-based: %d)", total_frames, total_frames - 1))
  
  -- Create custom .ot data where all slice end points = total_frames - 1
  local ot = make_ot_table_play_to_end(sample, total_frames - 1)  -- 0-based for Octatrack
  
  local filename = renoise.app():prompt_for_filename_to_write("*.wav", "Save play-to-end drumkit...")
  
  if not filename or filename == "" then
    sample.name = temp_name  -- Restore original name
    renoise.app():show_status("Export cancelled")
    return
  end
  
  -- Export .ot file with custom slice end points
  write_ot_file(filename, ot)
  
  -- Export .wav file
  local wav_filename = filename
  local base_name = filename:match("(.+)%..+$") or filename
  if not filename:match("%.wav$") then
    wav_filename = base_name .. ".wav"
  end
  
  sample.sample_buffer:save_as(wav_filename, "wav")
  
  -- Restore original name
  sample.name = temp_name
  
  local ot_path = base_name .. ".ot"
  renoise.app():show_status("Exported play-to-end drumkit: " .. ot_path .. " + " .. wav_filename)
  print("-- OT Export PlayToEnd: Export completed successfully")
end

-- Modified make_ot_table function for play-to-end drumkits
function make_ot_table_play_to_end(sample, end_frame)
  local sample_buffer = sample.sample_buffer
  local slice_count = table.getn(sample.slice_markers)
  local sample_len = sample_buffer.number_of_frames
  
  print(string.format("-- OT Export PlayToEnd: Creating .ot table with all slice ends = %d", end_frame))
  
  -- Use regular metadata extraction but override slice end points
  local sample_rate = sample.sample_buffer.sample_rate
  local bpm = renoise.song().transport.bpm
  
  -- Try to extract OT metadata from sample name
  local tempo_value, trim_loop_value, loop_len_value, stretch_value, loop_value, gain_value
  
  -- Try newest format first, then fallback
  local t_val, tl_val, ll_val, s_val, l_val, g_val, te_val, e_val = sample.name:match("OT%[T(%d+):TL(%d+):LL(%d+):S(%d+):L(%d+):G(%d+):TE(%d+):E=([%d,]*)%]")
  
  if not t_val then
    t_val, tl_val, ll_val, s_val, l_val, g_val, e_val = sample.name:match("OT%[T(%d+):TL(%d+):LL(%d+):S(%d+):L(%d+):G(%d+):E=([%d,]*)%]")
  end
  
  if not t_val then
    t_val, tl_val, ll_val, s_val, l_val, g_val = sample.name:match("OT%[T(%d+):TL(%d+):LL(%d+):S(%d+):L(%d+):G(%d+)%]")
  end
  
  if t_val then
    tempo_value = tonumber(t_val)
    trim_loop_value = tonumber(tl_val)
    loop_len_value = tonumber(ll_val)
    stretch_value = tonumber(s_val)
    loop_value = tonumber(l_val)
    gain_value = tonumber(g_val)
    print("-- OT Export PlayToEnd: Using stored OT metadata")
  else
    -- Fallback calculations
    tempo_value = math.floor(bpm * 24)
    local bars = math.floor(((bpm * sample_len) / (sample_rate * 60.0 * 4)) + 0.5)
    trim_loop_value = bars * 25
    loop_len_value = trim_loop_value
    stretch_value = 0
    loop_value = 0
    gain_value = 48
    print("-- OT Export PlayToEnd: Using calculated values")
  end
  
  -- Limit slice count to 64
  local export_slice_count = math.min(slice_count, 64)
  
  local ot = {}
  
  -- Insert header and unknown
  for k, v in ipairs(header) do
    table.insert(ot, v)
  end
  for k, v in ipairs(unknown) do
    table.insert(ot, v)
  end
  
  -- Main parameters
  table.insert(ot, tempo_value)
  table.insert(ot, trim_loop_value)
  table.insert(ot, loop_len_value)
  table.insert(ot, stretch_value)
  table.insert(ot, loop_value)
  table.insert(ot, gain_value)
  table.insert(ot, 0xFF)  -- quantize
  table.insert(ot, 0x00)  -- trim_start
  table.insert(ot, sample_len)  -- trim_end (total sample length)
  table.insert(ot, 0x00)  -- loop_point
  
  -- Process slices with custom end points
  for k = 1, export_slice_count do
    local v = sample.slice_markers[k]
    
    -- Convert from 1-based (Renoise) to 0-based (Octatrack) indexing
    local s_start = (k == 1) and 0 or (v - 1)
    local s_end = end_frame  -- ALL slices end at the same point!
    
    print(string.format("-- OT Export PlayToEnd: Slice %d: start=%d, end=%d (plays to end)", k, s_start, s_end))
    
    table.insert(ot, s_start)     -- start_point
    table.insert(ot, s_end)       -- end_point (always the same!)
    table.insert(ot, 0xFFFFFFFF)  -- loop_point
  end
  
  -- slice_count
  table.insert(ot, export_slice_count)
  
  return ot
end


-- Add menu entries
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Octatrack:Generate Drumkit (Play to End)",invoke=function() PakettiOTDrumkitPlayToEnd() end}
renoise.tool():add_menu_entry{name="Sample Mappings:Paketti:Octatrack:Generate .ot Drumkit (Play to End)",invoke=function() PakettiOTDrumkitPlayToEnd() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Octatrack Generate Drumkit (Play to End)",invoke=function() PakettiOTDrumkitPlayToEnd() end}

