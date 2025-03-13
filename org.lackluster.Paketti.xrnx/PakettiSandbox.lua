local dialog = nil
local show_dialog = nil
local current_scope = 1  -- Add this to store the scope value


function get_unique_notes()
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track = pattern:track(song.selected_track_index)
  local trackvis = renoise.song().selected_track
  local unique_notes = {}
  local order = {}
  
  for line_index = 1, pattern.number_of_lines do
    local line = track:line(line_index)
    for note_index = 1, trackvis.visible_note_columns do
      local note_column = line:note_column(note_index)
      if note_column.note_string ~= "---" and note_column.note_string ~= "OFF" then
        -- Use just the note string as key to group by note regardless of instrument
        local key = note_column.note_string
        if not unique_notes[key] then
          unique_notes[key] = {
            note = note_column.note_string,
            instrument = note_column.instrument_value
          }
          table.insert(order, key)
        end
      end
    end
  end
  
  local ordered_notes = {}
  for _, key in ipairs(order) do
    table.insert(ordered_notes, unique_notes[key])
  end
  
  return ordered_notes
end

function apply_instrument_changes(note_string, original_instrument, new_instrument, whole_song)
  local song = renoise.song()
  
  print("\n=== Instrument Change Debug ===")
  print(string.format("Note: %s", note_string))
  print(string.format("Original Instrument: %02X", original_instrument))
  print(string.format("New Instrument: %02X", new_instrument))
  print(string.format("Whole Song Mode: %s", tostring(whole_song)))
  print(string.format("Total Patterns: %d", #song.patterns))
  print(string.format("Selected Track: %d", song.selected_track_index))
  
  if whole_song then
    -- Apply changes across all patterns
    for pattern_index = 1, #song.patterns do
      local pattern = song.patterns[pattern_index]  -- Changed this line
      local track = pattern:track(song.selected_track_index)
      local trackvis = song.selected_track
      local changes_in_pattern = 0
      
      for line_index = 1, pattern.number_of_lines do
        local line = track:line(line_index)
        for note_index = 1, trackvis.visible_note_columns do
          local note_column = line:note_column(note_index)
          if note_column.note_string == note_string and note_column.instrument_value == original_instrument then
            note_column.instrument_value = new_instrument
            changes_in_pattern = changes_in_pattern + 1
          end
        end
      end
      
      print(string.format("Pattern %d: Changed %d notes", pattern_index, changes_in_pattern))
    end
else
    -- Original behavior for current pattern only
    local pattern = song.selected_pattern
    local track = pattern:track(song.selected_track_index)
    local trackvis = song.selected_track
    local changes = 0
    
    for line_index = 1, pattern.number_of_lines do
      local line = track:line(line_index)
      for note_index = 1, trackvis.visible_note_columns do
        local note_column = line:note_column(note_index)
        if note_column.note_string == note_string and note_column.instrument_value == original_instrument then
          note_column.instrument_value = new_instrument
          changes = changes + 1
        end
      end
    end
    
    print(string.format("Current Pattern: Changed %d notes", changes))
  end
  print("=== End Debug ===\n")
end

function track_change_handler()
  if dialog and dialog.visible then
    show_dialog()
  end
end

function show_note_mapping_dialog()
  local dialog = nil

  if dialog and dialog.visible then
    dialog:close()
  end

  local song = renoise.song()


  -- Create track options for dropdown
  local track_options = {}
  for i = 1, song.sequencer_track_count do
    local track = song:track(i)
    track_options[i] = string.format("%02d: %s", i, track.name)
  end

  local instrument_options = {}
  for i = 0, 255 do
    local instrument = song.instruments[i + 1]
    if instrument then
      local name = instrument.name
      if name == "" then name = string.format("Instrument %02X", i) end
      instrument_options[i + 1] = string.format("%02X: %s", i, name)
    end
  end

  -- Declare show_dialog function first
-- Declare show_dialog function first

  function show_dialog()
    if dialog and dialog.visible then
      -- Store current scope before closing
      current_scope = dialog.views.scope_switch.value
      dialog:close()
    end

    local vb = renoise.ViewBuilder()
    local unique_notes = get_unique_notes()
    local content = vb:column{      
      vb:row{
        vb:text{text="Track:", width=40},
        vb:popup{
          width = 250,
          items = track_options,
          value = song.selected_track_index,
          notifier = function(new_index)
            song.selected_track_index = new_index
            show_dialog()
          end
        }
      },
      vb:row{
        margin = 4,
        vb:text{text="Scope:", width=40},
        vb:switch{
          id = "scope_switch",
          width = 250,
          items = {"Current Pattern", "Whole Song"},
          value = current_scope  -- Use stored scope value
        }
      }
    }

        
    -- Add header and notes if we have them
    if #unique_notes > 0 then
      content:add_child(
        vb:row{
          vb:text{text="Note", width=40, font="bold", style="strong"},
          vb:text{text="Instrument", width = 250, font="bold", style="strong"}
        }
      )
      
      for _, note_data in ipairs(unique_notes) do
        content:add_child(
          vb:row{
            vb:text{text = note_data.note, width = 40, font = "mono", style="strong"},
            vb:popup{
              width = 250,
              items = instrument_options,
              value = note_data.instrument + 1,
              notifier = function(new_index)
                local scope_whole_song = (vb.views.scope_switch.value == 2)
                apply_instrument_changes(note_data.note, note_data.instrument, new_index - 1, scope_whole_song)
              end
            }
          }
        )
      end
    else
      content:add_child(
        vb:text{
          text = "No notes on this track, select another one.",
          font = "bold",
          style = "strong"
        }
      )
    end
    
    dialog = renoise.app():show_custom_dialog(
      "Switch Note Instrument Dialog",
      content,
      NoteToInstrumentKeyhandler
    )
    renoise.app().window.active_middle_frame = patternEditor
  end

  -- Remove any existing notifiers first
  if song.selected_track_index_observable:has_notifier(show_dialog) then
    song.selected_track_index_observable:remove_notifier(show_dialog)
  end
  if song.selected_pattern_index_observable:has_notifier(show_dialog) then
    song.selected_pattern_index_observable:remove_notifier(show_dialog)
  end

  -- Add notifiers
  song.selected_track_index_observable:add_notifier(show_dialog)
  song.selected_pattern_index_observable:add_notifier(show_dialog)



  -- Show initial dialog
  show_dialog()
  
  -- Add notifier for track changes
--  song.selected_track_index_observable:add_notifier(show_dialog)
  
  renoise.app().window.active_middle_frame = patternEditor
end

function NoteToInstrumentKeyhandler(dialog,key)
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    local song = renoise.song()
    -- Clean up notifiers when closing
    if song.selected_track_index_observable:has_notifier(show_dialog) then
      song.selected_track_index_observable:remove_notifier(show_dialog)
    end
    if song.selected_pattern_index_observable:has_notifier(show_dialog) then
      song.selected_pattern_index_observable:remove_notifier(show_dialog)
    end
    dialog:close()
    dialog = nil
    return nil
  else
    return key
  end
end
  
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Switch Note Instrument Dialog...",invoke=show_note_mapping_dialog}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Switch Note Instrument Dialog...",invoke=show_note_mapping_dialog}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Switch Note Instrument Dialog...",invoke=show_note_mapping_dialog}




-----

function detect_zero_crossings()
  local song = renoise.song()
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


-- Add menu entries and keybindings
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Experimental/WIP..:Detect Zero Crossings",invoke=detect_zero_crossings}
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

-- Keyhandler Function
local function my_keyhandler_func(dialog, key)
    local closer = preferences.pakettiDialogClose.value
      if key.modifiers == "" and key.name == closer then
        dialog:close()
        dialog=nil
        return nil
      else
        return key
      end
    end
  
-- Function to Calculate BPM
--[[local function calculate_bpm(speed, tempo)
  return tempo / (speed / 6)
end
]]--

-- Function to Calculate BPM
local function calculate_bpm(speed, tempo)
  local rate = 44100  -- or get actual sample rate
  local samplesPerTick = math.floor(rate / tempo)
  return (rate / samplesPerTick) / (speed / 15)
end

-- GUI Dialog Function
function show_speed_tempo_dialog()
  if dialog and dialog.visible then
    dialog:close()
  end

  -- Valueboxes for Speed and Tempo
  local vb = renoise.ViewBuilder()
  local dialog_content = vb:column {
    margin = 10,
    spacing = 8,

    vb:row {
      spacing = 10,
      vb:column {
        vb:text { text = "Speed:" },
        vb:valuebox {
          min = 1,
          max = 255,
          value = speed,
          tostring = function(val) return string.format("%X", val) end,
          tonumber = function(val) return tonumber(val, 16) end,
          notifier = function(val)
            speed = val
            real_bpm = calculate_bpm(speed, tempo)
            vb.views.result_label.text = string.format("Speed %d Tempo %d is %.2f BPM", speed, tempo, real_bpm)
          end
        }
      },
      vb:column {
        vb:text { text = "Tempo:" },
        vb:valuebox {
          min = 32,
          max = 255,
          value = tempo,
          notifier = function(val)
            tempo = val
            real_bpm = calculate_bpm(speed, tempo)
            vb.views.result_label.text = string.format("Speed %d Tempo %d is %.2f BPM", speed, tempo, real_bpm)
          end
        }
      }
    },

    -- Result Display
    vb:row {
      vb:text {
        id = "result_label",
        text = string.format("Speed %d Tempo %d is %.2f BPM", speed, tempo, real_bpm)
      }
    }
  }

  -- Show Dialog
  dialog = renoise.app():show_custom_dialog(
    "Speed and Tempo to BPM",
    dialog_content,
    my_keyhandler_func
  )
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR

end
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Paketti Speed and Tempo to BPM...",invoke=show_speed_tempo_dialog}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Speed and Tempo to BPM...",invoke=show_speed_tempo_dialog}


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
  local song = renoise.song()
  
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
function showTimeSignatureDialog()
  local vb = renoise.ViewBuilder()
  
  local DIALOG_MARGIN = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN
  local CONTENT_SPACING = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING
  
  local function createPresetButton(text, F, K)
    return vb:button {
      text = text,
      width = 60,
      notifier = function()
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
  
  local dialog_content = vb:column {
    margin = DIALOG_MARGIN,
    spacing = CONTENT_SPACING,
    
    vb:horizontal_aligner {
      mode = "center",
      vb:row {
        spacing = CONTENT_SPACING,
        vb:text { text = "Rows per Beat:" },
        vb:valuebox {
          id = "numerator",
          width = 70,
          min = 1,
          max = 20,
          value = 4,
          notifier = function() updatePreview() end
        },
        vb:text { text = "Beats per Pattern:" },
        vb:valuebox {
          id = "denominator",
          width = 70,
          min = 1,
          max = 20,
          value = 4,
          notifier = function() updatePreview() end
        }
      }
    },
    
    vb:space { height = 10 },
    
    -- Common time signatures grid
    vb:column {
      style = "group",
      margin = DIALOG_MARGIN,
      spacing = CONTENT_SPACING,
      
      vb:text { text = "Presets:" },
      
      -- Common time signatures first
      vb:row { 
        spacing = CONTENT_SPACING,
        createPresetButton("4/4", 4, 4),
        createPresetButton("3/4", 3, 4),
        createPresetButton("5/4", 5, 4),
        createPresetButton("6/8", 6, 8),
        createPresetButton("9/8", 9, 8)
      },
      -- Septuple meters
      vb:row { 
        spacing = CONTENT_SPACING,
        createPresetButton("7/4", 7, 4),
        createPresetButton("7/8", 7, 8),
        createPresetButton("7/9", 7, 9),
        createPresetButton("7/5", 7, 5),
        createPresetButton("7/6", 7, 6)
      },
      -- Other time signatures
      vb:row { 
        spacing = CONTENT_SPACING,
        createPresetButton("2/5", 2, 5),
        createPresetButton("3/5", 3, 5),
        createPresetButton("8/5", 8, 5),
        createPresetButton("9/5", 9, 5),
        createPresetButton("7/7", 7, 7)
      },
      vb:row { 
        spacing = CONTENT_SPACING,
        createPresetButton("8/10", 8, 10),
        createPresetButton("9/10", 9, 10),
        createPresetButton("7/10", 7, 10),
        createPresetButton("3/18", 3, 18),
        createPresetButton("4/14", 4, 14)
      },
    vb:column {
      id = "preview",
    --  style = "group",
    --  margin = DIALOG_MARGIN,
      
      vb:text { 
        id = "preview_text",
        text = string.format(
          "BPM: %d\nLPB: %d\nPattern Length: %d",
          renoise.song().transport.bpm,
          renoise.song().transport.lpb,
          renoise.song().selected_pattern.number_of_lines
        )
      }}
    },
    
    vb:horizontal_aligner {
      mode = "center",
      vb:button {
        text = "Apply",
        width = 90,
        notifier = function()
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
  
  local dialog=renoise.app():show_custom_dialog("Beat Structure Editor",dialog_content,TimeSignatureDialogKeyHandler)
  
  -- Set initial focus to pattern editor
  renoise.app().window.active_middle_frame = 1
end

-- Add key handler function (moved to before usage)
function TimeSignatureDialogKeyHandler(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    dialog = nil
    return nil
  else
    return key
  end
end

-- Add menu entries for common time signatures
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Paketti Beat Structure Editor...",invoke=showTimeSignatureDialog}
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Paketti Beat Structure Editor...",invoke=showTimeSignatureDialog}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Beat Structure Editor...",invoke=showTimeSignatureDialog}
-------





-- Function to set output delay with bounds checking
function set_output_delay(delay_value, rename)
  local track = renoise.song().selected_track
  
  -- Check if track type allows output delay changes
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Cannot change output delay on group, master or send tracks")
    return
  end
  
  -- Clamp value between -100 and 100
  delay_value = math.max(-100, math.min(100, delay_value))
  track.output_delay = delay_value
  
  -- Update track name if rename is true
  if rename then
    local prefix = delay_value > 0 and "+" or ""
    track.name = string.format("%s%dms", prefix, delay_value)
  end
  
  renoise.app():show_status(string.format("Output delay set to: %d", delay_value))
end

-- Function to nudge output delay
function nudge_output_delay(amount, rename)
  local track = renoise.song().selected_track
  
  -- Check if track type allows output delay changes
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("Cannot change output delay on group, master or send tracks")
    return
  end
  
  local current_delay = track.output_delay
  local new_delay = current_delay + amount
  
  if new_delay > 100 then
    renoise.app():show_status("At maximum positive delay, cannot go further")
    return
  elseif new_delay < -100 then
    renoise.app():show_status("At maximum negative delay, cannot go further")
    return
  end
  
  track.output_delay = new_delay
  
  -- Update track name if rename is true
  if rename then
    local prefix = new_delay > 0 and "+" or ""
    track.name = string.format("%s%dms", prefix, new_delay)
  end
  
  renoise.app():show_status(string.format("Output delay: %d", new_delay))
end

function reset_output_delay(rename)
  local track = renoise.song().selected_track
  
  -- Check if track type allows output delay changes
  if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    track.output_delay = 0
    if rename then
      track.name = "0ms"
    end
    renoise.app():show_status("Output delay reset to 0ms")
  else
    renoise.app():show_status("Cannot change output delay on group, master or send tracks")
  end
end

function reset_output_delayALL(rename)
  local song = renoise.song()
  local count = 0
  
  -- Reset delays for sequencer tracks only
  for i = 1, song.sequencer_track_count do
    local track = song:track(i)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER and track.output_delay ~= 0 then
      track.output_delay = 0
      if rename then
        track.name = "0ms"
      end
      count = count + 1
    end
  end
  
  if count > 0 then
    renoise.app():show_status(string.format("Reset output delay to 0ms on %d tracks", count))
  else
    renoise.app():show_status("All track output delays were already at 0ms")
  end
end

-- MIDI mappings
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay Control x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
      local value = message.int_value
      local delay_value
      
      if value == 64 then
        delay_value = 0
      elseif value > 64 then
        -- Map 65-127 to 1-100
        delay_value = math.floor((value - 64) * (100 / 63))
      else
        -- Map 0-63 to -100-(-1)
        delay_value = math.floor(value * (-100 / 63))
      end
      
      set_output_delay(delay_value, false)
    end
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay Control (Rename) x[Knob]",
  invoke = function(message)
    if message:is_abs_value() then
      local value = message.int_value
      local delay_value
      
      if value == 64 then
        delay_value = 0
      elseif value > 64 then
        -- Map 65-127 to 1-100
        delay_value = math.floor((value - 64) * (100 / 63))
      else
        -- Map 0-63 to -100-(-1)
        delay_value = math.floor(value * (-100 / 63))
      end
      
      set_output_delay(delay_value, true)
    end
  end
}

-- Trigger MIDI mappings
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay +01 x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(1, false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay -01 x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(-1, false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay +05 x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(5, false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay -05 x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(-5, false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay +10 x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(10, false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay -10 x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(-10, false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Reset Nudge Delay Output Delay to 0ms x[Trigger]",invoke=function(message) if message:is_trigger() then reset_output_delay(false) end end}
renoise.tool():add_midi_mapping{name="Paketti:Reset Nudge Delay Output Delay to 0ms (ALL) x[Trigger]",invoke=function(message) if message:is_trigger() then reset_output_delayALL(false) end end}

-- Trigger MIDI mappings (Rename versions)
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay +01 (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(1, true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay -01 (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(-1, true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay +05 (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(5, true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay -05 (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(-5, true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay +10 (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(10, true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Nudge Delay Output Delay -10 (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then nudge_output_delay(-10, true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Reset Nudge Delay Output Delay to 0ms (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then reset_output_delay(true) end end}
renoise.tool():add_midi_mapping{name="Paketti:Reset Nudge Delay Output Delay to 0ms (ALL) (Rename) x[Trigger]",invoke=function(message) if message:is_trigger() then reset_output_delayALL(true) end end}

-- Keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay +01ms",invoke=function() nudge_output_delay(1, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay -01ms",invoke=function() nudge_output_delay(-1, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay +10ms",invoke=function() nudge_output_delay(10, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay -10ms",invoke=function() nudge_output_delay(-10, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay +05ms",invoke=function() nudge_output_delay(5, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay -05ms",invoke=function() nudge_output_delay(-5, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Reset Nudge Delay Output Delay to 0ms",invoke=function() reset_output_delay(false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Reset Nudge Delay Output Delay to 0ms (ALL)",invoke=function() reset_output_delayALL(false) end}

-- Keybindings (Rename versions)
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay +01ms (Rename)",invoke=function() nudge_output_delay(1, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay -01ms (Rename)",invoke=function() nudge_output_delay(-1, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay +10ms (Rename)",invoke=function() nudge_output_delay(10, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay -10ms (Rename)",invoke=function() nudge_output_delay(-10, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay +05ms (Rename)",invoke=function() nudge_output_delay(5, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Nudge Delay Output Delay -05ms (Rename)",invoke=function() nudge_output_delay(-5, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Reset Nudge Delay Output Delay to 0ms (Rename)",invoke=function() reset_output_delay(true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Reset Nudge Delay Output Delay to 0ms (ALL) (Rename)",invoke=function() reset_output_delayALL(true) end}

-- Menu entries
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti..:Delay Output..:Nudge Delay Output +01ms",invoke=function() nudge_output_delay(1, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Delay Output..:Nudge Delay Output -01ms",invoke=function() nudge_output_delay(-1, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Delay Output..:Nudge Delay Output +05ms",invoke=function() nudge_output_delay(5, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Delay Output..:Nudge Delay Output -05ms",invoke=function() nudge_output_delay(-5, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Delay Output..:Nudge Delay Output +10ms",invoke=function() nudge_output_delay(10, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Delay Output..:Nudge Delay Output -10ms",invoke=function() nudge_output_delay(-10, false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms",invoke=function() reset_output_delay(false) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms (ALL)",invoke=function() reset_output_delayALL(false) end}

-- Menu entries (Rename versions)
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti..:Delay Output..:Nudge Delay Output +01ms (Rename)",invoke=function() nudge_output_delay(1, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Delay Output..:Nudge Delay Output -01ms (Rename)",invoke=function() nudge_output_delay(-1, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Delay Output..:Nudge Delay Output +05ms (Rename)",invoke=function() nudge_output_delay(5, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Delay Output..:Nudge Delay Output -05ms (Rename)",invoke=function() nudge_output_delay(-5, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Delay Output..:Nudge Delay Output +10ms (Rename)",invoke=function() nudge_output_delay(10, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Delay Output..:Nudge Delay Output -10ms (Rename)",invoke=function() nudge_output_delay(-10, true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms (Rename)",invoke=function() reset_output_delay(true) end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms (ALL) (Rename)",invoke=function() reset_output_delayALL(true) end}

-- Mixer menu entries
renoise.tool():add_menu_entry{name="--Mixer:Paketti..:Delay Output..:Nudge Delay Output Delay +01ms",invoke=function() nudge_output_delay(1, false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Delay Output..:Nudge Delay Output Delay -01ms",invoke=function() nudge_output_delay(-1, false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Delay Output..:Nudge Delay Output Delay +05ms",invoke=function() nudge_output_delay(5, false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Delay Output..:Nudge Delay Output Delay -05ms",invoke=function() nudge_output_delay(-5, false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Delay Output..:Nudge Delay Output Delay +10ms",invoke=function() nudge_output_delay(10, false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Delay Output..:Nudge Delay Output Delay -10ms",invoke=function() nudge_output_delay(-10, false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms",invoke=function() reset_output_delay(false) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms (ALL)",invoke=function() reset_output_delayALL(false) end}

-- Mixer menu entries (Rename versions)
renoise.tool():add_menu_entry{name="--Mixer:Paketti..:Delay Output..:Nudge Delay Output Delay +01ms (Rename)",invoke=function() nudge_output_delay(1, true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Delay Output..:Nudge Delay Output Delay -01ms (Rename)",invoke=function() nudge_output_delay(-1, true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Delay Output..:Nudge Delay Output Delay +05ms (Rename)",invoke=function() nudge_output_delay(5, true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Delay Output..:Nudge Delay Output Delay -05ms (Rename)",invoke=function() nudge_output_delay(-5, true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Delay Output..:Nudge Delay Output Delay +10ms (Rename)",invoke=function() nudge_output_delay(10, true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Delay Output..:Nudge Delay Output Delay -10ms (Rename)",invoke=function() nudge_output_delay(-10, true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms (Rename)",invoke=function() reset_output_delay(true) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms (ALL) (Rename)",invoke=function() reset_output_delayALL(true) end}

-- Pattern Matrix menu entries
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay +01ms",invoke=function() nudge_output_delay(1, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay -01ms",invoke=function() nudge_output_delay(-1, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay +05ms",invoke=function() nudge_output_delay(5, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay -05ms",invoke=function() nudge_output_delay(-5, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay +10ms",invoke=function() nudge_output_delay(10, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay -10ms",invoke=function() nudge_output_delay(-10, false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms",invoke=function() reset_output_delay(false) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms (ALL)",invoke=function() reset_output_delayALL(false) end}

-- Pattern Matrix menu entries (Rename versions)
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay +01ms (Rename)",invoke=function() nudge_output_delay(1, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay -01ms (Rename)",invoke=function() nudge_output_delay(-1, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay +05ms (Rename)",invoke=function() nudge_output_delay(5, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay -05ms (Rename)",invoke=function() nudge_output_delay(-5, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay +10ms (Rename)",invoke=function() nudge_output_delay(10, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Nudge Delay Output Delay -10ms (Rename)",invoke=function() nudge_output_delay(-10, true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms (Rename)",invoke=function() reset_output_delay(true) end}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Delay Output..:Reset Delay Output Delay to 0ms (ALL) (Rename)",invoke=function() reset_output_delayALL(true) end}
