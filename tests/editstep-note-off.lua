-- tests/editstep-note-off.lua
-- Unit tests for EditStep Note Off engine, toggles, delay calculation, and preferences

local f = assert(io.open('PakettiPatternEditor.lua'))
local source = f:read('*a')
f:close()

local p1 = assert(source:find('-- EditStep with Note Off', 1, true))
local p2 = assert(source:find('-- Function to adjust the delay column', p1, true))
local block = source:sub(p1, p2 - 1)

local keys, menus, options_menus, midi, statuses = {}, {}, {}, {}, {}
local current
local app_window = { active_middle_frame = 1 }

PAKETTI_HAS_PHRASES = true

preferences = {
  pakettiEditStepNoteOffMode = { value = 1 }
}

local idle_notifiers = {}
local new_doc_notifiers = {}

renoise = {
  PatternLine = { EMPTY_NOTE = 121 },
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
      app_idle_observable = {
        add_notifier = function(_, fn) idle_notifiers[fn] = true end,
        remove_notifier = function(_, fn) idle_notifiers[fn] = nil end,
        has_notifier = function(_, fn) return idle_notifiers[fn] ~= nil end,
      },
      app_new_document_observable = {
        add_notifier = function(_, fn) new_doc_notifiers[fn] = true end,
        remove_notifier = function(_, fn) new_doc_notifiers[fn] = nil end,
        has_notifier = function(_, fn) return new_doc_notifiers[fn] ~= nil end,
      }
    }
  end
}

PakettiAddMenuEntry = function(v) menus[v.name] = v.invoke end
PakettiAddMenuOptionsEntry = function(v) options_menus[v.name] = v end

assert(load(block))()

local function make_note_col(note_val, delay_val)
  return {
    note_value = note_val or 121,
    instrument_value = 255,
    volume_value = 255,
    panning_value = 255,
    delay_value = delay_val or 0,
    effect_number_value = 0,
    effect_amount_value = 0,
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

local function make_fixture(num_lines, edit_step)
  num_lines = num_lines or 16
  edit_step = edit_step or 4
  local s = {
    selected_pattern_index = 1,
    selected_track_index = 1,
    selected_note_column_index = 1,
    selected_line_index = 1,
    undo = {},
    transport = {
      edit_mode = true,
      edit_step = edit_step
    },
    tracks = {
      { type = renoise.Track.TRACK_TYPE_SEQUENCER, visible_note_columns = 1, delay_column_visible = false }
    },
    describe_undo = function(self, desc) table.insert(self.undo, desc) end
  }
  s.selected_track = s.tracks[1]

  local pt = { lines = {}, is_empty = false }
  for l = 1, num_lines do
    local line = { is_empty = false, note_columns = { make_note_col(121) } }
    table.insert(pt.lines, line)
  end
  function pt:line(idx) return self.lines[idx] end

  local pattern = { number_of_lines = num_lines, tracks = { pt } }
  function pattern:track(idx) return self.tracks[idx] end

  s.selected_pattern = pattern
  return s
end

-- Test 1: Toggle shortcuts and Options menu selections
preferences.pakettiEditStepNoteOffMode.value = 1
assert(options_menus["EditStep Note Off: Off"].selected() == true)
assert(options_menus["EditStep Note Off: Above EditStep (Right Before)"].selected() == false)

-- Press Above EditStep toggle
keys["Pattern Editor:Paketti:Toggle EditStep Note Off (Above EditStep)"]()
assert(preferences.pakettiEditStepNoteOffMode.value == 2)
assert(options_menus["EditStep Note Off: Above EditStep (Right Before)"].selected() == true)
assert(idle_notifiers[PakettiEditStepNoteOffIdleTick] == true, "Idle notifier attached when mode active")

-- Press Below Input Note toggle (switches mode)
keys["Pattern Editor:Paketti:Toggle EditStep Note Off (Below Input Note)"]()
assert(preferences.pakettiEditStepNoteOffMode.value == 3)
assert(options_menus["EditStep Note Off: Below Input Note (Right After)"].selected() == true)

-- Press Halfway toggle (switches mode)
keys["Pattern Editor:Paketti:Toggle EditStep Note Off (Halfway)"]()
assert(preferences.pakettiEditStepNoteOffMode.value == 4)
assert(options_menus["EditStep Note Off: Halfway"].selected() == true)

-- Press Halfway toggle again (turns off)
keys["Pattern Editor:Paketti:Toggle EditStep Note Off (Halfway)"]()
assert(preferences.pakettiEditStepNoteOffMode.value == 1)
assert(options_menus["EditStep Note Off: Off"].selected() == true)
assert(idle_notifiers[PakettiEditStepNoteOffIdleTick] == nil, "Idle notifier detached when mode off")

-- Test 2: Mode 2 - Above EditStep (edit_step = 4)
-- Note placed at line 1 (00), cursor steps to line 5 (04).
-- OFF should land on line 4 (03: row above editstep).
preferences.pakettiEditStepNoteOffMode.value = 2
PakettiUpdateEditStepNoteOffNotifier()
current = make_fixture(16, 4)
current.selected_line_index = 1
-- Initial idle tick to seed tracking
PakettiEditStepNoteOffIdleTick()

-- User enters C-4 at line 1, cursor advances to line 5
current.selected_pattern:track(1):line(1).note_columns[1].note_value = 48
current.selected_line_index = 5
PakettiEditStepNoteOffIdleTick()

local track = current.selected_pattern:track(1)
assert(track:line(1).note_columns[1].note_value == 48, "Note C-4 intact at line 1")
assert(track:line(4).note_columns[1].note_value == 120, "OFF placed at line 4 (row 03: above editstep)")
assert(track:line(4).note_columns[1].delay_value == 0, "No delay on line 4")
assert(track:line(2).note_columns[1].note_value == 121, "Line 2 empty")
assert(track:line(3).note_columns[1].note_value == 121, "Line 3 empty")

-- Test 3: Mode 3 - Below Input Note (edit_step = 4)
-- Note placed at line 1 (00), cursor steps to line 5 (04).
-- OFF should land on line 2 (01: row below input note).
preferences.pakettiEditStepNoteOffMode.value = 3
PakettiUpdateEditStepNoteOffNotifier()
current = make_fixture(16, 4)
current.selected_line_index = 1
PakettiEditStepNoteOffIdleTick()

current.selected_pattern:track(1):line(1).note_columns[1].note_value = 48
current.selected_line_index = 5
PakettiEditStepNoteOffIdleTick()

track = current.selected_pattern:track(1)
assert(track:line(1).note_columns[1].note_value == 48, "Note C-4 intact at line 1")
assert(track:line(2).note_columns[1].note_value == 120, "OFF placed at line 2 (row 01: below input note)")
assert(track:line(3).note_columns[1].note_value == 121, "Line 3 empty")
assert(track:line(4).note_columns[1].note_value == 121, "Line 4 empty")

-- Test 4: Mode 4 - Halfway (edit_step = 4)
-- Note placed at line 1 (00), cursor steps to line 5 (04).
-- Halfway = 4 / 2 = 2. OFF lands on line 3 (02).
preferences.pakettiEditStepNoteOffMode.value = 4
PakettiUpdateEditStepNoteOffNotifier()
current = make_fixture(16, 4)
current.selected_line_index = 1
PakettiEditStepNoteOffIdleTick()

current.selected_pattern:track(1):line(1).note_columns[1].note_value = 48
current.selected_line_index = 5
PakettiEditStepNoteOffIdleTick()

track = current.selected_pattern:track(1)
assert(track:line(1).note_columns[1].note_value == 48, "Note C-4 intact at line 1")
assert(track:line(3).note_columns[1].note_value == 120, "OFF placed at line 3 (row 02: halfway)")
assert(track:line(3).note_columns[1].delay_value == 0, "No delay on even step halfway")

-- Test 5: Mode 4 - Halfway with ODD step (edit_step = 3)
-- Note placed at line 1 (00), cursor steps to line 4 (03).
-- Halfway = 3 / 2 = 1.5 lines!
-- OFF lands on line 2 (01) with delay_value = 128 (0x80) AND delay column auto-enabled!
preferences.pakettiEditStepNoteOffMode.value = 4
PakettiUpdateEditStepNoteOffNotifier()
current = make_fixture(16, 3)
assert(current.selected_track.delay_column_visible == false, "Delay column initially hidden")
current.selected_line_index = 1
PakettiEditStepNoteOffIdleTick()

current.selected_pattern:track(1):line(1).note_columns[1].note_value = 48
current.selected_line_index = 4
PakettiEditStepNoteOffIdleTick()

track = current.selected_pattern:track(1)
assert(track:line(1).note_columns[1].note_value == 48, "Note C-4 intact at line 1")
assert(track:line(2).note_columns[1].note_value == 120, "OFF placed at line 2 (row 01)")
assert(track:line(2).note_columns[1].delay_value == 128, "Delay calculated to 128 (0x80) for 1.5 lines!")
assert(current.selected_track.delay_column_visible == true, "Delay column was automatically enabled!")

-- Test 6: edit_step = 2 with any mode
-- Halfway = 2 / 2 = 1. OFF lands on line 2 (01).
preferences.pakettiEditStepNoteOffMode.value = 4
PakettiUpdateEditStepNoteOffNotifier()
current = make_fixture(16, 2)
current.selected_line_index = 1
PakettiEditStepNoteOffIdleTick()

current.selected_pattern:track(1):line(1).note_columns[1].note_value = 48
current.selected_line_index = 3
PakettiEditStepNoteOffIdleTick()

track = current.selected_pattern:track(1)
assert(track:line(1).note_columns[1].note_value == 48, "Note C-4 intact at line 1")
assert(track:line(2).note_columns[1].note_value == 120, "OFF placed on line 2 (row 01)")

-- Test 7: Guard - edit_step = 1 (step < 2) does nothing
preferences.pakettiEditStepNoteOffMode.value = 2
PakettiUpdateEditStepNoteOffNotifier()
current = make_fixture(16, 1)
current.selected_line_index = 1
PakettiEditStepNoteOffIdleTick()

current.selected_pattern:track(1):line(1).note_columns[1].note_value = 48
current.selected_line_index = 2
PakettiEditStepNoteOffIdleTick()

track = current.selected_pattern:track(1)
assert(track:line(2).note_columns[1].note_value == 121, "No OFF placed when edit_step < 2")

-- Test 8: Guard - edit_mode = false does nothing
preferences.pakettiEditStepNoteOffMode.value = 2
PakettiUpdateEditStepNoteOffNotifier()
current = make_fixture(16, 4)
current.transport.edit_mode = false
current.selected_line_index = 1
PakettiEditStepNoteOffIdleTick()

current.selected_pattern:track(1):line(1).note_columns[1].note_value = 48
current.selected_line_index = 5
PakettiEditStepNoteOffIdleTick()

track = current.selected_pattern:track(1)
assert(track:line(4).note_columns[1].note_value == 121, "No OFF placed when edit_mode is false")

-- Test 9: Navigation (cursor moves by 1 line without note entry) does not place OFF
preferences.pakettiEditStepNoteOffMode.value = 2
PakettiUpdateEditStepNoteOffNotifier()
current = make_fixture(16, 4)
current.selected_line_index = 1
PakettiEditStepNoteOffIdleTick()

-- User presses down arrow: cursor moves to line 2 (not step 4)
current.selected_line_index = 2
PakettiEditStepNoteOffIdleTick()
track = current.selected_pattern:track(1)
assert(track:line(1).note_columns[1].note_value == 121, "Line 1 still empty")
assert(track:line(2).note_columns[1].note_value == 121, "Line 2 still empty")
assert(track:line(4).note_columns[1].note_value == 121, "Line 4 still empty")

-- Test 10: MIDI trigger
preferences.pakettiEditStepNoteOffMode.value = 1
midi["Paketti:Toggle EditStep Note Off (Halfway)"]({ is_trigger = function() return false end })
assert(preferences.pakettiEditStepNoteOffMode.value == 1, "Non-trigger MIDI does nothing")
midi["Paketti:Toggle EditStep Note Off (Halfway)"]({ is_trigger = function() return true end })
assert(preferences.pakettiEditStepNoteOffMode.value == 4, "Trigger MIDI toggles Halfway on")

-- Test 11: Disable via Options menu entry
options_menus["EditStep Note Off: Off"].invoke()
assert(preferences.pakettiEditStepNoteOffMode.value == 1, "Turned off via menu")

print("editstep-note-off: all tests passed successfully!")
