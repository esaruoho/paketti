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

-- Sectionizer: Create sections from text input
function PakettiSectionizer()
  local vb = renoise.ViewBuilder()
  local dialog = nil
  
  local function parseSectionText(text)
    local sections = {}
    local lines = {}
    local song = renoise.song()
    local current_pattern_rows = song.selected_pattern.number_of_lines
    
    -- Split text into lines
    for line in text:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    
    for _, line in ipairs(lines) do
      local trimmed = line:match("^%s*(.-)%s*$") -- Trim whitespace
      if trimmed ~= "" then
        -- Split by commas
        local parts = {}
        for part in trimmed:gmatch("([^,]+)") do
          table.insert(parts, part:match("^%s*(.-)%s*$")) -- Trim each part
        end
        
        if #parts >= 2 then
          local section_name = parts[1]
          local pattern_count = tonumber(parts[2])
          local row_count = nil
          local pattern_name_base = nil
          
          -- Parse optional row count (3rd parameter)
          if parts[3] then
            row_count = tonumber(parts[3])
            if row_count then
              row_count = math.floor(row_count)
              row_count = math.max(1, math.min(512, row_count)) -- Clamp between 1-512
            else
              renoise.app():show_status("Invalid row count in line: " .. line)
              return nil
            end
          else
            row_count = current_pattern_rows -- Use current pattern's row count
          end
          
          -- Parse optional pattern name base (4th parameter)
          if parts[4] then
            pattern_name_base = parts[4]
          end
          
          if pattern_count and pattern_count > 0 then
            table.insert(sections, {
              name = section_name, 
              count = pattern_count, 
              rows = row_count,
              pattern_name_base = pattern_name_base
            })
          else
            renoise.app():show_status("Invalid pattern count for section: " .. section_name)
            return nil
          end
        else
          renoise.app():show_status("Invalid format in line: " .. line .. " (expected: name, count [, rows] [, pattern_name_base])")
          return nil
        end
      end
    end
    
    return sections
  end
  
  local function createSections()
    local text = vb.views.sectionizer_text.text
    local sections = parseSectionText(text)
    
    if not sections or #sections == 0 then
      renoise.app():show_status("No valid sections found")
      return
    end
    
    local song = renoise.song()
    local sequencer = song.sequencer
    local current_pos = song.selected_sequence_index -- Start from current position
    
    -- Create patterns and sections
    for section_index, section in ipairs(sections) do
      local section_start = current_pos
      
      -- Add the required number of patterns for this section
      for i = 1, section.count do
        local pattern_index
        
        if section_index == 1 and i == 1 then
          -- For the first pattern of first section, use existing pattern
          pattern_index = sequencer.pattern_sequence[current_pos]
          if not pattern_index then
            pattern_index = sequencer:insert_new_pattern_at(current_pos)
          end
        else
          -- Create new pattern and insert it into the sequence
          pattern_index = sequencer:insert_new_pattern_at(current_pos)
        end
        
        -- Set pattern row count
        song.patterns[pattern_index].number_of_lines = section.rows
        
        -- Set pattern name if specified
        if section.pattern_name_base then
          song.patterns[pattern_index].name = section.pattern_name_base .. tostring(i)
        end
        
        current_pos = current_pos + 1
      end
      
      -- Set section start flag and name at the start of this section
      sequencer:set_sequence_is_start_of_section(section_start, true)
      sequencer:set_sequence_section_name(section_start, section.name)
      
      renoise.app():show_status("Created section '" .. section.name .. "' with " .. section.count .. " patterns (" .. section.rows .. " rows each) starting at position " .. section_start)
    end
    
    renoise.app():show_status("Sectionizer complete: Created " .. #sections .. " sections")
    dialog:close()
  end
  
  local dialog_content = vb:column {
    margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
    spacing = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING,
    
    vb:text {
      text = "Enter section definitions (one per line):",
      font = "big"
    },
    
    vb:text {
      text = "Format: section_name, pattern_count [, rows] [, pattern_name_base]",
      font = "italic"
    },
    
    vb:text {
      text = "Example:",
      font = "italic"
    },
    
    vb:multiline_textfield {
      width = 400,
      height = 80,
      font = "mono",
      text = "intro, 5, 64, hello\nbridge, 2, 128, world\nchorus, 5, 256, helloyep\noutro, 10, 512, worldyep",
      style = "body",
      active = false
    },
    
    vb:space { height = 10 },
    
    vb:multiline_textfield {
      id = "sectionizer_text",
      width = 400,
      height = 200,
      font = "mono",
      text = "intro, 5, 64, hello\nbridge, 2, 128, world\nchorus, 5, 256, helloyep\noutro, 10, 512, worldyep",
      style = "border"
    },
    
    vb:space { height = 10 },
    
    vb:row {
      vb:button {
        text = "Sectionizer",
        width = 100,
        notifier = createSections
      },
      
      vb:button {
        text = "Cancel",
        width = 100,
        notifier = function()
          dialog:close()
        end
      }
    }
  }
  
  dialog = renoise.app():show_custom_dialog("Sectionizer", dialog_content, my_keyhandler_func)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
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

-- Sectionizer menu entries and keybinding
renoise.tool():add_menu_entry{name = "--Main Menu:Tools:Paketti Gadgets:Sectionizer... (⌘-OPT-S)", invoke = PakettiSectionizer}
renoise.tool():add_menu_entry{name = "--Pattern Sequencer:Paketti Gadgets:Sectionizer...", invoke = PakettiSectionizer}
renoise.tool():add_keybinding{name = "Global:Paketti:Sectionizer...", invoke = PakettiSectionizer}
---
