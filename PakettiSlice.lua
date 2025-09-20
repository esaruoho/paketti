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
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Delete Slice Markers in Selection",invoke=function() pakettiDeleteSliceMarkersInSelection() end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Delete Slice Markers in Selection",invoke=function() pakettiDeleteSliceMarkersInSelection() end}
renoise.tool():add_midi_mapping{name="Paketti:Delete Slice Markers in Selection",invoke=function(message) if message:is_trigger() then pakettiDeleteSliceMarkersInSelection() end end}


renoise.tool():add_keybinding{name="Global:Paketti:Wipe&Slice&Write to Pattern",invoke = function() WipeSliceAndWrite() end}

function WipeSliceAndWrite()
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
      s.instruments[currInst].samples[currSamp]:insert_slice_marker(tw * i)
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

local dialogMargin=175
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
    value = current_bpm,
    width = 60,
    notifier = function(value)
      song.transport.bpm = value
      print("MODIFIED BPM to: " .. value)
    end
  }
  
  local lpb_valuebox = vb:valuebox{
    min = 1,
    max = 256,
    value = current_lpb,
    width = 60,
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
    width = dialogMargin,
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
    width = dialogMargin,
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
    width = dialogMargin,
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

renoise.tool():add_keybinding{name="Global:Paketti:Create Pattern Sequencer Patterns based on Slice Count with Automatic Slice Printing",invoke = createPatternSequencerPatternsBasedOnSliceCount}
renoise.tool():add_keybinding{name="Global:Paketti:Slice to Pattern Sequencer Dialog...",invoke = showSliceToPatternSequencerInterface}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Slice to Pattern Sequencer Dialog...",invoke = showSliceToPatternSequencerInterface}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Slice to Pattern Sequencer Dialog...",invoke = showSliceToPatternSequencerInterface}


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
        if slice_position < total_frames then
            sample:insert_slice_marker(slice_position)
            print("Created slice marker " .. (i + 1) .. " at frame " .. slice_position)
        end
    end
    
    renoise.app():show_status("Sliced to " .. beats_per_slice .. " beats per slice at " .. sample_bpm .. " BPM (" .. #sample.slice_markers .. " slices)")
    focus_sample_editor()
end

-- Wrapper functions for common beat counts
function pakettiBPMBasedSlice1Beat(sample_bpm)
    pakettiBPMBasedSlice(sample_bpm, 1)
end

function pakettiBPMBasedSlice2Beats(sample_bpm)
    pakettiBPMBasedSlice(sample_bpm, 2)
end

function pakettiBPMBasedSlice4Beats(sample_bpm)
    pakettiBPMBasedSlice(sample_bpm, 4)
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
        width = 60
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
            text = "1/4",
            width = 40,
            notifier = function()
                beats_valuebox.value = 0.25
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
            text = "4",
            width = 40,
            notifier = function()
                beats_valuebox.value = 4
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
    
    -- Refresh button
    local refresh_button = vb:button{
        text = "Refresh Info",
        width = dialogMargin / 2,
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
        width = dialogMargin / 2,
        notifier = function()
            bpm_valuebox.value = song.transport.bpm
            status_text.text = "Set to song BPM: " .. song.transport.bpm
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
                    copy_bpm_button
                }
            }
        },
        
        vb:column{
            vb:row{
                vb:text{text = "Sample BPM:", width = 80, font = "bold", style = "strong"},
                bpm_valuebox,
                vb:text{text = "Beats per Slice:", width = 100, font = "bold", style = "strong"},
                beats_valuebox
            },
            vb:row{
                vb:text{text = "Presets:", width = 60, font = "bold", style = "strong"},
                preset_buttons
            },
            slice_button,
            create_patterns_button
        },
        
        vb:horizontal_aligner{
            mode = "center",
            vb:column{
                vb:text{text = "Status:", font = "bold", style = "strong"},
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
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:BPM-Based Sample Slicer Dialog...",invoke = showBPMBasedSliceDialog}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:BPM-Based Sample Slicer Dialog...",invoke = showBPMBasedSliceDialog}
renoise.tool():add_midi_mapping{name="Paketti:BPM-Based Sample Slicer Dialog",invoke=function(message) if message:is_trigger() then showBPMBasedSliceDialog() end end}
