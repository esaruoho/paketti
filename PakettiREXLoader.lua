--------------------------------------------------------------------------------
-- Additional File Format Support for Renoise - REX File Loader
--
-- Original Copyright 2011 Martin Bealby (mbealby@gmail.com)
-- Updated for Renoise 3.4.4 API v6.2
--
-- Propellerheads Recycle REX file support code
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Revision History
-- 2.0  - Updated for Renoise 3.4.4 API v6.2
--        - Modernized code structure
--        - Improved error handling
--        - Better temporary file management
--        - Memory optimization
--        - Fixed slice boundary clipping issues
--        - Added automatic instrument naming
--------------------------------------------------------------------------------

-- Debug configuration
local _DEBUG = true -- Set to true to enable debug output

-- Debug print helper function
local function dprint(...)
  if _DEBUG then
    local args = {...}
    local output = ""
    for i, v in ipairs(args) do
      output = output .. tostring(v)
    end
    print(output)
  end
end

-- Helper function to get clean filename without path and extension
local function get_clean_filename(filepath)
  -- Get filename from path (works for both forward and backslashes)
  local filename = filepath:match("[^/\\]+$")  -- Get everything after the last slash
  if filename then
    return filename:gsub("%.rex$", "")  -- Remove .rex extension if present
  end
  return "REX Sample" -- Fallback name if pattern match fails
end

--------------------------------------------------------------------------------
-- Binary Operations Helper Functions
--------------------------------------------------------------------------------
-- Read a big-endian 32-bit integer from memory
local function read_dword_from_memory(data, pos)
  local b1, b2, b3, b4 = data:byte(pos, pos + 3)
  return (b1 * 16777216) + (b2 * 65536) + (b3 * 256) + b4
end

--------------------------------------------------------------------------------
-- REX File Loading Functions
--------------------------------------------------------------------------------

-- Helper function to analyze and clean slice boundary
local function clean_slice_boundary(sample_buffer, slice_pos, next_slice_pos, is_last_slice, is_second_last_slice, slice_markers)
  -- Analysis window size for regular slices
  local ANALYSIS_WINDOW = 256

  -- Regular slice handling
  local divergence_point = nil
  local match_threshold = 0.0001
  
  if is_last_slice then
    -- For the last slice, remove exactly 252 frames before it by shifting data
    local header_length = 252
    local header_start = slice_pos - header_length
    
    -- Move all frames after the header to the left
    for frame = slice_pos, sample_buffer.number_of_frames do
      for channel = 1, sample_buffer.number_of_channels do
        local value = sample_buffer:sample_data(channel, frame)
        sample_buffer:set_sample_data(channel, frame - header_length, value)
      end
    end
    
    dprint(string.format("  Removed %d header frames before last slice by shifting data", header_length))
    
    -- Update the slice marker position
    if slice_markers and #slice_markers > 0 then
      slice_markers[#slice_markers] = slice_markers[#slice_markers] - header_length
    end
    
    return {
      cleaned_start = header_start,
      cleaned_end = slice_pos - 1,
      frames_removed = header_length
    }
  end
  
  if next_slice_pos then
    for offset = 0, ANALYSIS_WINDOW do
      if slice_pos + offset >= next_slice_pos then break end
      
      local current_sample = sample_buffer:sample_data(1, slice_pos + offset)
      local next_slice_sample = sample_buffer:sample_data(1, next_slice_pos + offset)
      
      if math.abs(current_sample - next_slice_sample) > match_threshold then
        divergence_point = slice_pos + offset
        break
      end
    end
  end
  
  if divergence_point then
    local analysis_start = math.max(1, divergence_point - 244)
    local analysis_end = math.min(sample_buffer.number_of_frames, divergence_point + 12)
    
    for frame = analysis_start, analysis_end do
      for channel = 1, sample_buffer.number_of_channels do
        sample_buffer:set_sample_data(channel, frame, 0.0)
      end
    end
    
    dprint(string.format("  Cleaned frames %d to %d around divergence point %d", 
      analysis_start, analysis_end, divergence_point))
    
    return {
      cleaned_start = analysis_start,
      cleaned_end = analysis_end
    }
  end
  
  return {
    cleaned_start = nil,
    cleaned_end = nil
  }
end

function rex_loadsample(filename)
  local song = renoise.song()
  
  -- Get clean filename for instrument name
  local instrument_name = get_clean_filename(filename)
  
  -- Check if current instrument exists and has content
  if song.selected_instrument and #song.selected_instrument.samples > 0 then
    -- Create new instrument
    local new_index = song.selected_instrument_index + 1
    song:insert_instrument_at(new_index)
    song.selected_instrument_index = new_index
  elseif not song.selected_instrument then
    -- No instrument selected, create new one at the end
    song:insert_instrument_at(#song.instruments + 1)
    song.selected_instrument_index = #song.instruments
  end
  
  -- Set the instrument name
  song.selected_instrument.name = instrument_name
  
  -- Make sure we have a sample to work with
  if #song.selected_instrument.samples < 1 then
    song.selected_instrument:insert_sample_at(1)
  end
  
  local smp = song.selected_sample
  if not smp then
    renoise.app():show_warning("REX Import Error", "Could not create or select a sample.")
    return false
  end
  
  -- Set sample name to match instrument
  smp.name = instrument_name
  
  local d = "" -- in memory copy
 
  renoise.app():show_status("Importing Recycle REX Sample...")
  dprint("rex_loadsample: filename=", filename)

  -- Create temporary AIFF file
  local aiff_copy = os.tmpname() .. ".aiff"
  dprint("rex_loadsample: aiff_copy=", aiff_copy)
  
  -- Open source file
  local f_in = io.open(filename, "rb")
  if not f_in then
    renoise.app():show_warning("REX Import Error", "Could not open source file: " .. filename)
    return false
  end
  
  -- Open temporary destination file
  local f_out = io.open(aiff_copy, "wb")
  if not f_out then
    f_in:close()
    renoise.app():show_warning("REX Import Error", "Could not create temporary file: " .. aiff_copy)
    return false
  end
  
  -- Read and write file contents
  f_in:seek("set")
  f_out:seek("set")
  d = f_in:read("*a")
  f_out:write(d)
  f_out:flush()
  
  -- Close file handles
  f_in:close()
  f_out:close()
  
  -- Import audio data
  if smp.sample_buffer and smp.sample_buffer.has_sample_data then
    if smp.sample_buffer.read_only then
      renoise.app():show_warning("REX Import Error", "Sample is read-only")
      os.remove(aiff_copy)
      return false
    end
  end
  
  -- Clear and load sample
  smp:clear()
  if not smp.sample_buffer:load_from(aiff_copy) then
    renoise.app():show_warning("REX Import Error", "Failed to load audio data")
    os.remove(aiff_copy)
    return false
  end

  -- Set sample properties to handle slice boundaries better
  smp.loop_mode = renoise.Sample.LOOP_MODE_OFF
  smp.new_note_action = renoise.Sample.NEW_NOTE_ACTION_NOTE_OFF
  smp.autofade = false -- Disable autofade to prevent artifacts at slice points
  smp.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC -- Better quality interpolation
  
  -- Find REX chunk
  local start_pos = d:find("REX ", 1, true)
  if not start_pos then
    dprint("rex_loadsample: couldn't find REX info, not adding slices")
    os.remove(aiff_copy)
    return true
  end
  
  dprint("rex_loadsample: found 'REX ' chunk at ", start_pos)
  
  -- The REX header is 1032 bytes, and we know this can cause garbage in the audio
  -- Let's clean up this region in the sample data
  if smp and smp.sample_buffer and smp.sample_buffer.has_sample_data then
    -- Calculate the frame position that corresponds to the REX header
    local header_frames = math.floor(start_pos + 1032)
    
    -- Clean up potential garbage around the header region
    smp.sample_buffer:prepare_sample_data_changes()
    for frame = math.max(1, header_frames - 256), header_frames + 256 do
      if frame <= smp.sample_buffer.number_of_frames then
        smp.sample_buffer:set_sample_data(1, frame, 0.0)
        if smp.sample_buffer.number_of_channels == 2 then
          smp.sample_buffer:set_sample_data(2, frame, 0.0)
        end
      end
    end
    smp.sample_buffer:finalize_sample_data_changes()
    
    dprint(string.format("Cleaned up potential garbage around REX header (frames %d to %d)", 
      math.max(1, header_frames - 256), math.min(smp.sample_buffer.number_of_frames, header_frames + 256)))
  end

  -- Move to start of slices (REX header size is 1032 bytes)
  start_pos = start_pos + 1032
  
  -- Add first slice marker
  smp:insert_slice_marker(1)
  
  -- Read and add remaining slice markers
  local slice = 0
  local prev_slice = 1
  local slice_points = {1} -- Store all slice points for analysis
  
  repeat
    slice = read_dword_from_memory(d, start_pos) + 1
    if slice > 1 then
      dprint("rex_loadsample: found slice marker with value ", slice)
      -- Ensure slice markers are properly aligned
      if slice > prev_slice then
        smp:insert_slice_marker(slice)
        table.insert(slice_points, slice)
        prev_slice = slice
      end
      start_pos = start_pos + 12
    end
  until slice == 1
  
  -- Analyze and clean sample data around slice points
  dprint("\nAnalyzing and cleaning slice boundaries:")
  dprint("Total number of slices: " .. #slice_points)
  
  -- Single prepare/finalize block for all sample data changes
  smp.sample_buffer:prepare_sample_data_changes()
  
  for i, slice_pos in ipairs(slice_points) do
    local next_slice_pos = (i < #slice_points) and slice_points[i + 1] or nil
    local is_last_slice = (i == #slice_points)
    local is_second_last_slice = (i == #slice_points - 1)
    
    -- Use the same cleaning approach for all slices
    local analysis = clean_slice_boundary(smp.sample_buffer, slice_pos, next_slice_pos, 
      is_last_slice, is_second_last_slice, smp.slice_markers)
      
    if analysis and analysis.cleaned_start then
      if is_last_slice then
        dprint(string.format("\nCleaning last slice (#%d) at position %d", i, slice_pos))
        dprint(string.format("Previous slice was at position %d", slice_points[i-1]))
      end
      dprint(string.format("  Cleaned region: %d to %d", 
        analysis.cleaned_start, analysis.cleaned_end))
    end
  end
  
  -- Single finalize for all changes
  smp.sample_buffer:finalize_sample_data_changes()

  -- Clean up
  os.remove(aiff_copy)
  d = nil
  collectgarbage()

  -- Final sample settings
  smp.fine_tune = 0
  smp.volume = 1.0
  
  renoise.app():show_status(string.format("REX file '%s' imported successfully", instrument_name))
  return true
end

--------------------------------------------------------------------------------
-- Register File Import Hook
--------------------------------------------------------------------------------
local rex_integration = {
  category = "sample",
  extensions = {"rex"},
  invoke = rex_loadsample
}

-- Only add the hook if it's not already registered
if not renoise.tool():has_file_import_hook("sample", {"rex"}) then
  renoise.tool():add_file_import_hook(rex_integration)
end 