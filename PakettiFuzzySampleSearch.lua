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
local current_page = 1
local results_per_page = 150 -- Maximum buttons to create at once
local max_safe_results_per_page = 50 -- CRITICAL FIX: Much smaller for very large file sets to prevent unresponsiveness
-- Removed esc_just_closed_dialog flag - no longer needed since ESC doesn't close dialog when search is empty

-- Colors for button highlighting (from PakettiGater.lua)
local normal_color = {0, 0, 0}  -- Default black
local selected_color = {0x80, 0x00, 0x80}  -- Deep purple for selected

-- Optimization: Cache search results and pagination data
local cached_search_query = ""
local cached_search_results = {}
local cached_pagination_info = {total_results = 0, max_pages = 1}

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

-- Get the last used directory from preferences
function PakettiFuzzySampleSearchGetLastDirectory()
  return preferences.PakettiFuzzySampleSearchPath.value or ""
end

-- Save the current directory to preferences
function PakettiFuzzySampleSearchSaveLastDirectory(directory)
  preferences.PakettiFuzzySampleSearchPath.value = directory
  preferences:save_as("preferences.xml")
end

-- Optimized: Create extension lookup table for O(1) checking
local supported_ext_lookup = {}
for _, ext in ipairs(supported_extensions) do
  supported_ext_lookup[ext] = true
end

-- Check if file has supported extension (optimized)
function PakettiFuzzySampleSearchIsSupported(filename)
  local ext = filename:match("%.([^%.]+)$")
  if not ext then return false end
  return supported_ext_lookup[ext:lower()] == true
end

-- Optimized bulk file processing
function PakettiFuzzySampleSearchProcessFilesBulk(filepaths, directory, start_idx, end_idx)
  local results = {}
  local directory_prefix = directory .. "/"
  local dir_len = #directory_prefix
  
  -- Pre-escape directory pattern once
  local dir_pattern = "^" .. directory:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1") .. "/?$"
  
  for i = start_idx, end_idx do
    local filepath = filepaths[i]
    local filename = filepath:match("[^/]+$")
    
    if filename then
      local ext = filename:match("%.([^%.]+)$")
      if ext and supported_ext_lookup[ext:lower()] then
        -- Fast relative path calculation
        local rel_path = filepath:gsub(dir_pattern, "")
        if rel_path == filepath then
          -- Fallback to substring method if gsub didn't work
          if filepath:sub(1, dir_len) == directory_prefix then
            rel_path = filepath:sub(dir_len + 1)
          else
            rel_path = filename
          end
        end
        
        results[#results + 1] = {
          name = filename,
          full_path = filepath,
          relative_path = rel_path,
          display_name = rel_path
        }
      end
    end
  end
  
  return results
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
    -- Optimized: Use shell command to pre-filter by extension for massive speedup
    local extensions_pattern = "\\.(" .. table.concat(supported_extensions, "|") .. ")$"
    local find_cmd = string.format('find "%s" -type f | grep -iE "%s" 2>/dev/null', directory, extensions_pattern)
    
    local all_filepaths = {}
    local success, items = pcall(function()
      return io.popen(find_cmd):lines()
    end)
    
    if success then
      for filepath in items do
        all_filepaths[#all_filepaths + 1] = filepath
      end
    else
      -- Fallback to original method if grep fails
      success, items = pcall(function()
        return io.popen('find "' .. directory .. '" -type f 2>/dev/null'):lines()
      end)
      
      if success then
        for filepath in items do
          all_filepaths[#all_filepaths + 1] = filepath
        end
      else
        renoise.app():show_status("Could not scan directory. Please ensure the path is accessible.")
        if callback then callback({}) end
        return
      end
    end
    
    local total_files = #all_filepaths
    if total_files == 0 then
      if callback then callback({}) end
      return
    end
    
    -- Process files in massive chunks - no reason to be conservative  
    local chunk_size = 25000 -- Massive chunks for maximum performance
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
      
      -- Process chunk with optimized bulk function
      local end_index = math.min(i + chunk_size - 1, total_files)
      local chunk_results = PakettiFuzzySampleSearchProcessFilesBulk(all_filepaths, directory, i, end_index)
      
      -- Bulk append results (much faster than individual inserts)
      for _, file_data in ipairs(chunk_results) do
        files[#files + 1] = file_data
      end
      
      total_processed = end_index
      
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

-- Optimization: Calculate and cache search results efficiently
function PakettiFuzzySampleSearchCalculateFilteredResults(force_recalc)
  -- Only recalculate if search query changed or forced
  if not force_recalc and search_query == cached_search_query then
    return cached_search_results
  end
  
  cached_search_query = search_query
  
  if search_query == "" then
    cached_search_results = current_files
  else
    -- CRITICAL FIX: For very large file sets, use simple substring matching instead of fuzzy search
    -- This is much faster and prevents timeouts with 185k+ files
    if #current_files > 10000 then
      cached_search_results = {}
      local query_lower = search_query:lower()
      -- Use more efficient string matching for large file sets
      for _, file in ipairs(current_files) do
        if file.display_name:lower():find(query_lower, 1, true) or 
           file.name:lower():find(query_lower, 1, true) then
          table.insert(cached_search_results, file)
        end
      end
    else
      -- Use fuzzy search for smaller file sets
      cached_search_results = PakettiFuzzySearchUtil(current_files, search_query, {
        search_type = "substring",
        field_extractor = function(file)
          return {file.display_name, file.name}
        end
      })
    end
  end
  
  -- Update pagination info - use appropriate page size for large file sets
  cached_pagination_info.total_results = #cached_search_results
  -- CRITICAL FIX: Use much smaller page sizes for very large file sets to prevent unresponsiveness
  local effective_page_size = results_per_page
  if #cached_search_results > 100000 then
    effective_page_size = max_safe_results_per_page
  elseif #cached_search_results > 50000 then
    effective_page_size = 75 -- Medium page size for large file sets
  end
  cached_pagination_info.max_pages = math.ceil(cached_pagination_info.total_results / effective_page_size)
  
  return cached_search_results
end

-- Update the file list display efficiently without recreating dialog
function PakettiFuzzySampleSearchUpdateDisplay(force_recalc)
  if not dialog or not dialog.visible then return end
  
  -- Get filtered results (uses cache if possible)
  local all_filtered = PakettiFuzzySampleSearchCalculateFilteredResults(force_recalc)
  
  -- Use cached pagination info
  local total_results = cached_pagination_info.total_results
  local max_pages = cached_pagination_info.max_pages
  
  if current_page > max_pages then
    current_page = max_pages
  end
  if current_page < 1 then
    current_page = 1
  end
  
  -- Get current page of results - use smaller page size for very large file sets
  local effective_results_per_page = results_per_page
  if total_results > 100000 then
    effective_results_per_page = max_safe_results_per_page
  elseif total_results > 50000 then
    effective_results_per_page = 75 -- Medium page size for large file sets
  end
  
  local start_index = ((current_page - 1) * effective_results_per_page) + 1
  local end_index = math.min(start_index + effective_results_per_page - 1, total_results)
  local page_files = {}
  for i = start_index, end_index do
    table.insert(page_files, all_filtered[i])
  end
  filtered_files = page_files
  
  print("DEBUG: Pagination - current_page=" .. current_page .. ", start_index=" .. start_index .. ", end_index=" .. end_index .. ", page_files_count=" .. #page_files .. ", total_results=" .. total_results)
  
  -- Ensure selected index is valid
  if selected_index > #filtered_files then
    selected_index = #filtered_files
  end
  if selected_index < 1 and #filtered_files > 0 then
    selected_index = 1
  end
  
  -- CRITICAL FIX: Always use in-place updates to avoid dialog recreation
  -- Dialog recreation is the main cause of unresponsiveness with large file sets
  PakettiFuzzySampleSearchUpdateButtonsInPlace()
  PakettiFuzzySampleSearchUpdateStatusInPlace()
  PakettiFuzzySampleSearchUpdateSelection()
end

-- Get current popup value based on max_results_per_column setting  
function PakettiFuzzySampleSearchGetCurrentPerColumnValue()
  local items_options = {15, 20, 25, 30, 35, 40, 45, 50}
  for i, option in ipairs(items_options) do
    if option == max_results_per_column then
      return i
    end
  end
  return 4 -- Default to 30 if not found (index 4)
end

-- Get status text with pagination info
function PakettiFuzzySampleSearchGetStatusText()
  -- Use cached results instead of recalculating
  PakettiFuzzySampleSearchCalculateFilteredResults(false)
  local total_filtered = cached_pagination_info.total_results
  
  if total_filtered == 0 then
    if #current_files > 0 then
      return "No matches"
    else
      return "Choose directory to see files"
    end
  end
  
  local max_pages = cached_pagination_info.max_pages
  local showing_count = #filtered_files
  
  if max_pages > 1 then
    -- Calculate the actual range of files being displayed
    local effective_results_per_page = results_per_page
    if total_filtered > 100000 then
      effective_results_per_page = max_safe_results_per_page
    elseif total_filtered > 50000 then
      effective_results_per_page = 75 -- Medium page size for large file sets
    end
    
    local start_index = ((current_page - 1) * effective_results_per_page) + 1
    local end_index = math.min(start_index + showing_count - 1, total_filtered)
    
    return string.format("Files: %d-%d/%d", start_index, end_index, total_filtered)
  else
    return string.format("Files: %d", total_filtered)
  end
end

-- Create compact pagination controls for the control row
function PakettiFuzzySampleSearchCreatePaginationControlsCompact()
  -- Use cached pagination info
  local max_pages = cached_pagination_info.max_pages
  
  if max_pages <= 1 then
    return vb:space{width = 1} -- No pagination needed
  end
  
  return vb:row{
    vb:button{
      text = "<<",
      width = 25,
      active = current_page > 1,
      notifier = function()
        if current_page > 1 then
          current_page = 1
          selected_index = 1
          PakettiFuzzySampleSearchUpdateDisplay(true)
        end
      end
    },
    vb:button{
      text = "<",
      width = 25,
      active = current_page > 1,
      notifier = function()
        if current_page > 1 then
          current_page = current_page - 1
          selected_index = 1
          PakettiFuzzySampleSearchUpdateDisplay(true)
        end
      end
    },
    vb:text{
      id = "pagination_text",
      text = string.format("P%d/%d", current_page, max_pages),
      width = 40,
      style = "strong",
      font = "bold"
    },
    vb:button{
      text = ">",
      width = 25,
      active = current_page < max_pages,
      notifier = function()
        if current_page < max_pages then
          current_page = current_page + 1
          selected_index = 1
          PakettiFuzzySampleSearchUpdateDisplay(true)
        end
      end
    },
    vb:button{
      text = ">>",
      width = 25,
      active = current_page < max_pages,
      notifier = function()
        if current_page < max_pages then
          current_page = max_pages
          selected_index = 1
          PakettiFuzzySampleSearchUpdateDisplay(true)
        end
      end
    }
  }
end

-- Create the file display section
function PakettiFuzzySampleSearchCreateFileDisplay()
  print("DEBUG: PakettiFuzzySampleSearchCreateFileDisplay called")
  print("DEBUG: #filtered_files = " .. #filtered_files)
  print("DEBUG: results_per_page = " .. results_per_page)
  print("DEBUG: columns_count = " .. columns_count)
  print("DEBUG: max_results_per_column = " .. max_results_per_column)
  
  local file_columns = {}
  
  -- CRITICAL FIX: Always create maximum possible buttons to avoid recreation
  local max_buttons_needed = results_per_page
  local files_to_display = math.min(#filtered_files, max_buttons_needed)
  
  print("DEBUG: max_buttons_needed = " .. max_buttons_needed)
  print("DEBUG: files_to_display = " .. files_to_display)
  
  -- Create columns
  for col = 1, columns_count do
    local column_start = (col - 1) * max_results_per_column + 1
    local column_end = math.min(col * max_results_per_column, max_buttons_needed)
    
    print("DEBUG: Column " .. col .. " - start: " .. column_start .. ", end: " .. column_end)
    
    if column_start <= max_buttons_needed then
      local column_views = {}
      
      -- Create buttons for this column (up to max_buttons_needed)
      for i = column_start, column_end do
        local file = filtered_files[i]
        local is_selected = (i == selected_index)
        local button_text = ""
        
        if file then
          button_text = file.display_name
          print("DEBUG: Creating button " .. i .. " for file: " .. file.display_name)
        else
          -- Create empty button for future use
          button_text = ""
          print("DEBUG: Creating empty button " .. i .. " for future use")
        end
        
        -- Show full text when selected, truncate when not selected  
        if is_selected and file then
          -- Selected: show full filename (but cap it for the narrower buttons)
          if #button_text > 42 then
            button_text = button_text:sub(1, 39) .. "..."
          end
        elseif file then
          -- Not selected: truncate for consistent layout
          if #button_text > 38 then
            button_text = button_text:sub(1, 35) .. "..."
          end
        end
        
        local button = vb:button{
          text = button_text,
          width = 240, -- Reasonable width without waste
          height = 22,
          align = "left", -- Left-align the filename text
          font = "normal", -- Keep font consistent
          color = is_selected and selected_color or normal_color,
          visible = file ~= nil, -- Only show if we have a file
          notifier = function()
            if file then -- Only allow selection if file exists
              selected_index = i
              PakettiFuzzySampleSearchUpdateSelection()
            end
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
  
  print("DEBUG: Created " .. #file_columns .. " columns")
  print("DEBUG: Total file_buttons stored: " .. #file_buttons)
  
  return vb:horizontal_aligner{
    mode = "left",
    vb:row{
      views = file_columns
    }
  }
end

-- Create the main dialog content
function PakettiFuzzySampleSearchCreateDialog()
  print("DEBUG: PakettiFuzzySampleSearchCreateDialog called")
  print("DEBUG: #current_files = " .. #current_files)
  print("DEBUG: #filtered_files = " .. #filtered_files)
  
  -- Apply pagination to filtered_files before creating dialog
  if #filtered_files > 0 then
    local all_filtered = filtered_files -- Store all files
    local total_results = #all_filtered
    local max_pages = math.ceil(total_results / results_per_page)
    
    if current_page > max_pages then
      current_page = max_pages
    end
    if current_page < 1 then
      current_page = 1
    end
    
    local effective_results_per_page = results_per_page
    if total_results > 100000 then
      effective_results_per_page = max_safe_results_per_page
    end
    
    local start_index = ((current_page - 1) * effective_results_per_page) + 1
    local end_index = math.min(start_index + effective_results_per_page - 1, total_results)
    local page_files = {}
    for i = start_index, end_index do
      table.insert(page_files, all_filtered[i])
    end
    filtered_files = page_files
    
    print("DEBUG: Pagination applied - current_page=" .. current_page .. ", start_index=" .. start_index .. ", end_index=" .. end_index .. ", page_files_count=" .. #page_files .. ", total_results=" .. total_results)
  end
  
  -- Create a new ViewBuilder instance each time to avoid ID conflicts
  vb = renoise.ViewBuilder()
  
  -- Clear button references for fresh dialog
  file_buttons = {}
  local dialog_content = vb:column{
    
    vb:row{
      vb:text{
        id = "current_directory",
        text = current_directory ~= "" and ("Directory: " .. current_directory) or "No directory selected",
        width = 400,
        font = "bold",
        style = "strong"
      },
      vb:text{
        text = "Search:",
        width = 50,
        style = "strong",
        font = "bold"
      },
      vb:text{
        id = "search_display",
        text = search_query == "" and "(type to search)" or search_query,
        width = 200,
        style = search_query == "" and "disabled" or "normal",
        font = "mono"
      }
    },
    
    vb:row{
      vb:button{
        text = "Browse...",
        width = 70,
        notifier = PakettiFuzzySampleSearchBrowseDirectory
      },
      current_directory ~= "" and vb:button{
        text = "Scan",
        tooltip = "Scan the displayed directory",
        width = 50,
        notifier = function()
          if current_directory ~= "" then
            -- Clear existing files and update display
            current_files = {}
            filtered_files = {}
            search_query = ""
            selected_index = 1
            current_page = 1
            
            -- Update status to show scanning state
            if dialog and vb and vb.views.file_count then
              vb.views.file_count.text = "Scanning directory..."
            end
            
            -- Scan directory with callback
            PakettiFuzzySampleSearchScanDirectory(current_directory, function(files)
              current_files = files
              filtered_files = files
              search_query = ""
              selected_index = 1
              current_page = 1
              -- Set up search cache properly for loaded files
              cached_search_query = ""
              cached_search_results = files
              local total_files = #files
              local effective_page_size = (total_files > 100000) and max_safe_results_per_page or results_per_page
              local max_pages = math.ceil(total_files / effective_page_size)
              cached_pagination_info = {total_results = total_files, max_pages = max_pages}
              
              if dialog and dialog.visible then
                -- CRITICAL FIX: Use in-place updates instead of dialog recreation
                PakettiFuzzySampleSearchUpdateDisplay(true)
              end
            end)
          end
        end
      } or vb:space{width = 50},
      current_directory ~= "" and vb:button{
        text = "Clear Cache",
        tooltip = "Force rescan by clearing cached results",
        width = 70,
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
      } or vb:space{width = 70},
      vb:space{width = 1}, -- Spacer
      vb:popup{
        id = "columns_popup",
        items = {"2 Columns", "3 Columns", "4 Columns", "5 Columns", "6 Columns"},
        value = columns_count - 1, -- Convert to 1-based index (5 columns = index 4)
        width = 80,
        notifier = function(value)
          columns_count = value + 1 -- Convert back to actual column count
          
          -- CRITICAL FIX: Recreate dialog only when column count changes
          -- This is necessary because the layout structure changes
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
        items = {"15 per column", "20 per column", "25 per column", "30 per column", "35 per column", "40 per column", "45 per column", "50 per column"},
        value = PakettiFuzzySampleSearchGetCurrentPerColumnValue(), -- Set to current value
        width = 90,
        notifier = function(value)
          local items_options = {15, 20, 25, 30, 35, 40, 45, 50}
          max_results_per_column = items_options[value]
          
          -- CRITICAL FIX: Recreate dialog only when items per column changes
          -- This is necessary because the layout structure changes
          if dialog and dialog.visible then
            local was_visible = dialog.visible
            dialog:close()
            if was_visible then
              PakettiFuzzySampleSearchCreateDialog()
            end
          end
        end
      },
      PakettiFuzzySampleSearchCreatePaginationControlsCompact(),
      vb:text{
        id = "file_count", 
        text = PakettiFuzzySampleSearchGetStatusText(),
        width = 150,
        style = "strong",
        font = "bold"
      }
    },
    
    vb:text{
      text = "Use ↑↓←→ to navigate, PageUp/PageDown for pages, Enter to load, Esc to clear search/close",
      style = "disabled"
    },
    
    
    PakettiFuzzySampleSearchCreateFileDisplay(),
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

-- Navigate between pages
function PakettiFuzzySampleSearchNavigatePage(direction)
  -- Use cached pagination info
  local max_pages = cached_pagination_info.max_pages
  
  if direction == "up" and current_page > 1 then
    current_page = current_page - 1
    selected_index = 1
    PakettiFuzzySampleSearchUpdateDisplay()
  elseif direction == "down" and current_page < max_pages then
    current_page = current_page + 1
    selected_index = 1
    PakettiFuzzySampleSearchUpdateDisplay()
  end
end

-- Navigate selection up/down
function PakettiFuzzySampleSearchNavigate(direction)
  if #filtered_files == 0 then return end
  
  local old_index = selected_index
  local max_pages = cached_pagination_info.max_pages
  local current_page_size = #filtered_files -- Current page has this many files
  
  print("DEBUG: Navigation start - current_page=" .. current_page .. ", selected_index=" .. selected_index .. ", page_size=" .. current_page_size)
  
  if direction == "up" then
    selected_index = selected_index - 1
    if selected_index < 1 then
      -- Go to previous page if available
      if current_page > 1 then
        current_page = current_page - 1
        selected_index = current_page_size -- Last item of previous page
        print("DEBUG: Up navigation - went to previous page " .. current_page .. ", index " .. selected_index)
        PakettiFuzzySampleSearchUpdateDisplay(true)
        return
      else
        selected_index = current_page_size -- Wrap to last item of current page
        print("DEBUG: Up navigation - wrapped to end of current page, index " .. selected_index)
      end
    else
      print("DEBUG: Up navigation - moved to index " .. selected_index)
    end
  elseif direction == "down" then
    selected_index = selected_index + 1
    if selected_index > current_page_size then
      -- Go to next page if available
      if current_page < max_pages then
        current_page = current_page + 1
        selected_index = 1 -- First item of next page
        print("DEBUG: Down navigation - went to next page " .. current_page .. ", index " .. selected_index)
        PakettiFuzzySampleSearchUpdateDisplay(true)
        return
      else
        selected_index = 1 -- Wrap to first item of current page
        print("DEBUG: Down navigation - wrapped to beginning of current page, index " .. selected_index)
      end
    else
      print("DEBUG: Down navigation - moved to index " .. selected_index)
    end
  elseif direction == "left" then
    -- Move to previous column (subtract max_results_per_column)
    selected_index = selected_index - max_results_per_column
    if selected_index < 1 then
      -- Go to previous page if available
      if current_page > 1 then
        current_page = current_page - 1
        selected_index = current_page_size -- Last item of previous page
        print("DEBUG: Left navigation - went to previous page " .. current_page .. ", index " .. selected_index)
        PakettiFuzzySampleSearchUpdateDisplay(true)
        return
      else
        -- Wrap to end of current page
        selected_index = current_page_size
        print("DEBUG: Left navigation - wrapped to end of current page, index " .. selected_index)
      end
    else
      print("DEBUG: Left navigation - moved to index " .. selected_index)
    end
  elseif direction == "right" then
    -- Move to next column (add max_results_per_column)
    selected_index = selected_index + max_results_per_column
    if selected_index > current_page_size then
      -- Go to next page if available
      if current_page < max_pages then
        current_page = current_page + 1
        selected_index = 1 -- First item of next page
        print("DEBUG: Right navigation - went to next page " .. current_page .. ", index " .. selected_index)
        PakettiFuzzySampleSearchUpdateDisplay(true)
        return
      else
        -- Wrap to beginning of current page
        selected_index = 1
        print("DEBUG: Right navigation - wrapped to beginning of current page, index " .. selected_index)
      end
    else
      print("DEBUG: Right navigation - moved to index " .. selected_index)
    end
  end
  
  if old_index ~= selected_index then
    -- Just update the button colors without recreating the dialog
    PakettiFuzzySampleSearchUpdateSelection()
  end
end

-- Fast selection update without dialog recreation
function PakettiFuzzySampleSearchUpdateSelection()
  -- Update button colors efficiently like PakettiGater does
  for i, button in pairs(file_buttons) do
    if button and button.color then
      if i == selected_index then
        button.color = selected_color -- Deep purple for selected
      else
        button.color = normal_color -- Default black for unselected
      end
    end
  end
  
  -- Also show selection in status bar
  if #filtered_files > 0 and selected_index >= 1 and selected_index <= #filtered_files then
    local selected_file = filtered_files[selected_index]
    renoise.app():show_status(string.format("Selected: %s (%d/%d)", selected_file.display_name, selected_index, #filtered_files))
  end
end

-- Handle search input with optimization
function PakettiFuzzySampleSearchUpdateSearch(new_query)
  local query_changed = (search_query ~= new_query)
  search_query = new_query
  
  -- Always update display when query changes, or when forced (like backspace)
  current_page = 1 -- Reset to first page when searching
  selected_index = 1
  -- Force recalculation since query changed
  PakettiFuzzySampleSearchUpdateDisplay(true)
end

-- Optimization: Check if dialog can be updated in-place
function PakettiFuzzySampleSearchCanUpdateInPlace()
  -- Can update in-place if same number of buttons would be needed
  local current_button_count = #file_buttons
  local new_button_count = math.min(#filtered_files, results_per_page)
  return current_button_count == new_button_count and dialog and dialog.visible
end

-- Optimization: Update button text/colors without recreating dialog
function PakettiFuzzySampleSearchUpdateButtonsInPlace()
  -- CRITICAL FIX: Ensure we have enough buttons for the current page
  local needed_buttons = #filtered_files
  local current_buttons = #file_buttons
  
  -- If we don't have enough buttons, we need to recreate the dialog
  -- This should only happen once when the dialog is first created
  if needed_buttons > current_buttons then
    print("DEBUG: Not enough buttons (" .. current_buttons .. ") for files (" .. needed_buttons .. "), recreating dialog")
    local was_visible = dialog.visible
    dialog:close()
    if was_visible then
      PakettiFuzzySampleSearchCreateDialog()
    end
    return
  end
  
  -- Update existing buttons
  for i = 1, needed_buttons do
    local button = file_buttons[i]
    if button then
      local file = filtered_files[i]
      local is_selected = (i == selected_index)
      
      -- Show the button
      button.visible = true
      
      -- Update button text - show full text when selected
      local button_text = file.display_name
      if is_selected then
        -- Selected: show full filename (but cap it for the narrower buttons)
        if #button_text > 42 then
          button_text = button_text:sub(1, 39) .. "..."
        end
      else
        -- Not selected: truncate for consistent layout
        if #button_text > 38 then
          button_text = button_text:sub(1, 35) .. "..."
        end
      end
      button.text = button_text
      
      -- Update button appearance
      button.font = "normal" -- Keep font consistent
      button.color = is_selected and selected_color or normal_color
    end
  end
  
  -- Hide any extra buttons that aren't needed
  for i = needed_buttons + 1, current_buttons do
    local button = file_buttons[i]
    if button then
      button.visible = false
    end
  end
end

-- Optimization: Update status text without dialog recreation
function PakettiFuzzySampleSearchUpdateStatusInPlace()
  if dialog and vb and vb.views.file_count then
    local status_text = PakettiFuzzySampleSearchGetStatusText()
    vb.views.file_count.text = status_text
    
    -- ALWAYS apply bold styling to status text
    vb.views.file_count.style = "strong"
    vb.views.file_count.font = "bold"
  end
  if dialog and vb and vb.views.search_display then
    vb.views.search_display.text = search_query == "" and "(type to search)" or search_query
    vb.views.search_display.style = search_query == "" and "disabled" or "normal"
  end
  if dialog and vb and vb.views.pagination_text then
    local max_pages = cached_pagination_info.max_pages
    vb.views.pagination_text.text = string.format("P%d/%d", current_page, max_pages)
  end
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
    current_page = 1
    
    -- Update status to show scanning state
    if dialog and vb and vb.views.file_count then
      vb.views.file_count.text = "Scanning directory..."
    end
    if dialog and vb and vb.views.current_directory then
      vb.views.current_directory.text = "Directory: " .. current_directory
    end
    
    -- Scan new directory with callback
    PakettiFuzzySampleSearchScanDirectory(current_directory, function(files)
      current_files = files
      filtered_files = files
      search_query = ""
      selected_index = 1
      current_page = 1
      -- Set up search cache properly for loaded files
      cached_search_query = ""
      cached_search_results = files
      local total_files = #files
      local effective_page_size = (total_files > 100000) and max_safe_results_per_page or results_per_page
      local max_pages = math.ceil(total_files / effective_page_size)
      cached_pagination_info = {total_results = total_files, max_pages = max_pages}
      
      if dialog and dialog.visible then
        -- CRITICAL FIX: Use in-place updates instead of dialog recreation
        PakettiFuzzySampleSearchUpdateDisplay(true)
      end
    end)
  end
end

-- Key handler for the dialog
function PakettiFuzzySampleSearchKeyHandler(dialog_ref, key)
  if not dialog_ref or not dialog_ref.visible then
    return key
  end
  
  -- DEBUG: Print all key presses to see what's actually being registered
  print("KEY PRESSED: name='" .. tostring(key.name) .. "' modifiers='" .. tostring(key.modifiers) .. "' character='" .. tostring(key.character or "nil") .. "'")
  
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
    elseif key.name == "pageup" then
      print("DEBUG: PageUp detected!")
      PakettiFuzzySampleSearchNavigatePage("up")
      return nil
    elseif key.name == "pagedown" then
      print("DEBUG: PageDown detected!")
      PakettiFuzzySampleSearchNavigatePage("down")
      return nil
    elseif key.name == "return" then
      PakettiFuzzySampleSearchLoadSelected()
      -- Don't close dialog, just load sample
      return nil
    elseif key.name == "esc" then
      print("DEBUG: ESC detected! search_query='" .. search_query .. "' length=" .. #search_query)
      if search_query ~= "" then
        print("DEBUG: Clearing search query")
        PakettiFuzzySampleSearchUpdateSearch("")
        return nil
      else
        print("DEBUG: Search query is empty, starting browse process")
        PakettiFuzzySampleSearchBrowseDirectory()
        return nil
      end
    elseif key.name == "backspace" or key.name == "delete" or key.name == "back" then
      print("DEBUG: Backspace detected! search_query='" .. search_query .. "' length=" .. #search_query)
      if #search_query > 0 then
        -- Remove last character and force update
        local new_query = search_query:sub(1, -2)
        print("DEBUG: Removing character, new query='" .. new_query .. "'")
        PakettiFuzzySampleSearchUpdateSearch(new_query)
        return nil
      else
        print("DEBUG: Search query empty, refreshing display")
        -- Even if query is empty, refresh display (fixes display issues)
        PakettiFuzzySampleSearchUpdateDisplay(true)
        return nil
      end
    elseif key.name == "space" then
      print("DEBUG: Space detected, adding to query")
      PakettiFuzzySampleSearchUpdateSearch(search_query .. " ")
      return nil
    elseif #key.name == 1 then  -- Single character
      print("DEBUG: Single char detected: '" .. key.name .. "' adding to query")
      PakettiFuzzySampleSearchUpdateSearch(search_query .. key.name)
      return nil
    else
      print("DEBUG: Unhandled key: name='" .. key.name .. "' length=" .. #key.name)
    end
  elseif key.modifiers == "command" then
    -- Handle Cmd+key combinations for macOS
    if key.name == "up" then
      print("DEBUG: Cmd+Up detected! (Page Up)")
      PakettiFuzzySampleSearchNavigatePage("up")
      return nil
    elseif key.name == "down" then
      print("DEBUG: Cmd+Down detected! (Page Down)")
      PakettiFuzzySampleSearchNavigatePage("down")
      return nil
    else
      print("DEBUG: Unhandled Cmd+key: name='" .. key.name .. "'")
    end
  else
    print("DEBUG: Key with modifiers - name='" .. key.name .. "' modifiers='" .. key.modifiers .. "'")
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
  
  -- Check if directory exists and is accessible
  local function directory_exists(path)
    if path == "" then return false end
    local success, result = pcall(function()
      local handle = io.popen('test -d "' .. path .. '" && echo "exists" 2>/dev/null')
      if handle then
        local output = handle:read("*l")
        handle:close()
        return output == "exists"
      end
      return false
    end)
    return success and result or false
  end
  
  -- If no directory is set or directory doesn't exist, immediately prompt for one
  if last_directory == "" or not directory_exists(last_directory) then
    if last_directory ~= "" then
      renoise.app():show_status("Previous directory no longer exists: " .. last_directory)
    end
    local new_directory = renoise.app():prompt_for_path("Select Sample Directory")
    if not new_directory or new_directory == "" then
      renoise.app():show_status("No directory selected - Sample Search cancelled")
      return
    end
    -- Set the new directory and save it
    current_directory = new_directory
    PakettiFuzzySampleSearchSaveLastDirectory(current_directory)
    renoise.app():show_status("Directory selected: " .. current_directory)
  else
    current_directory = last_directory
  end
  
  -- Always reset files if we have a directory (either new or existing)
  if current_directory ~= "" then
    current_files = {}
    filtered_files = {}
    search_query = ""
    selected_index = 1
    current_page = 1
    
    -- Try to load from cache if directory is set
    print("DEBUG: Checking cache for directory: " .. current_directory)
    local cache_valid = PakettiFuzzySampleSearchIsCacheValid(current_directory)
    print("DEBUG: Cache valid: " .. tostring(cache_valid))
    
    if current_directory ~= "" and cache_valid then
      local cache_data = PakettiFuzzySampleSearchLoadCache(current_directory)
      if cache_data and cache_data.files then
        print("DEBUG: Loading " .. #cache_data.files .. " files from cache")
        current_files = cache_data.files
        filtered_files = cache_data.files
        -- Set up search cache properly for loaded files
        cached_search_query = ""
        cached_search_results = cache_data.files
        local total_files = #cache_data.files
        local effective_page_size = (total_files > 100000) and max_safe_results_per_page or results_per_page
        local max_pages = math.ceil(total_files / effective_page_size)
        cached_pagination_info = {total_results = total_files, max_pages = max_pages}
        renoise.app():show_status("Loaded " .. #current_files .. " files from cache")
      else
        print("DEBUG: Cache data is nil or has no files")
        -- No cache available, set scanning state and auto-scan after dialog creation
        renoise.app():show_status("Will scan directory: " .. current_directory)
        -- Mark that we need to auto-scan after dialog creation
        local needs_auto_scan = true
      end
    else
      print("DEBUG: No cache available, will auto-scan")
      -- No cache available, set scanning state and auto-scan after dialog creation
      renoise.app():show_status("Will scan directory: " .. current_directory)
      -- Mark that we need to auto-scan after dialog creation
      local needs_auto_scan = true
    end
  end
  
  -- Always reset selection to start
  selected_index = 1
  current_page = 1
  
  -- Create the dialog
  PakettiFuzzySampleSearchCreateDialog()
  
  if current_directory ~= "" then
    if #current_files > 0 then
      renoise.app():show_status("Sample Search opened - " .. #current_files .. " files ready from: " .. current_directory)
      -- CRITICAL FIX: Use in-place updates instead of dialog recreation
      PakettiFuzzySampleSearchUpdateDisplay(true)
    else
      -- No files loaded, auto-scan the directory
      print("DEBUG: Starting auto-scan for directory: " .. current_directory)
      renoise.app():show_status("Scanning directory: " .. current_directory)
      PakettiFuzzySampleSearchScanDirectory(current_directory, function(files)
        print("DEBUG: Auto-scan completed, found " .. #files .. " files")
        current_files = files
        filtered_files = files
        search_query = ""
        selected_index = 1
        current_page = 1
        -- Set up search cache properly for loaded files
        cached_search_query = ""
        cached_search_results = files
        local total_files = #files
        local effective_page_size = (total_files > 100000) and max_safe_results_per_page or results_per_page
        local max_pages = math.ceil(total_files / effective_page_size)
        cached_pagination_info = {total_results = total_files, max_pages = max_pages}
        
        if dialog and dialog.visible then
          print("DEBUG: Dialog is visible, using in-place updates with " .. #files .. " files")
          -- CRITICAL FIX: Use in-place updates instead of dialog recreation
          PakettiFuzzySampleSearchUpdateDisplay(true)
        else
          print("DEBUG: Dialog is not visible, cannot update display")
        end
      end)
    end
  else
    renoise.app():show_status("Sample Search opened - Click Browse to select a directory")
  end
end

-- Wrapper function for keybinding
function PakettiFuzzySampleSearchKeybindingWrapper()
  -- If dialog is open, don't do anything (ESC will handle search clearing or browse)
  if dialog and dialog.visible then
    return
  end
  
  -- Otherwise, open the dialog
  PakettiFuzzySampleSearchDialog()
end

-- Add keybinding
renoise.tool():add_keybinding{
  name = "Global:Paketti:Fuzzy Sample Search Dialog...",
  invoke = PakettiFuzzySampleSearchKeybindingWrapper
}

-- Add menu entries
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti Gadgets:Fuzzy Sample Search Dialog...",
  invoke = PakettiFuzzySampleSearchDialog
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti Fuzzy Sample Search...",
  invoke = PakettiFuzzySampleSearchDialog
}
