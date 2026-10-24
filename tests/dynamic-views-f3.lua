-- tests/dynamic-views-f3.lua
-- Verifies that F3 (Dynamic View 02) always jumps to the Sample Editor middle frame
-- when not currently on the Sample Editor, and cycles only when already on it.
-- Run with: lua tests/dynamic-views-f3.lua

local status_messages = {}

local window = {
  active_upper_frame = 1,
  upper_frame_is_visible = true,
  active_middle_frame = 1, -- Starts in Pattern Editor
  active_lower_frame = 1,
  lower_frame_is_visible = false,
  disk_browser_is_visible = false,
  instrument_box_is_visible = false,
  sample_record_dialog_is_visible = false,
  pattern_matrix_is_visible = false,
  pattern_advanced_edit_is_visible = false,
  instrument_editor_is_detached = false,
  mixer_view_is_detached = false,
}

local current_song = {
  transport = {
    metronome_enabled = false,
    edit_mode = false,
    follow_player = false,
    playing = false,
  }
}

renoise = {
  ApplicationWindow = {
    UPPER_FRAME_TRACK_SCOPES = 1,
    UPPER_FRAME_MASTER_SPECTRUM = 2,
    MIDDLE_FRAME_PATTERN_EDITOR = 1,
    MIDDLE_FRAME_MIXER = 2,
    MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR = 3,
    MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES = 4,
    MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR = 5,
    MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION = 6,
    MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS = 7,
    MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR = 8,
    MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR = 9,
    LOWER_FRAME_TRACK_DSPS = 1,
    LOWER_FRAME_TRACK_AUTOMATION = 2,
    INSTRUMENT_BOX_SLOT_SIZE_SMALL = 1,
  },
  app = function()
    return {
      window = window,
      show_status = function(self, msg)
        table.insert(status_messages, msg)
      end
    }
  end,
  tool = function()
    return {
      bundle_path = "./",
      add_keybinding = function() end,
      add_midi_mapping = function() end,
      add_menu_entry = function() end,
    }
  end,
  song = function()
    return current_song
  end,
  Document = {
    create = function(name)
      return function(tbl)
        local props = {}
        local doc = {}
        function doc:add_property(name, obs)
          props[name] = obs
        end
        function doc:property(name)
          return props[name]
        end
        function doc:load_from(path) end
        function doc:save_as(path) end
        setmetatable(doc, {
          __index = function(t, k)
            return props[k]
          end
        })
        return doc
      end
    end,
    ObservableNumber = function(default_val)
      return { value = default_val or 1 }
    end,
    ObservableBoolean = function(default_val)
      return { value = default_val or false }
    end,
  }
}

io.exists = function(path) return false end

local test_clock = 100.0
os.clock = function()
  test_clock = test_clock + 1.0
  return test_clock
end

-- Load PakettiDynamicViews.lua
local f = assert(io.open("PakettiDynamicViews.lua", "r"))
local content = f:read("*all")
f:close()
local chunk = assert(load(content, "PakettiDynamicViews.lua"))
chunk()

print("--- Running Dynamic Views F3 Navigation Tests ---")

-- Configure Dynamic View 02 (F3):
-- Step 1: Sample Editor (value 6 in views_middle = index 5)
-- Step 2: Sample Keyzones (value 5 in views_middle = index 4)
-- Step 3: Sample Modulation (value 7 in views_middle = index 6)
-- Step 4: Sample Effects (value 8 in views_middle = index 7)
DynamicViewPrefs["dynamic_view02_middle_step1"].value = 6
DynamicViewPrefs["dynamic_view02_middle_step2"].value = 5
DynamicViewPrefs["dynamic_view02_middle_step3"].value = 7
DynamicViewPrefs["dynamic_view02_middle_step4"].value = 8

-- Configure Dynamic View 01 (F2):
-- Step 1: Pattern Editor (value 2 in views_middle = index 1)
-- Step 2: Pattern Editor (value 2)
DynamicViewPrefs["dynamic_view01_middle_step1"].value = 2
DynamicViewPrefs["dynamic_view01_middle_step2"].value = 2

-- TEST 1: From Pattern Editor (active_middle_frame = 1), press F3
window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
cycle_dynamic_view(2)
assert(window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR,
  "Pressing F3 from Pattern Editor MUST immediately jump to Sample Editor (5), got " .. tostring(window.active_middle_frame))

-- TEST 2: Already on Sample Editor (active_middle_frame = 5), press F3 again -> cycle to next step (Keyzones)
cycle_dynamic_view(2)
assert(window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES,
  "Pressing F3 while on Sample Editor should cycle to Step 2 (Keyzones, 4), got " .. tostring(window.active_middle_frame))

-- TEST 3: On Sample Keyzones (active_middle_frame = 4), press F3 -> MUST jump back to Sample Editor!
-- "if not on sample editor frame then f3 should always hit sample editor middle frame"
cycle_dynamic_view(2)
assert(window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR,
  "Pressing F3 while on Keyzones MUST return directly to Sample Editor (5), got " .. tostring(window.active_middle_frame))

-- TEST 4: From Mixer (active_middle_frame = 2), press F3 -> MUST jump to Sample Editor
window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER
cycle_dynamic_view(2)
assert(window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR,
  "Pressing F3 from Mixer MUST jump directly to Sample Editor (5), got " .. tostring(window.active_middle_frame))

-- TEST 5: From Sample Modulation (active_middle_frame = 6), press F3 -> MUST jump to Sample Editor
window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION
cycle_dynamic_view(2)
assert(window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR,
  "Pressing F3 from Sample Modulation MUST jump directly to Sample Editor (5), got " .. tostring(window.active_middle_frame))

-- TEST 6: From Sample Effects (active_middle_frame = 7), press F3 -> MUST jump to Sample Editor
window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS
cycle_dynamic_view(2)
assert(window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR,
  "Pressing F3 from Sample Effects MUST jump directly to Sample Editor (5), got " .. tostring(window.active_middle_frame))

-- TEST 7: From Sample Editor (active_middle_frame = 5), press F2 (Dynamic View 01)
-- Should go directly to Pattern Editor (1)!
cycle_dynamic_view(1)
assert(window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR,
  "Pressing F2 from Sample Editor MUST jump directly to Pattern Editor (1), got " .. tostring(window.active_middle_frame))

print("ALL DYNAMIC VIEWS F3 TESTS PASSED!")
