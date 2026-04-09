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
-- 1. AudioDevice / PluginInfo  short_name  (API 6.1+)
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
--     We polyfill it so code compiles — curves degrade to lines on 3.1.1.
------------------------------------------------------------------------

if not renoise.PatternTrackAutomation.PLAYMODE_CURVES then
  renoise.PatternTrackAutomation.PLAYMODE_CURVES = renoise.PatternTrackAutomation.PLAYMODE_LINES
end

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
-- 7. Safe trigger_pattern_line() wrapper  (API 6.2+)
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
