-- REPORT-CARD >> features/sample-browser-loop-load.feature
local function read(path) local f=assert(io.open(path)); local s=f:read('*a'); f:close(); return s end
local browser=read('PakettiLoadSampleBrowser.lua')
local body=assert(browser:match('(local function plsb_do_load%(path, opts%).-)\nlocal function plsb_confirm_now'))
local sample={slice_markers={},sample_buffer={has_sample_data=true,number_of_frames=100,sample_rate=44100}}
local loads,cues=0,0
sample.sample_buffer.load_from=function() loads=loads+1; sample.slice_markers={} end
local song={transport={bpm=120,lpb=4},selected_instrument_index=1,instruments={{samples={sample}}}}
renoise={Sample={LOOP_MODE_OFF=1},song=function() return song end,app=function() return {show_status=function() end} end}
pakettiPreferencesDefaultInstrumentLoader=function() end
PakettiInjectApplyLoaderSettings=function(s) s.loop_mode=2 end
PakettiWavCueImportWavWithCuesIntoSample=function(s) cues=cues+1; s.slice_markers={1,50} end
local S={}
local prefix=[[local S, sample = ...
local PLSB_NATIVE={wav=true}
local function plsb_ext() return 'wav' end
local function plsb_basename() return 'test' end
local function plsb_cleanup_scratch() S.loop=nil end
local function plsb_pick_target() return 1 end
local function plsb_finalize() end
local function plsb_scratch_sample() return sample end
]]
local sync=assert(browser:match('(local function plsb_apply_beatsync%(smp%).-)\n%-%- load the highlighted'))
local run=assert(load(prefix..sync..body..'\nreturn plsb_do_load'))(S,sample)
S.loop={mode=4,start=3,stop=6,frames=100}
S.beatsync=3; S.sync_lines=37
S.playback_choices={interpolation_mode=4,oversample_enabled=true,autofade=false}
run('test.wav')
assert(sample.beat_sync_enabled and sample.beat_sync_mode==2 and sample.beat_sync_lines==37)
assert(sample.interpolation_mode==4 and sample.oversample_enabled==true and sample.autofade==false)
assert(loads==1 and cues==0 and #sample.slice_markers==0)
assert(sample.loop_mode==4 and sample.loop_start==3 and sample.loop_end==6,'Ping-Pong loop must survive loading and loader defaults')
S.loop={mode=1,start=3,stop=6,frames=100}
run('test.wav'); assert(cues==1,'cue sets still import when preview loop is off')
local saved, loaded_path
sample.sample_buffer.save_as=function(_, path, format) saved=path; assert(format=='wav'); return true end
sample.sample_buffer.load_from=function(_, path) loaded_path=path; sample.slice_markers={}; return true end
S.edited=true; S.loaded_path='test.wav'; S.loop={mode=4,start=3,stop=6,frames=100}
run('test.wav'); assert(saved and loaded_path==saved, 'final load must use edited preview audio')
local source=read('PakettiWavCueExtract.lua')
local importer=assert(source:match('(function PakettiWavCueImportWavWithCuesIntoSample%(sample, wav_path%).-)\nfunction '))
-- Execute the real importer through its early normal-load branch.
assert(load(importer))()
print=function() end
for _,info in ipairs({{cues={}},{cues={{offset=50}}}}) do
  PakettiWavCueParseWavCues=function() return info end
  local n=0
  local s={sample_buffer={load_from=function() n=n+1 end},insert_slice_marker=function() error('single cue became a slice') end}
  PakettiWavCueImportWavWithCuesIntoSample(s,'test.wav'); assert(n==1)
end
io.write('sample-browser-loop-load: passed\n')
