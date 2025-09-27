-- PakettiHyperEdit.lua
-- 8-Row Interchangeable Stepsequencer with individual device/parameter selection
-- Each row has its own canvas with device and parameter dropdowns

local vb = renoise.ViewBuilder()
-- Global flag to prevent auto-read during device list updates
local is_updating_device_lists = false

local row_devices = {}   -- [row] = selected device
local row_parameters = {} -- [row] = selected parameter
local device_lists = {}  -- [row] = available devices for that row
local parameter_lists = {} -- [row] = available parameters for selected device
-- Observers
local track_change_notifier = nil
local device_change_notifier = nil


-- Constants  
MAX_STEPS = 256  -- Global, support up to 256 steps

-- Dynamic row count - will be set from preferences
local NUM_ROWS = 8

-- Update NUM_ROWS from preferences
function PakettiHyperEditUpdateRowCount()
  -- Initialize preferences if they don't exist
  if preferences then
    if not preferences.PakettiHyperEditRowCount then
      preferences:add_property("PakettiHyperEditRowCount", renoise.Document.ObservableNumber(8))
      preferences:save_as("preferences.xml")
    end
    if not preferences.PakettiHyperEditAutoFit then
      preferences:add_property("PakettiHyperEditAutoFit", renoise.Document.ObservableBoolean(true))
      preferences:save_as("preferences.xml")
    end
    if not preferences.PakettiHyperEditManualRows then
      preferences:add_property("PakettiHyperEditManualRows", renoise.Document.ObservableNumber(8))
      preferences:save_as("preferences.xml")
    end
  end
  
  -- Use manual row count if auto-fit is disabled, otherwise use saved row count
  if preferences and preferences.PakettiHyperEditAutoFit and not preferences.PakettiHyperEditAutoFit.value then
    -- Auto-fit disabled: use manual row count
    NUM_ROWS = preferences.PakettiHyperEditManualRows.value
  elseif preferences and preferences.PakettiHyperEditRowCount then
    -- Auto-fit enabled: use saved row count (which may have been auto-expanded)
    NUM_ROWS = preferences.PakettiHyperEditRowCount.value
  else
    NUM_ROWS = 8  -- Default fallback
  end
end

-- Dialog state
local hyperedit_dialog = nil
local dialog_vb = nil    -- Store ViewBuilder instance
local row_canvases = {}  -- [row] = canvas
local pre_configuration_applied = false

-- Playhead variables (like PakettiGater)
local playhead_timer_fn = nil
local playing_observer_fn = nil
local playhead_step_indices = {}  -- [row] = current_step
local playhead_color = nil

-- Row state variables (must be declared early for playhead functions)
local row_steps = {}  -- [row] = step count for this row (individual per row)

-- Track color capture state is now stored in preferences (PakettiHyperEditCaptureTrackColor)

-- Get current track color with blending
function PakettiHyperEditGetTrackColor()
  local song = renoise.song()
  if not song then return {120, 40, 160} end  -- Default purple
  
  local track = song.selected_track
  if not track then return {120, 40, 160} end
  
  -- Get track color (RGB 0-255) and blend amount (0-100)
  local track_color = track.color  -- RGB array
  local color_blend = track.color_blend or 50  -- Default 50% blend
  
  
  -- When blend is 0%, it means "no blending" in Renoise - use raw color with boost
  if color_blend == 0 then
    local boosted_color = {
      math.max(track_color[1], 100),  -- Ensure minimum 100 for visibility
      math.max(track_color[2], 100),
      math.max(track_color[3], 100)
    }
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
  
  
  return blended_color
end

-- Update colors based on capture track color setting
function PakettiHyperEditUpdateColors()
  
  if preferences.PakettiHyperEditCaptureTrackColor.value then
    local track_color = PakettiHyperEditGetTrackColor()
    COLOR_ACTIVE_STEP = {track_color[1], track_color[2], track_color[3], 255}
  else
    COLOR_ACTIVE_STEP = {120, 40, 160, 255}  -- Default purple
  end
  
  -- Update playhead color too
  playhead_color = PakettiHyperEditResolvePlayheadColor()
  
  -- Update all canvases
  -- Update all step count button colors
  for row = 1, NUM_ROWS do
    PakettiHyperEditUpdateStepButtonColors(row)
  end
  
  local updated_count = 0
  for row = 1, NUM_ROWS do
    if row_canvases[row] then
      row_canvases[row]:update()
      updated_count = updated_count + 1
    end
  end
end

-- Playhead color resolution function
function PakettiHyperEditResolvePlayheadColor()
  
  -- If track color capture is enabled, use track color for playhead too
  if preferences.PakettiHyperEditCaptureTrackColor.value then
    local track_color = PakettiHyperEditGetTrackColor()
    -- Make playhead brighter than active steps for visibility
    local playhead_result = {
      math.min(255, track_color[1] + 60),
      math.min(255, track_color[2] + 60), 
      math.min(255, track_color[3] + 60)
    }
    return playhead_result
  end
  
  -- Otherwise use preferences
  local choice = (preferences and preferences.PakettiGrooveboxPlayheadColor and preferences.PakettiGrooveboxPlayheadColor.value) or 2
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
-- Row count is now dynamic based on preferences
step_data = {}  -- [row][step] = value (0.0 to 1.0) - Global 
step_active = {}  -- [row][step] = boolean - Global

-- Canvas dimensions per row - taller as requested
local canvas_width = 777
local canvas_height_per_row = 60  -- 2x taller (was 40)
local content_margin = 1

-- Mouse state
local mouse_is_down = false
local current_row_drawing = 0
local mouse_state_monitor_timer = nil
local last_mouse_move_time = 0

-- Track switching state
local is_track_switching = false

-- Colors for visualization (GLOBAL so PakettiHyperEditUpdateColors can modify them)
COLOR_ACTIVE_STEP = {120, 40, 160, 255}     -- Purple for active steps (will be updated by track color capture)
COLOR_INACTIVE_STEP = {40, 40, 40, 255}     -- Dark gray for inactive steps  
COLOR_GRID = {80, 80, 80, 255}              -- Grid lines
COLOR_BACKGROUND = {20, 20, 20, 255}        -- Dark background

-- Pre-configure parameters when opening on empty channel
function PakettiHyperEditPreConfigureParameters()
  local song = renoise.song()
  if not song then return end
  
  local track = song.selected_track
  if not track then return end
  
  -- Check if there are any existing automations on this track - if so, skip pre-configuration
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  
  -- Quick check for any existing automations 
  local has_automation = false
  for i = 2, #track.devices do -- Skip Track Vol/Pan
    local device = track.devices[i]
    for j = 1, #device.parameters do
      local param = device.parameters[j]
      if param.is_automatable then
        local automation = pattern_track:find_automation(param)
        if automation and #automation.points > 0 then
          has_automation = true
          break
        end
      end
    end
    if has_automation then break end
  end
  
  if has_automation then
    -- If automation exists, populate from it instead of pre-configuring
    print("DEBUG: Automation detected - populating from existing automation envelopes")
    PakettiHyperEditPopulateFromExistingAutomation()
    pre_configuration_applied = true  -- Prevent init timer from running automation population again
    return
  end
  
  -- Get available devices
  local devices = PakettiHyperEditGetDevices()
  if #devices == 0 then return end
  
  -- Use first device
  local first_device_info = devices[1]
  local first_device_params = PakettiHyperEditGetParameters(first_device_info.device)
  if #first_device_params == 0 then return end
  
  -- Pre-configure first 8 rows with parameters from first device
  -- For *Instr. Macros devices, skip parameter 1 and map parameters 2-8
  local param_offset = 0
  local max_params = 8
  if first_device_info.name:find("Instr") and first_device_info.name:find("Macro") then
    param_offset = 1  -- Skip first parameter for Instrument Macros
    print("DEBUG: Detected Instrument Macros device, using parameters 2-8")
  end
  
  local available_params = #first_device_params - param_offset
  local max_rows = math.min(NUM_ROWS, max_params, available_params)
  
  print("DEBUG: Device has " .. #first_device_params .. " parameters, offset: " .. param_offset .. ", available: " .. available_params .. ", max_rows: " .. max_rows)
  
  for row = 1, max_rows do
    local param_index = row + param_offset
    if param_index > #first_device_params then
      print("DEBUG: Skipping row " .. row .. " - param index " .. param_index .. " exceeds available parameters (" .. #first_device_params .. ")")
      break
    end
    local param_info = first_device_params[param_index]
    
    -- If we encounter X_PitchBend, look for Pitchbend instead
    if param_info.name == "X_PitchBend" then
      for i, p in ipairs(first_device_params) do
        if p.name == "Pitchbend" then
          param_info = p
          param_index = i
          break
        end
      end
    end
    
    -- Set device for this row (store AudioDevice directly for consistency)
    row_devices[row] = first_device_info.device
    parameter_lists[row] = first_device_params
    
    -- Set parameter for this row
    row_parameters[row] = param_info
    
    -- Update UI elements if they exist
    if dialog_vb then
      -- Update device popup (set to first device)
      local device_popup = dialog_vb.views["device_popup_" .. row]
      if device_popup then
        device_popup.value = 1 -- First device
      end
      
      -- Update parameter popup
      local param_popup = dialog_vb.views["parameter_popup_" .. row]
      if param_popup then
        local param_names = {}
        for _, p in ipairs(first_device_params) do
          table.insert(param_names, p.name)
        end
        param_popup.items = param_names
        param_popup.value = param_index -- Select the correct parameter index
      end
    end
  end
  
  -- Set flag to indicate pre-configuration was applied
  pre_configuration_applied = true
  
  renoise.app():show_status("HyperEdit: Pre-configured first " .. max_rows .. " rows with " .. first_device_info.name .. " parameters")
end

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

-- Device parameter whitelists for cleaner parameter selection
local DEVICE_PARAMETER_WHITELISTS = {
  ["AU: Valhalla DSP, LLC: ValhallaDelay"] = {
    "Mix",
    "Feedback", 
    "DelayL_Ms",
    "DelayR_Ms",
    "DelayStyle",
    "Width",
    "Age",
    "DriveIn",
    "ModRate",
    "ModDepth",
    "LowCut",
    "HighCut",
    "Diffusion",
    "Mode",
    "Era"
  },
  ["Wavetable Mod *LFO"] = {
    "Amplitude",
    "Frequency",
    "Offset"
  },
  ["*Instr. Macros"] = {
    "Cutoff",
    "Resonance", 
    "Pitchbend",
    "Drive",
    "ParallelComp",
    "CutLfoAmp",
    "CutLfoFreq",
    "PB Inertia"
  },
  ["Gainer"] = {
    "Gain"
  }
}

-- Get automatable parameters from device (with optional whitelist filtering)
function PakettiHyperEditGetParameters(device)
  if not device then return {} end
  
  local all_params = {}
  
  -- Get all automatable parameters
  for i = 1, #device.parameters do
    local param = device.parameters[i]
    if param.is_automatable then
      -- Special handling for Gainer device - custom range mapping
      local device_name = device.display_name or ""
      local param_min = param.value_min
      local param_max = param.value_max 
      local param_default = param.value_default
      
      if device_name == "Gainer" and param.name == "Gain" then
        -- Custom mapping: HyperEdit 0.0-1.0 maps to Renoise 0.0-1.0 (not 0.0-4.0)
        param_min = 0.0
        param_max = 1.0
        param_default = 1.0
        print("DEBUG: Gainer Gain parameter - using custom range 0.0-1.0 (instead of " .. param.value_min .. "-" .. param.value_max .. ")")
      end
      
      table.insert(all_params, {
        index = i,
        parameter = param,
        name = param.name,
        value_min = param_min,
        value_max = param_max,
        value_default = param_default,
        -- Store original parameter info for custom mapping
        original_min = param.value_min,
        original_max = param.value_max,
        is_custom_mapped = (device_name == "Gainer" and param.name == "Gain")
      })
    end
  end
  
  -- Check if this device has a whitelist
  local device_name = device.display_name or ""
  local whitelist = DEVICE_PARAMETER_WHITELISTS[device_name]
  
  if not whitelist then
    -- No whitelist - return all parameters
    print("DEBUG: No whitelist found for device: " .. device_name .. " - showing all " .. #all_params .. " parameters")
    return all_params
  end
  
  -- Apply whitelist filtering
  local filtered_params = {}
  local whitelist_lookup = {}
  
  -- Create lookup table for faster searching
  for _, whitelisted_name in ipairs(whitelist) do
    whitelist_lookup[whitelisted_name] = true
  end
  
  -- Filter parameters based on whitelist
  for _, param_info in ipairs(all_params) do
    if whitelist_lookup[param_info.name] then
      table.insert(filtered_params, param_info)
    end
  end
  
  print("DEBUG: Applied whitelist for " .. device_name .. " - filtered from " .. #all_params .. " to " .. #filtered_params .. " parameters")
  
  return filtered_params
end

-- Update all device lists
function PakettiHyperEditUpdateAllDeviceLists()
  if not hyperedit_dialog or not hyperedit_dialog.visible then
    return
  end
  
  -- Set flag to prevent auto-parameter assignment during device updates
  is_updating_device_lists = true
  
  print("DEBUG: Device change detected - updating dropdowns while preserving assignments")
  
  local new_devices = PakettiHyperEditGetDevices()
  local device_names = {}
  
  for i, device_info in ipairs(new_devices) do
    table.insert(device_names, device_info.name)
  end
  
  if #device_names == 0 then
    device_names = {"No devices available"}
  end
  
  print("DEBUG: Updating device dropdowns with " .. #new_devices .. " devices")
  print("DEBUG: NUM_ROWS = " .. NUM_ROWS .. ", processing rows 1 to " .. NUM_ROWS)
  
  -- Update dropdown items and carefully preserve existing assignments
  local preserved_count = 0
  local updated_count = 0
  
  for row = 1, NUM_ROWS do
    local device_popup = dialog_vb and dialog_vb.views["device_popup_" .. row]
    if device_popup then
      -- Save current assignment info BEFORE touching the dropdown
      local current_device = row_devices[row]
      local current_parameter = row_parameters[row]
      print("DEBUG: Processing row " .. row .. " - has_device: " .. (current_device and "YES" or "NO"))
      
      -- Update the items list (this is safe)
      device_popup.items = device_names
      updated_count = updated_count + 1
      
      -- If this row has an existing device assignment, find its new index
      if current_device then
        local found_index = nil
        for i, device_info in ipairs(new_devices) do
          if device_info.device.display_name == current_device.display_name then
            found_index = i
            break
          end
        end
        
        if found_index then
          -- Device still exists - update dropdown index to match
          device_popup.value = found_index
          -- Update device lists for this row
          device_lists[row] = new_devices
          preserved_count = preserved_count + 1
          print("DEBUG: Row " .. row .. " - preserved " .. current_device.display_name .. " at new index " .. found_index)
        else
          -- Device was removed - clear assignment
          print("DEBUG: Row " .. row .. " - device " .. current_device.display_name .. " was removed, clearing assignment")
          row_devices[row] = nil
          row_parameters[row] = nil
          parameter_lists[row] = {}
          
          -- Clear parameter popup
          local param_popup = dialog_vb.views["parameter_popup_" .. row]
          if param_popup then
            param_popup.items = {"Select device first"}
            param_popup.value = 1
          end
          
          -- Clear step data since device is gone
          if step_data[row] then
            for step = 1, MAX_STEPS do
              step_data[row][step] = 0.5
              step_active[row][step] = false
            end
            PakettiHyperEditRedrawCanvas(row)
          end
        end
      else
        -- No existing assignment - set to first device or stay unassigned
        print("DEBUG: Row " .. row .. " - setting device_lists[row] with " .. #new_devices .. " devices")
        device_lists[row] = new_devices
        if #new_devices > 0 then
          print("DEBUG: Row " .. row .. " - setting dropdown value to 1")
          device_popup.value = 1
          print("DEBUG: Row " .. row .. " - dropdown value set, device_lists[row] has " .. #device_lists[row] .. " devices")
          
          -- CRITICAL: Manually trigger device selection since notifier won't fire if value is already 1
          print("DEBUG: Row " .. row .. " - manually triggering device selection")
          PakettiHyperEditSelectDevice(row, 1)
        end
      end
    else
      print("DEBUG: Row " .. row .. " - device_popup not found")
    end
  end
  
  local status_msg = "HyperEdit: Updated " .. updated_count .. " device dropdowns"
  if preserved_count > 0 then
    status_msg = status_msg .. ", preserved " .. preserved_count .. " assignments"
  end
  
  renoise.app():show_status(status_msg)
  print("DEBUG: Device list update complete - " .. preserved_count .. " assignments preserved")
  
  -- Clear flag to allow normal parameter assignment
  is_updating_device_lists = false
end

-- Fix dropdown indices after device list changes (preserve existing assignments and canvas data)
function PakettiHyperEditFixDropdownIndices()
  print("DEBUG: === Fixing dropdown indices - SIMPLE APPROACH ===")
  
  for row = 1, NUM_ROWS do
    if row_devices[row] and row_parameters[row] then
      local existing_device_name = row_devices[row].display_name
      print("DEBUG: Row " .. row .. " has device: " .. existing_device_name)
      
      -- Find this device by name in the current device list
      local devices = PakettiHyperEditGetDevices()
      local found_device_idx = nil
      
      for i, device_info in ipairs(devices) do
        if device_info.name == existing_device_name then
          found_device_idx = i
          print("DEBUG: Found device " .. existing_device_name .. " at new index " .. i)
          break
        end
      end
      
      if found_device_idx then
        -- ONLY update the dropdown index - don't touch anything else!
        device_lists[row] = devices
        if dialog_vb and dialog_vb.views["device_popup_" .. row] then
          dialog_vb.views["device_popup_" .. row].value = found_device_idx
          print("DEBUG: Updated dropdown for row " .. row .. " to index " .. found_device_idx .. " - DONE!")
        end
      else
        print("DEBUG: Device " .. existing_device_name .. " no longer exists - keeping old assignment")
      end
    end
  end
  
  print("DEBUG: === Simple dropdown fix complete - canvas data untouched ===")
end

-- Refresh automation data for existing assignments (preserve assignments, just update data)
function PakettiHyperEditRefreshExistingAutomation()
  local song = renoise.song()
  if not song then return end
  
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  
  print("DEBUG: Refreshing automation for existing assignments without clearing")
  
  for row = 1, NUM_ROWS do
    if row_parameters[row] and row_devices[row] then
      local param_name = row_parameters[row].name
      local device_name = row_devices[row].display_name
      print("DEBUG: Checking row " .. row .. ": " .. device_name .. " -> " .. param_name)
      
      -- Find automation for this existing parameter
      local automation = pattern_track:find_automation(row_parameters[row].parameter)
      
      if automation then
        print("DEBUG: Found automation for " .. param_name .. " - refreshing step data")
        
        -- Set automation to POINTS mode
        automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_POINTS
        
        -- Detect pattern length
        local detected_step_count = PakettiHyperEditDetectPatternLength(automation.points)
        row_steps[row] = detected_step_count
        
        -- Clear and re-read step data from automation
        for step = 1, MAX_STEPS do
          step_active[row][step] = false
          step_data[row][step] = 0.5
        end
        
        -- Read automation points
        for _, point in ipairs(automation.points) do
          local line_pos = point.time_stamp + 1
          local consolidated_step = ((line_pos - 1) % detected_step_count) + 1
          
          step_active[row][consolidated_step] = true
          
          -- Apply reverse custom mapping for special devices
          local step_value = point.value
          if row_parameters[row].is_custom_mapped then
            -- For Gainer: Convert Renoise automation (normalized from 0.0-4.0) back to HyperEdit 0.0-1.0
            -- point.value is normalized 0.0-1.0 from original 0.0-4.0 range
            -- We want: automation 0.0 → HyperEdit 0.0, automation 0.25 (=1.0 on 0-4 scale) → HyperEdit 1.0
            local original_min = row_parameters[row].original_min or 0.0
            local original_max = row_parameters[row].original_max or 4.0
            local actual_renoise_value = original_min + (point.value * (original_max - original_min))
            step_value = math.max(0.0, math.min(1.0, actual_renoise_value / 1.0)) -- Map 0.0-1.0 renoise to 0.0-1.0 hyperedit
            print("DEBUG: Reverse mapping - Renoise " .. actual_renoise_value .. " → HyperEdit " .. step_value)
          end
          
          step_data[row][consolidated_step] = step_value
        end
        
        print("DEBUG: Refreshed " .. #automation.points .. " automation points for " .. param_name .. " (Row " .. row .. ")")
        
        -- Update canvas
        if row_canvases[row] then
          row_canvases[row]:update()
        end
      else
        print("DEBUG: No automation found for " .. param_name .. " - keeping user-drawn data")
      end
    end
  end
  
  print("DEBUG: Automation refresh complete")
end

-- Smart device switching when all parameters of current device are used
function PakettiHyperEditTrySwitchDevice(row, current_device_name, used_param_names)
  -- Device switching priority based on current device
  local device_switch_map = {
    ["Wavetable Mod *LFO"] = {"*Instr. Macros"},
    ["*Instr. Macros"] = {"AU: Valhalla DSP, LLC: ValhallaDelay", "AU: Valhalla DSP, LLC: ValhallaVintageVerb"},
    -- Add more device switching rules as needed
  }
  
  local preferred_devices = device_switch_map[current_device_name]
  if not preferred_devices then
    print("DEBUG: SMART-SWITCH: No switching rules for device: " .. current_device_name)
    return nil
  end
  
  -- Try each preferred device in order
  for _, preferred_device_name in ipairs(preferred_devices) do
    -- Find this device in the available device list
    local target_device_info = nil
    local target_device_index = nil
    
    for i, device_info in ipairs(device_lists[row]) do
      if device_info.name == preferred_device_name then
        target_device_info = device_info
        target_device_index = i
        break
      end
    end
    
    if target_device_info then
      -- Check if this target device has unused parameters
      local target_params = PakettiHyperEditGetParameters(target_device_info.device)
      local has_unused_params = false
      
      for _, param_info in ipairs(target_params) do
        if not used_param_names[param_info.name] then
          has_unused_params = true
          break
        end
      end
      
      if has_unused_params then
        print("DEBUG: SMART-SWITCH: Found suitable target device: " .. preferred_device_name .. " with unused parameters")
        
        -- Switch to the target device
        row_devices[row] = target_device_info.device
        parameter_lists[row] = target_params
        
        -- Update device dropdown
        local device_popup = dialog_vb and dialog_vb.views["device_popup_" .. row]
        if device_popup then
          device_popup.value = target_device_index
        end
        
        -- Update parameter dropdown
        local param_popup = dialog_vb and dialog_vb.views["parameter_popup_" .. row]
        if param_popup then
          local param_names = {}
          for _, p in ipairs(target_params) do
            table.insert(param_names, p.name)
          end
          param_popup.items = param_names
          
          -- Find first unused parameter
          for i, param_info in ipairs(target_params) do
            if not used_param_names[param_info.name] then
              param_popup.value = i
              PakettiHyperEditSelectParameter(row, i)
              break
            end
          end
        end
        
        return target_device_info
      else
        print("DEBUG: SMART-SWITCH: Target device " .. preferred_device_name .. " has no unused parameters")
      end
    else
      print("DEBUG: SMART-SWITCH: Target device " .. preferred_device_name .. " not available on this track")
    end
  end
  
  print("DEBUG: SMART-SWITCH: No suitable device switch found for " .. current_device_name)
  return nil
end

-- Select device for specific row
function PakettiHyperEditSelectDevice(row, device_index)
  print("DEBUG: PakettiHyperEditSelectDevice called for row " .. row .. " with device_index " .. device_index)
  
  -- DEBUG: Show device_lists[row] state
  if not device_lists[row] then
    print("DEBUG: Row " .. row .. " - device_lists[row] is nil")
  else
    print("DEBUG: Row " .. row .. " - device_lists[row] has " .. #device_lists[row] .. " devices")
  end
  
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
    
    if #parameter_lists[row] > 0 and not is_updating_device_lists then
      -- Simple default: select first parameter (automation re-read will fix this properly)
      -- Skip during device list updates to allow smart assignment to handle deduplication
      param_popup.value = 1
      PakettiHyperEditSelectParameter(row, 1)
    elseif is_updating_device_lists then
      print("DEBUG: Skipping auto-parameter assignment for row " .. row .. " - letting smart assignment handle deduplication")
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
  
  -- CRITICAL: Skip auto-read during device list updates to preserve existing step data
  if not is_updating_device_lists then
    -- Auto-read automation when parameter is selected
    PakettiHyperEditAutoReadAutomation(row)
  else
    print("DEBUG: Skipping auto-read for " .. param_info.name .. " during device list update - preserving existing step data")
  end
  
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
      last_mouse_move_time = os.clock() * 1000 -- Set initial timestamp
      
      -- Check for right-click or Ctrl+click to delete automation envelope
      if ev.button == "right" or (ev.button == "left" and ev.modifiers == "control") then
        PakettiHyperEditDeleteAutomation(row)
      else
        -- Regular left-click
        PakettiHyperEditHandleRowClick(row, x, y)
      end
    elseif ev.type == "up" then
      mouse_is_down = false
      current_row_drawing = 0
    elseif ev.type == "move" and mouse_is_down and current_row_drawing == row then
      last_mouse_move_time = os.clock() * 1000 -- Update timestamp on move
      PakettiHyperEditHandleRowClick(row, x, y)
    elseif ev.type == "double" then
      -- Double-click special behaviors for different parameter types
      if row_parameters[row] and row_parameters[row].parameter then
        local param_name = row_parameters[row].name:lower()
        
        -- Calculate which step was double-clicked
        local content_margin = 3
        local content_x = content_margin
        local content_width = canvas_width - (content_margin * 2)
        local row_step_count = row_steps[row] or 16
        local step_width = content_width / row_step_count
        local step = math.floor((x - content_x) / step_width) + 1
        step = math.max(1, math.min(row_step_count, step))
        
        if not step_active[row] then step_active[row] = {} end
        if not step_data[row] then step_data[row] = {} end
        
        local new_value = 0.5  -- Default center value
        
        if row_parameters[row].is_custom_mapped and param_name == "gain" then
          -- Gainer Gain: Toggle between 0.0 (silent) and 1.0 (0dB/unity)
          local current_value = step_data[row][step] or 0.5
          if math.abs(current_value - 1.0) < 0.01 then
            -- Currently at unity gain (1.0) → set to silent (0.0)
            new_value = 0.0
            print("DEBUG: Gainer double-click - Unity → Silent")
          else
            -- Currently at anything else → set to unity gain (1.0)
            new_value = 1.0
            print("DEBUG: Gainer double-click - " .. string.format("%.2f", current_value) .. " → Unity")
          end
        elseif param_name:find("pitch") or param_name:find("bend") then
          -- Pitchbend: Center to 0.5
          new_value = 0.5
          print("DEBUG: Pitchbend double-click - Center")
        end
        
        step_active[row][step] = true
        step_data[row][step] = new_value
        
        -- Apply immediately
        PakettiHyperEditApplyStep(row, step)
        
        -- Update canvas
        if row_canvases[row] then
          row_canvases[row]:update()
        end
        
        local action_desc = "set to " .. string.format("%.2f", new_value)
        if row_parameters[row].is_custom_mapped and param_name == "gain" then
          action_desc = new_value == 1.0 and "set to Unity Gain" or "set to Silent"
        elseif param_name:find("pitch") or param_name:find("bend") then
          action_desc = "centered"
        end
        
        renoise.app():show_status("HyperEdit Row " .. row .. ": " .. action_desc .. " at step " .. step)
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

-- Delete automation envelope for a row
function PakettiHyperEditDeleteAutomation(row)
  if not row_parameters[row] then 
    renoise.app():show_status("HyperEdit Row " .. row .. ": No parameter selected")
    return 
  end
  
  local song = renoise.song()
  if not song then return end
  
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  local parameter = row_parameters[row].parameter
  
  -- Delete the automation envelope
  pattern_track:delete_automation(parameter)
  
  -- Clear visual canvas data for this row
  for step = 1, MAX_STEPS do
    step_active[row][step] = false
    step_data[row][step] = 0.5  -- Reset to center value
  end
  
  -- Redraw the canvas
  if row_canvases[row] then
    row_canvases[row]:update()
  end
  
  local param_name = row_parameters[row].name or "Unknown"
  renoise.app():show_status("HyperEdit Row " .. row .. ": Deleted automation for " .. param_name)
  print("DEBUG: Deleted automation for row " .. row .. " parameter: " .. param_name)
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
  
  -- Get or create automation
  local parameter = row_parameters[row].parameter
  local automation = pattern_track:find_automation(parameter)
  if not automation then
    automation = pattern_track:create_automation(parameter)
  end
  
  print("DEBUG: Writing parameter automation for " .. row_parameters[row].name)
  
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
        
        -- Apply custom mapping for special devices
        if row_parameters[row].is_custom_mapped then
          -- For Gainer: HyperEdit 0.0-1.0 maps to Renoise 0.0-1.0 (not 0.0-4.0)
          param_value = param_value -- param_value is already 0.0-1.0 from our custom range
          print("DEBUG: Custom mapping - HyperEdit " .. step_value .. " → Renoise " .. param_value)
        end
        
        -- Normalize for automation (0.0-1.0)
        local original_min = row_parameters[row].original_min or parameter.value_min
        local original_max = row_parameters[row].original_max or parameter.value_max
        local normalized_value = (param_value - original_min) / (original_max - original_min)
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
  
  -- Skip auto-read during track switching to prevent interference
  if is_track_switching then
    print("DEBUG: Skipping auto-read automation during track switching for row " .. row)
    return
  end
  
  -- Skip auto-read during device list updates to preserve existing data
  if is_updating_device_lists then
    print("DEBUG: Skipping auto-read automation during device list update for row " .. row .. " - preserving existing step data")
    return
  end
  
  local song = renoise.song()
  if not song then return end
  
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  
  -- Find existing automation
  local parameter = row_parameters[row].parameter
  local automation = pattern_track:find_automation(parameter)
  
  print("DEBUG: Looking for parameter automation for " .. row_parameters[row].name)
  if not automation then
    -- CRITICAL: Don't clear step data during device list updates - preserve existing data
    if not is_updating_device_lists then
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
    else
      print("DEBUG: No automation found for " .. row_parameters[row].name .. " - preserving existing step data during device list update")
    end
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
  
  -- Update step count button colors
  PakettiHyperEditUpdateStepButtonColors(row)
  
  -- CRITICAL: Don't clear existing step data during device list updates - preserve it
  if not is_updating_device_lists then
    -- Clear existing step data
    for step = 1, MAX_STEPS do
      step_active[row][step] = false
      step_data[row][step] = 0.5
    end
  end
  
  local points_read = 0
  
  -- Read automation points and consolidate to detected pattern length
  for _, point in ipairs(automation.points) do
    local step = point.time
    local value = point.value  -- Already 0.0-1.0
    
    -- Apply reverse custom mapping for special devices
    if row_parameters[row].is_custom_mapped then
      -- For Gainer: Convert Renoise automation (normalized from 0.0-4.0) back to HyperEdit 0.0-1.0
      local original_min = row_parameters[row].original_min or 0.0
      local original_max = row_parameters[row].original_max or 4.0
      local actual_renoise_value = original_min + (value * (original_max - original_min))
      value = math.max(0.0, math.min(1.0, actual_renoise_value / 1.0)) -- Map 0.0-1.0 renoise to 0.0-1.0 hyperedit
      print("DEBUG: Reverse mapping (auto-read) - Renoise " .. actual_renoise_value .. " → HyperEdit " .. value)
    end
    
    if step >= 1 and step <= MAX_STEPS then
      -- Map to the detected pattern length (consolidate repeating patterns)
      local consolidated_step = ((step - 1) % detected_step_count) + 1
      step_active[row][consolidated_step] = true
      step_data[row][consolidated_step] = value
      points_read = points_read + 1
      
      --if consolidated_step ~= step then
        --print("DEBUG: Consolidated step " .. step .. " → " .. consolidated_step .. " (pattern length: " .. detected_step_count .. ")")
      --end
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
  
  -- CRITICAL: Only clear data if NOT during device updates (preserve existing canvas data)
  if not is_updating_device_lists then
    print("DEBUG: Clearing all existing row data to prevent duplicates")
    for row = 1, NUM_ROWS do
      row_devices[row] = nil
      row_parameters[row] = nil
      parameter_lists[row] = nil
      device_lists[row] = nil
    end
  else
    print("DEBUG: Device update in progress - preserving existing row data, only updating assignments")
  end
  
  local song = renoise.song()
  if not song then 
    print("DEBUG: No song available")
    return 
  end
  
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  local track = song.tracks[track_index]
  
  print("DEBUG: Scanning pattern " .. current_pattern .. ", track " .. track_index .. " (" .. track.name .. ")")
  print("DEBUG: Track has " .. #track.devices .. " devices, pattern_track: " .. (pattern_track and "valid" or "nil"))
  
  -- Clean automation detection approach (based on PakettiAutomationStack.lua)
  local found_automations = {}
  
  if not track then
    print("DEBUG: No track available")
    return
  end
  
  -- Get device list for UI consistency
  local device_list = PakettiHyperEditGetDevices()
  local device_names = {}
  for i, device_info in ipairs(device_list) do
    table.insert(device_names, device_info.name)
  end
  if #device_names == 0 then
    device_names = {"No devices available"}
  end
  
  -- Method: Scan devices and parameters (clean approach from AutomationStack)
  -- Skip device 1 (Track Vol/Pan) to match UI device list
  print("DEBUG: === Clean Device/Parameter Scan ===")
  for d = 2, #track.devices do
    local dev = track.devices[d]
    local device_name = dev.display_name or "Device"
    print("DEBUG: Scanning device " .. d .. ": " .. device_name)
    
    
    for pi = 1, #dev.parameters do
      local param = dev.parameters[pi]
      if param.is_automatable then
        local a = pattern_track:find_automation(param)
        if a then
          print("DEBUG: Found automation for " .. device_name .. " -> " .. (param.name or "Parameter"))
          
        -- Find the matching device in device_list for UI consistency
        local ui_device_idx = nil
        print("DEBUG: Looking for device '" .. device_name .. "' in UI device list of " .. #device_list .. " devices")
        for ui_idx, ui_device_info in ipairs(device_list) do
          print("DEBUG:   UI device " .. ui_idx .. ": " .. ui_device_info.name)
          if ui_device_info.device.display_name == dev.display_name then
            ui_device_idx = ui_idx
            print("DEBUG:   FOUND MATCH at UI index " .. ui_idx)
            break
          end
        end
        
        if not ui_device_idx then
          print("DEBUG:   NO MATCH FOUND for device '" .. device_name .. "'")
        end
          
          -- Store automation data with all needed info
          local automation_data = {
            automation = a,
            parameter = param,
            device_idx = ui_device_idx or d, -- Use UI index if found, otherwise track device index
            param_idx = pi,
            device_info = { device = dev, name = device_name }
          }
          found_automations[#found_automations + 1] = automation_data
        else
          print("DEBUG: Checking for automation points on " .. device_name .. " -> " .. (param.name or "Parameter"))
        end
      end
      
    end
    if d > 1 then -- Skip Track Vol/Pan device when counting
      local device_automation_count = 0
      for pi = 1, #dev.parameters do
        local param = dev.parameters[pi]
        if param.is_automatable then
          local a = pattern_track:find_automation(param)
          if a then device_automation_count = device_automation_count + 1 end
        end
      end
      if device_automation_count == 0 then
        print("DEBUG: No automation found on device " .. device_name)
      else
        print("DEBUG: Found " .. device_automation_count .. " automations on " .. device_name)
      end
    end
  end
  
  
  -- Note: Direct pattern track automation access not available in Renoise API
  -- Using device/parameter scan method only (which is the correct approach)
  
  -- CRITICAL: Update ALL UI popups with current track's device list FIRST
  -- This prevents popup index out of range errors when switching tracks
  print("DEBUG: Updating all UI popups with current track's device list (" .. #device_list .. " devices)")
  for row = 1, NUM_ROWS do
    if dialog_vb and dialog_vb.views["device_popup_" .. row] then
      local device_popup = dialog_vb.views["device_popup_" .. row]
      device_popup.items = device_names
      device_popup.value = 1 -- Safe default
      device_lists[row] = device_list -- Update the row's device list
    end
    if dialog_vb and dialog_vb.views["parameter_popup_" .. row] then
      dialog_vb.views["parameter_popup_" .. row].items = {"Select device first"}
      dialog_vb.views["parameter_popup_" .. row].value = 1
    end
  end
  
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
      
      -- Update canvases to show empty state
      if row_canvases[row] then
        row_canvases[row]:update()
      end
    end
    
    print("DEBUG: All rows cleared for track with no automation")
    return
  end
  
  print("DEBUG: Found " .. #found_automations .. " automation envelopes - populating rows")
  
  -- Take all available automations and assign to rows (up to 32 max)
  -- ANTI-DUPLICATE: Track used parameter names to avoid duplicates like multiple "Mix" parameters
  local used_parameter_names = {}
  local populated_rows = 0
  local max_automations = math.min(32, #found_automations)  -- Cap at 32 rows max
  
  for _, automation_data in ipairs(found_automations) do
    if populated_rows >= max_automations then break end  -- Use all available automations
    
    local row = populated_rows + 1
    local automation = automation_data.automation
    local parameter = automation_data.parameter
    local param_name = parameter.name
    
    -- ANTI-DUPLICATE: If this parameter name is already used, find the NEXT parameter from same device
    local should_process_row = true  -- Flag to track if we should process this row
    
    if used_parameter_names[param_name] then
      print("DEBUG: Parameter name '" .. param_name .. "' already used - looking for next parameter from same device")
      
      -- Get device's parameter list to find what comes after this duplicate parameter
      local device_params = PakettiHyperEditGetParameters(automation_data.device_info.device)
      local current_param_index = nil
      
      -- Find current parameter's index in the device
      for i, param_info in ipairs(device_params) do
        if param_info.parameter.name == param_name then
          current_param_index = i
          break
        end
      end
      
      -- Look for next available parameter from same device that's not already used
      local next_param_found = false
      if current_param_index then
        for next_i = current_param_index + 1, #device_params do
          local next_param_info = device_params[next_i]
          local next_param_name = next_param_info.parameter.name
          
          if not used_parameter_names[next_param_name] then
            -- Check if this next parameter has automation
            local track_index = renoise.song().selected_track_index
            local pattern_track = renoise.song():pattern(renoise.song().selected_pattern_index):track(track_index)
            local next_automation = pattern_track:find_automation(next_param_info.parameter)
            
            if next_automation then
              print("DEBUG: Found next parameter with automation: '" .. next_param_name .. "' (was going to use duplicate '" .. param_name .. "')")
              -- Use the next parameter instead
              automation_data.parameter = next_param_info.parameter
              automation_data.automation = next_automation
              automation_data.param_idx = next_i
              param_name = next_param_name
              next_param_found = true
              break
            end
          end
        end
      end
      
      -- If no suitable next parameter found, skip this duplicate entirely
      if not next_param_found then
        print("DEBUG: No suitable next parameter found for duplicate '" .. param_name .. "' - skipping this automation")
        should_process_row = false
      end
    end
    
    -- Only process this row if we found a valid (non-duplicate) parameter
    if should_process_row then
      -- Mark this parameter name as used
      used_parameter_names[param_name] = true
      
      print("DEBUG: Row " .. row .. " → " .. param_name)
      
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
      row_devices[row] = device_list[found_device_idx].device
      parameter_lists[row] = PakettiHyperEditGetParameters(row_devices[row])
      row_parameters[row] = parameter_lists[row][found_param_idx]
      
      -- Update UI dropdowns (popups already updated with correct device list above)
      print("DEBUG: Updating UI for row " .. row .. " - device idx " .. found_device_idx .. ", param idx " .. found_param_idx)
      
      if dialog_vb and dialog_vb.views["device_popup_" .. row] then
        local ui_device_popup = dialog_vb.views["device_popup_" .. row]
        -- Since we already updated all popups with current device_list, we can use found_device_idx directly
        local max_items = #device_list
        if found_device_idx > 0 and found_device_idx <= max_items then
          ui_device_popup.value = found_device_idx
          print("DEBUG: Set device dropdown for row " .. row .. " to index " .. found_device_idx)
        else
          print("DEBUG: ERROR - Device index " .. found_device_idx .. " out of range (max: " .. max_items .. ") for row " .. row)
          ui_device_popup.value = 1  -- Safe fallback
        end
      else
        print("DEBUG: ERROR - Could not find device_popup_" .. row)
      end
      
      if dialog_vb and dialog_vb.views["parameter_popup_" .. row] then
        local param_names = {}
        for i, param_info in ipairs(parameter_lists[row]) do
          table.insert(param_names, param_info.name)
        end
        dialog_vb.views["parameter_popup_" .. row].items = param_names
        -- Validate parameter index before setting it
        if found_param_idx > 0 and found_param_idx <= #param_names then
          dialog_vb.views["parameter_popup_" .. row].value = found_param_idx
          print("DEBUG: Set parameter dropdown for row " .. row .. " to '" .. parameter.name .. "' at index " .. found_param_idx)
        else
          print("DEBUG: ERROR - Parameter index " .. found_param_idx .. " out of range (max: " .. #param_names .. ") for row " .. row)
          dialog_vb.views["parameter_popup_" .. row].value = 1  -- Safe fallback
        end
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
      
      -- Update step count button colors
      PakettiHyperEditUpdateStepButtonColors(row)
      
      -- Read automation points and consolidate to detected pattern length
      local points_read = 0
      for _, point in ipairs(automation.points) do
        local step = point.time
        local value = point.value  -- Already 0.0-1.0
        
        -- Apply reverse custom mapping for special devices
        if row_parameters[row].is_custom_mapped then
          -- For Gainer: Convert Renoise automation (normalized from 0.0-4.0) back to HyperEdit 0.0-1.0
          local original_min = row_parameters[row].original_min or 0.0
          local original_max = row_parameters[row].original_max or 4.0
          local actual_renoise_value = original_min + (value * (original_max - original_min))
          value = math.max(0.0, math.min(1.0, actual_renoise_value / 1.0)) -- Map 0.0-1.0 renoise to 0.0-1.0 hyperedit
          print("DEBUG: Reverse mapping (populate) - Renoise " .. actual_renoise_value .. " → HyperEdit " .. value)
        end
        
        if step >= 1 and step <= MAX_STEPS then
          -- Map to the detected pattern length (consolidate repeating patterns)
          local consolidated_step = ((step - 1) % detected_step_count) + 1
          step_active[row][consolidated_step] = true
          step_data[row][consolidated_step] = value
          points_read = points_read + 1
          
          --if consolidated_step ~= step then
            --print("DEBUG: Consolidated step " .. step .. " → " .. consolidated_step .. " (pattern length: " .. detected_step_count .. ")")
          --end
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
    end  -- End of should_process_row conditional
  end
  
  print("DEBUG: Successfully populated " .. populated_rows .. " rows with existing automation")
  
  -- Auto-adjust NUM_ROWS if we found more automations than current setting (only if auto-fit is enabled)
  if populated_rows > NUM_ROWS and preferences and preferences.PakettiHyperEditAutoFit and preferences.PakettiHyperEditAutoFit.value then
    print("DEBUG: Found " .. populated_rows .. " automations but NUM_ROWS was only " .. NUM_ROWS .. " - expanding to show all")
    local old_num_rows = NUM_ROWS
    NUM_ROWS = populated_rows
    
    -- Update preferences to persist the change
    if preferences.PakettiHyperEditRowCount then
      preferences.PakettiHyperEditRowCount.value = NUM_ROWS
      preferences:save_as("preferences.xml")
    end
    
    print("DEBUG: NUM_ROWS expanded from " .. old_num_rows .. " to " .. NUM_ROWS .. " - dialog recreation needed")
    renoise.app():show_status("HyperEdit: Auto-expanded to " .. populated_rows .. " rows - reopening dialog...")
    
    -- Close current dialog and reopen with new row count
    if hyperedit_dialog then
      hyperedit_dialog:close()
      -- Reopen after a brief delay to ensure cleanup is complete
      local reopen_timer
      reopen_timer = function()
        PakettiHyperEditInit()
        renoise.tool():remove_timer(reopen_timer)
      end
      renoise.tool():add_timer(reopen_timer, 100)
    end
  elseif populated_rows > 0 then
    renoise.app():show_status("HyperEdit: Loaded " .. populated_rows .. " existing automations into rows")
  end
  
  -- Ensure track switching flag is always cleared after automation population
  is_track_switching = false
  print("DEBUG: === Automation population complete - track switching flag cleared ===")
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
    
    -- Calculate step width for later use
    local step_width = content_width / row_step_count
    
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
    
    
    -- Draw content area border (like PakettiCanvasExperiments) with track color if enabled
    if preferences.PakettiHyperEditCaptureTrackColor.value then
      local track_color = PakettiHyperEditGetTrackColor()
      ctx.stroke_color = {track_color[1], track_color[2], track_color[3], 255}
    else
      ctx.stroke_color = {80, 0, 120, 255}  -- Default purple border
    end
    ctx.line_width = 2
    ctx:begin_path()
    ctx:rect(content_x, content_y, content_width, content_height)
    ctx:stroke()
    
    -- Draw grid lines OVER the content area border
    -- Adaptive line width based on step density to preserve visibility (minimum 1px to avoid spikes)
    local adaptive_line_width
    if step_width >= 20 then
      adaptive_line_width = 2  -- Wide steps: medium lines
    elseif step_width >= 10 then
      adaptive_line_width = 1  -- Medium steps: thin lines  
    else
      adaptive_line_width = 1  -- Narrow/very narrow steps: minimum 1px to avoid spiky appearance
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
        ctx:move_to(x, content_y - 1)
        ctx:line_to(x, content_y + content_height + 1)
        ctx:stroke()
      end
    end
    
    -- Draw playhead indicator line ON TOP of grid lines if playhead is active
    if playhead_color and playhead_step_indices[row] then
      local playhead_step = playhead_step_indices[row]
      if playhead_step >= 1 and playhead_step <= row_step_count then
        local playhead_x = content_x + ((playhead_step - 1) * step_width) + (step_width / 2)
        
        ctx.stroke_color = playhead_color
        ctx.line_width = 2
        ctx:begin_path()
        ctx:move_to(playhead_x, content_y + 4)
        ctx:line_to(playhead_x, content_y + content_height - 1)
        ctx:stroke()
        
        -- Draw playhead triangle at top
        ctx.fill_color = playhead_color
        ctx:begin_path()
        ctx:move_to(playhead_x, content_y + 6)
        ctx:line_to(playhead_x - 4, content_y + 1)
        ctx:line_to(playhead_x + 4, content_y + 1)
        ctx:close_path()
        ctx:fill()
      end
    end
    
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
        
        -- Set flag to prevent auto-read automation from interfering
        is_track_switching = true
        
        -- Clear old step data first
        PakettiHyperEditInitStepData()
        
        -- Update device lists and observers
        PakettiHyperEditSetupDeviceObserver()
        
        -- CRITICAL: Populate automation FIRST, before updating device lists
        -- This prevents PakettiHyperEditSelectDevice from clearing automation data
        PakettiHyperEditPopulateFromExistingAutomation()
        
        -- Clear flag IMMEDIATELY after automation population so auto-read works
        is_track_switching = false
        print("DEBUG: === Track switching flag cleared - auto-read now enabled ===")
        
        -- Update device lists (this may call SelectDevice and auto-read automation now)
        PakettiHyperEditUpdateAllDeviceLists()
        
        -- CRITICAL: Smart assignment for free rows after track change
        print("DEBUG: Running smart parameter assignment for free rows after track change")
        
        -- DEBUG: Check row states
        for debug_row = 1, NUM_ROWS do
          local has_device = row_devices[debug_row] and "YES" or "NO"
          local has_param = row_parameters[debug_row] and "YES" or "NO"
          print("DEBUG: Row " .. debug_row .. " - Device: " .. has_device .. ", Parameter: " .. has_param)
        end
        
        -- First, collect what parameters are already in use
        local used_param_names = {}
        for check_row = 1, NUM_ROWS do
          if row_parameters[check_row] then
            used_param_names[row_parameters[check_row].name] = true
            print("DEBUG: Row " .. check_row .. " already uses parameter: " .. row_parameters[check_row].name)
          end
        end
        
        -- Assign parameters to free rows (have device but no parameter)
        for row = 1, NUM_ROWS do
          if row_devices[row] and not row_parameters[row] then
            print("DEBUG: Row " .. row .. " has device but no parameter - assigning smart parameter")
            
            local params = parameter_lists[row] or PakettiHyperEditGetParameters(row_devices[row])
            if params and #params > 0 then
              -- Find first unused parameter in this device
              local assigned = false
              for i, param_info in ipairs(params) do
                if not used_param_names[param_info.name] then
                  -- Found unused parameter - assign it
                  used_param_names[param_info.name] = true -- Mark as used
                  row_parameters[row] = param_info
                  print("DEBUG: Row " .. row .. " assigned parameter: " .. param_info.name)
                  
                  -- Update parameter dropdown
                  if dialog_vb and dialog_vb.views["parameter_popup_" .. row] then
                    dialog_vb.views["parameter_popup_" .. row].value = i
                  end
                  
                  assigned = true
                  break
                end
              end
              
              if not assigned then
                print("DEBUG: Row " .. row .. " - all parameters already used, taking first parameter")
                row_parameters[row] = params[1]
                if dialog_vb and dialog_vb.views["parameter_popup_" .. row] then
                  dialog_vb.views["parameter_popup_" .. row].value = 1
                end
              end
            end
          end
        end
        
        -- Update colors if track color capture is enabled
        if preferences.PakettiHyperEditCaptureTrackColor.value then
          PakettiHyperEditUpdateColors()
        else
          -- Update step count button colors even if track color capture is disabled
          for row = 1, NUM_ROWS do
            PakettiHyperEditUpdateStepButtonColors(row)
          end
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
        print("DEBUG: === Device changed - using EXACT same logic as dialog initialization ===")
        
        -- CRITICAL: Use the EXACT same initialization sequence that works when dialog opens
        -- This ensures we get identical behavior and automation reading
        
        -- Step 1: Clear step data
        PakettiHyperEditInitStepData()
        
        -- Step 2: Get updated device list
        local devices = PakettiHyperEditGetDevices()
        if #devices == 0 then
          print("DEBUG: No devices available after device change")
          return
        end
        
        -- Step 3: Force fresh references - add small delay to ensure device changes are fully processed
        local timer_func
        timer_func = function()
          print("DEBUG: Device change - calling PopulateFromExistingAutomation with FRESH references")
          PakettiHyperEditPopulateFromExistingAutomation()
          
          -- Step 4: Update device dropdowns AFTER automation population (with fresh references)
          local fresh_devices = PakettiHyperEditGetDevices() -- Get fresh device list
          local device_names = {}
          for i, device_info in ipairs(fresh_devices) do
            table.insert(device_names, device_info.name)
          end
          
          for row = 1, NUM_ROWS do
            if dialog_vb and dialog_vb.views["device_popup_" .. row] then
              local device_popup = dialog_vb.views["device_popup_" .. row]
              device_popup.items = device_names
              
              -- CRITICAL: If this row's device dropdown shows a device, update its parameter dropdown
              local selected_device_idx = device_popup.value
              if selected_device_idx > 0 and selected_device_idx <= #fresh_devices then
                local device_info = fresh_devices[selected_device_idx]
                device_lists[row] = fresh_devices
                row_devices[row] = device_info.device
                parameter_lists[row] = PakettiHyperEditGetParameters(device_info.device)
                
                -- Update parameter dropdown items only - let existing logic handle parameter selection
                local param_popup = dialog_vb.views["parameter_popup_" .. row]
                if param_popup and #parameter_lists[row] > 0 then
                  local param_names = {}
                  for j, param_info in ipairs(parameter_lists[row]) do
                    table.insert(param_names, param_info.name)
                  end
                  param_popup.items = param_names
                  -- DON'T automatically select parameter - let deduplication logic handle it
                  print("DEBUG: Updated parameter dropdown items for row " .. row .. " device: " .. device_info.name)
                  
                  -- DEBUG: Show what parameter is currently selected for this row
                  local current_param_name = "NONE"
                  if row_parameters[row] and row_parameters[row].name then
                    current_param_name = row_parameters[row].name
                  elseif param_popup.value > 0 and param_popup.value <= #param_names then
                    current_param_name = param_names[param_popup.value] .. " (dropdown default)"
                  end
                  print("DEBUG: Row " .. row .. " parameter assignment: " .. current_param_name)
                else
                  -- Clear parameter dropdown if no parameters available
                  if param_popup then
                    param_popup.items = {"Select device first"}
                    param_popup.value = 1
                  end
                end
              end
            end
          end
          
          -- CRITICAL: Smart assignment for free rows (with device but no parameter)
          print("DEBUG: Running smart parameter assignment for free rows")
          
          -- First, collect what parameters are already in use
          local used_param_names = {}
          for check_row = 1, NUM_ROWS do
            if row_parameters[check_row] then
              used_param_names[row_parameters[check_row].name] = true
              print("DEBUG: Row " .. check_row .. " already uses parameter: " .. row_parameters[check_row].name)
            end
          end
          
          -- Assign parameters to free rows (have device but no parameter)
          for row = 1, NUM_ROWS do
            if row_devices[row] and not row_parameters[row] then
              print("DEBUG: Row " .. row .. " has device but no parameter - assigning smart parameter")
              
              local params = parameter_lists[row] or PakettiHyperEditGetParameters(row_devices[row])
              if params and #params > 0 then
                -- Find first unused parameter in this device
                local assigned = false
                for i, param_info in ipairs(params) do
                  if not used_param_names[param_info.name] then
                    -- Found unused parameter - assign it
                    used_param_names[param_info.name] = true -- Mark as used
                    row_parameters[row] = param_info
                    print("DEBUG: Row " .. row .. " assigned parameter: " .. param_info.name)
                    
                    -- Update parameter dropdown
                    if dialog_vb and dialog_vb.views["parameter_popup_" .. row] then
                      dialog_vb.views["parameter_popup_" .. row].value = i
                    end
                    
                    assigned = true
                    break
                  end
                end
                
                if not assigned then
                  print("DEBUG: Row " .. row .. " - all parameters already used, taking first parameter")
                  row_parameters[row] = params[1]
                  if dialog_vb and dialog_vb.views["parameter_popup_" .. row] then
                    dialog_vb.views["parameter_popup_" .. row].value = 1
                  end
                end
              end
            end
          end
          
          -- Refresh canvases after automation population and dropdown updates
          for row = 1, NUM_ROWS do
            if row_canvases[row] then
              row_canvases[row]:update()
            end
          end
          
          -- Remove the timer after execution
          renoise.tool():remove_timer(timer_func)
        end
        
        -- Only add timer if it doesn't already exist (prevent rapid device change overlaps)
        if not renoise.tool():has_timer(timer_func) then
          renoise.tool():add_timer(timer_func, 10) -- 10ms delay to ensure stale references are cleared
        end
        
        print("DEBUG: === Device change using dialog initialization logic complete ===")
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
--- Update step count button colors for a specific row
function PakettiHyperEditUpdateStepButtonColors(row)
  if not dialog_vb then return end
  
  local step_counts = {1, 2, 4, 8, 16, 32, 48, 64, 96, 112, 128, 192, 256}
  local active_color = {0x00, 0x80, 0x00}  -- Default green for active step count
  local inactive_color = {0x40, 0x40, 0x40}  -- Default button color for inactive
  
  -- Use track color if "Capture Track Color" is enabled
  if preferences.PakettiHyperEditCaptureTrackColor.value then
    local track_color = PakettiHyperEditGetTrackColor()
    if track_color then
      active_color = track_color
    end
  end
  
  for _, step_count in ipairs(step_counts) do
    local button_id = "step_btn_" .. row .. "_" .. step_count
    if dialog_vb.views[button_id] then
      -- Use active color for current step count, inactive color for others (never nil)
      dialog_vb.views[button_id].color = (row_steps[row] == step_count) and active_color or inactive_color
    end
  end
end

function PakettiHyperEditChangeRowStepCount(row, steps)
  row_steps[row] = steps
  
  -- Update button colors to highlight the new step count
  PakettiHyperEditUpdateStepButtonColors(row)
  
  -- Update only this row's canvas
  if row_canvases[row] then
    row_canvases[row]:update()
  end
  renoise.app():show_status("HyperEdit Row " .. row .. ": Changed to " .. steps .. " steps")
end

-- Clear all automation data AND visual canvas
function PakettiHyperEditClearAll()
  local song = renoise.song()
  if not song then return end
  
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  local cleared_count = 0
  
  -- Clear automation for each row that has a parameter selected
  for row = 1, NUM_ROWS do
    if row_parameters[row] then
      -- Find parameter automation
      local automation = pattern_track:find_automation(row_parameters[row].parameter)
      
      if automation and #automation.points > 0 then
        -- Clear all automation points
        automation.points = {}
        cleared_count = cleared_count + 1
        print("DEBUG: Cleared automation for row " .. row .. " parameter: " .. parameter.name)
      end
    end
  end
  
  -- Clear visual canvas data
  PakettiHyperEditInitStepData()
  for row = 1, NUM_ROWS do
    if row_canvases[row] then
      row_canvases[row]:update()
    end
  end
  
  if cleared_count > 0 then
    renoise.app():show_status("HyperEdit: Cleared " .. cleared_count .. " automation envelope(s) and canvas data")
  else
    renoise.app():show_status("HyperEdit: Cleared canvas data (no automation to clear)")
  end
end

-- DEBUG: Simple automation scanner - just print what exists
function PakettiHyperEditDebugAutomation()
  print("DEBUG: === AUTOMATION SCANNER ===")
  
  local song = renoise.song()
  if not song then 
    print("DEBUG: No song")
    return 
  end
  
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  local track = song.tracks[track_index]
  
  print("DEBUG: Pattern " .. current_pattern .. ", Track " .. track_index .. " (" .. track.name .. ")")
  print("DEBUG: Total devices on track: " .. #track.devices)
  
  local total_automations = 0
  
  -- Scan ALL devices (including Track Vol/Pan at index 1)
  for d = 1, #track.devices do
    local dev = track.devices[d]
    local device_name = dev.display_name or "Device"
    print("DEBUG: Device " .. d .. ": " .. device_name)
    
    local device_automations = 0
    
    for pi = 1, #dev.parameters do
      local param = dev.parameters[pi]
      if param.is_automatable then
        local a = pattern_track:find_automation(param)
        if a and #a.points > 0 then
          device_automations = device_automations + 1
          total_automations = total_automations + 1
          print("DEBUG:   → " .. (param.name or "Parameter") .. " (" .. #a.points .. " points)")
        end
      end
    end
    
    if device_automations == 0 then
      print("DEBUG:   → No automation")
    end
  end
  
  print("DEBUG: TOTAL AUTOMATION ENVELOPES: " .. total_automations)
  print("DEBUG: === END SCAN ===")
  renoise.app():show_status("HyperEdit DEBUG: Found " .. total_automations .. " automation envelopes - check console")
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
  PakettiHyperEditStopMouseMonitor()
  
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

-- Mouse state monitor to handle mouse releases outside canvas
function PakettiHyperEditStartMouseMonitor()
  -- Stop any existing monitor
  PakettiHyperEditStopMouseMonitor()
  
  -- Start new monitor that checks mouse state every 100ms
  mouse_state_monitor_timer = renoise.tool():add_timer(function()
    if not hyperedit_dialog or not hyperedit_dialog.visible then
      PakettiHyperEditStopMouseMonitor()
      return
    end
    
    -- If mouse is down but we haven't received a move event for 5000ms (5 seconds),
    -- assume mouse was released outside canvas (increased timeout for long holds)
    if mouse_is_down then
      local current_time = os.clock() * 1000 -- Convert to milliseconds
      if current_time - last_mouse_move_time > 5000 then
        print("DEBUG: Mouse release detected outside canvas - stopping drawing")
        mouse_is_down = false
        current_row_drawing = 0
        
        -- Update all canvases to reflect the stopped drawing
        for row = 1, NUM_ROWS do
          if row_canvases[row] then
            row_canvases[row]:update()
          end
        end
      end
    end
  end, 100)
  
  print("DEBUG: Mouse state monitor started")
end

function PakettiHyperEditStopMouseMonitor()
  if mouse_state_monitor_timer then
    renoise.tool():remove_timer(mouse_state_monitor_timer)
    mouse_state_monitor_timer = nil
    print("DEBUG: Mouse state monitor stopped")
  end
end

-- Create main dialog
function PakettiHyperEditCreateDialog()
  if hyperedit_dialog and hyperedit_dialog.visible then
    hyperedit_dialog:close()
  end
  
  -- Reset pre-configuration flag for new dialog
  pre_configuration_applied = false
  
  -- Update row count from preferences
  PakettiHyperEditUpdateRowCount()
  
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
      vb:checkbox {
        id = "capture_track_color",
        value = preferences.PakettiHyperEditCaptureTrackColor.value,
        notifier = function(value)
          print("DEBUG: === Capture Track Color checkbox toggled to: " .. tostring(value) .. " ===")
          preferences.PakettiHyperEditCaptureTrackColor.value = value
          preferences:save_as("preferences.xml")
          print("DEBUG: capture_track_color preference set to: " .. tostring(preferences.PakettiHyperEditCaptureTrackColor.value))
          
          print("DEBUG: About to call PakettiHyperEditUpdateColors()")
          PakettiHyperEditUpdateColors()
          print("DEBUG: PakettiHyperEditUpdateColors() completed")
          
          if value then
            renoise.app():show_status("HyperEdit: Using track color for active steps (saved to preferences)")
          else
            renoise.app():show_status("HyperEdit: Using default colors (saved to preferences)")
          end
          print("DEBUG: === Checkbox notifier complete ===")
        end
      },
      vb:text { text = "Capture Track Color", style="strong",font="bold",width = 120 },
      vb:text{text="|",style="strong",font="bold"},
      vb:checkbox {
        id = "auto_fit_checkbox",
        value = preferences.PakettiHyperEditAutoFit.value,
        notifier = function(value)
          preferences.PakettiHyperEditAutoFit.value = value
          preferences:save_as("preferences.xml")
          
          if value then
            -- Auto-fit enabled: check if we need to expand immediately
            local populated_rows = 0
            for row = 1, 32 do  -- Check all possible rows
              if row_parameters[row] then
                populated_rows = populated_rows + 1
              end
            end
            
            if populated_rows > NUM_ROWS then
              renoise.app():show_status("HyperEdit: Auto-fit enabled - expanding to " .. populated_rows .. " rows")
              -- Close and reopen dialog with expanded rows
              if hyperedit_dialog and hyperedit_dialog.visible then
                hyperedit_dialog:close()
                renoise.tool():add_timer(function()
                  PakettiHyperEditInit()
                  renoise.tool():remove_timer(PakettiHyperEditInit)
                end, 100)
              end
            else
              renoise.app():show_status("HyperEdit: Auto-fit enabled")
            end
          else
            -- Auto-fit disabled: switch to manual row count
            local manual_rows = preferences.PakettiHyperEditManualRows.value
            if manual_rows ~= NUM_ROWS then
              renoise.app():show_status("HyperEdit: Auto-fit disabled - switching to " .. manual_rows .. " rows")
              -- Close and reopen dialog with manual row count
              if hyperedit_dialog and hyperedit_dialog.visible then
                hyperedit_dialog:close()
                renoise.tool():add_timer(function()
                  PakettiHyperEditInit()
                  renoise.tool():remove_timer(PakettiHyperEditInit)
                end, 100)
              end
            else
              renoise.app():show_status("HyperEdit: Auto-fit disabled - using manual row count")
            end
          end
        end
      },
      vb:text { text = "Auto-Fit", style="strong",font="bold",width = 60 },
      vb:text{text="|",style="strong",font="bold"},
      vb:text { text = "Rows", width = 40, style="strong",font="bold" },
      vb:popup {
        id = "row_count_popup",
        items = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29", "30", "31", "32"},
        value = math.max(1, math.min(32, NUM_ROWS)), -- Direct mapping: NUM_ROWS = popup index
        width = 60,
        tooltip = "Number of parameter rows to display",
        notifier = function(index)
          local new_row_count = index -- Direct mapping: popup index = row count (1-32)
          
          if preferences then
            if preferences.PakettiHyperEditAutoFit and not preferences.PakettiHyperEditAutoFit.value then
              -- Auto-fit disabled: update manual row count
              if preferences.PakettiHyperEditManualRows then
                preferences.PakettiHyperEditManualRows.value = new_row_count
              end
            else
              -- Auto-fit enabled: update main row count
              if preferences.PakettiHyperEditRowCount then
                preferences.PakettiHyperEditRowCount.value = new_row_count
              end
            end
            preferences:save_as("preferences.xml")
          end
          
          renoise.app():show_status("HyperEdit: Changed to " .. new_row_count .. " rows - please reopen dialog")
          
          -- Close dialog to force recreation with new row count
          if hyperedit_dialog and hyperedit_dialog.visible then
            hyperedit_dialog:close()
            -- Reopen after a brief delay
            renoise.tool():add_timer(function()
              PakettiHyperEditInit()
              renoise.tool():remove_timer(PakettiHyperEditInit)
            end, 100)
          end
        end
      },
      --vb:space { width = 10 },
      vb:button {
        text = "Clear All",
        width = 70,
        notifier = function()
          PakettiHyperEditClearAll()
        end
      },
--[[      vb:space { width = 10 },
      vb:button {
        text = "DEBUG",
        width = 60,
        color = {0xFF, 0x80, 0x00},
        notifier = function()
          PakettiHyperEditDebugAutomation()
        end
      }]]--
    },
  }
  
  -- Create 8 rows
  for row = 1, NUM_ROWS do
    local row_content = vb:column {
      -- Row header with device/parameter selection and individual step count (no row labels, no read button)
      vb:row {
        -- Step count quick buttons (supports smart pattern detection with color highlighting)
        vb:button {
          id = "step_btn_" .. row .. "_1",
          text = "1",
          width = 20,
          color = (row_steps[row] == 1) and {0x00, 0x80, 0x00} or {0x40, 0x40, 0x40},
          tooltip = "Set step count to 1 (constant value)",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 1)
          end
        },
        vb:button {
          id = "step_btn_" .. row .. "_2",
          text = "2",
          width = 20,
          color = (row_steps[row] == 2) and {0x00, 0x80, 0x00} or {0x40, 0x40, 0x40},
          tooltip = "Set step count to 2",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 2)
          end
        },
        vb:button {
          id = "step_btn_" .. row .. "_4",
          text = "4", 
          width = 20,
          color = (row_steps[row] == 4) and {0x00, 0x80, 0x00} or {0x40, 0x40, 0x40},
          tooltip = "Set step count to 4",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 4)
          end
        },
        vb:button {
          id = "step_btn_" .. row .. "_8",
          text = "8",
          width = 20,
          color = (row_steps[row] == 8) and {0x00, 0x80, 0x00} or {0x40, 0x40, 0x40},
          tooltip = "Set step count to 8",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 8)
          end
        },
        vb:button {
          id = "step_btn_" .. row .. "_16",
          text = "16",
          width = 20,
          color = (row_steps[row] == 16) and {0x00, 0x80, 0x00} or {0x40, 0x40, 0x40},
          tooltip = "Set step count to 16",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 16)
          end
        },        
        vb:button {
          id = "step_btn_" .. row .. "_32",
          text = "32",
          width = 25,
          color = (row_steps[row] == 32) and {0x00, 0x80, 0x00} or {0x40, 0x40, 0x40},
          tooltip = "Set step count to 32",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 32)
          end
        },
        vb:button {
          id = "step_btn_" .. row .. "_48",
          text = "48",
          width = 25,
          color = (row_steps[row] == 48) and {0x00, 0x80, 0x00} or {0x40, 0x40, 0x40},
          tooltip = "Set step count to 48",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 48)
          end
        },
        vb:button {
          id = "step_btn_" .. row .. "_64",
          text = "64",
          width = 25,
          color = (row_steps[row] == 64) and {0x00, 0x80, 0x00} or {0x40, 0x40, 0x40},
          tooltip = "Set step count to 64",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 64)
          end
        },
        vb:button {
          id = "step_btn_" .. row .. "_96",
          text = "96",
          width = 25,
          color = (row_steps[row] == 96) and {0x00, 0x80, 0x00} or {0x40, 0x40, 0x40},
          tooltip = "Set step count to 96",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 96)
          end
        },
        vb:button {
          id = "step_btn_" .. row .. "_112",
          text = "112",
          width = 30,
          color = (row_steps[row] == 112) and {0x00, 0x80, 0x00} or {0x40, 0x40, 0x40},
          tooltip = "Set step count to 112",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 112)
          end
        },
        vb:button {
          id = "step_btn_" .. row .. "_128",
          text = "128",
          width = 30,
          color = (row_steps[row] == 128) and {0x00, 0x80, 0x00} or {0x40, 0x40, 0x40},
          tooltip = "Set step count to 128",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 128)
          end
        },
        vb:button {
          id = "step_btn_" .. row .. "_192",
          text = "192",
          width = 30,
          color = (row_steps[row] == 192) and {0x00, 0x80, 0x00} or {0x40, 0x40, 0x40},
          tooltip = "Set step count to 192",
          notifier = function()
            PakettiHyperEditChangeRowStepCount(row, 192)
          end
        },
        vb:button {
          id = "step_btn_" .. row .. "_256",
          text = "256",
          width = 30,
          color = (row_steps[row] == 256) and {0x00, 0x80, 0x00} or {0x40, 0x40, 0x40},
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
          width = 200,
          notifier = function(index)
            print("DEBUG: Device popup " .. row .. " notifier called with index " .. index)
            PakettiHyperEditSelectDevice(row, index)
          end
        },
        vb:popup {
          id = "parameter_popup_" .. row,
          items = {"Select device first"},
          value = 1,
          width = 100,
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
  
--[[  -- Bottom control
  dialog_content:add_child(vb:row {
    vb:button {
      text = "Close",
      width = 60,
      notifier = function()
        PakettiHyperEditCleanup()
        hyperedit_dialog:close()
      end
    }
  })--]]
  
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
  
  -- Start mouse state monitor to handle mouse releases outside canvas
  PakettiHyperEditStartMouseMonitor()
  
  -- Setup playhead
  PakettiHyperEditSetupPlayhead()
  
  -- Initialize colors based on track color capture setting
  PakettiHyperEditUpdateColors()
  
  -- Try to pre-configure parameters for empty channels
  PakettiHyperEditPreConfigureParameters()
  
  -- CRITICAL: Initialize with existing automation or default to first device
  if #devices > 0 then
    local init_timer
    init_timer = function()
      -- Only populate from existing automation if pre-configuration didn't already handle it
      if not pre_configuration_applied then
        -- First, try to populate from existing automation
        PakettiHyperEditPopulateFromExistingAutomation()
      end
      
      -- For any rows not populated by automation, set up with smart parameter distribution
      print("DEBUG: Checking which rows need default device setup...")
      
      -- First, collect what parameters are already in use
      local used_param_names = {}
      for check_row = 1, NUM_ROWS do
        if row_parameters[check_row] then
          used_param_names[row_parameters[check_row].name] = true
          print("DEBUG: Row " .. check_row .. " already uses parameter: " .. row_parameters[check_row].name)
        end
      end
      
      for row = 1, NUM_ROWS do
        if not row_devices[row] then
          print("DEBUG: Row " .. row .. " not populated by automation - setting up with smart parameter assignment")
          
          -- Get devices and try each one until we find unused parameters
          local devices = PakettiHyperEditGetDevices()
          local assigned = false
          
          for device_idx, device_info in ipairs(devices) do
            if assigned then break end
            
            local params = PakettiHyperEditGetParameters(device_info.device)
            print("DEBUG: Trying device " .. device_info.name .. " with " .. #params .. " parameters for row " .. row)
            
            -- Find first unused parameter in this device
            for i, param_info in ipairs(params) do
              if not used_param_names[param_info.name] then
                -- Found unused parameter - assign it
                used_param_names[param_info.name] = true -- Mark as used
                print("DEBUG: Row " .. row .. " assigned " .. device_info.name .. " -> " .. param_info.name)
                
                -- Set device and parameter
                device_lists[row] = devices
                parameter_lists[row] = params
                row_devices[row] = device_info.device
                
                -- Update UI
                if dialog_vb and dialog_vb.views["device_popup_" .. row] then
                  dialog_vb.views["device_popup_" .. row].value = device_idx
                end
                if dialog_vb and dialog_vb.views["parameter_popup_" .. row] then
                  local param_names = {}
                  for _, p in ipairs(params) do
                    table.insert(param_names, p.name)
                  end
                  dialog_vb.views["parameter_popup_" .. row].items = param_names
                  dialog_vb.views["parameter_popup_" .. row].value = i
                end
                
                -- Set parameter without triggering automation read
                row_parameters[row] = param_info
                assigned = true
                break
              end
            end
          end
          
          if not assigned then
            print("DEBUG: Row " .. row .. " - no unused parameters found across all devices")
          end
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