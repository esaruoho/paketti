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