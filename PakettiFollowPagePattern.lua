local preferences = renoise.tool().preferences

local follow_page_enabled = false
local internal_update = false
local desired_line = nil
local follow_last_row = false
local last_sequence_index = nil
local sequence_change_pending = false
local sequence_change_expected_line = nil
local last_seen_line_index = nil
local last_seen_sequence_index = nil
local attached_song = nil
local use_idle_notifier = false

local function get_playback_pos_observable(transport)
  local ok, obs = pcall(function() return transport.playback_pos_observable end)
  if ok then
    return obs
  end
  return nil
end

local function clamp_line(line, max_lines)
  if line < 1 then
    return 1
  end
  if line > max_lines then
    return max_lines
  end
  return line
end

local function current_pattern_length(song)
  local pattern = song.selected_pattern
  if pattern then
    return pattern.number_of_lines
  end
  return 1
end

local function init_desired_line(song)
  local line = song.selected_line_index or 1
  desired_line = line
  follow_last_row = (line == current_pattern_length(song))
end

local function follow_to_sequence(song, sequence_index)
  local pattern_index = song.sequencer.pattern_sequence[sequence_index]
  local pattern_length = nil
  if pattern_index and song.patterns[pattern_index] then
    pattern_length = song.patterns[pattern_index].number_of_lines
  else
    pattern_length = current_pattern_length(song)
  end

  local target_line
  if follow_last_row then
    target_line = pattern_length
  else
    if desired_line == nil then
      desired_line = song.selected_line_index or 1
    end
    target_line = clamp_line(desired_line, pattern_length)
  end

  internal_update = true
  if song.selected_sequence_index ~= sequence_index then
    song.selected_sequence_index = sequence_index
  end
  if song.selected_line_index ~= target_line then
    if desired_line ~= nil and target_line ~= desired_line then
      sequence_change_pending = true
      sequence_change_expected_line = target_line
    end
    song.selected_line_index = target_line
  end
  internal_update = false
end

local function on_playback_pos_changed()
  if not follow_page_enabled then
    return
  end
  local song = renoise.song()
  if not song then
    return
  end
  if not song.transport.playing then
    return
  end
  local pos = song.transport.playback_pos
  if not pos then
    return
  end
  local sequence_index = pos.sequence
  if not sequence_index or sequence_index < 1 then
    return
  end
  if last_sequence_index == sequence_index then
    return
  end

  last_sequence_index = sequence_index
  if desired_line == nil then
    init_desired_line(song)
  end
  follow_to_sequence(song, sequence_index)
end

local function follow_page_idle_notifier()
  local song = renoise.song()
  if not song then
    return
  end

  on_playback_pos_changed()

  if internal_update then
    return
  end

  local current_sequence = song.selected_sequence_index
  if last_seen_sequence_index ~= current_sequence then
    if desired_line == nil then
      init_desired_line(song)
    else
      local pattern_length = current_pattern_length(song)
      if not follow_last_row and desired_line > pattern_length then
        sequence_change_pending = true
        sequence_change_expected_line = pattern_length
      end
    end
    last_seen_sequence_index = current_sequence
  end

  local current_line = song.selected_line_index
  if last_seen_line_index ~= current_line then
    last_seen_line_index = current_line
    if song.transport.playing and song.transport.follow_player then
      return
    end
    if sequence_change_pending and sequence_change_expected_line == current_line then
      sequence_change_pending = false
      sequence_change_expected_line = nil
      return
    end
    sequence_change_pending = false
    sequence_change_expected_line = nil
    desired_line = current_line
    follow_last_row = (desired_line == current_pattern_length(song))
  end
end

local function attach_song(song)
  if not song then
    return
  end
  attached_song = song
  last_sequence_index = nil
  sequence_change_pending = false
  sequence_change_expected_line = nil
  last_seen_line_index = song.selected_line_index
  last_seen_sequence_index = song.selected_sequence_index
  init_desired_line(song)
  local playback_obs = get_playback_pos_observable(song.transport)
  if playback_obs then
    use_idle_notifier = false
    if not playback_obs:has_notifier(on_playback_pos_changed) then
      playback_obs:add_notifier(on_playback_pos_changed)
    end
  else
    use_idle_notifier = true
    if not renoise.tool().app_idle_observable:has_notifier(follow_page_idle_notifier) then
      renoise.tool().app_idle_observable:add_notifier(follow_page_idle_notifier)
    end
  end
end

local function detach_song(song)
  if not song then
    return
  end
  local playback_obs = get_playback_pos_observable(song.transport)
  if playback_obs and playback_obs:has_notifier(on_playback_pos_changed) then
    playback_obs:remove_notifier(on_playback_pos_changed)
  end
  if use_idle_notifier and renoise.tool().app_idle_observable:has_notifier(follow_page_idle_notifier) then
    renoise.tool().app_idle_observable:remove_notifier(follow_page_idle_notifier)
  end
  attached_song = nil
  last_sequence_index = nil
  last_seen_line_index = nil
  last_seen_sequence_index = nil
end

function PakettiFollowPagePatternSetEnabled(enabled)
  follow_page_enabled = enabled and true or false
  local song = renoise.song()
  if not song then
    return
  end
  if follow_page_enabled then
    attach_song(song)
  else
    detach_song(song)
  end
end

function PakettiFollowPagePatternOnNewDocument()
  local song = renoise.song()
  if not song then
    return
  end
  if attached_song and attached_song ~= song then
    detach_song(attached_song)
  end
  follow_page_enabled = preferences.pakettiFollowPagePattern.value
  if follow_page_enabled then
    attach_song(song)
  else
    detach_song(song)
  end
end

function PakettiToggleFollowPagePattern()
  local enabled = not preferences.pakettiFollowPagePattern.value
  preferences.pakettiFollowPagePattern.value = enabled
  preferences:save_as("preferences.xml")
  PakettiFollowPagePatternSetEnabled(enabled)
  renoise.app():show_status("Follow Page Pattern: " .. (enabled and "ON" or "OFF"))
end
