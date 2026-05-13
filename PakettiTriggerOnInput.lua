--------------------------------------------------------------------------------
-- PakettiTriggerOnInput.lua
-- "Trigger Sample on Pattern Input During Record"
--
-- STATUS: NOT CURRENTLY POSSIBLE WITH RENOISE 3.5 / API 6.2
--
-- The goal: while the song is playing AND edit mode is ON AND follow is OFF,
-- type a note in the pattern and HEAR it (without modifying the recorded
-- pattern beyond the note the user typed).
--
-- What we tried:
--   1) trigger_pattern_line()
--      -> API explicitly errors when playback is running.
--   2) trigger_instrument_note_on() (the obvious replacement, undocumented
--      restriction)
--      -> produces audio when transport is stopped, SILENT during playback.
--      Verified empirically with a manual test that bypasses the line
--      notifier path entirely. Same instrument, same track, same note —
--      only difference is transport.playing.
--   3) /renoise/trigger/note_on via Renoise's built-in OSC server
--      -> osc.md line 248 shows this command is internally implemented as
--      song:trigger_instrument_note_on(...), so it inherits the same
--      silent-during-playback behavior. ADDITIONALLY, when edit_mode is
--      ON, OSC trigger inputs are RECORDED into the pattern as new notes
--      (just like an external MIDI controller in record mode), which
--      causes runaway feedback when combined with add_line_edited_notifier.
--
-- The 7 built-in OSC commands (osc.md lines 351-357) do not include any
-- preview-without-recording endpoint. There is no Lua API to feed audio
-- to Renoise's preview/keyjazz channel during playback.
--
-- Until Renoise exposes such an API, this toggle is a documented no-op
-- and the file just shows a status message. The menu entry, keybinding,
-- and MIDI mapping are kept so user setups don't break.
--
-- Workaround for users: keep Follow Player ON — Renoise auditions natively
-- when the edit cursor and playback cursor coincide.
--------------------------------------------------------------------------------

PakettiTriggerOnInputEnabled = false

local function toi_show_unsupported()
  renoise.app():show_status(
    "Trigger Sample on Pattern Input During Record: not currently possible — Renoise API does not expose preview-without-recording during playback. Use Follow Player ON as workaround."
  )
end

function PakettiTriggerOnInputToggle()
  toi_show_unsupported()
end

function PakettiTriggerOnInputOnNewDocument()
  -- Feature is parked. Force the persisted pref off so old "true" values
  -- from previous attempts can't auto-re-enable on next boot.
  PakettiTriggerOnInputEnabled = false
  if preferences and preferences.pakettiTriggerOnInputEnabled then
    if preferences.pakettiTriggerOnInputEnabled.value ~= false then
      preferences.pakettiTriggerOnInputEnabled.value = false
      preferences:save_as("preferences.xml")
    end
  end
end

function PakettiTriggerOnInputManualTest()
  toi_show_unsupported()
end

--------------------------------------------------------------------------------
-- Registration (kept so existing user keybindings/menus don't disappear)
--------------------------------------------------------------------------------
renoise.tool():add_keybinding{
  name = "Global:Paketti:Trigger Sample on Pattern Input During Record Toggle",
  invoke = function() PakettiTriggerOnInputToggle() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Trigger Sample Manual Test",
  invoke = function() PakettiTriggerOnInputManualTest() end
}

-- PARKED 2026-05-13: menu entries disabled. Keybinding + MIDI mapping
-- remain so user-customised setups dont break. Re-enable both menu
-- entries (and PakettiMenuConfig.lua line 3492 for Main Menu:Options)
-- when Renoise exposes a preview-during-playback API.
-- PakettiAddMenuEntry{
--   name = "Pattern Editor:Paketti:Trigger Sample on Pattern Input During Record Toggle",
--   invoke = function() PakettiTriggerOnInputToggle() end,
--   selected = function() return PakettiTriggerOnInputEnabled end
-- }
--
-- PakettiAddMenuEntry{
--   name = "Main Menu:Tools:Paketti:Debug:Trigger Sample Manual Test",
--   invoke = function() PakettiTriggerOnInputManualTest() end
-- }

renoise.tool():add_midi_mapping{
  name = "Paketti:Trigger Sample on Pattern Input During Record x[Toggle]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiTriggerOnInputToggle()
    end
  end
}
