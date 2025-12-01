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
PakettiArp_modes_per_chord = {"ionian", "ionian", "ionian", "ionian", "ionian", "ionian", "ionian", "ionian"}
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
PakettiArp_chord_buttons = {} -- Array of arrays: chord_buttons[chord_position][degree]
PakettiArp_highlight_timer = nil

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

-- Roman numerals for degrees
PakettiArp_roman_numerals = {"I", "II", "III", "IV", "V", "VI", "VII"}

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

-- Audition/Playback state
PakettiArp_audition_playing = false
PakettiArp_audition_notes = {}
PakettiArp_audition_chord_idx = 1
PakettiArp_highlight_color = {40, 0, 72}  -- Deep purple from PakettiEightOneTwenty
PakettiArp_playback_timer = nil
PakettiArp_continuous_playing = false
PakettiArp_arp_step = 0
PakettiArp_bass_note = nil
PakettiArp_note_timers = {}
PakettiArp_read_from_track = nil -- Track to read from (nil = current track)

-- Stop all playback
function PakettiArp_StopAudition()
  -- Stop all timers
  if PakettiArp_playback_timer and renoise.tool():has_timer(PakettiArp_playback_timer) then
    renoise.tool():remove_timer(PakettiArp_playback_timer)
  end
  PakettiArp_playback_timer = nil
  
  for _, timer in ipairs(PakettiArp_note_timers) do
    if timer and renoise.tool():has_timer(timer) then
      renoise.tool():remove_timer(timer)
    end
  end
  PakettiArp_note_timers = {}
  
  -- Stop all notes safely
  local song = renoise.song()
  local track_idx = song.selected_track_index
  local inst_idx = song.selected_instrument_index
  
  if #PakettiArp_audition_notes > 0 then
    local unique_notes = PakettiArp_UniquifyNotes(PakettiArp_audition_notes)
    if #unique_notes > 0 then
      pcall(function() song:trigger_instrument_note_off(inst_idx, track_idx, unique_notes) end)
    end
  end
  
  -- Stop bass note
  if PakettiArp_bass_note then
    pcall(function() song:trigger_instrument_note_off(inst_idx, track_idx, {PakettiArp_bass_note}) end)
    PakettiArp_bass_note = nil
  end
  
  PakettiArp_audition_playing = false
  PakettiArp_continuous_playing = false
  PakettiArp_audition_notes = {}
  PakettiArp_audition_chord_idx = 1
  PakettiArp_arp_step = 0
end

-- Build note list for chord
function PakettiArp_GetChordNotes(chord_position)
  -- Generate scale for this specific chord position using its per-chord mode
  local mode_for_chord = PakettiArp_modes_per_chord[chord_position]
  local scale_for_chord = PakettiArp_GenerateScale(PakettiArp_key, mode_for_chord)
  
  if #scale_for_chord == 0 then
    return nil, nil
  end
  
  local chord_idx = PakettiArp_chord_progression[chord_position]
  if chord_idx <= 0 or chord_idx > #scale_for_chord then
    return nil, nil
  end
  
  local chord = scale_for_chord[chord_idx]
  
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
  
  -- Bass note (root, one octave lower)
  local bass_note = PakettiArp_NoteToMidi(chord.triad.notes[1].note, chord.triad.notes[1].rel_octave + PakettiArp_octave_base - 1)
  
  return notes, bass_note
end

-- Play one arpeggio note
function PakettiArp_PlayArpNote()
  if not PakettiArp_continuous_playing then return end
  
  local song = renoise.song()
  local track_idx = song.selected_track_index
  local inst_idx = song.selected_instrument_index
  
  if #PakettiArp_current_arpeggio == 0 then
    PakettiArp_UpdatePatterns()
  end
  
  -- Calculate timing based on BPM and LPB
  local bpm = PakettiArp_use_current_bpm and song.transport.bpm or PakettiArp_bpm
  local lpb = song.transport.lpb
  local beat_ms = 60000 / bpm
  local line_ms = beat_ms / lpb
  
  -- Each arpeggio step takes a fraction of one line
  local arp_length = math.min(16, #PakettiArp_current_arpeggio)
  local step_ms = line_ms / arp_length
  local note_duration = step_ms * 0.8 -- Note lasts 80% of the interval
  
  -- Get notes for current chord
  local notes, bass_note = PakettiArp_GetChordNotes(PakettiArp_audition_chord_idx)
  if not notes then return end
  
  -- Cap arpeggio length to first 16 steps
  local arp_step_capped = (PakettiArp_arp_step % math.min(16, #PakettiArp_current_arpeggio))
  local arp_idx = PakettiArp_current_arpeggio[arp_step_capped + 1] + 1
  
  if arp_idx <= #notes then
    local note = notes[arp_idx]
    local midi_note = PakettiArp_NoteToMidi(note.note, note.rel_octave + PakettiArp_octave_base)
    
    -- Stop previous arp note safely
    if #PakettiArp_audition_notes > 0 then
      pcall(function() song:trigger_instrument_note_off(inst_idx, track_idx, PakettiArp_audition_notes) end)
      PakettiArp_audition_notes = {}
    end
    
    -- Play new note
    song:trigger_instrument_note_on(inst_idx, track_idx, {midi_note}, 1.0)
    PakettiArp_audition_notes = {midi_note}
    
    -- Schedule note-off for this note (so it doesn't ring forever)
    
    -- Schedule one-shot note-off (timer will auto-remove after firing once)
    renoise.tool():add_timer(function()
      pcall(function() 
        if PakettiArp_continuous_playing then
          song:trigger_instrument_note_off(inst_idx, track_idx, {midi_note})
        end
      end)
    end, note_duration)
    
    -- Handle bass note (sustain for entire chord)
    if PakettiArp_arp_step == 0 then
      -- Stop previous bass safely
      if PakettiArp_bass_note then
        pcall(function() song:trigger_instrument_note_off(inst_idx, track_idx, {PakettiArp_bass_note}) end)
      end
      -- Start new bass (avoid duplicate if same as arp note)
      if bass_note ~= midi_note then
        PakettiArp_bass_note = bass_note
        song:trigger_instrument_note_on(inst_idx, track_idx, {bass_note}, 0.8)
      else
        PakettiArp_bass_note = nil
      end
      
      -- Don't rebuild dialog during playback - it's too expensive
    end
  end
  
  -- Move to next step
  PakettiArp_arp_step = PakettiArp_arp_step + 1
  
  -- If we've finished the pattern, move to next chord (using capped length)
  local arp_length = math.min(16, #PakettiArp_current_arpeggio)
  if PakettiArp_arp_step >= arp_length then
    PakettiArp_arp_step = 0
    PakettiArp_audition_chord_idx = PakettiArp_audition_chord_idx + 1
    if PakettiArp_audition_chord_idx > #PakettiArp_chord_progression then
      PakettiArp_audition_chord_idx = 1
    end
    -- Don't rebuild during continuous playback - too expensive/distracting
  end
  
end

-- Start continuous playback
function PakettiArp_Play()
  if PakettiArp_continuous_playing then
    PakettiArp_StopAudition()
    -- Update colors without rebuilding
    PakettiArp_UpdateChordButtonColors()
    return
  end
  
  PakettiArp_StopAudition()
  PakettiArp_continuous_playing = true
  PakettiArp_audition_playing = true
  PakettiArp_audition_chord_idx = 1
  PakettiArp_arp_step = 0
  
  -- Create a single repeating timer
  local song = renoise.song()
  local bpm = PakettiArp_use_current_bpm and song.transport.bpm or PakettiArp_bpm
  local lpb = song.transport.lpb
  local beat_ms = 60000 / bpm
  local line_ms = beat_ms / lpb
  
  -- Each arpeggio step takes a fraction of one line
  local arp_length = math.min(16, #PakettiArp_current_arpeggio)
  if arp_length == 0 then
    PakettiArp_UpdatePatterns()
    arp_length = math.min(16, #PakettiArp_current_arpeggio)
  end
  local interval_ms = line_ms / arp_length
  
  PakettiArp_playback_timer = function()
    if not PakettiArp_continuous_playing then return end
    PakettiArp_PlayArpNote()
  end
  
  -- Play first note immediately
  PakettiArp_PlayArpNote()
  
  -- Add repeating timer
  renoise.tool():add_timer(PakettiArp_playback_timer, interval_ms)
  
  -- Show timing info
  print(string.format("PakettiArp: Playing at %d BPM, %d LPB (%.1fms per step)", 
    math.floor(bpm), lpb, interval_ms))
end

-- Remove duplicates from note array
function PakettiArp_UniquifyNotes(note_array)
  local seen = {}
  local unique = {}
  for _, note in ipairs(note_array) do
    if not seen[note] then
      seen[note] = true
      table.insert(unique, note)
    end
  end
  return unique
end

-- Preview one chord with arpeggio (for Space key and clicking chord buttons)
function PakettiArp_NextChord()
  local was_playing = PakettiArp_audition_playing and not PakettiArp_continuous_playing
  
  -- Stop continuous playback if running
  if PakettiArp_continuous_playing then
    PakettiArp_StopAudition()
  end
  
  local song = renoise.song()
  local track_idx = song.selected_track_index
  local inst_idx = song.selected_instrument_index
  
  if #PakettiArp_current_arpeggio == 0 then
    PakettiArp_UpdatePatterns()
  end
  
  -- Advance chord position
  if was_playing then
    PakettiArp_audition_chord_idx = PakettiArp_audition_chord_idx + 1
    if PakettiArp_audition_chord_idx > #PakettiArp_chord_progression then
      PakettiArp_audition_chord_idx = 1
    end
  else
    PakettiArp_audition_chord_idx = 1
  end
  
  PakettiArp_audition_playing = true
  
  -- Stop previous notes (safely)
  if #PakettiArp_audition_notes > 0 then
    local unique_notes = PakettiArp_UniquifyNotes(PakettiArp_audition_notes)
    if #unique_notes > 0 then
      pcall(function() song:trigger_instrument_note_off(inst_idx, track_idx, unique_notes) end)
    end
    PakettiArp_audition_notes = {}
  end
  if PakettiArp_bass_note then
    pcall(function() song:trigger_instrument_note_off(inst_idx, track_idx, {PakettiArp_bass_note}) end)
    PakettiArp_bass_note = nil
  end
  
  -- Get notes for chord
  local notes, bass_note = PakettiArp_GetChordNotes(PakettiArp_audition_chord_idx)
  if notes then
    -- Play bass
    PakettiArp_bass_note = bass_note
    song:trigger_instrument_note_on(inst_idx, track_idx, {bass_note}, 0.8)
    
    -- Build unique arpeggio notes
    local temp_notes = {}
    for a = 1, math.min(#PakettiArp_current_arpeggio, #notes) do
      local arp_idx = PakettiArp_current_arpeggio[a] + 1
      if arp_idx <= #notes then
        local note = notes[arp_idx]
        local midi_note = PakettiArp_NoteToMidi(note.note, note.rel_octave + PakettiArp_octave_base)
        table.insert(temp_notes, midi_note)
      end
    end
    
    -- Remove duplicates
    PakettiArp_audition_notes = PakettiArp_UniquifyNotes(temp_notes)
    
    -- Start arpeggio playback (one note at a time)
    if #PakettiArp_audition_notes > 0 then
      local bpm = PakettiArp_use_current_bpm and song.transport.bpm or PakettiArp_bpm
      local lpb = song.transport.lpb
      local beat_ms = 60000 / bpm
      local line_ms = beat_ms / lpb
      
      -- Each arpeggio step takes a fraction of one line
      local arp_length = math.min(16, #PakettiArp_current_arpeggio)
      local note_duration = line_ms / arp_length
      
      -- Play each note sequentially
      for i, midi_note in ipairs(PakettiArp_audition_notes) do
        local delay_ms = (i - 1) * note_duration
        local timer_id = nil
        
        -- Note ON timer
        timer_id = function()
          song:trigger_instrument_note_on(inst_idx, track_idx, {midi_note}, 1.0)
          
          -- Schedule note OFF
          local off_timer = function()
            pcall(function() song:trigger_instrument_note_off(inst_idx, track_idx, {midi_note}) end)
          end
          renoise.tool():add_timer(off_timer, note_duration * 0.8)
          table.insert(PakettiArp_note_timers, off_timer)
        end
        
        if delay_ms > 0 then
          renoise.tool():add_timer(timer_id, delay_ms)
          table.insert(PakettiArp_note_timers, timer_id)
        else
          timer_id()
        end
      end
      
      -- Schedule cleanup after all notes finish
      local total_duration = (#PakettiArp_audition_notes) * note_duration
      local cleanup_timer = function()
        -- Stop bass note
        if PakettiArp_bass_note then
          pcall(function() song:trigger_instrument_note_off(inst_idx, track_idx, {PakettiArp_bass_note}) end)
          PakettiArp_bass_note = nil
        end
        
        -- Clear audition state
        PakettiArp_audition_playing = false
        PakettiArp_audition_notes = {}
        
        -- Update button colors without rebuilding
        PakettiArp_UpdateChordButtonColors()
      end
      renoise.tool():add_timer(cleanup_timer, total_duration + 100)
      table.insert(PakettiArp_note_timers, cleanup_timer)
    end
  end
end


-- Calculate chord notes for pattern matching
function PakettiArp_CalculateChordNotes(root_offset, degree, octave)
  -- Get scale using existing function
  local root_note = PakettiArp_keys[(root_offset % 12) + 1]
  local scale_data = PakettiArp_GenerateScale(root_note, PakettiArp_mode)
  
  if degree < 1 or degree > #scale_data then
    return {}
  end
  
  local chord = scale_data[degree]
  local notes = {}
  
  for i = 1, #chord.triad.notes do
    local note_data = chord.triad.notes[i]
    local midi_note = PakettiArp_NoteToMidi(note_data.note, note_data.rel_octave + octave)
    table.insert(notes, midi_note)
  end
  
  return notes
end


-- Read chord progression from pattern
function PakettiArp_ReadFromPattern()
  local song = renoise.song()
  
  -- Determine which track to read from
  local track_idx = PakettiArp_read_from_track or song.selected_track_index
  
  -- Validate track
  if track_idx < 1 or track_idx > #song.tracks then
    renoise.app():show_status("PakettiArp: Invalid track number")
    return
  end
  
  local track = song:track(track_idx)
  
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("PakettiArp: Not a sequencer track")
    return
  end
  
  local patt = song:pattern(song.selected_pattern_index)
  local ptrack = patt:track(track_idx)
  
  -- Clear current progression
  for i = 1, #PakettiArp_chord_progression do
    PakettiArp_chord_progression[i] = 1
  end
  
  -- Collect all unique notes and chord positions
  local all_notes = {}
  local chord_data = {}
  
  print("=== Scanning Pattern Lines ===")
  print("Track: " .. track_idx .. ", Pattern: " .. song.selected_pattern_index)
  print("Lines to scan: " .. patt.number_of_lines)
  print("Visible note columns: " .. track.visible_note_columns)
  print("")
  
  for line_idx = 1, patt.number_of_lines do
    local line = ptrack:line(line_idx)
    local notes_in_line = {}
    
    -- Collect notes from this line
    for col_idx = 1, math.min(12, track.visible_note_columns) do
      local ncol = line:note_column(col_idx)
      if not ncol.is_empty and ncol.note_string ~= "OFF" and ncol.note_string ~= "" then
        print("Line " .. line_idx .. " col " .. col_idx .. ": " .. ncol.note_string)
        local note_val = PakettiArp_NoteStringToValue(ncol.note_string)
        if note_val then
          local note_class = note_val % 12
          table.insert(notes_in_line, note_class)
          all_notes[note_class] = (all_notes[note_class] or 0) + 1
        end
      end
    end
    
    if #notes_in_line >= 2 then
      table.insert(chord_data, notes_in_line)
      print("  → Found chord at line " .. line_idx .. " with " .. #notes_in_line .. " notes")
    end
  end
  
  print("")
  print("Total chords found: " .. #chord_data)
  print("==============================")
  print("")
  
  -- Detect key AND mode together by maximizing scale-note matches
  local best_key_idx = 1
  local best_mode_name = "ionian"
  local best_score = -1000000
  
  for key_idx = 1, #PakettiArp_keys do
    local key_name = PakettiArp_keys[key_idx]
    
    for mode_idx = 1, #PakettiArp_modes do
      local mode_name = PakettiArp_modes[mode_idx]
      local scale_data = PakettiArp_GenerateScale(key_name, mode_name)
      
      -- Build a set of pitch classes that belong to this scale
      local scale_classes = {}
      for _, scale_note in ipairs(scale_data) do
        local first_note = scale_note.triad.notes[1]
        local midi_val = PakettiArp_NoteToMidi(first_note.note, first_note.rel_octave)
        scale_classes[midi_val % 12] = true
      end
      
      local mode_score = 0
      for note_class, count in pairs(all_notes) do
        if scale_classes[note_class] then
          mode_score = mode_score + count
        end
      end
      
      if mode_score > best_score then
        best_score = mode_score
        best_key_idx = key_idx
        best_mode_name = mode_name  -- e.g. "aeolian", "ionian", "dorian", ...
      end
    end
  end
  
  -- Store detected key & mode (mode is now one of PakettiArp_modes, lowercase)
  PakettiArp_key = PakettiArp_keys[best_key_idx]
  PakettiArp_mode = best_mode_name
  
  -- Set all per-chord modes to the detected mode
  for i = 1, 8 do
    PakettiArp_modes_per_chord[i] = best_mode_name
  end
  
  -- Update scale with new key/mode
  PakettiArp_UpdateScale()
  
  -- Now match chords to degrees with the detected key/mode
  local chord_found = 0
  local debug_info = {}
  
  print("=== PakettiArp Read from Pattern DEBUG ===")
  local mode_pretty = PakettiArp_scale_data[PakettiArp_ModeToKey(PakettiArp_mode)].name
  print("Detected Key: " .. PakettiArp_key .. " " .. mode_pretty)
  print("Found " .. #chord_data .. " chord positions")
  print("")
  
  -- Get the scale for reference
  local scale_data = PakettiArp_GenerateScale(PakettiArp_key, PakettiArp_mode)
  
  -- Precompute scale pitch classes for this key/mode
  local scale_pitch_classes = {}
  for _, scale_note in ipairs(scale_data) do
    local first_note = scale_note.triad.notes[1]
    local midi_val = PakettiArp_NoteToMidi(first_note.note, first_note.rel_octave)
    scale_pitch_classes[midi_val % 12] = true
  end
  
  for line_idx, notes_in_line in ipairs(chord_data) do
    if chord_found >= 8 then break end
    chord_found = chord_found + 1
    
    -- Convert note classes to note names for display
    local note_names_found = {}
    for _, note_class in ipairs(notes_in_line) do
      table.insert(note_names_found, PakettiArp_keys[(note_class % 12) + 1])
    end
    
    print("Position " .. chord_found .. " notes: " .. table.concat(note_names_found, ", "))
    
    -- Use the lowest note (first in the collected line) as a *hint*,
    -- but don't let it completely dominate (slash chords etc.)
    local bass_note_class = notes_in_line[1]
    
    local best_match = 1
    local best_score = -1000000
    
    for degree = 1, #scale_data do
      local scale_note = scale_data[degree]
      local root_note = scale_note.triad.notes[1]
      local root_midi = PakettiArp_NoteToMidi(root_note.note, root_note.rel_octave)
      local root_class = root_midi % 12
      
      -- Triad pitch classes for this degree (root, 3rd, 5th)
      local triad_classes = {}
      for _, n in ipairs(scale_note.triad.notes) do
        local midi_val = PakettiArp_NoteToMidi(n.note, n.rel_octave)
        triad_classes[midi_val % 12] = true
      end
      
      local score = 0
      
      -- Tiny nudge if bass matches this root (slash chords shouldn't flip function)
      if bass_note_class == root_class then
        score = score + 1
      end
      
      -- Root appears anywhere in the chord?
      for _, note_class in ipairs(notes_in_line) do
        if note_class == root_class then
          score = score + 1
          break
        end
      end
      
      -- Score each chord tone:
      --  - triad tone: strong
      --  - diatonic but not triad: weak positive (extension)
      --  - out of scale: penalty
      for _, note_class in ipairs(notes_in_line) do
        if triad_classes[note_class] then
          score = score + 3
        elseif scale_pitch_classes[note_class] then
          score = score + 1
        else
          score = score - 2
        end
      end

      -- Slight global bias towards the tonic when scores are close
      if degree == 1 then
        score = score + 1
      end
      
      if score > 0 then
        print(string.format("  - Degree %d (%s %s) score: %d",
          degree, scale_note.note, scale_note.triad.type, score))
      end
      
      if score > best_score then
        best_score = score
        best_match = degree
      end
    end
    
    local matched_chord = scale_data[best_match]
    print(string.format("  → Matched to degree %d (%s %s, score: %d)",
      best_match, matched_chord.note, matched_chord.triad.type, best_score))
    print("")
    
    if chord_found <= #PakettiArp_chord_progression then
      PakettiArp_chord_progression[chord_found] = best_match
      table.insert(debug_info, PakettiArp_roman_numerals[best_match] .. "=" .. matched_chord.note)
    end
  end
  
  -- Convert progression to Roman numerals for display
  local roman_progression = {}
  for _, degree in ipairs(PakettiArp_chord_progression) do
    table.insert(roman_progression, PakettiArp_roman_numerals[degree])
  end
  print("Final progression: " .. table.concat(roman_progression, ", "))
  print("==========================================")
  print("")
  
  local track_name = song:track(track_idx).name
  if track_name == "" then track_name = "Track " .. track_idx end
  local mode_pretty = PakettiArp_scale_data[PakettiArp_ModeToKey(PakettiArp_mode)].name
  renoise.app():show_status(
    "PakettiArp: Read " .. tostring(chord_found) ..
    " chords from " .. track_name ..
    " - " .. PakettiArp_key .. " " .. mode_pretty ..
    " [" .. table.concat(debug_info, " ") .. "]"
  )
end

-- Helper: Convert note string to MIDI value
function PakettiArp_NoteStringToValue(note_string)
  if not note_string or note_string == "" or note_string == "OFF" then return nil end
  
  local note_names = {C=0, D=2, E=4, F=5, G=7, A=9, B=11}
  local octave = tonumber(string.sub(note_string, -1))
  local note_name = string.sub(note_string, 1, 1)
  local sharp = string.find(note_string, "#") ~= nil
  
  if not octave or not note_names[note_name] then return nil end
  
  local value = octave * 12 + note_names[note_name]
  if sharp then value = value + 1 end
  
  return value
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
  
  -- Cap arpeggio length to reasonable size
  local arp_length = math.min(#PakettiArp_current_arpeggio, 16)
  
  -- Calculate lines needed: 1 line per chord + 1 line for note-offs
  local lines_per_chord = 2
  local total_lines = lines_per_chord * #PakettiArp_chord_progression
  
  if start_line + total_lines - 1 > patt.number_of_lines then
    renoise.app():show_status(string.format("PakettiArp: Need %d lines, only %d available from line %d", total_lines, patt.number_of_lines - start_line + 1, start_line))
    return
  end
  
  -- Ensure enough visible note columns for the arpeggio
  local needed_columns = math.min(arp_length, 12) -- Renoise max is 12
  if track.visible_note_columns < needed_columns then
    track.visible_note_columns = needed_columns
  end
  
  -- Enable delay column
  track.delay_column_visible = true
  
  -- Calculate delay increments (256 ticks per line in Renoise)
  local delay_per_step = math.floor(256 / arp_length)
  
  print(string.format("PakettiArp: Writing with %d note columns, delay increment = %d ticks", 
    needed_columns, delay_per_step))
  
  local line_idx = start_line
  
  for c = 1, #PakettiArp_chord_progression do
    local chord_idx = PakettiArp_chord_progression[c]
    
    -- Generate scale for this chord position using its per-chord mode
    local mode_for_chord = PakettiArp_modes_per_chord[c]
    local scale_for_chord = PakettiArp_GenerateScale(PakettiArp_key, mode_for_chord)
    
    if chord_idx > 0 and chord_idx <= #scale_for_chord then
      local chord = scale_for_chord[chord_idx]
      
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
      
      -- Write arpeggio notes across multiple columns with delay values
      if line_idx <= patt.number_of_lines then
        local line = ptrack:line(line_idx)
        
        for a = 1, math.min(arp_length, needed_columns) do
          local arp_idx = PakettiArp_current_arpeggio[a] + 1
          if arp_idx <= #notes then
            local note = notes[arp_idx]
            local midi_note = PakettiArp_NoteToMidi(note.note, note.rel_octave + PakettiArp_octave_base)
            
            local ncol = line:note_column(a)
            ncol.note_value = midi_note
            ncol.instrument_value = song.selected_instrument_index - 1
            ncol.delay_value = (a - 1) * delay_per_step
          end
        end
        
        line_idx = line_idx + 1
      end
      
      -- Write note-offs on next line
      if line_idx <= patt.number_of_lines then
        local line = ptrack:line(line_idx)
        
        for a = 1, math.min(arp_length, needed_columns) do
          local arp_idx = PakettiArp_current_arpeggio[a] + 1
          if arp_idx <= #notes then
            local ncol = line:note_column(a)
            ncol.note_value = 120 -- Note-OFF
            ncol.delay_value = (a - 1) * delay_per_step
          end
        end
        
        line_idx = line_idx + 1
      end
    end
  end
  
  renoise.app():show_status(string.format("PakettiArp: Written %d chords (%d lines) to pattern", #PakettiArp_chord_progression, line_idx - start_line))
end

-- Key handler
function PakettiArp_KeyHandler(dialog, key)
  if key and key.name == "esc" then
    local was_playing = PakettiArp_continuous_playing or PakettiArp_audition_playing
    PakettiArp_StopAudition()
    if was_playing and PakettiArp_dialog and PakettiArp_dialog.visible then
      -- Rebuild to clear highlighting and update UI
      PakettiArp_dialog:close()
      PakettiArp_ShowDialog()
    elseif PakettiArp_dialog and PakettiArp_dialog.visible then
      PakettiArp_dialog:close()
    end
    return nil
  elseif key and key.name == "space" then
    PakettiArp_NextChord()
    return nil
  elseif key and key.modifiers == "shift" and key.name == "space" then
    PakettiArp_Play()
    return nil
  end
  return my_keyhandler_func(dialog, key)
end

-- Update UI state without rebuilding (for playback)
function PakettiArp_UpdateUIState()
  -- This would update button colors if ViewBuilder supported it
  -- For now, just a placeholder for future enhancements
end

-- Update UI (full rebuild)
function PakettiArp_UpdateUI()
  if not PakettiArp_vb then return end
  
  -- Update all canvas views for pattern visualization
  for i = 1, #PakettiArp_canvas_views do
    if PakettiArp_canvas_views[i] then
      PakettiArp_canvas_views[i]:update()
    end
  end
end

-- Update chord button colors without rebuilding dialog
function PakettiArp_UpdateChordButtonColors()
  if not PakettiArp_chord_buttons or #PakettiArp_chord_buttons == 0 then return end
  
  for chord_pos = 1, #PakettiArp_chord_buttons do
    local button_array = PakettiArp_chord_buttons[chord_pos]
    if button_array then
      for degree = 1, #button_array do
        local btn = button_array[degree]
        if btn then
          local is_selected = (PakettiArp_chord_progression[chord_pos] == degree)
          local is_playing = (PakettiArp_audition_playing and PakettiArp_audition_chord_idx == chord_pos and is_selected)
          
          if is_playing then
            btn.color = PakettiArp_highlight_color
          elseif is_selected then
            btn.color = {255, 187, 0} -- Orange for selected
          else
            btn.color = {64, 64, 64} -- Default grey
          end
        end
      end
    end
  end
end

-- Start highlight timer
function PakettiArp_StartHighlightTimer()
  if not PakettiArp_highlight_timer then
    PakettiArp_highlight_timer = function()
      PakettiArp_UpdateChordButtonColors()
    end
    renoise.tool():add_timer(PakettiArp_highlight_timer, 40) -- 25fps like PakettiGater
  end
end

-- Stop highlight timer
function PakettiArp_StopHighlightTimer()
  if PakettiArp_highlight_timer and renoise.tool():has_timer(PakettiArp_highlight_timer) then
    renoise.tool():remove_timer(PakettiArp_highlight_timer)
  end
  PakettiArp_highlight_timer = nil
end

-- Cleanup function when dialog closes
function PakettiArp_CleanupOnClose()
  -- Stop all playback
  PakettiArp_StopAudition()
  
  -- Stop highlight timer
  PakettiArp_StopHighlightTimer()
  
  -- Clear dialog reference
  PakettiArp_dialog = nil
  PakettiArp_vb = nil
  PakettiArp_chord_buttons = {}
end

-- Create dialog
function PakettiArp_ShowDialog()
  if PakettiArp_dialog and PakettiArp_dialog.visible then
    PakettiArp_dialog:show()
    return
  end
  
  -- Initialize read track to current track if not set
  if not PakettiArp_read_from_track then
    PakettiArp_read_from_track = renoise.song().selected_track_index
  end
  
  PakettiArp_vb = renoise.ViewBuilder()
  PakettiArp_chord_buttons = {} -- Clear button references
  
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
        -- Don't rebuild - too expensive
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
        -- Don't rebuild - too expensive
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
  
  -- Mode Section (as dropdown)
  local mode_index = 1
  for i = 1, #PakettiArp_modes do
    if PakettiArp_modes[i] == PakettiArp_mode then
      mode_index = i
      break
    end
  end
  
  local mode_row = PakettiArp_vb:row{
    PakettiArp_vb:text{ text = "Mode (Set All):", width = 100, style = "strong", font = "bold" },
    PakettiArp_vb:popup{
      items = PakettiArp_modes,
      value = mode_index,
      width = 120,
      notifier = function(value)
        PakettiArp_mode = PakettiArp_modes[value]
        -- Set all per-chord modes to this mode
        for i = 1, 8 do
          PakettiArp_modes_per_chord[i] = PakettiArp_modes[value]
        end
        PakettiArp_UpdateScale()
        if PakettiArp_dialog and PakettiArp_dialog.visible then
          PakettiArp_dialog:close()
          PakettiArp_ShowDialog()
        end
      end
    }
  }
  
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
  local max_per_row = 15
  
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
        width = 60,
        height = 40,
        mode = "plain",
        render = function(context)
          local is_selected = (pattern_index == PakettiArp_pattern_id)
          PakettiArp_RenderPattern(context, pattern, is_selected)
        end,
        mouse_handler = function(event)
          if event.type == "down" then
            PakettiArp_pattern_id = pattern_index
            PakettiArp_current_arpeggio = patterns[pattern_index]
            -- Don't rebuild - too expensive
          end
        end,
        mouse_events = {"down"}
      }
      
      table.insert(PakettiArp_canvas_views, canvas)
      
      local pattern_col = PakettiArp_vb:column{
        spacing = 1,
        PakettiArp_vb:button{
          text = pattern_str,
          width = 60,
          height = 16,
          notifier = function()
            PakettiArp_pattern_id = pattern_index
            PakettiArp_current_arpeggio = patterns[pattern_index]
            -- Don't rebuild - too expensive
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
    local is_current_chord = (PakettiArp_audition_playing and PakettiArp_audition_chord_idx == c)
    local column_content = {
      PakettiArp_vb:button{
        text = tostring(c) .. ":",
        width = 70,
        height = 20,
        color = is_current_chord and PakettiArp_highlight_color or {64, 64, 64},
        notifier = function()
          -- Jump to this chord position during playback
          if PakettiArp_continuous_playing then
            PakettiArp_audition_chord_idx = chord_index
            PakettiArp_arp_step = 0 -- Reset to start of arpeggio pattern
          end
        end
      }
    }
    
    -- Add 7 degree buttons vertically in this column
    PakettiArp_chord_buttons[c] = {} -- Initialize button array for this chord position
    for degree = 1, 7 do
      local degree_val = degree
      local is_selected = (PakettiArp_chord_progression[c] == degree)
      local is_auditioning = (PakettiArp_audition_playing and PakettiArp_audition_chord_idx == c and is_selected)
      
      local btn = PakettiArp_vb:button{
        text = PakettiArp_roman_numerals[degree],
        width = 70,
        height = 25,
        color = is_auditioning and PakettiArp_highlight_color or (is_selected and {255, 187, 0} or {64, 64, 64}),
        notifier = function()
          -- Update progression silently
          PakettiArp_chord_progression[chord_index] = degree_val
          
          -- Update button colors immediately
          PakettiArp_UpdateChordButtonColors()
          
          -- If continuous playback is running, just update - don't interrupt
          if PakettiArp_continuous_playing then
            -- Update scale in case it affects the chord
            PakettiArp_UpdateScale()
            -- Don't rebuild dialog - keep playing
            return
          end
          
          -- If not playing, preview this chord
          PakettiArp_audition_chord_idx = chord_index
          
          local song = renoise.song()
          local track_idx = song.selected_track_index
          local inst_idx = song.selected_instrument_index
          
          -- Stop previous notes safely
          if #PakettiArp_audition_notes > 0 then
            local unique_notes = PakettiArp_UniquifyNotes(PakettiArp_audition_notes)
            if #unique_notes > 0 then
              pcall(function() song:trigger_instrument_note_off(inst_idx, track_idx, unique_notes) end)
            end
            PakettiArp_audition_notes = {}
          end
          if PakettiArp_bass_note then
            pcall(function() song:trigger_instrument_note_off(inst_idx, track_idx, {PakettiArp_bass_note}) end)
            PakettiArp_bass_note = nil
          end
          
          PakettiArp_audition_playing = true
          
          -- Play the preview (with arpeggio)
          local notes, bass_note = PakettiArp_GetChordNotes(chord_index)
          if notes then
            -- Play bass
            PakettiArp_bass_note = bass_note
            song:trigger_instrument_note_on(inst_idx, track_idx, {bass_note}, 0.8)
            
            -- Build unique arpeggio notes
            local temp_notes = {}
            for a = 1, math.min(#PakettiArp_current_arpeggio, #notes) do
              local arp_idx = PakettiArp_current_arpeggio[a] + 1
              if arp_idx <= #notes then
                local note = notes[arp_idx]
                local midi_note = PakettiArp_NoteToMidi(note.note, note.rel_octave + PakettiArp_octave_base)
                table.insert(temp_notes, midi_note)
              end
            end
            
            -- Remove duplicates and play arpeggiated
            PakettiArp_audition_notes = PakettiArp_UniquifyNotes(temp_notes)
            
            if #PakettiArp_audition_notes > 0 then
              local bpm = PakettiArp_use_current_bpm and song.transport.bpm or PakettiArp_bpm
              local lpb = song.transport.lpb
              local beat_ms = 60000 / bpm
              local line_ms = beat_ms / lpb
              
              -- Each arpeggio step takes a fraction of one line
              local arp_length = math.min(16, #PakettiArp_current_arpeggio)
              local note_duration = line_ms / arp_length
              
              -- Play each note sequentially
              for i, midi_note in ipairs(PakettiArp_audition_notes) do
                local delay_ms = (i - 1) * note_duration
                local timer_id = nil
                
                -- Note ON timer
                timer_id = function()
                  song:trigger_instrument_note_on(inst_idx, track_idx, {midi_note}, 1.0)
                  
                  -- Schedule note OFF
                  local off_timer = function()
                    pcall(function() song:trigger_instrument_note_off(inst_idx, track_idx, {midi_note}) end)
                  end
                  renoise.tool():add_timer(off_timer, note_duration * 0.8)
                  table.insert(PakettiArp_note_timers, off_timer)
                end
                
                if delay_ms > 0 then
                  renoise.tool():add_timer(timer_id, delay_ms)
                  table.insert(PakettiArp_note_timers, timer_id)
                else
                  timer_id()
                end
              end
              
              -- Schedule cleanup after all notes finish
              local total_duration = (#PakettiArp_audition_notes) * note_duration
              local cleanup_timer = function()
                -- Stop bass note
                if PakettiArp_bass_note then
                  pcall(function() song:trigger_instrument_note_off(inst_idx, track_idx, {PakettiArp_bass_note}) end)
                  PakettiArp_bass_note = nil
                end
                
                -- Clear audition state
                PakettiArp_audition_playing = false
                PakettiArp_audition_notes = {}
                
                -- Update button colors without rebuilding
                PakettiArp_UpdateChordButtonColors()
              end
              renoise.tool():add_timer(cleanup_timer, total_duration + 100)
              table.insert(PakettiArp_note_timers, cleanup_timer)
            end
          end
        end
      }
      
      -- Store button reference and add to column
      PakettiArp_chord_buttons[c][degree] = btn
      table.insert(column_content, btn)
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
  
  -- Per-chord mode selectors (8 dropdowns, one under each chord)
  local mode_dropdowns = {}
  for c = 1, 8 do
    local chord_index = c
    -- Find current mode index for this chord
    local current_mode_index = 1
    for m = 1, #PakettiArp_modes do
      if PakettiArp_modes[m] == PakettiArp_modes_per_chord[c] then
        current_mode_index = m
        break
      end
    end
    
    table.insert(mode_dropdowns, PakettiArp_vb:popup{
      items = PakettiArp_modes,
      value = current_mode_index,
      width = 70,
      notifier = function(value)
        PakettiArp_modes_per_chord[chord_index] = PakettiArp_modes[value]
        -- Don't rebuild - allow live editing
      end
    })
  end
  
  local mode_dropdowns_row = PakettiArp_vb:row(mode_dropdowns)
  
  -- Action buttons
  local play_text = PakettiArp_continuous_playing and "STOP" or "PLAY (Shift+Space)"
  local audition_text = "Next Chord (Space)"
  if PakettiArp_audition_playing and not PakettiArp_continuous_playing then
    audition_text = "Chord " .. tostring(PakettiArp_audition_chord_idx) .. "/" .. tostring(#PakettiArp_chord_progression) .. " (Space for next)"
  end
  
  local action_row = PakettiArp_vb:row{
    PakettiArp_vb:button{
      text = play_text,
      width = 150,
      color = PakettiArp_continuous_playing and {255, 128, 0} or {255, 187, 0},
      notifier = PakettiArp_Play
    },
    PakettiArp_vb:space{ width = 8 },
    PakettiArp_vb:button{
      text = audition_text,
      width = 200,
      notifier = PakettiArp_NextChord
    },
    PakettiArp_vb:space{ width = 8 },
    PakettiArp_vb:button{
      text = "Write to Pattern",
      width = 120,
      notifier = PakettiArp_WriteToPattern
    },
    PakettiArp_vb:space{ width = 8 },
    PakettiArp_vb:row{
      PakettiArp_vb:text{
        text = "Read Track:",
        font = "mono"
      },
      PakettiArp_vb:valuebox{
        min = 1,
        max = #renoise.song().tracks,
        value = PakettiArp_read_from_track or renoise.song().selected_track_index,
        width = 50,
        notifier = function(value)
          PakettiArp_read_from_track = value
        end
      },
      PakettiArp_vb:button{
        text = "Current",
        width = 50,
        notifier = function()
          PakettiArp_read_from_track = renoise.song().selected_track_index
          if PakettiArp_dialog and PakettiArp_dialog.visible then
            PakettiArp_dialog:close()
            PakettiArp_ShowDialog()
          end
        end
      },
      PakettiArp_vb:button{
        text = "Read",
        width = 50,
        notifier = function()
          PakettiArp_ReadFromPattern()
          if PakettiArp_dialog and PakettiArp_dialog.visible then
            PakettiArp_dialog:close()
            PakettiArp_ShowDialog()
          end
        end
      }
    },
    PakettiArp_vb:space{ width = 8 },
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
      local roman = PakettiArp_roman_numerals[chord_idx]
      table.insert(output_rows, PakettiArp_vb:text{
        text = roman .. " → " .. note.note .. " " .. note.triad.type:upper(),
        width = 130,
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
    -- Chord Progression + Output side by side
    PakettiArp_vb:row{
      PakettiArp_vb:column{
        style = "group",
        margin = 4,
        PakettiArp_vb:text{ text = "Chord Progression", style = "strong", font = "bold" },
        chord_prog_row,
        PakettiArp_vb:space{ height = 4 },
        PakettiArp_vb:text{ text = "Mode per chord:", style = "normal", font = "italic" },
        mode_dropdowns_row
      },
      PakettiArp_vb:space{ width = 8 },
      output_column
    },
    PakettiArp_vb:space{ height = 8 },
    -- Tonic/Root and Mode in single row
    PakettiArp_vb:column{
      style = "group",
      margin = 4,
      PakettiArp_vb:text{ text = "Key & Mode", style = "strong", font = "bold" },
      PakettiArp_vb:row{
        key_row,
        PakettiArp_vb:space{ width = 8 },
        mode_row
      }
    },
    PakettiArp_vb:space{ height = 8 },
    -- Arpeggio Steps, Type, and BPM in single row
    PakettiArp_vb:column{
      style = "group",
      margin = 4,
      PakettiArp_vb:text{ text = "Arpeggio Settings", style = "strong", font = "bold" },
      PakettiArp_vb:row{
        steps_row,
        PakettiArp_vb:space{ width = 16 },
        type_row,
        PakettiArp_vb:space{ width = 16 },
        bpm_row
      }
    },
    PakettiArp_vb:space{ height = 8 },
    -- Pattern grid
    pattern_column,
    PakettiArp_vb:space{ height = 8 },
    -- Action buttons
    action_row
  }
  
  PakettiArp_dialog = renoise.app():show_custom_dialog("Paketti Arpeggiator", content, PakettiArp_KeyHandler)
  
  -- Start highlight timer for real-time button color updates
  PakettiArp_StartHighlightTimer()
  
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

