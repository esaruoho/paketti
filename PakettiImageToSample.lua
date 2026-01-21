local DIALOG_TITLE = "Paketti Image to Sample Converter"

-- Global variables for the image to sample dialog
local image_to_sample_dialog = nil
local loaded_image_bitmap = nil
local current_sample_data = nil
local waveform_canvas_view = nil
local current_image_info = nil

-- Canvas dimensions
local WAVEFORM_CANVAS_WIDTH = 800
local WAVEFORM_CANVAS_HEIGHT = 200

-- Color constants for canvas drawing
local COLOR_BACKGROUND = {0, 0, 0, 255}
local COLOR_WAVEFORM = {0, 255, 0, 255}
local COLOR_GRID = {0, 64, 0, 128}
local COLOR_CENTER_LINE = {128, 128, 128, 255}

-- Convert image brightness to waveform amplitude
function PakettiImageToSampleConvertImageToWaveform(image_path)
  if not image_path then
    -- Create a default sine wave for demonstration
    local samples = 512  -- Short single-cycle waveform
    local waveform_data = {}
    
    for i = 0, samples - 1 do
      local phase = (i / samples) * 2 * math.pi
      local amplitude = math.sin(phase)
      table.insert(waveform_data, amplitude)
    end
    
    return waveform_data
  end
  
  -- For actual image processing, we'd need to:
  -- 1. Load the image file and read pixel data
  -- 2. Convert pixel brightness/color to amplitude values
  -- 3. Return the waveform data array
  
  -- Since Lua doesn't have built-in image processing, we'll analyze
  -- the binary data of the image file to create a unique waveform
  local samples = 1024
  local waveform_data = {}
  
  -- Read some bytes from the image file for analysis
  local file = io.open(image_path, "rb")
  if not file then
    -- Fallback to default sine wave if file can't be read
    for i = 0, samples - 1 do
      local phase = (i / samples) * 2 * math.pi
      local amplitude = math.sin(phase)
      table.insert(waveform_data, amplitude)
    end
    return waveform_data
  end
  
  -- Read first 1024 bytes of the file for analysis
  local file_data = file:read(1024)
  file:close()
  
  if not file_data then file_data = "" end
  
  -- Convert file bytes to waveform amplitudes
  for i = 0, samples - 1 do
    local byte_index = (i % #file_data) + 1
    local byte_value = 0
    
    if i < #file_data then
      byte_value = string.byte(file_data, byte_index) or 0
    end
    
    -- Normalize byte value (0-255) to amplitude (-1 to 1)
    local amplitude = (byte_value / 127.5) - 1.0
    
    -- Add some smoothing with neighboring values
    if i > 0 and i < samples - 1 then
      local prev_byte = string.byte(file_data, math.max(1, byte_index - 1)) or 0
      local next_byte = string.byte(file_data, math.min(#file_data, byte_index + 1)) or 0
      local prev_amp = (prev_byte / 127.5) - 1.0
      local next_amp = (next_byte / 127.5) - 1.0
      amplitude = (prev_amp * 0.25 + amplitude * 0.5 + next_amp * 0.25)
    end
    
    table.insert(waveform_data, amplitude)
  end
  
  return waveform_data
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
      -- Scan for SOF0 marker (0xFFC0) to get dimensions
      file:seek("set", 0)
      local data = file:read(1024) -- Read more data to find SOF marker
      if data then
        local sof_pos = data:find("\255\192") -- SOF0 marker
        if sof_pos and sof_pos + 7 <= #data then
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

-- Load image file and convert to waveform (now called before dialog opens)
function PakettiImageToSampleLoadImage(file_path)
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
  current_sample_data = PakettiImageToSampleConvertImageToWaveform(file_path)
  
  local filename = file_path:match("([^/\\]+)$") or file_path
  local info_str = ""
  if current_image_info then
    info_str = string.format(" (%dx%d, %s)", current_image_info.width, current_image_info.height, current_image_info.size_string)
  end
  renoise.app():show_status("Image loaded: " .. filename .. info_str .. " (" .. #current_sample_data .. " samples generated)")
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
  
  renoise.app():show_status("Waveform exported to sample: " .. (sample.name or "Sample 01"))
  
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
  
  -- Create dialog content
  local dialog_content = vb:column {
      -- Image info section
      vb:horizontal_aligner {
        mode = "center",
        vb:text {
          id = "image_info_display",
          text = loaded_image_bitmap and current_image_info and 
                 string.format("%s - %dx%d pixels, %s (%s)", 
                               loaded_image_bitmap:match("([^/\\]+)$") or loaded_image_bitmap,
                               current_image_info.width, current_image_info.height, 
                               current_image_info.format, current_image_info.size_string) or "No image loaded",
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
          if file_path and PakettiImageToSampleLoadImage(file_path) then
            -- Update combined image info display
            local info_view = vb.views.image_info_display
            if info_view and current_image_info then
              local filename = file_path:match("([^/\\]+)$") or file_path
              info_view.text = string.format("%s - %dx%d pixels, %s (%s)", 
                                           filename, current_image_info.width, current_image_info.height, 
                                           current_image_info.format, current_image_info.size_string)
            end
            -- Refresh canvas
            if waveform_canvas_view then
              waveform_canvas_view:update()
            end
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
  
  -- Load and convert the image
  if PakettiImageToSampleLoadImage(file_path) then
    -- Open dialog with waveform ready
    PakettiImageToSampleShowDialog()
  end
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
  -- Load the image and show dialog directly
  if PakettiImageToSampleLoadImage(file_path) then
    PakettiImageToSampleShowDialog()
    return true
  end
  return false
end

-- Create integration for image formats
-- NOTE: Image file import hook registration moved to PakettiImport.lua for centralized management
