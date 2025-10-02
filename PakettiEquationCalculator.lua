--[[
Paketti Volume Delay Pan Equation Calculator
Allows users to input mathematical equations and visualize them as waveforms,
then apply them to volume, delay, or panning columns in the pattern editor.
Uses canvas.lua for waveform visualization.
--]]

local vb = renoise.ViewBuilder()
local dialog = nil
local equation_canvas = nil

-- Equation evaluation state
local current_equation = "sin(t)"
local current_mode = "volume"  -- "volume", "delay", "panning"
local equation_error = nil
local waveform_data = {}
local canvas_width = 400
local canvas_height = 200

-- Mathematical function library for equation evaluation
local math_functions = {
  sin = math.sin,
  cos = math.cos,
  tan = math.tan,
  asin = math.asin,
  acos = math.acos,
  atan = math.atan,
  sinh = math.sinh,
  cosh = math.cosh,
  tanh = math.tanh,
  exp = math.exp,
  log = math.log,
  log10 = function(x) return math.log(x) / math.log(10) end,
  sqrt = math.sqrt,
  abs = math.abs,
  floor = math.floor,
  ceil = math.ceil,
  round = function(x) return math.floor(x + 0.5) end,
  min = math.min,
  max = math.max,
  pi = math.pi,
  e = math.exp(1),
  -- Additional useful functions
  sign = function(x) return x > 0 and 1 or (x < 0 and -1 or 0) end,
  clamp = function(x, min_val, max_val) return math.min(max_val, math.max(min_val, x)) end,
  lerp = function(a, b, t) return a + (b - a) * t end,
  -- Wave functions
  saw = function(x) return 2 * (x - math.floor(x + 0.5)) end,
  square = function(x) return math.sin(x) > 0 and 1 or -1 end,
  triangle = function(x) 
    local saw_val = 2 * (x - math.floor(x + 0.5))
    return 2 * math.abs(saw_val) - 1 
  end,
  noise = function(x) return math.sin(x * 12.9898) * 43758.5453 % 1 * 2 - 1 end
}

-- Safe equation evaluator that catches errors
function PakettiEquationCalculatorEvaluate(equation, t_value)
  if not equation or equation == "" then
    return nil, "Empty equation"
  end
  
  -- Replace 't' with the actual value, handling various formats
  local safe_equation = string.gsub(equation, "t", tostring(t_value))
  
  -- Create a safe environment with only math functions
  local safe_env = {}
  for name, func in pairs(math_functions) do
    safe_env[name] = func
  end
  
  -- Add basic arithmetic operators as functions (for complex expressions)
  safe_env["+"] = function(a, b) return a + b end
  safe_env["-"] = function(a, b) return a - b end
  safe_env["*"] = function(a, b) return a * b end
  safe_env["/"] = function(a, b) 
    if b == 0 then return 0 end -- Handle division by zero
    return a / b 
  end
  safe_env["^"] = function(a, b) 
    local result = a ^ b
    if result ~= result then return 0 end -- Handle NaN results
    return result
  end
  
  -- Try to evaluate the equation
  local success, result = pcall(function()
    -- First try direct evaluation
    local func = loadstring("return " .. safe_equation)
    if func then
      setfenv(func, safe_env)
      local value = func()
      if type(value) == "number" then
        -- Check for NaN, infinity, or other invalid values
        if value ~= value or value == math.huge or value == -math.huge then
          return 0 -- Return 0 for invalid values instead of erroring
        end
        return value
      else
        return 0 -- Return 0 for non-numeric results
      end
    else
      error("Invalid equation syntax")
    end
  end)
  
  if success then
    return result
  else
    return 0, result -- Return 0 instead of nil for errors
  end
end

-- Generate waveform data from equation
function PakettiEquationCalculatorGenerateWaveform()
  waveform_data = {}
  equation_error = nil
  
  local num_points = canvas_width
  local t_min = 0
  local t_max = 4 * math.pi  -- Show 2 full cycles by default
  
  local min_value = math.huge
  local max_value = -math.huge
  local valid_values = {}
  
  -- First pass: collect all valid values and find range
  for i = 1, num_points do
    local t = t_min + (i - 1) / (num_points - 1) * (t_max - t_min)
    local value, err = PakettiEquationCalculatorEvaluate(current_equation, t)
    
    if value and type(value) == "number" and value == value then -- Check for NaN
      valid_values[i] = value
      min_value = math.min(min_value, value)
      max_value = math.max(max_value, value)
    else
      equation_error = err or "Invalid result at t=" .. t
      return
    end
  end
  
  -- Second pass: normalize values to 0-1 range
  local range = max_value - min_value
  if range == 0 then
    -- All values are the same, center them
    for i = 1, num_points do
      waveform_data[i] = 0.5
    end
  else
    for i = 1, num_points do
      local normalized_value = (valid_values[i] - min_value) / range
      waveform_data[i] = math.max(0, math.min(1, normalized_value))
    end
  end
end

-- Canvas rendering function
function PakettiEquationCalculatorRenderCanvas(ctx)
  local w, h = canvas_width, canvas_height
  ctx:clear_rect(0, 0, w, h)
  
  -- Draw background
  ctx.fill_color = {32, 32, 32, 255}  -- Dark gray background
  ctx:fill_rect(0, 0, w, h)
  
  -- Draw grid
  ctx.stroke_color = {64, 64, 64, 255}  -- Gray grid lines
  ctx.line_width = 1
  
  -- Vertical grid lines
  for i = 0, 10 do
    local x = i * w / 10
    ctx:begin_path()
    ctx:move_to(x, 0)
    ctx:line_to(x, h)
    ctx:stroke()
  end
  
  -- Horizontal grid lines
  for i = 0, 8 do
    local y = i * h / 8
    ctx:begin_path()
    ctx:move_to(0, y)
    ctx:line_to(w, y)
    ctx:stroke()
  end
  
  -- Draw center line
  ctx.stroke_color = {128, 128, 128, 255}
  ctx.line_width = 2
  ctx:begin_path()
  ctx:move_to(0, h / 2)
  ctx:line_to(w, h / 2)
  ctx:stroke()
  
  if equation_error then
    -- Draw error message
    ctx.fill_color = {255, 100, 100, 255}  -- Red text
    -- Note: Canvas doesn't support text, so we'll show error in status
    return
  end
  
  if #waveform_data > 0 then
    -- Draw waveform
    ctx.stroke_color = {100, 255, 100, 255}  -- Green waveform
    ctx.line_width = 2
    ctx:begin_path()
    
    for i = 1, #waveform_data do
      local x = (i - 1) * w / (#waveform_data - 1)
      local y = h - (waveform_data[i] * h)
      
      if i == 1 then
        ctx:move_to(x, y)
      else
        ctx:line_to(x, y)
      end
    end
    
    ctx:stroke()
    
    -- Draw sample points
    ctx.fill_color = {255, 255, 100, 255}  -- Yellow points
    for i = 1, #waveform_data do
      local x = (i - 1) * w / (#waveform_data - 1)
      local y = h - (waveform_data[i] * h)
      ctx:fill_rect(x - 1, y - 1, 3, 3)
    end
  end
end

-- Apply waveform to pattern
function PakettiEquationCalculatorApplyWaveform()
  local song = renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local track = song.tracks[track_index]
  
  -- Make appropriate column visible
  if current_mode == "volume" then
    track.volume_column_visible = true
  elseif current_mode == "panning" then
    track.panning_column_visible = true
  elseif current_mode == "delay" then
    track.delay_column_visible = true
  end
  
  local pattern = song:pattern(pattern_index)
  local track_data = pattern:track(track_index)
  local pattern_lines = pattern.number_of_lines
  
  -- Find all notes in the pattern
  local notes = {}
  for line_index = 1, pattern_lines do
    local line = track_data:line(line_index)
    local has_note = false
    for note_column_index = 1, track.visible_note_columns do
      if line:note_column(note_column_index).note_value ~= 121 then -- 121 is empty note
        has_note = true
        break
      end
    end
    if has_note then
      table.insert(notes, line_index)
    end
  end
  
  if #notes == 0 then
    renoise.app():show_status("No notes found in pattern to apply equation to")
    return
  end
  
  -- Apply equation values to notes
  for i = 1, #notes do
    local t = (i - 1) / math.max(1, #notes - 1) * (4 * math.pi)  -- Map to 0 to 4π
    local value, err = PakettiEquationCalculatorEvaluate(current_equation, t)
    
    if value then
      -- Convert to appropriate range based on mode
      local final_value
      if current_mode == "delay" then
        -- Delay: 0-255
        final_value = math.floor((value + 1) / 2 * 255)
        final_value = math.max(0, math.min(255, final_value))
      else
        -- Volume/Panning: 0-128
        final_value = math.floor((value + 1) / 2 * 128)
        final_value = math.max(0, math.min(128, final_value))
      end
      
      local line = track_data:line(notes[i])
      for note_column_index = 1, track.visible_note_columns do
        if line:note_column(note_column_index).note_value ~= 121 then
          if current_mode == "volume" then
            line:note_column(note_column_index).volume_value = final_value
          elseif current_mode == "panning" then
            line:note_column(note_column_index).panning_value = final_value
          elseif current_mode == "delay" then
            line:note_column(note_column_index).delay_value = final_value
          end
        end
      end
    else
      renoise.app():show_status("Error evaluating equation: " .. tostring(err))
      return
    end
  end
  
  renoise.app():show_status("Applied equation to " .. #notes .. " notes in " .. current_mode .. " column")
end

-- Update equation and regenerate waveform
function PakettiEquationCalculatorUpdateEquation()
  PakettiEquationCalculatorGenerateWaveform()
  if equation_canvas then
    equation_canvas:update()
  end
  
  if equation_error then
    renoise.app():show_status("Equation error: " .. tostring(equation_error))
  else
    -- Show debug info for the first few values
    local debug_info = ""
    if #waveform_data > 0 then
      local min_val = math.huge
      local max_val = -math.huge
      for i = 1, math.min(5, #waveform_data) do
        min_val = math.min(min_val, waveform_data[i])
        max_val = math.max(max_val, waveform_data[i])
      end
      debug_info = string.format("Range: %.3f to %.3f", min_val, max_val)
    end
    renoise.app():show_status("Equation: " .. current_equation .. " | " .. debug_info)
  end
end

-- Main dialog function
function PakettiEquationCalculator()
  if dialog and dialog.visible then
    dialog:close()
    return
  end
  
  -- Generate initial waveform
  PakettiEquationCalculatorGenerateWaveform()
  
  dialog = renoise.app():show_custom_dialog("Paketti Volume Delay Pan Equation Calculator",
    vb:column{
      width = 500,
      vb:row{
        width = 500,
        vb:switch {
          width = 500,
          items = {"Volume", "Panning", "Delay"},
          value = 1,
          notifier = function(idx)
            current_mode = idx == 1 and "volume" or idx == 2 and "panning" or "delay"
          end
        }
      },
      vb:row{
        width = 500,
        vb:text{text = "Equation:", width = 80, style = "strong"},
        vb:textfield{
          id = "equation_field",
          width = 350,
          value = current_equation,
          notifier = function(value)
            current_equation = value
            PakettiEquationCalculatorUpdateEquation()
          end
        },
        vb:button{
          width = 60,
          text = "Update",
          notifier = function()
            PakettiEquationCalculatorUpdateEquation()
          end
        }
      },
      vb:row{
        width = 500,
        vb:canvas{
          id = "equation_canvas",
          width = canvas_width,
          height = canvas_height,
          render = PakettiEquationCalculatorRenderCanvas,
          mouse_events = {"down", "up", "move"},
          mouse_handler = function(ev)
            -- Handle mouse events if needed for interaction
          end
        }
      },
      vb:row{
        width = 500,
        vb:text{
          text = "Examples:",
          style = "strong",
          width = 80
        },
        vb:button{
          width = 70,
          text = "sin(t)",
          notifier = function()
            current_equation = "sin(t)"
            vb.views.equation_field.value = current_equation
            PakettiEquationCalculatorUpdateEquation()
          end
        },
        vb:button{
          width = 70,
          text = "cos(t)",
          notifier = function()
            current_equation = "cos(t)"
            vb.views.equation_field.value = current_equation
            PakettiEquationCalculatorUpdateEquation()
          end
        },
        vb:button{
          width = 70,
          text = "-cos(t)",
          notifier = function()
            current_equation = "-cos(t)"
            vb.views.equation_field.value = current_equation
            PakettiEquationCalculatorUpdateEquation()
          end
        },
        vb:button{
          width = 70,
          text = "cos(t)*t",
          notifier = function()
            current_equation = "cos(t)*t"
            vb.views.equation_field.value = current_equation
            PakettiEquationCalculatorUpdateEquation()
          end
        }
      },
      vb:row{
        width = 500,
        vb:button{
          width = 70,
          text = "sin(t)*cos(t)",
          notifier = function()
            current_equation = "sin(t)*cos(t)"
            vb.views.equation_field.value = current_equation
            PakettiEquationCalculatorUpdateEquation()
          end
        },
        vb:button{
          width = 70,
          text = "sin(t^2)",
          notifier = function()
            current_equation = "sin(t^2)"
            vb.views.equation_field.value = current_equation
            PakettiEquationCalculatorUpdateEquation()
          end
        },
        vb:button{
          width = 70,
          text = "sin(t)*t",
          notifier = function()
            current_equation = "sin(t)*t"
            vb.views.equation_field.value = current_equation
            PakettiEquationCalculatorUpdateEquation()
          end
        },
        vb:button{
          width = 70,
          text = "saw(t)",
          notifier = function()
            current_equation = "saw(t)"
            vb.views.equation_field.value = current_equation
            PakettiEquationCalculatorUpdateEquation()
          end
        },
        vb:button{
          width = 70,
          text = "square(t)",
          notifier = function()
            current_equation = "square(t)"
            vb.views.equation_field.value = current_equation
            PakettiEquationCalculatorUpdateEquation()
          end
        }
      },
      vb:row{
        width = 500,
        vb:button{
          width = 70,
          text = "triangle(t)",
          notifier = function()
            current_equation = "triangle(t)"
            vb.views.equation_field.value = current_equation
            PakettiEquationCalculatorUpdateEquation()
          end
        },
        vb:button{
          width = 70,
          text = "noise(t)",
          notifier = function()
            current_equation = "noise(t)"
            vb.views.equation_field.value = current_equation
            PakettiEquationCalculatorUpdateEquation()
          end
        },
        vb:button{
          width = 70,
          text = "sin(t)*cos(t^2)",
          notifier = function()
            current_equation = "sin(t)*cos(t^2)"
            vb.views.equation_field.value = current_equation
            PakettiEquationCalculatorUpdateEquation()
          end
        },
        vb:button{
          width = 70,
          text = "tan(t)",
          notifier = function()
            current_equation = "tan(t)"
            vb.views.equation_field.value = current_equation
            PakettiEquationCalculatorUpdateEquation()
          end
        },
        vb:button{
          width = 70,
          text = "sqrt(t)",
          notifier = function()
            current_equation = "sqrt(t)"
            vb.views.equation_field.value = current_equation
            PakettiEquationCalculatorUpdateEquation()
          end
        }
      },
      vb:row{
        width = 500,
        vb:button{
          width = 200,
          text = "Apply to Pattern",
          notifier = function()
            PakettiEquationCalculatorApplyWaveform()
          end
        },
        vb:button{
          width = 100,
          text = "Close",
          notifier = function()
            dialog:close()
          end
        }
      }
    }
  )
  
  -- Store canvas reference for updates - get it from the dialog's view builder
  equation_canvas = vb.views.equation_canvas
  
  -- Set active frame
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

renoise.tool():add_keybinding{name = "Pattern Editor:Paketti:Volume Delay Pan Equation Calculator...",invoke = PakettiEquationCalculator}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti Gadgets:Volume Delay Pan Equation Calculator...",invoke = PakettiEquationCalculator}
