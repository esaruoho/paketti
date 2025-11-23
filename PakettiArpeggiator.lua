-- PakettiArpeggiator.lua
-- Musical Chord Progression Arpeggiator
-- Lua 5.1 only. All functions GLOBAL and defined before first use.

-- State
PakettiArp_dialog = nil
PakettiArp_vb = nil
PakettiArp_playing = false
PakettiArp_use_current_bpm = true
PakettiArp_bpm = 135
PakettiArp_key = "C"
PakettiArp_mode = "ionian"
PakettiArp_steps = 4
PakettiArp_pattern_type = "straight"
PakettiArp_pattern_id = 1
PakettiArp_chord_progression = {1,3,7,4,5,3,6,2} -- default progression (indexes into scale)
PakettiArp_current_chord_step = 1
PakettiArp_current_arp_step = 1
PakettiArp_arp_repeat = 2
PakettiArp_octave_base = 4
PakettiArp_current_patterns = {}
PakettiArp_current_arpeggio = {}
PakettiArp_scale_notes = {}
PakettiArp_line_notifier = nil
PakettiArp_pattern_changed_notifier = nil
PakettiArp_canvas_views = {}

-- Musical scale dictionary
PakettiArp_keys = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

PakettiArp_flat_to_sharp = {
  Cb = "B", Db = "C#", Eb = "D#", Fb = "E",
  Gb = "F#", Ab = "G#", Bb = "A#"
}

PakettiArp_modes = {
  "ionian", "dorian", "phrygian", "lydian", 
  "mixolydian", "aeolian", "locrian",
  "major", "minor", "melodic", "harmonic"
}

PakettiArp_scale_data = {
  ion = { name = "Ionian", steps = {0,2,4,5,7,9,11}, triads = {"maj","min","min","maj","maj","min","dim"} },
  dor = { name = "Dorian", steps = {0,2,3,5,7,9,10}, triads = {"min","min","maj","maj","min","dim","maj"} },
  phr = { name = "Phrygian", steps = {0,1,3,5,7,8,10}, triads = {"min","maj","maj","min","dim","maj","min"} },
  lyd = { name = "Lydian", steps = {0,2,4,6,7,9,11}, triads = {"maj","min","min","dim","maj","min","min"} },
  mix = { name = "Mixolydian", steps = {0,2,4,5,7,9,10}, triads = {"maj","min","dim","maj","min","min","maj"} },
  aeo = { name = "Aeolian", steps = {0,2,3,5,7,8,10}, triads = {"min","dim","maj","min","min","maj","maj"} },
  loc = { name = "Locrian", steps = {0,1,3,5,6,8,10}, triads = {"dim","maj","min","min","maj","maj","min"} },
  mel = { name = "Melodic Minor", steps = {0,2,3,5,7,9,11}, triads = {"min","min","aug","maj","maj","dim","dim"} },
  har = { name = "Harmonic Minor", steps = {0,2,3,5,7,8,11}, triads = {"min","dim","aug","min","maj","maj","dim"} }
}

PakettiArp_triad_intervals = {
  maj = {0,4,7},
  min = {0,3,7},
  dim = {0,3,6},
  aug = {0,4,8}
}

-- Convert mode name to mode key
function PakettiArp_ModeToKey(mode)
  local map = {
    minor = "aeo", major = "ion", ionian = "ion",
    dorian = "dor", phrygian = "phr", lydian = "lyd",
    mixolydian = "mix", aeolian = "aeo", locrian = "loc",
    melodic = "mel", harmonic = "har"
  }
  return map[mode] or "ion"
end

-- Generate musical scale with triads
function PakettiArp_GenerateScale(key, mode)
  local scale = {}
  local mode_key = PakettiArp_ModeToKey(mode)
  local scale_info = PakettiArp_scale_data[mode_key]
  
  if not scale_info then return scale end
  
  -- Find key offset
  local key_offset = 0
  for i = 1, #PakettiArp_keys do
    if PakettiArp_keys[i] == key then
      key_offset = i - 1
      break
    end
  end
  
  -- Generate notes
  for s = 1, #scale_info.steps do
    local step = scale_info.steps[s]
    local note_idx = ((key_offset + step) % 12) + 1
    local note_name = PakettiArp_keys[note_idx]
    local rel_octave = (key_offset + step >= 12) and 1 or 0
    
    -- Generate triad
    local triad_type = scale_info.triads[s]
    local triad_steps = PakettiArp_triad_intervals[triad_type]
    local triad_notes = {}
    
    for t = 1, #triad_steps do
      local triad_step = triad_steps[t]
      local triad_idx = ((key_offset + step + triad_step) % 12) + 1
      local triad_octave = math.floor((key_offset + step + triad_step) / 12)
      table.insert(triad_notes, {
        note = PakettiArp_keys[triad_idx],
        rel_octave = rel_octave + triad_octave
      })
    end
    
    table.insert(scale, {
      step = s,
      note = note_name,
      rel_octave = rel_octave,
      triad = {
        type = triad_type,
        notes = triad_notes
      }
    })
  end
  
  return scale
end

-- Generate arpeggio patterns using permutations
function PakettiArp_Permute(arr, used, result)
  if #arr == 0 then
    local copy = {}
    for i = 1, #used do copy[i] = used[i] end
    table.insert(result, copy)
    return
  end
  
  for i = 1, #arr do
    local val = table.remove(arr, i)
    table.insert(used, val)
    PakettiArp_Permute(arr, used, result)
    table.remove(used)
    table.insert(arr, i, val)
  end
end

function PakettiArp_GeneratePatterns(steps)
  local arr = {}
  for i = 0, steps - 1 do table.insert(arr, i) end
  
  local straight = {}
  PakettiArp_Permute(arr, {}, straight)
  
  local looped = {}
  for p = 1, #straight do
    local perm = straight[p]
    local loop = {}
    for i = 1, #perm do table.insert(loop, perm[i]) end
    for x = #perm - 1, 2, -1 do
      table.insert(loop, perm[x])
    end
    table.insert(looped, loop)
  end
  
  return { straight = straight, looped = looped }
end

-- Convert note to MIDI value
function PakettiArp_NoteToMidi(note_name, octave)
  local note_values = {
    C = 0, ["C#"] = 1, D = 2, ["D#"] = 3,
    E = 4, F = 5, ["F#"] = 6, G = 7,
    ["G#"] = 8, A = 9, ["A#"] = 10, B = 11
  }
  local base = note_values[note_name]
  if not base then return 60 end
  return (octave * 12) + base
end

-- Update scale
function PakettiArp_UpdateScale()
  PakettiArp_scale_notes = PakettiArp_GenerateScale(PakettiArp_key, PakettiArp_mode)
  PakettiArp_UpdateUI()
end

-- Update patterns
function PakettiArp_UpdatePatterns()
  PakettiArp_current_patterns = PakettiArp_GeneratePatterns(PakettiArp_steps)
  local patterns = PakettiArp_current_patterns[PakettiArp_pattern_type]
  if PakettiArp_pattern_id > #patterns then
    PakettiArp_pattern_id = 1
  end
  PakettiArp_current_arpeggio = patterns[PakettiArp_pattern_id]
  PakettiArp_UpdateUI()
end

-- Render arpeggio pattern to canvas
function PakettiArp_RenderPattern(context, pattern, is_selected)
  if not pattern or #pattern == 0 then return end
  
  local width = context.size.width
  local height = context.size.height
  local padding = 6
  
  -- Draw background based on selection
  if is_selected then
    context.fill_color = {255, 187, 0}
  else
    context.fill_color = {255, 255, 255}
  end
  context:fill_rect(0, 0, width, height)
  
  -- Find max value for scaling
  local max_val = 0
  for i = 1, #pattern do
    if pattern[i] > max_val then max_val = pattern[i] end
  end
  
  if max_val == 0 then return end
  
  local step_width = (width - padding * 2) / (#pattern - 1)
  local step_height = (height - padding * 2) / max_val
  
  -- Draw path
  context:begin_path()
  for i = 1, #pattern do
    local x = padding + (i - 1) * step_width
    local y = height - padding - (pattern[i] * step_height)
    if i == 1 then
      context:move_to(x, y)
    else
      context:line_to(x, y)
    end
  end
  
  context.stroke_color = {0, 0, 0}
  context.line_width = 2
  context:stroke()
  
  -- Draw points
  for i = 1, #pattern do
    local x = padding + (i - 1) * step_width
    local y = height - padding - (pattern[i] * step_height)
    context:begin_path()
    context:arc(x, y, 3, 0, math.pi * 2, false)
    if is_selected then
      context.fill_color = {34, 34, 34}
    else
      context.fill_color = {0, 0, 0}
    end
    context:fill()
  end
end

-- Audition state
PakettiArp_audition_playing = false
PakettiArp_audition_notes = {}
PakettiArp_audition_chord_idx = 1
PakettiArp_highlight_color = {40, 0, 72}  -- Deep purple from PakettiEightOneTwenty

-- Stop audition
function PakettiArp_StopAudition()
  if not PakettiArp_audition_playing then return end
  
  local song = renoise.song()
  local track_idx = song.selected_track_index
  local inst_idx = song.selected_instrument_index
  
  if #PakettiArp_audition_notes > 0 then
    song:trigger_instrument_note_off(inst_idx, track_idx, PakettiArp_audition_notes)
  end
  
  PakettiArp_audition_playing = false
  PakettiArp_audition_notes = {}
end

-- Play audition of current arpeggio - cycles through chords
function PakettiArp_PlayAudition()
  local was_playing = PakettiArp_audition_playing
  PakettiArp_StopAudition()
  
  local song = renoise.song()
  local track_idx = song.selected_track_index
  local inst_idx = song.selected_instrument_index
  
  if #PakettiArp_scale_notes == 0 then
    PakettiArp_UpdateScale()
  end
  
  if #PakettiArp_current_arpeggio == 0 then
    PakettiArp_UpdatePatterns()
  end
  
  -- Cycle to next chord if already playing
  if was_playing then
    PakettiArp_audition_chord_idx = PakettiArp_audition_chord_idx + 1
    if PakettiArp_audition_chord_idx > #PakettiArp_chord_progression then
      PakettiArp_audition_chord_idx = 1
    end
  else
    PakettiArp_audition_chord_idx = 1
  end
  
  PakettiArp_audition_playing = true
  PakettiArp_audition_notes = {}
  
  -- Get current chord from progression
  local chord_idx = PakettiArp_chord_progression[PakettiArp_audition_chord_idx]
  if chord_idx > 0 and chord_idx <= #PakettiArp_scale_notes then
    local chord = PakettiArp_scale_notes[chord_idx]
    
    -- Build note list for arpeggio
    local notes = {}
    for i = 1, #chord.triad.notes do
      table.insert(notes, chord.triad.notes[i])
    end
    
    -- Extend notes for higher steps
    local base_count = #notes
    for ext = 1, math.ceil(PakettiArp_steps / 3) do
      for i = 1, base_count do
        table.insert(notes, {
          note = notes[i].note,
          rel_octave = notes[i].rel_octave + ext
        })
      end
    end
    
    -- Play first few notes of the arpeggio pattern
    local play_count = math.min(4, #PakettiArp_current_arpeggio)
    for a = 1, play_count do
      local arp_idx = PakettiArp_current_arpeggio[a] + 1
      if arp_idx <= #notes then
        local note = notes[arp_idx]
        local midi_note = PakettiArp_NoteToMidi(note.note, note.rel_octave + PakettiArp_octave_base)
        table.insert(PakettiArp_audition_notes, midi_note)
      end
    end
    
    -- Trigger all notes as a chord
    if #PakettiArp_audition_notes > 0 then
      song:trigger_instrument_note_on(inst_idx, track_idx, PakettiArp_audition_notes, 1.0)
    end
  end
  
  -- Rebuild dialog to show highlighted chord
  if PakettiArp_dialog and PakettiArp_dialog.visible then
    PakettiArp_dialog:close()
    PakettiArp_ShowDialog()
  end
end

-- Toggle audition
function PakettiArp_ToggleAudition()
  if PakettiArp_audition_playing then
    PakettiArp_StopAudition()
  else
    PakettiArp_PlayAudition()
  end
end

-- Write arpeggio to pattern
function PakettiArp_WriteToPattern()
  local song = renoise.song()
  local track = song.selected_track
  
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("PakettiArp: Select a sequencer track")
    return
  end
  
  local patt = song:pattern(song.selected_pattern_index)
  local ptrack = patt:track(song.selected_track_index)
  local start_line = song.selected_line_index
  
  if #PakettiArp_scale_notes == 0 then
    PakettiArp_UpdateScale()
  end
  
  if #PakettiArp_current_arpeggio == 0 then
    PakettiArp_UpdatePatterns()
  end
  
  -- Calculate how many lines we need
  local total_steps = #PakettiArp_current_arpeggio * #PakettiArp_chord_progression * PakettiArp_arp_repeat
  
  if start_line + total_steps > patt.number_of_lines then
    renoise.app():show_status("PakettiArp: Not enough lines in pattern")
    return
  end
  
  -- Ensure visible note columns
  if track.visible_note_columns < 1 then
    track.visible_note_columns = 1
  end
  
  local line_idx = start_line
  local step_counter = 0
  
  for c = 1, #PakettiArp_chord_progression do
    local chord_idx = PakettiArp_chord_progression[c]
    if chord_idx > 0 and chord_idx <= #PakettiArp_scale_notes then
      local chord = PakettiArp_scale_notes[chord_idx]
      
      -- Build extended note list for arpeggio
      local notes = {}
      for i = 1, #chord.triad.notes do
        table.insert(notes, chord.triad.notes[i])
      end
      
      -- Extend notes for higher steps
      local base_count = #notes
      for ext = 1, math.ceil(PakettiArp_steps / 3) do
        for i = 1, base_count do
          table.insert(notes, {
            note = notes[i].note,
            rel_octave = notes[i].rel_octave + ext
          })
        end
      end
      
      for rep = 1, PakettiArp_arp_repeat do
        for a = 1, #PakettiArp_current_arpeggio do
          if line_idx <= patt.number_of_lines then
            local arp_idx = PakettiArp_current_arpeggio[a] + 1
            if arp_idx <= #notes then
              local note = notes[arp_idx]
              local midi_note = PakettiArp_NoteToMidi(note.note, note.rel_octave + PakettiArp_octave_base)
              
              local line = ptrack:line(line_idx)
              local ncol = line:note_column(1)
              ncol.note_value = midi_note
              ncol.instrument_value = song.selected_instrument_index - 1
              
              line_idx = line_idx + 1
            end
          end
        end
      end
    end
  end
  
  renoise.app():show_status("PakettiArp: Written " .. tostring(line_idx - start_line) .. " notes to pattern")
end

-- Key handler
function PakettiArp_KeyHandler(dialog, key)
  if key and key.name == "esc" then
    PakettiArp_StopAudition()
    if PakettiArp_dialog and PakettiArp_dialog.visible then
      PakettiArp_dialog:close()
    end
    return nil
  elseif key and key.name == "space" then
    PakettiArp_ToggleAudition()
    if PakettiArp_dialog and PakettiArp_dialog.visible then
      PakettiArp_dialog:close()
      PakettiArp_ShowDialog()
    end
    return nil
  end
  return my_keyhandler_func(dialog, key)
end

-- Update UI
function PakettiArp_UpdateUI()
  if not PakettiArp_vb then return end
  
  -- Update all canvas views for pattern visualization
  for i = 1, #PakettiArp_canvas_views do
    if PakettiArp_canvas_views[i] then
      PakettiArp_canvas_views[i]:update()
    end
  end
end

-- Create dialog
function PakettiArp_ShowDialog()
  if PakettiArp_dialog and PakettiArp_dialog.visible then
    PakettiArp_dialog:show()
    return
  end
  
  PakettiArp_vb = renoise.ViewBuilder()
  
  -- Ensure scale and patterns are generated
  PakettiArp_UpdateScale()
  PakettiArp_UpdatePatterns()
  
  -- Clickable CodePen Link
  local link_row = PakettiArp_vb:row{
    PakettiArp_vb:button{
      text = "Original by Jake Albaugh → https://codepen.io/jak_e/full/qNrZyw",
      width = 800,
      notifier = function()
        renoise.app():open_url("https://codepen.io/jak_e/full/qNrZyw")
      end
    }
  }
  
  -- BPM Section
  local bpm_row_content = {
    PakettiArp_vb:text{ text = "BPM:", width = 60, style = "strong", font = "bold" },
    PakettiArp_vb:button{
      text = "Current",
      width = 60,
      color = PakettiArp_use_current_bpm and {255, 187, 0} or nil,
      notifier = function()
        PakettiArp_use_current_bpm = true
        if PakettiArp_dialog and PakettiArp_dialog.visible then
          PakettiArp_dialog:close()
          PakettiArp_ShowDialog()
        end
      end
    }
  }
  
  local bpms = {45, 60, 75, 90, 105, 120, 135, 150}
  for i = 1, #bpms do
    local bpm_val = bpms[i]
    table.insert(bpm_row_content, PakettiArp_vb:button{
      text = tostring(bpm_val),
      width = 50,
      color = (not PakettiArp_use_current_bpm and bpm_val == PakettiArp_bpm) and {255, 187, 0} or nil,
      notifier = function()
        PakettiArp_use_current_bpm = false
        PakettiArp_bpm = bpm_val
        if PakettiArp_dialog and PakettiArp_dialog.visible then
          PakettiArp_dialog:close()
          PakettiArp_ShowDialog()
        end
      end
    })
  end
  
  local bpm_row = PakettiArp_vb:row(bpm_row_content)
  
  -- Key Section
  local key_row_content = {
    PakettiArp_vb:text{ text = "Key:", width = 60, style = "strong", font = "bold" }
  }
  
  for i = 1, #PakettiArp_keys do
    local key_val = PakettiArp_keys[i]
    table.insert(key_row_content, PakettiArp_vb:button{
      text = key_val,
      width = 35,
      color = (key_val == PakettiArp_key) and {255, 187, 0} or nil,
      notifier = function()
        PakettiArp_key = key_val
        PakettiArp_UpdateScale()
        if PakettiArp_dialog and PakettiArp_dialog.visible then
          PakettiArp_dialog:close()
          PakettiArp_ShowDialog()
        end
      end
    })
  end
  
  local key_row = PakettiArp_vb:row(key_row_content)
  
  -- Mode Section
  local mode_row_content = {
    PakettiArp_vb:text{ text = "Mode:", width = 60, style = "strong", font = "bold" }
  }
  
  for i = 1, #PakettiArp_modes do
    local mode_val = PakettiArp_modes[i]
    table.insert(mode_row_content, PakettiArp_vb:button{
      text = mode_val,
      width = 80,
      color = (mode_val == PakettiArp_mode) and {255, 187, 0} or nil,
      notifier = function()
        PakettiArp_mode = mode_val
        PakettiArp_UpdateScale()
        if PakettiArp_dialog and PakettiArp_dialog.visible then
          PakettiArp_dialog:close()
          PakettiArp_ShowDialog()
        end
      end
    })
  end
  
  local mode_row = PakettiArp_vb:row(mode_row_content)
  
  -- Steps Section
  local steps_row_content = {
    PakettiArp_vb:text{ text = "Steps:", width = 60, style = "strong", font = "bold" }
  }
  
  for steps = 3, 6 do
    local step_val = steps
    table.insert(steps_row_content, PakettiArp_vb:button{
      text = tostring(steps),
      width = 40,
      color = (steps == PakettiArp_steps) and {255, 187, 0} or nil,
      notifier = function()
        PakettiArp_steps = step_val
        PakettiArp_UpdatePatterns()
        if PakettiArp_dialog and PakettiArp_dialog.visible then
          PakettiArp_dialog:close()
          PakettiArp_ShowDialog()
        end
      end
    })
  end
  
  local steps_row = PakettiArp_vb:row(steps_row_content)
  
  -- Type Section
  local type_row = PakettiArp_vb:row{
    PakettiArp_vb:text{ text = "Type:", width = 60, style = "strong", font = "bold" },
    PakettiArp_vb:button{
      text = "Straight",
      width = 80,
      color = (PakettiArp_pattern_type == "straight") and {255, 187, 0} or nil,
      notifier = function()
        PakettiArp_pattern_type = "straight"
        PakettiArp_UpdatePatterns()
        if PakettiArp_dialog and PakettiArp_dialog.visible then
          PakettiArp_dialog:close()
          PakettiArp_ShowDialog()
        end
      end
    },
    PakettiArp_vb:button{
      text = "Looped",
      width = 80,
      color = (PakettiArp_pattern_type == "looped") and {255, 187, 0} or nil,
      notifier = function()
        PakettiArp_pattern_type = "looped"
        PakettiArp_UpdatePatterns()
        if PakettiArp_dialog and PakettiArp_dialog.visible then
          PakettiArp_dialog:close()
          PakettiArp_ShowDialog()
        end
      end
    }
  }
  
  -- Pattern Selection Section with Canvas
  local pattern_rows = {
    PakettiArp_vb:text{ text = "Arpeggio Patterns", style = "strong", font = "bold" }
  }
  
  PakettiArp_canvas_views = {}
  local patterns = PakettiArp_current_patterns[PakettiArp_pattern_type]
  local max_per_row = 10
  
  for i = 1, #patterns, max_per_row do
    local pattern_row_content = {}
    
    for j = i, math.min(i + max_per_row - 1, #patterns) do
      local pattern = patterns[j]
      local pattern_str = ""
      for p = 1, #pattern do
        pattern_str = pattern_str .. tostring(pattern[p])
      end
      
      local pattern_index = j
      
      local canvas = PakettiArp_vb:canvas{
        width = 70,
        height = 50,
        mode = "plain",
        render = function(context)
          local is_selected = (pattern_index == PakettiArp_pattern_id)
          PakettiArp_RenderPattern(context, pattern, is_selected)
        end,
        mouse_handler = function(event)
          if event.type == "down" then
            PakettiArp_pattern_id = pattern_index
            PakettiArp_current_arpeggio = patterns[pattern_index]
            if PakettiArp_dialog and PakettiArp_dialog.visible then
              PakettiArp_dialog:close()
              PakettiArp_ShowDialog()
            end
          end
        end,
        mouse_events = {"down"}
      }
      
      table.insert(PakettiArp_canvas_views, canvas)
      
      local pattern_col = PakettiArp_vb:column{
        spacing = 1,
        PakettiArp_vb:button{
          text = pattern_str,
          width = 70,
          height = 18,
          notifier = function()
            PakettiArp_pattern_id = pattern_index
            PakettiArp_current_arpeggio = patterns[pattern_index]
            if PakettiArp_dialog and PakettiArp_dialog.visible then
              PakettiArp_dialog:close()
              PakettiArp_ShowDialog()
            end
          end
        },
        canvas
      }
      
      table.insert(pattern_row_content, pattern_col)
    end
    
    table.insert(pattern_rows, PakettiArp_vb:row{ spacing = 2, unpack(pattern_row_content) })
  end
  
  local pattern_column = PakettiArp_vb:column{
    style = "group",
    margin = 4,
    unpack(pattern_rows)
  }
  
  -- Chord Progression Section - Horizontal columns like PakettiChords
  local chord_prog_columns = {}
  
  -- Create 8 columns (one for each chord position)
  for c = 1, #PakettiArp_chord_progression do
    local chord_index = c
    local column_content = {
      PakettiArp_vb:text{ text = tostring(c) .. ":", width = 70, style = "strong", font = "bold", align = "center" }
    }
    
    -- Add 7 degree buttons vertically in this column
    for degree = 1, 7 do
      local degree_val = degree
      local is_selected = (PakettiArp_chord_progression[c] == degree)
      local is_auditioning = (PakettiArp_audition_playing and PakettiArp_audition_chord_idx == c and is_selected)
      
      table.insert(column_content, PakettiArp_vb:button{
        text = tostring(degree),
        width = 70,
        height = 25,
        color = is_auditioning and PakettiArp_highlight_color or (is_selected and {255, 187, 0} or nil),
        notifier = function()
          PakettiArp_chord_progression[chord_index] = degree_val
          if PakettiArp_dialog and PakettiArp_dialog.visible then
            PakettiArp_dialog:close()
            PakettiArp_ShowDialog()
          end
        end
      })
    end
    
    -- Wrap column in a group
    table.insert(chord_prog_columns, PakettiArp_vb:column{
      style = "group",
      margin = 2,
      unpack(column_content)
    })
  end
  
  -- Chord progression row containing all 8 columns
  local chord_prog_row = PakettiArp_vb:row(chord_prog_columns)
  
  -- Action buttons
  local audition_text = "Audition (Space)"
  if PakettiArp_audition_playing then
    audition_text = "Audition Chord " .. tostring(PakettiArp_audition_chord_idx) .. "/" .. tostring(#PakettiArp_chord_progression) .. " (Space for next)"
  end
  
  local action_row = PakettiArp_vb:row{
    PakettiArp_vb:button{
      text = audition_text,
      width = 300,
      notifier = PakettiArp_ToggleAudition
    },
    PakettiArp_vb:button{
      text = "Write to Pattern",
      width = 120,
      notifier = PakettiArp_WriteToPattern
    },
    PakettiArp_vb:button{
      text = "Close",
      width = 60,
      notifier = function()
        PakettiArp_StopAudition()
        if PakettiArp_dialog and PakettiArp_dialog.visible then
          PakettiArp_dialog:close()
        end
      end
    }
  }
  
  -- Create Output display
  local output_rows = {
    PakettiArp_vb:text{ text = "Output", style = "strong", font = "bold" },
    PakettiArp_vb:text{ text = PakettiArp_key .. " " .. PakettiArp_scale_data[PakettiArp_ModeToKey(PakettiArp_mode)].name, style = "normal" }
  }
  
  -- Add chord output info
  for i = 1, #PakettiArp_chord_progression do
    local chord_idx = PakettiArp_chord_progression[i]
    if chord_idx > 0 and chord_idx <= #PakettiArp_scale_notes then
      local note = PakettiArp_scale_notes[chord_idx]
      table.insert(output_rows, PakettiArp_vb:text{
        text = note.note .. " " .. note.triad.type:upper(),
        width = 100,
        style = "normal"
      })
    end
  end
  
  local output_column = PakettiArp_vb:column{
    style = "group",
    margin = 4,
    width = 120,
    unpack(output_rows)
  }
  
  -- Main content with better layout
  local content = PakettiArp_vb:column{
    margin = 8,
    link_row,
    PakettiArp_vb:space{ height = 8 },
    -- Chord Progression + Output
    PakettiArp_vb:column{
      style = "group",
      margin = 4,
      PakettiArp_vb:text{ text = "Chord Progression", style = "strong", font = "bold" },
      chord_prog_row
    },
    PakettiArp_vb:space{ height = 8 },
    output_column,
    PakettiArp_vb:space{ height = 8 },
    -- Tonic/Root and Mode side by side
    PakettiArp_vb:row{
      PakettiArp_vb:column{
        style = "group",
        margin = 4,
        PakettiArp_vb:text{ text = "Tonic / Root", style = "strong", font = "bold" },
        key_row
      },
      PakettiArp_vb:space{ width = 8 },
      PakettiArp_vb:column{
        style = "group",
        margin = 4,
        PakettiArp_vb:text{ text = "Mode", style = "strong", font = "bold" },
        mode_row
      }
    },
    PakettiArp_vb:space{ height = 8 },
    -- Arpeggio Steps and Type side by side
    PakettiArp_vb:row{
      PakettiArp_vb:column{
        style = "group",
        margin = 4,
        PakettiArp_vb:text{ text = "Arpeggio Steps", style = "strong", font = "bold" },
        steps_row
      },
      PakettiArp_vb:space{ width = 8 },
      PakettiArp_vb:column{
        style = "group",
        margin = 4,
        PakettiArp_vb:text{ text = "Arpeggio Type", style = "strong", font = "bold" },
        type_row
      }
    },
    PakettiArp_vb:space{ height = 8 },
    -- BPM
    PakettiArp_vb:column{
      style = "group",
      margin = 4,
      PakettiArp_vb:text{ text = "Beats Per Minute", style = "strong", font = "bold" },
      bpm_row
    },
    PakettiArp_vb:space{ height = 8 },
    -- Pattern grid
    pattern_column,
    PakettiArp_vb:space{ height = 8 },
    -- Action buttons
    action_row
  }
  
  PakettiArp_dialog = renoise.app():show_custom_dialog("Paketti Arpeggiator", content, PakettiArp_KeyHandler)
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Toggle dialog
function PakettiArp_Toggle()
  if PakettiArp_dialog and PakettiArp_dialog.visible then
    PakettiArp_StopAudition()
    PakettiArp_dialog:close()
    PakettiArp_dialog = nil
  else
    PakettiArp_ShowDialog()
  end
end

renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti Gadgets:Musical Chord Progression Arpeggiator...",invoke = PakettiArp_Toggle}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti Gadgets:Musical Chord Progression Arpeggiator...",invoke = PakettiArp_Toggle}
renoise.tool():add_keybinding{name = "Global:Paketti:Musical Chord Progression Arpeggiator...",invoke = PakettiArp_Toggle}

-- Add MIDI mapping
renoise.tool():add_midi_mapping{name="Paketti:Musical Chord Progression Arpeggiator...",invoke = PakettiArp_Toggle}

