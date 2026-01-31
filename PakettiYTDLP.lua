local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix

-- TODO YT-DLP make it output to GUI Console
-- TODO YT-DLP make sure it finishes downloading


local yt_dlp_path = ""  -- Will be set by PakettiYTDLPSetExecutablePaths() based on OS detection
local ffmpeg_path = ""

-- Helper function to extract string value from observable or convert to string
function PakettiYTDLPGetStringValue(value)
  if type(value) == "userdata" then
    -- Try to get the .value property if it's an observable
    if value.value ~= nil then
      return tostring(value.value)
    end
  end
  return tostring(value)
end

-- Auto-detect yt-dlp executable path by checking multiple known locations
-- Returns the path to the executable if found, or nil if not found
function PakettiYTDLPGuessExecutable()
  print("PakettiYTDLPGuessExecutable: Starting auto-detection...")
  
  local os_name = os.platform()
  local paths_to_check = {}
  
  if os_name == "MACINTOSH" then
    paths_to_check = {
      "/opt/homebrew/bin/yt-dlp",           -- Apple Silicon Homebrew
      "/usr/local/bin/yt-dlp",              -- Intel Mac Homebrew
      "/usr/bin/yt-dlp",                    -- System installation
    }
  elseif os_name == "LINUX" then
    paths_to_check = {
      "/usr/bin/yt-dlp",                        -- System-wide installation (most common)
      "/usr/local/bin/yt-dlp",                  -- Local installation
      "/home/linuxbrew/.linuxbrew/bin/yt-dlp",  -- Linux Homebrew path
      "/snap/bin/yt-dlp",                       -- Snap installation
    }
  elseif os_name == "WINDOWS" then
    paths_to_check = {
      "C:\\Program Files\\yt-dlp\\yt-dlp.exe",
      "C:\\Program Files (x86)\\yt-dlp\\yt-dlp.exe",
    }
  end
  
  -- Check each path
  for _, path in ipairs(paths_to_check) do
    print("PakettiYTDLPGuessExecutable: Checking path: " .. path)
    local f = io.open(path, "r")
    if f then
      io.close(f)
      print("PakettiYTDLPGuessExecutable: Found yt-dlp at: " .. path)
      return path
    end
  end
  
  -- If not found in known paths, try using 'which' command on Unix systems
  if os_name ~= "WINDOWS" then
    print("PakettiYTDLPGuessExecutable: Trying 'which' command...")
    local cmd = "which yt-dlp"
    print("PakettiYTDLPGuessExecutable: Running: " .. cmd)
    local handle = io.popen(cmd)
    if handle then
      local result = handle:read("*line")
      handle:close()
      if result and result ~= "" then
        -- Trim whitespace
        result = result:match("^%s*(.-)%s*$")
        if result ~= "" then
          -- Verify the path exists
          local f = io.open(result, "r")
          if f then
            io.close(f)
            print("PakettiYTDLPGuessExecutable: Found via 'which': " .. result)
            return result
          end
        end
      end
    end
  end
  
  print("PakettiYTDLPGuessExecutable: No yt-dlp executable found")
  return nil
end

-- Auto-detect ffmpeg executable path by checking multiple known locations
-- Returns the path to the executable if found, or nil if not found
function PakettiYTDLPGuessFFmpeg()
  print("PakettiYTDLPGuessFFmpeg: Starting auto-detection...")
  
  local os_name = os.platform()
  local paths_to_check = {}
  
  if os_name == "MACINTOSH" then
    paths_to_check = {
      "/opt/homebrew/bin/ffmpeg",           -- Apple Silicon Homebrew
      "/usr/local/bin/ffmpeg",              -- Intel Mac Homebrew
      "/usr/bin/ffmpeg",                    -- System installation
    }
  elseif os_name == "LINUX" then
    paths_to_check = {
      "/usr/bin/ffmpeg",                        -- System-wide installation (most common)
      "/usr/local/bin/ffmpeg",                  -- Local installation
      "/home/linuxbrew/.linuxbrew/bin/ffmpeg",  -- Linux Homebrew path
    }
  elseif os_name == "WINDOWS" then
    paths_to_check = {
      "C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe",
      "C:\\Program Files (x86)\\ffmpeg\\bin\\ffmpeg.exe",
    }
  end
  
  -- Check each path
  for _, path in ipairs(paths_to_check) do
    print("PakettiYTDLPGuessFFmpeg: Checking path: " .. path)
    local f = io.open(path, "r")
    if f then
      io.close(f)
      print("PakettiYTDLPGuessFFmpeg: Found ffmpeg at: " .. path)
      return path
    end
  end
  
  -- If not found in known paths, try using 'which' command on Unix systems
  if os_name ~= "WINDOWS" then
    print("PakettiYTDLPGuessFFmpeg: Trying 'which' command...")
    local cmd = "which ffmpeg"
    print("PakettiYTDLPGuessFFmpeg: Running: " .. cmd)
    local handle = io.popen(cmd)
    if handle then
      local result = handle:read("*line")
      handle:close()
      if result and result ~= "" then
        -- Trim whitespace
        result = result:match("^%s*(.-)%s*$")
        if result ~= "" then
          -- Verify the path exists
          local f = io.open(result, "r")
          if f then
            io.close(f)
            print("PakettiYTDLPGuessFFmpeg: Found via 'which': " .. result)
            return result
          end
        end
      end
    end
  end
  
  print("PakettiYTDLPGuessFFmpeg: No ffmpeg executable found")
  return nil
end

-- Show installation instructions dialog for yt-dlp and ffmpeg
function PakettiYTDLPShowInstallDialog()
  print("PakettiYTDLPShowInstallDialog: Showing installation instructions...")
  
  local install_vb = renoise.ViewBuilder()
  local install_dialog = nil
  local os_name = os.platform()
  
  local dialog_content
  
  if os_name == "MACINTOSH" then
    dialog_content = install_vb:column{
      margin = 10,
      spacing = 8,
      
      install_vb:text{
        text = "yt-dlp and/or ffmpeg are not installed on your system.",
        font = "bold",
      },
      
      install_vb:space{height = 5},
      
      install_vb:text{
        text = "To install these tools on macOS, you need Homebrew package manager.",
      },
      
      install_vb:space{height = 10},
      
      install_vb:text{
        text = "Step 1: Install Homebrew (if not already installed)",
        font = "bold",
      },
      install_vb:text{
        text = "Open Terminal and paste this command:",
      },
      install_vb:textfield{
        width = 550,
        text = '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
        edit_mode = true,
      },
      
      install_vb:space{height = 10},
      
      install_vb:text{
        text = "Step 2: Install yt-dlp",
        font = "bold",
      },
      install_vb:text{
        text = "After Homebrew is installed, run this command:",
      },
      install_vb:textfield{
        width = 550,
        text = "brew install yt-dlp",
        edit_mode = true,
      },
      
      install_vb:space{height = 10},
      
      install_vb:text{
        text = "Step 3: Install ffmpeg (required for audio extraction)",
        font = "bold",
      },
      install_vb:textfield{
        width = 550,
        text = "brew install ffmpeg",
        edit_mode = true,
      },
      
      install_vb:space{height = 10},
      
      install_vb:text{
        text = "After installation, click 'Detect Again' or manually browse for the executable.",
      },
      
      install_vb:space{height = 10},
      
      install_vb:row{
        spacing = 10,
        install_vb:button{
          text = "Detect Again",
          width = 120,
          notifier = function()
            if install_dialog then
              install_dialog:close()
            end
            -- Try to detect again
            local detected_path = PakettiYTDLPGuessExecutable()
            if detected_path then
              yt_dlp_path = detected_path
              preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = detected_path
              renoise.app():show_status("yt-dlp found at: " .. detected_path)
              -- Also detect ffmpeg
              local ffmpeg_detected = PakettiYTDLPGuessFFmpeg()
              if ffmpeg_detected then
                ffmpeg_path = ffmpeg_detected
                renoise.app():show_status("yt-dlp and ffmpeg found!")
              end
            else
              renoise.app():show_error("yt-dlp still not found. Please install it first.")
            end
          end
        },
        install_vb:button{
          text = "Browse for yt-dlp...",
          width = 140,
          notifier = function()
            if install_dialog then
              install_dialog:close()
            end
            local filename = renoise.app():prompt_for_filename_to_read({"*.*"}, "Select yt-dlp Executable")
            if filename ~= "" then
              yt_dlp_path = filename
              preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = filename
              renoise.app():show_status("yt-dlp path set to: " .. filename)
            end
          end
        },
        install_vb:button{
          text = "Close",
          width = 120,
          notifier = function()
            if install_dialog then
              install_dialog:close()
            end
          end
        },
      },
    }
  elseif os_name == "LINUX" then
    dialog_content = install_vb:column{
      margin = 10,
      spacing = 8,
      
      install_vb:text{
        text = "yt-dlp and/or ffmpeg are not installed on your system.",
        font = "bold",
      },
      
      install_vb:space{height = 5},
      
      install_vb:text{
        text = "To install these tools on Linux, use your package manager:",
      },
      
      install_vb:space{height = 5},
      
      install_vb:text{
        text = "Debian/Ubuntu:",
        font = "bold",
      },
      install_vb:textfield{
        width = 450,
        text = "sudo apt install yt-dlp ffmpeg",
        edit_mode = true,
      },
      
      install_vb:text{
        text = "Fedora:",
        font = "bold",
      },
      install_vb:textfield{
        width = 450,
        text = "sudo dnf install yt-dlp ffmpeg",
        edit_mode = true,
      },
      
      install_vb:text{
        text = "Arch Linux:",
        font = "bold",
      },
      install_vb:textfield{
        width = 450,
        text = "sudo pacman -S yt-dlp ffmpeg",
        edit_mode = true,
      },
      
      install_vb:text{
        text = "Or using pip (if package manager version is outdated):",
        font = "bold",
      },
      install_vb:textfield{
        width = 450,
        text = "pip install yt-dlp",
        edit_mode = true,
      },
      
      install_vb:space{height = 10},
      
      install_vb:row{
        spacing = 10,
        install_vb:button{
          text = "Detect Again",
          width = 120,
          notifier = function()
            if install_dialog then
              install_dialog:close()
            end
            local detected_path = PakettiYTDLPGuessExecutable()
            if detected_path then
              yt_dlp_path = detected_path
              preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = detected_path
              renoise.app():show_status("yt-dlp found at: " .. detected_path)
              local ffmpeg_detected = PakettiYTDLPGuessFFmpeg()
              if ffmpeg_detected then
                ffmpeg_path = ffmpeg_detected
                renoise.app():show_status("yt-dlp and ffmpeg found!")
              end
            else
              renoise.app():show_error("yt-dlp still not found. Please install it first.")
            end
          end
        },
        install_vb:button{
          text = "Browse for yt-dlp...",
          width = 140,
          notifier = function()
            if install_dialog then
              install_dialog:close()
            end
            local filename = renoise.app():prompt_for_filename_to_read({"*.*"}, "Select yt-dlp Executable")
            if filename ~= "" then
              yt_dlp_path = filename
              preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = filename
              renoise.app():show_status("yt-dlp path set to: " .. filename)
            end
          end
        },
        install_vb:button{
          text = "Close",
          width = 120,
          notifier = function()
            if install_dialog then
              install_dialog:close()
            end
          end
        },
      },
    }
  else
    -- Windows
    dialog_content = install_vb:column{
      margin = 10,
      spacing = 8,
      
      install_vb:text{
        text = "yt-dlp and/or ffmpeg are not installed on your system.",
        font = "bold",
      },
      
      install_vb:space{height = 5},
      
      install_vb:text{
        text = "To install these tools on Windows:",
      },
      
      install_vb:text{
        text = "1. Download yt-dlp from: https://github.com/yt-dlp/yt-dlp/releases",
      },
      install_vb:text{
        text = "2. Download ffmpeg from: https://ffmpeg.org/download.html",
      },
      install_vb:text{
        text = "3. Place the executables in your PATH or select them manually",
      },
      
      install_vb:space{height = 10},
      
      install_vb:row{
        spacing = 10,
        install_vb:button{
          text = "Open yt-dlp Download Page",
          width = 180,
          notifier = function()
            renoise.app():open_url("https://github.com/yt-dlp/yt-dlp/releases")
          end
        },
        install_vb:button{
          text = "Open ffmpeg Download Page",
          width = 180,
          notifier = function()
            renoise.app():open_url("https://ffmpeg.org/download.html")
          end
        },
      },
      
      install_vb:space{height = 10},
      
      install_vb:row{
        spacing = 10,
        install_vb:button{
          text = "Detect Again",
          width = 120,
          notifier = function()
            if install_dialog then
              install_dialog:close()
            end
            local detected_path = PakettiYTDLPGuessExecutable()
            if detected_path then
              yt_dlp_path = detected_path
              preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = detected_path
              renoise.app():show_status("yt-dlp found at: " .. detected_path)
              local ffmpeg_detected = PakettiYTDLPGuessFFmpeg()
              if ffmpeg_detected then
                ffmpeg_path = ffmpeg_detected
                renoise.app():show_status("yt-dlp and ffmpeg found!")
              end
            else
              renoise.app():show_error("yt-dlp still not found. Please install it first.")
            end
          end
        },
        install_vb:button{
          text = "Browse for yt-dlp...",
          width = 140,
          notifier = function()
            if install_dialog then
              install_dialog:close()
            end
            local filename = renoise.app():prompt_for_filename_to_read({"*.exe"}, "Select yt-dlp Executable")
            if filename ~= "" then
              yt_dlp_path = filename
              preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = filename
              renoise.app():show_status("yt-dlp path set to: " .. filename)
            end
          end
        },
        install_vb:button{
          text = "Close",
          width = 120,
          notifier = function()
            if install_dialog then
              install_dialog:close()
            end
          end
        },
      },
    }
  end
  
  install_dialog = renoise.app():show_custom_dialog("yt-dlp Installation Required", dialog_content)
end
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
local error_already_logged = false
local last_progress_message = ""

-- Function to get PATH environment string based on OS
function PakettiYTDLPGetPathEnv()
  local os_name = os.platform()
  if os_name == "MACINTOSH" then
    return "env PATH=/opt/homebrew/bin:$PATH "
  elseif os_name == "LINUX" then
    return ""  -- Use system PATH, no need to modify for Linux
  else
    return ""
  end
end

-- Function to detect the operating system and assign paths
-- Returns true if yt-dlp was found, false otherwise
function PakettiYTDLPSetExecutablePaths(show_install_dialog_if_not_found)
  print("PakettiYTDLPSetExecutablePaths: Starting...")
  
  -- Default to showing install dialog if not specified
  if show_install_dialog_if_not_found == nil then
    show_install_dialog_if_not_found = false
  end
  
  local os_name = os.platform()
  
  -- First check if path is already set in preferences
  local saved_path = PakettiYTDLPGetStringValue(preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value)
  print("PakettiYTDLPSetExecutablePaths: Saved path from preferences: " .. tostring(saved_path))
  
  -- Clear preferences if they contain wrong OS-specific paths
  if os_name == "LINUX" and saved_path and saved_path:match("^/opt/homebrew/") then
    print("PakettiYTDLPSetExecutablePaths: Clearing macOS path from Linux system preferences")
    saved_path = ""
    preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = ""
  elseif os_name == "MACINTOSH" and saved_path and saved_path:match("^/usr/bin/") then
    print("PakettiYTDLPSetExecutablePaths: Clearing Linux path from macOS system preferences")
    saved_path = ""
    preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = ""
  end
  
  -- If saved path is valid, use it
  if saved_path and saved_path ~= "" then
    local file = io.open(saved_path, "r")
    if file then
      file:close()
      yt_dlp_path = saved_path
      print("PakettiYTDLPSetExecutablePaths: Using saved path: " .. yt_dlp_path)
    else
      -- Saved path is invalid, clear it and try auto-detection
      print("PakettiYTDLPSetExecutablePaths: Saved path invalid, trying auto-detection...")
      saved_path = ""
    end
  end
  
  -- If not set in preferences or invalid, try to find it automatically
  if saved_path == nil or saved_path == "" then
    print("PakettiYTDLPSetExecutablePaths: Attempting auto-detection...")
    local detected_path = PakettiYTDLPGuessExecutable()
    
    if detected_path then
      yt_dlp_path = detected_path
      -- Save to preferences
      preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = detected_path
      print("PakettiYTDLPSetExecutablePaths: Auto-detected and saved: " .. detected_path)
      renoise.app():show_status("yt-dlp auto-detected at: " .. detected_path)
    else
      print("PakettiYTDLPSetExecutablePaths: Auto-detection failed")
      yt_dlp_path = ""
    end
  end
  
  -- If we still don't have a path, show install dialog or return false
  if not yt_dlp_path or yt_dlp_path == "" then
    print("PakettiYTDLPSetExecutablePaths: yt-dlp not found")
    if show_install_dialog_if_not_found then
      PakettiYTDLPShowInstallDialog()
    end
    return false
  end
  
  -- Final verification that the path actually exists and is executable
  local file = io.open(yt_dlp_path, "r")
  if file then
    file:close()
    print("PakettiYTDLPSetExecutablePaths: Using yt-dlp path: " .. yt_dlp_path)
    print("PakettiYTDLPSetExecutablePaths: Running on OS: " .. os_name)
    
    -- Test if yt-dlp is actually working
    local test_command = string.format('%s"%s" --version', PakettiYTDLPGetPathEnv(), yt_dlp_path)
    local test_handle = io.popen(test_command)
    if test_handle then
      local version_output = test_handle:read("*a")
      test_handle:close()
      if version_output and version_output ~= "" then
        print("PakettiYTDLPSetExecutablePaths: yt-dlp version check successful")
      else
        print("PakettiYTDLPSetExecutablePaths: WARNING - yt-dlp version check failed")
      end
    end
  else
    print("PakettiYTDLPSetExecutablePaths: ERROR - yt-dlp not found at: " .. yt_dlp_path)
    if show_install_dialog_if_not_found then
      PakettiYTDLPShowInstallDialog()
    end
    return false
  end
  
  -- Now detect ffmpeg using the new function
  print("PakettiYTDLPSetExecutablePaths: Detecting ffmpeg...")
  local detected_ffmpeg = PakettiYTDLPGuessFFmpeg()
  if detected_ffmpeg then
    ffmpeg_path = detected_ffmpeg
    print("PakettiYTDLPSetExecutablePaths: Found ffmpeg at: " .. ffmpeg_path)
  else
    -- Set a default fallback based on OS
    if os_name == "MACINTOSH" then
      ffmpeg_path = "/opt/homebrew/bin/ffmpeg"
    elseif os_name == "LINUX" then
      ffmpeg_path = "/usr/bin/ffmpeg"
    elseif os_name == "WINDOWS" then
      ffmpeg_path = "ffmpeg.exe"
    end
    print("PakettiYTDLPSetExecutablePaths: ffmpeg not found, using default: " .. ffmpeg_path)
  end
  
  return true
end


-- Function to log messages to the multiline textfield
function PakettiYTDLPLogMessage(message)
  if not logview then return end
  if not message or message == "" then return end
  
  -- Filter duplicate progress messages
  if message:match("^%[download%].*%%") then
    -- This is a download progress line - only show if different from last
    if message == last_progress_message then
      return -- Skip duplicate
    end
    last_progress_message = message
  end
  
  -- Show only essential output - no debug noise
  if message:match("^%[download%].*%%") or     -- Download progress with percentage
     message:match("^ERROR:") or               -- Errors
     message:match("^WARNING:.*Skipping") or   -- Format skip warnings
     message:match("^Downloading full video") or -- Clean start message
     message:match("^%[ExtractAudio%]") or     -- Audio extraction
     message:match("^%[info%].*available formats") then -- Format info
    
    logview.text = logview.text .. message .. "\n"
    
    -- Auto-scroll to bottom to show latest progress
    logview:scroll_to_last_line()
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
  -- Handle userdata (observable) objects
  path = PakettiYTDLPGetStringValue(path)
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
    -- Update status text based on output with improved pattern matching
    if status_text then
      -- Match various download progress patterns
      local percent = output:match("([%d%.]+)%%")
      local eta = output:match("ETA (%d+:%d+)")
      local speed = output:match("at%s+([%d%.]+[KMG]?iB/s)")
      
      if percent and eta and speed then
        status_text.text = string.format("Downloading: %s%% - %s at %s", percent, eta, speed)
      elseif percent and eta then
        status_text.text = string.format("Downloading: %s%% - ETA %s", percent, eta)
      elseif percent then
        status_text.text = "Downloading: " .. percent .. "%"
      elseif output:match("^%[ExtractAudio%]") then
        status_text.text = "Extracting Audio..."
      elseif output:match("^%[hlsnative%]") then
        status_text.text = "Processing stream..."
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
      status_text.text="Ready"
    end
    if cancel_button then
      cancel_button.active = false
    end
    
    -- Now create the completion signal since download actually finished
    local output_dir = preferences.PakettiYTDLP.PakettiYTDLPOutputDirectory.value
    if output_dir then
      local completion_file = output_dir .. separator .. "tempfolder" .. separator .. "download_completed.txt"
      local file = io.open(completion_file, "w")
      if file then
        file:close()
        PakettiYTDLPLogMessage("Download completed")
      end
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
      status_text.text="Failed to start process"
    end
    return false
  end
  
  process_running = true
  if status_text then
    status_text.text="Processing..."
  end
  if cancel_button then
    cancel_button.active = true
  end
  process_timer = renoise.tool():add_timer(PakettiYTDLPProcessSlice, 200) -- Check every 200ms (reduced frequency with --newline flag)
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

-- Function to sanitize and fix common URL issues
function PakettiYTDLPSanitizeURL(url)
  if not url or url == "" then
    return url
  end
  
  -- Fix missing 'h' at the start of https URLs
  if url:match("^ttps://") then
    url = "h" .. url
    PakettiYTDLPLogMessage("DEBUG: Fixed URL missing 'h' prefix: " .. url)
  elseif url:match("^ttp://") then
    url = "h" .. url
    PakettiYTDLPLogMessage("DEBUG: Fixed URL missing 'h' prefix: " .. url)
  end
  
  return url
end

-- Function to convert time string to seconds
function PakettiYTDLPTimeToSeconds(time_str)
  if not time_str then return nil end
  
  -- Remove trailing 's' if present
  time_str = time_str:gsub("s$", "")
  
  -- Check for minutes and seconds format (2m30s or 2m30)
  local minutes, seconds = time_str:match("(%d+)m(%d*)")
  if minutes then
    local total = tonumber(minutes) * 60
    if seconds and seconds ~= "" then
      total = total + tonumber(seconds)
    end
    return total
  end
  
  -- Check for hours, minutes, seconds format (1h2m30s or 1h2m30)
  local hours, minutes, seconds = time_str:match("(%d+)h(%d*)m?(%d*)")
  if hours then
    local total = tonumber(hours) * 3600
    if minutes and minutes ~= "" then
      total = total + tonumber(minutes) * 60
    end
    if seconds and seconds ~= "" then
      total = total + tonumber(seconds)
    end
    return total
  end
  
  -- Just plain seconds
  local plain_seconds = tonumber(time_str)
  if plain_seconds then
    return plain_seconds
  end
  
  return nil
end

-- Function to detect timestamps in URL
function PakettiYTDLPDetectTimestamps(url)
  if not url or url == "" then
    PakettiYTDLPLogMessage("DEBUG: No URL provided for timestamp detection")
    return nil
  end
  
  PakettiYTDLPLogMessage("DEBUG: Checking URL for timestamps: " .. url)
  
  -- Check for t= parameter - more comprehensive patterns
  -- Handles: ?t=47, &t=45s, ?t=2m30s, etc.
  local t_param = nil
  
  -- Try ?t= pattern first (youtu.be format)
  t_param = url:match("%?t=([^&]+)")
  if t_param then
    PakettiYTDLPLogMessage("DEBUG: Found ?t= pattern: t=" .. t_param)
  else
    -- Try &t= pattern (full youtube.com URLs)
    t_param = url:match("&t=([^&]+)")
    if t_param then
      PakettiYTDLPLogMessage("DEBUG: Found &t= pattern: t=" .. t_param)
    end
  end
  
  if t_param then
    PakettiYTDLPLogMessage("DEBUG: Detected timestamp parameter: t=" .. t_param)
    local start_seconds = PakettiYTDLPTimeToSeconds(t_param)
    if start_seconds then
      PakettiYTDLPLogMessage("DEBUG: Parsed start time: " .. start_seconds .. " seconds")
      local section_param = "*" .. start_seconds .. "-inf"
      PakettiYTDLPLogMessage("DEBUG: Will use download section: " .. section_param)
      return section_param
    else
      PakettiYTDLPLogMessage("DEBUG: Could not parse timestamp, falling back to *from-url")
      return "*from-url"
    end
  end
  
  -- Check for #t= fragment (like #t=120, #t=2m30s)
  local t_fragment = url:match("#t=([^&]+)")
  if t_fragment then
    PakettiYTDLPLogMessage("DEBUG: Detected timestamp fragment: #t=" .. t_fragment)
    local start_seconds = PakettiYTDLPTimeToSeconds(t_fragment)
    if start_seconds then
      PakettiYTDLPLogMessage("DEBUG: Parsed start time: " .. start_seconds .. " seconds")
      local section_param = "*" .. start_seconds .. "-inf"
      PakettiYTDLPLogMessage("DEBUG: Will use download section: " .. section_param)
      return section_param
    else
      PakettiYTDLPLogMessage("DEBUG: Could not parse timestamp, falling back to *from-url")
      return "*from-url"
    end
  end
  
  PakettiYTDLPLogMessage("DEBUG: No timestamps detected in URL")
  return nil
end

-- Function to detect if video has chapters and extract chapter info
function PakettiYTDLPDetectChapters(url)
  if not url or url == "" then
    return false, nil
  end
  
  PakettiYTDLPLogMessage("Checking for chapters in video...")
  
  -- Use yt-dlp to get video info and check for chapters
  local info_command = string.format('%s"%s" --dump-json --no-warnings "%s"', PakettiYTDLPGetPathEnv(), yt_dlp_path, url)
  local handle = io.popen(info_command)
  if not handle then
    PakettiYTDLPLogMessage("Failed to check for chapters")
    return false, nil
  end
  
  local json_output = handle:read("*a")
  handle:close()
  
  -- Simple check for chapters in JSON output
  if json_output and json_output:match('"chapters":%s*%[') and not json_output:match('"chapters":%s*%[%s*%]') then
    PakettiYTDLPLogMessage("Video has chapters detected!")
    
    -- Extract the first chapter title for downloading
    local first_chapter = nil
    local chapter_count = 0
    for title in json_output:gmatch('"title"%s*:%s*"([^"]*)"') do
      chapter_count = chapter_count + 1
      if chapter_count == 1 then
        first_chapter = title
        PakettiYTDLPLogMessage("  First chapter: " .. title)
      elseif chapter_count <= 3 then -- Only log first 3 chapters to avoid spam
        PakettiYTDLPLogMessage("  Chapter found: " .. title)
      end
    end
    
    if chapter_count > 3 then
      PakettiYTDLPLogMessage("  ... and " .. (chapter_count - 3) .. " more chapters")
    end
    
    return true, first_chapter
  end
  
  PakettiYTDLPLogMessage("No chapters found in video")
  return false, nil
end

-- Function to get a random URL from yt-dlp search
function PakettiYTDLPGetRandomUrl(search_phrase, search_results_file)
  PakettiYTDLPLogMessage("Searching for term \"" .. search_phrase .. "\"")
  
  local command = string.format('%s"%s" "ytsearch30:%s" --get-id --no-warnings', PakettiYTDLPGetPathEnv(), yt_dlp_path, search_phrase)
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

  -- Show clean start message
  PakettiYTDLPLogMessage("Downloading full video of " .. selected_url)

  -- Execute your simple working yt-dlp command directly
  local yt_dlp_cmd = string.format(
    'cd "%s" && %s"%s" --extract-audio --audio-format wav "%s"',
    temp_dir,
    PakettiYTDLPGetPathEnv(),
    yt_dlp_path,
    selected_url
  )
  
  if not PakettiYTDLPExecuteCommand(yt_dlp_cmd) then
    PakettiYTDLPLogMessage("ERROR: Download failed")
    return
  end

  -- Sanitize filenames and record them
  PakettiYTDLPSanitizeFilenames(temp_dir, filenames_file)

  -- Signal completion
  PakettiYTDLPSignalCompletion(completion_signal_file)

  PakettiYTDLPLogMessage("Paketti YT-DLP finished.")
end

-- Global variables for async sample loading
local async_sample_loading_timer = nil
local async_loading_state = nil

-- Function to load one sample at a time asynchronously  
function PakettiYTDLPAsyncSampleLoader()
  if not async_loading_state then return end
  
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local state = async_loading_state
  local current_index = state.current_index
  local sample_files = state.sample_files
  local instrument = state.instrument
  local loop_mode = state.loop_mode
  local download_dir = state.download_dir
  
  if current_index > #sample_files then
    -- All samples loaded, clean up
    if async_sample_loading_timer and renoise.tool():has_timer(async_sample_loading_timer) then
      renoise.tool():remove_timer(async_sample_loading_timer)
    end
    async_sample_loading_timer = nil
    async_loading_state = nil
    
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
    
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end
  
  -- Load current sample
  local file = sample_files[current_index]
  PakettiYTDLPLogMessage("Loading sample " .. current_index .. "/" .. #sample_files .. ": " .. file)
  
  local sample = instrument:insert_sample_at(1)
  if sample then
    local buffer = sample.sample_buffer
    if buffer then
      -- Load the sample
      if buffer:load_from(file) then
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
  
  -- Move to next sample
  async_loading_state.current_index = current_index + 1
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Function to start async sample loading
function PakettiYTDLPStartAsyncSampleLoading(sample_files, instrument, loop_mode, download_dir)
  if #sample_files == 0 then
    PakettiYTDLPLogMessage("No samples to load")
    return
  end
  
  -- Set up loading state
  async_loading_state = {
    current_index = 1,
    sample_files = sample_files,
    instrument = instrument,
    loop_mode = loop_mode,
    download_dir = download_dir
  }
  
  -- Clean up any existing timer
  if async_sample_loading_timer and renoise.tool():has_timer(async_sample_loading_timer) then
    renoise.tool():remove_timer(async_sample_loading_timer)
  end
  
  -- Start timer to load samples one by one
  async_sample_loading_timer = PakettiYTDLPAsyncSampleLoader
  renoise.tool():add_timer(async_sample_loading_timer, 200) -- 200ms delay between samples
  
  PakettiYTDLPLogMessage("Started async loading of " .. #sample_files .. " sample(s)")
end

-- Function to load downloaded samples into Renoise
function PakettiYTDLPLoadVideoAudioIntoRenoise(download_dir, loop_mode, create_new_instrument)
  local temp_dir = download_dir .. separator .. "tempfolder"
  local completion_signal_file = temp_dir .. separator .. "download_completed.txt"
  local filenames_file = temp_dir .. separator .. "filenames.txt"

  PakettiYTDLPLogMessage("=== Starting Renoise import process ===")
  PakettiYTDLPLogMessage("Checking completion signal file: " .. completion_signal_file)

  -- Check if completion signal file already exists (should be there since timer called us)
  if PakettiYTDLPFileExists(completion_signal_file) then
    PakettiYTDLPLogMessage("Completion signal file detected")
    -- CRITICAL: Remove completion signal file immediately to prevent repeated processing
    os.remove(completion_signal_file)
    PakettiYTDLPLogMessage("Removed completion signal file to prevent duplicate processing")
  else
    PakettiYTDLPLogMessage("WARNING: Completion signal not found, checking for files anyway...")
  end

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
    if not error_already_logged then
      PakettiYTDLPLogMessage("ERROR: No WAV files found in " .. temp_dir)
      error_already_logged = true
    end
    return
  end

  PakettiYTDLPLogMessage("Found " .. #sample_files .. " WAV file(s) to import")

  -- Simple file existence check (files should be ready since process completed)
  for _, file in ipairs(sample_files) do
    local f = io.open(file, "rb")
    if f then
      f:close()
      PakettiYTDLPLogMessage("File is ready: " .. file)
    else
      PakettiYTDLPLogMessage("WARNING: File not accessible: " .. file)
    end
  end

  local song=renoise.song()
  local selected_instrument_index = song.selected_instrument_index

  if create_new_instrument then
    selected_instrument_index = selected_instrument_index + 1
    if not safeInsertInstrumentAt(song, selected_instrument_index) then return end
    song.selected_instrument_index = selected_instrument_index
    pakettiPreferencesDefaultInstrumentLoader()
    PakettiYTDLPLogMessage("Created new instrument at index: " .. selected_instrument_index)
  end

  local instrument = song.instruments[selected_instrument_index]
  if not instrument then
    PakettiYTDLPLogMessage("ERROR: Failed to get instrument at index: " .. selected_instrument_index)
    return
  end

  -- Start async sample loading process (will handle file moving and completion)
  PakettiYTDLPStartAsyncSampleLoading(sample_files, instrument, loop_mode, download_dir)
end

-- Function to browse for output directory (direct, no warning)
function PakettiYTDLPBrowseForOutputDir()
  local dir = renoise.app():prompt_for_path("Set YT-DLP File Save Output Directory")
  if dir then
    vb.views.output_dir.text = dir
    preferences.PakettiYTDLP.PakettiYTDLPOutputDirectory.value = dir
    PakettiYTDLPLogMessage("Saved Output Directory to " .. dir)
  end
end

-- Function to prompt for output directory (with warning, used when starting download with no path)
function PakettiYTDLPPromptForOutputDir()
  renoise.app():show_warning("Please set the folder that YT-DLP will download to...")
  local dir = renoise.app():prompt_for_path("Set YT-DLP File Save Output Directory")
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
  -- Ensure paths are set up (backup in case called from other places)
  if yt_dlp_path == "" then
    PakettiYTDLPSetExecutablePaths()
  end
  
  -- Define paths for our tracking files
  local temp_dir = output_dir .. separator .. "tempfolder"
  local search_results_file = temp_dir .. separator .. "search_results.txt"
  local filenames_file = temp_dir .. separator .. "filenames.txt"
  
  -- Clear the files at start
  PakettiYTDLPClearFile(search_results_file)
  PakettiYTDLPClearFile(filenames_file)
  
  local command
  -- ProcessSlicer function now only handles search (direct URLs are handled outside ProcessSlicer)
  if not search_phrase or search_phrase == "" then
    PakettiYTDLPLogMessage("ERROR: ProcessSlicer called without search phrase")
    return
  end
  
  -- Search command - do this with slicing for UI responsiveness
  -- Update the log BEFORE starting the search
  logview.text="=== Starting search for term: \"" .. search_phrase .. "\" ===\n"
  local search_command = string.format('%s"%s" "ytsearch30:%s" --get-id --no-warnings', PakettiYTDLPGetPathEnv(), yt_dlp_path, search_phrase)
  local handle = io.popen(search_command)
  if not handle then
    PakettiYTDLPLogMessage("ERROR: Failed to start search")
    return
  end
  
  -- Read all results with yielding for UI responsiveness
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
  
  -- Execute download for selected URL
  local yt_dlp_cmd = string.format(
    'cd "%s" && %s"%s" --extract-audio --audio-format wav "%s"',
    temp_dir,
    PakettiYTDLPGetPathEnv(),
    yt_dlp_path,
    command
  )
  
  if not PakettiYTDLPExecuteCommand(yt_dlp_cmd) then
    PakettiYTDLPLogMessage("ERROR: Download failed")
    return
  end
  
  -- Return here - download is now running asynchronously  
  -- File listing and completion signal will be handled by the process timer when download completes
end

-- Modify StartYTDLP to properly handle timers
function PakettiYTDLPStartYTDLP()
  -- Reset flags for new download
  error_already_logged = false
  last_progress_message = ""
  -- Set up executable paths based on OS detection
  PakettiYTDLPSetExecutablePaths()
  local search_phrase = vb.views.search_phrase.text
  local youtube_url = vb.views.youtube_url.text
  local output_dir = vb.views.output_dir.text
  
  -- Sanitize URL to fix common issues like missing 'h' prefix
  local original_url = youtube_url
  youtube_url = PakettiYTDLPSanitizeURL(youtube_url)
  
  -- Update the text field if URL was corrected
  if original_url ~= youtube_url and vb.views.youtube_url then
    vb.views.youtube_url.text = youtube_url
  end
  
  
  if (search_phrase == "" or search_phrase == nil) and (youtube_url == "" or youtube_url == nil) then
    renoise.app():show_warning("Please set URL or search term")
    return
  end
  
  if output_dir == "" or output_dir == "Set this yourself, please." then
    PakettiYTDLPPromptForOutputDir()
    return
  end
  
  -- Check if save format requires save path
  local save_format = vb.views.save_format.value
  local save_path = vb.views.save_path.text
  if (save_format == 2 or save_format == 3) and (save_path == "<No path set>" or save_path == "" or save_path == nil) then
    PakettiYTDLPPromptForSavePath()
    -- Continue with download after setting save path
    save_path = vb.views.save_path.text
    if save_path == "<No path set>" or save_path == "" or save_path == nil then
      -- User cancelled save path selection, abort
      return
    end
  end
  
  -- Save all preferences
  preferences.PakettiYTDLP.PakettiYTDLPOutputDirectory.value = output_dir
  -- preferences.PakettiYTDLP.PakettiYTDLPClipLength.value = tonumber(vb.views.clip_length.value)  -- COMMENTED: No longer used
  preferences.PakettiYTDLP.PakettiYTDLPLoopMode.value = tonumber(vb.views.loop_mode.value)
  preferences.PakettiYTDLP.PakettiYTDLPAmountOfVideos.value = tonumber(vb.views.video_amount.value)
  -- preferences.PakettiYTDLP.PakettiYTDLPLoadWholeVideo.value = vb.views.full_video.value  -- COMMENTED: Always full video now
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
  
  -- For direct URLs, skip ProcessSlicer and download directly
  if youtube_url and youtube_url ~= "" then
    -- Direct download without ProcessSlicer (which was causing UI freezing)
    local temp_dir = output_dir .. separator .. "tempfolder"
    PakettiYTDLPCreateDir(temp_dir)
    
    -- Show clean start message
    PakettiYTDLPLogMessage("Downloading full video of " .. youtube_url)
    
    -- Execute your simple working yt-dlp command directly
    local yt_dlp_cmd = string.format(
      'cd "%s" && %s"%s" --extract-audio --audio-format wav "%s"',
      temp_dir,
      PakettiYTDLPGetPathEnv(),
      yt_dlp_path,
      youtube_url
    )
    
    if not PakettiYTDLPExecuteCommand(yt_dlp_cmd) then
      PakettiYTDLPLogMessage("ERROR: Download failed")
      return
    end
    
    -- Download is now running with timer-based progress updates
  else
    -- For search terms, use ProcessSlicer (needed for the search process)
    if process_slicer and process_slicer:running() then
      process_slicer:stop()
    end
    
    process_slicer = ProcessSlicer(PakettiYTDLPSlicedProcess, 
      search_phrase, 
      youtube_url, 
      output_dir, 
      15, -- Default clip length (not used but needed for function signature)
      true -- Always full video
    )
    
    process_slicer:start()
  end
  
  -- Proper timer handling
  local function check_completion()
    if PakettiYTDLPFileExists(output_dir .. separator .. "tempfolder" .. separator .. "download_completed.txt") then
      -- Remove the timer IMMEDIATELY to prevent multiple calls
      if renoise.tool():has_timer(completion_timer_func) then
        renoise.tool():remove_timer(completion_timer_func)
      end
      completion_timer_func = nil  -- Clear reference to prevent reuse
      
      -- Load into Renoise (this function will now remove the completion signal file)
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
    text="",
    width=690,
    height = 500
  }

  status_text = vb:text{
    id = "status_text",
    text="Ready",
    width=200
  }

  cancel_button = vb:button{
    id = "cancel_button",
    text="Cancel",
    active = false,
    notifier = PakettiYTDLPCancelProcess
  }

  local dialog_content = vb:column{
    id = "main_column",
    width=690,
    margin=1,
    vb:text{id="hi", text="YT-DLP is able to download content from:", font="bold",style="strong"},
    vb:text{id="List",text="YouTube, Twitter, Facebook, SoundCloud, Bandcamp and Instagram (tested).", font = "bold",style="strong" },
    vb:row{
      vb:column{
        width=170,
        vb:text{text="Search Phrase", font="bold",style="strong" },
        vb:text{text="URL", font="bold",style="strong" },
        vb:text{text="Output Directory", font="bold",style="strong" },
        vb:text{text="YT-DLP Location", font="bold",style="strong" },
        --vb:text{text="Clip Length (seconds)", font="bold",style="strong" },
        vb:text{text="Loop Mode", font="bold",style="strong" },
        vb:text{text="Amount of Searched Videos", font="bold",style="strong" }
      },
      vb:column{
        width=600,
        vb:textfield { 
          id = "search_phrase", 
          width=400,
          edit_mode = true,
          notifier=function(value)
            if value ~= "" then
              PakettiYTDLPStartYTDLP()
            end
          end
        },
        vb:textfield {
          id = "youtube_url",
          width=400,
          edit_mode = true,
          notifier=function(value)
            if value ~= "" then
              PakettiYTDLPStartYTDLP()
            end
          end
        },
        vb:row{
          vb:textfield {
            id = "output_dir",
            width=400,
            text = preferences.PakettiYTDLP.PakettiYTDLPOutputDirectory.value
          },
          vb:button{ text="Browse", notifier = PakettiYTDLPBrowseForOutputDir },
          vb:button{ text="Open Path", notifier=function()
            local path = vb.views.output_dir.text
            if path and path ~= "" and path ~= "Set this yourself, please." then
              os.execute('open "' .. path .. '"')
              PakettiYTDLPLogMessage("Opening path: " .. path)
            else
              renoise.app():show_warning("Please set a valid output directory first")
            end
          end},
        },
        vb:row{
          vb:textfield {
            id = "yt_dlp_location",
            width=400,
            text = preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value or "<No path set>",
           -- read_only = true
          },
          vb:button{ text="Browse", notifier = PakettiYTDLPPromptForYTDLPPath },
        },
        -- COMMENTED OUT: Clip length control (no longer functional - always downloads full video)
        -- vb:valuebox{
        --   id = "clip_length",
        --   min = 1,
        --   max = 60,
        --   value = preferences.PakettiYTDLP.PakettiYTDLPClipLength.value or SAMPLE_LENGTH,
        --   notifier=function(value)
        --     preferences.PakettiYTDLP.PakettiYTDLPClipLength.value = value
        --     PakettiYTDLPLogMessage("Saved Clip Length to " .. value)
        --   end
        -- },
        vb:popup{
          id = "loop_mode",
          items = loop_modes,
          value = preferences.PakettiYTDLP.PakettiYTDLPLoopMode.value or 2,
          width=80,
          notifier=function(value)
            preferences.PakettiYTDLP.PakettiYTDLPLoopMode.value = value
            PakettiYTDLPLogMessage("Saved Loop Mode to " .. value)
          end
        },
        vb:valuebox{
          id = "video_amount",
          min = 1,
          max = 100,
          value = preferences.PakettiYTDLP.PakettiYTDLPAmountOfVideos.value or 1,
          notifier=function(value)
            preferences.PakettiYTDLP.PakettiYTDLPAmountOfVideos.value = value
            PakettiYTDLPLogMessage("Saved Amount of Videos to " .. value)
          end
        }
      }
    },
    -- COMMENTED OUT: Full video checkbox (no longer functional - always downloads full video)
    -- vb:row{
    --   vb:checkbox{
    --     id = "full_video",
    --     value = preferences.PakettiYTDLP.PakettiYTDLPLoadWholeVideo.value,
    --     notifier=function(value)
    --       preferences.PakettiYTDLP.PakettiYTDLPLoadWholeVideo.value = value
    --       if value then vb.views.clip_length.value = SAMPLE_LENGTH end
    --       PakettiYTDLPLogMessage("Saved Load Whole Video to " .. tostring(value))
    --     end
    --   },
    --   vb:text{text="Download Whole Video as Audio", font="bold",style="strong" },
    -- },
    vb:row{
      vb:text{text="Download Whole Video as Audio", font="bold",style="strong" }
    },
    vb:row{
      vb:checkbox{
        id = "create_new_instrument",
        value = preferences.PakettiYTDLP.PakettiYTDLPNewInstrumentOrSameInstrument.value,
        notifier=function(value)
          preferences.PakettiYTDLP.PakettiYTDLPNewInstrumentOrSameInstrument.value = value
          PakettiYTDLPLogMessage("Saved Create New Instrument to " .. tostring(value))
        end
      },
      vb:text{text="Create New Instrument for Each Downloaded Audio", font="bold",style="strong" },
    },
    vb:row{vb:text{text="Save Successfully Downloaded Audio to Selected Folder", font="bold",style="strong"},
      vb:popup{
        id = "save_format",
        items = {"Off", "Save WAV", "Save FLAC"},
        value = preferences.PakettiYTDLP.PakettiYTDLPFormatToSave.value or 1,
        width=120,
        notifier=function(value)
          preferences.PakettiYTDLP.PakettiYTDLPFormatToSave.value = value
          if (value == 2 or value == 3) and (vb.views.save_path.text == "<No path set>" or vb.views.save_path.text == "") then
            PakettiYTDLPPromptForSavePath()
          end
          PakettiYTDLPLogMessage("Saved Save Format to " .. value)
        end
      },
    },
    vb:row{
      vb:text{text="Save Path", font="bold",style="strong" },
      vb:text{id = "save_path", text = preferences.PakettiYTDLP.PakettiYTDLPPathToSave.value or "<No path set>", font = "bold", style="strong" },
      vb:button{ text="Browse", notifier = PakettiYTDLPPromptForSavePath }
    },
    vb:row{
      vb:text{text="Status", font="bold",style="strong" },
      status_text,
      cancel_button
    },
    -- Multiline Textfield for Logs
    vb:row{
      vb:column{
        vb:row{
          vb:text{text="Log Output", font = "bold",style="strong" },
          vb:button{
            id = "Clear_thing",
            text="Clear",
            notifier=function() logview.text="" end
          }
        },
        logview,
      }
    },
    vb:row{
      vb:button{
        id = "start_button",
        text="Start",
        notifier=function()
          -- Check if yt-dlp location is set, try auto-detection first
          local saved_path = PakettiYTDLPGetStringValue(preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value)
          if saved_path == nil or saved_path == "" then
            -- Try auto-detection
            local detected = PakettiYTDLPGuessExecutable()
            if detected then
              yt_dlp_path = detected
              preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = detected
              if vb.views.yt_dlp_location then
                vb.views.yt_dlp_location.text = detected
              end
              renoise.app():show_status("yt-dlp auto-detected at: " .. detected)
            else
              -- Show install dialog instead of just prompting to browse
              PakettiYTDLPShowInstallDialog()
              return
            end
          end
          PakettiYTDLPStartYTDLP()
        end
      },
      vb:button{ text="Save", notifier=function()
        preferences.PakettiYTDLP.PakettiYTDLPOutputDirectory.value = vb.views.output_dir.text
        -- preferences.PakettiYTDLP.PakettiYTDLPClipLength.value = vb.views.clip_length.value  -- COMMENTED: No longer used
        preferences.PakettiYTDLP.PakettiYTDLPLoopMode.value = vb.views.loop_mode.value
        preferences.PakettiYTDLP.PakettiYTDLPAmountOfVideos.value = vb.views.video_amount.value
        -- preferences.PakettiYTDLP.PakettiYTDLPLoadWholeVideo.value = vb.views.full_video.value  -- COMMENTED: Always full video
        preferences.PakettiYTDLP.PakettiYTDLPNewInstrumentOrSameInstrument.value = vb.views.create_new_instrument.value
        preferences.PakettiYTDLP.PakettiYTDLPFormatToSave.value = vb.views.save_format.value
        preferences.PakettiYTDLP.PakettiYTDLPPathToSave.value = vb.views.save_path.text
        preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = vb.views.yt_dlp_location.text

        PakettiYTDLPPrintPreferences()
      end},
      vb:button{ text="Save & Close", notifier=function()
        preferences.PakettiYTDLP.PakettiYTDLPOutputDirectory.value = vb.views.output_dir.text
        -- preferences.PakettiYTDLP.PakettiYTDLPClipLength.value = vb.views.clip_length.value  -- COMMENTED: No longer used
        preferences.PakettiYTDLP.PakettiYTDLPLoopMode.value = vb.views.loop_mode.value
        preferences.PakettiYTDLP.PakettiYTDLPAmountOfVideos.value = vb.views.video_amount.value
        -- preferences.PakettiYTDLP.PakettiYTDLPLoadWholeVideo.value = vb.views.full_video.value  -- COMMENTED: Always full video
        preferences.PakettiYTDLP.PakettiYTDLPNewInstrumentOrSameInstrument.value = vb.views.create_new_instrument.value
        preferences.PakettiYTDLP.PakettiYTDLPFormatToSave.value = vb.views.save_format.value
        preferences.PakettiYTDLP.PakettiYTDLPPathToSave.value = vb.views.save_path.text
        preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = vb.views.yt_dlp_location.text

        PakettiYTDLPPrintPreferences()
        PakettiYTDLPCloseDialog()
      end}
    }
  }

  -- If yt-dlp location is not set, try auto-detection first, then show install dialog if needed
  local saved_path = PakettiYTDLPGetStringValue(preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value)
  if saved_path == nil or saved_path == "" then
    -- Try auto-detection
    local detected = PakettiYTDLPGuessExecutable()
    if detected then
      yt_dlp_path = detected
      preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value = detected
      vb.views.yt_dlp_location.text = detected
      renoise.app():show_status("yt-dlp auto-detected at: " .. detected)
    end
    -- Note: If not found, the Start button will show install dialog when clicked
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

function pakettiYTDLPDialog()
  -- Set up paths when dialog is opened (with install dialog if not found)
  local yt_dlp_found = PakettiYTDLPSetExecutablePaths(true)
  
  if dialog and dialog.visible then
    PakettiYTDLPLogMessage("Dialog is visible, closing dialog.")
    PakettiYTDLPCloseDialog()
  else
    -- Only show the main dialog if yt-dlp was found
    if yt_dlp_found then
      dialog_content = PakettiYTDLPDialogContent()
      local keyhandler = create_keyhandler_for_dialog(
        function() return dialog end,
        function(value) dialog = value end
      )
      dialog = renoise.app():show_custom_dialog("Paketti YT-DLP Downloader", dialog_content, keyhandler)
      PakettiYTDLPLogMessage("YT-DLP Downloader Initialized and ready to go.")
    end
    -- If yt-dlp wasn't found, PakettiYTDLPSetExecutablePaths already showed the install dialog
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

renoise.tool():add_keybinding{name="Global:Paketti:Paketti YT-DLP Downloader",invoke=pakettiYTDLPDialog }

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
    status_text.text="Ready"
  end
  if cancel_button then
    cancel_button.active = false
  end
  PakettiYTDLPLogMessage("Process cancelled")
end