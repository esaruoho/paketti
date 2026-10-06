-- REPORT-CARD >> features/sample-browser-editing.feature
local f=assert(io.open('PakettiLoadSampleBrowser.lua')); local source=f:read('*a'); f:close()
local cut=assert(source:match('(local function plsb_cut_selection%(trim%)%s.-)\n%-%- REPORT%-CARD >> features/sample%-browser%-editing.feature\nlocal function plsb_confirm_delete_file'))
local data={1,2,3,4,5,6,7,8,9,10}
local buf={number_of_frames=10,number_of_channels=1,sample_rate=44100,bit_depth=16}
function buf:create_sample_data(_,_,_,n) self.number_of_frames=n; data={}; return true end
function buf:prepare_sample_data_changes() end
function buf:finalize_sample_data_changes() end
function buf:set_sample_data(_,i,v) data[i]=v end
local sample={sample_buffer=buf,loop_start=6,loop_end=9,loop_mode=4}
local backup={}
function backup:copy_from(s)
 local old={}; for i,v in ipairs(data) do old[i]=v end
 self.sample_buffer={sample_rate=44100,bit_depth=16,number_of_channels=1,sample_data=function(_,_,i) return old[i] end}
end
local inst={samples={sample}}
function inst:insert_sample_at(i) self.samples[i]=backup end
function inst:delete_sample_at(i) table.remove(self.samples,i) end
renoise={Sample={LOOP_MODE_OFF=1},song=function() return {instruments={inst}} end,app=function() return {show_error=function(_,e) error(e) end,show_status=function() end} end}
local S={scratch_index=1,sel_range={2,4},meta={}}
local prefix=[[local S,sample=...
local function plsb_scratch_sample() return sample end
local function plsb_all_notes_off() end
local function plsb_clear_preview_slices() end
local function plsb_compute_peaks() return {} end
local function plsb_sync_loop() end
local function plsb_apply_beatsync() end
local function plsb_refresh() end
]]
assert(load(prefix..cut..'\nreturn plsb_cut_selection'))(S,sample)()
assert(table.concat(data,',')=='1,5,6,7,8,9,10','cut must remove inclusive selected frames')
assert(sample.loop_start==3 and sample.loop_end==6 and sample.loop_mode==4)
assert(S.edited and not S.sel_range and S.meta.frames==7 and #inst.samples==1)
data={1,2,3,4,5,6,7,8,9,10}; buf.number_of_frames=10
sample.loop_start=4; sample.loop_end=6; sample.loop_mode=4; S.sel_range={3,7}
assert(load(prefix..cut..'\nreturn plsb_cut_selection'))(S,sample)(true)
assert(table.concat(data,',')=='3,4,5,6,7' and sample.loop_start==2 and sample.loop_end==4)

print('sample-browser-editing: passed')
local confirm=assert(source:match('(local function plsb_confirm_delete_file%(%).-)\nlocal function plsb_key_handler'))
local timers,handler,deletes={},nil,0
local tool={add_timer=function(_,cb) timers[cb]=true end,remove_timer=function(_,cb) timers[cb]=nil end}
local function widget(_,v) return v end
local vb={column=widget,row=widget,text=widget,button=widget}
renoise.ViewBuilder=function() return vb end
renoise.tool=function() return tool end
renoise.app=function() return {show_custom_dialog=function(_,_,_,h) handler=h; return {visible=true,close=function(self) self.visible=false end} end,show_error=function(_,e) error(e) end,show_status=function() end} end
S.entries={{kind='file',name='test.wav',path='/mock/test.wav'}}; S.selected=1
local cp=[[local S=...
local function plsb_all_notes_off() end
local function plsb_rebuild_entries() end
local function plsb_refresh() end
]]
local ask=assert(load(cp..confirm..'\nreturn plsb_confirm_delete_file'))(S)
local remove=os.remove; os.remove=function(path) assert(path=='/mock/test.wav'); deletes=deletes+1; return true end
for _,key in ipairs({'esc','n','y','return'}) do
 ask(); handler(nil,{name=key,state='pressed'})
 local cb=next(timers); assert(cb); cb(); assert(not S.delete_dialog and not next(timers))
end
os.remove=remove
assert(deletes==2,'only Y and Enter may delete the source file')
print('sample-browser-delete-confirmation: passed')

local rebuild=assert(source:match('(local function plsb_rebuild_entries%(.-)\nlocal function plsb_enter_dir'))
local rp=[[local S=...
local PLSB_DRIVE_ROOT='/drives'
local VISIBLE_ROWS=5
local function plsb_list_drives() return {} end
local function plsb_find_parse() return nil end
local function plsb_find_match(_,name) return name:find("kick",1,true) ~= nil end
local function plsb_parent(dir) return dir end
local function plsb_join(dir,f) return dir..'/'..f end
local function plsb_adjust_scroll() end
local function plsb_preview_selected() assert(S.selected>=1 and S.selected<=math.max(1,#S.entries)) end
]]
local dirs,files=os.dirnames,os.filenames
os.dirnames=function() return {} end
local count=19
os.filenames=function() local r={} for i=1,count do r[i]=string.format('%02d.wav',i) end return r end
PakettiLoadableExtensions=function() return {'*.wav'} end
local state={current_dir='/samples',selected=20,scroll=15}
local refresh=assert(load(rp..rebuild..'\nreturn plsb_rebuild_entries'))(state)
refresh(nil,20); assert(state.selected==19 and state.scroll==14)
refresh(nil,10); assert(state.selected==10)
count=0; refresh(nil,1); assert(state.selected==1 and #state.entries==0 and state.scroll==0)
os.dirnames,os.filenames=dirs,files
print('sample-browser-delete-cursor: passed')

local octave=assert(source:match('(local function plsb_octave_key_delta%(key%).-)\nlocal function plsb_key_handler'))
local delta=assert(load(octave..'\nreturn plsb_octave_key_delta'))()
for _,mods in ipairs({'','capslock','caps','shift','shift,capslock','shift,caps'}) do
 assert(delta({name='less',character='<',modifiers=mods})==-1)
 assert(delta({name='less',character='>',modifiers=mods})==1)
 assert(delta({name='greater',modifiers=mods})==1)
 assert(delta({name='less',modifiers=mods})==(mods:find('shift',1,true) and 1 or -1))
end
assert(delta({name='a',modifiers='capslock'})==nil)
print('sample-browser-caps-octave: passed')

local sync=assert(source:match('(local function plsb_apply_beatsync%(smp%).-)\n%-%- load the highlighted'))
renoise.song=function() return {transport={bpm=120,lpb=4}} end
local syncstate={beatsync=4}
local apply=assert(load('local S=...\n'..sync..'\nreturn plsb_apply_beatsync'))(syncstate)
local target={sample_buffer={number_of_frames=88200,sample_rate=44100}}
apply(target); assert(target.beat_sync_enabled and target.beat_sync_mode==3 and target.beat_sync_lines==16)
syncstate.beatsync=1; apply(target); assert(target.beat_sync_enabled==false)
os.dirnames=function(path) return path=='/root' and {'nested'} or {} end
os.filenames=function(path) return path=='/root' and {'snare.wav'} or {'kick.wav'} end
state.search_root='/root'; state.find_query='kick'; state.current_dir='/other'
refresh(nil,1)
for _=1,5 do local cb=next(timers); if cb then cb() end end
assert(#state.entries==1 and state.entries[1].path=='/root/nested/kick.wav')
assert(not state.search_timer and not next(timers))
os.dirnames,os.filenames=dirs,files
print('sample-browser-trim-beatsync-root-search: passed')
local playhead=assert(source:match('(local function plsb_stop_playhead%(%).-)\n%-%- scratch instrument'))
renoise.Sample={LOOP_MODE_OFF=1,LOOP_MODE_FORWARD=2,LOOP_MODE_REVERSE=3,LOOP_MODE_PING_PONG=4}
local phstate={scratch_index=1,dialog={visible=true}}
local phsample={sample_buffer={has_sample_data=true,number_of_frames=1000,sample_rate=100},sample_mapping={base_note=48},transpose=0,fine_tune=0,loop_mode=4,loop_start=200,loop_end=400,beat_sync_enabled=false}
renoise.song=function() return {instruments={{samples={phsample}}},transport={bpm=120,lpb=4}} end
local stop,pos,start=assert(load('local S=...\n'..playhead..'\nreturn plsb_stop_playhead,plsb_playhead_position,plsb_start_playhead'))(phstate)
local p={offset=300,speed=100,frames=1000,mode=1,start=200,stop=400}
assert(pos(p,2)==500 and pos(p,8)==nil)
p.offset=1; p.mode=2; assert(pos(p,5)==301)
p.mode=3; assert(pos(p,5)==299)
p.mode=4; assert(pos(p,5)==299 and pos(p,7)==301)
start('__wave__',48,300); assert(phstate.playhead_frame==300 and phstate.playhead.mode==1)
stop(); assert(not phstate.playhead and not next(timers))
start('z',60); assert(phstate.playhead.speed==200 and phstate.playhead.mode==4)
phstate.dialog.visible=false; next(timers)(); assert(not phstate.playhead and not next(timers))
print('sample-browser-playhead: passed')
local setter=assert(source:match('(local function plsb_set_sync%(property, value%).-)\n%-%- map a canvas'))
local ss={beatsync=1,sync_lines=16,sync_mode=1}
local st={sample_buffer={number_of_frames=1000,sample_rate=100}}
local set=assert(load('local S,sample=...\nlocal function plsb_scratch_sample() return sample end\n'..sync..setter..'\nreturn plsb_set_sync'))(ss,st)
set('lines',37); assert(st.beat_sync_lines==37 and not st.beat_sync_enabled)
set('mode',3); set('enabled',true)
assert(st.beat_sync_enabled and st.beat_sync_mode==3 and st.beat_sync_lines==37)
set('enabled',false); assert(not st.beat_sync_enabled and st.beat_sync_lines==37)
set('lines',900); assert(st.beat_sync_lines==512)
set('lines',0); assert(st.beat_sync_lines==1)
ss.syncing_playback=true; set('lines',55); assert(st.beat_sync_lines==1)
print('sample-browser-exact-beatsync: passed')
