-- PakettiInterpolateBeyond.lua
-- Cross-pattern, multi-shape column interpolation, ported from GARBANZO's
-- "Interpolate Beyond" (rfgd.garbanzo.InterpolateBeyond).
--
-- Unlike Renoise's built-in interpolation (linear, within one pattern selection)
-- and Paketti's own Interpolate Column Values (selection-based, linear/exp), this
-- works from the CURSOR with no selection: it finds the previous and next
-- non-empty value in the current sub-column, searching ACROSS pattern boundaries
-- along the sequence ("Beyond"), and interpolates between them through the cursor.
-- If only one point is found it extends to the start or end of the track.
--
-- It offers a family of interpolation shapes — linear, log in/out, sine, square,
-- saw, triangle, bounce in/out, gradient noise — chosen per menu entry / keybind.
-- The number of oscillations for the wave shapes is taken from the Edit Step
-- (transport.edit_step), matching the original tool's behaviour.
--
-- Works on the sub-column under the cursor: note-column volume / panning / delay /
-- sample-effect amount, or effect-column amount.

-- Deliberate fixes vs. the original: functions are file-local (no global
-- pollution), the undeclared global write (end_effect_number_value) is scoped,
-- dead code (parameterOldFunc, isSample) is dropped, integer writes are rounded,
-- and a guard rejects note/instrument sub-columns where interpolation is meaningless.

----------------------------------------------------------------------
-- sequence <-> pattern helpers
----------------------------------------------------------------------
local function pattern_from_sequence(index)
  local seq = renoise.song().sequencer
  if index <= #seq.pattern_sequence then
    return renoise.song():pattern(seq.pattern_sequence[index])
  end
  return nil
end

local function findPatternIndex(patternObj)
  for index, pattern in ipairs(renoise.song().patterns) do
    if pattern == patternObj then return index end
  end
  return nil
end

local function patternID_from_sequenceID(seqID)
  return findPatternIndex(pattern_from_sequence(seqID))
end

----------------------------------------------------------------------
-- sub-column emptiness / equality
----------------------------------------------------------------------
local function isLineEmpty(lineID, columnID, patTrack, subColumnID)
  local s = renoise.Song
  local str
  if subColumnID == s.SUB_COLUMN_VOLUME then
    str = patTrack:line(lineID).note_columns[columnID].volume_string
  elseif subColumnID == s.SUB_COLUMN_PANNING then
    str = patTrack:line(lineID).note_columns[columnID].panning_string
  elseif subColumnID == s.SUB_COLUMN_DELAY then
    str = patTrack:line(lineID).note_columns[columnID].delay_string
  elseif subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_NUMBER or
         subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
    local n = patTrack:line(lineID).note_columns[columnID].effect_number_string
    local a = patTrack:line(lineID).note_columns[columnID].effect_amount_string
    return (n == ".." and a == "..")
  elseif subColumnID >= s.SUB_COLUMN_EFFECT_NUMBER then
    str = patTrack:line(lineID).effect_columns[columnID].number_string
  else
    str = nil
  end
  if subColumnID >= s.SUB_COLUMN_EFFECT_NUMBER then
    return str == "00"
  else
    return str == ".."
  end
end

local function isDeviceStringEqual(lineID, columnID, lineIDInit, seqID, trackID, seqIDInit, subColumnID)
  local s = renoise.Song
  local song = renoise.song()
  local a, b
  if subColumnID == s.SUB_COLUMN_VOLUME then
    a = song.patterns[patternID_from_sequenceID(seqID)]:track(trackID):line(lineID).note_columns[columnID].volume_string
    b = song.patterns[patternID_from_sequenceID(seqIDInit)]:track(trackID):line(lineIDInit).note_columns[columnID].volume_string
  elseif subColumnID == s.SUB_COLUMN_PANNING then
    a = song.patterns[patternID_from_sequenceID(seqID)]:track(trackID):line(lineID).note_columns[columnID].panning_string
    b = song.patterns[patternID_from_sequenceID(seqIDInit)]:track(trackID):line(lineIDInit).note_columns[columnID].panning_string
  elseif subColumnID == s.SUB_COLUMN_DELAY then
    a = song.patterns[patternID_from_sequenceID(seqID)]:track(trackID):line(lineID).note_columns[columnID].delay_string
    b = song.patterns[patternID_from_sequenceID(seqIDInit)]:track(trackID):line(lineIDInit).note_columns[columnID].delay_string
  elseif subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_NUMBER or
         subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
    a = song.patterns[patternID_from_sequenceID(seqID)]:track(trackID):line(lineID).note_columns[columnID].effect_number_string
    b = song.patterns[patternID_from_sequenceID(seqIDInit)]:track(trackID):line(lineIDInit).note_columns[columnID].effect_number_string
  else
    a = song.patterns[patternID_from_sequenceID(seqID)]:track(trackID):line(lineID).effect_columns[columnID].number_string
    b = song.patterns[patternID_from_sequenceID(seqIDInit)]:track(trackID):line(lineIDInit).effect_columns[columnID].number_string
  end
  return a == b
end

----------------------------------------------------------------------
-- wave / easing functions: (t in 0..1, f = oscillations) -> 0..1
----------------------------------------------------------------------
local function saw(t, f)
  local tf = t * math.max(1, f)
  return tf - math.floor(tf)
end

local function sqr(t, f) return math.floor(saw(t, f) + 0.5) end

local function sin(t, f)
  local tf = t * math.pi * 2 * (f + 0.5)
  return math.sin(tf - math.pi / 2) * 0.5 + 0.5
end

local function tri(t, f)
  local tf = t * (f + 0.5) * 2 + 1
  return math.abs((tf % 2) - 1.0)
end

local function lerp(a, b, t) return a + t * (b - a) end

local function lin(t, f) return t end

local function logIn(t, f)
  if f < 2 then f = 2 end
  if t == 0 then return 0 end
  return f ^ (10 * t - 10)
end

local function logOut(t, f)
  if f < 2 then f = 2 end
  if t == 1 then return 1 end
  return 1 - f ^ (-10 * t)
end

local function easeOutBounce(x, f)
  local n1, d1 = 7.5625, 2.75
  if x < 1 / d1 then
    return n1 * x * x
  elseif x < 2 / d1 then
    x = x - 1.5 / d1
    return n1 * x * x + 0.75
  elseif x < 2.5 / d1 then
    x = x - 2.25 / d1
    return n1 * x * x + 0.9375
  else
    x = x - 2.625 / d1
    return n1 * x * x + 0.984375
  end
end

local function easeInBounce(x, f)
  return 1 - easeOutBounce(1 - x)
end

-- Gradient noise keeps a small amount of state between steps.
local function thresholdRan()
  local poles = 0
  local poleRandomPrev = 2
  local poleRandomNext = math.random()
  return function(t, polesPlus, startValue, endValue)
    if poles > .95 and t < .05 then
      poleRandomPrev = startValue / 255
      poleRandomNext = math.random()
      poles = polesPlus
    end
    if poleRandomPrev == 2 then
      poleRandomPrev = startValue / 255
      poles = poles + polesPlus
    end
    if t > poles then
      poleRandomPrev = poleRandomNext
      poleRandomNext = math.random()
      poles = poles + polesPlus
    end
    if poles == 1 then poleRandomNext = endValue / 255 end
    return poleRandomPrev, poleRandomNext, poles
  end
end

local poleRan = thresholdRan()

local function GradientRan(t, f, startValue, endValue)
  local polesPlus = 1 / math.max(1, f + 1)
  local ran1, ran2, poles = poleRan(t, polesPlus, startValue, endValue)
  local tSub = (t - (poles - polesPlus)) / polesPlus
  if f == 0 then
    return math.random()
  elseif startValue < endValue then
    return lerp(ran1, ran2, tSub), true
  else
    return lerp(ran1, ran2, tSub), false
  end
end

local function interpolate_with(waveFun, startValue, endValue, curStep, stepCounter, numOsc)
  local t = curStep / (stepCounter + 1)
  local wavyTime, flip = waveFun(t, numOsc, startValue, endValue)
  if flip == nil or flip then
    return lerp(startValue, endValue, wavyTime)
  else
    return lerp(endValue, startValue, wavyTime)
  end
end

----------------------------------------------------------------------
-- point search across pattern boundaries
----------------------------------------------------------------------
local function lineIDAdder(lineID, seqID, patternLength)
  local lineIDNext = lineID + 1
  local seqIDNext = seqID
  if lineIDNext > patternLength then
    seqIDNext = seqID + 1
    lineIDNext = 1
  end
  if seqID == 1 and lineID == 1 then lineIDNext = 1 end
  return lineIDNext, seqIDNext
end

local function findPreviousPoint(lineID, columnID, seqID, trackID, beginningOfProject, patternLengthPrev, patternLength, lineDown, subColumnID)
  local song = renoise.song()
  local lineIDInit = lineID
  local seqIDInit = seqID
  if isLineEmpty(lineID, columnID, song.patterns[patternID_from_sequenceID(seqID)]:track(trackID), subColumnID) then
    while isLineEmpty(lineID, columnID, song.patterns[patternID_from_sequenceID(seqID)]:track(trackID), subColumnID) do
      lineID = lineID - 1
      if lineID == 0 then
        seqID = seqID - 1
        if seqID == 0 then
          seqID = 1
          beginningOfProject = true
          lineID = 1
          break
        end
        patternLengthPrev = song.patterns[patternID_from_sequenceID(seqID)].number_of_lines
        lineID = patternLengthPrev
      end
    end
  else
    local lineIDNext, seqIDNext = lineIDAdder(lineID, seqID, patternLength)
    if not isLineEmpty(lineIDNext, columnID, song.patterns[patternID_from_sequenceID(seqIDNext)]:track(trackID), subColumnID) then
      while not isLineEmpty(lineID, columnID, song.patterns[patternID_from_sequenceID(seqID)]:track(trackID), subColumnID)
            and isDeviceStringEqual(lineID, columnID, lineIDInit, seqID, trackID, seqIDInit, subColumnID) do
        lineID = lineID - 1
        if lineID == 0 then
          seqID = seqID - 1
          if seqID == 0 then
            seqID = 1
            beginningOfProject = false
            lineID = 1
            break
          end
          patternLengthPrev = song.patterns[patternID_from_sequenceID(seqID)].number_of_lines
          lineID = patternLengthPrev
        end
      end
      lineID = lineIDAdder(lineID, seqID, patternLength)
    end
  end

  lineDown = lineID + 1
  local seqNext = seqID
  if patternLengthPrev == nil then patternLengthPrev = patternLength end
  if lineDown > patternLengthPrev then
    lineDown = 1
    seqNext = seqID + 1
  end
  return lineID, seqID, beginningOfProject, patternLengthPrev, patternLength, lineDown, seqNext
end

local function findNextModulationPoint(lineDown, columnID, seqNext, trackID, seqCount, subColumnID)
  local song = renoise.song()
  local stepCounter = 0
  local endOfProject = false
  local lineIDInit = lineDown
  local seqIDInit = seqNext
  local patternLength = song.patterns[patternID_from_sequenceID(seqNext)].number_of_lines

  if isLineEmpty(lineDown, columnID, song.patterns[patternID_from_sequenceID(seqNext)]:track(trackID), subColumnID) then
    while isLineEmpty(lineDown, columnID, song.patterns[patternID_from_sequenceID(seqNext)]:track(trackID), subColumnID) do
      lineDown = lineDown + 1
      stepCounter = stepCounter + 1
      if lineDown == patternLength + 1 then seqNext = seqNext + 1 lineDown = 1 end
      if seqNext > seqCount then
        seqNext = seqNext - 1
        endOfProject = true
        lineDown = patternLength
        break
      end
    end
  else
    local lineIDNext, seqIDNext = lineIDAdder(lineDown, seqNext, patternLength)
    if isLineEmpty(lineIDNext, columnID, song.patterns[patternID_from_sequenceID(seqIDNext)]:track(trackID), subColumnID) then
      while isLineEmpty(lineDown, columnID, song.patterns[patternID_from_sequenceID(seqNext)]:track(trackID), subColumnID) do
        lineDown = lineDown + 1
        stepCounter = stepCounter + 1
        if lineDown == patternLength + 1 then seqNext = seqNext + 1 lineDown = 1 end
        if seqNext > seqCount then
          seqNext = seqNext - 1
          endOfProject = true
          lineDown = patternLength
          break
        end
      end
    else
      while not isLineEmpty(lineDown, columnID, song.patterns[patternID_from_sequenceID(seqNext)]:track(trackID), subColumnID)
            and isDeviceStringEqual(lineDown, columnID, lineIDInit, seqNext, trackID, seqIDInit, subColumnID) do
        lineDown = lineDown + 1
        stepCounter = stepCounter + 1
        patternLength = song.patterns[patternID_from_sequenceID(seqNext)].number_of_lines
        if lineDown == patternLength + 1 then seqNext = seqNext + 1 lineDown = 1 end
        if seqNext > seqCount then
          seqNext = seqNext - 1
          endOfProject = false
          lineDown = patternLength
          break
        end
      end
      stepCounter = stepCounter - 1
      if lineDown - 1 == 0 then
        lineDown = patternLength
        seqNext = seqNext - 1
      else
        lineDown = lineDown - 1
      end
    end
  end
  return lineDown, seqNext, stepCounter, endOfProject
end

----------------------------------------------------------------------
-- read start/end values, write interpolated steps
----------------------------------------------------------------------
local function round_int(v) return math.floor(v + 0.5) end

local function getParameterValues(seqID, seqNext, lineID, lineDown, trackID, columnID, beginningOfProject, endOfProject, subColumnID)
  local s = renoise.Song
  local song = renoise.song()
  local parameterStart, parameterEnd
  local start_effect_number_value
  local end_effect_number_value   -- scoped local (the original wrote this as a global)
  local line = song.patterns[patternID_from_sequenceID(seqID)]:track(trackID):line(lineID)

  if not beginningOfProject then
    if subColumnID == s.SUB_COLUMN_VOLUME then
      parameterStart = line.note_columns[columnID].volume_value
    elseif subColumnID == s.SUB_COLUMN_PANNING then
      parameterStart = line.note_columns[columnID].panning_value
    elseif subColumnID == s.SUB_COLUMN_DELAY then
      parameterStart = line.note_columns[columnID].delay_value
    elseif subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
      parameterStart = line.note_columns[columnID].effect_amount_value
      start_effect_number_value = line.note_columns[columnID].effect_number_value
    else
      parameterStart = line.effect_columns[columnID].amount_value
    end
  else
    parameterStart = 0
    if subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
      start_effect_number_value = line.note_columns[columnID].effect_number_value
    end
  end

  line = song.patterns[patternID_from_sequenceID(seqNext)]:track(trackID):line(lineDown)
  if not endOfProject then
    if subColumnID == s.SUB_COLUMN_VOLUME then
      parameterEnd = line.note_columns[columnID].volume_value
    elseif subColumnID == s.SUB_COLUMN_PANNING then
      parameterEnd = line.note_columns[columnID].panning_value
    elseif subColumnID == s.SUB_COLUMN_DELAY then
      parameterEnd = line.note_columns[columnID].delay_value
    elseif subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
      parameterEnd = line.note_columns[columnID].effect_amount_value
      end_effect_number_value = line.note_columns[columnID].effect_number_value
    else
      parameterEnd = line.effect_columns[columnID].amount_value
    end
  else
    parameterEnd = 255
    if subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
      end_effect_number_value = line.note_columns[columnID].effect_number_value
    end
  end

  return parameterStart, parameterEnd, start_effect_number_value
end

local function processModulationPoints(columnID, seqNext, trackID, parameterStart, parameterEnd, stepCounter, curStep,
                                       deviceString, seqCount, beginningOfProject, lineID, seqID, deviceStringEnd,
                                       waveFun, subColumnID, numOsc, endOfProject, start_effect_number_value)
  local s = renoise.Song
  local song = renoise.song()
  local lineDown = lineID + 1
  seqNext = seqID
  local patternLength = song.patterns[patternID_from_sequenceID(seqID)].number_of_lines
  if lineDown > patternLength then lineDown = 1 seqNext = seqID + 1 end
  if beginningOfProject then lineDown = 1 curStep = 0 deviceString = deviceStringEnd end

  while curStep <= stepCounter do
    local stepValue
    if endOfProject then
      stepValue = interpolate_with(waveFun, parameterStart, parameterEnd, curStep + 1, stepCounter, numOsc)
    else
      stepValue = interpolate_with(waveFun, parameterStart, parameterEnd, curStep, stepCounter, numOsc)
    end
    stepValue = round_int(stepValue)

    patternLength = song.patterns[patternID_from_sequenceID(seqNext)].number_of_lines
    local line = song.patterns[patternID_from_sequenceID(seqNext)]:track(trackID):line(lineDown)
    if subColumnID == s.SUB_COLUMN_VOLUME then
      if parameterStart <= 128 and parameterEnd <= 128 then line.note_columns[columnID].volume_value = stepValue end
    elseif subColumnID == s.SUB_COLUMN_PANNING then
      if parameterStart <= 128 and parameterEnd <= 128 then line.note_columns[columnID].panning_value = stepValue end
    elseif subColumnID == s.SUB_COLUMN_DELAY then
      line.note_columns[columnID].delay_value = stepValue
    elseif subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
      line.note_columns[columnID].effect_number_value = start_effect_number_value
      line.note_columns[columnID].effect_amount_value = stepValue
    else
      line.effect_columns[columnID].amount_value = stepValue
      line.effect_columns[columnID].number_string = deviceString
    end

    lineDown = lineDown + 1
    curStep = curStep + 1
    if lineDown == patternLength + 1 then seqNext = seqNext + 1 lineDown = 1 end
    if seqNext > seqCount then break end
  end
end

----------------------------------------------------------------------
-- entry point
----------------------------------------------------------------------
local function PakettiInterpolateBeyond(waveFun)
  local s = renoise.Song
  local song = renoise.song()
  local subColumnID = song.selected_sub_column_type

  -- Guard: only sub-columns that carry an interpolatable value.
  local ok = (subColumnID == s.SUB_COLUMN_VOLUME
           or subColumnID == s.SUB_COLUMN_PANNING
           or subColumnID == s.SUB_COLUMN_DELAY
           or subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_NUMBER
           or subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT
           or subColumnID == s.SUB_COLUMN_EFFECT_NUMBER
           or subColumnID == s.SUB_COLUMN_EFFECT_AMOUNT)
  if not ok then
    renoise.app():show_status("Interpolate Beyond: place the cursor on a volume, panning, delay, or effect sub-column.")
    return
  end

  local numOsc = song.transport.edit_step
  local lineID = song.selected_line_index
  local trackID = song.selected_track_index
  local patternID = song.selected_pattern_index
  local seqID = song.selected_sequence_index
  local columnID = song.selected_effect_column_index

  if subColumnID >= s.SUB_COLUMN_NOTE and subColumnID <= s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
    columnID = song.selected_note_column_index
  end
  if columnID == 0 then
    renoise.app():show_status("Interpolate Beyond: no column selected under the cursor.")
    return
  end

  local patternLength = song.patterns[patternID].number_of_lines
  local patternLengthPrev
  local seqCount = #song.sequencer.pattern_sequence
  local beginningOfProject = false
  local endOfProject = false
  local lineDown = lineID + 1
  local seqNext = seqID
  local stepCounter = 0
  local curStep = 1

  lineID, seqID, beginningOfProject, patternLengthPrev, patternLength, lineDown, seqNext =
    findPreviousPoint(lineID, columnID, seqID, trackID, beginningOfProject, patternLengthPrev, patternLength, lineDown, subColumnID)
  lineDown, seqNext, stepCounter, endOfProject =
    findNextModulationPoint(lineDown, columnID, seqNext, trackID, seqCount, subColumnID)

  local deviceString, deviceStringEnd
  local patTrack = song.patterns[patternID_from_sequenceID(seqID)]:track(trackID)
  if subColumnID >= s.SUB_COLUMN_NOTE and subColumnID <= s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
    deviceString, deviceStringEnd = "..", ".."
  else
    deviceString = patTrack:line(lineID).effect_columns[columnID].number_string
    deviceStringEnd = song.patterns[patternID_from_sequenceID(seqNext)]:track(trackID):line(lineDown).effect_columns[columnID].number_string
  end

  local parameterStart, parameterEnd, start_effect_number_value =
    getParameterValues(seqID, seqNext, lineID, lineDown, trackID, columnID, beginningOfProject, endOfProject, subColumnID)

  if beginningOfProject and endOfProject then
    renoise.app():show_status("Interpolate Beyond: need at least one point before or after the cursor.")
    return
  end

  processModulationPoints(columnID, seqNext, trackID, parameterStart, parameterEnd, stepCounter, curStep,
    deviceString, seqCount, beginningOfProject, lineID, seqID, deviceStringEnd, waveFun, subColumnID, numOsc,
    endOfProject, start_effect_number_value)
  renoise.app():show_status("Interpolate Beyond: interpolated across " .. (stepCounter + 1) .. " step(s).")
end

----------------------------------------------------------------------
-- registrations — one per shape
----------------------------------------------------------------------
local SHAPES = {
  {"Linear",          lin},
  {"Logarithmic In",  logIn},
  {"Logarithmic Out", logOut},
  {"Sine",            sin},
  {"Square",          sqr},
  {"Saw",             saw},
  {"Triangle",        tri},
  {"Bounce Out",      easeOutBounce},
  {"Bounce In",       easeInBounce},
  {"Gradient Noise",  GradientRan},
}

for _, entry in ipairs(SHAPES) do
  local name, fn = entry[1], entry[2]
  local invoke = function() PakettiInterpolateBeyond(fn) end
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Interpolate Beyond " .. name, invoke=invoke}
  PakettiAddMenuEntry{name="Pattern Editor:Paketti:Interpolate Beyond:" .. name, invoke=invoke}
  PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Pattern Editor:Interpolate Beyond:" .. name, invoke=invoke}
end
