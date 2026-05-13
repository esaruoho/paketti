--------------------------------------------------------------------------------
-- PakettiTriggerOnInput.lua
-- "Trigger Sample on Pattern Input During Record"
--
-- When the song is playing AND edit_mode is ON AND follow is OFF, typing a
-- note in the pattern is normally silent. This module fires a preview note
-- via trigger_instrument_note_on() so you hear what you're writing.
--
-- Uses pattern:add_line_edited_notifier (fires only on user keyboard/MIDI).
--
-- IMPORTANT: trigger_instrument_note_on must be called with the note as a
-- plain integer, NOT a table. Taktik confirmed (2026-05-13) that the
-- integer form works during playback; the table form is what made my
-- earlier "doesn't work during playback" conclusion wrong.
--------------------------------------------------------------------------------

PakettiTriggerOnInputEnabled = false

local toi_notifier_pattern_index = nil
local toi_active_notes = {}            -- {instr, track, note} tuples for note-off
local toi_debug = true                 -- flip to false once verified working

local function toi_log(msg)
  if toi_debug then
    print("[TriggerOnInput] " .. msg)
  end
end

--------------------------------------------------------------------------------
-- Core callback: fires when the user edits a line via keyboard/MIDI
--------------------------------------------------------------------------------
local function toi_on_line_edited(pos)
  if not PakettiTriggerOnInputEnabled then return end

  local song = renoise.song()
  if not song then return end

  if not song.transport.edit_mode then
    toi_log("skip: edit_mode off")
    return
  end

  -- Only fire when playback is RUNNING. When stopped, Renoise already
  -- auditions notes natively — re-triggering causes flam/phasing.
  if not song.transport.playing then
    toi_log("skip: playback stopped (Renoise auditions natively)")
    return
  end

  local pattern = song:pattern(pos.pattern)
  if not pattern then return end
  local pattern_track = pattern:track(pos.track)
  if not pattern_track then return end
  local line = pattern_track:line(pos.line)
  if not line then return end

  -- Sanity check the track: send/group/master can't play notes via this API
  local track = song:track(pos.track)
  if track and track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    toi_log(string.format("skip: track %d type %d is not sequencer", pos.track, track.type))
    return
  end

  -- Note off previously-triggered preview notes
  for _, ni in ipairs(toi_active_notes) do
    song:trigger_instrument_note_off(ni.instr, ni.track, ni.note)
  end
  toi_active_notes = {}

  -- Trigger each note column individually with integer-form note.
  -- (Table form had unreliable behavior; integer form is what Taktik confirmed.)
  local any_fired = false
  for col_idx = 1, #line.note_columns do
    local nc = line:note_column(col_idx)
    if nc.note_value < 120 then
      local instr_idx
      if nc.instrument_value ~= 255 then
        instr_idx = nc.instrument_value + 1
      else
        instr_idx = song.selected_instrument_index
      end

      local velocity = 1.0
      if nc.volume_value ~= 255 and nc.volume_value <= 127 then
        velocity = nc.volume_value / 127.0
      end

      local instr = song.instruments[instr_idx]
      if instr then
        song:trigger_instrument_note_on(instr_idx, pos.track, nc.note_value, velocity)
        table.insert(toi_active_notes, {instr = instr_idx, track = pos.track, note = nc.note_value})
        toi_log(string.format("fire: instr=%d '%s' track=%d note=%d vel=%.2f",
          instr_idx, instr.name, pos.track, nc.note_value, velocity))
        any_fired = true
      end
    end
  end

  if any_fired then
    renoise.app():show_status(string.format("TriggerOnInput: fired %d note(s) on track %d line %d", #toi_active_notes, pos.track, pos.line))
  end
end

--------------------------------------------------------------------------------
-- Notifier lifecycle
--------------------------------------------------------------------------------
local function toi_remove_notifier()
  local song = renoise.song()
  if not song then
    toi_notifier_pattern_index = nil
    return
  end
  if toi_notifier_pattern_index then
    local pat = song:pattern(toi_notifier_pattern_index)
    if pat and pat:has_line_edited_notifier(toi_on_line_edited) then
      pat:remove_line_edited_notifier(toi_on_line_edited)
      toi_log("detached from pattern " .. tostring(toi_notifier_pattern_index))
    end
    toi_notifier_pattern_index = nil
  end
end

local function toi_attach_notifier()
  toi_remove_notifier()
  local song = renoise.song()
  if not song then return end
  local pattern_index = song.selected_pattern_index
  local pattern = song:pattern(pattern_index)
  if not pattern then return end
  if not pattern:has_line_edited_notifier(toi_on_line_edited) then
    pattern:add_line_edited_notifier(toi_on_line_edited)
  end
  toi_notifier_pattern_index = pattern_index
  toi_log("attached to pattern " .. tostring(pattern_index))
end

--------------------------------------------------------------------------------
-- Pattern change observer
--------------------------------------------------------------------------------
local toi_pattern_observer_installed = false

local function toi_on_pattern_change()
  if not PakettiTriggerOnInputEnabled then return end
  toi_attach_notifier()
end

local function toi_install_pattern_observer()
  if toi_pattern_observer_installed then return end
  local song = renoise.song()
  if not song then return end
  if not song.selected_pattern_index_observable:has_notifier(toi_on_pattern_change) then
    song.selected_pattern_index_observable:add_notifier(toi_on_pattern_change)
  end
  toi_pattern_observer_installed = true
end

local function toi_remove_pattern_observer()
  if not toi_pattern_observer_installed then return end
  local song = renoise.song()
  if song and song.selected_pattern_index_observable:has_notifier(toi_on_pattern_change) then
    song.selected_pattern_index_observable:remove_notifier(toi_on_pattern_change)
  end
  toi_pattern_observer_installed = false
end

--------------------------------------------------------------------------------
-- Enable / Disable
--------------------------------------------------------------------------------
local function toi_enable()
  PakettiTriggerOnInputEnabled = true
  preferences.pakettiTriggerOnInputEnabled.value = true
  preferences:save_as("preferences.xml")
  toi_install_pattern_observer()
  toi_attach_notifier()
  renoise.app():show_status("Paketti: Trigger Sample on Pattern Input During Record ON")
  toi_log("ENABLED")
end

local function toi_disable()
  PakettiTriggerOnInputEnabled = false
  preferences.pakettiTriggerOnInputEnabled.value = false
  preferences:save_as("preferences.xml")
  toi_remove_notifier()
  toi_remove_pattern_observer()
  renoise.app():show_status("Paketti: Trigger Sample on Pattern Input During Record OFF")
  toi_log("DISABLED")
end

function PakettiTriggerOnInputToggle()
  if PakettiTriggerOnInputEnabled then
    toi_disable()
  else
    toi_enable()
  end
end

function PakettiTriggerOnInputOnNewDocument()
  if preferences.pakettiTriggerOnInputEnabled and preferences.pakettiTriggerOnInputEnabled.value then
    toi_enable()
  else
    PakettiTriggerOnInputEnabled = false
    toi_remove_notifier()
    toi_remove_pattern_observer()
  end
end

--------------------------------------------------------------------------------
-- Manual test: triggers selected instrument/track at C-4 via INTEGER-form note.
-- Use this to confirm trigger_instrument_note_on actually produces audio in
-- the current transport state, independent of the notifier path.
--------------------------------------------------------------------------------
function PakettiTriggerOnInputManualTest()
  local song = renoise.song()
  if not song then return end
  local track_idx = song.selected_track_index
  local track = song:track(track_idx)
  local note = 48  -- C-4

  if track and track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status(string.format("Manual test: track %d is not sequencer — using track 1", track_idx))
    track_idx = 1
  end

  local playing = song.transport.playing
  print(string.format("[ManualTest] playback=%s track=%d note=%d (C-4) — firing instr 1,2,3 with INTEGER note",
    tostring(playing), track_idx, note))

  for i = 1, 3 do
    local instr = song.instruments[i]
    if instr then
      print(string.format("[ManualTest]   instr %d (Renoise 0x%02X) name='%s' samples=%d",
        i, i - 1, instr.name, #instr.samples))
      song:trigger_instrument_note_on(i, track_idx, note, 1.0)
    else
      print(string.format("[ManualTest]   instr %d does not exist", i))
    end
  end

  renoise.app():show_status(string.format("Manual test fired instr 1/2/3 at C-4 on track %d (playing=%s, integer note)",
    track_idx, tostring(playing)))
end

--------------------------------------------------------------------------------
-- Registration (re-enabled 2026-05-13 after Taktik confirmed API works)
--------------------------------------------------------------------------------
renoise.tool():add_keybinding{
  name = "Global:Paketti:Trigger Sample on Pattern Input During Record Toggle",
  invoke = function() PakettiTriggerOnInputToggle() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Trigger Sample Manual Test",
  invoke = function() PakettiTriggerOnInputManualTest() end
}

PakettiAddMenuEntry{
  name = "Pattern Editor:Paketti:Trigger Sample on Pattern Input During Record Toggle",
  invoke = function() PakettiTriggerOnInputToggle() end,
  selected = function() return PakettiTriggerOnInputEnabled end
}

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Debug:Trigger Sample Manual Test",
  invoke = function() PakettiTriggerOnInputManualTest() end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Trigger Sample on Pattern Input During Record x[Toggle]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiTriggerOnInputToggle()
    end
  end
}
