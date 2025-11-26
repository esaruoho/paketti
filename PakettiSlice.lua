-- Delete Slice Markers in Sample Selection
function pakettiDeleteSliceMarkersInSelection()
  local song = renoise.song()
  
  -- Check if there's a sample selected
  if not song.selected_sample then
    renoise.app():show_status("No sample selected")
    return
  end
  
  local sample = song.selected_sample
  
  -- Check if sample has a buffer
  if not sample.sample_buffer then
    renoise.app():show_status("Selected sample has no buffer")
    return
  end
  
  local buffer = sample.sample_buffer
  
  -- Check if there's a selection in the sample buffer
  if not buffer.has_sample_data then
    renoise.app():show_status("Sample buffer has no data")
    return
  end
  
  -- Get selection range
  local selection_start = buffer.selection_start
  local selection_end = buffer.selection_end
  
  -- Check if there's actually a selection
  if selection_start == 0 and selection_end == 0 then
    renoise.app():show_status("No selection in sample buffer")
    return
  end
  
  -- Check if there are slice markers
  if #sample.slice_markers == 0 then
    renoise.app():show_status("No slice markers found in sample")
    return
  end
  
  print("Selection range: " .. selection_start .. " to " .. selection_end)
  print("Found " .. #sample.slice_markers .. " slice markers")
  
  -- Count markers that will be deleted
  local markers_to_delete = {}
  for i = 1, #sample.slice_markers do
    local marker_pos = sample.slice_markers[i]
    print("Checking slice marker " .. i .. " at position " .. marker_pos .. " against selection " .. selection_start .. " to " .. selection_end)
    if marker_pos >= selection_start and marker_pos <= selection_end then
      table.insert(markers_to_delete, marker_pos)  -- Store position, not index!
      print("Slice marker at position " .. marker_pos .. " is within selection - WILL DELETE")
    else
      print("Slice marker at position " .. marker_pos .. " is outside selection - KEEPING")
    end
  end
  
  if #markers_to_delete == 0 then
    renoise.app():show_status("No slice markers found within selection range")
    return
  end
  
  print("About to delete " .. #markers_to_delete .. " slice markers")
  
  -- Delete markers by position (API expects sample position, not index!)
  for i = 1, #markers_to_delete do
    local marker_pos = markers_to_delete[i]
    print("Attempting to delete slice marker at sample position: " .. marker_pos)
    sample:delete_slice_marker(marker_pos)
    print("Successfully deleted slice marker at position: " .. marker_pos)
  end
  
  renoise.app():show_status("Deleted " .. #markers_to_delete .. " slice markers from selection")
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Delete Slice Markers in Selection",invoke=function() pakettiDeleteSliceMarkersInSelection() end}
renoise.tool():add_keybinding{name="Global:Paketti:Delete Slice Markers in Selection",invoke=function() pakettiDeleteSliceMarkersInSelection() end}
renoise.tool():add_midi_mapping{name="Paketti:Delete Slice Markers in Selection",invoke=function(message) if message:is_trigger() then pakettiDeleteSliceMarkersInSelection() end end}


renoise.tool():add_keybinding{name="Global:Paketti:Wipe&Slice&Write to Pattern",invoke = function() WipeSliceAndWrite() end}

function WipeSliceAndWrite()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local s = renoise.song()
  local currInst = s.selected_instrument_index
  local pattern = s.selected_pattern
  local num_rows = pattern.number_of_lines
  
  -- Check if the instrument has samples
  if #s.instruments[currInst].samples == 0 then
      renoise.app():show_status("No samples available in the selected instrument.")
      return
  end

  -- Set to first sample
  s.selected_sample_index = 1
  local currSamp = s.selected_sample_index
  
  -- Check if sample has data
  if not s.instruments[currInst].samples[1].sample_buffer.has_sample_data then
      renoise.app():show_status("Selected sample has no audio data.")
      return
  end
  
  print("Detected " .. num_rows .. " rows in pattern")
  
  -- Determine the number of slices to create - limit to 255 max
  local slice_count = num_rows
  if slice_count > 255 then
      slice_count = 255
      renoise.app():show_status("Pattern has " .. num_rows .. " rows, but limiting to 255 slices due to Renoise limit.")
  end
  
  -- Store original values
  local beatsync_lines = nil
  local dontsync = nil
  if s.instruments[currInst].samples[1].beat_sync_enabled then
      beatsync_lines = s.instruments[currInst].samples[1].beat_sync_lines
  else
      dontsync = true
      beatsync_lines = 0
  end
  local currentTranspose = s.selected_sample.transpose

  -- Clear existing slice markers from the first sample (wipe slices)
  for i = #s.instruments[currInst].samples[1].slice_markers, 1, -1 do
      s.instruments[currInst].samples[1]:delete_slice_marker(s.instruments[currInst].samples[1].slice_markers[i])
  end

  -- Insert new slice markers (mathematically even cuts)
  local tw = s.selected_sample.sample_buffer.number_of_frames / slice_count
  s.instruments[currInst].samples[currSamp]:insert_slice_marker(1)
  for i = 1, slice_count - 1 do
      local slice_position = tw * i
      -- Ensure slice_position is never 0
      if slice_position < 1 then
          slice_position = 1
      end
      s.instruments[currInst].samples[currSamp]:insert_slice_marker(slice_position)
  end

  -- Apply settings to all samples created by the slicing
  for i, sample in ipairs(s.instruments[currInst].samples) do
      sample.new_note_action = preferences.WipeSlices.WipeSlicesNNA.value
      sample.oneshot = preferences.WipeSlices.WipeSlicesOneShot.value
      sample.autoseek = preferences.WipeSlices.WipeSlicesAutoseek.value
      sample.mute_group = preferences.WipeSlices.WipeSlicesMuteGroup.value

      if dontsync then 
          sample.beat_sync_enabled = false
      else
          local beat_sync_mode = preferences.WipeSlices.WipeSlicesBeatSyncMode.value

          -- Validate the beat_sync_mode value
          if beat_sync_mode < 1 or beat_sync_mode > 3 then
              sample.beat_sync_enabled = false  -- Disable beat sync for invalid mode
          else
              sample.beat_sync_mode = beat_sync_mode

              -- Only set beat_sync_lines if beatsynclines is valid
              if beatsync_lines / slice_count < 1 then 
                  sample.beat_sync_lines = beatsync_lines
              else 
                  sample.beat_sync_lines = beatsync_lines / slice_count
              end

              -- Enable beat sync for this sample since dontsync is false and mode is valid
              sample.beat_sync_enabled = true
          end
      end

      sample.loop_mode = preferences.WipeSlices.WipeSlicesLoopMode.value
      local loopstyle = preferences.WipeSlices.SliceLoopMode.value
      
      if loopstyle == true then
          if i > 1 then  -- Skip original sample
              -- Get THIS sample's length
              local max_loop_start = sample.sample_buffer.number_of_frames
              -- Set loop point to middle of THIS sample
              local slice_middle = math.floor(max_loop_start / 2)
              sample.loop_start = slice_middle
          end
      end
      
      sample.loop_release = preferences.WipeSlices.WipeSlicesLoopRelease.value
      sample.transpose = currentTranspose
      sample.autofade = preferences.WipeSlices.WipeSlicesAutofade.value
      sample.interpolation_mode = 4
      sample.oversample_enabled = true
  end

  -- Ensure beat sync is enabled for the original sample
  if dontsync ~= true then 
      s.instruments[currInst].samples[1].beat_sync_lines = beatsync_lines
      s.instruments[currInst].samples[1].beat_sync_enabled = true
  end
  
  -- Get the base note from the original sample to know where slices start
  local base_note = s.instruments[currInst].samples[1].sample_mapping.base_note
  local first_slice_note = base_note + 1  -- Slices start one note above base note
  
  -- Now write the notes to the pattern - one slice per row
  local track_index = s.selected_track_index
  local track = s.tracks[track_index]
  
  -- Make sure we have at least one visible note column
  if track.visible_note_columns == 0 then
      track.visible_note_columns = 1
  end
  
  print("Writing slice notes to pattern starting from note " .. first_slice_note .. "...")
  
  local notes_written = 0
  
  -- Write each slice to its corresponding row
  for row = 1, math.min(num_rows, slice_count) do
      local pattern_line = pattern.tracks[track_index].lines[row]
      local note_column = pattern_line.note_columns[1]
      
      -- Calculate which note corresponds to this slice
      local slice_index = row - 1  -- Slices are 0-indexed
      local note_value = first_slice_note + slice_index
      
      -- Stop writing if we exceed the valid note range (B-9 = 119)
      if note_value > 119 then
          print("Reached maximum note B-9 (119), stopping at row " .. row)
          break
      end
      
      -- Write the note
      note_column.note_value = note_value
      note_column.instrument_value = currInst - 1  -- Instrument indices are 0-based
      notes_written = notes_written + 1
      
      print("Row " .. row .. ": wrote note " .. note_value .. " (slice " .. slice_index .. ")")
  end

  -- Show completion status
  local sample_name = s.selected_instrument.samples[1].name
  local num_slices = #s.instruments[currInst].samples[currSamp].slice_markers
  
  renoise.app():show_status(sample_name .. " now has " .. num_slices .. " slices and " .. notes_written .. " notes written to pattern.")
  
  print("Wipe&Slice&Write completed: " .. num_slices .. " slices created, " .. notes_written .. " notes written")
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

---
--------
-- At the very start of the file
local dialog = nil  -- Proper global dialog reference

-- Create Pattern Sequencer Patterns based on Slice Count with Automatic Slice Printing
function createPatternSequencerPatternsBasedOnSliceCount()
  local song = renoise.song()
  
  -- Check if we have a selected instrument and sample
  if not song.selected_instrument_index or song.selected_instrument_index == 0 then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No samples in selected instrument")
    return
  end
  
  if not song.selected_sample_index or song.selected_sample_index == 0 then
    renoise.app():show_status("No sample selected")
    return
  end
  
  -- Always use the first sample (original sample) to check for slices
  local original_sample = instrument.samples[1]
  if not original_sample or not original_sample.sample_buffer or not original_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("First sample has no data")
    return
  end
  
    -- Check if the original sample has slices
  if not original_sample.slice_markers or #original_sample.slice_markers == 0 then
    renoise.app():show_status("Selected sample has no slices")
    return
  end

  local slice_count = #original_sample.slice_markers
  print("Found " .. slice_count .. " slices in sample: " .. original_sample.name)
  
  -- Check for disproportionately short slices and auto-fix if needed
  local total_frames = original_sample.sample_buffer.number_of_frames
  local slice_markers = original_sample.slice_markers
  
  -- Calculate length of first slice
  local first_slice_length
  if slice_count >= 2 then
    first_slice_length = slice_markers[2] - slice_markers[1]
  else
    first_slice_length = total_frames - slice_markers[1] + 1
  end
  
  -- Check if first slice is disproportionately short (less than 1/20th of total)
  local slice_proportion = first_slice_length / total_frames
  print("First slice length: " .. first_slice_length .. " frames (" .. string.format("%.2f%%", slice_proportion * 100) .. " of total)")
  
  if slice_proportion < 0.05 then  -- Less than 5% (1/20th)
    print("First slice is very short (" .. string.format("%.2f%%", slice_proportion * 100) .. " of total)")
    print("Running detect_first_slice_and_auto_slice to fix proportions...")
    
    renoise.app():show_status("Short slice detected, auto-slicing for better proportions...")
    
    -- Run the auto-slice function to create properly proportioned slices
    detect_first_slice_and_auto_slice()
    
    -- Update our slice count after auto-slicing
    slice_count = #original_sample.slice_markers
    print("After auto-slicing: " .. slice_count .. " slices")
  end
  
  -- Find where the first slice is actually mapped
  local first_slice_note
  
  -- Check if there are slice samples (samples beyond the first one)
  if #instrument.samples > 1 then
    -- Get the first slice sample (index 2, since index 1 is the original sample)
    local first_slice_sample = instrument.samples[2]
    if first_slice_sample and first_slice_sample.sample_mapping then
      first_slice_note = first_slice_sample.sample_mapping.base_note
      print("Found first slice mapped at note: " .. first_slice_note)
    else
      -- Fallback: assume slices start one note above the original sample's base note
      local base_note = original_sample.sample_mapping.base_note
      first_slice_note = base_note + 1
      print("Fallback: assuming first slice starts at note: " .. first_slice_note .. " (base_note + 1)")
    end
  else
    -- No slice samples found, use original sample's base note + 1 as fallback
    local base_note = original_sample.sample_mapping.base_note
    first_slice_note = base_note + 1
    print("No slice samples found, using fallback note: " .. first_slice_note)
  end
  
  local track_index = song.selected_track_index  
  local current_instrument = song.selected_instrument_index - 1  -- Instrument indices are 0-based in patterns
  
  -- Get current selected sequence position to start inserting from
  local current_seq_pos = song.selected_sequence_index
  
  -- Get the current pattern length to apply to all new patterns
  local current_pattern = song.selected_pattern
  local pattern_length = current_pattern.number_of_lines
  
  print("Creating " .. slice_count .. " patterns starting from sequence position " .. (current_seq_pos + 1))
  print("Using pattern length: " .. pattern_length .. " lines")
  
  -- Create patterns for each slice
  for slice_index = 0, slice_count - 1 do
    local pattern
    local result_seq_pos
    
    if slice_index == 0 then
      -- First slice goes into the currently selected pattern
      pattern = current_pattern
      result_seq_pos = current_seq_pos
      print("Using current pattern at sequence position " .. result_seq_pos)
    else
      -- Create new patterns for remaining slices
      local insert_pos = current_seq_pos + slice_index
      
      local ok, seq_pos, pattern_idx = pcall(function()
        return song.sequencer:insert_new_pattern_at(insert_pos)
      end)
      
      if not ok then
        print("Error inserting pattern at position " .. insert_pos .. ": " .. tostring(seq_pos))
        break
      end
      
      if not seq_pos then
        print("Failed to insert pattern at position " .. insert_pos)
        break
      end
      
      result_seq_pos = seq_pos
      print("Inserted pattern at sequence position " .. result_seq_pos)
      
      -- Get the pattern - use the sequencer to find the pattern index
      local sequence_pattern_index = song.sequencer.pattern_sequence[result_seq_pos]
      if not sequence_pattern_index then
        print("Error: Could not find pattern in sequence at position " .. result_seq_pos)
        break
      end
      
      pattern = song.patterns[sequence_pattern_index]
      if not pattern then
        print("Error: Could not access pattern at index " .. sequence_pattern_index)
        break
      end
    end
    
    local slice_name = "Slice " .. string.format("%02d", slice_index + 1)
    
    -- Try to get slice name from sample if available, otherwise use default
    if slice_index < #instrument.samples - 1 then
      local slice_sample = instrument.samples[slice_index + 2]  -- +2 because first sample is original, slices start at index 2
      if slice_sample and slice_sample.name and slice_sample.name ~= "" then
        slice_name = slice_sample.name
      end
    end
    
    pattern.name = slice_name
    if slice_index > 0 then
      pattern.number_of_lines = pattern_length
    end
    print("Named pattern: " .. slice_name .. " (" .. pattern_length .. " lines)")
    
    -- Calculate which note corresponds to this slice
    local note_value = first_slice_note + slice_index
    
    -- Make sure note is within valid range
    if note_value > 119 then  -- B-9 = 119
      print("Warning: Note value " .. note_value .. " exceeds maximum (119), clamping to 119")
      note_value = 119
    end
    
    -- Check if the selected track is a sequencer track before writing
    local track = song.tracks[track_index]
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      -- Write the slice note to the first row of the selected track
      local pattern_track = pattern.tracks[track_index]
      local pattern_line = pattern_track.lines[1]
      local note_column = pattern_line.note_columns[1]
      
      -- Ensure the track has at least one visible note column
      if track.visible_note_columns == 0 then
        track.visible_note_columns = 1
      end
      
      -- Write the note
      note_column.note_value = note_value
      note_column.instrument_value = current_instrument
      
             print("Written slice " .. (slice_index + 1) .. " (note " .. note_value .. ") to pattern " .. slice_name)
     else
       print("Warning: Track " .. track_index .. " is not a sequencer track, skipping note writing for slice " .. (slice_index + 1))
     end
  end
  
  -- Show completion status
  local status_msg = string.format("Created %d patterns for %d slices from sample: %s", 
    slice_count, slice_count, original_sample.name)
  renoise.app():show_status(status_msg)
  print("Pattern creation completed: " .. slice_count .. " patterns created")
end


-- Slice to Pattern Sequencer Interface
function showSliceToPatternSequencerInterface()
  -- First, check if dialog exists and is visible
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil  -- Clear the dialog reference
    return  -- Exit the function
  end

local dialogMargin=210
  local song = renoise.song()
  local vb = renoise.ViewBuilder()
  
  -- Get current instrument info
  local current_instrument_slot = song.selected_instrument_index or 0
  local current_instrument_name = "No Instrument"
  
  if current_instrument_slot > 0 and song.selected_instrument then
    current_instrument_name = song.selected_instrument.name
    if current_instrument_name == "" then 
      current_instrument_name = "Untitled Instrument"
    end
  end
  
  -- Create UI elements
  local instrument_info_text = vb:text{
    text = string.format("Instrument %02d: %s", current_instrument_slot, current_instrument_name),
    font = "bold",
    style="strong",
    width = 300
  }
  
  local status_text = vb:text{
    text = "Ready to process slices",
    width = 300,
    align = "center"
  }
  
  -- READ current values when opening interface
  local current_bpm = song.transport.bpm
  local current_lpb = song.transport.lpb
  local current_pattern_length = song.selected_pattern.number_of_lines
  
  print("Interface opened - Current values:")
  print("- BPM: " .. current_bpm)
  print("- LPB: " .. current_lpb)
  print("- Pattern Length: " .. current_pattern_length)
  
  -- Transport and pattern value boxes with PROPER ranges
  local bpm_valuebox = vb:valuebox{
    min = 20,
    max = 999,
    width = 55,
    value = current_bpm,

    notifier = function(value)
      song.transport.bpm = value
      print("MODIFIED BPM to: " .. value)
    end
  }
  
  local lpb_valuebox = vb:valuebox{
    min = 1,
    max = 256,
    value = current_lpb,
    width = 55,
    notifier = function(value)
      song.transport.lpb = value
      print("MODIFIED LPB to: " .. value)
    end
  }
  
  local pattern_length_valuebox = vb:valuebox{
    min = 1,
    max = 512,
    value = current_pattern_length,
    width = 60,
    notifier = function(value)
      song.selected_pattern.number_of_lines = value
      print("MODIFIED pattern length to: " .. value)
    end
  }
  
  -- Autoplay checkbox
  local autoplay_checkbox = vb:checkbox{
    value = true, -- Default to autoplay enabled
    notifier = function(value)
      print("Autoplay " .. (value and "enabled" or "disabled"))
    end
  }
  
  -- Play/Stop button with dynamic text
  local play_stop_button
  play_stop_button = vb:button{
    text = song.transport.playing and "Stop" or "Play",
    width = dialogMargin,
    --height = 30,
    notifier = function()
      if song.transport.playing then
        song.transport.playing = false
        play_stop_button.text = "Play"
        print("Stopped playback")
        status_text.text = "Playback stopped"
      else
        song.transport.playing = true
        play_stop_button.text = "Stop"
        print("Started playback")
        status_text.text = "Playback started"
      end
    end
  }
  
  local prepare_button = vb:button{
    text = "Prepare Sample",
    width = dialogMargin*2,
    --height = 30,
    notifier = function()
      print("=== PREPARE SAMPLE FOR SLICING ===")
      status_text.text = "Preparing sample for slicing..."
      
      -- Check if we have a valid instrument and sample
      if not song.selected_instrument_index or song.selected_instrument_index == 0 then
        status_text.text = "Error: No instrument selected"
        return
      end
      
      local instrument = song.selected_instrument
      if not instrument or #instrument.samples == 0 then
        status_text.text = "Error: No samples in selected instrument"
        return
      end
      
                    -- Run the prepare function
       local success, error_msg = pcall(prepare_sample_for_slicing)
       
       if success then
         -- Set zoom to show entire sample (maximum zoom out)
         local sample = song.selected_sample
         if sample and sample.sample_buffer.has_sample_data then
           local buffer = sample.sample_buffer
           buffer.display_length = buffer.number_of_frames
           print("Set zoom to show entire sample (" .. buffer.number_of_frames .. " frames)")
         end
         
         status_text.text = "Sample prepared for slicing successfully!"
         print("Sample preparation completed")
         -- Start playback only if autoplay is enabled
         if autoplay_checkbox.value then
           song.transport.playing = true
           play_stop_button.text = "Stop"
           print("Started playback automatically (autoplay enabled)")
         else
           print("Playback not started (autoplay disabled)")
         end
       else
         status_text.text = "Error preparing sample: " .. tostring(error_msg)
         print("Error in sample preparation: " .. tostring(error_msg))
       end
    end
  }
  
  local create_patterns_button = vb:button{
    text = "Create Patterns",
    width = dialogMargin*2,
    --height = 30,
    notifier = function()
      print("=== CREATE PATTERN SEQUENCER PATTERNS ===")
      status_text.text = "Creating pattern sequencer patterns..."
      
             -- Run the pattern creation function
       local success, error_msg = pcall(createPatternSequencerPatternsBasedOnSliceCount)
       
       if success then
         -- Move to pattern editor after successful pattern creation
         renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
         status_text.text = "Pattern sequencer patterns created successfully!"
         print("Pattern creation completed - moved to pattern editor")
       else
         status_text.text = "Error creating patterns: " .. tostring(error_msg)
         print("Error in pattern creation: " .. tostring(error_msg))
       end
    end
  }
  
  local delete_patterns_button = vb:button{
    text = "Delete All Patterns",
    width = dialogMargin,
    --height = 30,
    notifier = function()
      print("=== DELETE ALL PATTERN SEQUENCES ===")
      status_text.text = "Deleting all pattern sequences..."
      
      -- Run the delete function
      local success, error_msg = pcall(delete_all_pattern_sequences)
      
      if success then
        status_text.text = "All pattern sequences deleted successfully!"
        print("Pattern sequence deletion completed")
      else
        status_text.text = "Error deleting pattern sequences: " .. tostring(error_msg)
        print("Error in pattern sequence deletion: " .. tostring(error_msg))
      end
    end
  }
  
  local refresh_button = vb:button{
    text = "Refresh All Values",
    width = dialogMargin*2,
    notifier = function()
      -- Update instrument info
      local new_slot = song.selected_instrument_index or 0
      local new_name = "No Instrument"
      
      if new_slot > 0 and song.selected_instrument then
        new_name = song.selected_instrument.name
        if new_name == "" then 
          new_name = "Untitled Instrument"
        end
      end
      
      instrument_info_text.text = string.format("Instrument %02d: %s", new_slot, new_name)
      
      -- Update transport and pattern values
      bpm_valuebox.value = song.transport.bpm
      lpb_valuebox.value = song.transport.lpb
      pattern_length_valuebox.value = song.selected_pattern.number_of_lines
      
      status_text.text = "All values refreshed"
      print("Refreshed: " .. instrument_info_text.text .. ", BPM: " .. song.transport.bpm .. ", LPB: " .. song.transport.lpb .. ", Pattern: " .. song.selected_pattern.number_of_lines)
    end
  }
  
  -- Create the dialog content
  local dialog_content = vb:column{
    vb:horizontal_aligner{
      mode = "center",
      vb:column{
        vb:row{
          vb:text{text = "Current Instrument", width = 120,font="bold",style="strong"},
          instrument_info_text
        },
        vb:row{
          vb:text{text = "Autoplay", width = 50, style="strong",font="bold"},
          autoplay_checkbox,
          play_stop_button
        },
        vb:row{
          vb:text{text = "BPM", width = 30,style="strong",font="bold"},
          bpm_valuebox,
          vb:text{text = "LPB", width = 30, style="strong",font="bold"},
          lpb_valuebox,
          vb:text{text = "Pattern Length", width = 90, style="strong",font="bold"},
          pattern_length_valuebox
        },
        vb:row{
          refresh_button
        }
      }
    },
    
    vb:column{
      vb:row{
        vb:button{
          text = "Wipe Slices",
          width = dialogMargin,
          --height = 30,
            notifier = function()
              print("=== WIPE SLICES ===")
              status_text.text = "Wiping slices..."
              
              local success, error_msg = pcall(wipeslices)
              
              if success then
                status_text.text = "Slices wiped successfully!"
                print("Wipe slices completed")
              else
                status_text.text = "Error wiping slices: " .. tostring(error_msg)
                print("Error in wipe slices: " .. tostring(error_msg))
              end
            end
          },
        delete_patterns_button
      },
                prepare_button,
        vb:row{
          vb:button{
            text = "Select Beat Range of 4 beats",
            width = dialogMargin,
            --height = 30,
            notifier = function()
              print("=== SELECT BEAT RANGE 1.0.0 TO 5.0.0 (4 BEATS) ===")
              status_text.text = "Selecting beat range 1.0.0 to 5.0.0..."
              
              -- Create 4-beat selection function inline
              local success, error_msg = pcall(function()
                local song, sample = validate_sample()
                if not song then return end
                
                local bpm = song.transport.bpm
                local sample_rate = sample.sample_buffer.sample_rate
                local seconds_per_beat = 60 / bpm
                local total_seconds_for_4_beats = 4 * seconds_per_beat
                local frame_position_beat_5 = math.floor(total_seconds_for_4_beats * sample_rate)
                
                local buffer = sample.sample_buffer
                buffer.selection_start = 1
                buffer.selection_end = frame_position_beat_5
                buffer.selected_channel = renoise.SampleBuffer.CHANNEL_LEFT_AND_RIGHT
                
                -- Set zoom to show selection + 10000 frames padding
                local padding = 10000
                local desired_view_length = frame_position_beat_5 + padding
                local max_view_length = buffer.number_of_frames
                buffer.display_length = math.min(desired_view_length, max_view_length)
                
                print("Selected 1.0.0 to 5.0.0 (" .. frame_position_beat_5 .. " frames, " .. total_seconds_for_4_beats .. "s)")
                print("Set zoom: showing " .. buffer.display_length .. " frames (selection + " .. padding .. " padding)")
                focus_sample_editor()
              end)
              
              if success then
                status_text.text = "Beat range 1.0.0 to 5.0.0 (4 beats) selected successfully!"
                print("4-beat range selection completed")
              else
                status_text.text = "Error selecting 4-beat range: " .. tostring(error_msg)
                print("Error in 4-beat range selection: " .. tostring(error_msg))
              end
            end
          },
          vb:button{
            text = "Auto-Slice by 4 beats",
            width = dialogMargin,
            --height = 30,
            notifier = function()
              print("=== AUTO-SLICE EVERY 4 BEATS ===")
              status_text.text = "Auto-slicing every 4 beats..."
              
              -- Create 4-beat auto-slice function inline
              local success, error_msg = pcall(function()
                local song, sample = validate_sample()
                if not song then return end
                
                local bpm = song.transport.bpm
                local sample_rate = sample.sample_buffer.sample_rate
                local seconds_per_beat = 60 / bpm
                local total_seconds_for_4_beats = 4 * seconds_per_beat
                local frame_position_beat_5 = math.floor(total_seconds_for_4_beats * sample_rate)
                
                local buffer = sample.sample_buffer
                buffer.selection_start = 1
                buffer.selection_end = frame_position_beat_5
                buffer.selected_channel = renoise.SampleBuffer.CHANNEL_LEFT_AND_RIGHT
                
                focus_sample_editor()
                pakettiSlicesFromSelection()
                
                print("Auto-sliced every 4 beats (" .. frame_position_beat_5 .. " frames, " .. total_seconds_for_4_beats .. "s)")
              end)
              
              if success then
                status_text.text = "Auto-sliced every 4 beats successfully!"
                print("Auto-slice every 4 beats completed")
              else
                status_text.text = "Error auto-slicing 4 beats: " .. tostring(error_msg)
                print("Error in 4-beat auto-slice: " .. tostring(error_msg))
              end
            end
          }
        },
        vb:row{
          vb:button{
            text = "Select Beat Range of 8 beats",
            width = dialogMargin,
            --height = 30,
            notifier = function()
              print("=== SELECT BEAT RANGE 1.0.0 TO 9.0.0 (8 BEATS) ===")
              status_text.text = "Selecting beat range 1.0.0 to 9.0.0..."
              
              local success, error_msg = pcall(function()
                select_beat_range_for_verification()
                
                -- Add zoom functionality for 8-beat selection
                local song, sample = validate_sample()
                if song then
                  local bpm = song.transport.bpm
                  local sample_rate = sample.sample_buffer.sample_rate
                  local seconds_per_beat = 60 / bpm
                  local total_seconds_for_8_beats = 8 * seconds_per_beat
                  local frame_position_beat_9 = math.floor(total_seconds_for_8_beats * sample_rate)
                  
                  local buffer = sample.sample_buffer
                  local padding = 10000
                  local desired_view_length = frame_position_beat_9 + padding
                  local max_view_length = buffer.number_of_frames
                  buffer.display_length = math.min(desired_view_length, max_view_length)
                  
                  print("Set zoom: showing " .. buffer.display_length .. " frames (8-beat selection + " .. padding .. " padding)")
                end
              end)
              
              if success then
                status_text.text = "Beat range 1.0.0 to 9.0.0 (8 beats) selected successfully!"
                print("8-beat range selection completed")
              else
                status_text.text = "Error selecting 8-beat range: " .. tostring(error_msg)
                print("Error in 8-beat range selection: " .. tostring(error_msg))
              end
            end
          },
          vb:button{
            text = "Auto-Slice by 8 beats",
            width = dialogMargin,
            --height = 30,
            notifier = function()
              print("=== AUTO-SLICE EVERY 8 BEATS ===")
              status_text.text = "Auto-slicing every 8 beats..."
              
              local success, error_msg = pcall(auto_slice_every_8_beats)
              
              if success then
                status_text.text = "Auto-sliced every 8 beats successfully!"
                print("Auto-slice every 8 beats completed")
              else
                status_text.text = "Error auto-slicing 8 beats: " .. tostring(error_msg)
                print("Error in 8-beat auto-slice: " .. tostring(error_msg))
              end
            end
          }
        },
        vb:row{
          vb:button{
            text = "BPM-Based Slice Dialog",
            width = dialogMargin,
            notifier = function()
              print("=== OPENING BPM-BASED SLICE DIALOG ===")
              status_text.text = "Opening BPM-based slice dialog..."
              
              showBPMBasedSliceDialog()
              status_text.text = "BPM-based slice dialog opened"
            end
          },
          vb:button{
            text = "Quick: Slice at Song BPM (4 beats)",
            width = dialogMargin,
            notifier = function()
              print("=== QUICK BPM SLICE AT SONG BPM (4 BEATS) ===")
              local song_bpm = song.transport.bpm
              status_text.text = "Slicing at " .. song_bpm .. " BPM, 4 beats per slice..."
              
              local success, error_msg = pcall(pakettiBPMBasedSlice4Beats, song_bpm)
              
              if success then
                status_text.text = "Sliced at " .. song_bpm .. " BPM, 4 beats per slice"
                print("Quick BPM slice completed")
              else
                status_text.text = "Error: " .. tostring(error_msg)
                print("Error in quick BPM slice: " .. tostring(error_msg))
              end
            end
          }
        },
        create_patterns_button
    },
    
    vb:horizontal_aligner{
      mode = "center",
      vb:column{
        vb:horizontal_aligner{
          mode = "center",
          vb:text{text = "Status:", font = "bold"},
        },
        vb:horizontal_aligner{
          mode = "center",
          status_text
        }
      }
    },

  }
  
  -- Show dialog and store reference
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Slice to Pattern Sequencer Dialog", dialog_content, keyhandler)
end

renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti Gadgets:Slice to Pattern Sequencer Dialog...",invoke = showSliceToPatternSequencerInterface}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Slice to Pattern Sequencer Dialog...",invoke = showSliceToPatternSequencerInterface}

renoise.tool():add_keybinding{name="Global:Paketti:Create Pattern Sequencer Patterns based on Slice Count with Automatic Slice Printing",invoke = createPatternSequencerPatternsBasedOnSliceCount}
renoise.tool():add_keybinding{name="Global:Paketti:Slice to Pattern Sequencer Dialog...",invoke = showSliceToPatternSequencerInterface}


-- BPM-Based Slicing Functions
-- These functions slice samples based on a specified BPM, independent of song BPM

function validate_sample()
    local song = renoise.song()
    local sample = song.selected_sample
    if not sample or not sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample buffer empty")
        return false
    end
    return song, sample
end

-- Core BPM-based slicing function
function pakettiBPMBasedSlice(sample_bpm, beats_per_slice)
    -- Temporarily disable AutoSamplify monitoring to prevent interference
    local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
    
    print("=== BPM Based Slice: " .. sample_bpm .. " BPM, " .. beats_per_slice .. " beats per slice ===")
    
    local song, sample = validate_sample()
    if not song then return end
    
    -- Always target the first sample (original sample) for slicing, not slices
    local instrument = song.selected_instrument
    if not instrument or #instrument.samples == 0 then
        renoise.app():show_status("No samples in selected instrument")
        return
    end
    
    local original_selected_index = song.selected_sample_index
    local first_sample = instrument.samples[1]
    
    -- If we're not on the first sample, switch to it and notify user
    if song.selected_sample_index ~= 1 then
        song.selected_sample_index = 1
        sample = song.selected_sample  -- Update sample reference
        print("Switched from sample " .. original_selected_index .. " to original sample (sample 1) for slicing")
        renoise.app():show_status("Auto-switched to original sample for slicing")
    end
    
    -- Verify the first sample has data
    if not first_sample.sample_buffer or not first_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("Original sample has no data")
        return
    end
    
    local sample_rate = sample.sample_buffer.sample_rate
    local seconds_per_beat = 60 / sample_bpm
    local seconds_per_slice = beats_per_slice * seconds_per_beat
    local frames_per_slice = math.floor(seconds_per_slice * sample_rate)
    
    print("Sample rate: " .. sample_rate .. " Hz")
    print("Seconds per beat at " .. sample_bpm .. " BPM: " .. seconds_per_beat)
    print("Seconds per " .. beats_per_slice .. "-beat slice: " .. seconds_per_slice)
    print("Frames per slice: " .. frames_per_slice)
    
    -- Calculate how many complete slices we can fit
    local total_frames = sample.sample_buffer.number_of_frames
    local num_slices = math.floor(total_frames / frames_per_slice)
    
    print("Total frames: " .. total_frames)
    print("Number of complete " .. beats_per_slice .. "-beat slices: " .. num_slices)
    
    if num_slices < 1 then
        renoise.app():show_status("Sample too short for " .. beats_per_slice .. " beats at " .. sample_bpm .. " BPM")
        return
    end
    
    -- Clear existing slice markers
    while #sample.slice_markers > 0 do
        sample:delete_slice_marker(sample.slice_markers[1])
    end
    
    print("Cleared existing slice markers")
    
    -- Create new slice markers - always start with frame 1
    sample:insert_slice_marker(1)
    print("Created slice marker 1 at frame 1 (start)")
    
    -- Create remaining slice markers
    for i = 1, num_slices - 1 do
        local slice_position = i * frames_per_slice
        -- Ensure slice_position is never 0
        if slice_position < 1 then
            slice_position = 1
        end
        if slice_position < total_frames then
            sample:insert_slice_marker(slice_position)
            print("Created slice marker " .. (i + 1) .. " at frame " .. slice_position)
        end
    end
    
    -- Apply WipeSlices preferences to all samples in the instrument
    local currentTranspose = sample.transpose
    
    -- Store original beat sync values
    local beatsync_lines = nil
    local dontsync = nil
    if sample.beat_sync_enabled then
        beatsync_lines = sample.beat_sync_lines
    else
        dontsync = true
        beatsync_lines = 0
    end
    
    for i, sample_obj in ipairs(instrument.samples) do
        sample_obj.new_note_action = preferences.WipeSlices.WipeSlicesNNA.value
        sample_obj.oneshot = preferences.WipeSlices.WipeSlicesOneShot.value
        sample_obj.autoseek = preferences.WipeSlices.WipeSlicesAutoseek.value
        sample_obj.mute_group = preferences.WipeSlices.WipeSlicesMuteGroup.value
        sample_obj.loop_mode = preferences.WipeSlices.WipeSlicesLoopMode.value
        sample_obj.loop_release = preferences.WipeSlices.WipeSlicesLoopRelease.value
        sample_obj.transpose = currentTranspose
        sample_obj.autofade = preferences.WipeSlices.WipeSlicesAutofade.value
        sample_obj.interpolation_mode = 4
        sample_obj.oversample_enabled = true
        
        -- Apply beat sync settings
        if dontsync then 
            sample_obj.beat_sync_enabled = false
        else
            local beat_sync_mode = preferences.WipeSlices.WipeSlicesBeatSyncMode.value
            
            -- Validate the beat_sync_mode value
            if beat_sync_mode < 1 or beat_sync_mode > 3 then
                sample_obj.beat_sync_enabled = false  -- Disable beat sync for invalid mode
            else
                sample_obj.beat_sync_mode = beat_sync_mode
                
                -- Calculate beat sync lines for this slice
                local slice_beatsync_lines = beatsync_lines / num_slices
                if slice_beatsync_lines < 1 then 
                    sample_obj.beat_sync_lines = beatsync_lines
                else 
                    sample_obj.beat_sync_lines = slice_beatsync_lines
                end
                
                -- Enable beat sync for this sample
                sample_obj.beat_sync_enabled = true
            end
        end
        
        -- Apply slice loop mode if enabled and not the original sample
        local loopstyle = preferences.WipeSlices.SliceLoopMode.value
        if loopstyle == true and i > 1 then
            local max_loop_start = sample_obj.sample_buffer.number_of_frames
            local slice_middle = math.floor(max_loop_start / 2)
            sample_obj.loop_start = slice_middle
        end
    end
    
    renoise.app():show_status("Sliced to " .. beats_per_slice .. " beats per slice at " .. sample_bpm .. " BPM (" .. #sample.slice_markers .. " slices)")
    focus_sample_editor()
    
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Wrapper functions for common beat counts
function pakettiBPMBasedSlice1Beat(sample_bpm)
    pakettiBPMBasedSlice(sample_bpm, 1)
end

function pakettiBPMBasedSlice2Beats(sample_bpm)
    pakettiBPMBasedSlice(sample_bpm, 2)
end

function pakettiBPMBasedSlice3Beats(sample_bpm)
    pakettiBPMBasedSlice(sample_bpm, 3)
end

function pakettiBPMBasedSlice4Beats(sample_bpm)
    pakettiBPMBasedSlice(sample_bpm, 4)
end

function pakettiBPMBasedSlice6Beats(sample_bpm)
    pakettiBPMBasedSlice(sample_bpm, 6)
end

function pakettiBPMBasedSlice8Beats(sample_bpm)
    pakettiBPMBasedSlice(sample_bpm, 8)
end

function pakettiBPMBasedSliceHalfBeat(sample_bpm)
    pakettiBPMBasedSlice(sample_bpm, 0.5)
end

function pakettiBPMBasedSliceQuarterBeat(sample_bpm)
    pakettiBPMBasedSlice(sample_bpm, 0.25)
end

-- Focus sample editor utility
function focus_sample_editor()
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

-- Set all slices to End-Half loop mode (loop the end half of each slice)
function pakettiSetAllSlicesToEndHalfLoop()
    print("=== Setting All Slices to End-Half Loop Mode ===")
    
    local song, sample = validate_sample()
    if not song then return end
    
    local instrument = song.selected_instrument
    if not instrument or #instrument.samples == 0 then
        renoise.app():show_status("No samples in selected instrument")
        return
    end
    
    -- Get the first sample to check for slices
    local first_sample = instrument.samples[1]
    if not first_sample.slice_markers or #first_sample.slice_markers == 0 then
        renoise.app():show_status("No slices found in sample")
        return
    end
    
    local slices_processed = 0
    
    -- Apply end-half loop to all slice samples (skip original sample at index 1)
    for i = 2, #instrument.samples do
        local slice_sample = instrument.samples[i]
        if slice_sample and slice_sample.sample_buffer and slice_sample.sample_buffer.has_sample_data then
            local buffer = slice_sample.sample_buffer
            local total_frames = buffer.number_of_frames
            
            -- Only set loop mode to forward if currently OFF, otherwise preserve existing mode
            if slice_sample.loop_mode == renoise.Sample.LOOP_MODE_OFF then
                slice_sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
                print("Set slice " .. i .. " from OFF to Forward mode")
            else
                print("Preserved existing loop mode for slice " .. i)
            end
            
            -- Always set loop points to end half of slice
            local middle_frame = math.floor(total_frames / 2)
            slice_sample.loop_start = middle_frame
            slice_sample.loop_end = total_frames
            
            slices_processed = slices_processed + 1
            print("Set slice " .. i .. " to end-half loop points: frames " .. middle_frame .. " to " .. total_frames)
        end
    end
    
    renoise.app():show_status("Set " .. slices_processed .. " slices to End-Half loop points")
    print("End-Half loop points processing completed: " .. slices_processed .. " slices processed")
end

-- Set all slices to Full loop mode (loop the entire slice)
function pakettiSetAllSlicesToFullLoop()
    print("=== Setting All Slices to Full Loop Mode ===")
    
    local song, sample = validate_sample()
    if not song then return end
    
    local instrument = song.selected_instrument
    if not instrument or #instrument.samples == 0 then
        renoise.app():show_status("No samples in selected instrument")
        return
    end
    
    -- Get the first sample to check for slices
    local first_sample = instrument.samples[1]
    if not first_sample.slice_markers or #first_sample.slice_markers == 0 then
        renoise.app():show_status("No slices found in sample")
        return
    end
    
    local slices_processed = 0
    
    -- Apply full loop to all slice samples (skip original sample at index 1)
    for i = 2, #instrument.samples do
        local slice_sample = instrument.samples[i]
        if slice_sample and slice_sample.sample_buffer and slice_sample.sample_buffer.has_sample_data then
            local buffer = slice_sample.sample_buffer
            local total_frames = buffer.number_of_frames
            
            -- Only set loop mode to forward if currently OFF, otherwise preserve existing mode
            if slice_sample.loop_mode == renoise.Sample.LOOP_MODE_OFF then
                slice_sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
                print("Set slice " .. i .. " from OFF to Forward mode")
            else
                print("Preserved existing loop mode for slice " .. i)
            end
            
            -- Always set loop points to full slice
            slice_sample.loop_start = 1
            slice_sample.loop_end = total_frames
            
            slices_processed = slices_processed + 1
            print("Set slice " .. i .. " to full loop points: frames 1 to " .. total_frames)
        end
    end
    
    renoise.app():show_status("Set " .. slices_processed .. " slices to Full loop points")
    print("Full loop points processing completed: " .. slices_processed .. " slices processed")
end

-- Set all slices to Loop Off mode (no looping)
function pakettiSetAllSlicesToLoopOff()
    print("=== Setting All Slices to Loop Off Mode ===")
    
    local song, sample = validate_sample()
    if not song then return end
    
    local instrument = song.selected_instrument
    if not instrument or #instrument.samples == 0 then
        renoise.app():show_status("No samples in selected instrument")
        return
    end
    
    -- Get the first sample to check for slices
    local first_sample = instrument.samples[1]
    if not first_sample.slice_markers or #first_sample.slice_markers == 0 then
        renoise.app():show_status("No slices found in sample")
        return
    end
    
    local slices_processed = 0
    
    -- Apply loop off to all slice samples (skip original sample at index 1)
    for i = 2, #instrument.samples do
        local slice_sample = instrument.samples[i]
        if slice_sample and slice_sample.sample_buffer and slice_sample.sample_buffer.has_sample_data then
            -- Set loop mode to off
            slice_sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
            
            slices_processed = slices_processed + 1
            print("Set slice " .. i .. " to loop off mode")
        end
    end
    
    renoise.app():show_status("Set " .. slices_processed .. " slices to Loop Off mode")
    print("Loop Off processing completed: " .. slices_processed .. " slices processed")
end

-- Set all slices to Forward loop mode (loop entire slice forward)
function pakettiSetAllSlicesToForwardLoop()
    print("=== Setting All Slices to Forward Loop Mode ===")
    
    local song, sample = validate_sample()
    if not song then return end
    
    local instrument = song.selected_instrument
    if not instrument or #instrument.samples == 0 then
        renoise.app():show_status("No samples in selected instrument")
        return
    end
    
    -- Get the first sample to check for slices
    local first_sample = instrument.samples[1]
    if not first_sample.slice_markers or #first_sample.slice_markers == 0 then
        renoise.app():show_status("No slices found in sample")
        return
    end
    
    local slices_processed = 0
    
    -- Apply forward loop to all slice samples (skip original sample at index 1)
    for i = 2, #instrument.samples do
        local slice_sample = instrument.samples[i]
        if slice_sample and slice_sample.sample_buffer and slice_sample.sample_buffer.has_sample_data then
            -- Only set loop mode to forward, preserve existing loop points
            slice_sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
            
            slices_processed = slices_processed + 1
            print("Set slice " .. i .. " to forward loop mode (preserving existing loop points)")
        end
    end
    
    renoise.app():show_status("Set " .. slices_processed .. " slices to Forward loop mode")
    print("Forward loop processing completed: " .. slices_processed .. " slices processed")
end

-- Set all slices to Reverse loop mode (loop entire slice in reverse)
function pakettiSetAllSlicesToReverseLoop()
    print("=== Setting All Slices to Reverse Loop Mode ===")
    
    local song, sample = validate_sample()
    if not song then return end
    
    local instrument = song.selected_instrument
    if not instrument or #instrument.samples == 0 then
        renoise.app():show_status("No samples in selected instrument")
        return
    end
    
    -- Get the first sample to check for slices
    local first_sample = instrument.samples[1]
    if not first_sample.slice_markers or #first_sample.slice_markers == 0 then
        renoise.app():show_status("No slices found in sample")
        return
    end
    
    local slices_processed = 0
    
    -- Apply reverse loop to all slice samples (skip original sample at index 1)
    for i = 2, #instrument.samples do
        local slice_sample = instrument.samples[i]
        if slice_sample and slice_sample.sample_buffer and slice_sample.sample_buffer.has_sample_data then
            -- Only set loop mode to reverse, preserve existing loop points
            slice_sample.loop_mode = renoise.Sample.LOOP_MODE_REVERSE
            
            slices_processed = slices_processed + 1
            print("Set slice " .. i .. " to reverse loop mode (preserving existing loop points)")
        end
    end
    
    renoise.app():show_status("Set " .. slices_processed .. " slices to Reverse loop mode")
    print("Reverse loop processing completed: " .. slices_processed .. " slices processed")
end

-- Set all slices to PingPong loop mode (bounce back and forth within slice)
function pakettiSetAllSlicesToPingPongLoop()
    print("=== Setting All Slices to PingPong Loop Mode ===")
    
    local song, sample = validate_sample()
    if not song then return end
    
    local instrument = song.selected_instrument
    if not instrument or #instrument.samples == 0 then
        renoise.app():show_status("No samples in selected instrument")
        return
    end
    
    -- Get the first sample to check for slices
    local first_sample = instrument.samples[1]
    if not first_sample.slice_markers or #first_sample.slice_markers == 0 then
        renoise.app():show_status("No slices found in sample")
        return
    end
    
    local slices_processed = 0
    
    -- Apply pingpong loop to all slice samples (skip original sample at index 1)
    for i = 2, #instrument.samples do
        local slice_sample = instrument.samples[i]
        if slice_sample and slice_sample.sample_buffer and slice_sample.sample_buffer.has_sample_data then
            -- Only set loop mode to pingpong, preserve existing loop points
            slice_sample.loop_mode = renoise.Sample.LOOP_MODE_PING_PONG
            
            slices_processed = slices_processed + 1
            print("Set slice " .. i .. " to pingpong loop mode (preserving existing loop points)")
        end
    end
    
    renoise.app():show_status("Set " .. slices_processed .. " slices to PingPong loop mode")
    print("PingPong loop processing completed: " .. slices_processed .. " slices processed")
end

-- BPM-Based Slice Dialog
local bpm_dialog = nil

function showBPMBasedSliceDialog()
    -- Toggle dialog if already open
    if bpm_dialog and bpm_dialog.visible then
        bpm_dialog:close()
        bpm_dialog = nil
        return
    end

    local dialogMargin = 175
    local song = renoise.song()
    local vb = renoise.ViewBuilder()
    
    -- Default values
    local default_bpm = song.transport.bpm
    local default_beats = 4
    
    -- Get current instrument info  
    local current_instrument_slot = song.selected_instrument_index or 0
    local current_instrument_name = "No Instrument"
    
    if current_instrument_slot > 0 and song.selected_instrument then
        current_instrument_name = song.selected_instrument.name
        if current_instrument_name == "" then 
            current_instrument_name = "Untitled Instrument"
        end
    end
    
    -- UI elements
    local instrument_info_text = vb:text{
        text = string.format("Instrument %02d: %s", current_instrument_slot, current_instrument_name),
        font = "bold",
        style = "strong",
        width = 400
    }
    
    local status_text = vb:text{
        text = "Set sample BPM and slice timing",
        width = 400,
        align = "center"
    }
    
    -- BPM input
    local bpm_valuebox = vb:valuebox{
        min = 20,
        max = 999,
        value = default_bpm,
        width = 80,
        tostring = function(value)
            return string.format("%.2f", value)
        end,
        tonumber = function(str)
            return tonumber(str)
        end
    }
    
    -- Beats per slice input
    local beats_valuebox = vb:valuebox{
        min = 0.125,
        max = 16,
        value = default_beats,
        width = 60
    }
    
    -- Preset buttons for common beat values
    local preset_buttons = vb:row{
        vb:button{
            text = "1/6",
            width = 40,
            notifier = function()
                beats_valuebox.value = 1/6
            end
        },
        vb:button{
            text = "1/4",
            width = 40,
            notifier = function()
                beats_valuebox.value = 0.25
            end
        },
        vb:button{
            text = "1/3",
            width = 40,
            notifier = function()
                beats_valuebox.value = 1/3
            end
        },
        vb:button{
            text = "1/2", 
            width = 40,
            notifier = function()
                beats_valuebox.value = 0.5
            end
        },
        vb:button{
            text = "1",
            width = 40,
            notifier = function()
                beats_valuebox.value = 1
            end
        },
        vb:button{
            text = "2",
            width = 40,
            notifier = function()
                beats_valuebox.value = 2
            end
        },
        vb:button{
            text = "3",
            width = 40,
            notifier = function()
                beats_valuebox.value = 3
            end
        },
        vb:button{
            text = "4",
            width = 40,
            notifier = function()
                beats_valuebox.value = 4
            end
        },
        vb:button{
            text = "6",
            width = 40,
            notifier = function()
                beats_valuebox.value = 6
            end
        },
        vb:button{
            text = "8",
            width = 40,
            notifier = function()
                beats_valuebox.value = 8
            end
        }
    }
    
    -- Slice button
    local slice_button = vb:button{
        text = "Slice Sample",
        width = dialogMargin,
        notifier = function()
            local sample_bpm = bpm_valuebox.value
            local beats_per_slice = beats_valuebox.value
            
            print("=== BPM-Based Slicing from Dialog ===")
            status_text.text = "Slicing sample..."
            
            local success, error_msg = pcall(pakettiBPMBasedSlice, sample_bpm, beats_per_slice)
            
            if success then
                status_text.text = string.format("Sliced at %g BPM, %g beats per slice", sample_bpm, beats_per_slice)
                print("BPM-based slicing completed successfully")
            else
                status_text.text = "Error: " .. tostring(error_msg)
                print("Error in BPM-based slicing: " .. tostring(error_msg))
            end
        end
    }
    
    -- Create patterns button
    local create_patterns_button = vb:button{
        text = "Create Pattern Sequences",
        width = dialogMargin,
        notifier = function()
            status_text.text = "Creating pattern sequences..."
            
            local success, error_msg = pcall(createPatternSequencerPatternsBasedOnSliceCount)
            
            if success then
                renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
                status_text.text = "Pattern sequences created successfully!"
                print("Pattern creation completed from BPM dialog")
            else
                status_text.text = "Error creating patterns: " .. tostring(error_msg)
                print("Error in pattern creation: " .. tostring(error_msg))
            end
        end
    }
    
    -- Loop mode buttons
    local loop_off_button = vb:button{
        text = "Loop Off",
        width = dialogMargin / 2,
        notifier = function()
            status_text.text = "Setting all slices to loop off..."
            
            local success, error_msg = pcall(pakettiSetAllSlicesToLoopOff)
            
            if success then
                status_text.text = "All slices set to Loop Off mode"
                print("Loop Off mode set successfully")
            else
                status_text.text = "Error setting loop off: " .. tostring(error_msg)
                print("Error setting loop off: " .. tostring(error_msg))
            end
        end
    }
    
    local forward_loop_button = vb:button{
        text = "Forward Loop",
        width = dialogMargin / 2,
        notifier = function()
            status_text.text = "Setting all slices to forward loop..."
            
            local success, error_msg = pcall(pakettiSetAllSlicesToForwardLoop)
            
            if success then
                status_text.text = "All slices set to Forward loop mode"
                print("Forward loop mode set successfully")
            else
                status_text.text = "Error setting forward loop: " .. tostring(error_msg)
                print("Error setting forward loop: " .. tostring(error_msg))
            end
        end
    }
    
    local reverse_loop_button = vb:button{
        text = "Reverse Loop",
        width = dialogMargin / 2,
        notifier = function()
            status_text.text = "Setting all slices to reverse loop..."
            
            local success, error_msg = pcall(pakettiSetAllSlicesToReverseLoop)
            
            if success then
                status_text.text = "All slices set to Reverse loop mode"
                print("Reverse loop mode set successfully")
            else
                status_text.text = "Error setting reverse loop: " .. tostring(error_msg)
                print("Error setting reverse loop: " .. tostring(error_msg))
            end
        end
    }
    
    local pingpong_loop_button = vb:button{
        text = "PingPong Loop",
        width = dialogMargin / 2,
        notifier = function()
            status_text.text = "Setting all slices to pingpong loop..."
            
            local success, error_msg = pcall(pakettiSetAllSlicesToPingPongLoop)
            
            if success then
                status_text.text = "All slices set to PingPong loop mode"
                print("PingPong loop mode set successfully")
            else
                status_text.text = "Error setting pingpong loop: " .. tostring(error_msg)
                print("Error setting pingpong loop: " .. tostring(error_msg))
            end
        end
    }
    
    local end_half_loop_button = vb:button{
        text = "End-Half Loop",
        width = dialogMargin / 2,
        notifier = function()
            status_text.text = "Setting all slices to end-half loop..."
            
            local success, error_msg = pcall(pakettiSetAllSlicesToEndHalfLoop)
            
            if success then
                status_text.text = "All slices set to End-Half loop points"
                print("End-Half loop points set successfully")
            else
                status_text.text = "Error setting end-half loop: " .. tostring(error_msg)
                print("Error setting end-half loop: " .. tostring(error_msg))
            end
        end
    }
    
    local full_loop_button = vb:button{
        text = "Full Loop",
        width = dialogMargin / 2,
        notifier = function()
            status_text.text = "Setting all slices to full loop..."
            
            local success, error_msg = pcall(pakettiSetAllSlicesToFullLoop)
            
            if success then
                status_text.text = "All slices set to Full loop points"
                print("Full loop points set successfully")
            else
                status_text.text = "Error setting full loop: " .. tostring(error_msg)
                print("Error setting full loop: " .. tostring(error_msg))
            end
        end
    }
    
    -- Refresh button
    local refresh_button = vb:button{
        text = "Refresh Info",
        width = dialogMargin / 3,
        notifier = function()
            local new_slot = song.selected_instrument_index or 0
            local new_name = "No Instrument"
            
            if new_slot > 0 and song.selected_instrument then
                new_name = song.selected_instrument.name
                if new_name == "" then 
                    new_name = "Untitled Instrument"
                end
            end
            
            instrument_info_text.text = string.format("Instrument %02d: %s", new_slot, new_name)
            bpm_valuebox.value = song.transport.bpm
            
            status_text.text = "Info refreshed"
        end
    }
    
    -- Copy song BPM button
    local copy_bpm_button = vb:button{
        text = "Use Song BPM",
        width = dialogMargin / 3,
        notifier = function()
            bpm_valuebox.value = song.transport.bpm
            status_text.text = "Set to song BPM: " .. song.transport.bpm
        end
    }
    
    -- Intelligent BPM Detection button
    local intelligent_bpm_button = vb:button{
        text = "Intelligent BPM Detection",
        width = dialogMargin / 3 * 2,
        notifier = function()
            if not song.selected_sample or not song.selected_sample.sample_buffer or not song.selected_sample.sample_buffer.has_sample_data then
                status_text.text = "No sample selected or sample has no data"
                return
            end
            
            local sample_buffer = song.selected_sample.sample_buffer
            local detected_bpm, beat_count = pakettiBPMDetectFromSample(sample_buffer.number_of_frames, sample_buffer.sample_rate)
            bpm_valuebox.value = detected_bpm
            status_text.text = string.format("Intelligent Detection: %.1f BPM (%d beats)", detected_bpm, beat_count)
            print("Intelligent BPM Detection: " .. detected_bpm .. " BPM, " .. beat_count .. " beats")
        end
    }
    
    -- Dialog content
    local dialog_content = vb:column{
        vb:horizontal_aligner{
            mode = "center",
            vb:column{
                vb:row{
                    vb:text{text = "Current Instrument", width = 120, font = "bold", style = "strong"},
                    instrument_info_text
                },
                vb:row{
                    refresh_button,
                    copy_bpm_button,
                    intelligent_bpm_button
                }
            }
        },
        
        vb:column{
            vb:row{
                vb:text{text = "Sample BPM", width = 80, font = "bold", style = "strong"},
                bpm_valuebox,
                vb:text{text = "Beats per Slice", width = 100, font = "bold", style = "strong"},
                beats_valuebox
            },
            vb:row{
                vb:text{text = "Presets", width = 60, font = "bold", style = "strong"},
                preset_buttons
            },
            slice_button,
            create_patterns_button,
            vb:text{text = "Loop Modes for All Slices", font = "bold", style = "strong"},
            vb:row{
                loop_off_button,
                forward_loop_button
            },
            vb:row{
                reverse_loop_button,
                pingpong_loop_button
            },
            vb:row{
                end_half_loop_button,
                full_loop_button
            }
        },
        
        vb:horizontal_aligner{
            mode = "center",
            vb:column{
                vb:text{text = "Status", font = "bold", style = "strong"},
                status_text
            }
        }
    }
    
    -- Show dialog
    local keyhandler = create_keyhandler_for_dialog(
        function() return bpm_dialog end,
        function(value) bpm_dialog = value end
    )
    bpm_dialog = renoise.app():show_custom_dialog("BPM-Based Sample Slicer", dialog_content, keyhandler)
end

-- Keybindings and Menu Entries for BPM-Based Slicing
renoise.tool():add_keybinding{name="Global:Paketti:BPM-Based Sample Slicer Dialog...",invoke = showBPMBasedSliceDialog}
renoise.tool():add_midi_mapping{name="Paketti:BPM-Based Sample Slicer Dialog",invoke=function(message) if message:is_trigger() then showBPMBasedSliceDialog() end end}

--------------------------------------------------------------------------------
-- Real-Time Slice Marker Creation During Playback
--------------------------------------------------------------------------------

-- Global state for playback monitoring (MUST be global so F8 can stop it from PakettiImpulseTracker.lua)
realtime_slice_state = {
  is_monitoring = false,
  start_time = 0,
  sample_rate = 44100,
  instrument_index = 0,
  sample_index = 0,
  beat_sync_enabled = false,
  beat_sync_mode = 1,
  beat_sync_lines = 1,
  original_note = 48,  -- C-4
  base_note = 48,
  triggered_notes = {},  -- Store triggered notes for stopping later
  autosamplify_state = nil,  -- Store AutoSamplify state to restore later
  timer_func = nil,  -- Store timer function reference for has_timer/remove_timer
  selection_update_timer = nil  -- Continuous timer to update selection
}

-- Update sample selection to follow playhead
function pakettiRealtimeSliceUpdateSelection()
  if not realtime_slice_state.is_monitoring then
    return
  end
  
  local song = renoise.song()
  local instrument = song.instruments[realtime_slice_state.instrument_index]
  if not instrument then return end
  
  local sample = instrument.samples[realtime_slice_state.sample_index]
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    return
  end
  
  -- Get current playback position
  local current_frame = pakettiRealtimeSliceGetCurrentFrame()
  local total_frames = sample.sample_buffer.number_of_frames
  
  -- Check if playback has reached the end
  if current_frame >= total_frames then
    print("Playback reached end of sample (frame " .. current_frame .. " >= " .. total_frames .. "), auto-stopping monitoring")
    pakettiRealtimeSliceStop()
    return
  end
  
  -- Clamp to valid range
  if current_frame < 1 then current_frame = 1 end
  if current_frame > total_frames then current_frame = total_frames end
  
  -- Update selection to follow playhead
  sample.sample_buffer.selection_start = current_frame
  sample.sample_buffer.selection_end = total_frames
end

-- Calculate current estimated playback frame position
function pakettiRealtimeSliceGetCurrentFrame()
  if not realtime_slice_state.is_monitoring then
    return 1  -- Never return 0, always return at least frame 1
  end
  
  local elapsed_time = os.clock() - realtime_slice_state.start_time
  local song = renoise.song()
  
  -- If beat sync is enabled, we need to adjust for tempo
  if realtime_slice_state.beat_sync_enabled then
    local bpm = song.transport.bpm
    local lpb = song.transport.lpb
    
    -- Calculate how the beat sync affects playback speed
    -- beat_sync_lines tells us how many pattern lines the sample should span
    local beats_per_line = 1 / lpb
    local total_beats = realtime_slice_state.beat_sync_lines * beats_per_line
    local seconds_per_beat = 60 / bpm
    local total_seconds = total_beats * seconds_per_beat
    
    -- Get the original sample length in seconds at normal pitch
    local instrument = song.instruments[realtime_slice_state.instrument_index]
    local sample = instrument.samples[realtime_slice_state.sample_index]
    if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
      return 1  -- Never return 0, always return at least frame 1
    end
    
    local total_frames = sample.sample_buffer.number_of_frames
    local playback_rate_multiplier = (total_frames / realtime_slice_state.sample_rate) / total_seconds
    
    -- Calculate frame position with beat sync compensation
    local frame_position = math.floor(elapsed_time * realtime_slice_state.sample_rate * playback_rate_multiplier)
    -- Ensure frame_position is never 0
    if frame_position < 1 then
      frame_position = 1
    end
    return frame_position
  else
    -- Normal playback without beat sync
    local frame_position = math.floor(elapsed_time * realtime_slice_state.sample_rate)
    -- Ensure frame_position is never 0
    if frame_position < 1 then
      frame_position = 1
    end
    return frame_position
  end
end

-- Start monitoring/playback
function pakettiRealtimeSliceStart()
  local song = renoise.song()
  
  -- Validate sample
  if not song.selected_instrument_index or song.selected_instrument_index == 0 then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local instrument = song.selected_instrument
  if not instrument or not song.selected_sample_index or song.selected_sample_index == 0 then
    renoise.app():show_status("No sample selected")
    return
  end
  
  local sample = song.selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Selected sample has no data")
    return
  end
  
  -- Disable AutoSamplify monitoring to prevent interference with slice creation
  realtime_slice_state.autosamplify_state = PakettiTemporarilyDisableNewSampleMonitoring()
  
  -- Store sample information
  realtime_slice_state.instrument_index = song.selected_instrument_index
  realtime_slice_state.sample_index = song.selected_sample_index
  realtime_slice_state.sample_rate = sample.sample_buffer.sample_rate
  realtime_slice_state.beat_sync_enabled = sample.beat_sync_enabled
  realtime_slice_state.beat_sync_mode = sample.beat_sync_mode
  realtime_slice_state.beat_sync_lines = sample.beat_sync_lines or 1
  
  -- Always play at C-4 (note 48) for normal pitched playback
  realtime_slice_state.base_note = 48  -- C-4
  realtime_slice_state.original_note = 48
  print("Will trigger at note: 48 (C-4) for normal pitch playback")
  
  -- Auto-create first slice at frame 1 (beginning of sample) BEFORE starting playback
  if #sample.slice_markers == 0 then
    sample:insert_slice_marker(1)
    print("Auto-created first slice at frame 1")
  end
  
  realtime_slice_state.is_monitoring = true
  
  local track_index = song.selected_track_index
  local total_frames = sample.sample_buffer.number_of_frames
  
  -- Always view sample 1 (original) at start
  song.selected_sample_index = 1
  
  -- Set sample buffer selection to play from start to end
  sample.sample_buffer.selection_start = 1
  sample.sample_buffer.selection_end = total_frames
  
  -- Use a timer to trigger playback after slice is created (2.5ms delay for maximum responsiveness)
  realtime_slice_state.timer_func = function()
    -- Remove this one-shot timer
    if realtime_slice_state.timer_func and renoise.tool():has_timer(realtime_slice_state.timer_func) then
      renoise.tool():remove_timer(realtime_slice_state.timer_func)
    end
    realtime_slice_state.timer_func = nil
    
    if realtime_slice_state.is_monitoring then
      -- Start timing NOW (when playback actually starts)
      realtime_slice_state.start_time = os.clock()
      
      -- Trigger the ORIGINAL sample (always sample index 1) from the beginning using selection
      song:trigger_sample_note_on(
        realtime_slice_state.instrument_index,
        1,  -- Always play original sample (index 1)
        track_index,
        realtime_slice_state.base_note,
        1.0,  -- velocity
        true  -- use_selection = true (play from selection_start to selection_end)
      )
      
      realtime_slice_state.triggered_notes = {realtime_slice_state.base_note}
      print("Started original sample playback from frame 1 to " .. total_frames)
    end
  end
  renoise.tool():add_timer(realtime_slice_state.timer_func, 2.5)
  
  -- Start continuous timer to update selection to follow playhead (2.5ms = 400Hz update rate)
  realtime_slice_state.selection_update_timer = function()
    pakettiRealtimeSliceUpdateSelection()
  end
  renoise.tool():add_timer(realtime_slice_state.selection_update_timer, 2.5)
  print("Started selection update timer (2.5ms / 400Hz)")
  
  local status_msg = string.format("Real-time slice monitoring STARTED - Press assigned key/MIDI to drop markers (Sample rate: %d Hz)", 
    realtime_slice_state.sample_rate)
  renoise.app():show_status(status_msg)
  print("=== Real-Time Slice Monitoring Started ===")
  print("Sample rate: " .. realtime_slice_state.sample_rate .. " Hz")
  print("Beat sync: " .. (realtime_slice_state.beat_sync_enabled and "enabled" or "disabled"))
  if realtime_slice_state.beat_sync_enabled then
    print("Beat sync lines: " .. realtime_slice_state.beat_sync_lines)
  end
end

-- Stop monitoring
function pakettiRealtimeSliceStop()
  if not realtime_slice_state.is_monitoring then
    renoise.app():show_status("Real-time slice monitoring not active")
    return
  end
  
  -- Remove any pending timer
  if realtime_slice_state.timer_func and renoise.tool():has_timer(realtime_slice_state.timer_func) then
    renoise.tool():remove_timer(realtime_slice_state.timer_func)
    realtime_slice_state.timer_func = nil
    print("Removed pending slice trigger timer")
  end
  
  -- Stop the continuous selection update timer
  if realtime_slice_state.selection_update_timer and renoise.tool():has_timer(realtime_slice_state.selection_update_timer) then
    renoise.tool():remove_timer(realtime_slice_state.selection_update_timer)
    realtime_slice_state.selection_update_timer = nil
    print("Stopped selection update timer")
  end
  
  -- Stop the playing sample cleanly
  if #realtime_slice_state.triggered_notes > 0 then
    local song = renoise.song()
    local track_index = song.selected_track_index
    song:trigger_sample_note_off(
      realtime_slice_state.instrument_index,
      1,  -- Sample index 1 (original sample)
      track_index,
      realtime_slice_state.base_note
    )
  end
  
  -- Clear sample buffer selection range
  local song = renoise.song()
  if realtime_slice_state.instrument_index > 0 and realtime_slice_state.sample_index > 0 then
    local instrument = song.instruments[realtime_slice_state.instrument_index]
    if instrument and instrument.samples[realtime_slice_state.sample_index] then
      local sample = instrument.samples[realtime_slice_state.sample_index]
      if sample.sample_buffer and sample.sample_buffer.has_sample_data then
        sample.sample_buffer.selection_start = 1
        sample.sample_buffer.selection_end = 1
        print("Cleared sample buffer selection")
      end
    end
  end
  
  -- Restore AutoSamplify monitoring state
  if realtime_slice_state.autosamplify_state then
    PakettiRestoreNewSampleMonitoring(realtime_slice_state.autosamplify_state)
    realtime_slice_state.autosamplify_state = nil
  end
  
  realtime_slice_state.is_monitoring = false
  realtime_slice_state.triggered_notes = {}
  
  renoise.app():show_status("Real-time slice monitoring STOPPED")
  print("=== Real-Time Slice Monitoring Stopped ===")
end

-- Toggle monitoring on/off
function pakettiRealtimeSliceToggle()
  if realtime_slice_state.is_monitoring then
    pakettiRealtimeSliceStop()
  else
    pakettiRealtimeSliceStart()
  end
end

-- Insert slice marker at current playback position
function pakettiRealtimeSliceInsertMarker()
  -- Auto-start monitoring if not active
  if not realtime_slice_state.is_monitoring then
    pakettiRealtimeSliceStart()
    renoise.app():show_status("Real-time slice monitoring STARTED - Press key again to insert markers")
    return
  end
  
  local song = renoise.song()
  local instrument = song.instruments[realtime_slice_state.instrument_index]
  local sample = instrument.samples[realtime_slice_state.sample_index]
  
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Sample no longer valid")
    pakettiRealtimeSliceStop()
    return
  end
  
  -- Calculate current frame position from elapsed time
  -- Since we're playing the original sample continuously, the position is simply elapsed_time * sample_rate
  local absolute_frame_position = pakettiRealtimeSliceGetCurrentFrame()
  print("Current playback position: frame " .. absolute_frame_position)
  
  local total_frames = sample.sample_buffer.number_of_frames
  
  -- Check if playback has reached the end of the sample
  if absolute_frame_position >= total_frames then
    print("Playback reached end of sample (frame " .. absolute_frame_position .. " >= " .. total_frames .. "), auto-stopping monitoring")
    renoise.app():show_status("Real-time slice monitoring STOPPED - Playback reached end")
    pakettiRealtimeSliceStop()
    return
  end
  
  -- Clamp to valid range
  if absolute_frame_position < 1 then
    absolute_frame_position = 1
  elseif absolute_frame_position > total_frames then
    absolute_frame_position = total_frames
    renoise.app():show_status("Playback reached end of sample")
    pakettiRealtimeSliceStop()
    return
  end
  
  local frame_position = absolute_frame_position
  
  -- Check if marker already exists very close to this position (within 100 frames)
  local marker_exists = false
  for i = 1, #sample.slice_markers do
    local existing_marker = sample.slice_markers[i]
    if math.abs(existing_marker - frame_position) < 100 then
      marker_exists = true
      print("Marker already exists near position " .. frame_position .. " (existing at " .. existing_marker .. ")")
      break
    end
  end
  
  if not marker_exists then
    -- Insert the slice marker
    sample:insert_slice_marker(frame_position)
    
    local elapsed_time = os.clock() - realtime_slice_state.start_time
    local marker_count = #sample.slice_markers
    
    print(string.format("Inserted slice marker #%d at frame %d (%.3f seconds into playback)", 
      marker_count, frame_position, elapsed_time))
    
    renoise.app():show_status(string.format("Slice marker #%d inserted at frame %d", 
      marker_count, frame_position))
    
    -- Update the selection to start from the new slice position
    sample.sample_buffer.selection_start = frame_position
    sample.sample_buffer.selection_end = total_frames
    print("Updated selection: start=" .. frame_position .. ", end=" .. total_frames)
    
    -- Stop current playback
    local track_index = song.selected_track_index
    if #realtime_slice_state.triggered_notes > 0 then
      song:trigger_sample_note_off(
        realtime_slice_state.instrument_index,
        1,  -- Sample index 1 (original sample)
        track_index,
        realtime_slice_state.base_note
      )
    end
    
    -- Re-trigger playback from the new slice position using the updated selection
    song:trigger_sample_note_on(
      realtime_slice_state.instrument_index,
      1,  -- Always play original sample (index 1)
      track_index,
      realtime_slice_state.base_note,
      1.0,  -- velocity
      true  -- use_selection = true (play from selection_start to selection_end)
    )
    realtime_slice_state.triggered_notes = {realtime_slice_state.base_note}
    print("Re-triggered playback from frame " .. frame_position .. " to " .. total_frames)
    
    -- Adjust timer to account for the new starting position
    -- Calculate what the start_time should be so that current elapsed time = frame_position
    local seconds_elapsed = frame_position / realtime_slice_state.sample_rate
    realtime_slice_state.start_time = os.clock() - seconds_elapsed
    print("Adjusted timer: frame " .. frame_position .. " = " .. seconds_elapsed .. " seconds elapsed")
    
    -- Switch to newest slice sample if preference is enabled (otherwise stay on original)
    if preferences and preferences.pakettiLazySlicerShowNewestSlice and preferences.pakettiLazySlicerShowNewestSlice.value then
      -- The newest slice is at index marker_count + 1 (index 1 is original sample)
      local newest_slice_index = marker_count + 1
      if newest_slice_index <= #instrument.samples then
        song.selected_sample_index = newest_slice_index
        print("Switched to newest slice sample #" .. newest_slice_index)
      end
    else
      -- Show Original mode - ensure we're viewing sample 1
      song.selected_sample_index = 1
      print("Show Original mode: viewing sample 1")
    end
  else
    renoise.app():show_status("Marker already exists at this position")
  end
end

-- Keybindings and Menu Entries
renoise.tool():add_keybinding{
  name="Global:Paketti:Real-Time Slice Monitoring (Toggle Start/Stop)",
  invoke=function() pakettiRealtimeSliceToggle() end
}

renoise.tool():add_keybinding{
  name="Global:Paketti:Real-Time Slice Monitoring (Start)",
  invoke=function() pakettiRealtimeSliceStart() end
}

renoise.tool():add_keybinding{
  name="Global:Paketti:Real-Time Slice Monitoring (Stop)",
  invoke=function() pakettiRealtimeSliceStop() end
}

renoise.tool():add_keybinding{
  name="Global:Paketti:Real-Time Slice Insert Marker at Current Position",
  invoke=function() pakettiRealtimeSliceInsertMarker() end
}


-- MIDI Mappings
renoise.tool():add_midi_mapping{
  name="Paketti:Real-Time Slice Monitoring Toggle",
  invoke=function(message) 
    if message:is_trigger() then 
      pakettiRealtimeSliceToggle() 
    end 
  end
}

renoise.tool():add_midi_mapping{
  name="Paketti:Real-Time Slice Insert Marker",
  invoke=function(message) 
    if message:is_trigger() then 
      pakettiRealtimeSliceInsertMarker() 
    end 
  end
}

-- Create New Rhythmic Slice DrumChain with Current Slices
-- Takes the slice timing from current instrument and applies it to user-loaded samples
function PakettiSliceCreateRhythmicDrumChain(normalize_slices)
  normalize_slices = normalize_slices or false
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  -- Check if we have a valid sliced instrument
  if #instrument.samples == 0 then
    renoise.app():show_status("No samples in current instrument")
    return
  end
  
  local first_sample = instrument.samples[1]
  if not first_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("First sample has no data")
    return
  end
  
  if #first_sample.slice_markers == 0 then
    renoise.app():show_status("First sample has no slice markers - not a sliced instrument")
    return
  end
  
  -- Get source sample properties
  local source_buffer = first_sample.sample_buffer
  local source_sample_rate = source_buffer.sample_rate
  local source_bit_depth = source_buffer.bit_depth
  local source_channels = source_buffer.number_of_channels
  local total_frames = source_buffer.number_of_frames
  
  -- Calculate slice durations
  local slice_markers = first_sample.slice_markers
  local slice_count = #slice_markers -- Number of slices = number of markers
  local slice_durations = {}
  
  print(string.format("PakettiSlice: Source instrument has %d slice markers (%d slices)", #slice_markers, slice_count))
  print(string.format("PakettiSlice: Source format: %dHz, %d-bit, %d channels", 
    source_sample_rate, source_bit_depth, source_channels))
  
  -- Calculate duration for each slice
  -- Each marker marks the START of a slice
  -- Slice i goes from marker[i] to marker[i+1] (or to end for last slice)
  for i = 1, slice_count do
    local slice_start = slice_markers[i]
    local slice_end
    
    if i < slice_count then
      -- Not the last slice: goes to next marker
      slice_end = slice_markers[i + 1]
    else
      -- Last slice: goes to end of sample
      slice_end = total_frames
    end
    
    local duration = slice_end - slice_start
    -- Ensure duration is at least 1 frame (never 0)
    if duration < 1 then
      duration = 1
      print(string.format("PakettiSlice: WARNING - Slice %d had 0 or negative duration, forcing to 1 frame", i))
    end
    slice_durations[i] = duration
    print(string.format("PakettiSlice: Slice %d: marker[%d]=%d to %s=%d, duration=%d frames (%.3fs)", 
      i, i, slice_start, 
      (i < slice_count) and string.format("marker[%d]", i+1) or "end",
      slice_end, duration, duration / source_sample_rate))
  end
  
  -- Prompt user to load samples
  renoise.app():show_status(string.format("Please select %d or more samples to load...", slice_count))
  
  local filenames = renoise.app():prompt_for_multiple_filenames_to_read(
    {"*.wav", "*.flac", "*.ogg", "*.mp3", "*.aiff", "*.aif"},
    "Select " .. slice_count .. " or more samples for rhythmic chain")
  
  if not filenames or #filenames == 0 then
    renoise.app():show_status("Operation cancelled - no files selected")
    return
  end
  
  -- If fewer samples than slices, we'll cycle through them
  -- If more samples than slices, trim to slice_count
  if #filenames < slice_count then
    print(string.format("PakettiSlice: User selected %d samples for %d slices - will cycle through samples", #filenames, slice_count))
  elseif #filenames > slice_count then
    print(string.format("PakettiSlice: User selected %d samples, using first %d", #filenames, slice_count))
  else
    print(string.format("PakettiSlice: User selected %d samples matching %d slices", #filenames, slice_count))
  end
  
  -- Store original selection
  local original_instrument_index = song.selected_instrument_index
  local original_sample_index = song.selected_sample_index
  
  print("========================================")
  print(string.format("PakettiSlice: ORIGINAL instrument index: %d [%s]", 
    original_instrument_index, instrument.name))
  print(string.format("PakettiSlice: ORIGINAL has %d slices to replicate", slice_count))
  print("========================================")
  
  -- Create TEMP instrument for loading samples at index+1
  local temp_instrument_index = original_instrument_index + 1
  song:insert_instrument_at(temp_instrument_index)
  local temp_instrument = song.instruments[temp_instrument_index]
  temp_instrument.name = "TEMP_PROCESSING"
  
  print(string.format("PakettiSlice: TEMP instrument created at index %d for loading samples", temp_instrument_index))
  
  -- Load and process each sample
  local processed_samples = {}
  local process_cancelled = false
  
  local function process_samples_coroutine()
    -- Process slice_count samples, skipping silent ones and cycling through filenames
    local file_index = 0
    local attempts = 0
    local max_attempts = #filenames * 3  -- Prevent infinite loop
    
    for i = 1, slice_count do
      if process_cancelled then
        print("PakettiSlice: Processing cancelled by user")
        return
      end
      
      -- Keep trying files until we find a non-silent one
      local found_valid_sample = false
      while not found_valid_sample and attempts < max_attempts do
        coroutine.yield()
        attempts = attempts + 1
        file_index = (file_index % #filenames) + 1
        local filename = filenames[file_index]
        print(string.format("PakettiSlice: Loading slice %d (file %d/%d, attempt %d): %s", i, file_index, #filenames, attempts, filename))
        
        -- Load sample into temp instrument
        song.selected_instrument_index = temp_instrument_index
        local sample_index = #temp_instrument.samples + 1
        temp_instrument:insert_sample_at(sample_index)
        local sample = temp_instrument.samples[sample_index]
        
        -- Load file
        local load_success, load_error = pcall(function()
          sample.sample_buffer:load_from(filename)
        end)
        
        if not load_success then
          print("PakettiSlice: Failed to load " .. filename .. ": " .. tostring(load_error))
          renoise.app():show_status("Failed to load: " .. filename)
          -- Clean up and abort
          song:delete_instrument_at(temp_instrument_index)
          song.selected_instrument_index = original_instrument_index
          song.selected_sample_index = original_sample_index
          return
        end
        
        if not sample.sample_buffer.has_sample_data then
          print("PakettiSlice: Sample has no data: " .. filename)
          renoise.app():show_status("Sample has no data: " .. filename)
          song:delete_instrument_at(temp_instrument_index)
          song.selected_instrument_index = original_instrument_index
          song.selected_sample_index = original_sample_index
          return
        end
        
        local buffer = sample.sample_buffer
        print(string.format("PakettiSlice: Loaded sample %d: %d frames, %dHz, %d-bit, %d channels",
          i, buffer.number_of_frames, buffer.sample_rate, buffer.bit_depth, buffer.number_of_channels))
        
        -- Check if sample is silent (skip silent samples) by finding peak
        local peak = 0.0
        local CHUNK_SIZE = 10000
        for ch = 1, buffer.number_of_channels do
          for chunk_start = 1, buffer.number_of_frames, CHUNK_SIZE do
            local chunk_end = math.min(chunk_start + CHUNK_SIZE - 1, buffer.number_of_frames)
            for frame = chunk_start, chunk_end do
              local abs_value = math.abs(buffer:sample_data(ch, frame))
              if abs_value > peak then
                peak = abs_value
              end
            end
            -- If we found any audio, no need to keep checking
            if peak > 0.001 then
              break
            end
          end
          if peak > 0.001 then
            break
          end
        end
        
        local is_silent = (peak < 0.001)  -- Peak below -60dB is considered silent
        
        if is_silent then
          print(string.format("PakettiSlice: *** SILENCE DETECTED *** (peak: %.6f) - SKIPPING and trying next file: %s", peak, filename))
          -- Delete the silent sample from temp instrument and try next file
          temp_instrument:delete_sample_at(sample_index)
          -- Continue to next file in while loop
        else
          -- Found a valid non-silent sample!
          found_valid_sample = true
          print(string.format("PakettiSlice: Valid sample found (peak: %.6f)", peak))
          
          -- Get target duration for this slice
          local target_duration = slice_durations[i]
        
          -- INTELLIGENT PRE-TRUNCATION: Don't process huge samples if we only need a small portion
          local needs_truncation = buffer.number_of_frames > (target_duration * 10)
        
          if needs_truncation then
            -- Intelligently truncate to ~150% of what we need (leaves some headroom)
            local truncate_to = math.floor(target_duration * 1.5)
            print(string.format("PakettiSlice: Intelligent truncation: %d frames -> %d frames (need %d)",
              buffer.number_of_frames, truncate_to, target_duration))
            
            -- Read in chunks of 30,000 frames for performance
            local CHUNK_SIZE = 30000
            local truncated_data = {}
            for ch = 1, buffer.number_of_channels do
              truncated_data[ch] = {}
              for chunk_start = 1, truncate_to, CHUNK_SIZE do
                local chunk_end = math.min(chunk_start + CHUNK_SIZE - 1, truncate_to)
                for frame = chunk_start, chunk_end do
                  truncated_data[ch][frame] = buffer:sample_data(ch, frame)
                end
                coroutine.yield()
              end
            end
            
            -- Create new truncated buffer
            sample.sample_buffer:create_sample_data(
              buffer.sample_rate,
              buffer.bit_depth,
              buffer.number_of_channels,
              truncate_to
            )
            
            -- Write truncated data with prepare/finalize for performance
            sample.sample_buffer:prepare_sample_data_changes()
            for ch = 1, buffer.number_of_channels do
              for chunk_start = 1, truncate_to, CHUNK_SIZE do
                local chunk_end = math.min(chunk_start + CHUNK_SIZE - 1, truncate_to)
                for frame = chunk_start, chunk_end do
                  sample.sample_buffer:set_sample_data(ch, frame, truncated_data[ch][frame])
                end
                coroutine.yield()
              end
            end
            sample.sample_buffer:finalize_sample_data_changes()
            
            buffer = sample.sample_buffer
            print(string.format("PakettiSlice: Truncated to %d frames", buffer.number_of_frames))
          end
        
          -- Check if any conversion is needed
          local needs_conversion = (buffer.sample_rate ~= source_sample_rate) or 
                                 (buffer.bit_depth ~= source_bit_depth) or 
                                 (buffer.number_of_channels ~= source_channels)
        
          if needs_conversion then
            local current_rate = buffer.sample_rate
            local current_depth = buffer.bit_depth
            local current_channels = buffer.number_of_channels
            local current_frames = buffer.number_of_frames
            
            print(string.format("PakettiSlice: Converting sample format: %dHz/%dbit/%dch -> %dHz/%dbit/%dch",
              current_rate, current_depth, current_channels,
              source_sample_rate, source_bit_depth, source_channels))
            
            -- Calculate target frame count (if sample rate changes)
            local target_frames = current_frames
            if current_rate ~= source_sample_rate then
              target_frames = math.floor(current_frames * source_sample_rate / current_rate)
            end
            
            -- Read in chunks of 30,000 frames for performance
            local CHUNK_SIZE = 30000
            local original_data = {}
            for ch = 1, current_channels do
              original_data[ch] = {}
              for chunk_start = 1, current_frames, CHUNK_SIZE do
                local chunk_end = math.min(chunk_start + CHUNK_SIZE - 1, current_frames)
                for frame = chunk_start, chunk_end do
                  original_data[ch][frame] = buffer:sample_data(ch, frame)
                end
                coroutine.yield()
              end
            end
            
            -- Create new buffer with target format
            sample.sample_buffer:create_sample_data(source_sample_rate, source_bit_depth, source_channels, target_frames)
            
            -- Prepare converted data
            local converted_data = {}
            for ch = 1, source_channels do
              converted_data[ch] = {}
            end
            
            for target_frame = 1, target_frames do
              -- Calculate source frame (with resampling if needed)
              local source_frame = target_frame
              if current_rate ~= source_sample_rate then
                source_frame = math.floor((target_frame - 1) * current_frames / target_frames) + 1
                source_frame = math.min(source_frame, current_frames)
              end
              
              -- Handle channel conversion
              if source_channels == 1 and current_channels == 2 then
                -- Stereo to mono: average channels
                converted_data[1][target_frame] = (original_data[1][source_frame] + original_data[2][source_frame]) * 0.5
              elseif source_channels == 2 and current_channels == 1 then
                -- Mono to stereo: duplicate channel
                local value = original_data[1][source_frame]
                converted_data[1][target_frame] = value
                converted_data[2][target_frame] = value
              else
                -- Same channel count: direct copy
                for ch = 1, source_channels do
                  converted_data[ch][target_frame] = original_data[ch][source_frame]
                end
              end
            end
            
            -- Write converted data with prepare/finalize for performance in chunks
            sample.sample_buffer:prepare_sample_data_changes()
            for ch = 1, source_channels do
              for chunk_start = 1, target_frames, CHUNK_SIZE do
                local chunk_end = math.min(chunk_start + CHUNK_SIZE - 1, target_frames)
                for frame = chunk_start, chunk_end do
                  sample.sample_buffer:set_sample_data(ch, frame, converted_data[ch][frame])
                end
                coroutine.yield()
              end
            end
            sample.sample_buffer:finalize_sample_data_changes()
            
            -- Refresh buffer reference after conversion
            buffer = sample.sample_buffer
          end
        
          -- Extract sample data for this slice (target_duration already declared above)
          local sample_frames = math.min(buffer.number_of_frames, target_duration)
          
          -- Extract data with 10-frame fadeout, reading in chunks
          local CHUNK_SIZE = 30000
          local channel_data = {}
          for ch = 1, source_channels do
            channel_data[ch] = {}
            
            -- Read in chunks for performance
            for chunk_start = 1, sample_frames, CHUNK_SIZE do
              local chunk_end = math.min(chunk_start + CHUNK_SIZE - 1, sample_frames)
              for frame = chunk_start, chunk_end do
                local value = buffer:sample_data(ch, frame)
                
                -- Apply 10-frame fadeout at the end
                if frame > sample_frames - 10 then
                  local fade_position = frame - (sample_frames - 10)
                  local fade_factor = 1.0 - (fade_position / 10.0)
                  value = value * fade_factor
                end
                
                channel_data[ch][frame] = value
              end
              coroutine.yield()
            end
            
            -- Pad with silence if sample is shorter than slice duration
            for frame = sample_frames + 1, target_duration do
              channel_data[ch][frame] = 0.0
            end
          end
          
          processed_samples[i] = {
            data = channel_data,
            frames = target_duration
          }
          
          print(string.format("PakettiSlice: Processed sample %d: %d frames (target duration)", 
            i, target_duration))
        end -- end of else (non-silent sample processing)
      end -- end of while loop (finding valid sample)
      
      -- Check if we failed to find a valid sample
      if not found_valid_sample then
        print(string.format("PakettiSlice: WARNING - Could not find valid sample after %d attempts for slice %d", attempts, i))
        -- Create silence as fallback
        local silence_data = {}
        for ch = 1, source_channels do
          silence_data[ch] = {}
          for frame = 1, slice_durations[i] do
            silence_data[ch][frame] = 0.0
          end
        end
        processed_samples[i] = {
          data = silence_data,
          frames = slice_durations[i]
        }
      end
    end -- end of for loop
  end
  
  -- Create and run ProcessSlicer
  local process_slicer = ProcessSlicer(process_samples_coroutine)
  local process_dialog, process_vb = process_slicer:create_dialog("Processing Rhythmic Slice Chain Samples...")
  process_slicer:start()
  
  -- Use a polling timer to wait for processing completion
  local completion_timer_id = nil
  local completion_already_called = false
  
  local function complete_processing_and_build_chain()
    -- Prevent multiple calls
    if completion_already_called then
      return
    end
    completion_already_called = true
    
    if completion_timer_id then
      renoise.tool():remove_timer(completion_timer_id)
      completion_timer_id = nil
    end
    
    if process_dialog and process_dialog.visible then
      process_dialog:close()
    end
    
    if process_slicer:was_cancelled() then
      print("PakettiSlice: Processing was cancelled")
      song:delete_instrument_at(temp_instrument_index)
      song.selected_instrument_index = original_instrument_index
      song.selected_sample_index = original_sample_index
      renoise.app():show_status("Rhythmic slice chain creation cancelled")
      return
    end
    
    print("========================================")
    print(string.format("PakettiSlice: Finished processing - %d samples in processed_samples table", 
      #processed_samples))
    
    -- Verify processed_samples data
    local has_data_count = 0
    for i, processed in ipairs(processed_samples) do
      if processed and processed.data and processed.data[1] then
        has_data_count = has_data_count + 1
      end
    end
    print(string.format("PakettiSlice: Verified: %d/%d samples have audio data", 
      has_data_count, #processed_samples))
    print("========================================")
    
    -- Delete temp instrument (we've extracted all the data we need)
    print(string.format("PakettiSlice: Deleting TEMP instrument at index %d", temp_instrument_index))
    song:delete_instrument_at(temp_instrument_index)
    print("PakettiSlice: TEMP instrument deleted")
    
    -- Calculate total chain length and slice marker positions
    -- Each marker marks the START of a slice
    -- First marker is at frame 1 (start of first slice)
    local total_chain_frames = 0
    local chain_slice_markers = {}
    
    -- First marker at position 1 (start of slice 1)
    table.insert(chain_slice_markers, 1)
    
    for i, processed in ipairs(processed_samples) do
      total_chain_frames = total_chain_frames + processed.frames
      -- Add marker at end of each sample (except the last) to mark start of next slice
      if i < #processed_samples then
        -- Ensure marker position is never 0
        local marker_pos = total_chain_frames
        if marker_pos < 1 then
          marker_pos = 1
        end
        table.insert(chain_slice_markers, marker_pos)
      end
    end
    
    print(string.format("PakettiSlice: Total chain: %d frames with %d slice markers",
      total_chain_frames, #chain_slice_markers))
    print(string.format("PakettiSlice: First marker at frame 1, last marker at frame %d", 
      chain_slice_markers[#chain_slice_markers]))
    
    -- Ensure total_chain_frames is at least 1 (never 0)
    if total_chain_frames < 1 then
      total_chain_frames = 1
      print("PakettiSlice: WARNING - Total chain frames was 0, forcing to 1 frame")
    end
    
    -- Create FINAL instrument at index+2 (temp was deleted, so now it's at index+1)
    local new_instrument_index = original_instrument_index + 1
    song:insert_instrument_at(new_instrument_index)
    song.selected_instrument_index = new_instrument_index
    
    -- Apply Paketti default XRNI template (pakettification)
    print("PakettiSlice: Applying Paketti default XRNI template...")
    pakettiPreferencesDefaultInstrumentLoader()
    
    local new_instrument = song.instruments[new_instrument_index]
    
    -- Set instrument name AFTER pakettification (template may override it)
    local original_instrument = song.instruments[original_instrument_index]
    local original_name = original_instrument.name ~= "" and original_instrument.name or "Untitled"
    
    -- Strip any existing rhythmic suffix from original name to prevent flooding
    original_name = original_name:gsub(" %(.+[Rr]hythmic.+%)$", "")
    
    new_instrument.name = original_name .. " (Rhythmic Slice Flow Truncate Kit)"
    
    print("========================================")
    print(string.format("PakettiSlice: FINAL instrument created at index %d [%s] (Pakettified)", 
      new_instrument_index, new_instrument.name))
    print("========================================")
    
    -- Delete any default samples from the template
    if #new_instrument.samples > 0 then
      for i = #new_instrument.samples, 1, -1 do
        new_instrument:delete_sample_at(i)
      end
      print("PakettiSlice: Cleared default template samples")
    end
    
    -- Create the chained sample in new instrument
    new_instrument:insert_sample_at(1)
    local new_sample = new_instrument.samples[1]
    new_sample.name = "Rhythmic Slice Chain"
    
    -- Create sample buffer with correct format
    new_sample.sample_buffer:create_sample_data(
      source_sample_rate,
      source_bit_depth,
      source_channels,
      total_chain_frames
    )
    
    -- Write chained data with prepare/finalize for performance
    print(string.format("PakettiSlice: Writing chained data - %d samples to process, %d channels, %d total frames", 
      #processed_samples, source_channels, total_chain_frames))
    
    local CHUNK_SIZE = 30000
    new_sample.sample_buffer:prepare_sample_data_changes()
    local write_position = 1
    for i, processed in ipairs(processed_samples) do
      if processed and processed.data and processed.frames > 0 then
        print(string.format("PakettiSlice: Writing sample %d: %d frames starting at position %d", 
          i, processed.frames, write_position))
        
        -- Write in chunks for performance
        for chunk_start = 1, processed.frames, CHUNK_SIZE do
          local chunk_end = math.min(chunk_start + CHUNK_SIZE - 1, processed.frames)
          for frame = chunk_start, chunk_end do
            for ch = 1, source_channels do
              local value = processed.data[ch][frame] or 0.0
              new_sample.sample_buffer:set_sample_data(ch, write_position, value)
            end
            write_position = write_position + 1
          end
        end
      else
        print(string.format("PakettiSlice: Skipping sample %d (no data or 0 frames)", i))
      end
    end
    new_sample.sample_buffer:finalize_sample_data_changes()
    print(string.format("PakettiSlice: Finished writing at position %d (expected %d)", 
      write_position - 1, total_chain_frames))
    
    -- Apply slice markers
    local markers_added = 0
    for _, marker_position in ipairs(chain_slice_markers) do
      if marker_position > 0 and marker_position < total_chain_frames then
        new_sample:insert_slice_marker(marker_position)
        markers_added = markers_added + 1
        print(string.format("PakettiSlice: Added slice marker at position %d", marker_position))
      else
        print(string.format("PakettiSlice: Skipped invalid slice marker at position %d (total frames: %d)", 
          marker_position, total_chain_frames))
      end
    end
    
    print(string.format("PakettiSlice: Created new instrument with %d slices (%d markers added)",
      slice_count, markers_added))
    
    -- Select new instrument
    song.selected_instrument_index = new_instrument_index
    
    -- Apply Paketti loader settings to the chained sample
    print("PakettiSlice: Applying Paketti loader settings to chained sample...")
    PakettiInjectApplyLoaderSettings(new_sample)
    
    -- Normalize slices if requested
    if normalize_slices then
      print("PakettiSlice: Normalizing slices independently...")
      normalize_selected_sample_by_slices()
    end
    
    renoise.app():show_status(string.format("Rhythmic slice chain created: %d samples loaded, %d slices, %.2fs total (Pakettified%s)",
      slice_count, slice_count, total_chain_frames / source_sample_rate,
      normalize_slices and ", normalized" or ""))
  end
  
  -- Polling timer to check when processing completes
  local function check_processing_complete()
    if not process_slicer:running() then
      complete_processing_and_build_chain()
    end
  end
  
  completion_timer_id = renoise.tool():add_timer(check_processing_complete, 100)
end

-- Create New Rhythmic Slice DrumChain with Randomized Samples from Folder
-- Takes the slice timing from current instrument and applies it to randomly selected samples from a folder
function PakettiSliceCreateRhythmicDrumChainRandomize(normalize_slices)
  normalize_slices = normalize_slices or false
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  -- Check if we have a valid sliced instrument
  if #instrument.samples == 0 then
    renoise.app():show_status("No samples in current instrument")
    return
  end
  
  local first_sample = instrument.samples[1]
  if not first_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("First sample has no data")
    return
  end
  
  if #first_sample.slice_markers == 0 then
    renoise.app():show_status("First sample has no slice markers - not a sliced instrument")
    return
  end
  
  -- Get source sample properties
  local source_buffer = first_sample.sample_buffer
  local source_sample_rate = source_buffer.sample_rate
  local source_bit_depth = source_buffer.bit_depth
  local source_channels = source_buffer.number_of_channels
  local total_frames = source_buffer.number_of_frames
  
  -- Calculate slice durations
  local slice_markers = first_sample.slice_markers
  local slice_count = #slice_markers -- Number of slices = number of markers
  local slice_durations = {}
  
  print(string.format("PakettiSlice: Source instrument has %d slice markers (%d slices)", #slice_markers, slice_count))
  print(string.format("PakettiSlice: Source format: %dHz, %d-bit, %d channels", 
    source_sample_rate, source_bit_depth, source_channels))
  
  -- Calculate duration for each slice
  for i = 1, slice_count do
    local slice_start = slice_markers[i]
    local slice_end
    
    if i < slice_count then
      slice_end = slice_markers[i + 1]
    else
      slice_end = total_frames
    end
    
    local duration = slice_end - slice_start
    -- Ensure duration is at least 1 frame (never 0)
    if duration < 1 then
      duration = 1
      print(string.format("PakettiSlice: WARNING - Slice %d had 0 or negative duration, forcing to 1 frame", i))
    end
    slice_durations[i] = duration
    
    print(string.format("PakettiSlice: Slice %d: marker[%d]=%d to %s=%d, duration=%d frames (%.3fs)",
      i, i, slice_start, 
      i < slice_count and ("marker[" .. (i+1) .. "]") or "end",
      slice_end, duration, duration / source_sample_rate))
  end
  
  -- Prompt user to select a folder
  renoise.app():show_status(string.format("Please select a folder to randomize %d samples from...", slice_count))
  
  local folder_path = renoise.app():prompt_for_path("Select Folder to Randomize Samples From")
  if not folder_path or folder_path == "" then
    renoise.app():show_status("Operation cancelled - no folder selected")
    return
  end
  
  -- Get all audio files from the folder and subfolders
  local all_files = PakettiGetFilesInDirectory(folder_path)
  
  if not all_files or #all_files == 0 then
    renoise.app():show_status("No audio files found in selected folder")
    return
  end
  
  -- Randomize the file list
  math.randomseed(os.time())
  math.random(); math.random(); math.random() -- Extra calls to improve randomness
  
  -- Fisher-Yates shuffle
  for i = #all_files, 2, -1 do
    local j = math.random(1, i)
    all_files[i], all_files[j] = all_files[j], all_files[i]
  end
  
  -- Take only as many files as we need (or all if fewer than slice_count)
  local filenames = {}
  local files_to_use = math.min(#all_files, slice_count)
  for i = 1, files_to_use do
    filenames[i] = all_files[i]
  end
  
  print(string.format("PakettiSlice: Found %d files in folder, randomly selected %d for %d slices", 
    #all_files, #filenames, slice_count))
  
  -- If fewer samples than slices, we'll cycle through them (handled in processing loop)
  if #filenames < slice_count then
    print(string.format("PakettiSlice: Selected %d samples for %d slices - will cycle through samples", #filenames, slice_count))
  end
  
  -- Store original instrument info
  local original_instrument_index = song.selected_instrument_index
  local original_sample_index = song.selected_sample_index
  
  print("========================================")
  print(string.format("PakettiSlice: ORIGINAL instrument index: %d [%s]", original_instrument_index, instrument.name))
  print(string.format("PakettiSlice: ORIGINAL has %d slices to replicate", slice_count))
  print("========================================")
  
  -- Create temporary instrument for loading samples
  local temp_instrument_index = original_instrument_index + 1
  song:insert_instrument_at(temp_instrument_index)
  song.selected_instrument_index = temp_instrument_index
  local temp_instrument = song.instruments[temp_instrument_index]
  temp_instrument.name = "TEMP - Loading Samples"
  
  print(string.format("PakettiSlice: TEMP instrument created at index %d for loading samples", temp_instrument_index))
  
  -- Load and process each sample
  local processed_samples = {}
  local process_cancelled = false
  
  local function process_samples_coroutine()
    -- Process slice_count samples, skipping silent ones and cycling through filenames
    local file_index = 0
    local attempts = 0
    local max_attempts = #filenames * 3  -- Prevent infinite loop
    
    for i = 1, slice_count do
      if process_cancelled then
        print("PakettiSlice: Processing cancelled by user")
        return
      end
      
      -- Keep trying files until we find a non-silent one
      local found_valid_sample = false
      while not found_valid_sample and attempts < max_attempts do
        coroutine.yield()
        attempts = attempts + 1
        file_index = (file_index % #filenames) + 1
        local filename = filenames[file_index]
        print(string.format("PakettiSlice: Loading slice %d (file %d/%d, attempt %d): %s", i, file_index, #filenames, attempts, filename))
        
        -- Load sample into temp instrument
        song.selected_instrument_index = temp_instrument_index
        local sample_index = #temp_instrument.samples + 1
        temp_instrument:insert_sample_at(sample_index)
        local sample = temp_instrument.samples[sample_index]
        
        -- Load file
        local load_success, load_error = pcall(function()
          sample.sample_buffer:load_from(filename)
        end)
        
        if not load_success then
          print("PakettiSlice: Failed to load " .. filename .. ": " .. tostring(load_error))
          renoise.app():show_status("Failed to load: " .. filename)
          -- Clean up and abort
          song:delete_instrument_at(temp_instrument_index)
          song.selected_instrument_index = original_instrument_index
          song.selected_sample_index = original_sample_index
          return
        end
        
        if not sample.sample_buffer.has_sample_data then
          print("PakettiSlice: Sample has no data: " .. filename)
          renoise.app():show_status("Sample has no data: " .. filename)
          song:delete_instrument_at(temp_instrument_index)
          song.selected_instrument_index = original_instrument_index
          song.selected_sample_index = original_sample_index
          return
        end
        
        local buffer = sample.sample_buffer
        print(string.format("PakettiSlice: Loaded sample %d: %d frames, %dHz, %d-bit, %d channels",
          i, buffer.number_of_frames, buffer.sample_rate, buffer.bit_depth, buffer.number_of_channels))
        
        -- Check if sample is silent (skip silent samples) by finding peak
        local peak = 0.0
        local CHUNK_SIZE = 10000
        for ch = 1, buffer.number_of_channels do
          for chunk_start = 1, buffer.number_of_frames, CHUNK_SIZE do
            local chunk_end = math.min(chunk_start + CHUNK_SIZE - 1, buffer.number_of_frames)
            for frame = chunk_start, chunk_end do
              local abs_value = math.abs(buffer:sample_data(ch, frame))
              if abs_value > peak then
                peak = abs_value
              end
            end
            -- If we found any audio, no need to keep checking
            if peak > 0.001 then
              break
            end
          end
          if peak > 0.001 then
            break
          end
        end
        
        local is_silent = (peak < 0.001)  -- Peak below -60dB is considered silent
        
        if is_silent then
          print(string.format("PakettiSlice: *** SILENCE DETECTED *** (peak: %.6f) - SKIPPING and trying next file: %s", peak, filename))
          -- Delete the silent sample from temp instrument and try next file
          temp_instrument:delete_sample_at(sample_index)
          -- Continue to next file in while loop
        else
          -- Found a valid non-silent sample!
          found_valid_sample = true
          print(string.format("PakettiSlice: Valid sample found (peak: %.6f)", peak))
          
          -- Get target duration for this slice
          local target_duration = slice_durations[i]
        
          -- INTELLIGENT PRE-TRUNCATION: Don't process huge samples if we only need a small portion
          local needs_truncation = buffer.number_of_frames > (target_duration * 10)
        
          if needs_truncation then
            -- Intelligently truncate to ~150% of what we need (leaves some headroom)
            local truncate_to = math.floor(target_duration * 1.5)
            print(string.format("PakettiSlice: Intelligent truncation: %d frames -> %d frames (need %d)",
              buffer.number_of_frames, truncate_to, target_duration))
            
            -- Read in chunks of 30,000 frames for performance
            local CHUNK_SIZE = 30000
            local truncated_data = {}
            for ch = 1, buffer.number_of_channels do
              truncated_data[ch] = {}
              for chunk_start = 1, truncate_to, CHUNK_SIZE do
                local chunk_end = math.min(chunk_start + CHUNK_SIZE - 1, truncate_to)
                for frame = chunk_start, chunk_end do
                  truncated_data[ch][frame] = buffer:sample_data(ch, frame)
                end
                coroutine.yield()
              end
            end
            
            -- Create new truncated buffer
            sample.sample_buffer:create_sample_data(
              buffer.sample_rate,
              buffer.bit_depth,
              buffer.number_of_channels,
              truncate_to
            )
            
            -- Write truncated data with prepare/finalize for performance
            sample.sample_buffer:prepare_sample_data_changes()
            for ch = 1, buffer.number_of_channels do
              for chunk_start = 1, truncate_to, CHUNK_SIZE do
                local chunk_end = math.min(chunk_start + CHUNK_SIZE - 1, truncate_to)
                for frame = chunk_start, chunk_end do
                  sample.sample_buffer:set_sample_data(ch, frame, truncated_data[ch][frame])
                end
                coroutine.yield()
              end
            end
            sample.sample_buffer:finalize_sample_data_changes()
            
            buffer = sample.sample_buffer
            print(string.format("PakettiSlice: Truncated to %d frames", buffer.number_of_frames))
          end
        
          -- Check if any conversion is needed
          local needs_conversion = (buffer.sample_rate ~= source_sample_rate) or 
                                 (buffer.bit_depth ~= source_bit_depth) or 
                                 (buffer.number_of_channels ~= source_channels)
        
          if needs_conversion then
            local current_rate = buffer.sample_rate
            local current_depth = buffer.bit_depth
            local current_channels = buffer.number_of_channels
            local current_frames = buffer.number_of_frames
            
            print(string.format("PakettiSlice: Converting sample format: %dHz/%dbit/%dch -> %dHz/%dbit/%dch",
              current_rate, current_depth, current_channels,
              source_sample_rate, source_bit_depth, source_channels))
            
            -- Calculate target frame count (if sample rate changes)
            local target_frames = current_frames
            if current_rate ~= source_sample_rate then
              target_frames = math.floor(current_frames * source_sample_rate / current_rate)
            end
            
            -- Read in chunks of 30,000 frames for performance
            local CHUNK_SIZE = 30000
            local original_data = {}
            for ch = 1, current_channels do
              original_data[ch] = {}
              for chunk_start = 1, current_frames, CHUNK_SIZE do
                local chunk_end = math.min(chunk_start + CHUNK_SIZE - 1, current_frames)
                for frame = chunk_start, chunk_end do
                  original_data[ch][frame] = buffer:sample_data(ch, frame)
                end
                coroutine.yield()
              end
            end
            
            -- Create new buffer with target format
            sample.sample_buffer:create_sample_data(source_sample_rate, source_bit_depth, source_channels, target_frames)
            
            -- Prepare converted data
            local converted_data = {}
            for ch = 1, source_channels do
              converted_data[ch] = {}
            end
            
            for target_frame = 1, target_frames do
              -- Calculate source frame (with resampling if needed)
              local source_frame = target_frame
              if current_rate ~= source_sample_rate then
                source_frame = math.floor((target_frame - 1) * current_frames / target_frames) + 1
                source_frame = math.min(source_frame, current_frames)
              end
              
              -- Handle channel conversion
              if source_channels == 1 and current_channels == 2 then
                -- Stereo to mono: average channels
                converted_data[1][target_frame] = (original_data[1][source_frame] + original_data[2][source_frame]) * 0.5
              elseif source_channels == 2 and current_channels == 1 then
                -- Mono to stereo: duplicate channel
                local value = original_data[1][source_frame]
                converted_data[1][target_frame] = value
                converted_data[2][target_frame] = value
              else
                -- Same channel count: direct copy
                for ch = 1, source_channels do
                  converted_data[ch][target_frame] = original_data[ch][source_frame]
                end
              end
            end
            
            -- Write converted data with prepare/finalize for performance in chunks
            sample.sample_buffer:prepare_sample_data_changes()
            for ch = 1, source_channels do
              for chunk_start = 1, target_frames, CHUNK_SIZE do
                local chunk_end = math.min(chunk_start + CHUNK_SIZE - 1, target_frames)
                for frame = chunk_start, chunk_end do
                  sample.sample_buffer:set_sample_data(ch, frame, converted_data[ch][frame])
                end
                coroutine.yield()
              end
            end
            sample.sample_buffer:finalize_sample_data_changes()
            
            -- Refresh buffer reference after conversion
            buffer = sample.sample_buffer
          end
        
          -- Extract sample data for this slice (target_duration already declared above)
          local sample_frames = math.min(buffer.number_of_frames, target_duration)
          
          -- Extract data with 10-frame fadeout, reading in chunks
          local CHUNK_SIZE = 30000
          local channel_data = {}
          for ch = 1, source_channels do
            channel_data[ch] = {}
            
            -- Read in chunks for performance
            for chunk_start = 1, sample_frames, CHUNK_SIZE do
              local chunk_end = math.min(chunk_start + CHUNK_SIZE - 1, sample_frames)
              for frame = chunk_start, chunk_end do
                local value = buffer:sample_data(ch, frame)
                
                -- Apply 10-frame fadeout at the end
                if frame > sample_frames - 10 then
                  local fade_position = frame - (sample_frames - 10)
                  local fade_factor = 1.0 - (fade_position / 10.0)
                  value = value * fade_factor
                end
                
                channel_data[ch][frame] = value
              end
              coroutine.yield()
            end
            
            -- Pad with silence if sample is shorter than slice duration
            for frame = sample_frames + 1, target_duration do
              channel_data[ch][frame] = 0.0
            end
          end
          
          processed_samples[i] = {
            data = channel_data,
            frames = target_duration
          }
          
          print(string.format("PakettiSlice: Processed sample %d: %d frames (target duration)", 
            i, target_duration))
        end -- end of else (non-silent sample processing)
      end -- end of while loop (finding valid sample)
      
      -- Check if we failed to find a valid sample
      if not found_valid_sample then
        print(string.format("PakettiSlice: WARNING - Could not find valid sample after %d attempts for slice %d", attempts, i))
        -- Create silence as fallback
        local silence_data = {}
        for ch = 1, source_channels do
          silence_data[ch] = {}
          for frame = 1, slice_durations[i] do
            silence_data[ch][frame] = 0.0
          end
        end
        processed_samples[i] = {
          data = silence_data,
          frames = slice_durations[i]
        }
      end
    end -- end of for loop
  end
  
  -- Create and run ProcessSlicer
  local process_slicer = ProcessSlicer(process_samples_coroutine)
  local process_dialog, process_vb = process_slicer:create_dialog("Processing Rhythmic Slice Chain Samples (Randomize)...")
  process_slicer:start()
  
  -- Use a polling timer to wait for processing completion
  local completion_timer_id = nil
  local completion_already_called = false
  
  local function complete_processing_and_build_chain()
    -- Prevent multiple calls
    if completion_already_called then
      return
    end
    completion_already_called = true
    
    if completion_timer_id then
      renoise.tool():remove_timer(completion_timer_id)
      completion_timer_id = nil
    end
    
    if process_dialog and process_dialog.visible then
      process_dialog:close()
    end
    
    -- Verify we have all samples processed
    local missing_samples = 0
    for i = 1, slice_count do
      if not processed_samples[i] or not processed_samples[i].data then
        missing_samples = missing_samples + 1
      end
    end
    
    if missing_samples > 0 then
      print(string.format("PakettiSlice: ERROR - %d samples missing from processed_samples table", missing_samples))
      renoise.app():show_status(string.format("Processing incomplete - %d samples missing", missing_samples))
      return
    end
    
    print("========================================")
    print(string.format("PakettiSlice: Finished processing - %d samples in processed_samples table", #processed_samples))
    
    -- Verify all samples have data
    local samples_with_data = 0
    for i = 1, slice_count do
      if processed_samples[i] and processed_samples[i].data then
        samples_with_data = samples_with_data + 1
      end
    end
    print(string.format("PakettiSlice: Verified: %d/%d samples have audio data", samples_with_data, slice_count))
    print("========================================")
    
    -- Delete temp instrument
    print(string.format("PakettiSlice: Deleting TEMP instrument at index %d", temp_instrument_index))
    song:delete_instrument_at(temp_instrument_index)
    print("PakettiSlice: TEMP instrument deleted")
    
    -- Calculate total chain length
    local total_chain_frames = 0
    for i = 1, slice_count do
      total_chain_frames = total_chain_frames + processed_samples[i].frames
    end
    
    print(string.format("PakettiSlice: Total chain: %d frames with %d slice markers", total_chain_frames, slice_count))
    
    -- Ensure total_chain_frames is at least 1 (never 0)
    if total_chain_frames < 1 then
      total_chain_frames = 1
      print("PakettiSlice: WARNING - Total chain frames was 0, forcing to 1 frame")
    end
    
    -- Calculate slice marker positions
    local marker_positions = {}
    local current_position = 1
    marker_positions[1] = current_position  -- First marker at frame 1
    
    for i = 1, slice_count - 1 do
      current_position = current_position + processed_samples[i].frames
      -- Ensure marker position is never 0
      if current_position < 1 then
        current_position = 1
      end
      marker_positions[i + 1] = current_position
    end
    
    print(string.format("PakettiSlice: First marker at frame %d, last marker at frame %d", 
      marker_positions[1], marker_positions[slice_count]))
    
    -- Create FINAL instrument at index+1 (temp was deleted, so original is still at its original index)
    local new_instrument_index = original_instrument_index + 1
    song:insert_instrument_at(new_instrument_index)
    song.selected_instrument_index = new_instrument_index
    
    -- Apply Paketti default XRNI template (pakettification)
    print("PakettiSlice: Applying Paketti default XRNI template...")
    pakettiPreferencesDefaultInstrumentLoader()
    
    local new_instrument = song.instruments[new_instrument_index]
    
    print("========================================")
    print(string.format("PakettiSlice: FINAL instrument created at index %d (Pakettified)", 
      new_instrument_index))
    print("========================================")
    
    -- Delete any default samples from the template
    if #new_instrument.samples > 0 then
      for i = #new_instrument.samples, 1, -1 do
        new_instrument:delete_sample_at(i)
      end
      print("PakettiSlice: Cleared default template samples")
    end
    
    -- Create the chained sample
    new_instrument:insert_sample_at(1)
    local new_sample = new_instrument.samples[1]
    new_sample.name = "Rhythmic Slice Chain (Randomize)"
    
    -- Create sample buffer with correct format
    new_sample.sample_buffer:create_sample_data(
      source_sample_rate,
      source_bit_depth,
      source_channels,
      total_chain_frames
    )
    
    -- Write all processed samples into the chain
    print(string.format("PakettiSlice: Writing chained data - %d samples to process, %d channels, %d total frames",
      slice_count, source_channels, total_chain_frames))
    
    new_sample.sample_buffer:prepare_sample_data_changes()
    
    local chain_position = 1
    for i = 1, slice_count do
      local sample_data = processed_samples[i].data
      local sample_frames = processed_samples[i].frames
      
      print(string.format("PakettiSlice: Writing sample %d: %d frames starting at position %d", 
        i, sample_frames, chain_position))
      
      -- Write all frames for this sample
      for ch = 1, source_channels do
        for frame = 1, sample_frames do
          local target_frame = chain_position + frame - 1
          new_sample.sample_buffer:set_sample_data(ch, target_frame, sample_data[ch][frame])
        end
      end
      
      chain_position = chain_position + sample_frames
    end
    
    new_sample.sample_buffer:finalize_sample_data_changes()
    
    print(string.format("PakettiSlice: Finished writing at position %d (expected %d)", 
      chain_position - 1, total_chain_frames))
    
    -- Add slice markers
    local markers_added = 0
    for i = 1, slice_count do
      local marker_position = marker_positions[i]
      if marker_position > 0 and marker_position < total_chain_frames then
        new_sample:insert_slice_marker(marker_position)
        markers_added = markers_added + 1
        print(string.format("PakettiSlice: Added slice marker at position %d", marker_position))
      else
        print(string.format("PakettiSlice: Skipped invalid slice marker at position %d (total frames: %d)", 
          marker_position, total_chain_frames))
      end
    end
    
    print(string.format("PakettiSlice: Created new instrument with %d slices (%d markers added)", 
      slice_count, markers_added))
    
    -- Select new instrument
    song.selected_instrument_index = new_instrument_index
    song.selected_sample_index = 1
    
    -- Apply Paketti loader settings to the chained sample
    print("PakettiSlice: Applying Paketti loader settings to chained sample...")
    PakettiInjectApplyLoaderSettings(new_sample)
    
    -- Normalize slices if requested
    if normalize_slices then
      print("PakettiSlice: Normalizing slices independently...")
      normalize_selected_sample_by_slices()
    end
    
    -- Set instrument name at the VERY END (after all processing)
    local original_instrument = song.instruments[original_instrument_index]
    local original_name = original_instrument.name ~= "" and original_instrument.name or "Untitled"
    
    -- Strip any existing rhythmic suffix from original name to prevent flooding
    original_name = original_name:gsub(" %(.+[Rr]hythmic.+%)$", "")
    
    new_instrument.name = original_name .. " (Rhythmic Slice Flow Truncate Kit) (Randomize)"
    
    print(string.format("PakettiSlice: Set instrument name to: %s", new_instrument.name))
    
    renoise.app():show_status(string.format("Created rhythmic slice chain with %d randomized slices%s", 
      slice_count, normalize_slices and " (normalized)" or ""))
  end
  
  local function check_processing_complete()
    if not process_slicer:running() then
      complete_processing_and_build_chain()
    end
  end
  
  completion_timer_id = renoise.tool():add_timer(check_processing_complete, 100)
end

-- Create New Rhythmic Slice DrumChain from XRNI
-- Takes slice timing from current instrument and applies it to slices from a loaded XRNI
function PakettiSliceCreateRhythmicDrumChainFromXRNI(normalize_slices)
  normalize_slices = normalize_slices or false
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  -- Check if we have a valid sliced instrument
  if #instrument.samples == 0 then
    renoise.app():show_status("No samples in current instrument")
    return
  end
  
  local first_sample = instrument.samples[1]
  if not first_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("First sample has no data")
    return
  end
  
  if #first_sample.slice_markers == 0 then
    renoise.app():show_status("First sample has no slice markers - not a sliced instrument")
    return
  end
  
  -- Get source sample properties
  local source_buffer = first_sample.sample_buffer
  local source_sample_rate = source_buffer.sample_rate
  local source_bit_depth = source_buffer.bit_depth
  local source_channels = source_buffer.number_of_channels
  local total_frames = source_buffer.number_of_frames
  
  -- Calculate slice durations from source
  local slice_markers = first_sample.slice_markers
  local source_slice_count = #slice_markers
  local slice_durations = {}
  
  print(string.format("PakettiSlice: Source instrument has %d slice markers (%d slices)", #slice_markers, source_slice_count))
  print(string.format("PakettiSlice: Source format: %dHz, %d-bit, %d channels", 
    source_sample_rate, source_bit_depth, source_channels))
  
  -- Calculate duration for each slice
  -- Each marker marks the START of a slice
  -- Slice i goes from marker[i] to marker[i+1] (or to end for last slice)
  for i = 1, source_slice_count do
    local slice_start = slice_markers[i]
    local slice_end
    
    if i < source_slice_count then
      -- Not the last slice: goes to next marker
      slice_end = slice_markers[i + 1]
    else
      -- Last slice: goes to end of sample
      slice_end = total_frames
    end
    
    local duration = slice_end - slice_start
    -- Ensure duration is at least 1 frame (never 0)
    if duration < 1 then
      duration = 1
      print(string.format("PakettiSlice: WARNING - Slice %d had 0 or negative duration, forcing to 1 frame", i))
    end
    slice_durations[i] = duration
    print(string.format("PakettiSlice: Source slice %d: marker[%d]=%d to %s=%d, duration=%d frames (%.3fs)", 
      i, i, slice_start, 
      (i < source_slice_count) and string.format("marker[%d]", i+1) or "end",
      slice_end, duration, duration / source_sample_rate))
  end
  
  -- Store original selection
  local original_instrument_index = song.selected_instrument_index
  
  -- Loop until user selects valid XRNI or cancels
  local loaded_instrument = nil
  local loaded_first_sample = nil
  local loaded_slice_count = 0
  local temp_instrument_index = nil
  
  while true do
    -- Prompt user to load XRNI
    renoise.app():show_status("Please select an XRNI file with slice markers...")
    
    local xrni_filename = renoise.app():prompt_for_filename_to_read(
      {"*.xrni"},
      "Select XRNI with slices for rhythmic chain")
    
    if not xrni_filename or xrni_filename == "" then
      renoise.app():show_status("Operation cancelled - no XRNI selected")
      return
    end
    
    print("PakettiSlice: Loading XRNI: " .. xrni_filename)
    
    -- Load XRNI into temporary instrument
    temp_instrument_index = #song.instruments + 1
    song:insert_instrument_at(temp_instrument_index)
    song.selected_instrument_index = temp_instrument_index
    
    local load_success, load_error = pcall(function()
      renoise.app():load_instrument(xrni_filename)
    end)
    
    if not load_success then
      print("PakettiSlice: Failed to load XRNI: " .. tostring(load_error))
      renoise.app():show_status("Failed to load XRNI: " .. tostring(load_error))
      song:delete_instrument_at(temp_instrument_index)
      song.selected_instrument_index = original_instrument_index
      -- Loop back to try again
    else
      loaded_instrument = song.instruments[temp_instrument_index]
      
      -- Check if loaded instrument has slices
      if #loaded_instrument.samples == 0 then
        renoise.app():show_status("Loaded XRNI has no samples - please select another")
        song:delete_instrument_at(temp_instrument_index)
        song.selected_instrument_index = original_instrument_index
        -- Loop back to try again
      else
        loaded_first_sample = loaded_instrument.samples[1]
        if not loaded_first_sample.sample_buffer.has_sample_data then
          renoise.app():show_status("Loaded XRNI first sample has no data - please select another")
          song:delete_instrument_at(temp_instrument_index)
          song.selected_instrument_index = original_instrument_index
          -- Loop back to try again
        elseif #loaded_first_sample.slice_markers == 0 then
          renoise.app():show_status("Loaded XRNI has no slice markers - please select another")
          song:delete_instrument_at(temp_instrument_index)
          song.selected_instrument_index = original_instrument_index
          -- Loop back to try again
        else
          -- Valid XRNI with slices found!
          loaded_slice_count = #loaded_first_sample.slice_markers
          print(string.format("PakettiSlice: Loaded XRNI has %d slices", loaded_slice_count))
          break  -- Exit the while loop
        end
      end
    end
  end
  
  -- Extract slices from loaded XRNI
  local loaded_buffer = loaded_first_sample.sample_buffer
  local loaded_slices = {}
  
  for i = 1, loaded_slice_count do
    -- Each marker marks the START of a slice
    -- Slice i goes from marker[i] to marker[i+1] (or to end for last slice)
    local slice_start = loaded_first_sample.slice_markers[i]
    local slice_end
    
    if i < loaded_slice_count then
      -- Not the last slice: goes to next marker
      slice_end = loaded_first_sample.slice_markers[i + 1]
    else
      -- Last slice: goes to end of sample
      slice_end = loaded_buffer.number_of_frames
    end
    
    local slice_frames = slice_end - slice_start
    -- Ensure slice_frames is at least 1 frame (never 0)
    if slice_frames < 1 then
      slice_frames = 1
      print(string.format("PakettiSlice: WARNING - Loaded slice %d had 0 or negative duration, forcing to 1 frame", i))
    end
    local channel_data = {}
    
    for ch = 1, loaded_buffer.number_of_channels do
      channel_data[ch] = {}
      for frame = 1, slice_frames do
        channel_data[ch][frame] = loaded_buffer:sample_data(ch, slice_start + frame - 1)
      end
    end
    
    loaded_slices[i] = {
      data = channel_data,
      frames = slice_frames,
      channels = loaded_buffer.number_of_channels
    }
    
    print(string.format("PakettiSlice: Extracted loaded slice %d: %d frames", i, slice_frames))
  end
  
  -- Convert loaded slices to match source format if needed
  print("PakettiSlice: Converting loaded slices to match source format...")
  
  for i, slice_data in ipairs(loaded_slices) do
    -- Handle channel conversion
    if slice_data.channels ~= source_channels then
      print(string.format("PakettiSlice: Converting slice %d channels %d -> %d",
        i, slice_data.channels, source_channels))
      
      local new_channel_data = {}
      
      if source_channels == 1 and slice_data.channels == 2 then
        -- Stereo to mono
        new_channel_data[1] = {}
        for frame = 1, slice_data.frames do
          local left = slice_data.data[1][frame]
          local right = slice_data.data[2][frame]
          new_channel_data[1][frame] = (left + right) * 0.5
        end
      elseif source_channels == 2 and slice_data.channels == 1 then
        -- Mono to stereo
        new_channel_data[1] = {}
        new_channel_data[2] = {}
        for frame = 1, slice_data.frames do
          local mono_val = slice_data.data[1][frame]
          new_channel_data[1][frame] = mono_val
          new_channel_data[2][frame] = mono_val
        end
      end
      
      slice_data.data = new_channel_data
      slice_data.channels = source_channels
    end
  end
  
  -- Clean up temp instrument
  song:delete_instrument_at(temp_instrument_index)
  song.selected_instrument_index = original_instrument_index
  
  -- Process slices: cycle through loaded slices to match source slice count
  local processed_samples = {}
  
  for i = 1, source_slice_count do
    -- Cycle through loaded slices
    local loaded_slice_index = ((i - 1) % loaded_slice_count) + 1
    local source_slice = loaded_slices[loaded_slice_index]
    local target_duration = slice_durations[i]
    
    print(string.format("PakettiSlice: Processing source slice %d using loaded slice %d (target: %d frames)",
      i, loaded_slice_index, target_duration))
    
    -- Extract and process slice data
    local sample_frames = math.min(source_slice.frames, target_duration)
    local channel_data = {}
    
    for ch = 1, source_channels do
      channel_data[ch] = {}
      for frame = 1, sample_frames do
        local value = source_slice.data[ch][frame]
        
        -- Apply 10-frame fadeout at the end
        if frame > sample_frames - 10 then
          local fade_position = frame - (sample_frames - 10)
          local fade_factor = 1.0 - (fade_position / 10.0)
          value = value * fade_factor
        end
        
        channel_data[ch][frame] = value
      end
      
      -- Pad with silence if needed
      for frame = sample_frames + 1, target_duration do
        channel_data[ch][frame] = 0.0
      end
    end
    
    processed_samples[i] = {
      data = channel_data,
      frames = target_duration
    }
  end
  
  -- Calculate total chain length and slice marker positions
  local total_chain_frames = 0
  local chain_slice_markers = {}
  
  for i, processed in ipairs(processed_samples) do
    total_chain_frames = total_chain_frames + processed.frames
    if i < #processed_samples then
      -- Ensure marker position is never 0
      local marker_pos = total_chain_frames
      if marker_pos < 1 then
        marker_pos = 1
      end
      table.insert(chain_slice_markers, marker_pos)
    end
  end
  
  print(string.format("PakettiSlice: Total chain: %d frames with %d slice markers",
    total_chain_frames, #chain_slice_markers))
  
  -- Ensure total_chain_frames is at least 1 (never 0)
  if total_chain_frames < 1 then
    total_chain_frames = 1
    print("PakettiSlice: WARNING - Total chain frames was 0, forcing to 1 frame")
  end
  
  -- Create new instrument with chained sample
  local new_instrument_index = original_instrument_index + 1
  song:insert_instrument_at(new_instrument_index)
  song.selected_instrument_index = new_instrument_index
  
  -- Apply Paketti default XRNI template (pakettification)
  print("PakettiSlice: Applying Paketti default XRNI template...")
  pakettiPreferencesDefaultInstrumentLoader()
  
  local new_instrument = song.instruments[new_instrument_index]
  
  -- Delete any default samples from the template
  if #new_instrument.samples > 0 then
    for i = #new_instrument.samples, 1, -1 do
      new_instrument:delete_sample_at(i)
    end
    print("PakettiSlice: Cleared default template samples")
  end
  
  -- Create sample in new instrument
  new_instrument:insert_sample_at(1)
  local new_sample = new_instrument.samples[1]
  new_sample.name = "XRNI Rhythmic Chain"
  
  -- Create sample buffer
  new_sample.sample_buffer:create_sample_data(
    source_sample_rate,
    source_bit_depth,
    source_channels,
    total_chain_frames
  )
  
  -- Write chained data
  local write_position = 1
  for i, processed in ipairs(processed_samples) do
    for frame = 1, processed.frames do
      for ch = 1, source_channels do
        local value = processed.data[ch][frame] or 0.0
        new_sample.sample_buffer:set_sample_data(ch, write_position, value)
      end
      write_position = write_position + 1
    end
  end
  
  -- Apply slice markers
  local markers_added = 0
  for _, marker_position in ipairs(chain_slice_markers) do
    if marker_position > 0 and marker_position < total_chain_frames then
      new_sample:insert_slice_marker(marker_position)
      markers_added = markers_added + 1
      print(string.format("PakettiSlice: Added slice marker at position %d", marker_position))
    else
      print(string.format("PakettiSlice: Skipped invalid slice marker at position %d (total frames: %d)", 
        marker_position, total_chain_frames))
    end
  end
  
  print(string.format("PakettiSlice: Created new instrument with %d slices from XRNI (%d markers added)", 
    source_slice_count, markers_added))
  
  -- Select new instrument
  song.selected_instrument_index = new_instrument_index
  
  -- Apply Paketti loader settings to the chained sample
  print("PakettiSlice: Applying Paketti loader settings to chained sample...")
  PakettiInjectApplyLoaderSettings(new_sample)
  
  -- Normalize slices if requested
  if normalize_slices then
    print("PakettiSlice: Normalizing slices independently...")
    normalize_selected_sample_by_slices()
  end
  
  -- Set instrument name at the VERY END (after all processing)
  local original_name = instrument.name ~= "" and instrument.name or "Untitled"
  local xrni_name = loaded_instrument.name ~= "" and loaded_instrument.name or "Unknown"
  
  -- Strip any existing rhythmic suffix from original name to prevent flooding
  original_name = original_name:gsub(" %(.+rhythmic.+%)$", "")
  original_name = original_name:gsub(" %(.+XRNI.+%)$", "")
  
  new_instrument.name = string.format("%s (%s rhythmic slice)", original_name, xrni_name)
  
  print(string.format("PakettiSlice: Set instrument name to: %s", new_instrument.name))
  
  local status_msg = string.format("XRNI rhythmic chain created: %d slices from loaded XRNI (%d slices) (Pakettified", 
    source_slice_count, loaded_slice_count)
  if loaded_slice_count ~= source_slice_count then
    status_msg = status_msg .. string.format(" - cycled %dx", math.ceil(source_slice_count / loaded_slice_count))
  end
  if normalize_slices then
    status_msg = status_msg .. ", normalized"
  end
  status_msg = status_msg .. ")"
  renoise.app():show_status(status_msg)
end

-- Menu entries and keybindings for Rhythmic Slice DrumChain (without normalize)
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices",invoke = function() PakettiSliceCreateRhythmicDrumChain(false) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Create New Rhythmic Slice DrumChain with Current Slices",invoke = function() PakettiSliceCreateRhythmicDrumChain(false) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Create New Rhythmic Slice DrumChain with Current Slices",invoke = function() PakettiSliceCreateRhythmicDrumChain(false) end}
renoise.tool():add_keybinding{name = "Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices",invoke = function() PakettiSliceCreateRhythmicDrumChain(false) end}

-- Menu entries and keybindings for Rhythmic Slice DrumChain (with normalize)
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Normalized)",invoke = function() PakettiSliceCreateRhythmicDrumChain(true) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Normalized)",invoke = function() PakettiSliceCreateRhythmicDrumChain(true) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Normalized)",invoke = function() PakettiSliceCreateRhythmicDrumChain(true) end}
renoise.tool():add_keybinding{name = "Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Normalized)",invoke = function() PakettiSliceCreateRhythmicDrumChain(true) end}

-- Menu entries and keybindings for Rhythmic Slice DrumChain from XRNI (without normalize)
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Create New Rhythmic Slice DrumChain from XRNI",invoke = function() PakettiSliceCreateRhythmicDrumChainFromXRNI(false) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Create New Rhythmic Slice DrumChain from XRNI",invoke = function() PakettiSliceCreateRhythmicDrumChainFromXRNI(false) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Create New Rhythmic Slice DrumChain from XRNI",invoke = function() PakettiSliceCreateRhythmicDrumChainFromXRNI(false) end}
renoise.tool():add_keybinding{name = "Sample Editor:Paketti:Create New Rhythmic Slice DrumChain from XRNI",invoke = function() PakettiSliceCreateRhythmicDrumChainFromXRNI(false) end}

-- Menu entries and keybindings for Rhythmic Slice DrumChain from XRNI (with normalize)
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Create New Rhythmic Slice DrumChain from XRNI (Normalized)",invoke = function() PakettiSliceCreateRhythmicDrumChainFromXRNI(true) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Create New Rhythmic Slice DrumChain from XRNI (Normalized)",invoke = function() PakettiSliceCreateRhythmicDrumChainFromXRNI(true) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Create New Rhythmic Slice DrumChain from XRNI (Normalized)",invoke = function() PakettiSliceCreateRhythmicDrumChainFromXRNI(true) end}
renoise.tool():add_keybinding{name = "Sample Editor:Paketti:Create New Rhythmic Slice DrumChain from XRNI (Normalized)",invoke = function() PakettiSliceCreateRhythmicDrumChainFromXRNI(true) end}

-- Menu entries and keybindings for Rhythmic Slice DrumChain Randomize (without normalize)
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize)",invoke = function() PakettiSliceCreateRhythmicDrumChainRandomize(false) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize)",invoke = function() PakettiSliceCreateRhythmicDrumChainRandomize(false) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize)",invoke = function() PakettiSliceCreateRhythmicDrumChainRandomize(false) end}
renoise.tool():add_keybinding{name = "Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize)",invoke = function() PakettiSliceCreateRhythmicDrumChainRandomize(false) end}

-- Menu entries and keybindings for Rhythmic Slice DrumChain Randomize (with normalize)
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize) (Normalized)",invoke = function() PakettiSliceCreateRhythmicDrumChainRandomize(true) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize) (Normalized)",invoke = function() PakettiSliceCreateRhythmicDrumChainRandomize(true) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize) (Normalized)",invoke = function() PakettiSliceCreateRhythmicDrumChainRandomize(true) end}
renoise.tool():add_keybinding{name = "Sample Editor:Paketti:Create New Rhythmic Slice DrumChain with Current Slices (Randomize) (Normalized)",invoke = function() PakettiSliceCreateRhythmicDrumChainRandomize(true) end}

----------
-- Global variables for storing picked up slice markers
PakettiPickedUpSliceMarkers = nil
PakettiPickedUpSliceSampleRate = nil
PakettiPickedUpSliceOriginalLength = nil

-- Pick up slices from the current sample
function PakettiPickupSlices()
  local song = renoise.song()
  
  if not song.selected_sample then
    renoise.app():show_status("No sample selected, doing nothing.")
    return
  end
  
  local sample = song.selected_sample
  
  if not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Sample has no data, doing nothing.")
    return
  end
  
  if #sample.slice_markers == 0 then
    renoise.app():show_status("Sample has no slice markers, doing nothing.")
    return
  end
  
  -- Store the slice markers, sample rate, and original length
  PakettiPickedUpSliceMarkers = {}
  for _, marker in ipairs(sample.slice_markers) do
    table.insert(PakettiPickedUpSliceMarkers, marker)
  end
  
  PakettiPickedUpSliceSampleRate = sample.sample_buffer.sample_rate
  PakettiPickedUpSliceOriginalLength = sample.sample_buffer.number_of_frames
  
  renoise.app():show_status(string.format("Picked up %d slice markers from %dHz sample (%d frames).", 
    #PakettiPickedUpSliceMarkers, PakettiPickedUpSliceSampleRate, PakettiPickedUpSliceOriginalLength))
  
  print(string.format("=== Picked up slices ==="))
  print(string.format("Sample rate: %d Hz", PakettiPickedUpSliceSampleRate))
  print(string.format("Sample length: %d frames", PakettiPickedUpSliceOriginalLength))
  print(string.format("Number of markers: %d", #PakettiPickedUpSliceMarkers))
end

-- Apply picked up slices to the current sample with sample rate scaling
function PakettiApplySlicesBasedOnSampleRate()
  local song = renoise.song()
  
  print("=== Apply Slices with Same Relative Positioning ===")
  
  if not song.selected_sample then
    print("ERROR: No sample selected")
    renoise.app():show_status("No sample selected, doing nothing.")
    return
  end
  
  if not PakettiPickedUpSliceMarkers or #PakettiPickedUpSliceMarkers == 0 then
    print("ERROR: No slices picked up yet")
    renoise.app():show_status("No slices picked up yet. Use 'Pick up slices' first.")
    return
  end
  
  if not PakettiPickedUpSliceSampleRate or not PakettiPickedUpSliceOriginalLength then
    print("ERROR: No sample rate or length information available")
    renoise.app():show_status("No sample information available. Use 'Pick up slices' first.")
    return
  end
  
  local sample = song.selected_sample
  
  if not sample.sample_buffer.has_sample_data then
    print("ERROR: Target sample has no data")
    renoise.app():show_status("Target sample has no data, doing nothing.")
    return
  end
  
  local new_sample_rate = sample.sample_buffer.sample_rate
  local new_sample_length = sample.sample_buffer.number_of_frames
  
  print(string.format("Original sample rate: %d Hz", PakettiPickedUpSliceSampleRate))
  print(string.format("Original sample length: %d frames", PakettiPickedUpSliceOriginalLength))
  print(string.format("Target sample rate: %d Hz", new_sample_rate))
  print(string.format("Target sample length: %d frames", new_sample_length))
  print(string.format("Number of picked up markers: %d", #PakettiPickedUpSliceMarkers))
  
  -- Calculate the actual length ratio (frame count to frame count)
  local length_ratio = new_sample_length / PakettiPickedUpSliceOriginalLength
  print(string.format("Length ratio (frame count): %.6f", length_ratio))
  
  -- Also show what the sample rate ratio would be (for reference)
  local rate_ratio = new_sample_rate / PakettiPickedUpSliceSampleRate
  print(string.format("Sample rate ratio (reference): %.6f", rate_ratio))
  
  -- Calculate expected length if it was just sample rate conversion
  local expected_length = math.floor(PakettiPickedUpSliceOriginalLength * rate_ratio + 0.5)
  local length_difference = new_sample_length - expected_length
  print(string.format("Expected length (rate conversion): %d frames", expected_length))
  print(string.format("Actual length difference: %d frames (padding/processing)", length_difference))
  
  -- Scale markers based on ACTUAL frame count ratio
  local valid_markers = {}
  for i, marker in ipairs(PakettiPickedUpSliceMarkers) do
    -- Scale the marker position based on actual length ratio
    local scaled_marker = math.floor(marker * length_ratio + 0.5) -- Round to nearest frame
    -- Ensure scaled_marker is never 0
    if scaled_marker < 1 then
      scaled_marker = 1
      print(string.format("  Marker %d: %d -> %d (forced to 1, was 0)", i, marker, scaled_marker))
    else
      print(string.format("  Marker %d: %d -> %d (using length ratio: %.6f)", i, marker, scaled_marker, length_ratio))
    end
    if scaled_marker <= new_sample_length then
      table.insert(valid_markers, scaled_marker)
      print(string.format("    -> VALID (within %d frames)", new_sample_length))
    else
      print(string.format("    -> SKIPPED (exceeds %d frames)", new_sample_length))
    end
  end
  
  if #valid_markers == 0 then
    print("ERROR: No valid slice markers could be applied")
    renoise.app():show_status("No valid slice markers could be applied to this sample.")
    return
  end
  
  print(string.format("Total valid markers: %d", #valid_markers))
  
  -- Apply the scaled slice markers
  sample.slice_markers = valid_markers
  print("Slice markers applied successfully")
  
  -- Show info about the scaling
  local status_msg = string.format("Applied %d slice markers (length ratio: %.4f, %d->%d frames, %dHz->%dHz)", 
    #valid_markers, length_ratio, PakettiPickedUpSliceOriginalLength, new_sample_length,
    PakettiPickedUpSliceSampleRate, new_sample_rate)
  renoise.app():show_status(status_msg)
  print(status_msg)
  print("=== Done ===")
end

-- Random Slice Distribution
-- Distributes slices randomly across the selected track in the pattern
function PakettiRandomSliceDistribution()
  local song = renoise.song()
  local instrument = song.selected_instrument
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.selected_pattern_track
  local num_rows = pattern.number_of_lines
  
  -- Check if instrument has samples
  if #instrument.samples == 0 then
    renoise.app():show_status("No samples in selected instrument")
    return
  end
  
  -- Check if first sample has slices
  local first_sample = instrument.samples[1]
  if #first_sample.slice_markers == 0 then
    renoise.app():show_status("Selected instrument has no slices")
    return
  end
  
  -- Get the slice start note and count from sample mappings
  local slice_start_note = nil
  local slice_end_note = nil
  local slice_count = 0
  
  if instrument.sample_mappings[1] then
    local sample_mappings = instrument.sample_mappings[1]
    if #sample_mappings >= 2 then
      -- First slice mapping (index 2, since index 1 is the original sample)
      local first_slice_mapping = sample_mappings[2]
      if first_slice_mapping and first_slice_mapping.base_note then
        slice_start_note = first_slice_mapping.base_note
      end
      
      -- Count actual slice mappings (skip the first mapping which is the original sample)
      for i = 2, #sample_mappings do
        slice_count = slice_count + 1
        if sample_mappings[i] and sample_mappings[i].base_note then
          slice_end_note = sample_mappings[i].base_note
        end
      end
    end
  end
  
  -- Fallback: slices typically start one note above the original sample's base note
  if not slice_start_note and first_sample.sample_mapping and first_sample.sample_mapping.base_note then
    slice_start_note = first_sample.sample_mapping.base_note + 1
    slice_count = #first_sample.slice_markers + 1
  end
  
  if not slice_start_note or slice_count == 0 then
    renoise.app():show_status("Could not determine slice note mappings")
    return
  end
  
  print("Number of slices: " .. slice_count)
  print("Number of rows: " .. num_rows)
  print("Selected track: " .. track_index)
  print("Slice start note: " .. slice_start_note)
  
  -- Create a list of ALL slice note values (but only valid ones 0-119)
  local slice_notes = {}
  for i = 0, slice_count - 1 do
    local slice_note = slice_start_note + i
    if slice_note >= 0 and slice_note <= 119 then
      table.insert(slice_notes, slice_note)
    end
  end
  
  local valid_slice_count = #slice_notes
  
  if valid_slice_count == 0 then
    renoise.app():show_status("No valid slices within note range (0-119)")
    return
  end
  
  if valid_slice_count < slice_count then
    print(string.format("Warning: Only %d of %d slices fit in valid note range (0-119)", valid_slice_count, slice_count))
  end
  
  -- Shuffle the slice list using Fisher-Yates algorithm
  for i = #slice_notes, 2, -1 do
    local j = math.random(1, i)
    slice_notes[i], slice_notes[j] = slice_notes[j], slice_notes[i]
  end
  
  -- Clear the track first
  for i = 1, num_rows do
    local line = track:line(i)
    line:clear()
  end
  
  -- Calculate how many slices to write
  local slices_to_write = math.min(valid_slice_count, num_rows)
  
  -- Calculate equal spacing between slices
  local spacing = num_rows / slices_to_write
  
  -- If spacing is less than 2, just fill sequentially (too close together to spread)
  if spacing < 2 then
    for i = 1, slices_to_write do
      local row = i
      local slice_note = slice_notes[i]
      local line = track:line(row)
      local note_column = line.note_columns[1]
      
      -- Write the slice note and instrument
      note_column.note_value = slice_note
      note_column.instrument_value = song.selected_instrument_index - 1
      
      local notes = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
      local octave = math.floor(slice_note / 12)
      local note_name = notes[(slice_note % 12) + 1]
      print(string.format("Row %d: Note %s%d (value %d)", row, note_name, octave, slice_note))
    end
    renoise.app():show_status(string.format("Randomly distributed %d slices sequentially", slices_to_write))
  else
    -- Write the slices to the pattern at equal intervals
    for i = 1, slices_to_write do
      local row = math.floor((i - 1) * spacing) + 1
      local slice_note = slice_notes[i]
      local line = track:line(row)
      local note_column = line.note_columns[1]
      
      -- Write the slice note and instrument
      note_column.note_value = slice_note
      note_column.instrument_value = song.selected_instrument_index - 1
      
      local notes = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
      local octave = math.floor(slice_note / 12)
      local note_name = notes[(slice_note % 12) + 1]
      print(string.format("Row %d: Note %s%d (value %d)", row, note_name, octave, slice_note))
    end
    renoise.app():show_status(string.format("Randomly distributed %d slices across %d rows (spacing: %.2f)", slices_to_write, num_rows, spacing))
  end
end

-- Equal Slice Distribution
-- Distributes slices in order across the selected track in the pattern with equal spacing
function PakettiEqualSliceDistribution()
  local song = renoise.song()
  local instrument = song.selected_instrument
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.selected_pattern_track
  local num_rows = pattern.number_of_lines
  
  -- Check if instrument has samples
  if #instrument.samples == 0 then
    renoise.app():show_status("No samples in selected instrument")
    return
  end
  
  -- Check if first sample has slices
  local first_sample = instrument.samples[1]
  if #first_sample.slice_markers == 0 then
    renoise.app():show_status("Selected instrument has no slices")
    return
  end
  
  -- Get the slice start note and count from sample mappings
  local slice_start_note = nil
  local slice_end_note = nil
  local slice_count = 0
  
  if instrument.sample_mappings[1] then
    local sample_mappings = instrument.sample_mappings[1]
    if #sample_mappings >= 2 then
      -- First slice mapping (index 2, since index 1 is the original sample)
      local first_slice_mapping = sample_mappings[2]
      if first_slice_mapping and first_slice_mapping.base_note then
        slice_start_note = first_slice_mapping.base_note
      end
      
      -- Count actual slice mappings (skip the first mapping which is the original sample)
      for i = 2, #sample_mappings do
        slice_count = slice_count + 1
        if sample_mappings[i] and sample_mappings[i].base_note then
          slice_end_note = sample_mappings[i].base_note
        end
      end
    end
  end
  
  -- Fallback: slices typically start one note above the original sample's base note
  if not slice_start_note and first_sample.sample_mapping and first_sample.sample_mapping.base_note then
    slice_start_note = first_sample.sample_mapping.base_note + 1
    slice_count = #first_sample.slice_markers + 1
  end
  
  if not slice_start_note or slice_count == 0 then
    renoise.app():show_status("Could not determine slice note mappings")
    return
  end
  
  print("Number of slices: " .. slice_count)
  print("Number of rows: " .. num_rows)
  print("Selected track: " .. track_index)
  print("Slice start note: " .. slice_start_note)
  
  -- Create a list of ALL slice note values in order (but only valid ones 0-121)
  local slice_notes = {}
  for i = 0, slice_count - 1 do
    local slice_note = slice_start_note + i
    if slice_note >= 0 and slice_note <= 121 then
      table.insert(slice_notes, slice_note)
    end
  end
  
  local valid_slice_count = #slice_notes
  
  if valid_slice_count == 0 then
    renoise.app():show_status("No valid slices within note range (0-121)")
    return
  end
  
  if valid_slice_count < slice_count then
    print(string.format("Warning: Only %d of %d slices fit in valid note range (0-121)", valid_slice_count, slice_count))
  end
  
  -- Clear the track first
  for i = 1, num_rows do
    local line = track:line(i)
    line:clear()
  end
  
  -- Calculate how many slices to write
  local slices_to_write = math.min(valid_slice_count, num_rows)
  
  -- Calculate equal spacing between slices
  local spacing = num_rows / slices_to_write
  
  -- If spacing is less than 2, just fill sequentially (too close together to spread)
  if spacing < 2 then
    for i = 1, slices_to_write do
      local row = i
      local slice_note = slice_notes[i]
      local line = track:line(row)
      local note_column = line.note_columns[1]
      
      -- Write the slice note and instrument
      note_column.note_value = slice_note
      note_column.instrument_value = song.selected_instrument_index - 1
      
      local notes = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
      local octave = math.floor(slice_note / 12)
      local note_name = notes[(slice_note % 12) + 1]
      print(string.format("Row %d: Note %s%d (value %d)", row, note_name, octave, slice_note))
    end
    renoise.app():show_status(string.format("Distributed %d slices in order sequentially", slices_to_write))
  else
    -- Write the slices to the pattern at equal intervals
    for i = 1, slices_to_write do
      local row = math.floor((i - 1) * spacing) + 1
      local slice_note = slice_notes[i]
      local line = track:line(row)
      local note_column = line.note_columns[1]
      
      -- Write the slice note and instrument
      note_column.note_value = slice_note
      note_column.instrument_value = song.selected_instrument_index - 1
      
      local notes = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
      local octave = math.floor(slice_note / 12)
      local note_name = notes[(slice_note % 12) + 1]
      print(string.format("Row %d: Note %s%d (value %d)", row, note_name, octave, slice_note))
    end
    renoise.app():show_status(string.format("Distributed %d slices in order across %d rows (spacing: %.2f)", slices_to_write, num_rows, spacing))
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Random Slice Distribution",invoke=function() PakettiRandomSliceDistribution() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Slices..:Random Slice Distribution",invoke=function() PakettiRandomSliceDistribution() end}
renoise.tool():add_midi_mapping{name="Paketti:Random Slice Distribution",invoke=function(message) if message:is_trigger() then PakettiRandomSliceDistribution() end end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Equal Slice Distribution",invoke=function() PakettiEqualSliceDistribution() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Slices..:Equal Slice Distribution",invoke=function() PakettiEqualSliceDistribution() end}
renoise.tool():add_midi_mapping{name="Paketti:Equal Slice Distribution",invoke=function(message) if message:is_trigger() then PakettiEqualSliceDistribution() end end}
