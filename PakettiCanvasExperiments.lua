-- PakettiCanvasExperiments.lua
-- Canvas-based Device Parameter Editor
-- Allows visual editing of device parameters through a canvas interface

local vb = renoise.ViewBuilder()
local canvas_width = 1280  -- Increased from 1024
local canvas_height = 500  -- Increased from 400
local content_margin = 50  -- Margin around the content area
local content_width = canvas_width - (content_margin * 2)  -- 80% of canvas width
local content_height = canvas_height - (content_margin * 2)  -- 80% of canvas height
local content_x = content_margin
local content_y = content_margin
local canvas_experiments_dialog = nil
local canvas_experiments_canvas = nil
local current_device = nil
local device_parameters = {}
local parameter_width = 0
local mouse_is_down = false
-- Add variables for drawing feedback
local last_mouse_x = -1
local last_mouse_y = -1
-- Device selection observer
local device_selection_notifier = nil
-- Dynamic status text view
local status_text_view = nil
-- Current drawing parameter info
local current_drawing_parameter = nil
-- Track information for current device
local current_track_index = nil
local current_track_name = nil
-- Remember previous device index for smart restoration
local previous_device_index = nil
-- Randomization strength slider
local randomize_strength = 50  -- Default 50%
local randomize_slider_view = nil

-- Custom text rendering system for canvas
local function draw_letter_A(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x + size/2, y)
  ctx:line_to(x + size, y + size)
  ctx:move_to(x + size/4, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:stroke()
end

local function draw_letter_B(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + 3*size/4, y + size)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:line_to(x + 3*size/4, y)
  ctx:line_to(x, y)
  ctx:stroke()
end

local function draw_letter_C(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

local function draw_letter_D(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + 3*size/4, y + size)
  ctx:line_to(x + size, y + 3*size/4)
  ctx:line_to(x + size, y + size/4)
  ctx:line_to(x + 3*size/4, y)
  ctx:line_to(x, y)
  ctx:stroke()
end

local function draw_letter_E(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:stroke()
end

local function draw_letter_F(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x, y)
  ctx:line_to(x + size, y)
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:stroke()
end

local function draw_letter_G(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x + size/2, y + size/2)
  ctx:stroke()
end

local function draw_letter_H(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size)
  ctx:move_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:stroke()
end

local function draw_letter_I(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + size)
  ctx:move_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

local function draw_letter_L(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

local function draw_letter_M(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x, y)
  ctx:line_to(x + size/2, y + size/2)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

local function draw_letter_N(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x, y)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x + size, y)
  ctx:stroke()
end

local function draw_letter_O(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:line_to(x, y)
  ctx:stroke()
end

local function draw_letter_P(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:stroke()
end

local function draw_letter_R(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

local function draw_letter_S(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y + size/4)
  ctx:line_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:line_to(x, y + 3*size/4)
  ctx:stroke()
end

local function draw_letter_T(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + size)
  ctx:stroke()
end

local function draw_letter_U(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x + size, y)
  ctx:stroke()
end

local function draw_letter_V(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size/2, y + size)
  ctx:line_to(x + size, y)
  ctx:stroke()
end

local function draw_letter_W(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size/4, y + size)
  ctx:line_to(x + size/2, y + size/2)
  ctx:line_to(x + 3*size/4, y + size)
  ctx:line_to(x + size, y)
  ctx:stroke()
end

local function draw_letter_X(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y + size)
  ctx:move_to(x + size, y)
  ctx:line_to(x, y + size)
  ctx:stroke()
end

local function draw_letter_Y(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size/2, y + size/2)
  ctx:line_to(x + size, y)
  ctx:move_to(x + size/2, y + size/2)
  ctx:line_to(x + size/2, y + size)
  ctx:stroke()
end

local function draw_digit_0(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:line_to(x, y)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

local function draw_digit_1(ctx, x, y, size)
  ctx:begin_path()
  -- Main vertical line
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + size)
  -- Small angled line at top left (serif)
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/4, y + size/4)
  ctx:stroke()
end

local function draw_digit_2(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

local function draw_digit_3(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:move_to(x + size, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:stroke()
end

local function draw_digit_4(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:move_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

local function draw_digit_5(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:stroke()
end

local function draw_digit_6(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:stroke()
end

local function draw_digit_7(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size/2, y + size)
  ctx:stroke()
end

local function draw_digit_8(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:line_to(x, y)
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:stroke()
end

local function draw_digit_9(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y + size)
  ctx:line_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:stroke()
end

local function draw_letter_J(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + size)
  ctx:line_to(x, y + size)
  ctx:stroke()
end

local function draw_letter_K(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size)
  ctx:move_to(x + size, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

local function draw_letter_Q(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:line_to(x, y)
  ctx:move_to(x + size/2, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

local function draw_letter_Z(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

local function draw_space(ctx, x, y, size)
  -- Space character - do nothing
end

local function draw_dot(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/2, y + size)
  ctx:line_to(x + size/2, y + size - 2)
  ctx:stroke()
end

local function draw_dash(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:stroke()
end

-- Letter lookup table
local letter_functions = {
  A = draw_letter_A, B = draw_letter_B, C = draw_letter_C, D = draw_letter_D,
  E = draw_letter_E, F = draw_letter_F, G = draw_letter_G, H = draw_letter_H,
  I = draw_letter_I, J = draw_letter_J, K = draw_letter_K, L = draw_letter_L, 
  M = draw_letter_M, N = draw_letter_N, O = draw_letter_O, P = draw_letter_P, 
  Q = draw_letter_Q, R = draw_letter_R, S = draw_letter_S, T = draw_letter_T, 
  U = draw_letter_U, V = draw_letter_V, W = draw_letter_W, X = draw_letter_X, 
  Y = draw_letter_Y, Z = draw_letter_Z,
  ["0"] = draw_digit_0, ["1"] = draw_digit_1, ["2"] = draw_digit_2, ["3"] = draw_digit_3,
  ["4"] = draw_digit_4, ["5"] = draw_digit_5, ["6"] = draw_digit_6, ["7"] = draw_digit_7,
  ["8"] = draw_digit_8, ["9"] = draw_digit_9,
  [" "] = draw_space, ["."] = draw_dot, ["-"] = draw_dash
}

-- Function to draw text on canvas
local function draw_canvas_text(ctx, text, x, y, size)
  local current_x = x
  local letter_spacing = size * 1.2
  
  for i = 1, #text do
    local char = text:sub(i, i):upper()
    local letter_func = letter_functions[char]
    if letter_func then
      letter_func(ctx, current_x, y, size)
    end
    current_x = current_x + letter_spacing
  end
end

-- Generate dynamic status text
function PakettiCanvasExperimentsGetStatusText()
  -- Always show base device info
  if not current_device then
    return "No device selected"
  end
  
  local song = renoise.song()
  local device_name = current_device.display_name or "Unknown Device"
  local param_count = #device_parameters
  
  -- Use selected track info directly - much simpler!
  local track_number = tostring(song.selected_track_index)
  local track_name = song.selected_track.name
  
  local base_text = string.format("Track %s / %s [%s] / %d parameters", 
    track_number, track_name, device_name, param_count)
  
  -- If we have a current parameter (drawing or just selected), append parameter details
  if current_drawing_parameter then
    local param_info = current_drawing_parameter
    local param_text = string.format(" - Parameter %d: %s = %.3f", 
      param_info.index, param_info.name, param_info.parameter.value)
    return base_text .. param_text
  end
  
  return base_text
end

-- Refresh device parameters when device selection changes
function PakettiCanvasExperimentsRefreshDevice()
  local song = renoise.song()
  
  print("=== Device Selection Changed ===")
  
  -- Remember the current device index before it potentially gets lost
  if song.selected_device_index then
    previous_device_index = song.selected_device_index
    print("DEBUG: Remembering previous device index: " .. previous_device_index)
  end
  
  -- Clear current drawing state when device changes
  current_drawing_parameter = nil
  mouse_is_down = false
  last_mouse_x = -1
  last_mouse_y = -1
  
  -- Check if we have a selected device
  local selected_device = song.selected_device
  if not selected_device then
    print("DEBUG: No device selected - trying to restore previous device position")
    
         -- Try to restore to previous device position if we remember it
     local found_device = nil
     if previous_device_index then
       local current_track = song.selected_track
       if current_track and #current_track.devices > 0 then
         -- Smart device selection: try to stay close to where we were
         local target_device_index
         if previous_device_index <= #current_track.devices then
           -- Previous index still exists, use it
           target_device_index = previous_device_index
         else
           -- Previous index is too high, go to the last available device (not device 1!)
           target_device_index = #current_track.devices
         end
         
         print("DEBUG: Smart restore - was on device " .. previous_device_index .. ", now going to device " .. target_device_index .. " (available: " .. #current_track.devices .. ")")
         
         song.selected_device_index = target_device_index
         found_device = song.selected_device
         selected_device = found_device
         
         if found_device then
           print("DEBUG: Successfully restored to device: " .. (found_device.display_name or "Unknown") .. " at index " .. target_device_index)
         end
       end
     end
    
    -- If restoration failed, search for any available device
    if not found_device then
      print("DEBUG: Device restoration failed - searching for available devices")
      for track_index = 1, #song.tracks do
        local track = song.tracks[track_index]
        if #track.devices > 0 then
          -- Set the selected track first
          song.selected_track_index = track_index
          -- Then set the device index within that track
          song.selected_device_index = 1
          -- Get the device reference after setting the selection
          found_device = song.selected_device
          selected_device = found_device
          print("DEBUG: Auto-selected device: " .. (found_device.display_name or "Unknown") .. " on track " .. track_index)
          break
        end
      end
    end
    
    -- If no devices found at all, then show "no device selected"
    if not found_device then
      print("DEBUG: No devices found in entire song")
      current_device = nil
      device_parameters = {}
      parameter_width = 0
      
      -- Update status text
      if status_text_view then
        status_text_view.text = "No device selected"
      end
      
      if canvas_experiments_canvas then
        canvas_experiments_canvas:update()
      end
      return
    end
  end
  
  print("DEBUG: New selected device:")
  print("  Device name: " .. (selected_device.display_name or "Unknown"))
  print("  Total parameters: " .. #selected_device.parameters)
  
  current_device = selected_device
  device_parameters = {}
  
  -- Get all automatable parameters from the device
  for i = 1, #current_device.parameters do
    local param = current_device.parameters[i]
    print("  Parameter " .. i .. ": " .. param.name .. " (automatable: " .. tostring(param.is_automatable) .. ")")
    
    if param.is_automatable then
      print("    Value: " .. param.value .. " (min: " .. param.value_min .. ", max: " .. param.value_max .. ", default: " .. param.value_default .. ")")
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
  
  print("DEBUG: Found " .. #device_parameters .. " automatable parameters")
  
  if #device_parameters == 0 then
    print("DEBUG: No automatable parameters found")
    parameter_width = 0
  else
    -- Calculate parameter width based on content width
    parameter_width = content_width / #device_parameters
    print("DEBUG: Parameter width: " .. parameter_width .. " pixels each")
  end
  
  -- Update status text
  if status_text_view then
    status_text_view.text = PakettiCanvasExperimentsGetStatusText()
    print("DEBUG: Status text updated")
  end
  
  -- Update canvas if it exists
  if canvas_experiments_canvas then
    canvas_experiments_canvas:update()
    print("DEBUG: Canvas updated with new device parameters")
  end
  
  -- Show status message
  renoise.app():show_status(PakettiCanvasExperimentsGetStatusText())
end

-- Initialize the canvas experiments
function PakettiCanvasExperimentsInit()
  -- If dialog is already open, close it and cleanup (toggle behavior)
  if canvas_experiments_dialog and canvas_experiments_dialog.visible then
    print("DEBUG: Dialog already open - closing and cleaning up")
    PakettiCanvasExperimentsCleanup()
    canvas_experiments_dialog:close()
    return
  end
  
  local song = renoise.song()
  
  print("=== Paketti Canvas Experiments Debug ===")
  
  -- Check if we have a selected device
  local selected_device = song.selected_device
  if not selected_device then
    print("DEBUG: No device selected - searching for available devices")
    
         -- Find any available device in the song
     local found_device = nil
     for track_index = 1, #song.tracks do
       local track = song.tracks[track_index]
       if #track.devices > 0 then
         -- Set the selected track first
         song.selected_track_index = track_index
         -- Then set the device index within that track
         song.selected_device_index = 1
         -- Get the device reference after setting the selection
         found_device = song.selected_device
         selected_device = found_device
         print("DEBUG: Auto-selected device: " .. (found_device.display_name or "Unknown") .. " on track " .. track_index)
         break
       end
     end
    
    if not found_device then
      print("DEBUG: No devices found in entire song")
      renoise.app():show_status("No devices found in song. Please add a device to a track.")
      return
    end
  end
  
  print("DEBUG: Selected device found:")
  print("  Device name: " .. (selected_device.display_name or "Unknown"))
  print("  Total parameters: " .. #selected_device.parameters)
  
  current_device = selected_device
  device_parameters = {}
  
  -- Get all automatable parameters from the device
  for i = 1, #current_device.parameters do
    local param = current_device.parameters[i]
    print("  Parameter " .. i .. ": " .. param.name .. " (automatable: " .. tostring(param.is_automatable) .. ")")
    
    if param.is_automatable then
      print("    Value: " .. param.value .. " (min: " .. param.value_min .. ", max: " .. param.value_max .. ", default: " .. param.value_default .. ")")
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
  
  print("DEBUG: Found " .. #device_parameters .. " automatable parameters")
  
  if #device_parameters == 0 then
    print("DEBUG: No automatable parameters found")
    renoise.app():show_status("Selected device has no automatable parameters.")
    return
  end
  
  -- Calculate parameter width based on content width
  parameter_width = content_width / #device_parameters
  print("DEBUG: Parameter width: " .. parameter_width .. " pixels each")
  
  -- Create the dialog
  PakettiCanvasExperimentsCreateDialog()
  
  -- Set up device selection observer
  if device_selection_notifier then
    song.selected_device_observable:remove_notifier(device_selection_notifier)
  end
  
  device_selection_notifier = function()
    print("DEBUG: Device selection changed - refreshing")
    PakettiCanvasExperimentsRefreshDevice()
  end
  
  song.selected_device_observable:add_notifier(device_selection_notifier)
  print("DEBUG: Device selection observer added")
end

-- Handle mouse input
function PakettiCanvasExperimentsHandleMouse(ev)
  print("DEBUG: Mouse event - type: " .. ev.type .. ", position: " .. ev.position.x .. ", " .. ev.position.y)
  
  local w = canvas_width
  local h = canvas_height
  
  -- Handle mouse leave event - but don't stop dragging!
  if ev.type == "exit" then
    print("DEBUG: Mouse exit event - keeping mouse_is_down state")
    -- Don't reset mouse_is_down here - let user come back and continue dragging
    return
  end
  
  -- Check if mouse is within canvas bounds
  local mouse_in_canvas = ev.position.x >= 0 and ev.position.x < w and 
                         ev.position.y >= 0 and ev.position.y < h
  
  -- Check if mouse is within content area bounds
  local mouse_in_content = ev.position.x >= content_x and ev.position.x < (content_x + content_width) and 
                          ev.position.y >= content_y and ev.position.y < (content_y + content_height)
  
  print("DEBUG: Mouse in canvas: " .. tostring(mouse_in_canvas) .. ", in content: " .. tostring(mouse_in_content))
  
  -- Always handle mouse events if mouse is in canvas, regardless of content area
  if not mouse_in_canvas then
    -- Only handle mouse up when outside canvas to ensure we can stop dragging
    if ev.type == "up" then
      print("DEBUG: Mouse up outside canvas - STOP DRAWING")
      mouse_is_down = false
      -- Don't clear current_drawing_parameter - keep it visible after release
      last_mouse_x = -1
      last_mouse_y = -1
      if canvas_experiments_canvas then
        canvas_experiments_canvas:update()
      end
      -- Update status text to show the parameter info (without "drawing" indication)
      if status_text_view then
        status_text_view.text = PakettiCanvasExperimentsGetStatusText()
      end
    end
    return
  end
  
  local x = ev.position.x
  local y = ev.position.y
  
  -- Always update mouse tracking for cursor display
  last_mouse_x = x
  last_mouse_y = y
  
  if ev.type == "down" then
    print("DEBUG: Mouse down - START DRAWING")
    mouse_is_down = true
    -- Only apply parameter changes if we're in the content area
    if mouse_in_content then
      PakettiCanvasExperimentsHandleMouseInput(x, y)
    else
      print("DEBUG: Mouse down outside content area - tracking but not applying changes")
      current_drawing_parameter = nil
    end
  elseif ev.type == "up" then
    print("DEBUG: Mouse up - STOP DRAWING")
    mouse_is_down = false
    -- Don't clear current_drawing_parameter - keep it visible after release
    -- Clear mouse tracking and update canvas to hide cursor
    last_mouse_x = -1
    last_mouse_y = -1
    if canvas_experiments_canvas then
      canvas_experiments_canvas:update()
    end
    -- Update status text to show the parameter info (without "drawing" indication)
    if status_text_view then
      status_text_view.text = PakettiCanvasExperimentsGetStatusText()
    end
  elseif ev.type == "move" then
    if mouse_is_down then
      print("DEBUG: Mouse drag - mouse_in_content: " .. tostring(mouse_in_content))
      -- Only apply parameter changes if we're in the content area
      if mouse_in_content then
        print("DEBUG: Mouse drag in content area - DRAWING CURVE")
        PakettiCanvasExperimentsHandleMouseInput(x, y)
      else
        print("DEBUG: Mouse drag outside content area - tracking cursor but not applying changes")
        -- Keep current_drawing_parameter visible even when outside content area
        -- Still update the canvas to show cursor movement
        if canvas_experiments_canvas then
          canvas_experiments_canvas:update()
        end
        -- Update status text to show the parameter info
        if status_text_view then
          status_text_view.text = PakettiCanvasExperimentsGetStatusText()
        end
      end
    else
      print("DEBUG: Mouse move (not drawing)")
    end
  end
end

-- Handle mouse input for parameter editing (only called when in content area)
function PakettiCanvasExperimentsHandleMouseInput(x, y)
  print("DEBUG: Mouse input at " .. x .. ", " .. y .. " (content area)")
  
  if not current_device or #device_parameters == 0 then
    print("DEBUG: No device or parameters available for mouse input")
    return
  end
  
  -- Calculate which parameter column we're in (relative to content area)
  local parameter_index = math.floor((x - content_x) / parameter_width) + 1
  parameter_index = math.max(1, math.min(parameter_index, #device_parameters))
  
  print("DEBUG: Drawing on parameter " .. parameter_index .. " (" .. device_parameters[parameter_index].name .. ")")
  
  -- Calculate normalized Y position (0 = max, 1 = min) relative to content area
  local normalized_y = 1.0 - ((y - content_y) / content_height)
  normalized_y = math.max(0, math.min(1, normalized_y))
  
  print("DEBUG: Normalized Y: " .. normalized_y)
  
  -- Update the parameter we're currently touching
  local param_info = device_parameters[parameter_index]
  if param_info then
    -- Set current drawing parameter for status display
    current_drawing_parameter = param_info
    
    local new_value = param_info.value_min + (normalized_y * (param_info.value_max - param_info.value_min))
    print("DEBUG: Setting parameter " .. parameter_index .. " (" .. param_info.name .. ") to " .. new_value)
    param_info.parameter.value = new_value
    
    -- Update status text to show current parameter info
    if status_text_view then
      status_text_view.text = PakettiCanvasExperimentsGetStatusText()
    end
    
    -- Update canvas immediately for smooth drawing feedback
    if canvas_experiments_canvas then
      canvas_experiments_canvas:update()
      print("DEBUG: Canvas updated for parameter " .. parameter_index)
    else
      print("DEBUG: Warning - canvas reference is nil!")
    end
  else
    print("DEBUG: No parameter info found for index " .. parameter_index)
    current_drawing_parameter = nil
  end
end

-- Draw the canvas
function PakettiCanvasExperimentsDrawCanvas(ctx)
  local w, h = canvas_width, canvas_height
  
  -- Use the exact same clear pattern as working PCMWriter
  ctx:clear_rect(0, 0, w, h)
  
  print("DEBUG: Canvas size: " .. w .. "x" .. h)
  print("DEBUG: Content area: " .. content_width .. "x" .. content_height .. " at " .. content_x .. "," .. content_y)
  print("DEBUG: Device parameters count: " .. #device_parameters)
  
  if #device_parameters == 0 then
    print("DEBUG: No parameters - drawing error message")
    -- Draw error message using working color format
    ctx.stroke_color = {255, 0, 0, 255}  -- Red - using 0-255 integers like working code
    ctx.line_width = 2
    ctx:begin_path()
    ctx:move_to(10, h/2)
    ctx:line_to(w-10, h/2)
    ctx:stroke()
    return
  end
  
  -- Draw background grid within content area only
  ctx.stroke_color = {32, 0, 48, 255}  -- Dark purple grid - using 0-255 integers
  ctx.line_width = 1
  for i = 0, 10 do
    local x = content_x + (i / 10) * content_width
    ctx:begin_path()
    ctx:move_to(x, content_y)
    ctx:line_to(x, content_y + content_height)
    ctx:stroke()
  end
  for i = 0, 10 do
    local y = content_y + (i / 10) * content_height
    ctx:begin_path()
    ctx:move_to(content_x, y)
    ctx:line_to(content_x + content_width, y)
    ctx:stroke()
  end
  
  -- Draw center line within content area (like zero line in PCMWriter)
  ctx.stroke_color = {128, 128, 128, 255}  -- Gray center line - using 0-255 integers
  ctx.line_width = 1
  local center_y = content_y + (content_height / 2)
  ctx:begin_path()
  ctx:move_to(content_x, center_y)
  ctx:line_to(content_x + content_width, center_y)
  ctx:stroke()
  
  -- Draw parameter bars using the exact same pattern as working PCMWriter waveform drawing
  print("DEBUG: Drawing " .. #device_parameters .. " parameter bars")
  
  for i, param_info in ipairs(device_parameters) do
    local column_start_x = content_x + (i - 1) * parameter_width
    local column_center_x = column_start_x + (parameter_width / 2)
    local column_end_x = column_start_x + parameter_width
    
    print("DEBUG: Parameter " .. i .. " at x=" .. column_start_x .. " width=" .. parameter_width)
    
    -- Draw parameter column background - light gray
    ctx.stroke_color = {64, 64, 64, 255}  -- Dark gray - using 0-255 integers
    ctx.line_width = 1
    ctx:begin_path()
    ctx:move_to(column_start_x, content_y)
    ctx:line_to(column_start_x, content_y + content_height)
    ctx:stroke()
    
    -- Get parameter value and calculate bar height
    local param_value = param_info.parameter.value
    local value_min = param_info.value_min
    local value_max = param_info.value_max
    
    print("DEBUG: Parameter " .. i .. " value=" .. param_value .. " range=" .. value_min .. " to " .. value_max)
    
    -- Calculate normalized value (0 to 1)
    local normalized_value = 0
    if value_max > value_min then
      normalized_value = (param_value - value_min) / (value_max - value_min)
      normalized_value = math.max(0, math.min(1, normalized_value))
    end
    
    -- Draw parameter bar as filled rectangle
    local bar_height = normalized_value * content_height
    local bar_start_y = content_y + content_height - bar_height  -- Start from bottom of content area
    
    -- Draw parameter bar - slightly brighter purple
    ctx.fill_color = {120, 40, 160, 255}  -- Brighter purple - using 0-255 integers
    ctx:fill_rect(column_start_x + 1, bar_start_y, parameter_width - 2, bar_height)  -- Fill full column width minus 1px margins
    
    
    -- Draw parameter name vertically using custom text rendering
    if parameter_width > 20 then  -- Only draw text if there's enough space
      ctx.stroke_color = {200, 200, 200, 255}  -- Light gray text
      ctx.line_width = 2  -- Make text bold by using thicker lines
      
      -- Draw parameter name vertically (rotated text effect)
      local text_size = math.max(4, math.min(12, parameter_width * 0.6))  -- Scale text reasonably to fit column
      local text_start_y = content_y + 10  -- Start near top
      
      -- Draw each character of the parameter name vertically
      local param_name = param_info.name
      local letter_spacing = text_size + 4  -- Add 4 pixels between letters for better readability
      -- Calculate how many characters can fit vertically
      local max_chars = math.floor((content_height - 20) / letter_spacing)
      if #param_name > max_chars then
        param_name = param_name:sub(1, max_chars - 3) .. "..."
      end
      
      for char_index = 1, #param_name do
        local char = param_name:sub(char_index, char_index)
        local char_y = text_start_y + (char_index - 1) * letter_spacing
        if char_y < content_y + content_height - text_size - 5 then  -- Don't draw outside content area
          local char_func = letter_functions[char:upper()]
          if char_func then
            char_func(ctx, column_center_x - text_size/2, char_y, text_size)
          end
        end
      end
    end
    
    print("DEBUG: Drew parameter " .. i .. " bar height=" .. bar_height .. " at y=" .. bar_start_y)
  end
  
  -- Draw content area border (dark purple to show the active area)
  ctx.stroke_color = {80, 0, 120, 255}  -- Dark purple border for content area
  ctx.line_width = 3
  ctx:begin_path()
  ctx:rect(content_x, content_y, content_width, content_height)
  ctx:stroke()
  
  -- Draw overall canvas border (white)
  ctx.stroke_color = {255, 255, 255, 255}  -- White border - using 0-255 integers
  ctx.line_width = 2
  ctx:begin_path()
  ctx:rect(0, 0, w, h)
  ctx:stroke()
  
  -- Draw mouse cursor when drawing (like working PCMWriter)
  if mouse_is_down and last_mouse_x >= 0 and last_mouse_y >= 0 then
    print("DEBUG: Drawing mouse cursor at " .. last_mouse_x .. ", " .. last_mouse_y)
    
    -- Draw crosshair cursor - white like working PCMWriter
    ctx.stroke_color = {255, 255, 255, 255}  -- White - using 0-255 integers
    ctx.line_width = 1
    
    -- Vertical line (full canvas height)
    ctx:begin_path()
    ctx:move_to(last_mouse_x, 0)
    ctx:line_to(last_mouse_x, h)
    ctx:stroke()
    
    -- Horizontal line (full canvas width)
    ctx:begin_path()
    ctx:move_to(0, last_mouse_y)
    ctx:line_to(w, last_mouse_y)
    ctx:stroke()
    
    -- Central dot - bright red
    ctx.stroke_color = {255, 0, 0, 255}  -- Red - using 0-255 integers
    ctx.line_width = 3
    ctx:begin_path()
    ctx:move_to(last_mouse_x - 2, last_mouse_y - 2)
    ctx:line_to(last_mouse_x + 2, last_mouse_y + 2)
    ctx:move_to(last_mouse_x - 2, last_mouse_y + 2)
    ctx:line_to(last_mouse_x + 2, last_mouse_y - 2)
    ctx:stroke()
  end
  
  print("DEBUG: Canvas drawing complete")
end

-- Key handler function to pass keys back to Renoise
function my_keyhandler_func(dialog, key)
  -- Pass all keys back to Renoise so normal shortcuts work
  return key
end

-- Clean up observers when dialog closes
function PakettiCanvasExperimentsCleanup()
  print("DEBUG: Cleaning up Canvas Experiments")
  
  -- Remove device selection observer
  if device_selection_notifier then
    local song = renoise.song()
    song.selected_device_observable:remove_notifier(device_selection_notifier)
    device_selection_notifier = nil
    print("DEBUG: Device selection observer removed")
  end
  
  -- Clear references
  canvas_experiments_dialog = nil
  canvas_experiments_canvas = nil
  status_text_view = nil
  randomize_slider_view = nil
  current_device = nil
  device_parameters = {}
  parameter_width = 0
  mouse_is_down = false
  last_mouse_x = -1
  last_mouse_y = -1
  current_drawing_parameter = nil
end

-- Create the main dialog
function PakettiCanvasExperimentsCreateDialog()
  if canvas_experiments_dialog and canvas_experiments_dialog.visible then
    canvas_experiments_dialog:close()
  end
  
  local title = "Paketti Selected Device Parameter Editor"
  
  -- Create fresh ViewBuilder instance
  local vb = renoise.ViewBuilder()
  
  local dialog_content = vb:column {
    margin = 10,
    
    -- Dynamic status text showing track, device, and parameter info
    vb:text {
      id = "status_text_view",
      text = PakettiCanvasExperimentsGetStatusText(),
      font = "bold",
      style = "strong"
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
    
    -- Randomize controls
    vb:row {
      vb:text {
        text = "Randomize Strength:",
        width = 120
      },
      vb:slider {
        id = "randomize_slider_view",
        min = 0,
        max = 100,
        value = randomize_strength,
        width = math.max(50, parameter_width),  -- Use actual calculated parameter width
        notifier = function(value)
          randomize_strength = value
          -- Update percentage text
          if vb.views.randomize_percentage_text then
            vb.views.randomize_percentage_text.text = string.format("%.2f%%", value)
          end
        end
      },
      vb:text {
        text = string.format("%.2f%%", randomize_strength),
        width = math.max(47, parameter_width - 3),  -- actual parameter width minus 3
        id = "randomize_percentage_text"
      },
      vb:button {
        text = "Randomize",
        width = 100,
        notifier = function()
          PakettiCanvasExperimentsRandomizeParameters()
        end
      }
    },
    
    -- Control buttons
    vb:row {
      vb:button {
        text = "Toggle External Editor",
        width = 150,
        notifier = function()
          if current_device then
            current_device.external_editor_visible = not current_device.external_editor_visible
          end
        end
      },
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
          PakettiCanvasExperimentsCleanup()
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
  status_text_view = vb.views.status_text_view
  randomize_slider_view = vb.views.randomize_slider_view
  
  -- Add dialog close notifier for cleanup
  if canvas_experiments_dialog then
    print("DEBUG: Paketti Selected Device Parameter Editor dialog created successfully")
  end
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

-- Randomize all parameters with strength control
function PakettiCanvasExperimentsRandomizeParameters()
  if not current_device or #device_parameters == 0 then
    return
  end
  
  local strength = randomize_strength / 100.0  -- Convert to 0-1 range
  
  for i, param_info in ipairs(device_parameters) do
    local current_value = param_info.parameter.value
    local value_range = param_info.value_max - param_info.value_min
    
    -- Generate random value in full range
    local random_value = param_info.value_min + (math.random() * value_range)
    
    -- Apply strength: interpolate between current value and random value
    local new_value = current_value + (random_value - current_value) * strength
    
    -- Clamp to valid range
    new_value = math.max(param_info.value_min, math.min(param_info.value_max, new_value))
    
    param_info.parameter.value = new_value
    
    print("DEBUG: Randomized parameter " .. i .. " (" .. param_info.name .. ") from " .. current_value .. " to " .. new_value)
  end
  
  -- Update canvas
  if canvas_experiments_canvas then
    canvas_experiments_canvas:update()
  end
  
  renoise.app():show_status("Randomized " .. #device_parameters .. " parameters with " .. randomize_strength .. "% strength")
end

-- Menu entries
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Canvas Device Parameter Editor",
  invoke = PakettiCanvasExperimentsInit
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:Canvas Device Parameter Editor",
  invoke = PakettiCanvasExperimentsInit
}

print("PakettiCanvasExperiments.lua loaded successfully") 

