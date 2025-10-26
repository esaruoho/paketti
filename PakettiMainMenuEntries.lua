local vb = renoise.ViewBuilder()
local dialog -- Declare the dialog variable outside the function
local textfield_width="100%"

local donations = {
  {"2012-02-06", "Nate Schmold", 76.51, {"3030.ca", "https://3030.ca"}, {"Ghost Cartridge", "https://ghostcartridge.com"}, {"YouTube", "https://YouTube.com/@3030-tv"}},
  {"2024-04-18", "Casiino", 17.98, {"Instagram", "https://www.instagram.com/elcasiino/"}},
  {"2024-06-30", "Zoey Samples", 13.43, {"BTD Records", "https://linktr.ee/BTD_Records"}},
  {"2024-07-19", "Casiino", 43.87, {"Instagram", "https://www.instagram.com/elcasiino/"}},
  {"2024-08-02", "Casiino", 12.40, {"Instagram", "https://www.instagram.com/elcasiino/"}},
  {"2024-08-03", "Diigitae", 10.00, {"Bandcamp", "https://diigitae.bandcamp.com/music"}},
  {"2024-08-08", "dmt", 20.00},
  {"2024-09-06", "Casiino", 8.63, {"Instagram", "https://www.instagram.com/elcasiino/"}},
  {"2024-09-19", "Casiino", 12.87, {"Instagram", "https://www.instagram.com/elcasiino/"}},
  {"2024-10-25", "grymmjack", 9.11, {"YouTube", "https://youtube.com/grymmjack"}, {"Soundcloud","https://soundcloud.com/grymmjack"},{"GitHub","https://github.com/grymmjack"}},
  {"2024-12-19", "c0der9", 4.23, {"Codingplace.de","https://codingplace.de"}},
  {"2024-12-25", "tkna | TAKAHASHI Naoki", 100.00, {"tkna", "https://tkna.work"}, {"1/a", "https://one-over-a.com"}, {"Ittteki", "https://ittteki.com"}},
  {"2025-03-26", "Brandon Hale", 20.61, {"bthale", "https://bthale.com"}, {"YouTube", "https://www.youtube.com/@brandonhale7574"}},
  {"2025-05-29", "JTPE", 6.08, {"Bandcamp", "https://plugexpert.bandcamp.com/music"}},
  {"2025-07-05", "Antti Hyypiö", 4.48},
  {"2025-07-17", "Helge H.", 47.95, {"YouTube","https://www.youtube.com/@HeiniGurke"}, {"Weizenkeim","https://planet.weizenkeim.org/"}},
  {"2025-07-21", "Jussi R.", 60.00},
  {"2025-07-28", "Leann Lai Syn Yuan", 4.38},
  {"2025-07-29", "Cosmic Ollie", 96.25},
  {"2025-08-17", "Cubeinthebox", 16.39, {"Soundcloud", "https://soundcloud.com/thecubeinthebox"}},
  {"2025-08-31", "grymmjack", 9.11, {"YouTube", "https://youtube.com/grymmjack"}, {"Soundcloud","https://soundcloud.com/grymmjack"},{"GitHub","https://github.com/grymmjack"}},
  {"2025-08-30", "Bloodclot", 7.22, {"Linktree", "https://linktr.ee/bclbclbcl"}},
  {"2025-09-18", "Untilde", 3.11},
  {"2025-10-06", "Brandon Hale", 7.37, {"bthale", "https://bthale.com"}, {"YouTube", "https://www.youtube.com/@brandonhale7574"}},

}

local total_amount = 0
for _, donation in ipairs(donations) do
  total_amount = total_amount + donation[3]
end

-- Build donation rows dynamically
local donation_rows = {}
for i, donation in ipairs(donations) do
  local date = donation[1]
  local person = donation[2]
  local amount = donation[3]
  local links = {}
  
  -- Collect all links starting from index 4
  for j = 4, #donation do
    if donation[j] and type(donation[j]) == "table" and #donation[j] == 2 then
      table.insert(links, donation[j])
    end
  end
  
  -- Create link buttons dynamically
  local link_buttons = {}
  for _, link in ipairs(links) do
    table.insert(link_buttons, vb:button{
      text = link[1], 
      notifier = function() renoise.app():open_url(link[2]) end
    })
  end
  
  -- Create the row
  local row_content = {
    vb:text{text = date, width = 70},
    vb:text{text = person, width = 150},
    vb:text{text = string.format("%.2f", amount) .. "€", width = 50, font = "bold"}
  }
  
  -- Add link buttons if any exist
  if #link_buttons > 0 then
    table.insert(row_content, vb:horizontal_aligner{
      mode = "left",
      unpack(link_buttons)
    })
  end
  
  table.insert(donation_rows, vb:row(row_content))
end

-- Build donation section dynamically
local donation_section = {
  width="100%",
  style = "group", 
  margin=5,
  vb:horizontal_aligner{mode="distribute",
    vb:text{text="Donations:", style = "strong", font = "bold"}},
  vb:row{
    vb:text{text="Date",width=70}, 
    vb:text{text="Person",width=150}, 
    vb:text{text="Amount",width=50}, 
    vb:text{text="Links",width=100}
  }
}

-- Insert donation rows one by one
for i, row in ipairs(donation_rows) do
  table.insert(donation_section, row)
end

-- Add final elements
table.insert(donation_section, vb:space{height = 5})
table.insert(donation_section, vb:horizontal_aligner{mode="distribute",
  vb:text{text="Total: " .. string.format("%.2f", total_amount) .. "€", font = "bold"}})

-- Create dialog content
local dialog_content = vb:column{
  --margin=10,
  vb:text{text="Thanks for the support / assistance:", style = "strong", font = "bold"},
  vb:multiline_textfield{width=textfield_width, height=40,text= 
  -- THANKS
  "dBlue, danoise, cortex, pandabot, ffx, Joule, Avaruus, astu/flo, syflom, Protman, vV, Bantai, taktik, Snowrobot, MXB, Jenoki, Kmaki, aleksip, Unless, martblek, schmuzoo, Sandroid, ylmrx, onetwentyeight, Tobias Felsner and the whole Renoise community."},

  vb:text{text="Ideas provided by:", style = "strong", font = "bold"},
  vb:multiline_textfield{width=textfield_width, height = 100, text = 
  -- IDEAS
  "tkna, Nate Schmold, Casiino, Royal Sexton, Bovaflux, Xerxes, ViZiON, Satoi, Kaneel, Subi, MigloJE, Yalk DX, Michael Langer, Christopher Jooste, Zoey Samples, Avaruus, Pieter Koenekoop, Widgetphreak, Bálint Magyar, Mick Rippon, MMD (Mr. Mark Dollin), ne7, renoize-user, Dionysis, untilde, Greystar, Kaidiak, sousândrade, senseiprod, Brandon Hale, dmt, Diigitae, Dávid Halmi (Nagz), tEiS, Floppi J, Aleksi Eeben, fuzzy, Jalex, Mike Pehel, grymmjack, Mister Garbanzo, tdel, Jek, Mezzguru, Run Anymore, gentleclockdivider, Aaron Munson (Ilkae), pr0t0type, Joonas Holmén (JouluPam), Ugly Cry, NPC1, Vulkan, super_lsd, sodiufas, amenburoda, davide, Hyena lord, zolipapa420, Amethyst, JTPE, Cosmic Ollie, Newtined, Kusoipilled, Spencer Williams (spnw), RENEGADE ANDROiD, Phill Tew, croay, ishineee, user22c, Helge H., ShasuraMk2, Mastrcode, Cthonic, Kavoli, polyplexmescalia" ..
  ", Josh Montgomery, Filthy Animal, AZ-Rotator" ..
  " and many others."},

  vb:text{text="Who made it possible:", style = "strong", font = "bold"},
  vb:multiline_textfield{width=textfield_width, height = 35, text="Lassi Nikko aka Brothomstates told me, early on, that he thought I could learn LUA. So here we are. Thanks for everything, all the mentoring in trackers and musicmaking, and all the inspiration."},

  vb:text{text="Kudos:", style = "strong", font = "bold"},
  vb:multiline_textfield{width=textfield_width, height = 45, text = 
  -- KUDOS
  "Massive kudos to martblek for allowing me to take his abandoned ReSpeak tool and make it into Paketti eSpeak Text-to-Speech, Kaidiak for donating ClippyClip device, and also for smdkun for letting me tweak their KeyBind Visualizer code and incorporate it into Paketti further down the line. mxb for the original ReCycle import code which i heavily reworked. Jaap3 for the work reverse-engineering the PTI format. Also many thanks to Phill Tew for the idea for the Additive Record Follow Pattern!, ryrun for the SFZ2XRNI Gist on GitHub."},

  vb:horizontal_aligner{mode = "distribute", vb:text{text="Talk about Paketti", style = "strong", font = "bold"}},
  vb:horizontal_aligner{
    mode = "distribute",
    vb:button{text="Paketti GitHub", width=200,notifier=function() renoise.app():open_url("https://github.com/esaruoho/org.lackluster.Paketti.xrnx") end},
    vb:button{text="Paketti Discord", width=200,notifier=function() renoise.app():open_url("https://discord.gg/Qex7k5j4wG") end},
    vb:button{text="Paketti Renoise Forum Thread", width=200,notifier=function() renoise.app():open_url("https://forum.renoise.com/t/new-tool-3-1-pakettir3/35848/88") end},
    vb:button{text="Email", width=200,notifier=function() renoise.app():open_url("mailto:esaruoho@icloud.com") end}
  },

  -- Insert donation section
  vb:column(donation_section),
  vb:horizontal_aligner{mode="distribute",vb:text{text="Support Paketti",style="strong",font="bold"}},
  vb:horizontal_aligner{mode="distribute",
    vb:button{text="Become a Patron at Patreon",notifier=function() renoise.app():open_url("https://patreon.com/esaruoho") end},
    vb:button{text="Send a donation via PayPal",notifier=function() renoise.app():open_url("https://www.paypal.com/donate/?hosted_button_id=PHZ9XDQZ46UR8") end},
    vb:button{text="Support via Ko-Fi",notifier=function() renoise.app():open_url("https://ko-fi.com/esaruoho") end},
    vb:button{text="Become a GitHub Sponsor",notifier=function() renoise.app():open_url("https://github.com/sponsors/esaruoho") end},
    vb:button{text="Onetime purchase from Gumroad",notifier=function() renoise.app():open_url("https://lackluster.gumroad.com/l/paketti") end},
    vb:button{text="Purchase Music via Bandcamp",notifier=function() renoise.app():open_url("http://lackluster.bandcamp.com/") end},
    vb:button{text="Linktr.ee", notifier=function() renoise.app():open_url("https://linktr.ee/esaruoho") end}},
  vb:space{height = 5},
  vb:horizontal_aligner{mode="distribute",
    vb:button{text="OK",width=300,notifier=function() dialog:close() end},
    vb:button{text="Cancel",width=300,notifier=function() dialog:close() end}}}

function pakettiAboutDonations()
  if dialog and dialog.visible then 
    dialog:close() 
    dialog = nil
  else
    -- Create keyhandler that can manage dialog variable
    local keyhandler = create_keyhandler_for_dialog(
      function() return dialog end,
      function(value) dialog = value end
    )
    dialog = renoise.app():show_custom_dialog("About Paketti / Donations, written by Esa Juhani Ruoho (C) 2009-2025", dialog_content, keyhandler)
  end
end

----------
function randomBPM()
  local bpmList = {80, 100, 115, 123, 128, 132, 135, 138, 160}
  local currentBPM = renoise.song().transport.bpm
  local newBpmList = {}
  for _, bpm in ipairs(bpmList) do
      if bpm ~= currentBPM then
          table.insert(newBpmList, bpm)
      end
  end

  if #newBpmList > 0 then
      local selectedBPM = newBpmList[math.random(#newBpmList)]
      renoise.song().transport.bpm = selectedBPM
      print("Random BPM set to: " .. selectedBPM) -- Debug output to the console
  else
      print("No alternative BPM available to switch to.")
  end

  -- Optional: write the BPM to a file or apply other logic
  if renoise.tool().preferences.RandomBPM and renoise.tool().preferences.RandomBPM.value then
      write_bpm() -- Ensure this function is defined elsewhere in your tool
      print("BPM written to file or handled additionally.")
  end

end  

--renoise.song().transport.bpm=math.random(60,180) end}




-- Global dialog reference for Squiggler toggle behavior
local dialog = nil

-- Function to create and show the dialog with a text field.
function squigglerdialog()
  -- Check if dialog is already open and close it
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  local content = vb:column{
    vb:textfield {
      value = "∿",
      edit_mode = true
    }
  }
  
  -- Create keyhandler that can manage dialog variable
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Copy the Squiggler to your clipboard", content, keyhandler)
end

renoise.tool():add_keybinding{name="Global:Paketti:∿ Squiggly Sinewave to Clipboard (macOS)",invoke=function() squigglerdialog() end}
----------
local vb=renoise.ViewBuilder()
local dialog_of_dialogs=nil

-- Function to create the button list dynamically based on API version
local function create_button_list()
  local buttons = {
    {"About Paketti/Donations", "pakettiAboutDonations"},
    {"Paketti Preferences", "pakettiPreferences"},
    {"Paketti Menu Configuration", "pakettiMenuConfigDialog"},
    {"Theme Selector", "pakettiThemeSelectorDialogShow"},
    {"Gater", "pakettiGaterDialog"},
    {"Effect Column CheatSheet", "pakettiPatternEditorCheatsheetDialog"},
    {"Phrase Init Dialog", "pakettiPhraseSettings"},
    {"Dynamic Views 1-4", function() pakettiDynamicViewDialog(1,4) end},
    {"Dynamic Views 5-8", function() pakettiDynamicViewDialog(5,8) end},
    {"Automation Value Dialog", "pakettiAutomationValue"},
    {"Merge Instruments", "pakettiMergeInstrumentsDialog"},
    {"Track DSP Device&Instrument Loader", "pakettiDeviceChainDialog"},
    {"Volume/Delay/Pan Slider Controls", "pakettiVolDelayPanSliderDialog"},
    {"Paketti Global Volume Adjustment", "pakettiGlobalVolumeDialog"},
    {"Paketti Offset Dialog", "pakettiOffsetDialog"},
    {"PitchStepper Demo", "pakettiPitchStepperDemo"},
    {"Value Interpolation Looper Dialog", "pakettiVolumeInterpolationLooper"},
    {"MIDI Populator", "pakettiMIDIPopulator"},
    {"New Song Dialog", "pakettiImpulseTrackerNewSongDialog"},
    {"Paketti Stacker", function() pakettiStackerDialog(proceed_with_stacking) end},
    {"SlotShow", "pakettiUserPreferencesShowerDialog"},
    {"Configure Launch App Selection/Path", "pakettiAppSelectionDialog"},
    {"Paketti KeyBindings", "pakettiKeyBindingsDialog"},
    {"Renoise KeyBindings", "pakettiRenoiseKeyBindingsDialog"},
    {"Find Free KeyBindings", "pakettiFreeKeybindingsDialog"},
    {"TimeStretch Dialog", "pakettiTimestretchDialog"},
    {"Fuzzy Search Track", "pakettiFuzzySearchTrackDialog"},
    {"Keyzone Distributor", "pakettiKeyzoneDistributorDialog"},
    {"Paketti Formula Device Manual", "pakettiFormulaDeviceDialog"},
    {"Paketti Pattern/Phrase Length Dialog", "pakettiLengthDialog"},
    {"Paketti EQ10 XY Control Dialog", "pakettiEQ10XYDialog"},
    {"EditStep Dialog", "pakettiEditStepDialog"},
    {"Switch Note Instrument Dialog", "pakettiSwitchNoteInstrumentDialog"},
    {"Show Largest Samples", "pakettiShowLargestSamplesDialog"},
    {"Beat Structure Editor", "pakettiBeatStructureEditorDialog"},
    {"Paketti XRNS Probe", "pakettiXRNSProbeShowDialog"},
    {"Audio Processing", "pakettiAudioProcessingToolsDialog"},
    {"eSpeak Text-to-Speech", "pakettieSpeakDialog"},
    {"YT-DLP Downloader", "pakettiYTDLPDialog"},
    {"User-Defined Sample Folders", "pakettiUserDefinedSamplesDialog"},
    {"Output Routings", "pakettiTrackOutputRoutingsDialog"},
    {"Convolver Dialog", "pakettiConvolverSelectionDialog"},
    {"Oblique Strategies", "pakettiObliqueStrategiesDialog"},
    {"Quick Load Device", "pakettiQuickLoadDialog"},
    {"Native/VST/VST3/AU Devices", "pakettiLoadDevicesDialog"},
    {"VST/VST3/AU Plugins", "pakettiLoadPluginsDialog"},
    {"Randomize Plugins/Devices", "pakettiRandomizerDialog"},
    {"Track Renamer", "pakettiTrackRenamerDialog"},
    {"Track Dater / Titler", "pakettiTitlerDialog"},
    {"Paketti Action Selector", "pakettiActionSelectorDialog"},
    {"Debug: Squiggler", "squigglerdialog"},
    {"Paketti Groovebox 8120", "pakettiEightSlotsByOneTwentyDialog"},
    {"Midi Mappings", "pakettiMIDIMappingsDialog"},
    {"BeatDetector", "pakettiBeatDetectorDialog"},
    {"OctaMED Note Echo", "pakettiOctaMEDNoteEchoDialog"},
    {"OctaMED Pick/Put Row", "pakettiOctaMEDPickPutRowDialog"},
    {"PlayerPro Note Dropdown Grid", "pakettiPlayerProNoteGridShowDropdownGrid"},
    {"PlayerPro Main Dialog", "pakettiPlayerProShowMainDialog"},
    {"PlayerPro Effect Dialog", "pakettiPlayerProEffectDialog"},
    {"Set Selection by Hex Offset", "pakettiHexOffsetDialog"},
    {"Paketti Tuplet Writer", "pakettiTupletDialog"},
    {"Speed and Tempo to BPM", "pakettiSpeedTempoDialog"},
    {"Debug: Available Plugin Information", "pakettiDebugPluginInfoDialog"},
    {"Debug: Available Device Information", "pakettiDebugDeviceInfoDialog"},
    {"AKWF Load 04 Samples (XY)", "pakettiLoad04AKWFSamplesXYDialog"},
    {"BPM to MS Delay Calculator", "pakettiBPMMSCalculator"},
    {"Sample Cycle Tuning Calculator", "pakettiSimpleSampleTuningDialog"},
    {"Paketti Sequencer Settings Dialog", "pakettiSequencerSettingsDialog"},
    {"Paketti Steppers Dialog", "PakettiSteppersDialog"},
    {"Protracker MOD modulation Dialog", "showProtrackerModDialog"},
    {"Slice->Pattern Sequencer Dialog", "showSliceToPatternSequencerInterface"},
    {"Polyend Buddy", "show_polyend_buddy_dialog"},
    {"Sample Pitch Modifier Dialog", "show_sample_pitch_modifier_dialog"},
    {"BPM From Sample Length", "pakettiBpmFromSampleDialog"},
    {"Hotelsinus Stepsequencer","createStepSequencerDialog"},
    {"Hotelsinus Matrix Overview", "createMatrixOverview"},
    {"AM Sine Wave Generator", "createCustomAmplitudeModulatedSinewave"},
    {"Sine Wave Generator", "createCustomSinewave"},
    {"XY Pad Sound Mixer", "showXyPaddialog"},
    {"SBX Playback Handler", "showSBX_dialog"},
    {"Paketti Sample Adjust", "show_paketti_sample_adjust_dialog"},
  }
  
  -- Add API 6.2+ specific dialogs only if supported
  if renoise.API_VERSION >= 6.2 then
    table.insert(buttons, {"V3.5 GUI Demo", "pakettiGUIDemo"})
    table.insert(buttons, {"Paketti Enhanced Phrase Generator", "pakettiPhraseGeneratorDialog"})
    table.insert(buttons, {"Chebyshev Polynomial Waveshaper", "show_chebyshev_waveshaper"})
    table.insert(buttons, {"Paketti Device Parameter Editor", "PakettiCanvasExperimentsInit"})
    table.insert(buttons, {"Sample Offset / Slice Step Sequencer", "PakettiSliceStepCreateDialog"})  
  end
  
  -- **ALL MISSING DIALOGS ADDED (FROM COMPREHENSIVE GREP):**
  table.insert(buttons, {"Digitakt Sample Chain", "PakettiDigitaktDialog"})
  table.insert(buttons, {"LFO Envelope Editor", "pakettiLFOEnvelopeEditorDialog"})
  table.insert(buttons, {"Wavetable", "show_wavetable_dialog"})
  table.insert(buttons, {"CCizer TXT->CC Loader", "pakettiCCizerTXTCCDialog"})
  table.insert(buttons, {"CCizer TXT->MIDI Control Loader", "pakettiCCizerTXTMIDIDialog"})
  table.insert(buttons, {"Metric Modulation Calculator", "pakettiMetricModulationDialog"})
  table.insert(buttons, {"Advanced Subdivision Calculator", "pakettiAdvancedSubdivisionDialog"})
  table.insert(buttons, {"OctaCycle Generator", "pakettiOctaCycleDialog"})
  table.insert(buttons, {"Track Mapping", "showTrackMappingDialog"})
  table.insert(buttons, {"Polyend Pattern Browser", "showPolyendPatternBrowser"})
  table.insert(buttons, {"Humanize Selection", "pakettiHumanizeDialog"})
  table.insert(buttons, {"Paketti XYPad Sample Rotator", "pakettiXYPadSampleRotatorDialog"})
  table.insert(buttons, {"Octatrack .OT File Analysis", "pakettiOTFileAnalysisDialog"})
  table.insert(buttons, {"Offset Sample Buffer", "pakettiOffsetSampleBufferDialog"})
  table.insert(buttons, {"Set EditStep&Enter", "pakettiEditStepEnterDialog"})
  table.insert(buttons, {"Player Pro Note Selector", "pakettiPlayerProNoteGridShowDropdownGrid"})
  table.insert(buttons, {"Player Pro FX Dialog", "pakettiPlayerProEffectDialog"})
  table.insert(buttons, {"Paketti Minimize Cheatsheet", "pakettiMinimizeCheatsheetDialog"})
  table.insert(buttons, {"Category Management (MIDI)", "pakettiCategoryManagementDialog"})
  table.insert(buttons, {"Paketti PCM Writer", "PCMWriterDialog"})
  --table.insert(buttons, {"Sample Visualizer", "show_sample_visualizer"})
  table.insert(buttons, {"Sononymph", "show_sononymph_dialog"})
  table.insert(buttons, {"Paketti RePitch", "show_paketti_repitch_dialog"})
  table.insert(buttons, {"Switch Note Instrument Dialog", "pakettiSwitchNoteInstrumentDialog"})
  table.insert(buttons, {"Plugin Details", "pakettiPluginDetailsDialog"})
  table.insert(buttons, {"Effect Details", "pakettiEffectDetailsDialog"})
  table.insert(buttons, {"Set Pattern/Phrase Length", "pakettiPatternPhraseLength"})
  table.insert(buttons, {"Instrument Transpose Dialog", "PakettiInstrumentTransposeDialog"})
  return buttons
end

-- Dialog of dialogs state variables (autocomplete-style)
local dod_current_search_text = ""
local dod_filtered_buttons = {}
local dod_selected_index = 1
local dod_search_display_text = nil
local dod_status_text = nil
local dod_button_widgets = {}
local dod_keyhandler = nil
local dod_buttons_per_row = preferences.pakettiDialogOfDialogsColumnsPerRow.value  -- User-configurable buttons per row, loaded from preferences
local dod_columns_valuebox = nil

-- Function to update dialog of dialogs search display
function update_dod_search_display()
  if dod_search_display_text then
    dod_search_display_text.text = "'" .. dod_current_search_text .. "'"
  end
end

-- Function to update dialog of dialogs suggestions
function update_dod_suggestions()
  local button_list = create_button_list()
  
  -- Apply filtering if search text is provided
  if dod_current_search_text ~= "" then
    dod_filtered_buttons = PakettiFuzzySearchUtil(button_list, dod_current_search_text, {
      search_type = "substring",
      field_extractor = function(button_def)
        return {button_def[1]} -- Search in button name only
      end
    })
  else
    dod_filtered_buttons = button_list
  end
  
  -- Reset selection
  dod_selected_index = (#dod_filtered_buttons > 0) and 1 or 0
  
  -- Update status text
  if dod_status_text then
    local max_buttons_to_show = 6 * 20  -- buttons_per_row * max_visible_rows
    local visible_count = math.min(#dod_filtered_buttons, max_buttons_to_show)
    local status_msg = string.format("(%d matches)", #dod_filtered_buttons)
    
    if dod_current_search_text ~= "" then
      status_msg = string.format("'%s' - %d matches", dod_current_search_text, #dod_filtered_buttons)
    end
    
    if #dod_filtered_buttons > max_buttons_to_show then
      status_msg = status_msg .. string.format(" - Showing first %d", visible_count)
    end
    
    if #dod_filtered_buttons > 0 and dod_selected_index > 0 then
      status_msg = status_msg .. string.format(" - Item %d selected", dod_selected_index)
    end
    dod_status_text.text = status_msg
  end
  
  -- Update button display
  update_dod_button_display()
end

-- Function to update button display (MAINTAINS FIXED GRID SIZE)
function update_dod_button_display()
  local button_index = 1
  local max_buttons_to_show = dod_buttons_per_row * math.ceil(120 / dod_buttons_per_row)  -- buttons_per_row * max_visible_rows
  
  for row_idx, row_buttons in ipairs(dod_button_widgets) do
    for col_idx, button in ipairs(row_buttons) do
      if button_index <= #dod_filtered_buttons and button_index <= max_buttons_to_show then
        local button_def = dod_filtered_buttons[button_index]
        button.text = button_def[1]
        button.visible = true
        button.active = true  -- Enable clicking
        
        -- Set deep purple background for selected button
        if button_index == dod_selected_index then
          button.color = {0x80, 0x00, 0x80} -- Deep purple (selected)
        else
          button.color = {0x00, 0x00, 0x00} -- Default (black/transparent)
        end
      else
        -- Empty button but ALWAYS VISIBLE to maintain fixed grid
        button.text = ""
        button.visible = true  -- KEEP VISIBLE to maintain grid size
        button.active = false  -- Disable clicking
        button.color = {0x00, 0x00, 0x00} -- Default color
      end
      button_index = button_index + 1
    end
  end
end

-- Function to move selection left (previous item in row)
function move_dod_selection_left()
  local buttons_per_row = dod_buttons_per_row
  local max_buttons_to_show = buttons_per_row * math.ceil(120 / buttons_per_row)
  local visible_count = math.min(#dod_filtered_buttons, max_buttons_to_show)
  if visible_count > 0 then
    if dod_selected_index <= 1 then
      dod_selected_index = visible_count -- Wrap to last item
    else
      dod_selected_index = dod_selected_index - 1
    end
    print("DOD: Selection moved left to index " .. dod_selected_index)
    update_dod_button_display()
    update_dod_status_text()
  end
end

-- Function to move selection right (next item in row)
function move_dod_selection_right()
  local buttons_per_row = dod_buttons_per_row
  local max_buttons_to_show = buttons_per_row * math.ceil(120 / buttons_per_row)
  local visible_count = math.min(#dod_filtered_buttons, max_buttons_to_show)
  if visible_count > 0 then
    if dod_selected_index >= visible_count then
      dod_selected_index = 1 -- Wrap to first item
    else
      dod_selected_index = dod_selected_index + 1
    end
    print("DOD: Selection moved right to index " .. dod_selected_index)
    update_dod_button_display()
    update_dod_status_text()
  end
end

-- Function to move selection up (previous row)
function move_dod_selection_up()
  local buttons_per_row = dod_buttons_per_row
  local max_buttons_to_show = buttons_per_row * math.ceil(120 / buttons_per_row)
  local visible_count = math.min(#dod_filtered_buttons, max_buttons_to_show)
  if visible_count > 0 then
    local new_index = dod_selected_index - buttons_per_row
    if new_index < 1 then
      -- Calculate position in last possible row
      local current_col = ((dod_selected_index - 1) % buttons_per_row) + 1
      local last_row_start = math.floor((visible_count - 1) / buttons_per_row) * buttons_per_row + 1
      new_index = math.min(last_row_start + current_col - 1, visible_count)
    end
    dod_selected_index = new_index
    print("DOD: Selection moved up to index " .. dod_selected_index)
    update_dod_button_display()
    update_dod_status_text()
  end
end

-- Function to move selection down (next row)
function move_dod_selection_down()
  local buttons_per_row = dod_buttons_per_row
  local max_buttons_to_show = buttons_per_row * math.ceil(120 / buttons_per_row)
  local visible_count = math.min(#dod_filtered_buttons, max_buttons_to_show)
  if visible_count > 0 then
    local new_index = dod_selected_index + buttons_per_row
    if new_index > visible_count then
      -- Go to same column in first row
      local current_col = ((dod_selected_index - 1) % buttons_per_row) + 1
      new_index = current_col
    end
    dod_selected_index = new_index
    print("DOD: Selection moved down to index " .. dod_selected_index)
    update_dod_button_display()
    update_dod_status_text()
  end
end

-- Helper function to update status text (extracted to avoid duplication)
function update_dod_status_text()
  if dod_status_text then
    local max_buttons_to_show = dod_buttons_per_row * math.ceil(120 / dod_buttons_per_row)  -- buttons_per_row * max_visible_rows
    local visible_count = math.min(#dod_filtered_buttons, max_buttons_to_show)
    local status_msg = string.format("(%d matches)", #dod_filtered_buttons)
    
    if dod_current_search_text ~= "" then
      status_msg = string.format("'%s' - %d matches", dod_current_search_text, #dod_filtered_buttons)
    end
    
    if #dod_filtered_buttons > max_buttons_to_show then
      status_msg = status_msg .. string.format(" - Showing first %d", visible_count)
    end
    
    if #dod_filtered_buttons > 0 and dod_selected_index > 0 then
      status_msg = status_msg .. string.format(" - Item %d selected", dod_selected_index)
    end
    dod_status_text.text = status_msg
  end
end

-- Function to execute selected dialog
function execute_dod_selection()
  if dod_selected_index > 0 and dod_selected_index <= #dod_filtered_buttons then
    local button_def = dod_filtered_buttons[dod_selected_index]
    local func = button_def[2]
    
    -- Execute the function (keep dialog open)
    if type(func) == "function" then
      func()
    else
      local global_func = _G[func]
      if global_func then global_func() end
    end
    
    print("DOD: Executed '" .. button_def[1] .. "' - dialog stays open")
  end
end

-- Function to handle button clicks in dialog of dialogs
local function handle_dod_button_click(button_index)
  dod_selected_index = button_index
  update_dod_button_display()  -- Update selection highlight
  execute_dod_selection()  -- Execute but keep dialog open
end

-- Function to calculate optimal dialog width based on columns and content
function calculate_dod_dialog_width(buttons_per_row, button_list)
  local max_visible_rows = math.ceil(120 / buttons_per_row)
  
  -- Calculate column widths based on longest text in each column
  local column_widths = {}
  local total_button_width = 0
  
  for col = 1, buttons_per_row do
    local max_length = 0
    -- Check every button that would be in this column
    for row = 0, max_visible_rows - 1 do
      local button_index = row * buttons_per_row + col
      if button_index <= #button_list then
        local text_length = #button_list[button_index][1]
        if text_length > max_length then
          max_length = text_length
        end
      end
    end
    -- Convert character count to pixels (approx 7px per char + 16px padding)
    column_widths[col] = math.max(80, math.min(200, max_length * 7 + 16))
    total_button_width = total_button_width + column_widths[col]
  end
  
  -- Calculate dialog width: button widths + minimal spacing + margins
  local dialog_width = total_button_width  -- Add minimal padding
  dialog_width = math.max(600, math.min(1800, dialog_width))  -- Reasonable limits
  
  print("DOD: Calculated width for " .. buttons_per_row .. " columns: " .. dialog_width .. "px (total button width: " .. total_button_width .. "px)")
  return dialog_width, column_widths
end

-- Function to create buttons from the list with optional filtering (now autocomplete-style)
function pakettiDialogOfDialogs(search_query, custom_keyhandler)
  search_query = search_query or ""
  dod_current_search_text = search_query
  local vb = renoise.ViewBuilder()  -- Create fresh ViewBuilder instance to avoid ID conflicts
  
  -- Initialize filtered buttons - ALWAYS show all dialogs initially
  local button_list = create_button_list()
  
  -- ENSURE we always show all dialogs when no search query
  if search_query and search_query ~= "" then
    dod_filtered_buttons = PakettiFuzzySearchUtil(button_list, search_query, {
      search_type = "substring",
      field_extractor = function(button_def)
        return {button_def[1]} -- Search in button name only
      end
    })
  else
    -- Show ALL dialogs by default
    dod_filtered_buttons = button_list
  end
  
  -- Ensure we have buttons and valid selection
  if #dod_filtered_buttons > 0 then
    dod_selected_index = 1
  else
    dod_selected_index = 0
  end
  
  -- Calculate dialog width and column widths based on current settings
  local buttons_per_row = dod_buttons_per_row  -- User-configurable buttons per row
  local max_visible_rows = math.ceil(120 / buttons_per_row)  -- Maintain ~120 total visible slots
  local BUTTON_HEIGHT = 20  -- Normal button height like Renoise default
  local max_buttons_to_show = buttons_per_row * max_visible_rows
  
  -- Calculate optimal dialog width and column widths
  local dialog_width, column_widths = calculate_dod_dialog_width(buttons_per_row, button_list)

  print("DOD: Using " .. buttons_per_row .. " buttons per row, max " .. max_visible_rows .. " rows")
  
  dod_button_widgets = {}
  local rows = {}
  local button_index = 1
  local max_buttons_to_show = buttons_per_row * max_visible_rows
  
  -- Create a FIXED-SIZE button grid that never changes dimensions
  for row = 1, max_visible_rows do
    local current_row = {}
    local row_buttons = {}
    
    -- Always create ALL buttons for EVERY row to maintain fixed grid size
    for col = 1, buttons_per_row do
      if button_index <= #dod_filtered_buttons and button_index <= max_buttons_to_show then
        local button_text = dod_filtered_buttons[button_index][1]
        local current_index = button_index
        
        local button = vb:button{
          text = button_text,
          width = column_widths[col],  -- Use column-specific width
          height = BUTTON_HEIGHT,
          visible = true,  -- Show button with content
          color = (button_index == dod_selected_index) and {0x80, 0x00, 0x80} or {0x00, 0x00, 0x00},
          notifier = function()
            handle_dod_button_click(current_index)
          end
        }
        
        table.insert(current_row, button)
        table.insert(row_buttons, button)
        button_index = button_index + 1
      else
        -- Create VISIBLE empty button to maintain FIXED grid structure
        local placeholder = vb:button{
          text = "",
          width = column_widths[col],  -- Use column-specific width
          height = BUTTON_HEIGHT,
          visible = true,  -- ALWAYS visible to maintain grid size
          active = false,  -- But disabled so can't be clicked
          color = {0x00, 0x00, 0x00}  -- Default color
        }
        table.insert(current_row, placeholder)
        table.insert(row_buttons, placeholder)
      end
    end
    
    table.insert(dod_button_widgets, row_buttons)
    table.insert(rows, vb:row(current_row))
  end
  
  local visible_count = math.min(#dod_filtered_buttons, max_buttons_to_show)
  print("DOD: Created " .. #rows .. " rows, showing " .. visible_count .. " of " .. #dod_filtered_buttons .. " dialogs")
  
  -- Debug: Show first few button names
  if #dod_filtered_buttons > 0 then
    print("DOD: First few buttons:")
    for i = 1, math.min(5, #dod_filtered_buttons) do
      print("  " .. i .. ": " .. dod_filtered_buttons[i][1])
    end
  else
    print("DOD: ERROR - No buttons in dod_filtered_buttons!")
  end
  
  return vb:column{
    vb:row{
      vb:text{
        text = "Type to search:",
        width = 100, font="bold",style="strong"
      },
      (function()
        dod_search_display_text = vb:text{
          width = 300,
          text = "'" .. dod_current_search_text .. "'",
          style = "strong"
        }
        return dod_search_display_text
      end)()
    },
    
    -- Add columns per row control between search and dialogs
    vb:row{
      vb:text{
        text = "Columns per row:",
        width = 100,style="strong",font="bold"
      },
      (function()
        dod_columns_valuebox = vb:valuebox{
          min = 1,
          max = 12,
          value = dod_buttons_per_row,
          width = 60,
          notifier = function(value)
            dod_buttons_per_row = value
            preferences.pakettiDialogOfDialogsColumnsPerRow.value = value
            preferences:save_as("preferences.xml")  -- Save preference immediately
            rebuild_dod_dialog()
          end
        }
        return dod_columns_valuebox
      end)()
    },
    
    vb:row{
      vb:text{
        text = "Dialogs:",
        style = "strong",font="bold",
        width = 100
      },
      (function()
        dod_status_text = vb:text{
          text = string.format("(%d matches)", #dod_filtered_buttons),font="bold",style="strong",
          --style = "disabled",
          width = 300
        }
        return dod_status_text
      end)()
    },
    
    vb:column{
      style = "group",
      width = dialog_width,  -- DYNAMIC WIDTH - adapts to number of columns but stays fixed during search
      unpack(rows)
    }
  }
end

-- Function to rebuild dialog when columns per row changes
function rebuild_dod_dialog()
  if dialog_of_dialogs and dialog_of_dialogs.visible then
    local button_list = create_button_list()
    local dialog_count = #button_list
    
    -- Close current dialog
    dialog_of_dialogs:close()
    
    -- Recreate with new layout
    dialog_of_dialogs = renoise.app():show_custom_dialog(
      string.format("Paketti Dialog of Dialogs (%d)", dialog_count), 
      pakettiDialogOfDialogs(dod_current_search_text, dod_keyhandler), 
      dod_keyhandler
    )
    
    -- Set focus to Renoise after dialog opens for key capture
    renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  end
end

function pakettiDialogOfDialogsToggle()
  if dialog_of_dialogs and dialog_of_dialogs.visible then
    dialog_of_dialogs:close()
    dialog_of_dialogs = nil
  else
    -- Count the number of dialogs in current button_list
    local button_list = create_button_list()
    local dialog_count = #button_list
    
    -- Load columns per row setting from preferences
    dod_buttons_per_row = preferences.pakettiDialogOfDialogsColumnsPerRow.value
    
    -- Reset search state
    dod_current_search_text = ""
    dod_selected_index = 1
    
    -- Create autocomplete-style keyhandler for dialog of dialogs
    dod_keyhandler = function(dialog, key)
      print("DOD: Key pressed - name: '" .. tostring(key.name) .. "', modifiers: '" .. tostring(key.modifiers) .. "'")
      if key.name == "return" then
        print("DOD: Enter key pressed - executing selection")
        -- Execute selected dialog
        execute_dod_selection()
        return nil
      elseif key.name == "left" then
        print("DOD: Left key pressed")
        move_dod_selection_left()
        return nil
      elseif key.name == "right" then
        print("DOD: Right key pressed")
        move_dod_selection_right()
        return nil
      elseif key.name == "up" then
        print("DOD: Up key pressed")
        move_dod_selection_up()
        return nil
      elseif key.name == "down" then
        print("DOD: Down key pressed")
        move_dod_selection_down()
        return nil
      elseif key.name == "esc" then
        -- If there's text, clear it first
        if dod_current_search_text ~= "" then
          dod_current_search_text = ""
          update_dod_search_display()
          update_dod_suggestions()
          return nil
        end
        -- If no text, fall through to closer key check
      end
      
      -- Check for close key
      local closer = preferences.pakettiDialogClose.value
      if key.modifiers == "" and key.name == closer then
        dialog:close()
        dialog_of_dialogs = nil
        return nil
      elseif key.name == "back" then
        -- Remove last character (real-time like autocomplete)
        if #dod_current_search_text > 0 then
          dod_current_search_text = dod_current_search_text:sub(1, #dod_current_search_text - 1)
          update_dod_search_display()
          update_dod_suggestions()
        end
        return nil
      elseif key.name == "delete" then
        -- Clear all text (real-time)
        dod_current_search_text = ""
        update_dod_search_display()
        update_dod_suggestions()
        return nil
      elseif key.name == "space" then
        -- Add space character (real-time)
        dod_current_search_text = dod_current_search_text .. " "
        update_dod_search_display()
        update_dod_suggestions()
        return nil
      elseif string.len(key.name) == 1 then
        -- Ignore the '<' character altogether (prevents interference from shift-cmd-< etc)
        if key.name ~= "<" then
          -- Add typed character immediately (real-time like autocomplete)
          dod_current_search_text = dod_current_search_text .. key.name
          update_dod_search_display()
          update_dod_suggestions()
        end
        return nil
      else
        -- Let other keys pass through
        return key
      end
    end
    
    dialog_of_dialogs = renoise.app():show_custom_dialog(
      string.format("Paketti Dialog of Dialogs (%d)", dialog_count), 
      pakettiDialogOfDialogs("", dod_keyhandler), 
      dod_keyhandler
    )
    
    -- Set focus to Renoise after dialog opens for key capture (like autocomplete)
    renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Paketti Dialog of Dialogs...",invoke=function() pakettiDialogOfDialogsToggle() end}


