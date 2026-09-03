--[[============================================================================
PakettiRemoveEmptyColumns.lua

Compact Columns to the Left.

Paketti already has three ways to HIDE trailing unused columns
(PakettiHideAllUnusedColumns in PakettiViews.lua, deleteUnusedColumns and
PakettiRemoveUnusedColumns in PakettiPatternEditor.lua). None of them close
GAPS: a track with notes in columns 1 and 4 keeps four columns visible, with
two empty ones stranded in the middle.

This closes those gaps. For each track it finds every note/effect column that
holds data anywhere in the song, slides them left in their original order, and
then sets the visible column count to what is left.

Because it uses Renoise's track-level column swaps, note column names and note
column mute states travel with their columns.

A column that holds data but was hidden by the user gets revealed again - the
visible count is raised to cover every column that actually has something in
it, so this never buries data.
============================================================================]]--

local function PakettiCCLCountUsed(used)
  local count = 0
  for i = 1, #used do
    if used[i] then count = count + 1 end
  end
  return count
end

-- Walks every pattern once and marks which note/effect columns of this track
-- hold data. Bails out early as soon as every column has been accounted for.
local function PakettiCCLScanTrack(song, track_index, max_note_columns, max_effect_columns)
  local note_used = {}
  local effect_used = {}

  for column = 1, max_note_columns do note_used[column] = false end
  for column = 1, max_effect_columns do effect_used[column] = false end

  local note_remaining = max_note_columns
  local effect_remaining = max_effect_columns

  for pattern_index = 1, #song.patterns do
    if note_remaining == 0 and effect_remaining == 0 then break end

    local pattern = song.patterns[pattern_index]
    local pattern_track = pattern.tracks[track_index]

    -- Automation lives outside note/effect columns, so an empty pattern track
    -- can never contribute a used column.
    if not pattern_track.is_empty then
      for line_index = 1, pattern.number_of_lines do
        if note_remaining == 0 and effect_remaining == 0 then break end

        local line = pattern_track.lines[line_index]
        if not line.is_empty then
          if note_remaining > 0 then
            for column = 1, max_note_columns do
              if not note_used[column] and not line.note_columns[column].is_empty then
                note_used[column] = true
                note_remaining = note_remaining - 1
              end
            end
          end

          if effect_remaining > 0 then
            for column = 1, max_effect_columns do
              if not effect_used[column] and not line.effect_columns[column].is_empty then
                effect_used[column] = true
                effect_remaining = effect_remaining - 1
              end
            end
          end
        end
      end
    end
  end

  return note_used, effect_used
end

-- True when at least one used column sits to the right of a gap.
local function PakettiCCLNeedsCompacting(used)
  local target = 1
  for column = 1, #used do
    if used[column] then
      if column ~= target then return true end
      target = target + 1
    end
  end
  return false
end

-- Slides every used column left, keeping their relative order. swap_callback
-- performs the matching song-wide Renoise column swap.
local function PakettiCCLCompact(used, swap_callback)
  local write_column = 1
  local swap_count = 0

  for read_column = 1, #used do
    if used[read_column] then
      if read_column ~= write_column then
        swap_callback(write_column, read_column)
        used[write_column], used[read_column] = used[read_column], used[write_column]
        swap_count = swap_count + 1
      end
      write_column = write_column + 1
    end
  end

  return swap_count
end

-- Processes one track. stats accumulates across tracks so the caller can print
-- a single summary. Returns true when the track was actually changed.
function PakettiCompactColumnsForTrack(track_index, stats)
  local song = renoise.song()
  local track = song.tracks[track_index]

  local max_note_columns = track.max_note_columns
  local max_effect_columns = track.max_effect_columns
  if max_note_columns == 0 and max_effect_columns == 0 then return false end

  local old_visible_notes = track.visible_note_columns
  local old_visible_effects = track.visible_effect_columns

  local note_used, effect_used = PakettiCCLScanTrack(
    song, track_index, max_note_columns, max_effect_columns)

  local used_note_count = PakettiCCLCountUsed(note_used)
  local used_effect_count = PakettiCCLCountUsed(effect_used)

  local new_visible_notes = math.max(track.min_note_columns, used_note_count)

  -- Leave one effect column visible on any track that can have one, so there
  -- is always somewhere to type an effect command. Use Paketti's existing
  -- "Hide All Unused Columns" if you want the last one gone too.
  local effect_floor = track.min_effect_columns
  if max_effect_columns > 0 then effect_floor = math.max(effect_floor, 1) end
  local new_visible_effects = math.max(effect_floor, used_effect_count)

  local track_changed = false

  if PakettiCCLNeedsCompacting(note_used) then
    stats.note_swaps = stats.note_swaps + PakettiCCLCompact(note_used, function(a, b)
      track:swap_note_columns_at(a, b)
    end)
    track_changed = true
  end

  if PakettiCCLNeedsCompacting(effect_used) then
    stats.effect_swaps = stats.effect_swaps + PakettiCCLCompact(effect_used, function(a, b)
      track:swap_effect_columns_at(a, b)
    end)
    track_changed = true
  end

  if old_visible_notes ~= new_visible_notes then
    track.visible_note_columns = new_visible_notes
    stats.notes_hidden = stats.notes_hidden + math.max(0, old_visible_notes - new_visible_notes)
    stats.notes_shown = stats.notes_shown + math.max(0, new_visible_notes - old_visible_notes)
    track_changed = true
  end

  if old_visible_effects ~= new_visible_effects then
    track.visible_effect_columns = new_visible_effects
    stats.effects_hidden = stats.effects_hidden + math.max(0, old_visible_effects - new_visible_effects)
    stats.effects_shown = stats.effects_shown + math.max(0, new_visible_effects - old_visible_effects)
    track_changed = true
  end

  return track_changed
end

-- selected_only: only the currently selected track, otherwise every track.
function PakettiCompactColumns(selected_only)
  local song = renoise.song()

  local stats = {
    note_swaps = 0, effect_swaps = 0,
    notes_hidden = 0, effects_hidden = 0,
    notes_shown = 0, effects_shown = 0
  }

  song:describe_undo("Paketti: Compact Columns to the Left")

  local changed_tracks = 0
  if selected_only then
    if PakettiCompactColumnsForTrack(song.selected_track_index, stats) then
      changed_tracks = 1
    end
  else
    for track_index = 1, #song.tracks do
      if PakettiCompactColumnsForTrack(track_index, stats) then
        changed_tracks = changed_tracks + 1
      end
    end
  end

  local scope = selected_only and ("Track " .. song.selected_track_index) or "Song"

  if changed_tracks == 0 then
    renoise.app():show_status(string.format(
      "Compact Columns (%s): nothing to do, no gaps and no hideable columns found.", scope))
    return
  end

  local revealed = ""
  if stats.notes_shown > 0 or stats.effects_shown > 0 then
    revealed = string.format(", revealed %d note and %d effect column(s) that had hidden data",
      stats.notes_shown, stats.effects_shown)
  end

  local message = string.format(
    "Compact Columns (%s): %d track(s) changed, %d column(s) moved left, hid %d note and %d effect column(s)%s.",
    scope, changed_tracks, stats.note_swaps + stats.effect_swaps,
    stats.notes_hidden, stats.effects_hidden, revealed)

  print(message)
  renoise.app():show_status(message)
end

----------------------------------------------------------------------------
-- Menu entries, keybindings, MIDI mappings
----------------------------------------------------------------------------

PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Pattern Editor:Compact Columns to the Left", invoke=function() PakettiCompactColumns(false) end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Pattern Editor:Compact Columns to the Left (Selected Track)", invoke=function() PakettiCompactColumns(true) end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Compact Columns to the Left", invoke=function() PakettiCompactColumns(false) end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Compact Columns to the Left (Selected Track)", invoke=function() PakettiCompactColumns(true) end}
PakettiAddMenuEntry{name="Pattern Matrix:Paketti:Compact Columns to the Left", invoke=function() PakettiCompactColumns(false) end}

-- Sits alongside the existing Hide All Unused Columns entries, which trim from
-- the right; this one closes the gaps they leave behind.
PakettiAddMenuEntry{name="Main Menu:View:Paketti:Visible Columns:Compact Columns to the Left", invoke=function() PakettiCompactColumns(false) end}
PakettiAddMenuEntry{name="Main Menu:View:Paketti:Visible Columns:Compact Columns to the Left (Selected Track)", invoke=function() PakettiCompactColumns(true) end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Compact Columns to the Left", invoke=function() PakettiCompactColumns(false) end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Pattern Editor:Visible Columns:Compact Columns to the Left (Selected Track)", invoke=function() PakettiCompactColumns(true) end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Compact Columns to the Left", invoke=function() PakettiCompactColumns(false) end}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Tracks:Visible Columns:Compact Columns to the Left (Selected Track)", invoke=function() PakettiCompactColumns(true) end}

renoise.tool():add_keybinding{name="Global:Paketti:Compact Columns to the Left", invoke=function() PakettiCompactColumns(false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Compact Columns to the Left (Selected Track)", invoke=function() PakettiCompactColumns(true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Compact Columns to the Left", invoke=function() PakettiCompactColumns(false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Compact Columns to the Left (Selected Track)", invoke=function() PakettiCompactColumns(true) end}

renoise.tool():add_midi_mapping{name="Paketti:Compact Columns to the Left", invoke=function(message) if message:is_trigger() then PakettiCompactColumns(false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Compact Columns to the Left (Selected Track)", invoke=function(message) if message:is_trigger() then PakettiCompactColumns(true) end end}
