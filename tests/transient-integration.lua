-- FEATURE-CARD >> features/transient-integration.feature
-- Executes actual navigation and detection source against a coroutine-backed host.
local function read(path) local f=assert(io.open(path)); local s=f:read('*a'); f:close(); return s end
local keys,menus,midi,notifiers,jobs={},{},{},{},{}
local song,status
local prefs={pakettiTransientNavSelectMode={value=false},pakettiTransientNavDetector={value=1},
 pakettiTransientNavSensitivity={value=60},pakettiTransientNavThreshold={value=40},
 pakettiTransientNavGapMs={value=50},pakettiTransientNavSnapMode={value=1},pakettiTransientNavZeroCross={value=true},save_as=function() end}
local function obs() return {add_notifier=function(_,fn) notifiers[#notifiers+1]=fn end} end
local tool={app_release_document_observable=obs(),app_new_document_observable=obs(),
 add_keybinding=function(_,v) keys[v.name]=v.invoke end,add_midi_mapping=function(_,v) midi[v.name]=v.invoke end}
local window={active_middle_frame=1}
local env=setmetatable({preferences=prefs,renoise={song=function() return song end,
 Sample={LOOP_MODE_OFF=1},ApplicationWindow={MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR=1},
 tool=function() return tool end,app=function() return {show_status=function(_,s) status=s end,window=window} end},
 PakettiAddMenuEntry=function(v) menus[v.name]=v.invoke end,
 BeatDetector=function() return {setSampleRate=function() end,Process=function() return false end} end,
 ProcessSlicer=function(fn)
  local j={co=coroutine.create(fn),active=false}
  function j:start() self.active=true; jobs[#jobs+1]=self end
  function j:running() return self.active end
  function j:stop() self.active=false end
  return j
 end, print=function() end},{__index=_G})
local internals=assert(load(read('PakettiTransientNavigation.lua')..'\nreturn {key=tn_sample_key,cache=tn_cache_valid,bounds=tn_boundaries,crop=tn_crop}', 'transient navigation','t',env))()
local function drain()
 for _,j in ipairs(jobs) do
  while j.active and coroutine.status(j.co)~='dead' do assert(coroutine.resume(j.co)) end
  j.active=false
 end
 jobs={}
end
local function fixture(channels,phase)
 local n=22050
 local b={number_of_frames=n,sample_rate=44100,number_of_channels=channels or 1,bit_depth=16,has_sample_data=true,read_only=false,selection_start=1,selection_end=n,display_length=n,display_start=1,data={},writes=0}
 for c=1,b.number_of_channels do
  b.data[c]={}
  for f=1,n do
   local value=0
   for _,onset in ipairs({4411,13231}) do
    local d=f-onset
    if d>=0 and d<1800 then value=value+0.8*math.exp(-d/400)*math.sin(d*0.3) end
   end
   if phase=='right' and c==1 then value=0 end
   if phase=='opposite' and c==2 then value=-value end
   b.data[c][f]=value
  end
 end
 function b:sample_data(c,f) assert(f>=1 and f<=self.number_of_frames); if self.fail_read then error('deleted buffer') end; return self.data[c][f] end
 function b:create_sample_data(rate,depth,nch,count)
  if self.fail_alloc then return false end
  self.number_of_frames=count; self.data={}; for c=1,nch do self.data[c]={} end
  return true
 end
 function b:prepare_sample_data_changes() end
 function b:set_sample_data(c,f,v) self.writes=self.writes+1; self.data[c][f]=v end
 function b:finalize_sample_data_changes() end
 local sample={sample_buffer=b,name='fixture',slice_markers={},loop_start=1,loop_end=n,loop_mode=1}
 function sample:delete_slice_marker(m) for i,v in ipairs(self.slice_markers) do if v==m then table.remove(self.slice_markers,i); return end end end
 function sample:insert_slice_marker(m) self.slice_markers[#self.slice_markers+1]=m end
 song={selected_sample=sample,selected_instrument_index=1,selected_sample_index=1,describe_undo=function() end}
 return sample,b
end
local analysis=require('PakettiTransientAnalysis')
local options={sensitivity=60,threshold=40,min_gap_ms=50,snap_mode=1,zero_cross=false}
for _,phase in ipairs({'mono','right','opposite'}) do
 local sample,b=fixture(phase=='mono' and 1 or 2,phase)
 local positions=analysis.detect(b,options)
 assert(#positions>=2,phase..' level rise missed hits')
 assert(math.abs(positions[1]-4411)<500 and math.abs(positions[#positions]-13231)<500,phase..' onset placement')
 env.PakettiTransientRedetect(); drain()
 assert(internals.cache(sample))
 local boundaries=internals.bounds(sample)
 assert(#boundaries>=4,phase..' adaptive missed hits')
 assert(boundaries[#boundaries]==b.number_of_frames+1)
 b.selection_start,b.selection_end=1,b.number_of_frames
 env.PakettiTransientNextRegion()
 local first_end=b.selection_end
 env.PakettiTransientNextRegion()
 assert(b.selection_start==first_end+1,'regions overlap or skip')
 b.selection_start,b.selection_end=1,b.number_of_frames
 env.PakettiTransientPreviousRegion()
 assert(b.selection_end==b.number_of_frames,'last region misses final frame')
 local start,endframe=b.selection_start,b.selection_end
 env.PakettiTransientSelectionEdge('both',-1)
 assert(b.selection_start==start and b.selection_end==endframe,'collapsed final region')
 local fingerprint=internals.key(sample)
 local frame=1+math.floor(17*(b.number_of_frames-1)/63)
 b.data[b.number_of_channels][frame]=0.5
 assert(internals.key(sample)~=fingerprint and not internals.cache(sample),'same-length edit not detected')
end
-- Peak placement and minimum-gap settings exercise the actual alternative picker.
local _,settings_buffer=fixture()
local onset=analysis.detect(settings_buffer,options)
local peak=analysis.detect(settings_buffer,{sensitivity=60,threshold=40,min_gap_ms=50,snap_mode=2,zero_cross=false})
assert(#onset==#peak and peak[1]>=onset[1] and peak[1]-onset[1]<=1103)
assert(#analysis.detect(settings_buffer,{sensitivity=60,threshold=40,min_gap_ms=500,snap_mode=1,zero_cross=false})==1)
-- Returning to an analyzed sample restores its cached positions.
local cached_sample=fixture(); local cache_song=song; env.PakettiTransientNextPoint(); drain()
local other_sample=fixture(); song=cache_song; song.selected_sample=other_sample; env.PakettiTransientNextPoint(); drain()
song.selected_sample=cached_sample
assert(internals.cache(cached_sample)); local prior=#jobs; env.PakettiTransientNextPoint(); assert(#jobs==prior)
-- Relative threshold permits quiet audio, while silence yields no false hits.
local _,b=fixture()
for f=1,b.number_of_frames do b.data[1][f]=b.data[1][f]*0.001 end
assert(#analysis.detect(b,options)>=2)
for f=1,b.number_of_frames do b.data[1][f]=0 end
assert(#analysis.detect(b,options)==0)
-- Deferred actions never touch a different sample or survive document release.
local original,old=fixture(); env.PakettiTransientNextPoint()
local replacement,new=fixture(); drain()
assert(new.selection_start==1 and new.selection_end==new.number_of_frames)
env.PakettiTransientNextPoint(); for _,fn in ipairs(notifiers) do fn() end; drain()
assert(new.selection_end==new.number_of_frames)
-- Failed background reads clear the busy state and permit retry.
local sample,b=fixture(); env.PakettiTransientRedetect(); b.fail_read=true; drain(); b.fail_read=false
env.PakettiTransientRedetect(); drain(); assert(internals.cache(sample))
-- Repeated pending commands reuse a job instead of restarting forever.
env.PakettiTransientNavInvalidate(); env.PakettiTransientNextPoint(); local count=#jobs
env.PakettiTransientPreviousPoint(); assert(#jobs==count); drain(); assert(b.selection_start==b.selection_end)
-- Level-rise option powers the same edge selection functions.
prefs.pakettiTransientNavDetector.value=2
env.PakettiTransientRedetect(); drain()
b.selection_start,b.selection_end=4411,4411
env.PakettiTransientSelectionEdge('end',1)
assert(b.selection_end>b.selection_start)
local original_start=b.selection_start
env.PakettiTransientSelectionEdge('start',-1); assert(b.selection_start<original_start)
env.PakettiTransientSelectionEdge('both',1); assert(b.selection_start==1 and b.selection_end==b.number_of_frames)
-- Cropping preserves audio/metadata; removed loops disable; allocation failure stops writes.
sample,b=fixture(); sample.slice_markers={5000,15000}; sample.loop_start=6000; sample.loop_end=9000; sample.loop_mode=2
local expected=b.data[1][5000]
internals.crop(5000,10000,'start')
assert(b.number_of_frames==5001 and b.data[1][1]==expected)
assert(sample.loop_start==1001 and sample.loop_end==4001 and sample.loop_mode==2)
assert(#sample.slice_markers==1 and sample.slice_markers[1]==1)
sample,b=fixture(); sample.loop_start=100; sample.loop_end=200; sample.loop_mode=2
internals.crop(5000,10000,'start'); assert(sample.loop_mode==1)
sample,b=fixture(); b.fail_alloc=true; internals.crop(5000,10000,'start'); assert(b.writes==0 and b.number_of_frames==22050)
sample,b=fixture(); b.read_only=true; internals.crop(5000,10000,'start'); assert(b.writes==0)
print('PASS: actual stereo detectors, quiet/silent audio, regions, edges, stale/error/repeated jobs, cache probes and crop preservation')
-- Optional real WAV regression uses the Lua implementations, not a detector mirror.
if arg[1] then
 local wav=read(arg[1]); assert(wav:sub(1,4)=='RIFF' and wav:sub(9,12)=='WAVE')
 local offset,format,channels,rate,bits,pcm=13
 while offset+7<=#wav do
  local id=wav:sub(offset,offset+3); local size=string.unpack('<I4',wav,offset+4)
  if id=='fmt ' then format,channels,rate=string.unpack('<I2I2I4',wav,offset+8); bits=string.unpack('<I2',wav,offset+22)
  elseif id=='data' then pcm=wav:sub(offset+8,offset+7+size) end
  offset=offset+8+size+size%2
 end
 assert(format==1 and bits==16 and pcm,'expected PCM16 WAV')
 local sample,b=fixture(channels)
 b.number_of_frames=#pcm/(2*channels); b.sample_rate=rate; b.display_length=b.number_of_frames; b.selection_start=1; b.selection_end=b.number_of_frames
 b.data={}; for c=1,channels do b.data[c]={} end
 local offset=1
 for f=1,b.number_of_frames do for c=1,channels do local v; v,offset=string.unpack('<i2',pcm,offset); b.data[c][f]=v/32768 end end
 prefs.pakettiTransientNavDetector.value=1; env.PakettiTransientRedetect(); drain()
 local adaptive=internals.bounds(sample)
 assert(#adaptive-2>=80,'real Lua adaptive regression missed dense hits')
 local novelty=analysis.detect(b,options)
 assert(#novelty>2,'real fixture novelty detector missed later attacks')
 print('PASS: real WAV, actual Lua adaptive '..(#adaptive-2)..' hits, level rise '..#novelty..' hits')
end
