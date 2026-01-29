-- PakettiAutomationCurves.lua
-- Paketti Enhanced Automation - Rapid automation envelope drawing with shape presets
-- Inspired by various automation tools, enhanced for Paketti workflow

-- Dialog and ViewBuilder references
PakettiAutomationCurvesDialog = nil
PakettiAutomationCurvesVb = nil

-- Control state
PakettiAutomationCurvesOffset = 0.0
PakettiAutomationCurvesAttenuation = 1.0
PakettiAutomationCurvesInputDivisor = 1
PakettiAutomationCurvesStepLength = 4
PakettiAutomationCurvesMoveBySelection = false

-- LFO Custom Waveform state
PakettiAutomationCurvesWriteToLFO = false
PakettiAutomationCurvesLFOEnvelopeLength = 64
PakettiAutomationCurvesSelectedShape = nil  -- Currently selected shape name

-- Automation Clipboard state
PakettiAutomationClipboard = {
  points = {},      -- Array of {relative_time, value, scaling}
  length = 0,       -- Original selection length in lines
  playmode = 1,     -- Original playmode for reference
  source_param = "" -- Source parameter name (for display)
}
PakettiAutomationClipboardPasteMode = "normal"  -- "normal", "stretch", "floodfill"

-- Shape data (initialized at load time)
PakettiAutomationCurvesShapes = nil
PakettiAutomationCurvesKeyMap = nil

-- Image path for bitmaps
PakettiAutomationCurvesImagePath = "images/automation_shapes/"

------------------------------------------------------------------------
-- Validation Helper Functions
------------------------------------------------------------------------

-- Clamp step length to valid range (1 to num_lines)
function PakettiAutomationCurvesClampStepLength(step_length, num_lines)
  if not num_lines or num_lines < 1 then
    num_lines = 1
  end
  if step_length < 1 then
    return 1
  elseif step_length > num_lines then
    return num_lines
  else
    return step_length
  end
end

------------------------------------------------------------------------
-- Shape Definitions
-- Each shape has: values (array of {x, y} points), key (keyboard shortcut)
------------------------------------------------------------------------

-- Resolution for calculated curves
PakettiAutomationCurveResolution = 16

-- Pre-calculate curved shapes
function PakettiAutomationCurvesCalculateShapes()
  local res = PakettiAutomationCurveResolution
  local sinUp_values = {}
  local sinDown_values = {}
  local circBr_values = {}
  local circTr_values = {}
  local circTl_values = {}
  local circBl_values = {}
  local cosUp_values = {}
  local cosDown_values = {}
  local bellUp_values = {}
  local bellDown_values = {}
  local sCurveUp_values = {}
  local sCurveDown_values = {}
  local bounceUp_values = {}
  local bounceDown_values = {}
  
  for i = 0, (res - 1) do
    local x = i / res
    
    -- Sine curves
    table.insert(sinUp_values, {x, math.sin(x * 3.141)})
    table.insert(sinDown_values, {x, 1 - math.sin(x * 3.141)})
    
    -- Circle quadrants
    table.insert(circBr_values, {x, 1 - math.sqrt(1 - x * x)})
    table.insert(circTr_values, {x, math.sqrt(1 - x * x)})
    table.insert(circTl_values, {x, math.sqrt(2 * x - x * x)})
    table.insert(circBl_values, {x, 1 - math.sqrt(2 * x - x * x)})
    
    -- Cosine curves
    table.insert(cosUp_values, {x, 1 - (0.5 * math.cos(x * 3.14) + 0.5)})
    table.insert(cosDown_values, {x, 0.5 * math.cos(x * 3.14) + 0.5})
    
    -- Bell curve (Gaussian)
    local gaussX = (x - 0.5) * 4
    local gaussY = math.exp(-gaussX * gaussX / 2)
    table.insert(bellUp_values, {x, gaussY})
    table.insert(bellDown_values, {x, 1 - gaussY})
    
    -- S-Curve (Sigmoid)
    local sigX = (x - 0.5) * 12
    local sigY = 1 / (1 + math.exp(-sigX))
    table.insert(sCurveUp_values, {x, sigY})
    table.insert(sCurveDown_values, {x, 1 - sigY})
    
    -- Bounce (decaying sine)
    local bounceDecay = math.exp(-x * 3)
    local bounceOsc = math.abs(math.sin(x * 3.141 * 4))
    table.insert(bounceUp_values, {x, (1 - bounceDecay * bounceOsc)})
    table.insert(bounceDown_values, {x, bounceDecay * bounceOsc})
  end
  
  -- Add final points
  table.insert(sinUp_values, {0.99, 0})
  table.insert(sinDown_values, {0.99, 1})
  table.insert(circBr_values, {0.99, 1})
  table.insert(circTr_values, {0.99, 0})
  table.insert(circTl_values, {0.99, 1})
  table.insert(circBl_values, {0.99, 0})
  table.insert(cosUp_values, {0.99, 1})
  table.insert(cosDown_values, {0.99, 0})
  table.insert(bellUp_values, {0.99, 0})
  table.insert(bellDown_values, {0.99, 1})
  table.insert(sCurveUp_values, {0.99, 1})
  table.insert(sCurveDown_values, {0.99, 0})
  table.insert(bounceUp_values, {0.99, 1})
  table.insert(bounceDown_values, {0.99, 0})
  
  return {
    sinUp = sinUp_values,
    sinDown = sinDown_values,
    circBr = circBr_values,
    circTr = circTr_values,
    circTl = circTl_values,
    circBl = circBl_values,
    cosUp = cosUp_values,
    cosDown = cosDown_values,
    bellUp = bellUp_values,
    bellDown = bellDown_values,
    sCurveUp = sCurveUp_values,
    sCurveDown = sCurveDown_values,
    bounceUp = bounceUp_values,
    bounceDown = bounceDown_values
  }
end

-- Calculate trapezoid shapes
function PakettiAutomationCurvesCalculateTrapezoid()
  local res = PakettiAutomationCurveResolution
  local trapUp_values = {{0, 0}, {1/3, 1/2}}
  local trapDown_values = {{0, 1}, {1/3, 1/2}}
  
  for i = 0, (math.floor(res / (3/2)) - 1) do
    local p = (2/3) * i / (math.floor(res / (3/2)))
    local x = 1/3 + p
    local h2 = (3/2) - (9/4) * p
    local y = (1/2) + (h2) * p + (((3/2) - h2) * p / 2)
    table.insert(trapUp_values, {x, y})
    table.insert(trapDown_values, {x, 1 - y})
  end
  
  table.insert(trapUp_values, {0.99, 1})
  table.insert(trapDown_values, {0.99, 0})
  
  return {
    trapUp = trapUp_values,
    trapDown = trapDown_values
  }
end

-- Initialize all shapes
function PakettiAutomationCurvesInitShapes()
  local calculated = PakettiAutomationCurvesCalculateShapes()
  local trapezoid = PakettiAutomationCurvesCalculateTrapezoid()
  
  PakettiAutomationCurvesShapes = {
    -- Ramps (linear)
    rampUp = {values = {{0, 0}, {0.99, 1}}, key = "q", image = "ramp-up.png", label = "Ramp Up"},
    rampDown = {values = {{0, 1}, {0.99, 0}}, key = "w", image = "ramp-down.png", label = "Ramp Down"},
    
    -- Circle quadrants
    circTl = {values = calculated.circTl, key = "e", image = "circ-tl.png", label = "Curve TL"},
    circTr = {values = calculated.circTr, key = "r", image = "circ-tr.png", label = "Curve TR"},
    
    -- Squares
    sqUp = {values = {{0, 0}, {0.5, 0}, {0.51, 1}, {0.99, 1}}, key = "t", image = "sq-up.png", label = "Square Up"},
    sqDown = {values = {{0, 1}, {0.5, 1}, {0.51, 0}, {0.99, 0}}, key = "y", image = "sq-down.png", label = "Square Down"},
    
    -- Trapezoids
    trapUp = {values = trapezoid.trapUp, key = "u", image = "trap-up.png", label = "Trapezoid Up"},
    trapDown = {values = trapezoid.trapDown, key = "i", image = "trap-down.png", label = "Trapezoid Down"},
    
    -- Triangle/Vee
    tri = {values = {{0, 0}, {0.5, 1}, {0.99, 0}}, key = "a", image = "tri.png", label = "Triangle"},
    vee = {values = {{0, 1}, {0.5, 0}, {0.99, 1}}, key = "s", image = "vee.png", label = "Vee"},
    
    -- Circle quadrants (bottom)
    circBl = {values = calculated.circBl, key = "d", image = "circ-bl.png", label = "Curve BL"},
    circBr = {values = calculated.circBr, key = "f", image = "circ-br.png", label = "Curve BR"},
    
    -- Sine
    sinUp = {values = calculated.sinUp, key = "g", image = "sin-up.png", label = "Sine Up"},
    sinDown = {values = calculated.sinDown, key = "h", image = "sin-down.png", label = "Sine Down"},
    
    -- Stairs
    stairUp = {values = {{0, 0}, {0.25, 0}, {0.26, 0.25}, {0.5, 0.25}, {0.51, 0.5}, {0.75, 0.5}, {0.76, 0.75}, {0.98, 0.75}, {0.99, 1}}, key = "z", image = "stair-up.png", label = "Stairs Up"},
    stairDown = {values = {{0, 1}, {0.25, 1}, {0.26, 0.75}, {0.5, 0.75}, {0.51, 0.5}, {0.75, 0.5}, {0.76, 0.25}, {0.98, 0.25}, {0.99, 0}}, key = "x", image = "stair-down.png", label = "Stairs Down"},
    
    -- Cosine
    cosUp = {values = calculated.cosUp, key = "c", image = "cos-up.png", label = "Cosine Up"},
    cosDown = {values = calculated.cosDown, key = "v", image = "cos-down.png", label = "Cosine Down"},
    
    -- On/Off constants (duty cycle 100% and 0%)
    off = {values = {{0, 0}, {0.99, 0}}, key = "1", image = "off.png", label = "Constant Off"},
    on = {values = {{0, 1}, {0.99, 1}}, key = "0", image = "on.png", label = "Constant On"},
    
    -- Bell curve (Gaussian)
    bellUp = {values = calculated.bellUp, key = "o", image = "bell-up.png", label = "Bell Up"},
    bellDown = {values = calculated.bellDown, key = "p", image = "bell-down.png", label = "Bell Down"},
    
    -- S-Curve (Sigmoid)
    sCurveUp = {values = calculated.sCurveUp, key = "j", image = "scurve-up.png", label = "S-Curve Up"},
    sCurveDown = {values = calculated.sCurveDown, key = "k", image = "scurve-down.png", label = "S-Curve Down"},
    
    -- Bounce
    bounceUp = {values = calculated.bounceUp, key = "l", image = "bounce-up.png", label = "Bounce Up"},
    bounceDown = {values = calculated.bounceDown, key = "b", image = "bounce-down.png", label = "Bounce Down"},
    
    -- Pulse variations in ascending order (10% to 90% duty cycle) - keys 2-9
    pulse10 = {values = {{0, 0}, {0.10, 0}, {0.11, 1}, {0.99, 1}}, key = "2", image = "pulse10.png", label = "Pulse 10%"},
    pulse25 = {values = {{0, 0}, {0.25, 0}, {0.26, 1}, {0.99, 1}}, key = "3", image = "pulse25.png", label = "Pulse 25%"},
    pulse33 = {values = {{0, 0}, {0.33, 0}, {0.34, 1}, {0.99, 1}}, key = "4", image = "pulse33.png", label = "Pulse 33%"},
    pulse50 = {values = {{0, 0}, {0.5, 0}, {0.51, 1}, {0.99, 1}}, key = "5", image = "pulse50.png", label = "Pulse 50%"},
    pulse66 = {values = {{0, 0}, {0.66, 0}, {0.67, 1}, {0.99, 1}}, key = "6", image = "pulse66.png", label = "Pulse 66%"},
    pulse75 = {values = {{0, 0}, {0.75, 0}, {0.76, 1}, {0.99, 1}}, key = "7", image = "pulse75.png", label = "Pulse 75%"},
    pulse80 = {values = {{0, 0}, {0.80, 0}, {0.81, 1}, {0.99, 1}}, key = "8", image = "pulse80.png", label = "Pulse 80%"},
    pulse90 = {values = {{0, 0}, {0.90, 0}, {0.91, 1}, {0.99, 1}}, key = "9", image = "pulse90.png", label = "Pulse 90%"},
    
    -- Random (generated at insert time)
    randomSmooth = {values = nil, key = "n", image = "random-smooth.png", generator = "smooth", label = "Random Smooth"},
    randomStep = {values = nil, key = "m", image = "random-step.png", generator = "step", label = "Random Step"},
    
    -- Sawtooth with overshoot
    sawtoothUp = {values = {{0, 0}, {0.8, 1.1}, {0.85, 0.95}, {0.9, 1.02}, {0.95, 0.99}, {0.99, 1}}, key = "comma", image = "sawtooth-up.png", label = "Sawtooth Up"},
    sawtoothDown = {values = {{0, 1}, {0.8, -0.1}, {0.85, 0.05}, {0.9, -0.02}, {0.95, 0.01}, {0.99, 0}}, key = "period", image = "sawtooth-down.png", label = "Sawtooth Down"}
  }
  
  -- Build reverse key map
  PakettiAutomationCurvesKeyMap = {}
  for name, shape in pairs(PakettiAutomationCurvesShapes) do
    if shape.key then
      PakettiAutomationCurvesKeyMap[shape.key] = name
    end
  end
end

------------------------------------------------------------------------
-- Get or Create Automation Envelope
------------------------------------------------------------------------
function PakettiAutomationCurvesGetAutomation()
  local ra = renoise.app()
  ra.window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
  
  local rs = renoise.song()
  local track = rs.selected_pattern_track
  local param = rs.selected_automation_parameter
  
  if not param then
    renoise.app():show_status("No automation parameter selected")
    return nil
  end
  
  local automation = track:find_automation(param)
  if automation == nil then
    automation = track:create_automation(param)
    print("PakettiAutomationCurves: Created new automation envelope for " .. param.name)
  end
  
  return automation
end

------------------------------------------------------------------------
-- Generate Random Values for Random Shapes
------------------------------------------------------------------------
function PakettiAutomationCurvesGenerateRandom(generator_type, num_points)
  local values = {}
  num_points = num_points or 16
  
  if generator_type == "smooth" then
    -- Smooth random using interpolation
    local prev = math.random()
    for i = 0, num_points - 1 do
      local x = i / num_points
      local target = math.random()
      local value = prev + (target - prev) * 0.3
      prev = value
      table.insert(values, {x, math.max(0, math.min(1, value))})
    end
  else
    -- Step random
    for i = 0, num_points - 1 do
      local x = i / num_points
      table.insert(values, {x, math.random()})
    end
  end
  
  table.insert(values, {0.99, values[#values][2]})
  return values
end

------------------------------------------------------------------------
-- Write Shape to LFO Custom Waveform
------------------------------------------------------------------------
function PakettiAutomationCurvesWriteToLFOCustom(shape_name)
  local rs = renoise.song()
  if not rs then
    renoise.app():show_status("No song loaded")
    return false
  end
  
  local device = rs.selected_device
  if not device then
    renoise.app():show_status("No device selected")
    return false
  end
  
  -- Check if device is an LFO
  if device.name ~= "*LFO" then
    renoise.app():show_status("Selected device is not an LFO (got: " .. device.name .. ")")
    return false
  end
  
  -- Get shape data
  local shape = PakettiAutomationCurvesShapes[shape_name]
  if not shape then
    renoise.app():show_status("Unknown shape: " .. tostring(shape_name))
    return false
  end
  
  -- Get or generate values
  local shape_values
  if shape.generator then
    shape_values = PakettiAutomationCurvesGenerateRandom(shape.generator, PakettiAutomationCurveResolution)
  else
    shape_values = shape.values
  end
  
  if not shape_values then
    renoise.app():show_status("No values for shape: " .. shape_name)
    return false
  end
  
  -- Store current LFO routing parameters (so we can restore them after XML injection)
  local stored_dest_track = device.parameters[1].value
  local stored_dest_effect = device.parameters[2].value
  local stored_dest_param = device.parameters[3].value
  local stored_amplitude = device.parameters[4].value
  local stored_offset = device.parameters[5].value
  local stored_frequency = device.parameters[6].value
  
  -- Get envelope length
  local envelope_length = PakettiAutomationCurvesLFOEnvelopeLength
  
  -- Convert shape values to LFO envelope points
  -- Shape values are {x, y} where x is 0.0-0.99 and y is 0.0-1.0
  -- LFO points are index,value,curve where index is 0 to (length-1)
  local points_xml = {}
  
  -- Apply offset and attenuation to values (same as automation curve logic)
  local offset = PakettiAutomationCurvesOffset
  local attenuation = PakettiAutomationCurvesAttenuation
  local divisor = PakettiAutomationCurvesInputDivisor
  
  -- Track which indices we've already added (to avoid duplicates)
  local added_indices = {}
  
  -- Loop through repetitions (1x to 8x repeat count)
  for slice = 0, (divisor - 1) do
    local slice_start = slice / divisor  -- Start position of this slice (0.0 to 1.0)
    local slice_width = 1 / divisor       -- Width of each slice
    
    for _, point in ipairs(shape_values) do
      local x_pos = point[1]  -- 0.0 to 0.99
      local y_val = point[2]  -- 0.0 to 1.0
      
      -- Apply offset and attenuation
      local val = offset + ((1 - offset) * y_val) * attenuation
      -- Clamp value to 0-1
      val = math.max(0, math.min(1, val))
      
      -- Scale x position to fit within this slice
      local scaled_x = slice_start + (x_pos * slice_width)
      
      -- Convert x position to envelope index
      local index = math.floor(scaled_x * envelope_length)
      if index >= envelope_length then
        index = envelope_length - 1
      end
      
      -- Only add if we haven't already added a point at this index
      if not added_indices[index] then
        added_indices[index] = true
        table.insert(points_xml, string.format('<Point>%d,%.6f,0.0</Point>', index, val))
      end
    end
  end
  
  local points_str = table.concat(points_xml, "\n        ")
  
  -- Build the LFO XML with Type=4 (Custom) and the custom envelope
  local lfo_xml = string.format([=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="LfoDevice">
    <IsMaximized>true</IsMaximized>
    <Amplitude>
      <Value>%.6f</Value>
    </Amplitude>
    <Offset>
      <Value>%.6f</Value>
    </Offset>
    <Frequency>
      <Value>%.6f</Value>
    </Frequency>
    <Type>
      <Value>4</Value>
    </Type>
    <CustomEnvelope>
      <PlayMode>Lines</PlayMode>
      <Length>%d</Length>
      <ValueQuantum>0.0</ValueQuantum>
      <Polarity>Unipolar</Polarity>
      <Points>
        %s
      </Points>
    </CustomEnvelope>
    <CustomEnvelopeOneShot>false</CustomEnvelopeOneShot>
    <UseAdjustedEnvelopeLength>true</UseAdjustedEnvelopeLength>
  </DeviceSlot>
</FilterDevicePreset>]=], stored_amplitude, stored_offset, stored_frequency, envelope_length, points_str)
  
  -- Inject the XML
  device.active_preset_data = lfo_xml
  
  -- Restore routing parameters (they get reset by XML injection)
  device.parameters[1].value = stored_dest_track
  device.parameters[2].value = stored_dest_effect
  device.parameters[3].value = stored_dest_param
  
  local label = shape.label or shape_name
  local repeat_str = divisor > 1 and (" x" .. divisor) or ""
  renoise.app():show_status("Wrote " .. label .. repeat_str .. " to LFO Custom Waveform (" .. envelope_length .. " points)")
  print("PakettiAutomationCurves: Wrote " .. shape_name .. " to LFO custom waveform with " .. envelope_length .. " points, repeat: " .. divisor .. "x")
  
  return true
end

------------------------------------------------------------------------
-- Insert Shape into Automation
------------------------------------------------------------------------
function PakettiAutomationCurvesInsert(shape_name)
  local rs = renoise.song()
  if not rs then
    renoise.app():show_status("No song loaded")
    return
  end
  
  -- If "Write to LFO" checkbox is enabled, write to LFO custom waveform instead
  if PakettiAutomationCurvesWriteToLFO then
    PakettiAutomationCurvesWriteToLFOCustom(shape_name)
    return
  end
  
  local pattern = rs.selected_pattern
  if not pattern then
    renoise.app():show_status("No pattern selected")
    return
  end
  
  local num_lines = pattern.number_of_lines
  if num_lines < 1 then
    num_lines = 1
  end
  
  -- Clamp step length to pattern length
  PakettiAutomationCurvesStepLength = PakettiAutomationCurvesClampStepLength(PakettiAutomationCurvesStepLength, num_lines)
  
  local current_line = rs.selected_line_index
  local step = PakettiAutomationCurvesStepLength
  
  local automation = PakettiAutomationCurvesGetAutomation()
  if not automation then
    return
  end
  
  -- Check for automation selection range
  local start_line, end_line
  local selection = automation.selection_range
  if selection and selection[1] and selection[2] then
    start_line = selection[1]
    end_line = selection[2]
    step = end_line - start_line
    print("PakettiAutomationCurves: Using selection range from " .. start_line .. " to " .. end_line)
  else
    -- No selection: write to full pattern
    start_line = 1
    end_line = num_lines + 1
    step = num_lines
    print("PakettiAutomationCurves: No selection, writing to full pattern (1 to " .. num_lines .. ")")
  end
  
  -- Get shape data
  local shape = PakettiAutomationCurvesShapes[shape_name]
  if not shape then
    renoise.app():show_status("Unknown shape: " .. tostring(shape_name))
    return
  end
  
  -- Get or generate values
  local shape_values
  if shape.generator then
    shape_values = PakettiAutomationCurvesGenerateRandom(shape.generator, PakettiAutomationCurveResolution)
  else
    shape_values = shape.values
  end
  
  if not shape_values then
    renoise.app():show_status("No values for shape: " .. shape_name)
    return
  end
  
  -- Clear existing points in range
  local old_points = automation.points
  local new_points = {}
  for _, v in pairs(old_points) do
    if v.time >= start_line and v.time < end_line then
      -- Skip points in the range we're about to fill
    else
      table.insert(new_points, v)
    end
  end
  automation.points = new_points
  
  -- Insert shape points with offset and attenuation
  local offset = PakettiAutomationCurvesOffset
  local attenuation = PakettiAutomationCurvesAttenuation
  local divisor = PakettiAutomationCurvesInputDivisor
  
  for slice = 0, (divisor - 1) do
    local start = slice / divisor * step
    for _, point in ipairs(shape_values) do
      local time = start_line + start + step * point[1] * (1 / divisor)
      local val = offset + ((1 - offset) * point[2]) * attenuation
      -- Clamp value to 0-1
      val = math.max(0, math.min(1, val))
      automation:add_point_at(time, val)
    end
  end
  
  -- Advance cursor by step length (only if not using selection range)
  if not selection or not selection[1] then
    local new_line = current_line + step
    while new_line > num_lines do
      new_line = new_line - num_lines
    end
    rs.selected_line_index = new_line
  end
  
  -- Move selection forward if checkbox is enabled and there was a selection
  if PakettiAutomationCurvesMoveBySelection and selection and selection[1] and selection[2] then
    local selection_length = end_line - start_line
    local new_start = end_line
    local new_end = end_line + selection_length
    
    -- Handle pattern boundary: clamp to pattern end if selection would exceed it
    if new_end > num_lines then
      new_end = num_lines
      -- Adjust start to maintain selection length if possible
      new_start = math.max(1, new_end - selection_length)
    end
    
    -- Set new selection range
    automation.selection_range = {new_start, new_end}
    
    -- Move cursor to new selection start
    rs.selected_line_index = new_start
    
    print("PakettiAutomationCurves: Moved selection from " .. start_line .. "-" .. end_line .. " to " .. new_start .. "-" .. new_end)
  end
  
  local label = shape.label or shape_name
  renoise.app():show_status("Inserted " .. label .. " (" .. step .. " lines)")
  print("PakettiAutomationCurves: Inserted " .. shape_name .. " at line " .. current_line .. " with step " .. step)
end

------------------------------------------------------------------------
-- Pattern Effect Functions
------------------------------------------------------------------------

function PakettiAutomationCurvesProcessPoints(process_func)
  local automation = PakettiAutomationCurvesGetAutomation()
  if not automation then
    return
  end
  
  local old_points = automation.points
  local new_points = {}
  
  for i, v in pairs(old_points) do
    local point = process_func(i, v)
    if point.value < 0 then point.value = 0 end
    if point.value > 1 then point.value = 1 end
    table.insert(new_points, point)
  end
  
  automation.points = new_points
end

function PakettiAutomationCurvesFadeIn()
  local rs = renoise.song()
  if not rs or not rs.selected_pattern then
    renoise.app():show_status("No pattern selected")
    return
  end
  local num_lines = rs.selected_pattern.number_of_lines
  if num_lines < 1 then
    num_lines = 1
  end
  PakettiAutomationCurvesProcessPoints(function(index, point)
    point.value = (point.time - 1) / num_lines * point.value
    return point
  end)
  renoise.app():show_status("Applied Fade In to automation")
end

function PakettiAutomationCurvesFadeOut()
  local rs = renoise.song()
  if not rs or not rs.selected_pattern then
    renoise.app():show_status("No pattern selected")
    return
  end
  local num_lines = rs.selected_pattern.number_of_lines
  if num_lines < 1 then
    num_lines = 1
  end
  PakettiAutomationCurvesProcessPoints(function(index, point)
    point.value = (1 - (point.time - 1) / num_lines) * point.value
    return point
  end)
  renoise.app():show_status("Applied Fade Out to automation")
end

function PakettiAutomationCurvesZeroOdd()
  PakettiAutomationCurvesProcessPoints(function(index, point)
    if index % 2 == 1 then point.value = 0 end
    return point
  end)
  renoise.app():show_status("Zeroed odd points")
end

function PakettiAutomationCurvesZeroEven()
  PakettiAutomationCurvesProcessPoints(function(index, point)
    if index % 2 == 0 then point.value = 0 end
    return point
  end)
  renoise.app():show_status("Zeroed even points")
end

function PakettiAutomationCurvesMaxOdd()
  PakettiAutomationCurvesProcessPoints(function(index, point)
    if index % 2 == 1 then point.value = 1 end
    return point
  end)
  renoise.app():show_status("Maxed odd points")
end

function PakettiAutomationCurvesMaxEven()
  PakettiAutomationCurvesProcessPoints(function(index, point)
    if index % 2 == 0 then point.value = 1 end
    return point
  end)
  renoise.app():show_status("Maxed even points")
end

-- Randomize existing points (selection-aware)
function PakettiAutomationCurvesRandomize(amount)
  amount = amount or 0.2
  local automation = PakettiAutomationCurvesGetAutomation()
  if not automation then
    return
  end
  
  local old_points = automation.points
  if #old_points == 0 then
    renoise.app():show_status("No automation points to randomize")
    return
  end
  
  local new_points = {}
  
  -- Check for selection range
  local selection = automation.selection_range
  local has_selection = selection and selection[1] and selection[2]
  local start_line, end_line
  if has_selection then
    start_line = selection[1]
    end_line = selection[2]
  end
  
  local randomized_count = 0
  for i, point in ipairs(old_points) do
    local new_point = {time = point.time, value = point.value}
    
    -- Randomize if no selection, or if point is within selection range
    if not has_selection or (point.time >= start_line and point.time < end_line) then
      local noise = (math.random() - 0.5) * 2 * amount
      new_point.value = new_point.value + noise
      -- Clamp value to 0-1
      if new_point.value < 0 then new_point.value = 0 end
      if new_point.value > 1 then new_point.value = 1 end
      randomized_count = randomized_count + 1
    end
    
    table.insert(new_points, new_point)
  end
  
  automation.points = new_points
  
  if has_selection then
    renoise.app():show_status("Randomized " .. randomized_count .. " points in selection")
  else
    renoise.app():show_status("Randomized " .. randomized_count .. " automation points")
  end
end

-- Smooth existing points
function PakettiAutomationCurvesSmooth()
  local automation = PakettiAutomationCurvesGetAutomation()
  if not automation or #automation.points < 3 then
    return
  end
  
  local old_points = automation.points
  local new_points = {}
  
  -- Keep first point unchanged
  table.insert(new_points, old_points[1])
  
  -- Smooth middle points
  for i = 2, #old_points - 1 do
    local prev = old_points[i - 1].value
    local curr = old_points[i].value
    local next_val = old_points[i + 1].value
    local smoothed = (prev + curr + next_val) / 3
    table.insert(new_points, {time = old_points[i].time, value = smoothed})
  end
  
  -- Keep last point unchanged
  table.insert(new_points, old_points[#old_points])
  
  automation.points = new_points
  renoise.app():show_status("Smoothed automation points")
end

-- Quantize to grid
function PakettiAutomationCurvesQuantize(grid_size)
  grid_size = grid_size or 0.125  -- Default to 8 steps
  PakettiAutomationCurvesProcessPoints(function(index, point)
    point.value = math.floor(point.value / grid_size + 0.5) * grid_size
    return point
  end)
  renoise.app():show_status("Quantized automation to " .. tostring(1 / grid_size) .. " steps")
end

------------------------------------------------------------------------
-- Automation Clipboard Functions
------------------------------------------------------------------------

-- Copy automation points from current selection to clipboard
function PakettiAutomationClipboardCopy()
  local rs = renoise.song()
  if not rs then
    renoise.app():show_status("No song loaded")
    return false
  end
  
  local pattern = rs.selected_pattern
  if not pattern then
    renoise.app():show_status("No pattern selected")
    return false
  end
  
  local param = rs.selected_automation_parameter
  if not param then
    renoise.app():show_status("No automation parameter selected")
    return false
  end
  
  local track = rs.selected_pattern_track
  local automation = track:find_automation(param)
  
  if not automation then
    renoise.app():show_status("No automation envelope found for " .. param.name)
    return false
  end
  
  -- Get selection range (or use full pattern if no selection)
  local selection = automation.selection_range
  local start_line, end_line
  local num_lines = pattern.number_of_lines
  
  if selection and selection[1] and selection[2] and selection[1] ~= selection[2] then
    start_line = selection[1]
    end_line = selection[2]
  else
    -- No selection, use full pattern
    start_line = 1
    end_line = num_lines + 1
  end
  
  -- Filter points within selection range
  local source_points = automation.points
  local clipboard_points = {}
  
  for _, point in ipairs(source_points) do
    if point.time >= start_line and point.time < end_line then
      -- Store with time normalized relative to selection start (0-based)
      local relative_time = point.time - start_line
      table.insert(clipboard_points, {
        relative_time = relative_time,
        value = point.value,
        scaling = point.scaling or 0
      })
    end
  end
  
  if #clipboard_points == 0 then
    renoise.app():show_status("No automation points in selection")
    return false
  end
  
  -- Store in clipboard
  PakettiAutomationClipboard.points = clipboard_points
  PakettiAutomationClipboard.length = end_line - start_line
  PakettiAutomationClipboard.playmode = automation.playmode
  PakettiAutomationClipboard.source_param = param.name
  
  renoise.app():show_status("Copied " .. #clipboard_points .. " points from " .. param.name .. " (" .. PakettiAutomationClipboard.length .. " lines)")
  print("PakettiAutomationClipboard: Copied " .. #clipboard_points .. " points, length: " .. PakettiAutomationClipboard.length)
  
  return true
end

-- Cut automation points (copy then clear)
function PakettiAutomationClipboardCut()
  local rs = renoise.song()
  if not rs then
    renoise.app():show_status("No song loaded")
    return false
  end
  
  local pattern = rs.selected_pattern
  if not pattern then
    renoise.app():show_status("No pattern selected")
    return false
  end
  
  local param = rs.selected_automation_parameter
  if not param then
    renoise.app():show_status("No automation parameter selected")
    return false
  end
  
  local track = rs.selected_pattern_track
  local automation = track:find_automation(param)
  
  if not automation then
    renoise.app():show_status("No automation envelope found for " .. param.name)
    return false
  end
  
  -- Get selection range before copying
  local selection = automation.selection_range
  local start_line, end_line
  local num_lines = pattern.number_of_lines
  
  if selection and selection[1] and selection[2] and selection[1] ~= selection[2] then
    start_line = selection[1]
    end_line = selection[2]
  else
    -- No selection, use full pattern
    start_line = 1
    end_line = num_lines + 1
  end
  
  -- Copy first
  local success = PakettiAutomationClipboardCopy()
  if not success then
    return false
  end
  
  -- Clear the range
  automation:clear_range(start_line, end_line)
  
  renoise.app():show_status("Cut " .. #PakettiAutomationClipboard.points .. " points from " .. param.name)
  print("PakettiAutomationClipboard: Cut " .. #PakettiAutomationClipboard.points .. " points")
  
  return true
end

-- Paste automation points to current parameter
function PakettiAutomationClipboardPaste()
  local rs = renoise.song()
  if not rs then
    renoise.app():show_status("No song loaded")
    return false
  end
  
  -- Check clipboard
  if not PakettiAutomationClipboard.points or #PakettiAutomationClipboard.points == 0 then
    renoise.app():show_status("Clipboard is empty - copy automation first")
    return false
  end
  
  local pattern = rs.selected_pattern
  if not pattern then
    renoise.app():show_status("No pattern selected")
    return false
  end
  
  local param = rs.selected_automation_parameter
  if not param then
    renoise.app():show_status("No automation parameter selected")
    return false
  end
  
  -- Get or create automation envelope
  local automation = PakettiAutomationCurvesGetAutomation()
  if not automation then
    return false
  end
  
  -- Get target selection range
  local selection = automation.selection_range
  local start_line, end_line
  local num_lines = pattern.number_of_lines
  local use_stretch = false
  
  if selection and selection[1] and selection[2] and selection[1] ~= selection[2] then
    start_line = selection[1]
    end_line = selection[2]
    -- If paste mode is stretch, scale to fit selection
    if PakettiAutomationClipboardPasteMode == "stretch" then
      use_stretch = true
    end
  else
    -- No selection, paste at cursor position
    start_line = rs.selected_line_index
    end_line = start_line + PakettiAutomationClipboard.length
    -- Clamp to pattern length
    if end_line > num_lines + 1 then
      end_line = num_lines + 1
    end
  end
  
  -- Clear target range first
  automation:clear_range(start_line, end_line)
  
  -- Calculate scaling factor for stretch mode
  local target_length = end_line - start_line
  local source_length = PakettiAutomationClipboard.length
  local scale = 1
  if use_stretch and source_length > 0 then
    scale = target_length / source_length
  end
  
  -- Paste points
  local points_added = 0
  for _, point in ipairs(PakettiAutomationClipboard.points) do
    local new_time
    if use_stretch then
      new_time = start_line + (point.relative_time * scale)
    else
      new_time = start_line + point.relative_time
    end
    
    -- Only add if within target range
    if new_time >= start_line and new_time < end_line then
      automation:add_point_at(new_time, point.value, point.scaling)
      points_added = points_added + 1
    end
  end
  
  local mode_str = use_stretch and " (stretched)" or ""
  renoise.app():show_status("Pasted " .. points_added .. " points to " .. param.name .. mode_str)
  print("PakettiAutomationClipboard: Pasted " .. points_added .. " points" .. mode_str)
  
  return true
end

-- Flood-fill: repeat clipboard pattern to fill selection or pattern
function PakettiAutomationClipboardFloodFill()
  local rs = renoise.song()
  if not rs then
    renoise.app():show_status("No song loaded")
    return false
  end
  
  -- Check clipboard
  if not PakettiAutomationClipboard.points or #PakettiAutomationClipboard.points == 0 then
    renoise.app():show_status("Clipboard is empty - copy automation first")
    return false
  end
  
  if PakettiAutomationClipboard.length <= 0 then
    renoise.app():show_status("Clipboard has invalid length")
    return false
  end
  
  local pattern = rs.selected_pattern
  if not pattern then
    renoise.app():show_status("No pattern selected")
    return false
  end
  
  local param = rs.selected_automation_parameter
  if not param then
    renoise.app():show_status("No automation parameter selected")
    return false
  end
  
  -- Get or create automation envelope
  local automation = PakettiAutomationCurvesGetAutomation()
  if not automation then
    return false
  end
  
  -- Get target selection range (or full pattern)
  local selection = automation.selection_range
  local start_line, end_line
  local num_lines = pattern.number_of_lines
  
  if selection and selection[1] and selection[2] and selection[1] ~= selection[2] then
    start_line = selection[1]
    end_line = selection[2]
  else
    -- No selection, use full pattern
    start_line = 1
    end_line = num_lines + 1
  end
  
  -- Clear target range first
  automation:clear_range(start_line, end_line)
  
  -- Calculate repetitions needed
  local target_length = end_line - start_line
  local source_length = PakettiAutomationClipboard.length
  local repetitions = math.ceil(target_length / source_length)
  
  -- Tile the pattern
  local points_added = 0
  for rep = 0, repetitions - 1 do
    local offset = rep * source_length
    for _, point in ipairs(PakettiAutomationClipboard.points) do
      local new_time = start_line + offset + point.relative_time
      -- Only add if within target range
      if new_time >= start_line and new_time < end_line then
        automation:add_point_at(new_time, point.value, point.scaling)
        points_added = points_added + 1
      end
    end
  end
  
  renoise.app():show_status("Flood-filled " .. param.name .. " with " .. repetitions .. " repetitions (" .. points_added .. " points)")
  print("PakettiAutomationClipboard: Flood-filled with " .. repetitions .. " reps, " .. points_added .. " points")
  
  return true
end

-- Paste with stretch mode (scales to fit target selection)
function PakettiAutomationClipboardPasteStretch()
  local old_mode = PakettiAutomationClipboardPasteMode
  PakettiAutomationClipboardPasteMode = "stretch"
  local result = PakettiAutomationClipboardPaste()
  PakettiAutomationClipboardPasteMode = old_mode
  return result
end

------------------------------------------------------------------------
-- Key Handler for Dialog
------------------------------------------------------------------------
function PakettiAutomationCurvesKeyHandler(dialog, key)
  local handled = false
  local rs = renoise.song()
  if not rs or not rs.selected_pattern then
    return key
  end
  
  local current_line = rs.selected_line_index
  local step = PakettiAutomationCurvesStepLength
  local num_lines = rs.selected_pattern.number_of_lines
  if num_lines < 1 then
    num_lines = 1
  end
  local closer = preferences.pakettiDialogClose.value
  
  print("PakettiAutomationCurves KEYHANDLER: name:'" .. tostring(key.name) .. "' modifiers:'" .. tostring(key.modifiers) .. "'")
  
  -- Close dialog with configured key
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    PakettiAutomationCurvesDialog = nil
    return nil
  end
  
  -- Pattern navigation emulation
  if key.name == "left" or key.name == "up" then
    if key.modifiers == "control" then step = 1 end
    local new_line = rs.selected_line_index - step
    while new_line < 1 do new_line = new_line + num_lines end
    rs.selected_line_index = new_line
    handled = true
  end
  
  if key.name == "right" or key.name == "down" then
    if key.modifiers == "control" then step = 1 end
    local new_line = rs.selected_line_index + step
    while new_line > num_lines do new_line = new_line - num_lines end
    rs.selected_line_index = new_line
    handled = true
  end
  
  -- Quadrant jump emulation (F9-F12)
  if key.name == "f9" then rs.selected_line_index = 1; handled = true end
  if key.name == "f10" then rs.selected_line_index = math.ceil(num_lines * 0.25) + 1; handled = true end
  if key.name == "f11" then rs.selected_line_index = math.ceil(num_lines * 0.50) + 1; handled = true end
  if key.name == "f12" then rs.selected_line_index = math.ceil(num_lines * 0.75) + 1; handled = true end
  
  -- Shift+Ctrl/Cmd+V for stretch paste (check before regular Ctrl/Cmd)
  if key.modifiers == "shift + control" or key.modifiers == "shift + meta" then
    if key.name == "v" then
      PakettiAutomationClipboardPasteStretch()
      handled = true
    end
  end
  
  -- Edit step emulation with Control/Cmd modifier (Mac and Windows support)
  if key.modifiers == "control" or key.modifiers == "meta" then
    if key.name == "`" then
      PakettiAutomationCurvesStepLength = PakettiAutomationCurvesClampStepLength(num_lines, num_lines)
      if PakettiAutomationCurvesVb and PakettiAutomationCurvesVb.views.step_length then
        PakettiAutomationCurvesVb.views.step_length.value = PakettiAutomationCurvesStepLength
      end
      handled = true
    end
    
    local num_keys = {"1", "2", "3", "4", "5", "6", "7", "8", "9"}
    local num_vals = {1, 2, 3, 4, 5, 6, 7, 8, 9}
    for idx, k in ipairs(num_keys) do
      if key.name == k then
        local new_val = num_vals[idx]
        PakettiAutomationCurvesStepLength = PakettiAutomationCurvesClampStepLength(new_val, num_lines)
        if PakettiAutomationCurvesVb and PakettiAutomationCurvesVb.views.step_length then
          PakettiAutomationCurvesVb.views.step_length.value = PakettiAutomationCurvesStepLength
        end
        handled = true
        break
      end
    end
    
    if key.name == "-" then
      if PakettiAutomationCurvesStepLength > 1 then
        PakettiAutomationCurvesStepLength = PakettiAutomationCurvesStepLength - 1
        PakettiAutomationCurvesStepLength = PakettiAutomationCurvesClampStepLength(PakettiAutomationCurvesStepLength, num_lines)
        if PakettiAutomationCurvesVb and PakettiAutomationCurvesVb.views.step_length then
          PakettiAutomationCurvesVb.views.step_length.value = PakettiAutomationCurvesStepLength
        end
      end
      handled = true
    end
    
    if key.name == "=" then
      if PakettiAutomationCurvesStepLength < num_lines then
        PakettiAutomationCurvesStepLength = PakettiAutomationCurvesStepLength + 1
        PakettiAutomationCurvesStepLength = PakettiAutomationCurvesClampStepLength(PakettiAutomationCurvesStepLength, num_lines)
        if PakettiAutomationCurvesVb and PakettiAutomationCurvesVb.views.step_length then
          PakettiAutomationCurvesVb.views.step_length.value = PakettiAutomationCurvesStepLength
        end
      end
      handled = true
    end
    
    -- Undo/Redo (Ctrl/Cmd+Z and Ctrl/Cmd+Y)
    if key.name == "z" then renoise.song():undo(); handled = true end
    if key.name == "y" then renoise.song():redo(); handled = true end
    
    -- Clipboard shortcuts (Ctrl/Cmd+X/C/V/F)
    if key.name == "x" then PakettiAutomationClipboardCut(); handled = true end
    if key.name == "c" then PakettiAutomationClipboardCopy(); handled = true end
    if key.name == "v" then PakettiAutomationClipboardPaste(); handled = true end
    if key.name == "f" then PakettiAutomationClipboardFloodFill(); handled = true end
  end
  
  -- Input divisor control with + and - keys (without modifiers)
  if key.modifiers == "" then
    if key.name == "-" then
      if PakettiAutomationCurvesInputDivisor > 1 then
        PakettiAutomationCurvesInputDivisor = PakettiAutomationCurvesInputDivisor - 1
        if PakettiAutomationCurvesVb and PakettiAutomationCurvesVb.views.input_divisor then
          PakettiAutomationCurvesVb.views.input_divisor.value = PakettiAutomationCurvesInputDivisor
        end
        renoise.app():show_status("Repeat Count: " .. PakettiAutomationCurvesInputDivisor .. "x")
        -- Auto-reapply if a shape is selected
        if PakettiAutomationCurvesSelectedShape then
          if PakettiAutomationCurvesWriteToLFO then
            PakettiAutomationCurvesWriteToLFOCustom(PakettiAutomationCurvesSelectedShape)
          else
            PakettiAutomationCurvesInsert(PakettiAutomationCurvesSelectedShape)
          end
        end
      end
      handled = true
    end
    
    if key.name == "+" then
      if PakettiAutomationCurvesInputDivisor < 8 then
        PakettiAutomationCurvesInputDivisor = PakettiAutomationCurvesInputDivisor + 1
        if PakettiAutomationCurvesVb and PakettiAutomationCurvesVb.views.input_divisor then
          PakettiAutomationCurvesVb.views.input_divisor.value = PakettiAutomationCurvesInputDivisor
        end
        renoise.app():show_status("Repeat Count: " .. PakettiAutomationCurvesInputDivisor .. "x")
        -- Auto-reapply if a shape is selected
        if PakettiAutomationCurvesSelectedShape then
          if PakettiAutomationCurvesWriteToLFO then
            PakettiAutomationCurvesWriteToLFOCustom(PakettiAutomationCurvesSelectedShape)
          else
            PakettiAutomationCurvesInsert(PakettiAutomationCurvesSelectedShape)
          end
        end
      end
      handled = true
    end
  end
  
  -- Shape keys (only without modifiers)
  if key.modifiers == "" and PakettiAutomationCurvesKeyMap and PakettiAutomationCurvesKeyMap[key.name] then
    local shape_name = PakettiAutomationCurvesKeyMap[key.name]
    -- Track the selected shape and update highlight
    local old_shape = PakettiAutomationCurvesSelectedShape
    PakettiAutomationCurvesSelectedShape = shape_name
    PakettiAutomationCurvesUpdateButtonHighlight(shape_name, old_shape)
    PakettiAutomationCurvesUpdateSelectedDisplay()
    -- Insert/write the shape
    PakettiAutomationCurvesInsert(shape_name)
    handled = true
  end
  
  if not handled then return key end
  return nil
end

------------------------------------------------------------------------
-- Read LFO Envelope Length from Device XML
------------------------------------------------------------------------
function PakettiAutomationCurvesReadLFOEnvelopeLength(device)
  if not device or device.name ~= "*LFO" then
    return nil
  end
  
  local xml_data = device.active_preset_data
  if not xml_data or xml_data == "" then
    return nil
  end
  
  -- Parse the Length from CustomEnvelope section
  local length = xml_data:match("<CustomEnvelope>.-<Length>(%d+)</Length>")
  if length then
    return tonumber(length)
  end
  
  return nil
end

------------------------------------------------------------------------
-- Get LFO Length Popup Index from Length Value
------------------------------------------------------------------------
function PakettiAutomationCurvesGetLFOLengthIndex(length)
  local lengths = {64, 128, 256, 512, 1024}
  for i, v in ipairs(lengths) do
    if v == length then
      return i
    end
  end
  -- Find closest match
  for i, v in ipairs(lengths) do
    if v >= length then
      return i
    end
  end
  return 5 -- Default to 1024 if larger
end

------------------------------------------------------------------------
-- Update Selected Shape Display
------------------------------------------------------------------------
function PakettiAutomationCurvesUpdateSelectedDisplay()
  if PakettiAutomationCurvesVb and PakettiAutomationCurvesVb.views.selected_shape_text then
    local shape = PakettiAutomationCurvesShapes[PakettiAutomationCurvesSelectedShape]
    if shape then
      local label = shape.label or PakettiAutomationCurvesSelectedShape
      PakettiAutomationCurvesVb.views.selected_shape_text.text = "Selected: " .. label
    else
      PakettiAutomationCurvesVb.views.selected_shape_text.text = "Selected: (none)"
    end
  end
end

------------------------------------------------------------------------
-- Update Button Highlight (visual selection feedback)
------------------------------------------------------------------------
function PakettiAutomationCurvesUpdateButtonHighlight(new_shape, old_shape)
  if not PakettiAutomationCurvesVb then return end
  
  -- Reset old button to plain mode
  if old_shape then
    local old_btn = PakettiAutomationCurvesVb.views["shape_btn_" .. old_shape]
    if old_btn then
      old_btn.mode = "plain"
    end
  end
  
  -- Highlight new button with main_color mode
  if new_shape then
    local new_btn = PakettiAutomationCurvesVb.views["shape_btn_" .. new_shape]
    if new_btn then
      new_btn.mode = "main_color"
    end
  end
end

------------------------------------------------------------------------
-- Build Shape Button
------------------------------------------------------------------------
function PakettiAutomationCurvesMakeButton(vb, shape_name)
  local shape = PakettiAutomationCurvesShapes[shape_name]
  if not shape then return vb:text{text = "?"} end
  
  local tooltip = shape.label or shape_name
  if shape.key then
    tooltip = tooltip .. " [" .. shape.key .. "]"
  end
  
  return vb:bitmap{
    id = "shape_btn_" .. shape_name,
    width = 48,
    height = 48,
    bitmap = PakettiAutomationCurvesImagePath .. shape.image,
    notifier = function()
      -- Track the selected shape and update highlight
      local old_shape = PakettiAutomationCurvesSelectedShape
      PakettiAutomationCurvesSelectedShape = shape_name
      PakettiAutomationCurvesUpdateButtonHighlight(shape_name, old_shape)
      PakettiAutomationCurvesUpdateSelectedDisplay()
      -- Insert/write the shape
      PakettiAutomationCurvesInsert(shape_name)
    end,
    tooltip = tooltip
  }
end

------------------------------------------------------------------------
-- Show Dialog
------------------------------------------------------------------------
function PakettiAutomationCurvesShowDialog()
  -- Initialize shapes if not done
  if not PakettiAutomationCurvesShapes then
    PakettiAutomationCurvesInitShapes()
  end
  
  -- Toggle: close if open, open if closed
  if PakettiAutomationCurvesDialog and PakettiAutomationCurvesDialog.visible then
    PakettiAutomationCurvesDialog:close()
    PakettiAutomationCurvesDialog = nil
    return
  end
  
  local rs = renoise.song()
  if not rs then
    renoise.app():show_status("No song loaded")
    return
  end
  
  local pattern = rs.selected_pattern
  if not pattern then
    renoise.app():show_status("No pattern selected")
    return
  end
  
  local num_lines = pattern.number_of_lines
  if num_lines < 1 then
    num_lines = 1
  end
  
  local edit_step = rs.transport.edit_step
  if edit_step < 1 then
    edit_step = 1
  end
  PakettiAutomationCurvesStepLength = PakettiAutomationCurvesClampStepLength(edit_step, num_lines)
  
  -- Auto-detect if selected device is an LFO (track DSP or sample FX chain)
  local selected_lfo = nil
  local lfo_envelope_length = nil
  
  -- Check track device first
  local track_device = rs.selected_device
  if track_device and track_device.name == "*LFO" then
    selected_lfo = track_device
  end
  
  -- Check sample FX chain device if in sample editor view
  if not selected_lfo then
    local sample_device = rs.selected_sample_device
    if sample_device and sample_device.name == "*LFO" then
      selected_lfo = sample_device
    end
  end
  
  -- If we found an LFO, auto-enable LFO mode and read its envelope length
  if selected_lfo then
    PakettiAutomationCurvesWriteToLFO = true
    lfo_envelope_length = PakettiAutomationCurvesReadLFOEnvelopeLength(selected_lfo)
    if lfo_envelope_length then
      PakettiAutomationCurvesLFOEnvelopeLength = lfo_envelope_length
      print("PakettiAutomationCurves: Auto-detected LFO with envelope length " .. lfo_envelope_length)
    end
  end
  
  local vb = renoise.ViewBuilder()
  PakettiAutomationCurvesVb = vb
  
  local content = vb:column{
    margin = 10,
    spacing = 4,
    
    -- Row 1: Shapes and sliders
    vb:row{
      spacing = 4,
      
      vb:column{
        spacing = 4,
        
        -- Row 1: 1 2 3 4 5 6 7 8 9 0 (number row - off/pulses/on, ascending duty cycle)
        vb:row{
          spacing = 4,
          PakettiAutomationCurvesMakeButton(vb, "off"),       -- 1 (0%)
          PakettiAutomationCurvesMakeButton(vb, "pulse10"),   -- 2 (10%)
          PakettiAutomationCurvesMakeButton(vb, "pulse25"),   -- 3 (25%)
          PakettiAutomationCurvesMakeButton(vb, "pulse33"),   -- 4 (33%)
          PakettiAutomationCurvesMakeButton(vb, "pulse50"),   -- 5 (50%)
          PakettiAutomationCurvesMakeButton(vb, "pulse66"),   -- 6 (66%)
          PakettiAutomationCurvesMakeButton(vb, "pulse75"),   -- 7 (75%)
          PakettiAutomationCurvesMakeButton(vb, "pulse80"),   -- 8 (80%)
          PakettiAutomationCurvesMakeButton(vb, "pulse90"),   -- 9 (90%)
          PakettiAutomationCurvesMakeButton(vb, "on")         -- 0 (100%)
        },
        
        -- Row 2: q w e r t y u i o p (10 shapes)
        vb:row{
          spacing = 4,
          PakettiAutomationCurvesMakeButton(vb, "rampUp"),
          PakettiAutomationCurvesMakeButton(vb, "rampDown"),
          PakettiAutomationCurvesMakeButton(vb, "circTl"),
          PakettiAutomationCurvesMakeButton(vb, "circTr"),
          PakettiAutomationCurvesMakeButton(vb, "sqUp"),
          PakettiAutomationCurvesMakeButton(vb, "sqDown"),
          PakettiAutomationCurvesMakeButton(vb, "trapUp"),
          PakettiAutomationCurvesMakeButton(vb, "trapDown"),
          PakettiAutomationCurvesMakeButton(vb, "bellUp"),
          PakettiAutomationCurvesMakeButton(vb, "bellDown")
        },
        
        -- Row 3: a s d f g h j k l (9 shapes)
        vb:row{
          spacing = 4,
          PakettiAutomationCurvesMakeButton(vb, "tri"),
          PakettiAutomationCurvesMakeButton(vb, "vee"),
          PakettiAutomationCurvesMakeButton(vb, "circBl"),
          PakettiAutomationCurvesMakeButton(vb, "circBr"),
          PakettiAutomationCurvesMakeButton(vb, "sinUp"),
          PakettiAutomationCurvesMakeButton(vb, "sinDown"),
          PakettiAutomationCurvesMakeButton(vb, "sCurveUp"),
          PakettiAutomationCurvesMakeButton(vb, "sCurveDown"),
          PakettiAutomationCurvesMakeButton(vb, "bounceUp")
        },
        
        -- Row 4: z x c v b n m , . (stairs, cosine, bounce, random, sawtooth)
        vb:row{
          spacing = 4,
          PakettiAutomationCurvesMakeButton(vb, "stairUp"),      -- z
          PakettiAutomationCurvesMakeButton(vb, "stairDown"),    -- x
          PakettiAutomationCurvesMakeButton(vb, "cosUp"),        -- c
          PakettiAutomationCurvesMakeButton(vb, "cosDown"),      -- v
          PakettiAutomationCurvesMakeButton(vb, "bounceDown"),   -- b
          PakettiAutomationCurvesMakeButton(vb, "randomSmooth"), -- n
          PakettiAutomationCurvesMakeButton(vb, "randomStep"),   -- m
          PakettiAutomationCurvesMakeButton(vb, "sawtoothUp"),   -- , (comma)
          PakettiAutomationCurvesMakeButton(vb, "sawtoothDown")  -- . (period)
        }
      },
      
      -- Offset minislider (baseline)
      vb:column{
        vb:text{text = "Off", font = "mono", style = "disabled"},
        vb:minislider{
          id = "offset_slider",
          min = 0.0,
          max = 1.0,
          value = PakettiAutomationCurvesOffset,
          width = renoise.ViewBuilder.DEFAULT_CONTROL_HEIGHT,
          height = 200,
          notifier = function(value)
            PakettiAutomationCurvesOffset = value
          end
        }
      },
      
      -- Attenuation minislider (scale)
      vb:column{
        vb:text{text = "Att", font = "mono", style = "disabled"},
        vb:minislider{
          id = "attenuation_slider",
          min = 0.0,
          max = 1.0,
          value = PakettiAutomationCurvesAttenuation,
          width = renoise.ViewBuilder.DEFAULT_CONTROL_HEIGHT,
          height = 200,
          notifier = function(value)
            PakettiAutomationCurvesAttenuation = value
          end
        }
      }
    },
    
    -- Controls row
    vb:row{
      vb:column{
        spacing = 2,
        vb:text{text = "Step Length:"},
        vb:text{text = "Repeat Count:"},
        vb:text{text = "Effects:"}
      },
      vb:column{
        spacing = 2,
        
        -- Step length controls
        vb:row{
          vb:valuebox{
            id = "step_length",
            min = 1,
            max = math.max(1, num_lines),
            value = PakettiAutomationCurvesClampStepLength(PakettiAutomationCurvesStepLength, num_lines),
            width = 60,
            notifier = function(value)
              PakettiAutomationCurvesStepLength = PakettiAutomationCurvesClampStepLength(value, num_lines)
            end
          },
          vb:button{
            text = "Halve",
            notifier = function()
              PakettiAutomationCurvesStepLength = math.max(1, math.floor(PakettiAutomationCurvesStepLength / 2))
              PakettiAutomationCurvesStepLength = PakettiAutomationCurvesClampStepLength(PakettiAutomationCurvesStepLength, num_lines)
              vb.views.step_length.value = PakettiAutomationCurvesStepLength
            end
          },
          vb:button{
            text = "Double",
            notifier = function()
              PakettiAutomationCurvesStepLength = math.min(num_lines, PakettiAutomationCurvesStepLength * 2)
              PakettiAutomationCurvesStepLength = PakettiAutomationCurvesClampStepLength(PakettiAutomationCurvesStepLength, num_lines)
              vb.views.step_length.value = PakettiAutomationCurvesStepLength
            end
          }
        },
        
        -- Move by selection checkbox
        vb:row{
          vb:checkbox{
            id = "move_by_selection",
            value = PakettiAutomationCurvesMoveBySelection,
            notifier = function(value)
              PakettiAutomationCurvesMoveBySelection = value
            end
          },
          vb:text{text = "Move by selection"}
        },
        
        -- Write to LFO Custom Waveform checkbox
        vb:row{
          vb:checkbox{
            id = "write_to_lfo",
            value = PakettiAutomationCurvesWriteToLFO,
            notifier = function(value)
              PakettiAutomationCurvesWriteToLFO = value
              -- Update UI to show/hide LFO-specific controls
              if PakettiAutomationCurvesVb then
                if PakettiAutomationCurvesVb.views.lfo_length_row then
                  PakettiAutomationCurvesVb.views.lfo_length_row.visible = value
                end
                if PakettiAutomationCurvesVb.views.selected_shape_row then
                  PakettiAutomationCurvesVb.views.selected_shape_row.visible = value
                end
              end
            end
          },
          vb:text{text = "Write to LFO Custom Waveform"}
        },
        
        -- LFO envelope length selector (visible when LFO mode is enabled)
        vb:row{
          id = "lfo_length_row",
          visible = PakettiAutomationCurvesWriteToLFO,
          vb:text{text = "LFO Length:"},
          vb:popup{
            id = "lfo_length",
            width = 80,
            value = PakettiAutomationCurvesGetLFOLengthIndex(PakettiAutomationCurvesLFOEnvelopeLength),
            items = {"64", "128", "256", "512", "1024"},
            notifier = function(idx)
              local lengths = {64, 128, 256, 512, 1024}
              PakettiAutomationCurvesLFOEnvelopeLength = lengths[idx]
              -- Auto-reapply if in LFO mode and a shape is selected
              if PakettiAutomationCurvesWriteToLFO and PakettiAutomationCurvesSelectedShape then
                PakettiAutomationCurvesWriteToLFOCustom(PakettiAutomationCurvesSelectedShape)
              end
            end
          }
        },
        
        -- Selected shape display (visible when LFO mode is enabled)
        vb:row{
          id = "selected_shape_row",
          visible = PakettiAutomationCurvesWriteToLFO,
          vb:text{
            id = "selected_shape_text",
            text = "Selected: (none)",
            font = "bold"
          }
        },
        
        -- Input divisor switch (Repeat Count)
        vb:row{
          vb:switch{
            id = "input_divisor",
            width = 341,
            value = 1,
            items = {"1x", "2x", "3x", "4x", "5x", "6x", "7x", "8x"},
            notifier = function(val)
              PakettiAutomationCurvesInputDivisor = val
              renoise.app():show_status("Repeat Count: " .. val .. "x")
              -- Auto-reapply if a shape is selected
              if PakettiAutomationCurvesSelectedShape then
                if PakettiAutomationCurvesWriteToLFO then
                  PakettiAutomationCurvesWriteToLFOCustom(PakettiAutomationCurvesSelectedShape)
                else
                  PakettiAutomationCurvesInsert(PakettiAutomationCurvesSelectedShape)
                end
              end
            end
          }
        },
        
        -- Pattern effects buttons
        vb:row{
          vb:button{text = "Fade In", notifier = PakettiAutomationCurvesFadeIn},
          vb:button{text = "Fade Out", notifier = PakettiAutomationCurvesFadeOut},
          vb:button{text = "Zero Odd", notifier = PakettiAutomationCurvesZeroOdd},
          vb:button{text = "Zero Even", notifier = PakettiAutomationCurvesZeroEven},
          vb:button{text = "Max Odd", notifier = PakettiAutomationCurvesMaxOdd},
          vb:button{text = "Max Even", notifier = PakettiAutomationCurvesMaxEven}
        },
        
        -- Additional effects
        vb:row{
          vb:button{text = "Randomize", notifier = function() PakettiAutomationCurvesRandomize(0.2) end},
          vb:button{text = "Smooth", notifier = PakettiAutomationCurvesSmooth},
          vb:button{text = "Quantize 8", notifier = function() PakettiAutomationCurvesQuantize(0.125) end},
          vb:button{text = "Quantize 16", notifier = function() PakettiAutomationCurvesQuantize(0.0625) end}
        },
        
        -- Clipboard row
        vb:row{
          spacing = 4,
          vb:text{text = "Clipboard:"},
          vb:button{text = "Cut", width = 50, notifier = PakettiAutomationClipboardCut},
          vb:button{text = "Copy", width = 50, notifier = PakettiAutomationClipboardCopy},
          vb:button{text = "Paste", width = 50, notifier = PakettiAutomationClipboardPaste},
          vb:button{text = "Flood", width = 50, notifier = PakettiAutomationClipboardFloodFill},
          vb:popup{
            id = "paste_mode",
            width = 80,
            items = {"Normal", "Stretch", "Flood"},
            value = 1,
            notifier = function(idx)
              local modes = {"normal", "stretch", "floodfill"}
              PakettiAutomationClipboardPasteMode = modes[idx]
              renoise.app():show_status("Paste mode: " .. PakettiAutomationClipboardPasteMode)
            end
          }
        }
      }
    }
  }
  
  PakettiAutomationCurvesDialog = renoise.app():show_custom_dialog(
    "Paketti Enhanced Automation",
    content,
    PakettiAutomationCurvesKeyHandler
  )
  
  -- Ensure Renoise gets keyboard focus
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

------------------------------------------------------------------------
-- Initialize shapes at load time
------------------------------------------------------------------------
PakettiAutomationCurvesInitShapes()

------------------------------------------------------------------------
-- Menu Entries, Key Bindings, MIDI Mappings
------------------------------------------------------------------------

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti Gadgets:Enhanced Automation (Curves)...",
  invoke = PakettiAutomationCurvesShowDialog
}

renoise.tool():add_menu_entry{
  name = "Track Automation:Paketti Gadgets:Enhanced Automation (Curves)...",
  invoke = PakettiAutomationCurvesShowDialog
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Enhanced Automation (Curves) Dialog",
  invoke = PakettiAutomationCurvesShowDialog
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Enhanced Automation (Curves) Dialog",
  invoke = function(message)
    if message:is_trigger() then
      PakettiAutomationCurvesShowDialog()
    end
  end
}

-- Individual shape keybindings
local shape_list = {
  "rampUp", "rampDown", "circTl", "circTr", "sqUp", "sqDown", "trapUp", "trapDown",
  "tri", "vee", "circBl", "circBr", "sinUp", "sinDown",
  "stairUp", "stairDown", "cosUp", "cosDown", "on", "off",
  "bellUp", "bellDown", "sCurveUp", "sCurveDown", "bounceUp", "bounceDown",
  "pulse10", "pulse25", "pulse50", "pulse75", "pulse80", "randomSmooth", "randomStep", "sawtoothUp", "sawtoothDown"
}

for _, shape_name in ipairs(shape_list) do
  local label = PakettiAutomationCurvesShapes[shape_name].label or shape_name
  renoise.tool():add_keybinding{
    name = "Global:Paketti:Automation Curve Insert " .. label,
    invoke = function()
      PakettiAutomationCurvesInsert(shape_name)
    end
  }
end

-- Pattern effect keybindings
renoise.tool():add_keybinding{
  name = "Global:Paketti:Automation Curves Fade In",
  invoke = PakettiAutomationCurvesFadeIn
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Automation Curves Fade Out",
  invoke = PakettiAutomationCurvesFadeOut
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Automation Curves Zero Odd",
  invoke = PakettiAutomationCurvesZeroOdd
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Automation Curves Zero Even",
  invoke = PakettiAutomationCurvesZeroEven
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Automation Curves Max Odd",
  invoke = PakettiAutomationCurvesMaxOdd
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Automation Curves Max Even",
  invoke = PakettiAutomationCurvesMaxEven
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Automation Curves Randomize",
  invoke = function() PakettiAutomationCurvesRandomize(0.2) end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Automation Curves Smooth",
  invoke = PakettiAutomationCurvesSmooth
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Automation Curves Quantize",
  invoke = function() PakettiAutomationCurvesQuantize(0.125) end
}

------------------------------------------------------------------------
-- Automation Clipboard Menu Entries, Keybindings, and MIDI Mappings
------------------------------------------------------------------------

-- Menu Entries for Track Automation
renoise.tool():add_menu_entry{
  name = "Track Automation:Paketti:Automation Clipboard Cut",
  invoke = PakettiAutomationClipboardCut
}

renoise.tool():add_menu_entry{
  name = "Track Automation:Paketti:Automation Clipboard Copy",
  invoke = PakettiAutomationClipboardCopy
}

renoise.tool():add_menu_entry{
  name = "Track Automation:Paketti:Automation Clipboard Paste",
  invoke = PakettiAutomationClipboardPaste
}

renoise.tool():add_menu_entry{
  name = "Track Automation:Paketti:Automation Clipboard Paste (Stretch)",
  invoke = PakettiAutomationClipboardPasteStretch
}

renoise.tool():add_menu_entry{
  name = "Track Automation:Paketti:Automation Clipboard Flood-Fill",
  invoke = PakettiAutomationClipboardFloodFill
}

-- Menu Entries for Track Automation List
renoise.tool():add_menu_entry{
  name = "Track Automation List:Paketti:Automation Clipboard Cut",
  invoke = PakettiAutomationClipboardCut
}

renoise.tool():add_menu_entry{
  name = "Track Automation List:Paketti:Automation Clipboard Copy",
  invoke = PakettiAutomationClipboardCopy
}

renoise.tool():add_menu_entry{
  name = "Track Automation List:Paketti:Automation Clipboard Paste",
  invoke = PakettiAutomationClipboardPaste
}

renoise.tool():add_menu_entry{
  name = "Track Automation List:Paketti:Automation Clipboard Paste (Stretch)",
  invoke = PakettiAutomationClipboardPasteStretch
}

renoise.tool():add_menu_entry{
  name = "Track Automation List:Paketti:Automation Clipboard Flood-Fill",
  invoke = PakettiAutomationClipboardFloodFill
}

-- Keybindings
renoise.tool():add_keybinding{
  name = "Automation:Paketti:Automation Clipboard Cut",
  invoke = function(repeated)
    if not repeated then PakettiAutomationClipboardCut() end
  end
}

renoise.tool():add_keybinding{
  name = "Automation:Paketti:Automation Clipboard Copy",
  invoke = function(repeated)
    if not repeated then PakettiAutomationClipboardCopy() end
  end
}

renoise.tool():add_keybinding{
  name = "Automation:Paketti:Automation Clipboard Paste",
  invoke = function(repeated)
    if not repeated then PakettiAutomationClipboardPaste() end
  end
}

renoise.tool():add_keybinding{
  name = "Automation:Paketti:Automation Clipboard Paste (Stretch)",
  invoke = function(repeated)
    if not repeated then PakettiAutomationClipboardPasteStretch() end
  end
}

renoise.tool():add_keybinding{
  name = "Automation:Paketti:Automation Clipboard Flood-Fill",
  invoke = function(repeated)
    if not repeated then PakettiAutomationClipboardFloodFill() end
  end
}

-- MIDI Mappings
renoise.tool():add_midi_mapping{
  name = "Paketti:Automation Clipboard Cut x[Toggle]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiAutomationClipboardCut()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Automation Clipboard Copy x[Toggle]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiAutomationClipboardCopy()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Automation Clipboard Paste x[Toggle]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiAutomationClipboardPaste()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Automation Clipboard Paste (Stretch) x[Toggle]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiAutomationClipboardPasteStretch()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Automation Clipboard Flood-Fill x[Toggle]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiAutomationClipboardFloodFill()
    end
  end
}