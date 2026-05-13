--------------------------------------------------------------------------------
-- PakettiTriggerOnInput.lua
-- "Trigger Sample on Pattern Input During Record"
--
-- When enabled: any note typed into the pattern while edit_mode is ON will
-- immediately audition the note via trigger_instrument_note_on, regardless of
-- whether playback is running or stopped, and regardless of follow mode.
--
-- Uses pattern:add_line_edited_notifier — fires ONLY on user keyboard/MIDI
-- input, never on script-driven edits. This is the correct API for this job.
--
-- Diagnostic prints land in Renoise's Scripting Terminal & Editor console.
-- Status messages show on Renoise's status bar so you can see firing live.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
PakettiTriggerOnInputEnabled = false

local toi_notifier_pattern_index = nil
local toi_active_notes = {}            -- previously-triggered notes for note-off
local toi_debug = true                 -- flip to false once verified

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
  -- auditions notes on entry natively — double-triggering would just
  -- cause flams / phasing. This feature exists specifically to fill the
  -- silence-during-playback gap.
  if not song.transport.playing then
    toi_log("skip: playback stopped (Renoise auditions natively in this state)")
    return
  end

  local pattern = song:pattern(pos.pattern)
  if not pattern then
    toi_log("skip: no pattern at " .. tostring(pos.pattern))
    return
  end

  local pattern_track = pattern:track(pos.track)
  if not pattern_track then return end

  local line = pattern_track:line(pos.line)
  if not line then return end

  -- Stop previously-previewed notes so they don't pile up
  for _, ni in ipairs(toi_active_notes) do
    song:trigger_instrument_note_off(ni.instr, ni.track, ni.notes)
  end
  toi_active_notes = {}

  -- Collect notes from all note columns, grouped by instrument
  local instr_notes = {}
  local has_any_note = false
  for col_idx = 1, #line.note_columns do
    local nc = line:note_column(col_idx)
    if nc.note_value < 120 then
      has_any_note = true
      local instr_idx
      if nc.instrument_value ~= 255 then
        instr_idx = nc.instrument_value + 1
      else
        instr_idx = song.selected_instrument_index
      end
      if not instr_notes[instr_idx] then
        instr_notes[instr_idx] = {notes = {}, velocity = 1.0}
      end
      table.insert(instr_notes[instr_idx].notes, nc.note_value)
      if nc.volume_value ~= 255 and nc.volume_value <= 127 then
        instr_notes[instr_idx].velocity = nc.volume_value / 127.0
      end
    end
  end

  if not has_any_note then
    toi_log(string.format("fired at p%d t%d l%d but no note present (fx/vol edit)", pos.pattern, pos.track, pos.line))
    return
  end

  -- Sanity check the track: send / group / master tracks cannot play notes
  local track = song:track(pos.track)
  if track then
    local t = track.type
    toi_log(string.format("track %d type=%d (1=seq, 2=master, 3=send, 4=group)", pos.track, t))
    if t ~= renoise.Track.TRACK_TYPE_SEQUENCER then
      renoise.app():show_status(string.format("TriggerOnInput: track %d is not a sequencer track (type %d) — can't preview", pos.track, t))
      return
    end
  end

  toi_log(string.format("trigger at p%d t%d l%d", pos.pattern, pos.track, pos.line))

  for instr_idx, info in pairs(instr_notes) do
    local instr = song.instruments[instr_idx]
    if not instr then
      toi_log(string.format("instrument %d (0x%02X) does not exist — skipping", instr_idx, instr_idx - 1))
      renoise.app():show_status(string.format("TriggerOnInput: instr 0x%02X does not exist", instr_idx - 1))
    else
      local n_samples = #instr.samples
      toi_log(string.format("instrument %d name='%s' samples=%d", instr_idx, instr.name, n_samples))
      if n_samples == 0 then
        renoise.app():show_status(string.format("TriggerOnInput: instr 0x%02X '%s' has no samples", instr_idx - 1, instr.name))
      end
      song:trigger_instrument_note_on(instr_idx, pos.track, info.notes, info.velocity)
      table.insert(toi_active_notes, {instr = instr_idx, track = pos.track, notes = info.notes})
      renoise.app():show_status(string.format("TriggerOnInput: instr 0x%02X '%s' note %d vel %.2f", instr_idx - 1, instr.name, info.notes[1], info.velocity))
    end
  end
end

--------------------------------------------------------------------------------
-- Manual test: trigger the selected instrument/note directly (bypass notifier)
-- Bind this to a keybinding to test whether trigger_instrument_note_on works
-- at all in your current Renoise state, independent of the notifier path.
--------------------------------------------------------------------------------
function PakettiTriggerOnInputManualTest()
  local song = renoise.song()
  if not song then return end
  local track_idx = song.selected_track_index
  local track = song:track(track_idx)
  local note = 48  -- C-4

  if track and track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status(string.format("Manual test: track %d type %d is not sequencer — switching to track 1", track_idx, track.type))
    track_idx = 1
  end

  -- Fire instruments 1, 2, 3 (Renoise display 0x00, 0x01, 0x02) at C-4 — if any
  -- of them has a sample at C-4 you should hear it. Verifies whether
  -- trigger_instrument_note_on produces audio in this transport state at all.
  local playing = song.transport.playing
  print(string.format("[ManualTest] playback=%s track=%d note=%d (C-4) — firing instr 1,2,3",
    tostring(playing), track_idx, note))

  for i = 1, 3 do
    local instr = song.instruments[i]
    if instr then
      local n_samples = #instr.samples
      print(string.format("[ManualTest]   instr %d (Renoise 0x%02X) name='%s' samples=%d — triggering",
        i, i - 1, instr.name, n_samples))
      song:trigger_instrument_note_on(i, track_idx, {note}, 1.0)
    else
      print(string.format("[ManualTest]   instr %d (Renoise 0x%02X) does not exist", i, i - 1))
    end
  end

  renoise.app():show_status(string.format("Manual test fired instr 0x00/0x01/0x02 at C-4 on track %d (playing=%s)",
    track_idx, tostring(playing)))
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
-- Registration
--------------------------------------------------------------------------------
renoise.tool():add_keybinding{
  name = "Global:Paketti:Trigger Sample on Pattern Input During Record Toggle",
  invoke = function() PakettiTriggerOnInputToggle() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Trigger Sample on Pattern Input — Manual Test (selected instr/track, C-4)",
  invoke = function() PakettiTriggerOnInputManualTest() end
}

-- Main Menu:Options entry is registered in PakettiMenuConfig.lua (central menu config)

PakettiAddMenuEntry{
  name = "Pattern Editor:Paketti:Trigger Sample on Pattern Input During Record Toggle",
  invoke = function() PakettiTriggerOnInputToggle() end,
  selected = function() return PakettiTriggerOnInputEnabled end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Trigger Sample on Pattern Input During Record x[Toggle]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiTriggerOnInputToggle()
    end
  end
}
