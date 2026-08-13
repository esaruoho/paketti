------------------------------------------------------------------------
-- PakettiCompat.lua
-- Centralised API-version compatibility layer for Paketti.
-- Loaded FIRST by main.lua so every other module can use these globals.
--
-- Renoise API versions vs Renoise releases:
--   API 4   = Renoise 2.8.x
--   API 5   = Renoise 3.0.x / 3.1.x
--   API 6   = Renoise 3.2.x
--   API 6.1 = Renoise 3.3.x
--   API 6.2 = Renoise 3.4+ / 3.5.x
--
-- API 5 added: phrases, sample_modulation_sets, sample_device_chains,
--   MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION,
--   MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR,
--   MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS
--
-- API 4 has: basic samples, keyzones, pattern editor, ViewBuilder,
--   track DSP, automation (no scaling), MIDI, OSC, describe_undo,
--   sample.oneshot, beat_sync_enabled/lines (no mode), and more.
------------------------------------------------------------------------

PAKETTI_API = renoise.API_VERSION  -- cache once; used by every helper

------------------------------------------------------------------------
-- 0. Safe ApplicationWindow constants  (API 4 compatibility)
--    Three middle-frame constants were added in API 5 (Renoise 3.0).
--    On API 4 we define them as nil so code that checks them won't crash.
------------------------------------------------------------------------

if PAKETTI_API < 5 then
  -- These constants don't exist in API 4 — define safe fallbacks.
  -- Code that uses these globals MUST check for nil before calling
  -- renoise.app().window.active_middle_frame = <constant>.
  sampleModulation = nil
  phraseEditor     = nil
  phrase           = nil
  sampleFX         = nil
else
  -- API 5+: constants exist natively — assigned in main.lua after this file loads
end

------------------------------------------------------------------------
-- 1. V2-only device chain / preset blacklist  (API 6.1+ / Renoise 3.3+)
--    These XRNT/XRDP files contain DigitalFilterDevice or Distortion2Device
--    which do not exist before API 6.1.  Shared by PakettiDeviceChains,
--    Paketti0G01_Loader (Preset++ default & file picker), and
--    PakettiPresetPlusPlus (channelstrip loader).
------------------------------------------------------------------------

PAKETTI_V2_ONLY_DEVICE_CHAINS = {
  ["ClippyClip.xrdp"] = true,
  ["ClippyClip_.xrdp"] = true,
  ["ClippyClip.xrnt"] = true,
  ["hipass_lopass_dcoffset.xrnt"] = true,
  ["Low - High Cut (flat) (NPC1).xrdp"] = true,
  ["Low - High Cut (halfsteep) (NPC1).xrdp"] = true,
  ["Low - High Cut (steep) (NPC1).xrdp"] = true,
}

------------------------------------------------------------------------
-- 2. AudioDevice / PluginInfo  short_name  (API 6.1+)
------------------------------------------------------------------------

-- Safe accessor for AudioDevice.short_name (device instances on a track)
function pakettiSafeDeviceShortName(device)
  if PAKETTI_API >= 6.1 and device.short_name then
    return device.short_name
  elseif device.display_name and device.display_name ~= "" then
    return device.display_name
  else
    return device.name or "Unknown"
  end
end

-- Safe accessor for AudioDeviceInfo / PluginInfo .short_name (info structs
-- from available_device_infos / available_plugin_infos)
function pakettiSafeInfoShortName(info)
  if PAKETTI_API >= 6.1 and info.short_name then
    return info.short_name
  elseif info.name and info.name ~= "" then
    return info.name
  elseif info.path then
    return info.path:match("([^/\\]+)$") or "Unknown"
  else
    return "Unknown"
  end
end

------------------------------------------------------------------------
-- 2. beat_sync_mode  (API 6+)
------------------------------------------------------------------------

-- Safe copy of beat_sync_mode from one sample to another
function pakettiSafeCopyBeatSyncMode(dst_sample, src_sample)
  if PAKETTI_API >= 6 then
    dst_sample.beat_sync_mode = src_sample.beat_sync_mode
  end
end

-- Safe setter for beat_sync_mode
function pakettiSafeSetBeatSyncMode(sample, mode)
  if PAKETTI_API >= 6 then
    sample.beat_sync_mode = mode
  end
end

-- Safe getter for beat_sync_mode (returns nil on API < 6)
function pakettiSafeGetBeatSyncMode(sample)
  if PAKETTI_API >= 6 then
    return sample.beat_sync_mode
  end
  return nil
end

------------------------------------------------------------------------
-- 2b. PLAYMODE_CURVES constant  (API 6+)
--     On API 5 (Renoise 3.1.1) only PLAYMODE_POINTS (1) and
--     PLAYMODE_LINES (2) exist.  PLAYMODE_CURVES (3) was added in API 6.
--     We use a global constant so code compiles on all versions.
--     On 3.1.1, curves degrade gracefully to lines.
------------------------------------------------------------------------

-- Hardcoded values — do NOT read from renoise.PatternTrackAutomation.*
-- because those class statics don't exist in older API versions and
-- even attempting to read them causes a fatal std::logic_error.
PAKETTI_PLAYMODE_POINTS = 1  -- exists in all versions
PAKETTI_PLAYMODE_LINES  = 2  -- exists in all versions
PAKETTI_PLAYMODE_CURVES = (PAKETTI_API >= 6) and 3 or 2
                              -- API 6+: real curves (3)
                              -- API 5:  degrades to lines (2)

PAKETTI_HAS_CURVES = (PAKETTI_API >= 6) -- true only when real curves exist

------------------------------------------------------------------------
-- 3. Automation point .scaling  (API 6+)
------------------------------------------------------------------------

-- Works for both Renoise userdata automation points and plain Lua tables.
function pakettiSafeGetScaling(point)
  if type(point) == "table" then
    return point.scaling or 0
  end
  if PAKETTI_API >= 6 then
    return point.scaling or 0
  end
  return 0
end

-- Safe wrapper for automation:add_point_at() — on API 5 only passes
-- (time, value) since the scaling parameter doesn't exist.
function pakettiSafeAddPointAt(automation, time, value, scaling)
  if PAKETTI_API >= 6 then
    automation:add_point_at(time, value, scaling or 0)
  else
    automation:add_point_at(time, value)
  end
end

------------------------------------------------------------------------
-- 4. ViewBuilder .style property  (API 6+)
------------------------------------------------------------------------

-- Safe setter for view.style — no-op on API < 6.
function pakettiSetViewStyle(view, style_value)
  if PAKETTI_API >= 6 then
    view.style = style_value
  end
end

------------------------------------------------------------------------
-- 5. ViewBuilder .steps property  (API 6+)
--    Use in widget constructors:
--      vb:valuebox{ ..., steps = pakettiSteps(1, 10), ... }
--    Returns the table on API >= 6, or nil on older versions.
------------------------------------------------------------------------

function pakettiSteps(...)
  if PAKETTI_API >= 6 then
    return {...}
  end
  return nil
end

------------------------------------------------------------------------
-- 6. Feature-availability flags
--    Use these instead of scattering "renoise.API_VERSION >= X" everywhere.
------------------------------------------------------------------------

-- API 5+ (Renoise 3.0+): Instrument internals
PAKETTI_HAS_PHRASES_BASIC    = (PAKETTI_API >= 5)    -- .phrases, insert_phrase_at, phrase_playback_mode
PAKETTI_HAS_MODULATION_SETS  = (PAKETTI_API >= 5)    -- .sample_modulation_sets
PAKETTI_HAS_DEVICE_CHAINS    = (PAKETTI_API >= 5)    -- .sample_device_chains
PAKETTI_HAS_SLICING          = (PAKETTI_API >= 5)    -- .slice_markers, insert_slice_marker
PAKETTI_HAS_SAMPLE_FX_FRAME  = (PAKETTI_API >= 5)    -- MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS
PAKETTI_HAS_PHRASE_FRAME     = (PAKETTI_API >= 5)    -- MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
PAKETTI_HAS_MOD_FRAME        = (PAKETTI_API >= 5)    -- MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION

-- API 6+ (Renoise 3.2+): Refinements
PAKETTI_HAS_BEAT_SYNC_MODE   = (PAKETTI_API >= 6)    -- beat_sync_mode
PAKETTI_HAS_STYLE            = (PAKETTI_API >= 6)    -- view .style
PAKETTI_HAS_STEPS            = (PAKETTI_API >= 6)    -- slider/valuebox .steps
PAKETTI_HAS_SCALING          = (PAKETTI_API >= 6)    -- automation .scaling

-- API 6.1+ (Renoise 3.3+)
PAKETTI_HAS_SHORT_NAME       = (PAKETTI_API >= 6.1)  -- device .short_name

-- API 6.2+ (Renoise 3.5+)
PAKETTI_HAS_CANVAS           = (PAKETTI_API >= 6.2)  -- Canvas API
PAKETTI_HAS_PHRASES          = (PAKETTI_API >= 6.2)  -- Advanced phrase features (phrase.script)
PAKETTI_HAS_TRIGGER_LINE     = (PAKETTI_API >= 6.2)  -- trigger_pattern_line()

------------------------------------------------------------------------
-- 7. Version-aware XRNI preset path resolver
--    Renoise 3.1 (API 5) cannot load doc_version 33/34 instruments.
--    We ship stripped-down v31 copies in Presets/v31/ for those users.
--    On API 6+ we use the normal Presets/ files (v33/v34).
------------------------------------------------------------------------

-- Given a bare XRNI filename (e.g. "12st_Pitchbend.xrni"), returns the
-- full absolute path to the version-appropriate copy.
-- If a v31 copy doesn't exist, falls back to the normal Presets/ path.
function pakettiGetVersionedPresetPath(filename)
  local sep = package.config:sub(1, 1)
  local bundle = renoise.tool().bundle_path

  if PAKETTI_API < 6 then
    -- Renoise 3.0/3.1: try the v31 subdirectory first
    local v31_path = bundle .. "Presets" .. sep .. "v31" .. sep .. filename
    local f = io.open(v31_path, "r")
    if f then
      f:close()
      return v31_path
    end
  end

  -- API 6+ or v31 file missing: use normal Presets/ path
  return bundle .. "Presets" .. sep .. filename
end

-- Convenience: given a relative preset path like "Presets/SomeFile.xrni",
-- extracts the filename and routes through the versioned resolver.
function pakettiResolvePresetPath(relative_path)
  local filename = relative_path:match("[^/\\]+$")
  if filename then
    return pakettiGetVersionedPresetPath(filename)
  end
  return renoise.tool().bundle_path .. relative_path
end

------------------------------------------------------------------------
-- 7b. Safe trigger_pattern_line() wrapper  (API 6.2+)
------------------------------------------------------------------------

function pakettiSafeTriggerPatternLine(track_index, line_index)
  if PAKETTI_HAS_TRIGGER_LINE then
    renoise.song():trigger_pattern_line(track_index, line_index)
    return true
  end
  return false
end

------------------------------------------------------------------------
-- 8. Vertical separator helper  (style-aware)
--    Creates "|" text that uses "strong" style on API 6+, plain on API 5/4.
------------------------------------------------------------------------

function pakettiVertSep(vb)
  if PAKETTI_HAS_STYLE then
    return vb:text{text = "|", font = "bold", style = "strong", width = 8}
  else
    return vb:text{text = "|", font = "bold", width = 8}
  end
end

------------------------------------------------------------------------
-- 9. Safe accessors for API 5+ instrument internals
--    On API 4 these return empty tables / nil / do nothing.
------------------------------------------------------------------------

-- Safe getter for instrument.phrases (returns empty table on API 4)
function pakettiSafeGetPhrases(instrument)
  if PAKETTI_HAS_PHRASES_BASIC then
    return instrument.phrases
  end
  return {}
end

-- Safe getter for instrument.sample_modulation_sets (returns empty table on API 4)
function pakettiSafeGetModulationSets(instrument)
  if PAKETTI_HAS_MODULATION_SETS then
    return instrument.sample_modulation_sets
  end
  return {}
end

-- Safe getter for instrument.sample_device_chains (returns empty table on API 4)
function pakettiSafeGetDeviceChains(instrument)
  if PAKETTI_HAS_DEVICE_CHAINS then
    return instrument.sample_device_chains
  end
  return {}
end

-- Safe frame switcher — switches to the requested middle frame only if available.
-- Returns true if switch succeeded, false if the frame doesn't exist on this API.
function pakettiSafeSetMiddleFrame(frame_constant)
  if frame_constant == nil then
    return false
  end
  renoise.app().window.active_middle_frame = frame_constant
  return true
end

------------------------------------------------------------------------
-- 10. Sample Recorder capability layer  (Renoise 3.5 / API 6.2+)
--
--   Renoise 3.5 exposes an explicit Sample Recorder surface:
--     transport:start_sample_recording()       -- replaces the DEPRECATED
--     transport:stop_sample_recording()        --   start_stop_sample_recording()
--     transport:cancel_sample_recording()      -- stop AND discard the take
--     transport.sample_recording               -- READ-ONLY, true while recording
--     transport.sample_recording_sync_enabled  -- read/write pattern quantize
--
--   IMPORTANT: renoise.API_VERSION cannot separate 3.4 from 3.5 — both report
--   6.2 (see the version table at the top of this file). So we do NOT gate on
--   the version number alone: we probe the live transport once and cache the
--   answer. Indexing a property that does not exist on older Renoise THROWS,
--   so every probe is wrapped in pcall.
--
--   Every helper below degrades gracefully: on pre-3.5 the explicit calls fall
--   back to the deprecated toggle, the state query returns nil ("unknown"),
--   and the sync setter returns false without touching anything.
------------------------------------------------------------------------

-- Declared here so the cache read below never touches an undeclared global
-- (Renoise strict-globals throws on reading one, which aborts the whole load).
PakettiSampleRecorderCapsCache = nil

-- Shadow "are we recording" flag for pre-3.5, where Renoise cannot tell us.
-- Maintained by the start/stop/cancel helpers below. It is only consulted when
-- the real transport.sample_recording property is unavailable.
--
-- Why this matters: the pre-3.5 fallback for "stop" is the DEPRECATED
-- start_stop_sample_recording() TOGGLE. If a caller does
--   "if recording then stop() end"
-- and we answered "unknown", a blind stop on 3.4 would TOGGLE — i.e. it would
-- START a recording that nobody asked for. The shadow flag means the query
-- always returns a usable boolean on every Renoise version.
PakettiSampleRecordingShadow = false

-- Returns a table: {explicit=bool, cancel=bool, state=bool, sync=bool}
-- Result is cached once a song exists; before that we probe fresh each call.
function pakettiSampleRecorderCaps()
  if PakettiSampleRecorderCapsCache ~= nil then
    return PakettiSampleRecorderCapsCache
  end

  local caps = {explicit = false, cancel = false, state = false, sync = false}

  local song = renoise.song()
  if song == nil then
    -- No song yet (tool boot). Report "nothing available" without caching,
    -- so the first real call after a song loads probes for real.
    return caps
  end

  if PAKETTI_API < 6.2 then
    PakettiSampleRecorderCapsCache = caps
    return caps
  end

  local t = song.transport

  local function has_fn(name)
    local ok, v = pcall(function() return t[name] end)
    return ok and type(v) == "function"
  end
  local function has_prop(name)
    local ok = pcall(function() return t[name] end)
    return ok
  end

  caps.explicit = has_fn("start_sample_recording") and has_fn("stop_sample_recording")
  caps.cancel   = has_fn("cancel_sample_recording")
  caps.state    = has_prop("sample_recording")
  caps.sync     = has_prop("sample_recording_sync_enabled")

  PakettiSampleRecorderCapsCache = caps
  return caps
end

-- Start sample recording. Uses the explicit 3.5 call when present, otherwise
-- the deprecated toggle. The Sample Recorder dialog must already be visible.
function pakettiSampleRecordingStart()
  local t = renoise.song().transport
  if pakettiSampleRecorderCaps().explicit then
    t:start_sample_recording()
  else
    t:start_stop_sample_recording()
  end
  PakettiSampleRecordingShadow = true
end

-- Stop sample recording and KEEP the take.
function pakettiSampleRecordingStop()
  local t = renoise.song().transport
  if pakettiSampleRecorderCaps().explicit then
    t:stop_sample_recording()
  else
    t:start_stop_sample_recording()
  end
  PakettiSampleRecordingShadow = false
end

-- Stop sample recording and DISCARD the take.
-- Pre-3.5 there is no discard, so we stop normally and return false to let the
-- caller know the take was kept and may need cleaning up by hand.
function pakettiSampleRecordingCancel()
  local t = renoise.song().transport
  if pakettiSampleRecorderCaps().cancel then
    t:cancel_sample_recording()
    PakettiSampleRecordingShadow = false
    return true
  end
  pakettiSampleRecordingStop()
  return false
end

-- "Is the Sample Recorder actually recording right now?"
-- ALWAYS returns a boolean, on every supported Renoise version:
--   3.5+  : the authoritative read-only transport.sample_recording property
--   <3.5  : our shadow flag, kept in sync by the helpers above
-- If the recorder dialog is closed, nothing can be recording.
--
-- IMPORTANT — do NOT write the property back into the shadow flag.
-- Verified on Renoise 3.5.4: transport.sample_recording LAGS behind
-- start_sample_recording() — it still reads false for a moment after the call,
-- then flips true once the recorder has actually armed. Copying that transient
-- false into the shadow destroys our record of what we asked for, which is the
-- one thing the shadow exists to remember on pre-3.5. The shadow tracks INTENT
-- (what Paketti asked for); the property reports REALITY (what Renoise is doing).
-- Keep them separate.
function pakettiSampleRecordingIsActive()
  if not renoise.app().window.sample_record_dialog_is_visible then
    PakettiSampleRecordingShadow = false
    return false
  end
  if pakettiSampleRecorderCaps().state then
    return renoise.song().transport.sample_recording
  end
  return PakettiSampleRecordingShadow
end

-- "Did Paketti ask for a recording that it has not stopped yet?"
-- This is the INTENT flag, and unlike pakettiSampleRecordingIsActive() it is
-- true immediately after a start, with no arming lag. Use this when you need to
-- decide whether to issue a stop; use IsActive() when you need to know whether
-- audio is genuinely being captured right now.
function pakettiSampleRecordingWasStarted()
  if not renoise.app().window.sample_record_dialog_is_visible then
    PakettiSampleRecordingShadow = false
    return false
  end
  return PakettiSampleRecordingShadow
end

-- true when the "is it recording" answer comes from Renoise itself (3.5+)
-- rather than from our shadow flag. Use when a caller wants to know how much
-- to trust the answer; most callers should just use pakettiSampleRecordingIsActive().
function pakettiSampleRecordingStateIsAuthoritative()
  return pakettiSampleRecorderCaps().state
end

-- Current pattern-sync (recording quantize) setting, or nil when unavailable.
function pakettiSampleRecordingSyncGet()
  if not pakettiSampleRecorderCaps().sync then
    return nil
  end
  return renoise.song().transport.sample_recording_sync_enabled
end

-- Set pattern sync. Returns true if it was actually applied, false on pre-3.5.
function pakettiSampleRecordingSyncSet(enabled)
  if not pakettiSampleRecorderCaps().sync then
    return false
  end
  renoise.song().transport.sample_recording_sync_enabled = enabled
  return true
end

------------------------------------------------------------------------
-- Done.  Print confirmation if debug output is enabled.
------------------------------------------------------------------------
if PakettiTimedRequireDebug then
  print(string.format(
    "PakettiCompat loaded — API %.1f  phrases_basic=%s  mod_sets=%s  dev_chains=%s  canvas=%s",
    PAKETTI_API,
    tostring(PAKETTI_HAS_PHRASES_BASIC),
    tostring(PAKETTI_HAS_MODULATION_SETS),
    tostring(PAKETTI_HAS_DEVICE_CHAINS),
    tostring(PAKETTI_HAS_CANVAS)))
end
