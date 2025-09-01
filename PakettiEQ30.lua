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
local canvas_height = 390  -- Increased to accommodate band labels
-- Independent content margins
local content_margin_x = 35  -- horizontal margin (left/right)
local content_margin_y = 20 -- vertical margin (top/bottom)
local content_width = canvas_width - (content_margin_x * 2)
local content_height = canvas_height - (content_margin_y * 2)
local content_x = content_margin_x
local content_y = content_margin_y
-- Vertical nudge for entire drawn content (does not change border)
local content_y_offset = 8


local eq30_frequencies = {
  25, 31, 40, 50, 62, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 
  1000, 1300, 1600, 2000, 2500, 3150, 4000, 5000, 6200, 8000, 10000, 13000, 16000, 20000
}

-- Forward declaration removed: define as a proper global function below


-- Renoise EQ10 bandwidth parameter expects 0.0001 to 1 (smaller = sharper)
function calculate_third_octave_bandwidth(center_freq)
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
function EQ30Cleanup()
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

-- Shared canvas font (moved to PakettiCanvasFont.lua)
-- Use PakettiCanvasFontLetterFunctions for per-character drawing and PakettiCanvasFontDrawText for strings

-- Convert frequency to canvas X position (logarithmic scale)
function freq_to_x(frequency)
  local log_min = math.log10(eq30_frequencies[1])      -- 25 Hz
  local log_max = math.log10(eq30_frequencies[#eq30_frequencies])  -- 20 kHz
  local log_freq = math.log10(frequency)
  local normalized = (log_freq - log_min) / (log_max - log_min)
  return content_x + normalized * content_width
end

-- Convert canvas X position to frequency (logarithmic scale)
function x_to_freq(x)
  local normalized = (x - content_x) / content_width
  normalized = math.max(0, math.min(1, normalized))
  local log_min = math.log10(eq30_frequencies[1])
  local log_max = math.log10(eq30_frequencies[#eq30_frequencies])
  local log_freq = log_min + normalized * (log_max - log_min)
  return math.pow(10, log_freq)
end

-- Convert gain to canvas Y position (EQ10 full range: -20dB to +20dB)
function gain_to_y(gain_db)
  local normalized = (gain_db + 20) / 40  -- -20 to +20 dB range (EQ10 maximum)
  normalized = math.max(0, math.min(1, normalized))
  return (content_y - content_y_offset) + content_height - (normalized * content_height)
end

-- Convert canvas Y position to gain (EQ10 full range: -20dB to +20dB)
function y_to_gain(y)
  local normalized = 1 - ((y - (content_y - content_y_offset)) / content_height)
  normalized = math.max(0, math.min(1, normalized))
  return (normalized * 40) - 20  -- -20 to +20 dB range (EQ10 maximum)
end

-- Find nearest EQ band for a given frequency
function find_nearest_band(frequency)
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
function debug_eq_device_parameters(device, device_name)
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

-- Live update EQ10 device GAIN parameter for specific band (handles both EQ30 and EQ64 systems)
function update_eq_device_parameter(band_index, gain_value)
  local song = renoise.song()
  if not song or not song.selected_track then
    return
  end
  
  local track = song.selected_track
  
  -- Determine system type based on number of frequency bands
  local total_bands = #eq30_frequencies
  local bands_per_device = 8  -- Always use 8 bands per device (parameters 2-9)
  local devices_needed = math.ceil(total_bands / bands_per_device)
  
  -- Find which EQ10 device this band belongs to
  local device_num = math.ceil(band_index / bands_per_device)
  local band_in_device = ((band_index - 1) % bands_per_device) + 1  -- 1-8
  
  -- Map to actual EQ10 parameters (2-9, skipping problematic 1st and 10th bands)
  local eq_param_num = band_in_device + 1  -- band 1 maps to param 2, band 8 maps to param 9
  
  -- Validate device and parameter numbers
  if device_num > devices_needed or eq_param_num < 2 or eq_param_num > 9 then
    print(string.format("ERROR: Invalid mapping - Band %d → Device %d, Param %d", band_index, device_num, eq_param_num))
    return
  end
  
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
          -- Debug output for troubleshooting
          -- print(string.format("LIVE: EQ%d Band %d → Device %d Param %d = %.1f dB", total_bands, band_index, device_num, eq_param_num, gain_value))
        else
          print(string.format("ERROR: Parameter %d not found on device %d", eq_param_num, device_num))
        end
        break
      end
    end
  end
  
  if not target_device_index then
    print(string.format("ERROR: Could not find EQ10 device %d for band %d", device_num, band_index))
    return
  end
  
  -- Autofocus the selected EQ10 device if enabled
  if autofocus_enabled and target_device_index then
    -- SAFETY: Double-check we have a valid song object before setting device index
    local success, error_msg = pcall(function()
      if song and song.selected_device_index ~= nil then
        song.selected_device_index = target_device_index
        
        -- Make sure lower frame is visible and shows device chain
        renoise.app().window.lower_frame_is_visible = true
        renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
      end
    end)
    
    if not success then
      print(string.format("AUTOFOCUS ERROR: %s", error_msg))
    end
  end
end

-- Helper: get parameter object for band index (for automation writes) - handles both EQ30 and EQ64
function get_parameter_for_band(band_index)
  local song = renoise.song()
  if not song or not song.selected_track then return nil end
  local track = song.selected_track
  
  -- Use same logic as update_eq_device_parameter for consistency
  local bands_per_device = 8  -- Always use 8 bands per device (parameters 2-9)
  local device_num = math.ceil(band_index / bands_per_device)
  local band_in_device = ((band_index - 1) % bands_per_device) + 1  -- 1-8
  local eq_param_num = band_in_device + 1  -- band 1 maps to param 2, band 8 maps to param 9
  
  -- Find the target device
  local target_device = nil
  local count = 0
  for i, device in ipairs(track.devices) do
    if device.device_path == "Audio/Effects/Native/EQ 10" then
      count = count + 1
      if count == device_num then
        target_device = device
        break
      end
    end
  end
  
  if not target_device then return nil end
  
  -- Validate parameter number and return the gain parameter
  if eq_param_num >= 2 and eq_param_num <= 9 then
    return target_device.parameters[eq_param_num]
  else
    return nil
  end
end

-- Automation: write single parameter at current line
function write_parameter_to_automation(parameter, value, skip_select)
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
function snapshot_all_bands_to_automation()
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
function clear_all_eq30_automation()
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
function clean_and_snap_all_bands()
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
function eq30_set_automation_playmode(mode)
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
function show_automation_for_band(band_index)
  local parameter = get_parameter_for_band(band_index)
  if not parameter then return end
  local song = renoise.song()
  song.selected_automation_parameter = parameter
  renoise.app().window.lower_frame_is_visible = true
  renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
end

-- Remove all observers used for EQ30 automation following
function remove_eq_param_observers()
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
function setup_eq_param_observers()
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
function ensure_eq_devices_exist()
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
function check_eq_devices_status()
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
function toggle_eq_devices_size()
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
function update_global_bandwidth(bandwidth_value)
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

-- Randomize by EditStep - writes automation per EditStep with randomized values
function PakettiEQ30RandomizeByEditStep()
  trueRandomSeed()
  
  local song = renoise.song()
  if not song or not song.selected_track then
    renoise.app():show_status("No track selected")
    return
  end
  
  local edit_step = song.transport.edit_step
  if edit_step <= 0 then
    edit_step = 1  -- Treat EditStep 0 as 1 (every line)
  end
  
  local pattern = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern_track = song:pattern(pattern):track(track_index)
  local pattern_length = song:pattern(pattern).number_of_lines
  
  -- Clear all automation first
  clear_all_eq30_automation()
  
  local written_points = 0
  
  -- Write randomized automation at EditStep intervals
  for i = 1, #eq30_frequencies do
    local parameter = get_parameter_for_band(i)
    if parameter then
      local automation = pattern_track:find_automation(parameter)
      if not automation then
        automation = pattern_track:create_automation(parameter)
      end
      
      if automation then
        automation:clear()
        
        -- Write points at EditStep intervals
        for line = 1, pattern_length, edit_step do
          if line <= pattern_length then
            -- Generate random gain value (-12 to +12 dB for musical range)
            local random_gain = (math.random() - 0.5) * 24
            random_gain = math.max(-20, math.min(20, random_gain))
            
            -- Convert to normalized value for automation
            local normalized_value = (random_gain - parameter.value_min) / (parameter.value_max - parameter.value_min)
            normalized_value = math.max(0.0, math.min(1.0, normalized_value))
            
            automation:add_point_at(line, normalized_value)
            written_points = written_points + 1
            
            -- Update canvas display for the current random value
            eq_gains[i] = random_gain
          end
        end
        
        -- Set this envelope to POINTS mode after creating content
        automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_POINTS
      end
    end
  end
  
  -- Update canvas to show randomized values
  if eq_canvas then
    eq_canvas:update()
  end
  
  -- Apply random values to EQ devices as well
  for i = 1, #eq30_frequencies do
    update_eq_device_parameter(i, eq_gains[i])
  end
  
  renoise.app():show_status(string.format("EQ30 randomized per EditStep %d: %d automation points written", edit_step, written_points))
end

-- Randomize EQ curve with different patterns
function randomize_eq_curve(pattern_type)
  trueRandomSeed()

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
function update_eq_status()
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
function draw_eq_canvas(ctx)
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
    ctx:move_to(x, content_y - content_y_offset)
    ctx:line_to(x, (content_y - content_y_offset) + content_height)
    ctx:stroke()
  end
  
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
      local text_start_y = (content_y - content_y_offset) + 15 - math.floor(text_size * 0.5)  -- lift by ~0.5 char
      
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
        if char_y < (content_y - content_y_offset) + content_height - text_size - 5 then  -- Don't draw outside content area
          local char_func = PakettiCanvasFontLetterFunctions[char:upper()]
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
    -- Allow vertical tweak of bottom band number labels via content_y_offset
    local label_y_start = (content_y - content_y_offset) + content_height + 10
    
    -- Draw ALL band numbers (01-30) below each column
    local band_text = string.format("%02d", i)  -- 01, 02, 03, ..., 30
    local text_size = math.max(3, math.min(6, band_width * 0.4))  -- Scale text to fit narrow columns
    PakettiCanvasFontDrawText(ctx, band_text, bar_center_x - (#band_text * text_size/3), label_y_start, text_size)
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
    PakettiCanvasFontDrawText(ctx, text, left_x, y, label_size)
    PakettiCanvasFontDrawText(ctx, text, right_x, y, label_size)
  end

  -- Corner min/max labels removed per request
  
  -- Draw content area border (shifted with vertical offset)
  ctx.stroke_color = {80, 80, 120, 255}
  ctx.line_width = 2
  ctx:begin_path()
  ctx:rect(content_x, content_y - content_y_offset, content_width, content_height)
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
function handle_eq_mouse(ev)
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

  -- Check if mouse is within content area (respect vertical offset so hotspots match visuals)
  -- Allow some leniency outside the content vertically for better drawing UX
  local content_top = (content_y - content_y_offset) - 12
  local content_bottom = (content_y - content_y_offset) + content_height + 12
  local mouse_in_content = ev.position.x >= content_x - 6 and ev.position.x <= (content_x + content_width + 6) and 
                          ev.position.y >= content_top and ev.position.y <= content_bottom
  
  if not mouse_in_content and ev.type ~= "up" then
    return
  end
  
  local x = ev.position.x
  -- Use raw mouse Y; y_to_gain already compensates for content_y_offset
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
      -- Minimal status update without debug spam
      local eq_param_num = band_in_device + 1  -- Maps to params 2-9
      renoise.app():show_status(string.format("LIVE EQ30: %.0f Hz: %.1f dB", eq30_frequencies[band_index], eq_gains[band_index]))
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
      local eq_param_num = band_in_device + 1
      renoise.app():show_status(string.format("LIVE EQ30: %.0f Hz: %.1f dB", eq30_frequencies[band_index], eq_gains[band_index]))
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
function my_keyhandler_func(dialog, key)
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
function reset_eq_flat()
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
function auto_load_existing_eq_settings()
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
function load_eq_from_track()
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
function create_eq_dialog()
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
        color = {96, 96, 96},
        notifier = function()
          follow_automation = not follow_automation
          if vb.views.eq30_follow_automation_button then
            vb.views.eq30_follow_automation_button.text = follow_automation and "Automation Sync: ON" or "Automation Sync: OFF"
            vb.views.eq30_follow_automation_button.color = follow_automation and {0, 120, 0} or {96, 96, 96}
          end
          renoise.song().transport.follow_player = follow_automation
          renoise.app():show_status("Automation Sync " .. (follow_automation and "ON" or "OFF"))
        end
      },
      -- Randomize automation
      vb:button {
        text = "Randomize Automation Step",
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
        color = {96, 96, 96},
        tooltip = "When ON: follow selected track, auto-load its EQ30; if missing, click canvas to create",
        notifier = function()
          create_follow_enabled = not create_follow_enabled
          if vb.views.eq30_create_follow_button then
            vb.views.eq30_create_follow_button.text = create_follow_enabled and "Create/Follow: ON" or "Create/Follow: OFF"
            vb.views.eq30_create_follow_button.color = create_follow_enabled and {0, 120, 0} or {96, 96, 96}
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
        width = 60
      },
      vb:button {
        text = "Smooth",
        width = 60,
        tooltip = "Generate smooth, musical random EQ curve with gentle peaks",
        notifier = function()
          randomize_eq_curve("smooth")
        end
      },
      vb:button {
        text = "Surgical",
        width = 60,
        tooltip = "Generate surgical random EQ with sharp individual band adjustments",
        notifier = function()
          randomize_eq_curve("surgical")
        end
      },
      vb:button {
        text = "Creative",
        width = 60,
        tooltip = "Generate wild and experimental random EQ curve",
        notifier = function()
          randomize_eq_curve("creative")
        end
      },
      vb:button {
        text = "Randomize by EditStep",
        width = 180,
        tooltip = "Randomize automation at EditStep intervals (clear all, write at steps, set to Point mode)",
        notifier = function()
          PakettiEQ30RandomizeByEditStep()
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

  }
  
  eq_dialog = renoise.app():show_custom_dialog("Paketti EQ30 with Automation Controls",dialog_content,my_keyhandler_func)
  
  eq_canvas = vb.views.eq_canvas
  -- Ensure Renoise grabs keyboard focus for the middle frame after opening the dialog
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  -- Apply preferences for autofocus/minimize from global preferences
  if preferences and preferences.PakettiEQ30Autofocus ~= nil then
    autofocus_enabled = preferences.PakettiEQ30Autofocus.value and true or false
  end
  if preferences and preferences.PakettiEQ30MinimizeDevices ~= nil then
    devices_minimized = preferences.PakettiEQ30MinimizeDevices.value and true or false
    toggle_eq_devices_size()
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
    vb.views.eq30_follow_automation_button.color = follow_automation and {0, 120, 0} or {96, 96, 96}
  end

  -- No closed_observable on Dialog in current API; cleanup is done on manual Close and before re-open
end

-- Initialize the EQ30 experiment
function PakettiEQ10ExperimentInit()
  create_eq_dialog()
end

-- Add menu entry and keybinding
--renoise.tool():add_menu_entry {name = "Main Menu:Tools:Paketti EQ30", invoke = PakettiEQ10ExperimentInit}
--renoise.tool():add_keybinding {name = "Global:Paketti:Paketti EQ30", invoke = PakettiEQ10ExperimentInit}
--renoise.tool():add_midi_mapping{name = "Paketti:Paketti EQ30", invoke = function(message) if message:is_trigger() then PakettiEQ10ExperimentInit() end end}

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
    vb.views.eq30_create_follow_button.color = {0, 120, 0}
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
renoise.tool():add_keybinding {name = "Global:Paketti:Load & Show Paketti EQ30", invoke = PakettiEQ30ShowAndFollow}
renoise.tool():add_menu_entry {name = "Main Menu:Tools:Load & Show Paketti EQ30", invoke = PakettiEQ30ShowAndFollow}
renoise.tool():add_midi_mapping{name = "Paketti:Load & Show PakettiEQ30", invoke=function(message) if message:is_trigger() then PakettiEQ30ToggleShowFollow() end end}

-- Paketti EQ30 Unused Note Frequency Reduction Flavor
-- Analyzes selected track for used notes, generates EQ bands for unused note frequencies

-- Convert note value to frequency (A4 = 440Hz reference)
function note_to_frequency(note_value)
  if note_value == 121 then return nil end -- OFF/empty note
  return 440 * math.pow(2, (note_value - 69) / 12)
end

-- Scan selected track pattern(s) for used notes
function analyze_track_used_notes()
  local song = renoise.song()
  if not song or not song.selected_track then
    return {}
  end
  
  local track_index = song.selected_track_index
  local pattern_index = song.selected_pattern_index
  local pattern = song:pattern(pattern_index)
  local pattern_track = pattern:track(track_index)
  
  local used_notes = {}
  
  -- Scan all note columns in current pattern
  for line_index = 1, pattern.number_of_lines do
    local line = pattern_track:line(line_index)
    for col_index = 1, #line.note_columns do
      local note_col = line.note_columns[col_index]
      if note_col.note_value ~= 121 and note_col.note_value >= 0 and note_col.note_value <= 119 then
        used_notes[note_col.note_value] = true
      end
    end
  end
  
  print("=== Used Notes Analysis ===")
  local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
  local count = 0
  for note_value, _ in pairs(used_notes) do
    local octave = math.floor(note_value / 12)
    local note_name = note_names[(note_value % 12) + 1] .. octave
    local freq = note_to_frequency(note_value)
    print(string.format("  %s (note %d) = %.1f Hz", note_name, note_value, freq))
    count = count + 1
  end
  print(string.format("Total used notes: %d", count))
  
  return used_notes
end

-- Generate unused note frequencies for EQ30 system
function generate_unused_note_frequencies(used_notes)
  local unused_frequencies = {}
  local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
  
  -- Find the range of used notes
  local min_note, max_note = 119, 0
  for note_value, _ in pairs(used_notes) do
    min_note = math.min(min_note, note_value)
    max_note = math.max(max_note, note_value)
  end
  
  if min_note > max_note then
    -- No notes found, fall back to default frequencies
    return eq30_frequencies
  end
  
  -- Expand range by 1 octave in each direction for more comprehensive coverage
  local range_start = math.max(0, min_note - 12)
  local range_end = math.min(119, max_note + 12)
  
  print("=== Generating Unused Note Frequencies ===")
  print(string.format("Note range: %d to %d (expanded for coverage)", range_start, range_end))
  
  -- Collect unused notes in the expanded range
  local unused_notes = {}
  for note_value = range_start, range_end do
    if not used_notes[note_value] then
      local freq = note_to_frequency(note_value)
      if freq and freq >= 20 and freq <= 20000 then -- Audible range
        table.insert(unused_notes, {note = note_value, freq = freq})
        local octave = math.floor(note_value / 12)
        local note_name = note_names[(note_value % 12) + 1] .. octave
        print(string.format("  Unused: %s (note %d) = %.1f Hz", note_name, note_value, freq))
      end
    end
  end
  
  -- Sort by frequency
  table.sort(unused_notes, function(a, b) return a.freq < b.freq end)
  
  -- Extract frequencies and limit to 30 bands (EQ30 system)
  for i = 1, math.min(30, #unused_notes) do
    unused_frequencies[i] = unused_notes[i].freq
  end
  
  -- If we have fewer than 30 unused notes, fill remaining slots with harmonics
  if #unused_frequencies < 30 then
    print("=== Adding Harmonic Frequencies ===")
    local original_count = #unused_frequencies
    
    -- Add 2nd and 3rd harmonics of used notes (potential interference frequencies)
    for note_value, _ in pairs(used_notes) do
      if #unused_frequencies >= 30 then break end
      
      local fundamental_freq = note_to_frequency(note_value)
      
      -- 2nd harmonic (octave)
      local second_harmonic = fundamental_freq * 2
      if second_harmonic <= 20000 then
        table.insert(unused_frequencies, second_harmonic)
        print(string.format("  Added 2nd harmonic: %.1f Hz", second_harmonic))
      end
      
      if #unused_frequencies >= 30 then break end
      
      -- 3rd harmonic
      local third_harmonic = fundamental_freq * 3
      if third_harmonic <= 20000 then
        table.insert(unused_frequencies, third_harmonic)
        print(string.format("  Added 3rd harmonic: %.1f Hz", third_harmonic))
      end
    end
    
    -- Sort again after adding harmonics
    table.sort(unused_frequencies)
    
    -- Limit to exactly 30 bands
    while #unused_frequencies > 30 do
      table.remove(unused_frequencies)
    end
    
    print(string.format("Final frequency count: %d (was %d unused notes)", #unused_frequencies, original_count))
  end
  
  -- If still not enough frequencies, pad with default EQ30 frequencies
  if #unused_frequencies < 30 then
    print("=== Padding with Standard Frequencies ===")
    for i = #unused_frequencies + 1, 30 do
      if i <= #eq30_frequencies then
        unused_frequencies[i] = eq30_frequencies[i]
        print(string.format("  Padded with standard: %.0f Hz", eq30_frequencies[i]))
      end
    end
  end
  
  print(string.format("=== Generated %d unused note frequencies ===", #unused_frequencies))
  
  return unused_frequencies
end

-- Create EQ30 dialog with unused note frequencies
function create_unused_note_eq_dialog()
  -- Analyze current track
  local used_notes = analyze_track_used_notes()
  
  if not used_notes or not next(used_notes) then
    renoise.app():show_status("No notes found on selected track - select a track with notes first")
    return
  end
  
  -- Generate unused note frequencies
  local unused_frequencies = generate_unused_note_frequencies(used_notes)
  
  -- Temporarily replace the global frequency table
  local original_frequencies = eq30_frequencies
  eq30_frequencies = unused_frequencies
  
  -- Reset gains for new frequency set
  eq_gains = {}
  for i = 1, #eq30_frequencies do
    eq_gains[i] = 0.0
  end
  
  -- Create the dialog using existing EQ30 framework
  create_eq_dialog()
  
  -- Show analysis results
  local note_count = 0
  for _, _ in pairs(used_notes) do note_count = note_count + 1 end
  
  renoise.app():show_status(string.format("EQ30 Unused Note Reducer: %d used notes analyzed, %d reduction frequencies loaded", 
    note_count, #eq30_frequencies))
  
  print("=== EQ30 Unused Note Frequency Reduction Active ===")
  print("Use this EQ to notch out frequencies that might clash with your melody")
  print("Right-click canvas to reset, left-click/drag to adjust individual bands")
end

-- Wrapper function for menu/keybinding
function PakettiEQ30UnusedNoteFrequencyReductionFlavor()
  create_unused_note_eq_dialog()
end

-- Add menu entries and keybindings for the new feature
renoise.tool():add_menu_entry {name = "Main Menu:Tools:Paketti EQ30 Unused Note Frequency Reduction Flavor", invoke = PakettiEQ30UnusedNoteFrequencyReductionFlavor}
renoise.tool():add_keybinding {name = "Global:Paketti:Paketti EQ30 Unused Note Frequency Reduction Flavor", invoke = PakettiEQ30UnusedNoteFrequencyReductionFlavor}
renoise.tool():add_midi_mapping{name = "Paketti:Paketti EQ30 Unused Note Frequency Reduction Flavor", invoke = function(message) if message:is_trigger() then PakettiEQ30UnusedNoteFrequencyReductionFlavor() end end}

-- EQ64 Unused Note Frequency Reduction (64-band version using 8 EQ10 devices)
-- Generate unused note frequencies for EQ64 system (64 bands)
function generate_unused_note_frequencies_64(used_notes)
  local unused_frequencies = {}
  local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
  
  -- Find the range of used notes
  local min_note, max_note = 119, 0
  for note_value, _ in pairs(used_notes) do
    min_note = math.min(min_note, note_value)
    max_note = math.max(max_note, note_value)
  end
  
  if min_note > max_note then
    -- No notes found, fall back to extended default frequencies
    local extended_freqs = {}
    -- Create 64 logarithmically spaced frequencies from 20Hz to 20kHz
    for i = 1, 64 do
      local log_pos = (i - 1) / 63
      local freq = 20 * math.pow(1000, log_pos) -- 20Hz to 20kHz logarithmic
      extended_freqs[i] = freq
    end
    return extended_freqs
  end
  
  -- Expand range by 1 octave in each direction (more musical for 64-band coverage)
  local range_start = math.max(0, min_note - 12)
  local range_end = math.min(119, max_note + 12)
  
  print("=== Generating 64-Band Unused Note Frequencies ===")
  print(string.format("Note range: %d to %d (expanded 1 octave for musical coverage)", range_start, range_end))
  
  -- Collect unused notes in the expanded range
  local unused_notes = {}
  for note_value = range_start, range_end do
    if not used_notes[note_value] then
      local freq = note_to_frequency(note_value)
      if freq and freq >= 20 and freq <= 20000 then -- Audible range
        table.insert(unused_notes, {note = note_value, freq = freq})
        local octave = math.floor(note_value / 12)
        local note_name = note_names[(note_value % 12) + 1] .. octave
        print(string.format("  Unused: %s (note %d) = %.1f Hz", note_name, note_value, freq))
      end
    end
  end
  
  -- Sort by frequency
  table.sort(unused_notes, function(a, b) return a.freq < b.freq end)
  
  -- Extract frequencies and limit to 64 bands (EQ64 system)
  for i = 1, math.min(64, #unused_notes) do
    unused_frequencies[i] = unused_notes[i].freq
  end
  
  -- If we have fewer than 64 unused notes, fill remaining slots with harmonics and sub-harmonics
  if #unused_frequencies < 64 then
    print("=== Adding Harmonic & Sub-Harmonic Frequencies for 64-Band Coverage ===")
    local original_count = #unused_frequencies
    
    -- Add selective harmonics of used notes (only 2nd and 3rd harmonics for musical relevance)
    for note_value, _ in pairs(used_notes) do
      if #unused_frequencies >= 64 then break end
      
      local fundamental_freq = note_to_frequency(note_value)
      
      -- Add only 2nd harmonic (octave) and 3rd harmonic (musical fifth above octave)
      for harmonic = 2, 3 do
        if #unused_frequencies >= 64 then break end
        local harmonic_freq = fundamental_freq * harmonic
        if harmonic_freq <= 20000 then
          table.insert(unused_frequencies, harmonic_freq)
          print(string.format("  Added %d%s harmonic: %.1f Hz", harmonic, 
            (harmonic == 2 and "nd") or "rd", harmonic_freq))
        end
      end
    end
    
    -- Sort again after adding harmonics
    table.sort(unused_frequencies)
    
    -- Limit to exactly 64 bands
    while #unused_frequencies > 64 do
      table.remove(unused_frequencies)
    end
    
    print(string.format("After harmonics: %d frequencies (was %d unused notes)", #unused_frequencies, original_count))
  end
  
  -- If still not enough frequencies, pad with musically relevant frequencies
  if #unused_frequencies < 64 then
    print("=== Padding with Musical Frequencies ===")
    local current_count = #unused_frequencies
    
    -- Fill remaining slots with frequencies between existing ones (interpolation)
    table.sort(unused_frequencies)  -- Ensure sorted order
    local gaps_filled = {}
    
    -- Find gaps between existing frequencies and fill them
    for i = 1, #unused_frequencies - 1 do
      if current_count >= 64 then break end
      local freq1 = unused_frequencies[i]
      local freq2 = unused_frequencies[i + 1]
      local ratio = freq2 / freq1
      
      -- If there's a significant gap (more than 1.5x), add frequencies in between
      if ratio > 1.5 then
        local mid_freq = math.sqrt(freq1 * freq2)  -- Geometric mean
        table.insert(gaps_filled, mid_freq)
        current_count = current_count + 1
        print(string.format("  Filled gap between %.1f and %.1f Hz with %.1f Hz", freq1, freq2, mid_freq))
      end
    end
    
    -- Add the gap-filling frequencies
    for _, freq in ipairs(gaps_filled) do
      table.insert(unused_frequencies, freq)
    end
    
    -- If still not enough, use traditional EQ30 frequencies as fallback
    if #unused_frequencies < 64 then
      for i = #unused_frequencies + 1, 64 do
        if i <= #eq30_frequencies then
          table.insert(unused_frequencies, eq30_frequencies[i])
          print(string.format("  Padded with standard EQ30: %.0f Hz", eq30_frequencies[i]))
        else
          -- Create additional frequencies based on musical intervals
          local base_freq = unused_frequencies[#unused_frequencies]
          local new_freq = base_freq * 1.2  -- Minor third interval
          if new_freq <= 20000 then
            table.insert(unused_frequencies, new_freq)
            print(string.format("  Added musical interval: %.1f Hz", new_freq))
          end
        end
      end
    end
    
    -- Final sort and limit
    table.sort(unused_frequencies)
    while #unused_frequencies > 64 do
      table.remove(unused_frequencies)
    end
  end
  
  print(string.format("=== Generated %d unused note frequencies for EQ64 ===", #unused_frequencies))
  
  return unused_frequencies
end

-- Apply EQ64 system to track (8 EQ10 devices for 64 bands)
function apply_eq64_to_track()
  print("=== APPLY EQ64 TO TRACK START ===")
  
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
  
  -- EQ64 system using 8 EQ10 devices, only middle 8 bands each
  local devices_needed = 8
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
  
  -- Create EQ10 devices for 64-band system
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
    
    -- Set all parameters directly
    eq_device.display_name = string.format("EQ64 Device %d", device_idx)
    
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
        
        print(string.format("  Band %d: %.1fHz, BW=%.2f (using EQ param %d)", global_band, freq, bandwidth_value, band))
      else
        -- Neutral values for unused bands
        eq_device.parameters[band].value = 0.0              -- Gain = 0dB
        eq_device.parameters[band + 10].value = 1000        -- Frequency = 1kHz
        eq_device.parameters[band + 20].value = 0.5         -- Bandwidth = 0.5 (neutral)
      end
    end
    
    print(string.format("EQ10-%d configured for EQ64 system", device_idx))
  end
  
  print("=== EQ64 SETUP COMPLETE ===")
  print("Successfully created " .. devices_needed .. " EQ10 devices for 64-band system")
  print("Each device uses middle 8 bands (2-9) for precise control")
  
  renoise.app():show_status("EQ64 system created: 8 EQ10 devices with 64 total bands")
end

-- Create EQ64 dialog with unused note frequencies (64 bands)
function create_unused_note_eq64_dialog()
  -- Analyze current track
  local used_notes = analyze_track_used_notes()
  
  if not used_notes or not next(used_notes) then
    renoise.app():show_status("No notes found on selected track - select a track with notes first")
    return
  end
  
  -- Generate 64 unused note frequencies
  local unused_frequencies = generate_unused_note_frequencies_64(used_notes)
  
  -- Temporarily replace the global frequency table with 64 frequencies
  local original_frequencies = eq30_frequencies
  eq30_frequencies = unused_frequencies
  
  -- Reset gains for new frequency set (64 bands)
  eq_gains = {}
  for i = 1, #eq30_frequencies do
    eq_gains[i] = 0.0
  end
  
  -- Create EQ64 devices first
  apply_eq64_to_track()
  
  -- Create the dialog using existing EQ30 framework (but with 64 frequencies)
  create_eq_dialog()
  
  -- Show analysis results
  local note_count = 0
  for _, _ in pairs(used_notes) do note_count = note_count + 1 end
  
  renoise.app():show_status(string.format("EQ64 Unused Note Reducer: %d used notes analyzed, %d reduction frequencies loaded", 
    note_count, #eq30_frequencies))
  
  print("=== EQ64 Unused Note Frequency Reduction Active ===")
  print("64-band system for ultra-precise frequency cleanup")
  print("Use this EQ to surgically notch out frequencies that clash with your melody")
  print("Right-click canvas to reset, left-click/drag to adjust individual bands")
end

-- Wrapper function for menu/keybinding
function PakettiEQ64UnusedNoteFrequencyReductionFlavor()
  create_unused_note_eq64_dialog()
end

-- Add menu entries and keybindings for the 64-band version
renoise.tool():add_menu_entry {name = "Main Menu:Tools:Paketti EQ64 Unused Note Frequency Reduction Flavor", invoke = PakettiEQ64UnusedNoteFrequencyReductionFlavor}
renoise.tool():add_keybinding {name = "Global:Paketti:Paketti EQ64 Unused Note Frequency Reduction Flavor", invoke = PakettiEQ64UnusedNoteFrequencyReductionFlavor}
renoise.tool():add_midi_mapping{name = "Paketti:Paketti EQ64 Unused Note Frequency Reduction Flavor", invoke = function(message) if message:is_trigger() then PakettiEQ64UnusedNoteFrequencyReductionFlavor() end end}





