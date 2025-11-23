-- Phrase follow variables
-- Initialize from preferences, defaulting to false if not set
local phrase_follow_enabled = false
if preferences and preferences.PakettiPhraseFollowPatternPlayback then
  phrase_follow_enabled = preferences.PakettiPhraseFollowPatternPlayback.value
end
local current_cycle = 0  -- Track current cycle for phrase follow

-- Function to apply settings to the selected phrase or create a new one if none exists
function pakettiPhraseSettingsApplyPhraseSettings()
  local song = renoise.song()
  if not song then
    return
  end
  
  local instrument = song.selected_instrument

  -- Check if there are no phrases in the selected instrument
  if #instrument.phrases == 0 then
    instrument:insert_phrase_at(1)
    song.selected_phrase_index = 1
  elseif song.selected_phrase_index == 0 then
    song.selected_phrase_index = 1
  end

  local phrase = song.selected_phrase

  -- Apply the name to the phrase if "Set Name" is checked and the name text field has a value
  if preferences.pakettiPhraseInitDialog.SetName.value then
    local custom_name = preferences.pakettiPhraseInitDialog.Name.value
    if custom_name ~= "" then
      phrase.name = custom_name
    else
      phrase.name = string.format("Phrase %02d", song.selected_phrase_index)
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
  local song = renoise.song()
  if not song then
    return
  end
  
  renoise.app().window.active_middle_frame = 3
  local instrument = song.selected_instrument
  local phrase_count = #instrument.phrases
  local new_phrase_index = phrase_count + 1

  -- Insert the new phrase at the end of the phrase list
  instrument:insert_phrase_at(new_phrase_index)
  song.selected_phrase_index = new_phrase_index

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
  local song = renoise.song()
  if not song then
    return
  end
  
  local instrument = song.selected_instrument
  if #instrument.phrases == 0 then
    pakettiInitPhraseSettingsCreateNewPhrase()
  else
    pakettiPhraseSettingsApplyPhraseSettings()
  end
end

------------------------------------------------
renoise.tool():add_keybinding{name="Global:Paketti:Create New Phrase using Paketti Settings",invoke=function() pakettiInitPhraseSettingsCreateNewPhrase() end}
renoise.tool():add_keybinding{name="Global:Paketti:Modify Current Phrase using Paketti Settings",invoke=function() pakettiPhraseSettingsModifyCurrentPhrase() end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Create New Phrase using Paketti Settings",invoke=function() pakettiInitPhraseSettingsCreateNewPhrase() end}
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Modify Current Phrase using Paketti Settings",invoke=function() pakettiPhraseSettingsModifyCurrentPhrase() end}
renoise.tool():add_midi_mapping{name="Paketti:Create New Phrase Using Paketti Settings",invoke=function(message) if message:is_trigger() then pakettiInitPhraseSettingsCreateNewPhrase() end end}
renoise.tool():add_midi_mapping{name="Paketti:Modify Current Phrase Using Paketti Settings",invoke=function(message) if message:is_trigger() then pakettiPhraseSettingsModifyCurrentPhrase() end end}
------------------------------------------------
function RecordFollowOffPhrase()
local s=renoise.song()
if not s then
  return
end

local t=s.transport
t.follow_player=false
if t.edit_mode == false then 
t.edit_mode=true else
t.edit_mode=false end end

renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Record+Follow Off",invoke=function() RecordFollowOffPhrase() end}


function createPhrase()
local s=renoise.song() 
if not s then
  return
end

  renoise.app().window.active_middle_frame=3
  s.instruments[s.selected_instrument_index]:insert_phrase_at(1) 
  s.instruments[s.selected_instrument_index].phrase_editor_visible=true
  s.selected_phrase_index=1

local selphra=s.instruments[s.selected_instrument_index].phrases[s.selected_phrase_index]
  
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
  if not s then
    return
  end
  
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
local s=renoise.song()
if not s then
  return
end

s.instruments[s.selected_instrument_index]:insert_phrase_at(1)
end

renoise.tool():add_keybinding{name="Global:Paketti:Add New Phrase",invoke=function()  phraseadd() end}

----
renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Init Phrase Settings",invoke=function()
local s=renoise.song()
if not s then
  return
end

if s.selected_phrase == nil then
s.instruments[s.selected_instrument_index]:insert_phrase_at(1)
s.selected_phrase_index = 1
end

local selphra=s.selected_phrase
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

local renamephrase_to_index=tostring(s.selected_phrase_index)
selphra.name=renamephrase_to_index
--selphra.name=s.selected_phrase_index
end}

function joulephrasedoubler()
  local s=renoise.song()
  if not s then
    return
  end
  
  local old_phraselength = s.selected_phrase.number_of_lines
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
  local s=renoise.song()
  if not s then
    return
  end
  
  local old_phraselength = s.selected_phrase.number_of_lines
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
  local song=renoise.song()
  if not song then
    return
  end
  
  if song.transport.playing then
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
  if not s then
    return
  end
  
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
  if not s then
    return
  end
  
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
  if not s then
    return
  end
  
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
  if not s then
    return
  end
  
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
  if not s then
    return
  end
  
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
  if not s then
    return
  end
  
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
  if not s then
    return
  end
  
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
  if not song then
    return
  end
  
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
-- SubColumn-Aware Write Values/Notes for Phrase Editor
---------------------------------------------------------------------------------------------------------
-- WAITING FOR API UPDATE: Phrase Editor does not yet have selected_phrase_sub_column_type API
-- When Renoise API adds phrase sub-column detection, change this variable to point to the correct property:
-- local phrase_subcolumn_selection = song.selected_phrase_sub_column_type (or similar)
-- Then uncomment the keybindings at the bottom of this section
---------------------------------------------------------------------------------------------------------
-- These functions adapt to whichever subcolumn you're in:
-- - Note subcolumn -> writes notes (delegates to existing note writing functions)
-- - Volume subcolumn -> writes 00-80 (0-128)
-- - Panning subcolumn -> writes 00-80 (0-128)
-- - Delay subcolumn -> writes 00-FF (0-255)
-- - Sample Effect Amount -> writes 00-FF (0-255)
-- - Effect Amount -> writes 00-FF (0-255)

function PakettiPhraseEditorSubColumnWriteValues(method, use_editstep)
  local song = renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  
  -- WAITING FOR API UPDATE: This property doesn't exist yet for Phrase Editor
  -- When API is updated, change this to: song.selected_phrase_sub_column_type (or whatever it's called)
  local phrase_subcolumn_selection = song.selected_sub_column_type -- This only works in Pattern Editor!
  local sub_column_type = phrase_subcolumn_selection
  
  -- If in Note subcolumn, delegate to existing note writing functions
  if sub_column_type == 1 then -- SUB_COLUMN_NOTE
    if use_editstep then
      PakettiPhraseEditorWriteNotesMethodEditStep(method)
    else
      PakettiPhraseEditorWriteNotesMethod(method)
    end
    return
  end
  
  -- For other subcolumns, write values
  local current_line = song.selected_phrase_line_index
  local selected_note_column = song.selected_phrase_note_column_index
  local edit_step = use_editstep and song.transport.edit_step or 1
  
  -- If edit_step is 0, treat it as 1
  if edit_step == 0 then
    edit_step = 1
  end
  
  -- Determine value range based on subcolumn type
  local min_value = 0
  local max_value = 255
  local hex_format = "%02X"
  local column_name = "value"
  
  if sub_column_type == 3 then -- Volume
    max_value = 128
    column_name = "volume"
  elseif sub_column_type == 4 then -- Panning
    max_value = 128
    column_name = "panning"
  elseif sub_column_type == 5 then -- Delay
    max_value = 255
    column_name = "delay"
  elseif sub_column_type == 7 then -- Sample Effect Amount
    max_value = 255
    column_name = "sample effect amount"
  elseif sub_column_type == 9 then -- Effect Amount
    max_value = 255
    column_name = "effect amount"
  else
    renoise.app():show_status("Write Values only works in Volume, Panning, Delay, or Effect Amount columns")
    return
  end
  
  -- Create value table
  local values = {}
  for i = min_value, max_value do
    table.insert(values, i)
  end
  
  -- Sort or shuffle based on method
  if method == "ascending" then
    -- Already in ascending order
  elseif method == "descending" then
    local reversed = {}
    for i = #values, 1, -1 do
      table.insert(reversed, values[i])
    end
    values = reversed
  elseif method == "random" then
    -- Fisher-Yates shuffle
    trueRandomSeed()
    for i = #values, 2, -1 do
      local j = math.random(i)
      values[i], values[j] = values[j], values[i]
    end
  end
  
  -- Clear existing values if using editstep
  if use_editstep then
    for line_index = current_line, phrase.number_of_lines do
      local note_column = phrase:line(line_index):note_column(selected_note_column or 1)
      if sub_column_type == 3 then
        note_column.volume_value = renoise.PatternLine.EMPTY_VOLUME
      elseif sub_column_type == 4 then
        note_column.panning_value = renoise.PatternLine.EMPTY_PANNING
      elseif sub_column_type == 5 then
        note_column.delay_value = renoise.PatternLine.EMPTY_DELAY
      elseif sub_column_type == 7 then
        note_column.effect_amount_value = renoise.PatternLine.EMPTY_EFFECT_AMOUNT
      elseif sub_column_type == 9 then
        local effect_column = song.selected_phrase_effect_column_index
        if effect_column > 0 then
          phrase:line(line_index):effect_column(effect_column).amount_value = renoise.PatternLine.EMPTY_EFFECT_AMOUNT
        end
      end
    end
  end
  
  -- Write the values
  local write_line = current_line
  local last_value = -1
  
  for i = 1, #values do
    if write_line <= phrase.number_of_lines then
      if sub_column_type == 3 then -- Volume
        local note_column = phrase:line(write_line):note_column(selected_note_column or 1)
        note_column.volume_value = values[i]
        last_value = values[i]
      elseif sub_column_type == 4 then -- Panning
        local note_column = phrase:line(write_line):note_column(selected_note_column or 1)
        note_column.panning_value = values[i]
        last_value = values[i]
      elseif sub_column_type == 5 then -- Delay
        local note_column = phrase:line(write_line):note_column(selected_note_column or 1)
        note_column.delay_value = values[i]
        last_value = values[i]
      elseif sub_column_type == 7 then -- Sample Effect Amount
        local note_column = phrase:line(write_line):note_column(selected_note_column or 1)
        note_column.effect_amount_value = values[i]
        last_value = values[i]
      elseif sub_column_type == 9 then -- Effect Amount
        local effect_column_index = song.selected_phrase_effect_column_index
        if effect_column_index > 0 then
          local effect_column = phrase:line(write_line):effect_column(effect_column_index)
          effect_column.amount_value = values[i]
          last_value = values[i]
        end
      end
      
      if use_editstep then
        write_line = write_line + edit_step
      else
        write_line = write_line + 1
      end
    else
      break
    end
  end
  
  if last_value ~= -1 then
    local hex_value = string.format("%02X", last_value)
    renoise.app():show_status(string.format(
      "Wrote %s %s values until row %d (last: %s/%d)", 
      method,
      column_name,
      write_line - (use_editstep and edit_step or 1),
      hex_value,
      last_value
    ))
  end
end

-- Wrapper functions for different modes
function PakettiPhraseEditorSubColumnWriteRandom()
  PakettiPhraseEditorSubColumnWriteValues("random", false)
end

function PakettiPhraseEditorSubColumnWriteRandomEditStep()
  PakettiPhraseEditorSubColumnWriteValues("random", true)
end

function PakettiPhraseEditorSubColumnWriteAscending()
  PakettiPhraseEditorSubColumnWriteValues("ascending", false)
end

function PakettiPhraseEditorSubColumnWriteAscendingEditStep()
  PakettiPhraseEditorSubColumnWriteValues("ascending", true)
end

function PakettiPhraseEditorSubColumnWriteDescending()
  PakettiPhraseEditorSubColumnWriteValues("descending", false)
end

function PakettiPhraseEditorSubColumnWriteDescendingEditStep()
  PakettiPhraseEditorSubColumnWriteValues("descending", true)
end

-- WAITING FOR API UPDATE: Uncomment these keybindings when Phrase Editor gets sub-column detection API
-- Add keybindings for intelligent write system in Phrase Editor
-- These adapt to whatever subcolumn you're in
--renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Write Values/Notes Random (SubColumn Aware)", invoke=PakettiPhraseEditorSubColumnWriteRandom}
--renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Write Values/Notes Random EditStep (SubColumn Aware)", invoke=PakettiPhraseEditorSubColumnWriteRandomEditStep}
--renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Write Values/Notes Ascending (SubColumn Aware)", invoke=PakettiPhraseEditorSubColumnWriteAscending}
--renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Write Values/Notes Ascending EditStep (SubColumn Aware)", invoke=PakettiPhraseEditorSubColumnWriteAscendingEditStep}
--renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Write Values/Notes Descending (SubColumn Aware)", invoke=PakettiPhraseEditorSubColumnWriteDescending}
--renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Write Values/Notes Descending EditStep (SubColumn Aware)", invoke=PakettiPhraseEditorSubColumnWriteDescendingEditStep}

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
  if not song then
    return
  end
  
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
  if not song then
    return nil
  end
  
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

---------------------------------------------------------------------------------------------------------
-- Nudge by Delay or Row for Phrase Editor (works on selection or current cell)
---------------------------------------------------------------------------------------------------------
function PakettiPhraseEditorNudgeHelperSelectCurrentCell()
  local song=renoise.song()
  if not song then
    return false
  end
  
  local phrase = song.selected_phrase
  
  if not phrase then
    return false
  end
  
  local selected_line = song.selected_phrase_line_index
  local selected_note_column = song.selected_phrase_note_column_index
  local selected_effect_column = song.selected_phrase_effect_column_index
  
  local column_index
  if selected_note_column > 0 then
    column_index = selected_note_column
  elseif selected_effect_column > 0 then
    column_index = phrase.visible_note_columns + selected_effect_column
  else
    column_index = 1
  end
  
  song.selection_in_phrase = {
    start_line = selected_line,
    end_line = selected_line,
    start_column = column_index,
    end_column = column_index
  }
  
  return true
end

function PakettiPhraseEditorNudgeClearSelection()
  local s=renoise.song()
  if not s then
    return
  end
  
  s.selection_in_phrase = nil
end

function PakettiPhraseEditorNudgeMoveEditCursorUp()
  local song=renoise.song()
  if not song then
    return
  end
  
  local phrase = song.selected_phrase
  if not phrase then
    return
  end
  
  local current_line = song.selected_phrase_line_index
  if current_line > 1 then
    song.selected_phrase_line_index = current_line - 1
  end
end

function PakettiPhraseEditorNudgeMoveEditCursorDown()
  local song=renoise.song()
  if not song then
    return
  end
  
  local phrase = song.selected_phrase
  if not phrase then
    return
  end
  
  local current_line = song.selected_phrase_line_index
  if current_line < phrase.number_of_lines then
    song.selected_phrase_line_index = current_line + 1
  end
end

function PakettiPhraseEditorNudgeGetSelectionInfo()
  local song=renoise.song()
  if not song then
    return nil
  end
  
  local phrase = song.selected_phrase
  local selection = song.selection_in_phrase
  
  if not phrase or not selection then
    return nil
  end
  
  local result = {
    start_line = selection.start_line,
    end_line = selection.end_line,
    start_column = selection.start_column,
    end_column = selection.end_column,
    note_columns = {},
    effect_columns = {}
  }
  
  local visible_note_columns = phrase.visible_note_columns
  local visible_effect_columns = phrase.visible_effect_columns
  
  for col_idx = selection.start_column, selection.end_column do
    if col_idx <= visible_note_columns then
      table.insert(result.note_columns, col_idx)
    else
      local effect_col = col_idx - visible_note_columns
      if effect_col <= visible_effect_columns then
        table.insert(result.effect_columns, effect_col)
      end
    end
  end
  
  return result
end

function PakettiPhraseEditorNudgeByDelay(steps)
  local song=renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  
  local using_edit_cursor = false
  
  if not song.selection_in_phrase then
    if song.selected_phrase_effect_column_index ~= 0 then
      renoise.app():show_status("Cannot nudge effect columns by delay")
      return
    elseif song.selected_phrase_note_column_index ~= 0 then
      if not PakettiPhraseEditorNudgeHelperSelectCurrentCell() then
        return
      end
      using_edit_cursor = true
    else
      return
    end
  end
  
  local selection_info = PakettiPhraseEditorNudgeGetSelectionInfo()
  if not selection_info then
    return
  end
  
  if #selection_info.effect_columns > 0 then
    renoise.app():show_status("Cannot nudge effect columns by delay")
    return
  end
  
  local column_entry_moved_to_new_line = false
  local something_was_nudged = false
  local is_single_cell = (selection_info.start_line == selection_info.end_line)
  
  phrase.delay_column_visible = true
  
  for _, col_idx in ipairs(selection_info.note_columns) do
    if steps > 0 then
      for line_idx = selection_info.end_line, selection_info.start_line, -1 do
        local line = phrase:line(line_idx)
        local note_column = line:note_column(col_idx)
        
        if not note_column.is_empty then
          local current_delay = note_column.delay_value
          local new_delay = current_delay + steps
          
          if new_delay > 255 then
            local next_line_idx = line_idx + 1
            if is_single_cell then
              if next_line_idx > phrase.number_of_lines then
                next_line_idx = 1
              end
            else
              if next_line_idx > selection_info.end_line then
                next_line_idx = selection_info.start_line
              end
            end
            
            local next_line = phrase:line(next_line_idx)
            local next_note_column = next_line:note_column(col_idx)
            
            if next_note_column.is_empty and next_note_column.delay_value == 0 then
              next_note_column:copy_from(note_column)
              next_note_column.delay_value = new_delay - 256
              note_column:clear()
              column_entry_moved_to_new_line = true
              something_was_nudged = true
            else
              note_column.delay_value = 255
              something_was_nudged = true
            end
          else
            note_column.delay_value = new_delay
            something_was_nudged = true
          end
        end
      end
    else
      for line_idx = selection_info.start_line, selection_info.end_line do
        local line = phrase:line(line_idx)
        local note_column = line:note_column(col_idx)
        
        if not note_column.is_empty then
          local current_delay = note_column.delay_value
          local new_delay = current_delay + steps
          
          if new_delay < 0 then
            local prev_line_idx = line_idx - 1
            if is_single_cell then
              if prev_line_idx < 1 then
                prev_line_idx = phrase.number_of_lines
              end
            else
              if prev_line_idx < selection_info.start_line then
                prev_line_idx = selection_info.end_line
              end
            end
            
            local prev_line = phrase:line(prev_line_idx)
            local prev_note_column = prev_line:note_column(col_idx)
            
            if prev_note_column.is_empty and prev_note_column.delay_value == 0 then
              prev_note_column:copy_from(note_column)
              prev_note_column.delay_value = new_delay + 256
              note_column:clear()
              column_entry_moved_to_new_line = true
              something_was_nudged = true
            else
              note_column.delay_value = 0
              something_was_nudged = true
            end
          else
            note_column.delay_value = new_delay
            something_was_nudged = true
          end
        end
      end
    end
  end
  
  if using_edit_cursor then
    PakettiPhraseEditorNudgeClearSelection()
    if column_entry_moved_to_new_line then
      if is_single_cell then
        if steps > 0 then
          local target_line = selection_info.start_line + 1
          if target_line > phrase.number_of_lines then
            song.selected_phrase_line_index = 1
          else
            song.selected_phrase_line_index = target_line
          end
        else
          local target_line = selection_info.start_line - 1
          if target_line < 1 then
            song.selected_phrase_line_index = phrase.number_of_lines
          else
            song.selected_phrase_line_index = target_line
          end
        end
      else
        if steps > 0 then
          PakettiPhraseEditorNudgeMoveEditCursorDown()
        else
          PakettiPhraseEditorNudgeMoveEditCursorUp()
        end
      end
    end
  end
  
  if something_was_nudged then
    local direction = (steps > 0) and "down" or "up"
    renoise.app():show_status(string.format("Nudged %s by delay", direction))
  end
end

function PakettiPhraseEditorNudgeByRow(direction)
  local song=renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  
  local using_edit_cursor = false
  
  if not song.selection_in_phrase then
    if song.selected_phrase_effect_column_index ~= 0 then
      if not PakettiPhraseEditorNudgeHelperSelectCurrentCell() then
        return
      end
      using_edit_cursor = true
    elseif song.selected_phrase_note_column_index ~= 0 then
      if not PakettiPhraseEditorNudgeHelperSelectCurrentCell() then
        return
      end
      using_edit_cursor = true
    else
      return
    end
  end
  
  local selection_info = PakettiPhraseEditorNudgeGetSelectionInfo()
  if not selection_info then
    return
  end
  
  local column_entry_moved = false
  local is_single_cell = (selection_info.start_line == selection_info.end_line)
  
  for _, col_idx in ipairs(selection_info.note_columns) do
    if is_single_cell then
      -- Single cell: calculate target and handle wrapping
      local source_idx = selection_info.start_line
      local target_idx = source_idx + direction
      local did_wrap = false
      
      if target_idx > phrase.number_of_lines then
        target_idx = 1
        did_wrap = true
      elseif target_idx < 1 then
        target_idx = phrase.number_of_lines
        did_wrap = true
      end
      
      local source_col = phrase:line(source_idx):note_column(col_idx)
      local target_col = phrase:line(target_idx):note_column(col_idx)
      
      -- Only move if source has content AND target is empty
      if not source_col.is_empty and target_col.is_empty then
        target_col:copy_from(source_col)
        source_col:clear()
        column_entry_moved = true
      end
    else
      -- Multi-row selection: use store-shift-place algorithm
      if direction > 0 then
        -- Nudge DOWN: Store last row, shift everything down, place stored at first row
        local stored_line = phrase:line(selection_info.end_line):note_column(col_idx)
        local temp_note = {}
        local has_stored_content = not stored_line.is_empty
        
        if has_stored_content then
          temp_note.note_value = stored_line.note_value
          temp_note.instrument_value = stored_line.instrument_value
          temp_note.volume_value = stored_line.volume_value
          temp_note.panning_value = stored_line.panning_value
          temp_note.delay_value = stored_line.delay_value
          temp_note.effect_number_value = stored_line.effect_number_value
          temp_note.effect_amount_value = stored_line.effect_amount_value
        end
        
        -- Shift all rows down (from end to start)
        for line_idx = selection_info.end_line, selection_info.start_line + 1, -1 do
          local curr_line = phrase:line(line_idx)
          local prev_line = phrase:line(line_idx - 1)
          curr_line:note_column(col_idx):copy_from(prev_line:note_column(col_idx))
          if not prev_line:note_column(col_idx).is_empty then
            column_entry_moved = true
          end
        end
        
        -- Clear and place stored content at wrap destination
        local target_line = phrase:line(selection_info.start_line)
        local target_col = target_line:note_column(col_idx)
        target_col:clear()
        if has_stored_content then
          target_col.note_value = temp_note.note_value
          target_col.instrument_value = temp_note.instrument_value
          target_col.volume_value = temp_note.volume_value
          target_col.panning_value = temp_note.panning_value
          target_col.delay_value = temp_note.delay_value
          target_col.effect_number_value = temp_note.effect_number_value
          target_col.effect_amount_value = temp_note.effect_amount_value
          column_entry_moved = true
        end
      else
        -- Nudge UP: Store first row, shift everything up, place stored at last row
        local stored_line = phrase:line(selection_info.start_line):note_column(col_idx)
        local temp_note = {}
        local has_stored_content = not stored_line.is_empty
        
        if has_stored_content then
          temp_note.note_value = stored_line.note_value
          temp_note.instrument_value = stored_line.instrument_value
          temp_note.volume_value = stored_line.volume_value
          temp_note.panning_value = stored_line.panning_value
          temp_note.delay_value = stored_line.delay_value
          temp_note.effect_number_value = stored_line.effect_number_value
          temp_note.effect_amount_value = stored_line.effect_amount_value
        end
        
        -- Shift all rows up (from start to end)
        for line_idx = selection_info.start_line, selection_info.end_line - 1 do
          local curr_line = phrase:line(line_idx)
          local next_line = phrase:line(line_idx + 1)
          curr_line:note_column(col_idx):copy_from(next_line:note_column(col_idx))
          if not next_line:note_column(col_idx).is_empty then
            column_entry_moved = true
          end
        end
        
        -- Clear and place stored content at wrap destination
        local target_line = phrase:line(selection_info.end_line)
        local target_col = target_line:note_column(col_idx)
        target_col:clear()
        if has_stored_content then
          target_col.note_value = temp_note.note_value
          target_col.instrument_value = temp_note.instrument_value
          target_col.volume_value = temp_note.volume_value
          target_col.panning_value = temp_note.panning_value
          target_col.delay_value = temp_note.delay_value
          target_col.effect_number_value = temp_note.effect_number_value
          target_col.effect_amount_value = temp_note.effect_amount_value
          column_entry_moved = true
        end
      end
    end
  end
  
  for _, col_idx in ipairs(selection_info.effect_columns) do
    if is_single_cell then
      -- Single cell: calculate target and handle wrapping
      local source_idx = selection_info.start_line
      local target_idx = source_idx + direction
      local did_wrap = false
      
      if target_idx > phrase.number_of_lines then
        target_idx = 1
        did_wrap = true
      elseif target_idx < 1 then
        target_idx = phrase.number_of_lines
        did_wrap = true
      end
      
      local source_col = phrase:line(source_idx):effect_column(col_idx)
      local target_col = phrase:line(target_idx):effect_column(col_idx)
      
      -- Only move if source has content AND target is empty
      if not source_col.is_empty and target_col.is_empty then
        target_col:copy_from(source_col)
        source_col:clear()
        column_entry_moved = true
      end
    else
      -- Multi-row selection: use store-shift-place algorithm
      if direction > 0 then
        -- Nudge DOWN: Store last row, shift everything down, place stored at first row
        local stored_line = phrase:line(selection_info.end_line):effect_column(col_idx)
        local temp_effect = {}
        local has_stored_content = not stored_line.is_empty
        
        if has_stored_content then
          temp_effect.number_value = stored_line.number_value
          temp_effect.amount_value = stored_line.amount_value
        end
        
        -- Shift all rows down (from end to start)
        for line_idx = selection_info.end_line, selection_info.start_line + 1, -1 do
          local curr_line = phrase:line(line_idx)
          local prev_line = phrase:line(line_idx - 1)
          curr_line:effect_column(col_idx):copy_from(prev_line:effect_column(col_idx))
          if not prev_line:effect_column(col_idx).is_empty then
            column_entry_moved = true
          end
        end
        
        -- Clear and place stored content at wrap destination
        local target_line = phrase:line(selection_info.start_line)
        local target_col = target_line:effect_column(col_idx)
        target_col:clear()
        if has_stored_content then
          target_col.number_value = temp_effect.number_value
          target_col.amount_value = temp_effect.amount_value
          column_entry_moved = true
        end
      else
        -- Nudge UP: Store first row, shift everything up, place stored at last row
        local stored_line = phrase:line(selection_info.start_line):effect_column(col_idx)
        local temp_effect = {}
        local has_stored_content = not stored_line.is_empty
        
        if has_stored_content then
          temp_effect.number_value = stored_line.number_value
          temp_effect.amount_value = stored_line.amount_value
        end
        
        -- Shift all rows up (from start to end)
        for line_idx = selection_info.start_line, selection_info.end_line - 1 do
          local curr_line = phrase:line(line_idx)
          local next_line = phrase:line(line_idx + 1)
          curr_line:effect_column(col_idx):copy_from(next_line:effect_column(col_idx))
          if not next_line:effect_column(col_idx).is_empty then
            column_entry_moved = true
          end
        end
        
        -- Clear and place stored content at wrap destination
        local target_line = phrase:line(selection_info.end_line)
        local target_col = target_line:effect_column(col_idx)
        target_col:clear()
        if has_stored_content then
          target_col.number_value = temp_effect.number_value
          target_col.amount_value = temp_effect.amount_value
          column_entry_moved = true
        end
      end
    end
  end
  
  if using_edit_cursor then
    PakettiPhraseEditorNudgeClearSelection()
    if column_entry_moved then
      if is_single_cell then
        if direction > 0 then
          local target_line = selection_info.start_line + 1
          if target_line > phrase.number_of_lines then
            song.selected_phrase_line_index = 1
          else
            song.selected_phrase_line_index = target_line
          end
        else
          local target_line = selection_info.start_line - 1
          if target_line < 1 then
            song.selected_phrase_line_index = phrase.number_of_lines
          else
            song.selected_phrase_line_index = target_line
          end
        end
      else
        if direction > 0 then
          PakettiPhraseEditorNudgeMoveEditCursorDown()
        else
          PakettiPhraseEditorNudgeMoveEditCursorUp()
        end
      end
    end
  end
  
  if column_entry_moved then
    local dir_text = (direction > 0) and "down" or "up"
    renoise.app():show_status(string.format("Nudged %s by row", dir_text))
  end
end

if renoise.API_VERSION >= 6.2 then
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge Up by Delay",invoke=function() PakettiPhraseEditorNudgeByDelay(-1) end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge Down by Delay",invoke=function() PakettiPhraseEditorNudgeByDelay(1) end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge Up by Row",invoke=function() PakettiPhraseEditorNudgeByRow(-1) end}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge Down by Row",invoke=function() PakettiPhraseEditorNudgeByRow(1) end}
end

--------------------------------------------------------------------------------
-- Nudge and Move Selection for Phrase Editor
--------------------------------------------------------------------------------

-- Helper function to check if a line has any data in the specified columns
function PakettiPhraseEditorNudgeAndMoveCheckLineForData(phrase, line_index, note_columns, effect_columns)
  local line = phrase:line(line_index)
  
  -- Check selected note columns
  for _, col_idx in ipairs(note_columns) do
    local note_col = line:note_column(col_idx)
    if not note_col.is_empty then
      return true
    end
  end
  
  -- Check selected effect columns
  for _, col_idx in ipairs(effect_columns) do
    local effect_col = line:effect_column(col_idx)
    if not effect_col.is_empty then
      return true
    end
  end
  
  return false
end

-- Main function to perform nudge and move selection in phrase editor
function PakettiPhraseEditorNudgeAndMoveSelection(direction)
  local song = renoise.song()
  local phrase = song.selected_phrase
  
  if not phrase then
    renoise.app():show_status("No phrase selected, doing nothing.")
    return
  end
  
  local selection = song.selection_in_phrase
  
  if not selection then
    renoise.app():show_status("No selection in phrase, doing nothing.")
    return
  end
  
  -- Get selection details using PakettiPhraseEditorSelectionInfo
  local selection_info = PakettiPhraseEditorSelectionInfo()
  if not selection_info then
    renoise.app():show_status("Please select a range before running this function.")
    return
  end
  
  local start_line = selection.start_line
  local end_line = selection.end_line
  local num_lines = end_line - start_line + 1
  
  -- Calculate new selection range
  local new_start_line = start_line + direction
  local new_end_line = end_line + direction
  
  -- Check bounds
  if new_start_line < 1 then
    renoise.app():show_status("Cannot move beyond beginning of phrase, doing nothing.")
    return
  end
  
  if new_end_line > phrase.number_of_lines then
    renoise.app():show_status("Cannot move beyond end of phrase, doing nothing.")
    return
  end
  
  -- Check for data collision in the destination area
  -- We only need to check the NEW line that wasn't part of the selection before
  local check_line = nil
  if direction < 0 then
    -- Moving up: check line above current selection
    check_line = new_start_line
  else
    -- Moving down: check line below current selection
    check_line = new_end_line
  end
  
  -- Check for collisions in the destination line
  if PakettiPhraseEditorNudgeAndMoveCheckLineForData(
    phrase, 
    check_line,
    selection_info.note_columns,
    selection_info.effect_columns
  ) then
    renoise.app():show_status("This nudge and move would result in a data collision, doing nothing.")
    return
  end
  
  -- All checks passed, perform the move
  -- We need to copy in the right order to avoid overwriting data
  if direction < 0 then
    -- Moving up: copy from top to bottom
    for line_offset = 0, num_lines - 1 do
      local src_line = start_line + line_offset
      local dst_line = new_start_line + line_offset
      
      local src = phrase:line(src_line)
      local dst = phrase:line(dst_line)
      
      -- Copy selected note columns
      for _, col_idx in ipairs(selection_info.note_columns) do
        dst:note_column(col_idx):copy_from(src:note_column(col_idx))
      end
      
      -- Copy selected effect columns
      for _, col_idx in ipairs(selection_info.effect_columns) do
        dst:effect_column(col_idx):copy_from(src:effect_column(col_idx))
      end
    end
    
    -- Clear the old line at the bottom that's no longer part of selection
    local clear_line = phrase:line(end_line)
    
    for _, col_idx in ipairs(selection_info.note_columns) do
      clear_line:note_column(col_idx):clear()
    end
    
    for _, col_idx in ipairs(selection_info.effect_columns) do
      clear_line:effect_column(col_idx):clear()
    end
  else
    -- Moving down: copy from bottom to top
    for line_offset = num_lines - 1, 0, -1 do
      local src_line = start_line + line_offset
      local dst_line = new_start_line + line_offset
      
      local src = phrase:line(src_line)
      local dst = phrase:line(dst_line)
      
      -- Copy selected note columns
      for _, col_idx in ipairs(selection_info.note_columns) do
        dst:note_column(col_idx):copy_from(src:note_column(col_idx))
      end
      
      -- Copy selected effect columns
      for _, col_idx in ipairs(selection_info.effect_columns) do
        dst:effect_column(col_idx):copy_from(src:effect_column(col_idx))
      end
    end
    
    -- Clear the old line at the top that's no longer part of selection
    local clear_line = phrase:line(start_line)
    
    for _, col_idx in ipairs(selection_info.note_columns) do
      clear_line:note_column(col_idx):clear()
    end
    
    for _, col_idx in ipairs(selection_info.effect_columns) do
      clear_line:effect_column(col_idx):clear()
    end
  end
  
  -- Update the selection to the new range
  song.selection_in_phrase = {
    start_line = new_start_line,
    start_column = selection.start_column,
    end_line = new_end_line,
    end_column = selection.end_column
  }
  
  -- Move cursor to maintain relative position within selection
  local cursor_line = song.selected_phrase_line_index
  if cursor_line >= start_line and cursor_line <= end_line then
    song.selected_phrase_line_index = cursor_line + direction
  end
  
  renoise.app():show_status(string.format("Nudged and moved selection %s", direction < 0 and "up" or "down"))
end

-- Wrapper functions for up/down
function PakettiPhraseEditorNudgeAndMoveSelectionUp()
  PakettiPhraseEditorNudgeAndMoveSelection(-1)
end

function PakettiPhraseEditorNudgeAndMoveSelectionDown()
  PakettiPhraseEditorNudgeAndMoveSelection(1)
end

-- Add keybindings
if renoise.API_VERSION >= 6.2 then
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge and Move Selection Up", invoke=PakettiPhraseEditorNudgeAndMoveSelectionUp}
  renoise.tool():add_keybinding{name="Phrase Editor:Paketti:Nudge and Move Selection Down", invoke=PakettiPhraseEditorNudgeAndMoveSelectionDown}
  renoise.tool():add_midi_mapping{name="Paketti:Phrase Editor Nudge and Move Selection Up", invoke=function(message) if message:is_trigger() then PakettiPhraseEditorNudgeAndMoveSelectionUp() end end}
  renoise.tool():add_midi_mapping{name="Paketti:Phrase Editor Nudge and Move Selection Down", invoke=function(message) if message:is_trigger() then PakettiPhraseEditorNudgeAndMoveSelectionDown() end end}
end