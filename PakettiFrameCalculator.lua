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
  
  -- Result display views
  local result_views = {
    pattern_beats = vb:text{ text = "", font = "bold", style = "strong", width = 100 },
    pattern_seconds = vb:text{ text = "", font = "bold", style = "strong", width = 100 },
    pattern_frames = vb:text{ text = "", font = "bold", style = "strong", width = 120 },
    time_format = vb:text{ text = "", font = "bold", style = "strong", width = 100 }
  }
  
  -- Input field views for updating
  local input_views = {
    bpm = nil,
    lpb = nil,
    tpl = nil,
    pattern_lines = nil,
    sample_rate = nil
  }
  
  -- Debug output text field
  local debug_text = vb:text{ text = "", width = 400, height = 200 }
  
  -- Calculation mode (1 = Current Pattern, 2 = Whole Song, 3 = Song to Line, 4 = Pattern to Line)
  local calculation_mode = 1
  
  -- Observables for reactive updates
  local observables = {}
  
  -- Timer for Song to Line and Pattern to Line modes
  local line_timer = nil
  
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
    
    -- Start timer that updates every 100ms using app_idle_observable
    line_timer = renoise.tool().app_idle_observable:add_notifier(function()
      if calculation_mode == 3 or calculation_mode == 4 then
        updateCalculation()
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
    if calculation_mode == 1 then
      -- Current Pattern mode
      local pattern_beats = pattern_lines / lpb
      local pattern_seconds = (pattern_beats * 60) / bpm
      local pattern_frames = math.floor(pattern_seconds * sample_rate + 0.5)
      local minutes = math.floor(pattern_seconds / 60)
      local seconds = pattern_seconds - (minutes * 60)
      
      result_views.pattern_beats.text = string.format("%.2f", pattern_beats)
      result_views.pattern_seconds.text = string.format("%.2f", pattern_seconds)
      result_views.pattern_frames.text = string.format("%d", pattern_frames)
      result_views.time_format.text = string.format("%d:%05.2f", minutes, seconds)
    elseif calculation_mode == 2 then
      -- Whole Song mode
      local song = renoise.song()
      local sequencer = song.sequencer
      
      local total_frames = 0
      local total_seconds = 0
      local pattern_count = 0
      
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
      end
      
      local total_minutes = math.floor(total_seconds / 60)
      local total_secs = total_seconds - (total_minutes * 60)
      
      result_views.pattern_beats.text = string.format("%d patterns", pattern_count)
      result_views.pattern_seconds.text = string.format("%.2f", total_seconds)
      result_views.pattern_frames.text = string.format("%d", total_frames)
      result_views.time_format.text = string.format("%d:%05.2f", total_minutes, total_secs)
    elseif calculation_mode == 3 then
      -- Song to Line mode
      local song = renoise.song()
      local transport = song.transport
      local sequencer = song.sequencer
      
      local bpm_calc = transport.bpm
      local lpb_calc = transport.lpb
      local sample_rate_calc = 44100
      local current_sequence_pos = song.selected_sequence_index
      local selected_line = song.selected_line_index
      
      local total_frames = 0
      local total_seconds = 0
      
      -- Calculate frames for all patterns before current sequence position
      for i = 1, current_sequence_pos - 1 do
        local pattern_index = sequencer.pattern_sequence[i]
        local pattern = song:pattern(pattern_index)
        local pattern_lines_calc = pattern.number_of_lines
        
        local pattern_beats = pattern_lines_calc / lpb_calc
        local pattern_seconds = (pattern_beats * 60) / bpm_calc
        local pattern_frames = math.floor(pattern_seconds * sample_rate_calc + 0.5)
        
        total_frames = total_frames + pattern_frames
        total_seconds = total_seconds + pattern_seconds
      end
      
      -- Add frames from current pattern to selected line
      local current_pattern = song:pattern(sequencer.pattern_sequence[current_sequence_pos])
      local lines_to_selected = selected_line - 1
      local beats_to_selected = lines_to_selected / lpb_calc
      local seconds_to_selected = (beats_to_selected * 60) / bpm_calc
      local frames_to_selected = math.floor(seconds_to_selected * sample_rate_calc + 0.5)
      
      total_frames = total_frames + frames_to_selected
      total_seconds = total_seconds + seconds_to_selected
      
      local total_minutes = math.floor(total_seconds / 60)
      local total_secs = total_seconds - (total_minutes * 60)
      
      result_views.pattern_beats.text = string.format("Line %d", selected_line)
      result_views.pattern_seconds.text = string.format("%.2f", total_seconds)
      result_views.pattern_frames.text = string.format("%d", total_frames)
      result_views.time_format.text = string.format("%d:%05.2f", total_minutes, total_secs)
    elseif calculation_mode == 4 then
      -- Pattern to Line mode
      local song = renoise.song()
      local transport = song.transport
      local selected_line = song.selected_line_index
      
      local bpm_calc = transport.bpm
      local lpb_calc = transport.lpb
      local sample_rate_calc = 44100
      
      local lines_to_selected = selected_line - 1
      local beats_to_selected = lines_to_selected / lpb_calc
      local seconds_to_selected = (beats_to_selected * 60) / bpm_calc
      local frames_to_selected = math.floor(seconds_to_selected * sample_rate_calc + 0.5)
      
      local minutes = math.floor(seconds_to_selected / 60)
      local seconds = seconds_to_selected - (minutes * 60)
      
      result_views.pattern_beats.text = string.format("%.2f", beats_to_selected)
      result_views.pattern_seconds.text = string.format("%.2f", seconds_to_selected)
      result_views.pattern_frames.text = string.format("%d", frames_to_selected)
      result_views.time_format.text = string.format("%d:%05.2f", minutes, seconds)
    end
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
    
    table.insert(rows, vb:space{ height = 8 })
    
    -- Calculation mode switch
    table.insert(rows, vb:row {
      vb:text{ text = "Mode:", width = 60 },
      vb:switch {
        items = {"Current Pattern", "Whole Song", "Song to Line", "Pattern to Line"},
        value = calculation_mode,
        width = 500,
        notifier = function(val)
          calculation_mode = val
          updateCalculation()
          
          -- Start/stop line timer based on mode
          if val == 3 or val == 4 then
            startLineTimer()
          else
            stopLineTimer()
          end
        end
      }
    })
    
    table.insert(rows, vb:space{ height = 8 })
    
    -- Results
    table.insert(rows, vb:text{ text = "Results:", font = "bold", style = "strong" })
    
    table.insert(rows, vb:row {
      vb:text{ text = "Pattern Beats:", width = 100 },
      result_views.pattern_beats
    })
    
    table.insert(rows, vb:row {
      vb:text{ text = "Duration (sec):", width = 100 },
      result_views.pattern_seconds
    })
    
    table.insert(rows, vb:row {
      vb:text{ text = "Duration (frames):", width = 100 },
      result_views.pattern_frames
    })
    
    table.insert(rows, vb:row {
      vb:text{ text = "Time Format:", width = 100 },
      result_views.time_format
    })
    
    table.insert(rows, vb:space{ height = 8 })
    
    -- Buttons
    table.insert(rows, vb:row {
      vb:button {
        text = "Use Current Pattern",
        notifier = function()
          local current_info = PakettiFrameCalculatorGetPatternFrames()
          bpm = current_info.bpm
          lpb = current_info.lpb
          tpl = current_info.tpl
          pattern_lines = current_info.pattern_lines
          sample_rate = current_info.sample_rate
          
          -- Update the input fields
          input_views.bpm.value = bpm
          input_views.lpb.value = lpb
          input_views.tpl.value = tpl
          input_views.pattern_lines.value = pattern_lines
          input_views.sample_rate.value = sample_rate
          
          updateCalculation()
        end
      },
      vb:button {
        text = "Calculate Song",
        notifier = function()
          -- Calculate song info and show debug output
          local song = renoise.song()
          local transport = song.transport
          local sequencer = song.sequencer
          
          local bpm_calc = transport.bpm
          local lpb_calc = transport.lpb
          local sample_rate_calc = 44100
          
          local debug_output = {}
          table.insert(debug_output, "=== SONG FRAME CALCULATION ===")
          table.insert(debug_output, string.format("BPM: %d | LPB: %d | Sample Rate: %d", bpm_calc, lpb_calc, sample_rate_calc))
          table.insert(debug_output, "")
          
          local total_frames = 0
          local total_seconds = 0
          local pattern_count = 0
          
          -- Calculate frames for each pattern in sequence
          for i = 1, #sequencer.pattern_sequence do
            local pattern_index = sequencer.pattern_sequence[i]
            local pattern = song:pattern(pattern_index)
            local pattern_lines = pattern.number_of_lines
            
            -- Calculate pattern duration
            local pattern_beats = pattern_lines / lpb_calc
            local pattern_seconds = (pattern_beats * 60) / bpm_calc
            local pattern_frames = math.floor(pattern_seconds * sample_rate_calc + 0.5)
            
            total_frames = total_frames + pattern_frames
            total_seconds = total_seconds + pattern_seconds
            pattern_count = pattern_count + 1
            
            table.insert(debug_output, string.format("Pattern %d (seq pos %d): %d lines | %.2f beats | %.2fs | %d frames", 
              pattern_index, i, pattern_lines, pattern_beats, pattern_seconds, pattern_frames))
          end
          
          table.insert(debug_output, "")
          table.insert(debug_output, "=== SEQUENCE TOTALS ===")
          table.insert(debug_output, string.format("Total patterns: %d", pattern_count))
          table.insert(debug_output, string.format("Total duration: %.2f seconds", total_seconds))
          table.insert(debug_output, string.format("Total frames: %d", total_frames))
          
          local total_minutes = math.floor(total_seconds / 60)
          local total_secs = total_seconds - (total_minutes * 60)
          table.insert(debug_output, string.format("Time format: %d:%05.2f", total_minutes, total_secs))
          
          debug_text.text = table.concat(debug_output, "\n")
        end
      },
      vb:button {
        text = "Copy to Status",
        notifier = function()
          if calculation_mode == 1 then
            -- Current Pattern mode
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
          elseif calculation_mode == 2 then
            -- Whole Song mode
            local song = renoise.song()
            local sequencer = song.sequencer
            local transport = song.transport
            
            local bpm_calc = transport.bpm
            local lpb_calc = transport.lpb
            local sample_rate_calc = 44100
            
            local total_frames = 0
            local total_seconds = 0
            local pattern_count = 0
            
            -- Calculate frames for each pattern in sequence
            for i = 1, #sequencer.pattern_sequence do
              local pattern_index = sequencer.pattern_sequence[i]
              local pattern = song:pattern(pattern_index)
              local pattern_lines_calc = pattern.number_of_lines
              
              -- Calculate pattern duration
              local pattern_beats = pattern_lines_calc / lpb_calc
              local pattern_seconds = (pattern_beats * 60) / bpm_calc
              local pattern_frames = math.floor(pattern_seconds * sample_rate_calc + 0.5)
              
              total_frames = total_frames + pattern_frames
              total_seconds = total_seconds + pattern_seconds
              pattern_count = pattern_count + 1
            end
            
            local total_minutes = math.floor(total_seconds / 60)
            local total_secs = total_seconds - (total_minutes * 60)
            
            local status_text = string.format(
              "Song: %d patterns | %.2fs | %d frames @ %dHz | %d:%05.2f",
              pattern_count,
              total_seconds,
              total_frames,
              sample_rate_calc,
              total_minutes,
              total_secs
            )
            renoise.app():show_status(status_text)
          elseif calculation_mode == 3 then
            -- Song to Line mode
            local song = renoise.song()
            local transport = song.transport
            local sequencer = song.sequencer
            
            local bpm_calc = transport.bpm
            local lpb_calc = transport.lpb
            local sample_rate_calc = 44100
            local current_sequence_pos = song.selected_sequence_index
            local selected_line = song.selected_line_index
            
            local total_frames = 0
            local total_seconds = 0
            
            -- Calculate frames for all patterns before current sequence position
            for i = 1, current_sequence_pos - 1 do
              local pattern_index = sequencer.pattern_sequence[i]
              local pattern = song:pattern(pattern_index)
              local pattern_lines_calc = pattern.number_of_lines
              
              local pattern_beats = pattern_lines_calc / lpb_calc
              local pattern_seconds = (pattern_beats * 60) / bpm_calc
              local pattern_frames = math.floor(pattern_seconds * sample_rate_calc + 0.5)
              
              total_frames = total_frames + pattern_frames
              total_seconds = total_seconds + pattern_seconds
            end
            
            -- Add frames from current pattern to selected line
            local current_pattern = song:pattern(sequencer.pattern_sequence[current_sequence_pos])
            local lines_to_selected = selected_line - 1
            local beats_to_selected = lines_to_selected / lpb_calc
            local seconds_to_selected = (beats_to_selected * 60) / bpm_calc
            local frames_to_selected = math.floor(seconds_to_selected * sample_rate_calc + 0.5)
            
            total_frames = total_frames + frames_to_selected
            total_seconds = total_seconds + seconds_to_selected
            
            local total_minutes = math.floor(total_seconds / 60)
            local total_secs = total_seconds - (total_minutes * 60)
            
            local status_text = string.format(
              "Song to line %d: %.2fs | %d frames @ %dHz | %d:%05.2f",
              selected_line,
              total_seconds,
              total_frames,
              sample_rate_calc,
              total_minutes,
              total_secs
            )
            renoise.app():show_status(status_text)
          elseif calculation_mode == 4 then
            -- Pattern to Line mode
            local song = renoise.song()
            local transport = song.transport
            local selected_line = song.selected_line_index
            
            local bpm_calc = transport.bpm
            local lpb_calc = transport.lpb
            local sample_rate_calc = 44100
            
            local lines_to_selected = selected_line - 1
            local beats_to_selected = lines_to_selected / lpb_calc
            local seconds_to_selected = (beats_to_selected * 60) / bpm_calc
            local frames_to_selected = math.floor(seconds_to_selected * sample_rate_calc + 0.5)
            
            local minutes = math.floor(seconds_to_selected / 60)
            local seconds = seconds_to_selected - (minutes * 60)
            
            local status_text = string.format(
              "Pattern to line %d: %d lines | %.2f beats | %.2fs | %d frames @ %dHz | %d:%05.2f",
              selected_line,
              lines_to_selected,
              beats_to_selected,
              seconds_to_selected,
              frames_to_selected,
              sample_rate_calc,
              minutes,
              seconds
            )
            renoise.app():show_status(status_text)
          end
        end
      }
    })
    
    table.insert(rows, vb:space{ height = 8 })
    
    -- Debug output section
    table.insert(rows, vb:text{ text = "Debug Output:", font = "bold", style = "strong" })
    table.insert(rows, debug_text)
    
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
renoise.tool():add_keybinding{name = "Global:Paketti:Frame Calculator Dialog", invoke = PakettiFrameCalculatorDialog}

renoise.tool():add_menu_entry{name = "Pattern Matrix:Paketti:Show Pattern Frame Info", invoke = PakettiFrameCalculatorShowPatternInfo}
renoise.tool():add_menu_entry{name = "Pattern Matrix:Paketti:Show Sequence Frame Info", invoke = PakettiFrameCalculatorShowSequenceInfo}
renoise.tool():add_menu_entry{name = "Pattern Matrix:Paketti:Frame Calculator Dialog", invoke = PakettiFrameCalculatorDialog}

renoise.tool():add_menu_entry{name = "Pattern Sequencer:Paketti:Show Pattern Frame Info", invoke = PakettiFrameCalculatorShowPatternInfo}
renoise.tool():add_menu_entry{name = "Pattern Sequencer:Paketti:Show Sequence Frame Info", invoke = PakettiFrameCalculatorShowSequenceInfo}
renoise.tool():add_menu_entry{name = "Pattern Sequencer:Paketti:Frame Calculator Dialog", invoke = PakettiFrameCalculatorDialog}

renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti:Show Pattern Frame Info", invoke = PakettiFrameCalculatorShowPatternInfo}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti:Show Sequence Frame Info", invoke = PakettiFrameCalculatorShowSequenceInfo}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti:Show Pattern to Line Frame Info", invoke = PakettiFrameCalculatorShowPatternToLineInfo}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti:Show Song to Line Frame Info", invoke = PakettiFrameCalculatorShowSongToLineInfo}
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti:Frame Calculator Dialog", invoke = PakettiFrameCalculatorDialog}

renoise.tool():add_menu_entry{name = "Mixer:Paketti:Show Pattern Frame Info", invoke = PakettiFrameCalculatorShowPatternInfo}
renoise.tool():add_menu_entry{name = "Mixer:Paketti:Show Sequence Frame Info", invoke = PakettiFrameCalculatorShowSequenceInfo}
renoise.tool():add_menu_entry{name = "Mixer:Paketti:Frame Calculator Dialog", invoke = PakettiFrameCalculatorDialog}
