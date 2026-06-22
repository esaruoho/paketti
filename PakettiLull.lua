-- PakettiLull.lua — make a selected segment quieter (three ways), reversibly.
--
-- The three approaches from LULL-FEASIBILITY.md:
--   1. Volume-column offset on the selection (the literal "offset selected notes' volume").
--      Generalises to panning/delay (same column shape). Instrument-agnostic — works on
--      drumtracks with many instruments. Core: PakettiColumnOffsetRange().
--   2. "Lull" instrument duplicate — duplicate each instrument used in the selection,
--      tag "(Lull)", remap the notes, set the dupe's volume relatively. Reversible via the
--      existing "Set Selection to Instrument". Core: PakettiLullInstrumentRange().
--   3. "Lull" track-volume automation over the segment — drop the whole track output for the
--      line-range (best for drumtracks / IT-style channel volume). Core: PakettiLullTrackVolumeRange().
--
-- Core functions take EXPLICIT ranges so they're unit-testable without a live selection;
-- the *Selection wrappers read renoise.song().selection_in_pattern.
-- FEATURE-CARD >> (volume/lull selection ops)

local VOL_FULL = 0x80   -- volume column: 0x00..0x80 (128 = full), 255 = empty
local PAN_CENTER = 0x40 -- panning column: 0x00..0x80 (0x40 = center), 255 = empty

-- ── Approach 1: column-value offset over an explicit range ───────────────────
-- field: "volume_value" | "panning_value" | "delay_value". Returns #notes changed.
function PakettiColumnOffsetRange(field, delta, s_track, e_track, s_line, e_line, s_col, e_col)
  local song = renoise.song()
  local pat = song:pattern(song.selected_pattern_index)
  local cap, empty_default
  if field == "volume_value" then cap, empty_default = VOL_FULL, VOL_FULL
  elseif field == "panning_value" then cap, empty_default = VOL_FULL, PAN_CENTER
  else cap, empty_default = 0xFF, 0 end  -- delay_value 0x00..0xFF, empty→0
  local changed = 0
  for t = s_track, e_track do
    local track = song.tracks[t]
    if track and track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      local ptrack = pat:track(t)
      local ncols = track.visible_note_columns
      local c0 = (t == s_track) and s_col or 1
      local c1 = (t == e_track) and e_col or ncols
      c1 = math.min(c1, ncols)
      for line = s_line, e_line do
        local pline = ptrack:line(line)
        for c = math.max(1, c0), c1 do
          local nc = pline.note_columns[c]
          if nc and not nc.is_empty then
            local v = nc[field]
            if v == 255 or v > cap then v = empty_default end
            v = math.max(0, math.min(cap, v + delta))
            nc[field] = v
            changed = changed + 1
          end
        end
      end
    end
  end
  return changed
end

local function with_selection(fn)
  local s = renoise.song().selection_in_pattern
  if not s then
    renoise.app():show_status("Paketti Lull: make a pattern selection first")
    return nil
  end
  return fn(s)
end

function PakettiVolumeOffsetSelection(delta)
  return with_selection(function(s)
    local n = PakettiColumnOffsetRange("volume_value", delta, s.start_track, s.end_track,
      s.start_line, s.end_line, s.start_column, s.end_column)
    renoise.app():show_status(("Paketti: volume %s%d on %d note(s)"):format(delta >= 0 and "+" or "", delta, n))
    return n
  end)
end

function PakettiPanningOffsetSelection(delta)
  return with_selection(function(s)
    return PakettiColumnOffsetRange("panning_value", delta, s.start_track, s.end_track,
      s.start_line, s.end_line, s.start_column, s.end_column)
  end)
end

function PakettiDelayOffsetSelection(delta)
  return with_selection(function(s)
    return PakettiColumnOffsetRange("delay_value", delta, s.start_track, s.end_track,
      s.start_line, s.end_line, s.start_column, s.end_column)
  end)
end

-- ── Approach 2: "Lull" instrument duplicate over an explicit range ───────────
-- vol_factor multiplies the dupe instrument's linear volume (clamped 0..+6dB). Dedup:
-- an existing "<name> (Lull)" instrument is reused, and notes already on a Lull dupe just
-- have that dupe's volume re-adjusted (so repeated presses keep tweaking, not re-duplicate).
function PakettiLullInstrumentRange(vol_factor, s_track, e_track, s_line, e_line, s_col, e_col)
  local song = renoise.song()
  local pat = song:pattern(song.selected_pattern_index)
  local vmax = math.db2lin(6)
  local function is_lull_name(name) return name:find("%(Lull%)$") ~= nil end
  -- index existing lull dupes by their source name
  local existing = {}  -- "<orig> (Lull)" -> 0-based index
  for i, ins in ipairs(song.instruments) do
    if is_lull_name(ins.name) then existing[ins.name] = i - 1 end
  end
  local map = {}        -- orig 0-based idx -> lull 0-based idx
  local touched = {}    -- set of 0-based lull idx to volume-adjust
  local function lull_for(orig_idx)
    if map[orig_idx] then return map[orig_idx] end
    local orig = song.instruments[orig_idx + 1]
    local lull_name = orig.name .. " (Lull)"
    if existing[lull_name] then map[orig_idx] = existing[lull_name]; return existing[lull_name] end
    local new_idx = #song.instruments          -- 0-based index of the new instrument
    song:insert_instrument_at(new_idx + 1)
    local dupe = song.instruments[new_idx + 1]
    dupe:copy_from(orig)
    dupe.name = lull_name
    existing[lull_name] = new_idx
    map[orig_idx] = new_idx
    return new_idx
  end
  for t = s_track, e_track do
    local track = song.tracks[t]
    if track and track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      local ptrack = pat:track(t)
      local ncols = track.visible_note_columns
      local c0 = (t == s_track) and s_col or 1
      local c1 = math.min((t == e_track) and e_col or ncols, ncols)
      for line = s_line, e_line do
        local pline = ptrack:line(line)
        for c = math.max(1, c0), c1 do
          local nc = pline.note_columns[c]
          if nc and not nc.is_empty and nc.note_value < 120 then
            local iv = nc.instrument_value         -- 0-based, 255 = empty
            if iv < 255 then
              if is_lull_name(song.instruments[iv + 1].name) then
                touched[iv] = true                  -- already a lull dupe → just re-adjust
              else
                local dupe_idx = lull_for(iv)
                nc.instrument_value = dupe_idx
                touched[dupe_idx] = true
              end
            end
          end
        end
      end
    end
  end
  local n = 0
  for idx in pairs(touched) do
    local ins = song.instruments[idx + 1]
    ins.volume = math.max(0, math.min(vmax, ins.volume * vol_factor))
    n = n + 1
  end
  return touched, n
end

function PakettiLullInstrumentSelection(vol_factor)
  return with_selection(function(s)
    local _, n = PakettiLullInstrumentRange(vol_factor, s.start_track, s.end_track,
      s.start_line, s.end_line, s.start_column, s.end_column)
    renoise.app():show_status(("Paketti Lull: x%.2f volume on %d duplicated instrument(s)"):format(vol_factor, n))
    return n
  end)
end

-- ── Approach 3: "Lull" track-volume automation over the segment ──────────────
-- Drops postfx_volume (linear * factor) across [s_line, e_line] on the track, with a
-- restore point after. Reversible: remove the points / envelope.
function PakettiLullTrackVolumeRange(factor, track_index, s_line, e_line)
  local song = renoise.song()
  local pat = song:pattern(song.selected_pattern_index)
  local track = song.tracks[track_index]
  if not (track and track.type == renoise.Track.TRACK_TYPE_SEQUENCER) then return nil end
  local param = track.prefx_volume   -- prefx_volume is automatable; postfx_volume is NOT
  local ptrack = pat:track(track_index)
  local env = ptrack:find_automation(param) or ptrack:create_automation(param)
  local function norm(v) return (v - param.value_min) / (param.value_max - param.value_min) end
  local cur = param.value
  local target = math.max(param.value_min, math.min(param.value_max, cur * factor))
  env:add_point_at(s_line, norm(target))
  env:add_point_at(e_line, norm(target))
  local after = e_line + 1
  if after <= pat.number_of_lines then env:add_point_at(after, norm(cur)) end
  return env
end

function PakettiLullTrackVolumeSelection(factor)
  return with_selection(function(s)
    local last
    for t = s.start_track, s.end_track do
      last = PakettiLullTrackVolumeRange(factor, t, s.start_line, s.end_line)
    end
    renoise.app():show_status(("Paketti Lull: track volume x%.2f over lines %d-%d"):format(factor, s.start_line, s.end_line))
    return last
  end)
end

-- ── Registrations (guarded so dev re-dofile during testing can't double-register) ──
-- rawget/rawset bypass the .spine harness's magic _G (a plain `_G.flag` reads truthy
-- there and would silently skip — and hide duplicates from the CI gate).
if not rawget(_G, "__PakettiLullRegistered") then
  rawset(_G, "__PakettiLullRegistered", true)

  -- Approach 1: volume offset (the literal ask)
  for _, d in ipairs({ {1,"+1"}, {-1,"-1"}, {8,"+8"}, {-8,"-8"}, {16,"+16"}, {-16,"-16"} }) do
    local delta, label = d[1], d[2]
    renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Selection Volume Offset "..label, invoke=function() PakettiVolumeOffsetSelection(delta) end}
    renoise.tool():add_midi_mapping{name="Paketti:Selection Volume Offset "..label, invoke=function(message) if message:is_trigger() then PakettiVolumeOffsetSelection(delta) end end}
  end

  -- Approach 2: Lull instrument duplicate (quieter / louder / reset)
  for _, d in ipairs({ {0.5,"Quieter (-6dB)"}, {0.7071,"Quieter (-3dB)"}, {1.4142,"Louder (+3dB)"} }) do
    local factor, label = d[1], d[2]
    renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Lull Selection Instrument "..label, invoke=function() PakettiLullInstrumentSelection(factor) end}
    renoise.tool():add_midi_mapping{name="Paketti:Lull Selection Instrument "..label, invoke=function(message) if message:is_trigger() then PakettiLullInstrumentSelection(factor) end end}
  end

  -- Approach 3: Lull track-volume automation over the segment
  for _, d in ipairs({ {0.5,"Quieter (-6dB)"}, {0.7071,"Quieter (-3dB)"}, {1.4142,"Louder (+3dB)"} }) do
    local factor, label = d[1], d[2]
    renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Lull Selection Track Volume "..label, invoke=function() PakettiLullTrackVolumeSelection(factor) end}
    renoise.tool():add_midi_mapping{name="Paketti:Lull Selection Track Volume "..label, invoke=function(message) if message:is_trigger() then PakettiLullTrackVolumeSelection(factor) end end}
  end
end
