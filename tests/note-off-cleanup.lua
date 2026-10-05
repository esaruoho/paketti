-- FEATURE-CARD >> features/note-off-cleanup.feature
local f=assert(io.open('PakettiPatternEditor.lua')); local source=f:read('*a'); f:close()
local block=assert(source:match('(local function PakettiClearPatternTrackNoteOffs.-)\n%-%- Adjust delay value'))
local keys, menus, midi, statuses = {}, {}, {}, {}
local current
renoise={Track={TRACK_TYPE_SEQUENCER=1}, song=function() return current end,
  app=function() return {show_status=function(_,s) statuses[#statuses+1]=s end} end,
  tool=function() return {
    add_keybinding=function(_,v) keys[v.name]=v.invoke end,
    add_midi_mapping=function(_,v) midi[v.name]=v.invoke end} end}
PakettiAddMenuEntry=function(v) menus[v.name]=v.invoke end
assert(load(block))()
local function fixture()
  local s={tracks={{type=1,visible_note_columns=1},{type=1},{type=2},{type=3},{type=4}}, selected_track_index=1, patterns={}, undo={}}
  for p=1,3 do
    local pattern={number_of_lines=2,tracks={}}
    for t=1,5 do
      local pt={lines={},is_empty=false}
      for l=1,2 do
        pt.lines[l]={is_empty=false,note_columns={}}
        for c=1,3 do
          pt.lines[l].note_columns[c]={note_value=c==2 and 48 or 120,instrument_value=7,volume_value=50,panning_value=31,delay_value=13,effect_number_value=12,effect_amount_value=99}
        end
      end
      function pt:line(l) return self.lines[l] end
      pattern.tracks[t]=pt
    end
    s.patterns[p]=pattern
  end
  s.selected_pattern=s.patterns[2]; s.selected_track=s.tracks[1]
  s.sequencer={pattern_sequence={2,2,1}} -- pattern 3 is unused
  function s:describe_undo(v) self.undo[#self.undo+1]=v end
  return s
end
for _,case in ipairs({{'Track',false,false,4},{'Pattern',true,false,8},{'Track (Whole Song)',false,true,12},{'Song',true,true,24}}) do
  current=fixture()
  keys['Pattern Editor:Paketti:Delete Note Offs in '..case[1]](false)
  for p=1,3 do for t=1,5 do for l=1,2 do for c=1,3 do
    local n=current.patterns[p].tracks[t].lines[l].note_columns[c]
    local affected=(case[3] or p==2) and (case[2] and t<=2 or t==1)
    assert(n.note_value==(c==2 and 48 or affected and 121 or 120),case[1])
    assert(n.instrument_value==7 and n.volume_value==50 and n.panning_value==31 and n.delay_value==13 and n.effect_number_value==12 and n.effect_amount_value==99)
  end end end end
  assert(#current.undo==1)
  assert(statuses[#statuses]:find('Deleted '..case[4]..' note offs',1,true))
end
current=fixture()
keys['Pattern Editor:Paketti:Delete Note Offs in Song'](true)
midi['Paketti:Delete Note Offs in Song']({is_trigger=function() return false end})
assert(#current.undo==0)
midi['Paketti:Delete Note Offs in Song']({is_trigger=function() return true end})
assert(#current.undo==1)
for t=3,5 do
  current=fixture(); current.selected_track_index=t; current.selected_track=current.tracks[t]
  keys['Pattern Editor:Paketti:Delete Note Offs in Track'](false)
  assert(#current.undo==0)
end
current=fixture()
menus['Pattern Editor:Paketti:Note Offs:Delete Note Offs in Pattern']()
assert(#current.undo==1)
menus['Main Menu:Tools:Paketti:Note Offs:Delete Note Offs in Pattern']()
assert(statuses[#statuses]:find('Deleted 0 note offs',1,true))
current=fixture(); current.patterns[1].tracks[1].is_empty=true
current.patterns[2].tracks[1].lines[1].is_empty=true
keys['Pattern Editor:Paketti:Delete Note Offs in Track (Whole Song)'](false)
assert(statuses[#statuses]:find('Deleted 6 note offs',1,true))
current=nil
keys['Pattern Editor:Paketti:Delete Note Offs in Song'](false)
print('note-off cleanup: all scope, preservation, hidden-column, unused-pattern, repeat, MIDI, menu, guard and empty-skip checks passed')
