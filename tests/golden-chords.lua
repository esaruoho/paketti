-- Exercise the actual chord definitions and both dialog insertion callbacks.
local f = assert(io.open('PakettiMicrotonalTunings.lua'))
local source = f:read('*a'); f:close()
local first = assert(source:find('local function get_golden_chords()', 1, true))
local last = assert(source:find('-- GOLDEN RATIO TEMPO/RHYTHM', first, true))
local buttons, views = {}, {}
local vb = {views = views}
for _, kind in ipairs({'column', 'row', 'text', 'popup', 'valuebox', 'button'}) do
  vb[kind] = function(self, props)
    if props.id then views[props.id] = props end
    if kind == 'button' then buttons[props.text] = props.notifier end
    return props
  end
end
local lines = {}
for n = 1, 6 do
  lines[n] = {note_columns = {}}
  for i = 1, 4 do lines[n].note_columns[i] = {} end
end
local instrument = {trigger_options = {}}
local song = {
  selected_instrument = instrument, selected_instrument_index = 1,
  selected_track = {visible_note_columns = 1}, selected_track_index = 1,
  selected_line = lines[1], selected_line_index = 1,
  selected_pattern = {number_of_lines = 6, track = function() return {line = function(_, i) return lines[i] end} end},
  describe_undo = function() end,
}
local app = {show_status = function() end, show_custom_dialog = function() end,
  window = {active_middle_frame = 1}}
renoise = {song = function() return song end, app = function() return app end, ViewBuilder = function() return vb end}
local prelude = [[
local PHI = (1 + math.sqrt(5))/2
local function ratio_to_cents(r) return 1200 * math.log(r)/math.log(2) end
local function generate_n_edo(n)
  local r = {}; for i=1,n do r[i]=2^(i/n) end; return r, n..'-EDO'
end
]]
local compile = loadstring or load
local chords = assert(compile(prelude .. source:sub(first, last-1) .. '\nreturn get_golden_chords()'))()
local function near(a,b) assert(math.abs(a-b)<0.00001, tostring(a)..' ~= '..tostring(b)) end
near(chords[1].notes[2], 1100/3); near(chords[1].notes[3], 2200/3)   -- golden triad steps 0,11,22
near(chords[2].notes[4], 1100)                                       -- golden seventh adds step 33
near(chords[3].notes[2], 1000/3); near(chords[3].notes[3], 2000/3)   -- silver triad steps 0,10,20
near(chords[4].notes[2], 1300/3); near(chords[4].notes[3], 2600/3)   -- bronze triad steps 0,13,26
for _, chord in ipairs(chords) do
  local seen = {}
  for _, cents in ipairs(chord.notes) do
    local step = math.floor(cents*36/1200+0.5)
    assert(cents >= 0 and cents < 1200)
    assert(not seen[step], chord.name .. ' duplicates a pitch')
    seen[step] = true
  end
end
show_golden_chord_dialog()
buttons['Insert at Cursor']()
assert(lines[1].note_columns[1].note_value == 48)
assert(lines[1].note_columns[2].note_value == 59)
assert(lines[1].note_columns[3].note_value == 70)
assert(#instrument.trigger_options.tuning == 36)
near(instrument.trigger_options.tuning[36],2)
buttons['Insert All on Successive Lines']()
for i, chord in ipairs(chords) do
  for j,cents in ipairs(chord.notes) do
    assert(lines[i].note_columns[j].note_value == 48+math.floor(cents*36/1200+0.5))
  end
end
assert(instrument.trigger_options.tuning_name == '36-EDO')
print('PASS: definitions, unique pitches, single and bulk 36-EDO insertion')
