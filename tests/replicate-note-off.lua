-- tests/replicate-note-off.lua
-- Unit tests for PakettiReplicateNoteOff and its registrations

local f = assert(io.open('PakettiPatternEditor.lua'))
local source = f:read('*a')
f:close()

local p1 = assert(source:find('-- Replicate Note Off', 1, true))
local p2 = assert(source:find('-- EditStep with Note Off', p1, true))
local block = source:sub(p1, p2 - 1)

local keys, menus, midi, statuses = {}, {}, {}, {}
local current
local app_window = { active_middle_frame = 1 }

PAKETTI_HAS_PHRASES = true

renoise = {
  Track = { TRACK_TYPE_SEQUENCER = 1, TRACK_TYPE_MASTER = 2, TRACK_TYPE_SEND = 3 },
  ApplicationWindow = {
    MIDDLE_FRAME_PATTERN_EDITOR = 1,
    MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR = 2,
  },
  song = function() return current end,
  app = function()
    return {
      window = app_window,
      show_status = function(_, s) table.insert(statuses, s) end
    }
  end,
  tool = function()
    return {
      add_keybinding = function(_, v) keys[v.name] = v.invoke end,
      add_midi_mapping = function(_, v) midi[v.name] = v.invoke end,
    }
  end
}

PakettiAddMenuEntry = function(v) menus[v.name] = v.invoke end

assert(load(block))()

local function make_note_col(note_val, delay_val, instr_val, vol_val, pan_val, fx_num, fx_amt)
  return {
    note_value = note_val or 121,
    instrument_value = instr_val or 255,
    volume_value = vol_val or 255,
    panning_value = pan_val or 255,
    delay_value = delay_val or 0,
    effect_number_value = fx_num or 0,
    effect_amount_value = fx_amt or 0,
    clear = function(self)
      self.note_value = 121
      self.instrument_value = 255
      self.volume_value = 255
      self.panning_value = 255
      self.delay_value = 0
      self.effect_number_value = 0
      self.effect_amount_value = 0
    end
  }
end

local function make_fixture(num_lines, num_cols)
  num_lines = num_lines or 8
  num_cols = num_cols or 1
  local s = {
    selected_track_index = 1,
    selected_note_column_index = 1,
    selected_line_index = 2,
    selection_in_pattern = nil,
    undo = {},
    tracks = {
      { type = renoise.Track.TRACK_TYPE_SEQUENCER, visible_note_columns = num_cols }
    },
    describe_undo = function(self, desc) table.insert(self.undo, desc) end
  }
  s.selected_track = s.tracks[1]

  local pt = { lines = {}, is_empty = false }
  for l = 1, num_lines do
    local line = { is_empty = false, note_columns = {} }
    for c = 1, num_cols do
      table.insert(line.note_columns, make_note_col(121))
    end
    table.insert(pt.lines, line)
  end
  function pt:line(idx) return self.lines[idx] end

  local pattern = { number_of_lines = num_lines, tracks = { pt } }
  function pattern:track(idx) return self.tracks[idx] end

  s.selected_pattern = pattern
  return s
end

-- Test 1: User's primary scenario
-- Cursor on row 2, Row 1 has C-4 (48), Row 2 has OFF (120), Row 3 has D-4 (50), Row 4 empty, Row 5 has E-4 (52), Row 6 empty
-- Replicate note off -> OFF repeats on every 2nd row (4, 6, 8) to end of pattern, preserving C-4, D-4, E-4!
current = make_fixture(8, 1)
current.selected_line_index = 2
current.selected_pattern:track(1):line(1).note_columns[1].note_value = 48
current.selected_pattern:track(1):line(2).note_columns[1].note_value = 120
current.selected_pattern:track(1):line(3).note_columns[1].note_value = 50
current.selected_pattern:track(1):line(5).note_columns[1].note_value = 52

keys["Pattern Editor:Paketti:Replicate Note Off Above + Current"]()

assert(#current.undo == 1, "Undo should be recorded")
local track_lines = current.selected_pattern:track(1).lines
assert(track_lines[1].note_columns[1].note_value == 48, "Row 1 note C-4 preserved")
assert(track_lines[2].note_columns[1].note_value == 120, "Row 2 note off preserved")
assert(track_lines[3].note_columns[1].note_value == 50, "Row 3 note D-4 preserved")
assert(track_lines[4].note_columns[1].note_value == 120, "Row 4 got note off")
assert(track_lines[5].note_columns[1].note_value == 52, "Row 5 note E-4 preserved")
assert(track_lines[6].note_columns[1].note_value == 120, "Row 6 got note off")
assert(track_lines[7].note_columns[1].note_value == 121, "Row 7 remains empty")
assert(track_lines[8].note_columns[1].note_value == 120, "Row 8 got note off")

-- Test 2: "Pattern Editor:Paketti:Replicate Note Off at Cursor" keybinding alias
current = make_fixture(8, 1)
current.selected_line_index = 2
current.selected_pattern:track(1):line(1).note_columns[1].note_value = 48
current.selected_pattern:track(1):line(2).note_columns[1].note_value = 120
keys["Pattern Editor:Paketti:Replicate Note Off at Cursor"]()
assert(current.selected_pattern:track(1):line(4).note_columns[1].note_value == 120, "Replicate Note Off at Cursor worked")

-- Test 3: Above Current Row option (cursor on row 3)
current = make_fixture(8, 1)
current.selected_line_index = 3
current.selected_pattern:track(1):line(1).note_columns[1].note_value = 48
current.selected_pattern:track(1):line(2).note_columns[1].note_value = 120
current.selected_pattern:track(1):line(3).note_columns[1].note_value = 50
keys["Pattern Editor:Paketti:Replicate Note Off Above Current Row"]()
assert(current.selected_pattern:track(1):line(3).note_columns[1].note_value == 50, "Row 3 note D-4 preserved")
assert(current.selected_pattern:track(1):line(4).note_columns[1].note_value == 120, "Row 4 got note off")
assert(current.selected_pattern:track(1):line(6).note_columns[1].note_value == 120, "Row 6 got note off")
assert(current.selected_pattern:track(1):line(8).note_columns[1].note_value == 120, "Row 8 got note off")

-- Test 4: Clearing old note offs on rows where source does NOT have note off
current = make_fixture(8, 1)
current.selected_line_index = 2
current.selected_pattern:track(1):line(1).note_columns[1].note_value = 48
current.selected_pattern:track(1):line(2).note_columns[1].note_value = 120
current.selected_pattern:track(1):line(3).note_columns[1].note_value = 120 -- old unwanted OFF
current.selected_pattern:track(1):line(5).note_columns[1].note_value = 120 -- old unwanted OFF
keys["Pattern Editor:Paketti:Replicate Note Off Above + Current"]()
assert(current.selected_pattern:track(1):line(3).note_columns[1].note_value == 121, "Old OFF on row 3 was cleared")
assert(current.selected_pattern:track(1):line(4).note_columns[1].note_value == 120, "Row 4 got note off")
assert(current.selected_pattern:track(1):line(5).note_columns[1].note_value == 121, "Old OFF on row 5 was cleared")
assert(current.selected_pattern:track(1):line(6).note_columns[1].note_value == 120, "Row 6 got note off")

-- Test 5: Note Off with delay preservation
current = make_fixture(8, 1)
current.selected_line_index = 2
current.selected_pattern:track(1):line(2).note_columns[1].note_value = 120
current.selected_pattern:track(1):line(2).note_columns[1].delay_value = 0x40
keys["Pattern Editor:Paketti:Replicate Note Off Above + Current"]()
assert(current.selected_pattern:track(1):line(4).note_columns[1].note_value == 120, "Row 4 note off")
assert(current.selected_pattern:track(1):line(4).note_columns[1].delay_value == 0x40, "Row 4 delay preserved")
assert(current.selected_pattern:track(1):line(6).note_columns[1].delay_value == 0x40, "Row 6 delay preserved")

-- Test 6: Preserving note properties (instrument, volume, panning, etc.)
current = make_fixture(8, 1)
current.selected_line_index = 2
current.selected_pattern:track(1):line(1).note_columns[1].note_value = 48
current.selected_pattern:track(1):line(2).note_columns[1].note_value = 120
local r3 = current.selected_pattern:track(1):line(3).note_columns[1]
r3.note_value = 60
r3.instrument_value = 5
r3.volume_value = 80
r3.panning_value = 40
r3.delay_value = 15
r3.effect_number_value = 2
r3.effect_amount_value = 33
keys["Pattern Editor:Paketti:Replicate Note Off Above + Current"]()
assert(r3.note_value == 60)
assert(r3.instrument_value == 5)
assert(r3.volume_value == 80)
assert(r3.panning_value == 40)
assert(r3.delay_value == 15)
assert(r3.effect_number_value == 2)
assert(r3.effect_amount_value == 33)

-- Test 7: Track scope across multiple columns
current = make_fixture(8, 2)
current.selected_line_index = 2
-- Col 1 has OFF on row 2
current.selected_pattern:track(1):line(2).note_columns[1].note_value = 120
-- Col 2 has OFF on row 1
current.selected_pattern:track(1):line(1).note_columns[2].note_value = 120
keys["Pattern Editor:Paketti:Replicate Note Off Track Above + Current"]()
local p_track = current.selected_pattern:track(1)
-- Col 1 gets OFF on even rows
assert(p_track:line(4).note_columns[1].note_value == 120)
assert(p_track:line(6).note_columns[1].note_value == 120)
-- Col 2 gets OFF on odd rows
assert(p_track:line(3).note_columns[2].note_value == 120)
assert(p_track:line(5).note_columns[2].note_value == 120)

-- Test 8: Column scope with multiple columns only affects selected column
current = make_fixture(8, 2)
current.selected_note_column_index = 1
current.selected_line_index = 2
current.selected_pattern:track(1):line(2).note_columns[1].note_value = 120
current.selected_pattern:track(1):line(4).note_columns[2].note_value = 72 -- Col 2 note
keys["Pattern Editor:Paketti:Replicate Note Off Above + Current"]()
assert(current.selected_pattern:track(1):line(4).note_columns[1].note_value == 120, "Col 1 got note off")
assert(current.selected_pattern:track(1):line(4).note_columns[2].note_value == 72, "Col 2 note completely untouched")

-- Test 9: No note offs in source range
current = make_fixture(8, 1)
current.selected_line_index = 2
current.selected_pattern:track(1):line(1).note_columns[1].note_value = 48
current.selected_pattern:track(1):line(2).note_columns[1].note_value = 50
keys["Pattern Editor:Paketti:Replicate Note Off Above + Current"]()
assert(#current.undo == 0, "No undo recorded when no note offs found")
assert(statuses[#statuses]:find("No note offs found in source range", 1, true))

-- Test 10: On last row
current = make_fixture(8, 1)
current.selected_line_index = 8
keys["Pattern Editor:Paketti:Replicate Note Off Above + Current"]()
assert(#current.undo == 0)
assert(statuses[#statuses]:find("You are on the last row", 1, true))

-- Test 11: MIDI mappings
current = make_fixture(8, 1)
current.selected_line_index = 2
current.selected_pattern:track(1):line(2).note_columns[1].note_value = 120
midi["Paketti:Replicate Note Off Above + Current"]({ is_trigger = function() return false end })
assert(#current.undo == 0, "Non-trigger MIDI does nothing")
midi["Paketti:Replicate Note Off Above + Current"]({ is_trigger = function() return true end })
assert(#current.undo == 1, "Trigger MIDI executed")
assert(current.selected_pattern:track(1):line(4).note_columns[1].note_value == 120)

-- Test 12: Menus
current = make_fixture(8, 1)
current.selected_line_index = 2
current.selected_pattern:track(1):line(2).note_columns[1].note_value = 120
menus["Pattern Editor:Paketti:Replicate:Replicate Note Off Above + Current"]()
assert(current.selected_pattern:track(1):line(4).note_columns[1].note_value == 120)

-- Test 13: Non-sequencer track rejection
current = make_fixture(8, 1)
current.tracks[1].type = renoise.Track.TRACK_TYPE_MASTER
current.selected_track = current.tracks[1]
keys["Pattern Editor:Paketti:Replicate Note Off Above + Current"]()
assert(statuses[#statuses]:find("Select a sequencer track", 1, true))

-- Test 14: Phrase Editor replication
current = {
  selected_phrase_line_index = 2,
  selected_phrase_note_column_index = 1,
  undo = {},
  describe_undo = function(self, desc) table.insert(self.undo, desc) end,
  selected_phrase = {
    number_of_lines = 4,
    visible_note_columns = 1,
    lines = {
      { note_columns = { make_note_col(48) } },
      { note_columns = { make_note_col(120) } },
      { note_columns = { make_note_col(50) } },
      { note_columns = { make_note_col(121) } },
    },
    line = function(self, idx) return self.lines[idx] end
  }
}
renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
keys["Phrase Editor:Paketti:Replicate Note Off Above + Current"]()
assert(current.selected_phrase.lines[3].note_columns[1].note_value == 50, "Phrase line 3 note intact")
assert(current.selected_phrase.lines[4].note_columns[1].note_value == 120, "Phrase line 4 got note off")

print("replicate-note-off: all tests passed successfully!")
