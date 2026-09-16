-- PakettiInterpolateBeyond.lua
-- Cross-pattern, multi-shape column interpolation, ported from GARBANZO's
-- "Interpolate Beyond" (rfgd.garbanzo.InterpolateBeyond) and extended.
--
-- Two modes, chosen automatically:
--   * SELECTION mode — if there is a pattern selection, interpolate the current
--     sub-column across the selection from its first value to its last value.
--   * CURSOR mode ("Beyond") — with no selection, find the previous and next
--     non-empty value in the current sub-column, searching ACROSS pattern
--     boundaries along the sequence, and interpolate between them through the
--     cursor. One point found -> extends to the start or end of the track.
--
-- Interpolation shapes: linear, log in/out, sine, square, saw, triangle,
-- bounce in/out, gradient noise. Works on note-column volume / panning / delay /
-- sample-effect amount, or effect-column amount.
--
-- Fixes over the original:
--   1. Oscillation count is its own setting (preference + dialog control),
--      decoupled from the Edit Step the original hijacked.
--   2. Gradient Noise re-seeds its RNG on every run, so results are self-contained.
--   4. Selection mode added (the original was cursor-only).
--   5. A preview dialog draws the chosen shape on a canvas before you apply it.
-- (Undo: Renoise already coalesces all edits of one invocation into a single undo
--  step; there is no undo-transaction API to do more, so nothing to add there.)

----------------------------------------------------------------------
-- oscillation-count setting (decoupled from Edit Step)
----------------------------------------------------------------------
local function get_oscillations()
  local ok, v = pcall(function() return preferences.pakettiInterpolateBeyondOscillations.value end)
  if ok and type(v) == "number" then return v end
  return 1
end

local function set_oscillations(v)
  pcall(function()
    preferences.pakettiInterpolateBeyondOscillations.value = v
    preferences:save_as("preferences.xml")
  end)
end

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

-- Gradient noise keeps a little state between steps; re-created each run (fix 2).
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

local poleRan = thresholdRan()  -- reassigned per run in PakettiInterpolateBeyond

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

-- Core: map t (0..1) through a shape into a value between startValue and endValue.
local function apply_wave(waveFun, startValue, endValue, t, osc)
  local wavyTime, flip = waveFun(t, osc, startValue, endValue)
  if flip == nil or flip then
    return lerp(startValue, endValue, wavyTime)
  else
    return lerp(endValue, startValue, wavyTime)
  end
end

local function interpolate_with(waveFun, startValue, endValue, curStep, stepCounter, osc)
  return apply_wave(waveFun, startValue, endValue, curStep / (stepCounter + 1), osc)
end

----------------------------------------------------------------------
-- shared sub-column read / write
----------------------------------------------------------------------
local function round_int(v) return math.floor(v + 0.5) end

local function read_subcolumn_value(line, columnID, subColumnID)
  local s = renoise.Song
  if subColumnID == s.SUB_COLUMN_VOLUME then
    return line.note_columns[columnID].volume_value
  elseif subColumnID == s.SUB_COLUMN_PANNING then
    return line.note_columns[columnID].panning_value
  elseif subColumnID == s.SUB_COLUMN_DELAY then
    return line.note_columns[columnID].delay_value
  elseif subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
    return line.note_columns[columnID].effect_amount_value
  else
    return line.effect_columns[columnID].amount_value
  end
end

local function write_subcolumn_value(line, columnID, subColumnID, value, effnum, deviceString)
  local s = renoise.Song
  value = round_int(value)
  if subColumnID == s.SUB_COLUMN_VOLUME then
    if value <= 128 then line.note_columns[columnID].volume_value = value end
  elseif subColumnID == s.SUB_COLUMN_PANNING then
    if value <= 128 then line.note_columns[columnID].panning_value = value end
  elseif subColumnID == s.SUB_COLUMN_DELAY then
    line.note_columns[columnID].delay_value = value
  elseif subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
    if effnum then line.note_columns[columnID].effect_number_value = effnum end
    line.note_columns[columnID].effect_amount_value = value
  else
    line.effect_columns[columnID].amount_value = value
    if deviceString then line.effect_columns[columnID].number_string = deviceString end
  end
end

local function subcolumn_is_interpolatable(subColumnID)
  local s = renoise.Song
  return subColumnID == s.SUB_COLUMN_VOLUME
      or subColumnID == s.SUB_COLUMN_PANNING
      or subColumnID == s.SUB_COLUMN_DELAY
      or subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_NUMBER
      or subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT
      or subColumnID == s.SUB_COLUMN_EFFECT_NUMBER
      or subColumnID == s.SUB_COLUMN_EFFECT_AMOUNT
end

local function column_for_subcolumn(song, subColumnID)
  local s = renoise.Song
  if subColumnID >= s.SUB_COLUMN_NOTE and subColumnID <= s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
    return song.selected_note_column_index
  end
  return song.selected_effect_column_index
end

----------------------------------------------------------------------
-- cursor cross-pattern point search (the original "Beyond" algorithm)
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

local function getParameterValues(seqID, seqNext, lineID, lineDown, trackID, columnID, beginningOfProject, endOfProject, subColumnID)
  local s = renoise.Song
  local song = renoise.song()
  local parameterStart, parameterEnd
  local start_effect_number_value
  local end_effect_number_value   -- scoped local (the original wrote a global here)
  local line = song.patterns[patternID_from_sequenceID(seqID)]:track(trackID):line(lineID)

  if not beginningOfProject then
    parameterStart = read_subcolumn_value(line, columnID, subColumnID)
    if subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
      start_effect_number_value = line.note_columns[columnID].effect_number_value
    end
  else
    parameterStart = 0
    if subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
      start_effect_number_value = line.note_columns[columnID].effect_number_value
    end
  end

  line = song.patterns[patternID_from_sequenceID(seqNext)]:track(trackID):line(lineDown)
  if not endOfProject then
    parameterEnd = read_subcolumn_value(line, columnID, subColumnID)
    if subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
      end_effect_number_value = line.note_columns[columnID].effect_number_value
    end
  else
    parameterEnd = 255
    if subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
      end_effect_number_value = line.note_columns[columnID].effect_number_value
    end
  end
  return parameterStart, parameterEnd, start_effect_number_value
end

local function processModulationPoints(columnID, trackID, parameterStart, parameterEnd, stepCounter, curStep,
                                       deviceString, seqCount, beginningOfProject, lineID, seqID, deviceStringEnd,
                                       waveFun, subColumnID, osc, endOfProject, start_effect_number_value)
  local song = renoise.song()
  local lineDown = lineID + 1
  local seqNext = seqID
  local patternLength = song.patterns[patternID_from_sequenceID(seqID)].number_of_lines
  if lineDown > patternLength then lineDown = 1 seqNext = seqID + 1 end
  if beginningOfProject then lineDown = 1 curStep = 0 deviceString = deviceStringEnd end

  while curStep <= stepCounter do
    local step = endOfProject and (curStep + 1) or curStep
    local stepValue = interpolate_with(waveFun, parameterStart, parameterEnd, step, stepCounter, osc)

    patternLength = song.patterns[patternID_from_sequenceID(seqNext)].number_of_lines
    local line = song.patterns[patternID_from_sequenceID(seqNext)]:track(trackID):line(lineDown)
    write_subcolumn_value(line, columnID, subColumnID, stepValue, start_effect_number_value, deviceString)

    lineDown = lineDown + 1
    curStep = curStep + 1
    if lineDown == patternLength + 1 then seqNext = seqNext + 1 lineDown = 1 end
    if seqNext > seqCount then break end
  end
end

local function interpolate_cursor_cross_pattern(waveFun, osc)
  local s = renoise.Song
  local song = renoise.song()
  local subColumnID = song.selected_sub_column_type
  if not subcolumn_is_interpolatable(subColumnID) then
    renoise.app():show_status("Interpolate Beyond: place the cursor on a volume, panning, delay, or effect sub-column.")
    return
  end

  local lineID = song.selected_line_index
  local trackID = song.selected_track_index
  local patternID = song.selected_pattern_index
  local seqID = song.selected_sequence_index
  local columnID = column_for_subcolumn(song, subColumnID)
  if columnID == 0 then
    renoise.app():show_status("Interpolate Beyond: no column selected under the cursor.")
    return
  end

  local patternLength = song.patterns[patternID].number_of_lines
  local patternLengthPrev
  local seqCount = #song.sequencer.pattern_sequence
  local beginningOfProject, endOfProject = false, false
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

  processModulationPoints(columnID, trackID, parameterStart, parameterEnd, stepCounter, curStep,
    deviceString, seqCount, beginningOfProject, lineID, seqID, deviceStringEnd, waveFun, subColumnID, osc,
    endOfProject, start_effect_number_value)
  renoise.app():show_status("Interpolate Beyond (cursor): interpolated across " .. (stepCounter + 1) .. " step(s).")
end

----------------------------------------------------------------------
-- selection mode (fix 4)
----------------------------------------------------------------------
local function interpolate_selection(waveFun, osc)
  local s = renoise.Song
  local song = renoise.song()
  local sel = song.selection_in_pattern
  local subColumnID = song.selected_sub_column_type
  if not subcolumn_is_interpolatable(subColumnID) then
    renoise.app():show_status("Interpolate Beyond: place the cursor on a volume, panning, delay, or effect sub-column.")
    return
  end

  local trackID = song.selected_track_index
  local columnID = column_for_subcolumn(song, subColumnID)
  if columnID == 0 then
    renoise.app():show_status("Interpolate Beyond: no column selected under the cursor.")
    return
  end

  local ptrack = song:pattern(song.selected_pattern_index):track(trackID)
  local start_line, end_line = sel.start_line, sel.end_line
  local steps = end_line - start_line
  if steps < 1 then
    renoise.app():show_status("Interpolate Beyond: selection is too small to interpolate.")
    return
  end

  local first_line = ptrack:line(start_line)
  local startValue = read_subcolumn_value(first_line, columnID, subColumnID)
  local endValue = read_subcolumn_value(ptrack:line(end_line), columnID, subColumnID)

  local effnum, deviceString
  if subColumnID == s.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
    effnum = first_line.note_columns[columnID].effect_number_value
  elseif subColumnID == s.SUB_COLUMN_EFFECT_NUMBER or subColumnID == s.SUB_COLUMN_EFFECT_AMOUNT then
    deviceString = first_line.effect_columns[columnID].number_string
  end

  for k = 0, steps do
    local v = apply_wave(waveFun, startValue, endValue, k / steps, osc)
    write_subcolumn_value(ptrack:line(start_line + k), columnID, subColumnID, v, effnum, deviceString)
  end
  renoise.app():show_status("Interpolate Beyond (selection): interpolated " .. (steps + 1) .. " line(s).")
end

----------------------------------------------------------------------
-- dispatcher
----------------------------------------------------------------------
function PakettiInterpolateBeyond(waveFun)
  poleRan = thresholdRan()  -- fix 2: fresh noise generator each run
  local osc = get_oscillations()
  local song = renoise.song()
  if song.selection_in_pattern then
    interpolate_selection(waveFun, osc)
  else
    interpolate_cursor_cross_pattern(waveFun, osc)
  end
end

----------------------------------------------------------------------
-- shapes
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

----------------------------------------------------------------------
-- preview dialog with canvas (fix 5)
----------------------------------------------------------------------
local ib_dialog = nil
local ib_preview_shape = 1  -- index into SHAPES

local function ib_render_preview(ctx)
  local CW, CH = 360, 150
  local pad = 8
  ctx:clear_rect(0, 0, CW, CH)
  ctx.fill_color = {28, 28, 32, 255}
  ctx:fill_rect(0, 0, CW, CH)

  -- grid at 0 / 0.5 / 1
  ctx.stroke_color = {64, 64, 72, 255}
  ctx.line_width = 1
  for _, gy in ipairs({0, 0.5, 1}) do
    local y = pad + gy * (CH - 2 * pad)
    ctx:begin_path() ctx:move_to(0, y) ctx:line_to(CW, y) ctx:stroke()
  end

  local fn = SHAPES[ib_preview_shape][2]
  local osc = get_oscillations()
  if fn == GradientRan then poleRan = thresholdRan() end

  ctx.stroke_color = {120, 200, 120, 255}
  ctx.line_width = 2
  ctx:begin_path()
  for x = 0, CW do
    local t = x / CW
    local v = apply_wave(fn, 0, 255, t, osc) / 255
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    local y = pad + (1 - v) * (CH - 2 * pad)
    if x == 0 then ctx:move_to(x, y) else ctx:line_to(x, y) end
  end
  ctx:stroke()
end

function PakettiInterpolateBeyondDialog()
  if ib_dialog and ib_dialog.visible then
    ib_dialog:close()
    ib_dialog = nil
    return
  end
  local vb = renoise.ViewBuilder()
  local canvas_id = "ib_canvas_" .. tostring(math.random(2, 30000))
  local shape_items = {}
  for i, e in ipairs(SHAPES) do shape_items[i] = e[1] end

  local mode_text = renoise.song().selection_in_pattern
    and "Mode: Selection (interpolate the marked block)"
    or  "Mode: Cursor (search across patterns from the cursor)"

  local content = vb:column{
    margin = 10, spacing = 8,
    vb:text{text = "Interpolate Beyond", font = "bold"},
    vb:text{text = mode_text},
    vb:row{
      vb:text{text = "Shape:", width = 80},
      vb:popup{id = "ib_shape", width = 200, items = shape_items, value = ib_preview_shape,
        notifier = function(v) ib_preview_shape = v vb.views[canvas_id]:invalidate() end},
    },
    vb:row{
      vb:text{text = "Oscillations:", width = 80},
      vb:valuebox{width = 80, min = 0, max = 16, value = get_oscillations(),
        notifier = function(v) set_oscillations(v) vb.views[canvas_id]:invalidate() end},
    },
    vb:canvas{id = canvas_id, width = 360, height = 150, mode = "plain", render = ib_render_preview},
    vb:row{
      vb:button{text = "Apply", width = 100, notifier = function()
        PakettiInterpolateBeyond(SHAPES[ib_preview_shape][2])
      end},
      vb:button{text = "Close", width = 100, notifier = function()
        if ib_dialog and ib_dialog.visible then ib_dialog:close() ib_dialog = nil end
      end},
    },
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return ib_dialog end,
    function(value) ib_dialog = value end
  )
  ib_dialog = renoise.app():show_custom_dialog("Paketti Interpolate Beyond", content, keyhandler)
end

----------------------------------------------------------------------
-- registrations — one per shape + the preview dialog
----------------------------------------------------------------------
for _, entry in ipairs(SHAPES) do
  local name, fn = entry[1], entry[2]
  local invoke = function() PakettiInterpolateBeyond(fn) end
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Interpolate Beyond " .. name, invoke=invoke}
  PakettiAddMenuEntry{name="Pattern Editor:Paketti:Interpolate Beyond:" .. name, invoke=invoke}
  PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Pattern Editor:Interpolate Beyond:" .. name, invoke=invoke}
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Interpolate Beyond Dialog...", invoke=PakettiInterpolateBeyondDialog}
PakettiAddMenuEntry{name="Pattern Editor:Paketti:Interpolate Beyond:Dialog (Preview)...", invoke=PakettiInterpolateBeyondDialog}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Pattern Editor:Interpolate Beyond:Dialog (Preview)...", invoke=PakettiInterpolateBeyondDialog}
renoise.tool():add_midi_mapping{name="Paketti:Interpolate Beyond Dialog", invoke=function(m) if m:is_trigger() then PakettiInterpolateBeyondDialog() end end}
