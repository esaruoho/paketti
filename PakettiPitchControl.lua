local dialog = nil


-- Function to calculate length of a specific sample selection/range
function calculate_sample_selection_length()
  local song = renoise.song()
  
  if not song.selected_sample or not song.selected_sample.sample_buffer then
    return nil, "No sample selected"
  end
  
  local sample = song.selected_sample
  local buffer = sample.sample_buffer
  
  if not buffer.has_sample_data then
    return nil, "Sample has no data"
  end
  
  -- Get selection range
  local selection_start = buffer.selection_start
  local selection_end = buffer.selection_end
  
  -- If no selection, use entire sample
  if selection_start == 0 and selection_end == 0 then
    selection_start = 1
    selection_end = buffer.number_of_frames
  end
  
  local selection_frames = selection_end - selection_start + 1
  local sample_rate = buffer.sample_rate
  local selection_length = selection_frames / sample_rate
  
  print("Sample selection length calculation:")
  print("  Selection start: " .. selection_start)
  print("  Selection end: " .. selection_end) 
  print("  Selection frames: " .. selection_frames)
  print("  Sample rate: " .. sample_rate .. " Hz")
  print("  Selection length: " .. string.format("%.6f", selection_length) .. " seconds")
  
  return selection_length, nil
end


-- Function to calculate the length of the selected sample in seconds
function calculate_selected_sample_length()
  local song = renoise.song()
  
  -- Check if there's a selected instrument
  if not song.selected_instrument then
    print("No instrument selected")
    return nil, "No instrument selected"
  end
  
  -- Check if there's a selected sample
  if not song.selected_sample then
    print("No sample selected") 
    return nil, "No sample selected"
  end
  
  local sample = song.selected_sample
  
  -- Check if sample has buffer (sample data)
  if not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    print("Sample has no data")
    return nil, "Sample has no data"
  end
  
  -- Get sample properties
  local sample_rate = sample.sample_buffer.sample_rate
  local number_of_frames = sample.sample_buffer.number_of_frames
  
  -- Calculate length in seconds
  local length_in_seconds = number_of_frames / sample_rate
  
  -- Print debug information
  print("Sample length calculation:")
  print("  Sample rate: " .. sample_rate .. " Hz")
  print("  Number of frames: " .. number_of_frames)
  print("  Length: " .. string.format("%.6f", length_in_seconds) .. " seconds")
  
  return length_in_seconds, nil
end

-- Function to calculate BPM from sample length, beatsync, and transpose
function calculate_bpm_from_sample_beatsync()
  local length_seconds, error_msg = calculate_selected_sample_length()
  if error_msg then
    return nil, nil, nil
  end
  
  local song = renoise.song()
  local sample = song.selected_sample
  local beat_sync_lines = sample.beat_sync_lines
  local lpb = song.transport.lpb
  
  if beat_sync_lines <= 0 or lpb <= 0 or length_seconds <= 0 then
    return nil, nil, nil
  end
  
  local transpose = sample.transpose
  local finetune = sample.fine_tune
  local cents = (transpose * 100) + (finetune / 128 * 100)
  local bpm_factor = math.pow(2, (cents / 1200))
  local calculated_bpm = 60 / lpb / length_seconds * beat_sync_lines * bpm_factor
  
  return calculated_bpm, length_seconds, beat_sync_lines
end

-- Function to calculate and set BPM from sample beatsync
function set_bpm_from_sample_beatsync()
  local calculated_bpm, length_seconds, beat_sync_lines = calculate_bpm_from_sample_beatsync()
  
  if not calculated_bpm then
    return
  end
  
  -- Check if BPM is within valid range
  if calculated_bpm < 20 or calculated_bpm > 999 then
    local message = string.format("Calculated BPM %.3f is outside valid range (20-999)", calculated_bpm)
    renoise.app():show_status(message)
    print(message)
    return
  end
  
  local song = renoise.song()
  local sample = song.selected_sample
  
  -- Set both BPM and beat sync lines
  song.transport.bpm = calculated_bpm
  sample.beat_sync_lines = beat_sync_lines
  
  local status_message = string.format("BPM set to %.3f and Beat Sync Lines set to %d (%.6fs sample)", 
    calculated_bpm, beat_sync_lines, length_seconds)
  renoise.app():show_status(status_message)
  print("SUCCESS: " .. status_message)
  
  return calculated_bpm
end

-- Function to show BPM calculation dialog with custom beat sync lines
function pakettiBpmFromSampleDialog()
  local vb = renoise.ViewBuilder()
  if dialog and dialog.visible then dialog:close() dialog=nil return end
  
  -- Flag to prevent vinyl slider notifier from firing during initialization
  local initializing_vinyl_slider = false
  -- Flag to prevent feedback loop when vinyl slider updates valueboxes
  local updating_from_vinyl_slider = false
  
  -- Pitch range settings (transpose ranges)
  local pitch_ranges = {
    {name = "±3", range = 3 * 128, scale = 1.0},    -- ±3 semitones
    {name = "±12", range = 12 * 128, scale = 1.0},  -- ±12 semitones (1 octave)
    {name = "±24", range = 24 * 128, scale = 1.0},  -- ±24 semitones (2 octaves)
    {name = "±120", range = 120 * 128, scale = 1.0}, -- ±120 semitones (full range)
    {name = "Legacy", range = 2000, scale = 1.5}    -- Legacy ±2000 with 1.5 scale
  }
  -- Load range from preferences, default to ±12 (index 2) if not set
  local current_range_index = 2  -- Default: ±12 (Normal)
  if preferences and preferences.pakettiPitchSliderRange and preferences.pakettiPitchSliderRange.value then
    current_range_index = preferences.pakettiPitchSliderRange.value
    -- Clamp to valid range (1-5)
    current_range_index = math.max(1, math.min(5, current_range_index))
    print(string.format("-- BPM Dialog: Loaded pitch slider range from preferences: %d (%s)", 
      current_range_index, pitch_ranges[current_range_index].name))
  else
    print("-- BPM Dialog: Using default pitch slider range: ±12")
  end
  
  -- Function to get current pitch range settings
  local function get_current_range()
    return pitch_ranges[current_range_index]
  end
  
  -- Function to update slider range and recalculate position
  local function update_slider_range()
    local range_settings = get_current_range()
    local slider = vb.views.vinyl_pitch_slider
    
    if slider then
      -- Get current transpose/finetune values
      local current_transpose = vb.views.transpose_valuebox.value
      local current_finetune = vb.views.finetune_valuebox.value
      
      -- Update slider range
      slider.min = -range_settings.range
      slider.max = range_settings.range
      
      -- Recalculate slider position with new scaling
      initializing_vinyl_slider = true
      local vinyl_pitch_value = (current_transpose * 128) + current_finetune
      vinyl_pitch_value = vinyl_pitch_value / range_settings.scale
      vinyl_pitch_value = math.max(-range_settings.range, math.min(range_settings.range, vinyl_pitch_value))
      slider.value = vinyl_pitch_value
      initializing_vinyl_slider = false
      
      print(string.format("-- BPM Dialog: Range changed to %s (±%d, scale=%.1f)", 
        range_settings.name, range_settings.range, range_settings.scale))
    end
  end
  
  -- Get initial values
  local length_seconds, error_msg = calculate_selected_sample_length()
  if error_msg then
    renoise.app():show_status(error_msg)
    return
  end
  
  local song = renoise.song()
  local sample = song.selected_sample
  local instrument = song.selected_instrument
  local current_lpb = song.transport.lpb
  local current_beat_sync = sample.beat_sync_lines
  
  -- Get sample name
  local sample_name = sample.name
  if sample_name == "" then
    sample_name = "[Untitled Sample]"
  end
  
  -- Forward declaration for update_calculation
  local update_calculation
  
  -- Observer function to update dialog when selection changes
  local function update_dialog_on_selection_change()
    if not dialog or not dialog.visible then
      return -- Dialog is not visible, no need to update
    end
    
    -- Check if we still have valid selections
    local current_song = renoise.song()
    if not current_song.selected_instrument or not current_song.selected_sample then
      return
    end
    
    -- Recalculate with new selection
    local new_length_seconds, new_error_msg = calculate_selected_sample_length()
    if new_error_msg then
      return -- Can't update if no valid sample
    end
    
    -- Update the length value used by update_calculation
    length_seconds = new_length_seconds
    
    -- Update sample name
    local new_sample = current_song.selected_sample
    local new_sample_name = new_sample.name
    if new_sample_name == "" then
      new_sample_name = "[Untitled Sample]"
    end
    sample_name = new_sample_name
    
    -- Update beat sync default
    if vb.views and vb.views.beat_sync_valuebox then
      vb.views.beat_sync_valuebox.value = new_sample.beat_sync_lines
    end
    
    -- Trigger recalculation
    if update_calculation then
      update_calculation()
    end
  end
  
  update_calculation = function()
    local beat_sync_lines = vb.views.beat_sync_valuebox.value
    local lpb = vb.views.lpb_valuebox.value
    local calculated_bpm = 60 / lpb / length_seconds * beat_sync_lines
    
    -- Always use current selected instrument index
    local current_song = renoise.song()
    local current_instrument_index = current_song.selected_instrument_index
    local current_instrument = current_song.selected_instrument
    local current_sample = current_song.selected_sample
    local instrument_hex = string.format("%02X", current_instrument_index - 1)  -- Renoise uses 0-based for display
    
    -- Update transpose/finetune valueboxes with current sample values
    if vb.views.transpose_valuebox then
      vb.views.transpose_valuebox.value = current_sample.transpose
    end
    if vb.views.finetune_valuebox then
      vb.views.finetune_valuebox.value = current_sample.fine_tune
    end
    
    -- Calculate pitch-compensated BPM
    local transpose = current_sample.transpose
    local finetune = current_sample.fine_tune
    local cents = (transpose * 100) + (finetune / 128 * 100)
    local bpm_factor = math.pow(2, (cents / 1200))
    local calculated_bpm_pitch = calculated_bpm * bpm_factor
    
    -- Update each value individually
    vb.views.instrument_value.text = string.format("%s (%s)", instrument_hex, current_instrument.name)
    vb.views.sample_value.text = sample_name
    vb.views.length_value.text = string.format("%.3f seconds", length_seconds)
    vb.views.beatsync_value.text = tostring(beat_sync_lines)
    vb.views.lpb_value.text = tostring(lpb)
    vb.views.bpm_value.text = string.format("%.3f", calculated_bpm)
    if vb.views.bpm_pitch_value then
      vb.views.bpm_pitch_value.text = string.format("%.3f", calculated_bpm_pitch)
    end
    
    -- Show warning if out of range (check both BPM values)
    if (calculated_bpm < 20 or calculated_bpm > 999) or (calculated_bpm_pitch < 20 or calculated_bpm_pitch > 999) then
      vb.views.warning_text.text = "WARNING: BPM outside valid range (20-999)!"
    else
      vb.views.warning_text.text = ""
    end
    
    return calculated_bpm
  end
  
  local function write_note_to_pattern()
    local track = song.selected_track
    local pattern_line = renoise.song().selected_pattern.tracks[renoise.song().selected_track_index]:line(1)
    local note_column = pattern_line:note_column(1)
    
    -- Always use current selected instrument index
    local current_song = renoise.song()
    local current_instrument_index = current_song.selected_instrument_index
    local current_instrument = current_song.selected_instrument
    
    -- Write note using sample mapping's basenote (the actual trigger note)
    local mapping_base_note = current_instrument.sample_mappings[1][current_song.selected_sample_index].base_note
    note_column.note_value = mapping_base_note
    note_column.instrument_value = current_instrument_index - 1  -- 0-based for pattern data
    
    -- Note: Sample selection within instrument is handled by the note mapping and base_note
    
    return true
  end
  local textWidth= 110
  local dialog_content = vb:column{    
    vb:row{
      vb:checkbox{
        id = "auto_set_bpm_beatsync_checkbox",
        value = false,
        notifier = function(value)
          if value then
            -- Turn off the pitch auto-set when beatsync auto-set is enabled
            if vb.views.auto_set_bpm_pitch_checkbox then
              vb.views.auto_set_bpm_pitch_checkbox.value = false
            end
            -- Auto-set BPM immediately when checkbox is turned on
            local beat_sync_lines = vb.views.beat_sync_valuebox.value
            local lpb = vb.views.lpb_valuebox.value
            local calculated_bpm = 60 / lpb / length_seconds * beat_sync_lines
            if calculated_bpm >= 20 and calculated_bpm <= 999 then
              renoise.song().transport.bpm = calculated_bpm
              renoise.app():show_status(string.format("Auto-set BPM (Beatsync) enabled: BPM set to %.3f", calculated_bpm))
            else
              renoise.app():show_status("Auto-set BPM (Beatsync) enabled: BPM outside valid range (20-999)")
            end
          else
            renoise.app():show_status("Auto-set BPM (Beatsync) disabled")
          end
        end
      },
      vb:text{text = "Auto-Set BPM (Beatsync)", width = textWidth, style = "strong", font = "bold"}
    },
    vb:row{
      vb:text{text="Beatsync",width=60,style="strong",font="bold"},
      vb:valuebox{id = "beat_sync_valuebox",min=1,max=512,value = current_beat_sync,
        width = 50,notifier = function(value)
          update_calculation()
          renoise.song().selected_sample.beat_sync_lines = value
          -- Auto-set BPM if beatsync checkbox is enabled
          if vb.views.auto_set_bpm_beatsync_checkbox and vb.views.auto_set_bpm_beatsync_checkbox.value then
            local beat_sync_lines = value
            local lpb = vb.views.lpb_valuebox.value
            local calculated_bpm = 60 / lpb / length_seconds * beat_sync_lines
            if calculated_bpm >= 20 and calculated_bpm <= 999 then
              renoise.song().transport.bpm = calculated_bpm
            end
          end
        end
      },
      vb:switch{
        items = {"OFF", "4", "8", "16", "32", "64", "128", "256", "512"},
        value = 1,
        width = 200,
        notifier = function(index)
          local values = {0, 4, 8, 16, 32, 64, 128, 256, 512}
          local selected_value = values[index]
          
          if selected_value == 0 then
            renoise.song().selected_sample.beat_sync_enabled = false
            renoise.app():show_status("Beatsync deactivated")
          else
            vb.views.beat_sync_valuebox.value = selected_value
            renoise.song().selected_sample.beat_sync_enabled = true
            renoise.song().selected_sample.beat_sync_lines = selected_value
            renoise.app():show_status(string.format("Beatsync set to %d lines", selected_value))
            -- Auto-set BPM if beatsync checkbox is enabled
            if vb.views.auto_set_bpm_beatsync_checkbox and vb.views.auto_set_bpm_beatsync_checkbox.value then
              local beat_sync_lines = selected_value
              local lpb = vb.views.lpb_valuebox.value
              local calculated_bpm = 60 / lpb / length_seconds * beat_sync_lines
              if calculated_bpm >= 20 and calculated_bpm <= 999 then
                renoise.song().transport.bpm = calculated_bpm
              end
            end
          end
          update_calculation()
        end
      },
      vb:button{
        text = "/2",
        width = 30,
        notifier = function()
          local current_value = vb.views.beat_sync_valuebox.value
          local new_value = math.max(1, math.floor(current_value / 2))
          vb.views.beat_sync_valuebox.value = new_value
          renoise.song().selected_sample.beat_sync_enabled = true
          renoise.song().selected_sample.beat_sync_lines = new_value
          renoise.app():show_status(string.format("Beatsync set to %d lines", new_value))
          -- Auto-set BPM if beatsync checkbox is enabled
          if vb.views.auto_set_bpm_beatsync_checkbox and vb.views.auto_set_bpm_beatsync_checkbox.value then
            local beat_sync_lines = new_value
            local lpb = vb.views.lpb_valuebox.value
            local calculated_bpm = 60 / lpb / length_seconds * beat_sync_lines
            if calculated_bpm >= 20 and calculated_bpm <= 999 then
              renoise.song().transport.bpm = calculated_bpm
            end
          end
          update_calculation()
        end
      },
      vb:button{
        text = "*2",
        width = 30,
        notifier = function()
          local current_value = vb.views.beat_sync_valuebox.value
          local new_value = math.min(512, current_value * 2)
          vb.views.beat_sync_valuebox.value = new_value
          renoise.song().selected_sample.beat_sync_enabled = true
          renoise.song().selected_sample.beat_sync_lines = new_value
          renoise.app():show_status(string.format("Beatsync set to %d lines", new_value))
          -- Auto-set BPM if beatsync checkbox is enabled
          if vb.views.auto_set_bpm_beatsync_checkbox and vb.views.auto_set_bpm_beatsync_checkbox.value then
            local beat_sync_lines = new_value
            local lpb = vb.views.lpb_valuebox.value
            local calculated_bpm = 60 / lpb / length_seconds * beat_sync_lines
            if calculated_bpm >= 20 and calculated_bpm <= 999 then
              renoise.song().transport.bpm = calculated_bpm
            end
          end
          update_calculation()
        end
      }
    },
    
    vb:row{
      vb:text{text="LPB",width=60,style="strong",font="bold"},
      vb:valuebox{
        id = "lpb_valuebox",
        min = 1,
        max = 256,
        value = current_lpb,
        width = 50,
        notifier = function(value)
          renoise.song().transport.lpb = value
          renoise.app():show_status(string.format("LPB set to %d", value))
          update_calculation()
        end
      },
      vb:switch{
        items = {"1", "2", "4", "8", "16", "24", "32", "48", "64"},
        value = 3,
        width = 200,
        notifier = function(index)
          local values = {1, 2, 4, 8, 16, 24, 32, 48, 64}
          local selected_value = values[index]
          vb.views.lpb_valuebox.value = selected_value
          renoise.song().transport.lpb = selected_value
          renoise.app():show_status(string.format("LPB set to %d", selected_value))
          update_calculation()
        end
      },
      vb:button{
        text = "/2",
        width = 30,
        notifier = function()
          local current_value = vb.views.lpb_valuebox.value
          local new_value = math.max(1, math.floor(current_value / 2))
          vb.views.lpb_valuebox.value = new_value
          renoise.song().transport.lpb = new_value
          renoise.app():show_status(string.format("LPB set to %d", new_value))
          update_calculation()
        end
      },
      vb:button{
        text = "*2",
        width = 30,
        notifier = function()
          local current_value = vb.views.lpb_valuebox.value
          local new_value = math.min(256, current_value * 2)
          vb.views.lpb_valuebox.value = new_value
          renoise.song().transport.lpb = new_value
          renoise.app():show_status(string.format("LPB set to %d", new_value))
          update_calculation()
        end
      }
    },
    
    -- Information display in two columns
    
    vb:row{
      vb:text{text = "Instrument", width = textWidth, style = "strong", font = "bold"},
      vb:text{id = "instrument_value", text = "", style = "strong", font = "bold"}
    },
    vb:row{
      vb:text{text = "Sample", width = textWidth, style = "strong", font = "bold"},
      vb:text{id = "sample_value", text = "", style = "strong", font = "bold"}
    },
    vb:row{
      vb:text{text = "Length", width = textWidth, style = "strong", font = "bold"},
      vb:text{id = "length_value", text = "", style = "strong", font = "bold"}
    },
    vb:row{
      vb:text{text = "Beatsync", width = textWidth, style = "strong", font = "bold"},
      vb:text{id = "beatsync_value", text = "", style = "strong", font = "bold"}
    },
    vb:row{
      vb:text{text = "LPB", width = textWidth, style = "strong", font = "bold"},
      vb:text{id = "lpb_value", text = "", style = "strong", font = "bold"}
    },
    vb:row{
      vb:checkbox{
        id = "auto_set_bpm_pitch_checkbox",
        value = false,
        notifier = function(value)
          if value then
            -- Turn off the beatsync auto-set when pitch auto-set is enabled
            if vb.views.auto_set_bpm_beatsync_checkbox then
              vb.views.auto_set_bpm_beatsync_checkbox.value = false
            end
            -- Auto-set BPM immediately when checkbox is turned on
            local beat_sync_lines = vb.views.beat_sync_valuebox.value
            local lpb = vb.views.lpb_valuebox.value
            local calculated_bpm = 60 / lpb / length_seconds * beat_sync_lines
            local transpose = renoise.song().selected_sample.transpose
            local finetune = renoise.song().selected_sample.fine_tune
            local cents = (transpose * 100) + (finetune / 128 * 100)
            local bpm_factor = math.pow(2, (cents / 1200))
            local calculated_bpm_pitch = calculated_bpm * bpm_factor
            if calculated_bpm_pitch >= 20 and calculated_bpm_pitch <= 999 then
              renoise.song().transport.bpm = calculated_bpm_pitch
              renoise.app():show_status(string.format("Auto-set BPM (Pitch) enabled: BPM set to %.3f", calculated_bpm_pitch))
            else
              renoise.app():show_status("Auto-set BPM (Pitch) enabled: BPM outside valid range (20-999)")
            end
          else
            renoise.app():show_status("Auto-set BPM (Pitch) disabled")
          end
        end
      },
      vb:text{text = "Auto-Set BPM (Pitch)", width = textWidth, style = "strong", font = "bold"}
    },
    vb:row{
      vb:text{text = "Transpose", width = textWidth, style = "strong", font = "bold"},
      vb:valuebox{
        id = "transpose_valuebox",
        min = -120,
        max = 120,
        value = 0,
        width = 60,
        notifier = function(value)
          renoise.song().selected_sample.transpose = value
          -- Update vinyl pitch slider to match (vinyl-style calculation) - only if not updating from vinyl slider
          if not updating_from_vinyl_slider then
            local current_finetune = vb.views.finetune_valuebox.value
            local range_settings = get_current_range()
            -- Convert transpose + finetune back to continuous vinyl position
            local vinyl_pitch_value = (value * 128) + current_finetune
            vinyl_pitch_value = vinyl_pitch_value / range_settings.scale
            vinyl_pitch_value = math.max(-range_settings.range, math.min(range_settings.range, vinyl_pitch_value))
            vb.views.vinyl_pitch_slider.value = vinyl_pitch_value
          end
          update_calculation()
          -- Auto-set BPM if checkbox is enabled
          if vb.views.auto_set_bpm_pitch_checkbox and vb.views.auto_set_bpm_pitch_checkbox.value then
            local beat_sync_lines = vb.views.beat_sync_valuebox.value
            local lpb = vb.views.lpb_valuebox.value
            local calculated_bpm = 60 / lpb / length_seconds * beat_sync_lines
            local transpose = renoise.song().selected_sample.transpose
            local finetune = renoise.song().selected_sample.fine_tune
            local cents = (transpose * 100) + (finetune / 128 * 100)
            local bpm_factor = math.pow(2, (cents / 1200))
            local calculated_bpm_pitch = calculated_bpm * bpm_factor
            if calculated_bpm_pitch >= 20 and calculated_bpm_pitch <= 999 then
              renoise.song().transport.bpm = calculated_bpm_pitch
            end
          end
        end
      },
      vb:button{
        text = "0",
        width = 30,
        notifier = function()
          vb.views.transpose_valuebox.value = 0
          renoise.song().selected_sample.transpose = 0
          -- Update vinyl pitch slider to match (vinyl-style calculation) - only if not updating from vinyl slider
          if not updating_from_vinyl_slider then
            local current_finetune = vb.views.finetune_valuebox.value
            -- Convert transpose + finetune back to continuous vinyl position
            local vinyl_pitch_value = (0 * 128) + current_finetune
            vinyl_pitch_value = vinyl_pitch_value / 1.5  -- Scale back down to match new scaling
            vinyl_pitch_value = math.max(-2000, math.min(2000, vinyl_pitch_value))
            vb.views.vinyl_pitch_slider.value = vinyl_pitch_value
          end
          update_calculation()
          -- Auto-set BPM if checkbox is enabled
          if vb.views.auto_set_bpm_pitch_checkbox and vb.views.auto_set_bpm_pitch_checkbox.value then
            local beat_sync_lines = vb.views.beat_sync_valuebox.value
            local lpb = vb.views.lpb_valuebox.value
            local calculated_bpm = 60 / lpb / length_seconds * beat_sync_lines
            local transpose = renoise.song().selected_sample.transpose
            local finetune = renoise.song().selected_sample.fine_tune
            local cents = (transpose * 100) + (finetune / 128 * 100)
            local bpm_factor = math.pow(2, (cents / 1200))
            local calculated_bpm_pitch = calculated_bpm * bpm_factor
            if calculated_bpm_pitch >= 20 and calculated_bpm_pitch <= 999 then
              renoise.song().transport.bpm = calculated_bpm_pitch
            end
          end
        end
      }
    },
    vb:row{
      vb:text{text = "Finetune", width = textWidth, style = "strong", font = "bold"},
      vb:valuebox{
        id = "finetune_valuebox",
        min = -127,
        max = 127,
        value = 0,
        width = 60,
        notifier = function(value)
          renoise.song().selected_sample.fine_tune = value
          -- Update vinyl pitch slider to match (vinyl-style calculation) - only if not updating from vinyl slider
          if not updating_from_vinyl_slider then
            local current_transpose = vb.views.transpose_valuebox.value
            local range_settings = get_current_range()
            -- Convert transpose + finetune back to continuous vinyl position
            local vinyl_pitch_value = (current_transpose * 128) + value
            vinyl_pitch_value = vinyl_pitch_value / range_settings.scale
            vinyl_pitch_value = math.max(-range_settings.range, math.min(range_settings.range, vinyl_pitch_value))
            vb.views.vinyl_pitch_slider.value = vinyl_pitch_value
          end
          update_calculation()
          -- Auto-set BPM if checkbox is enabled
          if vb.views.auto_set_bpm_pitch_checkbox and vb.views.auto_set_bpm_pitch_checkbox.value then
            local beat_sync_lines = vb.views.beat_sync_valuebox.value
            local lpb = vb.views.lpb_valuebox.value
            local calculated_bpm = 60 / lpb / length_seconds * beat_sync_lines
            local transpose = renoise.song().selected_sample.transpose
            local finetune = renoise.song().selected_sample.fine_tune
            local cents = (transpose * 100) + (finetune / 128 * 100)
            local bpm_factor = math.pow(2, (cents / 1200))
            local calculated_bpm_pitch = calculated_bpm * bpm_factor
            if calculated_bpm_pitch >= 20 and calculated_bpm_pitch <= 999 then
              renoise.song().transport.bpm = calculated_bpm_pitch
            end
          end
        end
      },
      vb:button{
        text = "0",
        width = 30,
        notifier = function()
          vb.views.finetune_valuebox.value = 0
          renoise.song().selected_sample.fine_tune = 0
          -- Update vinyl pitch slider to match (vinyl-style calculation) - only if not updating from vinyl slider
          if not updating_from_vinyl_slider then
            local current_transpose = vb.views.transpose_valuebox.value
            local range_settings = get_current_range()
            -- Convert transpose + finetune back to continuous vinyl position
            local vinyl_pitch_value = (current_transpose * 128) + 0
            vinyl_pitch_value = vinyl_pitch_value / range_settings.scale
            vinyl_pitch_value = math.max(-range_settings.range, math.min(range_settings.range, vinyl_pitch_value))
            vb.views.vinyl_pitch_slider.value = vinyl_pitch_value
          end
          update_calculation()
          -- Auto-set BPM if checkbox is enabled
          if vb.views.auto_set_bpm_pitch_checkbox and vb.views.auto_set_bpm_pitch_checkbox.value then
            local beat_sync_lines = vb.views.beat_sync_valuebox.value
            local lpb = vb.views.lpb_valuebox.value
            local calculated_bpm = 60 / lpb / length_seconds * beat_sync_lines
            local transpose = renoise.song().selected_sample.transpose
            local finetune = renoise.song().selected_sample.fine_tune
            local cents = (transpose * 100) + (finetune / 128 * 100)
            local bpm_factor = math.pow(2, (cents / 1200))
            local calculated_bpm_pitch = calculated_bpm * bpm_factor
            if calculated_bpm_pitch >= 20 and calculated_bpm_pitch <= 999 then
              renoise.song().transport.bpm = calculated_bpm_pitch
            end
          end
        end
      }
    },
    
    -- Vinyl Pitch Slider (continuous transpose + finetune control)
    vb:row{
      vb:text{text = "Vinyl Pitch", width = textWidth, style = "strong", font = "bold"},
      vb:switch{
        id = "range_switch",
        items = {"±3", "±12", "±24", "±120", "Legacy"},
        value = current_range_index,
        width = 250,
        notifier = function(value)
          current_range_index = value
          update_slider_range()
          -- Save to preferences
          if preferences and preferences.pakettiPitchSliderRange then
            preferences.pakettiPitchSliderRange.value = value
            preferences:save_as("preferences.xml")
            print(string.format("-- BPM Dialog: Saved pitch slider range to preferences: %d (%s)", 
              value, pitch_ranges[value].name))
          end
        end
      }
    },
    vb:row{
      vb:slider{
        id = "vinyl_pitch_slider",
        min = -get_current_range().range,
        max = get_current_range().range,
        value = 0,
        width = 370,  -- Full dialog width
        steps = {1, -1},  -- Fine step increments for precision
        notifier = function(value)
          -- Skip notifier during initialization to prevent overwriting sample values
          if initializing_vinyl_slider then
            return
          end
          
          -- Set flag to prevent feedback loop when updating valueboxes
          updating_from_vinyl_slider = true
          
          -- Vinyl-style pitch control: continuous finetune with transpose rollover
          -- Each step moves finetune, when finetune hits ±127 it rolls to next semitone
          
          -- Get current range settings
          local range_settings = get_current_range()
          
          -- Convert vinyl slider value to continuous finetune position
          local total_finetune = value * range_settings.scale
          
          -- Calculate how many complete semitone cycles we've crossed
          local transpose = 0
          local finetune = total_finetune
          
          -- Handle positive direction (going up in pitch)
          while finetune > 127 do
            transpose = transpose + 1
            finetune = finetune - 128  -- Wrap from +127 to 0, then continue
          end
          
          -- Handle negative direction (going down in pitch)  
          while finetune < -127 do
            transpose = transpose - 1
            finetune = finetune + 128  -- Wrap from -127 to 0, then continue
          end
          
          -- Clamp transpose to valid range
          transpose = math.max(-120, math.min(120, transpose))
          
          -- If we hit transpose limits, adjust finetune accordingly
          if transpose == -120 and finetune < -127 then
            finetune = -127
          elseif transpose == 120 and finetune > 127 then
            finetune = 127
          end
          
          -- Round finetune to integer
          finetune = math.floor(finetune + 0.5)
          
          -- Update valueboxes and sample
          vb.views.transpose_valuebox.value = transpose
          vb.views.finetune_valuebox.value = finetune
          renoise.song().selected_sample.transpose = transpose
          renoise.song().selected_sample.fine_tune = finetune
          
          -- Clear flag to allow normal operation
          updating_from_vinyl_slider = false
          
          update_calculation()
          
          -- Auto-set BPM if checkbox is enabled
          if vb.views.auto_set_bpm_pitch_checkbox and vb.views.auto_set_bpm_pitch_checkbox.value then
            local beat_sync_lines = vb.views.beat_sync_valuebox.value
            local lpb = vb.views.lpb_valuebox.value
            local calculated_bpm = 60 / lpb / length_seconds * beat_sync_lines
            local cents = (transpose * 100) + (finetune / 128 * 100)
            local bpm_factor = math.pow(2, (cents / 1200))
            local calculated_bpm_pitch = calculated_bpm * bpm_factor
            if calculated_bpm_pitch >= 20 and calculated_bpm_pitch <= 999 then
              renoise.song().transport.bpm = calculated_bpm_pitch
            end
          end
        end
      },
      vb:button{
        text = "0",
        width = 30,
        notifier = function()
          -- Set flag to prevent feedback loop when updating controls
          updating_from_vinyl_slider = true
          vb.views.vinyl_pitch_slider.value = 0
          vb.views.transpose_valuebox.value = 0
          vb.views.finetune_valuebox.value = 0
          renoise.song().selected_sample.transpose = 0
          renoise.song().selected_sample.fine_tune = 0
          -- Clear flag to allow normal operation
          updating_from_vinyl_slider = false
          update_calculation()
          -- Auto-set BPM if checkbox is enabled
          if vb.views.auto_set_bpm_pitch_checkbox and vb.views.auto_set_bpm_pitch_checkbox.value then
            local beat_sync_lines = vb.views.beat_sync_valuebox.value
            local lpb = vb.views.lpb_valuebox.value
            local calculated_bpm = 60 / lpb / length_seconds * beat_sync_lines
            local transpose = renoise.song().selected_sample.transpose
            local finetune = renoise.song().selected_sample.fine_tune
            local cents = (transpose * 100) + (finetune / 128 * 100)
            local bpm_factor = math.pow(2, (cents / 1200))
            local calculated_bpm_pitch = calculated_bpm * bpm_factor
            if calculated_bpm_pitch >= 20 and calculated_bpm_pitch <= 999 then
              renoise.song().transport.bpm = calculated_bpm_pitch
            end
          end
        end
      }
    },
    vb:row{vb:text{text="Calculated BPM",width=textWidth,style="strong",font="bold"}},
    vb:row{
      vb:text{text = "BPM (Beatsync)", width = textWidth, style = "strong", font = "bold"},
      vb:text{id = "bpm_value", text = "", style = "strong", font = "bold"}
    },
    vb:row{
      vb:text{text="BPM (Pitch)",width=textWidth,style="strong",font="bold"},
      vb:text{id="bpm_pitch_value", text="",style="strong",font="bold"}
    },
    
    vb:text{id="warning_text",text="",style="strong",font="bold"},
    
    -- Title for Set section
    vb:text{text="Set (with Beatsync)",style="strong",font="bold"},
    
    -- First row: Main set buttons
    vb:row{
      vb:button{
        text = "BPM",
        width = 123,
        notifier = function()
          local calculated_bpm = update_calculation()
          if calculated_bpm >= 20 and calculated_bpm <= 999 then
            local beat_sync_lines = vb.views.beat_sync_valuebox.value
            local current_song = renoise.song()
            local current_sample = current_song.selected_sample
            current_song.transport.bpm = calculated_bpm
            current_sample.beat_sync_enabled = true
            current_sample.beat_sync_lines = beat_sync_lines
            renoise.app():show_status(string.format("BPM set to %.3f, Beat Sync enabled and set to %d lines", calculated_bpm, beat_sync_lines))
          else
            renoise.app():show_status("Cannot set BPM - value outside valid range")
          end
        end
      },
      vb:button{
        text = "BPM&Note",
        width = 123,
        notifier = function()
          local calculated_bpm = update_calculation()
          if calculated_bpm >= 20 and calculated_bpm <= 999 then
            local beat_sync_lines = vb.views.beat_sync_valuebox.value
            local current_song = renoise.song()
            local current_sample = current_song.selected_sample
            current_song.transport.bpm = calculated_bpm
            current_sample.beat_sync_enabled = true
            current_sample.beat_sync_lines = beat_sync_lines
            write_note_to_pattern()
            renoise.app():show_status(string.format("BPM set to %.3f, Beat Sync enabled and set to %d lines, Note written to track", calculated_bpm, beat_sync_lines))
          else
            renoise.app():show_status("Cannot set BPM - value outside valid range")
          end
        end
      },
      vb:button{
        text = "Note",
        width = 124,
        notifier = function()
          local beat_sync_lines = vb.views.beat_sync_valuebox.value
          local current_song = renoise.song()
          local current_sample = current_song.selected_sample
          current_sample.beat_sync_enabled = true
          current_sample.beat_sync_lines = beat_sync_lines
          write_note_to_pattern()
          renoise.app():show_status(string.format("Beat Sync enabled and set to %d lines, Note written to track (BPM unchanged)", beat_sync_lines))
        end
      }
    },
    
    -- Convert Beatsync to Pitch button
    vb:row{
      vb:button{
        text = "Convert Beatsync to Pitch",
        width = 370,
        notifier = function()
          -- Just call the standalone function which has all the debug output
          convert_beatsync_to_pitch()
          
          -- Update the dialog after conversion
          update_calculation()
        end
      }
    },
    
    -- Title for Set section
    vb:text{
      text = "Set (with Pitch/Finetune)",
      style = "strong",
      font = "bold"
    },

    -- Second row: Pitch/Finetune buttons
    vb:row{
      vb:button{
        text = "BPM",
        width = 123,
        notifier = function()
          local current_song = renoise.song()
          local current_sample = current_song.selected_sample
          local beat_sync_lines = vb.views.beat_sync_valuebox.value
          local current_lpb = current_song.transport.lpb
          
          -- Calculate BPM with pitch/finetune compensation
          local transpose = current_sample.transpose
          local finetune = current_sample.fine_tune
          local cents = (transpose * 100) + (finetune / 128 * 100)
          local bpm_factor = math.pow(2, (cents / 1200))
          local calculated_bpm = 60 / current_lpb / length_seconds * beat_sync_lines * bpm_factor
          
          print("\n=== PITCH-COMPENSATED BPM CALCULATION DEBUG (BPM Button) ===")
          print("Sample length: " .. string.format("%.6f", length_seconds) .. " seconds")
          print("Beat sync lines: " .. beat_sync_lines)
          print("LPB: " .. current_lpb)
          print("Transpose: " .. transpose)
          print("Finetune: " .. finetune)
          print("Cents calculation: (" .. transpose .. " * 100) + (" .. finetune .. " / 128 * 100) = " .. string.format("%.6f", cents))
          print("BPM factor: 2^(" .. string.format("%.6f", cents) .. "/1200) = " .. string.format("%.6f", bpm_factor))
          print("BPM calculation: 60 / " .. current_lpb .. " / " .. string.format("%.6f", length_seconds) .. " * " .. beat_sync_lines .. " * " .. string.format("%.6f", bpm_factor))
          print("Calculated BPM: " .. string.format("%.6f", calculated_bpm))
          print("=== END DEBUG ===\n")
          
          if calculated_bpm >= 20 and calculated_bpm <= 999 then
            -- Turn off beat sync
            current_sample.beat_sync_enabled = false
            
            -- Set BPM to calculated value (already includes pitch compensation)
            current_song.transport.bpm = calculated_bpm
            
            renoise.app():show_status(string.format("BPM set to %.3f (with pitch compensation), Beat Sync disabled", calculated_bpm))
          else
            renoise.app():show_status("Cannot calculate pitch - BPM value outside valid range")
          end
        end
      },
      vb:button{
        text = "BPM&Note",
        width = 123,
        notifier = function()
          local current_song = renoise.song()
          local current_sample = current_song.selected_sample
          local beat_sync_lines = vb.views.beat_sync_valuebox.value
          local current_lpb = current_song.transport.lpb
          
          -- Calculate BPM with pitch/finetune compensation
          local transpose = current_sample.transpose
          local finetune = current_sample.fine_tune
          local cents = (transpose * 100) + (finetune / 128 * 100)
                    local bpm_factor = math.pow(2, (cents / 1200))
          local calculated_bpm = 60 / current_lpb / length_seconds * beat_sync_lines * bpm_factor
          
          print("\n=== PITCH-COMPENSATED BPM CALCULATION DEBUG (BPM&Note Button) ===")
          print("Sample length: " .. string.format("%.6f", length_seconds) .. " seconds")
          print("Beat sync lines: " .. beat_sync_lines)
          print("LPB: " .. current_lpb)
          print("Transpose: " .. transpose)
          print("Finetune: " .. finetune)
          print("Cents calculation: (" .. transpose .. " * 100) + (" .. finetune .. " / 128 * 100) = " .. string.format("%.6f", cents))
          print("BPM factor: 2^(" .. string.format("%.6f", cents) .. "/1200) = " .. string.format("%.6f", bpm_factor))
          print("BPM calculation: 60 / " .. current_lpb .. " / " .. string.format("%.6f", length_seconds) .. " * " .. beat_sync_lines .. " * " .. string.format("%.6f", bpm_factor))
          print("Calculated BPM: " .. string.format("%.6f", calculated_bpm))
          print("=== END DEBUG ===\n")
          
          if calculated_bpm >= 20 and calculated_bpm <= 999 then
              
            -- Turn off beat sync
            current_sample.beat_sync_enabled = false
            
            -- Set BPM to calculated value
            current_song.transport.bpm = calculated_bpm
            
            -- Calculate how many times sample should play per pattern based on beat sync
            local pattern_length = current_song.selected_pattern.number_of_lines
            local beat_sync_lines = vb.views.beat_sync_valuebox.value
            local times_per_pattern = pattern_length / beat_sync_lines
            
            -- Calculate target sample duration to achieve this timing
            local pattern_duration_seconds = (pattern_length / current_song.transport.lpb) * (60 / calculated_bpm)
            local target_sample_duration = pattern_duration_seconds / times_per_pattern
            
            -- Calculate pitch factor needed to achieve target duration
            local pitch_factor = length_seconds / target_sample_duration
            local cents = 1200 * math.log(pitch_factor) / math.log(2)
            local transpose = math.floor(cents / 100)
            local finetune = math.floor((cents - transpose * 100) * 128 / 100)
            
            -- Verify using your formula
            local verify_cents = transpose * 100 + finetune / 128 * 100
            local verify_factor = math.pow(2, verify_cents / 1200)
            print(string.format("DEBUG: Calculated transpose=%d, finetune=%d", transpose, finetune))
            print(string.format("DEBUG: Verify: cents=%.6f, factor=%.6f", verify_cents, verify_factor))
            
            -- Clamp values to valid ranges
            transpose = math.max(-120, math.min(120, transpose))
            finetune = math.max(-127, math.min(127, finetune))
            
            -- Apply pitch values
            current_sample.transpose = transpose
            current_sample.fine_tune = finetune
            
            -- Write note to pattern
            write_note_to_pattern()
            
            renoise.app():show_status(string.format("BPM set to %.3f, Beat Sync disabled, Transpose set to %d, Fine Tune set to %d, Note written", calculated_bpm, transpose, finetune))
          else
            renoise.app():show_status("Cannot calculate pitch - BPM value outside valid range")
          end
        end
      },
      vb:button{
        text = "Note",
        width = 124,
        notifier = function()
          local calculated_bpm = update_calculation()
          if calculated_bpm >= 20 and calculated_bpm <= 999 then
            local current_song = renoise.song()
            local current_sample = current_song.selected_sample
            local original_bpm = current_song.transport.bpm
            
            -- Turn off beat sync
            current_sample.beat_sync_enabled = false
            
            -- Calculate how many times sample should play per pattern based on beat sync
            local pattern_length = current_song.selected_pattern.number_of_lines
            local beat_sync_lines = vb.views.beat_sync_valuebox.value
            local times_per_pattern = pattern_length / beat_sync_lines
            
            -- Calculate target sample duration to achieve this timing (using current BPM)
            local pattern_duration_seconds = (pattern_length / current_song.transport.lpb) * (60 / original_bpm)
            local target_sample_duration = pattern_duration_seconds / times_per_pattern
            
            -- Calculate pitch factor needed to achieve target duration
            local pitch_factor = length_seconds / target_sample_duration
            local cents = 1200 * math.log(pitch_factor) / math.log(2)
            local transpose = math.floor(cents / 100)
            local finetune = math.floor((cents - transpose * 100) * 128 / 100)
            
            -- Verify using your formula
            local verify_cents = transpose * 100 + finetune / 128 * 100
            local verify_factor = math.pow(2, verify_cents / 1200)
            print(string.format("DEBUG: Calculated transpose=%d, finetune=%d", transpose, finetune))
            print(string.format("DEBUG: Verify: cents=%.6f, factor=%.6f", verify_cents, verify_factor))
            
            -- Clamp values to valid ranges
            transpose = math.max(-120, math.min(120, transpose))
            finetune = math.max(-127, math.min(127, finetune))
            
            -- Apply pitch values
            current_sample.transpose = transpose
            current_sample.fine_tune = finetune
            
            -- Write note to pattern
            write_note_to_pattern()
            
            renoise.app():show_status(string.format("Beat Sync disabled, Transpose set to %d, Fine Tune set to %d, Note written (BPM unchanged)", transpose, finetune))
          else
            renoise.app():show_status("Cannot calculate pitch - BPM value outside valid range")
          end
        end
      }
    },
    
    -- Third row: Close button
    vb:row{
      vb:button{
        text = "Close",
        width = 370,
        notifier = function()
          -- Remove notifiers when dialog closes via button
          local current_song = renoise.song()
          if current_song.selected_instrument_observable:has_notifier(update_dialog_on_selection_change) then
            current_song.selected_instrument_observable:remove_notifier(update_dialog_on_selection_change)
          end
          if current_song.selected_sample_observable:has_notifier(update_dialog_on_selection_change) then
            current_song.selected_sample_observable:remove_notifier(update_dialog_on_selection_change)
          end
          if dialog then dialog:close() end
        end
      }
    }
  }
  
  -- Remove existing notifiers if any
  if song.selected_instrument_observable:has_notifier(update_dialog_on_selection_change) then
    song.selected_instrument_observable:remove_notifier(update_dialog_on_selection_change)
  end
  if song.selected_sample_observable:has_notifier(update_dialog_on_selection_change) then
    song.selected_sample_observable:remove_notifier(update_dialog_on_selection_change)
  end
  
  -- Add the observers for live updating
  song.selected_instrument_observable:add_notifier(update_dialog_on_selection_change)
  song.selected_sample_observable:add_notifier(update_dialog_on_selection_change)
  
  update_calculation()  -- Initial calculation
  
  -- Set initial transpose/finetune values from current sample
  if vb.views.transpose_valuebox then
    vb.views.transpose_valuebox.value = sample.transpose
  end
  if vb.views.finetune_valuebox then
    vb.views.finetune_valuebox.value = sample.fine_tune
  end
  
  -- Initialize vinyl pitch slider from current sample values
  if vb.views.vinyl_pitch_slider then
    -- Set flag to prevent notifier from firing during initialization
    initializing_vinyl_slider = true
    
    -- Convert current transpose + finetune to vinyl position using current range
    local range_settings = get_current_range()
    local vinyl_pitch_value = (sample.transpose * 128) + sample.fine_tune
    vinyl_pitch_value = vinyl_pitch_value / range_settings.scale
    -- Clamp to slider range
    vinyl_pitch_value = math.max(-range_settings.range, math.min(range_settings.range, vinyl_pitch_value))
    vb.views.vinyl_pitch_slider.value = vinyl_pitch_value
    print(string.format("-- BPM Dialog: Vinyl Pitch Slider initialized: transpose=%d, finetune=%d, vinyl_value=%d, range=%s", 
      sample.transpose, sample.fine_tune, vinyl_pitch_value, range_settings.name))
    
    -- Clear flag to allow normal operation
    initializing_vinyl_slider = false
  end
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) 
      dialog = value
      -- Remove notifiers when dialog closes
      if value == nil then
        if song.selected_instrument_observable:has_notifier(update_dialog_on_selection_change) then
          song.selected_instrument_observable:remove_notifier(update_dialog_on_selection_change)
        end
        if song.selected_sample_observable:has_notifier(update_dialog_on_selection_change) then
          song.selected_sample_observable:remove_notifier(update_dialog_on_selection_change)
        end
      end
    end
  )
  dialog = renoise.app():show_custom_dialog("BPM from Sample Length", dialog_content, keyhandler)

end



-- Function to convert beatsync to pitch/finetune
function convert_beatsync_to_pitch()
  local current_song = renoise.song()
  local current_sample = current_song.selected_sample
  
  if not current_sample or not current_sample.sample_buffer or not current_sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample selected")
    return
  end
  
  if not current_sample.beat_sync_enabled then
    renoise.app():show_status("Beatsync is not enabled - nothing to convert")
    return
  end
  
  local beat_sync_lines = current_sample.beat_sync_lines
  local bpm = current_song.transport.bpm
  local lpb = current_song.transport.lpb
  
  -- Calculate sample length
  local buffer = current_sample.sample_buffer
  local sample_seconds = buffer.number_of_frames / buffer.sample_rate
  
  print("\n=== CONVERT BEATSYNC TO PITCH DEBUG ===")
  print("Beat sync lines: " .. beat_sync_lines)
  print("BPM: " .. bpm)
  print("LPB: " .. lpb)
  print("Sample seconds: " .. string.format("%.6f", sample_seconds))
  print("Sample frames: " .. buffer.number_of_frames)
  print("Sample rate: " .. buffer.sample_rate)
  
  -- Store original values
  local original_transpose = current_sample.transpose
  local original_finetune = current_sample.fine_tune
  print("Original transpose: " .. original_transpose)
  print("Original finetune: " .. original_finetune)
  
  -- Calculate how long the beatsync duration is in seconds
  local beatsync_duration_seconds = beat_sync_lines * (60 / bpm / lpb)
  print("Beatsync duration: " .. beat_sync_lines .. " * (60 / " .. bpm .. " / " .. lpb .. ") = " .. string.format("%.6f", beatsync_duration_seconds))
  
  -- The factor should be: how much faster should the sample play 
  -- to compress its natural length into the beatsync duration
  -- If beatsync duration is shorter, sample needs to play faster (higher pitch)
  local factor = sample_seconds / beatsync_duration_seconds
  print("Factor: " .. string.format("%.6f", sample_seconds) .. " / " .. string.format("%.6f", beatsync_duration_seconds) .. " = " .. string.format("%.6f", factor))
  
  -- Convert to transpose and finetune
  local log_factor = math.log(factor) / math.log(2)
  print("Log2 factor: " .. string.format("%.6f", log_factor))
  
  local semitones = 12 * log_factor
  print("Semitones: 12 * " .. string.format("%.6f", log_factor) .. " = " .. string.format("%.6f", semitones))
  
  local transpose, finetune_fraction = math.modf(semitones)
  local finetune = math.floor(finetune_fraction * 128)
  
  print("Before clamping - Transpose: " .. transpose .. ", Finetune fraction: " .. string.format("%.6f", finetune_fraction) .. ", Finetune: " .. finetune)
  
  -- Clamp values to valid ranges
  transpose = math.max(-120, math.min(120, transpose))
  finetune = math.max(-127, math.min(127, finetune))
  
  print("After clamping - Transpose: " .. transpose .. ", Finetune: " .. finetune)
  
  -- Turn off beatsync and apply pitch values
  current_sample.beat_sync_enabled = false
  current_sample.transpose = transpose
  current_sample.fine_tune = finetune
  
  print("Applied - Beatsync enabled: " .. tostring(current_sample.beat_sync_enabled))
  print("Applied - New transpose: " .. current_sample.transpose)
  print("Applied - New finetune: " .. current_sample.fine_tune)
  print("=== END DEBUG ===\n")
  
  renoise.app():show_status(string.format("Beatsync %d converted to Transpose %d and Finetune %d", beat_sync_lines, transpose, finetune))
end

-- TODO: figure out which ones still need to exist
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Set BPM from Sample Length",invoke=set_bpm_from_sample_beatsync}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Show BPM Calculation Dialog...",invoke=pakettiBpmFromSampleDialog}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Set BPM from Sample Length",invoke=set_bpm_from_sample_beatsync}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set BPM from Sample Length",invoke=set_bpm_from_sample_beatsync}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show BPM Calculation Dialog...",invoke=pakettiBpmFromSampleDialog}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Set BPM from Sample Length",invoke=set_bpm_from_sample_beatsync}

renoise.tool():add_keybinding{name="Global:Paketti:Set BPM from Sample Length",invoke=set_bpm_from_sample_beatsync}
renoise.tool():add_keybinding{name="Global:Paketti:Show BPM Calculation Dialog...",invoke=pakettiBpmFromSampleDialog}

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Convert Beatsync to Sample Pitch",invoke=convert_beatsync_to_pitch}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Convert Beatsync to Sample Pitch",invoke=convert_beatsync_to_pitch}
renoise.tool():add_keybinding{name="Global:Paketti:Convert Beatsync to Sample Pitch",invoke=convert_beatsync_to_pitch}





--------------------------------------------------------------------------------
-- Sample Pitch Modifier Dialog
-- Minimal dialog with just transpose, finetune, and vinyl slider
--------------------------------------------------------------------------------

local dialog = nil

function show_sample_pitch_modifier_dialog()
  -- Close existing dialog if open
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  
  local song = renoise.song()
  local sample = song.selected_sample
  
  -- Check if we have a valid sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No valid sample selected")
    return
  end
  
  local vb = renoise.ViewBuilder()
  
  -- Flag to prevent vinyl slider notifier from firing during initialization
  local initializing_vinyl_slider = false
  -- Flag to prevent feedback loop when vinyl slider updates valueboxes
  local updating_from_vinyl_slider = false
  
  local textWidth = 80
  
  -- Load preference for minimized layout
  local use_small_layout = true  -- Default: true (current compact layout)
  if preferences and preferences.MinimizedPitchControlSmall and preferences.MinimizedPitchControlSmall.value ~= nil then
    use_small_layout = preferences.MinimizedPitchControlSmall.value
    print("-- Sample Pitch Modifier: Loaded layout preference: " .. tostring(use_small_layout))
  else
    print("-- Sample Pitch Modifier: Using default small layout")
  end
  
  -- Pitch range settings (transpose ranges)
  local pitch_ranges = {
    {name = "±3", range = 3 * 128, scale = 1.0},    -- ±3 semitones
    {name = "±12", range = 12 * 128, scale = 1.0},  -- ±12 semitones (1 octave)
    {name = "±24", range = 24 * 128, scale = 1.0},  -- ±24 semitones (2 octaves)
    {name = "±120", range = 120 * 128, scale = 1.0}, -- ±120 semitones (full range)
  }
  -- Load range from preferences, default to ±12 (index 2) if not set
  local current_range_index = 2  -- Default: ±12 (Normal)
  if preferences and preferences.pakettiPitchSliderRange and preferences.pakettiPitchSliderRange.value then
    current_range_index = preferences.pakettiPitchSliderRange.value
    -- Clamp to valid range (1-4)
    current_range_index = math.max(1, math.min(4, current_range_index))
    print(string.format("-- Sample Pitch Modifier: Loaded pitch slider range from preferences: %d (%s)", 
      current_range_index, pitch_ranges[current_range_index].name))
  else
    print("-- Sample Pitch Modifier: Using default pitch slider range: ±12")
  end
  
  -- Function to get current pitch range settings
  local function get_current_range()
    return pitch_ranges[current_range_index]
  end
  
  -- Function to update slider range and recalculate position
  local function update_slider_range()
    local range_settings = get_current_range()
    local slider = vb.views.vinyl_pitch_slider
    
    if slider then
      -- Get current transpose/finetune values
      local current_transpose = vb.views.transpose_valuebox.value
      local current_finetune = vb.views.finetune_valuebox.value
      
      -- Update slider range
      slider.min = -range_settings.range
      slider.max = range_settings.range
      
      -- Recalculate slider position with new scaling
      initializing_vinyl_slider = true
      local vinyl_pitch_value = (current_transpose * 128) + current_finetune
      vinyl_pitch_value = vinyl_pitch_value / range_settings.scale
      vinyl_pitch_value = math.max(-range_settings.range, math.min(range_settings.range, vinyl_pitch_value))
      slider.value = vinyl_pitch_value
      initializing_vinyl_slider = false
      
      print(string.format("-- Sample Pitch Modifier: Range changed to %s (±%d, scale=%.1f)", 
        range_settings.name, range_settings.range, range_settings.scale))
    end
  end

  local dialog_content = vb:column{}
  
  if use_small_layout then
    -- Small layout: Everything in one row (current behavior)
    dialog_content:add_child(vb:row{
      vb:text{text = "Transpose", style = "strong", font = "bold"},
      vb:valuebox{
        id = "transpose_valuebox",
        min = -120,
        max = 120,
        value = sample.transpose,
        width = 60,
        notifier = function(value)
          renoise.song().selected_sample.transpose = value
          -- Update vinyl pitch slider to match (vinyl-style calculation) - only if not updating from vinyl slider
          if not updating_from_vinyl_slider and not initializing_vinyl_slider then
            local current_finetune = vb.views.finetune_valuebox.value
            local range_settings = get_current_range()
            -- Convert transpose + finetune back to continuous vinyl position
            local vinyl_pitch_value = (value * 128) + current_finetune
            vinyl_pitch_value = vinyl_pitch_value / range_settings.scale
            vinyl_pitch_value = math.max(-range_settings.range, math.min(range_settings.range, vinyl_pitch_value))
            vb.views.vinyl_pitch_slider.value = vinyl_pitch_value
          end
        end
      },
      vb:text{text = "Finetune", style = "strong", font = "bold"},
      vb:valuebox{
        id = "finetune_valuebox",
        min = -127,
        max = 127,
        value = sample.fine_tune,
        width = 60,
        notifier = function(value)
          renoise.song().selected_sample.fine_tune = value
          -- Update vinyl pitch slider to match (vinyl-style calculation) - only if not updating from vinyl slider
          if not updating_from_vinyl_slider and not initializing_vinyl_slider then
            local current_transpose = vb.views.transpose_valuebox.value
            local range_settings = get_current_range()
            -- Convert transpose + finetune back to continuous vinyl position
            local vinyl_pitch_value = (current_transpose * 128) + value
            vinyl_pitch_value = vinyl_pitch_value / range_settings.scale
            vinyl_pitch_value = math.max(-range_settings.range, math.min(range_settings.range, vinyl_pitch_value))
            vb.views.vinyl_pitch_slider.value = vinyl_pitch_value
          end
        end
      },
      vb:switch{
        id = "range_switch",
        items = {"±3", "±12", "±24", "±120"},
        value = current_range_index,
        width = 150,
        notifier = function(value)
          current_range_index = value
          update_slider_range()
          -- Save to preferences
          if preferences and preferences.pakettiPitchSliderRange then
            preferences.pakettiPitchSliderRange.value = value
            preferences:save_as("preferences.xml")
            print(string.format("-- Sample Pitch Modifier: Saved pitch slider range to preferences: %d (%s)", 
              value, pitch_ranges[value].name))
          end
        end
      },
      vb:slider{
        id = "vinyl_pitch_slider",
        min = -get_current_range().range,
        max = get_current_range().range,
        value = 0,
        width = 400,  -- Slightly smaller to fit the range switch
        steps = {1, -1},
        notifier = function(value)
          -- Skip notifier during initialization to prevent overwriting sample values
          if initializing_vinyl_slider then
            return
          end
          
          -- Set flag to prevent feedback loop when updating valueboxes
          updating_from_vinyl_slider = true
          
          -- Vinyl-style pitch control: continuous finetune with transpose rollover
          -- Each step moves finetune, when finetune hits ±127 it rolls to next semitone
          
          -- Get current range settings
          local range_settings = get_current_range()
          
          -- Convert vinyl slider value to continuous finetune position
          local total_finetune = value * range_settings.scale
          
          -- Calculate how many complete semitone cycles we've crossed
          local transpose = 0
          local finetune = total_finetune
          
          -- Handle positive direction (going up in pitch)
          while finetune > 127 do
            transpose = transpose + 1
            finetune = finetune - 128  -- Wrap from +127 to 0, then continue
          end
          
          -- Handle negative direction (going down in pitch)  
          while finetune < -127 do
            transpose = transpose - 1
            finetune = finetune + 128  -- Wrap from -127 to 0, then continue
          end
          
          -- Clamp transpose to valid range
          transpose = math.max(-120, math.min(120, transpose))
          
          -- If we hit transpose limits, adjust finetune accordingly
          if transpose == -120 and finetune < -127 then
            finetune = -127
          elseif transpose == 120 and finetune > 127 then
            finetune = 127
          end
          
          -- Round finetune to integer
          finetune = math.floor(finetune + 0.5)
          
          -- Update valueboxes and sample
          vb.views.transpose_valuebox.value = transpose
          vb.views.finetune_valuebox.value = finetune
          renoise.song().selected_sample.transpose = transpose
          renoise.song().selected_sample.fine_tune = finetune
          
          -- Clear flag to allow normal operation
          updating_from_vinyl_slider = false
        end
      }
    })
  else
    -- Large layout: Controls on first row, slider on second row taking full width
    dialog_content:add_child(vb:row{
      vb:text{text = "Transpose", style = "strong", font = "bold"},
      vb:valuebox{
        id = "transpose_valuebox",
        min = -120,
        max = 120,
        value = sample.transpose,
        width = 60,
        notifier = function(value)
          renoise.song().selected_sample.transpose = value
          -- Update vinyl pitch slider to match (vinyl-style calculation) - only if not updating from vinyl slider
          if not updating_from_vinyl_slider and not initializing_vinyl_slider then
            local current_finetune = vb.views.finetune_valuebox.value
            local range_settings = get_current_range()
            -- Convert transpose + finetune back to continuous vinyl position
            local vinyl_pitch_value = (value * 128) + current_finetune
            vinyl_pitch_value = vinyl_pitch_value / range_settings.scale
            vinyl_pitch_value = math.max(-range_settings.range, math.min(range_settings.range, vinyl_pitch_value))
            vb.views.vinyl_pitch_slider.value = vinyl_pitch_value
          end
        end
      },
      vb:text{text = "Finetune", style = "strong", font = "bold"},
      vb:valuebox{
        id = "finetune_valuebox",
        min = -127,
        max = 127,
        value = sample.fine_tune,
        width = 60,
        notifier = function(value)
          renoise.song().selected_sample.fine_tune = value
          -- Update vinyl pitch slider to match (vinyl-style calculation) - only if not updating from vinyl slider
          if not updating_from_vinyl_slider and not initializing_vinyl_slider then
            local current_transpose = vb.views.transpose_valuebox.value
            local range_settings = get_current_range()
            -- Convert transpose + finetune back to continuous vinyl position
            local vinyl_pitch_value = (current_transpose * 128) + value
            vinyl_pitch_value = vinyl_pitch_value / range_settings.scale
            vinyl_pitch_value = math.max(-range_settings.range, math.min(range_settings.range, vinyl_pitch_value))
            vb.views.vinyl_pitch_slider.value = vinyl_pitch_value
          end
        end
      },
      vb:switch{
        id = "range_switch",
        items = {"±3", "±12", "±24", "±120"},
        value = current_range_index,
        width = 150,
        notifier = function(value)
          current_range_index = value
          update_slider_range()
          -- Save to preferences
          if preferences and preferences.pakettiPitchSliderRange then
            preferences.pakettiPitchSliderRange.value = value
            preferences:save_as("preferences.xml")
            print(string.format("-- Sample Pitch Modifier: Saved pitch slider range to preferences: %d (%s)", 
              value, pitch_ranges[value].name))
          end
        end
      }
    })
    
    -- Second row: Full-width slider
    dialog_content:add_child(vb:row{
      vb:slider{
        id = "vinyl_pitch_slider",
        min = -get_current_range().range,
        max = get_current_range().range,
        value = 0,
        width = 392,  -- Match combined width of controls above
        steps = {1, -1},
        notifier = function(value)
          -- Skip notifier during initialization to prevent overwriting sample values
          if initializing_vinyl_slider then
            return
          end
          
          -- Set flag to prevent feedback loop when updating valueboxes
          updating_from_vinyl_slider = true
          
          -- Vinyl-style pitch control: continuous finetune with transpose rollover
          -- Each step moves finetune, when finetune hits ±127 it rolls to next semitone
          
          -- Get current range settings
          local range_settings = get_current_range()
          
          -- Convert vinyl slider value to continuous finetune position
          local total_finetune = value * range_settings.scale
          
          -- Calculate how many complete semitone cycles we've crossed
          local transpose = 0
          local finetune = total_finetune
          
          -- Handle positive direction (going up in pitch)
          while finetune > 127 do
            transpose = transpose + 1
            finetune = finetune - 128  -- Wrap from +127 to 0, then continue
          end
          
          -- Handle negative direction (going down in pitch)  
          while finetune < -127 do
            transpose = transpose - 1
            finetune = finetune + 128  -- Wrap from -127 to 0, then continue
          end
          
          -- Clamp transpose to valid range
          transpose = math.max(-120, math.min(120, transpose))
          
          -- If we hit transpose limits, adjust finetune accordingly
          if transpose == -120 and finetune < -127 then
            finetune = -127
          elseif transpose == 120 and finetune > 127 then
            finetune = 127
          end
          
          -- Round finetune to integer
          finetune = math.floor(finetune + 0.5)
          
          -- Update valueboxes and sample
          vb.views.transpose_valuebox.value = transpose
          vb.views.finetune_valuebox.value = finetune
          renoise.song().selected_sample.transpose = transpose
          renoise.song().selected_sample.fine_tune = finetune
          
          -- Clear flag to allow normal operation
          updating_from_vinyl_slider = false
        end
      }
    })
  end
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Sample Pitch Modifier Dialog", dialog_content, keyhandler)
  
  -- Initialize vinyl pitch slider from current sample values AFTER dialog is shown
  if vb.views.vinyl_pitch_slider then
    -- Set flag to prevent notifier from firing during initialization
    initializing_vinyl_slider = true
    
    -- Convert current transpose + finetune to vinyl position using current range
    local range_settings = get_current_range()
    local vinyl_pitch_value = (sample.transpose * 128) + sample.fine_tune
    vinyl_pitch_value = vinyl_pitch_value / range_settings.scale
    -- Clamp to slider range
    vinyl_pitch_value = math.max(-range_settings.range, math.min(range_settings.range, vinyl_pitch_value))
    vb.views.vinyl_pitch_slider.value = vinyl_pitch_value
    print(string.format("-- Sample Pitch Modifier: Vinyl Pitch Slider initialized: transpose=%d, finetune=%d, vinyl_value=%d, range=%s", 
      sample.transpose, sample.fine_tune, vinyl_pitch_value, range_settings.name))
    
    -- Clear flag to allow normal operation
    initializing_vinyl_slider = false
  end
end

function toggle_sample_pitch_modifier_dialog_size()
  -- Initialize preferences if they don't exist
  if not preferences then
    preferences = renoise.Document.create("PakettiPreferences") {}
  end
  
  -- Initialize the specific preference if it doesn't exist
  if not preferences.MinimizedPitchControlSmall then
    preferences:add_property("MinimizedPitchControlSmall", renoise.Document.ObservableBoolean(true))
  end
  
  -- Toggle the preference
  local current_value = preferences.MinimizedPitchControlSmall.value
  local new_value = not current_value
  preferences.MinimizedPitchControlSmall.value = new_value
  
  -- Save preferences
  preferences:save_as("preferences.xml")
  
  -- Provide feedback
  local size_name = new_value and "Small (compact)" or "Large (slider on separate row)"
  local status_message = string.format("Sample Pitch Modifier Dialog size changed to: %s", size_name)
  renoise.app():show_status(status_message)
  print("-- " .. status_message)
end

renoise.tool():add_keybinding{name="Global:Paketti:Sample Pitch Modifier Dialog...",invoke = show_sample_pitch_modifier_dialog}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Sample Pitch Modifier Dialog...",invoke = show_sample_pitch_modifier_dialog}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti Gadgets:Sample Pitch Modifier Dialog...",invoke = show_sample_pitch_modifier_dialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Instruments:Sample Pitch Modifier Dialog...",invoke = show_sample_pitch_modifier_dialog}

renoise.tool():add_keybinding{name="Global:Paketti:Sample Pitch Modifier Dialog Size Toggle",invoke = toggle_sample_pitch_modifier_dialog_size}

-- Comprehensive BPM Calculation Debug Function
-- Combines all debug and calculation functionality into one comprehensive tool
function comprehensive_bpm_calculation_debug()
  local song = renoise.song()
  local sample = song.selected_sample
  
  print("\n" .. string.rep("=", 80))
  print("=== COMPREHENSIVE BPM CALCULATION DEBUG REPORT ===")
  print(string.rep("=", 80))
  
  -- Check if we have a valid sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    local error_msg = "No valid sample selected"
    print("ERROR: " .. error_msg)
    renoise.app():show_status(error_msg)
    return
  end
  
  local buffer = sample.sample_buffer
  local sample_rate = buffer.sample_rate
  local number_of_frames = buffer.number_of_frames
  local length_in_seconds = number_of_frames / sample_rate
  
  -- 1. BASIC SAMPLE INFORMATION
  print("\n1. BASIC SAMPLE INFORMATION:")
  print("   Sample name: " .. (sample.name or "Unnamed"))
  print("   Sample rate: " .. sample_rate .. " Hz")
  print("   Number of frames: " .. number_of_frames)
  print("   Number of channels: " .. buffer.number_of_channels)
  print("   Bit depth: " .. buffer.bit_depth .. " bit")
  print("   Raw calculation: " .. number_of_frames .. " / " .. sample_rate .. " = " .. length_in_seconds)
  print("   Length (6 decimals): " .. string.format("%.6f", length_in_seconds) .. " seconds")
  print("   Length (9 decimals): " .. string.format("%.9f", length_in_seconds) .. " seconds")
  
  -- Format time in various ways
  local total_seconds = math.floor(length_in_seconds)
  local milliseconds = math.floor((length_in_seconds - total_seconds) * 1000)
  local minutes = math.floor(total_seconds / 60)
  local seconds_remainder = total_seconds % 60
  
  print("   Formatted times:")
  print("     • " .. string.format("%.6f seconds", length_in_seconds))
  print("     • " .. string.format("%.3f seconds", length_in_seconds))
  print("     • " .. string.format("%d:%02d.%03d (mm:ss.ms)", minutes, seconds_remainder, milliseconds))
  print("     • " .. string.format("%.0f ms", length_in_seconds * 1000))
  
  -- 2. SAMPLE SELECTION INFORMATION
  print("\n2. SAMPLE SELECTION INFORMATION:")
  local selection_start = buffer.selection_start
  local selection_end = buffer.selection_end
  
  if selection_start == 0 and selection_end == 0 then
    print("   No selection - using entire sample")
    selection_start = 1
    selection_end = buffer.number_of_frames
  else
    print("   Selection start: " .. selection_start)
    print("   Selection end: " .. selection_end)
  end
  
  local selection_frames = selection_end - selection_start + 1
  local selection_length = selection_frames / sample_rate
  print("   Selection frames: " .. selection_frames)
  print("   Selection length: " .. string.format("%.6f", selection_length) .. " seconds")
  
  -- 3. CURRENT SAMPLE SETTINGS
  print("\n3. CURRENT SAMPLE SETTINGS:")
  print("   Transpose: " .. sample.transpose .. " semitones")
  print("   Finetune: " .. sample.fine_tune .. " cents")
  print("   Beat sync enabled: " .. tostring(sample.beat_sync_enabled))
  print("   Beat sync lines: " .. sample.beat_sync_lines)
  
  local cents = (sample.transpose * 100) + (sample.fine_tune / 128 * 100)
  local pitch_factor = math.pow(2, (cents / 1200))
  print("   Total cents: " .. string.format("%.2f", cents))
  print("   Pitch factor: " .. string.format("%.6f", pitch_factor))
  
  -- 4. SONG TRANSPORT SETTINGS
  print("\n4. SONG TRANSPORT SETTINGS:")
  local current_bpm = song.transport.bpm
  local current_lpb = song.transport.lpb
  print("   Current BPM: " .. current_bpm)
  print("   Current LPB: " .. current_lpb)
  
  -- 5. BPM CALCULATION FROM SAMPLE
  print("\n5. BPM CALCULATION FROM SAMPLE:")
  local beat_sync_lines = sample.beat_sync_lines
  print("   Formula: 60 / LPB / sample_length * beat_sync_lines * pitch_factor")
  print("   Formula: 60 / " .. current_lpb .. " / " .. string.format("%.9f", length_in_seconds) .. " * " .. beat_sync_lines .. " * " .. string.format("%.6f", pitch_factor))
  
  local step1 = 60 / current_lpb
  local step2 = step1 / length_in_seconds
  local step3 = step2 * beat_sync_lines
  local calculated_bpm = step3 * pitch_factor
  
  print("   Step 1: 60 / " .. current_lpb .. " = " .. string.format("%.9f", step1))
  print("   Step 2: " .. string.format("%.9f", step1) .. " / " .. string.format("%.9f", length_in_seconds) .. " = " .. string.format("%.9f", step2))
  print("   Step 3: " .. string.format("%.9f", step2) .. " * " .. beat_sync_lines .. " = " .. string.format("%.9f", step3))
  print("   Step 4: " .. string.format("%.9f", step3) .. " * " .. string.format("%.6f", pitch_factor) .. " = " .. string.format("%.9f", calculated_bpm))
  print("   CALCULATED BPM: " .. string.format("%.3f", calculated_bpm))
  
  -- Check if BPM is in valid range
  if calculated_bpm < 20 or calculated_bpm > 999 then
    print("   WARNING: Calculated BPM is outside valid range (20-999)")
  else
    print("   ✓ Calculated BPM is within valid range")
  end
  
  -- 6. BEATSYNC TO PITCH CONVERSION ANALYSIS
  if sample.beat_sync_enabled then
    print("\n6. BEATSYNC TO PITCH CONVERSION ANALYSIS:")
    print("   Current beatsync settings would convert to:")
    
    -- Calculate how long the beatsync duration is in seconds
    local beatsync_duration_seconds = beat_sync_lines * (60 / current_bpm / current_lpb)
    print("   Beatsync duration: " .. beat_sync_lines .. " * (60 / " .. current_bpm .. " / " .. current_lpb .. ") = " .. string.format("%.6f", beatsync_duration_seconds) .. " seconds")
    
    -- The factor should be: how much faster should the sample play 
    local factor = length_in_seconds / beatsync_duration_seconds
    print("   Pitch factor needed: " .. string.format("%.6f", length_in_seconds) .. " / " .. string.format("%.6f", beatsync_duration_seconds) .. " = " .. string.format("%.6f", factor))
    
    -- Convert to transpose and finetune
    local log_factor = math.log(factor) / math.log(2)
    local semitones = 12 * log_factor
    local transpose, finetune_fraction = math.modf(semitones)
    local finetune = math.floor(finetune_fraction * 128)
    
    print("   Log2 factor: " .. string.format("%.6f", log_factor))
    print("   Semitones: 12 * " .. string.format("%.6f", log_factor) .. " = " .. string.format("%.6f", semitones))
    print("   Would convert to:")
    print("     • Transpose: " .. transpose .. " semitones")
    print("     • Finetune: " .. finetune .. " cents")
    
    -- Clamp check
    local clamped_transpose = math.max(-120, math.min(120, transpose))
    local clamped_finetune = math.max(-127, math.min(127, finetune))
    if clamped_transpose ~= transpose or clamped_finetune ~= finetune then
      print("     • After clamping: Transpose " .. clamped_transpose .. ", Finetune " .. clamped_finetune)
      print("     • WARNING: Values were clamped to valid ranges")
    else
      print("     • ✓ Values are within valid ranges")
    end
  else
    print("\n6. BEATSYNC TO PITCH CONVERSION:")
    print("   Beatsync is disabled - no conversion analysis available")
  end
  
  -- 7. PRECISION ANALYSIS
  print("\n7. PRECISION ANALYSIS:")
  -- Test with common BPM values to show precision differences
  local test_bpms = {120, 140, 146.341, 174}
  for _, test_bpm in ipairs(test_bpms) do
    local test_result = 60 / current_lpb / length_in_seconds * beat_sync_lines
    local difference = math.abs(test_result - test_bpm)
    print("   If target BPM was " .. test_bpm .. ": difference = " .. string.format("%.6f", difference))
  end
  
  -- 8. SUMMARY AND RECOMMENDATIONS
  print("\n8. SUMMARY AND RECOMMENDATIONS:")
  print("   Sample length: " .. string.format("%.6f", length_in_seconds) .. " seconds")
  print("   Calculated BPM: " .. string.format("%.3f", calculated_bpm))
  print("   Current song BPM: " .. current_bpm)
  print("   BPM difference: " .. string.format("%.3f", math.abs(calculated_bpm - current_bpm)))
  
  if math.abs(calculated_bpm - current_bpm) < 0.1 then
    print("   ✓ Sample BPM matches song BPM very closely")
  elseif math.abs(calculated_bpm - current_bpm) < 1.0 then
    print("   ⚠ Sample BPM is close to song BPM (within 1 BPM)")
  else
    print("   ⚠ Sample BPM differs significantly from song BPM")
  end
  
  if sample.beat_sync_enabled then
    print("   • Beatsync is enabled - sample will play at song tempo")
    print("   • Use 'Convert Beatsync to Sample Pitch' to disable beatsync and set pitch")
  else
    print("   • Beatsync is disabled - sample plays at its natural pitch")
    print("   • Use 'Set BPM from Sample Length' to set song BPM to match sample")
  end
  
  print("\n" .. string.rep("=", 80))
  print("=== END OF BPM CALCULATION DEBUG REPORT ===")
  print(string.rep("=", 80) .. "\n")
  
  -- Show summary in status bar
  local status_msg = string.format("Sample: %.3fs, Calculated BPM: %.3f, Current BPM: %.1f (diff: %.1f)", 
    length_in_seconds, calculated_bpm, current_bpm, math.abs(calculated_bpm - current_bpm))
  renoise.app():show_status(status_msg)
  
  return {
    sample_length = length_in_seconds,
    calculated_bpm = calculated_bpm,
    current_bpm = current_bpm,
    bpm_difference = math.abs(calculated_bpm - current_bpm),
    selection_length = selection_length,
    pitch_factor = pitch_factor,
    beatsync_enabled = sample.beat_sync_enabled
  }
end


-- Comprehensive BPM Calculation Debug - combines all the functionality from commented functions above
renoise.tool():add_keybinding{name="Sample Editor:Paketti:BPM Calculation Debug (Comprehensive)",invoke=comprehensive_bpm_calculation_debug}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:BPM Calculation Debug (Comprehensive)",invoke=comprehensive_bpm_calculation_debug}
renoise.tool():add_keybinding{name="Global:Paketti:BPM Calculation Debug (Comprehensive)",invoke=comprehensive_bpm_calculation_debug}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:BPM Calculation Debug (Comprehensive)",invoke=comprehensive_bpm_calculation_debug}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:BPM Calculation Debug (Comprehensive)",invoke=comprehensive_bpm_calculation_debug}


