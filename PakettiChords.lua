-- PakettiChords.lua
-- Chord Progression Player for Renoise
-- Based on MIDI Chord Player HTML app with per-slot settings
-- Lua 5.1 only. All functions GLOBAL and defined before first use.
-- Uses my_keyhandler_func as fallback. After dialog opens, reactivate middle frame for key passthrough.

-- State Variables
PakettiChords_dialog = nil
PakettiChords_vb = nil
PakettiChords_is_playing = false
PakettiChords_is_auditioning = false
PakettiChords_MAX_SLOTS = 8
PakettiChords_progression_sequence = {} -- Array of settings objects per slot
PakettiChords_selected_slot = 1
PakettiChords_current_playing_slot = nil
PakettiChords_active_notes = {} -- Currently playing notes for cleanup
PakettiChords_playback_timer = nil
PakettiChords_note_off_timers = {} -- Track note-off timers
PakettiChords_clipboard_slot = nil -- For copy/paste
PakettiChords_DEBUG = false

-- UI Width Constants
PakettiChords_LABEL_WIDTH = 50
PakettiChords_VALUEBOX_WIDTH = 50
PakettiChords_TOTAL_ROW_WIDTH = 105 -- Label + Valuebox + spacing
PakettiChords_CHORD_BUTTON_WIDTH = 50
PakettiChords_ACTION_BUTTON_WIDTH = 105

-- UI References
PakettiChords_slot_buttons = {}
PakettiChords_chord_buttons = {} -- [slot][chord_index]
PakettiChords_slot_settings = {} -- Per-slot setting controls
PakettiChords_key_popup = nil
PakettiChords_base_octave_value = nil
PakettiChords_chord_interval_value = nil
PakettiChords_instrument_number_value = nil
PakettiChords_repeat_checkbox = nil
PakettiChords_info_text = nil
PakettiChords_play_button = nil
PakettiChords_stop_button = nil

-- Extended chord definitions with 7ths, sus, aug
PakettiChords_CHORD_TYPES = {
  {name = "I", type = "maj", intervals = {0, 4, 7}},
  {name = "ii", type = "min", intervals = {0, 3, 7}},
  {name = "iii", type = "min", intervals = {0, 3, 7}},
  {name = "IV", type = "maj", intervals = {0, 4, 7}},
  {name = "V", type = "maj", intervals = {0, 4, 7}},
  {name = "vi", type = "min", intervals = {0, 3, 7}},
  {name = "vii°", type = "dim", intervals = {0, 3, 6}},
  {name = "I7", type = "maj7", intervals = {0, 4, 7, 11}},
  {name = "ii7", type = "min7", intervals = {0, 3, 7, 10}},
  {name = "V7", type = "dom7", intervals = {0, 4, 7, 10}},
  {name = "Isus2", type = "sus2", intervals = {0, 2, 7}},
  {name = "Isus4", type = "sus4", intervals = {0, 5, 7}},
  {name = "I+", type = "aug", intervals = {0, 4, 8}}
}

-- Major scale intervals
PakettiChords_MAJOR_INTERVALS = {0, 2, 4, 5, 7, 9, 11}

-- Note names
PakettiChords_NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

-- Strum order options
PakettiChords_STRUM_ORDERS = {"Up", "Down", "Random"}

-- Strum mode options
PakettiChords_STRUM_MODES = {"Rows", "Delays"}

-- Preset progressions (common chord progressions from various genres)
PakettiChords_PRESETS = {
  {name = "I-V-vi-IV (Pop)", chords = {1, 5, 6, 4}},
  {name = "I-IV-V (Rock)", chords = {1, 4, 5}},
  {name = "I-IV-I-V (Blues)", chords = {1, 4, 1, 5}},
  {name = "I-vi-IV-V (50s)", chords = {1, 6, 4, 5}},
  {name = "vi-IV-I-V (Axis)", chords = {6, 4, 1, 5}},
  {name = "I-V-vi-iii-IV-I-IV-V (Canon)", chords = {1, 5, 6, 3, 4, 1, 4, 5}},
  {name = "ii-V-I (Jazz)", chords = {2, 5, 1}},
  {name = "I-vi-ii-V (Circle)", chords = {1, 6, 2, 5}},
  {name = "I-bVII-IV (Modal)", chords = {1, 7, 4}},
  {name = "i-bVII-bVI-V (Minor)", chords = {1, 7, 6, 5}},
  {name = "I-iii-IV-iv (Creep)", chords = {1, 3, 4, 4}},
  {name = "vi-V-IV-V (Andalusian)", chords = {6, 5, 4, 5}},
  {name = "I-IV-vi-V (Sensitive)", chords = {1, 4, 6, 5}},
  {name = "I-II-IV-I (Royal Road)", chords = {1, 2, 4, 1}},
  {name = "I-V-IV-IV (Plagal)", chords = {1, 5, 4, 4}},
  {name = "I-bIII-bVII-IV (Dorian)", chords = {1, 3, 7, 4}},
  {name = "vi-ii-V-I (Turnaround)", chords = {6, 2, 5, 1}}
}

-- Create default slot settings
function PakettiChords_CreateDefaultSlotSettings()
  return {
    chord_index = nil,
    note_duration = 0.9, -- Slightly shorter than default interval to avoid overlap
    strum = 0,
    strum_mode = 1, -- 1=Rows, 2=Delays
    strum_order = 1, -- 1=Up, 2=Down, 3=Random
    velocity = 80, -- 0-127 (0x00-0x7F, displayed as 00-80 hex in Renoise)
    extra1_index = 0,
    extra1_octave = -2,
    extra1_duration = 8,
    extra2_index = 0,
    extra2_octave = 1,
    extra2_duration = 0.1
  }
end

-- Initialize progression slots
function PakettiChords_Initialize()
  PakettiChords_progression_sequence = {}
  for i = 1, PakettiChords_MAX_SLOTS do
    PakettiChords_progression_sequence[i] = PakettiChords_CreateDefaultSlotSettings()
  end
end

-- Helper: Get note name from number (0-11)
function PakettiChords_GetNoteName(note_num)
  return PakettiChords_NOTE_NAMES[(note_num % 12) + 1]
end

-- Helper: Convert note value to Renoise note string
function PakettiChords_NoteValueToString(note_value)
  local octave = math.floor(note_value / 12)
  local note_name = PakettiChords_GetNoteName(note_value)
  return note_name .. "-" .. tostring(octave)
end

-- Helper: Calculate chord notes based on key and chord index
function PakettiChords_CalculateChordNotes(key, chord_index, base_octave)
  local chord_type = PakettiChords_CHORD_TYPES[chord_index]
  if not chord_type then return {} end
  
  local root = (key + PakettiChords_MAJOR_INTERVALS[chord_index > 7 and (chord_index - 7) or chord_index]) % 12
  local notes = {}
  
  for _, interval in ipairs(chord_type.intervals) do
    local note = root + interval + (base_octave * 12)
    if note >= 0 and note <= 119 then
      table.insert(notes, note)
    end
  end
  
  return notes
end

-- Helper: Get chord info string
function PakettiChords_GetChordInfo(key, chord_index)
  local chord_type = PakettiChords_CHORD_TYPES[chord_index]
  if not chord_type then return "" end
  
  local root = (key + PakettiChords_MAJOR_INTERVALS[chord_index > 7 and (chord_index - 7) or chord_index]) % 12
  local note_names = {}
  
  for _, interval in ipairs(chord_type.intervals) do
    local note = (root + interval) % 12
    table.insert(note_names, PakettiChords_GetNoteName(note))
  end
  
  return "Chord " .. chord_type.name .. ": " .. table.concat(note_names, ", ")
end

-- Apply strum order to notes
function PakettiChords_ApplyStrumOrder(notes, strum_order)
  local result = {}
  for _, note in ipairs(notes) do
    table.insert(result, note)
  end
  
  if strum_order == 2 then
    -- Down: reverse (descending)
    local reversed = {}
    for i = #result, 1, -1 do
      table.insert(reversed, result[i])
    end
    return reversed
  elseif strum_order == 3 then
    -- Random: shuffle
    for i = #result, 2, -1 do
      local j = math.random(1, i)
      result[i], result[j] = result[j], result[i]
    end
    return result
  end
  
  -- Up (default): already ascending
  return result
end

-- Stop all active notes
function PakettiChords_StopAllNotes()
  if #PakettiChords_active_notes == 0 then return end
  
  local song = renoise.song()
  local track_index = song.selected_track_index
  local instrument_index = song.selected_instrument_index
  
  -- Remove duplicates
  local unique_notes = {}
  local seen = {}
  for _, note_value in ipairs(PakettiChords_active_notes) do
    if not seen[note_value] then
      seen[note_value] = true
      table.insert(unique_notes, note_value)
    end
  end
  
  if #unique_notes > 0 then
    song:trigger_instrument_note_off(instrument_index, track_index, unique_notes)
  end
  
  PakettiChords_active_notes = {}
end

-- Clear all timers (properly check has_timer before removing)
function PakettiChords_ClearAllTimers()
  local cleared_count = 0
  local total_timers = #PakettiChords_note_off_timers
  
  print(string.format("PakettiChords DEBUG: ClearAllTimers() attempting to clear %d tracked timers", total_timers))
  
  -- Clear all timers in the array (includes both note-offs AND playback timers now)
  for i, timer_func in ipairs(PakettiChords_note_off_timers) do
    if timer_func and renoise.tool():has_timer(timer_func) then
      renoise.tool():remove_timer(timer_func)
      cleared_count = cleared_count + 1
    else
      if timer_func then
        print(string.format("PakettiChords DEBUG: Timer %d/%d was not active", i, total_timers))
      end
    end
  end
  
  -- Reset arrays
  PakettiChords_note_off_timers = {}
  PakettiChords_playback_timer = nil
  
  print(string.format("PakettiChords DEBUG: ClearAllTimers() successfully removed %d/%d timers", cleared_count, total_timers))
end

-- Stop playback
function PakettiChords_Stop()
  if not PakettiChords_is_playing and not PakettiChords_is_auditioning then 
    print("PakettiChords DEBUG: Stop() called but not playing/auditioning, ignoring")
    return 
  end
  
  print("PakettiChords DEBUG: Stop() called, stopping playback")
  
  PakettiChords_is_playing = false
  PakettiChords_is_auditioning = false
  PakettiChords_ClearAllTimers()
  PakettiChords_StopAllNotes()
  PakettiChords_current_playing_slot = nil
  PakettiChords_UpdateUI()
  
  renoise.app():show_status("PakettiChords: Stopped")
end

-- Preview/Audition a single slot (slow, non-looping)
function PakettiChords_AuditionSlot(slot)
  -- If already auditioning, stop it
  if PakettiChords_is_auditioning then
    PakettiChords_StopAllNotes()
    PakettiChords_ClearAllTimers()
    PakettiChords_is_auditioning = false
    renoise.app():show_status("PakettiChords: Audition stopped")
    return
  end
  
  local settings = PakettiChords_progression_sequence[slot]
  if not settings or not settings.chord_index then
    renoise.app():show_status("PakettiChords: No chord in slot " .. string.format("%02d", slot))
    return
  end
  
  -- Stop any current playback first
  PakettiChords_Stop()
  PakettiChords_is_auditioning = true
  
  -- Get settings
  local key = PakettiChords_key_popup and (PakettiChords_key_popup.value - 1) or 0
  local base_octave = PakettiChords_base_octave_value and PakettiChords_base_octave_value.value or 4
  
  local song = renoise.song()
  local track_index = song.selected_track_index
  local instrument_index = song.selected_instrument_index
  
  -- Calculate and play chord
  local base_notes = PakettiChords_CalculateChordNotes(key, settings.chord_index, base_octave)
  local strummed_notes = PakettiChords_ApplyStrumOrder(base_notes, settings.strum_order)
  
  -- Play immediately at slower tempo for audition
  local bpm = song.transport.bpm
  local lpb = song.transport.lpb
  local beat_ms = 60000 / bpm
  local lpb_ms = beat_ms / lpb
  local strum_delay_ms = settings.strum * lpb_ms * 2 -- Double delay for audition
  
  -- Play notes with strum
  for i, note in ipairs(strummed_notes) do
    local delay = (i - 1) * strum_delay_ms
    
    if delay > 0 then
      local timer_func = function()
        song:trigger_instrument_note_on(instrument_index, track_index, {note}, settings.velocity / 80.0)
        table.insert(PakettiChords_active_notes, note)
      end
      renoise.tool():add_timer(timer_func, delay)
      table.insert(PakettiChords_note_off_timers, timer_func)
    else
      song:trigger_instrument_note_on(instrument_index, track_index, {note}, settings.velocity / 80.0)
      table.insert(PakettiChords_active_notes, note)
    end
  end
  
  -- Schedule note off
  local duration_ms = settings.note_duration * beat_ms * 1.5 -- Longer for audition
  local timer_func = function()
    PakettiChords_StopAllNotes()
    PakettiChords_is_auditioning = false
  end
  renoise.tool():add_timer(timer_func, duration_ms)
  table.insert(PakettiChords_note_off_timers, timer_func)
  
  -- Show chord info
  if PakettiChords_info_text then
    PakettiChords_info_text.text = "Audition: " .. PakettiChords_GetChordInfo(key, settings.chord_index)
  end
  
  renoise.app():show_status("PakettiChords: Auditioning slot " .. string.format("%02d", slot))
end

-- Play a single chord with strum
function PakettiChords_PlayChordWithStrum(notes, slot_settings, next_chord_interval_ms)
  if #notes == 0 then return end
  
  local song = renoise.song()
  local track_index = song.selected_track_index
  local instrument_index = song.selected_instrument_index
  local bpm = song.transport.bpm
  local lpb = song.transport.lpb
  
  -- Calculate timing
  local beat_ms = 60000 / bpm
  local lpb_ms = beat_ms / lpb
  
  -- Convert velocity (0-127) to 0.0-1.0 for Renoise
  local velocity_norm = slot_settings.velocity / 127.0
  
  local strum_mode = slot_settings.strum_mode or 1
  local strum_mode_str = (strum_mode == 2) and "Delays" or "Rows"
  
  print(string.format("PakettiChords DEBUG: PlayChordWithStrum - %d notes, mode=%s, strum=%.2f, velocity=%d (%.3f)", 
    #notes, strum_mode_str, slot_settings.strum, slot_settings.velocity, velocity_norm))
  
  -- Play notes with strum
  for i, note in ipairs(notes) do
    local delay
    
    if strum_mode == 2 then
      -- Delays mode: evenly distribute across delay range (0-255 delay units = 0-1 line)
      -- 255 delay units = 1 full line = lpb_ms
      if #notes > 1 and slot_settings.strum > 0 then
        local max_delay_units = 255 * (slot_settings.strum / 16.0)
        local delay_units = (i - 1) * (max_delay_units / (#notes - 1))
        delay = (delay_units / 255) * lpb_ms
      else
        delay = 0
      end
    else
      -- Rows mode: delay between notes in rows
      delay = (i - 1) * slot_settings.strum * lpb_ms
    end
    
    if delay > 0 then
      local timer_func = function()
        if PakettiChords_is_playing then
          print(string.format("PakettiChords DEBUG: Triggering strummed note %d at delay %.2fms", note, delay))
          song:trigger_instrument_note_on(instrument_index, track_index, {note}, velocity_norm)
          table.insert(PakettiChords_active_notes, note)
        end
      end
      renoise.tool():add_timer(timer_func, delay)
      table.insert(PakettiChords_note_off_timers, timer_func)
    else
      print(string.format("PakettiChords DEBUG: Triggering note %d immediately", note))
      song:trigger_instrument_note_on(instrument_index, track_index, {note}, velocity_norm)
      table.insert(PakettiChords_active_notes, note)
    end
  end
  
  -- Schedule note off RIGHT BEFORE next chord starts (subtract 10ms safety margin)
  -- This ensures no overlap regardless of strum setting
  local note_off_time = math.max(10, next_chord_interval_ms - 10)
  
  print(string.format("PakettiChords DEBUG: Scheduling note-off in %.2fms (next chord in %.2fms)", 
    note_off_time, next_chord_interval_ms))
  
  local timer_func = function()
    if PakettiChords_is_playing or true then -- Always turn off notes, even if stopped
      print("PakettiChords DEBUG: Executing note-off timer, stopping all notes")
      PakettiChords_StopAllNotes()
    end
  end
  renoise.tool():add_timer(timer_func, note_off_time)
  table.insert(PakettiChords_note_off_timers, timer_func)
end

-- Play extra notes for a slot
function PakettiChords_PlayExtraNotes(base_notes, slot_settings, next_chord_interval_ms)
  local song = renoise.song()
  local track_index = song.selected_track_index
  local instrument_index = song.selected_instrument_index
  local bpm = song.transport.bpm
  local beat_ms = 60000 / bpm
  local velocity_norm = slot_settings.velocity / 127.0
  
  -- Extra note 1
  if slot_settings.extra1_index > 0 and slot_settings.extra1_index <= #base_notes then
    local extra_note = base_notes[slot_settings.extra1_index] + (slot_settings.extra1_octave * 12)
    if extra_note >= 0 and extra_note <= 119 then
      print(string.format("PakettiChords DEBUG: Playing EX1 note %d", extra_note))
      song:trigger_instrument_note_on(instrument_index, track_index, {extra_note}, velocity_norm)
      table.insert(PakettiChords_active_notes, extra_note)
      
      -- Use the minimum of extra1_duration or time until next chord
      local duration_ms = math.min(slot_settings.extra1_duration * beat_ms, next_chord_interval_ms - 10)
      local timer_func = function()
        print(string.format("PakettiChords DEBUG: Turning off EX1 note %d", extra_note))
        song:trigger_instrument_note_off(instrument_index, track_index, {extra_note})
      end
      renoise.tool():add_timer(timer_func, duration_ms)
      table.insert(PakettiChords_note_off_timers, timer_func)
    end
  end
  
  -- Extra note 2
  if slot_settings.extra2_index > 0 and slot_settings.extra2_index <= #base_notes then
    local extra_note = base_notes[slot_settings.extra2_index] + (slot_settings.extra2_octave * 12)
    if extra_note >= 0 and extra_note <= 119 then
      print(string.format("PakettiChords DEBUG: Playing EX2 note %d", extra_note))
      song:trigger_instrument_note_on(instrument_index, track_index, {extra_note}, velocity_norm)
      table.insert(PakettiChords_active_notes, extra_note)
      
      -- Use the minimum of extra2_duration or time until next chord
      local duration_ms = math.min(slot_settings.extra2_duration * beat_ms, next_chord_interval_ms - 10)
      local timer_func = function()
        print(string.format("PakettiChords DEBUG: Turning off EX2 note %d", extra_note))
        song:trigger_instrument_note_off(instrument_index, track_index, {extra_note})
      end
      renoise.tool():add_timer(timer_func, duration_ms)
      table.insert(PakettiChords_note_off_timers, timer_func)
    end
  end
end

-- Get active progression (non-nil chord slots)
function PakettiChords_GetActiveProgression()
  local active = {}
  for slot = 1, PakettiChords_MAX_SLOTS do
    local settings = PakettiChords_progression_sequence[slot]
    if settings and settings.chord_index then
      table.insert(active, {slot = slot, settings = settings})
    end
  end
  return active
end

-- Playback tick function
function PakettiChords_PlaybackTick(current_index, active_progression, key, base_octave, chord_interval, repeat_enabled)
  if not PakettiChords_is_playing then 
    print("PakettiChords DEBUG: PlaybackTick called but is_playing=false, exiting")
    return 
  end
  
  local song = renoise.song()
  local bpm = song.transport.bpm
  local beat_ms = 60000 / bpm
  
  print(string.format("PakettiChords DEBUG: PlaybackTick index=%d/%d, BPM=%d, beat_ms=%.2f, chord_interval=%.2f beats", 
    current_index, #active_progression, bpm, beat_ms, chord_interval))
  
  -- Stop all previous notes before playing new chord
  PakettiChords_StopAllNotes()
  
  -- Check if we've finished
  if current_index > #active_progression then
    if repeat_enabled then
      print("PakettiChords DEBUG: Reached end, repeat enabled, looping to slot 1")
      current_index = 1
    else
      print("PakettiChords DEBUG: Reached end, repeat disabled, stopping playback")
      PakettiChords_Stop()
      return
    end
  end
  
  -- Get current progression item
  local prog_item = active_progression[current_index]
  local slot = prog_item.slot
  local settings = prog_item.settings
  
  print(string.format("PakettiChords DEBUG: Playing slot %d, chord_index=%s, strum=%.2f, velocity=%d", 
    slot, tostring(settings.chord_index), settings.strum, settings.velocity))
  
  PakettiChords_current_playing_slot = slot
  PakettiChords_UpdateUI()
  
  -- Calculate base chord notes
  local base_notes = PakettiChords_CalculateChordNotes(key, settings.chord_index, base_octave)
  
  -- Apply strum order
  local strummed_notes = PakettiChords_ApplyStrumOrder(base_notes, settings.strum_order)
  
  -- Calculate interval for next chord (when notes MUST be off)
  local interval_ms = chord_interval * beat_ms
  
  -- Play chord with strum (pass interval_ms so notes can be turned off BEFORE next chord)
  PakettiChords_PlayChordWithStrum(strummed_notes, settings, interval_ms)
  
  -- Play extra notes
  PakettiChords_PlayExtraNotes(base_notes, settings, interval_ms)
  
  -- Update info display
  if PakettiChords_info_text then
    PakettiChords_info_text.text = PakettiChords_GetChordInfo(key, settings.chord_index)
  end
  
  -- Schedule next chord
  print(string.format("PakettiChords DEBUG: Scheduling next chord in %.2fms (%.2f beats)", interval_ms, chord_interval))
  local timer_func = function()
    PakettiChords_PlaybackTick(current_index + 1, active_progression, key, base_octave, chord_interval, repeat_enabled)
  end
  
  -- CRITICAL: Add to timers array BEFORE scheduling, so it can be cleared if needed
  table.insert(PakettiChords_note_off_timers, timer_func)
  PakettiChords_playback_timer = timer_func
  renoise.tool():add_timer(timer_func, interval_ms)
  
  print(string.format("PakettiChords DEBUG: Now tracking %d total timers", #PakettiChords_note_off_timers))
end

-- Start playback
function PakettiChords_Play()
  if PakettiChords_is_playing then 
    print("PakettiChords DEBUG: Play() called but already playing, ignoring")
    return 
  end
  
  print("PakettiChords DEBUG: Play() called, starting playback")
  
  local active_progression = PakettiChords_GetActiveProgression()
  if #active_progression == 0 then
    print("PakettiChords DEBUG: No chords in progression, aborting")
    renoise.app():show_status("PakettiChords: No chords selected in progression")
    return
  end
  
  print(string.format("PakettiChords DEBUG: Active progression has %d slots", #active_progression))
  
  -- Clean up any leftover state from previous playback
  print("PakettiChords DEBUG: Clearing all timers and notes before starting")
  PakettiChords_ClearAllTimers()
  PakettiChords_StopAllNotes()
  PakettiChords_current_playing_slot = nil
  
  -- Get settings from UI
  local key = PakettiChords_key_popup and (PakettiChords_key_popup.value - 1) or 0
  local base_octave = PakettiChords_base_octave_value and PakettiChords_base_octave_value.value or 4
  local chord_interval = PakettiChords_chord_interval_value and PakettiChords_chord_interval_value.value or 4
  local repeat_enabled = PakettiChords_repeat_checkbox and PakettiChords_repeat_checkbox.value or false
  
  print(string.format("PakettiChords DEBUG: Settings - key=%d, base_octave=%d, chord_interval=%.2f, repeat=%s", 
    key, base_octave, chord_interval, tostring(repeat_enabled)))
  
  PakettiChords_is_playing = true
  PakettiChords_UpdateUI()
  
  renoise.app():show_status("PakettiChords: Playing progression")
  
  -- Start playback
  PakettiChords_PlaybackTick(1, active_progression, key, base_octave, chord_interval, repeat_enabled)
end

-- Write progression to pattern
function PakettiChords_WriteToPattern()
  local active_progression = PakettiChords_GetActiveProgression()
  if #active_progression == 0 then
    renoise.app():show_status("PakettiChords: No chords selected to write")
    return
  end
  
  local song = renoise.song()
  local track = song.selected_track
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("PakettiChords: Not a sequencer track")
    return
  end
  
  -- Validate pattern exists
  local patt = song:pattern(song.selected_pattern_index)
  if not patt then
    renoise.app():show_status("PakettiChords: No pattern selected")
    return
  end
  
  local ptrack = patt:track(song.selected_track_index)
  
  -- CLEAR THE ENTIRE TRACK FIRST - prevent duplicates and havoc
  print("PakettiChords DEBUG: Clearing entire track before writing pattern")
  for line_idx = 1, patt.number_of_lines do
    local line = ptrack:line(line_idx)
    line:clear()
  end
  print(string.format("PakettiChords DEBUG: Cleared %d lines in track", patt.number_of_lines))
  
  -- Get settings
  local key = PakettiChords_key_popup and (PakettiChords_key_popup.value - 1) or 0
  local base_octave = PakettiChords_base_octave_value and PakettiChords_base_octave_value.value or 4
  local chord_interval = PakettiChords_chord_interval_value and PakettiChords_chord_interval_value.value or 4
  local instrument_number = PakettiChords_instrument_number_value and (PakettiChords_instrument_number_value.value - 1) or 0
  local lpb = song.transport.lpb
  
  local lines_per_step = chord_interval * lpb
  local start_line = 1 -- Always start from beginning of pattern
  
  -- Calculate max columns needed
  local max_cols = 0
  for _, prog_item in ipairs(active_progression) do
    local settings = prog_item.settings
    local chord_type = PakettiChords_CHORD_TYPES[settings.chord_index]
    local col_count = #chord_type.intervals
    if settings.extra1_index > 0 then col_count = col_count + 1 end
    if settings.extra2_index > 0 then col_count = col_count + 1 end
    max_cols = math.max(max_cols, col_count)
  end
  
  -- Ensure enough visible columns
  if track.visible_note_columns < max_cols then
    track.visible_note_columns = math.min(12, max_cols)
  end
  
  -- Track note-on events for intelligent note-off placement
  local note_on_events = {}
  local chords_written = 0
  
  -- Write each chord in progression
  for step_idx, prog_item in ipairs(active_progression) do
    local settings = prog_item.settings
    local step_start_line = start_line + ((step_idx - 1) * lines_per_step)
    
    -- Skip if starting beyond pattern length
    if step_start_line > patt.number_of_lines then 
      break 
    end
    
    -- Calculate base notes
    local chord_type = PakettiChords_CHORD_TYPES[settings.chord_index]
    local root = (key + PakettiChords_MAJOR_INTERVALS[settings.chord_index > 7 and (settings.chord_index - 7) or settings.chord_index]) % 12
    local base_notes = {}
    for _, interval in ipairs(chord_type.intervals) do
      table.insert(base_notes, root + interval + (base_octave * 12))
    end
    
    -- Apply strum order
    local strummed_notes = PakettiChords_ApplyStrumOrder(base_notes, settings.strum_order)
    
    -- Write chord notes
    local col_idx = 1
    for note_idx, note in ipairs(strummed_notes) do
      -- Validate note is in MIDI range (0-119)
      if note >= 0 and note <= 119 and col_idx <= 12 and step_start_line <= patt.number_of_lines then
        local note_line
        local delay_value = 0
        
        if settings.strum_mode == 2 then
          -- Delays mode: all notes on same row, evenly divide 00-FF delay range
          note_line = step_start_line
          if #strummed_notes > 1 and settings.strum > 0 then
            -- Divide 255 by (num_notes - 1), then scale by strum value (0-16)
            -- strum=16 means full 00-FF spread, strum=8 means half spread, etc
            local max_delay = math.floor(255 * (settings.strum / 16.0))
            delay_value = math.floor((note_idx - 1) * (max_delay / (#strummed_notes - 1)))
          end
        else
          -- Rows mode: notes on separate rows (original behavior)
          local strum_delay = (note_idx - 1) * settings.strum
          note_line = step_start_line + math.floor(strum_delay)
          delay_value = math.floor((strum_delay - math.floor(strum_delay)) * 255)
        end
        
        if note_line <= patt.number_of_lines then
          local line = ptrack:line(note_line)
          local ncol = line:note_column(col_idx)
          ncol.note_string = PakettiChords_NoteValueToString(note)
          ncol.instrument_value = instrument_number
          ncol.volume_value = settings.velocity -- 0-127 range
          if delay_value > 0 then
            ncol.delay_value = delay_value
          end
          
          -- Track for intelligent note-off
          local duration_lines = settings.note_duration * lpb
          table.insert(note_on_events, {
            col = col_idx,
            start_line = note_line,
            end_line = note_line + math.floor(duration_lines),
            note = note
          })
        end
        col_idx = col_idx + 1
      end
    end
    
    -- Write extra notes
    if settings.extra1_index > 0 and settings.extra1_index <= #base_notes and col_idx <= 12 then
      local extra_note = base_notes[settings.extra1_index] + (settings.extra1_octave * 12)
      if extra_note >= 0 and extra_note <= 119 and step_start_line <= patt.number_of_lines then
        local line = ptrack:line(step_start_line)
        local ncol = line:note_column(col_idx)
        ncol.note_string = PakettiChords_NoteValueToString(extra_note)
        ncol.instrument_value = instrument_number
        ncol.volume_value = settings.velocity -- 0-127 range
        
        local duration_lines = settings.extra1_duration * lpb
        table.insert(note_on_events, {
          col = col_idx,
          start_line = step_start_line,
          end_line = step_start_line + math.floor(duration_lines),
          note = extra_note
        })
        col_idx = col_idx + 1
      end
    end
    
    if settings.extra2_index > 0 and settings.extra2_index <= #base_notes and col_idx <= 12 then
      local extra_note = base_notes[settings.extra2_index] + (settings.extra2_octave * 12)
      if extra_note >= 0 and extra_note <= 119 and step_start_line <= patt.number_of_lines then
        local line = ptrack:line(step_start_line)
        local ncol = line:note_column(col_idx)
        ncol.note_string = PakettiChords_NoteValueToString(extra_note)
        ncol.instrument_value = instrument_number
        ncol.volume_value = settings.velocity -- 0-127 range
        
        local duration_lines = settings.extra2_duration * lpb
        table.insert(note_on_events, {
          col = col_idx,
          start_line = step_start_line,
          end_line = step_start_line + math.floor(duration_lines),
          note = extra_note
        })
        col_idx = col_idx + 1
      end
    end
    
    chords_written = chords_written + 1
  end
  
  -- Show how many chords were written
  local status_msg = string.format("PakettiChords: Wrote %d/%d chords to pattern", chords_written, #active_progression)
  if chords_written < #active_progression then
    status_msg = status_msg .. string.format(" (need %d lines, pattern has %d)", 
      #active_progression * lines_per_step, patt.number_of_lines)
  end
  renoise.app():show_status(status_msg)
  
  -- Intelligent note-off placement
  for _, event in ipairs(note_on_events) do
    if event.end_line <= patt.number_of_lines then
      -- Check if there's another note-on in the same column after this one
      local next_note_in_col = nil
      for _, other_event in ipairs(note_on_events) do
        if other_event.col == event.col and other_event.start_line > event.start_line then
          if not next_note_in_col or other_event.start_line < next_note_in_col.start_line then
            next_note_in_col = other_event
          end
        end
      end
      
      -- Only place note-off if it happens before the next note or if there's no next note
      if not next_note_in_col or event.end_line < next_note_in_col.start_line then
        local line = ptrack:line(event.end_line)
        local ncol = line:note_column(event.col)
        if ncol.is_empty then
          ncol.note_string = "OFF"
        end
      end
    end
  end
  
  renoise.app():show_status("PakettiChords: Wrote progression to pattern (" .. tostring(#active_progression) .. " chords)")
end

-- Copy slot settings
function PakettiChords_CopySlot(slot)
  local settings = PakettiChords_progression_sequence[slot]
  if not settings or not settings.chord_index then
    renoise.app():show_status("PakettiChords: No chord in slot to copy")
    return
  end
  
  -- Deep copy
  PakettiChords_clipboard_slot = {
    chord_index = settings.chord_index,
    note_duration = settings.note_duration,
    strum = settings.strum,
    strum_mode = settings.strum_mode,
    strum_order = settings.strum_order,
    velocity = settings.velocity,
    extra1_index = settings.extra1_index,
    extra1_octave = settings.extra1_octave,
    extra1_duration = settings.extra1_duration,
    extra2_index = settings.extra2_index,
    extra2_octave = settings.extra2_octave,
    extra2_duration = settings.extra2_duration
  }
  
  renoise.app():show_status("PakettiChords: Copied slot " .. string.format("%02d", slot))
end

-- Paste slot settings
function PakettiChords_PasteSlot(slot)
  if not PakettiChords_clipboard_slot then
    renoise.app():show_status("PakettiChords: No slot in clipboard")
    return
  end
  
  -- Deep copy from clipboard
  PakettiChords_progression_sequence[slot] = {
    chord_index = PakettiChords_clipboard_slot.chord_index,
    note_duration = PakettiChords_clipboard_slot.note_duration,
    strum = PakettiChords_clipboard_slot.strum,
    strum_mode = PakettiChords_clipboard_slot.strum_mode or 1,
    strum_order = PakettiChords_clipboard_slot.strum_order,
    velocity = PakettiChords_clipboard_slot.velocity,
    extra1_index = PakettiChords_clipboard_slot.extra1_index,
    extra1_octave = PakettiChords_clipboard_slot.extra1_octave,
    extra1_duration = PakettiChords_clipboard_slot.extra1_duration,
    extra2_index = PakettiChords_clipboard_slot.extra2_index,
    extra2_octave = PakettiChords_clipboard_slot.extra2_octave,
    extra2_duration = PakettiChords_clipboard_slot.extra2_duration
  }
  
  PakettiChords_UpdateUI()
  renoise.app():show_status("PakettiChords: Pasted to slot " .. string.format("%02d", slot))
end

-- Move slot up
function PakettiChords_MoveSlotUp(slot)
  if slot <= 1 then return end
  
  local temp = PakettiChords_progression_sequence[slot]
  PakettiChords_progression_sequence[slot] = PakettiChords_progression_sequence[slot - 1]
  PakettiChords_progression_sequence[slot - 1] = temp
  
  PakettiChords_selected_slot = slot - 1
  PakettiChords_UpdateUI()
  renoise.app():show_status("PakettiChords: Moved slot " .. string.format("%02d", slot) .. " up")
end

-- Move slot down
function PakettiChords_MoveSlotDown(slot)
  if slot >= PakettiChords_MAX_SLOTS then return end
  
  local temp = PakettiChords_progression_sequence[slot]
  PakettiChords_progression_sequence[slot] = PakettiChords_progression_sequence[slot + 1]
  PakettiChords_progression_sequence[slot + 1] = temp
  
  PakettiChords_selected_slot = slot + 1
  PakettiChords_UpdateUI()
  renoise.app():show_status("PakettiChords: Moved slot " .. string.format("%02d", slot) .. " down")
end

-- Load preset progression
function PakettiChords_LoadPreset(preset_index)
  local preset = PakettiChords_PRESETS[preset_index]
  if not preset then return end
  
  -- Clear all slots first
  PakettiChords_Initialize()
  
  -- Load preset chords
  for i, chord_idx in ipairs(preset.chords) do
    if i <= PakettiChords_MAX_SLOTS then
      PakettiChords_progression_sequence[i].chord_index = chord_idx
    end
  end
  
  PakettiChords_UpdateUI()
  renoise.app():show_status("PakettiChords: Loaded preset '" .. preset.name .. "'")
end

-- Clear progression
function PakettiChords_Clear()
  PakettiChords_Stop()
  PakettiChords_Initialize()
  PakettiChords_selected_slot = 1
  PakettiChords_UpdateUI()
  renoise.app():show_status("PakettiChords: Cleared progression")
end

-- Select chord for slot
function PakettiChords_SelectChord(slot, chord_index)
  PakettiChords_progression_sequence[slot].chord_index = chord_index
  PakettiChords_selected_slot = slot
  PakettiChords_UpdateUI()
  
  -- Show chord info
  if PakettiChords_info_text and PakettiChords_key_popup then
    local key = PakettiChords_key_popup.value - 1
    PakettiChords_info_text.text = PakettiChords_GetChordInfo(key, chord_index)
  end
end

-- Clear chord for slot
function PakettiChords_ClearSlot(slot)
  PakettiChords_progression_sequence[slot] = PakettiChords_CreateDefaultSlotSettings()
  PakettiChords_UpdateUI()
end

-- Update UI
function PakettiChords_UpdateUI()
  if not PakettiChords_vb then return end
  
  -- Update slot buttons (using text property to show state since color can't be set to nil)
  for slot = 1, PakettiChords_MAX_SLOTS do
    if PakettiChords_slot_buttons[slot] then
      local has_chord = PakettiChords_progression_sequence[slot].chord_index ~= nil
      local is_playing = (PakettiChords_current_playing_slot == slot)
      local is_selected = (slot == PakettiChords_selected_slot)
      
      if is_playing then
        PakettiChords_slot_buttons[slot].color = {255, 128, 0} -- Bright Orange for playing (matches PakettiGater playhead)
      elseif is_selected and has_chord then
        PakettiChords_slot_buttons[slot].color = {128, 0, 128} -- Purple for selected (matches PakettiGater)
      elseif has_chord then
        PakettiChords_slot_buttons[slot].color = {82, 139, 255} -- Blue for has chord
      else
        -- Can't set color to nil, so use a neutral gray
        PakettiChords_slot_buttons[slot].color = {64, 64, 64} -- Darker gray for empty
      end
    end
    
    -- Update chord buttons for this slot
    if PakettiChords_chord_buttons[slot] then
      for chord_index = 1, #PakettiChords_CHORD_TYPES do
        local btn = PakettiChords_chord_buttons[slot][chord_index]
        if btn then
          if PakettiChords_progression_sequence[slot].chord_index == chord_index then
            btn.color = {128, 0, 128} -- Purple for selected chord (matches PakettiGater)
          else
            -- Gray for unselected
            btn.color = {64, 64, 64}
          end
        end
      end
    end
  end
  
  -- Update play/stop buttons
  if PakettiChords_play_button then
    if PakettiChords_is_playing then
      PakettiChords_play_button.text = "Stop (Space)"
    else
      PakettiChords_play_button.text = "Play (Space)"
    end
  end
  if PakettiChords_stop_button then
    PakettiChords_stop_button.active = PakettiChords_is_playing
  end
end

-- Build chord buttons for a slot
function PakettiChords_BuildChordButtons(slot)
  local buttons = {}
  local column = PakettiChords_vb:column{}
  
  for chord_index = 1, #PakettiChords_CHORD_TYPES do
    local chord_type = PakettiChords_CHORD_TYPES[chord_index]
    local btn = PakettiChords_vb:button{
      text = chord_type.name,
      width = PakettiChords_TOTAL_ROW_WIDTH,
      height = 18,
      align = "center",
      notifier = function()
        PakettiChords_SelectChord(slot, chord_index)
      end
    }
    buttons[chord_index] = btn
    column:add_child(btn)
    
  end
  
  PakettiChords_chord_buttons[slot] = buttons
  return column
end

-- Build slot settings panel
function PakettiChords_BuildSlotSettings(slot)
  local settings = PakettiChords_progression_sequence[slot]
  
  local panel = PakettiChords_vb:column{
    -- Duration, Strum, Velocity
    PakettiChords_vb:row{
      PakettiChords_vb:text{text = "Length", width = PakettiChords_LABEL_WIDTH, style = "strong", font = "bold"},
      PakettiChords_vb:valuebox{
        min = 0.1,
        max = 64,
        value = settings.note_duration,
        width = PakettiChords_VALUEBOX_WIDTH,
        notifier = function(value)
          PakettiChords_progression_sequence[slot].note_duration = value
        end
      }
    },
    PakettiChords_vb:row{
      PakettiChords_vb:text{text = "Strum", width = PakettiChords_LABEL_WIDTH, style = "strong", font = "bold", tooltip = "Rows: delay between notes in rows | Delays: split 00-FF delay range"},
      PakettiChords_vb:valuebox{
        min = 0,
        max = 16,
        value = settings.strum,
        width = PakettiChords_VALUEBOX_WIDTH,
        tooltip = "0-16: Rows mode uses row spacing, Delays mode divides 00-FF evenly",
        notifier = function(value)
          PakettiChords_progression_sequence[slot].strum = value
        end
      }
    },
    PakettiChords_vb:row{
      PakettiChords_vb:popup{
        items = PakettiChords_STRUM_MODES,
        value = settings.strum_mode,
        width = PakettiChords_TOTAL_ROW_WIDTH,
        tooltip = "Rows: notes on separate rows | Delays: notes on same row with delay column",
        notifier = function(value)
          PakettiChords_progression_sequence[slot].strum_mode = value
        end
      }
    },
    PakettiChords_vb:row{
      PakettiChords_vb:text{text = "Velocity", width = PakettiChords_LABEL_WIDTH, style = "strong", font = "bold", tooltip = "Volume: 0-127 (displays as 00-80 hex in Renoise)"},
      PakettiChords_vb:valuebox{
        min = 0,
        max = 127,
        value = settings.velocity,
        width = PakettiChords_VALUEBOX_WIDTH,
        tooltip = "Volume: 0-127 (00-7F hex)",
        notifier = function(value)
          PakettiChords_progression_sequence[slot].velocity = value
        end
      }
    },
    PakettiChords_vb:row{
      PakettiChords_vb:popup{
        items = PakettiChords_STRUM_ORDERS,
        value = settings.strum_order,
        width = PakettiChords_TOTAL_ROW_WIDTH,
        notifier = function(value)
          PakettiChords_progression_sequence[slot].strum_order = value
        end
      }
    },
    -- Extra Note 1: Index, Octave Offset, Duration
    PakettiChords_vb:text{text = "EX1", width = PakettiChords_TOTAL_ROW_WIDTH, style = "strong", tooltip = "Extra Note 1: Additional note based on chord notes, triggers immediately (not affected by strum), has independent duration"},
    PakettiChords_vb:column{
      PakettiChords_vb:row{
        PakettiChords_vb:text{text = "Index", width = 52, style = "strong", font = "bold", tooltip = "Which chord note to use: 0=Off, 1=1st note (root), 2=2nd note, 3=3rd note, 4=4th note (if exists)"},
        PakettiChords_vb:valuebox{
          min = 0,
          max = 4,
          value = settings.extra1_index,
          width = 50,
          tooltip = "Which chord note to base EX1 on: 0=Off, 1=Root, 2=2nd, 3=3rd, 4=4th. Plays immediately when chord starts, not affected by strum.",
          notifier = function(value)
            PakettiChords_progression_sequence[slot].extra1_index = value
          end
        }
      },
      PakettiChords_vb:row{
        PakettiChords_vb:text{text = "Octave", width = 52, style = "strong", font = "bold", tooltip = "Transpose EX1 by octaves: -2 = two octaves down (bass), 0 = same octave, +1 = one octave up"},
        PakettiChords_vb:valuebox{
          min = -4,
          max = 4,
          value = settings.extra1_octave,
          width = 50,
          tooltip = "Octave offset for EX1: -2=bass note, -1=one octave down, 0=same octave, +1=one octave up, etc.",
          notifier = function(value)
            PakettiChords_progression_sequence[slot].extra1_octave = value
          end
        }
      },
      PakettiChords_vb:row{
        PakettiChords_vb:text{text = "Length", width = 52, style = "strong", font = "bold", tooltip = "Independent duration for EX1 in beats: Can be shorter or longer than main chord notes"},
        PakettiChords_vb:valuebox{
          min = 0.1,
          max = 64,
          value = settings.extra1_duration,
          width = 50,
          tooltip = "EX1 duration in beats: Independent length, can overlap multiple chords. Example: 8 beats = sustained bass note.",
          notifier = function(value)
            PakettiChords_progression_sequence[slot].extra1_duration = value
          end
        }
      }
    },
    -- Extra Note 2: Index, Octave Offset, Duration
    PakettiChords_vb:text{text = "EX2", width = PakettiChords_TOTAL_ROW_WIDTH, style = "strong", tooltip = "Extra Note 2: Additional note based on chord notes, triggers immediately (not affected by strum), has independent duration"},
    PakettiChords_vb:column{
      PakettiChords_vb:row{
        PakettiChords_vb:text{text = "Index", width = 52, style = "strong", font = "bold", tooltip = "Which chord note to use: 0=Off, 1=1st note (root), 2=2nd note, 3=3rd note, 4=4th note (if exists)"},
        PakettiChords_vb:valuebox{
          min = 0,
          max = 4,
          value = settings.extra2_index,
          width = 50,
          tooltip = "Which chord note to base EX2 on: 0=Off, 1=Root, 2=2nd, 3=3rd, 4=4th. Plays immediately when chord starts, not affected by strum.",
          notifier = function(value)
            PakettiChords_progression_sequence[slot].extra2_index = value
          end
        }
      },
      PakettiChords_vb:row{
        PakettiChords_vb:text{text = "Octave", width = 52, style = "strong", font = "bold", tooltip = "Transpose EX2 by octaves: -2 = two octaves down (bass), 0 = same octave, +1 = one octave up (melody accent)"},
        PakettiChords_vb:valuebox{
          min = -4,
          max = 4,
          value = settings.extra2_octave,
          width = 50,
          tooltip = "Octave offset for EX2: -2=bass note, -1=one octave down, 0=same octave, +1=one octave up (melody), etc.",
          notifier = function(value)
            PakettiChords_progression_sequence[slot].extra2_octave = value
          end
        }
      },
      PakettiChords_vb:row{
        PakettiChords_vb:text{text = "Length", width = 52, style = "strong", font = "bold", tooltip = "Independent duration for EX2 in beats: Can be shorter (staccato) or longer than main chord notes"},
        PakettiChords_vb:valuebox{
          min = 0.1,
          max = 64,
          value = settings.extra2_duration,
          width = 50,
          tooltip = "EX2 duration in beats: Independent length. Example: 0.1 = short accent, 2 = sustained melody note.",
          notifier = function(value)
            PakettiChords_progression_sequence[slot].extra2_duration = value
          end
        }
      }
    }
  }
  
  return panel
end

-- Build slot column
function PakettiChords_BuildSlotColumn(slot)
  local slot_btn = PakettiChords_vb:button{
    text = string.format("%02d", slot),
    width = PakettiChords_TOTAL_ROW_WIDTH,
    height = 20,
    align = "center",
    notifier = function()
      PakettiChords_selected_slot = slot
      PakettiChords_UpdateUI()
    end
  }
  PakettiChords_slot_buttons[slot] = slot_btn
  
  -- Slot control buttons row (Up/Down arrows)
  local control_row = PakettiChords_vb:row{
    PakettiChords_vb:button{
      text = "▲",
      width = 52,
      height = 18,
      align = "center",
      tooltip = "Move Up (Shift+Up)",
      notifier = function()
        PakettiChords_MoveSlotUp(slot)
      end
    },
    PakettiChords_vb:button{
      text = "▼",
      width = 52,
      height = 18,
      align = "center",
      tooltip = "Move Down (Shift+Down)",
      notifier = function()
        PakettiChords_MoveSlotDown(slot)
      end
    }
  }
  
  -- Copy/Paste buttons row
  local action_row = PakettiChords_vb:row{
    PakettiChords_vb:button{
      text = "C",
      width = 52,
      height = 18,
      align = "center",
      tooltip = "Copy (Ctrl+C)",
      notifier = function()
        PakettiChords_CopySlot(slot)
      end
    },
    PakettiChords_vb:button{
      text = "P",
      width = 52,
      height = 18,
      align = "center",
      tooltip = "Paste (Ctrl+V)",
      notifier = function()
        PakettiChords_PasteSlot(slot)
      end
    }
  }
  
  local clear_btn = PakettiChords_vb:button{
    text = "Clear",
    width = PakettiChords_TOTAL_ROW_WIDTH,
    align = "center",
    notifier = function()
      PakettiChords_ClearSlot(slot)
    end
  }
  
  local audition_btn = PakettiChords_vb:button{
    text = "Audition",
    width = PakettiChords_TOTAL_ROW_WIDTH,
    align = "center",
    notifier = function()
      PakettiChords_AuditionSlot(slot)
    end
  }
  
  -- Wrap entire slot column in group
  return PakettiChords_vb:column{
    style = "group",
    margin = 3,
    
    slot_btn,
    control_row,
    action_row,
    PakettiChords_BuildSlotSettings(slot),
    PakettiChords_BuildChordButtons(slot),
    audition_btn,
    clear_btn
  }
end

-- Key handler
function PakettiChords_KeyHandler(dialog, key)
  if key and key.name == "escape" then
    PakettiChords_Stop()
    return nil
  elseif key and key.name == "space" then
    if PakettiChords_is_playing then
      PakettiChords_Stop()
    else
      PakettiChords_Play()
    end
    return nil
  elseif key and key.modifiers == "control" and key.name == "c" then
    if PakettiChords_selected_slot then
      PakettiChords_CopySlot(PakettiChords_selected_slot)
    end
    return nil
  elseif key and key.modifiers == "control" and key.name == "v" then
    if PakettiChords_selected_slot then
      PakettiChords_PasteSlot(PakettiChords_selected_slot)
    end
    return nil
  elseif key and key.modifiers == "control" and key.name == "w" then
    PakettiChords_WriteToPattern()
    return nil
  elseif key and key.modifiers == "shift" and key.name == "up" then
    if PakettiChords_selected_slot then
      PakettiChords_MoveSlotUp(PakettiChords_selected_slot)
    end
    return nil
  elseif key and key.modifiers == "shift" and key.name == "down" then
    if PakettiChords_selected_slot then
      PakettiChords_MoveSlotDown(PakettiChords_selected_slot)
    end
    return nil
  elseif key and key.name == "a" and key.modifiers == "" then
    if PakettiChords_selected_slot then
      PakettiChords_AuditionSlot(PakettiChords_selected_slot)
    end
    return nil
  end
  
  -- Fallback to global handler
  return my_keyhandler_func(dialog, key)
end

-- Create dialog
function PakettiChords_CreateDialog()
  if PakettiChords_dialog and PakettiChords_dialog.visible then
    PakettiChords_dialog:close()
    PakettiChords_dialog = nil
  end
  
  PakettiChords_vb = renoise.ViewBuilder()
  
  -- Build all slot columns
  local slot_columns = {}
  for slot = 1, PakettiChords_MAX_SLOTS do
    table.insert(slot_columns, PakettiChords_BuildSlotColumn(slot))
  end
  
  -- Key selector
  local key_items = {}
  for _, name in ipairs(PakettiChords_NOTE_NAMES) do
    table.insert(key_items, name)
  end
  
  PakettiChords_key_popup = PakettiChords_vb:popup{
    items = key_items,
    value = 1,
    width = 60
  }
  
  -- Settings controls
  PakettiChords_base_octave_value = PakettiChords_vb:valuebox{
    min = 0,
    max = 8,
    value = 4,
    width = 60
  }
  
  PakettiChords_chord_interval_value = PakettiChords_vb:valuebox{
    min = 0.25,
    max = 64,
    value = 1,
    width = 60
  }
  
  PakettiChords_instrument_number_value = PakettiChords_vb:valuebox{
    min = 1,
    max = 255,
    value = renoise.song().selected_instrument_index,
    width = 60
  }
  
  PakettiChords_repeat_checkbox = PakettiChords_vb:checkbox{
    value = false
  }
  
  -- Preset selector
  local preset_items = {"<Select>"}
  for _, preset in ipairs(PakettiChords_PRESETS) do
    table.insert(preset_items, preset.name)
  end
  
  local preset_popup = PakettiChords_vb:popup{
    items = preset_items,
    value = 1, -- Start with <Select>
    width = 200,
    notifier = function(index)
      if index > 1 then
        PakettiChords_LoadPreset(index - 1) -- Adjust for <Select> offset
      end
    end
  }
  
  PakettiChords_info_text = PakettiChords_vb:text{
    text = "Click slot number to select. A=Audition, Ctrl+C/V=Copy/Paste, Shift+Up/Down=Move. Extended chords available!",
    width = 750,
    style = "normal"
  }
  
  PakettiChords_play_button = PakettiChords_vb:button{
    text = "Play (Space)",
    width = 150,
    notifier = function()
      if PakettiChords_is_playing then
        PakettiChords_Stop()
      else
        PakettiChords_Play()
      end
    end
  }
  
  PakettiChords_stop_button = PakettiChords_vb:button{
    text = "Stop (Esc)",
    width = 100,
    active = false,
    notifier = PakettiChords_Stop
  }
  
  local content = PakettiChords_vb:column{
    -- Global settings section
    PakettiChords_vb:row{
      PakettiChords_vb:column{
        PakettiChords_vb:text{text = "Key", style = "strong", font = "bold"},
        PakettiChords_key_popup
      },
      PakettiChords_vb:space{width = 10},
      PakettiChords_vb:column{
        PakettiChords_vb:text{text = "Base Octave", style = "strong", font = "bold"},
        PakettiChords_base_octave_value
      },
      PakettiChords_vb:space{width = 10},
      PakettiChords_vb:column{
        PakettiChords_vb:text{text = "Interval (beats)", style = "strong", font = "bold"},
        PakettiChords_chord_interval_value
      },
      PakettiChords_vb:space{width = 10},
      PakettiChords_vb:column{
        PakettiChords_vb:text{text = "Instrument", style = "strong", font = "bold"},
        PakettiChords_instrument_number_value
      },
      PakettiChords_vb:space{width = 10},
      PakettiChords_vb:column{
        PakettiChords_vb:text{text = "Preset", style = "strong", font = "bold"},
        preset_popup
      }
    },
    PakettiChords_vb:space{height = 10},
    
    -- Progression editor
    PakettiChords_vb:text{text = "Progression Editor - 13 chord types, per-slot velocity + settings", font = "bold", style = "strong"},
    PakettiChords_vb:row{
      unpack(slot_columns)
    },
    PakettiChords_vb:space{height = 10},
    
    -- Info and controls
    PakettiChords_info_text,
    PakettiChords_vb:space{height = 5},
    PakettiChords_vb:row{
      PakettiChords_play_button,
      PakettiChords_vb:space{width = 5},
      PakettiChords_stop_button,
      PakettiChords_vb:space{width = 10},
      PakettiChords_vb:button{
        text = "Write to Pattern (Ctrl+W)",
        width = 150,
        notifier = PakettiChords_WriteToPattern
      },
      PakettiChords_vb:space{width = 10},
      PakettiChords_vb:button{
        text = "Clear All",
        width = 80,
        notifier = PakettiChords_Clear
      },
      PakettiChords_vb:space{width = 10},
      PakettiChords_repeat_checkbox,
      PakettiChords_vb:text{text = "Repeat", style = "normal"}
    }
  }
  
  PakettiChords_dialog = renoise.app():show_custom_dialog("Paketti Chords - Progression Player (C) sEptIQ - quick HTML->LUA conversion by esaruoho", content, PakettiChords_KeyHandler)
  PakettiChords_UpdateUI()
  
  -- Ensure Renoise keeps focus for keyboard
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  renoise.app():show_status("PakettiChords: 13 chord types, presets, copy/paste, audition, per-slot settings. Ctrl+W to write.")
end

-- Toggle dialog
function PakettiChords_Toggle()
  if PakettiChords_dialog and PakettiChords_dialog.visible then
    PakettiChords_Stop()
    PakettiChords_dialog:close()
    PakettiChords_dialog = nil
  else
    PakettiChords_CreateDialog()
  end
end

-- Only register tool if API 6.2+ (dialog uses .color and tooltip properties that don't exist in older versions)
if renoise.API_VERSION >= 6.2 then
  -- Initialize on load (safe - no renoise.song() calls, just creates empty tables)
  PakettiChords_Initialize()
  
  renoise.tool():add_keybinding{name = "Global:Paketti:Paketti Chords - Progression Player...", invoke = PakettiChords_Toggle}
  renoise.tool():add_midi_mapping{name = "Paketti:Paketti Chords - Progression Player", invoke = PakettiChords_Toggle}
  renoise.tool():add_menu_entry{name = "Main Menu:Tools:Chords - Progression Player...", invoke = PakettiChords_Toggle}
end
