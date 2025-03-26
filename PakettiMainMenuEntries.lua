local vb = renoise.ViewBuilder()
local dialog -- Declare the dialog variable outside the function
local textfield_width = "100%"

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
  {"2025-03-26", "Brandon Hale", 20.61, {"bthale", "https://bthale.com"}, {"YouTube", "https://www.youtube.com/@brandonhale7574"}}
}

local total_amount = 0
for _, donation in ipairs(donations) do
  total_amount = total_amount + donation[3]
end

-- Create dialog content
local dialog_content = vb:column{
  margin = 10,
  spacing = 5,

  vb:text{text = "Thanks for the support / assistance:", style = "strong", font = "bold"},
  vb:multiline_textfield{width = textfield_width, height = 40, text = "There's probably tons more, but: dBlue, danoise, cortex, pandabot, ffx, Joule, Avaruus, astu/flo, syflom, Protman, vV, Bantai, taktik, Snowrobot, MXB, Jenoki, Kmaki, aleksip, Unless, martblek, schmuzoo and the whole Renoise community."},

  vb:text{text = "Ideas provided by:", style = "strong", font = "bold"},
  vb:multiline_textfield{width = textfield_width, height = 80, text = "tkna, Nate Schmold, Casiino, Royal Sexton, Bovaflux, Xerxes, ViZiON, Satoi, Kaneel, Subi, MigloJE, Yalk DX, Michael Langer, Christopher Jooste, Zoey Samples, Avaruus, Pieter Koenekoop, Widgetphreak, Bálint Magyar, Mick Rippon, MMD (Mr. Mark Dollin), ne7, renoize-user, Dionysis, untilde, Greystar, Kaidiak, sousândrade, senseiprod, Brandon Hale, dmt, Diigitae, Dávid Halmi (Nagz), tEiS, Floppi J, Aleksi Eeben, fuzzy, Jalex, Mike Pehel, grymmjack, Mister Garbanzo, tdel, Jek, Mezzguru, Run Anymore, gentleclockdivider, Aaron Munson (Ilkae), pr0t0type, Joonas Holmén (JouluPam), Ugly Cry, NPC1, Vulkan, Dancing Ponies, super_lsd, amenburoda and many others."},

  vb:text{text = "Who made it possible:", style = "strong", font = "bold"},
  vb:multiline_textfield{width = textfield_width, height = 40, text = "Thanks to @lpn (Brothomstates) for suggesting that I could pick up and learn LUA, that it would not be beyond me. Really appreciate your (sometimes misplaced and ahead-of-time) faith in me. And thanks for the inspiration."},

  vb:text{text = "Kudos:", style = "strong", font = "bold"},
  vb:multiline_textfield{width = textfield_width, height = 60, text = "Massive kudos to martblek for allowing me to take his abandoned ReSpeak tool and make it into Paketti eSpeak Text-to-Speech, Kaidiak for donating ClippyClip device, and also for smdkun for letting me tweak their KeyBind Visualizer code and incorporate it into Paketti further down the line. And Dancing Ponies for giving the idea for Timestretch and for Paketti Beat Structure Generator."},

  vb:horizontal_aligner{mode = "distribute", vb:text{text = "Talk about Paketti", style = "strong", font = "bold"}},
  vb:horizontal_aligner{
    mode = "distribute",
    vb:button{text = "Paketti GitHub", notifier = function() renoise.app():open_url("https://github.com/esaruoho/org.lackluster.Paketti.xrnx") end},
    vb:button{text = "Paketti Discord", notifier = function() renoise.app():open_url("https://discord.gg/Qex7k5j4wG") end},
    vb:button{text = "Paketti Renoise Forum Thread", notifier = function() renoise.app():open_url("https://forum.renoise.com/t/new-tool-3-1-pakettir3/35848/88") end},
    vb:button{text = "Email", notifier = function() renoise.app():open_url("mailto:esaruoho@icloud.com") end}
  },

  -- Grouped donation section
  vb:column{ width = "100%",
    style = "group", 
    margin = 5,
vb:horizontal_aligner{mode="distribute",
    vb:text{text = "Donations:", style = "strong", font = "bold"}},
    vb:row{
      vb:text{text = "Date", width = 70}, 
      vb:text{text = "Person", width = 150}, 
      vb:text{text = "Amount", width = 50}, 
      vb:text{text = "Links", width = 100}
    },

    -- Manually create and add each donation row
    vb:row{
      vb:text{text = donations[0+1][1], width = 70},
      vb:text{text = donations[0+1][2], width = 150},
      vb:text{text = string.format("%.2f", donations[0+1][3]).."€", width = 50, font = "bold"},
      vb:horizontal_aligner{mode = "left",
      vb:button{text = donations[0+1][4][1], notifier = function() renoise.app():open_url(donations[0+1][4][2]) end},
      vb:button{text = donations[0+1][5][1], notifier = function() renoise.app():open_url(donations[0+1][5][2]) end},
      vb:button{text = donations[0+1][6][1], notifier = function() renoise.app():open_url(donations[0+1][6][2]) end}
      }
    },
    vb:row{
      vb:text{text = donations[1+1][1], width = 70},
      vb:text{text = donations[1+1][2], width = 150},
      vb:text{text = string.format("%.2f", donations[1+1][3]).."€", width = 50, font = "bold"},
      vb:horizontal_aligner{mode = "left",
      vb:button{text = donations[1+1][4][1], notifier = function() renoise.app():open_url(donations[1+1][4][2]) end}
      }
    },
    vb:row{
      vb:text{text = donations[2+1][1], width = 70},
      vb:text{text = donations[2+1][2], width = 150},
      vb:text{text = string.format("%.2f", donations[2+1][3]).."€", width = 50, font = "bold"},
      vb:horizontal_aligner{mode = "left",
      vb:button{text = donations[2+1][4][1], notifier = function() renoise.app():open_url(donations[2+1][4][2]) end}
      }
    },
    vb:row{
      vb:text{text = donations[3+1][1], width = 70},
      vb:text{text = donations[3+1][2], width = 150},
      vb:text{text = string.format("%.2f", donations[3+1][3]).."€", width = 50, font = "bold"},
      vb:horizontal_aligner{mode = "left",
      vb:button{text = donations[3+1][4][1], notifier = function() renoise.app():open_url(donations[3+1][4][2]) end}
      }
    },
    vb:row{
      vb:text{text = donations[4+1][1], width = 70},
      vb:text{text = donations[4+1][2], width = 150},
      vb:text{text = string.format("%.2f", donations[4+1][3]).."€", width = 50, font = "bold"},
      vb:horizontal_aligner{mode = "left",
      vb:button{text = donations[4+1][4][1], notifier = function() renoise.app():open_url(donations[4+1][4][2]) end}
      }
    },
    vb:row{
      vb:text{text = donations[5+1][1], width = 70},
      vb:text{text = donations[5+1][2], width = 150},
      vb:text{text = string.format("%.2f", donations[5+1][3]).."€", width = 50, font = "bold"},
      vb:horizontal_aligner{mode = "left",
      vb:button{text = donations[5+1][4][1], notifier = function() renoise.app():open_url(donations[5+1][4][2]) end}
      }
    },
    vb:row{
      vb:text{text = donations[6+1][1], width = 70},
      vb:text{text = donations[6+1][2], width = 150},
      vb:text{text = string.format("%.2f", donations[6+1][3]).."€", width = 50, font = "bold"}
    },
    vb:row{
      vb:text{text = donations[7+1][1], width = 70},
      vb:text{text = donations[7+1][2], width = 150},
      vb:text{text = string.format("%.2f", donations[7+1][3]).."€", width = 50, font = "bold"},
      vb:horizontal_aligner{mode = "left",
      vb:button{text = donations[7+1][4][1], notifier = function() renoise.app():open_url(donations[7+1][4][2]) end}}
    },
    vb:row{
      vb:text{text = donations[8+1][1], width = 70},
      vb:text{text = donations[8+1][2], width = 150},
      vb:text{text = string.format("%.2f", donations[8+1][3]).."€", width = 50, font = "bold"},
      vb:horizontal_aligner{mode = "left",
      vb:button{text = donations[8+1][4][1], notifier = function() renoise.app():open_url(donations[8+1][4][2]) end}}
    },    
    vb:row{
      vb:text{text = donations[9+1][1], width = 70},
      vb:text{text = donations[9+1][2], width = 150},
      vb:text{text = string.format("%.2f", donations[9+1][3]).."€", width = 50, font = "bold"},
      vb:horizontal_aligner{mode = "left",
      vb:button{text = donations[9+1][4][1], notifier = function() renoise.app():open_url(donations[9+1][4][2]) end},
      vb:button{text = donations[9+1][5][1], notifier = function() renoise.app():open_url(donations[9+1][5][2]) end},
      vb:button{text = donations[9+1][6][1], notifier = function() renoise.app():open_url(donations[9+1][6][2]) end}}
    },   
    vb:row{
      vb:text{text = donations[10+1][1], width = 70},
      vb:text{text = donations[10+1][2], width = 150},
      vb:text{text = string.format("%.2f", donations[10+1][3]).."€", width = 50, font = "bold"},
      vb:horizontal_aligner{mode = "left",
      vb:button{text = donations[10+1][4][1], notifier = function() renoise.app():open_url(donations[10+1][4][2]) end}}
    },       
    vb:row{
      vb:text{text = donations[11+1][1], width = 70},
      vb:text{text = donations[11+1][2], width = 150},
      vb:text{text = string.format("%.2f", donations[11+1][3]).."€", width = 50, font = "bold"},
      vb:horizontal_aligner{mode = "left",
      vb:button{text = donations[11+1][4][1], notifier = function() renoise.app():open_url(donations[11+1][4][2]) end},
      vb:button{text = donations[11+1][5][1], notifier = function() renoise.app():open_url(donations[11+1][5][2]) end},
      vb:button{text = donations[11+1][6][1], notifier = function() renoise.app():open_url(donations[11+1][6][2]) end}}
    }, 
    vb:row{
      vb:text{text = donations[12+1][1], width = 70},
      vb:text{text = donations[12+1][2], width = 150},
      vb:text{text = string.format("%.2f", donations[12+1][3]).."€", width = 50, font = "bold"},
      vb:horizontal_aligner{mode = "left",
      vb:button{text = donations[12+1][4][1], notifier = function() renoise.app():open_url(donations[12+1][4][2]) end},
      vb:button{text = donations[12+1][5][1], notifier = function() renoise.app():open_url(donations[12+1][5][2]) end}}
    },
    

    vb:space{height = 5},
    vb:horizontal_aligner{mode="distribute",
    vb:text{text = "Total: " .. string.format("%.2f", total_amount) .. "€", font = "bold"}}
  },
  vb:horizontal_aligner{mode="distribute",vb:text{text = "Support Paketti", style = "strong", font = "bold"}},

  vb:horizontal_aligner{
    mode = "distribute",
    vb:button{text = "Become a Patron at Patreon", notifier = function() renoise.app():open_url("https://patreon.com/esaruoho") end},
    vb:button{text = "Send a donation via PayPal", notifier = function() renoise.app():open_url("https://www.paypal.com/donate/?hosted_button_id=PHZ9XDQZ46UR8") end},
    vb:button{text = "Support via Ko-Fi", notifier = function() renoise.app():open_url("https://ko-fi.com/esaruoho") end},
    vb:button{text = "Become a GitHub Sponsor", notifier = function() renoise.app():open_url("https://github.com/sponsors/esaruoho") end},
    vb:button{text = "Onetime purchase from Gumroad", notifier=function() renoise.app():open_url("https://lackluster.gumroad.com/l/paketti") end},
    vb:button{text = "Purchase Music via Bandcamp", notifier = function() renoise.app():open_url("http://lackluster.bandcamp.com/") end},
    vb:button{text = "Linktr.ee", notifier = function() renoise.app():open_url("https://linktr.ee/esaruoho") end}
  },

  vb:space{height = 20},
  vb:horizontal_aligner{mode = "distribute",
    vb:button{text = "OK", notifier = function() dialog:close() end},
    vb:button{text = "Cancel", notifier = function() dialog:close() end}
  }
}

local function my_keyhandler_func(dialog, key)
local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    dialog = nil
    return nil
else
    return key
  end
end

function show_about_dialog()
  if dialog and dialog.visible then
    dialog:close() -- Close the dialog if it's open
  else
    dialog = renoise.app():show_custom_dialog("About Paketti / Donations, written by Esa Juhani Ruoho (C) 2009-2025", dialog_content, my_keyhandler_func)
  end
end

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:!!About..:About Paketti/Donations...",invoke=function() show_about_dialog() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:!Preferences..:Open Paketti Path",invoke=function() renoise.app():open_path(renoise.tool().bundle_path)end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Plugins/Devices..:Debug..:Inspect Plugin (Console)",invoke=function() inspectPlugin() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Plugins/Devices..:Debug..:Inspect Selected Device (Console)",invoke=function() inspectEffect() end}
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

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Pattern Editor..:Random BPM (60-180)",invoke=function() randomBPM() end}

--renoise.song().transport.bpm=math.random(60,180) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Pattern Editor..:Write Current BPM&LPB to Master column",invoke=function() write_bpm() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Paketti Effect Column CheatSheet...",invoke=function() CheatSheet() end}

-------- Plugins/Devices
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Plugins/Devices..:Load Devices...",invoke=function()
showDeviceListDialog()
end}

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Pattern Editor..:Clone Current Sequence",invoke=clone_current_sequence}


renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Plugins/Devices..:Debug..:List Available VST Plugins (Console)",
    invoke=function() listByPluginType("VST") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Plugins/Devices..:Debug..:List Available AU Plugins (Console)",
    invoke=function() listByPluginType("AU") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Plugins/Devices..:Debug..:List Available VST3 Plugins (Console)",
    invoke=function() listByPluginType("VST3") end}
-- Adding menu entries for listing available devices (effects) by type
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Plugins/Devices..:Debug..:List Available VST Effects (Console)",
    invoke=function() listDevicesByType("VST") end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Plugins/Devices..:Debug..:List Available AU Effects (Console)",
    invoke=function() listDevicesByType("AU") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Plugins/Devices..:Debug..:List Available VST3 Effects (Console)",
    invoke=function() listDevicesByType("VST3") end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Plugins/Devices..:Debug..:Dump VST/VST3/AU/Native Effects (Console)",invoke=function() 
local devices=renoise.song().tracks[renoise.song().selected_track_index].available_devices
  for key, value in ipairs (devices) do 
    print(key, value)
  end
end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Plugins/Devices..:Debug..:Available Routings for Track...",invoke=function() showAvailableRoutings() end}

-- Function to create and show the dialog with a text field.
function squigglerdialog()
  local vb = renoise.ViewBuilder()
  local content = vb:column {
    margin = 10,
    vb:textfield {
      value = "∿",
      edit_mode = true
    }
  }
  
  -- Using a local variable for 'dialog' to limit its scope to this function.
  local dialog = renoise.app():show_custom_dialog("Copy the Squiggler to your clipboard", content, my_keyhandler_func)
end

renoise.tool():add_keybinding{name="Global:Paketti:∿ Squiggly Sinewave to Clipboard (macOS)",invoke=function() squigglerdialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Plugins/Devices..:Debug..:∿ Squiggly Sinewave to Clipboard...",invoke=function() squigglerdialog() end}
----------

local vb = renoise.ViewBuilder()
local dialog_instance = nil

local function create_paketti_dialog()
  local dialog_content = vb:column{margin=10,
    vb:column{style="group",margin=5,
      vb:row{
        vb:button{text="About Paketti/Donations...", width=50, notifier=function() show_about_dialog() end},      
        vb:button{text="Theme Selector", width=120, notifier=function() pakettiThemeSelectorDialogShow() end},
        vb:button{text="Gater", width=80, notifier=function()
          local max_rows = renoise.song().selected_pattern.number_of_lines
          if renoise.song() then
            pakettiGaterDialog()
            renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
          end
        end},
        vb:button{text="Effect Column CheatSheet", width=120, notifier=function() CheatSheet() end},
        vb:button{text="Phrase Init Dialog", width=120, notifier=function() pakettiPhraseSettingsDialogShow() end},
        vb:button{text="MIDI Populator", width=100, notifier=function() generaMIDISetupShowCustomDialog() end},
        vb:button{text="KeyBindings", width=50, notifier=function() showPakettiKeyBindingsDialog() end},
        vb:button{text="Midi Mappings", width=50, notifier=function() show_midi_mappings_dialog() end},
        vb:button{text="Audio Processing", width=50, notifier=function() PakettiAudioProcessingToolsDialogShow() end },
        vb:button{text="eSpeak TTS", width=50, notifier=function() PakettieSpeakToggleDialog() end },
        vb:button{text="Coluga", width=50, notifier=function() PakettiYTDLPShowDialog() end },
        vb:button{text="Output Routings", width=50, notifier=function() trackOutputRoutingsGUI_create() end },
        vb:button{text="Convolver Dialog", width=50, notifier=function() show_convolver_selection_dialog() end }},
       
      vb:row{
        vb:button{text="Oblique Strategies", width=50, notifier=function() create_oblique_strategies_dialog() end},
        vb:button{text="Native/VST/VST3/AU/LADSPA/DSSI/ Devices", width=50, notifier=function() showDeviceListDialog() end},
        vb:button{text="VST/VST3/AU Plugins", width=50, notifier=function() showPluginListDialog() end},
        vb:button{text="Randomize Plugins/Devices", width=50, notifier=function() openCombinedRandomizerDialog() end},
        vb:button{text="Configure Launch App Selection/Paths", width=50, notifier=function() show_app_selection_dialog() end},
        vb:button{text="Renoise KeyBindings", width=50, notifier=function() showRenoiseKeyBindingsDialog()end},
        vb:button{text="Track Renamer", width=50, notifier=function() PakettiTrackRenamerDialog() end},
        vb:button{text="Track Dater / Titler", width=50, notifier=function() PakettiTrackDaterTitlerDialog() end}}, vb:row{
        vb:button{text="Paketti Preferences", width=50, notifier=function() show_paketti_preferences() end},
        vb:button{text="Squiggler", width=50, notifier=function() squigglerdialog() end},
        vb:button{text="Paketti Groovebox 8120", width=50, notifier=function()   if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    rows = {}
  else PakettiEightSlotsByOneTwentyDialog() end end}
      }}}
  return dialog_content
end

local function toggle_paketti_dialog()
  if dialog_instance and dialog_instance.visible then

    dialog_instance:close()
    dialog_instance = nil
  else

    dialog_instance = renoise.app():show_custom_dialog("Paketti Dialog of Dialogs", create_paketti_dialog(), my_keyhandler_func)
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Paketti Dialog of Dialogs",invoke=function() toggle_paketti_dialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Paketti Dialog of Dialogs...",invoke=function() toggle_paketti_dialog() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Paketti New Song Dialog...",invoke=function() show_new_song_dialog() end }
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Paketti Track Dater & Titler...",invoke=function() PakettiTrackDaterTitlerDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Paketti Theme Selector...",invoke=pakettiThemeSelectorDialogShow }
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Paketti Gater...",invoke=function()
          local max_rows = renoise.song().selected_pattern.number_of_lines
          if renoise.song() then
            pakettiGaterDialog()
            renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
          end
        end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Paketti MIDI Populator...",invoke=function() generaMIDISetupShowCustomDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Track Routings...",invoke=function() trackOutputRoutingsGUI_create() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Oblique Strategies...",invoke=function() create_oblique_strategies_dialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Paketti Track Renamer...",invoke=function() PakettiTrackRenamerDialog() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Paketti eSpeak Text-to-Speech...",invoke=function()PakettieSpeakToggleDialog()end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Xperimental/Work in Progress:Audio Processing Tools...",invoke=function() PakettiAudioProcessingToolsDialogShow() end}

