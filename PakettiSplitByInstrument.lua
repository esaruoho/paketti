--[[============================================================================
PakettiSplitByInstrument.lua

Split a track that has several instruments jumbled together into one new track
per instrument.

Paketti's existing "Explode Notes to New Tracks" splits on PITCH - every
distinct note gets its own track, which is what you want for a drum kit. This
splits on INSTRUMENT instead: a track playing instruments 00, 03 and 07 becomes
three tracks, one per instrument, in ascending instrument order.

The new tracks are inserted directly after the source and inherit its DSP
chain, colour, collapsed state and column visibility, so the split does not
change how anything sounds.

What travels with a note: its volume, panning, delay and sample-effect values.
A note with no instrument number set inherits the last instrument seen in that
same note column, which is how Renoise plays it back. Track effect commands go
to the leftmost instrument playing on that line, or to the last instrument seen
above if the line has no notes.

Automation is NOT moved - it belongs to the source track and stays there. That
is why the default keeps the source track (with its notes cleared) rather than
deleting it. Use the "Delete Source Track" variants when you know the source
has no automation you care about.
============================================================================]]--

local PakettiSBI_MAX_NOTE_COLUMNS = 12
local PakettiSBI_MAX_EFFECT_COLUMNS = 8
local PakettiSBI_NO_INSTRUMENT = 255

local function PakettiSBIReadNoteColumn(nc)
  return {
    note_value = nc.note_value,
    instrument_value = nc.instrument_value,
    volume_value = nc.volume_value,
    panning_value = nc.panning_value,
    delay_value = nc.delay_value,
    effect_number_value = nc.effect_number_value,
    effect_amount_value = nc.effect_amount_value
  }
end

local function PakettiSBIWriteNoteColumn(nc, t)
  nc.note_value = t.note_value
  nc.instrument_value = t.instrument_value
  nc.volume_value = t.volume_value
  nc.panning_value = t.panning_value
  nc.delay_value = t.delay_value
  nc.effect_number_value = t.effect_number_value
  nc.effect_amount_value = t.effect_amount_value
end

local function PakettiSBIInstrumentLabel(instrument_value)
  local song = renoise.song()
  local slot = instrument_value + 1
  if slot >= 1 and slot <= #song.instruments then
    local name = song.instruments[slot].name
    if type(name) == "string" and #name > 0 then
      return string.format("%02X %s", instrument_value, name)
    end
  end
  return string.format("Instrument %02X", instrument_value)
end

-- Copies the look and the signal path of the source track onto a new track, so
-- the split tracks sound and read the same. Follows create_identical_track in
-- PakettiRequests.lua: device 1 is the built-in Track Volume/Pan, so skip it.
local function PakettiSBICloneTrackSettings(source_track, dest_track)
  dest_track.visible_effect_columns = source_track.visible_effect_columns
  dest_track.volume_column_visible = source_track.volume_column_visible
  dest_track.panning_column_visible = source_track.panning_column_visible
  dest_track.delay_column_visible = source_track.delay_column_visible
  dest_track.sample_effects_column_visible = source_track.sample_effects_column_visible
  dest_track.collapsed = source_track.collapsed
  dest_track.color = source_track.color
  dest_track.color_blend = source_track.color_blend

  local copied, failed = 0, 0
  for device_index = 2, #source_track.devices do
    local source_device = source_track.devices[device_index]
    local ok, err = pcall(function()
      local new_device = dest_track:insert_device_at(source_device.device_path, device_index)
      for param_index = 1, #source_device.parameters do
        new_device.parameters[param_index].value = source_device.parameters[param_index].value
      end
      new_device.is_maximized = source_device.is_maximized
      if source_device.active_preset_data then
        new_device.active_preset_data = source_device.active_preset_data
      end
    end)
    if ok then copied = copied + 1 else
      failed = failed + 1
      print("Paketti Split by Instrument: could not copy device '" ..
        tostring(source_device.device_path) .. "': " .. tostring(err))
    end
  end
  return copied, failed
end

-- Walks every pattern for one track and buckets its content per instrument.
-- Returns notes[iv][pattern][line] = ordered list, fx[iv][pattern][line] = list,
-- columns_needed[iv], and the ascending list of instruments found.
local function PakettiSBIGatherTrack(track_index)
  local song = renoise.song()
  local track = song.tracks[track_index]
  local visible_notes = track.visible_note_columns
  local visible_effects = track.visible_effect_columns

  local notes, fx, columns_needed, instrument_set = {}, {}, {}, {}
  local last_column_instrument = {}
  local last_note_instrument = nil

  for pattern_index = 1, #song.patterns do
    local pattern = song.patterns[pattern_index]
    local pattern_track = pattern.tracks[track_index]

    if not pattern_track.is_empty then
      for line_index = 1, pattern.number_of_lines do
        local line = pattern_track.lines[line_index]
        if not line.is_empty then
          local line_instruments = {}

          for column_index = 1, visible_notes do
            local nc = line.note_columns[column_index]
            if not nc.is_empty then
              local data = PakettiSBIReadNoteColumn(nc)
              local iv = data.instrument_value

              -- A note column with no instrument number keeps playing whatever
              -- was last triggered in that column, so follow it there.
              if iv >= PakettiSBI_NO_INSTRUMENT then
                iv = last_column_instrument[column_index]
              else
                last_column_instrument[column_index] = iv
                last_note_instrument = iv
                instrument_set[iv] = true
              end

              if iv ~= nil then
                notes[iv] = notes[iv] or {}
                notes[iv][pattern_index] = notes[iv][pattern_index] or {}
                local row = notes[iv][pattern_index][line_index] or {}
                notes[iv][pattern_index][line_index] = row
                row[#row + 1] = data
                if (columns_needed[iv] or 0) < #row then columns_needed[iv] = #row end
                line_instruments[#line_instruments + 1] = iv
              end
            end
          end

          if visible_effects > 0 then
            local owner = line_instruments[1] or last_note_instrument
            if owner ~= nil then
              local effects = {}
              for column_index = 1, visible_effects do
                local ec = line.effect_columns[column_index]
                if not ec.is_empty then
                  effects[#effects + 1] = {
                    number_value = ec.number_value,
                    amount_value = ec.amount_value
                  }
                end
              end
              if #effects > 0 then
                fx[owner] = fx[owner] or {}
                fx[owner][pattern_index] = fx[owner][pattern_index] or {}
                fx[owner][pattern_index][line_index] = effects
              end
            end
          end
        end
      end
    end
  end

  local instrument_list = {}
  for iv in pairs(instrument_set) do instrument_list[#instrument_list + 1] = iv end
  table.sort(instrument_list)
  for _, iv in ipairs(instrument_list) do
    if not columns_needed[iv] then columns_needed[iv] = 1 end
  end

  return notes, fx, columns_needed, instrument_list
end

-- True when the track carries any automation in any pattern.
local function PakettiSBITrackHasAutomation(track_index)
  local song = renoise.song()
  for pattern_index = 1, #song.patterns do
    if #song.patterns[pattern_index].tracks[track_index].automation > 0 then
      return true
    end
  end
  return false
end

-- Splits one track. Returns created_track_count, instrument_count, had_automation.
function PakettiSplitTrackByInstrument(track_index, delete_source)
  local song = renoise.song()
  local source_track = song.tracks[track_index]

  if source_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    return 0, 0, false
  end

  local notes, fx, columns_needed, instrument_list = PakettiSBIGatherTrack(track_index)
  if #instrument_list == 0 then return 0, 0, false end

  local had_automation = PakettiSBITrackHasAutomation(track_index)
  local source_name = source_track.name

  -- Gathering is finished, so inserting tracks can no longer shift data out
  -- from under us.
  local devices_failed = 0
  for offset, iv in ipairs(instrument_list) do
    local new_index = track_index + offset
    song:insert_track_at(new_index)
    local new_track = song.tracks[new_index]

    local _, failed = PakettiSBICloneTrackSettings(source_track, new_track)
    devices_failed = devices_failed + failed

    -- One note column can never need more than 12, because the source track
    -- itself cannot show more than 12.
    new_track.visible_note_columns =
      math.max(1, math.min(PakettiSBI_MAX_NOTE_COLUMNS, columns_needed[iv]))
    new_track.name = source_name .. " " .. PakettiSBIInstrumentLabel(iv)

    if notes[iv] then
      for pattern_index, lines in pairs(notes[iv]) do
        local pattern_track = song.patterns[pattern_index].tracks[new_index]
        for line_index, row in pairs(lines) do
          for column_index, data in ipairs(row) do
            if column_index <= PakettiSBI_MAX_NOTE_COLUMNS then
              PakettiSBIWriteNoteColumn(
                pattern_track.lines[line_index].note_columns[column_index], data)
            end
          end
        end
      end
    end

    if fx[iv] then
      for pattern_index, lines in pairs(fx[iv]) do
        local pattern_track = song.patterns[pattern_index].tracks[new_index]
        for line_index, effects in pairs(lines) do
          for column_index, data in ipairs(effects) do
            if column_index <= PakettiSBI_MAX_EFFECT_COLUMNS then
              local ec = pattern_track.lines[line_index].effect_columns[column_index]
              ec.number_value = data.number_value
              ec.amount_value = data.amount_value
            end
          end
        end
      end
    end
  end

  if devices_failed > 0 then
    print(string.format(
      "Paketti Split by Instrument: %d device(s) could not be copied onto the new tracks.",
      devices_failed))
  end

  if delete_source then
    song:delete_track_at(track_index)
  else
    -- Keep the track so its automation, routing and devices survive, but clear
    -- the notes so nothing double-triggers.
    for pattern_index = 1, #song.patterns do
      song.patterns[pattern_index].tracks[track_index]:clear()
    end
    song.tracks[track_index].name = source_name .. " (split, emptied)"
  end

  return #instrument_list, #instrument_list, had_automation
end

function PakettiSplitSelectedTrackByInstrument(delete_source)
  local song = renoise.song()
  local track_index = song.selected_track_index
  local track = song.tracks[track_index]

  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Split by Instrument: this only works on a sequencer track.")
    return
  end

  song:describe_undo("Paketti: Split Track by Instrument")
  local name = track.name
  local created, instruments, had_automation =
    PakettiSplitTrackByInstrument(track_index, delete_source)

  if created == 0 then
    renoise.app():show_status(string.format(
      "Split by Instrument: '%s' has no notes with an instrument, nothing to split.", name))
    return
  end

  local tail
  if delete_source then
    tail = had_automation
      and " Source track deleted - it had automation, which was deleted with it."
      or " Source track deleted."
  else
    tail = " Source track kept and emptied, so its automation and devices survive."
  end

  renoise.app():show_status(string.format(
    "Split by Instrument: '%s' split into %d track(s), one per instrument.%s",
    name, created, tail))
end

function PakettiSplitAllTracksByInstrument(delete_source)
  local song = renoise.song()
  song:describe_undo("Paketti: Split All Tracks by Instrument")

  local total_created, tracks_split, automation_lost = 0, 0, 0

  -- Walk backwards so inserting and deleting tracks cannot shift the ones we
  -- have not reached yet.
  for track_index = song.sequencer_track_count, 1, -1 do
    if song.tracks[track_index].type == renoise.Track.TRACK_TYPE_SEQUENCER then
      local created, _, had_automation =
        PakettiSplitTrackByInstrument(track_index, delete_source)
      if created > 0 then
        total_created = total_created + created
        tracks_split = tracks_split + 1
        if had_automation and delete_source then automation_lost = automation_lost + 1 end
      end
    end
  end

  if tracks_split == 0 then
    renoise.app():show_status("Split All Tracks by Instrument: no track had notes with an instrument.")
    return
  end

  local tail = ""
  if automation_lost > 0 then
    tail = string.format(" %d deleted source track(s) had automation, which was deleted with them.", automation_lost)
  end

  renoise.app():show_status(string.format(
    "Split All Tracks by Instrument: %d track(s) became %d track(s), one per instrument.%s",
    tracks_split, total_created, tail))
end

----------------------------------------------------------------------------
-- Menu entries, keybindings, MIDI mappings
----------------------------------------------------------------------------

local PakettiSBIVariants = {
  {label = "Split Selected Track by Instrument",
   run = function() PakettiSplitSelectedTrackByInstrument(false) end},
  {label = "Split Selected Track by Instrument (Delete Source Track)",
   run = function() PakettiSplitSelectedTrackByInstrument(true) end},
  {label = "Split All Tracks by Instrument",
   run = function() PakettiSplitAllTracksByInstrument(false) end},
  {label = "Split All Tracks by Instrument (Delete Source Tracks)",
   run = function() PakettiSplitAllTracksByInstrument(true) end}
}

for _, variant in ipairs(PakettiSBIVariants) do
  local label, run = variant.label, variant.run
  PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Pattern Editor:" .. label, invoke=run}
  PakettiAddMenuEntry{name="Pattern Editor:Paketti:Tracks:" .. label, invoke=run}
  PakettiAddMenuEntry{name="Mixer:Paketti:" .. label, invoke=run}
  renoise.tool():add_keybinding{name="Global:Paketti:" .. label, invoke=run}
  renoise.tool():add_midi_mapping{name="Paketti:" .. label, invoke=function(message)
    if message:is_trigger() then run() end
  end}
end
