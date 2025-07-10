-- PakettiOP1Export.lua  
-- Teenage Engineering OP-1 sample export tool
-- Based on DigiChain's OP-1 implementation using AIF files with metadata

local dialog = nil
local separator = package.config:sub(1,1)

-- OP-1 audio format specifications
local OP1_SAMPLE_RATE = 44100
local OP1_BIT_DEPTH = 16
local OP1_CHANNELS = 2  -- OP-1 supports stereo

-- OP-1 metadata constants
local OP1_METADATA = {
  drum = {
    type = "drum",
    name = "op1-drum",
    octave = 0,
    pitch = 0,
    volume = 8000,
    pan = 8000,
    envelope = {
      attack = 0,
      decay = 8000,
      sustain = 8000,
      release = 8000
    },
    lfo = {
      wave = 0,
      rate = 8000,
      depth = 0
    },
    fx = {
      type = 0,
      param1 = 8000,
      param2 = 8000
    }
  },
  
  tape = {
    type = "tape",
    name = "op1-tape",
    tempo = 120,
    quantize = 0,
    bars = 4,
    mode = "four-track"
  }
}

-- Function to write big-endian 32-bit integer
local function write_be32(file, value)
  file:write(string.char(
    math.floor(value / 16777216) % 256,
    math.floor(value / 65536) % 256,
    math.floor(value / 256) % 256,
    value % 256
  ))
end

-- Function to write big-endian 16-bit integer
local function write_be16(file, value)
  file:write(string.char(
    math.floor(value / 256) % 256,
    value % 256
  ))
end

-- Function to write string with padding
local function write_string_padded(file, str, length)
  local padded = str
  while #padded < length do
    padded = padded .. "\0"
  end
  file:write(padded:sub(1, length))
end

-- Function to read big-endian 32-bit integer
local function read_be32(file)
  local bytes = file:read(4)
  if not bytes or #bytes < 4 then
    return nil
  end
  local b1, b2, b3, b4 = bytes:byte(1, 4)
  return b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
end

-- Function to read big-endian 16-bit integer
local function read_be16(file)
  local bytes = file:read(2)
  if not bytes or #bytes < 2 then
    return nil
  end
  local b1, b2 = bytes:byte(1, 2)
  return b1 * 256 + b2
end

-- Function to create OP-1 JSON metadata
local function create_op1_metadata(op1_type, sample_count, total_frames)
  local metadata = {
    type = op1_type,
    name = "renoise-" .. op1_type,
    octave = 0,
    pitch = 0,
    volume = 8000,
    pan = 8000,
    envelope = {
      attack = 0,
      decay = 8000,
      sustain = 8000,
      release = 8000
    },
    lfo = {
      wave = 0,
      rate = 8000,
      depth = 0
    },
    fx = {
      type = 0,
      param1 = 8000,
      param2 = 8000
    }
  }
  
  if op1_type == "drum" then
    metadata.drum_version = 1
    metadata.playback = "fwd"
    metadata.reverse = false
    metadata.volume = 8000
    metadata.pitch = 0
    metadata.start = 0
    metadata["end"] = total_frames
    metadata.loop_start = 0
    metadata.loop_end = total_frames
  elseif op1_type == "tape" then
    metadata.tape_version = 1
    metadata.tempo = 120
    metadata.quantize = 0
    metadata.bars = 4
    metadata.mode = "four-track"
  end
  
  return metadata
end

-- Function to write AIF file with OP-1 metadata
local function write_aif_with_op1_metadata(filename, sample_data, channels, sample_rate, bit_depth, op1_type, sample_count)
  print("-- OP-1 Export: Writing AIF with OP-1 metadata")
  
  local file = io.open(filename, "wb")
  if not file then
    return false
  end
  
  local num_samples = #sample_data / channels
  local bytes_per_sample = bit_depth / 8
  local data_size = #sample_data * bytes_per_sample
  
  -- Create OP-1 metadata
  local metadata = create_op1_metadata(op1_type, sample_count, num_samples)
  local metadata_json = string.format([[{
    "type": "%s",
    "name": "renoise-%s",
    "octave": %d,
    "pitch": %d,
    "volume": %d,
    "pan": %d,
    "envelope": {
      "attack": %d,
      "decay": %d,
      "sustain": %d,
      "release": %d
    },
    "lfo": {
      "wave": %d,
      "rate": %d,
      "depth": %d
    },
    "fx": {
      "type": %d,
      "param1": %d,
      "param2": %d
    }
  }]], 
    metadata.type, metadata.name, metadata.octave, metadata.pitch, metadata.volume, metadata.pan,
    metadata.envelope.attack, metadata.envelope.decay, metadata.envelope.sustain, metadata.envelope.release,
    metadata.lfo.wave, metadata.lfo.rate, metadata.lfo.depth,
    metadata.fx.type, metadata.fx.param1, metadata.fx.param2
  )
  
  -- Calculate chunk sizes
  local comm_chunk_size = 18 + #metadata_json
  if comm_chunk_size % 2 == 1 then
    comm_chunk_size = comm_chunk_size + 1  -- Pad to even length
  end
  
  local ssnd_chunk_size = 8 + data_size
  if ssnd_chunk_size % 2 == 1 then
    ssnd_chunk_size = ssnd_chunk_size + 1  -- Pad to even length
  end
  
  local total_size = 4 + 8 + comm_chunk_size + 8 + ssnd_chunk_size
  
  -- Write FORM header
  file:write("FORM")
  write_be32(file, total_size)
  file:write("AIFF")
  
  -- Write COMM chunk (with OP-1 metadata)
  file:write("COMM")
  write_be32(file, comm_chunk_size)
  write_be16(file, channels)
  write_be32(file, num_samples)
  write_be16(file, bit_depth)
  
  -- Write sample rate in IEEE 754 extended precision format (simplified)
  local exp = 0x400E -- Exponent for 44100 Hz
  write_be16(file, exp)
  write_be32(file, sample_rate * 65536)  -- Simplified mantissa
  write_be32(file, 0)  -- Lower mantissa
  
  -- Write OP-1 metadata JSON
  file:write(metadata_json)
  if #metadata_json % 2 == 1 then
    file:write("\0")  -- Pad to even length
  end
  
  -- Write SSND chunk
  file:write("SSND")
  write_be32(file, ssnd_chunk_size)
  write_be32(file, 0)  -- Offset
  write_be32(file, 0)  -- Block size
  
  -- Write sample data (big-endian)
  if bit_depth == 16 then
    for i = 1, #sample_data do
      local int_sample = math.floor(sample_data[i] * 32767 + 0.5)
      int_sample = math.max(-32768, math.min(32767, int_sample))
      write_be16(file, int_sample >= 0 and int_sample or (65536 + int_sample))
    end
  end
  
  -- Pad data to even length if needed
  if data_size % 2 == 1 then
    file:write("\0")
  end
  
  file:close()
  return true
end

-- Function to export OP-1 drum kit
function PakettiOP1ExportDrumKit()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_error("No samples found in selected instrument")
    return
  end
  
  if #instrument.samples[1].slice_markers > 0 then
    renoise.app():show_error("Cannot export from sliced instrument.\nPlease select an instrument with individual samples in separate slots.")
    return
  end
  
  print("-- OP-1 Drum Export: Starting OP-1 drum kit export")
  print("-- OP-1 Drum Export: Processing " .. #instrument.samples .. " samples")
  
  -- Process and combine samples
  local combined_data = {}
  local processed_count = 0
  
  for i, sample in ipairs(instrument.samples) do
    if sample and sample.sample_buffer.has_sample_data then
      renoise.app():show_status(string.format("OP-1 Export: Processing sample %d/%d", i, #instrument.samples))
      
      local buffer = sample.sample_buffer
      local frames = buffer.number_of_frames
      local channels = buffer.number_of_channels
      
      -- Convert to stereo OP-1 format
      for frame = 1, frames do
        local left = buffer:sample_data(1, frame)
        local right = channels > 1 and buffer:sample_data(2, frame) or left
        
        table.insert(combined_data, left)
        table.insert(combined_data, right)
      end
      
      processed_count = processed_count + 1
      print(string.format("-- OP-1 Drum Export: Processed sample %d: %d frames", i, frames))
    end
  end
  
  if processed_count == 0 then
    renoise.app():show_error("No valid samples found to export")
    return
  end
  
  -- Get output filename
  local filename = renoise.app():prompt_for_filename_to_write("*.aif", "Save OP-1 drum kit...")
  if not filename or filename == "" then
    renoise.app():show_status("OP-1 drum export cancelled")
    return
  end
  
  -- Ensure .aif extension
  if not filename:match("%.aif$") then
    filename = filename .. ".aif"
  end
  
  -- Write AIF file with OP-1 metadata
  local success = write_aif_with_op1_metadata(filename, combined_data, OP1_CHANNELS, OP1_SAMPLE_RATE, OP1_BIT_DEPTH, "drum", processed_count)
  
  if success then
    renoise.app():show_status(string.format("OP-1 Drum Export: Created %s with %d samples", filename:match("([^/\\]+)$"), processed_count))
    print(string.format("-- OP-1 Drum Export: Successfully exported %d samples", processed_count))
  else
    renoise.app():show_error("Failed to write OP-1 drum kit file")
  end
end

-- Function to export OP-1 tape
function PakettiOP1ExportTape()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_error("No samples found in selected instrument")
    return
  end
  
  print("-- OP-1 Tape Export: Starting OP-1 tape export")
  print("-- OP-1 Tape Export: Processing " .. #instrument.samples .. " samples")
  
  -- Process and combine samples into tape format
  local combined_data = {}
  local processed_count = 0
  
  for i, sample in ipairs(instrument.samples) do
    if sample and sample.sample_buffer.has_sample_data then
      renoise.app():show_status(string.format("OP-1 Tape Export: Processing sample %d/%d", i, #instrument.samples))
      
      local buffer = sample.sample_buffer
      local frames = buffer.number_of_frames
      local channels = buffer.number_of_channels
      
      -- Convert to stereo OP-1 format
      for frame = 1, frames do
        local left = buffer:sample_data(1, frame)
        local right = channels > 1 and buffer:sample_data(2, frame) or left
        
        table.insert(combined_data, left)
        table.insert(combined_data, right)
      end
      
      processed_count = processed_count + 1
      print(string.format("-- OP-1 Tape Export: Processed sample %d: %d frames", i, frames))
    end
  end
  
  if processed_count == 0 then
    renoise.app():show_error("No valid samples found to export")
    return
  end
  
  -- Get output filename
  local filename = renoise.app():prompt_for_filename_to_write("*.aif", "Save OP-1 tape...")
  if not filename or filename == "" then
    renoise.app():show_status("OP-1 tape export cancelled")
    return
  end
  
  -- Ensure .aif extension
  if not filename:match("%.aif$") then
    filename = filename .. ".aif"
  end
  
  -- Write AIF file with OP-1 metadata
  local success = write_aif_with_op1_metadata(filename, combined_data, OP1_CHANNELS, OP1_SAMPLE_RATE, OP1_BIT_DEPTH, "tape", processed_count)
  
  if success then
    renoise.app():show_status(string.format("OP-1 Tape Export: Created %s with %d samples", filename:match("([^/\\]+)$"), processed_count))
    print(string.format("-- OP-1 Tape Export: Successfully exported %d samples", processed_count))
  else
    renoise.app():show_error("Failed to write OP-1 tape file")
  end
end

-- Function to export OP-1 single sample
function PakettiOP1ExportSample()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_error("No samples found in selected instrument")
    return
  end
  
  local sample = instrument.samples[1]
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_error("No valid sample data found")
    return
  end
  
  print("-- OP-1 Sample Export: Starting OP-1 sample export")
  
  local buffer = sample.sample_buffer
  local frames = buffer.number_of_frames
  local channels = buffer.number_of_channels
  
  -- Convert to stereo OP-1 format
  local sample_data = {}
  for frame = 1, frames do
    local left = buffer:sample_data(1, frame)
    local right = channels > 1 and buffer:sample_data(2, frame) or left
    
    table.insert(sample_data, left)
    table.insert(sample_data, right)
  end
  
  -- Get output filename
  local filename = renoise.app():prompt_for_filename_to_write("*.aif", "Save OP-1 sample...")
  if not filename or filename == "" then
    renoise.app():show_status("OP-1 sample export cancelled")
    return
  end
  
  -- Ensure .aif extension
  if not filename:match("%.aif$") then
    filename = filename .. ".aif"
  end
  
  -- Write AIF file with OP-1 metadata
  local success = write_aif_with_op1_metadata(filename, sample_data, OP1_CHANNELS, OP1_SAMPLE_RATE, OP1_BIT_DEPTH, "drum", 1)
  
  if success then
    renoise.app():show_status(string.format("OP-1 Sample Export: Created %s", filename:match("([^/\\]+)$")))
    print("-- OP-1 Sample Export: Successfully exported sample")
  else
    renoise.app():show_error("Failed to write OP-1 sample file")
  end
end

-- Menu entries
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:OP-1:Export Drum Kit", invoke = PakettiOP1ExportDrumKit}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:OP-1:Export Tape", invoke = PakettiOP1ExportTape}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:OP-1:Export Sample", invoke = PakettiOP1ExportSample}

renoise.tool():add_keybinding{name = "Global:Paketti:OP-1 Export Drum Kit", invoke = PakettiOP1ExportDrumKit}
renoise.tool():add_keybinding{name = "Global:Paketti:OP-1 Export Tape", invoke = PakettiOP1ExportTape}
renoise.tool():add_keybinding{name = "Global:Paketti:OP-1 Export Sample", invoke = PakettiOP1ExportSample}

-- Function to read OP-1 metadata from AIF file
local function read_op1_metadata(filename)
  print("-- OP-1 Import: Reading OP-1 metadata from AIF file")
  
  local file = io.open(filename, "rb")
  if not file then
    return nil
  end
  
  -- Read FORM header
  local form = file:read(4)
  if form ~= "FORM" then
    file:close()
    return nil
  end
  
  local form_size = read_be32(file)
  local aiff = file:read(4)
  if aiff ~= "AIFF" then
    file:close()
    return nil
  end
  
  local metadata = {}
  
  -- Read chunks
  while true do
    local chunk_id = file:read(4)
    if not chunk_id or #chunk_id < 4 then break end
    
    local chunk_size = read_be32(file)
    if not chunk_size then break end
    
    if chunk_id == "COMM" then
      -- Read COMM chunk
      local channels = read_be16(file)
      local num_samples = read_be32(file)
      local bit_depth = read_be16(file)
      
      -- Skip IEEE 754 extended precision format (10 bytes)
      file:seek("cur", 10)
      
      -- Read OP-1 metadata JSON (remaining bytes in COMM chunk)
      local metadata_size = chunk_size - 18
      if metadata_size > 0 then
        local metadata_json = file:read(metadata_size)
        if metadata_json then
          metadata.json = metadata_json
          metadata.channels = channels
          metadata.num_samples = num_samples
          metadata.bit_depth = bit_depth
          print("-- OP-1 Import: Found OP-1 metadata")
        end
      end
    else
      -- Skip other chunks
      file:seek("cur", chunk_size)
      if chunk_size % 2 == 1 then
        file:seek("cur", 1)  -- Skip padding byte
      end
    end
  end
  
  file:close()
  return metadata
end

-- Function to import OP-1 sample
function PakettiOP1Import()
  local filename = renoise.app():prompt_for_filename_to_read({"*.aif", "*.aiff"}, "Load OP-1 sample...")
  if not filename or filename == "" then
    return
  end
  
  print("-- OP-1 Import: Loading file: " .. filename)
  
  -- First check if file exists and is readable
  local test_file = io.open(filename, "rb")
  if not test_file then
    renoise.app():show_error("Cannot open file: " .. filename)
    return
  end
  test_file:close()
  
  -- Read OP-1 metadata from AIF file
  local metadata = read_op1_metadata(filename)
  
  -- Create new instrument
  local song = renoise.song()
  local new_instrument_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  local instrument = song.selected_instrument
  
  -- Set instrument name
  local base_name = filename:match("([^/\\]+)$"):gsub("%.aif[f]?$", "")
  instrument.name = metadata and "OP-1 " .. base_name or base_name
  
  -- Load AIF file into first sample
  local sample = instrument.samples[1]
  if not sample then
    print("-- OP-1 Import: No sample found in instrument, creating new sample")
    sample = instrument:insert_sample_at(1)
  end
  
  local success, error_msg = pcall(function()
    sample.sample_buffer:load_from(filename)
  end)
  
  if not success then
    print("-- OP-1 Import: Error loading AIF file: " .. tostring(error_msg))
    renoise.app():show_error("Failed to load AIF file: " .. filename .. "\nError: " .. tostring(error_msg))
    return
  end
  
  if not sample.sample_buffer.has_sample_data then
    renoise.app():show_error("AIF file loaded but contains no sample data: " .. filename)
    return
  end
  
  -- Set sample name
  sample.name = base_name
  
  -- Apply OP-1 metadata if available
  if metadata and metadata.json then
    print("-- OP-1 Import: Applying OP-1 metadata")
    print("-- OP-1 Import: Metadata JSON: " .. metadata.json)
    
    -- Switch to sample editor
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    
    renoise.app():show_status(string.format("OP-1 Import: Loaded %s with OP-1 metadata", base_name))
  else
    print("-- OP-1 Import: No OP-1 metadata found in AIF file")
    renoise.app():show_status(string.format("OP-1 Import: Loaded %s (no OP-1 metadata found)", base_name))
  end
  
  print("-- OP-1 Import: Successfully imported OP-1 sample")
end

-- File import hook for OP-1 AIF files (commented out)
--[[
local function import_op1_aif_file(filename)
  print("-- OP-1 Import Hook: Processing AIF file: " .. filename)
  
  -- Check if this AIF file has OP-1 metadata
  local metadata = read_op1_metadata(filename)
  if metadata and metadata.json then
    print("-- OP-1 Import Hook: Found OP-1 metadata, importing as OP-1 sample")
    
    -- Create new instrument
    local song = renoise.song()
    local new_instrument_index = song.selected_instrument_index + 1
    song:insert_instrument_at(new_instrument_index)
    song.selected_instrument_index = new_instrument_index
    local instrument = song.selected_instrument
    
    -- Set instrument name
    local base_name = filename:match("([^/\\]+)$"):gsub("%.aif[f]?$", "")
    instrument.name = "OP-1 " .. base_name
    
    -- Load AIF file into first sample
    local sample = instrument.samples[1]
    if not sample then
      print("-- OP-1 Import Hook: No sample found in instrument, creating new sample")
      sample = instrument:insert_sample_at(1)
    end
    
    local success = pcall(function()
      sample.sample_buffer:load_from(filename)
    end)
    
    if not success or not sample.sample_buffer.has_sample_data then
      print("-- OP-1 Import Hook: Failed to load AIF file")
      return
    end
    
    -- Set sample name
    sample.name = base_name
    
    -- Switch to sample editor
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    
    renoise.app():show_status(string.format("OP-1 Import Hook: Loaded %s with OP-1 metadata", base_name))
    print("-- OP-1 Import Hook: Successfully imported OP-1 sample")
  else
    print("-- OP-1 Import Hook: No OP-1 metadata found, skipping OP-1 import")
  end
end
]]--
-- Add import menu entries
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:OP-1:Import Sample", invoke = PakettiOP1Import}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Xperimental/Work in Progress:OP-1:Import Sample", invoke = PakettiOP1Import}
renoise.tool():add_menu_entry{name = "Sample Mappings:Paketti:Xperimental/Work in Progress:OP-1:Import Sample", invoke = PakettiOP1Import}

-- Add import keybinding
renoise.tool():add_keybinding{name = "Global:Paketti:OP-1 Import Sample", invoke = PakettiOP1Import}

-- Register file import hook for OP-1 AIF files (commented out)
--[[
local aif_integration = {
  category = "sample",
  extensions = { "aif", "aiff" },
  invoke = import_op1_aif_file
}

if not renoise.tool():has_file_import_hook("sample", { "aif", "aiff" }) then
  renoise.tool():add_file_import_hook(aif_integration)
end
]]--
 