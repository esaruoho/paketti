-- Run: lua tests/parameter-editor-close.lua
local function section(path,first,last)
 local f=assert(io.open(path)); local s=f:read("*a"); f:close()
 local a=assert(s:find(first,1,true)); local b=assert(s:find(last,a,true)); return s:sub(a,b-1)
end
local close_source=section("PakettiCanvasExperiments.lua","function PakettiCanvasExperimentsCloseDialog()","-- Song-lifecycle safety:")
local hide_source=section("PakettiLoaders.lua","function hide_all_external_editors()",'renoise.tool():add_keybinding{name="Global:Paketti:Hide Track DSP')
local cleanup,closed=0,0
local dialog={visible=true,focused=false}
function dialog:close() assert(cleanup>0); self.visible=false; closed=closed+1 end
local env=setmetatable({canvas_experiments_dialog=dialog,PakettiCanvasExperimentsCleanup=function() cleanup=cleanup+1 end},{__index=_G})
assert(load(close_source,'close dialog','t',env))()
local external={external_editor_available=true,external_editor_visible=true}
local track={devices={{},external},device=function(self,i) return self.devices[i] end}
local song={tracks={track},instruments={},track=function(self,i) return self.tracks[i] end}
local status
local host=setmetatable({renoise={song=function() return song end,app=function() return {show_status=function(_,s) status=s end} end},PakettiCanvasExperimentsCloseDialog=env.PakettiCanvasExperimentsCloseDialog},{__index=_G})
host._G=host
assert(load(hide_source,'hide editors','t',host))()
host.hide_all_external_editors()
assert(not dialog.visible and closed==1 and cleanup==1)
assert(not external.external_editor_visible)
assert(status:find('Parameter Editor',1,true))
host.hide_all_external_editors(); assert(closed==1 and cleanup==1)
-- When the parameter editor module is unavailable, external editors still close.
host.PakettiCanvasExperimentsCloseDialog=nil; external.external_editor_visible=true
host.hide_all_external_editors(); assert(not external.external_editor_visible)
print('PASS: unfocused parameter editor closes with cleanup; external editors still close; repeated/missing-module calls safe')

-- Exercise the actual focused Cmd-H branch with the real shared hide action.
local key_source=section("PakettiCanvasExperiments.lua", "function paketti_canvas_keyhandler_func(dialog, key)", "  -- Check for SPACE to open external editor") .. "  return key\nend\n"
host.preferences={pakettiDialogClose={value="esc"}}
assert(load(key_source,'focused hide shortcut','t',host))()
host.PakettiCanvasExperimentsCloseDialog=env.PakettiCanvasExperimentsCloseDialog
local sample_fx={external_editor_available=true,external_editor_visible=true}
local plugin={external_editor_available=true,external_editor_visible=true}
local hidden={external_editor_available=true,external_editor_visible=false}
local chain={devices={{},sample_fx,hidden},device=track.device}
local instrument={sample_device_chains={chain},plugin_properties={plugin_device=plugin}}
song.instruments={instrument}; song.instrument=function(self,i) return self.instruments[i] end
external.external_editor_visible=true; dialog.visible=true
local ordinary={name="h",modifiers=""}
assert(host.paketti_canvas_keyhandler_func(dialog,ordinary)==ordinary)
assert(dialog.visible and external.external_editor_visible and plugin.external_editor_visible)
assert(host.paketti_canvas_keyhandler_func(dialog,{name="h",modifiers="command"})==nil)
assert(not dialog.visible and not external.external_editor_visible)
assert(not sample_fx.external_editor_visible and not plugin.external_editor_visible and not hidden.external_editor_visible)
assert(closed==2 and cleanup==2)
host.paketti_canvas_keyhandler_func(dialog,{name="h",modifiers="command"})
assert(closed==2 and cleanup==2)
print('PASS: focused Cmd-H consumes key, cleans dialog, hides track/plugin/sample FX editors; plain H and repeated hide are safe')
