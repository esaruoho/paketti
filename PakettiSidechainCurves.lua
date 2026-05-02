-- PakettiSidechainCurves.lua
-- Sidechain Curve Pack: 8 ducking-shaped curves that plug into the existing
-- PakettiAutomationCurves system. Each shape is registered into
-- PakettiAutomationCurvesShapes so the existing LFO Custom Waveform writer
-- and automation insert pipeline can apply them directly.
--
-- All shapes start at Y=0 (ducked at trigger) and recover to Y=1 (rest),
-- so they suit a Custom LFO driving a destination where 0 = ducked.

local CURVES = PAKETTI_PLAYMODE_CURVES
local LINES  = PAKETTI_PLAYMODE_LINES
local POINTS = PAKETTI_PLAYMODE_POINTS

------------------------------------------------------------------------
-- Shape Generators
------------------------------------------------------------------------

local function gen_edm_pump()
  -- Instant drop to 0, exponential recovery to 1
  local v = {{0, 0}}
  local k = 5  -- recovery sharpness (higher = faster initial recovery)
  for i = 1, 15 do
    local x = i / 16
    local y = 1 - math.exp(-x * k)
    table.insert(v, {x, y})
  end
  table.insert(v, {0.99, 1})
  return v
end

local function gen_reverse_pump()
  -- Slow exponential descent to 0, snap back to 1 (cycling LFO use)
  local v = {}
  local k = 5
  for i = 0, 14 do
    local x = i / 16
    local y = math.exp(-x * k)        -- 1 → ~0
    table.insert(v, {x, y})
  end
  table.insert(v, {0.94, 0})
  table.insert(v, {0.95, 1})
  table.insert(v, {0.99, 1})
  return v
end

local function gen_double_tap()
  -- Two pumps in one cycle (kick on each half)
  local v = {}
  local k = 6
  -- First half: 0 → 1
  for i = 0, 7 do
    local x_local = i / 8
    local y = 1 - math.exp(-x_local * k)
    table.insert(v, {x_local * 0.49, y})
  end
  -- Second half: 0 → 1
  for i = 0, 7 do
    local x_local = i / 8
    local y = 1 - math.exp(-x_local * k)
    table.insert(v, {0.50 + x_local * 0.49, y})
  end
  table.insert(v, {0.99, 1})
  return v
end

local function gen_triple_tap()
  -- Three pumps in one cycle
  local v = {}
  local k = 7
  for seg = 0, 2 do
    local seg_start = seg / 3
    local seg_width = 1 / 3 - 0.005
    for i = 0, 5 do
      local x_local = i / 6
      local y = 1 - math.exp(-x_local * k)
      table.insert(v, {seg_start + x_local * seg_width, y})
    end
  end
  table.insert(v, {0.99, 1})
  return v
end

local function gen_kick_ghost()
  -- Tiny brief dip near the start, mostly flat at 1
  return {
    {0, 1},
    {0.01, 1},
    {0.02, 0.35},
    {0.04, 0.35},
    {0.06, 0.85},
    {0.10, 1},
    {0.99, 1}
  }
end

local function gen_bump_pump()
  -- Fast drop, two-stage release: rapid rise to 0.70, then slow climb to 1
  local v = {{0, 0}, {0.03, 0.45}, {0.07, 0.65}, {0.10, 0.70}}
  -- Slow climb from 0.70 to 1.0 over remaining 90%
  for i = 1, 12 do
    local t = i / 12
    local x = 0.10 + t * 0.89
    local y = 0.70 + 0.30 * t
    table.insert(v, {x, y})
  end
  table.insert(v, {0.99, 1})
  return v
end

local function gen_breath_pump()
  -- Smooth swell down, smooth swell back: cosine, but flatter at extremes
  -- y = 0.5 - 0.5*cos(2π * x^0.7) inverted — slow approach to dip, slow release
  local v = {}
  for i = 0, 15 do
    local x = i / 16
    -- Two-half cosine, asymmetric easing
    local phase
    if x < 0.5 then
      phase = (x / 0.5) ^ 0.85           -- ease-in to bottom
    else
      phase = 1 + ((x - 0.5) / 0.5) ^ 1.15 -- ease-out from bottom
    end
    -- y goes 1 → 0 → 1 across phase 0..2
    local y = 0.5 - 0.5 * math.cos(math.pi * phase)
    -- Invert so y starts at 0 (ducked at trigger), rises to 1, dips back, ends at 1
    -- Actually we want: start at 0, swell to 1, gentle stay. Simpler: half-cycle.
    -- Reformulate: 1 - 0.5*(1+cos(π*x)) = 0.5 - 0.5*cos(π*x)
    y = 0.5 - 0.5 * math.cos(math.pi * x)
    table.insert(v, {x, y})
  end
  table.insert(v, {0.99, 1})
  return v
end

local function gen_swing_duck()
  -- Asymmetric: deep early duck, fast release, then mild secondary dip
  return {
    {0, 0},
    {0.05, 0.30},
    {0.10, 0.55},
    {0.18, 0.85},
    {0.30, 1},
    {0.50, 1},
    {0.55, 0.70},
    {0.62, 0.55},
    {0.70, 0.75},
    {0.85, 1},
    {0.99, 1}
  }
end

------------------------------------------------------------------------
-- Inject Sidechain Shapes
------------------------------------------------------------------------

function PakettiSidechainCurvesInject()
  -- Make sure the parent shape table exists
  if not PakettiAutomationCurvesShapes then
    if PakettiAutomationCurvesInitShapes then
      PakettiAutomationCurvesInitShapes()
    else
      print("PakettiSidechainCurves: PakettiAutomationCurves not loaded — skipping injection")
      return
    end
  end

  local pack = {
    edmPump      = {values = gen_edm_pump(),     image = "bell-down.png",   label = "EDM Pump",      playmode = CURVES},
    reversePump  = {values = gen_reverse_pump(), image = "ramp-down.png",   label = "Reverse Pump",  playmode = CURVES},
    doubleTap    = {values = gen_double_tap(),   image = "bounce-up.png",   label = "Double Tap",    playmode = CURVES},
    tripleTap    = {values = gen_triple_tap(),   image = "bounce-up.png",   label = "Triple Tap",    playmode = CURVES},
    kickGhost    = {values = gen_kick_ghost(),   image = "pulse10.png",     label = "Kick Ghost",    playmode = POINTS},
    bumpPump     = {values = gen_bump_pump(),    image = "bell-down.png",   label = "Bump Pump",     playmode = CURVES},
    breathPump   = {values = gen_breath_pump(),  image = "sin-up.png",      label = "Breath Pump",   playmode = CURVES},
    swingDuck    = {values = gen_swing_duck(),   image = "sawtooth-up.png", label = "Swing Duck",    playmode = LINES}
  }

  for name, def in pairs(pack) do
    PakettiAutomationCurvesShapes[name] = def
  end

  print("PakettiSidechainCurves: injected 8 sidechain shapes")
end

------------------------------------------------------------------------
-- Apply Helper
------------------------------------------------------------------------

local function apply_sidechain_shape(shape_name)
  if not PakettiAutomationCurvesShapes or not PakettiAutomationCurvesShapes[shape_name] then
    PakettiSidechainCurvesInject()
  end
  if not PakettiAutomationCurvesWriteToLFOCustom then
    renoise.app():show_status("PakettiAutomationCurves not available")
    return
  end

  local rs = renoise.song()
  local device = rs and rs.selected_device
  if not device or device.name ~= "*LFO" then
    renoise.app():show_status("Select a *LFO device first (sidechain curves write to the selected LFO)")
    return
  end

  PakettiAutomationCurvesWriteToLFOCustom(shape_name)
end

------------------------------------------------------------------------
-- Registration: shape order for menus/keybindings
------------------------------------------------------------------------

local sidechain_shape_order = {
  "edmPump", "reversePump", "doubleTap", "tripleTap",
  "kickGhost", "bumpPump", "breathPump", "swingDuck"
}

-- Inject at load time so shapes are visible before any menu invocation
PakettiSidechainCurvesInject()

-- Menu entries
for _, shape_name in ipairs(sidechain_shape_order) do
  local label = PakettiAutomationCurvesShapes[shape_name].label or shape_name
  PakettiAddMenuEntry{
    name = "Main Menu:Tools:Paketti:DSP:Sidechain Curves:" .. label,
    invoke = function() apply_sidechain_shape(shape_name) end
  }
  PakettiAddMenuEntry{
    name = "DSP Device:Paketti:Sidechain Curves:" .. label,
    invoke = function() apply_sidechain_shape(shape_name) end
  }
end

-- Keybindings (3 colon-separated parts only — flat name part)
for _, shape_name in ipairs(sidechain_shape_order) do
  local label = PakettiAutomationCurvesShapes[shape_name].label or shape_name
  renoise.tool():add_keybinding{
    name = "Global:Paketti:Sidechain Curve " .. label,
    invoke = function() apply_sidechain_shape(shape_name) end
  }
end

-- MIDI mappings
for _, shape_name in ipairs(sidechain_shape_order) do
  local label = PakettiAutomationCurvesShapes[shape_name].label or shape_name
  renoise.tool():add_midi_mapping{
    name = "Paketti:Sidechain Curve " .. label,
    invoke = function(message)
      if message:is_trigger() then apply_sidechain_shape(shape_name) end
    end
  }
end
