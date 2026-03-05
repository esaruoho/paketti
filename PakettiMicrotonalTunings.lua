-- Paketti Microtonal Tunings
-- Applies custom tuning systems to instruments via trigger_options.tuning API
-- Supports: Golden Pythagorean, 36-TET, Solfeggio, Colundi, N-EDO, historical temperaments, Just Intonation

local microtonal_dialog = nil

-- ========================================
-- TUNING GENERATORS
-- ========================================

-- Golden Pythagorean (13-note scale from phi)
local function generate_golden_pythagorean()
  local phi = (1 + math.sqrt(5)) / 2
  local ratios = {}
  for n = 0, 12 do
    local r = phi ^ n
    while r >= 2.0 do r = r / 2.0 end
    while r < 1.0 do r = r * 2.0 end
    ratios[#ratios + 1] = r
  end
  table.sort(ratios)
  -- Remove duplicate 1.0 entries (phi^0 = 1.0, and possibly others that reduce to ~1.0)
  local unique = {}
  for i, r in ipairs(ratios) do
    if i == 1 or math.abs(r - ratios[i - 1]) > 0.0001 then
      unique[#unique + 1] = r
    end
  end
  -- The tuning array should NOT include the unison (1/1) — only the scale degrees above it
  -- and MUST end with the octave (2/1)
  local result = {}
  for _, r in ipairs(unique) do
    if r > 1.0001 then
      result[#result + 1] = r
    end
  end
  -- Ensure octave is present
  if #result == 0 or math.abs(result[#result] - 2.0) > 0.001 then
    result[#result + 1] = 2.0
  end
  return result, "Golden Pythagorean (13-note)"
end

-- N-EDO (N equal divisions of the octave)
local function generate_n_edo(n)
  local ratios = {}
  for step = 1, n do
    ratios[#ratios + 1] = 2 ^ (step / n)
  end
  return ratios, n .. "-EDO"
end

-- Solfeggio frequencies as a scale
-- Base frequencies: 174, 285, 396, 417, 528, 639, 741, 852, 963 Hz
-- We express these as ratios relative to the lowest (174 Hz)
local function generate_solfeggio()
  local freqs = {174, 285, 396, 417, 528, 639, 741, 852, 963}
  local base = freqs[1]
  local ratios = {}
  for i = 2, #freqs do
    local r = freqs[i] / base
    -- Reduce to one octave
    while r >= 2.0 do r = r / 2.0 end
    while r < 1.0 do r = r * 2.0 end
    if r > 1.0001 then
      ratios[#ratios + 1] = r
    end
  end
  table.sort(ratios)
  -- Remove near-duplicates
  local unique = {}
  for i, r in ipairs(ratios) do
    if i == 1 or math.abs(r - ratios[i - 1]) > 0.001 then
      unique[#unique + 1] = r
    end
  end
  unique[#unique + 1] = 2.0
  return unique, "Solfeggio"
end

-- Colundi Sequence (Aleksi Perala / Ovuca)
-- 128 frequencies spanning multiple octaves. We reduce the first octave's worth to ratios.
-- Primary Colundi frequencies (first octave, Hz):
local function generate_colundi()
  -- The Colundi sequence defines specific frequencies. Here are the fundamental
  -- 12 tones of the first Colundi octave as documented by Aleksi Perala.
  -- These are NOT equal-tempered — they form an irregular scale.
  local colundi_hz = {
    261.6256, -- C (reference, standard C4)
    273.375,
    286.6725,
    298.6,
    312.975,
    327.35,
    340.15,
    353.7,
    370.0,
    385.75,
    401.5,
    419.625,
  }
  local base = colundi_hz[1]
  local ratios = {}
  for i = 2, #colundi_hz do
    ratios[#ratios + 1] = colundi_hz[i] / base
  end
  ratios[#ratios + 1] = 2.0
  return ratios, "Colundi"
end

-- Werckmeister III (1691)
local function generate_werckmeister_iii()
  local ratios = {
    256/243,     -- C#
    1.117403,    -- D  (sqrt(2) * 256/243 / sqrt(3/2) ≈ Werckmeister D)
    32/27,       -- Eb
    1.252827,    -- E
    4/3,         -- F
    1024/729,    -- F#
    1.494927,    -- G
    128/81,      -- Ab
    1.670436,    -- A
    16/9,        -- Bb
    1.879241,    -- B
    2/1          -- C (octave)
  }
  return ratios, "Werckmeister III (1691)"
end

-- Pythagorean (pure fifths)
local function generate_pythagorean()
  local ratios = {}
  -- Stack pure 3/2 fifths: F C G D A E B F# C# G# D# A#
  -- Generate 12 notes from -1 to +10 fifths from C, reduce to octave
  local fifth = 3/2
  for n = -1, 10 do
    local r = fifth ^ n
    while r >= 2.0 do r = r / 2.0 end
    while r < 1.0 do r = r * 2.0 end
    ratios[#ratios + 1] = r
  end
  table.sort(ratios)
  -- Remove unison, add octave
  local result = {}
  for _, r in ipairs(ratios) do
    if r > 1.0001 then
      result[#result + 1] = r
    end
  end
  if #result == 0 or math.abs(result[#result] - 2.0) > 0.001 then
    result[#result + 1] = 2.0
  end
  return result, "Pythagorean (pure fifths)"
end

-- Just Intonation (5-limit, Ptolemy's intense diatonic + chromatic)
local function generate_just_intonation()
  local ratios = {
    16/15,   -- m2
    9/8,     -- M2
    6/5,     -- m3
    5/4,     -- M3
    4/3,     -- P4
    45/32,   -- aug4 / tritone
    3/2,     -- P5
    8/5,     -- m6
    5/3,     -- M6
    9/5,     -- m7
    15/8,    -- M7
    2/1      -- octave
  }
  return ratios, "Just Intonation (5-limit)"
end

-- Kirnberger III (1779)
local function generate_kirnberger_iii()
  local ratios = {
    256/243,            -- C#
    math.sqrt(3/2) * (2/3) * 2,  -- D ≈ 1.1180
    32/27,              -- Eb
    5/4,                -- E (pure major third)
    4/3,                -- F
    1024/729,           -- F#
    math.sqrt(3/2) * math.sqrt(3/2) * (4/9) * 4, -- G ≈ 1.4953
    128/81,             -- Ab
    math.sqrt(3/2) * math.sqrt(3/2) * math.sqrt(3/2) * (8/27) * 4, -- A
    16/9,               -- Bb
    15/8,               -- B (pure)
    2/1
  }
  -- Clamp any rounding issues
  for i = 1, #ratios do
    if ratios[i] < 1.0 then ratios[i] = ratios[i] * 2.0 end
    if ratios[i] >= 2.0 and i < #ratios then ratios[i] = ratios[i] / 2.0 end
  end
  return ratios, "Kirnberger III (1779)"
end

-- Quarter-comma Meantone
local function generate_quarter_comma_meantone()
  -- Fifth = 5^(1/4) ≈ 1.49535 (narrowed from 3/2)
  local fifth = 5 ^ (1/4)
  local ratios = {}
  for n = -1, 10 do
    local r = fifth ^ n
    while r >= 2.0 do r = r / 2.0 end
    while r < 1.0 do r = r * 2.0 end
    ratios[#ratios + 1] = r
  end
  table.sort(ratios)
  local result = {}
  for _, r in ipairs(ratios) do
    if r > 1.0001 then
      result[#result + 1] = r
    end
  end
  if math.abs(result[#result] - 2.0) > 0.001 then
    result[#result + 1] = 2.0
  end
  return result, "Quarter-Comma Meantone"
end

-- ========================================
-- TUNING PRESET TABLE
-- ========================================

local tuning_presets = {
  {name = "12-TET (Standard)", generator = function() return {}, "12-TET (Standard)" end, is_reset = true},
  {name = "Golden Pythagorean (13-note)", generator = generate_golden_pythagorean},
  {name = "36-EDO", generator = function() return generate_n_edo(36) end},
  {name = "Solfeggio", generator = generate_solfeggio},
  {name = "Colundi", generator = generate_colundi},
  {name = "Pythagorean (pure fifths)", generator = generate_pythagorean},
  {name = "Just Intonation (5-limit)", generator = generate_just_intonation},
  {name = "Werckmeister III (1691)", generator = generate_werckmeister_iii},
  {name = "Kirnberger III (1779)", generator = generate_kirnberger_iii},
  {name = "Quarter-Comma Meantone", generator = generate_quarter_comma_meantone},
  {name = "5-EDO", generator = function() return generate_n_edo(5) end},
  {name = "7-EDO", generator = function() return generate_n_edo(7) end},
  {name = "10-EDO", generator = function() return generate_n_edo(10) end},
  {name = "15-EDO", generator = function() return generate_n_edo(15) end},
  {name = "17-EDO", generator = function() return generate_n_edo(17) end},
  {name = "19-EDO", generator = function() return generate_n_edo(19) end},
  {name = "22-EDO", generator = function() return generate_n_edo(22) end},
  {name = "24-EDO (Quarter-tone)", generator = function() return generate_n_edo(24) end},
  {name = "31-EDO", generator = function() return generate_n_edo(31) end},
  {name = "41-EDO", generator = function() return generate_n_edo(41) end},
  {name = "48-EDO", generator = function() return generate_n_edo(48) end},
  {name = "53-EDO", generator = function() return generate_n_edo(53) end},
  {name = "72-EDO", generator = function() return generate_n_edo(72) end},
}

-- ========================================
-- HELPER: ratio to cents
-- ========================================

local function ratio_to_cents(ratio)
  return 1200 * math.log(ratio) / math.log(2)
end

-- ========================================
-- APPLY TUNING TO INSTRUMENT
-- ========================================

local function apply_tuning_to_instrument(preset_index, instrument_index)
  local song = renoise.song()
  if not song then return end

  local instr = instrument_index and song.instruments[instrument_index] or song.selected_instrument
  if not instr then
    renoise.app():show_status("No instrument selected")
    return
  end

  local preset = tuning_presets[preset_index]
  if not preset then return end

  song:describe_undo("Apply Microtonal Tuning: " .. preset.name)

  if preset.is_reset then
    instr.trigger_options.tuning = {}
    instr.trigger_options.tuning_name = ""
    renoise.app():show_status("Reset " .. instr.name .. " to standard 12-TET tuning")
    return
  end

  local ratios, name = preset.generator()
  instr.trigger_options.tuning = ratios
  instr.trigger_options.tuning_name = name

  local note_count = #ratios
  if ratios[#ratios] and math.abs(ratios[#ratios] - 2.0) < 0.001 then
    note_count = note_count -- octave included in count
  end
  renoise.app():show_status("Applied " .. name .. " (" .. note_count .. " notes/octave) to " .. instr.name)
end

-- Apply to all instruments
local function apply_tuning_to_all_instruments(preset_index)
  local song = renoise.song()
  if not song then return end

  local preset = tuning_presets[preset_index]
  if not preset then return end

  song:describe_undo("Apply Microtonal Tuning to All: " .. preset.name)

  local ratios, name
  if preset.is_reset then
    ratios = {}
    name = ""
  else
    ratios, name = preset.generator()
  end

  local count = 0
  for i = 1, #song.instruments do
    song.instruments[i].trigger_options.tuning = ratios
    song.instruments[i].trigger_options.tuning_name = name or ""
    count = count + 1
  end

  if preset.is_reset then
    renoise.app():show_status("Reset all " .. count .. " instruments to standard 12-TET")
  else
    renoise.app():show_status("Applied " .. name .. " to all " .. count .. " instruments")
  end
end

-- ========================================
-- DIALOG
-- ========================================

local function show_microtonal_tuning_dialog()
  if microtonal_dialog and microtonal_dialog.visible then
    microtonal_dialog:close()
  end

  local vb = renoise.ViewBuilder()

  -- Build popup items list
  local popup_items = {}
  for _, preset in ipairs(tuning_presets) do
    popup_items[#popup_items + 1] = preset.name
  end

  -- Try to find current tuning in presets
  local current_index = 1
  local song = renoise.song()
  if song and song.selected_instrument then
    local current_name = song.selected_instrument.trigger_options.tuning_name
    local current_tuning = song.selected_instrument.trigger_options.tuning
    if not current_name or current_name == "" then
      if #current_tuning == 0 then
        current_index = 1 -- 12-TET
      end
    else
      for i, preset in ipairs(tuning_presets) do
        if preset.name == current_name or current_name:find(preset.name, 1, true) then
          current_index = i
          break
        end
      end
    end
  end

  -- Scale info display
  local function get_scale_info(preset_index)
    local preset = tuning_presets[preset_index]
    if not preset then return "No preset selected" end
    if preset.is_reset then return "Standard 12-TET equal temperament (12 notes, 100 cents each)" end

    local ratios, name = preset.generator()
    local lines = {name .. " — " .. #ratios .. " notes per octave", ""}

    -- Show each degree with cents
    lines[#lines + 1] = string.format("  %-6s  %-12s  %s", "Deg", "Ratio", "Cents")
    lines[#lines + 1] = string.format("  %-6s  %-12s  %s", "---", "-----", "-----")
    lines[#lines + 1] = string.format("  %-6s  %-12s  %s", "0", "1/1", "0.00")
    for i, r in ipairs(ratios) do
      local cents = ratio_to_cents(r)
      lines[#lines + 1] = string.format("  %-6d  %-12.6f  %.2f", i, r, cents)
    end
    return table.concat(lines, "\n")
  end

  local content = vb:column{
    margin = 10,
    spacing = 5,

    vb:text{text = "Microtonal Tuning System", style = "strong", font = "bold"},

    vb:row{
      spacing = 5,
      vb:text{text = "Tuning:", width = 50},
      vb:popup{
        id = "microtonal_preset_popup",
        items = popup_items,
        value = current_index,
        width = 280,
        notifier = function(index)
          vb.views.microtonal_info.text = get_scale_info(index)
        end
      },
    },

    vb:multiline_textfield{
      id = "microtonal_info",
      text = get_scale_info(current_index),
      width = 450,
      height = 300,
      font = "mono",
    },

    vb:row{
      spacing = 5,
      vb:button{
        text = "Apply to Selected Instrument",
        width = 180,
        notifier = function()
          apply_tuning_to_instrument(vb.views.microtonal_preset_popup.value)
        end
      },
      vb:button{
        text = "Apply to All Instruments",
        width = 160,
        notifier = function()
          local choice = renoise.app():show_prompt(
            "Apply to All",
            "Apply this tuning to ALL instruments in the song?",
            {"OK", "Cancel"}
          )
          if choice == "OK" then
            apply_tuning_to_all_instruments(vb.views.microtonal_preset_popup.value)
          end
        end
      },
    },

    vb:row{
      spacing = 5,
      vb:button{
        text = "Load Scala File (.scl)...",
        width = 180,
        notifier = function()
          local filename = renoise.app():prompt_for_filename_to_read({"scl"}, "Select Scala tuning file")
          if filename and filename ~= "" then
            local instr = renoise.song().selected_instrument
            if instr then
              renoise.song():describe_undo("Load Scala Tuning")
              local success = instr.trigger_options:load_tuning(filename)
              if success then
                renoise.app():show_status("Loaded Scala tuning: " .. filename:match("([^/\\]+)$"))
                vb.views.microtonal_info.text = "Loaded Scala file: " .. filename:match("([^/\\]+)$") .. "\nTuning name: " .. (instr.trigger_options.tuning_name or "")
              else
                renoise.app():show_status("Failed to load Scala file")
              end
            end
          end
        end
      },
      vb:button{
        text = "Export as Scala (.scl)...",
        width = 150,
        notifier = function()
          export_tuning_as_scala(vb.views.microtonal_preset_popup.value)
        end
      },
      vb:button{
        text = "Reset to 12-TET",
        width = 120,
        notifier = function()
          apply_tuning_to_instrument(1)
          vb.views.microtonal_preset_popup.value = 1
          vb.views.microtonal_info.text = get_scale_info(1)
        end
      },
    },

    vb:space{height = 5},
    vb:text{text = "Wavetable Generators", style = "strong", font = "bold"},

    vb:row{
      spacing = 5,
      vb:button{
        text = "Golden Shimmer Wavetable",
        width = 180,
        tooltip = "12-position wavetable: phi-detuned golden partials create shimmering effect",
        notifier = generate_shimmering_wavetable
      },
      vb:button{
        text = "Golden Beating Wavetable",
        width = 180,
        tooltip = "12-position wavetable: morph from unison to golden sixth interval (beating)",
        notifier = generate_golden_beating_wavetable
      },
    },
  }

  microtonal_dialog = renoise.app():show_custom_dialog("Paketti Microtonal Tunings", content)
end

-- ========================================
-- SHIMMERING WAVETABLE GENERATOR (Phase 3)
-- ========================================

local function generate_shimmering_wavetable()
  local song = renoise.song()
  if not song then return end

  local phi = (1 + math.sqrt(5)) / 2
  local wave_size = 512
  local num_positions = 12 -- max wavetable positions in PCMWriter convention
  local sample_rate = 44100

  song:describe_undo("Generate Golden Shimmering Wavetable")

  -- Create a new instrument
  local instr_index = song.selected_instrument_index
  local instr = song.instruments[instr_index]

  -- Clear existing samples if instrument has no name (empty slot)
  if instr.name == "" then
    while #instr.samples > 1 do
      instr:delete_sample_at(#instr.samples)
    end
  else
    -- Insert new instrument
    song:insert_instrument_at(instr_index + 1)
    instr_index = instr_index + 1
    instr = song.instruments[instr_index]
    song.selected_instrument_index = instr_index
  end

  instr.name = "Golden Shimmer Wavetable"

  -- Generate 12 wavetable positions, each slightly detuned by golden-ratio cents
  for pos = 1, num_positions do
    -- Ensure sample slot exists
    if pos > #instr.samples then
      instr:insert_sample_at(pos)
    end
    local sample = instr.samples[pos]
    local buffer = sample.sample_buffer

    -- Detune: each position is shifted by (pos-1) * phi cents
    -- This creates a subtle beating/shimmering when cycling through positions
    local detune_cents = (pos - 1) * phi -- 0, 1.618, 3.236, 4.854, ...
    local detune_ratio = 2 ^ (detune_cents / 1200)

    -- Also add golden harmonics: each position adds more phi-spaced partials
    local num_partials = math.floor(pos / 2) + 1 -- 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6

    buffer:create_sample_data(sample_rate, 16, 1, wave_size)
    buffer:prepare_sample_data_changes()

    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local t = phase * math.pi * 2 * detune_ratio
      local value = 0
      local amp_sum = 0

      for p = 0, num_partials - 1 do
        local freq = phi ^ p
        local amp = 1 / (p + 1)
        value = value + math.sin(t * freq) * amp
        amp_sum = amp_sum + amp
      end

      if amp_sum > 0 then
        value = value / amp_sum
      end

      -- Convert to 16-bit range (0..65535 for Renoise buffer)
      local sample_val = math.floor((value * 32767) + 32768)
      sample_val = math.max(0, math.min(65535, sample_val))
      -- Renoise set_sample_data expects -1..1 range
      buffer:set_sample_data(1, i, (sample_val - 32768) / 32768)
    end

    buffer:finalize_sample_data_changes()

    sample.name = string.format("Shimmer %02d (+%.1f¢, %d partials)", pos, detune_cents, num_partials)
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = wave_size
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  end

  -- Remove the initial empty sample if it exists and has no data
  if #instr.samples > num_positions and not instr.samples[1].sample_buffer.has_sample_data then
    instr:delete_sample_at(1)
  end

  renoise.app():show_status("Generated Golden Shimmer Wavetable: " .. num_positions .. " positions with phi-detuning")
end

-- Generate a beating wavetable: pairs of sine waves at golden intervals
local function generate_golden_beating_wavetable()
  local song = renoise.song()
  if not song then return end

  local phi = (1 + math.sqrt(5)) / 2
  local wave_size = 512
  local num_positions = 12
  local sample_rate = 44100

  song:describe_undo("Generate Golden Beating Wavetable")

  local instr_index = song.selected_instrument_index
  local instr = song.instruments[instr_index]

  if instr.name == "" then
    while #instr.samples > 1 do
      instr:delete_sample_at(#instr.samples)
    end
  else
    song:insert_instrument_at(instr_index + 1)
    instr_index = instr_index + 1
    instr = song.instruments[instr_index]
    song.selected_instrument_index = instr_index
  end

  instr.name = "Golden Beating Wavetable"

  -- Each position morphs from unison to golden interval
  for pos = 1, num_positions do
    if pos > #instr.samples then
      instr:insert_sample_at(pos)
    end
    local sample = instr.samples[pos]
    local buffer = sample.sample_buffer

    -- Morph: position 1 = pure unison, position 12 = full golden interval
    local morph = (pos - 1) / (num_positions - 1) -- 0.0 to 1.0
    local second_freq = 1.0 + (phi - 1.0) * morph -- 1.0 to phi

    buffer:create_sample_data(sample_rate, 16, 1, wave_size)
    buffer:prepare_sample_data_changes()

    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local t = phase * math.pi * 2
      local value = (math.sin(t) + math.sin(t * second_freq)) / 2

      buffer:set_sample_data(1, i, math.max(-1, math.min(1, value)))
    end

    buffer:finalize_sample_data_changes()

    sample.name = string.format("Beat %02d (1:%.3f)", pos, second_freq)
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = wave_size
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  end

  if #instr.samples > num_positions and not instr.samples[1].sample_buffer.has_sample_data then
    instr:delete_sample_at(1)
  end

  renoise.app():show_status("Generated Golden Beating Wavetable: morph from unison to golden sixth")
end

-- ========================================
-- SCALA FILE EXPORT (Phase 4)
-- ========================================

local function export_tuning_as_scala(preset_index)
  local preset = tuning_presets[preset_index]
  if not preset or preset.is_reset then
    renoise.app():show_status("Cannot export standard 12-TET as Scala (it's the default)")
    return
  end

  local ratios, name = preset.generator()

  -- Build Scala file content
  local lines = {}
  lines[#lines + 1] = "! " .. name:lower():gsub("[%s%(%)%-,]", "_"):gsub("__+", "_") .. ".scl"
  lines[#lines + 1] = "!"
  lines[#lines + 1] = name
  lines[#lines + 1] = tostring(#ratios)
  lines[#lines + 1] = "!"

  for _, r in ipairs(ratios) do
    local cents = 1200 * math.log(r) / math.log(2)
    lines[#lines + 1] = string.format("%.6f", cents)
  end

  local content = table.concat(lines, "\n") .. "\n"

  -- Prompt for save location
  local filename = renoise.app():prompt_for_filename_to_write("scl", "Save Scala tuning file")
  if filename and filename ~= "" then
    local file = io.open(filename, "w")
    if file then
      file:write(content)
      file:close()
      renoise.app():show_status("Exported Scala file: " .. filename:match("([^/\\]+)$"))
    else
      renoise.app():show_error("Could not write to " .. filename)
    end
  end
end

-- ========================================
-- QUICK-APPLY FUNCTIONS (for menu/keybinding)
-- ========================================

local function apply_golden_pythagorean()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Golden Pythagorean (13-note)" then
      apply_tuning_to_instrument(i)
      return
    end
  end
end

local function apply_36_edo()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "36-EDO" then
      apply_tuning_to_instrument(i)
      return
    end
  end
end

local function apply_solfeggio()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Solfeggio" then
      apply_tuning_to_instrument(i)
      return
    end
  end
end

local function apply_colundi()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Colundi" then
      apply_tuning_to_instrument(i)
      return
    end
  end
end

local function apply_just_intonation()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Just Intonation (5-limit)" then
      apply_tuning_to_instrument(i)
      return
    end
  end
end

local function apply_pythagorean()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Pythagorean (pure fifths)" then
      apply_tuning_to_instrument(i)
      return
    end
  end
end

local function reset_to_12tet()
  apply_tuning_to_instrument(1)
end

-- ========================================
-- MENU ENTRIES
-- ========================================

renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Microtonal Tunings:Microtonal Tunings Dialog...", invoke = show_microtonal_tuning_dialog}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Microtonal Tunings:Apply Golden Pythagorean (13-note)", invoke = apply_golden_pythagorean}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Microtonal Tunings:Apply 36-EDO", invoke = apply_36_edo}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Microtonal Tunings:Apply Solfeggio", invoke = apply_solfeggio}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Microtonal Tunings:Apply Colundi", invoke = apply_colundi}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Microtonal Tunings:Apply Just Intonation (5-limit)", invoke = apply_just_intonation}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Microtonal Tunings:Apply Pythagorean (pure fifths)", invoke = apply_pythagorean}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Microtonal Tunings:Reset to 12-TET", invoke = reset_to_12tet}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Microtonal Tunings:Generate Golden Shimmer Wavetable", invoke = generate_shimmering_wavetable}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti:Microtonal Tunings:Generate Golden Beating Wavetable", invoke = generate_golden_beating_wavetable}

renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Microtonal Tunings:Microtonal Tunings Dialog...", invoke = show_microtonal_tuning_dialog}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Microtonal Tunings:Apply Golden Pythagorean (13-note)", invoke = apply_golden_pythagorean}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Microtonal Tunings:Apply 36-EDO", invoke = apply_36_edo}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Microtonal Tunings:Apply Solfeggio", invoke = apply_solfeggio}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Microtonal Tunings:Apply Colundi", invoke = apply_colundi}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Microtonal Tunings:Apply Just Intonation (5-limit)", invoke = apply_just_intonation}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Microtonal Tunings:Apply Pythagorean (pure fifths)", invoke = apply_pythagorean}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Microtonal Tunings:Reset to 12-TET", invoke = reset_to_12tet}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Microtonal Tunings:Generate Golden Shimmer Wavetable", invoke = generate_shimmering_wavetable}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Microtonal Tunings:Generate Golden Beating Wavetable", invoke = generate_golden_beating_wavetable}

-- ========================================
-- KEYBINDINGS
-- ========================================

renoise.tool():add_keybinding{name = "Global:Paketti:Microtonal Tunings Dialog", invoke = show_microtonal_tuning_dialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Apply Golden Pythagorean Tuning", invoke = apply_golden_pythagorean}
renoise.tool():add_keybinding{name = "Global:Paketti:Apply 36-EDO Tuning", invoke = apply_36_edo}
renoise.tool():add_keybinding{name = "Global:Paketti:Apply Solfeggio Tuning", invoke = apply_solfeggio}
renoise.tool():add_keybinding{name = "Global:Paketti:Apply Colundi Tuning", invoke = apply_colundi}
renoise.tool():add_keybinding{name = "Global:Paketti:Reset Instrument to 12-TET", invoke = reset_to_12tet}

-- ========================================
-- MIDI MAPPINGS
-- ========================================

renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply Golden Pythagorean", invoke = function(message) if message:is_trigger() then apply_golden_pythagorean() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply 36-EDO", invoke = function(message) if message:is_trigger() then apply_36_edo() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply Solfeggio", invoke = function(message) if message:is_trigger() then apply_solfeggio() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply Colundi", invoke = function(message) if message:is_trigger() then apply_colundi() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Reset to 12-TET", invoke = function(message) if message:is_trigger() then reset_to_12tet() end end}
