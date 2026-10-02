-- Run from the tool root: lua tests/sample-browser-deferred-close.lua
-- REPORT-CARD >> features/sample-browser-deferred-close.feature
local timers, binding = {}, nil
local dispatching, closes, loads = false, 0, 0
local tool = {
  has_timer = function(_, cb) return timers[cb] ~= nil end,
  add_timer = function(_, cb, ms) assert(ms == 50); timers[cb] = ms end,
  remove_timer = function(_, cb) timers[cb] = nil end,
  add_keybinding = function(_, entry) binding = entry end,
  add_midi_mapping = function() end,
}
local app = {window = {}, show_status = function() end,
  show_error = function(_, err) error(err) end}
local sample = {sample_buffer = {load_from = function()
  assert(not dispatching, 'sample loaded during keyboard dispatch')
  loads = loads + 1; return true
end}}
local song = {instruments = {{name = 'target', samples = {},
  plugin_properties = {plugin_loaded = false}}}, selected_instrument_index = 1}
renoise = {tool = function() return tool end, app = function() return app end,
  song = function() return song end,
  ApplicationWindow = {MIDDLE_FRAME_PATTERN_EDITOR = 1}}
PakettiAddMenuEntry = function() end
pakettiPreferencesDefaultInstrumentLoader = function()
  assert(not dispatching); song.instruments[song.selected_instrument_index].samples = {sample}
end
safeInsertInstrumentAt = function(_, index)
  table.insert(song.instruments, index, {name = 'target', samples = {}, plugin_properties = {plugin_loaded = false}})
  return true
end
PakettiInjectApplyLoaderSettings = function() end
PakettiExpandLoadableCleanup = function() end
dofile('PakettiLoadSampleBrowser.lua')
local function up(fn, wanted)
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then return value end
  end
  error('Missing upvalue: ' .. wanted)
end
local S = up(PakettiLoadSampleBrowserToggle, 'S')
local handler = up(PakettiLoadSampleBrowser_Open, 'plsb_key_handler')
local release = up(PakettiLoadSampleBrowser_Open, 'plsb_on_document_release')
local function setup(kind)
  song.instruments = {song.instruments[1]}
  song.selected_instrument_index = 1
  song.instruments[1].samples = {}
  S.dialog = {visible = true, close = function(self)
    assert(not dispatching, 'window closed during keyboard dispatch')
    closes = closes + 1; self.visible = false
  end}
  S.entries = {{kind = kind, path = '/sample.wav', name = 'sample.wav'}}
  S.selected = 1
end
local function fire()
  local cb = next(timers); assert(cb, 'expected queued timer')
  cb(); assert(next(timers) == nil, 'timer must be one-shot')
  assert(S.pending_action == nil)
end
setup('file')
dispatching = true
binding.invoke(false)
local pending = S.pending_action
binding.invoke(false); binding.invoke(true)
handler(S.dialog, {name = 'down', state = 'pressed'})
assert(S.pending_action == pending and S.selected == 1)
assert(loads == 0 and closes == 0 and S.dialog.visible)
dispatching = false
fire()
assert(loads == 1 and closes == 1 and S.dialog == nil)
assert(app.window.active_middle_frame == 1)
binding.invoke(true); assert(next(timers) == nil, 'repeat reopened dialog')

setup('file')
dispatching = true
handler(S.dialog, {name = 'esc', state = 'pressed'})
assert(closes == 1)
dispatching = false; fire(); assert(closes == 2)

setup('dir')
dispatching = true; binding.invoke(false); assert(closes == 2)
dispatching = false; fire(); assert(closes == 3)

setup('file')
dispatching = true
handler(S.dialog, {name = 'return', state = 'pressed', repeated = true})
assert(next(timers) == nil)
handler(S.dialog, {name = 'return', state = 'pressed', repeated = false})
assert(loads == 1)
dispatching = false; fire(); assert(loads == 2)

setup('file'); binding.invoke(false)
release()
assert(next(timers) == nil and S.pending_action == nil and S.dialog == nil)
assert(loads == 2, 'pending load survived document release')

setup('file'); binding.invoke(false)
S.dialog.visible = false -- user closes the window before the timer fires
fire(); assert(loads == 2, 'loaded from externally closed dialog')
print('PASS: deferred load/close, duplicate and repeat guards, frozen selection, Return/Esc, document release, stale dialog')

setup('file')
for _, key in ipairs({
  {name = '<', modifiers = '', state = 'pressed'},
  {name = '>', modifiers = 'shift', state = 'pressed'},
  {name = '<', modifiers = 'shift', state = 'pressed'},
  {name = 'capslock', modifiers = 'command', state = 'pressed'},
  {name = 'capslock', modifiers = 'command', state = 'released'},
  {name = 'q', modifiers = 'command', state = 'pressed'},
}) do assert(handler(S.dialog, key) == key, 'shortcut swallowed: ' .. key.name) end
dispatching = true
local key = {name = 'capslock', modifiers = 'command', state = 'pressed'}
assert(handler(S.dialog, key) == key)
binding.invoke(false) -- host dispatches the forwarded global binding
assert(loads == 2 and S.dialog.visible)
dispatching = false; fire(); assert(loads == 3)

os.platform = function() return 'MACINTOSH' end
PakettiLoadableExtensions = function() return {'*.wav'} end
local names = {'b.wav', 'a.wav'}
os.filenames = function(path) assert(path == '/folder'); return names end
local paths = {}
sample.sample_buffer.load_from = function(_, path)
  assert(not dispatching); paths[#paths + 1] = path; return true
end
setup('dir'); S.entries[1].path = '/folder'; S.entries[1].name = 'folder'
dispatching = true
handler(S.dialog, {name = 'return', modifiers = 'shift', state = 'pressed'})
assert(#paths == 0 and S.dialog.visible)
dispatching = false; fire()
assert(#song.instruments == 2 and S.dialog == nil)
assert(paths[1] == '/folder/a.wav' and paths[2] == '/folder/b.wav')
setup('dir'); S.entries[1].path = '/folder'; names = {}
handler(S.dialog, {name = 'return', modifiers = 'shift', state = 'pressed'})
fire(); assert(S.dialog.visible and #paths == 2, 'empty folder should stay open')
print('PASS: octave/modified-key forwarding, Cmd-CapsLock confirmation, sorted folder load, empty folder')
