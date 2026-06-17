-- PakettiMusicMouse.lua
-- A faithful Renoise/Paketti port of Laurie Spiegel's "Music Mouse - An Intelligent Instrument" (1986).
-- 40th anniversary tribute (1986-2026). Built from scratch on Renoise's Canvas API.
--
-- Model (from the MacMM manual + Spiegel's scale/voiceStep/pattern tables):
--   * 4 voices. Mouse X drives the treble axis, mouse Y drives the bass axis; the software
--     supplies the other voices. Position is quantized to the current harmony mode so you
--     "can't play wrong notes".
--   * Harmony modes (q w e r t y, decreasing resolution): chromatic / octatonic / midEastern /
--     diatonic(default) / pentatonic / quartal. tab = (near-)microtonal, internal sound only.
--   * Transposition z/x/c (+shift = change interval; cmd = quiet, no replay).
--   * Patterning a + 0-9 : 10 melodic contour arrays added on top, advanced by the tempo timer.
--   * Voicing s/d/f/g : pattern symmetry / mouse-line direction / chord-melody vs voice-pairs / grouping.
--   * Rhythmic treatments cmd-1..4 : Chord / Arpeggiate / Line / Improvise.
--   * Articulation / and shift-/ ; Loudness < > ; Muting shift-1..4, ~ ; dual Tempo - + [ ] \.
--   * Sound: plays the SELECTED instrument (4-voice trigger). u/i/o switch the classic
--     triangle/square/saw single-cycle waveforms; a button creates the classic MM instrument.
--
-- FEATURE-CARD >> features/music-mouse.feature

--------------------------------------------------------------------------------
-- State (module-level; never call renoise.song() at file-load time)
--------------------------------------------------------------------------------

local vb = renoise.ViewBuilder()
local dialog = nil
local mm_canvas = nil
local mm_pat_canvas = nil   -- the melodic-pattern editor canvas
local mm_update_panel       -- forward decl (assigned in the panel section)
local mm_record_write       -- forward decl (assigned in the recorder section)

-- harmony scale tables, transcribed from Spiegel's running implementation (intervals are the
-- repeating step pattern of the scale; voiceSteps give the scale-degree offsets of the two
-- software-supplied voices; centerNote anchors degree 0).
-- Renoise note values: 48 = C-4, A-4 (57) = 440 Hz. centerNote octave5/pc0 -> Renoise note 60.
local MM_SCALES = {
  chromatic  = { intervals = {1},                 vs3 = 7,  vs4 = 14, center = 60, label = "Chromatic" },
  octatonic  = { intervals = {1,2},               vs3 = 4,  vs4 = 6,  center = 55, label = "Octatonic" },
  midEastern = { intervals = {3,1,1,3,1,2,1},     vs3 = 4,  vs4 = 9,  center = 60, label = "Middle Eastern" },
  diatonic   = { intervals = {2,2,1,2,2,2,1},     vs3 = 4,  vs4 = 9,  center = 60, label = "Diatonic" },
  pentatonic = { intervals = {2,3,2,2,3},         vs3 = 3,  vs4 = 7,  center = 60, label = "Pentatonic" },
  quartal    = { intervals = {5},                 vs3 = 1,  vs4 = 2,  center = 60, label = "Quartal" },
}
-- q w e r t y -> decreasing resolution (most pitches per octave first)
local MM_SCALE_ORDER = { "chromatic", "octatonic", "midEastern", "diatonic", "pentatonic", "quartal" }

-- The 10 melodic contour patterns (keys 1-9,0). Values are scale-degree offsets added to the base.
local MM_PATTERNS = {
  {0,4,5,0,4,3,4,5,0,4},                       -- 1
  {0,2,4,7,4,2},                               -- 2
  {0,1,2,3,4,3,2,1},                           -- 3
  {0,1,2,3,4,5,6,7,6,5,4,3,2,1},               -- 4
  {0,4,7,11,7,4,7,4},                          -- 5
  {0,1,0,1,2,1,2,3,2,3,4,3,2,3,2,1},           -- 6
  {0,2,3,4,5,6,5,4,3,2},                       -- 7
  {0,7,1,6,2,5,3,4,5,2,4,5,2,6,1,7},           -- 8
  {0,1,4,1,0,4,0,4},                           -- 9
  {0,0,0,0,7,0,0,2,1,2,4,3,4,2,1,2},           -- 0 (slot 10)
}

-- pristine copies of Spiegel's original contours, for the editor's Reset button
local MM_PATTERNS_ORIG = {}
for i, p in ipairs(MM_PATTERNS) do
  local c = {}
  for j, v in ipairs(p) do c[j] = v end
  MM_PATTERNS_ORIG[i] = c
end
local MM_PAT_MAX = 14    -- max scale-degree offset a pattern step can hold
local MM_PAT_MAXLEN = 16 -- max pattern length

local TREATMENT_NAMES = { "Chord", "Arpeggiate", "Line", "Improvise" }

-- Live performance state
local mm = {
  scale_key   = "diatonic",   -- current harmony mode
  transpose   = 0,            -- semitones
  interval    = 1,            -- interval of transposition (semitones per z/x press)

  pattern_on  = false,
  pattern_idx = 6,            -- selected pattern (1..10); MM default is 6
  pat_step    = 1,
  pat_target  = "all",        -- which voices the contour ornaments: "all" / "melody" / "bass"

  format_pairs = false,       -- f: false = chord-melody, true = voice-pairs
  mouse_contrary = false,     -- d: parallel/contrary for mouse lines
  pattern_contrary = false,   -- s: parallel/contrary for the added pattern
  grouping    = false,        -- g: all 4 voices sound together vs only changed ones

  staccato    = false,        -- '/' : true = staccato, false = legato (MM default = Full Legato)
  half_legato = false,        -- shift-/ : legato sub-mode
  loudness    = 0.8,          -- 0..1 -> note velocity
  sound_on    = true,         -- spacebar

  treatment   = 1,            -- 1 Chord, 2 Arpeggiate, 3 Line, 4 Improvise
  num_voices  = 4,            -- 4 = classic Music Mouse; 5..9 = richer chords (extra X-chord tones)
  mute        = { false, false, false, false, false, false, false, false, false },

  tempo_basic = 100,          -- quarter-notes/min (a MM beat = a 16th, so beats/min = tempo*4)
  tempo_alt   = 200,
  tempo_use_alt = false,
  sync_bpm    = true,         -- pattern player locks to the song's BPM/LPB (read live)

  waveform    = "Square",     -- current single-cycle waveform
  bell        = true,         -- true = Bell (non-looping decay, default), false = Sustain (loop)
  dark        = false,        -- theme: false = authentic light Music Mouse, true = dark

  -- runtime
  mouse_active = true,        -- delete key disconnects
  key_probe   = false,        -- key-name diagnostic logger (off)
  frozen      = false,        -- SPACE: pause sound + mouse-follow + auto-play (keys still drive it)
  keyjazz     = false,        -- punch mode: mouse aims silently; i/o/p triggers (and records)
  record      = false,        -- right-shift: imprint current notes to the pattern at the playhead
  held        = {},           -- ENTER-locked notes that keep ringing (compose buffer)
  seeds       = {},           -- gravitation seeds: click-dropped attractor positions {dx,dy}
  gravity_play = false,       -- when on, the timer steps through the seeds in recorded order
  gravity_index = 0,          -- current seed in the gravity-play sequence
  mx = 0.5, my = 0.5,         -- normalized mouse position in play area (0..1)
  deg_x = 0, deg_y = 0,       -- current quantized scale-degree on each axis
  axis  = {},                 -- ordered list of degrees whose note is in playable range
  voice_note = {}, -- currently sounding Renoise note per voice (max MM_MAX_VOICES)
  last_notes = {}, -- last computed target notes
  seq_i = 0,                  -- arp/line/improvise voice index
  random_seed = 12345,        -- deterministic pseudo-random for improvise
  timer_running = false,
}

-- persist performance settings (tempo + loudness) across close/reopen and tool reloads
local function mm_load_prefs()
  if not preferences or not preferences.pakettiMusicMouseTempoBasic then return end
  mm.tempo_basic = preferences.pakettiMusicMouseTempoBasic.value or mm.tempo_basic
  mm.tempo_alt   = preferences.pakettiMusicMouseTempoAlt.value or mm.tempo_alt
  mm.sync_bpm    = preferences.pakettiMusicMouseSyncBPM.value
  local ld = preferences.pakettiMusicMouseLoudness.value
  if not ld or ld < 1 then ld = 102 end   -- a stored 0/empty = silent = fall back to an audible default
  mm.loudness    = math.max(0, math.min(1, ld / 127))
  -- restore gravitation seeds (the diamonds stay across close/reopen + reloads)
  mm.seeds = {}
  local str = preferences.pakettiMusicMouseSeeds.value or ""
  for pair in str:gmatch("[^;]+") do
    local dx, dy = pair:match("(-?%d+):(-?%d+)")
    if dx and dy then mm.seeds[#mm.seeds + 1] = { dx = tonumber(dx), dy = tonumber(dy) } end
  end
end

local function mm_save_prefs()
  if not preferences or not preferences.pakettiMusicMouseTempoBasic then return end
  preferences.pakettiMusicMouseTempoBasic.value = mm.tempo_basic
  preferences.pakettiMusicMouseTempoAlt.value   = mm.tempo_alt
  preferences.pakettiMusicMouseSyncBPM.value    = mm.sync_bpm
  preferences.pakettiMusicMouseLoudness.value   = math.floor(mm.loudness * 127 + 0.5)
  local parts = {}
  for _, s in ipairs(mm.seeds) do parts[#parts + 1] = s.dx .. ":" .. s.dy end
  preferences.pakettiMusicMouseSeeds.value = table.concat(parts, ";")
  preferences:save_as("preferences.xml")
end

-- canvas geometry
local MM_W, MM_H = 660, 660
local EDGE = 40                       -- thickness of the edge piano keyboards
local PLAY_X0, PLAY_Y0 = EDGE, EDGE
local PLAY_X1, PLAY_Y1 = MM_W - EDGE, MM_H - EDGE

-- chromatic display range (the piano keyboards span this; input is quantized to the scale within it)
local DISPLAY_LO, DISPLAY_HI = 24, 96         -- C-1 .. C-7 (Renoise note values), 6 octaves
local DISPLAY_SPAN = DISPLAY_HI - DISPLAY_LO

local function mm_is_black(note)
  local pc = note % 12
  return pc == 1 or pc == 3 or pc == 6 or pc == 8 or pc == 10
end

-- white-key layout over the display range (built once)
local mm_white_notes = {}     -- ordered list of white-key notes in range
local mm_white_index = {}     -- note -> 0-based white index
local function mm_build_keyboard_layout()
  mm_white_notes = {}
  mm_white_index = {}
  for nn = DISPLAY_LO, DISPLAY_HI do
    if not mm_is_black(nn) then
      mm_white_index[nn] = #mm_white_notes
      mm_white_notes[#mm_white_notes + 1] = nn
    end
  end
end

-- note -> fraction 0..1 along the keyboard axis (white-key spacing; black keys sit between)
local function mm_note_frac(note)
  if note < DISPLAY_LO then note = DISPLAY_LO end
  if note > DISPLAY_HI then note = DISPLAY_HI end
  local nw = #mm_white_notes
  if nw < 2 then return 0.5 end
  if not mm_is_black(note) then
    return (mm_white_index[note] + 0.5) / nw
  else
    local below = mm_white_index[note - 1] or 0   -- white key just below the accidental
    return (below + 1) / nw
  end
end

-- theme (light = authentic Music Mouse black-on-white; dark = Renoise-friendly)
local function mm_theme()
  if mm and mm.dark then
    return {
      surround = { 18, 20, 28, 255 }, play = { 26, 28, 40, 255 }, dot = { 72, 80, 104, 255 },
      white = { 206, 210, 224, 255 }, black = { 8, 8, 14, 255 }, sep = { 44, 48, 64, 255 },
      frame = { 96, 106, 136, 255 }, cursor = { 130, 205, 255, 255 }, dot_hi = { 255, 255, 255, 255 },
      key_hi = { 255, 120, 70, 255 },
    }
  end
  return {
    surround = { 232, 232, 236, 255 }, play = { 252, 252, 255, 255 }, dot = { 150, 156, 172, 255 },
    white = { 252, 252, 255, 255 }, black = { 14, 14, 20, 255 }, sep = { 120, 124, 138, 255 },
    frame = { 36, 36, 46, 255 }, cursor = { 28, 64, 200, 255 }, dot_hi = { 255, 255, 255, 255 },
    key_hi = { 255, 90, 50, 255 },
  }
end

--------------------------------------------------------------------------------
-- Pitch space
--------------------------------------------------------------------------------

-- degree (can be negative) -> Renoise note value, WITHOUT transposition (axis is stable)
local function mm_degree_note_base(degree)
  local sc = MM_SCALES[mm.scale_key]
  local iv = sc.intervals
  local n = #iv
  local note = sc.center
  if degree > 0 then
    for k = 1, degree do
      local idx = ((k - 1) % n) + 1
      note = note + iv[idx]
    end
  elseif degree < 0 then
    for k = 1, -degree do
      local idx = ((n - 1 - ((k - 1) % n)) % n) + 1
      note = note - iv[idx]
    end
  end
  return note
end

-- degree -> playable Renoise note (0..119) with transposition applied
local function mm_degree_note(degree)
  local note = mm_degree_note_base(degree) + mm.transpose
  if note < 0 then note = 0 end
  if note > 119 then note = 119 end
  return note
end

-- Rebuild the ordered scale-degree list (those whose transposed note sits in the display range)
local function mm_rebuild_axis()
  mm_build_keyboard_layout()
  mm.axis = {}
  for d = -120, 120 do
    local note = mm_degree_note_base(d) + mm.transpose
    if note >= DISPLAY_LO and note <= DISPLAY_HI then
      mm.axis[#mm.axis + 1] = d
    end
  end
  if #mm.axis == 0 then mm.axis = { 0 } end
end

-- normalized fraction (0..1) -> nearest scale degree (chromatic target within the display range)
local function mm_frac_to_degree(frac)
  if frac < 0 then frac = 0 end
  if frac > 1 then frac = 1 end
  local target = DISPLAY_LO + frac * DISPLAY_SPAN
  local best_d, best_dist = mm.axis[1], math.huge
  for _, d in ipairs(mm.axis) do
    local dist = math.abs(mm_degree_note(d) - target)
    if dist < best_dist then best_dist = dist; best_d = d end
  end
  return best_d
end

-- degree -> normalized fraction (positions the cursor on the real key)
local function mm_degree_to_frac(degree)
  return mm_note_frac(mm_degree_note(degree))
end

--------------------------------------------------------------------------------
-- Voice computation
--------------------------------------------------------------------------------

-- Returns the 4 target Renoise notes for the current state.
-- voice layout:
--   chord-melody (default): v1,v2,v3 = 3-note chord on X axis (treble); v4 = melody on Y axis (bass)
--   voice-pairs:            v1,v2 = pair on X axis;  v3,v4 = pair on Y axis
-- X-axis and Y-axis voice degrees (before the pattern contour). mm.num_voices = 4 is classic
-- Music Mouse; 5 and 6 add richer chord tones (extra thirds stacked on the X-axis chord).
local function mm_axis_degrees()
  local sc = MM_SCALES[mm.scale_key]
  local dx, dy = mm.deg_x, mm.deg_y
  local sign = mm.mouse_contrary and -1 or 1
  local n = mm.num_voices
  -- ascending chord-tone offsets (scale degrees): 0, vs3, vs4, vs4+2, vs4+4, ... (a third per extra)
  local offs = { 0, sc.vs3, sc.vs4 }
  while #offs < n do offs[#offs + 1] = sc.vs4 + 2 * (#offs - 2) end
  local xd, yd = {}, {}
  if not mm.format_pairs then
    -- chord-melody: solo melody on Y; the chord (n-1 tones) on X
    for i = 1, n - 1 do xd[#xd + 1] = dx + offs[i] * sign end
    yd[1] = dy
  else
    -- voice-pairs: X pair (dx, dx+vs3), Y pair (dy, dy+vs4); extra tones stack on X
    xd[1] = dx
    if n >= 2 then xd[#xd + 1] = dx + sc.vs3 * sign end
    yd[1] = dy
    if n >= 4 then yd[#yd + 1] = dy + sc.vs4 * sign end
    for vi = 5, n do xd[#xd + 1] = dx + (sc.vs4 + 2 * (vi - 4)) * sign end
  end
  return xd, yd
end

-- Returns the target Renoise notes for the current state (one per active voice).
-- Voice order is X-axis voices first, then Y-axis voices (so 4-voice layout is unchanged:
-- v1..v3 = X chord, v4 = Y melody).
local function mm_compute_voices()
  local pat = 0
  if mm.pattern_on then
    local arr = MM_PATTERNS[mm.pattern_idx]
    local step = ((mm.pat_step - 1) % #arr) + 1
    pat = arr[step]
    if mm.pattern_contrary then pat = -pat end
  end

  local xd, yd = mm_axis_degrees()
  local base = {}
  for _, d in ipairs(xd) do base[#base + 1] = d end
  for _, d in ipairs(yd) do base[#base + 1] = d end
  local nv = #base

  -- which voices the pattern contour ornaments (target = all / melody-top / bass-bottom)
  local apply = {}
  for v = 1, nv do apply[v] = true end
  if mm.pattern_on and mm.pat_target ~= "all" then
    for v = 1, nv do apply[v] = false end
    local pick, best = 1, base[1]
    for v = 2, nv do
      if mm.pat_target == "melody" and base[v] > best then best = base[v]; pick = v end
      if mm.pat_target == "bass" and base[v] < best then best = base[v]; pick = v end
    end
    apply[pick] = true
  end

  local notes = {}
  for v = 1, nv do
    notes[v] = mm_degree_note(base[v] + (apply[v] and pat or 0))
  end
  return notes
end

--------------------------------------------------------------------------------
-- Sound engine (4 voice slots on the selected instrument)
--------------------------------------------------------------------------------

local function mm_inst_track()
  local song = renoise.song()
  return song.selected_instrument_index, song.selected_track_index
end

local function mm_note_off(voice)
  local n = mm.voice_note[voice]
  if n == nil then return end
  local song = renoise.song()
  local ii, ti = mm_inst_track()
  pcall(function() song:trigger_instrument_note_off(ii, ti, { n }) end)
  mm.voice_note[voice] = nil
end

local function mm_note_on(voice, note)
  if note == nil then return end
  if mm.mute[voice] then return end
  if not mm.sound_on then return end
  local song = renoise.song()
  local ii, ti = mm_inst_track()
  -- legato: release prior note in this voice only as the new one sounds
  if mm.voice_note[voice] ~= nil and mm.voice_note[voice] ~= note then
    pcall(function() song:trigger_instrument_note_off(ii, ti, { mm.voice_note[voice] }) end)
  end
  local vel = mm.loudness
  if vel <= 0 then vel = 0.01 end
  if vel > 1 then vel = 1 end
  local ok = pcall(function() song:trigger_instrument_note_on(ii, ti, note, vel) end)
  if ok then mm.voice_note[voice] = note end
end

-- release all ENTER-locked (held) notes
local function mm_release_held()
  if #mm.held == 0 then return end
  local song = renoise.song()
  local ii, ti = mm_inst_track()
  for _, n in ipairs(mm.held) do
    pcall(function() song:trigger_instrument_note_off(ii, ti, { n }) end)
  end
  mm.held = {}
end

local MM_MAX_VOICES = 9

local function mm_all_notes_off()
  for v = 1, MM_MAX_VOICES do mm_note_off(v) end
  mm_release_held()
end

-- ENTER: lock the currently sounding voices so they keep ringing; the mouse then plays fresh ones
local function mm_lock_voices()
  local locked = 0
  for v = 1, MM_MAX_VOICES do
    local n = mm.voice_note[v]
    if n ~= nil then
      mm.held[#mm.held + 1] = n   -- keep it ringing; detach so future plays don't release it
      mm.voice_note[v] = nil
      locked = locked + 1
    end
  end
  return locked
end

-- Play the full set of target notes honoring grouping/staccato. Voices beyond the active count
-- (or muted) are released, so dropping from 6 to 4 voices silences the extras.
local function mm_play_chord(notes)
  for v = 1, MM_MAX_VOICES do
    if v > #notes or mm.mute[v] then
      mm_note_off(v)
    else
      local newn = notes[v]
      if mm.grouping then
        mm_note_on(v, newn)                                   -- grouping: retrigger every voice
      else
        if newn ~= mm.voice_note[v] then mm_note_on(v, newn) end -- only retrigger changed voices
      end
    end
  end
  mm.last_notes = notes
  if mm_record_write then
    local rl = {}
    for v = 1, #notes do if not mm.mute[v] then rl[#rl + 1] = notes[v] end end
    mm_record_write(rl)
  end
  if mm.staccato then
    for v = 1, MM_MAX_VOICES do mm_note_off(v) end   -- staccato: release immediately
  end
end

-- Play a single voice (used by arpeggiate / line / improvise)
local function mm_play_one(voice, note)
  if mm.mute[voice] then return end
  mm_note_on(voice, note)
  if mm_record_write then mm_record_write({ note }) end
  if mm.staccato then mm_note_off(voice) end
end

-- Force-retrigger: re-strike the current chord regardless of grouping (so changing the
-- sound/waveform/mode re-articulates the same notes — keeps Bell as Bell, re-hits the sample).
-- In Arpeggiate/Line/Improvise modes a "re-strike" restarts the sequence instead of a block chord.
local function mm_retrigger()
  local notes = mm_compute_voices()
  mm.last_notes = notes
  if mm.treatment ~= 1 then
    mm.seq_i = 0   -- restart the arpeggio/line/improvise from the top with the new sound
    return
  end
  for v = 1, MM_MAX_VOICES do
    if mm.voice_note[v] then mm_note_off(v) end
  end
  for v = 1, #notes do
    if not mm.mute[v] then mm_note_on(v, notes[v]) end
  end
  if mm_record_write then
    local rl = {}
    for v = 1, #notes do if not mm.mute[v] then rl[#rl + 1] = notes[v] end end
    mm_record_write(rl)
  end
  if mm.staccato then for v = 1, MM_MAX_VOICES do mm_note_off(v) end end
end

-- Arpeggio "button": write the current 4-voice arpeggio into consecutive pattern lines at the
-- edit cursor (selected track), then advance the cursor so repeated presses build a sequence.
local function mm_stamp_arpeggio()
  local song = renoise.song()
  local ti = song.selected_track_index
  local track = song.tracks[ti]
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Music Mouse: select a sequencer track to write the arpeggio")
    return
  end
  local notes = mm_compute_voices()
  local patt = song.selected_pattern
  local nlines = patt.number_of_lines
  local ptrack = patt:track(ti)
  local instr0 = song.selected_instrument_index - 1
  local vel = math.max(1, math.min(127, math.floor(mm.loudness * 127 + 0.5)))
  if track.visible_note_columns < 1 then track.visible_note_columns = 1 end
  local start_line = song.selected_line_index
  local written = 0
  for v = 1, #notes do
    if not mm.mute[v] and notes[v] then
      local line = start_line + written
      if line <= nlines then
        local col = ptrack:line(line):note_column(1)
        col.note_value = notes[v]
        col.instrument_value = instr0
        col.volume_value = vel       -- write the picked loudness as the note volume
        written = written + 1
      end
    end
  end
  if written > 0 then
    song.selected_line_index = math.min(nlines, start_line + written)
  end
  renoise.app():show_status("Music Mouse: arpeggio written to pattern (" .. written .. " notes)")
end

--------------------------------------------------------------------------------
-- Record to Pattern: while armed + Renoise is playing, stamp the currently-sounding
-- notes onto the selected track at the playhead line. Captures both mouse- and
-- key-driven chords (works while frozen — keys still sound), so you can freeze the
-- mouse, drive harmony with q/e, and imprint it straight into the pattern.
--------------------------------------------------------------------------------

-- write a list of notes to the selected track at a given pattern line
local function mm_stamp_to_line(seq, line, notelist)
  local song = renoise.song()
  local ti = song.selected_track_index
  local track = song.tracks[ti]
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then return end
  local seen, notes = {}, {}
  for _, n in ipairs(notelist) do
    if n and not seen[n] then seen[n] = true; notes[#notes + 1] = n end
  end
  if #notes == 0 then return end
  local need = math.min(12, #notes)
  if track.visible_note_columns < need then track.visible_note_columns = need end
  local patt_idx = song.sequencer.pattern_sequence[seq]
  if not patt_idx then return end
  local pline = song.patterns[patt_idx]:track(ti):line(line)
  local instr0 = song.selected_instrument_index - 1
  local vel = math.max(1, math.min(127, math.floor(mm.loudness * 127 + 0.5)))
  for c = 1, need do
    local col = pline:note_column(c)
    col.note_value = notes[c]
    col.instrument_value = instr0
    col.volume_value = vel       -- write the picked loudness as the note volume
  end
end

-- WRITE-ON-TRIGGER: called from the note-trigger points (timer beat, key press, mouse step).
-- Writes the just-triggered notes to the playhead line — obeys the trigger/timer, so sustained
-- chords are NOT re-stamped on every Renoise line.
mm_record_write = function(notelist)
  if not mm.record then return end
  local song = renoise.song()
  if not song or not song.transport.playing then return end
  local pos = song.transport.playback_pos
  pcall(function() mm_stamp_to_line(pos.sequence, pos.line, notelist) end)
end

-- Right-Shift / checkbox: toggle the first-class Paketti recording context.
-- ON  -> show Pattern Editor, Edit Mode on, Follow Pattern on, start playback, arm imprint.
-- OFF -> stop imprinting (leaves your transport/edit/follow as they are).
local function mm_set_record(on)
  mm.record = on
  local song = renoise.song()
  if on then
    pcall(function()
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end)
    if song then
      song.transport.edit_mode = true
      song.transport.follow_player = true
      if not song.transport.playing then song.transport.playing = true end
    end
  else
    if song then
      song.transport.edit_mode = false
      song.transport.follow_player = false
    end
  end
  if mm_canvas then mm_canvas:update() end
  if mm_update_panel then mm_update_panel() end
  renoise.app():show_status("Music Mouse: Record to Pattern " ..
    (on and "ON — playing + edit mode + follow + pattern editor" or "OFF (imprint stopped)"))
end

--------------------------------------------------------------------------------
-- Tempo timer: patterning + rhythmic treatments
--------------------------------------------------------------------------------

local MM_TICK_MS = 16       -- fixed clock; beat length is derived live so BPM changes are followed
local mm_beat_accum = 0

-- duration (ms) of one Music Mouse beat. When Sync-to-BPM is on, this is one pattern LINE at
-- the song's current BPM/LPB, so the pattern player locks to Renoise tempo (and follows changes).
local function mm_beat_ms()
  if mm.sync_bpm then
    local song = renoise.song()
    if song then
      local bpm = song.transport.bpm
      local lpb = song.transport.lpb
      if bpm and bpm > 0 and lpb and lpb > 0 then
        return 60000 / (bpm * lpb)
      end
    end
  end
  local t = mm.tempo_use_alt and mm.tempo_alt or mm.tempo_basic
  if t < 20 then t = 20 end
  return 60000 / (t * 4)   -- free-running fallback: a MM beat = a 16th
end

-- deterministic pseudo-random 0..1 (avoid math.random for reproducibility per the workflow rules)
local function mm_rand()
  mm.random_seed = (mm.random_seed * 1103515245 + 12345) % 2147483648
  return mm.random_seed / 2147483648
end

local mm_timer_fn  -- forward declaration

local function mm_tick()
  if not dialog or not dialog.visible then return end
  if mm.frozen or not mm.sound_on then mm_beat_accum = 0; return end

  -- accumulate real time; fire a beat when enough has passed (beat length read live from BPM)
  mm_beat_accum = mm_beat_accum + MM_TICK_MS
  local beat = mm_beat_ms()
  -- arpeggiate subdivides by 4, but Gravity Play always steps at the base (BPM-locked) beat
  if mm.treatment == 2 and not mm.gravity_play then beat = beat / 4 end
  if beat < 8 then beat = 8 end
  if mm_beat_accum < beat then return end
  mm_beat_accum = mm_beat_accum - beat
  if mm_beat_accum > beat * 4 then mm_beat_accum = 0 end   -- clamp runaway

  -- GRAVITY PLAY: step through the dropped seeds in recorded order, one chord per beat
  if mm.gravity_play and #mm.seeds > 0 then
    mm.gravity_index = (mm.gravity_index % #mm.seeds) + 1
    local s = mm.seeds[mm.gravity_index]
    mm.deg_x = s.dx; mm.deg_y = s.dy
    mm_play_chord(mm_compute_voices())
    if mm_canvas then mm_canvas:update() end
    return
  end

  if mm.pattern_on then mm.pat_step = mm.pat_step + 1 end
  local notes = mm_compute_voices()

  if mm.treatment == 1 then
    if mm.pattern_on then mm_play_chord(notes) end   -- chord: timer only sounds when patterning
  elseif mm.treatment == 2 or mm.treatment == 3 then
    mm.seq_i = (mm.seq_i % #notes) + 1
    mm_play_one(mm.seq_i, notes[mm.seq_i])
  elseif mm.treatment == 4 then
    for v = 1, #notes do
      if mm_rand() < 0.45 then mm_play_one(v, notes[v]) end
    end
  end

  if mm_canvas then mm_canvas:update() end
  if mm.pattern_on and mm_pat_canvas then mm_pat_canvas:update() end
end

mm_timer_fn = mm_tick

local function mm_start_timer()
  if mm.timer_running then return end
  if not renoise.tool():has_timer(mm_timer_fn) then
    renoise.tool():add_timer(mm_timer_fn, MM_TICK_MS)
  end
  mm.timer_running = true
end

local function mm_stop_timer()
  if renoise.tool():has_timer(mm_timer_fn) then
    renoise.tool():remove_timer(mm_timer_fn)
  end
  mm.timer_running = false
end

local function mm_restart_timer()
  mm_beat_accum = 0
  mm_stop_timer()
  mm_start_timer()
end

--------------------------------------------------------------------------------
-- Mouse interaction
--------------------------------------------------------------------------------

local MM_SEED_PULL = 2   -- gravitation radius (scale-degrees) around a seed — wide enough to feel the magnet

-- snap the current degrees toward a nearby seed (the "gravity well")
local function mm_apply_gravitation()
  for _, s in ipairs(mm.seeds) do
    if math.abs(mm.deg_x - s.dx) <= MM_SEED_PULL and math.abs(mm.deg_y - s.dy) <= MM_SEED_PULL then
      mm.deg_x = s.dx; mm.deg_y = s.dy
      return
    end
  end
end

local function mm_update_from_mouse()
  if mm.frozen or not mm.mouse_active then return end   -- SPACE pause: mouse no longer follows
  local fx = (mm.mx)              -- 0..1 left->right (treble up to the right)
  local fy = (1 - mm.my)          -- invert: top of canvas = high pitch
  mm.deg_x = mm_frac_to_degree(fx)
  mm.deg_y = mm_frac_to_degree(fy)
  -- (no auto-snap: the mouse moves freely so you can place/modify seeds anywhere;
  --  the diamonds are reached by Gravity Play, not by magnetism)
  if mm.keyjazz then
    -- punch mode: aim silently — update the cursor only; i/o/p triggers the picked chord
    mm.last_notes = mm_compute_voices()
    if mm_canvas then mm_canvas:update() end
    return
  end
  local notes = mm_compute_voices()
  if mm.treatment == 1 then
    mm_play_chord(notes)          -- chord mode: every move sounds the chord
  else
    mm.last_notes = notes         -- arp/line/improvise: timer sequences these
  end
  if mm_canvas then mm_canvas:update() end
end

-- gravitation seeds: click drops a marked attractor at the picked chord; right-click removes nearest
local function mm_add_seed()
  local dx = mm_frac_to_degree(mm.mx)
  local dy = mm_frac_to_degree(1 - mm.my)
  for _, s in ipairs(mm.seeds) do if s.dx == dx and s.dy == dy then return end end
  mm.seeds[#mm.seeds + 1] = { dx = dx, dy = dy }
  mm_save_prefs()
  renoise.app():show_status("Music Mouse: gravitation seed dropped (" .. #mm.seeds .. " total)")
end

local function mm_remove_nearest_seed()
  if #mm.seeds == 0 then return end
  local dx = mm_frac_to_degree(mm.mx)
  local dy = mm_frac_to_degree(1 - mm.my)
  local best, bestd = nil, math.huge
  for i, s in ipairs(mm.seeds) do
    local d = math.abs(s.dx - dx) + math.abs(s.dy - dy)
    if d < bestd then bestd = d; best = i end
  end
  if best then table.remove(mm.seeds, best); mm_save_prefs(); renoise.app():show_status("Music Mouse: seed removed (" .. #mm.seeds .. " left)") end
end

function mm_clear_seeds()
  mm.seeds = {}
  mm.gravity_play = false
  mm_save_prefs()
  if mm_canvas then mm_canvas:update() end
  renoise.app():show_status("Music Mouse: gravitation seeds cleared")
end

function mm_toggle_gravity_play()
  mm.gravity_play = not mm.gravity_play
  mm.gravity_index = 0
  mm_restart_timer()
  if mm_canvas then mm_canvas:update() end
  renoise.app():show_status("Music Mouse: Gravity Play " ..
    (mm.gravity_play and ("ON — " .. #mm.seeds .. " seeds, in order") or "OFF"))
end

function mm_mouse_handler(ev)
  if ev == nil or ev.position == nil then return end
  if ev.type == "exit" then return end
  -- clamp to play area
  local px = ev.position.x
  local py = ev.position.y
  if px < PLAY_X0 then px = PLAY_X0 end
  if px > PLAY_X1 then px = PLAY_X1 end
  if py < PLAY_Y0 then py = PLAY_Y0 end
  if py > PLAY_Y1 then py = PLAY_Y1 end
  mm.mx = (px - PLAY_X0) / (PLAY_X1 - PLAY_X0)
  mm.my = (py - PLAY_Y0) / (PLAY_Y1 - PLAY_Y0)
  -- right-click removes the nearest seed
  if ev.type == "down" and ev.button == "right" then
    mm_remove_nearest_seed()
    if mm_canvas then mm_canvas:update() end
    return
  end
  -- play on down / move / drag (any pointer motion over the play area sounds the voices)
  if ev.type == "down" or ev.type == "move" or ev.type == "drag" then
    mm_update_from_mouse()
    if ev.type == "down" and ev.button == "left" then mm_add_seed() end  -- click drops a gravitation seed
  else
    if mm_canvas then mm_canvas:update() end
  end
end

--------------------------------------------------------------------------------
-- Canvas rendering
--------------------------------------------------------------------------------

-- Draw a horizontal piano keyboard in rect (x0,y0,w,h). black_at_bottom = black keys hang toward grid.
-- hi = set of highlighted notes ({[note]=true}); white pass first, black pass on top, so the
-- white highlight never covers a black key.
local function mm_draw_h_keyboard(ctx, x0, y0, w, h, black_at_bottom, th, hi)
  hi = hi or {}
  ctx.fill_color = th.sep
  ctx:fill_rect(x0, y0, w, h)
  local nw = #mm_white_notes
  local ww = w / nw
  for i = 1, nw do
    local n = mm_white_notes[i]
    local cx = x0 + mm_note_frac(n) * w
    ctx.fill_color = hi[n] and th.key_hi or th.white
    ctx:fill_rect(cx - ww * 0.5 + 0.5, y0 + 1, ww - 1, h - 2)
  end
  local bw = ww * 0.66
  local bh = h * 0.62
  local by = black_at_bottom and (y0 + h - bh) or y0
  for nn = DISPLAY_LO, DISPLAY_HI do
    if mm_is_black(nn) then
      local cx = x0 + mm_note_frac(nn) * w
      ctx.fill_color = hi[nn] and th.key_hi or th.black
      ctx:fill_rect(cx - bw * 0.5, by, bw, bh)
    end
  end
end

-- Draw a vertical piano keyboard in rect (x0,y0,w,h). top = high pitch. black_at_left = black toward grid.
local function mm_draw_v_keyboard(ctx, x0, y0, w, h, black_at_left, th, hi)
  hi = hi or {}
  ctx.fill_color = th.sep
  ctx:fill_rect(x0, y0, w, h)
  local nw = #mm_white_notes
  local wh = h / nw
  for i = 1, nw do
    local n = mm_white_notes[i]
    local cy = y0 + (1 - mm_note_frac(n)) * h
    ctx.fill_color = hi[n] and th.key_hi or th.white
    ctx:fill_rect(x0 + 1, cy - wh * 0.5 + 0.5, w - 2, wh - 1)
  end
  local bw = w * 0.62
  local bh = wh * 0.66
  local bx = black_at_left and x0 or (x0 + w - bw)
  for nn = DISPLAY_LO, DISPLAY_HI do
    if mm_is_black(nn) then
      local cy = y0 + (1 - mm_note_frac(nn)) * h
      ctx.fill_color = hi[nn] and th.key_hi or th.black
      ctx:fill_rect(bx, cy - bh * 0.5, bw, bh)
    end
  end
end

function mm_render(ctx)
  local th = mm_theme()
  local playW = PLAY_X1 - PLAY_X0
  local playH = PLAY_Y1 - PLAY_Y0

  -- surround + play area
  ctx:clear_rect(0, 0, MM_W, MM_H)
  ctx.fill_color = th.surround
  ctx:fill_rect(0, 0, MM_W, MM_H)
  ctx.fill_color = th.play
  ctx:fill_rect(PLAY_X0, PLAY_Y0, playW, playH)

  -- woven grid: faint dots at every white-key gridline intersection (aligned to the keyboards)
  ctx.fill_color = th.dot
  for i = 1, #mm_white_notes do
    local gx = PLAY_X0 + mm_note_frac(mm_white_notes[i]) * playW
    for j = 1, #mm_white_notes do
      local gy = PLAY_Y0 + (1 - mm_note_frac(mm_white_notes[j])) * playH
      ctx:fill_rect(gx, gy, 1, 1)
    end
  end

  -- current voice degrees per axis (X = top/bottom keyboards, Y = left/right keyboards)
  local x_degs, y_degs = mm_axis_degrees()
  local hi_x, hi_y = {}, {}
  local vline_fracs, hline_fracs = {}, {}
  for _, d in ipairs(x_degs) do hi_x[mm_degree_note(d)] = true; vline_fracs[#vline_fracs + 1] = mm_degree_to_frac(d) end
  for _, d in ipairs(y_degs) do hi_y[mm_degree_note(d)] = true; hline_fracs[#hline_fracs + 1] = mm_degree_to_frac(d) end

  -- four-sided piano keyboards with active keys highlighted in-place (white pass, then black on top)
  mm_draw_h_keyboard(ctx, PLAY_X0, 0, playW, EDGE - 2, true, th, hi_x)               -- top
  mm_draw_h_keyboard(ctx, PLAY_X0, MM_H - EDGE + 2, playW, EDGE - 2, false, th, hi_x) -- bottom
  mm_draw_v_keyboard(ctx, 0, PLAY_Y0, EDGE - 2, playH, false, th, hi_y)              -- left
  mm_draw_v_keyboard(ctx, MM_W - EDGE + 2, PLAY_Y0, EDGE - 2, playH, true, th, hi_y) -- right

  -- play-area frame
  ctx.stroke_color = th.frame
  ctx.line_width = 1
  ctx:begin_path(); ctx:rect(PLAY_X0, PLAY_Y0, playW, playH); ctx:stroke()

  -- cursor crosshair bars
  ctx.stroke_color = th.cursor
  ctx.line_width = 2
  for _, f in ipairs(vline_fracs) do
    local cx = PLAY_X0 + f * playW
    ctx:begin_path(); ctx:move_to(cx, PLAY_Y0); ctx:line_to(cx, PLAY_Y1); ctx:stroke()
  end
  for _, f in ipairs(hline_fracs) do
    local cy = PLAY_Y0 + (1 - f) * playH
    ctx:begin_path(); ctx:move_to(PLAY_X0, cy); ctx:line_to(PLAY_X1, cy); ctx:stroke()
  end

  -- white dots at the sounding intersections
  for _, fv in ipairs(vline_fracs) do
    for _, fh in ipairs(hline_fracs) do
      local cx = PLAY_X0 + fv * playW
      local cy = PLAY_Y0 + (1 - fh) * playH
      ctx.fill_color = th.dot_hi
      ctx:fill_rect(cx - 3, cy - 3, 6, 6)
      ctx.stroke_color = th.frame
      ctx.line_width = 1
      ctx:begin_path(); ctx:rect(cx - 3, cy - 3, 6, 6); ctx:stroke()
    end
  end

  -- gravitation seeds: green diamonds you can land back on (cursor is pulled toward them).
  -- During Gravity Play the active seed is larger + yellow, and each shows its play order.
  for i, s in ipairs(mm.seeds) do
    local cx = PLAY_X0 + mm_degree_to_frac(s.dx) * playW
    local cy = PLAY_Y0 + (1 - mm_degree_to_frac(s.dy)) * playH
    local active = mm.gravity_play and (i == mm.gravity_index)
    local r = active and 9 or 6
    ctx.fill_color = active and { 255, 220, 40, 255 } or { 60, 220, 130, 255 }
    ctx.stroke_color = th.frame
    ctx.line_width = 1
    ctx:begin_path()
    ctx:move_to(cx, cy - r); ctx:line_to(cx + r, cy); ctx:line_to(cx, cy + r)
    ctx:line_to(cx - r, cy); ctx:line_to(cx, cy - r)
    ctx:fill()
    ctx:stroke()
  end

  -- frozen (SPACE) or mouse-disconnected (delete) indicator — red frame
  if mm.frozen or not mm.mouse_active then
    ctx.stroke_color = mm.frozen and { 255, 170, 40, 255 } or { 220, 60, 60, 255 }
    ctx.line_width = 3
    ctx:begin_path(); ctx:rect(PLAY_X0 + 2, PLAY_Y0 + 2, playW - 4, playH - 4); ctx:stroke()
  end

  -- held (ENTER-locked) note count, small marker bottom-left of play area
  if #mm.held > 0 then
    ctx.fill_color = { 80, 200, 120, 255 }
    for i = 1, math.min(#mm.held, 24) do
      ctx:fill_rect(PLAY_X0 + 4 + (i - 1) * 5, PLAY_Y1 - 8, 3, 4)
    end
  end

  -- REC indicator (top-left): armed = dim red, actively writing (transport playing) = bright red
  if mm.record then
    local song = renoise.song()
    local live = song and song.transport.playing
    ctx.fill_color = live and { 255, 40, 40, 255 } or { 150, 50, 50, 255 }
    ctx:fill_rect(PLAY_X0 + 6, PLAY_Y0 + 6, 12, 12)
  end
end

--------------------------------------------------------------------------------
-- Waveforms (single-cycle generators) + pakettified instrument generation
--------------------------------------------------------------------------------

-- single-cycle period (frames). 256 @ 44100 -> 172.27 Hz reference.
local MM_PERIOD = 256
local TWO_PI = math.pi * 2

-- waveform palette (dropdown). The first three map to the classic MM u/i/o keys.
local MM_WAVEFORMS = { "Triangle", "Square", "Saw", "Sine", "Rounded Square", "Pulse 25%", "Diode", "Gauss" }

-- phase 0..1 -> sample value -1..1
local function mm_wave_value(shape, phase)
  if shape == "Sine" then
    return math.sin(phase * TWO_PI)
  elseif shape == "Triangle" then
    -- centered: starts at 0, up to +1, back through 0 to -1, back to 0
    if phase < 0.25 then return 4 * phase
    elseif phase < 0.75 then return 2 - 4 * phase
    else return 4 * phase - 4 end
  elseif shape == "Square" then
    return (phase < 0.5) and 0.85 or -0.85
  elseif shape == "Rounded Square" then
    local s = math.sin(phase * TWO_PI) * 2.2          -- soft-clipped sine = rounded square
    if s > 1 then s = 1 elseif s < -1 then s = -1 end
    return s
  elseif shape == "Pulse 25%" then
    return (phase < 0.25) and 0.85 or -0.85
  elseif shape == "Diode" then
    local s = math.sin(phase * TWO_PI)
    return s > 0 and (2 * s - 1) or -1                -- half-rectified, centered-ish
  elseif shape == "Gauss" then
    local x = (phase - 0.5) * 6
    return 2 * math.exp(-x * x * 0.5) - 1
  else
    return math.sin(phase * TWO_PI)
  end
end

-- sustain waveform: one looping single cycle (drone)
local function mm_render_sustain(buf, shape)
  buf:create_sample_data(44100, 16, 1, MM_PERIOD)
  buf:prepare_sample_data_changes()
  for i = 1, MM_PERIOD do
    buf:set_sample_data(1, i, mm_wave_value(shape, (i - 1) / MM_PERIOD) * 0.9)
  end
  buf:finalize_sample_data_changes()
end

-- bell waveform: ~1.3 s of repeated single cycles with an exponential decay baked in (non-looping fade)
local function mm_render_bell(buf, shape)
  local frames = 57344   -- ~1.3 s @ 44100, multiple of MM_PERIOD (224 cycles)
  buf:create_sample_data(44100, 16, 1, frames)
  buf:prepare_sample_data_changes()
  for i = 1, frames do
    local phase = ((i - 1) % MM_PERIOD) / MM_PERIOD
    local t = (i - 1) / frames
    local decay = math.exp(-4.5 * t)          -- struck-bell amplitude envelope
    buf:set_sample_data(1, i, mm_wave_value(shape, phase) * 0.9 * decay)
  end
  buf:finalize_sample_data_changes()
end

-- tune the single-cycle sample so played notes are in pitch (A-4 = 57 = 440 Hz in Renoise note values)
local function mm_tune_sample(smp)
  smp.interpolation_mode = renoise.Sample.INTERPOLATE_NONE
  smp.oversample_enabled = false
  -- Tune with Paketti's PCM Writer single-cycle convention (sample.transpose + fine_tune, base_note
  -- left at default), so Music Mouse instruments match the PCM Writer and can be edited with it.
  -- The wave PERIOD is 256 whether Sustain (256-frame loop) or Bell (many 256-frame cycles).
  if PCMWriterApplyPitchCorrectionToSample then
    pcall(function() PCMWriterApplyPitchCorrectionToSample(smp, MM_PERIOD) end)
  end
  pcall(function() smp.sample_mapping.note_range = { 0, 119 } end)
end

-- render the current waveform + mode into a sample
local function mm_render_into_sample(smp)
  if mm.bell then
    mm_render_bell(smp.sample_buffer, mm.waveform)
    smp.loop_mode = renoise.Sample.LOOP_MODE_OFF
  else
    mm_render_sustain(smp.sample_buffer, mm.waveform)
    smp.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    smp.loop_start = 1
    smp.loop_end = smp.sample_buffer.number_of_frames
  end
  mm_tune_sample(smp)
  smp.name = "MM " .. mm.waveform .. (mm.bell and " bell" or "")
end

local function mm_current_is_mm_instrument()
  local instr = renoise.song().selected_instrument
  return instr and instr.name:find("Music Mouse") and #instr.samples > 0
end

-- create a fresh pakettified Music Mouse instrument: load the Paketti default, then render the wavefile
function pakettiMusicMouseGenerateInstrument()
  local song = renoise.song()
  local idx = song.selected_instrument_index
  song:insert_instrument_at(idx + 1)
  song.selected_instrument_index = idx + 1
  -- pakettified: load the Paketti default instrument (modulation/filter chain), then render into it
  if pakettiPreferencesDefaultInstrumentLoader then
    pakettiPreferencesDefaultInstrumentLoader()
  end
  local instr = song.selected_instrument
  while #instr.samples > 1 do instr:delete_sample_at(#instr.samples) end
  if #instr.samples == 0 then instr:insert_sample_at(1) end
  song.selected_sample_index = 1
  -- keep the sample linked to the Paketti default instrument's modulation set (envelope/filter)
  if #instr.sample_modulation_sets >= 1 then
    pcall(function() instr.samples[1].modulation_set_index = 1 end)
  end
  mm_render_into_sample(instr.samples[1])
  instr.name = "Music Mouse " .. mm.waveform
  if mm_update_panel then mm_update_panel() end
  renoise.app():show_status("Music Mouse: " .. mm.waveform .. (mm.bell and " (bell)" or " (sustain)") .. " instrument ready")
end

-- apply waveform/mode: regenerate the selected MM instrument in place, else create a new pakettified one
local function mm_apply_waveform()
  if mm_current_is_mm_instrument() then
    local instr = renoise.song().selected_instrument
    mm_render_into_sample(instr.samples[1])
    instr.name = "Music Mouse " .. mm.waveform
    if mm_update_panel then mm_update_panel() end
    renoise.app():show_status("Music Mouse: " .. mm.waveform .. (mm.bell and " (bell)" or " (sustain)"))
  else
    pakettiMusicMouseGenerateInstrument()
  end
end

local mm_ui_busy = false   -- guard against programmatic control updates re-firing notifiers

function mm_wave_index_value()
  for i, w in ipairs(MM_WAVEFORMS) do if w == mm.waveform then return i end end
  return 1
end

local function mm_sync_wave_ui()
  mm_ui_busy = true
  if vb.views["mm_wave_popup"] then
    for i, w in ipairs(MM_WAVEFORMS) do
      if w == mm.waveform then vb.views["mm_wave_popup"].value = i; break end
    end
  end
  if vb.views["mm_mode_switch"] then
    vb.views["mm_mode_switch"].value = mm.bell and 2 or 1
  end
  mm_ui_busy = false
end

local function mm_set_waveform(shape)
  local changed = (shape ~= mm.waveform) or not mm_current_is_mm_instrument()
  mm.waveform = shape           -- mm.bell is left untouched: Bell stays Bell, Sustain stays Sustain
  mm_sync_wave_ui()
  if changed then mm_apply_waveform() end
  -- MM behavior: pressing a sound key re-strikes the current chord with the new/same timbre
  mm_retrigger()
  -- In Arpeggiate mode, the sound key also writes the arpeggio into the pattern (arpeggio button)
  if mm.treatment == 2 then mm_stamp_arpeggio() end
  if mm_canvas then mm_canvas:update() end
end

local function mm_set_bell(is_bell)
  mm.bell = is_bell
  mm_sync_wave_ui()
  mm_apply_waveform()
  mm_retrigger()                -- re-strike so you hear the new articulation immediately
  if mm_canvas then mm_canvas:update() end
end

--------------------------------------------------------------------------------
-- Live parameter panel (mirrors the original MM left-hand readout)
--------------------------------------------------------------------------------

local MM_HARMONY_ITEMS = {}
for _, k in ipairs(MM_SCALE_ORDER) do MM_HARMONY_ITEMS[#MM_HARMONY_ITEMS + 1] = MM_SCALES[k].label end
local MM_ARTIC_ITEMS = { "Staccato", "Half Legato", "Full Legato" }
local MM_PATTERN_ITEMS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
local MM_PATTARGET_ITEMS = { "All voices", "Melody (top)", "Bass (bottom)" }
local MM_PATTARGET_KEYS = { "all", "melody", "bass" }
local LBL = 120  -- label column width

local function mm_pattarget_index()
  for i, k in ipairs(MM_PATTARGET_KEYS) do if k == mm.pat_target then return i end end
  return 1
end

local function mm_scale_index()
  for i, k in ipairs(MM_SCALE_ORDER) do if k == mm.scale_key then return i end end
  return 4
end
local function mm_artic_index()
  if mm.staccato then return 1 elseif mm.half_legato then return 2 else return 3 end
end

-- replay the chord and refresh the canvas (used by controls that change pitch content)
local function mm_replay()
  mm_play_chord(mm_compute_voices())
  if mm_canvas then mm_canvas:update() end
end
local function mm_reseat_axis()
  mm_rebuild_axis()
  mm.deg_x = mm_frac_to_degree(mm.mx)
  mm.deg_y = mm_frac_to_degree(1 - mm.my)
end
local function mm_set_num_voices(n)
  mm.num_voices = n
  for v = n + 1, MM_MAX_VOICES do mm_note_off(v) end   -- silence voices that are no longer active
  mm_replay()
  mm_update_panel()
end

-- build the live control panel (dropdowns / valueboxes / checkboxes), two-way synced with the keyboard
local function mm_controls_column(vbx)
  local function lbl(t) return vbx:text{ text = t, width = LBL, font = "mono" } end
  -- mute row (1..MM_MAX_VOICES), built programmatically
  local mute_row = { spacing = 3, lbl("Mute voices") }
  for i = 1, MM_MAX_VOICES do
    local vi = i
    mute_row[#mute_row + 1] = vbx:checkbox{ id = "mm_mute_" .. vi, value = not mm.mute[vi],
      notifier = function(b) if mm_ui_busy then return end mm.mute[vi] = not b; if mm.mute[vi] then mm_note_off(vi) end end }
    mute_row[#mute_row + 1] = vbx:text{ text = tostring(vi), font = "mono" }
  end
  return vbx:column{
    spacing = 3,
    vbx:row{ spacing = 4, lbl("Voices (4-9)"),
      vbx:switch{ id = "mm_voices_switch", width = 168, items = { "4", "5", "6", "7", "8", "9" }, value = mm.num_voices - 3,
        notifier = function(i) if mm_ui_busy then return end mm_set_num_voices(i + 3) end },
      vbx:text{ text = "5+=rich", font = "mono" } },
    vbx:row(mute_row),
    vbx:row{ spacing = 4, lbl("Harmonic Mode"),
      vbx:popup{ id = "mm_harmony_popup", width = 150, items = MM_HARMONY_ITEMS, value = mm_scale_index(),
        notifier = function(i) if mm_ui_busy then return end mm.scale_key = MM_SCALE_ORDER[i]; mm_reseat_axis(); mm_replay() end } },
    vbx:row{ spacing = 4, lbl("Treatment"),
      vbx:popup{ id = "mm_treatment_popup", width = 150, items = TREATMENT_NAMES, value = mm.treatment,
        notifier = function(i) if mm_ui_busy then return end mm.treatment = i; mm.seq_i = 0; mm_restart_timer() end } },
    vbx:row{ spacing = 4, lbl("Transposition"),
      vbx:valuebox{ id = "mm_transpose_box", width = 150, min = -48, max = 48, value = mm.transpose,
        notifier = function(v) if mm_ui_busy then return end mm.transpose = v; mm_reseat_axis(); mm_replay() end } },
    vbx:row{ spacing = 4, lbl("Interval Transp"),
      vbx:valuebox{ id = "mm_interval_box", width = 150, min = 1, max = 24, value = mm.interval,
        notifier = function(v) if mm_ui_busy then return end mm.interval = v end } },
    vbx:row{ spacing = 4, lbl("Pattern"),
      vbx:checkbox{ id = "mm_pattern_check", value = mm.pattern_on,
        notifier = function(b) if mm_ui_busy then return end mm.pattern_on = b; mm.pat_step = 1; mm_restart_timer() end },
      vbx:popup{ id = "mm_pattern_popup", width = 116, items = MM_PATTERN_ITEMS, value = mm.pattern_idx,
        notifier = function(i) if mm_ui_busy then return end mm.pattern_idx = i; if mm_pat_canvas then mm_pat_canvas:update() end end } },
    vbx:row{ spacing = 4, lbl("Pattern Applies"),
      vbx:popup{ id = "mm_pattarget_popup", width = 150, items = MM_PATTARGET_ITEMS, value = mm_pattarget_index(),
        notifier = function(i) if mm_ui_busy then return end mm.pat_target = MM_PATTARGET_KEYS[i]; mm_replay() end } },
    vbx:row{ spacing = 4, lbl("Record -> Pattern"),
      vbx:checkbox{ id = "mm_record_check", value = mm.record,
        notifier = function(b) if mm_ui_busy then return end mm_set_record(b) end },
      vbx:text{ text = "(right-shift: play+edit+follow+imprint)", font = "mono" } },
    vbx:row{ spacing = 4, lbl("Keyjazz Punch"),
      vbx:checkbox{ id = "mm_keyjazz_check", value = mm.keyjazz,
        notifier = function(b) if mm_ui_busy then return end mm.keyjazz = b; if b then mm_all_notes_off() end; if mm_canvas then mm_canvas:update() end end },
      vbx:text{ text = "(j: mouse silent, i/o/p triggers)", font = "mono" } },
    vbx:row{ spacing = 4, lbl("Mouse Movement"),
      vbx:switch{ id = "mm_mousemov_switch", width = 150, items = { "Parallel", "Contrary" }, value = (mm.mouse_contrary and 2 or 1),
        notifier = function(i) if mm_ui_busy then return end mm.mouse_contrary = (i == 2); mm_replay() end } },
    vbx:row{ spacing = 4, lbl("Pattern Movement"),
      vbx:switch{ id = "mm_patmov_switch", width = 150, items = { "Parallel", "Contrary" }, value = (mm.pattern_contrary and 2 or 1),
        notifier = function(i) if mm_ui_busy then return end mm.pattern_contrary = (i == 2) end } },
    vbx:row{ spacing = 4, lbl("Voicing Format"),
      vbx:switch{ id = "mm_format_switch", width = 150, items = { "Chord-melody", "Voice-pairs" }, value = (mm.format_pairs and 2 or 1),
        notifier = function(i) if mm_ui_busy then return end mm.format_pairs = (i == 2); mm_replay() end } },
    vbx:row{ spacing = 4, lbl("Articulation"),
      vbx:popup{ id = "mm_artic_popup", width = 150, items = MM_ARTIC_ITEMS, value = mm_artic_index(),
        notifier = function(i) if mm_ui_busy then return end mm.staccato = (i == 1); mm.half_legato = (i == 2) end } },
    vbx:row{ spacing = 4, lbl("Loudness"),
      vbx:valuebox{ id = "mm_loudness_box", width = 150, min = 0, max = 127, value = math.floor(mm.loudness * 127 + 0.5),
        notifier = function(v) if mm_ui_busy then return end mm.loudness = v / 127; mm_save_prefs() end } },
    vbx:row{ spacing = 4, lbl("Tempo 1 / 2"),
      vbx:valuebox{ id = "mm_tempo1_box", width = 60, min = 20, max = 400, value = mm.tempo_basic,
        notifier = function(v) if mm_ui_busy then return end mm.tempo_basic = v; mm_restart_timer(); mm_save_prefs() end },
      vbx:valuebox{ id = "mm_tempo2_box", width = 60, min = 20, max = 400, value = mm.tempo_alt,
        notifier = function(v) if mm_ui_busy then return end mm.tempo_alt = v; mm_restart_timer(); mm_save_prefs() end },
      vbx:text{ text = "Sync", font = "mono" },
      vbx:checkbox{ id = "mm_syncbpm_check", value = mm.sync_bpm,
        notifier = function(b) if mm_ui_busy then return end mm.sync_bpm = b; mm_restart_timer(); mm_save_prefs() end } },
    vbx:row{ spacing = 4, lbl("Grouping"),
      vbx:checkbox{ id = "mm_grouping_check", value = mm.grouping, notifier = function(b) if mm_ui_busy then return end mm.grouping = b end },
      vbx:text{ text = "Sound", font = "mono" },
      vbx:checkbox{ id = "mm_sound_check", value = mm.sound_on, notifier = function(b) if mm_ui_busy then return end mm.sound_on = b; if not b then mm_all_notes_off() end end },
      vbx:text{ text = "AltTmp", font = "mono" },
      vbx:checkbox{ id = "mm_altt_check", value = mm.tempo_use_alt, notifier = function(b) if mm_ui_busy then return end mm.tempo_use_alt = b; mm_restart_timer() end },
      vbx:text{ text = "Mouse", font = "mono" },
      vbx:checkbox{ id = "mm_mouse_check", value = mm.mouse_active, notifier = function(b) if mm_ui_busy then return end mm.mouse_active = b; if not b then mm_all_notes_off() end; if mm_canvas then mm_canvas:update() end end },
    },
    vbx:row{ spacing = 4, lbl("Launchpad"),
      vbx:popup{ id = "mm_launchpad_popup", width = 150, items = { "Off", "Play chords", "Raindrops demo" },
        value = (PakettiMusicMouseLaunchpadModeIndex and PakettiMusicMouseLaunchpadModeIndex()) or 1,
        notifier = function(i) if mm_ui_busy then return end
          PakettiMusicMouseLaunchpadSetMode((i == 2 and "play") or (i == 3 and "raindrops") or "off") end },
      vbx:text{ text = "(8x8 pads trigger chords / ripple light show)", font = "mono" } },
  }
end

-- two-way sync: push current state into all controls (guarded so it doesn't re-fire notifiers)
mm_update_panel = function()
  local v = vb.views
  if not v["mm_harmony_popup"] then return end
  mm_ui_busy = true
  v["mm_harmony_popup"].value = mm_scale_index()
  v["mm_treatment_popup"].value = mm.treatment
  v["mm_transpose_box"].value = mm.transpose
  v["mm_interval_box"].value = mm.interval
  v["mm_pattern_check"].value = mm.pattern_on
  v["mm_pattern_popup"].value = mm.pattern_idx
  if v["mm_pattarget_popup"] then v["mm_pattarget_popup"].value = mm_pattarget_index() end
  if v["mm_record_check"] then v["mm_record_check"].value = mm.record end
  if v["mm_keyjazz_check"] then v["mm_keyjazz_check"].value = mm.keyjazz end
  v["mm_mousemov_switch"].value = mm.mouse_contrary and 2 or 1
  v["mm_patmov_switch"].value = mm.pattern_contrary and 2 or 1
  v["mm_format_switch"].value = mm.format_pairs and 2 or 1
  v["mm_artic_popup"].value = mm_artic_index()
  v["mm_loudness_box"].value = math.floor(mm.loudness * 127 + 0.5)
  v["mm_tempo1_box"].value = mm.tempo_basic
  v["mm_tempo2_box"].value = mm.tempo_alt
  if v["mm_syncbpm_check"] then v["mm_syncbpm_check"].value = mm.sync_bpm end
  v["mm_grouping_check"].value = mm.grouping
  v["mm_sound_check"].value = mm.sound_on
  v["mm_altt_check"].value = mm.tempo_use_alt
  v["mm_mouse_check"].value = mm.mouse_active
  for i = 1, MM_MAX_VOICES do if v["mm_mute_" .. i] then v["mm_mute_" .. i].value = not mm.mute[i] end end
  if v["mm_voices_switch"] then v["mm_voices_switch"].value = mm.num_voices - 3 end
  if v["mm_wave_popup"] then v["mm_wave_popup"].value = mm_wave_index_value() end
  if v["mm_mode_switch"] then v["mm_mode_switch"].value = mm.bell and 2 or 1 end
  mm_ui_busy = false
end

--------------------------------------------------------------------------------
-- Melodic-pattern editor (edit the a + 0-9 contours as step bars)
--------------------------------------------------------------------------------

local MM_PAT_W, MM_PAT_H = 256, 96
local mm_pat_drag = false

local function mm_pat_cur() return MM_PATTERNS[mm.pattern_idx] end

function mm_pat_render(ctx)
  local th = mm_theme()
  local pat = mm_pat_cur()
  local n = #pat
  local sw = MM_PAT_W / math.max(1, n)
  local floor = MM_PAT_H - 12   -- baseline; play-step marker lives below it

  ctx:clear_rect(0, 0, MM_PAT_W, MM_PAT_H)
  ctx.fill_color = th.play
  ctx:fill_rect(0, 0, MM_PAT_W, MM_PAT_H)

  for s = 1, n do
    local x = (s - 1) * sw
    if s % 2 == 0 then ctx.fill_color = th.dot; ctx:fill_rect(x, 0, sw, MM_PAT_H) end
    local val = pat[s] or 0
    local bh = (val / MM_PAT_MAX) * floor
    ctx.fill_color = th.cursor
    ctx:fill_rect(x + 1, floor - bh, sw - 2, bh + 1)
  end

  -- current play-step marker (orange) when patterning is running
  if mm.pattern_on then
    local cs = ((mm.pat_step - 1) % n) + 1
    ctx.fill_color = th.key_hi
    ctx:fill_rect((cs - 1) * sw, MM_PAT_H - 5, sw, 5)
  end

  ctx.stroke_color = th.frame
  ctx.line_width = 1
  ctx:begin_path(); ctx:rect(0, 0, MM_PAT_W, MM_PAT_H); ctx:stroke()
end

local function mm_pat_set_from_xy(px, py)
  local pat = mm_pat_cur()
  local n = #pat
  local sw = MM_PAT_W / math.max(1, n)
  local s = math.floor(px / sw) + 1
  if s < 1 then s = 1 elseif s > n then s = n end
  local floor = MM_PAT_H - 12
  local frac = 1 - (py / floor)
  if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
  pat[s] = math.floor(frac * MM_PAT_MAX + 0.5)
  if mm_pat_canvas then mm_pat_canvas:update() end
end

function mm_pat_mouse(ev)
  if ev == nil or ev.position == nil then return end
  if ev.type == "down" then
    mm_pat_drag = true
    mm_pat_set_from_xy(ev.position.x, ev.position.y)
  elseif ev.type == "up" or ev.type == "exit" then
    mm_pat_drag = false
  elseif (ev.type == "move" or ev.type == "drag") and mm_pat_drag then
    mm_pat_set_from_xy(ev.position.x, ev.position.y)
  end
end

local function mm_pat_length_delta(d)
  local pat = mm_pat_cur()
  if d > 0 and #pat < MM_PAT_MAXLEN then pat[#pat + 1] = 0
  elseif d < 0 and #pat > 1 then pat[#pat] = nil end
  if mm_pat_canvas then mm_pat_canvas:update() end
end

local function mm_pat_reset()
  local orig = MM_PATTERNS_ORIG[mm.pattern_idx]
  local pat = {}
  for j, v in ipairs(orig) do pat[j] = v end
  MM_PATTERNS[mm.pattern_idx] = pat
  if mm_pat_canvas then mm_pat_canvas:update() end
  renoise.app():show_status("Music Mouse: pattern " .. (mm.pattern_idx == 10 and 0 or mm.pattern_idx) .. " reset to original")
end

--------------------------------------------------------------------------------
-- Keyboard controls (the Music Mouse keymap)
--------------------------------------------------------------------------------

local function mm_set_scale(key_letter, quiet)
  local map = { q = "chromatic", w = "octatonic", e = "midEastern", r = "diatonic", t = "pentatonic", y = "quartal" }
  local sk = map[key_letter]
  if not sk then return end
  mm.scale_key = sk
  mm_rebuild_axis()
  -- recompute axis position for the new scale
  mm.deg_x = mm_frac_to_degree(mm.mx)
  mm.deg_y = mm_frac_to_degree(1 - mm.my)
  if not quiet then
    local notes = mm_compute_voices()
    mm_play_chord(notes)
  end
end

local function mm_transpose(delta_semitones, quiet)
  mm.transpose = mm.transpose + delta_semitones
  if not quiet then
    local notes = mm_compute_voices()
    mm_play_chord(notes)
  end
end

local function mm_toggle_mute(v)
  mm.mute[v] = not mm.mute[v]
  if mm.mute[v] then mm_note_off(v) end
end

-- returns nil to consume the key, or the key to pass it through to Renoise
function mm_keyhandler(dlg, key)
  local name = key.name
  local mods = key.modifiers or ""
  local has_shift = mods:find("shift") ~= nil
  local has_cmd = mods:find("cmd") ~= nil or mods:find("command") ~= nil
              or mods:find("control") ~= nil or mods:find("ctrl") ~= nil
  local has_alt = mods:find("alt") ~= nil or mods:find("option") ~= nil

  -- KEY PROBE (temporary): surfaces exactly what Renoise reports for each key, so we can
  -- discover what the right-shift key produces on this machine.
  if mm.key_probe then
    print(string.format("[MusicMouse] key name='%s' modifiers='%s' repeated=%s", tostring(name), tostring(mods), tostring(key.repeated)))
    renoise.app():show_status("MM key: name='" .. tostring(name) .. "'  mods='" .. tostring(mods) .. "'")
  end

  -- Keys/combos Music Mouse must NOT capture — let them through to Renoise:
  -- F8 (and F5..F12; MM only uses F1-F4), any Alt/Option (incl. right-option), and Shift+Cmd combos.
  local fnum = name:match("^f(%d+)$")
  local is_alt_key = name == "ralt" or name == "lalt" or name == "alt"
                  or name == "roption" or name == "loption" or name == "option"
  if name == "f8"
     or (fnum and tonumber(fnum) >= 5)
     or has_alt or is_alt_key
     or (has_shift and has_cmd) then
    return key
  end

  -- ===== General (no modifier) =====
  if name == "esc" then pakettiMusicMouseClose(); return nil end
  if name == "home" or name == "ins" or name == "insert" or name == "help" then mm_reinit(); return nil end
  if name == "back" or name == "delete" then       -- disconnect mouse
    mm.mouse_active = not mm.mouse_active
    if not mm.mouse_active then mm_all_notes_off() end
    mm_update_panel(); if mm_canvas then mm_canvas:update() end
    return nil
  end
  -- RIGHT-shift only toggles Record-to-Pattern (left-shift stays a normal modifier for your
  -- shift-combos). Ignore auto-repeat so one press = one toggle.
  if name == "rshift" then
    if key.repeated then return nil end
    mm_set_record(not mm.record)
    return nil
  end

  -- ===== Bindings that legitimately use cmd/shift (handled before the modifier guard) =====
  -- cmd-up / cmd-down: select previous / next instrument (and re-strike on it)
  if has_cmd and (name == "up" or name == "down") then
    local song = renoise.song()
    local i = song.selected_instrument_index
    if name == "up" and i > 1 then song.selected_instrument_index = i - 1 end
    if name == "down" and i < #song.instruments then song.selected_instrument_index = i + 1 end
    mm_retrigger()
    renoise.app():show_status("Music Mouse: instrument " .. song.selected_instrument_index ..
      " — " .. (song.selected_instrument.name ~= "" and song.selected_instrument.name or "(unnamed)"))
    return nil
  end
  -- Harmony q w e r t y : plain = play, cmd = quiet. (shift-qwerty passes through.)
  if (not has_shift) and (name == "q" or name == "w" or name == "e" or name == "r" or name == "t" or name == "y") then
    mm_set_scale(name, has_cmd)
    mm_update_panel(); if mm_canvas then mm_canvas:update() end
    return nil
  end
  -- Transposition z x c : plain = transpose, shift = interval, cmd = quiet
  if name == "z" then
    if has_shift then mm.interval = math.max(1, mm.interval - 1) else mm_transpose(-mm.interval, has_cmd) end
    mm_update_panel(); return nil
  end
  if name == "x" then
    if has_shift then mm.interval = mm.interval + 1 else mm_transpose(mm.interval, has_cmd) end
    mm_update_panel(); return nil
  end
  if name == "c" then
    if has_shift then mm.interval = 1
    else mm.transpose = 0; if not has_cmd then mm_play_chord(mm_compute_voices()) end end
    mm_update_panel(); return nil
  end
  -- Articulation / (shift = half/full legato) ; Loudness , . (shift = extremes)
  if name == "/" or name == "slash" then
    if has_shift then mm.half_legato = not mm.half_legato else mm.staccato = not mm.staccato end
    mm_update_panel(); return nil
  end
  -- shift-comma = ';' on Nordic/many layouts -> Gravity Play (must be caught before loudness)
  if (name == "," or name == "comma") and has_shift then mm_toggle_gravity_play(); return nil end
  if name == "," or name == "comma" or name == "<" then
    mm.loudness = math.max(0, mm.loudness - 0.08)   -- loudness down (plain comma)
    mm_update_panel(); mm_save_prefs(); return nil
  end
  if name == "." or name == "period" or name == ">" then
    if has_shift then mm.loudness = 1 else mm.loudness = math.min(1, mm.loudness + 0.08) end
    mm_update_panel(); mm_save_prefs(); return nil
  end
  -- ENTER lock (shift = release held)
  if name == "return" or name == "enter" then
    if has_shift then mm_release_held(); renoise.app():show_status("Music Mouse: released all locked notes")
    else local n = mm_lock_voices(); renoise.app():show_status("Music Mouse: locked " .. n .. " note(s) — " .. #mm.held .. " held total") end
    if mm_canvas then mm_canvas:update() end
    return nil
  end
  -- Muting shift-1..9 ; ~ reverse / shift-~ all on
  if has_shift and name:match("^[1-9]$") then mm_toggle_mute(tonumber(name)); mm_update_panel(); return nil end
  if name == "~" or name == "`" then
    if has_shift then for v = 1, MM_MAX_VOICES do mm.mute[v] = false end
    else for v = 1, MM_MAX_VOICES do mm.mute[v] = not mm.mute[v]; if mm.mute[v] then mm_note_off(v) end end end
    mm_update_panel(); return nil
  end
  -- Tempo - + [ ] \  (shift = Slow/Fast/Default presets). Taking manual tempo control
  -- releases Sync-to-BPM so the Music Mouse tempo actually drives the player.
  if name == "-" or name == "minus" then
    mm.sync_bpm = false
    if has_shift then mm.tempo_basic = 50 else mm.tempo_basic = math.max(20, mm.tempo_basic - 4) end
    mm_restart_timer(); mm_update_panel(); mm_save_prefs()
    renoise.app():show_status("Music Mouse: Tempo 1 = " .. mm.tempo_basic .. " (Sync off)"); return nil
  end
  if name == "+" or name == "=" or name == "equals" then
    mm.sync_bpm = false
    if has_shift then mm.tempo_basic = 200 else mm.tempo_basic = math.min(400, mm.tempo_basic + 4) end
    mm_restart_timer(); mm_update_panel(); mm_save_prefs()
    renoise.app():show_status("Music Mouse: Tempo 1 = " .. mm.tempo_basic .. " (Sync off)"); return nil
  end
  if name == "[" then
    mm.sync_bpm = false
    if has_shift then mm.tempo_alt = 50 else mm.tempo_alt = math.max(20, mm.tempo_alt - 4) end
    mm_restart_timer(); mm_update_panel(); mm_save_prefs(); return nil
  end
  if name == "]" then
    mm.sync_bpm = false
    if has_shift then mm.tempo_alt = 200 else mm.tempo_alt = math.min(400, mm.tempo_alt + 4) end
    mm_restart_timer(); mm_update_panel(); mm_save_prefs(); return nil
  end
  if name == "\\" or name == "backslash" then
    mm.sync_bpm = false
    if has_shift then mm.tempo_basic = 100 else mm.tempo_use_alt = not mm.tempo_use_alt end
    mm_restart_timer(); mm_update_panel(); mm_save_prefs(); return nil
  end
  -- Treatments cmd-1..4 / F1-F4
  if has_cmd and name:match("^[1-4]$") then
    mm.treatment = tonumber(name); mm.seq_i = 0; mm_restart_timer(); mm_update_panel(); return nil
  end
  if name == "f1" then mm.treatment = 1; mm_restart_timer(); mm_update_panel(); return nil end
  if name == "f2" then mm.treatment = 2; mm_restart_timer(); mm_update_panel(); return nil end
  if name == "f3" then mm.treatment = 3; mm_restart_timer(); mm_update_panel(); return nil end
  if name == "f4" then mm.treatment = 4; mm_restart_timer(); mm_update_panel(); return nil end

  -- ===== MODIFIER GUARD: any shift/cmd combo Music Mouse did NOT map → pass through to Renoise =====
  if has_shift or has_cmd then return key end

  -- ===== Plain-only keys (guaranteed no shift/cmd; alt was already passed through above) =====
  if name == "space" then
    if mm.record then
      mm_set_record(false); mm.frozen = true; mm_all_notes_off()
    else
      mm.frozen = not mm.frozen
      if mm.frozen then mm_all_notes_off() end
    end
    mm_update_panel(); if mm_canvas then mm_canvas:update() end
    renoise.app():show_status("Music Mouse: " .. (mm.frozen and "FROZEN (mouse + playback paused; keys still work)" or "live"))
    return nil
  end
  if name == "tab" then
    -- cycle the selected instrument's tuning through Paketti's microtonal presets (12-TET first)
    if PakettiMicrotonalCycleTuning then
      local tname = PakettiMicrotonalCycleTuning(1)   -- next tuning (12-TET -> ... -> wrap)
      mm_retrigger()
      renoise.app():show_status("Music Mouse tuning: " .. (tname == "" and "12-TET" or tname))
    else
      renoise.app():show_status("Music Mouse: Microtonal Tunings not available")
    end
    return nil
  end
  if name:match("^[0-9]$") then
    local num = tonumber(name)
    mm.pattern_idx = (num == 0) and 10 or num
    mm_update_panel(); if mm_pat_canvas then mm_pat_canvas:update() end; return nil
  end
  if name == "a" then mm.pattern_on = not mm.pattern_on; mm.pat_step = 1; mm_restart_timer(); mm_update_panel(); return nil end
  if name == "s" then mm.pattern_contrary = not mm.pattern_contrary; mm_update_panel(); return nil end
  if name == "d" then
    mm.mouse_contrary = not mm.mouse_contrary
    mm_play_chord(mm_compute_voices()); mm_update_panel(); if mm_canvas then mm_canvas:update() end; return nil
  end
  if name == "f" then
    mm.format_pairs = not mm.format_pairs
    mm_play_chord(mm_compute_voices()); mm_update_panel(); if mm_canvas then mm_canvas:update() end; return nil
  end
  if name == "g" then  -- cycle Articulation: Staccato -> Half Legato -> Full Legato
    local cur = mm.staccato and 1 or (mm.half_legato and 2 or 3)
    local nxt = cur % 3 + 1
    mm.staccato = (nxt == 1); mm.half_legato = (nxt == 2)
    mm_update_panel()
    renoise.app():show_status("Music Mouse: Articulation — " .. ({ "Staccato", "Half Legato", "Full Legato" })[nxt])
    return nil
  end
  if name == "h" then  -- cycle Treatment: Chord -> Arpeggiate -> Line -> Improvise
    mm.treatment = mm.treatment % 4 + 1
    mm.seq_i = 0; mm_restart_timer(); mm_update_panel()
    renoise.app():show_status("Music Mouse: Treatment — " .. TREATMENT_NAMES[mm.treatment])
    return nil
  end
  if name == "k" then mm_toggle_dark(); return nil end
  -- waveforms (each re-strikes the current chord, keeps Bell setting)
  if name == "u" then mm_set_waveform("Triangle"); return nil end
  if name == "i" then mm_set_waveform("Square"); return nil end
  if name == "o" then mm_set_waveform("Saw"); return nil end
  if name == "p" then mm_set_waveform("Sine"); return nil end
  if name == "m" then  -- cycle through the full waveform palette
    local idx = mm_wave_index_value() % #MM_WAVEFORMS + 1
    mm_set_waveform(MM_WAVEFORMS[idx]); return nil
  end
  if name == "b" then mm_set_bell(not mm.bell); return nil end   -- Bell / Sustain toggle
  if name == "l" then mm_clear_seeds(); return nil end           -- clear gravitation seeds
  if name == ";" or name == "semicolon" then mm_toggle_gravity_play(); return nil end  -- Gravity Play
  if name == "j" then  -- keyjazz punch mode: mouse aims silently, i/o/p triggers
    mm.keyjazz = not mm.keyjazz
    if mm.keyjazz then mm_all_notes_off() end
    mm_update_panel(); if mm_canvas then mm_canvas:update() end
    renoise.app():show_status("Music Mouse: Keyjazz punch " .. (mm.keyjazz and "ON — mouse silent; punch with i/o/p" or "OFF"))
    return nil
  end
  if name == "n" then  -- Sync-to-BPM toggle
    mm.sync_bpm = not mm.sync_bpm; mm_restart_timer(); mm_update_panel(); mm_save_prefs()
    renoise.app():show_status("Music Mouse: Sync to BPM " .. (mm.sync_bpm and "ON" or "OFF")); return nil
  end
  if name == "v" then  -- cycle Pattern-Applies target (All / Melody / Bass)
    local idx = mm_pattarget_index() % #MM_PATTARGET_KEYS + 1
    mm.pat_target = MM_PATTARGET_KEYS[idx]
    mm_play_chord(mm_compute_voices()); mm_update_panel(); if mm_canvas then mm_canvas:update() end
    renoise.app():show_status("Music Mouse: Pattern Applies — " .. MM_PATTARGET_ITEMS[idx]); return nil
  end

  -- Anything Music Mouse doesn't map → pass through to Renoise (your shortcuts stay live)
  return key
end

--------------------------------------------------------------------------------
-- Dialog open / close + lifecycle safety
--------------------------------------------------------------------------------

function mm_toggle_dark()
  mm.dark = not mm.dark
  if mm_canvas then mm_canvas:update() end
  renoise.app():show_status("Music Mouse theme: " .. (mm.dark and "Dark" or "Light"))
end

-- MM 'help' key: re-initialize all program values to their defaults
function mm_reinit()
  mm.scale_key = "diatonic"; mm.transpose = 0; mm.interval = 1
  mm.pattern_on = false; mm.pattern_idx = 6; mm.pat_step = 1; mm.pat_target = "all"
  mm.format_pairs = false; mm.mouse_contrary = false; mm.pattern_contrary = false; mm.grouping = false
  mm.staccato = false; mm.half_legato = false; mm.loudness = 0.8; mm.sound_on = true
  mm.treatment = 1; mm.mute = { false, false, false, false }
  mm.tempo_basic = 100; mm.tempo_alt = 200; mm.tempo_use_alt = false
  mm.frozen = false
  mm_all_notes_off()
  mm_rebuild_axis()
  mm.deg_x = mm_frac_to_degree(mm.mx); mm.deg_y = mm_frac_to_degree(1 - mm.my)
  mm_restart_timer()
  if mm_update_panel then mm_update_panel() end
  if mm_canvas then mm_canvas:update() end
  if mm_pat_canvas then mm_pat_canvas:update() end
  renoise.app():show_status("Music Mouse: re-initialized all values (help)")
end

function pakettiMusicMouseClose()
  mm_save_prefs()        -- retain tempo + loudness across close/reopen
  mm_stop_timer()
  mm.record = false
  mm_all_notes_off()
  if PakettiMusicMouseLaunchpadSetMode then PakettiMusicMouseLaunchpadSetMode("off") end  -- release Launchpad LEDs + MIDI
  if dialog and dialog.visible then dialog:close() end
  dialog = nil
end

-- Detach on song release to avoid the canvas/observer SIGSEGV class (see memory note)
local function mm_doc_release()
  pakettiMusicMouseClose()
end

local MM_KEYMAP_TEXT = [[
MUSIC MOUSE — KEYBOARD MAP
(everything else passes through to Renoise:
 F5-F12, Alt/Option, Shift+Cmd, unlisted keys)

PITCH / HARMONY
  q w e r t y  Chromatic Octatonic MidEast
               Diatonic Pentatonic Quartal
  cmd-q..y     same, quiet (no replay)
  z / x        transpose down / up
  c            reset transpose       (cmd = quiet)
  shift-z/x    interval - / +    shift-c  reset
  tab          cycle tuning (12-TET -> Paketti microtonals)

PATTERNS
  a            patterning on/off
  0-9          select pattern 1..10
  v            applies: All / Melody / Bass
  s            pattern motion: parallel/contrary

VOICING
  d  mouse motion parallel/contrary
  f  format chord-melody / voice-pairs
  (grouping = checkbox)

ARTICULATION / LOUDNESS / MUTING
  g            cycle Staccato/Half/Full Legato
  /            staccato / legato
  shift-/      half / full legato
  , .          loudness down / up  (shift-. = max)
  shift-1..9   mute voice 1..9
  ~  reverse mutes     shift-~  all on
  (Voices 4-9 selector in panel: 5+ = rich chords)

TEMPO
  - +  tempo1 down/up    [ ]  tempo2
  \    use tempo 1/2     n    sync to BPM

TREATMENT
  h               cycle Chord/Arp/Line/Improvise
  cmd-1..4 / F1-F4  Chord Arp Line Improvise

SOUND
  u i o p  Triangle Square Saw Sine
  m        cycle full waveform palette
  b        Bell / Sustain
  cmd-up/down   prev / next instrument

PERFORMANCE
  space        freeze (stops record too)
  enter        lock notes   shift-enter release
  right-shift  Record to Pattern on/off
  j            Keyjazz punch (mouse silent; i/o/p triggers)
  click        drop gravitation seed (cursor pulled to it)
  right-click  remove nearest seed     l  clear all seeds
  ;            Gravity Play (= shift-comma; also button / MIDI)
  delete       disconnect mouse
  k  theme    home  re-init    esc  close
]]

function mm_show_keys()
  local kvb = renoise.ViewBuilder()
  local content = kvb:column{ margin = 10,
    kvb:multiline_text{ text = MM_KEYMAP_TEXT, width = 360, height = 560, font = "mono" } }
  renoise.app():show_custom_dialog("Music Mouse — Keyboard Map", content)
end

function pakettiMusicMouseShow()
  if dialog and dialog.visible then
    pakettiMusicMouseClose()
    return
  end

  vb = renoise.ViewBuilder()
  mm_load_prefs()        -- restore retained tempo + loudness
  mm.mouse_active = true
  mm.sound_on = true
  mm_rebuild_axis()
  mm.deg_x = mm_frac_to_degree(mm.mx)
  mm.deg_y = mm_frac_to_degree(1 - mm.my)

  mm_canvas = vb:canvas{
    width = MM_W,
    height = MM_H,
    mode = "plain",
    render = mm_render,
    mouse_handler = mm_mouse_handler,
    mouse_events = { "down", "up", "move", "drag", "exit" },
  }

  mm_pat_canvas = vb:canvas{
    width = MM_PAT_W,
    height = MM_PAT_H,
    mode = "plain",
    render = mm_pat_render,
    mouse_handler = mm_pat_mouse,
    mouse_events = { "down", "up", "move", "drag", "exit" },
  }

  local content = vb:row{
    margin = 8, spacing = 10,
    vb:column{
      spacing = 4,
      mm_controls_column(vb),
      vb:row{
        spacing = 4,
        vb:text{ text = "Wave", width = 38 },
        vb:popup{ id = "mm_wave_popup", width = 188, items = MM_WAVEFORMS, value = mm_wave_index_value(),
          notifier = function(i) if not mm_ui_busy then mm_set_waveform(MM_WAVEFORMS[i]) end end },
      },
      vb:row{
        spacing = 4,
        vb:text{ text = "Mode", width = 38 },
        vb:switch{ id = "mm_mode_switch", width = 188, items = { "Sustain", "Bell" }, value = (mm.bell and 2 or 1),
          notifier = function(i) if not mm_ui_busy then mm_set_bell(i == 2) end end },
      },
      vb:button{ text = "Generate New Pakettified Instrument", width = 230, notifier = pakettiMusicMouseGenerateInstrument },
      vb:row{
        spacing = 4,
        vb:button{ text = "Gravity Play (;)", width = 150, notifier = mm_toggle_gravity_play },
        vb:button{ text = "Clear Seeds (l)", width = 76, notifier = mm_clear_seeds },
      },
      vb:text{ text = "Pattern Editor — drag bars (a + 0-9 contour)", font = "mono" },
      mm_pat_canvas,
      vb:row{
        spacing = 4,
        vb:button{ text = "Len -", width = 50, notifier = function() mm_pat_length_delta(-1) end },
        vb:button{ text = "Len +", width = 50, notifier = function() mm_pat_length_delta(1) end },
        vb:button{ text = "Reset Pattern", width = 122, notifier = mm_pat_reset },
      },
      vb:row{
        spacing = 4,
        vb:button{ text = "Keys...", width = 56, notifier = mm_show_keys },
        vb:button{ text = "Re-Init", width = 56, notifier = mm_reinit },
        vb:button{ text = "Light/Dark", width = 56, notifier = mm_toggle_dark },
        vb:button{ text = "Close", width = 56, notifier = pakettiMusicMouseClose },
      },
    },
    vb:column{ mm_canvas },
  }

  dialog = renoise.app():show_custom_dialog("Music Mouse — An Intelligent Instrument - Laurie Spiegel 1986", content, mm_keyhandler)
  mm_start_timer()
  renoise.app():show_status("Music Mouse: click 'Generate New Pakettified Instrument' (or select one), then move the mouse over the grid to play.")

  if not renoise.tool().app_release_document_observable:has_notifier(mm_doc_release) then
    renoise.tool().app_release_document_observable:add_notifier(mm_doc_release)
  end
end

--------------------------------------------------------------------------------
-- Launchpad controller — pads PLAY Music Mouse chords; LEDs mirror / ripple.
-- Layout learned via the probe (Esa confirmed row-by-row 1..8): Programmer mode,
-- note = row*10 + col (11..88), row 1 = bottom, col 1 = left. mk3 velocity palette.
-- Three modes (dialog popup / cycle key / MIDI):
--   off       — devices closed, LEDs cleared.
--   play      — press a pad -> punch the chord at that X/Y; LED mirrors the cursor.
--   raindrops — same triggering PLUS an expanding-ring light show (ambient + per press).
--------------------------------------------------------------------------------

local mm_lp = { mode = "off", in_dev = nil, out_dev = nil, timer = nil, frame = nil, drops = {}, tickn = 0, flash = {} }
local MM_LP_RING   = { 45, 41, 37, 33, 25, 21 }                         -- mk3 palette: blue->cyan->green ripple
local MM_LP_CURSOR = 21                                                 -- green: the live cursor pad (Play)
local MM_LP_FLASH  = 3                                                  -- white: a pad you just pressed
local MM_LP_PROG   = { 0xF0, 0x00, 0x20, 0x29, 0x02, 0x0D, 0x0E, 0x01, 0xF7 }  -- Mini mk3 Programmer mode

local function mm_lp_find(list)
  for _, n in ipairs(list or {}) do if n:lower():find("launchpad") then return n end end
  return nil
end

local function mm_lp_raw(note, color)
  if mm_lp.out_dev then pcall(function() mm_lp.out_dev:send { 0x90, note, color } end) end
end

local function mm_lp_clear_all()
  for r = 1, 8 do for c = 1, 8 do mm_lp_raw(r * 10 + c, 0) end end
  mm_lp.frame = nil
end

-- grid pad note (11..88) -> normalized cursor fraction (mx, my); nil if not a grid pad
local function mm_lp_note_frac(note)
  local r, c = math.floor(note / 10), note % 10
  if r < 1 or r > 8 or c < 1 or c > 8 then return nil end
  return (c - 1) / 7, (8 - r) / 7        -- col1=left=low X ; row8=top=my0=high pitch
end

-- normalized fraction -> nearest grid pad note
local function mm_lp_frac_note(mx, my)
  local c = math.max(1, math.min(8, math.floor((mx or 0) * 7 + 0.5) + 1))
  local r = math.max(1, math.min(8, 8 - math.floor((my or 0) * 7 + 0.5)))
  return r * 10 + c
end

-- diff-render a full frame (table note->color); only push the pads that changed
local function mm_lp_render(newframe)
  local prev = mm_lp.frame or {}
  for r = 1, 8 do for c = 1, 8 do
    local note = r * 10 + c
    local col = newframe[note] or 0
    if prev[note] ~= col then mm_lp_raw(note, col) end
  end end
  mm_lp.frame = newframe
end

-- punch the chord at a pad's X/Y (fires regardless of frozen / keyjazz, like i/o/p)
local function mm_lp_trigger(note)
  local mx, my = mm_lp_note_frac(note)
  if not mx then return end
  mm.mx, mm.my = mx, my
  mm.deg_x = mm_frac_to_degree(mm.mx)
  mm.deg_y = mm_frac_to_degree(1 - mm.my)
  mm_play_chord(mm_compute_voices())
  if mm_update_panel then mm_update_panel() end
  if mm_canvas then mm_canvas:update() end
end

local function mm_lp_on_midi(msg)
  local status = msg[1] or 0
  local note   = msg[2] or 0
  local vel    = msg[3] or 0
  if (status - (status % 16)) ~= 0x90 or vel == 0 then return end   -- note-on only
  if not mm_lp_note_frac(note) then return end                     -- ignore side/scene buttons
  if mm_lp.mode == "play" then
    mm_lp.flash[note] = 2
    mm_lp_trigger(note)
  elseif mm_lp.mode == "raindrops" then
    mm_lp.drops[#mm_lp.drops + 1] = { r = math.floor(note / 10), c = note % 10, age = 0 }
    mm_lp_trigger(note)
  end
end

local function mm_lp_tick()
  if mm_lp.mode == "off" or not mm_lp.out_dev then return end
  mm_lp.tickn = mm_lp.tickn + 1
  local frame = {}
  if mm_lp.mode == "play" then
    frame[mm_lp_frac_note(mm.mx, mm.my)] = MM_LP_CURSOR     -- mirror the cursor pad
    for note, f in pairs(mm_lp.flash) do
      if f > 0 then frame[note] = MM_LP_FLASH; mm_lp.flash[note] = f - 1 else mm_lp.flash[note] = nil end
    end
  elseif mm_lp.mode == "raindrops" then
    if mm_lp.tickn % 10 == 0 then                            -- ambient drop
      mm_lp.drops[#mm_lp.drops + 1] = { r = math.floor(mm_rand() * 8) + 1, c = math.floor(mm_rand() * 8) + 1, age = 0 }
    end
    local alive = {}
    for _, d in ipairs(mm_lp.drops) do
      for r = 1, 8 do for c = 1, 8 do
        if math.floor(math.sqrt((r - d.r) ^ 2 + (c - d.c) ^ 2) + 0.5) == d.age then
          frame[r * 10 + c] = MM_LP_RING[math.min(#MM_LP_RING, d.age + 1)]
        end
      end end
      d.age = d.age + 1
      if d.age <= 12 then alive[#alive + 1] = d end          -- expire once the ring leaves the grid
    end
    mm_lp.drops = alive
  end
  mm_lp_render(frame)
end

local function mm_lp_open()
  if not mm_lp.out_dev then
    local on = mm_lp_find(renoise.Midi.available_output_devices())
    if on then mm_lp.out_dev = renoise.Midi.create_output_device(on) end
  end
  if not mm_lp.in_dev then
    local inn = mm_lp_find(renoise.Midi.available_input_devices())
    if inn then mm_lp.in_dev = renoise.Midi.create_input_device(inn, mm_lp_on_midi) end
  end
  if mm_lp.out_dev then pcall(function() mm_lp.out_dev:send(MM_LP_PROG) end); mm_lp_clear_all() end
  if not mm_lp.timer then mm_lp.timer = mm_lp_tick; renoise.tool():add_timer(mm_lp.timer, 60) end
  return (mm_lp.out_dev ~= nil) or (mm_lp.in_dev ~= nil)
end

local function mm_lp_shutdown()
  if mm_lp.timer and renoise.tool():has_timer(mm_lp.timer) then renoise.tool():remove_timer(mm_lp.timer) end
  mm_lp.timer = nil
  if mm_lp.out_dev then mm_lp_clear_all(); pcall(function() mm_lp.out_dev:close() end); mm_lp.out_dev = nil end
  if mm_lp.in_dev then pcall(function() mm_lp.in_dev:close() end); mm_lp.in_dev = nil end
  mm_lp.drops = {}; mm_lp.flash = {}; mm_lp.frame = nil
end

-- index for the dialog popup (1=Off, 2=Play, 3=Raindrops)
function PakettiMusicMouseLaunchpadModeIndex()
  return (mm_lp.mode == "play" and 2) or (mm_lp.mode == "raindrops" and 3) or 1
end

-- the one entry point — used by the dialog popup, the cycle key, and MIDI
function PakettiMusicMouseLaunchpadSetMode(mode)
  if mode ~= "off" and mode ~= "play" and mode ~= "raindrops" then mode = "off" end
  if mode == "off" then
    mm_lp.mode = "off"
    mm_lp_shutdown()
    renoise.app():show_status("Music Mouse Launchpad: OFF")
  else
    mm_lp.mode = mode
    if not mm_lp_open() then
      mm_lp.mode = "off"; mm_lp_shutdown()
      renoise.app():show_status("Music Mouse Launchpad: no 'Launchpad' device found")
    else
      renoise.app():show_status("Music Mouse Launchpad: " ..
        (mode == "play" and "PLAY — pads trigger chords" or "RAINDROPS — ripple light show + triggers"))
    end
  end
  if vb and vb.views and vb.views["mm_launchpad_popup"] then
    mm_ui_busy = true
    pcall(function() vb.views["mm_launchpad_popup"].value = PakettiMusicMouseLaunchpadModeIndex() end)
    mm_ui_busy = false
  end
end

function PakettiMusicMouseLaunchpadCycleMode()
  local nxt = { off = "play", play = "raindrops", raindrops = "off" }
  PakettiMusicMouseLaunchpadSetMode(nxt[mm_lp.mode] or "play")
end

--------------------------------------------------------------------------------
-- Registration (define-before-register: all functions above; registrations last)
--------------------------------------------------------------------------------

PakettiAddMenuEntry{ name = "Main Menu:Tools:Paketti:Instruments:Music Mouse Launchpad Mode (Cycle)", invoke = PakettiMusicMouseLaunchpadCycleMode }
renoise.tool():add_keybinding{ name = "Global:Paketti:Music Mouse Launchpad Mode Cycle", invoke = PakettiMusicMouseLaunchpadCycleMode }
renoise.tool():add_midi_mapping{ name = "Paketti:Music Mouse Launchpad Mode (Cycle)", invoke = function(message) if message:is_trigger() then PakettiMusicMouseLaunchpadCycleMode() end end }

PakettiAddMenuEntry{ name = "Main Menu:Tools:Paketti:Music Mouse...", invoke = pakettiMusicMouseShow }
PakettiAddMenuEntry{ name = "Main Menu:Tools:Paketti:Instruments:Music Mouse...", invoke = pakettiMusicMouseShow }
PakettiAddMenuEntry{ name = "Instrument Box:Paketti:Music Mouse...", invoke = pakettiMusicMouseShow }

renoise.tool():add_keybinding{ name = "Global:Paketti:Music Mouse Show/Hide", invoke = pakettiMusicMouseShow }

renoise.tool():add_midi_mapping{ name = "Paketti:Music Mouse Show/Hide", invoke = function(message)
  if message:is_trigger() then pakettiMusicMouseShow() end
end }

-- MIDI slider/knob -> song BPM (also drives the Music Mouse / Gravity Play tempo when Sync is on)
renoise.tool():add_midi_mapping{ name = "Paketti:Music Mouse BPM (Slider)", invoke = function(message)
  local song = renoise.song()
  if not song or not message:is_abs_value() then return end
  local bpm = math.floor(40 + (message.int_value / 127) * (240 - 40) + 0.5)
  song.transport.bpm = math.max(32, math.min(999, bpm))
  mm.sync_bpm = true
  mm_restart_timer()
  if mm_update_panel then mm_update_panel() end
  renoise.app():show_status("Music Mouse: BPM " .. bpm)
end }

-- MIDI slider/knob -> Gravity Play / pattern tempo (Music Mouse Tempo 1, Sync off), 20..400
renoise.tool():add_midi_mapping{ name = "Paketti:Music Mouse Tempo (Slider)", invoke = function(message)
  if not message:is_abs_value() then return end
  mm.sync_bpm = false
  mm.tempo_basic = math.floor(20 + (message.int_value / 127) * (400 - 20) + 0.5)
  mm_restart_timer()
  if mm_update_panel then mm_update_panel() end
  renoise.app():show_status("Music Mouse: Tempo 1 = " .. mm.tempo_basic)
end }

-- MIDI pad/button -> toggle Gravity Play (sequence the gravitation seeds in recorded order)
renoise.tool():add_midi_mapping{ name = "Paketti:Music Mouse Gravity Play (Toggle)", invoke = function(message)
  if message:is_trigger() then mm_toggle_gravity_play() end
end }
