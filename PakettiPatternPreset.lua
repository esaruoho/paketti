-- PakettiPatternPreset.lua
-- Pick/Put a complete Pattern Matrix slot (one track-in-pattern cell)
-- across 32 banks stored persistently in preferences.

local NUM_SLOTS = 32
local vb = renoise.ViewBuilder()
local dialog = nil

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

local function get_slot_name(i)
  return preferences.PakettiPatternPreset[slot_name_key(i)].value or ""
end

local function is_slot_empty(i)
  local d = get_slot_data(i)
  return d == nil or d == ""
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

-- Apply serialized slot data to the currently selected matrix slot
local function apply_to_selected_slot(data)
  if data == nil or data == "" then return false, "Empty preset" end

  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.tracks[track_index]
  local pattern_track = pattern.tracks[track_index]

  -- Parse header (first chunk before first '~')
  local first_sep = data:find("~", 1, true)
  local header = first_sep and data:sub(1, first_sep - 1) or data
  local lines_s, ncols_s, ecols_s = header:match("^H#(%d+)#(%d+)#(%d+)#%d+$")
  if not lines_s then return false, "Invalid preset header" end
  local _ = lines_s
  local stored_ncols = tonumber(ncols_s) or 0
  local stored_ecols = tonumber(ecols_s) or 0

  -- Update visible columns to fit stored data (clamped, but never reduce)
  if track.type == renoise.Track.TRACK_TYPE_SEQUENCER and stored_ncols > 0 then
    if stored_ncols > track.visible_note_columns then
      track.visible_note_columns = math.min(stored_ncols, 12)
    end
  end
  if stored_ecols > 0 and stored_ecols > track.visible_effect_columns then
    track.visible_effect_columns = math.min(stored_ecols, 8)
  end

  -- Clear destination track in pattern
  for line_idx = 1, pattern.number_of_lines do
    pattern_track:line(line_idx):clear()
  end

  if not first_sep then
    return true  -- empty pattern
  end

  -- Walk the rest
  local rest = data:sub(first_sep + 1)
  for chunk in (rest .. "~"):gmatch("([^~]+)~") do
    if chunk:sub(1, 2) == "L#" then
      local body = chunk:sub(3)
      -- body = "<line>#<nc>#<ec>" — but nc and ec may contain ':' and ',' but not '#'
      local hash1 = body:find("#", 1, true)
      if hash1 then
        local line_idx = tonumber(body:sub(1, hash1 - 1))
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

        if line_idx and line_idx >= 1 and line_idx <= pattern.number_of_lines then
          local line = pattern_track:line(line_idx)

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

  return true
end

-- Build a short summary describing the slot for the UI
local function slot_summary(i)
  local d = get_slot_data(i)
  if d == nil or d == "" then
    return string.format("Slot %02d: Empty", i)
  end
  local lines, ncols, ecols = d:match("^H#(%d+)#(%d+)#(%d+)#")
  local count = 0
  for _ in d:gmatch("L#") do count = count + 1 end
  local name = get_slot_name(i)
  if name and name ~= "" then
    return string.format("Slot %02d (%s): %s lines, %s nc, %s ec, %d filled",
      i, name, lines or "?", ncols or "?", ecols or "?", count)
  end
  return string.format("Slot %02d: %s lines, %s nc, %s ec, %d filled",
    i, lines or "?", ncols or "?", ecols or "?", count)
end

-- Update single slot's display in the dialog (if open)
local function refresh_slot_display(i)
  if vb and vb.views then
    local id = string.format("pp_slot_display_%02d", i)
    if vb.views[id] then
      vb.views[id].text = slot_summary(i)
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
  local ok, err = apply_to_selected_slot(get_slot_data(slot_index))
  if not ok then
    renoise.app():show_status(string.format("Pattern Preset Put failed: %s", err or "?"))
    return
  end
  renoise.app():show_status(string.format(
    "Pattern Preset: Put Slot %02d into Pattern %d, Track %d",
    slot_index, song.selected_pattern_index, song.selected_track_index))
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

local function build_slot_row(i)
  return vb:row{
    spacing = 4,
    vb:text{
      id = string.format("pp_slot_display_%02d", i),
      text = slot_summary(i),
      width = 260,
      style = "strong",
    },
    vb:button{
      text = "Pick",
      width = 44,
      pressed = function() PakettiPatternPresetPick(i) end,
    },
    vb:button{
      text = "Put",
      width = 44,
      pressed = function() PakettiPatternPresetPut(i) end,
    },
    vb:button{
      text = "Clear",
      width = 50,
      pressed = function() PakettiPatternPresetClear(i) end,
    },
  }
end

function PakettiPatternPresetDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  vb = renoise.ViewBuilder()

  local left_col = vb:column{ spacing = 2 }
  local right_col = vb:column{ spacing = 2 }
  for i = 1, 16 do left_col:add_child(build_slot_row(i)) end
  for i = 17, NUM_SLOTS do right_col:add_child(build_slot_row(i)) end

  local content = vb:column{
    margin = 8,
    spacing = 6,
    vb:text{
      text = "Pattern Preset — Pick/Put complete Pattern Matrix slots (32 banks).",
      style = "strong",
    },
    vb:text{
      text = "Pick captures the currently selected matrix cell (selected pattern × selected track). Put writes the stored cell into the currently selected matrix cell.",
    },
    vb:row{
      spacing = 8,
      left_col,
      right_col,
    },
    vb:row{
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

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(d) dialog = d end
  )
  dialog = renoise.app():show_custom_dialog("Paketti Pattern Preset", content, keyhandler)
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
    name = "Pattern Matrix:Paketti:Pattern Preset:Pick " .. label,
    invoke = function() PakettiPatternPresetPick(i) end,
  }
end
for i = 1, NUM_SLOTS do
  local label = string.format("%02d", i)
  PakettiAddMenuEntry{
    name = "Pattern Matrix:Paketti:Pattern Preset:Put " .. label,
    invoke = function() PakettiPatternPresetPut(i) end,
  }
end
for i = 1, NUM_SLOTS do
  local label = string.format("%02d", i)
  PakettiAddMenuEntry{
    name = "Pattern Matrix:Paketti:Pattern Preset:Clear " .. label,
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
