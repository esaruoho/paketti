-- PakettiGlider.lua
-- Quantized Legato Engine for Paketti
-- Dynamically calculates Gxx glide values to complete pitch movement in a fixed musical time
-- Lua 5.1, global functions only, namespaced per project rules

--------------------------------------------------------------------------------
-- GLOBAL STATE VARIABLES
--------------------------------------------------------------------------------

-- Master enable state
PakettiGliderEnabled = false

-- Settings (will be loaded from preferences on startup)
PakettiGliderDuration = 4           -- Glide duration in lines
PakettiGliderMode = "live"          -- "live" (immediate) or "noteoff" (retroactive)
PakettiGliderMinInterval = 1        -- Minimum semitone difference to trigger glide
PakettiGliderLegatoOnly = true      -- Only glide when notes overlap
PakettiGliderWriteMultiLine = true  -- Write Gxx on every line (spec compliant)
PakettiGliderScaleFactor = 16       -- Base scale factor for Gxx calculation
PakettiGliderDebug = false          -- Debug logging toggle

-- MIDI state
PakettiGlider_midi_device = nil
PakettiGlider_midi_listening = false
PakettiGlider_SelectedMidiDeviceName = ""

-- Note tracking state
PakettiGlider_previous_note = nil       -- {note_value, instrument, line_index, track_index, time}
PakettiGlider_current_note = nil        -- Same structure
PakettiGlider_active_notes = {}         -- Table of currently held notes
PakettiGlider_note_start_times = {}     -- For note-off mode: note_value -> start_time

-- Dialog state
PakettiGlider_dialog = nil
PakettiGlider_vb = nil

-- Song notifier state
PakettiGlider_song_notifier_installed = false

--------------------------------------------------------------------------------
-- PREFERENCES LOADING/SAVING
--------------------------------------------------------------------------------

-- Load settings from preferences
function PakettiGliderLoadPreferences()
  if not preferences then
    print("PakettiGlider: preferences not available yet")
    return false
  end
  
  -- Load each preference with safety checks
  if preferences.pakettiGliderEnabled ~= nil then
    PakettiGliderEnabled = preferences.pakettiGliderEnabled.value
  end
  if preferences.pakettiGliderDuration ~= nil then
    PakettiGliderDuration = preferences.pakettiGliderDuration.value
  end
  if preferences.pakettiGliderMode ~= nil then
    PakettiGliderMode = preferences.pakettiGliderMode.value
  end
  if preferences.pakettiGliderMinInterval ~= nil then
    PakettiGliderMinInterval = preferences.pakettiGliderMinInterval.value
  end
  if preferences.pakettiGliderLegatoOnly ~= nil then
    PakettiGliderLegatoOnly = preferences.pakettiGliderLegatoOnly.value
  end
  if preferences.pakettiGliderMultiLine ~= nil then
    PakettiGliderWriteMultiLine = preferences.pakettiGliderMultiLine.value
  end
  if preferences.pakettiGliderMidiDevice ~= nil then
    PakettiGlider_SelectedMidiDeviceName = preferences.pakettiGliderMidiDevice.value
  end
  if preferences.pakettiGliderScaleFactor ~= nil then
    PakettiGliderScaleFactor = preferences.pakettiGliderScaleFactor.value
  end
  if preferences.pakettiGliderDebug ~= nil then
    PakettiGliderDebug = preferences.pakettiGliderDebug.value
  end
  
  if PakettiGliderDebug then
    print("PakettiGlider: Loaded preferences - Enabled=" .. tostring(PakettiGliderEnabled) ..
          ", Duration=" .. tostring(PakettiGliderDuration) ..
          ", Mode=" .. PakettiGliderMode ..
          ", MinInterval=" .. tostring(PakettiGliderMinInterval))
  end
  
  return true
end

-- Save settings to preferences
function PakettiGliderSavePreferences()
  if not preferences then
    print("PakettiGlider: preferences not available for saving")
    return false
  end
  
  -- Save each setting with safety checks
  if preferences.pakettiGliderEnabled ~= nil then
    preferences.pakettiGliderEnabled.value = PakettiGliderEnabled
  end
  if preferences.pakettiGliderDuration ~= nil then
    preferences.pakettiGliderDuration.value = PakettiGliderDuration
  end
  if preferences.pakettiGliderMode ~= nil then
    preferences.pakettiGliderMode.value = PakettiGliderMode
  end
  if preferences.pakettiGliderMinInterval ~= nil then
    preferences.pakettiGliderMinInterval.value = PakettiGliderMinInterval
  end
  if preferences.pakettiGliderLegatoOnly ~= nil then
    preferences.pakettiGliderLegatoOnly.value = PakettiGliderLegatoOnly
  end
  if preferences.pakettiGliderMultiLine ~= nil then
    preferences.pakettiGliderMultiLine.value = PakettiGliderWriteMultiLine
  end
  if preferences.pakettiGliderMidiDevice ~= nil then
    preferences.pakettiGliderMidiDevice.value = PakettiGlider_SelectedMidiDeviceName
  end
  if preferences.pakettiGliderScaleFactor ~= nil then
    preferences.pakettiGliderScaleFactor.value = PakettiGliderScaleFactor
  end
  if preferences.pakettiGliderDebug ~= nil then
    preferences.pakettiGliderDebug.value = PakettiGliderDebug
  end
  
  -- Save to file
  preferences:save_as("preferences.xml")
  
  if PakettiGliderDebug then
    print("PakettiGlider: Saved preferences to file")
  end
  
  return true
end

--------------------------------------------------------------------------------
-- DEBUG LOGGING
--------------------------------------------------------------------------------

-- Conditional debug print
function PakettiGliderDebugPrint(msg)
  if PakettiGliderDebug then
    print("PakettiGlider DEBUG: " .. tostring(msg))
  end
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

-- Clamp a value between min and max
function PakettiGliderClamp(value, min_val, max_val)
  if value < min_val then return min_val end
  if value > max_val then return max_val end
  return value
end

-- Convert MIDI note value (0-119) to note string (C-0 to B-9)
function PakettiGliderNoteValueToString(value)
  local names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
  local v = PakettiGliderClamp(value, 0, 119)
  local octave = math.floor(v / 12)
  local name = names[(v % 12) + 1]
  return name .. tostring(octave)
end

--------------------------------------------------------------------------------
-- GXX CALCULATION (BPM/LPB-AWARE)
--------------------------------------------------------------------------------

-- Calculate the Gxx value needed to glide a given pitch distance in a given number of lines
-- BPM/LPB-aware: adjusts the scale factor based on current tempo
-- Parameters:
--   semitone_distance: absolute pitch difference in semitones
--   duration_lines: number of lines to complete the glide
-- Returns: Gxx value (1-255), or nil if no glide needed
function PakettiGliderCalculateGxx(semitone_distance, duration_lines)
  if semitone_distance < PakettiGliderMinInterval then
    PakettiGliderDebugPrint("Interval " .. tostring(semitone_distance) .. 
                           " below threshold " .. tostring(PakettiGliderMinInterval))
    return nil  -- No glide for small intervals
  end
  
  if duration_lines < 1 then
    duration_lines = 1
  end
  
  local song = renoise.song()
  if not song then
    PakettiGliderDebugPrint("No song available for Gxx calculation")
    return nil
  end
  
  local bpm = song.transport.bpm
  local lpb = song.transport.lpb
  
  -- BPM/LPB-aware Gxx calculation:
  -- Base timing: at 120 BPM, 4 LPB, the base scale_factor works well
  -- Adjust for current tempo: faster tempo = faster glide needed
  -- tempo_factor scales the Gxx value based on how fast the song is playing
  local tempo_factor = (bpm / 120) * (lpb / 4)
  local adjusted_scale = PakettiGliderScaleFactor * tempo_factor
  
  -- Calculate Gxx value
  -- Formula: gxx = (semitone_distance * adjusted_scale) / duration_lines
  local gxx_value = math.floor((semitone_distance * adjusted_scale) / duration_lines)
  
  -- Clamp to valid range (01-FF)
  gxx_value = PakettiGliderClamp(gxx_value, 1, 255)
  
  PakettiGliderDebugPrint(string.format(
    "Calculated Gxx=%02X for %d semitones in %d lines (BPM=%d, LPB=%d, scale=%.2f)",
    gxx_value, semitone_distance, duration_lines, bpm, lpb, adjusted_scale))
  
  return gxx_value
end

-- Calculate Gxx for the final line (GFF for convergence)
function PakettiGliderGetConvergenceGxx()
  return 255  -- GFF forces pitch to destination
end

-- Get a preview of what Gxx value would be calculated for given parameters
-- Useful for the dialog "Test Glide" feature
function PakettiGliderPreviewGxx(semitone_distance, duration_lines)
  if semitone_distance < 1 then return "N/A" end
  if duration_lines < 1 then duration_lines = 1 end
  
  local song = renoise.song()
  if not song then return "N/A" end
  
  local bpm = song.transport.bpm
  local lpb = song.transport.lpb
  local tempo_factor = (bpm / 120) * (lpb / 4)
  local adjusted_scale = PakettiGliderScaleFactor * tempo_factor
  local gxx_value = math.floor((semitone_distance * adjusted_scale) / duration_lines)
  gxx_value = PakettiGliderClamp(gxx_value, 1, 255)
  
  return string.format("0G%02X", gxx_value)
end

--------------------------------------------------------------------------------
-- EDITOR CONTEXT DETECTION
--------------------------------------------------------------------------------

-- Check if we're currently in the phrase editor
function PakettiGliderIsPhraseEditorActive()
  local window = renoise.app().window
  return window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
end

-- Get the current selected phrase, if any
function PakettiGliderGetSelectedPhrase()
  local song = renoise.song()
  if not song then return nil end
  
  local instrument = song.selected_instrument
  if not instrument then return nil end
  
  local phrase_index = song.selected_phrase_index
  if phrase_index == 0 or phrase_index > #instrument.phrases then
    return nil
  end
  
  return instrument.phrases[phrase_index]
end

--------------------------------------------------------------------------------
-- PHRASE EDITOR WRITING
--------------------------------------------------------------------------------

-- Write Gxx effect to a specific line in the phrase editor
-- Parameters:
--   line_index: 1-based line number
--   gxx_value: value to write (1-255)
--   phrase: the phrase to write to (optional, defaults to selected)
function PakettiGliderWriteGxxToPhraseLine(line_index, gxx_value, phrase)
  local song = renoise.song()
  if not song then return false end
  
  phrase = phrase or PakettiGliderGetSelectedPhrase()
  if not phrase then
    print("PakettiGlider: No phrase selected for writing")
    return false
  end
  
  -- Ensure effect column is visible in phrase
  if phrase.visible_effect_columns < 1 then
    phrase.visible_effect_columns = 1
  end
  
  -- Check line bounds
  if line_index < 1 or line_index > phrase.number_of_lines then
    print("PakettiGlider: Phrase line " .. tostring(line_index) .. " out of bounds")
    return false
  end
  
  local line = phrase:line(line_index)
  if not line then return false end
  
  local effect_column = line:effect_column(1)
  if not effect_column then return false end
  
  effect_column.number_string = "0G"
  effect_column.amount_value = gxx_value
  
  print("PakettiGlider: Wrote 0G" .. string.format("%02X", gxx_value) .. 
        " to phrase line " .. tostring(line_index))
  
  return true
end

-- Write multi-line Gxx sequence to phrase according to spec
-- Parameters:
--   start_line: line where the new note is
--   duration_lines: how many lines to write Gxx commands
--   gxx_value: calculated Gxx value for the glide
--   phrase: optional phrase to write to
function PakettiGliderWriteGxxSequenceToPhrase(start_line, duration_lines, gxx_value, phrase)
  local song = renoise.song()
  if not song then return false end
  
  phrase = phrase or PakettiGliderGetSelectedPhrase()
  if not phrase then return false end
  
  local max_line = phrase.number_of_lines
  
  if not PakettiGliderWriteMultiLine then
    -- Single line mode: just write one Gxx on the note line
    return PakettiGliderWriteGxxToPhraseLine(start_line, gxx_value, phrase)
  end
  
  -- Multi-line mode (spec compliant):
  -- Lines 1 to (T-1): calculated Gxx value
  -- Line T: GFF (convergence)
  
  local lines_written = 0
  for i = 0, duration_lines - 1 do
    local target_line = start_line + i
    if target_line > max_line then
      -- Wrap around to phrase start
      target_line = target_line - max_line
    end
    
    local value_to_write
    if i == duration_lines - 1 then
      -- Final line: use GFF for convergence
      value_to_write = PakettiGliderGetConvergenceGxx()
    else
      -- Normal lines: use calculated Gxx
      value_to_write = gxx_value
    end
    
    if PakettiGliderWriteGxxToPhraseLine(target_line, value_to_write, phrase) then
      lines_written = lines_written + 1
    end
  end
  
  print("PakettiGlider: Wrote Gxx sequence of " .. tostring(lines_written) .. " lines to phrase")
  return lines_written > 0
end

--------------------------------------------------------------------------------
-- PATTERN EDITOR WRITING
--------------------------------------------------------------------------------

-- Write Gxx effect to a specific line in the pattern editor
-- Parameters:
--   line_index: 1-based line number
--   gxx_value: value to write (1-255)
--   track_index: track to write to (optional, defaults to selected)
function PakettiGliderWriteGxxToLine(line_index, gxx_value, track_index)
  local song = renoise.song()
  if not song then return false end
  
  track_index = track_index or song.selected_track_index
  local track = song:track(track_index)
  
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    print("PakettiGlider: Cannot write to non-sequencer track")
    return false
  end
  
  -- Ensure effect column is visible
  if track.visible_effect_columns < 1 then
    track.visible_effect_columns = 1
  end
  
  local pattern = song:pattern(song.selected_pattern_index)
  if not pattern then return false end
  
  local pattern_track = pattern:track(track_index)
  if not pattern_track then return false end
  
  -- Check line bounds
  if line_index < 1 or line_index > pattern.number_of_lines then
    print("PakettiGlider: Line " .. tostring(line_index) .. " out of bounds")
    return false
  end
  
  local line = pattern_track:line(line_index)
  if not line then return false end
  
  local effect_column = line:effect_column(1)
  if not effect_column then return false end
  
  effect_column.number_string = "0G"
  effect_column.amount_value = gxx_value
  
  print("PakettiGlider: Wrote 0G" .. string.format("%02X", gxx_value) .. 
        " to track " .. tostring(track_index) .. ", line " .. tostring(line_index))
  
  return true
end

-- Write multi-line Gxx sequence according to spec
-- Parameters:
--   start_line: line where the new note is
--   duration_lines: how many lines to write Gxx commands
--   gxx_value: calculated Gxx value for the glide
--   track_index: optional track index
function PakettiGliderWriteGxxSequence(start_line, duration_lines, gxx_value, track_index)
  local song = renoise.song()
  if not song then return false end
  
  local pattern = song:pattern(song.selected_pattern_index)
  if not pattern then return false end
  
  local max_line = pattern.number_of_lines
  
  if not PakettiGliderWriteMultiLine then
    -- Single line mode: just write one Gxx on the note line
    return PakettiGliderWriteGxxToLine(start_line, gxx_value, track_index)
  end
  
  -- Multi-line mode (spec compliant):
  -- Lines 1 to (T-1): calculated Gxx value
  -- Line T: GFF (convergence)
  -- After T: nothing or G00
  
  local lines_written = 0
  for i = 0, duration_lines - 1 do
    local target_line = start_line + i
    if target_line > max_line then
      -- Wrap around to pattern start
      target_line = target_line - max_line
    end
    
    local value_to_write
    if i == duration_lines - 1 then
      -- Final line: use GFF for convergence
      value_to_write = PakettiGliderGetConvergenceGxx()
    else
      -- Normal lines: use calculated Gxx
      value_to_write = gxx_value
    end
    
    if PakettiGliderWriteGxxToLine(target_line, value_to_write, track_index) then
      lines_written = lines_written + 1
    end
  end
  
  print("PakettiGlider: Wrote Gxx sequence of " .. tostring(lines_written) .. " lines")
  return lines_written > 0
end

--------------------------------------------------------------------------------
-- UNIFIED WRITE FUNCTION (Pattern or Phrase)
--------------------------------------------------------------------------------

-- Write Gxx sequence to either pattern or phrase editor based on current context
-- Parameters:
--   start_line: line where the new note is
--   duration_lines: how many lines to write Gxx commands
--   gxx_value: calculated Gxx value for the glide
--   track_index: optional track index (for pattern editor)
function PakettiGliderWriteGxxAuto(start_line, duration_lines, gxx_value, track_index)
  if PakettiGliderIsPhraseEditorActive() then
    local phrase = PakettiGliderGetSelectedPhrase()
    if phrase then
      return PakettiGliderWriteGxxSequenceToPhrase(start_line, duration_lines, gxx_value, phrase)
    else
      print("PakettiGlider: Phrase editor active but no phrase selected, falling back to pattern")
    end
  end
  
  return PakettiGliderWriteGxxSequence(start_line, duration_lines, gxx_value, track_index)
end

--------------------------------------------------------------------------------
-- NOTE TRACKING AND GLIDE PROCESSING
--------------------------------------------------------------------------------

-- Process a new note and determine if glide should be applied
-- Parameters:
--   note_value: MIDI note value (0-119)
--   instrument_index: instrument index (1-based)
--   velocity: note velocity (optional)
--   line_index: pattern line where note is (optional, defaults to selected)
--   track_index: track where note is (optional, defaults to selected)
function PakettiGliderProcessNoteOn(note_value, instrument_index, velocity, line_index, track_index)
  if not PakettiGliderEnabled then return end
  
  local song = renoise.song()
  if not song then return end
  
  -- CRITICAL: Only write Gxx when Edit Mode is ON (actual recording)
  if not song.transport.edit_mode then
    PakettiGliderDebugPrint("Edit Mode is OFF - not writing Gxx")
    -- Still track the note for when edit mode is enabled
    PakettiGlider_previous_note = {
      note_value = note_value,
      instrument = instrument_index or song.selected_instrument_index,
      line_index = song.selected_line_index,
      track_index = song.selected_track_index,
      time = os.clock()
    }
    PakettiGlider_active_notes[note_value] = PakettiGlider_previous_note
    return
  end
  
  -- Determine line index based on active editor
  local is_phrase_mode = PakettiGliderIsPhraseEditorActive()
  if line_index == nil then
    if is_phrase_mode and renoise.API_VERSION >= 6.2 then
      line_index = song.selected_phrase_line_index or 1
    else
      line_index = song.selected_line_index
    end
  end
  
  track_index = track_index or song.selected_track_index
  velocity = velocity or 127
  
  local current_time = os.clock()
  
  local editor_str = is_phrase_mode and "Phrase" or "Pattern"
  print("PakettiGlider: Note ON (" .. editor_str .. ") - " .. PakettiGliderNoteValueToString(note_value) .. 
        " (value=" .. tostring(note_value) .. ") at line " .. tostring(line_index))
  
  -- Store note start time for note-off mode
  PakettiGlider_note_start_times[note_value] = {
    time = current_time,
    line = line_index,
    track = track_index
  }
  
  -- Check if we have a previous note to glide from
  if PakettiGlider_previous_note then
    local prev_note = PakettiGlider_previous_note.note_value
    local prev_line = PakettiGlider_previous_note.line_index
    
    -- Calculate semitone distance
    local semitone_distance = math.abs(note_value - prev_note)
    
    -- Check minimum interval threshold
    if semitone_distance >= PakettiGliderMinInterval then
      -- Check legato condition if enabled
      local should_glide = true
      if PakettiGliderLegatoOnly then
        -- Check if previous note is still active (overlapping)
        if not PakettiGlider_active_notes[prev_note] then
          should_glide = false
          print("PakettiGlider: Legato mode - previous note not held, skipping glide")
        end
      end
      
      if should_glide then
        -- Calculate and write Gxx
        local gxx_value = PakettiGliderCalculateGxx(semitone_distance, PakettiGliderDuration)
        
        if gxx_value then
          if PakettiGliderMode == "live" then
            -- Live mode: write immediately (auto-detects pattern vs phrase editor)
            PakettiGliderWriteGxxAuto(line_index, PakettiGliderDuration, gxx_value, track_index)
            local editor_mode = PakettiGliderIsPhraseEditorActive() and "Phrase" or "Pattern"
            renoise.app():show_status("PakettiGlider (" .. editor_mode .. "): " .. PakettiGliderNoteValueToString(prev_note) .. 
                                       " -> " .. PakettiGliderNoteValueToString(note_value) .. 
                                       " = 0G" .. string.format("%02X", gxx_value))
          else
            -- Note-off mode: store for later calculation
            PakettiGlider_current_note = {
              note_value = note_value,
              instrument = instrument_index,
              line_index = line_index,
              track_index = track_index,
              time = current_time,
              prev_note = prev_note,
              semitone_distance = semitone_distance
            }
          end
        end
      end
    else
      print("PakettiGlider: Interval " .. tostring(semitone_distance) .. 
            " below threshold " .. tostring(PakettiGliderMinInterval))
    end
  end
  
  -- Update tracking state
  PakettiGlider_active_notes[note_value] = {
    instrument = instrument_index,
    line_index = line_index,
    track_index = track_index,
    time = current_time
  }
  
  PakettiGlider_previous_note = {
    note_value = note_value,
    instrument = instrument_index,
    line_index = line_index,
    track_index = track_index,
    time = current_time
  }
end

-- Process note off event
-- Parameters:
--   note_value: MIDI note value (0-119)
function PakettiGliderProcessNoteOff(note_value)
  if not PakettiGliderEnabled then return end
  
  print("PakettiGlider: Note OFF - " .. PakettiGliderNoteValueToString(note_value))
  
  -- Handle note-off mode retroactive calculation
  if PakettiGliderMode == "noteoff" and PakettiGlider_current_note then
    if PakettiGlider_current_note.note_value == note_value then
      local start_info = PakettiGlider_note_start_times[note_value]
      if start_info then
        local song = renoise.song()
        if song then
          -- Get current line based on active editor
          local is_phrase_mode = PakettiGliderIsPhraseEditorActive()
          local current_line
          local max_lines
          
          if is_phrase_mode and renoise.API_VERSION >= 6.2 then
            current_line = song.selected_phrase_line_index or 1
            local phrase = PakettiGliderGetSelectedPhrase()
            max_lines = phrase and phrase.number_of_lines or 64
          else
            current_line = song.selected_line_index
            local pattern = song:pattern(song.selected_pattern_index)
            max_lines = pattern and pattern.number_of_lines or 64
          end
          
          local duration_lines = current_line - start_info.line
          
          if duration_lines <= 0 then
            -- Wrapped around
            duration_lines = duration_lines + max_lines
          end
          
          -- Recalculate Gxx based on actual note duration
          local gxx_value = PakettiGliderCalculateGxx(
            PakettiGlider_current_note.semitone_distance, 
            duration_lines
          )
          
          if gxx_value then
            -- Use auto-detect for pattern vs phrase editor
            PakettiGliderWriteGxxAuto(
              start_info.line, 
              duration_lines, 
              gxx_value, 
              start_info.track
            )
            local editor_mode = PakettiGliderIsPhraseEditorActive() and "Phrase" or "Pattern"
            renoise.app():show_status("PakettiGlider (Note-Off, " .. editor_mode .. "): Gxx=" .. 
                                       string.format("%02X", gxx_value) .. 
                                       " over " .. tostring(duration_lines) .. " lines")
          end
        end
      end
      PakettiGlider_current_note = nil
    end
  end
  
  -- Remove from active notes
  PakettiGlider_active_notes[note_value] = nil
  PakettiGlider_note_start_times[note_value] = nil
end

-- Clear all tracking state
function PakettiGliderClearState()
  PakettiGlider_previous_note = nil
  PakettiGlider_current_note = nil
  PakettiGlider_active_notes = {}
  PakettiGlider_note_start_times = {}
  print("PakettiGlider: State cleared")
end

--------------------------------------------------------------------------------
-- MIDI INPUT HANDLING
--------------------------------------------------------------------------------

-- Safe wrapper for pcall-based error handling
function PakettiGliderSafeCall(func, ...)
  local success, result = pcall(func, ...)
  if not success then
    print("PakettiGlider ERROR: " .. tostring(result))
    return nil, result
  end
  return result
end

-- MIDI callback function with error handling
function PakettiGlider_MidiCallback(message)
  -- Wrap entire callback in pcall for safety
  local success, err = pcall(function()
    if not message or #message ~= 3 then return end
    if not PakettiGliderEnabled then return end
    
    local status = message[1]
    local data1 = message[2]
    local data2 = message[3]
    
    -- Validate message bytes
    if type(status) ~= "number" or type(data1) ~= "number" then
      PakettiGliderDebugPrint("Invalid MIDI message bytes")
      return
    end
    
    -- Note ON (status & 0xF0 == 0x90 and velocity > 0)
    if (bit.band(status, 0xF0) == 0x90) and (data2 and data2 > 0) then
      local note_value = PakettiGliderClamp(tonumber(data1) or 0, 0, 119)
      local velocity = PakettiGliderClamp(tonumber(data2) or 127, 0, 127)
      
      local song = renoise.song()
      if not song then
        PakettiGliderDebugPrint("No song available in MIDI callback")
        return
      end
      
      local instrument_index = song.selected_instrument_index or 1
      
      PakettiGliderProcessNoteOn(note_value, instrument_index, velocity)
      
    -- Note OFF (status & 0xF0 == 0x80 OR status & 0xF0 == 0x90 with velocity 0)
    elseif (bit.band(status, 0xF0) == 0x80) or ((bit.band(status, 0xF0) == 0x90) and (data2 == 0)) then
      local note_value = PakettiGliderClamp(tonumber(data1) or 0, 0, 119)
      PakettiGliderProcessNoteOff(note_value)
    end
  end)
  
  if not success then
    print("PakettiGlider MIDI callback error: " .. tostring(err))
  end
end

-- Start MIDI listening with error handling
function PakettiGliderStartMidiListening()
  if PakettiGlider_midi_listening then 
    PakettiGliderDebugPrint("Already listening to MIDI")
    return true
  end
  
  local inputs = renoise.Midi.available_input_devices()
  if not inputs or #inputs == 0 then
    renoise.app():show_status("PakettiGlider: No MIDI input devices available")
    return false
  end
  
  local device_name = PakettiGlider_SelectedMidiDeviceName
  if not device_name or device_name == "" then
    device_name = inputs[1]
  end
  
  -- Check if device exists in available inputs
  local device_exists = false
  for _, name in ipairs(inputs) do
    if name == device_name then
      device_exists = true
      break
    end
  end
  
  if not device_exists then
    PakettiGliderDebugPrint("Device '" .. tostring(device_name) .. "' not found, using first available")
    device_name = inputs[1]
    PakettiGlider_SelectedMidiDeviceName = device_name
  end
  
  -- Try to create MIDI device with error handling
  local success, result = pcall(function()
    return renoise.Midi.create_input_device(device_name, PakettiGlider_MidiCallback)
  end)
  
  if not success then
    print("PakettiGlider: Failed to create MIDI device: " .. tostring(result))
    renoise.app():show_status("PakettiGlider: Failed to open MIDI device")
    return false
  end
  
  PakettiGlider_midi_device = result
  PakettiGlider_midi_listening = true
  
  print("PakettiGlider: Started MIDI listening on " .. tostring(device_name))
  renoise.app():show_status("PakettiGlider: Listening to MIDI on " .. tostring(device_name))
  
  return true
end

-- Stop MIDI listening
function PakettiGliderStopMidiListening()
  if PakettiGlider_midi_device then
    PakettiGlider_midi_device:close()
    PakettiGlider_midi_device = nil
  end
  
  PakettiGlider_midi_listening = false
  PakettiGliderClearState()
  
  print("PakettiGlider: Stopped MIDI listening")
  renoise.app():show_status("PakettiGlider: MIDI listening stopped")
end

--------------------------------------------------------------------------------
-- ENABLE/DISABLE FUNCTIONS
--------------------------------------------------------------------------------

-- Enable Glider
function PakettiGliderEnable()
  if PakettiGliderEnabled then return end
  
  PakettiGliderEnabled = true
  PakettiGliderClearState()
  
  if PakettiGlider_SelectedMidiDeviceName and PakettiGlider_SelectedMidiDeviceName ~= "" then
    PakettiGliderStartMidiListening()
  end
  
  print("PakettiGlider: Enabled")
  renoise.app():show_status("PakettiGlider: Enabled (Duration=" .. tostring(PakettiGliderDuration) .. " lines)")
end

-- Disable Glider
function PakettiGliderDisable()
  if not PakettiGliderEnabled then return end
  
  PakettiGliderEnabled = false
  PakettiGliderStopMidiListening()
  PakettiGliderClearState()
  
  print("PakettiGlider: Disabled")
  renoise.app():show_status("PakettiGlider: Disabled")
end

-- Toggle Glider
function PakettiGliderToggle()
  if PakettiGliderEnabled then
    PakettiGliderDisable()
  else
    PakettiGliderEnable()
  end
end

--------------------------------------------------------------------------------
-- DIALOG
--------------------------------------------------------------------------------

-- Dialog key handler that saves preferences on close
function PakettiGliderKeyHandler(dialog, key)
  local closer = preferences and preferences.pakettiDialogClose and preferences.pakettiDialogClose.value or "esc"
  if key.modifiers == "" and key.name == closer then
    -- Save preferences before closing
    PakettiGliderSavePreferences()
    dialog:close()
    PakettiGlider_dialog = nil
    return nil
  end
  return key
end

-- Update the Gxx preview text based on current settings
function PakettiGliderUpdatePreview()
  if PakettiGlider_vb and PakettiGlider_vb.views.gxx_preview then
    -- Preview for 12 semitones (octave) at current duration
    local preview = PakettiGliderPreviewGxx(12, PakettiGliderDuration)
    PakettiGlider_vb.views.gxx_preview.text = "12 semitones -> " .. preview
  end
end

function PakettiGliderShowDialog()
  if PakettiGlider_dialog and PakettiGlider_dialog.visible then
    -- Save preferences when closing via toggle
    PakettiGliderSavePreferences()
    PakettiGlider_dialog:close()
    PakettiGlider_dialog = nil
    return
  end
  
  -- Load latest preferences before showing dialog
  PakettiGliderLoadPreferences()
  
  PakettiGlider_vb = renoise.ViewBuilder()
  local vb = PakettiGlider_vb
  
  -- Get available MIDI devices
  local midi_devices = renoise.Midi.available_input_devices()
  if #midi_devices == 0 then
    midi_devices = {"No MIDI devices"}
  end
  
  -- Find current device index
  local current_device_index = 1
  for i, name in ipairs(midi_devices) do
    if name == PakettiGlider_SelectedMidiDeviceName then
      current_device_index = i
      break
    end
  end
  
  -- Get current song info for status display
  local song = renoise.song()
  local bpm_text = song and tostring(song.transport.bpm) or "N/A"
  local lpb_text = song and tostring(song.transport.lpb) or "N/A"
  
  local dialog_content = vb:column{
    margin = 10,
    spacing = 6,
    
    -- Enable toggle
    vb:row{
      vb:checkbox{
        id = "glider_enabled",
        value = PakettiGliderEnabled,
        notifier = function(value)
          if value then
            PakettiGliderEnable()
          else
            PakettiGliderDisable()
          end
        end
      },
      vb:text{text = "Enable Glider"},
      vb:space{width = 20},
      vb:text{text = "BPM: " .. bpm_text .. " | LPB: " .. lpb_text, style = "disabled"}
    },
    
    vb:space{height = 6},
    
    -- MIDI Device selection
    vb:row{
      vb:text{text = "MIDI Device:", width = 100},
      vb:popup{
        id = "midi_device",
        items = midi_devices,
        value = current_device_index,
        width = 200,
        notifier = function(index)
          local device_name = midi_devices[index]
          if device_name and device_name ~= "No MIDI devices" then
            PakettiGlider_SelectedMidiDeviceName = device_name
            if PakettiGliderEnabled and PakettiGlider_midi_listening then
              PakettiGliderStopMidiListening()
              PakettiGliderStartMidiListening()
            end
          end
        end
      }
    },
    
    vb:space{height = 6},
    
    -- Glide Duration
    vb:row{
      vb:text{text = "Glide Duration:", width = 100},
      vb:valuebox{
        id = "glide_duration",
        min = 1,
        max = 64,
        value = PakettiGliderDuration,
        width = 60,
        notifier = function(value)
          PakettiGliderDuration = value
          PakettiGliderDebugPrint("Duration set to " .. tostring(value) .. " lines")
          PakettiGliderUpdatePreview()
        end
      },
      vb:text{text = "lines"}
    },
    
    -- Minimum Interval
    vb:row{
      vb:text{text = "Min Interval:", width = 100},
      vb:valuebox{
        id = "min_interval",
        min = 1,
        max = 24,
        value = PakettiGliderMinInterval,
        width = 60,
        notifier = function(value)
          PakettiGliderMinInterval = value
          PakettiGliderDebugPrint("Min interval set to " .. tostring(value) .. " semitones")
        end
      },
      vb:text{text = "semitones"}
    },
    
    -- Scale Factor (advanced)
    vb:row{
      vb:text{text = "Scale Factor:", width = 100},
      vb:valuebox{
        id = "scale_factor",
        min = 1,
        max = 64,
        value = PakettiGliderScaleFactor,
        width = 60,
        notifier = function(value)
          PakettiGliderScaleFactor = value
          PakettiGliderDebugPrint("Scale factor set to " .. tostring(value))
          PakettiGliderUpdatePreview()
        end
      },
      vb:text{text = "(adjust if glides feel wrong)"}
    },
    
    vb:space{height = 6},
    
    -- Mode selection
    vb:row{
      vb:text{text = "Mode:", width = 100},
      vb:switch{
        id = "glide_mode",
        items = {"Live", "Note-Off"},
        value = PakettiGliderMode == "live" and 1 or 2,
        width = 150,
        notifier = function(index)
          PakettiGliderMode = index == 1 and "live" or "noteoff"
          PakettiGliderDebugPrint("Mode set to " .. PakettiGliderMode)
        end
      }
    },
    
    vb:space{height = 6},
    
    -- Options
    vb:row{
      vb:checkbox{
        id = "legato_only",
        value = PakettiGliderLegatoOnly,
        notifier = function(value)
          PakettiGliderLegatoOnly = value
          PakettiGliderDebugPrint("Legato only = " .. tostring(value))
        end
      },
      vb:text{text = "Legato Only (require note overlap)"}
    },
    
    vb:row{
      vb:checkbox{
        id = "multi_line",
        value = PakettiGliderWriteMultiLine,
        notifier = function(value)
          PakettiGliderWriteMultiLine = value
          PakettiGliderDebugPrint("Multi-line = " .. tostring(value))
        end
      },
      vb:text{text = "Multi-line Gxx (spec compliant)"}
    },
    
    vb:row{
      vb:checkbox{
        id = "debug_mode",
        value = PakettiGliderDebug,
        notifier = function(value)
          PakettiGliderDebug = value
        end
      },
      vb:text{text = "Debug Logging"}
    },
    
    vb:space{height = 6},
    
    -- Gxx Preview
    vb:row{
      vb:text{text = "Gxx Preview:", width = 100},
      vb:text{id = "gxx_preview", text = "12 semitones -> " .. PakettiGliderPreviewGxx(12, PakettiGliderDuration)}
    },
    
    vb:space{height = 10},
    
    -- Buttons
    vb:row{
      vb:button{
        text = "Clear State",
        width = 80,
        notifier = function()
          PakettiGliderClearState()
          renoise.app():show_status("PakettiGlider: State cleared")
        end
      },
      vb:button{
        text = "Save",
        width = 80,
        notifier = function()
          PakettiGliderSavePreferences()
          renoise.app():show_status("PakettiGlider: Preferences saved")
        end
      },
      vb:button{
        text = "Close",
        width = 80,
        notifier = function()
          if PakettiGlider_dialog then
            PakettiGliderSavePreferences()
            PakettiGlider_dialog:close()
            PakettiGlider_dialog = nil
          end
        end
      }
    }
  }
  
  PakettiGlider_dialog = renoise.app():show_custom_dialog(
    "Paketti Glider - Quantized Legato Engine",
    dialog_content,
    PakettiGliderKeyHandler
  )
  
  -- Set focus for keyboard handling
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

--------------------------------------------------------------------------------
-- KEYBINDINGS, MENU ENTRIES, AND MIDI MAPPINGS
--------------------------------------------------------------------------------

renoise.tool():add_keybinding{
  name = "Global:Paketti:Glider Toggle",
  invoke = function() PakettiGliderToggle() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Glider Show Dialog",
  invoke = function() PakettiGliderShowDialog() end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Glider Toggle [Trigger]",
  invoke = function(message)
    if message:is_trigger() then
      PakettiGliderToggle()
    end
  end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Glider:Glider Dialog...",
  invoke = function() PakettiGliderShowDialog() end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Glider:Glider Toggle",
  invoke = function() PakettiGliderToggle() end,
  selected = function() return PakettiGliderEnabled end
}

renoise.tool():add_menu_entry{
  name = "--Main Menu:Tools:Paketti:Glider:Set Duration 2 Lines",
  invoke = function()
    PakettiGliderDuration = 2
    renoise.app():show_status("PakettiGlider: Duration set to 2 lines")
  end,
  selected = function() return PakettiGliderDuration == 2 end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Glider:Set Duration 4 Lines",
  invoke = function()
    PakettiGliderDuration = 4
    renoise.app():show_status("PakettiGlider: Duration set to 4 lines")
  end,
  selected = function() return PakettiGliderDuration == 4 end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Glider:Set Duration 8 Lines",
  invoke = function()
    PakettiGliderDuration = 8
    renoise.app():show_status("PakettiGlider: Duration set to 8 lines")
  end,
  selected = function() return PakettiGliderDuration == 8 end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Glider:Set Duration 16 Lines",
  invoke = function()
    PakettiGliderDuration = 16
    renoise.app():show_status("PakettiGlider: Duration set to 16 lines")
  end,
  selected = function() return PakettiGliderDuration == 16 end
}

renoise.tool():add_menu_entry{
  name = "--Main Menu:Tools:Paketti:Glider:Mode Live",
  invoke = function()
    PakettiGliderMode = "live"
    renoise.app():show_status("PakettiGlider: Mode set to Live")
  end,
  selected = function() return PakettiGliderMode == "live" end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Glider:Mode Note-Off",
  invoke = function()
    PakettiGliderMode = "noteoff"
    renoise.app():show_status("PakettiGlider: Mode set to Note-Off")
  end,
  selected = function() return PakettiGliderMode == "noteoff" end
}

renoise.tool():add_menu_entry{
  name = "--Main Menu:Tools:Paketti:Glider:Legato Only Toggle",
  invoke = function()
    PakettiGliderLegatoOnly = not PakettiGliderLegatoOnly
    renoise.app():show_status("PakettiGlider: Legato Only = " .. tostring(PakettiGliderLegatoOnly))
  end,
  selected = function() return PakettiGliderLegatoOnly end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Glider:Multi-Line Gxx Toggle",
  invoke = function()
    PakettiGliderWriteMultiLine = not PakettiGliderWriteMultiLine
    renoise.app():show_status("PakettiGlider: Multi-Line = " .. tostring(PakettiGliderWriteMultiLine))
  end,
  selected = function() return PakettiGliderWriteMultiLine end
}

renoise.tool():add_menu_entry{
  name = "--Main Menu:Tools:Paketti:Glider:Clear State",
  invoke = function() PakettiGliderClearState() end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Glider:Debug Logging Toggle",
  invoke = function()
    PakettiGliderDebug = not PakettiGliderDebug
    renoise.app():show_status("PakettiGlider: Debug = " .. tostring(PakettiGliderDebug))
  end,
  selected = function() return PakettiGliderDebug end
}

--------------------------------------------------------------------------------
-- SONG CHANGE NOTIFIER
--------------------------------------------------------------------------------

-- Handler for when the song changes (new song loaded, etc.)
function PakettiGliderOnSongChanged()
  PakettiGliderDebugPrint("Song changed - clearing state")
  PakettiGliderClearState()
  
  -- Re-apply preferences to ensure consistency
  PakettiGliderLoadPreferences()
end

-- Install the song change notifier
function PakettiGliderInstallSongNotifier()
  if PakettiGlider_song_notifier_installed then
    return
  end
  
  -- Add notifier for when a new song is created/loaded
  if not renoise.tool().app_new_document_observable:has_notifier(PakettiGliderOnSongChanged) then
    renoise.tool().app_new_document_observable:add_notifier(PakettiGliderOnSongChanged)
    PakettiGlider_song_notifier_installed = true
    PakettiGliderDebugPrint("Installed song change notifier")
  end
end

-- Remove the song change notifier (cleanup)
function PakettiGliderRemoveSongNotifier()
  if not PakettiGlider_song_notifier_installed then
    return
  end
  
  if renoise.tool().app_new_document_observable:has_notifier(PakettiGliderOnSongChanged) then
    renoise.tool().app_new_document_observable:remove_notifier(PakettiGliderOnSongChanged)
    PakettiGlider_song_notifier_installed = false
    PakettiGliderDebugPrint("Removed song change notifier")
  end
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

-- Initialize Glider on load
function PakettiGliderInitialize()
  -- Load preferences
  PakettiGliderLoadPreferences()
  
  -- Install song notifier
  PakettiGliderInstallSongNotifier()
  
  -- If was enabled in preferences, start MIDI listening
  if PakettiGliderEnabled and PakettiGlider_SelectedMidiDeviceName ~= "" then
    -- Use a small delay to ensure Renoise is fully loaded
    -- Don't auto-enable on startup, let user manually enable
    PakettiGliderEnabled = false
  end
  
  print("PakettiGlider: Initialized")
end

-- Run initialization
PakettiGliderInitialize()

print("PakettiGlider: Loaded")

