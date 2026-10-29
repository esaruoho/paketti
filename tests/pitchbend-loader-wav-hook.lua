-- tests/pitchbend-loader-wav-hook.lua
-- Unit test: Verifies that Pitchbend sample loaders and duplicators work cleanly
-- without interference from the WAV import hook.
-- Run with: luajit tests/pitchbend-loader-wav-hook.lua

local function extract(path, first, last)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a"); f:close()
  local a = assert(s:find(first, 1, true), "Could not find start: " .. tostring(first))
  local b = assert(s:find(last, a, true), "Could not find end: " .. tostring(last))
  return s:sub(a, b - 1)
end

-- Track hook lifecycle calls
local hook_unregistered_count = 0
local hook_sync_count = 0

PakettiWavImportHookUnregister = function()
  hook_unregistered_count = hook_unregistered_count + 1
end

PakettiWavImportHookSync = function()
  hook_sync_count = hook_sync_count + 1
end

PakettiWavImportHookBypass = false

-- Mock environment
preferences = {
  pakettiWavImportHook = { value = true },
  pakettiDefaultXRNI = { value = "" },
  pakettiDefaultDrumkitXRNI = { value = "" },
  pakettiLoaderInterpolation = { value = 1 },
  pakettiLoaderOverSampling = { value = false },
  pakettiLoaderAutofade = { value = false },
  pakettiLoaderAutoseek = { value = false },
  pakettiLoaderLoopMode = { value = 1 },
  pakettiLoaderOneshot = { value = false },
  pakettiLoaderNNA = { value = 1 },
  pakettiLoaderLoopExit = { value = false },
  pakettiLoaderNormalizeSamples = { value = false },
  pakettiLoaderMoveSilenceToEnd = { value = false },
  pakettiLoaderDontCreateAutomationDevice = { value = true },
  pakettiSampleRangeDeviceLoaderEnabled = { value = false },
}
setmetatable(preferences, {
  __index = function(t, k)
    t[k] = { value = false }
    return t[k]
  end
})

local function make_sample(name)
  local smp = {
    name = name or "",
    transpose = 0,
    fine_tune = 0,
    volume = 1.0,
    panning = 0.5,
    loop_mode = 1,
    loop_start = 1,
    loop_end = 100,
    loop_release = false,
    interpolation_mode = 1,
    oversample_enabled = false,
    autoseek = false,
    autofade = false,
    new_note_action = 1,
    mute_group = 0,
    oneshot = false,
    device_chain_index = 1,
    modulation_set_index = 1,
    sample_mapping = {
      base_note = 48,
      note_range = {0, 119},
      velocity_range = {0, 127},
      map_key_to_pitch = true,
      map_velocity_to_volume = true,
    },
    slice_markers = {},
    sample_buffer = {
      has_sample_data = true,
      sample_rate = 44100,
      bit_depth = 16,
      number_of_channels = 2,
      number_of_frames = 1000,
      load_from = function(self, path) self.has_sample_data = true; return true end,
      save_as = function(self, path, fmt) return true end,
      create_sample_data = function(self, r, b, c, f)
        self.sample_rate = r; self.bit_depth = b; self.number_of_channels = c; self.number_of_frames = f
        self.has_sample_data = true; return true
      end,
      prepare_sample_data_changes = function() end,
      finalize_sample_data_changes = function() end,
      sample_data = function(self, c, f) return 0.5 end,
      set_sample_data = function(self, c, f, v) end,
    }
  }
  function smp:copy_from(other)
    self.name = other.name
    self.transpose = other.transpose
    self.volume = other.volume
    self.loop_mode = other.loop_mode
    -- Simulate native copy_from populating sample data
    self.sample_buffer.has_sample_data = other.sample_buffer.has_sample_data
    self.sample_buffer.number_of_frames = other.sample_buffer.number_of_frames
  end
  function smp:insert_slice_marker(pos) table.insert(self.slice_markers, pos) end
  function smp:delete_slice_marker(pos)
    for i, v in ipairs(self.slice_markers) do if v == pos then table.remove(self.slice_markers, i); break end end
  end
  return smp
end

local function make_instrument(name)
  local inst = {
    name = name or "",
    samples = {make_sample("Placeholder sample")},
    phrases = {},
    sample_device_chains = {},
    sample_modulation_sets = {{name = "Pitchbend"}},
    plugin_properties = {plugin_loaded = false},
    midi_output_properties = {device_name = ""},
    volume = 1.0,
    transpose = 0,
  }
  function inst:insert_sample_at(i)
    local s = make_sample("Sample " .. i)
    s.sample_buffer.has_sample_data = false
    table.insert(self.samples, i, s)
    return s
  end
  function inst:sample(i) return self.samples[i] end
  function inst:delete_sample_at(i) table.remove(self.samples, i) end
  function inst:copy_from(other)
    self.name = other.name
    self.samples = {}
    for i, s in ipairs(other.samples) do
      local ns = make_sample(s.name)
      ns:copy_from(s)
      table.insert(self.samples, ns)
    end
  end
  return inst
end

local song = {
  instruments = {make_instrument("Init")},
  selected_instrument_index = 1,
  selected_sample_index = 1,
  selected_track = {type = 1, devices = {{}, {}}},
}
song.instrument = function(self, i) return self.instruments[i] end
song.selected_instrument = song.instruments[1]

renoise = {
  tool = function() return {
    add_keybinding = function() end,
    add_midi_mapping = function() end,
  } end,
  song = function() return song end,
  app = function() return {
    window = {active_middle_frame = 1},
    show_status = function() end,
    show_warning = function() end,
    load_instrument = function(self, path)
      local inst = make_instrument("Preset")
      song.instruments[song.selected_instrument_index] = inst
      song.selected_instrument = inst
      return true
    end,
  } end,
  ApplicationWindow = {
    MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR = 1,
    MIDDLE_FRAME_PATTERN_EDITOR = 2,
  }
}

safeInsertInstrumentAt = function(s, i)
  local inst = make_instrument("New")
  table.insert(s.instruments, i, inst)
  return inst
end

PakettiTemporarilyDisableNewSampleMonitoring = function() return true end
PakettiRestoreNewSampleMonitoring = function() end
PakettiApplyLoaderModulationSettings = function() end
PakettiInjectApplyLoaderSettings = function() end
PakettiExpandLoadableFiles = function(files) return files, {}, {} end
PakettiExpandLoadableReport = function() end
PakettiExpandLoadableCleanup = function() end
PakettiLoadableExtensions = function() return {"*.wav"} end
pakettiGetVersionedPresetPath = function(p) return p end
pakettiPreferencesDefaultInstrumentLoader = function()
  renoise.app():load_instrument("")
end
on_sample_count_change = function() end
formatDigits = function(d, n) return tostring(n) end
G01 = function() end
coroutine = { yield = function() end }

-- Load the functions from PakettiSamples.lua
local samples_source = assert(io.open("PakettiSamples.lua", "rb")):read("*a")
local copy_helpers = extract("PakettiSamples.lua", "function PakettiCopySample", "function pakettiPreferencesDefaultInstrumentLoader")
assert(loadstring(copy_helpers))()

local copy_inst_helper = extract("PakettiSamples.lua", "function PakettiCopyInstrument", "function pakettiPreferencesDefaultInstrumentLoader")
assert(loadstring(copy_inst_helper))()

-- 1. TEST: PakettiCopySample protects against hook interference
hook_unregistered_count = 0
hook_sync_count = 0
local src_smp = make_sample("Original")
local dst_smp = make_sample("Copy")
dst_smp.sample_buffer.has_sample_data = false

assert(PakettiCopySample(src_smp, dst_smp) == true)
assert(hook_unregistered_count == 1, "PakettiCopySample must unregister WAV hook")
assert(hook_sync_count == 1, "PakettiCopySample must sync/restore WAV hook")
assert(PakettiWavImportHookBypass == false, "PakettiCopySample must reset bypass flag")
assert(dst_smp.name == "Original", "Sample name must match")
assert(dst_smp.sample_buffer.has_sample_data == true, "Sample buffer data must be present")
print("PASS: PakettiCopySample unregisters hook, preserves buffer & restores state")

-- 2. TEST: PakettiCopyInstrument protects against hook interference
hook_unregistered_count = 0
hook_sync_count = 0
local src_inst = make_instrument("SrcInst")
local dst_inst = make_instrument("DstInst")

assert(PakettiCopyInstrument(src_inst, dst_inst) == true)
assert(hook_unregistered_count == 1, "PakettiCopyInstrument must unregister WAV hook")
assert(hook_sync_count == 1, "PakettiCopyInstrument must sync/restore WAV hook")
assert(PakettiWavImportHookBypass == false, "PakettiCopyInstrument must reset bypass flag")
assert(#dst_inst.samples == #src_inst.samples, "Sample counts must match")
assert(dst_inst.samples[1].sample_buffer.has_sample_data == true, "Copied sample buffer must have data")
print("PASS: PakettiCopyInstrument unregisters hook, clones instrument & restores state")

-- 3. TEST: pitchBendDrumkitLoader protects against hook interference
local drumkit_source = extract("PakettiSamples.lua", "function pitchBendDrumkitLoader", "renoise.tool():add_keybinding{name=\"Global:Paketti:Paketti PitchBend Drumkit Sample Loader\"")
assert(loadstring(drumkit_source))()

hook_unregistered_count = 0
hook_sync_count = 0
song.selected_instrument_index = 1
song.selected_instrument = song.instruments[1]

pitchBendDrumkitLoader({"/samples/kick.wav", "/samples/snare.wav", "/samples/hihat.wav"})
assert(hook_unregistered_count == 1, "pitchBendDrumkitLoader must unregister WAV hook")
assert(hook_sync_count == 1, "pitchBendDrumkitLoader must restore WAV hook on completion")
assert(PakettiWavImportHookBypass == false, "pitchBendDrumkitLoader must reset bypass flag")
print("PASS: pitchBendDrumkitLoader runs cleanly under hook protection")

-- 4. TEST: pitchBendMultipleSampleLoader_process protects against hook interference
pitchbend_loader_progress = {
  current_file_index = 0,
  current_filename = "",
  total_files = 2,
  slicer = { was_cancelled = function() return false end },
  vb = nil,
  dialog = nil,
  temp_files = nil
}

local multi_source = extract("PakettiSamples.lua", "function pitchBendMultipleSampleLoader_process", "renoise.tool():add_keybinding{name=\"Global:Paketti:Paketti PitchBend Multiple Sample Loader\"")
assert(loadstring(multi_source))()

hook_unregistered_count = 0
hook_sync_count = 0

pitchBendMultipleSampleLoader_process({"/samples/lead1.wav", "/samples/lead2.wav"}, false, nil)
assert(hook_unregistered_count == 1, "pitchBendMultipleSampleLoader_process must unregister WAV hook")
assert(hook_sync_count == 1, "pitchBendMultipleSampleLoader_process must restore WAV hook on completion")
assert(PakettiWavImportHookBypass == false, "pitchBendMultipleSampleLoader_process must reset bypass flag")
print("PASS: pitchBendMultipleSampleLoader_process runs cleanly under hook protection")

print("\nALL PITCHBEND LOADER & HOOK TESTS PASSED SUCCESSFULLY!")
