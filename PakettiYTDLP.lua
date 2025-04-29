local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix

-- TODO YT-DLP make it output to GUI Console
-- TODO YT-DLP make sure it finishes downloading


local yt_dlp_path = "/opt/homebrew/bin/yt-dlp"
local ffmpeg_path = ""
local RUNTIME = tostring(os.time())
local SAMPLE_LENGTH = 10
local dialog = nil
local dialog_content = nil
local loop_modes = {"Off", "Forward", "Backward", "PingPong"}
local vb = nil        -- ViewBuilder instance
local logview = nil   
local process_running = false
local process_handle = nil
local process_timer = nil
local cancel_button = nil
local status_text = nil
local process_slicer = nil
local completion_timer_func = nil

-- Function to detect the operating system and assign paths
function PakettiYTDLPSetExecutablePaths()
  -- First check if path is already set in preferences
  yt_dlp_path = preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value

  -- If not set in preferences, try to find it automatically
  if yt_dlp_path == nil or yt_dlp_path == "" then
    local os_name = os.platform()
    
    if os_name == "MACINTOSH" then
      -- Check Homebrew path on Mac
      yt_dlp_path = "/opt/homebrew/bin/yt-dlp"
      PakettiYTDLPLogMessage("Detected macOS. Trying Homebrew yt-dlp path.")
    
    elseif os_name == "LINUX" then
      -- Try multiple common Linux paths in order
      local linux_paths = {
        "/home/linuxbrew/.linuxbrew/bin/yt-dlp",  -- Linux Homebrew path
        "/usr/local/bin/yt-dlp",                  -- Common local installation
        "/usr/bin/yt-dlp",                        -- System-wide installation
        "/snap/bin/yt-dlp"                        -- Snap installation
      }
      
      for _, path in ipairs(linux_paths) do
        local file = io.open(path, "r")
        if file then
          file:close()
          yt_dlp_path = path
          PakettiYTDLPLogMessage("Found yt-dlp at: " .. path)
          break
        end
      end
      
      if not yt_dlp_path or yt_dlp_path == "" then
        PakettiYTDLPLogMessage("Could not find yt-dlp in common Linux paths.")
      end
    
    elseif os_name == "WINDOWS" then
      renoise.app():show_status("Windows is currently not supported.")
      PakettiYTDLPLogMessage("Windows detected. Exiting as it's not supported.")
      error("Windows is currently not supported.")
    else
      renoise.app():show_status("Unsupported OS detected.")
      PakettiYTDLPLogMessage("Unsupported OS detected. Exiting.")
      error("Unsupported OS detected.")
    end
  end

  -- If we still don't have a path, we need to ask the user
  if not yt_dlp_path or yt_dlp_path == "" then
    PakettiYTDLPLogMessage("yt-dlp path not found automatically. Please set it manually.")
    return
  end

  PakettiYTDLPLogMessage("Using yt-dlp path: " .. yt_dlp_path)

  -- Set ffmpeg_path based on OS
  local os_name = os.platform()
  if os_name == "MACINTOSH" then
    ffmpeg_path = "/opt/homebrew/bin/ffmpeg"
    PakettiYTDLPLogMessage("Detected macOS. Setting ffmpeg path accordingly.")
  elseif os_name == "LINUX" then
    -- Try multiple ffmpeg paths on Linux
    local linux_ffmpeg_paths = {
      "/home/linuxbrew/.linuxbrew/bin/ffmpeg",  -- Linux Homebrew
      "/usr/bin/ffmpeg",                        -- System installation
      "/usr/local/bin/ffmpeg"                   -- Local installation
    }
    
    for _, path in ipairs(linux_ffmpeg_paths) do
      local file = io.open(path, "r")
      if file then
        file:close()
        ffmpeg_path = path
        PakettiYTDLPLogMessage("Found ffmpeg at: " .. path)
        break
      end
    end
    
    if not ffmpeg_path or ffmpeg_path == "" then
      ffmpeg_path = "/usr/bin/ffmpeg"  -- Default fallback
      PakettiYTDLPLogMessage("Defaulting to standard ffmpeg path")
    end
  end
end


-- Function to log messages to the multiline textfield
function PakettiYTDLPLogMessage(message)
  if not logview then return end
  
  -- Only log certain types of messages
  if message:match("^%[") or           -- yt-dlp progress
     message:match("^ERROR:") or       -- errors
     message:match("^WARNING:") or     -- warnings
     message:match("^No videos found") or
     message:match("^Found video") then
    -- Just append the text
    logview.text = logview.text .. message .. "\n"
  end
end

-- Function to move files (fallback if os.rename is not available)
function PakettiYTDLPMove(src, dest)
  local success, err = os.rename(src, dest)
  if success then
    return true
  else
    -- Attempt to copy and delete if os.rename fails (e.g., across different filesystems)
    local src_file = io.open(src, "rb")
    if not src_file then
      return false, "Failed to open source file: " .. src
    end
    local data = src_file:read("*a")
    src_file:close()

    local dest_file = io.open(dest, "wb")
    if not dest_file then
      return false, "Failed to open destination file: " .. dest
    end
    dest_file:write(data)
    dest_file:close()

    local remove_success = os.remove(src)
    if not remove_success then
      return false, "Failed to remove source file after copying: " .. src
    end
    return true
  end
end

-- Function to check if a file exists
function PakettiYTDLPFileExists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  else
    return false
  end
end

-- Function to check if a directory exists
function PakettiYTDLPDirectoryExists(path)
  -- Use 'os.rename' as a way to check existence
  local ok, err = os.rename(path, path)
  if not ok then
    return false
  end
  -- Additional check to ensure it's a directory
  -- Attempt to list its contents
  local handle = io.popen('test -d "' .. path .. '" && echo "yes" || echo "no"')
  if not handle then
    return false
  end
  local result = handle:read("*a")
  handle:close()
  result = result:gsub("%s+", "")
  return result == "yes"
end

-- Function to create a directory if it doesn't exist
function PakettiYTDLPCreateDir(path)
  if not PakettiYTDLPDirectoryExists(path) then
    local success, err = os.execute('mkdir -p "' .. path .. '"')
    if not success then
      PakettiYTDLPLogMessage("Failed to create directory '" .. path .. "': " .. tostring(err))
      error("Failed to create directory '" .. path .. "': " .. tostring(err))
    end
    PakettiYTDLPLogMessage("Created directory: " .. path)
  else
    PakettiYTDLPLogMessage("Directory already exists: " .. path)
  end
end

-- Function to list files in a directory
function PakettiYTDLPListDir(dir)
  local files = {}
  local handle = io.popen('ls "' .. dir .. '"')
  if handle then
    for file in handle:lines() do
      local filepath = dir .. separator .. file
      if not filepath:match("^%.") then  -- Skip hidden files
        table.insert(files, file)
      end
    end
    handle:close()
  end
  return files
end

-- Function to safely remove files with a specific extension
function PakettiYTDLPRemoveFilesWithExtension(dir, extension)
  local files = PakettiYTDLPListDir(dir)
  for _, file in ipairs(files) do
    if file:sub(-#extension) == extension then
      local filepath = dir .. "/" .. file
      local success, err = os.remove(filepath)
      if success then
        PakettiYTDLPLogMessage("Removed file: " .. filepath)
      else
        PakettiYTDLPLogMessage("Failed to remove file: " .. filepath .. " Error: " .. tostring(err))
      end
    end
  end
end

-- Function to clear a file's contents
function PakettiYTDLPClearFile(filepath)
  local file, err = io.open(filepath, "w")
  if not file then
    PakettiYTDLPLogMessage("Failed to open file '" .. filepath .. "' for writing: " .. tostring(err))
    error("Failed to open file '" .. filepath .. "' for writing: " .. tostring(err))
  end
  file:close()
  PakettiYTDLPLogMessage("Cleared file: " .. filepath)
end

-- Function to handle process output in slices
function PakettiYTDLPProcessSlice()
  if not process_handle then return end
  
  local output = process_handle:read("*l")
  if output then
    -- Update status text based on output
    if status_text then
      if output:match("^%[download%]%s+([%d%.]+)%%%s+") then
        status_text.text = "Downloading: " .. output:match("^%[download%]%s+([%d%.]+)%%%s+") .. "%"
      elseif output:match("^%[ExtractAudio%]") then
        status_text.text = "Extracting Audio..."
      end
    end
    
    -- Log all relevant output
    PakettiYTDLPLogMessage(output)
  else
    -- Process finished
    process_handle:close()
    process_handle = nil
    if process_timer then
      process_timer:stop()
      process_timer = nil
    end
    process_running = false
    if status_text then
      status_text.text = "Ready"
    end
    if cancel_button then
      cancel_button.active = false
    end
  end
end

-- Modified execute command function to use process slicing
function PakettiYTDLPExecuteCommand(command)
  if process_running then
    PakettiYTDLPLogMessage("Another process is already running")
    return false
  end
  
  process_handle = io.popen(command .. " 2>&1", "r")
  if not process_handle then
    PakettiYTDLPLogMessage("Failed to start process")
    if status_text then
      status_text.text = "Failed to start process"
    end
    return false
  end
  
  process_running = true
  if status_text then
    status_text.text = "Processing..."
  end
  if cancel_button then
    cancel_button.active = true
  end
  process_timer = renoise.tool():add_timer(PakettiYTDLPProcessSlice, 50) -- Check every 50ms
  return true
end

-- Function to sanitize filenames: allow only A-Z, a-z, 0-9, hyphens, and underscores, preserve extension
function PakettiYTDLPSanitizeFilename(filename)
  local base, ext = filename:match("^(.*)%.([^%.]+)$")
  if base and ext then
    local sanitized_base = base:gsub("[^%w%-%_]", "")
    return sanitized_base .. "." .. ext
  else
    -- No extension found, sanitize entire filename
    return filename:gsub("[^%w%-%_]", "")
  end
end

-- Function to get a random URL from yt-dlp search
function PakettiYTDLPGetRandomUrl(search_phrase, search_results_file)
  PakettiYTDLPLogMessage("Searching for term \"" .. search_phrase .. "\"")
  
  local command = string.format('env PATH=/opt/homebrew/bin:$PATH "%s" "ytsearch30:%s" --get-id --no-warnings', yt_dlp_path, search_phrase)
  local handle = io.popen(command)
  if not handle then
    PakettiYTDLPLogMessage("Failed to start search")
    return nil
  end
  
  -- Read results
  local urls = {}
  for line in handle:lines() do
    if line and line ~= "" then
      table.insert(urls, "https://www.youtube.com/watch?v=" .. line)
      PakettiYTDLPLogMessage("Found video: " .. line)
    end
  end
  handle:close()
  
  if #urls == 0 then
    PakettiYTDLPLogMessage("No videos found")
    return nil
  end
  
  -- Select random URL
  math.randomseed(os.time())
  local random_index = math.random(1, #urls)
  return urls[random_index]
end

-- Modified download video function
function PakettiYTDLPDownloadVideo(youtube_url, full_video, clip_length, temp_dir)
  local command
  if full_video then
    command = string.format(
      'env PATH=/opt/homebrew/bin:$PATH "%s" --restrict-filenames -f ba --extract-audio --audio-format wav -o "%s%stempfolder%s%%(title)s-%%(id)s.%%(ext)s" "%s"',
      yt_dlp_path,
      temp_dir,
      separator,
      separator,
      youtube_url
    )
  else
    command = string.format(
      'env PATH=/opt/homebrew/bin:$PATH "%s" --restrict-filenames --download-sections "*0-%d" -f ba --extract-audio --audio-format wav -o "%s%stempfolder%s%%(title)s-%%(id)s.%%(ext)s" "%s"',
      yt_dlp_path,
      clip_length,
      temp_dir,
      separator,
      separator,
      youtube_url
    )
  end
  
  -- Execute with process slicing
  if not PakettiYTDLPExecuteCommand(command) then
    return false
  end
  
  -- Wait for process to finish
  while process_running do
    os.execute("sleep 0.1")
  end
  
  return true
end

-- Function to sanitize filenames in temp_dir and record them
function PakettiYTDLPSanitizeFilenames(temp_dir, filenames_file)
  local files = PakettiYTDLPListDir(temp_dir)
  for _, file in ipairs(files) do
    if file:sub(-4) == ".wav" then
      local sanitized = PakettiYTDLPSanitizeFilename(file)
      if file ~= sanitized then
        local old_path = temp_dir .. separator .. file
        local new_path = temp_dir .. separator .. sanitized
        local success, err = PakettiYTDLPMove(old_path, new_path)
        if success then
          PakettiYTDLPLogMessage("Renamed '" .. file .. "' to '" .. sanitized .. "'")
        else
          PakettiYTDLPLogMessage("Failed to rename '" .. file .. "': " .. tostring(err))
        end
      end
      -- Append sanitized filename to filenames_file
      local file_handle, err = io.open(filenames_file, "a")
      if file_handle then
        file_handle:write(sanitized .. "\n")
        file_handle:close()
        PakettiYTDLPLogMessage("Recorded filename: " .. sanitized)
      else
        PakettiYTDLPLogMessage("Failed to open filenames file: " .. tostring(err))
      end
    end
  end
end

-- Function to signal completion by creating a file
function PakettiYTDLPSignalCompletion(completion_signal_file)
  local file, err = io.open(completion_signal_file, "w")
  if not file then
    PakettiYTDLPLogMessage("Failed to create completion signal file: " .. tostring(err))
    error("Failed to create completion signal file: " .. tostring(err))
  end
  file:close()
  PakettiYTDLPLogMessage("Created completion signal file: " .. completion_signal_file)
end

function PakettiYTDLPExecuteLua(search_phrase, youtube_url, download_dir, clip_length, full_video)
  -- Set executable paths based on OS
  PakettiYTDLPSetExecutablePaths()

  -- Define paths
  -- Ensure no trailing slash on download_dir
  if download_dir:sub(-1) == separator then
    download_dir = download_dir:sub(1, -2)
  end
  local temp_dir = download_dir .. separator .. "tempfolder"
  local completion_signal_file = temp_dir .. separator .. "download_completed.txt"
  local filenames_file = temp_dir .. separator .. "filenames.txt"
  local search_results_file = temp_dir .. separator .. "search_results.txt"

  -- Log starting arguments
  PakettiYTDLPLogMessage("Starting Paketti YT-DLP with arguments:")
  PakettiYTDLPLogMessage("SEARCH_PHRASE: " .. tostring(search_phrase))
  PakettiYTDLPLogMessage("YOUTUBE_URL: " .. tostring(youtube_url))
  PakettiYTDLPLogMessage("DOWNLOAD_DIR: " .. tostring(download_dir))
  PakettiYTDLPLogMessage("CLIP_LENGTH: " .. tostring(clip_length))
  PakettiYTDLPLogMessage("FULL_VIDEO: " .. tostring(full_video))

  -- Create necessary directories
  PakettiYTDLPCreateDir(download_dir)
  PakettiYTDLPCreateDir(temp_dir)

  -- Clean up temp_dir
  PakettiYTDLPRemoveFilesWithExtension(temp_dir, ".wav")
  -- Remove completion signal file if it exists
  if PakettiYTDLPFileExists(completion_signal_file) then
    local success_remove, err_remove = os.remove(completion_signal_file)
    if success_remove then
      PakettiYTDLPLogMessage("Removed completion signal file if it existed: " .. completion_signal_file)
    else
      PakettiYTDLPLogMessage("Failed to remove completion signal file: " .. completion_signal_file .. " Error: " .. tostring(err_remove))
    end
  else
    PakettiYTDLPLogMessage("No existing completion signal file to remove: " .. completion_signal_file)
  end
  PakettiYTDLPClearFile(filenames_file)
  PakettiYTDLPClearFile(search_results_file)

  -- Determine which URL to download
  local selected_url = youtube_url
  if not selected_url or selected_url == "" then
    selected_url = PakettiYTDLPGetRandomUrl(search_phrase, search_results_file)
  end

  if not selected_url then
    PakettiYTDLPLogMessage("No URL selected for download. Exiting.")
    return
  end

  PakettiYTDLPLogMessage(string.format("Starting download for URL: %s.", selected_url))

  -- Download video or clip
  PakettiYTDLPDownloadVideo(selected_url, full_video, clip_length, temp_dir)

  -- Sanitize filenames and record them
  PakettiYTDLPSanitizeFilenames(temp_dir, filenames_file)

  -- Signal completion
  PakettiYTDLPSignalCompletion(completion_signal_file)

  PakettiYTDLPLogMessage("Paketti YT-DLP finished.")
end

-- Function to load downloaded samples into Renoise
function PakettiYTDLPLoadVideoAudioIntoRenoise(download_dir, loop_mode, create_new_instrument)
  local temp_dir = download_dir .. separator .. "tempfolder"
  local completion_signal_file = temp_dir .. separator .. "download_completed.txt"
  local filenames_file = temp_dir .. separator .. "filenames.txt"

  PakettiYTDLPLogMessage("=== Starting Renoise import process ===")
  PakettiYTDLPLogMessage("Checking completion signal file: " .. completion_signal_file)

  -- Wait until the completion signal file is created
  while not PakettiYTDLPFileExists(completion_signal_file) do
    PakettiYTDLPLogMessage("Waiting for completion signal file...")
    os.execute('sleep 1')
  end
  PakettiYTDLPLogMessage("Completion signal file detected")

  -- List all WAV files in temp directory
  local files = PakettiYTDLPListDir(temp_dir)
  local sample_files = {}
  for _, file in ipairs(files) do
    if file:match("%.wav$") then
      table.insert(sample_files, temp_dir .. separator .. file)
      PakettiYTDLPLogMessage("Found WAV file: " .. file)
    end
  end

  if #sample_files == 0 then
    PakettiYTDLPLogMessage("ERROR: No WAV files found in " .. temp_dir)
    return
  end

  PakettiYTDLPLogMessage("Found " .. #sample_files .. " WAV file(s) to import")

  -- Ensure files are fully available
  for _, file in ipairs(sample_files) do
    PakettiYTDLPLogMessage("Checking file availability: " .. file)
    local file_size = -1
    while true do
      local f = io.open(file, "rb")
      if f then
        local current_file_size = f:seek("end")
        f:close()
        if current_file_size == file_size then
          break
        end
        file_size = current_file_size
      end
      os.execute('sleep 1')
    end
    PakettiYTDLPLogMessage("File is ready: " .. file)
  end

  local song = renoise.song()
  local selected_instrument_index = song.selected_instrument_index

  if create_new_instrument then
    selected_instrument_index = selected_instrument_index + 1
    song:insert_instrument_at(selected_instrument_index)
    song.selected_instrument_index = selected_instrument_index
    pakettiPreferencesDefaultInstrumentLoader()
    PakettiYTDLPLogMessage("Created new instrument at index: " .. selected_instrument_index)
  end

  local instrument = song.instruments[selected_instrument_index]
  if not instrument then
    PakettiYTDLPLogMessage("ERROR: Failed to get instrument at index: " .. selected_instrument_index)
    return
  end

  for _, file in ipairs(sample_files) do
    PakettiYTDLPLogMessage("Loading sample into Renoise: " .. file)
    local sample = instrument:insert_sample_at(1)
    if sample then
      local buffer = sample.sample_buffer
      if buffer then
        -- Load the sample
        if buffer:load_from(file) then
          -- Wait for sample to be fully loaded
          buffer:prepare_sample_data_changes()
          buffer:finalize_sample_data_changes()

          -- Set names and properties
          local filename = file:match("[^" .. separator .. "]+$")
          sample.name = filename
          instrument.name = filename
          sample.loop_mode = loop_mode

          PakettiYTDLPLogMessage("Successfully loaded sample: " .. filename)

          -- Remove placeholder sample if it exists
          local num_samples = #instrument.samples
          if num_samples > 0 and instrument.samples[num_samples].name == "Placeholder sample" then
            instrument:delete_sample_at(num_samples)
            PakettiYTDLPLogMessage("Removed placeholder sample from last slot")
          end
        else
          PakettiYTDLPLogMessage("ERROR: Failed to load sample from file")
        end
      else
        PakettiYTDLPLogMessage("ERROR: Failed to get sample buffer")
      end
    else
      PakettiYTDLPLogMessage("ERROR: Failed to insert sample")
    end
  end

  -- Move files to final destination
  for _, file in ipairs(sample_files) do
    local dest_file = download_dir .. separator .. file:match("[^" .. separator .. "]+$")
    local success_move, err_move = PakettiYTDLPMove(file, dest_file)
    if success_move then
      PakettiYTDLPLogMessage("Moved file to final location: " .. dest_file)
    else
      PakettiYTDLPLogMessage("ERROR: Failed to move file: " .. tostring(err_move))
    end
  end

  -- Switch to sample editor view
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  PakettiYTDLPLogMessage("=== Sample import complete ===")
end

-- Function to prompt for output directory
function PakettiYTDLPPromptForOutputDir()
  renoise.app():show_warning("Please set the folder that YT-DLP will download to...")
  local dir = renoise.app():prompt_for_path("Select Output Directory")
  if dir then
    vb.views.output_dir.text = dir
    preferences.PakettiYTDLP.PakettiYTDLPOutputDirectory.value = dir
    PakettiYTDLPLogMessage("Saved Output Directory to " .. dir)
  end
end

-- Function to prompt for save path
function PakettiYTDLPPromptForSavePath()
  renoise.app():show_warning("Please set the folder to save WAV or FLAC to...")
  local dir = renoise.app():prompt_for_path("Select Save Path")
  if dir then
    vb.views.save_path.text = dir
    preferences.PakettiYTDLP.PakettiYTDLPPathToSave.value = dir
    PakettiYTDLPLogMessage("Saved Save Path to " .. dir)
  end
end

-- Function to prompt for yt-dlp path
function PakettiYTDLPPromptForYTDLPPath()
  renoise.app():show_warning("Please select the YT-DLP executable")
  local file = renoise.app():prompt_for_filename_to_read({"*.*"}, "Select YT-DLP Executable")
  if file then
    vb.views.yt_dlp_location.text = file
    preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = file
    PakettiYTDLPLogMessage("Saved yt-dlp location to " .. file)
  end
end

-- Function to print saved preferences
function PakettiYTDLPPrintPreferences()
  PakettiYTDLPLogMessage("Preferences:")
  PakettiYTDLPLogMessage("  Output Directory: " .. preferences.PakettiYTDLP.PakettiYTDLPOutputDirectory.value)
  PakettiYTDLPLogMessage("  Clip Length: " .. preferences.PakettiYTDLP.PakettiYTDLPClipLength.value)
  PakettiYTDLPLogMessage("  Loop Mode: " .. loop_modes[preferences.PakettiYTDLP.PakettiYTDLPLoopMode.value])
  PakettiYTDLPLogMessage("  Amount of Videos: " .. preferences.PakettiYTDLP.PakettiYTDLPAmountOfVideos.value)
  PakettiYTDLPLogMessage("  Load Whole Video: " .. tostring(preferences.PakettiYTDLP.PakettiYTDLPLoadWholeVideo.value))
  PakettiYTDLPLogMessage("  New Instrument: " .. tostring(preferences.PakettiYTDLP.PakettiYTDLPNewInstrumentOrSameInstrument.value))
  PakettiYTDLPLogMessage("  Save Format: " .. preferences.PakettiYTDLP.PakettiYTDLPFormatToSave.value)
  PakettiYTDLPLogMessage("  Save Path: " .. preferences.PakettiYTDLP.PakettiYTDLPPathToSave.value)
  PakettiYTDLPLogMessage("  yt-dlp Location: " .. preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value)
end

-- Function to handle the entire download process with proper slicing
function PakettiYTDLPSlicedProcess(search_phrase, youtube_url, output_dir, clip_length, full_video)
  -- Define paths for our tracking files
  local temp_dir = output_dir .. separator .. "tempfolder"
  local search_results_file = temp_dir .. separator .. "search_results.txt"
  local filenames_file = temp_dir .. separator .. "filenames.txt"
  
  -- Clear the files at start
  PakettiYTDLPClearFile(search_results_file)
  PakettiYTDLPClearFile(filenames_file)
  
  local command
  if youtube_url and youtube_url ~= "" then
    -- Direct URL download
    command = youtube_url
    PakettiYTDLPLogMessage("Starting download for URL: " .. youtube_url)
    -- Write URL to search results
    local f = io.open(search_results_file, "w")
    if f then
      f:write(youtube_url .. "\n")
      f:close()
    end
  else
    -- Search command - do this immediately without slicing
    -- Update the log BEFORE starting the search
    logview.text = "=== Starting search for term: \"" .. search_phrase .. "\" ===\n"
    local search_command = string.format('env PATH=/opt/homebrew/bin:$PATH "%s" "ytsearch30:%s" --get-id --no-warnings', yt_dlp_path, search_phrase)
    local handle = io.popen(search_command)
    if not handle then
      PakettiYTDLPLogMessage("ERROR: Failed to start search")
      return
    end
    
    -- Read all results immediately
    local urls = {}
    local count = 0
    local results_file = io.open(search_results_file, "w")
    local current_log = logview.text
    
    for line in handle:lines() do
      if line and line ~= "" then
        count = count + 1
        local url = "https://www.youtube.com/watch?v=" .. line
        table.insert(urls, url)
        
        -- Write to search results file
        if results_file then
          results_file:write(url .. "\n")
        end
        
        -- Update the progress on the same line
        logview.text = current_log .. string.format("Found video %02d/30", count)
        coroutine.yield()
      end
    end
    
    if results_file then
      results_file:close()
    end
    handle:close()
    
    if #urls == 0 then
      PakettiYTDLPLogMessage("ERROR: No videos found")
      return
    end
    
    logview.text = logview.text .. "\n"  -- Add newline after counter
    PakettiYTDLPLogMessage("=== Found " .. #urls .. " videos total ===")
    
    -- Select random URL
    math.randomseed(os.time())
    command = urls[math.random(1, #urls)]
    PakettiYTDLPLogMessage("=== Selected video for download: " .. command .. " ===")
  end
  
  -- Now start the actual download with slicing
  local download_cmd
  if full_video then
    download_cmd = string.format(
      'env PATH=/opt/homebrew/bin:$PATH "%s" --restrict-filenames -f ba --extract-audio --audio-format wav -o "%s%stempfolder%s%%(title)s-%%(id)s.%%(ext)s" "%s"',
      yt_dlp_path,
      output_dir,
      separator,
      separator,
      command
    )
  else
    download_cmd = string.format(
      'env PATH=/opt/homebrew/bin:$PATH "%s" --restrict-filenames --download-sections "*0-%d" -f ba --extract-audio --audio-format wav -o "%s%stempfolder%s%%(title)s-%%(id)s.%%(ext)s" "%s"',
      yt_dlp_path,
      clip_length,
      output_dir,
      separator,
      separator,
      command
    )
  end
  
  PakettiYTDLPLogMessage("=== Starting download process ===")
  
  -- Execute download with process slicing
  process_handle = io.popen(download_cmd .. " 2>&1", "r")
  if not process_handle then
    PakettiYTDLPLogMessage("ERROR: Failed to start download")
    return
  end
  
  -- Monitor download progress with slicing
  while true do
    local output = process_handle:read("*l")
    if not output then break end
    
    -- Update status text based on output
    if status_text then
      if output:match("^%[download%]%s+([%d%.]+)%%%s+") then
        status_text.text = "Downloading: " .. output:match("^%[download%]%s+([%d%.]+)%%%s+") .. "%"
      elseif output:match("^%[ExtractAudio%]") then
        status_text.text = "Extracting Audio..."
      end
    end
    
    PakettiYTDLPLogMessage(output)
    coroutine.yield()
  end
  
  process_handle:close()
  process_handle = nil
  
  if status_text then
    status_text.text = "Ready"
  end
  
  -- Write downloaded filenames to filenames.txt
  local files = PakettiYTDLPListDir(temp_dir)
  local filenames_handle = io.open(filenames_file, "w")
  if filenames_handle then
    for _, file in ipairs(files) do
      if file:match("%.wav$") then
        filenames_handle:write(file .. "\n")
        PakettiYTDLPLogMessage("Recording filename: " .. file)
      end
    end
    filenames_handle:close()
  else
    PakettiYTDLPLogMessage("ERROR: Could not open filenames.txt for writing")
  end
  
  -- Signal completion and trigger Renoise loading
  local completion_file = temp_dir .. separator .. "download_completed.txt"
  local file = io.open(completion_file, "w")
  if file then
    file:close()
    PakettiYTDLPLogMessage("=== Download complete, signaling for Renoise import ===")
  else
    PakettiYTDLPLogMessage("ERROR: Could not create completion signal file")
  end
end

-- Modify StartYTDLP to properly handle timers
function PakettiYTDLPStartYTDLP()
  local search_phrase = vb.views.search_phrase.text
  local youtube_url = vb.views.youtube_url.text
  local output_dir = vb.views.output_dir.text
  
  if (search_phrase == "" or search_phrase == nil) and (youtube_url == "" or youtube_url == nil) then
    renoise.app():show_warning("Please set URL or search term")
    return
  end
  
  if output_dir == "" or output_dir == "Set this yourself, please." then
    PakettiYTDLPPromptForOutputDir()
    return
  end
  
  -- Save all preferences
  preferences.PakettiYTDLP.PakettiYTDLPOutputDirectory.value = output_dir
  preferences.PakettiYTDLP.PakettiYTDLPClipLength.value = tonumber(vb.views.clip_length.value)
  preferences.PakettiYTDLP.PakettiYTDLPLoopMode.value = tonumber(vb.views.loop_mode.value)
  preferences.PakettiYTDLP.PakettiYTDLPAmountOfVideos.value = tonumber(vb.views.video_amount.value)
  preferences.PakettiYTDLP.PakettiYTDLPLoadWholeVideo.value = vb.views.full_video.value
  preferences.PakettiYTDLP.PakettiYTDLPNewInstrumentOrSameInstrument.value = vb.views.create_new_instrument.value
  preferences.PakettiYTDLP.PakettiYTDLPFormatToSave.value = vb.views.save_format.value
  preferences.PakettiYTDLP.PakettiYTDLPPathToSave.value = vb.views.save_path.text
  preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = vb.views.yt_dlp_location.text
  
  -- Create necessary directories
  PakettiYTDLPCreateDir(output_dir)
  PakettiYTDLPCreateDir(output_dir .. separator .. "tempfolder")
  
  -- Clean up old files
  if PakettiYTDLPFileExists(output_dir .. separator .. "tempfolder" .. separator .. "download_completed.txt") then
    os.remove(output_dir .. separator .. "tempfolder" .. separator .. "download_completed.txt")
  end
  PakettiYTDLPClearFile(output_dir .. separator .. "tempfolder" .. separator .. "filenames.txt")
  
  -- Start the sliced process
  if process_slicer and process_slicer:running() then
    process_slicer:stop()
  end
  
  process_slicer = ProcessSlicer(PakettiYTDLPSlicedProcess, 
    search_phrase, 
    youtube_url, 
    output_dir, 
    tonumber(vb.views.clip_length.value),
    vb.views.full_video.value
  )
  
  process_slicer:start()
  
  -- Proper timer handling
  local function check_completion()
    if PakettiYTDLPFileExists(output_dir .. separator .. "tempfolder" .. separator .. "download_completed.txt") then
      -- Remove the timer first
      if renoise.tool():has_timer(completion_timer_func) then
        renoise.tool():remove_timer(completion_timer_func)
      end
      -- Load into Renoise
      PakettiYTDLPLoadVideoAudioIntoRenoise(
        output_dir,
        tonumber(vb.views.loop_mode.value),
        vb.views.create_new_instrument.value
      )
    end
  end
  
  -- Store the function reference
  completion_timer_func = check_completion
  
  -- Remove existing timer if it exists
  if renoise.tool():has_timer(completion_timer_func) then
    renoise.tool():remove_timer(completion_timer_func)
  end
  
  -- Add the new timer
  renoise.tool():add_timer(completion_timer_func, 100)
end

function PakettiYTDLPDialogContent()
  vb = renoise.ViewBuilder()  -- Create a new ViewBuilder instance

  logview = vb:multiline_textfield {
    id = "log_view",
    text = "",
    width = 690,
    height = 500
  }

  status_text = vb:text { 
    id = "status_text",
    text = "Ready",
    width = 200
  }

  cancel_button = vb:button {
    id = "cancel_button",
    text = "Cancel",
    active = false,
    notifier = PakettiYTDLPCancelProcess
  }

  local dialog_content = vb:column {
    id = "main_column",
    width = 690,
    margin = 1,
    vb:text { id="hi", text = "YT-DLP is able to download content from:", font="bold"},
    vb:text{id="List",text="YouTube, Twitter, Facebook, SoundCloud, Bandcamp and Instagram (tested).", font = "bold" },
    vb:row {
      margin = 5,
      vb:column {
        width = 170,
        vb:text { text = "Search Phrase:" },
        vb:text { text = "URL:" },
        vb:text { text = "Output Directory:" },
        vb:text { text = "yt-dlp location:" },
        vb:text { text = "Clip Length (seconds):" },
        vb:text { text = "Loop Mode:" },
        vb:text { text = "Amount of Videos to Search for:" }
      },
      vb:column {
        width = 600,
        vb:textfield { 
          id = "search_phrase", 
          width = 400,
          edit_mode = true,
          notifier = function(value)
            if value ~= "" then
              PakettiYTDLPStartYTDLP()
            end
          end
        },
        vb:textfield {
          id = "youtube_url",
          width = 400,
          edit_mode = true,
          notifier = function(value)
            if value ~= "" then
              PakettiYTDLPStartYTDLP()
            end
          end
        },
        vb:row {
          vb:textfield {
            id = "output_dir",
            width = 400,
            text = preferences.PakettiYTDLP.PakettiYTDLPOutputDirectory.value
          },
          vb:button { text = "Browse", notifier = PakettiYTDLPPromptForOutputDir },
          vb:button { text = "Open Path", notifier = function()
            local path = vb.views.output_dir.text
            if path and path ~= "" and path ~= "Set this yourself, please." then
              os.execute('open "' .. path .. '"')
              PakettiYTDLPLogMessage("Opening path: " .. path)
            else
              renoise.app():show_warning("Please set a valid output directory first")
            end
          end},
        },
        vb:row {
          vb:textfield {
            id = "yt_dlp_location",
            width = 400,
            text = preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value or "<No path set>",
           -- read_only = true
          },
          vb:button { text = "Browse", notifier = PakettiYTDLPPromptForYTDLPPath },
        },
        vb:valuebox {
          id = "clip_length",
          min = 1,
          max = 60,
          value = preferences.PakettiYTDLP.PakettiYTDLPClipLength.value or SAMPLE_LENGTH,
          notifier = function(value)
            preferences.PakettiYTDLP.PakettiYTDLPClipLength.value = value
            PakettiYTDLPLogMessage("Saved Clip Length to " .. value)
          end
        },
        vb:popup {
          id = "loop_mode",
          items = loop_modes,
          value = preferences.PakettiYTDLP.PakettiYTDLPLoopMode.value or 2,
          width = 80,
          notifier = function(value)
            preferences.PakettiYTDLP.PakettiYTDLPLoopMode.value = value
            PakettiYTDLPLogMessage("Saved Loop Mode to " .. value)
          end
        },
        vb:valuebox {
          id = "video_amount",
          min = 1,
          max = 100,
          value = preferences.PakettiYTDLP.PakettiYTDLPAmountOfVideos.value or 1,
          notifier = function(value)
            preferences.PakettiYTDLP.PakettiYTDLPAmountOfVideos.value = value
            PakettiYTDLPLogMessage("Saved Amount of Videos to " .. value)
          end
        }
      }
    },
    vb:row {
      vb:checkbox {
        id = "full_video",
        value = preferences.PakettiYTDLP.PakettiYTDLPLoadWholeVideo.value,
        notifier = function(value)
          preferences.PakettiYTDLP.PakettiYTDLPLoadWholeVideo.value = value
          if value then vb.views.clip_length.value = SAMPLE_LENGTH end
          PakettiYTDLPLogMessage("Saved Load Whole Video to " .. tostring(value))
        end
      },
      vb:text { text = "Download Whole Video as Audio" },
    },
    vb:row {
      vb:checkbox {
        id = "create_new_instrument",
        value = preferences.PakettiYTDLP.PakettiYTDLPNewInstrumentOrSameInstrument.value,
        notifier = function(value)
          preferences.PakettiYTDLP.PakettiYTDLPNewInstrumentOrSameInstrument.value = value
          PakettiYTDLPLogMessage("Saved Create New Instrument to " .. tostring(value))
        end
      },
      vb:text { text = "Create New Instrument for Each Downloaded Audio" },
    },
    vb:row { vb:text { text = "Save Successfully Downloaded Audio to Selected Folder" },
      vb:popup {
        id = "save_format",
        items = {"Off", "Save WAV", "Save FLAC"},
        value = preferences.PakettiYTDLP.PakettiYTDLPFormatToSave.value or 1,
        width = 120,
        notifier = function(value)
          preferences.PakettiYTDLP.PakettiYTDLPFormatToSave.value = value
          if (value == 2 or value == 3) and (vb.views.save_path.text == "<No path set>" or vb.views.save_path.text == "") then
            PakettiYTDLPPromptForSavePath()
          end
          PakettiYTDLPLogMessage("Saved Save Format to " .. value)
        end
      },
    },
    vb:row {
      vb:text { text = "Save Path: " },
      vb:text { id = "save_path", text = preferences.PakettiYTDLP.PakettiYTDLPPathToSave.value or "<No path set>", font = "bold" },
      vb:button { text = "Browse", notifier = PakettiYTDLPPromptForSavePath }
    },
    vb:row {
      vb:text { text = "Status: " },
      status_text,
      cancel_button
    },
    -- Multiline Textfield for Logs
    vb:row {
      vb:column {
        vb:row {
          vb:text { text = "Log Output:", font = "bold" },
          vb:button {
            id = "Clear_thing",
            text = "Clear",
            notifier = function() logview.text = "" end
          }
        },
        logview,
      }
    },
    vb:row {
      vb:button {
        id = "start_button",
        text = "Start",
        notifier = function()
          -- Disable Start if yt-dlp location is not set
          if preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value == nil or preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value == "" then
            PakettiYTDLPPromptForYTDLPPath()
            if preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value == nil or preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value == "" then
              renoise.app():show_warning("Please set the yt-dlp location")
              return
            end
          end
          PakettiYTDLPStartYTDLP()
        end
      },
      vb:button { text = "Save", notifier = function()
        preferences.PakettiYTDLP.PakettiYTDLPOutputDirectory.value = vb.views.output_dir.text
        preferences.PakettiYTDLP.PakettiYTDLPClipLength.value = vb.views.clip_length.value
        preferences.PakettiYTDLP.PakettiYTDLPLoopMode.value = vb.views.loop_mode.value
        preferences.PakettiYTDLP.PakettiYTDLPAmountOfVideos.value = vb.views.video_amount.value
        preferences.PakettiYTDLP.PakettiYTDLPLoadWholeVideo.value = vb.views.full_video.value
        preferences.PakettiYTDLP.PakettiYTDLPNewInstrumentOrSameInstrument.value = vb.views.create_new_instrument.value
        preferences.PakettiYTDLP.PakettiYTDLPFormatToSave.value = vb.views.save_format.value
        preferences.PakettiYTDLP.PakettiYTDLPPathToSave.value = vb.views.save_path.text
        preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = vb.views.yt_dlp_location.text

        PakettiYTDLPPrintPreferences()
      end},
      vb:button { text = "Save & Close", notifier = function()
        preferences.PakettiYTDLP.PakettiYTDLPOutputDirectory.value = vb.views.output_dir.text
        preferences.PakettiYTDLP.PakettiYTDLPClipLength.value = vb.views.clip_length.value
        preferences.PakettiYTDLP.PakettiYTDLPLoopMode.value = vb.views.loop_mode.value
        preferences.PakettiYTDLP.PakettiYTDLPAmountOfVideos.value = vb.views.video_amount.value
        preferences.PakettiYTDLP.PakettiYTDLPLoadWholeVideo.value = vb.views.full_video.value
        preferences.PakettiYTDLP.PakettiYTDLPNewInstrumentOrSameInstrument.value = vb.views.create_new_instrument.value
        preferences.PakettiYTDLP.PakettiYTDLPFormatToSave.value = vb.views.save_format.value
        preferences.PakettiYTDLP.PakettiYTDLPPathToSave.value = vb.views.save_path.text
        preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = vb.views.yt_dlp_location.text

        PakettiYTDLPPrintPreferences()
        PakettiYTDLPCloseDialog()
      end}
    }
  }

  -- If yt-dlp location is not set, prompt immediately
  if preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value == nil or preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value == "" then
    PakettiYTDLPPromptForYTDLPPath()
  end

  -- Store references to UI elements
  status_text = vb.views.status_text
  cancel_button = vb.views.cancel_button

  return dialog_content
end

function PakettiYTDLPKeyHandlerFunc(dialog, key)
local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    dialog = nil
    return nil
end

  if key.modifiers == "" and key.name == "return" then
    PakettiYTDLPLogMessage("Enter key pressed, starting process.")
    PakettiYTDLPStartYTDLP()
  else
    return key
  end
end


function PakettiYTDLPShowDialog()
  if dialog and dialog.visible then
    PakettiYTDLPLogMessage("Dialog is visible, closing dialog.")
    PakettiYTDLPCloseDialog()
  else
    dialog_content = PakettiYTDLPDialogContent()
    dialog = renoise.app():show_custom_dialog("Paketti YT-DLP Downloader", dialog_content, PakettiYTDLPKeyHandlerFunc)
    PakettiYTDLPLogMessage("YT-DLP Downloader Initialized and ready to go.")
  end
end

function PakettiYTDLPCloseDialog()
  if process_running then
    PakettiYTDLPCancelProcess()
  end
  
  -- Clean up timer
  if completion_timer_func and renoise.tool():has_timer(completion_timer_func) then
    renoise.tool():remove_timer(completion_timer_func)
  end
  
  if dialog and dialog.visible then
    dialog:close()
  end
  dialog = nil
  logview = nil
  vb = nil
  status_text = nil
  cancel_button = nil
  completion_timer_func = nil
  renoise.app():show_status("Closing Paketti YT-DLP Dialog")
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Xperimental/Work in Progress..:Paketti YT-DLP Downloader...",invoke=function() PakettiYTDLPShowDialog() end}

renoise.tool():add_keybinding{name="Global:Paketti:Paketti YT-DLP Downloader",invoke=PakettiYTDLPShowDialog }
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Paketti YT-DLP Downloader...",invoke=PakettiYTDLPShowDialog }
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Paketti YT-DLP Downloader...",invoke=PakettiYTDLPShowDialog }
--renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Paketti YT-DLP Downloader...",invoke=PakettiYTDLPShowDialog }

-- Add this function to handle process cancellation
function PakettiYTDLPCancelProcess()
  if process_handle then
    -- Get process ID on macOS
    local handle = io.popen("ps -o ppid= -p " .. tostring(process_handle:getfd()))
    if handle then
      local ppid = handle:read("*n")
      handle:close()
      if ppid then
        os.execute("kill " .. ppid)
      end
    end
    process_handle:close()
    process_handle = nil
  end
  
  if process_timer then
    process_timer:stop()
    process_timer = nil
  end
  
  process_running = false
  if status_text then
    status_text.text = "Ready"
  end
  if cancel_button then
    cancel_button.active = false
  end
  PakettiYTDLPLogMessage("Process cancelled")
end

