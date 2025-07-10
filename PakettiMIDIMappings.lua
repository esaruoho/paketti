-- Define the mapping between menu names and their corresponding identifiers
local menu_to_identifier = {
    ["Track Automation"] = "Automation",
    ["Sample Mappings"] = "Sample Keyzones"
  }

-- Global table of all Lua scripts for MIDI mapping discovery
local PakettiLUAScriptsTableForMidi = {
  "Paketti35.lua",
  "PakettiAudioProcessing.lua",
  "PakettiAutomation.lua",
  "PakettiChordsPlus.lua",
  "PakettiControls.lua",
  "PakettiDynamicViews.lua",
  "PakettiEightOneTwenty.lua",
  "PakettiExperimental_Verify.lua",
  "PakettiGater.lua",
  "PakettiGlobalGrooveToDelayValues.lua",
  "PakettiImpulseTracker.lua",
  "PakettiInstrumentBox.lua",
  "PakettiKeyBindings.lua",
  "PakettiKeyzoneDistributor.lua",
  "PakettiLaunchApp.lua",
  "PakettiLoadDevices.lua",
  "PakettiLoaders.lua",
  "PakettiLoadPlugins.lua",
  "PakettiMidi.lua",
  "PakettiOctaMEDSuite.lua",
  "PakettiPatternEditor.lua",
  "PakettiPatternLength.lua",
  "PakettiPatternMatrix.lua",
  "PakettiPatternSequencer.lua",
  "PakettiPhraseEditor.lua",
  "PakettiPlayerProSuite.lua",
  "PakettiProcess.lua",
  "PakettiRecorder.lua",
  "PakettiRequests.lua",
  "PakettiSamples.lua",
  "PakettiSteppers.lua",
  "PakettiSubColumnModifier.lua",
  "PakettiTkna.lua",
  "PakettiWavetabler.lua"
}

-- Define the original table of all MIDI mappings
local PakettiMidiMappings = {
  "Paketti:Cycle Sample Editor Tabs",
  "Paketti:Toggle Mute Tracks",
  "Paketti:Shift Sample Buffer Up x[Trigger]",
  "Paketti:Shift Sample Buffer Down x[Trigger]",
  "Paketti:Shift Sample Buffer Up x[Knob]",
  "Paketti:Shift Sample Buffer Down x[Knob]",
  "Paketti:Shift Sample Buffer Up/Down x[Knob]",
  "Paketti:Toggle Solo Tracks",
  "Paketti:Slide Selected Column Content Down",
  "Paketti:Slide Selected Column Content Up",
  "Paketti:Slide Selected Track Content Up",
  "Paketti:Slide Selected Track Content Down",
  "Paketti:Rotate Sample Buffer Content Forward [Set]",
  "Paketti:Rotate Sample Buffer Content Backward [Set]",
  "Paketti:Move to Next Track (Wrap) [Knob]",
  "Paketti:Move to Previous Track (Wrap) [Knob]",
  "Paketti:Move to Next Track [Knob]",
  "Paketti:Move to Previous Track [Knob]",
  "Track Devices:Paketti:Load DC Offset",
  "Paketti:Hide Track DSP Device External Editors for All Tracks",
  "Paketti:Set Beatsync Value x[Knob]",
  "Paketti:Groove Settings Groove #1 x[Knob]",
  "Paketti:Groove Settings Groove #2 x[Knob]",
  "Paketti:Groove Settings Groove #3 x[Knob]",
  "Paketti:Groove Settings Groove #4 x[Knob]",
  "Paketti:Computer Keyboard Velocity Slider x[Knob]",
  "Paketti:Change Selected Sample Volume x[Slider]",
  "Paketti:Delay Column (DEPRECATED) x[Slider]",
  "Paketti:Metronome On/Off x[Toggle]",
  "Paketti:Uncollapser",
  "Paketti:Collapser",
  "Paketti:Show/Hide Pattern Matrix x[Toggle]",
  "Paketti:Record and Follow x[Toggle]",
  "Paketti:Record and Follow On/Off x[Knob]",
  "Paketti:Record Quantize On/Off x[Toggle]",
  "Paketti:Impulse Tracker F5 Start Playback x[Toggle]",
  "Paketti:Impulse Tracker F8 Stop Playback (Panic) x[Toggle]",
  "Paketti:Impulse Tracker F7 Start Playback from Cursor Row x[Toggle]",
  "Paketti:Stop Playback (Panic) x[Toggle]",
  "Paketti:Play Current Line & Advance by EditStep x[Toggle]",
  "Paketti:Impulse Tracker Pattern (Next) x[Toggle]",
  "Paketti:Impulse Tracker Pattern (Previous) x[Toggle]",
  "Paketti:Switch to Automation",
  "Paketti:Save Sample Range .WAV",
  "Paketti:Save Sample Range .FLAC",
  "Paketti:Wipe&Slice (004) x[Toggle]",
  "Paketti:Wipe&Slice (008) x[Toggle]",
  "Paketti:Wipe&Slice (016) x[Toggle]",
  "Paketti:Wipe&Slice (032) x[Toggle]",
  "Paketti:Wipe&Slice (064) x[Toggle]",
  "Paketti:Wipe&Slice (128) x[Toggle]",
  "Paketti:Set Delay (+1) x[Toggle]",
  "Paketti:Set Delay (-1) x[Toggle]",
  "Paketti:Numpad SelectPlay 0 x[Toggle]",
  "Paketti:Numpad SelectPlay 1 x[Toggle]",
  "Paketti:Numpad SelectPlay 2 x[Toggle]",
  "Paketti:Numpad SelectPlay 3 x[Toggle]",
  "Paketti:Numpad SelectPlay 4 x[Toggle]",
  "Paketti:Numpad SelectPlay 5 x[Toggle]",
  "Paketti:Numpad SelectPlay 6 x[Toggle]",
  "Paketti:Numpad SelectPlay 7 x[Toggle]",
  "Paketti:Numpad SelectPlay 8 x[Toggle]",
  "Paketti:Capture Nearest Instrument and Octave",
  "Paketti:Simple Play",
  "Paketti:Columnizer Delay Increase (+1) x[Toggle]",
  "Paketti:Columnizer Delay Decrease (-1) x[Toggle]",
  "Paketti:Columnizer Panning Increase (+1) x[Toggle]",
  "Paketti:Columnizer Panning Decrease (-1) x[Toggle]",
  "Paketti:Columnizer Volume Increase (+1) x[Toggle]",
  "Paketti:Columnizer Volume Decrease (-1) x[Toggle]",
  "Paketti:Columnizer Effect Number Increase (+1) x[Toggle]",
  "Paketti:Columnizer Effect Number Decrease (-1) x[Toggle]",
  "Paketti:Columnizer Effect Amount Increase (+1) x[Toggle]",
  "Paketti:Columnizer Effect Amount Decrease (-1) x[Toggle]",
  "Sample Editor:Paketti:Disk Browser Focus",
  "Pattern Editor:Paketti:Disk Browser Focus",
  "Paketti:Change Selected Sample Loop Mode x[Knob]",
  "Paketti:Selected Sample Loop to 1 No Loop x[On]",
  "Paketti:Selected Sample Loop to 2 Forward x[On]",
  "Paketti:Selected Sample Loop to 3 Backward x[On]",
  "Paketti:Selected Sample Loop to 4 PingPong x[On]",
  "Paketti:Selected Sample Loop to 1 No Loop x[Toggle]",
  "Paketti:Selected Sample Loop to 2 Forward x[Toggle]",
  "Paketti:Selected Sample Loop to 3 Backward x[Toggle]",
  "Paketti:Selected Sample Loop to 4 PingPong x[Toggle]",
  "Paketti:Record to Current Track x[Toggle]",
  "Paketti:Simple Play Record Follow",
  "Paketti:Midi Change EditStep 1-64 x[Knob]",
  "Paketti:Midi Select Group (Previous)",
  "Paketti:Midi Select Group (Next)",
  "Paketti:Midi Select Track (Previous)",
  "Paketti:Midi Select Track (Next)",
  "Paketti:Midi Select Group Tracks x[Knob]",
  "Paketti:Midi Change Octave x[Knob]",
  "Paketti:Midi Change Selected Track x[Knob]",
  "Paketti:Midi Change Selected Track DSP Device x[Knob]",
  "Paketti:Midi Change Selected Instrument x[Knob]",
  "Paketti:Midi Change Selected Sample Loop 01 Start x[Knob]",
  "Paketti:Midi Change Selected Sample Loop 02 End x[Knob]",
  "Sample Editor:Paketti:Sample Buffer Selection 01 Start x[Knob]",
  "Sample Editor:Paketti:Sample Buffer Selection 02 End x[Knob]",
  "Track Automation:Paketti:Midi Automation Curve Draw Selection x[Knob]",
  "Paketti:Midi Automation Selection 01 Start x[Knob]",
  "Paketti:Midi Automation Selection 02 End x[Knob]",
  "Paketti:Create New Instrument & Loop from Selection",
  "Paketti:Midi Change Sample Modulation Set Filter",
  "Paketti:Selected Instrument Midi Program +1 (Next)",
  "Paketti:Selected Instrument Midi Program -1 (Previous)",
  "Paketti:Midi Change 01 Volume Column Value x[Knob]",
  "Paketti:Midi Change 02 Panning Column Value x[Knob]",
  "Paketti:Midi Change 03 Delay Column Value x[Knob]",
  "Paketti:Midi Change 04 Effect Column Value x[Knob]",
  "Paketti:EditStep Double x[Button]",
  "Paketti:EditStep Halve x[Button]",
  "Paketti:Set Pattern Length to 001",
  "Paketti:Set Pattern Length to 004",
  "Paketti:Set Pattern Length to 008",
  "Paketti:Set Pattern Length to 016",
  "Paketti:Set Pattern Length to 032",
  "Paketti:Set Pattern Length to 048",
  "Paketti:Set Pattern Length to 064",
  "Paketti:Set Pattern Length to 096",
  "Paketti:Set Pattern Length to 128",
  "Paketti:Set Pattern Length to 192",
  "Paketti:Set Pattern Length to 256",
  "Paketti:Set Pattern Length to 384",
  "Paketti:Set Pattern Length to 512",
  "Paketti:Effect Column B00 Reverse Sample Effect On/Off",
  "Paketti:Toggle Edit Mode and Tint Track",
  "Paketti:Duplicate Effect Column Content to Pattern or Selection",
  "Paketti:Randomize Effect Column Parameters",
  "Paketti:Flood Fill Note and Instrument",
  "Paketti:Flood Fill Note and Instrument with EditStep",
  "Paketti:Paketti Track Renamer",
  "Paketti:Clone Current Sequence",
  "Sample Editor:Paketti:Sample Buffer Selection Halve",
  "Sample Editor:Paketti:Sample Buffer Selection Double",
  "Pattern Editor:Paketti:Adjust Selection ",
  "Pattern Editor:Paketti:Wipe Selection ",
  "Sample Editor:Paketti:Mono to Right with Blank Left",
  "Sample Editor:Paketti:Mono to Left with Blank Right",
  "Sample Editor:Paketti:Convert Mono to Stereo",
  "Paketti:Note Interpolation",
  "Paketti:Jump to First Track in Next Group",
  "Paketti:Jump to First Track in Previous Group",
  "Paketti:Bypass All Other Track DSP Devices (Toggle)",
  "Paketti:Isolate Slices or Samples to New Instruments",
  "Paketti:Octave Basenote Up",
  "Paketti:Octave Basenote Down",
  "Paketti:Midi Paketti PitchBend Drumkit Sample Loader",
  "Paketti:Midi Paketti PitchBend Multiple Sample Loader",
  "Paketti:Midi Paketti Save Selected Sample .WAV",
  "Paketti:Midi Paketti Save Selected Sample .FLAC",
  "Paketti:Midi Select Padded Slice (Next)",
  "Paketti:Midi Select Padded Slice (Previous)",
  "Paketti:Duplicate and Reverse Instrument [Trigger]",
  "Paketti:Strip Silence",
  "Paketti:Move Beginning Silence to End",
  "Paketti:Continue Sequence From Same Line [Set Sequence]",
  "Paketti:Set Current Section as Scheduled Sequence",
  "Paketti:Add Current Section to Scheduled Sequences",
  "Paketti:Section Loop (Next)",
  "Paketti:Section Loop (Previous)",
  "Paketti:Sequence Selection (Next)",
  "Paketti:Sequence Selection (Previous)",
  "Paketti:Sequence Loop Selection (Next)",
  "Paketti:Sequence Loop Selection (Previous)",
  "Paketti:Set Section Loop and Schedule Section [Knob]",
}

  

-- Function to dynamically discover all MIDI mappings in the tool
function get_active_midi_mappings()
  -- Table to store discovered midi mappings
  local discovered_mappings = {}
  local active_mappings = {}

  -- Function to read a file and extract midi mappings
  local function read_file_and_extract_midi_mappings(file)
    local f = io.open(file, "r")
    if f then
      for line in f:lines() do
        -- Match lines that contain "renoise.tool():add_midi_mapping"
        local mapping = line:match('renoise.tool%(%):add_midi_mapping{name="([^"]+)"')
        if mapping then
          table.insert(discovered_mappings, mapping)
        end
      end
      f:close()
    else
      print("Could not open file: " .. file)
    end
  end

  -- Iterate through each required file and extract midi mappings
  for _, file in ipairs(PakettiLUAScriptsTableForMidi) do
    read_file_and_extract_midi_mappings(file)
  end

  -- Now check which discovered mappings actually exist in the tool
  for _, mapping in ipairs(discovered_mappings) do
    if renoise.tool():has_midi_mapping(mapping) then
      table.insert(active_mappings, mapping)
      print("ACTIVE: " .. mapping)
    else
      print("NOT FOUND: " .. mapping)
    end
  end

  -- ENHANCED: Also discover dynamic mappings by checking all registered mappings
  print("\n=== DISCOVERING DYNAMIC MAPPINGS ===")
  local all_tool_mappings = {}
  
  -- Get all MIDI mappings that are actually registered in the tool
  -- We'll use a different approach: iterate through known dynamic patterns
  local dynamic_patterns = {
    -- PakettiLaunchApp.lua patterns
    {pattern = "Paketti:Send Selected Sample to AppSelection %d", range = {1, 6}},
    {pattern = "Paketti:Save Sample to Smart/Backup Folder %d", range = {1, 3}},
    {pattern = "Paketti:Save All Samples to Smart/Backup Folder %d", range = {1, 3}},
    
    -- PakettiRequests.lua patterns  
    {pattern = "Paketti:Midi Set Selected Track Output Routing %02d", range = {0, 63}},
    {pattern = "Paketti:Midi Set Master Track Output Routing %02d", range = {0, 63}},
    
    -- PakettiSamples.lua patterns
    {pattern = "Paketti:Midi Change Slice %02d", range = {1, 32}},
    
    -- PakettiControls.lua patterns (these are harder to detect due to device_name variable)
    -- We'll skip these for now as they require runtime device enumeration
    
    -- PakettiEightOneTwenty.lua patterns
    {pattern = "Paketti:Paketti Groovebox 8120:Global Step %d", range = {1, 16}},
    {pattern = "Paketti:Paketti Groovebox 8120:Row%d Step%d", nested_range = {{1, 8}, {1, 16}}},
  }
  
  -- Check dynamic patterns
  for _, pattern_info in ipairs(dynamic_patterns) do
    if pattern_info.nested_range then
      -- Handle nested patterns (like Row%d Step%d)
      for i = pattern_info.nested_range[1][1], pattern_info.nested_range[1][2] do
        for j = pattern_info.nested_range[2][1], pattern_info.nested_range[2][2] do
          local mapping_name = string.format(pattern_info.pattern, i, j)
          if renoise.tool():has_midi_mapping(mapping_name) then
            table.insert(active_mappings, mapping_name)
            print("DYNAMIC FOUND: " .. mapping_name)
          end
        end
      end
    elseif pattern_info.range then
      -- Handle single-variable patterns
      for i = pattern_info.range[1], pattern_info.range[2] do
        local mapping_name = string.format(pattern_info.pattern, i)
        if renoise.tool():has_midi_mapping(mapping_name) then
          table.insert(active_mappings, mapping_name)
          print("DYNAMIC FOUND: " .. mapping_name)
        end
      end
    end
  end
  
  -- Additional EightOneTwenty button patterns
  local buttons = {"<", ">", "Clear", "Randomize", "Browse", "Show", "Random", "Automation", "Reverse"}
  for row = 1, 8 do
    for _, btn in ipairs(buttons) do
      local mapping_name = string.format("Paketti:Paketti Groovebox 8120:Row%d %s", row, btn)
      if renoise.tool():has_midi_mapping(mapping_name) then
        table.insert(active_mappings, mapping_name)
        print("DYNAMIC FOUND: " .. mapping_name)
      end
    end
    
    -- Sample slider mappings
    local slider_mapping = string.format("Paketti:Paketti Groovebox 8120:Row%d Sample Slider", row)
    if renoise.tool():has_midi_mapping(slider_mapping) then
      table.insert(active_mappings, slider_mapping)
      print("DYNAMIC FOUND: " .. slider_mapping)
    end
  end

  print(string.format("Found %d mappings in source files, %d are active in tool (including dynamic)", 
    #discovered_mappings, #active_mappings))

  return active_mappings, discovered_mappings
end

-- Function to extract and print MIDI mappings from required files
function extract_midi_mappings()
  -- Table to store extracted midi mappings
  local midi_mappings = {}

  -- Function to read a file and extract midi mappings
  local function read_file_and_extract_midi_mappings(file)
    local f = io.open(file, "r")
    if f then
      for line in f:lines() do
        -- Match lines that contain "renoise.tool():add_midi_mapping"
        local mapping = line:match('renoise.tool%(%):add_midi_mapping{name="([^"]+)"')
        if mapping then
          table.insert(midi_mappings, mapping)
        end
      end
      f:close()
    else
      print("Could not open file: " .. file)
    end
  end

  -- Iterate through each required file and extract midi mappings
  for _, file in ipairs(PakettiLUAScriptsTableForMidi) do
    read_file_and_extract_midi_mappings(file)
  end

  -- Print the midi mappings in a format ready for pasting into the list
  print("\nPasteable Midi Mappings:\n")
  for _, mapping in ipairs(midi_mappings) do
    print('  "' .. mapping .. '",')
  end
end

-- Function to check specific mappings from a list
function verify_midi_mappings_from_list(mapping_list)
  local active_mappings = {}
  local inactive_mappings = {}
  
  for _, mapping in ipairs(mapping_list) do
    if renoise.tool():has_midi_mapping(mapping) then
      table.insert(active_mappings, mapping)
    else
      table.insert(inactive_mappings, mapping)
    end
  end
  
  return active_mappings, inactive_mappings
end

-- Function to print all active MIDI mappings
function print_active_midi_mappings()
  local active, discovered = get_active_midi_mappings()
  
  print("\n=== ACTIVE MIDI MAPPINGS ===")
  for i, mapping in ipairs(active) do
    print(string.format("%03d: %s", i, mapping))
  end
  
  print(string.format("\nTotal: %d active MIDI mappings", #active))
  return active
end

-- Function to generate and update PakettiMidiMappings with discovered mappings
function update_paketti_midi_mappings()
  local active, discovered = get_active_midi_mappings()
  local complex_mappings = detect_complex_dynamic_mappings()
  
  -- Combine regular active mappings with complex dynamic mappings
  for _, mapping in ipairs(complex_mappings) do
    table.insert(active, mapping)
  end
  
  -- Update the global PakettiMidiMappings with discovered active mappings
  PakettiMidiMappings = active
  
  print("\n=== UPDATED PAKETTI MIDI MAPPINGS ===")
  print("PakettiMidiMappings table updated with " .. #active .. " active mappings (including dynamic)")
  
  return active
end

-- Initialize with discovered mappings
local PakettiMidiMappings = {}

-- Example grouped structure - will be populated dynamically
local grouped_mappings = {
  ["Discovered Mappings"] = {}
}

-- Variable to store the dialog reference
local PakettiMidiMappingDialog = nil

-- Add persistent settings to preferences
if not preferences.PakettiMidiMappingsDialog then
  preferences.PakettiMidiMappingsDialog = {
    category_filter_value = renoise.Document.ObservableNumber(1),
    alphabet_filter_value = renoise.Document.ObservableNumber(1),
    items_per_page_value = renoise.Document.ObservableNumber(5), -- 125 items (index 5 in the array)
    rows_per_column_value = renoise.Document.ObservableNumber(6), -- 35 rows (index 6 in the array)
    edit_mode_value = renoise.Document.ObservableNumber(1),
    last_assigned_category = renoise.Document.ObservableString("Uncategorized")
  }
end

-- Variables to preserve dialog state across rebuilds - load from preferences
local dialog_state = {
  category_filter_value = preferences.PakettiMidiMappingsDialog.category_filter_value.value,
  alphabet_filter_value = preferences.PakettiMidiMappingsDialog.alphabet_filter_value.value,
  items_per_page_value = preferences.PakettiMidiMappingsDialog.items_per_page_value.value,
  rows_per_column_value = preferences.PakettiMidiMappingsDialog.rows_per_column_value.value,
  edit_mode_value = preferences.PakettiMidiMappingsDialog.edit_mode_value.value,
  last_assigned_category = preferences.PakettiMidiMappingsDialog.last_assigned_category.value
}

-- Function to save dialog state to preferences
local function save_dialog_state()
  preferences.PakettiMidiMappingsDialog.category_filter_value.value = dialog_state.category_filter_value
  preferences.PakettiMidiMappingsDialog.alphabet_filter_value.value = dialog_state.alphabet_filter_value
  preferences.PakettiMidiMappingsDialog.items_per_page_value.value = dialog_state.items_per_page_value
  preferences.PakettiMidiMappingsDialog.rows_per_column_value.value = dialog_state.rows_per_column_value
  preferences.PakettiMidiMappingsDialog.edit_mode_value.value = dialog_state.edit_mode_value
  preferences.PakettiMidiMappingsDialog.last_assigned_category.value = dialog_state.last_assigned_category
  preferences:save_as("preferences.xml")
end

-- Function to handle key events
function my_MidiMappingkeyhandler_func(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    PakettiMidiMappingDialog = nil
    return nil
  else
    return key
  end
end


-- Function to generate and print Paketti MIDI Mappings to console
function generate_paketti_midi_mappings()
    local active_mappings = update_paketti_midi_mappings()
    
    print("=== PAKETTI MIDI MAPPINGS (DISCOVERED + DYNAMIC) ===")
    for i, mapping in ipairs(active_mappings) do
      print(string.format("%03d: %s", i, mapping))
    end
    print(string.format("\nTotal: %d MIDI mappings discovered (including dynamic patterns)", #active_mappings))
  end
  
  -- Function to show category statistics
  function show_category_statistics()
    local active_mappings = update_paketti_midi_mappings()
    local stats = get_category_statistics(active_mappings)
    
    print("\n=== MIDI MAPPING CATEGORY STATISTICS ===")
    local total_categorized = 0
    for category, count in pairs(stats) do
      print(string.format("%s: %d mappings", category, count))
      if category ~= "Uncategorized" then
        total_categorized = total_categorized + count
      end
    end
    
    local uncategorized_count = stats["Uncategorized"] or 0
    print(string.format("\nSummary: %d categorized, %d uncategorized, %d total", 
      total_categorized, uncategorized_count, #active_mappings))
  end
  
  
  
  
  function verify_paketti_midi_mappings()
    local active, inactive = verify_midi_mappings_from_list(PakettiMidiMappings)
    
    print("\n=== PAKETTI MIDI MAPPINGS VERIFICATION ===")
    print("ACTIVE:")
    for i, mapping in ipairs(active) do
      print(string.format("  %03d: %s", i, mapping))
    end
    
    if #inactive > 0 then
      print("\nINACTIVE/MISSING:")
      for i, mapping in ipairs(inactive) do
        print(string.format("  %03d: %s", i, mapping))
      end
    end
    
    print(string.format("\nSummary: %d active, %d inactive out of %d total", 
      #active, #inactive, #PakettiMidiMappings))
      
    return active, inactive
  end

-- Function to test and report on dynamic MIDI mapping detection
function test_dynamic_mapping_detection()
  print("\n=== DYNAMIC MIDI MAPPING DETECTION TEST ===")
  
  -- Test each dynamic pattern category
  local pattern_categories = {
    {
      name = "PakettiLaunchApp Patterns",
      patterns = {
        {base = "Paketti:Send Selected Sample to AppSelection %d", range = {1, 6}},
        {base = "Paketti:Save Sample to Smart/Backup Folder %d", range = {1, 3}},
        {base = "Paketti:Save All Samples to Smart/Backup Folder %d", range = {1, 3}}
      }
    },
    {
      name = "PakettiRequests Output Routing Patterns", 
      patterns = {
        {base = "Paketti:Midi Set Selected Track Output Routing %02d", range = {0, 63}},
        {base = "Paketti:Midi Set Master Track Output Routing %02d", range = {0, 63}}
      }
    },
    {
      name = "PakettiSamples Slice Patterns",
      patterns = {
        {base = "Paketti:Midi Change Slice %02d", range = {1, 32}}
      }
    },
    {
      name = "PakettiEightOneTwenty Groovebox Patterns",
      patterns = {
        {base = "Paketti:Paketti Groovebox 8120:Global Step %d", range = {1, 16}}
      }
    }
  }
  
  local total_expected = 0
  local total_found = 0
  
  for _, category in ipairs(pattern_categories) do
    print(string.format("\n--- %s ---", category.name))
    local category_expected = 0
    local category_found = 0
    
    for _, pattern_info in ipairs(category.patterns) do
      local pattern_expected = pattern_info.range[2] - pattern_info.range[1] + 1
      local pattern_found = 0
      
      print(string.format("Testing pattern: %s", pattern_info.base))
      print(string.format("Expected range: %d to %d (%d mappings)", 
        pattern_info.range[1], pattern_info.range[2], pattern_expected))
      
      for i = pattern_info.range[1], pattern_info.range[2] do
        local mapping_name = string.format(pattern_info.base, i)
        if renoise.tool():has_midi_mapping(mapping_name) then
          pattern_found = pattern_found + 1
        end
      end
      
      print(string.format("Found: %d/%d mappings (%.1f%%)", 
        pattern_found, pattern_expected, (pattern_found/pattern_expected)*100))
      
      category_expected = category_expected + pattern_expected
      category_found = category_found + pattern_found
    end
    
    print(string.format("Category total: %d/%d mappings (%.1f%%)", 
      category_found, category_expected, (category_found/category_expected)*100))
    
    total_expected = total_expected + category_expected
    total_found = total_found + category_found
  end
  
  -- Test nested patterns separately
  print("\n--- PakettiEightOneTwenty Nested Patterns ---")
  local nested_expected = 8 * 16  -- 8 rows × 16 steps
  local nested_found = 0
  
  print("Testing pattern: Paketti:Paketti Groovebox 8120:Row%d Step%d")
  print(string.format("Expected: 8 rows × 16 steps = %d mappings", nested_expected))
  
  for row = 1, 8 do
    for step = 1, 16 do
      local mapping_name = string.format("Paketti:Paketti Groovebox 8120:Row%d Step%d", row, step)
      if renoise.tool():has_midi_mapping(mapping_name) then
        nested_found = nested_found + 1
      end
    end
  end
  
  print(string.format("Found: %d/%d nested mappings (%.1f%%)", 
    nested_found, nested_expected, (nested_found/nested_expected)*100))
  
  total_expected = total_expected + nested_expected
  total_found = total_found + nested_found
  
  -- Test button patterns
  local buttons = {"<", ">", "Clear", "Randomize", "Browse", "Show", "Random", "Automation", "Reverse"}
  local button_expected = 8 * #buttons  -- 8 rows × 9 buttons
  local button_found = 0
  
  print("\n--- PakettiEightOneTwenty Button Patterns ---")
  print("Testing pattern: Paketti:Paketti Groovebox 8120:Row%d %s")
  print(string.format("Expected: 8 rows × %d buttons = %d mappings", #buttons, button_expected))
  
  for row = 1, 8 do
    for _, btn in ipairs(buttons) do
      local mapping_name = string.format("Paketti:Paketti Groovebox 8120:Row%d %s", row, btn)
      if renoise.tool():has_midi_mapping(mapping_name) then
        button_found = button_found + 1
      end
    end
  end
  
  print(string.format("Found: %d/%d button mappings (%.1f%%)", 
    button_found, button_expected, (button_found/button_expected)*100))
  
  total_expected = total_expected + button_expected
  total_found = total_found + button_found
  
  -- Final summary
  print(string.format("\n=== DYNAMIC DETECTION SUMMARY ==="))
  print(string.format("Total expected dynamic mappings: %d", total_expected))
  print(string.format("Total found dynamic mappings: %d", total_found))
  print(string.format("Detection success rate: %.1f%%", (total_found/total_expected)*100))
  
  if total_found < total_expected then
    print(string.format("\nMISSING: %d dynamic mappings were not detected", total_expected - total_found))
    print("This could mean:")
    print("1. The patterns are not currently loaded/active")
    print("2. The files containing these patterns haven't been executed")
    print("3. The patterns have different naming than expected")
  else
    print("\n✅ All expected dynamic patterns were successfully detected!")
  end
  
  return total_found, total_expected
end

-- Function to create and show the MIDI mappings dialog
function pakettiMIDIMappingsDialog()
  print("DEBUG: Starting pakettiMIDIMappingsDialog()")
  
  -- Close the dialog if it's already open
  if PakettiMidiMappingDialog and PakettiMidiMappingDialog.visible then
    PakettiMidiMappingDialog:close()
    PakettiMidiMappingDialog = nil
    return
  end

  -- First, get the current active MIDI mappings
  print("DEBUG: Getting active mappings...")
  local active_mappings = update_paketti_midi_mappings()
  print("DEBUG: Got " .. #active_mappings .. " active mappings")
  
  -- Update the grouped mappings with discovered mappings
  grouped_mappings["Discovered Mappings"] = active_mappings
  print("DEBUG: Updated grouped_mappings")

  -- Initialize the ViewBuilder
  local vb = renoise.ViewBuilder()
  if not vb then
    print("ERROR: Failed to create ViewBuilder")
    return
  end
  print("DEBUG: Created ViewBuilder")

  -- Define dialog properties
  local DIALOG_MARGIN = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN
  local CONTENT_SPACING = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING
  local MAX_ITEMS_PER_COLUMN = 40  -- Reasonable height limit
  local MAX_COLUMNS = 6  -- Allow more columns for all mappings
  local COLUMN_WIDTH = 200  -- Slightly smaller width
  local buttonWidth = 180  -- Slightly smaller buttons
  print("DEBUG: Defined dialog properties")

  -- Create the main column for the dialog
  local dialog_content = vb:column{
    margin = DIALOG_MARGIN,
    spacing = CONTENT_SPACING,
  }
  print("DEBUG: Created dialog_content")

  -- Add introductory note
  local note = vb:text{text="NOTE: This dialog shows DYNAMICALLY DISCOVERED MIDI mappings from your Lua files. Open Renoise's MIDI Mappings dialog (CMD-M), click arrow down to show list + searchbar, then click the buttons below.\n\n✅ NEW: Filter by Category • Switch to Edit Mode to assign mappings to categories • Colored buttons = categorized",style="strong",font="bold"}
  dialog_content:add_child(note)
  print("DEBUG: Added note")

  -- Create a row container for multiple columns
  local mappings_view = vb:row{
    spacing = CONTENT_SPACING,
  }
  print("DEBUG: Created mappings_view as row container")

  -- Declare variables that will be used in the function
  local alphabet_filter = nil
  local items_per_page_filter = nil
  local rows_per_column_filter = nil
  local category_filter = nil
  local edit_mode_switch = nil
  local assignment_mode = false
  local assignment_main_category_selector = nil
  local assignment_sub_category_selector = nil

  -- Function to create the category management dialog
  local function show_category_management_dialog()
    local cat_vb = renoise.ViewBuilder()
    local cat_dialog = nil
    
    local categories = get_all_categories()
    local main_categories = get_main_categories()
    local category_list_view = nil
    local main_category_selector = nil
    local sub_category_selector = nil
    
    local function refresh_category_list()
      categories = get_all_categories()
      main_categories = get_main_categories()
      local category_items = {}
      for _, cat in ipairs(categories) do
        table.insert(category_items, cat)
      end
      if category_list_view then
        category_list_view.items = category_items
      end
      if main_category_selector then
        main_category_selector.items = main_categories
      end
    end
    
    -- Sub-category field for new categories
    local new_sub_category_field = cat_vb:textfield{
      text = "",
      width = 150
    }
    
    -- Update sub-category selector when main category changes
    local initial_sub_categories = get_sub_categories(main_categories[1])
    sub_category_selector = cat_vb:popup{
      items = initial_sub_categories,
      width = 150,
      value = 1
    }
    
    -- Main category selector for adding new sub-categories (with notifier)
    main_category_selector = cat_vb:popup{
      items = main_categories,
      width = 150,
      value = 1,
      notifier = function(value)
        local selected_main = main_categories[value]
        local sub_cats = get_sub_categories(selected_main)
        sub_category_selector.items = sub_cats
        sub_category_selector.value = 1
      end
    }
    
    category_list_view = cat_vb:popup{
      items = categories,
      width = 300,
      value = 1
    }
    
    local cat_content = cat_vb:column{
      margin = 10,
      spacing = 5,
      cat_vb:text{text = "Category Management", style = "strong", font = "bold"},
      
      -- Add new sub-category section
      cat_vb:text{text = "Add New Sub-Category:", font = "bold"},
      cat_vb:row{
        cat_vb:text{text = "Main:", width = 50},
        main_category_selector,
        cat_vb:text{text = "Sub:", width = 30},
        new_sub_category_field,
        cat_vb:button{
          text = "Add",
          width = 60,
          notifier = function()
            local main_cat = main_categories[main_category_selector.value]
            local sub_cat = new_sub_category_field.text
            if sub_cat and sub_cat ~= "" then
              local full_name = get_full_category_name(main_cat, sub_cat)
              local success, msg = add_category(full_name)
              if success then
                new_sub_category_field.text = ""
                refresh_category_list()
                renoise.app():show_status("Category added: " .. full_name)
                rebuild_mappings_display()
              else
                renoise.app():show_error(msg)
              end
            end
          end
        }
      },
      
      -- Quick add main category sections
      cat_vb:text{text = "Quick Add Main Category Sections:", font = "bold"},
      cat_vb:row{
        cat_vb:button{
          text = "Add Sample Editor",
          width = 120,
          notifier = function()
            local success, msg = add_sub_categories_for_main("Sample Editor")
            if success then
              refresh_category_list()
              renoise.app():show_status(msg)
              rebuild_mappings_display()
            else
              renoise.app():show_error(msg)
            end
          end
        },
        cat_vb:button{
          text = "Add Automation",
          width = 120,
          notifier = function()
            local success, msg = add_sub_categories_for_main("Automation")
            if success then
              refresh_category_list()
              renoise.app():show_status(msg)
              rebuild_mappings_display()
            else
              renoise.app():show_error(msg)
            end
          end
        },
        cat_vb:button{
          text = "Add Paketti Gadgets",
          width = 120,
          notifier = function()
            local success, msg = add_sub_categories_for_main("Paketti Gadgets")
            if success then
              refresh_category_list()
              renoise.app():show_status(msg)
              rebuild_mappings_display()
            else
              renoise.app():show_error(msg)
            end
          end
        }
      },
      
      -- Remove existing category section
      cat_vb:text{text = "Remove Existing Category:", font = "bold"},
      cat_vb:row{
        cat_vb:text{text = "Category:", width = 70},
        category_list_view,
        cat_vb:button{
          text = "Remove",
          width = 60,
          notifier = function()
            local selected_cat = categories[category_list_view.value]
            if selected_cat then
              local success, msg = remove_category(selected_cat)
              if success then
                refresh_category_list()
                renoise.app():show_status("Category removed: " .. selected_cat)
                rebuild_mappings_display()
              else
                renoise.app():show_error(msg)
              end
            end
          end
        }
      },
      cat_vb:horizontal_aligner{
        mode = "center",
        cat_vb:button{
          text = "Export to File",
          width = 120,
          notifier = function()
            export_categories_to_txt()
          end
        },
        cat_vb:button{
          text = "Import from File", 
          width = 120,
          notifier = function()
            import_categories_from_txt()
            refresh_category_list()
            renoise.app():show_status("Categories imported")
            rebuild_mappings_display()
          end
        }
      },
      cat_vb:button{
        text = "Close",
        width = 100,
        notifier = function()
          if cat_dialog then
            cat_dialog:close()
          end
        end
      }
    }
    
    local keyhandler = create_keyhandler_for_dialog(
    function() return cat_dialog end,
    function(value) cat_dialog = value end
  )
  cat_dialog = renoise.app():show_custom_dialog("Category Management", cat_content, keyhandler)
  end

  -- Simple rebuild approach - close and reopen with proper cleanup
  local function rebuild_mappings_display()
    print("DEBUG: Rebuilding display...")
    
    -- Save current dialog state first
    if category_filter then dialog_state.category_filter_value = category_filter.value end
    if alphabet_filter then dialog_state.alphabet_filter_value = alphabet_filter.value end
    if items_per_page_filter then dialog_state.items_per_page_value = items_per_page_filter.value end
    if rows_per_column_filter then dialog_state.rows_per_column_value = rows_per_column_filter.value end
    if edit_mode_switch then dialog_state.edit_mode_value = edit_mode_switch.value end
    
    -- Note: assignment_controls_row will be recreated when dialog reopens
    
    -- Auto-reset alphabet filter to "All Mappings" when selecting specific categories
    if category_filter then
      local category_name = category_filter.items[category_filter.value]
      if category_name and not category_name:find("All Mappings") and not category_name:find("Show Uncategorized") then
        print("DEBUG: Specific category selected, resetting alphabet filter to 'All Mappings'")
        dialog_state.alphabet_filter_value = 1  -- "All Mappings" is always index 1
      end
    end
    
    save_dialog_state()
    
    -- Close current dialog cleanly
    if PakettiMidiMappingDialog and PakettiMidiMappingDialog.visible then
      PakettiMidiMappingDialog:close()
    end
    PakettiMidiMappingDialog = nil
    
    -- Reopen immediately - no delay needed
    pakettiMIDIMappingsDialog()
  end
  
  -- Function to calculate optimal button width based on text content
  local function calculate_optimal_button_width(mappings_to_show)
    local max_width = 180  -- minimum width
    local char_width = 7   -- approximate character width in pixels
    local padding = 20     -- button padding
    
    for _, mapping in ipairs(mappings_to_show) do
      local button_text = mapping:gsub("Paketti:", ""):gsub("Track Automation:", ""):gsub("Sample Editor:", "")
      if button_text == "" then
        button_text = mapping
      end
      
      local text_width = string.len(button_text) * char_width + padding
      if text_width > max_width then
        max_width = text_width
      end
    end
    
    -- Cap at reasonable maximum
    max_width = math.min(max_width, 350)
    print("DEBUG: Calculated optimal button width:", max_width)
    return max_width
  end

  -- Function to get button color based on category
  local function get_button_color_for_category(category)
    if category == "Uncategorized" then
      return nil  -- Default button color
    end
    
    -- Extract main category
    local main_category = category:match("^([^:]+):")
    if not main_category then
      main_category = category
    end
    
    -- Color mapping for different main categories
    local color_map = {
      ["Pattern Editor"] = {0x40, 0x80, 0x40},  -- Green
      ["Sample Editor"] = {0x40, 0x40, 0x80},   -- Blue  
      ["Automation"] = {0x80, 0x40, 0x40},      -- Red
      ["Playback"] = {0x80, 0x80, 0x40},        -- Yellow
      ["Track"] = {0x80, 0x40, 0x80},           -- Purple
      ["Instrument"] = {0x40, 0x80, 0x80},      -- Cyan
      ["Paketti Gadgets"] = {0x80, 0x60, 0x40}, -- Orange
      ["Sequencer"] = {0x60, 0x80, 0x60},       -- Light Green
      ["Mixer"] = {0x80, 0x80, 0x60},           -- Light Yellow
      ["Utility"] = {0x60, 0x60, 0x80},         -- Light Blue
      ["Experimental"] = {0x80, 0x60, 0x80},    -- Light Purple
    }
    
    return color_map[main_category] or {0x60, 0x60, 0x60}  -- Default gray for unknown categories
  end





  -- Original function to build mappings display (only called once)
  local function build_initial_mappings_display()
    print("DEBUG: Building initial mappings display")
    
    -- Get the selected filters
    local alphabet_filter_value = alphabet_filter.value
    local alphabet_filter_name = alphabet_filter.items[alphabet_filter_value]
    local category_filter_value = category_filter.value
    local category_filter_display_name = category_filter.items[category_filter_value]
    
    -- Extract category name from display format "Category Name (count)" with error handling
    local category_filter_name = category_filter_display_name
    print("DEBUG: Raw category_filter_display_name: " .. tostring(category_filter_display_name))
    
    if category_filter_display_name then
      -- Try to extract name from format "Name (count)"
      local extracted_name = category_filter_display_name:match("^(.+) %(%d+%)$")
      if extracted_name then
        category_filter_name = extracted_name
        print("DEBUG: Extracted name: " .. extracted_name)
      end
      
      -- Handle special cases
      if category_filter_name:find("All Mappings") then
        category_filter_name = "All Mappings"
        print("DEBUG: Set to All Mappings")
      elseif category_filter_name:find("Show Uncategorized") then
        category_filter_name = "Show Uncategorized"
        print("DEBUG: Set to Show Uncategorized")
      end
    else
      print("ERROR: category_filter_display_name is nil, defaulting to 'All Mappings'")
      category_filter_name = "All Mappings"
    end
    
    print("DEBUG: Final category_filter_name: " .. tostring(category_filter_name))
    
    print("DEBUG: Selected alphabet filter: " .. alphabet_filter_name)
    print("DEBUG: Selected category filter: " .. category_filter_name)
    
    -- First, apply category filter with error handling
    local category_filtered_mappings = {}
    local is_main_category = false
    
    print("DEBUG: Starting category filtering...")
    
    if category_filter_name == "All Mappings" then
      print("DEBUG: Using All Mappings filter")
      category_filtered_mappings = active_mappings or {}
      print("DEBUG: All Mappings result count:", #category_filtered_mappings)
    elseif category_filter_name == "Show Uncategorized" then
      print("DEBUG: Using Show Uncategorized filter")
      category_filtered_mappings = get_uncategorized_mappings(active_mappings or {})
      print("DEBUG: Uncategorized result count:", #category_filtered_mappings)
    else
      print("DEBUG: Checking if main category:", category_filter_name)
      -- Check if this is a main category (like "Automation") or full category (like "Automation: Control")
      local main_categories = get_main_categories()
      print("DEBUG: Available main categories:", table.concat(main_categories, ", "))
      for _, main_cat in ipairs(main_categories) do
        if main_cat == category_filter_name then
          is_main_category = true
          print("DEBUG: Found as main category!")
          break
        end
      end
      
      if is_main_category then
        print("DEBUG: Processing as main category")
        -- Get all mappings for this main category (all sub-categories)
        for _, mapping in ipairs(active_mappings or {}) do
          local mapping_category = get_mapping_category(mapping)
          local main_part = mapping_category:match("^([^:]+):")
          if main_part == category_filter_name then
            table.insert(category_filtered_mappings, mapping)
          end
        end
        print("DEBUG: Main category result count:", #category_filtered_mappings)
      else
        print("DEBUG: Processing as full category")
        category_filtered_mappings = get_mappings_for_category(category_filter_name, active_mappings or {})
        print("DEBUG: Full category result count:", #category_filtered_mappings)
      end
    end
    
    -- Fallback to all mappings if filtering failed
    if #category_filtered_mappings == 0 and active_mappings and #active_mappings > 0 then
      print("WARNING: Category filtering failed, showing all mappings")
      category_filtered_mappings = active_mappings
    end
    
    print("DEBUG: Final category_filtered_mappings count:", #category_filtered_mappings)
    
    -- Then apply alphabetical filter to category-filtered results
    local mappings_to_show = {}
    if alphabet_filter_value == 1 then -- "All Mappings"
      print("DEBUG: Using All alphabet filter")
      mappings_to_show = category_filtered_mappings
    else
      print("DEBUG: Using alphabet filter range:", alphabet_filter_value)
      -- Filter alphabetically
      local ranges = {
        [2] = {string.byte('A'), string.byte('F')}, -- A-F
        [3] = {string.byte('G'), string.byte('M')}, -- G-M  
        [4] = {string.byte('N'), string.byte('S')}, -- N-S
        [5] = {string.byte('T'), string.byte('Z')}  -- T-Z
      }
      
      local range = ranges[alphabet_filter_value]
      if range then
        print("DEBUG: Alphabet range:", string.char(range[1]) .. "-" .. string.char(range[2]))
        for _, mapping in ipairs(category_filtered_mappings) do
          local clean_name = mapping:gsub("^[^:]*:", ""):gsub("^%s*", "")
          local first_byte = string.byte(string.upper(clean_name:sub(1,1)))
          if first_byte >= range[1] and first_byte <= range[2] then
            table.insert(mappings_to_show, mapping)
          end
        end
      end
    end
    
    print("DEBUG: After alphabet filter, mappings_to_show count:", #mappings_to_show)
    
    -- Sort mappings alphabetically by their clean names
    table.sort(mappings_to_show, function(a, b)
      local clean_a = a:gsub("^[^:]*:", ""):gsub("^%s*", "")
      local clean_b = b:gsub("^[^:]*:", ""):gsub("^%s*", "")
      return string.upper(clean_a) < string.upper(clean_b)
    end)
    
    print("DEBUG: Showing " .. #mappings_to_show .. " mappings")
    
        -- Safety check: if no mappings to show, add a message to mappings_view
    if #mappings_to_show == 0 then
      local no_items_label = vb:text{
        text = "No mappings found for selected filter combination.\nTry different Category or Alphabet filters.",
        font = "italic"
      }
      mappings_view:add_child(no_items_label)
      print("DEBUG: No mappings to show")
      return
    else
                -- Get the already calculated values
    local items_per_page_options = {25, 50, 75, 100, 125, 150, 200, 250, 300, 350, 400}
    local max_items_to_show = items_per_page_options[items_per_page_filter.value]
        local rows_per_column_options = {10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70}
        local max_items_per_column = rows_per_column_options[rows_per_column_filter.value]
        local items_to_show = math.min(#mappings_to_show, max_items_to_show)
        local num_columns = math.max(1, math.ceil(items_to_show / max_items_per_column))
        
        -- Calculate optimal button width for current mappings
        local optimal_button_width = calculate_optimal_button_width(mappings_to_show)
        
        -- Safety check: ensure we have valid values
        if items_to_show <= 0 or max_items_per_column <= 0 then
          print("DEBUG: Invalid values - items_to_show:", items_to_show, "max_items_per_column:", max_items_per_column)
          return
        end
      
      -- Create columns
      local columns = {}
      for col = 1, num_columns do
        columns[col] = vb:column{
          spacing = CONTENT_SPACING,
          width = COLUMN_WIDTH,
        }
        mappings_view:add_child(columns[col])
      end

      -- If this is a main category filter, group by sub-categories with headers
      if is_main_category then
        -- Group mappings by sub-category
        local grouped_mappings = {}
        local sub_category_order = {}
        
        for _, mapping in ipairs(mappings_to_show) do
          local mapping_category = get_mapping_category(mapping)
          local main_part, sub_part = mapping_category:match("^([^:]+):%s*(.+)")
          if sub_part then
            if not grouped_mappings[sub_part] then
              grouped_mappings[sub_part] = {}
              table.insert(sub_category_order, sub_part)
            end
            table.insert(grouped_mappings[sub_part], mapping)
          end
        end
        
        -- Sort sub-categories
        table.sort(sub_category_order)
        
        local current_column = 1
        local current_row_in_column = 0
        
        -- Add mappings grouped by sub-category
        for _, sub_category in ipairs(sub_category_order) do
          local sub_mappings = grouped_mappings[sub_category]
          
          -- Add sub-category header
          if current_row_in_column > 0 then
            -- Add some spacing before new sub-category
            current_row_in_column = current_row_in_column + 1
            if current_row_in_column > max_items_per_column then
              current_column = current_column + 1
              current_row_in_column = 1
              if current_column > num_columns then break end
            end
          end
          
          local header = vb:text{
            text = category_filter_name .. ": " .. sub_category,
            style = "strong",
            font = "bold"
          }
          
          if columns[current_column] then
            columns[current_column]:add_child(header)
            current_row_in_column = current_row_in_column + 1
          end
          
          -- Add buttons for this sub-category
          for _, mapping in ipairs(sub_mappings) do
            if current_row_in_column > max_items_per_column then
              current_column = current_column + 1
              current_row_in_column = 1
              if current_column > num_columns then break end
            end
            
            local button_text = mapping:gsub("Paketti:", ""):gsub("Track Automation:", ""):gsub("Sample Editor:", "")
            if button_text == "" then
              button_text = mapping
            end
            
            local current_category = get_mapping_category(mapping)
            local button_color = get_button_color_for_category(current_category)
            
            local button = vb:button{
              width = optimal_button_width,
              text = button_text,
              midi_mapping = mapping,
              color = button_color,
              notifier = function()
                if assignment_mode and edit_mode_switch.value == 2 then
                  -- Assignment mode: instant assignment using persistent dropdowns
                  local selected_main = main_categories[assignment_main_category_selector.value]
                  local selected_sub = assignment_sub_category_selector.items[assignment_sub_category_selector.value]
                  local full_category = get_full_category_name(selected_main, selected_sub)
                  
                  local success, msg = assign_mapping_to_category(mapping, full_category)
                  if success then
                    -- Remember this category for future use
                    dialog_state.last_assigned_category = full_category
                    save_dialog_state()
                    
                    renoise.app():show_status("✅ " .. button_text:sub(1,30) .. "... → " .. selected_main .. ":" .. selected_sub)
                    
                    -- Check if we need to rebuild the display
                    local current_filter = category_filter.items[category_filter.value]
                    local needs_rebuild = false
                    
                    -- Always rebuild if we're showing uncategorized (item will disappear)
                    if current_filter and current_filter:find("Show Uncategorized") then
                      needs_rebuild = true
                    end
                    
                    -- Rebuild if we're showing "All Mappings" to update button colors
                    if current_filter and current_filter:find("All Mappings") then
                      needs_rebuild = true
                    end
                    
                    -- Rebuild if we're showing the specific category the item was assigned to
                    if current_filter and (current_filter:find(selected_main) or current_filter == selected_main) then
                      needs_rebuild = true
                    end
                    
                    if needs_rebuild then
                      rebuild_mappings_display()
                    end
                  else
                    renoise.app():show_error(msg)
                  end
                else
                  -- View Mode: execute the actual function behind the MIDI mapping
                  local success = execute_midi_mapping_function(mapping)
                  if success then
                    renoise.app():show_status("Executed: " .. button_text)
                  else
                    renoise.app():show_status("Could not execute: " .. button_text)
                  end
                end
              end
            }
            
            if columns[current_column] then
              columns[current_column]:add_child(button)
              current_row_in_column = current_row_in_column + 1
            end
          end
        end
      else
        -- Regular filtering (not main category) - distribute buttons across columns
        for i = 1, items_to_show do
          local mapping = mappings_to_show[i]
          if mapping and mapping ~= "" then
            local button_text = mapping:gsub("Paketti:", ""):gsub("Track Automation:", ""):gsub("Sample Editor:", "")
            
            -- Ensure button text is not empty
            if button_text == "" then
              button_text = mapping  -- fallback to original mapping name
            end
            
            -- Get current category for color coding
            local current_category = get_mapping_category(mapping)
            local button_color = get_button_color_for_category(current_category)
            
            local button = vb:button{
              width = optimal_button_width,
              text = button_text,
              midi_mapping = mapping,
              color = button_color,
              notifier = function()
                if assignment_mode and edit_mode_switch.value == 2 then
                  -- Assignment mode: instant assignment using persistent dropdowns
                  local current_main_categories = get_main_categories()
                  local selected_main = current_main_categories[assignment_main_category_selector.value]
                  local selected_sub = assignment_sub_category_selector.items[assignment_sub_category_selector.value]
                  local full_category = get_full_category_name(selected_main, selected_sub)
                  
                  local success, msg = assign_mapping_to_category(mapping, full_category)
                  if success then
                    -- Remember this category for future use
                    dialog_state.last_assigned_category = full_category
                    save_dialog_state()
                    
                    renoise.app():show_status("✅ " .. button_text:sub(1,30) .. "... → " .. selected_main .. ":" .. selected_sub)
                    
                    -- Check if we need to rebuild the display
                    local current_filter = category_filter.items[category_filter.value]
                    local needs_rebuild = false
                    
                    -- Always rebuild if we're showing uncategorized (item will disappear)
                    if current_filter and current_filter:find("Show Uncategorized") then
                      needs_rebuild = true
                    end
                    
                    -- Rebuild if we're showing "All Mappings" to update button colors
                    if current_filter and current_filter:find("All Mappings") then
                      needs_rebuild = true
                    end
                    
                    -- Rebuild if we're showing the specific category the item was assigned to
                    if current_filter and (current_filter:find(selected_main) or current_filter == selected_main) then
                      needs_rebuild = true
                    end
                    
                    if needs_rebuild then
                      rebuild_mappings_display()
                    end
                  else
                    renoise.app():show_error(msg)
                  end
                else
                  -- View Mode: execute the actual function behind the MIDI mapping
                  local success = execute_midi_mapping_function(mapping)
                  if success then
                    renoise.app():show_status("Executed: " .. button_text)
                  else
                    renoise.app():show_status("Could not execute: " .. button_text)
                  end
                end
              end
            }
            
            -- Determine which column this button goes in (fill columns sequentially)
            local col_index = math.ceil(i / max_items_per_column)
            if columns[col_index] then
              columns[col_index]:add_child(button)
            else
              print("DEBUG: Column index out of range:", col_index, "for item", i)
            end
          end
        end
        
        print("DEBUG: Added " .. items_to_show .. " buttons in " .. num_columns .. " columns")
      end -- Close the else block
    end -- Close the else block for mappings_to_show > 0
  end -- Close build_initial_mappings_display function
  print("DEBUG: Defined build_initial_mappings_display function")

  -- Create category filter dropdown with counts (hierarchical)
  local all_categories = get_all_categories()
  local main_categories = get_main_categories()
  local stats = get_category_statistics(active_mappings)
  
  print("DEBUG: all_categories count:", #all_categories)
  print("DEBUG: main_categories count:", #main_categories)
  print("DEBUG: active_mappings count:", #active_mappings)
  
  -- Ensure we have basic main categories
  if #main_categories <= 1 then  -- Only "Uncategorized"
    print("DEBUG: No main categories found, adding basic ones")
    local basic_main_categories = {"Pattern Editor", "Sample Editor", "Automation", "Playback", "Track", "Instrument", "Paketti Gadgets", "Sequencer", "Mixer", "Utility", "Experimental"}
    for _, main_cat in ipairs(basic_main_categories) do
      local success, msg = add_sub_categories_for_main(main_cat)
      if success then
        print("DEBUG: Added basic category: " .. main_cat)
      end
    end
    -- Refresh after adding
    all_categories = get_all_categories()
    main_categories = get_main_categories()
    stats = get_category_statistics(active_mappings)
  end
  
  local category_items = {
    string.format("All Mappings (%d)", #active_mappings),
    string.format("Show Uncategorized (%d)", stats["Uncategorized"] or 0)
  }
  
  -- Add main categories with total counts
  for _, main_cat in ipairs(main_categories) do
    if main_cat ~= "Uncategorized" then
      local total_count = 0
      -- Count all mappings in this main category
      for _, full_cat in ipairs(all_categories) do
        local main_part = full_cat:match("^([^:]+):")
        if main_part == main_cat then
          total_count = total_count + (stats[full_cat] or 0)
        end
      end
      -- Always add the main category, even if count is 0
      table.insert(category_items, string.format("%s (%d)", main_cat, total_count))
    end
  end
  
  print("DEBUG: category_items:")
  for i, item in ipairs(category_items) do
    print("  " .. i .. ": " .. item)
  end
  
  -- Ensure dialog_state.category_filter_value is valid
  if dialog_state.category_filter_value > #category_items then
    dialog_state.category_filter_value = 1  -- Default to "All Mappings"
    print("DEBUG: Reset category_filter_value to 1")
  end
  
  category_filter = vb:popup{
    items = category_items,
    width = 200,
    value = dialog_state.category_filter_value,
    notifier = rebuild_mappings_display
  }
  print("DEBUG: Created category_filter with value:", dialog_state.category_filter_value)

  -- Now create the alphabetical filter dropdown (with notifier set during creation)
  alphabet_filter = vb:popup{
    items = {"All Mappings", "A-F", "G-M", "N-S", "T-Z"},
    width = 200,
    value = dialog_state.alphabet_filter_value,
    notifier = rebuild_mappings_display
  }
  print("DEBUG: Created alphabet_filter")
  
  -- Create the items per page filter dropdown
  items_per_page_filter = vb:popup{
    items = {"25 items", "50 items", "75 items", "100 items", "125 items", "150 items", "200 items", "250 items", "300 items", "350 items", "400 items"},
    width = 100,
    value = dialog_state.items_per_page_value,
    notifier = rebuild_mappings_display
  }
  print("DEBUG: Created items_per_page_filter")
  
  -- Create the rows per column filter dropdown
  rows_per_column_filter = vb:popup{
    items = {"10 rows", "15 rows", "20 rows", "25 rows", "30 rows", "35 rows", "40 rows", "45 rows", "50 rows", "55 rows", "60 rows", "65 rows", "70 rows"},
    width = 100,
    value = dialog_state.rows_per_column_value,
    notifier = rebuild_mappings_display
  }
  print("DEBUG: Created rows_per_column_filter")
  
  -- Create edit mode switch
  edit_mode_switch = vb:switch{
    items = {"View Mode", "Edit Mode"},
    width = 150,
    value = dialog_state.edit_mode_value,
    notifier = function(value)
      assignment_mode = (value == 2)
      
      -- Show helpful status messages
      if value == 2 then
        renoise.app():show_status("EDIT MODE: Set target category below, then click mappings to assign instantly")
      else
        renoise.app():show_status("VIEW MODE: Click MIDI mapping buttons to use them normally")
      end
      
      -- Rebuild to update button behavior and show/hide assignment controls
      rebuild_mappings_display()
    end
  }
  print("DEBUG: Created edit_mode_switch")
  
  -- Set assignment_mode based on current switch value
  assignment_mode = (dialog_state.edit_mode_value == 2)
  
  -- Create assignment category controls (for edit mode)
  local assignment_controls_row = nil
  
  -- Get main categories for assignment
  local main_categories = get_main_categories()
  
  -- Find index of last assigned category for default selection
  local default_main_index = 1
  local default_sub_index = 1
  local last_assigned = dialog_state.last_assigned_category
  
  if last_assigned and last_assigned ~= "Uncategorized" then
    local main_part = last_assigned:match("^([^:]+):")
    if main_part then
      for i, cat in ipairs(main_categories) do
        if cat == main_part then
          default_main_index = i
          break
        end
      end
      local sub_categories = get_sub_categories(main_part)
      local sub_part = last_assigned:match("^[^:]+:%s*(.+)")
      if sub_part then
        for i, cat in ipairs(sub_categories) do
          if cat == sub_part then
            default_sub_index = i
            break
          end
        end
      end
    end
  end
  
  -- Create sub-category selector first (needed for main category notifier)
  local initial_sub_categories = get_sub_categories(main_categories[default_main_index])
  assignment_sub_category_selector = vb:popup{
    items = initial_sub_categories,
    value = math.min(default_sub_index, #initial_sub_categories),
    width = 200
  }
  
  -- Create main category selector with notifier to update sub-categories
  assignment_main_category_selector = vb:popup{
    items = main_categories,
    value = default_main_index,
    width = 200,
    notifier = function(value)
      local selected_main = main_categories[value]
      local sub_cats = get_sub_categories(selected_main)
      assignment_sub_category_selector.items = sub_cats
      assignment_sub_category_selector.value = 1
    end
  }
  
  -- Create the assignment controls row (initially hidden)
  assignment_controls_row = vb:row{
    spacing = 10,
    visible = assignment_mode,
    vb:text{text = "Target Category:", style = "strong"},
    vb:text{text = "Main:"},
    assignment_main_category_selector,
    vb:text{text = "Sub:"},
    assignment_sub_category_selector,
    vb:button{
      text = "Quick: Uncategorized",
      width = 120,
      notifier = function()
        -- Set both dropdowns to Uncategorized
        for i, cat in ipairs(main_categories) do
          if cat == "Uncategorized" then
            assignment_main_category_selector.value = i
            local sub_cats = get_sub_categories("Uncategorized")
            assignment_sub_category_selector.items = sub_cats
            assignment_sub_category_selector.value = 1
            break
          end
        end
      end
    }
  }
  
  -- Show initial status message
  if assignment_mode then
    renoise.app():show_status("EDIT MODE: Set target category below, then click mappings to assign instantly")
  end
  
  -- Add refresh button
  local refresh_button = vb:button{
    text = "Refresh MIDI Mappings",
    width = buttonWidth,
    notifier = function()
      rebuild_mappings_display()
    end
  }
  print("DEBUG: Created refresh_button")
  
  -- Add category management button
  local category_mgmt_button = vb:button{
    text = "Manage Categories",
    width = buttonWidth,
    notifier = function()
      show_category_management_dialog()
    end
  }
  print("DEBUG: Created category_mgmt_button")

  -- Add controls in rows (split for better layout)
  local filter_controls_row = vb:row{
    spacing = 10,
    vb:text{text = "Category:"},
    category_filter,
    vb:text{text = "Alphabet:"},
    alphabet_filter,
    vb:text{text = "Mode:"},
    edit_mode_switch
  }
  
  local display_controls_row = vb:row{
    spacing = 10,
    vb:text{text = "Show:"},
    items_per_page_filter,
    vb:text{text = "Rows:"},
    rows_per_column_filter,
    refresh_button,
    category_mgmt_button
  }
  
  dialog_content:add_child(filter_controls_row)
  dialog_content:add_child(display_controls_row)
  dialog_content:add_child(assignment_controls_row)
  print("DEBUG: Added control rows")

  -- Function to create a new column
  local function create_new_column()
    return vb:column{
      spacing = CONTENT_SPACING,
      width = COLUMN_WIDTH,
    }
  end
  print("DEBUG: Defined create_new_column function")

  -- Initial display build
  build_initial_mappings_display()
  print("DEBUG: Completed initial build_initial_mappings_display")
  
  -- Add the mappings view to the dialog
  dialog_content:add_child(mappings_view)
  print("DEBUG: Added mappings_view to dialog_content")
  
  -- Add status text as a separate group AFTER the mappings
  local function add_status_text()
    local active_mappings = update_paketti_midi_mappings()
    local category_filter_display_name = category_filter.items[category_filter.value]
    local alphabet_filter_name = alphabet_filter.items[alphabet_filter.value]
    
    -- Get current filter values
    local items_per_page_options = {25, 50, 75, 100, 125, 150, 200, 250, 300, 350, 400}
    local max_items_to_show = items_per_page_options[items_per_page_filter.value]
    local rows_per_column_options = {10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70}
    local max_items_per_column = rows_per_column_options[rows_per_column_filter.value]
    
    -- Apply the same filtering logic as build_initial_mappings_display
    local category_filter_name = category_filter_display_name
    if category_filter_display_name then
      local extracted_name = category_filter_display_name:match("^(.+) %(%d+%)$")
      if extracted_name then
        category_filter_name = extracted_name
      end
      if category_filter_name:find("All Mappings") then
        category_filter_name = "All Mappings"
      elseif category_filter_name:find("Show Uncategorized") then
        category_filter_name = "Show Uncategorized"
      end
    end
    
    local category_filtered_mappings = {}
    if category_filter_name == "All Mappings" then
      category_filtered_mappings = active_mappings or {}
    elseif category_filter_name == "Show Uncategorized" then
      category_filtered_mappings = get_uncategorized_mappings(active_mappings or {})
    else
      -- Check if this is a main category (like "Automation") or full category (like "Automation: Control")
      local main_categories = get_main_categories()
      local is_main_category = false
      for _, main_cat in ipairs(main_categories) do
        if main_cat == category_filter_name then
          is_main_category = true
          break
        end
      end
      
      if is_main_category then
        -- Get all mappings for this main category (all sub-categories)
        for _, mapping in ipairs(active_mappings or {}) do
          local mapping_category = get_mapping_category(mapping)
          local main_part = mapping_category:match("^([^:]+):")
          if main_part == category_filter_name then
            table.insert(category_filtered_mappings, mapping)
          end
        end
      else
        category_filtered_mappings = get_mappings_for_category(category_filter_name, active_mappings or {})
      end
    end
    
    local mappings_to_show = {}
    if alphabet_filter.value == 1 then
      mappings_to_show = category_filtered_mappings
    else
      local ranges = {
        [2] = {string.byte('A'), string.byte('F')},
        [3] = {string.byte('G'), string.byte('M')},
        [4] = {string.byte('N'), string.byte('S')},
        [5] = {string.byte('T'), string.byte('Z')}
      }
      local range = ranges[alphabet_filter.value]
      if range then
        for _, mapping in ipairs(category_filtered_mappings) do
          local clean_name = mapping:gsub("^[^:]*:", ""):gsub("^%s*", "")
          local first_byte = string.byte(string.upper(clean_name:sub(1,1)))
          if first_byte >= range[1] and first_byte <= range[2] then
            table.insert(mappings_to_show, mapping)
          end
        end
      end
    end
    
    -- Sort mappings alphabetically by their clean names
    table.sort(mappings_to_show, function(a, b)
      local clean_a = a:gsub("^[^:]*:", ""):gsub("^%s*", "")
      local clean_b = b:gsub("^[^:]*:", ""):gsub("^%s*", "")
      return string.upper(clean_a) < string.upper(clean_b)
    end)
    
    -- Create status text
    local status_text = ""
    if #mappings_to_show > 0 then
      local items_to_show = math.min(#mappings_to_show, max_items_to_show)
      local num_columns = math.max(1, math.ceil(items_to_show / max_items_per_column))
      
      status_text = string.format("Showing %d of %d mappings (%s + %s) in %d column%s", 
        items_to_show, #mappings_to_show, alphabet_filter_name, category_filter_display_name, num_columns, num_columns == 1 and "" or "s")
      if #mappings_to_show > max_items_to_show then
        status_text = status_text .. " [showing first " .. max_items_to_show .. "]"
      end
      
      -- Add assignment mode info
      if assignment_mode and edit_mode_switch.value == 2 then
        status_text = status_text .. " [ASSIGNMENT MODE: Set target category above, then click mappings]"
      end
      
      local status_label = vb:text{
        text = status_text,
        font = "bold"
      }
      dialog_content:add_child(status_label)
    end
  end
  
  -- Add the status text
  add_status_text()

  print("DEBUG: About to show dialog...")
  PakettiMidiMappingDialog = renoise.app():show_custom_dialog(
    "Paketti MIDI Mappings (Dynamic Discovery)", 
    dialog_content,
    function(dialog, key) return my_MidiMappingkeyhandler_func(dialog, key) end
  )
  print("DEBUG: Dialog shown successfully!")
end

-- Function to dynamically scan source files and build MIDI mapping function table
function build_midi_mapping_table()
  local mapping_table = {}
  local bundle_path = renoise.tool().bundle_path
  
  -- Function to scan a single file for MIDI mappings
  local function scan_file_for_mappings(file_path)
    local file = io.open(file_path, "r")
    if not file then 
      print("DEBUG: Could not open file: " .. file_path)
      return 
    end
    
    local content = file:read("*all")
    file:close()
    
    print("DEBUG: Scanning file: " .. file_path)
    
    -- Parse MIDI mappings - handle both single-line and multiline formats
    for line in content:gmatch("[^\r\n]+") do
      -- Look for add_midi_mapping calls
      if line:find('add_midi_mapping') then
        -- Extract the mapping name
        local mapping_name = line:match('name%s*=%s*"([^"]+)"')
        
        if mapping_name then
                     -- Extract the function body (the code inside the function)
           local invoke_pos = line:find('invoke%s*=')
           if invoke_pos then
             -- Extract the complete function definition first
             local invoke_content = line:match('invoke%s*=%s*(.-)%s*}%s*$')
             
             if invoke_content and invoke_content:len() > 0 then
               -- Now extract just the function body from inside function(...)...end
               local func_body = invoke_content:match('function%s*%(.-%)%s*(.-)%s*end%s*$')
               
               if func_body and func_body:len() > 0 then
                 -- Clean up the function body
                 local clean_body = func_body:gsub("^%s+", ""):gsub("%s+$", "")
                 
                 if clean_body:len() > 0 then
                   mapping_table[mapping_name] = clean_body
                   print("DEBUG: Found mapping: " .. mapping_name .. " (body: " .. clean_body .. ")")
                 end
               end
             end
           end
        end
      end
    end
  end
  
  -- Use the existing file list that's already defined
  for _, file_name in ipairs(PakettiLUAScriptsTableForMidi) do
    local file_path = bundle_path .. file_name
    scan_file_for_mappings(file_path)
  end
  
  -- Count the mapping table entries (since it's a hash table, not array)
  local count = 0
  for _ in pairs(mapping_table) do
    count = count + 1
  end
  print("DEBUG: Built mapping table with " .. count .. " entries")
  return mapping_table
end

-- Cache the mapping table (build once per session)
local cached_mapping_table = nil

-- Function to force refresh the mapping table cache
function refresh_mapping_table_cache()
  print("DEBUG: Force refreshing mapping table cache...")
  cached_mapping_table = nil
  cached_mapping_table = build_midi_mapping_table()
  renoise.app():show_status("MIDI mapping table refreshed - found " .. (function() local c=0; for _ in pairs(cached_mapping_table) do c=c+1 end; return c end)() .. " mappings")
end

-- Function to dynamically execute MIDI mapping functions
function execute_midi_mapping_function(mapping_name)
  local tool = renoise.tool()
  
  if not tool:has_midi_mapping(mapping_name) then
    print("DEBUG: MIDI mapping not found: " .. mapping_name)
    return false
  end
  
  -- Build mapping table if not cached
  if not cached_mapping_table then
    cached_mapping_table = build_midi_mapping_table()
  end
  
  -- Get the function body for this mapping
  local func_body = cached_mapping_table[mapping_name]
  if not func_body then
    print("DEBUG: No function body found for: " .. mapping_name)
    renoise.app():show_status("Function not found for: " .. mapping_name:gsub("^Paketti:", ""))
    return false
  end
  
  -- Create a fake message object for trigger-based mappings
  local fake_message = {
    is_trigger = function() return true end,
    is_switch = function() return false end,
    is_rel_value = function() return false end,
    is_abs_value = function() return false end,
    int_value = 127,
    boolean_value = true
  }
  
  -- Execute the function body with message context
  local success, error_msg = pcall(function()
    -- Create a sandboxed environment with full access to global scope
    -- This ensures all Paketti functions are available
    local func_env = setmetatable({
      message = fake_message
    }, {__index = _G})
    
    -- Debug: Print the function body being executed
    print("DEBUG: Executing function body: " .. func_body)
    
    -- Load and execute the function body (message is already in the environment)
    local chunk, load_error = load(func_body, "midi_mapping_" .. mapping_name, "t", func_env)
    
    if not chunk then
      print("DEBUG: Failed to load function body: " .. tostring(load_error))
      return false
    end
    
          chunk()
    return true
  end)
  
  if success then
    print("DEBUG: Successfully executed: " .. mapping_name)
    return true
  else
    print("DEBUG: Failed to execute: " .. mapping_name .. " - " .. tostring(error_msg))
    return false
  end
end

-- Function to detect complex dynamic patterns that require runtime enumeration
function detect_complex_dynamic_mappings()
  local complex_mappings = {}
  
  print("\n=== DETECTING COMPLEX DYNAMIC MAPPINGS ===")
  
  -- 1. Device-based mappings (PakettiControls.lua)
  -- These follow patterns like "Paketti:Toggle Device %02d (%s) x[Toggle]"
  -- We'll scan for any mapping that matches the pattern
  for i = 1, 99 do -- reasonable upper limit for device indices
    -- Try to find device mappings by testing common device names
    local test_patterns = {
      string.format("Paketti:Toggle Device %02d", i),
      string.format("Paketti:Hold Device %02d", i)
    }
    
    for _, base_pattern in ipairs(test_patterns) do
      -- Check if any mapping starts with this pattern
      local found_device_mapping = false
      -- We can't easily enumerate all mappings, so we'll use a different approach
      -- Try common device name patterns
      local common_devices = {"EQ", "Compressor", "Gate", "Delay", "Reverb", "Filter", "Distortion", "Chorus", "Flanger", "Phaser"}
      
      for _, device_name in ipairs(common_devices) do
        local full_pattern = base_pattern .. string.format(" (%s) x[Toggle]", device_name)
        if renoise.tool():has_midi_mapping(full_pattern) then
          table.insert(complex_mappings, full_pattern)
          print("COMPLEX DYNAMIC FOUND: " .. full_pattern)
          found_device_mapping = true
        end
        
        -- Also check button version
        local button_pattern = base_pattern .. string.format(" (%s) x[Button]", device_name)
        if renoise.tool():has_midi_mapping(button_pattern) then
          table.insert(complex_mappings, button_pattern)
          print("COMPLEX DYNAMIC FOUND: " .. button_pattern)
        end
      end
      
      if not found_device_mapping then
        -- Try the pattern without device name to see if any exist
        if renoise.tool():has_midi_mapping(base_pattern) then
          table.insert(complex_mappings, base_pattern)
          print("COMPLEX DYNAMIC FOUND: " .. base_pattern)
        end
      end
    end
  end
  
  -- 2. Instrument transpose mappings (PakettiExperimental_Verify.lua)
  for i = 1, 16 do
    local mapping_name = string.format("Paketti:Midi Instrument %02d Transpose (-64-+64)", i)
    if renoise.tool():has_midi_mapping(mapping_name) then
      table.insert(complex_mappings, mapping_name)
      print("COMPLEX DYNAMIC FOUND: " .. mapping_name)
    end
  end
  
  -- 3. EightOneTwenty expand/shrink patterns
  for i = 1, 8 do
    local expand_pattern = string.format("Paketti:Paketti Groovebox 8120 Expand Selection Replicate Track %d [Trigger]", i)
    local shrink_pattern = string.format("Paketti:Paketti Groovebox 8120 Shrink Selection Replicate Track %d [Trigger]", i)
    local transpose_pattern = string.format("Paketti:Paketti Groovebox 8120 Instrument %02d Transpose (-64-+64)", i)
    
    if renoise.tool():has_midi_mapping(expand_pattern) then
      table.insert(complex_mappings, expand_pattern)
      print("COMPLEX DYNAMIC FOUND: " .. expand_pattern)
    end
    
    if renoise.tool():has_midi_mapping(shrink_pattern) then
      table.insert(complex_mappings, shrink_pattern)
      print("COMPLEX DYNAMIC FOUND: " .. shrink_pattern)
    end
    
    if renoise.tool():has_midi_mapping(transpose_pattern) then
      table.insert(complex_mappings, transpose_pattern)
      print("COMPLEX DYNAMIC FOUND: " .. transpose_pattern)
    end
  end
  
  print(string.format("Found %d complex dynamic mappings", #complex_mappings))
  return complex_mappings
end

-------------------------
renoise.tool():add_keybinding{name="Global:Paketti:Verify Paketti MIDI Mappings",invoke=verify_paketti_midi_mappings}
renoise.tool():add_keybinding{name = "Global:Paketti:Paketti MIDI Mappings (Dynamic)...",invoke = function() pakettiMIDIMappingsDialog() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Print Active MIDI Mappings to Console",invoke = print_active_midi_mappings}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate MIDI Mappings to Console",invoke = generate_paketti_midi_mappings}
renoise.tool():add_keybinding{name = "Global:Paketti:Extract MIDI Mappings to Console",invoke = extract_midi_mappings}
renoise.tool():add_keybinding{name = "Global:Paketti:Show MIDI Category Statistics",invoke = show_category_statistics}
renoise.tool():add_keybinding{name = "Global:Paketti:Test Dynamic MIDI Mapping Detection",invoke = test_dynamic_mapping_detection}
renoise.tool():add_keybinding{name = "Global:Paketti:Refresh MIDI Mapping Table Cache",invoke = refresh_mapping_table_cache}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:!Preferences:Paketti MIDI Mappings (Dynamic)...",invoke = function() pakettiMIDIMappingsDialog() end}



 

