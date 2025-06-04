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
  f:write(b1, b2, b3, b4)
end

function wb16(f, x)
  local b4 = string.char(x % 256) x = (x - x % 256) / 256
  local b3 = string.char(x % 256) x = (x - x % 256) / 256
  f:write(b3, b4)
end

-- Function to write 16-bit value with byte order reversal for checksum
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

function make_ot_table(sample)
  local sample_buffer = sample.sample_buffer
  local slice_count   = table.getn(sample.slice_markers)
  local sample_len    = sample_buffer.number_of_frames

  -- Compute dynamic tempo (BPM × 120, big‐endian)
  local bpm = renoise.song().transport.bpm
  local tempo_value = math.floor(bpm * 120)

  -- Compute block counts (Octatrack uses 8‐frame blocks for trim_len/loop_len)
  -- If you want to match the working file exactly, use default_blocks = 225
  local full_blocks    = math.floor(sample_len / 8)
  local default_blocks = 225

  -- Limit slice count to 64 (Octatrack maximum)
  local export_slice_count = math.min(slice_count, 64)

  -- Debug prints
  print("sample length: " .. sample_len)
  print("total slices: " .. slice_count .. ", exporting: " .. export_slice_count)

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
  -- trim_len (32)   (in 8‐frame blocks; using default_blocks to match working file)
  table.insert(ot, default_blocks)
  -- loop_len (32)   (in 8‐frame blocks; using default_blocks to match working file)
  table.insert(ot, default_blocks)
  -- stretch (32)
  table.insert(ot, 0x00)
  -- loop (32)      (0 = off)
  table.insert(ot, 0x00)
  -- gain (16)
  table.insert(ot, 0x30)
  -- quantize (8)
  table.insert(ot, 0xFF)
  -- trim_start (32)
  table.insert(ot, 0x00)
  -- trim_end (32)
  table.insert(ot, sample_len)
  -- loop_point (32)
  table.insert(ot, 0x00)

  -- Checksum only includes the size of everything *after* header and unknown:
  --   gain (16 bits) + quantize (8 bits) + the other 8 fields (8 × 32 bits)
  local checksum = (16/8) + (8/8) + ((32/8) * 8)

  -- Process only the first 64 slices (or fewer if less than 64 exist)
  for k = 1, export_slice_count do
    local v    = sample.slice_markers[k]
    local nxt  = (k < export_slice_count) and sample.slice_markers[k + 1] or sample_len

    print("slice " .. k .. ": " .. v .. ", next: " .. nxt)

    local s_start  = v - 1
    local s_length = nxt - v

    -- start_point (32)
    table.insert(ot, s_start)
    -- slice_length (32)
    table.insert(ot, s_length)
    -- loop_point (32)
    table.insert(ot, 0xFFFFFFFF)

    checksum = checksum + ((32/8) * 3)

    print("slice " .. k .. ": start=" .. s_start .. ", length=" .. s_length)
  end

  -- Fill remaining slots up to 64 with empty slices
  for i = 1, (64 - export_slice_count) do
    -- start_point (32)
    table.insert(ot, 0x00000000)
    -- end_point (32)
    table.insert(ot, 0x00000000)
    -- loop_point (32)
    table.insert(ot, 0x00000000)

    checksum = checksum + ((32/8) * 3)
  end

  -- slice_count (32)
  table.insert(ot, export_slice_count)
  checksum = checksum + (32/8)

  print("checksum: " .. checksum)
  -- checksum (16, little‐endian)
  table.insert(ot, checksum)

  return ot
end

function write_ot_file(filename, ot)
  local name = filename:match("(.+)%..+$")
  local f = io.open(name..".ot", "wb")
  for k,v in ipairs(ot) do
      if k <= 23 or k == 30 then
          wb(f, v)
      elseif k == 29 then
          wb16(f, v)  -- Regular 16-bit write for gain
      elseif k == #ot then
          wb16_reversed(f, v)  -- FIXED: Use reversed byte order for checksum
      else
          wb32(f, v)
      end
  end
  f:close()
  print("PakettiOTExport: .ot file written with corrected slice lengths and checksum byte order")
end

-- Binary reading functions for .ot import
function rb32(f)
  local b1 = string.byte(f:read(1) or "\0")
  local b2 = string.byte(f:read(1) or "\0")
  local b3 = string.byte(f:read(1) or "\0")
  local b4 = string.byte(f:read(1) or "\0")
  return b1 * 256^3 + b2 * 256^2 + b3 * 256 + b4
end

function rb16(f)
  local b1 = string.byte(f:read(1) or "\0")
  local b2 = string.byte(f:read(1) or "\0")
  return b1 * 256 + b2
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
    local slice_length = rb32(f)  -- FIXED: This is slice LENGTH, not end_point
    local slice_loop_point = rb32(f)
    
    -- Only add slices that have actual data (not all zeros)
    if start_point > 0 or slice_length > 0 then
      table.insert(slices, {
        start_point = start_point,
        slice_length = slice_length,  -- FIXED: Store as slice_length
        loop_point = slice_loop_point
      })
      print("PakettiOTImport: Slice " .. i .. " - start: " .. start_point .. ", length: " .. slice_length)
    end
  end
  
  -- Read slice count and checksum
  local slice_count = rb32(f)
  local checksum = rb16(f)
  
  f:close()
  
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

-- Function to apply .ot slice data to current sample
function apply_ot_slices_to_sample(ot_data)
  local song = renoise.song()
  local sample = song.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample selected to apply slices to")
    print("PakettiOTImport: No valid sample selected")
    return
  end
  
  -- Clear existing slice markers
  sample.slice_markers = {}
  
  -- Apply slices from .ot data
  local applied_slices = 0
  for i, slice in ipairs(ot_data.slices) do
    if slice.start_point > 0 and slice.start_point < sample.sample_buffer.number_of_frames then
      -- Convert from 0-based to 1-based indexing and adjust
      local slice_position = slice.start_point + 1
      table.insert(sample.slice_markers, slice_position)
      applied_slices = applied_slices + 1
      print("PakettiOTImport: Applied slice at position " .. slice_position)
    end
  end
  
  renoise.app():show_status("Applied " .. applied_slices .. " slices from .ot file")
  print("PakettiOTImport: Successfully applied " .. applied_slices .. " slices to sample")
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
    
    local ot = make_ot_table(sample)
    local filename = renoise.app():prompt_for_filename_to_write("ot", "Save .ot file...")
    
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
    
    local filename = renoise.app():prompt_for_filename_to_read({"ot"}, "Load .ot file...")
    
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

renoise.tool():add_menu_entry {name = "Sample Editor:Export to Octatrack...",invoke = function() PakettiOTExport() end}
renoise.tool():add_menu_entry {name = "Sample Editor:Export .ot file only...",invoke = function() PakettiOTExportOtOnly() end}
renoise.tool():add_menu_entry {name = "Sample Editor:Import .ot file...",invoke = function() PakettiOTImport() end}

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Export to Octatrack",invoke=function() PakettiOTExport() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Export .ot file only",invoke=function() PakettiOTExportOtOnly() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Import .ot file",invoke=function() PakettiOTImport() end}

function PakettiOTExport()
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
        else
            renoise.app():show_status("Conversion failed - exporting original format")
            print("PakettiOTExport: Conversion failed, proceeding with original format")
        end
    end
    
    print("PakettiOTExport: All safety checks passed, proceeding with export")
    
    local ot = make_ot_table(sample)
    local filename = renoise.app():prompt_for_filename_to_write("wav", "Save sample...")
    
    -- Check if user cancelled the file dialog
    if not filename or filename == "" then
        renoise.app():show_status("Export cancelled")
        print("PakettiOTExport: Export cancelled by user")
        return
    end
    
    write_ot_file(filename, ot)
    sample.sample_buffer:save_as(filename, "wav")
    renoise.app():show_status("Sample exported successfully")
    print("PakettiOTExport: Export completed successfully")
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
    
    -- Delete the original sample and select the new one
    instrument:delete_sample_at(sample_index)
    song.selected_sample_index = #instrument.samples -- Select the new sample

    print("PakettiOTExport: Sample converted to " .. target_sample_rate .. "Hz, " .. target_bit_depth .. "-bit")
    return true
  else
    print("PakettiOTExport: Sample buffer is either not loaded or has no data")
    return false
  end
end

