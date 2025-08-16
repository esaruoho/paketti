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

------------------

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





--------------
-- Write ZT (BPM) and ZL (LPB) to the master track of a specific pattern's first line
function PakettiSectionizerWriteZTandZLToPattern(pattern_index, bpm_value, lpb_value)
  local song = renoise.song()
  local master_index = get_master_track_index()

  if not master_index then
    renoise.app():show_status("Sectionizer: Could not resolve master track index")
    return
  end

  if not song.patterns[pattern_index] then
    renoise.app():show_status("Sectionizer: Invalid pattern index " .. tostring(pattern_index))
    return
  end

  if bpm_value >= 256 then
    renoise.app():show_status("Sectionizer: BPM " .. tostring(bpm_value) .. " >= 256; skipping ZT write for pattern " .. tostring(pattern_index))
    return
  end

  if lpb_value < 1 then lpb_value = 1 end
  if lpb_value > 255 then lpb_value = 255 end

  song.tracks[master_index].visible_effect_columns = 2

  local ptrack = song.patterns[pattern_index].tracks[master_index]
  local first_line = ptrack.lines[1]

  first_line.effect_columns[1].number_string = "ZT"
  first_line.effect_columns[1].amount_value  = bpm_value
  first_line.effect_columns[2].number_string = "ZL"
  first_line.effect_columns[2].amount_value  = lpb_value
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
        
        if #parts >= 3 then
          local section_name = parts[1]
          local pattern_count = tonumber(parts[2])
          local row_count = tonumber(parts[3]) or current_pattern_rows

          if not pattern_count or pattern_count <= 0 then
            renoise.app():show_status("Invalid pattern count for section: " .. section_name)
            return nil
          end

          if not row_count then
            renoise.app():show_status("Invalid pattern length (rows) in line: " .. line)
            return nil
          end

          row_count = math.floor(row_count)
          row_count = math.max(1, math.min(512, row_count))

          local lpb_value = nil
          local bpm_value = nil
          local pattern_name_base = nil

          -- Optional LPB/BPM pair. Only treat as LPB/BPM if BOTH are present and numeric.
          if parts[4] and parts[5] and tonumber(parts[4]) and tonumber(parts[5]) then
            lpb_value = tonumber(parts[4])
            bpm_value = tonumber(parts[5])
            pattern_name_base = parts[6]
          else
            -- No LPB/BPM given; do not write ZT/ZL. Optional 4th value becomes pattern name base.
            pattern_name_base = parts[4]
          end

          table.insert(sections, {
            name = section_name,
            count = pattern_count,
            rows = row_count,
            lpb = lpb_value,
            bpm = bpm_value,
            pattern_name_base = pattern_name_base
          })
        else
          renoise.app():show_status("Invalid format in line: " .. line .. " (expected: name, count, rows [, LPB, BPM] [, pattern_name_base])")
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
    local append_info = false
    if vb.views.sectionizer_append_info then
      append_info = vb.views.sectionizer_append_info.value and true or false
    end
    
    -- Create patterns and sections
    for section_index, section in ipairs(sections) do
      local section_start = current_pos
      local suffix = ""
      if append_info then
        if section.bpm and section.lpb then
          suffix = string.format(" [%d, %d&%d]", section.rows, section.lpb, section.bpm)
        else
          suffix = string.format(" [%d]", section.rows)
        end
      end
      
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
        
        -- Set/append pattern name
        local pname = song.patterns[pattern_index].name or ""
        if section.pattern_name_base then
          pname = section.pattern_name_base .. tostring(i)
        end
        if append_info and suffix ~= "" then
          pname = (pname ~= "" and pname or pname) .. suffix
        end
        if pname ~= "" then
          song.patterns[pattern_index].name = pname
        end

        -- Write BPM/LPB commands for this pattern only if both were provided
        if section.bpm and section.lpb then
          PakettiSectionizerWriteZTandZLToPattern(pattern_index, section.bpm, section.lpb)
        end
        
        current_pos = current_pos + 1
      end
      
      -- Set section start flag and name at the start of this section
      sequencer:set_sequence_is_start_of_section(section_start, true)
      if append_info and suffix ~= "" then
        sequencer:set_sequence_section_name(section_start, section.name .. suffix)
      else
        sequencer:set_sequence_section_name(section_start, section.name)
      end
      
      if section.bpm and section.lpb then
        renoise.app():show_status("Created section '" .. section.name .. "' with " .. section.count .. " patterns (" .. section.rows .. " rows each, LPB=" .. tostring(section.lpb) .. ", BPM=" .. tostring(section.bpm) .. ") starting at position " .. section_start)
      else
        renoise.app():show_status("Created section '" .. section.name .. "' with " .. section.count .. " patterns (" .. section.rows .. " rows each) starting at position " .. section_start)
      end
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
      text = "Format: section_name, pattern_count, rows [, LPB, BPM] [, pattern_name_base]",
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
      text = "intro, 5, 64, hello\nbridge, 2, 128, world\nchorus, 5, 256, 8, 120, helloyep\noutro, 10, 512, 8, 120, worldyep",
      style = "body",
      active = false
    },
    
    vb:multiline_textfield {
      id = "sectionizer_text",
      width = 400,
      height = 200,
      font = "mono",
      text = "intro, 5, 64, hello\nbridge, 2, 128, world\nchorus, 5, 256, 8, 120, helloyep\noutro, 10, 512, 8, 120, worldyep",
      style = "border"
    },
    vb:row {
      vb:checkbox { id = "sectionizer_append_info", value = false },
      vb:text { text = "Append [rows, LPB&BPM] to section and pattern names",  }
    },
    
    vb:row {
      vb:button {
        text = "Sectionizer",
        width = 100,
        notifier = createSections
      },
      vb:button {
        text = "Clear",
        width = 100,
        notifier = function()
          vb.views.sectionizer_text.text = ""
          renoise.app():show_status("Sectionizer: cleared input")
        end
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
  
  dialog = renoise.app():show_custom_dialog("Paketti Sectionizer", dialog_content, my_keyhandler_func)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Clear all Pattern Names: sets every pattern's name to an empty string
function PakettiPatternNamesClearAll()
  local song = renoise.song()
  local cleared = 0
  local total = #song.patterns

  for idx, pat in ipairs(song.patterns) do
    if pat.name ~= nil and pat.name ~= "" then
      pat.name = ""
      cleared = cleared + 1
    end
  end

  if cleared > 0 then
    renoise.app():show_status(string.format("Cleared %d/%d pattern names", cleared, total))
  else
    renoise.app():show_status("No pattern names to clear")
  end
end


-- Sectionizer menu entries and keybinding
renoise.tool():add_menu_entry{name = "--Main Menu:Tools:Paketti Gadgets:Sectionizer... (⌘-OPT-S)", invoke = PakettiSectionizer}
renoise.tool():add_menu_entry{name = "--Pattern Sequencer:Paketti Gadgets:Sectionizer...", invoke = PakettiSectionizer}
renoise.tool():add_keybinding{name = "Global:Paketti:Sectionizer...", invoke = PakettiSectionizer}


renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Patterns:Clear all Pattern Names", invoke = PakettiPatternNamesClearAll}
renoise.tool():add_menu_entry{name = "--Pattern Sequencer:Paketti:Clear all Pattern Names", invoke = PakettiPatternNamesClearAll}
renoise.tool():add_menu_entry{name = "--Pattern Matrix:Paketti:Pattern Tools:Clear all Pattern Names", invoke = PakettiPatternNamesClearAll}
renoise.tool():add_menu_entry{name = "--Pattern Editor:Paketti:Pattern Tools:Clear all Pattern Names", invoke = PakettiPatternNamesClearAll}
renoise.tool():add_keybinding{name = "Global:Paketti:Clear all Pattern Names", invoke = PakettiPatternNamesClearAll}
---

--[[

local vb = renoise.ViewBuilder()
local dialog = nil

-- Parameters for the wacky filter
local filter_params={chaos=0.5,cutoff=2000,resonance=0.7}

-- Function to export, process, and reimport audio
local function process_audio()
  local song=renoise.song()
  local selection = song.selection_in_pattern
  if not selection then
    renoise.app():show_status("No audio selection found")
    return
  end

  -- Export selected audio to a WAV file
  local sample = song.instruments[1].samples[1]
  local output_path = os.tmpname() .. ".wav"
  sample.sample_buffer:save_as(output_path, "wav")

  -- Run Csound with the wacky filter
  local csound_command = string.format(
    "csound wacky_filter.csd -o %s -i %s -kcutoff %f -kresonance %f -kchaos %f",
    output_path,
    output_path,
    filter_params.cutoff,
    filter_params.resonance,
    filter_params.chaos
  )
  os.execute(csound_command)

  -- Load processed file back into Renoise
  sample.sample_buffer:load_from(output_path)
  renoise.app():show_status("Audio processed and reloaded")
end

-- Create GUI
local function show_dialog()
  if dialog and dialog.visible then
    dialog:close()
    return
  end

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Wacky Filter", vb:row{
    vb:column{
      vb:slider{ min = 0, max = 1, value = filter_params.chaos, notifier=function(v) filter_params.chaos = v end},
      vb:text{text="Chaos" },
      vb:slider{ min = 20, max = 20000, value = filter_params.cutoff, notifier=function(v) filter_params.cutoff = v end},
      vb:text{text="Cutoff" },
      vb:slider{ min = 0.1, max = 10, value = filter_params.resonance, notifier=function(v) filter_params.resonance = v end},
      vb:text{text="Resonance" },
      vb:button{ text="Process Audio", notifier = process_audio }
    }
  }, keyhandler)
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Xperimental/WIP:Wacky Filter",invoke=show_dialog}
]]--