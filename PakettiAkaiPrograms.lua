--[[============================================================================
PakettiAkaiPrograms.lua — Support for Akai Program formats (.p, .pgm)
============================================================================]]--

-- Helper: debug print
local function debug_print(...)
  print("[Akai Programs]", ...)
end

-- Import functions for different program formats
function importAkaiProgram(file_path)
  if not file_path then
    file_path = renoise.app():prompt_for_filename_to_read(
      {"*.p", "*.pgm"}, "Import Akai Program File"
    )
    if not file_path or file_path == "" then
      renoise.app():show_status("No file selected")
      return
    end
  end
  
  local extension = file_path:lower():match("%.([^.]+)$")
  debug_print("Importing Akai program file:", file_path, "extension:", extension)
  
  if extension == "p" then
    importS1000Program(file_path)
  elseif extension == "pgm" then
    -- Use unified MPC program importer with proper format detection
    importMPCProgram(file_path)
  else
    renoise.app():show_status("Unsupported program format: " .. (extension or "unknown"))
  end
end

-- Helper: convert unsigned byte to signed (two's complement)
local function byte_to_twos_complement(byte_val)
  return byte_val >= 128 and byte_val - 256 or byte_val
end

-- Helper: AKAII to ASCII conversion (same as S1000 sample files)
local AKAII_CHARS = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"

local function akaii_to_ascii(akaii_str)
  local result = ""
  for i = 1, #akaii_str do
    local byte_val = akaii_str:byte(i)
    if byte_val == 0 then
      break -- null terminator
    elseif byte_val >= 32 and byte_val <= 126 then
      result = result .. AKAII_CHARS:sub(byte_val - 31, byte_val - 31)
    else
      result = result .. " " -- fallback for invalid chars
    end
  end
  return result:match("^%s*(.-)%s*$") -- trim whitespace
end

-- Parse S1000 Program (.p) file
local function parse_s1000_program(data)
  if #data < 150 then
    error("File too small to be S1000 program file")
  end
  
  -- Validation using reference approach
  if data:byte(1) ~= 1 then
    error("Invalid S1000 program file (byte 1 should be 1)")
  end
  
  local program = {}
  
  -- Extract instrument name (AKAII encoded, bytes 4-15)
  program.instrument_name = akaii_to_ascii(data:sub(4, 15))
  debug_print("Program name:", program.instrument_name)
  
  -- Parse sample chunks (150 bytes each, starting from byte 150)
  program.samples = {}
  local chunk_count = math.floor(#data / 150)
  
  for chunk_idx = 1, chunk_count - 1 do -- Skip first chunk (header)
    local chunk_start = 1 + (chunk_idx * 150)
    
    if chunk_start + 149 <= #data then
      -- Extract zone parameters
      local zone_key_lo = data:byte(chunk_start + 4)
      local zone_key_hi = data:byte(chunk_start + 5)
      local zone_transpose = byte_to_twos_complement(data:byte(chunk_start + 6))
      local zone_finetune = byte_to_twos_complement(data:byte(chunk_start + 7))
      
      debug_print("Zone", chunk_idx, "keys:", zone_key_lo .. "-" .. zone_key_hi, 
                 "transpose:", zone_transpose, "finetune:", zone_finetune)
      
      -- Parse up to 3 samples per zone (sample offsets: 35, 69, 103)
      for sample_slot = 1, 3 do
        local sample_offset = 35 + (sample_slot - 1) * 34 -- 35, 69, 103
        local sample_data_start = chunk_start + sample_offset
        
        if sample_data_start + 33 <= #data then
          -- Check if sample slot is used
          local first_byte = data:byte(sample_data_start)
          if first_byte ~= 10 and first_byte ~= 0 then
            
            -- Extract sample info
            local vel_lo = data:byte(sample_data_start + 12)
            local vel_hi = data:byte(sample_data_start + 13)
            local sample_finetune = byte_to_twos_complement(data:byte(sample_data_start + 14))
            local sample_transpose = byte_to_twos_complement(data:byte(sample_data_start + 15))
            
            -- Extract sample name (AKAII encoded, 12 bytes)
            local sample_name = akaii_to_ascii(data:sub(sample_data_start, sample_data_start + 11))
            sample_name = sample_name:match("^%s*(.-)%s*$") -- trim whitespace
            if sample_name ~= "" then
              sample_name = sample_name .. ".s"
              
              -- Calculate total transpose and finetune
              local total_transpose = zone_transpose + sample_transpose
              local total_finetune = zone_finetune + sample_finetune
              
              -- Add to samples table
              table.insert(program.samples, {
                sample_name = sample_name,
                zone_key_lo = zone_key_lo,
                zone_key_hi = zone_key_hi,
                vel_lo = vel_lo,
                vel_hi = vel_hi,
                transpose = total_transpose,
                finetune = total_finetune
              })
              
              debug_print("  Sample:", sample_name, "vel:", vel_lo .. "-" .. vel_hi,
                         "transpose:", total_transpose, "finetune:", total_finetune)
            end
          end
        end
      end
    end
  end
  
  debug_print("Parsed", #program.samples, "sample references from program")
  return program
end

-- Get directory from file path
local function get_directory_from_path(file_path)
  return file_path:match("^(.*)[/\\][^/\\]*$") or "."
end

-- Check if file exists
local function file_exists(file_path)
  local f = io.open(file_path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

-- Get base note from .s sample file (simplified version)
local function get_base_note_from_sample(sample_path)
  local f = io.open(sample_path, "rb")
  if not f then return 60 end
  
  local header = f:read(150)
  f:close()
  
  if header and #header >= 3 then
    -- Base note is at byte 3 in S1000 .s files
    return header:byte(3)
  end
  return 60 -- fallback
end

-- S1000 Program (.p) support
function importS1000Program(file_path)
  if not file_path then
    file_path = renoise.app():prompt_for_filename_to_read(
      {"*.p"}, "Import S1000 Program"
    )
    if not file_path or file_path == "" then
      renoise.app():show_status("No file selected")
      return
    end
  end
  
  print("---------------------------------")
  debug_print("Importing S1000 program (.p):", file_path)
  renoise.app():show_status("Importing Akai S1000 Program...")
  
  -- Load and parse program file
  local f, err = io.open(file_path, "rb")
  if not f then
    error("Could not open file: " .. err)
  end
  local data = f:read("*all")
  f:close()
  
  local program = parse_s1000_program(data)
  
  if #program.samples == 0 then
    renoise.app():show_status("No sample references found in program")
    return
  end
  
  if #program.samples > 254 then
    renoise.app():show_error("Program has too many samples for Renoise (limit: 255)")
    return
  end
  
  -- Find sample directory
  local program_dir = get_directory_from_path(file_path)
  debug_print("Looking for samples in:", program_dir)
  
  -- Create new instrument
  local song = renoise.song()
  local current_idx = song.selected_instrument_index
  local new_idx = current_idx + 1
  if not safeInsertInstrumentAt(song, new_idx) then return end
  song.selected_instrument_index = new_idx

  local instrument = song.instruments[new_idx]
  instrument.name = program.instrument_name
  
  -- Clear existing samples
  while #instrument.samples > 0 do
    instrument:delete_sample_at(1)
  end
  
  local missing_samples = 0
  local loaded_samples = 0
  
  -- Load each sample reference
  for i, sample_info in ipairs(program.samples) do
    local sample_path = program_dir .. "/" .. sample_info.sample_name
    
    -- Try variations if file not found
    if not file_exists(sample_path) then
      -- Try uppercase extension
      sample_path = sample_path:gsub("%.s$", ".S")
    end
    
    if file_exists(sample_path) then
      debug_print("Loading sample:", sample_path)
      
      -- Import the .s file using existing S1000 importer
      local ok, err = pcall(function()
        importS1000Sample(sample_path)
      end)
      
      if ok then
        -- Get the newly loaded sample (it was loaded into a new instrument)
        local temp_instrument = song.instruments[song.selected_instrument_index]
        if #temp_instrument.samples > 0 then
          local loaded_sample = temp_instrument.samples[1]
          
          -- Move sample to our program instrument
          local new_sample_idx = #instrument.samples + 1
          instrument:insert_sample_at(new_sample_idx)
          local target_sample = instrument.samples[new_sample_idx]
          
          -- Copy sample data and properties
          target_sample.sample_buffer:create_sample_data(
            loaded_sample.sample_buffer.sample_rate,
            loaded_sample.sample_buffer.bit_depth,
            loaded_sample.sample_buffer.number_of_channels,
            loaded_sample.sample_buffer.number_of_frames
          )
          
          target_sample.sample_buffer:prepare_sample_data_changes()
          for ch = 1, loaded_sample.sample_buffer.number_of_channels do
            for frame = 1, loaded_sample.sample_buffer.number_of_frames do
              target_sample.sample_buffer:set_sample_data(ch, frame, 
                loaded_sample.sample_buffer:sample_data(ch, frame))
            end
          end
          target_sample.sample_buffer:finalize_sample_data_changes()
          
          -- Apply program settings
          target_sample.name = sample_info.sample_name
          target_sample.transpose = math.max(-127, math.min(127, sample_info.transpose))
          target_sample.fine_tune = math.max(-127, math.min(127, sample_info.finetune))
          target_sample.volume = math.db2lin(-3) -- Reference uses -3dB
          
          -- Get base note from sample
          local base_note = get_base_note_from_sample(sample_path)
          
          -- Create sample mapping with ranges
          target_sample.sample_mapping.base_note = base_note
          target_sample.sample_mapping.note_range = {
            math.max(0, math.min(119, sample_info.zone_key_lo)),
            math.max(0, math.min(119, sample_info.zone_key_hi))
          }
          target_sample.sample_mapping.velocity_range = {
            math.max(0, math.min(127, sample_info.vel_lo)),
            math.max(0, math.min(127, sample_info.vel_hi))
          }
          
          debug_print("Mapped sample:", sample_info.sample_name, 
                     "notes:", target_sample.sample_mapping.note_range[1] .. "-" .. target_sample.sample_mapping.note_range[2],
                     "vel:", target_sample.sample_mapping.velocity_range[1] .. "-" .. target_sample.sample_mapping.velocity_range[2])
          
          loaded_samples = loaded_samples + 1
        end
        
        -- Clean up temporary instrument
        song:delete_instrument_at(song.selected_instrument_index)
        song.selected_instrument_index = new_idx
        
      else
        debug_print("Failed to load sample:", sample_path, "Error:", err)
        missing_samples = missing_samples + 1
      end
    else
      debug_print("Sample not found:", sample_path)
      missing_samples = missing_samples + 1
    end
    
    -- Update progress
    local progress = math.floor((i / #program.samples) * 100)
    renoise.app():show_status(string.format("Importing S1000 program (%d%% done)...", progress))
  end
  
  -- Final status
  if missing_samples == 0 then
    renoise.app():show_status("S1000 program import complete: " .. loaded_samples .. " samples loaded")
  else
    local msg = string.format("S1000 program partially complete: %d loaded, %d missing", loaded_samples, missing_samples)
    renoise.app():show_status(msg)
    renoise.app():show_warning(string.format("%d samples could not be found when importing this program file.", missing_samples))
  end
  
  debug_print("Import complete:", loaded_samples, "loaded,", missing_samples, "missing")
end

function exportS1000Program()
  local output_path = renoise.app():prompt_for_filename_to_write("*.p", "Export S1000 Program"
  )
  
  if not output_path or output_path == "" then
    renoise.app():show_status("No file selected")
    return
  end
  
  debug_print("Exporting S1000 program (.p):", output_path)
  renoise.app():show_status("S1000 program export not fully implemented yet")
  -- TODO: Implement export functionality
end

-- Helper: read little-endian 16-bit word
local function read_le_u16_from_memory(data, offset)
  if offset > #data - 1 then return 0 end
  local b1, b2 = data:byte(offset, offset + 1)
  return b2 * 256 + b1
end

-- Helper: read little-endian 32-bit dword
local function read_le_u32_from_memory(data, offset)
  if offset > #data - 3 then return 0 end
  local b1, b2, b3, b4 = data:byte(offset, offset + 3)
  return b4 * 16777216 + b3 * 65536 + b2 * 256 + b1
end

-- Helper: read null-terminated string
local function read_string_from_memory(data, offset, max_len)
  local result = ""
  for i = 0, max_len - 1 do
    if offset + i > #data then break end
    local byte_val = data:byte(offset + i)
    if byte_val == 0 then break end
    result = result .. string.char(byte_val)
  end
  return result
end

-- Helper: convert word to two's complement
local function word_to_twos_complement(word_val)
  return word_val >= 32768 and word_val - 65536 or word_val
end

-- MPC1000 PGM validation
local function is_mpc1000_pgm(data)
  return read_le_u16_from_memory(data, 1) == 10756
end

-- MPC2000 PGM validation  
local function is_mpc2000_pgm(data)
  return read_le_u16_from_memory(data, 1) == 1031
end

-- Import MPC1000 PGM
local function import_mpc1000_pgm(file_path, data)
  debug_print("Importing MPC1000 PGM format")
  
  local program_dir = get_directory_from_path(file_path)
  local samples = {}
  local midimap = {}
  
  -- Parse samples from 64 pads (164 bytes each)
  for pad = 0, 63 do
    local pad_offset = pad * 164
    local pad_samples = {}
    
    -- Each pad can have up to 4 samples at offsets: 25, 49, 73, 97
    for sample_slot = 1, 4 do
      local sample_offset_in_pad = 25 + (sample_slot - 1) * 24
      local sample_name_offset = pad_offset + sample_offset_in_pad
      
      if sample_name_offset + 15 <= #data then
        local sample_name = read_string_from_memory(data, sample_name_offset, 16)
        sample_name = sample_name:match("^%s*(.-)%s*$") -- trim
        
        if sample_name ~= "" then
          -- Get tuning value (word at +20 from sample name)
          local tuning_offset = sample_name_offset + 20
          local tuning = 0
          if tuning_offset + 1 <= #data then
            tuning = word_to_twos_complement(read_le_u16_from_memory(data, tuning_offset)) / 100
          end
          
          table.insert(pad_samples, {
            name = sample_name .. ".wav",
            tuning = tuning
          })
          
          debug_print("Pad", pad, "sample", sample_slot, ":", sample_name, "tuning:", tuning)
        end
      end
    end
    
    if #pad_samples > 0 then
      samples[pad + 1] = pad_samples -- Lua 1-based indexing
    end
  end
  
  -- Parse MIDI map (128 bytes at offset 10585)
  for i = 0, 127 do
    local midi_offset = 10585 + i
    if midi_offset <= #data then
      local pad_num = data:byte(midi_offset) + 1 -- Convert to 1-based
      midimap[i + 1] = (pad_num == 65) and 0 or pad_num -- 65 = unmapped
    end
  end
  
  debug_print("Parsed", #samples, "pads with samples")
  return samples, midimap, program_dir
end

-- Import MPC2000 PGM
local function import_mpc2000_pgm(file_path, data)
  debug_print("Importing MPC2000 PGM format")
  
  local program_dir = get_directory_from_path(file_path)
  local samples = {}
  local midimap = {}
  
  -- Get sample count at offset 3
  local sample_count = read_le_u16_from_memory(data, 3)
  debug_print("Sample count:", sample_count)
  
  if sample_count > 254 then
    error("Program has too many samples for Renoise (limit: 255)")
  end
  
  -- Parse sample names (17 bytes apart, starting calculation: (i*17)-12)
  for i = 1, sample_count do
    local name_offset = (i * 17) - 12
    if name_offset + 15 <= #data then
      local sample_name = read_string_from_memory(data, name_offset, 16)
      sample_name = sample_name:match("^%s*(.-)%s*$") -- trim
      
      if sample_name ~= "" then
        table.insert(samples, sample_name .. ".snd")
        debug_print("Sample", i, ":", sample_name)
      end
    end
  end
  
  -- Parse MIDI map (63 entries from MIDI notes 35-98, 25 bytes apart at offset 150)
  for i = 1, 63 do
    local map_offset = (i * 25) + 150
    if map_offset <= #data then
      local sample_idx = data:byte(map_offset) + 1 -- Convert to 1-based
      midimap[i] = (sample_idx == 256) and 0 or sample_idx -- 255 = unmapped
    end
  end
  
  debug_print("Parsed", #samples, "samples")
  return samples, midimap, program_dir
end

-- Load samples and create mappings for MPC1000
local function load_mpc1000_samples(instrument, samples, midimap, sample_path)
  local missing_samples = 0
  local loaded_count = 0
  
  -- Load samples from pads
  for pad_num, pad_samples in pairs(samples) do
    for _, sample_info in ipairs(pad_samples) do
      local full_path = sample_path .. "/" .. sample_info.name
      
      if file_exists(full_path) then
        debug_print("Loading MPC1000 sample:", full_path)
        
        local sample_idx = #instrument.samples + 1
        instrument:insert_sample_at(sample_idx)
        local sample = instrument.samples[sample_idx]
        
        local ok, err = pcall(function()
          sample.sample_buffer:load_from(full_path)
          sample.name = sample_info.name:gsub("%.wav$", "")
          sample.transpose = math.max(-127, math.min(127, math.floor(sample_info.tuning)))
          sample.volume = math.db2lin(-3)
        end)
        
        if ok then
          loaded_count = loaded_count + 1
        else
          debug_print("Failed to load sample:", err)
          instrument:delete_sample_at(sample_idx)
          missing_samples = missing_samples + 1
        end
      else
        debug_print("Sample not found:", full_path)
        missing_samples = missing_samples + 1
      end
    end
  end
  
  -- Create MIDI mappings
  local current_pad = 0
  local range_start = 0
  
  for midi_note = 1, 128 do
    local pad_for_note = midimap[midi_note] or 0
    
    if pad_for_note ~= current_pad then
      -- End previous range, start new one
      if current_pad > 0 and range_start > 0 and samples[current_pad] then
        -- Find sample index for this pad
        local sample_idx = 0
        local count = 0
        for p = 1, current_pad do
          if samples[p] then
            count = count + #samples[p]
            if p == current_pad then
              sample_idx = count -- Use last sample of pad
              break
            end
          end
        end
        
        if sample_idx > 0 and sample_idx <= #instrument.samples then
          local sample = instrument.samples[sample_idx]
          sample.sample_mapping.base_note = range_start + 34 -- MIDI note offset
          sample.sample_mapping.note_range = {range_start + 34, midi_note + 33}
          sample.sample_mapping.velocity_range = {0, 127}
          
          debug_print("Mapped pad", current_pad, "to MIDI", range_start + 34, "-", midi_note + 33)
        end
      end
      
      current_pad = pad_for_note
      range_start = midi_note - 1
    end
  end
  
  return loaded_count, missing_samples
end

-- Load samples and create mappings for MPC2000
local function load_mpc2000_samples(instrument, samples, midimap, sample_path)
  local missing_samples = 0
  local loaded_count = 0
  
  -- Load samples
  for i, sample_name in ipairs(samples) do
    local full_path = sample_path .. "/" .. sample_name
    
    if file_exists(full_path) then
      debug_print("Loading MPC2000 sample:", full_path)
      
      local sample_idx = #instrument.samples + 1
      instrument:insert_sample_at(sample_idx)
      local sample = instrument.samples[sample_idx]
      
      -- Use existing MPC2000 SND loader if available, otherwise basic load
      local ok, err = pcall(function()
        if importMPC2000Sample then
          -- Save current state
          local old_idx = renoise.song().selected_instrument_index
          
          -- Load using MPC2000 importer (creates new instrument)
          importMPC2000Sample(full_path)
          
          -- Copy from temporary instrument
          local temp_inst = renoise.song().selected_instrument
          if #temp_inst.samples > 0 then
            local src_sample = temp_inst.samples[1]
            
            -- Copy sample data
            sample.sample_buffer:create_sample_data(
              src_sample.sample_buffer.sample_rate,
              src_sample.sample_buffer.bit_depth,
              src_sample.sample_buffer.number_of_channels,
              src_sample.sample_buffer.number_of_frames
            )
            
            sample.sample_buffer:prepare_sample_data_changes()
            for ch = 1, src_sample.sample_buffer.number_of_channels do
              for frame = 1, src_sample.sample_buffer.number_of_frames do
                sample.sample_buffer:set_sample_data(ch, frame,
                  src_sample.sample_buffer:sample_data(ch, frame))
              end
            end
            sample.sample_buffer:finalize_sample_data_changes()
            
            -- Copy properties
            sample.name = src_sample.name
            sample.transpose = src_sample.transpose
            sample.fine_tune = src_sample.fine_tune
            sample.loop_start = src_sample.loop_start
            sample.loop_end = src_sample.loop_end
            sample.loop_mode = src_sample.loop_mode
          end
          
          -- Clean up temporary instrument
          renoise.song():delete_instrument_at(renoise.song().selected_instrument_index)
          renoise.song().selected_instrument_index = old_idx
        else
          -- Fallback: basic load
          sample.sample_buffer:load_from(full_path)
          sample.name = sample_name:gsub("%.snd$", "")
        end
      end)
      
      if ok then
        loaded_count = loaded_count + 1
      else
        debug_print("Failed to load sample:", err)
        instrument:delete_sample_at(sample_idx)
        missing_samples = missing_samples + 1
      end
    else
      debug_print("Sample not found:", full_path)
      missing_samples = missing_samples + 1
    end
  end
  
  -- Create MIDI mappings (notes 35-98 = indices 1-63)
  local current_sample = 0
  local range_start = 35
  
  for i = 1, 63 do
    local sample_for_note = midimap[i] or 0
    local midi_note = i + 34 -- Convert to MIDI note (35-98)
    
    if sample_for_note ~= current_sample then
      -- End previous range
      if current_sample > 0 and current_sample <= #instrument.samples then
        local sample = instrument.samples[current_sample]
        sample.sample_mapping.base_note = range_start
        sample.sample_mapping.note_range = {range_start, midi_note - 1}
        sample.sample_mapping.velocity_range = {0, 127}
        
        debug_print("Mapped sample", current_sample, "to MIDI", range_start, "-", midi_note - 1)
      end
      
      current_sample = sample_for_note
      range_start = midi_note
    end
  end
  
  -- Handle final range
  if current_sample > 0 and current_sample <= #instrument.samples then
    local sample = instrument.samples[current_sample]
    sample.sample_mapping.base_note = range_start
    sample.sample_mapping.note_range = {range_start, 98}
    sample.sample_mapping.velocity_range = {0, 127}
  end
  
  return loaded_count, missing_samples
end

-- Unified MPC Program (.pgm) support
function importMPCProgram(file_path)
  if not file_path then
    file_path = renoise.app():prompt_for_filename_to_read(
      {"*.pgm"}, "Import MPC Program"
    )
    if not file_path or file_path == "" then
      renoise.app():show_status("No file selected")
      return
    end
  end
  
  print("---------------------------------")
  debug_print("Importing MPC program (.pgm):", file_path)
  
  -- Load file data
  local f, err = io.open(file_path, "rb")
  if not f then
    error("Could not open file: " .. err)
  end
  local data = f:read("*all")
  f:close()
  
  if #data < 10 then
    error("File too small to be MPC program")
  end
  
  -- Detect format and parse
  local samples, midimap, sample_path
  local is_mpc1000 = false
  
  if is_mpc2000_pgm(data) then
    renoise.app():show_status("Importing Akai MPC2000/XL program...")
    samples, midimap, sample_path = import_mpc2000_pgm(file_path, data)
  elseif is_mpc1000_pgm(data) then
    renoise.app():show_status("Importing Akai MPC1000 program...")
    samples, midimap, sample_path = import_mpc1000_pgm(file_path, data)
    is_mpc1000 = true
  else
    error("Not a supported Akai MPC program file")
  end
  
  -- Create instrument
  local song = renoise.song()
  local current_idx = song.selected_instrument_index
  local new_idx = current_idx + 1
  if not safeInsertInstrumentAt(song, new_idx) then return end
  song.selected_instrument_index = new_idx

  local instrument = song.instruments[new_idx]
  local filename = file_path:match("[^/\\]+$"):gsub("%.pgm$", "")
  instrument.name = filename
  
  -- Clear existing samples
  while #instrument.samples > 0 do
    instrument:delete_sample_at(1)
  end
  
  -- Load samples and create mappings
  local loaded_count, missing_samples
  if is_mpc1000 then
    loaded_count, missing_samples = load_mpc1000_samples(instrument, samples, midimap, sample_path)
  else
    loaded_count, missing_samples = load_mpc2000_samples(instrument, samples, midimap, sample_path)
  end
  
  -- Remove blank sample if exists
  if #instrument.samples > 0 and not instrument.samples[#instrument.samples].sample_buffer.has_sample_data then
    instrument:delete_sample_at(#instrument.samples)
  end
  
  -- Final status
  if missing_samples == 0 then
    renoise.app():show_status("MPC program import complete: " .. loaded_count .. " samples loaded")
  else
    local msg = string.format("MPC program partially complete: %d loaded, %d missing", loaded_count, missing_samples)
    renoise.app():show_status(msg)
    renoise.app():show_warning(string.format("%d samples could not be found when importing this program file.", missing_samples))
  end
  
  debug_print("Import complete:", loaded_count, "loaded,", missing_samples, "missing")
end

-- Legacy compatibility functions
function importMPC1000Program(file_path)
  return importMPCProgram(file_path)
end

function importMPC2000Program(file_path)  
  return importMPCProgram(file_path)
end

function exportMPC1000Program()
  local output_path = renoise.app():prompt_for_filename_to_write("*.pgm", "Export MPC1000 Program"
  )
  
  if not output_path or output_path == "" then
    renoise.app():show_status("No file selected")
    return
  end
  
  debug_print("Exporting MPC1000 program (.pgm):", output_path)
  renoise.app():show_status("MPC1000 program export not fully implemented yet")
end

function exportMPC2000Program()
  local output_path = renoise.app():prompt_for_filename_to_write("*.pgm", "Export MPC2000 Program")
  
  if not output_path or output_path == "" then
    renoise.app():show_status("No file selected")
    return
  end
  
  debug_print("Exporting MPC2000 program (.pgm):", output_path)  
  renoise.app():show_status("MPC2000 program export not fully implemented yet")
end

-- Generic export function with format selection
function exportAkaiProgram()
  local options = {"S1000 Program (.p)", "MPC1000 Program (.pgm)", "MPC2000 Program (.pgm)"}
  local choice = renoise.app():show_prompt("Export Akai Program", 
    "Select program format:", options)
  
  if choice == 1 then
    exportS1000Program()
  elseif choice == 2 then
    exportMPC1000Program()
  elseif choice == 3 then
    exportMPC2000Program()
  end
end

-- Menu entries
renoise.tool():add_keybinding{name = "Global:Paketti:Import Akai Program...",invoke = importAkaiProgram}

renoise.tool():add_keybinding{name = "Global:Paketti:Export Akai Program...",invoke = exportAkaiProgram}


-- File import hooks for program formats
local program_integration = {
  name = "Akai Program Files",
  category = "sample",
  extensions = { "p", "pgm" },
  invoke = importAkaiProgram
}

if not renoise.tool():has_file_import_hook("sample", { "p", "pgm" }) then
  renoise.tool():add_file_import_hook(program_integration)
end 