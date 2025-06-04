---@diagnostic disable: need-check-nil
local s = nil
local d = nil
local ticks = 20
local devices = {}
local filtered
local p
local last_selected_param_name = nil

-- Helper function to get device key using track and device indices
function get_device_key()
  local song = renoise.song()
  if not song then
    return nil
  end
  return song.selected_track_index .. "_" .. song.selected_device_index
end

-- Helper function to clean up stale device references
function refresh_device_state()
  s = renoise.song()
  if not s then
    return false
  end
  
  -- Use selected_device directly
  d = s.selected_device
  if not d then
    return false
  end
  
  return true
end

-- Helper function to get the best device name
function get_device_name(device)
  if device.display_name and device.display_name ~= "" and device.display_name ~= device.name then
    return device.display_name
  else
    return device.short_name
  end
end

function filter_inplace(arr, func)
  local new_index = 1
  local size_orig = #arr
  for old_index, v in ipairs(arr) do
    if func(v, old_index) then
        arr[new_index] = v
        new_index = new_index + 1
    end
  end
  for i = new_index, size_orig do
    arr[i] = nil
  end
  return arr
end

function index(arr, value)
  if not value then
    return nil
  end
  
  -- Safely get value name
  local value_name
  local success, result = pcall(function() return value.name end)
  if not success then
    return nil -- Value parameter is no longer valid
  end
  value_name = result
  
  for k, v in pairs(arr) do
    -- Safely get array item name
    local v_name
    local success, result = pcall(function() return v.name end)
    if success and result == value_name then
      return k
    end
  end
  return nil
end

function show_it()
  print("DEBUG: show_it() called")
  
  -- First, remember the current parameter from whatever device is currently selected
  local song = renoise.song()
  if song and song.selected_device then
    local current_key = song.selected_track_index .. "_" .. song.selected_device_index
    print("DEBUG: Current device key: " .. current_key)
    
    if devices[current_key] then
      local success, param_name = pcall(function() return devices[current_key].name end)
      if success then
        last_selected_param_name = param_name
        print("DEBUG: Remembered current parameter '" .. param_name .. "' from " .. current_key .. " before device change")
      else
        print("DEBUG: Failed to get parameter name from " .. current_key)
      end
    else
      print("DEBUG: No stored parameter for " .. current_key)
    end
  else
    print("DEBUG: No song or selected device")
  end
  
  if not refresh_device_state() then
    print("DEBUG: refresh_device_state failed in show_it")
    return
  end
  
  local device_key = get_device_key()
  if not device_key then
    print("DEBUG: No device key in show_it")
    return
  end
  
  print("DEBUG: Processing device at " .. device_key)
  
  filtered = filter_inplace(d.parameters, function(i) return i.show_in_mixer end)
  print("DEBUG: Device has " .. #filtered .. " mixer parameters")
  
  -- Always try to match parameter by name first
  if #filtered >= 1 then
    print("DEBUG: Trying to match parameter by name...")
    local matched = try_match_parameter_by_name()
    print("DEBUG: Parameter matching result: " .. tostring(matched))
    
    if not matched and not devices[device_key] then
      print("DEBUG: No match and no stored parameter, using first parameter")
      devices[device_key] = filtered[1] -- Fallback to first parameter only if no stored parameter
    else
      print("DEBUG: Have match or stored parameter, device_key stored: " .. tostring(devices[device_key] ~= nil))
    end
  else
    print("DEBUG: No mixer parameters available")
  end
  
  if devices[device_key] ~= nil then
    -- Safely check if stored parameter is still valid
    local param = devices[device_key]
    local success, param_name = pcall(function() return param.name end)
    if not success then
      -- Parameter is no longer valid, reset to first available
      print("DEBUG: Stored parameter is invalid, resetting to first")
      devices[device_key] = filtered[1]
      param = devices[device_key]
      success, param_name = pcall(function() return param.name end)
    end
    
    if success then
      local param_number = index(filtered, param) or 1
      local param_value
      local value_success, value_result = pcall(function() return param.value end)
      if value_success then
        param_value = string.format("%.3f", value_result)
      else
        param_value = "N/A"
      end
      print("DEBUG: Final result - showing parameter '" .. param_name .. "' at position " .. param_number)
      renoise.app():show_status(get_device_name(d) .. ": " .. string.format("%02d", param_number) .. ": " .. param_name .. ": " .. param_value)
    else
      print("DEBUG: Still failed to get parameter name after reset")
    end
  else
    print("DEBUG: No parameter stored for device " .. device_key .. " after processing")
  end
end

function param_next()
  remember_current_parameter() -- Remember before changing
  
  if not refresh_device_state() then
    renoise.app():show_status("No device selected")
    return
  end
  
  local device_key = get_device_key()
  if not device_key then
    return
  end
  
  local filtered = filter_inplace(d.parameters, function(i) return i.show_in_mixer end)
  if #filtered == 0 then
    renoise.app():show_status("No mixer parameters available")
    return
  end
  
  local current_index = index(filtered, devices[device_key])
  if not current_index then
    current_index = 0
  end
  
  local n = current_index + 1
  if n > #filtered then
    n = 1  -- Wrap around to first parameter
  end
  
  devices[device_key] = filtered[n]
  local track_index = s.selected_track_index
  local device_index = s.selected_device_index
  renoise.app():show_status("TRACK " .. string.format("%02d", track_index) .. ": Device " .. string.format("%02d", device_index) .. ": " .. get_device_name(d) .. ": " .. string.format("%02d", n) .. ": " .. filtered[n].name .. ": " .. string.format("%.3f", filtered[n].value))
  print("TRACK " .. string.format("%02d", track_index) .. ": Device " .. string.format("%02d", device_index) .. ": " .. get_device_name(d) .. ": " .. string.format("%02d", n) .. ": " .. filtered[n].name .. ": " .. string.format("%.3f", filtered[n].value))
end

function param_prev()
  remember_current_parameter() -- Remember before changing
  
  if not refresh_device_state() then
    renoise.app():show_status("No device selected")
    return
  end
  
  local device_key = get_device_key()
  if not device_key then
    return
  end
  
  local filtered = filter_inplace(d.parameters, function(i) return i.show_in_mixer end)
  if #filtered == 0 then
    renoise.app():show_status("No mixer parameters available")
    return
  end
  
  local current_index = index(filtered, devices[device_key])
  if not current_index then
    current_index = 2
  end
  
  local n = current_index - 1
  if n < 1 then
    n = #filtered  -- Wrap around to last parameter
  end
  
  devices[device_key] = filtered[n]
  local track_index = s.selected_track_index
  local device_index = s.selected_device_index
  renoise.app():show_status("TRACK " .. string.format("%02d", track_index) .. ": Device " .. string.format("%02d", device_index) .. ": " .. get_device_name(d) .. ": " .. string.format("%02d", n) .. ": " .. filtered[n].name .. ": " .. string.format("%.3f", filtered[n].value))
  print("TRACK " .. string.format("%02d", track_index) .. ": Device " .. string.format("%02d", device_index) .. ": " .. get_device_name(d) .. ": " .. string.format("%02d", n) .. ": " .. filtered[n].name .. ": " .. string.format("%.3f", filtered[n].value))
end

function param_up()
  remember_current_parameter() -- Remember before changing
  
  if not refresh_device_state() then
    renoise.app():show_status("No device selected")
    return
  end
  
  local device_key = get_device_key()
  if not device_key then
    return
  end
  
  local param = devices[device_key]
  if not param then
    local track_index = s.selected_track_index
    local device_index = s.selected_device_index
    print("DEBUG: No parameter stored for TRACK " .. string.format("%02d", track_index) .. ": Device " .. string.format("%02d", device_index) .. ": " .. get_device_name(d))
    renoise.app():show_status("No parameter selected for this device")
    return
  end
  
  -- Check if parameter is still valid
  local success, param_name = pcall(function() return param.name end)
  if not success then
    renoise.app():show_status("Selected parameter is no longer valid")
    devices[device_key] = nil -- Clear invalid reference
    return
  end
  
  local v = (param.value_max - param.value_min) / ticks
  local new_value = math.min(param.value_max, param.value + v)
  
  -- Find parameter number in filtered list
  local filtered = filter_inplace(d.parameters, function(i) return i.show_in_mixer end)
  local param_number = index(filtered, param) or 1
  
  if new_value == param.value then
    renoise.app():show_status(get_device_name(d) .. ": " .. string.format("%02d", param_number) .. ": " .. param_name .. ": " .. string.format("%.3f", param.value) .. " (Already at the highest value)")
  else
    param.value = new_value
    renoise.app():show_status(get_device_name(d) .. ": " .. string.format("%02d", param_number) .. ": " .. param_name .. ": " .. string.format("%.3f", param.value))
  end
end

function param_down()
  remember_current_parameter() -- Remember before changing
  
  if not refresh_device_state() then
    renoise.app():show_status("No device selected")
    return
  end
  
  local device_key = get_device_key()
  if not device_key then
    return
  end
  
  local param = devices[device_key]
  if not param then
    local track_index = s.selected_track_index
    local device_index = s.selected_device_index
    print("DEBUG: No parameter stored for TRACK " .. string.format("%02d", track_index) .. ": Device " .. string.format("%02d", device_index) .. ": " .. get_device_name(d))
    renoise.app():show_status("No parameter selected for this device")
    return
  end
  
  -- Check if parameter is still valid
  local success, param_name = pcall(function() return param.name end)
  if not success then
    renoise.app():show_status("Selected parameter is no longer valid")
    devices[device_key] = nil -- Clear invalid reference
    return
  end
  
  local v = (param.value_max - param.value_min) / ticks
  local new_value = math.max(param.value_min, param.value - v)
  
  -- Find parameter number in filtered list
  local filtered = filter_inplace(d.parameters, function(i) return i.show_in_mixer end)
  local param_number = index(filtered, param) or 1
  
  if new_value == param.value then
    renoise.app():show_status(get_device_name(d) .. ": " .. string.format("%02d", param_number) .. ": " .. param_name .. ": " .. string.format("%.3f", param.value) .. " (Already at the lowest value)")
  else
    param.value = new_value
    renoise.app():show_status(get_device_name(d) .. ": " .. string.format("%02d", param_number) .. ": " .. param_name .. ": " .. string.format("%.3f", param.value))
  end
end



renoise.tool():add_keybinding {name="Mixer:Device:Parama Param Next Parameter",invoke = param_next}
renoise.tool():add_keybinding {name="Mixer:Device:Parama Param Previous Parameter",invoke = param_prev}
renoise.tool():add_keybinding {name="Mixer:Device:Parama Param Increase",invoke = param_up}
renoise.tool():add_keybinding {name="Mixer:Device:Parama Param Decrease",invoke = param_down}
renoise.tool():add_menu_entry {name="Mixer:Device:Parama Param Next Parameter",invoke = param_next}
renoise.tool():add_menu_entry {name="Mixer:Device:Parama Param Previous Parameter",invoke = param_prev}
renoise.tool():add_menu_entry {name="Mixer:Device:Parama Param Increase",invoke = param_up}
renoise.tool():add_menu_entry {name="Mixer:Device:Parama Param Decrease",invoke = param_down}


-- Helper function for direct parameter access
function adjust_parameter_by_number(param_num, direction)
  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song loaded")
    return
  end
  
  local selected_device = song.selected_device
  if not selected_device then
    renoise.app():show_status("No device selected")
    return
  end
  
  local filtered = filter_inplace(selected_device.parameters, function(i) return i.show_in_mixer end)
  if #filtered == 0 then
    renoise.app():show_status("No mixer parameters available")
    return
  end
  
  if param_num > #filtered then
    local track_index = song.selected_track_index
    local device_index = song.selected_device_index
    renoise.app():show_status("TRACK " .. string.format("%02d", track_index) .. ": Device " .. string.format("%02d", device_index) .. ": " .. get_device_name(selected_device) .. " - Parameter " .. string.format("%02d", param_num) .. " not available (only " .. string.format("%02d", #filtered) .. " mixer parameters)")
    return
  end
  
  local param = filtered[param_num]
  local v = (param.value_max - param.value_min) / ticks
  local new_value
  
  if direction == "up" then
    new_value = math.min(param.value_max, param.value + v)
  else
    new_value = math.max(param.value_min, param.value - v)
  end
  
  local track_index = song.selected_track_index
  local device_index = song.selected_device_index
  
  if new_value == param.value then
    local limit_msg = direction == "up" and " (Already at the highest value)" or " (Already at the lowest value)"
    renoise.app():show_status("TRACK " .. string.format("%02d", track_index) .. ": Device " .. string.format("%02d", device_index) .. ": " .. get_device_name(selected_device) .. ": " .. string.format("%02d", param_num) .. ": " .. param.name .. ": " .. string.format("%.3f", param.value) .. limit_msg)
  else
    param.value = new_value
    renoise.app():show_status("TRACK " .. string.format("%02d", track_index) .. ": Device " .. string.format("%02d", device_index) .. ": " .. get_device_name(selected_device) .. ": " .. string.format("%02d", param_num) .. ": " .. param.name .. ": " .. string.format("%.3f", param.value))
  end
end

-- Create 16 parameter keybindings (01-16)
for param_num = 1, 16 do
  local param_num_str = string.format("%02d", param_num)
  
  renoise.tool():add_keybinding {
    name = "Mixer:Device:Parama Param Parameter " .. param_num_str .. " Value Increase",
    invoke = function() adjust_parameter_by_number(param_num, "up") end
  }
  
  renoise.tool():add_keybinding {
    name = "Mixer:Device:Parama Param Parameter " .. param_num_str .. " Value Decrease", 
    invoke = function() adjust_parameter_by_number(param_num, "down") end
  }
end

-- Safe observable setup
local function setup_observables()
  if not renoise.song() then
    return
  end
  local song = renoise.song()
  
  s = song
  
  if song.selected_track_device_observable:has_notifier(show_it) then
    song.selected_track_device_observable:remove_notifier(show_it)
  end
  song.selected_track_device_observable:add_notifier(show_it)
  
  if song.selected_track_observable:has_notifier(show_it) then
    song.selected_track_observable:remove_notifier(show_it)
  end
  song.selected_track_observable:add_notifier(show_it)
end

if renoise.song() ~= nil then 
-- Initialize observables if song exists
  setup_observables()
else return
end

renoise.tool().app_new_document_observable:add_notifier(function()
  if renoise.song() then
    s = renoise.song()
    devices = {}
    setup_observables()
  end
end)

renoise.tool().app_release_document_observable:add_notifier(function()
  devices = {}
  s = nil
  d = nil
end)

-- Helper function to remember current parameter name
function remember_current_parameter()
  if not refresh_device_state() then
    return
  end
  
  local device_key = get_device_key()
  if device_key and devices[device_key] then
    local success, param_name = pcall(function() return devices[device_key].name end)
    if success then
      last_selected_param_name = param_name
    end
  end
end

-- Helper function to try matching parameter by name on track change
function try_match_parameter_by_name()
  print("DEBUG: try_match_parameter_by_name() called")
  print("DEBUG: last_selected_param_name = " .. (last_selected_param_name or "nil"))
  
  if not last_selected_param_name then
    print("DEBUG: No last selected parameter name, exiting")
    return false
  end
  
  if not refresh_device_state() then
    print("DEBUG: refresh_device_state failed")
    return false
  end
  
  local device_key = get_device_key()
  if not device_key then
    print("DEBUG: No device key")
    return false
  end
  
  print("DEBUG: Looking for parameter '" .. last_selected_param_name .. "' on device at " .. device_key)
  
  -- Look for parameter with the same name
  local filtered = filter_inplace(d.parameters, function(i) return i.show_in_mixer end)
  print("DEBUG: Device has " .. #filtered .. " mixer parameters")
  
  for i, param in ipairs(filtered) do
    local success, param_name = pcall(function() return param.name end)
    if success then
      print("DEBUG: Parameter " .. i .. ": " .. param_name)
      if param_name == last_selected_param_name then
        print("DEBUG: Found matching parameter '" .. param_name .. "'!")
        
        -- Always switch to the matching parameter if we find it
        local current_param = devices[device_key]
        local should_switch = false
        
        if not current_param then
          should_switch = true
          print("DEBUG: No current parameter stored, switching to matched parameter")
        else
          -- Check if the stored parameter is different or invalid
          local stored_success, stored_param_name = pcall(function() return current_param.name end)
          if not stored_success then
            should_switch = true
            print("DEBUG: Stored parameter is invalid, switching to matched parameter")
          elseif stored_param_name ~= param_name then
            should_switch = true
            print("DEBUG: Stored parameter '" .. stored_param_name .. "' != '" .. param_name .. "', switching")
          else
            print("DEBUG: Already have the right parameter stored, no switch needed")
          end
        end
        
        if should_switch then
          devices[device_key] = param
          print("DEBUG: Successfully switched to parameter '" .. param_name .. "' at " .. device_key)
          return true
        else
          print("DEBUG: No switch was needed")
          return true
        end
      end
    else
      print("DEBUG: Failed to get name for parameter " .. i)
    end
  end
  
  print("DEBUG: No matching parameter found for '" .. last_selected_param_name .. "'")
  return false
end

-----