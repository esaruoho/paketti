-- Run with lua tests/keyjazz-special-cycler.lua (mocked Renoise API).
local function source(path)
  local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s
end
local function section(s, first, last)
  local a = assert(s:find(first, 1, true)); local b = assert(s:find(last, a, true))
  return s:sub(a, b - 1)
end
local keys, midi, menus = {}, {}, {}
local tool = {}
function tool:add_keybinding(v) keys[v.name] = v.invoke end
function tool:add_midi_mapping(v) midi[v.name] = v.invoke end
function PakettiAddMenuEntry(v) menus[v.name] = v.invoke end
local track = {visible_note_columns=12}
local pattern = {tracks={{lines={}}}, number_of_lines=3}
for row=1,3 do
  local cols = {}; for col=1,12 do cols[col]={delay_value=0} end
  pattern.tracks[1].lines[row]={note_columns=cols}
end
local active = false
function pattern:has_line_notifier() return active end
function pattern:add_line_notifier() assert(not active); active=true end
function pattern:remove_line_notifier() assert(active); active=false end
local song = {selected_track=track, tracks={track}, selected_track_index=1,
  selected_pattern=pattern, patterns={pattern}, selected_pattern_index=1,
  transport={}, selected_note_column_index=12}
renoise = {song=function() return song end, tool=function() return tool end,
  app=function() return {show_status=function() end} end}
function formatDigits(n,v) return string.format("%0"..n.."d",v) end
function pattern_line_notifier() end
local pe = source("PakettiPatternEditor.lua")
assert(load(section(pe, "function displayNoteColumn(number)", "\n")))()
assert(load(section(pe, 'function GenerateDelayValue(scope)', 'renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay')))()
local experimental = source("PakettiExperimental_Verify.lua")
assert(load(section(experimental, 'PakettiColumnCycleKeyjazzActiveCount = nil', '\n---\n-- Toggle mute state functions')))()
local function check(count)
  assert(track.visible_note_columns==count)
  for row=1,3 do for col=1,count do
    assert(pattern.tracks[1].lines[row].note_columns[col].delay_value==math.floor(256/count*(col-1)))
  end end
  assert(track.delay_column_visible and song.transport.edit_mode)
  assert(song.transport.edit_step==0 and song.selected_note_column_index==1)
end
keys["Global:Paketti:Column Cycle Keyjazz Special (12)"](); check(12)
-- Re-trigger numbered Special 12 at an already-visible twelve and refresh.
for row=1,3 do for col=1,12 do pattern.tracks[1].lines[row].note_columns[col].delay_value=0 end end
keys["Global:Paketti:Column Cycle Keyjazz Special (12)"](); check(12)
-- Erase delays, then hit +1 at the upper limit. It must regenerate and stay on.
for row=1,3 do for col=1,12 do pattern.tracks[1].lines[row].note_columns[col].delay_value=0 end end
keys["Global:Paketti:Column Cycle Keyjazz Cycler Special +1"](); check(12); assert(active)
keys["Global:Paketti:Column Cycle Keyjazz Cycler Special -1"](); check(11); assert(active)
midi["Paketti:Column Cycle Keyjazz Cycler Special [01-12]"]({is_abs_value=function() return true end,int_value=0}); check(1)
menus["Pattern Editor:Paketti:Column Cycle Keyjazz:Column Cycle Keyjazz Cycler Special -1"](); check(1); assert(active)
midi["Paketti:Column Cycle Keyjazz Cycler Special [01-12]"]({is_abs_value=function() return true end,int_value=127}); check(12)
-- Ordinary cycler changes count without overwriting delays.
pattern.tracks[1].lines[1].note_columns[2].delay_value=77
keys["Global:Paketti:Column Cycle Keyjazz Cycler -1"]()
assert(track.visible_note_columns==11 and pattern.tracks[1].lines[1].note_columns[2].delay_value==77)
print("PASS: Special 12 refresh, Special steps/knob, boundaries, ordinary delay preservation")
