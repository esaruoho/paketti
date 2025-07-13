-- Chebyshev Waveshaper for Paketti
-- Advanced polynomial waveshaping with real-time preview

local vb = renoise.ViewBuilder()
local dialog = nil
local current_polynomial = 2
local drive_value = 1.0
local mix_value = 1.0
local output_gain_value = 1.0
local auto_normalize_enabled = false  -- Add auto-normalize state
local preview_enabled = false
local backup_sample_data = nil
local backup_sample_properties = nil

-- Canvas state variables
local parameter_canvas = nil
local waveform_canvas = nil
local waveform_canvas_width = 500
local waveform_canvas_height = 200
local parameter_canvas_width = waveform_canvas_width  -- Match waveform width
local parameter_canvas_height = 210
local is_dragging_param = false
local drag_param_type = nil -- "drive", "mix", "output"

-- Double-click detection variables
local last_click_time = 0
local last_click_x = 0
local last_click_y = 0
local double_click_threshold = 500  -- milliseconds

-- Cached waveform data for display
local original_waveform_cache = nil
local processed_waveform_cache = nil

-- Chebyshev polynomial functions (T2-T8)
local function chebyshev_t2(x)
  return 2 * x * x - 1
end

local function chebyshev_t3(x)
  return 4 * x * x * x - 3 * x
end

local function chebyshev_t4(x)
  local x2 = x * x
  return 8 * x2 * x2 - 8 * x2 + 1
end

local function chebyshev_t5(x)
  local x2 = x * x
  local x3 = x2 * x
  return 16 * x3 * x2 - 20 * x3 + 5 * x
end

local function chebyshev_t6(x)
  local x2 = x * x
  local x4 = x2 * x2
  return 32 * x4 * x2 - 48 * x4 + 18 * x2 - 1
end

local function chebyshev_t7(x)
  local x2 = x * x
  local x3 = x2 * x
  local x4 = x2 * x2
  return 64 * x4 * x3 - 112 * x4 * x + 56 * x3 - 7 * x
end

local function chebyshev_t8(x)
  local x2 = x * x
  local x4 = x2 * x2
  local x6 = x4 * x2
  return 128 * x4 * x4 - 256 * x6 + 160 * x4 - 32 * x2 + 1
end

-- Get the appropriate Chebyshev function
local function get_chebyshev_function(order)
  if order == 2 then return chebyshev_t2
  elseif order == 3 then return chebyshev_t3
  elseif order == 4 then return chebyshev_t4
  elseif order == 5 then return chebyshev_t5
  elseif order == 6 then return chebyshev_t6
  elseif order == 7 then return chebyshev_t7
  elseif order == 8 then return chebyshev_t8
  else return chebyshev_t2 end
end

-- Get polynomial description
local function get_polynomial_description(order)
  if order == 2 then return "2nd order - Adds even harmonics, warm saturation"
  elseif order == 3 then return "3rd order - Adds odd harmonics, tube-like distortion"
  elseif order == 4 then return "4th order - Complex even harmonics, aggressive saturation"
  elseif order == 5 then return "5th order - Rich odd harmonics, vintage tube sound"
  elseif order == 6 then return "6th order - Dense even harmonics, harsh clipping"
  elseif order == 7 then return "7th order - Complex odd harmonics, fuzzy distortion"
  elseif order == 8 then return "8th order - Very dense harmonics, extreme saturation"
  else return "Unknown polynomial order" end
end

-- Cache sample waveform data for display
local function cache_sample_waveform()
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    return false
  end
  
  local buffer = sample.sample_buffer
  local num_frames = buffer.number_of_frames
  local num_channels = buffer.number_of_channels
  
  -- Cache original waveform (downsample to canvas width for performance)
  original_waveform_cache = {}
  for pixel = 1, waveform_canvas_width do
    local frame_pos = math.floor((pixel - 1) / (waveform_canvas_width - 1) * (num_frames - 1)) + 1
    frame_pos = math.max(1, math.min(num_frames, frame_pos))
    
    -- Average all channels
    local sample_value = 0
    for channel = 1, num_channels do
      sample_value = sample_value + buffer:sample_data(channel, frame_pos)
    end
    sample_value = sample_value / num_channels
    
    original_waveform_cache[pixel] = sample_value
  end
  
  return true
end

-- Generate processed waveform cache
local function generate_processed_waveform_cache()
  if not original_waveform_cache then
    return false
  end
  
  local chebyshev_func = get_chebyshev_function(current_polynomial)
  processed_waveform_cache = {}
  
  for pixel = 1, waveform_canvas_width do
    local input_sample = original_waveform_cache[pixel]
    local driven_sample = input_sample * drive_value
    driven_sample = math.max(-1.0, math.min(1.0, driven_sample))
    
    -- Apply Chebyshev polynomial with proper scaling
    local shaped_sample
    if current_polynomial % 2 == 0 then
      local abs_input = math.abs(driven_sample)
      local sign = driven_sample >= 0 and 1 or -1
      shaped_sample = sign * abs_input * chebyshev_func(abs_input)
    else
      shaped_sample = chebyshev_func(driven_sample)
    end
    
    -- Apply scaling
    local scale_factor = 1.0
    if current_polynomial == 2 then scale_factor = 0.5
    elseif current_polynomial == 3 then scale_factor = 0.35
    elseif current_polynomial == 4 then scale_factor = 0.25
    elseif current_polynomial == 5 then scale_factor = 0.2
    elseif current_polynomial == 6 then scale_factor = 0.15
    elseif current_polynomial == 7 then scale_factor = 0.12
    elseif current_polynomial == 8 then scale_factor = 0.1
    end
    
    shaped_sample = shaped_sample * scale_factor
    shaped_sample = math.tanh(shaped_sample)
    
    -- Mix and apply output gain
    local mixed_sample = input_sample * (1 - mix_value) + shaped_sample * mix_value
    local final_sample = mixed_sample * output_gain_value
    final_sample = math.max(-1.0, math.min(1.0, final_sample))
    
    processed_waveform_cache[pixel] = final_sample
  end
  
  return true
end

-- Render parameter canvas
local function render_parameter_canvas(ctx)
  local w, h = parameter_canvas_width, parameter_canvas_height
  ctx:clear_rect(0, 0, w, h)
  
  -- Draw background with subtle gradient
  ctx:set_fill_linear_gradient(0, 0, 0, h)
  ctx:add_fill_color_stop(0, {35, 35, 35, 255})
  ctx:add_fill_color_stop(1, {15, 15, 15, 255})
  ctx:begin_path()
  ctx:rect(0, 0, w, h)
  ctx:fill()
  
  -- Draw three vertical slider tracks with gradients (4x wider sliders)
  local slider_width = 80  -- 4x wider than before (was 20)
  local slider_spacing = (w - (3 * slider_width)) / 4
  
  -- Drive slider (red) - track
  local drive_x = slider_spacing
  local drive_y = h - 10 - ((drive_value - 0.1) / 2.9) * (h - 20)
  
  -- Drive track gradient (dark red recessed look)
  ctx:set_fill_linear_gradient(drive_x, 10, drive_x + slider_width, 10)
  ctx:add_fill_color_stop(0, {80, 25, 25, 255})
  ctx:add_fill_color_stop(0.5, {45, 15, 15, 255})
  ctx:add_fill_color_stop(1, {80, 25, 25, 255})
  ctx:begin_path()
  ctx:rect(drive_x, 10, slider_width, h - 20)
  ctx:fill()
  
  -- Drive handle gradient (bright red with 3D effect)
  ctx:set_fill_linear_gradient(drive_x, drive_y - 8, drive_x + slider_width, drive_y - 8)
  ctx:add_fill_color_stop(0, {255, 180, 180, 255})
  ctx:add_fill_color_stop(0.3, {255, 120, 120, 255})
  ctx:add_fill_color_stop(0.7, {220, 80, 80, 255})
  ctx:add_fill_color_stop(1, {180, 60, 60, 255})
  ctx:begin_path()
  ctx:rect(drive_x, drive_y - 8, slider_width, 16)
  ctx:fill()
  
  -- Drive handle highlight
  ctx:set_fill_linear_gradient(drive_x + 2, drive_y - 6, drive_x + 2, drive_y - 2)
  ctx:add_fill_color_stop(0, {255, 220, 220, 180})
  ctx:add_fill_color_stop(1, {255, 150, 150, 80})
  ctx:begin_path()
  ctx:rect(drive_x + 2, drive_y - 6, slider_width - 4, 4)
  ctx:fill()
  
  -- Mix slider (green) - track
  local mix_x = slider_spacing * 2 + slider_width
  local mix_y = h - 10 - mix_value * (h - 20)
  
  -- Mix track gradient (dark green recessed look)
  ctx:set_fill_linear_gradient(mix_x, 10, mix_x + slider_width, 10)
  ctx:add_fill_color_stop(0, {25, 80, 25, 255})
  ctx:add_fill_color_stop(0.5, {15, 45, 15, 255})
  ctx:add_fill_color_stop(1, {25, 80, 25, 255})
  ctx:begin_path()
  ctx:rect(mix_x, 10, slider_width, h - 20)
  ctx:fill()
  
  -- Mix handle gradient (bright green with 3D effect)
  ctx:set_fill_linear_gradient(mix_x, mix_y - 8, mix_x + slider_width, mix_y - 8)
  ctx:add_fill_color_stop(0, {180, 255, 180, 255})
  ctx:add_fill_color_stop(0.3, {120, 255, 120, 255})
  ctx:add_fill_color_stop(0.7, {80, 220, 80, 255})
  ctx:add_fill_color_stop(1, {60, 180, 60, 255})
  ctx:begin_path()
  ctx:rect(mix_x, mix_y - 8, slider_width, 16)
  ctx:fill()
  
  -- Mix handle highlight
  ctx:set_fill_linear_gradient(mix_x + 2, mix_y - 6, mix_x + 2, mix_y - 2)
  ctx:add_fill_color_stop(0, {220, 255, 220, 180})
  ctx:add_fill_color_stop(1, {150, 255, 150, 80})
  ctx:begin_path()
  ctx:rect(mix_x + 2, mix_y - 6, slider_width - 4, 4)
  ctx:fill()
  
  -- Output slider (blue) - track
  local output_x = slider_spacing * 3 + slider_width * 2
  local output_y = h - 10 - ((output_gain_value - 0.1) / 1.9) * (h - 20)
  
  -- Output track gradient (dark blue recessed look)
  ctx:set_fill_linear_gradient(output_x, 10, output_x + slider_width, 10)
  ctx:add_fill_color_stop(0, {25, 25, 80, 255})
  ctx:add_fill_color_stop(0.5, {15, 15, 45, 255})
  ctx:add_fill_color_stop(1, {25, 25, 80, 255})
  ctx:begin_path()
  ctx:rect(output_x, 10, slider_width, h - 20)
  ctx:fill()
  
  -- Output handle gradient (bright blue with 3D effect)
  ctx:set_fill_linear_gradient(output_x, output_y - 8, output_x + slider_width, output_y - 8)
  ctx:add_fill_color_stop(0, {180, 180, 255, 255})
  ctx:add_fill_color_stop(0.3, {120, 120, 255, 255})
  ctx:add_fill_color_stop(0.7, {80, 80, 220, 255})
  ctx:add_fill_color_stop(1, {60, 60, 180, 255})
  ctx:begin_path()
  ctx:rect(output_x, output_y - 8, slider_width, 16)
  ctx:fill()
  
  -- Output handle highlight
  ctx:set_fill_linear_gradient(output_x + 2, output_y - 6, output_x + 2, output_y - 2)
  ctx:add_fill_color_stop(0, {220, 220, 255, 180})
  ctx:add_fill_color_stop(1, {150, 150, 255, 80})
  ctx:begin_path()
  ctx:rect(output_x + 2, output_y - 6, slider_width - 4, 4)
  ctx:fill()
  
  -- Draw simple colored dots below sliders as indicators
  ctx.fill_color = {255, 100, 100, 255}  -- Red dot for Drive
  ctx:begin_path()
  ctx:rect(drive_x + 7, h - 15, 6, 6)
  ctx:fill()
  
  ctx.fill_color = {100, 255, 100, 255}  -- Green dot for Mix
  ctx:begin_path()
  ctx:rect(mix_x + 7, h - 15, 6, 6)
  ctx:fill()
  
  ctx.fill_color = {100, 100, 255, 255}  -- Blue dot for Output
  ctx:begin_path()
  ctx:rect(output_x + 7, h - 15, 6, 6)
  ctx:fill()
end

-- Render waveform canvas
local function render_waveform_canvas(ctx)
  local w, h = waveform_canvas_width, waveform_canvas_height
  ctx:clear_rect(0, 0, w, h)
  
  -- Draw background
  ctx.fill_color = {15, 15, 15, 255}
  ctx:begin_path()
  ctx:rect(0, 0, w, h)
  ctx:fill()
  
  -- Draw grid
  ctx.stroke_color = {40, 40, 40, 255}
  ctx.line_width = 1
  for i = 0, 10 do
    local x = (i / 10) * w
    ctx:begin_path()
    ctx:move_to(x, 0)
    ctx:line_to(x, h)
    ctx:stroke()
  end
  for i = 0, 8 do
    local y = (i / 8) * h
    ctx:begin_path()
    ctx:move_to(0, y)
    ctx:line_to(w, y)
    ctx:stroke()
  end
  
  -- Draw center line (zero)
  ctx.stroke_color = {100, 100, 100, 255}
  ctx.line_width = 1
  local center_y = h / 2
  ctx:begin_path()
  ctx:move_to(0, center_y)
  ctx:line_to(w, center_y)
  ctx:stroke()
  
  -- Draw original waveform (if cached)
  if original_waveform_cache then
    ctx.stroke_color = {100, 150, 255, 180}
    ctx.line_width = 1
    ctx:begin_path()
    
    for pixel = 1, #original_waveform_cache do
      local x = (pixel - 1) / (#original_waveform_cache - 1) * w
      local y = center_y - (original_waveform_cache[pixel] * center_y)
      
      if pixel == 1 then
        ctx:move_to(x, y)
      else
        ctx:line_to(x, y)
      end
    end
    ctx:stroke()
  end
  
  -- Draw processed waveform (if cached)
  if processed_waveform_cache then
    ctx.stroke_color = {255, 150, 100, 255}
    ctx.line_width = 2
    ctx:begin_path()
    
    for pixel = 1, #processed_waveform_cache do
      local x = (pixel - 1) / (#processed_waveform_cache - 1) * w
      local y = center_y - (processed_waveform_cache[pixel] * center_y)
      
      if pixel == 1 then
        ctx:move_to(x, y)
      else
        ctx:line_to(x, y)
      end
    end
    ctx:stroke()
  end
end

-- Update canvas displays
local function update_canvas_displays()
  if cache_sample_waveform() then
    generate_processed_waveform_cache()
  end
  
  if parameter_canvas then
    parameter_canvas:update()
  end
  if waveform_canvas then
    waveform_canvas:update()
  end
end

-- Handle mouse events on parameter canvas
local function handle_parameter_canvas_mouse(ev)
  local w, h = parameter_canvas_width, parameter_canvas_height
  local slider_width = 80  -- Match the render function
  local slider_spacing = (w - (3 * slider_width)) / 4
  
  -- Calculate slider X positions
  local drive_x = slider_spacing
  local mix_x = slider_spacing * 2 + slider_width
  local output_x = slider_spacing * 3 + slider_width * 2
  
  -- Check if mouse is within canvas bounds
  local mouse_x = ev.position.x
  local mouse_y = ev.position.y
  local mouse_in_bounds = mouse_x >= 0 and mouse_x <= w and mouse_y >= 0 and mouse_y <= h
  
  if ev.type == "down" and ev.button == "left" and mouse_in_bounds then
    -- Manual double-click detection
    local current_time = os.clock() * 1000  -- Convert to milliseconds
    local time_diff = current_time - last_click_time
    local distance = math.sqrt((mouse_x - last_click_x)^2 + (mouse_y - last_click_y)^2)
    
    local is_double_click = (time_diff < double_click_threshold) and (distance < 10)
    
    if is_double_click then
      -- Determine which slider was double-clicked
      if mouse_x >= drive_x and mouse_x <= drive_x + slider_width then
        -- Drive slider - reset to 1.0
        drive_value = 1.0
        if vb.views.drive_value then
          vb.views.drive_value.text = string.format("%.2f", drive_value)
        end
        if vb.views.canvas_drive_value then
          vb.views.canvas_drive_value.text = string.format("%.2f", drive_value)
        end
        update_canvas_displays()
        PakettiChebyshevUpdatePreview()
        -- Reset click tracking
        last_click_time = 0
        return -- Don't start dragging on double-click
        
      elseif mouse_x >= mix_x and mouse_x <= mix_x + slider_width then
        -- Mix slider - reset to 0.0
        mix_value = 0.0
        if vb.views.mix_value then
          vb.views.mix_value.text = string.format("%.2f", mix_value)
        end
        if vb.views.canvas_mix_value then
          vb.views.canvas_mix_value.text = string.format("%.2f", mix_value)
        end
        update_canvas_displays()
        PakettiChebyshevUpdatePreview()
        -- Reset click tracking
        last_click_time = 0
        return -- Don't start dragging on double-click
        
      elseif mouse_x >= output_x and mouse_x <= output_x + slider_width then
        -- Output slider - reset to 1.0
        output_gain_value = 1.0
        if vb.views.output_value then
          vb.views.output_value.text = string.format("%.2f", output_gain_value)
        end
        if vb.views.canvas_output_value then
          vb.views.canvas_output_value.text = string.format("%.2f", output_gain_value)
        end
        update_canvas_displays()
        PakettiChebyshevUpdatePreview()
        -- Reset click tracking
        last_click_time = 0
        return -- Don't start dragging on double-click
      end
    end
    
    -- Update click tracking for next time
    last_click_time = current_time
    last_click_x = mouse_x
    last_click_y = mouse_y
    -- Determine which slider was clicked based on X position
    if mouse_x >= drive_x and mouse_x <= drive_x + slider_width then
      -- Drive slider
      drag_param_type = "drive"
      is_dragging_param = true
      
      -- Calculate value from Y position (inverted - top is max, bottom is min)
      local y_norm = 1 - ((mouse_y - 10) / (h - 20))
      drive_value = math.max(0.1, math.min(3.0, 0.1 + y_norm * 2.9))
      
      -- Update slider and text
      if vb.views.drive_value then
        vb.views.drive_value.text = string.format("%.2f", drive_value)
      end
      if vb.views.canvas_drive_value then
        vb.views.canvas_drive_value.text = string.format("%.2f", drive_value)
      end
      
    elseif mouse_x >= mix_x and mouse_x <= mix_x + slider_width then
      -- Mix slider
      drag_param_type = "mix"
      is_dragging_param = true
      
      -- Calculate value from Y position
      local y_norm = 1 - ((mouse_y - 10) / (h - 20))
      mix_value = math.max(0.0, math.min(1.0, y_norm))
      
      -- Update slider and text
      if vb.views.mix_value then
        vb.views.mix_value.text = string.format("%.2f", mix_value)
      end
      if vb.views.canvas_mix_value then
        vb.views.canvas_mix_value.text = string.format("%.2f", mix_value)
      end
      
    elseif mouse_x >= output_x and mouse_x <= output_x + slider_width then
      -- Output slider
      drag_param_type = "output"
      is_dragging_param = true
      
      -- Calculate value from Y position
      local y_norm = 1 - ((mouse_y - 10) / (h - 20))
      output_gain_value = math.max(0.1, math.min(2.0, 0.1 + y_norm * 1.9))
      
      -- Update slider and text
      if vb.views.output_value then
        vb.views.output_value.text = string.format("%.2f", output_gain_value)
      end
      if vb.views.canvas_output_value then
        vb.views.canvas_output_value.text = string.format("%.2f", output_gain_value)
      end
    end
    
    -- Update canvases and preview only if we're dragging
    if is_dragging_param then
      update_canvas_displays()
      PakettiChebyshevUpdatePreview()
    end
    
  elseif ev.type == "move" then
    -- Only continue if we're dragging (allow dragging outside bounds)
    if is_dragging_param then
      -- Clamp mouse position to canvas bounds for value calculation (extra safety)
      local clamped_y = math.max(10, math.min(h - 10, mouse_y))
      
      -- Update value based on which parameter we're dragging
              if drag_param_type == "drive" then
          local y_norm = 1 - ((clamped_y - 10) / (h - 20))
          drive_value = math.max(0.1, math.min(3.0, 0.1 + y_norm * 2.9))
          
          -- Update slider and text
          if vb.views.drive_value then
            vb.views.drive_value.text = string.format("%.2f", drive_value)
          end
          if vb.views.canvas_drive_value then
            vb.views.canvas_drive_value.text = string.format("%.2f", drive_value)
          end
          
        elseif drag_param_type == "mix" then
          local y_norm = 1 - ((clamped_y - 10) / (h - 20))
          mix_value = math.max(0.0, math.min(1.0, y_norm))
          
          -- Update slider and text
          if vb.views.mix_value then
            vb.views.mix_value.text = string.format("%.2f", mix_value)
          end
          if vb.views.canvas_mix_value then
            vb.views.canvas_mix_value.text = string.format("%.2f", mix_value)
          end
          
        elseif drag_param_type == "output" then
          local y_norm = 1 - ((clamped_y - 10) / (h - 20))
          output_gain_value = math.max(0.1, math.min(2.0, 0.1 + y_norm * 1.9))
          
          -- Update slider and text
          if vb.views.output_value then
            vb.views.output_value.text = string.format("%.2f", output_gain_value)
          end
          if vb.views.canvas_output_value then
            vb.views.canvas_output_value.text = string.format("%.2f", output_gain_value)
          end
        end
      
      -- Update canvases and preview
      update_canvas_displays()
      PakettiChebyshevUpdatePreview()
    end
    
  elseif ev.type == "up" and ev.button == "left" then
    -- Always reset drag state on mouse up, regardless of position
    is_dragging_param = false
    drag_param_type = nil
  end
end

-- Apply Chebyshev waveshaping to sample
local function apply_chebyshev_waveshaping(sample, polynomial_order, drive, mix, output_gain)
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    return false
  end

  local buffer = sample.sample_buffer
  local num_channels = buffer.number_of_channels
  local num_frames = buffer.number_of_frames
  local chebyshev_func = get_chebyshev_function(polynomial_order)

  buffer:prepare_sample_data_changes()

  for channel = 1, num_channels do
    for frame = 1, num_frames do
      local input_sample = buffer:sample_data(channel, frame)
      local driven_sample = input_sample * drive
      
      -- Clamp input to prevent extreme values
      driven_sample = math.max(-1.0, math.min(1.0, driven_sample))
      
      -- Apply Chebyshev polynomial with proper scaling for even/odd orders
      local shaped_sample
      if polynomial_order % 2 == 0 then
        -- Even-order polynomials: make them bipolar
        local abs_input = math.abs(driven_sample)
        local sign = driven_sample >= 0 and 1 or -1
        shaped_sample = sign * abs_input * chebyshev_func(abs_input)
      else
        -- Odd-order polynomials: naturally bipolar
        shaped_sample = chebyshev_func(driven_sample)
      end
      
      -- Apply order-specific scaling to prevent clipping
      local scale_factor = 1.0
      if polynomial_order == 2 then scale_factor = 0.5
      elseif polynomial_order == 3 then scale_factor = 0.35
      elseif polynomial_order == 4 then scale_factor = 0.25
      elseif polynomial_order == 5 then scale_factor = 0.2
      elseif polynomial_order == 6 then scale_factor = 0.15
      elseif polynomial_order == 7 then scale_factor = 0.12
      elseif polynomial_order == 8 then scale_factor = 0.1
      end
      
      shaped_sample = shaped_sample * scale_factor
      
      -- Soft clipping for any remaining peaks
      shaped_sample = math.tanh(shaped_sample)
      
      -- Mix with original signal
      local mixed_sample = input_sample * (1 - mix) + shaped_sample * mix
      
      -- Apply output gain
      local final_sample = mixed_sample * output_gain
      
      -- Final clipping protection
      final_sample = math.max(-1.0, math.min(1.0, final_sample))
      
      buffer:set_sample_data(channel, frame, final_sample)
    end
  end

  buffer:finalize_sample_data_changes()
  return true
end

-- Backup current sample data for preview mode
local function backup_sample()
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    return false
  end

  local buffer = sample.sample_buffer
  backup_sample_data = {}
  
  for channel = 1, buffer.number_of_channels do
    backup_sample_data[channel] = {}
    for frame = 1, buffer.number_of_frames do
      backup_sample_data[channel][frame] = buffer:sample_data(channel, frame)
    end
  end
  
  return true
end

-- Restore sample data from backup
local function restore_sample()
  if not backup_sample_data then return false end
  
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    return false
  end

  local buffer = sample.sample_buffer
  buffer:prepare_sample_data_changes()
  
  for channel = 1, #backup_sample_data do
    for frame = 1, #backup_sample_data[channel] do
      buffer:set_sample_data(channel, frame, backup_sample_data[channel][frame])
    end
  end
  
  buffer:finalize_sample_data_changes()
  return true
end

-- Apply normalization using the existing Paketti function
local function apply_normalization()
  -- Use the existing NormalizeSelectedSliceInSample function from PakettiProcess.lua
  if NormalizeSelectedSliceInSample then
    NormalizeSelectedSliceInSample()
  else
    renoise.app():show_status("Normalization function not available")
  end
end

-- Update preview
function PakettiChebyshevUpdatePreview()
  if not preview_enabled then return end
  
  -- Restore original sample first
  restore_sample()
  
  -- Apply current settings
  local sample = renoise.song().selected_sample
  if apply_chebyshev_waveshaping(sample, current_polynomial, drive_value, mix_value, output_gain_value) then
    -- Apply auto-normalize in preview if enabled
    if auto_normalize_enabled then
      apply_normalization()
    end
  end
  
  -- Update canvas displays
  update_canvas_displays()
end

-- Apply final processing
local function apply_processing()
  if preview_enabled then
    -- Disable preview mode first
    preview_enabled = false
    restore_sample()
  end
  
  -- Apply the effect
  local sample = renoise.song().selected_sample
  if apply_chebyshev_waveshaping(sample, current_polynomial, drive_value, mix_value, output_gain_value) then
    -- Apply auto-normalize if enabled
    if auto_normalize_enabled then
      apply_normalization()
    end
    
    renoise.app():show_status(string.format("Applied Chebyshev T%d waveshaping%s", 
      current_polynomial, auto_normalize_enabled and " + normalized" or ""))
  else
    renoise.app():show_error("Failed to apply Chebyshev waveshaping")
  end
end

-- Reset to original sample
local function reset_sample()
  if backup_sample_data then
    restore_sample()
    preview_enabled = false
    renoise.app():show_status("Reset to original sample")
  end
end

-- Toggle preview mode
local function toggle_preview()
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_error("No valid sample selected")
    return
  end
  
  if preview_enabled then
    -- Disable preview
    preview_enabled = false
    restore_sample()
    renoise.app():show_status("Preview disabled")
  else
    -- Enable preview
    if backup_sample() then
      preview_enabled = true
      PakettiChebyshevUpdatePreview()
      renoise.app():show_status("Preview enabled - changes are temporary")
    else
      renoise.app():show_error("Failed to backup sample for preview")
    end
  end
  
  -- Update button text
  if vb and vb.views and vb.views.preview_button then
    vb.views.preview_button.text = preview_enabled and "Disable Preview" or "Enable Preview"
  end
end

-- Key handler function
local function my_keyhandler_func(dialog, key)
  local closer = "esc"
  if preferences and preferences.pakettiDialogClose then
    closer = preferences.pakettiDialogClose.value
  end
  
  if key.modifiers == "" and key.name == closer then
    print("DEBUG: Chebyshev Waveshaper - Close key pressed:", key.name)
    
    -- Reset dragging state only when closing
    if is_dragging_param then
      is_dragging_param = false
      drag_param_type = nil
    end
    
    -- Clean up preview mode if active
    if preview_enabled then
      preview_enabled = false
      restore_sample()
      print("DEBUG: Chebyshev Waveshaper - Cleaned up preview mode")
    end
    
    -- Clear backup data
    backup_sample_data = nil
    
    dialog:close()
    return nil
  else
    return key
  end
end

-- Show Chebyshev Waveshaper dialog
function show_chebyshev_waveshaper()
  local sample = renoise.song().selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_error("No valid sample selected")
    return
  end

  -- Close existing dialog if open
  if dialog and dialog.visible then
    dialog:close()
  end

  -- Create fresh ViewBuilder
  vb = renoise.ViewBuilder()

  local content = vb:column{
    margin = 10,
    spacing = 10,
    
    
    -- Polynomial selection
    vb:column{
      style = "group",
      margin = 5,
      spacing = 5,
      
      vb:text{
        text = "Polynomial Order:",
        font = "bold"
      },
      
      vb:switch{
        items = {"T2", "T3", "T4", "T5", "T6", "T7", "T8"},
        value = current_polynomial - 1,
        width = 480,
        notifier = function(value)
          current_polynomial = value + 1
          if vb.views.polynomial_description then
            vb.views.polynomial_description.text = get_polynomial_description(current_polynomial)
          end
          PakettiChebyshevUpdatePreview()
        end
      },
      
      vb:text{
        id = "polynomial_description",
        text = get_polynomial_description(current_polynomial),
        font = "italic"
      }
    },
    
    -- Visual Canvases
    vb:column{
      style = "group",
      margin = 5,
      spacing = 5,
      
      vb:text{
        text = "Visual Controls:",
        font = "bold"
      },
      
      -- Parameter Canvas
      vb:column{
        spacing = 3,
        vb:canvas{
          id = "parameter_canvas",
          width = parameter_canvas_width,
          height = parameter_canvas_height,
          mode = "plain",
          render = render_parameter_canvas,
          mouse_handler = handle_parameter_canvas_mouse,
          mouse_events = {"down", "up", "move"}
        },
        -- Labels and values below canvas
        vb:row{
          spacing = 0,
          -- Calculate column widths to match exact slider center positions
          -- Canvas width = 500, slider_width = 80
          -- slider_spacing = (500 - 240) / 4 = 65
          -- Slider centers: 105, 250, 395
          -- Column widths: 0-170 (170px), 170-330 (160px), 330-500 (170px)
          vb:column{
            width = 170,  -- Centers text around slider center at 105
            vb:text{
              text = "Drive",
              align = "center",
              font = "bold"
            },
            vb:text{
              id = "canvas_drive_value",
              text = string.format("%.2f", drive_value),
              align = "center"
            }
          },
          vb:column{
            width = 160,  -- Centers text around slider center at 250
            vb:text{
              text = "Mix", 
              align = "center",
              font = "bold"
            },
            vb:text{
              id = "canvas_mix_value",
              text = string.format("%.2f", mix_value),
              align = "center"
            }
          },
          vb:column{
            width = 170,  -- Centers text around slider center at 395
            vb:text{
              text = "Output",
              align = "center", 
              font = "bold"
            },
            vb:text{
              id = "canvas_output_value",
              text = string.format("%.2f", output_gain_value),
              align = "center"
            }
          }
        }
      },
      
      -- Waveform Canvas
      vb:column{
        spacing = 3,
        vb:text{
          text = "Waveform Display (Blue=Original, Orange=Processed)",
          font = "italic"
        },
        vb:canvas{
          id = "waveform_canvas",
          width = waveform_canvas_width,
          height = waveform_canvas_height,
          mode = "plain",
          render = render_waveform_canvas,
          mouse_handler = function(ev)
            -- Stop parameter dragging if mouse is released on waveform canvas
            if ev.type == "up" and ev.button == "left" and is_dragging_param then
              is_dragging_param = false
              drag_param_type = nil
            end
          end,
          mouse_events = {"up"}
        }
      }
    },
    
    -- Parameters
    vb:column{
      style = "group",
      margin = 5,
      width=waveform_canvas_width,
      
      vb:text{
        text = "Parameters:",
        font = "bold"
      },
      
      -- Drive
      vb:row{
        vb:text{
          text = "Drive:",
          width = 60
        },
        vb:slider{
          min = 0.1,
          max = 3.0,
          value = drive_value,
          width = 150,
          notifier = function(value)
            drive_value = value
            if vb.views.drive_value then
              vb.views.drive_value.text = string.format("%.2f", value)
            end
            PakettiChebyshevUpdatePreview()
          end
        },
        vb:text{
          id = "drive_value",
          text = string.format("%.2f", drive_value),
          width = 40
        }
      },
      
      -- Mix
      vb:row{
        vb:text{
          text = "Mix:",
          width = 60
        },
        vb:slider{
          min = 0.0,
          max = 1.0,
          value = mix_value,
          width = 150,
          notifier = function(value)
            mix_value = value
            if vb.views.mix_value then
        vb.views.mix_value.text = string.format("%.2f", mix_value)
      end
      if vb.views.canvas_mix_value then
        vb.views.canvas_mix_value.text = string.format("%.2f", mix_value)
      end
      if false then
              vb.views.mix_value.text = string.format("%.2f", value)
            end
            PakettiChebyshevUpdatePreview()
          end
        },
        vb:text{
          id = "mix_value",
          text = string.format("%.2f", mix_value),
          width = 40
        }
      },
      
      -- Output Gain
      vb:row{
        vb:text{
          text = "Output:",
          width = 60
        },
        vb:slider{
          min = 0.1,
          max = 2.0,
          value = output_gain_value,
          width = 150,
          notifier = function(value)
            output_gain_value = value
            if vb.views.output_value then
              vb.views.output_value.text = string.format("%.2f", value)
            end
            PakettiChebyshevUpdatePreview()
          end
        },
        vb:text{
          id = "output_value",
          text = string.format("%.2f", output_gain_value),
          width = 40
        }
      }
    },
    
    -- Auto-normalize checkbox
    vb:column{
      style = "group",
      margin = 5,
      spacing = 5,
      
      vb:text{
        text = "Post-Processing:",
        font = "bold"
      },
      
      vb:row{
        vb:checkbox{
          value = auto_normalize_enabled,
          notifier = function(value)
            auto_normalize_enabled = value
          end
        },
        vb:text{
          text = "Auto-normalize after applying effect"
        }
      }
    },
    
    -- Control buttons
    vb:column{
      style = "group",
      margin = 5,
      spacing = 5,
      
      vb:row{
        spacing = 10,
        
        vb:button{
          text = preview_enabled and "Disable Preview" or "Enable Preview",
          width = 120,
          id = "preview_button",
          notifier = toggle_preview
        },
        
        vb:button{
          text = "Reset",
          width = 80,
          notifier = reset_sample
        }
      },
      
      vb:row{
        spacing = 10,
        
        vb:button{
          text = "Apply",
          width = 80,
          notifier = apply_processing
        },
        
        vb:button{
          text = "Normalize",
          width = 80,
          notifier = apply_normalization
        },
        
        vb:button{
          text = "Close",
          width = 80,
          notifier = function()
            if preview_enabled then
              preview_enabled = false
              restore_sample()
            end
            backup_sample_data = nil
            dialog:close()
          end
        }
      }
    }
  }

  -- Show dialog with key handler
  dialog = renoise.app():show_custom_dialog("Paketti Chebyshev Polynomial Waveshaper", content, my_keyhandler_func)
  
  -- Initialize canvas references
  parameter_canvas = vb.views.parameter_canvas
  waveform_canvas = vb.views.waveform_canvas
  
  -- Initialize canvas displays
  update_canvas_displays()
end

-- Menu entries
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Chebyshev Polynomial Waveshaper...",
  invoke = show_chebyshev_waveshaper
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Chebyshev Polynomial Waveshaper...",
  invoke = show_chebyshev_waveshaper
}

-- Keybindings
renoise.tool():add_keybinding{
  name = "Global:Paketti:Show Chebyshev Polynomial Waveshaper",
  invoke = show_chebyshev_waveshaper
}

renoise.tool():add_keybinding{
  name = "Sample Editor:Paketti:Show Chebyshev Polynomial Waveshaper",
  invoke = show_chebyshev_waveshaper
} 