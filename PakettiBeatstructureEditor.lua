
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
  -- Check if dialog is already open and close it
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  
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
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Beat Structure Editor",dialog_content,keyhandler)
  renoise.app().window.active_middle_frame = 1
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Beat Structure Editor...",invoke=pakettiBeatStructureEditorDialog}
