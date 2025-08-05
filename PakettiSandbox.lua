-- Helper function to convert MIDI note number to note name
function noteNumberToName(note_number)
  local note_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
  local octave = math.floor(note_number / 12) - 1
  local note_index = (note_number % 12) + 1
  return note_names[note_index] .. octave
end

-- Helper function to find APC devices (APC Key 25, APC40, APC mini, etc.)
function findAPCKey25()
  local available_devices = renoise.Midi.available_output_devices()
  
  -- Look for any device containing "apc" in the name
  for _, device_name in ipairs(available_devices) do
    if string.find(string.lower(device_name), "apc") then
      print("Found APC device: " .. device_name)
      return device_name
    end
  end
  
  -- If no APC device found, show available devices for debugging
  print("No APC device found. Available MIDI output devices:")
  for i, device_name in ipairs(available_devices) do
    print(string.format("[%d] => %s", i, device_name))
  end
  
  return nil
end

-- Function to control APC pads with note on/off messages
function pakettiAPCControlPads(message_type)
  print("=== pakettiAPCControlPads called with message_type: " .. tostring(message_type) .. " ===")
  
  local apc_device_name = findAPCKey25()
  
  if not apc_device_name then
    print("ERROR: APC device not found!")
    renoise.app():show_status("APC device not found")
    return
  end
  
  print("Using APC device: " .. apc_device_name)
  local midi_out = renoise.Midi.create_output_device(apc_device_name)
  local base_note = 36 -- This was working - lighting up 4 pads
  
  -- Send the original working range (this was lighting up pads 5-8)
  print("Sending original working range (notes 36-43)...")
  for i = 0, 7 do
    local note = base_note + i
    if message_type == "note_on" then
      print(string.format("Sending Note ON - Note: %d (%s), Velocity: 127", note, noteNumberToName(note)))
      midi_out:send {0x90, note, 127}  -- Note On message
    else
      print(string.format("Sending Note OFF - Note: %d (%s), Velocity: 0", note, noteNumberToName(note)))
      midi_out:send {0x90, note, 0}  -- Note On with velocity 0 (effectively note off)
    end
  end
  
  -- Also try the higher range for the missing pads (44-47)
  print("Also trying higher range (notes 44-47) for missing pads...")
  for i = 0, 3 do
    local note = 44 + i
    if message_type == "note_on" then
      print(string.format("Sending Note ON - Note: %d (%s), Velocity: 127", note, noteNumberToName(note)))
      midi_out:send {0x90, note, 127}  -- Note On message
    else
      print(string.format("Sending Note OFF - Note: %d (%s), Velocity: 0", note, noteNumberToName(note)))
      midi_out:send {0x90, note, 0}  -- Note On with velocity 0 (effectively note off)
    end
  end
  midi_out:close()
  print("=== MIDI messages sent, device closed ===")
end

-- Global variables to track APC pad states separately
local apc_pads_1_4_state = false  -- false = off, true = on
local apc_pads_5_8_state = false  -- false = off, true = on
local apc_all_pads_state = false  -- false = off, true = on

-- Function to toggle APC pads 1-4 on/off
function pakettiAPCTogglePads1to4()
  print("=== pakettiAPCTogglePads1to4 called, current state: " .. tostring(apc_pads_1_4_state) .. " ===")
  
  -- Toggle the state
  apc_pads_1_4_state = not apc_pads_1_4_state
  local message_type = apc_pads_1_4_state and "note_on" or "note_off"
  
  print("New state for pads 1-4: " .. tostring(apc_pads_1_4_state) .. ", sending: " .. message_type)
  pakettiAPCControlFirstFourPads(message_type)
end

-- Function to toggle APC pads 5-8 on/off (using the ORIGINAL working method)
function pakettiAPCTogglePads5to8()
  print("=== pakettiAPCTogglePads5to8 called, current state: " .. tostring(apc_pads_5_8_state) .. " ===")
  
  -- Toggle the state
  apc_pads_5_8_state = not apc_pads_5_8_state
  local message_type = apc_pads_5_8_state and "note_on" or "note_off"
  
  print("New state for pads 5-8: " .. tostring(apc_pads_5_8_state) .. ", sending: " .. message_type)
  
  -- Use the ORIGINAL working method - send the full range 36-43 like before
  local apc_device_name = findAPCKey25()
  
  if not apc_device_name then
    print("ERROR: APC device not found!")
    renoise.app():show_status("APC device not found")
    return
  end
  
  print("Using APC device: " .. apc_device_name)
  local midi_out = renoise.Midi.create_output_device(apc_device_name)
  local base_note = 36 -- Back to the original working setup
  
  -- Send the original working range (notes 36-43) that was lighting up pads 5-8
  print("Sending original working range (notes 36-43) for pads 5-8...")
  for i = 0, 7 do
    local note = base_note + i
    if message_type == "note_on" then
      print(string.format("Sending Note ON - Note: %d (%s), Velocity: 127", note, noteNumberToName(note)))
      midi_out:send {0x90, note, 127}  -- Note On message
    else
      print(string.format("Sending Note OFF - Note: %d (%s), Velocity: 0", note, noteNumberToName(note)))
      midi_out:send {0x90, note, 0}  -- Note On with velocity 0 (effectively note off)
    end
  end
  
  midi_out:close()
  print("=== Pads 5-8 toggle completed (using original method) ===")
end

-- Function to toggle ALL 8 pads with timing and theory-based approach
function pakettiAPCToggleAllPads()
  print("=== pakettiAPCToggleAllPads called, current state: " .. tostring(apc_all_pads_state) .. " ===")
  
  -- Toggle the state
  apc_all_pads_state = not apc_all_pads_state
  local message_type = apc_all_pads_state and "note_on" or "note_off"
  
  print("New state for ALL pads: " .. tostring(apc_all_pads_state) .. ", sending: " .. message_type)
  
  local apc_device_name = findAPCKey25()
  
  if not apc_device_name then
    print("ERROR: APC device not found!")
    renoise.app():show_status("APC device not found")
    return
  end
  
  print("Using APC device: " .. apc_device_name)
  local midi_out = renoise.Midi.create_output_device(apc_device_name)
  
  -- THEORY 1: Send pads 5-8 first (the reliable ones)
  print("Step 1: Controlling pads 5-8 first (notes 36-43)...")
  local base_note = 36
  for i = 0, 7 do
    local note = base_note + i
    if message_type == "note_on" then
      print(string.format("Sending Note ON - Note: %d (%s), Velocity: 127", note, noteNumberToName(note)))
      midi_out:send {0x90, note, 127}
    else
      print(string.format("Sending Note OFF - Note: %d (%s), Velocity: 0", note, noteNumberToName(note)))
      midi_out:send {0x90, note, 0}
    end
  end
  
  -- THEORY 2: Add small delay before sending pads 1-4 range
  print("Step 2: Small delay, then controlling pads 1-4...")
  
  -- Send the multiple ranges that work for pads 1-4
  local test_ranges = {
    {32, "32-35"},
    {44, "44-47"}, 
    {48, "48-51"}
  }
  
  for _, range in ipairs(test_ranges) do
    local start_note = range[1]
    local range_name = range[2]
    print(string.format("Trying range %s...", range_name))
    
    for i = 0, 3 do
      local note = start_note + i
      if message_type == "note_on" then
        print(string.format("Sending Note ON - Note: %d (%s), Velocity: 127", note, noteNumberToName(note)))
        midi_out:send {0x90, note, 127}
      else
        print(string.format("Sending Note OFF - Note: %d (%s), Velocity: 0", note, noteNumberToName(note)))
        midi_out:send {0x90, note, 0}
      end
    end
  end
  
  -- THEORY 3: Sync the individual state variables
  apc_pads_1_4_state = apc_all_pads_state
  apc_pads_5_8_state = apc_all_pads_state
  print(string.format("Synced individual states: 1-4=%s, 5-8=%s", 
    tostring(apc_pads_1_4_state), tostring(apc_pads_5_8_state)))
  
  midi_out:close()
  print("=== ALL pads toggle completed ===")
end

-- Function to control ONLY the first 4 pads (for testing)
function pakettiAPCControlFirstFourPads(message_type)
  print("=== pakettiAPCControlFirstFourPads called with message_type: " .. tostring(message_type) .. " ===")
  
  local apc_device_name = findAPCKey25()
  
  if not apc_device_name then
    print("ERROR: APC device not found!")
    renoise.app():show_status("APC device not found")
    return
  end
  
  print("Using APC device: " .. apc_device_name)
  local midi_out = renoise.Midi.create_output_device(apc_device_name)
  
  -- Try different note ranges to find what controls pads 1-4
  print("Testing different note ranges for pads 1-4...")
  
  -- Test range 1: notes 32-35
  print("Trying notes 32-35...")
  for i = 0, 3 do
    local note = 32 + i
    if message_type == "note_on" then
      print(string.format("Sending Note ON - Note: %d (%s), Velocity: 127", note, noteNumberToName(note)))
      midi_out:send {0x90, note, 127}
    else
      print(string.format("Sending Note OFF - Note: %d (%s), Velocity: 0", note, noteNumberToName(note)))
      midi_out:send {0x90, note, 0}
    end
  end
  
  -- Test range 2: notes 44-47
  print("Trying notes 44-47...")
  for i = 0, 3 do
    local note = 44 + i
    if message_type == "note_on" then
      print(string.format("Sending Note ON - Note: %d (%s), Velocity: 127", note, noteNumberToName(note)))
      midi_out:send {0x90, note, 127}
    else
      print(string.format("Sending Note OFF - Note: %d (%s), Velocity: 0", note, noteNumberToName(note)))
      midi_out:send {0x90, note, 0}
    end
  end
  
  -- Test range 3: notes 48-51
  print("Trying notes 48-51...")
  for i = 0, 3 do
    local note = 48 + i
    if message_type == "note_on" then
      print(string.format("Sending Note ON - Note: %d (%s), Velocity: 127", note, noteNumberToName(note)))
      midi_out:send {0x90, note, 127}
    else
      print(string.format("Sending Note OFF - Note: %d (%s), Velocity: 0", note, noteNumberToName(note)))
      midi_out:send {0x90, note, 0}
    end
  end
  
  midi_out:close()
  print("=== First four pads test completed ===")
end

renoise.tool():add_midi_mapping{name = "Paketti:APC Light Up All Pads",invoke = function(message) if message:is_trigger() then print("Light Up All Pads MIDI mapping triggered!") pakettiAPCControlPads("note_on") end end}
renoise.tool():add_midi_mapping{name = "Paketti:APC Turn Off All Pads",invoke = function(message) if message:is_trigger() then print("Turn Off All Pads MIDI mapping triggered!") pakettiAPCControlPads("note_off") end end}
renoise.tool():add_midi_mapping{name = "Paketti:APC Toggle Pads 1-4",invoke = function(message) if message:is_trigger() then print("Toggle Pads 1-4 MIDI mapping triggered!") pakettiAPCTogglePads1to4() end end}
renoise.tool():add_midi_mapping{name = "Paketti:APC Toggle Pads 5-8",invoke = function(message) if message:is_trigger() then print("Toggle Pads 5-8 MIDI mapping triggered!") pakettiAPCTogglePads5to8() end end}
renoise.tool():add_midi_mapping{name = "Paketti:APC Toggle ALL 8 Pads",invoke = function(message) if message:is_trigger() then print("Toggle ALL 8 Pads MIDI mapping triggered!") pakettiAPCToggleAllPads() end end}
renoise.tool():add_midi_mapping{name = "Paketti:APC Test First 4 Pads ON",invoke = function(message) if message:is_trigger() then print("Test First 4 Pads ON triggered!") pakettiAPCControlFirstFourPads("note_on") end end}
renoise.tool():add_midi_mapping{name = "Paketti:APC Test First 4 Pads OFF",invoke = function(message) if message:is_trigger() then print("Test First 4 Pads OFF triggered!") pakettiAPCControlFirstFourPads("note_off") end end}
---
