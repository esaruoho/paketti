-- tests/record-to-new-instrument.lua
-- Unit test for Record to New Instrument (Toggle & Pedal MIDI mappings and keybindings)
-- Run with: lua tests/record-to-new-instrument.lua

local timers = {}
local registered_midi_mappings = {}
local registered_keybindings = {}
local registered_menu_entries = {}
local show_status_messages = {}

local sample_recording_active = false

function pakettiSampleRecordingStart()
  sample_recording_active = true
end

function pakettiSampleRecordingStop()
  sample_recording_active = false
end

function pakettiSampleRecordingIsActive()
  return sample_recording_active
end

function canInsertInstrument()
  return true
end

PAKETTI_API = 6.8

function PakettiAddMenuEntry(entry)
  renoise.tool():add_menu_entry(entry)
end

preferences = {
  pakettiQuickSampleTrackVolume = { value = false },
}
setmetatable(preferences, {
  __index = function(t, k)
    t[k] = { value = false }
    return t[k]
  end
})

local window = {
  sample_record_dialog_is_visible = false,
  active_upper_frame = 0,
  active_middle_frame = 0,
  lock_keyboard_focus = false,
}

local current_song = nil

renoise = {
  ApplicationWindow = {
    MIDDLE_FRAME_PATTERN_EDITOR = 1,
    MIDDLE_FRAME_MIXER = 2,
    MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR = 5,
  },
  app = function()
    return {
      window = window,
      show_status = function(self, msg)
        table.insert(show_status_messages, msg)
      end
    }
  end,
  tool = function()
    return {
      add_timer = function(self, fn, interval)
        timers[fn] = true
        return fn
      end,
      remove_timer = function(self, fn)
        timers[fn] = nil
      end,
      has_timer = function(self, fn)
        return timers[fn] == true
      end,
      add_midi_mapping = function(self, mapping)
        registered_midi_mappings[mapping.name] = mapping.invoke
      end,
      add_keybinding = function(self, kb)
        registered_keybindings[kb.name] = kb.invoke
      end,
      add_menu_entry = function(self, entry)
        registered_menu_entries[entry.name] = entry.invoke
      end,
    }
  end,
  song = function()
    return current_song
  end,
}

local function create_mock_song()
  local song = {
    selected_instrument_index = 1,
    selected_track_index = 1,
    instruments = {},
    patterns = {
      {
        tracks = {
          {
            lines = {
              { note_columns = { { note_string = "---", instrument_value = 255 } }, effect_columns = { { number_string = "00", amount_string = "00" } } }
            }
          }
        }
      }
    },
    tracks = {
      {
        name = "Track 01",
        devices = {},
        type = 1, -- sequencer track
        visible_note_columns = 1,
        visible_effect_columns = 1,
      }
    },
  }

  function song:insert_instrument_at(index)
    local inst = {
      name = "Instrument " .. string.format("%02d", index),
      samples = {
        {
          autoseek = false,
          autofade = false,
          sample_buffer = {
            has_sample_data = false,
            number_of_frames = 0,
            sample_rate = 44100,
            bit_depth = 16,
            number_of_channels = 2,
          }
        }
      },
      plugin_properties = { plugin_loaded = false },
      midi_output_properties = { device_name = "", channel = nil },
    }
    table.insert(self.instruments, index, inst)
    return inst
  end

  -- Initial instrument 1 (free, has_sample_data is false)
  song:insert_instrument_at(1)

  local meta = {
    __index = function(t, k)
      if k == "selected_instrument" then
        return t.instruments[t.selected_instrument_index]
      elseif k == "selected_sample" then
        local inst = t.instruments[t.selected_instrument_index]
        return inst and inst.samples[1] or nil
      elseif k == "selected_track" then
        return t.tracks[t.selected_track_index]
      end
      return rawget(t, k)
    end
  }
  setmetatable(song, meta)
  return song
end

current_song = create_mock_song()

-- Load the real implementation files
local function load_file(path)
  local f = assert(io.open(path, "r"))
  local content = f:read("*all")
  f:close()
  local chunk = assert(load(content, path))
  chunk()
end

load_file("PakettiRecorder.lua")
load_file("PakettiMidi.lua")

print("--- Running Record to New Instrument Tests ---")

-- Test 1: Start recording into an initial free instrument
assert(not PakettiRecordToNewInstrumentIsRecording(), "Should not be recording initially")
assert(PakettiRecordToNewInstrumentStart() == true, "First start should succeed")
assert(PakettiRecordToNewInstrumentIsRecording() == true, "Should report active recording")
assert(window.sample_record_dialog_is_visible == true, "Sample record dialog should open")
assert(sample_recording_active == true, "Sample recording should be started")
assert(#current_song.instruments == 1, "Should reuse free initial instrument without inserting a new one")
assert(current_song.selected_instrument_index == 1, "Selected instrument should be 1")

-- Calling start again while active should be guarded
assert(PakettiRecordToNewInstrumentStart() == false, "Duplicate start while recording must be rejected")
assert(#current_song.instruments == 1, "Duplicate start must not insert instruments")

-- Test 2: Stop recording
assert(PakettiRecordToNewInstrumentStop() == true, "Stop should succeed")
assert(sample_recording_active == false, "Sample recording should be stopped")

-- Test 3: Monitor completion
-- Simulate sample data arrival in instrument 1
current_song.instruments[1].samples[1].sample_buffer.has_sample_data = true
current_song.instruments[1].samples[1].sample_buffer.number_of_frames = 44100

local monitor_result = PakettiRecordToNewInstrumentMonitor()
assert(monitor_result == false, "Monitor should complete and return false to stop timer")
assert(not PakettiRecordToNewInstrumentIsRecording(), "Should no longer be recording")
assert(window.sample_record_dialog_is_visible == false, "Dialog should be closed on finish")
assert(window.active_upper_frame == 1, "Upper frame should be 1")
assert(window.active_middle_frame == 5, "Middle frame should be Sample Editor (5)")
assert(window.lock_keyboard_focus == true, "Keyboard focus should be locked")
assert(current_song.instruments[1].samples[1].autoseek == true, "autoseek should be set to true")
assert(current_song.instruments[1].samples[1].autofade == true, "autofade should be set to true")

-- CRUCIAL CHECK: Pattern editor must NOT have been imprinted!
local line1 = current_song.patterns[1].tracks[1].lines[1]
assert(line1.note_columns[1].note_string == "---", "Pattern editor note must NOT be modified")
assert(#current_song.tracks == 1, "No tracks should have been created or deleted")

-- Test 4: Next recording into occupied instrument creates a new instrument
assert(current_song.instruments[1].samples[1].sample_buffer.has_sample_data == true, "Instrument 1 is now occupied")
assert(PakettiRecordToNewInstrumentStart() == true, "Start should succeed")
assert(#current_song.instruments == 2, "Must insert a new instrument since instrument 1 has data")
assert(current_song.selected_instrument_index == 2, "New instrument (index 2) must be selected")
PakettiRecordToNewInstrumentStop()
current_song.instruments[2].samples[1].sample_buffer.has_sample_data = true
PakettiRecordToNewInstrumentMonitor()
assert(current_song.instruments[2].samples[1].autoseek == true, "Instrument 2 autoseek should be set")

-- Test 5: Toggle function
assert(not PakettiRecordToNewInstrumentIsRecording())
PakettiRecordToNewInstrumentToggle()
assert(PakettiRecordToNewInstrumentIsRecording() == true, "Toggle from idle should start recording")
assert(#current_song.instruments == 3, "New instrument 3 created")
PakettiRecordToNewInstrumentToggle()
assert(sample_recording_active == false, "Toggle while recording should stop recording")
current_song.instruments[3].samples[1].sample_buffer.has_sample_data = true
PakettiRecordToNewInstrumentMonitor()
assert(not PakettiRecordToNewInstrumentIsRecording())

-- Test 6: Pedal MIDI handler
assert(type(PakettiPedalRecordToNewInstrument) == "function", "Pedal handler must be defined")
-- Pedal Down (127)
PakettiPedalRecordToNewInstrument({ int_value = 127 })
assert(PakettiRecordToNewInstrumentIsRecording() == true, "Pedal value 127 must start recording")
local prev_count = #current_song.instruments
-- Redundant Pedal Down (127) must not re-trigger
PakettiPedalRecordToNewInstrument({ int_value = 127 })
assert(#current_song.instruments == prev_count, "Redundant 127 must not insert another instrument")
-- Pedal Up (0)
PakettiPedalRecordToNewInstrument({ int_value = 0 })
assert(sample_recording_active == false, "Pedal value 0 must stop recording")
-- Redundant Pedal Up (0) must not error or restart
PakettiPedalRecordToNewInstrument({ int_value = 0 })

-- Finalize pedal take
current_song.instruments[prev_count].samples[1].sample_buffer.has_sample_data = true
PakettiRecordToNewInstrumentMonitor()
assert(not PakettiRecordToNewInstrumentIsRecording())

-- Test 7: Verify MIDI mappings and keybindings registered
assert(registered_midi_mappings["Paketti:Record to New Instrument x[Toggle]"] ~= nil, "Toggle MIDI mapping must be registered")
assert(registered_midi_mappings["Paketti:Record to New Instrument (2nd) x[Toggle]"] ~= nil, "Toggle (2nd) MIDI mapping must be registered")
assert(registered_midi_mappings["Paketti:Record to New Instrument (Pedal) x[Knob]"] ~= nil, "Pedal MIDI mapping must be registered")
assert(registered_midi_mappings["Paketti:Record to New Instrument (Pedal) (2nd) x[Knob]"] ~= nil, "Pedal (2nd) MIDI mapping must be registered")

assert(registered_keybindings["Global:Paketti:Record to New Instrument (Toggle)"] ~= nil, "Global toggle keybinding must be registered")
assert(registered_keybindings["Sample Editor:Paketti:Record to New Instrument (Toggle)"] ~= nil, "Sample Editor toggle keybinding must be registered")
assert(registered_keybindings["Pattern Editor:Paketti:Record to New Instrument (Toggle)"] ~= nil, "Pattern Editor toggle keybinding must be registered")
assert(registered_keybindings["Mixer:Paketti:Record to New Instrument (Toggle)"] ~= nil, "Mixer toggle keybinding must be registered")

-- Verify invoke of registered MIDI toggle mapping
registered_midi_mappings["Paketti:Record to New Instrument x[Toggle]"]({ is_trigger = function() return true end })
assert(PakettiRecordToNewInstrumentIsRecording() == true, "Invoking registered MIDI toggle mapping should start recording")
registered_midi_mappings["Paketti:Record to New Instrument x[Toggle]"]({ is_trigger = function() return true end })
assert(sample_recording_active == false, "Invoking registered MIDI toggle mapping again should stop recording")
current_song.instruments[#current_song.instruments].samples[1].sample_buffer.has_sample_data = true
PakettiRecordToNewInstrumentMonitor()

-- Verify invoke of registered MIDI pedal mapping
registered_midi_mappings["Paketti:Record to New Instrument (Pedal) x[Knob]"]({ int_value = 127 })
assert(PakettiRecordToNewInstrumentIsRecording() == true, "Invoking registered MIDI pedal mapping with 127 should start recording")
registered_midi_mappings["Paketti:Record to New Instrument (Pedal) x[Knob]"]({ int_value = 0 })
assert(sample_recording_active == false, "Invoking registered MIDI pedal mapping with 0 should stop recording")
current_song.instruments[#current_song.instruments].samples[1].sample_buffer.has_sample_data = true
PakettiRecordToNewInstrumentMonitor()

print("ALL RECORD TO NEW INSTRUMENT TESTS PASSED!")
