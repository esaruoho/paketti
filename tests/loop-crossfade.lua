-- FEATURE-CARD >> features/loop-crossfade.feature
local menus,keys,midi={},{},{}
local status
local song={describe_undo=function() end}
renoise={Sample={LOOP_MODE_FORWARD=2},song=function() return song end,
 app=function() return {show_status=function(_,s) status=s end} end,
 tool=function() return {
 add_menu_entry=function(_,e) menus[e.name]=e.invoke end,
 add_keybinding=function(_,e) keys[e.name]=e.invoke end,
 add_midi_mapping=function(_,e) midi[e.name]=e.invoke end} end}
dofile('PakettiLoopCrossfade.lua')
local function sample(channels,n,rate)
 local b={has_sample_data=true,number_of_frames=n,number_of_channels=channels,sample_rate=rate or 1000,
 selection_range={1,n},data={},prepared=0,finalized=0}
 for c=1,channels do b.data[c]={}; for i=1,n do b.data[c][i]=i/(n*2)+c/10 end end
 function b:sample_data(c,i) assert(i>=1 and i<=n,'read outside buffer');return self.data[c][i] end
 function b:set_sample_data(c,i,v) assert(i>=1 and i<=n,'write outside buffer'); if self.fail then error('injected write failure') end;self.data[c][i]=v end
 function b:prepare_sample_data_changes() self.prepared=self.prepared+1 end
 function b:finalize_sample_data_changes() self.finalized=self.finalized+1 end
 return {sample_buffer=b,loop_start=11,loop_end=n,loop_mode=2}
end
local function opts(curve,length,mode) return {curve=curve or 'linear',length_mode=mode or 'auto',length=length,region='selection',units='frames'} end
for _,curve in ipairs({'linear','equal_power'}) do
 local s=sample(2,20);local before={};for c=1,2 do before[c]={};for i=1,20 do before[c][i]=s.sample_buffer.data[c][i] end end
 assert(PakettiLoopCrossfadeSample(s,11,20,opts(curve),false)==10)
 for c=1,2 do
  for i=1,10 do assert(s.sample_buffer.data[c][i]==before[c][i]) end
  assert(s.sample_buffer.data[c][20]==before[c][10])
  local t=0.5;local a,z=t,1-t;if curve=='equal_power' then a,z=math.sin(t*math.pi/2),math.cos(t*math.pi/2) end
  assert(math.abs(s.sample_buffer.data[c][15]-(before[c][15]*z+before[c][5]*a))<1e-12)
 end
 assert(s.sample_buffer.prepared==1 and s.sample_buffer.finalized==1)
end
local s=sample(1,30)
assert(PakettiLoopCrossfadeSample(s,11,20,opts('linear',2,'frames'),false)==2)
assert(s.sample_buffer.data[1][21]==21/60+0.1)
assert(PakettiLoopCrossfadeSample(s,11,20,opts('linear',100,'frames'),false)==10)
assert(PakettiLoopCrossfadeSample(s,11,20,opts('linear',2,'ms'),false)==2)
assert(not PakettiLoopCrossfadeSample(s,11,20,opts('linear',1,'frames'),false))
assert(not PakettiLoopCrossfadeSample(s,1,20,opts(),false))
assert(not PakettiLoopCrossfadeSample(s,11,31,opts(),false))
s.loop_mode=3;assert(not PakettiLoopCrossfadeSample(s,11,20,opts(),false))
assert(PakettiLoopCrossfadeSample(s,11,20,opts(),true));assert(s.loop_mode==2 and s.loop_start==11 and s.loop_end==20)
s.sample_buffer.read_only=true;assert(not PakettiLoopCrossfadeSample(s,11,20,opts(),true));s.sample_buffer.read_only=false
s.sample_buffer.fail=true;local prior=s.sample_buffer.finalized
local f,reason=PakettiLoopCrossfadeSample(s,11,20,opts(),true)
assert(not f and reason:find('write failed',1,true));assert(s.sample_buffer.finalized==prior+1)
local a,b,empty,slice=sample(1,30),sample(1,60,2000),sample(1,30),sample(1,30)
empty.sample_buffer.has_sample_data=false;slice.sample_buffer.read_only=true
song.selected_sample=a;song.selected_instrument={samples={a,b,empty,slice}}
a.sample_buffer.selection_range={11,20}
local o=opts();o.units='time';PakettiLoopCrossfadeApply('instrument',o)
assert(a.loop_start==11 and a.loop_end==20 and b.loop_start==21 and b.loop_end==40)
assert(status:find('2/4 samples',1,true))
song.selected_sample=empty;o.region='loop';PakettiLoopCrossfadeApply('instrument',o);assert(status:find('2/4 samples',1,true))
-- Legacy caller must edit the selected sample, not sample 1, and never touch monitoring.
local file=assert(io.open('PakettiExperimental_Verify.lua'));local source=file:read('*a');file:close()
assert(load(source:match('(function crossfade_loop%(crossfade_length%).-)\n%-%- Helper function')))()
song.selected_sample=b;local untouched=a.sample_buffer.data[1][20];crossfade_loop(2)
assert(a.sample_buffer.data[1][20]==untouched)
assert(b.sample_buffer.data[1][40]==b.sample_buffer.data[1][20])
-- Execute the actual fixed-end implementation at the sample end.
file=assert(io.open('PakettiProcess.lua'));source=file:read('*a');file:close()
assert(load(source:match('(function crossfade_loop_edges_fixed_end%(%).-)\nfunction paketti_build_sample_variants')))()
local fixed=sample(1,100);fixed.loop_start=51;song.selected_sample=fixed;song.selected_sample_index=1;song.selected_instrument={samples={fixed}}
crossfade_loop_edges_fixed_end();assert(fixed.sample_buffer.data[1][100]==0)
assert(fixed.sample_buffer.finalized==1)
fixed.sample_buffer.fail=true;crossfade_loop_edges_fixed_end();assert(fixed.sample_buffer.finalized==2)
-- Repeated shortcuts and non-trigger MIDI are inert.
local before=b.sample_buffer.prepared
keys['Sample Editor:Paketti:Loop Crossfade Sample'](true)
midi['Paketti:Loop Crossfade Sample']({is_trigger=function() return false end})
assert(before==b.sample_buffer.prepared)
print('loop-crossfade: all checks passed')
local hot=sample(1,20);for i=1,20 do hot.sample_buffer.data[1][i]=0.9 end
assert(not PakettiLoopCrossfadeSample(hot,11,20,opts('equal_power'),false))
assert(hot.sample_buffer.prepared==0)
assert(PakettiLoopCrossfadeSample(hot,11,20,opts('linear'),false))
local marker=sample(1,20)
marker.loop_start=nil
setmetatable(marker,{__newindex=function(_,key) if key=='loop_start' then error('injected marker failure') end end})
local _,why=PakettiLoopCrossfadeSample(marker,11,20,opts(),true)
assert(why:find('loop markers failed',1,true))
a=sample(1,30);b=sample(1,60,2000);a.sample_buffer.selection_range={11,20}
song.selected_sample=a;song.selected_instrument={samples={a,b}}
PakettiLoopCrossfadeApply('instrument',opts());assert(b.loop_start==11 and b.loop_end==20)
-- UI constructs valid rows and changing mode enables the length control.
local controls={}
renoise.ViewBuilder=function()
 local vb={}
 for _,kind in ipairs({'valuebox','popup','text','row','column','button'}) do
  vb[kind]=function(_,v) controls[#controls+1]={kind=kind,view=v};return v end
 end
 return vb
end
renoise.app=function() return {show_custom_dialog=function(_,title,view,handler)
 assert(title=='Paketti Loop Crossfade' and view.margin==10)
 return {visible=true,close=function(self) self.visible=false end}
 end,show_status=function(_,s) status=s end} end
PakettiLoopCrossfadeDialog()
local valuebox
for _,control in ipairs(controls) do if control.kind=='valuebox' then valuebox=control.view end end
assert(valuebox.active==false)
for _,control in ipairs(controls) do
 if control.kind=='popup' and control.view.items[1]=='Auto' then control.view.notifier(2) end
end
assert(valuebox.active==true)
print('loop-crossfade: headroom, marker errors, batch frames and dialog checks passed')
file=assert(io.open('PakettiProcess.lua'));source=file:read('*a');file:close()
assert(load(source:match('(function crossfade_with_fades%(%).-)\n%-%-%[%[')))()
local reverse=sample(2,20);song.selected_sample=reverse
local original={};for c=1,2 do original[c]={};for i=1,20 do original[c][i]=reverse.sample_buffer.data[c][i] end end
crossfade_with_fades()
for c=1,2 do
 assert(reverse.sample_buffer.data[c][1]==0 and reverse.sample_buffer.data[c][20]==0)
 assert(reverse.sample_buffer.data[c][10]==(original[c][10]+original[c][11])*0.5)
end
reverse.sample_buffer.read_only=true;local prepared=reverse.sample_buffer.prepared
crossfade_with_fades();assert(reverse.sample_buffer.prepared==prepared)
reverse.sample_buffer.read_only=false;reverse.sample_buffer.fail=true
crossfade_with_fades();assert(reverse.sample_buffer.finalized==2)
local finalize=sample(1,20)
function finalize.sample_buffer:finalize_sample_data_changes() error('injected finalize failure') end
assert(not PakettiLoopCrossfadeSample(finalize,11,20,opts(),false))
print('loop-crossfade: reverse-blend preservation and finalize failure checks passed')
