-- big-endian 16-bit reader, 1-based
local function read_be_u16(str, pos)
  local b1,b2 = str:byte(pos,pos+1)
  return b1*256 + b2
end

-- determine where in a 4-ch/31-sample .mod the sample data begins
local function find_mod_sample_data_offset(data)
  -- song length
  local song_len = data:byte(951)
  -- pattern table
  local patt = { data:byte(953, 953+127) }
  local maxp = 0
  for i=1,song_len do
    if patt[i] and patt[i]>maxp then maxp = patt[i] end
  end
  local num_patterns = maxp + 1

  -- channel count from bytes 1081–1084
  local id = data:sub(1081,1084)
  local channels = ({
    ["M.K."]=4, ["4CHN"]=4, ["6CHN"]=6,
    ["8CHN"]=8, ["FLT4"]=4, ["FLT8"]=8
  })[id] or 4

  -- offset = 1084 (end of header) + pattern_data_size
  local pattern_data_size = num_patterns * 64 * channels * 4
  return 1084 + pattern_data_size
end

function pakettiLoadExeAsSample(file_path)
  local f = io.open(file_path,"rb")
  if not f then 
    renoise.app():show_status("Could not open file: "..file_path)
    return 
  end
  local data = f:read("*all")
  f:close()
  if #data == 0 then 
    renoise.app():show_status("File is empty.") 
    return 
  end

  -- detect .mod by extension or signature
  local is_mod = file_path:lower():match("%.mod$")
  if not is_mod then
    -- maybe detect signature too?
    local sig = data:sub(1081,1084)
    if sig:match("^[46]CHN$") or sig=="M.K." or sig=="FLT4" or sig=="FLT8" then
      is_mod = true
    end
  end

  local raw
  if is_mod then
    -- strip header & patterns
    local off = find_mod_sample_data_offset(data)
    -- Lua strings are 1-based, so data:sub(off+1) if off bytes are header
    raw = data:sub(off+1)
  else
    raw = data
  end

  -- now load raw as before
  local name = file_path:match("([^\\/]+)$") or "Sample"
  renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
  renoise.song().selected_instrument_index =
    renoise.song().selected_instrument_index + 1
  pakettiPreferencesDefaultInstrumentLoader()

  local instr = renoise.song().selected_instrument
  instr.name = name

  local smp = instr:insert_sample_at(#instr.samples+1)
  smp.name = name

  -- 8363 Hz, 8-bit, mono
  local length = #raw
  smp.sample_buffer:create_sample_data(8363, 8, 1, length)

  local buf = smp.sample_buffer
  buf:prepare_sample_data_changes()
  for i = 1, length do
    local byte = raw:byte(i)
    local val  = (byte / 255) * 2.0 - 1.0
    buf:set_sample_data(1, i, val)
  end
  buf:finalize_sample_data_changes()

  -- clean up any “Placeholder sample” left behind
  for i = #instr.samples, 1, -1 do
    if instr.samples[i].name == "Placeholder sample" then
      instr:delete_sample_at(i)
    end
  end

  renoise.app().window.active_middle_frame =
    renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR

  local what = is_mod and "MOD samples" or "bytes"
  renoise.app():show_status(
    ("Loaded %q as 8-bit-style sample (%d %s at 8363Hz).")
    :format(name, length, what)
  )
end


renoise.tool():add_file_import_hook{category="sample",extensions={"exe","dll","bin","sys","dylib"},invoke=pakettiLoadExeAsSample}


-------
-- ======================================
-- Paketti Multi-File Raw Loader
-- ======================================
-- Load multiple files as 8-bit samples, one file per instrument slot

function pakettiMultiFileRawLoader()
  -- Prompt for multiple files - support ALL file types
  local file_paths = renoise.app():prompt_for_multiple_filenames_to_read(
    {"*.*"}, 
    "Select Multiple Files to Load as 8-bit Raw Samples"
  )
  
  if not file_paths or #file_paths == 0 then
    renoise.app():show_status("No files selected")
    return
  end
  
  local loaded_count = 0
  local failed_count = 0
  local failed_files = {}
  
  -- Process each selected file
  for i, file_path in ipairs(file_paths) do
    renoise.app():show_status(string.format("Loading file %d of %d: %s", i, #file_paths, file_path:match("([^\\/]+)$") or "Unknown"))
    
    -- Load the file
    local f = io.open(file_path, "rb")
    if not f then 
      failed_count = failed_count + 1
      table.insert(failed_files, file_path:match("([^\\/]+)$") or file_path)
      print("-- Paketti Multi-File Raw Loader: Could not open file: " .. file_path)
    else
      local data = f:read("*all")
      f:close()
      
      if #data == 0 then 
        failed_count = failed_count + 1
        table.insert(failed_files, file_path:match("([^\\/]+)$") or file_path)
        print("-- Paketti Multi-File Raw Loader: File is empty: " .. file_path)
      else
        -- Use the same logic as pakettiLoadExeAsSample for .mod detection
        local is_mod = file_path:lower():match("%.mod$")
        if not is_mod then
          -- maybe detect signature too?
          local sig = data:sub(1081,1084)
          if sig:match("^[46]CHN$") or sig=="M.K." or sig=="FLT4" or sig=="FLT8" then
            is_mod = true
          end
        end

        local raw
        if is_mod then
          -- strip header & patterns using the same function
          local off = find_mod_sample_data_offset(data)
          raw = data:sub(off+1)
        else
          raw = data
        end

        -- Create new instrument for this file
        local name = file_path:match("([^\\/]+)$") or "Sample"
        renoise.song():insert_instrument_at(renoise.song().selected_instrument_index + 1)
        renoise.song().selected_instrument_index = renoise.song().selected_instrument_index + 1
        
        -- Apply default instrument loader settings
        pakettiPreferencesDefaultInstrumentLoader()

        local instr = renoise.song().selected_instrument
        instr.name = name

        local smp = instr:insert_sample_at(#instr.samples+1)
        smp.name = name

        -- Create 8-bit, 8363 Hz, mono sample (same as existing loader)
        local length = #raw
        smp.sample_buffer:create_sample_data(8363, 8, 1, length)

        local buf = smp.sample_buffer
        buf:prepare_sample_data_changes()
        for byte_index = 1, length do
          local byte = raw:byte(byte_index)
          local val = (byte / 255) * 2.0 - 1.0
          buf:set_sample_data(1, byte_index, val)
        end
        buf:finalize_sample_data_changes()

        -- Clean up any "Placeholder sample" left behind
        for sample_index = #instr.samples, 1, -1 do
          if instr.samples[sample_index].name == "Placeholder sample" then
            instr:delete_sample_at(sample_index)
          end
        end

        loaded_count = loaded_count + 1
        local what = is_mod and "MOD samples" or "bytes"
        print(string.format("-- Paketti Multi-File Raw Loader: Loaded %q as 8-bit sample (%d %s at 8363Hz)", name, length, what))
      end
    end
  end
  
  -- Show final results
  if loaded_count > 0 then
    -- Switch to sample editor to show the results
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    
    local status_message = string.format("Loaded %d file(s) as 8-bit raw samples", loaded_count)
    if failed_count > 0 then
      status_message = status_message .. string.format(" (%d failed)", failed_count)
    end
    
    renoise.app():show_status(status_message)
    print(string.format("-- Paketti Multi-File Raw Loader: Completed - %d files loaded, %d failed", loaded_count, failed_count))
    
    if failed_count > 0 then
      print("-- Paketti Multi-File Raw Loader: Failed files: " .. table.concat(failed_files, ", "))
    end
  else
    renoise.app():show_warning("No files could be loaded")
    print("-- Paketti Multi-File Raw Loader: No files were successfully loaded")
  end
end

renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Instruments:File Formats:Multi-File Raw Loader (8-bit)", invoke = pakettiMultiFileRawLoader}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Load:Multi-File Raw Loader (8-bit)", invoke = pakettiMultiFileRawLoader}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Load:Multi-File Raw Loader (8-bit)", invoke = pakettiMultiFileRawLoader}
renoise.tool():add_keybinding{name = "Global:Paketti:Multi-File Raw Loader (8-bit)", invoke = pakettiMultiFileRawLoader}
renoise.tool():add_midi_mapping{name = "Paketti:Multi-File Raw Loader (8-bit)", invoke = function(message) if message:is_trigger() then pakettiMultiFileRawLoader() end end}
