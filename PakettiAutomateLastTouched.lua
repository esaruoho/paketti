-- PakettiAutomateLastTouched.lua
-- FL Studio-style "Automate Last Touched Parameter" functionality
-- Touch any parameter, wait 3 seconds, automation gets created and automation view opens

--------------------------------------------------------------------------------
-- Global State Variables
--------------------------------------------------------------------------------

local last_touched_parameter = nil      -- The parameter reference
local last_touched_device = nil         -- The device it belongs to
local last_touched_track_index = nil    -- Track index where the device is
local watching_active = false           -- Is watching currently active
local inactivity_timer = nil            -- 3-second timeout timer function
local parameter_observers = {}          -- Table: parameter -> observer function
local watching_timeout_seconds = 3      -- Configurable timeout (default 3 sec)
local is_instrument_plugin = false      -- Flag to track if watching instrument plugin

--------------------------------------------------------------------------------
-- Cleanup Functions
--------------------------------------------------------------------------------

-- Remove all parameter observers safely
function PakettiAutomateLastTouchedCleanup()
  print("AUTOMATE_LAST_TOUCHED: Cleanup started")
  
  -- Remove inactivity timer if active
  if inactivity_timer then
    pcall(function()
      if renoise.tool():has_timer(inactivity_timer) then
        renoise.tool():remove_timer(inactivity_timer)
        print("AUTOMATE_LAST_TOUCHED: Removed inactivity timer")
      end
    end)
    inactivity_timer = nil
  end
  
  -- Remove all parameter observers safely
  for parameter, observer in pairs(parameter_observers) do
    pcall(function()
      if parameter and parameter.value_observable and parameter.value_observable:has_notifier(observer) then
        parameter.value_observable:remove_notifier(observer)
      end
    end)
  end
  parameter_observers = {}
  
  -- Reset state variables
  last_touched_parameter = nil
  last_touched_device = nil
  last_touched_track_index = nil
  watching_active = false
  is_instrument_plugin = false
  
  print("AUTOMATE_LAST_TOUCHED: Cleanup complete")
end

--------------------------------------------------------------------------------
-- Timer Functions
--------------------------------------------------------------------------------

-- Reset/restart the 3-second inactivity timer
function PakettiAutomateLastTouchedResetTimer()
  -- Remove existing timer if present
  if inactivity_timer then
    pcall(function()
      if renoise.tool():has_timer(inactivity_timer) then
        renoise.tool():remove_timer(inactivity_timer)
      end
    end)
    inactivity_timer = nil
  end
  
  -- Create new timer function
  inactivity_timer = function()
    print("AUTOMATE_LAST_TOUCHED: Timer expired - creating automation")
    
    -- Remove this timer
    pcall(function()
      if renoise.tool():has_timer(inactivity_timer) then
        renoise.tool():remove_timer(inactivity_timer)
      end
    end)
    inactivity_timer = nil
    
    -- Create automation for last touched parameter
    PakettiAutomateLastTouchedCreate()
    
    -- Cleanup
    PakettiAutomateLastTouchedCleanup()
  end
  
  -- Add timer (timeout in milliseconds)
  renoise.tool():add_timer(inactivity_timer, watching_timeout_seconds * 1000)
  print("AUTOMATE_LAST_TOUCHED: Timer reset - " .. watching_timeout_seconds .. " seconds until automation creation")
end

--------------------------------------------------------------------------------
-- Parameter Observer Callback
--------------------------------------------------------------------------------

-- Called when any watched parameter changes
function PakettiAutomateLastTouchedOnParameterTouched(param, device, track_index, is_plugin_instrument)
  if not watching_active then
    return
  end
  
  print("AUTOMATE_LAST_TOUCHED: Parameter touched: " .. param.name)
  
  -- Store the last touched parameter info
  last_touched_parameter = param
  last_touched_device = device
  last_touched_track_index = track_index
  is_instrument_plugin = is_plugin_instrument or false
  
  -- Show status
  renoise.app():show_status("Last touched: " .. param.name .. " - waiting " .. watching_timeout_seconds .. "s...")
  
  -- Reset the inactivity timer
  PakettiAutomateLastTouchedResetTimer()
end

--------------------------------------------------------------------------------
-- Parameter Watching Setup
--------------------------------------------------------------------------------

-- Add observers to all automatable parameters of a device
function PakettiAutomateLastTouchedSetupWatching(device, track_index, is_plugin_instrument)
  if not device then
    print("AUTOMATE_LAST_TOUCHED: No device provided for watching")
    return false
  end
  
  local param_count = 0
  
  for i = 1, #device.parameters do
    local param = device.parameters[i]
    
    if param.is_automatable then
      -- Create observer function for this parameter
      local observer = function()
        PakettiAutomateLastTouchedOnParameterTouched(param, device, track_index, is_plugin_instrument)
      end
      
      -- Add notifier
      if not param.value_observable:has_notifier(observer) then
        param.value_observable:add_notifier(observer)
        parameter_observers[param] = observer
        param_count = param_count + 1
      end
    end
  end
  
  print("AUTOMATE_LAST_TOUCHED: Added observers to " .. param_count .. " automatable parameters")
  return param_count > 0
end

--------------------------------------------------------------------------------
-- Automation Creation
--------------------------------------------------------------------------------

-- Create automation for the last touched parameter
function PakettiAutomateLastTouchedCreate()
  if not last_touched_parameter then
    renoise.app():show_status("No parameter was touched - nothing to automate")
    print("AUTOMATE_LAST_TOUCHED: No parameter was touched")
    return
  end
  
  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song available")
    return
  end
  
  local param = last_touched_parameter
  local param_name = param.name
  
  -- Handle instrument plugin vs track DSP
  if is_instrument_plugin then
    -- For instrument plugins, we need to guide user to use Instr. Automation device
    -- Check if there's an Instr. Automation device on the current track
    local track = song.tracks[last_touched_track_index or song.selected_track_index]
    local instr_auto_device = nil
    local instr_auto_device_index = nil
    
    if track then
      for i, dev in ipairs(track.devices) do
        if dev.device_path == "Audio/Effects/Native/*Instr. Automation" then
          instr_auto_device = dev
          instr_auto_device_index = i
          break
        end
      end
    end
    
    if instr_auto_device then
      -- Found Instr. Automation device - select it and show automation view
      song.selected_device_index = instr_auto_device_index
      
      -- Open automation view
      pcall(function()
        renoise.app().window.lower_frame_is_visible = true
        renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
      end)
      
      renoise.app():show_status("Instrument plugin: Use Instr. Automation device to automate '" .. param_name .. "'")
      print("AUTOMATE_LAST_TOUCHED: Instrument plugin parameter '" .. param_name .. "' - directed to Instr. Automation device")
    else
      -- No Instr. Automation device found
      renoise.app():show_status("Add '*Instr. Automation' device to automate instrument plugin parameter '" .. param_name .. "'")
      print("AUTOMATE_LAST_TOUCHED: No Instr. Automation device found for instrument plugin parameter")
    end
    return
  end
  
  -- For track DSP devices, create automation directly
  local track_index = last_touched_track_index or song.selected_track_index
  local current_pattern = song.selected_pattern_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  
  -- Find or create automation for the parameter
  local automation = pattern_track:find_automation(param)
  
  if not automation then
    automation = pattern_track:create_automation(param)
    print("AUTOMATE_LAST_TOUCHED: Created new automation envelope for '" .. param_name .. "'")
  else
    print("AUTOMATE_LAST_TOUCHED: Found existing automation envelope for '" .. param_name .. "'")
  end
  
  if automation then
    -- Write current value at current line position
    local current_line = song.selected_line_index
    local value = param.value
    local value_min = param.value_min
    local value_max = param.value_max
    
    -- Normalize value to 0.0-1.0 range for automation
    local normalized_value = (value - value_min) / (value_max - value_min)
    normalized_value = math.max(0.0, math.min(1.0, normalized_value))
    
    -- Remove existing point at this time if it exists
    if automation:has_point_at(current_line) then
      automation:remove_point_at(current_line)
    end
    
    -- Add new automation point
    automation:add_point_at(current_line, normalized_value)
    print("AUTOMATE_LAST_TOUCHED: Added automation point at line " .. current_line .. " with value " .. normalized_value)
    
    -- Open automation view and select this parameter
    pcall(function()
      renoise.app().window.lower_frame_is_visible = true
      renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
      
      -- Select the automation parameter to show it
      song.selected_automation_parameter = param
    end)
    
    renoise.app():show_status("Created automation for: " .. param_name .. " at line " .. current_line)
  else
    renoise.app():show_status("Failed to create automation for: " .. param_name)
    print("AUTOMATE_LAST_TOUCHED: Failed to create automation envelope")
  end
end

--------------------------------------------------------------------------------
-- Main Entry Point
--------------------------------------------------------------------------------

-- Main function - start watching for parameter changes
function PakettiAutomateLastTouchedStart()
  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song available")
    return
  end
  
  -- If already watching, cleanup and stop
  if watching_active then
    print("AUTOMATE_LAST_TOUCHED: Already watching - stopping")
    PakettiAutomateLastTouchedCleanup()
    renoise.app():show_status("Stopped watching for parameter changes")
    return
  end
  
  -- Cleanup any previous state
  PakettiAutomateLastTouchedCleanup()
  
  -- Try to find a device to watch
  local device_to_watch = nil
  local track_index = song.selected_track_index
  local is_plugin_instrument = false
  local device_name = ""
  
  -- First, check if there's a selected track device (DSP)
  if song.selected_device then
    device_to_watch = song.selected_device
    device_name = device_to_watch.display_name or device_to_watch.name or "Unknown Device"
    print("AUTOMATE_LAST_TOUCHED: Found selected track device: " .. device_name)
  end
  
  -- If no track device, check for plugin instrument
  if not device_to_watch then
    local instrument = song.selected_instrument
    if instrument and instrument.plugin_properties and instrument.plugin_properties.plugin_loaded then
      device_to_watch = instrument.plugin_properties.plugin_device
      is_plugin_instrument = true
      device_name = instrument.name or "Plugin Instrument"
      print("AUTOMATE_LAST_TOUCHED: Found plugin instrument: " .. device_name)
    end
  end
  
  -- No device found
  if not device_to_watch then
    renoise.app():show_status("No device selected - select a track device or plugin instrument first")
    print("AUTOMATE_LAST_TOUCHED: No device found to watch")
    return
  end
  
  -- Check if device has automatable parameters
  local automatable_count = 0
  for i = 1, #device_to_watch.parameters do
    if device_to_watch.parameters[i].is_automatable then
      automatable_count = automatable_count + 1
    end
  end
  
  if automatable_count == 0 then
    renoise.app():show_status("Device '" .. device_name .. "' has no automatable parameters")
    print("AUTOMATE_LAST_TOUCHED: Device has no automatable parameters")
    return
  end
  
  -- Setup watching
  watching_active = true
  
  local success = PakettiAutomateLastTouchedSetupWatching(device_to_watch, track_index, is_plugin_instrument)
  
  if success then
    -- Start the initial inactivity timer
    PakettiAutomateLastTouchedResetTimer()
    
    local type_str = is_plugin_instrument and "instrument" or "device"
    renoise.app():show_status("Watching " .. type_str .. " '" .. device_name .. "' (" .. automatable_count .. " params) - touch a parameter within " .. watching_timeout_seconds .. "s...")
    print("AUTOMATE_LAST_TOUCHED: Started watching " .. type_str .. " '" .. device_name .. "' with " .. automatable_count .. " automatable parameters")
  else
    watching_active = false
    renoise.app():show_status("Failed to setup parameter watching for '" .. device_name .. "'")
    print("AUTOMATE_LAST_TOUCHED: Failed to setup parameter watching")
  end
end

--------------------------------------------------------------------------------
-- Song Change Handler
--------------------------------------------------------------------------------

-- Cleanup when song changes
function PakettiAutomateLastTouchedOnSongChange()
  if watching_active then
    print("AUTOMATE_LAST_TOUCHED: Song changed - cleaning up")
    PakettiAutomateLastTouchedCleanup()
  end
end

-- Register song change observer
if not renoise.tool().app_new_document_observable:has_notifier(PakettiAutomateLastTouchedOnSongChange) then
  renoise.tool().app_new_document_observable:add_notifier(PakettiAutomateLastTouchedOnSongChange)
end

--------------------------------------------------------------------------------
-- Keybindings and Menu Entries
--------------------------------------------------------------------------------

renoise.tool():add_keybinding{
  name = "Global:Paketti:Automate Last Touched Parameter",
  invoke = PakettiAutomateLastTouchedStart
}

renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Automate Last Touched Parameter",
  invoke = PakettiAutomateLastTouchedStart
}

renoise.tool():add_keybinding{
  name = "Mixer:Paketti:Automate Last Touched Parameter",
  invoke = PakettiAutomateLastTouchedStart
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Automate Last Touched Parameter...",
  invoke = PakettiAutomateLastTouchedStart
}

renoise.tool():add_menu_entry{
  name = "DSP Device:Paketti:Automate Last Touched Parameter",
  invoke = PakettiAutomateLastTouchedStart
}

renoise.tool():add_menu_entry{
  name = "Mixer:Paketti Gadgets:Automate Last Touched Parameter",
  invoke = PakettiAutomateLastTouchedStart
}

--------------------------------------------------------------------------------
-- MIDI Mappings
--------------------------------------------------------------------------------

renoise.tool():add_midi_mapping{
  name = "Paketti:Automate Last Touched Parameter [Trigger]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiAutomateLastTouchedStart()
    end
  end
}

print("PakettiAutomateLastTouched.lua loaded")

