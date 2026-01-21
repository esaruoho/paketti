local DIALOG_TITLE = "Paketti Image to Sample Converter"

-- Global variables for the image to sample dialog
local image_to_sample_dialog = nil
local loaded_image_bitmap = nil
local current_sample_data = nil
local waveform_canvas_view = nil
local current_image_info = nil
local current_conversion_method = nil  -- Track how image was converted

-- Canvas dimensions
local WAVEFORM_CANVAS_WIDTH = 800
local WAVEFORM_CANVAS_HEIGHT = 200

-- Color constants for canvas drawing
local COLOR_BACKGROUND = {0, 0, 0, 255}
local COLOR_WAVEFORM = {0, 255, 0, 255}
local COLOR_GRID = {0, 64, 0, 128}
local COLOR_CENTER_LINE = {128, 128, 128, 255}

-- Platform detection function
function PakettiImageToSampleGetPlatform()
  local sep = package.config:sub(1, 1)
  if sep == "\\" then
    return "windows"
  end
  -- Try to detect macOS via uname
  local handle = io.popen("uname -s 2>/dev/null")
  if handle then
    local result = handle:read("*l")
    handle:close()
    if result == "Darwin" then
      return "macos"
    end
  end
  return "linux"
end

-- Helper functions for reading binary data (little-endian)
local function read_uint32_le(data, offset)
  local b1, b2, b3, b4 = string.byte(data, offset, offset + 3)
  if not b1 or not b2 or not b3 or not b4 then return 0 end
  return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function read_int32_le(data, offset)
  local val = read_uint32_le(data, offset)
  if val >= 2147483648 then
    val = val - 4294967296
  end
  return val
end

local function read_uint16_le(data, offset)
  local b1, b2 = string.byte(data, offset, offset + 1)
  if not b1 or not b2 then return 0 end
  return b1 + b2 * 256
end

-- Pure Lua BMP pixel parser - converts each pixel to a sample
function PakettiImageToSampleParseBMPPixels(file_path)
  local file = io.open(file_path, "rb")
  if not file then
    print("BMP Parser: Could not open file: " .. tostring(file_path))
    return nil, 0, 0
  end
  
  -- Read BMP header (at least 54 bytes for BITMAPINFOHEADER)
  local header = file:read(54)
  if not header or #header < 54 then
    print("BMP Parser: Header too short")
    file:close()
    return nil, 0, 0
  end
  
  -- Check BMP signature
  if header:sub(1, 2) ~= "BM" then
    print("BMP Parser: Invalid BMP signature")
    file:close()
    return nil, 0, 0
  end
  
  -- Parse header fields (1-indexed in Lua, so add 1 to offsets)
  local pixel_offset = read_uint32_le(header, 11)   -- Offset 10: pixel data start
  local width = read_int32_le(header, 19)           -- Offset 18: width
  local height = read_int32_le(header, 23)          -- Offset 22: height (negative = top-down)
  local bits_per_pixel = read_uint16_le(header, 29) -- Offset 28: bits per pixel
  
  print(string.format("BMP Parser: %dx%d, %d bpp, pixel offset: %d", width, height, bits_per_pixel, pixel_offset))
  
  -- Handle negative height (top-down bitmap)
  local top_down = false
  if height < 0 then
    height = math.abs(height)
    top_down = true
  end
  
  -- Only support 24-bit and 32-bit BMPs
  if bits_per_pixel ~= 24 and bits_per_pixel ~= 32 then
    print("BMP Parser: Unsupported bit depth: " .. bits_per_pixel .. " (only 24/32 supported)")
    file:close()
    return nil, 0, 0
  end
  
  local bytes_per_pixel = bits_per_pixel / 8
  -- BMP rows are padded to 4-byte boundaries
  local row_size = math.floor((width * bytes_per_pixel + 3) / 4) * 4
  
  -- Seek to pixel data
  file:seek("set", pixel_offset)
  
  -- Read all pixel data
  local pixel_data = file:read(row_size * height)
  file:close()
  
  if not pixel_data or #pixel_data < row_size * height then
    print("BMP Parser: Could not read all pixel data")
    return nil, 0, 0
  end
  
  -- Convert pixels to waveform (each pixel = one sample)
  local waveform = {}
  local total_pixels = width * height
  
  print(string.format("BMP Parser: Converting %d pixels to samples...", total_pixels))
  
  for y = 0, height - 1 do
    -- BMP stores rows bottom-to-top by default, unless top_down
    local actual_y
    if top_down then
      actual_y = y
    else
      actual_y = height - 1 - y
    end
    
    for x = 0, width - 1 do
      local offset = actual_y * row_size + x * bytes_per_pixel + 1  -- +1 for Lua 1-indexing
      
      -- BMP stores pixels as BGR (not RGB)
      local b = string.byte(pixel_data, offset) or 0
      local g = string.byte(pixel_data, offset + 1) or 0
      local r = string.byte(pixel_data, offset + 2) or 0
      
      -- Calculate brightness as average of RGB
      local brightness = (r + g + b) / 3
      
      -- Convert brightness (0-255) to amplitude (-1.0 to 1.0)
      local amplitude = (brightness / 127.5) - 1.0
      
      table.insert(waveform, amplitude)
    end
  end
  
  print(string.format("BMP Parser: Generated %d samples from %dx%d image", #waveform, width, height))
  
  return waveform, width, height
end

-- Binary file converter for Win/Linux fallback (reads raw file bytes)
function PakettiImageToSampleConvertBinaryToWaveform(file_path)
  local file = io.open(file_path, "rb")
  if not file then
    print("Binary Converter: Could not open file")
    return nil, 0, 0
  end
  
  -- Get file size
  file:seek("end")
  local file_size = file:seek()
  file:seek("set", 0)
  
  -- Read entire file
  local file_data = file:read("*all")
  file:close()
  
  if not file_data or #file_data == 0 then
    print("Binary Converter: Could not read file data")
    return nil, 0, 0
  end
  
  print(string.format("Binary Converter: Processing %d bytes...", #file_data))
  
  -- Convert each byte to a sample
  local waveform = {}
  for i = 1, #file_data do
    local byte_value = string.byte(file_data, i) or 0
    -- Convert byte (0-255) to amplitude (-1.0 to 1.0)
    local amplitude = (byte_value / 127.5) - 1.0
    table.insert(waveform, amplitude)
  end
  
  print(string.format("Binary Converter: Generated %d samples from file bytes", #waveform))
  
  -- Return waveform with pseudo-dimensions (treat as 1D)
  return waveform, #waveform, 1
end

-- macOS sips converter - converts PNG/JPEG/GIF to BMP
function PakettiImageToSampleConvertViaSips(file_path)
  -- Generate temp file path for converted BMP
  local temp_path = os.tmpname() .. ".bmp"
  
  -- Build sips command
  local cmd = string.format('sips -s format bmp "%s" --out "%s" 2>/dev/null', file_path, temp_path)
  
  print("Sips Converter: Running: " .. cmd)
  
  local result = os.execute(cmd)
  
  -- os.execute returns different values in different Lua versions
  -- Lua 5.1: returns exit code (0 = success)
  -- Lua 5.2+: returns true/false, "exit", exit_code
  local success = (result == 0 or result == true)
  
  if success then
    -- Verify the file was created
    local test_file = io.open(temp_path, "rb")
    if test_file then
      test_file:close()
      print("Sips Converter: Successfully converted to: " .. temp_path)
      return temp_path, true  -- true = needs cleanup
    end
  end
  
  print("Sips Converter: Conversion failed")
  return nil, false
end

-- ImageMagick detection function - checks for 'magick' (v7+) or 'convert' (v6)
function PakettiImageToSampleCheckImageMagick()
  local platform = PakettiImageToSampleGetPlatform()
  
  -- Try 'magick' first (ImageMagick 7+)
  local cmd_check = (platform == "windows") and "magick -version 2>nul" or "magick -version 2>/dev/null"
  local handle = io.popen(cmd_check)
  if handle then
    local result = handle:read("*l")
    handle:close()
    if result and result:find("ImageMagick") then
      print("ImageMagick Check: Found 'magick' command (v7+)")
      return "magick"
    end
  end
  
  -- Try 'convert' (ImageMagick 6 or legacy)
  cmd_check = (platform == "windows") and "convert -version 2>nul" or "convert -version 2>/dev/null"
  handle = io.popen(cmd_check)
  if handle then
    local result = handle:read("*l")
    handle:close()
    if result and result:find("ImageMagick") then
      print("ImageMagick Check: Found 'convert' command (v6)")
      return "convert"
    end
  end
  
  print("ImageMagick Check: Not found")
  return nil
end

-- ImageMagick converter - converts PNG/JPEG/GIF to BMP
function PakettiImageToSampleConvertViaImageMagick(file_path, im_command)
  local platform = PakettiImageToSampleGetPlatform()
  local temp_path = os.tmpname() .. ".bmp"
  
  -- Build command based on ImageMagick version
  local cmd
  local null_redirect = (platform == "windows") and "2>nul" or "2>/dev/null"
  
  if im_command == "magick" then
    -- ImageMagick 7+ syntax
    cmd = string.format('magick "%s" -type TrueColor BMP3:"%s" %s', file_path, temp_path, null_redirect)
  else
    -- ImageMagick 6 syntax (convert command)
    cmd = string.format('convert "%s" -type TrueColor BMP3:"%s" %s', file_path, temp_path, null_redirect)
  end
  
  print("ImageMagick Converter: Running: " .. cmd)
  
  local result = os.execute(cmd)
  local success = (result == 0 or result == true)
  
  if success then
    -- Verify the file was created
    local test_file = io.open(temp_path, "rb")
    if test_file then
      test_file:close()
      print("ImageMagick Converter: Successfully converted to: " .. temp_path)
      return temp_path, true  -- true = needs cleanup
    end
  end
  
  print("ImageMagick Converter: Conversion failed")
  return nil, false
end

-- Raw data settings for dialog
local raw_data_settings = {
  bits = 8,           -- 8, 16, or 32
  channels = 1,       -- 1 = mono, 2 = stereo
  is_signed = false,  -- signed or unsigned
  skip_bytes = 0,     -- bytes to skip at start of file
  file_path = nil,    -- current file being processed
  file_size = 0       -- size of current file
}

-- Raw data dialog reference
local raw_data_dialog = nil

-- Convert raw data with user-specified settings
function PakettiImageToSampleConvertRawWithSettings(file_path, bits, channels, is_signed, skip_bytes)
  local file = io.open(file_path, "rb")
  if not file then
    print("Raw Converter: Could not open file")
    return nil, 0, 0
  end
  
  -- Get file size
  file:seek("end")
  local file_size = file:seek()
  file:seek("set", skip_bytes)
  
  -- Read file data after skipping header
  local data = file:read("*all")
  file:close()
  
  if not data or #data == 0 then
    print("Raw Converter: Could not read file data")
    return nil, 0, 0
  end
  
  print(string.format("Raw Converter: Processing %d bytes (skipped %d), %d-bit %s %s", 
    #data, skip_bytes, bits, is_signed and "signed" or "unsigned", 
    channels == 1 and "mono" or "stereo"))
  
  local bytes_per_sample = bits / 8
  local waveform = {}
  
  local i = 1
  while i <= #data - bytes_per_sample + 1 do
    local value = 0
    
    if bits == 8 then
      value = string.byte(data, i) or 0
      if is_signed then
        -- Interpret as signed (-128 to 127)
        if value >= 128 then value = value - 256 end
        value = value / 128.0
      else
        -- Interpret as unsigned (0 to 255)
        value = (value / 127.5) - 1.0
      end
      i = i + 1
      
    elseif bits == 16 then
      local b1, b2 = string.byte(data, i, i + 1)
      if b1 and b2 then
        -- Little-endian
        value = b1 + b2 * 256
        if is_signed then
          if value >= 32768 then value = value - 65536 end
          value = value / 32768.0
        else
          value = (value / 32767.5) - 1.0
        end
      end
      i = i + 2
      
    elseif bits == 32 then
      local b1, b2, b3, b4 = string.byte(data, i, i + 3)
      if b1 and b2 and b3 and b4 then
        if is_signed then
          -- Interpret as 32-bit signed integer
          value = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
          if value >= 2147483648 then value = value - 4294967296 end
          value = value / 2147483648.0
        else
          -- Interpret as 32-bit unsigned
          value = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
          value = (value / 2147483647.5) - 1.0
        end
      end
      i = i + 4
    end
    
    table.insert(waveform, value)
    
    -- If stereo, read second channel and average (or skip)
    if channels == 2 and i <= #data - bytes_per_sample + 1 then
      local value2 = 0
      if bits == 8 then
        value2 = string.byte(data, i) or 0
        if is_signed then
          if value2 >= 128 then value2 = value2 - 256 end
          value2 = value2 / 128.0
        else
          value2 = (value2 / 127.5) - 1.0
        end
        i = i + 1
      elseif bits == 16 then
        local b1, b2 = string.byte(data, i, i + 1)
        if b1 and b2 then
          value2 = b1 + b2 * 256
          if is_signed then
            if value2 >= 32768 then value2 = value2 - 65536 end
            value2 = value2 / 32768.0
          else
            value2 = (value2 / 32767.5) - 1.0
          end
        end
        i = i + 2
      elseif bits == 32 then
        local b1, b2, b3, b4 = string.byte(data, i, i + 3)
        if b1 and b2 and b3 and b4 then
          if is_signed then
            value2 = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
            if value2 >= 2147483648 then value2 = value2 - 4294967296 end
            value2 = value2 / 2147483648.0
          else
            value2 = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
            value2 = (value2 / 2147483647.5) - 1.0
          end
        end
        i = i + 4
      end
      -- Average the two channels into mono
      waveform[#waveform] = (value + value2) / 2.0
    end
  end
  
  print(string.format("Raw Converter: Generated %d samples", #waveform))
  
  return waveform, #waveform, 1
end

-- Calculate preview sample count for raw data dialog
local function calculate_raw_preview(file_size, skip_bytes, bits, channels)
  local data_size = file_size - skip_bytes
  if data_size < 0 then data_size = 0 end
  local bytes_per_sample = (bits / 8) * channels
  local sample_count = math.floor(data_size / bytes_per_sample)
  return sample_count
end

-- Show raw data settings dialog and return user's choice
function PakettiImageToSampleShowRawDataDialog(file_path, callback)
  if raw_data_dialog and raw_data_dialog.visible then
    raw_data_dialog:close()
  end
  
  -- Get file size
  local file = io.open(file_path, "rb")
  if not file then
    renoise.app():show_status("Error: Could not open file")
    return
  end
  file:seek("end")
  local file_size = file:seek()
  file:close()
  
  -- Store file info
  raw_data_settings.file_path = file_path
  raw_data_settings.file_size = file_size
  
  -- Reset to defaults
  raw_data_settings.bits = 8
  raw_data_settings.channels = 1
  raw_data_settings.is_signed = false
  raw_data_settings.skip_bytes = 0
  
  local vb = renoise.ViewBuilder()
  
  -- Calculate initial preview
  local initial_samples = calculate_raw_preview(file_size, 0, 8, 1)
  local initial_duration = initial_samples / 44100
  
  local function update_preview()
    local samples = calculate_raw_preview(
      raw_data_settings.file_size, 
      raw_data_settings.skip_bytes, 
      raw_data_settings.bits, 
      raw_data_settings.channels
    )
    local duration = samples / 44100
    local duration_str
    if duration < 1 then
      duration_str = string.format("%.0fms", duration * 1000)
    elseif duration < 60 then
      duration_str = string.format("%.1fs", duration)
    else
      local minutes = math.floor(duration / 60)
      local seconds = duration - (minutes * 60)
      duration_str = string.format("%dm %.1fs", minutes, seconds)
    end
    vb.views.preview_text.text = string.format("Preview: %d samples (%s at 44100 Hz)", samples, duration_str)
  end
  
  local dialog_content = vb:column {
    margin = 10,
    spacing = 8,
    
    vb:text {
      text = "Raw Data Import Settings",
      font = "bold"
    },
    
    vb:text {
      text = string.format("File: %s (%d bytes)", 
        file_path:match("([^/\\]+)$") or file_path, file_size),
      style = "disabled"
    },
    
    vb:row {
      spacing = 8,
      vb:text { text = "Bits per sample:", width = 100 },
      vb:switch {
        id = "bits_switch",
        width = 150,
        items = {"8-bit", "16-bit", "32-bit"},
        value = 1,
        notifier = function(value)
          local bits_map = {8, 16, 32}
          raw_data_settings.bits = bits_map[value]
          -- Default signed for 16/32 bit
          if value > 1 then
            raw_data_settings.is_signed = true
            vb.views.signed_check.value = true
          else
            raw_data_settings.is_signed = false
            vb.views.signed_check.value = false
          end
          update_preview()
        end
      }
    },
    
    vb:row {
      spacing = 8,
      vb:text { text = "Channels:", width = 100 },
      vb:switch {
        id = "channels_switch",
        width = 150,
        items = {"Mono", "Stereo"},
        value = 1,
        notifier = function(value)
          raw_data_settings.channels = value
          update_preview()
        end
      }
    },
    
    vb:row {
      spacing = 8,
      vb:text { text = "Signed:", width = 100 },
      vb:checkbox {
        id = "signed_check",
        value = false,
        notifier = function(value)
          raw_data_settings.is_signed = value
        end
      },
      vb:text { text = "(typically signed for 16/32-bit)" }
    },
    
    vb:row {
      spacing = 8,
      vb:text { text = "Skip header:", width = 100 },
      vb:valuebox {
        id = "skip_valuebox",
        min = 0,
        max = math.max(0, file_size - 1),
        value = 0,
        notifier = function(value)
          raw_data_settings.skip_bytes = value
          update_preview()
        end
      },
      vb:text { text = "bytes" }
    },
    
    vb:space { height = 8 },
    
    vb:text {
      id = "preview_text",
      text = string.format("Preview: %d samples (%.1fs at 44100 Hz)", initial_samples, initial_duration),
      style = "strong"
    },
    
    vb:space { height = 8 },
    
    vb:horizontal_aligner {
      mode = "right",
      spacing = 8,
      
      vb:button {
        text = "Cancel",
        width = 80,
        notifier = function()
          if raw_data_dialog then
            raw_data_dialog:close()
            raw_data_dialog = nil
          end
        end
      },
      
      vb:button {
        text = "OK",
        width = 80,
        notifier = function()
          if raw_data_dialog then
            raw_data_dialog:close()
            raw_data_dialog = nil
          end
          -- Call the callback with the settings
          if callback then
            callback(
              raw_data_settings.file_path,
              raw_data_settings.bits,
              raw_data_settings.channels,
              raw_data_settings.is_signed,
              raw_data_settings.skip_bytes
            )
          end
        end
      }
    }
  }
  
  raw_data_dialog = renoise.app():show_custom_dialog("Raw Data Import", dialog_content, my_keyhandler_func)
end

-- Main conversion function with platform-aware logic
-- Returns: waveform, width, height, or "show_raw_dialog" to indicate dialog needed
function PakettiImageToSampleConvertImageToWaveform(image_path, skip_raw_dialog)
  if not image_path then
    -- Create a default sine wave for demonstration
    local samples = 512
    local waveform_data = {}
    for i = 0, samples - 1 do
      local phase = (i / samples) * 2 * math.pi
      local amplitude = math.sin(phase)
      table.insert(waveform_data, amplitude)
    end
    current_conversion_method = "default"
    return waveform_data, 512, 1
  end
  
  -- Get file extension
  local ext = image_path:lower():match("%.([^%.]+)$") or ""
  local platform = PakettiImageToSampleGetPlatform()
  
  print(string.format("Image Converter: File=%s, Extension=%s, Platform=%s", image_path, ext, platform))
  
  -- BMP: Direct parsing with pure Lua
  if ext == "bmp" then
    print("Image Converter: Using BMP pixel parser")
    current_conversion_method = "bmp_pixels"
    local waveform, w, h = PakettiImageToSampleParseBMPPixels(image_path)
    if waveform and #waveform > 0 then
      return waveform, w, h
    end
    -- Fall through to other methods if BMP parsing fails
    print("Image Converter: BMP parsing failed, trying other methods")
  end
  
  -- PNG/JPEG/GIF on macOS: Convert via sips, then parse BMP
  if platform == "macos" and (ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "gif") then
    print("Image Converter: Using sips conversion on macOS")
    local bmp_path, needs_cleanup = PakettiImageToSampleConvertViaSips(image_path)
    if bmp_path then
      current_conversion_method = "sips_pixels"
      local waveform, w, h = PakettiImageToSampleParseBMPPixels(bmp_path)
      if needs_cleanup then
        os.remove(bmp_path)
        print("Image Converter: Cleaned up temp file: " .. bmp_path)
      end
      if waveform and #waveform > 0 then
        return waveform, w, h
      end
    end
    -- Fall through if sips fails
    print("Image Converter: Sips conversion failed, trying other methods")
  end
  
  -- PNG/JPEG/GIF on Windows/Linux: Try ImageMagick first
  if (platform == "windows" or platform == "linux") and (ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "gif") then
    local im_command = PakettiImageToSampleCheckImageMagick()
    if im_command then
      print("Image Converter: Using ImageMagick conversion")
      local bmp_path, needs_cleanup = PakettiImageToSampleConvertViaImageMagick(image_path, im_command)
      if bmp_path then
        current_conversion_method = "imagemagick_pixels"
        local waveform, w, h = PakettiImageToSampleParseBMPPixels(bmp_path)
        if needs_cleanup then
          os.remove(bmp_path)
          print("Image Converter: Cleaned up temp file: " .. bmp_path)
        end
        if waveform and #waveform > 0 then
          return waveform, w, h
        end
      end
      print("Image Converter: ImageMagick conversion failed, trying raw data")
    else
      print("Image Converter: ImageMagick not available")
    end
    
    -- No ImageMagick or it failed - show raw data dialog unless skipped
    if not skip_raw_dialog then
      print("Image Converter: Requesting raw data dialog")
      return "show_raw_dialog", 0, 0
    end
  end
  
  -- Fallback: Binary conversion (8-bit unsigned) when other methods fail or skipped dialog
  print("Image Converter: Using binary fallback (8-bit unsigned)")
  current_conversion_method = "binary"
  return PakettiImageToSampleConvertBinaryToWaveform(image_path)
end

-- Canvas render function for waveform display
function PakettiImageToSampleRenderWaveform(ctx)
  local width = WAVEFORM_CANVAS_WIDTH
  local height = WAVEFORM_CANVAS_HEIGHT
  
  -- Clear canvas
  ctx:clear_rect(0, 0, width, height)
  
  -- Draw grid lines
  ctx.stroke_color = COLOR_GRID
  ctx.line_width = 1
  
  -- Vertical grid lines
  for i = 0, 10 do
    local x = (i / 10) * width
    ctx:begin_path()
    ctx:move_to(x, 0)
    ctx:line_to(x, height)
    ctx:stroke()
  end
  
  -- Horizontal grid lines  
  for i = 0, 4 do
    local y = (i / 4) * height
    ctx:begin_path()
    ctx:move_to(0, y)
    ctx:line_to(width, y)
    ctx:stroke()
  end
  
  -- Draw center line
  ctx.stroke_color = COLOR_CENTER_LINE
  ctx.line_width = 2
  local center_y = height / 2
  ctx:begin_path()
  ctx:move_to(0, center_y)
  ctx:line_to(width, center_y)
  ctx:stroke()
  
  -- Draw waveform
  if current_sample_data and #current_sample_data > 0 then
    ctx.stroke_color = COLOR_WAVEFORM
    ctx.line_width = 2
    ctx:begin_path()
    
    local sample_count = #current_sample_data
    for x = 0, width - 1 do
      local sample_index = math.floor((x / width) * sample_count) + 1
      if sample_index <= sample_count then
        local amplitude = current_sample_data[sample_index]
        local y = center_y - (amplitude * center_y)
        
        if x == 0 then
          ctx:move_to(x, y)
        else
          ctx:line_to(x, y)
        end
      end
    end
    
    ctx:stroke()
  end
end

-- Get image dimensions and file info
function PakettiImageToSampleGetImageInfo(file_path)
  local file = io.open(file_path, "rb")
  if not file then return nil end
  
  -- Get file size
  file:seek("end")
  local file_size = file:seek()
  file:seek("set", 0)
  
  local width, height = 0, 0
  local format = "Unknown"
  
  -- Read first few bytes to determine format
  local header = file:read(10) -- Read a bit more for GIF detection
  file:seek("set", 0)
  
  if header then
    -- Check PNG signature
    if header:sub(1, 8) == "\137\80\78\71\13\10\26\10" then
      format = "PNG"
      file:seek("set", 16) -- Skip to IHDR width/height
      local width_bytes = file:read(4)
      local height_bytes = file:read(4)
      if width_bytes and height_bytes and #width_bytes == 4 and #height_bytes == 4 then
        -- PNG uses big-endian 32-bit integers
        local w1, w2, w3, w4 = string.byte(width_bytes, 1, 4)
        local h1, h2, h3, h4 = string.byte(height_bytes, 1, 4)
        width = w1 * 16777216 + w2 * 65536 + w3 * 256 + w4
        height = h1 * 16777216 + h2 * 65536 + h3 * 256 + h4
      end
    -- Check BMP signature
    elseif header:sub(1, 2) == "BM" then
      format = "BMP"
      file:seek("set", 18) -- Skip to width/height in BMP header
      local width_bytes = file:read(4)
      local height_bytes = file:read(4)
      if width_bytes and height_bytes and #width_bytes == 4 and #height_bytes == 4 then
        -- BMP uses little-endian 32-bit integers
        local w1, w2, w3, w4 = string.byte(width_bytes, 1, 4)
        local h1, h2, h3, h4 = string.byte(height_bytes, 1, 4)
        width = w4 * 16777216 + w3 * 65536 + w2 * 256 + w1
        height = h4 * 16777216 + h3 * 65536 + h2 * 256 + h1
      end
    -- Check JPEG signature
    elseif header:sub(1, 3) == "\255\216\255" then
      format = "JPEG"
      -- Scan for SOF markers to get dimensions
      -- SOF0 (0xFFC0) = baseline, SOF2 (0xFFC2) = progressive
      file:seek("set", 0)
      local data = file:read(65536) -- Read more data for files with large EXIF
      if data then
        -- Search for SOF0 or SOF2 markers
        local sof_pos = data:find("\255\192") -- SOF0
        if not sof_pos then
          sof_pos = data:find("\255\194") -- SOF2 (progressive)
        end
        if sof_pos and sof_pos + 8 <= #data then
          local h1, h2 = string.byte(data, sof_pos + 5), string.byte(data, sof_pos + 6)
          local w1, w2 = string.byte(data, sof_pos + 7), string.byte(data, sof_pos + 8)
          height = h1 * 256 + h2
          width = w1 * 256 + w2
        end
      end
    -- Check GIF signature  
    elseif header:sub(1, 6) == "GIF87a" or header:sub(1, 6) == "GIF89a" then
      format = "GIF"
      file:seek("set", 6) -- GIF dimensions are at bytes 6-9
      local dim_bytes = file:read(4)
      if dim_bytes and #dim_bytes == 4 then
        local w1, w2, h1, h2 = string.byte(dim_bytes, 1, 4)
        width = w1 + w2 * 256  -- GIF uses little-endian
        height = h1 + h2 * 256
      end
    end
  end
  
  file:close()
  
  -- Format file size
  local size_str = ""
  if file_size < 1024 then
    size_str = file_size .. " bytes"
  elseif file_size < 1024 * 1024 then
    size_str = string.format("%.1f KB", file_size / 1024)
  else
    size_str = string.format("%.1f MB", file_size / (1024 * 1024))
  end
  
  return {
    width = width,
    height = height,
    format = format,
    file_size = file_size,
    size_string = size_str
  }
end

-- Helper function to format sample count with duration
local function format_sample_info(sample_count, sample_rate)
  sample_rate = sample_rate or 44100
  local duration_seconds = sample_count / sample_rate
  local duration_str
  if duration_seconds < 1 then
    duration_str = string.format("%.0fms", duration_seconds * 1000)
  elseif duration_seconds < 60 then
    duration_str = string.format("%.1fs", duration_seconds)
  else
    local minutes = math.floor(duration_seconds / 60)
    local seconds = duration_seconds - (minutes * 60)
    duration_str = string.format("%dm %.1fs", minutes, seconds)
  end
  return string.format("%d samples, %s", sample_count, duration_str)
end

-- Helper function to get conversion method description
local function get_conversion_method_description()
  if current_conversion_method == "bmp_pixels" then
    return "pixel-based"
  elseif current_conversion_method == "sips_pixels" then
    return "pixel-based via sips"
  elseif current_conversion_method == "imagemagick_pixels" then
    return "pixel-based via ImageMagick"
  elseif current_conversion_method == "raw_custom" then
    local bits_str = tostring(raw_data_settings.bits) .. "-bit"
    local signed_str = raw_data_settings.is_signed and "signed" or "unsigned"
    return string.format("raw data (%s %s)", bits_str, signed_str)
  elseif current_conversion_method == "binary" then
    return "raw data (8-bit unsigned)"
  else
    return ""
  end
end

-- Callback for after raw data dialog is closed with OK
local function on_raw_data_dialog_complete(file_path, bits, channels, is_signed, skip_bytes)
  -- Convert with user settings
  current_conversion_method = "raw_custom"
  current_sample_data = PakettiImageToSampleConvertRawWithSettings(file_path, bits, channels, is_signed, skip_bytes)
  
  if current_sample_data and #current_sample_data > 0 then
    local filename = file_path:match("([^/\\]+)$") or file_path
    local sample_info = format_sample_info(#current_sample_data, 44100)
    local method_str = get_conversion_method_description()
    
    local status_msg
    if current_image_info and current_image_info.width > 0 and current_image_info.height > 0 then
      status_msg = string.format("Loaded %dx%d %s: %s (%s)", 
        current_image_info.width, current_image_info.height, 
        current_image_info.format, sample_info, method_str)
    else
      status_msg = string.format("Loaded %s: %s (%s)", filename, sample_info, method_str)
    end
    
    renoise.app():show_status(status_msg)
    
    -- Show the main dialog now that we have data
    PakettiImageToSampleShowDialog()
  else
    renoise.app():show_status("Error: Could not convert raw data")
  end
end

-- Load image file and convert to waveform (now called before dialog opens)
-- Returns: true if loaded successfully (or dialog shown), false on error
function PakettiImageToSampleLoadImage(file_path, show_dialog_after)
  if show_dialog_after == nil then show_dialog_after = false end
  
  if not file_path then return false end
  
  renoise.app():show_status("Loading image: " .. file_path)
  
  -- Check if file exists and get image info
  local file = io.open(file_path, "r")
  if not file then
    renoise.app():show_status("Error: Could not open image file")
    return false
  end
  file:close()
  
  -- Get image metadata
  current_image_info = PakettiImageToSampleGetImageInfo(file_path)
  
  -- Store the image path
  loaded_image_bitmap = file_path
  
  -- Convert image to waveform data
  local result = PakettiImageToSampleConvertImageToWaveform(file_path)
  
  -- Check if we need to show the raw data dialog
  if result == "show_raw_dialog" then
    renoise.app():show_status("Image format requires manual settings...")
    -- Show dialog with callback that will complete the load and show main dialog
    PakettiImageToSampleShowRawDataDialog(file_path, on_raw_data_dialog_complete)
    return true  -- Return true because dialog is being shown
  end
  
  -- Normal case: we have waveform data
  current_sample_data = result
  
  if not current_sample_data or #current_sample_data == 0 then
    renoise.app():show_status("Error: Could not convert image")
    return false
  end
  
  local filename = file_path:match("([^/\\]+)$") or file_path
  local sample_info = format_sample_info(#current_sample_data, 44100)
  local method_str = get_conversion_method_description()
  
  local status_msg
  if current_image_info and current_image_info.width > 0 and current_image_info.height > 0 then
    status_msg = string.format("Loaded %dx%d %s: %s (%s)", 
      current_image_info.width, current_image_info.height, 
      current_image_info.format, sample_info, method_str)
  else
    status_msg = string.format("Loaded %s: %s (%s)", filename, sample_info, method_str)
  end
  
  renoise.app():show_status(status_msg)
  
  -- Show dialog if requested (for the normal flow)
  if show_dialog_after then
    PakettiImageToSampleShowDialog()
  end
  
  return true
end

-- Export waveform as sample
function PakettiImageToSampleExportToSample()
  if not current_sample_data then
    renoise.app():show_status("No waveform data to export")
    return
  end
  
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  -- Ensure the instrument has at least one sample
  if #instrument.samples == 0 then
    -- Create a new sample if none exists
    instrument:insert_sample_at(1)
  end
  
  local sample = instrument.samples[1]
  local sample_buffer = sample.sample_buffer
  
  -- Create new sample buffer
  sample_buffer:create_sample_data(44100, 16, 1, #current_sample_data)
  
  -- Copy waveform data to sample buffer
  if sample_buffer.has_sample_data then
    sample_buffer:prepare_sample_data_changes()
    
    for i = 1, #current_sample_data do
      sample_buffer:set_sample_data(1, i, current_sample_data[i])
    end
    
    sample_buffer:finalize_sample_data_changes()
  end
  
  -- Set a nice name for the sample
  if loaded_image_bitmap then
    local filename = loaded_image_bitmap:match("([^/\\]+)$") or "image"
    local basename = filename:match("(.+)%..+$") or filename -- Remove extension
    sample.name = "IMG_" .. basename
  end
  
  -- Apply Paketti Loader settings (interpolation, oversampling, autofade, autoseek, oneshot, loop_mode, NNA, loop_exit)
  PakettiInjectApplyLoaderSettings(sample)
  
  -- Set loop points specific to this waveform
  sample.loop_start = 1
  sample.loop_end = #current_sample_data
  
  -- Show detailed export status
  local sample_info = format_sample_info(#current_sample_data, 44100)
  renoise.app():show_status(string.format("Exported to sample: %s (%s at 44100 Hz)", 
    sample.name or "Sample 01", sample_info))
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Create the image to sample dialog
function PakettiImageToSampleShowDialog()
  if image_to_sample_dialog and image_to_sample_dialog.visible then
    image_to_sample_dialog:close()
  end
  
  -- Create fresh ViewBuilder for this dialog instance
  local vb = renoise.ViewBuilder()
  
  -- Image data should already be loaded before dialog opens
  
  -- Build info display text
  local info_text = "No image loaded"
  if loaded_image_bitmap and current_sample_data then
    local filename = loaded_image_bitmap:match("([^/\\]+)$") or loaded_image_bitmap
    local sample_info = format_sample_info(#current_sample_data, 44100)
    local method_str = get_conversion_method_description()
    
    if current_image_info and current_image_info.width > 0 and current_image_info.height > 0 then
      info_text = string.format("%s - %dx%d %s - %s (%s)", 
        filename, current_image_info.width, current_image_info.height, 
        current_image_info.format, sample_info, method_str)
    else
      info_text = string.format("%s - %s (%s)", filename, sample_info, method_str)
    end
  end
  
  -- Create dialog content
  local dialog_content = vb:column {
      -- Image info section
      vb:horizontal_aligner {
        mode = "center",
        vb:text {
          id = "image_info_display",
          text = info_text,
          style = "strong"
        }
      },
      
    -- Waveform display section  
    vb:column {
      
      vb:canvas {
        id = "waveform_canvas",
        width = WAVEFORM_CANVAS_WIDTH,
        height = WAVEFORM_CANVAS_HEIGHT,
        mode = "plain",
        render = PakettiImageToSampleRenderWaveform
      }
    },
    
    -- Control buttons
    vb:horizontal_aligner {
      mode = "center",
      
      vb:button {
        text = "Load Different Image",
        width = 140,
        notifier = function()
          local file_path = renoise.app():prompt_for_filename_to_read({"*.png", "*.bmp", "*.jpg", "*.jpeg", "*.gif"}, "Select different image file")
          if file_path then
            -- Close current dialog and reload with new file
            -- This handles the case where raw data dialog might be shown
            if image_to_sample_dialog then
              image_to_sample_dialog:close()
              image_to_sample_dialog = nil
            end
            -- Load new file and show dialog (handles raw dialog case via callback)
            PakettiImageToSampleLoadImage(file_path, true)
          end
        end
      },
      
      vb:button {
        text = "Export to Sample",
        width = 120,
        notifier = function()
          PakettiImageToSampleExportToSample()
        end
      },
      
      vb:button {
        text = "Close",
        width = 80,
        notifier = function()
          if image_to_sample_dialog then
            image_to_sample_dialog:close()
          end
        end
      }
    }
  }
  
  -- Create and show dialog
  image_to_sample_dialog = renoise.app():show_custom_dialog(DIALOG_TITLE, dialog_content, my_keyhandler_func)
  
  -- Store canvas reference for updates
  waveform_canvas_view = vb.views.waveform_canvas
  
  -- Ensure Renoise gets keyboard focus
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Menu entry function - now prompts for image first
function PakettiImageToSampleStart()
  -- Prompt for image file first
  local file_path = renoise.app():prompt_for_filename_to_read({"*.png", "*.bmp", "*.jpg", "*.jpeg", "*.gif"}, "Select image file to convert to waveform")
  
  if not file_path then
    renoise.app():show_status("Image to Sample: Cancelled")
    return
  end
  
  -- Load and convert the image (show_dialog_after=true handles showing dialog)
  -- For raw dialog case, the callback will show the main dialog
  PakettiImageToSampleLoadImage(file_path, true)
end


renoise.tool():add_keybinding {
  name = "Global:Paketti:Paketti Image to Sample Converter",
  invoke = function()
    PakettiImageToSampleStart()
  end
}

-- File import hooks for drag & drop and file loading
-- Global function for use by PakettiImport.lua file import hook
function PakettiImageToSampleImportHook(file_path)
  -- Load the image and show dialog directly (show_dialog_after=true handles showing dialog)
  -- For raw dialog case, the callback will show the main dialog
  return PakettiImageToSampleLoadImage(file_path, true)
end

-- Create integration for image formats
-- NOTE: Image file import hook registration moved to PakettiImport.lua for centralized management
