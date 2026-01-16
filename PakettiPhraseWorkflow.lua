-- PakettiPhraseWorkflow.lua
-- Deep Phrase Workflow System for Paketti
-- Provides clip-launcher style phrase management with follow actions, launch modes,
-- phrase groups, banks, templates, and deep integration with Renoise patterns.

--------------------------------------------------------------------------------
-- GLOBAL STATE VARIABLES
--------------------------------------------------------------------------------

-- Phrase Transport State
PakettiPhraseTransportEnabled = false
PakettiPhraseTransportArmedOffset = 0
PakettiPhraseTransportLastPatternPos = 1
PakettiPhraseTransportCurrentSection = 0

-- Phrase Switcher State
PakettiPhraseSwitcherDefaultMode = "trigger"  -- trigger, gate, toggle, oneshot, legato
PakettiPhraseSwitcherDefaultQuant = "beat"    -- line, beat, bar, custom
PakettiPhraseSwitcherCustomQuant = 4          -- Custom quantization in lines
PakettiPhraseSwitcherActiveStates = {}        -- Track which phrases are currently playing

-- PhraseGrid State (Runtime-only, not saved)
PakettiPhraseGridStates = {}      -- State storage
PakettiPhraseGridGroups = {}      -- Mute group definitions
PakettiPhraseGridCurrentState = 0 -- Currently active state
PakettiPhraseGridMaxStates = 32   -- Maximum number of states
PakettiPhraseGridMaxGroups = 8    -- Maximum number of groups

-- Phrase Banks State
PakettiPhraseBanks = {}           -- Bank storage
PakettiPhraseBankCurrent = 1      -- Current bank index
PakettiPhraseBankMaxBanks = 8     -- Maximum banks
PakettiPhraseBankSlotsPerBank = 8 -- Phrases per bank

-- Live Recording State
PakettiPhraseLiveRecordArmed = false
PakettiPhraseLiveRecordActive = false
PakettiPhraseLiveRecordBuffer = {}    -- Recorded triggers
PakettiPhraseLiveRecordStartLine = 0

-- Follow Actions State
PakettiPhraseFollowActionsEnabled = true
PakettiPhraseFollowActionLoopCount = {} -- Track loop counts per state

--------------------------------------------------------------------------------
-- PHRASE VOICE ORCHESTRATION SYSTEM
-- Enables multiple concurrent phrase voices per instrument with phase-locked starts
--------------------------------------------------------------------------------

-- Voice Pool: Tracks all active phrase voices
PakettiPhraseVoicePool = {}

-- Voice Configuration (defaults, will be overridden by preferences on load)
PakettiPhraseVoiceOutputMode = "track"    -- "track" or "column"
PakettiPhraseVoiceMaxVoices = 8           -- Max concurrent voices (track mode default)
PakettiPhraseVoiceMaxColumnsPerTrack = 12 -- Max voices in column mode
PakettiPhraseVoicePhaseLockEnabled = true -- Global phase lock setting
PakettiPhraseVoiceNextVoiceId = 1         -- Auto-increment voice ID
PakettiPhraseVoicePreserveExistingNotes = true  -- Don't overwrite existing pattern data
PakettiPhraseVoiceDebugEnabled = false    -- Enable debug logging
PakettiPhraseVoiceFadeOutEnabled = false  -- Fade out voices on stop
PakettiPhraseVoiceAdditiveMode = false    -- Additive layering mode (don't clear on state recall)
PakettiPhraseVoiceAutoSpawnEnabled = false -- Auto-spawn phrase voice on phrase selection

-- Forward declaration for UI update function (defined later)
-- This allows pool functions to call it safely
function PakettiPhraseVoiceUpdateUI() end

-- Load PhraseVoice preferences (called on tool load and new document)
function PakettiPhraseVoiceLoadPreferences()
  local success, err = pcall(function()
    local prefs = renoise.tool().preferences
    if prefs then
      if prefs.PakettiPhraseVoiceOutputMode then
        PakettiPhraseVoiceOutputMode = prefs.PakettiPhraseVoiceOutputMode.value or "track"
      end
      if prefs.PakettiPhraseVoiceMaxVoices then
        PakettiPhraseVoiceMaxVoices = prefs.PakettiPhraseVoiceMaxVoices.value or 8
      end
      if prefs.PakettiPhraseVoiceMaxColumns then
        PakettiPhraseVoiceMaxColumnsPerTrack = prefs.PakettiPhraseVoiceMaxColumns.value or 12
      end
      if prefs.PakettiPhraseVoicePhaseLockEnabled then
        PakettiPhraseVoicePhaseLockEnabled = prefs.PakettiPhraseVoicePhaseLockEnabled.value
      end
      if prefs.PakettiPhraseVoiceOperationMode then
        PakettiPhraseVoiceOperationMode = prefs.PakettiPhraseVoiceOperationMode.value or "switcher"
      end
      if prefs.PakettiPhraseVoicePreserveExistingNotes then
        PakettiPhraseVoicePreserveExistingNotes = prefs.PakettiPhraseVoicePreserveExistingNotes.value
      end
      if prefs.PakettiPhraseVoiceFadeOutEnabled then
        PakettiPhraseVoiceFadeOutEnabled = prefs.PakettiPhraseVoiceFadeOutEnabled.value
      end
      if prefs.PakettiPhraseVoiceAdditiveMode then
        PakettiPhraseVoiceAdditiveMode = prefs.PakettiPhraseVoiceAdditiveMode.value
      end
      if prefs.PakettiPhraseVoiceDebugEnabled then
        PakettiPhraseVoiceDebugEnabled = prefs.PakettiPhraseVoiceDebugEnabled.value
      end
      if prefs.PakettiPhraseVoiceAutoSpawnEnabled then
        PakettiPhraseVoiceAutoSpawnEnabled = prefs.PakettiPhraseVoiceAutoSpawnEnabled.value
      end
    end
  end)
  if not success then
    -- Preferences not available yet, use defaults
    PakettiPhraseVoiceOutputMode = "track"
    PakettiPhraseVoiceMaxVoices = 8
    PakettiPhraseVoiceMaxColumnsPerTrack = 12
    PakettiPhraseVoicePhaseLockEnabled = true
    PakettiPhraseVoiceOperationMode = "switcher"
    PakettiPhraseVoicePreserveExistingNotes = true
    PakettiPhraseVoiceFadeOutEnabled = false
    PakettiPhraseVoiceAdditiveMode = false
    PakettiPhraseVoiceDebugEnabled = false
    PakettiPhraseVoiceAutoSpawnEnabled = false
  end
end

-- Save PhraseVoice preferences
function PakettiPhraseVoiceSavePreferences()
  local success, err = pcall(function()
    local prefs = renoise.tool().preferences
    if prefs then
      if prefs.PakettiPhraseVoiceOutputMode then
        prefs.PakettiPhraseVoiceOutputMode.value = PakettiPhraseVoiceOutputMode
      end
      if prefs.PakettiPhraseVoiceMaxVoices then
        prefs.PakettiPhraseVoiceMaxVoices.value = PakettiPhraseVoiceMaxVoices
      end
      if prefs.PakettiPhraseVoiceMaxColumns then
        prefs.PakettiPhraseVoiceMaxColumns.value = PakettiPhraseVoiceMaxColumnsPerTrack
      end
      if prefs.PakettiPhraseVoicePhaseLockEnabled then
        prefs.PakettiPhraseVoicePhaseLockEnabled.value = PakettiPhraseVoicePhaseLockEnabled
      end
      if prefs.PakettiPhraseVoiceOperationMode then
        prefs.PakettiPhraseVoiceOperationMode.value = PakettiPhraseVoiceOperationMode
      end
      if prefs.PakettiPhraseVoicePreserveExistingNotes then
        prefs.PakettiPhraseVoicePreserveExistingNotes.value = PakettiPhraseVoicePreserveExistingNotes
      end
      if prefs.PakettiPhraseVoiceFadeOutEnabled then
        prefs.PakettiPhraseVoiceFadeOutEnabled.value = PakettiPhraseVoiceFadeOutEnabled
      end
      if prefs.PakettiPhraseVoiceAdditiveMode then
        prefs.PakettiPhraseVoiceAdditiveMode.value = PakettiPhraseVoiceAdditiveMode
      end
      if prefs.PakettiPhraseVoiceDebugEnabled then
        prefs.PakettiPhraseVoiceDebugEnabled.value = PakettiPhraseVoiceDebugEnabled
      end
      if prefs.PakettiPhraseVoiceAutoSpawnEnabled then
        prefs.PakettiPhraseVoiceAutoSpawnEnabled.value = PakettiPhraseVoiceAutoSpawnEnabled
      end
      prefs:save_as("preferences.xml")
    end
  end)
end

-- Clear voice pool on new document (reset state)
function PakettiPhraseVoiceOnNewDocument()
  PakettiPhraseVoiceDebugLog("New document loaded - resetting voice state")
  
  -- Clear all active voices
  PakettiPhraseVoicePool = {}
  PakettiPhraseVoicePendingQueue = {}
  PakettiPhraseVoiceNextVoiceId = 1
  PakettiPhraseVoiceLastQuantBoundary = 0
  PakettiPhraseVoiceLastPlaybackLine = 0
  
  -- Clear voice track references
  PakettiPhraseVoiceTracks = {}
  
  -- Reset phrase selection state
  PakettiPhraseVoiceLastSelectedPhraseIndex = 0
  PakettiPhraseVoiceSelectionNotifierActive = false
  
  -- Reload preferences
  PakettiPhraseVoiceLoadPreferences()
  
  -- Update UI
  PakettiPhraseVoiceUpdateUI()
end

-- Validate voice pool: remove voices with invalid track/column indices
function PakettiPhraseVoiceValidatePool()
  local song = renoise.song()
  if not song then return end
  
  local valid_voices = {}
  local removed_count = 0
  
  for _, voice in ipairs(PakettiPhraseVoicePool) do
    local valid = true
    
    -- Check track index
    if not voice.track_index or voice.track_index < 1 or voice.track_index > #song.tracks then
      valid = false
      PakettiPhraseVoiceDebugLog(string.format("Removing voice %d: invalid track index %s", 
        voice.voice_id or 0, tostring(voice.track_index)))
    end
    
    -- Check instrument index
    if valid and (not voice.instrument_index or voice.instrument_index < 1 or voice.instrument_index > #song.instruments) then
      valid = false
      PakettiPhraseVoiceDebugLog(string.format("Removing voice %d: invalid instrument index %s", 
        voice.voice_id or 0, tostring(voice.instrument_index)))
    end
    
    -- Check phrase index
    if valid and voice.instrument_index then
      local instrument = song.instruments[voice.instrument_index]
      if instrument and (not voice.phrase_index or voice.phrase_index < 1 or voice.phrase_index > #instrument.phrases) then
        valid = false
        PakettiPhraseVoiceDebugLog(string.format("Removing voice %d: invalid phrase index %s", 
          voice.voice_id or 0, tostring(voice.phrase_index)))
      end
    end
    
    if valid then
      table.insert(valid_voices, voice)
    else
      removed_count = removed_count + 1
    end
  end
  
  if removed_count > 0 then
    PakettiPhraseVoicePool = valid_voices
    PakettiPhraseVoiceDebugLog(string.format("Removed %d invalid voices from pool", removed_count))
    PakettiPhraseVoiceUpdateUI()
  end
end

-- Handle pattern/sequence changes (called from idle notifier)
PakettiPhraseVoiceLastPatternIndex = 0
PakettiPhraseVoiceLastSequenceIndex = 0

function PakettiPhraseVoiceCheckPatternChange()
  local song = renoise.song()
  if not song then return end
  
  local current_pattern = song.selected_pattern_index
  local current_sequence = song.selected_sequence_index
  
  if current_pattern ~= PakettiPhraseVoiceLastPatternIndex or 
     current_sequence ~= PakettiPhraseVoiceLastSequenceIndex then
    
    PakettiPhraseVoiceLastPatternIndex = current_pattern
    PakettiPhraseVoiceLastSequenceIndex = current_sequence
    
    -- Validate voice pool on pattern change
    PakettiPhraseVoiceValidatePool()
  end
end

-- Register new document notifier for proper initialization
if not renoise.tool().app_new_document_observable:has_notifier(PakettiPhraseVoiceOnNewDocument) then
  renoise.tool().app_new_document_observable:add_notifier(PakettiPhraseVoiceOnNewDocument)
end

-- Initialize preferences on tool load (with pcall protection)
PakettiPhraseVoiceLoadPreferences()

-- Pending Voice Queue: Voices scheduled for next quantization boundary
PakettiPhraseVoicePendingQueue = {}

-- Voice Tracks: Dedicated tracks for track-per-voice mode
PakettiPhraseVoiceTracks = {}             -- [voice_id] = track_index
PakettiPhraseVoiceTrackPrefix = "PhraseVoice_"

-- Create a new PhraseVoice data structure
function PakettiPhraseVoiceCreate(instrument_index, phrase_index, options)
  options = options or {}
  
  local song = renoise.song()
  if not song then return nil end
  
  local instrument = song.instruments[instrument_index]
  if not instrument then return nil end
  
  local phrase = instrument.phrases[phrase_index]
  if not phrase then return nil end
  
  local voice = {
    voice_id = PakettiPhraseVoiceNextVoiceId,
    instrument_index = instrument_index,
    phrase_index = phrase_index,
    track_index = options.track_index or nil,
    column_index = options.column_index or nil,
    start_song_line = options.start_song_line or song.transport.playback_pos.line,
    start_phrase_line = options.start_phrase_line or 1,  -- Sxx equivalent
    phrase_length_lines = phrase.number_of_lines,
    quantization_lines = options.quantization_lines or PakettiPhraseSwitcherCustomQuant,
    phase_locked = (options.phase_locked ~= nil) and options.phase_locked or PakettiPhraseVoicePhaseLockEnabled,
    looping = (options.looping ~= nil) and options.looping or true,
    active = true,
    spawn_time = os.clock()
  }
  
  PakettiPhraseVoiceNextVoiceId = PakettiPhraseVoiceNextVoiceId + 1
  
  return voice
end

-- Add voice to the pool
function PakettiPhraseVoicePoolAdd(voice)
  if not voice then return false end
  
  -- Check max voices limit
  local max_voices = PakettiPhraseVoiceOutputMode == "column" 
    and PakettiPhraseVoiceMaxColumnsPerTrack 
    or PakettiPhraseVoiceMaxVoices
  
  if #PakettiPhraseVoicePool >= max_voices then
    -- Voice stealing: remove oldest voice
    local oldest_index = 1
    local oldest_time = PakettiPhraseVoicePool[1] and PakettiPhraseVoicePool[1].spawn_time or os.clock()
    for i, v in ipairs(PakettiPhraseVoicePool) do
      if v.spawn_time and v.spawn_time < oldest_time then
        oldest_time = v.spawn_time
        oldest_index = i
      end
    end
    PakettiPhraseVoicePoolRemove(oldest_index)
  end
  
  table.insert(PakettiPhraseVoicePool, voice)
  
  -- Trigger UI update
  PakettiPhraseVoiceUpdateUI()
  
  return true
end

-- Remove voice from pool by index
function PakettiPhraseVoicePoolRemove(index)
  if index < 1 or index > #PakettiPhraseVoicePool then return false end
  
  local voice = PakettiPhraseVoicePool[index]
  if voice then
    voice.active = false
  end
  
  table.remove(PakettiPhraseVoicePool, index)
  
  -- Trigger UI update
  PakettiPhraseVoiceUpdateUI()
  
  return true
end

-- Remove voice from pool by voice_id
function PakettiPhraseVoicePoolRemoveById(voice_id)
  for i, voice in ipairs(PakettiPhraseVoicePool) do
    if voice.voice_id == voice_id then
      return PakettiPhraseVoicePoolRemove(i)
    end
  end
  return false
end

-- Remove all voices for a specific phrase
function PakettiPhraseVoicePoolRemoveByPhrase(instrument_index, phrase_index)
  local removed = 0
  for i = #PakettiPhraseVoicePool, 1, -1 do
    local voice = PakettiPhraseVoicePool[i]
    if voice.instrument_index == instrument_index and voice.phrase_index == phrase_index then
      PakettiPhraseVoicePoolRemove(i)
      removed = removed + 1
    end
  end
  return removed
end

-- Remove all voices for a specific instrument
function PakettiPhraseVoicePoolRemoveByInstrument(instrument_index)
  local removed = 0
  for i = #PakettiPhraseVoicePool, 1, -1 do
    local voice = PakettiPhraseVoicePool[i]
    if voice.instrument_index == instrument_index then
      PakettiPhraseVoicePoolRemove(i)
      removed = removed + 1
    end
  end
  return removed
end

-- Clear all voices from pool
function PakettiPhraseVoicePoolClear()
  for i = #PakettiPhraseVoicePool, 1, -1 do
    PakettiPhraseVoicePool[i].active = false
  end
  PakettiPhraseVoicePool = {}
  renoise.app():show_status("Cleared all phrase voices")
end

-- Get all active voices
function PakettiPhraseVoicePoolGetActive()
  local active = {}
  for _, voice in ipairs(PakettiPhraseVoicePool) do
    if voice.active then
      table.insert(active, voice)
    end
  end
  return active
end

-- Get voices for a specific instrument
function PakettiPhraseVoicePoolGetByInstrument(instrument_index)
  local voices = {}
  for _, voice in ipairs(PakettiPhraseVoicePool) do
    if voice.instrument_index == instrument_index and voice.active then
      table.insert(voices, voice)
    end
  end
  return voices
end

-- Check if a specific phrase is currently playing
function PakettiPhraseVoiceIsPlaying(instrument_index, phrase_index)
  for _, voice in ipairs(PakettiPhraseVoicePool) do
    if voice.instrument_index == instrument_index 
       and voice.phrase_index == phrase_index 
       and voice.active then
      return true, voice
    end
  end
  return false, nil
end

-- Voice stealing: find and kill the oldest voice to make room for a new one
-- Returns the stolen voice's track/column info, or nil if stealing failed
function PakettiPhraseVoiceStealOldest(mode, target_track_index)
  local song = renoise.song()
  if not song then return nil end
  
  if #PakettiPhraseVoicePool == 0 then return nil end
  
  local oldest_voice = nil
  local oldest_index = nil
  local oldest_spawn_time = math.huge
  
  for i, voice in ipairs(PakettiPhraseVoicePool) do
    if voice.active then
      -- Filter by mode
      local match = true
      if mode == "column" and target_track_index then
        match = (voice.track_index == target_track_index)
      end
      
      if match then
        -- Use spawn time (start_song_line) to find oldest
        local spawn_time = voice.start_song_line or 0
        if spawn_time < oldest_spawn_time then
          oldest_spawn_time = spawn_time
          oldest_voice = voice
          oldest_index = i
        end
      end
    end
  end
  
  if not oldest_voice then return nil end
  
  -- Inject note-off for the stolen voice
  PakettiPhraseVoiceInjectNoteOff(
    oldest_voice.instrument_index, 
    oldest_voice.track_index, 
    oldest_voice.column_index
  )
  
  -- Save track/column info before removing
  local stolen_info = {
    track_index = oldest_voice.track_index,
    column_index = oldest_voice.column_index
  }
  
  -- Remove from pool
  table.remove(PakettiPhraseVoicePool, oldest_index)
  
  return stolen_info
end

-- Get next available track for voice output (track mode)
function PakettiPhraseVoiceGetNextTrack()
  local song = renoise.song()
  if not song then return nil end
  
  -- Find existing voice tracks
  local used_tracks = {}
  for _, voice in ipairs(PakettiPhraseVoicePool) do
    if voice.track_index then
      used_tracks[voice.track_index] = true
    end
  end
  
  -- Find first available voice track
  for i = 1, #song.tracks do
    local track = song.tracks[i]
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      if track.name:match("^" .. PakettiPhraseVoiceTrackPrefix) then
        if not used_tracks[i] then
          return i
        end
      end
    end
  end
  
  -- No available track, create one if under limit
  local voice_track_count = 0
  for i = 1, #song.tracks do
    if song.tracks[i].name:match("^" .. PakettiPhraseVoiceTrackPrefix) then
      voice_track_count = voice_track_count + 1
    end
  end
  
  if voice_track_count < PakettiPhraseVoiceMaxVoices then
    -- Create new voice track at end of sequencer tracks
    local insert_pos = 1
    for i = #song.tracks, 1, -1 do
      if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEQUENCER then
        insert_pos = i + 1
        break
      end
    end
    
    song:insert_track_at(insert_pos)
    song.tracks[insert_pos].name = PakettiPhraseVoiceTrackPrefix .. string.format("%02d", voice_track_count + 1)
    return insert_pos
  end
  
  return nil
end

-- Get next available column for voice output (column mode)
function PakettiPhraseVoiceGetNextColumn(track_index)
  local song = renoise.song()
  if not song then return nil end
  
  track_index = track_index or song.selected_track_index
  local track = song.tracks[track_index]
  
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    return nil
  end
  
  -- Find columns used by active voices
  local used_columns = {}
  for _, voice in ipairs(PakettiPhraseVoicePool) do
    if voice.track_index == track_index and voice.column_index then
      used_columns[voice.column_index] = true
    end
  end
  
  -- Find first available column
  for col = 1, track.visible_note_columns do
    if not used_columns[col] then
      return col
    end
  end
  
  -- Expand columns if possible
  if track.visible_note_columns < PakettiPhraseVoiceMaxColumnsPerTrack then
    track.visible_note_columns = track.visible_note_columns + 1
    return track.visible_note_columns
  end
  
  return nil
end

-- Set voice output mode
function PakettiPhraseVoiceSetOutputMode(mode)
  if mode == "track" or mode == "column" then
    PakettiPhraseVoiceOutputMode = mode
    renoise.app():show_status("Phrase Voice output mode: " .. mode)
  else
    renoise.app():show_status("Invalid output mode: " .. tostring(mode))
  end
end

-- Toggle voice output mode
function PakettiPhraseVoiceToggleOutputMode()
  if PakettiPhraseVoiceOutputMode == "track" then
    PakettiPhraseVoiceSetOutputMode("column")
  else
    PakettiPhraseVoiceSetOutputMode("track")
  end
end

-- Toggle global phase lock
function PakettiPhraseVoiceTogglePhaseLock()
  PakettiPhraseVoicePhaseLockEnabled = not PakettiPhraseVoicePhaseLockEnabled
  local status = PakettiPhraseVoicePhaseLockEnabled and "enabled" or "disabled"
  renoise.app():show_status("Phrase Voice phase lock: " .. status)
end

--------------------------------------------------------------------------------
-- PHRASE VOICE PHASE CALCULATOR (Sxx-equivalent)
-- Calculates phase-correct start offset for groove-locked phrase playback
--------------------------------------------------------------------------------

-- Calculate phase offset for a phrase to start as if it had been playing
-- Returns the Sxx-equivalent line offset (1-based)
-- Uses global song position for true groove-locked playback
function PakettiPhraseVoiceCalculatePhaseOffset(phrase_length, quant_type)
  local song = renoise.song()
  if not song then return 1 end
  
  local transport = song.transport
  if not transport.playing then return 1 end
  
  local playback_pos = transport.playback_pos
  local current_line = playback_pos.line
  local current_sequence = playback_pos.sequence
  local lpb = transport.lpb
  
  quant_type = quant_type or PakettiPhraseSwitcherDefaultQuant
  
  -- Determine quantization resolution in lines
  local quant_lines = 1
  if quant_type == "line" then
    quant_lines = 1
  elseif quant_type == "beat" then
    quant_lines = lpb
  elseif quant_type == "bar" then
    quant_lines = lpb * 4
  elseif quant_type == "custom" then
    quant_lines = PakettiPhraseSwitcherCustomQuant or 4
  end
  
  -- Calculate global song line position (absolute line from song start)
  -- This is essential for groove-locked playback across patterns
  local global_line = 0
  for seq_idx = 1, current_sequence - 1 do
    local pattern_idx = song.sequencer:pattern(seq_idx)
    if pattern_idx and song.patterns[pattern_idx] then
      global_line = global_line + song.patterns[pattern_idx].number_of_lines
    end
  end
  global_line = global_line + current_line
  
  -- Calculate the next quantization boundary (global)
  local next_quant_boundary = math.ceil(global_line / quant_lines) * quant_lines
  
  -- Phase offset: where the phrase WOULD be if it had been playing from song start
  -- This is the key calculation for groove-locked playback (Sxx-equivalent)
  local start_phrase_line = (next_quant_boundary % phrase_length) + 1
  
  -- Ensure valid range
  if start_phrase_line < 1 then start_phrase_line = 1 end
  if start_phrase_line > phrase_length then start_phrase_line = 1 end
  
  return start_phrase_line
end

-- Calculate phase offset from global beat position (immediate mode)
-- Used when in Phrase Editor for non-quantized but phase-correct starts
function PakettiPhraseVoiceCalculateImmediatePhaseOffset(phrase_length, phrase_lpb)
  local song = renoise.song()
  if not song then return 1 end
  
  local transport = song.transport
  if not transport.playing then return 1 end
  
  local playback_pos = transport.playback_pos
  local song_lpb = transport.lpb
  phrase_lpb = phrase_lpb or song_lpb
  
  -- Calculate global beat position
  local global_beat = (playback_pos.line - 1) / song_lpb
  
  -- Convert to phrase line position
  local phrase_beat_lines = global_beat * phrase_lpb
  local phrase_line = math.floor(phrase_beat_lines % phrase_length) + 1
  
  -- Ensure valid range
  if phrase_line < 1 then phrase_line = 1 end
  if phrase_line > phrase_length then phrase_line = 1 end
  
  return phrase_line
end

-- Convert phase offset to Sxx effect value (0x00-0xFF)
function PakettiPhraseVoicePhaseToSxx(phrase_line, phrase_length)
  if phrase_length <= 1 then return 0x00 end
  
  -- Sxx value represents position within phrase as 0-255 range
  -- S00 = start, SFF = near end
  local normalized = (phrase_line - 1) / (phrase_length - 1)
  local sxx_value = math.floor(normalized * 255)
  
  -- Clamp to valid range
  if sxx_value < 0 then sxx_value = 0 end
  if sxx_value > 255 then sxx_value = 255 end
  
  return sxx_value
end

-- Convert Sxx effect value to phrase line
function PakettiPhraseVoiceSxxToPhraseLine(sxx_value, phrase_length)
  if phrase_length <= 1 then return 1 end
  
  -- Reverse the calculation
  local normalized = sxx_value / 255
  local phrase_line = math.floor(normalized * (phrase_length - 1)) + 1
  
  -- Clamp to valid range
  if phrase_line < 1 then phrase_line = 1 end
  if phrase_line > phrase_length then phrase_line = phrase_length end
  
  return phrase_line
end

-- Get quantization lines for a given quant type
function PakettiPhraseVoiceGetQuantLines(quant_type)
  local song = renoise.song()
  if not song then return 4 end
  
  local lpb = song.transport.lpb
  
  if quant_type == "line" then
    return 1
  elseif quant_type == "beat" then
    return lpb
  elseif quant_type == "bar" then
    return lpb * 4
  elseif quant_type == "custom" then
    return PakettiPhraseSwitcherCustomQuant
  else
    return lpb  -- Default to beat
  end
end

--------------------------------------------------------------------------------
-- PHRASE VOICE SPAWN SYSTEM
-- Spawns phrase voices with track-per-voice or column-per-voice output
--------------------------------------------------------------------------------

-- Spawn a new phrase voice (main entry point)
-- This is the additive version that doesn't stop other phrases
-- Validate environment for voice spawning and provide helpful feedback
function PakettiPhraseVoiceValidateEnvironment(instrument_index, phrase_index)
  local song = renoise.song()
  if not song then return false, "No song loaded" end
  
  -- Validate instrument
  if not instrument_index or instrument_index < 1 or instrument_index > #song.instruments then
    return false, "Invalid instrument index"
  end
  
  local instrument = song.instruments[instrument_index]
  if not instrument then
    return false, "Instrument not found"
  end
  
  -- Check for phrases
  if #instrument.phrases == 0 then
    return false, string.format("Instrument '%s' has no phrases. Create phrases first.", instrument.name or "")
  end
  
  -- Validate phrase index
  if phrase_index < 1 or phrase_index > #instrument.phrases then
    return false, string.format("Phrase %02d does not exist (instrument has %d phrases)", phrase_index, #instrument.phrases)
  end
  
  local phrase = instrument.phrases[phrase_index]
  local pattern = song.selected_pattern
  
  -- Check phrase length vs pattern length
  if phrase.number_of_lines > pattern.number_of_lines then
    PakettiPhraseVoiceDebugLog(string.format("Warning: Phrase (%d lines) is longer than pattern (%d lines)", 
      phrase.number_of_lines, pattern.number_of_lines))
  end
  
  -- Check quantization vs pattern length
  local quant_lines = PakettiPhraseVoiceGetQuantLines(PakettiPhraseSwitcherDefaultQuant)
  if quant_lines > pattern.number_of_lines then
    PakettiPhraseVoiceDebugLog(string.format("Warning: Quantization (%d lines) exceeds pattern length (%d lines)", 
      quant_lines, pattern.number_of_lines))
  end
  
  -- Check available sequencer tracks
  local sequencer_tracks = 0
  for i = 1, #song.tracks do
    if song.tracks[i].type == renoise.Track.TRACK_TYPE_SEQUENCER then
      sequencer_tracks = sequencer_tracks + 1
    end
  end
  
  if sequencer_tracks == 0 then
    return false, "No sequencer tracks available. Add a track first."
  end
  
  return true, nil
end

function PakettiPhraseVoiceSpawn(phrase_index, options)
  local song = renoise.song()
  if not song then return nil end
  
  options = options or {}
  local instrument_index = options.instrument_index or song.selected_instrument_index
  
  -- Comprehensive validation with helpful messages
  local valid, error_msg = PakettiPhraseVoiceValidateEnvironment(instrument_index, phrase_index)
  if not valid then
    renoise.app():show_status(error_msg)
    PakettiPhraseVoiceDebugLog("Spawn failed: " .. error_msg)
    return nil
  end
  
  local instrument = song.instruments[instrument_index]
  
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return nil
  end
  
  if #instrument.phrases == 0 then
    renoise.app():show_status("No phrases in selected instrument")
    return nil
  end
  
  if phrase_index < 1 or phrase_index > #instrument.phrases then
    renoise.app():show_status(string.format("Phrase %02d does not exist", phrase_index))
    return nil
  end
  
  local phrase = instrument.phrases[phrase_index]
  local quant_type = options.quant_type or PakettiPhraseSwitcherDefaultQuant
  local phase_locked = (options.phase_locked ~= nil) and options.phase_locked or PakettiPhraseVoicePhaseLockEnabled
  local output_mode = options.output_mode or PakettiPhraseVoiceOutputMode
  local immediate = options.immediate or false
  
  -- Check if this phrase is already playing (for toggle behavior)
  if options.toggle then
    local is_playing, existing_voice = PakettiPhraseVoiceIsPlaying(instrument_index, phrase_index)
    if is_playing then
      PakettiPhraseVoicePoolRemoveById(existing_voice.voice_id)
      PakettiPhraseVoiceInjectNoteOff(instrument_index, existing_voice.track_index, existing_voice.column_index)
      renoise.app():show_status(string.format("Stopped Phrase Voice %02d", phrase_index))
      return nil
    end
  end
  
  -- Calculate phase offset if phase-locked
  local start_phrase_line = 1
  if phase_locked and song.transport.playing then
    if immediate then
      start_phrase_line = PakettiPhraseVoiceCalculateImmediatePhaseOffset(phrase.number_of_lines, phrase.lpb)
    else
      start_phrase_line = PakettiPhraseVoiceCalculatePhaseOffset(phrase.number_of_lines, quant_type)
    end
  end
  
  -- Determine target track and column based on output mode
  local track_index, column_index
  local voice_stolen = false
  
  if output_mode == "track" then
    track_index = PakettiPhraseVoiceGetNextTrack()
    column_index = 1
    if not track_index then
      -- Voice stealing: kill oldest voice and reuse its track
      local stolen = PakettiPhraseVoiceStealOldest("track")
      if stolen then
        track_index = stolen.track_index
        column_index = stolen.column_index
        voice_stolen = true
      else
        renoise.app():show_status("No available tracks for voice (max reached, stealing failed)")
        return nil
      end
    end
  else  -- column mode
    track_index = options.track_index or song.selected_track_index
    column_index = PakettiPhraseVoiceGetNextColumn(track_index)
    if not column_index then
      -- Voice stealing: kill oldest voice on this track and reuse its column
      local stolen = PakettiPhraseVoiceStealOldest("column", track_index)
      if stolen then
        track_index = stolen.track_index
        column_index = stolen.column_index
        voice_stolen = true
      else
        renoise.app():show_status("No available columns for voice (max reached, stealing failed)")
        return nil
      end
    end
  end
  
  -- Create voice data structure
  local voice = PakettiPhraseVoiceCreate(instrument_index, phrase_index, {
    track_index = track_index,
    column_index = column_index,
    start_song_line = song.transport.playback_pos.line,
    start_phrase_line = start_phrase_line,
    quantization_lines = PakettiPhraseVoiceGetQuantLines(quant_type),
    phase_locked = phase_locked,
    looping = true
  })
  
  if not voice then
    renoise.app():show_status("Failed to create voice")
    return nil
  end
  
  -- Write the note trigger to the pattern
  local target_line
  if immediate then
    target_line = song.transport.playback_pos.line
  else
    target_line = PakettiPhraseSwitcherGetNextQuantLine(quant_type)
  end
  
  local success = PakettiPhraseVoiceWriteTrigger(voice, target_line, start_phrase_line)
  
  if success then
    PakettiPhraseVoicePoolAdd(voice)
    
    local status_msg = string.format("Spawned Phrase Voice %02d on %s %d (phase: line %d)%s", 
      phrase_index, 
      output_mode == "track" and "track" or "column",
      output_mode == "track" and track_index or column_index,
      start_phrase_line,
      voice_stolen and " [voice stolen]" or "")
    renoise.app():show_status(status_msg)
    
    return voice
  else
    renoise.app():show_status("Failed to write voice trigger")
    return nil
  end
end

-- Write phrase trigger to pattern (internal)
-- Helper: Check if a note column is empty
function PakettiPhraseVoiceIsColumnEmpty(note_col)
  if not note_col then return true end
  return note_col.is_empty
end

-- Helper: Find an empty line within quantization window
function PakettiPhraseVoiceFindEmptyLine(pattern_track, track, start_line, window_size, column_index)
  local pattern_length = pattern_track.lines_in_pattern
  window_size = window_size or 4
  
  for offset = 0, window_size - 1 do
    local line_idx = start_line + offset
    if line_idx > pattern_length then
      line_idx = line_idx - pattern_length
    end
    
    local line = pattern_track:line(line_idx)
    if line then
      local note_col = line:note_column(column_index)
      if note_col and note_col.is_empty then
        return line_idx
      end
    end
  end
  
  return nil  -- No empty line found
end

-- Helper: Debug logging
function PakettiPhraseVoiceDebugLog(message)
  if PakettiPhraseVoiceDebugEnabled then
    print("[PhraseVoice] " .. message)
  end
end

function PakettiPhraseVoiceWriteTrigger(voice, target_line, phase_offset)
  local song = renoise.song()
  if not song then return false end
  
  -- Nil guards for voice data
  if not voice then return false end
  
  local pattern = song.selected_pattern
  if not pattern then return false end
  
  local track_index = voice.track_index
  local column_index = voice.column_index or 1
  
  if not track_index or track_index < 1 or track_index > #song.tracks then return false end
  
  local track = song.tracks[track_index]
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then return false end
  
  -- Ensure column_index is valid
  if column_index < 1 then column_index = 1 end
  if column_index > track.visible_note_columns then
    if track.visible_note_columns < 12 then
      track.visible_note_columns = column_index
    else
      column_index = 1
    end
  end
  
  local pattern_track = pattern:track(track_index)
  if not pattern_track then return false end
  
  if target_line < 1 or target_line > pattern.number_of_lines then
    target_line = 1
  end
  
  local line = pattern_track:line(target_line)
  if not line then return false end
  
  local note_col = line:note_column(column_index)
  if not note_col then return false end
  
  -- Pattern write safety: check if we would overwrite existing data
  if PakettiPhraseVoicePreserveExistingNotes and not note_col.is_empty then
    -- Try to find an empty line within quantization window
    local quant_lines = PakettiPhraseVoiceGetQuantLines(PakettiPhraseSwitcherDefaultQuant)
    local empty_line = PakettiPhraseVoiceFindEmptyLine(pattern_track, track, target_line, quant_lines, column_index)
    
    if empty_line then
      target_line = empty_line
      line = pattern_track:line(target_line)
      note_col = line:note_column(column_index)
      PakettiPhraseVoiceDebugLog(string.format("Found empty line at %d (original was %d)", empty_line, target_line))
    else
      -- Try next column if available
      for col = column_index + 1, math.min(12, track.visible_note_columns + 1) do
        local alt_col = line:note_column(col)
        if alt_col and alt_col.is_empty then
          column_index = col
          note_col = alt_col
          if col > track.visible_note_columns then
            track.visible_note_columns = col
          end
          PakettiPhraseVoiceDebugLog(string.format("Using alternate column %d", col))
          break
        end
      end
      
      -- If still not empty, warn but proceed (override safety)
      if not note_col.is_empty then
        PakettiPhraseVoiceDebugLog("Warning: Overwriting existing note data")
        renoise.app():show_status("Voice trigger: overwriting existing note")
      end
    end
  end
  
  -- Write note with phrase trigger (Zxx command)
  note_col.note_value = 48  -- C-4
  note_col.instrument_value = (voice.instrument_index or 1) - 1
  
  -- Write Zxx command for phrase trigger
  track.sample_effects_column_visible = true
  note_col.effect_number_value = 0x23  -- Z command (phrase trigger)
  note_col.effect_amount_value = voice.phrase_index or 1
  
  -- If phase-locked with offset > 1, write Sxx command in effect column
  if voice.phase_locked and phase_offset and phase_offset > 1 then
    local sxx_value = PakettiPhraseVoicePhaseToSxx(phase_offset, voice.phrase_length_lines or 16)
    if sxx_value and sxx_value > 0 then
      -- Find or create an effect column for Sxx
      if track.visible_effect_columns < 1 then
        track.visible_effect_columns = 1
      end
      local effect_col = line:effect_column(1)
      if effect_col then
        effect_col.number_string = "0S"  -- Sample offset / phrase position command
        effect_col.amount_value = sxx_value
      end
    end
  end
  
  return true
end

-- Inject note-off for a specific voice
-- Inject fade-out effect before note-off for smooth voice stopping
function PakettiPhraseVoiceInjectFadeOut(track_index, column_index, start_line, fade_lines)
  local song = renoise.song()
  if not song then return false end
  
  fade_lines = fade_lines or 4
  local pattern = song.selected_pattern
  if not pattern then return false end
  
  local track = song.tracks[track_index]
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then return false end
  
  local pattern_track = pattern:track(track_index)
  if not pattern_track then return false end
  
  -- Ensure effect column is visible
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  
  -- Write fade-out over specified lines using 0O command
  for i = 0, fade_lines - 1 do
    local line_idx = start_line + i
    if line_idx > pattern.number_of_lines then
      line_idx = line_idx - pattern.number_of_lines
    end
    
    local line = pattern_track:line(line_idx)
    if line then
      local effect_col = line:effect_column(1)
      if effect_col then
        -- Calculate fade value (FF down to 00)
        local fade_value = math.floor(255 - (255 * i / fade_lines))
        effect_col.number_string = "0O"  -- Output volume
        effect_col.amount_value = fade_value
      end
    end
  end
  
  PakettiPhraseVoiceDebugLog(string.format("Injected fade-out over %d lines starting at line %d", fade_lines, start_line))
  return true
end

function PakettiPhraseVoiceInjectNoteOff(instrument_index, track_index, column_index, use_fade_out)
  local song = renoise.song()
  if not song then return false end
  
  -- Nil guards for parameters
  if not instrument_index or instrument_index < 1 then return false end
  if not track_index or track_index < 1 or track_index > #song.tracks then return false end
  
  local track = song.tracks[track_index]
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then return false end
  
  local target_line = PakettiPhraseSwitcherGetNextQuantLine(PakettiPhraseSwitcherDefaultQuant)
  local pattern = song.selected_pattern
  if not pattern then return false end
  
  local pattern_track = pattern:track(track_index)
  if not pattern_track then return false end
  
  if target_line < 1 or target_line > pattern.number_of_lines then
    target_line = 1
  end
  
  -- Use fade-out if enabled (default from preference)
  use_fade_out = (use_fade_out ~= nil) and use_fade_out or PakettiPhraseVoiceFadeOutEnabled
  
  if use_fade_out then
    -- Inject fade-out before note-off
    local fade_lines = 4  -- Fade over 4 lines
    PakettiPhraseVoiceInjectFadeOut(track_index, column_index, target_line, fade_lines)
    -- Offset note-off to after fade
    target_line = target_line + fade_lines
    if target_line > pattern.number_of_lines then
      target_line = target_line - pattern.number_of_lines
    end
  end
  
  local line = pattern_track:line(target_line)
  local note_col = line:note_column(column_index or 1)
  
  note_col.note_value = 120  -- OFF
  note_col.instrument_value = instrument_index - 1
  
  PakettiPhraseVoiceDebugLog(string.format("Injected note-off at line %d%s", 
    target_line, use_fade_out and " (with fade)" or ""))
  
  return true
end

-- Kill all voices (stop all phrase playback)
function PakettiPhraseVoiceKillAll()
  local song = renoise.song()
  if not song then return end
  
  -- Inject note-offs for all active voices
  for _, voice in ipairs(PakettiPhraseVoicePool) do
    if voice.active then
      PakettiPhraseVoiceInjectNoteOff(voice.instrument_index, voice.track_index, voice.column_index)
    end
  end
  
  PakettiPhraseVoicePoolClear()
end

-- Kill voice by phrase index
function PakettiPhraseVoiceKillPhrase(phrase_index, instrument_index)
  local song = renoise.song()
  if not song then return end
  
  instrument_index = instrument_index or song.selected_instrument_index
  
  -- Find and kill voices for this phrase
  for i = #PakettiPhraseVoicePool, 1, -1 do
    local voice = PakettiPhraseVoicePool[i]
    if voice.instrument_index == instrument_index and voice.phrase_index == phrase_index then
      PakettiPhraseVoiceInjectNoteOff(voice.instrument_index, voice.track_index, voice.column_index)
      PakettiPhraseVoicePoolRemove(i)
    end
  end
  
  renoise.app():show_status(string.format("Killed Phrase %02d voices", phrase_index))
end

-- Spawn multiple phrases as a state (concurrent voices)
function PakettiPhraseVoiceSpawnState(phrase_indices, options)
  local song = renoise.song()
  if not song then return {} end
  
  options = options or {}
  local voices = {}
  
  for _, phrase_index in ipairs(phrase_indices) do
    local voice = PakettiPhraseVoiceSpawn(phrase_index, options)
    if voice then
      table.insert(voices, voice)
    end
  end
  
  if #voices > 0 then
    renoise.app():show_status(string.format("Spawned %d phrase voices", #voices))
  end
  
  return voices
end

-- Quick spawn functions for keybindings (additive)
function PakettiPhraseVoiceSpawnPhrase01() PakettiPhraseVoiceSpawn(1) end
function PakettiPhraseVoiceSpawnPhrase02() PakettiPhraseVoiceSpawn(2) end
function PakettiPhraseVoiceSpawnPhrase03() PakettiPhraseVoiceSpawn(3) end
function PakettiPhraseVoiceSpawnPhrase04() PakettiPhraseVoiceSpawn(4) end
function PakettiPhraseVoiceSpawnPhrase05() PakettiPhraseVoiceSpawn(5) end
function PakettiPhraseVoiceSpawnPhrase06() PakettiPhraseVoiceSpawn(6) end
function PakettiPhraseVoiceSpawnPhrase07() PakettiPhraseVoiceSpawn(7) end
function PakettiPhraseVoiceSpawnPhrase08() PakettiPhraseVoiceSpawn(8) end
function PakettiPhraseVoiceSpawnPhrase09() PakettiPhraseVoiceSpawn(9) end
function PakettiPhraseVoiceSpawnPhrase10() PakettiPhraseVoiceSpawn(10) end
function PakettiPhraseVoiceSpawnPhrase11() PakettiPhraseVoiceSpawn(11) end
function PakettiPhraseVoiceSpawnPhrase12() PakettiPhraseVoiceSpawn(12) end
function PakettiPhraseVoiceSpawnPhrase13() PakettiPhraseVoiceSpawn(13) end
function PakettiPhraseVoiceSpawnPhrase14() PakettiPhraseVoiceSpawn(14) end
function PakettiPhraseVoiceSpawnPhrase15() PakettiPhraseVoiceSpawn(15) end
function PakettiPhraseVoiceSpawnPhrase16() PakettiPhraseVoiceSpawn(16) end

-- Quick kill functions for keybindings
function PakettiPhraseVoiceKillPhrase01() PakettiPhraseVoiceKillPhrase(1) end
function PakettiPhraseVoiceKillPhrase02() PakettiPhraseVoiceKillPhrase(2) end
function PakettiPhraseVoiceKillPhrase03() PakettiPhraseVoiceKillPhrase(3) end
function PakettiPhraseVoiceKillPhrase04() PakettiPhraseVoiceKillPhrase(4) end
function PakettiPhraseVoiceKillPhrase05() PakettiPhraseVoiceKillPhrase(5) end
function PakettiPhraseVoiceKillPhrase06() PakettiPhraseVoiceKillPhrase(6) end
function PakettiPhraseVoiceKillPhrase07() PakettiPhraseVoiceKillPhrase(7) end
function PakettiPhraseVoiceKillPhrase08() PakettiPhraseVoiceKillPhrase(8) end
function PakettiPhraseVoiceKillPhrase09() PakettiPhraseVoiceKillPhrase(9) end
function PakettiPhraseVoiceKillPhrase10() PakettiPhraseVoiceKillPhrase(10) end
function PakettiPhraseVoiceKillPhrase11() PakettiPhraseVoiceKillPhrase(11) end
function PakettiPhraseVoiceKillPhrase12() PakettiPhraseVoiceKillPhrase(12) end
function PakettiPhraseVoiceKillPhrase13() PakettiPhraseVoiceKillPhrase(13) end
function PakettiPhraseVoiceKillPhrase14() PakettiPhraseVoiceKillPhrase(14) end
function PakettiPhraseVoiceKillPhrase15() PakettiPhraseVoiceKillPhrase(15) end
function PakettiPhraseVoiceKillPhrase16() PakettiPhraseVoiceKillPhrase(16) end

--------------------------------------------------------------------------------
-- PHRASE VOICE OPERATION MODES
-- Editor Mode: Immediate, non-quantized playback for phrase editing
-- Switcher Mode: Quantized, scheduled playback for live performance
--------------------------------------------------------------------------------

-- Current operation mode
PakettiPhraseVoiceOperationMode = "switcher"  -- "editor" or "switcher"

-- Set operation mode
function PakettiPhraseVoiceSetOperationMode(mode)
  if mode == "editor" or mode == "switcher" then
    PakettiPhraseVoiceOperationMode = mode
    renoise.app():show_status("Phrase Voice operation mode: " .. mode)
  else
    renoise.app():show_status("Invalid operation mode: " .. tostring(mode))
  end
end

-- Toggle operation mode
function PakettiPhraseVoiceToggleOperationMode()
  if PakettiPhraseVoiceOperationMode == "editor" then
    PakettiPhraseVoiceSetOperationMode("switcher")
  else
    PakettiPhraseVoiceSetOperationMode("editor")
  end
end

-- Auto-detect operation mode based on current view
function PakettiPhraseVoiceAutoDetectMode()
  local app = renoise.app()
  if app.window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
    return "editor"
  else
    return "switcher"
  end
end

--------------------------------------------------------------------------------
-- PHRASE SELECTION AUTO-SPAWN
-- Automatically spawns phrase voices when selecting phrases in the Phrase Index
-- Section 5 (Editor Mode): Immediate, phase-correct spawn
-- Section 6 (Switcher Mode): Quantized, scheduled spawn at next boundary
--------------------------------------------------------------------------------

-- Track if notifier is currently active
PakettiPhraseVoiceSelectionNotifierActive = false

-- Last selected phrase index (to avoid duplicate triggers)
PakettiPhraseVoiceLastSelectedPhraseIndex = 0

-- Phrase selection notifier callback
-- Called when user selects a different phrase in the Phrase Index
function PakettiPhraseVoiceOnPhraseSelectionChanged()
  -- Check if auto-spawn is enabled
  if not PakettiPhraseVoiceAutoSpawnEnabled then
    return
  end
  
  -- Check if phrase transport is enabled
  if not PakettiPhraseTransportEnabled then
    return
  end
  
  local song = renoise.song()
  if not song then return end
  
  -- Get current phrase index
  local phrase_index = song.selected_phrase_index
  if phrase_index < 1 then return end
  
  -- Avoid duplicate triggers on same phrase
  if phrase_index == PakettiPhraseVoiceLastSelectedPhraseIndex then
    return
  end
  PakettiPhraseVoiceLastSelectedPhraseIndex = phrase_index
  
  -- Validate phrase exists
  local instrument = song.selected_instrument
  if not instrument then return end
  if phrase_index > #instrument.phrases then return end
  
  -- Check transport - only spawn when playing
  if not song.transport.playing then
    PakettiPhraseVoiceDebugLog(string.format("Auto-spawn skipped (not playing): Phrase %02d", phrase_index))
    return
  end
  
  -- Determine mode and spawn accordingly
  local mode = PakettiPhraseVoiceAutoDetectMode()
  
  if mode == "editor" then
    -- Editor Mode (Section 5): Immediate, phase-correct spawn
    PakettiPhraseVoiceDebugLog(string.format("Auto-spawn (editor mode): Phrase %02d", phrase_index))
    PakettiPhraseVoiceEditorModeSpawn(phrase_index)
  else
    -- Switcher Mode (Section 6): Schedule for next quantization boundary
    PakettiPhraseVoiceDebugLog(string.format("Auto-spawn (switcher mode): Scheduling Phrase %02d", phrase_index))
    PakettiPhraseVoiceSwitcherModeSchedule(phrase_index)
  end
end

-- Toggle auto-spawn on phrase selection
function PakettiPhraseVoiceToggleAutoSpawn()
  PakettiPhraseVoiceAutoSpawnEnabled = not PakettiPhraseVoiceAutoSpawnEnabled
  local status = PakettiPhraseVoiceAutoSpawnEnabled and "enabled" or "disabled"
  renoise.app():show_status("Phrase Voice auto-spawn on selection: " .. status)
  
  -- Save preference
  PakettiPhraseVoiceSavePreferences()
  
  -- If enabled, ensure notifier is added
  if PakettiPhraseVoiceAutoSpawnEnabled then
    PakettiPhraseVoiceAddSelectionNotifier()
  end
end

-- Add phrase selection notifier (safe - checks if already present)
function PakettiPhraseVoiceAddSelectionNotifier()
  local song = renoise.song()
  if not song then return false end
  
  -- Don't add if already active
  if PakettiPhraseVoiceSelectionNotifierActive then
    return true
  end
  
  -- Add the notifier
  local success = pcall(function()
    if not song.selected_phrase_index_observable:has_notifier(PakettiPhraseVoiceOnPhraseSelectionChanged) then
      song.selected_phrase_index_observable:add_notifier(PakettiPhraseVoiceOnPhraseSelectionChanged)
      PakettiPhraseVoiceSelectionNotifierActive = true
      PakettiPhraseVoiceDebugLog("Phrase selection notifier added")
    else
      PakettiPhraseVoiceSelectionNotifierActive = true
    end
  end)
  
  return success
end

-- Remove phrase selection notifier (safe - checks if present)
function PakettiPhraseVoiceRemoveSelectionNotifier()
  local song = renoise.song()
  if not song then
    PakettiPhraseVoiceSelectionNotifierActive = false
    return true
  end
  
  -- Remove the notifier
  local success = pcall(function()
    if song.selected_phrase_index_observable:has_notifier(PakettiPhraseVoiceOnPhraseSelectionChanged) then
      song.selected_phrase_index_observable:remove_notifier(PakettiPhraseVoiceOnPhraseSelectionChanged)
      PakettiPhraseVoiceDebugLog("Phrase selection notifier removed")
    end
    PakettiPhraseVoiceSelectionNotifierActive = false
  end)
  
  return success
end

-- Reset selection state on new document
function PakettiPhraseVoiceResetSelectionState()
  PakettiPhraseVoiceLastSelectedPhraseIndex = 0
  PakettiPhraseVoiceSelectionNotifierActive = false
  
  -- Re-add notifier if auto-spawn is enabled and transport is on
  if PakettiPhraseVoiceAutoSpawnEnabled and PakettiPhraseTransportEnabled then
    PakettiPhraseVoiceAddSelectionNotifier()
  end
end

-- Editor Mode: Immediate phrase voice spawn
-- Used when in Phrase Editor for instant, phase-correct playback
function PakettiPhraseVoiceEditorModeSpawn(phrase_index, options)
  local song = renoise.song()
  if not song then return nil end
  
  options = options or {}
  options.immediate = true  -- No quantization delay
  options.phase_locked = true  -- Always phase-correct in editor mode
  
  -- Use the phrase's own LPB for phase calculation
  local instrument_index = options.instrument_index or song.selected_instrument_index
  local instrument = song.instruments[instrument_index]
  if instrument and phrase_index <= #instrument.phrases then
    local phrase = instrument.phrases[phrase_index]
    -- Pass phrase LPB for accurate phase calculation
    options.phrase_lpb = phrase.lpb
  end
  
  return PakettiPhraseVoiceSpawn(phrase_index, options)
end

-- Editor Mode: Multi-select spawn
-- Spawns multiple phrases immediately when selected in Phrase Index
function PakettiPhraseVoiceEditorModeMultiSpawn(phrase_indices, options)
  local song = renoise.song()
  if not song then return {} end
  
  options = options or {}
  options.immediate = true
  options.phase_locked = true
  
  local voices = {}
  
  for _, phrase_index in ipairs(phrase_indices) do
    local voice = PakettiPhraseVoiceEditorModeSpawn(phrase_index, options)
    if voice then
      table.insert(voices, voice)
    end
  end
  
  if #voices > 0 then
    renoise.app():show_status(string.format("Editor Mode: Spawned %d phrase voices", #voices))
  end
  
  return voices
end

-- Spawn currently selected phrase in Editor mode
-- Can be called when user selects phrase in Phrase Index
function PakettiPhraseVoiceSpawnSelectedPhrase()
  local song = renoise.song()
  if not song then return nil end
  
  local instrument = song.selected_instrument
  if not instrument or #instrument.phrases == 0 then
    renoise.app():show_status("No phrases in selected instrument")
    return nil
  end
  
  local phrase_index = song.selected_phrase_index
  if phrase_index < 1 or phrase_index > #instrument.phrases then
    renoise.app():show_status("No phrase selected")
    return nil
  end
  
  PakettiPhraseVoiceDebugLog(string.format("Spawning selected phrase %d", phrase_index))
  return PakettiPhraseVoiceEditorModeSpawn(phrase_index)
end

-- Spawn a range of phrases (for modular phrase construction)
function PakettiPhraseVoiceSpawnRange(start_phrase, end_phrase, options)
  local song = renoise.song()
  if not song then return {} end
  
  local instrument = song.selected_instrument
  if not instrument or #instrument.phrases == 0 then
    renoise.app():show_status("No phrases in selected instrument")
    return {}
  end
  
  local phrase_indices = {}
  for i = start_phrase, math.min(end_phrase, #instrument.phrases) do
    table.insert(phrase_indices, i)
  end
  
  return PakettiPhraseVoiceEditorModeMultiSpawn(phrase_indices, options)
end

-- Spawn all active phrase voices for kick/snare/hat separation
-- This uses special naming convention: phrases named "Kick", "Snare", "Hat", etc.
function PakettiPhraseVoiceSpawnByName(name_pattern, options)
  local song = renoise.song()
  if not song then return {} end
  
  local instrument = song.selected_instrument
  if not instrument or #instrument.phrases == 0 then
    return {}
  end
  
  local phrase_indices = {}
  for i, phrase in ipairs(instrument.phrases) do
    if phrase.name:lower():find(name_pattern:lower()) then
      table.insert(phrase_indices, i)
    end
  end
  
  if #phrase_indices > 0 then
    PakettiPhraseVoiceDebugLog(string.format("Spawning %d phrases matching '%s'", #phrase_indices, name_pattern))
    return PakettiPhraseVoiceEditorModeMultiSpawn(phrase_indices, options)
  end
  
  return {}
end

-- Quick spawn functions for modular phrase construction
function PakettiPhraseVoiceSpawnKick() return PakettiPhraseVoiceSpawnByName("kick") end
function PakettiPhraseVoiceSpawnSnare() return PakettiPhraseVoiceSpawnByName("snare") end
function PakettiPhraseVoiceSpawnHihat() return PakettiPhraseVoiceSpawnByName("hat") end
function PakettiPhraseVoiceSpawnBass() return PakettiPhraseVoiceSpawnByName("bass") end
function PakettiPhraseVoiceSpawnLead() return PakettiPhraseVoiceSpawnByName("lead") end
function PakettiPhraseVoiceSpawnPad() return PakettiPhraseVoiceSpawnByName("pad") end

-- Switcher Mode: Quantized phrase voice spawn
-- Used for live performance with groove-safe switching
function PakettiPhraseVoiceSwitcherModeSpawn(phrase_index, options)
  local song = renoise.song()
  if not song then return nil end
  
  options = options or {}
  options.immediate = false  -- Quantized spawning
  options.quant_type = options.quant_type or PakettiPhraseSwitcherDefaultQuant
  
  return PakettiPhraseVoiceSpawn(phrase_index, options)
end

-- Switcher Mode: Schedule voice spawn at next boundary
-- Adds to pending queue for sloppy triggering support
function PakettiPhraseVoiceSwitcherModeSchedule(phrase_index, options)
  local song = renoise.song()
  if not song then return false end
  
  options = options or {}
  local instrument_index = options.instrument_index or song.selected_instrument_index
  
  -- Check for duplicate in pending queue
  for i, pending in ipairs(PakettiPhraseVoicePendingQueue) do
    if pending.instrument_index == instrument_index and pending.phrase_index == phrase_index then
      -- Already scheduled, cancel it (toggle behavior)
      table.remove(PakettiPhraseVoicePendingQueue, i)
      renoise.app():show_status(string.format("Cancelled scheduled Phrase %02d", phrase_index))
      return false
    end
  end
  
  -- Add to pending queue
  table.insert(PakettiPhraseVoicePendingQueue, {
    instrument_index = instrument_index,
    phrase_index = phrase_index,
    options = options,
    scheduled_at = os.clock()
  })
  
  renoise.app():show_status(string.format("Scheduled Phrase %02d for next boundary", phrase_index))
  return true
end

-- Process pending voice queue (called on quantization boundaries)
function PakettiPhraseVoiceProcessPendingQueue()
  local spawned = 0
  
  for i = #PakettiPhraseVoicePendingQueue, 1, -1 do
    local pending = PakettiPhraseVoicePendingQueue[i]
    local options = pending.options or {}
    options.instrument_index = pending.instrument_index
    
    local voice = PakettiPhraseVoiceSwitcherModeSpawn(pending.phrase_index, options)
    if voice then
      spawned = spawned + 1
    end
    
    table.remove(PakettiPhraseVoicePendingQueue, i)
  end
  
  if spawned > 0 then
    renoise.app():show_status(string.format("Processed %d pending voice(s)", spawned))
  end
end

-- Clear pending queue
function PakettiPhraseVoiceClearPendingQueue()
  local count = #PakettiPhraseVoicePendingQueue
  PakettiPhraseVoicePendingQueue = {}
  if count > 0 then
    renoise.app():show_status(string.format("Cleared %d pending voice(s)", count))
  end
end

-- Track last processed quantization boundary for pending queue
PakettiPhraseVoiceLastQuantBoundary = 0
PakettiPhraseVoiceIdleNotifierActive = false
PakettiPhraseVoiceLastPlaybackLine = 0

-- Track last UI update time for throttling
PakettiPhraseVoiceUILastUpdate = 0
PakettiPhraseVoiceUIUpdateInterval = 0.1  -- Update UI every 100ms

-- Update voice pool: track playhead positions and cleanup finished voices
function PakettiPhraseVoicePoolUpdate()
  local song = renoise.song()
  if not song then return end
  
  local transport = song.transport
  local current_time = os.clock()
  local pool_changed = false
  
  -- If transport stopped, mark all voices as inactive (but don't remove)
  if not transport.playing then
    for _, voice in ipairs(PakettiPhraseVoicePool) do
      if voice.active then
        voice.active = false
        pool_changed = true
      end
    end
    if pool_changed then
      PakettiPhraseVoiceUpdateUI()
    end
    return
  end
  
  local current_line = transport.playback_pos.line
  local voices_to_remove = {}
  
  -- Update each voice's estimated playhead position
  for i, voice in ipairs(PakettiPhraseVoicePool) do
    if voice.active then
      -- Calculate elapsed lines since spawn
      local elapsed_lines = current_line - (voice.start_song_line or 0)
      if elapsed_lines < 0 then
        -- Pattern wrapped, estimate based on pattern length
        local pattern_length = song.selected_pattern.number_of_lines
        elapsed_lines = elapsed_lines + pattern_length
      end
      
      -- Calculate current phrase playhead position
      local phrase_line = (voice.start_phrase_line or 1) + elapsed_lines
      if voice.looping then
        phrase_line = ((phrase_line - 1) % (voice.phrase_length_lines or 16)) + 1
      else
        -- Non-looping voice: check if it has finished
        if phrase_line > (voice.phrase_length_lines or 16) then
          voice.active = false
          table.insert(voices_to_remove, i)
          pool_changed = true
        end
      end
      
      -- Store estimated playhead for UI display
      voice.current_playhead = phrase_line
    end
  end
  
  -- Remove finished non-looping voices (iterate in reverse to avoid index issues)
  for i = #voices_to_remove, 1, -1 do
    table.remove(PakettiPhraseVoicePool, voices_to_remove[i])
    pool_changed = true
  end
  
  -- Throttled UI update
  if pool_changed or (current_time - PakettiPhraseVoiceUILastUpdate > PakettiPhraseVoiceUIUpdateInterval) then
    PakettiPhraseVoiceUILastUpdate = current_time
    PakettiPhraseVoiceUpdateUI()
  end
end

-- Update Performance Hub UI with current voice state
-- Update button highlighting for active voices
function PakettiPhraseVoiceUpdateButtonHighlights()
  if not PakettiPhraseGridPerformanceVb or not PakettiPhraseGridPerformanceDialog then return end
  if not PakettiPhraseGridPerformanceDialog.visible then return end
  
  local song = renoise.song()
  if not song then return end
  
  local instrument_index = song.selected_instrument_index
  
  -- Build set of active phrase indices for current instrument
  local active_phrases = {}
  local pending_phrases = {}
  
  for _, voice in ipairs(PakettiPhraseVoicePool) do
    if voice.instrument_index == instrument_index and voice.active then
      active_phrases[voice.phrase_index] = true
    end
  end
  
  for _, pending in ipairs(PakettiPhraseVoicePendingQueue) do
    if pending.instrument_index == instrument_index then
      pending_phrases[pending.phrase_index] = true
    end
  end
  
  -- Update button text to show state
  for i = 1, 16 do
    local btn_id = string.format("voice_btn_%02d", i)
    local btn = PakettiPhraseGridPerformanceVb.views[btn_id]
    if btn then
      if active_phrases[i] then
        -- Active voice: show with marker
        btn.text = string.format("[%02d]", i)
      elseif pending_phrases[i] then
        -- Pending voice: show with pending marker
        btn.text = string.format("*%02d*", i)
      else
        -- Inactive: normal text
        btn.text = string.format("P%02d", i)
      end
    end
  end
end

function PakettiPhraseVoiceUpdateUI()
  -- Update Performance Hub voice count if dialog is open
  if PakettiPhraseGridPerformanceVb and PakettiPhraseGridPerformanceDialog 
     and PakettiPhraseGridPerformanceDialog.visible then
    local count_text = PakettiPhraseGridPerformanceVb.views["perf_voice_count"]
    if count_text then 
      local active_count = 0
      for _, voice in ipairs(PakettiPhraseVoicePool) do
        if voice.active then active_count = active_count + 1 end
      end
      count_text.text = tostring(active_count)
    end
    
    -- Update button highlights
    PakettiPhraseVoiceUpdateButtonHighlights()
  end
end

-- Idle notifier function for processing pending voice queue and voice lifetime
function PakettiPhraseVoiceIdleNotifier()
  local song = renoise.song()
  if not song then return end
  
  -- Check for pattern/sequence changes (always, even when stopped)
  PakettiPhraseVoiceCheckPatternChange()
  
  local transport = song.transport
  if not transport.playing then
    PakettiPhraseVoiceLastQuantBoundary = 0
    PakettiPhraseVoiceLastPlaybackLine = 0
    return
  end
  
  local current_line = transport.playback_pos.line
  
  -- Only update voice pool when playback line changes (reduce CPU)
  if current_line ~= PakettiPhraseVoiceLastPlaybackLine then
    PakettiPhraseVoiceLastPlaybackLine = current_line
    
    -- Update voice pool (track playheads, cleanup finished voices)
    PakettiPhraseVoicePoolUpdate()
  end
  
  -- Process pending voices at quantization boundaries
  if #PakettiPhraseVoicePendingQueue > 0 then
    local quant_type = PakettiPhraseSwitcherDefaultQuant or "beat"
    local quant_lines = PakettiPhraseVoiceGetQuantLines(quant_type)
    local current_boundary = math.floor((current_line - 1) / quant_lines) * quant_lines + 1
    
    -- Check if we've crossed a new quantization boundary
    if current_boundary ~= PakettiPhraseVoiceLastQuantBoundary and current_boundary > 0 then
      PakettiPhraseVoiceLastQuantBoundary = current_boundary
      
      -- Process all pending voices at this boundary
      PakettiPhraseVoiceProcessPendingQueue()
    end
  end
end

-- Start the pending queue processor
function PakettiPhraseVoiceStartIdleNotifier()
  if not PakettiPhraseVoiceIdleNotifierActive then
    if not renoise.tool().app_idle_observable:has_notifier(PakettiPhraseVoiceIdleNotifier) then
      renoise.tool().app_idle_observable:add_notifier(PakettiPhraseVoiceIdleNotifier)
    end
    PakettiPhraseVoiceIdleNotifierActive = true
  end
end

-- Stop the pending queue processor
function PakettiPhraseVoiceStopIdleNotifier()
  if PakettiPhraseVoiceIdleNotifierActive then
    if renoise.tool().app_idle_observable:has_notifier(PakettiPhraseVoiceIdleNotifier) then
      renoise.tool().app_idle_observable:remove_notifier(PakettiPhraseVoiceIdleNotifier)
    end
    PakettiPhraseVoiceIdleNotifierActive = false
  end
end

-- Auto-start idle notifier when tool loads
PakettiPhraseVoiceStartIdleNotifier()

-- Smart spawn: Auto-selects mode based on current context
function PakettiPhraseVoiceSmartSpawn(phrase_index, options)
  local mode = PakettiPhraseVoiceAutoDetectMode()
  
  if mode == "editor" then
    return PakettiPhraseVoiceEditorModeSpawn(phrase_index, options)
  else
    return PakettiPhraseVoiceSwitcherModeSpawn(phrase_index, options)
  end
end

-- Toggle spawn: Spawn or kill depending on current state
function PakettiPhraseVoiceToggleSpawn(phrase_index, options)
  options = options or {}
  options.toggle = true
  
  local mode = PakettiPhraseVoiceAutoDetectMode()
  
  if mode == "editor" then
    return PakettiPhraseVoiceEditorModeSpawn(phrase_index, options)
  else
    return PakettiPhraseVoiceSwitcherModeSpawn(phrase_index, options)
  end
end

-- Smart spawn functions for keybindings
function PakettiPhraseVoiceSmartSpawn01() PakettiPhraseVoiceSmartSpawn(1) end
function PakettiPhraseVoiceSmartSpawn02() PakettiPhraseVoiceSmartSpawn(2) end
function PakettiPhraseVoiceSmartSpawn03() PakettiPhraseVoiceSmartSpawn(3) end
function PakettiPhraseVoiceSmartSpawn04() PakettiPhraseVoiceSmartSpawn(4) end
function PakettiPhraseVoiceSmartSpawn05() PakettiPhraseVoiceSmartSpawn(5) end
function PakettiPhraseVoiceSmartSpawn06() PakettiPhraseVoiceSmartSpawn(6) end
function PakettiPhraseVoiceSmartSpawn07() PakettiPhraseVoiceSmartSpawn(7) end
function PakettiPhraseVoiceSmartSpawn08() PakettiPhraseVoiceSmartSpawn(8) end
function PakettiPhraseVoiceSmartSpawn09() PakettiPhraseVoiceSmartSpawn(9) end
function PakettiPhraseVoiceSmartSpawn10() PakettiPhraseVoiceSmartSpawn(10) end
function PakettiPhraseVoiceSmartSpawn11() PakettiPhraseVoiceSmartSpawn(11) end
function PakettiPhraseVoiceSmartSpawn12() PakettiPhraseVoiceSmartSpawn(12) end
function PakettiPhraseVoiceSmartSpawn13() PakettiPhraseVoiceSmartSpawn(13) end
function PakettiPhraseVoiceSmartSpawn14() PakettiPhraseVoiceSmartSpawn(14) end
function PakettiPhraseVoiceSmartSpawn15() PakettiPhraseVoiceSmartSpawn(15) end
function PakettiPhraseVoiceSmartSpawn16() PakettiPhraseVoiceSmartSpawn(16) end

-- Toggle spawn functions for keybindings
function PakettiPhraseVoiceToggle01() PakettiPhraseVoiceToggleSpawn(1) end
function PakettiPhraseVoiceToggle02() PakettiPhraseVoiceToggleSpawn(2) end
function PakettiPhraseVoiceToggle03() PakettiPhraseVoiceToggleSpawn(3) end
function PakettiPhraseVoiceToggle04() PakettiPhraseVoiceToggleSpawn(4) end
function PakettiPhraseVoiceToggle05() PakettiPhraseVoiceToggleSpawn(5) end
function PakettiPhraseVoiceToggle06() PakettiPhraseVoiceToggleSpawn(6) end
function PakettiPhraseVoiceToggle07() PakettiPhraseVoiceToggleSpawn(7) end
function PakettiPhraseVoiceToggle08() PakettiPhraseVoiceToggleSpawn(8) end
function PakettiPhraseVoiceToggle09() PakettiPhraseVoiceToggleSpawn(9) end
function PakettiPhraseVoiceToggle10() PakettiPhraseVoiceToggleSpawn(10) end
function PakettiPhraseVoiceToggle11() PakettiPhraseVoiceToggleSpawn(11) end
function PakettiPhraseVoiceToggle12() PakettiPhraseVoiceToggleSpawn(12) end
function PakettiPhraseVoiceToggle13() PakettiPhraseVoiceToggleSpawn(13) end
function PakettiPhraseVoiceToggle14() PakettiPhraseVoiceToggleSpawn(14) end
function PakettiPhraseVoiceToggle15() PakettiPhraseVoiceToggleSpawn(15) end
function PakettiPhraseVoiceToggle16() PakettiPhraseVoiceToggleSpawn(16) end

--------------------------------------------------------------------------------
-- 1. PHRASE TRANSPORT (Enhanced Visual Follow)
--------------------------------------------------------------------------------

-- Get the current global beat position from transport
function PakettiPhraseTransportGetGlobalBeat()
  local song = renoise.song()
  if not song then return 0 end
  
  local transport = song.transport
  if not transport.playing then return 0 end
  
  local playback_pos = transport.playback_pos
  local lpb = transport.lpb
  
  -- Calculate global beat from line position
  local global_beat = (playback_pos.line - 1) / lpb
  return global_beat
end

-- Calculate phrase line from global beat
function PakettiPhraseTransportGetPhraseLine(phrase)
  if not phrase then return 1 end
  
  local global_beat = PakettiPhraseTransportGetGlobalBeat()
  local phrase_lpb = phrase.lpb
  local phrase_length = phrase.number_of_lines
  
  -- Apply armed offset
  local offset_beats = PakettiPhraseTransportArmedOffset / phrase_lpb
  global_beat = global_beat + offset_beats
  
  -- Calculate phrase line position (1-based)
  local phrase_line = math.floor((global_beat * phrase_lpb) % phrase_length) + 1
  return phrase_line
end

-- Phrase Transport notifier function
function PakettiPhraseTransportNotifier()
  local song = renoise.song()
  if not song then return end
  
  if not song.transport.playing then return end
  
  local phrase = song.selected_phrase
  if not phrase then return end
  
  local phrase_line = PakettiPhraseTransportGetPhraseLine(phrase)
  
  -- Update phrase editor playhead
  if phrase_line >= 1 and phrase_line <= phrase.number_of_lines then
    song.selected_phrase_line_index = phrase_line
  end
  
  -- Check for follow actions on loop boundary
  if PakettiPhraseFollowActionsEnabled then
    PakettiPhraseFollowActionCheckLoop(phrase_line, phrase.number_of_lines)
  end
end

-- Enable phrase transport
function PakettiPhraseTransportEnable()
  local song = renoise.song()
  if not song then return end
  
  -- Check API version
  if renoise.API_VERSION < 6.2 then
    renoise.app():show_status("Phrase Transport requires API 6.2+")
    return
  end
  
  -- Enable follow player
  song.transport.follow_player = true
  song.transport.edit_step = 0
  
  -- Switch to phrase editor
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
  
  -- Add transport notifier if not present
  if not renoise.tool().app_idle_observable:has_notifier(PakettiPhraseTransportNotifier) then
    renoise.tool().app_idle_observable:add_notifier(PakettiPhraseTransportNotifier)
  end
  
  PakettiPhraseTransportEnabled = true
  PakettiPhraseTransportCurrentSection = 0
  
  -- Add phrase selection notifier for auto-spawn if enabled
  if PakettiPhraseVoiceAutoSpawnEnabled then
    PakettiPhraseVoiceAddSelectionNotifier()
  end
  
  renoise.app():show_status("Phrase Transport: ON")
end

-- Disable phrase transport
function PakettiPhraseTransportDisable()
  -- Remove transport notifier if present
  if renoise.tool().app_idle_observable:has_notifier(PakettiPhraseTransportNotifier) then
    renoise.tool().app_idle_observable:remove_notifier(PakettiPhraseTransportNotifier)
  end
  
  -- Remove phrase selection notifier
  PakettiPhraseVoiceRemoveSelectionNotifier()
  
  PakettiPhraseTransportEnabled = false
  PakettiPhraseTransportCurrentSection = 0
  renoise.app():show_status("Phrase Transport: OFF")
end

-- Toggle phrase transport
function PakettiPhraseTransportToggle()
  if PakettiPhraseTransportEnabled then
    PakettiPhraseTransportDisable()
  else
    PakettiPhraseTransportEnable()
  end
end

-- Arm phrase offset (in lines)
function PakettiPhraseTransportArmOffset(offset)
  PakettiPhraseTransportArmedOffset = offset or 0
  renoise.app():show_status(string.format("Phrase Transport Offset: %d lines", PakettiPhraseTransportArmedOffset))
end

-- Clear armed offset
function PakettiPhraseTransportClearOffset()
  PakettiPhraseTransportArmedOffset = 0
  renoise.app():show_status("Phrase Transport Offset: Cleared")
end

--------------------------------------------------------------------------------
-- 2. PHRASE SWITCHER (Note Injection)
--------------------------------------------------------------------------------

-- Get next quantized line based on quantization type
function PakettiPhraseSwitcherGetNextQuantLine(quant_type)
  local song = renoise.song()
  if not song then return 1 end
  
  local transport = song.transport
  local current_line = transport.playback_pos.line
  local lpb = transport.lpb
  local pattern_length = song.selected_pattern.number_of_lines
  
  quant_type = quant_type or PakettiPhraseSwitcherDefaultQuant
  
  if quant_type == "line" then
    -- Immediate: next line
    return math.min(current_line + 1, pattern_length)
    
  elseif quant_type == "beat" then
    -- Next beat boundary (LPB-aligned)
    local next_beat_line = math.ceil(current_line / lpb) * lpb + 1
    if next_beat_line > pattern_length then
      next_beat_line = 1
    end
    return next_beat_line
    
  elseif quant_type == "bar" then
    -- Next bar boundary (4 beats or pattern length)
    local bar_length = lpb * 4
    if bar_length > pattern_length then
      bar_length = pattern_length
    end
    local next_bar_line = math.ceil(current_line / bar_length) * bar_length + 1
    if next_bar_line > pattern_length then
      next_bar_line = 1
    end
    return next_bar_line
    
  elseif quant_type == "custom" then
    -- Custom quantization
    local quant = PakettiPhraseSwitcherCustomQuant
    local next_quant_line = math.ceil(current_line / quant) * quant + 1
    if next_quant_line > pattern_length then
      next_quant_line = 1
    end
    return next_quant_line
    
  else
    return current_line
  end
end

-- Find all tracks using the specified instrument
function PakettiPhraseSwitcherFindInstrumentTracks(instrument_index)
  local song = renoise.song()
  if not song then return {} end
  
  local tracks = {}
  local pattern = song.selected_pattern
  
  for track_index = 1, #song.tracks do
    local track = song.tracks[track_index]
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      local pattern_track = pattern:track(track_index)
      
      -- Check if any line in this track uses the instrument
      for line_index = 1, pattern.number_of_lines do
        local line = pattern_track:line(line_index)
        for col_index = 1, track.visible_note_columns do
          local note_col = line:note_column(col_index)
          if note_col.instrument_value == instrument_index - 1 then
            table.insert(tracks, track_index)
            break
          end
        end
        if #tracks > 0 and tracks[#tracks] == track_index then
          break
        end
      end
    end
  end
  
  -- If no tracks found, use selected track
  if #tracks == 0 then
    local sel_track = song.selected_track
    if sel_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      table.insert(tracks, song.selected_track_index)
    end
  end
  
  return tracks
end

-- Find first empty note column in a line, or create one
function PakettiPhraseSwitcherFindEmptyColumn(track, line)
  for col_index = 1, track.visible_note_columns do
    local note_col = line:note_column(col_index)
    if note_col.is_empty then
      return col_index
    end
  end
  
  -- No empty column, try to add one
  if track.visible_note_columns < 12 then
    track.visible_note_columns = track.visible_note_columns + 1
    return track.visible_note_columns
  end
  
  return 1  -- Fallback to first column
end

-- Core note injection function
function PakettiPhraseSwitcherInject(phrase_index, launch_mode, quant_type)
  local song = renoise.song()
  if not song then return end
  
  local instrument_index = song.selected_instrument_index
  local instrument = song.selected_instrument
  
  if not instrument or #instrument.phrases == 0 then
    renoise.app():show_status("No phrases in selected instrument")
    return
  end
  
  if phrase_index < 1 or phrase_index > #instrument.phrases then
    renoise.app():show_status(string.format("Phrase %02d does not exist", phrase_index))
    return
  end
  
  launch_mode = launch_mode or PakettiPhraseSwitcherDefaultMode
  quant_type = quant_type or PakettiPhraseSwitcherDefaultQuant
  
  -- Get target line
  local target_line = PakettiPhraseSwitcherGetNextQuantLine(quant_type)
  
  -- Find all tracks using this instrument
  local tracks = PakettiPhraseSwitcherFindInstrumentTracks(instrument_index)
  
  local pattern = song.selected_pattern
  local triggers_added = 0
  
  for _, track_index in ipairs(tracks) do
    local track = song.tracks[track_index]
    local pattern_track = pattern:track(track_index)
    local line = pattern_track:line(target_line)
    
    -- Find empty column
    local col_index = PakettiPhraseSwitcherFindEmptyColumn(track, line)
    local note_col = line:note_column(col_index)
    
    -- Write note with phrase program (Zxx command)
    note_col.note_value = 48  -- C-4
    note_col.instrument_value = instrument_index - 1
    
    -- Write Zxx command in effect column if phrase index > 0
    if phrase_index > 0 then
      -- Use sample effect column for Zxx
      track.sample_effects_column_visible = true
      note_col.effect_number_value = 0x23  -- Z command (phrase trigger)
      note_col.effect_amount_value = phrase_index
    end
    
    triggers_added = triggers_added + 1
  end
  
  -- Handle launch mode specific behavior
  if launch_mode == "toggle" then
    local key = instrument_index .. "_" .. phrase_index
    if PakettiPhraseSwitcherActiveStates[key] then
      PakettiPhraseSwitcherActiveStates[key] = nil
      -- Inject note-off on next quantized line
      PakettiPhraseSwitcherInjectNoteOff(instrument_index, quant_type)
    else
      PakettiPhraseSwitcherActiveStates[key] = true
    end
  elseif launch_mode == "oneshot" then
    local key = instrument_index .. "_" .. phrase_index
    if PakettiPhraseSwitcherActiveStates[key] then
      renoise.app():show_status("Phrase already playing (one-shot)")
      return
    end
    PakettiPhraseSwitcherActiveStates[key] = true
  end
  
  -- Build status message with stacker info if applicable
  local status_msg = string.format("Injected Phrase %02d at line %d (%s, %s)", phrase_index, target_line, launch_mode, quant_type)
  
  -- Add stacker info if instrument is velocity-stacked
  if PakettiStackerIsVelocityStacked and PakettiStackerIsVelocityStacked(instrument) then
    local vel_info = nil
    if PakettiStackerGetPhraseVelocityInfo then
      vel_info = PakettiStackerGetPhraseVelocityInfo(instrument, phrase_index)
    end
    if vel_info and #vel_info > 0 then
      if #vel_info == 1 then
        status_msg = status_msg .. string.format(" [Stacked: Vel %02X]", vel_info[1])
      elseif #vel_info <= 3 then
        local vel_strs = {}
        for _, v in ipairs(vel_info) do
          table.insert(vel_strs, string.format("%02X", v))
        end
        status_msg = status_msg .. " [Stacked: Vel " .. table.concat(vel_strs, ",") .. "]"
      else
        status_msg = status_msg .. string.format(" [Stacked: %d velocities]", #vel_info)
      end
    else
      status_msg = status_msg .. " [Stacked instrument]"
    end
  end
  
  renoise.app():show_status(status_msg)
end

-- Inject note-off for stopping phrases
function PakettiPhraseSwitcherInjectNoteOff(instrument_index, quant_type)
  local song = renoise.song()
  if not song then return end
  
  local target_line = PakettiPhraseSwitcherGetNextQuantLine(quant_type)
  local tracks = PakettiPhraseSwitcherFindInstrumentTracks(instrument_index)
  local pattern = song.selected_pattern
  
  for _, track_index in ipairs(tracks) do
    local track = song.tracks[track_index]
    local pattern_track = pattern:track(track_index)
    local line = pattern_track:line(target_line)
    
    local col_index = PakettiPhraseSwitcherFindEmptyColumn(track, line)
    local note_col = line:note_column(col_index)
    
    note_col.note_value = 120  -- OFF
    note_col.instrument_value = instrument_index - 1
  end
end

-- Stop phrase playback for instrument
function PakettiPhraseSwitcherStop(instrument_index)
  local song = renoise.song()
  if not song then
    instrument_index = 1
  else
    instrument_index = instrument_index or song.selected_instrument_index
  end
  
  PakettiPhraseSwitcherInjectNoteOff(instrument_index, PakettiPhraseSwitcherDefaultQuant)
  
  -- Clear active states for this instrument
  local keys_to_remove = {}
  for key, _ in pairs(PakettiPhraseSwitcherActiveStates) do
    if string.match(key, "^" .. instrument_index .. "_") then
      table.insert(keys_to_remove, key)
    end
  end
  for _, key in ipairs(keys_to_remove) do
    PakettiPhraseSwitcherActiveStates[key] = nil
  end
  
  renoise.app():show_status(string.format("Stopped phrases for instrument %02d", instrument_index))
end

-- Set default launch mode
function PakettiPhraseSwitcherSetDefaultMode(mode)
  local valid_modes = {trigger=true, gate=true, toggle=true, oneshot=true, legato=true}
  if valid_modes[mode] then
    PakettiPhraseSwitcherDefaultMode = mode
    renoise.app():show_status("Default Launch Mode: " .. mode)
  else
    renoise.app():show_status("Invalid launch mode: " .. tostring(mode))
  end
end

-- Set default quantization
function PakettiPhraseSwitcherSetDefaultQuant(quant)
  local valid_quants = {line=true, beat=true, bar=true, custom=true}
  if valid_quants[quant] then
    PakettiPhraseSwitcherDefaultQuant = quant
    renoise.app():show_status("Default Quantization: " .. quant)
  else
    renoise.app():show_status("Invalid quantization: " .. tostring(quant))
  end
end

-- Cycle through launch modes
function PakettiPhraseSwitcherCycleLaunchMode()
  local modes = {"trigger", "gate", "toggle", "oneshot", "legato"}
  local current_index = 1
  for i, mode in ipairs(modes) do
    if mode == PakettiPhraseSwitcherDefaultMode then
      current_index = i
      break
    end
  end
  local next_index = (current_index % #modes) + 1
  PakettiPhraseSwitcherSetDefaultMode(modes[next_index])
end

-- Cycle through quantization types
function PakettiPhraseSwitcherCycleQuant()
  local quants = {"line", "beat", "bar", "custom"}
  local current_index = 1
  for i, quant in ipairs(quants) do
    if quant == PakettiPhraseSwitcherDefaultQuant then
      current_index = i
      break
    end
  end
  local next_index = (current_index % #quants) + 1
  PakettiPhraseSwitcherSetDefaultQuant(quants[next_index])
end

--------------------------------------------------------------------------------
-- 3. PHRASEGRID (Scene System)
--------------------------------------------------------------------------------

-- Auto-restore sequencer states on recall option
PakettiPhraseGridAutoRestoreSequencers = true

-- Initialize empty state
function PakettiPhraseGridCreateEmptyState()
  return {
    name = "",
    phrases = {},           -- [instrument_index] = phrase_index (legacy single-phrase mode)
    pattern_index = nil,    -- Optional automation binding
    follow_action = nil,    -- Follow action config
    group = nil,            -- Mute group index
    launch_mode = "trigger",
    -- Step sequencer snapshots
    eight_one_twenty = nil, -- 8120 checkbox state snapshot
    gater = nil,            -- Gater checkbox state snapshot
    slice_step = nil,       -- SliceStepSequencer checkbox state snapshot
    -- Voice Orchestration (NEW)
    phrase_voices = {},     -- Array of voice configs: {phrase_index, phase_locked, track_or_column}
    voice_output_mode = nil, -- "track" or "column" (nil = use global default)
    voice_quantization = nil -- Quantization lines override (nil = use global default)
  }
end

--------------------------------------------------------------------------------
-- PHRASE VOICE STATE MANAGEMENT
-- Save and recall multi-voice configurations as PhraseGrid states
--------------------------------------------------------------------------------

-- Save current active voices as a PhraseGrid state
function PakettiPhraseVoiceStateSave(state_index, name)
  local song = renoise.song()
  if not song then return false end
  
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    renoise.app():show_status(string.format("Invalid state index: %d", state_index))
    return false
  end
  
  -- Create state if it doesn't exist
  if not PakettiPhraseGridStates[state_index] then
    PakettiPhraseGridStates[state_index] = PakettiPhraseGridCreateEmptyState()
  end
  
  local state = PakettiPhraseGridStates[state_index]
  state.name = name or string.format("Voice State %02d", state_index)
  
  -- Clear existing voice data
  state.phrase_voices = {}
  
  -- Save all active voices
  for _, voice in ipairs(PakettiPhraseVoicePool) do
    if voice.active then
      table.insert(state.phrase_voices, {
        instrument_index = voice.instrument_index,
        phrase_index = voice.phrase_index,
        phase_locked = voice.phase_locked,
        track_or_column = PakettiPhraseVoiceOutputMode == "track" and voice.track_index or voice.column_index
      })
    end
  end
  
  -- Save current output mode and quantization
  state.voice_output_mode = PakettiPhraseVoiceOutputMode
  state.voice_quantization = PakettiPhraseSwitcherCustomQuant
  
  PakettiPhraseGridCurrentState = state_index
  
  renoise.app():show_status(string.format("Saved %d phrase voice(s) to State %02d", 
    #state.phrase_voices, state_index))
  
  return true
end

-- Recall voices from a PhraseGrid state
function PakettiPhraseVoiceStateRecall(state_index, options)
  local song = renoise.song()
  if not song then return false end
  
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    renoise.app():show_status(string.format("Invalid state index: %d", state_index))
    return false
  end
  
  local state = PakettiPhraseGridStates[state_index]
  if not state then
    renoise.app():show_status(string.format("State %02d is empty", state_index))
    return false
  end
  
  options = options or {}
  
  -- Additive mode: never clear existing voices
  -- Otherwise respect the option (default true = clear)
  local clear_existing = not PakettiPhraseVoiceAdditiveMode and (options.clear_existing ~= false)
  
  -- Clear existing voices if requested and not in additive mode
  if clear_existing then
    PakettiPhraseVoiceKillAll()
    PakettiPhraseVoiceDebugLog("State recall: cleared existing voices")
  else
    PakettiPhraseVoiceDebugLog("State recall: additive mode - keeping existing voices")
  end
  
  -- Apply saved output mode and quantization if stored
  if state.voice_output_mode then
    PakettiPhraseVoiceOutputMode = state.voice_output_mode
  end
  if state.voice_quantization then
    PakettiPhraseSwitcherCustomQuant = state.voice_quantization
  end
  
  local spawned = 0
  
  -- Check if state has voice data (new format) or legacy phrase data
  if state.phrase_voices and #state.phrase_voices > 0 then
    -- New format: spawn multi-voice configuration
    for _, voice_config in ipairs(state.phrase_voices) do
      local spawn_options = {
        instrument_index = voice_config.instrument_index,
        phase_locked = voice_config.phase_locked
      }
      
      local voice = PakettiPhraseVoiceSwitcherModeSpawn(voice_config.phrase_index, spawn_options)
      if voice then
        spawned = spawned + 1
      end
    end
  elseif state.phrases and next(state.phrases) then
    -- Legacy format: convert single-phrase-per-instrument to voices
    for inst_index, phrase_index in pairs(state.phrases) do
      local spawn_options = {
        instrument_index = inst_index,
        phase_locked = PakettiPhraseVoicePhaseLockEnabled
      }
      
      local voice = PakettiPhraseVoiceSwitcherModeSpawn(phrase_index, spawn_options)
      if voice then
        spawned = spawned + 1
      end
    end
  end
  
  PakettiPhraseGridCurrentState = state_index
  
  renoise.app():show_status(string.format("Recalled %d phrase voice(s) from State %02d: %s", 
    spawned, state_index, state.name or ""))
  
  return true
end

-- Merge voices from state (additive, doesn't clear existing)
function PakettiPhraseVoiceStateMerge(state_index)
  return PakettiPhraseVoiceStateRecall(state_index, {clear_existing = false})
end

-- Quick recall functions for keybindings
function PakettiPhraseVoiceStateRecall01() PakettiPhraseVoiceStateRecall(1) end
function PakettiPhraseVoiceStateRecall02() PakettiPhraseVoiceStateRecall(2) end
function PakettiPhraseVoiceStateRecall03() PakettiPhraseVoiceStateRecall(3) end
function PakettiPhraseVoiceStateRecall04() PakettiPhraseVoiceStateRecall(4) end
function PakettiPhraseVoiceStateRecall05() PakettiPhraseVoiceStateRecall(5) end
function PakettiPhraseVoiceStateRecall06() PakettiPhraseVoiceStateRecall(6) end
function PakettiPhraseVoiceStateRecall07() PakettiPhraseVoiceStateRecall(7) end
function PakettiPhraseVoiceStateRecall08() PakettiPhraseVoiceStateRecall(8) end
function PakettiPhraseVoiceStateRecall09() PakettiPhraseVoiceStateRecall(9) end
function PakettiPhraseVoiceStateRecall10() PakettiPhraseVoiceStateRecall(10) end
function PakettiPhraseVoiceStateRecall11() PakettiPhraseVoiceStateRecall(11) end
function PakettiPhraseVoiceStateRecall12() PakettiPhraseVoiceStateRecall(12) end
function PakettiPhraseVoiceStateRecall13() PakettiPhraseVoiceStateRecall(13) end
function PakettiPhraseVoiceStateRecall14() PakettiPhraseVoiceStateRecall(14) end
function PakettiPhraseVoiceStateRecall15() PakettiPhraseVoiceStateRecall(15) end
function PakettiPhraseVoiceStateRecall16() PakettiPhraseVoiceStateRecall(16) end

-- Quick save functions for keybindings
function PakettiPhraseVoiceStateSave01() PakettiPhraseVoiceStateSave(1) end
function PakettiPhraseVoiceStateSave02() PakettiPhraseVoiceStateSave(2) end
function PakettiPhraseVoiceStateSave03() PakettiPhraseVoiceStateSave(3) end
function PakettiPhraseVoiceStateSave04() PakettiPhraseVoiceStateSave(4) end
function PakettiPhraseVoiceStateSave05() PakettiPhraseVoiceStateSave(5) end
function PakettiPhraseVoiceStateSave06() PakettiPhraseVoiceStateSave(6) end
function PakettiPhraseVoiceStateSave07() PakettiPhraseVoiceStateSave(7) end
function PakettiPhraseVoiceStateSave08() PakettiPhraseVoiceStateSave(8) end

-- Store current phrase selections as a state
function PakettiPhraseGridStore(state_index, name)
  local song = renoise.song()
  if not song then return end
  
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    renoise.app():show_status(string.format("Invalid state index: %d", state_index))
    return
  end
  
  local state = PakettiPhraseGridCreateEmptyState()
  state.name = name or string.format("State %02d", state_index)
  
  -- Store phrase selections for all instruments that have phrases
  for inst_index = 1, #song.instruments do
    local instrument = song.instruments[inst_index]
    if #instrument.phrases > 0 then
      -- Store the currently selected phrase for this instrument
      if inst_index == song.selected_instrument_index then
        local phrase_index = song.selected_phrase_index
        if phrase_index > 0 then
          state.phrases[inst_index] = phrase_index
        end
      end
    end
  end
  
  -- Store current pattern index for automation binding
  state.pattern_index = song.selected_sequence_index
  
  -- Capture step sequencer snapshots if they're available
  if PakettiEightOneTwentyGetFullSnapshot then
    state.eight_one_twenty = PakettiEightOneTwentyGetFullSnapshot()
  end
  
  if PakettiGaterGetSnapshot then
    state.gater = PakettiGaterGetSnapshot()
  end
  
  if PakettiSliceStepGetSnapshot then
    state.slice_step = PakettiSliceStepGetSnapshot()
  end
  
  PakettiPhraseGridStates[state_index] = state
  PakettiPhraseGridCurrentState = state_index
  
  local snapshot_info = ""
  if state.eight_one_twenty then snapshot_info = snapshot_info .. " +8120" end
  if state.gater then snapshot_info = snapshot_info .. " +Gater" end
  if state.slice_step then snapshot_info = snapshot_info .. " +SliceStep" end
  
  renoise.app():show_status(string.format("Stored PhraseGrid State %02d: %s%s", state_index, state.name, snapshot_info))
end

-- Store only 8120 snapshot to a state (without overwriting phrase data)
function PakettiPhraseGridSnapshot8120ToState(state_index)
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    renoise.app():show_status(string.format("Invalid state index: %d", state_index))
    return
  end
  
  -- Create state if it doesn't exist
  if not PakettiPhraseGridStates[state_index] then
    PakettiPhraseGridStates[state_index] = PakettiPhraseGridCreateEmptyState()
    PakettiPhraseGridStates[state_index].name = string.format("State %02d", state_index)
  end
  
  -- Capture 8120 snapshot
  if PakettiEightOneTwentyGetFullSnapshot then
    PakettiPhraseGridStates[state_index].eight_one_twenty = PakettiEightOneTwentyGetFullSnapshot()
    renoise.app():show_status(string.format("Stored 8120 snapshot to State %02d", state_index))
  else
    renoise.app():show_status("8120 not available - open the dialog first")
  end
end

-- Store only Gater snapshot to a state (without overwriting phrase data)
function PakettiPhraseGridSnapshotGaterToState(state_index)
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    renoise.app():show_status(string.format("Invalid state index: %d", state_index))
    return
  end
  
  -- Create state if it doesn't exist
  if not PakettiPhraseGridStates[state_index] then
    PakettiPhraseGridStates[state_index] = PakettiPhraseGridCreateEmptyState()
    PakettiPhraseGridStates[state_index].name = string.format("State %02d", state_index)
  end
  
  -- Capture Gater snapshot
  if PakettiGaterGetSnapshot then
    PakettiPhraseGridStates[state_index].gater = PakettiGaterGetSnapshot()
    renoise.app():show_status(string.format("Stored Gater snapshot to State %02d", state_index))
  else
    renoise.app():show_status("Gater not available - open the dialog first")
  end
end

-- Store only SliceStep snapshot to a state (without overwriting phrase data)
function PakettiPhraseGridSnapshotSliceStepToState(state_index)
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    renoise.app():show_status(string.format("Invalid state index: %d", state_index))
    return
  end
  
  -- Create state if it doesn't exist
  if not PakettiPhraseGridStates[state_index] then
    PakettiPhraseGridStates[state_index] = PakettiPhraseGridCreateEmptyState()
    PakettiPhraseGridStates[state_index].name = string.format("State %02d", state_index)
  end
  
  -- Capture SliceStep snapshot
  if PakettiSliceStepGetSnapshot then
    PakettiPhraseGridStates[state_index].slice_step = PakettiSliceStepGetSnapshot()
    renoise.app():show_status(string.format("Stored SliceStep snapshot to State %02d", state_index))
  else
    renoise.app():show_status("SliceStep not available - open the dialog first")
  end
end

-- Store all sequencer snapshots to a state
function PakettiPhraseGridSnapshotAllSequencersToState(state_index)
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    renoise.app():show_status(string.format("Invalid state index: %d", state_index))
    return
  end
  
  -- Create state if it doesn't exist
  if not PakettiPhraseGridStates[state_index] then
    PakettiPhraseGridStates[state_index] = PakettiPhraseGridCreateEmptyState()
    PakettiPhraseGridStates[state_index].name = string.format("State %02d", state_index)
  end
  
  local stored = {}
  
  -- Capture 8120 snapshot
  if PakettiEightOneTwentyGetFullSnapshot then
    PakettiPhraseGridStates[state_index].eight_one_twenty = PakettiEightOneTwentyGetFullSnapshot()
    table.insert(stored, "8120")
  end
  
  -- Capture Gater snapshot
  if PakettiGaterGetSnapshot then
    PakettiPhraseGridStates[state_index].gater = PakettiGaterGetSnapshot()
    table.insert(stored, "Gater")
  end
  
  -- Capture SliceStep snapshot
  if PakettiSliceStepGetSnapshot then
    PakettiPhraseGridStates[state_index].slice_step = PakettiSliceStepGetSnapshot()
    table.insert(stored, "SliceStep")
  end
  
  if #stored > 0 then
    renoise.app():show_status(string.format("Stored %s to State %02d", table.concat(stored, ", "), state_index))
  else
    renoise.app():show_status("No sequencers available to snapshot")
  end
end

-- Recall a stored state
function PakettiPhraseGridRecall(state_index)
  local song = renoise.song()
  if not song then return end
  
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    renoise.app():show_status(string.format("Invalid state index: %d", state_index))
    return
  end
  
  local state = PakettiPhraseGridStates[state_index]
  if not state then
    renoise.app():show_status(string.format("State %02d is empty", state_index))
    return
  end
  
  -- Handle mute groups - stop other states in same group
  if state.group then
    PakettiPhraseGroupMuteOthers(state.group, state_index)
  end
  
  -- Switch to pattern if automation binding exists
  if state.pattern_index and state.pattern_index <= #song.sequencer.pattern_sequence then
    song.selected_sequence_index = state.pattern_index
  end
  
  -- Inject phrase triggers for all stored phrases
  for inst_index, phrase_index in pairs(state.phrases) do
    if inst_index <= #song.instruments then
      local instrument = song.instruments[inst_index]
      if phrase_index <= #instrument.phrases then
        -- Temporarily select this instrument and inject
        local prev_inst = song.selected_instrument_index
        song.selected_instrument_index = inst_index
        PakettiPhraseSwitcherInject(phrase_index, state.launch_mode, PakettiPhraseSwitcherDefaultQuant)
        song.selected_instrument_index = prev_inst
      end
    end
  end
  
  -- Restore step sequencer states if auto-restore is enabled
  local restored = {}
  if PakettiPhraseGridAutoRestoreSequencers then
    if state.eight_one_twenty and PakettiEightOneTwentyRestoreFromFullSnapshot then
      PakettiEightOneTwentyRestoreFromFullSnapshot(state.eight_one_twenty)
      table.insert(restored, "8120")
    end
    
    if state.gater and PakettiGaterRestoreFromSnapshot then
      PakettiGaterRestoreFromSnapshot(state.gater)
      table.insert(restored, "Gater")
    end
    
    if state.slice_step and PakettiSliceStepRestoreFromSnapshot then
      PakettiSliceStepRestoreFromSnapshot(state.slice_step)
      table.insert(restored, "SliceStep")
    end
  end
  
  PakettiPhraseGridCurrentState = state_index
  
  -- Initialize follow action loop counter
  PakettiPhraseFollowActionLoopCount[state_index] = 0
  
  local restore_info = ""
  if #restored > 0 then
    restore_info = " [Restored: " .. table.concat(restored, ", ") .. "]"
  end
  
  renoise.app():show_status(string.format("Recalled PhraseGrid State %02d: %s%s", state_index, state.name, restore_info))
end

-- Recall only the 8120 snapshot from a state
function PakettiPhraseGridRestore8120FromState(state_index)
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    renoise.app():show_status(string.format("Invalid state index: %d", state_index))
    return
  end
  
  local state = PakettiPhraseGridStates[state_index]
  if not state or not state.eight_one_twenty then
    renoise.app():show_status(string.format("State %02d has no 8120 snapshot", state_index))
    return
  end
  
  if PakettiEightOneTwentyRestoreFromFullSnapshot then
    PakettiEightOneTwentyRestoreFromFullSnapshot(state.eight_one_twenty)
    renoise.app():show_status(string.format("Restored 8120 from State %02d", state_index))
  else
    renoise.app():show_status("8120 restore function not available")
  end
end

-- Recall only the Gater snapshot from a state
function PakettiPhraseGridRestoreGaterFromState(state_index)
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    renoise.app():show_status(string.format("Invalid state index: %d", state_index))
    return
  end
  
  local state = PakettiPhraseGridStates[state_index]
  if not state or not state.gater then
    renoise.app():show_status(string.format("State %02d has no Gater snapshot", state_index))
    return
  end
  
  if PakettiGaterRestoreFromSnapshot then
    PakettiGaterRestoreFromSnapshot(state.gater)
    renoise.app():show_status(string.format("Restored Gater from State %02d", state_index))
  else
    renoise.app():show_status("Gater restore function not available")
  end
end

-- Recall only the SliceStep snapshot from a state
function PakettiPhraseGridRestoreSliceStepFromState(state_index)
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    renoise.app():show_status(string.format("Invalid state index: %d", state_index))
    return
  end
  
  local state = PakettiPhraseGridStates[state_index]
  if not state or not state.slice_step then
    renoise.app():show_status(string.format("State %02d has no SliceStep snapshot", state_index))
    return
  end
  
  if PakettiSliceStepRestoreFromSnapshot then
    PakettiSliceStepRestoreFromSnapshot(state.slice_step)
    renoise.app():show_status(string.format("Restored SliceStep from State %02d", state_index))
  else
    renoise.app():show_status("SliceStep restore function not available")
  end
end

-- Toggle auto-restore sequencers on recall
function PakettiPhraseGridToggleAutoRestoreSequencers()
  PakettiPhraseGridAutoRestoreSequencers = not PakettiPhraseGridAutoRestoreSequencers
  local status = PakettiPhraseGridAutoRestoreSequencers and "enabled" or "disabled"
  renoise.app():show_status("PhraseGrid auto-restore sequencers: " .. status)
end

-- Clear a stored state
function PakettiPhraseGridClear(state_index)
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    renoise.app():show_status(string.format("Invalid state index: %d", state_index))
    return
  end
  
  PakettiPhraseGridStates[state_index] = nil
  
  if PakettiPhraseGridCurrentState == state_index then
    PakettiPhraseGridCurrentState = 0
  end
  
  renoise.app():show_status(string.format("Cleared PhraseGrid State %02d", state_index))
end

-- Clear all states
function PakettiPhraseGridClearAll()
  PakettiPhraseGridStates = {}
  PakettiPhraseGridCurrentState = 0
  PakettiPhraseFollowActionLoopCount = {}
  renoise.app():show_status("Cleared all PhraseGrid States")
end

-- Set phrase for instrument in state
function PakettiPhraseGridSetPhrase(state_index, instrument_index, phrase_index)
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    return
  end
  
  if not PakettiPhraseGridStates[state_index] then
    PakettiPhraseGridStates[state_index] = PakettiPhraseGridCreateEmptyState()
    PakettiPhraseGridStates[state_index].name = string.format("State %02d", state_index)
  end
  
  PakettiPhraseGridStates[state_index].phrases[instrument_index] = phrase_index
end

-- Set follow action for state
function PakettiPhraseGridSetFollowAction(state_index, action_config)
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    return
  end
  
  if not PakettiPhraseGridStates[state_index] then
    return
  end
  
  PakettiPhraseGridStates[state_index].follow_action = action_config
end

-- Set group for state
function PakettiPhraseGridSetGroup(state_index, group_index)
  if state_index < 1 or state_index > PakettiPhraseGridMaxStates then
    return
  end
  
  if not PakettiPhraseGridStates[state_index] then
    return
  end
  
  PakettiPhraseGridStates[state_index].group = group_index
  
  -- Also update group definition
  if group_index then
    if not PakettiPhraseGridGroups[group_index] then
      PakettiPhraseGridGroups[group_index] = {name = string.format("Group %d", group_index), states = {}}
    end
    -- Add state to group if not already there
    local found = false
    for _, s in ipairs(PakettiPhraseGridGroups[group_index].states) do
      if s == state_index then
        found = true
        break
      end
    end
    if not found then
      table.insert(PakettiPhraseGridGroups[group_index].states, state_index)
    end
  end
end

-- Get state info
function PakettiPhraseGridGetState(state_index)
  return PakettiPhraseGridStates[state_index]
end

-- Get current state index
function PakettiPhraseGridGetCurrentState()
  return PakettiPhraseGridCurrentState
end

--------------------------------------------------------------------------------
-- 4. FOLLOW ACTIONS
--------------------------------------------------------------------------------

-- Create default follow action config
function PakettiPhraseFollowActionCreateConfig()
  return {
    enabled = false,
    after_loops = 1,       -- Trigger after N phrase loops
    action_a = "next",     -- Primary action
    action_b = "stop",     -- Secondary action
    chance_a = 100,        -- Probability for action A (0-100)
    chance_b = 0           -- Probability for action B
  }
end

-- Enable follow action for state
function PakettiPhraseFollowActionEnable(state_index)
  if not PakettiPhraseGridStates[state_index] then
    return
  end
  
  if not PakettiPhraseGridStates[state_index].follow_action then
    PakettiPhraseGridStates[state_index].follow_action = PakettiPhraseFollowActionCreateConfig()
  end
  
  PakettiPhraseGridStates[state_index].follow_action.enabled = true
  renoise.app():show_status(string.format("Follow Action enabled for State %02d", state_index))
end

-- Disable follow action for state
function PakettiPhraseFollowActionDisable(state_index)
  if not PakettiPhraseGridStates[state_index] then
    return
  end
  
  if PakettiPhraseGridStates[state_index].follow_action then
    PakettiPhraseGridStates[state_index].follow_action.enabled = false
  end
  
  renoise.app():show_status(string.format("Follow Action disabled for State %02d", state_index))
end

-- Set follow action config
function PakettiPhraseFollowActionSet(state_index, config)
  if not PakettiPhraseGridStates[state_index] then
    return
  end
  
  PakettiPhraseGridStates[state_index].follow_action = config
end

-- Check for phrase loop and process follow actions
function PakettiPhraseFollowActionCheckLoop(current_line, phrase_length)
  if PakettiPhraseGridCurrentState == 0 then return end
  
  local state = PakettiPhraseGridStates[PakettiPhraseGridCurrentState]
  if not state then return end
  if not state.follow_action then return end
  if not state.follow_action.enabled then return end
  
  -- Detect loop (line 1 after being at end)
  if current_line == 1 then
    local loop_count = PakettiPhraseFollowActionLoopCount[PakettiPhraseGridCurrentState] or 0
    loop_count = loop_count + 1
    PakettiPhraseFollowActionLoopCount[PakettiPhraseGridCurrentState] = loop_count
    
    -- Check if we've reached the trigger point
    if loop_count >= state.follow_action.after_loops then
      PakettiPhraseFollowActionProcess(PakettiPhraseGridCurrentState)
      PakettiPhraseFollowActionLoopCount[PakettiPhraseGridCurrentState] = 0
    end
  end
end

-- Process follow action for state
function PakettiPhraseFollowActionProcess(state_index)
  local state = PakettiPhraseGridStates[state_index]
  if not state or not state.follow_action then return end
  
  local config = state.follow_action
  
  -- Determine which action to take based on probability
  trueRandomSeed()
  local roll = math.random(1, 100)
  local action = nil
  
  if roll <= config.chance_a then
    action = config.action_a
  elseif roll <= config.chance_a + config.chance_b then
    action = config.action_b
  else
    -- No action (remaining probability)
    return
  end
  
  -- Execute the action
  PakettiPhraseFollowActionExecute(action, state_index)
end

-- Execute a follow action
function PakettiPhraseFollowActionExecute(action, current_state_index)
  if action == "stop" then
    -- Stop all phrases
    local song = renoise.song()
    if song then
      PakettiPhraseSwitcherStop(song.selected_instrument_index)
    end
    PakettiPhraseGridCurrentState = 0
    
  elseif action == "next" then
    -- Play next state
    local next_state = current_state_index + 1
    if next_state > PakettiPhraseGridMaxStates or not PakettiPhraseGridStates[next_state] then
      next_state = 1
    end
    -- Find next valid state
    local start = next_state
    while not PakettiPhraseGridStates[next_state] do
      next_state = next_state + 1
      if next_state > PakettiPhraseGridMaxStates then
        next_state = 1
      end
      if next_state == start then
        return  -- No valid states
      end
    end
    PakettiPhraseGridRecall(next_state)
    
  elseif action == "previous" then
    -- Play previous state
    local prev_state = current_state_index - 1
    if prev_state < 1 then
      prev_state = PakettiPhraseGridMaxStates
    end
    -- Find previous valid state
    local start = prev_state
    while not PakettiPhraseGridStates[prev_state] do
      prev_state = prev_state - 1
      if prev_state < 1 then
        prev_state = PakettiPhraseGridMaxStates
      end
      if prev_state == start then
        return  -- No valid states
      end
    end
    PakettiPhraseGridRecall(prev_state)
    
  elseif action == "first" then
    -- Play first state
    for i = 1, PakettiPhraseGridMaxStates do
      if PakettiPhraseGridStates[i] then
        PakettiPhraseGridRecall(i)
        return
      end
    end
    
  elseif action == "last" then
    -- Play last state
    for i = PakettiPhraseGridMaxStates, 1, -1 do
      if PakettiPhraseGridStates[i] then
        PakettiPhraseGridRecall(i)
        return
      end
    end
    
  elseif action == "random" then
    -- Play random state (including current)
    local valid_states = {}
    for i = 1, PakettiPhraseGridMaxStates do
      if PakettiPhraseGridStates[i] then
        table.insert(valid_states, i)
      end
    end
    if #valid_states > 0 then
      trueRandomSeed()
      local random_index = valid_states[math.random(1, #valid_states)]
      PakettiPhraseGridRecall(random_index)
    end
    
  elseif action == "random_other" then
    -- Play random state (excluding current)
    local valid_states = {}
    for i = 1, PakettiPhraseGridMaxStates do
      if PakettiPhraseGridStates[i] and i ~= current_state_index then
        table.insert(valid_states, i)
      end
    end
    if #valid_states > 0 then
      trueRandomSeed()
      local random_index = valid_states[math.random(1, #valid_states)]
      PakettiPhraseGridRecall(random_index)
    end
    
  elseif type(action) == "number" then
    -- Jump to specific state
    if PakettiPhraseGridStates[action] then
      PakettiPhraseGridRecall(action)
    end
  end
end

--------------------------------------------------------------------------------
-- 5. PHRASE GROUPS (Mute Groups)
--------------------------------------------------------------------------------

-- Create a new phrase group
function PakettiPhraseGroupCreate(name)
  local group_index = nil
  
  -- Find first empty slot
  for i = 1, PakettiPhraseGridMaxGroups do
    if not PakettiPhraseGridGroups[i] then
      group_index = i
      break
    end
  end
  
  if not group_index then
    renoise.app():show_status("Maximum groups reached")
    return nil
  end
  
  PakettiPhraseGridGroups[group_index] = {
    name = name or string.format("Group %d", group_index),
    states = {}
  }
  
  renoise.app():show_status(string.format("Created Group %d: %s", group_index, PakettiPhraseGridGroups[group_index].name))
  return group_index
end

-- Add state to group
function PakettiPhraseGroupAdd(group_index, state_index)
  if not PakettiPhraseGridGroups[group_index] then
    renoise.app():show_status(string.format("Group %d does not exist", group_index))
    return
  end
  
  -- Check if already in group
  for _, s in ipairs(PakettiPhraseGridGroups[group_index].states) do
    if s == state_index then
      return  -- Already in group
    end
  end
  
  table.insert(PakettiPhraseGridGroups[group_index].states, state_index)
  
  -- Also set group on state
  if PakettiPhraseGridStates[state_index] then
    PakettiPhraseGridStates[state_index].group = group_index
  end
  
  renoise.app():show_status(string.format("Added State %02d to Group %d", state_index, group_index))
end

-- Remove state from group
function PakettiPhraseGroupRemove(group_index, state_index)
  if not PakettiPhraseGridGroups[group_index] then
    return
  end
  
  for i, s in ipairs(PakettiPhraseGridGroups[group_index].states) do
    if s == state_index then
      table.remove(PakettiPhraseGridGroups[group_index].states, i)
      break
    end
  end
  
  -- Also clear group on state
  if PakettiPhraseGridStates[state_index] then
    PakettiPhraseGridStates[state_index].group = nil
  end
end

-- Mute other states in the same group
function PakettiPhraseGroupMuteOthers(group_index, active_state)
  if not PakettiPhraseGridGroups[group_index] then
    return
  end
  
  local song = renoise.song()
  if not song then return end
  
  for _, state_index in ipairs(PakettiPhraseGridGroups[group_index].states) do
    if state_index ~= active_state then
      local state = PakettiPhraseGridStates[state_index]
      if state then
        -- Stop phrases for instruments in this state
        for inst_index, _ in pairs(state.phrases) do
          if inst_index <= #song.instruments then
            -- Inject note-off
            local prev_inst = song.selected_instrument_index
            song.selected_instrument_index = inst_index
            PakettiPhraseSwitcherInjectNoteOff(inst_index, "line")
            song.selected_instrument_index = prev_inst
          end
        end
      end
    end
  end
end

-- Delete a group
function PakettiPhraseGroupDelete(group_index)
  if not PakettiPhraseGridGroups[group_index] then
    return
  end
  
  -- Clear group reference from all states
  for _, state_index in ipairs(PakettiPhraseGridGroups[group_index].states) do
    if PakettiPhraseGridStates[state_index] then
      PakettiPhraseGridStates[state_index].group = nil
    end
  end
  
  PakettiPhraseGridGroups[group_index] = nil
  renoise.app():show_status(string.format("Deleted Group %d", group_index))
end

--------------------------------------------------------------------------------
-- 6. PHRASE BANKS
--------------------------------------------------------------------------------

-- Create a new phrase bank
function PakettiPhraseBankCreate(instrument_index, name)
  local song = renoise.song()
  if not song then return nil end
  
  instrument_index = instrument_index or song.selected_instrument_index
  
  local bank_index = nil
  
  -- Find first empty slot
  for i = 1, PakettiPhraseBankMaxBanks do
    if not PakettiPhraseBanks[i] then
      bank_index = i
      break
    end
  end
  
  if not bank_index then
    renoise.app():show_status("Maximum banks reached")
    return nil
  end
  
  local instrument = song.instruments[instrument_index]
  if not instrument then
    renoise.app():show_status("Invalid instrument")
    return nil
  end
  
  -- Create bank with first 8 phrases (or available)
  local phrases = {}
  for i = 1, PakettiPhraseBankSlotsPerBank do
    if i <= #instrument.phrases then
      phrases[i] = i
    else
      phrases[i] = nil
    end
  end
  
  PakettiPhraseBanks[bank_index] = {
    name = name or string.format("Bank %s", string.char(64 + bank_index)),  -- A, B, C...
    instrument_index = instrument_index,
    phrases = phrases
  }
  
  renoise.app():show_status(string.format("Created Phrase Bank %d: %s", bank_index, PakettiPhraseBanks[bank_index].name))
  return bank_index
end

-- Select a phrase bank
function PakettiPhraseBankSelect(bank_index)
  if bank_index < 1 or bank_index > PakettiPhraseBankMaxBanks then
    renoise.app():show_status(string.format("Invalid bank index: %d", bank_index))
    return
  end
  
  if not PakettiPhraseBanks[bank_index] then
    renoise.app():show_status(string.format("Bank %d is empty", bank_index))
    return
  end
  
  PakettiPhraseBankCurrent = bank_index
  renoise.app():show_status(string.format("Selected Bank %d: %s", bank_index, PakettiPhraseBanks[bank_index].name))
end

-- Select next bank
function PakettiPhraseBankNext()
  local next_bank = PakettiPhraseBankCurrent + 1
  if next_bank > PakettiPhraseBankMaxBanks then
    next_bank = 1
  end
  
  -- Find next valid bank
  local start = next_bank
  while not PakettiPhraseBanks[next_bank] do
    next_bank = next_bank + 1
    if next_bank > PakettiPhraseBankMaxBanks then
      next_bank = 1
    end
    if next_bank == start then
      renoise.app():show_status("No banks available")
      return
    end
  end
  
  PakettiPhraseBankSelect(next_bank)
end

-- Select previous bank
function PakettiPhraseBankPrevious()
  local prev_bank = PakettiPhraseBankCurrent - 1
  if prev_bank < 1 then
    prev_bank = PakettiPhraseBankMaxBanks
  end
  
  -- Find previous valid bank
  local start = prev_bank
  while not PakettiPhraseBanks[prev_bank] do
    prev_bank = prev_bank - 1
    if prev_bank < 1 then
      prev_bank = PakettiPhraseBankMaxBanks
    end
    if prev_bank == start then
      renoise.app():show_status("No banks available")
      return
    end
  end
  
  PakettiPhraseBankSelect(prev_bank)
end

-- Get phrase from current bank slot
function PakettiPhraseBankGetPhrase(slot)
  if slot < 1 or slot > PakettiPhraseBankSlotsPerBank then
    return nil
  end
  
  local bank = PakettiPhraseBanks[PakettiPhraseBankCurrent]
  if not bank then
    return nil
  end
  
  return bank.phrases[slot]
end

-- Trigger phrase from bank slot
function PakettiPhraseBankTriggerSlot(slot)
  local phrase_index = PakettiPhraseBankGetPhrase(slot)
  if phrase_index then
    PakettiPhraseSwitcherInject(phrase_index, PakettiPhraseSwitcherDefaultMode, PakettiPhraseSwitcherDefaultQuant)
  else
    renoise.app():show_status(string.format("Bank slot %d is empty", slot))
  end
end

-- Set phrase in bank slot
function PakettiPhraseBankSetSlot(bank_index, slot, phrase_index)
  if not PakettiPhraseBanks[bank_index] then
    return
  end
  
  if slot < 1 or slot > PakettiPhraseBankSlotsPerBank then
    return
  end
  
  PakettiPhraseBanks[bank_index].phrases[slot] = phrase_index
end

-- Delete a bank
function PakettiPhraseBankDelete(bank_index)
  if not PakettiPhraseBanks[bank_index] then
    return
  end
  
  PakettiPhraseBanks[bank_index] = nil
  
  if PakettiPhraseBankCurrent == bank_index then
    PakettiPhraseBankCurrent = 1
  end
  
  renoise.app():show_status(string.format("Deleted Bank %d", bank_index))
end

--------------------------------------------------------------------------------
-- 7. PHRASE TEMPLATES
--------------------------------------------------------------------------------

-- Create phrase from template
function PakettiPhraseTemplateCreate(template_type, options)
  local song = renoise.song()
  if not song then return nil end
  
  options = options or {}
  local instrument = song.selected_instrument
  
  -- Create new phrase
  local phrase_count = #instrument.phrases
  local new_phrase_index = phrase_count + 1
  instrument:insert_phrase_at(new_phrase_index)
  song.selected_phrase_index = new_phrase_index
  
  local phrase = song.selected_phrase
  
  -- Apply template settings
  if template_type == "empty" then
    phrase.number_of_lines = options.length or 16
    phrase.lpb = options.lpb or song.transport.lpb
    phrase.name = options.name or string.format("Empty %d", new_phrase_index)
    
  elseif template_type == "beat_grid" then
    local grid_size = options.grid_size or 16
    phrase.number_of_lines = grid_size
    phrase.lpb = options.lpb or song.transport.lpb
    phrase.name = string.format("Beat Grid %d", grid_size)
    
    -- Add note on first beat
    if options.add_trigger then
      local line = phrase:line(1)
      local note_col = line:note_column(1)
      note_col.note_value = 48  -- C-4
      note_col.instrument_value = song.selected_instrument_index - 1
    end
    
  elseif template_type == "sliced" then
    PakettiPhraseTemplateFromSlices()
    return new_phrase_index
    
  elseif template_type == "drum" then
    PakettiPhraseTemplateDrum(options.pattern_preset or "basic")
    return new_phrase_index
    
  elseif template_type == "arp" then
    PakettiPhraseTemplateArp(options.direction or "ascending", options.range or 12)
    return new_phrase_index
  end
  
  renoise.app():show_status(string.format("Created phrase template: %s", template_type))
  return new_phrase_index
end

-- Create phrase from instrument slice markers
function PakettiPhraseTemplateFromSlices()
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  if #instrument.samples == 0 then
    renoise.app():show_status("No samples in instrument")
    return
  end
  
  local first_sample = instrument.samples[1]
  if #first_sample.slice_markers == 0 then
    renoise.app():show_status("No slice markers in first sample")
    return
  end
  
  local slice_count = #first_sample.slice_markers
  
  -- Create new phrase
  local phrase_count = #instrument.phrases
  local new_phrase_index = phrase_count + 1
  instrument:insert_phrase_at(new_phrase_index)
  song.selected_phrase_index = new_phrase_index
  
  local phrase = song.selected_phrase
  phrase.number_of_lines = slice_count
  phrase.name = "Slices"
  
  -- Get base note for slices
  local base_note = 48  -- C-4 default
  local sample_mappings = instrument.sample_mappings[1]
  if sample_mappings and #sample_mappings >= 2 then
    local first_slice_mapping = sample_mappings[2]
    if first_slice_mapping and first_slice_mapping.base_note then
      base_note = first_slice_mapping.base_note
    end
  end
  
  -- Write notes for each slice
  for i = 1, slice_count do
    if i <= phrase.number_of_lines then
      local line = phrase:line(i)
      local note_col = line:note_column(1)
      note_col.note_value = base_note + (i - 1)
      note_col.instrument_value = song.selected_instrument_index - 1
    end
  end
  
  renoise.app():show_status(string.format("Created phrase from %d slices", slice_count))
end

-- Create drum pattern phrase
function PakettiPhraseTemplateDrum(pattern_preset)
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  
  -- Create new phrase
  local phrase_count = #instrument.phrases
  local new_phrase_index = phrase_count + 1
  instrument:insert_phrase_at(new_phrase_index)
  song.selected_phrase_index = new_phrase_index
  
  local phrase = song.selected_phrase
  phrase.number_of_lines = 16
  phrase.name = "Drum " .. pattern_preset
  phrase.visible_note_columns = 3
  
  local inst_val = song.selected_instrument_index - 1
  
  if pattern_preset == "basic" then
    -- Kick on 1, 5, 9, 13
    -- Snare on 5, 13
    -- Hat on every other
    local kicks = {1, 5, 9, 13}
    local snares = {5, 13}
    local hats = {1, 3, 5, 7, 9, 11, 13, 15}
    
    for _, line_num in ipairs(kicks) do
      local line = phrase:line(line_num)
      line:note_column(1).note_value = 36  -- C-2 (kick)
      line:note_column(1).instrument_value = inst_val
    end
    
    for _, line_num in ipairs(snares) do
      local line = phrase:line(line_num)
      line:note_column(2).note_value = 38  -- D-2 (snare)
      line:note_column(2).instrument_value = inst_val
    end
    
    for _, line_num in ipairs(hats) do
      local line = phrase:line(line_num)
      line:note_column(3).note_value = 42  -- F#2 (closed hat)
      line:note_column(3).instrument_value = inst_val
    end
    
  elseif pattern_preset == "four_floor" then
    -- Kick on every beat
    for i = 1, 16, 4 do
      local line = phrase:line(i)
      line:note_column(1).note_value = 36
      line:note_column(1).instrument_value = inst_val
    end
    -- Offbeat hats
    for i = 3, 16, 4 do
      local line = phrase:line(i)
      line:note_column(2).note_value = 42
      line:note_column(2).instrument_value = inst_val
    end
    
  elseif pattern_preset == "breakbeat" then
    -- Classic breakbeat pattern
    local kicks = {1, 7, 11}
    local snares = {5, 13}
    
    for _, line_num in ipairs(kicks) do
      local line = phrase:line(line_num)
      line:note_column(1).note_value = 36
      line:note_column(1).instrument_value = inst_val
    end
    
    for _, line_num in ipairs(snares) do
      local line = phrase:line(line_num)
      line:note_column(2).note_value = 38
      line:note_column(2).instrument_value = inst_val
    end
  end
  
  renoise.app():show_status(string.format("Created drum pattern: %s", pattern_preset))
end

-- Create arpeggio pattern phrase
function PakettiPhraseTemplateArp(direction, range)
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  direction = direction or "ascending"
  range = range or 12
  
  -- Create new phrase
  local phrase_count = #instrument.phrases
  local new_phrase_index = phrase_count + 1
  instrument:insert_phrase_at(new_phrase_index)
  song.selected_phrase_index = new_phrase_index
  
  local phrase = song.selected_phrase
  phrase.number_of_lines = range
  phrase.name = "Arp " .. direction
  
  local base_note = 48  -- C-4
  local inst_val = song.selected_instrument_index - 1
  
  for i = 1, range do
    local line = phrase:line(i)
    local note_col = line:note_column(1)
    
    local offset = 0
    if direction == "ascending" then
      offset = i - 1
    elseif direction == "descending" then
      offset = range - i
    elseif direction == "updown" then
      if i <= range / 2 then
        offset = i - 1
      else
        offset = range - i
      end
    elseif direction == "random" then
      trueRandomSeed()
      offset = math.random(0, range - 1)
    end
    
    note_col.note_value = base_note + offset
    note_col.instrument_value = inst_val
  end
  
  renoise.app():show_status(string.format("Created arp pattern: %s (%d notes)", direction, range))
end

--------------------------------------------------------------------------------
-- 8. PATTERN INTEGRATION: Auto-Fill
--------------------------------------------------------------------------------

-- Enhanced auto-fill pattern with variations
function PakettiPhraseAutoFillPattern(phrase_index, track_index)
  local song = renoise.song()
  if not song then return end
  
  local instrument_index = song.selected_instrument_index
  local instrument = song.selected_instrument
  
  phrase_index = phrase_index or song.selected_phrase_index
  track_index = track_index or song.selected_track_index
  
  if phrase_index < 1 or phrase_index > #instrument.phrases then
    renoise.app():show_status("Invalid phrase index")
    return
  end
  
  local phrase = instrument.phrases[phrase_index]
  local phrase_length = phrase.number_of_lines
  
  local pattern = song.selected_pattern
  local pattern_length = pattern.number_of_lines
  local pattern_track = pattern:track(track_index)
  
  -- Calculate triggers
  local trigger_count = math.floor(pattern_length / phrase_length)
  local triggers_added = 0
  
  for i = 0, trigger_count - 1 do
    local line_index = (i * phrase_length) + 1
    if line_index <= pattern_length then
      local line = pattern_track:line(line_index)
      local note_col = line:note_column(1)
      
      note_col.note_value = 48  -- C-4
      note_col.instrument_value = instrument_index - 1
      
      -- Add Zxx phrase program
      song.tracks[track_index].sample_effects_column_visible = true
      note_col.effect_number_value = 0x23  -- Z command (phrase trigger)
      note_col.effect_amount_value = phrase_index
      
      triggers_added = triggers_added + 1
    end
  end
  
  renoise.app():show_status(string.format(
    "Auto-filled pattern with phrase %02d (%d triggers)",
    phrase_index, triggers_added
  ))
end

-- Auto-fill all tracks with their selected phrases
function PakettiPhraseAutoFillAllTracks()
  local song = renoise.song()
  if not song then return end
  
  local total_triggers = 0
  
  for track_index = 1, #song.tracks do
    local track = song.tracks[track_index]
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      -- Check if track has phrase data for current instrument
      local phrase_index = song.selected_phrase_index
      if phrase_index > 0 then
        PakettiPhraseAutoFillPattern(phrase_index, track_index)
        total_triggers = total_triggers + 1
      end
    end
  end
  
  renoise.app():show_status(string.format("Auto-filled %d tracks", total_triggers))
end

-- Auto-fill with phrase variations (cycle through phrases)
function PakettiPhraseAutoFillWithVariation()
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  local instrument_index = song.selected_instrument_index
  
  if #instrument.phrases == 0 then
    renoise.app():show_status("No phrases in instrument")
    return
  end
  
  local pattern = song.selected_pattern
  local pattern_length = pattern.number_of_lines
  local pattern_track = pattern:track(song.selected_track_index)
  
  -- Use first phrase length as base
  local phrase_length = instrument.phrases[1].number_of_lines
  local trigger_count = math.floor(pattern_length / phrase_length)
  
  for i = 0, trigger_count - 1 do
    local line_index = (i * phrase_length) + 1
    if line_index <= pattern_length then
      local line = pattern_track:line(line_index)
      local note_col = line:note_column(1)
      
      -- Cycle through phrases
      local phrase_index = (i % #instrument.phrases) + 1
      
      note_col.note_value = 48
      note_col.instrument_value = instrument_index - 1
      
      song.tracks[song.selected_track_index].sample_effects_column_visible = true
      note_col.effect_number_value = 0x23  -- Z command (phrase trigger)
      note_col.effect_amount_value = phrase_index
    end
  end
  
  renoise.app():show_status("Auto-filled with phrase variations")
end

--------------------------------------------------------------------------------
-- 9. PATTERN INTEGRATION: Phrase to Pattern
--------------------------------------------------------------------------------

-- Convert phrase content to pattern data
function PakettiPhraseToPattern(phrase_index)
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  phrase_index = phrase_index or song.selected_phrase_index
  
  if phrase_index < 1 or phrase_index > #instrument.phrases then
    renoise.app():show_status("Invalid phrase index")
    return
  end
  
  local phrase = instrument.phrases[phrase_index]
  local track_index = song.selected_track_index
  local pattern = song.selected_pattern
  local pattern_track = pattern:track(track_index)
  local track = song.tracks[track_index]
  
  -- Ensure pattern is long enough
  if pattern.number_of_lines < phrase.number_of_lines then
    pattern.number_of_lines = phrase.number_of_lines
  end
  
  -- Ensure enough columns visible
  if track.visible_note_columns < phrase.visible_note_columns then
    track.visible_note_columns = phrase.visible_note_columns
  end
  if track.visible_effect_columns < phrase.visible_effect_columns then
    track.visible_effect_columns = phrase.visible_effect_columns
  end
  
  -- Copy phrase content to pattern
  for line_index = 1, phrase.number_of_lines do
    local phrase_line = phrase:line(line_index)
    local pattern_line = pattern_track:line(line_index)
    
    -- Copy note columns
    for col_index = 1, phrase.visible_note_columns do
      local src_col = phrase_line:note_column(col_index)
      local dst_col = pattern_line:note_column(col_index)
      
      if not src_col.is_empty then
        dst_col.note_value = src_col.note_value
        dst_col.instrument_value = song.selected_instrument_index - 1
        dst_col.volume_value = src_col.volume_value
        dst_col.panning_value = src_col.panning_value
        dst_col.delay_value = src_col.delay_value
        dst_col.effect_number_value = src_col.effect_number_value
        dst_col.effect_amount_value = src_col.effect_amount_value
      end
    end
    
    -- Copy effect columns
    for col_index = 1, phrase.visible_effect_columns do
      local src_col = phrase_line:effect_column(col_index)
      local dst_col = pattern_line:effect_column(col_index)
      
      if not src_col.is_empty then
        dst_col.number_value = src_col.number_value
        dst_col.amount_value = src_col.amount_value
      end
    end
  end
  
  renoise.app():show_status(string.format("Converted phrase %02d to pattern", phrase_index))
end

-- Convert all phrases to new patterns
function PakettiPhraseToPatternAll()
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  
  if #instrument.phrases == 0 then
    renoise.app():show_status("No phrases in instrument")
    return
  end
  
  local start_sequence = #song.sequencer.pattern_sequence
  
  for phrase_index = 1, #instrument.phrases do
    -- Create new pattern
    local new_pattern_index = song.sequencer:insert_new_pattern_at(start_sequence + phrase_index)
    song.selected_sequence_index = start_sequence + phrase_index
    
    -- Set pattern length to phrase length
    local phrase = instrument.phrases[phrase_index]
    song.patterns[new_pattern_index].number_of_lines = phrase.number_of_lines
    
    -- Convert phrase to pattern
    PakettiPhraseToPattern(phrase_index)
  end
  
  renoise.app():show_status(string.format("Converted %d phrases to patterns", #instrument.phrases))
end

--------------------------------------------------------------------------------
-- 10. PATTERN INTEGRATION: Pattern to Phrase
--------------------------------------------------------------------------------

-- Extract pattern content to new phrase
function PakettiPatternToPhrase()
  local song = renoise.song()
  if not song then return end
  
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local pattern_track = pattern:track(track_index)
  local track = song.tracks[track_index]
  local instrument = song.selected_instrument
  
  -- Check for selection
  local start_line, end_line
  local selection = song.selection_in_pattern
  if selection then
    start_line = selection.start_line
    end_line = selection.end_line
  else
    start_line = 1
    end_line = pattern.number_of_lines
  end
  
  local phrase_length = end_line - start_line + 1
  
  -- Create new phrase
  local phrase_count = #instrument.phrases
  local new_phrase_index = phrase_count + 1
  instrument:insert_phrase_at(new_phrase_index)
  song.selected_phrase_index = new_phrase_index
  
  local phrase = song.selected_phrase
  phrase.number_of_lines = phrase_length
  phrase.lpb = song.transport.lpb
  phrase.name = string.format("From Pattern %d", song.selected_pattern_index)
  
  -- Ensure enough columns
  if phrase.visible_note_columns < track.visible_note_columns then
    phrase.visible_note_columns = track.visible_note_columns
  end
  if phrase.visible_effect_columns < track.visible_effect_columns then
    phrase.visible_effect_columns = track.visible_effect_columns
  end
  
  -- Copy pattern content to phrase
  for i = 1, phrase_length do
    local pattern_line_index = start_line + i - 1
    local pattern_line = pattern_track:line(pattern_line_index)
    local phrase_line = phrase:line(i)
    
    -- Copy note columns
    for col_index = 1, track.visible_note_columns do
      local src_col = pattern_line:note_column(col_index)
      local dst_col = phrase_line:note_column(col_index)
      
      if not src_col.is_empty then
        dst_col.note_value = src_col.note_value
        dst_col.instrument_value = src_col.instrument_value
        dst_col.volume_value = src_col.volume_value
        dst_col.panning_value = src_col.panning_value
        dst_col.delay_value = src_col.delay_value
        dst_col.effect_number_value = src_col.effect_number_value
        dst_col.effect_amount_value = src_col.effect_amount_value
      end
    end
    
    -- Copy effect columns
    for col_index = 1, track.visible_effect_columns do
      local src_col = pattern_line:effect_column(col_index)
      local dst_col = phrase_line:effect_column(col_index)
      
      if not src_col.is_empty then
        dst_col.number_value = src_col.number_value
        dst_col.amount_value = src_col.amount_value
      end
    end
  end
  
  renoise.app():show_status(string.format("Created phrase %02d from pattern (%d lines)", new_phrase_index, phrase_length))
end

-- Extract single track to phrase
function PakettiPatternToPhraseTrack(track_index)
  local song = renoise.song()
  if not song then return end
  
  track_index = track_index or song.selected_track_index
  local prev_track = song.selected_track_index
  song.selected_track_index = track_index
  
  PakettiPatternToPhrase()
  
  song.selected_track_index = prev_track
end

--------------------------------------------------------------------------------
-- 11. LIVE RECORDING
--------------------------------------------------------------------------------

-- Arm live recording
function PakettiPhraseLiveRecordArm()
  PakettiPhraseLiveRecordArmed = true
  PakettiPhraseLiveRecordBuffer = {}
  renoise.app():show_status("Phrase Live Recording: ARMED")
end

-- Start live recording
function PakettiPhraseLiveRecordStart()
  local song = renoise.song()
  if not song then return end
  
  if not song.transport.playing then
    song.transport:start(renoise.Transport.PLAYMODE_RESTART_PATTERN)
  end
  
  PakettiPhraseLiveRecordActive = true
  PakettiPhraseLiveRecordArmed = false
  PakettiPhraseLiveRecordBuffer = {}
  PakettiPhraseLiveRecordStartLine = song.transport.playback_pos.line
  
  renoise.app():show_status("Phrase Live Recording: RECORDING")
end

-- Stop live recording
function PakettiPhraseLiveRecordStop()
  PakettiPhraseLiveRecordActive = false
  PakettiPhraseLiveRecordArmed = false
  
  local trigger_count = #PakettiPhraseLiveRecordBuffer
  renoise.app():show_status(string.format("Phrase Live Recording: STOPPED (%d triggers)", trigger_count))
end

-- Record a phrase trigger (called when phrase is triggered during recording)
function PakettiPhraseLiveRecordTrigger(instrument_index, phrase_index)
  if not PakettiPhraseLiveRecordActive then return end
  
  local song = renoise.song()
  if not song then return end
  
  local current_line = song.transport.playback_pos.line
  
  table.insert(PakettiPhraseLiveRecordBuffer, {
    line = current_line,
    instrument = instrument_index,
    phrase = phrase_index,
    timestamp = os.clock()
  })
end

-- Apply recorded triggers to pattern
function PakettiPhraseLiveRecordApply()
  local song = renoise.song()
  if not song then return end
  
  if #PakettiPhraseLiveRecordBuffer == 0 then
    renoise.app():show_status("No recorded triggers to apply")
    return
  end
  
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local pattern_track = pattern:track(track_index)
  local track = song.tracks[track_index]
  
  for _, trigger in ipairs(PakettiPhraseLiveRecordBuffer) do
    local line_index = trigger.line
    if line_index >= 1 and line_index <= pattern.number_of_lines then
      local line = pattern_track:line(line_index)
      local col_index = 1
      
      -- Find empty column
      for c = 1, track.visible_note_columns do
        if line:note_column(c).is_empty then
          col_index = c
          break
        end
      end
      
      local note_col = line:note_column(col_index)
      note_col.note_value = 48
      note_col.instrument_value = trigger.instrument - 1
      
      track.sample_effects_column_visible = true
      note_col.effect_number_value = 0x23  -- Z command (phrase trigger)
      note_col.effect_amount_value = trigger.phrase
    end
  end
  
  renoise.app():show_status(string.format("Applied %d recorded triggers", #PakettiPhraseLiveRecordBuffer))
  PakettiPhraseLiveRecordBuffer = {}
end

-- Quantize recorded triggers
function PakettiPhraseLiveRecordQuantize(quant_type)
  quant_type = quant_type or PakettiPhraseSwitcherDefaultQuant
  
  local song = renoise.song()
  if not song then return end
  
  local lpb = song.transport.lpb
  local quant_value = lpb  -- Default to beat
  
  if quant_type == "line" then
    quant_value = 1
  elseif quant_type == "beat" then
    quant_value = lpb
  elseif quant_type == "bar" then
    quant_value = lpb * 4
  end
  
  for i, trigger in ipairs(PakettiPhraseLiveRecordBuffer) do
    local quantized_line = math.floor((trigger.line - 1) / quant_value + 0.5) * quant_value + 1
    PakettiPhraseLiveRecordBuffer[i].line = quantized_line
  end
  
  renoise.app():show_status(string.format("Quantized %d triggers to %s", #PakettiPhraseLiveRecordBuffer, quant_type))
end

--------------------------------------------------------------------------------
-- 12. PATTERN MATRIX INTEGRATION
--------------------------------------------------------------------------------

-- Store current pattern matrix state as PhraseGrid state
function PakettiPhraseGridStoreFromPatternMatrix()
  local song = renoise.song()
  if not song then return end
  
  -- Find next empty state slot
  local state_index = nil
  for i = 1, PakettiPhraseGridMaxStates do
    if not PakettiPhraseGridStates[i] then
      state_index = i
      break
    end
  end
  
  if not state_index then
    renoise.app():show_status("No empty state slots available")
    return
  end
  
  -- Store with pattern matrix context
  local name = string.format("PM State %02d (Seq %d)", state_index, song.selected_sequence_index)
  PakettiPhraseGridStore(state_index, name)
end

-- Recall PhraseGrid state from Pattern Matrix context
function PakettiPhraseGridRecallFromPatternMatrix(state_index)
  if not state_index then
    -- Show popup to select state
    PakettiPhraseGridShowPopup()
    return
  end
  
  PakettiPhraseGridRecall(state_index)
end

--------------------------------------------------------------------------------
-- 12B. QUICK FLICKS ENGINE
--------------------------------------------------------------------------------

-- Quick Flicks output mode: "pattern" or "phrase"
PakettiQuickFlicksOutputMode = "pattern"

-- Helper: Get target (pattern track or phrase) based on mode
function PakettiQuickFlicksGetTarget()
  local song = renoise.song()
  if not song then return nil, nil, nil end
  
  if PakettiQuickFlicksOutputMode == "phrase" then
    local phrase = song.selected_phrase
    if not phrase then
      renoise.app():show_status("No phrase selected for Quick Flicks")
      return nil, nil, nil
    end
    return "phrase", phrase, phrase.number_of_lines
  else
    local pattern = song.selected_pattern
    local track_index = song.selected_track_index
    return "pattern", pattern:track(track_index), pattern.number_of_lines
  end
end

-- Helper: Get line from target
function PakettiQuickFlicksGetLine(target_type, target, line_index)
  if target_type == "phrase" then
    return target:line(line_index)
  else
    return target:line(line_index)
  end
end

-- Helper: Get current selection range
function PakettiQuickFlicksGetSelection()
  local song = renoise.song()
  if not song then return nil, nil end
  
  if PakettiQuickFlicksOutputMode == "phrase" then
    local sel = song.selection_in_phrase
    if sel then
      return sel.start_line, sel.end_line
    end
    -- Default to full phrase
    local phrase = song.selected_phrase
    if phrase then
      return 1, phrase.number_of_lines
    end
  else
    local sel = song.selection_in_pattern
    if sel then
      return sel.start_line, sel.end_line
    end
    -- Default to full pattern
    return 1, song.selected_pattern.number_of_lines
  end
  return nil, nil
end

-- Helper: Set selection in pattern or phrase
function PakettiQuickFlicksSetSelection(start_line, end_line)
  local song = renoise.song()
  if not song then return end
  
  local track_index = song.selected_track_index
  
  if PakettiQuickFlicksOutputMode == "phrase" then
    song.selection_in_phrase = {
      start_line = start_line,
      end_line = end_line,
      start_column = 1,
      end_column = 1
    }
  else
    song.selection_in_pattern = {
      start_line = start_line,
      end_line = end_line,
      start_track = track_index,
      end_track = track_index,
      start_column = 1,
      end_column = 1
    }
  end
end

--------------------------------------------------------------------------------
-- VOLUME RAMPS (0I / 0O)
--------------------------------------------------------------------------------

-- Volume Ramp Up: Apply 0I commands with ascending values
function PakettiQuickFlickVolumeRampUp(start_line, end_line)
  local song = renoise.song()
  if not song then return end
  
  local target_type, target, max_lines = PakettiQuickFlicksGetTarget()
  if not target then return end
  
  -- Use selection if no explicit lines provided
  if not start_line or not end_line then
    start_line, end_line = PakettiQuickFlicksGetSelection()
  end
  
  if not start_line or not end_line then
    renoise.app():show_status("No selection for volume ramp")
    return
  end
  
  local range = end_line - start_line + 1
  local track = song.selected_track
  
  -- Ensure effect column is visible
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  
  for line = start_line, end_line do
    if line <= max_lines then
      local pattern_line = PakettiQuickFlicksGetLine(target_type, target, line)
      local effect_col = pattern_line:effect_column(1)
      
      -- Calculate ramp value (00 -> FF)
      local progress = (line - start_line) / math.max(1, range - 1)
      local value = math.floor(progress * 255)
      
      effect_col.number_string = "0I"
      effect_col.amount_value = value
    end
  end
  
  renoise.app():show_status(string.format("Volume ramp up: lines %d-%d (0I 00->FF)", start_line, end_line))
end

-- Volume Ramp Down: Apply 0O commands with descending values
function PakettiQuickFlickVolumeRampDown(start_line, end_line)
  local song = renoise.song()
  if not song then return end
  
  local target_type, target, max_lines = PakettiQuickFlicksGetTarget()
  if not target then return end
  
  if not start_line or not end_line then
    start_line, end_line = PakettiQuickFlicksGetSelection()
  end
  
  if not start_line or not end_line then
    renoise.app():show_status("No selection for volume ramp")
    return
  end
  
  local range = end_line - start_line + 1
  local track = song.selected_track
  
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  
  for line = start_line, end_line do
    if line <= max_lines then
      local pattern_line = PakettiQuickFlicksGetLine(target_type, target, line)
      local effect_col = pattern_line:effect_column(1)
      
      -- Calculate ramp value (FF -> 00)
      local progress = (line - start_line) / math.max(1, range - 1)
      local value = math.floor((1 - progress) * 255)
      
      effect_col.number_string = "0O"
      effect_col.amount_value = value
    end
  end
  
  renoise.app():show_status(string.format("Volume ramp down: lines %d-%d (0O FF->00)", start_line, end_line))
end

-- Volume Gate: Apply alternating 0C00/clear based on pattern
function PakettiQuickFlickVolumeGate(start_line, end_line, pattern_str)
  local song = renoise.song()
  if not song then return end
  
  local target_type, target, max_lines = PakettiQuickFlicksGetTarget()
  if not target then return end
  
  if not start_line or not end_line then
    start_line, end_line = PakettiQuickFlicksGetSelection()
  end
  
  if not start_line or not end_line then
    renoise.app():show_status("No selection for volume gate")
    return
  end
  
  pattern_str = pattern_str or "1010"  -- Default: on-off-on-off
  local pattern_len = #pattern_str
  local track = song.selected_track
  
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  
  for line = start_line, end_line do
    if line <= max_lines then
      local pattern_line = PakettiQuickFlicksGetLine(target_type, target, line)
      local effect_col = pattern_line:effect_column(1)
      
      local pattern_pos = ((line - start_line) % pattern_len) + 1
      local is_on = pattern_str:sub(pattern_pos, pattern_pos) == "1"
      
      if is_on then
        effect_col:clear()  -- No cut
      else
        effect_col.number_string = "0C"
        effect_col.amount_value = 0x00  -- Instant cut
      end
    end
  end
  
  renoise.app():show_status(string.format("Volume gate pattern '%s': lines %d-%d", pattern_str, start_line, end_line))
end

--------------------------------------------------------------------------------
-- CUT PATTERNS (0C)
--------------------------------------------------------------------------------

-- Cut Pattern: Apply 0C with specific cut value
function PakettiQuickFlickCutPattern(start_line, end_line, cut_value)
  local song = renoise.song()
  if not song then return end
  
  local target_type, target, max_lines = PakettiQuickFlicksGetTarget()
  if not target then return end
  
  if not start_line or not end_line then
    start_line, end_line = PakettiQuickFlicksGetSelection()
  end
  
  if not start_line or not end_line then
    renoise.app():show_status("No selection for cut pattern")
    return
  end
  
  cut_value = cut_value or 0x00  -- Default: instant cut
  local track = song.selected_track
  
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  
  for line = start_line, end_line do
    if line <= max_lines then
      local pattern_line = PakettiQuickFlicksGetLine(target_type, target, line)
      local effect_col = pattern_line:effect_column(1)
      effect_col.number_string = "0C"
      effect_col.amount_value = cut_value
    end
  end
  
  renoise.app():show_status(string.format("Cut pattern 0C%02X: lines %d-%d", cut_value, start_line, end_line))
end

-- Cut Gate: Apply 0C based on on/off pattern string
function PakettiQuickFlickCutGate(start_line, end_line, pattern_str, cut_value)
  local song = renoise.song()
  if not song then return end
  
  local target_type, target, max_lines = PakettiQuickFlicksGetTarget()
  if not target then return end
  
  if not start_line or not end_line then
    start_line, end_line = PakettiQuickFlicksGetSelection()
  end
  
  if not start_line or not end_line then
    renoise.app():show_status("No selection for cut gate")
    return
  end
  
  pattern_str = pattern_str or "1100"  -- Default: on-on-cut-cut
  cut_value = cut_value or 0x00
  local pattern_len = #pattern_str
  local track = song.selected_track
  
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  
  for line = start_line, end_line do
    if line <= max_lines then
      local pattern_line = PakettiQuickFlicksGetLine(target_type, target, line)
      local effect_col = pattern_line:effect_column(1)
      
      local pattern_pos = ((line - start_line) % pattern_len) + 1
      local is_on = pattern_str:sub(pattern_pos, pattern_pos) == "1"
      
      if is_on then
        effect_col:clear()
      else
        effect_col.number_string = "0C"
        effect_col.amount_value = cut_value
      end
    end
  end
  
  renoise.app():show_status(string.format("Cut gate '%s' 0C%02X: lines %d-%d", pattern_str, cut_value, start_line, end_line))
end

--------------------------------------------------------------------------------
-- RETRIG PATTERNS (0R)
--------------------------------------------------------------------------------

-- Retrig: Apply 0R with speed and volume curve
function PakettiQuickFlickRetrig(start_line, end_line, speed, volume_curve)
  local song = renoise.song()
  if not song then return end
  
  local target_type, target, max_lines = PakettiQuickFlicksGetTarget()
  if not target then return end
  
  if not start_line or not end_line then
    start_line, end_line = PakettiQuickFlicksGetSelection()
  end
  
  if not start_line or not end_line then
    renoise.app():show_status("No selection for retrig")
    return
  end
  
  speed = speed or 4  -- Default: 4 ticks between retrigs
  volume_curve = volume_curve or "flat"  -- "up", "down", "flat"
  
  local track = song.selected_track
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  
  local range = end_line - start_line + 1
  
  for line = start_line, end_line do
    if line <= max_lines then
      local pattern_line = PakettiQuickFlicksGetLine(target_type, target, line)
      local effect_col = pattern_line:effect_column(1)
      
      local vol_factor = 0  -- 0 = flat
      if volume_curve == "up" then
        local progress = (line - start_line) / math.max(1, range - 1)
        vol_factor = math.floor(progress * 15)
      elseif volume_curve == "down" then
        local progress = (line - start_line) / math.max(1, range - 1)
        vol_factor = 15 - math.floor(progress * 15)
      end
      
      -- 0Rxy: x = volume factor (0-F), y = speed (ticks, 1-F)
      local retrig_value = (vol_factor * 16) + math.min(15, math.max(1, speed))
      
      effect_col.number_string = "0R"
      effect_col.amount_value = retrig_value
    end
  end
  
  renoise.app():show_status(string.format("Retrig 0R (speed=%d, curve=%s): lines %d-%d", speed, volume_curve, start_line, end_line))
end

--------------------------------------------------------------------------------
-- SLICE SEQUENCES (0S)
--------------------------------------------------------------------------------

-- Slice Sequential: Apply 0S01, 0S02, 0S03... through selection
function PakettiQuickFlickSliceSequential(start_line, end_line)
  local song = renoise.song()
  if not song then return end
  
  local target_type, target, max_lines = PakettiQuickFlicksGetTarget()
  if not target then return end
  
  if not start_line or not end_line then
    start_line, end_line = PakettiQuickFlicksGetSelection()
  end
  
  if not start_line or not end_line then
    renoise.app():show_status("No selection for slice sequence")
    return
  end
  
  -- Get slice count from instrument
  local instrument = song.selected_instrument
  local slice_count = 16  -- Default
  if instrument and instrument.samples[1] and instrument.samples[1].slice_markers then
    slice_count = #instrument.samples[1].slice_markers
    if slice_count == 0 then slice_count = 16 end
  end
  
  local track = song.selected_track
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  
  local slice_index = 1
  for line = start_line, end_line do
    if line <= max_lines then
      local pattern_line = PakettiQuickFlicksGetLine(target_type, target, line)
      local effect_col = pattern_line:effect_column(1)
      
      effect_col.number_string = "0S"
      effect_col.amount_value = slice_index
      
      slice_index = slice_index + 1
      if slice_index > slice_count then
        slice_index = 1
      end
    end
  end
  
  renoise.app():show_status(string.format("Slice sequential (01->%02X): lines %d-%d", slice_count, start_line, end_line))
end

-- Slice Reverse: Apply 0S descending through selection
function PakettiQuickFlickSliceReverse(start_line, end_line)
  local song = renoise.song()
  if not song then return end
  
  local target_type, target, max_lines = PakettiQuickFlicksGetTarget()
  if not target then return end
  
  if not start_line or not end_line then
    start_line, end_line = PakettiQuickFlicksGetSelection()
  end
  
  if not start_line or not end_line then
    renoise.app():show_status("No selection for slice reverse")
    return
  end
  
  local instrument = song.selected_instrument
  local slice_count = 16
  if instrument and instrument.samples[1] and instrument.samples[1].slice_markers then
    slice_count = #instrument.samples[1].slice_markers
    if slice_count == 0 then slice_count = 16 end
  end
  
  local track = song.selected_track
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  
  local slice_index = slice_count
  for line = start_line, end_line do
    if line <= max_lines then
      local pattern_line = PakettiQuickFlicksGetLine(target_type, target, line)
      local effect_col = pattern_line:effect_column(1)
      
      effect_col.number_string = "0S"
      effect_col.amount_value = slice_index
      
      slice_index = slice_index - 1
      if slice_index < 1 then
        slice_index = slice_count
      end
    end
  end
  
  renoise.app():show_status(string.format("Slice reverse (%02X->01): lines %d-%d", slice_count, start_line, end_line))
end

-- Slice Random: Apply random 0S values through selection
function PakettiQuickFlickSliceRandom(start_line, end_line)
  local song = renoise.song()
  if not song then return end
  
  local target_type, target, max_lines = PakettiQuickFlicksGetTarget()
  if not target then return end
  
  if not start_line or not end_line then
    start_line, end_line = PakettiQuickFlicksGetSelection()
  end
  
  if not start_line or not end_line then
    renoise.app():show_status("No selection for random slices")
    return
  end
  
  local instrument = song.selected_instrument
  local slice_count = 16
  if instrument and instrument.samples[1] and instrument.samples[1].slice_markers then
    slice_count = #instrument.samples[1].slice_markers
    if slice_count == 0 then slice_count = 16 end
  end
  
  local track = song.selected_track
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  
  for line = start_line, end_line do
    if line <= max_lines then
      local pattern_line = PakettiQuickFlicksGetLine(target_type, target, line)
      local effect_col = pattern_line:effect_column(1)
      
      effect_col.number_string = "0S"
      effect_col.amount_value = math.random(1, slice_count)
    end
  end
  
  renoise.app():show_status(string.format("Slice random (01-%02X): lines %d-%d", slice_count, start_line, end_line))
end

--------------------------------------------------------------------------------
-- CUSTOM SEQUENCES
--------------------------------------------------------------------------------

-- Custom: Apply any effect with value pattern
function PakettiQuickFlickCustom(start_line, end_line, effect_code, value_pattern)
  local song = renoise.song()
  if not song then return end
  
  local target_type, target, max_lines = PakettiQuickFlicksGetTarget()
  if not target then return end
  
  if not start_line or not end_line then
    start_line, end_line = PakettiQuickFlicksGetSelection()
  end
  
  if not start_line or not end_line then
    renoise.app():show_status("No selection for custom sequence")
    return
  end
  
  effect_code = effect_code or "0C"
  value_pattern = value_pattern or "00,80,FF"  -- Default: comma-separated values
  
  -- Parse value pattern
  local values = {}
  if value_pattern:match("^ramp:") then
    -- "ramp:00-FF" format
    local start_val, end_val = value_pattern:match("ramp:(%x+)-(%x+)")
    if start_val and end_val then
      local sv = tonumber(start_val, 16)
      local ev = tonumber(end_val, 16)
      local range = end_line - start_line + 1
      for i = 0, range - 1 do
        local progress = i / math.max(1, range - 1)
        values[#values + 1] = math.floor(sv + (ev - sv) * progress)
      end
    end
  elseif value_pattern:match("^random:") then
    -- "random:00-7F" format
    local min_val, max_val = value_pattern:match("random:(%x+)-(%x+)")
    if min_val and max_val then
      local minv = tonumber(min_val, 16)
      local maxv = tonumber(max_val, 16)
      for line = start_line, end_line do
        values[#values + 1] = math.random(minv, maxv)
      end
    end
  else
    -- Comma-separated values
    for val in value_pattern:gmatch("(%x+)") do
      values[#values + 1] = tonumber(val, 16)
    end
  end
  
  if #values == 0 then
    values = {0x00}
  end
  
  local track = song.selected_track
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  
  local val_index = 1
  for line = start_line, end_line do
    if line <= max_lines then
      local pattern_line = PakettiQuickFlicksGetLine(target_type, target, line)
      local effect_col = pattern_line:effect_column(1)
      
      effect_col.number_string = effect_code
      effect_col.amount_value = values[val_index]
      
      val_index = val_index + 1
      if val_index > #values then
        val_index = 1
      end
    end
  end
  
  renoise.app():show_status(string.format("Custom %s pattern: lines %d-%d", effect_code, start_line, end_line))
end

--------------------------------------------------------------------------------
-- QUICK RANGE SELECTION
--------------------------------------------------------------------------------

-- Select range in pattern/phrase
function PakettiQuickFlicksSelectRange(start_line, end_line)
  PakettiQuickFlicksSetSelection(start_line, end_line)
  renoise.app():show_status(string.format("Selected lines %d-%d", start_line, end_line))
end

-- Quick range presets
function PakettiQuickFlicksSelectRange_0_16()
  PakettiQuickFlicksSelectRange(1, 16)
end

function PakettiQuickFlicksSelectRange_16_32()
  PakettiQuickFlicksSelectRange(17, 32)
end

function PakettiQuickFlicksSelectRange_32_48()
  PakettiQuickFlicksSelectRange(33, 48)
end

function PakettiQuickFlicksSelectRange_48_64()
  PakettiQuickFlicksSelectRange(49, 64)
end

function PakettiQuickFlicksSelectFullPattern()
  local song = renoise.song()
  if not song then return end
  
  if PakettiQuickFlicksOutputMode == "phrase" then
    local phrase = song.selected_phrase
    if phrase then
      PakettiQuickFlicksSelectRange(1, phrase.number_of_lines)
    end
  else
    PakettiQuickFlicksSelectRange(1, song.selected_pattern.number_of_lines)
  end
end

function PakettiQuickFlicksSelectFirstHalf()
  local song = renoise.song()
  if not song then return end
  
  local length = song.selected_pattern.number_of_lines
  if PakettiQuickFlicksOutputMode == "phrase" then
    local phrase = song.selected_phrase
    if phrase then
      length = phrase.number_of_lines
    end
  end
  PakettiQuickFlicksSelectRange(1, math.floor(length / 2))
end

function PakettiQuickFlicksSelectSecondHalf()
  local song = renoise.song()
  if not song then return end
  
  local length = song.selected_pattern.number_of_lines
  if PakettiQuickFlicksOutputMode == "phrase" then
    local phrase = song.selected_phrase
    if phrase then
      length = phrase.number_of_lines
    end
  end
  PakettiQuickFlicksSelectRange(math.floor(length / 2) + 1, length)
end

-- Toggle output mode
function PakettiQuickFlicksToggleOutputMode()
  if PakettiQuickFlicksOutputMode == "pattern" then
    PakettiQuickFlicksOutputMode = "phrase"
  else
    PakettiQuickFlicksOutputMode = "pattern"
  end
  renoise.app():show_status("Quick Flicks output: " .. PakettiQuickFlicksOutputMode)
end

--------------------------------------------------------------------------------
-- QUICK SELECT + FLICKS DIALOG
--------------------------------------------------------------------------------

PakettiQuickFlicksDialog = nil
PakettiQuickFlicksDialogVb = nil

function PakettiQuickFlicksShowDialog()
  local song = renoise.song()
  if not song then return end
  
  -- Close existing dialog
  if PakettiQuickFlicksDialog and PakettiQuickFlicksDialog.visible then
    PakettiQuickFlicksDialog:close()
    PakettiQuickFlicksDialog = nil
    return
  end
  
  PakettiQuickFlicksDialogVb = renoise.ViewBuilder()
  local vb = PakettiQuickFlicksDialogVb
  
  -- Get current pattern length for dynamic buttons
  local pattern_length = song.selected_pattern.number_of_lines
  
  -- Selection Range Section
  local range_buttons = vb:row{spacing = 2}
  
  -- Add standard range buttons
  local ranges = {
    {1, 16, "1-16"},
    {17, 32, "17-32"},
    {33, 48, "33-48"},
    {49, 64, "49-64"},
    {65, 80, "65-80"},
    {81, 96, "81-96"},
    {97, 112, "97-112"},
    {113, 128, "113-128"}
  }
  
  for _, range in ipairs(ranges) do
    if range[2] <= pattern_length then
      range_buttons:add_child(vb:button{
        text = range[3],
        width = 45,
        notifier = function()
          PakettiQuickFlicksSelectRange(range[1], math.min(range[2], pattern_length))
        end
      })
    end
  end
  
  -- Quick selection presets
  local preset_buttons = vb:row{
    spacing = 2,
    vb:button{text = "Full", width = 40, notifier = PakettiQuickFlicksSelectFullPattern},
    vb:button{text = "1st Half", width = 50, notifier = PakettiQuickFlicksSelectFirstHalf},
    vb:button{text = "2nd Half", width = 55, notifier = PakettiQuickFlicksSelectSecondHalf},
  }
  
  -- Numeric input row
  local start_valuebox = vb:valuebox{
    id = "qf_start_line",
    min = 1,
    max = 512,
    value = 1,
    width = 60
  }
  
  local end_valuebox = vb:valuebox{
    id = "qf_end_line",
    min = 1,
    max = 512,
    value = pattern_length,
    width = 60
  }
  
  local numeric_row = vb:row{
    spacing = 5,
    vb:text{text = "Start:"},
    start_valuebox,
    vb:text{text = "End:"},
    end_valuebox,
    vb:button{
      text = "Select",
      width = 50,
      notifier = function()
        PakettiQuickFlicksSelectRange(
          vb.views.qf_start_line.value,
          vb.views.qf_end_line.value
        )
      end
    },
  }
  
  -- Volume Flicks
  local volume_row = vb:row{
    spacing = 2,
    vb:button{text = "Ramp Up", width = 60, notifier = function() PakettiQuickFlickVolumeRampUp() end},
    vb:button{text = "Ramp Down", width = 70, notifier = function() PakettiQuickFlickVolumeRampDown() end},
    vb:button{text = "Gate 1010", width = 65, notifier = function() PakettiQuickFlickVolumeGate(nil, nil, "1010") end},
    vb:button{text = "Gate 1100", width = 65, notifier = function() PakettiQuickFlickVolumeGate(nil, nil, "1100") end},
    vb:button{text = "Gate 1000", width = 65, notifier = function() PakettiQuickFlickVolumeGate(nil, nil, "1000") end},
  }
  
  -- Cut Flicks
  local cut_row = vb:row{
    spacing = 2,
    vb:button{text = "0C00", width = 40, notifier = function() PakettiQuickFlickCutPattern(nil, nil, 0x00) end},
    vb:button{text = "0C40", width = 40, notifier = function() PakettiQuickFlickCutPattern(nil, nil, 0x40) end},
    vb:button{text = "0C80", width = 40, notifier = function() PakettiQuickFlickCutPattern(nil, nil, 0x80) end},
    vb:button{text = "0CC0", width = 40, notifier = function() PakettiQuickFlickCutPattern(nil, nil, 0xC0) end},
    vb:button{text = "0CF0", width = 40, notifier = function() PakettiQuickFlickCutPattern(nil, nil, 0xF0) end},
    vb:valuebox{
      id = "qf_custom_cut",
      min = 0,
      max = 255,
      value = 0,
      width = 50,
      tostring = function(v) return string.format("%02X", v) end,
      tonumber = function(s) return tonumber(s, 16) or 0 end
    },
    vb:button{text = "Apply", width = 45, notifier = function()
      PakettiQuickFlickCutPattern(nil, nil, vb.views.qf_custom_cut.value)
    end},
  }
  
  -- Retrig Flicks
  local retrig_row = vb:row{
    spacing = 2,
    vb:button{text = "R01", width = 35, notifier = function() PakettiQuickFlickRetrig(nil, nil, 1, "flat") end},
    vb:button{text = "R02", width = 35, notifier = function() PakettiQuickFlickRetrig(nil, nil, 2, "flat") end},
    vb:button{text = "R04", width = 35, notifier = function() PakettiQuickFlickRetrig(nil, nil, 4, "flat") end},
    vb:button{text = "R08", width = 35, notifier = function() PakettiQuickFlickRetrig(nil, nil, 8, "flat") end},
    vb:button{text = "Vol Up", width = 50, notifier = function() PakettiQuickFlickRetrig(nil, nil, 4, "up") end},
    vb:button{text = "Vol Down", width = 60, notifier = function() PakettiQuickFlickRetrig(nil, nil, 4, "down") end},
  }
  
  -- Slice Flicks
  local slice_row = vb:row{
    spacing = 2,
    vb:button{text = "Sequential", width = 70, notifier = function() PakettiQuickFlickSliceSequential() end},
    vb:button{text = "Reverse", width = 60, notifier = function() PakettiQuickFlickSliceReverse() end},
    vb:button{text = "Random", width = 55, notifier = function() PakettiQuickFlickSliceRandom() end},
  }
  
  -- Custom Effect Row
  local custom_effect_input = vb:textfield{
    id = "qf_custom_effect",
    width = 40,
    value = "0C"
  }
  
  local custom_values_input = vb:textfield{
    id = "qf_custom_values",
    width = 150,
    value = "00,40,80,C0,FF"
  }
  
  local custom_row = vb:row{
    spacing = 5,
    vb:text{text = "Effect:"},
    custom_effect_input,
    vb:text{text = "Values:"},
    custom_values_input,
    vb:button{text = "Apply", width = 50, notifier = function()
      PakettiQuickFlickCustom(nil, nil, vb.views.qf_custom_effect.value, vb.views.qf_custom_values.value)
    end},
  }
  
  -- Target mode switch
  local target_switch = vb:row{
    spacing = 5,
    vb:text{text = "Target:"},
    vb:switch{
      width = 120,
      items = {"Pattern", "Phrase"},
      value = (PakettiQuickFlicksOutputMode == "pattern") and 1 or 2,
      notifier = function(value)
        PakettiQuickFlicksOutputMode = (value == 1) and "pattern" or "phrase"
      end
    },
  }
  
  local content = vb:column{
    margin = 10,
    spacing = 8,
    
    vb:row{vb:text{text = "Selection Range", font = "bold"}},
    range_buttons,
    preset_buttons,
    numeric_row,
    
    vb:space{height = 5},
    
    vb:row{vb:text{text = "Quick Flicks", font = "bold"}},
    
    vb:row{vb:text{text = "Volume (0I/0O):"}},
    volume_row,
    
    vb:row{vb:text{text = "Cuts (0C):"}},
    cut_row,
    
    vb:row{vb:text{text = "Retrig (0R):"}},
    retrig_row,
    
    vb:row{vb:text{text = "Slices (0S):"}},
    slice_row,
    
    vb:space{height = 5},
    
    vb:row{vb:text{text = "Custom Sequence", font = "bold"}},
    custom_row,
    
    vb:space{height = 5},
    
    target_switch,
    
    vb:row{
      spacing = 5,
      vb:button{
        text = "Close",
        width = 60,
        notifier = function()
          PakettiQuickFlicksDialog:close()
        end
      },
    },
  }
  
  PakettiQuickFlicksDialog = renoise.app():show_custom_dialog(
    "Quick Select & Flicks",
    content,
    my_keyhandler_func
  )
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

--------------------------------------------------------------------------------
-- 13. UI: MINIMAL POPUP
--------------------------------------------------------------------------------

-- Popup dialog state
PakettiPhraseGridPopupDialog = nil
PakettiPhraseGridPopupVb = nil

-- Show minimal popup for state selection
function PakettiPhraseGridShowPopup()
  local song = renoise.song()
  if not song then return end
  
  -- Close existing dialog
  if PakettiPhraseGridPopupDialog and PakettiPhraseGridPopupDialog.visible then
    PakettiPhraseGridPopupDialog:close()
    PakettiPhraseGridPopupDialog = nil
    return
  end
  
  PakettiPhraseGridPopupVb = renoise.ViewBuilder()
  local vb = PakettiPhraseGridPopupVb
  
  -- Build state list
  local state_items = {"-- Select State --"}
  for i = 1, PakettiPhraseGridMaxStates do
    local state = PakettiPhraseGridStates[i]
    if state then
      table.insert(state_items, string.format("%02d: %s", i, state.name))
    else
      table.insert(state_items, string.format("%02d: (empty)", i))
    end
  end
  
  -- Build bank list
  local bank_items = {}
  for i = 1, PakettiPhraseBankMaxBanks do
    local bank = PakettiPhraseBanks[i]
    if bank then
      table.insert(bank_items, string.format("%d: %s", i, bank.name))
    else
      table.insert(bank_items, string.format("%d: (empty)", i))
    end
  end
  if #bank_items == 0 then
    bank_items = {"No banks"}
  end
  
  local content = vb:column{
    margin = 5,
    spacing = 5,
    
    vb:row{
      vb:text{text = "PhraseGrid State:", font = "bold"},
    },
    
    vb:popup{
      id = "state_popup",
      width = 200,
      items = state_items,
      value = PakettiPhraseGridCurrentState + 1,
      notifier = function(value)
        if value > 1 then
          PakettiPhraseGridRecall(value - 1)
        end
      end
    },
    
    vb:row{
      spacing = 5,
      vb:button{
        text = "Store",
        width = 60,
        notifier = function()
          local current = vb.views.state_popup.value - 1
          if current >= 1 then
            PakettiPhraseGridStore(current)
            PakettiPhraseGridPopupDialog:close()
            PakettiPhraseGridShowPopup()  -- Refresh
          end
        end
      },
      vb:button{
        text = "Clear",
        width = 60,
        notifier = function()
          local current = vb.views.state_popup.value - 1
          if current >= 1 then
            PakettiPhraseGridClear(current)
            PakettiPhraseGridPopupDialog:close()
            PakettiPhraseGridShowPopup()  -- Refresh
          end
        end
      },
    },
    
    vb:space{height = 5},
    
    vb:row{
      vb:text{text = "Bank:", font = "bold"},
    },
    
    vb:popup{
      id = "bank_popup",
      width = 200,
      items = bank_items,
      value = PakettiPhraseBankCurrent,
      notifier = function(value)
        PakettiPhraseBankSelect(value)
      end
    },
    
    vb:row{
      spacing = 5,
      vb:text{text = "Mode:"},
      vb:popup{
        id = "mode_popup",
        width = 80,
        items = {"trigger", "gate", "toggle", "oneshot", "legato"},
        value = 1,
        notifier = function(value)
          local modes = {"trigger", "gate", "toggle", "oneshot", "legato"}
          PakettiPhraseSwitcherSetDefaultMode(modes[value])
        end
      },
      vb:text{text = "Quant:"},
      vb:popup{
        id = "quant_popup",
        width = 60,
        items = {"line", "beat", "bar"},
        value = 2,
        notifier = function(value)
          local quants = {"line", "beat", "bar"}
          PakettiPhraseSwitcherSetDefaultQuant(quants[value])
        end
      },
    },
    
    vb:space{height = 5},
    
    vb:row{
      vb:text{text = "Bank Slots:", font = "bold"},
    },
    
    vb:row{
      spacing = 2,
      vb:button{text = "1", width = 24, notifier = function() PakettiPhraseBankTriggerSlot(1) end},
      vb:button{text = "2", width = 24, notifier = function() PakettiPhraseBankTriggerSlot(2) end},
      vb:button{text = "3", width = 24, notifier = function() PakettiPhraseBankTriggerSlot(3) end},
      vb:button{text = "4", width = 24, notifier = function() PakettiPhraseBankTriggerSlot(4) end},
      vb:button{text = "5", width = 24, notifier = function() PakettiPhraseBankTriggerSlot(5) end},
      vb:button{text = "6", width = 24, notifier = function() PakettiPhraseBankTriggerSlot(6) end},
      vb:button{text = "7", width = 24, notifier = function() PakettiPhraseBankTriggerSlot(7) end},
      vb:button{text = "8", width = 24, notifier = function() PakettiPhraseBankTriggerSlot(8) end},
    },
  }
  
  PakettiPhraseGridPopupDialog = renoise.app():show_custom_dialog(
    "PhraseGrid Quick Select",
    content,
    my_keyhandler_func
  )
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

--------------------------------------------------------------------------------
-- 14. UI: FULL DIALOG
--------------------------------------------------------------------------------

-- Full dialog state
PakettiPhraseGridDialog = nil
PakettiPhraseGridDialogVb = nil

-- Show full PhraseGrid dialog
function PakettiPhraseGridShowDialog()
  local song = renoise.song()
  if not song then return end
  
  -- Close existing dialog
  if PakettiPhraseGridDialog and PakettiPhraseGridDialog.visible then
    PakettiPhraseGridDialog:close()
    PakettiPhraseGridDialog = nil
    return
  end
  
  PakettiPhraseGridDialogVb = renoise.ViewBuilder()
  local vb = PakettiPhraseGridDialogVb
  
  -- State buttons row
  local state_buttons = vb:row{spacing = 2}
  for i = 1, 16 do
    local state = PakettiPhraseGridStates[i]
    local style = state and "button" or "body"
    state_buttons:add_child(vb:button{
      text = string.format("%02d", i),
      width = 30,
      color = (i == PakettiPhraseGridCurrentState) and {0x40, 0x80, 0xFF} or nil,
      notifier = function()
        if PakettiPhraseGridStates[i] then
          PakettiPhraseGridRecall(i)
        else
          PakettiPhraseGridStore(i)
        end
        -- Refresh dialog
        PakettiPhraseGridDialog:close()
        PakettiPhraseGridShowDialog()
      end
    })
  end
  
  local state_buttons_row2 = vb:row{spacing = 2}
  for i = 17, 32 do
    local state = PakettiPhraseGridStates[i]
    state_buttons_row2:add_child(vb:button{
      text = string.format("%02d", i),
      width = 30,
      color = (i == PakettiPhraseGridCurrentState) and {0x40, 0x80, 0xFF} or nil,
      notifier = function()
        if PakettiPhraseGridStates[i] then
          PakettiPhraseGridRecall(i)
        else
          PakettiPhraseGridStore(i)
        end
        PakettiPhraseGridDialog:close()
        PakettiPhraseGridShowDialog()
      end
    })
  end
  
  -- Bank buttons
  local bank_buttons = vb:row{spacing = 2}
  for i = 1, 8 do
    local bank = PakettiPhraseBanks[i]
    bank_buttons:add_child(vb:button{
      text = bank and bank.name or string.format("Bank %d", i),
      width = 60,
      color = (i == PakettiPhraseBankCurrent) and {0xFF, 0x80, 0x40} or nil,
      notifier = function()
        if PakettiPhraseBanks[i] then
          PakettiPhraseBankSelect(i)
        else
          PakettiPhraseBankCreate(song.selected_instrument_index)
        end
        PakettiPhraseGridDialog:close()
        PakettiPhraseGridShowDialog()
      end
    })
  end
  
  -- Phrase trigger buttons (from current bank)
  local phrase_buttons = vb:row{spacing = 2}
  for i = 1, 8 do
    local phrase_index = PakettiPhraseBankGetPhrase(i)
    local text = phrase_index and string.format("P%02d", phrase_index) or "--"
    phrase_buttons:add_child(vb:button{
      text = text,
      width = 40,
      notifier = function()
        PakettiPhraseBankTriggerSlot(i)
      end
    })
  end
  
  -- Template buttons
  local template_buttons = vb:row{spacing = 2}
  template_buttons:add_child(vb:button{
    text = "Empty 16",
    width = 60,
    notifier = function()
      PakettiPhraseTemplateCreate("empty", {length = 16})
    end
  })
  template_buttons:add_child(vb:button{
    text = "From Slices",
    width = 70,
    notifier = function()
      PakettiPhraseTemplateFromSlices()
    end
  })
  template_buttons:add_child(vb:button{
    text = "Drum Basic",
    width = 70,
    notifier = function()
      PakettiPhraseTemplateDrum("basic")
    end
  })
  template_buttons:add_child(vb:button{
    text = "Arp Up",
    width = 50,
    notifier = function()
      PakettiPhraseTemplateArp("ascending", 12)
    end
  })
  
  -- Pattern conversion buttons
  local pattern_buttons = vb:row{spacing = 2}
  pattern_buttons:add_child(vb:button{
    text = "Phrase -> Pattern",
    width = 100,
    notifier = function()
      PakettiPhraseToPattern()
    end
  })
  pattern_buttons:add_child(vb:button{
    text = "Pattern -> Phrase",
    width = 100,
    notifier = function()
      PakettiPatternToPhrase()
    end
  })
  pattern_buttons:add_child(vb:button{
    text = "Auto-Fill",
    width = 60,
    notifier = function()
      PakettiPhraseAutoFillPattern()
    end
  })
  
  -- Live recording buttons
  local record_buttons = vb:row{spacing = 2}
  record_buttons:add_child(vb:button{
    text = "Arm",
    width = 40,
    notifier = function()
      PakettiPhraseLiveRecordArm()
    end
  })
  record_buttons:add_child(vb:button{
    text = "Record",
    width = 50,
    color = PakettiPhraseLiveRecordActive and {0xFF, 0x40, 0x40} or nil,
    notifier = function()
      if PakettiPhraseLiveRecordActive then
        PakettiPhraseLiveRecordStop()
      else
        PakettiPhraseLiveRecordStart()
      end
      PakettiPhraseGridDialog:close()
      PakettiPhraseGridShowDialog()
    end
  })
  record_buttons:add_child(vb:button{
    text = "Apply",
    width = 50,
    notifier = function()
      PakettiPhraseLiveRecordApply()
    end
  })
  record_buttons:add_child(vb:button{
    text = "Quantize",
    width = 60,
    notifier = function()
      PakettiPhraseLiveRecordQuantize()
    end
  })
  
  -- Settings row
  local settings_row = vb:row{spacing = 5}
  settings_row:add_child(vb:text{text = "Mode:"})
  settings_row:add_child(vb:popup{
    width = 80,
    items = {"trigger", "gate", "toggle", "oneshot", "legato"},
    value = 1,
    notifier = function(value)
      local modes = {"trigger", "gate", "toggle", "oneshot", "legato"}
      PakettiPhraseSwitcherSetDefaultMode(modes[value])
    end
  })
  settings_row:add_child(vb:text{text = "Quant:"})
  settings_row:add_child(vb:popup{
    width = 60,
    items = {"line", "beat", "bar"},
    value = 2,
    notifier = function(value)
      local quants = {"line", "beat", "bar"}
      PakettiPhraseSwitcherSetDefaultQuant(quants[value])
    end
  })
  settings_row:add_child(vb:checkbox{
    value = PakettiPhraseTransportEnabled,
    notifier = function(value)
      if value then
        PakettiPhraseTransportEnable()
      else
        PakettiPhraseTransportDisable()
      end
    end
  })
  settings_row:add_child(vb:text{text = "Transport Follow"})
  
  local content = vb:column{
    margin = 10,
    spacing = 8,
    
    vb:row{vb:text{text = "PhraseGrid States", font = "bold"}},
    state_buttons,
    state_buttons_row2,
    
    vb:space{height = 5},
    
    vb:row{vb:text{text = "Phrase Banks", font = "bold"}},
    bank_buttons,
    phrase_buttons,
    
    vb:space{height = 5},
    
    vb:row{vb:text{text = "Templates", font = "bold"}},
    template_buttons,
    
    vb:space{height = 5},
    
    vb:row{vb:text{text = "Pattern Integration", font = "bold"}},
    pattern_buttons,
    
    vb:space{height = 5},
    
    vb:row{vb:text{text = "Live Recording", font = "bold"}},
    record_buttons,
    
    vb:space{height = 5},
    
    vb:row{vb:text{text = "Settings", font = "bold"}},
    settings_row,
    
    vb:space{height = 5},
    
    -- Sequencer Snapshot Section
    vb:row{vb:text{text = "Sequencer Snapshots", font = "bold"}},
    vb:row{
      spacing = 2,
      vb:button{
        text = "Snap 8120",
        width = 70,
        notifier = function()
          local state_idx = PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1
          PakettiPhraseGridSnapshot8120ToState(state_idx)
        end
      },
      vb:button{
        text = "Snap Gater",
        width = 70,
        notifier = function()
          local state_idx = PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1
          PakettiPhraseGridSnapshotGaterToState(state_idx)
        end
      },
      vb:button{
        text = "Snap SliceSeq",
        width = 80,
        notifier = function()
          local state_idx = PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1
          PakettiPhraseGridSnapshotSliceStepToState(state_idx)
        end
      },
      vb:button{
        text = "Snap All",
        width = 60,
        notifier = function()
          local state_idx = PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1
          PakettiPhraseGridSnapshotAllSequencersToState(state_idx)
        end
      },
    },
    vb:row{
      vb:checkbox{
        value = PakettiPhraseGridAutoRestoreSequencers,
        notifier = function(value)
          PakettiPhraseGridAutoRestoreSequencers = value
        end
      },
      vb:text{text = "Auto-restore sequencers on state recall"},
    },
    
    vb:space{height = 5},
    
    -- Stacker Integration Section
    vb:row{vb:text{text = "Stacker Integration", font = "bold"}},
    vb:row{
      vb:text{text = "Status: "},
      vb:text{
        text = (function()
          if PakettiStackerIsVelocityStacked and PakettiStackerIsVelocityStacked() then
            local layers = PakettiStackerGetVelocityLayers and PakettiStackerGetVelocityLayers() or {}
            return string.format("STACKED (%d layers)", #layers)
          else
            return "Not stacked"
          end
        end)(),
        style = (PakettiStackerIsVelocityStacked and PakettiStackerIsVelocityStacked()) and "strong" or "disabled"
      },
      vb:button{
        text = "Studio",
        width = 50,
        notifier = function()
          if PakettiStackerPhraseStudioShow then
            PakettiStackerPhraseStudioShow()
          end
        end
      }
    },
    vb:row{
      spacing = 2,
      vb:button{
        text = "Velocity Phrases",
        width = 90,
        notifier = function()
          if PakettiStackerCreateVelocityPhrases then
            PakettiStackerCreateVelocityPhrases()
          else
            renoise.app():show_status("Stacker not available")
          end
        end
      },
      vb:button{
        text = "Cycle Phrase",
        width = 80,
        notifier = function()
          if PakettiStackerCreateVelocityCyclePhrase then
            PakettiStackerCreateVelocityCyclePhrase()
          else
            renoise.app():show_status("Stacker not available")
          end
        end
      },
      vb:button{
        text = "Random Phrase",
        width = 85,
        notifier = function()
          if PakettiStackerCreateRandomVelocityPhrase then
            PakettiStackerCreateRandomVelocityPhrase(16)
          else
            renoise.app():show_status("Stacker not available")
          end
        end
      },
      vb:button{
        text = "Create Bank",
        width = 75,
        notifier = function()
          if PakettiStackerCreatePhraseBankFromStacked then
            PakettiStackerCreatePhraseBankFromStacked()
          else
            renoise.app():show_status("Stacker not available")
          end
        end
      },
    },
    
    vb:space{height = 5},
    
    -- Output Mode Section
    vb:row{vb:text{text = "Sequencer Output Mode", font = "bold"}},
    vb:row{
      spacing = 5,
      vb:text{text = "8120:"},
      vb:popup{
        width = 80,
        items = {"Pattern", "Phrase", "Triggers"},
        value = (PakettiEightOneTwentyOutputMode == "pattern" and 1) or (PakettiEightOneTwentyOutputMode == "phrase" and 2) or 3,
        notifier = function(value)
          local modes = {"pattern", "phrase", "phrase_trigger"}
          if PakettiEightOneTwentySetOutputMode then
            PakettiEightOneTwentySetOutputMode(modes[value])
          end
        end
      },
      vb:text{text = "Gater:"},
      vb:popup{
        width = 70,
        items = {"Pattern", "Phrase"},
        value = (PakettiGaterOutputMode == "pattern" and 1) or 2,
        notifier = function(value)
          local modes = {"pattern", "phrase"}
          if PakettiGaterSetOutputMode then
            PakettiGaterSetOutputMode(modes[value])
          end
        end
      },
      vb:text{text = "SliceSeq:"},
      vb:popup{
        width = 70,
        items = {"Pattern", "Phrase"},
        value = (PakettiSliceStepOutputMode == "pattern" and 1) or 2,
        notifier = function(value)
          local modes = {"pattern", "phrase"}
          if PakettiSliceStepSetOutputMode then
            PakettiSliceStepSetOutputMode(modes[value])
          end
        end
      },
    },
    
    vb:space{height = 5},
    
    vb:row{
      spacing = 5,
      vb:button{
        text = "Clear All States",
        width = 100,
        notifier = function()
          PakettiPhraseGridClearAll()
          PakettiPhraseGridDialog:close()
          PakettiPhraseGridShowDialog()
        end
      },
      vb:button{
        text = "Close",
        width = 60,
        notifier = function()
          PakettiPhraseGridDialog:close()
        end
      },
    },
  }
  
  PakettiPhraseGridDialog = renoise.app():show_custom_dialog(
    "Paketti PhraseGrid",
    content,
    my_keyhandler_func
  )
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

--------------------------------------------------------------------------------
-- 15. KEYBINDINGS
--------------------------------------------------------------------------------

-- Phrase Transport
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Transport Toggle", invoke=PakettiPhraseTransportToggle}
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Transport Arm Offset", invoke=function() PakettiPhraseTransportArmOffset(0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Transport Clear Offset", invoke=PakettiPhraseTransportClearOffset}

-- Phrase Switcher - Inject phrases 01-16
for i = 1, 16 do
  local phrase_num = string.format("%02d", i)
  renoise.tool():add_keybinding{
    name="Global:Paketti:Switch to Phrase " .. phrase_num,
    invoke=function() PakettiPhraseSwitcherInject(i) end
  }
end

-- Phrase Switcher - Mode and Quant cycling
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Switcher Cycle Launch Mode", invoke=PakettiPhraseSwitcherCycleLaunchMode}
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Switcher Cycle Quantization", invoke=PakettiPhraseSwitcherCycleQuant}
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Switcher Stop", invoke=function() PakettiPhraseSwitcherStop() end}

-- PhraseGrid - Store states 01-16
for i = 1, 16 do
  local state_num = string.format("%02d", i)
  renoise.tool():add_keybinding{
    name="Global:Paketti:PhraseGrid Store State " .. state_num,
    invoke=function() PakettiPhraseGridStore(i) end
  }
end

-- PhraseGrid - Recall states 01-16
for i = 1, 16 do
  local state_num = string.format("%02d", i)
  renoise.tool():add_keybinding{
    name="Global:Paketti:PhraseGrid Recall State " .. state_num,
    invoke=function() PakettiPhraseGridRecall(i) end
  }
end

-- PhraseGrid - UI
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Dialog", invoke=PakettiPhraseGridShowDialog}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Popup", invoke=PakettiPhraseGridShowPopup}

-- Phrase Banks
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Bank Next", invoke=PakettiPhraseBankNext}
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Bank Previous", invoke=PakettiPhraseBankPrevious}

-- Bank slots 1-8
for i = 1, 8 do
  renoise.tool():add_keybinding{
    name="Global:Paketti:Phrase Bank Trigger Slot " .. i,
    invoke=function() PakettiPhraseBankTriggerSlot(i) end
  }
end

-- Pattern Integration
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Auto-Fill Pattern", invoke=function() PakettiPhraseAutoFillPattern() end}
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Auto-Fill With Variation", invoke=PakettiPhraseAutoFillWithVariation}
renoise.tool():add_keybinding{name="Global:Paketti:Phrase to Pattern", invoke=function() PakettiPhraseToPattern() end}
renoise.tool():add_keybinding{name="Global:Paketti:Pattern to Phrase", invoke=PakettiPatternToPhrase}

-- Templates
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Template From Slices", invoke=PakettiPhraseTemplateFromSlices}
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Template Drum Basic", invoke=function() PakettiPhraseTemplateDrum("basic") end}
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Template Arp Ascending", invoke=function() PakettiPhraseTemplateArp("ascending", 12) end}

-- Live Recording
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Live Record Arm", invoke=PakettiPhraseLiveRecordArm}
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Live Record Start", invoke=PakettiPhraseLiveRecordStart}
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Live Record Stop", invoke=PakettiPhraseLiveRecordStop}
renoise.tool():add_keybinding{name="Global:Paketti:Phrase Live Record Apply", invoke=PakettiPhraseLiveRecordApply}

-- Sequencer Snapshot Controls
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Toggle Auto-Restore Sequencers", invoke=PakettiPhraseGridToggleAutoRestoreSequencers}

-- Snapshot 8120 to current state
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Snapshot 8120 to Current State", invoke=function()
  PakettiPhraseGridSnapshot8120ToState(PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1)
end}

-- Snapshot Gater to current state
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Snapshot Gater to Current State", invoke=function()
  PakettiPhraseGridSnapshotGaterToState(PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1)
end}

-- Snapshot SliceStep to current state
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Snapshot SliceStep to Current State", invoke=function()
  PakettiPhraseGridSnapshotSliceStepToState(PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1)
end}

-- Snapshot All Sequencers to current state
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Snapshot All Sequencers to Current State", invoke=function()
  PakettiPhraseGridSnapshotAllSequencersToState(PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1)
end}

-- Quick Flicks keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flicks Toggle Output Mode", invoke=PakettiQuickFlicksToggleOutputMode}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flicks Dialog", invoke=PakettiQuickFlicksShowDialog}

-- Quick Range Selection
renoise.tool():add_keybinding{name="Global:Paketti:Quick Select Lines 1-16", invoke=PakettiQuickFlicksSelectRange_0_16}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Select Lines 17-32", invoke=PakettiQuickFlicksSelectRange_16_32}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Select Lines 33-48", invoke=PakettiQuickFlicksSelectRange_32_48}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Select Lines 49-64", invoke=PakettiQuickFlicksSelectRange_48_64}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Select Full Pattern", invoke=PakettiQuickFlicksSelectFullPattern}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Select First Half", invoke=PakettiQuickFlicksSelectFirstHalf}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Select Second Half", invoke=PakettiQuickFlicksSelectSecondHalf}

-- Quick Flicks - Volume Ramps
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Volume Ramp Up", invoke=function() PakettiQuickFlickVolumeRampUp() end}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Volume Ramp Down", invoke=function() PakettiQuickFlickVolumeRampDown() end}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Volume Gate 1010", invoke=function() PakettiQuickFlickVolumeGate(nil, nil, "1010") end}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Volume Gate 1100", invoke=function() PakettiQuickFlickVolumeGate(nil, nil, "1100") end}

-- Quick Flicks - Cuts
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Cut 0C00", invoke=function() PakettiQuickFlickCutPattern(nil, nil, 0x00) end}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Cut 0C80", invoke=function() PakettiQuickFlickCutPattern(nil, nil, 0x80) end}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Cut 0CF0", invoke=function() PakettiQuickFlickCutPattern(nil, nil, 0xF0) end}

-- Quick Flicks - Retrig
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Retrig R01", invoke=function() PakettiQuickFlickRetrig(nil, nil, 1, "flat") end}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Retrig R02", invoke=function() PakettiQuickFlickRetrig(nil, nil, 2, "flat") end}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Retrig R04", invoke=function() PakettiQuickFlickRetrig(nil, nil, 4, "flat") end}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Retrig R08", invoke=function() PakettiQuickFlickRetrig(nil, nil, 8, "flat") end}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Retrig Volume Up", invoke=function() PakettiQuickFlickRetrig(nil, nil, 4, "up") end}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Retrig Volume Down", invoke=function() PakettiQuickFlickRetrig(nil, nil, 4, "down") end}

-- Quick Flicks - Slices
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Slice Sequential", invoke=function() PakettiQuickFlickSliceSequential() end}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Slice Reverse", invoke=function() PakettiQuickFlickSliceReverse() end}
renoise.tool():add_keybinding{name="Global:Paketti:Quick Flick Slice Random", invoke=function() PakettiQuickFlickSliceRandom() end}

-- Voice Orchestration Keybindings (NEW)
-- Voice Spawn (additive)
for i = 1, 16 do
  local phrase_num = string.format("%02d", i)
  renoise.tool():add_keybinding{
    name="Global:Paketti:PhraseVoice Spawn Phrase " .. phrase_num,
    invoke=function() PakettiPhraseVoiceSpawn(i) end
  }
end

-- Voice Toggle (spawn or kill)
for i = 1, 16 do
  local phrase_num = string.format("%02d", i)
  renoise.tool():add_keybinding{
    name="Global:Paketti:PhraseVoice Toggle Phrase " .. phrase_num,
    invoke=function() PakettiPhraseVoiceToggleSpawn(i) end
  }
end

-- Voice Smart Spawn (auto-detect editor/switcher mode)
for i = 1, 16 do
  local phrase_num = string.format("%02d", i)
  renoise.tool():add_keybinding{
    name="Global:Paketti:PhraseVoice Smart Spawn Phrase " .. phrase_num,
    invoke=function() PakettiPhraseVoiceSmartSpawn(i) end
  }
end

-- Voice Kill (stop specific phrase)
for i = 1, 16 do
  local phrase_num = string.format("%02d", i)
  renoise.tool():add_keybinding{
    name="Global:Paketti:PhraseVoice Kill Phrase " .. phrase_num,
    invoke=function() PakettiPhraseVoiceKillPhrase(i) end
  }
end

-- Voice State Recall
for i = 1, 16 do
  local state_num = string.format("%02d", i)
  renoise.tool():add_keybinding{
    name="Global:Paketti:PhraseVoice State Recall " .. state_num,
    invoke=function() PakettiPhraseVoiceStateRecall(i) end
  }
end

-- Voice State Save
for i = 1, 8 do
  renoise.tool():add_keybinding{
    name="Global:Paketti:PhraseVoice State Save " .. i,
    invoke=function() PakettiPhraseVoiceStateSave(i) end
  }
end

-- Voice Control Keybindings
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Kill All", invoke=PakettiPhraseVoiceKillAll}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Toggle Phase Lock", invoke=PakettiPhraseVoiceTogglePhaseLock}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Toggle Output Mode", invoke=PakettiPhraseVoiceToggleOutputMode}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Toggle Operation Mode", invoke=PakettiPhraseVoiceToggleOperationMode}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Clear Pending Queue", invoke=PakettiPhraseVoiceClearPendingQueue}

-- Editor Mode: Spawn Selected and Modular Construction
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Spawn Selected Phrase", invoke=PakettiPhraseVoiceSpawnSelectedPhrase}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Spawn Kick Phrases", invoke=PakettiPhraseVoiceSpawnKick}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Spawn Snare Phrases", invoke=PakettiPhraseVoiceSpawnSnare}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Spawn HiHat Phrases", invoke=PakettiPhraseVoiceSpawnHihat}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Spawn Bass Phrases", invoke=PakettiPhraseVoiceSpawnBass}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Spawn Lead Phrases", invoke=PakettiPhraseVoiceSpawnLead}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Spawn Pad Phrases", invoke=PakettiPhraseVoiceSpawnPad}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Toggle Additive Mode", invoke=function() PakettiPhraseVoiceAdditiveMode = not PakettiPhraseVoiceAdditiveMode renoise.app():show_status("Additive Mode: " .. (PakettiPhraseVoiceAdditiveMode and "ON" or "OFF")) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Toggle Debug Mode", invoke=function() PakettiPhraseVoiceDebugEnabled = not PakettiPhraseVoiceDebugEnabled renoise.app():show_status("Debug Mode: " .. (PakettiPhraseVoiceDebugEnabled and "ON" or "OFF")) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseVoice Toggle Auto-Spawn on Selection", invoke=PakettiPhraseVoiceToggleAutoSpawn}

--------------------------------------------------------------------------------
-- 16. MIDI MAPPINGS
--------------------------------------------------------------------------------

-- Phrase Transport
renoise.tool():add_midi_mapping{name="Paketti:Phrase Transport Toggle", invoke=function(message) if message:is_trigger() then PakettiPhraseTransportToggle() end end}

-- Phrase Switcher - Inject phrases 01-16
for i = 1, 16 do
  local phrase_num = string.format("%02d", i)
  renoise.tool():add_midi_mapping{
    name="Paketti:Switch to Phrase " .. phrase_num,
    invoke=function(message) if message:is_trigger() then PakettiPhraseSwitcherInject(i) end end
  }
end

-- Phrase Switcher - Mode and Quant
renoise.tool():add_midi_mapping{name="Paketti:Phrase Switcher Cycle Launch Mode", invoke=function(message) if message:is_trigger() then PakettiPhraseSwitcherCycleLaunchMode() end end}
renoise.tool():add_midi_mapping{name="Paketti:Phrase Switcher Cycle Quantization", invoke=function(message) if message:is_trigger() then PakettiPhraseSwitcherCycleQuant() end end}
renoise.tool():add_midi_mapping{name="Paketti:Phrase Switcher Stop", invoke=function(message) if message:is_trigger() then PakettiPhraseSwitcherStop() end end}

-- PhraseGrid - Store states 01-16
for i = 1, 16 do
  local state_num = string.format("%02d", i)
  renoise.tool():add_midi_mapping{
    name="Paketti:PhraseGrid Store State " .. state_num,
    invoke=function(message) if message:is_trigger() then PakettiPhraseGridStore(i) end end
  }
end

-- PhraseGrid - Recall states 01-16
for i = 1, 16 do
  local state_num = string.format("%02d", i)
  renoise.tool():add_midi_mapping{
    name="Paketti:PhraseGrid Recall State " .. state_num,
    invoke=function(message) if message:is_trigger() then PakettiPhraseGridRecall(i) end end
  }
end

-- Phrase Banks
renoise.tool():add_midi_mapping{name="Paketti:Phrase Bank Next", invoke=function(message) if message:is_trigger() then PakettiPhraseBankNext() end end}
renoise.tool():add_midi_mapping{name="Paketti:Phrase Bank Previous", invoke=function(message) if message:is_trigger() then PakettiPhraseBankPrevious() end end}

-- Bank slots 1-8
for i = 1, 8 do
  renoise.tool():add_midi_mapping{
    name="Paketti:Phrase Bank Trigger Slot " .. i,
    invoke=function(message) if message:is_trigger() then PakettiPhraseBankTriggerSlot(i) end end
  }
end

-- Live Recording
renoise.tool():add_midi_mapping{name="Paketti:Phrase Live Record Arm", invoke=function(message) if message:is_trigger() then PakettiPhraseLiveRecordArm() end end}
renoise.tool():add_midi_mapping{name="Paketti:Phrase Live Record Start", invoke=function(message) if message:is_trigger() then PakettiPhraseLiveRecordStart() end end}
renoise.tool():add_midi_mapping{name="Paketti:Phrase Live Record Stop", invoke=function(message) if message:is_trigger() then PakettiPhraseLiveRecordStop() end end}

-- Sequencer Snapshot MIDI Mappings
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Toggle Auto-Restore Sequencers [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPhraseGridToggleAutoRestoreSequencers() end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Snapshot 8120 to Current State [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPhraseGridSnapshot8120ToState(PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1) end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Snapshot Gater to Current State [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPhraseGridSnapshotGaterToState(PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1) end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Snapshot SliceStep to Current State [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPhraseGridSnapshotSliceStepToState(PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1) end end}

-- Quick Flicks MIDI Mappings
renoise.tool():add_midi_mapping{name="Paketti:Quick Flicks Toggle Output Mode [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlicksToggleOutputMode() end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Flicks Volume Ramp Up [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlickVolumeRampUp() end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Flicks Volume Ramp Down [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlickVolumeRampDown() end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Flicks Gate 1010 [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlickVolumeGate(nil, nil, "1010") end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Flicks Gate 1100 [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlickVolumeGate(nil, nil, "1100") end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Flicks Cut 0C00 [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlickCutPattern(nil, nil, 0x00) end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Flicks Cut 0C80 [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlickCutPattern(nil, nil, 0x80) end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Flicks Retrig R04 [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlickRetrig(nil, nil, 4, "flat") end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Flicks Slice Sequential [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlickSliceSequential() end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Flicks Slice Random [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlickSliceRandom() end end}

-- Quick Select MIDI Mappings
renoise.tool():add_midi_mapping{name="Paketti:Quick Select Lines 1-16 [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlicksSelectRange_0_16() end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Select Lines 17-32 [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlicksSelectRange_16_32() end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Select Lines 33-48 [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlicksSelectRange_32_48() end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Select Lines 49-64 [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlicksSelectRange_48_64() end end}
renoise.tool():add_midi_mapping{name="Paketti:Quick Select Full Pattern [Trigger]", invoke=function(message) if message:is_trigger() then PakettiQuickFlicksSelectFullPattern() end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Snapshot All Sequencers [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPhraseGridSnapshotAllSequencersToState(PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1) end end}

-- Voice Orchestration MIDI Mappings (NEW)
-- Voice Spawn (additive) 01-16
for i = 1, 16 do
  local phrase_num = string.format("%02d", i)
  renoise.tool():add_midi_mapping{
    name="Paketti:PhraseVoice Spawn Phrase " .. phrase_num .. " [Trigger]",
    invoke=function(message) if message:is_trigger() then PakettiPhraseVoiceSpawn(i) end end
  }
end

-- Voice Toggle (spawn or kill) 01-16
for i = 1, 16 do
  local phrase_num = string.format("%02d", i)
  renoise.tool():add_midi_mapping{
    name="Paketti:PhraseVoice Toggle Phrase " .. phrase_num .. " [Trigger]",
    invoke=function(message) if message:is_trigger() then PakettiPhraseVoiceToggleSpawn(i) end end
  }
end

-- Voice Smart Spawn 01-16
for i = 1, 16 do
  local phrase_num = string.format("%02d", i)
  renoise.tool():add_midi_mapping{
    name="Paketti:PhraseVoice Smart Spawn Phrase " .. phrase_num .. " [Trigger]",
    invoke=function(message) if message:is_trigger() then PakettiPhraseVoiceSmartSpawn(i) end end
  }
end

-- Voice Kill 01-16
for i = 1, 16 do
  local phrase_num = string.format("%02d", i)
  renoise.tool():add_midi_mapping{
    name="Paketti:PhraseVoice Kill Phrase " .. phrase_num .. " [Trigger]",
    invoke=function(message) if message:is_trigger() then PakettiPhraseVoiceKillPhrase(i) end end
  }
end

-- Voice State Recall 01-16
for i = 1, 16 do
  local state_num = string.format("%02d", i)
  renoise.tool():add_midi_mapping{
    name="Paketti:PhraseVoice State Recall " .. state_num .. " [Trigger]",
    invoke=function(message) if message:is_trigger() then PakettiPhraseVoiceStateRecall(i) end end
  }
end

-- Voice State Save 01-08
for i = 1, 8 do
  renoise.tool():add_midi_mapping{
    name="Paketti:PhraseVoice State Save " .. i .. " [Trigger]",
    invoke=function(message) if message:is_trigger() then PakettiPhraseVoiceStateSave(i) end end
  }
end

-- Voice Control MIDI Mappings
renoise.tool():add_midi_mapping{name="Paketti:PhraseVoice Kill All [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPhraseVoiceKillAll() end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseVoice Toggle Phase Lock [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPhraseVoiceTogglePhaseLock() end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseVoice Toggle Output Mode [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPhraseVoiceToggleOutputMode() end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseVoice Toggle Operation Mode [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPhraseVoiceToggleOperationMode() end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseVoice Clear Pending Queue [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPhraseVoiceClearPendingQueue() end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseVoice Toggle Auto-Spawn on Selection [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPhraseVoiceToggleAutoSpawn() end end}

--------------------------------------------------------------------------------
-- 16b. UNIFIED QUICK CAPTURE/RECALL COMMANDS
--------------------------------------------------------------------------------

-- Universal snapshot function - captures ALL connected tool states to a PhraseGrid state
function PakettiPhraseGridQuickCapture(state_index)
  state_index = state_index or (PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1)
  
  -- Ensure state exists
  if not PakettiPhraseGridStates[state_index] then
    PakettiPhraseGridStates[state_index] = PakettiPhraseGridCreateEmptyState()
  end
  local state = PakettiPhraseGridStates[state_index]
  
  local captured = {}
  
  -- Capture 8120 sequencer state
  if PakettiEightOneTwentyGetFullSnapshot then
    local snapshot = PakettiEightOneTwentyGetFullSnapshot()
    if snapshot then
      state.eight_one_twenty = snapshot
      table.insert(captured, "8120")
    end
  end
  
  -- Capture Gater state
  if PakettiGaterGetSnapshot then
    local snapshot = PakettiGaterGetSnapshot()
    if snapshot then
      state.gater = snapshot
      table.insert(captured, "Gater")
    end
  end
  
  -- Capture SliceStep state
  if PakettiSliceStepGetSnapshot then
    local snapshot = PakettiSliceStepGetSnapshot()
    if snapshot then
      state.slice_seq = snapshot
      table.insert(captured, "SliceStep")
    end
  end
  
  -- Capture Canvas device parameters
  if PakettiCanvasExperimentsGetSnapshot then
    local snapshot = PakettiCanvasExperimentsGetSnapshot()
    if snapshot then
      state.device_params = snapshot
      table.insert(captured, "Device Params")
    end
  end
  
  -- Capture Multitap scene
  if PakettiMultitapGetSnapshot then
    local snapshot = PakettiMultitapGetSnapshot()
    if snapshot then
      state.multitap = snapshot
      table.insert(captured, "Multitap")
    end
  end
  
  -- Capture SlicePro analysis
  if PakettiSliceProGetState then
    local snapshot = PakettiSliceProGetState()
    if snapshot and snapshot.total_beats then
      state.slicepro = snapshot
      table.insert(captured, "SlicePro")
    end
  end
  
  -- Capture Phrase Generator settings
  if PakettiPhraseGeneratorGetSettings then
    local snapshot = PakettiPhraseGeneratorGetSettings()
    if snapshot then
      state.generator = snapshot
      table.insert(captured, "Generator")
    end
  end
  
  -- Capture current phrase selection
  local song = renoise.song()
  if song then
    local instrument = song.selected_instrument
    if instrument and #instrument.phrases > 0 then
      state.phrases = state.phrases or {}
      state.phrases[song.selected_instrument_index] = song.selected_phrase_index
      table.insert(captured, "Phrase")
    end
  end
  
  PakettiPhraseGridCurrentState = state_index
  
  if #captured > 0 then
    renoise.app():show_status(string.format("Quick Capture to State %02d: %s", state_index, table.concat(captured, ", ")))
    print("PhraseGrid Quick Capture: State " .. state_index .. " captured: " .. table.concat(captured, ", "))
  else
    renoise.app():show_status(string.format("Quick Capture to State %02d: No tools to capture", state_index))
  end
  
  return captured
end

-- Universal recall function - restores ALL tool states from a PhraseGrid state
function PakettiPhraseGridQuickRecall(state_index)
  state_index = state_index or (PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1)
  
  if not PakettiPhraseGridStates[state_index] then
    renoise.app():show_status("No state at index " .. state_index)
    return {}
  end
  
  local state = PakettiPhraseGridStates[state_index]
  local restored = {}
  
  -- Restore 8120 sequencer state
  if state.eight_one_twenty and PakettiEightOneTwentyRestoreFromFullSnapshot then
    PakettiEightOneTwentyRestoreFromFullSnapshot(state.eight_one_twenty)
    table.insert(restored, "8120")
  end
  
  -- Restore Gater state
  if state.gater and PakettiGaterRestoreFromSnapshot then
    PakettiGaterRestoreFromSnapshot(state.gater)
    table.insert(restored, "Gater")
  end
  
  -- Restore SliceStep state
  if state.slice_seq and PakettiSliceStepRestoreFromSnapshot then
    PakettiSliceStepRestoreFromSnapshot(state.slice_seq)
    table.insert(restored, "SliceStep")
  end
  
  -- Restore Canvas device parameters
  if state.device_params and PakettiCanvasExperimentsRestoreFromSnapshot then
    PakettiCanvasExperimentsRestoreFromSnapshot(state.device_params)
    table.insert(restored, "Device Params")
  end
  
  -- Restore Multitap scene
  if state.multitap and PakettiMultitapRestoreFromSnapshot then
    PakettiMultitapRestoreFromSnapshot(state.multitap)
    table.insert(restored, "Multitap")
  end
  
  -- Restore Phrase Generator settings
  if state.generator and PakettiPhraseGeneratorRestoreSettings then
    PakettiPhraseGeneratorRestoreSettings(state.generator)
    table.insert(restored, "Generator")
  end
  
  -- Restore phrase selections
  if state.phrases then
    local song = renoise.song()
    if song then
      for inst_index, phrase_index in pairs(state.phrases) do
        if song.instruments[inst_index] then
          local instrument = song.instruments[inst_index]
          if instrument.phrases[phrase_index] then
            song.selected_instrument_index = inst_index
            song.selected_phrase_index = phrase_index
            table.insert(restored, "Phrase")
            break  -- Just restore first phrase found for now
          end
        end
      end
    end
  end
  
  PakettiPhraseGridCurrentState = state_index
  
  if #restored > 0 then
    renoise.app():show_status(string.format("Quick Recall State %02d: %s", state_index, table.concat(restored, ", ")))
    print("PhraseGrid Quick Recall: State " .. state_index .. " restored: " .. table.concat(restored, ", "))
  else
    renoise.app():show_status(string.format("Quick Recall State %02d: Nothing to restore", state_index))
  end
  
  return restored
end

-- Context-aware phrase creation - auto-detects what's active and creates appropriate phrases
-- If phrases already exist, writes a trigger to the pattern instead of creating more
function PakettiPhraseGridCreateFromContext()
  local song = renoise.song()
  if not song then return nil end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return nil
  end
  
  -- Check if instrument already has phrases - if so, write trigger to pattern instead
  if #instrument.phrases > 0 then
    -- Phrases exist - write trigger to pattern instead of creating more
    local phrase_index = song.selected_phrase_index or 1
    if phrase_index < 1 then phrase_index = 1 end
    if phrase_index > #instrument.phrases then phrase_index = 1 end
    
    -- Make sure we're on a valid track type
    local track = song.tracks[song.selected_track_index]
    if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
      renoise.app():show_status("Select a sequencer track to write phrase trigger")
      return nil
    end
    
    -- Write note + Zxx to current position in pattern
    local pattern_track = song.selected_pattern:track(song.selected_track_index)
    local line = pattern_track:line(song.selected_line_index)
    local note_col = line:note_column(1)
    
    note_col.note_value = 48  -- C-4
    note_col.instrument_value = song.selected_instrument_index - 1
    note_col.effect_number_value = 0x23  -- Z command (phrase trigger)  -- Z command
    note_col.effect_amount_value = phrase_index
    
    renoise.app():show_status(string.format("Wrote phrase %02d trigger to pattern (instrument has %d phrases)", 
      phrase_index, #instrument.phrases))
    return true
  end
  
  -- No phrases exist - create them based on context
  local result = nil
  
  -- Check for slice markers first
  if instrument.samples[1] then
    local sample = instrument.samples[1]
    if #sample.slice_markers > 0 then
      -- Has slices - use SlicePro if analysis available, otherwise basic slice phrases
      if rawget(_G, "PakettiSliceProGetState") then
        local state = PakettiSliceProGetState()
        if state and state.total_beats then
          if rawget(_G, "PakettiSliceProCreateBeatsyncedPhrases") then
            result = PakettiSliceProCreateBeatsyncedPhrases()
            if result then
              renoise.app():show_status("Created beat-synced phrases from SlicePro analysis")
              return result
            end
          end
        end
      end
      
      -- Fallback to basic slice phrases
      if rawget(_G, "PakettiStemLoaderCreatePhrasesFromSlices") then
        result = PakettiStemLoaderCreatePhrasesFromSlices(song.selected_instrument_index, #sample.slice_markers)
        if result then
          renoise.app():show_status("Created phrases from slice markers")
          return result
        end
      elseif rawget(_G, "PakettiPhraseTemplateFromSlices") then
        PakettiPhraseTemplateFromSlices()
        renoise.app():show_status("Created phrase template from slices")
        return true
      end
    end
  end
  
  -- Check if this looks like a stacked instrument
  if #instrument.samples > 1 then
    local has_velocity_mapping = false
    for _, sample in ipairs(instrument.samples) do
      if sample.sample_mapping and 
         (sample.sample_mapping.velocity_range_start ~= 0 or 
          sample.sample_mapping.velocity_range_end ~= 127) then
        has_velocity_mapping = true
        break
      end
    end
    
    if has_velocity_mapping and rawget(_G, "PakettiStackerCreatePhraseBankFromStacked") then
      PakettiStackerCreatePhraseBankFromStacked()
      renoise.app():show_status("Created velocity layer phrases from stacked instrument")
      return true
    end
  end
  
  -- Check if Phrase Generator is available (API 6.2+)
  if rawget(_G, "PakettiPhraseGeneratorCreateBank") then
    result = PakettiPhraseGeneratorCreateBank()
    if result then
      renoise.app():show_status("Created phrase bank using generator")
      return result
    end
  end
  
  -- Fallback: Create a simple empty phrase
  if rawget(_G, "PakettiPhraseTemplateCreate") then
    PakettiPhraseTemplateCreate("empty", {length = 16})
    renoise.app():show_status("Created empty phrase template")
    return true
  end
  
  renoise.app():show_status("No context-aware phrase creation available")
  return nil
end

-- Quick Capture keybindings
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Capture (Current State)",invoke=function() PakettiPhraseGridQuickCapture() end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Recall (Current State)",invoke=function() PakettiPhraseGridQuickRecall() end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Create From Context",invoke=function() PakettiPhraseGridCreateFromContext() end}

-- Quick Capture keybindings for states 1-8
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Capture to State 1",invoke=function() PakettiPhraseGridQuickCapture(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Capture to State 2",invoke=function() PakettiPhraseGridQuickCapture(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Capture to State 3",invoke=function() PakettiPhraseGridQuickCapture(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Capture to State 4",invoke=function() PakettiPhraseGridQuickCapture(4) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Capture to State 5",invoke=function() PakettiPhraseGridQuickCapture(5) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Capture to State 6",invoke=function() PakettiPhraseGridQuickCapture(6) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Capture to State 7",invoke=function() PakettiPhraseGridQuickCapture(7) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Capture to State 8",invoke=function() PakettiPhraseGridQuickCapture(8) end}

-- Quick Recall keybindings for states 1-8
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Recall State 1",invoke=function() PakettiPhraseGridQuickRecall(1) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Recall State 2",invoke=function() PakettiPhraseGridQuickRecall(2) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Recall State 3",invoke=function() PakettiPhraseGridQuickRecall(3) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Recall State 4",invoke=function() PakettiPhraseGridQuickRecall(4) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Recall State 5",invoke=function() PakettiPhraseGridQuickRecall(5) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Recall State 6",invoke=function() PakettiPhraseGridQuickRecall(6) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Recall State 7",invoke=function() PakettiPhraseGridQuickRecall(7) end}
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Quick Recall State 8",invoke=function() PakettiPhraseGridQuickRecall(8) end}

-- Quick Capture MIDI mappings
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Quick Capture [Trigger]",invoke=function(message) if message:is_trigger() then PakettiPhraseGridQuickCapture() end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Quick Recall [Trigger]",invoke=function(message) if message:is_trigger() then PakettiPhraseGridQuickRecall() end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Create From Context [Trigger]",invoke=function(message) if message:is_trigger() then PakettiPhraseGridCreateFromContext() end end}

-- State-specific MIDI mappings
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Quick Capture State 1 [Trigger]",invoke=function(message) if message:is_trigger() then PakettiPhraseGridQuickCapture(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Quick Capture State 2 [Trigger]",invoke=function(message) if message:is_trigger() then PakettiPhraseGridQuickCapture(2) end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Quick Capture State 3 [Trigger]",invoke=function(message) if message:is_trigger() then PakettiPhraseGridQuickCapture(3) end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Quick Capture State 4 [Trigger]",invoke=function(message) if message:is_trigger() then PakettiPhraseGridQuickCapture(4) end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Quick Recall State 1 [Trigger]",invoke=function(message) if message:is_trigger() then PakettiPhraseGridQuickRecall(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Quick Recall State 2 [Trigger]",invoke=function(message) if message:is_trigger() then PakettiPhraseGridQuickRecall(2) end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Quick Recall State 3 [Trigger]",invoke=function(message) if message:is_trigger() then PakettiPhraseGridQuickRecall(3) end end}
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Quick Recall State 4 [Trigger]",invoke=function(message) if message:is_trigger() then PakettiPhraseGridQuickRecall(4) end end}

--------------------------------------------------------------------------------
-- 16c. UNIFIED PERFORMANCE DIALOG
--------------------------------------------------------------------------------

PakettiPhraseGridPerformanceDialog = nil
PakettiPhraseGridPerformanceVb = nil

-- Create state trigger buttons grid (4 rows of 8)
function PakettiPhraseGridCreateStateTriggerGrid(vb)
  local grid = vb:column{spacing = 2}
  
  for row = 0, 3 do
    local row_content = vb:row{spacing = 2}
    for col = 1, 8 do
      local state_index = row * 8 + col
      local button_style = "button"
      local button_text = string.format("%02d", state_index)
      
      -- Check if state has content
      if PakettiPhraseGridStates[state_index] then
        local state = PakettiPhraseGridStates[state_index]
        local has_content = false
        if state.phrases and next(state.phrases) then has_content = true end
        if state.eight_one_twenty then has_content = true end
        if state.gater then has_content = true end
        if state.device_params then has_content = true end
        if state.multitap then has_content = true end
        
        if has_content then
          button_style = "button"
          button_text = string.format("%02d*", state_index)
        end
      end
      
      row_content:add_child(vb:button{
        id = "perf_state_" .. state_index,
        text = button_text,
        width = 36,
        height = 28,
        color = (state_index == PakettiPhraseGridCurrentState) and {0x60, 0x90, 0x60} or nil,
        notifier = function()
          PakettiPhraseGridQuickRecall(state_index)
        end
      })
    end
    grid:add_child(row_content)
  end
  
  return grid
end

--------------------------------------------------------------------------------
-- PREREQUISITE CHECKING FUNCTIONS
-- Check if various tools have the required state to perform their actions
--------------------------------------------------------------------------------

-- Check if SlicePro has beat analysis ready
function PakettiPhraseGridCheckSliceProReady()
  local song = renoise.song()
  if not song then return false, "No song loaded" end
  local sample = song.selected_sample
  if not sample or not sample.sample_buffer.has_sample_data then
    return false, "No sample selected"
  end
  -- Check if SlicePro functions exist
  if not rawget(_G, "PakettiSliceProCreateBeatsyncedPhrases") then
    return false, "SlicePro not loaded"
  end
  -- Check for beat analysis data (stored in global state)
  if rawget(_G, "PakettiSliceProState") then
    if PakettiSliceProState.beats and #PakettiSliceProState.beats > 0 then
      return true, "Ready (" .. #PakettiSliceProState.beats .. " beats)"
    end
  end
  return false, "No beat analysis"
end

-- Check if Stem Loader can create phrases
function PakettiPhraseGridCheckStemLoaderReady()
  local song = renoise.song()
  if not song then return false, "No song loaded" end
  -- Check if function exists
  if not rawget(_G, "PakettiStemLoaderCreatePhrasesNow") then
    return false, "Stem Loader not loaded"
  end
  -- Check for slices in current instrument
  local instrument = song.selected_instrument
  if not instrument then return false, "No instrument selected" end
  local first_sample = instrument.samples[1]
  if not first_sample or not first_sample.sample_buffer.has_sample_data then
    return false, "No sample in instrument"
  end
  local slice_count = #first_sample.slice_markers
  if slice_count == 0 then
    return false, "No slices in sample"
  end
  return true, "Ready (" .. slice_count .. " slices)"
end

-- Check if Generator can create a bank
function PakettiPhraseGridCheckGeneratorReady()
  local song = renoise.song()
  if not song then return false, "No song loaded" end
  -- Check if function exists
  if not rawget(_G, "PakettiPhraseGeneratorCreateBank") then
    return false, "Generator not loaded (API 6.2+)"
  end
  local instrument = song.selected_instrument
  if not instrument then return false, "No instrument selected" end
  return true, "Ready"
end

-- Check if Multitap can create echo phrase
function PakettiPhraseGridCheckMultitapReady()
  local song = renoise.song()
  if not song then return false, "No song loaded" end
  -- Check if function exists
  if not rawget(_G, "PakettiMultitapCreateEchoPhrase") then
    return false, "Multitap not loaded"
  end
  -- Check for Multitap device on current track
  local track = song.selected_track
  if track then
    for _, device in ipairs(track.devices) do
      if device.name and device.name:match("Multitap") then
        return true, "Ready (device found)"
      end
    end
  end
  return false, "No Multitap device on track"
end

-- Check if slices can be converted to bank
function PakettiPhraseGridCheckSlicesToBankReady()
  local song = renoise.song()
  if not song then return false, "No song loaded" end
  local instrument = song.selected_instrument
  if not instrument then return false, "No instrument selected" end
  local first_sample = instrument.samples[1]
  if not first_sample or not first_sample.sample_buffer.has_sample_data then
    return false, "No sample in instrument"
  end
  local slice_count = #first_sample.slice_markers
  if slice_count == 0 then
    return false, "No slices - will auto-slice"
  end
  return true, "Ready (" .. slice_count .. " slices)"
end

--------------------------------------------------------------------------------
-- SMART WRAPPER FUNCTIONS
-- Handle prerequisites gracefully with fallback behaviors
--------------------------------------------------------------------------------

-- Smart SlicePro Sync - opens dialog or analyzes if not ready
function PakettiPhraseGridSliceProSyncSmart()
  local ready, reason = PakettiPhraseGridCheckSliceProReady()
  if ready then
    PakettiSliceProCreateBeatsyncedPhrases()
    renoise.app():show_status("Beat-synced phrases created from SlicePro analysis")
  else
    if reason == "SlicePro not loaded" then
      renoise.app():show_status("SlicePro module not available")
    elseif reason == "No sample selected" then
      renoise.app():show_status("Select a sample first, then try again")
    elseif reason == "No beat analysis" then
      -- Try to open SlicePro dialog
      if rawget(_G, "PakettiSliceProShowDialog") then
        PakettiSliceProShowDialog()
        renoise.app():show_status("SlicePro opened - run beat analysis, then use Sync")
      elseif rawget(_G, "pakettiSliceProInit") then
        pakettiSliceProInit()
        renoise.app():show_status("SlicePro opened - run beat analysis, then use Sync")
      else
        renoise.app():show_status("Run SlicePro beat analysis first: Tools > Paketti > SlicePro")
      end
    else
      renoise.app():show_status("SlicePro: " .. reason)
    end
  end
end

-- Smart Stem Phrases - creates phrases or guides user
function PakettiPhraseGridStemPhrasesSmart()
  local ready, reason = PakettiPhraseGridCheckStemLoaderReady()
  if ready then
    PakettiStemLoaderCreatePhrasesNow()
    renoise.app():show_status("Phrases created from stem slices")
  else
    if reason == "Stem Loader not loaded" then
      renoise.app():show_status("Stem Loader module not available")
    elseif reason == "No slices in sample" then
      -- Offer to auto-slice
      if rawget(_G, "slicerough") then
        slicerough(8)
        renoise.app():show_status("Auto-sliced sample into 8 parts - click again to create phrases")
      else
        renoise.app():show_status("No slices found. Load stems or slice sample first.")
      end
    elseif reason == "No sample in instrument" then
      -- Try to open Stem Loader
      if rawget(_G, "PakettiStemLoaderShowDialog") then
        PakettiStemLoaderShowDialog()
        renoise.app():show_status("Stem Loader opened - load stems, then create phrases")
      else
        renoise.app():show_status("Load a sample first, or use Tools > Paketti > Stem Loader")
      end
    else
      renoise.app():show_status("Stem Phrases: " .. reason)
    end
  end
end

-- Smart Generator Bank - creates phrases or shows status
function PakettiPhraseGridGeneratorBankSmart()
  local ready, reason = PakettiPhraseGridCheckGeneratorReady()
  if ready then
    PakettiPhraseGeneratorCreateBank()
    renoise.app():show_status("Phrase bank created with 8 variations")
  else
    if reason:match("not loaded") then
      renoise.app():show_status("Phrase Generator requires Renoise API 6.2+")
    else
      renoise.app():show_status("Generator: " .. reason)
    end
  end
end

-- Smart Multitap Echo - inserts device if needed or creates phrase
function PakettiPhraseGridMultitapEchoSmart()
  local ready, reason = PakettiPhraseGridCheckMultitapReady()
  if ready then
    PakettiMultitapCreateEchoPhrase()
    renoise.app():show_status("Echo phrase created from Multitap settings")
  else
    if reason == "Multitap not loaded" then
      renoise.app():show_status("Multitap module not available")
    elseif reason == "No Multitap device on track" then
      -- Try to open Multitap dialog which will ensure device exists
      if rawget(_G, "PakettiMultitapExperimentInit") then
        PakettiMultitapExperimentInit()
        renoise.app():show_status("Multitap opened - configure delays, then create echo phrase")
      else
        renoise.app():show_status("Add a Multitap device to the track first")
      end
    else
      renoise.app():show_status("Multitap: " .. reason)
    end
  end
end

-- Smart Slices to Bank - auto-slices if needed
function PakettiPhraseGridSlicesToBankSmart()
  local ready, reason = PakettiPhraseGridCheckSlicesToBankReady()
  if ready then
    PakettiSlicesToPhraseBank()
    renoise.app():show_status("Phrase bank created from slices")
  else
    if reason == "No slices - will auto-slice" then
      -- Auto-slice then create bank
      if rawget(_G, "slicerough") then
        slicerough(8)
        -- Now try again
        local song = renoise.song()
        if song and song.selected_instrument then
          local first_sample = song.selected_instrument.samples[1]
          if first_sample and #first_sample.slice_markers > 0 then
            PakettiSlicesToPhraseBank()
            renoise.app():show_status("Auto-sliced into 8 parts and created phrase bank")
            return
          end
        end
        renoise.app():show_status("Sample sliced - click again to create phrase bank")
      else
        renoise.app():show_status("No slices found. Slice the sample first.")
      end
    elseif reason == "No sample in instrument" then
      renoise.app():show_status("Load a sample first")
    else
      renoise.app():show_status("Slices to Bank: " .. reason)
    end
  end
end

-- Create integration status panel
function PakettiPhraseGridCreateIntegrationStatus(vb)
  local status = vb:column{
    style = "group",
    margin = 5,
    vb:text{text = "Integration Status", font = "bold"},
    vb:row{
      spacing = 10,
      vb:column{
        vb:row{
          vb:checkbox{id = "perf_8120_available", value = (rawget(_G, "PakettiEightOneTwentyGetFullSnapshot") ~= nil), active = false},
          vb:text{text = "8120"}
        },
        vb:row{
          vb:checkbox{id = "perf_gater_available", value = (rawget(_G, "PakettiGaterGetSnapshot") ~= nil), active = false},
          vb:text{text = "Gater"}
        },
        vb:row{
          vb:checkbox{id = "perf_slice_available", value = (rawget(_G, "PakettiSliceStepGetSnapshot") ~= nil), active = false},
          vb:text{text = "SliceStep"}
        }
      },
      vb:column{
        vb:row{
          vb:checkbox{id = "perf_canvas_available", value = (rawget(_G, "PakettiCanvasExperimentsGetSnapshot") ~= nil), active = false},
          vb:text{text = "Device Params"}
        },
        vb:row{
          vb:checkbox{id = "perf_multitap_available", value = (rawget(_G, "PakettiMultitapGetSnapshot") ~= nil), active = false},
          vb:text{text = "Multitap"}
        },
        vb:row{
          vb:checkbox{id = "perf_generator_available", value = (rawget(_G, "PakettiPhraseGeneratorGetSettings") ~= nil), active = false},
          vb:text{text = "Generator"}
        }
      }
    }
  }
  
  return status
end

-- Create quick action buttons
function PakettiPhraseGridCreateQuickActions(vb)
  -- Get current status for tooltips
  local slicepro_ready, slicepro_status = PakettiPhraseGridCheckSliceProReady()
  local stem_ready, stem_status = PakettiPhraseGridCheckStemLoaderReady()
  local generator_ready, generator_status = PakettiPhraseGridCheckGeneratorReady()
  local multitap_ready, multitap_status = PakettiPhraseGridCheckMultitapReady()
  
  local actions = vb:column{
    style = "group",
    margin = 5,
    vb:text{text = "Quick Actions", font = "bold"},
    vb:row{
      spacing = 5,
      vb:button{
        text = "Capture",
        width = 60,
        tooltip = "Quick Capture current state of all tools",
        notifier = function() PakettiPhraseGridQuickCapture() end
      },
      vb:button{
        text = "Recall",
        width = 60,
        tooltip = "Quick Recall current state",
        notifier = function() PakettiPhraseGridQuickRecall() end
      },
      vb:button{
        text = "Create",
        width = 60,
        tooltip = "Create phrases from context",
        notifier = function() PakettiPhraseGridCreateFromContext() end
      }
    },
    vb:row{
      spacing = 5,
      vb:button{
        text = stem_ready and "Stem Phrases" or "Stem...",
        width = 90,
        tooltip = "Stem Phrases: " .. stem_status .. "\nClick to create phrases or open Stem Loader",
        notifier = function()
          PakettiPhraseGridStemPhrasesSmart()
        end
      },
      vb:button{
        text = slicepro_ready and "SlicePro Sync" or "SlicePro...",
        width = 90,
        tooltip = "SlicePro Sync: " .. slicepro_status .. "\nClick to create phrases or open SlicePro",
        notifier = function()
          PakettiPhraseGridSliceProSyncSmart()
        end
      }
    },
    vb:row{
      spacing = 5,
      vb:button{
        text = generator_ready and "Generator Bank" or "Generator...",
        width = 90,
        tooltip = "Generator Bank: " .. generator_status .. "\nClick to create 8 phrase variations",
        notifier = function()
          PakettiPhraseGridGeneratorBankSmart()
        end
      },
      vb:button{
        text = multitap_ready and "Multitap Echo" or "Multitap...",
        width = 90,
        tooltip = "Multitap Echo: " .. multitap_status .. "\nClick to create echo phrase or open Multitap",
        notifier = function()
          PakettiPhraseGridMultitapEchoSmart()
        end
      }
    }
  }
  
  return actions
end

-- Create current state info panel
function PakettiPhraseGridCreateStateInfo(vb)
  local state_index = PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 0
  local state = PakettiPhraseGridStates[state_index]
  
  local info_text = "No state selected"
  if state_index > 0 and state then
    local parts = {}
    if state.name and state.name ~= "" then
      table.insert(parts, "Name: " .. state.name)
    end
    if state.phrases and next(state.phrases) then
      local count = 0
      for _ in pairs(state.phrases) do count = count + 1 end
      table.insert(parts, "Phrases: " .. count)
    end
    if state.eight_one_twenty then table.insert(parts, "8120") end
    if state.gater then table.insert(parts, "Gater") end
    if state.device_params then table.insert(parts, "DevParams") end
    if state.multitap then table.insert(parts, "Multitap") end
    if state.slicepro then table.insert(parts, "SlicePro") end
    if state.generator then table.insert(parts, "Generator") end
    
    if #parts > 0 then
      info_text = "State " .. state_index .. ": " .. table.concat(parts, ", ")
    else
      info_text = "State " .. state_index .. ": Empty"
    end
  end
  
  local info = vb:column{
    style = "group",
    margin = 5,
    vb:text{text = "Current State", font = "bold"},
    vb:text{id = "perf_state_info", text = info_text, width = 280}
  }
  
  return info
end

-- Show unified performance dialog
function PakettiPhraseGridShowPerformanceDialog()
  local song = renoise.song()
  if not song then return end
  
  if PakettiPhraseGridPerformanceDialog and PakettiPhraseGridPerformanceDialog.visible then
    PakettiPhraseGridPerformanceDialog:close()
    PakettiPhraseGridPerformanceDialog = nil
    return
  end
  
  PakettiPhraseGridPerformanceVb = renoise.ViewBuilder()
  local vb = PakettiPhraseGridPerformanceVb
  
  local content = vb:column{
    margin = 10,
    spacing = 8,
    
    -- State trigger grid
    vb:column{
      style = "group",
      margin = 5,
      vb:text{text = "State Triggers (Click to Recall)", font = "bold"},
      PakettiPhraseGridCreateStateTriggerGrid(vb)
    },
    
    vb:row{
      spacing = 10,
      
      -- Left column: Status and Quick Actions
      vb:column{
        spacing = 5,
        PakettiPhraseGridCreateIntegrationStatus(vb),
        PakettiPhraseGridCreateQuickActions(vb)
      },
      
      -- Right column: State info and output mode
      vb:column{
        spacing = 5,
        PakettiPhraseGridCreateStateInfo(vb),
        vb:column{
          style = "group",
          margin = 5,
          vb:text{text = "Output Mode", font = "bold"},
          vb:row{
            spacing = 5,
            vb:text{text = "Quick Flicks:"},
            vb:switch{
              items = {"Pattern", "Phrase"},
              width = 100,
              value = (PakettiQuickFlicksOutputMode == "phrase") and 2 or 1,
              notifier = function(value)
                PakettiQuickFlicksOutputMode = (value == 2) and "phrase" or "pattern"
              end
            }
          },
          vb:row{
            spacing = 5,
            vb:text{text = "8120:"},
            vb:switch{
              items = {"Pattern", "Phrase"},
              width = 100,
              value = (PakettiEightOneTwentyOutputMode == "phrase") and 2 or 1,
              notifier = function(value)
                if PakettiEightOneTwentySetOutputMode then
                  PakettiEightOneTwentySetOutputMode((value == 2) and "phrase" or "pattern")
                end
              end
            }
          }
        }
      }
    },
    
    -- Bottom: Bank and transport controls
    vb:row{
      spacing = 10,
      vb:column{
        style = "group",
        margin = 5,
        vb:text{text = "Phrase Banks", font = "bold"},
        vb:row{
          spacing = 5,
          vb:button{text = "<", width = 30, notifier = function() PakettiPhraseBankPrevious() end},
          vb:text{id = "perf_bank_display", text = string.format("Bank %d", PakettiPhraseBankCurrent or 1), width = 80},
          vb:button{text = ">", width = 30, notifier = function() PakettiPhraseBankNext() end}
        }
      },
      vb:column{
        style = "group",
        margin = 5,
        vb:text{text = "Transport", font = "bold"},
        vb:row{
          spacing = 5,
          vb:checkbox{
            value = PakettiPhraseTransportEnabled or false,
            notifier = function(value)
              if value then
                PakettiPhraseTransportEnable()
              else
                PakettiPhraseTransportDisable()
              end
            end
          },
          vb:text{text = "Phrase Transport"}
        },
        vb:row{
          spacing = 5,
          vb:checkbox{
            id = "perf_auto_spawn_cb",
            value = PakettiPhraseVoiceAutoSpawnEnabled or false,
            notifier = function(value)
              PakettiPhraseVoiceAutoSpawnEnabled = value
              PakettiPhraseVoiceSavePreferences()
              if value and PakettiPhraseTransportEnabled then
                PakettiPhraseVoiceAddSelectionNotifier()
              elseif not value then
                PakettiPhraseVoiceRemoveSelectionNotifier()
              end
            end
          },
          vb:text{text = "Auto-Spawn on Selection"}
        }
      }
    },
    
    -- Render Controls Section
    vb:column{
      style = "group",
      margin = 5,
      vb:text{text = "Render to Phrase", font = "bold"},
      vb:row{
        spacing = 5,
        vb:button{
          text = "Render Pattern",
          width = 90,
          tooltip = "Render current track to sample, slice into 8 parts, create phrases",
          notifier = function()
            PakettiRenderPatternToPhrase({slice_count = 8, normalize = true, create_phrases = true, add_to_bank = true})
          end
        },
        vb:button{
          text = "Render + Slice",
          width = 80,
          tooltip = "Render track and auto-detect beat divisions for slicing",
          notifier = function()
            PakettiRenderAndAutoSlice({normalize = true})
          end
        },
        vb:button{
          text = "Full Stack",
          width = 70,
          tooltip = "Render, slice, and create velocity-stacked instrument with phrases",
          notifier = function()
            PakettiFullRenderStackWorkflow({slice_count = 8})
          end
        }
      },
      vb:row{
        spacing = 5,
        vb:button{
          text = "Slices→Bank",
          width = 80,
          tooltip = "Convert slices to phrase bank (auto-slices if needed)",
          notifier = function()
            PakettiPhraseGridSlicesToBankSmart()
          end
        },
        vb:button{
          text = "Rearrange",
          width = 70,
          tooltip = "Place slices sequentially on new track",
          notifier = function()
            PakettiRearrangeTrackFromSlices()
          end
        },
        vb:button{
          text = "Random",
          width = 60,
          tooltip = "Place slices in random order on new track",
          notifier = function()
            PakettiRearrangeTrackFromSlices({randomize = true})
          end
        }
      }
    },
    
    -- Stacker Phrase Controls (for existing velocity-stacked instruments)
    vb:column{
      style = "group",
      margin = 5,
      vb:text{text = "Stacker Phrases (Velocity-Mapped)", font = "bold"},
      vb:row{
        vb:text{text = "Status: "},
        vb:text{
          text = (function()
            if PakettiStackerIsVelocityStacked and PakettiStackerIsVelocityStacked() then
              local layers = PakettiStackerGetVelocityLayers and PakettiStackerGetVelocityLayers() or {}
              return string.format("STACKED (%d layers)", #layers)
            else
              return "Not stacked"
            end
          end)(),
          style = (PakettiStackerIsVelocityStacked and PakettiStackerIsVelocityStacked()) and "strong" or "disabled"
        },
        vb:button{
          text = "Studio",
          width = 50,
          tooltip = "Open Stacker Phrase Studio dialog",
          notifier = function()
            if PakettiStackerPhraseStudioShow then
              PakettiStackerPhraseStudioShow()
            else
              renoise.app():show_status("Stacker Phrase Studio not loaded")
            end
          end
        }
      },
      vb:row{
        spacing = 5,
        vb:button{
          text = "Layer",
          width = 50,
          tooltip = "Create one phrase per velocity layer (for live switching)",
          notifier = function()
            if PakettiStackerCreateVelocityPhrases then
              PakettiStackerCreateVelocityPhrases()
            else
              renoise.app():show_status("Stacker functions not loaded")
            end
          end
        },
        vb:button{
          text = "Cycle",
          width = 50,
          tooltip = "Create phrase that cycles through all velocity layers",
          notifier = function()
            if PakettiStackerCreateVelocityCyclePhrase then
              PakettiStackerCreateVelocityCyclePhrase()
            else
              renoise.app():show_status("Stacker functions not loaded")
            end
          end
        },
        vb:button{
          text = "From Pat",
          width = 60,
          tooltip = "Create phrase from current pattern track (preserves velocities)",
          notifier = function()
            if PakettiStackerCreatePhraseFromPattern then
              PakettiStackerCreatePhraseFromPattern()
            else
              renoise.app():show_status("Stacker functions not loaded")
            end
          end
        },
        vb:button{
          text = "Rnd16",
          width = 45,
          tooltip = "Create random velocity phrase (16 lines)",
          notifier = function()
            if PakettiStackerCreateRandomPhrase16 then
              PakettiStackerCreateRandomPhrase16()
            else
              renoise.app():show_status("Stacker functions not loaded")
            end
          end
        },
        vb:button{
          text = "Sparse",
          width = 50,
          tooltip = "Create sparse random phrase (50% density with rests)",
          notifier = function()
            if PakettiStackerCreateSparseRandomPhrase then
              PakettiStackerCreateSparseRandomPhrase(16)
            else
              renoise.app():show_status("Stacker functions not loaded")
            end
          end
        }
      }
    },
    
    -- Voice Orchestration Section (NEW)
    vb:column{
      style = "group",
      margin = 5,
      vb:text{text = "Voice Orchestration", font = "bold"},
      
      -- Active Voices Display
      vb:row{
        vb:text{text = "Active Voices: "},
        vb:text{
          id = "perf_voice_count",
          text = tostring(#PakettiPhraseVoicePool),
          font = "bold"
        },
        vb:text{text = " / "},
        vb:text{text = tostring(PakettiPhraseVoiceMaxVoices)},
        vb:button{
          text = "Kill All",
          width = 60,
          tooltip = "Stop all phrase voices",
          notifier = function()
            PakettiPhraseVoiceKillAll()
            -- Refresh voice count display
            if PakettiPhraseGridPerformanceVb then
              local count_text = PakettiPhraseGridPerformanceVb.views["perf_voice_count"]
              if count_text then count_text.text = "0" end
            end
          end
        }
      },
      
      -- Voice Output Mode
      vb:row{
        spacing = 5,
        vb:text{text = "Output:"},
        vb:switch{
          items = {"Track", "Column"},
          width = 100,
          value = (PakettiPhraseVoiceOutputMode == "column") and 2 or 1,
          notifier = function(value)
            PakettiPhraseVoiceSetOutputMode((value == 2) and "column" or "track")
          end
        },
        vb:checkbox{
          value = PakettiPhraseVoicePhaseLockEnabled,
          notifier = function(value)
            PakettiPhraseVoicePhaseLockEnabled = value
          end
        },
        vb:text{text = "Phase Lock"}
      },
      
      -- Voice Trigger Grid (8 buttons for phrases 1-8)
      -- Buttons have IDs for highlighting active voices
      vb:row{
        spacing = 2,
        vb:button{id = "voice_btn_01", text = "P01", width = 35, tooltip = "Toggle Phrase 01 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(1) PakettiPhraseVoiceUpdateButtonHighlights() end},
        vb:button{id = "voice_btn_02", text = "P02", width = 35, tooltip = "Toggle Phrase 02 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(2) PakettiPhraseVoiceUpdateButtonHighlights() end},
        vb:button{id = "voice_btn_03", text = "P03", width = 35, tooltip = "Toggle Phrase 03 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(3) PakettiPhraseVoiceUpdateButtonHighlights() end},
        vb:button{id = "voice_btn_04", text = "P04", width = 35, tooltip = "Toggle Phrase 04 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(4) PakettiPhraseVoiceUpdateButtonHighlights() end},
        vb:button{id = "voice_btn_05", text = "P05", width = 35, tooltip = "Toggle Phrase 05 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(5) PakettiPhraseVoiceUpdateButtonHighlights() end},
        vb:button{id = "voice_btn_06", text = "P06", width = 35, tooltip = "Toggle Phrase 06 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(6) PakettiPhraseVoiceUpdateButtonHighlights() end},
        vb:button{id = "voice_btn_07", text = "P07", width = 35, tooltip = "Toggle Phrase 07 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(7) PakettiPhraseVoiceUpdateButtonHighlights() end},
        vb:button{id = "voice_btn_08", text = "P08", width = 35, tooltip = "Toggle Phrase 08 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(8) PakettiPhraseVoiceUpdateButtonHighlights() end}
      },
      vb:row{
        spacing = 2,
        vb:button{id = "voice_btn_09", text = "P09", width = 35, tooltip = "Toggle Phrase 09 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(9) PakettiPhraseVoiceUpdateButtonHighlights() end},
        vb:button{id = "voice_btn_10", text = "P10", width = 35, tooltip = "Toggle Phrase 10 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(10) PakettiPhraseVoiceUpdateButtonHighlights() end},
        vb:button{id = "voice_btn_11", text = "P11", width = 35, tooltip = "Toggle Phrase 11 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(11) PakettiPhraseVoiceUpdateButtonHighlights() end},
        vb:button{id = "voice_btn_12", text = "P12", width = 35, tooltip = "Toggle Phrase 12 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(12) PakettiPhraseVoiceUpdateButtonHighlights() end},
        vb:button{id = "voice_btn_13", text = "P13", width = 35, tooltip = "Toggle Phrase 13 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(13) PakettiPhraseVoiceUpdateButtonHighlights() end},
        vb:button{id = "voice_btn_14", text = "P14", width = 35, tooltip = "Toggle Phrase 14 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(14) PakettiPhraseVoiceUpdateButtonHighlights() end},
        vb:button{id = "voice_btn_15", text = "P15", width = 35, tooltip = "Toggle Phrase 15 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(15) PakettiPhraseVoiceUpdateButtonHighlights() end},
        vb:button{id = "voice_btn_16", text = "P16", width = 35, tooltip = "Toggle Phrase 16 voice", notifier = function() PakettiPhraseVoiceToggleSpawn(16) PakettiPhraseVoiceUpdateButtonHighlights() end}
      },
      
      -- Quantization Control
      vb:row{
        spacing = 5,
        vb:text{text = "Quant:"},
        vb:popup{
          width = 80,
          items = {"Line", "Beat", "Bar", "Custom"},
          value = (function()
            if PakettiPhraseSwitcherDefaultQuant == "line" then return 1
            elseif PakettiPhraseSwitcherDefaultQuant == "beat" then return 2
            elseif PakettiPhraseSwitcherDefaultQuant == "bar" then return 3
            else return 4 end
          end)(),
          notifier = function(value)
            local quants = {"line", "beat", "bar", "custom"}
            PakettiPhraseSwitcherSetDefaultQuant(quants[value])
          end
        },
        vb:text{text = "Custom:"},
        vb:valuebox{
          min = 1,
          max = 64,
          value = PakettiPhraseSwitcherCustomQuant,
          width = 50,
          notifier = function(value)
            PakettiPhraseSwitcherCustomQuant = value
          end
        },
        vb:text{text = "lines"}
      },
      
      -- Voice State Actions
      vb:row{
        spacing = 5,
        vb:button{
          text = "Save Voices",
          width = 80,
          tooltip = "Save active voices as PhraseGrid state",
          notifier = function()
            local state_idx = PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1
            PakettiPhraseVoiceStateSave(state_idx)
          end
        },
        vb:button{
          text = "Clear Pending",
          width = 80,
          tooltip = "Clear scheduled voice queue",
          notifier = function()
            PakettiPhraseVoiceClearPendingQueue()
          end
        }
      }
    },
    
    -- Live Recording Section (from PakettiPhraseTransportRecording)
    vb:column{
      style = "group",
      margin = 5,
      vb:text{text = "Live Phrase Recording", font = "bold"},
      
      -- State display and controls
      vb:row{
        spacing = 5,
        vb:text{text = "State:"},
        vb:text{
          id = "perf_rec_state",
          text = (PakettiPhraseRec_GetStateName and PakettiPhraseRec_GetStateName(PakettiPhraseRec_CurrentState or 1)) or "IDLE",
          font = "bold"
        },
        vb:button{
          id = "perf_rec_arm_btn",
          text = "Arm",
          width = 50,
          tooltip = "Arm phrase recording (MIDI interception begins)",
          notifier = function()
            if PakettiPhraseRec_Arm then
              if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_IDLE then
                PakettiPhraseRec_Arm()
              else
                PakettiPhraseRec_Disarm()
              end
              -- Update state display
              local state_text = vb.views["perf_rec_state"]
              if state_text then
                state_text.text = PakettiPhraseRec_GetStateName(PakettiPhraseRec_CurrentState)
              end
            end
          end
        },
        vb:button{
          id = "perf_rec_rec_btn",
          text = "Record",
          width = 55,
          tooltip = "Start recording to phrase",
          notifier = function()
            if PakettiPhraseRec_StartRecording then
              if PakettiPhraseRec_CurrentState == PakettiPhraseRec_STATE_RECORDING_ACTIVE then
                PakettiPhraseRec_StopRecording()
              else
                PakettiPhraseRec_StartRecording()
              end
              -- Update state display
              local state_text = vb.views["perf_rec_state"]
              if state_text then
                state_text.text = PakettiPhraseRec_GetStateName(PakettiPhraseRec_CurrentState)
              end
            end
          end
        },
        vb:button{
          text = "Stop",
          width = 45,
          tooltip = "Stop recording and disarm",
          notifier = function()
            if PakettiPhraseRec_StopRecording then
              PakettiPhraseRec_StopRecording()
              -- Update state display
              local state_text = vb.views["perf_rec_state"]
              if state_text then
                state_text.text = PakettiPhraseRec_GetStateName(PakettiPhraseRec_CurrentState)
              end
            end
          end
        }
      },
      
      -- MIDI and Quantize settings
      vb:row{
        spacing = 5,
        vb:checkbox{
          value = PakettiPhraseRec_MidiInterceptEnabled or true,
          notifier = function(value)
            if PakettiPhraseRec_MidiInterceptEnabled ~= nil then
              PakettiPhraseRec_MidiInterceptEnabled = value
              if PakettiPhraseRec_SavePreferences then
                PakettiPhraseRec_SavePreferences()
              end
            end
          end
        },
        vb:text{text = "MIDI Intercept"},
        vb:checkbox{
          value = PakettiPhraseRec_QuantizeEnabled or true,
          notifier = function(value)
            if PakettiPhraseRec_QuantizeEnabled ~= nil then
              PakettiPhraseRec_QuantizeEnabled = value
              if PakettiPhraseRec_SavePreferences then
                PakettiPhraseRec_SavePreferences()
              end
            end
          end
        },
        vb:text{text = "Quantize"},
        vb:popup{
          items = {"OFF", "1", "2", "3", "4", "6", "8", "12", "16"},
          value = (function()
            local grid = PakettiPhraseRec_QuantizeGrid or 4
            if grid == 0 then return 1
            elseif grid == 1 then return 2
            elseif grid == 2 then return 3
            elseif grid == 3 then return 4
            elseif grid == 4 then return 5
            elseif grid == 6 then return 6
            elseif grid == 8 then return 7
            elseif grid == 12 then return 8
            elseif grid == 16 then return 9
            else return 5 end
          end)(),
          width = 55,
          notifier = function(idx)
            local grid_values = {0, 1, 2, 3, 4, 6, 8, 12, 16}
            if PakettiPhraseRec_QuantizeGrid ~= nil then
              PakettiPhraseRec_QuantizeGrid = grid_values[idx]
              if PakettiPhraseRec_SavePreferences then
                PakettiPhraseRec_SavePreferences()
              end
            end
          end
        }
      },
      
      -- Quantize actions
      vb:row{
        spacing = 5,
        vb:button{
          text = "Quantize Sel",
          width = 80,
          tooltip = "Quantize notes in current phrase selection",
          notifier = function()
            if PakettiPhraseRec_QuantizeSelection then
              PakettiPhraseRec_QuantizeSelection()
            end
          end
        },
        vb:button{
          text = "Quantize Phrase",
          width = 95,
          tooltip = "Quantize all notes in current phrase",
          notifier = function()
            if PakettiPhraseRec_QuantizePhrase then
              PakettiPhraseRec_QuantizePhrase()
            end
          end
        },
        vb:button{
          text = "Dialog...",
          width = 60,
          tooltip = "Open full Phrase Recording dialog",
          notifier = function()
            if PakettiPhraseRec_ShowDialog then
              PakettiPhraseRec_ShowDialog()
            end
          end
        }
      }
    },
    
    -- Close button
    vb:row{
      vb:button{
        text = "Close",
        width = 80,
        notifier = function()
          if PakettiPhraseGridPerformanceDialog then
            PakettiPhraseGridPerformanceDialog:close()
            PakettiPhraseGridPerformanceDialog = nil
          end
        end
      }
    }
  }
  
  PakettiPhraseGridPerformanceDialog = renoise.app():show_custom_dialog(
    "PhraseGrid Performance Hub",
    content,
    my_keyhandler_func
  )
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Keybinding and menu entries for performance dialog
renoise.tool():add_keybinding{name="Global:Paketti:PhraseGrid Performance Hub",invoke=PakettiPhraseGridShowPerformanceDialog}
renoise.tool():add_midi_mapping{name="Paketti:PhraseGrid Performance Hub [Trigger]",invoke=function(message) if message:is_trigger() then PakettiPhraseGridShowPerformanceDialog() end end}

--------------------------------------------------------------------------------
-- 17. MENU ENTRIES
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Show PhraseGrid Dialog", invoke=PakettiPhraseGridShowDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Show Performance Hub", invoke=PakettiPhraseGridShowPerformanceDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Show Quick Popup", invoke=PakettiPhraseGridShowPopup}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Toggle Phrase Transport", invoke=PakettiPhraseTransportToggle}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Toggle Auto-Spawn on Selection", invoke=PakettiPhraseVoiceToggleAutoSpawn}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Templates:Create Empty Phrase (16 lines)", invoke=function() PakettiPhraseTemplateCreate("empty", {length = 16}) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Templates:Create Phrase From Slices", invoke=PakettiPhraseTemplateFromSlices}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Templates:Create Drum Pattern (Basic)", invoke=function() PakettiPhraseTemplateDrum("basic") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Templates:Create Drum Pattern (Four Floor)", invoke=function() PakettiPhraseTemplateDrum("four_floor") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Templates:Create Arp Pattern (Ascending)", invoke=function() PakettiPhraseTemplateArp("ascending", 12) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Templates:Create Arp Pattern (Descending)", invoke=function() PakettiPhraseTemplateArp("descending", 12) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Pattern Integration:Auto-Fill Pattern with Phrase", invoke=function() PakettiPhraseAutoFillPattern() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Pattern Integration:Auto-Fill with Variations", invoke=PakettiPhraseAutoFillWithVariation}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Pattern Integration:Convert Phrase to Pattern", invoke=function() PakettiPhraseToPattern() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Pattern Integration:Convert Pattern to Phrase", invoke=PakettiPatternToPhrase}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Quick Flicks:Show Quick Flicks Dialog", invoke=PakettiQuickFlicksShowDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Quick Flicks:Volume Ramp Up", invoke=function() PakettiQuickFlickVolumeRampUp() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Quick Flicks:Volume Ramp Down", invoke=function() PakettiQuickFlickVolumeRampDown() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Quick Flicks:Gate Pattern 1010", invoke=function() PakettiQuickFlickVolumeGate(nil, nil, "1010") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Quick Flicks:Gate Pattern 1100", invoke=function() PakettiQuickFlickVolumeGate(nil, nil, "1100") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Quick Flicks:Cut 0C00 (Instant)", invoke=function() PakettiQuickFlickCutPattern(nil, nil, 0x00) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Quick Flicks:Cut 0C80 (Half)", invoke=function() PakettiQuickFlickCutPattern(nil, nil, 0x80) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Quick Flicks:Retrig R04", invoke=function() PakettiQuickFlickRetrig(nil, nil, 4, "flat") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Quick Flicks:Slice Sequential", invoke=function() PakettiQuickFlickSliceSequential() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Quick Flicks:Slice Random", invoke=function() PakettiQuickFlickSliceRandom() end}

-- Pattern Matrix context menus
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Store as PhraseGrid State", invoke=PakettiPhraseGridStoreFromPatternMatrix}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti:Recall PhraseGrid State...", invoke=function() PakettiPhraseGridShowPopup() end}

-- Phrase Editor context menus
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:PhraseGrid:Show Dialog", invoke=PakettiPhraseGridShowDialog}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:PhraseGrid:Auto-Fill Pattern", invoke=function() PakettiPhraseAutoFillPattern() end}
renoise.tool():add_menu_entry{name="Phrase Editor:Paketti:PhraseGrid:Convert to Pattern", invoke=function() PakettiPhraseToPattern() end}

--------------------------------------------------------------------------------
-- 18. RENDER + PHRASEGRID INTEGRATION
-- Deep integration between rendering, slicing, stacking and phrase creation
--------------------------------------------------------------------------------

-- Global render context for phrase creation
PakettiRenderPhraseContext = {
  source_track = 0,
  target_instrument = 0,
  temp_file_path = "",
  render_mode = "pattern",  -- "pattern", "selection", "phrase"
  auto_slice = false,
  auto_create_phrases = false,
  auto_normalize = false,
  auto_reverse = false,
  target_phrase_bank = nil,
  original_pattern_length = 0,
  num_tracks_before = 0
}

-- Render current pattern track to sample, then auto-slice and create phrases
function PakettiRenderPatternToPhrase(options)
  options = options or {}
  local song = renoise.song()
  if not song then return end
  
  local slice_count = options.slice_count or 8
  local auto_normalize = options.normalize ~= false
  local create_phrases = options.create_phrases ~= false
  local add_to_bank = options.add_to_bank ~= false
  
  -- Store context
  PakettiRenderPhraseContext.source_track = song.selected_track_index
  PakettiRenderPhraseContext.render_mode = "pattern"
  PakettiRenderPhraseContext.auto_slice = slice_count > 0
  PakettiRenderPhraseContext.auto_create_phrases = create_phrases
  PakettiRenderPhraseContext.auto_normalize = auto_normalize
  PakettiRenderPhraseContext.slice_count = slice_count
  PakettiRenderPhraseContext.add_to_bank = add_to_bank
  PakettiRenderPhraseContext.original_pattern_length = song.selected_pattern.number_of_lines
  PakettiRenderPhraseContext.num_tracks_before = #song.tracks
  
  -- Create new instrument for rendered sample
  local new_inst_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_inst_index)
  song.selected_instrument_index = new_inst_index
  PakettiRenderPhraseContext.target_instrument = new_inst_index
  
  -- Set up temp file path
  PakettiRenderPhraseContext.temp_file_path = pakettiGetTempFilePath(".wav")
  
  -- Set up rendering options
  local render_priority = "high"
  local selected_track = song:track(PakettiRenderPhraseContext.source_track)
  
  for _, device in ipairs(selected_track.devices) do
    if device.name == "#Line Input" then
      render_priority = "realtime"
      break
    end
  end
  
  local render_options = {
    sample_rate = preferences.renderSampleRate.value,
    bit_depth = preferences.renderBitDepth.value,
    interpolation = preferences.renderInterpolation.value,
    priority = render_priority,
    start_pos = renoise.SongPos(song.selected_sequence_index, 1),
    end_pos = renoise.SongPos(song.selected_sequence_index, song.selected_pattern.number_of_lines),
  }
  
  -- Solo the source track
  for i, track in ipairs(song.tracks) do
    track.solo_state = false
  end
  song.tracks[PakettiRenderPhraseContext.source_track].solo_state = true
  
  -- Start rendering
  local success, error_message = song:render(render_options, PakettiRenderPhraseContext.temp_file_path, 
    PakettiRenderPatternToPhraseCallback)
  
  if not success then
    renoise.app():show_status("Render failed: " .. (error_message or "unknown error"))
    -- Cleanup
    song:delete_instrument_at(new_inst_index)
  else
    renoise.app():show_status("Rendering pattern to phrase...")
  end
end

-- Callback for pattern-to-phrase render completion
function PakettiRenderPatternToPhraseCallback()
  local song = renoise.song()
  if not song then return end
  
  local ctx = PakettiRenderPhraseContext
  
  -- Unsolo source track
  song.tracks[ctx.source_track].solo_state = false
  
  -- Load rendered sample into instrument
  local instrument = song:instrument(ctx.target_instrument)
  if instrument then
    -- Ensure at least one sample exists
    if #instrument.samples == 0 then
      instrument:insert_sample_at(1)
    end
    instrument.samples[1].sample_buffer:load_from(ctx.temp_file_path)
    
    -- Name the instrument
    local track_name = song.tracks[ctx.source_track].name or "Rendered"
    instrument.name = track_name .. " (Rendered)"
    instrument.samples[1].name = track_name .. " (Rendered)"
    instrument.samples[1].autofade = true
  end
  
  -- Clean up temp file
  os.remove(ctx.temp_file_path)
  
  -- Normalize if requested
  if ctx.auto_normalize then
    if normalize_selected_sample_ultra_fast then
      normalize_selected_sample_ultra_fast()
    end
  end
  
  -- Auto-slice if requested
  if ctx.auto_slice and ctx.slice_count and ctx.slice_count > 0 then
    if slicerough then
      slicerough(ctx.slice_count)
    end
  end
  
  -- Create phrases from slices
  if ctx.auto_create_phrases then
    local phrases_created = PakettiRenderCreatePhrasesFromSlices()
    
    -- Add to PhraseGrid bank if requested
    if ctx.add_to_bank and phrases_created and phrases_created > 0 then
      PakettiRenderCreateBankFromPhrases(phrases_created)
    end
  end
  
  -- Handle post-processing if specified
  if ctx.post_process == "reverse" then
    PakettiRenderApplyReverse()
    if ctx.create_phrase_after then
      local phrases_created = PakettiRenderCreatePhrasesFromSlices()
      if phrases_created and phrases_created > 0 then
        PakettiRenderCreateBankFromPhrases(phrases_created)
      end
    end
    renoise.app():show_status("Pattern rendered and reversed!")
  elseif ctx.post_process == "stack" or ctx.post_process == "full_stack_workflow" then
    PakettiStackerFromRenderedSlices()
    renoise.app():show_status("Pattern rendered and stacked with velocity phrases!")
  else
    renoise.app():show_status("Pattern rendered to phrases successfully!")
  end
  
  -- Clear post_process flag after handling
  ctx.post_process = nil
  ctx.create_phrase_after = nil
end

-- Create phrases from slices in current instrument
function PakettiRenderCreatePhrasesFromSlices()
  local song = renoise.song()
  if not song then return 0 end
  
  local instrument = song.selected_instrument
  if not instrument then return 0 end
  
  local first_sample = instrument.samples[1]
  if not first_sample then return 0 end
  
  local slice_count = #first_sample.slice_markers
  if slice_count == 0 then
    -- No slices, create single phrase for whole sample
    local phrase_count = #instrument.phrases
    instrument:insert_phrase_at(phrase_count + 1)
    local phrase = instrument.phrases[phrase_count + 1]
    phrase.number_of_lines = song.selected_pattern.number_of_lines
    phrase.lpb = song.transport.lpb
    phrase.name = "Full Sample"
    
    local line = phrase:line(1)
    line:note_column(1).note_value = 48  -- C-4
    line:note_column(1).instrument_value = song.selected_instrument_index - 1
    
    return 1
  end
  
  local phrases_created = 0
  
  -- Create one phrase per slice
  for i = 1, slice_count + 1 do  -- +1 because slices create slice_count+1 playable regions
    local phrase_count = #instrument.phrases
    instrument:insert_phrase_at(phrase_count + 1)
    
    local phrase = instrument.phrases[phrase_count + 1]
    phrase.number_of_lines = math.max(4, math.floor(song.selected_pattern.number_of_lines / (slice_count + 1)))
    phrase.lpb = song.transport.lpb
    phrase.name = string.format("Slice %02d", i)
    
    -- Calculate note for this slice (C-0 = slice 0, C#0 = slice 1, etc.)
    local note_value = (i - 1)  -- 0-based slice index
    if note_value > 119 then note_value = 119 end
    
    local line = phrase:line(1)
    line:note_column(1).note_value = note_value
    line:note_column(1).instrument_value = song.selected_instrument_index - 1
    
    phrases_created = phrases_created + 1
  end
  
  return phrases_created
end

-- Create PhraseGrid bank from recently created phrases
function PakettiRenderCreateBankFromPhrases(num_phrases)
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  if not instrument then return end
  
  local total_phrases = #instrument.phrases
  if total_phrases == 0 then return end
  
  num_phrases = num_phrases or total_phrases
  
  -- Create new bank
  local bank_name = instrument.name .. " Bank"
  local bank_index = nil
  
  if PakettiPhraseBankCreate then
    bank_index = PakettiPhraseBankCreate(song.selected_instrument_index, bank_name)
  else
    -- Fallback: create bank manually
    local bank_slot = #PakettiPhraseBanks + 1
    PakettiPhraseBanks[bank_slot] = {
      name = bank_name,
      instrument = song.selected_instrument_index,
      slots = {}
    }
    bank_index = bank_slot
  end
  
  if bank_index and PakettiPhraseBanks[bank_index] then
    -- Assign phrases to bank slots (up to 8)
    local start_phrase = total_phrases - num_phrases + 1
    for i = 1, math.min(8, num_phrases) do
      if PakettiPhraseBankSetSlot then
        PakettiPhraseBankSetSlot(bank_index, i, start_phrase + i - 1)
      else
        PakettiPhraseBanks[bank_index].slots[i] = start_phrase + i - 1
      end
    end
    
    renoise.app():show_status(string.format("Created bank '%s' with %d phrases", bank_name, math.min(8, num_phrases)))
  end
end

-- Render current phrase to new sample
function PakettiRenderPhraseToSample(options)
  options = options or {}
  local song = renoise.song()
  if not song then return end
  
  local phrase = song.selected_phrase
  if not phrase then
    renoise.app():show_status("No phrase selected")
    return
  end
  
  -- Convert phrase to pattern first
  local temp_pattern_index = song.selected_pattern_index
  local temp_track_index = song.selected_track_index
  
  -- Insert temporary pattern for rendering
  local pattern_count = #song.sequencer.pattern_sequence
  song.sequencer:insert_new_pattern_at(pattern_count + 1)
  local temp_seq_index = pattern_count + 1
  song.selected_sequence_index = temp_seq_index
  
  local temp_pattern = song:pattern(song.sequencer.pattern_sequence[temp_seq_index])
  temp_pattern.number_of_lines = phrase.number_of_lines
  
  -- Copy phrase content to temp pattern
  local track_data = temp_pattern:track(temp_track_index)
  for line_idx = 1, phrase.number_of_lines do
    local phrase_line = phrase:line(line_idx)
    local pattern_line = track_data:line(line_idx)
    
    for col_idx = 1, math.min(#phrase_line.note_columns, #pattern_line.note_columns) do
      local phrase_col = phrase_line:note_column(col_idx)
      local pattern_col = pattern_line:note_column(col_idx)
      
      if not phrase_col.is_empty then
        pattern_col.note_value = phrase_col.note_value
        pattern_col.instrument_value = phrase_col.instrument_value
        pattern_col.volume_value = phrase_col.volume_value
        pattern_col.panning_value = phrase_col.panning_value
        pattern_col.delay_value = phrase_col.delay_value
        pattern_col.effect_number_value = phrase_col.effect_number_value
        pattern_col.effect_amount_value = phrase_col.effect_amount_value
      end
    end
    
    for col_idx = 1, math.min(#phrase_line.effect_columns, #pattern_line.effect_columns) do
      local phrase_col = phrase_line:effect_column(col_idx)
      local pattern_col = pattern_line:effect_column(col_idx)
      
      if not phrase_col.is_empty then
        pattern_col.number_value = phrase_col.number_value
        pattern_col.amount_value = phrase_col.amount_value
      end
    end
  end
  
  -- Now render this pattern
  PakettiRenderPhraseContext.source_track = temp_track_index
  PakettiRenderPhraseContext.render_mode = "phrase"
  PakettiRenderPhraseContext.auto_slice = options.slice_count and options.slice_count > 0
  PakettiRenderPhraseContext.slice_count = options.slice_count or 0
  PakettiRenderPhraseContext.auto_create_phrases = options.create_phrases or false
  PakettiRenderPhraseContext.auto_normalize = options.normalize ~= false
  PakettiRenderPhraseContext.temp_seq_index = temp_seq_index
  PakettiRenderPhraseContext.original_pattern_index = temp_pattern_index
  PakettiRenderPhraseContext.original_track_index = temp_track_index
  
  -- Create new instrument
  local new_inst_index = song.selected_instrument_index + 1
  song:insert_instrument_at(new_inst_index)
  song.selected_instrument_index = new_inst_index
  PakettiRenderPhraseContext.target_instrument = new_inst_index
  
  PakettiRenderPhraseContext.temp_file_path = pakettiGetTempFilePath(".wav")
  
  local render_options = {
    sample_rate = preferences.renderSampleRate.value,
    bit_depth = preferences.renderBitDepth.value,
    interpolation = preferences.renderInterpolation.value,
    priority = "high",
    start_pos = renoise.SongPos(temp_seq_index, 1),
    end_pos = renoise.SongPos(temp_seq_index, phrase.number_of_lines),
  }
  
  -- Solo the track
  for i, track in ipairs(song.tracks) do
    track.solo_state = false
  end
  song.tracks[temp_track_index].solo_state = true
  
  local success, error_message = song:render(render_options, PakettiRenderPhraseContext.temp_file_path,
    PakettiRenderPhraseToSampleCallback)
  
  if not success then
    renoise.app():show_status("Render failed: " .. (error_message or "unknown error"))
    song:delete_instrument_at(new_inst_index)
    song.sequencer:delete_sequence_at(temp_seq_index)
  else
    renoise.app():show_status("Rendering phrase to sample...")
  end
end

-- Callback for phrase-to-sample render completion
function PakettiRenderPhraseToSampleCallback()
  local song = renoise.song()
  if not song then return end
  
  local ctx = PakettiRenderPhraseContext
  
  -- Unsolo track
  song.tracks[ctx.source_track].solo_state = false
  
  -- Load sample
  local instrument = song:instrument(ctx.target_instrument)
  if instrument then
    -- Ensure at least one sample exists
    if #instrument.samples == 0 then
      instrument:insert_sample_at(1)
    end
    instrument.samples[1].sample_buffer:load_from(ctx.temp_file_path)
    instrument.name = "Phrase Rendered"
    instrument.samples[1].name = "Phrase Rendered"
    instrument.samples[1].autofade = true
  end
  
  -- Clean up temp file
  os.remove(ctx.temp_file_path)
  
  -- Remove temporary pattern
  if ctx.temp_seq_index then
    song.sequencer:delete_sequence_at(ctx.temp_seq_index)
    song.selected_sequence_index = math.min(ctx.original_pattern_index or 1, #song.sequencer.pattern_sequence)
  end
  
  -- Normalize if requested
  if ctx.auto_normalize then
    if normalize_selected_sample_ultra_fast then
      normalize_selected_sample_ultra_fast()
    end
  end
  
  -- Auto-slice if requested
  if ctx.auto_slice and ctx.slice_count and ctx.slice_count > 0 then
    if slicerough then
      slicerough(ctx.slice_count)
    end
  end
  
  -- Create phrases from slices
  if ctx.auto_create_phrases then
    PakettiRenderCreatePhrasesFromSlices()
  end
  
  renoise.app():show_status("Phrase rendered to sample!")
end

-- Render pattern selection to phrase bank
function PakettiRenderSelectionToPhraseBank(num_selections)
  local song = renoise.song()
  if not song then return end
  
  num_selections = num_selections or 4
  local pattern_length = song.selected_pattern.number_of_lines
  local section_length = math.floor(pattern_length / num_selections)
  
  if section_length < 1 then
    renoise.app():show_status("Pattern too short for " .. num_selections .. " sections")
    return
  end
  
  renoise.app():show_status(string.format("Rendering %d sections of %d lines each...", num_selections, section_length))
  
  -- This would need to be done sequentially with callbacks
  -- For now, just render the full pattern and slice it
  PakettiRenderPatternToPhrase({
    slice_count = num_selections,
    normalize = true,
    create_phrases = true,
    add_to_bank = true
  })
end

--------------------------------------------------------------------------------
-- 19. POST-RENDER PROCESSING INTEGRATION
--------------------------------------------------------------------------------

-- Render and reverse the result
function PakettiRenderAndReverse(options)
  options = options or {}
  local song = renoise.song()
  if not song then return end
  
  -- First render
  PakettiRenderPhraseContext.post_process = "reverse"
  PakettiRenderPhraseContext.create_phrase_after = options.create_phrase ~= false
  
  PakettiRenderPatternToPhrase({
    slice_count = 0,  -- Don't slice, we'll reverse
    normalize = options.normalize ~= false,
    create_phrases = false,  -- We'll create after reversing
    add_to_bank = false
  })
end

-- Apply reverse to rendered sample (called after render)
function PakettiRenderApplyReverse()
  local song = renoise.song()
  if not song then return end
  
  local sample = song.selected_sample
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample data to reverse")
    return
  end
  
  -- Use existing reverse function if available
  if PakettiReverseSampleBuffer then
    PakettiReverseSampleBuffer(sample.sample_buffer)
    renoise.app():show_status("Sample reversed!")
  else
    -- Manual reverse implementation
    local buffer = sample.sample_buffer
    local frames = buffer.number_of_frames
    local channels = buffer.number_of_channels
    
    if buffer:prepare_sample_data_changes() then
      for channel = 1, channels do
        local i = 1
        local j = frames
        while i < j do
          local temp = buffer:sample_data(channel, i)
          buffer:set_sample_data(channel, i, buffer:sample_data(channel, j))
          buffer:set_sample_data(channel, j, temp)
          i = i + 1
          j = j - 1
        end
      end
      buffer:finalize_sample_data_changes()
      renoise.app():show_status("Sample reversed!")
    end
  end
end

-- Render, normalize, and optionally slice
function PakettiRenderAndNormalize(options)
  options = options or {}
  
  PakettiRenderPatternToPhrase({
    slice_count = options.slice_count or 0,
    normalize = true,
    create_phrases = options.create_phrases ~= false,
    add_to_bank = options.add_to_bank ~= false
  })
end

-- Render with auto beat detection and slicing
function PakettiRenderAndAutoSlice(options)
  options = options or {}
  local song = renoise.song()
  if not song then return end
  
  -- Use beat detection if available
  local slice_count = options.slice_count
  if not slice_count and PakettiSliceProCalculateLPBForBeats then
    -- Try to detect appropriate slice count from pattern
    local pattern_length = song.selected_pattern.number_of_lines
    local lpb = song.transport.lpb
    local beats = pattern_length / lpb
    slice_count = math.floor(beats)
  end
  
  slice_count = slice_count or 8
  
  PakettiRenderPatternToPhrase({
    slice_count = slice_count,
    normalize = options.normalize ~= false,
    create_phrases = true,
    add_to_bank = true
  })
end

--------------------------------------------------------------------------------
-- 20. SLICE TO PHRASE AUTOMATION
--------------------------------------------------------------------------------

-- Convert existing slices in selected instrument to PhraseGrid bank
function PakettiSlicesToPhraseBank(options)
  options = options or {}
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local first_sample = instrument.samples[1]
  if not first_sample then
    renoise.app():show_status("Instrument has no samples")
    return
  end
  
  local slice_count = #first_sample.slice_markers
  if slice_count == 0 then
    renoise.app():show_status("No slices in selected instrument")
    return
  end
  
  local phrase_length = options.phrase_length or 4
  local phrases_created = 0
  
  -- Create one phrase per slice
  for i = 0, slice_count do  -- 0 = original, 1..slice_count = slices
    local phrase_count = #instrument.phrases
    instrument:insert_phrase_at(phrase_count + 1)
    
    local phrase = instrument.phrases[phrase_count + 1]
    phrase.number_of_lines = phrase_length
    phrase.lpb = song.transport.lpb
    phrase.name = i == 0 and "Full Sample" or string.format("Slice %02d", i)
    
    -- Note value: C-0 for original, C#0-B-9 for slices
    local note_value = i
    if note_value > 119 then note_value = 119 end
    
    local line = phrase:line(1)
    line:note_column(1).note_value = note_value
    line:note_column(1).instrument_value = song.selected_instrument_index - 1
    
    phrases_created = phrases_created + 1
  end
  
  -- Create bank from phrases
  PakettiRenderCreateBankFromPhrases(phrases_created)
  
  renoise.app():show_status(string.format("Created %d phrases from slices", phrases_created))
  return phrases_created
end

-- Auto-detect beats, slice, and create phrases
function PakettiAutoSliceAndPhraseCreate(options)
  options = options or {}
  local song = renoise.song()
  if not song then return end
  
  local sample = song.selected_sample
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample data to slice")
    return
  end
  
  local slice_count = options.slice_count
  
  -- Try beat detection if available and no slice count specified
  if not slice_count and pakettiBPMDetectFromSample then
    local frames = sample.sample_buffer.number_of_frames
    local sample_rate = sample.sample_buffer.sample_rate
    local detected_bpm, beat_count = pakettiBPMDetectFromSample(frames, sample_rate)
    if beat_count and beat_count > 0 then
      slice_count = beat_count
    end
  end
  
  slice_count = slice_count or 8
  
  -- Slice the sample
  if slicerough then
    slicerough(slice_count)
  end
  
  -- Create phrases from slices
  local phrases_created = PakettiRenderCreatePhrasesFromSlices()
  
  -- Add to bank
  if phrases_created and phrases_created > 0 then
    PakettiRenderCreateBankFromPhrases(phrases_created)
  end
  
  return phrases_created
end

-- Rearrange slices on new track using sample offset method
function PakettiRearrangeTrackFromSlices(options)
  options = options or {}
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local first_sample = instrument.samples[1]
  if not first_sample then
    renoise.app():show_status("Instrument has no samples")
    return
  end
  
  local slice_count = #first_sample.slice_markers
  if slice_count == 0 then
    renoise.app():show_status("No slices to rearrange")
    return
  end
  
  local pattern_length = song.selected_pattern.number_of_lines
  local step = options.step or math.floor(pattern_length / (slice_count + 1))
  local randomize = options.randomize or false
  
  -- Create new track
  local source_track = song.selected_track_index
  song:insert_track_at(source_track + 1)
  song.selected_track_index = source_track + 1
  
  local track_data = song.selected_pattern:track(song.selected_track_index)
  local current_line = 1
  
  -- Seed random if needed
  if randomize then
    math.randomseed(os.time())
  end
  
  -- Build slice order
  local slice_order = {}
  if randomize then
    -- Random order
    local available = {}
    for i = 0, slice_count do
      table.insert(available, i)
    end
    while #available > 0 do
      local idx = math.random(1, #available)
      table.insert(slice_order, available[idx])
      table.remove(available, idx)
    end
  else
    -- Sequential order
    for i = 0, slice_count do
      table.insert(slice_order, i)
    end
  end
  
  for _, slice_idx in ipairs(slice_order) do
    if current_line > pattern_length then break end
    
    local line = track_data:line(current_line)
    local note_col = line:note_column(1)
    
    -- Note value for slice
    local note_value = slice_idx
    if note_value > 119 then note_value = 119 end
    
    note_col.note_value = note_value
    note_col.instrument_value = song.selected_instrument_index - 1
    
    current_line = current_line + step
  end
  
  song.tracks[song.selected_track_index].name = instrument.name .. " (Rearranged)"
  renoise.app():show_status(string.format("Rearranged %d slices on new track", #slice_order))
end

--------------------------------------------------------------------------------
-- 21. STACKER + RENDER WORKFLOW INTEGRATION
--------------------------------------------------------------------------------

-- Render track, slice, stack, and create velocity phrases
function PakettiStackerRenderAndStack(options)
  options = options or {}
  local song = renoise.song()
  if not song then return end
  
  local slice_count = options.slice_count or 8
  
  -- First render the pattern
  PakettiRenderPhraseContext.post_process = "stack"
  PakettiRenderPhraseContext.stack_options = options
  
  PakettiRenderPatternToPhrase({
    slice_count = slice_count,
    normalize = options.normalize ~= false,
    create_phrases = false,  -- We'll create velocity phrases instead
    add_to_bank = false
  })
end

-- Create stacked velocity instrument from rendered slices
function PakettiStackerFromRenderedSlices()
  local song = renoise.song()
  if not song then return end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local first_sample = instrument.samples[1]
  if not first_sample then
    renoise.app():show_status("Instrument has no samples")
    return
  end
  
  local slice_count = #first_sample.slice_markers
  if slice_count == 0 then
    renoise.app():show_status("No slices to stack")
    return
  end
  
  -- Isolate slices to individual samples
  if PakettiIsolateSlicesToInstrumentNoProcess then
    PakettiIsolateSlicesToInstrumentNoProcess()
  elseif PakettiIsolateSlicesToInstrument then
    PakettiIsolateSlicesToInstrument()
  else
    renoise.app():show_status("Slice isolation function not available")
    return
  end
  
  -- Get the updated instrument (after isolation)
  instrument = song.selected_instrument
  local num_samples = #instrument.samples
  
  -- Set up velocity mapping for stacking with distributed ranges
  local base_note = 48  -- C-4
  local note_range = {0, 119}
  local velocity_step = math.floor(128 / num_samples)
  
  for i = 1, num_samples do
    local sample = instrument.samples[i]
    local vel_min = (i - 1) * velocity_step
    local vel_max = (i == num_samples) and 127 or (i * velocity_step - 1)
    
    sample.sample_mapping.map_velocity_to_volume = false
    sample.sample_mapping.base_note = base_note
    sample.sample_mapping.note_range = note_range
    sample.sample_mapping.velocity_range = {vel_min, vel_max}
  end
  
  -- Create velocity phrases using Stacker integration
  if PakettiStackerCreateVelocityPhrases then
    local phrases_created = PakettiStackerCreateVelocityPhrases()
    if phrases_created and phrases_created > 0 then
      PakettiRenderCreateBankFromPhrases(phrases_created)
    end
  end
  
  renoise.app():show_status("Stacked instrument created with velocity phrases")
end

-- Full workflow: Render -> Slice -> Stack -> Create Phrases -> Add to PhraseGrid
function PakettiFullRenderStackWorkflow(options)
  options = options or {}
  local song = renoise.song()
  if not song then return end
  
  local slice_count = options.slice_count or 8
  
  renoise.app():show_status("Starting full render-stack workflow...")
  
  -- This is a multi-step process that chains together:
  -- 1. Render current track
  -- 2. Normalize
  -- 3. Slice
  -- 4. Isolate slices
  -- 5. Stack with velocity mapping
  -- 6. Create velocity phrases
  -- 7. Create PhraseGrid bank
  
  PakettiRenderPhraseContext.post_process = "full_stack_workflow"
  PakettiRenderPhraseContext.workflow_slice_count = slice_count
  
  PakettiRenderPatternToPhrase({
    slice_count = slice_count,
    normalize = true,
    create_phrases = false,
    add_to_bank = false
  })
end

--------------------------------------------------------------------------------
-- 22. PHRASEGRID RENDER TRIGGERS
--------------------------------------------------------------------------------

-- Store render action in PhraseGrid state
function PakettiPhraseGridAddRenderAction(state_index, action_type, action_params)
  if not PakettiPhraseGridStates[state_index] then
    PakettiPhraseGridStates[state_index] = {}
  end
  
  if not PakettiPhraseGridStates[state_index].render_actions then
    PakettiPhraseGridStates[state_index].render_actions = {}
  end
  
  table.insert(PakettiPhraseGridStates[state_index].render_actions, {
    type = action_type,
    params = action_params or {}
  })
  
  renoise.app():show_status(string.format("Added render action '%s' to state %d", action_type, state_index))
end

-- Execute render actions for a state
function PakettiPhraseGridExecuteRenderActions(state_index)
  local state = PakettiPhraseGridStates[state_index]
  if not state or not state.render_actions then return end
  
  for _, action in ipairs(state.render_actions) do
    if action.type == "render_pattern" then
      PakettiRenderPatternToPhrase(action.params)
    elseif action.type == "render_phrase" then
      PakettiRenderPhraseToSample(action.params)
    elseif action.type == "render_and_reverse" then
      PakettiRenderAndReverse(action.params)
    elseif action.type == "render_and_slice" then
      PakettiRenderAndAutoSlice(action.params)
    elseif action.type == "slices_to_bank" then
      PakettiSlicesToPhraseBank(action.params)
    elseif action.type == "stack_workflow" then
      PakettiFullRenderStackWorkflow(action.params)
    end
  end
end

-- Render current state to sample and create phrase
function PakettiPhraseGridRenderCurrentState()
  local song = renoise.song()
  if not song then return end
  
  local state_index = PakettiPhraseGridCurrentState
  if state_index == 0 then
    renoise.app():show_status("No active PhraseGrid state")
    return
  end
  
  local state = PakettiPhraseGridStates[state_index]
  if not state then
    renoise.app():show_status("State not found")
    return
  end
  
  -- First recall the state to set up the environment
  PakettiPhraseGridRecall(state_index)
  
  -- Then render
  PakettiRenderPatternToPhrase({
    slice_count = 0,
    normalize = true,
    create_phrases = true,
    add_to_bank = true
  })
  
  renoise.app():show_status(string.format("Rendering state %d...", state_index))
end

-- Create phrase from rendered selection and add to current state
function PakettiPhraseGridCaptureRenderToState(state_index)
  local song = renoise.song()
  if not song then return end
  
  state_index = state_index or PakettiPhraseGridCurrentState
  if state_index == 0 then
    renoise.app():show_status("No active PhraseGrid state")
    return
  end
  
  -- Render current selection/pattern
  PakettiRenderPhraseContext.capture_to_state = state_index
  
  PakettiRenderPatternToPhrase({
    slice_count = 0,
    normalize = true,
    create_phrases = true,
    add_to_bank = false  -- Add to specific state instead
  })
end

--------------------------------------------------------------------------------
-- 23. RENDER INTEGRATION KEYBINDINGS & MENU ENTRIES
--------------------------------------------------------------------------------

-- Keybindings for render integration
renoise.tool():add_keybinding{name="Global:Paketti:Render Pattern to Phrases", invoke=function() PakettiRenderPatternToPhrase() end}
renoise.tool():add_keybinding{name="Global:Paketti:Render Pattern to Phrases (8 slices)", invoke=function() PakettiRenderPatternToPhrase({slice_count = 8}) end}
renoise.tool():add_keybinding{name="Global:Paketti:Render Pattern to Phrases (16 slices)", invoke=function() PakettiRenderPatternToPhrase({slice_count = 16}) end}
renoise.tool():add_keybinding{name="Global:Paketti:Render Phrase to Sample", invoke=function() PakettiRenderPhraseToSample() end}
renoise.tool():add_keybinding{name="Global:Paketti:Render and Reverse", invoke=function() PakettiRenderAndReverse() end}
renoise.tool():add_keybinding{name="Global:Paketti:Render and Auto-Slice", invoke=function() PakettiRenderAndAutoSlice() end}
renoise.tool():add_keybinding{name="Global:Paketti:Slices to Phrase Bank", invoke=function() PakettiSlicesToPhraseBank() end}
renoise.tool():add_keybinding{name="Global:Paketti:Auto-Slice and Create Phrases", invoke=function() PakettiAutoSliceAndPhraseCreate() end}
renoise.tool():add_keybinding{name="Global:Paketti:Rearrange Slices on New Track", invoke=function() PakettiRearrangeTrackFromSlices() end}
renoise.tool():add_keybinding{name="Global:Paketti:Rearrange Slices (Random)", invoke=function() PakettiRearrangeTrackFromSlices({randomize = true}) end}
renoise.tool():add_keybinding{name="Global:Paketti:Full Render Stack Workflow", invoke=function() PakettiFullRenderStackWorkflow() end}
renoise.tool():add_keybinding{name="Global:Paketti:Render Current PhraseGrid State", invoke=function() PakettiPhraseGridRenderCurrentState() end}

-- MIDI mappings for render integration
renoise.tool():add_midi_mapping{name="Paketti:Render Pattern to Phrases [Trigger]", invoke=function(message) if message:is_trigger() then PakettiRenderPatternToPhrase() end end}
renoise.tool():add_midi_mapping{name="Paketti:Render Phrase to Sample [Trigger]", invoke=function(message) if message:is_trigger() then PakettiRenderPhraseToSample() end end}
renoise.tool():add_midi_mapping{name="Paketti:Slices to Phrase Bank [Trigger]", invoke=function(message) if message:is_trigger() then PakettiSlicesToPhraseBank() end end}
renoise.tool():add_midi_mapping{name="Paketti:Full Render Stack Workflow [Trigger]", invoke=function(message) if message:is_trigger() then PakettiFullRenderStackWorkflow() end end}
renoise.tool():add_midi_mapping{name="Paketti:Rearrange Slices [Trigger]", invoke=function(message) if message:is_trigger() then PakettiRearrangeTrackFromSlices() end end}
renoise.tool():add_midi_mapping{name="Paketti:Render Current State [Trigger]", invoke=function(message) if message:is_trigger() then PakettiPhraseGridRenderCurrentState() end end}

-- Menu entries for render integration
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Render Integration:Render Pattern to Phrases", invoke=function() PakettiRenderPatternToPhrase() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Render Integration:Render Pattern (8 slices)", invoke=function() PakettiRenderPatternToPhrase({slice_count = 8}) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Render Integration:Render Pattern (16 slices)", invoke=function() PakettiRenderPatternToPhrase({slice_count = 16}) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Render Integration:Render Phrase to Sample", invoke=function() PakettiRenderPhraseToSample() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Render Integration:Render and Reverse", invoke=function() PakettiRenderAndReverse() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Render Integration:Render and Auto-Slice", invoke=function() PakettiRenderAndAutoSlice() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Slice to Phrase:Convert Slices to Phrase Bank", invoke=function() PakettiSlicesToPhraseBank() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Slice to Phrase:Auto-Slice and Create Phrases", invoke=function() PakettiAutoSliceAndPhraseCreate() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Slice to Phrase:Rearrange Slices on New Track", invoke=function() PakettiRearrangeTrackFromSlices() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Slice to Phrase:Rearrange Slices (Random)", invoke=function() PakettiRearrangeTrackFromSlices({randomize = true}) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Stacker Integration:Full Render-Stack Workflow", invoke=function() PakettiFullRenderStackWorkflow() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:Stacker Integration:Stack from Rendered Slices", invoke=function() PakettiStackerFromRenderedSlices() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:PhraseGrid:PhraseGrid Render:Render Current State", invoke=function() PakettiPhraseGridRenderCurrentState() end}

-- Pattern Editor context menu for render integration
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:PhraseGrid:Render to Phrases", invoke=function() PakettiRenderPatternToPhrase() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:PhraseGrid:Render (8 slices)", invoke=function() PakettiRenderPatternToPhrase({slice_count = 8}) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:PhraseGrid:Full Stack Workflow", invoke=function() PakettiFullRenderStackWorkflow() end}

-- Sample Editor context menu for slice-to-phrase
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:PhraseGrid:Slices to Phrase Bank", invoke=function() PakettiSlicesToPhraseBank() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:PhraseGrid:Auto-Slice and Create Phrases", invoke=function() PakettiAutoSliceAndPhraseCreate() end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:PhraseGrid:Rearrange on New Track", invoke=function() PakettiRearrangeTrackFromSlices() end}
