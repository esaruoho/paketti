--------------------------------------------------------------------------------
-- PakettiTriggerOnInput.lua
-- "Trigger Sample on Pattern Input During Record"
--
-- When enabled: any note typed into the pattern while edit_mode is ON will
-- immediately audition the edited line via trigger_pattern_line(), regardless
-- of whether playback is running or stopped, and regardless of follow mode.
--
-- Uses pattern:add_line_notifier() (event-driven, not timer polling).
-- Lifecycle follows the proven SBx / Column Cycle Keyjazz pattern.
--
-- API 6.2+ only (requires trigger_pattern_line).
--------------------------------------------------------------------------------
if not PAKETTI_HAS_TRIGGER_LINE then return end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
PakettiTriggerOnInputEnabled = false

local toi_notifier_pattern_index = nil  -- which pattern currently has our notifier
local toi_previous_line_snapshot = {}   -- {[track_idx] = {line_hash}} to detect actual note entry

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
  local has_note = false
  for col_idx = 1, #line.note_columns do
    local nc = line:note_column(col_idx)
    if nc.note_value < 120 then
      has_note = true
      break
    end
  end

  if not has_note then return end

  -- Trigger the line — plays all note columns with correct instruments/volumes
  pcall(function()
    song:trigger_pattern_line(pos.line)
  end)
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
