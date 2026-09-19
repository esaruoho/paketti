-- PakettiPatternNoteTransforms.lua
-- Delay-aware note transforms for the Pattern Editor selection, ported from the
-- Phrase Value Processor (PakettiPhraseEditor.lua):
--   Mirror   - invert note pitch around a centre note
--   Quantize - pull notes toward the line grid (adjustable strength + preserve lengths)
--   Flip     - reverse note-event timing around the selection centre
-- Every transform plans all moves before mutating, so Safe mode can veto any
-- move that would push a note out of range instead of clamping or dropping it.

local NOTE_NAMES = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}
local function PPNT_NoteName(value)
  value = math.max(0, math.min(119, value))
  return NOTE_NAMES[(value % 12) + 1] .. math.floor(value / 12)
end

local NOTE_NAME_TO_BASE = {C=0,D=2,E=4,F=5,G=7,A=9,B=11}
local function PPNT_NoteNameToValue(text)
  local letter, accidental, octave = string.match(tostring(text), "^([A-Ga-g])([#%-]?)(%-?%d+)$")
  local base = letter and NOTE_NAME_TO_BASE[letter:upper()]
  if base then
    if accidental == "#" then base = base + 1 end
    local v = base + tonumber(octave) * 12
    return math.max(0, math.min(119, v))
  end
  return tonumber(text) or 60
end

local function PPNT_IsRealNote(value)
  return value ~= nil and value >= 0 and value < renoise.PatternLine.NOTE_OFF
end

local function PPNT_Clamp(value, lo, hi)
  return math.max(lo, math.min(hi, math.floor((tonumber(value) or 0) + 0.5)))
end

local function PPNT_PosToLineDelay(pos)
  local line = math.floor(pos)
  local delay = math.floor((pos - line) * 256 + 0.5)
  if delay >= 256 then line = line + 1 delay = delay - 256 end
  if delay < 0 then delay = 0 end
  return line, delay
end

-- Lean selection reader: returns start_line, end_line, and per-track note-column
-- lists for every sequencer track in the pattern selection. Effect columns are
-- ignored (these transforms act on note events only).
local function PPNT_GetSelection(song)
  local sel = song.selection_in_pattern
  if not sel then return nil end
  local tracks = {}
  for track_index = sel.start_track, sel.end_track do
    local track = song.tracks[track_index]
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      local visible_note_columns = track.visible_note_columns
      local total = visible_note_columns + track.visible_effect_columns
      local start_column = (track_index == sel.start_track) and sel.start_column or 1
      local end_column = (track_index == sel.end_track) and sel.end_column or total
      start_column = math.max(start_column, 1)
      end_column = math.min(end_column, total)
      local note_columns = {}
      for col = start_column, math.min(end_column, visible_note_columns) do
        note_columns[#note_columns + 1] = col
      end
      if #note_columns > 0 then
        tracks[#tracks + 1] = {track_index = track_index, note_columns = note_columns}
      end
    end
  end
  if #tracks == 0 then return nil end
  return sel.start_line, sel.end_line, tracks
end

local function PPNT_CollectEvents(pattern_track, start_line, end_line, col)
  local events = {}
  for line = start_line, end_line do
    local c = pattern_track:line(line):note_column(col)
    local note_value = c.note_value
    if PPNT_IsRealNote(note_value) or note_value == renoise.PatternLine.NOTE_OFF then
      events[#events + 1] = {
        line = line,
        note_value = note_value,
        instrument_value = c.instrument_value,
        volume_value = c.volume_value,
        panning_value = c.panning_value,
        delay_value = c.delay_value,
        effect_number_value = c.effect_number_value,
        effect_amount_value = c.effect_amount_value,
        is_off = note_value == renoise.PatternLine.NOTE_OFF
      }
    end
  end
  return events
end

local function PPNT_PlaceEvent(pattern_track, col, event, line, delay)
  local c = pattern_track:line(line):note_column(col)
  c.note_value = event.note_value
  c.instrument_value = event.instrument_value
  c.volume_value = event.volume_value
  c.panning_value = event.panning_value
  c.delay_value = delay
  c.effect_number_value = event.effect_number_value
  c.effect_amount_value = event.effect_amount_value
end

-- Shared mutate/report step for the timing transforms. plan entries are
-- {pattern_track, col, events, targets}; each target is {line, delay, dropped}.
local function PPNT_CommitPlan(song, tracks, plan, label, safe_mode, extra_status)
  if safe_mode then
    for _, p in ipairs(plan) do
      for _, target in ipairs(p.targets) do
        if target.dropped then
          renoise.app():show_status("Paketti: Safe mode - " .. label .. " would move notes out of range")
          return false
        end
      end
    end
  end

  song:describe_undo("Paketti Pattern " .. label)
  local moved, dropped, need_delay = 0, 0, false
  for _, p in ipairs(plan) do
    for _, event in ipairs(p.events) do
      p.pattern_track:line(event.line):note_column(p.col):clear()
    end
    for i, event in ipairs(p.events) do
      local target = p.targets[i]
      if target.dropped then
        dropped = dropped + 1
      else
        PPNT_PlaceEvent(p.pattern_track, p.col, event, target.line, target.delay)
        if target.delay > 0 then need_delay = true end
        moved = moved + 1
      end
    end
  end
  if need_delay then
    for _, t in ipairs(tracks) do song.tracks[t.track_index].delay_column_visible = true end
  end
  renoise.app():show_status(string.format("Paketti: %s moved %d note(s)%s%s", label, moved,
    extra_status or "",
    dropped > 0 and string.format(", dropped %d out of range", dropped) or ""))
  return true
end

-- Mirror: invert note pitch around a centre note. Out-of-range mirrors clamp to
-- 0..119; Safe mode aborts instead so no pitch relationship is silently bent.
function PakettiPatternMirrorNotes(center, safe_mode)
  local song = renoise.song()
  local start_line, end_line, tracks = PPNT_GetSelection(song)
  if not start_line then renoise.app():show_status("Paketti: No pattern selection to mirror") return end
  center = PPNT_Clamp(center, 0, 119)
  local pattern = song.selected_pattern

  if safe_mode then
    for _, t in ipairs(tracks) do
      local pattern_track = pattern:track(t.track_index)
      for line = start_line, end_line do
        for _, col in ipairs(t.note_columns) do
          local nv = pattern_track:line(line):note_column(col).note_value
          if PPNT_IsRealNote(nv) then
            local mirrored = center * 2 - nv
            if mirrored < 0 or mirrored > 119 then
              renoise.app():show_status("Paketti: Safe mode - Mirror would move a note out of range")
              return
            end
          end
        end
      end
    end
  end

  song:describe_undo("Paketti Pattern Mirror Notes")
  local changed = 0
  for _, t in ipairs(tracks) do
    local pattern_track = pattern:track(t.track_index)
    for line = start_line, end_line do
      for _, col in ipairs(t.note_columns) do
        local c = pattern_track:line(line):note_column(col)
        if PPNT_IsRealNote(c.note_value) then
          c.note_value = PPNT_Clamp(center * 2 - c.note_value, 0, 119)
          changed = changed + 1
        end
      end
    end
  end
  renoise.app():show_status(string.format("Paketti: Mirrored %d note(s) around %s", changed, PPNT_NoteName(center)))
end

-- Flip: reverse note-event timing around the selection centre (delay-aware).
function PakettiPatternFlipNotes(safe_mode)
  local song = renoise.song()
  local start_line, end_line, tracks = PPNT_GetSelection(song)
  if not start_line then renoise.app():show_status("Paketti: No pattern selection to flip") return end
  local pattern = song.selected_pattern
  local num_lines = pattern.number_of_lines

  local plan = {}
  for _, t in ipairs(tracks) do
    local pattern_track = pattern:track(t.track_index)
    for _, col in ipairs(t.note_columns) do
      local events = PPNT_CollectEvents(pattern_track, start_line, end_line, col)
      local targets = {}
      for i, event in ipairs(events) do
        local pos = event.line + event.delay_value / 256
        local new_line, new_delay = PPNT_PosToLineDelay(start_line + end_line - pos)
        targets[i] = {line = new_line, delay = new_delay,
          dropped = new_line < 1 or new_line > num_lines}
      end
      plan[#plan + 1] = {pattern_track = pattern_track, col = col, events = events, targets = targets}
    end
  end
  PPNT_CommitPlan(song, tracks, plan, "Flip", safe_mode, nil)
end

-- Quantize: pull notes toward the nearest line, delay-aware. strength 0..256 =
-- 0..100% grid pull. Preserve Lengths leaves note-offs where they are so note
-- durations do not shift.
function PakettiPatternQuantizeNotes(strength, preserve_lengths, safe_mode)
  local song = renoise.song()
  local start_line, end_line, tracks = PPNT_GetSelection(song)
  if not start_line then renoise.app():show_status("Paketti: No pattern selection to quantize") return end
  local pattern = song.selected_pattern
  local num_lines = pattern.number_of_lines
  local fraction = PPNT_Clamp(strength, 0, 256) / 256

  local plan = {}
  for _, t in ipairs(tracks) do
    local pattern_track = pattern:track(t.track_index)
    for _, col in ipairs(t.note_columns) do
      local events = PPNT_CollectEvents(pattern_track, start_line, end_line, col)
      local targets = {}
      for i, event in ipairs(events) do
        if preserve_lengths and event.is_off then
          targets[i] = {line = event.line, delay = event.delay_value, dropped = false}
        else
          local pos = event.line + event.delay_value / 256
          local target = math.floor(pos + 0.5)
          local new_line, new_delay = PPNT_PosToLineDelay(pos + (target - pos) * fraction)
          targets[i] = {line = new_line, delay = new_delay,
            dropped = new_line < 1 or new_line > num_lines}
        end
      end
      plan[#plan + 1] = {pattern_track = pattern_track, col = col, events = events, targets = targets}
    end
  end
  PPNT_CommitPlan(song, tracks, plan, "Quantize", safe_mode,
    preserve_lengths and " (preserve lengths)" or "")
end

--------------------------------------------------------------------------
-- Dialog
--------------------------------------------------------------------------

PakettiPatternNoteTransformsDialog = nil

function PakettiPatternNoteTransformsDialogShow()
  if PakettiPatternNoteTransformsDialog and PakettiPatternNoteTransformsDialog.visible then
    PakettiPatternNoteTransformsDialog:close()
    PakettiPatternNoteTransformsDialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local function safe_mode() return vb.views.paketti_pnt_safe.value end

  local content = vb:column{
    margin = 8, spacing = 6,
    vb:row{spacing = 4, vb:checkbox{id = "paketti_pnt_safe", value = false}, vb:text{text = "Safe mode (abort out-of-range moves)", width = 220}},
    vb:column{
      style = "group", margin = 6, spacing = 4, width = "100%",
      vb:text{text = "Timing", font = "bold"},
      vb:row{
        spacing = 6,
        vb:button{text = "Flip", width = 90, tooltip = "Reverse note timing around the selection centre", pressed = function() PakettiPatternFlipNotes(safe_mode()) end}
      },
      vb:row{
        spacing = 6,
        vb:text{text = "Quantize", width = 60},
        vb:valuebox{id = "paketti_pnt_quantize", min = 0, max = 256, value = 256, width = 58, tooltip = "Grid pull strength (00=none, 100=full)", tostring = function(v) return string.format("%d%%", math.floor(v / 256 * 100 + 0.5)) end, tonumber = function(s) return math.floor((tonumber((s:gsub("%%",""))) or 0) / 100 * 256 + 0.5) end},
        vb:checkbox{id = "paketti_pnt_preserve", value = true},
        vb:text{text = "Preserve Lengths", width = 110},
        vb:button{text = "Apply", width = 60, pressed = function() PakettiPatternQuantizeNotes(vb.views.paketti_pnt_quantize.value, vb.views.paketti_pnt_preserve.value, safe_mode()) end}
      }
    },
    vb:column{
      style = "group", margin = 6, spacing = 4, width = "100%",
      vb:text{text = "Pitch", font = "bold"},
      vb:row{
        spacing = 6,
        vb:text{text = "Mirror around", width = 90},
        vb:valuebox{id = "paketti_pnt_center", min = 0, max = 119, value = 60, width = 58, tostring = function(v) return PPNT_NoteName(v) end, tonumber = function(s) return PPNT_NoteNameToValue(s) end},
        vb:button{text = "Mirror", width = 90, tooltip = "Invert note pitch around the centre note", pressed = function() PakettiPatternMirrorNotes(vb.views.paketti_pnt_center.value, safe_mode()) end}
      }
    }
  }

  local function keyhandler(dialog, key)
    if key.name == "esc" then
      dialog:close()
      PakettiPatternNoteTransformsDialog = nil
    else
      return key
    end
  end

  PakettiPatternNoteTransformsDialog = renoise.app():show_custom_dialog("Paketti Pattern Note Transforms", content, keyhandler)
end

--------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Pattern Note Transforms Dialog...", invoke=function() PakettiPatternNoteTransformsDialogShow() end}
renoise.tool():add_keybinding{name="Global:Paketti:Pattern Note Transforms Dialog...", invoke=function() PakettiPatternNoteTransformsDialogShow() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Pattern Mirror Notes in Selection", invoke=function() PakettiPatternMirrorNotes(60, false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Pattern Flip Notes in Selection", invoke=function() PakettiPatternFlipNotes(false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Pattern Quantize Notes in Selection", invoke=function() PakettiPatternQuantizeNotes(256, true, false) end}

renoise.tool():add_midi_mapping{name="Paketti:Pattern Note Transforms Dialog [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPatternNoteTransformsDialogShow() end end}
renoise.tool():add_midi_mapping{name="Paketti:Pattern Mirror Notes in Selection [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPatternMirrorNotes(60, false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Pattern Flip Notes in Selection [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPatternFlipNotes(false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Pattern Quantize Notes in Selection [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPatternQuantizeNotes(256, true, false) end end}

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Pattern Editor:Pattern Note Transforms Dialog...", invoke=function() PakettiPatternNoteTransformsDialogShow() end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Pattern Note Transforms Dialog...", invoke=function() PakettiPatternNoteTransformsDialogShow() end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Pattern Note Transforms:Mirror Notes in Selection", invoke=function() PakettiPatternMirrorNotes(60, false) end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Pattern Note Transforms:Flip Notes in Selection", invoke=function() PakettiPatternFlipNotes(false) end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Pattern Note Transforms:Quantize Notes in Selection", invoke=function() PakettiPatternQuantizeNotes(256, true, false) end}
