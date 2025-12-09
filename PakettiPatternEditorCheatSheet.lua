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
end

-- Helper function to check if we're in the Phrase Editor
local function is_phrase_editor_active()
  return renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
end

-- Helper function to check if there's a valid phrase selected
local function has_valid_phrase()
  local song = renoise.song()
  if not song then return false end
  local phrase = song.selected_phrase
  return phrase ~= nil
end

-- Helper function to get the appropriate selection data based on active editor
-- Returns: is_phrase_mode, selection_data, target_data
-- target_data contains line_index, note_column_index, effect_column_index for single-line operations
local function get_editor_context()
  local song = renoise.song()
  if not song then return false, nil, nil end
  
  local is_phrase_mode = is_phrase_editor_active() and has_valid_phrase()
  
  if is_phrase_mode then
    local phrase = song.selected_phrase
    local selection = song.selection_in_phrase
    local target_data = {
      line_index = song.selected_phrase_line_index,
      note_column_index = song.selected_phrase_note_column_index,
      effect_column_index = song.selected_phrase_effect_column_index,
      phrase = phrase,
      visible_note_columns = phrase.visible_note_columns,
      visible_effect_columns = phrase.visible_effect_columns,
      number_of_lines = phrase.number_of_lines
    }
    return true, selection, target_data
  else
    local selection = song.selection_in_pattern
    local track = song.selected_track
    local target_data = {
      line_index = song.selected_line_index,
      note_column_index = song.selected_note_column_index,
      effect_column_index = song.selected_effect_column_index,
      track = track,
      visible_note_columns = track.visible_note_columns,
      visible_effect_columns = track.visible_effect_columns,
      pattern_index = song.selected_pattern_index,
      track_index = song.selected_track_index
    }
    return false, selection, target_data
  end
end

-- Helper function to get line from phrase or pattern based on mode
local function get_line(is_phrase_mode, target_data, line_index)
  if is_phrase_mode then
    return target_data.phrase:line(line_index)
  else
    local song = renoise.song()
    local pattern = song:pattern(target_data.pattern_index)
    local pattern_track = pattern:track(target_data.track_index)
    return pattern_track:line(line_index)
  end
end

-- Helper function to restore focus to appropriate middle frame
local function restore_middle_frame(is_phrase_mode)
  if is_phrase_mode then
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
  else
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end
end

-- Effects that are valid in phrases (sample/note effects only)
-- Pattern-only effects (track/global effects) are: 0L, 0P, 0W, 0J, 0X, 0Z, ZT, ZL, ZK, ZG, ZB, ZD
local phrase_valid_effects = {
  ["0A"] = true,  -- Arpeggio
  ["0U"] = true,  -- Slide Pitch up
  ["0D"] = true,  -- Slide Pitch down
  ["0G"] = true,  -- Glide towards note
  ["0I"] = true,  -- Fade Volume in
  ["0O"] = true,  -- Fade Volume out
  ["0C"] = true,  -- Cut volume
  ["0Q"] = true,  -- Delay note
  ["0M"] = true,  -- Set note volume
  ["0S"] = true,  -- Trigger sample slice
  ["0B"] = true,  -- Play Sample Backwards
  ["0R"] = true,  -- Retrigger
  ["0Y"] = true,  -- Maybe trigger (probability)
  ["0V"] = true,  -- Vibrato
  ["0T"] = true,  -- Tremolo
  ["0N"] = true,  -- Auto Pan
  ["0E"] = true,  -- Set envelope position
}

-- Helper function to check if an effect is valid for phrases
local function is_effect_valid_for_phrase(effect_code)
  return phrase_valid_effects[effect_code] == true
end

-- Effects that are valid in Sample FX columns (per-note-column sample effects)
-- These are the commands that work in the sample effects sub-column of note columns
local sample_fx_valid_effects = {
  ["0A"] = true,  -- Arpeggio
  ["0U"] = true,  -- Slide Pitch up
  ["0D"] = true,  -- Slide Pitch down
  ["0G"] = true,  -- Glide towards note
  ["0V"] = true,  -- Vibrato
  ["0I"] = true,  -- Fade Volume in
  ["0O"] = true,  -- Fade Volume out
  ["0T"] = true,  -- Tremolo
  ["0C"] = true,  -- Cut volume
  ["0S"] = true,  -- Trigger sample slice/offset
  ["0B"] = true,  -- Play Sample Backwards/forwards
  ["0E"] = true,  -- Set envelope position
  ["0N"] = true,  -- Auto Pan
}

-- Helper function to check if an effect is valid for Sample FX columns
local function is_effect_valid_for_sample_fx(effect_code)
  return sample_fx_valid_effects[effect_code] == true
end

-- Current write mode: 1 = Effect Columns, 2 = Sample FX
local cheatsheet_write_mode = 1

function Cheatsheetclear_effect_columns()
  local s = renoise.song()
  local is_phrase_mode, selection, target_data = get_editor_context()
  
  if is_phrase_mode then
    -- Phrase Editor mode
    local phrase = target_data.phrase
    local note_columns_visible = phrase.visible_note_columns
    local effect_columns_visible = phrase.visible_effect_columns
    
    if selection then
      -- Clear selection in phrase
      local total_columns_visible = note_columns_visible + effect_columns_visible
      local start_column = selection.start_column or (note_columns_visible + 1)
      local end_column = selection.end_column or total_columns_visible
      
      for i = selection.start_line, selection.end_line do
        local line = phrase:line(i)
        for col = start_column, end_column do
          local column_index = col - note_columns_visible
          if column_index > 0 and column_index <= effect_columns_visible then
            local effect_column = line:effect_column(column_index)
            if effect_column then
              effect_column:clear()
            end
          end
        end
      end
    else
      -- Clear current effect column in phrase
      local effect_col_idx = target_data.effect_column_index
      if effect_col_idx > 0 then
        local line = phrase:line(target_data.line_index)
        local effect_column = line:effect_column(effect_col_idx)
        if effect_column then
          effect_column:clear()
        end
      end
    end
  else
    -- Pattern Editor mode
    if s.selection_in_pattern then
      -- Clear selection
      local pattern = s:pattern(s.selected_pattern_index)
      for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
        local track = s:track(t)
        local pattern_track = pattern:track(t)
        local note_columns_visible = track.visible_note_columns
        local effect_columns_visible = track.visible_effect_columns
        local total_columns_visible = note_columns_visible + effect_columns_visible
        
        local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or note_columns_visible + 1
        local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or total_columns_visible
        
        for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
          local line = pattern_track:line(i)
          for col = start_column, end_column do
            local column_index = col - note_columns_visible
            if column_index > 0 and column_index <= effect_columns_visible then
              local effect_column = line:effect_column(column_index)
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
  end
  
  renoise.app():show_status("Effect columns cleared")
  restore_middle_frame(is_phrase_mode)
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

function randomizeSmatterEffectColumnCustom(effect_command, fill_percentage, min_value, max_value, target_effect_column_index)
  trueRandomSeed()

  local song = renoise.song()
  local is_phrase_mode, selection, target_data = get_editor_context()
  local randomize_switch = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeSwitch.value
  local dont_overwrite = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeDontOverwrite.value
  local only_modify_effects = preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyEffects.value
  local only_modify_notes = preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyNotes.value
  local randomize_whole_track_cb = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeWholeTrack.value
  
  -- Determine target column if not specified
  if not target_effect_column_index then
    if is_phrase_mode then
      if target_data.note_column_index > 0 then
        target_effect_column_index = 1
      elseif target_data.effect_column_index > 0 then
        target_effect_column_index = target_data.effect_column_index
      else
        target_effect_column_index = 1
      end
    else
      if song.selected_note_column_index > 0 then
        target_effect_column_index = 1
      elseif song.selected_effect_column_index > 0 then
        target_effect_column_index = song.selected_effect_column_index
      else
        target_effect_column_index = 1
      end
    end
  end

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

  -- Helper to check for notes in a line (works for both pattern and phrase)
  local has_notes_in_line_generic = function(line, visible_columns)
    for i = 1, visible_columns do
      local note_column = line.note_columns[i]
      if note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE and 
         note_column.note_string ~= "OFF" then
        return true
      end
    end
    return false
  end

  local apply_command = function(line, column_index, visible_note_columns)
    local effect_column = line:effect_column(column_index)
    if effect_column then
      if only_modify_notes then
        if has_notes_in_line_generic(line, visible_note_columns) and should_apply() then
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

  if is_phrase_mode then
    -- Phrase Editor mode
    local phrase = target_data.phrase
    local note_columns_visible = phrase.visible_note_columns
    local effect_columns_visible = phrase.visible_effect_columns
    
    if selection then
      -- Apply to selection in phrase
      local total_columns_visible = note_columns_visible + effect_columns_visible
      local start_column = selection.start_column or 1
      local end_column = selection.end_column or total_columns_visible
      
      for line_index = selection.start_line, selection.end_line do
        local line = phrase:line(line_index)
        for col = start_column, end_column do
          local column_index = col - note_columns_visible
          if col > note_columns_visible and column_index > 0 and column_index <= effect_columns_visible then
            apply_command(line, column_index, note_columns_visible)
          end
        end
      end
    else
      if randomize_whole_track_cb then
        -- Apply to whole phrase
        for line_index = 1, phrase.number_of_lines do
          for column_index = 1, effect_columns_visible do
            local line = phrase:line(line_index)
            apply_command(line, column_index, note_columns_visible)
          end
        end
      else
        -- Apply to current line in phrase
        if target_effect_column_index <= effect_columns_visible then
          local line = phrase:line(target_data.line_index)
          apply_command(line, target_effect_column_index, note_columns_visible)
        end
      end
    end
  else
    -- Pattern Editor mode
    if selection then
      -- Apply to selection
      local pattern = song:pattern(song.selected_pattern_index)
      for line_index = selection.start_line, selection.end_line do
        for t = selection.start_track, selection.end_track do
          local track = pattern:track(t)
          local trackvis = song:track(t)
          local note_columns_visible = trackvis.visible_note_columns
          local effect_columns_visible = trackvis.visible_effect_columns
          local total_columns_visible = note_columns_visible + effect_columns_visible

          local start_column = (t == selection.start_track) and selection.start_column or 1
          local end_column = (t == selection.end_track) and selection.end_column or total_columns_visible
          
          local line = track:line(line_index)
          for col = start_column, end_column do
            local column_index = col - note_columns_visible
            if col > note_columns_visible and column_index > 0 and column_index <= effect_columns_visible then
              apply_command(line, column_index, note_columns_visible)
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
          local note_columns_visible = song:track(track_index).visible_note_columns
          for line_index = 1, lines do
            for column_index = 1, song:track(track_index).visible_effect_columns do
              apply_command(track:line(line_index), column_index, note_columns_visible)
            end
          end
        end
      else
        -- Apply to current line, target specific effect column
        local line = song.selected_line
        local note_columns_visible = song.selected_track.visible_note_columns
        if target_effect_column_index <= song.selected_track.visible_effect_columns then
          apply_command(line, target_effect_column_index, note_columns_visible)
        end
      end
    end
  end

  renoise.app():show_status("Random " .. effect_command .. " commands applied to effect column " .. target_effect_column_index .. ".")
  restore_middle_frame(is_phrase_mode)
end

function randomizeSmatterEffectColumnC0(fill_percentage, target_effect_column_index)
  randomizeSmatterEffectColumnCustom("0C", fill_percentage, 0x00, 0x0F, target_effect_column_index)
end

function randomizeSmatterEffectColumnB0(fill_percentage, target_effect_column_index)
  randomizeSmatterEffectColumnCustom("0B", fill_percentage, 0x00, 0x01, target_effect_column_index)
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
  local is_phrase_mode, selection, target_data = get_editor_context()
  local min_value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMin.value
  local max_value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMax.value
  local randomize_switch = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeSwitch.value

  if min_value > max_value then
    min_value, max_value = max_value, min_value
  end

  -- Make column visible (only works in pattern editor mode)
  if not is_phrase_mode then
    sliderVisible(column_name)
  else
    -- Make column visible in phrase
    local phrase = target_data.phrase
    if column_name == "volume_value" then
      phrase.volume_column_visible = true
    elseif column_name == "panning_value" then
      phrase.panning_column_visible = true
    elseif column_name == "delay_value" then
      phrase.delay_column_visible = true
    elseif column_name == "effect_amount_value" then
      phrase.sample_effects_column_visible = true
    end
  end
  
  local column_max_value = 0xFF
  if column_name == "volume_value" or column_name == "panning_value" or column_name == "effect_amount_value" then
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

  if is_phrase_mode then
    -- Phrase Editor mode
    local phrase = target_data.phrase
    local note_columns_visible = phrase.visible_note_columns
    
    if selection then
      -- Iterate over selection in phrase
      local start_column = selection.start_column or 1
      local end_column = selection.end_column or note_columns_visible
      for i = selection.start_line, selection.end_line do
        local line = phrase:line(i)
        for col = start_column, end_column do
          if col <= note_columns_visible then
            local note_column = line.note_columns[col]
            if note_column and is_subcolumn_not_empty(note_column) and should_apply() then
              note_column[column_name] = random_value()
            end
          end
        end
      end
    else
      if not randomize_whole_track_cb then
        -- Randomize current line in phrase
        local note_col_idx = target_data.note_column_index
        if note_col_idx > 0 then
          local line = phrase:line(target_data.line_index)
          local note_column = line:note_column(note_col_idx)
          if note_column and is_subcolumn_not_empty(note_column) then
            note_column[column_name] = random_value()
          end
        end
      else
        -- Randomize whole phrase
        for i = 1, phrase.number_of_lines do
          local line = phrase:line(i)
          for col = 1, note_columns_visible do
            local note_column = line.note_columns[col]
            if note_column and is_subcolumn_not_empty(note_column) and should_apply() then
              note_column[column_name] = random_value()
            end
          end
        end
      end
    end
  else
    -- Pattern Editor mode
    if s.selection_in_pattern then
      -- Iterate over selection
      local pattern = s:pattern(s.selected_pattern_index)
      for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
        local track = s:track(t)
        if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          local pattern_track = pattern:track(t)
          local note_columns_visible = track.visible_note_columns
          local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or 1
          local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or note_columns_visible
          for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
            local line = pattern_track:line(i)
            for col = start_column, end_column do
              if col <= note_columns_visible then
                local note_column = line.note_columns[col]
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
            local pattern_track = pattern:track(track_index)
            local lines = pattern.number_of_lines
            local note_columns_visible = track.visible_note_columns
            for i = 1, lines do
              local line = pattern_track:line(i)
              for col = 1, note_columns_visible do
                local note_column = line.note_columns[col]
                if note_column and is_subcolumn_not_empty(note_column) and should_apply() then
                  note_column[column_name] = random_value()
                end
              end
            end
          end
        end
      end
    end
  end
  restore_middle_frame(is_phrase_mode)
end

function randomizeEffectAmount()
  local s = renoise.song()
  local is_phrase_mode, selection, target_data = get_editor_context()
  local min_value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMin.value
  local max_value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMax.value
  local randomize_switch = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeSwitch.value

  if min_value > max_value then
    min_value, max_value = max_value, min_value
  end

  -- Make effect columns visible
  if not is_phrase_mode then
    sliderVisibleEffect()
  else
    local phrase = target_data.phrase
    if phrase.visible_effect_columns < 1 then
      phrase.visible_effect_columns = 1
    end
  end

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

  if is_phrase_mode then
    -- Phrase Editor mode
    local phrase = target_data.phrase
    local note_columns_visible = phrase.visible_note_columns
    local effect_columns_visible = phrase.visible_effect_columns
    
    if selection then
      -- Apply to selection in phrase
      local total_columns_visible = note_columns_visible + effect_columns_visible
      local start_column = selection.start_column or (note_columns_visible + 1)
      local end_column = selection.end_column or total_columns_visible
      for i = selection.start_line, selection.end_line do
        local line = phrase:line(i)
        for col = start_column, end_column do
          local column_index = col - note_columns_visible
          if column_index > 0 and column_index <= effect_columns_visible then
            local effect_column = line:effect_column(column_index)
            if effect_column and not effect_column.is_empty and should_apply() then
              effect_column.amount_value = random_value()
            end
          end
        end
      end
    else
      if not randomize_whole_track_cb then
        -- Randomize current line in phrase
        local effect_col_idx = target_data.effect_column_index
        if effect_col_idx > 0 then
          local line = phrase:line(target_data.line_index)
          local effect_column = line:effect_column(effect_col_idx)
          if effect_column and not effect_column.is_empty then
            effect_column.amount_value = random_value()
          end
        end
      else
        -- Randomize whole phrase
        for i = 1, phrase.number_of_lines do
          local line = phrase:line(i)
          for col = 1, effect_columns_visible do
            local effect_column = line:effect_column(col)
            if effect_column and not effect_column.is_empty and should_apply() then
              effect_column.amount_value = random_value()
            end
          end
        end
      end
    end
  else
    -- Pattern Editor mode
    if s.selection_in_pattern then
      local pattern = s:pattern(s.selected_pattern_index)
      for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
        local track = s:track(t)
        if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          local pattern_track = pattern:track(t)
          local note_columns_visible = track.visible_note_columns
          local effect_columns_visible = track.visible_effect_columns
          local total_columns_visible = note_columns_visible + effect_columns_visible
          local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or note_columns_visible + 1
          local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or total_columns_visible
          for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
            local line = pattern_track:line(i)
            for col = start_column, end_column do
              local column_index = col - note_columns_visible
              if column_index > 0 and column_index <= effect_columns_visible then
                local effect_column = line:effect_column(column_index)
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
            local pattern_track = pattern:track(track_index)
            local lines = pattern.number_of_lines
            local effect_columns_visible = track.visible_effect_columns
            for i = 1, lines do
              local line = pattern_track:line(i)
              for col = 1, effect_columns_visible do
                local effect_column = line:effect_column(col)
                if effect_column and not effect_column.is_empty and should_apply() then
                  effect_column.amount_value = random_value()
                end
              end
            end
          end
        end
      end
    end
  end
  restore_middle_frame(is_phrase_mode)
end

-- Sample FX write function - writes to sample effects sub-column of note columns
function sample_fx_write(effect, status, command, min_value, max_value)
  local s = renoise.song()
  local a = renoise.app()
  local is_phrase_mode, selection, target_data = get_editor_context()

  -- Retrieve randomization preferences
  local randomize_cb = preferences.pakettiCheatSheet.pakettiCheatSheetRandomize.value
  local fill_percentage = preferences.pakettiCheatSheet.pakettiCheatSheetFillAll.value
  local randomize_whole_track_cb = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeWholeTrack.value
  local randomize_switch = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeSwitch.value
  local dont_overwrite = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeDontOverwrite.value
  local only_modify_notes = preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyNotes.value

  min_value = min_value or preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMin.value
  max_value = max_value or preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMax.value

  if min_value > max_value then
    min_value, max_value = max_value, min_value
  end

  -- Check for slice markers if this is a 0S command
  if effect == "0S" then
    local instrument = s.selected_instrument
    if instrument and instrument.samples[1] and #instrument.samples[1].slice_markers > 0 then
      min_value = 1
      max_value = #instrument.samples[1].slice_markers
    end
  end

  -- Use the full two-character effect code (e.g., "0A", "0S") for sample FX column
  local effect_code_string = effect

  local should_apply = function()
    return math.random(100) <= fill_percentage
  end

  local randomize = function()
    if randomize_switch then
      return string.format("%02X", math.random() < 0.5 and min_value or max_value)
    else
      return string.format("%02X", math.random(min_value, max_value))
    end
  end

  local has_note = function(note_column)
    return note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE and 
           note_column.note_string ~= "OFF"
  end

  if is_phrase_mode then
    -- Phrase Editor mode
    local phrase = target_data.phrase
    local note_columns_visible = phrase.visible_note_columns
    
    -- Make sample effects column visible
    phrase.sample_effects_column_visible = true

    if selection then
      -- Apply to selection in phrase
      local start_column = selection.start_column or 1
      local end_column = math.min(selection.end_column or note_columns_visible, note_columns_visible)
      
      for i = selection.start_line, selection.end_line do
        local line = phrase:line(i)
        for col = start_column, end_column do
          if col <= note_columns_visible then
            local note_column = line.note_columns[col]
            if note_column then
              local should_modify = true
              if only_modify_notes and not has_note(note_column) then
                should_modify = false
              end
              if dont_overwrite and note_column.effect_number_string ~= ".." then
                should_modify = false
              end
              if should_modify then
                if randomize_cb then
                  if should_apply() then
                    note_column.effect_number_string = effect_code_string
                    note_column.effect_amount_string = randomize()
                  end
                else
                  note_column.effect_number_string = effect_code_string
                end
              end
            end
          end
        end
      end
    else
      -- No selection - write to current note column or all note columns if randomize whole track
      local note_col_idx = target_data.note_column_index
      if note_col_idx > 0 and note_col_idx <= note_columns_visible then
        if randomize_cb and randomize_whole_track_cb then
          -- Randomize whole phrase
          for i = 1, phrase.number_of_lines do
            local line = phrase:line(i)
            for col = 1, note_columns_visible do
              local note_column = line.note_columns[col]
              if note_column then
                local should_modify = true
                if only_modify_notes and not has_note(note_column) then
                  should_modify = false
                end
                if dont_overwrite and note_column.effect_number_string ~= ".." then
                  should_modify = false
                end
                if should_modify and should_apply() then
                  note_column.effect_number_string = effect_code_string
                  note_column.effect_amount_string = randomize()
                end
              end
            end
          end
        else
          -- Write to current note column only
          local line = phrase:line(target_data.line_index)
          local note_column = line.note_columns[note_col_idx]
          if note_column then
            if randomize_cb then
              note_column.effect_number_string = effect_code_string
              note_column.effect_amount_string = randomize()
            else
              note_column.effect_number_string = effect_code_string
            end
          end
        end
      else
        a:show_status("Please select a note column to write Sample FX")
        restore_middle_frame(is_phrase_mode)
        return
      end
    end
  else
    -- Pattern Editor mode
    local track = s.selected_track
    if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
      a:show_status("Sample FX can only be written to sequencer tracks")
      restore_middle_frame(is_phrase_mode)
      return
    end

    -- Make sample effects column visible
    track.sample_effects_column_visible = true

    if s.selection_in_pattern then
      -- Apply to selection
      local pattern = s:pattern(s.selected_pattern_index)
      for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
        local sel_track = s:track(t)
        if sel_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          sel_track.sample_effects_column_visible = true
          local pattern_track = pattern:track(t)
          local note_columns_visible = sel_track.visible_note_columns
          local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or 1
          local end_column = (t == s.selection_in_pattern.end_track) and math.min(s.selection_in_pattern.end_column, note_columns_visible) or note_columns_visible
          
          for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
            local line = pattern_track:line(i)
            for col = start_column, end_column do
              if col <= note_columns_visible then
                local note_column = line.note_columns[col]
                if note_column then
                  local should_modify = true
                  if only_modify_notes and not has_note(note_column) then
                    should_modify = false
                  end
                  if dont_overwrite and note_column.effect_number_string ~= ".." then
                    should_modify = false
                  end
                  if should_modify then
                    if randomize_cb then
                      if should_apply() then
                        note_column.effect_number_string = effect_code_string
                        note_column.effect_amount_string = randomize()
                      end
                    else
                      note_column.effect_number_string = effect_code_string
                    end
                  end
                end
              end
            end
          end
        end
      end
    else
      -- No selection
      local note_col_idx = s.selected_note_column_index
      if note_col_idx > 0 and note_col_idx <= track.visible_note_columns then
        if randomize_cb and randomize_whole_track_cb then
          -- Randomize whole track
          local track_index = s.selected_track_index
          for pattern_index = 1, #s.patterns do
            local pattern = s:pattern(pattern_index)
            local pattern_track = pattern:track(track_index)
            local lines = pattern.number_of_lines
            for i = 1, lines do
              local line = pattern_track:line(i)
              for col = 1, track.visible_note_columns do
                local note_column = line.note_columns[col]
                if note_column then
                  local should_modify = true
                  if only_modify_notes and not has_note(note_column) then
                    should_modify = false
                  end
                  if dont_overwrite and note_column.effect_number_string ~= ".." then
                    should_modify = false
                  end
                  if should_modify and should_apply() then
                    note_column.effect_number_string = effect_code_string
                    note_column.effect_amount_string = randomize()
                  end
                end
              end
            end
          end
        else
          -- Write to current note column only
          local line = s.selected_line
          local note_column = line.note_columns[note_col_idx]
          if note_column then
            if randomize_cb then
              note_column.effect_number_string = effect_code_string
              note_column.effect_amount_string = randomize()
            else
              note_column.effect_number_string = effect_code_string
            end
          end
        end
      else
        a:show_status("Please select a note column to write Sample FX")
        restore_middle_frame(is_phrase_mode)
        return
      end
    end
  end

  a:show_status("Sample FX: " .. status)
  restore_middle_frame(is_phrase_mode)
end

-- Clear sample FX columns function
function Cheatsheetclear_sample_fx_columns()
  local s = renoise.song()
  local is_phrase_mode, selection, target_data = get_editor_context()
  
  if is_phrase_mode then
    -- Phrase Editor mode
    local phrase = target_data.phrase
    local note_columns_visible = phrase.visible_note_columns
    
    if selection then
      -- Clear selection in phrase
      local start_column = selection.start_column or 1
      local end_column = math.min(selection.end_column or note_columns_visible, note_columns_visible)
      
      for i = selection.start_line, selection.end_line do
        local line = phrase:line(i)
        for col = start_column, end_column do
          if col <= note_columns_visible then
            local note_column = line.note_columns[col]
            if note_column then
              note_column.effect_number_string = ".."
              note_column.effect_amount_string = ".."
            end
          end
        end
      end
    else
      -- Clear current note column
      local note_col_idx = target_data.note_column_index
      if note_col_idx > 0 then
        local line = phrase:line(target_data.line_index)
        local note_column = line.note_columns[note_col_idx]
        if note_column then
          note_column.effect_number_string = "."
          note_column.effect_amount_string = ".."
        end
      end
    end
  else
    -- Pattern Editor mode
    if s.selection_in_pattern then
      -- Clear selection
      local pattern = s:pattern(s.selected_pattern_index)
      for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
        local track = s:track(t)
        if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          local pattern_track = pattern:track(t)
          local note_columns_visible = track.visible_note_columns
          local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or 1
          local end_column = (t == s.selection_in_pattern.end_track) and math.min(s.selection_in_pattern.end_column, note_columns_visible) or note_columns_visible
          
          for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
            local line = pattern_track:line(i)
            for col = start_column, end_column do
              if col <= note_columns_visible then
                local note_column = line.note_columns[col]
                if note_column then
                  note_column.effect_number_string = "."
                  note_column.effect_amount_string = ".."
                end
              end
            end
          end
        end
      end
    else
      -- Clear current note column
      if s.selected_note_column then
        s.selected_note_column.effect_number_string = "."
        s.selected_note_column.effect_amount_string = ".."
      end
    end
  end
  
  renoise.app():show_status("Sample FX columns cleared")
  restore_middle_frame(is_phrase_mode)
end

-- Modified effect_write function with randomization logic

function effect_write(effect, status, command, min_value, max_value)
  local s = renoise.song()
  local a = renoise.app()
  local w = a.window
  local is_phrase_mode, selection, target_data = get_editor_context()

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
    -- Determine which effect column to target
    local target_effect_column_index = nil
    if selection == nil then
      if is_phrase_mode then
        if target_data.note_column_index > 0 then
          target_effect_column_index = 1
        elseif target_data.effect_column_index > 0 then
          target_effect_column_index = target_data.effect_column_index
        else
          target_effect_column_index = 1
        end
      else
        if s.selected_note_column_index > 0 then
          target_effect_column_index = 1
        elseif s.selected_effect_column_index > 0 then
          target_effect_column_index = s.selected_effect_column_index
        else
          target_effect_column_index = 1
        end
      end
    end
    
    if effect == "0C" then
      status = "Random C00/C0F commands applied to effect column."
      randomizeSmatterEffectColumnC0(fill_percentage, target_effect_column_index)
    elseif effect == "0B" then
      status = "Random B00/B01 commands applied to effect column."
      randomizeSmatterEffectColumnB0(fill_percentage, target_effect_column_index)
    else
      status = "Random " .. effect .. " commands applied to effect column."
      randomizeSmatterEffectColumnCustom(effect, fill_percentage, min_value, max_value, target_effect_column_index)
    end
  else
    -- Original logic without randomization
    if is_phrase_mode then
      -- Phrase Editor mode
      local phrase = target_data.phrase
      local note_columns_visible = phrase.visible_note_columns
      local effect_columns_visible = phrase.visible_effect_columns
      
      -- Ensure at least one effect column is visible
      if effect_columns_visible < 1 then
        phrase.visible_effect_columns = 1
        effect_columns_visible = 1
      end
      
      if selection == nil then
        -- Determine which effect column to write to
        local target_effect_column_index = 1
        
        if target_data.note_column_index > 0 then
          target_effect_column_index = 1
        elseif target_data.effect_column_index > 0 then
          target_effect_column_index = target_data.effect_column_index
        end
        
        -- Get the line and write to the target effect column
        if target_effect_column_index <= effect_columns_visible then
          local line = phrase:line(target_data.line_index)
          line.effect_columns[target_effect_column_index].number_string = effect
        else
          a:show_status(status)
          restore_middle_frame(is_phrase_mode)
          return false
        end
      else
        -- Apply to selection in phrase
        local total_columns_visible = note_columns_visible + effect_columns_visible
        local start_column = selection.start_column or (note_columns_visible + 1)
        local end_column = selection.end_column or total_columns_visible

        for i = selection.start_line, selection.end_line do
          local line = phrase:line(i)
          for col = start_column, end_column do
            local column_index = col - note_columns_visible
            if column_index > 0 and column_index <= effect_columns_visible then
              local effect_column = line:effect_column(column_index)
              if effect_column then
                effect_column.number_string = effect
              end
            end
          end
        end
      end
    else
      -- Pattern Editor mode
      if s.selection_in_pattern == nil then
        -- Determine which effect column to write to
        local target_effect_column_index = 1  -- default to first
        
        if s.selected_note_column_index > 0 then
          -- We're in a note column, write to first effect column
          target_effect_column_index = 1
        elseif s.selected_effect_column_index > 0 then
          -- We're in an effect column, write to that specific column
          target_effect_column_index = s.selected_effect_column_index
        end
        
        -- Get the line and write to the target effect column
        local line = s.selected_line
        if line and target_effect_column_index <= s.selected_track.visible_effect_columns then
          line.effect_columns[target_effect_column_index].number_string = effect
        else
          a:show_status(status)
          restore_middle_frame(is_phrase_mode)
          return false
        end
      else
        local pattern = s:pattern(s.selected_pattern_index)
        for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
          local track = s:track(t)
          local pattern_track = pattern:track(t)
          local note_columns_visible = track.visible_note_columns
          local effect_columns_visible = track.visible_effect_columns
          local total_columns_visible = note_columns_visible + effect_columns_visible

          local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or note_columns_visible + 1
          local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or total_columns_visible

          for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
            local line = pattern_track:line(i)
            for col = start_column, end_column do
              local column_index = col - note_columns_visible
              if column_index > 0 and column_index <= effect_columns_visible then
                local effect_column = line:effect_column(column_index)
                if effect_column then
                  effect_column.number_string = effect
                end
              end
            end
          end
        end
      end
    end
  end
  a:show_status(status)
  restore_middle_frame(is_phrase_mode)
end

-- GUI elements
function pakettiPatternEditorCheatsheetDialog()
  local vb = renoise.ViewBuilder()
  local s = renoise.song()

  if dialog and dialog.visible then
    dialog:close()
    return
  end
  
  -- Remember initial mode to preserve it
  local initial_is_phrase_mode = is_phrase_editor_active() and has_valid_phrase()

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
      renoise.app():open_url(wikitooltip)
    end
  }

  -- Track if we're in phrase mode for dynamic button states
  local current_is_phrase_mode = is_phrase_editor_active() and has_valid_phrase()
  
  -- Store button view IDs for dynamic updates
  local effect_button_ids = {}
  
  -- Write mode switch: 1 = Effect Columns, 2 = Sample FX
  local write_mode_switch = vb:switch{
    id = "cheatsheet_write_mode_switch",
    width = 200,
    items = {"Effect Columns", "Sample FX"},
    value = cheatsheet_write_mode,
    notifier = function(index)
      cheatsheet_write_mode = index
      -- Update button states based on new mode
      local is_phrase_now = is_phrase_editor_active() and has_valid_phrase()
      for _, btn_info in ipairs(effect_button_ids) do
        local view = vb.views[btn_info.id]
        if view then
          local is_active = true
          if cheatsheet_write_mode == 2 then
            -- Sample FX mode - only allow sample FX valid effects
            is_active = is_effect_valid_for_sample_fx(btn_info.code)
          else
            -- Effect Columns mode - check phrase mode
            if is_phrase_now then
              is_active = btn_info.valid_for_phrase
            end
          end
          view.active = is_active
        end
      end
      -- Update clear button text
      local clear_btn = vb.views["cheatsheet_clear_button"]
      if clear_btn then
        if cheatsheet_write_mode == 2 then
          clear_btn.text = "Clear Sample FX"
          clear_btn.tooltip = "Clear all sample FX in selection"
        else
          clear_btn.text = "Clear Effects"
          clear_btn.tooltip = "Clear all effect columns in selection"
        end
      end
    end
  }
  
  -- Function to determine if button should be active based on current modes
  local function is_button_active(effect_code, is_phrase_now)
    if cheatsheet_write_mode == 2 then
      -- Sample FX mode - only allow sample FX valid effects
      return is_effect_valid_for_sample_fx(effect_code)
    else
      -- Effect Columns mode - check phrase mode
      if is_phrase_now then
        return is_effect_valid_for_phrase(effect_code)
      end
      return true
    end
  end
  
  local effect_buttons = vb:column{
    vb:row{
      vb:text{text = "Write to:", style = "strong"},
      write_mode_switch
    }
  }
  for i, effect in ipairs(effects) do
    local effect_code = effect[1]
    local is_valid_for_phrase = is_effect_valid_for_phrase(effect_code)
    local is_valid_for_sample_fx = is_effect_valid_for_sample_fx(effect_code)
    local button_id = "effect_btn_" .. effect_code
    effect_button_ids[i] = {
      id = button_id, 
      code = effect_code, 
      valid_for_phrase = is_valid_for_phrase,
      valid_for_sample_fx = is_valid_for_sample_fx
    }
    
    local button = vb:button{
      id = button_id,
      width=globalwidth,
      text = effect[2],
      tooltip = effect[3],
      active = is_button_active(effect_code, current_is_phrase_mode),
      pressed = function()
        local is_phrase_now = is_phrase_editor_active() and has_valid_phrase()
        
        if cheatsheet_write_mode == 2 then
          -- Sample FX mode
          if not is_effect_valid_for_sample_fx(effect_code) then
            renoise.app():show_status("Effect " .. effect[2] .. " is not available for Sample FX columns")
            return
          end
          sample_fx_write(effect[1], effect[2] .. " - " .. effect[3], effect[2], effect[4], effect[5])
        else
          -- Effect Columns mode
          if is_phrase_now and not is_effect_valid_for_phrase(effect_code) then
            renoise.app():show_status("Effect " .. effect[2] .. " is not available in Phrase Editor")
            return
          end
          effect_write(effect[1], effect[2] .. " - " .. effect[3], effect[2], effect[4], effect[5])
        end
        restore_middle_frame(is_phrase_now)
      end
    }
    local desc = vb:text{text = effect[3]}
    effect_buttons:add_child(vb:row{button, desc})
  end
  
  -- Function to update button states based on phrase mode and write mode
  local function update_button_states()
    local is_phrase_now = is_phrase_editor_active() and has_valid_phrase()
    if is_phrase_now ~= current_is_phrase_mode then
      current_is_phrase_mode = is_phrase_now
      for _, btn_info in ipairs(effect_button_ids) do
        local view = vb.views[btn_info.id]
        if view then
          local is_active = true
          if cheatsheet_write_mode == 2 then
            -- Sample FX mode - only allow sample FX valid effects
            is_active = is_effect_valid_for_sample_fx(btn_info.code)
          else
            -- Effect Columns mode - check phrase mode
            if is_phrase_now then
              is_active = btn_info.valid_for_phrase
            end
          end
          view.active = is_active
        end
      end
    end
  end
  
  -- Timer to check and update button states
  local button_update_timer = nil
  local function start_button_update_timer()
    if button_update_timer and renoise.tool():has_timer(button_update_timer) then
      return
    end
    button_update_timer = function()
      if dialog and dialog.visible then
        update_button_states()
      else
        -- Stop timer when dialog is closed
        if renoise.tool():has_timer(button_update_timer) then
          renoise.tool():remove_timer(button_update_timer)
        end
        button_update_timer = nil
      end
    end
    renoise.tool():add_timer(button_update_timer, 200)
  end
  
  -- Start the timer
  start_button_update_timer()

  -- Randomization Preferences UI Elements
  local randomize_cb = vb:checkbox{
    value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomize.value,
    notifier=function(v)
      preferences.pakettiCheatSheet.pakettiCheatSheetRandomize.value = v
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
      end
    end
  }

  local randomize_whole_track_cb = vb:checkbox{
    value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeWholeTrack.value,
    notifier=function(v)
      preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeWholeTrack.value = v
    end
  }

  local randomizeswitch_cb = vb:checkbox{
    value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeSwitch.value,
    notifier=function(v)
      preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeSwitch.value = v
    end
  }

  local dontoverwrite_cb = vb:checkbox{
    value = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeDontOverwrite.value,
    notifier=function(v)
      preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeDontOverwrite.value = v
    end
  }

  local only_modify_effects_cb = vb:checkbox{
    value = preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyEffects.value,
    notifier=function(v)
      preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyEffects.value = v
    end
  }

  local only_modify_notes_cb = vb:checkbox{
    value = preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyNotes.value,
    notifier=function(v)
      preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyNotes.value = v
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
      
      -- Check if Randomize is enabled first
      local randomize_cb_val = preferences.pakettiCheatSheet.pakettiCheatSheetRandomize.value
      local is_phrase_mode_local, selection_local, target_data_local = get_editor_context()
      if not randomize_cb_val then
        restore_middle_frame(is_phrase_mode_local)
        return
      end
      
      trueRandomSeed()
      local s = renoise.song()
      local min_val = v
      local max_val = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMax.value
      local randomize_switch = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeSwitch.value
      local dont_overwrite = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeDontOverwrite.value
      local only_modify_effects = preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyEffects.value
      local only_modify_notes = preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyNotes.value
      local fill_percentage = preferences.pakettiCheatSheet.pakettiCheatSheetFillAll.value
      
      if min_val > max_val then
        min_val, max_val = max_val, min_val
      end
      
      local should_apply = function()
        return math.random(100) <= fill_percentage
      end
      
      local has_notes_in_line_generic = function(line, visible_columns)
        for i = 1, visible_columns do
          local note_column = line.note_columns[i]
          if note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE and 
             note_column.note_string ~= "OFF" then
            return true
          end
        end
        return false
      end
      
      if is_phrase_mode_local then
        -- Phrase Editor mode
        local phrase = target_data_local.phrase
        local note_columns_visible = phrase.visible_note_columns
        local effect_columns_visible = phrase.visible_effect_columns
        
        if effect_columns_visible < 1 then
          phrase.visible_effect_columns = 1
          effect_columns_visible = 1
        end
        
        if selection_local then
          local total_columns_visible = note_columns_visible + effect_columns_visible
          local start_column = selection_local.start_column or (note_columns_visible + 1)
          local end_column = selection_local.end_column or total_columns_visible
          for i = selection_local.start_line, selection_local.end_line do
            local line = phrase:line(i)
            for col = start_column, end_column do
              local column_index = col - note_columns_visible
              if column_index > 0 and column_index <= effect_columns_visible then
                local effect_column = line:effect_column(column_index)
                if effect_column then
                  local should_modify = true
                  if only_modify_notes and not has_notes_in_line_generic(line, note_columns_visible) then
                    should_modify = false
                  end
                  if dont_overwrite and not effect_column.is_empty then
                    should_modify = false
                  end
                  if only_modify_effects and effect_column.is_empty then
                    should_modify = false
                  end
                  if should_modify and should_apply() then
                    if randomize_switch then
                      effect_column.amount_value = math.random() < 0.5 and min_val or max_val
                    else
                      effect_column.amount_value = math.random(min_val, max_val)
                    end
                  end
                end
              end
            end
          end
        else
          local target_effect_column_index = 1
          if target_data_local.note_column_index > 0 then
            target_effect_column_index = 1
          elseif target_data_local.effect_column_index > 0 then
            target_effect_column_index = target_data_local.effect_column_index
          end
          if target_effect_column_index <= effect_columns_visible then
            local line = phrase:line(target_data_local.line_index)
            if should_apply() then
              if randomize_switch then
                line.effect_columns[target_effect_column_index].amount_value = math.random() < 0.5 and min_val or max_val
              else
                line.effect_columns[target_effect_column_index].amount_value = math.random(min_val, max_val)
              end
            end
          end
        end
      else
        -- Pattern Editor mode
        sliderVisibleEffect()
        if s.selection_in_pattern then
          local pattern = s:pattern(s.selected_pattern_index)
          for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
            local track = s:track(t)
            if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
              local pattern_track = pattern:track(t)
              local note_columns_visible = track.visible_note_columns
              local effect_columns_visible = track.visible_effect_columns
              local total_columns_visible = note_columns_visible + effect_columns_visible
              local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or note_columns_visible + 1
              local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or total_columns_visible
              for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
                local line = pattern_track:line(i)
                for col = start_column, end_column do
                  local column_index = col - note_columns_visible
                  if column_index > 0 and column_index <= effect_columns_visible then
                    local effect_column = line:effect_column(column_index)
                    if effect_column then
                      local should_modify = true
                      if only_modify_notes and not has_notes_in_line_generic(line, note_columns_visible) then
                        should_modify = false
                      end
                      if dont_overwrite and not effect_column.is_empty then
                        should_modify = false
                      end
                      if only_modify_effects and effect_column.is_empty then
                        should_modify = false
                      end
                      if should_modify and should_apply() then
                        if randomize_switch then
                          effect_column.amount_value = math.random() < 0.5 and min_val or max_val
                        else
                          effect_column.amount_value = math.random(min_val, max_val)
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        else
          local target_effect_column_index = 1
          if s.selected_note_column_index > 0 then
            target_effect_column_index = 1
          elseif s.selected_effect_column_index > 0 then
            target_effect_column_index = s.selected_effect_column_index
          end
          local line = s.selected_line
          if line and target_effect_column_index <= s.selected_track.visible_effect_columns then
            if should_apply() then
              if randomize_switch then
                line.effect_columns[target_effect_column_index].amount_value = math.random() < 0.5 and min_val or max_val
              else
                line.effect_columns[target_effect_column_index].amount_value = math.random(min_val, max_val)
              end
            end
          end
        end
      end
      restore_middle_frame(is_phrase_mode_local)
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
      
      -- Check if Randomize is enabled first
      local randomize_cb_val = preferences.pakettiCheatSheet.pakettiCheatSheetRandomize.value
      local is_phrase_mode_local, selection_local, target_data_local = get_editor_context()
      if not randomize_cb_val then
        restore_middle_frame(is_phrase_mode_local)
        return
      end
      
      trueRandomSeed()
      local s = renoise.song()
      local min_val = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeMin.value
      local max_val = v
      local randomize_switch = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeSwitch.value
      local dont_overwrite = preferences.pakettiCheatSheet.pakettiCheatSheetRandomizeDontOverwrite.value
      local only_modify_effects = preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyEffects.value
      local only_modify_notes = preferences.pakettiCheatSheet.pakettiCheatSheetOnlyModifyNotes.value
      local fill_percentage = preferences.pakettiCheatSheet.pakettiCheatSheetFillAll.value
      
      if min_val > max_val then
        min_val, max_val = max_val, min_val
      end
      
      local should_apply = function()
        return math.random(100) <= fill_percentage
      end
      
      local has_notes_in_line_generic = function(line, visible_columns)
        for i = 1, visible_columns do
          local note_column = line.note_columns[i]
          if note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE and 
             note_column.note_string ~= "OFF" then
            return true
          end
        end
        return false
      end
      
      if is_phrase_mode_local then
        -- Phrase Editor mode
        local phrase = target_data_local.phrase
        local note_columns_visible = phrase.visible_note_columns
        local effect_columns_visible = phrase.visible_effect_columns
        
        if effect_columns_visible < 1 then
          phrase.visible_effect_columns = 1
          effect_columns_visible = 1
        end
        
        if selection_local then
          local total_columns_visible = note_columns_visible + effect_columns_visible
          local start_column = selection_local.start_column or (note_columns_visible + 1)
          local end_column = selection_local.end_column or total_columns_visible
          for i = selection_local.start_line, selection_local.end_line do
            local line = phrase:line(i)
            for col = start_column, end_column do
              local column_index = col - note_columns_visible
              if column_index > 0 and column_index <= effect_columns_visible then
                local effect_column = line:effect_column(column_index)
                if effect_column then
                  local should_modify = true
                  if only_modify_notes and not has_notes_in_line_generic(line, note_columns_visible) then
                    should_modify = false
                  end
                  if dont_overwrite and not effect_column.is_empty then
                    should_modify = false
                  end
                  if only_modify_effects and effect_column.is_empty then
                    should_modify = false
                  end
                  if should_modify and should_apply() then
                    if randomize_switch then
                      effect_column.amount_value = math.random() < 0.5 and min_val or max_val
                    else
                      effect_column.amount_value = math.random(min_val, max_val)
                    end
                  end
                end
              end
            end
          end
        else
          local target_effect_column_index = 1
          if target_data_local.note_column_index > 0 then
            target_effect_column_index = 1
          elseif target_data_local.effect_column_index > 0 then
            target_effect_column_index = target_data_local.effect_column_index
          end
          if target_effect_column_index <= effect_columns_visible then
            local line = phrase:line(target_data_local.line_index)
            if should_apply() then
              if randomize_switch then
                line.effect_columns[target_effect_column_index].amount_value = math.random() < 0.5 and min_val or max_val
              else
                line.effect_columns[target_effect_column_index].amount_value = math.random(min_val, max_val)
              end
            end
          end
        end
      else
        -- Pattern Editor mode
        sliderVisibleEffect()
        if s.selection_in_pattern then
          local pattern = s:pattern(s.selected_pattern_index)
          for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
            local track = s:track(t)
            if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
              local pattern_track = pattern:track(t)
              local note_columns_visible = track.visible_note_columns
              local effect_columns_visible = track.visible_effect_columns
              local total_columns_visible = note_columns_visible + effect_columns_visible
              local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or note_columns_visible + 1
              local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or total_columns_visible
              for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
                local line = pattern_track:line(i)
                for col = start_column, end_column do
                  local column_index = col - note_columns_visible
                  if column_index > 0 and column_index <= effect_columns_visible then
                    local effect_column = line:effect_column(column_index)
                    if effect_column then
                      local should_modify = true
                      if only_modify_notes and not has_notes_in_line_generic(line, note_columns_visible) then
                        should_modify = false
                      end
                      if dont_overwrite and not effect_column.is_empty then
                        should_modify = false
                      end
                      if only_modify_effects and effect_column.is_empty then
                        should_modify = false
                      end
                      if should_modify and should_apply() then
                        if randomize_switch then
                          effect_column.amount_value = math.random() < 0.5 and min_val or max_val
                        else
                          effect_column.amount_value = math.random(min_val, max_val)
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        else
          local target_effect_column_index = 1
          if s.selected_note_column_index > 0 then
            target_effect_column_index = 1
          elseif s.selected_effect_column_index > 0 then
            target_effect_column_index = s.selected_effect_column_index
          end
          local line = s.selected_line
          if line and target_effect_column_index <= s.selected_track.visible_effect_columns then
            if should_apply() then
              if randomize_switch then
                line.effect_columns[target_effect_column_index].amount_value = math.random() < 0.5 and min_val or max_val
              else
                line.effect_columns[target_effect_column_index].amount_value = math.random(min_val, max_val)
              end
            end
          end
        end
      end
      restore_middle_frame(is_phrase_mode_local)
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
      id = "cheatsheet_clear_button",
      text = cheatsheet_write_mode == 2 and "Clear Sample FX" or "Clear Effects",
      tooltip = cheatsheet_write_mode == 2 and "Clear all sample FX in selection" or "Clear all effect columns in selection",
      width=globalwidth,
      pressed = function()
        if cheatsheet_write_mode == 2 then
          Cheatsheetclear_sample_fx_columns()
        else
          Cheatsheetclear_effect_columns()
        end
      end
    },
    vb:button{
      text="Minimize Horizontal",
      tooltip = "Open the minimized cheatsheet dialog (horizontal layout)",
      width=globalwidth,
      pressed = function()
        pakettiMiniCheatsheetHorizontal()
      end
    },
    vb:button{
      text="Minimize Vertical",
      tooltip = "Open the minimized cheatsheet dialog (vertical layout)",
      width=globalwidth,
      pressed = function()
        pakettiMiniCheatsheetVertical()
      end
    },
    vb:button{text="Close",width=globalwidth, pressed = function()
      dialog:close()
    end}
  }

  -- Helper function for note column slider notifiers (supports phrase and pattern editor)
  local function apply_note_column_value(column_name, value)
    local s = renoise.song()
    local is_phrase_mode_local, selection_local, target_data_local = get_editor_context()
    
    if is_phrase_mode_local then
      -- Phrase Editor mode
      local phrase = target_data_local.phrase
      -- Make column visible in phrase
      if column_name == "volume_value" then
        phrase.volume_column_visible = true
      elseif column_name == "panning_value" then
        phrase.panning_column_visible = true
      elseif column_name == "delay_value" then
        phrase.delay_column_visible = true
      elseif column_name == "effect_amount_value" then
        phrase.sample_effects_column_visible = true
      end
      
      local note_columns_visible = phrase.visible_note_columns
      
      if selection_local then
        local start_column = selection_local.start_column or 1
        local end_column = selection_local.end_column or note_columns_visible
        for i = selection_local.start_line, selection_local.end_line do
          local line = phrase:line(i)
          for col = start_column, end_column do
            if col <= note_columns_visible then
              local note_column = line.note_columns[col]
              if note_column then
                note_column[column_name] = value
              end
            end
          end
        end
      else
        local note_col_idx = target_data_local.note_column_index
        if note_col_idx > 0 then
          local line = phrase:line(target_data_local.line_index)
          local note_column = line:note_column(note_col_idx)
          if note_column then
            note_column[column_name] = value
          end
        end
      end
    else
      -- Pattern Editor mode
      if column_name == "volume_value" then
        sliderVisible("volume")
      elseif column_name == "panning_value" then
        sliderVisible("panning")
      elseif column_name == "delay_value" then
        sliderVisible("delay")
      elseif column_name == "effect_amount_value" then
        sliderVisible("samplefx")
      end
      
      if s.selection_in_pattern then
        local pattern = s:pattern(s.selected_pattern_index)
        for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
          local track = s:track(t)
          if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
            local pattern_track = pattern:track(t)
            local note_columns_visible = track.visible_note_columns
            local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or 1
            local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or note_columns_visible
            for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
              local line = pattern_track:line(i)
              for col = start_column, end_column do
                if col <= note_columns_visible then
                  local note_column = line.note_columns[col]
                  if note_column then
                    note_column[column_name] = value
                  end
                end
              end
            end
          end
        end
      else
        if s.selected_note_column then
          s.selected_note_column[column_name] = value
        end
      end
    end
    restore_middle_frame(is_phrase_mode_local)
  end
  
  -- Helper function for effect column slider notifier (supports phrase and pattern editor)
  local function apply_effect_column_value(value)
    local s = renoise.song()
    local is_phrase_mode_local, selection_local, target_data_local = get_editor_context()
    
    if is_phrase_mode_local then
      -- Phrase Editor mode
      local phrase = target_data_local.phrase
      local note_columns_visible = phrase.visible_note_columns
      local effect_columns_visible = phrase.visible_effect_columns
      
      if effect_columns_visible < 1 then
        phrase.visible_effect_columns = 1
        effect_columns_visible = 1
      end
      
      if selection_local then
        local total_columns_visible = note_columns_visible + effect_columns_visible
        local start_column = selection_local.start_column or (note_columns_visible + 1)
        local end_column = selection_local.end_column or total_columns_visible
        for i = selection_local.start_line, selection_local.end_line do
          local line = phrase:line(i)
          for col = start_column, end_column do
            local column_index = col - note_columns_visible
            if column_index > 0 and column_index <= effect_columns_visible then
              local effect_column = line:effect_column(column_index)
              if effect_column then
                effect_column.amount_value = value
              end
            end
          end
        end
      else
        local target_effect_column_index = 1
        if target_data_local.note_column_index > 0 then
          target_effect_column_index = 1
        elseif target_data_local.effect_column_index > 0 then
          target_effect_column_index = target_data_local.effect_column_index
        end
        if target_effect_column_index <= effect_columns_visible then
          local line = phrase:line(target_data_local.line_index)
          line.effect_columns[target_effect_column_index].amount_value = value
        end
      end
    else
      -- Pattern Editor mode
      sliderVisibleEffect()
      if s.selection_in_pattern then
        local pattern = s:pattern(s.selected_pattern_index)
        for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
          local track = s:track(t)
          if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
            local pattern_track = pattern:track(t)
            local note_columns_visible = track.visible_note_columns
            local effect_columns_visible = track.visible_effect_columns
            local total_columns_visible = note_columns_visible + effect_columns_visible
            local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or note_columns_visible + 1
            local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or total_columns_visible
            for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
              local line = pattern_track:line(i)
              for col = start_column, end_column do
                local column_index = col - note_columns_visible
                if column_index > 0 and column_index <= effect_columns_visible then
                  local effect_column = line:effect_column(column_index)
                  if effect_column then
                    effect_column.amount_value = value
                  end
                end
              end
            end
          end
        end
      else
        local target_effect_column_index = 1
        if s.selected_note_column_index > 0 then
          target_effect_column_index = 1
        elseif s.selected_effect_column_index > 0 then
          target_effect_column_index = s.selected_effect_column_index
        end
        local line = s.selected_line
        if line and target_effect_column_index <= s.selected_track.visible_effect_columns then
          line.effect_columns[target_effect_column_index].amount_value = value
        end
      end
    end
    restore_middle_frame(is_phrase_mode_local)
  end

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
        end
      },
      vb:minislider {
        id = "volumeslider",
        width=50,
        height = eSlider,
        min = 0,
        max = 0x80,
        notifier=function(v)
          apply_note_column_value("volume_value", v)
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
        end
      },
      vb:minislider {
        id = "panningslider",
        width=50,
        height = eSlider,
        min = 0,
        max = 0x80,
        notifier=function(v)
          apply_note_column_value("panning_value", v)
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
        end
      },
      vb:minislider {
        id = "delayslider",
        width=50,
        height = eSlider,
        min = 0,
        max = 0xFF,
        notifier=function(v)
          apply_note_column_value("delay_value", v)
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
        end
      },
      vb:minislider {
        id = "samplefxslider",
        width=50,
        height = eSlider,
        min = 0,
        max = 0x80,
        notifier=function(v)
          apply_note_column_value("effect_amount_value", v)
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
        end
      },
      vb:minislider {
        id = "effectslider",
        width=50,
        height = eSlider,
        min = 0,
        max = 0xFF,
        notifier=function(v)
          apply_effect_column_value(v)
        end
      }
    }
  }

  local left_column=vb:column{effect_buttons,randomize_section}
  local dialog_content=vb:row{left_column,sliders}

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) 
      dialog = value 
    end
  )
  dialog = renoise.app():show_custom_dialog("Paketti Effect Command CheatSheet", dialog_content, keyhandler)
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
  local s = renoise.song()
  local is_phrase_mode, selection, target_data = get_editor_context()
  
  if is_phrase_mode then
    -- Phrase Editor mode
    local phrase = target_data.phrase
    local note_columns_visible = phrase.visible_note_columns
    local effect_columns_visible = phrase.visible_effect_columns
    
    -- Ensure at least one effect column is visible
    if effect_columns_visible < 1 then
      phrase.visible_effect_columns = 1
      effect_columns_visible = 1
    end
    
    if selection then
      -- Apply to selection in phrase
      local total_columns_visible = note_columns_visible + effect_columns_visible
      local start_column = selection.start_column or (note_columns_visible + 1)
      local end_column = selection.end_column or total_columns_visible
      for i = selection.start_line, selection.end_line do
        local line = phrase:line(i)
        for col = start_column, end_column do
          local column_index = col - note_columns_visible
          if column_index > 0 and column_index <= effect_columns_visible then
            local effect_column = line:effect_column(column_index)
            if effect_column then
              effect_column.number_string = effect_command
              effect_column.amount_value = hex_value
            end
          end
        end
      end
    else
      -- Determine which effect column to write to
      local target_effect_column_index = 1
      
      if target_data.note_column_index > 0 then
        target_effect_column_index = 1
      elseif target_data.effect_column_index > 0 then
        target_effect_column_index = target_data.effect_column_index
      end
      
      -- Get the line and write to the target effect column
      if target_effect_column_index <= effect_columns_visible then
        local line = phrase:line(target_data.line_index)
        line.effect_columns[target_effect_column_index].number_string = effect_command
        line.effect_columns[target_effect_column_index].amount_value = hex_value
      end
    end
  else
    -- Pattern Editor mode
    sliderVisibleEffect()
    if s.selection_in_pattern then
      local pattern = s:pattern(s.selected_pattern_index)
      for t = s.selection_in_pattern.start_track, s.selection_in_pattern.end_track do
        local track = s:track(t)
        if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          local pattern_track = pattern:track(t)
          local note_columns_visible = track.visible_note_columns
          local effect_columns_visible = track.visible_effect_columns
          local total_columns_visible = note_columns_visible + effect_columns_visible
          local start_column = (t == s.selection_in_pattern.start_track) and s.selection_in_pattern.start_column or note_columns_visible + 1
          local end_column = (t == s.selection_in_pattern.end_track) and s.selection_in_pattern.end_column or total_columns_visible
          for i = s.selection_in_pattern.start_line, s.selection_in_pattern.end_line do
            local line = pattern_track:line(i)
            for col = start_column, end_column do
              local column_index = col - note_columns_visible
              if column_index > 0 and column_index <= effect_columns_visible then
                local effect_column = line:effect_column(column_index)
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
      -- Determine which effect column to write to
      local target_effect_column_index = 1  -- default to first
      
      if s.selected_note_column_index > 0 then
        -- We're in a note column, write to first effect column
        target_effect_column_index = 1
      elseif s.selected_effect_column_index > 0 then
        -- We're in an effect column, write to that specific column
        target_effect_column_index = s.selected_effect_column_index
      end
      
      -- Get the line and write to the target effect column
      local line = s.selected_line
      if line and target_effect_column_index <= s.selected_track.visible_effect_columns then
        line.effect_columns[target_effect_column_index].number_string = effect_command
        line.effect_columns[target_effect_column_index].amount_value = hex_value
      end
    end
  end
  restore_middle_frame(is_phrase_mode)
end

-- Persistent state for mini cheatsheet
local mini_selected_effect_index = 1
local mini_hex_value = 128  -- Start at 0x80 (50%)

-- Helper to build filtered effects list based on phrase mode
local function get_filtered_effects_for_mode(is_phrase_mode)
  local filtered = {}
  local index_map = {}  -- Maps filtered index to original index
  for i, effect in ipairs(mini_effects) do
    if not is_phrase_mode or is_effect_valid_for_phrase(effect[1]) then
      table.insert(filtered, effect)
      index_map[#filtered] = i
    end
  end
  return filtered, index_map
end

function pakettiMiniCheatsheetHorizontal()
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

  -- Check if we're in phrase mode
  local is_phrase_mode = is_phrase_editor_active() and has_valid_phrase()
  local filtered_effects, index_map = get_filtered_effects_for_mode(is_phrase_mode)
  
  -- Create dropdown items from filtered effects
  local dropdown_items = {}
  for i, effect in ipairs(filtered_effects) do
    dropdown_items[i] = effect[2] .. " - " .. effect[3]
  end

  -- Find current selection in filtered list
  local selected_effect_index = 1
  for i, effect in ipairs(filtered_effects) do
    if effect[1] == mini_effects[mini_selected_effect_index][1] then
      selected_effect_index = i
      break
    end
  end
  local hex_value = mini_hex_value

  local percentage_text = vb:text{
    text = string.format("%d%% Fill (0x%02X)", math.floor((hex_value / 255) * 100), hex_value)
  }
  
  -- Mode indicator text
  local mode_text = vb:text{
    text = is_phrase_mode and "[Phrase Mode]" or "[Pattern Mode]",
    font = "italic"
  }

  -- Apply random effect
  local function apply_random_effect()
    local random_index = math.random(1, #filtered_effects)
    selected_effect_index = random_index
    mini_selected_effect_index = index_map[random_index]  -- Update persistent state with original index
    local selected_effect = filtered_effects[selected_effect_index]
    apply_mini_effect_direct(selected_effect[1], hex_value)
    renoise.app():show_status(string.format("Random effect: %s", selected_effect[2]))
    -- Update the dropdown to show the randomly selected effect
    if mini_dialog and mini_dialog.visible then
      mini_dialog:close()
      pakettiMiniCheatsheetHorizontal()
    end
  end

  local dialog_content = vb:column{
    vb:row{
      spacing = 10,
      mode_text,
      vb:popup{
        items = dropdown_items,
        value = selected_effect_index,
        width = 420,
        notifier = function(index)
          selected_effect_index = index
          mini_selected_effect_index = index_map[index]  -- Update persistent state with original index
          -- Apply effect when dropdown changes
          local selected_effect = filtered_effects[selected_effect_index]
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
          local selected_effect = filtered_effects[selected_effect_index]
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
function pakettiMiniCheatsheetVertical()
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

  -- Check if we're in phrase mode
  local is_phrase_mode = is_phrase_editor_active() and has_valid_phrase()
  local filtered_effects, index_map = get_filtered_effects_for_mode(is_phrase_mode)
  
  -- Create dropdown items from filtered effects
  local dropdown_items = {}
  for i, effect in ipairs(filtered_effects) do
    dropdown_items[i] = effect[2] .. " - " .. effect[3]
  end

  -- Find current selection in filtered list
  local selected_effect_index = 1
  for i, effect in ipairs(filtered_effects) do
    if effect[1] == mini_effects[mini_selected_effect_index][1] then
      selected_effect_index = i
      break
    end
  end
  local hex_value = mini_hex_value

  local percentage_text = vb:text{
    style = "strong",
    font = "bold",
    text = string.format("%03d%% Fill (0x%02X)", math.floor((hex_value / 255) * 100), hex_value)
  }
  
  -- Mode indicator text
  local mode_text = vb:text{
    text = is_phrase_mode and "[Phrase]" or "[Pattern]",
    font = "italic"
  }

  -- Apply random effect
  local function apply_random_effect()
    local random_index = math.random(1, #filtered_effects)
    selected_effect_index = random_index
    mini_selected_effect_index = index_map[random_index]  -- Update persistent state with original index
    local selected_effect = filtered_effects[selected_effect_index]
    apply_mini_effect_direct(selected_effect[1], hex_value)
    renoise.app():show_status(string.format("Random effect: %s", selected_effect[2]))
    -- Update the dropdown to show the randomly selected effect
    if mini_dialog and mini_dialog.visible then
      mini_dialog:close()
      pakettiMiniCheatsheetVertical()
    end
  end

  -- Apply random value
  local function apply_random_value()
    hex_value = math.random(0, 255)
    mini_hex_value = hex_value  -- Update persistent state
    local percentage = math.floor((hex_value / 255) * 100)
    percentage_text.text = string.format("%03d%% Fill (0x%02X)", percentage, hex_value)
    -- Apply effect with new random value
    local selected_effect = filtered_effects[selected_effect_index]
    apply_mini_effect_direct(selected_effect[1], hex_value)
    renoise.app():show_status(string.format("Random value: 0x%02X (%03d%%)", hex_value, percentage))
  end

  local dialog_content = vb:column{
    -- Mode indicator at top
    vb:horizontal_aligner{
      mode = "center",
      mode_text
    },
    
    -- Dropdown at top
    vb:popup{
      items = dropdown_items,
      value = selected_effect_index,
      width = 100,
      notifier = function(index)
        selected_effect_index = index
        mini_selected_effect_index = index_map[index]  -- Update persistent state with original index
        -- Apply effect when dropdown changes
        local selected_effect = filtered_effects[selected_effect_index]
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
          local selected_effect = filtered_effects[selected_effect_index]
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

renoise.tool():add_keybinding{name = "Global:Paketti:Show Minimize Cheatsheet Horizontal", invoke = pakettiMiniCheatsheetHorizontal}
renoise.tool():add_keybinding{name = "Global:Paketti:Show Minimize Cheatsheet Vertical", invoke = pakettiMiniCheatsheetVertical}


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
  local is_phrase_mode = is_phrase_editor_active() and has_valid_phrase()
  
  if is_phrase_mode then
    -- Phrase Editor mode
    local phrase = song.selected_phrase
    local line_index = song.selected_phrase_line_index
    local effect_column_index = song.selected_phrase_effect_column_index
    local note_column_index = song.selected_phrase_note_column_index
    
    local prefix = "[Phrase] "
    
    -- Check if we're in an effect column in the phrase
    if effect_column_index > 0 then
      local line = phrase:line(line_index)
      local effect_column = line:effect_column(effect_column_index)
      if effect_column and not effect_column.is_empty then
        local effect_number = effect_column.number_string
        local effect_value = effect_column.amount_value
        local display_name, description = get_effect_description(effect_number)
        
        if display_name and description then
          status_text = string.format("%sEffect: %s (0x%02X/255) - %s", 
                                     prefix, display_name, effect_value, description)
        else
          status_text = string.format("%sEffect: %s (0x%02X/255) - Unknown effect", 
                                     prefix, effect_number, effect_value)
        end
      else
        status_text = prefix .. "Effect Column: Empty"
      end
      
    -- Check if we're in a note column in the phrase
    elseif note_column_index > 0 then
      local line = phrase:line(line_index)
      local note_column = line:note_column(note_column_index)
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
        
        -- Instrument (sample) information - in phrases this refers to samples
        if note_column.instrument_value ~= renoise.PatternLine.EMPTY_INSTRUMENT then
          table.insert(parts, string.format("S:%02X", note_column.instrument_value))
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
          status_text = prefix .. table.concat(parts, " ")
        else
          status_text = prefix .. "Empty"
        end
      end
    else
      status_text = prefix .. "Line " .. line_index .. "/" .. phrase.number_of_lines
    end
  else
    -- Pattern Editor mode
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
  
  local current_position = ""
  local is_phrase_mode = is_phrase_editor_active() and has_valid_phrase()
  
  if is_phrase_mode then
    -- Phrase Editor mode - track phrase position
    local phrase_index = song.selected_phrase_index or 0
    local phrase_line_index = song.selected_phrase_line_index or 0
    local phrase_note_column_index = song.selected_phrase_note_column_index or 0
    local phrase_effect_column_index = song.selected_phrase_effect_column_index or 0
    local instrument_index = song.selected_instrument_index or 0
    
    -- Create position hash for phrase mode
    current_position = string.format("PHRASE:%d:%d:%d:%d:%d", 
      instrument_index, phrase_index, phrase_line_index, 
      phrase_note_column_index, phrase_effect_column_index)
  else
    -- Pattern Editor mode - track pattern position
    local track_index = song.selected_track_index
    local line_index = song.selected_line_index
    local note_column_index = song.selected_note_column_index
    local effect_column_index = song.selected_effect_column_index
    local pattern_index = song.selected_pattern_index
    
    -- Create position hash for pattern mode
    current_position = string.format("PATTERN:%d:%d:%d:%d:%d", 
      track_index, line_index, note_column_index, effect_column_index, pattern_index)
  end
  
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
