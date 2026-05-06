-- PakettiNoteReleaseGate.lua
-- MIDI note-on -> device active, note-off -> device inactive.
-- Robust replacement for the brittle prototype "Note Release Device Gate" tool.
--
-- Differences from the prototype:
--   * Device targets stored as {track_index, device_index}, never as raw refs,
--     so device insert/delete/swap can't dangle them. Resolved at fire-time.
--   * Polyphonic gate: a target stays ON until the LAST held note that
--     references it releases (per-target hold counter, not a global).
--   * Multiple targets across multiple tracks. Each target can be filtered to
--     a note range and (via global pref) a MIDI channel.
--   * Latch mode (note-on toggles, note-off ignored) for free-running effects.
--   * Automation writing dedup: same value on same line is not re-written.
--   * Pattern scanner is opt-in and only runs when at least one target exists.
--   * Targets persist across sessions via preferences.
--   * Lifecycle cleanup on tool unload + song change.

local NOTE_GATE = {
  midi_device = nil,
  midi_listening = false,
  -- per-target hold counter: target_key -> int
  hold_count = {},
  -- per-key-event -> target_keys it incremented (so note-off knows what to decrement)
  active_holds = {},
  -- target_key -> last automation value written at (pattern,line) -> dedup
  last_auto = {},
  -- targets: array of {track_index, device_index, note_lo, note_hi}
  targets = {},
  -- track_index -> last seen pattern_index:line for the scanner
  last_scan_key = nil,
}

------------------------------------------------------------------------
-- Target persistence
------------------------------------------------------------------------

local function serialize_targets(targets)
  local parts = {}
  for _, t in ipairs(targets) do
    table.insert(parts, string.format("%d,%d,%d,%d",
      t.track_index, t.device_index, t.note_lo, t.note_hi))
  end
  return table.concat(parts, ";")
end

local function deserialize_targets(s)
  local out = {}
  if not s or s == "" then return out end
  for chunk in string.gmatch(s, "[^;]+") do
    local ti, di, lo, hi = string.match(chunk, "^(-?%d+),(-?%d+),(-?%d+),(-?%d+)$")
    if ti and di and lo and hi then
      table.insert(out, {
        track_index = tonumber(ti),
        device_index = tonumber(di),
        note_lo = tonumber(lo),
        note_hi = tonumber(hi),
      })
    end
  end
  return out
end

local function save_targets()
  preferences.pakettiNoteGateTargets.value = serialize_targets(NOTE_GATE.targets)
  preferences:save_as("preferences.xml")
end

local function load_targets()
  NOTE_GATE.targets = deserialize_targets(preferences.pakettiNoteGateTargets.value)
end

local function target_key(t)
  return tostring(t.track_index) .. "/" .. tostring(t.device_index)
end

------------------------------------------------------------------------
-- Resolution (lazy — never trust a stored device ref)
------------------------------------------------------------------------

local function resolve_target(t)
  local song = renoise.song()
  local track = song.tracks[t.track_index]
  if not track then return nil end
  local device = track.devices[t.device_index]
  if not device then return nil end
  return device, track
end

------------------------------------------------------------------------
-- Automation writing (with dedup)
------------------------------------------------------------------------

local function get_pattern_index_from_playback()
  local song = renoise.song()
  local pos = song.transport.playback_pos
  if pos.sequence and song.sequencer and song.sequencer.pattern_sequence then
    local idx = song.sequencer.pattern_sequence[pos.sequence]
    if idx then return idx end
  end
  return song.selected_pattern_index
end

local function get_current_line()
  local song = renoise.song()
  if song.transport.playing then
    return song.transport.playback_pos.line
  end
  return song.selected_line_index
end

local function get_step_record_note_on_line()
  local song = renoise.song()
  if song.transport.playing then
    return song.transport.playback_pos.line
  end
  if song.transport.edit_mode and song.transport.edit_step > 0 then
    local line = song.selected_line_index - song.transport.edit_step
    if line < 1 then line = 1 end
    return line
  end
  return song.selected_line_index
end

local function write_active_automation(t, device, pattern_index, line, value)
  if not preferences.pakettiNoteGateWriteAutomation.value then return end

  local active_param = device.is_active_parameter
  if not active_param then return end

  local song = renoise.song()
  local pattern = song.patterns[pattern_index]
  if not pattern then return end
  local pattern_track = pattern.tracks[t.track_index]
  if not pattern_track then return end

  -- Dedup: skip write if the same target wrote the same value at this exact spot
  local dk = target_key(t)
  local stamp = string.format("%d:%d:%.2f", pattern_index, line, value)
  if NOTE_GATE.last_auto[dk] == stamp then return end
  NOTE_GATE.last_auto[dk] = stamp

  local automation = pattern_track:find_automation(active_param)
  if not automation then
    automation = pattern_track:create_automation(active_param)
  end
  if automation:has_point_at(line) then
    automation:remove_point_at(line)
  end
  automation:add_point_at(line, value)
end

------------------------------------------------------------------------
-- Device toggle
------------------------------------------------------------------------

local function set_target_active(t, active, pattern_index, line)
  local device = resolve_target(t)
  if not device then
    -- Target no longer exists — silently drop this fire (don't spam status)
    return
  end
  device.is_active = active
  write_active_automation(
    t, device,
    pattern_index or get_pattern_index_from_playback(),
    line or get_current_line(),
    active and 1.0 or 0.0
  )
end

local function release_all_targets()
  for _, t in ipairs(NOTE_GATE.targets) do
    local device = resolve_target(t)
    if device then device.is_active = false end
  end
  NOTE_GATE.hold_count = {}
  NOTE_GATE.active_holds = {}
end

------------------------------------------------------------------------
-- Polyphonic gate logic
------------------------------------------------------------------------

local function targets_for_note(note)
  local hits = {}
  for _, t in ipairs(NOTE_GATE.targets) do
    if note >= t.note_lo and note <= t.note_hi then
      table.insert(hits, t)
    end
  end
  return hits
end

local function gate_note_on(channel, note)
  local hits = targets_for_note(note)
  if #hits == 0 then return end

  local event_key = tostring(channel) .. ":" .. tostring(note)
  -- If a stale event_key exists (no matching note-off received), release it first
  if NOTE_GATE.active_holds[event_key] then
    -- treat as virtual note-off before re-applying
    for _, tk in ipairs(NOTE_GATE.active_holds[event_key]) do
      NOTE_GATE.hold_count[tk] = math.max(0, (NOTE_GATE.hold_count[tk] or 1) - 1)
    end
    NOTE_GATE.active_holds[event_key] = nil
  end

  local stamped = {}
  local song = renoise.song()
  local on_line = get_step_record_note_on_line()
  local on_pattern = song.selected_pattern_index

  for _, t in ipairs(hits) do
    local tk = target_key(t)
    local prev = NOTE_GATE.hold_count[tk] or 0
    NOTE_GATE.hold_count[tk] = prev + 1
    table.insert(stamped, tk)

    if preferences.pakettiNoteGateLatchMode.value then
      -- Latch: each note-on toggles state. Use prev parity as basis.
      local device = resolve_target(t)
      if device then
        local new_state = not device.is_active
        device.is_active = new_state
        write_active_automation(t, device, on_pattern, on_line,
          new_state and 1.0 or 0.0)
      end
    else
      -- Momentary: turn on if first hold for this target
      if prev == 0 then
        set_target_active(t, true, on_pattern, on_line)
      end
    end
  end

  NOTE_GATE.active_holds[event_key] = stamped
end

local function gate_note_off(channel, note)
  local event_key = tostring(channel) .. ":" .. tostring(note)
  local stamped = NOTE_GATE.active_holds[event_key]
  if not stamped then return end
  NOTE_GATE.active_holds[event_key] = nil

  if preferences.pakettiNoteGateLatchMode.value then
    -- Latch ignores note-offs; just decrement counters for bookkeeping
    for _, tk in ipairs(stamped) do
      NOTE_GATE.hold_count[tk] = math.max(0, (NOTE_GATE.hold_count[tk] or 1) - 1)
    end
    return
  end

  local pattern_index = get_pattern_index_from_playback()
  local line = get_current_line()

  for _, tk in ipairs(stamped) do
    local count = math.max(0, (NOTE_GATE.hold_count[tk] or 1) - 1)
    NOTE_GATE.hold_count[tk] = count
    if count == 0 then
      -- find the target row whose key matches and turn it off
      for _, t in ipairs(NOTE_GATE.targets) do
        if target_key(t) == tk then
          set_target_active(t, false, pattern_index, line)
          break
        end
      end
    end
  end
end

------------------------------------------------------------------------
-- MIDI callback
------------------------------------------------------------------------

local function midi_callback(message)
  if not message or #message < 3 then return end
  local status = message[1]
  local note = message[2]
  local velocity = message[3]
  local message_type = bit.band(status, 0xF0)
  local channel = bit.band(status, 0x0F) + 1

  local filter = preferences.pakettiNoteGateChannel.value
  if filter ~= 0 and channel ~= filter then return end

  local is_note_on = (message_type == 0x90) and (velocity > 0)
  local is_note_off = (message_type == 0x80)
                   or ((message_type == 0x90) and (velocity == 0))

  if is_note_on then
    gate_note_on(channel, note)
  elseif is_note_off then
    gate_note_off(channel, note)
  end
end

------------------------------------------------------------------------
-- Pattern scanner (note-driven, optional)
------------------------------------------------------------------------

local function scan_pattern_notes()
  if not preferences.pakettiNoteGatePatternScanner.value then return end
  if #NOTE_GATE.targets == 0 then return end

  local song = renoise.song()
  if not song.transport.playing then
    NOTE_GATE.last_scan_key = nil
    return
  end

  local pattern_index = get_pattern_index_from_playback()
  local line_index = song.transport.playback_pos.line
  local scan_key = tostring(pattern_index) .. ":" .. tostring(line_index)
  if scan_key == NOTE_GATE.last_scan_key then return end
  NOTE_GATE.last_scan_key = scan_key

  -- One pass per track that has at least one target on it
  local tracks_with_targets = {}
  for _, t in ipairs(NOTE_GATE.targets) do
    tracks_with_targets[t.track_index] = true
  end

  for track_index, _ in pairs(tracks_with_targets) do
    local pattern = song.patterns[pattern_index]
    if pattern then
      local pattern_track = pattern.tracks[track_index]
      if pattern_track then
        local line = pattern_track.lines[line_index]
        if line then
          local seen_off, seen_on_note = false, nil
          for _, note_col in ipairs(line.note_columns) do
            local s = note_col.note_string
            if s == "OFF" then
              seen_off = true
            elseif s ~= "---" and s ~= "" then
              seen_on_note = note_col.note_value
            end
          end
          if seen_on_note then
            for _, t in ipairs(NOTE_GATE.targets) do
              if t.track_index == track_index
                 and seen_on_note >= t.note_lo
                 and seen_on_note <= t.note_hi then
                set_target_active(t, true, pattern_index, line_index)
              end
            end
          elseif seen_off then
            for _, t in ipairs(NOTE_GATE.targets) do
              if t.track_index == track_index then
                set_target_active(t, false, pattern_index, line_index)
              end
            end
          end
        end
      end
    end
  end
end

local function start_pattern_scanner()
  if not renoise.tool():has_timer(scan_pattern_notes) then
    renoise.tool():add_timer(scan_pattern_notes, 10)
  end
end

local function stop_pattern_scanner()
  if renoise.tool():has_timer(scan_pattern_notes) then
    renoise.tool():remove_timer(scan_pattern_notes)
  end
end

------------------------------------------------------------------------
-- Public actions
------------------------------------------------------------------------

function PakettiNoteReleaseGateAddSelectedDevice()
  load_targets()
  local s = renoise.song()
  local track_index = s.selected_track_index
  local device_index = s.selected_device_index
  local device = s.selected_device
  if not device then
    renoise.app():show_status("Note Gate: no selected device")
    return
  end
  -- skip duplicates
  for _, t in ipairs(NOTE_GATE.targets) do
    if t.track_index == track_index and t.device_index == device_index then
      renoise.app():show_status("Note Gate: target already exists for "
        .. device.display_name)
      return
    end
  end
  table.insert(NOTE_GATE.targets, {
    track_index = track_index,
    device_index = device_index,
    note_lo = 0,
    note_hi = 119,
  })
  save_targets()
  renoise.app():show_status("Note Gate: target added — track "
    .. track_index .. " / " .. device.display_name
    .. " (" .. #NOTE_GATE.targets .. " total)")
end

function PakettiNoteReleaseGateRemoveTargetsForCurrentTrack()
  load_targets()
  local track_index = renoise.song().selected_track_index
  local kept = {}
  local removed = 0
  for _, t in ipairs(NOTE_GATE.targets) do
    if t.track_index == track_index then
      removed = removed + 1
    else
      table.insert(kept, t)
    end
  end
  NOTE_GATE.targets = kept
  save_targets()
  renoise.app():show_status("Note Gate: removed " .. removed
    .. " target(s) for track " .. track_index)
end

function PakettiNoteReleaseGateClearAllTargets()
  NOTE_GATE.targets = {}
  save_targets()
  renoise.app():show_status("Note Gate: all targets cleared")
end

function PakettiNoteReleaseGateListTargets()
  load_targets()
  if #NOTE_GATE.targets == 0 then
    renoise.app():show_status("Note Gate: no targets")
    return
  end
  local song = renoise.song()
  local lines = {}
  for i, t in ipairs(NOTE_GATE.targets) do
    local device, track = resolve_target(t)
    local label
    if device then
      label = string.format("[%d] track %d (%s) / device %d (%s) notes %d-%d",
        i, t.track_index, track.name, t.device_index,
        device.display_name, t.note_lo, t.note_hi)
    else
      label = string.format("[%d] track %d / device %d (UNRESOLVED) notes %d-%d",
        i, t.track_index, t.device_index, t.note_lo, t.note_hi)
    end
    table.insert(lines, label)
  end
  renoise.app():show_message("Note Gate Targets\n\n" .. table.concat(lines, "\n"))
end

function PakettiNoteReleaseGateStart()
  load_targets()
  if NOTE_GATE.midi_device then
    NOTE_GATE.midi_device:close()
    NOTE_GATE.midi_device = nil
  end
  NOTE_GATE.hold_count = {}
  NOTE_GATE.active_holds = {}
  NOTE_GATE.last_auto = {}

  local inputs = renoise.Midi.available_input_devices()
  if not inputs or #inputs == 0 then
    renoise.app():show_status("Note Gate: no MIDI input devices available")
    return
  end

  local pref_name = preferences.pakettiNoteGateMidiDeviceName.value
  local selected_name = nil
  if pref_name and pref_name ~= "" then
    for _, name in ipairs(inputs) do
      if name == pref_name then selected_name = name break end
    end
  end
  if not selected_name then selected_name = inputs[1] end

  NOTE_GATE.midi_device = renoise.Midi.create_input_device(selected_name, midi_callback)
  NOTE_GATE.midi_listening = true
  start_pattern_scanner()
  renoise.app():show_status("Note Gate: started on '" .. selected_name
    .. "', " .. #NOTE_GATE.targets .. " target(s)")
end

function PakettiNoteReleaseGateStop()
  if NOTE_GATE.midi_device then
    NOTE_GATE.midi_device:close()
    NOTE_GATE.midi_device = nil
  end
  NOTE_GATE.midi_listening = false
  release_all_targets()
  stop_pattern_scanner()
  NOTE_GATE.last_auto = {}
  renoise.app():show_status("Note Gate: stopped")
end

function PakettiNoteReleaseGateToggle()
  if NOTE_GATE.midi_listening then
    PakettiNoteReleaseGateStop()
  else
    PakettiNoteReleaseGateStart()
  end
end

function PakettiNoteReleaseGateToggleLatch()
  local v = not preferences.pakettiNoteGateLatchMode.value
  preferences.pakettiNoteGateLatchMode.value = v
  preferences:save_as("preferences.xml")
  renoise.app():show_status("Note Gate: latch mode " .. (v and "ON" or "OFF"))
end

function PakettiNoteReleaseGateToggleAutomationWriting()
  local v = not preferences.pakettiNoteGateWriteAutomation.value
  preferences.pakettiNoteGateWriteAutomation.value = v
  preferences:save_as("preferences.xml")
  renoise.app():show_status("Note Gate: automation writing " .. (v and "ON" or "OFF"))
end

function PakettiNoteReleaseGateTogglePatternScanner()
  local v = not preferences.pakettiNoteGatePatternScanner.value
  preferences.pakettiNoteGatePatternScanner.value = v
  preferences:save_as("preferences.xml")
  if v and NOTE_GATE.midi_listening then
    start_pattern_scanner()
  elseif not v then
    stop_pattern_scanner()
  end
  renoise.app():show_status("Note Gate: pattern scanner " .. (v and "ON" or "OFF"))
end

------------------------------------------------------------------------
-- Lifecycle: stop on unload + reload targets on song change
------------------------------------------------------------------------

renoise.tool().tool_will_unload_observable:add_notifier(function()
  if NOTE_GATE.midi_listening then
    PakettiNoteReleaseGateStop()
  end
end)

renoise.tool().app_new_document_observable:add_notifier(function()
  -- New song: stop the gate (device targets refer to a different song's tracks)
  if NOTE_GATE.midi_listening then
    PakettiNoteReleaseGateStop()
  end
  load_targets()
  if preferences.pakettiNoteGateAutoStart.value then
    PakettiNoteReleaseGateStart()
  end
end)

-- Initial target load
load_targets()

------------------------------------------------------------------------
-- Menu / keybindings
------------------------------------------------------------------------

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Note Release Gate:Add Selected Device as Target",
  invoke = PakettiNoteReleaseGateAddSelectedDevice
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Note Release Gate:Remove Targets For Current Track",
  invoke = PakettiNoteReleaseGateRemoveTargetsForCurrentTrack
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Note Release Gate:Clear All Targets",
  invoke = PakettiNoteReleaseGateClearAllTargets
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Note Release Gate:List Targets",
  invoke = PakettiNoteReleaseGateListTargets
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Note Release Gate:Start",
  invoke = PakettiNoteReleaseGateStart
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Note Release Gate:Stop",
  invoke = PakettiNoteReleaseGateStop
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Note Release Gate:Toggle Start/Stop",
  invoke = PakettiNoteReleaseGateToggle
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Note Release Gate:Toggle Latch Mode",
  invoke = PakettiNoteReleaseGateToggleLatch
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Note Release Gate:Toggle Automation Writing",
  invoke = PakettiNoteReleaseGateToggleAutomationWriting
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Note Release Gate:Toggle Pattern Scanner",
  invoke = PakettiNoteReleaseGateTogglePatternScanner
}

PakettiAddMenuEntry{
  name = "DSP Device:Paketti:Note Release Gate Add as Target",
  invoke = PakettiNoteReleaseGateAddSelectedDevice
}
PakettiAddMenuEntry{
  name = "Mixer:Paketti:Note Release Gate Toggle Start/Stop",
  invoke = PakettiNoteReleaseGateToggle
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Note Release Gate Add Selected Device as Target",
  invoke = PakettiNoteReleaseGateAddSelectedDevice
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Note Release Gate Toggle Start/Stop",
  invoke = PakettiNoteReleaseGateToggle
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Note Release Gate Start",
  invoke = PakettiNoteReleaseGateStart
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Note Release Gate Stop",
  invoke = PakettiNoteReleaseGateStop
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Note Release Gate Toggle Latch Mode",
  invoke = PakettiNoteReleaseGateToggleLatch
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Note Release Gate Toggle Automation Writing",
  invoke = PakettiNoteReleaseGateToggleAutomationWriting
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Note Release Gate Toggle Pattern Scanner",
  invoke = PakettiNoteReleaseGateTogglePatternScanner
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Note Release Gate Clear All Targets",
  invoke = PakettiNoteReleaseGateClearAllTargets
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Note Release Gate List Targets",
  invoke = PakettiNoteReleaseGateListTargets
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Note Release Gate Toggle Start/Stop",
  invoke = function(message)
    if message:is_trigger() then PakettiNoteReleaseGateToggle() end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Note Release Gate Toggle Latch Mode",
  invoke = function(message)
    if message:is_trigger() then PakettiNoteReleaseGateToggleLatch() end
  end
}
