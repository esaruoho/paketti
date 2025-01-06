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
function PakettiColugaSetExecutablePaths()
  yt_dlp_path = preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value

  if yt_dlp_path == nil or yt_dlp_path == "" then
    PakettiColugaLogMessage("yt-dlp path not set. Exiting.")
    error("yt-dlp path not set. Please set the yt-dlp location in the preferences.")
  end

  PakettiColugaLogMessage("Using yt-dlp path: " .. yt_dlp_path)

  -- Set ffmpeg_path based on OS
  local os_name = os.platform()

  if os_name == "MACINTOSH" then
    ffmpeg_path = "/opt/homebrew/bin/ffmpeg"
    PakettiColugaLogMessage("Detected macOS. Setting ffmpeg path accordingly.")
  elseif os_name == "LINUX" then
    ffmpeg_path = "/usr/bin/ffmpeg"
    PakettiColugaLogMessage("Detected Linux. Setting ffmpeg path accordingly.")
  elseif os_name == "WINDOWS" then
    renoise.app():show_status("Windows is currently not supported.")
    PakettiColugaLogMessage("Windows detected. Exiting as it's not supported.")
    error("Windows is currently not supported.")
  else
    renoise.app():show_status("Unsupported OS detected.")
    PakettiColugaLogMessage("Unsupported OS detected. Exiting.")
    error("Unsupported OS detected.")
  end
end

-- Function to log messages to the multiline textfield
function PakettiColugaLogMessage(message)
  if logview then
    local current_text = logview.text
    logview.text = current_text .. message .. "\n"
  else
    -- If logview is not available, fallback to print
    print("Log view not available. Message:", message)
  end
end

-- Function to move files (fallback if os.rename is not available)
function PakettiColugaMove(src, dest)
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
function PakettiColugaFileExists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  else
    return false
  end
end

-- Function to check if a directory exists
function PakettiColugaDirectoryExists(path)
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
function PakettiColugaCreateDir(path)
  if not PakettiColugaDirectoryExists(path) then
    local success, err = os.execute('mkdir -p "' .. path .. '"')
    if not success then
      PakettiColugaLogMessage("Failed to create directory '" .. path .. "': " .. tostring(err))
      error("Failed to create directory '" .. path .. "': " .. tostring(err))
    end
    PakettiColugaLogMessage("Created directory: " .. path)
  else
    PakettiColugaLogMessage("Directory already exists: " .. path)
  end
end

-- Function to list files in a directory
function PakettiColugaListDir(dir)
  local files = {}
  local handle = io.popen('ls "' .. dir .. '"')
  if handle then
    for file in handle:lines() do
      table.insert(files, file)
    end
    handle:close()
  else
    PakettiColugaLogMessage("Failed to list directory: " .. dir)
    error("Failed to list directory: " .. dir)
  end
  return files
end

-- Function to safely remove files with a specific extension
function PakettiColugaRemoveFilesWithExtension(dir, extension)
  local files = PakettiColugaListDir(dir)
  for _, file in ipairs(files) do
    if file:sub(-#extension) == extension then
      local filepath = dir .. "/" .. file
      local success, err = os.remove(filepath)
      if success then
        PakettiColugaLogMessage("Removed file: " .. filepath)
      else
        PakettiColugaLogMessage("Failed to remove file: " .. filepath .. " Error: " .. tostring(err))
      end
    end
  end
end

-- Function to clear a file's contents
function PakettiColugaClearFile(filepath)
  local file, err = io.open(filepath, "w")
  if not file then
    PakettiColugaLogMessage("Failed to open file '" .. filepath .. "' for writing: " .. tostring(err))
    error("Failed to open file '" .. filepath .. "' for writing: " .. tostring(err))
  end
  file:close()
  PakettiColugaLogMessage("Cleared file: " .. filepath)
end

-- Function to execute shell commands and log output in real-time
function PakettiColugaExecuteCommand(command)
  PakettiColugaLogMessage("Executing command: " .. command)
  local handle = io.popen(command)
  if handle then
    for line in handle:lines() do
      PakettiColugaLogMessage(line)
    end
    local success, exit_reason, exit_code = handle:close()
    if not success then
      PakettiColugaLogMessage("Command failed (" .. tostring(exit_code) .. "): " .. command)
      error("Command failed (" .. tostring(exit_code) .. "): " .. command)
    end
  else
    PakettiColugaLogMessage("Failed to execute command: " .. command)
    error("Failed to execute command: " .. command)
  end
end

-- Function to sanitize filenames: allow only A-Z, a-z, 0-9, hyphens, and underscores, preserve extension
function PakettiColugaSanitizeFilename(filename)
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
function PakettiColugaGetRandomUrl(search_phrase, search_results_file)
  -- Prepend PATH using 'env' to ensure ffmpeg is found
  local command = string.format('env PATH=/opt/homebrew/bin:$PATH "%s" "ytsearch30:%s" --get-id  > "%s"', yt_dlp_path, search_phrase, search_results_file)
  PakettiColugaLogMessage("Executing command for search: " .. command)
  PakettiColugaExecuteCommand(command)

  -- Check if search_results_file has content
  local file = io.open(search_results_file, "r")
  if not file then
    PakettiColugaLogMessage("Failed to open search results file: " .. search_results_file)
    return
  end
  local content = file:read("*a")
  file:close()

  if content == "" then
    PakettiColugaLogMessage("No URLs found for the search term.")
    return
  end

  -- Split the content into URLs
  local urls = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(urls, "https://www.youtube.com/watch?v=" .. line)
  end

  PakettiColugaLogMessage(string.format("Got %d search results.", #urls))

  -- Select a random URL
  math.randomseed(os.time())
  local random_index = math.random(1, #urls)
  local selected_url = urls[random_index]
  PakettiColugaLogMessage("Selected URL: " .. selected_url)
  return selected_url
end

-- Function to download video or clip
function PakettiColugaDownloadVideo(youtube_url, full_video, clip_length, temp_dir)
  if full_video then
    PakettiColugaLogMessage("Downloading full video from URL...")
    -- Prepend PATH using 'env' to ensure ffmpeg is found
    local command = string.format(
      'env PATH=/opt/homebrew/bin:$PATH "%s" --restrict-filenames -f ba --extract-audio --audio-format wav -o "%s/%%(title)s-%%(id)s.%%(ext)s" "%s"',
      yt_dlp_path,
      temp_dir,
      youtube_url
    )
    PakettiColugaExecuteCommand(command)
  else
    PakettiColugaLogMessage(string.format("Downloading clip of length %d seconds from URL...", clip_length))
    -- Prepend PATH using 'env' to ensure ffmpeg is found
    local command = string.format(
      'env PATH=/opt/homebrew/bin:$PATH "%s" --restrict-filenames --download-sections "*0-%d" -f ba --extract-audio --audio-format wav -o "%s/%%(title)s-%%(id)s.%%(ext)s" "%s"',
      yt_dlp_path,
      clip_length,
      temp_dir,
      youtube_url
    )
    PakettiColugaExecuteCommand(command)
  end
end

-- Function to sanitize filenames in temp_dir and record them
function PakettiColugaSanitizeFilenames(temp_dir, filenames_file)
  local files = PakettiColugaListDir(temp_dir)
  for _, file in ipairs(files) do
    if file:sub(-4) == ".wav" then
      local sanitized = PakettiColugaSanitizeFilename(file)
      if file ~= sanitized then
        local old_path = temp_dir .. "/" .. file
        local new_path = temp_dir .. "/" .. sanitized
        local success, err = PakettiColugaMove(old_path, new_path)
        if success then
          PakettiColugaLogMessage("Renamed '" .. file .. "' to '" .. sanitized .. "'")
        else
          PakettiColugaLogMessage("Failed to rename '" .. file .. "': " .. tostring(err))
        end
      end
      -- Append sanitized filename to filenames_file
      local file_handle, err = io.open(filenames_file, "a")
      if file_handle then
        file_handle:write(sanitized .. "\n")
        file_handle:close()
        PakettiColugaLogMessage("Recorded filename: " .. sanitized)
      else
        PakettiColugaLogMessage("Failed to open filenames file: " .. tostring(err))
      end
    end
  end
end

-- Function to signal completion by creating a file
function PakettiColugaSignalCompletion(completion_signal_file)
  local file, err = io.open(completion_signal_file, "w")
  if not file then
    PakettiColugaLogMessage("Failed to create completion signal file: " .. tostring(err))
    error("Failed to create completion signal file: " .. tostring(err))
  end
  file:close()
  PakettiColugaLogMessage("Created completion signal file: " .. completion_signal_file)
end


-- =====================
-- Main Functionalities
-- =====================

-- Main Function to execute the download process
function PakettiColugaExecuteLua(search_phrase, youtube_url, download_dir, clip_length, full_video)
  -- Set executable paths based on OS
  PakettiColugaSetExecutablePaths()

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
  PakettiColugaLogMessage("Starting Paketti YT-DLP with arguments:")
  PakettiColugaLogMessage("SEARCH_PHRASE: " .. tostring(search_phrase))
  PakettiColugaLogMessage("YOUTUBE_URL: " .. tostring(youtube_url))
  PakettiColugaLogMessage("DOWNLOAD_DIR: " .. tostring(download_dir))
  PakettiColugaLogMessage("CLIP_LENGTH: " .. tostring(clip_length))
  PakettiColugaLogMessage("FULL_VIDEO: " .. tostring(full_video))

  -- Create necessary directories
  PakettiColugaCreateDir(download_dir)
  PakettiColugaCreateDir(temp_dir)

  -- Clean up temp_dir
  PakettiColugaRemoveFilesWithExtension(temp_dir, ".wav")
  -- Remove completion signal file if it exists
  if PakettiColugaFileExists(completion_signal_file) then
    local success_remove, err_remove = os.remove(completion_signal_file)
    if success_remove then
      PakettiColugaLogMessage("Removed completion signal file if it existed: " .. completion_signal_file)
    else
      PakettiColugaLogMessage("Failed to remove completion signal file: " .. completion_signal_file .. " Error: " .. tostring(err_remove))
    end
  else
    PakettiColugaLogMessage("No existing completion signal file to remove: " .. completion_signal_file)
  end
  PakettiColugaClearFile(filenames_file)
  PakettiColugaClearFile(search_results_file)

  -- Determine which URL to download
  local selected_url = youtube_url
  if not selected_url or selected_url == "" then
    selected_url = PakettiColugaGetRandomUrl(search_phrase, search_results_file)
  end

  if not selected_url then
    PakettiColugaLogMessage("No URL selected for download. Exiting.")
    return
  end

  PakettiColugaLogMessage(string.format("Starting download for URL: %s.", selected_url))

  -- Download video or clip
  PakettiColugaDownloadVideo(selected_url, full_video, clip_length, temp_dir)

  -- Sanitize filenames and record them
  PakettiColugaSanitizeFilenames(temp_dir, filenames_file)

  -- Signal completion
  PakettiColugaSignalCompletion(completion_signal_file)

  PakettiColugaLogMessage("Paketti YT-DLP finished.")
end

-- Function to load downloaded samples into Renoise
function PakettiColugaLoadVideoAudioIntoRenoise(download_dir, loop_mode, create_new_instrument)
  local temp_dir = download_dir .. "/tempfolder"
  local completion_signal_file = temp_dir .. "/download_completed.txt"
  local filenames_file = temp_dir .. "/filenames.txt"

  -- Wait until the completion signal file is created
  PakettiColugaLogMessage("Waiting for completion signal file...")
  while not PakettiColugaFileExists(completion_signal_file) do
    os.execute('sleep 1')
  end
  PakettiColugaLogMessage("Completion signal file detected.")

  -- Wait until the filenames.txt file is created and contains data
  local filenames = ""
  PakettiColugaLogMessage("Waiting for filenames file to contain data...")
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
  PakettiColugaLogMessage("Filenames file contains data.")

  -- Read sanitized filenames from the filenames.txt file
  local sample_files = {}
  for line in filenames:gmatch("[^\r\n]+") do
    table.insert(sample_files, temp_dir .. "/" .. line:match('^"?([^"]*)"?$'))
  end

  if #sample_files == 0 then
    PakettiColugaLogMessage("No samples found in directory: " .. temp_dir)
    return
  end

  PakettiColugaLogMessage("Found " .. #sample_files .. " sample(s) in directory: " .. temp_dir)

  -- Ensure files are fully available
  for _, file in ipairs(sample_files) do
    PakettiColugaLogMessage("Checking file: " .. file)
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
    PakettiColugaLogMessage("File is fully available: " .. file)
  end

  local selected_instrument_index = renoise.song().selected_instrument_index

  if create_new_instrument then
    selected_instrument_index = renoise.song().selected_instrument_index + 1
    renoise.song():insert_instrument_at(selected_instrument_index)
    renoise.song().selected_instrument_index = selected_instrument_index
    pakettiPreferencesDefaultInstrumentLoader() -- Assuming this function is defined elsewhere
    PakettiColugaLogMessage("Created new instrument at index: " .. selected_instrument_index)
  end

  local instrument = renoise.song().instruments[selected_instrument_index]

  for _, file in ipairs(sample_files) do
    PakettiColugaLogMessage("Loading sample: " .. file)
    local f = io.open(file, "rb")
    if f then
      f:close()
      local sample = instrument:insert_sample_at(1)
      sample.sample_buffer:load_from(file)
      normalize_selected_sample() -- Assuming this function is defined elsewhere

      sample.name = file:match("^.+/(.+)$")
      instrument.name = sample.name
      PakettiColugaLogMessage("Loaded sample: " .. file)
      sample.loop_mode = loop_mode
    else
      PakettiColugaLogMessage("File does not exist: " .. file)
    end
  end

  for _, file in ipairs(sample_files) do
    local dest_file = download_dir .. "/" .. file:match("^.+/(.+)$")
    local success_move, err_move = PakettiColugaMove(file, dest_file)
    if success_move then
      PakettiColugaLogMessage("Moved '" .. file .. "' to '" .. dest_file .. "'")
    else
      PakettiColugaLogMessage("Failed to move '" .. file .. "': " .. tostring(err_move))
    end
  end

  -- Clear the filenames.txt file
  PakettiColugaClearFile(filenames_file)

  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  PakettiColugaLogMessage("Samples loaded into Renoise.")
end

-- =====================
-- GUI Components
-- =====================

-- Function to prompt for output directory
function PakettiColugaPromptForOutputDir()
  renoise.app():show_warning("Please set the folder that YT-DLP will download to...")
  local dir = renoise.app():prompt_for_path("Select Output Directory")
  if dir then
    vb.views.output_dir.text = dir
    preferences.pakettiColuga.pakettiColugaOutputDirectory.value = dir
    PakettiColugaLogMessage("Saved Output Directory to " .. dir)
  end
end

-- Function to prompt for save path
function PakettiColugaPromptForSavePath()
  renoise.app():show_warning("Please set the folder to save WAV or FLAC to...")
  local dir = renoise.app():prompt_for_path("Select Save Path")
  if dir then
    vb.views.save_path.text = dir
    preferences.pakettiColuga.pakettiColugaPathToSave.value = dir
    PakettiColugaLogMessage("Saved Save Path to " .. dir)
  end
end

-- Function to prompt for yt-dlp path
function PakettiColugaPromptForYTDLPPath()
  renoise.app():show_warning("Please select the YT-DLP executable")
  local file = renoise.app():prompt_for_filename_to_read({"*.*"}, "Select YT-DLP Executable")
  if file then
    vb.views.yt_dlp_location.text = file
    preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value = file
    PakettiColugaLogMessage("Saved yt-dlp location to " .. file)
  end
end

-- Function to print saved preferences
function PakettiColugaPrintPreferences()
  PakettiColugaLogMessage("Preferences:")
  PakettiColugaLogMessage("  Output Directory: " .. preferences.pakettiColuga.pakettiColugaOutputDirectory.value)
  PakettiColugaLogMessage("  Clip Length: " .. preferences.pakettiColuga.pakettiColugaClipLength.value)
  PakettiColugaLogMessage("  Loop Mode: " .. loop_modes[preferences.pakettiColuga.pakettiColugaLoopMode.value])
  PakettiColugaLogMessage("  Amount of Videos: " .. preferences.pakettiColuga.pakettiColugaAmountOfVideos.value)
  PakettiColugaLogMessage("  Load Whole Video: " .. tostring(preferences.pakettiColuga.pakettiColugaLoadWholeVideo.value))
  PakettiColugaLogMessage("  New Instrument: " .. tostring(preferences.pakettiColuga.pakettiColugaNewInstrumentOrSameInstrument.value))
  PakettiColugaLogMessage("  Save Format: " .. preferences.pakettiColuga.pakettiColugaFormatToSave.value)
  PakettiColugaLogMessage("  Save Path: " .. preferences.pakettiColuga.pakettiColugaPathToSave.value)
  PakettiColugaLogMessage("  yt-dlp Location: " .. preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value)
end

-- Function to start the YT-DLP process
function PakettiColugaStartYTDLP()
  local search_phrase = vb.views.search_phrase.text
  local youtube_url = vb.views.youtube_url.text
  local output_dir = vb.views.output_dir.text

  PakettiColugaLogMessage("Start pressed. Beginning the download process.")

  if (search_phrase == "" or search_phrase == nil) and (youtube_url == "" or youtube_url == nil) then
    renoise.app():show_warning("Please set URL or search term")
    return
  end
  if output_dir == "" or output_dir == "Set this yourself, please." then
    PakettiColugaPromptForOutputDir()
    return
  end
  if preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value == nil or preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value == "" then
    PakettiColugaPromptForYTDLPPath()
    if preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value == nil or preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value == "" then
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
    PakettiColugaPromptForSavePath()
    return
  end

  preferences.pakettiColuga.pakettiColugaOutputDirectory.value = output_dir
  preferences.pakettiColuga.pakettiColugaClipLength.value = clip_length
  preferences.pakettiColuga.pakettiColugaLoopMode.value = loop_mode
  preferences.pakettiColuga.pakettiColugaAmountOfVideos.value = tonumber(vb.views.video_amount.value)
  preferences.pakettiColuga.pakettiColugaLoadWholeVideo.value = full_video
  preferences.pakettiColuga.pakettiColugaNewInstrumentOrSameInstrument.value = create_new_instrument
  preferences.pakettiColuga.pakettiColugaFormatToSave.value = vb.views.save_format.value
  preferences.pakettiColuga.pakettiColugaPathToSave.value = save_path
  preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value = vb.views.yt_dlp_location.text

  PakettiColugaLogMessage("Starting process with:")
  PakettiColugaLogMessage("  Search Phrase: " .. tostring(search_phrase))
  PakettiColugaLogMessage("  URL: " .. tostring(youtube_url))
  PakettiColugaLogMessage("  Output Directory: " .. tostring(output_dir))
  PakettiColugaLogMessage("  Clip Length: " .. tostring(clip_length))
  PakettiColugaLogMessage("  Download Full Video: " .. tostring(full_video))
  PakettiColugaLogMessage("  Loop Mode: " .. loop_modes[loop_mode])
  PakettiColugaLogMessage("  Create New Instrument: " .. tostring(create_new_instrument))
  PakettiColugaLogMessage("  Save Format: " .. save_format)
  PakettiColugaLogMessage("  Save to Folder: " .. tostring(save_to_folder))
  PakettiColugaLogMessage("  Save Path: " .. tostring(save_path))
  PakettiColugaLogMessage("  yt-dlp Location: " .. preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value)

  -- Execute the download process
  PakettiColugaExecuteLua(search_phrase, youtube_url, output_dir, clip_length, full_video)
  -- Load the downloaded audio into Renoise
  PakettiColugaLoadVideoAudioIntoRenoise(output_dir, loop_mode, create_new_instrument)
end

-- =====================
-- Dialog Functions
-- =====================

-- Function to create the dialog content
function PakettiColugaDialogContent()
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
              PakettiColugaStartYTDLP()
            end
          end
        },
        vb:row {
          vb:textfield {
            id = "output_dir",
            width = 400,
            text = preferences.pakettiColuga.pakettiColugaOutputDirectory.value
          },
          vb:button { text = "Browse", notifier = PakettiColugaPromptForOutputDir },
        },
        vb:row {
          vb:textfield {
            id = "yt_dlp_location",
            width = 400,
            text = preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value or "<No path set>",
           -- read_only = true
          },
          vb:button { text = "Browse", notifier = PakettiColugaPromptForYTDLPPath },
        },
        vb:valuebox {
          id = "clip_length",
          min = 1,
          max = 60,
          value = preferences.pakettiColuga.pakettiColugaClipLength.value or SAMPLE_LENGTH,
          notifier = function(value)
            preferences.pakettiColuga.pakettiColugaClipLength.value = value
            PakettiColugaLogMessage("Saved Clip Length to " .. value)
          end
        },
        vb:popup {
          id = "loop_mode",
          items = loop_modes,
          value = preferences.pakettiColuga.pakettiColugaLoopMode.value or 2,
          width = 80,
          notifier = function(value)
            preferences.pakettiColuga.pakettiColugaLoopMode.value = value
            PakettiColugaLogMessage("Saved Loop Mode to " .. value)
          end
        },
        vb:valuebox {
          id = "video_amount",
          min = 1,
          max = 100,
          value = preferences.pakettiColuga.pakettiColugaAmountOfVideos.value or 1,
          notifier = function(value)
            preferences.pakettiColuga.pakettiColugaAmountOfVideos.value = value
            PakettiColugaLogMessage("Saved Amount of Videos to " .. value)
          end
        }
      }
    },
    vb:row {
      vb:checkbox {
        id = "full_video",
        value = preferences.pakettiColuga.pakettiColugaLoadWholeVideo.value,
        notifier = function(value)
          preferences.pakettiColuga.pakettiColugaLoadWholeVideo.value = value
          if value then vb.views.clip_length.value = SAMPLE_LENGTH end
          PakettiColugaLogMessage("Saved Load Whole Video to " .. tostring(value))
        end
      },
      vb:text { text = "Download Whole Video as Audio" },
    },
    vb:row {
      vb:checkbox {
        id = "create_new_instrument",
        value = preferences.pakettiColuga.pakettiColugaNewInstrumentOrSameInstrument.value,
        notifier = function(value)
          preferences.pakettiColuga.pakettiColugaNewInstrumentOrSameInstrument.value = value
          PakettiColugaLogMessage("Saved Create New Instrument to " .. tostring(value))
        end
      },
      vb:text { text = "Create New Instrument for Each Downloaded Audio" },
    },
    vb:row { vb:text { text = "Save Successfully Downloaded Audio to Selected Folder" },
      vb:popup {
        id = "save_format",
        items = {"Off", "Save WAV", "Save FLAC"},
        value = preferences.pakettiColuga.pakettiColugaFormatToSave.value or 1,
        width = 120,
        notifier = function(value)
          preferences.pakettiColuga.pakettiColugaFormatToSave.value = value
          if (value == 2 or value == 3) and (vb.views.save_path.text == "<No path set>" or vb.views.save_path.text == "") then
            PakettiColugaPromptForSavePath()
          end
          PakettiColugaLogMessage("Saved Save Format to " .. value)
        end
      },
    },
    vb:row {
      vb:text { text = "Save Path: " },
      vb:text { id = "save_path", text = preferences.pakettiColuga.pakettiColugaPathToSave.value or "<No path set>", font = "bold" },
      vb:button { text = "Browse", notifier = PakettiColugaPromptForSavePath }
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
          if preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value == nil or preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value == "" then
            PakettiColugaPromptForYTDLPPath()
            if preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value == nil or preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value == "" then
              renoise.app():show_warning("Please set the yt-dlp location")
              return
            end
          end
          PakettiColugaStartYTDLP()
        end
      },
      vb:button { text = "Save", notifier = function()
        preferences.pakettiColuga.pakettiColugaOutputDirectory.value = vb.views.output_dir.text
        preferences.pakettiColuga.pakettiColugaClipLength.value = vb.views.clip_length.value
        preferences.pakettiColuga.pakettiColugaLoopMode.value = vb.views.loop_mode.value
        preferences.pakettiColuga.pakettiColugaAmountOfVideos.value = vb.views.video_amount.value
        preferences.pakettiColuga.pakettiColugaLoadWholeVideo.value = vb.views.full_video.value
        preferences.pakettiColuga.pakettiColugaNewInstrumentOrSameInstrument.value = vb.views.create_new_instrument.value
        preferences.pakettiColuga.pakettiColugaFormatToSave.value = vb.views.save_format.value
        preferences.pakettiColuga.pakettiColugaPathToSave.value = vb.views.save_path.text
        preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value = vb.views.yt_dlp_location.text

        PakettiColugaPrintPreferences()
      end },
      vb:button { text = "Save & Close", notifier = function()
        preferences.pakettiColuga.pakettiColugaOutputDirectory.value = vb.views.output_dir.text
        preferences.pakettiColuga.pakettiColugaClipLength.value = vb.views.clip_length.value
        preferences.pakettiColuga.pakettiColugaLoopMode.value = vb.views.loop_mode.value
        preferences.pakettiColuga.pakettiColugaAmountOfVideos.value = vb.views.video_amount.value
        preferences.pakettiColuga.pakettiColugaLoadWholeVideo.value = vb.views.full_video.value
        preferences.pakettiColuga.pakettiColugaNewInstrumentOrSameInstrument.value = vb.views.create_new_instrument.value
        preferences.pakettiColuga.pakettiColugaFormatToSave.value = vb.views.save_format.value
        preferences.pakettiColuga.pakettiColugaPathToSave.value = vb.views.save_path.text
        preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value = vb.views.yt_dlp_location.text

        PakettiColugaPrintPreferences()
        PakettiColugaCloseDialog()
      end }
    }
  }

  -- If yt-dlp location is not set, prompt immediately
  if preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value == nil or preferences.pakettiColuga.pakettiColugaYT_DLPLocation.value == "" then
    PakettiColugaPromptForYTDLPPath()
  end

  return dialog_content
end

-- Key Handler function for the dialog
function PakettiColugaKeyHandlerFunc(dialog, key)
local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    dialog = nil
    return nil
end

  if key.modifiers == "" and key.name == "return" then
    PakettiColugaLogMessage("Enter key pressed, starting process.")
    PakettiColugaStartYTDLP()
  else
    return key
  end
end


function PakettiColugaShowDialog()
  if dialog and dialog.visible then
    PakettiColugaLogMessage("Dialog is visible, closing dialog.")
    PakettiColugaCloseDialog()
  else
    dialog_content = PakettiColugaDialogContent()
    dialog = renoise.app():show_custom_dialog("Paketti YT-DLP Downloader", dialog_content, PakettiColugaKeyHandlerFunc)
    PakettiColugaLogMessage("YT-DLP Downloader Initialized and ready to go.")
  end
end

function PakettiColugaCloseDialog()
  if dialog and dialog.visible then
    dialog:close()
  end
  dialog = nil
  logview = nil  
  vb = nil       
  renoise.app():show_status("Closing Paketti YT-DLP Dialog")
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Xperimental/Work in Progress:Paketti YT-DLP Downloader...", invoke = function() PakettiColugaShowDialog() end }

renoise.tool():add_keybinding { name = "Global:Tools:Paketti YT-DLP Downloader", invoke = PakettiColugaShowDialog }
--renoise.tool():add_menu_entry { name = "Sample Editor:Paketti..:Paketti YT-DLP Downloader...", invoke = PakettiColugaShowDialog }
--renoise.tool():add_menu_entry { name = "Sample Navigator:Paketti..:Paketti YT-DLP Downloader...", invoke = PakettiColugaShowDialog }
--renoise.tool():add_menu_entry { name = "Instrument Box:Paketti..:Paketti YT-DLP Downloader...", invoke = PakettiColugaShowDialog }

