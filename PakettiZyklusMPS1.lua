function paketti_convert_track_to_pattrns_script_accurate()
  local rs = renoise.song()
  local instr = rs.selected_instrument
  local patt = rs.selected_pattern
  local patt_idx = rs.selected_pattern_index
  local track_idx = rs.selected_track_index
  local track = rs.tracks[track_idx]

  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Paketti: Not a note track.")
    return
  end

  if #instr.phrases >= 128 then
    renoise.app():show_status("Paketti: Max phrase count reached.")
    return
  end

  local track_name = track.name
  local safe_name = track_name:gsub("%W", "_"):gsub("__+", "_"):gsub("^_+", ""):gsub("_+$", "")
  local phrase_name = string.format("pattrns_%s_Pat%02d", safe_name, patt_idx + 1)

  local phrase = instr:insert_phrase(#instr.phrases + 1)
  phrase.name = phrase_name
  phrase.script_mode = true

  local src_track = rs.patterns[patt_idx].tracks[track_idx]
  local pattern_lines = patt.number_of_lines

  local midi_notes = {}

  for line = 1, pattern_lines do
    for col = 1, 12 do
      local note_col = src_track:line(line).note_columns[col]
      if note_col and not note_col.is_empty and note_col.note_value < 120 then
        table.insert(midi_notes, note_col.note_value)
        break
      end
    end
  end

  local function list_of_numbers(tbl)
    local out = {}
    for _, v in ipairs(tbl) do
      table.insert(out, tostring(v))
    end
    return table.concat(out, ", ")
  end

  local script = [[
return pattern {
  unit = "1/64",
  parameter = {
    parameter.enum("speed", "1x", {
      "1/4x", "1/3x", "1/2x", "1x", "2x", "3x", "4x"
    }),
    parameter.boolean("reverse", false),
    parameter.integer("transpose", 0, -24, 24),
    parameter.integer("swing_amount", 0, 0, 50),
    parameter.enum("swing_interval", 2, { 2, 3, 4 })
  },

    pulse = function(context)
    local map = {
      ["1/4x"] = 16,
      ["1/3x"] = 12,
      ["1/2x"] = 8,
      ["1x"]   = 4,
      ["2x"]   = 2,
      ["3x"]   = 1.33,
      ["4x"]   = 1
    }
    local div = math.floor(map[context.parameter.speed] or 4)
    local step = context.pulse_step - 1
    local swing_every = tonumber(context.parameter.swing_interval) or 2
    local swing_amount = tonumber(context.parameter.swing_amount) or 0

    if step % div == 0 then
      local delay = 0
      if (step // div) % swing_every == 1 then
        delay = math.floor(256 * (swing_amount / 100))
      end
      return { 1, delay }
    else
      return 0
    end
  end,


  event = function(context)
    local notes = { ]] .. list_of_numbers(midi_notes) .. [[ }
    if context.parameter.reverse then
      for i = 1, math.floor(#notes / 2) do
        notes[i], notes[#notes - i + 1] = notes[#notes - i + 1], notes[i]
      end
    end
    local transposed = {}
    for _, n in ipairs(notes) do
      table.insert(transposed, n + context.parameter.transpose)
    end
    return transposed
  end
}
]]

  phrase.script_data = script
  renoise.app():show_status("✅ pattrns script with speed + voicing + reverse: " .. phrase.name)
end

renoise.tool():add_menu_entry {
  name = "Pattern Editor:Paketti:Convert Track to pattrns (Pulse Divider + FX)",
  invoke = paketti_convert_track_to_pattrns_script_accurate
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:Convert Track to pattrns (Pulse Divider + FX)",
  invoke = paketti_convert_track_to_pattrns_script_accurate
}
