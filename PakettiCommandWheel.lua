-- PakettiCommandWheel.lua
-- A unified scroll-wheel control interface for Renoise
-- Modes: MACRO, MIDI CC (*MIDI Control), PATTERN COMMAND, DEVICE

--------------------------------------------------------------------------------
-- DEBUG FLAG
--------------------------------------------------------------------------------
PakettiCommandWheelDebug = false

--------------------------------------------------------------------------------
-- MODE CONSTANTS
--------------------------------------------------------------------------------
PAKETTI_COMMAND_WHEEL_MODE_MACRO = 1
PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC = 2
PAKETTI_COMMAND_WHEEL_MODE_PATTERN_COMMAND = 3
PAKETTI_COMMAND_WHEEL_MODE_DEVICE = 4

-- Mode names for display
PAKETTI_COMMAND_WHEEL_MODE_NAMES = {
  [PAKETTI_COMMAND_WHEEL_MODE_MACRO] = "MACRO",
  [PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC] = "*MIDI Control",
  [PAKETTI_COMMAND_WHEEL_MODE_PATTERN_COMMAND] = "PATTERN CMD",
  [PAKETTI_COMMAND_WHEEL_MODE_DEVICE] = "DEVICE"
}

--------------------------------------------------------------------------------
-- PLACEMENT POLICIES (5 from original spec)
--------------------------------------------------------------------------------
PAKETTI_COMMAND_WHEEL_PLACEMENT_CURSOR = 1
PAKETTI_COMMAND_WHEEL_PLACEMENT_FIND_APPROPRIATE = 2
PAKETTI_COMMAND_WHEEL_PLACEMENT_FIND_COMPATIBLE = 3
PAKETTI_COMMAND_WHEEL_PLACEMENT_CREATE_NEW = 4
PAKETTI_COMMAND_WHEEL_PLACEMENT_NEVER_EXPAND = 5

PAKETTI_COMMAND_WHEEL_PLACEMENT_NAMES = {
  [PAKETTI_COMMAND_WHEEL_PLACEMENT_CURSOR] = "Overwrite Current",
  [PAKETTI_COMMAND_WHEEL_PLACEMENT_FIND_APPROPRIATE] = "Find Appropriate",
  [PAKETTI_COMMAND_WHEEL_PLACEMENT_FIND_COMPATIBLE] = "Find Compatible",
  [PAKETTI_COMMAND_WHEEL_PLACEMENT_CREATE_NEW] = "Create New Column",
  [PAKETTI_COMMAND_WHEEL_PLACEMENT_NEVER_EXPAND] = "Never Expand"
}

--------------------------------------------------------------------------------
-- STATE MANAGEMENT
--------------------------------------------------------------------------------
PakettiCommandWheelState = {
  mode = PAKETTI_COMMAND_WHEEL_MODE_MACRO,
  index = 1,
  value = 0,
  placement_policy = PAKETTI_COMMAND_WHEEL_PLACEMENT_CURSOR,
  write_on_scroll = false
}

-- Dialog and UI references
PakettiCommandWheelDialog = nil
PakettiCommandWheelViewBuilder = nil

-- Observable tracking
PakettiCommandWheelObservables = {
  device_observer = nil,
  instrument_observer = nil,
  track_observer = nil
}

--------------------------------------------------------------------------------
-- PHRASE-VALID EFFECTS (from PakettiPatternEditorCheatSheet)
--------------------------------------------------------------------------------
PAKETTI_COMMAND_WHEEL_PHRASE_VALID_EFFECTS = {
  ["0A"] = true, ["0U"] = true, ["0D"] = true, ["0G"] = true,
  ["0I"] = true, ["0O"] = true, ["0C"] = true, ["0Q"] = true,
  ["0M"] = true, ["0S"] = true, ["0B"] = true, ["0R"] = true,
  ["0Y"] = true, ["0V"] = true, ["0T"] = true, ["0N"] = true,
  ["0E"] = true
}

--------------------------------------------------------------------------------
-- PATTERN COMMANDS LIST
--------------------------------------------------------------------------------
PAKETTI_COMMAND_WHEEL_PATTERN_COMMANDS = {
  -- Note column sub-columns (special handling)
  {id = "VOLUME", name = "Volume", is_note_column = true, max_value = 128, phrase_valid = true},
  {id = "PANNING", name = "Panning", is_note_column = true, max_value = 128, phrase_valid = true},
  {id = "DELAY", name = "Delay", is_note_column = true, max_value = 255, phrase_valid = true},
  
  -- Sample/Note effects (work in phrases)
  {id = "0A", name = "Arpeggio", max_value = 255, phrase_valid = true},
  {id = "0U", name = "Slide Pitch Up", max_value = 255, phrase_valid = true},
  {id = "0D", name = "Slide Pitch Down", max_value = 255, phrase_valid = true},
  {id = "0G", name = "Glide to Note", max_value = 255, phrase_valid = true},
  {id = "0I", name = "Fade Volume In", max_value = 255, phrase_valid = true},
  {id = "0O", name = "Fade Volume Out", max_value = 255, phrase_valid = true},
  {id = "0C", name = "Cut Volume", max_value = 255, phrase_valid = true},
  {id = "0Q", name = "Delay Note", max_value = 255, phrase_valid = true},
  {id = "0M", name = "Set Note Volume", max_value = 255, phrase_valid = true},
  {id = "0S", name = "Trigger Slice/Offset", max_value = 255, phrase_valid = true},
  {id = "0B", name = "Play Backwards/Forwards", max_value = 255, phrase_valid = true},
  {id = "0R", name = "Retrigger", max_value = 255, phrase_valid = true},
  {id = "0Y", name = "Probability", max_value = 255, phrase_valid = true},
  {id = "0Z", name = "Trigger Phrase", max_value = 255, phrase_valid = false},
  {id = "0V", name = "Vibrato", max_value = 255, phrase_valid = true},
  {id = "0T", name = "Tremolo", max_value = 255, phrase_valid = true},
  {id = "0N", name = "Auto Pan", max_value = 255, phrase_valid = true},
  {id = "0E", name = "Set Envelope Position", max_value = 255, phrase_valid = true},
  
  -- Track effects (pattern-only)
  {id = "0L", name = "Track Volume", max_value = 255, phrase_valid = false},
  {id = "0P", name = "Track Pan", max_value = 255, phrase_valid = false},
  {id = "0W", name = "Track Surround Width", max_value = 255, phrase_valid = false},
  {id = "0J", name = "Track Routing", max_value = 255, phrase_valid = false},
  {id = "0X", name = "Stop Notes/FX", max_value = 255, phrase_valid = false},
  
  -- Global effects
  {id = "ZT", name = "Set Tempo", max_value = 255, phrase_valid = false},
  {id = "ZL", name = "Set LPB", max_value = 255, phrase_valid = false},
  {id = "ZK", name = "Set TPL", max_value = 16, phrase_valid = false},
  {id = "ZG", name = "Toggle Groove", max_value = 1, phrase_valid = false},
  {id = "ZB", name = "Pattern Break", max_value = 255, phrase_valid = false},
  {id = "ZD", name = "Pattern Delay", max_value = 255, phrase_valid = false}
}

--------------------------------------------------------------------------------
-- DEBUG HELPER
--------------------------------------------------------------------------------
function PakettiCommandWheelPrint(msg)
  if PakettiCommandWheelDebug then
    print("CommandWheel: " .. tostring(msg))
  end
end

--------------------------------------------------------------------------------
-- PHRASE MODE DETECTION
--------------------------------------------------------------------------------
function PakettiCommandWheelIsPhraseMode()
  local success, result = pcall(function()
    return renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
  end)
  if success then
    return result
  end
  return false
end

--------------------------------------------------------------------------------
-- SAFE ACCESSORS WITH PCALL
--------------------------------------------------------------------------------
function PakettiCommandWheelGetSong()
  local success, song = pcall(function() return renoise.song() end)
  if success and song then
    return song
  end
  return nil
end

function PakettiCommandWheelGetSelectedDevice()
  local song = PakettiCommandWheelGetSong()
  if not song then return nil end
  
  local success, device = pcall(function() return song.selected_device end)
  if success and device then
    return device
  end
  return nil
end

function PakettiCommandWheelGetSelectedInstrument()
  local song = PakettiCommandWheelGetSong()
  if not song then return nil end
  
  local success, instrument = pcall(function() return song.selected_instrument end)
  if success and instrument then
    return instrument
  end
  return nil
end

function PakettiCommandWheelGetSelectedPhrase()
  local song = PakettiCommandWheelGetSong()
  if not song then return nil end
  
  local success, phrase = pcall(function()
    local instr = song.selected_instrument
    if instr and #instr.phrases > 0 then
      local phrase_idx = song.selected_phrase_index
      if phrase_idx and phrase_idx > 0 and phrase_idx <= #instr.phrases then
        return instr.phrases[phrase_idx]
      end
    end
    return nil
  end)
  
  if success then
    return phrase
  end
  return nil
end

function PakettiCommandWheelGetDeviceParameter(device, index)
  if not device then return nil end
  
  local success, param = pcall(function()
    if index > 0 and index <= #device.parameters then
      return device.parameters[index]
    end
    return nil
  end)
  
  if success then
    return param
  end
  return nil
end

function PakettiCommandWheelGetMacro(instrument, index)
  if not instrument then return nil end
  
  local success, macro = pcall(function()
    if index > 0 and index <= 8 then
      return instrument.macros[index]
    end
    return nil
  end)
  
  if success then
    return macro
  end
  return nil
end

--------------------------------------------------------------------------------
-- *MIDI CONTROL DEVICE DETECTION
--------------------------------------------------------------------------------
function PakettiCommandWheelFindMidiControlDevice()
  local song = PakettiCommandWheelGetSong()
  if not song then return nil, nil end
  
  local success, result = pcall(function()
    local track = song.selected_track
    if not track then return nil, nil end
    
    for i, device in ipairs(track.devices) do
      if device.device_path == "Audio/Effects/Native/*MIDI Control" or
         device.name == "*MIDI Control" then
        return device, i
      end
    end
    return nil, nil
  end)
  
  if success then
    return result
  end
  return nil, nil
end

--------------------------------------------------------------------------------
-- WRITE POSITION HELPER
--------------------------------------------------------------------------------
function PakettiCommandWheelGetWritePosition()
  local song = PakettiCommandWheelGetSong()
  if not song then return nil, nil, nil end
  
  local success, result = pcall(function()
    local write_line
    local write_pattern_index = song.selected_pattern_index
    local write_track_index = song.selected_track_index
    
    if song.transport.playing and song.transport.follow_player then
      write_line = song.transport.playback_pos.line
      local playback_seq = song.transport.playback_pos.sequence
      write_pattern_index = song.sequencer.pattern_sequence[playback_seq]
    else
      write_line = song.selected_line_index
    end
    
    return {write_pattern_index, write_track_index, write_line}
  end)
  
  if success and result then
    return result[1], result[2], result[3]
  end
  return nil, nil, nil
end

--------------------------------------------------------------------------------
-- SELECTION RANGE HELPER
--------------------------------------------------------------------------------
function PakettiCommandWheelGetSelectionRange()
  local song = PakettiCommandWheelGetSong()
  if not song then return nil end
  
  local success, selection = pcall(function()
    return song.selection_in_pattern
  end)
  
  if success and selection then
    return selection
  end
  return nil
end

--------------------------------------------------------------------------------
-- MAX VALUE / MAX INDEX
--------------------------------------------------------------------------------
function PakettiCommandWheelGetMaxValue()
  local state = PakettiCommandWheelState
  
  if state.mode == PAKETTI_COMMAND_WHEEL_MODE_MACRO then
    return 127
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC then
    return 127
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_PATTERN_COMMAND then
    local cmd = PAKETTI_COMMAND_WHEEL_PATTERN_COMMANDS[state.index]
    if cmd then
      return cmd.max_value or 255
    end
    return 255
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_DEVICE then
    return 255
  end
  
  return 255
end

function PakettiCommandWheelGetMaxIndex()
  local state = PakettiCommandWheelState
  
  if state.mode == PAKETTI_COMMAND_WHEEL_MODE_MACRO then
    return 8
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC then
    -- *MIDI Control device has parameters for MIDI CCs
    local device = PakettiCommandWheelFindMidiControlDevice()
    if device then
      local success, count = pcall(function() return #device.parameters end)
      if success and count > 0 then
        return count
      end
    end
    return 16  -- Default to 16 if no device found
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_PATTERN_COMMAND then
    return #PAKETTI_COMMAND_WHEEL_PATTERN_COMMANDS
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_DEVICE then
    local device = PakettiCommandWheelGetSelectedDevice()
    if device then
      local success, count = pcall(function() return #device.parameters end)
      if success and count > 0 then
        return count
      end
    end
    return 1
  end
  
  return 1
end

--------------------------------------------------------------------------------
-- INDEX NAME
--------------------------------------------------------------------------------
function PakettiCommandWheelGetIndexName()
  local state = PakettiCommandWheelState
  
  if state.mode == PAKETTI_COMMAND_WHEEL_MODE_MACRO then
    return "Macro " .. state.index
    
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC then
    local device = PakettiCommandWheelFindMidiControlDevice()
    if device then
      local param = PakettiCommandWheelGetDeviceParameter(device, state.index)
      if param then
        local success, name = pcall(function() return param.name end)
        if success then
          return name
        end
      end
    end
    return "CC Param " .. state.index .. " (No *MIDI Control)"
    
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_PATTERN_COMMAND then
    local cmd = PAKETTI_COMMAND_WHEEL_PATTERN_COMMANDS[state.index]
    if cmd then
      return cmd.id .. " - " .. cmd.name
    end
    return "Unknown"
    
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_DEVICE then
    local device = PakettiCommandWheelGetSelectedDevice()
    if device then
      local param = PakettiCommandWheelGetDeviceParameter(device, state.index)
      if param then
        local success, name = pcall(function() return param.name end)
        if success then
          return name
        end
      end
    end
    return "No Device"
  end
  
  return "Unknown"
end

function PakettiCommandWheelFormatValue(value)
  return string.format("%02X (%d)", value, value)
end

--------------------------------------------------------------------------------
-- OBSERVABLE MANAGEMENT
--------------------------------------------------------------------------------
function PakettiCommandWheelSetupObservables()
  PakettiCommandWheelCleanupObservables()
  
  local song = PakettiCommandWheelGetSong()
  if not song then return end
  
  PakettiCommandWheelPrint("Setting up observables")
  
  -- Device selection observer
  local success1 = pcall(function()
    if song.selected_device_observable and 
       not song.selected_device_observable:has_notifier(PakettiCommandWheelOnDeviceChanged) then
      song.selected_device_observable:add_notifier(PakettiCommandWheelOnDeviceChanged)
      PakettiCommandWheelObservables.device_observer = PakettiCommandWheelOnDeviceChanged
      PakettiCommandWheelPrint("Device observer added")
    end
  end)
  
  -- Instrument selection observer
  local success2 = pcall(function()
    if song.selected_instrument_observable and
       not song.selected_instrument_observable:has_notifier(PakettiCommandWheelOnInstrumentChanged) then
      song.selected_instrument_observable:add_notifier(PakettiCommandWheelOnInstrumentChanged)
      PakettiCommandWheelObservables.instrument_observer = PakettiCommandWheelOnInstrumentChanged
      PakettiCommandWheelPrint("Instrument observer added")
    end
  end)
  
  -- Track selection observer
  local success3 = pcall(function()
    if song.selected_track_observable and
       not song.selected_track_observable:has_notifier(PakettiCommandWheelOnTrackChanged) then
      song.selected_track_observable:add_notifier(PakettiCommandWheelOnTrackChanged)
      PakettiCommandWheelObservables.track_observer = PakettiCommandWheelOnTrackChanged
      PakettiCommandWheelPrint("Track observer added")
    end
  end)
end

function PakettiCommandWheelCleanupObservables()
  local song = PakettiCommandWheelGetSong()
  if not song then return end
  
  PakettiCommandWheelPrint("Cleaning up observables")
  
  pcall(function()
    if PakettiCommandWheelObservables.device_observer and song.selected_device_observable then
      if song.selected_device_observable:has_notifier(PakettiCommandWheelObservables.device_observer) then
        song.selected_device_observable:remove_notifier(PakettiCommandWheelObservables.device_observer)
      end
    end
  end)
  PakettiCommandWheelObservables.device_observer = nil
  
  pcall(function()
    if PakettiCommandWheelObservables.instrument_observer and song.selected_instrument_observable then
      if song.selected_instrument_observable:has_notifier(PakettiCommandWheelObservables.instrument_observer) then
        song.selected_instrument_observable:remove_notifier(PakettiCommandWheelObservables.instrument_observer)
      end
    end
  end)
  PakettiCommandWheelObservables.instrument_observer = nil
  
  pcall(function()
    if PakettiCommandWheelObservables.track_observer and song.selected_track_observable then
      if song.selected_track_observable:has_notifier(PakettiCommandWheelObservables.track_observer) then
        song.selected_track_observable:remove_notifier(PakettiCommandWheelObservables.track_observer)
      end
    end
  end)
  PakettiCommandWheelObservables.track_observer = nil
end

function PakettiCommandWheelOnDeviceChanged()
  PakettiCommandWheelPrint("Device changed")
  local state = PakettiCommandWheelState
  
  if state.mode == PAKETTI_COMMAND_WHEEL_MODE_DEVICE then
    -- Reset index to 1 and sync value
    state.index = 1
    PakettiCommandWheelSyncDeviceValue()
    PakettiCommandWheelUpdateDisplay()
  end
end

function PakettiCommandWheelOnInstrumentChanged()
  PakettiCommandWheelPrint("Instrument changed")
  local state = PakettiCommandWheelState
  
  if state.mode == PAKETTI_COMMAND_WHEEL_MODE_MACRO then
    PakettiCommandWheelSyncMacroValue()
    PakettiCommandWheelUpdateDisplay()
  end
end

function PakettiCommandWheelOnTrackChanged()
  PakettiCommandWheelPrint("Track changed")
  local state = PakettiCommandWheelState
  
  if state.mode == PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC then
    -- Re-check for *MIDI Control device
    state.index = 1
    PakettiCommandWheelSyncMidiCCValue()
    PakettiCommandWheelUpdateDisplay()
  end
end

--------------------------------------------------------------------------------
-- MODE SWITCHING
--------------------------------------------------------------------------------
function PakettiCommandWheelSetMode(new_mode)
  local state = PakettiCommandWheelState
  state.mode = new_mode
  state.index = 1
  state.value = 0
  
  if new_mode == PAKETTI_COMMAND_WHEEL_MODE_DEVICE then
    PakettiCommandWheelSyncDeviceValue()
  elseif new_mode == PAKETTI_COMMAND_WHEEL_MODE_MACRO then
    PakettiCommandWheelSyncMacroValue()
  elseif new_mode == PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC then
    PakettiCommandWheelSyncMidiCCValue()
  end
  
  PakettiCommandWheelUpdateDisplay()
  renoise.app():show_status("Command Wheel: " .. PAKETTI_COMMAND_WHEEL_MODE_NAMES[new_mode] .. " mode")
end

function PakettiCommandWheelSetModeMacro()
  PakettiCommandWheelSetMode(PAKETTI_COMMAND_WHEEL_MODE_MACRO)
end

function PakettiCommandWheelSetModeMidiCC()
  PakettiCommandWheelSetMode(PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC)
end

function PakettiCommandWheelSetModePatternCommand()
  PakettiCommandWheelSetMode(PAKETTI_COMMAND_WHEEL_MODE_PATTERN_COMMAND)
end

function PakettiCommandWheelSetModeDevice()
  PakettiCommandWheelSetMode(PAKETTI_COMMAND_WHEEL_MODE_DEVICE)
end

--------------------------------------------------------------------------------
-- INDEX NAVIGATION
--------------------------------------------------------------------------------
function PakettiCommandWheelIndexNext()
  local state = PakettiCommandWheelState
  local max_index = PakettiCommandWheelGetMaxIndex()
  
  state.index = state.index + 1
  if state.index > max_index then
    state.index = 1
  end
  
  if state.mode == PAKETTI_COMMAND_WHEEL_MODE_DEVICE then
    PakettiCommandWheelSyncDeviceValue()
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_MACRO then
    PakettiCommandWheelSyncMacroValue()
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC then
    PakettiCommandWheelSyncMidiCCValue()
  else
    state.value = 0
  end
  
  PakettiCommandWheelUpdateDisplay()
  renoise.app():show_status("Command Wheel: " .. PakettiCommandWheelGetIndexName())
end

function PakettiCommandWheelIndexPrev()
  local state = PakettiCommandWheelState
  local max_index = PakettiCommandWheelGetMaxIndex()
  
  state.index = state.index - 1
  if state.index < 1 then
    state.index = max_index
  end
  
  if state.mode == PAKETTI_COMMAND_WHEEL_MODE_DEVICE then
    PakettiCommandWheelSyncDeviceValue()
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_MACRO then
    PakettiCommandWheelSyncMacroValue()
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC then
    PakettiCommandWheelSyncMidiCCValue()
  else
    state.value = 0
  end
  
  PakettiCommandWheelUpdateDisplay()
  renoise.app():show_status("Command Wheel: " .. PakettiCommandWheelGetIndexName())
end

--------------------------------------------------------------------------------
-- VALUE SYNC
--------------------------------------------------------------------------------
function PakettiCommandWheelSyncDeviceValue()
  local state = PakettiCommandWheelState
  local device = PakettiCommandWheelGetSelectedDevice()
  
  if not device then
    state.value = 0
    return
  end
  
  local param = PakettiCommandWheelGetDeviceParameter(device, state.index)
  if param then
    local success, result = pcall(function()
      local normalized = (param.value - param.value_min) / (param.value_max - param.value_min)
      return math.floor(normalized * 255 + 0.5)
    end)
    if success then
      state.value = result
    else
      state.value = 0
    end
  else
    state.value = 0
  end
end

function PakettiCommandWheelSyncMacroValue()
  local state = PakettiCommandWheelState
  local instrument = PakettiCommandWheelGetSelectedInstrument()
  
  if not instrument then
    state.value = 0
    return
  end
  
  local macro = PakettiCommandWheelGetMacro(instrument, state.index)
  if macro then
    local success, result = pcall(function()
      return math.floor(macro.value * 127 + 0.5)
    end)
    if success then
      state.value = result
    else
      state.value = 0
    end
  else
    state.value = 0
  end
end

function PakettiCommandWheelSyncMidiCCValue()
  local state = PakettiCommandWheelState
  local device = PakettiCommandWheelFindMidiControlDevice()
  
  if not device then
    state.value = 0
    return
  end
  
  local param = PakettiCommandWheelGetDeviceParameter(device, state.index)
  if param then
    local success, result = pcall(function()
      local normalized = (param.value - param.value_min) / (param.value_max - param.value_min)
      return math.floor(normalized * 127 + 0.5)
    end)
    if success then
      state.value = result
    else
      state.value = 0
    end
  else
    state.value = 0
  end
end

--------------------------------------------------------------------------------
-- VALUE ADJUSTMENT
--------------------------------------------------------------------------------
function PakettiCommandWheelAdjustValue(delta)
  local state = PakettiCommandWheelState
  local max_value = PakettiCommandWheelGetMaxValue()
  
  state.value = state.value + delta
  if state.value > max_value then
    state.value = max_value
  elseif state.value < 0 then
    state.value = 0
  end
  
  -- Apply value immediately for modes that support audition
  if state.mode == PAKETTI_COMMAND_WHEEL_MODE_MACRO then
    PakettiCommandWheelApplyMacroValue()
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_DEVICE then
    PakettiCommandWheelApplyDeviceValue()
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC then
    PakettiCommandWheelApplyMidiCCValue()
  end
  
  if state.write_on_scroll then
    PakettiCommandWheelWriteToPattern()
  end
  
  PakettiCommandWheelUpdateDisplay()
  
  local hex_value = string.format("%02X", state.value)
  renoise.app():show_status("Command Wheel: " .. PakettiCommandWheelGetIndexName() .. " = " .. hex_value .. " (" .. state.value .. ")")
end

function PakettiCommandWheelValueUp1()
  PakettiCommandWheelAdjustValue(1)
end

function PakettiCommandWheelValueDown1()
  PakettiCommandWheelAdjustValue(-1)
end

function PakettiCommandWheelValueUp10()
  PakettiCommandWheelAdjustValue(10)
end

function PakettiCommandWheelValueDown10()
  PakettiCommandWheelAdjustValue(-10)
end

--------------------------------------------------------------------------------
-- VALUE APPLICATION (Audition)
--------------------------------------------------------------------------------
function PakettiCommandWheelApplyMacroValue()
  local state = PakettiCommandWheelState
  local instrument = PakettiCommandWheelGetSelectedInstrument()
  
  if not instrument then
    PakettiCommandWheelPrint("No instrument for macro apply")
    return
  end
  
  local macro = PakettiCommandWheelGetMacro(instrument, state.index)
  if macro then
    local success, err = pcall(function()
      macro.value = state.value / 127
    end)
    if not success then
      PakettiCommandWheelPrint("Error applying macro: " .. tostring(err))
    end
  end
end

function PakettiCommandWheelApplyDeviceValue()
  local state = PakettiCommandWheelState
  local device = PakettiCommandWheelGetSelectedDevice()
  
  if not device then
    PakettiCommandWheelPrint("No device for value apply")
    return
  end
  
  local param = PakettiCommandWheelGetDeviceParameter(device, state.index)
  if param then
    local success, err = pcall(function()
      local normalized = state.value / 255
      param.value = param.value_min + normalized * (param.value_max - param.value_min)
    end)
    if not success then
      PakettiCommandWheelPrint("Error applying device value: " .. tostring(err))
    end
  end
end

function PakettiCommandWheelApplyMidiCCValue()
  local state = PakettiCommandWheelState
  local device = PakettiCommandWheelFindMidiControlDevice()
  
  if not device then
    PakettiCommandWheelPrint("No *MIDI Control device for CC apply")
    return
  end
  
  local param = PakettiCommandWheelGetDeviceParameter(device, state.index)
  if param then
    local success, err = pcall(function()
      local normalized = state.value / 127
      param.value = param.value_min + normalized * (param.value_max - param.value_min)
    end)
    if not success then
      PakettiCommandWheelPrint("Error applying MIDI CC: " .. tostring(err))
    end
  end
end

--------------------------------------------------------------------------------
-- PATTERN/PHRASE WRITING - CORE DISPATCHER
--------------------------------------------------------------------------------
function PakettiCommandWheelWriteToPattern()
  local state = PakettiCommandWheelState
  local is_phrase_mode = PakettiCommandWheelIsPhraseMode()
  
  PakettiCommandWheelPrint("WriteToPattern: mode=" .. state.mode .. ", phrase_mode=" .. tostring(is_phrase_mode))
  
  if state.mode == PAKETTI_COMMAND_WHEEL_MODE_MACRO then
    PakettiCommandWheelWriteMacro(is_phrase_mode)
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC then
    if is_phrase_mode then
      renoise.app():show_status("Command Wheel: *MIDI Control cannot write to phrases")
    else
      PakettiCommandWheelWriteMidiCC()
    end
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_PATTERN_COMMAND then
    PakettiCommandWheelWritePatternCommand(is_phrase_mode)
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_DEVICE then
    renoise.app():show_status("Command Wheel: DEVICE mode does not write to pattern")
  end
end

--------------------------------------------------------------------------------
-- MACRO WRITING
--------------------------------------------------------------------------------
function PakettiCommandWheelWriteMacro(is_phrase_mode)
  local state = PakettiCommandWheelState
  local song = PakettiCommandWheelGetSong()
  if not song then return end
  
  -- Macro commands use 1X format where X is the macro number (1-8)
  local effect_number = string.format("1%d", state.index)
  local amount_string = string.format("%02X", state.value)
  
  if is_phrase_mode then
    PakettiCommandWheelWriteEffectToPhrase(effect_number, amount_string)
  else
    PakettiCommandWheelWriteEffectToPattern(effect_number, amount_string)
  end
end

--------------------------------------------------------------------------------
-- MIDI CC WRITING (*MIDI Control device)
--------------------------------------------------------------------------------
function PakettiCommandWheelWriteMidiCC()
  local state = PakettiCommandWheelState
  local song = PakettiCommandWheelGetSong()
  if not song then return end
  
  local device, device_index = PakettiCommandWheelFindMidiControlDevice()
  if not device then
    renoise.app():show_status("Command Wheel: No *MIDI Control device on track")
    return
  end
  
  -- Write device parameter automation command
  -- Format: XYxx where X is device index (hex), Y is parameter index (hex), xx is value
  local device_hex = string.format("%X", device_index)
  local param_hex = string.format("%X", state.index)
  local effect_number = device_hex .. param_hex
  local amount_string = string.format("%02X", state.value)
  
  PakettiCommandWheelWriteEffectToPattern(effect_number, amount_string)
end

--------------------------------------------------------------------------------
-- PATTERN COMMAND WRITING
--------------------------------------------------------------------------------
function PakettiCommandWheelWritePatternCommand(is_phrase_mode)
  local state = PakettiCommandWheelState
  local cmd = PAKETTI_COMMAND_WHEEL_PATTERN_COMMANDS[state.index]
  
  if not cmd then
    PakettiCommandWheelPrint("Invalid command index: " .. state.index)
    return
  end
  
  -- Check if command is valid for phrase mode
  if is_phrase_mode and not cmd.phrase_valid then
    renoise.app():show_status("Command Wheel: " .. cmd.id .. " not valid in phrases")
    return
  end
  
  -- Handle note column sub-columns
  if cmd.is_note_column then
    if is_phrase_mode then
      PakettiCommandWheelWriteNoteColumnToPhrase(cmd)
    else
      PakettiCommandWheelWriteNoteColumnToPattern(cmd)
    end
    return
  end
  
  -- Handle effect column commands
  local effect_number = cmd.id
  local amount_string = string.format("%02X", state.value)
  
  if is_phrase_mode then
    PakettiCommandWheelWriteEffectToPhrase(effect_number, amount_string)
  else
    PakettiCommandWheelWriteEffectToPattern(effect_number, amount_string)
  end
end

--------------------------------------------------------------------------------
-- EFFECT COLUMN WRITERS (WITH SELECTION SUPPORT)
--------------------------------------------------------------------------------
function PakettiCommandWheelWriteEffectToPattern(effect_number, amount_string)
  local state = PakettiCommandWheelState
  local song = PakettiCommandWheelGetSong()
  if not song then return end
  
  local selection = PakettiCommandWheelGetSelectionRange()
  
  if selection then
    -- Write to selection range
    PakettiCommandWheelWriteEffectToSelection(effect_number, amount_string, selection)
  else
    -- Write to single line
    PakettiCommandWheelWriteEffectToSingleLine(effect_number, amount_string)
  end
end

function PakettiCommandWheelWriteEffectToSingleLine(effect_number, amount_string)
  local state = PakettiCommandWheelState
  local song = PakettiCommandWheelGetSong()
  if not song then return end
  
  local pattern_idx, track_idx, line_idx = PakettiCommandWheelGetWritePosition()
  if not pattern_idx then return end
  
  local success, err = pcall(function()
    local track = song:track(track_idx)
    
    if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
      renoise.app():show_status("Command Wheel: Cannot write to non-sequencer track")
      return
    end
    
    local pattern = song:pattern(pattern_idx)
    local pattern_track = pattern:track(track_idx)
    local line = pattern_track:line(line_idx)
    
    -- Apply placement policy
    local effect_column = PakettiCommandWheelGetTargetEffectColumn(track, line)
    if not effect_column then
      renoise.app():show_status("Command Wheel: No valid effect column (policy: " .. 
        PAKETTI_COMMAND_WHEEL_PLACEMENT_NAMES[state.placement_policy] .. ")")
      return
    end
    
    effect_column.number_string = effect_number
    effect_column.amount_string = amount_string
    
    renoise.app():show_status("Command Wheel: Wrote " .. effect_number .. amount_string .. " at line " .. line_idx)
  end)
  
  if not success then
    PakettiCommandWheelPrint("Error writing effect: " .. tostring(err))
  end
end

function PakettiCommandWheelWriteEffectToSelection(effect_number, amount_string, selection)
  local state = PakettiCommandWheelState
  local song = PakettiCommandWheelGetSong()
  if not song then return end
  
  local effects_written = 0
  
  local success, err = pcall(function()
    local pattern = song:pattern(song.selected_pattern_index)
    
    for track_idx = selection.start_track, selection.end_track do
      local track = song:track(track_idx)
      
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local pattern_track = pattern:track(track_idx)
        
        for line_idx = selection.start_line, selection.end_line do
          local line = pattern_track:line(line_idx)
          local effect_column = PakettiCommandWheelGetTargetEffectColumn(track, line)
          
          if effect_column then
            effect_column.number_string = effect_number
            effect_column.amount_string = amount_string
            effects_written = effects_written + 1
          end
        end
      end
    end
  end)
  
  if success and effects_written > 0 then
    renoise.app():show_status("Command Wheel: Wrote " .. effect_number .. amount_string .. 
      " to " .. effects_written .. " positions in selection")
  elseif not success then
    PakettiCommandWheelPrint("Error writing to selection: " .. tostring(err))
  end
end

function PakettiCommandWheelWriteEffectToPhrase(effect_number, amount_string)
  local state = PakettiCommandWheelState
  local song = PakettiCommandWheelGetSong()
  if not song then return end
  
  local phrase = PakettiCommandWheelGetSelectedPhrase()
  if not phrase then
    renoise.app():show_status("Command Wheel: No phrase selected")
    return
  end
  
  local success, err = pcall(function()
    local line_idx = song.selected_line_index
    if line_idx < 1 or line_idx > phrase.number_of_lines then
      line_idx = 1
    end
    
    local line = phrase:line(line_idx)
    
    -- Ensure effect column exists
    if phrase.visible_effect_columns == 0 then
      phrase.visible_effect_columns = 1
    end
    
    local effect_column = line:effect_column(1)
    effect_column.number_string = effect_number
    effect_column.amount_string = amount_string
    
    renoise.app():show_status("Command Wheel: Wrote " .. effect_number .. amount_string .. 
      " to phrase line " .. line_idx)
  end)
  
  if not success then
    PakettiCommandWheelPrint("Error writing to phrase: " .. tostring(err))
  end
end

--------------------------------------------------------------------------------
-- NOTE COLUMN WRITERS (WITH SELECTION SUPPORT)
--------------------------------------------------------------------------------
function PakettiCommandWheelWriteNoteColumnToPattern(cmd)
  local state = PakettiCommandWheelState
  local song = PakettiCommandWheelGetSong()
  if not song then return end
  
  local selection = PakettiCommandWheelGetSelectionRange()
  
  if selection then
    PakettiCommandWheelWriteNoteColumnToSelection(cmd, selection)
  else
    PakettiCommandWheelWriteNoteColumnToSingleLine(cmd)
  end
end

function PakettiCommandWheelWriteNoteColumnToSingleLine(cmd)
  local state = PakettiCommandWheelState
  local song = PakettiCommandWheelGetSong()
  if not song then return end
  
  local pattern_idx, track_idx, line_idx = PakettiCommandWheelGetWritePosition()
  if not pattern_idx then return end
  
  local success, err = pcall(function()
    local pattern = song:pattern(pattern_idx)
    local pattern_track = pattern:track(track_idx)
    local line = pattern_track:line(line_idx)
    
    local note_column_idx = PakettiCommandWheelGetTargetNoteColumn(cmd)
    if not note_column_idx then
      renoise.app():show_status("Command Wheel: No valid note column")
      return
    end
    
    local note_column = line:note_column(note_column_idx)
    
    if cmd.id == "VOLUME" then
      note_column.volume_value = state.value
    elseif cmd.id == "PANNING" then
      note_column.panning_value = state.value
    elseif cmd.id == "DELAY" then
      note_column.delay_value = state.value
    end
    
    renoise.app():show_status("Command Wheel: Wrote " .. cmd.name .. " = " .. 
      string.format("%02X", state.value) .. " at line " .. line_idx)
  end)
  
  if not success then
    PakettiCommandWheelPrint("Error writing note column: " .. tostring(err))
  end
end

function PakettiCommandWheelWriteNoteColumnToSelection(cmd, selection)
  local state = PakettiCommandWheelState
  local song = PakettiCommandWheelGetSong()
  if not song then return end
  
  local values_written = 0
  
  local success, err = pcall(function()
    local pattern = song:pattern(song.selected_pattern_index)
    
    for track_idx = selection.start_track, selection.end_track do
      local track = song:track(track_idx)
      local pattern_track = pattern:track(track_idx)
      
      for line_idx = selection.start_line, selection.end_line do
        local line = pattern_track:line(line_idx)
        
        -- Get note column based on placement policy
        local note_column_idx = PakettiCommandWheelGetTargetNoteColumn(cmd)
        if note_column_idx and note_column_idx <= track.visible_note_columns then
          local note_column = line:note_column(note_column_idx)
          
          if cmd.id == "VOLUME" then
            note_column.volume_value = state.value
          elseif cmd.id == "PANNING" then
            note_column.panning_value = state.value
          elseif cmd.id == "DELAY" then
            note_column.delay_value = state.value
          end
          
          values_written = values_written + 1
        end
      end
    end
  end)
  
  if success and values_written > 0 then
    renoise.app():show_status("Command Wheel: Wrote " .. cmd.name .. " = " .. 
      string.format("%02X", state.value) .. " to " .. values_written .. " positions")
  elseif not success then
    PakettiCommandWheelPrint("Error writing to selection: " .. tostring(err))
  end
end

function PakettiCommandWheelWriteNoteColumnToPhrase(cmd)
  local state = PakettiCommandWheelState
  local song = PakettiCommandWheelGetSong()
  if not song then return end
  
  local phrase = PakettiCommandWheelGetSelectedPhrase()
  if not phrase then
    renoise.app():show_status("Command Wheel: No phrase selected")
    return
  end
  
  local success, err = pcall(function()
    local line_idx = song.selected_line_index
    if line_idx < 1 or line_idx > phrase.number_of_lines then
      line_idx = 1
    end
    
    local line = phrase:line(line_idx)
    local note_column = line:note_column(1)
    
    if cmd.id == "VOLUME" then
      note_column.volume_value = state.value
    elseif cmd.id == "PANNING" then
      note_column.panning_value = state.value
    elseif cmd.id == "DELAY" then
      note_column.delay_value = state.value
    end
    
    renoise.app():show_status("Command Wheel: Wrote " .. cmd.name .. " = " .. 
      string.format("%02X", state.value) .. " to phrase line " .. line_idx)
  end)
  
  if not success then
    PakettiCommandWheelPrint("Error writing to phrase: " .. tostring(err))
  end
end

--------------------------------------------------------------------------------
-- PLACEMENT POLICY HELPERS
--------------------------------------------------------------------------------
function PakettiCommandWheelGetTargetEffectColumn(track, line)
  local state = PakettiCommandWheelState
  local policy = state.placement_policy
  local song = PakettiCommandWheelGetSong()
  if not song then return nil end
  
  if policy == PAKETTI_COMMAND_WHEEL_PLACEMENT_CURSOR then
    -- Overwrite current column
    if track.visible_effect_columns == 0 then
      track.visible_effect_columns = 1
    end
    local col_idx = song.selected_effect_column_index
    if col_idx and col_idx > 0 and col_idx <= track.visible_effect_columns then
      return line:effect_column(col_idx)
    end
    return line:effect_column(1)
    
  elseif policy == PAKETTI_COMMAND_WHEEL_PLACEMENT_FIND_APPROPRIATE then
    -- Use first effect column
    if track.visible_effect_columns == 0 then
      track.visible_effect_columns = 1
    end
    return line:effect_column(1)
    
  elseif policy == PAKETTI_COMMAND_WHEEL_PLACEMENT_FIND_COMPATIBLE then
    -- Find first empty or matching effect column
    for i = 1, track.visible_effect_columns do
      local col = line:effect_column(i)
      if col.number_string == ".." or col.number_string == "" then
        return col
      end
    end
    -- If none empty, use first
    if track.visible_effect_columns > 0 then
      return line:effect_column(1)
    end
    return nil
    
  elseif policy == PAKETTI_COMMAND_WHEEL_PLACEMENT_CREATE_NEW then
    -- Create new column if needed
    local found_empty = false
    for i = 1, track.visible_effect_columns do
      local col = line:effect_column(i)
      if col.number_string == ".." or col.number_string == "" then
        found_empty = true
        return col
      end
    end
    
    if not found_empty and track.visible_effect_columns < 8 then
      track.visible_effect_columns = track.visible_effect_columns + 1
      return line:effect_column(track.visible_effect_columns)
    end
    
    if track.visible_effect_columns > 0 then
      return line:effect_column(1)
    end
    return nil
    
  elseif policy == PAKETTI_COMMAND_WHEEL_PLACEMENT_NEVER_EXPAND then
    -- Never expand, only use existing
    if track.visible_effect_columns > 0 then
      return line:effect_column(1)
    end
    return nil
  end
  
  return nil
end

function PakettiCommandWheelGetTargetNoteColumn(cmd)
  local state = PakettiCommandWheelState
  local policy = state.placement_policy
  local song = PakettiCommandWheelGetSong()
  if not song then return nil end
  
  -- For note columns, placement policy affects which column to use
  if policy == PAKETTI_COMMAND_WHEEL_PLACEMENT_CURSOR or
     policy == PAKETTI_COMMAND_WHEEL_PLACEMENT_FIND_APPROPRIATE then
    local col_idx = song.selected_note_column_index
    if col_idx and col_idx > 0 then
      return col_idx
    end
    return 1
  end
  
  return song.selected_note_column_index or 1
end

--------------------------------------------------------------------------------
-- PLACEMENT POLICY CYCLING
--------------------------------------------------------------------------------
function PakettiCommandWheelCyclePlacementPolicy()
  local state = PakettiCommandWheelState
  
  state.placement_policy = state.placement_policy + 1
  if state.placement_policy > PAKETTI_COMMAND_WHEEL_PLACEMENT_NEVER_EXPAND then
    state.placement_policy = PAKETTI_COMMAND_WHEEL_PLACEMENT_CURSOR
  end
  
  PakettiCommandWheelUpdateDisplay()
  renoise.app():show_status("Command Wheel: Placement = " .. 
    PAKETTI_COMMAND_WHEEL_PLACEMENT_NAMES[state.placement_policy])
end

function PakettiCommandWheelTogglePlacementPolicy()
  PakettiCommandWheelCyclePlacementPolicy()
end

--------------------------------------------------------------------------------
-- WRITE ON SCROLL TOGGLE
--------------------------------------------------------------------------------
function PakettiCommandWheelToggleWriteOnScroll()
  local state = PakettiCommandWheelState
  state.write_on_scroll = not state.write_on_scroll
  
  PakettiCommandWheelUpdateDisplay()
  
  if state.write_on_scroll then
    renoise.app():show_status("Command Wheel: Write on scroll ENABLED")
  else
    renoise.app():show_status("Command Wheel: Write on scroll DISABLED")
  end
end

--------------------------------------------------------------------------------
-- DIALOG UPDATE
--------------------------------------------------------------------------------
function PakettiCommandWheelUpdateDisplay()
  local vb = PakettiCommandWheelViewBuilder
  if not vb then return end
  
  local state = PakettiCommandWheelState
  
  local success = pcall(function()
    if vb.views.mode_switch then
      vb.views.mode_switch.value = state.mode
    end
    
    if vb.views.index_display then
      vb.views.index_display.text = PakettiCommandWheelGetIndexName()
    end
    
    if vb.views.value_display then
      vb.views.value_display.text = PakettiCommandWheelFormatValue(state.value)
    end
    
    if vb.views.value_slider then
      local max_value = PakettiCommandWheelGetMaxValue()
      vb.views.value_slider.max = max_value
      vb.views.value_slider.value = math.min(state.value, max_value)
    end
    
    if vb.views.placement_display then
      vb.views.placement_display.text = PAKETTI_COMMAND_WHEEL_PLACEMENT_NAMES[state.placement_policy]
    end
    
    if vb.views.write_on_scroll_checkbox then
      vb.views.write_on_scroll_checkbox.value = state.write_on_scroll
    end
    
    if vb.views.phrase_indicator then
      local is_phrase = PakettiCommandWheelIsPhraseMode()
      vb.views.phrase_indicator.text = is_phrase and "PHRASE MODE" or "PATTERN MODE"
    end
  end)
end

--------------------------------------------------------------------------------
-- DIALOG KEYHANDLER
--------------------------------------------------------------------------------
function PakettiCommandWheelKeyHandler(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  
  PakettiCommandWheelPrint("KEY: name='" .. tostring(key.name) .. "' mod='" .. tostring(key.modifiers) .. "'")
  
  if key.modifiers == "" and key.name == closer then
    PakettiCommandWheelCleanupObservables()
    dialog:close()
    PakettiCommandWheelDialog = nil
    return nil
  end
  
  if key.name == "wheel_up" then
    if key.modifiers == "shift" then
      PakettiCommandWheelAdjustValue(10)
    else
      PakettiCommandWheelAdjustValue(1)
    end
    return nil
  elseif key.name == "wheel_down" then
    if key.modifiers == "shift" then
      PakettiCommandWheelAdjustValue(-10)
    else
      PakettiCommandWheelAdjustValue(-1)
    end
    return nil
  end
  
  if key.modifiers == "" then
    if key.name == "left" then
      PakettiCommandWheelIndexPrev()
      return nil
    elseif key.name == "right" then
      PakettiCommandWheelIndexNext()
      return nil
    elseif key.name == "up" then
      PakettiCommandWheelAdjustValue(1)
      return nil
    elseif key.name == "down" then
      PakettiCommandWheelAdjustValue(-1)
      return nil
    elseif key.name == "return" then
      PakettiCommandWheelWriteToPattern()
      return nil
    elseif key.name == "p" then
      PakettiCommandWheelCyclePlacementPolicy()
      return nil
    elseif key.name == "1" then
      PakettiCommandWheelSetModeMacro()
      return nil
    elseif key.name == "2" then
      PakettiCommandWheelSetModeMidiCC()
      return nil
    elseif key.name == "3" then
      PakettiCommandWheelSetModePatternCommand()
      return nil
    elseif key.name == "4" then
      PakettiCommandWheelSetModeDevice()
      return nil
    end
  end
  
  return key
end

--------------------------------------------------------------------------------
-- DIALOG
--------------------------------------------------------------------------------
function PakettiCommandWheelShowDialog()
  if PakettiCommandWheelDialog and PakettiCommandWheelDialog.visible then
    PakettiCommandWheelCleanupObservables()
    PakettiCommandWheelDialog:close()
    PakettiCommandWheelDialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  PakettiCommandWheelViewBuilder = vb
  
  local state = PakettiCommandWheelState
  local max_value = PakettiCommandWheelGetMaxValue()
  local is_phrase = PakettiCommandWheelIsPhraseMode()
  
  local content = vb:column{
    margin = 10,
    spacing = 8,
    
    -- Mode selector
    vb:row{
      spacing = 4,
      vb:text{text = "Mode:", width = 60},
      vb:switch{
        id = "mode_switch",
        items = {"MACRO", "*MIDI Ctrl", "PAT CMD", "DEVICE"},
        value = state.mode,
        width = 280,
        notifier = function(value)
          PakettiCommandWheelSetMode(value)
        end
      }
    },
    
    -- Index display and navigation
    vb:row{
      spacing = 4,
      vb:text{text = "Index:", width = 60},
      vb:button{
        text = "<",
        width = 30,
        notifier = function()
          PakettiCommandWheelIndexPrev()
        end
      },
      vb:text{
        id = "index_display",
        text = PakettiCommandWheelGetIndexName(),
        width = 190,
        font = "bold"
      },
      vb:button{
        text = ">",
        width = 30,
        notifier = function()
          PakettiCommandWheelIndexNext()
        end
      }
    },
    
    -- Value display and slider
    vb:row{
      spacing = 4,
      vb:text{text = "Value:", width = 60},
      vb:text{
        id = "value_display",
        text = PakettiCommandWheelFormatValue(state.value),
        width = 80,
        font = "bold"
      },
      vb:slider{
        id = "value_slider",
        min = 0,
        max = max_value,
        value = state.value,
        width = 170,
        notifier = function(value)
          state.value = math.floor(value)
          
          if state.mode == PAKETTI_COMMAND_WHEEL_MODE_MACRO then
            PakettiCommandWheelApplyMacroValue()
          elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_DEVICE then
            PakettiCommandWheelApplyDeviceValue()
          elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC then
            PakettiCommandWheelApplyMidiCCValue()
          end
          
          PakettiCommandWheelUpdateDisplay()
          
          local hex_value = string.format("%02X", state.value)
          renoise.app():show_status("Command Wheel: " .. PakettiCommandWheelGetIndexName() .. " = " .. hex_value .. " (" .. state.value .. ")")
        end
      }
    },
    
    -- Placement policy
    vb:row{
      spacing = 4,
      vb:text{text = "Placement:", width = 60},
      vb:text{
        id = "placement_display",
        text = PAKETTI_COMMAND_WHEEL_PLACEMENT_NAMES[state.placement_policy],
        width = 150
      },
      vb:button{
        text = "Cycle (P)",
        width = 80,
        notifier = function()
          PakettiCommandWheelCyclePlacementPolicy()
        end
      }
    },
    
    -- Write on scroll toggle
    vb:row{
      spacing = 4,
      vb:checkbox{
        id = "write_on_scroll_checkbox",
        value = state.write_on_scroll,
        notifier = function(value)
          state.write_on_scroll = value
          if value then
            renoise.app():show_status("Command Wheel: Write on scroll ENABLED")
          else
            renoise.app():show_status("Command Wheel: Write on scroll DISABLED")
          end
        end
      },
      vb:text{text = "Write on Scroll"},
      vb:space{width = 50},
      vb:text{
        id = "phrase_indicator",
        text = is_phrase and "PHRASE MODE" or "PATTERN MODE",
        font = "italic"
      }
    },
    
    -- Write button
    vb:row{
      spacing = 4,
      vb:button{
        text = "Write to Pattern/Phrase (Enter)",
        width = 340,
        notifier = function()
          PakettiCommandWheelWriteToPattern()
        end
      }
    },
    
    -- Help text
    vb:text{
      text = "Scroll: +/-1 | Shift+Scroll: +/-10 | Arrows: nav | 1-4: mode | P: placement",
      font = "italic"
    }
  }
  
  -- Setup observables before showing dialog
  PakettiCommandWheelSetupObservables()
  
  -- Sync current values
  if state.mode == PAKETTI_COMMAND_WHEEL_MODE_DEVICE then
    PakettiCommandWheelSyncDeviceValue()
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_MACRO then
    PakettiCommandWheelSyncMacroValue()
  elseif state.mode == PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC then
    PakettiCommandWheelSyncMidiCCValue()
  end
  
  PakettiCommandWheelDialog = renoise.app():show_custom_dialog(
    "Paketti Command Wheel",
    content,
    PakettiCommandWheelKeyHandler
  )
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

--------------------------------------------------------------------------------
-- KEYBINDINGS
--------------------------------------------------------------------------------
renoise.tool():add_keybinding{
  name = "Global:Paketti:Command Wheel Dialog",
  invoke = function() PakettiCommandWheelShowDialog() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Command Wheel Mode MACRO",
  invoke = function() PakettiCommandWheelSetModeMacro() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Command Wheel Mode MIDI CC",
  invoke = function() PakettiCommandWheelSetModeMidiCC() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Command Wheel Mode PATTERN COMMAND",
  invoke = function() PakettiCommandWheelSetModePatternCommand() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Command Wheel Mode DEVICE",
  invoke = function() PakettiCommandWheelSetModeDevice() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Command Wheel Index +1",
  invoke = function() PakettiCommandWheelIndexNext() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Command Wheel Index -1",
  invoke = function() PakettiCommandWheelIndexPrev() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Command Wheel Value +1",
  invoke = function() PakettiCommandWheelValueUp1() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Command Wheel Value -1",
  invoke = function() PakettiCommandWheelValueDown1() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Command Wheel Value +10",
  invoke = function() PakettiCommandWheelValueUp10() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Command Wheel Value -10",
  invoke = function() PakettiCommandWheelValueDown10() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Command Wheel Toggle Placement Policy",
  invoke = function() PakettiCommandWheelTogglePlacementPolicy() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Command Wheel Write to Pattern",
  invoke = function() PakettiCommandWheelWriteToPattern() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Command Wheel Toggle Write on Scroll",
  invoke = function() PakettiCommandWheelToggleWriteOnScroll() end
}

--------------------------------------------------------------------------------
-- MENU ENTRIES
--------------------------------------------------------------------------------
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Instruments..:Command Wheel...",
  invoke = function() PakettiCommandWheelShowDialog() end
}

renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti..:Command Wheel...",
  invoke = function() PakettiCommandWheelShowDialog() end
}

renoise.tool():add_menu_entry{
  name = "Phrase Editor:Paketti..:Command Wheel...",
  invoke = function() PakettiCommandWheelShowDialog() end
}

--------------------------------------------------------------------------------
-- MIDI MAPPINGS
--------------------------------------------------------------------------------
renoise.tool():add_midi_mapping{
  name = "Paketti:Command Wheel Value x[Knob]",
  invoke = function(midi_message)
    if midi_message:is_abs_value() then
      local max_value = PakettiCommandWheelGetMaxValue()
      PakettiCommandWheelState.value = math.floor(midi_message.int_value * max_value / 127)
      
      if PakettiCommandWheelState.mode == PAKETTI_COMMAND_WHEEL_MODE_MACRO then
        PakettiCommandWheelApplyMacroValue()
      elseif PakettiCommandWheelState.mode == PAKETTI_COMMAND_WHEEL_MODE_DEVICE then
        PakettiCommandWheelApplyDeviceValue()
      elseif PakettiCommandWheelState.mode == PAKETTI_COMMAND_WHEEL_MODE_MIDI_CC then
        PakettiCommandWheelApplyMidiCCValue()
      end
      
      if PakettiCommandWheelState.write_on_scroll then
        PakettiCommandWheelWriteToPattern()
      end
      
      PakettiCommandWheelUpdateDisplay()
      
      local hex_value = string.format("%02X", PakettiCommandWheelState.value)
      renoise.app():show_status("Command Wheel: " .. PakettiCommandWheelGetIndexName() .. " = " .. hex_value)
    elseif midi_message:is_rel_value() then
      local delta = midi_message.int_value > 64 and (midi_message.int_value - 128) or midi_message.int_value
      PakettiCommandWheelAdjustValue(delta)
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Command Wheel Index Next x[Button]",
  invoke = function(midi_message)
    if midi_message:is_trigger() then
      PakettiCommandWheelIndexNext()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Command Wheel Index Prev x[Button]",
  invoke = function(midi_message)
    if midi_message:is_trigger() then
      PakettiCommandWheelIndexPrev()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Command Wheel Write x[Button]",
  invoke = function(midi_message)
    if midi_message:is_trigger() then
      PakettiCommandWheelWriteToPattern()
    end
  end
}
