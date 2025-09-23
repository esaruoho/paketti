-- PakettiHyperEdit.lua
-- 8-Row Interchangeable Stepsequencer with individual device/parameter selection
-- Each row has its own canvas with device and parameter dropdowns

local vb = renoise.ViewBuilder()

local row_devices = {}   -- [row] = selected device
local row_parameters = {} -- [row] = selected parameter
local device_lists = {}  -- [row] = available devices for that row
local parameter_lists = {} -- [row] = available parameters for selected device
-- Observers
local track_change_notifier = nil
local device_change_notifier = nil


-- Constants
local NUM_ROWS = 8
MAX_STEPS = 256  -- Global, support up to 256 steps

-- Dialog state
local hyperedit_dialog = nil
local dialog_vb = nil    -- Store ViewBuilder instance
local row_canvases = {}  -- [row] = canvas

-- Playhead variables (like PakettiGater)
local playhead_timer_fn = nil
local playing_observer_fn = nil
local playhead_step_indices = {}  -- [row] = current_step
local playhead_color = nil

-- Row state variables (must be declared early for playhead functions)
local row_steps = {}  -- [row] = step count for this row (individual per row)

-- Track color capture
local capture_track_color = false  -- Checkbox state

-- Get current track color with blending
function PakettiHyperEditGetTrackColor()
  local song = renoise.song()
  if not song then return {120, 40, 160} end  -- Default purple
  
  local track = song.selected_track
  if not track then return {120, 40, 160} end
  
  -- Get track color (RGB 0-255) and blend amount (0-100)
  local track_color = track.color  -- RGB array
  local color_blend = track.color_blend or 50  -- Default 50% blend
  
  print("DEBUG: Raw track color: " .. track_color[1] .. ", " .. track_color[2] .. ", " .. track_color[3])
  print("DEBUG: Track color blend: " .. color_blend .. "%")
  
  -- When blend is 0%, it means "no blending" in Renoise - use raw color with boost
  if color_blend == 0 then
    print("DEBUG: 0% blend - using raw track color with brightness boost")
    local boosted_color = {
      math.max(track_color[1], 100),  -- Ensure minimum 100 for visibility
      math.max(track_color[2], 100),
      math.max(track_color[3], 100)
    }
    print("DEBUG: 0% blend result: " .. boosted_color[1] .. ", " .. boosted_color[2] .. ", " .. boosted_color[3])
    return boosted_color
  end
  
  -- For non-zero blend, use normal blending
  local min_brightness = 80  -- Minimum component value for visibility
  local boosted_color = {
    math.max(track_color[1], min_brightness),
    math.max(track_color[2], min_brightness),
    math.max(track_color[3], min_brightness)
  }
  
  -- Use actual blend percentage (don't force minimum)
  local effective_blend = color_blend / 100.0
  
  -- Apply blending with darker background for contrast
  local background = {30, 30, 30}  -- Slightly lighter background for better contrast
  
  local blended_color = {
    math.floor(boosted_color[1] * effective_blend + background[1] * (1 - effective_blend)),
    math.floor(boosted_color[2] * effective_blend + background[2] * (1 - effective_blend)),
    math.floor(boosted_color[3] * effective_blend + background[3] * (1 - effective_blend))
  }
  
  print("DEBUG: Boosted color: " .. boosted_color[1] .. ", " .. boosted_color[2] .. ", " .. boosted_color[3])
  print("DEBUG: Final blended color: " .. blended_color[1] .. ", " .. blended_color[2] .. ", " .. blended_color[3])
  
  return blended_color
end

-- Update colors based on capture track color setting
function PakettiHyperEditUpdateColors()
  print("DEBUG: PakettiHyperEditUpdateColors() started, capture_track_color = " .. tostring(capture_track_color))
  
  if capture_track_color then
    print("DEBUG: Getting track color...")
    local track_color = PakettiHyperEditGetTrackColor()
    print("DEBUG: Got track color: " .. track_color[1] .. ", " .. track_color[2] .. ", " .. track_color[3])
    
    COLOR_ACTIVE_STEP = {track_color[1], track_color[2], track_color[3], 255}
    print("DEBUG: Set COLOR_ACTIVE_STEP to: " .. COLOR_ACTIVE_STEP[1] .. ", " .. COLOR_ACTIVE_STEP[2] .. ", " .. COLOR_ACTIVE_STEP[3] .. ", " .. COLOR_ACTIVE_STEP[4])
  else
    COLOR_ACTIVE_STEP = {120, 40, 160, 255}  -- Default purple
    print("DEBUG: Set COLOR_ACTIVE_STEP to default purple: " .. COLOR_ACTIVE_STEP[1] .. ", " .. COLOR_ACTIVE_STEP[2] .. ", " .. COLOR_ACTIVE_STEP[3] .. ", " .. COLOR_ACTIVE_STEP[4])
  end
  
  -- Update playhead color too
  print("DEBUG: Updating playhead color...")
  playhead_color = PakettiHyperEditResolvePlayheadColor()
  if playhead_color then
    print("DEBUG: Set playhead_color to: " .. playhead_color[1] .. ", " .. playhead_color[2] .. ", " .. playhead_color[3])
  else
    print("DEBUG: Set playhead_color to nil (no playhead)")
  end
  
  -- Update all canvases
  print("DEBUG: Updating " .. NUM_ROWS .. " canvases...")
  local updated_count = 0
  for row = 1, NUM_ROWS do
    if row_canvases[row] then
      row_canvases[row]:update()
      updated_count = updated_count + 1
    end
  end
  print("DEBUG: Updated " .. updated_count .. " canvases out of " .. NUM_ROWS)
  print("DEBUG: PakettiHyperEditUpdateColors() completed")
end

-- Playhead color resolution function
function PakettiHyperEditResolvePlayheadColor()
  print("DEBUG: PakettiHyperEditResolvePlayheadColor() called, capture_track_color = " .. tostring(capture_track_color))
  
  -- If track color capture is enabled, use track color for playhead too
  if capture_track_color then
    print("DEBUG: Using track color for playhead...")
    local track_color = PakettiHyperEditGetTrackColor()
    -- Make playhead brighter than active steps for visibility
    local playhead_result = {
      math.min(255, track_color[1] + 60),
      math.min(255, track_color[2] + 60), 
      math.min(255, track_color[3] + 60)
    }
    print("DEBUG: Playhead color result: " .. playhead_result[1] .. ", " .. playhead_result[2] .. ", " .. playhead_result[3])
    return playhead_result
  end
  
  -- Otherwise use preferences
  print("DEBUG: Using preference-based playhead color...")
  local choice = (preferences and preferences.PakettiGrooveboxPlayheadColor and preferences.PakettiGrooveboxPlayheadColor.value) or 2
  print("DEBUG: Playhead color preference choice: " .. choice)
  if choice == 1 then return nil end -- None
  if choice == 2 then return {255,128,0} end -- Bright Orange
  if choice == 3 then return {64,0,96} end -- Deeper Purple
  if choice == 4 then return {0,0,0} end -- Black
  if choice == 5 then return {255,255,255} end -- White
  if choice == 6 then return {64,64,64} end -- Dark Grey
  return {255,128,0}
end

-- Playhead update functions (like PakettiGater)
function PakettiHyperEditUpdatePlayheadHighlights()
  if not hyperedit_dialog or not hyperedit_dialog.visible then return end
  
  local song = renoise.song()
  if not song then return end
  
  local current_line = song.selected_line_index
  if song.transport.playing then
    local pos = song.transport.playback_pos
    if pos and pos.line then current_line = pos.line end
  end
  if not current_line then return end
  
  -- Update playhead for each row based on its individual step count
  local needs_update = false
  for row = 1, NUM_ROWS do
    local row_step_count = row_steps[row] or 16
    local step_index = ((current_line - 1) % row_step_count) + 1
    
    if playhead_step_indices[row] ~= step_index then
      playhead_step_indices[row] = step_index
      needs_update = true
      
      -- Update the canvas for this row
      if row_canvases[row] then
        row_canvases[row]:update()
      end
    end
  end
end

function PakettiHyperEditSetupPlayhead()
  local song = renoise.song()
  if not song then return end
  
  playhead_color = PakettiHyperEditResolvePlayheadColor()
  
  if not playhead_timer_fn then
    playhead_timer_fn = function()
      PakettiHyperEditUpdatePlayheadHighlights()
    end
    renoise.tool():add_timer(playhead_timer_fn, 40)  -- 25 FPS
  end
  
  if not playing_observer_fn then
    playing_observer_fn = function()
      playhead_color = PakettiHyperEditResolvePlayheadColor()
      PakettiHyperEditUpdatePlayheadHighlights()
    end
    if song.transport.playing_observable and not song.transport.playing_observable:has_notifier(playing_observer_fn) then
      song.transport.playing_observable:add_notifier(playing_observer_fn)
    end
  end
end

function PakettiHyperEditCleanupPlayhead()
  if playhead_timer_fn then
    if renoise.tool():has_timer(playhead_timer_fn) then
      renoise.tool():remove_timer(playhead_timer_fn)
    end
    playhead_timer_fn = nil
  end
  
  local song = renoise.song()
  if song and playing_observer_fn then
    pcall(function()
      if song.transport.playing_observable and song.transport.playing_observable:has_notifier(playing_observer_fn) then
        song.transport.playing_observable:remove_notifier(playing_observer_fn)
      end
    end)
    playing_observer_fn = nil
  end
  
  playhead_step_indices = {}
end

-- Detect shortest repeating pattern in automation points
function PakettiHyperEditDetectPatternLength(automation_points)
  if not automation_points or #automation_points == 0 then
    return 16  -- Default
  end
  
  -- Convert points to a step/value map for easier analysis
  local step_values = {}
  local max_step = 0
  
  for _, point in ipairs(automation_points) do
    local step = point.time
    local value = point.value
    if step >= 1 and step <= 256 then  -- Only consider first 256 steps
      step_values[step] = value
      if step > max_step then
        max_step = step
      end
    end
  end
  
  if max_step <= 1 then
    return 16  -- Not enough data, default to 16
  end
  
  -- Test different pattern lengths starting from shortest
  for pattern_length = 1, 256 do
    local is_repeating = true
    
    -- Check if this pattern length creates a repeating cycle
    for test_step = 1, max_step do
      local base_step = ((test_step - 1) % pattern_length) + 1
      local base_value = step_values[base_step]
      local current_value = step_values[test_step]
      
      -- If both steps have values, they must match for pattern to be valid
      if base_value and current_value then
        -- Allow small tolerance for floating point comparison
        if math.abs(base_value - current_value) > 0.001 then
          is_repeating = false
          break
        end
      elseif base_value or current_value then
        -- One has a value, the other doesn't - not a match
        is_repeating = false
        break
      end
    end
    
    if is_repeating then
      print("DEBUG: Detected repeating pattern of " .. pattern_length .. " steps (max step: " .. max_step .. ")")
      return pattern_length
    end
  end
  
  -- No repeating pattern found, use max step count or default
  if max_step <= 16 then
    return 16
  elseif max_step <= 32 then
    return 32
  elseif max_step <= 48 then
    return 48
  elseif max_step <= 64 then
    return 64
  elseif max_step <= 96 then
    return 96
  elseif max_step <= 112 then
    return 112
  elseif max_step <= 128 then
    return 128
  elseif max_step <= 192 then
    return 192
  else
    return 256
  end
end

-- Set all steps in row to a specific value
function PakettiHyperEditSetAllStepsToValue(row, value)
  print("DEBUG: PakettiHyperEditSetAllStepsToValue called - row: " .. row .. ", value: " .. value)
  
  if not step_data[row] then 
    print("DEBUG: step_data[" .. row .. "] does not exist, initializing...")
    step_data[row] = {}
    step_active[row] = {}
  end
  
  if not row_parameters[row] then 
    renoise.app():show_status("HyperEdit Row " .. row .. ": Select parameter first")
    print("DEBUG: No parameter selected for row " .. row)
    return 
  end
  
  local row_step_count = row_steps[row] or 16
  print("DEBUG: Setting " .. row_step_count .. " steps to value " .. value .. " for row " .. row)
  
  -- Set all steps to the specified value
  for step = 1, row_step_count do
    step_active[row][step] = true
    step_data[row][step] = value
  end
  
  print("DEBUG: Set " .. row_step_count .. " steps, now updating canvas...")
  
  -- Redraw canvas
  if row_canvases[row] then
    row_canvases[row]:update()
    print("DEBUG: Canvas updated for row " .. row)
  else
    print("DEBUG: No canvas found for row " .. row)
  end
  
  -- Apply to automation immediately
  print("DEBUG: Applying to automation...")
  PakettiHyperEditWriteAutomationPattern(row)
  
  renoise.app():show_status("HyperEdit Row " .. row .. ": Set all " .. row_step_count .. " steps to " .. value)
end

-- Change row step count and update UI
function PakettiHyperEditChangeRowStepCount(row, new_count)
  row_steps[row] = new_count
  
  -- Update the UI valuebox
  if dialog_vb and dialog_vb.views["steps_" .. row] then
    dialog_vb.views["steps_" .. row].value = new_count
  end
  
  -- Initialize new steps if needed
  if not step_data[row] then
    step_data[row] = {}
    step_active[row] = {}
  end
  
  -- Clear existing steps beyond new count
  for step = new_count + 1, MAX_STEPS do
    step_active[row][step] = false
    step_data[row][step] = 0.0
  end
  
  -- Redraw canvas with new step count
  if row_canvases[row] then
    row_canvases[row]:update()
  end
  
  renoise.app():show_status("HyperEdit Row " .. row .. ": Step count set to " .. new_count)
end

-- Fill row with pattern every N steps (like PakettiSliceEffectStepSequencer)
function PakettiHyperEditFillRowEveryN(row, interval)
  if not row_parameters[row] then 
    renoise.app():show_status("HyperEdit Row " .. row .. ": Select parameter first")
    return 
  end
  
  local row_step_count = row_steps[row] or 16
  
  -- Clear all steps first
  for step = 1, MAX_STEPS do
    if step_active[row] then
      step_active[row][step] = false
    end
    if step_data[row] then
      step_data[row][step] = 0.5  -- Default center value
    end
  end
  
  -- Initialize arrays if needed
  if not step_active[row] then step_active[row] = {} end
  if not step_data[row] then step_data[row] = {} end
  
  -- Fill every N steps (starting from step 1, so 1,1+N,1+2N...)
  for step = 1, row_step_count, interval do
    if step <= MAX_STEPS then
      step_active[row][step] = true
      step_data[row][step] = 0.5  -- Default center value
    end
  end
  
  -- Update canvas and write pattern
  if row_canvases[row] then
    row_canvases[row]:update()
  end
  
  PakettiHyperEditWriteAutomationPattern(row)
  
  renoise.app():show_status(string.format("HyperEdit Row %d: Filled every %d steps (%d total steps)", row, interval, row_step_count))
end



-- Stepsequencer state (MAX_STEPS already defined above as global)
NUM_ROWS = 8  -- Global as per project rules
step_data = {}  -- [row][step] = value (0.0 to 1.0) - Global 
step_active = {}  -- [row][step] = boolean - Global
local loop_length = 16  -- Loop repetition

-- Canvas dimensions per row - taller as requested
local canvas_width = 600
local canvas_height_per_row = 60  -- 2x taller (was 40)
local content_margin = 2

-- Mouse state
local mouse_is_down = false
local current_row_drawing = 0

-- Colors for visualization (GLOBAL so PakettiHyperEditUpdateColors can modify them)
COLOR_ACTIVE_STEP = {120, 40, 160, 255}     -- Purple for active steps (will be updated by track color capture)
COLOR_INACTIVE_STEP = {40, 40, 40, 255}     -- Dark gray for inactive steps  
COLOR_GRID = {80, 80, 80, 255}              -- Grid lines
COLOR_BACKGROUND = {20, 20, 20, 255}        -- Dark background

-- Initialize step data for all rows
function PakettiHyperEditInitStepData()
  step_data = {}
  step_active = {}
  row_steps = {}
  
  for row = 1, NUM_ROWS do
    step_data[row] = {}
    step_active[row] = {}
    row_steps[row] = 16  -- Default 16 steps per row
    for step = 1, MAX_STEPS do  -- Initialize for max steps
      step_data[row][step] = 0.5  -- Default to middle value
      step_active[row][step] = false  -- Default to inactive
    end
  end
end

-- Get available devices from current track (skip Track Vol/Pan)
function PakettiHyperEditGetDevices()
  local song = renoise.song()
  if not song then return {} end
  
  local track = song.selected_track
  if not track then return {} end
  
  local devices = {}
  
  -- Skip the first device (Track Vol/Pan) and start with device 2
  for i = 2, #track.devices do
    local device = track.devices[i]
    table.insert(devices, {
      index = i,
      device = device,
      name = device.display_name or ("Device " .. i)
    })
  end
  
  return devices
end

-- Get automatable parameters from device
function PakettiHyperEditGetParameters(device)
  if not device then return {} end
  
  local params = {}
  
  for i = 1, #device.parameters do
    local param = device.parameters[i]
    if param.is_automatable then
      table.insert(params, {
        index = i,
        parameter = param,
        name = param.name,
        value_min = param.value_min,
        value_max = param.value_max,
        value_default = param.value_default
      })
    end
  end
  
  return params
end

-- Update all device lists
function PakettiHyperEditUpdateAllDeviceLists()
  if not hyperedit_dialog or not hyperedit_dialog.visible then
    return
  end
  
  local devices = PakettiHyperEditGetDevices()
  local device_names = {}
  
  for i, device_info in ipairs(devices) do
    table.insert(device_names, device_info.name)
  end
  
  if #device_names == 0 then
    device_names = {"No devices available"}
  end
  
  print("DEBUG: PakettiHyperEditUpdateAllDeviceLists called with " .. #devices .. " devices")
  
  -- Update all rows
  for row = 1, NUM_ROWS do
    device_lists[row] = devices
    
    local device_popup = dialog_vb and dialog_vb.views["device_popup_" .. row]
    if device_popup then
      -- Save current selection BEFORE updating items
      local current_value = device_popup.value
      local current_device_name = nil
      
      if row_devices[row] then
        current_device_name = row_devices[row].display_name
        print("DEBUG: Row " .. row .. " currently has device: " .. current_device_name)
      end
      
      print("DEBUG: Updating device popup for row " .. row .. " with " .. #device_names .. " items")
      device_popup.items = device_names
      
      -- Try to maintain current selection by finding the same device in the new list
      if current_device_name and #devices > 0 then
        local found_current = false
        
        for i, device_info in ipairs(devices) do
          if device_info.device.display_name == current_device_name then
            device_popup.value = i
            found_current = true
            print("DEBUG: Successfully maintained selection for row " .. row .. " - device '" .. current_device_name .. "' at index " .. i)
            break
          end
        end
        
        if not found_current then
          print("DEBUG: Could not find device '" .. current_device_name .. "' in new list for row " .. row)
          -- Device was removed - let it default to index 1 but don't call SelectDevice
          if #devices > 0 then
            device_popup.value = 1
          end
        end
      else
        -- No current device - set to first available
        if #devices > 0 then
          device_popup.value = 1
          PakettiHyperEditSelectDevice(row, 1)
        end
      end
    else
      print("ERROR: Could not find device_popup_" .. row)
    end
  end
  
  renoise.app():show_status("HyperEdit: Updated device lists (" .. #devices .. " devices)")
end

-- Select device for specific row
function PakettiHyperEditSelectDevice(row, device_index)
  print("DEBUG: PakettiHyperEditSelectDevice called for row " .. row .. " with device_index " .. device_index)
  
  if not device_lists[row] or device_index <= 0 or device_index > #device_lists[row] then
    print("DEBUG: Invalid device selection for row " .. row .. " - clearing parameters")
    row_devices[row] = nil
    row_parameters[row] = nil
    parameter_lists[row] = {}
    
    -- Update parameter dropdown to show no parameters available
    local param_popup = dialog_vb and dialog_vb.views["parameter_popup_" .. row]
    if param_popup then
      param_popup.items = {"No device selected"}
      param_popup.value = 1
    end
    return
  end
  
  local device_info = device_lists[row][device_index]
  row_devices[row] = device_info.device
  
  print("DEBUG: Selected device for row " .. row .. ": " .. device_info.name)
  
  -- Update parameter list for this row
  parameter_lists[row] = PakettiHyperEditGetParameters(row_devices[row])
  
  print("DEBUG: Found " .. #parameter_lists[row] .. " automatable parameters for row " .. row)
  
  local param_names = {}
  for i, param_info in ipairs(parameter_lists[row]) do
    table.insert(param_names, param_info.name)
    print("DEBUG: Parameter " .. i .. " for row " .. row .. ": " .. param_info.name)
  end
  
  if #param_names == 0 then
    param_names = {"No automatable parameters"}
  end
  
  -- Update parameter dropdown for this row
  local param_popup = dialog_vb and dialog_vb.views["parameter_popup_" .. row]
  if param_popup then
    print("DEBUG: Updating parameter popup for row " .. row .. " with " .. #param_names .. " items")
    param_popup.items = param_names
    param_popup.value = 1
    if #parameter_lists[row] > 0 then
      PakettiHyperEditSelectParameter(row, 1)
    end
  else
    print("ERROR: Could not find parameter_popup_" .. row .. " - dialog_vb:" .. tostring(dialog_vb ~= nil))
  end
  
  renoise.app():show_status("HyperEdit Row " .. row .. ": Selected device - " .. device_info.name .. " (" .. #param_names .. " parameters)")
end

-- Select parameter for specific row
function PakettiHyperEditSelectParameter(row, param_index)
  if not parameter_lists[row] or param_index <= 0 or param_index > #parameter_lists[row] then
    row_parameters[row] = nil
    return
  end
  
  local param_info = parameter_lists[row][param_index]
  row_parameters[row] = param_info
  
  -- Auto-read automation when parameter is selected
  PakettiHyperEditAutoReadAutomation(row)
  
  renoise.app():show_status("HyperEdit Row " .. row .. ": Selected parameter - " .. param_info.name)
end

-- Handle mouse input on specific row canvas
function PakettiHyperEditHandleRowMouse(row)
  return function(ev)
    local w = canvas_width
    local h = canvas_height_per_row
    
    if ev.type == "exit" then
      return
    end
    
    local mouse_in_canvas = ev.position.x >= 0 and ev.position.x < w and 
                           ev.position.y >= 0 and ev.position.y < h
    
    if not mouse_in_canvas then
      if ev.type == "up" then
        mouse_is_down = false
        current_row_drawing = 0
      end
      return
    end
    
    local x = ev.position.x
    local y = ev.position.y
    
    if ev.type == "down" then
      mouse_is_down = true
      current_row_drawing = row
      PakettiHyperEditHandleRowClick(row, x, y)
    elseif ev.type == "up" then
      mouse_is_down = false
      current_row_drawing = 0
    elseif ev.type == "move" and mouse_is_down and current_row_drawing == row then
      PakettiHyperEditHandleRowClick(row, x, y)
    elseif ev.type == "double" then
      -- Double-click to center pitchbend parameters
      if row_parameters[row] and row_parameters[row].parameter then
        local param_name = row_parameters[row].name:lower()
        if param_name:find("pitch") or param_name:find("bend") then
          -- Calculate which step was double-clicked
          local content_margin = 3
          local content_x = content_margin
          local content_width = canvas_width - (content_margin * 2)
          local row_step_count = row_steps[row] or 16
          local step_width = content_width / row_step_count
          local step = math.floor((x - content_x) / step_width) + 1
          step = math.max(1, math.min(row_step_count, step))
          
          -- Set to center value (0.5)
          if not step_active[row] then step_active[row] = {} end
          if not step_data[row] then step_data[row] = {} end
          
          step_active[row][step] = true
          step_data[row][step] = 0.5  -- Center value
          
          -- Apply immediately
          PakettiHyperEditApplyStep(row, step)
          
          -- Update canvas
          if row_canvases[row] then
            row_canvases[row]:update()
          end
          
          renoise.app():show_status("HyperEdit Row " .. row .. ": Centered pitchbend at step " .. step)
        end
      end
    end
  end
end

-- Handle click on specific row
function PakettiHyperEditHandleRowClick(row, x, y)
  if not row_parameters[row] then
    renoise.app():show_status("HyperEdit Row " .. row .. ": Select device and parameter first")
    return
  end
  
  -- Content area with small margins (exactly like PakettiCanvasExperiments)
  local content_margin = 3
  local content_x = content_margin
  local content_y = content_margin
  local content_width = canvas_width - (content_margin * 2)
  local content_height = canvas_height_per_row - (content_margin * 2)
  
  -- Check if click is within content area (like PakettiCanvasExperiments)
  local mouse_in_content = x >= content_x and x < (content_x + content_width) and 
                          y >= content_y and y < (content_y + content_height)
  
  if not mouse_in_content then
    return -- Ignore clicks outside content area
  end
  
  -- Calculate step from X position using ROW-SPECIFIC step count (like PakettiSliceEffectStepSequencer)
  local row_step_count = row_steps[row] or 16
  local step_width = content_width / row_step_count
  local step = math.floor((x - content_x) / step_width) + 1
  step = math.max(1, math.min(row_step_count, step))
  
  -- Always activate the step (no toggling - just set values like PakettiCanvasExperiments)
  step_active[row][step] = true
  
  -- Set step value from Y position using content area (like PakettiCanvasExperiments)
  local normalized_y = 1.0 - ((y - content_y) / content_height)
  normalized_y = math.max(0.0, math.min(1.0, normalized_y))
  step_data[row][step] = normalized_y
  
  -- Apply immediately to device parameter or pattern
  PakettiHyperEditApplyStep(row, step)
  
  -- Update canvas
  if row_canvases[row] then
    row_canvases[row]:update()
  end
  
  -- Show parameter info (like PakettiCanvasExperiments)
  if row_parameters[row] and row_parameters[row].parameter then
    local param_name = row_parameters[row].name
    local param_min = row_parameters[row].parameter.value_min
    local param_max = row_parameters[row].parameter.value_max
    local actual_value = param_min + (normalized_y * (param_max - param_min))
    renoise.app():show_status(string.format("HyperEdit Row %d: %s Step %d = %.3f", row, param_name, step, actual_value))
  end
end

-- Apply step change immediately
function PakettiHyperEditApplyStep(row, step)
  if not row_parameters[row] then return end
  
  local param_info = row_parameters[row]
  local parameter = param_info.parameter
  
  if step_active[row][step] then
    -- Convert normalized value to parameter range
    local param_value = param_info.value_min + (step_data[row][step] * (param_info.value_max - param_info.value_min))
    
    -- Check if this is a volume-related parameter
    local is_volume = param_info.name:lower():find("volume") ~= nil
    
    if is_volume then
      -- Write to pattern editor volume column
      PakettiHyperEditWriteVolumeToPattern(row, step, step_data[row][step])
    else
      -- Write to automation immediately
      PakettiHyperEditWriteAutomationPoint(parameter, step, param_value)
    end
  end
end

-- Write volume to pattern editor
function PakettiHyperEditWriteVolumeToPattern(row, step, normalized_value)
  local song = renoise.song()
  if not song then return end
  
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.selected_track
  
  -- Ensure enough note columns
  if track.visible_note_columns < row then
    track.visible_note_columns = row
  end
  
  -- Calculate which pattern line this step represents
  local current_line = song.selected_line_index
  local target_line = current_line + (step - 1)
  
  if target_line <= pattern.number_of_lines then
    local pattern_line = pattern:track(track_index):line(target_line)
    local note_col = pattern_line:note_column(row)
    
    -- Convert to volume (0-127) and then to hex
    local volume_value = math.floor(normalized_value * 127)
    volume_value = math.max(0, math.min(127, volume_value))
    note_col.volume_string = string.format("%02X", volume_value)
  end
end

-- Write automation pattern (repeating across full pattern length)
function PakettiHyperEditWriteAutomationPattern(row)
  if not row_parameters[row] then return end
  
  local song = renoise.song()
  if not song then return end
  
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  local pattern_length = song:pattern(current_pattern).number_of_lines
  local parameter = row_parameters[row].parameter
  
  -- Get or create automation
  local automation = pattern_track:find_automation(parameter)
  if not automation then
    automation = pattern_track:create_automation(parameter)
  end
  
  if automation then
    -- Clear existing automation
    automation:clear()
    
    -- Set to POINTS mode as requested
    automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_POINTS
    
    local row_step_count = row_steps[row] or 16
    local points_written = 0
    
    -- Write repeating pattern across entire pattern length
    for line = 1, pattern_length do
      local step_in_pattern = ((line - 1) % row_step_count) + 1
      
      if step_active[row] and step_active[row][step_in_pattern] then
        local step_value = step_data[row][step_in_pattern] or 0.5
        
        -- Convert to parameter range
        local param_value = row_parameters[row].value_min + 
                           (step_value * (row_parameters[row].value_max - row_parameters[row].value_min))
        
        -- Normalize for automation (0.0-1.0)
        local normalized_value = (param_value - parameter.value_min) / (parameter.value_max - parameter.value_min)
        normalized_value = math.max(0.0, math.min(1.0, normalized_value))
        
        automation:add_point_at(line, normalized_value)
        points_written = points_written + 1
      end
    end
    
    print("DEBUG: Wrote " .. points_written .. " automation points for " .. row_parameters[row].name .. " (Row " .. row .. ") in POINTS mode")
  end
end

-- Apply step change immediately with full pattern automation
function PakettiHyperEditApplyStep(row, step)
  if not row_parameters[row] then return end
  
  -- Write the entire repeating automation pattern
  PakettiHyperEditWriteAutomationPattern(row)
  
  -- Switch automation view to show this parameter's envelope (like PakettiCanvasExperiments)
  PakettiHyperEditSwitchToAutomationView(row)
end

-- Switch automation view to show the parameter being edited (like PakettiCanvasExperiments)
function PakettiHyperEditSwitchToAutomationView(row)
  if not row_parameters[row] then return end
  
  local parameter = row_parameters[row].parameter
  if not parameter then return end
  
  -- Switch to automation view and select this parameter's envelope
  local success, error_msg = pcall(function()
    local song = renoise.song()
    
    -- Show automation frame and make it active (like PakettiCanvasExperiments)
    renoise.app().window.lower_frame_is_visible = true
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
    
    -- Select this parameter's automation envelope
    song.selected_automation_parameter = parameter
    print("DEBUG: Switched automation view to " .. parameter.name .. " (Row " .. row .. ")")
  end)
  
  if not success then
    print("DEBUG: Failed to switch automation view: " .. tostring(error_msg))
  end
end

-- Auto-read automation when parameter is selected (silent, automatic)
function PakettiHyperEditAutoReadAutomation(row)
  if not row_parameters[row] then return end
  
  local song = renoise.song()
  if not song then return end
  
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  local parameter = row_parameters[row].parameter
  
  -- Find existing automation
  local automation = pattern_track:find_automation(parameter)
  if not automation then
    -- No automation exists - clear step data and leave empty for user to draw
    for step = 1, MAX_STEPS do
      step_active[row][step] = false
      step_data[row][step] = 0.5
    end
    
    -- Update canvas
    if row_canvases[row] then
      row_canvases[row]:update()
    end
    
    print("DEBUG: No automation found for " .. row_parameters[row].name .. " - cleared step data")
    return
  end
  
  -- IMPORTANT: Set automation to POINTS mode first
  automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_POINTS
  
  -- SMART PATTERN DETECTION: Find shortest repeating cycle
  local detected_step_count = PakettiHyperEditDetectPatternLength(automation.points)
  
  -- Set the row step count based on detected pattern
  row_steps[row] = detected_step_count
  print("DEBUG: Smart-detected " .. detected_step_count .. "-step repeating pattern for row " .. row)
  
  -- Update the UI step count valuebox
  if dialog_vb and dialog_vb.views["steps_" .. row] then
    dialog_vb.views["steps_" .. row].value = detected_step_count
  end
  
  -- Clear existing step data
  for step = 1, MAX_STEPS do
    step_active[row][step] = false
    step_data[row][step] = 0.5
  end
  
  local points_read = 0
  
  -- Read automation points and consolidate to detected pattern length
  for _, point in ipairs(automation.points) do
    local step = point.time
    local value = point.value  -- Already 0.0-1.0
    
    if step >= 1 and step <= MAX_STEPS then
      -- Map to the detected pattern length (consolidate repeating patterns)
      local consolidated_step = ((step - 1) % detected_step_count) + 1
      step_active[row][consolidated_step] = true
      step_data[row][consolidated_step] = value
      points_read = points_read + 1
      
      if consolidated_step ~= step then
        print("DEBUG: Consolidated step " .. step .. " → " .. consolidated_step .. " (pattern length: " .. detected_step_count .. ")")
      end
    end
  end
  
  -- Update canvas with detected step count
  if row_canvases[row] then
    row_canvases[row]:update()
  end
  
  if points_read > 0 then
    print("DEBUG: Auto-read " .. points_read .. " automation points for " .. row_parameters[row].name .. " (Row " .. row .. ") and set to POINTS mode with " .. detected_step_count .. "-step pattern")
  else
    print("DEBUG: Found automation for " .. row_parameters[row].name .. " but no points in detected range")
  end
end

-- Scan track for existing automation and populate rows
function PakettiHyperEditPopulateFromExistingAutomation()
  print("DEBUG: === Starting PakettiHyperEditPopulateFromExistingAutomation ===")
  
  local song = renoise.song()
  if not song then 
    print("DEBUG: No song available")
    return 
  end
  
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  
  print("DEBUG: Scanning pattern " .. current_pattern .. ", track " .. track_index)
  
  -- Get all existing automation envelopes by scanning devices and parameters
  local device_list = PakettiHyperEditGetDevices()
  local device_names = {}
  for i, device_info in ipairs(device_list) do
    table.insert(device_names, device_info.name)
  end
  if #device_names == 0 then
    device_names = {"No devices available"}
  end
  
  local found_automations = {}
  print("DEBUG: Found " .. #device_list .. " devices to scan")
  
  -- BETTER APPROACH: Scan pattern track's existing automations directly
  print("DEBUG: Alternative scan - checking pattern_track automations directly...")
  
  -- First, try to get all existing automations from pattern track directly
  local track_automations = {}
  
  -- Method 1: Scan devices and parameters (current method)
  print("DEBUG: === Method 1: Device/Parameter Scan ===")
  for device_idx, device_info in ipairs(device_list) do
    print("DEBUG: Scanning device " .. device_idx .. ": " .. device_info.name)
    local device_automation_count = 0
    
    for param_idx, param in ipairs(device_info.device.parameters) do
      if param.is_automatable then
        local automation = pattern_track:find_automation(param)
        if automation then
          print("DEBUG: Found automation for " .. device_info.name .. " -> " .. param.name)
          table.insert(found_automations, {
            automation = automation,
            parameter = param,
            device_idx = device_idx,
            device_info = device_info
          })
          device_automation_count = device_automation_count + 1
        else
          -- Check if parameter has any automation points at all
          print("DEBUG: Checking for automation points on " .. device_info.name .. " -> " .. param.name)
        end
      end
    end
    
    if device_automation_count == 0 then
      print("DEBUG: No automation found on device " .. device_info.name)
    else
      print("DEBUG: Found " .. device_automation_count .. " automations on " .. device_info.name)
    end
  end
  
  -- Method 2: Try direct automation enumeration (if API supports it)
  print("DEBUG: === Method 2: Direct Pattern Track Scan ===")
  
  -- Method 2: Try to access automations property directly
  local function try_automation_property_access()
    local status, result = pcall(function()
      -- Check if pattern_track has an automations property
      local automations = pattern_track.automations
      if automations then
        print("DEBUG: Found automations property with " .. #automations .. " items")
        for i, automation in ipairs(automations) do
          local dest_param = automation.dest_parameter
          if dest_param then
            print("DEBUG: Automation " .. i .. " -> " .. dest_param.name)
            
            -- Find the device this belongs to
            for device_idx, device_info in ipairs(device_list) do
              for param_idx, param in ipairs(device_info.device.parameters) do
                if param.name == dest_param.name then
                  print("DEBUG: Property method found: " .. device_info.name .. " -> " .. param.name)
                  -- Add to found_automations if not already there
                  local already_found = false
                  for _, found_auto in ipairs(found_automations) do
                    if found_auto.parameter.name == param.name then
                      already_found = true
                      break
                    end
                  end
                  if not already_found then
                    table.insert(found_automations, {
                      automation = automation,
                      parameter = param,
                      device_idx = device_idx,
                      device_info = device_info
                    })
                    print("DEBUG: Added automation via property method: " .. device_info.name .. " -> " .. param.name)
                  end
                  break
                end
              end
            end
          end
        end
      else
        print("DEBUG: No automations property found")
      end
    end)
    
    if not status then
      print("DEBUG: Automation property access failed: " .. tostring(result))
    end
  end
  
  try_automation_property_access()
  
  -- Method 3: Alternative iterator approach
  local function try_automation_iteration()
    local status, result = pcall(function()
      print("DEBUG: Trying automation iteration...")
      local automation_count = 0
      -- Try different iteration methods
      for automation in pattern_track:automations_iter() do
        automation_count = automation_count + 1
        print("DEBUG: Iter method found automation " .. automation_count)
        local dest_param = automation.dest_parameter
        if dest_param then
          print("DEBUG: Iter automation -> " .. dest_param.name)
        end
      end
      
      if automation_count == 0 then
        print("DEBUG: No automations found via iteration")
      end
    end)
    
    if not status then
      print("DEBUG: Automation iteration failed: " .. tostring(result))
    end
  end
  
  try_automation_iteration()
  
  if #found_automations == 0 then
    print("DEBUG: No automation envelopes found on track - clearing all step data")
    
    -- Clear all step data and reset to defaults
    for row = 1, NUM_ROWS do
      for step = 1, MAX_STEPS do
        step_active[row][step] = false
        step_data[row][step] = 0.5
      end
      
      -- Reset row parameters
      row_parameters[row] = nil
      row_devices[row] = nil
      
      -- Reset dropdowns to first available options
      if dialog_vb then
        if dialog_vb.views["device_popup_" .. row] and #device_names > 0 then
          dialog_vb.views["device_popup_" .. row].value = 1
        end
        if dialog_vb.views["parameter_popup_" .. row] then
          dialog_vb.views["parameter_popup_" .. row].items = {"No Device Selected"}
          dialog_vb.views["parameter_popup_" .. row].value = 1
        end
      end
      
      -- Update canvases to show empty state
      if row_canvases[row] then
        row_canvases[row]:update()
      end
    end
    
    print("DEBUG: All rows cleared for track with no automation")
    return
  end
  
  print("DEBUG: Found " .. #found_automations .. " automation envelopes - populating rows")
  
  -- Take the first 8 automations and assign to rows
  local populated_rows = 0
  for _, automation_data in ipairs(found_automations) do
    if populated_rows >= NUM_ROWS then break end  -- Max 8 rows
    
    local row = populated_rows + 1
    local automation = automation_data.automation
    local parameter = automation_data.parameter
    
    print("DEBUG: Row " .. row .. " → " .. parameter.name)
    
    -- Use the device info from our found automation data (already resolved)
    local found_device_idx = automation_data.device_idx
    local device_info = automation_data.device_info
    
    -- Find parameter index in the device's parameter list
    local found_param_idx = nil
    for param_idx, param_info in ipairs(PakettiHyperEditGetParameters(device_info.device)) do
      if param_info.parameter.name == parameter.name then
        found_param_idx = param_idx
        break
      end
    end
    
    if found_device_idx and found_param_idx then
      -- Set up this row
      device_lists[row] = device_list
      row_devices[row] = device_list[found_device_idx].device
      parameter_lists[row] = PakettiHyperEditGetParameters(row_devices[row])
      row_parameters[row] = parameter_lists[row][found_param_idx]
      
      -- Update UI dropdowns
      print("DEBUG: Updating UI for row " .. row .. " - device idx " .. found_device_idx .. ", param idx " .. found_param_idx)
      
      if dialog_vb and dialog_vb.views["device_popup_" .. row] then
        dialog_vb.views["device_popup_" .. row].value = found_device_idx
        print("DEBUG: Set device dropdown for row " .. row .. " to index " .. found_device_idx)
      else
        print("DEBUG: ERROR - Could not find device_popup_" .. row)
      end
      
      if dialog_vb and dialog_vb.views["parameter_popup_" .. row] then
        local param_names = {}
        for i, param_info in ipairs(parameter_lists[row]) do
          table.insert(param_names, param_info.name)
        end
        dialog_vb.views["parameter_popup_" .. row].items = param_names
        dialog_vb.views["parameter_popup_" .. row].value = found_param_idx
        print("DEBUG: Set parameter dropdown for row " .. row .. " to '" .. parameter.name .. "' at index " .. found_param_idx)
      else
        print("DEBUG: ERROR - Could not find parameter_popup_" .. row)
      end
      
      -- Set automation to POINTS mode and read points
      automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_POINTS
      
      -- Initialize step data
      if not step_active[row] then step_active[row] = {} end
      if not step_data[row] then step_data[row] = {} end
      
      -- SMART PATTERN DETECTION: Find shortest repeating cycle
      local detected_step_count = PakettiHyperEditDetectPatternLength(automation.points)
      
      -- Set the row step count based on detected pattern
      row_steps[row] = detected_step_count
      print("DEBUG: Smart-detected " .. detected_step_count .. "-step repeating pattern for row " .. row)
      
      -- Update the UI step count valuebox
      if dialog_vb and dialog_vb.views["steps_" .. row] then
        dialog_vb.views["steps_" .. row].value = detected_step_count
      end
      
      -- Read automation points and consolidate to detected pattern length
      local points_read = 0
      for _, point in ipairs(automation.points) do
        local step = point.time
        local value = point.value  -- Already 0.0-1.0
        
        if step >= 1 and step <= MAX_STEPS then
          -- Map to the detected pattern length (consolidate repeating patterns)
          local consolidated_step = ((step - 1) % detected_step_count) + 1
          step_active[row][consolidated_step] = true
          step_data[row][consolidated_step] = value
          points_read = points_read + 1
          
          if consolidated_step ~= step then
            print("DEBUG: Consolidated step " .. step .. " → " .. consolidated_step .. " (pattern length: " .. detected_step_count .. ")")
          end
        end
      end
      
      print("DEBUG: Read " .. points_read .. " automation points for " .. detected_step_count .. "-step repeating pattern (row " .. row .. ")")
      
      -- Redraw canvas with new step count  
      if row_canvases[row] then
        row_canvases[row]:update()
      end
      
      populated_rows = populated_rows + 1
    else
      print("DEBUG: Could not find device for parameter " .. parameter.name)
    end
  end
  
  print("DEBUG: Successfully populated " .. populated_rows .. " rows with existing automation")
  
  if populated_rows > 0 then
    renoise.app():show_status("HyperEdit: Loaded " .. populated_rows .. " existing automations into rows")
  end
end

-- Draw canvas for specific row
function PakettiHyperEditDrawRowCanvas(row)
  return function(ctx)
    local w = canvas_width
    local h = canvas_height_per_row
    
    -- Clear canvas
    ctx:clear_rect(0, 0, w, h)
    
    -- Draw background
    ctx.fill_color = COLOR_BACKGROUND
    ctx:fill_rect(0, 0, w, h)
    
    -- Content area with small margins (matching mouse handling)
    local content_margin = 3
    local content_x = content_margin
    local content_y = content_margin
    local content_width = w - (content_margin * 2)
    local content_height = h - (content_margin * 2)
    
    -- Use ROW-SPECIFIC step count
    local row_step_count = row_steps[row] or 16
    
    -- Draw grid lines within content area
    ctx.stroke_color = COLOR_GRID
    ctx.line_width = 1
    
    -- Vertical lines (steps) within content area with every 4th beat highlighting
    local step_width = content_width / row_step_count
    
    -- Adaptive line width based on step density to preserve visibility
    local adaptive_line_width
    if step_width >= 20 then
      adaptive_line_width = 3  -- Wide steps: thick lines like original
    elseif step_width >= 10 then
      adaptive_line_width = 2  -- Medium steps: medium lines  
    elseif step_width >= 5 then
      adaptive_line_width = 1  -- Narrow steps: thin lines
    else
      adaptive_line_width = 0.5  -- Very narrow steps: hair-thin lines
    end
    
    -- Skip grid lines entirely if steps are extremely narrow (< 3px)
    local show_grid_lines = step_width >= 3
    
    if show_grid_lines then
      for step = 0, row_step_count do
        local x = content_x + (step * step_width)
        
        -- Make every 4th step line bright white, all others pale grey (like PakettiSliceEffectStepSequencer)
        if step > 0 and (step % 4) == 0 then
          ctx.stroke_color = {255, 255, 255, 255}  -- Bright white for 4-step separators
          ctx.line_width = adaptive_line_width
        elseif step > 0 then
          ctx.stroke_color = {80, 80, 80, 255}  -- Pale grey for regular step separators
          ctx.line_width = adaptive_line_width
        else
          ctx.stroke_color = COLOR_GRID  -- Use original grid color for edges
          ctx.line_width = math.max(0.5, adaptive_line_width * 0.5)  -- Even thinner for edges
        end
        
        ctx:begin_path()
        ctx:move_to(x, content_y)
        ctx:line_to(x, content_y + content_height)
        ctx:stroke()
      end
    else
      print("DEBUG: Skipping grid lines - steps too narrow (" .. string.format("%.1f", step_width) .. "px per step)")
    end
    
    -- Removed horizontal center line to avoid confusion across multiple steps
    
    -- Draw steps using FULL content height (matching mouse handling)
    for step = 1, row_step_count do
      if step_active[row] and step_active[row][step] then
        local step_x = content_x + ((step - 1) * step_width)
        local value = step_data[row][step] or 0.5
        
        -- Check if this is the current playhead step
        local is_playhead_step = (playhead_step_indices[row] == step)
        
        -- Use playhead color if this is the current step and playhead is active
        if is_playhead_step and playhead_color then
          ctx.fill_color = playhead_color
        else
          ctx.fill_color = COLOR_ACTIVE_STEP
        end
        
        local bar_height = value * content_height
        local bar_y = content_y + content_height - bar_height
        
        -- Make step bars fatter at high step counts for better visibility
        local bar_x_offset, bar_width
        if row_step_count >= 192 then
          -- At 192+ steps: use full width, overlap slightly  
          bar_x_offset = 0
          bar_width = step_width + 1  -- Slight overlap for better visibility
        elseif row_step_count >= 128 then
          -- At 128+ steps: minimal margin
          bar_x_offset = 0.5
          bar_width = step_width - 1
        else
          -- Lower step counts: keep original thin appearance  
          bar_x_offset = 1
          bar_width = step_width - 2
        end
        
        ctx:fill_rect(step_x + bar_x_offset, bar_y, bar_width, bar_height)
      end
    end
    
    -- Draw playhead indicator line (outside of steps) if playhead is active
    if playhead_color and playhead_step_indices[row] then
      local playhead_step = playhead_step_indices[row]
      if playhead_step >= 1 and playhead_step <= row_step_count then
        local playhead_x = content_x + ((playhead_step - 1) * step_width) + (step_width / 2)
        
        ctx.stroke_color = playhead_color
        ctx.line_width = 2
        ctx:begin_path()
        ctx:move_to(playhead_x, content_y - 5)
        ctx:line_to(playhead_x, content_y + content_height + 5)
        ctx:stroke()
        
        -- Draw playhead triangle at top
        ctx.fill_color = playhead_color
        ctx:begin_path()
        ctx:move_to(playhead_x, content_y - 5)
        ctx:line_to(playhead_x - 4, content_y - 12)
        ctx:line_to(playhead_x + 4, content_y - 12)
        ctx:close_path()
        ctx:fill()
      end
    end
    
    -- Draw content area border (like PakettiCanvasExperiments) with track color if enabled
    if capture_track_color then
      local track_color = PakettiHyperEditGetTrackColor()
      ctx.stroke_color = {track_color[1], track_color[2], track_color[3], 255}
    else
      ctx.stroke_color = {80, 0, 120, 255}  -- Default purple border
    end
    ctx.line_width = 2
    ctx:begin_path()
    ctx:rect(content_x, content_y, content_width, content_height)
    ctx:stroke()
    
    -- Draw outer canvas border
    ctx.stroke_color = {255, 255, 255, 255}
    ctx.line_width = 1
    ctx:begin_path()
    ctx:rect(0, 0, w, h)
    ctx:stroke()
  end
end

-- Setup observers
function PakettiHyperEditSetupObservers()
  local song = renoise.song()
  if not song then return end
  
  -- Track change observer
  if not track_change_notifier then
    track_change_notifier = function()
      if hyperedit_dialog and hyperedit_dialog.visible then
        print("DEBUG: === Track changed - refreshing HyperEdit ===")
        
        -- Clear old step data first
        PakettiHyperEditInitStepData()
        
        -- Update device lists and observers
        PakettiHyperEditSetupDeviceObserver()
        PakettiHyperEditUpdateAllDeviceLists()
        
        -- Repopulate with new track's automation
        PakettiHyperEditPopulateFromExistingAutomation()
        
        -- Update colors if track color capture is enabled
        if capture_track_color then
          PakettiHyperEditUpdateColors()
        end
        
        -- Refresh all canvases
        for row = 1, NUM_ROWS do
          if row_canvases[row] then
            row_canvases[row]:update()
          end
        end
        
        print("DEBUG: === Track change refresh complete ===")
      end
    end
    
    if song.selected_track_index_observable and 
       not song.selected_track_index_observable:has_notifier(track_change_notifier) then
      song.selected_track_index_observable:add_notifier(track_change_notifier)
    end
  end
  
  PakettiHyperEditSetupDeviceObserver()
end

-- Setup device observer
function PakettiHyperEditSetupDeviceObserver()
  PakettiHyperEditRemoveDeviceObserver()
  
  local song = renoise.song()
  if not song or not song.selected_track then return end
  
  local track = song.selected_track
  
  if not device_change_notifier then
    device_change_notifier = function()
      print("DEBUG: Device change detected!")
      if hyperedit_dialog and hyperedit_dialog.visible then
        PakettiHyperEditUpdateAllDeviceLists()
      end
    end
  end
  
  if track.devices_observable and 
     not track.devices_observable:has_notifier(device_change_notifier) then
    track.devices_observable:add_notifier(device_change_notifier)
    print("DEBUG: Device observer added for track: " .. track.name)
  else
    print("DEBUG: Device observer already exists or failed to add")
  end
end

-- Remove device observer
function PakettiHyperEditRemoveDeviceObserver()
  if device_change_notifier then
    local song = renoise.song()
    if song and song.selected_track and song.selected_track.devices_observable then
      pcall(function()
        if song.selected_track.devices_observable:has_notifier(device_change_notifier) then
          song.selected_track.devices_observable:remove_notifier(device_change_notifier)
        end
      end)
    end
  end
end

-- Remove all observers
function PakettiHyperEditRemoveObservers()
  if track_change_notifier then
    local song = renoise.song()
    if song and song.selected_track_index_observable then
      pcall(function()
        if song.selected_track_index_observable:has_notifier(track_change_notifier) then
          song.selected_track_index_observable:remove_notifier(track_change_notifier)
        end
      end)
    end
    track_change_notifier = nil
  end
  
  PakettiHyperEditRemoveDeviceObserver()
  device_change_notifier = nil
end

-- Change step count for specific row
function PakettiHyperEditChangeRowStepCount(row, steps)
  row_steps[row] = steps
  -- Update only this row's canvas
  if row_canvases[row] then
    row_canvases[row]:update()
  end
  renoise.app():show_status("HyperEdit Row " .. row .. ": Changed to " .. steps .. " steps")
end

-- Change loop length
function PakettiHyperEditChangeLoopLength(loop_len)
  loop_length = loop_len
  renoise.app():show_status("HyperEdit: Loop length set to " .. loop_len .. " steps")
end

-- Clear all data
function PakettiHyperEditClearAll()
  PakettiHyperEditInitStepData()
  for row = 1, NUM_ROWS do
    if row_canvases[row] then
      row_canvases[row]:update()
    end
  end
  renoise.app():show_status("HyperEdit: Cleared all step data")
end

-- Key handler
function paketti_hyperedit_keyhandler_func(dialog, key)
  if key.modifiers == "command" and key.name == "h" then
    PakettiHyperEditCleanup()
    if hyperedit_dialog then
      hyperedit_dialog:close()
    end
    return nil
  end
  
  return key
end

-- Cleanup
function PakettiHyperEditCleanup()
  PakettiHyperEditRemoveObservers()
  PakettiHyperEditCleanupPlayhead()
  
  hyperedit_dialog = nil
  dialog_vb = nil  -- Clear ViewBuilder reference
  row_canvases = {}
  row_devices = {}
  row_parameters = {}
  device_lists = {}
  parameter_lists = {}
  mouse_is_down = false
  current_row_drawing = 0
end

-- Create main dialog
function PakettiHyperEditCreateDialog()
  if hyperedit_dialog and hyperedit_dialog.visible then
    hyperedit_dialog:close()
  end
  
  -- Initialize data
  PakettiHyperEditInitStepData()
  
  local vb = renoise.ViewBuilder()
  
  -- Get initial device list
  local devices = PakettiHyperEditGetDevices()
  local device_names = {}
  for i, device_info in ipairs(devices) do
    table.insert(device_names, device_info.name)
  end
  if #device_names == 0 then
    device_names = {"No devices available"}
  end
  
  -- Initialize all rows with same device list
  for row = 1, NUM_ROWS do
    device_lists[row] = devices
    row_devices[row] = nil
    row_parameters[row] = nil
    parameter_lists[row] = {}
  end
  
  local dialog_content = vb:column {
    -- Global controls
    vb:row {
      vb:text { text = "Loop", width = 40 },
      vb:valuebox {
        min = 1,
        max = 256,
        value = loop_length,
        width = 50,
        notifier = function(value)
          PakettiHyperEditChangeLoopLength(value)
        end
      },
      vb:space { width = 10 },
      vb:checkbox {
        id = "capture_track_color",
        value = capture_track_color,
        notifier = function(value)
          print("DEBUG: === Capture Track Color checkbox toggled to: " .. tostring(value) .. " ===")
          capture_track_color = value
          print("DEBUG: capture_track_color variable set to: " .. tostring(capture_track_color))
          
          print("DEBUG: About to call PakettiHyperEditUpdateColors()")
          PakettiHyperEditUpdateColors()
          print("DEBUG: PakettiHyperEditUpdateColors() completed")
          
          if value then
            renoise.app():show_status("HyperEdit: Using track color for active steps")
          else
            renoise.app():show_status("HyperEdit: Using default purple color")
          end
          print("DEBUG: === Checkbox notifier complete ===")
        end
      },
      vb:text { text = "Capture Track Color", width = 120 },
      vb:space { width = 10 },
      vb:button {
        text = "Clear All",
        width = 70,
        notifier = function()
          PakettiHyperEditClearAll()
        end
      }
    },
  }
  
  -- Create 8 rows
  for row = 1, NUM_ROWS do
    local row_content = vb:column {
      -- Row header with device/parameter selection and individual step count (no row labels, no read button)
      vb:row {
        -- Step count quick buttons (supports smart pattern detection)
        vb:button {
          text = "1",
          width = 20,
          tooltip = "Set step count to 1 (constant value)",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 1)
          end
        },
        vb:button {
          text = "2",
          width = 20,
          tooltip = "Set step count to 2",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 2)
          end
        },
        vb:button {
          text = "4", 
          width = 20,
          tooltip = "Set step count to 4",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 4)
          end
        },
        vb:button {
          text = "8",
          width = 20,
          tooltip = "Set step count to 8",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 8)
          end
        },
        vb:button {
          text = "32",
          width = 25,
          tooltip = "Set step count to 32",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 32)
          end
        },
        vb:button {
          text = "48",
          width = 25,
          tooltip = "Set step count to 48",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 48)
          end
        },
        vb:button {
          text = "64",
          width = 25,
          tooltip = "Set step count to 64",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 64)
          end
        },
        vb:button {
          text = "96",
          width = 25,
          tooltip = "Set step count to 96",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 96)
          end
        },
        vb:button {
          text = "112",
          width = 30,
          tooltip = "Set step count to 112",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 112)
          end
        },
        vb:button {
          text = "128",
          width = 30,
          tooltip = "Set step count to 128",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 128)
          end
        },
        vb:button {
          text = "192",
          width = 30,
          tooltip = "Set step count to 192",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 192)
          end
        },
        vb:button {
          text = "256",
          width = 30,
          tooltip = "Set step count to 256",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 256)
          end
        },
        
        vb:valuebox {
          id = "steps_" .. row,
          min = 1,  -- Allow any pattern length from smart detection
          max = 256,
          value = 16,
          width = 50,  -- Made wider so you can see the number
          tooltip = "Steps for this row (smart-detected from automation)",
          notifier = function(value)
            PakettiHyperEditChangeRowStepCount(row, value)
          end
        },
        vb:popup {
          id = "device_popup_" .. row,
          items = device_names,
          value = (#devices > 0) and 1 or 1,  -- Select first device if available
          width = 200,  -- Made even wider without Read button
          notifier = function(index)
            print("DEBUG: Device popup " .. row .. " notifier called with index " .. index)
            PakettiHyperEditSelectDevice(row, index)
          end
        },
        vb:popup {
          id = "parameter_popup_" .. row,
          items = {"Select device first"},
          value = 1,
          width = 200,  -- Made even wider without Read button
          tooltip = "Selecting parameter auto-reads existing automation and sets to POINTS mode",
          notifier = function(index)
            PakettiHyperEditSelectParameter(row, index)
          end
        },
        
        -- Value set buttons
        vb:button {
          text = "0.0",
          width = 30,
          tooltip = "Set all steps to 0.0",
          notifier = function()
            PakettiHyperEditSetAllStepsToValue(row, 0.0)
          end
        },
        vb:button {
          text = "0.5",
          width = 30,
          tooltip = "Set all steps to 0.5 (center)",
          notifier = function()
            PakettiHyperEditSetAllStepsToValue(row, 0.5)
          end
        },
        vb:button {
          text = "1.0",
          width = 30,
          tooltip = "Set all steps to 1.0 (maximum)",
          notifier = function()
            PakettiHyperEditSetAllStepsToValue(row, 1.0)
          end
        }
      },
      
      -- Row canvas
      vb:canvas {
        id = "row_canvas_" .. row,
        width = canvas_width,
        height = canvas_height_per_row,
        mode = "plain",
        render = PakettiHyperEditDrawRowCanvas(row),
        mouse_handler = PakettiHyperEditHandleRowMouse(row),
        mouse_events = {"down", "up", "move", "exit", "double"}
      },
    }
    
    dialog_content:add_child(row_content)
  end
  
  -- Bottom controls
  dialog_content:add_child(vb:row {
    vb:button {
      text = "Close",
      width = 60,
      notifier = function()
        PakettiHyperEditCleanup()
        hyperedit_dialog:close()
      end
    }
  })
  
  -- Store the ViewBuilder instance for later use
  dialog_vb = vb
  
  -- Create dialog
  hyperedit_dialog = renoise.app():show_custom_dialog(
    "Paketti HyperEdit",
    dialog_content,
    paketti_hyperedit_keyhandler_func
  )
  
  -- Store canvas references and check if views are accessible
  for row = 1, NUM_ROWS do
    row_canvases[row] = dialog_vb.views["row_canvas_" .. row]
    
    -- Debug: Check if views are accessible
    local device_popup = dialog_vb.views["device_popup_" .. row]
    local param_popup = dialog_vb.views["parameter_popup_" .. row]
    print("DEBUG: Row " .. row .. " - Device popup: " .. tostring(device_popup ~= nil) .. ", Param popup: " .. tostring(param_popup ~= nil))
    
    if device_popup then
      print("DEBUG: Row " .. row .. " device popup value: " .. device_popup.value .. ", items: " .. #device_popup.items)
    end
  end
  
  -- Setup observers and initialize
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  PakettiHyperEditSetupObservers()
  
  -- Setup playhead
  PakettiHyperEditSetupPlayhead()
  
  -- Initialize colors based on track color capture setting
  PakettiHyperEditUpdateColors()
  
  -- CRITICAL: Initialize with existing automation or default to first device
  if #devices > 0 then
    print("DEBUG: Setting up initialization timer with " .. #devices .. " devices")
    local init_timer
    init_timer = function()
      print("DEBUG: === Initialization timer executing ===")
      
      -- First, try to populate from existing automation
      PakettiHyperEditPopulateFromExistingAutomation()
      
      -- For any rows not populated by automation, set to first device
      print("DEBUG: Checking which rows need default device setup...")
      for row = 1, NUM_ROWS do
        if not row_devices[row] then
          print("DEBUG: Row " .. row .. " not populated by automation - setting to first device")
          PakettiHyperEditSelectDevice(row, 1)
        else
          print("DEBUG: Row " .. row .. " already has device: " .. (row_devices[row].display_name or "unknown"))
        end
      end
      
      print("DEBUG: === Initialization timer complete ===")
      -- Remove this one-time timer
      renoise.tool():remove_timer(init_timer)
    end
    print("DEBUG: Adding initialization timer...")
    renoise.tool():add_timer(init_timer, 150)  -- Slightly longer delay for automation population
  else
    renoise.app():show_status("HyperEdit: No devices found - add devices to track")
  end
end

-- Main init function
function PakettiHyperEditInit()
  if hyperedit_dialog and hyperedit_dialog.visible then
    hyperedit_dialog:close()
    return
  end
  
  PakettiHyperEditCreateDialog()
end

-- Menu entries
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti HyperEdit",
  invoke = PakettiHyperEditInit
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:Paketti HyperEdit",
  invoke = PakettiHyperEditInit
}