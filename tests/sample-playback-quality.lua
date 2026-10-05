-- FEATURE-CARD >> features/sample-playback-quality.feature
local f=assert(io.open('PakettiTkna.lua')); local src=f:read('*a'); f:close()
local block=assert(src:match('%-%- Phaos.s SimpleInterpolation inspired.-\n(do\n.*)$'))
local menus,keys,midi={},{},{}
local s
renoise={song=function() return s end,app=function() return {show_status=function() end} end,
 tool=function() return {add_keybinding=function(_,v) assert(not keys[v.name]); keys[v.name]=v.invoke end,
 add_midi_mapping=function(_,v) assert(not midi[v.name]); midi[v.name]=v.invoke end} end}
PakettiAddMenuEntry=function(v) assert(not menus[v.name]); menus[v.name]=v end
selectedSampleInterpolation=function(v) s.selected_sample.interpolation_mode=v end
setSelectedInstrumentInterpolation=function(v) for _,a in ipairs(s.selected_instrument.samples) do a.interpolation_mode=v end end
PakettiGlobalSample=function(v) for _,i in ipairs(s.instruments) do for _,a in ipairs(i.samples) do a.interpolation_mode=v end end end
selectedSampleOversampleOn=function() s.selected_sample.oversample_enabled=true end
selectedSampleOversampleOff=function() s.selected_sample.oversample_enabled=false end
PakettiGlobalOversample=function(v) for _,i in ipairs(s.instruments) do for _,a in ipairs(i.samples) do a.oversample_enabled=v end end end
assert(load(block))()
assert(menus['--Main Menu:Tools:Paketti:Sample Playback Quality:Whole Song - 00 None'])
assert(not menus['--Main Menu:Tools:Paketti:Sample Playback Quality:Oversampling'])
assert(menus['Main Menu:Tools:Paketti:Sample Playback Quality:Interpolation (Next)'])
local function reset()
 local a={interpolation_mode=4,oversample_enabled=true,volume=0.7}
 local b={interpolation_mode=2,oversample_enabled=false,volume=0.8}
 local c={interpolation_mode=3,oversample_enabled=true,volume=0.9}
 s={selected_sample=a,selected_instrument={samples={a,b}},undo=0}
 s.instruments={s.selected_instrument,{samples={c}}}
 function s:describe_undo() self.undo=self.undo+1 end
 return a,b,c
end
local base='Main Menu:Tools:Paketti:Sample Playback Quality:'
local function oversampling(scope)
 return base..(scope=='Selected Instrument' and '' or scope..' - ')..'Oversampling'
end
for _,scope in ipairs({'Selected Sample','Selected Instrument','Whole Song'}) do
 local a,b,c=reset()
 for _,v in pairs(menus) do if v.selected then assert(type(v.selected())=='boolean') end end
 assert(menus[base..'Selected Sample - 03 Sinc'].selected())
 assert(not menus[base..'03 Sinc'].selected())
 keys['Global:Paketti:Interpolation (Next) in '..scope](false)
 assert(a.interpolation_mode==1)
 assert(b.interpolation_mode==(scope=='Selected Sample' and 2 or 1))
 assert(c.interpolation_mode==(scope=='Whole Song' and 1 or 3))
 local before=s.undo
 keys['Global:Paketti:Interpolation (Next) in '..scope](true)
 assert(s.undo==before)
 menus[oversampling(scope)].invoke()
 assert(a.oversample_enabled==(scope~='Selected Sample'))
 if scope~='Selected Sample' then assert(b.oversample_enabled) end
 menus[oversampling(scope)].invoke()
 assert(a.oversample_enabled==(scope=='Selected Sample'))
 assert(a.volume==0.7 and b.volume==0.8 and c.volume==0.9)
end
reset()
menus['Sample Editor:Paketti:Sample Playback Quality:01 Linear'].invoke()
assert(s.selected_sample.interpolation_mode==2)
menus['Instrument Box:Paketti:Sample Playback Quality:Whole Song - 02 Cubic'].invoke()
assert(s.instruments[2].samples[1].interpolation_mode==3)
local before=s.undo
midi['Paketti:Interpolation (Next) in Whole Song']({is_trigger=function() return false end})
assert(s.undo==before)
midi['Paketti:Interpolation (Next) in Whole Song']({is_trigger=function() return true end})
assert(s.instruments[2].samples[1].interpolation_mode==4)
s={instruments={},selected_instrument={samples={}}}
for _,v in pairs(menus) do if v.selected then assert(v.selected()==false) end end
menus[base..'Whole Song - Interpolation (Next)'].invoke()
s=nil
for _,v in pairs(menus) do if v.selected then assert(v.selected()==false) end end
print('sample playback quality: menu booleans, mixed scopes, cycles, toggles, preservation, empty targets, repeat and MIDI checks passed')
