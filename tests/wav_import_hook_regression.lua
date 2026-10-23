-- REPORT-CARD >> features/wav-import-destination.feature
-- Run: luajit tests/wav_import_hook_regression.lua
local f = assert(io.open("PakettiDebug.lua", "rb"))
local source = f:read("*a"); f:close()
local a = assert(source:find("local function paketti_wav_basename", 1, true))
local b = assert(source:find("--- Register the hook", a, true))
local hook_source = source:sub(a, b - 1)
preferences = {pakettiWavImportHook = {value = true}}
local function instrument()
  local inst = {samples = {}, name = "", phrases = {}, sample_device_chains = {},
    plugin_properties = {plugin_loaded = false}, midi_output_properties = {device_name = ""}}
  function inst:insert_sample_at(i)
    local buffer = {has_sample_data = false, number_of_frames = 1000}
    function buffer:load_from(path) self.has_sample_data = true; self.path = path; return true end
    table.insert(self.samples, i, {sample_buffer = buffer, sample_mapping = {}, slice_markers = {},
      insert_slice_marker = function(self, pos) table.insert(self.slice_markers, pos) end,
      delete_slice_marker = function(self, pos) for n, v in ipairs(self.slice_markers) do if v == pos then table.remove(self.slice_markers, n); break end end end})
  end
  function inst:delete_sample_at(i) table.remove(self.samples, i) end
  inst:insert_sample_at(1)
  return inst
end
local song = {instruments = {instrument(), instrument()}, selected_instrument_index = 1}
local idle
local window = {sample_record_dialog_is_visible = false}
renoise = {tool = function() return {app_idle_observable = {add_notifier = function(_, fn) idle = fn end}} end, song = function() return song end, app = function() return {window = window, show_status = function() end} end}
local function select(i) song.selected_instrument_index = i; song.selected_instrument = song.instruments[i] end
safeInsertInstrumentAt = function(_, i)
  local inst = instrument(); table.insert(song.instruments, i, inst)
  song.selected_instrument = inst
  return true
end
local templates, restores = 0, 0
pakettiPreferencesDefaultInstrumentLoader = function() templates = templates + 1 end
PakettiTemporarilyDisableNewSampleMonitoring = function() return "monitor" end
PakettiRestoreNewSampleMonitoring = function(v) assert(v == "monitor"); restores = restores + 1 end
local preamble = assert(source:find("local paketti_wav_existing = {}", 1, true))
local ending = assert(source:find("local function paketti_wav_basename", preamble, true))
assert(loadstring(source:sub(preamble, ending - 1) .. hook_source))()
-- In-flight recorder callbacks must do nothing, with either preference state.
local real_song = renoise.song
window.sample_record_dialog_is_visible = true
renoise.song = function() error("recorder bypass must not access song") end
for _, enabled in ipairs({true, false}) do
  preferences.pakettiWavImportHook.value = enabled
  assert(PakettiWavImportHookInvoke("/tmp/TempSampleRef1.wav") == false)
end
assert(templates == 0 and restores == 0)
renoise.song = real_song
window.sample_record_dialog_is_visible = false
preferences.pakettiWavImportHook.value = true
-- Renoise supplies eight selected destinations after two existing instruments.
for i = 1, 8 do song.instruments[#song.instruments + 1] = instrument() end
for i = 1, 8 do
  select(i + 2)
  assert(PakettiWavImportHookInvoke("/tmp/drop" .. i .. ".wav"))
end
assert(#song.instruments == 10, "eight files must not allocate eight EXTRA instruments")
for i = 1, 8 do
  local inst = song.instruments[i + 2]
  assert(inst.name == "drop" .. i, "load into Renoise-selected destination")
  assert(inst.samples[1].sample_buffer.path == "/tmp/drop" .. i .. ".wav")
  assert(inst.samples[1].sample_mapping.note_range[2] == 119)
end
-- Simulate Renoise's post-callback drop edits: placeholders in earlier
-- destinations and a one-note mapping in the final destination.
for i = 3, 9 do song.instruments[i]:insert_sample_at(2) end
song.instruments[10].samples[1].sample_mapping.note_range = {0, 0}
song.instruments[10].samples[1].sample_mapping.base_note = 0
select(1) -- finalization must use captured objects, not current selection
idle()
for i = 3, 10 do
  local inst = song.instruments[i]
  assert(#inst.samples == 1, "post-drop empty placeholder remains at " .. i)
  assert(inst.samples[1].sample_mapping.base_note == 48, "post-drop base note")
  assert(inst.samples[1].sample_mapping.note_range[2] == 119, "post-drop chromatic mapping")
end
assert(not song.instruments[1].samples[1].sample_buffer.has_sample_data)
assert(not song.instruments[2].samples[1].sample_buffer.has_sample_data)
assert(templates == 8 and restores == 8)
preferences.pakettiWavImportHook.value = false
select(3)
assert(PakettiWavImportHookInvoke("plain.wav"))
assert(#song.instruments == 10 and templates == 8)
-- A drop on an existing occupied or intentionally empty slot must append.
preferences.pakettiWavImportHook.value = true
idle()
select(1)
assert(PakettiWavImportHookInvoke("added.wav"))
assert(#song.instruments == 11, "preserve pre-existing empty slot")
assert(not song.instruments[1].samples[1].sample_buffer.has_sample_data)
-- Deferred cleanup preserves other samples with audio and leaves selection alone.
local added = song.selected_instrument
added:insert_sample_at(2)
added.samples[2].sample_buffer:load_from("other-audio.wav")
added:insert_sample_at(3)
select(1)
idle()
assert(#added.samples == 2 and added.samples[2].sample_buffer.path == "other-audio.wav")
assert(song.selected_instrument_index == 1 and song.selected_instrument == song.instruments[1])
idle() -- a consumed queue must be harmless
print("PASS: additive batch, post-drop placeholders/mapping, other audio and selection preserved")

-- Register every extension even when WAV is already registered.
local tool, registered = {app_idle_observable = {add_notifier = function() end}}, {wav = true}
function tool:remove_file_import_hook(_, exts) registered[exts[1]] = nil end
function tool:has_file_import_hook(category, exts) assert(category == "sample"); return registered[exts[1]] end
function tool:add_file_import_hook(hook) registered[hook.extensions[1]] = hook end
renoise.tool = function() return tool end
local register_start = assert(source:find("function PakettiWavImportHookRegister()", 1, true))
local register_end = assert(source:find("--- Menu/keybinding toggle", register_start, true))
assert(loadstring("local paketti_wav_hook_registered = false; local paketti_wav_owned_hooks = {}\n" .. source:sub(register_start, register_end - 1)))()
assert(PakettiWavImportHookRegister())
for _, ext in ipairs({"wav", "aiff", "aif", "flac", "mp3"}) do assert(registered[ext], ext) end
window.sample_record_dialog_is_visible = true
PakettiWavImportHookSync()
for _, ext in ipairs({"aiff", "aif", "flac", "mp3"}) do assert(not registered[ext]) end
assert(registered.wav == true, "do not remove another owner's registration")
assert(PakettiWavImportHookRegister())
assert(not registered.aiff, "must not register while recorder visible")
window.sample_record_dialog_is_visible = false
PakettiWavImportHookSync()
assert(registered.aiff, "restore imports when recorder hidden")
preferences.pakettiWavImportHook.value = false
PakettiWavImportHookSync()
assert(not registered.aiff)
preferences.pakettiWavImportHook.value = true
PakettiWavImportHookSync()
print("PASS: recorder visibility removes owned hooks and hiding restores them")
-- Parse real RIFF cue bytes; do not create a sidecar next to the source.
local cf = assert(io.open("PakettiWavCueExtract.lua", "rb"))
local cue_source = cf:read("*a"); cf:close()
local cue_end = assert(cue_source:find("function PakettiWavCueSamplesToMSF", 1, true))
assert(loadstring(cue_source:sub(1, cue_end - 1)))()
local real_parse, parses = PakettiWavCueParseWavCues, 0
PakettiWavCueParseWavCues = function(path) parses = parses + 1; return real_parse(path) end
local function u32(v) return string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256) end
local cue_data = u32(5)
for i, offset in ipairs({0, 100, 100, 999, 1000}) do
  cue_data = cue_data .. u32(i) .. u32(offset) .. "data" .. u32(0) .. u32(0) .. u32(offset)
end
local fmt = string.char(1,0,1,0) .. u32(44100) .. u32(88200) .. string.char(2,0,16,0)
local body = "WAVEfmt " .. u32(#fmt) .. fmt .. "data" .. u32(2000) .. string.rep("\0",2000) .. "cue " .. u32(#cue_data) .. cue_data
local path = os.tmpname() .. ".WAV"
local wf = assert(io.open(path,"wb")); wf:write("RIFF" .. u32(#body) .. body); wf:close()
select(1)
assert(PakettiWavImportHookInvoke(path))
local sliced = song.selected_instrument.samples[1]
idle()
assert(#sliced.slice_markers == 3)
assert(sliced.slice_markers[1] == 1 and sliced.slice_markers[2] == 101 and sliced.slice_markers[3] == 1000)
assert(parses == 1)
for _, ext in ipairs({"aiff", "aif", "flac", "mp3"}) do
  select(1)
  assert(registered[ext].invoke("/tmp/mixed." .. ext))
  local imported = song.selected_instrument
  imported:insert_sample_at(2)
  idle()
  assert(#imported.samples == 1 and imported.samples[1].sample_mapping.note_range[2] == 119)
end
assert(parses == 1, "only WAV should invoke the cue parser")
local sidecar = io.open(path:gsub("%.WAV$", ".cue"), "rb")
assert(not sidecar, "unexpected cue sidecar")
os.remove(path)
print("PASS: all five extensions and real embedded WAV cue offsets, deduplication and bounds")
