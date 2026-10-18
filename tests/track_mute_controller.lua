-- Run: lua tests/track_mute_controller.lua
local timers, sent, closed = {}, {}, 0
local function observable() return {add_notifier=function() end} end
local tool = {bundle_path="/tmp/", app_release_document_observable=observable(), app_new_document_observable=observable()}
function tool:has_timer(fn) return timers[fn] ~= nil end
function tool:add_timer(fn, interval) timers[fn]=interval end
function tool:remove_timer(fn) timers[fn]=nil end
function tool:add_menu_entry() end
function tool:add_keybinding() end
local song = {tracks={
  {name="Drums", type=1, mute_state=1},
  {name="Bass", type=1, mute_state=2},
  {name="Master", type=2, mute_state=1}
}}
renoise = {
  Track={TRACK_TYPE_SEQUENCER=1, MUTE_STATE_ACTIVE=1, MUTE_STATE_MUTED=2},
  tool=function() return tool end, song=function() return song end,
  app=function() return {show_status=function() end} end,
  Document={create=function() return function(defaults)
    local doc={load_from=function() end, save_as=function() end}
    for k,v in pairs(defaults) do doc[k]={value=v} end
    return doc
  end end},
  Midi={create_input_device=function() return {close=function() closed=closed+1 end} end,
    create_output_device=function() return {
      send=function(_, m) sent[#sent+1]=m end, close=function() closed=closed+1 end
    } end}
}
dofile("PakettiTrackMuteController.lua")
local M=PakettiTrackMute
local c=M.config
c.input.value="MPK test"
c.output.value="MPK test"
c.feedback.value=true
assert(M.start())
assert(sent[1][1]==0x99 and sent[1][2]==36 and sent[1][3]==127)
assert(sent[2][3]==0)
local function midi(kind, note, value, ch) M.on_midi({kind+(ch or 9),note,value}) end
midi(0x90,36,100)
assert(song.tracks[1].mute_state==2)
midi(0x90,36,120) -- duplicate positive value
assert(song.tracks[1].mute_state==2)
midi(0x80,36,0)
assert(song.tracks[1].mute_state==2)
midi(0x90,36,100)
assert(song.tracks[1].mute_state==1)
song.tracks[1].mute_state=2 -- external mouse/mapping edit
M.refresh()
assert(sent[#sent][2]==36 and sent[#sent][3]==0)
local count=#sent
M.refresh() assert(#sent==count) -- diff rendering
M.stop()
c.input_kind.value=2
assert(M.start())
midi(0x90,36,127) assert(song.tracks[1].mute_state==1)
midi(0x80,36,0) assert(song.tracks[1].mute_state==2)
midi(0x90,36,0) assert(song.tracks[1].mute_state==2) -- duplicate off
M.stop()
c.input_kind.value=1 c.behavior.value=2
song.tracks[1].mute_state=1
assert(M.start())
midi(0x90,36,127) assert(song.tracks[1].mute_state==2)
M.stop() assert(song.tracks[1].mute_state==1) -- restore on stop
assert(M.start())
midi(0x90,36,127) midi(0x80,36,0)
assert(song.tracks[1].mute_state==1)
midi(0x90,38,127) assert(song.tracks[3].mute_state==1) -- never mute Master
M.stop()
c.message_kind.value=2 c.behavior.value=1 c.input_kind.value=2
assert(M.start())
midi(0xB0,36,127) assert(song.tracks[1].mute_state==2)
midi(0xB0,36,0) assert(song.tracks[1].mute_state==1)
midi(0xB0,36,127,0) assert(song.tracks[1].mute_state==1) -- other channel
M.test_leds() assert(timers[M.finish_led_test]==1000)
M.finish_led_test() assert(not timers[M.finish_led_test])
assert(sent[#sent][1]==0xB9)
M.stop() assert(not timers[M.refresh])
assert(not M.parse_notes("36,36"))
assert(not M.parse_notes("36,"))
assert(not M.parse_notes("128"))
assert(#M.parse_notes("36, 37")==2)
assert(closed>0)
c.behavior.value=3 c.input_kind.value=1 c.message_kind.value=1
song.tracks[1].mute_state=2
assert(M.start())
midi(0x90,36,100) assert(song.tracks[1].mute_state==1)
midi(0x80,36,0) assert(song.tracks[1].mute_state==2)
M.stop()
-- Render both dialogs against a small ViewBuilder contract and exercise clicks.
local dialogs={}
renoise.Midi.available_input_devices=function() return {"MPK test"} end
renoise.Midi.available_output_devices=function() return {"MPK test"} end
renoise.ViewBuilder=function()
  return setmetatable({}, {__index=function(_, kind)
    return function(_, props)
      props.kind=kind
      props.add_child=function(self, child) self[#self+1]=child end
      return props
    end
  end})
end
local app={show_status=function() end}
function app:show_custom_dialog(title, content, handler)
  local d={title=title,content=content,visible=true,handler=handler}
  function d:show() self.visible=true end
  function d:close() self.visible=false end
  dialogs[#dialogs+1]=d
  return d
end
renoise.app=function() return app end
PakettiTrackMuteControllerDialog()
PakettiTrackMuteModesDialog()
assert(#dialogs==2 and timers[M.ui_refresh]==50)
local function find(view, predicate)
  if predicate(view) then return view end
  for _,child in ipairs(view) do local found=find(child,predicate) if found then return found end end
end
local button=find(dialogs[2].content,function(v) return v.kind=='button' and v.text:find('Drums',1,true) end)
assert(button and button.color[1]==190)
button.notifier() assert(song.tracks[1].mute_state==1 and button.color[2]==160)
song.tracks[1].mute_state=2
M.ui_refresh() assert(button.color[1]==190)
dialogs[2]:close() M.ui_refresh() assert(not timers[M.ui_refresh])
-- Output failure must stop without a recursive refresh failure.
renoise.Midi.create_output_device=function() return {send=function() error('disconnected') end,close=function() end} end
assert(not M.start())
assert(not timers[M.refresh])
print("track mute controller regression checks passed")
