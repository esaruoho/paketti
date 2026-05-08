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

local function get_advance_to_end()
  return preferences.PakettiPatternPreset.AdvanceToEnd.value or false
end

-- Read the stored pattern length (header field "lines") from a serialized slot.
local function slot_stored_lines(data)
  if data == nil or data == "" then return 0 end
  local lines_s = data:match("^H#(%d+)#")
  return tonumber(lines_s) or 0
end

-- Serialize a single pattern line into the "L#<idx>#<NC>#<EC>" chunk format.
local function serialize_line(line, ncols, ecols, ttype, stored_idx)
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
  return string.format("L#%d#%s#%s", stored_idx, nc_part, ec_part)
end

-- Serialize the currently selected matrix slot (track-in-pattern cell)
-- Format: H#lines#ncols#ecols#ttype~L#n#NC#EC~L#n#NC#EC...
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
      out[#out+1] = serialize_line(line, ncols, ecols, ttype, line_idx)
    end
  end
  return table.concat(out, "~")
end

-- Serialize a sub-range of the currently selected matrix slot, with line
-- indices remapped to start at 1 (so the resulting preset behaves as a
-- standalone N-line pattern).
local function serialize_selected_slot_range(source_start, source_end)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.tracks[track_index]
  local pattern_track = pattern.tracks[track_index]

  local ncols = track.visible_note_columns or 0
  local ecols = track.visible_effect_columns or 0
  local total_lines = pattern.number_of_lines
  local ttype = track.type

  if source_start < 1 then source_start = 1 end
  if source_end > total_lines then source_end = total_lines end
  local span = source_end - source_start + 1
  if span < 1 then return "" end

  local out = {}
  out[#out+1] = string.format("H#%d#%d#%d#%d", span, ncols, ecols, ttype)
  for line_idx = source_start, source_end do
    local line = pattern_track:line(line_idx)
    if not line.is_empty then
      local rel_idx = line_idx - source_start + 1
      out[#out+1] = serialize_line(line, ncols, ecols, ttype, rel_idx)
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

  -- Advance cursor after a Put-at-cursor placement.
  --   AdvanceToEnd takes precedence (jump to one past the placed preset),
  --   else UseEditStep advances by transport.edit_step.
  local advanced_to = nil
  if put_at_cursor then
    local pattern_lines = song.selected_pattern.number_of_lines
    if get_advance_to_end() then
      local span = slot_stored_lines(get_slot_data(slot_index))
      if span > 0 then
        local new_line = applied_at_line + span
        if new_line > pattern_lines then new_line = pattern_lines end
        song.selected_line_index = new_line
        advanced_to = new_line
      end
    elseif get_use_edit_step() then
      local step = song.transport.edit_step or 0
      if step > 0 then
        local new_line = applied_at_line + step
        if new_line > pattern_lines then new_line = pattern_lines end
        song.selected_line_index = new_line
        advanced_to = new_line
      end
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

-- Slice the currently selected matrix slot into num_slices equal-length
-- pieces and store them into consecutive banks starting at start_slot.
function PakettiPatternPresetSliceCurrent(num_slices, start_slot)
  num_slices = tonumber(num_slices) or 0
  start_slot = tonumber(start_slot) or 1
  if num_slices < 2 then
    renoise.app():show_status("Pattern Preset: Slice count must be 2 or more.")
    return
  end
  if start_slot < 1 or start_slot > NUM_SLOTS then
    renoise.app():show_status("Pattern Preset: Start slot out of range.")
    return
  end
  if start_slot + num_slices - 1 > NUM_SLOTS then
    renoise.app():show_status(string.format(
      "Pattern Preset: %d slices starting at slot %02d would exceed slot %02d.",
      num_slices, start_slot, NUM_SLOTS))
    return
  end

  local song = renoise.song()
  local pattern = song.selected_pattern
  local total_lines = pattern.number_of_lines
  local chunk_size = math.floor(total_lines / num_slices)
  if chunk_size < 1 then
    renoise.app():show_status(string.format(
      "Pattern Preset: pattern has only %d lines — too few for %d slices.",
      total_lines, num_slices))
    return
  end

  for slice = 1, num_slices do
    local slot_idx = start_slot + slice - 1
    local source_start = (slice - 1) * chunk_size + 1
    local source_end = source_start + chunk_size - 1
    local data = serialize_selected_slot_range(source_start, source_end)
    local nm = string.format("Slice %d/%d (P%d/T%d)",
      slice, num_slices,
      song.selected_pattern_index, song.selected_track_index)
    set_slot_data(slot_idx, data, nm)
    refresh_slot_display(slot_idx)
  end

  renoise.app():show_status(string.format(
    "Pattern Preset: Sliced %d-line pattern into %d × %d-line slices, slots %02d-%02d.",
    total_lines, num_slices, chunk_size,
    start_slot, start_slot + num_slices - 1))
end

-- Human-readable encoding helpers --------------------------------------------

local PITCH_TO_VAL = {
  ["C-"]=0,["C#"]=1,["D-"]=2,["D#"]=3,["E-"]=4,["F-"]=5,
  ["F#"]=6,["G-"]=7,["G#"]=8,["A-"]=9,["A#"]=10,["B-"]=11,
}

local function note_value_to_str(v)
  if v == nil or v == 121 then return "---" end
  if v == 120 then return "OFF" end
  if v >= 0 and v < 120 then
    local oct = math.floor(v / 12)
    local n = v % 12
    return NOTE_NAMES[n + 1] .. tostring(oct)
  end
  return "---"
end

local function str_to_note_value(s)
  if s == nil then return 121 end
  s = s:upper()
  if s == "---" or s == ".." or s == "" then return 121 end
  if s == "OFF" then return 120 end
  local pitch_str, oct_str = s:match("^([A-G][-#])(%d)$")
  if pitch_str and oct_str then
    local p = PITCH_TO_VAL[pitch_str]
    local o = tonumber(oct_str)
    if p and o then return o * 12 + p end
  end
  return 121
end

local function byte_to_str(v, empty_val)
  if v == nil then return ".." end
  if empty_val ~= nil and v == empty_val then return ".." end
  return string.format("%02X", v)
end

local function str_to_byte(s, empty_val)
  if s == nil or s == ".." or s == "" then
    return empty_val ~= nil and empty_val or 0
  end
  return tonumber(s, 16) or 0
end

local function split_str(s, sep)
  local out = {}
  local pos = 1
  while true do
    local found = s:find(sep, pos, true)
    if found then
      out[#out+1] = s:sub(pos, found - 1)
      pos = found + #sep
    else
      out[#out+1] = s:sub(pos)
      break
    end
  end
  return out
end

-- Convert internal compact format → table of human-readable line strings
-- plus header values. Returns: { lines, total_lines, ncols, ecols, ttype }
local function slot_to_human(data)
  local result = { lines = {}, total_lines = 0, ncols = 0, ecols = 0, ttype = 1 }
  if data == nil or data == "" then return result end

  local first_sep = data:find("~", 1, true)
  local header = first_sep and data:sub(1, first_sep - 1) or data
  local lines_s, ncols_s, ecols_s, ttype_s = header:match("^H#(%d+)#(%d+)#(%d+)#(%d+)$")
  if not lines_s then return result end
  result.total_lines = tonumber(lines_s) or 0
  result.ncols = tonumber(ncols_s) or 0
  result.ecols = tonumber(ecols_s) or 0
  result.ttype = tonumber(ttype_s) or 1

  if not first_sep then return result end

  for chunk in (data:sub(first_sep + 1) .. "~"):gmatch("([^~]+)~") do
    if chunk:sub(1, 2) == "L#" then
      local body = chunk:sub(3)
      local h1 = body:find("#", 1, true)
      if h1 then
        local stored_idx = tonumber(body:sub(1, h1 - 1))
        local rest_body = body:sub(h1 + 1)
        local h2 = rest_body:find("#", 1, true)
        local nc_part, ec_part
        if h2 then
          nc_part = rest_body:sub(1, h2 - 1)
          ec_part = rest_body:sub(h2 + 1)
        else
          nc_part = rest_body
          ec_part = ""
        end

        local nc_strs = {}
        if nc_part ~= "" then
          for nc_str in (nc_part .. ":"):gmatch("([^:]*):") do
            if nc_str ~= "" then
              local nv, iv, vv, pv, dv, env, eav = nc_str:match(
                "^(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+)$")
              if nv then
                nc_strs[#nc_strs + 1] = string.format("%s %s %s %s %s %s %s",
                  note_value_to_str(tonumber(nv)),
                  byte_to_str(tonumber(iv), 255),
                  byte_to_str(tonumber(vv), 255),
                  byte_to_str(tonumber(pv), 255),
                  string.format("%02X", tonumber(dv) or 0),
                  string.format("%02X", tonumber(env) or 0),
                  string.format("%02X", tonumber(eav) or 0))
              end
            end
          end
        end

        local ec_strs = {}
        if ec_part ~= "" then
          for ec_str in (ec_part .. ":"):gmatch("([^:]*):") do
            if ec_str ~= "" then
              local en, ea = ec_str:match("^(%d+),(%d+)$")
              if en then
                ec_strs[#ec_strs + 1] = string.format("%02X %02X",
                  tonumber(en), tonumber(ea))
              end
            end
          end
        end

        local nc_combined = table.concat(nc_strs, " | ")
        local ec_combined = table.concat(ec_strs, " | ")
        if stored_idx then
          if ec_combined ~= "" then
            result.lines[#result.lines + 1] = string.format("%03d: %s || %s",
              stored_idx, nc_combined, ec_combined)
          else
            result.lines[#result.lines + 1] = string.format("%03d: %s",
              stored_idx, nc_combined)
          end
        end
      end
    end
  end
  return result
end

-- Convert parsed human meta + line strings → internal compact format.
local function human_to_slot(meta, line_strs)
  local lines_count = tonumber(meta.Lines) or 0
  local ncols = tonumber(meta.NoteCols) or 0
  local ecols = tonumber(meta.EffectCols) or 0
  local ttype = tonumber(meta.TrackType) or 1
  if lines_count <= 0 then return "" end

  local out = {}
  out[#out + 1] = string.format("H#%d#%d#%d#%d", lines_count, ncols, ecols, ttype)

  for _, raw in ipairs(line_strs) do
    local idx_str, payload = raw:match("^%s*(%d+)%s*:%s*(.-)%s*$")
    if idx_str then
      local line_idx = tonumber(idx_str)
      local nc_part_str, ec_part_str
      local sep_pos = payload:find("||", 1, true)
      if sep_pos then
        nc_part_str = payload:sub(1, sep_pos - 1):match("^%s*(.-)%s*$")
        ec_part_str = payload:sub(sep_pos + 2):match("^%s*(.-)%s*$")
      else
        nc_part_str = payload:match("^%s*(.-)%s*$")
        ec_part_str = ""
      end

      local nc_strs = {}
      if nc_part_str and nc_part_str ~= "" then
        for _, nc_human in ipairs(split_str(nc_part_str, " | ")) do
          nc_human = nc_human:match("^%s*(.-)%s*$") or ""
          if nc_human ~= "" then
            local fields = {}
            for f in nc_human:gmatch("%S+") do fields[#fields + 1] = f end
            if #fields >= 7 then
              local nv = str_to_note_value(fields[1])
              local iv = str_to_byte(fields[2], 255)
              local vv = str_to_byte(fields[3], 255)
              local pv = str_to_byte(fields[4], 255)
              local dv = str_to_byte(fields[5], 0)
              local en = str_to_byte(fields[6], 0)
              local ea = str_to_byte(fields[7], 0)
              nc_strs[#nc_strs + 1] = string.format("%d,%d,%d,%d,%d,%d,%d",
                nv, iv, vv, pv, dv, en, ea)
            end
          end
        end
      end

      local ec_strs = {}
      if ec_part_str and ec_part_str ~= "" then
        for _, ec_human in ipairs(split_str(ec_part_str, " | ")) do
          ec_human = ec_human:match("^%s*(.-)%s*$") or ""
          if ec_human ~= "" then
            local fields = {}
            for f in ec_human:gmatch("%S+") do fields[#fields + 1] = f end
            if #fields >= 2 then
              local en = str_to_byte(fields[1], 0)
              local ea = str_to_byte(fields[2], 0)
              ec_strs[#ec_strs + 1] = string.format("%d,%d", en, ea)
            end
          end
        end
      end

      out[#out + 1] = string.format("L#%d#%s#%s",
        line_idx, table.concat(nc_strs, ":"), table.concat(ec_strs, ":"))
    end
  end

  return table.concat(out, "~")
end

-- Save all 32 slot banks to a human-readable text file (v2 format).
function PakettiPatternPresetSaveBank(filename)
  if not filename or filename == "" then
    filename = renoise.app():prompt_for_filename_to_write(
      "txt", "Save Pattern Preset Bank")
    if not filename or filename == "" then return end
  end

  local lines = {
    "# Paketti Pattern Preset Bank — human-editable",
    "#",
    "# Per-line entry: <line>: <NC> | <NC> | ... || <EC> | <EC> | ...",
    "#   NC fields: <note> <inst> <vol> <pan> <delay> <fxN> <fxA>",
    "#   EC fields: <num> <amt>",
    "#   note: C-4, C#4, D-3, ..., OFF, ---",
    "#   bytes: 00-FF hex, .. = empty (inst/vol/pan only)",
    "#   delay/fxN/fxA always shown as 00-FF hex",
    "# Header per slot: Lines (pattern length), NoteCols, EffectCols,",
    "#   TrackType (1=Sequencer, 2=Master, 3=Send, 4=Group)",
    "PakettiPatternPresetBank v2",
    "",
  }
  for i = 1, NUM_SLOTS do
    local label = string.format("%02d", i)
    local name = preferences.PakettiPatternPreset[slot_name_key(i)].value or ""
    local data = preferences.PakettiPatternPreset[slot_key(i)].value or ""
    name = name:gsub("[\r\n]", " ")

    local h = slot_to_human(data)
    lines[#lines + 1] = "[Slot" .. label .. "]"
    lines[#lines + 1] = "Name=" .. name
    lines[#lines + 1] = "Lines=" .. tostring(h.total_lines)
    lines[#lines + 1] = "NoteCols=" .. tostring(h.ncols)
    lines[#lines + 1] = "EffectCols=" .. tostring(h.ecols)
    lines[#lines + 1] = "TrackType=" .. tostring(h.ttype)
    for _, l in ipairs(h.lines) do
      lines[#lines + 1] = l
    end
    lines[#lines + 1] = ""
  end

  local fh, err = io.open(filename, "w")
  if not fh then
    renoise.app():show_error("Pattern Preset: cannot open file for writing: " .. tostring(err))
    return
  end
  fh:write(table.concat(lines, "\n"))
  fh:close()
  renoise.app():show_status("Pattern Preset: Saved bank to " .. filename)
end

-- Internal: parse v1 (compact pipe-separated) bank file format.
local function load_bank_v1(content)
  local count = 0
  for raw_line in (content .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    local idx_str, field, value = raw_line:match("^Slot(%d%d)|([^|]+)|(.*)$")
    if idx_str then
      local i = tonumber(idx_str)
      if i and i >= 1 and i <= NUM_SLOTS then
        if field == "Name" then
          preferences.PakettiPatternPreset[slot_name_key(i)].value = value or ""
        elseif field == "Data" then
          preferences.PakettiPatternPreset[slot_key(i)].value = value or ""
          if value and value ~= "" then count = count + 1 end
        end
      end
    end
  end
  return count
end

-- Internal: parse v2 (human-readable section-based) bank file format.
local function load_bank_v2(content)
  local count = 0
  local current_slot = nil
  local current_meta = {}
  local current_lines = {}

  local function flush()
    if current_slot then
      local data = ""
      if (tonumber(current_meta.Lines) or 0) > 0 then
        data = human_to_slot(current_meta, current_lines)
      end
      preferences.PakettiPatternPreset[slot_key(current_slot)].value = data
      preferences.PakettiPatternPreset[slot_name_key(current_slot)].value =
        current_meta.Name or ""
      if data ~= "" then count = count + 1 end
    end
    current_slot = nil
    current_meta = {}
    current_lines = {}
  end

  for raw in (content .. "\n"):gmatch("([^\r\n]*)\r?\n") do
    local stripped = raw:match("^%s*(.-)%s*$") or ""
    if stripped == "" or stripped:sub(1, 1) == "#" or
       stripped:match("^PakettiPatternPresetBank") then
      -- comment / blank / header line — skip
    else
      local section_idx = stripped:match("^%[Slot(%d%d)%]$")
      if section_idx then
        flush()
        current_slot = tonumber(section_idx)
      elseif current_slot then
        local key, val = stripped:match("^([A-Za-z]+)=(.*)$")
        if key then
          current_meta[key] = val
        elseif stripped:match("^%d+%s*:") then
          current_lines[#current_lines + 1] = stripped
        end
      end
    end
  end
  flush()
  return count
end

-- Load all 32 slot banks from a text file. Supports v1 (compact) and v2 (human).
function PakettiPatternPresetLoadBank(filename)
  if not filename or filename == "" then
    filename = renoise.app():prompt_for_filename_to_read(
      { "*.txt" }, "Load Pattern Preset Bank")
    if not filename or filename == "" then return end
  end

  local fh, err = io.open(filename, "r")
  if not fh then
    renoise.app():show_error("Pattern Preset: cannot open file for reading: " .. tostring(err))
    return
  end
  local content = fh:read("*a")
  fh:close()

  if not content:match("PakettiPatternPresetBank") then
    renoise.app():show_error("Pattern Preset: file is not a Paketti Pattern Preset bank.")
    return
  end

  local count
  if content:match("PakettiPatternPresetBank v2") then
    count = load_bank_v2(content)
  else
    count = load_bank_v1(content)
  end

  preferences:save_as("preferences.xml")
  refresh_all_displays()
  renoise.app():show_status(string.format(
    "Pattern Preset: Loaded bank from %s (%d non-empty slots).",
    filename, count or 0))
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
    vb:row{
      spacing = 8,
      vb:checkbox{
        value = get_advance_to_end(),
        notifier = function(v)
          preferences.PakettiPatternPreset.AdvanceToEnd.value = v
          preferences:save_as("preferences.xml")
        end,
      },
      vb:text{
        text = "Advance to End of Put (after Put-at-cursor, jump cursor to the line right after the placed preset — overrides Edit Step)",
      },
    },
    row1,
    row2,
    row3,
    row4,
    vb:row{
      spacing = 4,
      vb:text{ text = "Slice current pattern into", style = "strong" },
      vb:popup{
        id = "pp_slice_count",
        items = { "2", "4", "8", "16", "32" },
        value = 3,
        width = 50,
      },
      vb:text{ text = "equal pieces, starting at slot" },
      vb:valuebox{
        id = "pp_slice_start",
        min = 1,
        max = NUM_SLOTS,
        value = 1,
        width = 50,
      },
      vb:button{
        text = "Slice & Distribute",
        width = 130,
        pressed = function()
          local items = { 2, 4, 8, 16, 32 }
          local n = items[vb.views.pp_slice_count.value] or 8
          local start_slot = vb.views.pp_slice_start.value or 1
          PakettiPatternPresetSliceCurrent(n, start_slot)
        end,
      },
    },
    vb:row{
      spacing = 4,
      vb:button{
        text = "Save Bank to File...",
        width = 150,
        pressed = function() PakettiPatternPresetSaveBank() end,
      },
      vb:button{
        text = "Load Bank from File...",
        width = 150,
        pressed = function() PakettiPatternPresetLoadBank() end,
      },
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

PakettiAddMenuEntry{
  name = "Pattern Matrix:Paketti:Pattern Preset:Slice into 2",
  invoke = function() PakettiPatternPresetSliceCurrent(2, 1) end,
}
PakettiAddMenuEntry{
  name = "Pattern Matrix:Paketti:Pattern Preset:Slice into 4",
  invoke = function() PakettiPatternPresetSliceCurrent(4, 1) end,
}
PakettiAddMenuEntry{
  name = "Pattern Matrix:Paketti:Pattern Preset:Slice into 8",
  invoke = function() PakettiPatternPresetSliceCurrent(8, 1) end,
}
PakettiAddMenuEntry{
  name = "Pattern Matrix:Paketti:Pattern Preset:Slice into 16",
  invoke = function() PakettiPatternPresetSliceCurrent(16, 1) end,
}
PakettiAddMenuEntry{
  name = "Pattern Matrix:Paketti:Pattern Preset:Slice into 32",
  invoke = function() PakettiPatternPresetSliceCurrent(32, 1) end,
}
PakettiAddMenuEntry{
  name = "Pattern Matrix:Paketti:Pattern Preset:Save Bank to File...",
  invoke = function() PakettiPatternPresetSaveBank() end,
}
PakettiAddMenuEntry{
  name = "Pattern Matrix:Paketti:Pattern Preset:Load Bank from File...",
  invoke = function() PakettiPatternPresetLoadBank() end,
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Pattern Preset Slice into 2",
  invoke = function() PakettiPatternPresetSliceCurrent(2, 1) end,
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Pattern Preset Slice into 4",
  invoke = function() PakettiPatternPresetSliceCurrent(4, 1) end,
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Pattern Preset Slice into 8",
  invoke = function() PakettiPatternPresetSliceCurrent(8, 1) end,
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Pattern Preset Slice into 16",
  invoke = function() PakettiPatternPresetSliceCurrent(16, 1) end,
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Pattern Preset Slice into 32",
  invoke = function() PakettiPatternPresetSliceCurrent(32, 1) end,
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Pattern Preset Save Bank to File",
  invoke = function() PakettiPatternPresetSaveBank() end,
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Pattern Preset Load Bank from File",
  invoke = function() PakettiPatternPresetLoadBank() end,
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Pattern Preset Save Bank to File",
  invoke = function(message)
    if message:is_trigger() then PakettiPatternPresetSaveBank() end
  end,
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Pattern Preset Load Bank from File",
  invoke = function(message)
    if message:is_trigger() then PakettiPatternPresetLoadBank() end
  end,
}

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
