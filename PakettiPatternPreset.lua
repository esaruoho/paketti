-- PakettiPatternPreset.lua
-- Pick/Put a complete Pattern Matrix slot (one track-in-pattern cell)
-- across 32 banks stored persistently in preferences.
--
-- Dialog layout mirrors the QWERTY keyboard:
--   Row 1 (slots 01-10): 1 2 3 4 5 6 7 8 9 0
--   Row 2 (slots 11-20): q w e r t y u i o p
--   Row 3 (slots 21-30): a s d f g h j k l ;
--   Row 4 (slots 31-32): z x
-- While the dialog is focused: <key> = Put, Shift+<key> = Pick.

local NUM_SLOTS = 32
local vb = renoise.ViewBuilder()
local dialog = nil

local SLOT_KEYS = {
  "1","2","3","4","5","6","7","8","9","0",
  "q","w","e","r","t","y","u","i","o","p",
  "a","s","d","f","g","h","j","k","l",";",
  "z","x"
}

local function key_for_slot(i)
  return SLOT_KEYS[i] or "?"
end

-- Map shifted-character variants back to their base key, so that platforms
-- which deliver the shifted glyph (e.g. "!" for shift+1, ":" for shift+;)
-- still resolve to the correct slot.
local SHIFTED_TO_BASE = {
  ["!"] = "1", ["@"] = "2", ["#"] = "3", ["$"] = "4", ["%"] = "5",
  ["^"] = "6", ["&"] = "7", ["*"] = "8", ["("] = "9", [")"] = "0",
  [":"] = ";",
}

local function slot_for_key(name)
  if name == nil or name == "" then return nil end
  local lowered = name:lower()
  if SHIFTED_TO_BASE[lowered] then lowered = SHIFTED_TO_BASE[lowered] end
  for i, k in ipairs(SLOT_KEYS) do
    if k == lowered then return i end
  end
  return nil
end

local function slot_key(i) return string.format("Slot%02d", i) end
local function slot_name_key(i) return string.format("Slot%02d", i) .. "Name" end

local function get_slot_data(i)
  return preferences.PakettiPatternPreset[slot_key(i)].value or ""
end

local function set_slot_data(i, data, name)
  preferences.PakettiPatternPreset[slot_key(i)].value = data or ""
  if name ~= nil then
    preferences.PakettiPatternPreset[slot_name_key(i)].value = name
  end
  preferences:save_as("preferences.xml")
end

local function is_slot_empty(i)
  local d = get_slot_data(i)
  return d == nil or d == ""
end

local function get_put_at_cursor()
  return preferences.PakettiPatternPreset.PutAtCursor.value or false
end

local function get_use_edit_step()
  return preferences.PakettiPatternPreset.UseEditStep.value or false
end

-- Serialize the currently selected matrix slot (track-in-pattern cell)
-- Format: H#lines#ncols#ecols#ttype~L#n#NC#EC~L#n#NC#EC...
--   NC = note columns separated by ':', each col = "note,inst,vol,pan,delay,fxN,fxA"
--   EC = effect columns separated by ':', each col = "num,amt"
--   Only non-empty lines are stored.
local function serialize_selected_slot()
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.tracks[track_index]
  local pattern_track = pattern.tracks[track_index]

  local ncols = track.visible_note_columns or 0
  local ecols = track.visible_effect_columns or 0
  local lines_count = pattern.number_of_lines
  local ttype = track.type

  local out = {}
  out[#out+1] = string.format("H#%d#%d#%d#%d", lines_count, ncols, ecols, ttype)

  for line_idx = 1, lines_count do
    local line = pattern_track:line(line_idx)
    if not line.is_empty then
      local nc_part = ""
      if ttype == renoise.Track.TRACK_TYPE_SEQUENCER and ncols > 0 then
        local nc_strs = {}
        for c = 1, ncols do
          local nc = line.note_columns[c]
          nc_strs[#nc_strs+1] = string.format("%d,%d,%d,%d,%d,%d,%d",
            nc.note_value, nc.instrument_value, nc.volume_value,
            nc.panning_value, nc.delay_value,
            nc.effect_number_value, nc.effect_amount_value)
        end
        nc_part = table.concat(nc_strs, ":")
      end

      local ec_part = ""
      if ecols > 0 then
        local ec_strs = {}
        for c = 1, ecols do
          local ec = line.effect_columns[c]
          ec_strs[#ec_strs+1] = string.format("%d,%d", ec.number_value, ec.amount_value)
        end
        ec_part = table.concat(ec_strs, ":")
      end

      out[#out+1] = string.format("L#%d#%s#%s", line_idx, nc_part, ec_part)
    end
  end

  return table.concat(out, "~")
end

-- Apply serialized slot data to the currently selected matrix slot.
-- When PutAtCursor preference is true, places the preset starting at
-- the current selected_line_index instead of overwriting the whole pattern.
local function apply_to_selected_slot(data)
  if data == nil or data == "" then return false, "Empty preset" end

  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.tracks[track_index]
  local pattern_track = pattern.tracks[track_index]

  local first_sep = data:find("~", 1, true)
  local header = first_sep and data:sub(1, first_sep - 1) or data
  local lines_s, ncols_s, ecols_s = header:match("^H#(%d+)#(%d+)#(%d+)#%d+$")
  if not lines_s then return false, "Invalid preset header" end
  local stored_lines = tonumber(lines_s) or 0
  local stored_ncols = tonumber(ncols_s) or 0
  local stored_ecols = tonumber(ecols_s) or 0

  if track.type == renoise.Track.TRACK_TYPE_SEQUENCER and stored_ncols > 0 then
    if stored_ncols > track.visible_note_columns then
      track.visible_note_columns = math.min(stored_ncols, 12)
    end
  end
  if stored_ecols > 0 and stored_ecols > track.visible_effect_columns then
    track.visible_effect_columns = math.min(stored_ecols, 8)
  end

  local put_at_cursor = get_put_at_cursor()
  local line_offset = 0
  local clear_start, clear_end
  if put_at_cursor then
    line_offset = song.selected_line_index - 1
    clear_start = math.max(1, line_offset + 1)
    clear_end = math.min(pattern.number_of_lines, line_offset + stored_lines)
  else
    clear_start = 1
    clear_end = pattern.number_of_lines
  end

  for line_idx = clear_start, clear_end do
    pattern_track:line(line_idx):clear()
  end

  if not first_sep then return true end

  local rest = data:sub(first_sep + 1)
  for chunk in (rest .. "~"):gmatch("([^~]+)~") do
    if chunk:sub(1, 2) == "L#" then
      local body = chunk:sub(3)
      local hash1 = body:find("#", 1, true)
      if hash1 then
        local stored_line_idx = tonumber(body:sub(1, hash1 - 1))
        local rest2 = body:sub(hash1 + 1)
        local hash2 = rest2:find("#", 1, true)
        local nc_part, ec_part
        if hash2 then
          nc_part = rest2:sub(1, hash2 - 1)
          ec_part = rest2:sub(hash2 + 1)
        else
          nc_part = rest2
          ec_part = ""
        end

        if stored_line_idx then
          local target_line = stored_line_idx + line_offset
          if target_line >= 1 and target_line <= pattern.number_of_lines then
            local line = pattern_track:line(target_line)

            if nc_part ~= "" and track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
              local col = 1
              for nc_str in (nc_part .. ":"):gmatch("([^:]*):") do
                if nc_str ~= "" and col <= track.visible_note_columns then
                  local nv, iv, vv, pv, dv, env, eav = nc_str:match(
                    "^(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+)$")
                  if nv then
                    local nc = line.note_columns[col]
                    nc.note_value = tonumber(nv)
                    nc.instrument_value = tonumber(iv)
                    nc.volume_value = tonumber(vv)
                    nc.panning_value = tonumber(pv)
                    nc.delay_value = tonumber(dv)
                    nc.effect_number_value = tonumber(env)
                    nc.effect_amount_value = tonumber(eav)
                  end
                end
                col = col + 1
              end
            end

            if ec_part ~= "" then
              local col = 1
              for ec_str in (ec_part .. ":"):gmatch("([^:]*):") do
                if ec_str ~= "" and col <= track.visible_effect_columns then
                  local ev, av = ec_str:match("^(%d+),(%d+)$")
                  if ev then
                    local ec = line.effect_columns[col]
                    ec.number_value = tonumber(ev)
                    ec.amount_value = tonumber(av)
                  end
                end
                col = col + 1
              end
            end
          end
        end
      end
    end
  end

  return true
end

local NOTE_NAMES = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}

local function note_value_to_string(v)
  if v == nil then return "..." end
  if v == 121 then return "..." end
  if v == 120 then return "OFF" end
  if v >= 0 and v < 120 then
    local oct = math.floor(v / 12)
    local n = v % 12
    return NOTE_NAMES[n + 1] .. tostring(oct)
  end
  return "???"
end

local function slot_stats(i)
  local d = get_slot_data(i)
  if d == nil or d == "" then return "Empty" end
  local lines, ncols, ecols = d:match("^H#(%d+)#(%d+)#(%d+)#")
  local count = 0
  for _ in d:gmatch("L#") do count = count + 1 end
  return string.format("%sL %sN %sE %dF",
    lines or "?", ncols or "?", ecols or "?", count)
end

-- Build a content preview string of up to ~max_notes first-column notes
local function slot_preview(i, max_notes)
  max_notes = max_notes or 6
  local d = get_slot_data(i)
  if d == nil or d == "" then return "(empty)" end
  local notes = {}
  for chunk in d:gmatch("[^~]+") do
    if chunk:sub(1, 2) == "L#" then
      if #notes >= max_notes then break end
      local body = chunk:sub(3)
      local h1 = body:find("#", 1, true)
      if h1 then
        local rest_body = body:sub(h1 + 1)
        local h2 = rest_body:find("#", 1, true)
        local nc = h2 and rest_body:sub(1, h2 - 1) or rest_body
        local first_col = nc:match("^([^:]*)") or nc
        local nv = first_col:match("^(%-?%d+),")
        if nv then
          notes[#notes + 1] = note_value_to_string(tonumber(nv))
        else
          notes[#notes + 1] = "fx"
        end
      end
    end
  end
  if #notes == 0 then return "(empty)" end
  return table.concat(notes, " ")
end

local function slot_label(i)
  local k = key_for_slot(i):upper()
  return string.format("%s . %02d", k, i)
end

local function refresh_slot_display(i)
  if vb and vb.views then
    local stats_id = string.format("pp_slot_stats_%02d", i)
    local prev_id = string.format("pp_slot_preview_%02d", i)
    if vb.views[stats_id] then
      vb.views[stats_id].text = slot_stats(i)
    end
    if vb.views[prev_id] then
      vb.views[prev_id].text = slot_preview(i)
    end
  end
end

local function refresh_all_displays()
  for i = 1, NUM_SLOTS do refresh_slot_display(i) end
end

function PakettiPatternPresetPick(slot_index)
  if slot_index < 1 or slot_index > NUM_SLOTS then return end
  local song = renoise.song()
  local data = serialize_selected_slot()
  local nm = string.format("P%d/T%d", song.selected_pattern_index, song.selected_track_index)
  set_slot_data(slot_index, data, nm)
  refresh_slot_display(slot_index)
  renoise.app():show_status(string.format(
    "Pattern Preset: Picked into Slot %02d (Pattern %d, Track %d)",
    slot_index, song.selected_pattern_index, song.selected_track_index))
end

function PakettiPatternPresetPut(slot_index)
  if slot_index < 1 or slot_index > NUM_SLOTS then return end
  if is_slot_empty(slot_index) then
    renoise.app():show_status(string.format("Pattern Preset: Slot %02d is empty.", slot_index))
    return
  end
  local song = renoise.song()
  local put_at_cursor = get_put_at_cursor()
  local applied_at_line = song.selected_line_index
  local ok, err = apply_to_selected_slot(get_slot_data(slot_index))
  if not ok then
    renoise.app():show_status(string.format("Pattern Preset Put failed: %s", err or "?"))
    return
  end

  -- Advance the cursor by edit_step (only when both Put-at-cursor and Use Edit Step are on)
  local advanced_to = nil
  if put_at_cursor and get_use_edit_step() then
    local step = song.transport.edit_step or 0
    if step > 0 then
      local pattern_lines = song.selected_pattern.number_of_lines
      local new_line = applied_at_line + step
      if new_line > pattern_lines then new_line = pattern_lines end
      song.selected_line_index = new_line
      advanced_to = new_line
    end
  end

  local where
  if put_at_cursor then
    if advanced_to then
      where = string.format("at line %d (advanced to %d)", applied_at_line, advanced_to)
    else
      where = string.format("at line %d", applied_at_line)
    end
  else
    where = "(full pattern)"
  end
  renoise.app():show_status(string.format(
    "Pattern Preset: Put Slot %02d into Pattern %d, Track %d %s",
    slot_index, song.selected_pattern_index, song.selected_track_index, where))
end

function PakettiPatternPresetClear(slot_index)
  if slot_index < 1 or slot_index > NUM_SLOTS then return end
  set_slot_data(slot_index, "", "")
  refresh_slot_display(slot_index)
  renoise.app():show_status(string.format("Pattern Preset: Cleared Slot %02d", slot_index))
end

function PakettiPatternPresetClearAll()
  for i = 1, NUM_SLOTS do
    preferences.PakettiPatternPreset[slot_key(i)].value = ""
    preferences.PakettiPatternPreset[slot_name_key(i)].value = ""
  end
  preferences:save_as("preferences.xml")
  refresh_all_displays()
  renoise.app():show_status("Pattern Preset: Cleared All Slots")
end

local CARD_W = 130
local INNER_W = CARD_W - 8

-- Build a single slot mini-card with key label, Pick/Put/Clear, stats, preview
local function build_slot_card(i)
  return vb:column{
    spacing = 1,
    width = CARD_W,
    style = "group",
    margin = 3,
    vb:text{
      text = slot_label(i),
      style = "strong",
      align = "center",
      width = INNER_W,
    },
    vb:row{
      spacing = 1,
      vb:button{
        text = "Pick",
        width = math.floor(INNER_W / 2),
        pressed = function() PakettiPatternPresetPick(i) end,
      },
      vb:button{
        text = "Put",
        width = math.ceil(INNER_W / 2),
        pressed = function() PakettiPatternPresetPut(i) end,
      },
    },
    vb:button{
      text = "Clear",
      width = INNER_W,
      pressed = function() PakettiPatternPresetClear(i) end,
    },
    vb:text{
      id = string.format("pp_slot_stats_%02d", i),
      text = slot_stats(i),
      width = INNER_W,
      font = "mono",
      align = "center",
    },
    vb:text{
      id = string.format("pp_slot_preview_%02d", i),
      text = slot_preview(i),
      width = INNER_W,
      font = "mono",
    },
  }
end

local function build_keyboard_row(slot_indices)
  local r = vb:row{ spacing = 2 }
  for _, i in ipairs(slot_indices) do
    r:add_child(build_slot_card(i))
  end
  return r
end

local function pattern_preset_keyhandler(dialog_obj, key)
  if not key or not key.name then return key end
  print(string.format(
    "PakettiPatternPreset keyhandler: name='%s' modifiers='%s'",
    tostring(key.name), tostring(key.modifiers)))

  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    if dialog_obj and dialog_obj.visible then dialog_obj:close() end
    dialog = nil
    return nil
  end

  -- Treat any modifier string containing shift (and nothing else) as a Pick
  local mods = tostring(key.modifiers or "")
  local is_shift_only = (mods == "shift")
  local is_no_mod = (mods == "")

  if is_no_mod then
    local slot = slot_for_key(key.name)
    if slot then
      PakettiPatternPresetPut(slot)
      return nil
    end
  end

  if is_shift_only then
    local slot = slot_for_key(key.name)
    if slot then
      PakettiPatternPresetPick(slot)
      return nil
    end
  end

  return key
end

function PakettiPatternPresetDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  vb = renoise.ViewBuilder()

  local row1 = build_keyboard_row({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 })
  local row2 = build_keyboard_row({ 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 })
  local row3 = build_keyboard_row({ 21, 22, 23, 24, 25, 26, 27, 28, 29, 30 })
  local row4 = build_keyboard_row({ 31, 32 })

  local content = vb:column{
    margin = 8,
    spacing = 4,
    vb:text{
      text = "Pattern Preset — pick/put complete Pattern Matrix slots (32 banks).",
      style = "strong",
    },
    vb:text{
      text = "Keys: <key> = Put, Shift+<key> = Pick. Click cards directly for the same actions.",
    },
    vb:row{
      spacing = 8,
      vb:checkbox{
        value = get_put_at_cursor(),
        notifier = function(v)
          preferences.PakettiPatternPreset.PutAtCursor.value = v
          preferences:save_as("preferences.xml")
        end,
      },
      vb:text{
        text = "Put at cursor (place preset starting at the selected line; outside lines untouched)",
      },
    },
    vb:row{
      spacing = 8,
      vb:checkbox{
        value = get_use_edit_step(),
        notifier = function(v)
          preferences.PakettiPatternPreset.UseEditStep.value = v
          preferences:save_as("preferences.xml")
        end,
      },
      vb:text{
        text = "Use Edit Step (after Put-at-cursor, advance cursor by transport edit_step — same as OctaMED Pick/Put Row)",
      },
    },
    row1,
    row2,
    row3,
    row4,
    vb:row{
      spacing = 4,
      vb:button{
        text = "Refresh Displays",
        width = 120,
        pressed = function() refresh_all_displays() end,
      },
      vb:button{
        text = "Clear All Slots",
        width = 120,
        pressed = function() PakettiPatternPresetClearAll() end,
      },
      vb:button{
        text = "Close",
        width = 80,
        pressed = function() if dialog and dialog.visible then dialog:close() end end,
      },
    },
  }

  dialog = renoise.app():show_custom_dialog(
    "Paketti Pattern Preset",
    content,
    pattern_preset_keyhandler)
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Menu / Keybindings / MIDI registration ------------------------------------

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Pattern Editor:Pattern Preset Dialog...",
  invoke = PakettiPatternPresetDialog,
}
PakettiAddMenuEntry{
  name = "Main Menu:Options:Paketti Pattern Preset Menu",
  invoke = PakettiPatternPresetDialog,
}
PakettiAddMenuEntry{
  name = "Pattern Editor:Paketti:Pattern Preset Dialog...",
  invoke = PakettiPatternPresetDialog,
}
PakettiAddMenuEntry{
  name = "Pattern Matrix:Paketti:Pattern Preset:Open Dialog",
  invoke = PakettiPatternPresetDialog,
}

for i = 1, NUM_SLOTS do
  local label = string.format("%02d", i)
  PakettiAddMenuEntry{
    name = "Pattern Matrix:Paketti:Pattern Preset:Pick:" .. label,
    invoke = function() PakettiPatternPresetPick(i) end,
  }
end
for i = 1, NUM_SLOTS do
  local label = string.format("%02d", i)
  PakettiAddMenuEntry{
    name = "Pattern Matrix:Paketti:Pattern Preset:Put:" .. label,
    invoke = function() PakettiPatternPresetPut(i) end,
  }
end
for i = 1, NUM_SLOTS do
  local label = string.format("%02d", i)
  PakettiAddMenuEntry{
    name = "Pattern Matrix:Paketti:Pattern Preset:Clear:" .. label,
    invoke = function() PakettiPatternPresetClear(i) end,
  }
end

renoise.tool():add_keybinding{
  name = "Global:Paketti:Pattern Preset Dialog",
  invoke = PakettiPatternPresetDialog,
}
renoise.tool():add_keybinding{
  name = "Pattern Matrix:Paketti:Pattern Preset Dialog",
  invoke = PakettiPatternPresetDialog,
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Pattern Preset Dialog",
  invoke = PakettiPatternPresetDialog,
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Pattern Preset Dialog",
  invoke = function(message)
    if message:is_trigger() then PakettiPatternPresetDialog() end
  end,
}

for i = 1, NUM_SLOTS do
  local label = string.format("%02d", i)
  renoise.tool():add_keybinding{
    name = "Global:Paketti:Pattern Preset Pick Slot " .. label,
    invoke = function() PakettiPatternPresetPick(i) end,
  }
  renoise.tool():add_keybinding{
    name = "Pattern Matrix:Paketti:Pattern Preset Pick Slot " .. label,
    invoke = function() PakettiPatternPresetPick(i) end,
  }
  renoise.tool():add_keybinding{
    name = "Pattern Editor:Paketti:Pattern Preset Pick Slot " .. label,
    invoke = function() PakettiPatternPresetPick(i) end,
  }
  renoise.tool():add_keybinding{
    name = "Global:Paketti:Pattern Preset Put Slot " .. label,
    invoke = function() PakettiPatternPresetPut(i) end,
  }
  renoise.tool():add_keybinding{
    name = "Pattern Matrix:Paketti:Pattern Preset Put Slot " .. label,
    invoke = function() PakettiPatternPresetPut(i) end,
  }
  renoise.tool():add_keybinding{
    name = "Pattern Editor:Paketti:Pattern Preset Put Slot " .. label,
    invoke = function() PakettiPatternPresetPut(i) end,
  }
  renoise.tool():add_midi_mapping{
    name = "Paketti:Pattern Preset Pick Slot " .. label,
    invoke = function(message)
      if message:is_trigger() then PakettiPatternPresetPick(i) end
    end,
  }
  renoise.tool():add_midi_mapping{
    name = "Paketti:Pattern Preset Put Slot " .. label,
    invoke = function(message)
      if message:is_trigger() then PakettiPatternPresetPut(i) end
    end,
  }
end
