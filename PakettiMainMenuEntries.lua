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
  margin=10,
  vb:text{text="Thanks for the support / assistance:", style = "strong", font = "bold"},
  vb:multiline_textfield{width=textfield_width, height=40,text= 
  -- THANKS
  "dBlue, danoise, cortex, pandabot, ffx, Joule, Avaruus, astu/flo, syflom, Protman, vV, Bantai, taktik, Snowrobot, MXB, Jenoki, Kmaki, aleksip, Unless, martblek, schmuzoo, Sandroid, ylmrx, onetwentyeight and the whole Renoise community."},

  vb:text{text="Ideas provided by:", style = "strong", font = "bold"},
  vb:multiline_textfield{width=textfield_width, height = 80, text = 
  -- IDEAS
  "tkna, Nate Schmold, Casiino, Royal Sexton, Bovaflux, Xerxes, ViZiON, Satoi, Kaneel, Subi, MigloJE, Yalk DX, Michael Langer, Christopher Jooste, Zoey Samples, Avaruus, Pieter Koenekoop, Widgetphreak, Bálint Magyar, Mick Rippon, MMD (Mr. Mark Dollin), ne7, renoize-user, Dionysis, untilde, Greystar, Kaidiak, sousândrade, senseiprod, Brandon Hale, dmt, Diigitae, Dávid Halmi (Nagz), tEiS, Floppi J, Aleksi Eeben, fuzzy, Jalex, Mike Pehel, grymmjack, Mister Garbanzo, tdel, Jek, Mezzguru, Run Anymore, gentleclockdivider, Aaron Munson (Ilkae), pr0t0type, Joonas Holmén (JouluPam), Ugly Cry, NPC1, Vulkan, super_lsd, sodiufas, amenburoda, davide, Hyena lord, zolipapa420, Amethyst, JTPE, Cosmic Ollie, Newtined, Kusoipilled, Spencer Williams (spnw), RENEGADE ANDROiD, Phill Tew, croay, ishineee, user22c, Helge H., ShasuraMk2, Mastrcode, Cthonic, Kavoli and many others."},

  vb:text{text="Who made it possible:", style = "strong", font = "bold"},
  vb:multiline_textfield{width=textfield_width, height = 40, text="Thanks to @lpn (Brothomstates) for suggesting that I could pick up and learn LUA, that it would not be beyond me. Really appreciate your (sometimes misplaced and ahead-of-time) faith in me. And thanks for the inspiration."},

  vb:text{text="Kudos:", style = "strong", font = "bold"},
  vb:multiline_textfield{width=textfield_width, height = 60, text = 
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
    {"Theme Selector", "pakettiThemeSelectorDialogShow"},
    {"Gater", "pakettiGaterDialog"},
    {"Effect Column CheatSheet", "pakettiPatternEditorCheatsheetDialog"},
    {"Phrase Init Dialog", "pakettiPhraseSettings"},
    {"Dynamic Views 1-4", function() pakettiDynamicViewDialog(1,4) end},
    {"Dynamic Views 5-8", function() pakettiDynamicViewDialog(5,8) end},
    {"Automation Value Dialog", "pakettiAutomationValue"},
    {"Merge Instruments", "pakettiMergeInstrumentsDialog"},
    {"Paketti Track DSP Device & Instrument Loader", "pakettiDeviceChainDialog"},
    {"Paketti Volume/Delay/Pan Slider Controls", "pakettiVolDelayPanSliderDialog"},
    {"Paketti Global Volume Adjustment", "pakettiGlobalVolumeDialog"},
    {"Paketti Offset Dialog", "pakettiOffsetDialog"},
    {"PitchStepper Demo", "pakettiPitchStepperDemo"},
    {"Value Interpolation Looper Dialog", "pakettiVolumeInterpolationLooper"},
    {"MIDI Populator", "pakettiMIDIPopulator"},
    {"New Song Dialog", "pakettiImpulseTrackerNewSongDialog"},
    {"Paketti Stacker", function() pakettiStackerDialog(proceed_with_stacking) end},
    {"SlotShow", "pakettiUserPreferencesShowerDialog"},
    {"Configure Launch App Selection/Paths", "pakettiAppSelectionDialog"},
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
    {"Paketti Slice to Pattern Sequencer Dialog", "showSliceToPatternSequencerInterface"},
    {"Paketti Polyend Buddy", "show_polyend_buddy_dialog"},
    {"Paketti Sample Pitch Modifier Dialog", "show_sample_pitch_modifier_dialog"},
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
    table.insert(buttons, {"Paketti Selected Device Parameter Editor", "PakettiCanvasExperimentsInit"})
  
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
  table.insert(buttons, {"Sample Visualizer", "show_sample_visualizer"})
  table.insert(buttons, {"Instrument Info", "show_instrument_info_dialog"})
  table.insert(buttons, {"Sononymph", "show_sononymph_dialog"})
  table.insert(buttons, {"Plugin Editor Position", "show_plugin_editor_position_dialog"})
  table.insert(buttons, {"Paketti RePitch", "show_paketti_repitch_dialog"})
  table.insert(buttons, {"Switch Note Instrument Dialog", "pakettiSwitchNoteInstrumentDialog"})
  table.insert(buttons, {"Set Smart Folder Path", "pakettiSetSmartFolderPathDialog"})
  table.insert(buttons, {"Plugin Details", "pakettiPluginDetailsDialog"})
  table.insert(buttons, {"Effect Details", "pakettiEffectDetailsDialog"})
  table.insert(buttons, {"Set Pattern/Phrase Length", "pakettiPatternPhraseLength"})  
  return buttons
end

-- Function to create buttons from the list with optional filtering
function pakettiDialogOfDialogs(search_query, custom_keyhandler)
  search_query = search_query or ""
  local vb = renoise.ViewBuilder()  -- Create fresh ViewBuilder instance to avoid ID conflicts
  local button_list = create_button_list()  -- Get current button list
  local total_count = #button_list  -- Store total count for display
  
  -- Apply fuzzy search filtering if search query is provided
  if search_query ~= "" then
    button_list = PakettiFuzzySearchUtil(button_list, search_query, {
      search_type = "substring",
      field_extractor = function(button_def)
        return {button_def[1]} -- Search in button name only
      end
    })
  end
  
  local filtered_count = #button_list  -- Count after filtering
  
  local buttons_per_row = 7
  local rows = {}
  local current_row = {}
  
  for i, button_def in ipairs(button_list) do
    local name, func = button_def[1], button_def[2]
    table.insert(current_row, vb:button{
      text = name,
      width=120,
      notifier = type(func) == "function" and func or function()
        local global_func = _G[func]
        if global_func then global_func() end
      end
    })
    
    if #current_row == buttons_per_row then
      table.insert(rows, vb:row(current_row))
      current_row = {}
    end
  end
  
  if #current_row > 0 then
    table.insert(rows, vb:row(current_row))
  end
  
  return vb:column{
    

    vb:row{
      vb:text{text="Search:", width=30,font="bold", style="strong"},
      vb:textfield{
        id="search_field",
        width=350,
        edit_mode = true,
        text = search_query,
        notifier=function(text)
          -- Recreate the dialog content with filtered results
          local filtered_content = pakettiDialogOfDialogs(text, custom_keyhandler)
          if dialog_of_dialogs and dialog_of_dialogs.visible then
            -- Get button list for count
            local total_list = create_button_list()
            local total_count = #total_list
            local current_list = total_list
            if text ~= "" then
              current_list = PakettiFuzzySearchUtil(current_list, text, {
                search_type = "substring",
                field_extractor = function(button_def)
                  return {button_def[1]} -- Search in button name only
                end
              })
            end
            local filtered_count = #current_list
            -- Update dialog title and content with "X out of Y" format
            local title = text ~= "" and 
              string.format("Paketti Dialog of Dialogs (%d out of %d)", filtered_count, total_count) or
              string.format("Paketti Dialog of Dialogs (%d)", total_count)
            dialog_of_dialogs:close()
            dialog_of_dialogs = renoise.app():show_custom_dialog(
              title, 
              filtered_content, 
              custom_keyhandler
            )
          end
        end
      },
      vb:button{
        text="Reset",
        width=50,
        notifier=function()
          -- Reset to show all items
          local all_button_list = create_button_list()
          local all_dialog_count = #all_button_list
          local reset_content = pakettiDialogOfDialogs("", custom_keyhandler)
          if dialog_of_dialogs and dialog_of_dialogs.visible then
            dialog_of_dialogs:close()
            dialog_of_dialogs = renoise.app():show_custom_dialog(
              string.format("Paketti Dialog of Dialogs (%d)", all_dialog_count), 
              reset_content, 
              custom_keyhandler
            )
          end
        end
      }
    },
    vb:column{
      style = "group",
      margin=5,
      unpack(rows)
    }
  }
end

function pakettiDialogOfDialogsToggle()
  if dialog_of_dialogs and dialog_of_dialogs.visible then
    dialog_of_dialogs:close()
    dialog_of_dialogs = nil
  else
    -- Count the number of dialogs in current button_list
    local button_list = create_button_list()
    local dialog_count = #button_list
    
    -- Create custom keyhandler for dialog of dialogs
    local keyhandler
    keyhandler = function(dialog, key)
      local closer = preferences.pakettiDialogClose.value
      
      -- Handle close key (escape, etc.)
      if key.modifiers == "" and key.name == closer then
        dialog:close()
        dialog_of_dialogs = nil
        return nil
      else
        return key
      end
    end
    
    dialog_of_dialogs = renoise.app():show_custom_dialog(string.format("Paketti Dialog of Dialogs (%d)", dialog_count), pakettiDialogOfDialogs("", keyhandler), keyhandler)
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Paketti Dialog of Dialogs...",invoke=function() pakettiDialogOfDialogsToggle() end}


