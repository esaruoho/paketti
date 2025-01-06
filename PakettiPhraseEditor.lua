-- Ensure the dialog is initialized
local pakettiInitPhraseSettingsDialog = nil

-- Function to load preferences
local function loadPreferences()
  if io.exists("preferences.xml") then
    preferences:load_from("preferences.xml")
  end
end

-- Function to save preferences
local function savePreferences()
  preferences:save_as("preferences.xml")
end

-- Function to apply settings to the selected phrase or create a new one if none exists
function pakettiPhraseSettingsApplyPhraseSettings()
  local instrument = renoise.song().selected_instrument

  -- Check if there are no phrases in the selected instrument
  if #instrument.phrases == 0 then
    instrument:insert_phrase_at(1)
    renoise.song().selected_phrase_index = 1
  elseif renoise.song().selected_phrase_index == 0 then
    renoise.song().selected_phrase_index = 1
  end

  local phrase = renoise.song().selected_phrase

  -- Apply the name to the phrase if "Set Name" is checked and the name text field has a value
  if preferences.pakettiPhraseInitDialog.SetName.value then
    local custom_name = preferences.pakettiPhraseInitDialog.Name.value
    if custom_name ~= "" then
      phrase.name = custom_name
    else
      phrase.name = string.format("Phrase %02d", renoise.song().selected_phrase_index)
    end
  end

  -- Apply other settings to the phrase
  phrase.autoseek = preferences.pakettiPhraseInitDialog.Autoseek.value
  phrase.volume_column_visible = preferences.pakettiPhraseInitDialog.VolumeColumnVisible.value
  phrase.panning_column_visible = preferences.pakettiPhraseInitDialog.PanningColumnVisible.value
  phrase.instrument_column_visible = preferences.pakettiPhraseInitDialog.InstrumentColumnVisible.value
  phrase.delay_column_visible = preferences.pakettiPhraseInitDialog.DelayColumnVisible.value
  phrase.sample_effects_column_visible = preferences.pakettiPhraseInitDialog.SampleFXColumnVisible.value
  phrase.visible_note_columns = preferences.pakettiPhraseInitDialog.NoteColumns.value
  phrase.visible_effect_columns = preferences.pakettiPhraseInitDialog.EffectColumns.value
  phrase.shuffle = preferences.pakettiPhraseInitDialog.Shuffle.value / 100
  phrase.lpb = preferences.pakettiPhraseInitDialog.LPB.value
  phrase.number_of_lines = preferences.pakettiPhraseInitDialog.Length.value
end

-- Function to create a new phrase and apply settings
function pakettiInitPhraseSettingsCreateNewPhrase()
  renoise.app().window.active_middle_frame = 3
  local instrument = renoise.song().selected_instrument
  local phrase_count = #instrument.phrases
  local new_phrase_index = phrase_count + 1

  -- Insert the new phrase at the end of the phrase list
  instrument:insert_phrase_at(new_phrase_index)
  renoise.song().selected_phrase_index = new_phrase_index

  -- If "Set Name" is checked, use the name from the text field, otherwise use the default
  if preferences.pakettiPhraseInitDialog.SetName.value then
    local custom_name = preferences.pakettiPhraseInitDialog.Name.value
    if custom_name ~= "" then
      preferences.pakettiPhraseInitDialog.Name.value = custom_name
    else
      preferences.pakettiPhraseInitDialog.Name.value = string.format("Phrase %02d", new_phrase_index)
    end
  end

  pakettiPhraseSettingsApplyPhraseSettings()
end

-- Function to modify the current phrase or create a new one if none exists
function pakettiPhraseSettingsModifyCurrentPhrase()
  local instrument = renoise.song().selected_instrument
  if #instrument.phrases == 0 then
    pakettiInitPhraseSettingsCreateNewPhrase()
  else
    pakettiPhraseSettingsApplyPhraseSettings()
  end
end

-- Function to handle key events for the dialog (including closing it)
function pakettiPhraseSettingsKeyHandler(dialog, key)
local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    pakettiInitPhraseSettingsDialog = nil
    return nil
else
    return key
  end
end

-- Function to show the PakettiInitPhraseSettingsDialog
function pakettiPhraseSettingsDialogShow()
  if pakettiInitPhraseSettingsDialog and pakettiInitPhraseSettingsDialog.visible then
    pakettiInitPhraseSettingsDialog:close()
    pakettiInitPhraseSettingsDialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local phrase = renoise.song().selected_phrase
  if phrase then
    preferences.pakettiPhraseInitDialog.Name.value = phrase.name
  end

  pakettiInitPhraseSettingsDialog = renoise.app():show_custom_dialog(
    "Paketti Phrase Default Settings Dialog",
    vb:column {
      margin = 10,
      -- "Set Name" Checkbox above the Phrase Name field
      vb:row {
        vb:checkbox {
          id = "set_name_checkbox",
          value = preferences.pakettiPhraseInitDialog.SetName.value,
          notifier = function(value)
            preferences.pakettiPhraseInitDialog.SetName.value = value
          end
        },
        vb:text {text = "Set Name", width = 150},
      },
      vb:row {
        vb:text {text = "Phrase Name:", width = 150},
        vb:textfield {
          id = "phrase_name_textfield",
          width = 300,
          text = preferences.pakettiPhraseInitDialog.Name.value,
          notifier = function(value) preferences.pakettiPhraseInitDialog.Name.value = value end
        }
      },
      vb:row {
        vb:text {text = "Autoseek:", width = 150},
        vb:switch {
          id = "autoseek_switch",
          width = 300,
          items = {"Off", "On"},
          value = preferences.pakettiPhraseInitDialog.Autoseek.value and 2 or 1,
          notifier = function(value) preferences.pakettiPhraseInitDialog.Autoseek.value = (value == 2) end
        }
      },
      vb:row {
        vb:text {text = "Volume Column Visible:", width = 150},
        vb:switch {
          id = "volume_column_visible_switch",
          width = 300,
          items = {"Off", "On"},
          value = preferences.pakettiPhraseInitDialog.VolumeColumnVisible.value and 2 or 1,
          notifier = function(value) preferences.pakettiPhraseInitDialog.VolumeColumnVisible.value = (value == 2) end
        }
      },
      vb:row {
        vb:text {text = "Panning Column Visible:", width = 150},
        vb:switch {
          id = "panning_column_visible_switch",
          width = 300,
          items = {"Off", "On"},
          value = preferences.pakettiPhraseInitDialog.PanningColumnVisible.value and 2 or 1,
          notifier = function(value) preferences.pakettiPhraseInitDialog.PanningColumnVisible.value = (value == 2) end
        }
      },
      vb:row {
        vb:text {text = "Instrument Column Visible:", width = 150},
        vb:switch {
          id = "instrument_column_visible_switch",
          width = 300,
          items = {"Off", "On"},
          value = preferences.pakettiPhraseInitDialog.InstrumentColumnVisible.value and 2 or 1,
          notifier = function(value) preferences.pakettiPhraseInitDialog.InstrumentColumnVisible.value = (value == 2) end
        }
      },
      vb:row {
        vb:text {text = "Delay Column Visible:", width = 150},
        vb:switch {
          id = "delay_column_visible_switch",
          width = 300,
          items = {"Off", "On"},
          value = preferences.pakettiPhraseInitDialog.DelayColumnVisible.value and 2 or 1,
          notifier = function(value) preferences.pakettiPhraseInitDialog.DelayColumnVisible.value = (value == 2) end
        }
      },
      vb:row {
        vb:text {text = "Sample FX Column Visible:", width = 150},
        vb:switch {
          id = "samplefx_column_visible_switch",
          width = 300,
          items = {"Off", "On"},
          value = preferences.pakettiPhraseInitDialog.SampleFXColumnVisible.value and 2 or 1,
          notifier = function(value) preferences.pakettiPhraseInitDialog.SampleFXColumnVisible.value = (value == 2) end
        }
      },     
      
      vb:row {
        vb:text {text = "Visible Note Columns:", width = 150},
        vb:switch {
          id = "note_columns_switch",
          width = 300,
          value = preferences.pakettiPhraseInitDialog.NoteColumns.value,
          items = {"1","2","3","4","5","6","7","8","9","10","11","12"},
          notifier = function(value) preferences.pakettiPhraseInitDialog.NoteColumns.value = value end
        }
      },
      vb:row {
        vb:text {text = "Visible Effect Columns:", width = 150},
        vb:switch {
          id = "effect_columns_switch",
          width = 300,
          value = preferences.pakettiPhraseInitDialog.EffectColumns.value + 1,
          items = {"0","1","2","3","4","5","6","7","8"},
          notifier = function(value) preferences.pakettiPhraseInitDialog.EffectColumns.value = value - 1 end
        }
      },
      vb:row {
        vb:text {text = "Shuffle:", width = 150},
        vb:slider {
          id = "shuffle_slider",
          width = 100,
          min = 0,
          max = 100,
          value = preferences.pakettiPhraseInitDialog.Shuffle.value,
          notifier = function(value)
            preferences.pakettiPhraseInitDialog.Shuffle.value = math.floor(value)
            vb.views["shuffle_value"].text = tostring(preferences.pakettiPhraseInitDialog.Shuffle.value) .. "%"
          end
        },
        vb:text {id = "shuffle_value", text = tostring(preferences.pakettiPhraseInitDialog.Shuffle.value) .. "%", width = 50}
      },
      vb:row {
        vb:text {text = "LPB:", width = 150},
        vb:valuebox {
          id = "lpb_valuebox",
          min = 1,
          max = 256,
          value = preferences.pakettiPhraseInitDialog.LPB.value,
          width = 100,
          notifier = function(value) preferences.pakettiPhraseInitDialog.LPB.value = value end
        }
      },
      vb:row {
        vb:text {text = "Length:", width = 150},
        vb:valuebox {
          id = "length_valuebox",
          min = 1,
          max = 512,
          value = preferences.pakettiPhraseInitDialog.Length.value,
          width = 100,
          notifier = function(value) preferences.pakettiPhraseInitDialog.Length.value = value end
        },
        vb:button {text = "2", notifier = function() vb.views.length_valuebox.value = 2 preferences.pakettiPhraseInitDialog.Length.value = 2 end},
        vb:button {text = "4", notifier = function() vb.views.length_valuebox.value = 4 preferences.pakettiPhraseInitDialog.Length.value = 4 end},
        vb:button {text = "6", notifier = function() vb.views.length_valuebox.value = 6 preferences.pakettiPhraseInitDialog.Length.value = 6 end},
        vb:button {text = "8", notifier = function() vb.views.length_valuebox.value = 8 preferences.pakettiPhraseInitDialog.Length.value = 8 end},
        vb:button {text = "12", notifier = function() vb.views.length_valuebox.value = 12 preferences.pakettiPhraseInitDialog.Length.value = 12 end},
        vb:button {text = "16", notifier = function() vb.views.length_valuebox.value = 16 preferences.pakettiPhraseInitDialog.Length.value = 16 end},
        vb:button {text = "24", notifier = function() vb.views.length_valuebox.value = 24 preferences.pakettiPhraseInitDialog.Length.value = 24 end},
        vb:button {text = "32", notifier = function() vb.views.length_valuebox.value = 32 preferences.pakettiPhraseInitDialog.Length.value = 32 end},
        vb:button {text = "48", notifier = function() vb.views.length_valuebox.value = 48 preferences.pakettiPhraseInitDialog.Length.value = 48 end},
        vb:button {text = "64", notifier = function() vb.views.length_valuebox.value = 64 preferences.pakettiPhraseInitDialog.Length.value = 64 end},
        vb:button {text = "96", notifier = function() vb.views.length_valuebox.value = 96 preferences.pakettiPhraseInitDialog.Length.value = 96 end},
        vb:button {text = "128", notifier = function() vb.views.length_valuebox.value = 128 preferences.pakettiPhraseInitDialog.Length.value = 128 end},
        vb:button {text = "192", notifier = function() vb.views.length_valuebox.value = 192 preferences.pakettiPhraseInitDialog.Length.value = 192 end},
        vb:button {text = "256", notifier = function() vb.views.length_valuebox.value = 256 preferences.pakettiPhraseInitDialog.Length.value = 256 end},
        vb:button {text = "384", notifier = function() vb.views.length_valuebox.value = 384 preferences.pakettiPhraseInitDialog.Length.value = 384 end},
        vb:button {text = "512", notifier = function() vb.views.length_valuebox.value = 512 preferences.pakettiPhraseInitDialog.Length.value = 512 end}
      },
      vb:row {
        vb:button {text = "Create New Phrase", width = 100, notifier = function()
          pakettiInitPhraseSettingsCreateNewPhrase()
        end},
        vb:button {text = "Modify Phrase", width = 100, notifier = function()
          pakettiPhraseSettingsModifyCurrentPhrase()
        end},
        vb:button {text = "Save", width = 100, notifier = function()
          savePreferences()
        end},
        vb:button {text = "Cancel", width = 100, notifier = function()
          pakettiInitPhraseSettingsDialog:close()
          pakettiInitPhraseSettingsDialog = nil
        end}
      }
    }, pakettiPhraseSettingsKeyHandler
  )
end

renoise.tool():add_keybinding {name = "Global:Paketti:Open Paketti Init Phrase Dialog...", invoke = function() pakettiPhraseSettingsDialogShow() end}
renoise.tool():add_keybinding {name = "Phrase Editor:Paketti:Open Paketti Init Phrase Dialog...", invoke = function() pakettiPhraseSettingsDialogShow() end}

renoise.tool():add_menu_entry {name = "Phrase Editor:Paketti..:Open Paketti Init Phrase Dialog...", invoke = function() pakettiPhraseSettingsDialogShow() end}
renoise.tool():add_menu_entry {name = "Main Menu:Tools:Paketti..:!Preferences..:Open Paketti Init Phrase Dialog...", invoke = function() pakettiPhraseSettingsDialogShow() end}

renoise.tool():add_keybinding {name = "Global:Paketti:Create New Phrase using Paketti Settings", invoke = function() pakettiInitPhraseSettingsCreateNewPhrase() end}
renoise.tool():add_menu_entry {name = "Phrase Editor:Paketti..:Create New Phrase using Paketti Settings", invoke = function() pakettiInitPhraseSettingsCreateNewPhrase() end}
renoise.tool():add_midi_mapping {name = "Paketti:Create New Phrase Using Paketti Settings", invoke = function() pakettiInitPhraseSettingsCreateNewPhrase() end}

renoise.tool():add_keybinding {name = "Global:Paketti:Modify Current Phrase using Paketti Settings", invoke = function() pakettiPhraseSettingsModifyCurrentPhrase() end}
renoise.tool():add_menu_entry {name = "Phrase Editor:Paketti..:Modify Current Phrase using Paketti Settings", invoke = function() pakettiPhraseSettingsModifyCurrentPhrase() end}
renoise.tool():add_midi_mapping {name = "Paketti:Modify Current Phrase Using Paketti Settings", invoke = function() pakettiPhraseSettingsModifyCurrentPhrase() end}



------------------------------------------------




function RecordFollowOffPhrase()
local t=renoise.song().transport
t.follow_player=false
if t.edit_mode == false then 
t.edit_mode=true else
t.edit_mode=false end end

renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Record+Follow Off",invoke=function() RecordFollowOffPhrase() end}


function createPhrase()
local s=renoise.song() 


  renoise.app().window.active_middle_frame=3
  s.instruments[s.selected_instrument_index]:insert_phrase_at(1) 
  s.instruments[s.selected_instrument_index].phrase_editor_visible=true
  s.selected_phrase_index=1

local selphra=renoise.song().instruments[renoise.song().selected_instrument_index].phrases[renoise.song().selected_phrase_index]
  
selphra.shuffle=preferences.pakettiPhraseInitDialog.Shuffle.value / 100
selphra.visible_note_columns=preferences.pakettiPhraseInitDialog.NoteColumns.value
selphra.visible_effect_columns=preferences.pakettiPhraseInitDialog.EffectColumns.value
selphra.volume_column_visible=preferences.pakettiPhraseInitDialog.VolumeColumnVisible.value
selphra.panning_column_visible=preferences.pakettiPhraseInitDialog.PanningColumnVisible.value
selphra.delay_column_visible=preferences.pakettiPhraseInitDialog.DelayColumnVisible.value
selphra.sample_effects_column_visible=preferences.pakettiPhraseInitDialog.SampleFXColumnVisible.value
selphra.instrument_column_visible=preferences.pakettiPhraseInitDialog.InstrumentColumnVisible.value
selphra.autoseek=preferences.pakettiPhraseInitDialog.Autoseek.value
selphra.lpb=preferences.pakettiPhraseInitDialog.LPB.value
selphra.number_of_lines=preferences.pakettiPhraseInitDialog.Length.value
end

renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:Create Paketti Phrase",invoke=function() createPhrase() end}
--renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:Create Paketti Phrase",invoke=function() createPhrase() end}

--------
function phraseEditorVisible()
  local s=renoise.song()
--If no Phrase in instrument, create phrase, otherwise do nothing.
if s.instruments[s.selected_instrument_index]:can_insert_phrase_at(1) == true then
s.instruments[s.selected_instrument_index]:insert_phrase_at(1) end

--Select created phrase.
s.selected_phrase_index=1

--Check to make sure the Phrase Editor is Visible
if not s.instruments[s.selected_instrument_index].phrase_editor_visible then
renoise.app().window.active_middle_frame =3
s.instruments[s.selected_instrument_index].phrase_editor_visible=true
--If Phrase Editor is already visible, go back to pattern editor.
else s.instruments[s.selected_instrument_index].phrase_editor_visible=false 
renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end end

renoise.tool():add_keybinding{name="Global:Paketti:Phrase Editor Visible",invoke=function() phraseEditorVisible() end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Phrase Editor Visible",invoke=function() phraseEditorVisible() end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Phrase Editor Visible",invoke=function() phraseEditorVisible() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Phrase Editor Visible",invoke=function() phraseEditorVisible() end}

function phraseadd()
renoise.song().instruments[renoise.song().selected_instrument_index]:insert_phrase_at(1)
end

renoise.tool():add_keybinding{name="Global:Paketti:Add New Phrase",invoke=function()  phraseadd() end}

----
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Init Phrase Settings",invoke=function()
if renoise.song().selected_phrase == nil then
renoise.song().instruments[renoise.song().selected_instrument_index]:insert_phrase_at(1)
renoise.song().selected_phrase_index = 1
end

local selphra=renoise.song().selected_phrase
selphra.shuffle=preferences.pakettiPhraseInitDialog.Shuffle.value / 100
selphra.visible_note_columns=preferences.pakettiPhraseInitDialog.NoteColumns.value
selphra.visible_effect_columns=preferences.pakettiPhraseInitDialog.EffectColumns.value
selphra.volume_column_visible=preferences.pakettiPhraseInitDialog.VolumeColumnVisible.value
selphra.panning_column_visible=preferences.pakettiPhraseInitDialog.PanningColumnVisible.value
selphra.delay_column_visible=preferences.pakettiPhraseInitDialog.DelayColumnVisible.value
selphra.sample_effects_column_visible=preferences.pakettiPhraseInitDialog.SampleFXColumnVisible.value
selphra.instrument_column_visible=preferences.pakettiPhraseInitDialog.InstrumentColumnVisible.value
selphra.autoseek=preferences.pakettiPhraseInitDialog.Autoseek.value
selphra.lpb=preferences.pakettiPhraseInitDialog.LPB.value
selphra.number_of_lines=preferences.pakettiPhraseInitDialog.Length.value

local renamephrase_to_index=tostring(renoise.song().selected_phrase_index)
selphra.name=renamephrase_to_index
--selphra.name=renoise.song().selected_phrase_index
end}

function joulephrasedoubler()
  local old_phraselength = renoise.song().selected_phrase.number_of_lines
  local s=renoise.song()
  local resultlength = nil
--Note, when doubling up a 512 pattern, this will shoot a "can't change number_of_lines to 1024" error. fix.
--Note: tried to fix, still shoots 1024 error in Terminal.
  resultlength = old_phraselength*2
if resultlength > 512 then return else s.selected_phrase.number_of_lines=resultlength

if old_phraselength >256 then return else 
for line_index, line in ipairs(s.selected_phrase.lines) do
   if not line.is_empty then
     if line_index <= old_phraselength then
       s.selected_phrase:line(line_index+old_phraselength):copy_from(line)
     end
   end
 end
end
--Modification, cursor is placed to "start of "clone""
--commented away because there is no way to set current_phrase_index.
  -- renoise.song().selected_line_index = old_patternlength+1
  -- renoise.song().selected_line_index = old_phraselength+renoise.song().selected_line_index
  -- renoise.song().transport.edit_step=0
end
end

renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Paketti Phrase Doubler",invoke=function() joulephrasedoubler() end}  
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Paketti Phrase Doubler (2nd)",invoke=function() joulepatterndoubler() end}    
-------
function joulephrasehalver()
  local old_phraselength = renoise.song().selected_phrase.number_of_lines
  local s=renoise.song()
  local resultlength = nil
--Note, when doubling up a 512 pattern, this will shoot a "can't change number_of_lines to 1024" error. fix.
--Note: tried to fix, still shoots 1024 error in Terminal.
  resultlength = old_phraselength/2
if resultlength > 512 or resultlength < 1 then return else s.selected_phrase.number_of_lines=resultlength

if old_phraselength >256 then return else 
for line_index, line in ipairs(s.selected_phrase.lines) do
   if not line.is_empty then
     if line_index <= old_phraselength then
       s.selected_phrase:line(line_index+old_phraselength):copy_from(line)
     end
   end
 end
end

--Modification, cursor is placed to "start of "clone""
--commented away because there is no way to set current_phrase_index.
  -- renoise.song().selected_line_index = old_patternlength+1
  -- renoise.song().selected_line_index = old_phraselength+renoise.song().selected_line_index
  -- renoise.song().transport.edit_step=0
end
end

renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Phrase Halver (Joule)",invoke=function() joulephrasehalver() end}  
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Phrase Halver (Joule) (2nd)",invoke=function() joulephrasehalver() end}  

