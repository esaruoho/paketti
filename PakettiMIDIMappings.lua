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

  print(string.format("Found %d mappings in source files, %d are active in tool", 
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
  
  -- Update the global PakettiMidiMappings with discovered active mappings
  PakettiMidiMappings = active
  
  print("\n=== UPDATED PAKETTI MIDI MAPPINGS ===")
  print("PakettiMidiMappings table updated with " .. #active .. " active mappings")
  
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
  local note = vb:text{text="NOTE: This dialog shows DYNAMICALLY DISCOVERED MIDI mappings from your Lua files. Open Renoise's MIDI Mappings dialog (CMD-M), click arrow down to show list + searchbar, then click the buttons below.",style="strong",font="bold"}
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

  -- Function to rebuild the mappings display based on dropdown selection
  local function rebuild_mappings_display()
    print("DEBUG: Starting rebuild_mappings_display")
    
    -- Clear existing content
    while #mappings_view.views > 0 do
      mappings_view:remove_child(mappings_view.views[1])
    end
    
    -- Safety check: if no mappings to show, add a message
    if #mappings_to_show == 0 then
      local no_items_label = vb:text{
        text = "No mappings found for selected filter.",
        font = "italic"
      }
      mappings_view:add_child(no_items_label)
      print("DEBUG: No mappings to show")
      return
    end
    
    -- Get the selected filter
    local filter_value = alphabet_filter.value
    local filter_name = alphabet_filter.items[filter_value]
    print("DEBUG: Selected filter: " .. filter_name)
    
    -- Get mappings to show based on selection
    local mappings_to_show = {}
    if filter_value == 1 then -- "All Mappings"
      mappings_to_show = active_mappings
    else
      -- Filter alphabetically
      local ranges = {
        [2] = {string.byte('A'), string.byte('F')}, -- A-F
        [3] = {string.byte('G'), string.byte('M')}, -- G-M  
        [4] = {string.byte('N'), string.byte('S')}, -- N-S
        [5] = {string.byte('T'), string.byte('Z')}  -- T-Z
      }
      
      local range = ranges[filter_value]
      if range then
        for _, mapping in ipairs(active_mappings) do
          local clean_name = mapping:gsub("^[^:]*:", ""):gsub("^%s*", "")
          local first_byte = string.byte(string.upper(clean_name:sub(1,1)))
          if first_byte >= range[1] and first_byte <= range[2] then
            table.insert(mappings_to_show, mapping)
          end
        end
      end
    end
    
    print("DEBUG: Showing " .. #mappings_to_show .. " mappings")
    
    -- Create buttons for mappings in multiple columns
    local items_per_page_options = {25, 50, 75, 100, 150, 200, 250, 300, 350, 400}
    local max_items_to_show = items_per_page_options[items_per_page_filter.value]
    local rows_per_column_options = {10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70}
    local max_items_per_column = rows_per_column_options[rows_per_column_filter.value]
    local items_to_show = math.min(#mappings_to_show, max_items_to_show)
    
    -- Calculate number of columns needed
    local num_columns = math.max(1, math.ceil(items_to_show / max_items_per_column))
    
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
    
    -- Distribute buttons across columns
    for i = 1, items_to_show do
      local mapping = mappings_to_show[i]
      if mapping and mapping ~= "" then
        local button_text = mapping:gsub("Paketti:", ""):gsub("Track Automation:", ""):gsub("Sample Editor:", "")
        
        -- Ensure button text is not empty
        if button_text == "" then
          button_text = mapping  -- fallback to original mapping name
        end
        
        local button = vb:button{
          width = buttonWidth,
          text = button_text,
          midi_mapping = mapping
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
    
    -- Add count info to the first column
    local count_text = string.format("Showing %d of %d mappings (%s) in %d column%s", 
      items_to_show, #mappings_to_show, filter_name, num_columns, num_columns == 1 and "" or "s")
    if #mappings_to_show > max_items_to_show then
      count_text = count_text .. " [showing first " .. max_items_to_show .. "]"
    end
    
    local count_label = vb:text{
      text = count_text,
      font = "bold"
    }
    if #columns > 0 then
      columns[1]:add_child(count_label)
    end
    
    print("DEBUG: Added " .. items_to_show .. " buttons in " .. num_columns .. " columns")
  end
  print("DEBUG: Defined rebuild_mappings_display function")

  -- Now create the alphabetical filter dropdown (with notifier set during creation)
  alphabet_filter = vb:popup{
    items = {"All Mappings", "A-F", "G-M", "N-S", "T-Z"},
    width = 200,
    value = 1,
    notifier = rebuild_mappings_display
  }
  print("DEBUG: Created alphabet_filter")
  
  -- Create the items per page filter dropdown
  items_per_page_filter = vb:popup{
    items = {"25 items", "50 items", "75 items", "100 items", "150 items", "200 items", "250 items", "300 items", "350 items", "400 items"},
    width = 100,
    value = 2,  -- Default to 50 items
    notifier = rebuild_mappings_display
  }
  print("DEBUG: Created items_per_page_filter")
  
  -- Create the rows per column filter dropdown
  rows_per_column_filter = vb:popup{
    items = {"10 rows", "15 rows", "20 rows", "25 rows", "30 rows", "35 rows", "40 rows", "45 rows", "50 rows", "55 rows", "60 rows", "65 rows", "70 rows"},
    width = 100,
    value = 4,  -- Default to 25 rows
    notifier = rebuild_mappings_display
  }
  print("DEBUG: Created rows_per_column_filter")
  
  -- Add refresh button
  local refresh_button = vb:button{
    text = "Refresh MIDI Mappings",
    width = buttonWidth,
    notifier = function()
      -- Close and reopen dialog to refresh
      PakettiMidiMappingDialog:close()
      PakettiMidiMappingDialog = nil
      pakettiMIDIMappingsDialog()
    end
  }
  print("DEBUG: Created refresh_button")
  
  -- Add controls in a row
  local controls_row = vb:row{
    spacing = 10,
    vb:text{text = "Filter:"},
    alphabet_filter,
    vb:text{text = "Show:"},
    items_per_page_filter,
    vb:text{text = "Rows:"},
    rows_per_column_filter,
    refresh_button
  }
  dialog_content:add_child(controls_row)
  print("DEBUG: Added controls_row")

  -- Function to create a new column
  local function create_new_column()
    return vb:column{
      spacing = CONTENT_SPACING,
      width = COLUMN_WIDTH,
    }
  end
  print("DEBUG: Defined create_new_column function")

  -- Initial display build
  rebuild_mappings_display()
  print("DEBUG: Completed initial rebuild_mappings_display")

  -- Add the mappings view to the dialog  
  dialog_content:add_child(mappings_view)
  print("DEBUG: Added mappings_view to dialog_content")

  print("DEBUG: About to show dialog...")
  PakettiMidiMappingDialog = renoise.app():show_custom_dialog(
    "Paketti MIDI Mappings (Dynamic Discovery)", 
    dialog_content,
    function(dialog, key) return my_MidiMappingkeyhandler_func(dialog, key) end
  )
  print("DEBUG: Dialog shown successfully!")
end

-- Function to generate and print Paketti MIDI Mappings to console
function generate_paketti_midi_mappings()
  local active_mappings = update_paketti_midi_mappings()
  
  print("=== PAKETTI MIDI MAPPINGS (DISCOVERED) ===")
  for i, mapping in ipairs(active_mappings) do
    print(string.format("%03d: %s", i, mapping))
  end
  print(string.format("\nTotal: %d MIDI mappings discovered", #active_mappings))
end

-- Add keybindings and menu entries
renoise.tool():add_keybinding{name = "Global:Paketti:Paketti MIDI Mappings (Dynamic)...",invoke = function() pakettiMIDIMappingsDialog() end}
renoise.tool():add_keybinding{name = "Global:Paketti:Print Active MIDI Mappings to Console",invoke = print_active_midi_mappings}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate MIDI Mappings to Console",invoke = generate_paketti_midi_mappings}
renoise.tool():add_keybinding{name = "Global:Paketti:Extract MIDI Mappings to Console",invoke = extract_midi_mappings}

-- Add menu entry
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti..:!Preferences..:Paketti MIDI Mappings (Dynamic)...",invoke = function() pakettiMIDIMappingsDialog() end}

print("PakettiMIDIMappings.lua loaded - Dynamic MIDI mapping discovery ready!") 


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
  
  renoise.tool():add_keybinding{name="Global:Paketti:Verify Paketti MIDI Mappings",invoke=verify_paketti_midi_mappings}
