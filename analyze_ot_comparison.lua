-- Detailed analysis and comparison of Renoise vs OctaChainer .ot files
-- This script reads both .ot files and shows the differences

function rb32_be(f)
  local b1 = string.byte(f:read(1) or "\0")  -- MSB first
  local b2 = string.byte(f:read(1) or "\0")
  local b3 = string.byte(f:read(1) or "\0")
  local b4 = string.byte(f:read(1) or "\0")  -- LSB last
  return b1 * 256^3 + b2 * 256^2 + b3 * 256 + b4  -- BIG-ENDIAN
end

function rb16_be(f)
  local b1 = string.byte(f:read(1) or "\0")  -- MSB first
  local b2 = string.byte(f:read(1) or "\0")  -- LSB last
  return b1 * 256 + b2  -- BIG-ENDIAN
end

function rb(f)
  return string.byte(f:read(1) or "\0")
end

function analyze_ot_file(filename)
  print("=== ANALYZING: " .. filename .. " ===")
  
  local f = io.open(filename, "rb")
  if not f then
    print("ERROR: Could not open " .. filename)
    return nil
  end
  
  -- Skip header (16 bytes) and unknown (7 bytes)
  f:seek("set", 23)
  
  -- Read main parameters
  local tempo = rb32_be(f)
  local trim_len = rb32_be(f)
  local loop_len = rb32_be(f)
  local stretch = rb32_be(f)
  local loop = rb32_be(f)
  local gain = rb16_be(f)
  local quantize = rb(f)
  local trim_start = rb32_be(f)
  local trim_end = rb32_be(f)
  local loop_point = rb32_be(f)
  
  print(string.format("TEMPO: %d (BPM: %.1f)", tempo, tempo / 24.0))
  print(string.format("TRIM_LEN: %d", trim_len))
  print(string.format("LOOP_LEN: %d", loop_len))
  print(string.format("STRETCH: %d", stretch))
  print(string.format("LOOP: %d", loop))
  print(string.format("GAIN: %d (dB offset: %+d)", gain, gain - 48))
  print(string.format("QUANTIZE: 0x%02X", quantize))
  print(string.format("TRIM_START: %d", trim_start))
  print(string.format("TRIM_END: %d", trim_end))
  print(string.format("LOOP_POINT: %d", loop_point))
  
  -- Read slice data (64 slices max, 3 x 32-bit values each)
  local slices = {}
  for i = 1, 64 do
    local start_point = rb32_be(f)
    local end_point = rb32_be(f)
    local slice_loop_point = rb32_be(f)
    
    -- Only add slices that have actual data (not all zeros)
    if start_point > 0 or end_point > 0 then
      table.insert(slices, {
        start_point = start_point,
        end_point = end_point,
        loop_point = slice_loop_point
      })
    end
  end
  
  -- Read slice count and checksum
  local slice_count = rb32_be(f)
  local checksum = rb16_be(f)
  
  f:close()
  
  print(string.format("SLICE_COUNT: %d", slice_count))
  print(string.format("ACTUAL_SLICES_FOUND: %d", #slices))
  print(string.format("CHECKSUM: %d (0x%04X)", checksum, checksum))
  
  print("\nSLICE DATA:")
  for i = 1, math.min(10, #slices) do
    local slice = slices[i]
    local start_time = slice.start_point / 44100.0
    local end_time = slice.end_point / 44100.0
    local duration = end_time - start_time
    print(string.format("  Slice %02d: Start=%d (%.3fs), End=%d (%.3fs), Duration=%.3fs", 
      i, slice.start_point, start_time, slice.end_point, end_time, duration))
  end
  if #slices > 10 then
    print(string.format("  ... and %d more slices", #slices - 10))
  end
  
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

function compare_files()
  local renoise_data = analyze_ot_file("OT/renoise.ot")
  print("\n" .. string.rep("=", 80) .. "\n")
  local octachainer_data = analyze_ot_file("OT/octachainer.ot")
  
  if not renoise_data or not octachainer_data then
    print("ERROR: Could not analyze both files")
    return
  end
  
  print("\n" .. string.rep("=", 80))
  print("=== COMPARISON SUMMARY ===")
  print(string.rep("=", 80))
  
  -- Compare key parameters
  local function compare_param(name, r_val, o_val, format_func)
    format_func = format_func or function(v) return tostring(v) end
    local r_str = format_func(r_val)
    local o_str = format_func(o_val)
    local status = (r_val == o_val) and "SAME" or "DIFFERENT"
    print(string.format("%-15s: Renoise=%s, OctaChainer=%s [%s]", name, r_str, o_str, status))
  end
  
  compare_param("TEMPO", renoise_data.tempo, octachainer_data.tempo, 
    function(v) return string.format("%d (%.1f BPM)", v, v/24.0) end)
  compare_param("TRIM_LEN", renoise_data.trim_len, octachainer_data.trim_len)
  compare_param("LOOP_LEN", renoise_data.loop_len, octachainer_data.loop_len)
  compare_param("STRETCH", renoise_data.stretch, octachainer_data.stretch)
  compare_param("LOOP", renoise_data.loop, octachainer_data.loop)
  compare_param("GAIN", renoise_data.gain, octachainer_data.gain)
  compare_param("TRIM_END", renoise_data.trim_end, octachainer_data.trim_end)
  compare_param("SLICE_COUNT", renoise_data.slice_count, octachainer_data.slice_count)
  compare_param("CHECKSUM", renoise_data.checksum, octachainer_data.checksum, 
    function(v) return string.format("%d (0x%04X)", v, v) end)
  
  print("\n" .. string.rep("-", 80))
  print("=== KEY FINDINGS ===")
  print(string.rep("-", 80))
  
  if renoise_data.slice_count ~= octachainer_data.slice_count then
    print(string.format("SLICE COUNT MISMATCH: Renoise exported %d slices, OctaChainer has %d slices", 
      renoise_data.slice_count, octachainer_data.slice_count))
    print("   This explains why they show different behavior on Octatrack!")
  end
  
  if renoise_data.tempo ~= octachainer_data.tempo then
    print(string.format("TEMPO DIFFERENCE: Renoise=%.1f BPM, OctaChainer=%.1f BPM", 
      renoise_data.tempo/24.0, octachainer_data.tempo/24.0))
  end
  
  if renoise_data.stretch ~= octachainer_data.stretch then
    print(string.format("STRETCH SETTING: Renoise=%d, OctaChainer=%d", 
      renoise_data.stretch, octachainer_data.stretch))
  end
  
  if renoise_data.loop ~= octachainer_data.loop then
    print(string.format("LOOP SETTING: Renoise=%d, OctaChainer=%d", 
      renoise_data.loop, octachainer_data.loop))
  end
  
  print("\n" .. string.rep("-", 80))
  print("=== RECOMMENDATIONS ===")
  print(string.rep("-", 80))
  
  if renoise_data.slice_count < octachainer_data.slice_count then
    print("1. Renoise is only exporting " .. renoise_data.slice_count .. " slices instead of all 24 samples")
    print("   This suggests the slice limit logic is cutting off too early.")
  end
  
  if renoise_data.tempo ~= octachainer_data.tempo then
    print("2. Tempo calculation differs - check BPM source and multiplication factor")
  end
  
  if renoise_data.stretch == 2 and octachainer_data.stretch == 0 then
    print("3. Renoise sets stretch=2 (Normal), OctaChainer sets stretch=0 (Off)")
    print("   Consider using stretch=0 to match OctaChainer behavior")
  end
  
  if renoise_data.loop == 1 and octachainer_data.loop == 0 then
    print("4. Renoise enables loop=1, OctaChainer uses loop=0")
    print("   Consider using loop=0 to match OctaChainer behavior")
  end
end

-- Run the comparison
compare_files() 