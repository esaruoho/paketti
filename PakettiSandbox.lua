local dialog = nil
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

-- Function to get selected sample length and display it in various formats
function show_selected_sample_length()
  local length_seconds, error_msg = calculate_selected_sample_length()
  
  if error_msg then
    renoise.app():show_status(error_msg)
    return
  end
  
  if length_seconds then
    -- Format the time in various ways
    local total_seconds = math.floor(length_seconds)
    local milliseconds = math.floor((length_seconds - total_seconds) * 1000)
    local minutes = math.floor(total_seconds / 60)
    local seconds_remainder = total_seconds % 60
    
    local time_formats = {
      string.format("%.6f seconds", length_seconds),
      string.format("%.3f seconds", length_seconds),
      string.format("%d:%02d.%03d (mm:ss.ms)", minutes, seconds_remainder, milliseconds),
      string.format("%.0f ms", length_seconds * 1000)
    }
    
    local status_text = "Sample length: " .. time_formats[2]
    renoise.app():show_status(status_text)
    
    print("Selected sample length:")
    for i, format_text in ipairs(time_formats) do
      print("  " .. format_text)
    end
    
    return length_seconds
  end
end

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

-- Function to calculate BPM from sample length, beat sync, and transpose
function calculate_bpm_from_sample_beatsync()
  local song = renoise.song()
  
  -- Get selected sample length
  local length_seconds, error_msg = calculate_selected_sample_length()
  if error_msg then
    renoise.app():show_status(error_msg)
    return nil, error_msg
  end
  
  local sample = song.selected_sample
  local current_lpb = song.transport.lpb
  local transpose = sample.transpose
  local finetune = sample.fine_tune
  local cents = (transpose * 100) + (finetune / 128 * 100)
  local bpm_factor = math.pow(2, (cents / 1200))
  
  -- Get beat_sync_lines from the sample
  local beat_sync_lines = sample.beat_sync_lines
  
  -- Formula: 60 / lpb / seconds * beat_sync_lines
  local calculated_bpm = 60 / current_lpb / length_seconds * beat_sync_lines * bpm_factor
  
  print("BPM Calculation from Sample:")
  print("  Sample length: " .. string.format("%.6f", length_seconds) .. " seconds")
  print("  Current LPB: " .. current_lpb)
  print("  Beat sync lines: " .. beat_sync_lines)
  print("  Formula: 60 / " .. current_lpb .. " / " .. string.format("%.6f", length_seconds) .. " * " .. beat_sync_lines)
  print("  Calculated BPM: " .. string.format("%.3f", calculated_bpm))
  
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
--    margin = 10,
    
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
            -- Convert transpose + finetune back to continuous vinyl position
            local vinyl_pitch_value = (value * 128) + current_finetune
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
            -- Convert transpose + finetune back to continuous vinyl position
            local vinyl_pitch_value = (current_transpose * 128) + value
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
            -- Convert transpose + finetune back to continuous vinyl position
            local vinyl_pitch_value = (current_transpose * 128) + 0
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
    
    -- Vinyl Pitch Slider (continuous transpose + finetune control)
    vb:row{
      vb:text{text = "Vinyl Pitch", width = textWidth, style = "strong", font = "bold"}
    },
    vb:row{
      vb:slider{
        id = "vinyl_pitch_slider",
        min = -2000,  -- Increased range for more fidelity
        max = 2000,   -- Increased range for more fidelity
        value = 0,
        width = 340,  -- Full dialog width minus some margin
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
          
          -- Convert vinyl slider value to continuous finetune position
          local total_finetune = value * 1.5  -- Scale for finer control with larger range
          
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
    
    -- Convert current transpose + finetune to vinyl position
    local vinyl_pitch_value = (sample.transpose * 128) + sample.fine_tune
    vinyl_pitch_value = vinyl_pitch_value / 1.5  -- Scale back down to match new scaling
    -- Clamp to slider range
    vinyl_pitch_value = math.max(-2000, math.min(2000, vinyl_pitch_value))
    vb.views.vinyl_pitch_slider.value = vinyl_pitch_value
    print(string.format("-- Vinyl Pitch Slider initialized: transpose=%d, finetune=%d, vinyl_value=%d", 
      sample.transpose, sample.fine_tune, vinyl_pitch_value))
    
    -- Clear flag to allow normal operation
    initializing_vinyl_slider = false
  end
  
  dialog = renoise.app():show_custom_dialog("BPM from Sample Length", dialog_content, function(dialog, key)
    -- Handle dialog close
    if key and key.name == "esc" then
      -- Remove notifiers when dialog closes
      if song.selected_instrument_observable:has_notifier(update_dialog_on_selection_change) then
        song.selected_instrument_observable:remove_notifier(update_dialog_on_selection_change)
      end
      if song.selected_sample_observable:has_notifier(update_dialog_on_selection_change) then
        song.selected_sample_observable:remove_notifier(update_dialog_on_selection_change)
      end
      dialog:close()
      return nil
    end
    return my_keyhandler_func(dialog, key)
  end)

end

-- Function to debug sample length precision
function debug_sample_length_precision()
  local song = renoise.song()
  local sample = song.selected_sample
  
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    print("No valid sample selected")
    return
  end
  
  local buffer = sample.sample_buffer
  local sample_rate = buffer.sample_rate
  local number_of_frames = buffer.number_of_frames
  local length_in_seconds = number_of_frames / sample_rate
  
  print("\n=== SAMPLE LENGTH PRECISION DEBUG ===")
  print("Sample rate: " .. sample_rate .. " Hz")
  print("Number of frames: " .. number_of_frames)
  print("Raw calculation: " .. number_of_frames .. " / " .. sample_rate .. " = " .. length_in_seconds)
  print("Length (6 decimals): " .. string.format("%.6f", length_in_seconds))
  print("Length (9 decimals): " .. string.format("%.9f", length_in_seconds))
  
  -- Test the exact math with your example
  local lpb = song.transport.lpb
  local beat_sync = sample.beat_sync_lines
  
  print("\n=== BPM CALCULATION TEST ===")
  print("Current LPB: " .. lpb)
  print("Current Beat Sync Lines: " .. beat_sync)
  print("Formula: 60 / " .. lpb .. " / " .. string.format("%.9f", length_in_seconds) .. " * " .. beat_sync)
  
  local step1 = 60 / lpb
  local step2 = step1 / length_in_seconds
  local result = step2 * beat_sync
  
  print("Step 1: 60 / " .. lpb .. " = " .. string.format("%.9f", step1))
  print("Step 2: " .. string.format("%.9f", step1) .. " / " .. string.format("%.9f", length_in_seconds) .. " = " .. string.format("%.9f", step2))
  print("Step 3: " .. string.format("%.9f", step2) .. " * " .. beat_sync .. " = " .. string.format("%.9f", result))
  print("Final BPM: " .. string.format("%.3f", result))
  
  -- Test with your exact example values
  if beat_sync == 32 and lpb == 4 then
    print("\n=== YOUR EXAMPLE TEST (should be 146.341) ===")
    local expected_length = 3.28
    local expected_bpm = 60 / 4 / expected_length * 32
    print("Expected with 3.28s: " .. string.format("%.3f", expected_bpm))
    print("Actual with " .. string.format("%.6f", length_in_seconds) .. "s: " .. string.format("%.3f", result))
    print("Difference: " .. string.format("%.6f", expected_bpm - result))
  end
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
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Calculate Selected Sample Length",invoke=calculate_selected_sample_length}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Show Selected Sample Length",invoke=show_selected_sample_length}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Calculate Sample Selection Length",invoke=calculate_sample_selection_length}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Calculate BPM from Sample Length",invoke=calculate_bpm_from_sample_beatsync}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Set BPM from Sample Length",invoke=set_bpm_from_sample_beatsync}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Show BPM Calculation Dialog...",invoke=pakettiBpmFromSampleDialog}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Calculate BPM from Sample Length",invoke=calculate_bpm_from_sample_beatsync}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Set BPM from Sample Length",invoke=set_bpm_from_sample_beatsync}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Calculate Selected Sample Length",invoke=calculate_selected_sample_length}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show Selected Sample Length",invoke=show_selected_sample_length}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Calculate Sample Selection Length",invoke=calculate_sample_selection_length}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Calculate BPM from Sample Length",invoke=calculate_bpm_from_sample_beatsync}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Set BPM from Sample Length",invoke=set_bpm_from_sample_beatsync}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show BPM Calculation Dialog...",invoke=pakettiBpmFromSampleDialog}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Calculate BPM from Sample Length",invoke=calculate_bpm_from_sample_beatsync}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Set BPM from Sample Length",invoke=set_bpm_from_sample_beatsync}

renoise.tool():add_keybinding{name="Global:Paketti:Calculate Selected Sample Length",invoke=calculate_selected_sample_length}
renoise.tool():add_keybinding{name="Global:Paketti:Show Selected Sample Length",invoke=show_selected_sample_length}
renoise.tool():add_keybinding{name="Global:Paketti:Calculate Sample Selection Length",invoke=calculate_sample_selection_length}
renoise.tool():add_keybinding{name="Global:Paketti:Calculate BPM from Sample Length",invoke=calculate_bpm_from_sample_beatsync}
renoise.tool():add_keybinding{name="Global:Paketti:Set BPM from Sample Length",invoke=set_bpm_from_sample_beatsync}
renoise.tool():add_keybinding{name="Global:Paketti:Show BPM Calculation Dialog...",invoke=pakettiBpmFromSampleDialog}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Convert Beatsync to Sample Pitch",invoke=convert_beatsync_to_pitch}
--renoise.tool():add_keybinding{name="Sample Editor:Paketti:Debug Sample Length Precision",invoke=debug_sample_length_precision}

----------
-- Function to toggle showing only one specific column type
function showOnlyColumnType(column_type)
    local song=renoise.song()
    
    -- Validate column_type parameter
    if not column_type or type(column_type) ~= "string" then
        print("Invalid column type specified")
        return
    end
    
    -- Map of valid column types to their corresponding track properties
    local column_properties = {
        ["volume"] = "volume_column_visible",
        ["panning"] = "panning_column_visible",
        ["delay"] = "delay_column_visible",
        ["effects"] = "sample_effects_column_visible"
    }
    
    -- Check if the specified column type is valid
    if not column_properties[column_type] then
        print("Invalid column type: " .. column_type)
        return
    end
    
    -- Check if we're already showing only this column type
    local is_showing_only_this = true
    for track_index = 1, song.sequencer_track_count do
        local track = song.tracks[track_index]
        -- Check if current column is visible and others are hidden
        if not track[column_properties[column_type]] or
           (column_type ~= "volume" and track.volume_column_visible) or
           (column_type ~= "panning" and track.panning_column_visible) or
           (column_type ~= "delay" and track.delay_column_visible) or
           (column_type ~= "effects" and track.sample_effects_column_visible) then
            is_showing_only_this = false
            break
        end
    end
    
    -- Iterate through all tracks (except Master and Send tracks)
    for track_index = 1, song.sequencer_track_count do
        local track = song.tracks[track_index]
        
        -- Hide all columns first
        track.volume_column_visible = false
        track.panning_column_visible = false
        track.delay_column_visible = false
        track.sample_effects_column_visible = false
        
        -- If we weren't already showing only this column, show it
        if not is_showing_only_this then
            track[column_properties[column_type]] = true
        end
    end
    
    -- Show status message
    local message = is_showing_only_this and 
        "Hiding all columns" or 
        "Showing only " .. column_type .. " columns across all tracks"
    renoise.app():show_status(message)
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Show Only Volume Columns",invoke=function() showOnlyColumnType("volume") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Show Only Panning Columns",invoke=function() showOnlyColumnType("panning") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Show Only Delay Columns",invoke=function() showOnlyColumnType("delay") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Show Only Effect Columns",invoke=function() showOnlyColumnType("effects") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show Only Volume Columns",invoke=function() showOnlyColumnType("volume") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show Only Panning Columns",invoke=function() showOnlyColumnType("panning") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show Only Delay Columns",invoke=function() showOnlyColumnType("delay") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show Only Effect Columns",invoke=function() showOnlyColumnType("effects") end}


--
function detect_zero_crossings()
    local song=renoise.song()
    local sample = song.selected_sample
  
    if not sample or not sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample has no data")
        return
    end
  
    local buffer = sample.sample_buffer
    local zero_crossings = {}
    local max_silence = 0.002472  -- Your maximum silence threshold
  
    print("\n=== Sample Buffer Analysis ===")
    print("Sample length:", buffer.number_of_frames, "frames")
    print("Number of channels:", buffer.number_of_channels)
    print("Scanning for zero crossings (threshold:", max_silence, ")")
  
    -- Scan through sample data in chunks for better performance
    local chunk_size = 1000
    local last_was_silence = nil
  
    for frame = 1, buffer.number_of_frames do
        local value = buffer:sample_data(1, frame)
        local is_silence = (value >= 0 and value <= max_silence)
        
        -- Detect transition points between silence and non-silence
        if last_was_silence ~= nil and last_was_silence ~= is_silence then
            table.insert(zero_crossings, frame)
        end
        
        last_was_silence = is_silence
        
        -- Show progress every chunk_size frames
        if frame % chunk_size == 0 or frame == buffer.number_of_frames then
            renoise.app():show_status(string.format("Analyzing frames %d to %d of %d", 
                math.max(1, frame-chunk_size+1), frame, buffer.number_of_frames))
        end
    end
  
    -- Show results
    local status_message = string.format("\nFound %d zero crossings", #zero_crossings)
    renoise.app():show_status(status_message)
    print(status_message)
  
    -- Animate through the zero crossings
    if #zero_crossings >= 2 then
        -- Create a coroutine to handle the animation
        local co = coroutine.create(function()
            for i = 1, #zero_crossings - 1, 2 do  -- Step by 2 to get pairs of transitions
                if i + 1 <= #zero_crossings then
                    buffer.selection_range = {
                        zero_crossings[i],
                        zero_crossings[i + 1]
                    }
                    renoise.app():show_status(string.format("Selecting zero crossings %d to %d (frames %d to %d)", 
                        i, i+1, zero_crossings[i], zero_crossings[i + 1]))
                    coroutine.yield()
                end
            end
        end)
        
        -- Add timer to step through coroutine
        renoise.tool():add_timer(function()
            if coroutine.status(co) ~= "dead" then
                local success, err = coroutine.resume(co)
                if not success then
                    print("Error:", err)
                    return false
                end
                return true
            end
            return false
        end, 0.5)
    else
        print("Not enough zero crossings found to set loop points")
    end
end

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Detect Zero Crossings",invoke=detect_zero_crossings}

-- from Paper
-- Rough formula i hacked up: 
-- ( 1 / (floor((5 * rate) / (3 * tempo)) / rate * speed) ) * 10

-- and another Paper example:
-- ( 1 / (floor((5 * rate) / (3 * tempo)) / rate * speed) ) * (rows_per_beat * 2.5)
-- i think this is correct


-- Paper simplified
--- (rows_per_beat * 2.5 * rate) / (floor((5 * rate) / (3 * tempo)) * speed)

-- from 8bitbubsy
-- Take BPM 129 at 44100Hz as an example:
-- samplesPerTick = 44100 / 129 = 341.860465116 --> truncated to 341.
-- BPM = 44100.0 / samplesPerTick (341) = BPM 129.325 

-- another example from 8bitbubsy
-- realBPM = (rate / floor(rate / bpm * 2.5)) / (speed / 15) 
-- result is (15 = 6*2.5)



-- TODO: Does this work if you have a 192 pattern length?
-- TODO: What if you wanna double it or halve it based on how many beats are there
-- in the pattern?
-- TODO: Consider those examples above.
-- Dialog Reference
local dialog = nil

-- Default Values
local speed = 6
local tempo = 125
local real_bpm = tempo / (speed / 6)


-- Function to Calculate BPM
local function calculate_bpm(speed, tempo)
  -- Simple formula: if speed is 6, BPM equals tempo
  -- If speed is higher than 6, BPM is lower, if speed is lower than 6, BPM is higher
  local bpm = tempo / (speed / 6)
  -- Check if BPM is within valid range (20 to 999)
  if bpm < 20 or bpm > 999 then
    return nil, {
      string.format("Invalid BPM value '%.2f'", bpm),
      "Valid values are (20 to 999)"
    }
  end
  return bpm
end

-- GUI Dialog Function
function pakettiSpeedTempoDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  -- Valueboxes for Speed and Tempo
  local vb = renoise.ViewBuilder()
  local dialog_content = vb:column{margin=10,--spacing=8,
    vb:row{
      vb:column{
        vb:text{text="Speed:"},
        vb:valuebox{min=1,max=255,value=speed,
          tostring=function(val) return string.format("%X", val) end,
          tonumber=function(val) return tonumber(val, 16) end,
          notifier=function(val)
            speed = val
            local calculated_bpm, error_msgs = calculate_bpm(speed, tempo)
            real_bpm = calculated_bpm
            vb.views.result_label.text = string.format("Speed %d Tempo %d is %.2f BPM", speed, tempo, real_bpm or 0)
            if error_msgs then
              vb.views.error_label1.text = error_msgs[1]
              vb.views.error_label2.text = error_msgs[2]
            else
              vb.views.error_label1.text = ""
              vb.views.error_label2.text = ""
            end
          end
        }
      },
      vb:column{
        vb:text{text="Tempo:"},
        vb:valuebox{min=32,max=255,value=tempo,
          notifier=function(val)
            tempo = val
            local calculated_bpm, error_msgs = calculate_bpm(speed, tempo)
            real_bpm = calculated_bpm
            vb.views.result_label.text = string.format("Speed %d Tempo %d is %.2f BPM", speed, tempo, real_bpm or 0)
            if error_msgs then
              vb.views.error_label1.text = error_msgs[1]
              vb.views.error_label2.text = error_msgs[2]
            else
              vb.views.error_label1.text = ""
              vb.views.error_label2.text = ""
            end
          end
        }
      }
    },

    -- Result Display
    vb:row{
      vb:text{id="result_label",text=string.format("Speed %d Tempo %d is %.2f BPM", speed, tempo, real_bpm)}
    },

    -- Error Display (split into two rows)
    vb:row{vb:text{id="error_label1",text="",style="strong",font="bold"}},
    vb:row{vb:text{id="error_label2",text="",style="strong",font="bold"}},
    
    -- Set BPM Button
    vb:row{
      vb:button{text="Set BPM",width=60,
        notifier=function()
          if not real_bpm then
            renoise.app():show_status("Cannot set BPM - value out of valid range (20 to 999)")
            return
          end
          renoise.song().transport.bpm = real_bpm
          renoise.app():show_status(string.format("BPM set to %.2f", real_bpm))
        end
      },
      vb:button{text="Close",width=60,
        notifier=function()
          if dialog and dialog.visible then
            dialog:close()
            dialog = nil
          end
        end
      }
    }
  }

  dialog = renoise.app():show_custom_dialog("Speed and Tempo to BPM",dialog_content,my_keyhandler_func)
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Speed and Tempo to BPM Dialog...",invoke=pakettiSpeedTempoDialog}

-- Function to check if values exceed Renoise limits and adjust if needed
function adjustValuesForRenoiseLimits(F, K)
  local max_lpb = 256  -- Renoise's maximum LPB
  local max_pattern_length = 512  -- Renoise's maximum pattern length
  local original_F, original_K = F, K
  local divided = false
  
  -- Keep dividing by 2 until within limits
  while (F * K > max_lpb) or (F * K * 4 > max_pattern_length) do
    F = F / 2
    K = K / 2
    divided = true
  end
  
  if divided then
    local choice = renoise.app():show_prompt(
      "Time Signature Warning",
      string.format("Time signature %d/%d exceeds Renoise limits. Would you like to:\n" ..
                   "- Use reduced values (%d/%d)\n" ..
                   "- Enter a new time signature",
                   original_F, original_K, math.floor(F), math.floor(K)),
      {"Use Reduced", "New Time Signature"}
    )
    
    if choice == "New Time Signature" then
      return nil  -- Signal that we need new input
    end
  end
  
  return math.floor(F), math.floor(K)
end

-- Function to configure time signature settings
function configureTimeSignature(F, K)
  local song=renoise.song()
  
  -- Check and adjust values if they exceed limits
  local adjusted_F, adjusted_K = adjustValuesForRenoiseLimits(F, K)
  
  if not adjusted_F then
    -- User chose to enter new values
    renoise.app():show_status("Please select a different time signature")
    return
  end
  
  -- Apply the adjusted values
  F, K = adjusted_F, adjusted_K
  
  -- Calculate new values
  local new_lpb = F * K
  local new_pattern_length = F * K * 4
  
  -- Apply new values (BPM stays unchanged)
  song.transport.lpb = new_lpb
  song.selected_pattern.number_of_lines = new_pattern_length
  
  -- Get master track
  local master_track_index = song.sequencer_track_count + 1
  local master_track = song:track(master_track_index)
  local pattern = song.selected_pattern
  local master_track_pattern = pattern:track(master_track_index)
  local first_line = master_track_pattern:line(1)
  
  print("\n=== Debug Info ===")
  print("Visible effect columns:", master_track.visible_effect_columns)
  
  -- Find first empty effect column or create one if needed
  local found_empty_column = false
  local column_to_use = nil
  
  if master_track.visible_effect_columns == 0 then
    print("No effect columns visible, creating first one")
    master_track.visible_effect_columns = 1
    found_empty_column = true
    column_to_use = 1
  else
    -- Check existing effect columns for an empty one
    print("Checking existing effect columns:")
    for i = 1, master_track.visible_effect_columns do
      local effect_column = first_line:effect_column(i)
      print(string.format("Column %d: number_string='%s', amount_string='%s'", 
        i, effect_column.number_string, effect_column.amount_string))
      
      -- Check if both number and amount are "00" or empty
      if (effect_column.number_string == "" or effect_column.number_string == "00") and
         (effect_column.amount_string == "" or effect_column.amount_string == "00") then
        print("Found empty column at position", i)
        found_empty_column = true
        column_to_use = i
        break
      end
    end
  end
  
  -- If no empty column found among visible ones and we haven't reached the maximum, add a new one
  if not found_empty_column and master_track.visible_effect_columns < 8 then
    print("No empty columns found, adding new column at position", master_track.visible_effect_columns + 1)
    master_track.visible_effect_columns = master_track.visible_effect_columns + 1
    found_empty_column = true
    column_to_use = master_track.visible_effect_columns
  end
  
  if not found_empty_column then
    print("No empty columns available and can't add more")
    renoise.app():show_status("All Effect Columns on Master Track first row are filled, doing nothing.")
    return
  end
  
  print("Using column:", column_to_use)
  print("=== End Debug ===\n")
  
  -- Write LPB command to the found empty column
  first_line:effect_column(column_to_use).number_string = "ZL"
  first_line:effect_column(column_to_use).amount_string = string.format("%02X", new_lpb)
  
  -- Show confirmation message
  local message = string.format(
    "Time signature %d/%d configured: LPB=%d, Pattern Length=%d (BPM unchanged)",
    F, K, new_lpb, new_pattern_length
  )
  print(message)  -- Print to console
  renoise.app():show_status(message)
end

-- Function to show custom time signature dialog
function pakettiBeatStructureEditorDialog()
  local vb = renoise.ViewBuilder()
  
  local DIALOG_MARGIN = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN
  local CONTENT_SPACING = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING
  
  local function createPresetButton(text, F, K)
    return vb:button{
      text = text,
      width=60,
      notifier=function()
        vb.views.numerator.value = F
        vb.views.denominator.value = K
        renoise.app().window.active_middle_frame = 1
      end
    }
  end
  
  -- Declare updatePreview function before using it
  local function updatePreview()
    local F = tonumber(vb.views.numerator.value) or 0
    local K = tonumber(vb.views.denominator.value) or 0
    local lpb = F * K
    local pattern_length = F * K * 4
    local current_bpm = renoise.song().transport.bpm
    
    local warning = ""
    if lpb > 256 or pattern_length > 512 then
      warning = "\n\nWARNING: CANNOT USE THESE VALUES!\nEXCEEDS RENOISE LIMITS!"
    end
    
    vb.views.preview_text.text = string.format(
      "BPM: %d\n" ..
      "LPB: %d\n" ..
      "Pattern Length: %d%s",
      current_bpm, lpb, pattern_length, warning
    )
    vb.views.preview_text.style = "strong"
    renoise.app().window.active_middle_frame = 1
  end
  
  local function printTimeSignatureInfo()
    local current_bpm = renoise.song().transport.bpm
    
    print("\n=== AVAILABLE TIME SIGNATURES ===")
    print("Current preset buttons:")
    local presets = {
      {4,4}, {3,4}, {7,8}, {7,4}, {7,9},
      {2,5}, {3,5}, {8,5}, {9,5}, {8,10},
      {9,10}, {7,5}, {7,10}, {7,7}, {6,7}, {7,6}
    }
    
    for _, sig in ipairs(presets) do
      local F, K = sig[1], sig[2]
      local lpb = F * K
      local pattern_length = F * K * 4
      print(string.format("%d/%d: LPB=%d, Pattern Length=%d, BPM=%d", 
        F, K, lpb, pattern_length, current_bpm))
    end

    print("\n=== ALL POSSIBLE COMBINATIONS ===")
    for F = 1, 20 do
      for K = 1, 20 do
        local lpb = F * K
        local pattern_length = F * K * 4
        local warning = ""
        if lpb > 256 then warning = warning .. " [EXCEEDS LPB LIMIT]" end
        if pattern_length > 512 then warning = warning .. " [EXCEEDS PATTERN LENGTH LIMIT]" end
        
        if warning ~= "" then
          print(string.format("%d/%d: LPB=%d, Pattern Length=%d, BPM=%d%s", 
            F, K, lpb, pattern_length, current_bpm, warning))
        else
          print(string.format("%d/%d: LPB=%d, Pattern Length=%d, BPM=%d", 
            F, K, lpb, pattern_length, current_bpm))
        end
      end
    end
  end
  
  local dialog_content = vb:column{
    margin=DIALOG_MARGIN,
    spacing=CONTENT_SPACING,
    
    vb:horizontal_aligner{
      mode = "center",
      vb:row{
        spacing=CONTENT_SPACING,
        vb:text{text="Rows per Beat:" },
        vb:valuebox{
          id = "numerator",
          width=70,
          min = 1,
          max = 20,
          value = 4,
          notifier=function() updatePreview() end
        },
        vb:text{text="Beats per Pattern:" },
        vb:valuebox{
          id = "denominator",
          width=70,
          min = 1,
          max = 20,
          value = 4,
          notifier=function() updatePreview() end
        }
      }
    },
    
    vb:space { height = 10 },
    
    -- Common time signatures grid
    vb:column{
      style = "group",
      margin=DIALOG_MARGIN,
      spacing=CONTENT_SPACING,
      
      vb:text{text="Presets:" },
      
      -- Common time signatures first
      vb:row{
        spacing=CONTENT_SPACING,
        createPresetButton("4/4", 4, 4),
        createPresetButton("3/4", 3, 4),
        createPresetButton("5/4", 5, 4),
        createPresetButton("6/8", 6, 8),
        createPresetButton("9/8", 9, 8)
      },
      -- Septuple meters
      vb:row{
        spacing=CONTENT_SPACING,
        createPresetButton("7/4", 7, 4),
        createPresetButton("7/8", 7, 8),
        createPresetButton("7/9", 7, 9),
        createPresetButton("7/5", 7, 5),
        createPresetButton("7/6", 7, 6)
      },
      -- Other time signatures
      vb:row{
        spacing=CONTENT_SPACING,
        createPresetButton("2/5", 2, 5),
        createPresetButton("3/5", 3, 5),
        createPresetButton("8/5", 8, 5),
        createPresetButton("9/5", 9, 5),
        createPresetButton("7/7", 7, 7)
      },
      vb:row{
        spacing=CONTENT_SPACING,
        createPresetButton("8/10", 8, 10),
        createPresetButton("9/10", 9, 10),
        createPresetButton("7/10", 7, 10),
        createPresetButton("3/18", 3, 18),
        createPresetButton("4/14", 4, 14)
      },
    vb:column{
      id = "preview",
    --  style = "group",
    --  margin=DIALOG_MARGIN,
      
      vb:text{
        id = "preview_text",
        text = string.format(
          "BPM: %d\nLPB: %d\nPattern Length: %d",
          renoise.song().transport.bpm,
          renoise.song().transport.lpb,
          renoise.song().selected_pattern.number_of_lines
        )
      }}
    },
    
    vb:horizontal_aligner{
      mode = "center",
      vb:button{
        text="Apply",
        width=90,
        notifier=function()
          local F = tonumber(vb.views.numerator.value)
          local K = tonumber(vb.views.denominator.value)
          
          if not F or not K or F <= 0 or K <= 0 then
            renoise.app():show_warning("Please enter valid positive numbers")
            return
          end
          
          configureTimeSignature(F, K)
        end
      }
    }
  }
  
  printTimeSignatureInfo()  -- Add this before showing the dialog
  updatePreview()  -- Initial preview update
  local dialog=renoise.app():show_custom_dialog("Beat Structure Editor",dialog_content,
  my_keyhandler_func)
  renoise.app().window.active_middle_frame = 1
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Beat Structure Editor...",invoke=pakettiBeatStructureEditorDialog}
-------

-- Function to toggle columns with configurable options
function toggleColumns(include_sample_effects)
    local song=renoise.song()
    
    -- Check the first track's state to determine if we should show or hide
    local first_track = song.tracks[1]
    local should_show = not (
        first_track.volume_column_visible and
        first_track.panning_column_visible and
        first_track.delay_column_visible and
        (not include_sample_effects or first_track.sample_effects_column_visible)
    )
    
    -- Iterate through all tracks (except Master and Send tracks)
    for track_index = 1, song.sequencer_track_count do
        local track = song.tracks[track_index]
        -- Set all basic columns
        track.volume_column_visible = should_show
        track.panning_column_visible = should_show
        track.delay_column_visible = should_show
        -- Set sample effects based on parameter
        if include_sample_effects then
            track.sample_effects_column_visible = should_show
        else
            track.sample_effects_column_visible = false
        end
    end
    
    -- Show status message
    local message = should_show and 
        (include_sample_effects and "Showing all columns across all tracks" or 
                                  "Showing all columns except sample effects across all tracks") or 
        "Hiding all columns across all tracks"
    renoise.app():show_status(message)
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle All Columns",invoke=function() toggleColumns(true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle All Columns (No Sample Effects)",invoke=function() toggleColumns(false) end}

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
  
  -- Pitch range settings (transpose ranges)
  local pitch_ranges = {
    {name = "±3", range = 3 * 128, scale = 1.0},    -- ±3 semitones
    {name = "±12", range = 12 * 128, scale = 1.0},  -- ±12 semitones (1 octave)
    {name = "±24", range = 24 * 128, scale = 1.0},  -- ±24 semitones (2 octaves)
    {name = "±120", range = 120 * 128, scale = 1.0} -- ±120 semitones (full range)
  }
  local current_range_index = 2  -- Start with Normal
  
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

  local dialog_content = vb:column{
    -- Single minimal row: Transpose, Finetune, Range Switch, Slider
    vb:row{
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
        width = 200,
        notifier = function(value)
          current_range_index = value
          update_slider_range()
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
    }
  }
  
  -- Show the dialog
  dialog = renoise.app():show_custom_dialog("Sample Pitch Modifier", dialog_content,my_keyhandler_func)
  
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

renoise.tool():add_keybinding{name="Global:Paketti:Sample Pitch Modifier Dialog...",invoke = show_sample_pitch_modifier_dialog}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Sample Pitch Modifier Dialog...",invoke = show_sample_pitch_modifier_dialog}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti Gadgets..:Sample Pitch Modifier Dialog...",invoke = show_sample_pitch_modifier_dialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments..:Sample Pitch Modifier Dialog...",invoke = show_sample_pitch_modifier_dialog}
