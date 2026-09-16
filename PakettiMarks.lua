-- PakettiMarks.lua
-- Named GUI-location bookmarks, ported from aklt's "Marks" (dk.bladre.Marks).
--
-- A mark is a snapshot of WHERE you are in Renoise — which frames are showing,
-- the selected instrument/sample/track/device, the pattern position and cursor,
-- the pattern selection, and every track's collapse state — stored under a single
-- key (a-z, 0-9). Jump to a mark and Renoise snaps back to that whole layout.
--
-- Three accuracy levels control how much a jump restores:
--   view    — only the window frames / visibility
--   pattern — the above plus instrument/sample/track/device/sequence
--   cursor  — the above plus line/columns/selection/collapse (the default)
--
-- Persistence: marks live per-song, serialised into song.comments inside a fenced
-- block, auto-saved whenever a mark is set and auto-loaded when a song opens. (The
-- original stored them in a hidden instrument; comments are a more reliable
-- channel and don't clutter the instrument list.)

local COMMENT_START = "== PakettiMarks v1 (auto-managed, do not edit below) =="
local COMMENT_END   = "== /PakettiMarks =="
local ACCURACY_LABELS = {"view", "pattern", "cursor"}

local marks    = {}   -- key(char) -> array of numbers
local accuracy = 3    -- 1=view, 2=pattern, 3=cursor
local marks_dialog = nil
local loading_from_song = false

----------------------------------------------------------------------
-- capture / restore
----------------------------------------------------------------------
local function b2n(v) return v and 1 or 0 end

local function capture_mark()
  local win  = renoise.app().window
  local song = renoise.song()
  local t = song.selected_track_index
  local data = {
    win.active_lower_frame,                    -- 1
    win.active_middle_frame,                   -- 2
    win.active_upper_frame,                    -- 3
    b2n(win.lower_frame_is_visible),           -- 4
    b2n(win.upper_frame_is_visible),           -- 5
    b2n(win.pattern_matrix_is_visible),        -- 6
    song.selected_instrument_index,            -- 7
    song.selected_sample_index,                -- 8
    t,                                         -- 9
    song.selected_device_index,                -- 10
    song.selected_sequence_index,              -- 11
    song.selected_pattern_index,               -- 12
    song.selected_line_index,                  -- 13
    song.selected_note_column_index or 0,      -- 14
    song.selected_effect_column_index or 0,    -- 15
  }
  local sa = song.selection_in_pattern
  data[16] = sa and sa.start_line   or 0
  data[17] = sa and sa.end_line     or 0
  data[18] = sa and sa.start_track  or 0
  data[19] = sa and sa.end_track    or 0
  data[20] = sa and sa.start_column or 0
  data[21] = sa and sa.end_column   or 0
  -- collapse states appended from index 22 onward, one per track
  for i = 1, #song.tracks do
    data[21 + i] = b2n(song.tracks[i].collapsed)
  end
  return data
end

local function try(fn) pcall(fn) end

local function restore_mark(data)
  local win  = renoise.app().window
  local song = renoise.song()

  -- view level: frames + visibility
  try(function() if data[1] ~= 0 then win.active_lower_frame = data[1] end end)
  try(function() win.active_middle_frame = data[2] end)
  try(function() if data[3] ~= 0 then win.active_upper_frame = data[3] end end)
  try(function() win.lower_frame_is_visible    = data[4] == 1 end)
  try(function() win.upper_frame_is_visible    = data[5] == 1 end)
  try(function() win.pattern_matrix_is_visible = data[6] == 1 end)
  if accuracy < 2 then return end

  -- pattern level: instrument/sample/track/device/sequence
  if data[7] <= #song.instruments then
    try(function() song.selected_instrument_index = data[7] end)
    if data[8] <= #song.instruments[data[7]].samples then
      try(function() song.selected_sample_index = data[8] end)
    end
  end
  if data[9] <= #song.tracks then
    try(function() song.selected_track_index = data[9] end)
    if data[10] <= #song.tracks[data[9]].devices then
      try(function() song.selected_device_index = data[10] end)
    end
  end
  if data[11] <= #song.sequencer.pattern_sequence then
    try(function() song.selected_sequence_index = data[11] end)
  end
  if accuracy < 3 then return end

  -- cursor level: line / columns / selection / collapse
  local patt_idx = song.selected_pattern_index
  local max_line = song:pattern(patt_idx).number_of_lines
  try(function() song.selected_line_index = math.min(math.max(1, data[13]), max_line) end)
  if data[14] > 0 then try(function() song.selected_note_column_index   = data[14] end) end
  if data[15] > 0 then try(function() song.selected_effect_column_index = data[15] end) end
  if data[16] > 0 then
    try(function()
      song.selection_in_pattern = {
        start_line = data[16], end_line = data[17],
        start_track = data[18], end_track = data[19],
        start_column = data[20], end_column = data[21],
      }
    end)
  end
  for i = 1, #song.tracks do
    local c = data[21 + i]
    if c ~= nil then
      local track = song.tracks[i]
      try(function()
        if track.type == renoise.Track.TRACK_TYPE_GROUP then
          track.group_collapsed = (c == 1)
        else
          track.collapsed = (c == 1)
        end
      end)
    end
  end
end

----------------------------------------------------------------------
-- persistence in song.comments
----------------------------------------------------------------------
local function serialize()
  local out = {}
  for key, data in pairs(marks) do
    out[#out + 1] = key .. "=" .. table.concat(data, ",")
  end
  table.sort(out)
  return out
end

local function save_marks_to_song()
  if loading_from_song then return end
  local song = renoise.song()
  local existing = song.comments
  local kept = {}
  local skipping = false
  for _, line in ipairs(existing) do
    if line == COMMENT_START then skipping = true
    elseif line == COMMENT_END then skipping = false
    elseif not skipping then kept[#kept + 1] = line end
  end
  local block = serialize()
  if #block > 0 then
    kept[#kept + 1] = COMMENT_START
    for _, l in ipairs(block) do kept[#kept + 1] = l end
    kept[#kept + 1] = COMMENT_END
  end
  song.comments = kept
end

local function load_marks_from_song()
  loading_from_song = true
  marks = {}
  local ok, song = pcall(function() return renoise.song() end)
  if ok and song then
    local skipping = false
    for _, line in ipairs(song.comments) do
      if line == COMMENT_START then skipping = true
      elseif line == COMMENT_END then skipping = false
      elseif skipping then
        local key, vals = line:match("^(.)=(.+)$")
        if key and vals then
          local data = {}
          for num in vals:gmatch("[^,]+") do data[#data + 1] = tonumber(num) or 0 end
          marks[key] = data
        end
      end
    end
  end
  loading_from_song = false
end

----------------------------------------------------------------------
-- operations
----------------------------------------------------------------------
local function normalize_key(k)
  if type(k) ~= "string" or #k == 0 then return nil end
  k = k:sub(1, 1):lower()
  if k:match("[a-z0-9]") then return k end
  return nil
end

local function set_mark(key)
  key = normalize_key(key)
  if not key then renoise.app():show_status("Mark key must be a-z or 0-9.") return end
  marks[key] = capture_mark()
  save_marks_to_song()
  renoise.app():show_status("Saved mark '" .. key:upper() .. "'.")
  if marks_dialog and marks_dialog.visible then PakettiMarksRefreshList() end
end

local function jump_mark(key)
  key = normalize_key(key)
  if not key then return end
  local data = marks[key]
  if not data then renoise.app():show_status("No mark '" .. key:upper() .. "' set.") return end
  restore_mark(data)
  renoise.app():show_status("Jumped to mark '" .. key:upper() .. "'.")
end

local function clear_mark(key)
  key = normalize_key(key)
  if not key then return end
  if marks[key] then
    marks[key] = nil
    save_marks_to_song()
    renoise.app():show_status("Cleared mark '" .. key:upper() .. "'.")
    if marks_dialog and marks_dialog.visible then PakettiMarksRefreshList() end
  end
end

local function cycle_accuracy()
  accuracy = (accuracy % 3) + 1
  renoise.app():show_status("Marks jump accuracy: " .. ACCURACY_LABELS[accuracy])
end

----------------------------------------------------------------------
-- dialog
----------------------------------------------------------------------
local dvb  -- dialog ViewBuilder (fresh per open)

function PakettiMarksRefreshList()
  if not (dvb and dvb.views["marks_list"]) then return end
  local keys = {}
  for k in pairs(marks) do keys[#keys + 1] = k end
  table.sort(keys)
  if #keys == 0 then
    dvb.views["marks_list"].text = "(no marks set — press Shift+<key> to save one)"
  else
    local rows = {}
    for _, k in ipairs(keys) do
      local d = marks[k]
      rows[#rows + 1] = string.format(
        "%s   instr %02X · track %d · seq %d · line %d",
        k:upper(), (d[7] or 1) - 1, d[9] or 1, d[11] or 1, d[13] or 1)
    end
    dvb.views["marks_list"].text = table.concat(rows, "\n")
  end
end

local function marks_keyhandler(dialog, key)
  -- plain a-z/0-9 = jump; Shift = save; Alt/Ctrl = clear
  local nk = normalize_key(key.name)
  if nk then
    if key.modifiers == "shift" then set_mark(nk)
    elseif key.modifiers == "alt" or key.modifiers == "control" then clear_mark(nk)
    else jump_mark(nk) end
    return nil
  end
  return key
end

function PakettiMarksShowDialog()
  if marks_dialog and marks_dialog.visible then
    marks_dialog:close()
    marks_dialog = nil
    return
  end
  dvb = renoise.ViewBuilder()
  local key_field = "marks_key_" .. tostring(math.random(2, 30000))

  local content = dvb:column{
    margin = 10, spacing = 8,
    dvb:text{text = "Marks — named GUI-location bookmarks", font = "bold"},
    dvb:text{text = "In this dialog: press a key (a-z, 0-9) to JUMP,\nShift+key to SAVE, Alt+key to CLEAR.", },
    dvb:row{
      dvb:text{text = "Key:", width = 40},
      dvb:textfield{id = key_field, width = 60, text = "a"},
      dvb:button{text = "Save",  width = 60, notifier = function() set_mark(dvb.views[key_field].text) end},
      dvb:button{text = "Jump",  width = 60, notifier = function() jump_mark(dvb.views[key_field].text) end},
      dvb:button{text = "Clear", width = 60, notifier = function() clear_mark(dvb.views[key_field].text) end},
    },
    dvb:row{
      dvb:text{text = "Jump accuracy:", width = 100},
      dvb:button{text = "view / pattern / cursor", width = 200, notifier = cycle_accuracy},
    },
    dvb:text{text = "Saved marks:"},
    dvb:multiline_textfield{id = "marks_list", width = 380, height = 180, font = "mono", active = false, text = ""},
  }

  marks_dialog = renoise.app():show_custom_dialog("Paketti Marks", content, marks_keyhandler)
  PakettiMarksRefreshList()
end

----------------------------------------------------------------------
-- song lifecycle: reload marks when a song opens
----------------------------------------------------------------------
local tool = renoise.tool()
if not tool.app_new_document_observable:has_notifier(load_marks_from_song) then
  tool.app_new_document_observable:add_notifier(load_marks_from_song)
end
pcall(load_marks_from_song)  -- load for the already-open document

----------------------------------------------------------------------
-- registrations
----------------------------------------------------------------------
renoise.tool():add_keybinding{name="Global:Paketti:Marks Dialog...",       invoke=PakettiMarksShowDialog}
renoise.tool():add_keybinding{name="Global:Paketti:Marks Cycle Accuracy",  invoke=cycle_accuracy}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Pattern Editor:Marks...",       invoke=PakettiMarksShowDialog}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Marks...",                        invoke=PakettiMarksShowDialog}
renoise.tool():add_midi_mapping{name="Paketti:Marks Dialog", invoke=function(m) if m:is_trigger() then PakettiMarksShowDialog() end end}
