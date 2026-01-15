-- PakettiAutomateLastTouched.lua
-- FL Studio-style "Automate Last Touched Parameter" functionality
-- Press shortcut, touch ANY parameter, automation is INSTANTLY created and automation view opens

--------------------------------------------------------------------------------
-- Global State Variables
--------------------------------------------------------------------------------

local watching_device = nil             -- The device being watched
local watching_track_index = nil        -- Track index where the device is
local watching_active = false           -- Is watching currently active
local parameter_observers = {}          -- Table: parameter -> observer function
local is_watching_instrument_plugin = false  -- Flag to track if watching instrument plugin
local continuous_mode_active = false    -- For continuous recording: stay watching after first touch

--------------------------------------------------------------------------------
-- Helper: Get preference value with fallback
--------------------------------------------------------------------------------

function PakettiAutomateLastTouchedGetPref(key, default_value)
  local success, result = pcall(function()
    if preferences and preferences.pakettiAutomateLastTouched and preferences.pakettiAutomateLastTouched[key] then
      return preferences.pakettiAutomateLastTouched[key].value
    end
    return default_value
  end)
  
  if success then
    return result
  end
  return default_value
end

--------------------------------------------------------------------------------
-- Helper: Get fractional line position for continuous recording
--------------------------------------------------------------------------------

function PakettiAutomateLastTouchedGetFractionalLinePos()
  local song = renoise.song()
  if not song then return nil end
  
  local beats, line
  if song.transport.playing then
    beats = song.transport.playback_pos_beats - math.floor(song.transport.playback_pos_beats)
    line = song.transport.playback_pos.line
  else
    beats = song.transport.edit_pos_beats - math.floor(song.transport.edit_pos_beats)
    line = song.transport.edit_pos.line
  end
  
  local lpb = song.transport.lpb
  local beats_scaled = beats * lpb
  local line_in_beat = math.floor(beats_scaled)
  local fraction = 0
  if (line_in_beat + 1) - line_in_beat ~= 0 then
    fraction = (beats_scaled - line_in_beat) / ((line_in_beat + 1) - line_in_beat)
  end
  
  local line_fract = line + fraction
  return line_fract
end

--------------------------------------------------------------------------------
-- Cleanup Functions
--------------------------------------------------------------------------------

function PakettiAutomateLastTouchedCleanup()
  print("AUTOMATE_LAST_TOUCHED: Cleanup started")
  
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
  watching_device = nil
  watching_track_index = nil
  watching_active = false
  is_watching_instrument_plugin = false
  continuous_mode_active = false
  
  print("AUTOMATE_LAST_TOUCHED: Cleanup complete")
end

--------------------------------------------------------------------------------
-- Create Automation for a Single Parameter (instant)
--------------------------------------------------------------------------------

function PakettiAutomateLastTouchedCreateForParameter(param, device, track_index, is_plugin_instrument)
  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song available")
    return false
  end
  
  local param_name = param.name
  
  -- Handle instrument plugin vs track DSP
  if is_plugin_instrument then
    -- For instrument plugins, guide user to use Instr. Automation device
    local track = song.tracks[track_index]
    local instr_auto_device = nil
    local instr_auto_device_index = nil
    
    if track then
      for j, dev in ipairs(track.devices) do
        if dev.device_path == "Audio/Effects/Native/*Instr. Automation" then
          instr_auto_device = dev
          instr_auto_device_index = j
          break
        end
      end
    end
    
    if instr_auto_device then
      song.selected_device_index = instr_auto_device_index
      pcall(function()
        renoise.app().window.lower_frame_is_visible = true
        renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
      end)
      renoise.app():show_status("Instrument plugin: Use Instr. Automation device to automate '" .. param_name .. "'")
      print("AUTOMATE_LAST_TOUCHED: Instrument plugin - directed to Instr. Automation device")
    else
      renoise.app():show_status("Add '*Instr. Automation' device to automate '" .. param_name .. "'")
      print("AUTOMATE_LAST_TOUCHED: No Instr. Automation device found")
    end
    return false
  end
  
  -- For track DSP devices, create automation directly
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
    
    -- Open automation view and select this parameter
    pcall(function()
      renoise.app().window.lower_frame_is_visible = true
      renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
      song.selected_automation_parameter = param
    end)
    
    renoise.app():show_status("Created automation for: " .. param_name)
    print("AUTOMATE_LAST_TOUCHED: Created automation for '" .. param_name .. "' at line " .. current_line)
    return true
  end
  
  return false
end

--------------------------------------------------------------------------------
-- Write automation point for continuous recording
--------------------------------------------------------------------------------

function PakettiAutomateLastTouchedWriteContinuousPoint(param, track_index)
  local song = renoise.song()
  if not song then return end
  
  -- Must be in edit mode for continuous recording to write
  if not song.transport.edit_mode then
    return
  end
  
  local current_pattern = song.selected_pattern_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  
  local automation = pattern_track:find_automation(param)
  if not automation then
    automation = pattern_track:create_automation(param)
  end
  
  if automation then
    local line_pos = PakettiAutomateLastTouchedGetFractionalLinePos()
    if not line_pos then
      line_pos = song.selected_line_index
    end
    
    local value = param.value
    local normalized_value = (value - param.value_min) / (param.value_max - param.value_min)
    normalized_value = math.max(0.0, math.min(1.0, normalized_value))
    
    automation:add_point_at(line_pos, normalized_value)
  end
end

--------------------------------------------------------------------------------
-- Parameter Observer Callback - INSTANT automation creation
--------------------------------------------------------------------------------

function PakettiAutomateLastTouchedOnParameterTouched(param, device, track_index, is_plugin_instrument)
  if not watching_active then
    return
  end
  
  print("AUTOMATE_LAST_TOUCHED: Parameter touched: " .. param.name)
  
  local continuous_recording = PakettiAutomateLastTouchedGetPref("ContinuousRecording", false)
  
  if continuous_recording then
    -- Continuous recording mode
    if not continuous_mode_active then
      -- First touch: create automation + open view, then stay watching
      continuous_mode_active = true
      PakettiAutomateLastTouchedCreateForParameter(param, device, track_index, is_plugin_instrument)
      renoise.app():show_status("Continuous recording started for: " .. param.name .. " - press shortcut to stop")
      print("AUTOMATE_LAST_TOUCHED: Continuous mode started")
    else
      -- Subsequent touches: just write points
      PakettiAutomateLastTouchedWriteContinuousPoint(param, track_index)
    end
  else
    -- Normal mode: INSTANTLY create automation and cleanup
    PakettiAutomateLastTouchedCreateForParameter(param, device, track_index, is_plugin_instrument)
    PakettiAutomateLastTouchedCleanup()
  end
end

--------------------------------------------------------------------------------
-- Parameter Watching Setup
--------------------------------------------------------------------------------

function PakettiAutomateLastTouchedSetupWatching(device, track_index, is_plugin_instrument)
  if not device then
    print("AUTOMATE_LAST_TOUCHED: No device provided for watching")
    return false
  end
  
  local param_count = 0
  
  for i = 1, #device.parameters do
    local param = device.parameters[i]
    
    if param.is_automatable then
      local observer = function()
        PakettiAutomateLastTouchedOnParameterTouched(param, device, track_index, is_plugin_instrument)
      end
      
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
-- Main Entry Point
--------------------------------------------------------------------------------

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
  
  -- Auto-open external editor if preference is enabled
  local auto_open_editor = PakettiAutomateLastTouchedGetPref("AutoOpenExternalEditor", true)
  if auto_open_editor and device_to_watch.external_editor_available then
    device_to_watch.external_editor_visible = true
    print("AUTOMATE_LAST_TOUCHED: Auto-opened external editor for " .. device_name)
  end
  
  -- Store watching state
  watching_device = device_to_watch
  watching_track_index = track_index
  is_watching_instrument_plugin = is_plugin_instrument
  watching_active = true
  
  -- Setup watching
  local success = PakettiAutomateLastTouchedSetupWatching(device_to_watch, track_index, is_plugin_instrument)
  
  if success then
    local type_str = is_plugin_instrument and "instrument" or "device"
    local continuous_recording = PakettiAutomateLastTouchedGetPref("ContinuousRecording", false)
    local mode_str = continuous_recording and " [CONTINUOUS]" or ""
    
    renoise.app():show_status("Watching " .. type_str .. " '" .. device_name .. "' (" .. automatable_count .. " params)" .. mode_str .. " - touch a parameter...")
    print("AUTOMATE_LAST_TOUCHED: Started watching " .. type_str .. " '" .. device_name .. "'")
  else
    watching_active = false
    watching_device = nil
    watching_track_index = nil
    renoise.app():show_status("Failed to setup parameter watching for '" .. device_name .. "'")
    print("AUTOMATE_LAST_TOUCHED: Failed to setup parameter watching")
  end
end

--------------------------------------------------------------------------------
-- Song Change Handler
--------------------------------------------------------------------------------

function PakettiAutomateLastTouchedOnSongChange()
  if watching_active then
    print("AUTOMATE_LAST_TOUCHED: Song changed - cleaning up")
    PakettiAutomateLastTouchedCleanup()
  end
end

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
