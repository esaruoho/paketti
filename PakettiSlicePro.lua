-- PakettiSlicePro.lua
-- SlicePro: Automatic per-slice beat_sync_lines calculation and application
-- Hybrid implementation combining DSP-based analysis with full GUI and preferences.
-- After slicing a sample, this tool calculates beats per slice proportionally
-- and sets beat_sync_lines so all slices remain tempo-locked when BPM changes.

local vb = renoise.ViewBuilder()
local slicepro_dialog = nil

--------------------------------------------------------------------------------
-- State Management
--------------------------------------------------------------------------------

local SliceProState = {
  instrument_index = nil,     -- Which instrument we analyzed
  total_beats = nil,          -- Total beats in root sample
  slice_beats = {},           -- Beat count per slice (index = slice number)
  user_overrides = {},        -- Manual user edits per slice {index = beats}
  dirty = false,              -- True if sample/slices changed since analysis
  confidence = nil,           -- Detection confidence (0.0-1.0)
  method = nil,               -- Analysis method used ("hybrid" or "fallback")
  sample_rate = nil,          -- Sample rate of analyzed sample
  total_frames = nil,         -- Total frames of analyzed sample
  root_override = nil,        -- Manual root beats override (nil = use analyzed)
  sample_name = nil           -- Name of the analyzed sample for persistence key
}

local state_flags = {
  user_touched_config = false  -- Prevents auto-re-analysis after user opens Config
}

-- UI state
local slicepro_rows_per_column = 30  -- Default rows per column in slice list
local slicepro_rows_options = {5, 10, 15, 30, 35, 40, 45, 50, 55, 60, 80, 128}

-- Observer tracking for cache invalidation
local attached_observers = {
  sample = nil,
  buffer_notifier = nil,
  markers_notifier = nil
}

--------------------------------------------------------------------------------
-- Observer Management (Cache Invalidation)
--------------------------------------------------------------------------------

local function SliceProInvalidateCache()
  SliceProState.dirty = true
  print("SlicePro: Cache invalidated by observer")
end

local function SliceProDetachObservers()
  if attached_observers.sample then
    local sample = attached_observers.sample
    if attached_observers.buffer_notifier then
      pcall(function()
        sample.sample_buffer_observable:remove_notifier(attached_observers.buffer_notifier)
      end)
    end
    if attached_observers.markers_notifier then
      pcall(function()
        sample.slice_markers_observable:remove_notifier(attached_observers.markers_notifier)
      end)
    end
    attached_observers.sample = nil
    attached_observers.buffer_notifier = nil
    attached_observers.markers_notifier = nil
    print("SlicePro: Detached observers")
  end
end

local function SliceProAttachObservers(sample)
  SliceProDetachObservers()
  
  attached_observers.sample = sample
  attached_observers.buffer_notifier = SliceProInvalidateCache
  attached_observers.markers_notifier = SliceProInvalidateCache
  
  sample.sample_buffer_observable:add_notifier(attached_observers.buffer_notifier)
  sample.slice_markers_observable:add_notifier(attached_observers.markers_notifier)
  print("SlicePro: Attached observers to sample")
end

--------------------------------------------------------------------------------
-- Persistent Overrides (Preferences Storage)
--------------------------------------------------------------------------------

local function SliceProGetOverrideKey()
  local song = renoise.song()
  if not song.selected_instrument then return nil end
  local instrument = song.selected_instrument
  local sample_name = #instrument.samples > 0 and instrument.samples[1].name or "unknown"
  return instrument.name .. "_" .. sample_name
end

local function SliceProSaveOverrides()
  local key = SliceProGetOverrideKey()
  if not key then return end
  
  -- Get existing overrides table or create new one
  local overrides_str = preferences.SlicePro.SliceProOverrides.value
  local overrides = {}
  
  -- Parse existing JSON-like format (simple comma-separated key:value pairs)
  if overrides_str and overrides_str ~= "" then
    for k, v in string.gmatch(overrides_str, "([^;]+):([^;]+)") do
      overrides[k] = v
    end
  end
  
  -- Store current overrides as serialized string
  local data_parts = {}
  if SliceProState.root_override then
    table.insert(data_parts, "root=" .. tostring(SliceProState.root_override))
  end
  for i, beats in pairs(SliceProState.user_overrides) do
    table.insert(data_parts, "s" .. i .. "=" .. tostring(beats))
  end
  
  if #data_parts > 0 then
    overrides[key] = table.concat(data_parts, ",")
  else
    overrides[key] = nil
  end
  
  -- Serialize back to preference string
  local parts = {}
  for k, v in pairs(overrides) do
    table.insert(parts, k .. ":" .. v)
  end
  preferences.SlicePro.SliceProOverrides.value = table.concat(parts, ";")
  
  print("SlicePro: Saved overrides for " .. key)
end

local function SliceProLoadOverrides()
  local key = SliceProGetOverrideKey()
  if not key then return false end
  
  local overrides_str = preferences.SlicePro.SliceProOverrides.value
  if not overrides_str or overrides_str == "" then return false end
  
  -- Find our key in the overrides
  for k, v in string.gmatch(overrides_str, "([^;]+):([^;]+)") do
    if k == key then
      -- Parse the data
      for name, value in string.gmatch(v, "([^,=]+)=([^,]+)") do
        if name == "root" then
          SliceProState.root_override = tonumber(value)
        elseif string.sub(name, 1, 1) == "s" then
          local slice_idx = tonumber(string.sub(name, 2))
          if slice_idx then
            SliceProState.user_overrides[slice_idx] = tonumber(value)
          end
        end
      end
      print("SlicePro: Loaded overrides for " .. key)
      return true
    end
  end
  
  return false
end

local function SliceProClearAllOverrides()
  SliceProState.root_override = nil
  SliceProState.user_overrides = {}
  
  -- Also clear from persistence
  local key = SliceProGetOverrideKey()
  if not key then return end
  
  local overrides_str = preferences.SlicePro.SliceProOverrides.value
  if not overrides_str or overrides_str == "" then return end
  
  local overrides = {}
  for k, v in string.gmatch(overrides_str, "([^;]+):([^;]+)") do
    if k ~= key then
      overrides[k] = v
    end
  end
  
  local parts = {}
  for k, v in pairs(overrides) do
    table.insert(parts, k .. ":" .. v)
  end
  preferences.SlicePro.SliceProOverrides.value = table.concat(parts, ";")
  
  print("SlicePro: Cleared all overrides for " .. key)
end

--------------------------------------------------------------------------------
-- Reset State
--------------------------------------------------------------------------------

local function SliceProResetState()
  SliceProDetachObservers()
  SliceProState.instrument_index = nil
  SliceProState.total_beats = nil
  SliceProState.slice_beats = {}
  SliceProState.user_overrides = {}
  SliceProState.dirty = false
  SliceProState.confidence = nil
  SliceProState.method = nil
  SliceProState.sample_rate = nil
  SliceProState.total_frames = nil
  SliceProState.root_override = nil
  SliceProState.sample_name = nil
  state_flags.user_touched_config = false
end

--------------------------------------------------------------------------------
-- Sample Editor Check
--------------------------------------------------------------------------------

local function SliceProEnsureSampleEditor()
  -- Check if preference requires Sample Editor to be open
  if preferences.SlicePro.SliceProRequireSampleEditor and 
     preferences.SlicePro.SliceProRequireSampleEditor.value then
    if renoise.app().window.active_middle_frame ~= 
       renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
      renoise.app():show_status("SlicePro: Open the Sample Editor first")
      return false
    end
  end
  return true
end

--------------------------------------------------------------------------------
-- Validation
--------------------------------------------------------------------------------

local function SliceProValidateSelection()
  local song = renoise.song()
  
  if not song.selected_instrument then
    return false, "No instrument selected"
  end
  
  local instrument = song.selected_instrument
  if #instrument.samples == 0 then
    return false, "Instrument has no samples"
  end
  
  local root_sample = instrument.samples[1]
  if not root_sample.sample_buffer or not root_sample.sample_buffer.has_sample_data then
    return false, "Root sample has no audio data"
  end
  
  return true, nil
end

-- Get root sample even if slice alias is selected
local function SliceProGetRootSample()
  local song = renoise.song()
  local sample = song.selected_sample
  if not sample then return nil end
  
  if sample.is_slice_alias then
    return song.selected_instrument.samples[1]
  end
  return sample
end

--------------------------------------------------------------------------------
-- Duration-Based Beat Calculation (Fallback)
--------------------------------------------------------------------------------

local function SliceProCalculateDurationBeats(frames, sr)
  -- Calculate beat count from sample duration and song BPM
  local duration_sec = frames / sr
  local song_bpm = renoise.song().transport.bpm
  local duration_beats = math.floor((duration_sec * song_bpm / 60) + 0.5)
  
  -- Snap to nearest musical value
  local musical_values = {1, 2, 4, 8, 16, 32, 64, 128, 256, 512}
  local snapped_beats = duration_beats  -- default to calculated value
  
  for _, m in ipairs(musical_values) do
    -- If within 15% of a musical value, snap to it
    if math.abs(m - duration_beats) < duration_beats * 0.15 then
      snapped_beats = m
      break
    elseif m > duration_beats then
      -- Use the next higher musical value if we haven't found a close match
      snapped_beats = m
      break
    end
  end
  
  -- Clamp to valid range
  snapped_beats = math.max(1, math.min(512, snapped_beats))
  
  print(string.format("SlicePro: Duration-based fallback: %.2f sec @ %d BPM = %d beats (snapped to %d)", 
    duration_sec, song_bpm, duration_beats, snapped_beats))
  
  return snapped_beats
end

--------------------------------------------------------------------------------
-- RMS + Autocorrelation Analysis (Hybrid Beat Detection)
--------------------------------------------------------------------------------

local function SliceProAnalyzeRMS(buffer, silent)
  local frames = buffer.number_of_frames
  local sr = buffer.sample_rate
  local channel = 1
  local duration_sec = frames / sr
  
  -- OPTIMIZATION: Skip slow DSP analysis for large files (>30 seconds)
  -- Use fast duration-based calculation instead to prevent timeouts
  if duration_sec > 30 then
    print(string.format("SlicePro: Large file detected (%.1f sec), using fast duration-based analysis", duration_sec))
    if not silent then
      renoise.app():show_status("SlicePro: Large file - using fast analysis")
    end
    local duration_beats = SliceProCalculateDurationBeats(frames, sr)
    return { 
      total_beats = duration_beats, 
      confidence = 0.5, 
      method = "duration-fast" 
    }
  end
  
  print(string.format("SlicePro: RMS analysis starting - %d frames @ %d Hz (%.2f sec)", frames, sr, duration_sec))
  
  -- Show progress for samples > 5 seconds
  local show_progress = duration_sec > 5 and not silent
  
  if show_progress then
    renoise.app():show_status("SlicePro: Analyzing... 0%")
  end
  
  -- RMS envelope extraction (20ms window, 50% overlap)
  local win = math.floor(sr * 0.02)
  local hop = math.floor(win / 2)
  local env = {}
  local total_steps = math.floor((frames - win) / hop)
  local progress_interval = math.floor(total_steps / 4)  -- Update 4 times
  
  for pos = 1, frames - win, hop do
    local sum = 0
    for i = 0, win - 1 do
      local v = buffer:sample_data(channel, pos + i)
      sum = sum + (v * v)
    end
    env[#env + 1] = math.sqrt(sum / win)
    
    -- Progress indication
    if show_progress and #env % progress_interval == 0 then
      local pct = math.floor((#env / total_steps) * 50)  -- First 50% is envelope extraction
      renoise.app():show_status(string.format("SlicePro: Extracting envelope... %d%%", pct))
    end
  end
  
  print(string.format("SlicePro: Extracted %d RMS envelope points", #env))
  
  if #env < 10 then
    print("SlicePro: Not enough envelope data, using fallback")
    -- Use intelligent detection as fallback
    if preferences.SlicePro.SliceProFallbackOnLowConfidence and 
       preferences.SlicePro.SliceProFallbackOnLowConfidence.value then
      local detected_bpm, beat_count = pakettiBPMDetectFromSample(frames, sr)
      print(string.format("SlicePro: Fallback detected %.1f BPM, %d beats", detected_bpm, beat_count))
      return { total_beats = beat_count, confidence = 0.4, method = "fallback-intelligent" }
    end
    -- Use duration-based calculation instead of hardcoded 4
    local duration_beats = SliceProCalculateDurationBeats(frames, sr)
    return { total_beats = duration_beats, confidence = 0.3, method = "duration-fallback" }
  end
  
  if show_progress then
    renoise.app():show_status("SlicePro: Autocorrelation... 50%")
  end
  
  -- Autocorrelation to find beat period (30-240 BPM range)
  local min_lag = math.floor((60 / 240) * (sr / hop))
  local max_lag = math.floor((60 / 30) * (sr / hop))
  
  print(string.format("SlicePro: Autocorrelation lag range: %d to %d", min_lag, max_lag))
  
  local best_lag = nil
  local best_corr = 0
  local lag_range = max_lag - min_lag
  local lag_progress_interval = math.floor(lag_range / 4)
  
  for lag = min_lag, max_lag do
    local corr = 0
    for i = 1, #env - lag do
      corr = corr + env[i] * env[i + lag]
    end
    if corr > best_corr then
      best_corr = corr
      best_lag = lag
    end
    
    -- Progress indication for autocorrelation (50-100%)
    if show_progress and (lag - min_lag) % lag_progress_interval == 0 then
      local pct = 50 + math.floor(((lag - min_lag) / lag_range) * 50)
      renoise.app():show_status(string.format("SlicePro: Correlating... %d%%", pct))
    end
  end
  
  if not best_lag then
    print("SlicePro: No correlation peak found, using fallback")
    -- Use intelligent detection as fallback
    if preferences.SlicePro.SliceProFallbackOnLowConfidence and 
       preferences.SlicePro.SliceProFallbackOnLowConfidence.value then
      local detected_bpm, beat_count = pakettiBPMDetectFromSample(frames, sr)
      print(string.format("SlicePro: Fallback detected %.1f BPM, %d beats", detected_bpm, beat_count))
      return { total_beats = beat_count, confidence = 0.4, method = "fallback-intelligent" }
    end
    -- Use duration-based calculation instead of hardcoded 4
    local duration_beats = SliceProCalculateDurationBeats(frames, sr)
    return { total_beats = duration_beats, confidence = 0.3, method = "duration-fallback" }
  end
  
  local seconds_per_beat = (best_lag * hop) / sr
  local duration = frames / sr
  local raw_beats = duration / seconds_per_beat
  
  print(string.format("SlicePro: Best lag=%d, seconds_per_beat=%.4f, raw_beats=%.2f", 
    best_lag, seconds_per_beat, raw_beats))
  
  -- Snap to musical counts if close (within 0.5 beats)
  local musical = {1, 2, 4, 8, 16, 32, 64, 128, 256, 512}
  local beats = raw_beats
  local snapped = false
  
  for _, m in ipairs(musical) do
    if math.abs(m - raw_beats) < 0.5 then
      beats = m
      snapped = true
      print(string.format("SlicePro: Snapped %.2f to %d beats", raw_beats, m))
      break
    end
  end
  
  if not snapped then
    -- Round to nearest 0.5
    beats = math.floor(raw_beats * 2 + 0.5) / 2
    print(string.format("SlicePro: Rounded to %.1f beats (no snap)", beats))
  end
  
  -- Calculate confidence (normalize correlation)
  local confidence = math.min(1.0, best_corr / 1e6)
  
  -- Check if confidence is below threshold and fallback is enabled
  local threshold = preferences.SlicePro.SliceProConfidenceThreshold and 
                    preferences.SlicePro.SliceProConfidenceThreshold.value or 0.3
  
  if confidence < threshold and preferences.SlicePro.SliceProFallbackOnLowConfidence and 
     preferences.SlicePro.SliceProFallbackOnLowConfidence.value then
    print(string.format("SlicePro: Low confidence (%.2f < %.2f), using fallback", confidence, threshold))
    local detected_bpm, beat_count = pakettiBPMDetectFromSample(frames, sr)
    print(string.format("SlicePro: Fallback detected %.1f BPM, %d beats", detected_bpm, beat_count))
    return { total_beats = beat_count, confidence = 0.5, method = "fallback-intelligent" }
  end
  
  -- Store RMS result
  local rms_beats = beats
  local rms_confidence = confidence
  local method = "hybrid"
  
  -- Run transient detection for comparison (hybrid approach)
  local transient_bpm, transient_beats, transients = pakettiBPMDetectFromTransients(buffer, rms_beats)
  
  if transient_beats and transient_beats > 0 then
    local transient_confidence = 0
    if transients and #transients > 0 then
      -- Calculate confidence based on transient count vs expected
      -- More transients relative to beat count = higher confidence
      local expected_transients = transient_beats * 2  -- Assume ~2 transients per beat minimum
      transient_confidence = math.min(1.0, #transients / expected_transients)
      
      -- Boost confidence if transient count aligns well with detected beats
      local transients_per_beat = #transients / transient_beats
      if transients_per_beat >= 1 and transients_per_beat <= 4 then
        transient_confidence = transient_confidence * 1.2  -- Boost for reasonable alignment
        transient_confidence = math.min(1.0, transient_confidence)
      end
    end
    
    print(string.format("SlicePro: Transient detection found %d transients, estimated %d beats (confidence: %.2f)", 
      transients and #transients or 0, transient_beats, transient_confidence))
    
    -- Use transient result if more confident than RMS
    if transient_confidence > rms_confidence then
      beats = transient_beats
      confidence = transient_confidence
      method = "transient"
      print(string.format("SlicePro: Using transient method (%.2f > %.2f)", transient_confidence, rms_confidence))
    else
      print(string.format("SlicePro: Keeping RMS method (%.2f >= %.2f)", rms_confidence, transient_confidence))
    end
  end
  
  print(string.format("SlicePro: Analysis complete - %s beats, confidence=%.2f, method=%s", 
    tostring(beats), confidence, method))
  
  if show_progress then
    renoise.app():show_status("SlicePro: Analysis complete")
  end
  
  return {
    total_beats = beats,
    confidence = confidence,
    method = method
  }
end

--------------------------------------------------------------------------------
-- Get Slice Frame Ranges
--------------------------------------------------------------------------------

local function SliceProGetSliceRanges()
  local song = renoise.song()
  local instrument = song.selected_instrument
  local root_sample = instrument.samples[1]
  local markers = root_sample.slice_markers
  local total_frames = root_sample.sample_buffer.number_of_frames
  
  local ranges = {}
  
  if #markers == 0 then
    return ranges
  end
  
  for i = 1, #markers do
    local start_frame = markers[i]
    local end_frame
    
    if i < #markers then
      end_frame = markers[i + 1]
    else
      end_frame = total_frames
    end
    
    local length_frames = end_frame - start_frame
    
    table.insert(ranges, {
      start_frame = start_frame,
      end_frame = end_frame,
      length_frames = length_frames
    })
  end
  
  return ranges
end

--------------------------------------------------------------------------------
-- Main Analysis Function
--------------------------------------------------------------------------------

function SliceProAnalyze(silent)
  print("SlicePro: Starting analysis...")
  
  local valid, err = SliceProValidateSelection()
  if not valid then
    if not silent then
      renoise.app():show_status("SlicePro: " .. err)
    end
    return false
  end
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  local root_sample = instrument.samples[1]
  local buffer = root_sample.sample_buffer
  
  local total_frames = buffer.number_of_frames
  local sample_rate = buffer.sample_rate
  local markers = root_sample.slice_markers
  
  -- Store basic info in state
  SliceProState.instrument_index = song.selected_instrument_index
  SliceProState.total_frames = total_frames
  SliceProState.sample_rate = sample_rate
  SliceProState.sample_name = root_sample.name
  
  -- Attach observers for cache invalidation
  SliceProAttachObservers(root_sample)
  
  -- Try to load persistent overrides first
  SliceProLoadOverrides()
  
  -- If root override exists, use it instead of analysis
  if SliceProState.root_override then
    print(string.format("SlicePro: Using root override of %.1f beats", SliceProState.root_override))
    SliceProState.total_beats = SliceProState.root_override
    SliceProState.confidence = 1.0  -- Manual = full confidence
    SliceProState.method = "override"
  else
    -- Use RMS + autocorrelation hybrid analysis
    local analysis = SliceProAnalyzeRMS(buffer, silent)
    
    SliceProState.total_beats = analysis.total_beats
    SliceProState.confidence = analysis.confidence
    SliceProState.method = analysis.method
    
    print(string.format("SlicePro: Detected %.1f beats (confidence: %.0f%%, method: %s)", 
      analysis.total_beats, analysis.confidence * 100, analysis.method))
  end
  
  -- Calculate per-slice beats proportionally (unless individual overrides exist)
  SliceProState.slice_beats = {}
  
  if #markers > 0 then
    local ranges = SliceProGetSliceRanges()
    
    for i, range in ipairs(ranges) do
      -- Only calculate if no user override exists for this slice
      if not SliceProState.user_overrides[i] then
        local slice_ratio = range.length_frames / total_frames
        local slice_beats = slice_ratio * SliceProState.total_beats
        SliceProState.slice_beats[i] = slice_beats
        
        print(string.format("SlicePro: Slice %d: %d frames (%.2f%%) = %.2f beats", 
          i, range.length_frames, slice_ratio * 100, slice_beats))
      else
        -- Use existing override
        SliceProState.slice_beats[i] = SliceProState.user_overrides[i]
        print(string.format("SlicePro: Slice %d: using override = %.2f beats", 
          i, SliceProState.user_overrides[i]))
      end
    end
  end
  
  SliceProState.dirty = false
  
  if not silent then
    local slice_count = #markers
    if slice_count > 0 then
      renoise.app():show_status(string.format("SlicePro: Analyzed %d slices, %.1f total beats (%.0f%% confidence)", 
        slice_count, SliceProState.total_beats, SliceProState.confidence * 100))
    else
      renoise.app():show_status(string.format("SlicePro: %.1f total beats detected (%.0f%% confidence)", 
        SliceProState.total_beats, SliceProState.confidence * 100))
    end
  end
  
  return true
end

--------------------------------------------------------------------------------
-- Apply Beat Sync
--------------------------------------------------------------------------------

function SliceProApply(silent)
  print("SlicePro: Applying beat sync settings...")
  
  -- Sample Editor check (if enabled in preferences)
  if not SliceProEnsureSampleEditor() then
    return false
  end
  
  local valid, err = SliceProValidateSelection()
  if not valid then
    if not silent then
      renoise.app():show_status("SlicePro: " .. err)
    end
    return false
  end
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  local root_sample = instrument.samples[1]
  local markers = root_sample.slice_markers
  local lpb = song.transport.lpb
  
  -- Check if we have analysis for current instrument
  if not SliceProState.total_beats or 
     SliceProState.instrument_index ~= song.selected_instrument_index then
    if not silent then
      renoise.app():show_status("SlicePro: No analysis available, run analysis first")
    end
    return false
  end
  
  -- Save overrides to preferences before applying
  SliceProSaveOverrides()
  
  -- Create undo point for single Ctrl+Z undo
  song:describe_undo("SlicePro Apply")
  
  -- Use root override if set, otherwise use analyzed total_beats
  local effective_total_beats = SliceProState.root_override or SliceProState.total_beats
  
  -- Check if beat sync should be enabled for slices (default is OFF)
  local beatsync_enabled = preferences.SlicePro.SliceProBeatsyncEnabled and preferences.SlicePro.SliceProBeatsyncEnabled.value or false
  
  if #markers == 0 then
    -- No slices, just apply to root sample
    local sync_lines = math.max(1, math.min(512, math.floor(effective_total_beats * lpb + 0.5)))
    root_sample.beat_sync_enabled = beatsync_enabled
    if beatsync_enabled then
      root_sample.beat_sync_lines = sync_lines
      root_sample.beat_sync_mode = preferences.SlicePro.SliceProBeatsyncMode.value
    end
    
    if not silent then
      renoise.app():show_status(string.format("SlicePro: Applied %d lines to root sample%s", sync_lines, beatsync_enabled and "" or " (Beatsync off)"))
    end
    return true
  end
  
  -- Slices are samples[2], samples[3], etc.
  local applied_count = 0
  local warnings = {}
  
  for i = 2, #instrument.samples do
    local sample = instrument.samples[i]
    local slice_index = i - 1
    
    -- Check if this is a slice alias
    if sample.is_slice_alias then
      -- Use user override if exists, otherwise calculated beats
      local beats = SliceProState.user_overrides[slice_index] or SliceProState.slice_beats[slice_index]
      
      if beats then
        -- Convert beats to beat_sync_lines
        local sync_lines = math.max(1, math.min(512, math.floor(beats * lpb + 0.5)))
        
        -- Check if we're clamping
        if beats * lpb > 512 then
          table.insert(warnings, string.format("Slice %d: %.1f beats clamped to 512 lines", slice_index, beats))
        end
        
        sample.beat_sync_enabled = beatsync_enabled
        if beatsync_enabled then
          sample.beat_sync_lines = sync_lines
          sample.beat_sync_mode = preferences.SlicePro.SliceProBeatsyncMode.value
        end
        
        -- Apply other preferences
        sample.mute_group = preferences.SlicePro.SliceProMuteGroup.value
        sample.new_note_action = preferences.SlicePro.SliceProNNA.value
        sample.loop_mode = preferences.SlicePro.SliceProLoopMode.value
        sample.autofade = preferences.SlicePro.SliceProAutofade.value
        sample.loop_release = preferences.SlicePro.SliceProLoopRelease.value
        
        -- Apply oneshot if enabled
        if preferences.SlicePro.SliceProOneShot and preferences.SlicePro.SliceProOneShot.value then
          sample.oneshot = true
        end
        
        applied_count = applied_count + 1
        print(string.format("SlicePro: Slice %d: %.2f beats -> %d lines", slice_index, beats, sync_lines))
      end
    end
  end
  
  -- NOTE: Root sample beat sync is NOT modified when slices exist
  -- Only slices get beat sync applied (if enabled)
  -- The root sample's beat sync state is left as-is
  
  -- Show warnings if any
  if #warnings > 0 then
    for _, warning in ipairs(warnings) do
      print("SlicePro WARNING: " .. warning)
    end
  end
  
  if not silent then
    renoise.app():show_status(string.format("SlicePro: Applied to %d slices (LPB=%d%s)", applied_count, lpb, beatsync_enabled and "" or ", Beatsync off"))
  end
  return true
end

--------------------------------------------------------------------------------
-- Silent Apply (One-Button, No GUI)
--------------------------------------------------------------------------------

function SliceProSilentApply()
  -- Sample Editor check
  if not SliceProEnsureSampleEditor() then
    return
  end
  
  local valid, err = SliceProValidateSelection()
  if not valid then
    renoise.app():show_status("SlicePro: " .. err)
    return
  end
  
  local song = renoise.song()
  
  -- If no analysis, cache is dirty, or different instrument - analyze first
  if not SliceProState.total_beats or 
     SliceProState.instrument_index ~= song.selected_instrument_index or
     SliceProState.dirty then
    SliceProAnalyze(true)  -- Silent analysis
  end
  
  -- Apply immediately
  if SliceProApply(true) then  -- Silent apply
    local slice_count = #song.selected_instrument.samples[1].slice_markers
    if slice_count > 0 then
      renoise.app():show_status(string.format("SlicePro: Applied to %d slices (%.1f beats)", 
        slice_count, SliceProState.total_beats))
    else
      renoise.app():show_status(string.format("SlicePro: Applied %.1f beats to sample", 
        SliceProState.total_beats))
    end
  end
end

--------------------------------------------------------------------------------
-- Recalculate from Total Beats
--------------------------------------------------------------------------------

local function SliceProRecalculateFromTotal(new_total_beats, is_override)
  if not SliceProState.total_frames then return end
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  local markers = instrument.samples[1].slice_markers
  
  -- If this is a manual override, store it
  if is_override then
    SliceProState.root_override = new_total_beats
  end
  
  if #markers == 0 then
    SliceProState.total_beats = new_total_beats
    return
  end
  
  local ranges = SliceProGetSliceRanges()
  
  SliceProState.total_beats = new_total_beats
  SliceProState.slice_beats = {}
  
  for i, range in ipairs(ranges) do
    -- Only recalculate if no user override exists for this slice
    if not SliceProState.user_overrides[i] then
      local slice_ratio = range.length_frames / SliceProState.total_frames
      SliceProState.slice_beats[i] = slice_ratio * new_total_beats
    end
  end
end

--------------------------------------------------------------------------------
-- Config GUI
--------------------------------------------------------------------------------

function SliceProConfigDialog()
  -- Sample Editor check (if enabled)
  if not SliceProEnsureSampleEditor() then
    return
  end
  
  -- Close existing dialog if open
  if slicepro_dialog and slicepro_dialog.visible then
    slicepro_dialog:close()
    slicepro_dialog = nil
  end
  
  local valid, err = SliceProValidateSelection()
  if not valid then
    renoise.app():show_status("SlicePro: " .. err)
    return
  end
  
  -- Mark that user has touched config (prevents auto-re-analysis on Apply)
  state_flags.user_touched_config = true
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  local root_sample = instrument.samples[1]
  local markers = root_sample.slice_markers
  local lpb = song.transport.lpb
  
  -- Run analysis if not done for current instrument
  if not SliceProState.total_beats or 
     SliceProState.instrument_index ~= song.selected_instrument_index then
    SliceProAnalyze()
  end
  
  vb = renoise.ViewBuilder()
  
  -- Determine if root override is active
  local has_root_override = SliceProState.root_override ~= nil
  local effective_total_beats = SliceProState.root_override or SliceProState.total_beats or 4
  
  -- Get sample buffer info
  local buffer = root_sample.sample_buffer
  local sample_rate = buffer and buffer.sample_rate or 44100
  local bit_depth = buffer and buffer.bit_depth or 16
  local channels = buffer and buffer.number_of_channels or 1
  local channel_str = channels == 1 and "mono" or "stereo"
  
  local dialog_content = vb:column{
    --margin = 6,
    --spacing = 4,
    
    -- Header row: sample info + slice count + rows/col dropdown
    vb:row{
      vb:text{
        text = string.format("%s | %dHz %dbit %s | %d slices", 
          root_sample.name ~= "" and root_sample.name or instrument.name,
          sample_rate, bit_depth, channel_str, #markers),
        font = "mono"
      },
      vb:text{text = "  Rows/Col:"},
      vb:popup{
        items = {"5", "10", "15", "30", "35", "40", "45", "50", "55", "60", "80", "128"},
        value = (function()
          for i, v in ipairs(slicepro_rows_options) do
            if v == slicepro_rows_per_column then return i end
          end
          return 4  -- Default to 30
        end)(),
        width = 50,
        notifier = function(idx)
          slicepro_rows_per_column = slicepro_rows_options[idx]
          -- Refresh dialog
          if slicepro_dialog and slicepro_dialog.visible then
            slicepro_dialog:close()
            slicepro_dialog = nil
            SliceProConfigDialog()
          end
        end
      }
    },
    
    -- Two-column layout: Analysis Info (left) | Global Slice Settings (right)
    vb:row{
      --spacing = 16,
      
      -- LEFT COLUMN: Analysis Info
      vb:column{
        --spacing = 2,
        
        -- Total Beats row
        vb:row{
          vb:text{text = "Total Beats:", width = 80},
          vb:valuebox{
            id = "slicepro_total_beats",
            min = 1,
            max = 512,
            value = effective_total_beats,
            width = 55,
            tostring = function(val) return string.format("%.1f", val) end,
            tonumber = function(str) return tonumber(str) end,
            notifier = function(val)
              local override_checkbox = vb.views["slicepro_root_override"]
              if override_checkbox and override_checkbox.value then
                SliceProRecalculateFromTotal(val, true)
              else
                SliceProRecalculateFromTotal(val, false)
              end
            end
          },
          vb:checkbox{
            id = "slicepro_root_override",
            value = has_root_override,
            notifier = function(val)
              if val then
                local beats_view = vb.views["slicepro_total_beats"]
                if beats_view then
                  SliceProState.root_override = beats_view.value
                end
              else
                SliceProState.root_override = nil
              end
            end
          },
          vb:text{text = "Override"}
        },
        
        -- LPB info row
        vb:row{
          vb:text{text = string.format("(LPB: %d, Max per slice: %.1f beats)", lpb, 512 / lpb), style = "disabled"}
        },
        
        -- Confidence row
        vb:row{
          vb:text{text = "Confidence:", width = 80},
          vb:text{
            id = "slicepro_confidence",
            text = string.format("%.0f%%", (SliceProState.confidence or 0) * 100),
            font = "mono",
            width = 40
          },
          vb:text{text = string.format("(Method: %s)", SliceProState.method or "none")}
        },
        
        -- Sample info row
        vb:row{
          vb:text{
            text = string.format("Sample: %d frames @ %d Hz = %.2f sec", 
              SliceProState.total_frames or 0,
              SliceProState.sample_rate or 44100,
              (SliceProState.total_frames or 0) / (SliceProState.sample_rate or 44100)),
            font = "mono"
          }
        }
      },
      
      -- RIGHT COLUMN: Global Slice Settings
      vb:column{
        --spacing = 2,
        
        -- Beatsync Enable/Mode
        vb:row{
          vb:checkbox{
            id = "slicepro_beatsync_enabled",
            value = preferences.SlicePro.SliceProBeatsyncEnabled and preferences.SlicePro.SliceProBeatsyncEnabled.value or false,
            notifier = function(val)
              if preferences.SlicePro.SliceProBeatsyncEnabled then
                preferences.SlicePro.SliceProBeatsyncEnabled.value = val
              end
            end
          },
          vb:text{text = "Beatsync:", width = 70},
          vb:popup{
            id = "slicepro_beatsync_mode",
            items = {"Repitch", "Percussion", "Texture"},
            value = preferences.SlicePro.SliceProBeatsyncMode.value,
            width = 100,
            notifier = function(val)
              preferences.SlicePro.SliceProBeatsyncMode.value = val
            end
          }
        },
        
        -- Mute Group
        vb:row{
          vb:text{text = "Mute Group:", width = 90},
          vb:valuebox{
            id = "slicepro_mute_group",
            min = 0,
            max = 15,
            value = preferences.SlicePro.SliceProMuteGroup.value,
            width = 50,
            notifier = function(val)
              preferences.SlicePro.SliceProMuteGroup.value = val
            end
          },
          vb:text{text = "(0 = None)"}
        },
        
        -- NNA
        vb:row{
          vb:text{text = "NNA:", width = 90},
          vb:popup{
            id = "slicepro_nna",
            items = {"Cut", "Note Off", "Sustain"},
            value = preferences.SlicePro.SliceProNNA.value,
            width = 100,
            notifier = function(val)
              preferences.SlicePro.SliceProNNA.value = val
            end
          }
        },
        
        -- Loop Mode
        vb:row{
          vb:text{text = "Loop Mode:", width = 90},
          vb:popup{
            id = "slicepro_loop_mode",
            items = {"Off", "Forward", "Reverse", "Ping-Pong"},
            value = preferences.SlicePro.SliceProLoopMode.value,
            width = 100,
            notifier = function(val)
              preferences.SlicePro.SliceProLoopMode.value = val
            end
          }
        },
        
        -- Checkboxes row
        vb:row{
          vb:checkbox{
            id = "slicepro_oneshot",
            value = preferences.SlicePro.SliceProOneShot and preferences.SlicePro.SliceProOneShot.value or true,
            notifier = function(val)
              if preferences.SlicePro.SliceProOneShot then
                preferences.SlicePro.SliceProOneShot.value = val
              end
            end
          },
          vb:text{text = "One-Shot"},
          --vb:space{width = 6},
          vb:checkbox{
            id = "slicepro_autofade",
            value = preferences.SlicePro.SliceProAutofade.value,
            notifier = function(val)
              preferences.SlicePro.SliceProAutofade.value = val
            end
          },
          vb:text{text = "Autofade"},
          --vb:space{width = 6},
          vb:checkbox{
            id = "slicepro_loop_release",
            value = preferences.SlicePro.SliceProLoopRelease.value,
            notifier = function(val)
              preferences.SlicePro.SliceProLoopRelease.value = val
            end
          },
          vb:text{text = "Loop Release"}
        }
      }
    },
    
    --vb:space{height = 4}
  }
  
  -- Buttons Row (all buttons in single row)
  local button_row = vb:row{
    vb:button{
      text = "Analyze",
      width = 60,
      notifier = function()
        -- Clear root override if user wants fresh analysis
        SliceProState.root_override = nil
        SliceProAnalyze()
        -- Close and reopen to refresh
        if slicepro_dialog and slicepro_dialog.visible then
          slicepro_dialog:close()
          slicepro_dialog = nil
          SliceProConfigDialog()
        end
      end
    },
    vb:button{
      text = "Apply",
      width = 50,
      notifier = function()
        -- Update total beats from GUI
        local total_beats_view = vb.views["slicepro_total_beats"]
        local override_checkbox = vb.views["slicepro_root_override"]
        if total_beats_view then
          local is_override = override_checkbox and override_checkbox.value
          SliceProRecalculateFromTotal(total_beats_view.value, is_override)
        end
        SliceProApply()
      end
    },
    vb:button{
      text = "Silent Apply",
      width = 70,
      notifier = function()
        -- Update total beats from GUI first
        local total_beats_view = vb.views["slicepro_total_beats"]
        local override_checkbox = vb.views["slicepro_root_override"]
        if total_beats_view then
          local is_override = override_checkbox and override_checkbox.value
          SliceProRecalculateFromTotal(total_beats_view.value, is_override)
        end
        SliceProApply(true)
        renoise.app():show_status("SlicePro: Applied silently")
      end
    },
    vb:button{
      text = "Clear Overrides",
      width = 90,
      notifier = function()
        SliceProClearAllOverrides()
        -- Refresh dialog
        if slicepro_dialog and slicepro_dialog.visible then
          slicepro_dialog:close()
          slicepro_dialog = nil
          SliceProAnalyze()  -- Re-analyze without overrides
          SliceProConfigDialog()
        end
      end
    },
    vb:button{
      text = "Real-Time Slice",
      width = 90,
      notifier = function()
        pakettiRealtimeSliceInsertMarker()
      end
    },
    vb:button{
      text = "Close",
      width = 50,
      notifier = function()
        if slicepro_dialog and slicepro_dialog.visible then
          slicepro_dialog:close()
          slicepro_dialog = nil
        end
      end
    }
  }
  
  dialog_content:add_child(button_row)
  
  -- Slice List Section (only if there are slices)
  if #markers > 0 then
    -- Multi-column slice display
    local rows_per_column = slicepro_rows_per_column
    local max_columns = 8
    local display_limit = rows_per_column * max_columns
    local slices_to_display = math.min(#markers, display_limit)
    local column_count = math.ceil(slices_to_display / rows_per_column)
    
    local ranges = SliceProGetSliceRanges()
    
    -- Create multi-column container
    local columns_container = vb:row{}
    
    for col = 1, column_count do
      local column = vb:column{}
      
      -- Compact column header
      column:add_child(vb:row{
        vb:text{text = "Slice", width = 35, font = "mono"},
        vb:text{text = "Frames", width = 55, font = "mono"},
        --vb:space{width = 4},
        vb:text{text = "Beats", width = 55},
        vb:text{text = "Lines", width = 35},
        vb:text{text = "Override", width = 50}
      })
      
      -- Calculate slice range for this column
      local start_idx = (col - 1) * rows_per_column + 1
      local end_idx = math.min(col * rows_per_column, slices_to_display)
      
      -- Build slice rows for this column
      for i = start_idx, end_idx do
        local beats = SliceProState.user_overrides[i] or SliceProState.slice_beats[i] or 1
        local sync_lines = math.max(1, math.min(512, math.floor(beats * lpb + 0.5)))
        local frames = ranges[i] and ranges[i].length_frames or 0
        local has_override = SliceProState.user_overrides[i] ~= nil
        
        local slice_row = vb:row{
          vb:text{text = string.format("%02d", i), width = 35, font = "mono"},
          vb:text{text = string.format("%d", frames), width = 55, font = "mono"},
          --vb:space{width = 4},
          vb:valuebox{
            id = "slicepro_slice_beats_" .. i,
            min = 0.1,
            max = 64,
            value = beats,
            width = 55,
            tostring = function(val) return string.format("%.2f", val) end,
            tonumber = function(str) return tonumber(str) end,
            notifier = function(val)
              SliceProState.user_overrides[i] = val
            end
          },
          vb:text{
            id = "slicepro_slice_lines_" .. i,
            text = string.format("%d", sync_lines), 
            width = 35, 
            font = "mono"
          },
          vb:button{
            text = has_override and "Clear" or "-",
            width = 50,
            active = has_override,
            notifier = function()
              SliceProState.user_overrides[i] = nil
            end
          }
        }
        
        column:add_child(slice_row)
      end
      
      columns_container:add_child(column)
    end
    
    dialog_content:add_child(columns_container)
    
    -- Show message if more slices exist beyond display limit
    if #markers > display_limit then
      dialog_content:add_child(vb:row{
        vb:text{text = string.format("... and %d more slices (all will be processed)", #markers - display_limit)}
      })
    end
    
    dialog_content:add_child(vb:space{height = 2})
  else
    dialog_content:add_child(vb:row{
      vb:text{text = "No slices in sample. Total beats will be applied to root sample only.", style = "disabled"}
    })
    dialog_content:add_child(vb:space{height = 2})
  end
  
  -- Create keyhandler
  local keyhandler = create_keyhandler_for_dialog(
    function() return slicepro_dialog end,
    function(value) slicepro_dialog = value end
  )
  
  slicepro_dialog = renoise.app():show_custom_dialog("SlicePro Config", dialog_content, keyhandler)
  
  -- Set active_middle_frame to ensure Renoise gets keyboard presses
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

--------------------------------------------------------------------------------
-- Main Entry Point
--------------------------------------------------------------------------------

function SliceProApplyOrConfig()
  -- Sample Editor check
  if not SliceProEnsureSampleEditor() then
    return
  end
  
  local valid, err = SliceProValidateSelection()
  if not valid then
    renoise.app():show_status("SlicePro: " .. err)
    return
  end
  
  local song = renoise.song()
  
  -- If user has touched config, respect their settings and just apply
  if state_flags.user_touched_config and SliceProState.total_beats and 
     SliceProState.instrument_index == song.selected_instrument_index and
     not SliceProState.dirty then
    SliceProApply()
    return
  end
  
  -- If no analysis, cache is dirty, or different instrument - open Config for first time
  if not SliceProState.total_beats or 
     SliceProState.instrument_index ~= song.selected_instrument_index or
     SliceProState.dirty then
    SliceProConfigDialog()
  else
    -- Analysis exists, apply directly
    SliceProApply()
  end
end

--------------------------------------------------------------------------------
-- Keybindings
--------------------------------------------------------------------------------

renoise.tool():add_keybinding{
  name = "Sample Editor:Paketti:SlicePro Apply",
  invoke = SliceProApplyOrConfig
}

renoise.tool():add_keybinding{
  name = "Sample Editor:Paketti:SlicePro Config...",
  invoke = SliceProConfigDialog
}

renoise.tool():add_keybinding{
  name = "Sample Editor:Paketti:SlicePro Silent Apply",
  invoke = SliceProSilentApply
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:SlicePro Apply",
  invoke = SliceProApplyOrConfig
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:SlicePro Config...",
  invoke = SliceProConfigDialog
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:SlicePro Silent Apply",
  invoke = SliceProSilentApply
}

--------------------------------------------------------------------------------
-- MIDI Mappings
--------------------------------------------------------------------------------

renoise.tool():add_midi_mapping{
  name = "Paketti:SlicePro Apply",
  invoke = function(message)
    if message:is_trigger() then
      SliceProApplyOrConfig()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:SlicePro Config",
  invoke = function(message)
    if message:is_trigger() then
      SliceProConfigDialog()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:SlicePro Silent Apply",
  invoke = function(message)
    if message:is_trigger() then
      SliceProSilentApply()
    end
  end
}

--------------------------------------------------------------------------------
-- Menu Entries
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti..:SlicePro:SlicePro Apply",
  invoke = SliceProApplyOrConfig
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti..:SlicePro:SlicePro Config...",
  invoke = SliceProConfigDialog
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti..:SlicePro:SlicePro Silent Apply",
  invoke = SliceProSilentApply
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti..:SlicePro:SlicePro Apply",
  invoke = SliceProApplyOrConfig
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti..:SlicePro:SlicePro Config...",
  invoke = SliceProConfigDialog
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti..:SlicePro:SlicePro Silent Apply",
  invoke = SliceProSilentApply
}

--------------------------------------------------------------------------------
-- PHRASE CREATION FROM SLICEPRO BEAT ANALYSIS
--------------------------------------------------------------------------------

-- Get the current SlicePro state for external access
function PakettiSliceProGetState()
  return {
    instrument_index = SliceProState.instrument_index,
    total_beats = SliceProState.total_beats,
    slice_beats = SliceProState.slice_beats,
    confidence = SliceProState.confidence,
    method = SliceProState.method,
    sample_rate = SliceProState.sample_rate,
    total_frames = SliceProState.total_frames,
    dirty = SliceProState.dirty
  }
end

-- Calculate optimal LPB for a beat count
function PakettiSliceProCalculateLPBForBeats(beats)
  if not beats or beats <= 0 then return 4 end
  
  -- Common beat values and their ideal LPB
  -- Goal: minimize lines while keeping integer counts
  local beat_value = beats
  
  -- For fractional beats, we want higher LPB
  if beat_value < 1 then
    if beat_value >= 0.5 then
      return 8  -- Half beat = 4 lines at LPB 8
    elseif beat_value >= 0.25 then
      return 16  -- Quarter beat = 4 lines at LPB 16
    else
      return 4  -- Very short, default
    end
  elseif beat_value == math.floor(beat_value) then
    -- Whole beats - use song LPB
    return renoise.song().transport.lpb
  else
    -- Fractional beats - use higher LPB for accuracy
    return 8
  end
end

-- Create beat-synced phrases from SlicePro analysis
function PakettiSliceProCreateBeatsyncedPhrases()
  local song = renoise.song()
  if not song then return end
  
  -- Check if we have valid analysis
  if not SliceProState.total_beats or not SliceProState.slice_beats or #SliceProState.slice_beats == 0 then
    renoise.app():show_status("SlicePro: No beat analysis available. Run SlicePro Apply first.")
    return
  end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("SlicePro: No instrument selected")
    return
  end
  
  local sample = instrument.samples[1]
  if not sample then
    renoise.app():show_status("SlicePro: No sample in instrument")
    return
  end
  
  -- Get base note for slice triggering
  local base_note = 48  -- C-4
  if sample.sample_mapping then
    base_note = sample.sample_mapping.base_note
  end
  
  local slice_count = #sample.slice_markers
  if slice_count == 0 then
    renoise.app():show_status("SlicePro: No slices in sample")
    return
  end
  
  local phrases_created = {}
  print("SlicePro Phrases: Creating " .. slice_count .. " beat-synced phrases")
  
  for slice_index = 1, slice_count do
    local beats = SliceProState.slice_beats[slice_index] or 1
    
    -- Calculate optimal LPB and line count for this slice's beat duration
    local phrase_lpb = PakettiSliceProCalculateLPBForBeats(beats)
    local phrase_lines = math.max(1, math.floor(beats * phrase_lpb + 0.5))
    
    -- Create a new phrase
    local phrase_index = #instrument.phrases + 1
    instrument:insert_phrase_at(phrase_index)
    local phrase = instrument.phrases[phrase_index]
    
    if phrase then
      -- Configure phrase with beat-accurate timing
      phrase.name = string.format("Slice %02d (%.2f beats)", slice_index, beats)
      phrase.number_of_lines = phrase_lines
      phrase.lpb = phrase_lpb
      phrase.is_empty = false
      phrase.autoseek = false
      phrase.loop_start = 1
      phrase.loop_end = phrase_lines
      phrase.looping = true
      
      -- Ensure at least 1 note column
      if phrase.visible_note_columns < 1 then
        phrase.visible_note_columns = 1
      end
      
      -- Write the slice trigger note on line 1
      local slice_note = base_note + slice_index
      if slice_note > 119 then slice_note = 119 end
      
      local line = phrase:line(1)
      line.note_columns[1].note_value = slice_note
      line.note_columns[1].instrument_value = 0  -- Self-reference
      line.note_columns[1].volume_value = 128  -- Full volume
      
      phrases_created[slice_index] = phrase_index
      print(string.format("SlicePro Phrases: Slice %d = %.2f beats, %d lines @ LPB %d", 
        slice_index, beats, phrase_lines, phrase_lpb))
    end
  end
  
  -- Create a PhraseGrid bank if available
  if PakettiPhraseBankCreate then
    local stem_name = instrument.name or "SlicePro"
    local bank_index = PakettiPhraseBankCreate(song.selected_instrument_index, "SlicePro: " .. stem_name)
    
    if bank_index and PakettiPhraseBanks and PakettiPhraseBanks[bank_index] then
      local max_slots = math.min(slice_count, 8)
      for slot = 1, max_slots do
        if phrases_created[slot] then
          PakettiPhraseBankSetSlot(bank_index, slot, phrases_created[slot])
        end
      end
      print("SlicePro Phrases: Created PhraseGrid bank " .. bank_index)
    end
  end
  
  -- Store analysis in PhraseGrid state if available
  if PakettiPhraseGridStates and PakettiPhraseGridCurrentState then
    local state_index = PakettiPhraseGridCurrentState > 0 and PakettiPhraseGridCurrentState or 1
    if not PakettiPhraseGridStates[state_index] then
      if PakettiPhraseGridCreateEmptyState then
        PakettiPhraseGridStates[state_index] = PakettiPhraseGridCreateEmptyState()
      end
    end
    if PakettiPhraseGridStates[state_index] then
      PakettiPhraseGridStates[state_index].slicepro = {
        total_beats = SliceProState.total_beats,
        slice_beats = SliceProState.slice_beats,
        confidence = SliceProState.confidence,
        method = SliceProState.method
      }
      print("SlicePro Phrases: Stored analysis in PhraseGrid state " .. state_index)
    end
  end
  
  renoise.app():show_status(string.format("Created %d beat-synced phrases (%.1f total beats, %s confidence)", 
    slice_count, SliceProState.total_beats or 0, 
    SliceProState.confidence and string.format("%.0f%%", SliceProState.confidence * 100) or "N/A"))
  
  return phrases_created
end

-- Create phrases with uniform length based on total beats
function PakettiSliceProCreateUniformPhrases()
  local song = renoise.song()
  if not song then return end
  
  if not SliceProState.total_beats then
    renoise.app():show_status("SlicePro: No beat analysis available. Run SlicePro Apply first.")
    return
  end
  
  local instrument = song.selected_instrument
  if not instrument or not instrument.samples[1] then
    renoise.app():show_status("SlicePro: No sample in instrument")
    return
  end
  
  local sample = instrument.samples[1]
  local slice_count = #sample.slice_markers
  if slice_count == 0 then
    renoise.app():show_status("SlicePro: No slices in sample")
    return
  end
  
  -- Calculate uniform beat length per slice
  local beats_per_slice = SliceProState.total_beats / slice_count
  local phrase_lpb = song.transport.lpb
  local phrase_lines = math.max(1, math.floor(beats_per_slice * phrase_lpb + 0.5))
  
  local base_note = 48
  if sample.sample_mapping then
    base_note = sample.sample_mapping.base_note
  end
  
  local phrases_created = {}
  
  for slice_index = 1, slice_count do
    local phrase_index = #instrument.phrases + 1
    instrument:insert_phrase_at(phrase_index)
    local phrase = instrument.phrases[phrase_index]
    
    if phrase then
      phrase.name = string.format("Slice %02d (uniform)", slice_index)
      phrase.number_of_lines = phrase_lines
      phrase.lpb = phrase_lpb
      phrase.is_empty = false
      phrase.autoseek = false
      phrase.loop_start = 1
      phrase.loop_end = phrase_lines
      phrase.looping = true
      
      if phrase.visible_note_columns < 1 then
        phrase.visible_note_columns = 1
      end
      
      local slice_note = base_note + slice_index
      if slice_note > 119 then slice_note = 119 end
      
      local line = phrase:line(1)
      line.note_columns[1].note_value = slice_note
      line.note_columns[1].instrument_value = 0
      line.note_columns[1].volume_value = 128
      
      phrases_created[slice_index] = phrase_index
    end
  end
  
  renoise.app():show_status(string.format("Created %d uniform phrases (%.2f beats each, %d lines @ LPB %d)", 
    slice_count, beats_per_slice, phrase_lines, phrase_lpb))
  
  return phrases_created
end

-- Keybindings for phrase creation
renoise.tool():add_keybinding{
  name = "Sample Editor:Paketti:SlicePro Create Beat-Synced Phrases",
  invoke = PakettiSliceProCreateBeatsyncedPhrases
}

renoise.tool():add_keybinding{
  name = "Sample Editor:Paketti:SlicePro Create Uniform Phrases",
  invoke = PakettiSliceProCreateUniformPhrases
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:SlicePro Create Beat-Synced Phrases",
  invoke = PakettiSliceProCreateBeatsyncedPhrases
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:SlicePro Create Uniform Phrases",
  invoke = PakettiSliceProCreateUniformPhrases
}

-- MIDI Mappings
renoise.tool():add_midi_mapping{
  name = "Paketti:SlicePro Create Beat-Synced Phrases",
  invoke = function(message)
    if message:is_trigger() then
      PakettiSliceProCreateBeatsyncedPhrases()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:SlicePro Create Uniform Phrases",
  invoke = function(message)
    if message:is_trigger() then
      PakettiSliceProCreateUniformPhrases()
    end
  end
}

-- Menu entries
renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti..:SlicePro:Create Beat-Synced Phrases",
  invoke = PakettiSliceProCreateBeatsyncedPhrases
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti..:SlicePro:Create Uniform Phrases",
  invoke = PakettiSliceProCreateUniformPhrases
}

print("PakettiSlicePro.lua loaded (v3 - with overrides, fallback, progress, phrase integration)")



