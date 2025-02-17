-- Define the mapping between menu names and their corresponding identifiers
local menu_to_identifier = {
  ["Track Automation"] = "Automation",
  ["Sample Mappings"] = "Sample Keyzones"
}

local function sortKeybindings(filteredKeybindings)
  table.sort(filteredKeybindings, function(a, b)
    -- Split each Topic into its parts
    local a_parts = {}
    local b_parts = {}
    
    -- Split by spaces and store each part
    for part in a.Topic:gmatch("%S+") do
      table.insert(a_parts, part)
    end
    for part in b.Topic:gmatch("%S+") do
      table.insert(b_parts, part)
    end
    
    -- First compare by Identifier
    if a.Identifier ~= b.Identifier then
      return a.Identifier < b.Identifier
    end
    
    -- Then compare each Topic part in order
    for i = 1, math.min(#a_parts, #b_parts) do
      if a_parts[i] ~= b_parts[i] then
        return a_parts[i] < b_parts[i]
      end
    end
    
    -- If one has more parts than the other, shorter comes first
    if #a_parts ~= #b_parts then
      return #a_parts < #b_parts
    end
    
    -- If Topics are identical, sort by Binding
    return a.Binding < b.Binding
  end)
end

-- Function to extract and print MIDI mappings from required files
function extract_midi_mappings()
  -- Define a list of required Lua files (replace with your actual files)
  local required_files = {
    "Paketti0G01_Loader.lua",
    "PakettiAudioProcessing.lua",
    "PakettiAutomation.lua",
    "PakettiBeatDetect.lua",
    "PakettiChordsPlus.lua",
    "PakettiYTDLP.lua",
    "PakettiControls.lua",
    "PakettiCustomization.lua",
    "PakettiDeviceChains.lua",
    "PakettiDynamicViews.lua",
    "PakettiEightOneTwenty.lua",
    "PakettieSpeak.lua",
    "PakettiExperimental_Verify.lua",
    "PakettiGater.lua",
    "PakettiImpulseTracker.lua",
    "PakettiInstrumentBox.lua",
    "PakettiLoadDevices.lua",
    "PakettiLoaders.lua",
    "PakettiLoadPlugins.lua",
    "PakettiMainMenuEntries.lua",
    "PakettiMidi.lua",
    "PakettiMidiPopulator.lua",
    "PakettiOctaMEDSuite.lua",
    "PakettiPatternEditor.lua",
    "PakettiPatternEditorCheatSheet.lua",
    "PakettiPatternMatrix.lua",
    "PakettiPatternSequencer.lua",
    "PakettiPhraseEditor.lua",
    "PakettiPlayerProSuite.lua",
    "PakettiRecorder.lua",
    "PakettiRequests.lua",
    "PakettiSampleLoader.lua",
    "PakettiSamples.lua",
    "PakettiSandbox.lua",
    "PakettiStacker.lua",
    "PakettiStretch.lua",
    "PakettiThemeSelector.lua",
    "PakettiTkna.lua",
    "PakettiTupletGenerator.lua",
    "PakettiWavetabler.lua"
  }

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
  for _, file in ipairs(required_files) do
    read_file_and_extract_midi_mappings(file)
  end

  -- Print the midi mappings in a format ready for pasting into the list
  print("\nPasteable Midi Mappings:\n")
  for _, mapping in ipairs(midi_mappings) do
    print('  "' .. mapping .. '",')
  end
end

-- Call the function to extract and print MIDI mappings
--extract_midi_mappings()


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
  "Paketti:Interpolate Effect Column Parameters",
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

-- Example grouped structure with direct paths
local grouped_mappings = {
  ["Groove Settings"] = {
    "Paketti:Groove Settings Groove #1 x[Knob]",
    "Paketti:Groove Settings Groove #2 x[Knob]",
    "Paketti:Groove Settings Groove #3 x[Knob]",
    "Paketti:Groove Settings Groove #4 x[Knob]"
  },
  ["Loading/Saving Samples/Instruments"] = {
    "Paketti:Midi Paketti PitchBend Multiple Sample Loader",
    "Paketti:Midi Paketti PitchBend Drumkit Sample Loader",
    "Paketti:Midi Paketti Save Selected Sample .WAV",
    "Paketti:Midi Paketti Save Selected Sample .FLAC",
    "Paketti:Save Sample Range .WAV",
    "Paketti:Save Sample Range .FLAC",
    "Paketti:Send Selected Sample to AppSelection1",
    "Paketti:Send Selected Sample to AppSelection2",
    "Paketti:Send Selected Sample to AppSelection3",
    "Paketti:Send Selected Sample to AppSelection4",
    "Paketti:Send Selected Sample to AppSelection5",
    "Paketti:Send Selected Sample to AppSelection6",
    "Paketti:Save Sample to Smart/Backup Folder 1",
    "Paketti:Save Sample to Smart/Backup Folder 2",
    "Paketti:Save Sample to Smart/Backup Folder 3",
    "Paketti:Save All Samples to Smart/Backup Folder 1",
    "Paketti:Save All Samples to Smart/Backup Folder 2",
    "Paketti:Save All Samples to Smart/Backup Folder 3"
  },
  ["Sample Editor"] = {
    "Paketti:Shift Sample Buffer Up x[Trigger]",
    "Paketti:Shift Sample Buffer Down x[Trigger]",
    "Paketti:Shift Sample Buffer Up x[Knob]",
    "Paketti:Shift Sample Buffer Down x[Knob]",
    "Paketti:Shift Sample Buffer Up/Down x[Knob]",
    "Paketti:Strip Silence",
    "Paketti:Move Beginning Silence to End",
    "Paketti:Set Beatsync Value x[Knob]",
    "Paketti:Midi Change Sample Modulation Set Filter",
    "Paketti:Duplicate and Reverse Instrument [Trigger]",  
    "Paketti:Isolate Slices or Samples to New Instruments",  
    "Paketti:Change Selected Sample Volume x[Slider]",
    "Paketti:Change Selected Sample Loop Mode [x]Knob",
    "Paketti:Selected Sample Loop to 1 No Loop x[On]",
    "Paketti:Selected Sample Loop to 2 Forward x[On]",
    "Paketti:Selected Sample Loop to 3 Backward x[On]",
    "Paketti:Selected Sample Loop to 4 PingPong x[On]",
    "Paketti:Selected Sample Loop to 1 No Loop x[Toggle]",
    "Paketti:Selected Sample Loop to 2 Forward x[Toggle]",
    "Paketti:Selected Sample Loop to 3 Backward x[Toggle]",
    "Paketti:Selected Sample Loop to 4 PingPong x[Toggle]",
    "Paketti:Cycle Sample Editor Tabs",
    "Paketti:Create New Instrument & Loop from Selection",    
    "Paketti:Midi Change Selected Sample Loop 01 Start x[Knob]",
    "Sample Editor:Paketti:Sample Buffer Selection 01 Start x[Knob]",
    "Sample Editor:Paketti:Sample Buffer Selection 02 End x[Knob]",
    "Sample Editor:Paketti:Sample Buffer Selection Halve",
    "Sample Editor:Paketti:Sample Buffer Selection Double",
    "Sample Editor:Paketti:Mono to Right with Blank Left",
    "Sample Editor:Paketti:Mono to Left with Blank Right",
    "Sample Editor:Paketti:Convert Mono to Stereo",    
    "Paketti:Midi Select Padded Slice (Next)",
    "Paketti:Midi Select Padded Slice (Previous)",
    "Paketti:Rotate Sample Buffer Content Forward [Set]",
    "Paketti:Rotate Sample Buffer Content Backward [Set]",
    "Sample Editor:Paketti:Disk Browser Focus" 
  },
  ["Playback Control"] = {
    "Paketti:Impulse Tracker F5 Start Playback x[Toggle]",
    "Paketti:Impulse Tracker F8 Stop Playback (Panic) x[Toggle]",
    "Paketti:Impulse Tracker F7 Start Playback from Cursor Row x[Toggle]",
    "Paketti:Simple Play",
    "Paketti:Simple Play Record Follow",
    "Paketti:Stop Playback (Panic) x[Toggle]",
    "Paketti:Play Current Line & Advance by EditStep x[Toggle]",
    "Paketti:Impulse Tracker F8 Stop Playback (Panic) x[Toggle]"
  },
  ["Pattern Editor"] = {
    "Paketti:Record to Current Track x[Toggle]",
    "Paketti:Jump to First Track in Next Group",
    "Paketti:Jump to First Track in Previous Group",
    "Paketti:Slide Selected Column Content Down",
    "Paketti:Slide Selected Column Content Up",
    "Paketti:Slide Selected Track Content Up",
    "Paketti:Slide Selected Track Content Down",
    "Paketti:Capture Nearest Instrument and Octave",
    "Paketti:Flood Fill Note and Instrument",
    "Paketti:Flood Fill Note and Instrument with EditStep",
    "Paketti:Paketti Track Renamer",  
    "Paketti:Duplicate Effect Column Content to Pattern or Selection",
    "Paketti:Randomize Effect Column Parameters",
    "Paketti:Note Interpolation",
    "Paketti:Interpolate Effect Column Parameters",
    "Paketti:Effect Column B00 Reverse Sample Effect On/Off",
    "Paketti:Delay Column (DEPRECATED) x[Slider]",
    "Paketti:Set Delay (+1) x[Toggle]",
    "Paketti:Set Delay (-1) x[Toggle]",
    "Paketti:Toggle Mute Tracks",
    "Paketti:Toggle Solo Tracks",    
    "Paketti:Uncollapser",
    "Paketti:Collapser",
    "Paketti:Midi Change 01 Volume Column Value x[Knob]",
    "Paketti:Midi Change 02 Panning Column Value x[Knob]",
    "Paketti:Midi Change 03 Delay Column Value x[Knob]",
    "Paketti:Midi Change 04 Effect Column Value x[Knob]",
    "Paketti:Impulse Tracker Pattern (Next) x[Toggle]",
    "Paketti:Impulse Tracker Pattern (Previous) x[Toggle]",
    "Pattern Editor:Paketti:Disk Browser Focus",
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
    "Paketti:Set Pattern Length to 512"
  },
  ["Automation"] = {
    "Paketti:Switch to Automation",
    "Track Automation:Paketti:Midi Automation Curve Draw Selection x[Knob]",
    "Paketti:Midi Automation Selection 01 Start x[Knob]",
    "Paketti:Midi Automation Selection 02 End x[Knob]"
  },  
  ["Pattern Sequencer/Matrix"] = {
    "Paketti:Show/Hide Pattern Matrix x[Toggle]",  
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
    "Paketti:Clone Current Sequence"

  },
  ["Controls"] = {
    "Paketti:Set EditStep to 00",
    "Paketti:Midi Change EditStep 1-64 x[Knob]",
    "Paketti:Midi Change EditStep 0-64 x[Knob]",
    "Paketti:EditStep Double x[Button]",
    "Paketti:EditStep Halve x[Button]",
    "Paketti:Midi Select Group (Next)",
    "Paketti:Midi Select Group (Previous)",
    "Paketti:Midi Select Track (Next)",
    "Paketti:Midi Select Track (Previous)",
    "Paketti:Midi Select Group Tracks x[Knob]",
    "Paketti:Move to Next Track (Wrap) [Knob]",
    "Paketti:Move to Previous Track (Wrap) [Knob]",
    "Paketti:Numpad SelectPlay 0 x[Toggle]",
    "Paketti:Numpad SelectPlay 1 x[Toggle]",
    "Paketti:Numpad SelectPlay 2 x[Toggle]",
    "Paketti:Numpad SelectPlay 3 x[Toggle]",
    "Paketti:Numpad SelectPlay 4 x[Toggle]",
    "Paketti:Numpad SelectPlay 5 x[Toggle]",
    "Paketti:Numpad SelectPlay 6 x[Toggle]",
    "Paketti:Numpad SelectPlay 7 x[Toggle]",
    "Paketti:Numpad SelectPlay 8 x[Toggle]",
    "Paketti:Computer Keyboard Velocity Slider x[Knob]",
    "Paketti:Move to Next Track [Knob]",
    "Paketti:Move to Previous Track [Knob]",
    "Paketti:Metronome On/Off x[Toggle]",
    "Paketti:Record and Follow x[Toggle]",
    "Paketti:Record and Follow On/Off x[Knob]",
    "Paketti:Record Quantize On/Off x[Toggle]",    
    "Paketti:Toggle Edit Mode and Tint Track",
    "Paketti:Paketti Track Renamer",
    "Paketti:Octave Basenote Up",
    "Paketti:Octave Basenote Down",
    "Paketti:Midi Change Octave x[Knob]",
    "Paketti:Midi Change Selected Track x[Knob]",
    "Paketti:Midi Change Selected Track DSP Device x[Knob]",
    "Paketti:Midi Change Selected Instrument x[Knob]",
  },
  ["Wipe&Slice"] = {
    "Paketti:Wipe&Slice (004) x[Toggle]",
    "Paketti:Wipe&Slice (008) x[Toggle]",
    "Paketti:Wipe&Slice (016) x[Toggle]",
    "Paketti:Wipe&Slice (032) x[Toggle]",
    "Paketti:Wipe&Slice (064) x[Toggle]",
    "Paketti:Wipe&Slice (128) x[Toggle]",  
  },
  ["Track DSP Control"] = {
    "Paketti:Bypass All Other Track DSP Devices (Toggle)",  
    "Paketti:Hide Track DSP Device External Editors for All Tracks",  
    "Track Devices:Paketti:Load DC Offset",
    "Paketti:Midi Change Selected Track DSP Device x[Knob]"
  }
}

-- Determine the "Unused Mappings" by filtering out used mappings
local used_mappings = {}
for _, group in pairs(grouped_mappings) do
  for _, mapping in ipairs(group) do
    used_mappings[mapping] = true
  end
end

-- Collect unused mappings
local unused_mappings = {}
for _, mapping in ipairs(PakettiMidiMappings) do
  if not used_mappings[mapping] then
    table.insert(unused_mappings, mapping)
  end
end

-- Add "Unused Mappings" to grouped_mappings
grouped_mappings["Unused Mappings"] = unused_mappings

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
function show_midi_mappings_dialog()
  -- Close the dialog if it's already open
  if PakettiMidiMappingDialog and PakettiMidiMappingDialog.visible then
    PakettiMidiMappingDialog:close()
    PakettiMidiMappingDialog = nil
    return
  end

  -- Initialize the ViewBuilder
  local vb = renoise.ViewBuilder()

  -- Define dialog properties
  local DIALOG_MARGIN = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN
  local CONTENT_SPACING = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING
  local MAX_ITEMS_PER_COLUMN = 41
  local COLUMN_WIDTH = 220
  local buttonWidth = 200  -- Adjustable global button width

  -- Create the main column for the dialog
  local dialog_content = vb:column {
    margin = DIALOG_MARGIN,
    spacing = CONTENT_SPACING,
  }

  -- Add introductory note
  local note = vb:text {
    text = "NOTE: Open up the Renoise Midi Mappings dialog (CMD-M on macOS), click on the arrow down to show list + searchbar, then click on a button in this dialog to display it.",
    style = "strong",
    font="bold"
  }
  dialog_content:add_child(note)

  -- Function to create a new column
  local function create_new_column()
    return vb:column {
      spacing = CONTENT_SPACING,
      width = COLUMN_WIDTH,
    }
  end

  local current_row = vb:row {}
  dialog_content:add_child(current_row)
  local current_column = create_new_column()
  current_row:add_child(current_column)
  local item_count = 0

  -- Optimized sorted group titles
  local sorted_group_titles = {
    "Playback Control",
    "Wipe&Slice",
    "Groove Settings",
    "Loading/Saving Samples/Instruments",
    "Automation",
    "Track DSP Control",
    "Controls",
    "Sample Editor",
    "Pattern Editor"
  }

  -- Add "Unused Mappings" to the list if there are any
  if #grouped_mappings["Unused Mappings"] > 0 then
    table.insert(sorted_group_titles, "Unused Mappings")
  end

  -- Iterate over the sorted grouped mappings and create GUI elements
  for _, group_title in ipairs(sorted_group_titles) do
    local mappings = grouped_mappings[group_title]
    if mappings then
      -- Calculate total items including the title
      local total_items = #mappings + 1

      -- Check if adding this group would exceed the max items per column
      if item_count + total_items > MAX_ITEMS_PER_COLUMN then
        -- Create a new column
        current_column = create_new_column()
        current_row:add_child(current_column)
        item_count = 0
      end

      -- Add the group title
      local group_title_text = vb:text {
        text = group_title,
        font = "bold",
        style = "strong",
      }
      current_column:add_child(group_title_text)
      item_count = item_count + 1

      -- Add buttons for each mapping in the group
      for _, mapping in ipairs(mappings) do
        local button_text = mapping:gsub("Paketti:", ""):gsub("Track Automation:", ""):gsub("Sample Editor:", "Sample Editor:")
        current_column:add_child(vb:button {
          width = buttonWidth,
          text = button_text,
          midi_mapping = mapping
        })
        item_count = item_count + 1

        -- Check if we need to start a new column
        if item_count >= MAX_ITEMS_PER_COLUMN then
          current_column = create_new_column()
          current_row:add_child(current_column)
          item_count = 0
        end
      end
    end
  end

  -- Show the custom dialog with key handler
  PakettiMidiMappingDialog = renoise.app():show_custom_dialog(
    "Paketti MIDI Mappings",
    dialog_content,
    function(dialog, key) return my_MidiMappingkeyhandler_func(dialog, key) end
  )
end

-- Function to generate and print Paketti MIDI Mappings to console
function generate_paketti_midi_mappings()
  print("Paketti MIDI Mappings:")
  for group_title, mappings in pairs(grouped_mappings) do
    print("\n" .. group_title)
    for _, mapping in ipairs(mappings) do
      print("  " .. mapping)
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti MIDI Mappings...",
  invoke=function() show_midi_mappings_dialog() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:!Preferences..:Paketti MIDI Mappings...",
  invoke=function() show_midi_mappings_dialog() end}
renoise.tool():add_keybinding{name="Global:Paketti:Generate Paketti Midi Mappings to Console",
  invoke=function() generate_paketti_midi_mappings() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:!Preferences..:Debug..:Generate Paketti Midi Mappings to Console",
  invoke=function() generate_paketti_midi_mappings() end}


----

-- Variable declarations
local vb = renoise.ViewBuilder()
local dialog
local debug_log = ""
local suppress_debug_log
local pakettiKeybindings = {}
local identifier_switch
local keybinding_list
local total_shortcuts_text
local selected_shortcuts_text
local show_shortcuts_switch
local show_script_filter_switch  -- Add this line
local search_text
local search_textfield
local padding_number_identifier = 5  -- Padding between number and identifier
local padding_identifier_topic = 25  -- Padding between identifier and topic
local padding_topic_binding = 25  -- Padding between topic and binding

-- Function to detect OS and construct the KeyBindings.xml path
function detectOSAndGetKeyBindingsPath()
  local os_name = os.platform()
  local renoise_version = renoise.RENOISE_VERSION
  local key_bindings_path

  if os_name == "WINDOWS" then
    local home = os.getenv("USERPROFILE") or os.getenv("HOME")
    key_bindings_path = home .. "\\AppData\\Roaming\\Renoise\\V" .. renoise_version .. "\\KeyBindings.xml"
  elseif os_name == "MACINTOSH" then
    local home = os.getenv("HOME")
    key_bindings_path = home .. "/Library/Preferences/Renoise/V" .. renoise_version .. "/KeyBindings.xml"
  else -- Assume Linux
    local home = os.getenv("HOME")
    key_bindings_path = home .. "/.config/Renoise/V" .. renoise_version .. "/KeyBindings.xml"
  end

  return key_bindings_path
end

-- Function to replace XML encoded entities with their corresponding characters
local function decodeXMLString(value)
  local replacements = {
    ["&amp;"] = "&",
    -- Add more replacements if needed
  }
  return value:gsub("(&amp;)", replacements)
end

-- Function to parse XML and find Paketti content
function pakettiKeyBindingsParseXML(filePath)
  local fileHandle = io.open(filePath, "r")
  if not fileHandle then
    debug_log = debug_log .. "Debug: Failed to open the file - " .. filePath .. "\n"
    return {}
  end

  local content = fileHandle:read("*all")
  fileHandle:close()

  local pakettiKeybindings = {}
  local currentIdentifier = "nil"

  for categorySection in content:gmatch("<Category>(.-)</Category>") do
    local identifier = categorySection:match("<Identifier>(.-)</Identifier>") or "nil"
    if identifier ~= "nil" then
      currentIdentifier = identifier
    end

    for keyBindingSection in categorySection:gmatch("<KeyBinding>(.-)</KeyBinding>") do
      local topic = keyBindingSection:match("<Topic>(.-)</Topic>")
      if topic and topic:find("Paketti") then
        local binding = keyBindingSection:match("<Binding>(.-)</Binding>") or "<No Binding>"
        local key = keyBindingSection:match("<Key>(.-)</Key>") or "<Shortcut not Assigned>"

        -- Decode XML entities
        topic = decodeXMLString(topic)
        binding = decodeXMLString(binding)
        key = decodeXMLString(key)

        table.insert(pakettiKeybindings, { Identifier = currentIdentifier, Topic = topic, Binding = binding, Key = key })
        debug_log = debug_log .. "Debug: Found Paketti keybinding - " .. currentIdentifier .. ":" .. topic .. ":" .. binding .. ":" .. key .. "\n"
      end
    end
  end

  return pakettiKeybindings
end

-- Function to save the debug log
function pakettiKeyBindingsSaveDebugLog(filteredKeybindings, showUnassignedOnly)
  if not pakettiKeybindings then return end -- Ensure pakettiKeybindings is not nil

  local filePath = "KeyBindings/Debug_Paketti_KeyBindings.log"
  local fileHandle = io.open(filePath, "w")
  if fileHandle then
    local log_content = "Debug: Total Paketti keybindings found - " .. #pakettiKeybindings .. "\n"
    local count = 0
    for index, binding in ipairs(filteredKeybindings) do
      if not showUnassignedOnly or (showUnassignedOnly and binding.Key == "<Shortcut not Assigned>") then
        count = count + 1
        log_content = log_content .. string.format("%04d", count) .. ":" .. binding.Identifier .. ":" .. binding.Topic .. ": " .. binding.Binding .. ": " .. binding.Key .. "\n"
      end
    end
    fileHandle:write(log_content)
    fileHandle:close()
    renoise.app():show_status("Debug log saved to: " .. filePath)
  else
    renoise.app():show_status("Failed to save debug log.")
  end
end

-- Function to calculate the maximum length for entries
function pakettiCalculateMaxLength(entries)
  local max_length = 0
  for _, entry in ipairs(entries) do
    -- Account for the visual difference caused by the squiggle character
    local length_adjustment = entry.Binding:find("∿") and 2 or 0
    local length = #(string.format("%04d", 0) .. ":" .. entry.Identifier .. ":" .. entry.Topic .. ": " .. entry.Binding) - length_adjustment
    max_length = math.max(max_length, length)
  end
  return max_length
end

-- Function to update the list view based on the filter
function pakettiKeyBindingsUpdateList()
  if not identifier_switch then return end -- Ensure the switch is initialized

  local showUnassignedOnly = (show_shortcuts_switch.value == 2)
  local showAssignedOnly = (show_shortcuts_switch.value == 3)
  local scriptFilter = show_script_filter_switch.value  -- Get value from the switch
  local selectedIdentifier = identifier_switch.items[identifier_switch.value]
  local searchQuery = search_textfield.value:lower()
  local content = ""
  local count = 0
  local unassigned_count = 0
  local selected_count = 0
  local selected_unassigned_count = 0

  local filteredKeybindings = {}

  for _, binding in ipairs(pakettiKeybindings) do
    local isSelected = (selectedIdentifier == "All") or (binding.Identifier == selectedIdentifier)
    -- Normalize to lowercase for case-insensitive search
    local topic_lower = binding.Topic:lower()
    local binding_lower = binding.Binding:lower()
    local identifier_lower = binding.Identifier:lower()

    -- Display all entries if searchQuery is empty, otherwise match the query
    local matchesSearch = true
    for word in searchQuery:gmatch("%S+") do
      if not (topic_lower:find(word) or binding_lower:find(word) or identifier_lower:find(word) or binding.Key:lower():find(word)) then
        matchesSearch = false
        break
      end
    end

    -- Check if the entry should be included based on the scriptFilter
    local isScript = binding.Binding:find("∿") ~= nil
    local matchesScriptFilter = (scriptFilter == 1) or (scriptFilter == 2 and not isScript) or (scriptFilter == 3 and isScript)

    if isSelected and matchesSearch and matchesScriptFilter then
      -- Count unassigned regardless of show_unassigned_only
      if binding.Key == "<Shortcut not Assigned>" then
        unassigned_count = unassigned_count + 1
      end

      -- Filter based on the selected option (Show All, Show without Shortcuts, Show with Shortcuts)
      if (showUnassignedOnly and binding.Key == "<Shortcut not Assigned>") or
         (showAssignedOnly and binding.Key ~= "<Shortcut not Assigned>") or
         (not showUnassignedOnly and not showAssignedOnly) then

        table.insert(filteredKeybindings, binding)

        if binding.Key == "<Shortcut not Assigned>" then
          selected_unassigned_count = selected_unassigned_count + 1
        end

        selected_count = selected_count + 1
      end
    end
    count = count + 1
  end

  sortKeybindings(filteredKeybindings)

  if #filteredKeybindings == 0 then
    content = "No KeyBindings available for this filter."
  else
    -- Calculate max length across all entries
    local max_length = pakettiCalculateMaxLength(pakettiKeybindings) + 35

    -- Append the key, aligned right
    for index, binding in ipairs(filteredKeybindings) do
      local entry = string.format("%04d", index)
        .. string.rep(" ", padding_number_identifier) .. binding.Identifier
        .. string.rep(" ", padding_identifier_topic - #binding.Identifier)
        .. binding.Topic
        .. string.rep(" ", padding_topic_binding - #binding.Topic)
        .. binding.Binding

      -- Adjust the visual difference caused by the squiggle character
      local length_adjustment = binding.Binding:find("∿") and 2 or 0
      local padded_entry = entry .. string.rep(" ", max_length - #entry + length_adjustment) .. " " .. binding.Key
      content = content .. padded_entry .. "\n"
    end
  end

  keybinding_list.text = content

  local selectedText = ""
  if selectedIdentifier == "All" then
    selectedText = "For all sections, there are " .. selected_count .. " shortcuts and " .. selected_unassigned_count .. " are unassigned."
  else
    selectedText = "For " .. selectedIdentifier .. ", there are " .. selected_count .. " shortcuts and " .. selected_unassigned_count .. " are unassigned."
  end

  selected_shortcuts_text.text = selectedText
  total_shortcuts_text.text = "Total: " .. count .. " shortcuts, " .. unassigned_count .. " unassigned."

  if not suppress_debug_log then
    pakettiKeyBindingsSaveDebugLog(filteredKeybindings, showUnassignedOnly)
  end
end

-- Function to handle key events
function my_PakettiKeybindingskeyhandler_func(dialog, key)
local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    dialog = nil
    return nil
else
    return key
end
end

-- Main function to display the Paketti keybindings dialog
function showPakettiKeyBindingsDialog(selectedIdentifier)  -- Accept an optional parameter
  -- Check if the dialog is already visible and close it
  if dialog and dialog.visible then
    dialog:close()
    return
  end

  -- Map menu identifiers to their internal names
  if selectedIdentifier then
    selectedIdentifier = menu_to_identifier[selectedIdentifier] or selectedIdentifier
  end

  local keyBindingsPath = detectOSAndGetKeyBindingsPath()
  if not keyBindingsPath then
    renoise.app():show_status("Failed to detect OS and find KeyBindings.xml path.")
    return
  end

  debug_log = debug_log .. "Debug: Using KeyBindings path - " .. keyBindingsPath .. "\n"
  pakettiKeybindings = pakettiKeyBindingsParseXML(keyBindingsPath)
  if not pakettiKeybindings or #pakettiKeybindings == 0 then
    renoise.app():show_status("No Paketti keybindings found.")
    debug_log = debug_log .. "Debug: Total Paketti keybindings found - 0\n"
    pakettiKeyBindingsSaveDebugLog(pakettiKeybindings, false)
    return
  end

  -- Print total found count at the start
  debug_log = "Debug: Total Paketti keybindings found - " .. #pakettiKeybindings .. "\n" .. debug_log

  -- Collect all unique Identifiers and sort them alphabetically
  local identifier_items = { "All" }
  local unique_identifiers = {}
  for _, binding in ipairs(pakettiKeybindings) do
    if not unique_identifiers[binding.Identifier] then
      unique_identifiers[binding.Identifier] = true
      table.insert(identifier_items, binding.Identifier)
    end
  end
  table.sort(identifier_items)

  -- Determine the index of the selectedIdentifier
  local selected_index = 1 -- Default to "All"
  if selectedIdentifier then
    -- Map the identifier before looking for its index
    local mapped_identifier = menu_to_identifier[selectedIdentifier] or selectedIdentifier
    for i, id in ipairs(identifier_items) do
      if id == mapped_identifier then
        selected_index = i
        break
      end
    end
  end

  identifier_switch = vb:popup {
    items = identifier_items,
    width = 300,
    value = selected_index,
    notifier = pakettiKeyBindingsUpdateList
  }

  -- Create the switch for showing/hiding shortcuts
  show_shortcuts_switch = vb:switch {
    items = { "Show All", "Show KeyBindings without Shortcuts", "Show KeyBindings with Shortcuts" },
    width = 1100,
    value = 1, -- Default to "Show All"
    notifier = pakettiKeyBindingsUpdateList
  }

  show_script_filter_switch = vb:switch {
    items = { "All", "Show without Tools", "Show Only Tools" },
    width = 1100,
    value = 1,
    notifier = function(value)
      pakettiKeyBindingsUpdateList()
      if value == 1 then
        renoise.app():show_status("Now showing all KeyBindings")
      elseif value == 2 then
        renoise.app():show_status("Now showing KeyBindings without Tools")
      elseif value == 3 then
        renoise.app():show_status("Now showing KeyBindings with only Tools")
      end
    end
  }

  -- UI Elements
  search_textfield = vb:textfield {
    width = 300,
    notifier = pakettiKeyBindingsUpdateList
  }

  total_shortcuts_text = vb:text {
    text = "Total: 0 shortcuts, 0 unassigned",
    font = "bold",
    width = 1100, -- Adjusted width to fit the dialog
    align = "left"
  }

  selected_shortcuts_text = vb:text {
    text = "For selected sections, there are 0 shortcuts and 0 are unassigned.",
    font = "bold",
    width = 1100, -- Adjusted width to fit the dialog
    align = "left"
  }

  search_text = vb:text{text="Filter with"}


  keybinding_list = vb:multiline_textfield { width = 1100, height = 600, font = "mono" }

  -- Dialog title including Renoise version
  local dialog_title = "Paketti KeyBindings for Renoise Version " .. renoise.RENOISE_VERSION

  dialog = renoise.app():show_custom_dialog(
    dialog_title,
    vb:column {
      margin = 10,
      vb:text {
        text = "NOTE: KeyBindings.xml is only saved when Renoise is closed - so this is not a realtime / updatable Dialog. Make changes, quit Renoise, and relaunch this Dialog.",
        font = "bold"
      },
      identifier_switch,
      show_shortcuts_switch,
vb:row{vb:button{text="Save as Textfile", notifier = function()
    local filename = renoise.app():prompt_for_filename_to_write(".txt", "Available Plugins Saver")
    if filename then
      local file, err = io.open(filename, "w")
      if file then
        file:write(keybinding_list.text)  -- Correct reference to multiline_field's text
        file:close()
        renoise.app():show_status("File saved successfully")
      else
        renoise.app():show_status("Error saving file: " .. err)
      end
    end
  end}},

      search_text,
      search_textfield,
      keybinding_list,
      selected_shortcuts_text,
      total_shortcuts_text
    },
    my_PakettiKeybindingskeyhandler_func  -- Key handler function
  )

  -- Initial list update
  pakettiKeyBindingsUpdateList()

  -- Print total found count at the end
  debug_log = debug_log .. "Debug: Total Paketti keybindings found - " .. #pakettiKeybindings .. "\n"
  pakettiKeyBindingsSaveDebugLog(pakettiKeybindings, false)
end

-- Add main menu entry for Paketti keybindings dialog
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:!Preferences..:Paketti KeyBindings...",invoke=function() showPakettiKeyBindingsDialog() end}


-- Single list of valid menu locations (using correct menu paths)
local menu_entries = {
  "Track Automation",  -- This will map to "Automation"
  "Disk Browser",
  "DSP Chain",
  "Instrument Box",
  "Mixer",
  "Pattern Editor",
  "Pattern Matrix",
  "Pattern Sequencer",
  "Phrase Editor",
  "Phrase Map",
  "Sample Editor",
  "Sample FX Mixer",
  "Sample Mappings",  -- This will map to "Sample Keyzones"
  "Sample Modulation Matrix"
}

-- Add menu entries for both Paketti and Renoise KeyBindings
for _, menu_name in ipairs(menu_entries) do
  -- Get the correct identifier (handle special cases)
  local identifier = menu_to_identifier[menu_name] or menu_name
  
  -- Add Paketti KeyBindings entry
  renoise.tool():add_menu_entry{name=menu_name .. ":Paketti..:Show Paketti KeyBindings...",
    invoke=function() showPakettiKeyBindingsDialog(identifier) end
  }
  
  -- Add Renoise KeyBindings entry
  renoise.tool():add_menu_entry{name=menu_name .. ":Paketti..:Show Renoise KeyBindings...",
    invoke=function() showRenoiseKeyBindingsDialog(identifier) end
  }
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:!Preferences..:Renoise KeyBindings...",
  invoke=function() showRenoiseKeyBindingsDialog() end}

renoise.tool():add_keybinding{name="Global:Paketti:Show Paketti KeyBindings Dialog...",
  invoke=function() showPakettiKeyBindingsDialog() end}

renoise.tool():add_keybinding{name="Global:Paketti:Show Renoise KeyBindings Dialog...",
  invoke=function() showRenoiseKeyBindingsDialog() end}

-------------------------------------------

local vb = renoise.ViewBuilder()
local renoise_dialog
local renoise_debug_log = ""
local renoise_suppress_debug_log
local renoiseKeybindings = {}
local renoise_identifier_dropdown
local renoise_keybinding_list
local renoise_total_shortcuts_text
local renoise_selected_shortcuts_text
local renoise_show_shortcuts_switch
local renoise_show_script_filter_switch
local renoise_search_text
local renoise_search_textfield
local padding_number_identifier = 5  -- Padding between number and identifier
local padding_identifier_topic = 25  -- Padding between identifier and topic
local padding_topic_binding = 25  -- Padding between topic and binding

-- Function to detect OS and construct the KeyBindings.xml path
function detectOSAndGetKeyBindingsPath()
  local os_name = os.platform()
  local renoise_version = renoise.RENOISE_VERSION
  local key_bindings_path

  if os_name == "WINDOWS" then
    local home = os.getenv("USERPROFILE") or os.getenv("HOME")
    key_bindings_path = home .. "\\AppData\\Roaming\\Renoise\\V" .. renoise_version .. "\\KeyBindings.xml"
  elseif os_name == "MACINTOSH" then
    local home = os.getenv("HOME")
    key_bindings_path = home .. "/Library/Preferences/Renoise/V" .. renoise_version .. "/KeyBindings.xml"
  else -- Assume Linux
    local home = os.getenv("HOME")
    key_bindings_path = home .. "/.config/Renoise/V" .. renoise_version .. "/KeyBindings.xml"
  end

  return key_bindings_path
end

-- Function to replace XML encoded entities with their corresponding characters
local function decodeXMLString(value)
  local replacements = {
    ["&amp;"] = "&",
    -- Add more replacements if needed
  }
  return value:gsub("(&amp;)", replacements)
end

-- Function to parse XML and find Renoise content
function renoiseKeyBindingsParseXML(filePath)
  local fileHandle = io.open(filePath, "r")
  if not fileHandle then
    renoise_debug_log = renoise_debug_log .. "Debug: Failed to open the file - " .. filePath .. "\n"
    return {}
  end

  local content = fileHandle:read("*all")
  fileHandle:close()

  local renoiseKeybindings = {}
  local currentIdentifier = "nil"

  for categorySection in content:gmatch("<Category>(.-)</Category>") do
    local identifier = categorySection:match("<Identifier>(.-)</Identifier>") or "nil"
    if identifier ~= "nil" then
      currentIdentifier = identifier
    end

    for keyBindingSection in categorySection:gmatch("<KeyBinding>(.-)</KeyBinding>") do
      local topic = keyBindingSection:match("<Topic>(.-)</Topic>")
      if topic then
        local binding = keyBindingSection:match("<Binding>(.-)</Binding>") or "<No Binding>"
        local key = keyBindingSection:match("<Key>(.-)</Key>") or "<Shortcut not Assigned>"

        -- Decode XML entities
        topic = decodeXMLString(topic)
        binding = decodeXMLString(binding)
        key = decodeXMLString(key)

        table.insert(renoiseKeybindings, { Identifier = currentIdentifier, Topic = topic, Binding = binding, Key = key })
        renoise_debug_log = renoise_debug_log .. "Debug: Found Renoise keybinding - " .. currentIdentifier .. ":" .. topic .. ":" .. binding .. ":" .. key .. "\n"
      end
    end
  end

  return renoiseKeybindings
end

-- Function to save the debug log
function renoiseKeyBindingsSaveDebugLog(filteredKeybindings, showUnassignedOnly)
  if not renoiseKeybindings then return end -- Ensure renoiseKeybindings is not nil

  local filePath = "KeyBindings/Debug_Renoise_KeyBindings.log"
  local fileHandle = io.open(filePath, "w")
  if fileHandle then
    local log_content = "Debug: Total Renoise keybindings found - " .. #renoiseKeybindings .. "\n"
    local count = 0
    for index, binding in ipairs(filteredKeybindings) do
      if not showUnassignedOnly or (showUnassignedOnly and binding.Key == "<Shortcut not Assigned>") then
        count = count + 1
        log_content = log_content .. string.format("%04d", count) .. ":" .. binding.Identifier .. ":" .. binding.Topic .. ": " .. binding.Binding .. ": " .. binding.Key .. "\n"
      end
    end
    fileHandle:write(log_content)
    fileHandle:close()
    renoise.app():show_status("Debug log saved to: " .. filePath)
  else
    renoise.app():show_status("Failed to save debug log.")
  end
end

-- Function to calculate the maximum length for entries
function renoiseCalculateMaxLength(entries)
  local max_length = 0
  for _, entry in ipairs(entries) do
    -- Account for the visual difference caused by the squiggle character
    local length_adjustment = entry.Binding:find("∿") and 2 or 0
    local length = #(string.format("%04d", 0) .. ":" .. entry.Identifier .. ":" .. entry.Topic .. ": " .. entry.Binding) - length_adjustment
    max_length = math.max(max_length, length)
  end
  return max_length
end

-- Function to update the list view based on the filter
function renoiseKeyBindingsUpdateList()
  if not renoise_identifier_dropdown then return end -- Ensure the dropdown is initialized

  local showUnassignedOnly = (renoise_show_shortcuts_switch.value == 2)
  local showAssignedOnly = (renoise_show_shortcuts_switch.value == 3)
  local scriptFilter = renoise_show_script_filter_switch.value
  local selectedIdentifier = renoise_identifier_dropdown.items[renoise_identifier_dropdown.value]
  local searchQuery = renoise_search_textfield.value:lower()
  local content = ""
  local count = 0
  local unassigned_count = 0
  local selected_count = 0
  local selected_unassigned_count = 0

  local filteredKeybindings = {}

  for _, binding in ipairs(renoiseKeybindings) do
    local isSelected = (selectedIdentifier == "All") or (binding.Identifier == selectedIdentifier)
    -- Normalize to lowercase for case-insensitive search
    local topic_lower = binding.Topic:lower()
    local binding_lower = binding.Binding:lower()
    local identifier_lower = binding.Identifier:lower()

    -- Display all entries if searchQuery is empty, otherwise match the query
    local matchesSearch = true
    for word in searchQuery:gmatch("%S+") do
      if not (topic_lower:find(word) or binding_lower:find(word) or identifier_lower:find(word) or binding.Key:lower():find(word)) then
        matchesSearch = false
        break
      end
    end

    -- Check if the entry should be included based on the scriptFilter
    local isScript = binding.Binding:find("∿") ~= nil
    local matchesScriptFilter = (scriptFilter == 1) or (scriptFilter == 2 and not isScript) or (scriptFilter == 3 and isScript)

    if isSelected and matchesSearch and matchesScriptFilter then
      -- Count unassigned regardless of show_unassigned_only
      if binding.Key == "<Shortcut not Assigned>" then
        unassigned_count = unassigned_count + 1
      end

      -- Filter based on the selected option (Show All, Show without Shortcuts, Show with Shortcuts)
      if (showUnassignedOnly and binding.Key == "<Shortcut not Assigned>") or
         (showAssignedOnly and binding.Key ~= "<Shortcut not Assigned>") or
         (not showUnassignedOnly and not showAssignedOnly) then

        table.insert(filteredKeybindings, binding)

        if binding.Key == "<Shortcut not Assigned>" then
          selected_unassigned_count = selected_unassigned_count + 1
        end

        selected_count = selected_count + 1
      end
    end
    count = count + 1
  end

  sortKeybindings(filteredKeybindings)

  if #filteredKeybindings == 0 then
    content = "No KeyBindings available for this filter."
  else
    -- Calculate max length across all entries
    local max_length = renoiseCalculateMaxLength(renoiseKeybindings) + 35

    -- Append the key, aligned right
    for index, binding in ipairs(filteredKeybindings) do
      local entry = string.format("%04d", index)
        .. string.rep(" ", padding_number_identifier) .. binding.Identifier
        .. string.rep(" ", padding_identifier_topic - #binding.Identifier)
        .. binding.Topic
        .. string.rep(" ", padding_topic_binding - #binding.Topic)
        .. binding.Binding

      -- Adjust the visual difference caused by the squiggle character
      local length_adjustment = binding.Binding:find("∿") and 2 or 0
      local padded_entry = entry .. string.rep(" ", max_length - #entry + length_adjustment) .. " " .. binding.Key
      content = content .. padded_entry .. "\n"
    end
  end

  renoise_keybinding_list.text = content

  local selectedText = ""
  if selectedIdentifier == "All" then
    selectedText = "For all sections, there are " .. selected_count .. " shortcuts and " .. selected_unassigned_count .. " are unassigned."
  else
    selectedText = "For " .. selectedIdentifier .. ", there are " .. selected_count .. " shortcuts and " .. selected_unassigned_count .. " are unassigned."
  end

  renoise_selected_shortcuts_text.text = selectedText
  renoise_total_shortcuts_text.text = "Total: " .. count .. " shortcuts, " .. unassigned_count .. " unassigned."

  if not renoise_suppress_debug_log then
    renoiseKeyBindingsSaveDebugLog(filteredKeybindings, showUnassignedOnly)
  end
end

-- Function to handle key events
function my_RenoiseKeybindingskeyhandler_func(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    dialog=nil
    return nil
  else
    return key
  end
end

-- Main function to display the Renoise keybindings dialog
function showRenoiseKeyBindingsDialog(selectedIdentifier)  -- Accept an optional parameter
  -- Check if the dialog is already visible and close it
  if renoise_dialog and renoise_dialog.visible then
    renoise_dialog:close()
    return
  end

  -- Map menu identifiers to their internal names
  if selectedIdentifier then
    selectedIdentifier = menu_to_identifier[selectedIdentifier] or selectedIdentifier
  end

  local keyBindingsPath = detectOSAndGetKeyBindingsPath()
  if not keyBindingsPath then
    renoise.app():show_status("Failed to detect OS and find KeyBindings.xml path.")
    return
  end

  renoise_debug_log = renoise_debug_log .. "Debug: Using KeyBindings path - " .. keyBindingsPath .. "\n"
  renoiseKeybindings = renoiseKeyBindingsParseXML(keyBindingsPath)
  if not renoiseKeybindings or #renoiseKeybindings == 0 then
    renoise.app():show_status("No Renoise keybindings found.")
    renoise_debug_log = renoise_debug_log .. "Debug: Total Renoise keybindings found - 0\n"
    renoiseKeyBindingsSaveDebugLog(renoiseKeybindings, false)
    return
  end

  -- Print total found count at the start
  renoise_debug_log = "Debug: Total Renoise keybindings found - " .. #renoiseKeybindings .. "\n" .. renoise_debug_log

  -- Collect all unique Identifiers and sort them alphabetically
  local identifier_items = { "All" }
  local unique_identifiers = {}
  for _, binding in ipairs(renoiseKeybindings) do
    if not unique_identifiers[binding.Identifier] then
      unique_identifiers[binding.Identifier] = true
      table.insert(identifier_items, binding.Identifier)
    end
  end
  table.sort(identifier_items)

  -- Determine the index of the selectedIdentifier
  local selected_index = 1 -- Default to "All"
  if selectedIdentifier then
    -- Map the identifier before looking for its index
    local mapped_identifier = menu_to_identifier[selectedIdentifier] or selectedIdentifier
    for i, id in ipairs(identifier_items) do
      if id == mapped_identifier then
        selected_index = i
        break
      end
    end
  end

  -- Create the dropdown menu for identifier selection
  renoise_identifier_dropdown = vb:popup {
    items = identifier_items,
    width = 300,
    value = selected_index,  -- Set the dropdown to the selected identifier
    notifier = renoiseKeyBindingsUpdateList
  }

  -- Create the switch for showing/hiding shortcuts
  renoise_show_shortcuts_switch = vb:switch {
    items = { "Show All", "Show without Shortcuts", "Show with Shortcuts" },
    width = 1100,
    value = 1, -- Default to "Show All"
    notifier = renoiseKeyBindingsUpdateList
  }

  -- Create the switch for showing/hiding tools/scripts
  renoise_show_script_filter_switch = vb:switch {
    items = { "All", "Show without Tools", "Show Only Tools" },
    width = 1100,
    value = 1, -- Default to "All"
    notifier = function(value)
      renoiseKeyBindingsUpdateList()
      if value == 1 then
        renoise.app():show_status("Now showing all KeyBindings")
      elseif value == 2 then
        renoise.app():show_status("Now showing KeyBindings without Tools")
      elseif value == 3 then
        renoise.app():show_status("Now showing KeyBindings with only Tools")
      end
    end
  }

  -- UI Elements
  renoise_search_textfield = vb:textfield{width=300, notifier=renoiseKeyBindingsUpdateList}

  renoise_total_shortcuts_text = vb:text {
    text = "Total: 0 shortcuts, 0 unassigned",
    font = "bold",
    width = 1100, -- Adjusted width to fit the dialog
    align = "left"
  }

  renoise_selected_shortcuts_text = vb:text {
    text = "For selected sections, there are 0 shortcuts and 0 are unassigned.",
    font = "bold",
    width = 1100, -- Adjusted width to fit the dialog
    align = "left"
  }

  renoise_search_text = vb:text{text="Filter with"}

  renoise_keybinding_list = vb:multiline_textfield { width = 1100, height = 600, font = "mono" }

  -- Dialog title including Renoise version
  local dialog_title = "Renoise KeyBindings for Renoise Version " .. renoise.RENOISE_VERSION

  renoise_dialog = renoise.app():show_custom_dialog(
    dialog_title,
    vb:column {
      margin = 10,
      vb:text {
        text = "NOTE: KeyBindings.xml is only saved when Renoise is closed - so this is not a realtime / updatable Dialog. Make changes, quit Renoise, and relaunch this Dialog.",
        font = "bold"
      },
      renoise_identifier_dropdown,
      renoise_show_script_filter_switch,
      renoise_show_shortcuts_switch,
      vb:row{
        vb:button{
          text="Save as Textfile",
          notifier = function()
            local filename = renoise.app():prompt_for_filename_to_write(".txt", "Available Plugins Saver")
            if filename then
              local file, err = io.open(filename, "w")
              if file then
                file:write(renoise_keybinding_list.text)  -- Correct reference to multiline_field's text
                file:close()
                renoise.app():show_status("File saved successfully")
              else
                renoise.app():show_status("Error saving file: " .. err)
              end
            end
          end
        }
      },
      renoise_search_text,
      renoise_search_textfield,
      renoise_keybinding_list,
      renoise_selected_shortcuts_text,
      renoise_total_shortcuts_text
    },
    my_RenoiseKeybindingskeyhandler_func  -- Key handler function
  )

  -- Initial list update
  renoiseKeyBindingsUpdateList()

  -- Print total found count at the end
  renoise_debug_log = renoise_debug_log .. "Debug: Total Renoise keybindings found - " .. #renoiseKeybindings .. "\n"
  renoiseKeyBindingsSaveDebugLog(renoiseKeybindings, false)
end


-- Add submenu entries under corresponding identifiers
local renoise_identifiers = {
  "Automation",
  "Disk Browser",
  "DSP Chain",
  "Instrument Box",
  "Mixer",
  "Pattern Editor",
  "Pattern Matrix",
  "Pattern Sequencer",
  "Phrase Editor",
  "Phrase Map",
  "Sample Editor",
  "Sample FX Mixer",
  "Sample Keyzones",
  "Sample Modulation Matrix",
}

for _, identifier in ipairs(renoise_identifiers) do
  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:!Preferences..:Renoise KeyBindings..:" .. identifier,
    invoke=function() showRenoiseKeyBindingsDialog(identifier) end}
  renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:!Preferences..:Paketti KeyBindings..:" .. identifier,
    invoke=function() showPakettiKeyBindingsDialog(identifier) end}  
end



