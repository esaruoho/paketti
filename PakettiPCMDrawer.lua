-- Advanced PCM Wave Editor with Zoom, Interpolation, and Multiple File Formats
-- Features: .bin/.wav export, zoom/scroll, interpolation smoothing, wavetable support

local vb = renoise.ViewBuilder()
local DIALOG_TITLE = "Paketti Advanced PCM Wave Editor"

-- Editor state
local wave_size_options = {32, 64, 128, 256, 512, 1024}
local wave_size = 512
local wave_data = table.create()
for i = 1, wave_size do wave_data[i] = 32768 end

local selected_sample_index = -1
local is_drawing = false
local hex_buttons = {}
local pcm_dialog = nil
local waveform_canvas = nil
local dialog_initialized = false
local selection_info_view = nil
local dialog_rebuilding = false  -- Flag to prevent dropdown from triggering during rebuild

-- UI element references for dynamic updates
local wavetable_count_text = nil
local cursor_step_slider = nil
local cursor_step_text = nil

-- Cursor control settings
local cursor_width = 1  -- Default width of cursor (number of samples to affect)
local cursor_step_size = 1000  -- Default step size for arrow keys

-- Mouse and selection state
local selection_start = -1
local selection_end = -1
local selection_dragging = false
local selection_info_view = nil

-- Mouse tracking for smooth drawing
local last_mouse_x = -1
local last_mouse_y = -1
local last_sample_index = -1

-- Zoom and pan state
local zoom_factor = 1.0
local pan_offset = 0
local min_zoom = 0.25
local max_zoom = 8.0

-- Canvas display state
local show_sample_points = true
local canvas_interpolation_mode = "linear" -- "linear", "cubic", "bezier" for canvas display

-- Sample export settings (separate from canvas display)
local sample_interpolation_mode = "linear" -- "none", "linear", "cubic", "sinc"
local sample_oversample_enabled = true

-- Wavetable state
local wavetable_waves = {}
local current_wave_index = 1
local wavetable_size = 512  -- Match the main wave editor size
local wavetable_canvas_width = 1024

-- Hex editor state
local hex_editor_page = 0
local hex_samples_per_page = 128  -- 8 rows × 16 columns = 128 samples per page
local hex_items_per_row = 16
local hex_textfield_width = 32  -- Width of hex editor textfields

-- Initialize empty wavetable (no default wave)
-- wavetable_waves starts empty - waves are added when user clicks "Add Current to Wavetable"

-- Generate basic waveforms
function PCMDrawerGenerateWaveform(type, target_data, size)
  target_data = target_data or wave_data
  size = size or wave_size
  
  for i = 1, size do
    local phase = (i - 1) / size
    if type == "sine" then
      target_data[i] = math.floor((math.sin(phase * math.pi * 2) * 32767) + 32768)
    elseif type == "square" then
      target_data[i] = i <= size / 2 and 65535 or 0
    elseif type == "saw" then
      target_data[i] = math.floor(phase * 65535)
    elseif type == "triangle" then
      if phase < 0.25 then
        -- 0.5 to 1.0 (first quarter)
        target_data[i] = math.floor((0.5 + phase * 2) * 65535)
      elseif phase < 0.75 then
        -- 1.0 to 0.0 (middle half)
        target_data[i] = math.floor((1.0 - (phase - 0.25) * 2) * 65535)
      else
        -- 0.0 to 0.5 (last quarter)
        target_data[i] = math.floor((phase - 0.75) * 2 * 65535)
      end
    elseif type == "noise" then
      target_data[i] = math.random(0, 65535)
    end
  end
  selected_sample_index = -1
end

-- Cubic interpolation function
function PCMDrawerCubicInterpolate(y0, y1, y2, y3, mu)
  local mu2 = mu * mu
  local a0 = y3 - y2 - y0 + y1
  local a1 = y0 - y1 - a0
  local a2 = y2 - y0
  local a3 = y1
  return a0 * mu * mu2 + a1 * mu2 + a2 * mu + a3
end

-- Bezier curve interpolation
function PCMDrawerBezierInterpolate(p0, p1, p2, p3, t)
  local t2 = t * t
  local t3 = t2 * t
  local mt = 1 - t
  local mt2 = mt * mt
  local mt3 = mt2 * mt
  return mt3 * p0 + 3 * mt2 * t * p1 + 3 * mt * t2 * p2 + t3 * p3
end

-- Hex editor functions (need to be defined before mouse handler)
function PCMDrawerUpdateHexDisplay()
  if not hex_buttons then return end
  
  -- Only update buttons that exist on current page - selective updates only
  local current_page = hex_editor_page
  local start_sample = current_page * hex_samples_per_page + 1
  local end_sample = math.min(start_sample + hex_samples_per_page - 1, wave_size)
  
  for idx = start_sample, end_sample do
    if hex_buttons[idx] then
      hex_buttons[idx].text = string.format("%04X", wave_data[idx])
    end
  end
end

function PCMDrawerHighlightSample(idx)
  -- Note: TextFields don't have a color property according to the API,
  -- so we only track the selected sample index for waveform visualization
  if idx >= 1 and idx <= wave_size then
    selected_sample_index = idx
    
    -- No automatic page navigation - let user navigate manually
    -- This improves performance significantly
  end
end

-- Canvas rendering function with zoom, pan, and interpolation
function PCMDrawerRenderWaveform(ctx)
  local w, h = wavetable_canvas_width, ctx.size.height  -- Use configurable width
  ctx:clear_rect(0, 0, w, h)

  -- Calculate visible range based on zoom and pan
  local visible_start = math.max(1, math.floor(pan_offset + 1))
  local visible_end = math.min(wave_size, math.floor(pan_offset + wave_size / zoom_factor))
  local visible_samples = visible_end - visible_start + 1

  if visible_samples <= 0 then return end

  -- Draw grid
  ctx.stroke_color = {0, 64, 0, 255}
  ctx.line_width = 1
  for i = 0, 10 do
    local x = (i / 10) * w
    ctx:begin_path()
    ctx:move_to(x, 0)
    ctx:line_to(x, h)
    ctx:stroke()
  end
  for i = 0, 10 do
    local y = (i / 10) * h
    ctx:begin_path()
    ctx:move_to(0, y)
    ctx:line_to(w, y)
    ctx:stroke()
  end

  -- Draw zero line (center)
  ctx.stroke_color = {128, 128, 128, 255}
  ctx.line_width = 1
  local center_y = h / 2
  ctx:begin_path()
  ctx:move_to(0, center_y)
  ctx:line_to(w, center_y)
  ctx:stroke()

  -- Draw waveform with canvas interpolation modes
  ctx.stroke_color = {0, 255, 0, 255}
  ctx.line_width = 2
  ctx:begin_path()

  -- Draw waveform across full canvas width with selected interpolation
  if canvas_interpolation_mode == "linear" then
    -- Linear interpolation across full canvas width
    for pixel = 0, w - 1 do
      local sample_pos = visible_start + (pixel / (w - 1)) * (visible_samples - 1)
      local i = math.floor(sample_pos)
      local frac = sample_pos - i
      local i1 = math.max(1, math.min(wave_size, i))
      local i2 = math.max(1, math.min(wave_size, i + 1))
      
      -- Linear interpolation between samples
      local interp_value = wave_data[i1] + frac * (wave_data[i2] - wave_data[i1])
      
      local x = pixel
      local y = h - (interp_value / 65535 * h)
      
      if pixel == 0 then
        ctx:move_to(x, y)
      else
        ctx:line_to(x, y)
      end
    end
  else
    -- Advanced interpolation modes for canvas display
    for pixel = 0, w - 1 do
      local sample_pos = visible_start + (pixel / (w - 1)) * (visible_samples - 1)
      local x = pixel
      local y
      
      if canvas_interpolation_mode == "cubic" then
        -- Cubic interpolation
        local i = math.floor(sample_pos)
        local frac = sample_pos - i
        local i0 = math.max(1, math.min(wave_size, i - 1))
        local i1 = math.max(1, math.min(wave_size, i))
        local i2 = math.max(1, math.min(wave_size, i + 1))
        local i3 = math.max(1, math.min(wave_size, i + 2))
        local interp_value = PCMDrawerCubicInterpolate(wave_data[i0], wave_data[i1], wave_data[i2], wave_data[i3], frac)
        y = h - (math.max(0, math.min(65535, interp_value)) / 65535 * h)
        
      elseif canvas_interpolation_mode == "bezier" then
        -- Bezier interpolation
        local i = math.floor(sample_pos)
        local frac = sample_pos - i
        local i1 = math.max(1, math.min(wave_size, i))
        local i2 = math.max(1, math.min(wave_size, i + 1))
        local control1 = wave_data[i1] + (i1 > 1 and (wave_data[i1] - wave_data[i1-1]) * 0.3 or 0)
        local control2 = wave_data[i2] - (i2 < wave_size and (wave_data[i2+1] - wave_data[i2]) * 0.3 or 0)
        local interp_value = PCMDrawerBezierInterpolate(wave_data[i1], control1, control2, wave_data[i2], frac)
        y = h - (math.max(0, math.min(65535, interp_value)) / 65535 * h)
      else
        -- Fallback to linear if unknown mode
        local i = math.floor(sample_pos)
        local frac = sample_pos - i
        local i1 = math.max(1, math.min(wave_size, i))
        local i2 = math.max(1, math.min(wave_size, i + 1))
        local interp_value = wave_data[i1] + frac * (wave_data[i2] - wave_data[i1])
        y = h - (interp_value / 65535 * h)
      end
      
      if pixel == 0 then
        ctx:move_to(x, y)
      else
        ctx:line_to(x, y)
      end
    end
  end
  ctx:stroke()

  -- Draw sample points if enabled and zoomed in enough
  if show_sample_points and zoom_factor >= 2.0 then
    ctx.fill_color = {0, 200, 0, 255}
    for i = visible_start, visible_end do
      local sample_in_visible = i - visible_start
      local x = (sample_in_visible / (visible_samples - 1)) * w
      local y = h - (wave_data[i] / 65535 * h)
      ctx:begin_path()
      ctx:arc(x, y, 3, 0, math.pi * 2, false)
      ctx:fill()
    end
  end

  -- Selected sample highlight
  if selected_sample_index > 0 and selected_sample_index >= visible_start and selected_sample_index <= visible_end then
    local sample_in_visible = selected_sample_index - visible_start
    local x = (sample_in_visible / (visible_samples - 1)) * w
    local y = h - (wave_data[selected_sample_index] / 65535 * h)
    
    -- Draw vertical line
    ctx.stroke_color = {255, 0, 0, 180}
    ctx.line_width = 2
    ctx:begin_path()
    ctx:move_to(x, 0)
    ctx:line_to(x, h)
    ctx:stroke()
    
    -- Draw selected point
    ctx.fill_color = {255, 0, 0, 255}
    ctx:begin_path()
    ctx:arc(x, y, 5, 0, math.pi * 2, false)
    ctx:fill()
  end

  -- Draw selection overlay
  if selection_start > 0 and selection_end > 0 and selection_start <= selection_end then
    local sel_start = math.max(visible_start, selection_start)
    local sel_end = math.min(visible_end, selection_end)
    
    if sel_start <= sel_end then
      local start_in_visible = sel_start - visible_start
      local end_in_visible = sel_end - visible_start
      local start_x = (start_in_visible / (visible_samples - 1)) * w
      local end_x = (end_in_visible / (visible_samples - 1)) * w
      
      -- Draw selection background
      ctx.fill_color = {0, 150, 255, 60}
      ctx:begin_path()
      ctx:rect(start_x, 0, end_x - start_x, h)
      ctx:fill()
      
      -- Draw selection borders
      ctx.stroke_color = {0, 150, 255, 200}
      ctx.line_width = 2
      ctx:begin_path()
      ctx:move_to(start_x, 0)
      ctx:line_to(start_x, h)
      ctx:move_to(end_x, 0)
      ctx:line_to(end_x, h)
      ctx:stroke()
    end
  end

  -- Draw zoom info
  ctx.fill_color = {255, 255, 255, 200}
  local zoom_text = string.format("Zoom: %.1fx | Samples: %d-%d", zoom_factor, visible_start, visible_end)
  -- Note: Canvas doesn't support text, so we'll show this in status instead
end

-- Draw a line between two sample points to prevent gaps during fast mouse movement
function PCMDrawerDrawLineBetweenSamples(start_idx, start_value, end_idx, end_value)
  if start_idx == end_idx then
    wave_data[start_idx] = end_value
    return
  end
  
  -- Ensure start_idx is less than end_idx
  if start_idx > end_idx then
    start_idx, end_idx = end_idx, start_idx
    start_value, end_value = end_value, start_value
  end
  
  -- Interpolate between the two points
  local distance = end_idx - start_idx
  for i = start_idx, end_idx do
    local progress = (i - start_idx) / distance
    local interpolated_value = math.floor(start_value + progress * (end_value - start_value))
    wave_data[i] = math.max(0, math.min(65535, interpolated_value))
  end
end

-- Mouse handler with zoom and pan support
function PCMDrawerHandleMouse(ev)
  local w = wavetable_canvas_width  -- Use configurable width
  local h = waveform_canvas.height
  local visible_start = math.max(1, math.floor(pan_offset + 1))
  local visible_end = math.min(wave_size, math.floor(pan_offset + wave_size / zoom_factor))
  local visible_samples = visible_end - visible_start + 1
  
  local rel_x = ev.position.x / w
  local rel_y = ev.position.y / h
  local idx = math.floor(visible_start + rel_x * (visible_samples - 1))
  
  if idx >= 1 and idx <= wave_size then
    selected_sample_index = idx
    local current_value = math.floor((1 - rel_y) * 65535)
    
    -- Simple drawing mode only - no shift+drag selection
    if ev.type == "down" and ev.button == "left" then
      is_drawing = true
      wave_data[idx] = current_value
      last_sample_index = idx
      last_mouse_x = ev.position.x
      last_mouse_y = ev.position.y
      waveform_canvas:update()
      PCMDrawerUpdateHexDisplay()
      PCMDrawerHighlightSample(idx)
    elseif ev.type == "move" and is_drawing then
      -- Continue drawing while dragging with interpolation to prevent gaps
      if last_sample_index > 0 and last_sample_index ~= idx then
        -- Draw line between last position and current position
        local last_value = math.floor((1 - (last_mouse_y / h)) * 65535)
        PCMDrawerDrawLineBetweenSamples(last_sample_index, last_value, idx, current_value)
      else
        -- Just set current sample if no previous position or same position
        wave_data[idx] = current_value
      end
      
      last_sample_index = idx
      last_mouse_x = ev.position.x
      last_mouse_y = ev.position.y
      waveform_canvas:update()
      PCMDrawerUpdateHexDisplay()
      PCMDrawerHighlightSample(idx)
    elseif ev.type == "up" and ev.button == "left" then
      is_drawing = false
      last_sample_index = -1
      last_mouse_x = -1
      last_mouse_y = -1
    elseif ev.type == "move" and not is_drawing then
      -- Just highlight when hovering without drawing
      PCMDrawerHighlightSample(idx)
    end
  else
    -- Mouse is outside valid sample range
    if is_drawing then
      -- Stop drawing and reset tracking when mouse leaves canvas
      is_drawing = false
      last_sample_index = -1
      last_mouse_x = -1
      last_mouse_y = -1
    end
    
    -- Handle mouse up outside canvas
    if ev.type == "up" and ev.button == "left" then
      is_drawing = false
      last_sample_index = -1
      last_mouse_x = -1
      last_mouse_y = -1
    end
  end
end

-- Keyboard handler for arrow key controls
function PCMDrawerHandleKeyboard(dialog, key)
  if selected_sample_index > 0 and selected_sample_index <= wave_size then
    if key.name == "up" then
      -- Modify samples around cursor position based on cursor width
      local half_width = math.floor(cursor_width / 2)
      local start_idx = math.max(1, selected_sample_index - half_width)
      local end_idx = math.min(wave_size, selected_sample_index + half_width)
      
      for i = start_idx, end_idx do
        wave_data[i] = math.min(65535, wave_data[i] + cursor_step_size)
      end
      
      waveform_canvas:update()
      PCMDrawerUpdateHexDisplay()
      return nil  -- Consume the key
    elseif key.name == "down" then
      -- Modify samples around cursor position based on cursor width
      local half_width = math.floor(cursor_width / 2)
      local start_idx = math.max(1, selected_sample_index - half_width)
      local end_idx = math.min(wave_size, selected_sample_index + half_width)
      
      for i = start_idx, end_idx do
        wave_data[i] = math.max(0, wave_data[i] - cursor_step_size)
      end
      
      waveform_canvas:update()
      PCMDrawerUpdateHexDisplay()
      return nil  -- Consume the key
    elseif key.name == "left" then
      selected_sample_index = math.max(1, selected_sample_index - 1)
      waveform_canvas:update()
      PCMDrawerUpdateHexDisplay()
      PCMDrawerHighlightSample(selected_sample_index)
      return nil  -- Consume the key
    elseif key.name == "right" then
      selected_sample_index = math.min(wave_size, selected_sample_index + 1)
      waveform_canvas:update()
      PCMDrawerUpdateHexDisplay()
      PCMDrawerHighlightSample(selected_sample_index)
      return nil  -- Consume the key
    end
  end
  
  -- Default key handling
  local closer = "esc"
  if preferences and preferences.pakettiDialogClose then
    closer = preferences.pakettiDialogClose.value
  end
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    pcm_dialog = nil
    return nil
  else
    return key
  end
end

-- Selection operation functions
function PCMDrawerHasSelection()
  return selection_start > 0 and selection_end > 0 and selection_start <= selection_end
end

function PCMDrawerGetSelectionInfo()
  if not PCMDrawerHasSelection() then
    return "No selection"
  end
  local count = selection_end - selection_start + 1
  return string.format("Selected: %d-%d (%d samples)", selection_start, selection_end, count)
end

-- Update all displays function (moved before functions that use it)
function PCMDrawerUpdateAllDisplays()
  if waveform_canvas then
    waveform_canvas:update()
  end
  PCMDrawerUpdateHexDisplay()
  -- Note: No longer updating selection info since we removed selection UI
end

function PCMDrawerClearSelection()
  selection_start = -1
  selection_end = -1
  PCMDrawerUpdateAllDisplays()
end

function PCMDrawerSelectAll()
  selection_start = 1
  selection_end = wave_size
  PCMDrawerUpdateAllDisplays()
end

-- Zoom functions
function PCMDrawerZoomIn()
  zoom_factor = math.min(max_zoom, zoom_factor * 1.5)
  pan_offset = math.max(0, math.min(wave_size - wave_size/zoom_factor, pan_offset))
  PCMDrawerUpdateAllDisplays()
end

function PCMDrawerZoomOut()
  zoom_factor = math.max(min_zoom, zoom_factor / 1.5)
  pan_offset = math.max(0, math.min(wave_size - wave_size/zoom_factor, pan_offset))
  PCMDrawerUpdateAllDisplays()
end

function PCMDrawerZoomFit()
  zoom_factor = 1.0
  pan_offset = 0
  PCMDrawerUpdateAllDisplays()
end

-- Pan functions
function PCMDrawerPanLeft()
  pan_offset = math.max(0, pan_offset - wave_size / zoom_factor * 0.1)
  PCMDrawerUpdateAllDisplays()
end

function PCMDrawerPanRight()
  pan_offset = math.min(wave_size - wave_size/zoom_factor, pan_offset + wave_size / zoom_factor * 0.1)
  PCMDrawerUpdateAllDisplays()
end

function PCMDrawerEditHexSample(idx, new_value)
  local value = tonumber(new_value, 16)
  
  -- If not a valid hex number, try to extract valid hex characters
  if not value then
    -- Remove any non-hex characters and try again
    local cleaned = new_value:upper():gsub("[^0-9A-F]", "")
    if cleaned == "" then
      value = 0
    else
      value = tonumber(cleaned, 16) or 0
    end
  end
  
  -- Clamp to valid range (0000-FFFF)
  value = math.max(0, math.min(65535, value))
  
  wave_data[idx] = value
  selected_sample_index = idx
  
  -- Update the textfield to show the clamped value
  if hex_buttons[idx] then
    hex_buttons[idx].text = string.format("%04X", value)
  end
  
  waveform_canvas:update()
  PCMDrawerUpdateHexDisplay()
  PCMDrawerHighlightSample(idx)
end

-- WAV file format functions
function PCMDrawerCreateWavHeader(sample_rate, num_channels, num_samples, bits_per_sample)
  local byte_rate = sample_rate * num_channels * bits_per_sample / 8
  local block_align = num_channels * bits_per_sample / 8
  local data_size = num_samples * num_channels * bits_per_sample / 8
  local file_size = 36 + data_size
  
  local header = {}
  
  -- RIFF header
  table.insert(header, string.char(0x52, 0x49, 0x46, 0x46)) -- "RIFF"
  table.insert(header, string.char(file_size % 256, math.floor(file_size / 256) % 256, 
                                  math.floor(file_size / 65536) % 256, math.floor(file_size / 16777216) % 256))
  table.insert(header, string.char(0x57, 0x41, 0x56, 0x45)) -- "WAVE"
  
  -- fmt chunk
  table.insert(header, string.char(0x66, 0x6D, 0x74, 0x20)) -- "fmt "
  table.insert(header, string.char(16, 0, 0, 0)) -- chunk size
  table.insert(header, string.char(1, 0)) -- PCM format
  table.insert(header, string.char(num_channels, 0)) -- mono
  
  -- Sample rate (32-bit little-endian)
  table.insert(header, string.char(sample_rate % 256, math.floor(sample_rate / 256) % 256,
                                  math.floor(sample_rate / 65536) % 256, math.floor(sample_rate / 16777216) % 256))
  
  -- Byte rate (32-bit little-endian)
  table.insert(header, string.char(byte_rate % 256, math.floor(byte_rate / 256) % 256,
                                  math.floor(byte_rate / 65536) % 256, math.floor(byte_rate / 16777216) % 256))
  
  table.insert(header, string.char(block_align, 0)) -- block align
  table.insert(header, string.char(bits_per_sample, 0)) -- bits per sample
  
  -- data chunk
  table.insert(header, string.char(0x64, 0x61, 0x74, 0x61)) -- "data"
  table.insert(header, string.char(data_size % 256, math.floor(data_size / 256) % 256,
                                  math.floor(data_size / 65536) % 256, math.floor(data_size / 16777216) % 256))
  
  return table.concat(header)
end

-- Enhanced save functions
function PCMDrawerSaveWaveBin()
  local suggested_name = string.format("waveform_%dsamples.bin", wave_size)
  local filename = renoise.app():prompt_for_filename_to_write(".bin", suggested_name)
  
  if filename then
    local file = io.open(filename, "wb")
    if file then
      for i = 1, wave_size do
        local value = wave_data[i]
        file:write(string.char(value % 256))
        file:write(string.char(math.floor(value / 256)))
      end
      file:close()
      renoise.app():show_status("Wave saved as BIN: " .. filename)
    else
      renoise.app():show_error("Could not save BIN file")
    end
  else
    renoise.app():show_status("Save BIN cancelled")
  end
end

function PCMDrawerSaveWaveWav()
  local suggested_name = string.format("waveform_%dsamples.wav", wave_size)
  local filename = renoise.app():prompt_for_filename_to_write(".wav", suggested_name)
  
  if filename then
    local file = io.open(filename, "wb")
    if file then
      -- Write WAV header
      local header = PCMDrawerCreateWavHeader(44100, 1, wave_size, 16)
      file:write(header)
      
      -- Write PCM data (convert from unsigned 16-bit to signed 16-bit)
      for i = 1, wave_size do
        local value = wave_data[i] - 32768 -- Convert to signed
        value = math.max(-32768, math.min(32767, value))
        if value < 0 then value = value + 65536 end
        file:write(string.char(value % 256))
        file:write(string.char(math.floor(value / 256)))
      end
      file:close()
      renoise.app():show_status("Wave saved as WAV: " .. filename)
    else
      renoise.app():show_error("Could not save WAV file")
    end
  else
    renoise.app():show_status("Save WAV cancelled")
  end
end

function PCMDrawerLoadWave()
  local filename = renoise.app():prompt_for_filename_to_read({"*.raw", "*.bin", "*.wav"}, "Load Wave File")
  
  if filename then
    local file = io.open(filename, "rb")
    if file then
      local content = file:read("*a")
      file:close()
      
      local is_wav = filename:lower():match("%.wav$")
      local data_offset = 0
      local expected_size = wave_size * 2
      
      if is_wav then
        -- Find data chunk in WAV file
        local data_pos = content:find("data")
        if data_pos then
          data_offset = data_pos + 7 -- Skip "data" + 4-byte size
          local available_data = #content - data_offset
          expected_size = math.min(expected_size, available_data)
        else
          renoise.app():show_error("Invalid WAV file: no data chunk found")
          return
        end
      end
      
      if #content - data_offset >= expected_size then
        for i = 1, wave_size do
          local pos = data_offset + (i - 1) * 2 + 1
          if pos + 1 <= #content then
            local low = string.byte(content, pos)
            local high = string.byte(content, pos + 1)
            local value = low + (high * 256)
            
            if is_wav then
              -- Convert from signed to unsigned
              if value > 32767 then value = value - 65536 end
              value = value + 32768
            end
            
            wave_data[i] = math.max(0, math.min(65535, value))
          end
        end
        selected_sample_index = -1
        PCMDrawerZoomFit()
        renoise.app():show_status("Wave loaded: " .. filename)
      else
        renoise.app():show_error(string.format("Invalid file size! Expected at least %d bytes, got %d", 
          expected_size, #content - data_offset))
      end
    else
      renoise.app():show_error("Could not read file")
    end
  else
    renoise.app():show_status("Load wave cancelled")
  end
end

-- Wavetable functions
function PCMDrawerExportWavetableToSample()
  if #wavetable_waves == 0 then
    renoise.app():show_error("No waves in wavetable to export")
    return
  end
  
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- Check if instrument has samples or plugins, if so create new instrument
  if #inst.samples > 0 or inst.plugin_properties.plugin_loaded then
    song:insert_instrument_at(song.selected_instrument_index + 1)
    song.selected_instrument_index = song.selected_instrument_index + 1
    inst = song.selected_instrument
    -- Apply Paketti default instrument configuration
    pakettiPreferencesDefaultInstrumentLoader()
  end
  
  -- Create separate sample slots for each wave (up to 12)
  for wave_idx, wave in ipairs(wavetable_waves) do
    -- Create sample slot
    if #inst.samples < wave_idx then
      inst:insert_sample_at(wave_idx)
    end
    
    local sample = inst:sample(wave_idx)
    local buffer = sample.sample_buffer
    
    -- Create sample data for this single wave
    buffer:create_sample_data(44100, 16, 1, wave_size)
    buffer:prepare_sample_data_changes()
    
    -- Write this wave's data
    for i = 1, wave_size do
      buffer:set_sample_data(1, i, (wave.data[i] - 32768) / 32768)
    end
    buffer:finalize_sample_data_changes()
    
    -- Set sample properties
    sample.name = string.format("PCM Wave %02d (%d frames)", wave_idx, wave_size)
    
    -- Enable loop mode for each sample
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = wave_size
    
    -- Set interpolation
    if sample_interpolation_mode == "linear" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
    elseif sample_interpolation_mode == "cubic" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC
    elseif sample_interpolation_mode == "sinc" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
    elseif sample_interpolation_mode == "none" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_NONE
    else
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR -- default
    end
    
    sample.oversample_enabled = sample_oversample_enabled
  end
  
  inst.name = string.format("PCM Wavetable (%d waves, %d frames)", #wavetable_waves, wave_size)
  
  -- Select the first sample
  song.selected_sample_index = 1
  
  renoise.app():show_status(string.format("Wavetable exported: %d waves as separate sample slots with %s interpolation", #wavetable_waves, sample_interpolation_mode))
end

function PCMDrawerAddWavetableWave()
  -- Check if we've reached the maximum of 12 waves
  if #wavetable_waves >= 12 then
    renoise.app():show_status("Maximum wavetable size reached (12 waves)")
    return
  end
  
  -- Preserve the current selection position
  local saved_selected_index = selected_sample_index
  
  local new_wave = {data = table.create(), name = string.format("Wave %d", #wavetable_waves + 1)}
  
  -- Copy current editor wave to new wavetable wave
  -- Both should now be the same size (512 samples)
  for i = 1, wave_size do
    new_wave.data[i] = wave_data[i]
  end
  
  table.insert(wavetable_waves, new_wave)
  current_wave_index = #wavetable_waves
  
  -- Restore the selection position
  selected_sample_index = saved_selected_index
  
  renoise.app():show_status(string.format("Added %s to wavetable (%d/12 waves)", new_wave.name, #wavetable_waves))
  
  -- Update the wavetable count display without rebuilding the entire dialog
  if wavetable_count_text then
    wavetable_count_text.text = string.format("Wavetable Tools (%d/12)", #wavetable_waves)
  end
end

function PCMDrawerGenerateRandomWaveform()
  local max_attempts = 5  -- Maximum attempts to generate a good waveform
  local attempt = 1
  
  while attempt <= max_attempts do
    -- MAXIMUM RANDOMNESS - Multiple entropy sources and chaos
    local chaos_seed = os.time() + math.floor(os.clock() * 1000000) + wave_size + (selected_sample_index or 0) + attempt * 54321
    
    -- Add more entropy from system state
    chaos_seed = chaos_seed + #wavetable_waves * 1337 + cursor_width * 42 + cursor_step_size
    
    -- Random seed the seed with itself (recursive randomness)
    for chaos_round = 1, math.random(3, 8) do
      math.randomseed(chaos_seed + chaos_round * 12345)
      chaos_seed = chaos_seed + math.random(1, 999999)
    end
    
    -- Final seed with accumulated chaos
    math.randomseed(chaos_seed)
    
    -- Warm up with random number of calls
    for i = 1, math.random(5, 15) do math.random() end
  
  -- Randomly choose generation method (now with 6 methods)
  local method = math.random(1, 6)
  local status_text = ""
  
  if method == 1 then
    -- Method 1: CHAOTIC mix of basic waveforms with random frequencies
    local num_oscillators = math.random(1, 8)  -- Multiple oscillators per waveform type
    local sine_amp = math.random() > math.random() and (math.random() * math.random(0.5, 2.0)) or 0
    local square_amp = math.random() > math.random() and (math.random() * math.random(0.3, 1.5)) or 0
    local triangle_amp = math.random() > math.random() and (math.random() * math.random(0.4, 1.8)) or 0
    local saw_amp = math.random() > math.random() and (math.random() * math.random(0.2, 1.2)) or 0
    local noise_amp = math.random() > math.random() and (math.random() * math.random(0.1, 0.8)) or 0
    
    -- Random frequency multipliers for each waveform
    local sine_freq = math.random() * 4 + 0.5
    local square_freq = math.random() * 6 + 0.25
    local triangle_freq = math.random() * 5 + 0.33
    local saw_freq = math.random() * 7 + 0.1
    
    local total_amp = sine_amp + square_amp + triangle_amp + saw_amp + noise_amp
    if total_amp == 0 then sine_amp = 0.5 end -- Fallback
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      
      if sine_amp > 0 then
        -- Multiple sine waves with random phase shifts
        for osc = 1, num_oscillators do
          local freq = sine_freq * math.random(0.5, 2.0)
          local phase_shift = math.random() * math.pi * 2
          value = value + math.sin(phase * math.pi * 2 * freq + phase_shift) * (sine_amp / num_oscillators)
        end
      end
      if square_amp > 0 then
        local square_phase = phase * square_freq
        local square = (square_phase % 1 < math.random(0.2, 0.8)) and 1 or -1
        value = value + square * square_amp
      end
      if triangle_amp > 0 then
        local tri_phase = (phase * triangle_freq) % 1
        local triangle
        local peak_pos = math.random(0.2, 0.8)  -- Random peak position
        if tri_phase < peak_pos then
          triangle = (tri_phase / peak_pos) * 2 - 1
        else
          triangle = 1 - ((tri_phase - peak_pos) / (1 - peak_pos)) * 2
        end
        value = value + triangle * triangle_amp
      end
      if saw_amp > 0 then
        local saw_phase = (phase * saw_freq) % 1
        local saw = (saw_phase * 2 - 1)
        -- Random saw direction
        if math.random() > 0.5 then saw = -saw end
        value = value + saw * saw_amp
      end
      if noise_amp > 0 then
        -- Colored noise with random filtering
        local noise = (math.random() * 2 - 1)
        if math.random() > 0.5 then
          -- Low-pass filtered noise
          noise = noise * (1 - phase * math.random(0.5, 1.0))
        end
        value = value + noise * noise_amp
      end
      
      if total_amp > 0 then
        value = value / total_amp
      end
      wave_data[i] = math.floor((value * 32767) + 32768)
      wave_data[i] = math.max(0, math.min(65535, wave_data[i]))
    end
    status_text = string.format("Random mix (s:%.1f sq:%.1f tri:%.1f saw:%.1f n:%.1f)", 
      sine_amp, square_amp, triangle_amp, saw_amp, noise_amp)
  
  elseif method == 2 then
    -- Method 2: Harmonic series with random harmonics
    local fundamental = math.random(1, 6)
    local harmonics = {}
    for h = 1, 12 do
      local prob = math.random(0.4, 0.8) - (h * 0.05)  -- Decreasing probability for higher harmonics
      harmonics[h] = math.random() > prob and (math.random() * (1.2 - h * 0.08) / h) or 0
    end
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      for h = 1, 12 do
        if harmonics[h] > 0 then
          value = value + math.sin(phase * math.pi * 2 * h * fundamental) * harmonics[h]
        end
      end
      wave_data[i] = math.floor((value * 32767) + 32768)
      wave_data[i] = math.max(0, math.min(65535, wave_data[i]))
    end
    
    -- Count active harmonics
    local active_harmonics = 0
    for h = 1, 12 do
      if harmonics[h] > 0 then active_harmonics = active_harmonics + 1 end
    end
    status_text = string.format("Harmonic series (fund:%d, %d harmonics)", fundamental, active_harmonics)
  
  elseif method == 3 then
    -- Method 3: Bezier curve with random control points
    local control_points = {}
    local num_points = math.random(3, 15)
    for p = 1, num_points do
      -- More varied control point distribution
      local range = math.random(0.5, 2.0)
      control_points[p] = (math.random() * 2 - 1) * range
    end
    
    for i = 1, wave_size do
      local t = (i - 1) / (wave_size - 1)
      local segment = t * (num_points - 1)
      local seg_idx = math.floor(segment)
      local seg_t = segment - seg_idx
      
      local value
      if seg_idx >= num_points - 1 then
        value = control_points[num_points]
      else
        -- Linear interpolation between control points
        value = control_points[seg_idx + 1] + seg_t * (control_points[seg_idx + 2] - control_points[seg_idx + 1])
      end
      
      wave_data[i] = math.floor((value * 32767) + 32768)
      wave_data[i] = math.max(0, math.min(65535, wave_data[i]))
    end
    status_text = string.format("Bezier curve (%d control points)", num_points)
  
  elseif method == 4 then
    -- Method 4: Fractal/chaos waveform
    local chaos_factor = math.random() * 1.2 + 0.05
    local seed_value = (math.random() * 2 - 1) * math.random(0.5, 2.0)
    local feedback = math.random() * 1.2 + 0.05
    local chaos_type = math.random(1, 3)  -- Different chaos equations
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      
      -- Different chaotic equations for variety
      if chaos_type == 1 then
        -- Logistic map variation
        seed_value = chaos_factor * seed_value * (1 - seed_value) + feedback * math.sin(phase * math.pi * 2)
      elseif chaos_type == 2 then
        -- Sine map variation
        seed_value = math.sin(seed_value * chaos_factor * math.pi) + feedback * math.cos(phase * math.pi * 4)
      else
        -- Tent map variation
        if seed_value < 0.5 then
          seed_value = chaos_factor * seed_value + feedback * math.sin(phase * math.pi * 6)
        else
          seed_value = chaos_factor * (1 - seed_value) + feedback * math.cos(phase * math.pi * 3)
        end
      end
      
      -- Clamp to prevent overflow
      seed_value = math.max(-2, math.min(2, seed_value))
      
      local value = seed_value
      wave_data[i] = math.floor((value * 32767) + 32768)
      wave_data[i] = math.max(0, math.min(65535, wave_data[i]))
    end
    
    local chaos_names = {"Logistic", "Sine", "Tent"}
    status_text = string.format("Chaotic waveform (%s, chaos:%.2f, feedback:%.2f)", 
      chaos_names[chaos_type], chaos_factor, feedback)
  
  elseif method == 5 then
    -- Method 5: ULTIMATE CHAOS - Hybrid of all methods with random switching
    local method_switches = {}
    for i = 1, wave_size do
      method_switches[i] = math.random(1, 4)  -- Random method per sample
    end
    
    -- Pre-generate parameters for all methods
    local sine_amp = math.random() * 2
    local square_amp = math.random() * 1.5
    local triangle_amp = math.random() * 1.8
    local saw_amp = math.random() * 1.2
    local noise_amp = math.random() * 0.8
    
    local fundamental = math.random(1, 8)
    local harmonics = {}
    for h = 1, 16 do
      harmonics[h] = math.random() > 0.5 and (math.random() * 2 / h) or 0
    end
    
    local control_points = {}
    local num_points = math.random(5, 20)
    for p = 1, num_points do
      control_points[p] = (math.random() * 4 - 2)
    end
    
    local chaos_factor = math.random() * 2 + 0.1
    local seed_value = math.random() * 4 - 2
    local feedback = math.random() * 2 + 0.1
    
    -- Generate with method-switching chaos
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      local current_method = method_switches[i]
      
      if current_method == 1 then
        -- Random mix method
        value = math.sin(phase * math.pi * 2 * math.random(0.5, 8)) * sine_amp * math.random(0.5, 1.5)
        value = value + ((phase * math.random(2, 10)) % 1 < 0.5 and 1 or -1) * square_amp * math.random(0.3, 1.2)
        value = value + (math.random() * 2 - 1) * noise_amp * math.random(0.1, 0.9)
      elseif current_method == 2 then
        -- Harmonic method
        for h = 1, math.random(3, 12) do
          if harmonics[h] and harmonics[h] > 0 then
            value = value + math.sin(phase * math.pi * 2 * h * fundamental * math.random(0.8, 1.2)) * harmonics[h]
          end
        end
      elseif current_method == 3 then
        -- Bezier method
        local t = phase
        local segment = t * (num_points - 1)
        local seg_idx = math.floor(segment)
        local seg_t = segment - seg_idx
        if seg_idx >= num_points - 1 then
          value = control_points[num_points] or 0
        else
          local p1 = control_points[seg_idx + 1] or 0
          local p2 = control_points[seg_idx + 2] or 0
          value = p1 + seg_t * (p2 - p1)
        end
        value = value * math.random(0.5, 2.0)  -- Random amplitude scaling
      else
        -- Chaos method
        seed_value = math.sin(seed_value * chaos_factor * math.pi * math.random(0.5, 2.0)) + 
                    feedback * math.cos(phase * math.pi * math.random(2, 12))
        seed_value = math.max(-3, math.min(3, seed_value))
        value = seed_value
      end
      
      -- Add random cross-contamination between methods
      if math.random() > 0.7 then
        local contamination = math.sin(phase * math.pi * math.random(4, 32)) * math.random(0.1, 0.5)
        value = value + contamination
      end
      
      wave_data[i] = math.floor((value * 16383) + 32768)  -- Different scaling for more chaos
      wave_data[i] = math.max(0, math.min(65535, wave_data[i]))
    end
    status_text = string.format("ULTIMATE CHAOS (hybrid switching, %d methods)", num_points)
  
  else
    -- Method 6: Spectral/Additive synthesis with random partials
    local num_partials = math.random(3, 16)
    local fundamental_freq = math.random(0.5, 4.0)
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      
      -- Generate random partials with varying amplitudes and frequencies
      for partial = 1, num_partials do
        local freq_ratio = partial * math.random(0.8, 1.2)  -- Slightly detuned harmonics
        local amplitude = math.random(0.1, 1.0) / partial  -- Decreasing amplitude
        local phase_offset = math.random() * math.pi * 2
        
        value = value + math.sin(phase * math.pi * 2 * fundamental_freq * freq_ratio + phase_offset) * amplitude
      end
      
      wave_data[i] = math.floor((value * 32767 / num_partials) + 32768)
      wave_data[i] = math.max(0, math.min(65535, wave_data[i]))
    end
    status_text = string.format("Spectral synthesis (%d partials, fund:%.1f)", num_partials, fundamental_freq)
  end
  
  -- RANDOM POST-PROCESSING CHAOS
  local post_fx = math.random(1, 7)
  if post_fx == 1 then
    -- Random bit crushing
    local bit_crush = math.random(8, 15)
    local crush_factor = math.pow(2, 16 - bit_crush)
    for i = 1, wave_size do
      wave_data[i] = math.floor(wave_data[i] / crush_factor) * crush_factor
    end
    status_text = status_text .. " + BitCrush"
  elseif post_fx == 2 then
    -- Random waveshaping distortion
    local drive = math.random(1.5, 4.0)
    for i = 1, wave_size do
      local normalized = (wave_data[i] - 32768) / 32768
      normalized = math.tanh(normalized * drive) / drive
      wave_data[i] = math.floor(normalized * 32768 + 32768)
    end
    status_text = status_text .. " + Distortion"
  elseif post_fx == 3 then
    -- Random frequency modulation
    local fm_freq = math.random(0.5, 8.0)
    local fm_depth = math.random(0.1, 0.8)
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local fm_mod = math.sin(phase * math.pi * 2 * fm_freq) * fm_depth
      local mod_phase = phase + fm_mod
      if mod_phase >= 0 and mod_phase <= 1 then
        local mod_idx = math.floor(mod_phase * (wave_size - 1)) + 1
        if mod_idx >= 1 and mod_idx <= wave_size then
          wave_data[i] = (wave_data[i] + wave_data[mod_idx]) / 2
        end
      end
    end
    status_text = status_text .. " + FM"
  elseif post_fx == 4 then
    -- Random ring modulation
    local ring_freq = math.random(0.25, 12.0)
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local ring_mod = math.sin(phase * math.pi * 2 * ring_freq)
      local normalized = (wave_data[i] - 32768) / 32768
      normalized = normalized * ring_mod
      wave_data[i] = math.floor(normalized * 32768 + 32768)
    end
    status_text = status_text .. " + RingMod"
  elseif post_fx == 5 then
    -- Random phase distortion
    local phase_amt = math.random(0.2, 2.0)
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local distorted_phase = math.sin(phase * math.pi * phase_amt)
      local new_idx = math.floor(math.abs(distorted_phase) * (wave_size - 1)) + 1
      if new_idx >= 1 and new_idx <= wave_size then
        wave_data[i] = wave_data[new_idx]
      end
    end
    status_text = status_text .. " + PhaseDistort"
  elseif post_fx == 6 then
    -- Chebyshev polynomial waveshaping
    local order = math.random(2, 6)  -- Use 2nd to 6th order Chebyshev polynomials
    local drive = math.random(0.5, 2.0)
    for i = 1, wave_size do
      local normalized = (wave_data[i] - 32768) / 32768  -- Convert to -1 to 1 range
      normalized = math.max(-1, math.min(1, normalized * drive))  -- Apply drive and clamp
      
      local shaped
      if order == 2 then
        -- T2(x) = 2x^2 - 1
        shaped = 2 * normalized * normalized - 1
      elseif order == 3 then
        -- T3(x) = 4x^3 - 3x
        shaped = 4 * normalized * normalized * normalized - 3 * normalized
      elseif order == 4 then
        -- T4(x) = 8x^4 - 8x^2 + 1
        local x2 = normalized * normalized
        shaped = 8 * x2 * x2 - 8 * x2 + 1
      elseif order == 5 then
        -- T5(x) = 16x^5 - 20x^3 + 5x
        local x2 = normalized * normalized
        local x3 = x2 * normalized
        shaped = 16 * x3 * x2 - 20 * x3 + 5 * normalized
      else -- order == 6
        -- T6(x) = 32x^6 - 48x^4 + 18x^2 - 1
        local x2 = normalized * normalized
        local x4 = x2 * x2
        shaped = 32 * x4 * x2 - 48 * x4 + 18 * x2 - 1
      end
      
      -- Clamp result and convert back to 0-65535 range
      shaped = math.max(-1, math.min(1, shaped))
      wave_data[i] = math.floor(shaped * 32768 + 32768)
    end
    status_text = status_text .. string.format(" + Chebyshev T%d", order)
  end
  -- post_fx == 7 means no post-processing (clean)
  
  -- Debug: Check waveform energy before click-free processing
  local energy_before = 0
  local min_val = 65535
  local max_val = 0
  for i = 1, wave_size do
    local deviation = math.abs(wave_data[i] - 32768)
    energy_before = energy_before + deviation
    min_val = math.min(min_val, wave_data[i])
    max_val = math.max(max_val, wave_data[i])
  end
  local range_before = max_val - min_val
  local avg_energy_before = energy_before / wave_size
  
  -- Post-process to ensure click-free looping: force first and last samples to center (0.5)
  local center_value = 32768  -- Center value (0.5 in normalized range)
  
  -- Only apply click-free processing if waveform has sufficient energy
  if avg_energy_before > 1000 and range_before > 2000 then
    -- Store original first and last values for gentler processing
    local original_first = wave_data[1]
    local original_last = wave_data[wave_size]
    
    -- Gentle click-free: blend towards center instead of forcing to center
    local blend_factor = 0.3  -- Only blend 30% towards center
    wave_data[1] = math.floor(original_first + (center_value - original_first) * blend_factor)
    wave_data[wave_size] = math.floor(original_last + (center_value - original_last) * blend_factor)
    
    -- Much gentler smoothing - only 2-3 samples maximum
    local smooth_samples = math.min(2, math.floor(wave_size / 64))  -- Much less aggressive
    
    if smooth_samples > 0 then
      -- Gentle smooth start
      for i = 2, smooth_samples + 1 do
        local blend = (i - 1) / smooth_samples * 0.2  -- Very gentle blending
        local original_value = wave_data[i]
        wave_data[i] = math.floor(original_value + (center_value - original_value) * blend)
      end
      
      -- Gentle smooth end
      for i = wave_size - smooth_samples, wave_size - 1 do
        local blend = (wave_size - i) / smooth_samples * 0.2  -- Very gentle blending
        local original_value = wave_data[i]
        wave_data[i] = math.floor(original_value + (center_value - original_value) * blend)
      end
    end
  end
  
  -- Debug: Check waveform energy after processing
  local energy_after = 0
  local min_val_after = 65535
  local max_val_after = 0
  for i = 1, wave_size do
    local deviation = math.abs(wave_data[i] - 32768)
    energy_after = energy_after + deviation
    min_val_after = math.min(min_val_after, wave_data[i])
    max_val_after = math.max(max_val_after, wave_data[i])
  end
  local range_after = max_val_after - min_val_after
  local avg_energy_after = energy_after / wave_size
  
  -- Debug output for boring waveforms
  -- Check for "envelope-only" waveforms (mostly flat with just edge fades)
  local middle_start = math.floor(wave_size * 0.2)  -- Skip first 20%
  local middle_end = math.floor(wave_size * 0.8)    -- Skip last 20%
  local middle_variation = 0
  local middle_samples = middle_end - middle_start + 1
  
  -- Check variation in the middle 60% of the waveform
  for i = middle_start, middle_end do
    local deviation = math.abs(wave_data[i] - 32768)
    middle_variation = middle_variation + deviation
  end
  local avg_middle_variation = middle_variation / middle_samples
  
  -- Check if waveform is mostly flat in the middle (boring envelope-only shape)
  local is_boring = avg_middle_variation < 200 or range_after < 1000
  
  if is_boring or avg_energy_after < 500 then
    print("DEBUG: BORING/DEAD WAVEFORM DETECTED!")
    print("  Attempt:", attempt)
    print("  Method:", method)
    print("  Post-FX:", post_fx)
    print("  Energy before:", string.format("%.1f", avg_energy_before))
    print("  Energy after:", string.format("%.1f", avg_energy_after))
    print("  Range before:", range_before)
    print("  Range after:", range_after)
    print("  Middle variation:", string.format("%.1f", avg_middle_variation))
    print("  Status:", status_text)
    print("  First 10 samples:", wave_data[1], wave_data[2], wave_data[3], wave_data[4], wave_data[5], wave_data[6], wave_data[7], wave_data[8], wave_data[9], wave_data[10])
    print("  Middle 10 samples:", wave_data[math.floor(wave_size*0.4)], wave_data[math.floor(wave_size*0.45)], wave_data[math.floor(wave_size*0.5)], wave_data[math.floor(wave_size*0.55)], wave_data[math.floor(wave_size*0.6)])
    print("  Last 10 samples:", wave_data[wave_size-9], wave_data[wave_size-8], wave_data[wave_size-7], wave_data[wave_size-6], wave_data[wave_size-5], wave_data[wave_size-4], wave_data[wave_size-3], wave_data[wave_size-2], wave_data[wave_size-1], wave_data[wave_size])
    
    -- If this is a boring waveform and we haven't reached max attempts, try again
    if attempt < max_attempts then
      print("  Retrying generation... (attempt " .. (attempt + 1) .. "/" .. max_attempts .. ")")
      attempt = attempt + 1
      -- Continue the while loop to try again
    else
      print("  Max attempts reached, keeping this waveform")
      break  -- Exit the while loop
    end
  else
    -- Good waveform generated, exit the while loop
    if attempt > 1 then
      print("DEBUG: Good waveform generated on attempt " .. attempt)
    end
    break
  end
  
  end  -- End of while loop
  
  selected_sample_index = -1
  selection_start = -1
  selection_end = -1
  
  if waveform_canvas then
    waveform_canvas:update()
  end
  PCMDrawerUpdateHexDisplay()
  
  renoise.app():show_status("Generated " .. status_text .. " (click-free)")
end

-- Enhanced version with entropy control and forced method selection for wavetable generation
function PCMDrawerGenerateRandomWaveformWithEntropy(entropy_seed, forced_method)
  -- Use provided entropy seed for consistent but diverse randomization
  math.randomseed(entropy_seed)
  
  -- Warm up with entropy-specific number of calls
  for i = 1, (entropy_seed % 20) + 5 do 
    math.random() 
  end
  
  -- Use forced method to ensure diversity across wavetable
  local method = forced_method or math.random(1, 6)
  local status_text = ""
  
  if method == 1 then
    -- Method 1: CHAOTIC mix of basic waveforms with random frequencies
    local num_oscillators = math.random(1, 8)
    local sine_amp = math.random() > math.random() and (math.random() * math.random(0.5, 2.0)) or 0
    local square_amp = math.random() > math.random() and (math.random() * math.random(0.3, 1.5)) or 0
    local triangle_amp = math.random() > math.random() and (math.random() * math.random(0.4, 1.8)) or 0
    local saw_amp = math.random() > math.random() and (math.random() * math.random(0.2, 1.2)) or 0
    local noise_amp = math.random() > math.random() and (math.random() * math.random(0.1, 0.8)) or 0
    
    local sine_freq = math.random() * 4 + 0.5
    local square_freq = math.random() * 6 + 0.25
    local triangle_freq = math.random() * 5 + 0.33
    local saw_freq = math.random() * 7 + 0.1
    
    local total_amp = sine_amp + square_amp + triangle_amp + saw_amp + noise_amp
    if total_amp == 0 then sine_amp = 0.5 end
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      
      if sine_amp > 0 then
        for osc = 1, num_oscillators do
          local freq = sine_freq * math.random(0.5, 2.0)
          local phase_shift = math.random() * math.pi * 2
          value = value + math.sin(phase * math.pi * 2 * freq + phase_shift) * (sine_amp / num_oscillators)
        end
      end
      if square_amp > 0 then
        local square_phase = phase * square_freq
        local square = (square_phase % 1 < math.random(0.2, 0.8)) and 1 or -1
        value = value + square * square_amp
      end
      if triangle_amp > 0 then
        local tri_phase = (phase * triangle_freq) % 1
        local triangle
        local peak_pos = math.random(0.2, 0.8)
        if tri_phase < peak_pos then
          triangle = (tri_phase / peak_pos) * 2 - 1
        else
          triangle = 1 - ((tri_phase - peak_pos) / (1 - peak_pos)) * 2
        end
        value = value + triangle * triangle_amp
      end
      if saw_amp > 0 then
        local saw_phase = (phase * saw_freq) % 1
        local saw = (saw_phase * 2 - 1)
        if math.random() > 0.5 then saw = -saw end
        value = value + saw * saw_amp
      end
      if noise_amp > 0 then
        local noise = (math.random() * 2 - 1)
        if math.random() > 0.5 then
          noise = noise * (1 - phase * math.random(0.5, 1.0))
        end
        value = value + noise * noise_amp
      end
      
      if total_amp > 0 then
        value = value / total_amp
      end
      wave_data[i] = math.floor((value * 32767) + 32768)
      wave_data[i] = math.max(0, math.min(65535, wave_data[i]))
    end
    status_text = string.format("Random mix (s:%.1f sq:%.1f tri:%.1f saw:%.1f n:%.1f)", 
      sine_amp, square_amp, triangle_amp, saw_amp, noise_amp)
  
  elseif method == 2 then
    -- Method 2: Harmonic series with random harmonics
    local fundamental = math.random(1, 6)
    local harmonics = {}
    for h = 1, 12 do
      local prob = math.random(0.4, 0.8) - (h * 0.05)
      harmonics[h] = math.random() > prob and (math.random() * (1.2 - h * 0.08) / h) or 0
    end
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      for h = 1, 12 do
        if harmonics[h] > 0 then
          value = value + math.sin(phase * math.pi * 2 * h * fundamental) * harmonics[h]
        end
      end
      wave_data[i] = math.floor((value * 32767) + 32768)
      wave_data[i] = math.max(0, math.min(65535, wave_data[i]))
    end
    
    local active_harmonics = 0
    for h = 1, 12 do
      if harmonics[h] > 0 then active_harmonics = active_harmonics + 1 end
    end
    status_text = string.format("Harmonic series (fund:%d, %d harmonics)", fundamental, active_harmonics)
  
  elseif method == 3 then
    -- Method 3: Bezier curve with random control points
    local control_points = {}
    local num_points = math.random(3, 15)
    for p = 1, num_points do
      local range = math.random(0.5, 2.0)
      control_points[p] = (math.random() * 2 - 1) * range
    end
    
    for i = 1, wave_size do
      local t = (i - 1) / (wave_size - 1)
      local segment = t * (num_points - 1)
      local seg_idx = math.floor(segment)
      local seg_t = segment - seg_idx
      
      local value
      if seg_idx >= num_points - 1 then
        value = control_points[num_points]
      else
        value = control_points[seg_idx + 1] + seg_t * (control_points[seg_idx + 2] - control_points[seg_idx + 1])
      end
      
      wave_data[i] = math.floor((value * 32767) + 32768)
      wave_data[i] = math.max(0, math.min(65535, wave_data[i]))
    end
    status_text = string.format("Bezier curve (%d control points)", num_points)
  
  elseif method == 4 then
    -- Method 4: Fractal/chaos waveform
    local chaos_factor = math.random() * 1.2 + 0.05
    local seed_value = (math.random() * 2 - 1) * math.random(0.5, 2.0)
    local feedback = math.random() * 1.2 + 0.05
    local chaos_type = math.random(1, 3)
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      
      if chaos_type == 1 then
        seed_value = chaos_factor * seed_value * (1 - seed_value) + feedback * math.sin(phase * math.pi * 2)
      elseif chaos_type == 2 then
        seed_value = math.sin(seed_value * chaos_factor * math.pi) + feedback * math.cos(phase * math.pi * 4)
      else
        if seed_value < 0.5 then
          seed_value = chaos_factor * seed_value + feedback * math.sin(phase * math.pi * 6)
        else
          seed_value = chaos_factor * (1 - seed_value) + feedback * math.cos(phase * math.pi * 3)
        end
      end
      
      seed_value = math.max(-2, math.min(2, seed_value))
      
      local value = seed_value
      wave_data[i] = math.floor((value * 32767) + 32768)
      wave_data[i] = math.max(0, math.min(65535, wave_data[i]))
    end
    
    local chaos_names = {"Logistic", "Sine", "Tent"}
    status_text = string.format("Chaotic waveform (%s, chaos:%.2f, feedback:%.2f)", 
      chaos_names[chaos_type], chaos_factor, feedback)
  
  elseif method == 5 then
    -- Method 5: ULTIMATE CHAOS - Hybrid of all methods with random switching
    local method_switches = {}
    for i = 1, wave_size do
      method_switches[i] = math.random(1, 4)
    end
    
    local sine_amp = math.random() * 2
    local square_amp = math.random() * 1.5
    local triangle_amp = math.random() * 1.8
    local saw_amp = math.random() * 1.2
    local noise_amp = math.random() * 0.8
    
    local fundamental = math.random(1, 8)
    local harmonics = {}
    for h = 1, 16 do
      harmonics[h] = math.random() > 0.5 and (math.random() * 2 / h) or 0
    end
    
    local control_points = {}
    local num_points = math.random(5, 20)
    for p = 1, num_points do
      control_points[p] = (math.random() * 4 - 2)
    end
    
    local chaos_factor = math.random() * 2 + 0.1
    local seed_value = math.random() * 4 - 2
    local feedback = math.random() * 2 + 0.1
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      local current_method = method_switches[i]
      
      if current_method == 1 then
        value = math.sin(phase * math.pi * 2 * math.random(0.5, 8)) * sine_amp * math.random(0.5, 1.5)
        value = value + ((phase * math.random(2, 10)) % 1 < 0.5 and 1 or -1) * square_amp * math.random(0.3, 1.2)
        value = value + (math.random() * 2 - 1) * noise_amp * math.random(0.1, 0.9)
      elseif current_method == 2 then
        for h = 1, math.random(3, 12) do
          if harmonics[h] and harmonics[h] > 0 then
            value = value + math.sin(phase * math.pi * 2 * h * fundamental * math.random(0.8, 1.2)) * harmonics[h]
          end
        end
      elseif current_method == 3 then
        local t = phase
        local segment = t * (num_points - 1)
        local seg_idx = math.floor(segment)
        local seg_t = segment - seg_idx
        if seg_idx >= num_points - 1 then
          value = control_points[num_points] or 0
        else
          local p1 = control_points[seg_idx + 1] or 0
          local p2 = control_points[seg_idx + 2] or 0
          value = p1 + seg_t * (p2 - p1)
        end
        value = value * math.random(0.5, 2.0)
      else
        seed_value = math.sin(seed_value * chaos_factor * math.pi * math.random(0.5, 2.0)) + 
                    feedback * math.cos(phase * math.pi * math.random(2, 12))
        seed_value = math.max(-3, math.min(3, seed_value))
        value = seed_value
      end
      
      if math.random() > 0.7 then
        local contamination = math.sin(phase * math.pi * math.random(4, 32)) * math.random(0.1, 0.5)
        value = value + contamination
      end
      
      wave_data[i] = math.floor((value * 16383) + 32768)
      wave_data[i] = math.max(0, math.min(65535, wave_data[i]))
    end
    status_text = string.format("ULTIMATE CHAOS (hybrid switching, %d methods)", num_points)
  
  else
    -- Method 6: Spectral/Additive synthesis with random partials
    local num_partials = math.random(3, 16)
    local fundamental_freq = math.random(0.5, 4.0)
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      
      for partial = 1, num_partials do
        local freq_ratio = partial * math.random(0.8, 1.2)
        local amplitude = math.random(0.1, 1.0) / partial
        local phase_offset = math.random() * math.pi * 2
        
        value = value + math.sin(phase * math.pi * 2 * fundamental_freq * freq_ratio + phase_offset) * amplitude
      end
      
      wave_data[i] = math.floor((value * 32767 / num_partials) + 32768)
      wave_data[i] = math.max(0, math.min(65535, wave_data[i]))
    end
    status_text = string.format("Spectral synthesis (%d partials, fund:%.1f)", num_partials, fundamental_freq)
  end
  
  -- Reduced post-processing for wavetables (less aggressive smoothing)
  local post_fx = math.random(1, 9)  -- Increased chance of no post-processing
  if post_fx == 1 then
    local bit_crush = math.random(8, 15)
    local crush_factor = math.pow(2, 16 - bit_crush)
    for i = 1, wave_size do
      wave_data[i] = math.floor(wave_data[i] / crush_factor) * crush_factor
    end
    status_text = status_text .. " + BitCrush"
  elseif post_fx == 2 then
    local drive = math.random(1.5, 4.0)
    for i = 1, wave_size do
      local normalized = (wave_data[i] - 32768) / 32768
      normalized = math.tanh(normalized * drive) / drive
      wave_data[i] = math.floor(normalized * 32768 + 32768)
    end
    status_text = status_text .. " + Distortion"
  elseif post_fx == 3 then
    local fm_freq = math.random(0.5, 8.0)
    local fm_depth = math.random(0.1, 0.8)
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local fm_mod = math.sin(phase * math.pi * 2 * fm_freq) * fm_depth
      local mod_phase = phase + fm_mod
      if mod_phase >= 0 and mod_phase <= 1 then
        local mod_idx = math.floor(mod_phase * (wave_size - 1)) + 1
        if mod_idx >= 1 and mod_idx <= wave_size then
          wave_data[i] = (wave_data[i] + wave_data[mod_idx]) / 2
        end
      end
    end
    status_text = status_text .. " + FM"
  elseif post_fx == 4 then
    -- Chebyshev polynomial waveshaping
    local order = math.random(2, 6)  -- Use 2nd to 6th order Chebyshev polynomials
    local drive = math.random(0.5, 2.0)
    for i = 1, wave_size do
      local normalized = (wave_data[i] - 32768) / 32768  -- Convert to -1 to 1 range
      normalized = math.max(-1, math.min(1, normalized * drive))  -- Apply drive and clamp
      
      local shaped
      if order == 2 then
        -- T2(x) = 2x^2 - 1
        shaped = 2 * normalized * normalized - 1
      elseif order == 3 then
        -- T3(x) = 4x^3 - 3x
        shaped = 4 * normalized * normalized * normalized - 3 * normalized
      elseif order == 4 then
        -- T4(x) = 8x^4 - 8x^2 + 1
        local x2 = normalized * normalized
        shaped = 8 * x2 * x2 - 8 * x2 + 1
      elseif order == 5 then
        -- T5(x) = 16x^5 - 20x^3 + 5x
        local x2 = normalized * normalized
        local x3 = x2 * normalized
        shaped = 16 * x3 * x2 - 20 * x3 + 5 * normalized
      else -- order == 6
        -- T6(x) = 32x^6 - 48x^4 + 18x^2 - 1
        local x2 = normalized * normalized
        local x4 = x2 * x2
        shaped = 32 * x4 * x2 - 48 * x4 + 18 * x2 - 1
      end
      
      -- Clamp result and convert back to 0-65535 range
      shaped = math.max(-1, math.min(1, shaped))
      wave_data[i] = math.floor(shaped * 32768 + 32768)
    end
    status_text = status_text .. string.format(" + Chebyshev T%d", order)
  end
  -- post_fx 5-9 means no post-processing (higher chance of clean waveforms)
  
  -- Less aggressive click-free processing for wavetables
  local center_value = 32768
  
  -- Check waveform energy before processing
  local energy_check = 0
  local min_check = 65535
  local max_check = 0
  for i = 1, wave_size do
    local deviation = math.abs(wave_data[i] - 32768)
    energy_check = energy_check + deviation
    min_check = math.min(min_check, wave_data[i])
    max_check = math.max(max_check, wave_data[i])
  end
  local range_check = max_check - min_check
  local avg_energy_check = energy_check / wave_size
  
  -- Only apply click-free processing if waveform has sufficient energy
  if avg_energy_check > 1000 and range_check > 2000 then
    -- Store original values
    local original_first = wave_data[1]
    local original_last = wave_data[wave_size]
    
    -- Very gentle click-free: only blend 20% towards center for wavetables
    local blend_factor = 0.2
    wave_data[1] = math.floor(original_first + (center_value - original_first) * blend_factor)
    wave_data[wave_size] = math.floor(original_last + (center_value - original_last) * blend_factor)
    
    -- Ultra-minimal smoothing (only 1-2 samples)
    local smooth_samples = math.min(1, math.floor(wave_size / 128))
    
    if smooth_samples > 0 then
      for i = 2, smooth_samples + 1 do
        local blend = (i - 1) / smooth_samples * 0.1  -- Ultra-gentle blending
        local original_value = wave_data[i]
        wave_data[i] = math.floor(original_value + (center_value - original_value) * blend)
      end
      
      for i = wave_size - smooth_samples, wave_size - 1 do
        local blend = (wave_size - i) / smooth_samples * 0.1  -- Ultra-gentle blending
        local original_value = wave_data[i]
        wave_data[i] = math.floor(original_value + (center_value - original_value) * blend)
      end
    end
  end
  
  selected_sample_index = -1
  selection_start = -1
  selection_end = -1
  
  if waveform_canvas then
    waveform_canvas:update()
  end
  PCMDrawerUpdateHexDisplay()
  
  renoise.app():show_status("Generated " .. status_text .. " (entropy: " .. tostring(entropy_seed % 10000) .. ")")
end

function PCMDrawerCreate12RandomInstrument()
  -- Clear existing wavetable
  wavetable_waves = {}
  
  -- Preserve the current selection position
  local saved_selected_index = selected_sample_index
  
  -- Create new instrument first
  local song = renoise.song()
  song:insert_instrument_at(song.selected_instrument_index + 1)
  song.selected_instrument_index = song.selected_instrument_index + 1
  -- Apply Paketti default instrument configuration
  pakettiPreferencesDefaultInstrumentLoader()
  
  -- Create a base entropy pool for this batch to ensure diversity
  local base_entropy = os.time() * 1000 + math.floor(os.clock() * 1000000)
  
  -- Generate 12 random waveforms and add them to wavetable
  for wave_num = 1, 12 do
    -- Add significant entropy per wave to ensure diversity
    local wave_entropy = base_entropy + (wave_num * 98765) + math.random(1, 999999)
    
    -- Force different method selection per wave for guaranteed diversity
    local forced_method = ((wave_num - 1) % 6) + 1  -- Cycle through methods 1-6
    
    -- Generate random waveform with wave-specific entropy
    PCMDrawerGenerateRandomWaveformWithEntropy(wave_entropy, forced_method)
    
    -- Add current waveform to wavetable
    local new_wave = {data = table.create(), name = string.format("Random_%02d", wave_num)}
    
    -- Copy current editor wave to new wavetable wave
    for i = 1, wave_size do
      new_wave.data[i] = wave_data[i]
    end
    
    table.insert(wavetable_waves, new_wave)
    current_wave_index = #wavetable_waves
    
    -- Update progress
    renoise.app():show_status(string.format("Generating random wavetable... %d/12", wave_num))
    
    -- Small delay to ensure entropy changes between iterations
    for delay = 1, 1000 do
      math.random() -- Burn some cycles and advance RNG state
    end
  end
  
  -- Restore the selection position
  selected_sample_index = saved_selected_index
  
  -- Update the wavetable count display
  if wavetable_count_text then
    wavetable_count_text.text = string.format("Wavetable Tools (%d/12)", #wavetable_waves)
  end
  
  -- Export the wavetable to instrument (now using the pre-created instrument)
  -- Skip the instrument creation check since we already created it
  local inst = song.selected_instrument
  
  -- Create separate sample slots for each wave (up to 12)
  for wave_idx, wave in ipairs(wavetable_waves) do
    -- Create sample slot
    if #inst.samples < wave_idx then
      inst:insert_sample_at(wave_idx)
    end
    
    local sample = inst:sample(wave_idx)
    local buffer = sample.sample_buffer
    
    -- Create sample data for this single wave
    buffer:create_sample_data(44100, 16, 1, wave_size)
    buffer:prepare_sample_data_changes()
    
    -- Write this wave's data
    for i = 1, wave_size do
      buffer:set_sample_data(1, i, (wave.data[i] - 32768) / 32768)
    end
    buffer:finalize_sample_data_changes()
    
    -- Set sample properties
    sample.name = string.format("PCM Random %02d (%d frames)", wave_idx, wave_size)
    
    -- Enable loop mode for each sample
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = wave_size
    
    -- Set interpolation
    if sample_interpolation_mode == "linear" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
    elseif sample_interpolation_mode == "cubic" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC
    elseif sample_interpolation_mode == "sinc" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
    elseif sample_interpolation_mode == "none" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_NONE
    else
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR -- default
    end
    
    sample.oversample_enabled = sample_oversample_enabled
  end
  
  inst.name = string.format("PCM Random Wavetable (%d waves, %d frames)", #wavetable_waves, wave_size)
  
  -- Select the first sample
  song.selected_sample_index = 1
  
  renoise.app():show_status("Created 12 Random Instrument with wavetable (12 waves)")
end

function PCMDrawerSaveWavetable()
  if #wavetable_waves == 0 then
    renoise.app():show_error("No waves in wavetable to save")
    return
  end
  
  local suggested_name = string.format("wavetable_%dwaves_%dsamples.wav", #wavetable_waves, wave_size)
  local filename = renoise.app():prompt_for_filename_to_write(".wav", suggested_name)
  
  if filename then
    local file = io.open(filename, "wb")
    if file then
      local total_samples = #wavetable_waves * wave_size  -- Use wave_size (512) not wavetable_size
      local header = PCMDrawerCreateWavHeader(44100, 1, total_samples, 16)
      file:write(header)
      
      -- Write all waves sequentially
      for _, wave in ipairs(wavetable_waves) do
        for i = 1, wave_size do  -- Use wave_size (512) not wavetable_size
          local value = wave.data[i] - 32768 -- Convert to signed
          value = math.max(-32768, math.min(32767, value))
          if value < 0 then value = value + 65536 end
          file:write(string.char(value % 256))
          file:write(string.char(math.floor(value / 256)))
        end
      end
      file:close()
      renoise.app():show_status(string.format("Wavetable saved: %d waves, %s", #wavetable_waves, filename))
    else
      renoise.app():show_error("Could not save wavetable")
    end
  else
    renoise.app():show_status("Save wavetable cancelled")
  end
end

function PCMDrawerExportToSample()
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- Check if instrument has samples or plugins, if so create new instrument
  if #inst.samples > 0 or inst.plugin_properties.plugin_loaded then
    song:insert_instrument_at(song.selected_instrument_index + 1)
    song.selected_instrument_index = song.selected_instrument_index + 1
    inst = song.selected_instrument
    -- Apply Paketti default instrument configuration
    pakettiPreferencesDefaultInstrumentLoader()
  end
  
  -- Create sample slot if it doesn't exist
  if #inst.samples == 0 then
    inst:insert_sample_at(1)
  end
  
  local sample = inst:sample(1)
  local buffer = sample.sample_buffer
  buffer:create_sample_data(44100, 16, 1, wave_size)
  buffer:prepare_sample_data_changes()
  for i = 1, wave_size do
    buffer:set_sample_data(1, i, (wave_data[i] - 32768) / 32768)
  end
  buffer:finalize_sample_data_changes()
  
  sample.name = string.format("PCM Wave (Single, %d frames)", wave_size)
  inst.name = string.format("PCM Wave (Single, %d frames)", wave_size)
  
  -- Select the created sample
  song.selected_sample_index = 1
  
  -- Enable loop mode (forward loop) and set loop points
  sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
  sample.loop_start = 1
  sample.loop_end = wave_size
  
  -- Set interpolation mode based on sample export settings
  if sample_interpolation_mode == "linear" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
  elseif sample_interpolation_mode == "cubic" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC
  elseif sample_interpolation_mode == "sinc" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  elseif sample_interpolation_mode == "none" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_NONE
  else
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR -- default
  end
  
  -- Enable oversampling based on setting
  sample.oversample_enabled = sample_oversample_enabled
  
  renoise.app():show_status(string.format("Wave exported with %s interpolation and oversampling %s", sample_interpolation_mode, sample_oversample_enabled and "enabled" or "disabled"))
end

-- Remaining selection operation functions
function PCMDrawerInvertSelection()
  -- Preserve cursor position
  local saved_cursor = selected_sample_index
  
  -- Invert entire waveform
  for i = 1, wave_size do
    wave_data[i] = 65535 - wave_data[i]
  end
  
  -- Restore cursor position
  selected_sample_index = saved_cursor
  
  PCMDrawerUpdateAllDisplays()
  renoise.app():show_status("Inverted entire waveform")
end

function PCMDrawerNormalizeSelection()
  -- Preserve cursor position
  local saved_cursor = selected_sample_index
  
  if not PCMDrawerHasSelection() then
    -- Normalize whole waveform if no selection
    local min_val = 65535
    local max_val = 0
    for i = 1, wave_size do
      min_val = math.min(min_val, wave_data[i])
      max_val = math.max(max_val, wave_data[i])
    end
    
    -- Avoid division by zero
    if max_val == min_val then
      selected_sample_index = saved_cursor
      renoise.app():show_status("Waveform has no dynamic range to normalize")
      return
    end
    
    -- Normalize to full range
    local range = max_val - min_val
    for i = 1, wave_size do
      wave_data[i] = math.floor(((wave_data[i] - min_val) / range) * 65535)
    end
    
    -- Restore cursor position
    selected_sample_index = saved_cursor
    PCMDrawerUpdateAllDisplays()
    renoise.app():show_status("Normalized entire waveform")
    return
  end
  
  -- Find min/max in selection
  local min_val = 65535
  local max_val = 0
  for i = selection_start, selection_end do
    min_val = math.min(min_val, wave_data[i])
    max_val = math.max(max_val, wave_data[i])
  end
  
  -- Avoid division by zero
  if max_val == min_val then
    renoise.app():show_status("Selection has no dynamic range to normalize")
    return
  end
  
  -- Normalize to full range
  local range = max_val - min_val
  for i = selection_start, selection_end do
    wave_data[i] = math.floor(((wave_data[i] - min_val) / range) * 65535)
  end
  
  PCMDrawerUpdateAllDisplays()
  renoise.app():show_status(string.format("Normalized samples %d-%d", selection_start, selection_end))
end

function PCMDrawerFadeInSelection()
  -- Preserve cursor position
  local saved_cursor = selected_sample_index
  
  -- Fade in entire waveform
  for i = 1, wave_size do
    local progress = (i - 1) / (wave_size - 1)
    local center = 32768
    wave_data[i] = math.floor(center + (wave_data[i] - center) * progress)
  end
  
  -- Restore cursor position
  selected_sample_index = saved_cursor
  
  PCMDrawerUpdateAllDisplays()
  renoise.app():show_status("Fade in applied to entire waveform")
end

function PCMDrawerFadeOutSelection()
  -- Preserve cursor position
  local saved_cursor = selected_sample_index
  
  -- Fade out entire waveform
  for i = 1, wave_size do
    local progress = 1 - ((i - 1) / (wave_size - 1))
    local center = 32768
    wave_data[i] = math.floor(center + (wave_data[i] - center) * progress)
  end
  
  -- Restore cursor position
  selected_sample_index = saved_cursor
  
  PCMDrawerUpdateAllDisplays()
  renoise.app():show_status("Fade out applied to entire waveform")
end

function PCMDrawerSilenceSelection()
  -- Preserve cursor position
  local saved_cursor = selected_sample_index
  
  -- Silence entire waveform
  for i = 1, wave_size do
    wave_data[i] = 32768  -- Center value (silence)
  end
  
  -- Restore cursor position
  selected_sample_index = saved_cursor
  
  PCMDrawerUpdateAllDisplays()
  renoise.app():show_status("Silenced entire waveform")
end

function PCMDrawerReverseSelection()
  -- Preserve cursor position
  local saved_cursor = selected_sample_index
  
  -- Reverse entire waveform
  for i = 1, math.floor(wave_size / 2) do
    local left_idx = i
    local right_idx = wave_size - i + 1
    local temp = wave_data[left_idx]
    wave_data[left_idx] = wave_data[right_idx]
    wave_data[right_idx] = temp
  end
  
  -- Restore cursor position
  selected_sample_index = saved_cursor
  
  PCMDrawerUpdateAllDisplays()
  renoise.app():show_status("Reversed entire waveform")
end

-- Rebuild hex editor display (scrollable version for large samples)
function PCMDrawerRebuildHexEditor()
  hex_buttons = {}
  local hex_columns = {}
  
  -- Calculate pagination
  local total_pages = math.ceil(wave_size / hex_samples_per_page)
  local current_page = math.min(hex_editor_page, total_pages - 1)
  local start_sample = current_page * hex_samples_per_page + 1
  local end_sample = math.min(start_sample + hex_samples_per_page - 1, wave_size)
  local samples_on_page = end_sample - start_sample + 1
  
  -- Navigation header
  local nav_row = vb:row{
    --spacing = 5,
    vb:text{
      text = string.format("Samples %d-%d of %d", start_sample, end_sample, wave_size),
      width = 180,
      font = "bold"
    },
    vb:button{
      text = "◀◀",
      width = 30,
      tooltip = "First Page",
      notifier = function()
        hex_editor_page = 0
        if pcm_dialog then pcm_dialog:close() end
        PCMDrawerShowPcmDialog()
      end
    },
    vb:button{
      text = "◀",
      width = 30,
      tooltip = "Previous Page", 
      notifier = function()
        hex_editor_page = math.max(0, hex_editor_page - 1)
        if pcm_dialog then pcm_dialog:close() end
        PCMDrawerShowPcmDialog()
      end
    },
    vb:text{
      text = string.format("Page %d/%d", current_page + 1, total_pages),
      width = 70
    },
    vb:button{
      text = "▶",
      width = 30,
      tooltip = "Next Page",
      notifier = function()
        hex_editor_page = math.min(total_pages - 1, hex_editor_page + 1)
        if pcm_dialog then pcm_dialog:close() end
        PCMDrawerShowPcmDialog()
      end
    },
    vb:button{
      text = "▶▶",
      width = 30,
      tooltip = "Last Page",
      notifier = function()
        hex_editor_page = total_pages - 1
        if pcm_dialog then pcm_dialog:close() end
        PCMDrawerShowPcmDialog()
      end
    }
  }
  table.insert(hex_columns, nav_row)
  
  -- Build hex grid for current page
  local rows = math.ceil(samples_on_page / hex_items_per_row)
  
  for row = 1, rows do
    local hex_row = vb:row{ spacing = 1 }
    
    local offset = (row - 1) * hex_items_per_row
    local absolute_offset = start_sample + offset - 1
    
    -- Address column
    hex_row:add_child(vb:text{
      text = string.format("%03X:", absolute_offset),
      width = 35,
      font = "mono"
    })
    
    -- Hex value columns
    for col = 1, hex_items_per_row do
      local absolute_idx = start_sample + offset + col - 1
      if absolute_idx <= end_sample then
        local hex_field = vb:textfield{
          text = string.format("%04X", wave_data[absolute_idx]),
          width = hex_textfield_width,
          notifier = function(new_value) 
            PCMDrawerEditHexSample(absolute_idx, new_value) 
          end
        }
        hex_buttons[absolute_idx] = hex_field
        hex_row:add_child(hex_field)
      end
    end
    
    table.insert(hex_columns, hex_row)
  end
  
  return hex_columns
end

function PCMDrawerResetWaveEditor()
  dialog_initialized = false
  selection_start = -1
  selection_end = -1
  selected_sample_index = -1
  hex_editor_page = 0
  zoom_factor = 1.0
  pan_offset = 0
  selection_info_view = nil
end



function PCMDrawerChangeWaveSize(new_size)
  local old_size = wave_size
  local old_data = wave_data
  wave_size = new_size
  wave_data = table.create()
  
  -- Interpolate existing data to fill new size
  for i = 1, wave_size do
    if old_size == 1 then
      -- Special case: if old size was 1, just repeat that value
      wave_data[i] = old_data[1] or 32768
    else
      -- Linear interpolation to stretch/compress existing data
      local old_pos = ((i - 1) / (wave_size - 1)) * (old_size - 1) + 1
      local old_idx = math.floor(old_pos)
      local frac = old_pos - old_idx
      
      if old_idx >= old_size then
        -- At or beyond the end
        wave_data[i] = old_data[old_size] or 32768
      elseif old_idx < 1 then
        -- Before the start
        wave_data[i] = old_data[1] or 32768
      else
        -- Interpolate between two points
        local val1 = old_data[old_idx] or 32768
        local val2 = old_data[old_idx + 1] or val1
        wave_data[i] = math.floor(val1 + frac * (val2 - val1))
      end
    end
  end
  
  selected_sample_index = -1
  
  -- Clear selection if it's outside new range
  if selection_start > wave_size or selection_end > wave_size then
    PCMDrawerClearSelection()
  end
  
  PCMDrawerZoomFit()
  
  -- Rebuild hex editor and update displays without closing dialog
  if pcm_dialog then
    pcm_dialog:close()
    PCMDrawerShowPcmDialog()
  end
  
  renoise.app():show_status(string.format("Wave size changed to %d samples (interpolated)", wave_size))
end

-- Main dialog function
function PCMDrawerShowPcmDialog()
  -- Set flag to prevent dropdown from triggering during rebuild
  dialog_rebuilding = true
  
  -- Create fresh ViewBuilder instance to avoid ID conflicts
  local vb = renoise.ViewBuilder()
  
  waveform_canvas = vb:canvas{
    width = wavetable_canvas_width,
    height = 200,
    mode = "plain",
    render = PCMDrawerRenderWaveform,
    mouse_handler = PCMDrawerHandleMouse,
    mouse_events = {"down", "up", "move"}
  }

  -- Only generate initial waveform on first dialog opening
  if not dialog_initialized then
    PCMDrawerGenerateWaveform("sine")
    dialog_initialized = true
  end
  
  local hex_editor_rows = PCMDrawerRebuildHexEditor()
  local hex_editor_content = vb:column{ spacing = 2 }
  for _, row in ipairs(hex_editor_rows) do
    hex_editor_content:add_child(row)
  end

  -- Create selection info view
  selection_info_view = vb:text{
    text = PCMDrawerGetSelectionInfo(),
    width = 200,
    height = 20
  }
  
  -- Create wavetable count text element
  wavetable_count_text = vb:text{
    text = string.format("Wavetable Tools (%d/12)", #wavetable_waves),
    width = 180,
    style = "strong",
    font = "bold"
  }
  
  -- Create cursor width slider
  cursor_step_slider = vb:slider{
    min = 1,
    max = 50,
    value = cursor_width,
    width = 100,
    notifier = function(value)
      cursor_width = math.floor(value)
      if cursor_step_text then
        cursor_step_text.text = string.format("%d", cursor_width)
      end
    end
  }
  
  -- Create cursor width text display
  cursor_step_text = vb:text{
    text = string.format("%d", cursor_width),
    width = 50
  }
  
  local dialog_content = vb:column{ -- DIALOG_CONTENT STARTS
    margin = 10,
    --spacing = 10,
        
        -- Main controls row
  vb:row{ -- MAIN_CONTROLS_ROW STARTS
      --spacing = 10,
    vb:text{ text = "Waveform", style = "strong" },
    vb:popup{
      items = {"sine", "square", "saw", "triangle", "noise"},
      value = 1,
      notifier = function(idx)
        -- Don't generate waveform if dialog is being rebuilt
        if dialog_rebuilding then
          return
        end
        local types = {"sine", "square", "saw", "triangle", "noise"}
        PCMDrawerGenerateWaveform(types[idx], nil, wave_size)
        selected_sample_index = -1
        selection_start = -1
        selection_end = -1
        if waveform_canvas then
          waveform_canvas:update()
        end
        PCMDrawerUpdateHexDisplay()
      end
    },
    vb:button{
      text = "Random",
      width = 50,
      tooltip = "Generate random mixed waveform",
      notifier = PCMDrawerGenerateRandomWaveform
    },
          vb:text{ text = "Samples", style = "strong" },
    vb:popup{
        items = {"32", "64", "128", "256", "512", "1024"},
      value = (function()
        -- Find the current wave_size in the options and return its index
        for i, size in ipairs(wave_size_options) do
          if size == wave_size then
            return i
          end
        end
        return 5 -- Default to 512 if not found
      end)(),
      notifier = function(idx)
          PCMDrawerChangeWaveSize(wave_size_options[idx])
        end
      },
      vb:text{ text = "Sample Interpolation", style = "strong" },
      vb:popup{
        items = {"None", "Linear", "Cubic", "Sinc"},
        value = 2,
        notifier = function(idx)
          local modes = {"none", "linear", "cubic", "sinc"}
          sample_interpolation_mode = modes[idx]
        end
      },
      vb:checkbox{
        value = sample_oversample_enabled,
        notifier = function(value)
          sample_oversample_enabled = value
        end
      },
      vb:text{ text = "Oversampling", style = "strong" },
      vb:text{ text = "| Cursor Width", style = "strong" },
      cursor_step_slider,
      cursor_step_text,
      vb:text{ text = "Canvas Display", style = "strong" },
      vb:popup{
        items = {"Linear", "Cubic", "Bezier"},
        value = 1,
        notifier = function(idx)
          local modes = {"linear", "cubic", "bezier"}
          canvas_interpolation_mode = modes[idx]
          PCMDrawerUpdateAllDisplays()
        end
      }
    }, -- MAIN_CONTROLS_ROW ENDS
    
    vb:text{
      text = "Click/drag to draw • Arrow keys to edit selected frame",
      font = "italic",
      width = 1024
    },
    
    waveform_canvas,
    
    vb:row{ -- HEX_EDITOR_ROW STARTS
      -- Hex editor column
      vb:column{ -- HEX_EDITOR_COLUMN STARTS
        style = "group",
        margin = 5,
        width = 1024,
        vb:horizontal_aligner{ -- HEX_ALIGNER STARTS
          mode = "center",
          vb:column{ -- HEX_INNER_COLUMN STARTS
            vb:text{
              text = "Hex Editor (Type to edit)",
              style = "strong"
            },
            hex_editor_content
          } -- HEX_INNER_COLUMN ENDS
        } -- HEX_ALIGNER ENDS
      }, -- HEX_EDITOR_COLUMN ENDS
    }, -- HEX_EDITOR_ROW ENDS
    
    vb:horizontal_aligner{ -- TOOLS_ALIGNER STARTS
      mode = "center",
      vb:row{ -- TOOLS_ROW STARTS
      vb:column{ -- SAMPLE_TOOLS_COLUMN STARTS
        style = "group",
        margin = 5,
        vb:text{
          text = "Sample Tools",
          style = "strong",font="bold"
        },

        vb:row{
          vb:button{
            text = "Invert",
            width = 70,
            tooltip = "Flip waveform upside down",
            notifier = PCMDrawerInvertSelection
          },
          vb:button{
            text = "Normalize",
            width = 70,
            tooltip = "Scale to full range (whole wave if no selection)",
            notifier = PCMDrawerNormalizeSelection
          }
        },
        vb:row{
          --spacing = 5,
          vb:button{
            text = "Fade In",
            width = 70,
            tooltip = "Fade from silence to full",
            notifier = PCMDrawerFadeInSelection
          },
          vb:button{
            text = "Fade Out",
            width = 70,
            tooltip = "Fade from full to silence",
            notifier = PCMDrawerFadeOutSelection
          }
        },
        vb:row{
          --spacing = 5,
          vb:button{
            text = "Silence",
            width = 70,
            tooltip = "Set to center (silence)",
            notifier = PCMDrawerSilenceSelection
          },
          vb:button{
            text = "Reverse",
            width = 70,
            tooltip = "Reverse sample order",
            notifier = PCMDrawerReverseSelection
          }
        }
      }, -- SAMPLE_TOOLS_COLUMN ENDS
      
      -- Export Tools column
      vb:column{ -- EXPORT_TOOLS_COLUMN STARTS
        style = "group",
        margin = 5,
        vb:text{
          text = "Export Tools",
          style = "strong", font="bold"
        },
        vb:button{
          text = "Load Wave File",
          width = 180,
          notifier = PCMDrawerLoadWave
        },
        vb:button{
          text = "Export to Sample Slot",
          width = 180,
          notifier = PCMDrawerExportToSample
        },
        vb:button{
          text = "Save as .BIN File",
          width = 180,
          notifier = PCMDrawerSaveWaveBin
        },
        vb:button{
          text = "Save as .WAV File", 
          width = 180,
          notifier = PCMDrawerSaveWaveWav
        }
      }, -- EXPORT_TOOLS_COLUMN ENDS
      
      -- Wavetable column
      vb:column{ -- WAVETABLE_COLUMN STARTS
        style = "group",
        margin = 5,
        wavetable_count_text,
        vb:button{
          text = "Add Current to Wavetable",
          width = 180,
          notifier = PCMDrawerAddWavetableWave
        },
        vb:button{
          text = "Create 12 Random Instrument",
          width = 180,
          tooltip = "Generate 12 random waveforms and create instrument",
          notifier = PCMDrawerCreate12RandomInstrument
        },
        vb:button{
          text = "Export Wavetable to Sample",
          width = 180,
          notifier = PCMDrawerExportWavetableToSample
        },
        vb:button{
          text = "Save Wavetable (.WAV)",
          width = 180,
          notifier = PCMDrawerSaveWavetable
        }
      } -- WAVETABLE_COLUMN ENDS
    } -- TOOLS_ROW ENDS
  } -- TOOLS_ALIGNER ENDS
  } -- DIALOG_CONTENT ENDS
  
  pcm_dialog = renoise.app():show_custom_dialog(DIALOG_TITLE, dialog_content, PCMDrawerHandleKeyboard)
  PCMDrawerUpdateAllDisplays()
  
  -- Clear the rebuilding flag after dialog is fully created
  dialog_rebuilding = false
end

-- Enhanced menu entry with reset option
function PCMDrawerShowPcmDialogFresh()
  if pcm_dialog and pcm_dialog.visible then
    pcm_dialog:close()
  end
  PCMDrawerResetWaveEditor()
  PCMDrawerShowPcmDialog()
end

-- Menu entry and keybinding
renoise.tool():add_menu_entry{
  name = "--Main Menu:Tools:Paketti:Xperimental/Work in Progress:Advanced PCM Wave Editor...",
  invoke = PCMDrawerShowPcmDialog
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Xperimental/Work in Progress:Advanced PCM Wave Editor (Fresh)...",
  invoke = PCMDrawerShowPcmDialogFresh
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Show Advanced PCM Wave Editor",
  invoke = PCMDrawerShowPcmDialog
}


