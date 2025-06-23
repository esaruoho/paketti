require "process_slicer"

-- Initialize the ViewBuilder and other variables
local vb = renoise.ViewBuilder()
local dialog = nil
local rns = nil
local rnt = renoise.tool()
local ra = renoise.app()
local button_press_active = false

local LANGUAGES = {{"Afrikaans","af"},{"Albanian","sq"},{"Amharic","am"},{"Aragonese","an"},{"Arabic","ar"},{"Armenian (East Armenia)","hy"},{"Armenian (West Armenia)","hyw"},{"Assamese","as"},{"Azerbaijani","az"},{"Bashkir","ba"},{"Basque","eu"},{"Belarusian","be"},{"Bengali","bn"},{"Bishnupriya Manipuri","bpy"},{"Bosnian","bs"},{"Bulgarian","bg"},{"Catalan","ca"},{"Cherokee","chr"},{"Chinese (Cantonese)","yue"},{"Chinese (Cantonese, Latin as Jyutping)","yue-Latn-jyutping"},{"Chinese (Mandarin, Latin as English)","cmn"},{"Chinese (Mandarin, Latin as Pinyin)","cmn-Latn-pinyin"},{"Chuvash","cv"},{"Croatian","hr"},{"Czech","cs"},{"Danish","da"},{"Dutch","nl"},{"English (America)","en-US"},{"English (America, New York City)","en-US-nyc"},{"English (Caribbean)","en-029"},{"English (Great Britain)","en"},{"English (Lancaster)","en-GB-x-gbclan"},{"English (Received Pronunciation)","en-GB-x-rp"},{"English (Scotland)","en-GB-scotland"},{"English (West Midlands)","en-GB-x-gbcwmd"},{"Esperanto","eo"},{"Estonian","et"},{"Finnish","fi"},{"French (Belgium)","fr-BE"},{"French (France)","fr"},{"French (Switzerland)","fr-CH"},{"Gaelic (Irish)","ga"},{"Gaelic (Scottish)","gd"},{"Georgian","ka"},{"German","de"},{"Greek","el"},{"Greek (Ancient)","grc"},{"Greenlandic","kl"},{"Gujarati","gu"},{"Haitian Creole","ht"},{"Hakka Chinese","hak"},{"Hawaiian","haw"},{"Hebrew","he"},{"Hindi","hi"},{"Hungarian","hu"},{"Icelandic","is"},{"Ido","io"},{"Indonesian","id"},{"Interlingua","ia"},{"Italian","it"},{"Japanese","ja"},{"Kazakh","kk"},{"K'iche'","quc"},{"Klingon","piqd"},{"Kannada","kn"},{"Konkani","kok"},{"Korean","ko"},{"Kurdish","ku"},{"Kyrgyz","ky"},{"Lang Belta","qdb"},{"Latin","la"},{"Latgalian","ltg"},{"Latvian","lv"},{"Lingua Franca Nova","lfn"},{"Lithuanian","lt"},{"Lojban","jbo"},{"Luxembourgish","lb"},{"Lule Saami","smj"},{"Macedonian","mk"},{"Maori","mi"},{"Malay","ms"},{"Malayalam","ml"},{"Maltese","mt"},{"Marathi","mr"},{"Myanmar (Burmese)","my"},{"Nahuatl (Classical)","nci"},{"Nepali","ne"},{"Norwegian Bokmål","nb"},{"Nogai","nog"},{"Oromo","om"},{"Oriya","or"},{"Papiamento","pap"},{"Persian","fa"},{"Persian (Pinglish)","fa-Latn"},{"Polish","pl"},{"Portuguese (Brazil)","pt-BR"},{"Portuguese (Portugal)","pt"},{"Punjabi","pa"},{"Pyash","py"},{"Quechua","qu"},{"Quenya","qya"},{"Romanian","ro"},{"Russian","ru"},{"Russian (Latvia)","ru-LV"},{"Sindarin","sjn"},{"Sindhi","sd"},{"Sinhala","si"},{"Shan (Tai Yai)","shn"},{"Slovak","sk"},{"Slovenian","sl"},{"Spanish (Latin America)","es-419"},{"Spanish (Spain)","es"},{"Swahili","sw"},{"Swedish","sv"},{"Tamil","ta"},{"Telugu","te"},{"Thai","th"},{"Turkish","tr"},{"Turkmen","tk"},{"Tatar","tt"},{"Ukrainian","uk"},{"Urdu","ur"},{"Uyghur","ug"},{"Uzbek","uz"},{"Vietnamese (Central)","vi-VN-x-central"},{"Vietnamese (Northern)","vi"},{"Vietnamese (Southern)","vi-VN-x-south"},{"Welsh","cy"}}

local VOICES = {"None","adam","Alex","Alicia","Andrea","Andy","anika","anikaRobot","Annie","announcer","antonio","AnxiousAndy","aunty","belinda","benjamin","boris","caleb","croak","david","Demonic","Denis","Diogo","ed","edward","edward2","f1","f2","f3","f4","f5","fast","Gene","Gene2","grandma","grandpa","gustave","Henrique","Hugo","iven","iven2","iven3","iven4","Jacky","john","kaukovalta","klatt","klatt2","klatt3","klatt4","klatt5","klatt6","Lee","linda","m1","m2","m3","m4","m5","m6","m7","m8","marcelo","Marco","Mario","max","miguel","Michael","michel","Mike","Mr serious","Nguyen","norbert","pablo","paul","pedro","quincy","RicishayMax","RicishayMax2","RicishayMax3","rob","robert","robosoft","sandro","shelby","steph","Storm","travis","Tweaky","victor","whisper","whisperf","zac"}

local LANGUAGE_NAMES = {}
local LANGUAGE_SHORTS = {}
local VOICES_NAMES = {}

for _, langs in pairs(LANGUAGES) do
  table.insert(LANGUAGE_NAMES, langs[1])
  table.insert(LANGUAGE_SHORTS, langs[2])
end

for _, voice in pairs(VOICES) do
  table.insert(VOICES_NAMES, voice)
end

local os_name = os.platform()
local default_executable
if os_name == "WINDOWS" then
  default_executable = "C:\\Program Files\\espeak\\espeak.exe"
elseif os_name == "MACINTOSH" then
  default_executable = "/opt/homebrew/bin/espeak-ng"
else
  default_executable = "/usr/bin/espeak-ng"
end

function PakettieSpeakConvertPath(path)
  path = tostring(path)
  if os_name == "WINDOWS" then
    return string.gsub(path, "/", "\\")
  else
    return path
  end
end

function PakettieSpeakRevertPath(path)
  path = tostring(path)
  if os_name == "WINDOWS" then
    return string.gsub(path, "\\", "/")
  else
    return path
  end
end

local selected_textfile = ""

function PakettieSpeakLoadTextfile(refresh)
  if not refresh then
    selected_textfile = renoise.app():prompt_for_filename_to_read({"*.txt"}, "Load Textfile")
  end
  if selected_textfile ~= "" then
    local file = io.open(selected_textfile, "r")
    if file then
      local content = file:read("*all")
      file:close()
      vb.views.PakettieSpeak_text_field.text = content
      vb.views.PakettieSpeak_load_textfile_button.text = selected_textfile:match("[^/\\]+$")
      print("Loaded textfile:", content)
      eSpeak.text.value = content
      PakettieSpeakCreateSample()
      PakettieSpeakUpdateLineCount() -- Update line count after loading textfile
    else
      renoise.app():show_error("Failed to read the file.")
    end
  end
end

function PakettieSpeakGetLines(text)
  local lines = {}
  for line in text:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  return lines
end

function PakettieSpeakUpdateLineCount()
  if not dialog then return end
  local text = vb.views.PakettieSpeak_text_field.text
  local lines = PakettieSpeakGetLines(text)
  local line_count = #lines
  vb.views.PakettieSpeak_which_row.max = math.max(line_count, 1)
  if vb.views.PakettieSpeak_which_row.value > line_count then
    vb.views.PakettieSpeak_which_row.value = 0 -- Set to 0 to render all text
  end
end

local dialog_width=300
local control_width=190
local valuebox_width=60
local button_width=190

local path_to_espeak = vb:text{width=control_width,height=24,text="Path to eSpeak",font="bold"}

local randomize_everything = vb:row{
      vb:button{id = "PakettieSpeak_randomize_everything",
      text="Randomized String",
        width=button_width + button_width,
        height=24,
        notifier=function()
          local characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#€%&/()=?"
          local result = ""
          local count = math.random(10, 100)
          for i = 1, count do
            local random_index = math.random(1, #characters)
            result = result .. characters:sub(random_index, random_index)
          end
          vb.views.PakettieSpeak_text_field.text = result
          eSpeak.text.value = result
          PakettieSpeakCreateSample()
          PakettieSpeakUpdateLineCount()
        end
      }
    }
    
    local randomize_consonants = vb:button{id = "PakettieSpeak_randomize_consonants",
        text="Randomize Consonants",
        width=button_width,
        height=24,
        notifier=function()
          local consonants = "bcdfghjklmnpqrstvwxyz"
          local result = ""
          local count = math.random(10, 100)
          for i = 1, count do
            local random_index = math.random(1, #consonants)
            result = result .. consonants:sub(random_index, random_index)
          end
          vb.views.PakettieSpeak_text_field.text = result
          eSpeak.text.value = result
          PakettieSpeakCreateSample()
          PakettieSpeakUpdateLineCount()
        end
              }

local randomize_vowels = vb:button{id = "PakettieSpeak_randomize_vowels",
        text="Randomize Vowels",
        width=button_width,
        height=24,
        notifier=function()
          local vowels = "aeiou"
          local result = ""
          local count = math.random(10, 100)
          for i = 1, count do
            local random_index = math.random(1, #vowels)
            result = result .. vowels:sub(random_index, random_index)
          end
          vb.views.PakettieSpeak_text_field.text = result
          eSpeak.text.value = result
          PakettieSpeakCreateSample()
          PakettieSpeakUpdateLineCount()
        end
      }
    

local exe_button = vb:button{id="PakettieSpeak_exe_button",
        width=control_width,
        height = 24,
        text = PakettieSpeakRevertPath(eSpeak.executable),
        notifier=function()
          local filename = renoise.app():prompt_for_filename_to_read({"*.*"}, "Select Executable")
          if filename ~= "" then
          
            eSpeak.executable = PakettieSpeakConvertPath(filename)
            renoise.tool().preferences.pakettieSpeak.executable = eSpeak.executable
            vb.views.PakettieSpeak_exe_button.text = PakettieSpeakRevertPath(eSpeak.executable)
            vb.views.PakettieSpeak_exe_button.width=math.min(#vb.views.PakettieSpeak_exe_button.text * 8, control_width)
          end end}

local horalign=vb:horizontal_aligner{mode="right",path_to_espeak,exe_button}
local consonants_vowels=vb:row{randomize_consonants,randomize_vowels,}

local loadtext_refresh=vb:row{
      vb:button{id = "PakettieSpeak_load_textfile_button",
        text="Load Textfile",width=button_width,height=24,
        notifier=function()
          PakettieSpeakLoadTextfile(false)
        end
      },
      vb:button{text="Refresh",width=button_width,height=24,
        notifier=function()
          PakettieSpeakLoadTextfile(true)
          print("Refresh: loaded textfile and updated textfield")
          eSpeak.text.value = vb.views.PakettieSpeak_text_field.text
          PakettieSpeakUpdateLineCount()
        end
      }
    }

local eSpeak_textfield=vb:column{
      margin=renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN,
      spacing=renoise.ViewBuilder.DEFAULT_CONTROL_SPACING,
      width=380,
      style = "group",
      vb:multiline_textfield{id="PakettieSpeak_text_field",width=373,height=100,
        style = "border",
        text = tostring(eSpeak.text.value),
        notifier=function() PakettieSpeakUpdateLineCount() end}}

local which_row= vb:row{
      vb:text{text="Which row:",width=80},
      vb:valuebox{
        id = "PakettieSpeak_which_row",
        min = 0,
        max = 1,
        value = 0,
        notifier=function(value)
          local text = vb.views.PakettieSpeak_text_field.text
          local lines = PakettieSpeakGetLines(text)
          if value == 0 then
            eSpeak.text.value = text -- Render all text
          else
            local selected_line = lines[value] or ""
            eSpeak.text.value = selected_line
          end
          if eSpeak.render_on_change.value then
            PakettieSpeakCreateSample(eSpeak.text.value)
          end
        end
      }
    }

function PakettieSpeakUpdateSelection()
  local text = vb.views.PakettieSpeak_text_field.text
  local start = vb.views.PakettieSpeak_start_pos.value
  local length = vb.views.PakettieSpeak_length_pos.value
  local max_length = #text - start + 1
  if length > max_length then
    length = max_length
    vb.views.PakettieSpeak_length_pos.value = length
    renoise.app():show_status("No more can be selected")
  end
  if length == 0 then
    vb.views.PakettieSpeak_selection_display.text=""
  else
    local end_pos = start + length - 1
    if start <= #text and end_pos <= #text and start <= end_pos then
      local selected_text = text:sub(start, end_pos)
      vb.views.PakettieSpeak_selection_display.text = selected_text
    end
  end
end

local start_pos=    vb:row{
      vb:text{text="Start:",width=80},
      vb:valuebox{
        id = "PakettieSpeak_start_pos",
        min = 1,
        max = 500,
        value = 1,
        notifier = PakettieSpeakUpdateSelection
      },
      vb:text{text="Length:"},
      vb:valuebox{
        id = "PakettieSpeak_length_pos",
        min = 0,
        max = 500,
        value = 0,
        notifier=function()
          PakettieSpeakUpdateSelection()
        end
      },
      vb:button{
        text="-",
        width=20,
        notifier=function()
          if vb.views.PakettieSpeak_length_pos.value > 0 then
            vb.views.PakettieSpeak_length_pos.value = vb.views.PakettieSpeak_length_pos.value - 1
            PakettieSpeakUpdateSelection()
            if eSpeak.render_on_change.value then
              PakettieSpeakCreateSample(vb.views.PakettieSpeak_selection_display.text)
            end
          end
        end
      },
      vb:button{
        text="+",
        width=20,
        notifier=function()
          if vb.views.PakettieSpeak_length_pos.value < 500 then
            vb.views.PakettieSpeak_length_pos.value = vb.views.PakettieSpeak_length_pos.value + 1
            PakettieSpeakUpdateSelection()
            if eSpeak.render_on_change.value then
              PakettieSpeakCreateSample(vb.views.PakettieSpeak_selection_display.text)
            end
          end
        end
      }
    }

local eSpeakselection=   vb:row{
      vb:text{text="Selection:",width=80},
      vb:textfield{
        id = "PakettieSpeak_selection_display",
        width=290,
        height = 20,
        edit_mode = false
      }
    }
 local eSpeakGenerateSelection=   vb:horizontal_aligner{
      mode = "center",
      vb:button{
        text="Generate Selection",
        width=button_width,
        height = 24,
        notifier=function()
          local text = vb.views.PakettieSpeak_text_field.text
          local start = vb.views.PakettieSpeak_start_pos.value
          local length = vb.views.PakettieSpeak_length_pos.value
          local end_pos = start + length - 1
          if start <= #text and end_pos <= #text and start <= end_pos then
            local selected_text = text:sub(start, end_pos)
            print("Selected text:", selected_text)
            renoise.app():show_status("Selected text: " .. selected_text)
            eSpeak.text.value = selected_text
            PakettieSpeakCreateSample()
          else
            renoise.app():show_status("Invalid selection range")
          end
        end
      }
    }

local settingsControls=      vb:row{
        vb:text{text="Language:",width=80},
        vb:popup{
          id = "PakettieSpeak_language",
          width=250,
          items = LANGUAGE_NAMES,
          value = eSpeak.language.value,
          notifier=function(idx)
            if not button_press_active then
              eSpeak.language.value = idx
              if eSpeak.render_on_change.value then PakettieSpeakCreateSample(eSpeak.text.value) end
            end
          end
        },
        vb:button{
          text="-",
          width=20,
          notifier=function()
            if vb.views.PakettieSpeak_language.value > 1 then
              button_press_active = true
              vb.views.PakettieSpeak_language.value = vb.views.PakettieSpeak_language.value - 1
              eSpeak.language.value = vb.views.PakettieSpeak_language.value
              if eSpeak.render_on_change.value then PakettieSpeakCreateSample(eSpeak.text.value) end
              button_press_active = false
            else
              renoise.app():show_status("You are at the beginning of the list.")
            end
          end
        },
        vb:button{
          text="+",
          width=20,
          notifier=function()
            if vb.views.PakettieSpeak_language.value < #LANGUAGE_NAMES then
              button_press_active = true
              vb.views.PakettieSpeak_language.value = vb.views.PakettieSpeak_language.value + 1
              eSpeak.language.value = vb.views.PakettieSpeak_language.value
              if eSpeak.render_on_change.value then PakettieSpeakCreateSample(eSpeak.text.value) end
              button_press_active = false
            else
              renoise.app():show_status("You are at the bottom of the list.")
            end
          end
        }
      }

local eSpeakvoice=      vb:row{
        vb:text{text="Voice:",width=80},        vb:popup{
          id = "PakettieSpeak_voice",
          width=250,
          items = VOICES,
          value = eSpeak.voice.value,
          notifier=function(idx)
            if not button_press_active then
              eSpeak.voice.value = idx
              if eSpeak.render_on_change.value then PakettieSpeakCreateSample(eSpeak.text.value) end
            end
          end
        },
        vb:button{
          text="-",
          width=20,
          notifier=function()
            if vb.views.PakettieSpeak_voice.value > 2 then
              button_press_active = true
              vb.views.PakettieSpeak_voice.value = vb.views.PakettieSpeak_voice.value - 1
              eSpeak.voice.value = vb.views.PakettieSpeak_voice.value
              if eSpeak.render_on_change.value then PakettieSpeakCreateSample(eSpeak.text.value) end
              button_press_active = false
            else
              renoise.app():show_status("You are at the beginning of the list")
            end
          end
        },
        vb:button{
          text="+",
          width=20,
          notifier=function()
            if vb.views.PakettieSpeak_voice.value < #VOICES then
              button_press_active = true
              vb.views.PakettieSpeak_voice.value = vb.views.PakettieSpeak_voice.value + 1
              eSpeak.voice.value = vb.views.PakettieSpeak_voice.value
              if eSpeak.render_on_change.value then PakettieSpeakCreateSample(eSpeak.text.value) end
              button_press_active = false
            else
              renoise.app():show_status("You are at the bottom of the list")
            end
          end
        }}

local eSpeakgapbox= vb:row{
        vb:text{width=80, text="Word Gap:"},
        vb:valuebox{
          id = "PakettieSpeak_gap_box",
          width=valuebox_width,
          min = 1,
          max = 10000,
          value = eSpeak.word_gap.value,
          steps = {1, 10, 100},
          notifier=function(gap)
            eSpeak.word_gap.value = gap
            print("Word Gap set to:", gap)
          end
        }
      }

local eSpeakpitchcap=  vb:row{
        vb:text{width=80, text="Pitch Capitals:"},
        vb:valuebox{
          id = "PakettieSpeak_capitals_box",
          width=valuebox_width,
          min = 1,
          max = 100,
          value = eSpeak.capitals.value,
          steps = {1, 5},
          notifier=function(capitals)
            eSpeak.capitals.value = capitals
            print("Pitch Capitals set to:", capitals)
          end
        }
      }

local eSpeakpitchbox=     vb:row{
        vb:text{width=80, text="Pitch:"},
        vb:valuebox{
          id = "PakettieSpeak_pitch_box",
          width=valuebox_width,
          min = 0,
          max = 99,
          value = eSpeak.pitch.value,
          steps = {1, 5},
          notifier=function(pitch)
            eSpeak.pitch.value = pitch
            print("Pitch set to:", pitch)
          end
        }
      }

local eSpeakamplitude=      vb:row{
        vb:text{width=80, text="Amplitude:"},
        vb:valuebox{
          id = "PakettieSpeak_amplitude_box",
          width=valuebox_width,
          min = 0,
          max = 200,
          value = eSpeak.amplitude.value,
          steps = {1, 5},
          notifier=function(amplitude)
            eSpeak.amplitude.value = amplitude
            print("Amplitude set to:", amplitude)
          end
        }
      }
      
      local eSpeakspeedbox=  vb:row{
        vb:text{width=80, text="Speed:"},
        vb:valuebox{
          id = "PakettieSpeak_speed_box",
          width=valuebox_width,
          min = 1,
          max = 500,
          value = eSpeak.speed.value,
          steps = {1, 5},
          notifier=function(speed)
            eSpeak.speed.value = speed
            print("Speed set to:", speed)
          end
        }
      }

local settingsColumn=    vb:column{
      margin=renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN,
      spacing=renoise.ViewBuilder.DEFAULT_CONTROL_SPACING,
      width=373,
         settingsControls,
 
          eSpeakvoice,
    eSpeakgapbox,
    eSpeakpitchcap,
    eSpeakpitchbox,
    eSpeakamplitude,
    eSpeakspeedbox,}
 local clearallsamples=   -- Checkboxes
    vb:row{
      vb:checkbox{
        id = "PakettieSpeak_clear_all_samples",
        width=18,
        height = 18,
        value = eSpeak.clear_all_samples.value == true,
        notifier=function(bool)
          eSpeak.clear_all_samples.value = bool
          print("Clear All Samples set to:", bool)
        end
      },
      vb:text{text="Overwrite Samples in Selected Instrument"}
    }
 local addrendertocurrentinstrument=vb:row{
  vb:checkbox{
    id = "PakettieSpeak_add_render_to_current_instrument",
    width=18,
    height = 18,
    value = eSpeak.add_render_to_current_instrument.value == true,
    notifier=function(bool)
      eSpeak.add_render_to_current_instrument.value = bool
      vb.views.PakettieSpeak_clear_all_samples.value = false
      print("Add Render to Current Instrument set to:", bool)
    end
  },
  vb:text{text="Add Render to Current Instrument"}
}

local dont_pakettify_checkbox = vb:row{
  vb:checkbox{
      id = "PakettieSpeak_dont_pakettify",
      width=18,
      height = 18,
      value = eSpeak.dont_pakettify.value,
      notifier=function(bool)
          eSpeak.dont_pakettify.value = bool
          print("Don't Pakettify set to:", bool)
      end
  },
  vb:text{text="Don't Pakettify"}
}

 local renderonchange= vb:row{
      vb:checkbox{
        id = "PakettieSpeak_render_on_change",
        width=18,
        height = 18,
        value = eSpeak.render_on_change.value == true,
        notifier=function(bool)
          eSpeak.render_on_change.value = bool
          print("Render on Change set to:", bool)
        end
      },
      vb:text{text="+/- Click Should Render Again"}
    }
local eSpeakloadsave=    vb:horizontal_aligner{
      mode = "center",
      vb:button{
        id = "PakettieSpeak_load_button",
        width=button_width,
        height = 24,
        text="Load Settings",
        notifier=function()
          local filename = renoise.app():prompt_for_filename_to_read({"*.rts"}, "Load Settings")
          if filename ~= "" then
            local result = eSpeak:load_from(filename)
            if result == nil then
              renoise.app():show_error("Unable to Load Settings.")
            else
              print("Loaded Settings:", result)
              vb.views.PakettieSpeak_text_field.text = tostring(eSpeak.text.value)
              vb.views.PakettieSpeak_language.value = eSpeak.language.value
              vb.views.PakettieSpeak_voice.value = eSpeak.voice.value
              vb.views.PakettieSpeak_gap_box.value = eSpeak.word_gap.value
              vb.views.PakettieSpeak_capitals_box.value = eSpeak.capitals.value
              vb.views.PakettieSpeak_pitch_box.value = eSpeak.pitch.value
              vb.views.PakettieSpeak_amplitude_box.value = eSpeak.amplitude.value
              vb.views.PakettieSpeak_speed_box.value = eSpeak.speed.value
              local espeak_executable = PakettieSpeakRevertPath(eSpeak.executable)
              vb.views.PakettieSpeak_exe_button.text = espeak_executable
              vb.views.PakettieSpeak_exe_button.width=math.min(#vb.views.PakettieSpeak_exe_button.text * 8, control_width)
              renoise.tool().preferences.pakettieSpeak.executable = espeak_executable
              vb.views.PakettieSpeak_clear_all_samples.value = eSpeak.clear_all_samples.value == true
              vb.views.PakettieSpeak_render_on_change.value = eSpeak.render_on_change.value == true
              PakettieSpeakUpdateLineCount()
            end
          end
        end
        
      },
      vb:button{
        id = "PakettieSpeak_save_button",
        width=button_width,
        height = 24,
        text="Save Settings",
        notifier=function()
          local filename = renoise.app():prompt_for_filename_to_write("*.rts", "Save Settings")
          if filename ~= "" then
            eSpeak.text.value = vb.views.PakettieSpeak_text_field.text
            local result = eSpeak:save_as(filename)
            if result == nil then
              renoise.app():show_error("Unable to Save Settings.")
            else
              print("Saved Settings:", result)
            end
          end
        end
      }
    }

local lastbuttons=    vb:horizontal_aligner{
      mode = "center",
      vb:button{
        text="Generate Sample",
        width=button_width,
        height = 24,
        notifier=function()
          eSpeak.text.value = vb.views.PakettieSpeak_text_field.text
          PakettieSpeakCreateSample()
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
        end
      },
      vb:button{
        text="Randomize Settings",
        width=button_width,
        height = 24,
        notifier=function()
          vb.views.PakettieSpeak_language.value = math.random(1, #LANGUAGE_NAMES)
          eSpeak.language.value = vb.views.PakettieSpeak_language.value
          vb.views.PakettieSpeak_voice.value = math.random(1, #VOICES)
          eSpeak.voice.value = vb.views.PakettieSpeak_voice.value
          local random_gap = math.random(1, 100)
          vb.views.PakettieSpeak_gap_box.value = random_gap
          eSpeak.word_gap.value = random_gap
          local random_capitals = math.random(1, 100)
          vb.views.PakettieSpeak_capitals_box.value = random_capitals
          eSpeak.capitals.value = random_capitals
          local random_pitch = math.random(0, 99)
          vb.views.PakettieSpeak_pitch_box.value = random_pitch
          eSpeak.pitch.value = random_pitch
          local random_speed = math.random(1, 500)
          vb.views.PakettieSpeak_speed_box.value = random_speed
          eSpeak.speed.value = random_speed
          if eSpeak.render_on_change.value then
            PakettieSpeakCreateSample(eSpeak.text.value)
          end
          eSpeak.text.value = vb.views.PakettieSpeak_text_field.text
          PakettieSpeakCreateSample()
        end
      }
    }

 local wholegui=vb:column{
    width=dialog_width,
    horalign,
    randomize_everything,
    consonants_vowels,
    loadtext_refresh,
    eSpeak_textfield,
    which_row, 
    start_pos,
    eSpeakselection,
    eSpeakGenerateSelection,
    settingsColumn,
    clearallsamples,
    addrendertocurrentinstrument,
    dont_pakettify_checkbox,
    renderonchange,
    eSpeakloadsave,
    lastbuttons}
    
 
function PakettieSpeakMakeGUI()
  return wholegui
end

function PakettieSpeakShowGUI()
  local gui = PakettieSpeakMakeGUI()
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti eSpeak Text-to-Speech", gui, keyhandler)
  PakettieSpeakUpdateLineCount() -- Update line count when showing the dialog
end

function PakettieSpeakPrepare()
  print("Starting dialog with settings:")
  print("Text:",eSpeak.text.value)
  print("Loaded Language:",eSpeak.language.value)
  print("Loaded Voice:",eSpeak.voice.value)
  print("Loaded Word Gap:",eSpeak.word_gap.value)
  print("Loaded Pitch Capitals:",eSpeak.capitals.value)
  print("Loaded Pitch:",eSpeak.pitch.value)
  print("Loaded Amplitude:",eSpeak.amplitude.value)
  print("Loaded Speed:",eSpeak.speed.value)
  print("Loaded Executable:",eSpeak.executable.value)
  print("Loaded Clear All Samples:",eSpeak.clear_all_samples.value)
  
  if dialog and dialog.visible then
    dialog:show()
    return
  end

  local espeak_location = renoise.tool().preferences.pakettieSpeak.executable
  if espeak_location ~= "" then
    eSpeak.executable = PakettieSpeakConvertPath(espeak_location)
  else
    renoise.app():show_alert("Please set the eSpeak path before running.")
    return
  end

  PakettieSpeakShowGUI()
end

function PakettieSpeakKeyHandlerFunc(dialog, key)
--  if key.modifiers == "" and key.name == "esc" then
if key.modifiers == "control" and key.name == "r" then
          PakettieSpeakLoadTextfile(true)
          print("Refresh: loaded textfile and updated textfield")
          eSpeak.text.value = vb.views.PakettieSpeak_text_field.text
          PakettieSpeakUpdateLineCount()
end

if key.modifiers == "control" and key.name == "return" then
      eSpeak.text.value = vb.views.PakettieSpeak_text_field.text
      PakettieSpeakCreateSample()
end

if key.modifiers == "alt" and key.name == "return" then
          local text = vb.views.PakettieSpeak_text_field.text
          local start = vb.views.PakettieSpeak_start_pos.value
          local length = vb.views.PakettieSpeak_length_pos.value
          local end_pos = start + length - 1
          if start <= #text and end_pos <= #text and start <= end_pos then
            local selected_text = text:sub(start, end_pos)
            print("Selected text:", selected_text)
            renoise.app():show_status("Selected text: " .. selected_text)
            eSpeak.text.value = selected_text
            PakettieSpeakCreateSample()
          else
            renoise.app():show_status("Invalid selection range")
          end


end

local closer = preferences.pakettiDialogClose.value
print (closer)
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    dialog = nil
    --vb = nil
  else
    return key
  end
end

function pakettieSpeakDialog()
  if dialog and dialog.visible then
    eSpeak.text.value = vb.views.PakettieSpeak_text_field.text
    PakettieSpeakCreateSample()
  else
    PakettieSpeakPrepare()
  end
end

function PakettieSpeakCreateSample(custom_text)
  local text_to_render = custom_text or eSpeak.text.value
  print(text_to_render)

  -- Create the process slicer with our process function
  local process = ProcessSlicer(function(text_to_render, dialog, vb)
    -- This is the actual process function that will be run by ProcessSlicer
    local executable = PakettieSpeakRevertPath(eSpeak.executable)
    local path = os.tmpname() .. ".wav"

    -- Update progress text
    if dialog and dialog.visible then
      vb.views.progress_text.text="Running eSpeak text-to-speech engine..."
    end
    
    -- Quote the executable and path to handle spaces
    local cmd = '"' .. executable .. '"'
    cmd = cmd .. " -a " .. eSpeak.amplitude.value
    cmd = cmd .. " -v " .. LANGUAGE_SHORTS[eSpeak.language.value]

    if eSpeak.voice.value ~= 1 then
      cmd = cmd .. "+" .. VOICES[eSpeak.voice.value]
    end

    cmd = cmd .. " -b 1 -m "
    cmd = cmd .. " -p " .. eSpeak.pitch.value
    cmd = cmd .. " -s " .. eSpeak.speed.value
    cmd = cmd .. " -g " .. eSpeak.word_gap.value
    cmd = cmd .. " -k " .. eSpeak.capitals.value
    cmd = cmd .. ' -w "' .. path .. '"'
    cmd = cmd .. ' "' .. text_to_render .. '"'

    print("Command to be executed:" .. cmd)

    -- Allow UI to update
    coroutine.yield()
    
    os.execute(cmd)

    -- Allow UI to update
    coroutine.yield()

    if dialog and dialog.visible then
      vb.views.progress_text.text="Setting up instrument..."
    end

    -- Set up instrument and sample slots
    local ok, err = pcall(function()
      local song=renoise.song()
      local instrument = nil

      -- Check if "Add Render to Current Instrument" is Enabled
      if eSpeak.add_render_to_current_instrument.value then
        -- If No Instruments Exist, Load the Pitchbend Instrument
        if not eSpeak.dont_pakettify.value and #song.instruments == 0 then
          pakettiPreferencesDefaultInstrumentLoader()
        end

        instrument = song.selected_instrument
        if not instrument then
          error("No instrument selected")
        end

        -- Add a New Sample Slot to the Current Instrument
        local new_sample_index = #instrument.samples + 1
        local sample = instrument:insert_sample_at(new_sample_index)
        song.selected_sample_index = new_sample_index
        sample.name = "eSpeak (" .. LANGUAGE_NAMES[eSpeak.language.value] .. ", " .. VOICES_NAMES[eSpeak.voice.value] .. ")"
        instrument.name = "eSpeak (" .. LANGUAGE_NAMES[eSpeak.language.value] .. ", " .. VOICES_NAMES[eSpeak.voice.value] .. ")"
        print("Added new sample slot to current instrument:", sample.name)

      elseif eSpeak.clear_all_samples.value then
        
        instrument = song.selected_instrument
        if not instrument then
          error("No instrument selected")
        end
        
        if not eSpeak.dont_pakettify.value then 
          pakettiPreferencesDefaultInstrumentLoader() 
        end 
        
        while #instrument.samples > 0 do
          instrument:delete_sample_at(1)
        end
        
        local sample = instrument:insert_sample_at(1)
        song.selected_sample_index = 1
        sample.name = "eSpeak (" .. LANGUAGE_NAMES[eSpeak.language.value] .. ", " .. VOICES_NAMES[eSpeak.voice.value] .. ")"
        instrument.name = "eSpeak (" .. LANGUAGE_NAMES[eSpeak.language.value] .. ", " .. VOICES_NAMES[eSpeak.voice.value] .. ")"
        print("Cleared all samples and added new sample:", sample.name)

      else
        
        instrument = song:insert_instrument_at(song.selected_instrument_index + 1)
        song.selected_instrument_index = song.selected_instrument_index + 1
        if not eSpeak.dont_pakettify.value then 
          pakettiPreferencesDefaultInstrumentLoader() 
        end 
        instrument = song.selected_instrument
        instrument.name = "eSpeak (" .. LANGUAGE_NAMES[eSpeak.language.value] .. ", " .. VOICES_NAMES[eSpeak.voice.value] .. ")"
        local sample = instrument:insert_sample_at(1)
        sample.name = "eSpeak (" .. LANGUAGE_NAMES[eSpeak.language.value] .. ", " .. VOICES_NAMES[eSpeak.voice.value] .. ")"
        song.selected_sample_index = 1
        print("Inserted new instrument and added sample:", sample.name)
      end
    end)

    if not ok then
      if dialog and dialog.visible then
        dialog:close()
      end
      renoise.app():show_error("Failed to set up instrument: " .. tostring(err))
      return
    end

    -- Allow UI to update
    coroutine.yield()

    if dialog and dialog.visible then
      vb.views.progress_text.text="Loading sample..."
    end

    -- Load the sample
    ok, err = pcall(function()
      local song=renoise.song()
      local sample = song.selected_sample
      if not sample then error("No sample selected") end
      
      local buffer = sample.sample_buffer
      if not buffer then error("No sample buffer available") end

      if not PakettieSpeakFileExists(path) then
        error("Sample was not rendered")
      end

      print("Loading sample from:", path)
      local success = buffer:load_from(path)
      if not success then
        error("Failed to load sample from file")
      end

      -- Wait for the sample to be fully loaded
      buffer:prepare_sample_data_changes()
      buffer:finalize_sample_data_changes()

      -- Ensure proper naming after loading
      local current_instrument = song.selected_instrument
      if current_instrument then
        current_instrument.name = "eSpeak (" .. LANGUAGE_NAMES[eSpeak.language.value] .. ", " .. VOICES_NAMES[eSpeak.voice.value] .. ")"
      end
      if sample then
        sample.name = "eSpeak (" .. LANGUAGE_NAMES[eSpeak.language.value] .. ", " .. VOICES_NAMES[eSpeak.voice.value] .. ")"
      end
      
      -- Now that sample is loaded, try to normalize
      if dialog and dialog.visible then
        vb.views.progress_text.text="Normalizing volume..."
      end

      -- Try to normalize now that we have a valid sample
      if not normalize_selected_sample() then
        print("Normalization skipped - no valid sample")
      end

      -- Double check names one final time
      current_instrument = song.selected_instrument
      sample = song.selected_sample
      if current_instrument then
        current_instrument.name = "eSpeak (" .. LANGUAGE_NAMES[eSpeak.language.value] .. ", " .. VOICES_NAMES[eSpeak.voice.value] .. ")"
      end
      if sample then
        sample.name = "eSpeak (" .. LANGUAGE_NAMES[eSpeak.language.value] .. ", " .. VOICES_NAMES[eSpeak.voice.value] .. ")"
      end
    end)

    if not ok then
      if dialog and dialog.visible then
        dialog:close()
      end
      renoise.app():show_error("Failed to process sample: " .. tostring(err))
      return
    end

    -- Allow UI to update
    coroutine.yield()

    -- Try to switch view
    pcall(function()
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    end)

    print("Sample processing completed")

    -- Clean up
    if dialog and dialog.visible then
      dialog:close()
    end
  end)
  
  -- Create the progress dialog
  local dialog, vb = process:create_dialog("Generating Speech")
  
  -- Start the process with our parameters
  process.__process_func_args = {text_to_render, dialog, vb}
  process:start()
end

-- Check if file exists
function PakettieSpeakFileExists(path)
  local f = io.open(path, "r")
  return f ~= nil and io.close(f)
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti eSpeak Text-to-Speech Dialog...",invoke=function() pakettieSpeakDialog() end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti eSpeak Generate Sample",invoke=function()
    if dialog and dialog.visible then
      eSpeak.text.value = vb.views.PakettieSpeak_text_field.text
      PakettieSpeakCreateSample()
    else PakettieSpeakPrepare() end end}

renoise.tool():add_keybinding{name="Global:Paketti:Paketti eSpeak Generate Selection",invoke=function()
    if dialog and dialog.visible then
      local text = vb.views.PakettieSpeak_text_field.text
      local start = vb.views.PakettieSpeak_start_pos.value
      local length = vb.views.PakettieSpeak_length_pos.value
      local end_pos = start + length - 1
      if start <= #text and end_pos <= #text and start <= end_pos then
        local selected_text = text:sub(start, end_pos)
        print("Selected text:", selected_text)
        renoise.app():show_status("Selected text: " .. selected_text)
        eSpeak.text.value = selected_text
        PakettieSpeakCreateSample()
      else
        renoise.app():show_status("Invalid selection range")
      end
    else PakettieSpeakPrepare() end end}

for value = 0, 31 do
  renoise.tool():add_keybinding{name=("Global:Paketti:Paketti eSpeak Generate Row %02d"):format(value),invoke=function()
      local text = vb.views.PakettieSpeak_text_field.text
      local lines = PakettieSpeakGetLines(text)
      -- If value is 0, take all the content, otherwise select the specific line.
      local selected_line = (value == 0) and text or (lines[value] or "")
      -- Protection: do nothing if selected line is empty
      if selected_line == "" then return end
      eSpeak.text.value = selected_line
      if eSpeak.render_on_change.value then
        PakettieSpeakCreateSample(eSpeak.text.value) end end}
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti eSpeak Refresh",invoke=function()
    if dialog and dialog.visible then
      PakettieSpeakLoadTextfile(true)
      print("Refresh: loaded textfile and updated textfield")
      eSpeak.text.value = vb.views.PakettieSpeak_text_field.text
      PakettieSpeakUpdateLineCount()
    else PakettieSpeakPrepare() end end}

local function txt_loadfile(filename)
  if dialog and dialog.visible then
    dialog:close()
  end
  selected_textfile = filename
  if selected_textfile ~= "" then
    local file = io.open(selected_textfile, "r")
    if file then
      local content = file:read("*all")
      file:close()
      eSpeak.text.value = content
      PakettieSpeakPrepare()
      PakettieSpeakCreateSample()
      return true
    else
      renoise.app():show_error("Failed to read the text file.")
      return false
    end
  end
  return false
end

local txt_integration = {
  category = "sample",
  extensions = { "txt" },
  invoke = txt_loadfile
}

if not renoise.tool():has_file_import_hook("sample", { "txt" }) then
  renoise.tool():add_file_import_hook(txt_integration)
end

_AUTO_RELOAD_DEBUG = function() end

