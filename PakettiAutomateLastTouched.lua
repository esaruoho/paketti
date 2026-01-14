-- PakettiAutomateLastTouched.lua
-- FL Studio-style "Automate Last Touched Parameter" functionality
-- Touch any parameter, wait for timeout, automation gets created and automation view opens

--------------------------------------------------------------------------------
-- Global State Variables
--------------------------------------------------------------------------------

local touched_parameters = {}           -- Table of touched parameters: {param, device, track_index, is_plugin_instrument}
local watching_device = nil             -- The device being watched
local watching_track_index = nil        -- Track index where the device is
local watching_active = false           -- Is watching currently active
local inactivity_timer = nil            -- Timeout timer function
local parameter_observers = {}          -- Table: parameter -> observer function
local is_watching_instrument_plugin = false  -- Flag to track if watching instrument plugin
local edit_mode_observer = nil          -- Observer for edit mode changes (continuous recording)

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
-- Based on ffx GUIAutomationRecorder's approach
--------------------------------------------------------------------------------

function PakettiAutomateLastTouchedGetFractionalLinePos()
  local song = renoise.song()
  if not song then return nil end
  
  local beats, line
  if song.transport.playing then
    -- Use playback position when playing
    beats = song.transport.playback_pos_beats - math.floor(song.transport.playback_pos_beats)
    line = song.transport.playback_pos.line
  else
    -- Use edit position when stopped
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
  
  -- Remove edit mode observer if present
  if edit_mode_observer then
    pcall(function()
      local song = renoise.song()
      if song and song.transport.edit_mode_observable:has_notifier(edit_mode_observer) then
        song.transport.edit_mode_observable:remove_notifier(edit_mode_observer)
        print("AUTOMATE_LAST_TOUCHED: Removed edit mode observer")
      end
    end)
    edit_mode_observer = nil
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
  touched_parameters = {}
  watching_device = nil
  watching_track_index = nil
  watching_active = false
  is_watching_instrument_plugin = false
  
  print("AUTOMATE_LAST_TOUCHED: Cleanup complete")
end

--------------------------------------------------------------------------------
-- Timer Functions
--------------------------------------------------------------------------------

-- Reset/restart the inactivity timer
function PakettiAutomateLastTouchedResetTimer()
  -- Get timeout from preferences (default 3 seconds)
  local timeout_seconds = PakettiAutomateLastTouchedGetPref("TimeoutSeconds", 3)
  
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
    
    -- Create automation for touched parameters
    PakettiAutomateLastTouchedCreate()
    
    -- Check if quick rewatch is enabled
    local quick_rewatch = PakettiAutomateLastTouchedGetPref("QuickRewatch", false)
    
    if quick_rewatch and watching_device then
      -- Clear touched parameters but keep watching
      touched_parameters = {}
      PakettiAutomateLastTouchedResetTimer()
      renoise.app():show_status("Created automation - watching again for next parameter...")
      print("AUTOMATE_LAST_TOUCHED: Quick rewatch - continuing to watch")
    else
      -- Full cleanup
      PakettiAutomateLastTouchedCleanup()
    end
  end
  
  -- Add timer (timeout in milliseconds)
  renoise.tool():add_timer(inactivity_timer, timeout_seconds * 1000)
  print("AUTOMATE_LAST_TOUCHED: Timer reset - " .. timeout_seconds .. " seconds until automation creation")
end

--------------------------------------------------------------------------------
-- Continuous Recording: Write automation point immediately
--------------------------------------------------------------------------------

function PakettiAutomateLastTouchedWriteAutomationPoint(param, device, track_index)
  local song = renoise.song()
  if not song then return end
  
  -- Must be in edit mode for continuous recording
  if not song.transport.edit_mode then
    return
  end
  
  -- Get current pattern track
  local current_pattern = song.selected_pattern_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  
  -- Find or create automation for the parameter
  local automation = pattern_track:find_automation(param)
  
  if not automation then
    automation = pattern_track:create_automation(param)
  end
  
  if automation then
    -- Get fractional line position for precision
    local line_pos = PakettiAutomateLastTouchedGetFractionalLinePos()
    if not line_pos then
      line_pos = song.selected_line_index
    end
    
    -- Get current value and normalize to 0.0-1.0 range
    local value = param.value
    local value_min = param.value_min
    local value_max = param.value_max
    local normalized_value = (value - value_min) / (value_max - value_min)
    normalized_value = math.max(0.0, math.min(1.0, normalized_value))
    
    -- Add automation point at current position
    automation:add_point_at(line_pos, normalized_value)
    
    print("AUTOMATE_LAST_TOUCHED: Continuous recording - wrote point for '" .. param.name .. "' at " .. string.format("%.2f", line_pos) .. " = " .. string.format("%.3f", normalized_value))
  end
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
  
  -- Check if continuous recording is enabled
  local continuous_recording = PakettiAutomateLastTouchedGetPref("ContinuousRecording", false)
  
  if continuous_recording then
    -- Write automation point immediately if in edit mode
    local song = renoise.song()
    if song and song.transport.edit_mode then
      PakettiAutomateLastTouchedWriteAutomationPoint(param, device, track_index)
    end
  end
  
  -- Check if multi-parameter mode is enabled
  local multi_param = PakettiAutomateLastTouchedGetPref("MultiParameter", true)
  
  if multi_param then
    -- Multi-parameter mode: add to list if not already present
    local already_touched = false
    for i, entry in ipairs(touched_parameters) do
      if entry.param == param then
        already_touched = true
        break
      end
    end
    
    if not already_touched then
      table.insert(touched_parameters, {
        param = param,
        device = device,
        track_index = track_index,
        is_plugin_instrument = is_plugin_instrument
      })
      print("AUTOMATE_LAST_TOUCHED: Added parameter to list (total: " .. #touched_parameters .. ")")
    end
    
    -- Show status with count
    renoise.app():show_status("Touched " .. #touched_parameters .. " parameter(s) - waiting...")
  else
    -- Single parameter mode: replace list with just this one
    touched_parameters = {{
      param = param,
      device = device,
      track_index = track_index,
      is_plugin_instrument = is_plugin_instrument
    }}
    renoise.app():show_status("Last touched: " .. param.name .. " - waiting...")
  end
  
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
  
  -- Setup edit mode observer for continuous recording status feedback
  local continuous_recording = PakettiAutomateLastTouchedGetPref("ContinuousRecording", false)
  if continuous_recording then
    local song = renoise.song()
    if song then
      edit_mode_observer = function()
        if song.transport.edit_mode then
          renoise.app():show_status("Continuous recording: ACTIVE (edit mode on)")
        else
          renoise.app():show_status("Continuous recording: PAUSED (edit mode off)")
        end
      end
      
      if not song.transport.edit_mode_observable:has_notifier(edit_mode_observer) then
        song.transport.edit_mode_observable:add_notifier(edit_mode_observer)
      end
    end
  end
  
  print("AUTOMATE_LAST_TOUCHED: Added observers to " .. param_count .. " automatable parameters")
  return param_count > 0
end

--------------------------------------------------------------------------------
-- Automation Creation
--------------------------------------------------------------------------------

-- Create automation for all touched parameters
function PakettiAutomateLastTouchedCreate()
  if #touched_parameters == 0 then
    renoise.app():show_status("No parameter was touched - nothing to automate")
    print("AUTOMATE_LAST_TOUCHED: No parameters were touched")
    return
  end
  
  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song available")
    return
  end
  
  local created_count = 0
  local first_param = nil
  
  for i, entry in ipairs(touched_parameters) do
    local param = entry.param
    local device = entry.device
    local track_index = entry.track_index
    local is_plugin_instrument = entry.is_plugin_instrument
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
        -- Found Instr. Automation device
        if i == 1 then
          song.selected_device_index = instr_auto_device_index
        end
        print("AUTOMATE_LAST_TOUCHED: Instrument plugin parameter '" .. param_name .. "' - use Instr. Automation device")
      else
        renoise.app():show_status("Add '*Instr. Automation' device to automate instrument plugin parameters")
        print("AUTOMATE_LAST_TOUCHED: No Instr. Automation device found")
      end
    else
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
        created_count = created_count + 1
        
        -- Store first parameter for automation view selection
        if not first_param then
          first_param = param
        end
        
        print("AUTOMATE_LAST_TOUCHED: Added automation point at line " .. current_line .. " for '" .. param_name .. "'")
      end
    end
  end
  
  -- Open automation view and select first parameter
  if created_count > 0 and first_param then
    pcall(function()
      renoise.app().window.lower_frame_is_visible = true
      renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
      song.selected_automation_parameter = first_param
    end)
    
    renoise.app():show_status("Created automation for " .. created_count .. " parameter(s)")
  else
    renoise.app():show_status("Failed to create automation")
    print("AUTOMATE_LAST_TOUCHED: Failed to create automation envelopes")
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
    -- Start the initial inactivity timer
    PakettiAutomateLastTouchedResetTimer()
    
    local timeout_seconds = PakettiAutomateLastTouchedGetPref("TimeoutSeconds", 3)
    local continuous_recording = PakettiAutomateLastTouchedGetPref("ContinuousRecording", false)
    local multi_param = PakettiAutomateLastTouchedGetPref("MultiParameter", true)
    
    local type_str = is_plugin_instrument and "instrument" or "device"
    local mode_str = ""
    if continuous_recording then
      mode_str = " [CONTINUOUS]"
    end
    if multi_param then
      mode_str = mode_str .. " [MULTI]"
    end
    
    renoise.app():show_status("Watching " .. type_str .. " '" .. device_name .. "' (" .. automatable_count .. " params)" .. mode_str .. " - touch a parameter within " .. timeout_seconds .. "s...")
    print("AUTOMATE_LAST_TOUCHED: Started watching " .. type_str .. " '" .. device_name .. "' with " .. automatable_count .. " automatable parameters")
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
