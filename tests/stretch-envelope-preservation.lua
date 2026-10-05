-- Run: lua tests/stretch-envelope-preservation.lua
local f=assert(io.open("PakettiStretch.lua")); local source=f:read("*a"); f:close()
local function extract(first,last)
  local a=assert(source:find(first,1,true)); local b=assert(source:find(last,a,true)); return source:sub(a,b-1)
end
local function device(enabled)
  local d={name="Volume AHDSR",enabled=enabled,operator=2,parameters={}}
  for i=1,8 do d.parameters[i]={value=i/10,value_string="custom"} end
  return d
end
local other,selected=device(false),device(false)
local sample={modulation_set_index=2,new_note_action=3,loop_mode=1}
local instrument={sample_modulation_sets={{devices={other}},{devices={selected}}}}
local song={selected_sample=sample,selected_instrument=instrument}
local checkbox={value=false}
local env={song=song,renoise={song=function() return song end,app=function() return {show_status=function() end} end},
  vb={views={envelope_checkbox=checkbox}},release_time_text={},scale_value_text={}}
setmetatable(env,{__index=_G})
local helpers=extract('local function find_stretch_volume_ahdsr_device','-- Add this helper function')
local function notifier(start, signature)
  local a=assert(source:find(start,1,true)); a=assert(source:find(signature or 'notifier=function(new_value)',a,true))
  local b=assert(source:find('\n                end',a,true))
  return source:sub(a,b-1):gsub('^notifier=','')..'\nend'
end
assert(not source:find('device.enabled =',1,true), 'Timestretch must never write enabled state')
assert(not source:find('envelope_checkbox',1,true), 'No startup checkbox callback')
local build=helpers..'\nreturn '..'function() return find_stretch_volume_ahdsr_device(song.selected_instrument) end'..','..notifier('-- Release Time slider')..','..notifier('-- Release Value scaling slider')
local toggle,release,scaling=assert(load(build,'actual envelope notifiers','t',env))()
local function preserved(except)
  assert(selected.operator==2 and sample.new_note_action==3 and sample.loop_mode==1)
  assert(other.enabled==false)
  for i=1,8 do if i~=except then assert(selected.parameters[i].value==i/10,'Parameter '..i..' overwritten') end end
end
toggle(true); assert(not selected.enabled); preserved()
toggle(); assert(not selected.enabled); preserved()
-- Device lookup and explicit parameter editing never enable an off envelope.
toggle(true); preserved()
selected.enabled=false
release(17); assert(not selected.enabled and selected.parameters[5].value==0.17); preserved(5)
selected.parameters[5].value=0.5
scaling(23); assert(selected.parameters[8].value==0.23); preserved(8)
-- No assigned modulation set must never edit an unrelated envelope.
sample.modulation_set_index=0; selected.enabled=false
toggle(true); assert(not selected.enabled and not other.enabled)
print('PASS: read-only lookup preserves AHDSR, operator and sample settings; Release/Scaling edit only their parameter; selected-set targeting')
