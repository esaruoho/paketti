-- PakettiFill.lua
-- Advanced pattern filling tool with density control, note ranges, and random effects

local dialog = nil
local vb = nil

-- Note names for conversion
local note_names = {
  "C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"
}

-- Effects list from PakettiPatternEditorCheatSheet.lua with blacklist capability
local effects_list = {
  {"0A", "-Axy", "Set arpeggio, x/y = first/second note offset in semitones", false},
  {"0U", "-Uxx", "Slide Pitch up by xx 1/16ths of a semitone", false},
  {"0D", "-Dxx", "Slide Pitch down by xx 1/16ths of a semitone", false},
  {"0G", "-Gxx", "Glide towards given note by xx 1/16ths of a semitone", false},
  {"0I", "-Ixx", "Fade Volume in by xx volume units", false},
  {"0O", "-Oxx", "Fade Volume out by xx volume units", false},
  {"0C", "-Cxy", "Cut volume to x after y ticks (x = volume factor: 0=0%, F=100%)", false},
  {"0Q", "-Qxx", "Delay note by xx ticks", false},
  {"0M", "-Mxx", "Set note volume to xx", false},
  {"0S", "-Sxx", "Trigger sample slice number xx or offset xx", false},
  {"0B", "-Bxx", "Play Sample Backwards (B00) or forwards again (B01)", false},
  {"0R", "-Rxy", "Retrigger line every y ticks with volume factor x", false},
  {"0Y", "-Yxx", "Maybe trigger line with probability xx, 00 = mutually exclusive note columns", false},
  {"0Z", "-Zxx", "Trigger Phrase xx (Phrase Number (01-7E), 00 = none, 7F = keymap)", false},
  {"0V", "-Vxy", "Set Vibrato x = speed, y = depth; x=(0-F); y=(0-F)", false},
  {"0T", "-Txy", "Set Tremolo x = speed, y = depth", false},
  {"0N", "-Nxy", "Set Auto Pan, x = speed, y = depth", false},
  {"0E", "-Exx", "Set Active Sample Envelope's Position to Offset XX", false},
  {"0L", "-Lxx", "Set Track Volume Level, 00 = -INF, FF = +3dB", true},
  {"0P", "-Pxx", "Set Track Pan, 00 = full left, 80 = center, FF = full right", true},
  {"0W", "-Wxx", "Set Track Surround Width, 00 = Min, FF = Max", true},
  {"0J", "-Jxx", "Set Track Routing, 01 upwards = hardware channels, FF downwards = parent groups", true},
  {"0X", "-Xxx", "Stop all notes and FX (xx = 00), or only effect xx (xx > 00)", true},
  {"ZT", "ZTxx", "Set tempo to xx BPM (14-FF, 00 = stop song)", true}, -- blacklisted by default
  {"ZL", "ZLxx", "Set Lines Per Beat (LPB) to xx lines", true}, -- blacklisted by default
  {"ZK", "ZKxx", "Set Ticks Per Line (TPL) to xx ticks (01-10)", true}, -- blacklisted by default
  {"ZG", "ZGxx", "Enable (xx = 01) or disable (xx = 00) Groove", true},
  {"ZB", "ZBxx", "Break pattern and jump to line xx in next", true}, -- blacklisted by default
  {"ZD", "ZDxx", "Delay (pause) pattern for xx lines", true} -- blacklisted by default
}

-- Convert note name and octave to note value
function PakettiFillNoteToValue(note_name, octave)
  for i, name in ipairs(note_names) do
    if name == note_name then
      return (octave * 12) + (i - 1)
    end
  end
  return 48 -- Default to C-4 if not found
end

-- Convert note value to note name and octave
function PakettiFillValueToNote(note_value)
  local octave = math.floor(note_value / 12)
  local note_index = (note_value % 12) + 1
  return note_names[note_index], octave
end

-- Generate random note within range
function PakettiFillGenerateRandomNote(from_note, to_note)
  if from_note > to_note then
    from_note, to_note = to_note, from_note
  end
  return math.random(from_note, to_note)
end

-- Get available effects (not blacklisted)
function PakettiFillGetAvailableEffects()
  local available = {}
  for _, effect in ipairs(effects_list) do
    if not effect[4] then -- not blacklisted
      table.insert(available, effect)
    end
  end
  return available
end

-- Generate appropriate random value for specific effects
function PakettiFillGenerateEffectValue(effect_command)
  if effect_command == "0B" then
    -- Backwards/Forwards: only 00 or 01
    return math.random(0, 1)
  elseif effect_command == "0C" then
    -- Cut volume: xy format where x=volume factor (0-F), y=ticks (0-F)
    local x = math.random(0, 15)
    local y = math.random(0, 15)
    return (x * 16) + y
  elseif effect_command == "0Z" then
    -- Phrase trigger: 00=none, 01-7E=phrase numbers, 7F=keymap
    return math.random(0, 127)
  elseif effect_command == "0V" or effect_command == "0T" or effect_command == "0N" then
    -- Vibrato/Tremolo/AutoPan: xy format where x=speed (0-F), y=depth (0-F)
    local x = math.random(0, 15)
    local y = math.random(0, 15)
    return (x * 16) + y
  elseif effect_command == "0R" then
    -- Retrigger: xy format where x=volume factor (0-F), y=ticks (0-F)
    local x = math.random(0, 15)
    local y = math.random(1, 15) -- y shouldn't be 0 for retrigger
    return (x * 16) + y
  else
    -- Default random value for other effects
    return math.random(0, 255)
  end
end

-- Generate Euclidean rhythm pattern
function PakettiFillGenerateEuclideanPattern(events, pattern_length)
  if events <= 0 or pattern_length <= 0 then
    return {}
  end
  
  if events >= pattern_length then
    -- Fill all steps if events >= pattern_length
    local pattern = {}
    for i = 1, pattern_length do
      pattern[i] = true
    end
    return pattern
  end
  
  -- Euclidean algorithm - distribute events evenly starting from step 1
  local pattern = {}
  for i = 1, pattern_length do
    pattern[i] = false
  end
  
  -- Place events using the Euclidean distribution
  local step_size = pattern_length / events
  for i = 0, events - 1 do
    local position = math.floor(i * step_size) + 1
    if position <= pattern_length then
      pattern[position] = true
    end
  end
  
  return pattern
end

-- Get sample name for note value from current instrument (truncated to 15 chars)
function PakettiFillGetSampleName(note_value)
  local song = renoise.song()
  local instrument = song:instrument(song.selected_instrument_index)
  
  if not instrument or #instrument.samples == 0 then
    local note_name, octave = PakettiFillValueToNote(note_value)
    return string.format("%s%d", note_name, octave)
  end
  
  -- Simple approach: use note value to map to sample index
  -- C-4 (48) = sample 1, C#4 (49) = sample 2, etc.
  local sample_index = (note_value % #instrument.samples) + 1
  local sample = instrument:sample(sample_index)
  
  if sample and sample.name and sample.name ~= "" then
    -- Truncate to 9 characters max to fit 80px width
    local name = sample.name
    if #name > 9 then
      name = string.sub(name, 1, 9) .. ".."
    end
    return name
  else
    -- Sample exists but no name, use sample index
    return "Sample " .. tostring(sample_index)
  end
end

-- Check Where? conditions (Polyend-style logic)
function PakettiFillShouldFillLine(pattern_line, where_mode, line_index, step_interval, selection, density, euclidean_pattern)
  -- 1=Note, 2=No Note, 3=FX, 4=No FX, 5=Random, 6=Each, 7=Euclidean
  if where_mode == 1 then -- Note: only fill where notes exist
    for i = 1, #pattern_line.note_columns do
      if pattern_line.note_columns[i].note_value ~= renoise.PatternLine.EMPTY_NOTE then
        return true
      end
    end
    return false
  elseif where_mode == 2 then -- No Note: only fill empty note slots
    for i = 1, #pattern_line.note_columns do
      if pattern_line.note_columns[i].note_value ~= renoise.PatternLine.EMPTY_NOTE then
        return false
      end
    end
    return true
  elseif where_mode == 3 then -- FX: only fill where effects exist
    for i = 1, #pattern_line.effect_columns do
      if not pattern_line.effect_columns[i].is_empty then
        return true
      end
    end
    return false
  elseif where_mode == 4 then -- No FX: only fill empty effect slots
    for i = 1, #pattern_line.effect_columns do
      if not pattern_line.effect_columns[i].is_empty then
        return false
      end
    end
    return true
  elseif where_mode == 5 then -- Random: use density
    return math.random(100) <= density
  elseif where_mode == 6 then -- Each: step intervals
    local relative_line = line_index - selection.start_line
    local edit_step = renoise.song().transport.edit_step
    return (relative_line % edit_step) == 0
  elseif where_mode == 7 then -- Euclidean: use pattern starting from row 00
    if euclidean_pattern and #euclidean_pattern > 0 then
      local relative_line = line_index - selection.start_line  -- 0-based from start of selection
      local pattern_index = (relative_line % #euclidean_pattern) + 1  -- 1-based Lua index
      return euclidean_pattern[pattern_index]
    end
    return false
  end
  return false
end

-- Apply fill to pattern selection
function PakettiFillApplyFill(density, fill_type, from_note, to_note, constant_note, use_random_fx, effects_only, selected_effect, where_mode, step_interval, selected_effect_index, effect_min_value, effect_max_value, use_editstep)
  local song = renoise.song()
  local selection = song.selection_in_pattern
  
  if not selection then
    renoise.app():show_status("No pattern selection found")
    return
  end
  
  local available_effects = PakettiFillGetAvailableEffects()
  
  -- Generate Euclidean pattern if needed
  local euclidean_pattern = nil
  if where_mode == 7 then -- Euclidean
    -- density = events (number of hits)
    local events = math.max(1, density)
    
    -- Use EditStep or Step Length based on checkbox
    local step_length
    if use_editstep then
      step_length = renoise.song().transport.edit_step
    else
      step_length = math.max(1, step_interval)
    end
    
    euclidean_pattern = PakettiFillGenerateEuclideanPattern(events, step_length)
  end
  
  -- Iterate through selection
  for track_index = selection.start_track, selection.end_track do
    local track = song:track(track_index)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      local note_columns_visible = track.visible_note_columns
      local effect_columns_visible = track.visible_effect_columns
      
      -- Ensure at least one note column is visible (unless effects only)
      if not effects_only and note_columns_visible == 0 then
        track.visible_note_columns = 1
        note_columns_visible = 1
      end
      
      -- Ensure effect columns are visible if using random FX
      if use_random_fx and effect_columns_visible == 0 then
        track.visible_effect_columns = 1
        effect_columns_visible = 1
      end
      
      local start_column = (track_index == selection.start_track) and selection.start_column or 1
      local end_column = (track_index == selection.end_track) and selection.end_column or note_columns_visible
      
      -- Process lines
      for line_index = selection.start_line, selection.end_line do
        local pattern_line = song:pattern(song.selected_pattern_index):track(track_index):line(line_index)
        
        -- Check if this line should be filled based on Where? conditions
        if PakettiFillShouldFillLine(pattern_line, where_mode, line_index, step_interval, selection, density, euclidean_pattern) then
          -- Determine what to write based on where_mode and effects_only
          local write_notes = true
          local write_effects = true
          
          if effects_only then
            -- Effects Only checkbox: only effects, no notes
            write_notes = false
            write_effects = true
          elseif where_mode == 3 then -- "FX" mode: only effects
            write_notes = false 
            write_effects = true
          elseif where_mode == 4 then -- "No FX" mode: only notes
            write_notes = true
            write_effects = false
          else
            -- All other modes: both notes and effects
            write_notes = true
            write_effects = true
          end
          
          -- Write notes if allowed
          if write_notes then
            for col = start_column, math.min(end_column, note_columns_visible) do
              local note_column = pattern_line:note_column(col)
              
              -- Generate note based on fill type
              local note_value
              if fill_type == 1 then -- Constant
                note_value = constant_note
              elseif fill_type == 2 then -- From-To (distributed evenly)
                -- Calculate position in range based on line position
                local range_size = selection.end_line - selection.start_line
                local line_position = line_index - selection.start_line
                local ratio = range_size > 0 and line_position / range_size or 0
                note_value = math.floor(from_note + (ratio * (to_note - from_note)))
              else -- Random
                note_value = PakettiFillGenerateRandomNote(from_note, to_note)
              end
              
              -- Set the note
              note_column.note_value = note_value
              note_column.instrument_value = song.selected_instrument_index - 1
            end
          end
          
          -- Write effects if allowed
          if write_effects and effect_columns_visible > 0 then
            local effect_column = pattern_line:effect_column(1)
            if effect_column then
              local effect_to_use
              if use_random_fx and #available_effects > 0 then
                -- Random FX takes precedence over dropdown selection
                effect_to_use = available_effects[math.random(#available_effects)]
              elseif selected_effect_index == 1 then
                -- "<No Effect>" selected and Random FX is off: clear effect
                effect_column.number_string = ".."
                effect_column.amount_value = 0
                effect_to_use = nil  -- Don't process further
              elseif selected_effect then 
                -- Specific effect selected
                effect_to_use = selected_effect
              end
              
              if effect_to_use then
                effect_column.number_string = effect_to_use[1]
                -- Use min/max range for effect values if specific effect is selected
                if not use_random_fx and selected_effect then
                  local min_val = math.min(effect_min_value, effect_max_value)
                  local max_val = math.max(effect_min_value, effect_max_value)
                  effect_column.amount_value = math.random(min_val, max_val)
                else
                  effect_column.amount_value = PakettiFillGenerateEffectValue(effect_to_use[1])
                end
              end
            end
          end
        end
      end
    end
  end
  
  local mode_text = effects_only and "effects-only" or "notes"
  renoise.app():show_status(string.format("PakettiFill: Applied %d%% density %s fill to selection", density, mode_text))
end

-- Toggle effect blacklist status
function PakettiFillToggleEffectBlacklist(effect_index)
  effects_list[effect_index][4] = not effects_list[effect_index][4]
end

-- Global state variables (persist across dialog rebuilds)
local paketti_fill_density_value = 50
local paketti_fill_fill_type = 1 -- 1=Constant, 2=From-To, 3=Random
local paketti_fill_from_note_value = 48 -- C-4
local paketti_fill_to_note_value = 72   -- C-6 (safer default within B-9 range)
local paketti_fill_constant_note_name = "C-"
local paketti_fill_constant_octave = 4
local paketti_fill_use_random_fx = false
local paketti_fill_effects_only = false
local paketti_fill_show_effects_config = false
local paketti_fill_selected_effect_index = 1
local paketti_fill_where_mode = 1 -- 1=Note, 2=No Note, 3=FX, 4=No FX, 5=Random, 6=Each
local paketti_fill_step_interval = 8 -- For "Each" and Euclidean modes
local paketti_fill_effect_min_value = 0  -- Min parameter value (00-FF)
local paketti_fill_effect_max_value = 255  -- Max parameter value (00-FF)
local paketti_fill_use_editstep = true  -- Use EditStep instead of Step Length slider in Euclidean mode

-- Create the main dialog
function PakettiFillShowDialog()
  if dialog and dialog.visible then
    dialog:close()
    return
  end
  
  vb = renoise.ViewBuilder()
  
  -- Use global state variables
  local density_value = paketti_fill_density_value
  local fill_type = paketti_fill_fill_type
  local from_note_value = paketti_fill_from_note_value
  local to_note_value = paketti_fill_to_note_value
  local constant_note_name = paketti_fill_constant_note_name
  local constant_octave = paketti_fill_constant_octave
  local use_random_fx = paketti_fill_use_random_fx
  local effects_only = paketti_fill_effects_only
  local show_effects_config = paketti_fill_show_effects_config
  local selected_effect_index = paketti_fill_selected_effect_index
  local where_mode = paketti_fill_where_mode
  local step_interval = paketti_fill_step_interval
  local effect_min_value = paketti_fill_effect_min_value
  local effect_max_value = paketti_fill_effect_max_value
  local use_editstep = paketti_fill_use_editstep
  
  -- Density slider (vertical)
  local density_label = vb:text{
    text = "Density",
    style = "strong",
    font = "bold"
  }
  
  local density_value_text = vb:text{
    text = string.format("%d%%", density_value),
    style = "strong",
    font = "bold"
  }
  
  local density_slider = vb:slider{
    min = 0,
    max = 100,
    value = density_value,
    width = 80,  -- Match other sliders for consistency
    height = 200,
    steps = {1, 10},  -- Small step: 1%, Big step: 10%
    notifier = function(value)
      density_value = math.floor(value)
      paketti_fill_density_value = density_value  -- Save to global
      if where_mode == 6 or where_mode == 7 then -- Each or Euclidean
        density_value_text.text = tostring(density_value)
      else
        density_value_text.text = string.format("%d%%", density_value)
      end
    end
  }
  
  -- Note range sliders (vertical) - declared first so they can be referenced
  local from_label = vb:text{
    text = "From",
    style = "strong",
    font = "bold"
  }
  
  local from_note_text = vb:text{
    text = string.format("%s%d", PakettiFillValueToNote(from_note_value)),
    style = "strong",
    font = "bold",
    width = 80  -- Fixed width to prevent jittering
  }
  
  local from_note_slider = vb:slider{
    min = 0,
    max = 119, -- B-9 is the highest note in Renoise
    value = from_note_value,
    width = 80,  -- Match From Sample text width
    height = 200,
    steps = {1, 12},  -- Small step: 1 semitone, Big step: 1 octave
    notifier = function(value)
      from_note_value = math.floor(value)
      paketti_fill_from_note_value = from_note_value  -- Save to global
      if where_mode == 7 then -- Euclidean: show sample names
        from_note_text.text = PakettiFillGetSampleName(from_note_value)
      else
        local note_name, octave = PakettiFillValueToNote(from_note_value)
        from_note_text.text = string.format("%s%d", note_name, octave)
      end
    end
  }
  
  local to_label = vb:text{
    text = "To",
    style = "strong",
    font = "bold"
  }
  
  local to_note_text = vb:text{
    text = string.format("%s%d", PakettiFillValueToNote(to_note_value)),
    style = "strong",
    font = "bold",
    width = 80  -- Fixed width to prevent jittering
  }
  
  local to_note_slider = vb:slider{
    min = 0,
    max = 119, -- B-9 is the highest note in Renoise
    value = to_note_value,
    width = 80,  -- Match To Sample text width
    height = 200,
    steps = {1, 12},  -- Small step: 1 semitone, Big step: 1 octave
    active = false, -- Start disabled since we're in Constant mode
    notifier = function(value)
      to_note_value = math.floor(value)
      paketti_fill_to_note_value = to_note_value  -- Save to global
      if where_mode == 7 then -- Euclidean: show sample names
        to_note_text.text = PakettiFillGetSampleName(to_note_value)
      else
        local note_name, octave = PakettiFillValueToNote(to_note_value)
        to_note_text.text = string.format("%s%d", note_name, octave)
      end
    end
  }

  -- Fill type selection (dropdown) - declared after sliders so it can reference them
  local fill_type_text = vb:text{
    text = "Fill Type",
    style = "strong",
    font = "bold"
  }
  
  local fill_type_popup = vb:popup{
    items = {"Constant", "From-To", "Random"},
    value = fill_type,
    width = 120,
    notifier = function(value)
      fill_type = value
      paketti_fill_fill_type = value  -- Save to global
      -- Enable/disable To slider based on fill type
      if fill_type == 1 then -- Constant
        to_note_slider.active = false
      else -- From-To or Random
        to_note_slider.active = true
      end
    end
  }
  

  
  -- Step interval control (for Euclidean mode)
  local step_interval_text = vb:text{
    text = (where_mode == 7) and "Step Length" or "Step",
    style = "strong",
    font = "bold"
  }
  
  local step_interval_value_text = vb:text{
    text = tostring(step_interval),
    style = "strong",
    font = "bold"
  }
  
  local step_interval_slider = vb:slider{
    min = 1,
    max = 16,  -- Reasonable max for Euclidean step lengths
    value = step_interval,
    width = 80,  -- Match Step Length text width
    height = 200,
    steps = {1, 4},  -- Small step: 1, Big step: 4
    active = (where_mode == 7 and not use_editstep),  -- Active when Euclidean mode and not using EditStep
    notifier = function(value)
      step_interval = math.floor(value)
      paketti_fill_step_interval = step_interval  -- Save to global
      step_interval_value_text.text = tostring(step_interval)
    end
  }
  
  -- EditStep checkbox for Euclidean mode
  local use_editstep_checkbox = vb:checkbox{
    value = use_editstep,
    notifier = function(value)
      use_editstep = value
      paketti_fill_use_editstep = value  -- Save to global
      -- Update slider active state and text display
      if where_mode == 7 then -- Euclidean mode
        step_interval_slider.active = not use_editstep
        if use_editstep then
          local current_editstep = renoise.song().transport.edit_step
          step_interval_value_text.text = tostring(current_editstep)
          step_interval_text.text = "EditStep"
        else
          step_interval_value_text.text = tostring(step_interval)
          step_interval_text.text = "Step Length"
        end
      end
    end
  }
  
  -- Function to update EditStep display and sample names
  local function PakettiFillUpdateRealTimeValues()
    if dialog and dialog.visible then
      -- Update EditStep display if using EditStep in Euclidean mode
      if where_mode == 7 and use_editstep then
        local current_editstep = renoise.song().transport.edit_step
        step_interval_value_text.text = tostring(current_editstep)
      end
      
      -- Update sample names in Euclidean mode if instrument changed
      if where_mode == 7 then
        local new_from_name = PakettiFillGetSampleName(from_note_value)
        local new_to_name = PakettiFillGetSampleName(to_note_value)
        if from_note_text.text ~= new_from_name then
          from_note_text.text = new_from_name
        end
        if to_note_text.text ~= new_to_name then
          to_note_text.text = new_to_name
        end
      end
    end
  end
  
  -- Add real-time update using idle notifier for frequent updates
  if not renoise.tool().app_idle_observable:has_notifier(PakettiFillUpdateRealTimeValues) then
    renoise.tool().app_idle_observable:add_notifier(PakettiFillUpdateRealTimeValues)
  end
  
  -- Where? selection (Polyend-style) - declared after all referenced elements
  local where_text = vb:text{
    text = "Where?",
    style = "strong",
    font = "bold"
  }
  
  local where_popup = vb:popup{
    items = {"Note", "No Note", "FX", "No FX", "Random", "Each", "Euclidean"},
    value = where_mode,
    width = 120,
    notifier = function(value)
      where_mode = value
      paketti_fill_where_mode = value  -- Save to global
      -- Update UI based on mode
      if where_mode == 6 then -- Each (uses transport.edit_step)
        density_label.text = "Density"
        density_slider.max = 100
        density_value_text.text = string.format("%d%%", density_value)
        step_interval_text.text = "EditStep: " .. tostring(renoise.song().transport.edit_step)
        step_interval_value_text.text = tostring(renoise.song().transport.edit_step)
        step_interval_slider.active = false  -- Disable slider for Each mode
        from_label.text = "From"
        to_label.text = "To"
        -- Update text displays to show note names
        local from_note_name, from_octave = PakettiFillValueToNote(from_note_value)
        from_note_text.text = string.format("%s%d", from_note_name, from_octave)
        local to_note_name, to_octave = PakettiFillValueToNote(to_note_value)
        to_note_text.text = string.format("%s%d", to_note_name, to_octave)
      elseif where_mode == 7 then -- Euclidean
        -- Auto-switch from Constant to Random for better Euclidean patterns
        if fill_type == 1 then -- If currently Constant
          fill_type = 3 -- Change to Random
          paketti_fill_fill_type = fill_type  -- Save to global
          fill_type_popup.value = fill_type
          -- Enable To slider since we're no longer in Constant mode
          to_note_slider.active = true
        end
        
        density_label.text = "Events"
        density_slider.max = 16  -- Max events should be reasonable
        density_value_text.text = tostring(density_value)
        
        -- Update Step Length or EditStep display based on checkbox
        if use_editstep then
          step_interval_text.text = "EditStep"
          step_interval_value_text.text = tostring(renoise.song().transport.edit_step)
          step_interval_slider.active = false
        else
          step_interval_text.text = "Step Length"
          step_interval_value_text.text = tostring(step_interval)
          step_interval_slider.active = true
          step_interval_slider.max = 16
        end
        
        from_label.text = "From Sample"
        to_label.text = "To Sample"
        -- Update text displays to show sample names
        from_note_text.text = PakettiFillGetSampleName(from_note_value)
        to_note_text.text = PakettiFillGetSampleName(to_note_value)
      else
        density_label.text = "Density"
        density_slider.max = 100
        density_value_text.text = string.format("%d%%", density_value)
        step_interval_text.text = "Step"
        step_interval_slider.active = false  -- Disable for other modes
        from_label.text = "From"
        to_label.text = "To"
        -- Update text displays to show note names
        local from_note_name, from_octave = PakettiFillValueToNote(from_note_value)
        from_note_text.text = string.format("%s%d", from_note_name, from_octave)
        local to_note_name, to_octave = PakettiFillValueToNote(to_note_value)
        to_note_text.text = string.format("%s%d", to_note_name, to_octave)
      end
    end
  }
  

  
  -- Effect selection dropdown
  local available_effects = PakettiFillGetAvailableEffects()
  local effect_names = {"<No Effect>"}  -- Add "No Effect" option as first item
  for i, effect in ipairs(available_effects) do
    -- Combine display name and description: "-Axy - Set arpeggio, x/y = first/second note offset in semitones"
    table.insert(effect_names, effect[2] .. " - " .. effect[3])
  end
  
  local effect_selector = vb:popup{
    items = effect_names,
    value = selected_effect_index,
    width = 120,
    notifier = function(value)
      selected_effect_index = value
      paketti_fill_selected_effect_index = value  -- Save to global
    end
  }
  
  -- Effect Parameter Min/Max Controls (visible when Random FX is checked)
  local effect_min_label = vb:text{
    text = "Min",
    style = "strong",
    font = "bold",
    visible = use_random_fx
  }
  
  local effect_min_value_text = vb:text{
    text = string.format("%02X", effect_min_value),
    style = "strong",
    font = "bold",
    visible = use_random_fx,
    width = 80  -- Fixed width to match other columns
  }
  
  local effect_min_slider = vb:slider{
    min = 0,
    max = 255,
    value = effect_min_value,
    width = 80,  -- Match other sliders
    height = 200,  -- Match From/To sliders
    steps = {1, 16},  -- Small step: 1, Big step: 16 (0x10)
    visible = use_random_fx,
    notifier = function(value)
      effect_min_value = math.floor(value)
      paketti_fill_effect_min_value = effect_min_value  -- Save to global
      effect_min_value_text.text = string.format("%02X", effect_min_value)
      -- Ensure min <= max
      if effect_min_value > effect_max_value then
        effect_max_value = effect_min_value
        paketti_fill_effect_max_value = effect_max_value
        effect_max_slider.value = effect_max_value
        effect_max_value_text.text = string.format("%02X", effect_max_value)
      end
    end
  }
  
  local effect_max_label = vb:text{
    text = "Max",
    style = "strong",
    font = "bold",
    visible = use_random_fx
  }
  
  local effect_max_value_text = vb:text{
    text = string.format("%02X", effect_max_value),
    style = "strong",
    font = "bold",
    visible = use_random_fx,
    width = 80  -- Fixed width to match other columns
  }
  
  local effect_max_slider = vb:slider{
    min = 0,
    max = 255,
    value = effect_max_value,
    width = 80,  -- Match other sliders
    height = 200,  -- Match From/To sliders
    steps = {1, 16},  -- Small step: 1, Big step: 16 (0x10)
    visible = use_random_fx,
    notifier = function(value)
      effect_max_value = math.floor(value)
      paketti_fill_effect_max_value = effect_max_value  -- Save to global
      effect_max_value_text.text = string.format("%02X", effect_max_value)
      -- Ensure max >= min
      if effect_max_value < effect_min_value then
        effect_min_value = effect_max_value
        paketti_fill_effect_min_value = effect_min_value
        effect_min_slider.value = effect_min_value
        effect_min_value_text.text = string.format("%02X", effect_min_value)
      end
    end
  }
  
  -- Random FX checkbox
  local random_fx_checkbox = vb:checkbox{
    value = use_random_fx,
    notifier = function(value)
      use_random_fx = value
      paketti_fill_use_random_fx = value  -- Save to global
    end
  }
  
  -- Random FX checkbox
  local random_fx_checkbox = vb:checkbox{
    value = use_random_fx,
    notifier = function(value)
      use_random_fx = value
      paketti_fill_use_random_fx = value  -- Save to global
      -- Show/hide effect min/max sliders based on Random FX checkbox
      effect_min_label.visible = use_random_fx
      effect_min_slider.visible = use_random_fx
      effect_min_value_text.visible = use_random_fx
      effect_max_label.visible = use_random_fx
      effect_max_slider.visible = use_random_fx
      effect_max_value_text.visible = use_random_fx
    end
  }
  
  -- Effects Only checkbox
  local effects_only_checkbox = vb:checkbox{
    value = effects_only,
    notifier = function(value)
      effects_only = value
      paketti_fill_effects_only = value  -- Save to global
    end
  }
  
  -- Configure Effects button
  local configure_effects_button = vb:button{
    text = "Configure Effects",
    width = 120,
    notifier = function()
      show_effects_config = not show_effects_config
      paketti_fill_show_effects_config = show_effects_config  -- Save to global
      -- Rebuild dialog to show/hide effects config
      dialog:close()
      PakettiFillShowDialog()
    end
  }
  
  -- Effects blacklist
  local effects_column = vb:column{}
  for i, effect in ipairs(effects_list) do
    local effect_row = vb:row{
      vb:checkbox{
        value = not effect[4], -- inverted because checkbox shows "enabled"
        notifier = function(value)
          effects_list[i][4] = not value -- invert back to blacklist boolean
        end
      },
      vb:text{text = effect[2], width = 60},
      vb:text{text = effect[3], width = 300}
    }
    effects_column:add_child(effect_row)
  end
  
  -- Fill button
  local fill_button = vb:button{
    text = "Fill Pattern Selection",
    width = 120,
    notifier = function()
      -- For constant mode, use the lowest note from the range
      local constant_note_value = math.min(from_note_value, to_note_value)
      -- Handle "<No Effect>" option (index 1) - pass nil for no effect
      local selected_effect = nil
      if selected_effect_index > 1 then
        selected_effect = available_effects[selected_effect_index - 1]  -- Adjust for "<No Effect>" offset
      end
      
      PakettiFillApplyFill(density_value, fill_type, from_note_value, to_note_value, constant_note_value, use_random_fx, effects_only, selected_effect, where_mode, step_interval, selected_effect_index, effect_min_value, effect_max_value, use_editstep)
      
      -- Return focus to middle frame for keyboard shortcuts
      renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
    end
  }
  
  -- Fill Track button
  local fill_track_button = vb:button{
    text = "Fill Track",
    width = 120,
    notifier = function()
      local song = renoise.song()
      local pattern_index = song.selected_pattern_index
      local track_index = song.selected_track_index
      local pattern = song:pattern(pattern_index)
      local track = song:track(track_index)
      
      -- Create a selection that covers the entire track
      local temp_selection = {
        start_track = track_index,
        end_track = track_index,
        start_line = 1,
        end_line = pattern.number_of_lines,
        start_column = 1,
        end_column = track.visible_note_columns  -- Use actual visible columns
      }
      
      -- For constant mode, use the lowest note from the range
      local constant_note_value = math.min(from_note_value, to_note_value)
      -- Handle "<No Effect>" option (index 1) - pass nil for no effect
      local selected_effect = nil
      if selected_effect_index > 1 then
        selected_effect = available_effects[selected_effect_index - 1]  -- Adjust for "<No Effect>" offset
      end
      
      -- Temporarily override selection for track fill
      local original_selection = song.selection_in_pattern
      song.selection_in_pattern = temp_selection
      
      PakettiFillApplyFill(density_value, fill_type, from_note_value, to_note_value, constant_note_value, use_random_fx, effects_only, selected_effect, where_mode, step_interval, selected_effect_index, effect_min_value, effect_max_value, use_editstep)
      
      -- Restore original selection
      song.selection_in_pattern = original_selection
      
      -- Return focus to middle frame for keyboard shortcuts
      renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
    end
  }
  
  -- Build content - SINGLE ROW layout as originally requested
  local content_items = {
    -- MAIN SINGLE ROW: [DENSITY/EVENTS] [STEP/INTERVAL] [MIDDLE CONTROLS] [FROM] [TO]
    vb:row{
      -- Density/Events vertical slider
      vb:column{
        vb:horizontal_aligner{
          mode = "center",
          density_label
        },
        density_slider,
        vb:horizontal_aligner{
          mode = "center",
          density_value_text
        }
      },
      
      -- Step interval/Step Length vertical slider (disabled for "Each" mode)
      vb:column{
        vb:horizontal_aligner{
          mode = "center",
          step_interval_text
        },
        step_interval_slider,
        vb:horizontal_aligner{
          mode = "center",
          step_interval_value_text
        },

      },
      
      -- Middle column: Where? + Fill Type + Effect controls + Fill button
      vb:column{
        where_text,
        where_popup,
        fill_type_text,
        fill_type_popup,
        vb:space{height = 5},
        effect_selector,
        vb:row{
          random_fx_checkbox,
          vb:text{text = "Random FX", style="strong", font="bold"}
        },
        vb:row{
          effects_only_checkbox,
          vb:text{text = "FX Only", style="strong", font="bold"}
        },
        vb:row{
          use_editstep_checkbox,
          vb:text{text = "Use EditStep", style="strong", font="bold"}
        },
        configure_effects_button,
        fill_button,
        fill_track_button
      },
      
      -- From note vertical slider
      vb:column{
        vb:horizontal_aligner{
          mode = "center",
          from_label
        },
        from_note_slider,
        vb:horizontal_aligner{
          mode = "center",
          from_note_text
        }
      },
      
      -- To note vertical slider
      vb:column{
        vb:horizontal_aligner{
          mode = "center",
          to_label
        },
        to_note_slider,
        vb:horizontal_aligner{
          mode = "center",
          to_note_text
        }
      },
      
      -- Effect Min vertical slider
      vb:column{
        vb:horizontal_aligner{
          mode = "center",
          effect_min_label
        },
        effect_min_slider,
        vb:horizontal_aligner{
          mode = "center",
          effect_min_value_text
        }
      },
      
      -- Effect Max vertical slider
      vb:column{
        vb:horizontal_aligner{
          mode = "center",
          effect_max_label
        },
        effect_max_slider,
        vb:horizontal_aligner{
          mode = "center",
          effect_max_value_text
        }
      }
    }
  }
  
  -- Add effects configuration if visible
  if show_effects_config then
    table.insert(content_items, vb:column{
      vb:text{text = "Configure Randomized Effect Blacklist", style = "strong", font = "bold"},
      effects_column
    })
  end
    
  -- Main layout
  local content = vb:column{
    table.unpack(content_items)
  }
  
  -- Create dialog with key handler
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  
  dialog = renoise.app():show_custom_dialog("Paketti Fill", content, keyhandler)
  
  -- Set active middle frame after showing dialog
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  -- Force update UI state based on current mode
  if where_mode == 7 then -- Euclidean mode
    step_interval_slider.active = not use_editstep
    if use_editstep then
      step_interval_text.text = "EditStep"
      step_interval_value_text.text = tostring(renoise.song().transport.edit_step)
    else
      step_interval_text.text = "Step Length"
      step_interval_value_text.text = tostring(step_interval)
    end
  end
  

end

-- Add menu entry and keybinding
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti Fill Dialog...", invoke = PakettiFillShowDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Paketti Fill Dialog...", invoke = PakettiFillShowDialog}
