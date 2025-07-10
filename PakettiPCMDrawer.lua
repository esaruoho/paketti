-- Advanced PCM Wave Editor with Zoom, Interpolation, and Multiple File Formats
-- Features: .bin/.wav export, zoom/scroll, interpolation smoothing, wavetable support

local vb = renoise.ViewBuilder()
local DIALOG_TITLE = "Paketti Advanced PCM Wave Editor"

-- Editor state
local wave_size_options = {32, 64, 128, 256, 512, 1024}
local wave_size = 64
local wave_data = table.create()
for i = 1, wave_size do wave_data[i] = 32768 end

local selected_sample_index = -1
local is_drawing = false
local hex_buttons = {}
local pcm_dialog = nil
local waveform_canvas = nil

-- Zoom and pan state
local zoom_factor = 1.0
local pan_offset = 0
local min_zoom = 0.25
local max_zoom = 8.0

-- Interpolation state
local interpolation_mode = "linear" -- "linear", "cubic", "bezier"
local show_sample_points = true

-- Wavetable state
local wavetable_waves = {}
local current_wave_index = 1
local wavetable_size = 64

-- Initialize wavetable with one wave
table.insert(wavetable_waves, {data = table.create(), name = "Wave 1"})
for i = 1, wavetable_size do
  wavetable_waves[1].data[i] = 32768
end

-- Generate basic waveforms
local function generate_waveform(type, target_data, size)
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
      if phase < 0.5 then
        target_data[i] = math.floor(phase * 2 * 65535)
      else
        target_data[i] = math.floor((1 - (phase - 0.5) * 2) * 65535)
      end
    elseif type == "noise" then
      target_data[i] = math.random(0, 65535)
    end
  end
  selected_sample_index = -1
end

-- Cubic interpolation function
local function cubic_interpolate(y0, y1, y2, y3, mu)
  local mu2 = mu * mu
  local a0 = y3 - y2 - y0 + y1
  local a1 = y0 - y1 - a0
  local a2 = y2 - y0
  local a3 = y1
  return a0 * mu * mu2 + a1 * mu2 + a2 * mu + a3
end

-- Bezier curve interpolation
local function bezier_interpolate(p0, p1, p2, p3, t)
  local t2 = t * t
  local t3 = t2 * t
  local mt = 1 - t
  local mt2 = mt * mt
  local mt3 = mt2 * mt
  return mt3 * p0 + 3 * mt2 * t * p1 + 3 * mt * t2 * p2 + t3 * p3
end

-- Canvas rendering function with zoom, pan, and interpolation
local function render_waveform(ctx)
  local w, h = ctx.size.width, ctx.size.height
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

  -- Draw waveform based on interpolation mode
  ctx.stroke_color = {0, 255, 0, 255}
  ctx.line_width = 2
  ctx:begin_path()

  if interpolation_mode == "linear" then
    -- Linear interpolation (original method)
    for i = visible_start, visible_end do
      local x = ((i - visible_start) / (visible_samples - 1)) * w
      local y = h - (wave_data[i] / 65535 * h)
      if i == visible_start then
        ctx:move_to(x, y)
      else
        ctx:line_to(x, y)
      end
    end
  else
    -- Smooth interpolation modes
    local steps_per_sample = math.max(4, math.floor(w / visible_samples))
    local total_steps = visible_samples * steps_per_sample
    
    for step = 0, total_steps do
      local t = step / total_steps
      local sample_pos = visible_start + t * (visible_samples - 1)
      local x = (step / total_steps) * w
      local y
      
      if interpolation_mode == "cubic" then
        -- Cubic interpolation
        local i = math.floor(sample_pos)
        local frac = sample_pos - i
        local i0 = math.max(1, i - 1)
        local i1 = math.max(1, math.min(wave_size, i))
        local i2 = math.max(1, math.min(wave_size, i + 1))
        local i3 = math.max(1, math.min(wave_size, i + 2))
        local interp_value = cubic_interpolate(wave_data[i0], wave_data[i1], wave_data[i2], wave_data[i3], frac)
        y = h - (math.max(0, math.min(65535, interp_value)) / 65535 * h)
        
      elseif interpolation_mode == "bezier" then
        -- Bezier interpolation
        local i = math.floor(sample_pos)
        local frac = sample_pos - i
        local i1 = math.max(1, math.min(wave_size, i))
        local i2 = math.max(1, math.min(wave_size, i + 1))
        local control1 = wave_data[i1] + (i1 > 1 and (wave_data[i1] - wave_data[i1-1]) * 0.3 or 0)
        local control2 = wave_data[i2] - (i2 < wave_size and (wave_data[i2+1] - wave_data[i2]) * 0.3 or 0)
        local interp_value = bezier_interpolate(wave_data[i1], control1, control2, wave_data[i2], frac)
        y = h - (math.max(0, math.min(65535, interp_value)) / 65535 * h)
      end
      
      if step == 0 then
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
      local x = ((i - visible_start) / (visible_samples - 1)) * w
      local y = h - (wave_data[i] / 65535 * h)
      ctx:begin_path()
      ctx:arc(x, y, 3, 0, math.pi * 2, false)
      ctx:fill()
    end
  end

  -- Selected sample highlight
  if selected_sample_index > 0 and selected_sample_index >= visible_start and selected_sample_index <= visible_end then
    local x = ((selected_sample_index - visible_start) / (visible_samples - 1)) * w
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

  -- Draw zoom info
  ctx.fill_color = {255, 255, 255, 200}
  local zoom_text = string.format("Zoom: %.1fx | Samples: %d-%d", zoom_factor, visible_start, visible_end)
  -- Note: Canvas doesn't support text, so we'll show this in status instead
end

-- Mouse handler with zoom and pan support
local function handle_mouse(ev)
  local w = waveform_canvas.width
  local h = waveform_canvas.height
  local visible_start = math.max(1, math.floor(pan_offset + 1))
  local visible_end = math.min(wave_size, math.floor(pan_offset + wave_size / zoom_factor))
  local visible_samples = visible_end - visible_start + 1
  
  local rel_x = ev.x / w
  local rel_y = ev.y / h
  local idx = math.floor(visible_start + rel_x * (visible_samples - 1))
  
  if idx >= 1 and idx <= wave_size then
    selected_sample_index = idx
    
    -- Update sample value when drawing
    if ev.buttons == 1 then
      is_drawing = true
      wave_data[idx] = math.floor((1 - rel_y) * 65535)
      waveform_canvas:update()
      update_hex_display()
      highlight_sample(idx)
    elseif ev.buttons == 0 and not is_drawing then
      highlight_sample(idx)
    end
  end
end

-- Zoom functions
local function zoom_in()
  zoom_factor = math.min(max_zoom, zoom_factor * 1.5)
  pan_offset = math.max(0, math.min(wave_size - wave_size/zoom_factor, pan_offset))
  update_all_displays()
end

local function zoom_out()
  zoom_factor = math.max(min_zoom, zoom_factor / 1.5)
  pan_offset = math.max(0, math.min(wave_size - wave_size/zoom_factor, pan_offset))
  update_all_displays()
end

local function zoom_fit()
  zoom_factor = 1.0
  pan_offset = 0
  update_all_displays()
end

-- Pan functions
local function pan_left()
  pan_offset = math.max(0, pan_offset - wave_size / zoom_factor * 0.1)
  update_all_displays()
end

local function pan_right()
  pan_offset = math.min(wave_size - wave_size/zoom_factor, pan_offset + wave_size / zoom_factor * 0.1)
  update_all_displays()
end

-- Hex editor functions
local function update_hex_display()
  if not hex_buttons then return end
  for i = 1, wave_size do
    if hex_buttons[i] then
      hex_buttons[i].text = string.format("%04X", wave_data[i])
    end
  end
end

local function highlight_sample(idx)
  if not hex_buttons then return end
  
  for i = 1, wave_size do
    if hex_buttons[i] then
      hex_buttons[i].color = nil
    end
  end
  
  if idx >= 1 and idx <= wave_size and hex_buttons[idx] then
    hex_buttons[idx].color = {255, 100, 100}
  end
end

local function edit_hex_sample(idx)
  local current_value = string.format("%04X", wave_data[idx])
  local result = renoise.app():show_prompt("Edit Sample Value", 
    string.format("Enter hex value for sample %d (0000-FFFF):", idx), current_value)
  
  if result and result ~= "" then
    local value = tonumber(result, 16)
    if value and value >= 0 and value <= 65535 then
      wave_data[idx] = value
      selected_sample_index = idx
      waveform_canvas:update()
      update_hex_display()
      highlight_sample(idx)
    else
      renoise.app():show_error("Invalid hex value! Must be between 0000 and FFFF")
    end
  end
end

-- WAV file format functions
local function create_wav_header(sample_rate, num_channels, num_samples, bits_per_sample)
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
local function save_wave_bin()
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
  end
end

local function save_wave_wav()
  local suggested_name = string.format("waveform_%dsamples.wav", wave_size)
  local filename = renoise.app():prompt_for_filename_to_write(".wav", suggested_name)
  
  if filename then
    local file = io.open(filename, "wb")
    if file then
      -- Write WAV header
      local header = create_wav_header(44100, 1, wave_size, 16)
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
  end
end

local function load_wave()
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
        zoom_fit()
        renoise.app():show_status("Wave loaded: " .. filename)
      else
        renoise.app():show_error(string.format("Invalid file size! Expected at least %d bytes, got %d", 
          expected_size, #content - data_offset))
      end
    else
      renoise.app():show_error("Could not read file")
    end
  end
end

-- Wavetable functions
local function add_wavetable_wave()
  local new_wave = {data = table.create(), name = string.format("Wave %d", #wavetable_waves + 1)}
  for i = 1, wavetable_size do
    new_wave.data[i] = 32768
  end
  table.insert(wavetable_waves, new_wave)
  current_wave_index = #wavetable_waves
  
  -- Copy current editor wave to new wavetable wave
  for i = 1, math.min(wave_size, wavetable_size) do
    new_wave.data[i] = wave_data[i]
  end
  
  renoise.app():show_status(string.format("Added %s to wavetable", new_wave.name))
end

local function save_wavetable()
  if #wavetable_waves == 0 then
    renoise.app():show_error("No waves in wavetable to save")
    return
  end
  
  local suggested_name = string.format("wavetable_%dwaves_%dsamples.wav", #wavetable_waves, wavetable_size)
  local filename = renoise.app():prompt_for_filename_to_write(".wav", suggested_name)
  
  if filename then
    local file = io.open(filename, "wb")
    if file then
      local total_samples = #wavetable_waves * wavetable_size
      local header = create_wav_header(44100, 1, total_samples, 16)
      file:write(header)
      
      -- Write all waves sequentially
      for _, wave in ipairs(wavetable_waves) do
        for i = 1, wavetable_size do
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
  end
end

local function export_to_sample()
  local inst = renoise.song().selected_instrument
  if not inst:sample(1) then inst:insert_sample_at(1) end
  local sample = inst:sample(1)
  local buffer = sample.sample_buffer
  buffer:create_sample_data(44100, 1, wave_size)
  for i = 1, wave_size do
    buffer:set_sample_data(1, i, (wave_data[i] - 32768) / 32768)
  end
  renoise.app():show_status("Wave exported to selected instrument")
end

-- Rebuild hex editor display (compact version)
local function rebuild_hex_editor()
  hex_buttons = {}
  local hex_columns = {}
  local items_per_row = 8  -- Reduced for better fit
  local max_rows = 8       -- Limit rows to prevent dialog from being too tall
  local rows = math.min(max_rows, math.ceil(wave_size / items_per_row))
  
  for row = 1, rows do
    local hex_row = vb:row{ spacing = 1 }
    
    local offset = (row - 1) * items_per_row
    hex_row:add_child(vb:text{
      text = string.format("%02X:", offset),
      width = 30,
      font = "mono"
    })
    
    for col = 1, items_per_row do
      local idx = offset + col
      if idx <= wave_size and idx <= max_rows * items_per_row then
        local hex_btn = vb:button{
          text = string.format("%04X", wave_data[idx]),
          width = 38,
          height = 18,
          notifier = function() edit_hex_sample(idx) end
        }
        hex_buttons[idx] = hex_btn
        hex_row:add_child(hex_btn)
      end
    end
    
    table.insert(hex_columns, hex_row)
  end
  
  -- Add info text if we're not showing all samples
  if wave_size > max_rows * items_per_row then
    local info_row = vb:row{
      vb:text{
        text = string.format("... showing first %d of %d samples", max_rows * items_per_row, wave_size),
        font = "italic"
      }
    }
    table.insert(hex_columns, info_row)
  end
  
  return hex_columns
end

local function update_all_displays()
  if waveform_canvas then
    waveform_canvas:update()
  end
  update_hex_display()
  if selected_sample_index > 0 then
    highlight_sample(selected_sample_index)
  end
end

local function change_wave_size(new_size)
  wave_size = new_size
  local old_data = wave_data
  wave_data = table.create()
  
  for i = 1, wave_size do
    if i <= #old_data then
      wave_data[i] = old_data[i]
    else
      wave_data[i] = 32768
    end
  end
  
  selected_sample_index = -1
  zoom_fit()
  
  if pcm_dialog then
    pcm_dialog:close()
  end
  show_pcm_dialog()
end

-- Main dialog function
function show_pcm_dialog()
  waveform_canvas = vb:canvas{
    width = 800,
    height = 200,
    mode = "plain",
    render = render_waveform,
    mouse_handler = handle_mouse
  }
  
  generate_waveform("sine")
  
  local hex_editor_rows = rebuild_hex_editor()
  local hex_editor_content = vb:column{ spacing = 2 }
  for _, row in ipairs(hex_editor_rows) do
    hex_editor_content:add_child(row)
  end
  
  local dialog_content = vb:column{
    margin = 10,
    spacing = 10,
    
    vb:text{
      text = "Paketti Advanced PCM Wave Editor",
      style = "strong",
      font = "big"
    },
    
    -- Main controls row
    vb:row{
      spacing = 10,
      vb:text{ text = "Waveform:" },
      vb:popup{
        items = {"sine", "square", "saw", "triangle", "noise"},
        value = 1,
        notifier = function(idx)
          local types = {"sine", "square", "saw", "triangle", "noise"}
          generate_waveform(types[idx])
          update_all_displays()
        end
      },
      vb:text{ text = "Samples:" },
      vb:popup{
        items = {"32", "64", "128", "256", "512", "1024"},
        value = 2,
        notifier = function(idx)
          change_wave_size(wave_size_options[idx])
        end
      },
      vb:text{ text = "Interpolation:" },
      vb:popup{
        items = {"Linear", "Cubic", "Bezier"},
        value = 1,
        notifier = function(idx)
          local modes = {"linear", "cubic", "bezier"}
          interpolation_mode = modes[idx]
          update_all_displays()
        end
      }
    },
    
    -- Zoom controls row
    vb:row{
      spacing = 5,
      vb:text{ text = "Zoom/Pan:" },
      vb:button{ text = "Zoom In", width = 60, notifier = zoom_in },
      vb:button{ text = "Zoom Out", width = 60, notifier = zoom_out },
      vb:button{ text = "Fit", width = 40, notifier = zoom_fit },
      vb:button{ text = "← Pan", width = 50, notifier = pan_left },
      vb:button{ text = "Pan →", width = 50, notifier = pan_right },
      vb:checkbox{
        value = show_sample_points,
        notifier = function(value)
          show_sample_points = value
          update_all_displays()
        end
      },
      vb:text{ text = "Show Points" }
    },
    
    waveform_canvas,
    
    vb:row{
      spacing = 10,
      
      -- Hex editor column
      vb:column{
        style = "group",
        margin = 5,
        width = 350,
        vb:text{
          text = "Hex Editor (Click to edit)",
          style = "strong"
        },
        hex_editor_content
      },
      
      -- Tools column
      vb:column{
        style = "group",
        margin = 5,
        spacing = 5,
        vb:text{
          text = "Export Tools",
          style = "strong"
        },
        vb:button{
          text = "Export to Sample Slot",
          width = 150,
          notifier = export_to_sample
        },
        vb:button{
          text = "Save as .BIN File",
          width = 150,
          notifier = save_wave_bin
        },
        vb:button{
          text = "Save as .WAV File", 
          width = 150,
          notifier = save_wave_wav
        },
        vb:button{
          text = "Load Wave File",
          width = 150,
          notifier = load_wave
        }
      },
      
      -- Wavetable column
      vb:column{
        style = "group",
        margin = 5,
        spacing = 5,
        vb:text{
          text = "Wavetable Tools",
          style = "strong"
        },
        vb:text{
          text = string.format("Waves: %d", #wavetable_waves),
          width = 150
        },
        vb:button{
          text = "Add Current to Wavetable",
          width = 150,
          notifier = add_wavetable_wave
        },
        vb:button{
          text = "Save Wavetable (.WAV)",
          width = 150,
          notifier = save_wavetable
        },
        vb:text{
          text = "Wavetables are collections of\nsingle-cycle waveforms used\nfor wavetable synthesis.\nEach wave becomes one\nframe in the wavetable.",
          width = 150,
          height = 80
        }
      }
    }
  }
  
  local function keyhandler(dialog, key)
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
  
  pcm_dialog = renoise.app():show_custom_dialog(DIALOG_TITLE, dialog_content, keyhandler)
  update_all_displays()
end

-- Menu entry and keybinding
renoise.tool():add_menu_entry{name = "--Main Menu:Tools:Paketti:Xperimental/Work in Progress:Advanced PCM Wave Editor...",invoke = show_pcm_dialog}

renoise.tool():add_keybinding{name = "Global:Paketti:Show Advanced PCM Wave Editor",invoke = show_pcm_dialog}


