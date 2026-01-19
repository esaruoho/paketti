-- PakettiAutomateLastTouched.lua
-- FL Studio-style "Automate Last Touched Parameter" functionality
-- Configurable watching modes and device scopes for user-controlled performance impact

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local WATCHING_MODE_SHORTCUT_FIRST = 1  -- Press shortcut to start watching (default)
local WATCHING_MODE_TRACK_WATCHING = 2  -- Always watching current track's devices
local WATCHING_MODE_ALWAYS_WATCHING = 3 -- Always watching all devices in scope

local DEVICE_SCOPE_SELECTED = 1         -- Only watch selected device (default)
local DEVICE_SCOPE_ALL_TRACK = 2        -- Watch all devices on current track
local DEVICE_SCOPE_ALL_SONG = 3         -- Watch every device in entire song

--------------------------------------------------------------------------------
-- Global State Variables - Shortcut First Mode (temporary watching)
--------------------------------------------------------------------------------

local watching_device = nil
local watching_track_index = nil
local watching_active = false
local parameter_observers = {}
local is_watching_instrument_plugin = false
local continuous_mode_active = false

--------------------------------------------------------------------------------
-- Global State Variables - Persistent Watching Modes
--------------------------------------------------------------------------------

local persistent_watching_active = false
local global_last_touched_parameter = nil
local global_last_touched_device = nil
local global_last_touched_track_index = nil
local global_last_touched_is_instrument = false
local persistent_parameter_observers = {}
local track_change_observer = nil
local device_list_observers = {}  -- Track -> observer for devices_observable
local persistent_setup_timer = nil  -- Timer function reference for persistent watching setup

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

-- Cleanup temporary watching (Shortcut First mode)
function PakettiAutomateLastTouchedCleanupTemporary()
  print("AUTOMATE_LAST_TOUCHED: Temporary cleanup started")
  
  for parameter, observer in pairs(parameter_observers) do
    pcall(function()
      if parameter and parameter.value_observable and parameter.value_observable:has_notifier(observer) then
        parameter.value_observable:remove_notifier(observer)
      end
    end)
  end
  parameter_observers = {}
  
  watching_device = nil
  watching_track_index = nil
  watching_active = false
  is_watching_instrument_plugin = false
  continuous_mode_active = false
  
  print("AUTOMATE_LAST_TOUCHED: Temporary cleanup complete")
end

-- Cleanup persistent watching (Track/Always Watching modes)
function PakettiAutomateLastTouchedCleanupPersistent()
  print("AUTOMATE_LAST_TOUCHED: Persistent cleanup started")
  
  -- Remove all persistent parameter observers
  for parameter, observer in pairs(persistent_parameter_observers) do
    pcall(function()
      if parameter and parameter.value_observable and parameter.value_observable:has_notifier(observer) then
        parameter.value_observable:remove_notifier(observer)
      end
    end)
  end
  persistent_parameter_observers = {}
  
  -- Remove track change observer
  if track_change_observer then
    pcall(function()
      local song = renoise.song()
      if song and song.selected_track_index_observable:has_notifier(track_change_observer) then
        song.selected_track_index_observable:remove_notifier(track_change_observer)
      end
    end)
    track_change_observer = nil
  end
  
  -- Remove device list observers
  for track, observer in pairs(device_list_observers) do
    pcall(function()
      if track and track.devices_observable and track.devices_observable:has_notifier(observer) then
        track.devices_observable:remove_notifier(observer)
      end
    end)
  end
  device_list_observers = {}
  
  -- Reset state
  persistent_watching_active = false
  global_last_touched_parameter = nil
  global_last_touched_device = nil
  global_last_touched_track_index = nil
  global_last_touched_is_instrument = false
  
  print("AUTOMATE_LAST_TOUCHED: Persistent cleanup complete")
end

-- Full cleanup
function PakettiAutomateLastTouchedCleanup()
  PakettiAutomateLastTouchedCleanupTemporary()
  PakettiAutomateLastTouchedCleanupPersistent()
end

--------------------------------------------------------------------------------
-- Create Automation for a Single Parameter
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
    else
      renoise.app():show_status("Add '*Instr. Automation' device to automate '" .. param_name .. "'")
    end
    return false
  end
  
  -- For track DSP devices
  local current_pattern = song.selected_pattern_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  
  local automation = pattern_track:find_automation(param)
  
  if not automation then
    automation = pattern_track:create_automation(param)
    print("AUTOMATE_LAST_TOUCHED: Created new automation for '" .. param_name .. "'")
  end
  
  if automation then
    local current_line = song.selected_line_index
    local value = param.value
    local normalized_value = (value - param.value_min) / (param.value_max - param.value_min)
    normalized_value = math.max(0.0, math.min(1.0, normalized_value))
    
    if automation:has_point_at(current_line) then
      automation:remove_point_at(current_line)
    end
    
    automation:add_point_at(current_line, normalized_value)
    
    pcall(function()
      renoise.app().window.lower_frame_is_visible = true
      renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
      song.selected_automation_parameter = param
    end)
    
    renoise.app():show_status("Created automation for: " .. param_name)
    return true
  end
  
  return false
end

--------------------------------------------------------------------------------
-- Write continuous automation point
--------------------------------------------------------------------------------

function PakettiAutomateLastTouchedWriteContinuousPoint(param, track_index)
  local song = renoise.song()
  if not song or not song.transport.edit_mode then return end
  
  local current_pattern = song.selected_pattern_index
  local pattern_track = song:pattern(current_pattern):track(track_index)
  
  local automation = pattern_track:find_automation(param)
  if not automation then
    automation = pattern_track:create_automation(param)
  end
  
  if automation then
    local line_pos = PakettiAutomateLastTouchedGetFractionalLinePos() or song.selected_line_index
    local normalized_value = (param.value - param.value_min) / (param.value_max - param.value_min)
    normalized_value = math.max(0.0, math.min(1.0, normalized_value))
    automation:add_point_at(line_pos, normalized_value)
  end
end

--------------------------------------------------------------------------------
-- Parameter Observer Callbacks
--------------------------------------------------------------------------------

-- For Shortcut First mode - instant automation creation
function PakettiAutomateLastTouchedOnParameterTouched(param, device, track_index, is_plugin_instrument)
  if not watching_active then return end
  
  print("AUTOMATE_LAST_TOUCHED: Parameter touched: " .. param.name)
  
  local continuous_recording = PakettiAutomateLastTouchedGetPref("ContinuousRecording", false)
  
  if continuous_recording then
    if not continuous_mode_active then
      continuous_mode_active = true
      PakettiAutomateLastTouchedCreateForParameter(param, device, track_index, is_plugin_instrument)
      renoise.app():show_status("Continuous recording started for: " .. param.name .. " - press shortcut to stop")
    else
      PakettiAutomateLastTouchedWriteContinuousPoint(param, track_index)
    end
  else
    PakettiAutomateLastTouchedCreateForParameter(param, device, track_index, is_plugin_instrument)
    PakettiAutomateLastTouchedCleanupTemporary()
  end
end

-- For Persistent modes - just store the last touched parameter
function PakettiAutomateLastTouchedOnPersistentParameterTouched(param, device, track_index, is_plugin_instrument)
  if not persistent_watching_active then return end
  
  global_last_touched_parameter = param
  global_last_touched_device = device
  global_last_touched_track_index = track_index
  global_last_touched_is_instrument = is_plugin_instrument
  
  print("AUTOMATE_LAST_TOUCHED: Stored last touched: " .. param.name)
  renoise.app():show_status("Last touched: " .. param.name .. " - press shortcut to automate")
end

--------------------------------------------------------------------------------
-- Setup Watching for Devices
--------------------------------------------------------------------------------

-- Add observers to a single device
function PakettiAutomateLastTouchedAddDeviceObservers(device, track_index, is_plugin_instrument, observer_table, callback)
  if not device then return 0 end
  
  local param_count = 0
  
  for i = 1, #device.parameters do
    local param = device.parameters[i]
    
    if param.is_automatable then
      local observer = function()
        callback(param, device, track_index, is_plugin_instrument)
      end
      
      if not param.value_observable:has_notifier(observer) then
        param.value_observable:add_notifier(observer)
        observer_table[param] = observer
        param_count = param_count + 1
      end
    end
  end
  
  return param_count
end

-- Setup temporary watching (Shortcut First mode)
function PakettiAutomateLastTouchedSetupTemporaryWatching(device, track_index, is_plugin_instrument)
  return PakettiAutomateLastTouchedAddDeviceObservers(
    device, track_index, is_plugin_instrument,
    parameter_observers, PakettiAutomateLastTouchedOnParameterTouched
  )
end

-- Get devices to watch based on scope
function PakettiAutomateLastTouchedGetDevicesToWatch()
  local song = renoise.song()
  if not song then return {} end
  
  local scope = PakettiAutomateLastTouchedGetPref("DeviceScope", DEVICE_SCOPE_SELECTED)
  local devices = {}
  
  if scope == DEVICE_SCOPE_SELECTED then
    -- Selected device only
    if song.selected_device then
      table.insert(devices, {
        device = song.selected_device,
        track_index = song.selected_track_index,
        is_instrument = false
      })
    end
    -- Also check for plugin instrument
    local instrument = song.selected_instrument
    if instrument and instrument.plugin_properties and instrument.plugin_properties.plugin_loaded then
      table.insert(devices, {
        device = instrument.plugin_properties.plugin_device,
        track_index = song.selected_track_index,
        is_instrument = true
      })
    end
    
  elseif scope == DEVICE_SCOPE_ALL_TRACK then
    -- All devices on current track
    local track_index = song.selected_track_index
    local track = song.tracks[track_index]
    if track then
      for i, device in ipairs(track.devices) do
        if i > 1 then -- Skip track mixer (device 1)
          table.insert(devices, {
            device = device,
            track_index = track_index,
            is_instrument = false
          })
        end
      end
    end
    -- Also check for plugin instrument
    local instrument = song.selected_instrument
    if instrument and instrument.plugin_properties and instrument.plugin_properties.plugin_loaded then
      table.insert(devices, {
        device = instrument.plugin_properties.plugin_device,
        track_index = track_index,
        is_instrument = true
      })
    end
    
  elseif scope == DEVICE_SCOPE_ALL_SONG then
    -- All devices in entire song
    for track_index, track in ipairs(song.tracks) do
      for i, device in ipairs(track.devices) do
        if i > 1 then -- Skip track mixer
          table.insert(devices, {
            device = device,
            track_index = track_index,
            is_instrument = false
          })
        end
      end
    end
    -- All plugin instruments
    for i, instrument in ipairs(song.instruments) do
      if instrument.plugin_properties and instrument.plugin_properties.plugin_loaded then
        table.insert(devices, {
          device = instrument.plugin_properties.plugin_device,
          track_index = song.selected_track_index,
          is_instrument = true
        })
      end
    end
  end
  
  return devices
end

--------------------------------------------------------------------------------
-- Persistent Watching Setup
--------------------------------------------------------------------------------

-- Refresh persistent watching (called on track change, device add/remove)
function PakettiAutomateLastTouchedRefreshPersistentWatching()
  if not persistent_watching_active then return end
  
  print("AUTOMATE_LAST_TOUCHED: Refreshing persistent watching")
  
  -- Remove old parameter observers
  for parameter, observer in pairs(persistent_parameter_observers) do
    pcall(function()
      if parameter and parameter.value_observable and parameter.value_observable:has_notifier(observer) then
        parameter.value_observable:remove_notifier(observer)
      end
    end)
  end
  persistent_parameter_observers = {}
  
  -- Get devices to watch based on scope
  local devices = PakettiAutomateLastTouchedGetDevicesToWatch()
  local total_params = 0
  
  for _, entry in ipairs(devices) do
    local count = PakettiAutomateLastTouchedAddDeviceObservers(
      entry.device, entry.track_index, entry.is_instrument,
      persistent_parameter_observers, PakettiAutomateLastTouchedOnPersistentParameterTouched
    )
    total_params = total_params + count
  end
  
  print("AUTOMATE_LAST_TOUCHED: Persistent watching " .. #devices .. " devices, " .. total_params .. " parameters")
end

-- Setup device list observer for a track
function PakettiAutomateLastTouchedSetupDeviceListObserver(track, track_index)
  if device_list_observers[track] then return end
  
  local observer = function()
    print("AUTOMATE_LAST_TOUCHED: Device list changed on track " .. track_index)
    PakettiAutomateLastTouchedRefreshPersistentWatching()
  end
  
  if not track.devices_observable:has_notifier(observer) then
    track.devices_observable:add_notifier(observer)
    device_list_observers[track] = observer
  end
end

-- Setup persistent watching infrastructure
function PakettiAutomateLastTouchedSetupPersistentWatching()
  local song = renoise.song()
  if not song then return end
  
  local watching_mode = PakettiAutomateLastTouchedGetPref("WatchingMode", WATCHING_MODE_SHORTCUT_FIRST)
  
  if watching_mode == WATCHING_MODE_SHORTCUT_FIRST then
    return -- No persistent watching needed
  end
  
  print("AUTOMATE_LAST_TOUCHED: Setting up persistent watching (mode=" .. watching_mode .. ")")
  
  -- Cleanup any existing persistent watching
  PakettiAutomateLastTouchedCleanupPersistent()
  
  persistent_watching_active = true
  
  -- Setup track change observer (for Track Watching mode)
  if watching_mode == WATCHING_MODE_TRACK_WATCHING then
    track_change_observer = function()
      print("AUTOMATE_LAST_TOUCHED: Track changed")
      PakettiAutomateLastTouchedRefreshPersistentWatching()
    end
    
    if not song.selected_track_index_observable:has_notifier(track_change_observer) then
      song.selected_track_index_observable:add_notifier(track_change_observer)
    end
  end
  
  -- Setup device list observers
  local scope = PakettiAutomateLastTouchedGetPref("DeviceScope", DEVICE_SCOPE_SELECTED)
  
  if scope == DEVICE_SCOPE_ALL_TRACK then
    -- Only current track
    local track = song.tracks[song.selected_track_index]
    if track then
      PakettiAutomateLastTouchedSetupDeviceListObserver(track, song.selected_track_index)
    end
  elseif scope == DEVICE_SCOPE_ALL_SONG then
    -- All tracks
    for track_index, track in ipairs(song.tracks) do
      PakettiAutomateLastTouchedSetupDeviceListObserver(track, track_index)
    end
  end
  
  -- Initial setup of parameter observers
  PakettiAutomateLastTouchedRefreshPersistentWatching()
  
  local scope_names = {"Selected Device", "All Track Devices", "All Song Devices"}
  local mode_names = {"Shortcut First", "Track Watching", "Always Watching"}
  renoise.app():show_status("Persistent watching active: " .. mode_names[watching_mode] .. " + " .. scope_names[scope])
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
  
  local watching_mode = PakettiAutomateLastTouchedGetPref("WatchingMode", WATCHING_MODE_SHORTCUT_FIRST)
  
  -- For persistent modes (2 and 3): check if we have a stored parameter
  if watching_mode == WATCHING_MODE_TRACK_WATCHING or watching_mode == WATCHING_MODE_ALWAYS_WATCHING then
    
    -- If persistent watching isn't active, set it up
    if not persistent_watching_active then
      PakettiAutomateLastTouchedSetupPersistentWatching()
      return
    end
    
    -- Check if we have a last touched parameter
    if global_last_touched_parameter then
      -- Create automation immediately
      PakettiAutomateLastTouchedCreateForParameter(
        global_last_touched_parameter,
        global_last_touched_device,
        global_last_touched_track_index,
        global_last_touched_is_instrument
      )
      -- Clear the stored parameter
      global_last_touched_parameter = nil
      global_last_touched_device = nil
      global_last_touched_track_index = nil
      global_last_touched_is_instrument = false
    else
      renoise.app():show_status("Touch a parameter first, then press shortcut to automate")
    end
    return
  end
  
  -- Mode 1 (Shortcut First): Original behavior
  
  -- If already watching, cleanup and stop
  if watching_active then
    PakettiAutomateLastTouchedCleanupTemporary()
    renoise.app():show_status("Stopped watching for parameter changes")
    return
  end
  
  PakettiAutomateLastTouchedCleanupTemporary()
  
  -- Get devices to watch based on scope
  local scope = PakettiAutomateLastTouchedGetPref("DeviceScope", DEVICE_SCOPE_SELECTED)
  local devices = PakettiAutomateLastTouchedGetDevicesToWatch()
  
  if #devices == 0 then
    renoise.app():show_status("No device selected - select a track device or plugin instrument first")
    return
  end
  
  -- Auto-open external editor if preference is enabled
  local auto_open_editor = PakettiAutomateLastTouchedGetPref("AutoOpenExternalEditor", true)
  if auto_open_editor then
    for _, entry in ipairs(devices) do
      if entry.device.external_editor_available then
        entry.device.external_editor_visible = true
      end
    end
  end
  
  watching_active = true
  watching_track_index = song.selected_track_index
  
  -- Setup watching for all devices
  local total_params = 0
  for _, entry in ipairs(devices) do
    local count = PakettiAutomateLastTouchedSetupTemporaryWatching(entry.device, entry.track_index, entry.is_instrument)
    total_params = total_params + count
  end
  
  if total_params > 0 then
    local scope_names = {"Selected Device", "All Track Devices", "All Song Devices"}
    local continuous = PakettiAutomateLastTouchedGetPref("ContinuousRecording", false)
    local mode_str = continuous and " [CONTINUOUS]" or ""
    
    renoise.app():show_status("Watching " .. #devices .. " device(s), " .. total_params .. " params (" .. scope_names[scope] .. ")" .. mode_str .. " - touch a parameter...")
  else
    watching_active = false
    renoise.app():show_status("No automatable parameters found")
  end
end

--------------------------------------------------------------------------------
-- Song Change Handler
--------------------------------------------------------------------------------

function PakettiAutomateLastTouchedOnSongChange()
  print("AUTOMATE_LAST_TOUCHED: Song changed - cleaning up")
  PakettiAutomateLastTouchedCleanup()
  
  -- Re-setup persistent watching if mode requires it
  local watching_mode = PakettiAutomateLastTouchedGetPref("WatchingMode", WATCHING_MODE_SHORTCUT_FIRST)
  if watching_mode == WATCHING_MODE_TRACK_WATCHING or watching_mode == WATCHING_MODE_ALWAYS_WATCHING then
    -- Remove existing timer if it exists
    if persistent_setup_timer and renoise.tool():has_timer(persistent_setup_timer) then
      renoise.tool():remove_timer(persistent_setup_timer)
    end
    
    -- Delay setup to ensure song is fully loaded
    persistent_setup_timer = function()
      if persistent_setup_timer and renoise.tool():has_timer(persistent_setup_timer) then
        renoise.tool():remove_timer(persistent_setup_timer)
      end
      persistent_setup_timer = nil
      PakettiAutomateLastTouchedSetupPersistentWatching()
    end
    
    renoise.tool():add_timer(persistent_setup_timer, 100)
  end
end

if not renoise.tool().app_new_document_observable:has_notifier(PakettiAutomateLastTouchedOnSongChange) then
  renoise.tool().app_new_document_observable:add_notifier(PakettiAutomateLastTouchedOnSongChange)
end

--------------------------------------------------------------------------------
-- Initialize Persistent Watching on Tool Load
--------------------------------------------------------------------------------

function PakettiAutomateLastTouchedInitialize()
  local watching_mode = PakettiAutomateLastTouchedGetPref("WatchingMode", WATCHING_MODE_SHORTCUT_FIRST)
  
  if watching_mode == WATCHING_MODE_TRACK_WATCHING or watching_mode == WATCHING_MODE_ALWAYS_WATCHING then
    print("AUTOMATE_LAST_TOUCHED: Initializing persistent watching on tool load")
    
    -- Remove existing timer if it exists
    if persistent_setup_timer and renoise.tool():has_timer(persistent_setup_timer) then
      renoise.tool():remove_timer(persistent_setup_timer)
    end
    
    -- Delay to ensure song is loaded
    persistent_setup_timer = function()
      if persistent_setup_timer and renoise.tool():has_timer(persistent_setup_timer) then
        renoise.tool():remove_timer(persistent_setup_timer)
      end
      persistent_setup_timer = nil
      PakettiAutomateLastTouchedSetupPersistentWatching()
    end
    
    renoise.tool():add_timer(persistent_setup_timer, 500)
  end
end

-- Call initialize (will only setup persistent watching if mode requires it)
PakettiAutomateLastTouchedInitialize()

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
