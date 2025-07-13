-- PakettiCanvasExperiments.lua
-- Canvas-based Device Parameter Editor
-- Allows visual editing of device parameters through a canvas interface

local vb = renoise.ViewBuilder()
local canvas_width = 1024
local canvas_height = 400
local canvas_experiments_dialog = nil
local canvas_experiments_canvas = nil
local current_device = nil
local device_parameters = {}
local parameter_width = 0
local mouse_is_down = false

-- Initialize the canvas experiments
function PakettiCanvasExperimentsInit()
  local song = renoise.song()
  
  -- Check if we have a selected device
  local selected_device = song.selected_device
  if not selected_device then
    renoise.app():show_status("No device selected. Please select a device in the mixer or track DSP chain.")
    return
  end
  
  current_device = selected_device
  device_parameters = {}
  
  -- Get all automatable parameters from the device
  for i = 1, #current_device.parameters do
    local param = current_device.parameters[i]
    if param.is_automatable then
      table.insert(device_parameters, {
        parameter = param,
        name = param.name,
        value = param.value,
        value_min = param.value_min,
        value_max = param.value_max,
        value_default = param.value_default,
        index = i
      })
    end
  end
  
  if #device_parameters == 0 then
    renoise.app():show_status("Selected device has no automatable parameters.")
    return
  end
  
  -- Calculate parameter width based on canvas width
  parameter_width = canvas_width / #device_parameters
  
  -- Create the dialog
  PakettiCanvasExperimentsCreateDialog()
end

-- Handle mouse input
function PakettiCanvasExperimentsHandleMouse(ev)
  local w = canvas_width
  local h = canvas_height
  
  -- Handle mouse leave event
  if ev.type == "exit" then
    if mouse_is_down then
      mouse_is_down = false
    end
    return
  end
  
  -- Check if mouse is within canvas bounds
  local mouse_in_bounds = ev.position.x >= 0 and ev.position.x < w and 
                         ev.position.y >= 0 and ev.position.y < h
  
  if not mouse_in_bounds then
    return
  end
  
  local x = ev.position.x
  local y = ev.position.y
  
  if ev.type == "down" then
    mouse_is_down = true
    PakettiCanvasExperimentsHandleMouseInput(x, y)
  elseif ev.type == "up" then
    mouse_is_down = false
  elseif ev.type == "move" and mouse_is_down then
    PakettiCanvasExperimentsHandleMouseInput(x, y)
  end
end

-- Handle mouse input for parameter editing
function PakettiCanvasExperimentsHandleMouseInput(x, y)
  if not current_device or #device_parameters == 0 then
    return
  end
  
  -- Calculate normalized Y position (0 = max, 1 = min)
  local normalized_y = 1.0 - (y / canvas_height)
  normalized_y = math.max(0, math.min(1, normalized_y))
  
  -- Apply the normalized value to all parameters
  for i, param_info in ipairs(device_parameters) do
    local new_value = param_info.value_min + (normalized_y * (param_info.value_max - param_info.value_min))
    param_info.parameter.value = new_value
  end
  
  -- Update canvas
  if canvas_experiments_canvas then
    canvas_experiments_canvas:update()
  end
end

-- Draw the canvas
function PakettiCanvasExperimentsDrawCanvas(ctx)
  -- Clear canvas with dark background
  ctx.fill_color = {0.1, 0.1, 0.1, 1.0}
  ctx:fill_rect(0, 0, canvas_width, canvas_height)
  
  -- Draw grid lines
  ctx.stroke_color = {0.2, 0.2, 0.2, 1.0}
  ctx.line_width = 1
  
  -- Vertical grid lines (parameter separators)
  for i = 1, #device_parameters do
    local x = (i - 1) * parameter_width
    ctx:begin_path()
    ctx:move_to(x, 0)
    ctx:line_to(x, canvas_height)
    ctx:stroke()
  end
  
  -- Horizontal grid lines
  for i = 1, 5 do
    local y = (i - 1) * (canvas_height / 4)
    ctx:begin_path()
    ctx:move_to(0, y)
    ctx:line_to(canvas_width, y)
    ctx:stroke()
  end
  
  -- Draw parameter values as vertical lines
  for i, param_info in ipairs(device_parameters) do
    local x = (i - 1) * parameter_width + (parameter_width / 2)
    local normalized_value = (param_info.parameter.value - param_info.value_min) / (param_info.value_max - param_info.value_min)
    local y = canvas_height - (normalized_value * canvas_height)
    
    -- Draw parameter line
    ctx.stroke_color = {0.7, 0.4, 0.2, 1.0}
    ctx.line_width = 3
    ctx:begin_path()
    ctx:move_to(x, canvas_height)
    ctx:line_to(x, y)
    ctx:stroke()
    
    -- Draw parameter value dot
    ctx.fill_color = {1.0, 0.6, 0.3, 1.0}
    ctx:begin_path()
    ctx:arc(x, y, 4, 0, 2 * math.pi, false)
    ctx:fill()
  end
  
  -- Draw title
  ctx.fill_color = {1.0, 1.0, 1.0, 1.0}
  ctx:fill_rect(8, 8, 500, 16)
  ctx.fill_color = {0.0, 0.0, 0.0, 1.0}
  ctx:fill_rect(10, 10, 496, 12)
  ctx.fill_color = {1.0, 1.0, 1.0, 1.0}
  -- Note: Text drawing is not supported in canvas, so we'll skip parameter names for now
end

-- Create the main dialog
function PakettiCanvasExperimentsCreateDialog()
  if canvas_experiments_dialog and canvas_experiments_dialog.visible then
    canvas_experiments_dialog:close()
  end
  
  local device_name = current_device.display_name or "Unknown Device"
  local title = "Canvas Device Parameter Editor - " .. device_name .. " (" .. #device_parameters .. " parameters)"
  
  -- Create fresh ViewBuilder instance
  local vb = renoise.ViewBuilder()
  
  local dialog_content = vb:column {
    margin = 10,
    spacing = 10,
    
    -- Header
    vb:text {
      text = title,
      font = "bold"
    },
    
    -- Parameter info
    vb:text {
      text = "Draw on the canvas to modify all parameters simultaneously. Each vertical line represents one parameter.",
      font = "italic"
    },
    
    -- Canvas
    vb:canvas {
      id = "canvas_experiments_canvas",
      width = canvas_width,
      height = canvas_height,
      mode = "plain",
      render = PakettiCanvasExperimentsDrawCanvas,
      mouse_handler = PakettiCanvasExperimentsHandleMouse,
      mouse_events = {"down", "up", "move", "exit"}
    },
    
    -- Control buttons
    vb:row {
      spacing = 10,
      vb:button {
        text = "Reset All to Default",
        width = 150,
        notifier = function()
          PakettiCanvasExperimentsResetToDefault()
        end
      },
      vb:button {
        text = "Refresh Device",
        width = 120,
        notifier = function()
          PakettiCanvasExperimentsRefreshDevice()
        end
      },
      vb:button {
        text = "Close",
        width = 80,
        notifier = function()
          canvas_experiments_dialog:close()
        end
      }
    }
  }
  
  canvas_experiments_dialog = renoise.app():show_custom_dialog(
    title,
    dialog_content,
    my_keyhandler_func
  )
  
  canvas_experiments_canvas = vb.views.canvas_experiments_canvas
end

-- Reset all parameters to default
function PakettiCanvasExperimentsResetToDefault()
  if not current_device or #device_parameters == 0 then
    return
  end
  
  for i, param_info in ipairs(device_parameters) do
    param_info.parameter.value = param_info.value_default
  end
  
  -- Update canvas
  if canvas_experiments_canvas then
    canvas_experiments_canvas:update()
  end
  
  renoise.app():show_status("Reset all parameters to default values")
end

-- Refresh device parameters
function PakettiCanvasExperimentsRefreshDevice()
  PakettiCanvasExperimentsInit()
end

-- Menu entries
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti..:Experiments:Canvas Device Parameter Editor",
  invoke = PakettiCanvasExperimentsInit
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:Canvas Device Parameter Editor",
  invoke = PakettiCanvasExperimentsInit
}

print("PakettiCanvasExperiments.lua loaded successfully") 