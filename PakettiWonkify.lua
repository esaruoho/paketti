-- PakettiWonkify.lua
-- Wonkify patterns by randomly modifying note properties
-- Features: Scale-aware pitch drift, Velocity variation, Delay drift, Row drift,
-- Note density, Ghost notes (rolls), Retrigs, Random effect commands,
-- Swing/groove templates, Selection-based operation, Phrase output,
-- Automation wonkification, Preset system, Multi-pattern chain generation

local preferences = renoise.tool().preferences
local wonkify_dialog = nil
local wonkify_quick_dialog = nil

-- Musical keys and scales (borrowed from PakettiArpeggiator pattern)
PakettiWonkify_keys = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

PakettiWonkify_modes = {
  "ionian", "dorian", "phrygian", "lydian", 
  "mixolydian", "aeolian", "locrian",
  "major", "minor", "melodic", "harmonic"
}

PakettiWonkify_scale_data = {
  ionian = {0, 2, 4, 5, 7, 9, 11},
  dorian = {0, 2, 3, 5, 7, 9, 10},
  phrygian = {0, 1, 3, 5, 7, 8, 10},
  lydian = {0, 2, 4, 6, 7, 9, 11},
  mixolydian = {0, 2, 4, 5, 7, 9, 10},
  aeolian = {0, 2, 3, 5, 7, 8, 10},
  locrian = {0, 1, 3, 5, 6, 8, 10},
  major = {0, 2, 4, 5, 7, 9, 11},
  minor = {0, 2, 3, 5, 7, 8, 10},
  melodic = {0, 2, 3, 5, 7, 9, 11},
  harmonic = {0, 2, 3, 5, 7, 8, 11}
}

-- Swing template definitions
PakettiWonkify_swing_templates = {
  {name = "MPC Swing", desc = "Classic 16th note swing"},
  {name = "Drunken", desc = "Random micro-timing per note"},
  {name = "Push", desc = "Notes slightly early"},
  {name = "Pull/Lazy", desc = "Notes slightly late"},
  {name = "Shuffle", desc = "Triplet-ish feel"},
  {name = "Human Drummer", desc = "Varying delay based on beat position"},
  {name = "Custom", desc = "Use DelayDrift settings"}
}

-- Built-in preset definitions
PakettiWonkify_builtin_presets = {
  {
    name = "Subtle Humanize",
    settings = {
      DelayDriftEnabled = true, DelayDriftPercentage = 25, DelayDriftMax = 16,
      VelocityEnabled = true, VelocityPercentage = 40, VelocityVariation = 15,
      SwingEnabled = false, EffectsEnabled = false, PitchDriftEnabled = false,
      RowDriftEnabled = false, DensityEnabled = false, GhostEnabled = false,
      RetrigEnabled = false, AutomationEnabled = false
    }
  },
  {
    name = "Drunk Groove",
    settings = {
      SwingEnabled = true, SwingTemplate = 2, SwingAmount = 70,
      DelayDriftEnabled = true, DelayDriftPercentage = 50, DelayDriftMax = 48,
      RowDriftEnabled = true, RowDriftPercentage = 15, RowDriftMax = 1,
      VelocityEnabled = true, VelocityPercentage = 30, VelocityVariation = 25,
      EffectsEnabled = false, PitchDriftEnabled = false, DensityEnabled = false,
      GhostEnabled = false, RetrigEnabled = false, AutomationEnabled = false
    }
  },
  {
    name = "Lo-Fi Grit",
    settings = {
      VelocityEnabled = true, VelocityPercentage = 60, VelocityVariation = 40,
      DensityEnabled = true, DensityAddPercentage = 0, DensityRemovePercentage = 8,
      EffectsEnabled = true, EffectsPercentage = 20, Effect_0Y_Enabled = true,
      DelayDriftEnabled = true, DelayDriftPercentage = 20, DelayDriftMax = 24,
      SwingEnabled = false, PitchDriftEnabled = false, RowDriftEnabled = false,
      GhostEnabled = false, RetrigEnabled = false, AutomationEnabled = false
    }
  },
  {
    name = "Glitchy",
    settings = {
      RowDriftEnabled = true, RowDriftPercentage = 35, RowDriftMax = 3,
      RetrigEnabled = true, RetrigPercentage = 25, RetrigMin = 2, RetrigMax = 8,
      EffectsEnabled = true, EffectsPercentage = 15, Effect_0S_Enabled = true,
      DelayDriftEnabled = false, VelocityEnabled = false, SwingEnabled = false,
      PitchDriftEnabled = false, DensityEnabled = false, GhostEnabled = false,
      AutomationEnabled = false
    }
  },
  {
    name = "Chaos",
    settings = {
      DelayDriftEnabled = true, DelayDriftPercentage = 40, DelayDriftMax = 64,
      RowDriftEnabled = true, RowDriftPercentage = 20, RowDriftMax = 2,
      PitchDriftEnabled = true, PitchDriftPercentage = 25, PitchDriftMax = 3,
      VelocityEnabled = true, VelocityPercentage = 50, VelocityVariation = 35,
      DensityEnabled = true, DensityAddPercentage = 10, DensityRemovePercentage = 10,
      EffectsEnabled = true, EffectsPercentage = 20,
      GhostEnabled = true, GhostPercentage = 15, GhostCount = 2,
      RetrigEnabled = true, RetrigPercentage = 15, RetrigMin = 2, RetrigMax = 6,
      SwingEnabled = false, AutomationEnabled = false
    }
  },
  {
    name = "Jazz Feel",
    settings = {
      SwingEnabled = true, SwingTemplate = 5, SwingAmount = 60,
      VelocityEnabled = true, VelocityPercentage = 45, VelocityVariation = 30,
      GhostEnabled = true, GhostPercentage = 20, GhostCount = 2, GhostDirection = 1,
      DelayDriftEnabled = true, DelayDriftPercentage = 30, DelayDriftMax = 20,
      PitchDriftEnabled = false, RowDriftEnabled = false, DensityEnabled = false,
      EffectsEnabled = false, RetrigEnabled = false, AutomationEnabled = false
    }
  },
  {
    name = "Machine Tight",
    settings = {
      DelayDriftEnabled = true, DelayDriftPercentage = 100, DelayDriftMax = 8,
      VelocityEnabled = false, SwingEnabled = false, PitchDriftEnabled = false,
      RowDriftEnabled = false, DensityEnabled = false, GhostEnabled = false,
      EffectsEnabled = false, RetrigEnabled = false, AutomationEnabled = false
    }
  }
}

-- Find first pattern that is both empty AND not used in the sequence
function PakettiFindFirstEmptyPattern()
  local song = renoise.song()
  local used_in_sequence = {}
  
  for i = 1, #song.sequencer.pattern_sequence do
    used_in_sequence[song.sequencer.pattern_sequence[i]] = true
  end
  
  for i = 1, #song.patterns do
    if song.patterns[i].is_empty and not used_in_sequence[i] then
      return i
    end
  end
  
  return nil
end

-- Helper function to copy all note column data
function PakettiWonkifyCopyNoteColumnData(src_column, dst_column)
  dst_column.note_value = src_column.note_value
  dst_column.instrument_value = src_column.instrument_value
  dst_column.volume_value = src_column.volume_value
  dst_column.panning_value = src_column.panning_value
  dst_column.delay_value = src_column.delay_value
  dst_column.effect_number_value = src_column.effect_number_value
  dst_column.effect_amount_value = src_column.effect_amount_value
end

-- Helper function to clear a note column
function PakettiWonkifyClearNoteColumn(column)
  column.note_value = renoise.PatternLine.EMPTY_NOTE
  column.instrument_value = renoise.PatternLine.EMPTY_INSTRUMENT
  column.volume_value = renoise.PatternLine.EMPTY_VOLUME
  column.panning_value = renoise.PatternLine.EMPTY_PANNING
  column.delay_value = renoise.PatternLine.EMPTY_DELAY
  column.effect_number_value = 0
  column.effect_amount_value = 0
end

-- Helper function to check if pitch drift should apply to a track
function PakettiWonkifyShouldApplyPitchDrift(track_index, track_list_string)
  if track_list_string == nil or track_list_string == "" then
    return true
  end
  
  for track_str in string.gmatch(track_list_string, "[^,]+") do
    local track_num = tonumber(track_str:match("^%s*(.-)%s*$"))
    if track_num and track_num == track_index then
      return true
    end
  end
  
  return false
end

-- Generate scale notes for a given key and mode
function PakettiWonkifyGenerateScaleNotes(key, mode)
  local scale_intervals = PakettiWonkify_scale_data[mode]
  if not scale_intervals then
    scale_intervals = PakettiWonkify_scale_data["ionian"]
  end
  
  local key_offset = 0
  for i = 1, #PakettiWonkify_keys do
    if PakettiWonkify_keys[i] == key then
      key_offset = i - 1
      break
    end
  end
  
  local scale_notes = {}
  for octave = 0, 9 do
    for _, interval in ipairs(scale_intervals) do
      local midi_note = (octave * 12) + key_offset + interval
      if midi_note >= 0 and midi_note <= 119 then
        scale_notes[midi_note] = true
      end
    end
  end
  
  return scale_notes
end

-- Find nearest scale note for scale-aware pitch drift
function PakettiWonkifyFindNearestScaleNote(note_value, scale_notes, direction)
  if scale_notes[note_value] then
    return note_value
  end
  
  local search_range = 12
  for offset = 1, search_range do
    if direction >= 0 then
      local up = note_value + offset
      if up <= 119 and scale_notes[up] then
        return up
      end
    end
    if direction <= 0 then
      local down = note_value - offset
      if down >= 0 and scale_notes[down] then
        return down
      end
    end
  end
  
  return note_value
end

-- Apply scale-aware pitch drift
function PakettiWonkifyApplyScaleAwarePitchDrift(note_value, max_drift, scale_notes)
  local drift = math.random(-max_drift, max_drift)
  local target_note = note_value + drift
  target_note = math.max(0, math.min(119, target_note))
  
  if scale_notes[target_note] then
    return target_note
  end
  
  return PakettiWonkifyFindNearestScaleNote(target_note, scale_notes, drift >= 0 and 1 or -1)
end

-- Apply swing template delay
function PakettiWonkifyApplySwingTemplate(line_index, template_id, swing_amount, pattern_length)
  local delay = 0
  local max_delay = math.floor(255 * (swing_amount / 100))
  
  if template_id == 1 then
    -- MPC Swing: delay on even rows (off-beats)
    if line_index % 2 == 0 then
      delay = max_delay
    end
  elseif template_id == 2 then
    -- Drunken: random delay per note
    delay = math.random(0, max_delay)
  elseif template_id == 3 then
    -- Push: slight early feel (lower delays on downbeats, higher on off-beats inverted)
    if line_index % 2 == 1 then
      delay = 0
    else
      delay = math.floor(max_delay * 0.3)
    end
  elseif template_id == 4 then
    -- Pull/Lazy: everything slightly late
    delay = math.floor(max_delay * 0.5) + math.random(0, math.floor(max_delay * 0.3))
  elseif template_id == 5 then
    -- Shuffle: triplet-ish feel (every other note pushed back)
    if line_index % 2 == 0 then
      delay = math.floor(max_delay * 0.66)
    end
  elseif template_id == 6 then
    -- Human Drummer: varying based on beat position
    local beat_pos = (line_index - 1) % 4
    if beat_pos == 0 then
      delay = 0  -- Downbeat on time
    elseif beat_pos == 2 then
      delay = math.random(0, math.floor(max_delay * 0.2))  -- Snare slightly varied
    else
      delay = math.random(math.floor(max_delay * 0.3), max_delay)  -- Hi-hats loose
    end
  elseif template_id == 7 then
    -- Custom: handled by DelayDrift settings
    delay = 0
  end
  
  return delay
end

-- Apply global intensity scaling to a percentage value
function PakettiWonkifyScaleByIntensity(value, intensity)
  return math.floor(value * (intensity / 100))
end

-- Check if we should process this track based on TrackMode
function PakettiWonkifyShouldProcessTrack(track_index, track_mode, selected_track_index)
  if track_mode == 1 then
    return true  -- All tracks
  elseif track_mode == 2 then
    return track_index == selected_track_index  -- Selected track only
  elseif track_mode == 3 then
    return track_index ~= selected_track_index  -- All except selected
  end
  return true
end

-- Get selection range if in selection mode
function PakettiWonkifyGetSelectionRange(operation_mode, pattern)
  local song = renoise.song()
  local start_line = 1
  local end_line = pattern.number_of_lines
  local start_track = 1
  local end_track = #song.tracks
  
  if operation_mode == 2 then
    -- Selection Only
    local selection = song.selection_in_pattern
    if selection then
      start_line = selection.start_line
      end_line = selection.end_line
      start_track = selection.start_track
      end_track = selection.end_track
    else
      renoise.app():show_status("Wonkify: No selection found, processing entire pattern")
    end
  elseif operation_mode == 3 then
    -- From Cursor Down
    start_line = song.selected_line_index
  end
  
  return start_line, end_line, start_track, end_track
end

-- Generate random effect command
function PakettiWonkifyGenerateRandomEffect(prefs)
  local enabled_effects = {}
  
  if prefs.Effect_0Y_Enabled.value then
    table.insert(enabled_effects, {type = "0Y", min = prefs.Effect_0Y_Min.value, max = prefs.Effect_0Y_Max.value})
  end
  if prefs.Effect_0V_Enabled.value then
    table.insert(enabled_effects, {type = "0V", speed_min = prefs.Effect_0V_SpeedMin.value, speed_max = prefs.Effect_0V_SpeedMax.value,
                                   depth_min = prefs.Effect_0V_DepthMin.value, depth_max = prefs.Effect_0V_DepthMax.value})
  end
  if prefs.Effect_0T_Enabled.value then
    table.insert(enabled_effects, {type = "0T", speed_min = prefs.Effect_0T_SpeedMin.value, speed_max = prefs.Effect_0T_SpeedMax.value,
                                   depth_min = prefs.Effect_0T_DepthMin.value, depth_max = prefs.Effect_0T_DepthMax.value})
  end
  if prefs.Effect_0A_Enabled.value then
    table.insert(enabled_effects, {type = "0A", semi1_min = prefs.Effect_0A_Semitones1Min.value, semi1_max = prefs.Effect_0A_Semitones1Max.value,
                                   semi2_min = prefs.Effect_0A_Semitones2Min.value, semi2_max = prefs.Effect_0A_Semitones2Max.value})
  end
  if prefs.Effect_0G_Enabled.value then
    table.insert(enabled_effects, {type = "0G", min = prefs.Effect_0G_Min.value, max = prefs.Effect_0G_Max.value})
  end
  if prefs.Effect_0Q_Enabled.value then
    table.insert(enabled_effects, {type = "0Q", min = prefs.Effect_0Q_Min.value, max = prefs.Effect_0Q_Max.value})
  end
  if prefs.Effect_0S_Enabled.value then
    table.insert(enabled_effects, {type = "0S", min = prefs.Effect_0S_Min.value, max = prefs.Effect_0S_Max.value})
  end
  
  if #enabled_effects == 0 then
    return nil, nil
  end
  
  local effect = enabled_effects[math.random(1, #enabled_effects)]
  local effect_type = effect.type
  local effect_value = 0
  
  if effect_type == "0Y" or effect_type == "0G" or effect_type == "0Q" or effect_type == "0S" then
    effect_value = math.random(effect.min, effect.max)
  elseif effect_type == "0V" or effect_type == "0T" then
    local speed = math.random(effect.speed_min, effect.speed_max)
    local depth = math.random(effect.depth_min, effect.depth_max)
    effect_value = speed * 16 + depth  -- xy format
  elseif effect_type == "0A" then
    local semi1 = math.random(effect.semi1_min, effect.semi1_max)
    local semi2 = math.random(effect.semi2_min, effect.semi2_max)
    effect_value = semi1 * 16 + semi2  -- xy format
  end
  
  return effect_type, effect_value
end

-- Write pattern content to a phrase with wonkify effects applied
function PakettiWonkifyWriteToPhrase(pattern_index, phrase_slot)
  local song = renoise.song()
  local pattern = song.patterns[pattern_index]
  local prefs = preferences.pakettiWonkify
  local instrument = song.selected_instrument
  
  if not instrument then
    renoise.app():show_status("Wonkify: No instrument selected for phrase output")
    return false
  end
  
  if not pattern then
    renoise.app():show_status("Wonkify: Invalid pattern index")
    return false
  end
  
  -- Ensure we have enough phrases
  while #instrument.phrases < phrase_slot do
    instrument:insert_phrase_at(#instrument.phrases + 1)
  end
  
  local phrase = instrument.phrases[phrase_slot]
  if not phrase then
    renoise.app():show_status("Wonkify: Could not access phrase slot " .. phrase_slot)
    return false
  end
  
  -- Set phrase length to match pattern
  phrase.number_of_lines = pattern.number_of_lines
  
  -- Get the selected track to copy from
  local track_index = song.selected_track_index
  local track = song.tracks[track_index]
  
  if track.type == renoise.Track.TRACK_TYPE_MASTER or track.type == renoise.Track.TRACK_TYPE_SEND then
    renoise.app():show_status("Wonkify: Cannot write Master/Send track to phrase")
    return false
  end
  
  local pattern_track = pattern:track(track_index)
  local intensity = prefs.GlobalIntensity.value
  
  -- Generate scale notes if scale-aware pitch drift is enabled
  local scale_notes = nil
  if prefs.PitchDriftEnabled.value and prefs.PitchDriftScaleAware.value then
    scale_notes = PakettiWonkifyGenerateScaleNotes(prefs.PitchDriftKey.value, prefs.PitchDriftMode.value)
  end
  
  -- Apply random seed if enabled
  if prefs.RandomSeedEnabled.value then
    local seed = prefs.RandomSeed.value
    math.randomseed(seed)
    math.random()
    math.random()
    math.random()
    math.randomseed(seed)
  else
    math.randomseed(os.time() + os.clock() * 1000)
  end
  
  -- Scale percentages by global intensity
  local delay_pct = PakettiWonkifyScaleByIntensity(prefs.DelayDriftPercentage.value, intensity)
  local pitch_pct = PakettiWonkifyScaleByIntensity(prefs.PitchDriftPercentage.value, intensity)
  local vel_pct = PakettiWonkifyScaleByIntensity(prefs.VelocityPercentage.value, intensity)
  local effects_pct = PakettiWonkifyScaleByIntensity(prefs.EffectsPercentage.value, intensity)
  
  local notes_written = 0
  
  -- Iterate through all lines in the pattern
  for line_index = 1, pattern.number_of_lines do
    local pattern_line = pattern_track:line(line_index)
    local phrase_line = phrase:line(line_index)
    
    -- Copy visible note columns
    local columns_to_copy = math.min(track.visible_note_columns, phrase.visible_note_columns)
    
    for column_index = 1, columns_to_copy do
      local src_column = pattern_line:note_column(column_index)
      local dst_column = phrase_line:note_column(column_index)
      
      -- Copy base data
      dst_column.note_value = src_column.note_value
      dst_column.instrument_value = src_column.instrument_value
      dst_column.volume_value = src_column.volume_value
      dst_column.panning_value = src_column.panning_value
      dst_column.delay_value = src_column.delay_value
      dst_column.effect_number_value = src_column.effect_number_value
      dst_column.effect_amount_value = src_column.effect_amount_value
      
      -- Apply wonkify effects if this is a valid note
      if dst_column.note_value ~= renoise.PatternLine.EMPTY_NOTE and
         dst_column.note_value ~= 120 then
        
        notes_written = notes_written + 1
        
        -- Apply Swing Template
        if prefs.SwingEnabled.value and prefs.SwingTemplate.value ~= 7 then
          local swing_delay = PakettiWonkifyApplySwingTemplate(
            line_index, prefs.SwingTemplate.value, prefs.SwingAmount.value, pattern.number_of_lines)
          if swing_delay > 0 then
            local current_delay = dst_column.delay_value
            if current_delay == renoise.PatternLine.EMPTY_DELAY then
              current_delay = 0
            end
            dst_column.delay_value = math.min(255, current_delay + swing_delay)
          end
        end
        
        -- Apply Delay Drift
        if prefs.DelayDriftEnabled.value then
          local dice = math.random(1, 100)
          if dice <= delay_pct then
            local current_delay = dst_column.delay_value
            if current_delay == renoise.PatternLine.EMPTY_DELAY then
              current_delay = 0
            end
            local max_drift = prefs.DelayDriftMax.value
            local drift = math.random(-max_drift, max_drift)
            dst_column.delay_value = math.max(0, math.min(255, current_delay + drift))
          end
        end
        
        -- Apply Pitch Drift
        if prefs.PitchDriftEnabled.value then
          local dice = math.random(1, 100)
          if dice <= pitch_pct then
            local max_drift = prefs.PitchDriftMax.value
            local new_note
            
            if prefs.PitchDriftScaleAware.value and scale_notes then
              new_note = PakettiWonkifyApplyScaleAwarePitchDrift(dst_column.note_value, max_drift, scale_notes)
            else
              local drift = math.random(-max_drift, max_drift)
              new_note = dst_column.note_value + drift
              new_note = math.max(0, math.min(119, new_note))
            end
            
            dst_column.note_value = new_note
          end
        end
        
        -- Apply Velocity Variation
        if prefs.VelocityEnabled.value then
          local dice = math.random(1, 100)
          if dice <= vel_pct then
            local current_vol = dst_column.volume_value
            if current_vol == renoise.PatternLine.EMPTY_VOLUME then
              current_vol = 128
            end
            
            local variation = prefs.VelocityVariation.value / 100
            local change = current_vol * variation * (math.random() * 2 - 1)
            dst_column.volume_value = math.max(1, math.min(128, math.floor(current_vol + change)))
          end
        end
        
        -- Apply Random Effects
        if prefs.EffectsEnabled.value then
          local dice = math.random(1, 100)
          if dice <= effects_pct then
            local effect_type, effect_value = PakettiWonkifyGenerateRandomEffect(prefs)
            if effect_type and dst_column.effect_number_value == 0 then
              dst_column.effect_number_string = effect_type
              dst_column.effect_amount_value = effect_value
            end
          end
        end
      end
    end
  end
  
  -- Name the phrase
  phrase.name = "Wonkified " .. phrase_slot
  
  renoise.app():show_status("Wonkify: Wrote " .. notes_written .. " notes to phrase " .. phrase_slot)
  return true
end

-- Wonkify to phrase action
function PakettiWonkifyToPhrase()
  local song = renoise.song()
  local prefs = preferences.pakettiWonkify
  local pattern_index = song.selected_pattern_index
  local phrase_slot = prefs.PhraseStartIndex.value
  
  local success = PakettiWonkifyWriteToPhrase(pattern_index, phrase_slot)
  if success then
    -- Increment phrase slot for next use
    prefs.PhraseStartIndex.value = prefs.PhraseStartIndex.value + 1
  end
end

-- Apply wonkify to automation
function PakettiWonkifyAutomation(pattern, prefs)
  local song = renoise.song()
  local intensity = prefs.GlobalIntensity.value
  local percentage = PakettiWonkifyScaleByIntensity(prefs.AutomationPercentage.value, intensity)
  local value_variation = prefs.AutomationValueVariation.value / 100
  local time_variation = prefs.AutomationTimeVariation.value
  local automation_modified = 0
  
  for track_index = 1, #song.tracks do
    local pattern_track = pattern:track(track_index)
    
    for _, automation in ipairs(pattern_track.automation) do
      local points = automation.points
      local new_points = {}
      
      for i, point in ipairs(points) do
        local dice = math.random(1, 100)
        local new_time = point.time
        local new_value = point.value
        
        if dice <= percentage then
          -- Randomize value
          local change = new_value * value_variation * (math.random() * 2 - 1)
          new_value = math.max(0.0, math.min(1.0, new_value + change))
          
          -- Randomize time (if enabled)
          if time_variation > 0 then
            local time_change = math.random(-time_variation, time_variation)
            new_time = math.max(1, math.min(pattern.number_of_lines, math.floor(new_time + time_change)))
          end
          
          automation_modified = automation_modified + 1
        end
        
        table.insert(new_points, {time = new_time, value = new_value})
      end
      
      -- Clear and rewrite points
      automation:clear()
      for _, pt in ipairs(new_points) do
        automation:add_point_at(pt.time, pt.value)
      end
    end
  end
  
  return automation_modified
end

-- Apply wonkify effects to a specific pattern
function PakettiWonkifyPattern(pattern_index)
  local song = renoise.song()
  local pattern = song.patterns[pattern_index]
  local prefs = preferences.pakettiWonkify
  
  if not pattern then
    renoise.app():show_status("Wonkify: Invalid pattern index")
    return
  end
  
  local intensity = prefs.GlobalIntensity.value
  local operation_mode = prefs.OperationMode.value
  local track_mode = prefs.TrackMode.value
  local selected_track_index = song.selected_track_index
  
  -- Get selection range
  local start_line, end_line, start_track, end_track = PakettiWonkifyGetSelectionRange(operation_mode, pattern)
  
  -- Generate scale notes if scale-aware pitch drift is enabled
  local scale_notes = nil
  if prefs.PitchDriftEnabled.value and prefs.PitchDriftScaleAware.value then
    scale_notes = PakettiWonkifyGenerateScaleNotes(prefs.PitchDriftKey.value, prefs.PitchDriftMode.value)
  end
  
  -- Count notes in pattern for diagnostic purposes
  local note_count = 0
  for track_index = start_track, end_track do
    local track = song.tracks[track_index]
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER and track.type ~= renoise.Track.TRACK_TYPE_SEND then
      if PakettiWonkifyShouldProcessTrack(track_index, track_mode, selected_track_index) then
        local pattern_track = pattern:track(track_index)
        for line_index = start_line, end_line do
          local line = pattern_track:line(line_index)
          for column_index = 1, track.visible_note_columns do
            local note_column = line:note_column(column_index)
            if note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE then
              note_count = note_count + 1
            end
          end
        end
      end
    end
  end
  
  -- Apply random seed if enabled
  if prefs.RandomSeedEnabled.value then
    local seed = prefs.RandomSeed.value
    math.randomseed(seed)
    math.random()
    math.random()
    math.random()
    math.randomseed(seed)
    print(string.format("Wonkify: Seed=%d, Pattern has %d notes, %d lines", seed, note_count, pattern.number_of_lines))
  else
    math.randomseed(os.time() + os.clock() * 1000)
    print(string.format("Wonkify: Time-based seed, Pattern has %d notes, %d lines", note_count, pattern.number_of_lines))
  end
  
  local notes_affected = 0
  local delay_drifts = 0
  local swing_applied = 0
  local row_drifts = 0
  local pitch_drifts = 0
  local velocity_changes = 0
  local notes_added = 0
  local notes_removed = 0
  local ghosts_added = 0
  local retrigs_added = 0
  local effects_added = 0
  
  local existing_notes = {}
  local ghost_notes_to_add = {}
  local row_drift_swaps = {}
  local notes_to_remove = {}
  local empty_positions = {}
  
  -- Scale percentages by global intensity
  local delay_pct = PakettiWonkifyScaleByIntensity(prefs.DelayDriftPercentage.value, intensity)
  local row_pct = PakettiWonkifyScaleByIntensity(prefs.RowDriftPercentage.value, intensity)
  local pitch_pct = PakettiWonkifyScaleByIntensity(prefs.PitchDriftPercentage.value, intensity)
  local vel_pct = PakettiWonkifyScaleByIntensity(prefs.VelocityPercentage.value, intensity)
  local density_remove_pct = PakettiWonkifyScaleByIntensity(prefs.DensityRemovePercentage.value, intensity)
  local ghost_pct = PakettiWonkifyScaleByIntensity(prefs.GhostPercentage.value, intensity)
  local retrig_pct = PakettiWonkifyScaleByIntensity(prefs.RetrigPercentage.value, intensity)
  local effects_pct = PakettiWonkifyScaleByIntensity(prefs.EffectsPercentage.value, intensity)
  
  -- First pass: collect notes, apply modifications
  for track_index = start_track, end_track do
    local track = song.tracks[track_index]
    
    if track.type == renoise.Track.TRACK_TYPE_MASTER or track.type == renoise.Track.TRACK_TYPE_SEND then
      -- Skip these tracks
    elseif not PakettiWonkifyShouldProcessTrack(track_index, track_mode, selected_track_index) then
      -- Skip based on track mode
    else
      local pattern_track = pattern:track(track_index)
      
      for line_index = start_line, end_line do
        local line = pattern_track:line(line_index)
        
        for column_index = 1, track.visible_note_columns do
          local note_column = line:note_column(column_index)
          
          if note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE and
             note_column.note_value ~= 120 then
            
            notes_affected = notes_affected + 1
            
            table.insert(existing_notes, {
              note_value = note_column.note_value,
              instrument_value = note_column.instrument_value
            })
            
            -- Apply Swing Template
            if prefs.SwingEnabled.value and prefs.SwingTemplate.value ~= 7 then
              local swing_delay = PakettiWonkifyApplySwingTemplate(
                line_index, prefs.SwingTemplate.value, prefs.SwingAmount.value, pattern.number_of_lines)
              if swing_delay > 0 then
                local current_delay = note_column.delay_value
                if current_delay == renoise.PatternLine.EMPTY_DELAY then
                  current_delay = 0
                end
                note_column.delay_value = math.min(255, current_delay + swing_delay)
                track.delay_column_visible = true
                swing_applied = swing_applied + 1
              end
            end
            
            -- Apply Delay Drift
            if prefs.DelayDriftEnabled.value then
              local dice = math.random(1, 100)
              if dice <= delay_pct then
                local current_delay = note_column.delay_value
                if current_delay == renoise.PatternLine.EMPTY_DELAY then
                  current_delay = 0
                end
                
                local max_drift = prefs.DelayDriftMax.value
                local drift = math.random(-max_drift, max_drift)
                local new_delay = current_delay + drift
                new_delay = math.max(0, math.min(255, new_delay))
                note_column.delay_value = new_delay
                track.delay_column_visible = true
                delay_drifts = delay_drifts + 1
              end
            end
            
            -- Collect Row Drift info
            if prefs.RowDriftEnabled.value then
              local dice = math.random(1, 100)
              if dice <= row_pct then
                local max_drift = prefs.RowDriftMax.value
                local drift = math.random(-max_drift, max_drift)
                local target_line = line_index + drift
                
                if target_line >= start_line and target_line <= end_line then
                  table.insert(row_drift_swaps, {
                    track_index = track_index,
                    src_line = line_index,
                    dst_line = target_line,
                    column_index = column_index
                  })
                end
              end
            end
            
            -- Apply Pitch Drift
            if prefs.PitchDriftEnabled.value then
              if PakettiWonkifyShouldApplyPitchDrift(track_index, prefs.PitchDriftTracks.value) then
                local dice = math.random(1, 100)
                if dice <= pitch_pct then
                  local max_drift = prefs.PitchDriftMax.value
                  local new_note
                  
                  if prefs.PitchDriftScaleAware.value and scale_notes then
                    new_note = PakettiWonkifyApplyScaleAwarePitchDrift(note_column.note_value, max_drift, scale_notes)
                  else
                    local drift = math.random(-max_drift, max_drift)
                    new_note = note_column.note_value + drift
                    new_note = math.max(0, math.min(119, new_note))
                  end
                  
                  note_column.note_value = new_note
                  pitch_drifts = pitch_drifts + 1
                end
              end
            end
            
            -- Apply Velocity Variation
            if prefs.VelocityEnabled.value then
              local dice = math.random(1, 100)
              if dice <= vel_pct then
                local current_vol = note_column.volume_value
                if current_vol == renoise.PatternLine.EMPTY_VOLUME then
                  current_vol = 128
                end
                
                local variation = prefs.VelocityVariation.value / 100
                local change = current_vol * variation * (math.random() * 2 - 1)
                local new_vol = math.floor(current_vol + change)
                new_vol = math.max(1, math.min(128, new_vol))
                note_column.volume_value = new_vol
                track.volume_column_visible = true
                velocity_changes = velocity_changes + 1
              end
            end
            
            -- Note Density - Remove
            if prefs.DensityEnabled.value then
              local dice = math.random(1, 100)
              if dice <= density_remove_pct then
                table.insert(notes_to_remove, {
                  track_index = track_index,
                  line_index = line_index,
                  column_index = column_index
                })
              end
            end
            
            -- Apply Random Effects
            if prefs.EffectsEnabled.value then
              local dice = math.random(1, 100)
              if dice <= effects_pct then
                local effect_type, effect_value = PakettiWonkifyGenerateRandomEffect(prefs)
                if effect_type then
                  if prefs.EffectsColumn.value == 1 then
                    -- Write to Effect Column
                    if track.visible_effect_columns < 1 then
                      track.visible_effect_columns = 1
                    end
                    local effect_column = line:effect_column(1)
                    if effect_column.number_value == 0 then
                      effect_column.number_string = effect_type
                      effect_column.amount_value = effect_value
                      effects_added = effects_added + 1
                    end
                  else
                    -- Write to Sample Effects Column
                    if note_column.effect_number_value == 0 then
                      track.sample_effects_column_visible = true
                      note_column.effect_number_string = effect_type
                      note_column.effect_amount_value = effect_value
                      effects_added = effects_added + 1
                    end
                  end
                end
              end
            end
            
            -- Apply Retrig
            if prefs.RetrigEnabled.value then
              local dice = math.random(1, 100)
              if dice <= retrig_pct then
                local retrig_range = prefs.RetrigMax.value - prefs.RetrigMin.value
                local retrig_val = prefs.RetrigMin.value + math.random(0, math.max(0, retrig_range))
                
                if prefs.RetrigColumn.value == 1 then
                  if track.visible_effect_columns < 1 then
                    track.visible_effect_columns = 1
                  end
                  local effect_column = line:effect_column(1)
                  effect_column.number_string = "0R"
                  effect_column.amount_value = retrig_val
                else
                  track.sample_effects_column_visible = true
                  note_column.effect_number_string = "0R"
                  note_column.effect_amount_value = retrig_val
                end
                
                retrigs_added = retrigs_added + 1
              end
            end
            
            -- Collect Ghost Note info
            if prefs.GhostEnabled.value then
              local dice = math.random(1, 100)
              if dice <= ghost_pct then
                local ghost_count = prefs.GhostCount.value
                local direction = prefs.GhostDirection.value
                local vol_start = prefs.GhostVolumeStart.value
                local vol_end = prefs.GhostVolumeEnd.value
                
                for ghost_i = 1, ghost_count do
                  local ghost_line
                  local ghost_vol
                  
                  if direction == 1 then
                    ghost_line = line_index - (ghost_count - ghost_i + 1)
                    ghost_vol = vol_start + (vol_end - vol_start) * ((ghost_i - 1) / math.max(1, ghost_count - 1))
                  else
                    ghost_line = line_index + ghost_i
                    ghost_vol = vol_end - (vol_end - vol_start) * ((ghost_i - 1) / math.max(1, ghost_count - 1))
                  end
                  
                  if ghost_line >= start_line and ghost_line <= end_line then
                    local actual_vol = math.floor(128 * ghost_vol / 100)
                    actual_vol = math.max(1, math.min(128, actual_vol))
                    
                    table.insert(ghost_notes_to_add, {
                      track_index = track_index,
                      line_index = ghost_line,
                      column_index = column_index,
                      note_value = note_column.note_value,
                      instrument_value = note_column.instrument_value,
                      volume = actual_vol
                    })
                  end
                end
              end
            end
          else
            -- Empty position - collect for density add
            if prefs.DensityEnabled.value and note_column.note_value == renoise.PatternLine.EMPTY_NOTE then
              table.insert(empty_positions, {
                track_index = track_index,
                line_index = line_index,
                column_index = column_index
              })
            end
          end
        end
      end
    end
  end
  
  -- Apply Row Drift swaps
  for _, swap in ipairs(row_drift_swaps) do
    local pattern_track = pattern:track(swap.track_index)
    local src_line = pattern_track:line(swap.src_line)
    local dst_line = pattern_track:line(swap.dst_line)
    local src_column = src_line:note_column(swap.column_index)
    local dst_column = dst_line:note_column(swap.column_index)
    
    local temp_note = src_column.note_value
    local temp_instrument = src_column.instrument_value
    local temp_volume = src_column.volume_value
    local temp_panning = src_column.panning_value
    local temp_delay = src_column.delay_value
    local temp_effect_num = src_column.effect_number_value
    local temp_effect_amt = src_column.effect_amount_value
    
    PakettiWonkifyCopyNoteColumnData(dst_column, src_column)
    
    dst_column.note_value = temp_note
    dst_column.instrument_value = temp_instrument
    dst_column.volume_value = temp_volume
    dst_column.panning_value = temp_panning
    dst_column.delay_value = temp_delay
    dst_column.effect_number_value = temp_effect_num
    dst_column.effect_amount_value = temp_effect_amt
    
    row_drifts = row_drifts + 1
  end
  
  -- Remove notes for density variation
  for _, pos in ipairs(notes_to_remove) do
    local pattern_track = pattern:track(pos.track_index)
    local line = pattern_track:line(pos.line_index)
    local note_column = line:note_column(pos.column_index)
    PakettiWonkifyClearNoteColumn(note_column)
    notes_removed = notes_removed + 1
  end
  
  -- Add notes for density variation
  local density_add_pct = PakettiWonkifyScaleByIntensity(prefs.DensityAddPercentage.value, intensity)
  if prefs.DensityEnabled.value and #existing_notes > 0 and #empty_positions > 0 then
    for _, pos in ipairs(empty_positions) do
      local dice = math.random(1, 100)
      if dice <= density_add_pct then
        local pattern_track = pattern:track(pos.track_index)
        local line = pattern_track:line(pos.line_index)
        local note_column = line:note_column(pos.column_index)
        
        local source = existing_notes[math.random(1, #existing_notes)]
        note_column.note_value = source.note_value
        note_column.instrument_value = source.instrument_value
        notes_added = notes_added + 1
      end
    end
  end
  
  -- Add ghost notes
  for _, ghost in ipairs(ghost_notes_to_add) do
    local track = song.tracks[ghost.track_index]
    local pattern_track = pattern:track(ghost.track_index)
    local line = pattern_track:line(ghost.line_index)
    local note_column = line:note_column(ghost.column_index)
    
    if note_column.note_value == renoise.PatternLine.EMPTY_NOTE then
      note_column.note_value = ghost.note_value
      note_column.instrument_value = ghost.instrument_value
      note_column.volume_value = ghost.volume
      track.volume_column_visible = true
      ghosts_added = ghosts_added + 1
    end
  end
  
  -- Apply automation wonkification
  local automation_modified = 0
  if prefs.AutomationEnabled.value then
    automation_modified = PakettiWonkifyAutomation(pattern, prefs)
  end
  
  local status_msg = string.format(
    "Wonkified: %d notes | Swing:%d Delay:%d Row:%d Pitch:%d Vel:%d +Notes:%d -Notes:%d Ghost:%d Retrig:%d FX:%d Auto:%d",
    notes_affected, swing_applied, delay_drifts, row_drifts, pitch_drifts, velocity_changes,
    notes_added, notes_removed, ghosts_added, retrigs_added, effects_added, automation_modified)
  renoise.app():show_status(status_msg)
  print(status_msg)
end

-- Wonkify current pattern in place
function PakettiWonkifyCurrentPattern()
  local song = renoise.song()
  local current_pattern_index = song.selected_pattern_index
  PakettiWonkifyPattern(current_pattern_index)
end

-- Duplicate pattern to new empty pattern and then wonkify it
function PakettiWonkifyDuplicatePattern()
  local song = renoise.song()
  local sequencer = song.sequencer
  local current_pattern_index = song.selected_pattern_index
  local current_sequence_index = song.selected_sequence_index
  
  local empty_pattern_index = PakettiFindFirstEmptyPattern()
  
  if not empty_pattern_index then
    local new_sequence_index = current_sequence_index + 1
    empty_pattern_index = sequencer:insert_new_pattern_at(new_sequence_index)
  else
    local new_sequence_index = current_sequence_index + 1
    sequencer:insert_sequence_at(new_sequence_index, empty_pattern_index)
  end
  
  local new_sequence_index = current_sequence_index + 1
  
  song.patterns[empty_pattern_index]:copy_from(song.patterns[current_pattern_index])
  
  local original_name = song.patterns[current_pattern_index].name
  if original_name == "" then
    original_name = "Pattern " .. tostring(current_pattern_index)
  end
  song.patterns[empty_pattern_index].name = original_name .. " (Wonky)"
  
  for track_index = 1, #song.tracks do
    local is_muted = sequencer:track_sequence_slot_is_muted(track_index, current_sequence_index)
    sequencer:set_track_sequence_slot_is_muted(track_index, new_sequence_index, is_muted)
  end
  
  for track_index = 1, #song.tracks do
    local original_track = song.patterns[current_pattern_index].tracks[track_index]
    local new_track = song.patterns[empty_pattern_index].tracks[track_index]
    for _, automation in ipairs(original_track.automation) do
      local parameter = automation.dest_parameter
      local new_automation = new_track:find_automation(parameter)
      if not new_automation then
        new_automation = new_track:create_automation(parameter)
      end
      new_automation:copy_from(automation)
    end
  end
  
  song.selected_sequence_index = new_sequence_index
  PakettiWonkifyPattern(empty_pattern_index)
  
  renoise.app():show_status("Duplicated and wonkified pattern to sequence " .. new_sequence_index)
end

-- Generate a chain of wonkified patterns
function PakettiWonkifyGenerateChain()
  local prefs = preferences.pakettiWonkify
  local count = prefs.PatternCount.value
  local original_seed = prefs.RandomSeed.value
  
  for i = 1, count do
    PakettiWonkifyDuplicatePattern()
    
    if prefs.RandomSeedEnabled.value then
      prefs.RandomSeed.value = prefs.RandomSeed.value + 1
    end
  end
  
  prefs.RandomSeed.value = original_seed
  renoise.app():show_status("Generated " .. count .. " wonkified patterns in chain")
end

-- Apply a built-in preset
function PakettiWonkifyApplyPreset(preset_index)
  local prefs = preferences.pakettiWonkify
  local preset = PakettiWonkify_builtin_presets[preset_index]
  
  if not preset then
    renoise.app():show_status("Wonkify: Invalid preset index")
    return
  end
  
  for key, value in pairs(preset.settings) do
    if prefs[key] then
      prefs[key].value = value
    end
  end
  
  prefs.CurrentPreset.value = preset_index
  renoise.app():show_status("Wonkify: Applied preset '" .. preset.name .. "'")
end

-- Quick preset actions
function PakettiWonkifySubtleHumanize()
  PakettiWonkifyApplyPreset(1)
  PakettiWonkifyCurrentPattern()
end

function PakettiWonkifyDrunkGroove()
  PakettiWonkifyApplyPreset(2)
  PakettiWonkifyCurrentPattern()
end

function PakettiWonkifyLoFiGrit()
  PakettiWonkifyApplyPreset(3)
  PakettiWonkifyCurrentPattern()
end

function PakettiWonkifyGlitchy()
  PakettiWonkifyApplyPreset(4)
  PakettiWonkifyCurrentPattern()
end

function PakettiWonkifyChaos()
  PakettiWonkifyApplyPreset(5)
  PakettiWonkifyCurrentPattern()
end

-- Quick Dialog for one-click variations
function PakettiWonkifyQuickDialog()
  if wonkify_quick_dialog and wonkify_quick_dialog.visible then
    wonkify_quick_dialog:close()
    wonkify_quick_dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  local prefs = preferences.pakettiWonkify
  
  local button_width = 100
  local button_height = 30
  
  local dialog_content = vb:column{
    
    -- Intensity Slider
    vb:row{
      vb:text{text = "Intensity", width = 60},
      vb:slider{
        id = "intensity_slider",
        min = 0,
        max = 100,
        value = prefs.GlobalIntensity.value,
        width = 200,
        notifier = function(value)
          prefs.GlobalIntensity.value = math.floor(value)
          vb.views.intensity_value.text = string.format("%d%%", math.floor(value))
        end
      },
      vb:text{id = "intensity_value", text = string.format("%d%%", prefs.GlobalIntensity.value), width = 40}
    },
    
    -- Quick Toggles
    vb:row{
      vb:column{
        vb:row{
          vb:checkbox{
            value = prefs.DelayDriftEnabled.value or prefs.SwingEnabled.value,
            notifier = function(value)
              prefs.DelayDriftEnabled.value = value
            end
          },
          vb:text{text = "Timing"}
        }
      },
      vb:column{
        vb:row{
          vb:checkbox{
            value = prefs.PitchDriftEnabled.value,
            notifier = function(value) prefs.PitchDriftEnabled.value = value end
          },
          vb:text{text = "Pitch"}
        }
      },
      vb:column{
        vb:row{
          vb:checkbox{
            value = prefs.VelocityEnabled.value,
            notifier = function(value) prefs.VelocityEnabled.value = value end
          },
          vb:text{text = "Velocity"}
        }
      },
      vb:column{
        vb:row{
          vb:checkbox{
            value = prefs.EffectsEnabled.value,
            notifier = function(value) prefs.EffectsEnabled.value = value end
          },
          vb:text{text = "Effects"}
        }
      }
    },
    
    
    -- Preset Buttons Row 1
    vb:row{
      vb:button{
        text = "Subtle Humanize",
        width = button_width,
        height = button_height,
        notifier = function()
          PakettiWonkifyApplyPreset(1)
          PakettiWonkifyDuplicatePattern()
        end
      },
      vb:button{
        text = "Drunk Groove",
        width = button_width,
        height = button_height,
        notifier = function()
          PakettiWonkifyApplyPreset(2)
          PakettiWonkifyDuplicatePattern()
        end
      },
      vb:button{
        text = "Lo-Fi Grit",
        width = button_width,
        height = button_height,
        notifier = function()
          PakettiWonkifyApplyPreset(3)
          PakettiWonkifyDuplicatePattern()
        end
      }
    },
    
    -- Preset Buttons Row 2
    vb:row{
      vb:button{
        text = "Glitchy",
        width = button_width,
        height = button_height,
        notifier = function()
          PakettiWonkifyApplyPreset(4)
          PakettiWonkifyDuplicatePattern()
        end
      },
      vb:button{
        text = "Chaos",
        width = button_width,
        height = button_height,
        notifier = function()
          PakettiWonkifyApplyPreset(5)
          PakettiWonkifyDuplicatePattern()
        end
      },
      vb:button{
        text = "Jazz Feel",
        width = button_width,
        height = button_height,
        notifier = function()
          PakettiWonkifyApplyPreset(6)
          PakettiWonkifyDuplicatePattern()
        end
      }
    },
    
    -- Preset Button Row 3
    vb:row{
      vb:button{
        text = "Machine Tight",
        width = button_width,
        height = button_height,
        notifier = function()
          PakettiWonkifyApplyPreset(7)
          PakettiWonkifyDuplicatePattern()
        end
      }
    },
    
    
    -- Action Buttons
    vb:row{
      vb:button{
        text = "Wonkify Current",
        width = 100,
        notifier = PakettiWonkifyCurrentPattern
      },
      vb:button{
        text = "Duplicate & Wonkify",
        width = 120,
        notifier = PakettiWonkifyDuplicatePattern
      },
      vb:button{
        text = "Advanced...",
        width = 80,
        notifier = function()
          if wonkify_quick_dialog and wonkify_quick_dialog.visible then
            wonkify_quick_dialog:close()
            wonkify_quick_dialog = nil
          end
          PakettiWonkifyDialog()
        end
      }
    }
  }
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return wonkify_quick_dialog end,
    function(value) wonkify_quick_dialog = value end
  )
  
  wonkify_quick_dialog = renoise.app():show_custom_dialog("Paketti Wonkify Quick", dialog_content, keyhandler)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Advanced Dialog with all controls organized in sections
function PakettiWonkifyDialog()
  if wonkify_dialog and wonkify_dialog.visible then
    wonkify_dialog:close()
    wonkify_dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  local prefs = preferences.pakettiWonkify
  
  local slider_width = 150
  local label_width = 130
  local value_width = 60
  local group_width = 354
  
  -- Helper function to create a labeled slider row
  local function create_slider_row(label, min_val, max_val, pref, suffix)
    suffix = suffix or ""
    local value_text = vb:text{
      text = string.format("%d%s", pref.value, suffix),
      width = value_width
    }
    return vb:row{
      vb:text{text = label, width = label_width},
      vb:slider{
        min = min_val,
        max = max_val,
        value = pref.value,
        width = slider_width,
        notifier = function(value)
          pref.value = math.floor(value)
          value_text.text = string.format("%d%s", math.floor(value), suffix)
        end
      },
      value_text
    }
  end
  
  -- Build swing template items for popup
  local swing_items = {}
  for i, template in ipairs(PakettiWonkify_swing_templates) do
    table.insert(swing_items, template.name)
  end
  
  -- Build mode items for popup
  local mode_items = {}
  for _, mode in ipairs(PakettiWonkify_modes) do
    table.insert(mode_items, mode)
  end
  
  -- Left Column
  local left_column = vb:column{
    
    -- Global Settings Section
    vb:column{
      style = "group",
      width = group_width,
      
      vb:text{text = "Global Settings", font = "bold", style = "strong"},
      
      create_slider_row("Global Intensity", 0, 100, prefs.GlobalIntensity, "%"),
      
      vb:row{
        vb:text{text = "Operation Mode", width = label_width},
        vb:popup{
          items = {"Entire Pattern", "Selection Only", "From Cursor Down"},
          value = prefs.OperationMode.value,
          width = slider_width,
          notifier = function(value) prefs.OperationMode.value = value end
        }
      },
      
      vb:row{
        vb:text{text = "Track Mode", width = label_width},
        vb:popup{
          items = {"All Tracks", "Selected Track Only", "All Except Selected"},
          value = prefs.TrackMode.value,
          width = slider_width,
          notifier = function(value) prefs.TrackMode.value = value end
        }
      },
      
      vb:row{
        vb:checkbox{
          value = prefs.RandomSeedEnabled.value,
          notifier = function(value) prefs.RandomSeedEnabled.value = value end
        },
        vb:text{text = "Random Seed", width = label_width - 18},
        vb:valuebox{
          min = 1,
          max = 999999,
          value = prefs.RandomSeed.value,
          width = 80,
          notifier = function(value) prefs.RandomSeed.value = value end
        },
        vb:button{
          text = "New",
          width = 40,
          notifier = function()
            local new_seed = (os.time() % 900000) + math.floor(os.clock() * 1000) % 99999
            prefs.RandomSeed.value = math.max(1, math.min(999999, new_seed))
          end
        }
      },
      
      vb:row{
        vb:text{text = "Pattern Count", width = label_width},
        vb:valuebox{
          min = 1,
          max = 16,
          value = prefs.PatternCount.value,
          width = 80,
          notifier = function(value) prefs.PatternCount.value = value end
        },
        vb:text{text = "(for chain generation)"}
      }
    },
    
    -- Swing/Groove Section
    vb:column{
      style = "group",
      width = group_width,
      
      vb:row{
        vb:checkbox{
          value = prefs.SwingEnabled.value,
          notifier = function(value) prefs.SwingEnabled.value = value end
        },
        vb:text{text = "Swing/Groove", font = "bold", style = "strong"}
      },
      vb:row{
        vb:text{text = "Template", width = label_width},
        vb:popup{
          items = swing_items,
          value = prefs.SwingTemplate.value,
          width = slider_width,
          notifier = function(value) prefs.SwingTemplate.value = value end
        }
      },
      create_slider_row("Swing Amount", 0, 100, prefs.SwingAmount, "%")
    },
    
    -- Rhythm Section
    vb:column{
      style = "group",
      width = group_width,
      
      vb:text{text = "Rhythm", font = "bold", style = "strong"},
      
      vb:row{
        vb:checkbox{
          value = prefs.DelayDriftEnabled.value,
          notifier = function(value) prefs.DelayDriftEnabled.value = value end
        },
        vb:text{text = "Delay Drift (ticks within row)"}
      },
      create_slider_row("Percentage", 0, 100, prefs.DelayDriftPercentage, "%"),
      create_slider_row("Max Ticks (+/-)", 0, 255, prefs.DelayDriftMax),
      
      vb:row{
        vb:checkbox{
          value = prefs.RowDriftEnabled.value,
          notifier = function(value) prefs.RowDriftEnabled.value = value end
        },
        vb:text{text = "Row Drift (swap positions)"}
      },
      create_slider_row("Percentage", 0, 100, prefs.RowDriftPercentage, "%"),
      create_slider_row("Max Rows (+/-)", 1, 16, prefs.RowDriftMax)
    },
    
    -- Pitch Section
    vb:column{
      style = "group",
      width = group_width,
      
      vb:row{
        vb:checkbox{
          value = prefs.PitchDriftEnabled.value,
          notifier = function(value) prefs.PitchDriftEnabled.value = value end
        },
        vb:text{text = "Pitch Drift", font = "bold", style = "strong"}
      },
      create_slider_row("Percentage", 0, 100, prefs.PitchDriftPercentage, "%"),
      create_slider_row("Max Semitones (+/-)", 1, 12, prefs.PitchDriftMax),
      vb:row{
        vb:text{text = "Apply to Tracks", width = label_width},
        vb:textfield{
          value = prefs.PitchDriftTracks.value,
          width = slider_width,
          tooltip = "Comma-separated track numbers (e.g. '1,2,3') or empty for all",
          notifier = function(value) prefs.PitchDriftTracks.value = value end
        }
      },
      
      
      vb:row{
        vb:row{
          width = label_width,
          vb:checkbox{
            value = prefs.PitchDriftScaleAware.value,
            notifier = function(value) prefs.PitchDriftScaleAware.value = value end
          },
          vb:text{text = "Scale-Aware (stay in key)"}
        }
      },
      vb:row{
        vb:text{text = "Key", width = label_width},
        vb:popup{
          items = PakettiWonkify_keys,
          value = 1,
          width = 60,
          notifier = function(value) prefs.PitchDriftKey.value = PakettiWonkify_keys[value] end
        },
        vb:text{text = "Mode", width = 50},
        vb:popup{
          items = mode_items,
          value = 1,
          width = slider_width - 110,
          notifier = function(value) prefs.PitchDriftMode.value = PakettiWonkify_modes[value] end
        }
      }
    },
    
    -- Velocity Section
    vb:column{
      style = "group",
      width = group_width,
      
      vb:row{
        vb:checkbox{
          value = prefs.VelocityEnabled.value,
          notifier = function(value) prefs.VelocityEnabled.value = value end
        },
        vb:text{text = "Velocity Variation", font = "bold", style = "strong"}
      },
      create_slider_row("Percentage", 0, 100, prefs.VelocityPercentage, "%"),
      create_slider_row("Max Change (+/-)", 1, 100, prefs.VelocityVariation, "%")
    },
    
    -- Density Section
    vb:column{
      style = "group",
      width = group_width,
      
      vb:row{
        vb:checkbox{
          value = prefs.DensityEnabled.value,
          notifier = function(value) prefs.DensityEnabled.value = value end
        },
        vb:text{text = "Note Density Variation", font = "bold", style = "strong"}
      },
      create_slider_row("Add Notes %", 0, 50, prefs.DensityAddPercentage, "%"),
      create_slider_row("Remove Notes %", 0, 50, prefs.DensityRemovePercentage, "%")
    }
  }
  
  -- Right Column
  local right_column = vb:column{
    
    -- Effects Section
    vb:column{
      style = "group",
      width = group_width,
      
      vb:row{
        vb:checkbox{
          value = prefs.EffectsEnabled.value,
          notifier = function(value) prefs.EffectsEnabled.value = value end
        },
        vb:text{text = "Random Effect Commands", font = "bold", style = "strong"}
      },
      create_slider_row("Effect Chance", 0, 100, prefs.EffectsPercentage, "%"),
      vb:row{
        vb:text{text = "Write To", width = label_width},
        vb:popup{
          items = {"Effect Column", "Sample FX Column"},
          value = prefs.EffectsColumn.value,
          width = slider_width,
          notifier = function(value) prefs.EffectsColumn.value = value end
        }
      },
      vb:row{
        vb:checkbox{value = prefs.Effect_0Y_Enabled.value, notifier = function(v) prefs.Effect_0Y_Enabled.value = v end},
        vb:text{text = "0Y Probability"},
        vb:checkbox{value = prefs.Effect_0V_Enabled.value, notifier = function(v) prefs.Effect_0V_Enabled.value = v end},
        vb:text{text = "0V Vibrato"},
        vb:checkbox{value = prefs.Effect_0T_Enabled.value, notifier = function(v) prefs.Effect_0T_Enabled.value = v end},
        vb:text{text = "0T Tremolo"}
      },
      vb:row{
        vb:checkbox{value = prefs.Effect_0A_Enabled.value, notifier = function(v) prefs.Effect_0A_Enabled.value = v end},
        vb:text{text = "0A Arp"},
        vb:checkbox{value = prefs.Effect_0G_Enabled.value, notifier = function(v) prefs.Effect_0G_Enabled.value = v end},
        vb:text{text = "0G Glide"},
        vb:checkbox{value = prefs.Effect_0Q_Enabled.value, notifier = function(v) prefs.Effect_0Q_Enabled.value = v end},
        vb:text{text = "0Q Delay"},
        vb:checkbox{value = prefs.Effect_0S_Enabled.value, notifier = function(v) prefs.Effect_0S_Enabled.value = v end},
        vb:text{text = "0S Offset"}
      }
    },
    
    -- Ghost Notes Section
    vb:column{
      style = "group",
      width = group_width,
      
      vb:row{
        vb:checkbox{
          value = prefs.GhostEnabled.value,
          notifier = function(value) prefs.GhostEnabled.value = value end
        },
        vb:text{text = "Ghost Notes (Rolls)", font = "bold", style = "strong"}
      },
      create_slider_row("Percentage", 0, 100, prefs.GhostPercentage, "%"),
      create_slider_row("Ghost Count", 1, 4, prefs.GhostCount),
      vb:row{
        vb:text{text = "Direction", width = label_width},
        vb:popup{
          items = {"Build-up (before)", "Trail-off (after)"},
          value = prefs.GhostDirection.value,
          width = slider_width,
          notifier = function(value) prefs.GhostDirection.value = value end
        }
      },
      create_slider_row("Volume Start", 1, 100, prefs.GhostVolumeStart, "%"),
      create_slider_row("Volume End", 1, 100, prefs.GhostVolumeEnd, "%")
    },
    
    -- Retrig Section
    vb:column{
      style = "group",
      width = group_width,
      
      vb:row{
        vb:checkbox{
          value = prefs.RetrigEnabled.value,
          notifier = function(value) prefs.RetrigEnabled.value = value end
        },
        vb:text{text = "Retrig (0Rxx)", font = "bold", style = "strong"}
      },
      create_slider_row("Percentage", 0, 100, prefs.RetrigPercentage, "%"),
      create_slider_row("Min Retrig", 1, 255, prefs.RetrigMin),
      create_slider_row("Max Retrig", 1, 255, prefs.RetrigMax),
      vb:row{
        vb:text{text = "Column", width = label_width},
        vb:popup{
          items = {"Effect Column", "Sample FX Column"},
          value = prefs.RetrigColumn.value,
          width = slider_width,
          notifier = function(value) prefs.RetrigColumn.value = value end
        }
      }
    },
    
    -- Automation Section
    vb:column{
      style = "group",
      width = group_width,
      
      vb:row{
        vb:checkbox{
          value = prefs.AutomationEnabled.value,
          notifier = function(value) prefs.AutomationEnabled.value = value end
        },
        vb:text{text = "Automation Wonkification", font = "bold", style = "strong"}
      },
      create_slider_row("Percentage", 0, 100, prefs.AutomationPercentage, "%"),
      create_slider_row("Value Variation (+/-)", 0, 50, prefs.AutomationValueVariation, "%"),
      create_slider_row("Time Variation (+/-)", 0, 8, prefs.AutomationTimeVariation, " lines")
    },
    
    -- Phrase Output Section
    vb:column{
      style = "group",
      width = group_width,
      
      vb:text{text = "Phrase Output", font = "bold", style = "strong"},
      vb:row{
        vb:text{text = "Start Phrase Slot", width = label_width},
        vb:valuebox{
          min = 1,
          max = 126,
          value = prefs.PhraseStartIndex.value,
          width = 60,
          notifier = function(value) prefs.PhraseStartIndex.value = value end
        },
        vb:button{
          text = "Write to Phrase",
          width = 100,
          notifier = PakettiWonkifyToPhrase
        }
      }
    }
  }
  
  local dialog_content = vb:column{
    
    -- Two column layout
    vb:row{
      left_column,
      right_column
    },
    
    -- Presets Section (spans both columns)
    vb:column{
      style = "group",
      width= group_width,
      vb:text{text = "Quick Presets", font = "bold", style = "strong"},
      vb:row{
        vb:button{text = "Subtle", width = 50, notifier = function() PakettiWonkifyApplyPreset(1) end},
        vb:button{text = "Drunk", width = 50, notifier = function() PakettiWonkifyApplyPreset(2) end},
        vb:button{text = "Lo-Fi", width = 50, notifier = function() PakettiWonkifyApplyPreset(3) end},
        vb:button{text = "Glitch", width = 50, notifier = function() PakettiWonkifyApplyPreset(4) end},
        vb:button{text = "Chaos", width = 50, notifier = function() PakettiWonkifyApplyPreset(5) end},
        vb:button{text = "Jazz", width = 50, notifier = function() PakettiWonkifyApplyPreset(6) end}
      }
    },
    
    -- Action Buttons
    vb:horizontal_aligner{
      mode = "center",
      
      vb:button{
        text = "Wonkify Current",
        width = group_width/1,
        notifier = PakettiWonkifyCurrentPattern
      },
      vb:button{
        text = "Duplicate & Wonkify",
        width = group_width/2,
        notifier = PakettiWonkifyDuplicatePattern
      },
      vb:button{
        text = "Generate Chain",
        width = group_width/2,
        notifier = PakettiWonkifyGenerateChain
      },
      vb:button{
        text = "To Phrase",
        width = group_width/2,
        notifier = PakettiWonkifyToPhrase
      }
    }
  }
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return wonkify_dialog end,
    function(value) wonkify_dialog = value end
  )
  
  wonkify_dialog = renoise.app():show_custom_dialog("Paketti Wonkify Advanced", dialog_content, keyhandler)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Wonkify Current Pattern", invoke=PakettiWonkifyCurrentPattern}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate & Wonkify Pattern", invoke=PakettiWonkifyDuplicatePattern}
renoise.tool():add_keybinding{name="Global:Paketti:Wonkify Generate Chain", invoke=PakettiWonkifyGenerateChain}
renoise.tool():add_keybinding{name="Global:Paketti:Wonkify Dialog", invoke=PakettiWonkifyDialog}
renoise.tool():add_keybinding{name="Global:Paketti:Wonkify Quick Dialog", invoke=PakettiWonkifyQuickDialog}
renoise.tool():add_keybinding{name="Global:Paketti:Wonkify Subtle Humanize", invoke=PakettiWonkifySubtleHumanize}
renoise.tool():add_keybinding{name="Global:Paketti:Wonkify Drunk Groove", invoke=PakettiWonkifyDrunkGroove}
renoise.tool():add_keybinding{name="Global:Paketti:Wonkify Selection Only", invoke=function()
  preferences.pakettiWonkify.OperationMode.value = 2
  PakettiWonkifyCurrentPattern()
end}
renoise.tool():add_keybinding{name="Global:Paketti:Wonkify To Phrase", invoke=PakettiWonkifyToPhrase}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wonkify Current Pattern", invoke=PakettiWonkifyCurrentPattern}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate & Wonkify Pattern", invoke=PakettiWonkifyDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wonkify Generate Chain", invoke=PakettiWonkifyGenerateChain}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wonkify Dialog", invoke=PakettiWonkifyDialog}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wonkify Quick Dialog", invoke=PakettiWonkifyQuickDialog}

renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Wonkify Current Pattern", invoke=PakettiWonkifyCurrentPattern}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Duplicate & Wonkify Pattern", invoke=PakettiWonkifyDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Wonkify Generate Chain", invoke=PakettiWonkifyGenerateChain}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Wonkify Dialog", invoke=PakettiWonkifyDialog}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Wonkify Quick Dialog", invoke=PakettiWonkifyQuickDialog}

renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Wonkify Current Pattern", invoke=PakettiWonkifyCurrentPattern}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Duplicate & Wonkify Pattern", invoke=PakettiWonkifyDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Wonkify Generate Chain", invoke=PakettiWonkifyGenerateChain}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Wonkify Dialog", invoke=PakettiWonkifyDialog}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Wonkify Quick Dialog", invoke=PakettiWonkifyQuickDialog}

-- MIDI Mappings
renoise.tool():add_midi_mapping{name="Paketti:Wonkify Current Pattern",
  invoke=function(message) 
    if message:is_trigger() then 
      PakettiWonkifyCurrentPattern() 
    end 
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Duplicate & Wonkify Pattern",
  invoke=function(message) 
    if message:is_trigger() then 
      PakettiWonkifyDuplicatePattern() 
    end 
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Wonkify Generate Chain",
  invoke=function(message) 
    if message:is_trigger() then 
      PakettiWonkifyGenerateChain() 
    end 
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Wonkify Dialog",
  invoke=function(message) 
    if message:is_trigger() then 
      PakettiWonkifyDialog() 
    end 
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Wonkify Quick Dialog",
  invoke=function(message) 
    if message:is_trigger() then 
      PakettiWonkifyQuickDialog() 
    end 
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Wonkify Intensity x[Knob]",
  invoke=function(message)
    local prefs = preferences.pakettiWonkify
    if message:is_abs_value() then
      prefs.GlobalIntensity.value = math.floor(message.int_value / 127 * 100)
    elseif message:is_rel_value() then
      local change = message.int_value > 64 and (message.int_value - 128) or message.int_value
      prefs.GlobalIntensity.value = math.max(0, math.min(100, prefs.GlobalIntensity.value + change))
    end
    renoise.app():show_status("Wonkify Intensity: " .. prefs.GlobalIntensity.value .. "%")
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Wonkify Subtle Humanize x[Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      PakettiWonkifySubtleHumanize()
    end
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Wonkify Drunk Groove x[Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      PakettiWonkifyDrunkGroove()
    end
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Wonkify Random Preset x[Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      local preset_index = math.random(1, #PakettiWonkify_builtin_presets)
      PakettiWonkifyApplyPreset(preset_index)
      PakettiWonkifyDuplicatePattern()
    end
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Wonkify To Phrase x[Trigger]",
  invoke=function(message)
    if message:is_trigger() then
      PakettiWonkifyToPhrase()
    end
  end
}
