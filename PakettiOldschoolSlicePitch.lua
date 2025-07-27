-- PakettiOldschoolSlicePitch.lua
-- Oldschool technique for filling gaps in resampled drum breaks
-- Detects silent gaps and fills them with reversed audio from the preceding slice
-- Also includes slice-to-pattern reconstruction for timing-accurate break programming

function detectGapsInSample()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No sample selected")
    return
  end
  
  local sample = instrument.samples[song.selected_sample_index]
  if not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample data found")
    return
  end
  
  local buffer = sample.sample_buffer
  local channels = buffer.number_of_channels
  local frames = buffer.number_of_frames
  local sample_rate = buffer.sample_rate
  
  local gaps = {}
  local silence_threshold = 0.001 -- Threshold for detecting silence
  local min_gap_length = math.floor(sample_rate * 0.01) -- Minimum 10ms gap
  
  local in_silence = false
  local silence_start = 0
  
  for frame = 1, frames do
    local is_silent = true
    
    -- Check all channels for silence
    for channel = 1, channels do
      local sample_value = math.abs(buffer:sample_data(channel, frame))
      if sample_value > silence_threshold then
        is_silent = false
        break
      end
    end
    
    if is_silent and not in_silence then
      -- Start of silence
      in_silence = true
      silence_start = frame
    elseif not is_silent and in_silence then
      -- End of silence
      local gap_length = frame - silence_start
      if gap_length >= min_gap_length then
        table.insert(gaps, {
          start_frame = silence_start,
          end_frame = frame - 1,
          length = gap_length
        })
      end
      in_silence = false
    end
  end
  
  -- Handle silence that goes to the end of the sample
  if in_silence then
    local gap_length = frames - silence_start + 1
    if gap_length >= min_gap_length then
      table.insert(gaps, {
        start_frame = silence_start,
        end_frame = frames,
        length = gap_length
      })
      print("Debug: Added final silence gap that goes to end of sample")
    end
  end
  
  if #gaps == 0 then
    renoise.app():show_status("No significant gaps detected")
    return
  end
  
  renoise.app():show_status(string.format("Found %d gaps", #gaps))
  return gaps
end

function fillGapWithReversedAudio(gap_start, gap_end)
  local song = renoise.song()
  local instrument = song.selected_instrument
  local sample = instrument.samples[song.selected_sample_index]
  local buffer = sample.sample_buffer
  
  local gap_length = gap_end - gap_start + 1
  local copy_start = math.max(1, gap_start - gap_length)
  local copy_end = gap_start - 1
  
  if copy_start >= copy_end then
    renoise.app():show_status("Not enough audio before gap to fill")
    return
  end
  
  local channels = buffer.number_of_channels
  
  -- Fill gap directly in the SAME sample buffer with REVERSED audio
  for channel = 1, channels do
    for i = 0, gap_length - 1 do
      local source_frame = copy_end - i    -- Start from end and work backwards (REVERSAL)
      local target_frame = gap_start + i   -- Fill gap from start to end
      
      if source_frame >= copy_start and target_frame <= gap_end then
        local sample_value = buffer:sample_data(channel, source_frame)
        buffer:set_sample_data(channel, target_frame, sample_value)
      end
    end
  end
  
  renoise.app():show_status("Gap filled with reversed audio")
end

function fillGapWithCopiedAudio(gap_start, gap_end)
  local song = renoise.song()
  local instrument = song.selected_instrument
  local sample = instrument.samples[song.selected_sample_index]
  local buffer = sample.sample_buffer
  
  local gap_length = gap_end - gap_start + 1
  local copy_start = math.max(1, gap_start - gap_length)
  local copy_end = gap_start - 1
  
  if copy_start >= copy_end then
    renoise.app():show_status("Not enough audio before gap to fill")
    return
  end
  
  local channels = buffer.number_of_channels
  
  -- Fill gap directly in the SAME sample buffer (NO new sample creation!)
  for channel = 1, channels do
    for i = 0, gap_length - 1 do
      local source_frame = copy_start + i -- Copy from start of source region forward
      local target_frame = gap_start + i  -- Fill gap from start to end
      
      if source_frame <= copy_end and target_frame <= gap_end then
        local sample_value = buffer:sample_data(channel, source_frame)
        buffer:set_sample_data(channel, target_frame, sample_value)
      end
    end
  end
  
  renoise.app():show_status("Gap filled with copied audio (no reversal)")
end

function pakettiOldschoolSlicePitchDetectGaps()
  local gaps = detectGapsInSample()
  if not gaps then return end
  
  local gap_info = {}
  for i, gap in ipairs(gaps) do
    table.insert(gap_info, string.format("Gap %d: %d - %d (%d samples)", 
      i, gap.start_frame, gap.end_frame, gap.length))
  end
  
  local message = "Detected gaps:\n" .. table.concat(gap_info, "\n") .. 
    "\n\nSelect range in sample and use 'Fill Selected Gap' to fix."
  renoise.app():show_message(message)
end

function pakettiOldschoolSlicePitchFillSelectedGap()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No sample selected")
    return
  end
  
  local sample = instrument.samples[song.selected_sample_index]
  if not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample data found")
    return
  end
  
  -- Check if there's a selection in the sample editor
  if not sample.sample_buffer.selection_range or 
     sample.sample_buffer.selection_range[1] == sample.sample_buffer.selection_range[2] then
    renoise.app():show_status("Please select the gap range in sample editor first")
    return
  end
  
  local gap_start = sample.sample_buffer.selection_range[1]
  local gap_end = sample.sample_buffer.selection_range[2]
  
  fillGapWithReversedAudio(gap_start, gap_end)
end

function pakettiOldschoolSlicePitchFillSelectedGapCopied()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No sample selected")
    return
  end
  
  local sample = instrument.samples[song.selected_sample_index]
  if not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample data found")
    return
  end
  
  -- Check if there's a selection in the sample editor
  if not sample.sample_buffer.selection_range or 
     sample.sample_buffer.selection_range[1] == sample.sample_buffer.selection_range[2] then
    renoise.app():show_status("Please select the gap range in sample editor first")
    return
  end
  
  local gap_start = sample.sample_buffer.selection_range[1]
  local gap_end = sample.sample_buffer.selection_range[2]
  
  fillGapWithCopiedAudio(gap_start, gap_end)
end

function pakettiOldschoolSlicePitchFillAllGaps()
  local gaps = detectGapsInSample()
  if not gaps then return end
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  local sample = instrument.samples[song.selected_sample_index]
  
  -- Create new sample for the result
  local new_sample = instrument:insert_sample_at(song.selected_sample_index + 1)
  new_sample:copy_from(sample)
  
  -- Fill all gaps in the new sample
  for i = #gaps, 1, -1 do -- Reverse order to maintain frame positions
    local gap = gaps[i]
    song.selected_sample_index = song.selected_sample_index
    fillGapWithReversedAudio(gap.start_frame, gap.end_frame)
  end
  
  new_sample.name = sample.name .. " (All Gaps Filled)"
  renoise.app():show_status(string.format("Filled %d gaps", #gaps))
end

function pakettiOldschoolSlicePitchFillAllGapsCopied()
  local gaps = detectGapsInSample()
  if not gaps then return end
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  local sample = instrument.samples[song.selected_sample_index]
  
  -- Create new sample for the result
  local new_sample = instrument:insert_sample_at(song.selected_sample_index + 1)
  new_sample:copy_from(sample)
  
  -- Update to work with the new sample
  song.selected_sample_index = song.selected_sample_index + 1
  
  -- Fill all gaps in the new sample (work backwards to maintain positions)
  for i = #gaps, 1, -1 do
    local gap = gaps[i]
    fillGapWithCopiedAudio(gap.start_frame, gap.end_frame)
  end
  
  new_sample.name = sample.name .. " (All Gaps Filled Copied)"
  renoise.app():show_status(string.format("Filled %d gaps with copied audio", #gaps))
end

function pakettiSlicesToPattern()
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No instrument or no samples found")
    return
  end
  
  -- Always use first sample
  local sample = instrument.samples[1]
  print("Debug: Using sample:", sample.name)
  if not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("First sample has no sample data")
    return
  end
  
  local buffer = sample.sample_buffer
  local sample_frames = buffer.number_of_frames
  local sample_rate = buffer.sample_rate
  
  -- Get slice markers
  local slice_markers = {}
  
  -- Debug: Check what slice_markers contains
  print("Debug: sample.slice_markers type:", type(sample.slice_markers))
  if sample.slice_markers then
    print("Debug: slice_markers length:", #sample.slice_markers)
    for i, marker in ipairs(sample.slice_markers) do
      print("Debug: slice marker", i, ":", marker)
      table.insert(slice_markers, marker)
    end
  else
    print("Debug: sample.slice_markers is nil")
  end
  
  if #slice_markers == 0 then
    renoise.app():show_status("No slice markers found - use Sample Editor to slice first")
    return
  end
  
  -- Add final marker at end of sample if not present
  if slice_markers[#slice_markers] ~= sample_frames then
    table.insert(slice_markers, sample_frames)
  end
  
  local pattern = song.selected_pattern
  local track = song.selected_track
  local pattern_lines = pattern.number_of_lines
  local bpm = song.transport.bpm
  local lpb = song.transport.lpb
  
  -- Calculate timing conversion
  local frames_per_second = sample_rate
  local beats_per_second = bpm / 60
  local lines_per_second = beats_per_second * lpb
  local frames_per_line = frames_per_second / lines_per_second
  local delay_frames_per_tick = frames_per_line / 256 -- 256 delay ticks per line
  
  -- Enable delay column
  if track.delay_column_visible == false then
    track.delay_column_visible = true
  end
  
  -- Clear pattern first
  local start_line = song.selected_line_index
  for line_idx = start_line, math.min(start_line + pattern_lines - 1, pattern_lines) do
    local line = pattern:track(song.selected_track_index):line(line_idx)
    if line.note_columns[1] then
      line.note_columns[1]:clear()
    end
  end
  
  -- Find the base note for slices by looking at sample mappings
  local slice_base_note = 60 -- Default to C-4
  local sample_mappings = instrument.sample_mappings[1] -- Note layer
  
  -- Find the lowest note that has a mapping (usually the full sample)
  for note = 0, 119 do
    local mapping = sample_mappings[note + 1] -- Lua 1-based indexing
    if mapping and mapping.sample then
      -- First mapping found - slices typically start one note higher
      slice_base_note = note + 1
      print("Debug: Found mapping at note", note, "- slices start at", slice_base_note)
      break
    end
  end
  
  print("Debug: Using slice base note:", slice_base_note)
  
  -- Check if slices are equally spaced (mathematical slicing)
  local slice_count = #slice_markers - 1 -- Don't count final end marker
  local is_equal_slicing = true
  if slice_count > 1 then
    local expected_spacing = sample_frames / slice_count
    for i = 1, slice_count do
      local expected_pos = (i - 1) * expected_spacing
      local actual_pos = slice_markers[i]
      local tolerance = expected_spacing * 0.05 -- 5% tolerance
      if math.abs(actual_pos - expected_pos) > tolerance then
        is_equal_slicing = false
        break
      end
    end
  end
  
  print("Debug: Equal slicing detected:", is_equal_slicing)
  
  -- Place slices in pattern
  if is_equal_slicing and slice_count > 0 then
    -- Mathematical placement - equal spacing across pattern rows
    local rows_per_slice = pattern_lines / slice_count
    print("Debug: Using mathematical placement -", rows_per_slice, "rows per slice")
    
    for i = 1, slice_count do
      local target_line = start_line + math.floor((i - 1) * rows_per_slice)
      if target_line <= pattern_lines then
        local line = pattern:track(song.selected_track_index):line(target_line)
        local note_column = line.note_columns[1]
        
        local slice_note = slice_base_note + (i - 1)
        if slice_note >= 0 and slice_note <= 119 then
          note_column.note_value = slice_note
          note_column.instrument_value = song.selected_instrument_index - 1
          note_column.delay_value = 0 -- No delay needed for equal spacing
        end
      end
    end
  else
    -- Frame-accurate placement with delay columns for irregular slicing
    print("Debug: Using frame-accurate placement with delays")
    for i, marker_frame in ipairs(slice_markers) do
      if i <= #slice_markers - 1 then -- Don't trigger the final end marker
        -- Calculate pattern position
        local total_lines_from_start = marker_frame / frames_per_line
        local line_offset = math.floor(total_lines_from_start)
        local delay_fraction = total_lines_from_start - line_offset
        local delay_value = math.floor(delay_fraction * 256)
        
        -- Ensure we stay within pattern bounds
        local target_line = start_line + line_offset
        if target_line <= pattern_lines then
          local line = pattern:track(song.selected_track_index):line(target_line)
          local note_column = line.note_columns[1]
          
          -- Set note to trigger slice using actual keyzone mapping
          local slice_note = slice_base_note + (i - 1)
          if slice_note >= 0 and slice_note <= 119 then -- Stay within MIDI range
            note_column.note_value = slice_note
            note_column.instrument_value = song.selected_instrument_index - 1
            note_column.delay_value = math.min(255, delay_value)
          end
        end
      end
    end
  end
  
  renoise.app():show_status(string.format("Placed %d slices in pattern from line %d", 
    #slice_markers - 1, start_line))
end

function pakettiSlicesToPhrase(add_trigger_note)
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No instrument or no samples found")
    return
  end
  
  -- Always use first sample
  local sample = instrument.samples[1]
  print("Debug: Using sample:", sample.name)
  if not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("First sample has no sample data")
    return
  end
  
  local buffer = sample.sample_buffer
  local sample_frames = buffer.number_of_frames
  local sample_rate = buffer.sample_rate
  
  -- Get slice markers
  local slice_markers = {}
  
  -- Debug: Check what slice_markers contains
  print("Debug: sample.slice_markers type:", type(sample.slice_markers))
  if sample.slice_markers then
    print("Debug: slice_markers length:", #sample.slice_markers)
    for i, marker in ipairs(sample.slice_markers) do
      print("Debug: slice marker", i, ":", marker)
      table.insert(slice_markers, marker)
    end
  else
    print("Debug: sample.slice_markers is nil")
  end
  
  if #slice_markers == 0 then
    renoise.app():show_status("No slice markers found - use Sample Editor to slice first")
    return
  end
  
  -- Add final marker at end of sample if not present
  if slice_markers[#slice_markers] ~= sample_frames then
    table.insert(slice_markers, sample_frames)
  end
  
  -- Duplicate the instrument
  local new_instrument = song:insert_instrument_at(song.selected_instrument_index + 1)
  new_instrument:copy_from(instrument)
  new_instrument.name = instrument.name .. " (Phrase)"
  
  -- Create a new phrase
  local phrase = new_instrument:insert_phrase_at(1)
  phrase.name = "Sliced Break"
  
  -- Find the base note for slices by looking at sample mappings
  local slice_base_note = 60 -- Default to C-4
  local sample_mappings = new_instrument.sample_mappings[1] -- Note layer
  
  -- Find the lowest note that has a mapping (usually the full sample)
  for note = 0, 119 do
    local mapping = sample_mappings[note + 1] -- Lua 1-based indexing
    if mapping and mapping.sample then
      -- First mapping found - slices typically start one note higher
      slice_base_note = note + 1
      print("Debug: Found mapping at note", note, "- slices start at", slice_base_note)
      break
    end
  end
  
  print("Debug: Using slice base note:", slice_base_note)
  
  -- Check if slices are equally spaced (mathematical slicing)
  local slice_count = #slice_markers - 1 -- Don't count final end marker
  local is_equal_slicing = true
  if slice_count > 1 then
    local expected_spacing = sample_frames / slice_count
    for i = 1, slice_count do
      local expected_pos = (i - 1) * expected_spacing
      local actual_pos = slice_markers[i]
      local tolerance = expected_spacing * 0.05 -- 5% tolerance
      if math.abs(actual_pos - expected_pos) > tolerance then
        is_equal_slicing = false
        break
      end
    end
  end
  
  print("Debug: Equal slicing detected:", is_equal_slicing)
  
  -- Set phrase length to accommodate all slices
  local phrase_lines = math.max(16, slice_count * 2) -- At least 16 lines, or 2 per slice
  phrase.number_of_lines = phrase_lines
  
  -- Place slices in phrase
  if is_equal_slicing and slice_count > 0 then
    -- Mathematical placement - equal spacing across phrase lines
    local rows_per_slice = phrase_lines / slice_count
    print("Debug: Using mathematical placement -", rows_per_slice, "rows per slice")
    
    for i = 1, slice_count do
      local target_line = math.floor((i - 1) * rows_per_slice) + 1
      if target_line <= phrase_lines then
        local line = phrase:line(target_line)
        local note_column = line.note_columns[1]
        
        local slice_note = slice_base_note + (i - 1)
        if slice_note >= 0 and slice_note <= 119 then
          note_column.note_value = slice_note
          note_column.instrument_value = song.selected_instrument_index -- Point to new instrument
          note_column.delay_value = 0 -- No delay needed for equal spacing
        end
      end
    end
  else
    -- Frame-accurate placement with delay columns for irregular slicing
    print("Debug: Using frame-accurate placement with delays")
    local bpm = song.transport.bpm
    local lpb = song.transport.lpb
    
    -- Calculate timing conversion for phrase
    local frames_per_second = sample_rate
    local beats_per_second = bpm / 60
    local lines_per_second = beats_per_second * lpb
    local frames_per_line = frames_per_second / lines_per_second
    
    for i, marker_frame in ipairs(slice_markers) do
      if i <= #slice_markers - 1 then -- Don't trigger the final end marker
        -- Calculate phrase position
        local total_lines_from_start = marker_frame / frames_per_line
        local line_offset = math.floor(total_lines_from_start)
        local delay_fraction = total_lines_from_start - line_offset
        local delay_value = math.floor(delay_fraction * 256)
        
        -- Ensure we stay within phrase bounds
        local target_line = line_offset + 1
        if target_line <= phrase_lines then
          local line = phrase:line(target_line)
          local note_column = line.note_columns[1]
          
          -- Set note to trigger slice
          local slice_note = slice_base_note + (i - 1)
          if slice_note >= 0 and slice_note <= 119 then
            note_column.note_value = slice_note
            note_column.instrument_value = song.selected_instrument_index -- Point to new instrument
            note_column.delay_value = math.min(255, delay_value)
          end
        end
      end
    end
  end
  
  -- Select the new instrument
  song.selected_instrument_index = song.selected_instrument_index + 1
  
  -- Add trigger note to pattern if requested
  if add_trigger_note then
    local pattern = song.selected_pattern
    local track = song.selected_track
    local start_line = song.selected_line_index
    
    local line = pattern:track(song.selected_track_index):line(start_line)
    local note_column = line.note_columns[1]
    
    -- Clear existing note
    note_column:clear()
    
    -- Add phrase trigger note (typically C-4)
    note_column.note_value = 60 -- C-4
    note_column.instrument_value = song.selected_instrument_index - 1
  end
  
  renoise.app():show_status(string.format("Created phrase with %d slices in new instrument", slice_count))
end





function pakettiOldschoolSlicePitchWorkflow(use_reversed_audio)
  use_reversed_audio = use_reversed_audio == nil and true or use_reversed_audio -- Default to true for backwards compatibility
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No instrument or no samples found")
    return
  end
  
  -- Step 1: Set all slices to LoopMode Off
  for i, sample in ipairs(instrument.samples) do
    if sample.sample_buffer and sample.sample_buffer.has_sample_data then
      sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
    end
  end
  print("Debug: Set all samples to Loop Mode Off")
  
  -- Step 2: Output slices to pattern
  print("Debug: Outputting slices to pattern")
  pakettiSlicesToPattern()
  
  -- Step 3: Select track content and render to WAV file using Paketti Clean Render
  local pattern = song.selected_pattern
  local start_line = song.selected_line_index
  local pattern_lines = pattern.number_of_lines
  
  -- Select the pattern range containing the slices
  song.selection_in_pattern = {
    start_track = song.selected_track_index,
    start_line = start_line,
    end_track = song.selected_track_index,
    end_line = pattern_lines
  }
  
  print("Debug: Calling Paketti Clean Render (no save, no track)")
  pakettiCleanRenderSelection(false, true, false, false, nil) -- muteOriginal=false, justwav=true, newtrack=false, timestretch_mode=false, current_bpm=nil
  
  -- Define gap processing function  
  local function processGapsAfterRender()
    print("Debug: processGapsAfterRender started")
    
    local current_instrument = song.selected_instrument
    if not current_instrument or #current_instrument.samples == 0 then
      print("Debug: No instrument or samples found")
      renoise.app():show_status("No rendered instrument found")
      return
    end
    
    local rendered_sample = current_instrument.samples[1]
    if not rendered_sample.sample_buffer or not rendered_sample.sample_buffer.has_sample_data then
      print("Debug: Rendered sample has no data")
      renoise.app():show_status("Rendered sample has no data")
      return
    end
    
    print("Debug: Processing gaps in rendered sample:", rendered_sample.name)
    
    -- Clear any existing slice markers first
    while #rendered_sample.slice_markers > 0 do
      rendered_sample:delete_slice_marker(rendered_sample.slice_markers[1])
    end
    
    -- Detect gaps (silences) and add slice markers at END of each silence BEFORE filling
    local gaps = detectGapsInSample()
    if gaps and #gaps > 0 then
      print("Debug: Found", #gaps, "gaps - adding slice markers at end of silences (except final)")
      
      -- Add slice markers at the END of each silence region (but NOT the final one)
      for i, gap in ipairs(gaps) do
        local slice_position = gap.end_frame
        
        -- Don't create slice marker if this gap goes to the end of the sample
        if slice_position < rendered_sample.sample_buffer.number_of_frames then
          rendered_sample:insert_slice_marker(slice_position)
          print("Debug: Added slice marker at end of silence", i, "at position", slice_position)
        else
          print("Debug: Skipping final slice marker - gap goes to end of sample")
        end
      end
      
      local fill_method = use_reversed_audio and "reversed" or "copied"
      print("Debug: Now filling gaps with " .. fill_method .. " audio")
      
      -- Fill all gaps in reverse order to maintain frame positions
      for i = #gaps, 1, -1 do
        local gap = gaps[i]
        print("Debug: Filling gap", i, "from", gap.start_frame, "to", gap.end_frame)
        if use_reversed_audio then
          fillGapWithReversedAudio(gap.start_frame, gap.end_frame)
        else
          fillGapWithCopiedAudio(gap.start_frame, gap.end_frame)
        end
      end
      
      local name_suffix = use_reversed_audio and " (Gaps Filled Reversed)" or " (Gaps Filled Copied)"
      rendered_sample.name = rendered_sample.name .. name_suffix
      
      renoise.app():show_status(string.format("Oldschool slice pitch complete - filled %d gaps with %s audio, %d slices created", 
        #gaps, fill_method, #gaps))
    else
      print("Debug: No gaps detected in rendered sample")
      renoise.app():show_status("Oldschool slice pitch complete - no gaps detected")
    end
  end
  
  -- Wait for rendering to complete, then process gaps
  local check_timer = nil
  local check_count = 0
  
  check_timer = function()
    check_count = check_count + 1
    print("Debug: Timer check", check_count, "- transport running:", song.transport.playing)
    
    -- Check if rendering is complete by looking for a new instrument with rendered audio
    local current_instrument = song.selected_instrument
    if current_instrument and #current_instrument.samples > 0 then
      local sample = current_instrument.samples[1]
      if sample.name and string.find(sample.name:lower(), "rendered") then
        print("Debug: Found rendered instrument:", current_instrument.name)
        renoise.tool():remove_timer(check_timer)
        processGapsAfterRender()
        return
      end
    end
    
    -- Stop checking after 30 seconds
    if check_count > 60 then
      print("Debug: Timeout waiting for rendered instrument")
      renoise.tool():remove_timer(check_timer)
      renoise.app():show_status("Timeout waiting for rendered instrument")
    end
  end
  
  -- Start timer (check every 500ms)
  renoise.tool():add_timer(check_timer, 500)
end




-- Menu entries
renoise.tool():add_menu_entry {
  name = "Sample Editor:Paketti..:Oldschool Slice Pitch:Detect Gaps",
  invoke = pakettiOldschoolSlicePitchDetectGaps
}

renoise.tool():add_menu_entry {
  name = "Sample Editor:Paketti..:Oldschool Slice Pitch:Fill Selected Gap (Reversed)",
  invoke = pakettiOldschoolSlicePitchFillSelectedGap
}

renoise.tool():add_menu_entry {
  name = "Sample Editor:Paketti..:Oldschool Slice Pitch:Fill Selected Gap (Copied)",
  invoke = pakettiOldschoolSlicePitchFillSelectedGapCopied
}

renoise.tool():add_menu_entry {
  name = "Sample Editor:Paketti..:Oldschool Slice Pitch:Fill All Gaps (Reversed)",
  invoke = pakettiOldschoolSlicePitchFillAllGaps
}

renoise.tool():add_menu_entry {
  name = "Sample Editor:Paketti..:Oldschool Slice Pitch:Fill All Gaps (Copied)",
  invoke = pakettiOldschoolSlicePitchFillAllGapsCopied
}

renoise.tool():add_menu_entry {
  name = "Pattern Editor:Paketti..:Oldschool Slice Pitch Workflow (Reversed)",
  invoke = function() pakettiOldschoolSlicePitchWorkflow(true) end
}

renoise.tool():add_menu_entry {
  name = "Pattern Editor:Paketti..:Oldschool Slice Pitch Workflow (Copied)",
  invoke = function() pakettiOldschoolSlicePitchWorkflow(false) end
}

renoise.tool():add_menu_entry {
  name = "Pattern Editor:Paketti..:Slices to Pattern",
  invoke = pakettiSlicesToPattern
}

renoise.tool():add_menu_entry {
  name = "Sample Editor:Paketti..:Slices to Pattern", 
  invoke = pakettiSlicesToPattern
}

renoise.tool():add_menu_entry {
  name = "Pattern Editor:Paketti..:Slices to Phrase (with trigger)",
  invoke = function() pakettiSlicesToPhrase(true) end
}

renoise.tool():add_menu_entry {
  name = "Pattern Editor:Paketti..:Slices to Phrase (phrase only)",
  invoke = function() pakettiSlicesToPhrase(false) end
}

renoise.tool():add_menu_entry {
  name = "Sample Editor:Paketti..:Slices to Phrase (with trigger)",
  invoke = function() pakettiSlicesToPhrase(true) end
}

renoise.tool():add_menu_entry {
  name = "Sample Editor:Paketti..:Slices to Phrase (phrase only)",
  invoke = function() pakettiSlicesToPhrase(false) end
}

-- Key bindings
renoise.tool():add_keybinding {
  name = "Sample Editor:Paketti:Detect Gaps in Sample",
  invoke = pakettiOldschoolSlicePitchDetectGaps
}

renoise.tool():add_keybinding {
  name = "Sample Editor:Paketti:Fill Selected Gap (Reversed)",
  invoke = pakettiOldschoolSlicePitchFillSelectedGap
}

renoise.tool():add_keybinding {
  name = "Sample Editor:Paketti:Fill Selected Gap (Copied)",
  invoke = pakettiOldschoolSlicePitchFillSelectedGapCopied
}

renoise.tool():add_keybinding {
  name = "Sample Editor:Paketti:Fill All Gaps (Reversed)",
  invoke = pakettiOldschoolSlicePitchFillAllGaps
}

renoise.tool():add_keybinding {
  name = "Sample Editor:Paketti:Fill All Gaps (Copied)",
  invoke = pakettiOldschoolSlicePitchFillAllGapsCopied
}

renoise.tool():add_keybinding {
  name = "Pattern Editor:Paketti:Oldschool Slice Pitch Workflow (Reversed)",
  invoke = function() pakettiOldschoolSlicePitchWorkflow(true) end
}

renoise.tool():add_keybinding {
  name = "Pattern Editor:Paketti:Oldschool Slice Pitch Workflow (Copied)",
  invoke = function() pakettiOldschoolSlicePitchWorkflow(false) end
}

renoise.tool():add_keybinding {
  name = "Pattern Editor:Paketti:Slices to Pattern",
  invoke = pakettiSlicesToPattern
}

renoise.tool():add_keybinding {
  name = "Sample Editor:Paketti:Slices to Pattern",
  invoke = pakettiSlicesToPattern
}

renoise.tool():add_keybinding {
  name = "Pattern Editor:Paketti:Slices to Phrase (with trigger)",
  invoke = function() pakettiSlicesToPhrase(true) end
}

renoise.tool():add_keybinding {
  name = "Pattern Editor:Paketti:Slices to Phrase (phrase only)",
  invoke = function() pakettiSlicesToPhrase(false) end
}

renoise.tool():add_keybinding {
  name = "Sample Editor:Paketti:Slices to Phrase (with trigger)",
  invoke = function() pakettiSlicesToPhrase(true) end
}

renoise.tool():add_keybinding {
  name = "Sample Editor:Paketti:Slices to Phrase (phrase only)",
  invoke = function() pakettiSlicesToPhrase(false) end
} 