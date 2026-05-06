-- PakettiNoteReleaseGate.lua
-- MIDI note-on / note-off as a gestural envelope over an arbitrary
-- device parameter on either a track or an instrument's Sample FX Chain.
--
-- The headline use case (and reason this exists at all): drop a #Send
-- device on a track or a Sample FX Chain, route it to a Send track
-- carrying a delay/reverb/whatever, gate the Send's Amount with this
-- module. Note-on opens the gate, note-off closes it; the destination
-- effect KEEPS RUNNING so its tail plays out naturally — Signal
-- Follower can't do this because audio gating depends on signal
-- presence, not gesture.
--
-- A target is a (scope, device, parameter) triple with on/off values,
-- optional note range, and optional channel filter. Targets persist
-- per-song.

------------------------------------------------------------------------
-- Constants & schema
------------------------------------------------------------------------

local SCOPE_TRACK = "track"
local SCOPE_SAMPLE_CHAIN = "sample_chain"

-- parameter_index sentinel: -1 means "use device.is_active_parameter"
local PARAM_IS_ACTIVE = -1

-- Field/record separators chosen to never appear in display names
local FS = "\28" -- file separator (between songs)
local GS = "\29" -- group separator (song-name vs targets payload)
local RS = "\30" -- record separator (between targets within a song)
local US = "\31" -- unit separator (between fields within a target)

local NOTE_GATE = {
  midi_device = nil,
  midi_listening = false,
  hold_count = {},          -- target.id -> int (number of MIDI keys holding)
  active_holds = {},        -- "ch:note" event_key -> array of target ids
  last_auto = {},           -- target.id -> "pattern:line:value" stamp (dedup)
  targets = {},             -- live targets for the current song
  last_scan_key = nil,
  current_song_key = "",
  -- target.id -> true if a live MIDI hold is currently keeping it open;
  -- the pattern scanner respects this and won't force-off a MIDI-held target.
  midi_held = {},
}

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function gen_id()
  return string.format("g%s_%d_%d",
    tostring(os.clock()):gsub("%.", "_"),
    math.random(1, 1000000),
    math.random(1, 1000000))
end

local function safe_name(s)
  if not s then return "" end
  return (tostring(s):gsub("[\28\29\30\31]", " "))
end

local function song_key()
  local s = renoise.song()
  if not s then return "" end
  local fn = s.file_name or ""
  if fn == "" then return "__unsaved__" end
  return fn
end

------------------------------------------------------------------------
-- Target factory
------------------------------------------------------------------------

local function make_target(opts)
  return {
    id = opts.id or gen_id(),
    scope = opts.scope or SCOPE_TRACK,
    track_index = opts.track_index or 1,
    instrument_index = opts.instrument_index or 0,
    chain_index = opts.chain_index or 0,
    device_index = opts.device_index or 1,
    parameter_index = opts.parameter_index or PARAM_IS_ACTIVE,
    on_value = opts.on_value or 1.0,
    off_value = opts.off_value or 0.0,
    note_lo = opts.note_lo or 0,
    note_hi = opts.note_hi or 119,
    channel = opts.channel or 0,
    device_name_snapshot = safe_name(opts.device_name_snapshot or ""),
    parameter_name_snapshot = safe_name(opts.parameter_name_snapshot or ""),
  }
end

------------------------------------------------------------------------
-- Serialization (per-song bucket)
------------------------------------------------------------------------

local function serialize_one(t)
  return table.concat({
    t.id, t.scope,
    tostring(t.track_index), tostring(t.instrument_index),
    tostring(t.chain_index), tostring(t.device_index),
    tostring(t.parameter_index),
    string.format("%.6f", t.on_value),
    string.format("%.6f", t.off_value),
    tostring(t.note_lo), tostring(t.note_hi),
    tostring(t.channel),
    t.device_name_snapshot, t.parameter_name_snapshot,
  }, US)
end

local function deserialize_one(s)
  local f = {}
  for chunk in string.gmatch(s, "([^" .. US .. "]+)") do
    f[#f + 1] = chunk
  end
  if #f < 14 then return nil end
  return make_target{
    id = f[1], scope = f[2],
    track_index = tonumber(f[3]), instrument_index = tonumber(f[4]),
    chain_index = tonumber(f[5]), device_index = tonumber(f[6]),
    parameter_index = tonumber(f[7]),
    on_value = tonumber(f[8]), off_value = tonumber(f[9]),
    note_lo = tonumber(f[10]), note_hi = tonumber(f[11]),
    channel = tonumber(f[12]),
    device_name_snapshot = f[13], parameter_name_snapshot = f[14],
  }
end

local function serialize_song_bucket(targets)
  local parts = {}
  for _, t in ipairs(targets) do parts[#parts + 1] = serialize_one(t) end
  return table.concat(parts, RS)
end

local function deserialize_song_bucket(s)
  local out = {}
  if not s or s == "" then return out end
  for chunk in string.gmatch(s, "([^" .. RS .. "]+)") do
    local t = deserialize_one(chunk)
    if t then out[#out + 1] = t end
  end
  return out
end

local function read_all_buckets()
  local raw = preferences.pakettiNoteGateTargetsBySong.value or ""
  local buckets = {}
  if raw == "" then return buckets end
  for entry in string.gmatch(raw, "([^" .. FS .. "]+)") do
    local sep_pos = string.find(entry, GS, 1, true)
    if sep_pos then
      local key = string.sub(entry, 1, sep_pos - 1)
      local payload = string.sub(entry, sep_pos + 1)
      buckets[key] = payload
    end
  end
  return buckets
end

local function write_all_buckets(buckets)
  local parts = {}
  for key, payload in pairs(buckets) do
    parts[#parts + 1] = key .. GS .. payload
  end
  preferences.pakettiNoteGateTargetsBySong.value = table.concat(parts, FS)
  preferences:save_as("preferences.xml")
end

------------------------------------------------------------------------
-- Migration from v1 (global) format
------------------------------------------------------------------------

local function migrate_v1_if_present()
  local old = preferences.pakettiNoteGateTargets.value or ""
  if old == "" then return nil end
  local out = {}
  for chunk in string.gmatch(old, "[^;]+") do
    local ti, di, lo, hi = string.match(chunk, "^(-?%d+),(-?%d+),(-?%d+),(-?%d+)$")
    if ti and di and lo and hi then
      out[#out + 1] = make_target{
        scope = SCOPE_TRACK,
        track_index = tonumber(ti), device_index = tonumber(di),
        parameter_index = PARAM_IS_ACTIVE,
        on_value = 1.0, off_value = 0.0,
        note_lo = tonumber(lo), note_hi = tonumber(hi),
      }
    end
  end
  -- Clear v1 blob so we don't migrate twice
  preferences.pakettiNoteGateTargets.value = ""
  preferences:save_as("preferences.xml")
  return out
end

------------------------------------------------------------------------
-- Per-song load/save
------------------------------------------------------------------------

local function save_targets()
  local buckets = read_all_buckets()
  buckets[NOTE_GATE.current_song_key] = serialize_song_bucket(NOTE_GATE.targets)
  write_all_buckets(buckets)
end

local function load_targets_for_current_song()
  NOTE_GATE.current_song_key = song_key()
  local buckets = read_all_buckets()
  local payload = buckets[NOTE_GATE.current_song_key]
  if payload then
    NOTE_GATE.targets = deserialize_song_bucket(payload)
  else
    NOTE_GATE.targets = {}
  end
  -- One-time migration: if v1 blob exists and current song has no targets,
  -- adopt the v1 targets into the current song's bucket.
  local migrated = migrate_v1_if_present()
  if migrated and #NOTE_GATE.targets == 0 and #migrated > 0 then
    NOTE_GATE.targets = migrated
    save_targets()
  end
end

------------------------------------------------------------------------
-- Resolution with identity reconciliation
------------------------------------------------------------------------

local function get_track_device_list(t)
  local song = renoise.song()
  if t.scope == SCOPE_SAMPLE_CHAIN then
    local instr = song.instruments[t.instrument_index]
    if not instr then return nil, nil end
    local chain = instr.sample_device_chains[t.chain_index]
    if not chain then return nil, nil end
    return chain.devices, nil -- no track for sample chain (no automation lane)
  else
    local track = song.tracks[t.track_index]
    if not track then return nil, nil end
    return track.devices, t.track_index
  end
end

local function resolve_target_full(t)
  local devices, container_track_index = get_track_device_list(t)
  if not devices then return nil end

  local device = devices[t.device_index]

  -- Reconcile by display_name if the indexed slot doesn't match snapshot
  if t.device_name_snapshot ~= "" then
    if not device or device.display_name ~= t.device_name_snapshot then
      device = nil
      for i, d in ipairs(devices) do
        if d.display_name == t.device_name_snapshot then
          device = d
          t.device_index = i
          break
        end
      end
    end
  end
  if not device then return nil end

  -- Resolve parameter
  local param
  if t.parameter_index == PARAM_IS_ACTIVE then
    param = device.is_active_parameter
  else
    if t.parameter_index >= 1 and t.parameter_index <= #device.parameters then
      param = device.parameters[t.parameter_index]
    end
    if t.parameter_name_snapshot ~= "" and param and param.name ~= t.parameter_name_snapshot then
      for i, p in ipairs(device.parameters) do
        if p.name == t.parameter_name_snapshot then
          param = p
          t.parameter_index = i
          break
        end
      end
    end
  end
  if not param then return nil end

  return device, param, container_track_index
end

------------------------------------------------------------------------
-- Automation writing
------------------------------------------------------------------------

local function get_pattern_index_from_playback()
  local s = renoise.song()
  local pos = s.transport.playback_pos
  if pos.sequence and s.sequencer and s.sequencer.pattern_sequence then
    local idx = s.sequencer.pattern_sequence[pos.sequence]
    if idx then return idx end
  end
  return s.selected_pattern_index
end

local function get_current_line()
  local s = renoise.song()
  if s.transport.playing then return s.transport.playback_pos.line end
  return s.selected_line_index
end

local function get_step_record_note_on_line()
  local s = renoise.song()
  if s.transport.playing then return s.transport.playback_pos.line end
  if s.transport.edit_mode and s.transport.edit_step > 0 then
    local line = s.selected_line_index - s.transport.edit_step
    if line < 1 then line = 1 end
    return line
  end
  return s.selected_line_index
end

local function write_param_automation(t, container_track_index, param, pattern_index, line, value)
  if not preferences.pakettiNoteGateWriteAutomation.value then return end
  if not container_track_index then return end -- sample chains don't get automation lanes
  if not param then return end

  local s = renoise.song()
  local pattern = s.patterns[pattern_index]
  if not pattern then return end
  local pattern_track = pattern.tracks[container_track_index]
  if not pattern_track then return end

  local stamp = string.format("%d:%d:%.4f", pattern_index, line, value)
  if NOTE_GATE.last_auto[t.id] == stamp then return end
  NOTE_GATE.last_auto[t.id] = stamp

  s:describe_undo("Note Gate Automation Write")
  local automation = pattern_track:find_automation(param)
  if not automation then
    automation = pattern_track:create_automation(param)
  end
  if automation:has_point_at(line) then
    automation:remove_point_at(line)
  end
  automation:add_point_at(line, value)
end

------------------------------------------------------------------------
-- Apply value to target
------------------------------------------------------------------------

local function set_target_value(t, value, pattern_index, line)
  local device, param, container_track_index = resolve_target_full(t)
  if not device or not param then return end

  -- For is_active parameter, also flip device.is_active directly so the
  -- mixer LED updates and signal gating happens immediately
  if t.parameter_index == PARAM_IS_ACTIVE then
    device.is_active = (value >= 0.5)
  else
    -- Clamp to parameter range
    local v = value
    if v < param.value_min then v = param.value_min end
    if v > param.value_max then v = param.value_max end
    param.value = v
  end

  write_param_automation(t, container_track_index, param,
    pattern_index or get_pattern_index_from_playback(),
    line or get_current_line(),
    value)
end

local function release_all_targets()
  for _, t in ipairs(NOTE_GATE.targets) do
    -- Do not write automation on a forced release (user pressed Stop)
    local saved = preferences.pakettiNoteGateWriteAutomation.value
    preferences.pakettiNoteGateWriteAutomation.value = false
    set_target_value(t, t.off_value)
    preferences.pakettiNoteGateWriteAutomation.value = saved
  end
  NOTE_GATE.hold_count = {}
  NOTE_GATE.active_holds = {}
  NOTE_GATE.midi_held = {}
end

------------------------------------------------------------------------
-- Polyphonic gate logic
------------------------------------------------------------------------

local function targets_for_event(channel, note)
  local global_ch = preferences.pakettiNoteGateChannel.value
  local hits = {}
  for _, t in ipairs(NOTE_GATE.targets) do
    -- Per-target channel: 0 = inherit global; otherwise must match
    local pass_ch
    if t.channel ~= 0 then
      pass_ch = (channel == t.channel)
    elseif global_ch ~= 0 then
      pass_ch = (channel == global_ch)
    else
      pass_ch = true
    end
    if pass_ch and note >= t.note_lo and note <= t.note_hi then
      hits[#hits + 1] = t
    end
  end
  return hits
end

local function find_target_by_id(id)
  for _, t in ipairs(NOTE_GATE.targets) do
    if t.id == id then return t end
  end
  return nil
end

local function gate_note_on(channel, note)
  local hits = targets_for_event(channel, note)
  if #hits == 0 then return end

  local event_key = tostring(channel) .. ":" .. tostring(note)
  -- Stale event-key cleanup (no matching note-off was received earlier)
  if NOTE_GATE.active_holds[event_key] then
    for _, id in ipairs(NOTE_GATE.active_holds[event_key]) do
      NOTE_GATE.hold_count[id] = math.max(0, (NOTE_GATE.hold_count[id] or 1) - 1)
    end
    NOTE_GATE.active_holds[event_key] = nil
  end

  local stamped = {}
  local s = renoise.song()
  local on_line = get_step_record_note_on_line()
  local on_pattern = s.selected_pattern_index

  for _, t in ipairs(hits) do
    local prev = NOTE_GATE.hold_count[t.id] or 0
    NOTE_GATE.hold_count[t.id] = prev + 1
    NOTE_GATE.midi_held[t.id] = true
    stamped[#stamped + 1] = t.id

    if preferences.pakettiNoteGateLatchMode.value then
      -- Latch: each note-on toggles between on_value and off_value
      local _, param = resolve_target_full(t)
      if param then
        local at_off = math.abs(param.value - t.off_value)
                       < math.abs(param.value - t.on_value)
        local target_v = at_off and t.on_value or t.off_value
        set_target_value(t, target_v, on_pattern, on_line)
      end
    else
      if prev == 0 then
        set_target_value(t, t.on_value, on_pattern, on_line)
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
    for _, id in ipairs(stamped) do
      NOTE_GATE.hold_count[id] = math.max(0, (NOTE_GATE.hold_count[id] or 1) - 1)
    end
    return
  end

  local pattern_index = get_pattern_index_from_playback()
  local line = get_current_line()

  for _, id in ipairs(stamped) do
    local count = math.max(0, (NOTE_GATE.hold_count[id] or 1) - 1)
    NOTE_GATE.hold_count[id] = count
    if count == 0 then
      NOTE_GATE.midi_held[id] = nil
      local t = find_target_by_id(id)
      if t then set_target_value(t, t.off_value, pattern_index, line) end
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
-- Pattern scanner (track-scope only — sample chains aren't pattern-driven)
------------------------------------------------------------------------

local function scan_pattern_notes()
  if not preferences.pakettiNoteGatePatternScanner.value then return end
  if #NOTE_GATE.targets == 0 then return end

  local s = renoise.song()
  if not s.transport.playing then
    NOTE_GATE.last_scan_key = nil
    return
  end

  local pattern_index = get_pattern_index_from_playback()
  local line_index = s.transport.playback_pos.line
  local scan_key = tostring(pattern_index) .. ":" .. tostring(line_index)
  if scan_key == NOTE_GATE.last_scan_key then return end
  NOTE_GATE.last_scan_key = scan_key

  local tracks_with_targets = {}
  for _, t in ipairs(NOTE_GATE.targets) do
    if t.scope == SCOPE_TRACK then
      tracks_with_targets[t.track_index] = true
    end
  end

  for track_index, _ in pairs(tracks_with_targets) do
    local pattern = s.patterns[pattern_index]
    if pattern then
      local pattern_track = pattern.tracks[track_index]
      if pattern_track then
        local line = pattern_track.lines[line_index]
        if line then
          local seen_off, seen_on_note = false, nil
          for _, note_col in ipairs(line.note_columns) do
            local ns = note_col.note_string
            if ns == "OFF" then seen_off = true
            elseif ns ~= "---" and ns ~= "" then seen_on_note = note_col.note_value end
          end
          if seen_on_note then
            for _, t in ipairs(NOTE_GATE.targets) do
              if t.scope == SCOPE_TRACK and t.track_index == track_index
                 and seen_on_note >= t.note_lo and seen_on_note <= t.note_hi then
                set_target_value(t, t.on_value, pattern_index, line_index)
              end
            end
          elseif seen_off then
            for _, t in ipairs(NOTE_GATE.targets) do
              if t.scope == SCOPE_TRACK and t.track_index == track_index then
                -- Source priority: a live MIDI hold beats the scanner.
                if not NOTE_GATE.midi_held[t.id] then
                  set_target_value(t, t.off_value, pattern_index, line_index)
                end
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
-- Send-Amount auto-detection
------------------------------------------------------------------------

local SEND_DEVICE_NAMES = {
  ["#Send"] = true,
  ["#Multiband Send"] = true,
}

local function find_amount_parameter(device)
  -- For a #Send: parameter named "Amount"
  -- For a #Multiband Send: first useful gain is Band1Volume
  for i, p in ipairs(device.parameters) do
    if p.name == "Amount" then return i, p end
  end
  for i, p in ipairs(device.parameters) do
    if p.name == "Band1Volume" then return i, p end
  end
  return nil, nil
end

local function default_target_settings_for_device(device)
  -- Returns parameter_index, on_value, off_value, parameter_name
  if device and SEND_DEVICE_NAMES[device.name] then
    local pi, p = find_amount_parameter(device)
    if pi and p then
      -- For Sends, off=0 (silence) on=1 (unity); gate-closed-by-default
      return pi, 1.0, 0.0, p.name
    end
  end
  -- Fallback: gate the device's bypass
  return PARAM_IS_ACTIVE, 1.0, 0.0, "is_active"
end

------------------------------------------------------------------------
-- Public actions
------------------------------------------------------------------------

local function ensure_target_added(t)
  for _, existing in ipairs(NOTE_GATE.targets) do
    if existing.scope == t.scope
       and existing.track_index == t.track_index
       and existing.instrument_index == t.instrument_index
       and existing.chain_index == t.chain_index
       and existing.device_index == t.device_index
       and existing.parameter_index == t.parameter_index then
      return false, existing
    end
  end
  NOTE_GATE.targets[#NOTE_GATE.targets + 1] = t
  save_targets()
  return true, t
end

function PakettiNoteReleaseGateAddSelectedDevice()
  local s = renoise.song()
  local device = s.selected_device
  if not device then
    renoise.app():show_status("Note Gate: no selected device")
    return
  end
  local pi, on_v, off_v, pname = default_target_settings_for_device(device)
  -- If the resting state is supposed to be off, clamp the device there now
  if pi ~= PARAM_IS_ACTIVE then
    local p = device.parameters[pi]
    if p then p.value = off_v end
  end
  local t = make_target{
    scope = SCOPE_TRACK,
    track_index = s.selected_track_index,
    device_index = s.selected_device_index,
    parameter_index = pi,
    on_value = on_v,
    off_value = off_v,
    device_name_snapshot = device.display_name,
    parameter_name_snapshot = pname,
  }
  local added, existing = ensure_target_added(t)
  if added then
    renoise.app():show_status(string.format(
      "Note Gate: added track target — %s / %s on/off %.2f/%.2f (%d total)",
      device.display_name, pname, on_v, off_v, #NOTE_GATE.targets))
  else
    renoise.app():show_status("Note Gate: target already exists")
  end
end

function PakettiNoteReleaseGateAddSelectedSampleChainDevice()
  local s = renoise.song()
  local instr = s.selected_instrument
  if not instr then
    renoise.app():show_status("Note Gate: no selected instrument")
    return
  end
  local chain = s.selected_sample_device_chain
  local chain_index = s.selected_sample_device_chain_index
  if not chain or not chain_index or chain_index < 1 then
    renoise.app():show_status("Note Gate: no selected Sample FX Chain — open one first")
    return
  end
  local device = s.selected_sample_device
  local device_index = s.selected_sample_device_index
  if not device or not device_index or device_index < 1 then
    renoise.app():show_status("Note Gate: no selected device in Sample FX Chain")
    return
  end
  local pi, on_v, off_v, pname = default_target_settings_for_device(device)
  if pi ~= PARAM_IS_ACTIVE then
    local p = device.parameters[pi]
    if p then p.value = off_v end
  end
  local t = make_target{
    scope = SCOPE_SAMPLE_CHAIN,
    instrument_index = s.selected_instrument_index,
    chain_index = chain_index,
    device_index = device_index,
    parameter_index = pi,
    on_value = on_v,
    off_value = off_v,
    device_name_snapshot = device.display_name,
    parameter_name_snapshot = pname,
  }
  local added = ensure_target_added(t)
  if added then
    renoise.app():show_status(string.format(
      "Note Gate: added sample-chain target — %s.[%d].%s / %s on/off %.2f/%.2f",
      instr.name, chain_index, device.display_name, pname, on_v, off_v))
  else
    renoise.app():show_status("Note Gate: target already exists")
  end
end

function PakettiNoteReleaseGateRemoveTargetsForCurrentTrack()
  local track_index = renoise.song().selected_track_index
  local kept, removed = {}, 0
  for _, t in ipairs(NOTE_GATE.targets) do
    if t.scope == SCOPE_TRACK and t.track_index == track_index then
      removed = removed + 1
    else
      kept[#kept + 1] = t
    end
  end
  NOTE_GATE.targets = kept
  save_targets()
  renoise.app():show_status("Note Gate: removed " .. removed
    .. " track target(s) for track " .. track_index)
end

function PakettiNoteReleaseGateClearAllTargets()
  NOTE_GATE.targets = {}
  save_targets()
  renoise.app():show_status("Note Gate: all targets cleared")
end

function PakettiNoteReleaseGateListTargets()
  if #NOTE_GATE.targets == 0 then
    renoise.app():show_status("Note Gate: no targets")
    return
  end
  local s = renoise.song()
  local lines = {}
  for i, t in ipairs(NOTE_GATE.targets) do
    local _, param = resolve_target_full(t)
    local pname = param and param.name or "?"
    if t.scope == SCOPE_SAMPLE_CHAIN then
      local instr = s.instruments[t.instrument_index]
      local iname = instr and instr.name or "?"
      lines[#lines + 1] = string.format(
        "[%d] sample-chain %s [chain %d] / device %d (%s) / param %s on/off %.2f/%.2f notes %d-%d",
        i, iname, t.chain_index, t.device_index, t.device_name_snapshot,
        pname, t.on_value, t.off_value, t.note_lo, t.note_hi)
    else
      local track = s.tracks[t.track_index]
      local tname = track and track.name or "?"
      lines[#lines + 1] = string.format(
        "[%d] track %d (%s) / device %d (%s) / param %s on/off %.2f/%.2f notes %d-%d",
        i, t.track_index, tname, t.device_index, t.device_name_snapshot,
        pname, t.on_value, t.off_value, t.note_lo, t.note_hi)
    end
  end
  renoise.app():show_message("Note Gate Targets\n\n" .. table.concat(lines, "\n"))
end

function PakettiNoteReleaseGateStart()
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
  if v and NOTE_GATE.midi_listening then start_pattern_scanner()
  elseif not v then stop_pattern_scanner() end
  renoise.app():show_status("Note Gate: pattern scanner " .. (v and "ON" or "OFF"))
end

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------

renoise.tool().tool_will_unload_observable:add_notifier(function()
  if NOTE_GATE.midi_listening then PakettiNoteReleaseGateStop() end
end)

renoise.tool().app_new_document_observable:add_notifier(function()
  if NOTE_GATE.midi_listening then PakettiNoteReleaseGateStop() end
  load_targets_for_current_song()
  if preferences.pakettiNoteGateAutoStart.value then
    PakettiNoteReleaseGateStart()
  end
end)

-- Initial target load on tool boot. song() may not be ready; defer if needed.
local function deferred_initial_load()
  if renoise.song() then
    load_targets_for_current_song()
  end
end
renoise.tool().tool_finished_loading_observable:add_notifier(deferred_initial_load)

------------------------------------------------------------------------
-- Menu / keybindings / MIDI mappings
------------------------------------------------------------------------

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Note Release Gate:Add Selected Device as Target",
  invoke = PakettiNoteReleaseGateAddSelectedDevice
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Note Release Gate:Add Selected Sample FX Chain Device as Target",
  invoke = PakettiNoteReleaseGateAddSelectedSampleChainDevice
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
  name = "Sample Editor:Paketti:Note Release Gate Add Sample FX Device as Target",
  invoke = PakettiNoteReleaseGateAddSelectedSampleChainDevice
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
  name = "Global:Paketti:Note Release Gate Add Sample FX Device as Target",
  invoke = PakettiNoteReleaseGateAddSelectedSampleChainDevice
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

------------------------------------------------------------------------
-- Dialog
------------------------------------------------------------------------

local NOTE_NAMES = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}
local function fmt_note(v)
  if v < 0 or v > 119 then return tostring(v) end
  return NOTE_NAMES[(v % 12) + 1] .. tostring(math.floor(v / 12))
end

local dialog_ref = nil

local function build_target_row(vb, idx, t)
  local s = renoise.song()
  local _, param = resolve_target_full(t)
  local resolved = (param ~= nil)

  local scope_label
  if t.scope == SCOPE_SAMPLE_CHAIN then
    local instr = s.instruments[t.instrument_index]
    scope_label = string.format("[%d] SmpFX %s · chain %d · D%d %s",
      idx, (instr and instr.name or "?"), t.chain_index,
      t.device_index, t.device_name_snapshot)
  else
    local track = s.tracks[t.track_index]
    scope_label = string.format("[%d] T%d %s · D%d %s",
      idx, t.track_index, (track and track.name or "?"),
      t.device_index, t.device_name_snapshot)
  end
  local param_label = "param: " ..
    (t.parameter_index == PARAM_IS_ACTIVE and "is_active"
     or (t.parameter_name_snapshot ~= "" and t.parameter_name_snapshot
         or ("#" .. tostring(t.parameter_index))))

  local channel_items = { "Inherit" }
  for i = 1, 16 do channel_items[#channel_items + 1] = "Ch " .. i end

  return vb:column{
    style = "border",
    margin = 4,
    spacing = 2,
    vb:row{
      spacing = 6,
      vb:text{ text = scope_label, width = 360, style = resolved and "normal" or "disabled" },
      vb:text{ text = param_label, width = 200 },
      vb:button{
        text = "Show", width = 50,
        notifier = function()
          if t.scope == SCOPE_SAMPLE_CHAIN then
            if s.instruments[t.instrument_index] then
              s.selected_instrument_index = t.instrument_index
            end
          else
            if s.tracks[t.track_index] then
              s.selected_track_index = t.track_index
              if s.tracks[t.track_index].devices[t.device_index] then
                s.selected_device_index = t.device_index
              end
            end
          end
        end,
      },
      vb:button{
        text = "Remove", width = 70,
        notifier = function()
          table.remove(NOTE_GATE.targets, idx)
          save_targets()
          PakettiNoteReleaseGateShowDialog()
        end,
      },
    },
    vb:row{
      spacing = 6,
      vb:text{ text = "lo", style = "strong" },
      vb:valuebox{
        min = 0, max = 119, value = t.note_lo, width = 60,
        tostring = fmt_note,
        tonumber = function(s2) return tonumber(s2) or 0 end,
        notifier = function(v)
          NOTE_GATE.targets[idx].note_lo = v
          if v > NOTE_GATE.targets[idx].note_hi then
            NOTE_GATE.targets[idx].note_hi = v
          end
          save_targets()
        end,
      },
      vb:text{ text = "hi", style = "strong" },
      vb:valuebox{
        min = 0, max = 119, value = t.note_hi, width = 60,
        tostring = fmt_note,
        tonumber = function(s2) return tonumber(s2) or 119 end,
        notifier = function(v)
          NOTE_GATE.targets[idx].note_hi = v
          if v < NOTE_GATE.targets[idx].note_lo then
            NOTE_GATE.targets[idx].note_lo = v
          end
          save_targets()
        end,
      },
      vb:text{ text = "ch", style = "strong" },
      vb:popup{
        items = channel_items, value = t.channel + 1, width = 80,
        notifier = function(idx2)
          NOTE_GATE.targets[idx].channel = idx2 - 1
          save_targets()
        end,
      },
      vb:text{ text = "on", style = "strong" },
      vb:valuefield{
        min = -1.0, max = 4.0, value = t.on_value, width = 70,
        notifier = function(v)
          NOTE_GATE.targets[idx].on_value = v; save_targets()
        end,
      },
      vb:text{ text = "off", style = "strong" },
      vb:valuefield{
        min = -1.0, max = 4.0, value = t.off_value, width = 70,
        notifier = function(v)
          NOTE_GATE.targets[idx].off_value = v; save_targets()
        end,
      },
    },
  }
end

function PakettiNoteReleaseGateShowDialog()
  if dialog_ref and dialog_ref.visible then
    dialog_ref:close(); dialog_ref = nil; return
  end

  local vb = renoise.ViewBuilder()

  local inputs = renoise.Midi.available_input_devices() or {}
  local input_items = { "(first available)" }
  for _, n in ipairs(inputs) do input_items[#input_items + 1] = n end
  local current_pref = preferences.pakettiNoteGateMidiDeviceName.value
  local input_idx = 1
  for i, n in ipairs(inputs) do
    if n == current_pref then input_idx = i + 1 end
  end

  local channel_items = { "Any" }
  for i = 1, 16 do channel_items[#channel_items + 1] = "Ch " .. i end

  local target_rows = vb:column{ spacing = 4 }
  if #NOTE_GATE.targets == 0 then
    target_rows:add_child(vb:text{
      text = "No targets. Pick a #Send (or any device) and 'Add Selected Device as Target'.",
      style = "disabled",
    })
  else
    for i, t in ipairs(NOTE_GATE.targets) do
      target_rows:add_child(build_target_row(vb, i, t))
    end
  end

  local content = vb:column{
    margin = 10, spacing = 8,

    vb:column{
      style = "group", margin = 6, spacing = 4,
      vb:text{ text = "MIDI Input", style = "strong" },
      vb:row{
        spacing = 4,
        vb:text{ text = "Device", width = 60 },
        vb:popup{
          items = input_items, value = input_idx, width = 320,
          notifier = function(i)
            preferences.pakettiNoteGateMidiDeviceName.value =
              (i == 1) and "" or (inputs[i - 1] or "")
            preferences:save_as("preferences.xml")
          end,
        },
      },
      vb:row{
        spacing = 4,
        vb:text{ text = "Global Channel", width = 100 },
        vb:popup{
          items = channel_items,
          value = preferences.pakettiNoteGateChannel.value + 1, width = 80,
          notifier = function(i)
            preferences.pakettiNoteGateChannel.value = i - 1
            preferences:save_as("preferences.xml")
          end,
        },
        vb:text{ text = "(per-target channel overrides this)", style = "disabled" },
      },
    },

    vb:column{
      style = "group", margin = 6, spacing = 4,
      vb:text{ text = "Modes", style = "strong" },
      vb:row{
        spacing = 4,
        vb:checkbox{
          value = preferences.pakettiNoteGateLatchMode.value,
          notifier = function(v)
            preferences.pakettiNoteGateLatchMode.value = v
            preferences:save_as("preferences.xml")
          end,
        },
        vb:text{ text = "Latch (note-on toggles between on/off)" },
      },
      vb:row{
        spacing = 4,
        vb:checkbox{
          value = preferences.pakettiNoteGateWriteAutomation.value,
          notifier = function(v)
            preferences.pakettiNoteGateWriteAutomation.value = v
            preferences:save_as("preferences.xml")
          end,
        },
        vb:text{ text = "Write parameter automation while gating (track scope only)" },
      },
      vb:row{
        spacing = 4,
        vb:checkbox{
          value = preferences.pakettiNoteGatePatternScanner.value,
          notifier = function(v)
            preferences.pakettiNoteGatePatternScanner.value = v
            preferences:save_as("preferences.xml")
            if v and NOTE_GATE.midi_listening then start_pattern_scanner()
            elseif not v then stop_pattern_scanner() end
          end,
        },
        vb:text{ text = "Pattern scanner (drive gate from pattern note-ons/OFFs)" },
      },
      vb:row{
        spacing = 4,
        vb:checkbox{
          value = preferences.pakettiNoteGateAutoStart.value,
          notifier = function(v)
            preferences.pakettiNoteGateAutoStart.value = v
            preferences:save_as("preferences.xml")
          end,
        },
        vb:text{ text = "Auto-start on song load" },
      },
    },

    vb:column{
      style = "group", margin = 6, spacing = 4,
      vb:text{ text = "Targets (per song: " ..
        (NOTE_GATE.current_song_key == "__unsaved__" and "[unsaved]"
         or NOTE_GATE.current_song_key) .. ")",
        style = "strong" },
      target_rows,
      vb:row{
        spacing = 4,
        vb:button{
          text = "Add Selected Device", width = 160,
          notifier = function()
            PakettiNoteReleaseGateAddSelectedDevice()
            PakettiNoteReleaseGateShowDialog()
          end,
        },
        vb:button{
          text = "Add Sample FX Device", width = 170,
          notifier = function()
            PakettiNoteReleaseGateAddSelectedSampleChainDevice()
            PakettiNoteReleaseGateShowDialog()
          end,
        },
        vb:button{
          text = "Remove For Current Track", width = 200,
          notifier = function()
            PakettiNoteReleaseGateRemoveTargetsForCurrentTrack()
            PakettiNoteReleaseGateShowDialog()
          end,
        },
        vb:button{
          text = "Clear All", width = 80,
          notifier = function()
            local resp = renoise.app():show_prompt("Clear all Note Gate targets?",
              "Remove all " .. #NOTE_GATE.targets .. " target(s) from this song?",
              {"Yes", "Cancel"})
            if resp == "Yes" then
              PakettiNoteReleaseGateClearAllTargets()
              PakettiNoteReleaseGateShowDialog()
            end
          end,
        },
      },
    },

    vb:column{
      style = "group", margin = 6, spacing = 4,
      vb:text{
        text = NOTE_GATE.midi_listening and "Status: LISTENING" or "Status: stopped",
        style = "strong",
      },
      vb:row{
        spacing = 4,
        vb:button{ text = "Start", width = 80,
          notifier = function() PakettiNoteReleaseGateStart(); PakettiNoteReleaseGateShowDialog() end },
        vb:button{ text = "Stop", width = 80,
          notifier = function() PakettiNoteReleaseGateStop(); PakettiNoteReleaseGateShowDialog() end },
        vb:button{ text = "Refresh", width = 80,
          notifier = function() PakettiNoteReleaseGateShowDialog() end },
      },
    },
  }

  dialog_ref = renoise.app():show_custom_dialog(
    "Paketti Note Release Gate", content,
    function(d, key)
      if key.name == "esc" then d:close(); return nil end
      return key
    end
  )
end

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Note Release Gate:Show Dialog...",
  invoke = PakettiNoteReleaseGateShowDialog
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Note Release Gate Show Dialog",
  invoke = PakettiNoteReleaseGateShowDialog
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Note Release Gate Show Dialog",
  invoke = function(message)
    if message:is_trigger() then PakettiNoteReleaseGateShowDialog() end
  end
}
