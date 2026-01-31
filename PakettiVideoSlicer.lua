-- PakettiVideoSlicer.lua
-- Simple video chopping tool: Load video audio, slice in Renoise, chop video
-- Supports local files and YouTube URLs
-- Supports external ping/pong communication via /tmp files

local separator = package.config:sub(1,1)

--------------------------------------------------------------------------------
-- Global state
--------------------------------------------------------------------------------
local vb = nil
local dialog = nil
local ffmpeg_path = ""
local ytdlp_path = ""

-- Current session state
local current_video_path = nil
local current_audio_path = nil
local current_output_dir = nil
local current_source_url = nil

-- External communication paths
local PING_FILE = "/tmp/renoisePing.txt"
local PONG_FILE = "/tmp/OSPingSlicingComplete.txt"
local ping_timer_func = nil

--------------------------------------------------------------------------------
-- Path Detection
--------------------------------------------------------------------------------

function PakettiVideoSlicerDetectFFmpegPath()
  local os_name = os.platform()
  
  if os_name == "MACINTOSH" then
    local paths = {
      "/opt/homebrew/bin/ffmpeg",
      "/usr/local/bin/ffmpeg",
      "/usr/bin/ffmpeg"
    }
    for _, path in ipairs(paths) do
      local file = io.open(path, "r")
      if file then
        file:close()
        ffmpeg_path = path
        return path
      end
    end
  elseif os_name == "LINUX" then
    local paths = {
      "/usr/bin/ffmpeg",
      "/usr/local/bin/ffmpeg",
      "/home/linuxbrew/.linuxbrew/bin/ffmpeg",
      "/snap/bin/ffmpeg"
    }
    for _, path in ipairs(paths) do
      local file = io.open(path, "r")
      if file then
        file:close()
        ffmpeg_path = path
        return path
      end
    end
  elseif os_name == "WINDOWS" then
    local paths = {
      "C:\\ffmpeg\\bin\\ffmpeg.exe",
      "C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe"
    }
    for _, path in ipairs(paths) do
      local file = io.open(path, "r")
      if file then
        file:close()
        ffmpeg_path = path
        return path
      end
    end
  end
  
  return nil
end

function PakettiVideoSlicerDetectYTDLPPath()
  -- First check preferences
  if preferences and preferences.PakettiYTDLP and preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation then
    local pref_path = preferences.PakettiYTDLP.PakettiYTDLPYT_DLPLocation.value
    if pref_path and pref_path ~= "" then
      local file = io.open(pref_path, "r")
      if file then
        file:close()
        ytdlp_path = pref_path
        return pref_path
      end
    end
  end
  
  local os_name = os.platform()
  
  if os_name == "MACINTOSH" then
    local paths = {
      "/opt/homebrew/bin/yt-dlp",
      "/usr/local/bin/yt-dlp",
      "/usr/bin/yt-dlp"
    }
    for _, path in ipairs(paths) do
      local file = io.open(path, "r")
      if file then
        file:close()
        ytdlp_path = path
        return path
      end
    end
  elseif os_name == "LINUX" then
    local paths = {
      "/usr/bin/yt-dlp",
      "/usr/local/bin/yt-dlp",
      "/home/linuxbrew/.linuxbrew/bin/yt-dlp",
      "/snap/bin/yt-dlp"
    }
    for _, path in ipairs(paths) do
      local file = io.open(path, "r")
      if file then
        file:close()
        ytdlp_path = path
        return path
      end
    end
  elseif os_name == "WINDOWS" then
    local paths = {
      "C:\\yt-dlp\\yt-dlp.exe",
      "C:\\Program Files\\yt-dlp\\yt-dlp.exe"
    }
    for _, path in ipairs(paths) do
      local file = io.open(path, "r")
      if file then
        file:close()
        ytdlp_path = path
        return path
      end
    end
  end
  
  return nil
end

function PakettiVideoSlicerGetPathEnv()
  if os.platform() == "MACINTOSH" then
    return "env PATH=/opt/homebrew/bin:/usr/local/bin:$PATH "
  end
  return ""
end

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

function PakettiVideoSlicerFileExists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

function PakettiVideoSlicerGetFilename(path)
  return path:match("([^/\\]+)$") or path
end

function PakettiVideoSlicerGetBasename(path)
  local filename = PakettiVideoSlicerGetFilename(path)
  return filename:gsub("%.[^%.]+$", "")
end

function PakettiVideoSlicerGetExtension(path)
  return path:match("%.([^%.]+)$") or ""
end

function PakettiVideoSlicerGetDirectory(path)
  return path:match("(.+)[/\\]") or ""
end

function PakettiVideoSlicerSanitizeFilename(name)
  return name:gsub("[^%w%s%-_]", "_"):gsub("%s+", "_")
end

function PakettiVideoSlicerIsURL(str)
  if not str then return false end
  return str:match("^https?://") or str:match("^www%.") or str:match("youtube%.com") or str:match("youtu%.be")
end

function PakettiVideoSlicerFramesToTimestamp(frames, sample_rate)
  local total_seconds = frames / sample_rate
  local hours = math.floor(total_seconds / 3600)
  local minutes = math.floor((total_seconds % 3600) / 60)
  local seconds = total_seconds % 60
  return string.format("%02d:%02d:%06.3f", hours, minutes, seconds)
end

function PakettiVideoSlicerFramesToMilliseconds(frames, sample_rate)
  return math.floor((frames / sample_rate) * 1000)
end

--------------------------------------------------------------------------------
-- Update Dialog Status
--------------------------------------------------------------------------------

function PakettiVideoSlicerUpdateStatus(message)
  if vb and vb.views and vb.views.status_text then
    vb.views.status_text.text = message
  end
  print("PakettiVideoSlicer: " .. message)
end

function PakettiVideoSlicerUpdateVideoInfo()
  if not vb or not vb.views then return end
  
  if current_video_path then
    local display = PakettiVideoSlicerGetFilename(current_video_path)
    if current_source_url then
      display = display .. " (from URL)"
    end
    vb.views.video_info.text = display
    vb.views.write_button.active = true
  else
    vb.views.video_info.text = "<No video loaded>"
    vb.views.write_button.active = false
  end
  
  local song = renoise.song()
  if song and song.selected_sample and song.selected_sample.sample_buffer.has_sample_data then
    local slice_count = #song.selected_sample.slice_markers
    vb.views.slice_info.text = tostring(slice_count) .. " slices"
  else
    vb.views.slice_info.text = "0 slices"
  end
end

--------------------------------------------------------------------------------
-- External Ping File Watcher
--------------------------------------------------------------------------------

function PakettiVideoSlicerCheckPingFile()
  if PakettiVideoSlicerFileExists(PING_FILE) then
    print("PakettiVideoSlicer: Ping file detected!")
    
    -- Read contents (might contain video path or URL)
    local ping_content = nil
    local file = io.open(PING_FILE, "r")
    if file then
      ping_content = file:read("*a")
      file:close()
      ping_content = ping_content and ping_content:gsub("^%s*(.-)%s*$", "%1") or nil
    end
    
    -- Delete the ping file immediately
    os.remove(PING_FILE)
    
    -- Apply dynamic view 8 (if the function exists)
    if apply_dynamic_view_step then
      apply_dynamic_view_step(8, 1)
      print("PakettiVideoSlicer: Applied Dynamic View 8")
    end
    
    -- Open the Video Slicer dialog
    PakettiVideoSlicerShowDialog()
    
    -- If ping file contained a path/URL, load it
    if ping_content and ping_content ~= "" then
      -- Check if it's a URL or file path
      if PakettiVideoSlicerIsURL(ping_content) then
        -- Set the URL field
        if vb and vb.views and vb.views.url_input then
          vb.views.url_input.text = ping_content
        end
        print("PakettiVideoSlicer: URL from ping: " .. ping_content)
      elseif PakettiVideoSlicerFileExists(ping_content) then
        -- It's a local file path - load it directly
        current_video_path = ping_content
        current_output_dir = PakettiVideoSlicerGetDirectory(ping_content)
        PakettiVideoSlicerLoadVideoAudio(ping_content)
      end
    end
    
    renoise.app():show_status("Video Slicer activated by external ping")
  end
end

function PakettiVideoSlicerStartPingWatcher()
  if ping_timer_func and renoise.tool():has_timer(ping_timer_func) then
    return -- Already running
  end
  
  ping_timer_func = PakettiVideoSlicerCheckPingFile
  renoise.tool():add_timer(ping_timer_func, 500) -- Check every 500ms
  print("PakettiVideoSlicer: Ping file watcher started")
end

function PakettiVideoSlicerStopPingWatcher()
  if ping_timer_func and renoise.tool():has_timer(ping_timer_func) then
    renoise.tool():remove_timer(ping_timer_func)
    ping_timer_func = nil
    print("PakettiVideoSlicer: Ping file watcher stopped")
  end
end

--------------------------------------------------------------------------------
-- Write Completion Signal (Pong)
--------------------------------------------------------------------------------

function PakettiVideoSlicerWritePongFile(slice_data, wav_path, timestamps_path)
  local file = io.open(PONG_FILE, "w")
  if not file then
    print("PakettiVideoSlicer: Failed to write pong file")
    return false
  end
  
  file:write("# Paketti Video Slicer - Slicing Complete\n")
  file:write("# Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
  file:write("\n")
  
  if current_video_path then
    file:write("SOURCE_VIDEO=" .. current_video_path .. "\n")
  end
  if current_source_url then
    file:write("SOURCE_URL=" .. current_source_url .. "\n")
  end
  if wav_path then
    file:write("WAV_WITH_CUE=" .. wav_path .. "\n")
  end
  if timestamps_path then
    file:write("TIMESTAMPS_FILE=" .. timestamps_path .. "\n")
  end
  
  file:write("\n# SLICE DATA\n")
  file:write("SLICE_COUNT=" .. #slice_data .. "\n")
  file:write("\n")
  
  for i, slice in ipairs(slice_data) do
    file:write(string.format("SLICE_%02d_START=%s\n", i, slice.start_time))
    file:write(string.format("SLICE_%02d_END=%s\n", i, slice.end_time))
    file:write(string.format("SLICE_%02d_START_MS=%d\n", i, slice.start_ms))
    file:write(string.format("SLICE_%02d_END_MS=%d\n", i, slice.end_ms))
    file:write(string.format("SLICE_%02d_START_FRAME=%d\n", i, slice.start_frame))
    file:write(string.format("SLICE_%02d_END_FRAME=%d\n", i, slice.end_frame))
    file:write("\n")
  end
  
  file:close()
  print("PakettiVideoSlicer: Wrote pong file: " .. PONG_FILE)
  return true
end

--------------------------------------------------------------------------------
-- Download Video from URL
--------------------------------------------------------------------------------

function PakettiVideoSlicerDownloadVideo(url, output_dir, callback)
  if not ytdlp_path or ytdlp_path == "" then
    PakettiVideoSlicerDetectYTDLPPath()
  end
  
  if not ytdlp_path or ytdlp_path == "" then
    renoise.app():show_error("yt-dlp not found. Please install yt-dlp to download from URLs.")
    return nil
  end
  
  PakettiVideoSlicerUpdateStatus("Downloading video from URL...")
  
  local output_template = output_dir .. separator .. "%(title)s.%(ext)s"
  
  local command = string.format(
    '%s"%s" -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" --merge-output-format mp4 -o "%s" "%s" 2>&1',
    PakettiVideoSlicerGetPathEnv(),
    ytdlp_path,
    output_template,
    url
  )
  
  print("PakettiVideoSlicer: Downloading with command:")
  print(command)
  
  local handle = io.popen(command)
  if not handle then
    PakettiVideoSlicerUpdateStatus("Error: Failed to start download")
    return nil
  end
  
  local output = handle:read("*a")
  handle:close()
  
  if output then
    print(output)
  end
  
  local downloaded_file = nil
  
  local dest_match = output:match("%[download%] Destination: ([^\n]+)")
  if dest_match then
    downloaded_file = dest_match
  else
    dest_match = output:match("%[Merger%] Merging formats into \"([^\"]+)\"")
    if dest_match then
      downloaded_file = dest_match
    else
      dest_match = output:match("%[download%] ([^\n]+) has already been downloaded")
      if dest_match then
        downloaded_file = dest_match
      end
    end
  end
  
  if not downloaded_file or not PakettiVideoSlicerFileExists(downloaded_file) then
    local list_cmd
    if os.platform() == "WINDOWS" then
      list_cmd = 'dir /b /o-d "' .. output_dir .. separator .. '*.mp4"'
    else
      list_cmd = 'ls -t "' .. output_dir .. '"/*.mp4 2>/dev/null | head -1'
    end
    
    local list_handle = io.popen(list_cmd)
    if list_handle then
      local newest = list_handle:read("*l")
      list_handle:close()
      if newest and newest ~= "" then
        if os.platform() == "WINDOWS" then
          downloaded_file = output_dir .. separator .. newest
        else
          downloaded_file = newest
        end
      end
    end
  end
  
  if downloaded_file and PakettiVideoSlicerFileExists(downloaded_file) then
    print("PakettiVideoSlicer: Downloaded to: " .. downloaded_file)
    current_source_url = url
    return downloaded_file
  else
    PakettiVideoSlicerUpdateStatus("Error: Download failed or file not found")
    return nil
  end
end

--------------------------------------------------------------------------------
-- Load Video Audio (shared logic)
--------------------------------------------------------------------------------

function PakettiVideoSlicerLoadVideoAudio(video_path)
  if not ffmpeg_path or ffmpeg_path == "" then
    PakettiVideoSlicerDetectFFmpegPath()
  end
  
  if not ffmpeg_path or ffmpeg_path == "" then
    renoise.app():show_error("ffmpeg not found.")
    return false
  end
  
  PakettiVideoSlicerUpdateStatus("Converting: " .. PakettiVideoSlicerGetFilename(video_path))
  
  current_video_path = video_path
  if not current_output_dir then
    current_output_dir = PakettiVideoSlicerGetDirectory(video_path)
  end
  
  local basename = PakettiVideoSlicerGetBasename(video_path)
  current_audio_path = pakettiGetTempFilePath(".wav")
  
  local command = string.format(
    '%s"%s" -i "%s" -vn -acodec pcm_s16le -y "%s" 2>&1',
    PakettiVideoSlicerGetPathEnv(),
    ffmpeg_path,
    video_path,
    current_audio_path
  )
  
  print("PakettiVideoSlicer: Extracting audio...")
  print(command)
  
  local handle = io.popen(command)
  if handle then
    local output = handle:read("*a")
    handle:close()
    if output and output ~= "" then
      print(output)
    end
  end
  
  if not PakettiVideoSlicerFileExists(current_audio_path) then
    PakettiVideoSlicerUpdateStatus("Error: Failed to extract audio")
    renoise.app():show_error("Failed to extract audio from video")
    current_video_path = nil
    current_audio_path = nil
    return false
  end
  
  local song = renoise.song()
  local current_index = song.selected_instrument_index
  local current_instrument = song.selected_instrument
  
  local use_existing = false
  if #current_instrument.samples == 0 then
    use_existing = true
  elseif #current_instrument.samples == 1 and not current_instrument.samples[1].sample_buffer.has_sample_data then
    use_existing = true
  end
  
  if not use_existing then
    if not safeInsertInstrumentAt(song, current_index + 1) then return end
    song.selected_instrument_index = current_index + 1
  end
  
  if pakettiPreferencesDefaultInstrumentLoader then
    pakettiPreferencesDefaultInstrumentLoader()
  end
  
  local instrument = song.selected_instrument
  if #instrument.samples == 0 then
    instrument:insert_sample_at(1)
  end
  
  song.selected_sample_index = 1
  local sample = song.selected_sample
  
  if sample.sample_buffer:load_from(current_audio_path) then
    sample.name = basename
    instrument.name = basename
    
    if preferences then
      sample.autofade = preferences.pakettiLoaderAutofade.value
      sample.autoseek = preferences.pakettiLoaderAutoseek.value
      sample.loop_mode = preferences.pakettiLoaderLoopMode.value
      sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
      sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
      sample.oneshot = preferences.pakettiLoaderOneshot.value
      sample.new_note_action = preferences.pakettiLoaderNNA.value
      sample.loop_release = preferences.pakettiLoaderLoopExit.value
    end
    
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    
    os.remove(current_audio_path)
    
    if vb and vb.views and vb.views.url_input then
      vb.views.url_input.text = ""
    end
    
    PakettiVideoSlicerUpdateStatus("Loaded: " .. basename .. " - Add slices, then Write")
    PakettiVideoSlicerUpdateVideoInfo()
    
    renoise.app():show_status("Video audio loaded: " .. basename)
    return true
  else
    PakettiVideoSlicerUpdateStatus("Error: Failed to load audio")
    renoise.app():show_error("Failed to load extracted audio")
    current_video_path = nil
    return false
  end
end

--------------------------------------------------------------------------------
-- START: Load Video Audio (Local or URL)
--------------------------------------------------------------------------------

function PakettiVideoSlicerStart()
  if not ffmpeg_path or ffmpeg_path == "" then
    PakettiVideoSlicerDetectFFmpegPath()
  end
  
  if not ffmpeg_path or ffmpeg_path == "" then
    renoise.app():show_error("ffmpeg not found. Please install ffmpeg.")
    return
  end
  
  local url_text = ""
  if vb and vb.views and vb.views.url_input then
    url_text = vb.views.url_input.text
  end
  
  local video_path = nil
  local is_url = PakettiVideoSlicerIsURL(url_text)
  
  if is_url then
    PakettiVideoSlicerDetectYTDLPPath()
    if not ytdlp_path or ytdlp_path == "" then
      renoise.app():show_error("yt-dlp not found. Please install yt-dlp to download from URLs.\n\nAlternatively, clear the URL field and use 'Start' to pick a local file.")
      return
    end
    
    local download_dir = renoise.app():prompt_for_path("Select Download Directory for Video")
    if not download_dir or download_dir == "" then
      return
    end
    
    video_path = PakettiVideoSlicerDownloadVideo(url_text, download_dir, nil)
    if not video_path then
      return
    end
    
    current_output_dir = download_dir
  else
    local video_extensions = {"*.mp4", "*.mkv", "*.avi", "*.mov", "*.webm", "*.flv", "*.wmv", "*.m4v"}
    video_path = renoise.app():prompt_for_filename_to_read(video_extensions, "Select Video File")
    
    if not video_path or video_path == "" then
      return
    end
    
    current_output_dir = PakettiVideoSlicerGetDirectory(video_path)
    current_source_url = nil
  end
  
  PakettiVideoSlicerLoadVideoAudio(video_path)
end

--------------------------------------------------------------------------------
-- WRITE: Export Slices and Chop Video
--------------------------------------------------------------------------------

function PakettiVideoSlicerWrite()
  if not current_video_path then
    renoise.app():show_error("No video loaded. Click Start first.")
    return
  end
  
  local song = renoise.song()
  local sample = song.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_error("No sample data available")
    return
  end
  
  local slice_markers = sample.slice_markers
  if #slice_markers == 0 then
    renoise.app():show_warning("No slices found. Add some slice markers first!")
    return
  end
  
  local output_dir = renoise.app():prompt_for_path("Select Output Directory for Video Slices")
  if not output_dir or output_dir == "" then
    return
  end
  
  local sample_rate = sample.sample_buffer.sample_rate
  local total_frames = sample.sample_buffer.number_of_frames
  local basename = PakettiVideoSlicerSanitizeFilename(PakettiVideoSlicerGetBasename(current_video_path))
  local video_ext = PakettiVideoSlicerGetExtension(current_video_path)
  
  PakettiVideoSlicerUpdateStatus("Writing slices...")
  
  -- Build slice regions
  local regions = {}
  local sorted_markers = {}
  for i = 1, #slice_markers do
    table.insert(sorted_markers, slice_markers[i])
  end
  table.sort(sorted_markers)
  
  for i = 1, #sorted_markers do
    local start_frame = sorted_markers[i]
    local end_frame = (i < #sorted_markers) and (sorted_markers[i + 1] - 1) or total_frames
    table.insert(regions, {
      start_frame = start_frame,
      end_frame = end_frame,
      start_time = PakettiVideoSlicerFramesToTimestamp(start_frame, sample_rate),
      end_time = PakettiVideoSlicerFramesToTimestamp(end_frame, sample_rate),
      start_ms = PakettiVideoSlicerFramesToMilliseconds(start_frame, sample_rate),
      end_ms = PakettiVideoSlicerFramesToMilliseconds(end_frame, sample_rate)
    })
  end
  
  -- 1. Write timestamps text file
  local timestamps_path = output_dir .. separator .. basename .. "_slices.txt"
  local ts_file = io.open(timestamps_path, "w")
  if ts_file then
    ts_file:write("# Video Slice Timestamps\n")
    ts_file:write("# Source: " .. current_video_path .. "\n")
    if current_source_url then
      ts_file:write("# URL: " .. current_source_url .. "\n")
    end
    ts_file:write("# Sample Rate: " .. sample_rate .. " Hz\n")
    ts_file:write("# Slices: " .. #regions .. "\n\n")
    
    for i, region in ipairs(regions) do
      ts_file:write(string.format("Slice %02d: %s -> %s\n", i, region.start_time, region.end_time))
    end
    ts_file:close()
    print("PakettiVideoSlicer: Wrote " .. timestamps_path)
  end
  
  -- 2. Write WAV with cue headers
  local wav_path = output_dir .. separator .. basename .. "_sliced.wav"
  local wav_success = sample.sample_buffer:save_as(wav_path, "wav")
  
  if wav_success and PakettiWavCueWriteCueChunksToWav then
    local cue_success = PakettiWavCueWriteCueChunksToWav(wav_path, slice_markers, sample_rate, sample.name)
    if cue_success then
      print("PakettiVideoSlicer: Wrote WAV with cue headers: " .. wav_path)
    end
  end
  
  -- 3. Write pong file for external communication
  PakettiVideoSlicerWritePongFile(regions, wav_path, timestamps_path)
  
  -- 4. Generate and run ffmpeg commands
  local os_name = os.platform()
  local is_windows = (os_name == "WINDOWS")
  
  local choice = renoise.app():show_prompt(
    "Chop Video",
    "Chop " .. #regions .. " video segments now?\n\n" ..
    "Yes = Run ffmpeg now (may take a while)\n" ..
    "No = Generate shell script only",
    {"Yes, Chop Now", "No, Script Only", "Cancel"}
  )
  
  if choice == "Cancel" then
    PakettiVideoSlicerUpdateStatus("Cancelled")
    return
  end
  
  local run_now = (choice == "Yes, Chop Now")
  
  local commands = {}
  for i, region in ipairs(regions) do
    local output_file = output_dir .. separator .. basename .. string.format("_slice_%02d.", i) .. video_ext
    local cmd = string.format(
      '"%s" -i "%s" -ss %s -to %s -c copy -y "%s"',
      ffmpeg_path,
      current_video_path,
      region.start_time,
      region.end_time,
      output_file
    )
    table.insert(commands, {cmd = cmd, index = i, output = output_file})
  end
  
  local script_ext = is_windows and ".bat" or ".sh"
  local script_path = output_dir .. separator .. basename .. "_chop" .. script_ext
  local script_file = io.open(script_path, "w")
  
  if script_file then
    if is_windows then
      script_file:write("@echo off\n")
      script_file:write("REM Video Slicer Script - " .. basename .. "\n")
      if current_source_url then
        script_file:write("REM Source URL: " .. current_source_url .. "\n")
      end
      script_file:write("\n")
    else
      script_file:write("#!/bin/bash\n")
      script_file:write("# Video Slicer Script - " .. basename .. "\n")
      if current_source_url then
        script_file:write("# Source URL: " .. current_source_url .. "\n")
      end
      script_file:write("\n")
    end
    
    for i, c in ipairs(commands) do
      if is_windows then
        script_file:write("echo Slice " .. i .. " of " .. #commands .. "...\n")
      else
        script_file:write("echo \"Slice " .. i .. " of " .. #commands .. "...\"\n")
      end
      script_file:write(c.cmd .. "\n\n")
    end
    
    if is_windows then
      script_file:write("echo Done!\npause\n")
    else
      script_file:write("echo \"Done!\"\n")
    end
    script_file:close()
    
    if not is_windows then
      os.execute('chmod +x "' .. script_path .. '"')
    end
    print("PakettiVideoSlicer: Wrote script: " .. script_path)
  end
  
  if run_now then
    PakettiVideoSlicerUpdateStatus("Chopping video... (0/" .. #commands .. ")")
    
    local success_count = 0
    for i, c in ipairs(commands) do
      PakettiVideoSlicerUpdateStatus("Chopping slice " .. i .. "/" .. #commands .. "...")
      
      local full_cmd = PakettiVideoSlicerGetPathEnv() .. c.cmd .. " 2>&1"
      print("Running: " .. full_cmd)
      
      local handle = io.popen(full_cmd)
      if handle then
        local output = handle:read("*a")
        handle:close()
        if output and output ~= "" then
          print(output)
        end
      end
      
      if PakettiVideoSlicerFileExists(c.output) then
        success_count = success_count + 1
      end
    end
    
    PakettiVideoSlicerUpdateStatus("Done: " .. success_count .. "/" .. #commands .. " slices created")
    
    renoise.app():show_message(
      "Video chopping complete!\n\n" ..
      "Created: " .. success_count .. " of " .. #commands .. " video slices\n" ..
      "Output: " .. output_dir .. "\n\n" ..
      "Files:\n" ..
      "- " .. basename .. "_slices.txt (timestamps)\n" ..
      "- " .. basename .. "_sliced.wav (with cue markers)\n" ..
      "- " .. basename .. "_slice_XX." .. video_ext .. " (video clips)\n" ..
      "- " .. basename .. "_chop" .. script_ext .. " (script)\n\n" ..
      "Completion signal written to:\n" .. PONG_FILE
    )
  else
    PakettiVideoSlicerUpdateStatus("Script written: " .. script_path)
    
    renoise.app():show_message(
      "Export complete!\n\n" ..
      "Output: " .. output_dir .. "\n\n" ..
      "Files:\n" ..
      "- " .. basename .. "_slices.txt (timestamps)\n" ..
      "- " .. basename .. "_sliced.wav (with cue markers)\n" ..
      "- " .. basename .. "_chop" .. script_ext .. " (run this to chop video)\n\n" ..
      "Completion signal written to:\n" .. PONG_FILE
    )
  end
end

--------------------------------------------------------------------------------
-- Dialog
--------------------------------------------------------------------------------

function PakettiVideoSlicerShowDialog()
  if not ffmpeg_path or ffmpeg_path == "" then
    PakettiVideoSlicerDetectFFmpegPath()
  end
  if not ytdlp_path or ytdlp_path == "" then
    PakettiVideoSlicerDetectYTDLPPath()
  end
  
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  
  vb = renoise.ViewBuilder()
  
  local dialog_content = vb:column{
    margin = 10,
    spacing = 6,
    width = 450,
    
    vb:text{
      text = "Paketti Video Slicer",
      font = "bold",
      style = "strong"
    },
    
    vb:text{
      text = "Load video audio, slice in Renoise, chop video segments",
      font = "italic"
    },
    
    vb:space{ height = 6 },
    
    vb:row{
      spacing = 4,
      vb:text{ text = "URL:", width = 40 },
      vb:textfield{
        id = "url_input",
        width = 350,
        text = "",
        edit_mode = true
      },
      vb:button{
        text = "X",
        width = 24,
        notifier = function()
          vb.views.url_input.text = ""
        end
      }
    },
    
    vb:text{
      text = "Paste YouTube/video URL above, or leave empty to pick local file",
      font = "italic"
    },
    
    vb:space{ height = 6 },
    
    vb:row{
      spacing = 4,
      vb:text{ text = "Video:", width = 50, font = "bold" },
      vb:text{ id = "video_info", text = "<No video loaded>", width = 350 }
    },
    
    vb:row{
      spacing = 4,
      vb:text{ text = "Slices:", width = 50, font = "bold" },
      vb:text{ id = "slice_info", text = "0 slices", width = 100 },
      vb:button{
        text = "Refresh",
        width = 60,
        notifier = PakettiVideoSlicerUpdateVideoInfo
      }
    },
    
    vb:space{ height = 6 },
    
    vb:row{
      vb:text{ id = "status_text", text = "Ready - Paste URL or click Start", width = 420 }
    },
    
    vb:space{ height = 10 },
    
    vb:horizontal_aligner{
      mode = "center",
      spacing = 20,
      
      vb:button{
        id = "start_button",
        text = "Start",
        width = 140,
        height = 40,
        notifier = PakettiVideoSlicerStart
      },
      
      vb:button{
        id = "write_button",
        text = "Write",
        width = 140,
        height = 40,
        active = false,
        notifier = PakettiVideoSlicerWrite
      }
    },
    
    vb:space{ height = 8 },
    
    vb:column{
      style = "group",
      margin = 6,
      width = 420,
      
      vb:text{ text = "1. Start - Download URL or pick local file, extract audio", font = "mono" },
      vb:text{ text = "2. Add slice markers in the Sample Editor", font = "mono" },
      vb:text{ text = "3. Write - Export timestamps + chop video into segments", font = "mono" }
    },
    
    vb:space{ height = 4 },
    
    vb:column{
      vb:text{
        text = ffmpeg_path and ffmpeg_path ~= "" and ("ffmpeg: OK") or "ffmpeg: NOT FOUND",
        font = "mono"
      },
      vb:text{
        text = ytdlp_path and ytdlp_path ~= "" and ("yt-dlp: OK") or "yt-dlp: NOT FOUND (optional, for URLs)",
        font = "mono"
      },
      vb:text{
        text = "Ping: " .. PING_FILE,
        font = "mono"
      }
    }
  }
  
  local keyhandler = function(d, key)
    local closer = preferences.pakettiDialogClose.value
    if key.modifiers == "" and key.name == closer then
      d:close()
      dialog = nil
      return nil
    end
    return key
  end
  
  dialog = renoise.app():show_custom_dialog("Paketti Video Slicer", dialog_content, keyhandler)
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  PakettiVideoSlicerUpdateVideoInfo()
end

--------------------------------------------------------------------------------
-- Menu Entries and Keybindings
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Video Slicer...",
  invoke = PakettiVideoSlicerShowDialog
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Video Slicer...",
  invoke = PakettiVideoSlicerShowDialog
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Video Slicer...",
  invoke = PakettiVideoSlicerShowDialog
}

renoise.tool():add_keybinding{
  name = "Sample Editor:Paketti:Video Slicer...",
  invoke = PakettiVideoSlicerShowDialog
}

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------

PakettiVideoSlicerDetectFFmpegPath()
PakettiVideoSlicerDetectYTDLPPath()

-- Start the ping file watcher
PakettiVideoSlicerStartPingWatcher()

print("PakettiVideoSlicer: Watching for ping at " .. PING_FILE)







