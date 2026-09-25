-- PakettiTrackNav.lua
-- Collapse-aware track navigation, ported from Hex's HexTools.
--
-- What this adds over Renoise's built-in next/prev track:
--   * Jump to next/previous ACTIVE track, skipping collapsed ones.
--   * Jump to next/previous COLLAPSED (null) track.
--   * Optional "auto-collapse null tracks before jump" so a jump first tidies
--     the pattern down to only the tracks that carry notes.
--   * Optional "auto-collapse on focus loss": when you leave a track that was
--     empty when you jumped to it, it re-collapses itself.
--   * "...and solo" variants that mute every other sequencer track.
--
-- Deliberate deviations from the HexTools original (to protect the user's song):
--   * The original recolours tracks (blue/grey/red) to signal active/null/focus.
--     Paketti does NOT touch track colours — that would clobber the user's theme.
--   * Auto-collapse-on-focus-loss defaults OFF (it mutates collapse state on
--     every track selection change; opt in via the toggle).
--
-- Song-lifecycle safety (see project_song_lifecycle_sigsegv): the selection
-- observer is (re)attached on each new document and detached on document
-- release, so a New/Load Song never leaves a notifier pointing at a dead song.

local M = {}

-- Session state (not persisted; the HexTools original didn't persist either).
local auto_collapse_before_jump   = true
local auto_collapse_on_focus_loss = false
local last_jumped_track           = nil
local last_jumped_track_was_null  = nil
local pattern_collapsed_state     = {}
local last_collapsed_pattern_idx  = nil

----------------------------------------------------------------------
-- track-state helpers
----------------------------------------------------------------------
local function is_sequencer_track(track)
  return track.type == renoise.Track.TRACK_TYPE_SEQUENCER
end

-- "Active" = the track has note/effect data in the current pattern.
local function is_track_active(track_idx)
  local song = renoise.song()
  return not song:pattern(song.selected_pattern_index):track(track_idx).is_empty
end

local function is_track_null(track_idx)
  return not is_track_active(track_idx)
end

local function is_track_collapsed(track_idx)
  return renoise.song().tracks[track_idx].collapsed
end

----------------------------------------------------------------------
-- collapse / expand null tracks in the current pattern
----------------------------------------------------------------------
local function collapse_null_tracks_in_pattern()
  local song     = renoise.song()
  local patt_idx = song.selected_pattern_index
  local initial  = (last_collapsed_pattern_idx ~= patt_idx)

  local function apply_state(expand)
    for t = 1, #song.tracks do
      local track = song.tracks[t]
      if is_sequencer_track(track) then
        if expand then
          track.collapsed = false
        else
          track.collapsed = not is_track_active(t)
        end
      end
    end
    pattern_collapsed_state[patt_idx] = not expand
  end

  if initial then
    apply_state(false)
    renoise.app():show_status("Collapsed null tracks.")
  else
    local currently_collapsed = pattern_collapsed_state[patt_idx]
    apply_state(currently_collapsed) -- toggle
    renoise.app():show_status(currently_collapsed and "Expanded all tracks."
                                                  or  "Collapsed null tracks.")
  end
  last_collapsed_pattern_idx = patt_idx
end
M.collapse_unused_tracks_in_pattern = collapse_null_tracks_in_pattern

local function is_pattern_collapsed()
  return pattern_collapsed_state[renoise.song().selected_pattern_index] == true
end

local function maybe_collapse_before_jump()
  if auto_collapse_before_jump and not is_pattern_collapsed() then
    collapse_null_tracks_in_pattern()
  end
end

local function handle_leaving_focused_track()
  if not last_jumped_track then return end
  local song  = renoise.song()
  local track = song.tracks[last_jumped_track]
  if track and is_sequencer_track(track) and is_track_null(last_jumped_track) then
    track.collapsed = true
  end
  last_jumped_track, last_jumped_track_was_null = nil, nil
end

----------------------------------------------------------------------
-- shared jump primitive: find the next non-collapsed sequencer track
-- forward (dir=1) or backward (dir=-1), wrapping around.
----------------------------------------------------------------------
local function jump_directional(dir, want_collapsed, solo)
  local song = renoise.song()
  maybe_collapse_before_jump()

  local cur = song.selected_track_index
  local tot = #song.tracks

  if last_jumped_track and last_jumped_track == cur then
    handle_leaving_focused_track()
  end

  if solo then
    for i = 1, tot do
      local tr = song.tracks[i]
      if is_sequencer_track(tr) then tr.mute_state = renoise.Track.MUTE_STATE_MUTED end
    end
  end

  local order = {}
  if dir > 0 then
    for i = cur + 1, tot do order[#order + 1] = i end
    for i = 1, cur - 1 do order[#order + 1] = i end
  else
    for i = cur - 1, 1, -1 do order[#order + 1] = i end
    for i = tot, cur + 1, -1 do order[#order + 1] = i end
  end

  for _, i in ipairs(order) do
    local tr = song.tracks[i]
    if is_sequencer_track(tr) and (is_track_collapsed(i) == want_collapsed) then
      song.selected_track_index = i
      pattern_collapsed_state[song.selected_pattern_index] = false
      if want_collapsed then
        tr.collapsed = false
        last_jumped_track = i
        last_jumped_track_was_null = is_track_null(i)
      end
      if solo then
        tr.mute_state = renoise.Track.MUTE_STATE_ACTIVE
        renoise.app():show_status(string.format("Jumped to track %d and soloed it", i))
      end
      return true
    end
  end

  if solo then
    -- nothing found: unmute everything again
    for i = 1, tot do
      local tr = song.tracks[i]
      if is_sequencer_track(tr) then tr.mute_state = renoise.Track.MUTE_STATE_ACTIVE end
    end
    renoise.app():show_status("No matching track found.")
  end
  return false
end

function M.jump_to_next_track()          jump_directional( 1, false, false) end
function M.jump_to_previous_track()       jump_directional(-1, false, false) end
function M.move_to_next_track_skip_collapsed() jump_directional(1, false, false) end
function M.jump_to_next_collapsed_track()  if not jump_directional( 1, true, false) then renoise.app():show_status("No other collapsed tracks found.") end end
function M.jump_to_previous_collapsed_track() if not jump_directional(-1, true, false) then renoise.app():show_status("No other collapsed tracks found.") end end
function M.jump_to_next_track_with_solo()     jump_directional( 1, false, true) end
function M.jump_to_previous_track_with_solo() jump_directional(-1, false, true) end

----------------------------------------------------------------------
-- focus-loss auto-collapse (observer on selected_track_index)
----------------------------------------------------------------------
local function handle_track_focus_change()
  if not auto_collapse_on_focus_loss or not last_jumped_track then return end
  local song = renoise.song()
  local current = song.selected_track_index
  if current ~= last_jumped_track then
    local track = song.tracks[last_jumped_track]
    if track and is_sequencer_track(track)
       and last_jumped_track_was_null and is_track_null(last_jumped_track) then
      track.collapsed = true
    end
    last_jumped_track, last_jumped_track_was_null = nil, nil
  end
end

----------------------------------------------------------------------
-- toggles
----------------------------------------------------------------------
function M.toggle_auto_collapse_before_jump()
  auto_collapse_before_jump = not auto_collapse_before_jump
  renoise.app():show_status("Auto-collapse before jump: " ..
    (auto_collapse_before_jump and "enabled" or "disabled"))
end

function M.toggle_auto_collapse_on_focus_loss()
  auto_collapse_on_focus_loss = not auto_collapse_on_focus_loss
  renoise.app():show_status("Auto-collapse on focus loss: " ..
    (auto_collapse_on_focus_loss and "enabled" or "disabled"))
end

----------------------------------------------------------------------
-- observer lifecycle — attach per document, detach on release
----------------------------------------------------------------------
local function attach_focus_observer()
  local song = renoise.song()
  if song and not song.selected_track_index_observable:has_notifier(handle_track_focus_change) then
    song.selected_track_index_observable:add_notifier(handle_track_focus_change)
  end
end

local function detach_focus_observer()
  -- Called on document release; the song object is going away, but removing our
  -- notifier defensively keeps us from ever pointing at a dead song.
  local ok, song = pcall(function() return renoise.song() end)
  if ok and song then
    if song.selected_track_index_observable:has_notifier(handle_track_focus_change) then
      song.selected_track_index_observable:remove_notifier(handle_track_focus_change)
    end
  end
  -- reset per-song state
  last_jumped_track, last_jumped_track_was_null = nil, nil
  pattern_collapsed_state = {}
  last_collapsed_pattern_idx = nil
end

local tool = renoise.tool()
if not tool.app_new_document_observable:has_notifier(attach_focus_observer) then
  tool.app_new_document_observable:add_notifier(attach_focus_observer)
end
if not tool.app_release_document_observable:has_notifier(detach_focus_observer) then
  tool.app_release_document_observable:add_notifier(detach_focus_observer)
end
-- attach for the already-open document at load time (guarded — no song at boot)
pcall(attach_focus_observer)

----------------------------------------------------------------------
-- registrations
----------------------------------------------------------------------
local KB = "Pattern Editor:Paketti:"
renoise.tool():add_keybinding{name=KB.."Jump To Next Track (Skip Collapsed)",     invoke=M.jump_to_next_track}
renoise.tool():add_keybinding{name=KB.."Jump To Previous Track (Skip Collapsed)", invoke=M.jump_to_previous_track}
renoise.tool():add_keybinding{name=KB.."Jump To Next Collapsed Track",            invoke=M.jump_to_next_collapsed_track}
renoise.tool():add_keybinding{name=KB.."Jump To Previous Collapsed Track",        invoke=M.jump_to_previous_collapsed_track}
renoise.tool():add_keybinding{name=KB.."Jump To Next Track (With Solo)",          invoke=M.jump_to_next_track_with_solo}
renoise.tool():add_keybinding{name=KB.."Jump To Previous Track (With Solo)",      invoke=M.jump_to_previous_track_with_solo}
renoise.tool():add_keybinding{name=KB.."Collapse Unused Tracks in Pattern",       invoke=M.collapse_unused_tracks_in_pattern}
renoise.tool():add_keybinding{name=KB.."Toggle Auto-Collapse Before Jump",        invoke=M.toggle_auto_collapse_before_jump}
renoise.tool():add_keybinding{name=KB.."Toggle Auto-Collapse On Focus Loss",      invoke=M.toggle_auto_collapse_on_focus_loss}

local MENU = "Main Menu:Tools:Paketti:Pattern Editor:Track Navigation:"
PakettiAddMenuEntry{name=MENU.."Jump To Next Track (Skip Collapsed)",     invoke=M.jump_to_next_track}
PakettiAddMenuEntry{name=MENU.."Jump To Previous Track (Skip Collapsed)", invoke=M.jump_to_previous_track}
PakettiAddMenuEntry{name=MENU.."Jump To Next Collapsed Track",            invoke=M.jump_to_next_collapsed_track}
PakettiAddMenuEntry{name=MENU.."Jump To Previous Collapsed Track",        invoke=M.jump_to_previous_collapsed_track}
PakettiAddMenuEntry{name=MENU.."Jump To Next Track (With Solo)",          invoke=M.jump_to_next_track_with_solo}
PakettiAddMenuEntry{name=MENU.."Jump To Previous Track (With Solo)",      invoke=M.jump_to_previous_track_with_solo}
PakettiAddMenuEntry{name=MENU.."Collapse Unused Tracks in Pattern",       invoke=M.collapse_unused_tracks_in_pattern}
PakettiAddMenuEntry{name=MENU.."Toggle Auto-Collapse Before Jump",        invoke=M.toggle_auto_collapse_before_jump}
PakettiAddMenuEntry{name=MENU.."Toggle Auto-Collapse On Focus Loss",      invoke=M.toggle_auto_collapse_on_focus_loss}

renoise.tool():add_midi_mapping{name="Paketti:Jump To Next Track (Skip Collapsed)",     invoke=function(m) if m:is_trigger() then M.jump_to_next_track() end end}
renoise.tool():add_midi_mapping{name="Paketti:Jump To Previous Track (Skip Collapsed)", invoke=function(m) if m:is_trigger() then M.jump_to_previous_track() end end}
renoise.tool():add_midi_mapping{name="Paketti:Jump To Next Collapsed Track",            invoke=function(m) if m:is_trigger() then M.jump_to_next_collapsed_track() end end}
renoise.tool():add_midi_mapping{name="Paketti:Jump To Previous Collapsed Track",        invoke=function(m) if m:is_trigger() then M.jump_to_previous_collapsed_track() end end}

return M
