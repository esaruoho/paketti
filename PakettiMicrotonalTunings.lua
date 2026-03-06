-- Paketti Microtonal Tunings
-- Comprehensive microtonal system: tunings, golden waveforms, drones, binaural beats,
-- chord library, reharmonization, spectral morphing, sacred geometry, Colundi deep integration,
-- tuning comparison A/B, golden ratio tempo/rhythm, hardware export helpers

local microtonal_dialog = nil
local golden_chord_dialog = nil
local golden_tempo_dialog = nil
local tuning_ab_dialog = nil
local PHI = (1 + math.sqrt(5)) / 2

-- Shared key handler: close on configured close key, return focus to middle frame
local function microtonal_key_handler(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    return nil
  end
  return key
end

-- ========================================
-- TUNING GENERATORS
-- ========================================

local function generate_golden_pythagorean()
  local ratios = {}
  for n = 0, 12 do
    local r = PHI ^ n
    while r >= 2.0 do r = r / 2.0 end
    while r < 1.0 do r = r * 2.0 end
    ratios[#ratios + 1] = r
  end
  table.sort(ratios)
  local unique = {}
  for i, r in ipairs(ratios) do
    if i == 1 or math.abs(r - ratios[i - 1]) > 0.0001 then
      unique[#unique + 1] = r
    end
  end
  local result = {}
  for _, r in ipairs(unique) do
    if r > 1.0001 then
      result[#result + 1] = r
    end
  end
  if #result == 0 or math.abs(result[#result] - 2.0) > 0.001 then
    result[#result + 1] = 2.0
  end
  return result, "Golden Pythagorean (13-note)"
end

local function generate_n_edo(n)
  local ratios = {}
  for step = 1, n do
    ratios[#ratios + 1] = 2 ^ (step / n)
  end
  return ratios, n .. "-EDO"
end

local function generate_solfeggio()
  local freqs = {174, 285, 396, 417, 528, 639, 741, 852, 963}
  local base = freqs[1]
  local ratios = {}
  for i = 2, #freqs do
    local r = freqs[i] / base
    while r >= 2.0 do r = r / 2.0 end
    while r < 1.0 do r = r * 2.0 end
    if r > 1.0001 then
      ratios[#ratios + 1] = r
    end
  end
  table.sort(ratios)
  local unique = {}
  for i, r in ipairs(ratios) do
    if i == 1 or math.abs(r - ratios[i - 1]) > 0.001 then
      unique[#unique + 1] = r
    end
  end
  unique[#unique + 1] = 2.0
  return unique, "Solfeggio"
end

local function generate_colundi()
  local colundi_hz = {
    261.6256, 273.375, 286.6725, 298.6, 312.975, 327.35,
    340.15, 353.7, 370.0, 385.75, 401.5, 419.625,
  }
  local base = colundi_hz[1]
  local ratios = {}
  for i = 2, #colundi_hz do
    ratios[#ratios + 1] = colundi_hz[i] / base
  end
  ratios[#ratios + 1] = 2.0
  return ratios, "Colundi"
end

local function generate_werckmeister_iii()
  return {
    256/243, 1.117403, 32/27, 1.252827, 4/3, 1024/729,
    1.494927, 128/81, 1.670436, 16/9, 1.879241, 2/1
  }, "Werckmeister III (1691)"
end

local function generate_pythagorean()
  local ratios = {}
  local fifth = 3/2
  for n = -1, 10 do
    local r = fifth ^ n
    while r >= 2.0 do r = r / 2.0 end
    while r < 1.0 do r = r * 2.0 end
    ratios[#ratios + 1] = r
  end
  table.sort(ratios)
  local result = {}
  for _, r in ipairs(ratios) do
    if r > 1.0001 then result[#result + 1] = r end
  end
  if #result == 0 or math.abs(result[#result] - 2.0) > 0.001 then
    result[#result + 1] = 2.0
  end
  return result, "Pythagorean (pure fifths)"
end

local function generate_just_intonation()
  return {
    16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 5/3, 9/5, 15/8, 2/1
  }, "Just Intonation (5-limit)"
end

local function generate_kirnberger_iii()
  local ratios = {
    256/243,
    math.sqrt(3/2) * (2/3) * 2,
    32/27,
    5/4,
    4/3,
    1024/729,
    math.sqrt(3/2) * math.sqrt(3/2) * (4/9) * 4,
    128/81,
    math.sqrt(3/2) * math.sqrt(3/2) * math.sqrt(3/2) * (8/27) * 4,
    16/9,
    15/8,
    2/1
  }
  for i = 1, #ratios do
    if ratios[i] < 1.0 then ratios[i] = ratios[i] * 2.0 end
    if ratios[i] >= 2.0 and i < #ratios then ratios[i] = ratios[i] / 2.0 end
  end
  return ratios, "Kirnberger III (1779)"
end

local function generate_quarter_comma_meantone()
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
    if r > 1.0001 then result[#result + 1] = r end
  end
  if math.abs(result[#result] - 2.0) > 0.001 then
    result[#result + 1] = 2.0
  end
  return result, "Quarter-Comma Meantone"
end

-- Sacred Geometry generators
local function generate_pi_harmonic()
  local ratios = {}
  for n = 0, 11 do
    local r = math.pi ^ n
    while r >= 2.0 do r = r / 2.0 end
    while r < 1.0 do r = r * 2.0 end
    ratios[#ratios + 1] = r
  end
  table.sort(ratios)
  local result = {}
  for i, r in ipairs(ratios) do
    if r > 1.0001 and (i == 1 or math.abs(r - ratios[i-1]) > 0.001) then
      result[#result + 1] = r
    end
  end
  if #result == 0 or math.abs(result[#result] - 2.0) > 0.001 then
    result[#result + 1] = 2.0
  end
  return result, "Pi-Harmonic"
end

local function generate_e_harmonic()
  local ratios = {}
  for n = 0, 11 do
    local r = math.exp(1) ^ n
    while r >= 2.0 do r = r / 2.0 end
    while r < 1.0 do r = r * 2.0 end
    ratios[#ratios + 1] = r
  end
  table.sort(ratios)
  local result = {}
  for i, r in ipairs(ratios) do
    if r > 1.0001 and (i == 1 or math.abs(r - ratios[i-1]) > 0.001) then
      result[#result + 1] = r
    end
  end
  if #result == 0 or math.abs(result[#result] - 2.0) > 0.001 then
    result[#result + 1] = 2.0
  end
  return result, "Euler (e)-Harmonic"
end

local function generate_silver_ratio()
  local silver = 1 + math.sqrt(2) -- ≈ 2.4142
  local ratios = {}
  for n = 0, 12 do
    local r = silver ^ n
    while r >= 2.0 do r = r / 2.0 end
    while r < 1.0 do r = r * 2.0 end
    ratios[#ratios + 1] = r
  end
  table.sort(ratios)
  local result = {}
  for i, r in ipairs(ratios) do
    if r > 1.0001 and (i == 1 or math.abs(r - ratios[i-1]) > 0.001) then
      result[#result + 1] = r
    end
  end
  if #result == 0 or math.abs(result[#result] - 2.0) > 0.001 then
    result[#result + 1] = 2.0
  end
  return result, "Silver Ratio"
end

local function generate_sqrt2_harmonic()
  local root = math.sqrt(2)
  local ratios = {}
  for n = 0, 12 do
    local r = root ^ n
    while r >= 2.0 do r = r / 2.0 end
    while r < 1.0 do r = r * 2.0 end
    ratios[#ratios + 1] = r
  end
  table.sort(ratios)
  local result = {}
  for i, r in ipairs(ratios) do
    if r > 1.0001 and (i == 1 or math.abs(r - ratios[i-1]) > 0.001) then
      result[#result + 1] = r
    end
  end
  if #result == 0 or math.abs(result[#result] - 2.0) > 0.001 then
    result[#result + 1] = 2.0
  end
  return result, "Sqrt(2)-Harmonic (Tritone)"
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
  {name = "Pi-Harmonic", generator = generate_pi_harmonic},
  {name = "Euler (e)-Harmonic", generator = generate_e_harmonic},
  {name = "Silver Ratio", generator = generate_silver_ratio},
  {name = "Sqrt(2)-Harmonic (Tritone)", generator = generate_sqrt2_harmonic},
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
-- HELPERS
-- ========================================

local function ratio_to_cents(ratio)
  return 1200 * math.log(ratio) / math.log(2)
end

-- Helper to create or reuse instrument slot
local function prepare_instrument(name)
  local song = renoise.song()
  local instr_index = song.selected_instrument_index
  local instr = song.instruments[instr_index]
  if instr.name == "" and #instr.samples <= 1 and (#instr.samples == 0 or not instr.samples[1].sample_buffer.has_sample_data) then
    while #instr.samples > 1 do
      instr:delete_sample_at(#instr.samples)
    end
  else
    song:insert_instrument_at(instr_index + 1)
    instr_index = instr_index + 1
    instr = song.instruments[instr_index]
    song.selected_instrument_index = instr_index
  end
  instr.name = name
  return instr, instr_index
end

-- Helper to write a sine wave into a sample buffer
local function write_sine_buffer(buffer, wave_size, sample_rate, freq_ratio, amplitude)
  amplitude = amplitude or 1.0
  buffer:create_sample_data(sample_rate, 16, 1, wave_size)
  buffer:prepare_sample_data_changes()
  for i = 1, wave_size do
    local phase = (i - 1) / wave_size
    local value = math.sin(phase * math.pi * 2 * freq_ratio) * amplitude
    buffer:set_sample_data(1, i, math.max(-1, math.min(1, value)))
  end
  buffer:finalize_sample_data_changes()
end

-- Helper to write stereo buffer with two frequencies (for binaural)
local function write_stereo_sine_buffer(buffer, wave_size, sample_rate, freq_l, freq_r)
  buffer:create_sample_data(sample_rate, 16, 2, wave_size)
  buffer:prepare_sample_data_changes()
  for i = 1, wave_size do
    local phase = (i - 1) / wave_size
    local val_l = math.sin(phase * math.pi * 2 * freq_l)
    local val_r = math.sin(phase * math.pi * 2 * freq_r)
    buffer:set_sample_data(1, i, math.max(-1, math.min(1, val_l)))
    buffer:set_sample_data(2, i, math.max(-1, math.min(1, val_r)))
  end
  buffer:finalize_sample_data_changes()
end

-- Helper to write additive synthesis buffer
local function write_additive_buffer(buffer, wave_size, sample_rate, partial_ratios, partial_amps)
  buffer:create_sample_data(sample_rate, 16, 1, wave_size)
  buffer:prepare_sample_data_changes()
  for i = 1, wave_size do
    local phase = (i - 1) / wave_size
    local t = phase * math.pi * 2
    local value = 0
    local amp_sum = 0
    for p = 1, #partial_ratios do
      local amp = partial_amps[p] or (1 / p)
      value = value + math.sin(t * partial_ratios[p]) * amp
      amp_sum = amp_sum + math.abs(amp)
    end
    if amp_sum > 0 then value = value / amp_sum end
    buffer:set_sample_data(1, i, math.max(-1, math.min(1, value)))
  end
  buffer:finalize_sample_data_changes()
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
  renoise.app():show_status("Applied " .. name .. " (" .. #ratios .. " notes/octave) to " .. instr.name)
end

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
-- SHIMMERING WAVETABLE GENERATORS
-- ========================================

local function generate_shimmering_wavetable()
  local song = renoise.song()
  if not song then return end
  local wave_size = 512
  local num_positions = 12
  local sample_rate = 44100

  song:describe_undo("Generate Golden Shimmering Wavetable")
  local instr = prepare_instrument("Golden Shimmer Wavetable")

  for pos = 1, num_positions do
    if pos > #instr.samples then instr:insert_sample_at(pos) end
    local sample = instr.samples[pos]
    local detune_cents = (pos - 1) * PHI
    local detune_ratio = 2 ^ (detune_cents / 1200)
    local num_partials = math.floor(pos / 2) + 1

    local partials = {}
    local amps = {}
    for p = 0, num_partials - 1 do
      partials[#partials + 1] = PHI ^ p * detune_ratio
      amps[#amps + 1] = 1 / (p + 1)
    end

    write_additive_buffer(sample.sample_buffer, wave_size, sample_rate, partials, amps)
    sample.name = string.format("Shimmer %02d (+%.1fc, %dp)", pos, detune_cents, num_partials)
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = wave_size
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  end

  if #instr.samples > num_positions and not instr.samples[1].sample_buffer.has_sample_data then
    instr:delete_sample_at(1)
  end
  renoise.app():show_status("Generated Golden Shimmer Wavetable: " .. num_positions .. " positions")
end

local function generate_golden_beating_wavetable()
  local song = renoise.song()
  if not song then return end
  local wave_size = 512
  local num_positions = 12
  local sample_rate = 44100

  song:describe_undo("Generate Golden Beating Wavetable")
  local instr = prepare_instrument("Golden Beating Wavetable")

  for pos = 1, num_positions do
    if pos > #instr.samples then instr:insert_sample_at(pos) end
    local sample = instr.samples[pos]
    local morph = (pos - 1) / (num_positions - 1)
    local second_freq = 1.0 + (PHI - 1.0) * morph

    write_additive_buffer(sample.sample_buffer, wave_size, sample_rate, {1.0, second_freq}, {0.5, 0.5})
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

-- Spectral morphing: Just Intonation chord → Golden chord across 12 positions
local function generate_spectral_morph_wavetable()
  local song = renoise.song()
  if not song then return end
  local wave_size = 512
  local num_positions = 12
  local sample_rate = 44100

  song:describe_undo("Generate Spectral Morph Wavetable")
  local instr = prepare_instrument("Spectral Morph JI-to-Golden")

  -- JI major triad: 1, 5/4, 3/2
  local ji_third = 5/4
  local ji_fifth = 3/2
  -- Golden triad: 1, 2/phi, phi (reduced to octave)
  local golden_third = 2 / PHI
  local golden_fifth = PHI
  while golden_fifth >= 2.0 do golden_fifth = golden_fifth / 2.0 end

  for pos = 1, num_positions do
    if pos > #instr.samples then instr:insert_sample_at(pos) end
    local sample = instr.samples[pos]
    local morph = (pos - 1) / (num_positions - 1)

    local third = ji_third + (golden_third - ji_third) * morph
    local fifth = ji_fifth + (golden_fifth - ji_fifth) * morph

    write_additive_buffer(sample.sample_buffer, wave_size, sample_rate,
      {1.0, third, fifth}, {0.4, 0.3, 0.3})
    sample.name = string.format("Morph %02d (3rd:%.3f 5th:%.3f)", pos, third, fifth)
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = wave_size
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  end

  if #instr.samples > num_positions and not instr.samples[1].sample_buffer.has_sample_data then
    instr:delete_sample_at(1)
  end
  renoise.app():show_status("Generated Spectral Morph: Just Intonation to Golden Triad")
end

-- History of tuning as wavetable: Pythagorean → Werckmeister → 12-TET → Golden
local function generate_tuning_history_wavetable()
  local song = renoise.song()
  if not song then return end
  local wave_size = 512
  local sample_rate = 44100

  song:describe_undo("Generate Tuning History Wavetable")
  local instr = prepare_instrument("Tuning History Wavetable")

  -- Major triads in each tuning system (root, third, fifth as ratios)
  local tunings = {
    {name = "Pythagorean",    third = 81/64,   fifth = 3/2},
    {name = "Werckmeister",   third = 1.252827, fifth = 1.494927},
    {name = "Meantone",       third = 5/4,     fifth = 5^(1/4)},
    {name = "Just",           third = 5/4,     fifth = 3/2},
    {name = "Kirnberger",     third = 5/4,     fifth = 1.4953},
    {name = "12-TET",         third = 2^(4/12), fifth = 2^(7/12)},
    {name = "24-TET",         third = 2^(8/24), fifth = 2^(14/24)},
    {name = "Golden 3rd",     third = 2/PHI,   fifth = 3/2},
    {name = "Golden 5th",     third = 5/4,     fifth = PHI / 2 * 2}, -- reduced
    {name = "Golden Triad",   third = 2/PHI,   fifth = PHI},
    {name = "36-TET approx",  third = 2^(12/36), fifth = 2^(21/36)},
    {name = "Full Golden",    third = 2/PHI,   fifth = PHI},
  }

  -- Reduce fifths to octave
  for _, t in ipairs(tunings) do
    while t.fifth >= 2.0 do t.fifth = t.fifth / 2.0 end
    while t.third >= 2.0 do t.third = t.third / 2.0 end
  end

  for pos = 1, #tunings do
    if pos > #instr.samples then instr:insert_sample_at(pos) end
    local sample = instr.samples[pos]
    local t = tunings[pos]

    write_additive_buffer(sample.sample_buffer, wave_size, sample_rate,
      {1.0, t.third, t.fifth}, {0.4, 0.3, 0.3})
    sample.name = string.format("%02d %s", pos, t.name)
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = wave_size
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  end

  if #instr.samples > #tunings and not instr.samples[1].sample_buffer.has_sample_data then
    instr:delete_sample_at(1)
  end
  renoise.app():show_status("Generated Tuning History Wavetable: " .. #tunings .. " tuning systems")
end

-- ========================================
-- DRONE GENERATOR
-- ========================================

local function generate_golden_drone()
  local song = renoise.song()
  if not song then return end
  local sample_rate = 44100
  local drone_length = sample_rate * 4 -- 4 seconds
  local num_drones = 7 -- root + 6 golden scale degrees

  song:describe_undo("Generate Golden Drone Instrument")
  local instr = prepare_instrument("Golden Drone Pad")

  -- Get golden scale degrees (first 7 including root)
  local golden_ratios = {1.0}
  local all_ratios, _ = generate_golden_pythagorean()
  for i = 1, math.min(6, #all_ratios) do
    golden_ratios[#golden_ratios + 1] = all_ratios[i]
  end

  for pos = 1, num_drones do
    if pos > #instr.samples then instr:insert_sample_at(pos) end
    local sample = instr.samples[pos]
    local buffer = sample.sample_buffer
    local base_ratio = golden_ratios[pos]

    -- Generate rich drone: base + golden partials with slow amplitude modulation
    buffer:create_sample_data(sample_rate, 16, 1, drone_length)
    buffer:prepare_sample_data_changes()

    for i = 1, drone_length do
      local t = (i - 1) / sample_rate
      local phase = t * math.pi * 2
      local value = 0

      -- Base tone + 4 golden partials with decreasing amplitude
      for p = 0, 4 do
        local freq = base_ratio * (PHI ^ p)
        local amp = 1 / ((p + 1) * 1.5)
        -- Slow amplitude modulation at different rates for organic movement
        local mod = 1.0 + 0.15 * math.sin(t * (0.3 + p * 0.17) * math.pi * 2)
        value = value + math.sin(phase * freq) * amp * mod
      end

      -- Normalize
      value = value / 2.5
      buffer:set_sample_data(1, i, math.max(-1, math.min(1, value)))
    end

    buffer:finalize_sample_data_changes()

    local cents = ratio_to_cents(base_ratio)
    sample.name = string.format("Drone %d (%.1fc)", pos, cents)
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = sample_rate -- loop after 1 second (skip attack)
    sample.loop_end = drone_length
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  end

  if #instr.samples > num_drones and not instr.samples[1].sample_buffer.has_sample_data then
    instr:delete_sample_at(1)
  end

  -- Apply golden tuning to the drone instrument
  instr.trigger_options.tuning = all_ratios
  instr.trigger_options.tuning_name = "Golden Pythagorean (13-note)"

  renoise.app():show_status("Generated Golden Drone Pad: " .. num_drones .. " drones with golden partials + tuning applied")
end

-- ========================================
-- BINAURAL BEAT GENERATOR
-- ========================================

local function generate_binaural_instrument()
  local song = renoise.song()
  if not song then return end
  local sample_rate = 44100
  local wave_size = sample_rate * 2 -- 2 seconds per note

  song:describe_undo("Generate Golden Binaural Instrument")
  local instr = prepare_instrument("Golden Binaural Beats")

  -- Generate binaural beats across 12 notes
  -- Each note: left channel = base freq, right channel = base freq * golden ratio offset
  local base_freqs = {
    130.81, -- C3
    146.83, -- D3
    164.81, -- E3
    174.61, -- F3
    196.00, -- G3
    220.00, -- A3
    246.94, -- B3
    261.63, -- C4
    293.66, -- D4
    329.63, -- E4
    349.23, -- F4
    392.00, -- G4
  }

  for pos = 1, #base_freqs do
    if pos > #instr.samples then instr:insert_sample_at(pos) end
    local sample = instr.samples[pos]
    local buffer = sample.sample_buffer
    local base_hz = base_freqs[pos]
    -- Right channel offset by golden ratio of the beat frequency
    -- Beat frequency = base * (phi - 1) * 0.01 ≈ 0.618% of base
    -- This creates a ~1-4 Hz binaural beat (theta/delta range for meditation)
    local beat_hz = base_hz * (PHI - 1) * 0.01
    local right_hz = base_hz + beat_hz

    buffer:create_sample_data(sample_rate, 16, 2, wave_size)
    buffer:prepare_sample_data_changes()

    for i = 1, wave_size do
      local t = (i - 1) / sample_rate
      local val_l = math.sin(t * base_hz * math.pi * 2)
      local val_r = math.sin(t * right_hz * math.pi * 2)
      buffer:set_sample_data(1, i, val_l)
      buffer:set_sample_data(2, i, val_r)
    end

    buffer:finalize_sample_data_changes()

    local note_names = {"C3","D3","E3","F3","G3","A3","B3","C4","D4","E4","F4","G4"}
    sample.name = string.format("Binaural %s (%.1f/%.1f Hz, beat:%.2f Hz)",
      note_names[pos], base_hz, right_hz, beat_hz)
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = wave_size
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  end

  if #instr.samples > #base_freqs and not instr.samples[1].sample_buffer.has_sample_data then
    instr:delete_sample_at(1)
  end
  renoise.app():show_status("Generated Golden Binaural Beats: " .. #base_freqs .. " stereo samples with phi-ratio beating")
end

-- ========================================
-- COLUNDI DEEP INTEGRATION (128 frequencies)
-- ========================================

local function generate_colundi_full_instrument()
  local song = renoise.song()
  if not song then return end
  local sample_rate = 44100
  local wave_size = 2048 -- longer single-cycle for lower frequencies

  song:describe_undo("Generate Full Colundi Instrument (128 frequencies)")
  local instr = prepare_instrument("Colundi Full (128 freq)")

  -- Colundi sequence: 128 frequencies across ~11 octaves
  -- Base octave frequencies, then extended by octave doubling/halving
  local colundi_base = {
    261.6256, 273.375, 286.6725, 298.6, 312.975, 327.35,
    340.15, 353.7, 370.0, 385.75, 401.5, 419.625,
  }

  -- Generate full 128 frequencies by extending across octaves
  local all_freqs = {}
  -- 5 octaves below to 5 octaves above the base, pick the first 128
  for oct = -5, 5 do
    for _, freq in ipairs(colundi_base) do
      local f = freq * (2 ^ oct)
      if f >= 20 and f <= 20000 then
        all_freqs[#all_freqs + 1] = f
      end
    end
  end
  table.sort(all_freqs)
  -- Trim to 128
  while #all_freqs > 128 do
    all_freqs[#all_freqs] = nil
  end

  for pos = 1, #all_freqs do
    if pos > #instr.samples then instr:insert_sample_at(pos) end
    local sample = instr.samples[pos]
    local freq = all_freqs[pos]

    -- Generate sine at the exact Colundi frequency
    -- Cycles per buffer = freq * wave_size / sample_rate
    local cycles = freq * wave_size / sample_rate
    write_sine_buffer(sample.sample_buffer, wave_size, sample_rate, cycles)

    sample.name = string.format("Colundi %03d (%.2f Hz)", pos, freq)
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = wave_size
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  end

  if #instr.samples > #all_freqs and not instr.samples[1].sample_buffer.has_sample_data then
    instr:delete_sample_at(1)
  end

  -- Apply Colundi tuning
  local colundi_ratios, colundi_name = generate_colundi()
  instr.trigger_options.tuning = colundi_ratios
  instr.trigger_options.tuning_name = colundi_name

  renoise.app():show_status("Generated Full Colundi Instrument: " .. #all_freqs .. " frequencies with Colundi tuning")
end

-- ========================================
-- SACRED GEOMETRY WAVEFORMS
-- ========================================

local function generate_sacred_geometry_wavetable()
  local song = renoise.song()
  if not song then return end
  local wave_size = 512
  local sample_rate = 44100

  song:describe_undo("Generate Sacred Geometry Wavetable")
  local instr = prepare_instrument("Sacred Geometry Wavetable")

  -- Each position uses a different irrational number as the harmonic generator
  local generators = {
    {name = "Phi (Golden)",  base = PHI,           partials = 6},
    {name = "Pi",            base = math.pi,       partials = 5},
    {name = "e (Euler)",     base = math.exp(1),   partials = 5},
    {name = "Sqrt(2)",       base = math.sqrt(2),  partials = 6},
    {name = "Silver Ratio",  base = 1+math.sqrt(2), partials = 5},
    {name = "Sqrt(3)",       base = math.sqrt(3),  partials = 5},
    {name = "Sqrt(5)",       base = math.sqrt(5),  partials = 5},
    {name = "Phi^2",         base = PHI*PHI,       partials = 5},
    {name = "Ln(2)",         base = math.log(2),   partials = 6},
    {name = "Phi/Pi",        base = PHI/math.pi,   partials = 6},
    {name = "e/Phi",         base = math.exp(1)/PHI, partials = 6},
    {name = "Pi*Phi",        base = math.pi*PHI,   partials = 4},
  }

  for pos = 1, #generators do
    if pos > #instr.samples then instr:insert_sample_at(pos) end
    local sample = instr.samples[pos]
    local gen = generators[pos]

    local partials = {}
    local amps = {}
    for p = 0, gen.partials - 1 do
      partials[#partials + 1] = gen.base ^ p
      amps[#amps + 1] = 1 / (p + 1)
    end

    write_additive_buffer(sample.sample_buffer, wave_size, sample_rate, partials, amps)
    sample.name = string.format("%02d %s", pos, gen.name)
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = wave_size
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  end

  if #instr.samples > #generators and not instr.samples[1].sample_buffer.has_sample_data then
    instr:delete_sample_at(1)
  end
  renoise.app():show_status("Generated Sacred Geometry Wavetable: " .. #generators .. " irrational generators")
end

-- ========================================
-- TUNING COMPARISON A/B
-- ========================================

local function tuning_comparison_ab()
  local song = renoise.song()
  if not song then return end

  local instr = song.selected_instrument
  if not instr then
    renoise.app():show_status("No instrument selected")
    return
  end

  -- Duplicate the instrument
  local src_index = song.selected_instrument_index
  song:insert_instrument_at(src_index + 1)
  local dst = song.instruments[src_index + 1]

  -- Copy samples from source to destination
  local src = song.instruments[src_index]
  for s = 1, #src.samples do
    if s > #dst.samples then dst:insert_sample_at(s) end
    dst.samples[s]:copy_from(src.samples[s])
  end
  dst.name = src.name .. " (B)"

  -- Show dialog to pick tunings
  local vb = renoise.ViewBuilder()
  local popup_items = {}
  for _, preset in ipairs(tuning_presets) do
    popup_items[#popup_items + 1] = preset.name
  end

  local content = vb:column{
    margin = 10,
    spacing = 5,
    vb:text{text = "Tuning Comparison A/B", style = "strong", font = "bold"},
    vb:text{text = "Instrument A: " .. src.name},
    vb:row{
      vb:text{text = "Tuning A:", width = 60},
      vb:popup{id = "tuning_a", items = popup_items, value = 1, width = 250},
    },
    vb:text{text = "Instrument B: " .. dst.name},
    vb:row{
      vb:text{text = "Tuning B:", width = 60},
      vb:popup{id = "tuning_b", items = popup_items, value = 2, width = 250},
    },
    vb:row{
      spacing = 5,
      vb:button{
        text = "Apply Both",
        width = 120,
        notifier = function()
          apply_tuning_to_instrument(vb.views.tuning_a.value, src_index)
          apply_tuning_to_instrument(vb.views.tuning_b.value, src_index + 1)
          renoise.app():show_status("Applied tuning A to " .. src.name .. ", tuning B to " .. dst.name .. ". Switch instruments to compare.")
        end
      },
      vb:button{
        text = "Select A",
        width = 80,
        notifier = function()
          song.selected_instrument_index = src_index
        end
      },
      vb:button{
        text = "Select B",
        width = 80,
        notifier = function()
          song.selected_instrument_index = src_index + 1
        end
      },
    },
  }

  tuning_ab_dialog = renoise.app():show_custom_dialog("Tuning Comparison A/B", content, microtonal_key_handler)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- ========================================
-- GOLDEN CHORD LIBRARY (Phase 5)
-- ========================================

local function get_golden_chords()
  local golden_third = 2 / PHI  -- ≈ 1.236 (≈ 366.91 cents)
  local golden_fifth_raw = PHI
  local golden_fifth = golden_fifth_raw
  while golden_fifth >= 2.0 do golden_fifth = golden_fifth / 2.0 end

  return {
    {name = "Golden Major",      notes = {0, ratio_to_cents(golden_third), ratio_to_cents(golden_fifth)}},
    {name = "Golden Minor",      notes = {0, ratio_to_cents(2.0 - golden_third), ratio_to_cents(golden_fifth)}},
    {name = "Golden Power",      notes = {0, ratio_to_cents(golden_fifth)}},
    {name = "Golden Sixth",      notes = {0, ratio_to_cents(golden_third), ratio_to_cents(golden_fifth), ratio_to_cents(PHI)}},
    {name = "Golden Sus",        notes = {0, ratio_to_cents(golden_fifth / golden_third), ratio_to_cents(golden_fifth)}},
    {name = "Golden Stacked 3rds", notes = {0, ratio_to_cents(golden_third), ratio_to_cents(golden_third * golden_third)}},
  }
end

local function insert_golden_chord(chord_index, root_note)
  local song = renoise.song()
  if not song then return end
  local chords = get_golden_chords()
  local chord = chords[chord_index]
  if not chord then return end

  root_note = root_note or song.selected_line.note_columns[1].note_value
  if root_note == 121 then root_note = 48 end -- default to C-4 if empty

  song:describe_undo("Insert Golden Chord: " .. chord.name)

  local line = song.selected_line
  local track = song.selected_track
  local instr_idx = song.selected_instrument_index - 1

  -- Ensure enough note columns
  local needed = #chord.notes
  if track.visible_note_columns < needed then
    track.visible_note_columns = needed
  end

  for i, cents in ipairs(chord.notes) do
    if i <= #line.note_columns then
      local semitones = cents / 100
      local note = root_note + math.floor(semitones + 0.5)
      note = math.max(0, math.min(119, note))
      line.note_columns[i].note_value = note
      line.note_columns[i].instrument_value = instr_idx
    end
  end

  renoise.app():show_status("Inserted " .. chord.name .. " from note " .. root_note)
end

local function show_golden_chord_dialog()
  local vb = renoise.ViewBuilder()
  local chords = get_golden_chords()
  local chord_names = {}
  for _, c in ipairs(chords) do
    chord_names[#chord_names + 1] = c.name
  end

  local content = vb:column{
    margin = 10,
    spacing = 5,
    vb:text{text = "Golden Chord Library", style = "strong", font = "bold"},
    vb:text{text = "Insert golden-ratio chords at cursor position"},
    vb:row{
      vb:text{text = "Chord:", width = 50},
      vb:popup{id = "chord_select", items = chord_names, value = 1, width = 200},
    },
    vb:row{
      vb:text{text = "Root:", width = 50},
      vb:valuebox{id = "root_note", min = 0, max = 119, value = 48, width = 60},
    },
    vb:row{
      spacing = 5,
      vb:button{
        text = "Insert at Cursor",
        width = 120,
        notifier = function()
          insert_golden_chord(vb.views.chord_select.value, vb.views.root_note.value)
        end
      },
      vb:button{
        text = "Insert All on Successive Lines",
        width = 180,
        notifier = function()
          local song = renoise.song()
          if not song then return end
          song:describe_undo("Insert All Golden Chords")
          local start_line = song.selected_line_index
          local pattern = song.selected_pattern
          for i = 1, #chords do
            local line_idx = start_line + (i - 1)
            if line_idx <= pattern.number_of_lines then
              local track_idx = song.selected_track_index
              local line = pattern:track(track_idx):line(line_idx)
              local root = vb.views.root_note.value
              local chord = chords[i]
              local track = song.selected_track
              if track.visible_note_columns < #chord.notes then
                track.visible_note_columns = #chord.notes
              end
              for j, cents in ipairs(chord.notes) do
                if j <= #line.note_columns then
                  local semitones = cents / 100
                  local note = root + math.floor(semitones + 0.5)
                  note = math.max(0, math.min(119, note))
                  line.note_columns[j].note_value = note
                  line.note_columns[j].instrument_value = song.selected_instrument_index - 1
                end
              end
            end
          end
          renoise.app():show_status("Inserted " .. #chords .. " golden chords")
        end
      },
    },
  }

  golden_chord_dialog = renoise.app():show_custom_dialog("Paketti Golden Chord Library", content, microtonal_key_handler)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- ========================================
-- GOLDEN RATIO TEMPO/RHYTHM
-- ========================================

local function apply_golden_tempo_relationship()
  local song = renoise.song()
  if not song then return end

  local current_bpm = song.transport.bpm
  local golden_bpm = math.floor(current_bpm * PHI + 0.5)
  local inverse_golden_bpm = math.floor(current_bpm / PHI + 0.5)

  -- Clamp to valid BPM range
  golden_bpm = math.max(32, math.min(999, golden_bpm))
  inverse_golden_bpm = math.max(32, math.min(999, inverse_golden_bpm))

  local vb = renoise.ViewBuilder()
  local content = vb:column{
    margin = 10,
    spacing = 5,
    vb:text{text = "Golden Ratio Tempo", style = "strong", font = "bold"},
    vb:text{text = string.format("Current BPM: %d", current_bpm)},
    vb:text{text = string.format("BPM x Phi: %d (%.2f)", golden_bpm, current_bpm * PHI)},
    vb:text{text = string.format("BPM / Phi: %d (%.2f)", inverse_golden_bpm, current_bpm / PHI)},
    vb:space{height = 5},
    vb:text{text = "Golden pattern lengths (current LPB=" .. song.transport.lpb .. "):"},
    vb:text{text = string.format("  64 lines / phi = %.1f -> 40 lines", 64 / PHI)},
    vb:text{text = string.format("  128 lines / phi = %.1f -> 79 lines", 128 / PHI)},
    vb:text{text = string.format("  32 lines / phi = %.1f -> 20 lines", 32 / PHI)},
    vb:space{height = 5},
    vb:row{
      spacing = 5,
      vb:button{
        text = "Set BPM x Phi (" .. golden_bpm .. ")",
        width = 160,
        notifier = function()
          song:describe_undo("Set Golden BPM (x Phi)")
          song.transport.bpm = golden_bpm
          renoise.app():show_status("BPM set to " .. golden_bpm .. " (x Phi)")
        end
      },
      vb:button{
        text = "Set BPM / Phi (" .. inverse_golden_bpm .. ")",
        width = 160,
        notifier = function()
          song:describe_undo("Set Golden BPM (/ Phi)")
          song.transport.bpm = inverse_golden_bpm
          renoise.app():show_status("BPM set to " .. inverse_golden_bpm .. " (/ Phi)")
        end
      },
    },
    vb:row{
      spacing = 5,
      vb:button{
        text = "Set Pattern to 40 lines",
        width = 160,
        notifier = function()
          song:describe_undo("Set Golden Pattern Length 40")
          song.selected_pattern.number_of_lines = 40
          renoise.app():show_status("Pattern length set to 40 (64/phi)")
        end
      },
      vb:button{
        text = "Set Pattern to 79 lines",
        width = 160,
        notifier = function()
          song:describe_undo("Set Golden Pattern Length 79")
          song.selected_pattern.number_of_lines = 79
          renoise.app():show_status("Pattern length set to 79 (128/phi)")
        end
      },
    },
    vb:row{
      spacing = 5,
      vb:button{
        text = "Write Golden Delays to Pattern",
        width = 200,
        tooltip = "Write golden-ratio delay values to every note in the selected track",
        notifier = function()
          song:describe_undo("Write Golden Delay Values")
          local pattern = song.selected_pattern
          local track_idx = song.selected_track_index
          local track_pattern = pattern:track(track_idx)
          local count = 0
          for line_idx = 1, pattern.number_of_lines do
            local line = track_pattern:line(line_idx)
            for col_idx = 1, #line.note_columns do
              local col = line.note_columns[col_idx]
              if col.note_value ~= 121 and col.note_value ~= 120 then
                -- Golden delay: position within the line based on golden ratio subdivision
                -- Alternate between phi-based subdivisions
                local golden_delay = math.floor(256 / PHI * ((count % 3) + 1) / 3) % 256
                col.delay_value = golden_delay
                count = count + 1
              end
            end
          end
          song.selected_track.delay_column_visible = true
          renoise.app():show_status("Wrote golden delay values to " .. count .. " notes")
        end
      },
    },
  }

  golden_tempo_dialog = renoise.app():show_custom_dialog("Paketti Golden Ratio Tempo/Rhythm", content, microtonal_key_handler)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- ========================================
-- PHRASE-BASED MICROTONAL ARPEGGIOS
-- ========================================

local function generate_golden_arpeggio_phrases()
  local song = renoise.song()
  if not song then return end
  local instr = song.selected_instrument
  if not instr then
    renoise.app():show_status("No instrument selected")
    return
  end

  song:describe_undo("Generate Golden Arpeggio Phrases")

  -- Golden scale degrees as semitone approximations (for pattern note values)
  local golden_ratios, _ = generate_golden_pythagorean()
  local golden_semitones = {0} -- root
  for _, r in ipairs(golden_ratios) do
    golden_semitones[#golden_semitones + 1] = math.floor(ratio_to_cents(r) / 100 + 0.5)
  end

  -- Arpeggio patterns to generate
  local arp_patterns = {
    {name = "Golden Triad Up",    degrees = {1, 4, 8, 4},       lpb = 8, lines = 4},
    {name = "Golden Triad Down",  degrees = {8, 4, 1, 4},       lpb = 8, lines = 4},
    {name = "Golden Scale Up",    degrees = {1,2,3,4,5,6,7,8},  lpb = 8, lines = 8},
    {name = "Golden Scale Down",  degrees = {8,7,6,5,4,3,2,1},  lpb = 8, lines = 8},
    {name = "Golden Penta",       degrees = {1,3,5,8,10,8,5,3}, lpb = 8, lines = 8},
    {name = "Golden Shimmer",     degrees = {1,8,4,8,1,5,8,5},  lpb = 8, lines = 8},
  }

  for p_idx, arp in ipairs(arp_patterns) do
    -- Create phrase if needed
    while #instr.phrases < p_idx do
      instr:insert_phrase_at(#instr.phrases + 1)
    end
    local phrase = instr.phrases[p_idx]
    phrase.name = arp.name
    phrase.number_of_lines = arp.lines
    phrase.lpb = arp.lpb
    phrase.looping = true

    -- Write notes
    for line_idx, degree in ipairs(arp.degrees) do
      if line_idx <= arp.lines then
        local line = phrase:line(line_idx)
        local semitone = golden_semitones[degree] or 0
        local note = 48 + semitone -- C-4 as root
        note = math.max(0, math.min(119, note))
        line.note_columns[1].note_value = note
        line.note_columns[1].instrument_value = 0 -- phrase-relative
      end
    end
  end

  renoise.app():show_status("Generated " .. #arp_patterns .. " golden arpeggio phrases for " .. instr.name)
end

-- ========================================
-- SCALA FILE EXPORT
-- ========================================

local function export_tuning_as_scala(preset_index)
  local preset = tuning_presets[preset_index]
  if not preset or preset.is_reset then
    renoise.app():show_status("Cannot export standard 12-TET as Scala (it's the default)")
    return
  end
  local ratios, name = preset.generator()
  local lines = {}
  lines[#lines + 1] = "! " .. name:lower():gsub("[%s%(%)%-,]", "_"):gsub("__+", "_") .. ".scl"
  lines[#lines + 1] = "!"
  lines[#lines + 1] = name
  lines[#lines + 1] = tostring(#ratios)
  lines[#lines + 1] = "!"
  for _, r in ipairs(ratios) do
    lines[#lines + 1] = string.format("%.6f", 1200 * math.log(r) / math.log(2))
  end
  local content = table.concat(lines, "\n") .. "\n"
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
-- MAIN DIALOG
-- ========================================

local function show_microtonal_tuning_dialog()
  if microtonal_dialog and microtonal_dialog.visible then
    microtonal_dialog:close()
  end

  local vb = renoise.ViewBuilder()

  local popup_items = {}
  for _, preset in ipairs(tuning_presets) do
    popup_items[#popup_items + 1] = preset.name
  end

  local current_index = 1
  local song = renoise.song()
  if song and song.selected_instrument then
    local current_name = song.selected_instrument.trigger_options.tuning_name
    local current_tuning = song.selected_instrument.trigger_options.tuning
    if not current_name or current_name == "" then
      if #current_tuning == 0 then current_index = 1 end
    else
      for i, preset in ipairs(tuning_presets) do
        if preset.name == current_name or current_name:find(preset.name, 1, true) then
          current_index = i
          break
        end
      end
    end
  end

  local function get_scale_info(preset_index)
    local preset = tuning_presets[preset_index]
    if not preset then return "No preset selected" end
    if preset.is_reset then return "Standard 12-TET equal temperament (12 notes, 100 cents each)" end
    local ratios, name = preset.generator()
    local lines = {name .. " -- " .. #ratios .. " notes per octave", ""}
    lines[#lines + 1] = string.format("  %-6s  %-12s  %s", "Deg", "Ratio", "Cents")
    lines[#lines + 1] = string.format("  %-6s  %-12s  %s", "---", "-----", "-----")
    lines[#lines + 1] = string.format("  %-6s  %-12s  %s", "0", "1/1", "0.00")
    for i, r in ipairs(ratios) do
      lines[#lines + 1] = string.format("  %-6d  %-12.6f  %.2f", i, r, ratio_to_cents(r))
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
      width = 500,
      height = 250,
      font = "mono",
    },

    vb:text{text = "Apply Tuning", style = "strong"},
    vb:row{
      spacing = 5,
      vb:button{text = "Apply to Selected Instrument", width = 180,
        notifier = function() apply_tuning_to_instrument(vb.views.microtonal_preset_popup.value) end},
      vb:button{text = "Apply to All Instruments", width = 160,
        notifier = function()
          if renoise.app():show_prompt("Apply to All", "Apply this tuning to ALL instruments?", {"OK","Cancel"}) == "OK" then
            apply_tuning_to_all_instruments(vb.views.microtonal_preset_popup.value)
          end
        end},
      vb:button{text = "Reset to 12-TET", width = 100,
        notifier = function()
          apply_tuning_to_instrument(1)
          vb.views.microtonal_preset_popup.value = 1
          vb.views.microtonal_info.text = get_scale_info(1)
        end},
    },

    vb:text{text = "Scala Files", style = "strong"},
    vb:row{
      spacing = 5,
      vb:button{text = "Load Scala (.scl)...", width = 140,
        notifier = function()
          local filename = renoise.app():prompt_for_filename_to_read({"scl"}, "Select Scala tuning file")
          if filename and filename ~= "" then
            local instr = renoise.song().selected_instrument
            if instr then
              renoise.song():describe_undo("Load Scala Tuning")
              local success = instr.trigger_options:load_tuning(filename)
              if success then
                renoise.app():show_status("Loaded: " .. filename:match("([^/\\]+)$"))
                vb.views.microtonal_info.text = "Loaded: " .. filename:match("([^/\\]+)$") .. "\nName: " .. (instr.trigger_options.tuning_name or "")
              end
            end
          end
        end},
      vb:button{text = "Export as Scala (.scl)...", width = 150,
        notifier = function() export_tuning_as_scala(vb.views.microtonal_preset_popup.value) end},
    },

    vb:text{text = "Wavetable Generators", style = "strong"},
    vb:row{
      spacing = 5,
      vb:button{text = "Golden Shimmer", width = 100, tooltip = "12-pos phi-detuned partials",
        notifier = generate_shimmering_wavetable},
      vb:button{text = "Golden Beating", width = 100, tooltip = "12-pos unison to golden sixth",
        notifier = generate_golden_beating_wavetable},
      vb:button{text = "Spectral Morph", width = 100, tooltip = "JI triad to Golden triad",
        notifier = generate_spectral_morph_wavetable},
      vb:button{text = "Tuning History", width = 100, tooltip = "Pythagorean to Golden as wavetable",
        notifier = generate_tuning_history_wavetable},
      vb:button{text = "Sacred Geometry", width = 100, tooltip = "12 irrational generators",
        notifier = generate_sacred_geometry_wavetable},
    },

    vb:text{text = "Instrument Generators", style = "strong"},
    vb:row{
      spacing = 5,
      vb:button{text = "Golden Drone Pad", width = 110, tooltip = "7 drones with golden partials + LFO modulation",
        notifier = generate_golden_drone},
      vb:button{text = "Binaural Beats", width = 100, tooltip = "12 stereo notes with golden-ratio binaural beating",
        notifier = generate_binaural_instrument},
      vb:button{text = "Full Colundi (128)", width = 110, tooltip = "128 Colundi frequencies across all octaves",
        notifier = generate_colundi_full_instrument},
    },

    vb:text{text = "Pattern / Composition Tools", style = "strong"},
    vb:row{
      spacing = 5,
      vb:button{text = "Golden Chords...", width = 110, tooltip = "Golden-ratio chord library",
        notifier = show_golden_chord_dialog},
      vb:button{text = "Golden Tempo...", width = 100, tooltip = "Phi-ratio BPM, pattern lengths, delay values",
        notifier = apply_golden_tempo_relationship},
      vb:button{text = "Golden Arpeggios", width = 110, tooltip = "Generate golden arpeggio phrases for selected instrument",
        notifier = generate_golden_arpeggio_phrases},
      vb:button{text = "Compare A/B...", width = 100, tooltip = "Duplicate instrument and compare two tunings",
        notifier = tuning_comparison_ab},
    },
  }

  microtonal_dialog = renoise.app():show_custom_dialog("Paketti Microtonal Tunings", content, microtonal_key_handler)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- ========================================
-- QUICK-APPLY FUNCTIONS
-- ========================================

local function apply_golden_pythagorean()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Golden Pythagorean (13-note)" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_36_edo()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "36-EDO" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_solfeggio()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Solfeggio" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_colundi()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Colundi" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_just_intonation()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Just Intonation (5-limit)" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_pythagorean()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Pythagorean (pure fifths)" then apply_tuning_to_instrument(i) return end
  end
end
local function reset_to_12tet()
  apply_tuning_to_instrument(1)
end

-- ========================================
-- MENU ENTRIES
-- ========================================

local menus = {"Main Menu:Tools:Paketti:Microtonal Tunings", "Instrument Box:Paketti:Microtonal Tunings"}
for _, base in ipairs(menus) do
  renoise.tool():add_menu_entry{name = base..":Microtonal Tunings Dialog...", invoke = show_microtonal_tuning_dialog}
  renoise.tool():add_menu_entry{name = base..":Apply Golden Pythagorean (13-note)", invoke = apply_golden_pythagorean}
  renoise.tool():add_menu_entry{name = base..":Apply 36-EDO", invoke = apply_36_edo}
  renoise.tool():add_menu_entry{name = base..":Apply Solfeggio", invoke = apply_solfeggio}
  renoise.tool():add_menu_entry{name = base..":Apply Colundi", invoke = apply_colundi}
  renoise.tool():add_menu_entry{name = base..":Apply Just Intonation (5-limit)", invoke = apply_just_intonation}
  renoise.tool():add_menu_entry{name = base..":Apply Pythagorean (pure fifths)", invoke = apply_pythagorean}
  renoise.tool():add_menu_entry{name = base..":Reset to 12-TET", invoke = reset_to_12tet}
  renoise.tool():add_menu_entry{name = base..":Generate Golden Shimmer Wavetable", invoke = generate_shimmering_wavetable}
  renoise.tool():add_menu_entry{name = base..":Generate Golden Beating Wavetable", invoke = generate_golden_beating_wavetable}
  renoise.tool():add_menu_entry{name = base..":Generate Spectral Morph Wavetable", invoke = generate_spectral_morph_wavetable}
  renoise.tool():add_menu_entry{name = base..":Generate Tuning History Wavetable", invoke = generate_tuning_history_wavetable}
  renoise.tool():add_menu_entry{name = base..":Generate Sacred Geometry Wavetable", invoke = generate_sacred_geometry_wavetable}
  renoise.tool():add_menu_entry{name = base..":Generate Golden Drone Pad", invoke = generate_golden_drone}
  renoise.tool():add_menu_entry{name = base..":Generate Golden Binaural Beats", invoke = generate_binaural_instrument}
  renoise.tool():add_menu_entry{name = base..":Generate Full Colundi (128 freq)", invoke = generate_colundi_full_instrument}
  renoise.tool():add_menu_entry{name = base..":Golden Chord Library...", invoke = show_golden_chord_dialog}
  renoise.tool():add_menu_entry{name = base..":Golden Ratio Tempo/Rhythm...", invoke = apply_golden_tempo_relationship}
  renoise.tool():add_menu_entry{name = base..":Generate Golden Arpeggio Phrases", invoke = generate_golden_arpeggio_phrases}
  renoise.tool():add_menu_entry{name = base..":Tuning Comparison A/B...", invoke = tuning_comparison_ab}
end

-- ========================================
-- KEYBINDINGS
-- ========================================

renoise.tool():add_keybinding{name = "Global:Paketti:Microtonal Tunings Dialog", invoke = show_microtonal_tuning_dialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Apply Golden Pythagorean Tuning", invoke = apply_golden_pythagorean}
renoise.tool():add_keybinding{name = "Global:Paketti:Apply 36-EDO Tuning", invoke = apply_36_edo}
renoise.tool():add_keybinding{name = "Global:Paketti:Apply Solfeggio Tuning", invoke = apply_solfeggio}
renoise.tool():add_keybinding{name = "Global:Paketti:Apply Colundi Tuning", invoke = apply_colundi}
renoise.tool():add_keybinding{name = "Global:Paketti:Reset Instrument to 12-TET", invoke = reset_to_12tet}
renoise.tool():add_keybinding{name = "Global:Paketti:Golden Chord Library Dialog", invoke = show_golden_chord_dialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Golden Ratio Tempo Dialog", invoke = apply_golden_tempo_relationship}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate Golden Arpeggio Phrases", invoke = generate_golden_arpeggio_phrases}
renoise.tool():add_keybinding{name = "Global:Paketti:Tuning Comparison AB", invoke = tuning_comparison_ab}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate Golden Drone Pad", invoke = generate_golden_drone}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate Golden Binaural Beats", invoke = generate_binaural_instrument}

-- ========================================
-- MIDI MAPPINGS
-- ========================================

renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply Golden Pythagorean", invoke = function(m) if m:is_trigger() then apply_golden_pythagorean() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply 36-EDO", invoke = function(m) if m:is_trigger() then apply_36_edo() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply Solfeggio", invoke = function(m) if m:is_trigger() then apply_solfeggio() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply Colundi", invoke = function(m) if m:is_trigger() then apply_colundi() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Reset to 12-TET", invoke = function(m) if m:is_trigger() then reset_to_12tet() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Generate Golden Drone", invoke = function(m) if m:is_trigger() then generate_golden_drone() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Generate Binaural Beats", invoke = function(m) if m:is_trigger() then generate_binaural_instrument() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Golden Arpeggio Phrases", invoke = function(m) if m:is_trigger() then generate_golden_arpeggio_phrases() end end}
