-- Ensure the dialog is initialized
local dialog = nil

-- Phrase follow variables
-- Initialize from preferences, defaulting to false if not set
local phrase_follow_enabled = false
if preferences and preferences.PakettiPhraseFollowPatternPlayback then
  phrase_follow_enabled = preferences.PakettiPhraseFollowPatternPlayback.value
end
local current_cycle = 0  -- Track current cycle for phrase follow

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
  phrase.looping = preferences.pakettiPhraseInitDialog.PhraseLooping.value
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
if #s.instruments[s.selected_instrument_index].phrases == 0 then
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
  
  -- Save preference
  if preferences and preferences.PakettiPhraseFollowPatternPlayback then
    preferences.PakettiPhraseFollowPatternPlayback.value = phrase_follow_enabled
    preferences:save_as("preferences.xml")
  end
  
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

-- Toggle function for Main Menu Options (with checkbox state persistence)
function PakettiTogglePhraseFollowPatternPlayback()
  observe_phrase_playhead()
end

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Phrases:Phrase Follow Pattern Playback Hack",invoke=observe_phrase_playhead}
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

----
-- Helper function for phrase line operations (replicate version)
function cpclex_phrase_line_replicate(from_line, to_line)
  local s = renoise.song()
  local phrase = s.selected_phrase
  if not phrase then
    renoise.app():show_status("No phrase selected.")
    return
  end
  phrase:line(to_line):copy_from(phrase:line(from_line))
  phrase:line(from_line):clear()
  if to_line + 1 <= phrase.number_of_lines then
    phrase:line(to_line + 1):clear()
  end
end

function cpclsh_phrase_line_replicate(from_line, to_line)
  local s = renoise.song()
  local phrase = s.selected_phrase
  if not phrase then
    renoise.app():show_status("No phrase selected.")
    return
  end
  phrase:line(to_line):copy_from(phrase:line(from_line))
  phrase:line(from_line):clear()
  if from_line + 1 <= phrase.number_of_lines then
    phrase:line(from_line + 1):clear()
  end
end

-- Phrase version of floodfill with selection
function floodfill_phrase_with_selection()
  local s = renoise.song()
  local phrase = s.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected.")
    return
  end
  
  if s.selection_in_phrase == nil then
    renoise.app():show_status("Nothing selected to fill phrase with.")
    return
  end
  
  local sl = s.selection_in_phrase.start_line
  local el = s.selection_in_phrase.end_line
  local sc = s.selection_in_phrase.start_column
  local ec = s.selection_in_phrase.end_column
  local nl = phrase.number_of_lines
  
  local selection_length = el - sl + 1
  local current_line = el + 1
  
  -- Fill the rest of the phrase with the selection pattern
  while current_line <= nl do
    local remaining_lines = nl - current_line + 1
    local lines_to_copy = math.min(selection_length, remaining_lines)
    
    for i = 1, lines_to_copy do
      local source_line = sl + (i - 1)
      local target_line = current_line + (i - 1)
      
      if target_line <= nl then
        phrase:line(target_line):copy_from(phrase:line(source_line))
      end
    end
    
    current_line = current_line + lines_to_copy
  end
end

function ExpandSelectionReplicatePhrase()
  local s = renoise.song()
  local phrase = s.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected.")
    return
  end
  
  if s.selection_in_phrase == nil then
    renoise.app():show_status("Nothing selected to Expand in phrase.")
    return
  end
  
  local sl = s.selection_in_phrase.start_line
  local el = s.selection_in_phrase.end_line
  local sc = s.selection_in_phrase.start_column
  local ec = s.selection_in_phrase.end_column
  local nl = phrase.number_of_lines
  
  -- Calculate the original and new selection lengths
  local original_length = el - sl + 1
  local new_end_line = el * 2
  if new_end_line > nl then
    new_end_line = nl
  end
  
  -- First pass: Expand the selection
  for l = el, sl, -1 do
    if l ~= sl then
      local new_line = (l * 2) - sl
      if new_line <= nl then
        cpclex_phrase_line_replicate(l, new_line)
      end
    end
  end
  
  -- Update selection to include expanded area
  s.selection_in_phrase = {
    start_line = sl,
    end_line = new_end_line,
    start_column = sc,
    end_column = ec
  }
  
  -- Fill the rest of the phrase
  floodfill_phrase_with_selection()
  
  renoise.app():show_status(string.format("Expanded and replicated selection in phrase from line %d to %d", sl, nl))
end

function ShrinkSelectionReplicatePhrase()
  local s = renoise.song()
  local phrase = s.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected.")
    return
  end
  
  if s.selection_in_phrase == nil then
    renoise.app():show_status("Nothing selected to Shrink in phrase.")
    return
  end
  
  local sl = s.selection_in_phrase.start_line
  local el = s.selection_in_phrase.end_line
  local sc = s.selection_in_phrase.start_column
  local ec = s.selection_in_phrase.end_column
  local nl = phrase.number_of_lines
  
  for l = sl, el, 2 do
    if l ~= sl then
      -- Calculate new_line as an integer
      local new_line = math.floor(l / 2 + sl / 2)
      
      -- Ensure new_line is within valid range
      if new_line >= 1 and new_line <= nl then
        cpclsh_phrase_line_replicate(l, new_line)
      end
    end
  end
  
  -- Update selection to include shrunken area
  local new_end_line = math.min(math.floor((el - sl) / 2) + sl, nl)
  s.selection_in_phrase = {
    start_line = sl,
    end_line = new_end_line,
    start_column = sc,
    end_column = ec
  }
  
  -- Fill the rest of the phrase
  floodfill_phrase_with_selection()
  
  renoise.app():show_status(string.format("Shrank and replicated selection in phrase from line %d to %d", sl, nl))
end

-- Keybindings for Phrase Editor Replicate versions (API 6.2+)
if renoise.API_VERSION >= 6.2 then
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker ALT-F Expand Selection Replicate",invoke=function() ExpandSelectionReplicatePhrase() end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker ALT-G Shrink Selection Replicate",invoke=function() ShrinkSelectionReplicatePhrase() end}
end

-- Initialize phrase follow at startup if preference is enabled
if renoise.API_VERSION >= 6.2 and phrase_follow_enabled then
  enable_phrase_follow()
end

---------------------------------------------------------------------------------------------------------
-- Auto-fill pattern with phrases based on phrase length
function PakettiFloodFillPatternWithPhrase()
  local song = renoise.song()
  
  -- Get current pattern and its length
  local pattern = song.selected_pattern
  local pattern_length = pattern.number_of_lines
  
  -- Get current instrument index
  local instrument_index = song.selected_instrument_index
  local instrument = song.instruments[instrument_index]
  
  -- Check if instrument has phrases
  if #instrument.phrases == 0 then
    renoise.app():show_status("No phrases in selected instrument")
    return
  end
  
  -- Check if a phrase is selected
  local phrase_index = song.selected_phrase_index
  if phrase_index == 0 then
    renoise.app():show_status("No phrase selected")
    return
  end
  
  -- Get the selected phrase and its length
  local phrase = instrument.phrases[phrase_index]
  local phrase_length = phrase.number_of_lines
  
  -- Get current track
  local track_index = song.selected_track_index
  local track = song.tracks[track_index]
  
  -- Check if track is a sequencer track (not master, send, or group)
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Current track is not a sequencer track")
    return
  end
  
  -- Get pattern track
  local pattern_track = pattern:track(track_index)
  
  -- Calculate how many times to trigger the phrase
  local trigger_count = math.floor(pattern_length / phrase_length)
  
  -- Clear the pattern track first (optional, but clean)
  -- Commented out to preserve existing data if user wants to layer
  -- for i = 1, pattern_length do
  --   pattern_track:line(i):clear()
  -- end
  
  -- Trigger phrase at intervals equal to phrase length
  local note_column_index = song.selected_note_column_index
  if note_column_index == 0 or note_column_index > track.visible_note_columns then
    note_column_index = 1
  end
  
  local triggers_added = 0
  for i = 0, trigger_count - 1 do
    local line_index = (i * phrase_length) + 1
    
    if line_index <= pattern_length then
      local line = pattern_track:line(line_index)
      local note_column = line:note_column(note_column_index)
      
      -- Trigger the phrase with a C-4 note (could be any note, depending on instrument mapping)
      note_column.note_value = 48  -- C-4
      note_column.instrument_value = instrument_index - 1
      triggers_added = triggers_added + 1
    end
  end
  
  -- Show status message
  renoise.app():show_status(string.format(
    "Flood filled pattern with phrase %02d (%d rows), added %d triggers", 
    phrase_index, phrase_length, triggers_added))
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Flood Fill Pattern with Phrase",invoke=function() PakettiFloodFillPatternWithPhrase() end}
renoise.tool():add_keybinding{name="Global:Paketti:Flood Fill Pattern with Phrase",invoke=function() PakettiFloodFillPatternWithPhrase() end}

---------------------------------------------------------------------------------------------------------
-- Write Notes Ascending/Descending/Random for Phrase Editor
---------------------------------------------------------------------------------------------------------
-- Helper function to convert note value to string
function PakettiPhraseEditorNoteValueToString(value)
  local notes = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
  local octave = math.floor(value / 12)
  local note = notes[(value % 12) + 1]
  return note .. octave
end

-- Function to write notes in specified order (ascending, descending, or random) in phrase
function PakettiPhraseEditorWriteNotesMethod(method)
  local song=renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  
  local instrument = song.selected_instrument
  local current_line = song.selected_phrase_line_index
  local selected_note_column = song.selected_phrase_note_column_index
  
  if not instrument or not instrument.sample_mappings[1] then
    renoise.app():show_status("No sample mappings found for this instrument")
    return
  end
  
  -- Check if first sample has slice markers
  local first_sample_has_slices = false
  local slice_start_note = nil
  local slice_count = 0
  
  if #instrument.samples > 0 then
    local first_sample = instrument:sample(1)
    if first_sample and #first_sample.slice_markers > 0 then
      first_sample_has_slices = true
      slice_count = #first_sample.slice_markers
      
      -- Get the slice start note - slices are the SECOND mapping onwards
      local sample_mappings = instrument.sample_mappings[1] -- Note layer
      if sample_mappings and #sample_mappings >= 2 then
        -- Get the first slice mapping (slices start at index 2)
        local first_slice_mapping = sample_mappings[2]
        if first_slice_mapping and first_slice_mapping.base_note then
          slice_start_note = first_slice_mapping.base_note
        end
      end
      
      -- Fallback: slices typically start one note above the original sample's base note
      if not slice_start_note and first_sample.sample_mapping and first_sample.sample_mapping.base_note then
        slice_start_note = first_sample.sample_mapping.base_note + 1
      end
    end
  end
  
  -- Create a table of all mapped notes
  local notes = {}
  
  if first_sample_has_slices and slice_start_note then
    -- If slice markers exist, only create notes for slices
    for i = 0, slice_count - 1 do
      local slice_note = slice_start_note + i
      -- Ensure we don't exceed valid note range (0-119)
      if slice_note <= 119 then
        table.insert(notes, {
          note = slice_note,
          mapping = instrument.samples[1].sample_mapping
        })
      else
        break -- Stop adding notes if we exceed the valid range
      end
    end
  else
    -- If no slice markers, process all sample mappings
    for _, mapping in ipairs(instrument.sample_mappings[1]) do
      if mapping.note_range then
        for i = mapping.note_range[1], mapping.note_range[2] do
          table.insert(notes, {
            note = i,
            mapping = mapping
          })
        end
      end
    end
  end
  
  if #notes == 0 then
    renoise.app():show_status("No valid sample mappings found for this instrument")
    return
  end
  
  -- Sort or shuffle based on method
  if method == "ascending" then
    table.sort(notes, function(a, b) return a.note < b.note end)
  elseif method == "descending" then
    table.sort(notes, function(a, b) return a.note > b.note end)
  elseif method == "random" then
    -- Fisher-Yates shuffle
    for i = #notes, 2, -1 do
      local j = math.random(i)
      notes[i], notes[j] = notes[j], notes[i]
    end
  end
  
  local last_note = -1
  local last_mapping = nil
  
  -- Write the notes
  for i = 1, #notes do
    if current_line <= phrase.number_of_lines then
      local note_column = phrase:line(current_line):note_column(selected_note_column)
      note_column.note_value = notes[i].note
      note_column.instrument_value = song.selected_instrument_index - 1
      current_line = current_line + 1
      last_note = notes[i].note
      last_mapping = notes[i].mapping
    else
      break
    end
  end
  
  if last_note ~= -1 and last_mapping then
    local note_name = PakettiPhraseEditorNoteValueToString(last_note)
    renoise.app():show_status(string.format(
      "Wrote notes until row %d at note %s (base note: %d)", 
      current_line - 1, 
      note_name,
      last_mapping.base_note
    ))
  end
end

-- Function to write notes in specified order with EditStep (ascending, descending, or random) in phrase
function PakettiPhraseEditorWriteNotesMethodEditStep(method)
  local song=renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  
  local instrument = song.selected_instrument
  local current_line = song.selected_phrase_line_index
  local selected_note_column = song.selected_phrase_note_column_index
  local edit_step = song.transport.edit_step
  
  -- If edit_step is 0, treat it as 1 (write to every row)
  if edit_step == 0 then
    edit_step = 1
  end
  
  if not instrument or not instrument.sample_mappings[1] then
    renoise.app():show_status("No sample mappings found for this instrument")
    return
  end
  
  -- Check if first sample has slice markers
  local first_sample_has_slices = false
  local slice_start_note = nil
  local slice_count = 0
  
  if #instrument.samples > 0 then
    local first_sample = instrument:sample(1)
    if first_sample and #first_sample.slice_markers > 0 then
      first_sample_has_slices = true
      slice_count = #first_sample.slice_markers
      
      -- Get the slice start note - slices are the SECOND mapping onwards
      local sample_mappings = instrument.sample_mappings[1] -- Note layer
      if sample_mappings and #sample_mappings >= 2 then
        -- Get the first slice mapping (slices start at index 2)
        local first_slice_mapping = sample_mappings[2]
        if first_slice_mapping and first_slice_mapping.base_note then
          slice_start_note = first_slice_mapping.base_note
        end
      end
      
      -- Fallback: slices typically start one note above the original sample's base note
      if not slice_start_note and first_sample.sample_mapping and first_sample.sample_mapping.base_note then
        slice_start_note = first_sample.sample_mapping.base_note + 1
      end
    end
  end
  
  -- Create a table of all mapped notes
  local notes = {}
  
  if first_sample_has_slices and slice_start_note then
    -- If slice markers exist, only create notes for slices
    for i = 0, slice_count - 1 do
      local slice_note = slice_start_note + i
      -- Ensure we don't exceed valid note range (0-119)
      if slice_note <= 119 then
        table.insert(notes, {
          note = slice_note,
          mapping = instrument.samples[1].sample_mapping
        })
      else
        break -- Stop adding notes if we exceed the valid range
      end
    end
  else
    -- If no slice markers, process all sample mappings
    for _, mapping in ipairs(instrument.sample_mappings[1]) do
      if mapping.note_range then
        for i = mapping.note_range[1], mapping.note_range[2] do
          table.insert(notes, {
            note = i,
            mapping = mapping
          })
        end
      end
    end
  end
  
  if #notes == 0 then
    renoise.app():show_status("No valid sample mappings found for this instrument")
    return
  end
  
  -- Sort or shuffle based on method
  if method == "ascending" then
    table.sort(notes, function(a, b) return a.note < b.note end)
  elseif method == "descending" then
    table.sort(notes, function(a, b) return a.note > b.note end)
  elseif method == "random" then
    -- Fisher-Yates shuffle
    for i = #notes, 2, -1 do
      local j = math.random(i)
      notes[i], notes[j] = notes[j], notes[i]
    end
  end
  
  -- First, clear all existing notes in the selected note column from current line to end of phrase
  for line_index = current_line, phrase.number_of_lines do
    local note_column = phrase:line(line_index):note_column(selected_note_column)
    note_column.note_value = renoise.PatternLine.EMPTY_NOTE
    note_column.instrument_value = renoise.PatternLine.EMPTY_INSTRUMENT
    note_column.volume_value = renoise.PatternLine.EMPTY_VOLUME
    note_column.panning_value = renoise.PatternLine.EMPTY_PANNING
    note_column.delay_value = renoise.PatternLine.EMPTY_DELAY
    note_column.effect_number_value = renoise.PatternLine.EMPTY_EFFECT_NUMBER
    note_column.effect_amount_value = renoise.PatternLine.EMPTY_EFFECT_AMOUNT
  end
  
  local last_note = -1
  local last_mapping = nil
  local write_line = current_line
  
  -- Write the notes using EditStep
  for i = 1, #notes do
    if write_line <= phrase.number_of_lines then
      local note_column = phrase:line(write_line):note_column(selected_note_column)
      -- Write the new note
      note_column.note_value = notes[i].note
      note_column.instrument_value = song.selected_instrument_index - 1
      write_line = write_line + edit_step
      last_note = notes[i].note
      last_mapping = notes[i].mapping
    else
      break
    end
  end
  
  if last_note ~= -1 and last_mapping then
    local note_name = PakettiPhraseEditorNoteValueToString(last_note)
    renoise.app():show_status(string.format(
      "Cleared and wrote notes with EditStep %d until row %d at note %s (base note: %d)", 
      edit_step,
      write_line - edit_step, 
      note_name,
      last_mapping.base_note
    ))
  end
end

renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Write Notes Ascending",invoke=function() PakettiPhraseEditorWriteNotesMethod("ascending") end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Write Notes Descending",invoke=function() PakettiPhraseEditorWriteNotesMethod("descending") end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Write Notes Random",invoke=function() PakettiPhraseEditorWriteNotesMethod("random") end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Write Notes EditStep Ascending",invoke=function() PakettiPhraseEditorWriteNotesMethodEditStep("ascending") end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Write Notes EditStep Descending",invoke=function() PakettiPhraseEditorWriteNotesMethodEditStep("descending") end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Write Notes EditStep Random",invoke=function() PakettiPhraseEditorWriteNotesMethodEditStep("random") end}

---------------------------------------------------------------------------------------------------------
-- Transpose functions for Phrase Editor
---------------------------------------------------------------------------------------------------------
function PakettiPhraseEditorTranspose(steps)
  local song=renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  
  local selection = song.selection_in_phrase
  local start_line, end_line, start_column, end_column
  
  if selection ~= nil then
    start_line = selection.start_line
    end_line = selection.end_line
    start_column = selection.start_column
    end_column = selection.end_column
  else
    start_line = 1
    end_line = phrase.number_of_lines
    start_column = 1
    end_column = phrase.visible_note_columns
  end
  
  for line_index = start_line, end_line do
    local line = phrase:line(line_index)
    
    local columns_to_end = math.min(end_column, phrase.visible_note_columns)
    
    for column_index = start_column, columns_to_end do
      local note_column = line:note_column(column_index)
      if not note_column.is_empty then
        if note_column.note_value < 120 then
          note_column.note_value = (note_column.note_value + steps) % 120
        end
      end
    end
  end
end

if renoise.API_VERSION >= 6.2 then
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Transpose Octave Up (Selection/Phrase)",invoke=function() PakettiPhraseEditorTranspose(12) end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Transpose Octave Down (Selection/Phrase)",invoke=function() PakettiPhraseEditorTranspose(-12) end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Transpose +1 (Selection/Phrase)",invoke=function() PakettiPhraseEditorTranspose(1) end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Transpose -1 (Selection/Phrase)",invoke=function() PakettiPhraseEditorTranspose(-1) end}
end

---------------------------------------------------------------------------------------------------------
-- Shift Selection function for Phrase Editor (DRY approach)
---------------------------------------------------------------------------------------------------------
function PakettiPhraseEditorShiftInitializeSelection()
  local song=renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    return
  end
  
  local selected_line_index = song.selected_phrase_line_index
  local selected_column_index = song.selected_phrase_note_column_index
  
  if selected_column_index == 0 then
    selected_column_index = phrase.visible_note_columns + song.selected_phrase_effect_column_index
  end
  
  song.selection_in_phrase = {
    start_column = selected_column_index,
    end_column = selected_column_index,
    start_line = selected_line_index,
    end_line = selected_line_index
  }
end

function PakettiPhraseEditorShift(direction)
  local song=renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  
  local selection = song.selection_in_phrase
  
  if not selection then
    PakettiPhraseEditorShiftInitializeSelection()
    selection = song.selection_in_phrase
  end
  
  if direction == "up" or direction == "down" then
    local delta = (direction == "down") and 1 or -1
    local limit = (direction == "down") and phrase.number_of_lines or 1
    local at_limit_msg = (direction == "down") and "You are at the end of the phrase. No more can be selected." or "You are at the beginning of the phrase. No more can be selected."
    
    if song.selected_phrase_line_index == selection.end_line then
      if (direction == "down" and selection.end_line < limit) or (direction == "up" and selection.end_line > limit) then
        selection.end_line = selection.end_line + delta
      else
        renoise.app():show_status(at_limit_msg)
        return
      end
    else
      if (direction == "down" and song.selected_phrase_line_index < selection.start_line) or 
         (direction == "up" and song.selected_phrase_line_index > selection.start_line) then
        local temp_line = selection.start_line
        selection.start_line = selection.end_line
        selection.end_line = temp_line
      end
      selection.start_line = song.selected_phrase_line_index
    end
    
    if selection.start_line > selection.end_line then
      local temp = selection.start_line
      selection.start_line = selection.end_line
      selection.end_line = temp
    end
    
    song.selection_in_phrase = selection
    song.selected_phrase_line_index = selection.end_line
    
  elseif direction == "left" or direction == "right" then
    local delta = (direction == "right") and 1 or -1
    local current_column = song.selected_phrase_note_column_index
    if current_column == 0 then
      current_column = phrase.visible_note_columns + song.selected_phrase_effect_column_index
    end
    
    local total_columns = phrase.visible_note_columns + phrase.visible_effect_columns
    local limit = (direction == "right") and total_columns or 1
    local at_limit_msg = (direction == "right") and "You are at the last column. No more can be selected." or "You are at the first column. No more can be selected."
    
    if current_column == selection.end_column then
      if (direction == "right" and selection.end_column < limit) or (direction == "left" and selection.end_column > limit) then
        selection.end_column = selection.end_column + delta
      else
        renoise.app():show_status(at_limit_msg)
        return
      end
    else
      if (direction == "right" and current_column < selection.start_column) or 
         (direction == "left" and current_column > selection.start_column) then
        local temp_column = selection.start_column
        selection.start_column = selection.end_column
        selection.end_column = temp_column
      end
      selection.start_column = current_column
    end
    
    if selection.start_column > selection.end_column then
      local temp = selection.start_column
      selection.start_column = selection.end_column
      selection.end_column = temp
    end
    
    song.selection_in_phrase = selection
    
    if selection.end_column <= phrase.visible_note_columns then
      song.selected_phrase_note_column_index = selection.end_column
    else
      song.selected_phrase_effect_column_index = selection.end_column - phrase.visible_note_columns
    end
  end
end

---------------------------------------------------------------------------------------------------------
-- Shift Notes Left/Right for Phrase Editor
---------------------------------------------------------------------------------------------------------
function PakettiPhraseEditorShiftNotes(direction)
  local song=renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  
  local selection = song.selection_in_phrase
  
  local start_line, end_line
  if selection then
    start_line = selection.start_line
    end_line = selection.end_line
    
    if direction < 0 then
      for line_idx = start_line, end_line do
        local line = phrase:line(line_idx)
        if not line.note_columns[1].is_empty then
          renoise.app():show_status("Cannot shift selection left: notes present in first column")
          return
        end
      end
    end
  else
    start_line = song.selected_phrase_line_index
    end_line = song.selected_phrase_line_index
  end
  
  for line_idx = start_line, end_line do
    local line = phrase:line(line_idx)
    
    local leftmost_used = nil
    local rightmost_used = 0
    for col_idx = 1, phrase.visible_note_columns do
      if not line.note_columns[col_idx].is_empty then
        if not leftmost_used then leftmost_used = col_idx end
        rightmost_used = col_idx
      end
    end
    
    if leftmost_used then
      if direction < 0 then
        if not selection and leftmost_used == 1 then
          renoise.app():show_status("Cannot shift notes left: notes present in first column")
          return
        end
      else
        if rightmost_used == 12 then
          renoise.app():show_status("Cannot shift notes right: all columns used")
          return
        end
        if rightmost_used == phrase.visible_note_columns and phrase.visible_note_columns < 12 then
          phrase.visible_note_columns = phrase.visible_note_columns + 1
        end
      end
      
      if direction < 0 then
        for col_idx = leftmost_used, rightmost_used do
          local source_col = line.note_columns[col_idx]
          local target_col = line.note_columns[col_idx - 1]
          
          target_col.note_value = source_col.note_value
          target_col.instrument_value = source_col.instrument_value
          target_col.volume_value = source_col.volume_value
          target_col.panning_value = source_col.panning_value
          target_col.delay_value = source_col.delay_value
          target_col.effect_number_value = source_col.effect_number_value
          target_col.effect_amount_value = source_col.effect_amount_value
        end
        line.note_columns[rightmost_used]:clear()
      else
        for col_idx = rightmost_used, leftmost_used, -1 do
          local source_col = line.note_columns[col_idx]
          local target_col = line.note_columns[col_idx + 1]
          
          target_col.note_value = source_col.note_value
          target_col.instrument_value = source_col.instrument_value
          target_col.volume_value = source_col.volume_value
          target_col.panning_value = source_col.panning_value
          target_col.delay_value = source_col.delay_value
          target_col.effect_number_value = source_col.effect_number_value
          target_col.effect_amount_value = source_col.effect_amount_value
        end
        line.note_columns[leftmost_used]:clear()
      end
    end
  end
  
  song.selected_phrase_note_column_index = 1
  if direction < 0 then
    renoise.app():show_status(selection and "Selection shifted left" or "Notes shifted left")
  else
    renoise.app():show_status(selection and "Selection shifted right" or "Notes shifted right")
  end
end

if renoise.API_VERSION >= 6.2 then
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker Shift-Right Selection In Phrase",invoke=function() PakettiPhraseEditorShift("right") end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker Shift-Left Selection In Phrase",invoke=function() PakettiPhraseEditorShift("left") end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker Shift-Down Selection In Phrase",invoke=function() PakettiPhraseEditorShift("down") end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Impulse Tracker Shift-Up Selection In Phrase",invoke=function() PakettiPhraseEditorShift("up") end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Shift Notes Right",invoke=function() PakettiPhraseEditorShiftNotes(1) end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Shift Notes Left",invoke=function() PakettiPhraseEditorShiftNotes(-1) end}
end

---------------------------------------------------------------------------------------------------------
-- Nudge functions for Phrase Editor
---------------------------------------------------------------------------------------------------------
-- Helper function to get selection info for phrase
function PakettiPhraseEditorSelectionInfo()
  local song=renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    return nil
  end
  
  local selection = song.selection_in_phrase
  if not selection then
    print("No selection in phrase!")
    return nil
  end
  
  print("Selection in Phrase:")
  print("Start Column:", selection.start_column)
  print("End Column:", selection.end_column)
  print("Start Line:", selection.start_line)
  print("End Line:", selection.end_line)
  
  local result = {
    note_columns = {},
    effect_columns = {}
  }
  
  local visible_note_columns = phrase.visible_note_columns
  local visible_effect_columns = phrase.visible_effect_columns
  local total_columns = visible_note_columns + visible_effect_columns
  
  print("Visible Note Columns:", visible_note_columns)
  print("Visible Effect Columns:", visible_effect_columns)
  print("Total Columns:", total_columns)
  
  local start_column = selection.start_column
  local end_column = selection.end_column
  
  start_column = math.max(start_column, 1)
  end_column = math.min(end_column, total_columns)
  
  if visible_note_columns > 0 and start_column <= visible_note_columns then
    for col = start_column, math.min(end_column, visible_note_columns) do
      table.insert(result.note_columns, col)
    end
  end
  
  if visible_effect_columns > 0 and end_column > visible_note_columns then
    local effect_start = math.max(start_column - visible_note_columns, 1)
    local effect_end = end_column - visible_note_columns
    for col = effect_start, math.min(effect_end, visible_effect_columns) do
      table.insert(result.effect_columns, col)
    end
  end
  
  print("Selected Note Columns:", #result.note_columns > 0 and table.concat(result.note_columns, ", ") or "None")
  print("Selected Effect Columns:", #result.effect_columns > 0 and table.concat(result.effect_columns, ", ") or "None")
  
  return result
end

function PakettiPhraseEditorNudge(direction)
  local song=renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  
  local selection_info = PakettiPhraseEditorSelectionInfo()
  if not selection_info then 
    renoise.app():show_status("No selection in phrase!")
    return
  end
  
  local phrase_selection = song.selection_in_phrase
  if not phrase_selection then
    renoise.app():show_status("No selection in phrase!")
    return
  end
  
  local start_line = phrase_selection.start_line
  local end_line = phrase_selection.end_line
  
  print("Selection in Phrase:")
  print(string.format("Start Line: %d, End Line: %d", start_line, end_line))
  print(string.format("Start Column: %d, End Column: %d", phrase_selection.start_column, phrase_selection.end_column))
  print(string.format("Selected Note Columns: %s", table.concat(selection_info.note_columns, ", ")))
  
  local function copy_note_column(note_column)
    return {
      note_value = note_column.note_value,
      instrument_value = note_column.instrument_value,
      volume_value = note_column.volume_value,
      panning_value = note_column.panning_value,
      delay_value = note_column.delay_value,
      effect_number_value = note_column.effect_number_value,
      effect_amount_value = note_column.effect_amount_value
    }
  end
  
  local function set_note_column(note_column, data)
    note_column.note_value = data.note_value
    note_column.instrument_value = data.instrument_value
    note_column.volume_value = data.volume_value
    note_column.panning_value = data.panning_value
    note_column.delay_value = data.delay_value
    note_column.effect_number_value = data.effect_number_value
    note_column.effect_amount_value = data.effect_amount_value
  end
  
  local function copy_effect_column(effect_column)
    return {
      number_value = effect_column.number_value,
      amount_value = effect_column.amount_value
    }
  end
  
  local function set_effect_column(effect_column, data)
    effect_column.number_value = data.number_value
    effect_column.amount_value = data.amount_value
  end
  
  local lines = phrase.lines
  local adjusted_start_line = math.max(1, math.min(start_line, phrase.number_of_lines))
  local adjusted_end_line = math.max(1, math.min(end_line, phrase.number_of_lines))
  
  for _, column_index in ipairs(selection_info.note_columns) do
    if direction == "down" then
      local bottom_line = lines[adjusted_end_line]
      local stored_note_column = copy_note_column(bottom_line.note_columns[column_index])
      local stored_effect_columns = {}
      for ec_index, effect_column in ipairs(bottom_line.effect_columns) do
        stored_effect_columns[ec_index] = copy_effect_column(effect_column)
      end
      
      for line_index = adjusted_end_line, adjusted_start_line + 1, -1 do
        local current_line = lines[line_index]
        local previous_line = lines[line_index - 1]
        
        local current_note_column = current_line.note_columns[column_index]
        local previous_note_column = previous_line.note_columns[column_index]
        current_note_column:copy_from(previous_note_column)
        
        local current_effect_columns = current_line.effect_columns
        local previous_effect_columns = previous_line.effect_columns
        for ec_index = 1, #current_effect_columns do
          current_effect_columns[ec_index]:copy_from(previous_effect_columns[ec_index])
        end
      end
      
      local top_line = lines[adjusted_start_line]
      set_note_column(top_line.note_columns[column_index], stored_note_column)
      local top_effect_columns = top_line.effect_columns
      for ec_index = 1, #top_effect_columns do
        set_effect_column(top_effect_columns[ec_index], stored_effect_columns[ec_index] or {})
      end
      
    elseif direction == "up" then
      local top_line = lines[adjusted_start_line]
      local stored_note_column = copy_note_column(top_line.note_columns[column_index])
      local stored_effect_columns = {}
      for ec_index, effect_column in ipairs(top_line.effect_columns) do
        stored_effect_columns[ec_index] = copy_effect_column(effect_column)
      end
      
      for line_index = adjusted_start_line, adjusted_end_line - 1 do
        local current_line = lines[line_index]
        local next_line = lines[line_index + 1]
        
        local current_note_column = current_line.note_columns[column_index]
        local next_note_column = next_line.note_columns[column_index]
        current_note_column:copy_from(next_note_column)
        
        local current_effect_columns = current_line.effect_columns
        local next_effect_columns = next_line.effect_columns
        for ec_index = 1, #current_effect_columns do
          current_effect_columns[ec_index]:copy_from(next_effect_columns[ec_index])
        end
      end
      
      local bottom_line = lines[adjusted_end_line]
      set_note_column(bottom_line.note_columns[column_index], stored_note_column)
      local bottom_effect_columns = bottom_line.effect_columns
      for ec_index = 1, #bottom_effect_columns do
        set_effect_column(bottom_effect_columns[ec_index], stored_effect_columns[ec_index] or {})
      end
      
    else
      renoise.app():show_status("Invalid nudge direction!")
      return
    end
  end
  
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
  renoise.app():show_status("Nudge " .. direction .. " applied in phrase.")
end

function PakettiPhraseEditorNudgeWithDelay(direction)
  local song=renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  
  local selection_info = PakettiPhraseEditorSelectionInfo()
  if not selection_info then 
    renoise.app():show_status("No selection in phrase!")
    return
  end
  
  local phrase_selection = song.selection_in_phrase
  if not phrase_selection then
    renoise.app():show_status("No selection in phrase!")
    return
  end
  
  local start_line = phrase_selection.start_line
  local end_line = phrase_selection.end_line
  
  print("Selection in Phrase:")
  print(string.format("Start Line: %d, End Line: %d", start_line, end_line))
  print(string.format("Start Column: %d, End Column: %d", phrase_selection.start_column, phrase_selection.end_column))
  print(string.format("Selected Note Columns: %s", table.concat(selection_info.note_columns, ", ")))
  
  local lines = phrase.lines
  local adjusted_start_line = math.max(1, math.min(start_line, phrase.number_of_lines))
  local adjusted_end_line = math.max(1, math.min(end_line, phrase.number_of_lines))
  
  for _, column_index in ipairs(selection_info.note_columns) do
    if direction == "down" then
      for line_index = adjusted_end_line, adjusted_start_line, -1 do
        local note_column = lines[line_index].note_columns[column_index]
        local effect_columns = lines[line_index].effect_columns
        
        if not note_column.is_empty or note_column.delay_value > 0 then
          local delay = note_column.delay_value
          local new_delay = delay + 1
          
          if new_delay > 0xFF then
            new_delay = 0
            
            local next_line_index = line_index + 1
            if next_line_index > adjusted_end_line then
              next_line_index = adjusted_start_line
            end
            
            local next_line = lines[next_line_index]
            local next_note_column = next_line.note_columns[column_index]
            local next_effect_columns = next_line.effect_columns
            
            local can_move = next_note_column.is_empty and next_note_column.delay_value == 0
            for _, next_effect_column in ipairs(next_effect_columns) do
              if not next_effect_column.is_empty then
                can_move = false
                break
              end
            end
            
            if can_move then
              print(string.format(
                "Moving note/delay down with wrap: Column %d, Row %d -> Row %d", 
                column_index, line_index, next_line_index))
              
              next_note_column:copy_from(note_column)
              next_note_column.delay_value = new_delay
              note_column:clear()
              
              for ec_index, effect_column in ipairs(effect_columns) do
                local next_effect_column = next_effect_columns[ec_index]
                next_effect_column:copy_from(effect_column)
                effect_column:clear()
              end
            else
              print(string.format(
                "Collision at Column %d, Row %d. Cannot nudge further.", 
                column_index, next_line_index))
            end
          else
            note_column.delay_value = new_delay
            print(string.format(
              "Row %d, Column %d: Note %s, Delay %02X -> %02X",
              line_index, column_index, note_column.note_string, delay, new_delay))
          end
        end
      end
    elseif direction == "up" then
      for line_index = adjusted_start_line, adjusted_end_line do
        local note_column = lines[line_index].note_columns[column_index]
        local effect_columns = lines[line_index].effect_columns
        
        if not note_column.is_empty or note_column.delay_value > 0 then
          local delay = note_column.delay_value
          local new_delay = delay - 1
          
          if new_delay < 0 then
            new_delay = 0xFF
            
            local prev_line_index = line_index - 1
            if prev_line_index < adjusted_start_line then
              prev_line_index = adjusted_end_line
            end
            
            local prev_line = lines[prev_line_index]
            local prev_note_column = prev_line.note_columns[column_index]
            local prev_effect_columns = prev_line.effect_columns
            
            local can_move = prev_note_column.is_empty and prev_note_column.delay_value == 0
            for _, prev_effect_column in ipairs(prev_effect_columns) do
              if not prev_effect_column.is_empty then
                can_move = false
                break
              end
            end
            
            if can_move then
              print(string.format(
                "Moving note/delay up with wrap: Column %d, Row %d -> Row %d", 
                column_index, line_index, prev_line_index))
              
              prev_note_column:copy_from(note_column)
              prev_note_column.delay_value = new_delay
              note_column:clear()
              
              for ec_index, effect_column in ipairs(effect_columns) do
                local prev_effect_column = prev_effect_columns[ec_index]
                prev_effect_column:copy_from(effect_column)
                effect_column:clear()
              end
            else
              print(string.format(
                "Collision at Column %d, Row %d. Cannot nudge further.", 
                column_index, prev_line_index))
            end
          else
            note_column.delay_value = new_delay
            print(string.format(
              "Row %d, Column %d: Note %s, Delay %02X -> %02X",
              line_index, column_index, note_column.note_string, delay, new_delay))
          end
        end
      end
    else
      renoise.app():show_status("Invalid nudge direction!")
      return
    end
  end
  
  phrase.delay_column_visible = true
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
  renoise.app():show_status("Nudge " .. direction .. " with delay applied in phrase.")
end

if renoise.API_VERSION >= 6.2 then
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge Down",invoke=function() PakettiPhraseEditorNudge("down") end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge Up",invoke=function() PakettiPhraseEditorNudge("up") end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge with Delay (Down)",invoke=function() PakettiPhraseEditorNudgeWithDelay("down") end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge with Delay (Up)",invoke=function() PakettiPhraseEditorNudgeWithDelay("up") end}
end