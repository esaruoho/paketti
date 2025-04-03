-- Debug print helper
local _DEBUG = true
local function dprint(...) if _DEBUG then print("RX2 Debug:", ...) end end

-- Test FFI availability and set up REX bindings
local has_ffi, ffi = pcall(require, "ffi")
if has_ffi then
  dprint("FFI is available!")
  
  -- Define the C types and functions
  ffi.cdef[[
    typedef unsigned long Handle;
    typedef unsigned int uint32_t;
    
    typedef struct {
        uint32_t channels;
        uint32_t sampleRate;
        uint32_t slices;
        uint32_t tempo;
        uint32_t nativeTempo;
        uint32_t length;
        uint32_t unk1;
        uint32_t unk2;
        uint32_t bits;
    } Info;

    typedef struct {
        uint32_t position;
        uint32_t length;
    } Slice;

    typedef struct {
        char name[256];
        char copyright[256];
        char url[256];
        char email[256];
        char description[256];
    } Creator;

    typedef unsigned int (*fnCreateCallback)(long percent, void* data);
    
    uint32_t _Open(void);
    void _Close(void);
    uint32_t _REXCreate(Handle* handle, void* buffer, long size, fnCreateCallback callback, void* data);
    void _REXDelete(Handle* handle);
    uint32_t _REXGetInfo(Handle handle, long infoSize, Info* info);
    uint32_t _REXGetInfoFromBuffer(long size, void* buffer, long infoSize, Info* info);
    uint32_t _REXGetCreatorInfo(Handle handle, long infoSize, Creator* info);
    uint32_t _REXGetSliceInfo(Handle handle, long index, long infoSize, Slice* info);
    uint32_t _REXSetOutputSampleRate(Handle handle, long sampleRate);
    uint32_t _REXRenderSlice(Handle handle, long index, long length, float* buffers[2]);
    uint32_t _REXStartPreview(Handle handle);
    uint32_t _REXStopPreview(Handle handle);
    uint32_t _REXRenderPreviewBatch(Handle handle, long length, float* buffers[2]);
    uint32_t _REXSetPreviewTempo(Handle handle, long tempo);
  ]]

  -- Try to load the library
  local rex_lib
  local lib_paths = {
    "REX Shared Library.dll",  -- Current directory
    "C:/Program Files/Common Files/Propellerhead Software/REX Shared Library.dll",
    "C:/Program Files (x86)/Common Files/Propellerhead Software/REX Shared Library.dll"
  }
  
  for _, path in ipairs(lib_paths) do
    local success, lib = pcall(ffi.load, path)
    if success then
      rex_lib = lib
      dprint("Successfully loaded REX library from:", path)
      break
    else
      dprint("Failed to load from:", path, "Error:", lib)
    end
  end

  if not rex_lib then
    dprint("Could not load REX library. Please ensure REX Shared Library.dll is in the same directory as this script.")
  end
else
  dprint("FFI is not available:", ffi)
end

-- Helper function to convert bytes to hex string
local function bytes_to_hexstr(data)
  local out = {}
  for i = 1, #data do
    out[#out + 1] = string.format("%02X", data:byte(i))
    if i % 16 == 0 then out[#out + 1] = "\n" else out[#out + 1] = " " end
  end
  return table.concat(out)
end

-- Helper function to read big-endian DWORD
local function read_dword(data, pos)
  local b1, b2, b3, b4 = data:byte(pos, pos + 3)
  return (b1 * 16777216) + (b2 * 65536) + (b3 * 256) + b4
end

-- Helper function for bit operations (Lua 5.1 compatible)
local function byte_from_int(value, byte_pos)
    return math.floor(value / (256 ^ (3 - byte_pos))) % 256
end

-- Helper function to get clean filename
local function get_clean_filename(filepath)
  local filename = filepath:match("[^/\\]+$")
  if filename then return filename:gsub("%.rx2$", "") end
  return "RX2 Sample"
end

-- Function to dump RX2 structure to text file
local function dump_rx2_structure(file_path)
  dprint("Opening RX2 file for analysis...")
  local f = io.open(file_path, "rb")
  if not f then
    renoise.app():show_status("Could not open file: " .. file_path)
    return
  end

  local data = f:read("*a")
  f:close()

  local filename_only = file_path:match("[^/\\]+$") or "rx2file"
  local out_path = file_path:gsub("%.rx2$", "") .. "_rx2_debug_dump.txt"
  dprint("Creating debug dump file:", out_path)
  
  local out = io.open(out_path, "w")
  if not out then
    renoise.app():show_status("Could not create debug dump file: " .. out_path)
    return
  end

  out:write("RX2 Debug Dump: ", filename_only, "\n")
  out:write("File size: ", #data, " bytes\n\n")

  -- Look for various possible RX2 identifiers
  local identifiers = {"RX2 ", "REX2", "ReCy"}
  local found_id = nil
  local rx2_offset = nil

  for _, id in ipairs(identifiers) do
    local offset = data:find(id, 1, true)
    if offset then
      found_id = id
      rx2_offset = offset
      break
    end
  end

  if not rx2_offset then
    out:write("No RX2 identifier found. Dumping first 4KB for analysis:\n\n")
    out:write(bytes_to_hexstr(data:sub(1, 4096)))
    out:close()
    dprint("No RX2 identifier found in file")
    renoise.app():show_status("No RX2 identifier found. Debug dump written to: " .. out_path)
    return
  end

  dprint(string.format("Found '%s' identifier at offset: %d", found_id, rx2_offset))
  out:write(string.format("Found '%s' identifier at offset: %d\n", found_id, rx2_offset))
  
  -- Read RX2 header
  local header_data = data:sub(rx2_offset, rx2_offset + 64)
  out:write("\n=== RX2 HEADER ===\n")
  out:write("Magic: ", header_data:sub(1, 4), "\n")
  out:write("Header size: ", read_dword(data, rx2_offset + 8), "\n")
  
  -- Try to read name from header
  local name_start = rx2_offset + 32
  local name_end = data:find("\0", name_start) or (name_start + 32)
  local sample_name = data:sub(name_start, name_end - 1)
  out:write("Sample name: ", sample_name, "\n\n")

  -- Find SDAT chunk
  local pos = rx2_offset
  local sdat_pos = nil
  local sdat_size = nil

  out:write("=== CHUNK ANALYSIS ===\n")
  while pos < #data - 8 do
    local chunk_id = data:sub(pos, pos + 3)
    local chunk_size = read_dword(data, pos + 4)
    
    if chunk_size > 0 and chunk_size < #data then
      out:write(string.format("Chunk '%s' at offset %d, size %d bytes\n", 
        chunk_id, pos, chunk_size))
      
      if chunk_id == "SDAT" then
        sdat_pos = pos + 8  -- Skip chunk header
        sdat_size = chunk_size
        out:write(string.format("  -> SDAT chunk contains %d bytes of (compressed) audio data\n", sdat_size))
        -- Show first few bytes of SDAT
        out:write("  -> First 32 bytes: ", bytes_to_hexstr(data:sub(sdat_pos, sdat_pos + 31)), "\n")
      end
      pos = pos + 8 + chunk_size
    else
      pos = pos + 1
    end
  end
  out:write("\n")

  -- Try to find slice markers
  out:write("=== SLICE MARKER ANALYSIS ===\n")
  pos = rx2_offset
  local slice_offsets = {}
  local seen = {}
  local slice_count = 0
  local invalid_count = 0
  local additional_data_types = {}

  while pos < #data - 8 do
    local chunk_id = data:sub(pos, pos + 3)
    if chunk_id == "SLCE" then
      -- Read chunk header
      local chunk_size = read_dword(data, pos + 4)
      -- Each SLCE chunk should be 11 bytes (0x0B)
      if chunk_size == 11 then
        -- Read slice offset and additional data
        local slice_offset = read_dword(data, pos + 8)
        local additional_data = string.format("%02X %02X %02X %02X", 
          data:byte(pos + 12), data:byte(pos + 13),
          data:byte(pos + 14), data:byte(pos + 15))
        
        -- Track different types of additional data
        additional_data_types[additional_data] = (additional_data_types[additional_data] or 0) + 1
        
        if slice_offset > 0 then
          if additional_data == "00 00 00 01" and not seen[slice_offset] then
            slice_count = slice_count + 1
            out:write(string.format("Valid slice #%d at file offset %d: position %d (0x%08X)\n", 
              slice_count, pos, slice_offset, slice_offset))
            table.insert(slice_offsets, slice_offset)
            seen[slice_offset] = true
          else
            invalid_count = invalid_count + 1
            out:write(string.format("Skipping slice at offset %d - additional data: %s\n", 
              pos, additional_data))
          end
        end
      end
      pos = pos + 8 + chunk_size
    else
      pos = pos + 1
    end
  end

  -- Summary of slice types
  out:write("\n=== SLICE ANALYSIS SUMMARY ===\n")
  out:write(string.format("Total SLCE chunks found: %d\n", slice_count + invalid_count))
  out:write(string.format("Valid slices (00 00 00 01): %d\n", slice_count))
  out:write(string.format("Other slice types: %d\n", invalid_count))
  out:write("\nAdditional data types found:\n")
  for data_type, count in pairs(additional_data_types) do
    out:write(string.format("- %s: %d occurrences\n", data_type, count))
  end

  if #slice_offsets > 0 then
    -- Sort the slice offsets
    table.sort(slice_offsets)
    out:write("\nValid slice positions: " .. table.concat(slice_offsets, ", ") .. "\n")
  end

  -- Note about compression
  out:write("\n=== IMPORTANT NOTES ===\n")
  out:write("The RX2 format uses proprietary compression for audio data.\n")
  out:write("Current implementation writes compressed data directly to AIFF.\n")
  out:write("This may result in invalid audio until decompression is implemented.\n")

  out:close()
  dprint("Debug analysis completed")
  dprint("Debug dump written to:", out_path)
  renoise.app():show_status(string.format("RX2 analysis complete - debug dump written to: %s", out_path))
end

-- Function to read a string from data until null terminator
local function read_string(data, pos)
  local end_pos = data:find("\0", pos) or pos
  return data:sub(pos, end_pos - 1)
end

-- Function to read metadata from GLOB chunk
local function read_glob_chunk(data, pos, size)
  local info = {}
  if size >= 22 then
    info.tempo = read_dword(data, pos)
    info.time_sig_numerator = data:byte(pos + 4)
    info.time_sig_denominator = data:byte(pos + 5)
    -- More fields can be read here as we discover them
  end
  return info
end

-- Function to read metadata from RECY chunk
local function read_recy_chunk(data, pos, size)
  local info = {}
  if size >= 15 then
    info.version = string.format("%d.%d.%d", 
      data:byte(pos), data:byte(pos + 1), data:byte(pos + 2))
    -- More fields can be read here as we discover them
  end
  return info
end

-- Function to analyze slice markers and find valid groups
local function analyze_slice_markers(data, rx2_offset)
  local pos = rx2_offset
  local all_slices = {}
  local slice_types = {}
  
  -- First pass: collect all slice markers and their types
  while pos < #data - 8 do
    local chunk_id = data:sub(pos, pos + 3)
    if chunk_id == "SLCE" then
      local chunk_size = read_dword(data, pos + 4)
      if chunk_size == 11 then
        local slice_offset = read_dword(data, pos + 8)
        local additional_data = string.format("%02X %02X %02X %02X", 
          data:byte(pos + 12), data:byte(pos + 13),
          data:byte(pos + 14), data:byte(pos + 15))
        
        if slice_offset > 0 then
          table.insert(all_slices, {
            offset = slice_offset,
            type = additional_data,
            file_pos = pos
          })
          slice_types[additional_data] = (slice_types[additional_data] or 0) + 1
        end
      end
      pos = pos + 8 + chunk_size
    else
      pos = pos + 1
    end
  end

  -- Sort slices by position
  table.sort(all_slices, function(a, b) return a.offset < b.offset end)

  -- Find the primary sequence of slices
  local valid_slices = {}
  local last_offset = 0
  local min_slice_length = 100  -- Minimum reasonable slice length
  local max_gap_multiplier = 5  -- Maximum allowed gap is 5x the average gap
  local gaps = {}
  local sequence_start = nil
  local current_sequence = {}
  
  -- First, collect all potential primary slices
  for i, slice in ipairs(all_slices) do
    if slice.type == "00 00 00 01" then
      if #current_sequence == 0 then
        table.insert(current_sequence, slice)
      else
        local prev = current_sequence[#current_sequence]
        local gap = slice.offset - prev.offset
        
        -- If gap is reasonable, add to sequence
        if gap >= min_slice_length then
          table.insert(current_sequence, slice)
          table.insert(gaps, gap)
        else
          -- Gap too small, might be a duplicate or error
          dprint(string.format("Skipping too close slice at %d (gap: %d)", slice.offset, gap))
        end
      end
    end
  end

  -- Calculate average gap for the sequence
  local avg_gap = 0
  if #gaps > 0 then
    local sum = 0
    for _, gap in ipairs(gaps) do
      sum = sum + gap
    end
    avg_gap = sum / #gaps
    dprint(string.format("Average gap between slices: %d frames", avg_gap))
  end

  -- Now find the most consistent sequence
  local best_sequence = {}
  local best_score = 0
  local sequence_start = 1
  
  while sequence_start <= #current_sequence - 10 do  -- Need at least 10 slices to consider
    local test_sequence = {}
    local last_offset = current_sequence[sequence_start].offset
    local sequence_gaps = {}
    table.insert(test_sequence, current_sequence[sequence_start])
    
    for i = sequence_start + 1, #current_sequence do
      local gap = current_sequence[i].offset - last_offset
      -- Accept if gap is within reasonable range of average
      if gap >= min_slice_length and gap <= avg_gap * max_gap_multiplier then
        table.insert(test_sequence, current_sequence[i])
        table.insert(sequence_gaps, gap)
        last_offset = current_sequence[i].offset
      end
    end
    
    -- Score this sequence based on consistency of gaps
    if #test_sequence >= 10 then
      local score = #test_sequence  -- Longer sequences are better
      
      -- Calculate gap consistency
      local gap_variance = 0
      local gap_avg = 0
      if #sequence_gaps > 0 then
        local sum = 0
        for _, gap in ipairs(sequence_gaps) do
          sum = sum + gap
        end
        gap_avg = sum / #sequence_gaps
        
        -- Calculate variance
        for _, gap in ipairs(sequence_gaps) do
          gap_variance = gap_variance + math.abs(gap - gap_avg)
        end
        gap_variance = gap_variance / #sequence_gaps
      end
      
      -- Better (lower) variance increases score
      score = score * (1000000 / (gap_variance + 1000))
      
      if score > best_score then
        best_score = score
        best_sequence = test_sequence
      end
    end
    
    sequence_start = sequence_start + 1
  end

  -- Extract offsets from best sequence
  local valid_slices = {}
  for _, slice in ipairs(best_sequence) do
    table.insert(valid_slices, slice.offset)
    dprint(string.format("Found valid slice at position %d (type: %s)", 
      slice.offset, slice.type))
  end

  return valid_slices, slice_types
end

-- Function to read metadata from chunks
local function read_chunks(data, rx2_offset)
  local pos = rx2_offset
  local chunks = {}
  local sdat_pos, sdat_size
  
  while pos < #data - 8 do
    local chunk_id = data:sub(pos, pos + 3)
    -- Only try to read chunk size if we have a valid-looking chunk ID
    if chunk_id:match("^[%w%s]+$") then
      local chunk_size = read_dword(data, pos + 4)
      -- Sanity check the chunk size
      if chunk_size > 0 and chunk_size < #data - pos then
        dprint(string.format("Found chunk '%s' at offset %d, size %d bytes", 
          chunk_id, pos, chunk_size))
        
        if chunk_id == "GLOB" then
          chunks.glob = read_glob_chunk(data, pos + 8, chunk_size)
          if chunks.glob.tempo then
            dprint(string.format("Found tempo: %d BPM", chunks.glob.tempo))
          end
        elseif chunk_id == "RECY" then
          chunks.recy = read_recy_chunk(data, pos + 8, chunk_size)
          if chunks.recy.version then
            dprint(string.format("ReCycle version: %s", chunks.recy.version))
          end
        elseif chunk_id == "SDAT" then
          sdat_pos = pos + 8
          sdat_size = chunk_size
          dprint(string.format("Found SDAT chunk at offset %d, size %d bytes", sdat_pos, sdat_size))
        end
        
        pos = pos + 8 + chunk_size
      else
        pos = pos + 1
      end
    else
      pos = pos + 1
    end
  end
  
  return chunks, sdat_pos, sdat_size
end

-- Actual RX2 import function
function rx2_loadsample(filename)
  dprint("Starting RX2 import for file:", filename)
  
  -- First, create debug dump
  dump_rx2_structure(filename)
  dprint("Created debug dump file")

  local song = renoise.song()
  
  -- Initialize with Paketti default instrument
  renoise.song():insert_instrument_at(renoise.song().selected_instrument_index+1)
  renoise.song().selected_instrument_index = renoise.song().selected_instrument_index+1

  pakettiPreferencesDefaultInstrumentLoader()
  local smp = song.selected_sample
  dprint("Using Paketti default instrument configuration")
  
  -- Read source file
  local f_in = io.open(filename, "rb")
  if not f_in then
    dprint("ERROR: Cannot open source file")
    renoise.app():show_status("RX2 Import Error: Cannot open source file.")
    return false
  end
  
  local data = f_in:read("*a")
  f_in:close()
  dprint("Read source file, size:", #data, "bytes")

  -- Look for RX2 identifier
  local identifiers = {"RX2 ", "REX2", "ReCy"}
  local found_id = nil
  local rx2_offset = nil

  for _, id in ipairs(identifiers) do
    local offset = data:find(id, 1, true)
    if offset then
      found_id = id
      rx2_offset = offset
      break
    end
  end

  if not rx2_offset then
    dprint("ERROR: RX2 chunk not found in file")
    renoise.app():show_status("RX2 chunk not found")
    return false
  end
  dprint(string.format("Found '%s' chunk at offset: %d", found_id, rx2_offset))

  -- Read all chunks including metadata and SDAT position
  local chunks, sdat_pos, sdat_size = read_chunks(data, rx2_offset)

  if not sdat_pos then
    dprint("ERROR: Could not find SDAT chunk")
    renoise.app():show_status("RX2 Import Error: No sample data found.")
    return false
  end

  -- Create a debug AIFF file with the compressed data
  local aiff_path = filename:gsub("%.rx2$", "") .. "_rx2_debug.aiff"
  local f_aiff = io.open(aiff_path, "wb")
  if not f_aiff then
    dprint("ERROR: Cannot create debug AIFF file")
    return false
  end

  -- Calculate sizes
  local num_frames = math.floor(sdat_size / 4)  -- 2 channels * 16 bits = 4 bytes per frame
  local ssnd_size = sdat_size + 8  -- Add 8 for offset and block size
  local form_size = ssnd_size + 46  -- Total size minus FORM header

  dprint(string.format("Creating debug AIFF with %d frames", num_frames))

  -- Write AIFF header
  f_aiff:write("FORM")  -- FORM chunk ID
  f_aiff:write(string.char(  -- FORM chunk size
    byte_from_int(form_size, 0),
    byte_from_int(form_size, 1),
    byte_from_int(form_size, 2),
    byte_from_int(form_size, 3)))
  f_aiff:write("AIFF")  -- File type
  f_aiff:write("COMM")  -- Common chunk ID
  f_aiff:write(string.char(0, 0, 0, 18))  -- Common chunk size
  f_aiff:write(string.char(0, 2))  -- Number of channels (2)
  f_aiff:write(string.char(  -- Number of frames
    byte_from_int(num_frames, 0),
    byte_from_int(num_frames, 1),
    byte_from_int(num_frames, 2),
    byte_from_int(num_frames, 3)))
  f_aiff:write(string.char(0, 16))  -- Sample size (16 bits)
  f_aiff:write(string.char(  -- Sample rate 44100 as 80-bit extended
    0x40, 0x0E, 0xAC, 0x44, 0, 0, 0, 0, 0, 0))
  f_aiff:write("SSND")  -- Sound data chunk ID
  f_aiff:write(string.char(  -- Sound data chunk size
    byte_from_int(ssnd_size, 0),
    byte_from_int(ssnd_size, 1),
    byte_from_int(ssnd_size, 2),
    byte_from_int(ssnd_size, 3)))
  f_aiff:write(string.char(0, 0, 0, 0))  -- Offset
  f_aiff:write(string.char(0, 0, 0, 0))  -- Block size

  -- Write SDAT data
  dprint("Writing SDAT data to debug AIFF")
  f_aiff:write(data:sub(sdat_pos, sdat_pos + sdat_size - 1))
  f_aiff:close()
  dprint("Debug AIFF file created:", aiff_path)

  -- Now try to load the sample
  dprint("Attempting to load sample")
  local load_success = pcall(function() 
    smp.sample_buffer:load_from(aiff_path)
  end)
  
  if not load_success then
    dprint("ERROR: Failed to load sample")
    renoise.app():show_status("RX2 Import Error: Failed to load sample.")
    return false
  end
  
  if not smp.sample_buffer.has_sample_data then
    dprint("ERROR: No audio data loaded")
    renoise.app():show_status("RX2 Import Error: No audio data loaded.")
    return false
  end
  dprint("Sample loaded successfully")

  -- Find and analyze slice markers
  local slice_offsets, slice_types = analyze_slice_markers(data, rx2_offset)

  if #slice_offsets == 0 then
    dprint("WARNING: No valid slice offsets found")
    renoise.app():show_status("Warning: RX2 contained no valid slice offsets.")
  else
    dprint(string.format("Found %d valid slices", #slice_offsets))
  end

  -- Set names
  local clean_name = get_clean_filename(filename)
  smp.name = clean_name
  song.selected_instrument.name = clean_name
  renoise.song().instruments[renoise.song().selected_instrument_index].sample_modulation_sets[1].name = clean_name
  renoise.song().instruments[renoise.song().selected_instrument_index].sample_device_chains[1].name = clean_name

  -- Add slice markers
  if #slice_offsets > 0 then
    dprint("Adding slice markers")
    -- First marker at the very beginning
    smp:insert_slice_marker(1)
    dprint("Added initial slice marker at position 1")
    
    -- Add remaining slice markers
    for i, offset in ipairs(slice_offsets) do
      if offset > 1 and offset <= smp.sample_buffer.number_of_frames then
        smp:insert_slice_marker(offset)
        dprint(string.format("Added slice marker %d at position %d", i, offset))
      end
    end
  end

  -- Set sample properties
  smp.autofade = preferences.pakettiLoaderAutofade.value
  smp.autoseek = preferences.pakettiLoaderAutoseek.value
  smp.loop_mode = preferences.pakettiLoaderLoopMode.value
  smp.interpolation_mode = preferences.pakettiLoaderInterpolation.value
  smp.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  smp.oneshot = preferences.pakettiLoaderOneshot.value
  smp.new_note_action = preferences.pakettiLoaderNNA.value
  smp.loop_release = preferences.pakettiLoaderLoopExit.value

  dprint("Import completed successfully")
  renoise.app():show_status(string.format("RX2 imported with %d slice markers", #slice_offsets))
  return true
end

-- Register menu entries
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti..:Instruments..:REX Tools..:Dump RX2 Structure to Text...",
  invoke = function()
    local file_path = renoise.app():prompt_for_filename_to_read({ "rx2" }, "Select RX2 file to analyze")
    if file_path then
      dprint("Starting analysis of RX2 file:", file_path)
      dump_rx2_structure(file_path)
    end
  end
}

-- Register file import hook for RX2
local rx2_integration = {
  category = "sample",
  extensions = { "rx2" },
  invoke = rx2_loadsample
}

if not renoise.tool():has_file_import_hook("sample", { "rx2" }) then
  renoise.tool():add_file_import_hook(rx2_integration)
end 