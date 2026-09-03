--[[============================================================================
PakettiFindMultiInstrumentColumns.lua

Finds note columns that play more than one instrument, and jumps to them.

A note column holding two or more different instrument numbers is usually
either something you did on purpose, or a mess left over from pasting. Either
way it is worth being able to find them, and it pairs with Split Track by
Instrument, which is how you untangle them once found.

Scans the pattern SEQUENCE in playback order, so hits come out in the order you
would hear them, and a pattern used twice in the sequence is reported at each
position. Sequencer tracks only.

Works with or without the dialog: the Find Next / Find Previous shortcuts jump
straight to the next hit, wrapping around, and rescan by themselves when the
song has changed underneath them.
============================================================================]]--

local PakettiFMIC_EMPTY_INSTRUMENT = 255

local PakettiFMICDialog = nil
local PakettiFMICVb = nil
local PakettiFMICHits = {}
local PakettiFMICScannedSongName = nil

-- Collects every note column containing 2+ distinct instruments.
-- Ordered by sequence position, then track, then column.
local function PakettiFMICBuildHits()
  local song = renoise.song()
  local sequence = song.sequencer.pattern_sequence
  local hits = {}

  for sequence_index = 1, #sequence do
    local pattern = song.patterns[sequence[sequence_index]]
    local number_of_lines = pattern.number_of_lines

    for track_index = 1, #song.tracks do
      local track = song.tracks[track_index]
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER and track.visible_note_columns > 0 then
        local visible = track.visible_note_columns
        local pattern_track = pattern.tracks[track_index]

        if not pattern_track.is_empty then
          local seen, distinct, first_row, instruments = {}, {}, {}, {}
          for column_index = 1, visible do
            seen[column_index] = {}
            distinct[column_index] = 0
            instruments[column_index] = {}
          end

          for line_index = 1, number_of_lines do
            local line = pattern_track.lines[line_index]
            if not line.is_empty then
              for column_index = 1, visible do
                local instrument_value = line.note_columns[column_index].instrument_value
                if instrument_value ~= PakettiFMIC_EMPTY_INSTRUMENT
                  and not seen[column_index][instrument_value] then
                  seen[column_index][instrument_value] = true
                  distinct[column_index] = distinct[column_index] + 1
                  local list = instruments[column_index]
                  list[#list + 1] = instrument_value
                  if first_row[column_index] == nil then first_row[column_index] = line_index end
                end
              end
            end
          end

          for column_index = 1, visible do
            if distinct[column_index] >= 2 then
              table.sort(instruments[column_index])
              hits[#hits + 1] = {
                sequence_index = sequence_index,
                pattern_index = sequence[sequence_index],
                track_index = track_index,
                column_index = column_index,
                row = first_row[column_index] or 1,
                instruments = instruments[column_index]
              }
            end
          end
        end
      end
    end
  end

  return hits
end

-- Moves the edit cursor onto a hit, tolerating edits made since the scan.
local function PakettiFMICJumpTo(hit)
  local song = renoise.song()
  song.selected_sequence_index = math.min(hit.sequence_index, #song.sequencer.pattern_sequence)
  song.selected_track_index = math.min(hit.track_index, #song.tracks)

  local track = song.tracks[song.selected_track_index]
  local column = math.min(hit.column_index, math.max(track.visible_note_columns, 1))
  pcall(function() song.selected_note_column_index = column end)

  local pattern = song.patterns[song.sequencer.pattern_sequence[song.selected_sequence_index]]
  song.selected_line_index = math.min(hit.row, pattern.number_of_lines)

  renoise.app().window.active_middle_frame =
    renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

local function PakettiFMICDescribeHit(index, wrapped)
  local song = renoise.song()
  local hit = PakettiFMICHits[index]
  local names = {}
  for _, instrument_value in ipairs(hit.instruments) do
    names[#names + 1] = string.format("%02X", instrument_value)
  end
  return string.format(
    "%d/%d%s  Seq %02d  Pat %02d  %s  Col %d  Row %02d  -  instruments %s",
    index, #PakettiFMICHits, wrapped and "  (wrapped)" or "",
    hit.sequence_index - 1, hit.pattern_index - 1,
    song.tracks[hit.track_index].name, hit.column_index, hit.row - 1,
    table.concat(names, " "))
end

local function PakettiFMICSetStatus(text)
  if PakettiFMICVb and PakettiFMICVb.views.pakettiFMICStatus then
    PakettiFMICVb.views.pakettiFMICStatus.text = text
  end
  renoise.app():show_status(text)
end

-- Next/previous hit relative to the cursor, wrapping around.
local function PakettiFMICFindInDirection(forward)
  local song = renoise.song()
  local s = song.selected_sequence_index
  local t = song.selected_track_index
  local c = song.selected_note_column_index

  if forward then
    for i = 1, #PakettiFMICHits do
      local h = PakettiFMICHits[i]
      if h.sequence_index > s
        or (h.sequence_index == s and h.track_index > t)
        or (h.sequence_index == s and h.track_index == t and h.column_index > c) then
        return i, false
      end
    end
    return 1, true
  end

  for i = #PakettiFMICHits, 1, -1 do
    local h = PakettiFMICHits[i]
    if h.sequence_index < s
      or (h.sequence_index == s and h.track_index < t)
      or (h.sequence_index == s and h.track_index == t and h.column_index < c) then
      return i, false
    end
  end
  return #PakettiFMICHits, true
end

function PakettiFindMultiInstrumentColumnsRescan()
  PakettiFMICHits = PakettiFMICBuildHits()
  PakettiFMICScannedSongName = renoise.song().name
  if #PakettiFMICHits == 0 then
    PakettiFMICSetStatus("Find Multi-Instrument Columns: none found, every note column plays a single instrument.")
  else
    PakettiFMICSetStatus(string.format(
      "Find Multi-Instrument Columns: found %d column(s) playing more than one instrument.",
      #PakettiFMICHits))
  end
  return #PakettiFMICHits
end

function PakettiFindMultiInstrumentColumnsNavigate(forward)
  -- Scan on first use, so the shortcuts work without opening the dialog.
  if #PakettiFMICHits == 0 or PakettiFMICScannedSongName ~= renoise.song().name then
    if PakettiFindMultiInstrumentColumnsRescan() == 0 then return end
  end

  if #PakettiFMICHits == 0 then
    PakettiFMICSetStatus("Find Multi-Instrument Columns: none found.")
    return
  end

  local index, wrapped = PakettiFMICFindInDirection(forward)
  PakettiFMICJumpTo(PakettiFMICHits[index])
  PakettiFMICSetStatus(PakettiFMICDescribeHit(index, wrapped))
end

function PakettiFindMultiInstrumentColumnsDialog()
  if PakettiFMICDialog and PakettiFMICDialog.visible then
    PakettiFMICDialog:close()
    PakettiFMICDialog = nil
    return
  end

  PakettiFMICVb = renoise.ViewBuilder()
  local DIALOG_MARGIN = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN
  local CONTROL_SPACING = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING

  PakettiFMICHits = PakettiFMICBuildHits()
  PakettiFMICScannedSongName = renoise.song().name

  local initial = (#PakettiFMICHits == 0)
    and "None found - every note column plays a single instrument."
    or string.format("Found %d column(s) playing more than one instrument. Press Find Next.", #PakettiFMICHits)

  local content = PakettiFMICVb:column{
    margin = DIALOG_MARGIN,
    spacing = CONTROL_SPACING,
    PakettiFMICVb:text{id = "pakettiFMICStatus", text = initial, font = "mono", width = 560},
    PakettiFMICVb:row{
      spacing = CONTROL_SPACING,
      PakettiFMICVb:button{text = "Find Next", width = 90,
        notifier = function() PakettiFindMultiInstrumentColumnsNavigate(true) end},
      PakettiFMICVb:button{text = "Find Previous", width = 100,
        notifier = function() PakettiFindMultiInstrumentColumnsNavigate(false) end},
      PakettiFMICVb:button{text = "Rescan", width = 80,
        notifier = function() PakettiFindMultiInstrumentColumnsRescan() end},
      PakettiFMICVb:button{text = "Split This Track by Instrument", width = 200,
        notifier = function()
          if type(rawget(_G, "PakettiSplitSelectedTrackByInstrument")) == "function" then
            PakettiSplitSelectedTrackByInstrument(false)
            PakettiFindMultiInstrumentColumnsRescan()
          else
            renoise.app():show_status("Split Track by Instrument is not available.")
          end
        end}
    }
  }

  local keyhandler = function(dialog, key)
    if key.modifiers == "" and key.name == "return" then
      PakettiFindMultiInstrumentColumnsNavigate(true)
      return nil
    elseif key.modifiers == "shift" and key.name == "return" then
      PakettiFindMultiInstrumentColumnsNavigate(false)
      return nil
    elseif key.modifiers == "" and key.name == "esc" then
      dialog:close()
      PakettiFMICDialog = nil
      return nil
    end
    return key
  end

  PakettiFMICDialog = renoise.app():show_custom_dialog(
    "Paketti Find Multi-Instrument Columns", content, keyhandler)
end

----------------------------------------------------------------------------
-- Menu entries, keybindings, MIDI mappings
----------------------------------------------------------------------------

local PakettiFMICActions = {
  {label = "Find Multi-Instrument Columns...", run = PakettiFindMultiInstrumentColumnsDialog},
  {label = "Find Multi-Instrument Columns Next", run = function() PakettiFindMultiInstrumentColumnsNavigate(true) end},
  {label = "Find Multi-Instrument Columns Previous", run = function() PakettiFindMultiInstrumentColumnsNavigate(false) end},
  {label = "Find Multi-Instrument Columns Rescan", run = function() PakettiFindMultiInstrumentColumnsRescan() end}
}

for _, action in ipairs(PakettiFMICActions) do
  local label, run = action.label, action.run
  PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Pattern Editor:" .. label, invoke=run}
  PakettiAddMenuEntry{name="Pattern Editor:Paketti:Tracks:" .. label, invoke=run}
  renoise.tool():add_keybinding{name="Global:Paketti:" .. label, invoke=run}
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:" .. label, invoke=run}
  renoise.tool():add_midi_mapping{name="Paketti:" .. label, invoke=function(message)
    if message:is_trigger() then run() end
  end}
end
