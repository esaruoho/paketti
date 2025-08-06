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

-- Edit A/B functionality (inspired by PakettiPCMWriter)
local current_edit_mode = "A"  -- "A" or "B"
local parameter_values_A = {}  -- Store parameter values for Edit A
local parameter_values_B = {}  -- Store parameter values for Edit B
local crossfade_amount = 0.0   -- 0.0 = full A, 1.0 = full B

-- Follow pattern automation parameter writing (DEFAULT: OFF)
local follow_automation = false
local device_parameter_observers = {}

-- Auto-switch to automation view when enabling automation sync (DEFAULT: OFF)
local auto_show_automation = false

-- Track which specific parameter is being manually edited (automation sync aware)
local parameter_being_drawn = nil  -- Index of parameter currently being drawn
local automation_reading_enabled = true

-- Button colors for Edit A/B
local COLOR_BUTTON_ACTIVE = {0xFF, 0x80, 0x80}    -- Light red for active
local COLOR_BUTTON_INACTIVE = {0x80, 0x80, 0x80}  -- Gray for inactive

-- Canvas bar colors for Edit A/B visualization (consistent like PakettiPCMWriter)
local COLOR_EDIT_A_ACTIVE = {120, 40, 160, 255}     -- Purple for Edit A (bold when editing A)
local COLOR_EDIT_A_INACTIVE = {120, 40, 160, 180}   -- Purple for Edit A (faded when not editing A)
local COLOR_EDIT_B_ACTIVE = {160, 160, 40, 255}     -- Yellow for Edit B (bold when editing B) 
local COLOR_EDIT_B_INACTIVE = {160, 160, 40, 180}   -- Yellow for Edit B (faded when not editing B)
local COLOR_CROSSFADE = {80, 160, 40, 255}          -- Green for crossfade outline

-- Canvas update timer
local canvas_update_timer = nil
-- Remember previous device index for smart restoration
local previous_device_index = nil

-- Navigation functions for track and device switching
function PakettiCanvasExperimentsSelectPreviousTrack()
  local song = renoise.song()
  local current_track = song.selected_track_index
  local new_track = current_track - 1
  if new_track < 1 then
    new_track = #song.tracks
  end
  song.selected_track_index = new_track
  renoise.app():show_status("Switched to track: " .. song.tracks[new_track].name)
end

function PakettiCanvasExperimentsSelectNextTrack()
  local song = renoise.song()
  local current_track = song.selected_track_index
  local new_track = current_track + 1
  if new_track > #song.tracks then
    new_track = 1
  end
  song.selected_track_index = new_track
  renoise.app():show_status("Switched to track: " .. song.tracks[new_track].name)
end

function PakettiCanvasExperimentsSelectPreviousDevice()
  local song = renoise.song()
  local track = song.selected_track
  if #track.devices > 0 then
    local current_device = song.selected_device_index or 1
    local new_device = current_device - 1
    if new_device < 1 then
      new_device = #track.devices
    end
    song.selected_device_index = new_device
    local device_name = track.devices[new_device].display_name or "Unknown"
    renoise.app():show_status("Switched to device: " .. device_name)
  else
    renoise.app():show_status("No devices available on this track")
  end
end

function PakettiCanvasExperimentsSelectNextDevice()
  local song = renoise.song()
  local track = song.selected_track
  if #track.devices > 0 then
    local current_device = song.selected_device_index or 1
    local new_device = current_device + 1
    if new_device > #track.devices then
      new_device = 1
    end
    song.selected_device_index = new_device
    local device_name = track.devices[new_device].display_name or "Unknown"
    renoise.app():show_status("Switched to device: " .. device_name)
  else
    renoise.app():show_status("No devices available on this track")
  end
end

-- Function to detect automation frame and selected parameter
function PakettiCanvasExperimentsDetectAutomationSelection()
  local song = renoise.song()
  
  -- Check if automation frame is displayed
  local automation_frame_active = (renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION)
  
  if automation_frame_active then
    -- Check if there's a selected automation parameter and device
    local selected_automation_param = song.selected_automation_parameter
    local selected_automation_device = song.selected_automation_device
    
    if selected_automation_param and selected_automation_param.is_automatable and selected_automation_device then
      print("AUTOMATION_DETECTION: Automation frame active, parameter: " .. selected_automation_param.name)
      print("AUTOMATION_DETECTION: Device: " .. selected_automation_device.display_name)
      
      -- Find the device index in the current track using display_name comparison
      local current_track = song.selected_track
      for device_index, device in ipairs(current_track.devices) do
        if device.display_name == selected_automation_device.display_name then
          print("AUTOMATION_DETECTION: Found device at index " .. device_index .. ": " .. device.display_name)
          -- Select this device
          song.selected_device_index = device_index
          renoise.app():show_status("Auto-selected device from automation: " .. device.display_name .. " (" .. selected_automation_param.name .. ")")
          return true
        end
      end
      
      print("AUTOMATION_DETECTION: Device not found in current track devices")
    end
  end
  
  return false
end
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
  ctx:move_to(x + size/4, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:stroke()
end

local function draw_hash(ctx, x, y, size)
  ctx:begin_path()
  -- Two vertical lines
  ctx:move_to(x + size/3, y + size/4)
  ctx:line_to(x + size/3, y + 3*size/4)
  ctx:move_to(x + 2*size/3, y + size/4)
  ctx:line_to(x + 2*size/3, y + 3*size/4)
  -- Two horizontal lines
  ctx:move_to(x + size/6, y + size/3)
  ctx:line_to(x + 5*size/6, y + size/3)
  ctx:move_to(x + size/6, y + 2*size/3)
  ctx:line_to(x + 5*size/6, y + 2*size/3)
  ctx:stroke()
end

local function draw_plus(ctx, x, y, size)
  ctx:begin_path()
  -- Vertical line
  ctx:move_to(x + size/2, y + size/4)
  ctx:line_to(x + size/2, y + 3*size/4)
  -- Horizontal line
  ctx:move_to(x + size/4, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
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
  [" "] = draw_space, ["."] = draw_dot, ["-"] = draw_dash, ["#"] = draw_hash, ["+"] = draw_plus
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
  -- Safe nil checking throughout with proper error handling
  local success, result = pcall(function()
    if not current_device then
      return "No device selected"
    end
    
    local song = renoise.song()
    if not song then
      return "No song available"
    end
    
    local device_name = "Unknown Device"
    if current_device and current_device.display_name then
      device_name = current_device.display_name
    end
    
    local param_count = 0
    if device_parameters then
      param_count = #device_parameters
    end
    
    -- Safe track info access
    local track_number = "?"
    local track_name = "Unknown Track"
    
    if song.selected_track_index then
      track_number = tostring(song.selected_track_index)
    end
    
    if song.selected_track and song.selected_track.name then
      track_name = song.selected_track.name
    end
    
    local base_text = string.format("Track %s / %s [%s] / %d parameters", 
      track_number, track_name, device_name, param_count)
    
    -- Safe current parameter access with multiple nil checks
    if current_drawing_parameter and 
       current_drawing_parameter.parameter and 
       current_drawing_parameter.parameter.value ~= nil and
       current_drawing_parameter.name and
       current_drawing_parameter.index then
      
      local param_info = current_drawing_parameter
      local param_text = string.format(" - Parameter %d: %s = %.3f", 
        param_info.index, param_info.name, param_info.parameter.value)
      return base_text .. param_text
    end
    
    return base_text
  end)
  
  -- Return result if successful, otherwise fallback
  if success then
    return result
  else
    return "Canvas Parameter Editor - Error accessing device state"
  end
end

-- Refresh device parameters when device selection changes
function PakettiCanvasExperimentsRefreshDevice()
  local song = renoise.song()
  
  print("=== Device Selection Changed ===")
  
  -- Reset A/B state when device changes (but preserve automation sync setting)
  parameter_values_A = {}
  parameter_values_B = {}
  crossfade_amount = 0.0
  current_edit_mode = "A"
  -- Keep follow_automation setting when switching devices
  
  -- Clear any manual editing state
  parameter_being_drawn = nil
  automation_reading_enabled = true
  
  -- Update UI to reflect reset state
  if vb.views.edit_a_button then 
    vb.views.edit_a_button.color = COLOR_BUTTON_ACTIVE 
  end
  if vb.views.edit_b_button then 
    vb.views.edit_b_button.color = COLOR_BUTTON_INACTIVE 
  end
  if vb.views.crossfade_slider then 
    vb.views.crossfade_slider.value = 0.0 
  end
  if vb.views.randomize_button then 
    vb.views.randomize_button.text = "Randomize Edit A"
  end
  if vb.views.follow_automation_button then
    -- Update button to reflect actual follow_automation state
    vb.views.follow_automation_button.text = follow_automation and "Automation Sync: ON" or "Automation Sync: OFF"
    vb.views.follow_automation_button.color = follow_automation and COLOR_BUTTON_ACTIVE or COLOR_BUTTON_INACTIVE
  end
  
  -- Keep Renoise's follow player setting consistent with automation sync
  song.transport.follow_player = follow_automation
  
  -- Remove parameter observers for old device
  RemoveParameterObservers()
  

  
  -- Remember the current device index before it potentially gets lost
  if song.selected_device_index then
    previous_device_index = song.selected_device_index
  end
  
  -- Clear current drawing state when device changes
  current_drawing_parameter = nil
  mouse_is_down = false
  last_mouse_x = -1
  last_mouse_y = -1
  
  -- Check if we have a selected device
  local selected_device = nil
  if song and song.selected_device then
    selected_device = song.selected_device
  end
  
  if not selected_device then
    print("DEVICE_ERROR: No device selected - trying to restore previous device position")
    
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
         
         song.selected_device_index = target_device_index
         found_device = song.selected_device
         selected_device = found_device
       end
     end
    
    -- If restoration failed, DON'T force track changes - just work with current track
    if not found_device then
      print("DEVICE_ERROR: No device found - working with current track state without forcing changes")
      -- Don't force track selection changes - let user control track selection
      selected_device = nil
    end
    
    -- If no devices found at all, then show "no device selected"
    if not found_device then
      print("DEVICE_ERROR: No devices found in entire song")
      current_device = nil
      device_parameters = {}
      parameter_width = 0
      selected_device = nil
      
      -- Update status text
      if status_text_view then
        status_text_view.text = PakettiCanvasExperimentsGetStatusText()
      end
      
      if canvas_experiments_canvas then
        canvas_experiments_canvas:update()
      end
      
      -- Show status message but continue - don't return early
      renoise.app():show_status("No devices found - add a device to continue")
    end
  end
  
  if selected_device then
    print("DEVICE_OK: New selected device:")
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
  else
    print("DEVICE_WARNING: selected_device is nil after search - using empty state")
    current_device = nil
    device_parameters = {}
  end
  
  if #device_parameters == 0 then
    parameter_width = 0
  else
    -- Calculate parameter width based on content width
    parameter_width = content_width / #device_parameters
    
    -- Automatically capture current device parameters to Edit A
    for i, param_info in ipairs(device_parameters) do
      parameter_values_A[i] = param_info.parameter.value
    end
    print("DEVICE_CHANGE: Captured " .. #device_parameters .. " current device parameters to Edit A")
  end
  
  -- Update status text
  if status_text_view then
    status_text_view.text = PakettiCanvasExperimentsGetStatusText()
  end
  
  -- Update canvas if it exists
  if canvas_experiments_canvas then
    canvas_experiments_canvas:update()
  end
  
  -- Setup parameter observers for automation visualization (always setup for canvas updates)
  SetupParameterObservers()
  
  -- Force immediate canvas update after device change
  if canvas_experiments_canvas then
    canvas_experiments_canvas:update()
  end
  
  -- Show status message
  renoise.app():show_status(PakettiCanvasExperimentsGetStatusText())
end

-- Initialize the canvas experiments
function PakettiCanvasExperimentsInit()
  -- If dialog is already open, just return - let the device selection observer handle the device change
  if canvas_experiments_dialog and canvas_experiments_dialog.visible then
    return
  end
  
  local song = renoise.song()
  
  -- First, try to detect automation frame and auto-select device if applicable
  local automation_detected = PakettiCanvasExperimentsDetectAutomationSelection()
  
  -- Check if we have a selected device with safe access
  local selected_device = nil
  if song and song.selected_device then
    selected_device = song.selected_device
  end
  
  if not selected_device then
    print("DEVICE_ERROR: No device selected - searching for available devices")
    
         -- Don't force track changes - work with current track state
     print("INIT: No device selected - working with current track without forcing changes")
           selected_device = nil
    
    if not selected_device then
      print("INIT: No device available - dialog will open with empty state")
      -- Continue anyway - let the dialog open with no device state
      current_device = nil
      device_parameters = {}
      parameter_width = 0
    end
  end
  
  if selected_device then
    print("DEVICE_OK: Selected device found:")
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
  else
    print("DEVICE_ERROR: No valid device available - initializing with empty state")
    current_device = nil
    device_parameters = {}
  end
  
  print("DEVICE_INFO: Found " .. #device_parameters .. " automatable parameters")
  
  if #device_parameters == 0 then
    print("DEVICE_INFO: No automatable parameters - dialog will show empty canvas")
    parameter_width = 0
  else
    -- Calculate parameter width based on content width
    parameter_width = content_width / #device_parameters
    print("DEVICE_INFO: Parameter width: " .. parameter_width .. " pixels each")
  end
  
  -- Automatically capture current device parameters to Edit A
  if #device_parameters > 0 then
    for i, param_info in ipairs(device_parameters) do
      parameter_values_A[i] = param_info.parameter.value
    end
    print("INIT: Captured " .. #device_parameters .. " current device parameters to Edit A")
  end
  
  -- Create the dialog
  PakettiCanvasExperimentsCreateDialog()
  
  -- Set up device selection observer
  if device_selection_notifier then
    pcall(function()
      if song and song.selected_device_observable then
        song.selected_device_observable:remove_notifier(device_selection_notifier)
        print("INIT: ✅ Removed existing device selection observer")
      end
    end)
    device_selection_notifier = nil
  end
  
  device_selection_notifier = function()
    PakettiCanvasExperimentsRefreshDevice()
  end
  
  song.selected_device_observable:add_notifier(device_selection_notifier)
end

-- Handle mouse input
function PakettiCanvasExperimentsHandleMouse(ev)
  -- print("DEBUG: Mouse event - type: " .. ev.type .. ", position: " .. ev.position.x .. ", " .. ev.position.y)
  
  local w = canvas_width
  local h = canvas_height
  
  -- Handle mouse leave event - but don't stop dragging!
  if ev.type == "exit" then
    -- print("DEBUG: Mouse exit event - keeping mouse_is_down state")
    -- Don't reset mouse_is_down here - let user come back and continue dragging
    return
  end
  
  -- Check if mouse is within canvas bounds
  local mouse_in_canvas = ev.position.x >= 0 and ev.position.x < w and 
                         ev.position.y >= 0 and ev.position.y < h
  
  -- Check if mouse is within content area bounds
  local mouse_in_content = ev.position.x >= content_x and ev.position.x < (content_x + content_width) and 
                          ev.position.y >= content_y and ev.position.y < (content_y + content_height)
  
  -- print("DEBUG: Mouse in canvas: " .. tostring(mouse_in_canvas) .. ", in content: " .. tostring(mouse_in_content))
  
  -- Always handle mouse events if mouse is in canvas, regardless of content area
  if not mouse_in_canvas then
    -- Only handle mouse up when outside canvas to ensure we can stop dragging
    if ev.type == "up" then
      mouse_is_down = false
      
      -- RE-ENABLE ONLY THE SPECIFIC PARAMETER'S OBSERVER (if it was disabled)
      if follow_automation and parameter_being_drawn then
        local param_info = device_parameters[parameter_being_drawn]
        if param_info and param_info.parameter and param_info.parameter.value_observable then
          local parameter = param_info.parameter
          local observer = device_parameter_observers[parameter]
          
          if observer then
            if not parameter.value_observable:has_notifier(observer) then
              parameter.value_observable:add_notifier(observer)
              print("MOUSE_UP_OUTSIDE: ✅ RE-ENABLED automation for parameter " .. parameter_being_drawn .. " (" .. param_info.name .. ")")
            end
          end
        end
      end
      
      -- Clear parameter being drawn
      parameter_being_drawn = nil
      
      last_mouse_x = -1
      last_mouse_y = -1
      if canvas_experiments_canvas then
        canvas_experiments_canvas:update()
      end
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
    mouse_is_down = true
    
    -- Calculate which parameter we're starting to draw on
    if mouse_in_content and current_device and device_parameters and #device_parameters > 0 and parameter_width > 0 then
      parameter_being_drawn = math.floor((x - content_x) / parameter_width) + 1
      parameter_being_drawn = math.max(1, math.min(parameter_being_drawn, #device_parameters))
      
      -- If automation sync is ON, disable ONLY this parameter's observer to prevent jitter
      if follow_automation then
        local param_info = device_parameters[parameter_being_drawn]
        if param_info and param_info.parameter then
          local parameter = param_info.parameter
          local observer = device_parameter_observers[parameter]
          
          print("MOUSE_DOWN: Disabling automation for parameter " .. parameter_being_drawn .. " (" .. param_info.name .. ")")
          
          if observer then
            if parameter.value_observable:has_notifier(observer) then
              parameter.value_observable:remove_notifier(observer)
              print("MOUSE_DOWN: ✅ DISABLED automation for parameter " .. parameter_being_drawn .. " (" .. param_info.name .. ")")
              renoise.app():show_status("Drawing: Automation disabled for " .. param_info.name)
            else
              print("MOUSE_DOWN: ❌ Observer not found on parameter " .. parameter_being_drawn)
              -- NOTE: Observer will be rebuilt when mouse is released (see MOUSE_UP section)
              print("MOUSE_DOWN: ⚠️ Observer missing for parameter " .. parameter_being_drawn .. " - will rebuild on mouse up")
            end
          else
            print("MOUSE_DOWN: ❌ No observer stored for parameter " .. parameter_being_drawn)
          end
        end
      end
    end
    
    -- Only apply parameter changes if we're in the content area
    if mouse_in_content then
      PakettiCanvasExperimentsHandleMouseInput(x, y)
    else
      current_drawing_parameter = nil
    end
  elseif ev.type == "up" then
    mouse_is_down = false
    
    -- RE-ENABLE ONLY THE SPECIFIC PARAMETER'S OBSERVER (if it was disabled)
    if follow_automation and parameter_being_drawn then
      local param_info = device_parameters[parameter_being_drawn]
      if param_info and param_info.parameter and param_info.parameter.value_observable then
        local parameter = param_info.parameter
        local observer = device_parameter_observers[parameter]
        
        if observer then
          if not parameter.value_observable:has_notifier(observer) then
            parameter.value_observable:add_notifier(observer)
            print("MOUSE_UP: ✅ RE-ENABLED automation for parameter " .. parameter_being_drawn .. " (" .. param_info.name .. ")")
            renoise.app():show_status("Drawing complete: Automation resumed for " .. param_info.name)
          else
            print("MOUSE_UP: ⚠️ Observer was already active for parameter " .. parameter_being_drawn)
          end
        else
          print("MOUSE_UP: ⚠️ REBUILDING observer for parameter " .. parameter_being_drawn)
          -- SAFETY: Rebuild the observer if it was lost (e.g., due to remove_all_notifiers)
          local param_index = parameter_being_drawn  -- Capture in closure
          local new_observer = function()
            if not canvas_experiments_dialog or not canvas_experiments_dialog.visible then
              return
            end
            if canvas_experiments_canvas then
              canvas_experiments_canvas:update()
            end
          end
          parameter.value_observable:add_notifier(new_observer)
          device_parameter_observers[parameter] = new_observer
          print("MOUSE_UP: ✅ REBUILT automation observer for parameter " .. parameter_being_drawn)
          renoise.app():show_status("Drawing complete: Automation observer rebuilt for " .. param_info.name)
        end
      end
    end
    
    -- Clear parameter being drawn
    parameter_being_drawn = nil
    
    -- Clear mouse tracking and update canvas immediately to hide cursor
    last_mouse_x = -1
    last_mouse_y = -1
    if canvas_experiments_canvas then
      canvas_experiments_canvas:update()
    end
    -- Update status text
    if status_text_view then
      status_text_view.text = PakettiCanvasExperimentsGetStatusText()
    end
  elseif ev.type == "move" then
    if mouse_is_down then
      -- print("DEBUG: Mouse drag - mouse_in_content: " .. tostring(mouse_in_content))
      -- Only apply parameter changes if we're in the content area
      if mouse_in_content then
        -- print("DEBUG: Mouse drag in content area - DRAWING CURVE")
        PakettiCanvasExperimentsHandleMouseInput(x, y)
      else
        -- print("DEBUG: Mouse drag outside content area - tracking cursor but not applying changes")
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
      -- print("DEBUG: Mouse move (not drawing)")
    end
  end
end

-- Handle mouse input for parameter editing (only called when in content area)
function PakettiCanvasExperimentsHandleMouseInput(x, y)
  -- print("DEBUG: Mouse input at " .. x .. ", " .. y .. " (content area)")
  
  if not current_device or not device_parameters or #device_parameters == 0 then
    -- print("DEBUG: No device or parameters available for mouse input")
    current_drawing_parameter = nil
    return
  end
  
  -- Calculate which parameter column we're in (relative to content area)
  local parameter_index = 1
  if parameter_width > 0 then
    parameter_index = math.floor((x - content_x) / parameter_width) + 1
    parameter_index = math.max(1, math.min(parameter_index, #device_parameters))
  end
  
  -- print("DEBUG: Drawing on parameter " .. parameter_index .. " (" .. device_parameters[parameter_index].name .. ")")
  
  -- Calculate normalized Y position (0 = max, 1 = min) relative to content area
  local normalized_y = 1.0 - ((y - content_y) / content_height)
  normalized_y = math.max(0, math.min(1, normalized_y))
  
  -- print("DEBUG: Normalized Y: " .. normalized_y)
  
  -- Update the parameter we're currently touching
  local param_info = device_parameters[parameter_index]
  if param_info then
    -- Set current drawing parameter for status display
    current_drawing_parameter = param_info
    
    local new_value = param_info.value_min + (normalized_y * (param_info.value_max - param_info.value_min))
    -- print("DEBUG: Setting parameter " .. parameter_index .. " (" .. param_info.name .. ") to " .. new_value)
    
    if current_edit_mode == "A" then
      -- Edit A mode: modify device parameters directly (Edit A IS the device)
      param_info.parameter.value = new_value
      
      -- Write to automation if following is enabled
      if follow_automation then
        WriteParameterToAutomation(param_info.parameter, new_value, false)  -- Show envelope for manual drawing
        -- Removed debug spam for performance during manual drawing
      end
      -- Removed manual set debug spam for performance
    elseif current_edit_mode == "B" then
      -- Edit B mode: modify Edit B values only, device unchanged until crossfade
      parameter_values_B[parameter_index] = new_value
      -- print("DEBUG: Stored Edit B value for parameter " .. parameter_index .. ": " .. new_value)
    end
    
    -- Update status text to show current parameter info
    if status_text_view then
      status_text_view.text = PakettiCanvasExperimentsGetStatusText()
    end
    
    -- Update canvas IMMEDIATELY for responsive drawing feedback
    if canvas_experiments_canvas then
      canvas_experiments_canvas:update()
    end
  else
    -- print("DEBUG: No parameter info found for index " .. parameter_index)
    current_drawing_parameter = nil
  end
end

-- Draw the canvas
function PakettiCanvasExperimentsDrawCanvas(ctx)
  local w, h = canvas_width, canvas_height
  
  -- Use the exact same clear pattern as working PCMWriter
  ctx:clear_rect(0, 0, w, h)
  
  -- print("DEBUG: Canvas size: " .. w .. "x" .. h)
  -- print("DEBUG: Content area: " .. content_width .. "x" .. content_height .. " at " .. content_x .. "," .. content_y)
  -- print("DEBUG: Device parameters count: " .. #device_parameters)
  
  if #device_parameters == 0 then
    -- Draw "no parameters" message
    ctx.stroke_color = {128, 128, 128, 255}  -- Gray - friendly message
    ctx.line_width = 2
    
    -- Draw a simple message in the center
    local center_x = w / 2
    local center_y = h / 2
    
    -- Draw "No Device Parameters" text using simple lines
    ctx:begin_path()
    ctx:move_to(center_x - 100, center_y)
    ctx:line_to(center_x + 100, center_y)
    ctx:stroke()
    
    ctx:begin_path()
    ctx:move_to(center_x, center_y - 20)
    ctx:line_to(center_x, center_y + 20)
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
  
      -- Draw parameter bars - SIMPLE AND CLEAR like PakettiPCMWriter
    
    for i, param_info in ipairs(device_parameters) do
      local column_start_x = content_x + (i - 1) * parameter_width
      local column_center_x = column_start_x + (parameter_width / 2)
      local column_end_x = column_start_x + parameter_width
      
      -- Draw parameter column background - light gray
      ctx.stroke_color = {64, 64, 64, 255}  -- Dark gray
      ctx.line_width = 1
      ctx:begin_path()
      ctx:move_to(column_start_x, content_y)
      ctx:line_to(column_start_x, content_y + content_height)
      ctx:stroke()
      
      local value_min = param_info.value_min
      local value_max = param_info.value_max
      local bar_width = parameter_width - 4  -- Leave 2px margin on each side
      local bar_x = column_start_x + 2
      
      -- Check what data we have
      local has_stored_a = parameter_values_A[i] ~= nil
      local has_stored_b = parameter_values_B[i] ~= nil
      
      if current_edit_mode == "A" then
        -- EDIT A MODE: Show current device parameters as bold purple (Edit A IS the device)
        local param_value = param_info.parameter.value
        local normalized_current = (param_value - value_min) / (value_max - value_min)
        normalized_current = math.max(0, math.min(1, normalized_current))
        local current_height = normalized_current * content_height
        local current_y = content_y + content_height - current_height
        ctx.fill_color = COLOR_EDIT_A_ACTIVE  -- Bold purple for current device values
        ctx:fill_rect(bar_x, current_y, bar_width, current_height)
        
        -- Show stored B values as faded yellow background (if they exist)
        if has_stored_b then
          local value_b = parameter_values_B[i]
          local b_normalized = (value_b - value_min) / (value_max - value_min)
          b_normalized = math.max(0, math.min(1, b_normalized))
          local b_height = b_normalized * content_height
          local b_y = content_y + content_height - b_height
          ctx.fill_color = COLOR_EDIT_B_INACTIVE  -- Faded yellow for B reference
          ctx:fill_rect(bar_x, b_y, bar_width, b_height)
        end
        
      elseif current_edit_mode == "B" then
        -- EDIT B MODE: Show stored A as faded purple background, stored B as bold yellow
        
        -- Show stored A values as faded purple background (if they exist)
        if has_stored_a then
          local value_a = parameter_values_A[i]
          local a_normalized = (value_a - value_min) / (value_max - value_min)
          a_normalized = math.max(0, math.min(1, a_normalized))
          local a_height = a_normalized * content_height
          local a_y = content_y + content_height - a_height
          ctx.fill_color = COLOR_EDIT_A_INACTIVE  -- Faded purple for A reference
          ctx:fill_rect(bar_x, a_y, bar_width, a_height)
        end
        
        -- Show stored B values as bold yellow (if they exist)
        if has_stored_b then
          local value_b = parameter_values_B[i]
          local b_normalized = (value_b - value_min) / (value_max - value_min)
          b_normalized = math.max(0, math.min(1, b_normalized))
          local b_height = b_normalized * content_height
          local b_y = content_y + content_height - b_height
          ctx.fill_color = COLOR_EDIT_B_ACTIVE  -- Bold yellow for B editing
          ctx:fill_rect(bar_x, b_y, bar_width, b_height)
        end
      end
      
      -- CROSSFADE: Draw FAT HORIZONTAL LINE at crossfaded value (NOT outline mess!)
      if has_stored_a and has_stored_b then
        local value_a = parameter_values_A[i]
        local value_b = parameter_values_B[i]
        local crossfaded_value = value_a + (value_b - value_a) * crossfade_amount
        
        local crossfade_normalized = (crossfaded_value - value_min) / (value_max - value_min)
        crossfade_normalized = math.max(0, math.min(1, crossfade_normalized))
        local crossfade_y = content_y + content_height - (crossfade_normalized * content_height)
        
        -- Draw FAT GREEN LINE at crossfaded level
        ctx.stroke_color = COLOR_CROSSFADE  -- Green
        ctx.line_width = 4
        ctx:begin_path()
        ctx:move_to(bar_x, crossfade_y)
        ctx:line_to(bar_x + bar_width, crossfade_y)
        ctx:stroke()
      end
    
    
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
    
    
    -- print("DEBUG: Drew parameter " .. i .. " - A:" .. tostring(has_stored_a) .. " B:" .. tostring(has_stored_b) .. " mode=" .. current_edit_mode)
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
    -- print("DEBUG: Drawing mouse cursor at " .. last_mouse_x .. ", " .. last_mouse_y)
    
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
  
  -- print("DEBUG: Canvas drawing complete")
end

-- Key handler function to pass keys back to Renoise
function my_keyhandler_func(dialog, key)
  -- DEBUG: Show exactly what we're receiving
  print("KEYHANDLER DEBUG:")
  print("  key.name: '" .. tostring(key.name) .. "'")
  print("  key.modifiers: '" .. tostring(key.modifiers) .. "'")
  print("  key.modifiers type: " .. type(key.modifiers))
  if type(key.modifiers) == "table" then
    print("  modifiers table contents:")
    for i, mod in ipairs(key.modifiers) do
      print("    [" .. i .. "] = '" .. tostring(mod) .. "'")
    end
  end
  print("  ---")
  
  -- Check for CMD-H to close dialog
  if key.modifiers == "command" and key.name == "h" then
    print("KEYHANDLER: CMD-H pressed - closing dialog")
    print("KEYHANDLER: canvas_experiments_dialog exists: " .. tostring(canvas_experiments_dialog ~= nil))
    
    -- Store reference to dialog before cleanup (cleanup sets it to nil)
    local dialog_to_close = canvas_experiments_dialog
    
    if dialog_to_close then
      print("KEYHANDLER: canvas_experiments_dialog.visible: " .. tostring(dialog_to_close.visible))
    end
    
    PakettiCanvasExperimentsCleanup()
    
    if dialog_to_close then
      print("KEYHANDLER: Attempting to close dialog...")
      local success, error_msg = pcall(function()
        dialog_to_close:close()
      end)
      print("KEYHANDLER: Close success: " .. tostring(success))
      if not success then
        print("KEYHANDLER: Close error: " .. tostring(error_msg))
      end
    else
      print("KEYHANDLER: No dialog to close!")
    end
    return nil -- Don't pass this key to Renoise
  end
  
  -- CRITICAL: Pass ALL other keys back to Renoise so normal shortcuts work
  -- This ensures track selection, navigation, and all other Renoise shortcuts work normally
  print("KEYHANDLER: Passing key '" .. tostring(key.name) .. "' back to Renoise")
  return key
end

-- Clean up observers when dialog closes
function PakettiCanvasExperimentsCleanup()
  
  -- CRITICAL: Turn off automation sync to stop all automation writing
  follow_automation = false
  
  -- AGGRESSIVELY remove device selection observer with multiple attempts
  if device_selection_notifier then
    pcall(function()
      local song = renoise.song()
      if song and song.selected_device_observable then
        song.selected_device_observable:remove_notifier(device_selection_notifier)
        print("CLEANUP: ✅ Removed device selection observer")
      end
    end)
    device_selection_notifier = nil
  end
  
  RemoveParameterObservers()
  RemoveCanvasUpdateTimer()
  
  -- FORCE RESET Renoise state that might have been hijacked
  pcall(function()
    local song = renoise.song()
    -- Restore normal follow player setting (don't force it to false)
    -- song.transport.follow_player = true  -- Let user control this
  end)
  
  -- Clear all references
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
  
  -- Clear all state variables
  parameter_being_drawn = nil
  automation_reading_enabled = true
  parameter_values_A = {}
  parameter_values_B = {}
  crossfade_amount = 0.0
  current_edit_mode = "A"
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
    
    -- Navigation controls
    vb:row {
      vb:button {
        text = "Previous Track",
        width = 100,
        tooltip = "Switch to previous track",
        notifier = function()
          PakettiCanvasExperimentsSelectPreviousTrack()
        end
      },
      vb:button {
        text = "Previous Device",
        width = 110,
        tooltip = "Switch to previous device on current track",
        notifier = function()
          PakettiCanvasExperimentsSelectPreviousDevice()
        end
      },
      vb:button {
        text = "Next Device",
        width = 100,
        tooltip = "Switch to next device on current track",
        notifier = function()
          PakettiCanvasExperimentsSelectNextDevice()
        end
      },
      vb:button {
        text = "Next Track",
        width = 90,
        tooltip = "Switch to next track",
        notifier = function()
          PakettiCanvasExperimentsSelectNextTrack()
        end
      }
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
        width = 300,
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
        id = "randomize_button",
        text = "Randomize Edit A",
        width = 120,
        notifier = function()
          PakettiCanvasExperimentsRandomizeCurrentMode()
        end
      }
    },
    
    -- Edit A/B controls (inspired by PakettiPCMWriter)
    vb:row {
      vb:text {
        text = "Edit A/B:",
        style = "strong",
        width = 80
      },
      vb:button {
        id = "edit_a_button",
        text = "Edit A",
        width = 60,
        color = current_edit_mode == "A" and COLOR_BUTTON_ACTIVE or COLOR_BUTTON_INACTIVE,
        tooltip = "Switch to Edit A parameters",
        notifier = function()
          -- When switching from B to A, restore device to Edit A state
          if current_edit_mode == "B" then
            -- Check if we have stored A values to restore
            local has_a_values = false
            for k, v in pairs(parameter_values_A) do
              has_a_values = true
              break
            end
            
            if has_a_values then
              print("EDIT_A_SWITCH: Restoring device parameters from stored Edit A values")
              LoadParametersFromEdit("A") -- Restore device to Edit A values
            else
              print("EDIT_A_SWITCH: No stored Edit A values to restore")
            end
          end
          
          current_edit_mode = "A"
          print("EDIT_A_SWITCH: Switched to Edit A mode")
          
          -- Update button colors
          if vb.views.edit_a_button then vb.views.edit_a_button.color = COLOR_BUTTON_ACTIVE end
          if vb.views.edit_b_button then vb.views.edit_b_button.color = COLOR_BUTTON_INACTIVE end
          -- Update randomize button text
          if vb.views.randomize_button then vb.views.randomize_button.text = "Randomize Edit A" end
          -- Update canvas to show Edit A colors
          if canvas_experiments_canvas then canvas_experiments_canvas:update() end
          renoise.app():show_status("Edit A: Direct device control (purple bars)")
        end
      },
      vb:button {
        id = "edit_b_button", 
        text = "Edit B",
        width = 60,
        color = current_edit_mode == "B" and COLOR_BUTTON_ACTIVE or COLOR_BUTTON_INACTIVE,
        tooltip = "Switch to Edit B parameters",
        notifier = function()
          -- When switching to Edit B, capture current device state as Edit A reference ONLY if B is empty
          if current_edit_mode == "A" then
            -- Check if B values already exist
            local has_b_values = false
            for k, v in pairs(parameter_values_B) do
              has_b_values = true
              break
            end
            
            -- Only capture A reference if B doesn't have values yet
            if not has_b_values then
              StoreParametersToEdit("A") -- Capture device state as A for crossfading
              renoise.app():show_status("Edit B: Captured current device state as A reference")
            else
              renoise.app():show_status("Edit B: Using existing A/B values for crossfading")
            end
          end
          
          current_edit_mode = "B"
          -- Update button colors
          if vb.views.edit_a_button then vb.views.edit_a_button.color = COLOR_BUTTON_INACTIVE end
          if vb.views.edit_b_button then vb.views.edit_b_button.color = COLOR_BUTTON_ACTIVE end
          -- Update randomize button text
          if vb.views.randomize_button then vb.views.randomize_button.text = "Randomize Edit B" end
          -- Update canvas to show Edit B colors
          if canvas_experiments_canvas then canvas_experiments_canvas:update() end
        end
      },
      vb:text {
        text = "Crossfade",
        width = 40, style="strong",font="bold"
      },
      vb:slider {
        id = "crossfade_slider",
        min = 0.0,
        max = 1.0,
        value = crossfade_amount,
        width = 300,
        tooltip = "Crossfade between Edit A (0%) and Edit B (100%)",
        notifier = function(value)
          ApplyCrossfade(value)
          -- Update crossfade percentage text
          if vb.views.crossfade_text then
            vb.views.crossfade_text.text = string.format("%.1f%%", value * 100)
          end
        end
      },
      vb:text {
        id = "crossfade_text",
        text = string.format("%.1f%%", crossfade_amount * 100),
        width = 50, style="strong",font="bold"
      }

    },
    
    
    -- Automation controls
    vb:row {
      vb:button {
        text = "Add Snapshot to Automation",
        width = 180,
        tooltip = "Add current parameter values as automation points",
        notifier = function()
          PakettiCanvasExperimentsSnapshotToAutomation()
        end
      },
      vb:button {
        id = "follow_automation_button",
        text = "Automation Sync: OFF",
        width = 180,
        color = COLOR_BUTTON_INACTIVE,
        tooltip = "Toggle bidirectional automation: read automation playback + write when drawing",
        notifier = function()
          follow_automation = not follow_automation
          -- Also control follow_player as requested
          renoise.song().transport.follow_player = follow_automation
          -- Update button appearance
          if vb.views.follow_automation_button then
            vb.views.follow_automation_button.text = follow_automation and "Automation Sync: ON" or "Automation Sync: OFF"
            vb.views.follow_automation_button.color = follow_automation and COLOR_BUTTON_ACTIVE or COLOR_BUTTON_INACTIVE
          end
          
          -- Setup or remove parameter observers based on automation sync state
          if follow_automation then
            SetupParameterObservers()
            renoise.app():show_status("Automation Sync ON: Canvas reads automation playback + writes when drawing")
            
            -- Auto-switch to automation view if option is enabled
            if auto_show_automation then
              renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
              renoise.app():show_status("Automation Sync ON + Switched to Automation View")
            end
          else
            RemoveParameterObservers()
            renoise.app():show_status("Automation Sync OFF: Manual parameter control only")
          end
        end
      },
      vb:button {
        text = "Randomize Automation",
        width = 150,
        tooltip = "Randomize current Edit A/B and write snapshot to automation",
        notifier = function()
          PakettiCanvasExperimentsRandomizeAutomation()
        end
      }
    },
    
    -- Automation view configuration
    vb:row {
      vb:checkbox {
        id = "auto_show_automation_checkbox",
        value = auto_show_automation,
        notifier = function(value)
          auto_show_automation = value
          if value then
            renoise.app():show_status("Auto-switch to Automation View: ENABLED")
          else
            renoise.app():show_status("Auto-switch to Automation View: DISABLED")
          end
        end
      },
      vb:text {
        text = "Display Automation if pressing Automation Sync On", font="bold",style="strong",
        tooltip = "When enabled, turning on Automation Sync will automatically switch to the Automation view"
      }
    },
    
    -- Automation management buttons
    vb:row {
      vb:button {
        text = "Clear",
        width = 80,
        color = {0xFF, 0x60, 0x60},  -- Light red for destructive action
        tooltip = "Clear all automation for selected device - parameters become stable",
        notifier = function()
          PakettiCanvasExperimentsClearAutomation()
        end
      },
      vb:button {
        text = "Clean & Snap",
        width = 120,
        color = {0x60, 0xFF, 0x60},  -- Light green for creation action
        tooltip = "Clear automation + write current parameter values at line 1",
        notifier = function()
          PakettiCanvasExperimentsCleanAndSnap()
        end
      },
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

    },
    
  }
  
  canvas_experiments_dialog = renoise.app():show_custom_dialog(
    title,
    dialog_content,
    my_keyhandler_func
  )
  
  -- CRITICAL: Ensure cleanup happens when dialog is closed by user clicking X
  if canvas_experiments_dialog then
    -- Add close notifier to ensure cleanup
    pcall(function()
      -- This ensures cleanup even if user closes dialog with X button
      canvas_experiments_dialog.closed_observable:add_notifier(function()
        print("DIALOG_CLOSE: User closed dialog - running cleanup")
        PakettiCanvasExperimentsCleanup()
      end)
    end)
  end
  
  canvas_experiments_canvas = vb.views.canvas_experiments_canvas
  status_text_view = vb.views.status_text_view
  randomize_slider_view = vb.views.randomize_slider_view
  
  -- Add dialog close notifier for cleanup
  if canvas_experiments_dialog then
    -- Setup canvas update timer for periodic refresh
    SetupCanvasUpdateTimer()
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

-- Clear all automation for the selected device
function PakettiCanvasExperimentsClearAutomation()
  if not current_device or #device_parameters == 0 then
    renoise.app():show_status("No device selected for automation clearing")
    return
  end
  
  local song = renoise.song()
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  
  local cleared_count = 0
  
  -- Clear automation for each automatable parameter
  for i, param_info in ipairs(device_parameters) do
    local parameter = param_info.parameter
    local automation = pattern_track:find_automation(parameter)
    
    if automation then
      -- Clear all points from the automation
      automation:clear()
      cleared_count = cleared_count + 1
      print("CLEAR: Cleared automation for parameter " .. i .. " (" .. param_info.name .. ")")
    end
  end
  
  -- Update canvas to show stable parameters
  if canvas_experiments_canvas then
    canvas_experiments_canvas:update()
  end
  
  if cleared_count > 0 then
    renoise.app():show_status("Cleared automation for " .. cleared_count .. " parameters - now stable")
    print("CLEAR: Cleared automation for " .. cleared_count .. " parameters on device: " .. current_device.display_name)
  else
    renoise.app():show_status("No automation found to clear for this device")
    print("CLEAR: No automation found for device: " .. current_device.display_name)
  end
end

-- Clear automation and write current parameter values at line 1
function PakettiCanvasExperimentsCleanAndSnap()
  if not current_device or #device_parameters == 0 then
    renoise.app():show_status("No device selected for clean & snap")
    return
  end
  
  local song = renoise.song()
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  
  local processed_count = 0
  
  -- Clear automation and write current values for each automatable parameter
  for i, param_info in ipairs(device_parameters) do
    local parameter = param_info.parameter
    local current_value = parameter.value
    
    -- Get or create automation for this parameter
    local automation = pattern_track:find_automation(parameter)
    
    if not automation then
      automation = pattern_track:create_automation(parameter)
    end
    
    if automation then
      -- Clear all existing points
      automation:clear()
      
      -- Normalize current value to 0.0-1.0 range for automation
      local normalized_value = (current_value - parameter.value_min) / (parameter.value_max - parameter.value_min)
      normalized_value = math.max(0.0, math.min(1.0, normalized_value))
      
      -- Add automation point at line 1 with current value
      automation:add_point_at(1, normalized_value)
      processed_count = processed_count + 1
      
      print("CLEAN&SNAP: Parameter " .. i .. " (" .. param_info.name .. ") = " .. current_value .. " → automation line 1")
    end
  end
  
  -- Update canvas
  if canvas_experiments_canvas then
    canvas_experiments_canvas:update()
  end
  
  -- Show automation editor for visual feedback
  pcall(function()
    renoise.app().window.lower_frame_is_visible = true
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
    
    -- Select first automation to show results
    if processed_count > 0 then
      local automations = pattern_track.automations
      if #automations > 0 then
        song.selected_automation_index = 1
      end
    end
  end)
  
  if processed_count > 0 then
    renoise.app():show_status("Clean & Snap: " .. processed_count .. " parameters snapped to automation line 1")
    print("CLEAN&SNAP: Created automation snapshots for " .. processed_count .. " parameters on device: " .. current_device.display_name)
  else
    renoise.app():show_status("Clean & Snap: No parameters processed")
    print("CLEAN&SNAP: No parameters found for device: " .. current_device.display_name)
  end
end

-- Randomize current mode (Edit A or Edit B) with strength control
function PakettiCanvasExperimentsRandomizeCurrentMode()
  if not current_device or #device_parameters == 0 then
    return
  end
  
  local strength = randomize_strength / 100.0  -- Convert to 0-1 range
  
  if current_edit_mode == "A" then
    -- Randomize Edit A (device parameters)
    
    -- Temporarily disable automation observers to prevent interference
    local observers_were_active = false
    if follow_automation then
      observers_were_active = true
      RemoveParameterObservers()
      print("RANDOMIZE_A: Temporarily disabled automation observers")
    end
    
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
      print("RANDOMIZE_A: Parameter " .. i .. " (" .. param_info.name .. ") " .. current_value .. " → " .. new_value)
    end
    
    -- Re-enable automation observers after a delay if they were active
    if observers_were_active then
      renoise.tool():add_timer(function()
        SetupParameterObservers()
        print("RANDOMIZE_A: Re-enabled automation observers")
      end, 100) -- 100ms delay
    end
    
    renoise.app():show_status("Randomized Edit A: " .. #device_parameters .. " device parameters with " .. randomize_strength .. "% strength")
    
  elseif current_edit_mode == "B" then
    -- Randomize Edit B (stored values only)
    for i, param_info in ipairs(device_parameters) do
      local current_b_value = parameter_values_B[i] or param_info.parameter.value
      local value_range = param_info.value_max - param_info.value_min
      
      -- Generate random value in full range
      local random_value = param_info.value_min + (math.random() * value_range)
      
      -- Apply strength: interpolate between current B value and random value
      local new_value = current_b_value + (random_value - current_b_value) * strength
      
      -- Clamp to valid range
      new_value = math.max(param_info.value_min, math.min(param_info.value_max, new_value))
      
      parameter_values_B[i] = new_value
      print("RANDOMIZE_B: Parameter " .. i .. " (" .. param_info.name .. ") " .. current_b_value .. " → " .. new_value)
    end
    
    renoise.app():show_status("Randomized Edit B: " .. #device_parameters .. " stored B values with " .. randomize_strength .. "% strength")
  end
  
  -- Update canvas
  if canvas_experiments_canvas then
    canvas_experiments_canvas:update()
  end
end

-- Legacy function for compatibility (used by "Randomize Automation" button)
function PakettiCanvasExperimentsRandomizeParameters()
  PakettiCanvasExperimentsRandomizeCurrentMode()
end

-- Helper function to write parameter value to automation
function WriteParameterToAutomation(parameter, value, skip_envelope_selection)
  -- CRITICAL: Only run if dialog is open and automation sync is on
  if not follow_automation or not parameter or not canvas_experiments_dialog or not canvas_experiments_dialog.visible then
    return
  end
  
  local song = renoise.song()
  local current_line = song.selected_line_index
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  
  -- Get or create automation for this parameter
  local pattern_track = song:pattern(current_pattern):track(track_index)
  local automation = pattern_track:find_automation(parameter)
  
  if not automation then
    automation = pattern_track:create_automation(parameter)
  end
  
  if automation then
    local time = current_line
    -- Remove existing point at this time if it exists
    if automation:has_point_at(time) then
      automation:remove_point_at(time)
    end
    -- Normalize value to 0.0-1.0 range for automation
    local normalized_value = (value - parameter.value_min) / (parameter.value_max - parameter.value_min)
    normalized_value = math.max(0.0, math.min(1.0, normalized_value))
    
    -- Add new point
    automation:add_point_at(time, normalized_value)
    
    -- Show automation editor and select this automation for visual feedback
    -- ONLY if dialog is still open AND not during bulk operations (like crossfade)
    if canvas_experiments_dialog and canvas_experiments_dialog.visible and not skip_envelope_selection then
      local success, error_msg = pcall(function()
        local song = renoise.song()
        
        -- FORCE automation frame to be visible and active
        renoise.app().window.lower_frame_is_visible = true
        renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
        
        -- Make sure we're looking at the right track
        song.selected_track_index = track_index
        
        -- CORRECT WAY: Directly set the selected automation parameter (like PakettiEightOneTwenty.lua does)
        song.selected_automation_parameter = parameter
        print("AUTOMATION_SELECT: Selected '" .. parameter.name .. "' parameter")
        
        -- ApplicationWindow doesn't have update() method - automation selection is enough
      end)
      
      if not success then
        print("AUTOMATION_ERROR: Failed to select parameter '" .. (parameter.name or "Unknown") .. "': " .. tostring(error_msg))
      end
    end
    
    -- Removed debug spam for performance during frequent automation writes
  end
end

-- Add snapshot of all device parameters to automation
function PakettiCanvasExperimentsSnapshotToAutomation()
  if not current_device or #device_parameters == 0 then
    renoise.app():show_status("No device parameters available for snapshot")
    return
  end
  
  local song = renoise.song()
  local current_line = song.selected_line_index
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  
  local points_added = 0
  
  for i, param_info in ipairs(device_parameters) do
    local parameter = param_info.parameter
    local value
    
    -- Use crossfaded value if both A and B exist, otherwise use device value
    if parameter_values_A[i] and parameter_values_B[i] then
      local value_a = parameter_values_A[i]
      local value_b = parameter_values_B[i]
      value = value_a + (value_b - value_a) * crossfade_amount
      print("SNAPSHOT: Parameter " .. i .. " (" .. param_info.name .. ") crossfaded A=" .. value_a .. " B=" .. value_b .. " → " .. value)
    else
      value = parameter.value
      print("SNAPSHOT: Parameter " .. i .. " (" .. param_info.name .. ") device value → " .. value)
    end
    
    -- Get or create automation for this parameter
    local automation = pattern_track:find_automation(parameter)
    
    if not automation then
      automation = pattern_track:create_automation(parameter)
    end
    
    if automation then
      local time = current_line
      -- Remove existing point at this time if it exists
      if automation:has_point_at(time) then
        automation:remove_point_at(time)
      end
      -- Normalize value to 0.0-1.0 range for automation
      local normalized_value = (value - parameter.value_min) / (parameter.value_max - parameter.value_min)
      normalized_value = math.max(0.0, math.min(1.0, normalized_value))
      
      -- Add new point
      automation:add_point_at(time, normalized_value)
      points_added = points_added + 1
    end
  end
  
  -- Show automation editor for visual feedback after snapshot
  pcall(function()
    -- Show lower frame (automation editor)
    renoise.app().window.lower_frame_is_visible = true
    -- Switch to track automation view in lower frame
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
    
    -- Select first automation to show snapshot results
    if points_added > 0 then
      local automations = song.selected_pattern_track.automations
      if #automations > 0 then
        song.selected_automation_index = 1  -- Select first automation to show something was created
        print("AUTOMATION_SELECT: Selected first automation for snapshot visual feedback")
        -- Force the automation editor to update
        renoise.app().window:update()
      end
    end
  end)
  
  renoise.app():show_status("Added " .. points_added .. " automation points at line " .. current_line .. " - automation editor updated")
end

-- Store current parameters to Edit A or Edit B
function StoreParametersToEdit(edit_mode)
  if not current_device or #device_parameters == 0 then
    return
  end
  
  local storage = (edit_mode == "A") and parameter_values_A or parameter_values_B
  
  -- Clear existing values
  for k, v in pairs(storage) do
    storage[k] = nil
  end
  
  -- Store current parameter values
  for i, param_info in ipairs(device_parameters) do
    storage[i] = param_info.parameter.value
    -- print("DEBUG: Stored parameter " .. i .. " (" .. param_info.name .. ") = " .. param_info.parameter.value .. " to Edit " .. edit_mode)
  end
  
  local count = 0
  for k, v in pairs(storage) do count = count + 1 end
  -- print("DEBUG: Edit " .. edit_mode .. " now has " .. count .. " stored parameters")
  renoise.app():show_status("Stored current parameters to Edit " .. edit_mode)
  
  -- Update canvas to show new Edit A/B state
  if canvas_experiments_canvas then
    canvas_experiments_canvas:update()
  end
end

-- Load parameters from Edit A or Edit B
function LoadParametersFromEdit(edit_mode)
  if not current_device or #device_parameters == 0 then
    print("LOAD_PARAMETERS: No device or parameters available")
    return
  end
  
  local storage = (edit_mode == "A") and parameter_values_A or parameter_values_B
  
  -- Check if storage has values
  local has_values = false
  local value_count = 0
  for k, v in pairs(storage) do
    has_values = true
    value_count = value_count + 1
  end
  
  if not has_values then
    print("LOAD_PARAMETERS: Edit " .. edit_mode .. " has no stored parameters")
    renoise.app():show_status("Edit " .. edit_mode .. " has no stored parameters")
    return
  end
  
  print("LOAD_PARAMETERS: Loading " .. value_count .. " parameters from Edit " .. edit_mode)
  
  -- Load parameter values
  local loaded_count = 0
  for i, param_info in ipairs(device_parameters) do
    if storage[i] then
      local old_value = param_info.parameter.value
      param_info.parameter.value = storage[i]
      print("LOAD_PARAMETERS: Parameter " .. i .. " (" .. param_info.name .. ") " .. old_value .. " → " .. storage[i])
      loaded_count = loaded_count + 1
    end
  end
  
  print("LOAD_PARAMETERS: Successfully loaded " .. loaded_count .. " parameters from Edit " .. edit_mode)
  
  -- Update canvas
  if canvas_experiments_canvas then
    canvas_experiments_canvas:update()
  end
  
  renoise.app():show_status("Loaded " .. loaded_count .. " parameters from Edit " .. edit_mode)
end

-- Apply crossfade between Edit A and Edit B (IMMEDIATE RESPONSE)
function ApplyCrossfade(amount)
  if not current_device or #device_parameters == 0 then
    return
  end
  
  crossfade_amount = amount
  
  -- Apply crossfade to each parameter - A is device state when B mode started, B is current B values
  for i, param_info in ipairs(device_parameters) do
    if parameter_values_A[i] and parameter_values_B[i] then
      local value_a = parameter_values_A[i]
      local value_b = parameter_values_B[i]
      local crossfaded_value = value_a + (value_b - value_a) * amount
      
      -- Set device parameter value immediately
      param_info.parameter.value = crossfaded_value
      
      -- Write to automation immediately if enabled (but don't select envelope during crossfade)
      if follow_automation then
        WriteParameterToAutomation(param_info.parameter, crossfaded_value, true)  -- Skip envelope selection during crossfade
      end
    end
  end
  
  -- Update canvas IMMEDIATELY for responsive feedback
  if canvas_experiments_canvas then
    canvas_experiments_canvas:update()
  end
end

-- Setup parameter observers for bidirectional communication
function SetupParameterObservers()
  -- Remove existing observers
  RemoveParameterObservers()
  
  if not current_device or #device_parameters == 0 then
    return
  end
  
  for i, param_info in ipairs(device_parameters) do
    local parameter = param_info.parameter
    if parameter.value_observable then
              local observer = function()
          -- CRITICAL: Only run if dialog is still open
          if not canvas_experiments_dialog or not canvas_experiments_dialog.visible then
            return
          end
          
          -- CRITICAL CHECK: Show if parameter being drawn is still getting automation updates
          if parameter_being_drawn == i then
            print("🔥 CRITICAL: Parameter " .. i .. " (" .. param_info.name .. ") got automation update during drawing!")
          end
          
          -- ALWAYS update canvas when parameter changes externally (automation playback)
          -- This ensures canvas follows automation even when automation sync is OFF
          if canvas_experiments_canvas then
            canvas_experiments_canvas:update()
          end
        end
      parameter.value_observable:add_notifier(observer)
      device_parameter_observers[parameter] = observer
    end
  end
end

-- Remove parameter observers
function RemoveParameterObservers()
  for parameter, observer in pairs(device_parameter_observers) do
    pcall(function()
      if parameter and parameter.value_observable and parameter.value_observable:has_notifier(observer) then
        parameter.value_observable:remove_notifier(observer)
      end
    end)
  end
  
  -- Clear the table completely
  device_parameter_observers = {}
end

-- Randomize Automation: Randomizes current Edit A/B and writes snapshot to automation
function PakettiCanvasExperimentsRandomizeAutomation()
  if not current_device or #device_parameters == 0 then
    renoise.app():show_status("No device parameters available for randomize automation")
    return
  end
  
  -- First randomize the parameters (this updates current values)
  PakettiCanvasExperimentsRandomizeParameters()
  
  -- Store the randomized values to current edit mode
  StoreParametersToEdit(current_edit_mode)
  
  -- Write snapshot to automation
  PakettiCanvasExperimentsSnapshotToAutomation()
  
  renoise.app():show_status("Randomized Edit " .. current_edit_mode .. " and wrote to automation at line " .. renoise.song().selected_line_index)
end

-- Setup canvas update timer for periodic refresh
function SetupCanvasUpdateTimer()
  if canvas_update_timer then
    renoise.tool():remove_timer(canvas_update_timer)
  end
  
  canvas_update_timer = function()
    -- CRITICAL: Double-check dialog is still open and valid
    if not canvas_experiments_canvas or not canvas_experiments_dialog or not canvas_experiments_dialog.visible then
      -- Dialog is closed - remove this timer immediately
      RemoveCanvasUpdateTimer()
      return
    end
    
    -- Only update canvas if no mouse interaction is happening (automation reading only)
    if not mouse_is_down then
      canvas_experiments_canvas:update()
    end
    -- Removed timer debug spam for cleaner console output
  end
  
  -- Update every 100ms for smooth automation visualization
  renoise.tool():add_timer(canvas_update_timer, 100)
end

-- Remove canvas update timer
function RemoveCanvasUpdateTimer()
  if canvas_update_timer then
    pcall(function()
      renoise.tool():remove_timer(canvas_update_timer)
    end)
    canvas_update_timer = nil
  end
end

-- EMERGENCY: Force cleanup any lingering state on tool load
if canvas_experiments_dialog or device_parameter_observers or canvas_update_timer then
  PakettiCanvasExperimentsCleanup()
end

-- EMERGENCY RESET: Function to force-reset everything if user gets stuck
function PakettiCanvasExperimentsEmergencyReset()
  print("EMERGENCY_RESET: Force resetting all Canvas Dialog state")
  
  -- Force close dialog
  if canvas_experiments_dialog then
    pcall(function() canvas_experiments_dialog:close() end)
  end
  
  -- Aggressive cleanup
  PakettiCanvasExperimentsCleanup()
  
  -- Clear any remaining global state
  pcall(function()
    -- Reset any potential stuck automation state
    follow_automation = false
    automation_reading_enabled = true
    parameter_being_drawn = nil
    
    -- Clear all observers aggressively
    device_parameter_observers = {}
    device_selection_notifier = nil
    canvas_update_timer = nil
  end)
  
  renoise.app():show_status("EMERGENCY RESET: Canvas Dialog state cleared")
  print("EMERGENCY_RESET: Complete")
end

renoise.tool():add_menu_entry {name = "Main Menu:Tools:Paketti Selected Device Parameter Editor",invoke = PakettiCanvasExperimentsInit}
renoise.tool():add_keybinding {name = "Global:Paketti:Paketti Selected Device Parameter Editor",invoke = PakettiCanvasExperimentsInit}
