-- Run: lua tests/loader-ahdsr-release.lua
local function extract(path,first,last)
 local f=assert(io.open(path)); local s=f:read('*a'); f:close()
 local a=assert(s:find(first,1,true)); local b=assert(s:find(last,a,true)); return s:sub(a,b-1)
end
local function device()
 local d={name='Volume AHDSR',is_active=false,enabled=false,operator=2,tempo_synced=true,parameters={}}
 for i=1,8 do d.parameters[i]={value=i/10} end
 return d
end
local d=device(); local instrument={sample_modulation_sets={{devices={d},filter_type='None'}}}
local prefs={pakettiPitchbendLoaderEnvelope={value=false},pakettiLoaderFilterType={value='None'}}
local env=setmetatable({preferences=prefs},{__index=_G})
assert(load(extract('PakettiSamples.lua','function PakettiApplyLoaderModulationSettings','function pakettiPreferencesDefaultInstrumentLoader'),'loader','t',env))()
env.PakettiApplyLoaderModulationSettings(instrument)
assert(not d.is_active and d.tempo_synced and not d.parameters[5].value_string)
prefs.pakettiPitchbendLoaderEnvelope.value=true
env.PakettiApplyLoaderModulationSettings(instrument)
assert(d.is_active and not d.tempo_synced and d.parameters[5].value_string=='480 ms')
for i=1,8 do assert(d.parameters[i].value==i/10) end
assert(d.operator==2)
local sample={modulation_set_index=1}
local stretch=setmetatable({renoise={song=function() return {selected_sample=sample,selected_instrument=instrument} end}},{__index=_G})
local helpers=extract('PakettiStretch.lua','local function find_stretch_volume_ahdsr_device','-- Add this helper function')
local set_release=assert(load(helpers..'return set_stretch_release_480ms','stretch','t',stretch))()
d.parameters[5].value_string=nil; d.tempo_synced=true
assert(set_release()); assert(d.parameters[5].value_string=='480 ms' and not d.enabled and d.operator==2)
print('PASS: preference off untouched; preference on sets 480 ms; explicit Timestretch action preserves enabled state and other values')
