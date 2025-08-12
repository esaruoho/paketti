-- PakettiEQ10Experiment.lua
-- EQ30 Band System using XML injection of EQ10 devices
-- Drawable frequency response interface with real-time EQ curve modification
local vb = nil  -- Will be created fresh in create_eq_dialog()
local eq_dialog = nil
local eq_canvas = nil
local autofocus_enabled = true  -- Default to enabled for better UX
local devices_minimized = false  -- Default to maximized (show full device parameters)
local global_bandwidth = 0.12  -- Default bandwidth value (0.0001 to 1.0, smaller = sharper)
local canvas_width = 1280
local canvas_height = 480  -- Increased to accommodate band labels
local content_margin = 50
local content_width = canvas_width - (content_margin * 2)
local content_height = canvas_height - (content_margin * 2)
local content_x = content_margin
local content_y = content_margin


local eq30_frequencies = {
  25, 31, 40, 50, 62, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 
  1000, 1300, 1600, 2000, 2500, 3150, 4000, 5000, 6200, 8000, 10000, 13000, 16000, 20000
}

-- Forward declaration removed: define as a proper global function below


-- Renoise EQ10 bandwidth parameter expects 0.0001 to 1 (smaller = sharper)
local function calculate_third_octave_bandwidth(center_freq)
  -- For sharp, surgical 1/3 octave bands (not fat and flabby)
  -- Renoise bandwidth: smaller values = sharper bands
  -- True 1/3 octave bandwidth ≈ 0.231, but we want sharper for precision
  
  if center_freq <= 100 then
    return 0.15  -- Sharp for low frequencies
  elseif center_freq <= 1000 then
    return 0.12  -- Very sharp for midrange
  elseif center_freq <= 8000 then
    return 0.10  -- Surgical for presence range
  else
    return 0.15  -- Sharp for high frequencies
  end
end

-- EQ band states: gain values in dB (-12 to +12)
local eq_gains = {}
for i = 1, #eq30_frequencies do
  eq_gains[i] = 0.0  -- Start flat
end

-- Mouse interaction state
local mouse_is_down = false
local last_mouse_x = -1
local last_mouse_y = -1

-- Automation / Edit A-B state (replicated gadget semantics)
local follow_automation = false
local current_edit_mode = "A"  -- "A" or "B"
local eq_values_A = {}
local eq_values_B = {}
local crossfade_amount = 0.0
local eq_param_observers = {}
local band_being_drawn = nil

-- Create/Follow mode: track change observer and state
local create_follow_enabled = false
local track_index_notifier = nil

-- Cleanup EQ30 dialog state
local function EQ30Cleanup()
  -- turn off automation sync on close to avoid accidental writes next time
  follow_automation = false
  band_being_drawn = nil
  pcall(function() remove_eq_param_observers() end)
  -- Clear transient canvas state to avoid flashing old content
  mouse_is_down = false
  last_mouse_x = -1
  last_mouse_y = -1
  for i = 1, #eq30_frequencies do
    eq_gains[i] = 0.0
  end
  eq_canvas = nil
  -- Remove Create/Follow track observer
  pcall(function()
    local song = renoise.song()
    if song and song.selected_track_index_observable and track_index_notifier then
      if song.selected_track_index_observable:has_notifier(track_index_notifier) then
        song.selected_track_index_observable:remove_notifier(track_index_notifier)
      end
    end
  end)
  track_index_notifier = nil
  create_follow_enabled = false
end

-- Canvas colors (using same pattern as PakettiPCMWriter)
local COLOR_GRID_LINES = {32, 64, 32, 255}        -- Dark green grid
local COLOR_ZERO_LINE = {255, 255, 255, 255}      -- Bright white center line
local COLOR_EQ_CURVE = {255, 64, 255, 255}        -- Bright pink EQ curve
local COLOR_FREQUENCY_MARKERS = {200, 200, 200, 255}  -- Light gray frequency markers
local COLOR_GAIN_MARKERS = {180, 180, 180, 255}   -- Gain level markers
local COLOR_MOUSE_CURSOR = {255, 255, 255, 255}   -- White mouse cursor
local COLOR_BAND_LABELS = {255, 255, 255, 255}    -- White band labels

-- Custom text rendering system for canvas (from PakettiCanvasExperiments.lua)
local function draw_letter_A(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x + size/2, y)
  ctx:line_to(x + size, y + size)
  ctx:move_to(x + size/4, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
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
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + size)
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

local function draw_letter_Z(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
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

local function draw_space(ctx, x, y, size)
  -- Space character - do nothing
end

local function draw_dot(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/2, y + size)
  ctx:line_to(x + size/2, y + size - 2)
  ctx:stroke()
end

-- Draw a horizontal dash (minus sign)
local function draw_dash(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:stroke()
end

-- Draw a plus sign
local function draw_plus(ctx, x, y, size)
  ctx:begin_path()
  -- Vertical
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + size)
  -- Horizontal
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:stroke()
end

-- Letter lookup table (subset for numbers and frequency labels)
local letter_functions = {
  A = draw_letter_A, H = draw_letter_H, Z = draw_letter_Z, K = draw_letter_K,
  ["0"] = draw_digit_0, ["1"] = draw_digit_1, ["2"] = draw_digit_2, ["3"] = draw_digit_3,
  ["4"] = draw_digit_4, ["5"] = draw_digit_5, ["6"] = draw_digit_6, ["7"] = draw_digit_7,
  ["8"] = draw_digit_8, ["9"] = draw_digit_9, [" "] = draw_space, ["."] = draw_dot,
  ["-"] = draw_dash, ["+"] = draw_plus
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

-- Convert frequency to canvas X position (logarithmic scale)
local function freq_to_x(frequency)
  local log_min = math.log10(eq30_frequencies[1])      -- 25 Hz
  local log_max = math.log10(eq30_frequencies[#eq30_frequencies])  -- 20 kHz
  local log_freq = math.log10(frequency)
  local normalized = (log_freq - log_min) / (log_max - log_min)
  return content_x + normalized * content_width
end

-- Convert canvas X position to frequency (logarithmic scale)
local function x_to_freq(x)
  local normalized = (x - content_x) / content_width
  normalized = math.max(0, math.min(1, normalized))
  local log_min = math.log10(eq30_frequencies[1])
  local log_max = math.log10(eq30_frequencies[#eq30_frequencies])
  local log_freq = log_min + normalized * (log_max - log_min)
  return math.pow(10, log_freq)
end

-- Convert gain to canvas Y position (EQ10 full range: -20dB to +20dB)
local function gain_to_y(gain_db)
  local normalized = (gain_db + 20) / 40  -- -20 to +20 dB range (EQ10 maximum)
  normalized = math.max(0, math.min(1, normalized))
  return content_y + content_height - (normalized * content_height)
end

-- Convert canvas Y position to gain (EQ10 full range: -20dB to +20dB)
local function y_to_gain(y)
  local normalized = 1 - ((y - content_y) / content_height)
  normalized = math.max(0, math.min(1, normalized))
  return (normalized * 40) - 20  -- -20 to +20 dB range (EQ10 maximum)
end

-- Find nearest EQ band for a given frequency
local function find_nearest_band(frequency)
  local nearest_index = 1
  local min_distance = math.abs(math.log10(frequency) - math.log10(eq30_frequencies[1]))
  
  for i = 2, #eq30_frequencies do
    local distance = math.abs(math.log10(frequency) - math.log10(eq30_frequencies[i]))
    if distance < min_distance then
      min_distance = distance
      nearest_index = i
    end
  end
  
  return nearest_index
end

-- No XML generation needed - using direct parameter control!

-- Parameters set directly in device creation - no separate function needed!

-- Debug: Show current parameter values of an EQ10 device (for troubleshooting)
local function debug_eq_device_parameters(device, device_name)
  print("=== " .. device_name .. " Parameters ===")
  print("Gains (1-10):")
  for i = 1, 10 do
    if device.parameters[i] then
      print(string.format("  Param %d: %.2f dB", i, device.parameters[i].value))
    end
  end
  print("Frequencies (11-20):")
  for i = 11, 20 do
    if device.parameters[i] then
      print(string.format("  Param %d: %.0f Hz", i, device.parameters[i].value))
    end
  end
  print("Bandwidths (21-30):")
  for i = 21, 30 do
    if device.parameters[i] then
      print(string.format("  Param %d: %.3f BW", i, device.parameters[i].value))
    end
  end
end

-- Live update EQ10 device GAIN parameter for specific band (only middle bands 2-9)
local function update_eq_device_parameter(band_index, gain_value)
  local song = renoise.song()
  if not song or not song.selected_track then
    return
  end
  
  local track = song.selected_track
  
  -- EQ30 system: Find which EQ10 device this band belongs to (8+8+8+6 distribution)
  local device_num, band_in_device
  if band_index <= 8 then
    device_num = 1
    band_in_device = band_index  -- 1-8
  elseif band_index <= 16 then
    device_num = 2  
    band_in_device = band_index - 8  -- 1-8
  elseif band_index <= 24 then
    device_num = 3
    band_in_device = band_index - 16  -- 1-8
  else -- bands 25-30
    device_num = 4
    band_in_device = band_index - 24  -- 1-6 (only 6 bands in device 4)
  end
  
  -- Map to actual EQ10 parameters (2-9, skipping problematic 1st and 10th bands)
  local eq_param_num = band_in_device + 1  -- band 1 maps to param 2, band 8 maps to param 9
  
  -- Find the corresponding EQ10 device on the track
  local eq_device_count = 0
  local target_device_index = nil
  
  for i, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/EQ 10" then
      eq_device_count = eq_device_count + 1
      if eq_device_count == device_num then
        target_device_index = i
        -- Update ONLY the gain parameter (parameters 2-9 are our usable gains)
        -- Skip parameters 1 and 10 (problematic bands)
        if device.parameters[eq_param_num] then
          device.parameters[eq_param_num].value = gain_value
          -- Debug output
          -- print(string.format("LIVE: EQ10-%d Param %d = %.1f dB", device_num, eq_param_num, gain_value))
        end
        break
      end
    end
  end
  
  -- Autofocus the selected EQ10 device if enabled
  if autofocus_enabled and target_device_index then
    print(string.format("AUTOFOCUS DEBUG: Band %d → Device %d → Track Device Index %d", band_index, device_num, target_device_index))
    
    -- SAFETY: Double-check we have a valid song object before setting device index
    local success, error_msg = pcall(function()
      if song and song.selected_device_index ~= nil then
        song.selected_device_index = target_device_index
        
        -- Make sure lower frame is visible and shows device chain
        renoise.app().window.lower_frame_is_visible = true
        renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
        
        print(string.format("Autofocus: Selected EQ30 Device %d at track index %d", device_num, target_device_index))
      else
        print("AUTOFOCUS ERROR: Invalid song object")
      end
    end)
    
    if not success then
      print(string.format("AUTOFOCUS ERROR: %s", error_msg))
    end
  elseif autofocus_enabled then
    print(string.format("AUTOFOCUS FAIL: Band %d → Device %d → target_device_index is nil", band_index, device_num))
  end
end

-- Helper: get parameter object for band index (for automation writes)
local function get_parameter_for_band(band_index)
  local song = renoise.song()
  if not song or not song.selected_track then return nil end
  local track = song.selected_track
  local device_num, band_in_device
  if band_index <= 8 then
    device_num = 1; band_in_device = band_index
  elseif band_index <= 16 then
    device_num = 2; band_in_device = band_index - 8
  elseif band_index <= 24 then
    device_num = 3; band_in_device = band_index - 16
  else
    device_num = 4; band_in_device = band_index - 24
  end
  local target_device = nil
  local count = 0
  for i, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/EQ 10" then
      count = count + 1
      if count == device_num then
        target_device = device; break
      end
    end
  end
  if not target_device then return nil end
  local eq_param_num = band_in_device + 1
  return target_device.parameters[eq_param_num]
end

-- Automation: write single parameter at current line
local function write_parameter_to_automation(parameter, value, skip_select)
  if not parameter then return end
  local song = renoise.song()
  local current_line = song.selected_line_index
  local current_pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  local automation = pattern_track:find_automation(parameter)
  if not automation then automation = pattern_track:create_automation(parameter) end
  if not automation then return end
  if automation:has_point_at(current_line) then automation:remove_point_at(current_line) end
  local normalized_value = (value - parameter.value_min) / (parameter.value_max - parameter.value_min)
  normalized_value = math.max(0.0, math.min(1.0, normalized_value))
  automation:add_point_at(current_line, normalized_value)
  if not skip_select then
    song.selected_automation_parameter = parameter
    renoise.app().window.lower_frame_is_visible = true
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
  end
end

-- Automation: snapshot all bands to current line
local function snapshot_all_bands_to_automation()
  local written = 0
  for i = 1, #eq30_frequencies do
    local parameter = get_parameter_for_band(i)
    if parameter then
      write_parameter_to_automation(parameter, eq_gains[i], true)
      written = written + 1
    end
  end
  renoise.app():show_status("EQ30 Snapshot to automation: " .. tostring(written) .. " bands")
end

-- Automation: clear all automation for EQ30 bands on selected track
local function clear_all_eq30_automation()
  local song = renoise.song()
  if not song or not song.selected_track then return end
  local track_index = song.selected_track_index
  local pattern = song.selected_pattern_index
  local pattern_track = song:pattern(pattern):track(track_index)
  local cleared = 0
  for i = 1, #eq30_frequencies do
    local parameter = get_parameter_for_band(i)
    if parameter then
      local automation = pattern_track:find_automation(parameter)
      if automation then automation:clear(); cleared = cleared + 1 end
    end
  end
  renoise.app():show_status("EQ30 Clear: " .. tostring(cleared) .. " automations cleared")
end

-- Automation: clean & snap (clear all then write line 1 snapshot)
local function clean_and_snap_all_bands()
  local song = renoise.song()
  if not song or not song.selected_track then return end
  local track_index = song.selected_track_index
  local pattern = song.selected_pattern_index
  local pattern_track = song:pattern(pattern):track(track_index)
  -- Clear
  clear_all_eq30_automation()
  -- Write snapshot at line 1
  local wrote = 0
  for i = 1, #eq30_frequencies do
    local parameter = get_parameter_for_band(i)
    if parameter then
      local automation = pattern_track:find_automation(parameter)
      if not automation then automation = pattern_track:create_automation(parameter) end
      if automation then
        automation:clear()
        local normalized_value = (eq_gains[i] - parameter.value_min) / (parameter.value_max - parameter.value_min)
        normalized_value = math.max(0.0, math.min(1.0, normalized_value))
        automation:add_point_at(1, normalized_value)
        wrote = wrote + 1
      end
    end
  end
  renoise.app():show_status("EQ30 Clean & Snap: " .. tostring(wrote) .. " bands at line 1")
end

-- Set playmode for ALL EQ30 envelopes on the selected track (existing envelopes only)
local function eq30_set_automation_playmode(mode)
  local song = renoise.song()
  if not song or not song.selected_track then return end
  local track_index = song.selected_track_index
  local pattern = song.selected_pattern_index
  local pattern_track = song:pattern(pattern):track(track_index)
  local changed = 0
  for i = 1, #eq30_frequencies do
    local parameter = get_parameter_for_band(i)
    if parameter then
      local env = pattern_track:find_automation(parameter)
      if env then
        env.playmode = mode
        changed = changed + 1
      end
    end
  end
  local name = (mode == renoise.PatternTrackAutomation.PLAYMODE_POINTS and "Points") or (mode == renoise.PatternTrackAutomation.PLAYMODE_LINES and "Lines") or "Curves"
  if changed > 0 then
    renoise.app():show_status("EQ30 Automation Playmode → " .. name .. " on " .. tostring(changed) .. " envelopes")
  else
    renoise.app():show_status("EQ30: No existing envelopes to set playmode on")
  end
end

-- Show automation envelope for specific EQ band and reveal Automation frame
local function show_automation_for_band(band_index)
  local parameter = get_parameter_for_band(band_index)
  if not parameter then return end
  local song = renoise.song()
  song.selected_automation_parameter = parameter
  renoise.app().window.lower_frame_is_visible = true
  renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
end

-- Remove all observers used for EQ30 automation following
local function remove_eq_param_observers()
  for parameter, observer in pairs(eq_param_observers) do
    pcall(function()
      if parameter and parameter.value_observable and parameter.value_observable:has_notifier(observer) then
        parameter.value_observable:remove_notifier(observer)
      end
    end)
  end
  eq_param_observers = {}
end

-- Install observers so canvas follows automation and device changes
local function setup_eq_param_observers()
  remove_eq_param_observers()
  local song = renoise.song()
  if not song or not song.selected_track then return end
  local track = song.selected_track
  local device_counter = 0
  for i, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/EQ 10" then
      device_counter = device_counter + 1
      if device_counter <= 4 then
        local start_band = (device_counter - 1) * 8 + 1
        for param_idx = 2, 9 do
          local band_index = start_band + (param_idx - 2)
          if band_index <= #eq30_frequencies then
            local parameter = device.parameters[param_idx]
            if parameter and parameter.value_observable then
              local observer = function()
                if band_being_drawn ~= band_index then
                  eq_gains[band_index] = parameter.value
                  if eq_canvas then eq_canvas:update() end
                end
              end
              parameter.value_observable:add_notifier(observer)
              eq_param_observers[parameter] = observer
            end
          end
        end
      end
    end
  end
end

-- Ensure EQ10 devices exist on track (auto-create if needed)
local function ensure_eq_devices_exist()
  local song = renoise.song()
  if not song or not song.selected_track then
    return false
  end
  
  local track = song.selected_track
  local eq_count = 0
  
  -- Count existing EQ10 devices
  for i, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/EQ 10" then
      eq_count = eq_count + 1
    end
  end
  
  -- Create missing EQ10 devices (need 4 for EQ30 system)
  if eq_count < 4 then
    print("Auto-creating missing EQ10 devices for EQ30 system...")
    apply_eq30_to_track()
    return true
  end
  
  return true
end

-- Check if EQ10 devices are present on the selected track
local function check_eq_devices_status()
  local song = renoise.song()
  if not song or not song.selected_track then
    return false, "No track selected"
  end
  
  local track = song.selected_track
  local eq_count = 0
  
  for i, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/EQ 10" then
      eq_count = eq_count + 1
    end
  end
  
  if eq_count >= 4 then
    return true, ""
  elseif eq_count > 0 then
    return false, string.format("Only %d EQ10 devices found - need 4 for full EQ30 system", eq_count)
  else
    return false, "No EQ10 devices found - click 'Recreate Devices' first"
  end
end

-- Minimize/Maximize all EQ10 devices on the track
local function toggle_eq_devices_size()
  local song = renoise.song()
  if not song or not song.selected_track then
    renoise.app():show_status("No track selected")
    return
  end
  
  local track = song.selected_track
  local eq_device_count = 0
  
  -- Find and toggle all EQ10 devices
  for i, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/EQ 10" then
      device.is_maximized = not devices_minimized
      eq_device_count = eq_device_count + 1
    end
  end
  
  if eq_device_count > 0 then
    local action = devices_minimized and "minimized" or "maximized"
    renoise.app():show_status(string.format("%d EQ10 devices %s", eq_device_count, action))
  else
    renoise.app():show_status("No EQ10 devices found to resize")
  end
end

-- Update global bandwidth (Q) for all EQ bands across all devices
local function update_global_bandwidth(bandwidth_value)
  local song = renoise.song()
  if not song or not song.selected_track then
    return
  end
  
  local track = song.selected_track
  local updated_count = 0
  
  -- Update bandwidth parameters (21-30) for all EQ10 devices
  for i, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/EQ 10" then
      -- Update bandwidth parameters 22-29 (middle 8 bands, skip problematic 21 and 30)
      for param_idx = 22, 29 do
        if device.parameters[param_idx] then
          device.parameters[param_idx].value = bandwidth_value
          updated_count = updated_count + 1
        end
      end
    end
  end
  
  -- Convert bandwidth to approximate Q for display (rough inverse relationship)
  local approx_q = math.max(0.1, 1.0 / (bandwidth_value * 10))
  
  if updated_count > 0 then
    renoise.app():show_status(string.format("Global Q updated: %.2f (≈Q %.1f) across %d bands", bandwidth_value, approx_q, updated_count))
  end
end

-- Randomize EQ curve with different patterns
local function randomize_eq_curve(pattern_type)
  local song = renoise.song()
  if not song or not song.selected_track then
    return
  end
  
  -- Reset all gains first
  for i = 1, #eq30_frequencies do
    eq_gains[i] = 0.0
  end
  
  if pattern_type == "smooth" then
    -- Smooth random curve (fewer peaks, more musical)
    local peak_bands = {5, 12, 18, 25}  -- Spread peaks across spectrum
    for _, band in ipairs(peak_bands) do
      local random_gain = (math.random() - 0.5) * 24  -- -12 to +12 dB range
      eq_gains[band] = random_gain
      
      -- Add some neighboring bands with lower values
      for offset = -2, 2 do
        local neighbor_band = band + offset
        if neighbor_band >= 1 and neighbor_band <= #eq30_frequencies and neighbor_band ~= band then
          eq_gains[neighbor_band] = random_gain * (1 - math.abs(offset) * 0.3)
        end
      end
    end
  elseif pattern_type == "surgical" then
    -- Surgical random (sharp individual band adjustments)
    local num_bands = math.random(8, 15)  -- Random number of active bands
    for i = 1, num_bands do
      local band = math.random(1, #eq30_frequencies)
      local random_gain = (math.random() - 0.5) * 32  -- -16 to +16 dB range
      eq_gains[band] = math.max(-20, math.min(20, random_gain))
    end
  else -- "creative"
    -- Creative random (wild and experimental)
    for i = 1, #eq30_frequencies do
      if math.random() > 0.6 then  -- 40% chance each band gets randomized
        local random_gain = (math.random() - 0.5) * 40  -- -20 to +20 dB range
        eq_gains[i] = math.max(-20, math.min(20, random_gain))
      end
    end
  end
  
  -- Apply to all EQ10 devices
  local updated_count = 0
  for i = 1, #eq30_frequencies do
    update_eq_device_parameter(i, eq_gains[i])
    updated_count = updated_count + 1
  end
  
  -- Update canvas
  if eq_canvas then
    eq_canvas:update()
  end
  
  renoise.app():show_status(string.format("EQ30 randomized (%s pattern): %d bands updated", pattern_type, updated_count))
end

-- Update status text based on EQ device presence
local function update_eq_status()
  if not eq_dialog or not eq_dialog.visible then return end
  
  local has_eq, status_msg = check_eq_devices_status()
  if create_follow_enabled then
    local song = renoise.song()
    local track_name = (song and song.selected_track and song.selected_track.name) or "<No Track>"
    if not has_eq then
      status_msg = string.format("No EQ30 device on track %s, click canvas to add", track_name)
    end
  end
  local status_view = vb.views.eq_status_text
  if status_view then
    status_view.text = status_msg
  end
end

-- Apply EQ30 settings to Renoise track 
-- Strategy: Direct parameter control for everything - no XML needed!
function apply_eq30_to_track()
  print("=== APPLY EQ30 TO TRACK START ===")
  
  local song = renoise.song()
  if not song then
    print("ERROR: No song available")
    renoise.app():show_status("ERROR: No song available")
    return
  end
  
  if not song.selected_track then
    print("ERROR: No track selected")
    renoise.app():show_status("ERROR: No track selected - select a track first")
    return
  end
  
  local track = song.selected_track
  print("Selected track: " .. (track.name or "Unknown"))
  print("Current devices on track: " .. #track.devices)
  
  -- EQ30 system using 4 EQ10 devices, only middle 8 bands each (avoid problematic 1st/10th bands)
  local devices_needed = 4
  local bands_per_device = 8  -- Only use bands 2-9 of each EQ10 device
  
  -- Clear existing EQ10 devices on track
  local removed_count = 0
  for i = #track.devices, 1, -1 do
    local device = track.devices[i]
    if device.device_path == "Audio/Effects/Native/EQ 10" then
      print("Removing existing EQ10 device at position " .. i)
      track:delete_device_at(i)
      removed_count = removed_count + 1
    end
  end
  print("Removed " .. removed_count .. " existing EQ10 devices")
  
  -- Create EQ10 devices for 30-band system
  for device_idx = 1, devices_needed do
    print("Creating EQ10 device " .. device_idx .. "/" .. devices_needed)
    
    local start_band = (device_idx - 1) * bands_per_device + 1
    local end_band = math.min(device_idx * bands_per_device, #eq30_frequencies)
    
    -- Load EQ10 device with error handling
    local success, error_msg = pcall(function()
      track:insert_device_at("Audio/Effects/Native/EQ 10", #track.devices + 1)
    end)
    
    if not success then
      print("ERROR: Failed to insert EQ10 device: " .. tostring(error_msg))
      renoise.app():show_status("ERROR: Failed to insert EQ10 device - " .. tostring(error_msg))
      return
    end
    
    local eq_device = track.devices[#track.devices]
    if not eq_device then
      print("ERROR: Failed to get inserted EQ10 device")
      renoise.app():show_status("ERROR: Failed to get inserted EQ10 device")
      return
    end
    
    print("Successfully inserted EQ10 device, total devices now: " .. #track.devices)
    
    -- Set all parameters directly - no XML needed!
    eq_device.display_name = string.format("EQ30 Device %d", device_idx)
    
    -- Set up only middle 8 bands (2-9) for this device - avoid problematic 1st/10th bands
    -- Set unused bands 1 and 10 to neutral
    eq_device.parameters[1].value = 0.0        -- Band 1: Gain = 0dB (unused)
    eq_device.parameters[11].value = 1000      -- Band 1: Frequency = 1kHz  
    eq_device.parameters[21].value = 0.5       -- Band 1: Bandwidth = 0.5
    
    eq_device.parameters[10].value = 0.0       -- Band 10: Gain = 0dB (unused)
    eq_device.parameters[20].value = 1000      -- Band 10: Frequency = 1kHz
    eq_device.parameters[30].value = 0.5       -- Band 10: Bandwidth = 0.5
    
    -- Configure middle 8 bands (2-9) with our frequencies
    for band = 2, 9 do
      local global_band = start_band + (band - 2)  -- band-2 because we start from band 2
      
      if global_band <= #eq30_frequencies then
        local freq = eq30_frequencies[global_band]
        local bandwidth_value = calculate_third_octave_bandwidth(freq)
        
        -- Set parameters directly (using bands 2-9):
        eq_device.parameters[band].value = 0.0                    -- Gain (param 2-9) - start flat
        eq_device.parameters[band + 10].value = freq              -- Frequency (param 12-19)
        eq_device.parameters[band + 20].value = bandwidth_value   -- Bandwidth (param 22-29)
        
        print(string.format("  Band %d: %.0fHz, BW=%.2f (using EQ param %d)", global_band, freq, bandwidth_value, band))
      else
        -- Neutral values for unused bands
        eq_device.parameters[band].value = 0.0              -- Gain = 0dB
        eq_device.parameters[band + 10].value = 1000        -- Frequency = 1kHz
        eq_device.parameters[band + 20].value = 0.5         -- Bandwidth = 0.5 (neutral)
      end
    end
    
    local end_band = math.min(start_band + bands_per_device - 1, #eq30_frequencies)
    print(string.format("EQ10-%d configured: %.0f-%.0fHz, sharp bandwidth precision", device_idx, eq30_frequencies[start_band], eq30_frequencies[end_band]))
    
    -- Debug: Show parameter values to verify settings
    debug_eq_device_parameters(eq_device, "EQ30 Device " .. device_idx .. " (Middle 8 Bands Only)")
    
    -- Debug output showing the mapping
    print(string.format("Created EQ10 device %d with bands %d-%d", device_idx, start_band, end_band))
    print(string.format("  Frequency range: %.0fHz - %.0fHz", eq30_frequencies[start_band], eq30_frequencies[end_band]))
    
    -- Show non-zero gains for this device
    for band = 1, 10 do
      local global_band = start_band + band - 1
      if global_band <= #eq30_frequencies and math.abs(eq_gains[global_band]) > 0.1 then
        print(string.format("    Band %d (%.0fHz): %.1fdB", global_band, eq30_frequencies[global_band], eq_gains[global_band]))
      end
    end
  end
  
  print("=== EQ30 SETUP COMPLETE ===")
  print("Successfully created " .. devices_needed .. " EQ10 devices using middle 8 bands each (avoiding problematic 1st/10th bands)")
  print("SHARP bandwidth 1/3 octave bands for PRECISE control (not fat and flabby!)")
  print("ALL parameters set directly - no XML needed! Only parameters 2-9 used per device")
  print("Bandwidth values: 0.10-0.15 for surgical precision (valid Renoise range: 0.0001-1)")
  print("Parameters 1 & 10 disabled on each device (problematic bands avoided)")
  print("Track now has " .. #track.devices .. " devices")
  
  -- Update status indicator
  update_eq_status()
  

end

-- Draw the EQ canvas
local function draw_eq_canvas(ctx)
  local w, h = canvas_width, canvas_height
  
  -- Clear canvas
  ctx:clear_rect(0, 0, w, h)
  
  -- Background grid removed; use precise guides and gain markers instead
  
  -- Draw zero line (0 dB) – thicker for strong center reference
  ctx.stroke_color = COLOR_ZERO_LINE
  ctx.line_width = 4
  local zero_y = gain_to_y(0)
  ctx:begin_path()
  ctx:move_to(content_x, zero_y)
  ctx:line_to(content_x + content_width, zero_y)
  ctx:stroke()
  
  -- Draw column-aligned vertical guides at each band boundary (lean green)
  local band_width = content_width / #eq30_frequencies
  ctx.stroke_color = {64, 160, 64, 140}
  ctx.line_width = 1
  for i = 0, #eq30_frequencies do
    local x = content_x + (i * band_width)
    ctx:begin_path()
    ctx:move_to(x, content_y)
    ctx:line_to(x, content_y + content_height)
    ctx:stroke()
  end
  
  -- Device split guides removed per UX preference
  
  -- Draw gain markers exactly at {-20,-12,-6,-3,0,+3,+6,+12,+20}
  ctx.stroke_color = COLOR_GAIN_MARKERS
  ctx.line_width = 1
  local gain_levels = {-20, -12, -6, -3, 0, 3, 6, 12, 20}
  for _, gain in ipairs(gain_levels) do
    local y = gain_to_y(gain)
    ctx:begin_path()
    ctx:move_to(content_x, y)
    ctx:line_to(content_x + content_width, y)
    ctx:stroke()
  end
  
  -- Draw EQ BARS
  local band_width = content_width / #eq30_frequencies
  local bar_margin = 2  -- Space between bars
  local bar_width = band_width - (bar_margin * 2)
  local zero_y = gain_to_y(0)  -- 0dB center line
  
  for i, freq in ipairs(eq30_frequencies) do
    local gain = eq_gains[i]
    local band_x = content_x + (i - 1) * band_width
    local bar_x = band_x + bar_margin
    
    -- Use purple bars like PakettiCanvasExperiments.lua (professional EQ look) - brighter
    local bar_color = {120, 40, 160, 255}

    -- Solid bar only (gradient removed) with a safe gap around the zero line (account for 4px thick line)
    ctx.fill_color = bar_color
    if gain >= 0 then
      local bar_top_y = gain_to_y(gain)
      local bar_height = (zero_y - 3) - bar_top_y
      if bar_height > 0 then ctx:fill_rect(bar_x, bar_top_y, bar_width, bar_height) end
    else
      local bar_bottom_y = gain_to_y(gain)
      local start_y = zero_y + 3
      local bar_height = bar_bottom_y - start_y
      if bar_height > 0 then ctx:fill_rect(bar_x, start_y, bar_width, bar_height) end
    end
    
    -- Draw bar outline for definition
    ctx.stroke_color = {255, 255, 255, 100}  -- Light white outline
    ctx.line_width = 1
    if gain >= 0 and ((zero_y - 3) - gain_to_y(gain)) > 0 then
      ctx:begin_path()
      ctx:rect(bar_x, gain_to_y(gain), bar_width, (zero_y - 3) - gain_to_y(gain))
      ctx:stroke()
    elseif gain < 0 and (gain_to_y(gain) - (zero_y + 3)) > 0 then
      ctx:begin_path()
      ctx:rect(bar_x, zero_y + 3, bar_width, gain_to_y(gain) - (zero_y + 3))
      ctx:stroke()
    end
    
    -- Draw frequency name vertically using custom text rendering (no Hz/kHz suffix)
    if bar_width > 12 then  -- Only draw text if there's enough space
      ctx.stroke_color = {200, 200, 200, 255}  -- Light gray text
      ctx.line_width = 2  -- Make text bold by using thicker lines (like PakettiCanvasExperiments)
      
      -- Create compact frequency text without units
      local freq_text
      if freq >= 1000 then
        if freq >= 10000 then
          freq_text = string.format("%.0f", freq / 1000) .. "k"
        else
          freq_text = string.format("%.1f", freq / 1000) .. "k"
        end
      else
        freq_text = tostring(freq)
      end
      
      -- Draw frequency name vertically (rotated text effect - EXACTLY like PakettiCanvasExperiments.lua)
      local bar_center_x = bar_x + (bar_width / 2)
      local text_size = math.max(4, math.min(12, bar_width * 0.6))
      local text_start_y = content_y + 15 - math.floor(text_size * 0.5)  -- lift by ~0.5 char
      
      -- Draw each character of the frequency name vertically (COPIED from PakettiCanvasExperiments.lua)
      local letter_spacing = text_size + 4  -- Add 4 pixels between letters for better readability
      -- Calculate how many characters can fit vertically
      local max_chars = math.floor((content_height - 40) / letter_spacing)
      if #freq_text > max_chars then
        freq_text = freq_text:sub(1, max_chars - 3) .. "..."
      end
      
      for char_index = 1, #freq_text do
        local char = freq_text:sub(char_index, char_index)
        local char_y = text_start_y + (char_index - 1) * letter_spacing
        if char_y < content_y + content_height - text_size - 5 then  -- Don't draw outside content area
          local char_func = letter_functions[char:upper()]
          if char_func then
            char_func(ctx, bar_center_x - text_size/2, char_y, text_size)
          end
        end
      end
    end
    
    -- No per-band divider lines to keep visual clean
  end
  
  -- Band numbers at bottom (30 bands total for EQ30 system: 8+8+8+6)
  ctx.stroke_color = COLOR_BAND_LABELS
  ctx.line_width = 1
  local band_width = content_width / #eq30_frequencies
  
  for i, freq in ipairs(eq30_frequencies) do
    local band_x = content_x + (i - 1) * band_width
    local bar_center_x = band_x + (band_width / 2)
    local label_y_start = content_y + content_height + 10  -- Below the main content
    
    -- Draw ALL band numbers (01-30) below each column
    local band_text = string.format("%02d", i)  -- 01, 02, 03, ..., 30
    local text_size = math.max(3, math.min(6, band_width * 0.4))  -- Scale text to fit narrow columns
    draw_canvas_text(ctx, band_text, bar_center_x - (#band_text * text_size/3), label_y_start, text_size)
  end
  
  -- Side dB labels at left and right edges for measurement feel (+/-20, +/-12, +/-6, +/-3) – ensure only drawn once
  ctx.stroke_color = COLOR_BAND_LABELS
  ctx.line_width = 1
  local label_size = 7
  -- Include full range on sides
  local levels = {20, 12, 6, 3, -3, -6, -12, -20}
  for i = 1, #levels do
    local lvl = levels[i]
    local text
    if lvl > 0 then
      text = "+" .. tostring(lvl)
    else
      text = tostring(lvl)
    end
    local y = gain_to_y(lvl) - (label_size / 2)
    local est_w = (#text * label_size) / 3
    local left_x = content_x - est_w - 20
    local right_x = content_x + content_width + 8
    draw_canvas_text(ctx, text, left_x, y, label_size)
    draw_canvas_text(ctx, text, right_x, y, label_size)
  end

  -- Corner min/max labels removed per request
  
  -- Draw content area border
  ctx.stroke_color = {80, 80, 120, 255}
  ctx.line_width = 2
  ctx:begin_path()
  ctx:rect(content_x, content_y, content_width, content_height)
  ctx:stroke()
  
  -- Draw overall canvas border
  ctx.stroke_color = {255, 255, 255, 255}
  ctx.line_width = 1
  ctx:begin_path()
  ctx:rect(0, 0, w, h)
  ctx:stroke()
  
  -- Draw mouse cursor during interaction
  if mouse_is_down and last_mouse_x >= 0 and last_mouse_y >= 0 then
    ctx.stroke_color = COLOR_MOUSE_CURSOR
    ctx.line_width = 1
    
    -- Vertical line
    ctx:begin_path()
    ctx:move_to(last_mouse_x, 0)
    ctx:line_to(last_mouse_x, h)
    ctx:stroke()
    
    -- Horizontal line
    ctx:begin_path()
    ctx:move_to(0, last_mouse_y)
    ctx:line_to(w, last_mouse_y)
    ctx:stroke()
    
    -- Center dot
    ctx.stroke_color = {255, 0, 0, 255}
    ctx.line_width = 2
    ctx:begin_path()
    ctx:arc(last_mouse_x, last_mouse_y, 3, 0, math.pi * 2, false)
    ctx:stroke()
  end
end

-- Handle mouse interaction for EQ curve drawing
local function handle_eq_mouse(ev)
  local w, h = canvas_width, canvas_height
  
  if ev.type == "exit" then
    mouse_is_down = false
    last_mouse_x = -1
    last_mouse_y = -1
    return
  end
  
  -- In Create/Follow mode, clicking anywhere on the canvas when EQ30 is missing should create it
  if ev.type == "down" and ev.button == "left" and create_follow_enabled then
    local has_eq, _ = check_eq_devices_status()
    if not has_eq then
      apply_eq30_to_track()
      setup_eq_param_observers()
      auto_load_existing_eq_settings()
      update_eq_status()
      if eq_canvas then eq_canvas:update() end
      renoise.app():show_status("EQ30 created for current track")
      return
    end
  end

  -- Check if mouse is within content area
  local mouse_in_content = ev.position.x >= content_x and ev.position.x <= (content_x + content_width) and 
                          ev.position.y >= content_y and ev.position.y <= (content_y + content_height)
  
  if not mouse_in_content and ev.type ~= "up" then
    return
  end
  
  local x = ev.position.x
  local y = ev.position.y
  
  -- Update mouse tracking
  last_mouse_x = x
  last_mouse_y = y
  
  -- Right-click anywhere in content area: reset to flat
  if ev.type == "down" and ev.button == "right" then
    for i = 1, #eq30_frequencies do
      eq_gains[i] = 0.0
      update_eq_device_parameter(i, 0.0)
    end
    if eq_canvas then eq_canvas:update() end
    renoise.app():show_status("EQ30: Reset to flat (right-click)")
    return
  end

  if ev.type == "down" and ev.button == "left" then
    mouse_is_down = true
    if mouse_in_content then
      -- NEW BAR SYSTEM: Direct mapping from X position to band index
      local band_width = content_width / #eq30_frequencies
      local band_index = math.floor((x - content_x) / band_width) + 1
      band_index = math.max(1, math.min(#eq30_frequencies, band_index))
      
      local gain = y_to_gain(y)
      eq_gains[band_index] = math.max(-20, math.min(20, gain))
      band_being_drawn = band_index
      
      -- LIVE UPDATE: Immediately update the corresponding EQ10 device parameter
      update_eq_device_parameter(band_index, eq_gains[band_index])
      -- Automation write if enabled
      if follow_automation == true then
        local parameter = get_parameter_for_band(band_index)
        write_parameter_to_automation(parameter, eq_gains[band_index], true)
      end
      
      if follow_automation then
        show_automation_for_band(band_index)
      end

      if eq_canvas then
        eq_canvas:update()
      end
      
      -- Determine which EQ10 device this band belongs to (EQ30 system)
      local device_num, band_in_device
      if band_index <= 8 then
        device_num = 1
        band_in_device = band_index
      elseif band_index <= 16 then
        device_num = 2  
        band_in_device = band_index - 8
      elseif band_index <= 24 then
        device_num = 3
        band_in_device = band_index - 16
      else -- bands 25-30
        device_num = 4
        band_in_device = band_index - 24
      end
      local eq_param_num = band_in_device + 1  -- Maps to params 2-9
      local autofocus_indicator = autofocus_enabled and " [FOCUS]" or ""
      renoise.app():show_status(string.format("LIVE EQ30: Device %d, Param %d (%.0f Hz): %.1f dB%s", device_num, eq_param_num, eq30_frequencies[band_index], eq_gains[band_index], autofocus_indicator))
    end
  elseif ev.type == "move" and mouse_is_down then
    if mouse_in_content then
      -- NEW BAR SYSTEM: Direct mapping from X position to band index
      local band_width = content_width / #eq30_frequencies
      local band_index = math.floor((x - content_x) / band_width) + 1
      band_index = math.max(1, math.min(#eq30_frequencies, band_index))
      
      local gain = y_to_gain(y)
      eq_gains[band_index] = math.max(-20, math.min(20, gain))
      
      -- LIVE UPDATE: Immediately update the corresponding EQ10 device parameter
      update_eq_device_parameter(band_index, eq_gains[band_index])
      -- Automation write if enabled
      if follow_automation == true then
        local parameter = get_parameter_for_band(band_index)
        write_parameter_to_automation(parameter, eq_gains[band_index], true)
      end
      
      if follow_automation then
        show_automation_for_band(band_index)
      end

      if eq_canvas then
        eq_canvas:update()
      end
      
      -- Determine which EQ10 device this band belongs to (EQ30 system)
      local device_num, band_in_device
      if band_index <= 8 then
        device_num = 1
        band_in_device = band_index
      elseif band_index <= 16 then
        device_num = 2  
        band_in_device = band_index - 8
      elseif band_index <= 24 then
        device_num = 3
        band_in_device = band_index - 16
      else -- bands 25-30
        device_num = 4
        band_in_device = band_index - 24
      end
      local eq_param_num = band_in_device + 1  -- Maps to params 2-9
      local autofocus_indicator = autofocus_enabled and " [FOCUS]" or ""
      renoise.app():show_status(string.format("LIVE EQ30: Device %d, Param %d (%.0f Hz): %.1f dB%s", device_num, eq_param_num, eq30_frequencies[band_index], eq_gains[band_index], autofocus_indicator))
    end
  elseif ev.type == "up" and ev.button == "left" then
    mouse_is_down = false
    last_mouse_x = -1
    last_mouse_y = -1
    band_being_drawn = nil
    if eq_canvas then
      eq_canvas:update()
    end
  end
end

-- Key handler function (using user's preferred pattern)
local function my_keyhandler_func(dialog, key)
  if key.modifiers == "command" and key.name == "h" then
    if eq_dialog then
      eq_dialog:close()
      eq_dialog = nil
    end
    return nil
  end
  
  return key
end

-- Reset EQ to flat response (BOTH canvas AND actual EQ10 device parameters) - NO AUTOFOCUS
local function reset_eq_flat()
  local song = renoise.song()
  if not song or not song.selected_track then
    renoise.app():show_status("No track selected")
    return
  end
  
  local track = song.selected_track
  
  -- Reset canvas display
  for i = 1, #eq30_frequencies do
    eq_gains[i] = 0.0
  end
  
  -- Reset ALL EQ10 device parameters directly (no autofocus, no individual calls)
  local eq_devices = {}
  for i, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/EQ 10" then
      table.insert(eq_devices, device)
    end
  end
  
  local reset_count = 0
  for device_idx, eq_device in ipairs(eq_devices) do
    if device_idx <= 4 then  -- Only process first 4 EQ10 devices
      -- Reset all gain parameters (2-9) to 0dB (skip problematic 1st/10th bands)
      for param_idx = 2, 9 do
        if eq_device.parameters[param_idx] then
          eq_device.parameters[param_idx].value = 0.0
          reset_count = reset_count + 1
        end
      end
    end
  end
  
  if eq_canvas then
    eq_canvas:update()
  end
  
  renoise.app():show_status(string.format("EQ30 reset to flat: %d parameters reset to 0dB (no autofocus)", reset_count))
end

-- Auto-load existing EQ settings when dialog opens (silent operation - makes it "just work")
local function auto_load_existing_eq_settings()
  local song = renoise.song()
  if not song or not song.selected_track then
    return
  end
  
  local track = song.selected_track
  local eq_devices = {}
  
  -- Find all EQ10 devices
  for i, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/EQ 10" then
      table.insert(eq_devices, device)
    end
  end
  
  -- Only auto-load if we have EQ devices (making it "just work")
  if #eq_devices >= 1 then
    print("🔄 Auto-loading existing EQ30 settings from " .. #eq_devices .. " devices...")
    
    -- Reset gains first
    for i = 1, #eq30_frequencies do
      eq_gains[i] = 0.0
    end
    
    -- Load gain values from EQ10 devices (EQ30 system: only middle 8 bands per device)
    for device_idx, device in ipairs(eq_devices) do
      if device_idx <= 4 then  -- Process up to 4 devices for EQ30
        local start_band = (device_idx - 1) * 8 + 1  -- 8 bands per device
        
        -- Load from parameters 2-9 (middle bands only, avoiding problematic 1st/10th)
        for param_idx = 2, 9 do
          local band_index = start_band + (param_idx - 2)  -- param 2 maps to band 1 of this device
          if band_index <= #eq30_frequencies and device.parameters[param_idx] then
            eq_gains[band_index] = device.parameters[param_idx].value
          end
        end
      end
    end
    
    -- Update canvas to show loaded settings
    if eq_canvas then
      eq_canvas:update()
    end
    
    print("Auto-loaded EQ30 settings from existing devices - canvas updated")
  end
end

-- Load EQ curve from current track devices
local function load_eq_from_track()
  local song = renoise.song()
  if not song or not song.selected_track then
    renoise.app():show_status("No track selected")
    return
  end
  
  local track = song.selected_track
  local eq_devices = {}
  
  -- Find EQ10 devices on track
  for i, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/EQ 10" then
      table.insert(eq_devices, device)
    end
  end
  
  if #eq_devices == 0 then
    renoise.app():show_status("No EQ10 devices found on selected track")
    return
  end
  
  -- Reset gains first
  for i = 1, #eq30_frequencies do
    eq_gains[i] = 0.0
  end
  
  -- Load gain values from EQ10 devices (EQ30 system: only middle 8 bands per device)
  for device_idx, device in ipairs(eq_devices) do
    if device_idx <= 4 then  -- Process up to 4 devices for EQ30
      local start_band = (device_idx - 1) * 8 + 1  -- 8 bands per device
      
      -- Load from parameters 2-9 (middle bands only, avoiding problematic 1st/10th)
      for param_idx = 2, 9 do
        local band_index = start_band + (param_idx - 2)  -- param 2 maps to band 1 of this device
        if band_index <= #eq30_frequencies and device.parameters[param_idx] then
          eq_gains[band_index] = device.parameters[param_idx].value
          print(string.format("Loaded Device %d, Param %d → Band %d (%.0fHz): %.1f dB", 
            device_idx, param_idx, band_index, eq30_frequencies[band_index], eq_gains[band_index]))
        end
      end
    end
  end
  
  if eq_canvas then
    eq_canvas:update()
  end
  
  update_eq_status()
  renoise.app():show_status(string.format("Loaded EQ30 settings from %d devices (middle 8 bands each)", #eq_devices))
end

-- Create the main EQ dialog
local function create_eq_dialog()
  if eq_dialog and eq_dialog.visible then
    pcall(function() EQ30Cleanup() end)
    eq_dialog:close()
  end

  -- Defensive reset when opening fresh
  EQ30Cleanup()

  -- Small delay to ensure UI has torn down before creating a new dialog
  -- Not using timers; just proceed to rebuild all views cleanly
  
  -- Create fresh ViewBuilder instance to avoid duplicate ID errors
  vb = renoise.ViewBuilder()
  
  local dialog_content = vb:column {
    
    -- Status indicator removed to avoid an empty spacer row above the controls
    
    -- Top control row (above canvas): Reset Flat, Automation controls, Global Q
    vb:row {
      -- Reset Flat
      vb:button {
        text = "Reset Flat",
        width = 100,
        tooltip = "Reset all bands to 0 dB (live updates)",
        notifier = function()
          reset_eq_flat()
          for i = 1, #eq30_frequencies do
            update_eq_device_parameter(i, 0.0)
          end
          renoise.app():show_status("EQ30 reset to flat - middle 8 bands of all devices updated")
        end
      },
      -- Snapshot to automation
      vb:button {
        text = "Add Snapshot to Automation",
        width = 180,
        notifier = function()
          snapshot_all_bands_to_automation()
        end
      },
      -- Clear automation
      vb:button {
        text = "Clear",
        width = 80,
        notifier = function()
          clear_all_eq30_automation()
        end
      },
      -- Clean & Snap automation
      vb:button {
        text = "Clean & Snap",
        width = 120,
        notifier = function()
          clean_and_snap_all_bands()
        end
      },
      -- Automation sync toggle
      vb:button {
        id = "eq30_follow_automation_button",
        text = "Automation Sync: OFF",
        width = 170,
        color = {64, 200, 64},
        notifier = function()
          follow_automation = not follow_automation
          if vb.views.eq30_follow_automation_button then
            vb.views.eq30_follow_automation_button.text = follow_automation and "Automation Sync: ON" or "Automation Sync: OFF"
            vb.views.eq30_follow_automation_button.color = follow_automation and {255, 64, 64} or {64, 200, 64}
          end
          renoise.song().transport.follow_player = follow_automation
          renoise.app():show_status("Automation Sync " .. (follow_automation and "ON" or "OFF"))
        end
      },
      -- Randomize automation
      vb:button {
        text = "Randomize Automation",
        width = 160,
        notifier = function()
          randomize_eq_curve("smooth")
          snapshot_all_bands_to_automation()
        end
      },
      vb:space { width = 20 },
      -- Global Q / Bandwidth
      vb:text {
        text = "Global Q",
        width = 60, style = "strong", font = "bold",
        tooltip = "Controls the bandwidth (sharpness) of all EQ bands simultaneously"
      },
      vb:slider {
        id = "global_bandwidth_slider",
        min = 0.05,
        max = 0.8,
        value = global_bandwidth,
        width = 200,
        tooltip = "Adjust the bandwidth of all EQ bands (left = sharp, right = wide)",
        notifier = function(value)
          global_bandwidth = value
          update_global_bandwidth(value)
          if vb.views.global_bandwidth_label then
            local approx_q = math.max(0.1, 1.0 / (value * 10))
            vb.views.global_bandwidth_label.text = string.format("BW:%.2f (≈Q %.1f)", value, approx_q)
          end
        end
      },
      vb:text {
        id = "global_bandwidth_label",style="strong",font="bold",
        text = string.format("BW:%.2f (≈Q %.1f)", global_bandwidth, math.max(0.1, 1.0 / (global_bandwidth * 10))),
        width = 100,
        tooltip = "Current bandwidth value and approximate Q factor"
      }
    },
    
    -- Canvas
    vb:canvas {
      id = "eq_canvas",
      width = canvas_width,
      height = canvas_height,
      mode = "plain",
      render = draw_eq_canvas,
      mouse_handler = handle_eq_mouse,
      mouse_events = {"down", "up", "move", "exit"}
    },
    
    -- Controls - Simplified for live interaction
    vb:row {
      vb:button {
        text = "Load from Track", 
        width = 120,
        tooltip = "Load EQ settings from existing EQ10 devices",
        notifier = function()
          load_eq_from_track()
        end
      },
      vb:button {
        id = "eq30_create_follow_button",
        text = "Create/Follow: OFF",
        width = 140,
        color = {64, 200, 64},
        tooltip = "When ON: follow selected track, auto-load its EQ30; if missing, click canvas to create",
        notifier = function()
          create_follow_enabled = not create_follow_enabled
          if vb.views.eq30_create_follow_button then
            vb.views.eq30_create_follow_button.text = create_follow_enabled and "Create/Follow: ON" or "Create/Follow: OFF"
            vb.views.eq30_create_follow_button.color = create_follow_enabled and {255, 64, 64} or {64, 200, 64}
          end
          local song = renoise.song()
          if create_follow_enabled and song and song.selected_track_index_observable then
            -- Install track observer
            track_index_notifier = function()
              if not (eq_dialog and eq_dialog.visible and create_follow_enabled) then return end
              -- Reset observers and reload for the newly selected track
              pcall(function() remove_eq_param_observers() end)
              local has_eq, _ = check_eq_devices_status()
              if has_eq then
                load_eq_from_track()
                setup_eq_param_observers()
              else
                -- Clear gains display to flat and update status; wait for user click to create
                for i = 1, #eq30_frequencies do
                  eq_gains[i] = 0.0
                end
                if eq_canvas then eq_canvas:update() end
              end
              update_eq_status()
            end
            -- Add notifier and trigger once immediately for current track
            song.selected_track_index_observable:add_notifier(track_index_notifier)
            track_index_notifier()
          else
            -- Remove track observer when toggled OFF
            pcall(function()
              if song and song.selected_track_index_observable and track_index_notifier then
                if song.selected_track_index_observable:has_notifier(track_index_notifier) then
                  song.selected_track_index_observable:remove_notifier(track_index_notifier)
                end
              end
            end)
            track_index_notifier = nil
            update_eq_status()
          end
        end
      },
      -- Reset Flat moved to the top control row
      vb:button {
        text = "Recreate Devices",
        width = 130,
        tooltip = "Force recreate the 4 EQ10 devices for EQ30 system",
        notifier = function()
          apply_eq30_to_track()
          renoise.app():show_status("EQ30 devices recreated - ready for live drawing!")
        end
      },
      vb:button {
        text = "Close",
        width = 80,
        notifier = function()
          if eq_dialog then
            pcall(function() EQ30Cleanup() end)
            eq_dialog:close()
            eq_dialog = nil
          end
        end
      },
    
    -- Randomize buttons
    
      vb:text {
        text = "Randomize",style="strong",font="bold",
        width = 80
      },
      vb:button {
        text = "Smooth",
        width = 80,
        tooltip = "Generate smooth, musical random EQ curve with gentle peaks",
        notifier = function()
          randomize_eq_curve("smooth")
        end
      },
      vb:button {
        text = "Surgical",
        width = 80,
        tooltip = "Generate surgical random EQ with sharp individual band adjustments",
        notifier = function()
          randomize_eq_curve("surgical")
        end
      },
      vb:button {
        text = "Creative",
        width = 80,
        tooltip = "Generate wild and experimental random EQ curve",
        notifier = function()
          randomize_eq_curve("creative")
        end
      },
      vb:text { text = "Automation Playmode", width = 130, style = "strong",font="bold" },
      vb:switch {
        id = "eq30_playmode_switch_1",
        width = 300,
        items = {"Points","Lines","Curves"},
        value = (preferences and preferences.PakettiEQ30AutomationPlaymode and preferences.PakettiEQ30AutomationPlaymode.value) or 2,
        notifier = function(value)
          if preferences and preferences.PakettiEQ30AutomationPlaymode then
            preferences.PakettiEQ30AutomationPlaymode.value = value
            preferences:save_as("preferences.xml")
          end
          local mode = renoise.PatternTrackAutomation.PLAYMODE_POINTS
          if value == 2 then mode = renoise.PatternTrackAutomation.PLAYMODE_LINES
          elseif value == 3 then mode = renoise.PatternTrackAutomation.PLAYMODE_CURVES end
          eq30_set_automation_playmode(mode)
        end
      }
    },
    vb:row {
      vb:checkbox {
        id = "autofocus_checkbox",
        value = autofocus_enabled,
        width = 20,
        tooltip = "Automatically focus the EQ10 device being modified in the lower frame",
        notifier = function(value)
          autofocus_enabled = value
          local status_text = autofocus_enabled and "enabled" or "disabled"
          renoise.app():show_status(string.format("EQ10 device autofocus %s", status_text))
        end
      },
      vb:text {
        text = "Autofocus selected EQ10 device",
        tooltip = "When enabled, automatically shows the EQ10 device being modified in the lower frame"
      },
    -- Minimize/Maximize devices option
      vb:checkbox {
        id = "minimize_devices_checkbox",
        value = devices_minimized,
        width = 20,
        tooltip = "Minimize or maximize all EQ10 devices to save screen space",
        notifier = function(value)
          devices_minimized = value
          toggle_eq_devices_size()
        end
      },
      vb:text {
        text = "Minimize EQ10 devices",
        tooltip = "When enabled, minimizes all EQ10 devices to save screen space and focus on the canvas"
      }
    },
    
    -- Global Q controls moved to top control row
    
    
  }
  
  eq_dialog = renoise.app():show_custom_dialog("Paketti EQ30 with Automation Controls",dialog_content,my_keyhandler_func)
  
  eq_canvas = vb.views.eq_canvas
  -- Ensure Renoise grabs keyboard focus for the middle frame after opening the dialog
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  -- Initialize autofocus checkbox state
  if vb.views.autofocus_checkbox then
    vb.views.autofocus_checkbox.value = autofocus_enabled
  end
  
  -- Initialize minimize devices checkbox state
  if vb.views.minimize_devices_checkbox then
    vb.views.minimize_devices_checkbox.value = devices_minimized
  end
  
  -- Initialize global bandwidth slider state
  if vb.views.global_bandwidth_slider then
    vb.views.global_bandwidth_slider.value = global_bandwidth
  end
  if vb.views.global_bandwidth_label then
    local approx_q = math.max(0.1, 1.0 / (global_bandwidth * 10))
    vb.views.global_bandwidth_label.text = string.format("BW:%.2f (≈Q %.1f)", global_bandwidth, approx_q)
  end
  
  -- Auto-create EQ devices if they don't exist
  ensure_eq_devices_exist()
  
  -- Auto-load existing EQ settings if devices already exist (makes it "just work")
  auto_load_existing_eq_settings()

  -- Always set up observers so the canvas follows playback in realtime (like PakettiCanvasExperiments)
  setup_eq_param_observers()
  
  -- Check initial EQ device status
  update_eq_status()
  
  -- Check if we auto-loaded settings
  local song = renoise.song()
  local existing_devices = 0
  if song and song.selected_track then
    for i, device in ipairs(song.selected_track.devices) do
      if device.device_path == "Audio/Effects/Native/EQ 10" then
        existing_devices = existing_devices + 1
      end
    end
  end
  
  local autofocus_status = autofocus_enabled and "with autofocus enabled" or "with autofocus disabled"
  local load_status = existing_devices > 0 and " (auto-loaded existing settings)" or ""


  -- Ensure toggle reflects actual follow_automation state on open
  if vb.views.eq30_follow_automation_button then
    vb.views.eq30_follow_automation_button.text = follow_automation and "Automation Sync: ON" or "Automation Sync: OFF"
    vb.views.eq30_follow_automation_button.color = follow_automation and {255, 64, 64} or {64, 200, 64}
  end

  -- No closed_observable on Dialog in current API; cleanup is done on manual Close and before re-open
end

-- Initialize the EQ30 experiment
function PakettiEQ10ExperimentInit()
  create_eq_dialog()
end

-- Add menu entry and keybinding
renoise.tool():add_menu_entry {name = "Main Menu:Tools:Paketti EQ30 Experiment", invoke = PakettiEQ10ExperimentInit}
renoise.tool():add_keybinding {name = "Global:Paketti:Paketti EQ30 Experiment", invoke = PakettiEQ10ExperimentInit}

-- Load & Show EQ30 toggle
function PakettiEQ30LoadAndShowToggle()
  local song = renoise.song()
  if not song or not song.selected_track then
    renoise.app():show_status("No track selected")
    return
  end
  -- Count EQ10s
  local eq_count = 0
  for i, device in ipairs(song.selected_track.devices) do
    if device.device_path == "Audio/Effects/Native/EQ 10" then
      eq_count = eq_count + 1
    end
  end
  local dialog_open = (eq_dialog and eq_dialog.visible)
  if eq_count >= 4 then
    -- We have EQ30 setup
    if dialog_open then
      eq_dialog:close(); eq_dialog = nil
      renoise.app():show_status("EQ30: Hide")
    else
      PakettiEQ10ExperimentInit()
      renoise.app():show_status("EQ30: Show")
    end
  else
    -- Not present -> add and show
    apply_eq30_to_track()
    PakettiEQ10ExperimentInit()
    renoise.app():show_status("EQ30: Added and Shown")
  end
end
-- Ensure EQ30 dialog is visible and follows the currently selected track
function PakettiEQ30ShowAndFollow()
  local song = renoise.song()
  if not song then return end

  -- Open if not visible
  if not (eq_dialog and eq_dialog.visible) then
    PakettiEQ10ExperimentInit()
  end

  -- Enable create/follow mode programmatically and install the observer
  create_follow_enabled = true
  if vb and vb.views and vb.views.eq30_create_follow_button then
    vb.views.eq30_create_follow_button.text = "Create/Follow: ON"
    vb.views.eq30_create_follow_button.color = {255, 64, 64}
  end

  if song.selected_track_index_observable then
    if not track_index_notifier then
      track_index_notifier = function()
        if not (eq_dialog and eq_dialog.visible and create_follow_enabled) then return end
        pcall(function() remove_eq_param_observers() end)
        local has_eq, _ = check_eq_devices_status()
        if has_eq then
          load_eq_from_track()
          setup_eq_param_observers()
        else
          for i = 1, #eq30_frequencies do eq_gains[i] = 0.0 end
          if eq_canvas then eq_canvas:update() end
        end
        update_eq_status()
      end
    end
    if not song.selected_track_index_observable:has_notifier(track_index_notifier) then
      song.selected_track_index_observable:add_notifier(track_index_notifier)
    end
    track_index_notifier()
  end
end

-- Toggle: if dialog visible -> close, else show & follow
function PakettiEQ30ToggleShowFollow()
  if eq_dialog and eq_dialog.visible then
    pcall(function() EQ30Cleanup() end)
    eq_dialog:close(); eq_dialog = nil
    renoise.app():show_status("EQ30: Hide")
    return
  end
  PakettiEQ30ShowAndFollow()
  renoise.app():show_status("EQ30: Show & Follow")
end
renoise.tool():add_keybinding {name = "Global:Paketti:Load & Show EQ30", invoke = PakettiEQ30ShowAndFollow}
renoise.tool():add_menu_entry {name = "Main Menu:Tools:Load & Show EQ30", invoke = PakettiEQ30ShowAndFollow}
renoise.tool():add_midi_mapping{name = "Paketti:Load & Show EQ30", invoke=function(message) if message:is_trigger() then PakettiEQ30ToggleShowFollow() end end}





