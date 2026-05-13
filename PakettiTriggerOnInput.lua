--------------------------------------------------------------------------------
-- PakettiTriggerOnInput.lua
-- "Trigger Sample on Pattern Input During Record"
--
-- When enabled: any note typed into the pattern while edit_mode is ON will
-- immediately audition the note via trigger_instrument_note_on(), regardless
-- of whether playback is running or stopped, and regardless of follow mode.
--
-- Uses trigger_instrument_note_on (NOT trigger_pattern_line, which only works
-- when playback is stopped — API limitation discovered in PakettiPatternEditor
-- line 8449).
--
-- Detection: pattern:add_line_notifier() (event-driven, not timer polling).
-- Lifecycle follows the proven SBx / Column Cycle Keyjazz pattern.
--
-- API 6.2+ only.
--------------------------------------------------------------------------------
if not PAKETTI_HAS_TRIGGER_LINE then return end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
PakettiTriggerOnInputEnabled = false

local toi_notifier_pattern_index = nil  -- which pattern currently has our notifier
local toi_active_notes = {}  -- currently ringing preview notes for note-off

--------------------------------------------------------------------------------
-- Core callback: fires when any line in the current pattern is edited
--------------------------------------------------------------------------------
local function toi_on_line_edited(pos)
  -- pos = {pattern = int, track = int, line = int}
  if not PakettiTriggerOnInputEnabled then return end

  local song = renoise.song()
  if not song then return end

  -- Must be in edit mode (record mode)
  if not song.transport.edit_mode then return end

  -- Read the edited line and check if it has an actual note (value < 120)
  local ok, pattern = pcall(function() return song:pattern(pos.pattern) end)
  if not ok or not pattern then return end

  local ok2, pattern_track = pcall(function() return pattern:track(pos.track) end)
  if not ok2 or not pattern_track then return end

  local line = pattern_track:line(pos.line)

  -- Stop previously triggered preview notes
  for _, note_info in ipairs(toi_active_notes) do
    pcall(function()
      song:trigger_instrument_note_off(note_info.instr, note_info.track, note_info.notes)
    end)
  end
  toi_active_notes = {}

  -- Collect notes from all note columns, grouped by instrument
  local instr_notes = {}  -- {[instr_index] = {notes={...}, velocity=float}}
  local has_any_note = false

  for col_idx = 1, #line.note_columns do
    local nc = line:note_column(col_idx)
    if nc.note_value < 120 then
      has_any_note = true
      local instr_idx
      if nc.instrument_value ~= 255 then
        instr_idx = nc.instrument_value + 1  -- 0-based column → 1-based API
      else
        instr_idx = song.selected_instrument_index
      end

      if not instr_notes[instr_idx] then
        instr_notes[instr_idx] = {notes = {}, velocity = 1.0}
      end
      table.insert(instr_notes[instr_idx].notes, nc.note_value)

      -- Respect volume column if present (0-127, 255=empty)
      if nc.volume_value ~= 255 and nc.volume_value <= 127 then
        instr_notes[instr_idx].velocity = nc.volume_value / 127.0
      end
    end
  end

  if not has_any_note then return end

  -- Use trigger_instrument_note_on — works during playback
  -- (trigger_pattern_line only works when stopped — API limitation)
  for instr_idx, info in pairs(instr_notes) do
    pcall(function()
      song:trigger_instrument_note_on(instr_idx, pos.track, info.notes, info.velocity)
    end)
    table.insert(toi_active_notes, {instr = instr_idx, track = pos.track, notes = info.notes})
  end
end

--------------------------------------------------------------------------------
-- Notifier lifecycle: attach to / detach from patterns
--------------------------------------------------------------------------------
local function toi_remove_notifier()
  local song = renoise.song()
  if not song then
    toi_notifier_pattern_index = nil
    return
  end
  if toi_notifier_pattern_index then
    local ok, pat = pcall(function() return song:pattern(toi_notifier_pattern_index) end)
    if ok and pat then
      if pat:has_line_notifier(toi_on_line_edited) then
        pat:remove_line_notifier(toi_on_line_edited)
      end
    end
    toi_notifier_pattern_index = nil
  end
end

local function toi_attach_notifier()
  toi_remove_notifier()
  local song = renoise.song()
  if not song then return end

  local pattern_index = song.selected_pattern_index
  local ok, pattern = pcall(function() return song:pattern(pattern_index) end)
  if not ok or not pattern then return end

  if not pattern:has_line_notifier(toi_on_line_edited) then
    pattern:add_line_notifier(toi_on_line_edited)
  end
  toi_notifier_pattern_index = pattern_index
end

--------------------------------------------------------------------------------
-- Pattern change observer: re-attach notifier when user navigates patterns
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
  if song then
    if song.selected_pattern_index_observable:has_notifier(toi_on_pattern_change) then
      song.selected_pattern_index_observable:remove_notifier(toi_on_pattern_change)
    end
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
end

local function toi_disable()
  PakettiTriggerOnInputEnabled = false
  preferences.pakettiTriggerOnInputEnabled.value = false
  preferences:save_as("preferences.xml")
  toi_remove_notifier()
  toi_remove_pattern_observer()
  renoise.app():show_status("Paketti: Trigger Sample on Pattern Input During Record OFF")
end

--------------------------------------------------------------------------------
-- Toggle (called by menu, keybinding, MIDI)
--------------------------------------------------------------------------------
function PakettiTriggerOnInputToggle()
  if PakettiTriggerOnInputEnabled then
    toi_disable()
  else
    toi_enable()
  end
end

--------------------------------------------------------------------------------
-- Boot init (called from main.lua PakettiOnNewDocument)
--------------------------------------------------------------------------------
function PakettiTriggerOnInputOnNewDocument()
  if preferences.pakettiTriggerOnInputEnabled.value then
    toi_enable()
  else
    -- Make sure we're clean
    PakettiTriggerOnInputEnabled = false
    toi_remove_notifier()
    toi_remove_pattern_observer()
  end
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

-- Keybinding
renoise.tool():add_keybinding{
  name = "Global:Paketti:Trigger Sample on Pattern Input During Record Toggle",
  invoke = function() PakettiTriggerOnInputToggle() end
}

-- Pattern Editor context menu
PakettiAddMenuEntry{
  name = "Pattern Editor:Paketti:Trigger Sample on Pattern Input During Record Toggle",
  invoke = function() PakettiTriggerOnInputToggle() end,
  selected = function() return PakettiTriggerOnInputEnabled end
}

-- MIDI mapping
renoise.tool():add_midi_mapping{
  name = "Paketti:Trigger Sample on Pattern Input During Record x[Toggle]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiTriggerOnInputToggle()
    end
  end
}
