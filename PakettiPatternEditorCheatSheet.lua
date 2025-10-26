-- Paketti Pattern Effect Command CheatSheet
local dialog = nil
local preferences = renoise.tool().preferences
-- Load and Save Preferences Functions
function load_Cheatsheetpreferences()
  if io.exists("preferences.xml") then
    preferences:load_from("preferences.xml")
  end
end

function save_Cheatsheetpreferences()
  preferences:save_as("preferences.xml")
  renoise.app():show_status("CheatSheet preferences saved")
end

function Cheatsheetclear_effect_columns()
  local s = renoise.song()
  
  if s.selection_in_pattern then
    -- Clear selection
    for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
      local track = s:track(t)
      local note_columns_visible = track.visible_note_columns
      local effect_columns_visible = track.visible_effect_columns
      local total_columns_visible = note_columns_visible + effect_columns_visible
      
      local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or note_columns_visible + 1
      local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or total_columns_visible
      
      for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
        for col = start_column, end_column do
          local column_index = col - note_columns_visible
          if column_index > 0 and column_index <= effect_columns_visible then
            local effect_column = s:pattern(s.selected_pattern_index):track(t):line(i):effect_column(column_index)
            if effect_column then
              effect_column:clear()
            end
          end
        end
      end
    end
  else
    -- Clear current effect column
    if s.selected_effect_column then
      s.selected_effect_column:clear()
    end
  end
  
  renoise.app():show_status("Effect columns cleared")
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end


-- Complete list of effects
local effects = {
  {"0A", "-Axy", "Set arpeggio, x/y = first/second note offset in semitones"},
  {"0U", "-Uxx", "Slide Pitch up by xx 1/16ths of a semitone"},
  {"0D", "-Dxx", "Slide Pitch down by xx 1/16ths of a semitone"},
  {"0G", "-Gxx", "Glide towards given note by xx 1/16ths of a semitone"},
  {"0I", "-Ixx", "Fade Volume in by xx volume units"},
  {"0O", "-Oxx", "Fade Volume out by xx volume units"},
  {"0C", "-Cxy", "Cut volume to x after y ticks (x = volume factor: 0=0%, F=100%)"},
  {"0Q", "-Qxx", "Delay note by xx ticks"},
  {"0M", "-Mxx", "Set note volume to xx"},
  {"0S", "-Sxx", "Trigger sample slice number xx or offset xx"},
  {"0B", "-Bxx", "Play Sample Backwards (B00) or forwards again (B01)"},
  {"0R", "-Rxy", "Retrigger line every y ticks with volume factor x"},
  {"0Y", "-Yxx", "Maybe trigger line with probability xx, 00 = mutually exclusive note columns"},
  {"0Z", "-Zxx", "Trigger Phrase xx (Phrase Number (01-7E), 00 = none, 7F = keymap)"},
  {"0V", "-Vxy", "Set Vibrato x = speed, y = depth; x=(0-F); y=(0-F)"},
  {"0T", "-Txy", "Set Tremolo x = speed, y = depth"},
  {"0N", "-Nxy", "Set Auto Pan, x = speed, y = depth"},
  {"0E", "-Exx", "Set Active Sample Envelope's Position to Offset XX"},
  {"0L", "-Lxx", "Set Track Volume Level, 00 = -INF, FF = +3dB"},
  {"0P", "-Pxx", "Set Track Pan, 00 = full left, 80 = center, FF = full right"},
  {"0W", "-Wxx", "Set Track Surround Width, 00 = Min, FF = Max"},
  {"0J", "-Jxx", "Set Track Routing, 01 upwards = hardware channels, FF downwards = parent groups"},
  {"0X", "-Xxx", "Stop all notes and FX (xx = 00), or only effect xx (xx > 00)"},
  {"ZT", "ZTxx", "Set tempo to xx BPM (14-FF, 00 = stop song)"},
  {"ZL", "ZLxx", "Set Lines Per Beat (LPB) to xx lines"},
  {"ZK", "ZKxx", "Set Ticks Per Line (TPL) to xx ticks (01-10)"},
  {"ZG", "ZGxx", "Enable (xx = 01) or disable (xx = 00) Groove"},
  {"ZB", "ZBxx", "Break pattern and jump to line xx in next"},
  {"ZD", "ZDxx", "Delay (pause) pattern for xx lines"}
}


-- Randomization Functions for Effect Columns

function randomizeSmatterEffectColumnCustom(effect_command, fill_percentage, min_value, max_value)
  trueRandomSeed()

  local song=renoise.song()
  local selection = song.selection_in_pattern
  local randomize_switch = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeSwitch.value
  local dont_overwrite = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeDontOverwrite.value
  local only_modify_effects = preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyEffects.value
  local only_modify_notes = preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyNotes.value
  local randomize_whole_track_cb = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeWholeTrack.value

  if min_value > max_value then
    min_value, max_value = max_value, min_value
  end

  -- Check for slice markers if this is a 0S command
  if effect_command == "0S" then
    local instrument = song.selected_instrument
    if instrument and instrument.samples[1] and #instrument.samples[1].slice_markers > 0 then
      -- Adjust range to start from 01 for slices
      min_value = 1
      max_value = #instrument.samples[1].slice_markers
    end
  end

  local randomize = function()
    if randomize_switch then
      return string.format("%02X", math.random() < 0.5 and min_value or max_value)
    else
      return string.format("%02X", math.random(min_value, max_value))
    end
  end

  local should_apply = function()
    return math.random(100) <= fill_percentage
  end

  local has_notes_in_line = function(track, line_index, track_index)
    local song=renoise.song()
    local line = track:line(line_index)
    local visible_columns = song:track(track_index).visible_note_columns
    for i = 1, visible_columns do
      local note_column = line.note_columns[i]
      -- Only check for actual notes (not empty and not NOTE_OFF)
      if note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE and 
         note_column.note_string ~= "OFF" then
        return true
      end
    end
    return false
  end

  local apply_command = function(line, column_index, track, line_index, track_index)
    local effect_column = line:effect_column(column_index)
    if effect_column then
      if only_modify_notes then
        if has_notes_in_line(track, line_index, track_index) and should_apply() then
          effect_column.number_string = effect_command
          effect_column.amount_string = randomize()
        end
      elseif dont_overwrite then
        if effect_column.is_empty and should_apply() then
          effect_column.number_string = effect_command
          effect_column.amount_string = randomize()
        end
      elseif only_modify_effects then
        if not effect_column.is_empty and should_apply() then
          effect_column.number_string = effect_command
          effect_column.amount_string = randomize()
        end
      else
        if should_apply() then
          effect_column.number_string = effect_command
          effect_column.amount_string = randomize()
        else
          effect_column:clear()
        end
      end
    end
  end

  if selection then
    -- Apply to selection
    for line_index = selection.start_line, selection.end_line do
      for t = selection.start_track, selection.end_track do
        local track = song:pattern(song.selected_pattern_index):track(t)
        local trackvis = song:track(t)
        local note_columns_visible = trackvis.visible_note_columns
        local effect_columns_visible = trackvis.visible_effect_columns
        local total_columns_visible = note_columns_visible + effect_columns_visible

        local start_column = (t == selection.start_track) and selection.start_column or 1
        local end_column = (t == selection.end_track) and selection.end_column or total_columns_visible

        for col = start_column, end_column do
          local column_index = col - note_columns_visible
          if col > note_columns_visible and column_index > 0 and column_index <= effect_columns_visible then
            apply_command(track:line(line_index), column_index, track, line_index, t)
          end
        end
      end
    end
  else
    if randomize_whole_track_cb then
      -- Apply to whole track
      local track_index = song.selected_track_index
      for pattern_index = 1, #song.patterns do
        local pattern = song:pattern(pattern_index)
        local track = pattern:track(track_index)
        local lines = pattern.number_of_lines
        for line_index = 1, lines do
          for column_index = 1, song:track(track_index).visible_effect_columns do
            apply_command(track:line(line_index), column_index, track, line_index, track_index)
          end
        end
      end
    else
      -- Apply to current line
      local line = song.selected_line
      local track_index = song.selected_track_index
      local track = song:pattern(song.selected_pattern_index):track(track_index)
      for column_index = 1, song.selected_track.visible_effect_columns do
        apply_command(line, column_index, track, song.selected_line_index, track_index)
      end
    end
  end

  renoise.app():show_status("Random " .. effect_command .. " commands applied to effect columns.")
end

function randomizeSmatterEffectColumnC0(fill_percentage)
  randomizeSmatterEffectColumnCustom("0C", fill_percentage, 0x00, 0x0F)
end

function randomizeSmatterEffectColumnB0(fill_percentage)
  randomizeSmatterEffectColumnCustom("0B", fill_percentage, 0x00, 0x01)
end


-- Function to ensure visibility of specific columns (volume, panning, delay, samplefx)
function sliderVisible(column)
  local s = renoise.song()
  if s.selection_in_pattern then
    for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
      local track = s:track(t)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        if column == "volume" then
          track.volume_column_visible = true
        elseif column == "panning" then
          track.panning_column_visible = true
        elseif column == "delay" then
          track.delay_column_visible = true
        elseif column == "samplefx" then
          track.sample_effects_column_visible = true
        end
      end
    end
  else
    local track = s.selected_track
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      if column == "volume" then
        track.volume_column_visible = true
      elseif column == "panning" then
        track.panning_column_visible = true
      elseif column == "delay" then
        track.delay_column_visible = true
      elseif column == "samplefx" then
        track.sample_effects_column_visible = true
      end
    end
  end
end

-- Function to ensure effect columns are visible
function sliderVisibleEffect()
  local s = renoise.song()
  if s.selection_in_pattern then
    for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
      local track = s:track(t)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        track.visible_effect_columns = math.max(track.visible_effect_columns, 1)
      end
    end
  else
    local track = s.selected_track
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      track.visible_effect_columns = math.max(track.visible_effect_columns, 1)
    end
  end
end

-- Randomize functions for note columns
function randomizeNoteColumn(column_name)
    if (column_name == "volume_value" or column_name == "panning_value" or column_name == "effect_amount_value") 
      and preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMax.value > 0x80 then
      renoise.app():show_status("Warning: Values above 0x80 cannot be set for Volume or Panning")
      return
    end

  local s = renoise.song()
  local min_value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMin.value
  local max_value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMax.value
  local randomize_switch = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeSwitch.value

  if min_value > max_value then
    min_value, max_value = max_value, min_value
  end

  sliderVisible(column_name)
  local column_max_value = 0xFF
  if column_name == "volume_value" or column_name == "panning_value" or column_name == "effect_amount_value" then
    -- Changed from 0x80 to 0xFF to allow full slider range
    column_max_value = 0xFF
  end

  if max_value > column_max_value then
    max_value = column_max_value
  end
  if min_value < 0 then
    min_value = 0
  end

  local randomize_whole_track_cb = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeWholeTrack.value
  local fill_percentage = preferences.pakettiCheatSheet.pakettiCheatSheetFillAll.value
  local should_apply = function()
    return math.random(100) <= fill_percentage
  end

  local random_value = function()
    -- Clamp the values for volume/panning/effect_amount to 0x80 max
    local actual_max = max_value
    if column_name == "volume_value" or column_name == "panning_value" or column_name == "effect_amount_value" then
      actual_max = math.min(max_value, 0x80)
    end
    
    if randomize_switch then
      return math.random() < 0.5 and math.min(min_value, actual_max) or math.min(max_value, actual_max)
    else
      return math.random(min_value, math.min(max_value, actual_max))
    end
  end


  local is_subcolumn_not_empty = function(note_column)
    if column_name == "volume_value" then
      return note_column.volume_value ~= renoise.PatternLine.EMPTY_VOLUME
    elseif column_name == "panning_value" then
      return note_column.panning_value ~= renoise.PatternLine.EMPTY_PANNING
    elseif column_name == "delay_value" then
      return note_column.delay_value ~= renoise.PatternLine.EMPTY_DELAY
    elseif column_name == "effect_amount_value" then
      return note_column.effect_number_value ~= renoise.PatternLine.EMPTY_EFFECT_NUMBER or
             note_column.effect_amount_value ~= renoise.PatternLine.EMPTY_EFFECT_AMOUNT
    else
      return false
    end
  end

  if s.selection_in_pattern then
    -- Iterate over selection
    for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
      local track = s:track(t)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local note_columns_visible = track.visible_note_columns
        local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or 1
        local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or note_columns_visible
        for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
          for col = start_column, end_column do
            if col <= note_columns_visible then
              local note_column = s:pattern(s.selected_pattern_index):track(t):line(i).note_columns[col]
              if note_column and is_subcolumn_not_empty(note_column) and should_apply() then
                note_column[column_name] = random_value()
              end
            end
          end
        end
      end
    end
  else
    if not randomize_whole_track_cb then
      -- Randomize current line
      local note_column = s.selected_line:note_column(s.selected_note_column_index)
      if note_column and is_subcolumn_not_empty(note_column) then
        note_column[column_name] = random_value()
      end
    else
      -- Randomize whole track
      local track_index = s.selected_track_index
      local track = s:track(track_index)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        for pattern_index = 1, #s.patterns do
          local pattern = s:pattern(pattern_index)
          local lines = pattern.number_of_lines
          local note_columns_visible = track.visible_note_columns
          for i = 1, lines do
            for col = 1, note_columns_visible do
              local note_column = pattern:track(track_index):line(i).note_columns[col]
              if note_column and is_subcolumn_not_empty(note_column) and should_apply() then
                note_column[column_name] = random_value()
              end
            end
          end
        end
      end
    end
  end
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

function randomizeEffectAmount()
  local s = renoise.song()
  local min_value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMin.value
  local max_value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMax.value
  local randomize_switch = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeSwitch.value

  if min_value > max_value then
    min_value, max_value = max_value, min_value
  end

  sliderVisibleEffect()

  local randomize_whole_track_cb = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeWholeTrack.value
  local fill_percentage = preferences.pakettiCheatSheet.pakettiCheatSheetFillAll.value
  local should_apply = function()
    return math.random(100) <= fill_percentage
  end

  local random_value = function()
    if randomize_switch then
      return math.random() < 0.5 and min_value or max_value
    else
      return math.random(min_value, max_value)
    end
  end

  if s.selection_in_pattern then
    for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
      local track = s:track(t)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local note_columns_visible = track.visible_note_columns
        local effect_columns_visible = track.visible_effect_columns
        local total_columns_visible = note_columns_visible + effect_columns_visible
        local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or note_columns_visible + 1
        local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or total_columns_visible
        for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
          for col = start_column, end_column do
            local column_index = col - note_columns_visible
            if column_index > 0 and column_index <= effect_columns_visible then
              local effect_column = s:pattern(s.selected_pattern_index):track(t):line(i):effect_column(column_index)
              if effect_column and not effect_column.is_empty and should_apply() then
                effect_column.amount_value = random_value()
              end
            end
          end
        end
      end
    end
  else
    if not randomize_whole_track_cb then
      -- Randomize current line
      local effect_column = s.selected_line:effect_column(s.selected_effect_column_index)
      if effect_column and not effect_column.is_empty then
        effect_column.amount_value = random_value()
      end
    else
      -- Randomize whole track
      local track_index = s.selected_track_index
      local track = s:track(track_index)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        for pattern_index = 1, #s.patterns do
          local pattern = s:pattern(pattern_index)
          local lines = pattern.number_of_lines
          local effect_columns_visible = track.visible_effect_columns
          for i = 1, lines do
            for col = 1, effect_columns_visible do
              local effect_column = pattern:track(track_index):line(i):effect_column(col)
              if effect_column and not effect_column.is_empty and should_apply() then
                effect_column.amount_value = random_value()
              end
            end
          end
        end
      end
    end
  end
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Modified effect_write function with randomization logic

function effect_write(effect, status, command, min_value, max_value)
  local s = renoise.song()
  local a = renoise.app()
  local w = a.window

  -- Retrieve randomization preferences
  local randomize_cb = preferences.pakettiCheatSheet.pakettiCheatSheetRandomize.value
  local fill_percentage = preferences.pakettiCheatSheet.pakettiCheatSheetFillAll.value
  local randomize_whole_track_cb = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeWholeTrack.value
  local randomize_switch = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeSwitch.value
  local dont_overwrite = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeDontOverwrite.value

  min_value = min_value or preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMin.value
  max_value = max_value or preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMax.value

  if min_value > max_value then
    min_value, max_value = max_value, min_value
  end

  -- Check for slice markers if this is a 0S command
  if effect == "0S" then
    local instrument = s.selected_instrument
    if instrument and instrument.samples[1] and #instrument.samples[1].slice_markers > 0 then
      -- Adjust range to start from 01 for slices
      min_value = 1
      max_value = #instrument.samples[1].slice_markers
    end
  end

  local randomize = function()
    if randomize_switch then
      return string.format("%02X", math.random() < 0.5 and min_value or max_value)
    else
      return string.format("%02X", math.random(min_value, max_value))
    end
  end

  local should_apply = function()
    return math.random(100) <= fill_percentage
  end

  if randomize_cb then
    if effect == "0C" then
      status = "Random C00/C0F commands applied to the effect columns."
      randomizeSmatterEffectColumnC0(fill_percentage)
    elseif effect == "0B" then
      status = "Random B00/B01 commands applied to the effect columns."
      randomizeSmatterEffectColumnB0(fill_percentage)
    else
      status = "Random " .. effect .. " commands applied to the effect columns."
      randomizeSmatterEffectColumnCustom(effect, fill_percentage, min_value, max_value)
    end
  else
    -- Original logic without randomization
    if s.selection_in_pattern == nil then
      local ec = s.selected_effect_column
      if ec then
        ec.number_string = effect
      else
        return false
      end
    else
      for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
        local track = s:track(t)
        local note_columns_visible = track.visible_note_columns
        local effect_columns_visible = track.visible_effect_columns
        local total_columns_visible = note_columns_visible + effect_columns_visible

        local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or note_columns_visible + 1
        local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or total_columns_visible

        for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
          for col = start_column, end_column do
            local column_index = col - note_columns_visible
            if column_index > 0 and column_index <= effect_columns_visible then
              local effect_column = s:pattern(s.selected_pattern_index):track(t):line(i):effect_column(column_index)
              if effect_column then
                effect_column.number_string = effect
              end
            end
          end
        end
      end
    end
  end
  a:show_status(status)
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- GUI elements
function pakettiPatternEditorCheatsheetDialog()
  local vb = renoise.ViewBuilder()
  local a = renoise.app()
  local s = renoise.song()
  local w = a.window

  if dialog and dialog.visible then
    dialog:close()
    return
  end

  -- Check for slice markers and adjust initial min/max values if needed
  local initial_min = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMin.value
  local initial_max = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMax.value
  
  -- Check if current instrument has slice markers
  local instrument = s.selected_instrument
  if instrument and instrument.samples[1] and #instrument.samples[1].slice_markers > 0 then
    initial_min = 1
    initial_max = #instrument.samples[1].slice_markers
    -- Update preferences
    preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMin.value = initial_min
    preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMax.value = initial_max
  end

  local eSlider = 137 -- Adjusted slider height
  local globalwidth=50

  local wikitooltip = "http://tutorials.renoise.com/wiki/Pattern_Effect_Commands#Effect_Listing"
  local wikibutton = vb:button{
    width=globalwidth,
    text="www",
    tooltip = wikitooltip,
    pressed = function()
      a:open_url(wikitooltip)
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
  }

  local effect_buttons = vb:column{}
  for _, effect in ipairs(effects) do
    local button = vb:button{
      width=globalwidth,
      text = effect[2],
      tooltip = effect[3],
      pressed = function()
        effect_write(effect[1], effect[2] .. " - " .. effect[3], effect[2], effect[4], effect[5])
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end
    }
    local desc = vb:text{text = effect[3]}
    effect_buttons:add_child(vb:row{button, desc})
  end

  -- Randomization Preferences UI Elements
  local randomize_cb = vb:checkbox{
    value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomize.value,
    notifier=function(v)
      preferences.pakettiCheatSheet.pakettiCheatSheetRandomize.value = v
     save_Cheatsheetpreferences()
    end
  }

  local fill_probability_text = vb:text{
    style = "strong",
    text = string.format("%d%% Fill Probability", preferences.pakettiCheatSheet.pakettiCheatSheetFillAll.value)
  }

  local fill_probability_slider = vb:slider{
    width=300,
    min = 0,
    max = 1,
    value = preferences.pakettiCheatSheet.pakettiCheatSheetFillAll.value / 100,
    notifier=function(value)
      local percentage_value = math.floor(value * 100 + 0.5)
      if preferences.pakettiCheatSheet.pakettiCheatSheetFillAll.value ~= percentage_value then
        preferences.pakettiCheatSheet.pakettiCheatSheetFillAll.value = percentage_value
        fill_probability_text.text = string.format("%d%% Fill Probability", percentage_value)
         save_Cheatsheetpreferences()
      end
    end
  }

  local randomize_whole_track_cb = vb:checkbox{
    value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeWholeTrack.value,
    notifier=function(v)
      preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeWholeTrack.value = v
       save_Cheatsheetpreferences()
    end
  }

  local randomizeswitch_cb = vb:checkbox{
    value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeSwitch.value,
    notifier=function(v)
      preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeSwitch.value = v
       save_Cheatsheetpreferences()
    end
  }

  local dontoverwrite_cb = vb:checkbox{
    value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeDontOverwrite.value,
    notifier=function(v)
      preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeDontOverwrite.value = v
       save_Cheatsheetpreferences()
    end
  }

  local only_modify_effects_cb = vb:checkbox{
    value = preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyEffects.value,
    notifier=function(v)
      preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyEffects.value = v
      save_Cheatsheetpreferences()
    end
  }

  local only_modify_notes_cb = vb:checkbox{
    value = preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyNotes.value,
    notifier=function(v)
      preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyNotes.value = v
      save_Cheatsheetpreferences()
    end
  }

  -- Minimum Slider
  local min_value = initial_min

  local min_slider = vb:minislider {
    id = "min_slider_unique",
    width=300,
    min = 0,
    max = 255,
    value = min_value,
    notifier=function(v)
      preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMin.value = v
      vb.views["min_text_unique"].text = string.format("%02X", v)
      save_Cheatsheetpreferences()
    end
  }

  local min_text = vb:text{
    id = "min_text_unique",
    text = string.format("%02X", min_value)
  }

  local min_decrement_button = vb:button{
    text="<",
    notifier=function()
      local current_value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMin.value
      if current_value > 0 then
        current_value = current_value - 1
        min_slider.value = current_value
      end
    end
  }

  local min_increment_button = vb:button{
    text=">",
    notifier=function()
      local current_value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMin.value
      if current_value < 255 then
        current_value = current_value + 1
        min_slider.value = current_value
      end
    end
  }

  -- Maximum Slider
  local max_value = initial_max

  local max_slider = vb:minislider {
    id = "max_slider_unique",
    width=300,
    min = 0,
    max = 255,
    value = max_value,
    notifier=function(v)
      preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMax.value = v
      vb.views["max_text_unique"].text = string.format("%02X", v)
       save_Cheatsheetpreferences()
    end
  }

  local max_text = vb:text{
    id = "max_text_unique",
    text = string.format("%02X", max_value)
  }

  local max_decrement_button = vb:button{
    text="<",
    notifier=function()
      local current_value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMax.value
      if current_value > 0 then
        current_value = current_value - 1
        max_slider.value = current_value
      end
    end
  }

  local max_increment_button = vb:button{
    text=">",
    notifier=function()
      local current_value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMax.value
      if current_value < 255 then
        current_value = current_value + 1
        max_slider.value = current_value
      end
    end
  }

  local randomize_section = vb:column{
    vb:text{style = "strong", text="Randomize Effect Value content"},
    vb:horizontal_aligner{mode = "left", randomize_cb, vb:text{text="Randomize"}},
    vb:horizontal_aligner{mode = "left", fill_probability_slider, fill_probability_text},
    vb:horizontal_aligner{mode = "left", randomize_whole_track_cb, vb:text{text="Randomize whole track if nothing is selected"}},
    vb:horizontal_aligner{mode = "left", randomizeswitch_cb, vb:text{text="Randomize Min/Max Only"}},
    vb:horizontal_aligner{mode = "left", dontoverwrite_cb, vb:text{text="Don't Overwrite Existing Data"}},
    vb:horizontal_aligner{mode = "left", only_modify_effects_cb, vb:text{text="Only Modify Rows With Effects"}},
    vb:horizontal_aligner{mode = "left", only_modify_notes_cb, vb:text{text="Only Modify Rows With Notes"}},
    vb:horizontal_aligner{mode = "left", vb:text{text="Min", font = "mono"}, min_decrement_button, min_increment_button, min_slider, min_text},
    vb:horizontal_aligner{mode = "left", vb:text{text="Max", font = "mono"}, max_decrement_button, max_increment_button, max_slider, max_text},
    vb:button{
      text="Clear Effects",
      tooltip = "Clear all effect columns in selection",
      width=globalwidth,
      pressed = function()
        Cheatsheetclear_effect_columns()
      end
    },
    vb:button{
      text="Minimize Horizontal",
      tooltip = "Open the minimized cheatsheet dialog (horizontal layout)",
      width=globalwidth,
      pressed = function()
        show_mini_cheatsheet()
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end
    },
    vb:button{
      text="Minimize Vertical",
      tooltip = "Open the minimized cheatsheet dialog (vertical layout)",
      width=globalwidth,
      pressed = function()
        show_mini_cheatsheet_vertical()
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end
    },
    vb:button{text="Close",width=globalwidth, pressed = function()
      dialog:close()
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end}
  }

  -- Sliders with Randomize Buttons
  local sliders = vb:column{
    -- Volume
    vb:horizontal_aligner{
      mode = "right",
      vb:text{style = "strong", font = "bold", text="Volume"},
      vb:button{
        text="R",
        tooltip = "Randomize Volume",
        notifier=function()
          randomizeNoteColumn("volume_value")
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:minislider {
        id = "volumeslider",
        width=50,
        height = eSlider,
        min = 0,
        max = 0x80,
        notifier=function(v)
          sliderVisible("volume")
          local s = renoise.song()
          if s.selection_in_pattern then
            for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
              local track = s:track(t)
              if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
                local note_columns_visible = track.visible_note_columns
                local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or 1
                local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or note_columns_visible
                for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
                  for col = start_column, end_column do
                    if col <= note_columns_visible then
                      local note_column = s:pattern(s.selected_pattern_index):track(t):line(i).note_columns[col]
                      if note_column then
                        note_column.volume_value = v
                      end
                    end
                  end
                end
              end
            end
          else
            if s.selected_note_column then
              s.selected_note_column.volume_value = v
            end
          end
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      }
    },
    -- Panning
    vb:horizontal_aligner{
      mode = "right",
      vb:text{style = "strong", font = "bold", text="Panning"},
      vb:button{
        text="R",
        tooltip = "Randomize Panning",
        notifier=function()
          randomizeNoteColumn("panning_value")
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:minislider {
        id = "panningslider",
        width=50,
        height = eSlider,
        min = 0,
        max = 0x80,
        notifier=function(v)
          sliderVisible("panning")
          local s = renoise.song()
          if s.selection_in_pattern then
            for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
              local track = s:track(t)
              if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
                local note_columns_visible = track.visible_note_columns
                local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or 1
                local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or note_columns_visible
                for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
                  for col = start_column, end_column do
                    if col <= note_columns_visible then
                      local note_column = s:pattern(s.selected_pattern_index):track(t):line(i).note_columns[col]
                      if note_column then
                        note_column.panning_value = v
                      end
                    end
                  end
                end
              end
            end
          else
            if s.selected_note_column then
              s.selected_note_column.panning_value = v
            end
          end
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      }
    },
    -- Delay
    vb:horizontal_aligner{
      mode = "right",
      vb:text{style = "strong", font = "bold", text="Delay"},
      vb:button{
        text="R",
        tooltip = "Randomize Delay",
        notifier=function()
          randomizeNoteColumn("delay_value")
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:minislider {
        id = "delayslider",
        width=50,
        height = eSlider,
        min = 0,
        max = 0xFF,
        notifier=function(v)
          sliderVisible("delay")
          local s = renoise.song()
          if s.selection_in_pattern then
            for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
              local track = s:track(t)
              if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
                local note_columns_visible = track.visible_note_columns
                local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or 1
                local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or note_columns_visible
                for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
                  for col = start_column, end_column do
                    if col <= note_columns_visible then
                      local note_column = s:pattern(s.selected_pattern_index):track(t):line(i).note_columns[col]
                      if note_column then
                        note_column.delay_value = v
                      end
                    end
                  end
                end
              end
            end
          else
            if s.selected_note_column then
              s.selected_note_column.delay_value = v
            end
          end
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      }
    },
    -- Sample FX
    vb:horizontal_aligner{
      mode = "right",
      vb:text{style = "strong", font = "bold", text="Sample FX"},
      vb:button{
        text="R",
        tooltip = "Randomize Sample FX",
        notifier=function()
          randomizeNoteColumn("effect_amount_value")
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:minislider {
        id = "samplefxslider",
        width=50,
        height = eSlider,
        min = 0,
        max = 0x80,
        notifier=function(v)
          sliderVisible("samplefx")
          local s = renoise.song()
          if s.selection_in_pattern then
            for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
              local track = s:track(t)
              if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
                local note_columns_visible = track.visible_note_columns
                local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or 1
                local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or note_columns_visible
                for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
                  for col = start_column, end_column do
                    if col <= note_columns_visible then
                      local note_column = s:pattern(s.selected_pattern_index):track(t):line(i).note_columns[col]
                      if note_column then
                        note_column.effect_amount_value = v
                      end
                    end
                  end
                end
              end
            end
          else
            if s.selected_note_column then
              s.selected_note_column.effect_amount_value = v
            end
          end
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      }
    },
    -- Effect
    vb:horizontal_aligner{
      mode = "right",
      vb:text{style = "strong", font = "bold", text="Effect"},
      vb:button{
        text="R",
        tooltip = "Randomize Effect Amount",
        notifier=function()
          randomizeEffectAmount()
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:minislider {
        id = "effectslider",
        width=50,
        height = eSlider,
        min = 0,
        max = 0xFF,
        notifier=function(v)
          sliderVisibleEffect()
          local s = renoise.song()
          if s.selection_in_pattern then
            for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
              local track = s:track(t)
              if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
                local note_columns_visible = track.visible_note_columns
                local effect_columns_visible = track.visible_effect_columns
                local total_columns_visible = note_columns_visible + effect_columns_visible
                local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or note_columns_visible + 1
                local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or total_columns_visible
                for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
                  for col = start_column, end_column do
                    local column_index = col - note_columns_visible
                    if column_index > 0 and column_index <= effect_columns_visible then
                      local effect_column = s:pattern(s.selected_pattern_index):track(t):line(i):effect_column(column_index)
                      if effect_column then
                        effect_column.amount_value = v
                      end
                    end
                  end
                end
              end
            end
          else
            if s.selected_effect_column then
              s.selected_effect_column.amount_value = v
            elseif s.selected_line then
              s.selected_line.effect_columns[1].amount_value = v
            end
          end
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      }
    }
  }

  local left_column=vb:column{effect_buttons,randomize_section}
  local dialog_content=vb:row{left_column,sliders}

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = a:show_custom_dialog("Paketti Pattern Effect Command CheatSheet", dialog_content, keyhandler)
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Keybinding to open the CheatSheet
renoise.tool():add_keybinding{name="Global:Paketti:Pattern Effect Command CheatSheet",invoke=pakettiPatternEditorCheatsheetDialog}




-----------
-- Minimized Cheatsheet for Pattern Effects
local mini_dialog = nil

-- Effects list from the full cheatsheet
local mini_effects = {
  {"0A", "-Axy", "Set arpeggio, x/y = first/second note offset in semitones"},
  {"0U", "-Uxx", "Slide Pitch up by xx 1/16ths of a semitone"},
  {"0D", "-Dxx", "Slide Pitch down by xx 1/16ths of a semitone"},
  {"0G", "-Gxx", "Glide towards given note by xx 1/16ths of a semitone"},
  {"0I", "-Ixx", "Fade Volume in by xx volume units"},
  {"0O", "-Oxx", "Fade Volume out by xx volume units"},
  {"0C", "-Cxy", "Cut volume to x after y ticks (x = volume factor: 0=0%, F=100%)"},
  {"0Q", "-Qxx", "Delay note by xx ticks"},
  {"0M", "-Mxx", "Set note volume to xx"},
  {"0S", "-Sxx", "Trigger sample slice number xx or offset xx"},
  {"0B", "-Bxx", "Play Sample Backwards (B00) or forwards again (B01)"},
  {"0R", "-Rxy", "Retrigger line every y ticks with volume factor x"},
  {"0Y", "-Yxx", "Maybe trigger line with probability xx, 00 = mutually exclusive note columns"},
  {"0Z", "-Zxx", "Trigger Phrase xx (Phrase Number (01-7E), 00 = none, 7F = keymap)"},
  {"0V", "-Vxy", "Set Vibrato x = speed, y = depth; x=(0-F); y=(0-F)"},
  {"0T", "-Txy", "Set Tremolo x = speed, y = depth"},
  {"0N", "-Nxy", "Set Auto Pan, x = speed, y = depth"},
  {"0E", "-Exx", "Set Active Sample Envelope's Position to Offset XX"},
  {"0L", "-Lxx", "Set Track Volume Level, 00 = -INF, FF = +3dB"},
  {"0P", "-Pxx", "Set Track Pan, 00 = full left, 80 = center, FF = full right"},
  {"0W", "-Wxx", "Set Track Surround Width, 00 = Min, FF = Max"},
  {"0J", "-Jxx", "Set Track Routing, 01 upwards = hardware channels, FF downwards = parent groups"},
  {"0X", "-Xxx", "Stop all notes and FX (xx = 00), or only effect xx (xx > 00)"},
  {"ZT", "ZTxx", "Set tempo to xx BPM (14-FF, 00 = stop song)"},
  {"ZL", "ZLxx", "Set Lines Per Beat (LPB) to xx lines"},
  {"ZK", "ZKxx", "Set Ticks Per Line (TPL) to xx ticks (01-10)"},
  {"ZG", "ZGxx", "Enable (xx = 01) or disable (xx = 00) Groove"},
  {"ZB", "ZBxx", "Break pattern and jump to line xx in next"},
  {"ZD", "ZDxx", "Delay (pause) pattern for xx lines"}
}

-- Apply effect command and value directly to all selected effect columns
local function apply_mini_effect_direct(effect_command, hex_value)
  sliderVisibleEffect()
  local s = renoise.song()
  if s.selection_in_pattern then
    for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
      local track = s:track(t)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local note_columns_visible = track.visible_note_columns
        local effect_columns_visible = track.visible_effect_columns
        local total_columns_visible = note_columns_visible + effect_columns_visible
        local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or note_columns_visible + 1
        local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or total_columns_visible
        for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
          for col = start_column, end_column do
            local column_index = col - note_columns_visible
            if column_index > 0 and column_index <= effect_columns_visible then
              local effect_column = s:pattern(s.selected_pattern_index):track(t):line(i):effect_column(column_index)
              if effect_column then
                effect_column.number_string = effect_command
                effect_column.amount_value = hex_value
              end
            end
          end
        end
      end
    end
  else
    if s.selected_effect_column then
      s.selected_effect_column.number_string = effect_command
      s.selected_effect_column.amount_value = hex_value
    elseif s.selected_line then
      s.selected_line.effect_columns[1].number_string = effect_command
      s.selected_line.effect_columns[1].amount_value = hex_value
    end
  end
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Persistent state for mini cheatsheet
local mini_selected_effect_index = 1
local mini_hex_value = 128  -- Start at 0x80 (50%)

function show_mini_cheatsheet()
  local vb = renoise.ViewBuilder()
  
  -- Close the full cheatsheet if it's open
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
  end
  
  if mini_dialog and mini_dialog.visible then
    mini_dialog:close()
    return
  end

  -- Create dropdown items
  local dropdown_items = {}
  for i, effect in ipairs(mini_effects) do
    dropdown_items[i] = effect[2] .. " - " .. effect[3]
  end

  local selected_effect_index = mini_selected_effect_index
  local hex_value = mini_hex_value

  local percentage_text = vb:text{
    text = string.format("%d%% Fill (0x%02X)", math.floor((hex_value / 255) * 100), hex_value)
  }

  -- Apply random effect
  local function apply_random_effect()
    local random_index = math.random(1, #mini_effects)
    selected_effect_index = random_index
    mini_selected_effect_index = random_index  -- Update persistent state
    local selected_effect = mini_effects[selected_effect_index]
    apply_mini_effect_direct(selected_effect[1], hex_value)
    renoise.app():show_status(string.format("Random effect: %s", selected_effect[2]))
    -- Update the dropdown to show the randomly selected effect
    if mini_dialog and mini_dialog.visible then
      mini_dialog:close()
      show_mini_cheatsheet()
    end
  end

  local dialog_content = vb:column{
    vb:row{
      spacing = 10,
      vb:popup{
        items = dropdown_items,
        value = selected_effect_index,
        width = 450,
        notifier = function(index)
          selected_effect_index = index
          mini_selected_effect_index = index  -- Update persistent state
          -- Apply effect when dropdown changes
          local selected_effect = mini_effects[selected_effect_index]
          apply_mini_effect_direct(selected_effect[1], hex_value)
        end
      },
      vb:button{
        text = "Random",
        width = 60,
        notifier = apply_random_effect
      },
      vb:button{
        text = "Maximize",
        width = 70,
        notifier = function()
          -- Close mini dialog and open full cheatsheet
          if mini_dialog and mini_dialog.visible then
            mini_dialog:close()
            mini_dialog = nil
          end
          pakettiPatternEditorCheatsheetDialog()
        end
      }
    },
    
    vb:row{
      spacing = 10,
      vb:slider{
        width = 200,
        min = 0,
        max = 255,
        value = hex_value,
        notifier = function(value)
          hex_value = math.floor(value + 0.5)
          mini_hex_value = hex_value  -- Update persistent state
          local percentage = math.floor((hex_value / 255) * 100)
          percentage_text.text = string.format("%d%% Fill (0x%02X)", percentage, hex_value)
          -- Apply effect in real-time
          local selected_effect = mini_effects[selected_effect_index]
          apply_mini_effect_direct(selected_effect[1], hex_value)
        end
      },
      percentage_text
    }
  }

  local function keyhandler(dialog, key)
    local closer = "esc"
    if preferences and preferences.pakettiDialogClose then
      closer = preferences.pakettiDialogClose.value
    end
    if key.modifiers == "" and key.name == closer then
      dialog:close()
      mini_dialog = nil
      return nil
    else
      return key
    end
  end

  mini_dialog = renoise.app():show_custom_dialog("Paketti Minimize Cheatsheet", dialog_content, keyhandler)
end

-- Vertical version of the minimized cheatsheet
function show_mini_cheatsheet_vertical()
  local vb = renoise.ViewBuilder()
  
  -- Close the full cheatsheet if it's open
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
  end
  
  if mini_dialog and mini_dialog.visible then
    mini_dialog:close()
    return
  end

  -- Create dropdown items
  local dropdown_items = {}
  for i, effect in ipairs(mini_effects) do
    dropdown_items[i] = effect[2] .. " - " .. effect[3]
  end

  local selected_effect_index = mini_selected_effect_index
  local hex_value = mini_hex_value

  local percentage_text = vb:text{
    style = "strong",
    font = "bold",
    text = string.format("%03d%% Fill (0x%02X)", math.floor((hex_value / 255) * 100), hex_value)
  }

  -- Apply random effect
  local function apply_random_effect()
    local random_index = math.random(1, #mini_effects)
    selected_effect_index = random_index
    mini_selected_effect_index = random_index  -- Update persistent state
    local selected_effect = mini_effects[selected_effect_index]
    apply_mini_effect_direct(selected_effect[1], hex_value)
    renoise.app():show_status(string.format("Random effect: %s", selected_effect[2]))
    -- Update the dropdown to show the randomly selected effect
    if mini_dialog and mini_dialog.visible then
      mini_dialog:close()
      show_mini_cheatsheet_vertical()
    end
  end

  -- Apply random value
  local function apply_random_value()
    hex_value = math.random(0, 255)
    mini_hex_value = hex_value  -- Update persistent state
    local percentage = math.floor((hex_value / 255) * 100)
    percentage_text.text = string.format("%03d%% Fill (0x%02X)", percentage, hex_value)
    -- Apply effect with new random value
    local selected_effect = mini_effects[selected_effect_index]
    apply_mini_effect_direct(selected_effect[1], hex_value)
    renoise.app():show_status(string.format("Random value: 0x%02X (%03d%%)", hex_value, percentage))
  end

  local dialog_content = vb:column{
    
    
    -- Dropdown at top
    vb:popup{
      items = dropdown_items,
      value = selected_effect_index,
      width = 100,
      notifier = function(index)
        selected_effect_index = index
        mini_selected_effect_index = index  -- Update persistent state
        -- Apply effect when dropdown changes
        local selected_effect = mini_effects[selected_effect_index]
        apply_mini_effect_direct(selected_effect[1], hex_value)
      end
    },
    
    -- Vertical slider in middle
    vb:horizontal_aligner{
      mode = "center",
      vb:minislider{
        width = 50,
        height = 200,
        min = 0,
        max = 255,
        value = hex_value,
        notifier = function(value)
          hex_value = math.floor(value + 0.5)
          mini_hex_value = hex_value  -- Update persistent state
          local percentage = math.floor((hex_value / 255) * 100)
          percentage_text.text = string.format("%03d%% Fill (0x%02X)", percentage, hex_value)
          -- Apply effect in real-time
          local selected_effect = mini_effects[selected_effect_index]
          apply_mini_effect_direct(selected_effect[1], hex_value)
        end
      }
    },
    
    -- Value text
    vb:horizontal_aligner{
      mode = "center",
      percentage_text
    },
    
    -- Buttons at bottom
    vb:horizontal_aligner{
      mode = "center",
      vb:button{
        text = "Random",
        width = 100,
        notifier = apply_random_effect
      }
    },
    vb:horizontal_aligner{
      mode = "center",
      vb:button{
        text = "Randomize",
        width = 100,
        notifier = apply_random_value
      }
    },
    vb:horizontal_aligner{
      mode = "center",
      vb:button{
        text = "Maximize",
        width = 100,
        notifier = function()
          -- Close mini dialog and open full cheatsheet
          if mini_dialog and mini_dialog.visible then
            mini_dialog:close()
            mini_dialog = nil
          end
          pakettiPatternEditorCheatsheetDialog()
        end
      }
    }
  }

  local function keyhandler(dialog, key)
    local closer = "esc"
    if preferences and preferences.pakettiDialogClose then
      closer = preferences.pakettiDialogClose.value
    end
    if key.modifiers == "" and key.name == closer then
      dialog:close()
      mini_dialog = nil
      return nil
    else
      return key
    end
  end

  mini_dialog = renoise.app():show_custom_dialog("Vert", dialog_content, keyhandler)
end

-- Add menu entry and keybinding for minimized cheatsheet
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Pattern Editor:Paketti Cheatsheet Minimize Horizontal...", invoke = show_mini_cheatsheet}
renoise.tool():add_keybinding{name = "Global:Paketti:Show Minimize Cheatsheet Horizontal", invoke = show_mini_cheatsheet}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Pattern Editor:Paketti Cheatsheet Minimize Vertical...", invoke = show_mini_cheatsheet_vertical}
renoise.tool():add_keybinding{name = "Global:Paketti:Show Minimize Cheatsheet Vertical", invoke = show_mini_cheatsheet_vertical}


-- Pattern Effect/Note Column Status Monitor
-- Note: Initialized from preferences at startup in main.lua
PakettiPatternStatusMonitorEnabled = false

-- Function to get effect description from our effects table
local function get_effect_description(effect_number)
  for _, effect_data in ipairs(effects) do
    if effect_data[1] == effect_number then
      return effect_data[2], effect_data[3]  -- Returns display name and description
    end
  end
  return nil, nil
end

-- Function to show status for current selection
function show_current_status()
  if not PakettiPatternStatusMonitorEnabled then return end
  
  local song = renoise.song()
  local status_text = ""
  
  -- Check if we're in an effect column
  if song.selected_effect_column_index > 0 then
    local effect_column = song.selected_effect_column
    if effect_column and not effect_column.is_empty then
      local effect_number = effect_column.number_string
      local effect_value = effect_column.amount_value
      local display_name, description = get_effect_description(effect_number)
      
      if display_name and description then
        status_text = string.format("Effect: %s (0x%02X/255) - %s", 
                                   display_name, effect_value, description)
      else
        status_text = string.format("Effect: %s (0x%02X/255) - Unknown effect", 
                                   effect_number, effect_value)
      end
    else
      status_text = "Effect Column: Empty"
    end
    
  -- Check if we're in a note column
  elseif song.selected_note_column_index > 0 then
    local note_column = song.selected_note_column
    if note_column then
      local parts = {}
      
      -- Note information
      if note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE then
        if note_column.note_string == "OFF" then
          table.insert(parts, "Note: OFF")
        else
          table.insert(parts, string.format("Note: %s", note_column.note_string))
        end
      end
      
      -- Instrument information
      if note_column.instrument_value ~= renoise.PatternLine.EMPTY_INSTRUMENT then
        table.insert(parts, string.format("I:%02X", note_column.instrument_value))
      end
      
      -- Volume information
      if note_column.volume_value ~= renoise.PatternLine.EMPTY_VOLUME then
        table.insert(parts, string.format("Vol:%02X", note_column.volume_value))
      end
      
      -- Panning information
      if note_column.panning_value ~= renoise.PatternLine.EMPTY_PANNING then
        table.insert(parts, string.format("Pan:%02X", note_column.panning_value))
      end
      
      -- Delay information
      if note_column.delay_value ~= renoise.PatternLine.EMPTY_DELAY then
        table.insert(parts, string.format("Dly:%02X", note_column.delay_value))
      end
      
      -- Sample FX information
      if note_column.effect_number_value ~= renoise.PatternLine.EMPTY_EFFECT_NUMBER or
         note_column.effect_amount_value ~= renoise.PatternLine.EMPTY_EFFECT_AMOUNT then
        local fx_num = string.format("%02X", note_column.effect_number_value)
        table.insert(parts, string.format("FX:%s%02X", fx_num, note_column.effect_amount_value))
      end
      
      if #parts > 0 then
        status_text = table.concat(parts, " ")
      else
        status_text = "Empty"
      end
    end
  else
    status_text = "No column selected"
  end
  
  renoise.app():show_status(status_text)
end

-- Variables for tracking position changes (like in PakettiTuningDisplay.lua)
local last_status_position = nil

-- Timer function for monitoring pattern editor status (based on PakettiTuningDisplay.lua approach)
local function status_monitor_timer()
  if not PakettiPatternStatusMonitorEnabled then
    return
  end
  
  -- Safe song access with error handling
  local song
  local success, error_msg = pcall(function()
    song = renoise.song()
  end)
  
  if not success or not song then
    return
  end
  
  -- Get current position (track, line, note column, effect column)
  local track_index = song.selected_track_index
  local line_index = song.selected_line_index
  local note_column_index = song.selected_note_column_index
  local effect_column_index = song.selected_effect_column_index
  local pattern_index = song.selected_pattern_index
  
  -- Create position hash for comparison
  local current_position = string.format("%d:%d:%d:%d:%d", 
    track_index, line_index, note_column_index, effect_column_index, pattern_index)
  
  -- Only update if position changed
  if current_position ~= last_status_position then
    last_status_position = current_position
    show_current_status()
  end
end

-- Function to start status monitoring
local function start_status_monitor()
  if not renoise.tool():has_timer(status_monitor_timer) then
    renoise.tool():add_timer(status_monitor_timer, 100) -- Check every 100ms
    print("Status Monitor: Timer started (100ms interval)")
  end
end

-- Function to stop status monitoring  
local function stop_status_monitor()
  if renoise.tool():has_timer(status_monitor_timer) then
    renoise.tool():remove_timer(status_monitor_timer)
    print("Status Monitor: Timer stopped")
  end
  last_status_position = nil
end

-- Function to enable status monitor (for startup)
function enable_pattern_status_monitor()
  if not PakettiPatternStatusMonitorEnabled then
    PakettiPatternStatusMonitorEnabled = true
    start_status_monitor()
    show_current_status()  -- Show initial status
    renoise.app():show_status("Pattern Status Monitor: ON - Effect/Note column info will be shown")
  end
end

-- Function to toggle status monitor
function toggle_pattern_status_monitor()
  PakettiPatternStatusMonitorEnabled = not PakettiPatternStatusMonitorEnabled
  preferences.pakettiPatternStatusMonitor.value = PakettiPatternStatusMonitorEnabled
  preferences:save_as("preferences.xml")
  
  if PakettiPatternStatusMonitorEnabled then
    start_status_monitor()
    show_current_status()  -- Show initial status
    renoise.app():show_status("Pattern Status Monitor: ON - Effect/Note column info will be shown")
  else
    stop_status_monitor()
    renoise.app():show_status("Pattern Status Monitor: OFF")
  end
end

-- Clean up timer when tool is unloaded
renoise.tool().app_release_document_observable:add_notifier(function()
  stop_status_monitor()
end)


renoise.tool():add_keybinding{name="Global:Paketti:Toggle Pattern Status Monitor", invoke=toggle_pattern_status_monitor}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Pattern Editor:Toggle Pattern Status Monitor", invoke=toggle_pattern_status_monitor,selected=function() return PakettiPatternStatusMonitorEnabled end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti:Toggle Pattern Status Monitor", invoke=toggle_pattern_status_monitor,selected=function() return PakettiPatternStatusMonitorEnabled end}
