local vb = renoise.ViewBuilder()
local dialog


-- Calculate frame length of current pattern
function PakettiFrameCalculatorGetPatternFrames()
  local song = renoise.song()
  local transport = song.transport
  local pattern = song.selected_pattern
  
  -- Get current transport settings
  local bpm = transport.bpm
  local lpb = transport.lpb
  local tpl = transport.tpl
  local pattern_lines = pattern.number_of_lines
  
  -- Calculate pattern duration in beats
  local pattern_beats = pattern_lines / lpb
  
  -- Calculate pattern duration in seconds
  local pattern_seconds = (pattern_beats * 60) / bpm
  
  -- Calculate pattern duration in frames (assuming 44.1kHz sample rate)
  local sample_rate = 44100
  local pattern_frames = math.floor(pattern_seconds * sample_rate + 0.5)
  
  -- Calculate minutes and seconds
  local minutes = math.floor(pattern_seconds / 60)
  local seconds = pattern_seconds - (minutes * 60)
  
  return {
    bpm = bpm,
    lpb = lpb,
    tpl = tpl,
    pattern_lines = pattern_lines,
    pattern_beats = pattern_beats,
    pattern_seconds = pattern_seconds,
    pattern_frames = pattern_frames,
    minutes = minutes,
    seconds = seconds,
    sample_rate = sample_rate
  }
end

-- Show pattern frame information in status bar
function PakettiFrameCalculatorShowPatternInfo()
  local info = PakettiFrameCalculatorGetPatternFrames()
  
  local status_text = string.format(
    "Pattern: %d lines | %d LPB | %.1f BPM | %.2f beats | %.2fs | %d frames @ %dHz | %d:%05.2f",
    info.pattern_lines,
    info.lpb,
    info.bpm,
    info.pattern_beats,
    info.pattern_seconds,
    info.pattern_frames,
    info.sample_rate,
    info.minutes,
    info.seconds
  )
  
  renoise.app():show_status(status_text)
end

-- Calculate sequence frame information
function PakettiFrameCalculatorShowSequenceInfo()
  local song = renoise.song()
  local transport = song.transport
  local sequencer = song.sequencer
  
  -- Get current transport settings
  local bpm = transport.bpm
  local lpb = transport.lpb
  local sample_rate = 44100
  
  print("=== SEQUENCE FRAME CALCULATION ===")
  print("BPM:", bpm, "| LPB:", lpb, "| Sample Rate:", sample_rate)
  print("")
  
  local total_frames = 0
  local total_seconds = 0
  local pattern_count = 0
  
  -- Calculate frames for each pattern in sequence
  for i = 1, #sequencer.pattern_sequence do
    local pattern_index = sequencer.pattern_sequence[i]
    local pattern = song:pattern(pattern_index)
    local pattern_lines = pattern.number_of_lines
    
    -- Calculate pattern duration
    local pattern_beats = pattern_lines / lpb
    local pattern_seconds = (pattern_beats * 60) / bpm
    local pattern_frames = math.floor(pattern_seconds * sample_rate + 0.5)
    
    total_frames = total_frames + pattern_frames
    total_seconds = total_seconds + pattern_seconds
    pattern_count = pattern_count + 1
    
    print(string.format("Pattern %d (seq pos %d): %d lines | %.2f beats | %.2fs | %d frames", 
      pattern_index, i, pattern_lines, pattern_beats, pattern_seconds, pattern_frames))
  end
  
  print("")
  print("=== SEQUENCE TOTALS ===")
  print("Total patterns:", pattern_count)
  print("Total duration:", string.format("%.2f seconds", total_seconds))
  print("Total frames:", total_frames)
  
  local total_minutes = math.floor(total_seconds / 60)
  local total_secs = total_seconds - (total_minutes * 60)
  
  local status_text = string.format(
    "Sequence: %d patterns | %.2fs | %d frames @ %dHz | %d:%05.2f",
    pattern_count,
    total_seconds,
    total_frames,
    sample_rate,
    total_minutes,
    total_secs
  )
  
  renoise.app():show_status(status_text)
end

-- Calculate frames from start of pattern to selected line
function PakettiFrameCalculatorShowPatternToLineInfo()
  local song = renoise.song()
  local transport = song.transport
  local pattern = song.selected_pattern
  
  -- Get current transport settings
  local bpm = transport.bpm
  local lpb = transport.lpb
  local sample_rate = 44100
  
  -- Get selected line (1-based)
  local selected_line = song.selected_line_index
  
  -- Calculate frames from start of pattern to selected line
  local lines_to_selected = selected_line - 1  -- Lines before selected line
  local beats_to_selected = lines_to_selected / lpb
  local seconds_to_selected = (beats_to_selected * 60) / bpm
  local frames_to_selected = math.floor(seconds_to_selected * sample_rate + 0.5)
  
  print("=== PATTERN TO SELECTED LINE ===")
  print("Selected line:", selected_line)
  print("Lines to selected:", lines_to_selected)
  print("Beats to selected:", string.format("%.2f", beats_to_selected))
  print("Seconds to selected:", string.format("%.2f", seconds_to_selected))
  print("Frames to selected:", frames_to_selected)
  
  local minutes = math.floor(seconds_to_selected / 60)
  local seconds = seconds_to_selected - (minutes * 60)
  
  local status_text = string.format(
    "Pattern to line %d: %d lines | %.2f beats | %.2fs | %d frames @ %dHz | %d:%05.2f",
    selected_line,
    lines_to_selected,
    beats_to_selected,
    seconds_to_selected,
    frames_to_selected,
    sample_rate,
    minutes,
    seconds
  )
  
  renoise.app():show_status(status_text)
end

-- Calculate frames from start of song to selected line
function PakettiFrameCalculatorShowSongToLineInfo()
  local song = renoise.song()
  local transport = song.transport
  local sequencer = song.sequencer
  
  -- Get current transport settings
  local bpm = transport.bpm
  local lpb = transport.lpb
  local sample_rate = 44100
  
  -- Get current sequence position and selected line
  local current_sequence_pos = song.selected_sequence_index
  local selected_line = song.selected_line_index
  
  print("=== SONG TO SELECTED LINE ===")
  print("Current sequence position:", current_sequence_pos)
  print("Selected line:", selected_line)
  print("BPM:", bpm, "| LPB:", lpb, "| Sample Rate:", sample_rate)
  print("")
  
  local total_frames = 0
  local total_seconds = 0
  
  -- Calculate frames for all patterns before current sequence position
  for i = 1, current_sequence_pos - 1 do
    local pattern_index = sequencer.pattern_sequence[i]
    local pattern = song:pattern(pattern_index)
    local pattern_lines = pattern.number_of_lines
    
    local pattern_beats = pattern_lines / lpb
    local pattern_seconds = (pattern_beats * 60) / bpm
    local pattern_frames = math.floor(pattern_seconds * sample_rate + 0.5)
    
    total_frames = total_frames + pattern_frames
    total_seconds = total_seconds + pattern_seconds
    
    print(string.format("Pattern %d (seq pos %d): %d lines | %.2f beats | %.2fs | %d frames", 
      pattern_index, i, pattern_lines, pattern_beats, pattern_seconds, pattern_frames))
  end
  
  -- Add frames from current pattern to selected line
  local current_pattern = song:pattern(sequencer.pattern_sequence[current_sequence_pos])
  local lines_to_selected = selected_line - 1
  local beats_to_selected = lines_to_selected / lpb
  local seconds_to_selected = (beats_to_selected * 60) / bpm
  local frames_to_selected = math.floor(seconds_to_selected * sample_rate + 0.5)
  
  total_frames = total_frames + frames_to_selected
  total_seconds = total_seconds + seconds_to_selected
  
  print("")
  print("Current pattern to selected line:")
  print(string.format("Lines to selected: %d | %.2f beats | %.2fs | %d frames", 
    lines_to_selected, beats_to_selected, seconds_to_selected, frames_to_selected))
  
  print("")
  print("=== SONG TOTALS TO SELECTED LINE ===")
  print("Total duration:", string.format("%.2f seconds", total_seconds))
  print("Total frames:", total_frames)
  
  local total_minutes = math.floor(total_seconds / 60)
  local total_secs = total_seconds - (total_minutes * 60)
  
  local status_text = string.format(
    "Song to line %d: %.2fs | %d frames @ %dHz | %d:%05.2f",
    selected_line,
    total_seconds,
    total_frames,
    sample_rate,
    total_minutes,
    total_secs
  )
  
  renoise.app():show_status(status_text)
end

-- Calculate total song length
function PakettiFrameCalculatorGetSongLength()
  local song = renoise.song()
  local transport = song.transport
  local sequencer = song.sequencer
  
  -- Get current transport settings
  local bpm = transport.bpm
  local lpb = transport.lpb
  local sample_rate = 44100
  
  local total_frames = 0
  local total_seconds = 0
  local pattern_count = 0
  
  -- Calculate frames for each pattern in sequence
  for i = 1, #sequencer.pattern_sequence do
    local pattern_index = sequencer.pattern_sequence[i]
    local pattern = song:pattern(pattern_index)
    local pattern_lines = pattern.number_of_lines
    
    -- Calculate pattern duration
    local pattern_beats = pattern_lines / lpb
    local pattern_seconds = (pattern_beats * 60) / bpm
    local pattern_frames = math.floor(pattern_seconds * sample_rate + 0.5)
    
    total_frames = total_frames + pattern_frames
    total_seconds = total_seconds + pattern_seconds
    pattern_count = pattern_count + 1
  end
  
  -- Calculate hours, minutes, seconds, and milliseconds
  local total_hours = math.floor(total_seconds / 3600)
  local remaining_seconds = total_seconds - (total_hours * 3600)
  local total_minutes = math.floor(remaining_seconds / 60)
  local final_seconds = remaining_seconds - (total_minutes * 60)
  local milliseconds = math.floor((final_seconds - math.floor(final_seconds)) * 1000)
  local whole_seconds = math.floor(final_seconds)
  
  return {
    total_seconds = total_seconds,
    total_frames = total_frames,
    pattern_count = pattern_count,
    hours = total_hours,
    minutes = total_minutes,
    seconds = whole_seconds,
    milliseconds = milliseconds,
    bpm = bpm,
    lpb = lpb,
    sample_rate = sample_rate
  }
end

-- Show song length in status bar
function PakettiFrameCalculatorShowSongLength()
  local info = PakettiFrameCalculatorGetSongLength()
  
  local time_format = string.format("%02d:%02d:%02d:%03d", 
    info.hours, info.minutes, info.seconds, info.milliseconds)
  
  local status_text = string.format(
    "Total song time: %s | %d patterns | %.2fs | %d frames @ %dHz | %d BPM | %d LPB",
    time_format, info.pattern_count, info.total_seconds, info.total_frames, 
    info.sample_rate, info.bpm, info.lpb
  )
  
  renoise.app():show_status(status_text)
end

-- Show song length dialog
function PakettiFrameCalculatorShowSongLengthDialog()
  local info = PakettiFrameCalculatorGetSongLength()
  
  local time_format = string.format("%02d:%02d:%02d:%03d", 
    info.hours, info.minutes, info.seconds, info.milliseconds)
  
  local dialog_content = vb:column {
    vb:row {
      vb:text { text = "Total song time:", width=100, style = "strong" },
      vb:text { text = time_format, style = "strong", font = "bold" }
    },
    vb:row {
      vb:text { text = "Patterns:", width = 100 },
      vb:text { text = tostring(info.pattern_count) }
    },
    vb:row {
      vb:text { text = "Duration:", width = 100 },
      vb:text { text = string.format("%.2f seconds", info.total_seconds) }
    },
    vb:row {
      vb:text { text = "Frames:", width = 100 },
      vb:text { text = string.format("%d @ %dHz", info.total_frames, info.sample_rate) }
    },
    vb:row {
      vb:text { text = "BPM:", width = 100 },
      vb:text { text = tostring(info.bpm) }
    },
    vb:row {
      vb:text { text = "LPB:", width = 100 },
      vb:text { text = tostring(info.lpb) }
    },
    vb:button {
      text = "OK",
      width = 100,
      notifier = function()
        if dialog then
          dialog:close()
          dialog = nil
        end
      end
    }
  }
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) 
      dialog = value
    end
  )
  
  dialog = renoise.app():show_custom_dialog("Total Song Time", dialog_content, keyhandler)
  
  -- Set active middle frame to ensure keyboard input works
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Frame calculator dialog
function PakettiFrameCalculatorDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  local song = renoise.song()
  local transport = song.transport
  
  -- Current values
  local bpm = transport.bpm
  local lpb = transport.lpb
  local tpl = transport.tpl
  local pattern_lines = song.selected_pattern.number_of_lines
  local sample_rate = 44100
  
  -- Combined output text field
  local output_textfield = vb:multiline_textfield{ 
    text = "", 
    width = 500, 
    edit_mode=true,
    active=true,
    height = 300,
  }
  
  -- Input field views for updating
  local input_views = {
    bpm = nil,
    lpb = nil,
    tpl = nil,
    pattern_lines = nil,
    sample_rate = nil
  }
  
  -- Calculation mode (1 = Current Pattern, 2 = Whole Song, 3 = Song to Line, 4 = Pattern to Line)
  local calculation_mode = 1
  
  -- Observables for reactive updates
  local observables = {}
  
  -- Timer for Song to Line and Pattern to Line modes
  local line_timer = nil
  
  -- Track last values to avoid unnecessary updates
  local last_values = {
    selected_line = 0,
    selected_sequence = 0,
    bpm = 0,
    lpb = 0
  }
  
  -- Function to update input fields from current song values
  local function updateInputFieldsFromSong()
    local song = renoise.song()
    local transport = song.transport
    local current_pattern = song.selected_pattern
    
    -- Update local variables
    bpm = transport.bpm
    lpb = transport.lpb
    tpl = transport.tpl
    pattern_lines = current_pattern.number_of_lines
    
    -- Update input field values if they exist
    if input_views.bpm then input_views.bpm.value = bpm end
    if input_views.lpb then input_views.lpb.value = lpb end
    if input_views.tpl then input_views.tpl.value = tpl end
    if input_views.pattern_lines then input_views.pattern_lines.value = pattern_lines end
    
    -- Update calculations
    updateCalculation()
  end
  
  -- Function to start observables
  local function startObservables()
    local song = renoise.song()
    if not song then return end
    
    -- BPM observable
    observables.bpm = song.transport.bpm_observable:add_notifier(function()
      updateInputFieldsFromSong()
    end)
    
    -- LPB observable
    observables.lpb = song.transport.lpb_observable:add_notifier(function()
      updateInputFieldsFromSong()
    end)
    
    -- TPL observable
    observables.tpl = song.transport.tpl_observable:add_notifier(function()
      updateInputFieldsFromSong()
    end)
    
    -- Pattern lines observable (for current pattern)
    observables.pattern_lines = song.selected_pattern.number_of_lines_observable:add_notifier(function()
      updateInputFieldsFromSong()
    end)
    
    -- Selected pattern observable (to switch pattern lines observable when pattern changes)
    observables.selected_pattern = song.selected_pattern_index_observable:add_notifier(function()
      -- Remove old pattern lines observable
      if observables.pattern_lines then
        song.selected_pattern.number_of_lines_observable:remove_notifier(observables.pattern_lines)
      end
      -- Add new pattern lines observable for new selected pattern
      observables.pattern_lines = song.selected_pattern.number_of_lines_observable:add_notifier(function()
        updateInputFieldsFromSong()
      end)
      updateInputFieldsFromSong()
    end)
  end
  
  -- Function to stop observables
  local function stopObservables()
    local song = renoise.song()
    if not song then return end
    
    if observables.bpm then
      song.transport.bpm_observable:remove_notifier(observables.bpm)
      observables.bpm = nil
    end
    
    if observables.lpb then
      song.transport.lpb_observable:remove_notifier(observables.lpb)
      observables.lpb = nil
    end
    
    if observables.tpl then
      song.transport.tpl_observable:remove_notifier(observables.tpl)
      observables.tpl = nil
    end
    
    if observables.pattern_lines then
      song.selected_pattern.number_of_lines_observable:remove_notifier(observables.pattern_lines)
      observables.pattern_lines = nil
    end
    
    if observables.selected_pattern then
      song.selected_pattern_index_observable:remove_notifier(observables.selected_pattern)
      observables.selected_pattern = nil
    end
  end
  
  -- Function to start line timer for Song to Line and Pattern to Line modes
  function startLineTimer()
    -- Stop any existing timer first
    stopLineTimer()
    
    -- Start timer that updates only when values change
    line_timer = renoise.tool().app_idle_observable:add_notifier(function()
      if calculation_mode == 3 or calculation_mode == 4 then
        local song = renoise.song()
        if not song then return end
        
        local transport = song.transport
        local current_line = song.selected_line_index
        local current_sequence = song.selected_sequence_index
        local current_bpm = transport.bpm
        local current_lpb = transport.lpb
        
        -- Only update if values actually changed
        if current_line ~= last_values.selected_line or
           current_sequence ~= last_values.selected_sequence or
           current_bpm ~= last_values.bpm or
           current_lpb ~= last_values.lpb then
          
          last_values.selected_line = current_line
          last_values.selected_sequence = current_sequence
          last_values.bpm = current_bpm
          last_values.lpb = current_lpb
          
          updateCalculation()
        end
      end
    end)
  end
  
  -- Function to stop line timer
  function stopLineTimer()
    if line_timer then
      renoise.tool().app_idle_observable:remove_notifier(line_timer)
      line_timer = nil
    end
  end
  
  -- Update calculation function
  function updateCalculation()
    local combined_text = ""
    
    if calculation_mode == 1 then
      -- Current Pattern mode
      local pattern_beats = pattern_lines / lpb
      local pattern_seconds = (pattern_beats * 60) / bpm
      local pattern_frames = math.floor(pattern_seconds * sample_rate + 0.5)
      local minutes = math.floor(pattern_seconds / 60)
      local seconds = pattern_seconds - (minutes * 60)
      
      combined_text = string.format(
        "=== CURRENT PATTERN ===\nBPM: %d | LPB: %d | TPL: %d | Sample Rate: %d\nPattern Lines: %d\n\nPattern Beats: %.2f\nDuration (sec): %.2f\nDuration (frames): %d\nTime Format: %d:%05.2f",
        bpm, lpb, tpl, sample_rate, pattern_lines, pattern_beats, pattern_seconds, pattern_frames, minutes, seconds
      )
    elseif calculation_mode == 2 then
      -- Whole Song mode
      local song = renoise.song()
      local sequencer = song.sequencer
      local transport = song.transport
      
      local bpm = transport.bpm
      local lpb = transport.lpb
      
      local total_frames = 0
      local total_seconds = 0
      local pattern_count = 0
      
      combined_text = string.format("=== WHOLE SONG ===\nBPM: %d | LPB: %d | Sample Rate: %d\n\n", bpm, lpb, sample_rate)
      
      -- Calculate frames for each pattern in sequence
      for i = 1, #sequencer.pattern_sequence do
        local pattern_index = sequencer.pattern_sequence[i]
        local pattern = song:pattern(pattern_index)
        local pattern_lines_calc = pattern.number_of_lines
        
        -- Calculate pattern duration
        local pattern_beats = pattern_lines_calc / lpb
        local pattern_seconds = (pattern_beats * 60) / bpm
        local pattern_frames = math.floor(pattern_seconds * sample_rate + 0.5)
        
        total_frames = total_frames + pattern_frames
        total_seconds = total_seconds + pattern_seconds
        pattern_count = pattern_count + 1
        
        combined_text = combined_text .. string.format(
          "Pattern %d (seq pos %d): %d lines | %.2f beats | %.2fs | %d frames\n",
          pattern_index, i, pattern_lines_calc, pattern_beats, pattern_seconds, pattern_frames
        )
      end
      
      local total_minutes = math.floor(total_seconds / 60)
      local total_secs = total_seconds - (total_minutes * 60)
      
      combined_text = combined_text .. string.format(
        "\n=== SEQUENCE TOTALS ===\nTotal Patterns: %d\nTotal Duration (sec): %.2f\nTotal Frames: %d\nTime Format: %d:%05.2f",
        pattern_count, total_seconds, total_frames, total_minutes, total_secs
      )
    elseif calculation_mode == 3 then
      -- Song to Line mode
      local song = renoise.song()
      local transport = song.transport
      local sequencer = song.sequencer
      
      local bpm = transport.bpm
      local lpb = transport.lpb
      local sample_rate_calc = 44100
      local current_sequence_pos = song.selected_sequence_index
      local selected_line = song.selected_line_index
      
      local total_frames = 0
      local total_seconds = 0
      
      combined_text = string.format(
        "=== SONG TO LINE %d ===\nBPM: %d | LPB: %d | Sample Rate: %d\nCurrent Sequence Position: %d\nSelected Line: %d\n\n",
        selected_line, bpm, lpb, sample_rate_calc, current_sequence_pos, selected_line
      )
      
      -- Calculate frames for all patterns before current sequence position
      for i = 1, current_sequence_pos - 1 do
        local pattern_index = sequencer.pattern_sequence[i]
        local pattern = song:pattern(pattern_index)
        local pattern_lines_calc = pattern.number_of_lines
        
        local pattern_beats = pattern_lines_calc / lpb
        local pattern_seconds = (pattern_beats * 60) / bpm
        local pattern_frames = math.floor(pattern_seconds * sample_rate_calc + 0.5)
        
        total_frames = total_frames + pattern_frames
        total_seconds = total_seconds + pattern_seconds
        
        combined_text = combined_text .. string.format(
          "Pattern %d (seq pos %d): %d lines | %.2f beats | %.2fs | %d frames\n",
          pattern_index, i, pattern_lines_calc, pattern_beats, pattern_seconds, pattern_frames
        )
      end
      
      -- Add frames from current pattern to selected line
      local current_pattern = song:pattern(sequencer.pattern_sequence[current_sequence_pos])
      local lines_to_selected = selected_line - 1
      local beats_to_selected = lines_to_selected / lpb
      local seconds_to_selected = (beats_to_selected * 60) / bpm
      local frames_to_selected = math.floor(seconds_to_selected * sample_rate_calc + 0.5)
      
      total_frames = total_frames + frames_to_selected
      total_seconds = total_seconds + seconds_to_selected
      
      local total_minutes = math.floor(total_seconds / 60)
      local total_secs = total_seconds - (total_minutes * 60)
      
      combined_text = combined_text .. string.format(
        "\nCurrent pattern to line %d:\nLines to selected: %d | %.2f beats | %.2fs | %d frames\n\n=== SONG TOTALS TO LINE %d ===\nLine: %d\nDuration (sec): %.2f\nTotal Frames: %d\nTime Format: %d:%05.2f",
        selected_line, lines_to_selected, beats_to_selected, seconds_to_selected, frames_to_selected, selected_line, selected_line, total_seconds, total_frames, total_minutes, total_secs
      )
    elseif calculation_mode == 4 then
      -- Pattern to Line mode
      local song = renoise.song()
      local transport = song.transport
      local selected_line = song.selected_line_index
      local current_pattern = song.selected_pattern
      
      local bpm = transport.bpm
      local lpb = transport.lpb
      local sample_rate_calc = 44100
      
      local lines_to_selected = selected_line - 1
      local beats_to_selected = lines_to_selected / lpb
      local seconds_to_selected = (beats_to_selected * 60) / bpm
      local frames_to_selected = math.floor(seconds_to_selected * sample_rate_calc + 0.5)
      
      local minutes = math.floor(seconds_to_selected / 60)
      local seconds = seconds_to_selected - (minutes * 60)
      
      combined_text = string.format(
        "=== PATTERN TO LINE %d ===\nBPM: %d | LPB: %d | Sample Rate: %d\nSelected Line: %d\n\nLines to Selected: %d\nPattern Beats: %.2f\nDuration (sec): %.2f\nDuration (frames): %d\nTime Format: %d:%05.2f",
        selected_line, bpm, lpb, sample_rate_calc, selected_line, lines_to_selected, beats_to_selected, seconds_to_selected, frames_to_selected, minutes, seconds
      )
    end
    
    -- Update the combined textfield
    output_textfield.text = combined_text
    output_textfield.edit_mode = true
    output_textfield.active = true
  end
  
  -- Build dialog content
  local function buildContent()
    local rows = {}
    
    -- Input controls
    input_views.bpm = vb:valuebox {
      value = bpm, min = 20, max = 999, width=100,
      notifier = function(val)
        bpm = val
        updateCalculation()
      end
    }
    
    input_views.lpb = vb:valuebox {
      value = lpb, min = 1, max = 256, width=100,
      notifier = function(val)
        lpb = val
        updateCalculation()
      end
    }
    
    input_views.tpl = vb:valuebox {
      value = tpl, min = 1, max = 16, width=100,
      notifier = function(val)
        tpl = val
        updateCalculation()
      end
    }
    
    input_views.pattern_lines = vb:valuebox {
      value = pattern_lines, min = 1, max = 1024, width=100,
      notifier = function(val)
        pattern_lines = val
        updateCalculation()
      end
    }
    
    input_views.sample_rate = vb:valuebox {
      value = sample_rate, min = 8000, max = 192000, width=100,
      notifier = function(val)
        sample_rate = val
        updateCalculation()
      end
    }
    
    table.insert(rows, vb:row {
      vb:text{ text = "BPM", width = 80, style="strong", font="bold" },
      input_views.bpm
    })
    
    table.insert(rows, vb:row {
      vb:text{ text = "LPB", width = 80, style="strong", font="bold" },
      input_views.lpb
    })
    
    table.insert(rows, vb:row {
      vb:text{ text = "TPL", width = 80, style="strong", font="bold" },
      input_views.tpl
    })
    
    table.insert(rows, vb:row {
      vb:text{ text = "Lines", width = 80, style="strong", font="bold" },
      input_views.pattern_lines
    })
    
    table.insert(rows, vb:row {
      vb:text{ text = "Sample Rate", width = 80, style="strong", font="bold" },
      input_views.sample_rate
    })
    
    -- Calculation mode switch
    table.insert(rows, vb:row {
      vb:text{ text = "Mode:", width = 60 },
      vb:switch {
        items = {"Current Pattern", "Whole Song", "Song to Line", "Pattern to Line"},
        value = calculation_mode,
        width = 400,
        notifier = function(val)
          calculation_mode = val
          updateCalculation()
          
          -- Start/stop line timer based on mode
          if val == 3 or val == 4 then
            -- Initialize last values when starting timer modes
            local song = renoise.song()
            if song then
              local transport = song.transport
              last_values.selected_line = song.selected_line_index
              last_values.selected_sequence = song.selected_sequence_index
              last_values.bpm = transport.bpm
              last_values.lpb = transport.lpb
            end
            startLineTimer()
          else
            stopLineTimer()
          end
        end
      }
    })
    
    table.insert(rows, output_textfield)
        
    
    
    -- Initial calculation
    updateCalculation()
    
    return vb:column { unpack(rows) }
  end
  
  -- Create key handler
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) 
      dialog = value
      if value == nil then
        -- Dialog is being closed, stop observables and timer
        stopObservables()
        stopLineTimer()
      end
    end
  )
  
  dialog = renoise.app():show_custom_dialog("Paketti Frame Calculator", buildContent(), keyhandler)
  
  -- Start observables after dialog is created
  startObservables()
end

renoise.tool():add_keybinding{name = "Global:Paketti:Show Pattern Frame Info", invoke = PakettiFrameCalculatorShowPatternInfo}
renoise.tool():add_keybinding{name = "Global:Paketti:Show Sequence Frame Info", invoke = PakettiFrameCalculatorShowSequenceInfo}
renoise.tool():add_keybinding{name = "Global:Paketti:Show Pattern to Line Frame Info", invoke = PakettiFrameCalculatorShowPatternToLineInfo}
renoise.tool():add_keybinding{name = "Global:Paketti:Show Song to Line Frame Info", invoke = PakettiFrameCalculatorShowSongToLineInfo}
renoise.tool():add_keybinding{name = "Global:Paketti:Show Song Length", invoke = PakettiFrameCalculatorShowSongLength}
renoise.tool():add_keybinding{name = "Global:Paketti:Show Song Length Dialog", invoke = PakettiFrameCalculatorShowSongLengthDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Frame Calculator Dialog", invoke = PakettiFrameCalculatorDialog}

renoise.tool():add_menu_entry{name = "--Pattern Matrix:Paketti:Show Pattern Frame Info", invoke = PakettiFrameCalculatorShowPatternInfo}
renoise.tool():add_menu_entry{name = "Pattern Matrix:Paketti:Show Sequence Frame Info", invoke = PakettiFrameCalculatorShowSequenceInfo}
renoise.tool():add_menu_entry{name = "Pattern Matrix:Paketti:Show Song Length", invoke = PakettiFrameCalculatorShowSongLength}
renoise.tool():add_menu_entry{name = "Pattern Matrix:Paketti:Show Song Length Dialog", invoke = PakettiFrameCalculatorShowSongLengthDialog}
renoise.tool():add_menu_entry{name = "Pattern Matrix:Paketti:Frame Calculator Dialog", invoke = PakettiFrameCalculatorDialog}

renoise.tool():add_menu_entry{name = "--Pattern Sequencer:Paketti:Show Pattern Frame Info", invoke = PakettiFrameCalculatorShowPatternInfo}
renoise.tool():add_menu_entry{name = "Pattern Sequencer:Paketti:Show Sequence Frame Info", invoke = PakettiFrameCalculatorShowSequenceInfo}
renoise.tool():add_menu_entry{name = "Pattern Sequencer:Paketti:Show Song Length", invoke = PakettiFrameCalculatorShowSongLength}
renoise.tool():add_menu_entry{name = "Pattern Sequencer:Paketti:Show Song Length Dialog", invoke = PakettiFrameCalculatorShowSongLengthDialog}
renoise.tool():add_menu_entry{name = "Pattern Sequencer:Paketti:Frame Calculator Dialog", invoke = PakettiFrameCalculatorDialog}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti:Show Pattern Frame Info", invoke = PakettiFrameCalculatorShowPatternInfo}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti:Show Sequence Frame Info", invoke = PakettiFrameCalculatorShowSequenceInfo}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti:Show Pattern to Line Frame Info", invoke = PakettiFrameCalculatorShowPatternToLineInfo}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti:Show Song to Line Frame Info", invoke = PakettiFrameCalculatorShowSongToLineInfo}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti:Show Song Length", invoke = PakettiFrameCalculatorShowSongLength}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti:Show Song Length Dialog", invoke = PakettiFrameCalculatorShowSongLengthDialog}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti:Frame Calculator Dialog", invoke = PakettiFrameCalculatorDialog}

renoise.tool():add_menu_entry{name = "--Mixer:Paketti:Show Pattern Frame Info", invoke = PakettiFrameCalculatorShowPatternInfo}
renoise.tool():add_menu_entry{name = "Mixer:Paketti:Show Sequence Frame Info", invoke = PakettiFrameCalculatorShowSequenceInfo}
renoise.tool():add_menu_entry{name = "Mixer:Paketti:Show Song Length", invoke = PakettiFrameCalculatorShowSongLength}
renoise.tool():add_menu_entry{name = "Mixer:Paketti:Show Song Length Dialog", invoke = PakettiFrameCalculatorShowSongLengthDialog}
renoise.tool():add_menu_entry{name = "Mixer:Paketti:Frame Calculator Dialog", invoke = PakettiFrameCalculatorDialog}

-- Frame Calculator Live Update Timer
local pakettiFrameCalculatorTimer = nil

-- Frame Calculator Live Update Functions
function pakettiFrameCalculatorLiveUpdate()
  local mode = preferences.pakettiFrameCalculatorLiveUpdate.value
  if mode == 1 then -- Off
    return
  end
  
  local song = renoise.song()
  if not song then return end
  
  local transport = song.transport
  local sequencer = song.sequencer
  
  -- Get current transport settings as defaults
  local default_bpm = transport.bpm
  local default_lpb = transport.lpb
  local sample_rate = 44100
  
  -- Get current sequence position and selected line
  local current_sequence_pos = song.selected_sequence_index
  local selected_line = song.selected_line_index
  
  local status_parts = {}
  
  -- Calculate Song to Line if needed
  if mode == 2 or mode == 4 then -- Song to Line or Both
    local song_frames = 0
    local song_seconds = 0
    local song_rows = 0
    
    -- Calculate frames for all patterns before current sequence position
    for i = 1, current_sequence_pos - 1 do
      local pattern_index = sequencer.pattern_sequence[i]
      local pattern = song:pattern(pattern_index)
      local pattern_lines = pattern.number_of_lines
      
      local pattern_beats = pattern_lines / default_lpb
      local pattern_seconds = (pattern_beats * 60) / default_bpm
      local pattern_frames = math.floor(pattern_seconds * sample_rate + 0.5)
      
      song_frames = song_frames + pattern_frames
      song_seconds = song_seconds + pattern_seconds
      song_rows = song_rows + pattern_lines
    end
    
    -- Add frames from current pattern to selected line
    local current_pattern = song:pattern(sequencer.pattern_sequence[current_sequence_pos])
    local lines_to_selected = selected_line - 1
    local beats_to_selected = lines_to_selected / default_lpb
    local seconds_to_selected = (beats_to_selected * 60) / default_bpm
    local frames_to_selected = math.floor(seconds_to_selected * sample_rate + 0.5)
    
    song_frames = song_frames + frames_to_selected
    song_seconds = song_seconds + seconds_to_selected
    song_rows = song_rows + lines_to_selected
    
    local song_minutes = math.floor(song_seconds / 60)
    local song_secs = song_seconds - (song_minutes * 60)
    
    table.insert(status_parts, string.format(
      "Song to line %d: %.2fs | %d frames | %d rows | %d:%05.2f",
      selected_line, song_seconds, song_frames, song_rows, song_minutes, song_secs
    ))
  end
  
  -- Calculate Pattern to Line if needed
  if mode == 3 or mode == 4 then -- Pattern to Line or Both
    local current_pattern = song:pattern(sequencer.pattern_sequence[current_sequence_pos])
    
    local lines_to_selected = selected_line - 1
    local beats_to_selected = lines_to_selected / default_lpb
    local seconds_to_selected = (beats_to_selected * 60) / default_bpm
    local frames_to_selected = math.floor(seconds_to_selected * sample_rate + 0.5)
    
    local pattern_minutes = math.floor(seconds_to_selected / 60)
    local pattern_secs = seconds_to_selected - (pattern_minutes * 60)
    
    table.insert(status_parts, string.format(
      "Pattern to line %d: %.2fs | %d frames | %d rows | %d:%05.2f",
      selected_line, seconds_to_selected, frames_to_selected, lines_to_selected, pattern_minutes, pattern_secs
    ))
  end
  
  -- Combine results
  local status_text = table.concat(status_parts, " | ")
  renoise.app():show_status(status_text)
end

function pakettiFrameCalculatorStartLiveUpdate()
  -- Stop any existing timer first
  pakettiFrameCalculatorStopLiveUpdate()
  
  -- Start timer that updates every 100ms using app_idle_observable
  pakettiFrameCalculatorTimer = renoise.tool().app_idle_observable:add_notifier(function()
    pakettiFrameCalculatorLiveUpdate()
  end)
  
  -- Show initial status
  pakettiFrameCalculatorLiveUpdate()
end

function pakettiFrameCalculatorStopLiveUpdate()
  -- Remove the timer if it exists
  if pakettiFrameCalculatorTimer then
    renoise.tool().app_idle_observable:remove_notifier(pakettiFrameCalculatorTimer)
    pakettiFrameCalculatorTimer = nil
  end
end

function pakettiFrameCalculatorInitializeLiveUpdate()
  if preferences.pakettiFrameCalculatorLiveUpdate.value > 1 then
    pakettiFrameCalculatorStartLiveUpdate()
  end
end
