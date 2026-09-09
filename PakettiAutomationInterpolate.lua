-- PakettiAutomationInterpolate.lua
-- Issue #423: automation from beginning point to endpoint, with curves / lines
-- Reads the value at the start and end of the current automation selection
-- (or the whole pattern when nothing is selected) and rewrites the points in
-- between along a chosen curve shape. Unlike PakettiAutomationCurvesInsert,
-- which stamps a normalized 0..1 shape scaled by global offset/attenuation,
-- this honours the two REAL endpoint values - it is Renoise's Ctrl+I with
-- curve options.

-- Shape functions: map t in [0,1] -> eased t in [0,1].
local PakettiAutomationInterpolateShapes = {
  ["Linear"]      = function(t) return t end,
  ["Ease In"]     = function(t) return t * t end,
  ["Ease Out"]    = function(t) return 1 - (1 - t) * (1 - t) end,
  ["Ease In-Out"] = function(t)
    if t < 0.5 then return 2 * t * t end
    return 1 - ((-2 * t + 2) ^ 2) / 2
  end,
  ["Exponential"] = function(t)
    if t <= 0 then return 0 end
    return (2 ^ (10 * (t - 1)))
  end,
  ["Logarithmic"] = function(t)
    if t >= 1 then return 1 end
    return 1 - (2 ^ (-10 * t))
  end,
  ["S-Curve"]     = function(t) return t * t * (3 - 2 * t) end,
}

-- Order used to build menu entries / keybindings.
local PakettiAutomationInterpolateOrder = {
  "Linear", "Ease In", "Ease Out", "Ease In-Out",
  "Exponential", "Logarithmic", "S-Curve"
}

-- Read the automation value at a fractional line by linearly walking the
-- existing points. Returns nil when there are no points at all.
local function value_at_time(points, time)
  if not points or #points == 0 then return nil end
  -- Before the first point / after the last: clamp to the edge value.
  if time <= points[1].time then return points[1].value end
  if time >= points[#points].time then return points[#points].value end
  for i = 1, #points - 1 do
    local a = points[i]
    local b = points[i + 1]
    if time >= a.time and time <= b.time then
      local span = b.time - a.time
      if span <= 0 then return a.value end
      local frac = (time - a.time) / span
      return a.value + (b.value - a.value) * frac
    end
  end
  return points[#points].value
end

function PakettiAutomationInterpolateSelection(shape_name)
  local shape = PakettiAutomationInterpolateShapes[shape_name]
  if not shape then
    renoise.app():show_status("Unknown interpolation shape: " .. tostring(shape_name))
    return
  end

  local rs = renoise.song()
  if not rs then
    renoise.app():show_status("No song loaded")
    return
  end

  local automation = PakettiAutomationCurvesGetAutomation()
  if not automation then
    -- Helper already showed a status about the missing parameter.
    return
  end

  local pattern = rs.selected_pattern
  local num_lines = pattern and pattern.number_of_lines or automation.length
  if num_lines < 2 then
    renoise.app():show_status("Pattern is too short to interpolate")
    return
  end

  -- Determine the range. selection_start/selection_end are 1-based lines;
  -- when there is no selection they read as the full length.
  local start_line = automation.selection_start
  local end_line = automation.selection_end
  local have_selection = start_line and end_line and end_line > start_line
    and not (start_line == 1 and end_line >= num_lines)

  if not have_selection then
    start_line = 1
    end_line = num_lines
  end
  if end_line <= start_line then
    renoise.app():show_status("Selection is too small to interpolate")
    return
  end

  -- Endpoint values: prefer existing points at the ends, otherwise fall back
  -- to the current parameter value so a fresh envelope still does something
  -- sensible.
  -- value_at_time returns nil only when the envelope has no points at all;
  -- in that case default to a clean 0 -> 1 ramp (automation values are the
  -- normalized 0..1 range, so we can't reuse the parameter's real value).
  local points = automation.points
  local v_start = value_at_time(points, start_line)
  local v_end = value_at_time(points, end_line)
  if v_start == nil then v_start = 0.0 end
  if v_end == nil then v_end = 1.0 end

  -- Clear the interior so we can rewrite it cleanly.
  automation:clear_range(start_line, end_line)

  -- Linear uses the LINES playmode (crisp), everything else uses CURVES.
  if shape_name == "Linear" then
    automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_LINES
  else
    automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_CURVES
  end

  -- Write a point per line across the range. Endpoints are placed exactly.
  local span = end_line - start_line
  for line = start_line, end_line do
    local t = (line - start_line) / span
    local eased = shape(t)
    if eased < 0 then eased = 0 elseif eased > 1 then eased = 1 end
    local val = v_start + (v_end - v_start) * eased
    if val < 0 then val = 0 elseif val > 1 then val = 1 end
    automation:add_point_at(line, val, 0.0)
  end

  renoise.app():show_status(string.format(
    "Interpolated %s from line %d (%.3f) to line %d (%.3f)",
    shape_name, start_line, v_start, end_line, v_end))
end

-- Registrations -------------------------------------------------------------
for _, shape_name in ipairs(PakettiAutomationInterpolateOrder) do
  local name = shape_name
  PakettiAddMenuEntry{
    name = "Main Menu:Tools:Paketti:Automation:Interpolate Selection (" .. name .. ")",
    invoke = function() PakettiAutomationInterpolateSelection(name) end
  }
  renoise.tool():add_keybinding{
    name = "Global:Paketti:Automation Interpolate Selection " .. name,
    invoke = function() PakettiAutomationInterpolateSelection(name) end
  }
  renoise.tool():add_midi_mapping{
    name = "Paketti:Automation Interpolate Selection " .. name .. " [Trigger]",
    invoke = function(message)
      if message:is_trigger() then PakettiAutomationInterpolateSelection(name) end
    end
  }
end
