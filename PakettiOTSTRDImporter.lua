-- PakettiOTSTRDImporter.lua
-- Octatrack .strd/.work → Renoise importer
-- Creates a Renoise song structure that mirrors the contents of an Octatrack project
-- Based on Octatrack STRD format reverse engineering
-- 
-- First release: 2025-01-01 – Paketti edition
-- Status: Enhanced - detects track count, instrument assignments, and project details

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

-- Read entire file as binary data
local function read_strd_file(path)
  print("PakettiOTSTRDImporter: Reading file: " .. path)
  local f, err = io.open(path, "rb")
  if not f then 
    print("PakettiOTSTRDImporter: Error opening file: " .. tostring(err))
    return nil, err 
  end
  local data = f:read("*all")
  f:close()
  print("PakettiOTSTRDImporter: Read " .. #data .. " bytes")
  return data
end

-- Read 32-bit big-endian unsigned integer
local function read_u32be(str, offset)
  if offset + 3 > #str then return 0 end
  local b1, b2, b3, b4 = str:byte(offset, offset + 3)
  return (b1 * 16777216) + (b2 * 65536) + (b3 * 256) + b4
end

-- Read 16-bit big-endian unsigned integer  
local function read_u16be(str, offset)
  if offset + 1 > #str then return 0 end
  local b1, b2 = str:byte(offset, offset + 1)
  return (b1 * 256) + b2
end

-- Read single byte
local function read_u8(str, offset)
  if offset > #str then return 0 end
  return str:byte(offset)
end

-- Read null-terminated string
local function read_string(str, offset, max_length)
  local result = ""
  local length = max_length or 32
  for i = 0, length - 1 do
    if offset + i > #str then break end
    local byte_val = str:byte(offset + i)
    if byte_val == 0 then break end
    result = result .. string.char(byte_val)
  end
  return result
end

-- Hexdump function for debugging
local function hexdump(data, start_offset, length, label)
  print("=== HEXDUMP: " .. label .. " ===")
  local end_offset = math.min(start_offset + length - 1, #data)
  
  for i = start_offset, end_offset, 16 do
    local hex_part = ""
    local ascii_part = ""
    local line_start = string.format("%08X: ", i - 1)
    
    for j = 0, 15 do
      if i + j <= end_offset then
        local byte_val = string.byte(data, i + j)
        hex_part = hex_part .. string.format("%02X ", byte_val)
        ascii_part = ascii_part .. (byte_val >= 32 and byte_val <= 126 and string.char(byte_val) or ".")
      else
        hex_part = hex_part .. "   "
        ascii_part = ascii_part .. " "
      end
    end
    
    print(line_start .. hex_part .. " |" .. ascii_part .. "|")
  end
  print("=== END HEXDUMP ===")
end

----------------------------------------------------------------------
-- Enhanced STRD Format Parser
----------------------------------------------------------------------

-- Enhanced trig structure detection
local function parse_trig_data(data, trig_byte, additional_bytes, step)
  local trig = nil
  
  -- Enhanced trig detection
  if trig_byte ~= 0 and trig_byte ~= 0xFF then
    -- Extract instrument and other parameters from additional bytes
    local instrument = 0
    local note = 48  -- Default C-4
    local velocity = 127
    local sample_slot = 0
    
    -- Try to extract instrument from following bytes
    if additional_bytes and #additional_bytes >= 2 then
      local param1 = additional_bytes[1]
      local param2 = additional_bytes[2]
      
      -- Instrument might be encoded in various ways
      if param1 ~= 0xFF and param1 ~= 0x00 then
        instrument = param1 % 16  -- Limit to reasonable instrument range
      end
      
      -- Sample slot from param2
      if param2 ~= 0xFF and param2 ~= 0x00 then
        sample_slot = param2 % 64
      end
    end
    
    -- Simple sample slot extraction from trig byte itself
    sample_slot = trig_byte % 64
    
    trig = {
      step = step,
      instrument = instrument,
      sample_slot = sample_slot,
      velocity = velocity,
      note = note,
      raw_byte = trig_byte
    }
  end
  
  return trig
end

-- Enhanced audio track parser
local function parse_audio_track_enhanced(data, offset, track_index)
  -- Standard Octatrack track size is 2048 bytes
  local TRACK_SIZE = 2048
  
  if offset + TRACK_SIZE > #data then
    print("PakettiOTSTRDImporter: Not enough data for TRAC chunk")
    return nil, offset
  end
  
  local trigs = {}
  local trig_count = 0
  local instruments_used = {}
  
  print(string.format("PakettiOTSTRDImporter: Parsing audio track %d at offset %d", track_index, offset))
  
  -- Debug: Show track header
  hexdump(data, offset, 64, string.format("AUDIO TRACK %d HEADER", track_index))
  
  -- Enhanced trig parsing - look for pattern in data
  -- Octatrack stores trig data in a structured format
  local trig_data_start = offset
  local step = 0
  
  -- Parse 64 steps (standard Octatrack pattern length)
  for i = 0, 63 do
    local trig_offset = trig_data_start + (i * 16)  -- Each trig might be 16 bytes
    
    if trig_offset + 15 < offset + TRACK_SIZE then
      local trig_byte = read_u8(data, trig_offset)
      
      -- Get additional parameter bytes
      local additional_bytes = {}
      for j = 1, 15 do
        if trig_offset + j <= offset + TRACK_SIZE then
          table.insert(additional_bytes, read_u8(data, trig_offset + j))
        end
      end
      
      local trig = parse_trig_data(data, trig_byte, additional_bytes, i)
      
      if trig then
        table.insert(trigs, trig)
        trig_count = trig_count + 1
        
        -- Track unique instruments
        if not instruments_used[trig.instrument] then
          instruments_used[trig.instrument] = true
          print(string.format("PakettiOTSTRDImporter: Track %d uses instrument %d", track_index, trig.instrument))
        end
        
        if trig_count <= 8 then -- Show first few trigs for debugging
          print(string.format("PakettiOTSTRDImporter: Track %d, Step %d - Inst: %d, Sample: %d, Raw: 0x%02X", 
            track_index, i, trig.instrument, trig.sample_slot, trig.raw_byte))
        end
      end
    end
  end
  
  -- Convert instruments_used table to array
  local instrument_list = {}
  for inst, _ in pairs(instruments_used) do
    table.insert(instrument_list, inst)
  end
  table.sort(instrument_list)
  
  print(string.format("PakettiOTSTRDImporter: Audio track %d - %d trigs, instruments: %s", 
    track_index, trig_count, table.concat(instrument_list, ", ")))
  
  return {
    type = "audio",
    index = track_index,
    trigs = trigs,
    instruments_used = instrument_list,
    trig_count = trig_count
  }, offset + TRACK_SIZE
end

-- Enhanced MIDI track parser
local function parse_midi_track_enhanced(data, offset, track_index)
  local MIDI_TRACK_SIZE = 1024
  
  if offset + MIDI_TRACK_SIZE > #data then
    return nil, offset
  end
  
  print(string.format("PakettiOTSTRDImporter: Parsing MIDI track %d at offset %d", track_index, offset))
  
  -- For now, basic MIDI track handling
  return {
    type = "midi",
    index = track_index,
    trigs = {},
    instruments_used = {},
    trig_count = 0
  }, offset + MIDI_TRACK_SIZE
end

-- Enhanced pattern header parser
local function parse_pattern_header_enhanced(data, offset)
  print("PakettiOTSTRDImporter: Parsing enhanced pattern header at offset " .. offset)
  
  -- Look for next chunk to determine header size
  local search_end = math.min(offset + 128, #data)
  local next_chunk_offset = nil
  
  for i = offset, search_end - 4 do
    local potential_chunk = data:sub(i, i + 3)
    if potential_chunk == "TRAC" or potential_chunk == "MTRA" then
      next_chunk_offset = i
      print("PakettiOTSTRDImporter: Found next chunk '" .. potential_chunk .. "' at offset " .. i)
      break
    end
  end
  
  local header_size = next_chunk_offset and (next_chunk_offset - offset) or 64
  print("PakettiOTSTRDImporter: Pattern header size: " .. header_size .. " bytes")
  
  -- Show header for analysis
  if header_size > 0 then
    hexdump(data, offset, math.min(header_size, 64), "ENHANCED PATTERN HEADER")
  end
  
  -- Enhanced header parsing
  local length = 16    -- Default pattern length
  local tempo = 120    -- Default tempo
  local swing = 0      -- Default swing
  local time_signature = 4
  local scale = "CHRO"  -- Default chromatic
  
  -- Try to extract more detailed pattern info
  if header_size >= 8 then
    local test_length = read_u8(data, offset)
    local test_tempo = read_u8(data, offset + 1)
    
    -- Pattern length (steps)
    if test_length > 0 and test_length <= 64 then
      length = test_length
    end
    
    -- Tempo extraction
    if test_tempo > 0 and test_tempo < 200 then
      tempo = test_tempo + 60  -- Octatrack tempo offset
    end
    
    swing = read_u8(data, offset + 2)
    time_signature = read_u8(data, offset + 3)
    
    -- Try to read scale information if available
    if header_size >= 8 then
      local scale_bytes = {}
      for i = 4, 7 do
        if offset + i <= #data then
          local byte_val = read_u8(data, offset + i)
          if byte_val >= 32 and byte_val <= 126 then
            table.insert(scale_bytes, string.char(byte_val))
          end
        end
      end
      if #scale_bytes > 0 then
        scale = table.concat(scale_bytes, "")
      end
    end
  end
  
  print(string.format("PakettiOTSTRDImporter: Enhanced Pattern - Length: %d, Tempo: %d, Swing: %d, Scale: %s", 
    length, tempo, swing, scale))
  
  local header_end = next_chunk_offset or (offset + header_size)
  
  return {
    length = length,
    tempo = tempo,
    swing = swing,
    time_signature = time_signature,
    scale = scale
  }, header_end
end

-- Enhanced main STRD parser with proper track detection
local function parse_strd_data_enhanced(data)
  print("PakettiOTSTRDImporter: Starting enhanced STRD parse...")
  
  -- Show file header for analysis
  hexdump(data, 1, 256, "STRD FILE HEADER (Enhanced Analysis)")
  
  local patterns = {}
  local project_info = {
    total_tracks = 0,
    total_patterns = 0,
    instruments_detected = {},
    tempo = 120
  }
  local offset = 1
  local pattern_count = 0
  
  -- Skip FORM header if present
  if data:sub(1, 4) == "FORM" then
    print("PakettiOTSTRDImporter: Found FORM header")
    local form_size = read_u32be(data, 5)
    print("PakettiOTSTRDImporter: FORM size: " .. form_size .. " bytes")
    offset = offset + 8  -- Skip FORM + size
    
    -- Read the format type (should be "DPS1")
    if data:sub(offset, offset + 3) == "DPS1" then
      print("PakettiOTSTRDImporter: Format type: DPS1")
      offset = offset + 4
    end
  end
  
  -- Skip BANK chunk if present
  if data:sub(offset, offset + 3) == "BANK" then
    print("PakettiOTSTRDImporter: Found BANK chunk")
    local bank_size = read_u32be(data, offset + 4)
    print("PakettiOTSTRDImporter: BANK size: " .. bank_size .. " bytes")
    offset = offset + 8  -- Skip BANK + size
  end
  
  -- Enhanced pattern detection
  while offset <= #data - 4 do
    local chunk_id = data:sub(offset, offset + 3)
    
    if chunk_id == "PTRN" then
      pattern_count = pattern_count + 1
      print(string.format("PakettiOTSTRDImporter: Found pattern %d at offset %d", pattern_count, offset))
      
      local pattern_size = read_u32be(data, offset + 4)
      print("PakettiOTSTRDImporter: Pattern size: " .. pattern_size .. " bytes")
      
      -- Skip PTRN header
      local pattern_data_start = offset + 8
      
      -- Parse pattern header
      local pattern_header, header_end = parse_pattern_header_enhanced(data, pattern_data_start)
      
      -- Find all track chunks for this pattern
      local tracks = {}
      local search_offset = header_end
      local tracks_found = 0
      local pattern_instruments = {}
      
      -- Enhanced track detection - count actual tracks
      while search_offset <= #data - 4 and tracks_found < 8 do  -- Octatrack has max 8 tracks
        local track_id = data:sub(search_offset, search_offset + 3)
        
        if track_id == "TRAC" then
          tracks_found = tracks_found + 1
          print(string.format("PakettiOTSTRDImporter: Found TRAC %d at offset %d", tracks_found, search_offset))
          
          -- Parse audio track with enhanced detection
          local track, next_offset = parse_audio_track_enhanced(data, search_offset + 8, tracks_found)
          if track then
            table.insert(tracks, track)
            
            -- Merge instruments used in this track
            for _, inst in ipairs(track.instruments_used) do
              pattern_instruments[inst] = true
              project_info.instruments_detected[inst] = true
            end
            
            print(string.format("PakettiOTSTRDImporter: Audio track %d parsed - %d trigs", 
              tracks_found, track.trig_count))
          end
          search_offset = next_offset
          
        elseif track_id == "MTRA" then
          tracks_found = tracks_found + 1
          print(string.format("PakettiOTSTRDImporter: Found MTRA %d at offset %d", tracks_found, search_offset))
          
          -- Parse MIDI track with enhanced detection
          local track, next_offset = parse_midi_track_enhanced(data, search_offset + 8, tracks_found)
          if track then
            table.insert(tracks, track)
            print(string.format("PakettiOTSTRDImporter: MIDI track %d parsed", tracks_found))
          end
          search_offset = next_offset
          
        elseif track_id == "PTRN" then
          -- Found next pattern, stop looking for tracks
          print("PakettiOTSTRDImporter: Found next pattern, stopping track search")
          break
          
        else
          -- Keep searching
          search_offset = search_offset + 1
        end
      end
      
      -- Update project statistics
      project_info.total_tracks = math.max(project_info.total_tracks, tracks_found)
      
      -- Convert pattern_instruments to array
      local pattern_inst_list = {}
      for inst, _ in pairs(pattern_instruments) do
        table.insert(pattern_inst_list, inst)
      end
      table.sort(pattern_inst_list)
      
      print(string.format("PakettiOTSTRDImporter: Pattern %d completed - %d tracks, instruments: %s", 
        pattern_count, #tracks, table.concat(pattern_inst_list, ", ")))
      
      -- Create enhanced pattern
      table.insert(patterns, {
        index = pattern_count,
        header = pattern_header,
        tracks = tracks,
        track_count = tracks_found,
        instruments_used = pattern_inst_list
      })
      
      -- Move to search for next pattern
      offset = search_offset
      
    else
      -- Keep searching for PTRN chunks
      offset = offset + 1
    end
  end
  
  project_info.total_patterns = #patterns
  
  -- Convert project instruments to array
  local project_inst_list = {}
  for inst, _ in pairs(project_info.instruments_detected) do
    table.insert(project_inst_list, inst)
  end
  table.sort(project_inst_list)
  
  print("=== ENHANCED PROJECT SUMMARY ===")
  print(string.format("Total patterns: %d", project_info.total_patterns))
  print(string.format("Max tracks per pattern: %d", project_info.total_tracks))
  print(string.format("Instruments detected: %s", table.concat(project_inst_list, ", ")))
  print("=================================")
  
  return patterns, project_info
end

----------------------------------------------------------------------
-- Enhanced Renoise Integration
----------------------------------------------------------------------

-- Enhanced pattern import with proper instrument mapping
local function import_patterns_to_renoise_enhanced(patterns, project_info)
  local song = renoise.song()
  
  if #patterns == 0 then
    renoise.app():show_warning("No valid patterns found in STRD file")
    return
  end
  
  print(string.format("PakettiOTSTRDImporter: Importing %d patterns with enhanced detection", #patterns))
  
  -- Ensure we have enough tracks in Renoise
  local required_tracks = project_info.total_tracks
  while #song.tracks < required_tracks do
    song:insert_group_at(#song.tracks + 1)
    local new_track = song:track(#song.tracks)
    new_track.name = string.format("OT Track %d", #song.tracks)
  end
  
  -- Ensure we have enough instruments for all detected instruments
  local max_instrument = 0
  for inst, _ in pairs(project_info.instruments_detected) do
    max_instrument = math.max(max_instrument, inst)
  end
  
  while #song.instruments <= max_instrument do
    song:insert_instrument_at(#song.instruments + 1)
    local new_inst = song:instrument(#song.instruments)
    new_inst.name = string.format("OT Instrument %02d", #song.instruments - 1)
  end
  
  -- Ensure we have enough pattern slots
  while #song.sequencer.pattern_sequence < #patterns do
    song.sequencer:insert_new_pattern_at(#song.sequencer.pattern_sequence + 1)
  end
  
  -- Import each pattern with enhanced data
  for pattern_idx, octatrack_pattern in ipairs(patterns) do
    local renoise_pattern_slot = song.sequencer.pattern_sequence[pattern_idx]
    local renoise_pattern = song.patterns[renoise_pattern_slot]
    
    -- Set pattern length
    local pattern_length = math.max(1, math.min(512, octatrack_pattern.header.length))
    renoise_pattern.number_of_lines = pattern_length
    
    print(string.format("PakettiOTSTRDImporter: Importing pattern %d (%d lines, %d tracks)", 
      pattern_idx, pattern_length, octatrack_pattern.track_count))
    
    -- Import tracks with proper instrument mapping
    for track_idx, octatrack_track in ipairs(octatrack_pattern.tracks) do
      if octatrack_track.type == "audio" and track_idx <= #song.tracks then
        local renoise_track = renoise_pattern:track(track_idx)
        
        -- Import trigs as notes with proper instrument assignments
        for _, trig in ipairs(octatrack_track.trigs) do
          local line_idx = math.max(1, math.min(pattern_length, trig.step + 1))
          local renoise_line = renoise_track:line(line_idx)
          local note_column = renoise_line.note_columns[1]
          
          -- Set note and proper instrument
          note_column.note_value = trig.note or 48
          note_column.instrument_value = math.min(trig.instrument, #song.instruments - 1)
          note_column.volume_value = renoise.PatternTrackLine.EMPTY_VOLUME
          
          -- Add slice command in effect column if sample slot specified
          if trig.sample_slot and trig.sample_slot > 0 then
            local effect_column = renoise_line.effect_columns[1]
            effect_column.number_string = "0S" -- Slice command
            effect_column.amount_value = math.min(255, trig.sample_slot)
          end
          
          print(string.format("PakettiOTSTRDImporter: Pattern %d, Track %d, Line %d - Note: %d, Inst: %d, Sample: %d", 
            pattern_idx, track_idx, line_idx, trig.note or 48, trig.instrument, trig.sample_slot or 0))
        end
      end
    end
  end
  
  -- Set song tempo based on first pattern
  if patterns[1] and patterns[1].header.tempo then
    song.transport.bpm = patterns[1].header.tempo
    print("PakettiOTSTRDImporter: Set song tempo to " .. patterns[1].header.tempo)
  end
  
  -- Show import summary
  local summary = string.format("Successfully imported %d patterns, %d tracks, instruments: %d-%d", 
    #patterns, project_info.total_tracks, 0, max_instrument)
  renoise.app():show_status(summary)
  print("PakettiOTSTRDImporter: " .. summary)
end

----------------------------------------------------------------------
-- Main Enhanced Import Function
----------------------------------------------------------------------

function PakettiOTSTRDImporter()
  local file_extensions = {"*.strd", "*.work"}
  local filename = renoise.app():prompt_for_filename_to_read(file_extensions, "Import Octatrack Bank (.strd/.work)")
  
  if not filename or filename == "" then
    print("PakettiOTSTRDImporter: Import cancelled by user")
    return
  end
  
  renoise.app():show_status("Importing Octatrack STRD file (Enhanced)...")
  
  local data, err = read_strd_file(filename)
  if not data then
    renoise.app():show_error("Could not read STRD file: " .. tostring(err))
    return
  end
  
  local patterns, project_info = parse_strd_data_enhanced(data)
  if #patterns == 0 then
    renoise.app():show_warning("No patterns found in STRD file. The file may be corrupted or use an unsupported format.")
    return
  end
  
  import_patterns_to_renoise_enhanced(patterns, project_info)
  
  local status_msg = string.format("Octatrack STRD imported: %d patterns, %d tracks, instruments detected", 
    #patterns, project_info.total_tracks)
  renoise.app():show_status(status_msg)
  print("PakettiOTSTRDImporter: " .. status_msg)
end

----------------------------------------------------------------------
-- Enhanced Drag & Drop Support
----------------------------------------------------------------------

-- Enhanced import from file path
function PakettiOTSTRDImportFile(filepath)
  if not filepath or filepath == "" then
    print("PakettiOTSTRDImporter: No file path provided")
    return false
  end
  
  -- Check file extension
  local ext = filepath:lower():match("%.([^%.]+)$")
  if ext ~= "strd" and ext ~= "work" then
    print("PakettiOTSTRDImporter: Not a STRD/WORK file: " .. filepath)
    return false
  end
  
  print("PakettiOTSTRDImporter: Enhanced import for: " .. filepath)
  renoise.app():show_status("Importing Octatrack STRD file (Enhanced)...")
  
  local data, err = read_strd_file(filepath)
  if not data then
    renoise.app():show_error("Could not read STRD file: " .. tostring(err))
    return false
  end
  
  local patterns, project_info = parse_strd_data_enhanced(data)
  if #patterns == 0 then
    renoise.app():show_warning("No patterns found in STRD file. The file may be corrupted or use an unsupported format.")
    return false
  end
  
  import_patterns_to_renoise_enhanced(patterns, project_info)
  
  local status_msg = string.format("Octatrack STRD imported: %d patterns, %d tracks, instruments detected", 
    #patterns, project_info.total_tracks)
  renoise.app():show_status(status_msg)
  print("PakettiOTSTRDImporter: " .. status_msg)
  
  return true
end

-- File import hook for .strd and .work files (drag & drop support)
function strd_import_filehook(filename)
  if not filename then
    renoise.app():show_error("STRD Import Error: No filename provided!")
    return false
  end

  print("Starting STRD import via file hook for file:", filename)
  
  -- Import the STRD file
  local success = PakettiOTSTRDImportFile(filename)
  
  if success then
    renoise.app():show_status("STRD Import: Successfully imported " .. (filename:match("([^/\\]+)$") or filename))
    print("STRD Import: Successfully imported file:", filename)
  else
    renoise.app():show_status("STRD Import: Failed to import " .. (filename:match("([^/\\]+)$") or filename))
    print("STRD Import: Failed to import file:", filename)
  end
  
  return success
end

-- Register the file import hook for .strd and .work files
local strd_integration = {
  category = "song",
  extensions = { "strd", "work" },
  invoke = strd_import_filehook
}

if not renoise.tool():has_file_import_hook("song", { "strd", "work" }) then
  renoise.tool():add_file_import_hook(strd_integration)
  
end

renoise.tool():add_keybinding{name="Global:Paketti:Octatrack Import STRD Bank",invoke=function() PakettiOTSTRDImporter() end}

 