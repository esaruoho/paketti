local _DEBUG = true
local function dprint(...) if _DEBUG then print("REX Debug:", ...) end end

local function get_clean_filename(filepath)
  local filename = filepath:match("[^/\\]+$")
  if filename then return filename:gsub("%.rex$", "") end
  return "REX Sample"
end

local function read_dword(data, pos)
  local b1, b2, b3, b4 = data:byte(pos, pos + 3)
  return (b1 * 16777216) + (b2 * 65536) + (b3 * 256) + b4
end

function rex_loadsample(filename)
  dprint("Starting REX import for file:", filename)
  
  local song = renoise.song()
  
  -- Define constants
  local header_len = 256  -- Length of each header in frames
  
  -- Initialize with Paketti default instrument
  renoise.song():insert_instrument_at(renoise.song().selected_instrument_index+1)
  renoise.song().selected_instrument_index = renoise.song().selected_instrument_index+1

  pakettiPreferencesDefaultInstrumentLoader()
  local smp = song.selected_sample
  dprint("Using Paketti default instrument configuration")
  
  -- Create temporary AIFF file
  local aiff_copy = os.tmpname() .. ".aiff"
  dprint("Created temporary file:", aiff_copy)
  
  local f_in = io.open(filename, "rb")
  if not f_in then
    dprint("ERROR: Cannot open source file")
    renoise.app():show_status("REX Import Error: Cannot open source file.")
    return false
  end
  dprint("Opened source file successfully")

  local f_out = io.open(aiff_copy, "wb")
  if not f_out then
    dprint("ERROR: Cannot create temp file")
    f_in:close()
    renoise.app():show_status("REX Import Error: Cannot create temp file.")
    return false
  end
  dprint("Created temporary file successfully")

  local data = f_in:read("*a")
  dprint("Read source file, size:", #data, "bytes")
  f_out:write(data)
  f_in:close()
  f_out:close()
  dprint("Wrote temporary file")

  -- Try to load the sample and verify it has data
  dprint("Attempting to load sample from temporary file")
  local load_success = pcall(function() 
    smp.sample_buffer:load_from(aiff_copy)
  end)
  
  if not load_success then
    dprint("ERROR: Failed to load sample")
    renoise.app():show_status("REX Import Error: Failed to load sample.")
    os.remove(aiff_copy)
    return false
  end
  
  if not smp.sample_buffer.has_sample_data then
    dprint("ERROR: No audio data loaded")
    renoise.app():show_status("REX Import Error: No audio data loaded.")
    os.remove(aiff_copy)
    return false
  end
  dprint("Sample loaded successfully")

  -- Verify sample buffer properties are accessible
  local buf = smp.sample_buffer
  if not buf or not buf.has_sample_data then
    dprint("ERROR: Invalid sample buffer")
    renoise.app():show_status("REX Import Error: Invalid sample buffer.")
    os.remove(aiff_copy)
    return false
  end
  dprint("Sample buffer is valid")

  -- Safe access of sample buffer after validation
  local ch = buf.number_of_channels
  local frames = buf.number_of_frames
  dprint("Sample properties - Channels:", ch, "Frames:", frames)
  
  if ch <= 0 or frames <= 0 then
    dprint("ERROR: Invalid sample dimensions")
    renoise.app():show_status("REX Import Error: Invalid sample data dimensions.")
    os.remove(aiff_copy)
    return false
  end

  local rex_start = data:find("REX ", 1, true)
  if not rex_start then
    dprint("ERROR: REX chunk not found in file")
    renoise.app():show_status("REX chunk not found")
    os.remove(aiff_copy)
    return true
  end
  dprint("Found REX chunk at offset:", rex_start)

  local header_offset = rex_start + 1032
  local slice_offsets = {}
  local seen = {}
  for i = 1, 256 do
    if header_offset + 3 > #data then break end
    local offs = read_dword(data, header_offset)
    if offs == 0 or seen[offs] then break end
    table.insert(slice_offsets, offs)
    seen[offs] = true
    header_offset = header_offset + 12
  end
  dprint("Found", #slice_offsets, "slice offsets")

  if #slice_offsets == 0 then
    dprint("ERROR: No slice offsets found")
    renoise.app():show_status("REX contained no slice offsets.")
    os.remove(aiff_copy)
    return false
  end

  -- Calculate total frames including headers
  local total_headers = #slice_offsets
  local total_header_frames = total_headers * header_len
  local actual_frames = frames + total_header_frames
  dprint(string.format("Actual audio length calculation: visible frames %d + (%d headers * %d frames) = %d total frames", 
    frames, total_headers, header_len, actual_frames))

  -- Copy sample data to memory, accounting for full length including headers
  dprint("Copying sample data to memory")
  local original = {}
  for c = 1, ch do
    original[c] = {}
    for i = 1, actual_frames do
      if i <= frames then  -- Only copy actual data we have
        original[c][i] = buf:sample_data(c, i)
      end
    end
  end
  dprint("Sample data copied successfully")

  -- Remove headers in reverse
  dprint("Processing slice headers")
  -- Sort in ascending order to process sequentially
  table.sort(slice_offsets)
  
  dprint("Original slice positions:", table.concat(slice_offsets, ", "))
  
  -- Now copy the data, removing headers
  local new_pos = 1  -- Where we're writing to
  local read_pos = 1  -- Where we're reading from
  local header_count = 0
  local total_removed = 0
  
  -- Create a new buffer for the processed data
  local processed = {}
  for c = 1, ch do
    processed[c] = {}
  end
  
  -- Process each slice
  for i = 1, #slice_offsets do
    local slice_pos = slice_offsets[i]
    local next_slice = (i < #slice_offsets) and slice_offsets[i+1] or frames
    
    -- The header ends exactly at slice position (inclusive)
    local header_start = slice_pos - header_len + 1
    
    -- If this is the first slice, copy everything up to the first header
    if i == 1 then
      for pos = 1, header_start-1 do
        for c = 1, ch do
          processed[c][new_pos] = original[c][pos]
        end
        new_pos = new_pos + 1
      end
    end
    
    -- Skip the header and report
    dprint(string.format("Removing header at position %d-%d (%d frames header detected ending at slice at %d - slice position becomes %d)", 
      header_start, slice_pos, header_len, slice_pos, new_pos))
    
    -- Copy the slice data
    -- For the last slice, copy all remaining data
    -- For other slices, copy until just before the next header
    local copy_end
    if i == #slice_offsets then
      copy_end = frames  -- Copy all the way to the end for last slice
      dprint(string.format("Last slice: copying all remaining data from %d to %d", slice_pos + 1, copy_end))
    else
      copy_end = slice_offsets[i+1] - header_len
      dprint(string.format("Slice %d: copying data from %d to %d", i, slice_pos + 1, copy_end))
    end
    
    for pos = slice_pos + 1, copy_end do
      if pos <= frames then  -- Make sure we don't read past the end
        for c = 1, ch do
          processed[c][new_pos] = original[c][pos]
        end
        new_pos = new_pos + 1
      end
    end
    
    total_removed = total_removed + header_len
  end
  
  -- Calculate new frame count
  local new_frames = new_pos - 1  -- Since new_pos is the next write position
  dprint(string.format("Processed %d headers, removed total of %d frames (%d frames per header), new length is %d frames", 
    #slice_offsets, total_removed, header_len, new_frames))

  -- Create new sample without headers
  dprint("Creating new sample without headers")
  local new_sample_index = #song.selected_instrument.samples + 1
  song.selected_instrument:insert_sample_at(new_sample_index)
  local new_smp = song.selected_instrument:sample(new_sample_index)
  
  -- Create the sample buffer with correct size
  local create_success = pcall(function()
    new_smp.sample_buffer:create_sample_data(buf.sample_rate, 16, ch, new_frames)
  end)

  if not create_success then
    dprint("ERROR: Failed to create new sample buffer")
    renoise.app():show_status("REX Import Error: Failed to create new sample buffer.")
    os.remove(aiff_copy)
    return false
  end

  -- Copy processed data to new buffer
  local new_buf = new_smp.sample_buffer
  if not new_buf or not new_buf.has_sample_data then
    dprint("ERROR: New sample buffer is invalid")
    renoise.app():show_status("REX Import Error: New sample buffer is invalid.")
    os.remove(aiff_copy)
    return false
  end

  -- Write the processed data
  dprint("Writing processed data")
  local write_success = pcall(function()
    for i = 1, new_frames do
      for c = 1, ch do
        new_buf:set_sample_data(c, i, processed[c][i] or 0)
      end
    end
  end)

  if not write_success then
    dprint("ERROR: Failed to write processed data")
    renoise.app():show_status("REX Import Error: Failed to write processed data.")
    os.remove(aiff_copy)
    return false
  end

  -- Remove the original sample
  song.selected_instrument:delete_sample_at(1)
  -- Select the new sample
  song.selected_sample_index = 1
  
  -- Insert slice markers at the actual positions
  dprint("Adding slice markers")
  local sample = renoise.song().selected_instrument.samples[1]
  sample.autofade = preferences.pakettiLoaderAutofade.value
  sample.autoseek = preferences.pakettiLoaderAutoseek.value
  sample.loop_mode = preferences.pakettiLoaderLoopMode.value
  sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
  sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  sample.oneshot = preferences.pakettiLoaderOneshot.value
  sample.new_note_action = preferences.pakettiLoaderNNA.value
  sample.loop_release = preferences.pakettiLoaderLoopExit.value

  -- First marker at the very beginning
  new_smp:insert_slice_marker(1)
  dprint("Added initial slice marker at position 1")
  
  -- Track how many frames we've removed so far
  local frames_removed = 0
  
  -- Add ALL slice markers, including the first actual slice
  for i = 1, #slice_offsets do
    local original_pos = slice_offsets[i]
    
    -- Calculate frames removed before this slice
    -- Each header before this slice has removed header_len frames
    frames_removed = i * header_len
    
    -- Calculate the new position after header removal
    local new_pos = original_pos - frames_removed
    
    dprint(string.format("Slice %d: Original pos %d, removed %d frames before this, new pos %d", 
      i, original_pos, frames_removed, new_pos))
    
    if new_pos > 1 and new_pos <= new_frames then
      new_smp:insert_slice_marker(new_pos)
      dprint(string.format("Added slice marker %d at position %d", i, new_pos))
    else
      dprint(string.format("Skipping slice marker %d - position %d out of range (1-%d)", 
        i, new_pos, new_frames))
    end
  end
  dprint(string.format("Added %d slice markers in total (including start)", #slice_offsets + 1))

  -- Enable oversampling for all slices
  for i = 1, #new_smp.slice_markers do
    renoise.song().selected_instrument.samples[i+1].oversample_enabled = preferences.pakettiLoaderOverSampling.value
    dprint(string.format("Enabled oversampling for slice %d", i))
  end

  -- Set names
  new_smp.name = get_clean_filename(filename)
  song.selected_instrument.name = get_clean_filename(filename)
  renoise.song().instruments[renoise.song().selected_instrument_index].sample_modulation_sets[1].name=get_clean_filename(filename)
  renoise.song().instruments[renoise.song().selected_instrument_index].sample_device_chains[1].name=get_clean_filename(filename)

  os.remove(aiff_copy)
  dprint("Import completed successfully")

  if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then 
  if renoise.song().selected_track.type == 2 then renoise.app():show_status("*Instr. Macro Device will not be added to the Master track.") return else
    loadnative("Audio/Effects/Native/*Instr. Macros") 
    local macro_device = renoise.song().selected_track:device(2)
    macro_device.display_name = string.format("%02X", renoise.song().selected_instrument_index - 1) .. " " .. get_clean_filename(filename)
    renoise.song().selected_track.devices[2].is_maximized = false
  end
end
  renoise.app():show_status(string.format("REX cleaned and imported with %d slice markers", #slice_offsets))
  return true
end

local rex_integration = {
  category = "sample",
  extensions = { "rex" },
  invoke = rex_loadsample
}

if not renoise.tool():has_file_import_hook("sample", { "rex" }) then
  renoise.tool():add_file_import_hook(rex_integration)
end

-- DEBUG TOOL: Dump REX structure to .txt
local function bytes_to_hexstr(data)
  local out = {}
  for i = 1, #data do
    out[#out + 1] = string.format("%02X", data:byte(i))
    if i % 16 == 0 then out[#out + 1] = "\n" else out[#out + 1] = " " end
  end
  return table.concat(out)
end

local function dump_rex_structure(file_path)
  local f = io.open(file_path, "rb")
  if not f then
    renoise.app():show_status("Could not open file: " .. file_path)
    return
  end

  local d = f:read("*a")
  f:close()

  local filename_only = file_path:match("[^/\\]+$") or "rexfile"
  local out_path = file_path:gsub("%.rex$", "") .. "_rex_debug_dump.txt"
  local out = io.open(out_path, "w")

  out:write("REX Debug Dump: ", filename_only, "\n")
  out:write("File size: ", #d, " bytes\n\n")

  local rex_offset = d:find("REX ", 1, true)
  if not rex_offset then
    out:write("REX chunk not found.\n")
    out:close()
    renoise.app():show_status("REX chunk not found.")
    return
  end

  out:write("Found 'REX ' chunk at offset: ", rex_offset, "\n")
  out:write("Starting slice header table read from offset ", rex_offset + 1032, "\n\n")

  local pos = rex_offset + 1032
  local seen_offsets = {}

  for i = 1, 256 do
    if pos + 11 > #d then break end
    local slice_offset = read_dword(d, pos)
    local chunk_hex = d:sub(pos, pos + 11)
    if seen_offsets[slice_offset] then break end
    seen_offsets[slice_offset] = true
    out:write(string.format("Slice %3d @ offset: %d\n", i, slice_offset))
    out:write("  Raw Chunk (hex): ", bytes_to_hexstr(chunk_hex), "\n")
    pos = pos + 12
  end

  out:write("\n=== HEX DUMP AROUND REX CHUNK ===\n\n")
  local dump_start = math.max(1, rex_offset - 256)
  local dump_end = math.min(#d, rex_offset + 4096)
  out:write(bytes_to_hexstr(d:sub(dump_start, dump_end)))
  out:close()
  renoise.app():show_status("REX debug dump written to: " .. out_path)
end

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti..:Instruments..:REX Tools..:Dump REX Structure to Text",
  invoke = function()
    local file_path = renoise.app():prompt_for_filename_to_read({ "*.rex" }, "")
    if file_path then
      dump_rex_structure(file_path)
    end
  end
}


