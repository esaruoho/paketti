-- PakettiFuzzySampleSearch.lua
-- Fuzzy Sample Search Dialog for Paketti
-- Recursive directory scanning with fuzzy search and quick loading

local dialog = nil
local current_files = {}
local filtered_files = {}
local selected_index = 1
local search_query = ""
local current_directory = ""
local max_results_per_column = 30
local columns_count = 5

-- ViewBuilder instance for use in update functions
local vb = renoise.ViewBuilder()

-- Store button references for efficient updates
local file_buttons = {}

-- Supported file extensions
local supported_extensions = {
  "wav", "flac", "aiff", "aif", "mp3", "m4a", "mp4", 
  "xrni", "sf2", "rex", "rx2", "pti", "iti", "iff"
}

-- Cache system variables
local cache_filename = "paketti_fuzzy_sample_cache.json"

-- Get the last used directory from preferences (no default)
function PakettiFuzzySampleSearchGetLastDirectory()
  if preferences.PakettiFuzzySampleSearch and preferences.PakettiFuzzySampleSearch.pakettiLastSampleSearchDirectory then
    local last_dir = preferences.PakettiFuzzySampleSearch.pakettiLastSampleSearchDirectory.value
    if last_dir and last_dir ~= "" then
      return last_dir
    end
  end
  -- Return empty string - no automatic directory selection
  return ""
end

-- Save the current directory to preferences
function PakettiFuzzySampleSearchSaveLastDirectory(directory)
  if not preferences.PakettiFuzzySampleSearch then
    preferences.PakettiFuzzySampleSearch = renoise.Document.create("PakettiFuzzySampleSearchPrefs") {
      pakettiLastSampleSearchDirectory = ""
    }
  end
  preferences.PakettiFuzzySampleSearch.pakettiLastSampleSearchDirectory.value = directory
end

-- Check if file has supported extension
function PakettiFuzzySampleSearchIsSupported(filename)
  local ext = filename:match("%.([^%.]+)$")
  if not ext then return false end
  ext = ext:lower()
  
  for _, supported_ext in ipairs(supported_extensions) do
    if ext == supported_ext then
      return true
    end
  end
  return false
end

-- Get cache file path
function PakettiFuzzySampleSearchGetCacheFilePath(directory)
  -- Create a unique cache filename based on directory path
  local dir_hash = ""
  for i = 1, #directory do
    dir_hash = dir_hash .. string.byte(directory:sub(i, i))
  end
  return renoise.tool().bundle_path .. "cache_" .. dir_hash .. ".json"
end

-- Get directory modification time (using stat command)
function PakettiFuzzySampleSearchGetDirectoryModTime(directory)
  local success, result = pcall(function()
    local handle = io.popen('stat -f "%m" "' .. directory .. '" 2>/dev/null')
    if handle then
      local modtime = handle:read("*l")
      handle:close()
      return tonumber(modtime) or 0
    end
    return 0
  end)
  return success and result or 0
end

-- Save cache to file
function PakettiFuzzySampleSearchSaveCache(directory, files)
  local cache_data = {
    directory = directory,
    directory_modtime = PakettiFuzzySampleSearchGetDirectoryModTime(directory),
    cache_time = os.time(),
    files = files
  }
  
  local cache_file_path = PakettiFuzzySampleSearchGetCacheFilePath(directory)
  local success, err = pcall(function()
    local file = io.open(cache_file_path, "w")
    if file then
      -- Simple JSON-like serialization
      local cache_str = "{\n"
      cache_str = cache_str .. '  "directory": "' .. directory:gsub('\\', '\\\\'):gsub('"', '\\"') .. '",\n'
      cache_str = cache_str .. '  "directory_modtime": ' .. cache_data.directory_modtime .. ',\n'
      cache_str = cache_str .. '  "cache_time": ' .. cache_data.cache_time .. ',\n'
      cache_str = cache_str .. '  "file_count": ' .. #files .. ',\n'
      cache_str = cache_str .. '  "files": [\n'
      
      for i, file_data in ipairs(files) do
        cache_str = cache_str .. '    {\n'
        cache_str = cache_str .. '      "name": "' .. file_data.name:gsub('\\', '\\\\'):gsub('"', '\\"') .. '",\n'
        cache_str = cache_str .. '      "full_path": "' .. file_data.full_path:gsub('\\', '\\\\'):gsub('"', '\\"') .. '",\n'
        cache_str = cache_str .. '      "relative_path": "' .. file_data.relative_path:gsub('\\', '\\\\'):gsub('"', '\\"') .. '",\n'
        cache_str = cache_str .. '      "display_name": "' .. file_data.display_name:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"\n'
        cache_str = cache_str .. '    }' .. (i < #files and ',' or '') .. '\n'
      end
      
      cache_str = cache_str .. '  ]\n'
      cache_str = cache_str .. '}\n'
      
      file:write(cache_str)
      file:close()
      renoise.app():show_status("Cache saved: " .. #files .. " files cached for future use")
    end
  end)
  
  if not success then
    print("Failed to save cache: " .. tostring(err))
  end
end

-- Load cache from file
function PakettiFuzzySampleSearchLoadCache(directory)
  local cache_file_path = PakettiFuzzySampleSearchGetCacheFilePath(directory)
  
  local success, cache_data = pcall(function()
    local file = io.open(cache_file_path, "r")
    if not file then return nil end
    
    local content = file:read("*a")
    file:close()
    
    -- Simple JSON parsing for our specific format
    local cache = {}
    cache.directory = content:match('"directory":%s*"([^"]*)"')
    cache.directory_modtime = tonumber(content:match('"directory_modtime":%s*(%d+)'))
    cache.cache_time = tonumber(content:match('"cache_time":%s*(%d+)'))
    cache.file_count = tonumber(content:match('"file_count":%s*(%d+)'))
    
    -- Parse files array
    cache.files = {}
    local files_section = content:match('"files":%s*%[(.-)%]')
    if files_section then
      for file_obj in files_section:gmatch('{.-}') do
        local file_data = {}
        file_data.name = file_obj:match('"name":%s*"([^"]*)"') or ""
        file_data.full_path = file_obj:match('"full_path":%s*"([^"]*)"') or ""
        file_data.relative_path = file_obj:match('"relative_path":%s*"([^"]*)"') or ""
        file_data.display_name = file_obj:match('"display_name":%s*"([^"]*)"') or ""
        
        -- Unescape strings
        file_data.name = file_data.name:gsub('\\"', '"'):gsub('\\\\', '\\')
        file_data.full_path = file_data.full_path:gsub('\\"', '"'):gsub('\\\\', '\\')
        file_data.relative_path = file_data.relative_path:gsub('\\"', '"'):gsub('\\\\', '\\')
        file_data.display_name = file_data.display_name:gsub('\\"', '"'):gsub('\\\\', '\\')
        
        table.insert(cache.files, file_data)
      end
    end
    
    return cache
  end)
  
  return success and cache_data or nil
end

-- Check if cache is valid for directory
function PakettiFuzzySampleSearchIsCacheValid(directory)
  local cache_data = PakettiFuzzySampleSearchLoadCache(directory)
  if not cache_data then return false end
  
  -- Check if directory matches
  if cache_data.directory ~= directory then return false end
  
  -- Check if directory was modified since cache was created
  local current_modtime = PakettiFuzzySampleSearchGetDirectoryModTime(directory)
  if current_modtime ~= cache_data.directory_modtime then return false end
  
  -- Cache is valid if less than 24 hours old and directory hasn't changed
  local cache_age = os.time() - (cache_data.cache_time or 0)
  return cache_age < (24 * 60 * 60) -- 24 hours
end

-- Process Slicer scanning variables
local scan_process_slicer = nil
local scan_dialog = nil
local scan_vb = nil

-- Recursively scan directory for supported files using ProcessSlicer
function PakettiFuzzySampleSearchScanDirectory(directory, callback)
  -- Check cache first
  if PakettiFuzzySampleSearchIsCacheValid(directory) then
    local cache_data = PakettiFuzzySampleSearchLoadCache(directory)
    if cache_data and cache_data.files then
      renoise.app():show_status("Loaded " .. #cache_data.files .. " files from cache (instant!)")
      if callback then callback(cache_data.files) end
      return
    end
  end
  
  -- Cancel any existing scan
  if scan_process_slicer and scan_process_slicer:running() then
    scan_process_slicer:cancel()
    scan_process_slicer:stop()
  end
  
  local files = {}
  local total_processed = 0
  
  local function scan_coroutine()
    -- Get all files first
    local all_filepaths = {}
    local success, items = pcall(function()
      return io.popen('find "' .. directory .. '" -type f 2>/dev/null'):lines()
    end)
    
    if success then
      for filepath in items do
        table.insert(all_filepaths, filepath)
      end
    else
      renoise.app():show_status("Could not scan directory. Please ensure the path is accessible.")
      if callback then callback({}) end
      return
    end
    
    local total_files = #all_filepaths
    if total_files == 0 then
      if callback then callback({}) end
      return
    end
    
    -- Process files in chunks to maintain responsiveness
    local chunk_size = 100
    for i = 1, total_files, chunk_size do
      -- Check for cancellation
      if scan_process_slicer and scan_process_slicer:was_cancelled() then
        renoise.app():show_status("Directory scan cancelled")
        if scan_dialog and scan_dialog.visible then
          scan_dialog:close()
          scan_dialog = nil
        end
        return
      end
      
      -- Process chunk
      local end_index = math.min(i + chunk_size - 1, total_files)
      for j = i, end_index do
        local filepath = all_filepaths[j]
        local filename = filepath:match("[^/]+$")
        if filename and PakettiFuzzySampleSearchIsSupported(filename) then
          -- Calculate relative path from base directory
          local rel_path = filepath:gsub("^" .. directory:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1") .. "/?", "")
          table.insert(files, {
            name = filename,
            full_path = filepath,
            relative_path = rel_path,
            display_name = rel_path
          })
        end
        total_processed = total_processed + 1
      end
      
      -- Update progress
      if scan_dialog and scan_dialog.visible and scan_vb then
        local progress_text = string.format("Scanning... %d/%d files (%d samples found)", 
          total_processed, total_files, #files)
        scan_vb.views.progress_text.text = progress_text
      end
      
      -- Yield to maintain responsiveness
      coroutine.yield()
    end
    
    -- Scan complete
    if scan_dialog and scan_dialog.visible then
      scan_dialog:close()
      scan_dialog = nil
    end
    
    -- Save results to cache
    if #files > 0 then
      PakettiFuzzySampleSearchSaveCache(directory, files)
    end
    
    if callback then 
      callback(files) 
    end
    
    renoise.app():show_status(string.format("Scan complete: Found %d samples", #files))
  end
  
  -- Start the process with progress dialog
  scan_process_slicer = ProcessSlicer(scan_coroutine)
  scan_dialog, scan_vb = scan_process_slicer:create_dialog("Scanning Directory...")
  scan_process_slicer:start()
end

-- Update the file list display by rebuilding the dialog
function PakettiFuzzySampleSearchUpdateDisplay()
  if not dialog or not dialog.visible then return end
  
  -- Apply fuzzy search filter
  if search_query == "" then
    filtered_files = current_files
  else
    filtered_files = PakettiFuzzySearchUtil(current_files, search_query, {
      search_type = "substring",
      field_extractor = function(file)
        return {file.display_name, file.name}
      end
    })
  end
  
  -- Limit results
  local max_display = max_results_per_column * columns_count
  if #filtered_files > max_display then
    local temp_files = {}
    for i = 1, max_display do
      table.insert(temp_files, filtered_files[i])
    end
    filtered_files = temp_files
  end
  
  -- Ensure selected index is valid
  if selected_index > #filtered_files then
    selected_index = #filtered_files
  end
  if selected_index < 1 and #filtered_files > 0 then
    selected_index = 1
  end
  
  -- Clear button references since we're recreating the dialog
  file_buttons = {}
  
  -- Close current dialog and recreate with updated content
  local was_visible = dialog.visible
  dialog:close()
  
  if was_visible then
    PakettiFuzzySampleSearchCreateDialog()
  end
  
  -- Update search display text
  if dialog and vb and vb.views.search_display then
    vb.views.search_display.text = search_query == "" and "(type to search)" or search_query
    vb.views.search_display.style = search_query == "" and "disabled" or "normal"
  end
end

-- Create the file display section
function PakettiFuzzySampleSearchCreateFileDisplay()
  local file_columns = {}
  
  -- Create columns
  for col = 1, columns_count do
    local column_start = (col - 1) * max_results_per_column + 1
    local column_end = math.min(col * max_results_per_column, #filtered_files)
    
    if column_start <= #filtered_files then
      local column_views = {}
      
      for i = column_start, column_end do
        local file = filtered_files[i]
        local is_selected = (i == selected_index)
        local button_text = file.display_name
        
        -- Truncate long names for display - wider buttons allow longer text
        if #button_text > 60 then
          button_text = button_text:sub(1, 57) .. "..."
        end
        
        local button = vb:button{
          text = button_text,
          width = 300,
          height = 22,
          font = is_selected and "bold" or "normal",
          color = is_selected and {0x80, 0xC0, 0xFF} or {0x00, 0x00, 0x00},
          notifier = function()
            selected_index = i
            PakettiFuzzySampleSearchUpdateSelection()
          end
        }
        
        -- Store button reference for efficient updates
        file_buttons[i] = button
        table.insert(column_views, button)
      end
      
      table.insert(file_columns, vb:column{
        views = column_views
      })
    end
  end
  
  return vb:horizontal_aligner{
    mode = "left",
    vb:row{
      views = file_columns
    }
  }
end

-- Create the main dialog content
function PakettiFuzzySampleSearchCreateDialog()
  -- Create a new ViewBuilder instance each time to avoid ID conflicts
  vb = renoise.ViewBuilder()
  
  -- Clear button references for fresh dialog
  file_buttons = {}
  local dialog_content = vb:column{
    
    vb:row{
      vb:text{
        id = "current_directory",
        text = current_directory ~= "" and ("Directory: " .. current_directory) or "No directory selected - Click Browse to choose",
        width = 350
      },
      vb:button{
        text = "Browse...",
        notifier = PakettiFuzzySampleSearchBrowseDirectory
      },
      current_directory ~= "" and vb:button{
        text = "Scan",
        tooltip = "Scan the displayed directory",
        notifier = function()
          if current_directory ~= "" then
            -- Clear existing files and update display
            current_files = {}
            filtered_files = {}
            search_query = ""
            selected_index = 1
            
            -- Recreate dialog to show scanning state
            if dialog and dialog.visible then
              local was_visible = dialog.visible
              dialog:close()
              if was_visible then
                PakettiFuzzySampleSearchCreateDialog()
              end
            end
            
            -- Scan directory with callback
            PakettiFuzzySampleSearchScanDirectory(current_directory, function(files)
              current_files = files
              search_query = ""
              selected_index = 1
              
              if dialog and dialog.visible then
                PakettiFuzzySampleSearchUpdateDisplay()
              end
            end)
          end
        end
      } or vb:space{width = 60},
      current_directory ~= "" and vb:button{
        text = "Clear Cache",
        tooltip = "Force rescan by clearing cached results",
        width = 80,
        notifier = function()
          local cache_file_path = PakettiFuzzySampleSearchGetCacheFilePath(current_directory)
          local success = pcall(function()
            os.remove(cache_file_path)
          end)
          if success then
            renoise.app():show_status("Cache cleared - next scan will be fresh")
          else
            renoise.app():show_status("No cache to clear")
          end
        end
      } or nil
    },
    
    vb:row{
      vb:text{
        text = "Search:",
        width = 50
      },
      vb:text{
        id = "search_display",
        text = search_query == "" and "(type to search)" or search_query,
        width = 400,
        style = search_query == "" and "disabled" or "normal",
        font = "mono"
      },
      vb:button{
        id = "columns_button",
        text = "Columns: " .. columns_count,
        tooltip = "Click to cycle through 2, 3, 4, 5, 6 columns",
        width = 90,
        notifier = function()
          local column_options = {2, 3, 4, 5, 6}
          local current_pos = 1
          for i, cols in ipairs(column_options) do
            if cols == columns_count then
              current_pos = i
              break
            end
          end
          
          columns_count = column_options[(current_pos % #column_options) + 1]
          
          if dialog and dialog.visible then
            local was_visible = dialog.visible
            dialog:close()
            if was_visible then
              PakettiFuzzySampleSearchCreateDialog()
            end
          end
        end
      },
      vb:popup{
        id = "items_per_column",
        items = {"10 per column", "20 per column", "30 per column", "40 per column", "50 per column"},
        value = 3, -- Default to 30
        width = 100,
        notifier = function(value)
          local items_options = {10, 20, 30, 40, 50}
          max_results_per_column = items_options[value]
          
          if dialog and dialog.visible then
            local was_visible = dialog.visible
            dialog:close()
            if was_visible then
              PakettiFuzzySampleSearchCreateDialog()
            end
          end
        end
      },
      vb:text{
        id = "file_count", 
        text = #filtered_files > 0 and (
          #current_files > #filtered_files and 
          string.format("Files: %d (of %d total)", #filtered_files, #current_files) or
          string.format("Files: %d", #filtered_files)
        ) or (
          #current_files > 0 and string.format("Files: %d", #current_files) or "Choose directory to see files"
        ),
        width = 200
      }
    },
    
    vb:text{
      text = "Use ↑↓←→ to navigate (visual highlight + status bar), Enter to load (keeps dialog open), Esc to clear search/close",
      style = "disabled"
    },
    
    PakettiFuzzySampleSearchCreateFileDisplay(),
    
    vb:row{
      vb:button{
        text = "Close",
        notifier = function()
          if dialog and dialog.visible then
            dialog:close()
            dialog = nil
          end
        end
      }
    }
  }
  
  -- Create custom keyhandler that combines close functionality with navigation
  local keyhandler = function(dialog_ref, key)
    -- First handle our custom keys
    local handled_key = PakettiFuzzySampleSearchKeyHandler(dialog_ref, key)
    if handled_key == nil then
      return nil  -- Key was handled by our function, stop processing
    end
    
    -- If not handled by our function, check for dialog close preference
    local closer = preferences.pakettiDialogClose.value
    if key.modifiers == "" and key.name == closer then
      dialog_ref:close()
      dialog = nil
      return nil
    end
    
    return key  -- Pass through unhandled keys
  end
  
  dialog = renoise.app():show_custom_dialog("Paketti Fuzzy Sample Search", dialog_content, keyhandler)
  
  -- Show initial selection in status bar
  PakettiFuzzySampleSearchUpdateSelection()
end

-- Load the selected sample
function PakettiFuzzySampleSearchLoadSelected()
  if selected_index < 1 or selected_index > #filtered_files then
    renoise.app():show_status("No file selected")
    return
  end
  
  local file = filtered_files[selected_index]
  local file_path = file.full_path
  local file_ext = file_path:match("%.([^%.]+)$"):lower()
  
  -- Load different file types appropriately
  if file_ext == "xrni" then
    -- Load XRNI following Paketti conventions
    local song = renoise.song()
    song:insert_instrument_at(song.selected_instrument_index + 1)
    song.selected_instrument_index = song.selected_instrument_index + 1
    
    -- Apply Paketti default instrument configuration before loading XRNI
    if pakettiPreferencesDefaultInstrumentLoader then
      pakettiPreferencesDefaultInstrumentLoader()
    end
    
    renoise.app():load_instrument(file_path)
    
    -- Clean up any "Placeholder sample" left behind
    local instrument = song.selected_instrument
    for i = #instrument.samples, 1, -1 do
      if instrument.samples[i].name == "Placeholder sample" then
        instrument:delete_sample_at(i)
      end
    end
    
    renoise.app():show_status("Loaded XRNI: " .. file.name)
  elseif file_ext == "sf2" then
    -- Load SF2 files - show message for now (loader functions need integration)
    renoise.app():show_status("SF2 files: Use Paketti SF2 Loader from menu for now")
  elseif file_ext == "rex" then
    -- Load REX files using rex_loadsample function
    if rex_loadsample then
      rex_loadsample(file_path)
    else
      renoise.app():show_status("REX loader not available")
    end
  elseif file_ext == "rx2" then
    -- Load RX2 files - show message for now (loader functions need integration)  
    renoise.app():show_status("RX2 files: Use Paketti RX2 Loader from menu for now")
  elseif file_ext == "pti" then
    -- Load PTI files - show message for now (loader functions need integration)
    renoise.app():show_status("PTI files: Use Paketti PTI Loader from menu for now")
  elseif file_ext == "iti" then
    -- Load ITI files - show message for now (loader functions need integration)
    renoise.app():show_status("ITI files: Use Paketti ITI Loader from menu for now")
  elseif file_ext == "iff" then
    -- Load IFF files - show message for now (loader functions need integration)
    renoise.app():show_status("IFF files: Use Paketti IFF Loader from menu for now")
  else
    -- Load regular audio files (wav, flac, aiff, mp3, etc.)
    local song = renoise.song()
    
    -- Create new instrument following Paketti conventions
    song:insert_instrument_at(song.selected_instrument_index + 1)
    song.selected_instrument_index = song.selected_instrument_index + 1
    
    -- Apply Paketti default instrument configuration
    if pakettiPreferencesDefaultInstrumentLoader then
      pakettiPreferencesDefaultInstrumentLoader()
    end
    
    local instrument = song.selected_instrument
    
    -- Load the sample
    local sample_index = #instrument.samples + 1
    instrument:insert_sample_at(sample_index)
    song.selected_sample_index = sample_index
    
    local sample_buffer = song.selected_sample.sample_buffer
    sample_buffer:load_from(file_path)
    
    -- Set both instrument and sample name to filename (without extension)
    local name_without_ext = file.name:match("(.+)%..+$") or file.name
    instrument.name = name_without_ext
    song.selected_sample.name = name_without_ext
    
    -- Clean up any "Placeholder sample" left behind by default instrument loader
    for i = #instrument.samples, 1, -1 do
      if instrument.samples[i].name == "Placeholder sample" then
        instrument:delete_sample_at(i)
      end
    end
    
    renoise.app():show_status("Loaded sample: " .. file.name)
  end
  
  -- Don't close dialog - user requested to keep it open
end

-- Navigate selection up/down
function PakettiFuzzySampleSearchNavigate(direction)
  if #filtered_files == 0 then return end
  
  local old_index = selected_index
  
  if direction == "up" then
    selected_index = selected_index - 1
    if selected_index < 1 then
      selected_index = #filtered_files
    end
  elseif direction == "down" then
    selected_index = selected_index + 1
    if selected_index > #filtered_files then
      selected_index = 1
    end
  elseif direction == "left" then
    -- Move to previous column (subtract max_results_per_column)
    selected_index = selected_index - max_results_per_column
    if selected_index < 1 then
      -- Wrap to end, find equivalent position in last column
      local position_in_column = ((selected_index - 1) % max_results_per_column) + 1
      local last_column_start = math.floor((#filtered_files - 1) / max_results_per_column) * max_results_per_column + 1
      selected_index = math.min(last_column_start + position_in_column - 1, #filtered_files)
    end
  elseif direction == "right" then
    -- Move to next column (add max_results_per_column)
    selected_index = selected_index + max_results_per_column
    if selected_index > #filtered_files then
      -- Wrap to beginning, find equivalent position in first column
      local position_in_column = ((selected_index - 1) % max_results_per_column) + 1
      selected_index = position_in_column
    end
  end
  
  if old_index ~= selected_index then
    -- Just update the button colors without recreating the dialog
    PakettiFuzzySampleSearchUpdateSelection()
  end
end

-- Fast selection update without dialog recreation
function PakettiFuzzySampleSearchUpdateSelection()
  -- Update button colors efficiently like Dialog of Dialogs does
  for i, button in pairs(file_buttons) do
    if button and button.color then
      if i == selected_index then
        button.color = {0x80, 0xC0, 0xFF} -- Light blue for selected
        button.font = "bold"
      else
        button.color = {0x00, 0x00, 0x00} -- Default for unselected
        button.font = "normal"
      end
    end
  end
  
  -- Also show selection in status bar
  if #filtered_files > 0 and selected_index >= 1 and selected_index <= #filtered_files then
    local selected_file = filtered_files[selected_index]
    renoise.app():show_status(string.format("Selected: %s (%d/%d)", selected_file.display_name, selected_index, #filtered_files))
  end
end

-- Handle search input
function PakettiFuzzySampleSearchUpdateSearch(new_query)
  search_query = new_query
  selected_index = 1
  PakettiFuzzySampleSearchUpdateDisplay()
end

-- Browse for directory
function PakettiFuzzySampleSearchBrowseDirectory()
  local new_directory = renoise.app():prompt_for_path("Select Sample Directory")
  if new_directory and new_directory ~= "" then
    current_directory = new_directory
    PakettiFuzzySampleSearchSaveLastDirectory(current_directory)
    
    -- Clear existing files and update display
    current_files = {}
    filtered_files = {}
    search_query = ""
    selected_index = 1
    
    -- Recreate dialog to show scanning state
    if dialog and dialog.visible then
      local was_visible = dialog.visible
      dialog:close()
      if was_visible then
        PakettiFuzzySampleSearchCreateDialog()
      end
    end
    
    -- Scan new directory with callback
    PakettiFuzzySampleSearchScanDirectory(current_directory, function(files)
      current_files = files
      search_query = ""
      selected_index = 1
      
      if dialog and dialog.visible then
        PakettiFuzzySampleSearchUpdateDisplay()
      end
    end)
  end
end

-- Key handler for the dialog
function PakettiFuzzySampleSearchKeyHandler(dialog_ref, key)
  if not dialog_ref or not dialog_ref.visible then
    return key
  end
  
  -- Handle keys regardless of modifiers for basic navigation and search
  if key.modifiers == "" then
    if key.name == "up" then
      PakettiFuzzySampleSearchNavigate("up")
      return nil
    elseif key.name == "down" then
      PakettiFuzzySampleSearchNavigate("down")
      return nil
    elseif key.name == "left" then
      PakettiFuzzySampleSearchNavigate("left")
      return nil
    elseif key.name == "right" then
      PakettiFuzzySampleSearchNavigate("right")
      return nil
    elseif key.name == "return" then
      PakettiFuzzySampleSearchLoadSelected()
      -- Don't close dialog, just load sample
      return nil
    elseif key.name == "escape" then
      if search_query ~= "" then
        PakettiFuzzySampleSearchUpdateSearch("")
        return nil
      else
        dialog_ref:close()
        dialog = nil
        return nil
      end
    elseif key.name == "backspace" then
      if #search_query > 0 then
        PakettiFuzzySampleSearchUpdateSearch(search_query:sub(1, -2))
        return nil
      end
    elseif key.name == "space" then
      PakettiFuzzySampleSearchUpdateSearch(search_query .. " ")
      return nil
    elseif #key.name == 1 then  -- Single character
      PakettiFuzzySampleSearchUpdateSearch(search_query .. key.name)
      return nil
    end
  end
  
  return key
end

-- Main dialog function
function PakettiFuzzySampleSearchDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  
  -- Get starting directory 
  local last_directory = PakettiFuzzySampleSearchGetLastDirectory()
  
  -- Only reset files if directory changed or no directory set
  if current_directory ~= last_directory then
    current_directory = last_directory
    current_files = {}
    filtered_files = {}
    search_query = ""
    selected_index = 1
    
    -- Try to load from cache if directory is set
    if current_directory ~= "" and PakettiFuzzySampleSearchIsCacheValid(current_directory) then
      local cache_data = PakettiFuzzySampleSearchLoadCache(current_directory)
      if cache_data and cache_data.files then
        current_files = cache_data.files
        filtered_files = cache_data.files
        renoise.app():show_status("Loaded " .. #current_files .. " files from cache")
      end
    end
  end
  
  -- Always reset selection to start
  selected_index = 1
  
  -- Create the dialog
  PakettiFuzzySampleSearchCreateDialog()
  
  if current_directory ~= "" then
    if #current_files > 0 then
      renoise.app():show_status("Sample Search opened - " .. #current_files .. " files ready from: " .. current_directory)
    else
      renoise.app():show_status("Sample Search opened - Previous directory: " .. current_directory .. " (click Scan to load)")
    end
  else
    renoise.app():show_status("Sample Search opened - Click Browse to select a directory")
  end
end

-- Add keybinding
renoise.tool():add_keybinding{
  name = "Global:Paketti:Fuzzy Sample Search Dialog...",
  invoke = PakettiFuzzySampleSearchDialog
}

-- Add menu entries
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:!Loaders:Fuzzy Sample Search Dialog...",
  invoke = PakettiFuzzySampleSearchDialog
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti Fuzzy Sample Search...",
  invoke = PakettiFuzzySampleSearchDialog
}
