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
  if logview then
    local current_text = logview.text
    logview.text = current_text .. message .. "\n"
  else
    -- If logview is not available, fallback to print
    print("Log view not available. Message:", message)
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
      table.insert(files, file)
    end
    handle:close()
  else
    PakettiYTDLPLogMessage("Failed to list directory: " .. dir)
    error("Failed to list directory: " .. dir)
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

-- Function to execute shell commands and log output in real-time
function PakettiYTDLPExecuteCommand(command)
  PakettiYTDLPLogMessage("Executing command: " .. command)
  local handle = io.popen(command)
  if handle then
    for line in handle:lines() do
      PakettiYTDLPLogMessage(line)
    end
    local success, exit_reason, exit_code = handle:close()
    if not success then
      PakettiYTDLPLogMessage("Command failed (" .. tostring(exit_code) .. "): " .. command)
      error("Command failed (" .. tostring(exit_code) .. "): " .. command)
    end
  else
    PakettiYTDLPLogMessage("Failed to execute command: " .. command)
    error("Failed to execute command: " .. command)
  end
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
  -- Prepend PATH using 'env' to ensure ffmpeg is found
  local command = string.format('env PATH=/opt/homebrew/bin:$PATH "%s" "ytsearch30:%s" --get-id  > "%s"', yt_dlp_path, search_phrase, search_results_file)
  PakettiYTDLPLogMessage("Executing command for search: " .. command)
  PakettiYTDLPExecuteCommand(command)

  -- Check if search_results_file has content
  local file = io.open(search_results_file, "r")
  if not file then
    PakettiYTDLPLogMessage("Failed to open search results file: " .. search_results_file)
    return
  end
  local content = file:read("*a")
  file:close()

  if content == "" then
    PakettiYTDLPLogMessage("No URLs found for the search term.")
    return
  end

  -- Split the content into URLs
  local urls = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(urls, "https://www.youtube.com/watch?v=" .. line)
  end

  PakettiYTDLPLogMessage(string.format("Got %d search results.", #urls))

  -- Select a random URL
  math.randomseed(os.time())
  local random_index = math.random(1, #urls)
  local selected_url = urls[random_index]
  PakettiYTDLPLogMessage("Selected URL: " .. selected_url)
  return selected_url
end

-- Function to download video or clip
function PakettiYTDLPDownloadVideo(youtube_url, full_video, clip_length, temp_dir)
  if full_video then
    PakettiYTDLPLogMessage("Downloading full video from URL...")
    -- Prepend PATH using 'env' to ensure ffmpeg is found
    local command = string.format(
      'env PATH=/opt/homebrew/bin:$PATH "%s" --restrict-filenames -f ba --extract-audio --audio-format wav -o "%s/%%(title)s-%%(id)s.%%(ext)s" "%s"',
      yt_dlp_path,
      temp_dir,
      youtube_url
    )
    PakettiYTDLPExecuteCommand(command)
  else
    PakettiYTDLPLogMessage(string.format("Downloading clip of length %d seconds from URL...", clip_length))
    -- Prepend PATH using 'env' to ensure ffmpeg is found
    local command = string.format(
      'env PATH=/opt/homebrew/bin:$PATH "%s" --restrict-filenames --download-sections "*0-%d" -f ba --extract-audio --audio-format wav -o "%s/%%(title)s-%%(id)s.%%(ext)s" "%s"',
      yt_dlp_path,
      clip_length,
      temp_dir,
      youtube_url
    )
    PakettiYTDLPExecuteCommand(command)
  end
end

-- Function to sanitize filenames in temp_dir and record them
function PakettiYTDLPSanitizeFilenames(temp_dir, filenames_file)
  local files = PakettiYTDLPListDir(temp_dir)
  for _, file in ipairs(files) do
    if file:sub(-4) == ".wav" then
      local sanitized = PakettiYTDLPSanitizeFilename(file)
      if file ~= sanitized then
        local old_path = temp_dir .. "/" .. file
        local new_path = temp_dir .. "/" .. sanitized
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


-- =====================
-- Main Functionalities
-- =====================

-- Main Function to execute the download process
function PakettiYTDLPExecuteLua(search_phrase, youtube_url, download_dir, clip_length, full_video)
  -- Set executable paths based on OS
  PakettiYTDLPSetExecutablePaths()

  -- Define paths
  -- Ensure no trailing slash on download_dir
  if download_dir:sub(-1) == "/" then
    download_dir = download_dir:sub(1, -2)
  end
  local temp_dir = download_dir .. "/tempfolder"
  local completion_signal_file = temp_dir .. "/download_completed.txt"
  local filenames_file = temp_dir .. "/filenames.txt"
  local search_results_file = temp_dir .. "/search_results.txt"

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
  local temp_dir = download_dir .. "/tempfolder"
  local completion_signal_file = temp_dir .. "/download_completed.txt"
  local filenames_file = temp_dir .. "/filenames.txt"

  -- Wait until the completion signal file is created
  PakettiYTDLPLogMessage("Waiting for completion signal file...")
  while not PakettiYTDLPFileExists(completion_signal_file) do
    os.execute('sleep 1')
  end
  PakettiYTDLPLogMessage("Completion signal file detected.")

  -- Wait until the filenames.txt file is created and contains data
  local filenames = ""
  PakettiYTDLPLogMessage("Waiting for filenames file to contain data...")
  while true do
    local file = io.open(filenames_file, "r")
    if file then
      filenames = file:read("*a")
      file:close()
      if filenames and #filenames > 0 then
        break
      end
    end
    os.execute('sleep 1')
  end
  PakettiYTDLPLogMessage("Filenames file contains data.")

  -- Read sanitized filenames from the filenames.txt file
  local sample_files = {}
  for line in filenames:gmatch("[^\r\n]+") do
    table.insert(sample_files, temp_dir .. "/" .. line:match('^"?([^"]*)"?$'))
  end

  if #sample_files == 0 then
    PakettiYTDLPLogMessage("No samples found in directory: " .. temp_dir)
    return
  end

  PakettiYTDLPLogMessage("Found " .. #sample_files .. " sample(s) in directory: " .. temp_dir)

  -- Ensure files are fully available
  for _, file in ipairs(sample_files) do
    PakettiYTDLPLogMessage("Checking file: " .. file)
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
    PakettiYTDLPLogMessage("File is fully available: " .. file)
  end

  local selected_instrument_index = renoise.song().selected_instrument_index

  if create_new_instrument then
    selected_instrument_index = renoise.song().selected_instrument_index + 1
    renoise.song():insert_instrument_at(selected_instrument_index)
    renoise.song().selected_instrument_index = selected_instrument_index
    pakettiPreferencesDefaultInstrumentLoader() -- Assuming this function is defined elsewhere
    PakettiYTDLPLogMessage("Created new instrument at index: " .. selected_instrument_index)
  end

  local instrument = renoise.song().instruments[selected_instrument_index]

  for _, file in ipairs(sample_files) do
    PakettiYTDLPLogMessage("Loading sample: " .. file)
    local f = io.open(file, "rb")
    if f then
      f:close()
      local sample = instrument:insert_sample_at(1)
      local buffer = sample.sample_buffer
      
      -- Load the sample
      if not buffer:load_from(file) then
        PakettiYTDLPLogMessage("Failed to load sample: " .. file)
        goto continue
      end
      
      -- Wait for sample to be fully loaded
      buffer:prepare_sample_data_changes()
      buffer:finalize_sample_data_changes()
      
      -- Only try to normalize if we have valid sample data
      if buffer.has_sample_data then
        if normalize_selected_sample() then
          PakettiYTDLPLogMessage("Successfully normalized sample: " .. file)
        else
          PakettiYTDLPLogMessage("Failed to normalize sample: " .. file)
        end
      else
        PakettiYTDLPLogMessage("Skipping normalization - no valid sample data")
      end

      sample.name = file:match("^.+/(.+)$")
      instrument.name = sample.name
      PakettiYTDLPLogMessage("Loaded sample: " .. file)
      sample.loop_mode = loop_mode
    else
      PakettiYTDLPLogMessage("File does not exist: " .. file)
    end
    ::continue::
  end

  for _, file in ipairs(sample_files) do
    local dest_file = download_dir .. "/" .. file:match("^.+/(.+)$")
    local success_move, err_move = PakettiYTDLPMove(file, dest_file)
    if success_move then
      PakettiYTDLPLogMessage("Moved '" .. file .. "' to '" .. dest_file .. "'")
    else
      PakettiYTDLPLogMessage("Failed to move '" .. file .. "': " .. tostring(err_move))
    end
  end

  -- Clear the filenames.txt file
  PakettiYTDLPClearFile(filenames_file)

  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  PakettiYTDLPLogMessage("Samples loaded into Renoise.")
end

-- =====================
-- GUI Components
-- =====================

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
  local file = renoise.app():prompt_for_filename_to_read({"*"}, "Select YT-DLP Executable")
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

-- Function to start the YT-DLP process
function PakettiYTDLPStartYTDLP()
  local search_phrase = vb.views.search_phrase.text
  local youtube_url = vb.views.youtube_url.text
  local output_dir = vb.views.output_dir.text

  PakettiYTDLPLogMessage("Start pressed. Beginning the download process.")

  if (search_phrase == "" or search_phrase == nil) and (youtube_url == "" or youtube_url == nil) then
    renoise.app():show_warning("Please set URL or search term")
    return
  end
  if output_dir == "" or output_dir == "Set this yourself, please." then
    PakettiYTDLPPromptForOutputDir()
    return
  end
  if preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value == nil or preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value == "" then
    PakettiYTDLPPromptForYTDLPPath()
    if preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value == nil or preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value == "" then
      renoise.app():show_warning("Please set the yt-dlp location")
      return
    end
  end

  local clip_length = tonumber(vb.views.clip_length.value)
  local full_video = vb.views.full_video.value
  local loop_mode = tonumber(vb.views.loop_mode.value)
  local create_new_instrument = vb.views.create_new_instrument.value
  local save_format = vb.views.save_format.items[vb.views.save_format.value]
  local save_to_folder = save_format ~= "Off"
  local save_path = vb.views.save_path.text

  if save_to_folder and (save_path == "<No path set>" or save_path == "") then
    PakettiYTDLPPromptForSavePath()
    return
  end

  preferences.PakettiYTDLP.PakettiYTDLPOutputDirectory.value = output_dir
  preferences.PakettiYTDLP.PakettiYTDLPClipLength.value = clip_length
  preferences.PakettiYTDLP.PakettiYTDLPLoopMode.value = loop_mode
  preferences.PakettiYTDLP.PakettiYTDLPAmountOfVideos.value = tonumber(vb.views.video_amount.value)
  preferences.PakettiYTDLP.PakettiYTDLPLoadWholeVideo.value = full_video
  preferences.PakettiYTDLP.PakettiYTDLPNewInstrumentOrSameInstrument.value = create_new_instrument
  preferences.PakettiYTDLP.PakettiYTDLPFormatToSave.value = vb.views.save_format.value
  preferences.PakettiYTDLP.PakettiYTDLPPathToSave.value = save_path
  preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = vb.views.yt_dlp_location.text

  PakettiYTDLPLogMessage("Starting process with:")
  PakettiYTDLPLogMessage("  Search Phrase: " .. tostring(search_phrase))
  PakettiYTDLPLogMessage("  URL: " .. tostring(youtube_url))
  PakettiYTDLPLogMessage("  Output Directory: " .. tostring(output_dir))
  PakettiYTDLPLogMessage("  Clip Length: " .. tostring(clip_length))
  PakettiYTDLPLogMessage("  Download Full Video: " .. tostring(full_video))
  PakettiYTDLPLogMessage("  Loop Mode: " .. loop_modes[loop_mode])
  PakettiYTDLPLogMessage("  Create New Instrument: " .. tostring(create_new_instrument))
  PakettiYTDLPLogMessage("  Save Format: " .. save_format)
  PakettiYTDLPLogMessage("  Save to Folder: " .. tostring(save_to_folder))
  PakettiYTDLPLogMessage("  Save Path: " .. tostring(save_path))
  PakettiYTDLPLogMessage("  yt-dlp Location: " .. preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value)

  -- Execute the download process
  PakettiYTDLPExecuteLua(search_phrase, youtube_url, output_dir, clip_length, full_video)
  -- Load the downloaded audio into Renoise
  PakettiYTDLPLoadVideoAudioIntoRenoise(output_dir, loop_mode, create_new_instrument)
end

-- =====================
-- Dialog Functions
-- =====================

-- Function to create the dialog content
function PakettiYTDLPDialogContent()
  vb = renoise.ViewBuilder()  -- Create a new ViewBuilder instance

  logview = vb:multiline_textfield {
    id = "log_view",
    text = "",
    width = 630,
    height = 500
  }

  local dialog_content = vb:column {
    id = "main_column",
    width = 650,
    margin = 10,
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
        vb:textfield { id = "search_phrase", width = 400 },
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
      end },
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
      end }
    }
  }

  -- If yt-dlp location is not set, prompt immediately
  if preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value == nil or preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value == "" then
    PakettiYTDLPPromptForYTDLPPath()
  end

  return dialog_content
end

-- Key Handler function for the dialog
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
  if dialog and dialog.visible then
    dialog:close()
  end
  dialog = nil
  logview = nil  
  vb = nil       
  renoise.app():show_status("Closing Paketti YT-DLP Dialog")
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Xperimental/Work in Progress..:Paketti YT-DLP Downloader...",invoke=function() PakettiYTDLPShowDialog() end }

renoise.tool():add_keybinding{name="Global:Tools:Paketti YT-DLP Downloader",invoke=PakettiYTDLPShowDialog }
--renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Paketti YT-DLP Downloader...",invoke=PakettiYTDLPShowDialog }
--renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Paketti YT-DLP Downloader...",invoke=PakettiYTDLPShowDialog }
--renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Paketti YT-DLP Downloader...",invoke=PakettiYTDLPShowDialog }

