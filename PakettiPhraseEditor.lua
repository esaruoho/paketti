-- Ensure the dialog is initialized
local dialog = nil

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



-- Function to show the PakettiInitPhraseSettingsDialog
function pakettiPhraseSettings()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local phrase = renoise.song().selected_phrase
  if phrase then
    preferences.pakettiPhraseInitDialog.Name.value = phrase.name
  end

  dialog = renoise.app():show_custom_dialog("Paketti Phrase Default Settings Dialog",
    vb:column{
      margin=10,
      
      vb:row{
        vb:checkbox{
          id = "set_name_checkbox",
          value = preferences.pakettiPhraseInitDialog.SetName.value,
          notifier=function(value)
            preferences.pakettiPhraseInitDialog.SetName.value = value
          end
        },
        vb:text{text="Set Name",width=150},
      },
      vb:row{
        vb:text{text="Phrase Name",width=150},
        vb:textfield {
          id = "phrase_name_textfield",
          width=300,
          text = preferences.pakettiPhraseInitDialog.Name.value,
          notifier=function(value) 
            preferences.pakettiPhraseInitDialog.Name.value = value
            -- Auto-check the Set Name checkbox when text is entered
            if value ~= "" then
              preferences.pakettiPhraseInitDialog.SetName.value = true
              vb.views.set_name_checkbox.value = true
            end
          end
        }
      },
      vb:row{
        vb:text{text="Autoseek",width=150},
        vb:switch {
          id = "autoseek_switch",
          width=300,
          items = {"Off", "On"},
          value = preferences.pakettiPhraseInitDialog.Autoseek.value and 2 or 1,
          notifier=function(value) preferences.pakettiPhraseInitDialog.Autoseek.value = (value == 2) end
        }
      },
      vb:row{
        vb:text{text="Volume Column Visible",width=150},
        vb:switch {
          id = "volume_column_visible_switch",
          width=300,
          items = {"Off", "On"},
          value = preferences.pakettiPhraseInitDialog.VolumeColumnVisible.value and 2 or 1,
          notifier=function(value) preferences.pakettiPhraseInitDialog.VolumeColumnVisible.value = (value == 2) end
        }
      },
      vb:row{
        vb:text{text="Panning Column Visible",width=150},
        vb:switch {
          id = "panning_column_visible_switch",
          width=300,
          items = {"Off", "On"},
          value = preferences.pakettiPhraseInitDialog.PanningColumnVisible.value and 2 or 1,
          notifier=function(value) preferences.pakettiPhraseInitDialog.PanningColumnVisible.value = (value == 2) end
        }
      },
      vb:row{
        vb:text{text="Instrument Column Visible",width=150},
        vb:switch {
          id = "instrument_column_visible_switch",
          width=300,
          items = {"Off", "On"},
          value = preferences.pakettiPhraseInitDialog.InstrumentColumnVisible.value and 2 or 1,
          notifier=function(value) preferences.pakettiPhraseInitDialog.InstrumentColumnVisible.value = (value == 2) end
        }
      },
      vb:row{
        vb:text{text="Delay Column Visible",width=150},
        vb:switch {
          id = "delay_column_visible_switch",
          width=300,
          items = {"Off", "On"},
          value = preferences.pakettiPhraseInitDialog.DelayColumnVisible.value and 2 or 1,
          notifier=function(value) preferences.pakettiPhraseInitDialog.DelayColumnVisible.value = (value == 2) end
        }
      },
      vb:row{
        vb:text{text="Sample FX Column Visible",width=150},
        vb:switch {
          id = "samplefx_column_visible_switch",
          width=300,
          items = {"Off", "On"},
          value = preferences.pakettiPhraseInitDialog.SampleFXColumnVisible.value and 2 or 1,
          notifier=function(value) preferences.pakettiPhraseInitDialog.SampleFXColumnVisible.value = (value == 2) end
        }
      },     
      vb:row{
        vb:text{text="Phrase Looping",width=150},
        vb:switch {
          id = "phrase_looping_switch",
          width=300,
          items = {"Off", "On"},
          value = preferences.pakettiPhraseInitDialog.PhraseLooping.value and 2 or 1,
          notifier=function(value) preferences.pakettiPhraseInitDialog.PhraseLooping.value = (value == 2) end
        }
      },     

      

      vb:row{
        vb:text{text="Visible Note Columns",width=150},
        vb:switch {
          id = "note_columns_switch",
          width=300,
          value = preferences.pakettiPhraseInitDialog.NoteColumns.value,
          items = {"1","2","3","4","5","6","7","8","9","10","11","12"},
          notifier=function(value) preferences.pakettiPhraseInitDialog.NoteColumns.value = value end
        }
      },
      vb:row{
        vb:text{text="Visible Effect Columns",width=150},
        vb:switch {
          id = "effect_columns_switch",
          width=300,
          value = preferences.pakettiPhraseInitDialog.EffectColumns.value + 1,
          items = {"0","1","2","3","4","5","6","7","8"},
          notifier=function(value) preferences.pakettiPhraseInitDialog.EffectColumns.value = value - 1 end
        }
      },
      vb:row{
        vb:text{text="Shuffle",width=150},
        vb:slider{
          id = "shuffle_slider",
          width=100,
          min = 0,
          max = 50,
          value = preferences.pakettiPhraseInitDialog.Shuffle.value,
          notifier=function(value)
            preferences.pakettiPhraseInitDialog.Shuffle.value = math.floor(value)
            vb.views["shuffle_value"].text = tostring(preferences.pakettiPhraseInitDialog.Shuffle.value) .. "%"
          end
        },
        vb:text{id = "shuffle_value", text = tostring(preferences.pakettiPhraseInitDialog.Shuffle.value) .. "%",width=50}
      },
      vb:row{
        vb:text{text="LPB",width=150},
        vb:valuebox{
          id = "lpb_valuebox",
          min = 1,
          max = 256,
          value = preferences.pakettiPhraseInitDialog.LPB.value,
          width=60,
          notifier=function(value) preferences.pakettiPhraseInitDialog.LPB.value = value end
        }
      },
      vb:row{
        vb:text{text="Length",width=150},
        vb:valuebox{
          id = "length_valuebox",
          min = 1,
          max = 512,
          value = preferences.pakettiPhraseInitDialog.Length.value,
          width=60,
          notifier=function(value) preferences.pakettiPhraseInitDialog.Length.value = value end
        },
        vb:button{text="2", notifier=function() vb.views.length_valuebox.value = 2 preferences.pakettiPhraseInitDialog.Length.value = 2 end},
        vb:button{text="4", notifier=function() vb.views.length_valuebox.value = 4 preferences.pakettiPhraseInitDialog.Length.value = 4 end},
        vb:button{text="6", notifier=function() vb.views.length_valuebox.value = 6 preferences.pakettiPhraseInitDialog.Length.value = 6 end},
        vb:button{text="8", notifier=function() vb.views.length_valuebox.value = 8 preferences.pakettiPhraseInitDialog.Length.value = 8 end},
        vb:button{text="12", notifier=function() vb.views.length_valuebox.value = 12 preferences.pakettiPhraseInitDialog.Length.value = 12 end},
        vb:button{text="16", notifier=function() vb.views.length_valuebox.value = 16 preferences.pakettiPhraseInitDialog.Length.value = 16 end},
        vb:button{text="24", notifier=function() vb.views.length_valuebox.value = 24 preferences.pakettiPhraseInitDialog.Length.value = 24 end},
        vb:button{text="32", notifier=function() vb.views.length_valuebox.value = 32 preferences.pakettiPhraseInitDialog.Length.value = 32 end},
        vb:button{text="48", notifier=function() vb.views.length_valuebox.value = 48 preferences.pakettiPhraseInitDialog.Length.value = 48 end},
        vb:button{text="64", notifier=function() vb.views.length_valuebox.value = 64 preferences.pakettiPhraseInitDialog.Length.value = 64 end},
        vb:button{text="96", notifier=function() vb.views.length_valuebox.value = 96 preferences.pakettiPhraseInitDialog.Length.value = 96 end},
        vb:button{text="128", notifier=function() vb.views.length_valuebox.value = 128 preferences.pakettiPhraseInitDialog.Length.value = 128 end},
        vb:button{text="192", notifier=function() vb.views.length_valuebox.value = 192 preferences.pakettiPhraseInitDialog.Length.value = 192 end},
        vb:button{text="256", notifier=function() vb.views.length_valuebox.value = 256 preferences.pakettiPhraseInitDialog.Length.value = 256 end},
        vb:button{text="384", notifier=function() vb.views.length_valuebox.value = 384 preferences.pakettiPhraseInitDialog.Length.value = 384 end},
        vb:button{text="512", notifier=function() vb.views.length_valuebox.value = 512 preferences.pakettiPhraseInitDialog.Length.value = 512 end}
      },
      vb:row{
        vb:button{text="Create New Phrase",width=100, notifier=function()
          pakettiInitPhraseSettingsCreateNewPhrase()
        end},
        vb:button{text="Modify Phrase",width=100, notifier=function()
          pakettiPhraseSettingsModifyCurrentPhrase()
        end},
        vb:button{text="Save",width=100, notifier=function()
          savePreferences()
        end},
        vb:button{text="Cancel",width=100, notifier=function()
          dialog:close()
          dialog = nil
        end}}},
    create_keyhandler_for_dialog(
      function() return dialog end,
      function(value) dialog = value end
    ))
end

renoise.tool():add_keybinding{name="Global:Paketti:Open Paketti Init Phrase Dialog...",invoke=function() pakettiPhraseSettings() end}
renoise.tool():add_keybinding{name="Global:Paketti:Create New Phrase using Paketti Settings",invoke=function() pakettiInitPhraseSettingsCreateNewPhrase() end}
renoise.tool():add_keybinding{name="Global:Paketti:Modify Current Phrase using Paketti Settings",invoke=function() pakettiPhraseSettingsModifyCurrentPhrase() end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Open Paketti Init Phrase Dialog...",invoke=function() pakettiPhraseSettings() end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Create New Phrase using Paketti Settings",invoke=function() pakettiInitPhraseSettingsCreateNewPhrase() end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Modify Current Phrase using Paketti Settings",invoke=function() pakettiPhraseSettingsModifyCurrentPhrase() end}
renoise.tool():add_midi_mapping{name="Paketti:Open Paketti Init Phrase Dialog...",invoke=function(message) if message:is_trigger() then pakettiPhraseSettings() end end}
renoise.tool():add_midi_mapping{name="Paketti:Create New Phrase Using Paketti Settings",invoke=function(message) if message:is_trigger() then pakettiInitPhraseSettingsCreateNewPhrase() end end}
renoise.tool():add_midi_mapping{name="Paketti:Modify Current Phrase Using Paketti Settings",invoke=function(message) if message:is_trigger() then pakettiPhraseSettingsModifyCurrentPhrase() end end}
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
selphra.looping=preferences.pakettiPhraseInitDialog.PhraseLooping.value
selphra.instrument_column_visible=preferences.pakettiPhraseInitDialog.InstrumentColumnVisible.value
selphra.autoseek=preferences.pakettiPhraseInitDialog.Autoseek.value
selphra.lpb=preferences.pakettiPhraseInitDialog.LPB.value
selphra.number_of_lines=preferences.pakettiPhraseInitDialog.Length.value
end


--renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Create Paketti Phrase",invoke=function() createPhrase() end}

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
selphra.looping=preferences.pakettiPhraseInitDialog.PhraseLooping.value
selphra.autoseek=preferences.pakettiPhraseInitDialog.Autoseek.value
selphra.lpb=preferences.pakettiPhraseInitDialog.LPB.value
selphra.number_of_lines=preferences.pakettiPhraseInitDialog.Length.value
selphra.looping=preferences.pakettiPhraseInitDialog.PhraseLooping.value

local renamephrase_to_index=tostring(renoise.song().selected_phrase_index)
selphra.name=renamephrase_to_index
--selphra.name=renoise.song().selected_phrase_index
end}

function joulephrasedoubler()
  local old_phraselength = renoise.song().selected_phrase.number_of_lines
  local s=renoise.song()
  local resultlength = nil

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

----------
local last_pattern_pos = 1  -- Start at 1, not 0
local current_section = 0

local function phrase_follow_notifier()
  if renoise.song().transport.playing then
    local song=renoise.song()
    local pattern_pos = song.selected_line_index  -- This is already 1-based from Renoise
    local pattern_length = song.selected_pattern.number_of_lines
    local phrase_length = song.selected_phrase.number_of_lines
    
    -- Detect wrap from end to start of pattern
    if pattern_pos < last_pattern_pos then
      current_section = (current_section + 1) % math.ceil(phrase_length / pattern_length)
    end
    
    -- Calculate phrase position based on current section (keeping 1-based indexing)
    local phrase_pos = pattern_pos + (current_section * pattern_length)
    
    -- Handle wrap-around if we exceed phrase length
    if phrase_pos > phrase_length then  -- Changed from >= to > since we're 1-based
      phrase_pos = 1  -- Reset to 1, not 0
      current_section = 0
    end
    
    print(string.format("Pattern pos: %d/%d, Section: %d, Phrase pos: %d/%d", 
          pattern_pos, pattern_length, current_section, phrase_pos, phrase_length))
          
    song.selected_phrase_line_index = phrase_pos
    last_pattern_pos = pattern_pos
  end
end


-- Function to explicitly enable phrase follow
function enable_phrase_follow()
  local s = renoise.song()
  local w = renoise.app().window

  -- Check API version first
  if renoise.API_VERSION < 6.2 then
    renoise.app():show_error("Phrase Editor observation requires API version 6.2 or higher!")
    return
  end

  -- Enable follow player and set editstep to 0
  s.transport.follow_player = true
  s.transport.edit_step = 0
  
  -- Force phrase editor view
  w.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
  
  -- Set up monitoring if not already active
  if not renoise.tool().app_idle_observable:has_notifier(phrase_follow_notifier) then
    renoise.tool().app_idle_observable:add_notifier(phrase_follow_notifier)
  end
  
  -- Reset cycle when enabling
  current_cycle = 0
  
  phrase_follow_enabled = true
  renoise.app():show_status("Phrase Follow Pattern Playback: ON")
end

-- Function to explicitly disable phrase follow
function disable_phrase_follow()
  -- Remove monitoring if active
  if renoise.tool().app_idle_observable:has_notifier(phrase_follow_notifier) then
    renoise.tool().app_idle_observable:remove_notifier(phrase_follow_notifier)
  end
  
  phrase_follow_enabled = false
  current_cycle = 0  -- Reset cycle when disabling
  renoise.app():show_status("Phrase Follow Pattern Playback: OFF")
end

function observe_phrase_playhead()
  local s = renoise.song()
  local w = renoise.app().window

  -- Check API version first
  if renoise.API_VERSION < 6.2 then
    renoise.app():show_error("Phrase Editor observation requires API version 6.2 or higher!")
    return
  end

  -- Toggle state
  phrase_follow_enabled = not phrase_follow_enabled
  
  if phrase_follow_enabled then
    -- Enable follow player and set editstep to 0
    s.transport.follow_player = true
    s.transport.edit_step = 0
    
    -- Force phrase editor view
    w.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
    
    -- Set up monitoring
    if not renoise.tool().app_idle_observable:has_notifier(phrase_follow_notifier) then
      renoise.tool().app_idle_observable:add_notifier(phrase_follow_notifier)
    end
    -- Reset cycle when enabling
    current_cycle = 0
    renoise.app():show_status("Phrase Follow Pattern Playback: ON")
  else
    -- Remove monitoring
    if renoise.tool().app_idle_observable:has_notifier(phrase_follow_notifier) then
      renoise.tool().app_idle_observable:remove_notifier(phrase_follow_notifier)
    end
    current_cycle = 0  -- Reset cycle when disabling
    renoise.app():show_status("Phrase Follow Pattern Playback: OFF")
  end
end

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Phrase Editor:Phrase Follow Pattern Playback Hack",invoke=observe_phrase_playhead}
renoise.tool():add_menu_entry{name="--Phrase Editor:Paketti:Phrase Follow Pattern Playback Hack",invoke=observe_phrase_playhead}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Toggle Phrase Follow Pattern Playback Hack",invoke=observe_phrase_playhead}
renoise.tool():add_keybinding{name="Global:Paketti:Toggle Phrase Follow Pattern Playback Hack",invoke=observe_phrase_playhead}
---
function Phrplusdelay(chg)
  local song=renoise.song()
  local nc = song.selected_note_column

  -- Check if a note column is selected
  if not nc then
    local message = "No note column is selected!"
    renoise.app():show_status(message)
    print(message)
    return
  end

  local currTrak = song.selected_track_index
  local currInst = song.selected_instrument_index
  local currPhra = song.selected_phrase_index
  local sli = song.selected_phrase_line_index
  local snci = song.selected_phrase_note_column_index

  -- Check if a phrase is selected
  if currPhra == 0 then
    local message = "No phrase is selected!"
    renoise.app():show_status(message)
    print(message)
    return
  end

  -- Ensure delay columns are visible in both track and phrase
  song.instruments[currInst].phrases[currPhra].delay_column_visible = true
  song.tracks[currTrak].delay_column_visible = true

  -- Get current delay value from the selected note column in the phrase
  local phrase = song.instruments[currInst].phrases[currPhra]
  local line = phrase:line(sli)
  local note_column = line:note_column(snci)
  local Phrad = note_column.delay_value

  -- Adjust delay value, ensuring it stays within 0-255 range
  note_column.delay_value = math.max(0, math.min(255, Phrad + chg))

  -- Show and print status message
  local message = "Delay value adjusted by " .. chg .. " at line " .. sli .. ", column " .. snci
  renoise.app():show_status(message)
  print(message)

  -- Show and print visible note columns and effect columns
  local visible_note_columns = phrase.visible_note_columns
  local visible_effect_columns = phrase.visible_effect_columns
  local columns_message = string.format("Visible Note Columns: %d, Visible Effect Columns: %d", visible_note_columns, visible_effect_columns)
  renoise.app():show_status(columns_message)
  print(columns_message)
end

renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Increase Delay +1",invoke=function() Phrplusdelay(1) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Decrease Delay -1",invoke=function() Phrplusdelay(-1) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Increase Delay +10",invoke=function() Phrplusdelay(10) end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Decrease Delay -10",invoke=function() Phrplusdelay(-10) end}
---------------------------------------------------------------------------------------------------------