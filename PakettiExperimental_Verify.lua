-- Additive Record Follow Pattern Tool
additive_record_follow = {
  is_active = false,
  last_pattern_index = 0,
  observer = nil,
  dialog = nil
}

function additive_record_follow:toggle()
  if self.is_active then
    self:deactivate()
  else
    self:activate()
  end
end

function additive_record_follow:activate()
  local song = renoise.song()
  local transport = song.transport
  
  -- Store current pattern index AND pattern length for reuse
  self.last_pattern_index = song.selected_pattern_index
  self.base_pattern_length = song.patterns[song.selected_pattern_index].number_of_lines
  
  -- Set up transport settings (F5-style playback start)
  local startpos = transport.playback_pos
  
  -- Panic first to ensure clean state
  if transport.playing then 
    transport:panic() 
    ResetAllSteppers() 
  end
  
  -- Set playback position to current sequence, line 1 (for jamming)
  startpos.line = 1
  -- Keep current sequence position (don't change startpos.sequence)
  transport.playback_pos = startpos
  
  -- Configure transport settings (but NOT follow_player yet)
  transport.edit_mode = true
  transport.wrapped_pattern_edit = false
  transport.loop_pattern = false
  transport.loop_block_enabled = false
  
  -- Add delay after panic (like F5)
  local start_time = os.clock()
  while (os.clock() - start_time < 0.225) do
    -- Delay the start after panic
  end
  
  -- Start playback from the set position FIRST
  transport:start_at(startpos)
  
  -- THEN enable follow_player to avoid jumping to playhead position
  transport.follow_player = true
  
  -- Add observer for pattern changes
  if not song.selected_pattern_index_observable:has_notifier(self.on_pattern_change) then
    song.selected_pattern_index_observable:add_notifier(self.on_pattern_change)
  end
  
  -- IMMEDIATELY add a new pattern with same length at next sequence position
  local sequencer = song.sequencer
  local current_seq_pos = transport.playback_pos.sequence
  local new_pattern_index = sequencer:insert_new_pattern_at(current_seq_pos + 1)
  
  -- Set the new pattern's length to match the original pattern
  song.patterns[new_pattern_index].number_of_lines = self.base_pattern_length
  
  self.is_active = true
  renoise.app():show_status("Additive Record Follow Pattern: ACTIVE - Added " .. self.base_pattern_length .. "-line pattern #" .. new_pattern_index)
  print("Additive Record Follow Pattern: ACTIVATED - Added " .. self.base_pattern_length .. "-line pattern #" .. new_pattern_index .. " at position " .. (current_seq_pos + 1))
end

function additive_record_follow:deactivate()
  local song = renoise.song()
  
  -- Remove observer
  if song.selected_pattern_index_observable:has_notifier(self.on_pattern_change) then
    song.selected_pattern_index_observable:remove_notifier(self.on_pattern_change)
  end
  
  self.is_active = false
  renoise.app():show_status("Additive Record Follow Pattern: INACTIVE")
  print("Additive Record Follow Pattern: DEACTIVATED")
end

function additive_record_follow:on_pattern_change()
  print("DEBUG: Pattern change detected, is_active =", additive_record_follow.is_active)
  
  if not additive_record_follow.is_active then
    print("DEBUG: Tool is not active, ignoring pattern change")
    return
  end
  
  local song = renoise.song()
  local current_pattern_index = song.selected_pattern_index
  
  print("DEBUG: Current pattern index:", current_pattern_index, "Last:", additive_record_follow.last_pattern_index)
  
  -- Only add if we've actually changed patterns
  if current_pattern_index ~= additive_record_follow.last_pattern_index then
    additive_record_follow.last_pattern_index = current_pattern_index
    
    -- Find where we are in the sequence
    local sequencer = song.sequencer
    local current_seq_pos = song.transport.playback_pos.sequence
    
    print("DEBUG: About to insert new " .. additive_record_follow.base_pattern_length .. "-line pattern at position", current_seq_pos + 1)
    
    -- Insert new pattern with same length after current position
    local new_pattern_index = sequencer:insert_new_pattern_at(current_seq_pos + 1)
    song.patterns[new_pattern_index].number_of_lines = additive_record_follow.base_pattern_length
    
    print("Additive Record Follow Pattern: Added " .. additive_record_follow.base_pattern_length .. "-line pattern #" .. new_pattern_index .. " at sequence position " .. (current_seq_pos + 1))
    renoise.app():show_status("Added " .. additive_record_follow.base_pattern_length .. "-line pattern #" .. new_pattern_index)
  else
    print("DEBUG: Pattern index unchanged, not adding new pattern")
  end
end



function additive_record_follow:show_dialog()
  if self.dialog and self.dialog.visible then
    self.dialog:close()
    self.dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  
  local dialog_content = vb:column{
    margin = 10,
    spacing = 10,
    
    vb:text{
      text = "Additive Record Follow Pattern",
      font = "bold"
    },
    
    vb:text{
      text = "Automatically adds new patterns with the same\nlength when you switch patterns during recording."
    },
    
    vb:horizontal_aligner{
      mode = "center",
      vb:button{
        text = self.is_active and "Deactivate" or "Activate",
        width = 100,
        notifier = function()
          self:toggle()
          if self.dialog and self.dialog.visible then
            self.dialog:close()
            self.dialog = nil
          end
        end
      }
    },
    
    vb:horizontal_aligner{
      mode = "center",
      vb:text{
        text = "Status: ",
        font = "bold"
      },
      vb:text{
        text = self.is_active and "ACTIVE" or "INACTIVE",
        style = self.is_active and "strong" or "normal"
      }
    },
    
          vb:text{
        text = "When active:\n• Follow Player: ON\n• Edit Mode: ON\n• Pattern Loop: OFF\n• Playback starts from current sequence, line 1\n• New patterns inherit original pattern length"
      }
  }
  
  -- Create keyhandler that can manage dialog variable
  local keyhandler = create_keyhandler_for_dialog(
    function() return self.dialog end,
    function(value) self.dialog = value end
  )
  
  self.dialog = renoise.app():show_custom_dialog(
    "Additive Record Follow Pattern", 
    dialog_content, 
    keyhandler
  )
end

-- Simple toggle function without dialog
function pakettiAdditiveRecordFollowToggle()
  additive_record_follow:toggle()
end

-- Add menu entries and keybindings
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Pattern/Phrase:Additive Record Follow Pattern (Dialog)",
  invoke = function() additive_record_follow:show_dialog() end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Pattern/Phrase:Additive Record Follow Pattern (Toggle)",
  invoke = function() pakettiAdditiveRecordFollowToggle() end
}

renoise.tool():add_menu_entry{
  name = "Pattern Editor:Pattern/Phrase:Additive Record Follow Pattern (Dialog)",
  invoke = function() additive_record_follow:show_dialog() end
}

renoise.tool():add_menu_entry{
  name = "Pattern Editor:Pattern/Phrase:Additive Record Follow Pattern (Toggle)",
  invoke = function() pakettiAdditiveRecordFollowToggle() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Toggle Additive Record Follow Pattern",
  invoke = function() pakettiAdditiveRecordFollowToggle() end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Additive Record Follow Pattern (Dialog)",
  invoke = function() additive_record_follow:show_dialog() end
}

-- Cleanup on song change
renoise.tool().app_release_document_observable:add_notifier(function()
  if additive_record_follow.is_active then
    additive_record_follow:deactivate()
  end
  if additive_record_follow.dialog and additive_record_follow.dialog.visible then
    additive_record_follow.dialog:close()
    additive_record_follow.dialog = nil
  end
end)








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
    margin = 10,
    vb:horizontal_aligner{
      mode = "center",
      vb:column{
        --spacing = 5,
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
      vb:space{ height=10 },
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
        create_patterns_button
    },
    
    vb:horizontal_aligner{
      mode = "center",
      vb:column{
        --spacing = 5,
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
----
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






-- Hide All Unused Columns Feature
function PakettiHideAllUnusedColumns()
  local song = renoise.song()
  local total_tracks_processed = 0
  local total_columns_hidden = 0
  
  print("=== PAKETTI HIDE UNUSED COLUMNS DEBUG ===")
  
  -- Process all sequencer tracks
  for track_index = 1, song.sequencer_track_count do
    local track = song.tracks[track_index]
    local track_columns_hidden = 0
    
    print(string.format("Processing Track %d: %s", track_index, track.name))
    
    -- Only process sequencer tracks
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    
      -- Check note columns usage across all patterns
      local note_columns_used = {}
      for col = 1, track.max_note_columns do
        note_columns_used[col] = false
      end
    
      -- Check effect columns usage across all patterns
      local effect_columns_used = {}
      for col = 1, track.max_effect_columns do
        effect_columns_used[col] = false
      end
    
      -- Check special columns usage across all patterns
      local delay_column_used = false
      local volume_column_used = false
      local panning_column_used = false
      local sample_effects_column_used = false
    
      -- Scan all patterns for this track
      for pattern_index = 1, #song.patterns do
        local pattern = song.patterns[pattern_index]
        local pattern_track = pattern.tracks[track_index]
        
        -- Scan all lines in this pattern
        for line_index = 1, pattern.number_of_lines do
          local line = pattern_track:line(line_index)
          
          -- Check note columns
          for col = 1, #line.note_columns do
            local note_col = line.note_columns[col]
            if note_col.note_string ~= "---" or 
               note_col.instrument_value ~= 255 or
               note_col.volume_value ~= 255 or
               note_col.panning_value ~= 255 or
               note_col.delay_value ~= 0 or
               note_col.effect_number_value ~= 0 or
               note_col.effect_amount_value ~= 0 then
              note_columns_used[col] = true
            end
            
            -- Check special columns within note columns
            if note_col.delay_value ~= 0 then
              delay_column_used = true
            end
            if note_col.volume_value ~= 255 then
              volume_column_used = true
            end
            if note_col.panning_value ~= 255 then
              panning_column_used = true
            end
            if note_col.effect_number_value ~= 0 or note_col.effect_amount_value ~= 0 then
              sample_effects_column_used = true
            end
          end
          
          -- Check effect columns
          for col = 1, #line.effect_columns do
            local effect_col = line.effect_columns[col]
            if effect_col.number_string ~= "00" or effect_col.amount_value ~= 0 then
              effect_columns_used[col] = true
            end
          end
        end
      end
      
      -- Now hide unused columns for this track
      
      -- Hide unused note columns (count from the end)
      local last_used_note_col = 0
      for col = track.max_note_columns, 1, -1 do
        if note_columns_used[col] then
          last_used_note_col = col
          break
        end
      end
      
      if last_used_note_col < track.visible_note_columns then
        local old_visible = track.visible_note_columns
        track.visible_note_columns = math.max(1, last_used_note_col) -- At least 1 note column
        local hidden = old_visible - track.visible_note_columns
        track_columns_hidden = track_columns_hidden + hidden
        print(string.format("  Note columns: %d -> %d (hidden %d)", old_visible, track.visible_note_columns, hidden))
      end
      
      -- Hide unused effect columns (count from the end)
      local last_used_effect_col = 0
      for col = track.max_effect_columns, 1, -1 do
        if effect_columns_used[col] then
          last_used_effect_col = col
          break
        end
      end
      
      if last_used_effect_col < track.visible_effect_columns then
        local old_visible = track.visible_effect_columns
        track.visible_effect_columns = last_used_effect_col
        local hidden = old_visible - track.visible_effect_columns
        track_columns_hidden = track_columns_hidden + hidden
        print(string.format("  Effect columns: %d -> %d (hidden %d)", old_visible, track.visible_effect_columns, hidden))
      end
      
      -- Hide unused special columns
      if not delay_column_used and track.delay_column_visible then
        track.delay_column_visible = false
        track_columns_hidden = track_columns_hidden + 1
        print("  Hidden delay column")
      end
      
      if not volume_column_used and track.volume_column_visible then
        track.volume_column_visible = false
        track_columns_hidden = track_columns_hidden + 1
        print("  Hidden volume column")
      end
      
      if not panning_column_used and track.panning_column_visible then
        track.panning_column_visible = false
        track_columns_hidden = track_columns_hidden + 1
        print("  Hidden panning column")
      end
      
      if not sample_effects_column_used and track.sample_effects_column_visible then
        track.sample_effects_column_visible = false
        track_columns_hidden = track_columns_hidden + 1
        print("  Hidden sample effects column")
      end
      
      total_columns_hidden = total_columns_hidden + track_columns_hidden
      total_tracks_processed = total_tracks_processed + 1
      
      print(string.format("  Track %d summary: %d columns hidden", track_index, track_columns_hidden))
    end
  end
  
  print(string.format("=== SUMMARY: Processed %d tracks, hidden %d total columns ===", total_tracks_processed, total_columns_hidden))
  renoise.app():show_status(string.format("Hide Unused Columns: processed %d tracks, hidden %d columns", total_tracks_processed, total_columns_hidden))
end

function PakettiHideAllUnusedColumnsSelectedTrack()
  local song = renoise.song()
  local track = song.selected_track
  local track_index = song.selected_track_index
  
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Selected track is not a sequencer track")
    return
  end
  
  local track_columns_hidden = 0
  
  print(string.format("=== PROCESSING SELECTED TRACK %d: %s ===", track_index, track.name))
  
  -- Check note columns usage across all patterns
  local note_columns_used = {}
  for col = 1, track.max_note_columns do
    note_columns_used[col] = false
  end
  
  -- Check effect columns usage across all patterns
  local effect_columns_used = {}
  for col = 1, track.max_effect_columns do
    effect_columns_used[col] = false
  end
  
  -- Check special columns usage across all patterns
  local delay_column_used = false
  local volume_column_used = false
  local panning_column_used = false
  local sample_effects_column_used = false
  
  -- Scan all patterns for this track
  for pattern_index = 1, #song.patterns do
    local pattern = song.patterns[pattern_index]
    local pattern_track = pattern.tracks[track_index]
    
    -- Scan all lines in this pattern
    for line_index = 1, pattern.number_of_lines do
      local line = pattern_track:line(line_index)
      
      -- Check note columns
      for col = 1, #line.note_columns do
        local note_col = line.note_columns[col]
        if note_col.note_string ~= "---" or 
           note_col.instrument_value ~= 255 or
           note_col.volume_value ~= 255 or
           note_col.panning_value ~= 255 or
           note_col.delay_value ~= 0 or
           note_col.effect_number_value ~= 0 or
           note_col.effect_amount_value ~= 0 then
          note_columns_used[col] = true
        end
        
        -- Check special columns within note columns
        if note_col.delay_value ~= 0 then
          delay_column_used = true
        end
        if note_col.volume_value ~= 255 then
          volume_column_used = true
        end
        if note_col.panning_value ~= 255 then
          panning_column_used = true
        end
        if note_col.effect_number_value ~= 0 or note_col.effect_amount_value ~= 0 then
          sample_effects_column_used = true
        end
      end
      
      -- Check effect columns
      for col = 1, #line.effect_columns do
        local effect_col = line.effect_columns[col]
        if effect_col.number_string ~= "00" or effect_col.amount_value ~= 0 then
          effect_columns_used[col] = true
        end
      end
    end
  end
  
  -- Now hide unused columns for this track
  
  -- Hide unused note columns (count from the end)
  local last_used_note_col = 0
  for col = track.max_note_columns, 1, -1 do
    if note_columns_used[col] then
      last_used_note_col = col
      break
    end
  end
  
  if last_used_note_col < track.visible_note_columns then
    local old_visible = track.visible_note_columns
    track.visible_note_columns = math.max(1, last_used_note_col) -- At least 1 note column
    local hidden = old_visible - track.visible_note_columns
    track_columns_hidden = track_columns_hidden + hidden
    print(string.format("Note columns: %d -> %d (hidden %d)", old_visible, track.visible_note_columns, hidden))
  end
  
  -- Hide unused effect columns (count from the end)
  local last_used_effect_col = 0
  for col = track.max_effect_columns, 1, -1 do
    if effect_columns_used[col] then
      last_used_effect_col = col
      break
    end
  end
  
  if last_used_effect_col < track.visible_effect_columns then
    local old_visible = track.visible_effect_columns
    track.visible_effect_columns = last_used_effect_col
    local hidden = old_visible - track.visible_effect_columns
    track_columns_hidden = track_columns_hidden + hidden
    print(string.format("Effect columns: %d -> %d (hidden %d)", old_visible, track.visible_effect_columns, hidden))
  end
  
  -- Hide unused special columns
  if not delay_column_used and track.delay_column_visible then
    track.delay_column_visible = false
    track_columns_hidden = track_columns_hidden + 1
    print("Hidden delay column")
  end
  
  if not volume_column_used and track.volume_column_visible then
    track.volume_column_visible = false
    track_columns_hidden = track_columns_hidden + 1
    print("Hidden volume column")
  end
  
  if not panning_column_used and track.panning_column_visible then
    track.panning_column_visible = false
    track_columns_hidden = track_columns_hidden + 1
    print("Hidden panning column")
  end
  
  if not sample_effects_column_used and track.sample_effects_column_visible then
    track.sample_effects_column_visible = false
    track_columns_hidden = track_columns_hidden + 1
    print("Hidden sample effects column")
  end
  
  print(string.format("=== SELECTED TRACK SUMMARY: %d columns hidden ===", track_columns_hidden))
  renoise.app():show_status(string.format("Hide Unused Columns (Selected Track): hidden %d columns", track_columns_hidden))
end

renoise.tool():add_keybinding{name="Global:Paketti:Hide All Unused Columns (All Tracks)", invoke=function() PakettiHideAllUnusedColumns() end}
renoise.tool():add_keybinding{name="Global:Paketti:Hide All Unused Columns (Selected Track)", invoke=function() PakettiHideAllUnusedColumnsSelectedTrack() end}
-------
-- Function to write notes in specified order (ascending, descending, or random)
function writeNotesMethod(method)
  local song=renoise.song()
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(song.selected_track_index)
  local instrument = song.selected_instrument
  local current_line = song.selected_line_index
  local selected_note_column = song.selected_note_column_index
  
  if not instrument or not instrument.sample_mappings[1] then
    renoise.app():show_status("No sample mappings found for this instrument")
    return
  end
  
  -- Create a table of all mapped notes
  local notes = {}
  for _, mapping in ipairs(instrument.sample_mappings[1]) do
    if mapping.note_range then
      for i = mapping.note_range[1], mapping.note_range[2] do
        table.insert(notes, {
          note = i,
          mapping = mapping
        })
      end
    end
  end
  
  if #notes == 0 then
    renoise.app():show_status("No valid sample mappings found for this instrument")
    return
  end
  
  -- Sort or shuffle based on method
  if method == "ascending" then
    table.sort(notes, function(a, b) return a.note < b.note end)
  elseif method == "descending" then
    table.sort(notes, function(a, b) return a.note > b.note end)
  elseif method == "random" then
    -- Fisher-Yates shuffle
    for i = #notes, 2, -1 do
      local j = math.random(i)
      notes[i], notes[j] = notes[j], notes[i]
    end
  end
  
  local last_note = -1
  local last_mapping = nil
  
  -- Write the notes
  for i = 1, #notes do
    if current_line <= pattern.number_of_lines then
      local note_column = track:line(current_line):note_column(selected_note_column)
      note_column.note_value = notes[i].note
      note_column.instrument_value = song.selected_instrument_index - 1
      current_line = current_line + 1
      last_note = notes[i].note
      last_mapping = notes[i].mapping
    else
      break
    end
  end
  
  if last_note ~= -1 and last_mapping then
    local note_name = note_value_to_string(last_note)
    renoise.app():show_status(string.format(
      "Wrote notes until row %d at note %s (base note: %d)", 
      current_line - 1, 
      note_name,
      last_mapping.base_note
    ))
  end
end

-- Function to write notes in specified order with EditStep (ascending, descending, or random)
function writeNotesMethodEditStep(method)
  local song=renoise.song()
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(song.selected_track_index)
  local instrument = song.selected_instrument
  local current_line = song.selected_line_index
  local selected_note_column = song.selected_note_column_index
  local edit_step = song.transport.edit_step
  
  -- If edit_step is 0, treat it as 1 (write to every row)
  if edit_step == 0 then
    edit_step = 1
  end
  
  if not instrument or not instrument.sample_mappings[1] then
    renoise.app():show_status("No sample mappings found for this instrument")
    return
  end
  
  -- Create a table of all mapped notes
  local notes = {}
  for _, mapping in ipairs(instrument.sample_mappings[1]) do
    if mapping.note_range then
      for i = mapping.note_range[1], mapping.note_range[2] do
        table.insert(notes, {
          note = i,
          mapping = mapping
        })
      end
    end
  end
  
  if #notes == 0 then
    renoise.app():show_status("No valid sample mappings found for this instrument")
    return
  end
  
  -- Sort or shuffle based on method
  if method == "ascending" then
    table.sort(notes, function(a, b) return a.note < b.note end)
  elseif method == "descending" then
    table.sort(notes, function(a, b) return a.note > b.note end)
  elseif method == "random" then
    -- Fisher-Yates shuffle
    for i = #notes, 2, -1 do
      local j = math.random(i)
      notes[i], notes[j] = notes[j], notes[i]
    end
  end
  
  -- First, clear all existing notes in the selected note column from current line to end of pattern
  for line_index = current_line, pattern.number_of_lines do
    local note_column = track:line(line_index):note_column(selected_note_column)
    note_column.note_value = renoise.PatternLine.EMPTY_NOTE
    note_column.instrument_value = renoise.PatternLine.EMPTY_INSTRUMENT
    note_column.volume_value = renoise.PatternLine.EMPTY_VOLUME
    note_column.panning_value = renoise.PatternLine.EMPTY_PANNING
    note_column.delay_value = renoise.PatternLine.EMPTY_DELAY
    note_column.effect_number_value = renoise.PatternLine.EMPTY_EFFECT_NUMBER
    note_column.effect_amount_value = renoise.PatternLine.EMPTY_EFFECT_AMOUNT
  end
  
  local last_note = -1
  local last_mapping = nil
  local write_line = current_line
  
  -- Write the notes using EditStep
  for i = 1, #notes do
    if write_line <= pattern.number_of_lines then
      local note_column = track:line(write_line):note_column(selected_note_column)
      -- Write the new note
      note_column.note_value = notes[i].note
      note_column.instrument_value = song.selected_instrument_index - 1
      write_line = write_line + edit_step
      last_note = notes[i].note
      last_mapping = notes[i].mapping
    else
      break
    end
  end
  
  if last_note ~= -1 and last_mapping then
    local note_name = note_value_to_string(last_note)
    renoise.app():show_status(string.format(
      "Cleared and wrote notes with EditStep %d until row %d at note %s (base note: %d)", 
      edit_step,
      write_line - edit_step, 
      note_name,
      last_mapping.base_note
    ))
  end
end

-- Helper function to convert note value to string
function note_value_to_string(value)
  local notes = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
  local octave = math.floor(value / 12)
  local note = notes[(value % 12) + 1]
  return note .. octave
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Notes Ascending",invoke=function() writeNotesMethod("ascending") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Notes Descending",invoke=function() writeNotesMethod("descending") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Notes Random",invoke=function() writeNotesMethod("random") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Notes EditStep Ascending",invoke=function() writeNotesMethodEditStep("ascending") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Notes EditStep Descending",invoke=function() writeNotesMethodEditStep("descending") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Write Notes EditStep Random",invoke=function() writeNotesMethodEditStep("random") end}




-- Function to ensure EQ10 exists on selected track and return its index
local function ensure_eq10_exists()
  local song=renoise.song()
  local track = song.selected_track
  
  -- First check if EQ10 already exists
  for i, device in ipairs(track.devices) do
    if device.name == "EQ 10" then
      -- Show the device in DSP chain
      device.is_maximized = true
      return i
    end
  end
  
  -- If not found, add EQ10 after the track volume device
  loadnative("Audio/Effects/Native/EQ 10")
  
  -- Find the newly added EQ10
  for i, device in ipairs(track.devices) do
    if device.name == "EQ 10" then
      device.is_maximized = true
      return i
    end
  end
  
  return nil
end

-- Function to get current EQ10 parameters
local function get_eq10_params(device)
  local params = {}
  for i = 1, 10 do
    params[i] = {
      gain = device.parameters[i].value,              -- Gains are parameters 1-10
      freq = device.parameters[i + 10].value,         -- Frequencies are parameters 11-20
      bandwidth=device.parameters[i + 20].value     -- Bandwidths are parameters 21-30
    }
  end
  return params
end

-- Function to normalize gain value to 0-1 range
local function normalize_gain(gain)
  -- EQ10 gain range is -12 to +12
  local normalized = (gain + 12) / 24
  -- Ensure value is between 0 and 1
  return math.max(0, math.min(1, normalized))
end

-- Global dialog reference for EQ10 XY toggle behavior
local dialog = nil

-- Function to create the EQ10 dialog
function pakettiEQ10XYDialog()
  -- Check if dialog is already open and close it
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  
  -- Ensure EQ10 exists and get its index
  local eq10_index = ensure_eq10_exists()
  local eq10_device = renoise.song().selected_track.devices[eq10_index]
  
  -- Create single row of XY pads
  local content = vb:column{
    margin=5,
    --spacing=5
  }
  
  -- Create the single row for all XY pads
  local row_content = vb:row{
    margin=5,
   -- spacing=10
  }
  
  -- Add all 10 bands
  for band_idx = 1, 10 do
    -- Parameter indices for this band
    local gain_idx = band_idx           -- Gains are parameters 1-10
    local freq_idx = band_idx + 10      -- Frequencies are parameters 11-20
    local bw_idx = band_idx + 20        -- Bandwidths are parameters 21-30
    
    -- Get current values
    local gain_param = eq10_device.parameters[gain_idx]
    local freq_param = eq10_device.parameters[freq_idx]
    local bw_param = eq10_device.parameters[bw_idx]
    
    -- Calculate normalized values
    local x_value = (freq_param.value - freq_param.value_min) / 
                   (freq_param.value_max - freq_param.value_min)
    local y_value = normalize_gain(gain_param.value)
    
    local band_group = vb:column{
      margin=2,
      vb:text{text=string.format("Band %d", band_idx) },
      vb:xypad{
        id = string.format("xy_band_%d", band_idx),
        width=80,
        height = 80,
        value = { x = x_value, y = y_value },
        notifier=function(value)
          -- Update frequency (X axis)
          local new_freq = freq_param.value_min + 
                         value.x * (freq_param.value_max - freq_param.value_min)
          freq_param.value = new_freq
          
          -- Update gain and bandwidth (Y axis)
          local gain = (value.y * 24) - 12
          gain_param.value = gain
          
          -- Adjust bandwidth based on gain (higher bandwidth when further from center)
          -- Scale to 0.0001 to 1 range
          local bw_factor = math.abs(gain) / 12  -- 0 to 1 based on gain
          local new_bw = 0.0001 + (bw_factor * 0.9999)  -- Scale to valid range
          bw_param.value = new_bw
        end
      }
    }
    row_content:add_child(band_group)
  end
  
  content:add_child(row_content)
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("EQ10 XY Control",content,keyhandler)
end

renoise.tool():add_keybinding{name="Global:Paketti:Show EQ10 XY Control Dialog...",invoke = pakettiEQ10XYDialog}
-----
if preferences.SelectedSampleBeatSyncLines.value == true then 
  for i=1,512 do
  renoise.tool():add_keybinding{name="Global:Paketti:Set Selected Sample Beatsync Lines to " .. i,invoke=function()SelectedSampleBeatSyncLine(i)end}
  end 
end

function AutoAssignOutputs()
  local song=renoise.song()
  local instrument = song.selected_instrument
  local samples = instrument.samples
  local sample_device_chains = instrument.sample_device_chains
  local available_outputs = sample_device_chains[1] 
    and sample_device_chains[1].available_output_routings 
    or {}

  -- Ensure sufficient output routings exist
  if #available_outputs < 2 then
    renoise.app():show_status("Not enough available output routings.")
    return
  end

  -- Determine the starting chain index based on pre-existing chains
  local pre_existing_chains = #sample_device_chains
  local start_chain_index = math.max(pre_existing_chains + 1, 1)
  if pre_existing_chains >= 2 then
    start_chain_index = 3
  elseif pre_existing_chains == 1 then
    start_chain_index = 2
  end

  -- Calculate the required number of chains (one per sample)
  local required_chains = start_chain_index + #samples - 1

  -- Add new chains if necessary
  for i = pre_existing_chains + 1, required_chains do
    instrument:insert_sample_device_chain_at(i)
  end

  -- Assign output routings and name the chains
  for i = 1, #samples do
    local chain_index = start_chain_index + i - 1
    local routing_index = (i - 1) % (#available_outputs - 1) + 2 -- Skip "Current Track"

    -- Fetch the chain
    local chain = sample_device_chains[chain_index]
    if not chain then
      renoise.app():show_status("Failed to fetch FX chain at index: " .. tostring(chain_index))
      return
    end

    -- Assign output routing and name the chain
    local routing_name = available_outputs[routing_index]
    chain.output_routing = routing_name
    chain.name = routing_name
  end

  renoise.app():show_status("FX chains assigned and outputs routed successfully.")
end


---
-- Initialize ViewBuilder
local vb = renoise.ViewBuilder()
local dialog = nil  -- Initialize dialog as nil

-- Tables to hold references to textfields for XRNT and XRNI slots
local slot_path_views_xrnt = {}
local slot_path_views_xrni = {}

-- Reference to the folder path textfield
local folder_path_view = nil

-- Helper functions to get slot preferences
local function get_slot_preference_xrnt(slot_number)
  return preferences.UserDevices["Slot" .. string.format("%02d", slot_number)]
end

local function get_slot_preference_xrni(slot_number)
  return preferences.UserInstruments["Slot" .. string.format("%02d", slot_number)]
end

-- Function to select the User XRNT Saving Folder
local function select_user_xrnt_saving_folder()
  local selected_folder = renoise.app():prompt_for_path("Select User-defined Saving Folder")
  if selected_folder then
    preferences.UserDevices.Path.value = selected_folder
    if folder_path_view then
      folder_path_view.text = preferences.UserDevices.Path.value
    end
    renoise.app():show_status("Saving folder set to: " .. selected_folder)
  end
end

-- Function to save a device chain to a XRNT slot
local function save_device_chain_to_slot(slot_number)
  if preferences.UserDevices.Path.value == "" then
    renoise.app():show_status("Please set the User XRNT Saving Folder first.")
    return
  end

  local file_name = "Slot" .. string.format("%02d", slot_number) .. ".xrnt"
  local full_path = preferences.UserDevices.Path.value .. "/" .. file_name

  local success, err = pcall(function()
    renoise.app():save_track_device_chain(full_path)
  end)

  if success then
    get_slot_preference_xrnt(slot_number).value = full_path
    if slot_path_views_xrnt[slot_number] then
      slot_path_views_xrnt[slot_number].text = full_path
    end
    renoise.app():show_status("Device chain saved to Slot " .. string.format("%02d", slot_number))
  else
    renoise.app():show_status("Failed to save device chain to Slot " .. string.format("%02d", slot_number) .. ": " .. tostring(err))
  end
end

-- Function to load a device chain from a XRNT slot
local function load_device_chain_from_slot(slot_number)
  local file_path = get_slot_preference_xrnt(slot_number).value
  if file_path == "" then
    renoise.app():show_status("No XRNT file set for Slot " .. string.format("%02d", slot_number))
    return
  end

  local file = io.open(file_path, "r")
  if not file then
    renoise.app():show_status("File not found: " .. file_path)
    return
  else
    file:close()
  end

  local success, err = pcall(function()
    renoise.app():load_track_device_chain(file_path)
  end)

  if success then
    renoise.app():show_status("Device chain loaded from Slot " .. string.format("%02d", slot_number))
  else
    renoise.app():show_status("Failed to load device chain from Slot " .. string.format("%02d", slot_number) .. ": " .. tostring(err))
  end
end

-- Function to select a XRNT file for a slot
local function select_xrnt_file(slot_number)
  local file = renoise.app():prompt_for_filename_to_read({"*.xrnt"}, "Select XRNT File")
  if file then
    get_slot_preference_xrnt(slot_number).value = file
    if slot_path_views_xrnt[slot_number] then
      slot_path_views_xrnt[slot_number].text = file
    end
    renoise.app():show_status("XRNT file set for Slot " .. string.format("%02d", slot_number))
  end
end

-- Function to save an instrument to a XRNI slot
local function save_instrument_to_slot(slot_number)
  if preferences.UserDevices.Path.value == "" then
    renoise.app():show_status("Please set the User XRNT Saving Folder first.")
    return
  end

  local file_name = "Slot" .. string.format("%02d", slot_number) .. ".xrni"
  local full_path = preferences.UserDevices.Path.value .. "/" .. file_name

  local selected_instrument = renoise.song().selected_instrument
  if not selected_instrument then
    renoise.app():show_status("No instrument selected to save.")
    return
  end

  local success, err = pcall(function()
    renoise.app():save_instrument(full_path)
  end)

  if success then
    get_slot_preference_xrni(slot_number).value = full_path
    if slot_path_views_xrni[slot_number] then
      slot_path_views_xrni[slot_number].text = full_path
    end
    renoise.app():show_status("Instrument saved to Slot " .. string.format("%02d", slot_number))
  else
    renoise.app():show_status("Failed to save instrument to Slot " .. string.format("%02d", slot_number) .. ": " .. tostring(err))
  end
end

-- Function to load an instrument from a XRNI slot
local function load_instrument_from_slot(slot_number)
  local file_path = get_slot_preference_xrni(slot_number).value
  if file_path == "" then
    renoise.app():show_status("No XRNI file set for Slot " .. string.format("%02d", slot_number))
    return
  end

  local file = io.open(file_path, "r")
  if not file then
    renoise.app():show_status("File not found: " .. file_path)
    return
  else
    file:close()
  end

  local success, err = pcall(function()
renoise.song():insert_instrument_at(renoise.song().selected_instrument_index+1)
renoise.song().selected_instrument_index=renoise.song().selected_instrument_index+1
    renoise.app():load_instrument(file_path)
  end)

  if success then
    renoise.app():show_status("Instrument loaded from Slot " .. string.format("%02d", slot_number))
  else
    renoise.app():show_status("Failed to load instrument from Slot " .. string.format("%02d", slot_number) .. ": " .. tostring(err))
  end
end

-- Function to select a XRNI file for a slot
local function select_xrni_file(slot_number)
  local file = renoise.app():prompt_for_filename_to_read({"*.xrni"}, "Select XRNI File")
  if file then
    get_slot_preference_xrni(slot_number).value = file
    if slot_path_views_xrni[slot_number] then
      slot_path_views_xrni[slot_number].text = file
    end
    renoise.app():show_status("XRNI file set for Slot " .. string.format("%02d", slot_number))
  end
end

-- Function to load both XRNI and XRNT from a slot
local function load_both_from_slot(slot_number)
  -- Load XRNI
  local xrni_path = get_slot_preference_xrni(slot_number).value
  if xrni_path == "" then
    renoise.app():show_status("No XRNI file set for Slot " .. string.format("%02d", slot_number))
    return
  end

  -- Load XRNT
  local xrnt_path = get_slot_preference_xrnt(slot_number).value
  if xrnt_path == "" then
    renoise.app():show_status("No XRNT file set for Slot " .. string.format("%02d", slot_number))
    return
  end

  -- Validate XRNI file
  local xrni_file = io.open(xrni_path, "r")
  if not xrni_file then
    renoise.app():show_status("XRNI file not found: " .. xrni_path)
    return
  else
    xrni_file:close()
  end

  -- Validate XRNT file
  local xrnt_file = io.open(xrnt_path, "r")
  if not xrnt_file then
    renoise.app():show_status("XRNT file not found: " .. xrnt_path)
    return
  else
    xrnt_file:close()
  end

  -- Load XRNI
  local success_xrni, err_xrni = pcall(function()
    renoise.song():insert_instrument_at(renoise.song().selected_instrument_index+1)
    renoise.song().selected_instrument_index=renoise.song().selected_instrument_index+1
    renoise.app():load_instrument(xrni_path)
  end)

  if not success_xrni then
    renoise.app():show_status("Failed to load Instrument (.XRNI) from Slot " .. string.format("%02d", slot_number) .. ": " .. tostring(err_xrni))
    return
  end

  -- Load XRNT
  local success_xrnt, err_xrnt = pcall(function()
    renoise.app():load_track_device_chain(xrnt_path)
  end)

  if success_xrnt then
    renoise.app():show_status("Both Instrument (.XRNI) and Device Chain (.XRNT) loaded from Slot " .. string.format("%02d", slot_number))
  else
    renoise.app():show_status("Instrument (.XRNI) loaded from Slot " .. string.format("%02d", slot_number) .. " but failed to load Device Chain (.XRNT): " .. tostring(err_xrnt))
  end
end

function pakettiDeviceChainDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  -- Reset the references
  slot_path_views_xrnt = {}
  slot_path_views_xrni = {}
  folder_path_view = nil

  local slots_rows_xrnt = {}
  local slots_rows_xrni = {}
  local slots_rows_both = {}

  for i = 1, 10 do
    local slot_number = string.format("%02d", i)

    -- Create XRNT textfield and store it
    local textfield_xrnt = vb:textfield {
      text = get_slot_preference_xrnt(i).value or "",
      width=900,  -- Increased width as per requirement
      notifier=function(text)
        get_slot_preference_xrnt(i).value = text
      end
    }
    slot_path_views_xrnt[i] = textfield_xrnt

    -- XRNT Row
    local row_xrnt = vb:row{
     -- margin=2,
      vb:text{text="Load Device Chain (.XRNT) Slot" .. slot_number .. ":",width=200 },
      textfield_xrnt,
      vb:button{text="Browse",notifier=function() select_xrnt_file(i) end},
      vb:button{text="Save",notifier=function() save_device_chain_to_slot(i) end},
      vb:button{text="Load",notifier=function() load_device_chain_from_slot(i) end}
    }
    slots_rows_xrnt[#slots_rows_xrnt + 1] = row_xrnt

    -- Create XRNI textfield and store it
    local textfield_xrni = vb:textfield {
      text = get_slot_preference_xrni(i).value or "",
      width=900,  -- Increased width as per requirement
      notifier=function(text)
        get_slot_preference_xrni(i).value = text
      end
    }
    slot_path_views_xrni[i] = textfield_xrni

    -- XRNI Row
    local row_xrni = vb:row{
    --  margin=2,
      vb:text{text="Load Instrument (.XRNI) Slot" .. slot_number .. ":",width=200 },
      textfield_xrni,
      vb:button{
        text="Browse",
        notifier=function()
          select_xrni_file(i)
        end
      },
      vb:button{text="Save",notifier=function() save_instrument_to_slot(i) end},
      vb:button{text="Load",notifier=function() load_instrument_from_slot(i) end}
    }
    slots_rows_xrni[#slots_rows_xrni + 1] = row_xrni

    -- Both XRNI&XRNT Row
    local row_both = vb:row{
      vb:text{text="Load Both Instrument&Device Chain (.XRNI&.XRNT) Slot" .. slot_number .. ":",width=200 },
      vb:button{
        text="Load Both",
        notifier=function()
          load_both_from_slot(i)
        end
      }
    }
    slots_rows_both[#slots_rows_both + 1] = row_both
  end

  -- Define the content of the dialog
  local content = vb:column{
    vb:row{
      vb:text{text="User XRNT/XRNI Save Folder:",width=200},
      vb:textfield {
        text = preferences.UserDevices.Path.value ~= "" and preferences.UserDevices.Path.value or "<Not Set, Please Set>",
        width=900,  -- Increased width as per requirement
        notifier=function(text)
          preferences.UserDevices.Path.value = text
        end
      },
      vb:button{
        text="Browse",
        notifier=function()
          select_user_xrnt_saving_folder()
        end
      }
    },
    vb:column{vb:text{text="Load Device Chain (.XRNT) Slots (01-10)",font="bold",style="strong"},unpack(slots_rows_xrnt)},
    vb:column{vb:text{text="Load Instrument (.XRNI) Slots (01-10)",font="bold",style="strong"},unpack(slots_rows_xrni)},
    vb:column{vb:text{text="Load Both Instrument&Device Chain (.XRNI&.XRNT) Slots (01-10)",font="bold",style="strong"},unpack(slots_rows_both)},
    vb:row{
      vb:button{
        text="Close",
        notifier=function()
          dialog:close()
          dialog = nil  -- Clear the dialog reference
        end
      }
    }
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti Device Chain & Instrument Dialog", content, keyhandler)
end

-- Function to add menu entries and key bindings grouped by functionality
local function add_menu_entries_and_keybindings()
  -- Load Device Chain (.XRNT) Slots 01-10
  for i = 1, 10 do
    local slot_number = string.format("%02d", i)

    local menu_entry_name_xrnt = "Mixer:Paketti:Device Chains:Load Device Chain (.XRNT) Slot" .. slot_number
    local menu_entry_name2_xrnt = "DSP Device:Paketti:Device Chains:Load Device Chain (.XRNT) Slot" .. slot_number
    local key_binding_name_xrnt = "Global:Paketti:Load Device Chain (.XRNT) Slot " .. slot_number

    renoise.tool():add_menu_entry{name=menu_entry_name_xrnt,invoke=function() load_device_chain_from_slot(i) end}
    renoise.tool():add_menu_entry{name=menu_entry_name2_xrnt,invoke=function() load_device_chain_from_slot(i) end}
    renoise.tool():add_keybinding{name=key_binding_name_xrnt,invoke=function() load_device_chain_from_slot(i) end}
  end

  -- Load Instrument (.XRNI) Slots 01-10
  for i = 1, 10 do
    local slot_number = string.format("%02d", i)

    local menu_entry_name_xrni = "Mixer:Paketti:Device Chains:Load Instrument (.XRNI) Slot" .. slot_number
    local menu_entry_name2_xrni = "DSP Device:Paketti:Device Chains:Load Instrument (.XRNI) Slot" .. slot_number
    local key_binding_name_xrni = "Global:Paketti:Load Instrument (.XRNI) Slot " .. slot_number

    renoise.tool():add_menu_entry{name=menu_entry_name_xrni,invoke=function() load_instrument_from_slot(i) end}
    renoise.tool():add_menu_entry{name=menu_entry_name2_xrni,invoke=function() load_instrument_from_slot(i) end}
    renoise.tool():add_keybinding{name=key_binding_name_xrni,invoke=function() load_instrument_from_slot(i) end}
  end

  -- Load Both Instrument&Device Chain (.XRNI&.XRNT) Slots 01-10
  for i = 1, 10 do
    local slot_number = string.format("%02d", i)

    local menu_entry_name_load_both = "Mixer:Paketti:Device Chains:Load Both Instrument&Device Chain (.XRNI&.XRNT) Slot" .. slot_number
    local menu_entry_name2_load_both = "DSP Device:Paketti:Device Chains:Load Both Instrument&Device Chain (.XRNI&.XRNT) Slot" .. slot_number
    local key_binding_name_load_both = "Global:Paketti:Load Both Instrument&Device Chain (.XRNI&.XRNT) Slot " .. slot_number

    renoise.tool():add_menu_entry{name=menu_entry_name_load_both,invoke=function() load_both_from_slot(i) end}
    renoise.tool():add_menu_entry{name=menu_entry_name2_load_both,invoke=function() load_both_from_slot(i) end}
    renoise.tool():add_keybinding{name=key_binding_name_load_both,invoke=function() load_both_from_slot(i) end}
  end
end

add_menu_entries_and_keybindings()



------------------------
local vb = renoise.ViewBuilder()
local dialog = nil
local dialog_content = nil

local function update_sample_volumes(x, y)
  local instrument = renoise.song().selected_instrument
  if #instrument.samples < 4 then
    renoise.app():show_status("Selected instrument must have at least 4 samples.")
    return
  end

  -- Calculate volumes based on the x, y position of the xypad
  local volumes = {
    (1 - x) * y, -- Top-left (Sample 1)
    x * y,       -- Top-right (Sample 2)
    (1 - x) * (1 - y), -- Bottom-left (Sample 3)
    x * (1 - y)  -- Bottom-right (Sample 4)
  }

  -- Normalize volumes to range 0.0 - 1.0
  for i, volume in ipairs(volumes) do
    instrument.samples[i].volume = math.min(1.0, math.max(0.0, volume))
  end

  renoise.app():show_status(
    ("Sample volumes updated: S1=%.2f, S2=%.2f, S3=%.2f, S4=%.2f"):
    format(volumes[1], volumes[2], volumes[3], volumes[4])
  )
end

dialog_content = vb:column{
  vb:xypad{width=200,height=200,value={x=0.5,y=0.5},
    notifier=function(value)
      update_sample_volumes(value.x, value.y)
    end
  }
}

function showXyPaddialog()
  if dialog and dialog.visible then
    dialog:close()
  else
    local keyhandler = create_keyhandler_for_dialog(
      function() return dialog end,
      function(value) dialog = value end
    )
    dialog = renoise.app():show_custom_dialog("XY Pad Sound Mixer", dialog_content, keyhandler)
  end
end

--

local vb = renoise.ViewBuilder()
local dialog = nil
local monitoring_enabled = false -- Tracks the monitoring state
local active = false

-- Tracks all SB0/SBX pairs in the Master Track
local loop_pairs = {}

-- Scan the Master Track for all SB0/SBX pairs

function analyze_loops()
  local song=renoise.song()
  local master_track_index = renoise.song().sequencer_track_count + 1
  local master_track = song.selected_pattern.tracks[master_track_index]
  loop_pairs = {}

  for line_idx, line in ipairs(master_track.lines) do
    if #line.effect_columns > 0 then
      local col = line.effect_columns[1]
      if col.number_string == "0S" then
        local parameter = col.amount_value - 176 -- Decode by subtracting `B0`

        if parameter == 0 then
          -- Found SB0 (start)
          table.insert(loop_pairs, {start_line = line_idx, end_line = nil, repeat_count = 0, max_repeats = 0})
        elseif parameter >= 1 and parameter <= 15 then
          -- Found SBX (end) for the last SB0
          local last_pair = loop_pairs[#loop_pairs]
          if last_pair and not last_pair.end_line then
            last_pair.end_line = line_idx
            last_pair.max_repeats = parameter
          end
        end
      end
    end
  end

  if #loop_pairs == 0 then
    print("Error: No valid SB0/SBX pairs found in the Master Track.")
    return false
  end

  print("Detected SB0/SBX pairs in Master Track:")
  for i, pair in ipairs(loop_pairs) do
    print("Pair " .. i .. ": Start=" .. pair.start_line .. ", End=" .. pair.end_line .. ", Max Repeats=" .. pair.max_repeats)
  end

  return true
end

-- Playback Monitoring Function
local function monitor_playback()
  local song=renoise.song()
  local play_pos = song.transport.playback_pos
  local current_line = play_pos.line
  local max_row = renoise.song().selected_pattern.number_of_lines - 1 -- Last row in the pattern

  -- Reset all repeat counts at the end of the pattern
  if current_line == max_row then
    for _, pair in ipairs(loop_pairs) do
      pair.repeat_count = 0
    end
    print("Resetting all repeat counts at the end of the pattern.")
    return
  end

  -- Handle looping logic for each pair
  for i, pair in ipairs(loop_pairs) do
    if current_line == pair.end_line then
      if pair.repeat_count < pair.max_repeats then
        pair.repeat_count = pair.repeat_count + 1
        print("Pair " .. i .. ": Looping back to SB0 (line " .. pair.start_line .. "). Repeat count: " .. pair.repeat_count)
        song.transport.playback_pos = renoise.SongPos(play_pos.sequence, pair.start_line)
        return
      else
        print("Pair " .. i .. ": Completed all repeats for this iteration.")
      end
    end
  end
end
--]]
-- Global Reset Function
function reset_repeat_counts()
  if not monitoring_enabled then
    print("Monitoring is disabled. Reset operation skipped.")
    return
  end

  print("Checking Master Track for SB0/SBX pairs...")
  if not analyze_loops() then
    print("No valid SB0/SBX pairs found in the Master Track. Reset operation aborted.")
    return
  end

  for i, pair in ipairs(loop_pairs) do
    pair.repeat_count = 0
    print("Reset Pair " .. i .. ": Start=" .. pair.start_line .. ", End=" .. pair.end_line .. ", Max Repeats=" .. pair.max_repeats)
  end

  print("All repeat counts reset to 0. Monitoring restarted.")
  InitSBx() -- Reinitialize SBX monitoring
end

-- Initialize SBX Monitoring
function InitSBx()
  if monitoring_enabled then
    print("Monitoring is enabled. Checking Master Track for SBX...")
    if not analyze_loops() then
      print("No valid SBX commands found in the Master Track. Monitoring will not start.")
      return
    end
    if not active then
      renoise.tool().app_idle_observable:add_notifier(monitor_playback)
      print("SBX Monitoring started.")
      active = true
    end
  else
    print("Monitoring is disabled. SBX initialization skipped.")
  end
end

-- Enable Monitoring
local function enable_monitoring()
  monitoring_enabled = true
  InitSBx()
end

-- Disable Monitoring
local function disable_monitoring()
  monitoring_enabled = false
  if active and renoise.tool().app_idle_observable:has_notifier(monitor_playback) then
    renoise.tool().app_idle_observable:remove_notifier(monitor_playback)
    print("SBX Monitoring stopped.")
    active = false
  end
end

-- GUI for Triggering the Script
function showSBX_dialog()
  if dialog and dialog.visible then dialog:close() return end
  local content = vb:column{
    margin=10,
    vb:text{text="Trigger SBX Loop Handler" },
    vb:button{
      text="Enable Monitoring",
      released = function()
        enable_monitoring()
      end
    },
    vb:button{
      text="Disable Monitoring",
      released = function()
        disable_monitoring()
      end
    }
  }
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("SBX Playback Handler", content, keyhandler)
end


renoise.tool():add_keybinding{name="Global:Transport:Reset SBx and Start Playback",
  invoke=function() reset_repeat_counts() renoise.song().transport:start() end}

-- Tool Initialization
  monitoring_enabled = true
--InitSBx()

function crossfade_loop(crossfade_length)
  -- User-adjustable fade length for loop start/end fades
  local fade_length = 20

  -- Check for an active instrument
  local instrument = renoise.song().selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument selected.")
    return
  end

  -- Check for an active sample
  local sample = instrument:sample(1)
  if not sample then
    renoise.app():show_status("No sample available.")
    return
  end

  -- Check if sample has data and looping is enabled
  local sample_buffer = sample.sample_buffer
  if not sample_buffer or not sample_buffer.has_sample_data then
    renoise.app():show_status("Sample has no data.")
    return
  end

  if sample.loop_mode == renoise.Sample.LOOP_MODE_OFF then
    renoise.app():show_status("Loop mode is off.")
    return
  end

  local loop_start = sample.loop_start
  local loop_end = sample.loop_end
  local num_frames = sample_buffer.number_of_frames

  -- Validate frame ranges for crossfade and fade operations
  if loop_start <= crossfade_length + fade_length then
    renoise.app():show_status("Not enough frames before loop_start for crossfade and fades.")
    return
  end

  if loop_end <= crossfade_length + fade_length then
    renoise.app():show_status("Not enough frames before loop_end for crossfade and fades.")
    return
  end

  if loop_start + fade_length - 1 > num_frames then
    renoise.app():show_status("Not enough frames after loop_start for fade-in.")
    return
  end

  if loop_end - fade_length < 1 then
    renoise.app():show_status("Not enough frames before loop_end for fade-out.")
    return
  end

  -- Define crossfade regions:
  -- a-b (fade-in region) is before loop_start
  local fade_in_start = loop_start - crossfade_length
  local fade_in_end = loop_start - 1

  -- c-d (fade-out region) is before loop_end
  local fade_out_start = loop_end - crossfade_length
  local fade_out_end = loop_end - 1

  -- Prepare sample data changes
  sample_buffer:prepare_sample_data_changes()

  ---------------------------------------------------
  -- Crossfade: Mix a-b region into c-d region
  ---------------------------------------------------
  for i = 0, crossfade_length - 1 do
    local fade_in_pos = fade_in_start + i
    local fade_out_pos = fade_out_start + i

    -- Fade ratios: fade_in ramps 0->1, fade_out ramps 1->0
    local fade_in_ratio = i / (crossfade_length - 1)
    local fade_out_ratio = 1 - fade_in_ratio

    for c = 1, sample_buffer.number_of_channels do
      local fade_in_val = sample_buffer:sample_data(c, fade_in_pos)
      local fade_out_val = sample_buffer:sample_data(c, fade_out_pos)

      -- Blend the two segments
      local blended_val = (fade_in_val * fade_in_ratio) + (fade_out_val * fade_out_ratio)

      -- Write the blended value back to the fade_out region (c-d)
      sample_buffer:set_sample_data(c, fade_out_pos, blended_val)
    end
  end

  ---------------------------------------------------
  -- 20-frame fade-out at loop_end
  -- Ensures silence right at loop_end
  ---------------------------------------------------
  for i = 0, fade_length - 1 do
    local pos = loop_end - fade_length + i
    local fade_ratio = 1 - (i / (fade_length - 1))
    for c = 1, sample_buffer.number_of_channels do
      local sample_val = sample_buffer:sample_data(c, pos)
      sample_buffer:set_sample_data(c, pos, sample_val * fade_ratio)
    end
  end

  ---------------------------------------------------
  -- 20-frame fade-in at loop_start
  -- Ensures sound ramps up from silence at loop_start
  ---------------------------------------------------
  for i = 0, fade_length - 1 do
    local pos = loop_start + i
    local fade_ratio = i / (fade_length - 1)
    for c = 1, sample_buffer.number_of_channels do
      local sample_val = sample_buffer:sample_data(c, pos)
      sample_buffer:set_sample_data(c, pos, sample_val * fade_ratio)
    end
  end

  ---------------------------------------------------
  -- 20-frame fade-out before loop_start
  -- Ensures silence leading into the loop_start region
  ---------------------------------------------------
  for i = 0, fade_length - 1 do
    local pos = loop_start - fade_length + i
    if pos >= 1 and pos <= num_frames then
      local fade_ratio = 1 - (i / (fade_length - 1))
      for c = 1, sample_buffer.number_of_channels do
        local sample_val = sample_buffer:sample_data(c, pos)
        sample_buffer:set_sample_data(c, pos, sample_val * fade_ratio)
      end
    end
  end

  -- Finalize changes
  sample_buffer:finalize_sample_data_changes()

  renoise.app():show_status("Crossfade and 20-frame fades applied to create a smooth X-shaped loop.")
end

-- Helper function to determine crossfade_length based on the current selection
local function get_dynamic_crossfade_length()
  local song=renoise.song()
  local sample = song and song.selected_sample or nil
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample selected.")
    return nil
  end

  local loop_end = sample.loop_end
  local sel = sample.sample_buffer.selection_range

  if not sel or #sel < 2 then
    renoise.app():show_status("No sample selection made.")
    return nil
  end

  -- According to the updated math:
  -- crossfade_length = loop_end - selection_end
  local selection_end = sel[2]

  if selection_end >= loop_end then
    renoise.app():show_status("Selection end must be before loop_end.")
    return nil
  end

  local crossfade_length = loop_end - selection_end
  return crossfade_length
end


-- Keybinding: Use the dynamic crossfade length based on selection_end
renoise.tool():add_keybinding{name="Global:Paketti:Crossfade Loop",
  invoke=function()
    local crossfade_length = get_dynamic_crossfade_length()
    if crossfade_length then
      renoise.app():show_status("Using crossfade length: " .. tostring(crossfade_length))
      crossfade_loop(crossfade_length)
    end
  end
}




renoise.tool():add_midi_mapping{name="Paketti:Midi Selected Instrument Transpose (-64-+64)",
  invoke=function(message)
    -- Ensure the selected instrument exists
    local instrument=renoise.song().selected_instrument
    if not instrument then return end
    
    -- Map the MIDI message value (0-127) to transpose range (-64 to 64)
    local transpose_value=math.floor((message.int_value/127)*128 - 64)
    instrument.transpose=math.max(-64,math.min(transpose_value,64))
    
    -- Status update for debugging
    renoise.app():show_status("Transpose adjusted to "..instrument.transpose)
  end
}

-- Function to set transpose for a specific instrument by index
local function set_instrument_transpose(instrument_index, message)
  local song = renoise.song()
  -- Check if the instrument exists (Lua is 1-indexed, but we receive 0-based indices)
  local instrument = song.instruments[instrument_index + 1]
  if not instrument then
    renoise.app():show_status("Instrument " .. string.format("%02d", instrument_index) .. " does not exist")
    return
  end
  
  -- Map the MIDI message value (0-127) to transpose range (-64 to 64)
  local transpose_value = math.floor((message.int_value / 127) * 128 - 64)
  instrument.transpose = math.max(-64, math.min(transpose_value, 64))
  
  -- Status update for debugging
  renoise.app():show_status("Instrument " .. string.format("%02d", instrument_index) .. " transpose adjusted to " .. instrument.transpose)
end


for i=0,7 do

renoise.tool():add_midi_mapping{name="Paketti:Midi Instrument 0" .. i .." Transpose (-64-+64)",
  invoke=function(message) set_instrument_transpose(i, message) 
  renoise.song().selected_instrument_index=i+1
  renoise.song().selected_track_index=i+1
  end}
end

-- Define the path to the mixpaste.xml file within the tool's directory
local tool_dir = renoise.tool().bundle_path
local xml_file_path = tool_dir .. "mixpaste.xml"

-- Function to save the current pattern selection to mixpaste.xml
function save_selection_as_xml()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if not selection then 
    renoise.app():show_status("No selection available.") 
    return 
  end

  local pattern_index = song.selected_pattern_index
  local xml_data = '<?xml version="1.0" encoding="UTF-8"?>\n<PatternClipboard.BlockBuffer doc_version="0">\n  <Columns>\n'

  for track_index = selection.start_track, selection.end_track do
    local track = song.tracks[track_index]
    local pattern_track = song.patterns[pattern_index].tracks[track_index]
    xml_data = xml_data .. '    <Column>\n'

    -- Handle NoteColumns
    local note_columns = track.visible_note_columns
    xml_data = xml_data .. '      <Column>\n        <Lines>\n'
    for line_index = selection.start_line, selection.end_line do
      local line = pattern_track:line(line_index)
      local has_data = false
      xml_data = xml_data .. '          <Line index="' .. (line_index - selection.start_line) .. '">\n            <NoteColumns>\n'
      for note_column_index = selection.start_column, selection.end_column do
        local note_column = line:note_column(note_column_index)
        if not note_column.is_empty then
          xml_data = xml_data .. '              <NoteColumn>\n'
          xml_data = xml_data .. '                <Note>' .. note_column.note_string .. '</Note>\n'
          xml_data = xml_data .. '                <Instrument>' .. note_column.instrument_string .. '</Instrument>\n'
          xml_data = xml_data .. '              </NoteColumn>\n'
          has_data = true
        end
      end
      xml_data = xml_data .. '            </NoteColumns>\n'
      if not has_data then
        xml_data = xml_data .. '          <Line />\n'
      end
      xml_data = xml_data .. '          </Line>\n'
    end
    xml_data = xml_data .. '        </Lines>\n        <ColumnType>NoteColumn</ColumnType>\n'
    xml_data = xml_data .. '        <SubColumnMask>' .. get_sub_column_mask(track, 'note') .. '</SubColumnMask>\n'
    xml_data = xml_data .. '      </Column>\n'

    -- Handle EffectColumns
    local effect_columns = track.visible_effect_columns
    xml_data = xml_data .. '      <Column>\n        <Lines>\n'
    for line_index = selection.start_line, selection.end_line do
      local line = pattern_track:line(line_index)
      local has_data = false
      xml_data = xml_data .. '          <Line>\n            <EffectColumns>\n'
      for effect_column_index = 1, effect_columns do
        local effect_column = line:effect_column(effect_column_index)
        if not effect_column.is_empty then
          xml_data = xml_data .. '              <EffectColumn>\n'
          xml_data = xml_data .. '                <EffectNumber>' .. effect_column.number_string .. '</EffectNumber>\n'
          xml_data = xml_data .. '                <EffectValue>' .. effect_column.amount_string .. '</EffectValue>\n'
          xml_data = xml_data .. '              </EffectColumn>\n'
          has_data = true
        end
      end
      xml_data = xml_data .. '            </EffectColumns>\n'
      if not has_data then
        xml_data = xml_data .. '          <Line />\n'
      end
      xml_data = xml_data .. '          </Line>\n'
    end
    xml_data = xml_data .. '        </Lines>\n        <ColumnType>EffectColumn</ColumnType>\n'
    xml_data = xml_data .. '        <SubColumnMask>' .. get_sub_column_mask(track, 'effect') .. '</SubColumnMask>\n'
    xml_data = xml_data .. '      </Column>\n'
    xml_data = xml_data .. '    </Column>\n'
  end

  xml_data = xml_data .. '  </Columns>\n</PatternClipboard.BlockBuffer>\n'

  -- Write XML to file
  local file = io.open(xml_file_path, "w")
  if file then
    file:write(xml_data)
    file:close()
    renoise.app():show_status("Selection saved to mixpaste.xml.")
    print("Saved selection to mixpaste.xml")
  else
    renoise.app():show_status("Error writing to mixpaste.xml.")
    print("Error writing to mixpaste.xml")
  end
end

-- Utility function to generate the SubColumnMask for note or effect columns
function get_sub_column_mask(track, column_type)
  local mask = {}
  if column_type == 'note' then
    for i = 1, track.visible_note_columns do
      mask[i] = 'true'
    end
  elseif column_type == 'effect' then
    for i = 1, track.visible_effect_columns do
      mask[i] = 'true'
    end
  end
  for i = #mask + 1, 8 do
    mask[i] = 'false'
  end
  return table.concat(mask, ' ')
end

-- Function to load the pattern data from mixpaste.xml and paste at the current cursor line
function load_xml_into_selection()
  local song=renoise.song()
  local cursor_line = song.selected_line_index
  local cursor_track = song.selected_track_index

  -- Open the mixpaste.xml file
  local xml_file = io.open(xml_file_path, "r")
  if not xml_file then
    renoise.app():show_status("Error reading mixpaste.xml.")
    print("Error reading mixpaste.xml.")
    return
  end

  local xml_data = xml_file:read("*a")
  xml_file:close()

  -- Parse the XML data manually (basic parsing for this use case)
  local parsed_data = parse_xml_data(xml_data)
  if not parsed_data or #parsed_data.lines == 0 then
    renoise.app():show_status("No valid data in mixpaste.xml.")
    print("No valid data in mixpaste.xml.")
    return
  end

  print("Parsed XML data successfully.")

  -- Insert parsed data starting at the cursor position
  local total_lines = #parsed_data.lines
  for line_index, line_data in ipairs(parsed_data.lines) do
    local target_line = cursor_line + line_index - 1
    if target_line > #song.patterns[song.selected_pattern_index].tracks[cursor_track].lines then
      break -- Avoid exceeding pattern length
    end

    local pattern_track = song.patterns[song.selected_pattern_index].tracks[cursor_track]
    local pattern_line = pattern_track:line(target_line)
    
    -- Handle NoteColumns
    for column_index, note_column_data in ipairs(line_data.note_columns) do
      local note_column = pattern_line:note_column(column_index)
      if note_column_data.note ~= "" then
        note_column.note_string = note_column_data.note
        note_column.instrument_string = note_column_data.instrument
        print("Pasting note: " .. (note_column_data.note or "nil") .. " at line " .. target_line .. ", column " .. column_index)
      end
    end

    -- Handle EffectColumns
    for column_index, effect_column_data in ipairs(line_data.effect_columns) do
      local effect_column = pattern_line:effect_column(column_index)
      if effect_column_data.effect_number ~= "" then
        effect_column.number_string = effect_column_data.effect_number
        effect_column.amount_string = effect_column_data.effect_value
        print("Pasting effect: " .. (effect_column_data.effect_number or "nil") .. " with value " .. (effect_column_data.effect_value or "nil") .. " at line " .. target_line .. ", column " .. column_index)
      end
    end
  end

  renoise.app():show_status("Pattern data loaded from mixpaste.xml.")
  print("Pattern data loaded from mixpaste.xml.")
end

-- Basic XML parsing function
function parse_xml_data(xml_string)
  local parsed_data = { lines = {} }
  local line_count = 0
  for line_content in xml_string:gmatch("<Line.-index=\"(.-)\">(.-)</Line>") do
    local line_index = tonumber(line_content:match("index=\"(.-)\""))
    local line_data = { note_columns = {}, effect_columns = {} }

    -- Parsing NoteColumns
    for note_column_content in line_content:gmatch("<NoteColumn>(.-)</NoteColumn>") do
      local note = note_column_content:match("<Note>(.-)</Note>") or ""
      local instrument = note_column_content:match("<Instrument>(.-)</Instrument>") or ""
      table.insert(line_data.note_columns, { note = note, instrument = instrument })
    end

    -- Parsing EffectColumns
    for effect_column_content in line_content:gmatch("<EffectColumn>(.-)</EffectColumn>") do
      local effect_number = effect_column_content:match("<EffectNumber>(.-)</EffectNumber>") or ""
      local effect_value = effect_column_content:match("<EffectValue>(.-)</EffectValue>") or ""
      table.insert(line_data.effect_columns, { effect_number = effect_number, effect_value = effect_value })
    end

    table.insert(parsed_data.lines, line_data)
    line_count = line_count + 1
  end
  print("Parsed " .. line_count .. " lines from XML.")
  return parsed_data
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Alt-M MixPaste - Save",invoke=function() save_selection_as_xml() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Alt-M MixPaste - Load",invoke=function() load_xml_into_selection() end}

-- Define the simplified table for base time divisions from 1/1 to 1/128
local base_time_divisions = {
  [1] = "1 / 1", [2] = "1 / 2", [3] = "1 / 4", [4] = "1 / 8", 
  [5] = "1 / 16", [6] = "1 / 32", [7] = "1 / 64", [8] = "1 / 128"
}

-- Function to load and apply parameters to the Repeater device
function PakettiRepeaterParameters(step, mode)
  -- Check if the Repeater device is already on the selected track
  local track = renoise.song().selected_track
  local device_found = false
  local device_index = nil
  
  for i, device in ipairs(track.devices) do
    if device.display_name == "Repeater" then
      device_found = true
      device_index = i
      break
    end
  end
  
  -- Determine the mode name based on mode value
  local mode_name = "Even"
  if mode == 3 then
    mode_name = "Triplet"
  elseif mode == 4 then
    mode_name = "Dotted"
  end

  -- If the device is found, check if the mode/step match
  if device_found then
    local device = track.devices[device_index]
    local current_mode = device.parameters[1].value
    local current_step_string = device.parameters[2].value_string -- Use value_string for step comparison
    
    -- If mode/step matches and device is active, deactivate the device
    if device.is_active then
      if current_mode == mode and current_step_string == base_time_divisions[step] then
        device.is_active = false
        renoise.app():show_status("Repeater bypassed")
      else
        -- If mode/step doesn't match, update parameters
        device.parameters[1].value = mode -- Set the correct mode
        device.parameters[2].value_string = base_time_divisions[step] -- Set the correct step using value_string
        renoise.app():show_status("Repeater mode/step updated to: "..base_time_divisions[step].." "..mode_name)
      end
    else
      -- If device is bypassed, update parameters and activate
      device.parameters[1].value = mode -- Set the correct mode
      device.parameters[2].value_string = base_time_divisions[step] -- Set the correct step using value_string
      device.is_active = true
      renoise.app():show_status("Repeater activated with mode/step: "..base_time_divisions[step].." "..mode_name)
    end
  else
    -- If the device is not found, load it and apply the parameters
    loadnative("Audio/Effects/Native/Repeater",nil,"./Presets/PakettiRepeaterHoldOff.xml")
    renoise.app():show_status("Repeater loaded and parameters set")
    
    -- Set the mode (parameter 1)
    track.devices[#track.devices].parameters[1].value = mode
    
    -- Set the step parameter using value_string
    if step ~= nil then
      track.devices[#track.devices].parameters[2].value_string = base_time_divisions[step] -- Set the chosen step using value_string
      renoise.app():show_status("Repeater step set to: "..base_time_divisions[step].." "..mode_name)
    end
  end
end

-- Create keybindings for "Even", "Dotted", and "Triplet" for each base time division
for step = 1, #base_time_divisions do
  -- Even (mode 2)
  renoise.tool():add_keybinding{name="Global:Paketti:Repeater " .. base_time_divisions[step] .. " Even",
    invoke=function() PakettiRepeaterParameters(step, 2) end} -- Mode 2 is Even
 
  
  -- Triplet (mode 3)
  renoise.tool():add_keybinding{name="Global:Paketti:Repeater " .. base_time_divisions[step] .. " Triplet",
    invoke=function() PakettiRepeaterParameters(step, 3) end} -- Mode 3 is Triplet
  
  -- Dotted (mode 4)
  renoise.tool():add_keybinding{name="Global:Paketti:Repeater " .. base_time_divisions[step] .. " Dotted",
    invoke=function() PakettiRepeaterParameters(step, 4) end} -- Mode 4 is Dotted
end
---------------



function shrink_to_triplets()
    local song=renoise.song()
    local track = song.selected_pattern.tracks[renoise.song().selected_track_index]
    local pattern_length = song.selected_pattern.number_of_lines

    local note_positions = {}

    -- Collect all notes and their positions
    for line_index = 1, pattern_length do
        local line = track:line(line_index)
        local note_column = line.note_columns[1]

        if not note_column.is_empty then
            -- Manually clone the note data
            table.insert(note_positions, {line_index, {
                note_value = note_column.note_value,
                instrument_value = note_column.instrument_value,
                volume_value = note_column.volume_value,
                panning_value = note_column.panning_value,
                delay_value = note_column.delay_value
            }})
        end
    end

    -- Ensure we have enough notes to work with
    if #note_positions < 2 then
        renoise.app():show_status("Not enough notes to apply triplet structure.")
        return
    end

    -- Calculate the original spacing between notes
    local original_spacing=note_positions[2][1] - note_positions[1][1]

    -- Determine the modifier based on the spacing
    local modifier = math.floor(original_spacing / 2)  -- Will be 1 for 2-row spacing and 2 for 4-row spacing
    local cycle_step = 0

    -- Clear the pattern before applying the triplets
    for line_index = 1, pattern_length do
        track:line(line_index):clear()
    end

    -- Apply triplet logic based on the original spacing
    local new_index = note_positions[1][1]  -- Start at the first note

    for i = 1, #note_positions do
        local note_data = note_positions[i][2]
        local target_line = track:line(new_index)

        -- Triplet Logic
        if original_spacing == 2 then
            -- Case for notes every 2 rows
            if cycle_step == 0 then
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0x00
            elseif cycle_step == 1 then
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0x55
            elseif cycle_step == 2 then
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0xAA

                -- Add extra empty row after AA
                new_index = new_index + 1
            end

            -- Move to the next row
            new_index = new_index + 1
            cycle_step = (cycle_step + 1) % 3

        elseif original_spacing == 4 then
            -- Case for notes every 4 rows
            if cycle_step == 0 then
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0x00
            elseif cycle_step == 1 then
                -- Move the note up by 2 rows and apply AA delay
                new_index = new_index + 2
                target_line = track:line(new_index)
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0xAA

                -- Add one empty row after AA
                new_index = new_index + 1
            elseif cycle_step == 2 then
                -- Apply 55 delay and move up by 1 row
                target_line = track:line(new_index)
                target_line.note_columns[1].note_value = note_data.note_value
                target_line.note_columns[1].instrument_value = note_data.instrument_value
                target_line.note_columns[1].delay_value = 0x55

                -- Add one empty row after 55
                new_index = new_index + 1
            end

            -- Move to the next row
            new_index = new_index + 1
            cycle_step = (cycle_step + 1) % 3
        end
    end

    renoise.app():show_status("Shrink to triplets applied successfully.")
end

-- Keybinding for the script
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Shrink to Triplets",invoke=function() shrink_to_triplets() end}

function triple(first,second,where)
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index+first].note_columns[1]:copy_from(renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[1])
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index+second].note_columns[1]:copy_from(renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[1])


local wherenext=renoise.song().selected_line_index+where

if wherenext > renoise.song().patterns[renoise.song().selected_pattern_index].number_of_lines then
wherenext=1 
renoise.song().selected_line_index = wherenext return
else  renoise.song().selected_line_index=renoise.song().selected_line_index+where
end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Triple (Experimental)",invoke=function() triple(3,6,8) end}

--------
function xypad()
local vb = renoise.ViewBuilder()
local dialog = nil

-- Initial center position
local initial_position = 0.5
local prev_x = initial_position
local prev_y = initial_position

-- Adjust the shift and rotation amounts
local shift_amount = 1  -- Reduced shift amount for smaller up/down changes
local rotation_amount = 2000  -- Adjusted rotation amount for left/right to be less intense

-- Set the middle frame to the instrument sample editor
renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR

-- Function to wrap the sample value
local function wrap_sample_value(value)
  if value > 1.0 then
    return value - 2.0
  elseif value < -1.0 then
    return value + 2.0
  else
    return value
  end
end

-- Function to shift the sample buffer upwards with wrap-around
local function PakettiXYPadSampleRotatorUp(knob_value)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    for c = 1, buffer.number_of_channels do
      for i = 1, buffer.number_of_frames do
        local current_value = buffer:sample_data(c, i)
        local shift_value = shift_amount * knob_value * 1000  -- Adjusted to match the desired intensity
        local new_value = wrap_sample_value(current_value + shift_value)
        buffer:set_sample_data(c, i, new_value)
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer shifted upwards with wrap-around.")
  else
    renoise.app():show_status("No sample data to shift.")
  end
end

-- Function to shift the sample buffer downwards with wrap-around
local function PakettiXYPadSampleRotatorDown(knob_value)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    for c = 1, buffer.number_of_channels do
      for i = 1, buffer.number_of_frames do
        local current_value = buffer:sample_data(c, i)
        local shift_value = shift_amount * knob_value * 1000  -- Adjusted to match the desired intensity
        local new_value = wrap_sample_value(current_value - shift_value)
        buffer:set_sample_data(c, i, new_value)
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer shifted downwards with wrap-around.")
  else
    renoise.app():show_status("No sample data to shift.")
  end
end

-- Function to rotate sample buffer content forwards by a specified number of frames
local function PakettiXYPadSampleRotatorRight(knob_value)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    local frames = buffer.number_of_frames
    for c = 1, buffer.number_of_channels do
      local temp_data = {}
      for i = 1, frames do
        temp_data[i] = buffer:sample_data(c, i)
      end
      for i = 1, frames do
        local new_pos = (i + rotation_amount * knob_value - 1) % frames + 1
        buffer:set_sample_data(c, new_pos, temp_data[i])
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer rotated forward by "..(rotation_amount * knob_value).." frames.")
  else
    renoise.app():show_status("No sample data to rotate.")
  end
end

-- Function to rotate sample buffer content backwards by a specified number of frames
local function PakettiXYPadSampleRotatorLeft(knob_value)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    local frames = buffer.number_of_frames
    for c = 1, buffer.number_of_channels do
      local temp_data = {}
      for i = 1, frames do
        temp_data[i] = buffer:sample_data(c, i)
      end
      for i = 1, frames do
        local new_pos = (i - rotation_amount * knob_value - 1 + frames) % frames + 1
        buffer:set_sample_data(c, new_pos, temp_data[i])
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer rotated backward by "..(rotation_amount * knob_value).." frames.")
  else
    renoise.app():show_status("No sample data to rotate.")
  end
end

-- Function to handle XY pad changes and call appropriate rotator functions
local function on_xy_change(value)
  local x = value.x
  local y = value.y

  -- Compare current x and y with previous values to determine direction
  if x > prev_x then
    PakettiXYPadSampleRotatorRight(x - prev_x) -- Moving right
  elseif x < prev_x then
    PakettiXYPadSampleRotatorLeft(prev_x - x) -- Moving left
  end

  if y > prev_y then
    PakettiXYPadSampleRotatorUp(y - prev_y) -- Moving up
  elseif y < prev_y then
    PakettiXYPadSampleRotatorDown(prev_y - y) -- Moving down
  end

  -- Update previous x and y with the current position
  prev_x = x
  prev_y = y

  -- Set focus back to the sample editor after each interaction
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

-- Function to handle vertical slider change (up/down)
local function on_vertical_slider_change(value)
  if value > initial_position then
    PakettiXYPadSampleRotatorUp(value - initial_position)
  elseif value < initial_position then
    PakettiXYPadSampleRotatorDown(initial_position - value)
  end
  -- Set focus back to the sample editor after each interaction
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

-- Function to handle horizontal slider change (left/right)
local function on_horizontal_slider_change(value)
  if value > initial_position then
    PakettiXYPadSampleRotatorRight(value - initial_position)
  elseif value < initial_position then
    PakettiXYPadSampleRotatorLeft(initial_position - value)
  end
  -- Set focus back to the sample editor after each interaction
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

-- Function to display the dialog with the XY pad and sliders
local function show_paketti_sample_rotator_dialog()
  -- Reset the XY pad to the center (0.5, 0.5)
  prev_x = initial_position
  prev_y = initial_position

  if dialog and dialog.visible then
    dialog:show()
    return
  end

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti XYPad Sample Rotator",
    vb:column{
      vb:row{
        vb:xypad{
          width=200,
          height = 200,
          notifier = on_xy_change,
          value = {x = initial_position, y = initial_position} -- Center the XY pad
        },
        vb:vertical_aligner{
          mode = "center",
          vb:slider{
            height = 200,
            min = 0.0,
            max = 1.0,
            value = initial_position,
            notifier = on_vertical_slider_change
          }
        }
      },
      vb:horizontal_aligner{
        mode = "center",
        vb:slider{
          width=200,
          min = 0.0,
          max = 1.0,
          value = initial_position,
          notifier = on_horizontal_slider_change
        }}}, keyhandler
  )
end

-- Show the dialog when the script is run
--show_paketti_sample_rotator_dialog()

end


------------------
-- Updated shift amount
local shift_amount = 0.01  -- Default value for subtle shifts

-- Function to wrap the sample value
local function wrap_sample_value(value)
  if value > 1.0 then
    return value - 2.0
  elseif value < -1.0 then
    return value + 2.0
  else
    return value
  end
end

-- Function to shift the sample buffer upwards with wrap-around
function PakettiShiftSampleBufferUpwards(knob_value)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    for c = 1, buffer.number_of_channels do
      for i = 1, buffer.number_of_frames do
        local current_value = buffer:sample_data(c, i)
        local shift_value = shift_amount * knob_value
        local new_value = wrap_sample_value(current_value + shift_value)
        buffer:set_sample_data(c, i, new_value)
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer shifted upwards with wrap-around.")
  else
    renoise.app():show_status("No sample data to shift.")
  end
end

-- Function to wrap the sample value correctly
local function wrap_sample_value(value)
  if value < -1.0 then
      return value + 2.0  -- Simple wrap from bottom to top
  elseif value > 1.0 then
      return value - 2.0  -- Simple wrap from top to bottom
  end
  return value
end

function PakettiShiftSampleBufferDownwards(knob_value)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
      -- First, read ALL values before modifying anything
      local values = {}
      for c = 1, buffer.number_of_channels do
          values[c] = {}
          for i = 1, buffer.number_of_frames do
              values[c][i] = buffer:sample_data(c, i)
          end
      end

      print("\nBefore shift (all frames):")
      for c = 1, buffer.number_of_channels do
          print("Channel " .. c .. ":")
          for i = 1, buffer.number_of_frames do
              print(string.format("Frame %d: %.12f", i, values[c][i]))
          end
      end

      buffer:prepare_sample_data_changes()
      
      local shift_value = shift_amount * knob_value
      
      -- Calculate new values before writing any of them
      local new_values = {}
      for c = 1, buffer.number_of_channels do
          new_values[c] = {}
          for i = 1, buffer.number_of_frames do
              local current_value = values[c][i]
              if math.abs(current_value + 1.0) < 0.000001 then
                  new_values[c][i] = 1.0 - shift_value
              else
                  new_values[c][i] = current_value - shift_value
              end
              
              print(string.format(
                  "Frame %d: %.12f %s shifted by %.12f = %.12f",
                  i,
                  current_value,
                  (math.abs(current_value + 1.0) < 0.000001) and "wrapped to 1.0 then" or "",
                  shift_value,
                  new_values[c][i]
              ))
          end
      end
      
      -- Now write all the new values
      for c = 1, buffer.number_of_channels do
          for i = 1, buffer.number_of_frames do
              buffer:set_sample_data(c, i, new_values[c][i])
              print(string.format("   Frame %d actually stored as: %.12f", i, buffer:sample_data(c, i)))
          end
      end
      
      buffer:finalize_sample_data_changes()

      print("\nAfter shift (all frames):")
      for c = 1, buffer.number_of_channels do
          print("Channel " .. c .. ":")
          for i = 1, buffer.number_of_frames do
              print(string.format("Frame %d: %.12f", i, buffer:sample_data(c, i)))
          end
      end

      print("\nShift parameters:")
      print(string.format("knob_value: %.12f", knob_value))
      print(string.format("shift_amount: %.12f", shift_amount))
      print(string.format("total shift: %.12f", shift_amount * knob_value))

      renoise.app():show_status("Sample buffer shifted downwards with wrap-around.")
  else
      renoise.app():show_status("No sample data to shift.")
  end
end










-- Function to shift the sample buffer based on knob position (Up/Down)
function PakettiShiftSampleBuffer(knob_value)
  local song=renoise.song()
  local sample = song.selected_sample
  local buffer = sample.sample_buffer

  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    local direction = 0
    if knob_value <= 63 then
      direction = -1  -- Shift downwards
    else
      direction = 1  -- Shift upwards
    end
    local adjusted_knob_value = math.abs(knob_value - 64) / 63  -- Normalize to 0...1 range
    
    for c = 1, buffer.number_of_channels do
      for i = 1, buffer.number_of_frames do
        local current_value = buffer:sample_data(c, i)
        local shift_value = shift_amount * adjusted_knob_value * direction
        local new_value = wrap_sample_value(current_value + shift_value)
        buffer:set_sample_data(c, i, new_value)
      end
    end
    buffer:finalize_sample_data_changes()
    renoise.app():show_status("Sample buffer shifted " .. (direction > 0 and "upwards" or "downwards") .. " with wrap-around.")
  else
    renoise.app():show_status("No sample data to shift.")
  end
end

renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Up x[Trigger]",invoke=function(message) if message:is_trigger() then PakettiShiftSampleBufferUpwards(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Down x[Trigger]",invoke=function(message) if message:is_trigger() then PakettiShiftSampleBufferDownwards(1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Up x[Knob]",invoke=function(message) local knob_value = message.int_value / 127 PakettiShiftSampleBufferUpwards(knob_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Down x[Knob]",invoke=function(message) local knob_value = message.int_value / 127 PakettiShiftSampleBufferDownwards(knob_value) end}
renoise.tool():add_midi_mapping{name="Paketti:Rotate Sample Buffer Up/Down x[Knob]",invoke=function(message) PakettiShiftSampleBuffer(message.int_value) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Upwards",invoke=function() PakettiShiftSampleBufferUpwards(1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Rotate Sample Buffer Downwards",invoke=function() PakettiShiftSampleBufferDownwards(1) end}















--[[
local function randomizeSmatterEffectColumnCustom(effect_command)
  local song=renoise.song()
  local track_index = song.selected_track_index
  local pattern_index = song.selected_pattern_index
  local pattern = song.patterns[pattern_index]
  local selection = song.selection_in_pattern
  local randomize = function()
    return string.format("%02X", math.random(1, 255))
  end

  local apply_command = function(line)
    local effect_column = line.effect_columns[1]
    if math.random() > 0.5 then
      effect_column.number_string = effect_command
      effect_column.amount_string = randomize()
    else
      effect_column:clear()
    end
  end

  if selection then
    for line_index = selection.start_line, selection.end_line do
      local line = pattern:track(track_index).lines[line_index]
      apply_command(line)
    end
  else
    for sequence_index, sequence in ipairs(song.sequencer.pattern_sequence) do
      if song:pattern(sequence).tracks[track_index] then
        local lines = song:pattern(sequence).number_of_lines
        for line_index = 1, lines do
          local line = song:pattern(sequence).tracks[track_index].lines[line_index]
          apply_command(line)
        end
      end
    end
  end

  renoise.app():show_status("Random " .. effect_command .. " commands applied to the first effect column of the selected track.")
end
]]--
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Smatter (C00/C0F)",invoke=function() randomizeSmatterEffectColumnCustom("0C", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Smatter (0G Glide)",invoke=function() randomizeSmatterEffectColumnCustom("0G", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Smatter (0U Slide Up)",invoke=function() randomizeSmatterEffectColumnCustom("0U", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Smatter (0D Slide Down)",invoke=function() randomizeSmatterEffectColumnCustom("0D", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Smatter (0R Retrig)",invoke=function() randomizeSmatterEffectColumnCustom("0R", false, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Smatter (0P Panning)",invoke=function() randomizeSmatterEffectColumnCustom("0P", false,0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Smatter (0B00/0B01)",invoke=function() randomizeSmatterEffectColumnCustom("0B", false, 0x00, 0xFF) end}


renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Fill (C00/C0F)",invoke=function() randomizeSmatterEffectColumnCustom("0C", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Fill (0G Glide)",invoke=function() randomizeSmatterEffectColumnCustom("0G", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Fill (0U Slide Up)",invoke=function() randomizeSmatterEffectColumnCustom("0U", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Fill (0D Slide Down)",invoke=function() randomizeSmatterEffectColumnCustom("0D", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Fill (0R Retrig)",invoke=function() randomizeSmatterEffectColumnCustom("0R", true, 0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Fill (0P Panning)",invoke=function() randomizeSmatterEffectColumnCustom("0P", true,0x00, 0xFF) end}
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Effect Column Fill (0B00/0B01)",invoke=function() randomizeSmatterEffectColumnCustom("0B", true, 0x00, 0xFF) end}



------------------------





----
-- Utility function to check if a table contains a value
function table_contains(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

-- Function to unmute all tracks and send tracks except the master track
function PakettiToggleSoloTracksUnmuteAllTracks()
  local song=renoise.song()
  local total_track_count = song.sequencer_track_count + 1 + song.send_track_count

  print("----")
  print("Unmuting all tracks")
  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER then
      song:track(i).mute_state = renoise.Track.MUTE_STATE_ACTIVE
      print("Unmuting track index: " .. i .. " (" .. song:track(i).name .. ")")
    end
  end
end

-- Function to mute all tracks except a specific range, and not the master track
function PakettiToggleSoloTracksMuteAllExceptRange(start_track, end_track)
  local song=renoise.song()
  local total_track_count = song.sequencer_track_count + 1 + song.send_track_count
  local group_parents = {}

  print("----")
  print("Muting all tracks except range: " .. start_track .. " to " .. end_track)
  for i = start_track, end_track do
    if song:track(i).group_parent then
      local group_parent = song:track(i).group_parent.name
      if not table_contains(group_parents, group_parent) then
        table.insert(group_parents, group_parent)
      end
    end
  end

  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER then
      if i < start_track or i > end_track then
        song:track(i).mute_state = renoise.Track.MUTE_STATE_OFF
        print("Muting track index: " .. i .. " (" .. song:track(i).name .. ")")
      end
    end
  end

  for i = start_track, end_track do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER then
      song:track(i).mute_state = renoise.Track.MUTE_STATE_ACTIVE
      print("Unmuting track index: " .. i .. " (" .. song:track(i).name .. ")")
    end
  end

  for _, group_parent_name in ipairs(group_parents) do
    local group_parent_index = nil
    for i = 1, song.sequencer_track_count do
      if song:track(i).name == group_parent_name then
        group_parent_index = i
        break
      end
    end
    if group_parent_index then
      local group_parent = song:track(group_parent_index)
      group_parent.mute_state = renoise.Track.MUTE_STATE_ACTIVE
      print("Unmuting group track: " .. group_parent.name)
    end
  end
end

-- Function to mute all tracks except a specific track and its group, and not the master track
function PakettiToggleSoloTracksMuteAllExceptSelectedTrack(track_index)
  local song=renoise.song()
  local total_track_count = song.sequencer_track_count + 1 + song.send_track_count
  local selected_track = song:track(track_index)
  local group_tracks = {}

  print("----")
  print("Muting all tracks except selected track: " .. track_index .. " (" .. selected_track.name .. ")")

  if selected_track.type == renoise.Track.TRACK_TYPE_GROUP then
    table.insert(group_tracks, track_index)
    print("Group name is " .. selected_track.name .. ", Number of Members is " .. #selected_track.members)
    for i = track_index + 1, track_index + #selected_track.members do
      if song:track(i).group_parent and song:track(i).group_parent.name == selected_track.name then
        table.insert(group_tracks, i)
        print("Member index: " .. i .. " (" .. song:track(i).name .. ")")
      else
        break
      end
    end
  elseif selected_track.group_parent then
    local group_parent = selected_track.group_parent.name
    for i = 1, song.sequencer_track_count do
      if song:track(i).type == renoise.Track.TRACK_TYPE_GROUP and song:track(i).name == group_parent then
        table.insert(group_tracks, i)
        print("Group parent: " .. group_parent .. " at index " .. i)
        break
      end
    end
    table.insert(group_tracks, track_index)
    print("Member index: " .. track_index .. " (" .. selected_track.name .. ")")
  else
    table.insert(group_tracks, track_index)
    print("Single track index: " .. track_index .. " (" .. selected_track.name .. ")")
  end

  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER and not table_contains(group_tracks, i) then
      song:track(i).mute_state = renoise.Track.MUTE_STATE_OFF
      print("Muting track index: " .. i .. " (" .. song:track(i).name .. ")")
    end
  end

  for _, group_track in ipairs(group_tracks) do
    if song:track(group_track).type ~= renoise.Track.TRACK_TYPE_MASTER then
      song:track(group_track).mute_state = renoise.Track.MUTE_STATE_ACTIVE
      print("Unmuting track index: " .. group_track .. " (" .. song:track(group_track).name .. ")")
    end
  end
end

-- Function to check if all tracks and send tracks are unmuted
function PakettiToggleSoloTracksAllTracksUnmuted()
  local song=renoise.song()
  local total_track_count = song.sequencer_track_count + 1 + song.send_track_count

  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER and song:track(i).mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
      return false
    end
  end
  return true
end

-- Function to check if all tracks except the selected track and its group are muted
function PakettiToggleSoloTracksAllOthersMutedExceptSelected(track_index)
  local song=renoise.song()
  local selected_track = song:track(track_index)
  local group_tracks = {}
  local total_track_count = song.sequencer_track_count + 1 + song.send_track_count

  if selected_track.type == renoise.Track.TRACK_TYPE_GROUP then
    table.insert(group_tracks, track_index)
    for i = track_index + 1, song.sequencer_track_count do
      if song:track(i).group_parent and song:track(i).group_parent.name == selected_track.name then
        table.insert(group_tracks, i)
      else
        break
      end
    end
  elseif selected_track.group_parent then
    local group_parent = selected_track.group_parent.name
    for i = 1, song.sequencer_track_count do
      if song:track(i).type == renoise.Track.TRACK_TYPE_GROUP and song:track(i).name == group_parent then
        table.insert(group_tracks, i)
        break
      end
    end
    table.insert(group_tracks, track_index)
  else
    table.insert(group_tracks, track_index)
  end

  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER and not table_contains(group_tracks, i) and song:track(i).mute_state ~= renoise.Track.MUTE_STATE_OFF then
      return false
    end
  end
  return selected_track.mute_state == renoise.Track.MUTE_STATE_ACTIVE
end

-- Function to check if all tracks except the selected range are muted
function PakettiToggleSoloTracksAllOthersMutedExceptRange(start_track, end_track)
  local song=renoise.song()
  local total_track_count = song.sequencer_track_count + 1 + song.send_track_count
  local group_parents = {}

  print("Selection In Pattern is from index " .. start_track .. " to index " .. end_track)
  for i = start_track, end_track do
    print("Track index: " .. i .. " (" .. song:track(i).name .. ")")
    if song:track(i).group_parent then
      local group_parent = song:track(i).group_parent.name
      if not table_contains(group_parents, group_parent) then
        table.insert(group_parents, group_parent)
        print("Group parent: " .. group_parent)
      end
    end
  end

  for i = 1, total_track_count do
    if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER and (i < start_track or i > end_track) and song:track(i).mute_state ~= renoise.Track.MUTE_STATE_OFF then
      return false
    end
  end
  for i = start_track, end_track do
    if song:track(i).mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
      return false
    end
  end

  for _, group_parent_name in ipairs(group_parents) do
    local group_parent_index = nil
    for i = 1, song.sequencer_track_count do
      if song:track(i).name == group_parent_name then
        group_parent_index = i
        break
      end
    end
    if group_parent_index then
      local group_parent = song:track(group_parent_index)
      if group_parent.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
        return false
      end
    end
  end
  return true
end

-- Main function to toggle mute states
function PakettiToggleSoloTracks()
  local song=renoise.song()
  local sip = song.selection_in_pattern
  local selected_track_index = song.selected_track_index
  local selected_track = song:track(selected_track_index)

  print("----")
  print("Running PakettiToggleSoloTracks")

  if sip then
    -- If a selection in pattern exists
    print("Selection In Pattern is from index " .. sip.start_track .. " to " .. sip.end_track)
    for i = sip.start_track, sip.end_track do
      print("Track index: " .. i .. " (" .. song:track(i).name .. ")")
    end
    if PakettiToggleSoloTracksAllOthersMutedExceptRange(sip.start_track, sip.end_track) then
      print("Detecting all-tracks-should-be-unmuted situation")
      PakettiToggleSoloTracksUnmuteAllTracks()
    else
      print("Detecting Muting situation")
      PakettiToggleSoloTracksMuteAllExceptRange(sip.start_track, sip.end_track)
    end
  elseif selected_track.type == renoise.Track.TRACK_TYPE_GROUP then
    -- If the selected track is a group, mute all tracks and then unmute the group and its members
    print("Selected track is a group")
    print("Group name is " .. selected_track.name .. ", Number of Members is " .. #selected_track.members)
    if PakettiToggleSoloTracksAllOthersMutedExceptSelected(selected_track_index) then
      print("Detecting all-tracks-should-be-unmuted situation")
      PakettiToggleSoloTracksUnmuteAllTracks()
    else
      for i = 1, song.sequencer_track_count + song.send_track_count do
        if song:track(i).type ~= renoise.Track.TRACK_TYPE_MASTER then
          song:track(i).mute_state = renoise.Track.MUTE_STATE_OFF
          print("Muting track index: " .. i .. " (" .. song:track(i).name .. ")")
        end
      end
      for i = selected_track_index - #selected_track.members, selected_track_index do
        song:track(i).mute_state = renoise.Track.MUTE_STATE_ACTIVE
        print("Unmuting track index: " .. i .. " (" .. song:track(i).name .. ")")
      end
    end
  else
    -- If no selection in pattern and selected track is not a group
    print("No selection in pattern, using selected track: " .. selected_track_index .. " (" .. selected_track.name .. ")")
    if PakettiToggleSoloTracksAllOthersMutedExceptSelected(selected_track_index) then
      print("Detecting all-tracks-should-be-unmuted situation")
      PakettiToggleSoloTracksUnmuteAllTracks()
    else
      print("Detecting Muting situation")
      PakettiToggleSoloTracksMuteAllExceptSelectedTrack(selected_track_index)
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Solo Tracks",invoke=PakettiToggleSoloTracks}
renoise.tool():add_midi_mapping{name="Paketti:Toggle Solo Tracks",invoke=PakettiToggleSoloTracks}

-- Define the function to toggle mute state
function toggle_mute_tracks()
  -- Get the current song
  local song=renoise.song()

  -- Determine the range of selected tracks
  local selection = song.selection_in_pattern

  -- Check if there is a valid selection
  local start_track, end_track
  if selection then
    start_track = selection.start_track
    end_track = selection.end_track
  end

  -- If no specific selection is made, operate on the currently selected track
  if not start_track or not end_track then
    start_track = song.selected_track_index
    end_track = song.selected_track_index
  end

  -- Check if any track in the selection is muted, ignoring the master track
  local any_track_muted = false
  for track_index = start_track, end_track do
    local track = song:track(track_index)
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER and track.mute_state == renoise.Track.MUTE_STATE_ACTIVE then
      any_track_muted = true
      break
    end
  end

  -- Determine the desired mute state for all tracks
  local new_mute_state
  if any_track_muted then
    new_mute_state = renoise.Track.MUTE_STATE_OFF
  else
    new_mute_state = renoise.Track.MUTE_STATE_ACTIVE
  end

  -- Iterate over the range of tracks and set the new mute state, ignoring the master track
  for track_index = start_track, end_track do
    local track = song:track(track_index)
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      track.mute_state = new_mute_state
    end
  end

  -- Additionally, handle groups if they are within the selected range
  for track_index = start_track, end_track do
    local track = song:track(track_index)
    if track.type == renoise.Track.TRACK_TYPE_GROUP then
      local group = track.group_parent
      if group then
        -- Set the mute state for the group and its member tracks, ignoring the master track
        set_group_mute_state(group, new_mute_state)
      end
    end
  end
end

-- Helper function to set mute state for a group and its member tracks
function set_group_mute_state(group, mute_state)
  -- Ensure we don't attempt to mute the master track
  if group.type ~= renoise.Track.TRACK_TYPE_MASTER then
    group.mute_state = mute_state
  end

  -- Set mute state for all member tracks of the group, ignoring the master track
  for _, track in ipairs(group.members) do
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      track.mute_state = mute_state
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Toggle Mute Tracks",invoke=toggle_mute_tracks}
renoise.tool():add_midi_mapping{name="Paketti:Toggle Mute Tracks",invoke=toggle_mute_tracks}








--------
-- Function to initialize selection if it is nil
function PakettiImpulseTrackerShiftInitializeSelection()
  local song=renoise.song()
  local pos = song.transport.edit_pos
  local selected_track_index = song.selected_track_index
  local selected_column_index = song.selected_note_column_index > 0 and song.selected_note_column_index or song.selected_effect_column_index

  song.selection_in_pattern = {
    start_track = selected_track_index,
    end_track = selected_track_index,
    start_column = selected_column_index,
    end_column = selected_column_index,
    start_line = pos.line,
    end_line = pos.line
  }
end

-- Function to ensure selection is valid and swap if necessary
function PakettiImpulseTrackerShiftEnsureValidSelection()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if selection.start_track > selection.end_track then
    local temp = selection.start_track
    selection.start_track = selection.end_track
    selection.end_track = temp
  end

  if selection.start_column > selection.end_column then
    local temp = selection.start_column
    selection.start_column = selection.end_column
    selection.end_column = temp
  end

  if selection.start_line > selection.end_line then
    local temp = selection.start_line
    selection.start_line = selection.end_line
    selection.end_line = temp
  end

  song.selection_in_pattern = selection
end

-- Debug function to print selection details
local function debug_print_selection(message)
  local song=renoise.song()
  local selection = song.selection_in_pattern
  print(message)
print("--------")
  print("Start Track: " .. selection.start_track .. ", End Track: " .. selection.end_track)
  print("Start Column: " .. selection.start_column .. ", End Column: " .. selection.end_column)
  print("Start Line: " .. selection.start_line .. ", End Line: " .. selection.end_line)
print("--------")

end

-- Function to select the next column or track to the right
function PakettiImpulseTrackerShiftRight()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if not selection then
    PakettiImpulseTrackerShiftInitializeSelection()
    selection = song.selection_in_pattern
  end

  debug_print_selection("Before Right Shift")

  if song.selected_track_index == selection.end_track and (song.selected_note_column_index == selection.end_column or song.selected_effect_column_index == selection.end_column) then
    if selection.end_column < song:track(selection.end_track).visible_note_columns then
      selection.end_column = selection.end_column + 1
    elseif selection.end_track < #song.tracks then
      selection.end_track = selection.end_track + 1
      local track = song:track(selection.end_track)
      if track.visible_note_columns > 0 then
        selection.end_column = 1
      else
        selection.end_column = track.visible_effect_columns > 0 and 1 or 0
      end
    else
      renoise.app():show_status("You are on the last track. No more can be selected in that direction.")
      return
    end
  else
    if song.selected_track_index < selection.start_track then
      local temp_track = selection.start_track
      selection.start_track = selection.end_track
      selection.end_track = temp_track

      local temp_column = selection.start_column
      selection.start_column = selection.end_column
      selection.end_column = temp_column
    end
    selection.start_track = song.selected_track_index
    selection.start_column = song.selected_note_column_index > 0 and song.selected_note_column_index or song.selected_effect_column_index
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection

  if song:track(selection.end_track).visible_note_columns > 0 then
    song.selected_note_column_index = selection.end_column
  else
    song.selected_effect_column_index = selection.end_column
  end

  debug_print_selection("After Right Shift")
end

-- Function to select the previous column or track to the left
function PakettiImpulseTrackerShiftLeft()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if not selection then
    PakettiImpulseTrackerShiftInitializeSelection()
    selection = song.selection_in_pattern
  end

  debug_print_selection("Before Left Shift")

  if song.selected_track_index == selection.end_track and (song.selected_note_column_index == selection.end_column or song.selected_effect_column_index == selection.end_column) then
    if selection.end_column > 1 then
      selection.end_column = selection.end_column - 1
    elseif selection.end_track > 1 then
      selection.end_track = selection.end_track - 1
      local track = song:track(selection.end_track)
      if track.visible_note_columns > 0 then
        selection.end_column = track.visible_note_columns
      else
        selection.end_column = track.visible_effect_columns > 0 and track.visible_effect_columns or 0
      end
    else
      renoise.app():show_status("You are on the first track. No more can be selected in that direction.")
      return
    end
  else
    if song.selected_track_index > selection.start_track then
      local temp_track = selection.start_track
      selection.start_track = selection.end_track
      selection.end_track = temp_track

      local temp_column = selection.start_column
      selection.start_column = selection.end_column
      selection.end_column = temp_column
    end
    selection.start_track = song.selected_track_index
    selection.start_column = song.selected_note_column_index > 0 and song.selected_note_column_index or song.selected_effect_column_index
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection

  if song:track(selection.end_track).visible_note_columns > 0 then
    song.selected_note_column_index = selection.end_column
  else
    song.selected_effect_column_index = selection.end_column
  end

  debug_print_selection("After Left Shift")
end

-- Function to extend the selection down by one line
function PakettiImpulseTrackerShiftDown()
  local song=renoise.song()
  local selection = song.selection_in_pattern
  local current_pattern = song.selected_pattern_index

  if not selection then
    PakettiImpulseTrackerShiftInitializeSelection()
    selection = song.selection_in_pattern
  end

  debug_print_selection("Before Down Shift")

  if song.transport.edit_pos.line == selection.end_line then
    if selection.end_line < song:pattern(current_pattern).number_of_lines then
      selection.end_line = selection.end_line + 1
    else
      renoise.app():show_status("You are at the end of the pattern. No more can be selected.")
      return
    end
  else
    if song.transport.edit_pos.line < selection.start_line then
      local temp_line = selection.start_line
      selection.start_line = selection.end_line
      selection.end_line = temp_line
    end
    selection.start_line = song.transport.edit_pos.line
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection
  song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)

  debug_print_selection("After Down Shift")
end

-- Main function to determine which shift up function to call
function PakettiImpulseTrackerShiftUp()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if not selection then
    PakettiImpulseTrackerShiftInitializeSelection()
    selection = song.selection_in_pattern
  end

  if selection.start_column == selection.end_column then
    PakettiImpulseTrackerShiftUpSingleColumn()
  else
    PakettiImpulseTrackerShiftUpMultipleColumns()
  end
end

-- Function to extend the selection up by one line in a single column
function PakettiImpulseTrackerShiftUpSingleColumn()
  local song=renoise.song()
  local selection = song.selection_in_pattern
  local edit_pos = song.transport.edit_pos

  debug_print_selection("Before Up Shift (Single Column)")

  -- Determine the current column index based on the track type
  local current_column_index
  if song:track(song.selected_track_index).visible_note_columns > 0 then
    current_column_index = song.selected_note_column_index
  else
    current_column_index = song.selected_effect_column_index
  end

  -- Check if the cursor is within the current selection
  local cursor_in_selection = song.selected_track_index == selection.start_track and
                              song.selected_track_index == selection.end_track and
                              current_column_index == selection.start_column and
                              edit_pos.line >= selection.start_line and
                              edit_pos.line <= selection.end_line

  if not cursor_in_selection then
    -- Reset the selection to start from the current cursor position if the cursor is not within the selection
    selection.start_track = song.selected_track_index
    selection.end_track = song.selected_track_index
    selection.start_column = current_column_index
    selection.end_column = current_column_index
    selection.start_line = edit_pos.line
    selection.end_line = edit_pos.line

    if selection.start_line > 1 then
      selection.start_line = selection.start_line - 1
      song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
    else
      renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
      return
    end
  else
    -- Extend the selection upwards if the cursor is within the selection
    if edit_pos.line == selection.end_line then
      if selection.end_line > selection.start_line then
        selection.end_line = selection.end_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)
      elseif selection.end_line == selection.start_line then
        if selection.start_line > 1 then
          selection.start_line = selection.start_line - 1
          song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
        else
          renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
          return
        end
      end
    elseif edit_pos.line == selection.start_line then
      if selection.start_line > 1 then
        selection.start_line = selection.start_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
        return
      end
    else
      if edit_pos.line < selection.start_line then
        selection.start_line = edit_pos.line
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        selection.end_line = edit_pos.line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)
      end
    end
  end

  -- Ensure start_line is always <= end_line
  if selection.start_line > selection.end_line then
    local temp = selection.start_line
    selection.start_line = selection.end_line
    selection.end_line = temp
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection

  debug_print_selection("After Up Shift (Single Column)")
end

-- Function to extend the selection up by one line in multiple columns
function PakettiImpulseTrackerShiftUpMultipleColumns()
  local song=renoise.song()
  local selection = song.selection_in_pattern
  local edit_pos = song.transport.edit_pos

  -- Print separator and current state
  print("----")
  print("Before Up Shift (Multiple Columns)")
  print("Current Line Index: " .. edit_pos.line)
  print("Start Track: " .. selection.start_track .. ", End Track: " .. selection.end_track)
  print("Start Column: " .. selection.start_column .. ", End Column: " .. selection.end_column)
  print("Start Line: " .. selection.start_line .. ", End Line: " .. selection.end_line)

  -- Determine the current column index based on the track type
  local current_column_index
  if song:track(song.selected_track_index).visible_note_columns > 0 then
    current_column_index = song.selected_note_column_index
  else
    current_column_index = song.selected_effect_column_index
  end

  -- Print the current column index and edit position line
  print("Current Column Index: " .. current_column_index)
  print("Edit Position Line: " .. edit_pos.line)

  -- Check if the cursor is within the current selection
  local cursor_in_selection = song.selected_track_index == selection.start_track and
                              song.selected_track_index == selection.end_track and
                              current_column_index >= selection.start_column and
                              current_column_index <= selection.end_column and
                              edit_pos.line >= selection.start_line and
                              edit_pos.line <= selection.end_line

  print("Cursor in Selection: " .. tostring(cursor_in_selection))

  if not cursor_in_selection then
    -- Reset the selection to start from the current cursor position if the cursor is not within the selection
    print("Cursor not in selection, resetting selection.")
    selection.start_track = song.selected_track_index
    selection.end_track = song.selected_track_index
    selection.start_column = current_column_index
    selection.end_column = current_column_index
    selection.start_line = edit_pos.line
    selection.end_line = edit_pos.line

    if selection.start_line > 1 then
      selection.start_line = selection.start_line - 1
      song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
    else
      renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
      return
    end
  else
    -- Extend the selection upwards if the cursor is within the selection
    print("Cursor in selection, extending selection upwards.")
    if edit_pos.line == selection.end_line and current_column_index == selection.end_column then
      if selection.end_line > selection.start_line then
        print("Decrementing end_line")
        selection.end_line = selection.end_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)
      elseif selection.start_line > 1 then
        print("Decrementing start_line")
        selection.start_line = selection.start_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
        return
      end
    elseif edit_pos.line == selection.start_line and current_column_index == selection.start_column then
      if selection.start_line > 1 then
        print("Decrementing start_line")
        selection.start_line = selection.start_line - 1
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        renoise.app():show_status("You are at the beginning of the pattern. No more can be selected.")
        return
      end
    else
      if edit_pos.line < selection.start_line then
        print("Adjusting start_line to edit position")
        selection.start_line = edit_pos.line
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.start_line)
      else
        print("Adjusting end_line to edit position")
        selection.end_line = edit_pos.line
        song.transport.edit_pos = renoise.SongPos(song.selected_sequence_index, selection.end_line)
      end
    end
  end

  -- Ensure start_line is always <= end_line
  if selection.start_line > selection.end_line then
    print("Swapping start_line and end_line to ensure start_line <= end_line")
    local temp = selection.start_line
    selection.start_line = selection.end_line
    selection.end_line = temp
  end

  PakettiImpulseTrackerShiftEnsureValidSelection()
  song.selection_in_pattern = selection

  -- Print separator and current state after the operation
  print("After Up Shift (Multiple Columns)")
  print("Current Line Index: " .. song.transport.edit_pos.line)
  print("Start Track: " .. selection.start_track .. ", End Track: " .. selection.end_track)
  print("Start Column: " .. selection.start_column .. ", End Column: " .. selection.end_column)
  print("Start Line: " .. selection.start_line .. ", End Line: " .. selection.end_line)
  print("----")
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Shift-Right Selection In Pattern",invoke=PakettiImpulseTrackerShiftRight}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Shift-Left Selection In Pattern",invoke=PakettiImpulseTrackerShiftLeft}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Shift-Down Selection In Pattern",invoke=PakettiImpulseTrackerShiftDown}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker Shift-Up Selection In Pattern",invoke=PakettiImpulseTrackerShiftUp}
-- Function to copy a single note column
function PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src, dst)
  if src and dst then
    dst.note_value = src.note_value
    dst.instrument_value = src.instrument_value
    dst.volume_value = src.volume_value
    dst.panning_value = src.panning_value
    dst.delay_value = src.delay_value
    dst.effect_number_value = src.effect_number_value
    dst.effect_amount_value = src.effect_amount_value
  elseif dst then
    dst:clear()
  end
end

-- Function to copy a single effect column
function PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src, dst)
  if src and dst then
    dst.number_value = src.number_value
    dst.amount_value = src.amount_value
  elseif dst then
    dst:clear()
  end
end

-- Slide selected column content down by one row in the current pattern
function PakettiImpulseTrackerSlideSelectedColumnDown()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern = song:pattern(pattern_index)
  local track = pattern:track(track_index)
  local number_of_lines = pattern.number_of_lines
  local column_index = song.selected_note_column_index
  local is_note_column = column_index > 0

  if not is_note_column then
    column_index = song.selected_effect_column_index
  end

  -- Store the content of the last row to move it to the first row
  local last_row_content
  if is_note_column then
    last_row_content = track:line(number_of_lines).note_columns[column_index]
  else
    last_row_content = track:line(number_of_lines).effect_columns[column_index]
  end

  -- Slide content down
  for line = number_of_lines, 2, -1 do
    local src_line = track:line(line - 1)
    local dst_line = track:line(line)
    if is_note_column then
      PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src_line.note_columns[column_index], dst_line.note_columns[column_index])
    else
      PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src_line.effect_columns[column_index], dst_line.effect_columns[column_index])
    end
  end

  -- Move the last row content to the first row and clear the last row
  local first_line = track:line(1)
  if is_note_column then
    PakettiImpulseTrackerSlideSelectedNoteColumnCopy(last_row_content, first_line.note_columns[column_index])
    track:line(number_of_lines).note_columns[column_index]:clear()
  else
    PakettiImpulseTrackerSlideSelectedEffectColumnCopy(last_row_content, first_line.effect_columns[column_index])
    track:line(number_of_lines).effect_columns[column_index]:clear()
  end
end

-- Slide selected column content up by one row in the current pattern
function PakettiImpulseTrackerSlideSelectedColumnUp()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern = song:pattern(pattern_index)
  local track = pattern:track(track_index)
  local number_of_lines = pattern.number_of_lines
  local column_index = song.selected_note_column_index
  local is_note_column = column_index > 0

  if not is_note_column then
    column_index = song.selected_effect_column_index
  end

  -- Store the content of the first row to move it to the last row
  local first_row_content
  if is_note_column then
    first_row_content = track:line(1).note_columns[column_index]
  else
    first_row_content = track:line(1).effect_columns[column_index]
  end

  -- Slide content up
  for line = 1, number_of_lines - 1 do
    local src_line = track:line(line + 1)
    local dst_line = track:line(line)
    if is_note_column then
      PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src_line.note_columns[column_index], dst_line.note_columns[column_index])
    else
      PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src_line.effect_columns[column_index], dst_line.effect_columns[column_index])
    end
  end

  -- Move the first row content to the last row and clear the first row
  local last_line = track:line(number_of_lines)
  if is_note_column then
    PakettiImpulseTrackerSlideSelectedNoteColumnCopy(first_row_content, last_line.note_columns[column_index])
    track:line(1).note_columns[column_index]:clear()
  else
    PakettiImpulseTrackerSlideSelectedEffectColumnCopy(first_row_content, last_line.effect_columns[column_index])
    track:line(1).effect_columns[column_index]:clear()
  end
end

-- Functions to slide selected columns up or down within a selection
local function slide_selected_columns_up(track, start_line, end_line, selected_note_columns, selected_effect_columns)
  local first_row_content_note_columns = {}
  local first_row_content_effect_columns = {}

  for _, column_index in ipairs(selected_note_columns) do
    first_row_content_note_columns[column_index] = track:line(start_line).note_columns[column_index]
  end
  for _, column_index in ipairs(selected_effect_columns) do
    first_row_content_effect_columns[column_index] = track:line(start_line).effect_columns[column_index]
  end

  for line = start_line, end_line - 1 do
    local src_line = track:line(line + 1)
    local dst_line = track:line(line)
    for _, column_index in ipairs(selected_note_columns) do
      PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src_line.note_columns[column_index], dst_line.note_columns[column_index])
    end
    for _, column_index in ipairs(selected_effect_columns) do
      PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src_line.effect_columns[column_index], dst_line.effect_columns[column_index])
    end
  end

  local last_line = track:line(end_line)
  for _, column_index in ipairs(selected_note_columns) do
    PakettiImpulseTrackerSlideSelectedNoteColumnCopy(first_row_content_note_columns[column_index], last_line.note_columns[column_index])
    track:line(start_line).note_columns[column_index]:clear()
  end
  for _, column_index in ipairs(selected_effect_columns) do
    PakettiImpulseTrackerSlideSelectedEffectColumnCopy(first_row_content_effect_columns[column_index], last_line.effect_columns[column_index])
    track:line(start_line).effect_columns[column_index]:clear()
  end
end

local function slide_selected_columns_down(track, start_line, end_line, selected_note_columns, selected_effect_columns)
  local last_row_content_note_columns = {}
  local last_row_content_effect_columns = {}

  for _, column_index in ipairs(selected_note_columns) do
    last_row_content_note_columns[column_index] = track:line(end_line).note_columns[column_index]
  end
  for _, column_index in ipairs(selected_effect_columns) do
    last_row_content_effect_columns[column_index] = track:line(end_line).effect_columns[column_index]
  end

  for line = end_line, start_line + 1, -1 do
    local src_line = track:line(line - 1)
    local dst_line = track:line(line)
    for _, column_index in ipairs(selected_note_columns) do
      PakettiImpulseTrackerSlideSelectedNoteColumnCopy(src_line.note_columns[column_index], dst_line.note_columns[column_index])
    end
    for _, column_index in ipairs(selected_effect_columns) do
      PakettiImpulseTrackerSlideSelectedEffectColumnCopy(src_line.effect_columns[column_index], dst_line.effect_columns[column_index])
    end
  end

  local first_line = track:line(start_line)
  for _, column_index in ipairs(selected_note_columns) do
    PakettiImpulseTrackerSlideSelectedNoteColumnCopy(last_row_content_note_columns[column_index], first_line.note_columns[column_index])
  end
  for _, column_index in ipairs(selected_effect_columns) do
    PakettiImpulseTrackerSlideSelectedEffectColumnCopy(last_row_content_effect_columns[column_index], first_line.effect_columns[column_index])
  end
end

-- Function to get selected columns in the current selection
local function get_selected_columns(track, start_line, end_line)
  local selected_note_columns = {}
  local selected_effect_columns = {}

  for column_index = 1, #track:line(start_line).note_columns do
    for line = start_line, end_line do
      if track:line(line).note_columns[column_index].is_selected then
        table.insert(selected_note_columns, column_index)
        break
      end
    end
  end

  for column_index = 1, #track:line(start_line).effect_columns do
    for line = start_line, end_line do
      if track:line(line).effect_columns[column_index].is_selected then
        table.insert(selected_effect_columns, column_index)
        break
      end
    end
  end

  return selected_note_columns, selected_effect_columns
end

-- Slide selected column content down by one row or the selection if it exists
function PakettiImpulseTrackerSlideDown()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if selection then
    local pattern_index = song.selected_pattern_index
    local track_index = song.selected_track_index
    local pattern = song:pattern(pattern_index)
    local track = pattern:track(track_index)
    local start_line = selection.start_line
    local end_line = math.min(selection.end_line, pattern.number_of_lines)
    local selected_note_columns, selected_effect_columns = get_selected_columns(track, start_line, end_line)
    slide_selected_columns_down(track, start_line, end_line, selected_note_columns, selected_effect_columns)
  else
    PakettiImpulseTrackerSlideSelectedColumnDown()
  end
end

-- Slide selected column content up by one row or the selection if it exists
function PakettiImpulseTrackerSlideUp()
  local song=renoise.song()
  local selection = song.selection_in_pattern

  if selection then
    local pattern_index = song.selected_pattern_index
    local track_index = song.selected_track_index
    local pattern = song:pattern(pattern_index)
    local track = pattern:track(track_index)
    local start_line = selection.start_line
    local end_line = math.min(selection.end_line, pattern.number_of_lines)
    local selected_note_columns, selected_effect_columns = get_selected_columns(track, start_line, end_line)
    slide_selected_columns_up(track, start_line, end_line, selected_note_columns, selected_effect_columns)
  else
    PakettiImpulseTrackerSlideSelectedColumnUp()
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Slide Selected Column Content Down",invoke=PakettiImpulseTrackerSlideDown}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Slide Selected Column Content Up",invoke=PakettiImpulseTrackerSlideUp}
renoise.tool():add_midi_mapping{name="Paketti:Slide Selected Column Content Down",invoke=PakettiImpulseTrackerSlideDown}
renoise.tool():add_midi_mapping{name="Paketti:Slide Selected Column Content Up",invoke=PakettiImpulseTrackerSlideUp}





--------------
-- Function to copy note columns
function PakettiImpulseTrackerSlideTrackCopyNoteColumns(src, dst)
  for i = 1, #src do
    if src[i] and dst[i] then
      dst[i].note_value = src[i].note_value
      dst[i].instrument_value = src[i].instrument_value
      dst[i].volume_value = src[i].volume_value
      dst[i].panning_value = src[i].panning_value
      dst[i].delay_value = src[i].delay_value
      dst[i].effect_number_value = src[i].effect_number_value
      dst[i].effect_amount_value = src[i].effect_amount_value
    elseif dst[i] then
      dst[i]:clear()
    end
  end
end

-- Function to copy effect columns
function PakettiImpulseTrackerSlideTrackCopyEffectColumns(src, dst)
  for i = 1, #src do
    if src[i] and dst[i] then
      dst[i].number_value = src[i].number_value
      dst[i].amount_value = src[i].amount_value
    elseif dst[i] then
      dst[i]:clear()
    end
  end
end

-- Slide selected track content down by one row in the current pattern
function PakettiImpulseTrackerSlideTrackDown()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern = song:pattern(pattern_index)
  local track = pattern:track(track_index)
  local number_of_lines = pattern.number_of_lines

  -- Store the content of the last row to move it to the first row
  local last_row_note_columns = {}
  local last_row_effect_columns = {}

  for pos, column in song.pattern_iterator:note_columns_in_pattern_track(pattern_index, track_index) do
    if pos.line == number_of_lines then
      table.insert(last_row_note_columns, column)
    end
  end

  for pos, column in song.pattern_iterator:effect_columns_in_pattern_track(pattern_index, track_index) do
    if pos.line == number_of_lines then
      table.insert(last_row_effect_columns, column)
    end
  end

  -- Slide content down
  for line = number_of_lines, 2, -1 do
    local src_line = track:line(line - 1)
    local dst_line = track:line(line)
    PakettiImpulseTrackerSlideTrackCopyNoteColumns(src_line.note_columns, dst_line.note_columns)
    PakettiImpulseTrackerSlideTrackCopyEffectColumns(src_line.effect_columns, dst_line.effect_columns)
  end

  -- Move the last row content to the first row
  local first_line = track:line(1)
  PakettiImpulseTrackerSlideTrackCopyNoteColumns(last_row_note_columns, first_line.note_columns)
  PakettiImpulseTrackerSlideTrackCopyEffectColumns(last_row_effect_columns, first_line.effect_columns)
end

-- Slide selected track content up by one row in the current pattern
function PakettiImpulseTrackerSlideTrackUp()
  local song=renoise.song()
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local pattern = song:pattern(pattern_index)
  local track = pattern:track(track_index)
  local number_of_lines = pattern.number_of_lines

  -- Store the content of the first row to move it to the last row
  local first_row_note_columns = {}
  local first_row_effect_columns = {}

  for pos, column in song.pattern_iterator:note_columns_in_pattern_track(pattern_index, track_index) do
    if pos.line == 1 then
      table.insert(first_row_note_columns, column)
    end
  end

  for pos, column in song.pattern_iterator:effect_columns_in_pattern_track(pattern_index, track_index) do
    if pos.line == 1 then
      table.insert(first_row_effect_columns, column)
    end
  end

  -- Slide content up
  for line = 1, number_of_lines - 1 do
    local src_line = track:line(line + 1)
    local dst_line = track:line(line)
    PakettiImpulseTrackerSlideTrackCopyNoteColumns(src_line.note_columns, dst_line.note_columns)
    PakettiImpulseTrackerSlideTrackCopyEffectColumns(src_line.effect_columns, dst_line.effect_columns)
  end

  -- Move the first row content to the last row
  local last_line = track:line(number_of_lines)
  PakettiImpulseTrackerSlideTrackCopyNoteColumns(first_row_note_columns, last_line.note_columns)
  PakettiImpulseTrackerSlideTrackCopyEffectColumns(first_row_effect_columns, last_line.effect_columns)
end


renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Slide Selected Track Content Up",invoke=PakettiImpulseTrackerSlideTrackUp}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Slide Selected Track Content Down",invoke=PakettiImpulseTrackerSlideTrackDown}

renoise.tool():add_midi_mapping{name="Paketti:Slide Selected Track Content Up",invoke=PakettiImpulseTrackerSlideTrackUp}
renoise.tool():add_midi_mapping{name="Paketti:Slide Selected Track Content Down",invoke=PakettiImpulseTrackerSlideTrackDown}






-----------
-- Define the XML content as a string
local InstrautomationXML = [[
<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="13">
  <DeviceSlot type="InstrumentAutomationDevice">
    <IsMaximized>true</IsMaximized>
    <ParameterNumber0>0</ParameterNumber0>
    <ParameterNumber1>1</ParameterNumber1>
    <ParameterNumber2>2</ParameterNumber2>
    <ParameterNumber3>3</ParameterNumber3>
    <ParameterNumber4>4</ParameterNumber4>
    <ParameterNumber5>5</ParameterNumber5>
    <ParameterNumber6>6</ParameterNumber6>
    <ParameterNumber7>7</ParameterNumber7>
    <ParameterNumber8>8</ParameterNumber8>
    <ParameterNumber9>9</ParameterNumber9>
    <ParameterNumber10>10</ParameterNumber10>
    <ParameterNumber11>11</ParameterNumber11>
    <ParameterNumber12>12</ParameterNumber12>
    <ParameterNumber13>13</ParameterNumber13>
    <ParameterNumber14>14</ParameterNumber14>
    <ParameterNumber15>15</ParameterNumber15>
    <ParameterNumber16>16</ParameterNumber16>
    <ParameterNumber17>17</ParameterNumber17>
    <ParameterNumber18>18</ParameterNumber18>
    <ParameterNumber19>19</ParameterNumber19>
    <ParameterNumber20>20</ParameterNumber20>
    <ParameterNumber21>21</ParameterNumber21>
    <ParameterNumber22>22</ParameterNumber22>
    <ParameterNumber23>23</ParameterNumber23>
    <ParameterNumber24>24</ParameterNumber24>
    <ParameterNumber25>25</ParameterNumber25>
    <ParameterNumber26>26</ParameterNumber26>
    <ParameterNumber27>27</ParameterNumber27>
    <ParameterNumber28>28</ParameterNumber28>
    <ParameterNumber29>29</ParameterNumber29>
    <ParameterNumber30>30</ParameterNumber30>
    <ParameterNumber31>31</ParameterNumber31>
    <ParameterNumber32>32</ParameterNumber32>
    <ParameterNumber33>33</ParameterNumber33>
    <ParameterNumber34>34</ParameterNumber34>
    <VisiblePages>8</VisiblePages>
  </DeviceSlot>
</FilterDevicePreset>
]]

-- Function to load the preset XML directly into the Instr. Automation device
function openVisiblePagesToFitParameters()
  local song=renoise.song()

  -- Load the Instr. Automation device into the selected track using insert_device_at
  local track = song.selected_track
  track:insert_device_at("Audio/Effects/Native/*Instr. Automation", 2)

  -- Set the active_preset_data to the provided XML content
  renoise.song().selected_track.devices[2].active_preset_data = InstrautomationXML

  -- Debug logging: Confirm the preset has been loaded
  renoise.app():show_status("Preset loaded into Instr. Automation device.")
end

renoise.tool():add_keybinding{name="Global:Paketti:Open Visible Pages to Fit Parameters",invoke=openVisiblePagesToFitParameters}

--------------
-- Mix-Paste Tool for Renoise
-- This tool will mix clipboard data with the pattern data in Renoise

local temp_text_path = renoise.tool().bundle_path .. "temp_mixpaste.txt"
local mix_paste_mode = false

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Impulse Tracker MixPaste",invoke=function()
  mix_paste()
end}

function mix_paste()
  if not mix_paste_mode then
    -- First invocation: save selection to text file and perform initial paste
    save_selection_to_text()
    local clipboard_data = load_pattern_data_from_text()
    if clipboard_data then
      print("Debug: Clipboard data loaded for initial paste:\n" .. clipboard_data)
      perform_initial_paste(clipboard_data)
      renoise.app():show_status("Initial mix-paste performed. Run Mix-Paste again to perform the final mix.")
    else
      renoise.app():show_error("Failed to load clipboard data from text file.")
    end
    mix_paste_mode = true
  else
    -- Second invocation: load from text file and perform final mix-paste
    local clipboard_data = load_pattern_data_from_text()
    if clipboard_data then
      print("Debug: Clipboard data loaded for final paste:\n" .. clipboard_data)
      perform_final_mix_paste(clipboard_data)
      mix_paste_mode = false
      -- Clear the temp text file
      local file = io.open(temp_text_path, "w")
      file:write("")
      file:close()
    else
      renoise.app():show_error("Failed to load clipboard data from text file.")
    end
  end
end

function save_selection_to_text()
  local song=renoise.song()
  local selection = song.selection_in_pattern
  if not selection then
    renoise.app():show_error("Please make a selection in the pattern first.")
    return
  end

  -- Capture pattern data using rprint and save to text file
  local pattern_data = {}
  local pattern = song:pattern(song.selected_pattern_index)
  local track_index = song.selected_track_index

  for line_index = selection.start_line, selection.end_line do
    local line_data = {}
    local line = pattern:track(track_index):line(line_index)
    for col_index = 1, #line.note_columns do
      local note_column = line:note_column(col_index)
      table.insert(line_data, string.format("%s %02X %02X %02X %02X", 
        note_column.note_string, note_column.instrument_value, 
        note_column.volume_value, note_column.effect_number_value, 
        note_column.effect_amount_value))
    end
    for col_index = 1, #line.effect_columns do
      local effect_column = line:effect_column(col_index)
      table.insert(line_data, string.format("%02X %02X", 
        effect_column.number_value, effect_column.amount_value))
    end
    table.insert(pattern_data, table.concat(line_data, " "))
  end

  -- Save pattern data to text file
  local file = io.open(temp_text_path, "w")
  file:write(table.concat(pattern_data, "\n"))
  file:close()

  print("Debug: Saved pattern data to text file:\n" .. table.concat(pattern_data, "\n"))
end

function load_pattern_data_from_text()
  local file = io.open(temp_text_path, "r")
  if not file then
    return nil
  end
  local clipboard = file:read("*a")
  file:close()
  return clipboard
end

function perform_initial_paste(clipboard_data)
  local song=renoise.song()
  local track_index = song.selected_track_index
  local line_index = song.selected_line_index
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(track_index)

  local clipboard_lines = parse_clipboard_data(clipboard_data)

  for i, clipboard_line in ipairs(clipboard_lines) do
    local line = track:line(line_index + i - 1)
    for col_index, clipboard_note_col in ipairs(clipboard_line.note_columns) do
      if col_index <= #line.note_columns then
        local note_col = line:note_column(col_index)
        if note_col.is_empty then
          note_col.note_string = clipboard_note_col.note_string
          note_col.instrument_value = clipboard_note_col.instrument_value
          note_col.volume_value = clipboard_note_col.volume_value
          note_col.effect_number_value = clipboard_note_col.effect_number_value
          note_col.effect_amount_value = clipboard_note_col.effect_amount_value
        end
      end
    end
    for col_index, clipboard_effect_col in ipairs(clipboard_line.effect_columns) do
      if col_index <= #line.effect_columns then
        local effect_col = line:effect_column(col_index)
        if effect_col.is_empty then
          effect_col.number_value = clipboard_effect_col.number_value
          effect_col.amount_value = clipboard_effect_col.amount_value
        end
      end
    end
  end
end

function perform_final_mix_paste(clipboard_data)
  local song=renoise.song()
  local track_index = song.selected_track_index
  local line_index = song.selected_line_index
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(track_index)

  local clipboard_lines = parse_clipboard_data(clipboard_data)

  for i, clipboard_line in ipairs(clipboard_lines) do
    local line = track:line(line_index + i - 1)
    for col_index, clipboard_note_col in ipairs(clipboard_line.note_columns) do
      if col_index <= #line.note_columns then
        local note_col = line:note_column(col_index)
        if not note_col.is_empty then
          if clipboard_note_col.effect_number_value > 0 then
            note_col.effect_number_value = clipboard_note_col.effect_number_value
            note_col.effect_amount_value = clipboard_note_col.effect_amount_value
          end
        end
      end
    end
    for col_index, clipboard_effect_col in ipairs(clipboard_line.effect_columns) do
      if col_index <= #line.effect_columns then
        local effect_col = line:effect_column(col_index)
        if not effect_col.is_empty then
          if clipboard_effect_col.number_value > 0 then
            effect_col.number_value = clipboard_effect_col.number_value
            effect_col.amount_value = clipboard_effect_col.amount_value
          end
        end
      end
    end
  end
end

function parse_clipboard_data(clipboard)
  local lines = {}
  for line in clipboard:gmatch("[^\r\n]+") do
    table.insert(lines, parse_line(line))
  end
  return lines
end

function parse_line(line)
  local note_columns = {}
  local effect_columns = {}
  for note_col_data in line:gmatch("(%S+ %S+ %S+ %S+ %S+)") do
    table.insert(note_columns, parse_note_column(note_col_data))
  end
  for effect_col_data in line:gmatch("(%S+ %S+)") do
    table.insert(effect_columns, parse_effect_column(effect_col_data))
  end
  return {note_columns=note_columns,effect_columns=effect_columns}
end

function parse_note_column(data)
  local note, instrument, volume, effect_number, effect_amount = data:match("(%S+) (%S+) (%S+) (%S+) (%S+)")
  return {
    note_string=note,
    instrument_value=tonumber(instrument, 16),
    volume_value=tonumber(volume, 16),
    effect_number_value=tonumber(effect_number, 16),
    effect_amount_value=tonumber(effect_amount, 16),
  }
end

function parse_effect_column(data)
  local number, amount = data:match("(%S+) (%S+)")
  return {
    number_value=tonumber(number, 16),
    amount_value=tonumber(amount, 16),
  }
end










--Wipes the pattern data, but not the samples or instruments.
--WARNING: Does not reset current filename.
-- TODO
--[[
function wipeSongPattern()
local s=renoise.song()
  for i=1,300 do
    if s.patterns[i].is_empty==false then
    s.patterns[i]:clear()
    renoise.song().patterns[i].number_of_lines=64
    else 
    print ("Encountered empty pattern, not deleting")
    renoise.song().patterns[i].number_of_lines=64
    end
  end
end
renoise.tool():add_keybinding{name="Global:Paketti:Wipe Song Patterns",invoke=function() wipeSongPattern() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Wipe Song Patterns",invoke=function() wipeSongPattern() end}
renoise.tool():add_menu_entry{name="Main Menu:File:Paketti:Wipe Song Patterns",invoke=function() wipeSongPattern() end}
----
--]]
function get_master_track_index()
  for k,v in ripairs(renoise.song().tracks)
    do if v.type == renoise.Track.TRACK_TYPE_MASTER then return k end  
  end
end

function AutoGapper()
renoise.song().tracks[get_master_track_index()].visible_effect_columns = 4  
local gapper=nil
renoise.app().window.active_lower_frame=1
renoise.app().window.lower_frame_is_visible=true
  loadnative("Audio/Effects/Native/Filter")
  loadnative("Audio/Effects/Native/*LFO")
  renoise.song().selected_track.devices[2].parameters[2].value=2
  renoise.song().selected_track.devices[2].parameters[3].value=1
  renoise.song().selected_track.devices[2].parameters[7].value=2
--  renoise.song().selected_track.devices[3].parameters[5].value=0.0074
local gapper=renoise.song().patterns[renoise.song().selected_pattern_index].number_of_lines*2*4
  renoise.song().selected_track.devices[2].parameters[6].value_string=tostring(gapper)
renoise.song().selected_pattern.tracks[get_master_track_index()].lines[renoise.song().selected_line_index].effect_columns[4].number_string = "18"
end

renoise.tool():add_keybinding{name="Global:Paketti:Add Filter & LFO (AutoGapper)",invoke=function() AutoGapper() end}


------------
function start_stop_sample_and_loop_oh_my()
local w=renoise.app().window
local s=renoise.song()
local t=s.transport
local ss=s.selected_sample
local currTrak=s.selected_track_index
local currPatt=s.selected_pattern_index

if w.sample_record_dialog_is_visible then
    -- we are recording, stop
    t:start_stop_sample_recording()
    -- write note
     ss.autoseek=true
     s.patterns[currPatt].tracks[currTrak].lines[1].effect_columns[1].number_string="0G"
     s.patterns[currPatt].tracks[currTrak].lines[1].effect_columns[1].amount_string="01"

for i= 1,12 do
if s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[i].is_empty==true then
   s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[i].note_string="C-4"
   s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[i].instrument_value=s.selected_instrument_index-1
else
 if i == renoise.song().tracks[currTrak].visible_note_columns and i == 12
  then renoise.song():insert_track_at(renoise.song().selected_track_index)
   s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[1].note_string="C-4"
   s.patterns[currPatt].tracks[currTrak].lines[1].note_columns[1].instrument_value=s.selected_instrument_index-1
end
end
end
-- hide dialog
    w.sample_record_dialog_is_visible = false
  else
    -- not recording. show dialog, start recording.
    w.sample_record_dialog_is_visible = true
    t:start_stop_sample_recording()
  end
end

----------------------------
-- has-line-input + add-line-input
function has_line_input()
-- Write some code to find the line input in the correct place
local tr = renoise.song().selected_track
 if tr.devices[2] and tr.devices[2].device_path=="Audio/Effects/Native/#Line Input" 
  then return true
 else
  return false
 end
end

function add_line_input()
-- Write some code to add the line input in the correct place
 loadnative("Audio/Effects/Native/#Line Input")
end

function remove_line_input()
-- Write some code to remove the line input if it's in the correct place
 renoise.song().selected_track:delete_device_at(2)
end

-- recordamajic
function recordamajic9000(running)
    if running then
    renoise.song().transport.playing=true
        -- start recording code here
renoise.app().window.sample_record_dialog_is_visible=true
renoise.app().window.lock_keyboard_focus=true
renoise.song().transport:start_stop_sample_recording()
    else
    -- Stop recording here
    end
end

renoise.tool():add_keybinding{name="Global:Paketti:Recordammajic9000",
invoke=function() if has_line_input() then 
      recordtocurrenttrack()    
      G01()
 else add_line_input()
      recordtocurrenttrack()
      G01()
 end end}

-- turn samplerecorder ON
function SampleRecorderOn()
local howmany = table.count(renoise.song().selected_track.devices)

if renoise.app().window.sample_record_dialog_is_visible==false then
renoise.app().window.sample_record_dialog_is_visible=true 

  if howmany == 1 then 
    loadnative("Audio/Effects/Native/#Line Input")
    return
  else
    if renoise.song().selected_track.devices[2].name=="#Line Input" then
    renoise.song().selected_track:delete_device_at(2)
    renoise.app().window.sample_record_dialog_is_visible=false
    else
    loadnative("Audio/Effects/Native/#Line Input")
    return
end    
  end  

else renoise.app().window.sample_record_dialog_is_visible=false
  if renoise.song().selected_track.devices[2].name=="#Line Input" then
  renoise.song().selected_track:delete_device_at(2)
  end
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Display Sample Recorder with #Line Input",invoke=function() SampleRecorderOn() end}

function glideamount(amount)
local counter=nil 
for i=renoise.song().selection_in_pattern.start_line,renoise.song().selection_in_pattern.end_line 
do renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[i].effect_columns[1].number_string="0G" 
counter=renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[i].effect_columns[1].amount_value+amount 

if counter > 255 then counter=255 end
if counter < 1 then counter=0 
end
renoise.song().patterns[renoise.song().selected_pattern_index].tracks[renoise.song().selected_track_index].lines[i].effect_columns[1].amount_value=counter 
end
end

local s = nil

function startup_()
  local s=renoise.song()
--   renoise.app().window:select_preset(1)
   
   renoise.song().instruments[s.selected_instrument_index].active_tab=1
    if renoise.app().window.active_middle_frame==0 and s.selected_sample.sample_buffer_observable:has_notifier(sample_loaded_change_to_sample_editor) then 
    s.selected_sample.sample_buffer_observable:remove_notifier(sample_loaded_change_to_sample_editor)
    else
  --s.selected_sample.sample_buffer_observable:add_notifier(sample_loaded_change_to_sample_editor)

    return
    end
end

  function sample_loaded_change_to_sample_editor()
--    renoise.app().window.active_middle_frame=4
  end

if not renoise.tool().app_new_document_observable:has_notifier(startup_) 
   then renoise.tool().app_new_document_observable:add_notifier(startup_)
   else renoise.tool().app_new_document_observable:remove_notifier(startup_)
end
--------------------------------------------------------------------------------
function PakettiCapsLockNoteOffNextPtn()   
local s=renoise.song()
local wrapping=s.transport.wrapped_pattern_edit
local editstep=s.transport.edit_step

local currLine=s.selected_line_index
local currPatt=s.selected_pattern_index

local counter=nil
local addlineandstep=nil
local counting=nil
local seqcount=nil
local resultPatt=nil

if s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string=="0O" and 
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string=="FF"
then
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string=""
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string=""
return
else
end

if s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string=="0O" and s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string=="CF"
then s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string="00"  
     s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string="00"
return
end

if renoise.song().transport.edit_mode==true then
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string="0O"  
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string="CF"
return
end

if s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string=="0O" and 
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string=="CF"

then s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string="00" 
     s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string="00"
return
end

if s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string~=nil then
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].number_string="0O"
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].effect_columns[1].amount_string="FF"
return
else 
if s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string=="OFF" then
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string=""
return
else
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string="OFF"
end

--s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string="OFF"
end

addlineandstep=currLine+editstep
seqcount = currPatt+1

if addlineandstep > s.patterns[currPatt].number_of_lines then
print ("Trying to move to index: " .. addlineandstep .. " Pattern number of lines is: " .. s.patterns[currPatt].number_of_lines)
counting=addlineandstep-s.patterns[currPatt].number_of_lines
 if seqcount > (table.count(renoise.song().sequencer.pattern_sequence)) then 
 seqcount = (table.count(renoise.song().sequencer.pattern_sequence))
 s.selected_sequence_index=seqcount
 end
 
resultPatt=currPatt+1 
 if resultPatt > #renoise.song().sequencer.pattern_sequence then 
 resultPatt = (table.count(renoise.song().sequencer.pattern_sequence))
s.selected_sequence_index=resultPatt
s.selected_line_index=counting
end
else 
print ("Trying to move to index: " .. addlineandstep .. " Pattern number of lines is: " .. s.patterns[currPatt].number_of_lines)
--s.selected_sequence_index=currPatt+1
s.selected_line_index=addlineandstep

counter = addlineandstep-1

renoise.app():show_status("Now on: " .. counter .. "/" .. s.patterns[currPatt].number_of_lines .. " In Pattern: " .. currPatt)
end
end
----
function PakettiCapsLockNoteOff()   
local s=renoise.song()
local st=s.transport
local wrapping=st.wrapped_pattern_edit
local editstep=st.edit_step

local currLine=s.selected_line_index
local currPatt=s.selected_sequence_index

local counter=nil
local addlineandstep=nil
local counting=nil
local seqcount=nil

if renoise.song().patterns[renoise.song().selected_sequence_index].tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[renoise.song().selected_note_column_index].note_string=="OFF" then 

s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string=""
return
else end

if not s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string=="OFF"
then
s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string="OFF"
else s.patterns[currPatt].tracks[s.selected_track_index].lines[s.selected_line_index].note_columns[s.selected_note_column_index].note_string=""
end

addlineandstep=currLine+editstep
seqcount = currPatt+1

if addlineandstep > s.patterns[currPatt].number_of_lines then
print ("Trying to move to index: " .. addlineandstep .. " Pattern number of lines is: " .. s.patterns[currPatt].number_of_lines)
counting=addlineandstep-s.patterns[currPatt].number_of_lines
 if seqcount > (table.count(renoise.song().sequencer.pattern_sequence)) then 
 seqcount = (table.count(renoise.song().sequencer.pattern_sequence))
 s.selected_sequence_index=seqcount
 end
--s.selected_sequence_index=currPatt+1
s.selected_line_index=counting
else 
print ("Trying to move to index: " .. addlineandstep .. " Pattern number of lines is: " .. s.patterns[currPatt].number_of_lines)
--s.selected_sequence_index=currPatt+1
s.selected_line_index=addlineandstep

counter = addlineandstep-1

renoise.app():show_status("Now on: " .. counter .. "/" .. s.patterns[currPatt].number_of_lines .. " In Pattern: " .. currPatt)
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Note Off / Caps Lock replacement",invoke=function() 
if renoise.song().transport.wrapped_pattern_edit == false then PakettiCapsLockNoteOffNextPtn() 
else PakettiCapsLockNoteOff() end
end}
----------------------------------------
function move_up(chg)
local sindex=renoise.song().selected_line_index
local s= renoise.song()
local note=s.selected_note_column
--This switches currently selected row but doesn't 
--move the note
--s.selected_line_index = (sindex+chg)
-- moving note up, applying correct delay value and moving cursor up goes here
end
--movedown
function move_down(chg)
local sindex=renoise.song().selected_line_index
local s= renoise.song()
--This switches currently selected row but doesn't 
--move the note
--s.selected_line_index = (sindex+chg)
-- moving note down, applying correct delay value and moving cursor down goes here
end


-- Function to adjust the delay value of the selected note column within the current phrase
function delay(seconds)
    local command = "sleep " .. tonumber(seconds)
    os.execute(command)
end

----------

---------------------------
function GenerateDelayValue(scope)
  local s = renoise.song()
  local track = s.tracks[s.selected_track_index]
  track.delay_column_visible = true
  
  local num_columns = track.visible_note_columns
  local base_delay = 256 / num_columns
  
  -- Get target lines based on scope
  local lines = {}
  if scope == "row" then
      table.insert(lines, s.selected_line_index)
  elseif scope == "pattern" then
      for i = 1, s.selected_pattern.number_of_lines do
          table.insert(lines, i)
      end
  elseif scope == "selection" then
      local selection = s.selection_in_pattern
      if not selection then
          renoise.app():show_status("No selection found!")
          return
      end
      for i = selection.start_line, selection.end_line do
          table.insert(lines, i)
      end
  end
  
  -- Apply to all target lines
  for _, line_index in ipairs(lines) do
      for i = 1, num_columns do
          local delay_value = math.floor(base_delay * (i - 1))
          s.patterns[s.selected_pattern_index].tracks[s.selected_track_index]
              .lines[line_index].note_columns[i].delay_value = delay_value
      end
  end
  
  s.selected_note_column_index = 1
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value on Note Columns",invoke=function() GenerateDelayValue("row") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value on Entire Pattern",invoke=function() GenerateDelayValue("pattern") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value on Selection",invoke=function() GenerateDelayValue("selection") end}
-------

-- Function to get selected columns in the current selection
local function get_selected_columns(track, start_line, end_line)
  local selected_note_columns = {}
  local selected_effect_columns = {}

  for column_index = 1, #track:line(start_line).note_columns do
    for line = start_line, end_line do
      if track:line(line).note_columns[column_index].is_selected then
        table.insert(selected_note_columns, column_index)
        break
      end
    end
  end

  return selected_note_columns, selected_effect_columns
end

function GenerateDelayValueNotes(scope)
  local s = renoise.song()
  local track = s.tracks[s.selected_track_index]
  track.delay_column_visible = true
  
  local lines = {}
  if scope == "row" then
      table.insert(lines, s.selected_line_index)
  elseif scope == "pattern" then
      for i = 1, s.selected_pattern.number_of_lines do
          table.insert(lines, i)
      end
  elseif scope == "selection" then
      local selection = s.selection_in_pattern
      if not selection then
          renoise.app():show_status("No selection found!")
          return
      end
      for i = selection.start_line, selection.end_line do
          table.insert(lines, i)
      end
  end
  
  for _, line_index in ipairs(lines) do
      local line = s.patterns[s.selected_pattern_index].tracks[s.selected_track_index]:line(line_index)
      
      local actual_notes = 0
      for i = 1, track.visible_note_columns do
          local note_column = line.note_columns[i]
          if note_column and note_column.note_string ~= "" and 
             note_column.note_string ~= "OFF" and note_column.note_value < 120 then
              actual_notes = actual_notes + 1
          end
      end
      
      if actual_notes > 1 then
          local current_note = 0
          for i = 1, track.visible_note_columns do
              local note_column = line.note_columns[i]
              if note_column and note_column.note_string ~= "" and 
                 note_column.note_string ~= "OFF" and note_column.note_value < 120 then
                  local delay = math.floor(256 * current_note / actual_notes)
                  note_column.delay_value = delay
                  current_note = current_note + 1
              end
          end
      end
  end
end


-- Add new keybindings for note-specific version
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value (Notes Only, Row)",invoke=function() GenerateDelayValueNotes("row") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value (Notes Only, Pattern)",invoke=function() GenerateDelayValueNotes("pattern") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Generate Delay Value (Notes Only, Selection)",invoke=function() GenerateDelayValueNotes("selection") end}

-------
-- Global variable to track which column cycling is active for
local active_cycling_column = nil

function pattern_line_notifier(pos)
  local s = renoise.song()
  local t = s.transport
  local pattern = s.patterns[s.selected_pattern_index]
  
  if t.edit_step == 0 then
    local new_col = s.selected_note_column_index + 1
    local max_cols = s.tracks[s.selected_track_index].visible_note_columns
    
    if new_col > max_cols then
      -- When reaching last column, move to next line or wrap
      local new_line = s.selected_line_index + 1
      
      if new_line > pattern.number_of_lines then
        new_line = 1  -- Wrap to first line if at end of pattern
      end
      
      s.selected_line_index = new_line
      s.selected_note_column_index = 1
    else
      s.selected_note_column_index = new_col
    end
    return
  end

  -- Existing code for edit_step > 0 cases
  local countline = s.selected_line_index + 1
  if t.edit_step > 1 then
    countline = countline - 1
  end
  
  if countline > pattern.number_of_lines then
    countline = 1
  end
  
  s.selected_line_index = countline
  local colnumber = s.selected_note_column_index + 1
  
  if colnumber > s.tracks[s.selected_track_index].visible_note_columns then
    s.selected_note_column_index = 1
    return
  end
  
  s.selected_note_column_index = colnumber
end

function startcolumncycling(number)
  local s = renoise.song()
  local pattern = s.patterns[s.selected_pattern_index]
  local was_active = pattern:has_line_notifier(pattern_line_notifier)

  if number then
    -- Store the current column before displayNoteColumn changes it
    local original_column = s.selected_note_column_index
    
    -- Column-specific activation/deactivation
    if was_active then
      -- Cycling is currently on, turn it off
      pattern:remove_line_notifier(pattern_line_notifier)
      renoise.app():show_status(number .. " Column Cycle Keyjazz Off")
    else
      -- Cycling is currently off, turn it on
      pattern:add_line_notifier(pattern_line_notifier)
      renoise.app():show_status(number .. " Column Cycle Keyjazz On")
    end
  else
    -- General toggle (no specific column)
    if was_active then
      pattern:remove_line_notifier(pattern_line_notifier)
      renoise.app():show_status("Column Cycling Off")
    else
      pattern:add_line_notifier(pattern_line_notifier)
      renoise.app():show_status(s.selected_note_column_index .. " Column Cycle Keyjazz On")
    end
  end
end

for cck=1,12 do 
renoise.tool():add_keybinding{name="Global:Paketti:Column Cycle Keyjazz " .. formatDigits(2,cck),invoke=function() displayNoteColumn(cck) startcolumncycling(cck) end} 
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Column Cycle Keyjazz:Column Cycle Keyjazz " .. formatDigits(2,cck),invoke=function() displayNoteColumn(cck) startcolumncycling(cck) end}
end

renoise.tool():add_keybinding{name="Global:Paketti:Start/Stop Column Cycling",invoke=function() startcolumncycling() end}

function ColumnCycleKeyjazzSpecial(number)
displayNoteColumn(number) 
GenerateDelayValue("pattern")
renoise.song().transport.edit_mode=true
renoise.song().transport.edit_step=0
renoise.song().selected_note_column_index=1
startcolumncycling(number)
end

for ccks=3,12 do
renoise.tool():add_keybinding{name="Global:Paketti:Column Cycle Keyjazz Special (" .. ccks .. ")",invoke=function() ColumnCycleKeyjazzSpecial(ccks) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Column Cycle Keyjazz:Column Cycle Keyjazz Special (" .. ccks .. ")",invoke=function() ColumnCycleKeyjazzSpecial(ccks) end}
end
renoise.tool():add_keybinding{name="Global:Paketti:Column Cycle Keyjazz Special (2)",invoke=function() ColumnCycleKeyjazzSpecial(2) end}

---
-- Toggle mute state functions
function toggleMuteSelectedTrack()
  local track = renoise.song().selected_track
  if track.mute_state == 1 then
    track.mute_state = 3
  elseif track.mute_state == 2 or track.mute_state == 3 then
    track.mute_state = 1
  end
end

function toggleMuteTrack(track_number)
  local song = renoise.song()
  if track_number <= #song.tracks then
    local track = song.tracks[track_number]
    if track.mute_state == 1 then
      track.mute_state = 3
    elseif track.mute_state == 2 or track.mute_state == 3 then
      track.mute_state = 1
    end
  end
end

-- Explicit mute functions
function muteSelectedTrack()
  renoise.song().selected_track.mute_state = 3
end

function muteTrack(track_number)
  local song = renoise.song()
  if track_number <= #song.tracks then
    song.tracks[track_number].mute_state = 3
  end
end

-- Explicit unmute functions
function unmuteSelectedTrack()
  renoise.song().selected_track.mute_state = 1
end

function unmuteTrack(track_number)
  local song = renoise.song()
  if track_number <= #song.tracks then
    song.tracks[track_number].mute_state = 1
  end
end

-- Keybindings and MIDI mappings for selected track
renoise.tool():add_keybinding{name="Global:Paketti:Toggle Mute/Unmute of Selected Track", invoke=toggleMuteSelectedTrack}
renoise.tool():add_midi_mapping{name="Paketti:Toggle Mute/Unmute of Selected Track", invoke=function(message) if message:is_trigger() then toggleMuteSelectedTrack() end end}

renoise.tool():add_keybinding{name="Global:Paketti:Mute Selected Track", invoke=muteSelectedTrack}
renoise.tool():add_midi_mapping{name="Paketti:Mute Selected Track", invoke=function(message) if message:is_trigger() then muteSelectedTrack() end end}

renoise.tool():add_keybinding{name="Global:Paketti:Unmute Selected Track", invoke=unmuteSelectedTrack}
renoise.tool():add_midi_mapping{name="Paketti:Unmute Selected Track", invoke=function(message) if message:is_trigger() then unmuteSelectedTrack() end end}

-- Keybindings and MIDI mappings for tracks 1-16
for i = 1, 16 do
  local track_num_str = string.format("%02d", i)
  renoise.tool():add_keybinding{name="Global:Paketti:Toggle Mute/Unmute of Track " .. track_num_str, invoke=function() toggleMuteTrack(i) end}
  renoise.tool():add_keybinding{name="Global:Paketti:Mute Track " .. track_num_str, invoke=function() muteTrack(i) end}
  renoise.tool():add_keybinding{name="Global:Paketti:Unmute Track " .. track_num_str, invoke=function() unmuteTrack(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:Toggle Mute/Unmute of Track " .. track_num_str, invoke=function(message) if message:is_trigger() then toggleMuteTrack(i) end end}
  renoise.tool():add_midi_mapping{name="Paketti:Mute Track " .. track_num_str, invoke=function(message) if message:is_trigger() then muteTrack(i) end end}
  renoise.tool():add_midi_mapping{name="Paketti:Unmute Track " .. track_num_str, invoke=function(message) if message:is_trigger() then unmuteTrack(i) end end}
end

-- Group Samples by Name to New Instruments Feature
function PakettiGroupSamplesByName()
  local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix
  local song = renoise.song()
  local selected_instrument_index = song.selected_instrument_index
  local instrument = song.selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("No valid instrument with samples selected.")
    return
  end

  -- Check if instrument has slices - we can't process sliced instruments
  if #instrument.samples > 0 and #instrument.samples[1].slice_markers > 0 then
    renoise.app():show_status("Cannot group slices - slices cannot be renamed. Use with multi-sample instruments only.")
    return
  end

  -- Need at least 2 samples to group
  if #instrument.samples < 2 then
    renoise.app():show_status("Need at least 2 samples in instrument to group by name.")
    return
  end

  -- Helper function to extract the base name from a sample name
  local function extract_base_name(name)
    -- Simple approach: take the first word before any numbers, notes, or separators
    local base_name = name
    
    -- Extract the first word (everything before first space, number, or separator)
    base_name = base_name:match("^([^%s%d_%-%.]+)")
    
    if not base_name or base_name == "" then
      -- Fallback: take everything before first number
      base_name = name:match("^([^%d]+)")
      if base_name then
        base_name = base_name:gsub("[%s_%-%.]+$", "") -- trim trailing separators
      end
    end
    
    if not base_name or base_name == "" then
      base_name = name -- ultimate fallback
    end
    
    -- Convert to lowercase for consistent grouping
    base_name = base_name:lower()
    
    print(string.format("  Base name extraction: '%s' -> '%s'", name, base_name))
    return base_name
  end

  -- Helper function to create a new drumkit instrument
  local function create_drumkit_instrument(index)
    song:insert_instrument_at(index)
    song.selected_instrument_index = index
    
    -- Load the default drumkit instrument template
    local defaultInstrument = preferences.pakettiDefaultDrumkitXRNI.value
    local fallbackInstrument = "Presets" .. separator .. "12st_Pitchbend_Drumkit_C0.xrni"
    
    local success, error_msg = pcall(function()
      renoise.app():load_instrument(defaultInstrument)
    end)
    
    if not success then
      -- Try fallback
      pcall(function()
        renoise.app():load_instrument(renoise.tool().bundle_path .. fallbackInstrument)
      end)
    end
    
    local new_instrument = song.instruments[index]
    return new_instrument
  end

  -- Helper function to copy sample to new instrument
  local function copy_sample_to_instrument(source_sample, target_instrument, key_index)
    local insert_position = #target_instrument.samples + 1
    print(string.format("  Inserting sample at position %d", insert_position))
    local new_sample = target_instrument:insert_sample_at(insert_position)
    
    -- Copy the entire sample
    new_sample:copy_from(source_sample)
    print(string.format("  Copied sample '%s' -> '%s'", source_sample.name, new_sample.name))
    
    -- Set up sequential key mapping starting from C-0
    local mapping = new_sample.sample_mapping
    mapping.base_note = key_index -- Sequential notes starting from 0 (C-0)
    mapping.note_range = {key_index, key_index} -- Each sample gets exactly one key
    mapping.velocity_range = {0, 127}
    mapping.map_velocity_to_volume = true
    
    return new_sample
  end

  -- Collect and group samples by base name
  local groups = {}
  
  print("Processing samples from instrument: " .. instrument.name)
  
  for i, sample in ipairs(instrument.samples) do
    local base_name = extract_base_name(sample.name)
    
    if not groups[base_name] then
      groups[base_name] = {}
    end
    
    table.insert(groups[base_name], sample)
    
    print(string.format("Sample %d ('%s') grouped under '%s'", i, sample.name, base_name))
  end

  -- Check if we actually have groups (more than one sample with same base name)
  local has_groups = false
  for group_name, group_samples in pairs(groups) do
    if #group_samples > 1 then
      has_groups = true
      break
    end
  end
  
  if not has_groups then
    renoise.app():show_status("No samples found with matching base names to group.")
    return
  end

  -- Create drumkit instruments for each group that has more than one sample
  local insert_index = selected_instrument_index + 1
  local created_instruments = 0
  
  for group_name, group_samples in pairs(groups) do
    if #group_samples > 1 then -- Only create instruments for groups with multiple samples
      print(string.format("Creating drumkit instrument for '%s' with %d samples", group_name, #group_samples))
      
      local new_instrument = create_drumkit_instrument(insert_index)
      
      -- Clear only placeholder samples from the drumkit template before copying real samples
      local deleted_count = 0
      for i = #new_instrument.samples, 1, -1 do
        if new_instrument.samples[i].name == "Placeholder for drumkit" then
          print(string.format("Deleting placeholder sample: '%s'", new_instrument.samples[i].name))
          new_instrument:delete_sample_at(i)
          deleted_count = deleted_count + 1
        end
      end
      print(string.format("Deleted %d placeholder samples, %d samples remain", deleted_count, #new_instrument.samples))
      
      -- Copy all samples in this group to the new instrument
      for i, sample in ipairs(group_samples) do
        local key_index = i - 1 -- Start from 0 (C-0), then 1 (C#-0), 2 (D-0), etc.
        print(string.format("Copying sample %d: '%s' to key %d", i, sample.name, key_index))
        copy_sample_to_instrument(sample, new_instrument, key_index)
        print(string.format("After copying, instrument has %d samples", #new_instrument.samples))
      end
      
      -- Set the instrument name AFTER all copying is complete
      local instrument_name = string.format("%s (%d)", group_name, #group_samples)
      new_instrument.name = instrument_name
      print(string.format("Set final instrument name: '%s'", new_instrument.name))
      
      insert_index = insert_index + 1
      created_instruments = created_instruments + 1
      
      print(string.format("Created instrument '%s' with %d samples", group_name, #group_samples))
    end
  end

  -- Set octave and show completion status
  --song.transport.octave = 3
  
  local total_grouped_samples = 0
  for _, group_samples in pairs(groups) do
    if #group_samples > 1 then
      total_grouped_samples = total_grouped_samples + #group_samples
    end
  end
  
  renoise.app():show_status(string.format(
    "Grouped %d samples into %d drumkit instruments by name", 
    total_grouped_samples, created_instruments
  ))
  
  print(string.format("=== GROUPING COMPLETE ==="))
  print(string.format("Source: %d samples from '%s'", #instrument.samples, instrument.name))
  print(string.format("Created: %d drumkit instruments", created_instruments))
  for group_name, group_samples in pairs(groups) do
    if #group_samples > 1 then
      print(string.format("  - '%s': %d samples", group_name, #group_samples))
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Group Samples by Name to New Instruments", invoke=PakettiGroupSamplesByName}
renoise.tool():add_midi_mapping{name="Paketti:Group Samples by Name to New Instruments", invoke=PakettiGroupSamplesByName}

-- Pure Sinewave Generator Function
-- Creates one complete sine wave cycle from 0.5 to 1.0 to 0.5 to 0.0 to 0.5
-- Parameters:
--   sample_rate: Sample rate (e.g., 44100)
--   frequency: Frequency of the sine wave (e.g., 440 for A4)
--   duration: Duration in seconds (optional, defaults to one cycle)
function generatePureSinewave(sample_rate, frequency, duration)
  sample_rate = sample_rate or 44100
  frequency = frequency or 440
  
  -- Use 1024 frames for high resolution, with one complete cycle
  local num_samples = 1024
  local samples = {}
  
  print("Generating sine wave:")
  print("- Sample rate: " .. sample_rate .. " Hz")
  print("- Frequency: " .. frequency .. " Hz (for naming)")
  print("- Number of samples: " .. num_samples .. " (one complete cycle, high resolution)")
  
  -- Generate the sine wave samples for exactly one cycle over 1024 frames
  for i = 0, num_samples - 1 do
    -- Calculate the phase (0 to 2*pi for one complete cycle over 1024 frames)
    local phase = (2.0 * math.pi * i) / num_samples
    
    -- Calculate sine wave value (-1 to 1)
    local sine_value = math.sin(phase)
    
    -- Scale and offset to go from 0.5 to 1.0 to 0.5 to 0.0 to 0.5
    -- sine_value * 0.5 + 0.5 gives us 0.0 to 1.0 range with 0.5 center
    local sample_value = sine_value * 0.5 + 0.5
    
    -- Store the sample (clamped to ensure it stays in range)
    samples[i + 1] = math.max(0.0, math.min(1.0, sample_value))
  end
  
  print("Sine wave generation completed")
  print("Sample range: " .. string.format("%.3f", samples[1]) .. " to " .. string.format("%.3f", samples[math.floor(num_samples/2) + 1]) .. " to " .. string.format("%.3f", samples[num_samples]))
  
  return samples, num_samples
end

-- Function to create a sine wave sample in Renoise
function createSinewaveSample(sample_rate, frequency, duration)
  local song = renoise.song()
  
  -- Check if we have a selected instrument
  if not song.selected_instrument_index or song.selected_instrument_index == 0 then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument available")
    return
  end
  
  -- Generate the sine wave data
  local samples, num_samples = generatePureSinewave(sample_rate, frequency, duration)
  
  -- Create a new sample in the instrument
  local sample_index = #instrument.samples + 1
  instrument:insert_sample_at(sample_index)
  local sample = instrument.samples[sample_index]
  
  -- Set sample properties
  sample.name = "Sine " .. frequency .. "Hz"
  
  -- Create sample buffer
  sample.sample_buffer:create_sample_data(sample_rate, 16, 1, num_samples)
  local buffer = sample.sample_buffer
  
  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    -- Write the sine wave data to the sample buffer
    for i = 1, num_samples do
      -- Convert 0.0-1.0 range to -1.0 to 1.0 range for sample buffer
      local buffer_value = (samples[i] - 0.5) * 2.0
      buffer:set_sample_data(1, i, buffer_value)
    end
    buffer:finalize_sample_data_changes()
    
    -- Set up sample mapping
    sample.sample_mapping.base_note = 48 -- C-4
    sample.sample_mapping.note_range = {0, 119}
    sample.sample_mapping.velocity_range = {0, 127}
    
    -- Add loop from 1st frame to last frame
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = buffer.number_of_frames
    
    -- Set instrument name
    instrument.name = "sinewave[" .. frequency .. "hz][" .. buffer.number_of_frames .. " frames]"
    
    -- Go to sample editor
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    
    print("Created sine wave sample: " .. sample.name)
    print("Sample properties:")
    print("- Index: " .. sample_index)
    print("- Sample rate: " .. buffer.sample_rate .. " Hz")
    print("- Bit depth: " .. buffer.bit_depth .. " bit")
    print("- Channels: " .. buffer.number_of_channels)
    print("- Length: " .. buffer.number_of_frames .. " frames")
    print("- Loop: " .. sample.loop_start .. " to " .. sample.loop_end)
    print("- Duration: " .. string.format("%.4f", buffer.number_of_frames / buffer.sample_rate) .. " seconds")
    
    renoise.app():show_status("Created sine wave sample: " .. sample.name)
  else
    renoise.app():show_status("Error: Could not create sample data")
    print("Error: Sample buffer has no data")
  end
end

-- Function to generate amplitude modulated sine wave
function generateAmplitudeModulatedSinewave(sample_rate, frequency, modulation_multiplier, modulation_amplitude)
  sample_rate = sample_rate or 44100
  frequency = frequency or 440
  modulation_multiplier = modulation_multiplier or 20
  modulation_amplitude = modulation_amplitude or 30
  
  -- Use 1024 frames for high resolution, with one complete cycle
  local num_samples = 1024
  local samples = {}
  
  print("Generating amplitude modulated sine wave:")
  print("- Sample rate: " .. sample_rate .. " Hz")
  print("- Base frequency: " .. frequency .. " Hz (for naming)")
  print("- Modulation: " .. modulation_multiplier .. "x faster")
  print("- Modulation amplitude: " .. modulation_amplitude .. "%")
  print("- Number of samples: " .. num_samples .. " (one base cycle, high resolution)")
  
  -- Convert amplitude percentage to decimal (0-100% -> 0.0-1.0)
  local amp_factor = modulation_amplitude / 100.0
  
  -- Generate the amplitude modulated sine wave
  for i = 0, num_samples - 1 do
    -- Master sine wave: one complete cycle over 1024 frames
    -- Generate directly in 0.25 to 0.75 range (centered at 0.5)
    local master_phase = (2.0 * math.pi * i) / num_samples
    local master_sine = math.sin(master_phase)
    local base_sample = master_sine * 0.25 + 0.5  -- Scale to 0.25-0.75 range
    
    -- Modulation sine wave: faster cycles for the tiny ripples
    local mod_phase = (2.0 * math.pi * modulation_multiplier * i) / num_samples
    local mod_sine = math.sin(mod_phase)
    
    -- Apply amplitude modulation to the base sample
    -- modulation_sine ranges from -1 to 1, so we scale it by amp_factor
    local modulated_sample = base_sample * (1.0 + amp_factor * mod_sine)
    
    -- Store the sample (clamped to ensure it stays in valid range)
    samples[i + 1] = math.max(0.0, math.min(1.0, modulated_sample))
  end
  
  print("Amplitude modulated sine wave generation completed")
  print("Sample range: " .. string.format("%.3f", samples[1]) .. " to " .. string.format("%.3f", samples[math.floor(num_samples/2) + 1]) .. " to " .. string.format("%.3f", samples[num_samples]))
  
  return samples, num_samples
end

-- Function to create amplitude modulated sine wave sample in Renoise
function createAmplitudeModulatedSinewaveSample(sample_rate, frequency, modulation_multiplier, modulation_amplitude)
  local song = renoise.song()
  
  -- Check if we have a selected instrument
  if not song.selected_instrument_index or song.selected_instrument_index == 0 then
    renoise.app():show_status("No instrument selected")
    return
  end
  
  local instrument = song.selected_instrument
  if not instrument then
    renoise.app():show_status("No instrument available")
    return
  end
  
  -- Generate the amplitude modulated sine wave data
  local samples, num_samples = generateAmplitudeModulatedSinewave(sample_rate, frequency, modulation_multiplier, modulation_amplitude)
  
  -- Create a new sample in the instrument
  local sample_index = #instrument.samples + 1
  instrument:insert_sample_at(sample_index)
  local sample = instrument.samples[sample_index]
  
  -- Set sample properties
  sample.name = "AM Sine " .. frequency .. "Hz (mod " .. modulation_multiplier .. "x, amp " .. (modulation_amplitude or 30) .. "%)"
  
  -- Create sample buffer
  sample.sample_buffer:create_sample_data(sample_rate, 16, 1, num_samples)
  local buffer = sample.sample_buffer
  
  if buffer.has_sample_data then
    buffer:prepare_sample_data_changes()
    -- Write the sine wave data to the sample buffer
    for i = 1, num_samples do
      -- Convert 0.0-1.0 range to -1.0 to 1.0 range for sample buffer
      local buffer_value = (samples[i] - 0.5) * 2.0
      buffer:set_sample_data(1, i, buffer_value)
    end
    buffer:finalize_sample_data_changes()
    
    -- Set up sample mapping
    sample.sample_mapping.base_note = 48 -- C-4
    sample.sample_mapping.note_range = {0, 119}
    sample.sample_mapping.velocity_range = {0, 127}
    
    -- Add loop from 1st frame to last frame
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    sample.loop_start = 1
    sample.loop_end = buffer.number_of_frames
    
    -- Set instrument name
    instrument.name = "am_sinewave[" .. frequency .. "hz][mod " .. modulation_multiplier .. "x][amp " .. (modulation_amplitude or 30) .. "%][" .. buffer.number_of_frames .. " frames]"
    
    -- Go to sample editor
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    
    print("Created amplitude modulated sine wave sample: " .. sample.name)
    renoise.app():show_status("Created AM sine wave sample: " .. sample.name)
  else
    renoise.app():show_status("Error: Could not create sample data")
    print("Error: Sample buffer has no data")
  end
end

-- Function for custom frequency sine wave generation
function createCustomSinewave()
  local vb = renoise.ViewBuilder()
  local frequency_text = vb:textfield{
    text = "440",
    width = 80
  }
  
  local dialog_content = vb:column{
    margin = 10,
    vb:row{
      vb:text{text = "Enter frequency in Hz (1-20000):"}
    },
    vb:row{
      frequency_text
    },
    vb:row{
      vb:button{
        text = "OK",
        width = 80,
        notifier = function()
          local freq_str = frequency_text.text
          local freq = tonumber(freq_str)
          if freq and freq > 0 and freq <= 20000 then
            createSinewaveSample(44100, freq, nil)
            -- Close dialog by setting it to nil - will be handled by dialog framework
          else
            renoise.app():show_status("Invalid frequency. Please enter a value between 1-20000 Hz")
          end
        end
      },
      vb:button{
        text = "Cancel",
        width = 80,
        notifier = function()
          -- Cancel button - dialog will close automatically
        end
      }
    }
  }
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  renoise.app():show_custom_dialog("Sine Wave Generator", dialog_content, keyhandler)
end

-- Function for custom amplitude modulated sine wave generation
function createCustomAmplitudeModulatedSinewave()
  local vb = renoise.ViewBuilder()
  local frequency_text = vb:textfield{
    text = "440",
    width = 80
  }
  local modulation_text = vb:textfield{
    text = "20",
    width = 80
  }
  local amplitude_text = vb:textfield{
    text = "30",
    width = 80
  }
  
  local dialog_content = vb:column{
    margin = 10,
    vb:row{
      vb:text{text = "Enter base frequency in Hz (1-20000):"}
    },
    vb:row{
      frequency_text
    },
    vb:row{
      vb:text{text = "Enter modulation multiplier (1-1000):"}
    },
    vb:row{
      modulation_text
    },
    vb:row{
      vb:text{text = "Enter modulation amplitude % (1-100):"}
    },
    vb:row{
      amplitude_text
    },
    vb:row{
      vb:button{
        text = "OK",
        width = 80,
        notifier = function()
          local freq_str = frequency_text.text
          local mod_str = modulation_text.text
          local amp_str = amplitude_text.text
          local freq = tonumber(freq_str)
          local mod = tonumber(mod_str)
          local amp = tonumber(amp_str)
          if freq and freq > 0 and freq <= 20000 and 
             mod and mod > 0 and mod <= 1000 and
             amp and amp > 0 and amp <= 100 then
            createAmplitudeModulatedSinewaveSample(44100, freq, mod, amp)
            -- Keep dialog open for multiple generations
            renoise.app():show_status("Generated AM sine wave: " .. freq .. "Hz, mod " .. mod .. "x, amp " .. amp .. "%")
          else
            renoise.app():show_status("Invalid values. Frequency: 1-20000 Hz, Modulation: 1-1000x, Amplitude: 1-100%")
          end
        end
      },
      vb:button{
        text = "Cancel",
        width = 80,
        notifier = function()
          -- Cancel button - dialog will close automatically
        end
      }
    }
  }
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  renoise.app():show_custom_dialog("AM Sine Wave Generator", dialog_content, keyhandler)
end


renoise.tool():add_keybinding{name = "Global:Paketti:Generate Pure Sinewave 440Hz", invoke = function() createSinewaveSample(44100, 440, nil) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate Pure Sinewave 1000Hz", invoke = function() createSinewaveSample(44100, 1000, nil) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate Pure Sinewave Custom", invoke = createCustomSinewave}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate AM Sinewave 440Hz (20x mod)", invoke = function() createAmplitudeModulatedSinewaveSample(44100, 440, 20, 30) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate AM Sinewave 1000Hz (20x mod)", invoke = function() createAmplitudeModulatedSinewaveSample(44100, 1000, 20, 30) end}
renoise.tool():add_keybinding{name = "Global:Paketti:Generate AM Sinewave Custom", invoke = createCustomAmplitudeModulatedSinewave}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Generate:Pure Sinewave 440Hz",invoke = function() createSinewaveSample(44100, 440, nil) end}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Generate:Pure Sinewave 1000Hz",invoke = function() createSinewaveSample(44100, 1000, nil) end}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Generate:Pure Sinewave Custom Frequency",invoke = createCustomSinewave}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Generate:AM Sinewave 440Hz (20x mod)",invoke = function() createAmplitudeModulatedSinewaveSample(44100, 440, 20, 30) end}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Generate:AM Sinewave 1000Hz (20x mod)",invoke = function() createAmplitudeModulatedSinewaveSample(44100, 1000, 20, 30) end}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Generate:AM Sinewave Custom",invoke = createCustomAmplitudeModulatedSinewave}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Generate:Pure Sinewave 440Hz",invoke = function() createSinewaveSample(44100, 440, nil) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Generate:Pure Sinewave 1000Hz",invoke = function() createSinewaveSample(44100, 1000, nil) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Generate:Pure Sinewave Custom Frequency",invoke = createCustomSinewave}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Generate:AM Sinewave 440Hz (20x mod)",invoke = function() createAmplitudeModulatedSinewaveSample(44100, 440, 20, 30) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Generate:AM Sinewave 1000Hz (20x mod)",invoke = function() createAmplitudeModulatedSinewaveSample(44100, 1000, 20, 30) end}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Generate:AM Sinewave Custom",invoke = createCustomAmplitudeModulatedSinewave}

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
