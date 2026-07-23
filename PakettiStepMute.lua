-- PakettiStepMute.lua
-- Non-destructive step muting for the tracker pattern.
--
-- Idea: instead of DELETING notes to gate a melody on/off (the destructive
-- behaviour of the Groovebox 8120 Row/Step toggles), Step Mute flips the
-- NOTE-COLUMN VOLUME of a line to 0 and remembers the original volume, so the
-- notes are never lost. Toggle a step off -> volume 0 (silent). Toggle it back
-- on -> the exact original volume is restored (including "empty" = full volume).
--
-- Dynamic sliding window: N MIDI buttons (N = 8/16/32/64) map to N consecutive
-- lines of the selected pattern/track. The window follows the playhead while
-- playing, and the edit cursor when stopped. So with an LPD8's 8 pads you can
-- mute/unmute an 8-line chunk, and as playback moves into the next chunk the
-- pads automatically address those lines. Selected track only.
--
-- FEATURE-CARD >> features/step-mute.feature

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

-- PakettiStepMuteState[pattern_index][track_index][line] = { [note_col]=orig_volume_value, ... }
-- Presence of a line entry == that line is currently muted by Step Mute.
-- NOTE: plain assignment (not `X = X or {}`) — Renoise strict-globals mode throws
-- when READING an undeclared global, so referencing PakettiStepMuteState before it
-- exists aborts the whole tool load. Writing a fresh global is always safe.
PakettiStepMuteState = {}

local NOTE_NAMES = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}

local function PakettiStepMuteNoteName(note_value)
  if note_value == nil then return "---" end
  if note_value == 120 then return "OFF" end
  if note_value >= 121 then return "---" end
  local name = NOTE_NAMES[(note_value % 12) + 1]
  local octave = math.floor(note_value / 12)
  return name .. tostring(octave)
end

local function PakettiStepMuteGetWindowSize()
  local ok, v = pcall(function() return preferences.pakettiStepMuteWindowSize.value end)
  if ok and (v == 8 or v == 16 or v == 32 or v == 64) then return v end
  return 8
end

-- The line that the sliding window centres on: playback line while playing,
-- otherwise the edit cursor line.
local function PakettiStepMuteReferenceLine()
  local song = renoise.song()
  if song.transport.playing then
    return song.transport.playback_pos.line
  end
  return song.selected_line_index
end

-- Returns start_line (1-based), window_size, number_of_lines
local function PakettiStepMuteWindow()
  local song = renoise.song()
  local W = PakettiStepMuteGetWindowSize()
  local nlines = song.selected_pattern.number_of_lines
  local ref = PakettiStepMuteReferenceLine()
  if ref < 1 then ref = 1 end
  if ref > nlines then ref = nlines end
  local win_index = math.floor((ref - 1) / W)
  local start_line = win_index * W + 1
  return start_line, W, nlines
end

--------------------------------------------------------------------------------
-- State helpers
--------------------------------------------------------------------------------

local function stateGet(pi, ti, line)
  local p = PakettiStepMuteState[pi]; if not p then return nil end
  local t = p[ti]; if not t then return nil end
  return t[line]
end

local function stateSet(pi, ti, line, tbl)
  PakettiStepMuteState[pi] = PakettiStepMuteState[pi] or {}
  PakettiStepMuteState[pi][ti] = PakettiStepMuteState[pi][ti] or {}
  PakettiStepMuteState[pi][ti][line] = tbl
end

local function stateClear(pi, ti, line)
  if PakettiStepMuteState[pi] and PakettiStepMuteState[pi][ti] then
    PakettiStepMuteState[pi][ti][line] = nil
  end
end

--------------------------------------------------------------------------------
-- Dialog forward-declared refresh hook (set later); safe to call before dialog exists
--------------------------------------------------------------------------------

local PakettiStepMuteMarkDirty = function() end  -- reassigned by dialog section

--------------------------------------------------------------------------------
-- Core: toggle / mute / unmute a single line on the selected pattern+track
--------------------------------------------------------------------------------

function PakettiStepMuteToggleLine(line_index)
  local song = renoise.song()
  local track = song.selected_track
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Paketti Step Mute: selected track has no note columns")
    return
  end
  local pi = song.selected_pattern_index
  local ti = song.selected_track_index
  local patt = song:pattern(pi)
  local nlines = patt.number_of_lines
  if line_index < 1 or line_index > nlines then return end
  local ptrack = patt:track(ti)
  local line = ptrack:line(line_index)
  local vis = track.visible_note_columns

  local existing = stateGet(pi, ti, line_index)
  if existing then
    -- UNMUTE: restore each stored volume exactly. If the note was deleted while
    -- muted, clear the volume instead of writing a stray value onto an empty column.
    for col, vol in pairs(existing) do
      local nc = line:note_column(col)
      if nc.note_value >= 121 then
        nc.volume_value = 255  -- empty column: leave volume clear
      else
        nc.volume_value = vol
      end
    end
    stateClear(pi, ti, line_index)
    renoise.app():show_status(string.format("Paketti Step Mute: line %d UNMUTED (volume restored)", line_index))
  else
    -- MUTE: remember current volume for every real-note column, then silence.
    local stored = {}
    local any = false
    for col = 1, vis do
      local nc = line:note_column(col)
      if nc.note_value <= 119 then  -- real note (skip OFF=120, empty=121)
        stored[col] = nc.volume_value
        nc.volume_value = 0
        any = true
      end
    end
    if any then
      stateSet(pi, ti, line_index, stored)
      renoise.app():show_status(string.format("Paketti Step Mute: line %d MUTED (notes kept)", line_index))
    else
      renoise.app():show_status(string.format("Paketti Step Mute: line %d has no notes to mute", line_index))
    end
  end
  PakettiStepMuteMarkDirty()
end

-- Toggle by window-relative button index (1..N). Buttons beyond the current
-- window size are ignored.
function PakettiStepMuteToggleButton(button_index)
  local start_line, W = PakettiStepMuteWindow()
  if button_index > W then
    renoise.app():show_status(string.format(
      "Paketti Step Mute: button %d is beyond current window size %d", button_index, W))
    return
  end
  PakettiStepMuteToggleLine(start_line + button_index - 1)
end

-- Toggle the line under the edit cursor.
function PakettiStepMuteToggleCurrentRow()
  PakettiStepMuteToggleLine(renoise.song().selected_line_index)
end

-- Restore all muted steps in the selected pattern+track.
function PakettiStepMuteUnmuteAllInTrack()
  local song = renoise.song()
  local pi = song.selected_pattern_index
  local ti = song.selected_track_index
  local p = PakettiStepMuteState[pi]
  if not p or not p[ti] or not next(p[ti]) then
    renoise.app():show_status("Paketti Step Mute: nothing muted in this track")
    return
  end
  local ptrack = song:pattern(pi):track(ti)
  local count = 0
  for line_index, stored in pairs(p[ti]) do
    local line = ptrack:line(line_index)
    for col, vol in pairs(stored) do
      local nc = line:note_column(col)
      if nc.note_value >= 121 then nc.volume_value = 255 else nc.volume_value = vol end
    end
    count = count + 1
  end
  p[ti] = nil
  renoise.app():show_status(string.format("Paketti Step Mute: unmuted %d step(s) in track", count))
  PakettiStepMuteMarkDirty()
end

-- Move the edit cursor by one window (the window follows the cursor when stopped).
function PakettiStepMutePageWindow(dir)
  local song = renoise.song()
  local W = PakettiStepMuteGetWindowSize()
  local nlines = song.selected_pattern.number_of_lines
  local start_line = PakettiStepMuteWindow()
  local new = start_line + dir * W
  if new < 1 then new = 1 end
  if new > nlines then new = ((math.ceil(nlines / W) - 1) * W) + 1 end
  song.selected_line_index = new
  renoise.app():show_status(string.format("Paketti Step Mute: window at lines %d-%d",
    new, math.min(new + W - 1, nlines)))
  PakettiStepMuteMarkDirty()
end

function PakettiStepMuteSetWindowSize(size)
  if not (size == 8 or size == 16 or size == 32 or size == 64) then return end
  preferences.pakettiStepMuteWindowSize.value = size
  preferences:save_as("preferences.xml")
  renoise.app():show_status("Paketti Step Mute: window size = " .. size .. " lines")
  PakettiStepMuteMarkDirty()
end

--------------------------------------------------------------------------------
-- Dialog (visual "pattern space" that follows the playhead; click to toggle)
--------------------------------------------------------------------------------

local dialog = nil
local dvb = nil
local button_ids = {}
local header_id = nil
local idle_fn = nil
local last_start = -1
local last_ref = -1
local last_size = -1
local dirty = true

local COLOR_DEFAULT   = {0, 0, 0}          -- theme default (no note)
local COLOR_ACTIVE    = {0x44, 0xAA, 0x44} -- note present, playing
local COLOR_MUTED     = {0xCC, 0x44, 0x44} -- note present, muted
local COLOR_ACTIVE_PH = {0x66, 0xFF, 0x66} -- + playhead
local COLOR_MUTED_PH  = {0xFF, 0x66, 0x66} -- + playhead

local function PakettiStepMuteRefresh()
  if not (dialog and dialog.visible and dvb) then return end
  local song = renoise.song()
  local start_line, W, nlines = PakettiStepMuteWindow()
  local ref = PakettiStepMuteReferenceLine()
  local pi = song.selected_pattern_index
  local ti = song.selected_track_index
  local ptrack = song:pattern(pi):track(ti)
  local is_seq = (song.selected_track.type == renoise.Track.TRACK_TYPE_SEQUENCER)
  local vis = is_seq and song.selected_track.visible_note_columns or 0

  -- Header
  if header_id and dvb.views[header_id] then
    dvb.views[header_id].text = string.format(
      "Track: %s   |   Window lines %d-%d / %d   |   Size %d   |   %s",
      song.selected_track.name,
      start_line, math.min(start_line + W - 1, nlines), nlines, W,
      song.transport.playing and "PLAYING (follows playhead)" or "STOPPED (follows cursor)")
  end

  for i = 1, 64 do
    local id = button_ids[i]
    if id and dvb.views[id] then
      local btn = dvb.views[id]
      if i > W then
        btn.text = ""
        btn.color = COLOR_DEFAULT
        btn.active = false
      else
        local line_index = start_line + i - 1
        btn.active = true
        if line_index > nlines then
          btn.text = "--"
          btn.color = COLOR_DEFAULT
        else
          local note_txt = "---"
          if is_seq then
            local line = ptrack:line(line_index)
            for col = 1, vis do
              local nv = line:note_column(col).note_value
              if nv <= 119 then note_txt = PakettiStepMuteNoteName(nv); break end
            end
          end
          local muted = stateGet(pi, ti, line_index) ~= nil
          local has_note = (note_txt ~= "---")
          local is_ph = (line_index == ref)
          btn.text = string.format("%02d %s", line_index, note_txt)
          if not has_note then
            btn.color = COLOR_DEFAULT
          elseif muted then
            btn.color = is_ph and COLOR_MUTED_PH or COLOR_MUTED
          else
            btn.color = is_ph and COLOR_ACTIVE_PH or COLOR_ACTIVE
          end
        end
      end
    end
  end
  last_start = start_line
  last_ref = ref
  last_size = W
  dirty = false
end

-- reassign the module-level dirty marker now that the dialog section exists
PakettiStepMuteMarkDirty = function() dirty = true; PakettiStepMuteRefresh() end

local function PakettiStepMuteIdle()
  if not (dialog and dialog.visible) then
    if renoise.tool().app_idle_observable:has_notifier(PakettiStepMuteIdle) then
      renoise.tool().app_idle_observable:remove_notifier(PakettiStepMuteIdle)
    end
    return
  end
  local ok = pcall(function()
    local start_line, W = PakettiStepMuteWindow()
    local ref = PakettiStepMuteReferenceLine()
    if dirty or start_line ~= last_start or ref ~= last_ref or W ~= last_size then
      PakettiStepMuteRefresh()
    end
  end)
  if not ok then dirty = true end
end

local function PakettiStepMuteAttachIdle()
  if not renoise.tool().app_idle_observable:has_notifier(PakettiStepMuteIdle) then
    renoise.tool().app_idle_observable:add_notifier(PakettiStepMuteIdle)
  end
end

local function PakettiStepMuteDetachIdle()
  if renoise.tool().app_idle_observable:has_notifier(PakettiStepMuteIdle) then
    renoise.tool().app_idle_observable:remove_notifier(PakettiStepMuteIdle)
  end
end

function PakettiStepMuteShowDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    PakettiStepMuteDetachIdle()
    return
  end

  dvb = renoise.ViewBuilder()
  button_ids = {}
  local rnd = tostring(math.random(2, 30000))
  header_id = "pkt_stepmute_hdr_" .. rnd

  local W = PakettiStepMuteGetWindowSize()
  local per_row = math.min(W, 16)

  local button_rows = {}
  local current_row = nil
  for i = 1, W do
    if ((i - 1) % per_row) == 0 then
      current_row = dvb:row{}
      button_rows[#button_rows + 1] = current_row
    end
    local id = "pkt_stepmute_btn_" .. i .. "_" .. rnd
    button_ids[i] = id
    local btn_index = i
    current_row:add_child(dvb:button{
      id = id,
      width = 58,
      height = 30,
      text = "",
      notifier = function() PakettiStepMuteToggleButton(btn_index) end
    })
  end

  local content = dvb:column{
    margin = 6,
    dvb:text{ id = header_id, text = "", font = "bold", width = per_row * 60 },
    dvb:text{ text = "Click a step to mute/unmute it (volume flips, notes are kept). Window follows the playhead.", width = per_row * 60 },
  }
  for _, r in ipairs(button_rows) do content:add_child(r) end

  content:add_child(dvb:row{
    dvb:button{ text = "<< Window", width = 90, notifier = function() PakettiStepMutePageWindow(-1) end },
    dvb:button{ text = "Window >>", width = 90, notifier = function() PakettiStepMutePageWindow(1) end },
    dvb:button{ text = "Unmute All", width = 90, notifier = function() PakettiStepMuteUnmuteAllInTrack() end },
    dvb:text{ text = "  Size:", width = 44 },
    dvb:button{ text = "8",  width = 34, notifier = function() PakettiStepMuteSetWindowSizeAndRebuild(8) end },
    dvb:button{ text = "16", width = 34, notifier = function() PakettiStepMuteSetWindowSizeAndRebuild(16) end },
    dvb:button{ text = "32", width = 34, notifier = function() PakettiStepMuteSetWindowSizeAndRebuild(32) end },
    dvb:button{ text = "64", width = 34, notifier = function() PakettiStepMuteSetWindowSizeAndRebuild(64) end },
  })

  dialog = renoise.app():show_custom_dialog("Paketti Step Mute (Non-Destructive)", content, my_keyhandler_func)
  PakettiStepMuteAttachIdle()
  dirty = true
  PakettiStepMuteRefresh()
end

-- Change window size and rebuild the dialog grid to match (button count changes).
function PakettiStepMuteSetWindowSizeAndRebuild(size)
  PakettiStepMuteSetWindowSize(size)
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    PakettiStepMuteDetachIdle()
    PakettiStepMuteShowDialog()
  end
end

-- Song-lifecycle safety: clear stale mute memory and detach the idle observer
-- when a new/other document is loaded (avoids restoring volumes into the wrong song).
renoise.tool().app_release_document_observable:add_notifier(function()
  PakettiStepMuteDetachIdle()
  if dialog and dialog.visible then dialog:close() end
  dialog = nil
  PakettiStepMuteState = {}
end)

--------------------------------------------------------------------------------
-- Menu entries
--------------------------------------------------------------------------------

PakettiAddMenuEntry{ name = "Main Menu:Tools:Paketti:Sequencer:Step Mute (Non-Destructive)...", invoke = function() PakettiStepMuteShowDialog() end }
PakettiAddMenuEntry{ name = "Pattern Editor:Paketti:Step Mute:Show Step Mute Dialog...", invoke = function() PakettiStepMuteShowDialog() end }
PakettiAddMenuEntry{ name = "Pattern Editor:Paketti:Step Mute:Toggle Mute Current Row", invoke = function() PakettiStepMuteToggleCurrentRow() end }
PakettiAddMenuEntry{ name = "Pattern Editor:Paketti:Step Mute:Unmute All in Track", invoke = function() PakettiStepMuteUnmuteAllInTrack() end }

--------------------------------------------------------------------------------
-- Keybindings (Global scope, exactly 3 colon-separated parts)
--------------------------------------------------------------------------------

renoise.tool():add_keybinding{ name = "Global:Paketti:Step Mute Show/Hide Dialog", invoke = function() PakettiStepMuteShowDialog() end }
renoise.tool():add_keybinding{ name = "Global:Paketti:Step Mute Toggle Current Row", invoke = function() PakettiStepMuteToggleCurrentRow() end }
renoise.tool():add_keybinding{ name = "Global:Paketti:Step Mute Unmute All in Track", invoke = function() PakettiStepMuteUnmuteAllInTrack() end }
renoise.tool():add_keybinding{ name = "Global:Paketti:Step Mute Window Previous", invoke = function() PakettiStepMutePageWindow(-1) end }
renoise.tool():add_keybinding{ name = "Global:Paketti:Step Mute Window Next", invoke = function() PakettiStepMutePageWindow(1) end }
renoise.tool():add_keybinding{ name = "Global:Paketti:Step Mute Window Size 8", invoke = function() PakettiStepMuteSetWindowSizeAndRebuild(8) end }
renoise.tool():add_keybinding{ name = "Global:Paketti:Step Mute Window Size 16", invoke = function() PakettiStepMuteSetWindowSizeAndRebuild(16) end }
renoise.tool():add_keybinding{ name = "Global:Paketti:Step Mute Window Size 32", invoke = function() PakettiStepMuteSetWindowSizeAndRebuild(32) end }
renoise.tool():add_keybinding{ name = "Global:Paketti:Step Mute Window Size 64", invoke = function() PakettiStepMuteSetWindowSizeAndRebuild(64) end }

--------------------------------------------------------------------------------
-- MIDI mappings
--------------------------------------------------------------------------------

-- 64 generic window-relative step buttons. Each triggers the corresponding line
-- in the current sliding window. Map any controller's pads to Steps 01-NN.
for i = 1, 64 do
  renoise.tool():add_midi_mapping{
    name = string.format("Paketti:Step Mute Toggle Step %02d [Trigger]", i),
    invoke = function(message) if message:is_trigger() then PakettiStepMuteToggleButton(i) end end
  }
end

-- Per-controller banks. These are separate, independently-bindable copies of the
-- window-relative step buttons so you can have several controllers plugged in at
-- once and map each one's pads to its OWN bank (they don't fight over one target).
-- All banks drive the same shared sliding window. Bank size matches each device's
-- real pad/button surface:
--   LPD8      = 8  pads
--   MidiMix   = 16 buttons (8 mute + 8 rec-arm)
--   APCKey25  = 40 clip-grid pads (8 x 5)
--   Launchpad = 64 grid pads (8 x 8)
local PakettiStepMuteControllerBanks = {
  { prefix = "LPD8",      count = 8  },
  { prefix = "MidiMix",   count = 16 },
  { prefix = "APCKey25",  count = 40 },
  { prefix = "Launchpad", count = 64 },
}
for _, bank in ipairs(PakettiStepMuteControllerBanks) do
  for i = 1, bank.count do
    local step_index = i
    renoise.tool():add_midi_mapping{
      name = string.format("Paketti:Step Mute %s Step %02d [Trigger]", bank.prefix, i),
      invoke = function(message) if message:is_trigger() then PakettiStepMuteToggleButton(step_index) end end
    }
  end
end

renoise.tool():add_midi_mapping{ name = "Paketti:Step Mute Show/Hide Dialog [Trigger]", invoke = function(message) if message:is_trigger() then PakettiStepMuteShowDialog() end end }
renoise.tool():add_midi_mapping{ name = "Paketti:Step Mute Toggle Current Row [Trigger]", invoke = function(message) if message:is_trigger() then PakettiStepMuteToggleCurrentRow() end end }
renoise.tool():add_midi_mapping{ name = "Paketti:Step Mute Unmute All in Track [Trigger]", invoke = function(message) if message:is_trigger() then PakettiStepMuteUnmuteAllInTrack() end end }
renoise.tool():add_midi_mapping{ name = "Paketti:Step Mute Window Previous [Trigger]", invoke = function(message) if message:is_trigger() then PakettiStepMutePageWindow(-1) end end }
renoise.tool():add_midi_mapping{ name = "Paketti:Step Mute Window Next [Trigger]", invoke = function(message) if message:is_trigger() then PakettiStepMutePageWindow(1) end end }
renoise.tool():add_midi_mapping{ name = "Paketti:Step Mute Set Window Size 8 [Trigger]", invoke = function(message) if message:is_trigger() then PakettiStepMuteSetWindowSizeAndRebuild(8) end end }
renoise.tool():add_midi_mapping{ name = "Paketti:Step Mute Set Window Size 16 [Trigger]", invoke = function(message) if message:is_trigger() then PakettiStepMuteSetWindowSizeAndRebuild(16) end end }
renoise.tool():add_midi_mapping{ name = "Paketti:Step Mute Set Window Size 32 [Trigger]", invoke = function(message) if message:is_trigger() then PakettiStepMuteSetWindowSizeAndRebuild(32) end end }
renoise.tool():add_midi_mapping{ name = "Paketti:Step Mute Set Window Size 64 [Trigger]", invoke = function(message) if message:is_trigger() then PakettiStepMuteSetWindowSizeAndRebuild(64) end end }
renoise.tool():add_midi_mapping{ name = "Paketti:Step Mute Set Window Size x[Knob]", invoke = function(message)
  if message:is_abs_value() then
    local v = message.int_value
    local size = 8
    if v >= 96 then size = 64 elseif v >= 64 then size = 32 elseif v >= 32 then size = 16 else size = 8 end
    PakettiStepMuteSetWindowSizeAndRebuild(size)
  end
end }
