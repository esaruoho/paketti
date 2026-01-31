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
  if not safeInsertInstrumentAt(renoise.song(), renoise.song().selected_instrument_index + 1) then return end
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


-- NOTE: EXE/DLL/BIN hook registration moved to end of file for centralized management

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
        if not safeInsertInstrumentAt(renoise.song(), renoise.song().selected_instrument_index + 1) then return end
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

-- ============================================================================
-- CENTRALIZED FILE IMPORT HOOK REGISTRATION
-- ============================================================================
-- All file import hooks are registered here with preference checks.
-- This allows users to enable/disable individual format imports via Paketti Toggler.
-- The master toggle (pakettiImportHooksEnabled) must be true AND the individual
-- format toggle must be true for the hook to be registered.
-- ============================================================================

local function should_register_hook(format_preference_key)
  -- Check master toggle first
  if not preferences.pakettiImportHooksEnabled.value then
    return false
  end
  -- Check individual format toggle
  if preferences[format_preference_key] and not preferences[format_preference_key].value then
    return false
  end
  return true
end

-- REX Import Hook (.rex)
if should_register_hook("pakettiImportREX") then
  if not renoise.tool():has_file_import_hook("sample", {"rex"}) then
    renoise.tool():add_file_import_hook({
      category = "sample",
      extensions = {"rex"},
      invoke = rex_loadsample
    })
  end
end

-- RX2 Import Hook (.rx2)
if should_register_hook("pakettiImportRX2") then
  if not renoise.tool():has_file_import_hook("sample", {"rx2"}) then
    renoise.tool():add_file_import_hook({
      category = "sample",
      extensions = {"rx2"},
      invoke = rx2_loadsample
    })
  end
end

-- IFF Import Hook (.iff, .8svx, .16sv)
if should_register_hook("pakettiImportIFF") then
  if not renoise.tool():has_file_import_hook("sample", {"iff", "8svx", "16sv"}) then
    renoise.tool():add_file_import_hook({
      name = "IFF (8SVX+16SV) -> WAV converter",
      category = "sample",
      extensions = {"iff", "8svx", "16sv"},
      invoke = loadIFFSample
    })
  end
end

-- SF2 Import Hook (.sf2)
if should_register_hook("pakettiImportSF2") then
  -- Remove any existing SF2 hook first (to avoid conflicts)
  if renoise.tool():has_file_import_hook("sample", {"sf2"}) then
    renoise.tool():remove_file_import_hook("sample", {"sf2"})
  end
  renoise.tool():add_file_import_hook({
    category = "sample",
    extensions = {"sf2"},
    invoke = import_sf2
  })
end

-- ITI Import Hook (.iti) - Impulse Tracker Instrument
if should_register_hook("pakettiImportITI") then
  if not renoise.tool():has_file_import_hook("instrument", {"iti"}) then
    renoise.tool():add_file_import_hook({
      category = "instrument",
      extensions = {"iti"},
      invoke = iti_loadinstrument
    })
  end
end

-- OT Import Hook (.ot) - Octatrack
if should_register_hook("pakettiImportOT") then
  if not renoise.tool():has_file_import_hook("sample", {"ot"}) then
    renoise.tool():add_file_import_hook({
      category = "sample",
      extensions = {"ot"},
      invoke = ot_import_filehook
    })
  end
end

-- WT Import Hook (.wt) - Wavetable
if should_register_hook("pakettiImportWT") then
  if not renoise.tool():has_file_import_hook("sample", {"wt"}) then
    renoise.tool():add_file_import_hook({
      category = "sample",
      extensions = {"wt"},
      invoke = wt_loadsample
    })
  end
end

-- STRD Import Hook (.strd, .work) - Octatrack STRD Bank
if should_register_hook("pakettiImportSTRD") then
  if not renoise.tool():has_file_import_hook("song", {"strd", "work"}) then
    renoise.tool():add_file_import_hook({
      category = "song",
      extensions = {"strd", "work"},
      invoke = strd_import_filehook
    })
  end
end

-- PTI Import Hook (.pti) - Polyend Tracker Instrument
if should_register_hook("pakettiImportPTI") then
  if not renoise.tool():has_file_import_hook("sample", {"pti"}) then
    renoise.tool():add_file_import_hook({
      category = "sample",
      extensions = {"pti"},
      invoke = pti_loadsample
    })
  end
  -- MTI Import Hook (.mti) - Polyend Tracker Mini Instrument
  if not renoise.tool():has_file_import_hook("sample", {"mti"}) then
    renoise.tool():add_file_import_hook({
      category = "sample",
      extensions = {"mti"},
      invoke = mti_loadsample
    })
  end
end

-- MTP/MT Import Hook (.mtp, .mt) - Polyend Tracker Pattern/Project
if should_register_hook("pakettiImportMTP") then
  -- MTP Pattern Import
  if not renoise.tool():has_file_import_hook("sample", {"mtp"}) then
    local success, error_msg = pcall(function()
      renoise.tool():add_file_import_hook({
        category = "sample",
        extensions = {"mtp"},
        invoke = mtp_import_hook
      })
    end)
    if not success then
      print("Warning: Could not register MTP hook: " .. tostring(error_msg))
    end
  end
  -- MT Project Import
  if not renoise.tool():has_file_import_hook("song", {"mt"}) then
    local success, error_msg = pcall(function()
      renoise.tool():add_file_import_hook({
        category = "song",
        extensions = {"mt"},
        invoke = mt_import_hook
      })
    end)
    if not success then
      print("Warning: Could not register MT hook: " .. tostring(error_msg))
    end
  end
end

-- MIDI Import Hook (.mid)
if should_register_hook("pakettiImportMID") then
  if not renoise.tool():has_file_import_hook("instrument", {"mid"}) then
    renoise.tool():add_file_import_hook({
      name = "MIDI IMPORT",
      category = "instrument",
      extensions = {"mid"},
      invoke = dudeMidi
    })
  end
end

-- TXT Import Hook (.txt) - eSpeak text-to-speech
if should_register_hook("pakettiImportTXT") then
  if not renoise.tool():has_file_import_hook("sample", {"txt"}) then
    renoise.tool():add_file_import_hook({
      category = "sample",
      extensions = {"txt"},
      invoke = txt_loadfile
    })
  end
end

-- Image Import Hook (.png, .bmp, .jpg, .jpeg, .gif) - API 6.2+ only
if renoise.API_VERSION >= 6.2 then
  if should_register_hook("pakettiImportImage") then
    if not renoise.tool():has_file_import_hook("sample", {"png", "bmp", "jpg", "jpeg", "gif"}) then
      renoise.tool():add_file_import_hook({
        category = "sample",
        extensions = {"png", "bmp", "jpg", "jpeg", "gif"},
        invoke = PakettiImageToSampleImportHook
      })
    end
  end
end

-- CSV Import Hook (.csv) - PCMWriter - API 6.2+ only
if renoise.API_VERSION >= 6.2 then
  if should_register_hook("pakettiImportCSV") then
    if not renoise.tool():has_file_import_hook("sample", {"csv"}) then
      renoise.tool():add_file_import_hook({
        category = "sample",
        extensions = {"csv"},
        invoke = csv_load_to_pcm_writer
      })
    end
  end
end

-- Raw Binary Import Hook (.exe, .dll, .bin, .sys, .dylib)
if should_register_hook("pakettiImportEXE") then
  if not renoise.tool():has_file_import_hook("sample", {"exe", "dll", "bin", "sys", "dylib"}) then
    renoise.tool():add_file_import_hook({
      category = "sample",
      extensions = {"exe", "dll", "bin", "sys", "dylib"},
      invoke = pakettiLoadExeAsSample
    })
  end
end

print("Paketti: Import hooks registered (Master=" .. tostring(preferences.pakettiImportHooksEnabled.value) .. ")")
