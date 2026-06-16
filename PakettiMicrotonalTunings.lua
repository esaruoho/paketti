-- Paketti Microtonal Tunings
-- Comprehensive microtonal system: tunings, golden waveforms, drones, binaural beats,
-- chord library, reharmonization, spectral morphing, sacred geometry, Colundi deep integration,
-- tuning comparison A/B, golden ratio tempo/rhythm, hardware export helpers

local microtonal_dialog = nil
local golden_chord_dialog = nil
local golden_tempo_dialog = nil
local tuning_ab_dialog = nil
local phi_sum_product_dialog = nil
local phi_interval_circle_dialog = nil
local phi_note_display_dialog = nil
local PHI = (1 + math.sqrt(5)) / 2
local LANGE_REF_HZ = 304.295 -- Christian Lange's Phi Music System reference frequency

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

local function generate_phi_9_lange()
  local PHI = (1 + math.sqrt(5)) / 2
  local ratios = {}
  for n = 1, 9 do
    local r = PHI ^ (n / 9)
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
  return result, "Phi-9 (Lange)"
end

local function generate_phi_7_lange()
  local PHI = (1 + math.sqrt(5)) / 2
  local ratios = {}
  for n = 1, 7 do
    local r = PHI ^ (n / 7)
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
  return result, "Phi-7 (Lange)"
end

local function generate_lange_phi_36()
  local PHI = (1 + math.sqrt(5)) / 2
  local ratios = {}
  for n = 1, 36 do
    local r = PHI ^ (n / 25)
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
  return result, "Lange 36-note Phi Scale"
end

local function generate_phi_power_series()
  local PHI = (1 + math.sqrt(5)) / 2
  local ratios = {}
  for n = -4, 4 do
    local r = PHI ^ n
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
  return result, "Phi Power Series"
end

-- Lange 10-TET Decagono: 10 equal divisions of the octave (2^(n/10))
local function generate_10_tet_decagono()
  local ratios = {}
  for step = 1, 10 do
    ratios[#ratios + 1] = 2 ^ (step / 10)
  end
  return ratios, "10-TET Decagono (Lange)"
end

-- Lange Phi 7/10 Hybrid: mean of 2^(n/10) and Phi^(n/7) for each step
-- This bridges the decimal octave division with the phi-based division
local function generate_phi_7_10_hybrid()
  local ratios = {}
  for n = 1, 10 do
    local tet_val = 2 ^ (n / 10)
    local phi_val = PHI ^ (n / 7)
    -- Reduce phi_val to within one octave above 1.0
    while phi_val >= 2.0 do phi_val = phi_val / 2.0 end
    while phi_val < 1.0 do phi_val = phi_val * 2.0 end
    local hybrid = (tet_val + phi_val) / 2
    ratios[#ratios + 1] = hybrid
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
  return result, "Phi 7/10 Hybrid (Lange)"
end

-- Lange Phi Music System: full 18-note scale derived from the Intonation sheet
-- Uses the "sistema" column values from Christian Lange's spreadsheet
-- Reference: 304.295 Hz (Lange's phi-derived reference pitch)
local function generate_lange_phi_music_system()
  -- These are the exact "sistema" ratios from Lange's Intonation sheet
  -- representing one octave of the Phi Music System (A0 to A1)
  -- Each ratio is relative to the fundamental (sistema value at A0 = 0.09016994...)
  -- Normalized to octave ratios (1.0 to 2.0) by dividing each by the base
  local sistema_raw = {
    0.09016994374947557,  -- A
    0.09726535583354479,  -- A#
    0.10332556124590123,  -- B
    0.11145618000168439,  -- C
    0.11803398874989592,  -- C#
    -- D is missing in phi system
    0.1273220037500358,   -- D#
    0.13525491562421335,  -- E
    0.14589803375031718,  -- F
    0.1573786516665279,   -- F#
    0.16718427000252659,  -- G
    -- G# is missing in phi system
    0.18033988749895113,  -- A (octave)
  }
  local base = sistema_raw[1]
  local ratios = {}
  for i = 2, #sistema_raw do
    local r = sistema_raw[i] / base
    if r > 1.0001 and r <= 2.001 then
      ratios[#ratios + 1] = r
    end
  end
  if #ratios == 0 or math.abs(ratios[#ratios] - 2.0) > 0.001 then
    ratios[#ratios + 1] = 2.0
  end
  return ratios, "Lange Phi Music System (304.295 Hz)"
end

-- Wendy Carlos's non-octave scales: equal divisions of the perfect fifth (3/2),
-- not the octave. The scale repeats every fifth (period = 3/2), so the equal
-- step size is preserved across the whole keyboard. (No octaves at all.)
local function generate_carlos_alpha()
  local r = {}
  for k = 1, 9 do r[k] = (3 / 2) ^ (k / 9) end    -- 9 steps of ~78.0 cents
  return r, "Wendy Carlos Alpha (78c, fifth/9)"
end
local function generate_carlos_beta()
  local r = {}
  for k = 1, 11 do r[k] = (3 / 2) ^ (k / 11) end  -- 11 steps of ~63.8 cents
  return r, "Wendy Carlos Beta (63.8c, fifth/11)"
end
local function generate_carlos_gamma()
  local r = {}
  for k = 1, 20 do r[k] = (3 / 2) ^ (k / 20) end  -- 20 steps of ~35.1 cents
  return r, "Wendy Carlos Gamma (35.1c, fifth/20)"
end

-- Indonesian gamelan example tunings (measured cents, with the characteristic
-- slightly stretched octave). Real gamelan tunings vary per ensemble; these are
-- representative examples, not a single canonical tuning. The leading 1/1 is
-- implicit, so only the steps are listed; the last value (stretched octave) is
-- the repeat period.
local function cents_to_ratios(cents_list)
  local r = {}
  for _, c in ipairs(cents_list) do r[#r + 1] = 2 ^ (c / 1200) end
  return r
end
local function generate_slendro()
  -- 5 near-equal tones; octave stretched to ~1208c (bonang inharmonicity)
  return cents_to_ratios({231, 474, 717, 955, 1208}), "Slendro (gamelan example, 5-tone)"
end
local function generate_pelog()
  -- 7 unequal tones; octave ~1206c
  return cents_to_ratios({120, 258, 539, 675, 785, 943, 1206}), "Pelog (gamelan example, 7-tone)"
end

-- ========================================
-- Scala (.scl) file loader
-- Reads standard Scala scale files from the bundled tunings/ folder (and any the
-- user drops there) and turns each into a tuning preset. The .scl format: lines
-- starting with "!" are comments; the first non-comment line is the description,
-- the next is the note count, then one pitch per line -- either CENTS (a number
-- containing a ".", e.g. 78.0) or a RATIO (a fraction "3/2", or a bare integer
-- treated as n/1). The last pitch is the period of repetition (often 2/1 octave,
-- but Carlos Alpha/Beta/Gamma repeat at the fifth instead -- fully supported by
-- Renoise's native tuning). 1/1 is implicit and never listed.
-- ========================================
local function parse_scl_pitch(token)
  -- returns a ratio (number) for one .scl pitch token, or nil if unparseable
  if token:find("/", 1, true) then
    local num, den = token:match("^(%d+)%s*/%s*(%d+)")
    if num and den and tonumber(den) ~= 0 then
      return tonumber(num) / tonumber(den)
    end
    return nil
  elseif token:find(".", 1, true) then
    local cents = tonumber(token)
    if cents then return 2 ^ (cents / 1200) end
    return nil
  else
    local whole = tonumber(token)
    if whole then return whole end  -- bare integer = whole-number ratio (n/1)
    return nil
  end
end

local function parse_scl_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local lines = {}
  for line in f:lines() do lines[#lines + 1] = line end
  f:close()

  local description, count, ratios = nil, nil, {}
  for _, raw in ipairs(lines) do
    -- strip trailing whitespace/CR; keep the leading-! check on the raw line
    local line = raw:gsub("[\r\n]+$", "")
    if line:match("^%s*!") then
      -- comment, skip
    elseif description == nil then
      description = line:gsub("^%s+", ""):gsub("%s+$", "")
    elseif count == nil then
      count = tonumber((line:match("(-?%d+)")))
    else
      -- first whitespace-delimited token on the line is the pitch
      local token = line:match("^%s*([^%s]+)")
      if token then
        local r = parse_scl_pitch(token)
        if r then ratios[#ratios + 1] = r end
      end
    end
  end

  if not description or description == "" then
    description = path:match("([^/\\]+)%.scl$") or "Scala tuning"
  end
  if #ratios == 0 then return nil end
  return ratios, description
end

-- Discover all bundled .scl files at load time and build a sorted preset list.
local function discover_scala_presets()
  local presets = {}
  local dir = renoise.tool().bundle_path .. "tunings/"
  local ok, files = pcall(function() return os.filenames(dir, "*.scl") end)
  if not ok or not files then return presets end
  table.sort(files)
  for _, filename in ipairs(files) do
    local ratios, description = parse_scl_file(dir .. filename)
    if ratios then
      local stem = filename:gsub("%.scl$", "")
      local display = string.format("%s (%s.scl, %d-note)", description, stem, #ratios)
      presets[#presets + 1] = {
        name = display,
        ratios = ratios,
        generator = function() return ratios, display end,
      }
    end
  end
  return presets
end

local scala_file_presets = discover_scala_presets()

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
  {name = "Phi-9 (Lange)", generator = generate_phi_9_lange},
  {name = "Phi-7 (Lange)", generator = generate_phi_7_lange},
  {name = "Lange 36-note Phi Scale", generator = generate_lange_phi_36},
  {name = "Phi Power Series", generator = generate_phi_power_series},
  {name = "10-TET Decagono (Lange)", generator = generate_10_tet_decagono},
  {name = "Phi 7/10 Hybrid (Lange)", generator = generate_phi_7_10_hybrid},
  {name = "Lange Phi Music System (304.295 Hz)", generator = generate_lange_phi_music_system},
  {name = "Wendy Carlos Alpha (78c)", generator = generate_carlos_alpha},
  {name = "Wendy Carlos Beta (63.8c)", generator = generate_carlos_beta},
  {name = "Wendy Carlos Gamma (35.1c)", generator = generate_carlos_gamma},
  {name = "Slendro (gamelan example)", generator = generate_slendro},
  {name = "Pelog (gamelan example)", generator = generate_pelog},
}

-- Append every .scl file found in the bundled tunings/ folder as a preset, so the
-- dialog popup, the A/B comparison and the menu all pick them up automatically.
-- Drop a new .scl into tunings/ and it shows up next time the tool loads.
for _, p in ipairs(scala_file_presets) do
  tuning_presets[#tuning_presets + 1] = {name = p.name, generator = p.generator}
end

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
-- LANGE PHI HARMONIC STRINGS WAVETABLE
-- From Christian Lange's "Phi Music System 7/10" spreadsheet
-- 18 harmonic "strings" based on ratios of 9
-- ========================================

local function generate_phi_harmonic_strings_wavetable()
  local song = renoise.song()
  if not song then return end
  local wave_size = 2048
  local sample_rate = 44100

  song:describe_undo("Generate Phi Harmonic Strings Wavetable")
  local instr = prepare_instrument("Phi Harmonic Strings (Lange)")

  -- The 18 harmonic string ratios from Lange's spreadsheet (columns H-Y at key 0)
  -- These represent the overtone series positions of a vibrating string
  -- divided by 9-based ratios: 1/9, 1/6, 2/9, 1/4, 1/3, 4/9, 1/2, 2/3, 3/4,
  -- 4/3, 3/2, 2, 9/4, 3, 4, 9/2, 6, 9
  local string_ratios = {
    1/9,   -- String 1: subharmonic ninth
    1/6,   -- String 2: subharmonic sixth
    2/9,   -- String 3: subharmonic
    1/4,   -- String 4: two octaves below
    1/3,   -- String 5: subharmonic third
    4/9,   -- String 6
    1/2,   -- String 7: one octave below
    2/3,   -- String 8: subharmonic fifth
    3/4,   -- String 9: subharmonic fourth
    4/3,   -- String 10: perfect fourth above
    3/2,   -- String 11: perfect fifth above
    2,     -- String 12: one octave above
    9/4,   -- String 13
    3,     -- String 14: octave + fifth
    4,     -- String 15: two octaves above
    9/2,   -- String 16
    6,     -- String 17: two octaves + fifth
    9,     -- String 18: three octaves + second
  }

  -- Generate 12 wavetable positions, progressively adding more string partials
  local num_positions = 12
  for pos = 1, num_positions do
    if pos > #instr.samples then instr:insert_sample_at(pos) end
    local sample = instr.samples[pos]

    -- Each position adds more harmonic strings
    -- Position 1: strings 7-11 (core: 1/2, 2/3, 3/4, 4/3, 3/2)
    -- Position 12: all 18 strings
    local start_idx = math.max(1, 7 - math.floor((pos - 1) * 6 / 11))
    local end_idx = math.min(18, 11 + math.floor((pos - 1) * 7 / 11))

    local partials = {}
    local amps = {}
    for i = start_idx, end_idx do
      partials[#partials + 1] = string_ratios[i]
      -- Amplitude falls off for extreme harmonics, strongest near fundamental
      local distance = math.abs(i - 9) -- 9 is near the fundamental region
      amps[#amps + 1] = 1 / (1 + distance * 0.3)
    end

    write_additive_buffer(sample.sample_buffer, wave_size, sample_rate, partials, amps)
    sample.name = string.format("Strings %02d (%d-%d)", pos, start_idx, end_idx)
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = wave_size
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  end

  if #instr.samples > num_positions and not instr.samples[1].sample_buffer.has_sample_data then
    instr:delete_sample_at(1)
  end
  renoise.app():show_status("Generated Phi Harmonic Strings: 12 positions, 18 string ratios (Lange)")
end

-- ========================================
-- PHI SUM/PRODUCT CHORD BUILDER
-- Interactive chord builder using Lange's phi sum/product matrices
-- Select two phi scale degrees → see their sum and product frequencies
-- ========================================

-- The phi scale degrees (sistema values) normalized to one octave
local phi_scale_degrees = {
  {ratio = 1.0,                              name = "A (root)"},
  {ratio = 0.09726535583354479 / 0.09016994374947557, name = "A#"},
  {ratio = 0.10332556124590123 / 0.09016994374947557, name = "B"},
  {ratio = 0.11145618000168439 / 0.09016994374947557, name = "C"},
  {ratio = 0.11803398874989592 / 0.09016994374947557, name = "C#"},
  {ratio = 0.1273220037500358  / 0.09016994374947557, name = "D#"},
  {ratio = 0.13525491562421335 / 0.09016994374947557, name = "E"},
  {ratio = 0.14589803375031718 / 0.09016994374947557, name = "F"},
  {ratio = 0.1573786516665279  / 0.09016994374947557, name = "F#"},
  {ratio = 0.16718427000252659 / 0.09016994374947557, name = "G"},
  {ratio = 0.18033988749895113 / 0.09016994374947557, name = "A (oct)"},
}

local function show_phi_sum_product_dialog()
  if phi_sum_product_dialog and phi_sum_product_dialog.visible then
    phi_sum_product_dialog:close()
  end

  local vb = renoise.ViewBuilder()

  local degree_names = {}
  for _, d in ipairs(phi_scale_degrees) do
    degree_names[#degree_names + 1] = string.format("%s (%.4f)", d.name, d.ratio)
  end

  local function update_info()
    local idx_a = vb.views.phi_degree_a.value
    local idx_b = vb.views.phi_degree_b.value
    local a = phi_scale_degrees[idx_a]
    local b = phi_scale_degrees[idx_b]

    local sum_ratio = a.ratio + b.ratio
    local prod_ratio = a.ratio * b.ratio

    -- Reduce to octave
    local sum_oct = sum_ratio
    while sum_oct >= 2.0 do sum_oct = sum_oct / 2.0 end
    while sum_oct < 1.0 do sum_oct = sum_oct * 2.0 end

    local prod_oct = prod_ratio
    while prod_oct >= 2.0 do prod_oct = prod_oct / 2.0 end
    while prod_oct < 1.0 do prod_oct = prod_oct * 2.0 end

    local sum_cents = 1200 * math.log(sum_oct) / math.log(2)
    local prod_cents = 1200 * math.log(prod_oct) / math.log(2)

    -- Calculate actual Hz at Lange's reference
    local freq_a = LANGE_REF_HZ * a.ratio
    local freq_b = LANGE_REF_HZ * b.ratio
    local freq_sum = LANGE_REF_HZ * sum_ratio
    local freq_prod = LANGE_REF_HZ * prod_ratio

    -- Check if sum equals a nice value
    local sum_nice = ""
    if math.abs(sum_ratio - 2.0) < 0.0001 then sum_nice = " = EXACT OCTAVE (2.000)"
    elseif math.abs(sum_ratio - 1.0) < 0.0001 then sum_nice = " = UNISON"
    elseif math.abs(sum_ratio - math.floor(sum_ratio + 0.5)) < 0.0001 then
      sum_nice = string.format(" = INTEGER (%d)", math.floor(sum_ratio + 0.5))
    end

    local lines = {
      "PHI SUM / PRODUCT CHORD BUILDER",
      string.format("Reference: %.3f Hz (Lange Phi Music System)", LANGE_REF_HZ),
      "",
      string.format("Degree A: %s = %.6f  (%.2f Hz)", a.name, a.ratio, freq_a),
      string.format("Degree B: %s = %.6f  (%.2f Hz)", b.name, b.ratio, freq_b),
      "",
      "--- SUM (A + B) ---",
      string.format("  Raw:     %.6f%s", sum_ratio, sum_nice),
      string.format("  Octave:  %.6f  (%.2f cents)", sum_oct, sum_cents),
      string.format("  Hz:      %.3f Hz", freq_sum),
      "",
      "--- PRODUCT (A x B) ---",
      string.format("  Raw:     %.6f", prod_ratio),
      string.format("  Octave:  %.6f  (%.2f cents)", prod_oct, prod_cents),
      string.format("  Hz:      %.3f Hz", freq_prod),
      "",
      "--- PHI IDENTITY CHECK ---",
      string.format("  A + B = %.6f", sum_ratio),
      string.format("  Phi property: 0.381966... + 1.618034... = 2.000000"),
    }
    vb.views.phi_sp_info.text = table.concat(lines, "\n")
  end

  local content = vb:column{
    margin = 10,
    spacing = 5,
    vb:text{text = "Phi Sum/Product Chord Builder (Lange)", style = "strong", font = "bold"},
    vb:row{
      spacing = 5,
      vb:text{text = "Degree A:", width = 60},
      vb:popup{id = "phi_degree_a", items = degree_names, value = 1, width = 220,
        notifier = function() update_info() end},
    },
    vb:row{
      spacing = 5,
      vb:text{text = "Degree B:", width = 60},
      vb:popup{id = "phi_degree_b", items = degree_names, value = 5, width = 220,
        notifier = function() update_info() end},
    },
    vb:multiline_textfield{
      id = "phi_sp_info",
      text = "",
      width = 500,
      height = 300,
      font = "mono",
    },
    vb:row{
      spacing = 5,
      vb:button{text = "Insert Sum as Note", width = 140,
        notifier = function()
          local song = renoise.song()
          if not song then return end
          local idx_a = vb.views.phi_degree_a.value
          local idx_b = vb.views.phi_degree_b.value
          local sum_ratio = phi_scale_degrees[idx_a].ratio + phi_scale_degrees[idx_b].ratio
          while sum_ratio >= 2.0 do sum_ratio = sum_ratio / 2.0 end
          while sum_ratio < 1.0 do sum_ratio = sum_ratio * 2.0 end
          local cents = 1200 * math.log(sum_ratio) / math.log(2)
          local semitones = math.floor(cents / 100 + 0.5)
          local note = 48 + semitones -- C-4 base
          note = math.max(0, math.min(119, note))
          song:describe_undo("Insert Phi Sum Note")
          local line = song.selected_line
          if line then
            line.note_columns[1].note_value = note
            line.note_columns[1].instrument_value = song.selected_instrument_index - 1
          end
          renoise.app():show_status(string.format("Inserted sum note: %d (%.1f cents)", note, cents))
        end},
      vb:button{text = "Insert Product as Note", width = 150,
        notifier = function()
          local song = renoise.song()
          if not song then return end
          local idx_a = vb.views.phi_degree_a.value
          local idx_b = vb.views.phi_degree_b.value
          local prod_ratio = phi_scale_degrees[idx_a].ratio * phi_scale_degrees[idx_b].ratio
          while prod_ratio >= 2.0 do prod_ratio = prod_ratio / 2.0 end
          while prod_ratio < 1.0 do prod_ratio = prod_ratio * 2.0 end
          local cents = 1200 * math.log(prod_ratio) / math.log(2)
          local semitones = math.floor(cents / 100 + 0.5)
          local note = 48 + semitones
          note = math.max(0, math.min(119, note))
          song:describe_undo("Insert Phi Product Note")
          local line = song.selected_line
          if line then
            line.note_columns[1].note_value = note
            line.note_columns[1].instrument_value = song.selected_instrument_index - 1
          end
          renoise.app():show_status(string.format("Inserted product note: %d (%.1f cents)", note, cents))
        end},
    },
  }

  phi_sum_product_dialog = renoise.app():show_custom_dialog("Phi Sum/Product (Lange)", content, microtonal_key_handler)
  update_info()
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- ========================================
-- CANVAS: PHI INTERVAL CIRCLE VISUALIZATION
-- Shows tuning relationships as a circle diagram
-- Each note of the current tuning is plotted on a circle
-- ========================================

local function show_phi_interval_circle()
  if not PAKETTI_HAS_CANVAS then
    renoise.app():show_warning("Phi Interval Circle requires Renoise 3.5 or newer (Canvas API).")
    return
  end
  if phi_interval_circle_dialog and phi_interval_circle_dialog.visible then
    phi_interval_circle_dialog:close()
  end

  local vb = renoise.ViewBuilder()
  local canvas_size = 500
  local cx = canvas_size / 2
  local cy = canvas_size / 2
  local radius = 200
  local inner_radius = 150

  -- Current tuning state for drawing
  local current_preset_idx = 1
  local compare_preset_idx = 1
  local show_comparison = false

  local function get_tuning_ratios(idx)
    local preset = tuning_presets[idx]
    if not preset or preset.is_reset then return {} end
    local ratios = preset.generator()
    return ratios
  end

  local function ratio_to_angle(r)
    -- Map cents (0-1200) to angle (0 to 2*pi), starting at top (12 o'clock)
    local cents = 1200 * math.log(r) / math.log(2)
    return (cents / 1200) * math.pi * 2 - math.pi / 2
  end

  local popup_items = {}
  for _, preset in ipairs(tuning_presets) do
    popup_items[#popup_items + 1] = preset.name
  end

  local function render_circle(ctx)
    -- Background
    ctx.fill_color = {30, 30, 40, 255}
    ctx:rect(0, 0, canvas_size, canvas_size)

    -- Draw 12-TET reference circle and lines
    ctx.stroke_color = {60, 60, 80, 255}
    ctx.line_width = 1
    for i = 0, 11 do
      local angle = (i / 12) * math.pi * 2 - math.pi / 2
      local x1 = cx + math.cos(angle) * (radius + 20)
      local y1 = cy + math.sin(angle) * (radius + 20)
      local x2 = cx + math.cos(angle) * (radius - 20)
      local y2 = cy + math.sin(angle) * (radius - 20)
      ctx:begin_path()
      ctx:move_to(x1, y1)
      ctx:line_to(x2, y2)
      ctx:stroke()
    end

    -- Draw outer circle
    ctx.stroke_color = {80, 80, 120, 255}
    ctx.line_width = 2
    local segments = 120
    ctx:begin_path()
    for i = 0, segments do
      local angle = (i / segments) * math.pi * 2
      local x = cx + math.cos(angle) * radius
      local y = cy + math.sin(angle) * radius
      if i == 0 then ctx:move_to(x, y) else ctx:line_to(x, y) end
    end
    ctx:stroke()

    -- Draw comparison tuning (if enabled)
    if show_comparison then
      local comp_ratios = get_tuning_ratios(compare_preset_idx)
      if #comp_ratios > 0 then
        ctx.stroke_color = {200, 200, 100, 180}
        ctx.line_width = 1
        -- Draw comparison notes as smaller dots on inner circle
        for _, r in ipairs(comp_ratios) do
          local angle = ratio_to_angle(r)
          local x = cx + math.cos(angle) * inner_radius
          local y = cy + math.sin(angle) * inner_radius
          ctx.fill_color = {200, 200, 100, 180}
          ctx:rect(x - 3, y - 3, 6, 6)
        end
        -- Connect comparison notes
        ctx:begin_path()
        local first_angle = ratio_to_angle(comp_ratios[1])
        ctx:move_to(cx + math.cos(first_angle) * inner_radius, cy + math.sin(first_angle) * inner_radius)
        for _, r in ipairs(comp_ratios) do
          local angle = ratio_to_angle(r)
          ctx:line_to(cx + math.cos(angle) * inner_radius, cy + math.sin(angle) * inner_radius)
        end
        ctx:stroke()
      end
    end

    -- Draw current tuning
    local ratios = get_tuning_ratios(current_preset_idx)
    if #ratios > 0 then
      -- Draw interval lines connecting all notes to root
      ctx.stroke_color = {100, 150, 200, 80}
      ctx.line_width = 1
      for _, r in ipairs(ratios) do
        local angle = ratio_to_angle(r)
        local x = cx + math.cos(angle) * radius
        local y = cy + math.sin(angle) * radius
        ctx:begin_path()
        ctx:move_to(cx, cy)
        ctx:line_to(x, y)
        ctx:stroke()
      end

      -- Draw polygon connecting all notes
      ctx.stroke_color = {150, 100, 200, 255}
      ctx.line_width = 2
      ctx:begin_path()
      -- Start at root (top, 12 o'clock = 0 cents)
      ctx:move_to(cx, cy - radius)
      for _, r in ipairs(ratios) do
        local angle = ratio_to_angle(r)
        ctx:line_to(cx + math.cos(angle) * radius, cy + math.sin(angle) * radius)
      end
      ctx:stroke()

      -- Draw note dots
      -- Root dot
      ctx.fill_color = {100, 200, 100, 255}
      ctx:rect(cx - 5, cy - radius - 5, 10, 10)

      -- Scale degree dots
      for i, r in ipairs(ratios) do
        local angle = ratio_to_angle(r)
        local x = cx + math.cos(angle) * radius
        local y = cy + math.sin(angle) * radius

        -- Color based on interval quality
        local cents = 1200 * math.log(r) / math.log(2)
        if math.abs(cents - 702) < 20 then
          ctx.fill_color = {100, 200, 100, 255} -- Green for ~fifth
        elseif math.abs(cents - 386) < 20 or math.abs(cents - 316) < 20 then
          ctx.fill_color = {200, 150, 100, 255} -- Orange for ~thirds
        elseif math.abs(cents - 1200) < 5 then
          ctx.fill_color = {100, 200, 100, 255} -- Green for octave
        else
          ctx.fill_color = {150, 100, 200, 255} -- Purple for others
        end

        ctx:rect(x - 4, y - 4, 8, 8)
      end
    end

    -- Draw center reference
    ctx.fill_color = {200, 200, 200, 100}
    ctx:rect(cx - 2, cy - 2, 4, 4)
  end

  local content = vb:column{
    margin = 10,
    spacing = 5,
    vb:text{text = "Phi Interval Circle", style = "strong", font = "bold"},
    vb:row{
      spacing = 5,
      vb:text{text = "Tuning:", width = 55},
      vb:popup{id = "circle_preset", items = popup_items, value = 2, width = 250,
        notifier = function(idx)
          current_preset_idx = idx
          vb.views.interval_canvas:update()
        end},
    },
    vb:row{
      spacing = 5,
      vb:checkbox{id = "circle_compare", value = false,
        notifier = function(v)
          show_comparison = v
          vb.views.interval_canvas:update()
        end},
      vb:text{text = "Compare with:", width = 80},
      vb:popup{id = "circle_compare_preset", items = popup_items, value = 1, width = 210,
        notifier = function(idx)
          compare_preset_idx = idx
          if show_comparison then vb.views.interval_canvas:update() end
        end},
    },
    vb:canvas{
      id = "interval_canvas",
      width = canvas_size,
      height = canvas_size,
      mode = "plain",
      render = render_circle,
    },
    vb:text{
      text = "Purple = current tuning on outer circle | Yellow = comparison on inner circle\n" ..
             "Green dots = root/fifth/octave | Orange dots = thirds | Purple dots = other degrees\n" ..
             "Gray lines = 12-TET reference positions",
      font = "mono",
    },
    vb:row{
      spacing = 5,
      vb:button{text = "Apply to Instrument", width = 140,
        notifier = function()
          apply_tuning_to_instrument(current_preset_idx)
        end},
      vb:button{text = "Export as Scala...", width = 120,
        notifier = function()
          export_tuning_as_scala(current_preset_idx)
        end},
    },
  }

  phi_interval_circle_dialog = renoise.app():show_custom_dialog("Phi Interval Circle", content, microtonal_key_handler)
  current_preset_idx = 2 -- Start with Golden Pythagorean
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- ========================================
-- TUNING-AWARE NOTE DISPLAY
-- Shows the current note in terms of the active phi tuning
-- Displays scale degree, cents, Hz, and nearest phi note name
-- ========================================

local function show_phi_note_display()
  if phi_note_display_dialog and phi_note_display_dialog.visible then
    phi_note_display_dialog:close()
  end

  local vb = renoise.ViewBuilder()

  -- Standard note names for reference
  local std_notes = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}

  -- Phi Music System note names (from Lange's Intonation sheet)
  local phi_note_names = {"A", "A#", "B", "C", "C#", "(D)", "D#", "E", "F", "F#", "G", "(G#)"}
  local phi_sistema = {
    0.09016994374947557, 0.09726535583354479, 0.10332556124590123,
    0.11145618000168439, 0.11803398874989592, nil,
    0.1273220037500358, 0.13525491562421335, 0.14589803375031718,
    0.1573786516665279, 0.16718427000252659, nil,
  }

  local function get_note_info()
    local song = renoise.song()
    if not song then return "No song loaded" end

    local line = song.selected_line
    if not line then return "No line selected" end

    local col_idx = song.selected_note_column_index
    if col_idx < 1 then return "Select a note column" end

    local col = line.note_columns[col_idx]
    if not col or col.note_value > 119 then return "No note at cursor" end

    local note_val = col.note_value
    local octave = math.floor(note_val / 12)
    local semitone = note_val % 12
    local std_name = std_notes[semitone + 1] .. octave

    -- Calculate frequency in standard 12-TET (A4 = 440 Hz)
    local freq_12tet = 440 * 2 ^ ((note_val - 57) / 12)

    -- Calculate in Lange's system (A4 = based on 304.295 Hz reference)
    -- In Lange's system, D#4/E4 area is 304.295 Hz
    local freq_lange = LANGE_REF_HZ * 2 ^ ((note_val - 51) / 12) -- rough mapping, D#4 = note 51

    -- Check current instrument tuning
    local instr = song.selected_instrument
    local tuning_name = "12-TET (Standard)"
    local tuning_ratios = {}
    if instr and instr.trigger_options then
      local tname = instr.trigger_options.tuning_name
      if tname and tname ~= "" then tuning_name = tname end
      tuning_ratios = instr.trigger_options.tuning or {}
    end

    -- Find nearest phi scale degree
    local cents_from_root = (note_val % 12) * 100
    local nearest_phi = "N/A"
    local nearest_phi_cents = 999
    for i, sist in ipairs(phi_sistema) do
      if sist then
        local ratio = sist / phi_sistema[1]
        local phi_cents = 1200 * math.log(ratio) / math.log(2)
        phi_cents = phi_cents % 1200
        local diff = math.abs(cents_from_root - phi_cents)
        if diff > 600 then diff = 1200 - diff end
        if diff < nearest_phi_cents then
          nearest_phi_cents = diff
          nearest_phi = phi_note_names[i]
        end
      end
    end

    local lines = {
      "TUNING-AWARE NOTE DISPLAY",
      "",
      string.format("Standard:  %s (MIDI %d)", std_name, note_val),
      string.format("12-TET Hz: %.3f Hz", freq_12tet),
      "",
      string.format("Current tuning: %s", tuning_name),
      string.format("Tuning degrees: %d notes/octave", #tuning_ratios > 0 and #tuning_ratios or 12),
      "",
      "--- Phi Music System ---",
      string.format("Nearest Phi note: %s", nearest_phi),
      string.format("Deviation: %.1f cents", nearest_phi_cents),
      string.format("Lange ref Hz:     %.3f Hz (at 304.295 ref)", freq_lange),
      "",
      "--- Scale Degree Info ---",
    }

    -- If tuning is applied, show the degree info
    if #tuning_ratios > 0 then
      local degree_in_scale = semitone % (#tuning_ratios)
      if degree_in_scale > 0 and degree_in_scale <= #tuning_ratios then
        local r = tuning_ratios[degree_in_scale]
        local cents = 1200 * math.log(r) / math.log(2)
        lines[#lines + 1] = string.format("Scale degree: %d of %d", degree_in_scale, #tuning_ratios)
        lines[#lines + 1] = string.format("Ratio: %.6f", r)
        lines[#lines + 1] = string.format("Cents from root: %.2f", cents)
      end
    else
      lines[#lines + 1] = string.format("Semitone: %d of 12", semitone)
      lines[#lines + 1] = string.format("Cents from C: %d", semitone * 100)
    end

    return table.concat(lines, "\n")
  end

  local content = vb:column{
    margin = 10,
    spacing = 5,
    vb:text{text = "Phi Tuning-Aware Note Display", style = "strong", font = "bold"},
    vb:multiline_textfield{
      id = "phi_note_info",
      text = get_note_info(),
      width = 420,
      height = 320,
      font = "mono",
    },
    vb:row{
      spacing = 5,
      vb:button{text = "Refresh", width = 80,
        notifier = function()
          vb.views.phi_note_info.text = get_note_info()
        end},
      vb:button{text = "Apply Lange Phi Music System", width = 200,
        notifier = function()
          for i, preset in ipairs(tuning_presets) do
            if preset.name == "Lange Phi Music System (304.295 Hz)" then
              apply_tuning_to_instrument(i)
              vb.views.phi_note_info.text = get_note_info()
              return
            end
          end
        end},
    },
  }

  phi_note_display_dialog = renoise.app():show_custom_dialog("Phi Note Display", content, microtonal_key_handler)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
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

function show_golden_chord_dialog()
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

function apply_golden_tempo_relationship()
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

function show_microtonal_tuning_dialog()
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
    vb:row{
      spacing = 5,
      vb:button{text = "Phi Harmonic Strings (Lange)", width = 190, tooltip = "12-pos wavetable with 18 harmonic strings from Lange's 9-series",
        notifier = generate_phi_harmonic_strings_wavetable},
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

    vb:text{text = "Lange Phi Music System Tools", style = "strong"},
    vb:row{
      spacing = 5,
      vb:button{text = "Sum/Product Chords...", width = 150, tooltip = "Interactive phi sum/product chord builder (Lange)",
        notifier = show_phi_sum_product_dialog},
      vb:button{text = "Interval Circle...", width = 110, tooltip = "Canvas visualization of tuning intervals",
        notifier = show_phi_interval_circle},
      vb:button{text = "Note Display...", width = 100, tooltip = "Tuning-aware note info with phi degree mapping",
        notifier = show_phi_note_display},
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
local function apply_carlos_alpha()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Wendy Carlos Alpha (78c)" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_carlos_beta()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Wendy Carlos Beta (63.8c)" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_carlos_gamma()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Wendy Carlos Gamma (35.1c)" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_preset_by_name(target)
  for i, preset in ipairs(tuning_presets) do
    if preset.name == target then apply_tuning_to_instrument(i) return end
  end
end
local function apply_slendro()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Slendro (gamelan example)" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_pelog()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Pelog (gamelan example)" then apply_tuning_to_instrument(i) return end
  end
end
local function reset_to_12tet()
  apply_tuning_to_instrument(1)
end
local function apply_phi_9_lange()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Phi-9 (Lange)" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_phi_7_lange()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Phi-7 (Lange)" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_lange_phi_36()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Lange 36-note Phi Scale" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_phi_power_series()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Phi Power Series" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_10_tet_decagono()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "10-TET Decagono (Lange)" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_phi_7_10_hybrid()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Phi 7/10 Hybrid (Lange)" then apply_tuning_to_instrument(i) return end
  end
end
local function apply_lange_phi_music_system()
  for i, preset in ipairs(tuning_presets) do
    if preset.name == "Lange Phi Music System (304.295 Hz)" then apply_tuning_to_instrument(i) return end
  end
end

-- ========================================
-- MENU ENTRIES
-- ========================================

local menus = {"Main Menu:Tools:Paketti:Microtonal Tunings", "Instrument Box:Paketti:Microtonal Tunings"}
for _, base in ipairs(menus) do
  PakettiAddMenuEntry{name = base..":Microtonal Tunings Dialog...", invoke = show_microtonal_tuning_dialog}
  PakettiAddMenuEntry{name = base..":Apply Golden Pythagorean (13-note)", invoke = apply_golden_pythagorean}
  PakettiAddMenuEntry{name = base..":Apply 36-EDO", invoke = apply_36_edo}
  PakettiAddMenuEntry{name = base..":Apply Solfeggio", invoke = apply_solfeggio}
  PakettiAddMenuEntry{name = base..":Apply Colundi", invoke = apply_colundi}
  PakettiAddMenuEntry{name = base..":Apply Just Intonation (5-limit)", invoke = apply_just_intonation}
  PakettiAddMenuEntry{name = base..":Apply Pythagorean (pure fifths)", invoke = apply_pythagorean}
  PakettiAddMenuEntry{name = base..":Apply Wendy Carlos Alpha (78c)", invoke = apply_carlos_alpha}
  PakettiAddMenuEntry{name = base..":Apply Wendy Carlos Beta (63.8c)", invoke = apply_carlos_beta}
  PakettiAddMenuEntry{name = base..":Apply Wendy Carlos Gamma (35.1c)", invoke = apply_carlos_gamma}
  PakettiAddMenuEntry{name = base..":Apply Slendro (gamelan example)", invoke = apply_slendro}
  PakettiAddMenuEntry{name = base..":Apply Pelog (gamelan example)", invoke = apply_pelog}
  for _, p in ipairs(scala_file_presets) do
    local preset_name = p.name
    PakettiAddMenuEntry{name = base..":Apply "..preset_name, invoke = function() apply_preset_by_name(preset_name) end}
  end
  PakettiAddMenuEntry{name = base..":Apply Phi-9 (Lange)", invoke = apply_phi_9_lange}
  PakettiAddMenuEntry{name = base..":Apply Phi-7 (Lange)", invoke = apply_phi_7_lange}
  PakettiAddMenuEntry{name = base..":Apply Lange 36-note Phi Scale", invoke = apply_lange_phi_36}
  PakettiAddMenuEntry{name = base..":Apply Phi Power Series", invoke = apply_phi_power_series}
  PakettiAddMenuEntry{name = base..":Apply 10-TET Decagono (Lange)", invoke = apply_10_tet_decagono}
  PakettiAddMenuEntry{name = base..":Apply Phi 7/10 Hybrid (Lange)", invoke = apply_phi_7_10_hybrid}
  PakettiAddMenuEntry{name = base..":Apply Lange Phi Music System (304.295 Hz)", invoke = apply_lange_phi_music_system}
  PakettiAddMenuEntry{name = base..":Reset to 12-TET", invoke = reset_to_12tet}
  PakettiAddMenuEntry{name = base..":Generate Golden Shimmer Wavetable", invoke = generate_shimmering_wavetable}
  PakettiAddMenuEntry{name = base..":Generate Golden Beating Wavetable", invoke = generate_golden_beating_wavetable}
  PakettiAddMenuEntry{name = base..":Generate Spectral Morph Wavetable", invoke = generate_spectral_morph_wavetable}
  PakettiAddMenuEntry{name = base..":Generate Tuning History Wavetable", invoke = generate_tuning_history_wavetable}
  PakettiAddMenuEntry{name = base..":Generate Sacred Geometry Wavetable", invoke = generate_sacred_geometry_wavetable}
  PakettiAddMenuEntry{name = base..":Generate Phi Harmonic Strings Wavetable (Lange)", invoke = generate_phi_harmonic_strings_wavetable}
  PakettiAddMenuEntry{name = base..":Generate Golden Drone Pad", invoke = generate_golden_drone}
  PakettiAddMenuEntry{name = base..":Generate Golden Binaural Beats", invoke = generate_binaural_instrument}
  PakettiAddMenuEntry{name = base..":Generate Full Colundi (128 freq)", invoke = generate_colundi_full_instrument}
  PakettiAddMenuEntry{name = base..":Golden Chord Library...", invoke = show_golden_chord_dialog}
  PakettiAddMenuEntry{name = base..":Golden Ratio Tempo/Rhythm...", invoke = apply_golden_tempo_relationship}
  PakettiAddMenuEntry{name = base..":Generate Golden Arpeggio Phrases", invoke = generate_golden_arpeggio_phrases}
  PakettiAddMenuEntry{name = base..":Tuning Comparison A/B...", invoke = tuning_comparison_ab}
  PakettiAddMenuEntry{name = base..":Phi Sum/Product Chord Builder (Lange)...", invoke = show_phi_sum_product_dialog}
  PakettiAddMenuEntry{name = base..":Phi Interval Circle...", invoke = show_phi_interval_circle}
  PakettiAddMenuEntry{name = base..":Phi Tuning-Aware Note Display...", invoke = show_phi_note_display}
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
renoise.tool():add_keybinding{name = "Global:Paketti:Apply Phi-9 Lange Tuning", invoke = apply_phi_9_lange}
renoise.tool():add_keybinding{name = "Global:Paketti:Apply Phi-7 Lange Tuning", invoke = apply_phi_7_lange}
renoise.tool():add_keybinding{name = "Global:Paketti:Apply Lange 36-note Phi Tuning", invoke = apply_lange_phi_36}
renoise.tool():add_keybinding{name = "Global:Paketti:Apply Phi Power Series Tuning", invoke = apply_phi_power_series}
renoise.tool():add_keybinding{name = "Global:Paketti:Apply 10-TET Decagono Lange Tuning", invoke = apply_10_tet_decagono}
renoise.tool():add_keybinding{name = "Global:Paketti:Apply Phi 7/10 Hybrid Lange Tuning", invoke = apply_phi_7_10_hybrid}
renoise.tool():add_keybinding{name = "Global:Paketti:Apply Lange Phi Music System Tuning", invoke = apply_lange_phi_music_system}
renoise.tool():add_keybinding{name = "Global:Paketti:Phi Harmonic Strings Wavetable Lange", invoke = generate_phi_harmonic_strings_wavetable}
renoise.tool():add_keybinding{name = "Global:Paketti:Phi Sum Product Chord Builder Lange", invoke = show_phi_sum_product_dialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Phi Interval Circle Visualization", invoke = show_phi_interval_circle}
renoise.tool():add_keybinding{name = "Global:Paketti:Phi Tuning-Aware Note Display", invoke = show_phi_note_display}

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
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply Phi-9 Lange", invoke = function(m) if m:is_trigger() then apply_phi_9_lange() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply Phi-7 Lange", invoke = function(m) if m:is_trigger() then apply_phi_7_lange() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply Lange 36-note Phi", invoke = function(m) if m:is_trigger() then apply_lange_phi_36() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply 10-TET Decagono Lange", invoke = function(m) if m:is_trigger() then apply_10_tet_decagono() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply Phi 7/10 Hybrid Lange", invoke = function(m) if m:is_trigger() then apply_phi_7_10_hybrid() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply Lange Phi Music System", invoke = function(m) if m:is_trigger() then apply_lange_phi_music_system() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Phi Harmonic Strings Wavetable", invoke = function(m) if m:is_trigger() then generate_phi_harmonic_strings_wavetable() end end}
renoise.tool():add_midi_mapping{name = "Paketti:Microtonal Tunings:Apply Phi Power Series", invoke = function(m) if m:is_trigger() then apply_phi_power_series() end end}
