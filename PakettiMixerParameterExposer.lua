-- PakettiMixerParameterExposer.lua
-- Dialog to view and toggle show_in_mixer for all device parameters on selected track

PakettiMixerParameterExposer_dialog = nil
PakettiMixerParameterExposer_track_notifier = nil
PakettiMixerParameterExposer_rebuilding = false  -- Guard flag to prevent recursion

-- Handler for track change - close and reopen dialog with new track's devices
function PakettiMixerParameterExposerTrackChangeHandler()
  -- Prevent recursion
  if PakettiMixerParameterExposer_rebuilding then
    return
  end
  
  if PakettiMixerParameterExposer_dialog and PakettiMixerParameterExposer_dialog.visible then
    PakettiMixerParameterExposer_rebuilding = true
    
    -- Remove notifier before closing
    if PakettiMixerParameterExposer_track_notifier then
      if renoise.song().selected_track_index_observable:has_notifier(PakettiMixerParameterExposer_track_notifier) then
        renoise.song().selected_track_index_observable:remove_notifier(PakettiMixerParameterExposer_track_notifier)
      end
      PakettiMixerParameterExposer_track_notifier = nil
    end
    
    -- Close existing dialog
    PakettiMixerParameterExposer_dialog:close()
    PakettiMixerParameterExposer_dialog = nil
    
    -- Reopen with new track
    PakettiMixerParameterExposerOpenDialog()
    
    PakettiMixerParameterExposer_rebuilding = false
  end
end

-- Internal function to open dialog (used by both initial open and track change rebuild)
function PakettiMixerParameterExposerOpenDialog()
  local song = renoise.song()
  local track = song.selected_track
  local track_index = song.selected_track_index
  
  if not track then
    renoise.app():show_status("No track selected")
    return
  end
  
  if #track.devices == 0 then
    renoise.app():show_status("Selected track has no devices")
    return
  end

  local vb = renoise.ViewBuilder()
  local device_columns = {}
  
  -- Store checkbox references for later updates (key: "dev_param" e.g. "2_5")
  local checkbox_refs = {}
  
  -- Get max rows per column from preferences (default 25)
  local max_rows = 25
  if preferences and preferences.pakettiMixerParameterExposer and preferences.pakettiMixerParameterExposer.MaxRowsPerColumn then
    max_rows = preferences.pakettiMixerParameterExposer.MaxRowsPerColumn.value
  end

  -- Build columns for each device (may be multiple columns per device if many parameters)
  for dev_idx = 1, #track.devices do
    local device = track.devices[dev_idx]
    local device_name = device.display_name or device.name or "Device"
    local num_params = #device.parameters
    
    -- Calculate how many columns this device needs
    local num_columns = math.ceil(num_params / max_rows)
    if num_columns < 1 then num_columns = 1 end
    
    for col_num = 1, num_columns do
      local param_rows = {}
      
      -- Add device name header (style strong + font bold)
      param_rows[#param_rows + 1] = vb:text{
        text = device_name,
        font = "bold",
        style = "strong",
        width = 140
      }
      
      -- Calculate parameter range for this column
      local start_param = (col_num - 1) * max_rows + 1
      local end_param = math.min(col_num * max_rows, num_params)
      
      -- Add checkbox + text for each parameter in this column's range
      for param_idx = start_param, end_param do
        local param = device.parameters[param_idx]
        local param_name = param.name or "Parameter"
        
        -- Create local references to capture current indices
        local current_dev_idx = dev_idx
        local current_param_idx = param_idx
        
        local checkbox = vb:checkbox{
          value = param.show_in_mixer,
          notifier = function(value)
            local current_track = renoise.song().selected_track
            if current_track and current_track.devices[current_dev_idx] then
              local current_param = current_track.devices[current_dev_idx].parameters[current_param_idx]
              if current_param then
                current_param.show_in_mixer = value
                print("Set " .. device_name .. " -> " .. param_name .. " show_in_mixer = " .. tostring(value))
              end
            end
          end
        }
        
        -- Store checkbox reference for later updates
        local ref_key = dev_idx .. "_" .. param_idx
        checkbox_refs[ref_key] = checkbox
        
        param_rows[#param_rows + 1] = vb:row{
          margin = 0,
          spacing = 0,
          checkbox,
          vb:text{
            text = param_name,
            width = 120
          }
        }
      end
      
      -- Create column for this device (or portion of device)
      device_columns[#device_columns + 1] = vb:column{
        margin = 0,
        spacing = 0,
        unpack(param_rows)
      }
    end
  end

  -- Create button row with action buttons
  local button_row = vb:row{
    margin = 0,
    spacing = 0,
    vb:button{
      text = "Expose Automated Parameters",
      notifier = function()
        local current_song = renoise.song()
        local current_track = current_song.selected_track
        local current_track_index = current_song.selected_track_index
        local count = 0
        
        -- Scan all devices on this track
        for dev_idx = 1, #current_track.devices do
          local device = current_track.devices[dev_idx]
          
          -- Check each parameter
          for param_idx = 1, #device.parameters do
            local param = device.parameters[param_idx]
            if param.is_automatable then
              -- Scan all patterns for automation
              for pattern_index = 1, #current_song.patterns do
                local pattern_track = current_song:pattern(pattern_index):track(current_track_index)
                local automation = pattern_track:find_automation(param)
                if automation and #automation.points > 0 then
                  -- Found automation - expose in mixer
                  param.show_in_mixer = true
                  count = count + 1
                  print("Exposed: " .. (device.display_name or device.name) .. " -> " .. param.name)
                  
                  -- Update checkbox in dialog
                  local ref_key = dev_idx .. "_" .. param_idx
                  if checkbox_refs[ref_key] then
                    checkbox_refs[ref_key].value = true
                  end
                  
                  break -- Found automation, no need to check more patterns
                end
              end
            end
          end
        end
        
        renoise.app():show_status("Exposed " .. count .. " automated parameters in mixer")
      end
    },
    vb:button{
      text = "Show All",
      notifier = function()
        local current_track = renoise.song().selected_track
        local count = 0
        
        for dev_idx = 1, #current_track.devices do
          local device = current_track.devices[dev_idx]
          for param_idx = 1, #device.parameters do
            local param = device.parameters[param_idx]
            param.show_in_mixer = true
            count = count + 1
            
            -- Update checkbox in dialog
            local ref_key = dev_idx .. "_" .. param_idx
            if checkbox_refs[ref_key] then
              checkbox_refs[ref_key].value = true
            end
          end
        end
        
        renoise.app():show_status("Showing all " .. count .. " parameters in mixer")
      end
    },
    vb:button{
      text = "Hide All",
      notifier = function()
        local current_track = renoise.song().selected_track
        local count = 0
        
        for dev_idx = 1, #current_track.devices do
          local device = current_track.devices[dev_idx]
          for param_idx = 1, #device.parameters do
            local param = device.parameters[param_idx]
            param.show_in_mixer = false
            count = count + 1
            
            -- Update checkbox in dialog
            local ref_key = dev_idx .. "_" .. param_idx
            if checkbox_refs[ref_key] then
              checkbox_refs[ref_key].value = false
            end
          end
        end
        
        renoise.app():show_status("Hiding all " .. count .. " parameters from mixer")
      end
    }
  }

  -- Build dialog content: button row on top, device columns below
  local dialog_content = vb:column{
    margin = 0,
    spacing = 0,
    button_row,
    vb:row{
      margin = 0,
      spacing = 0,
      unpack(device_columns)
    }
  }

  PakettiMixerParameterExposer_dialog = renoise.app():show_custom_dialog(
    "Mixer Parameter Exposer - " .. track.name,
    dialog_content,
    my_keyhandler_func
  )
  
  -- Add track change notifier to update dialog when track changes
  PakettiMixerParameterExposer_track_notifier = PakettiMixerParameterExposerTrackChangeHandler
  if not renoise.song().selected_track_index_observable:has_notifier(PakettiMixerParameterExposer_track_notifier) then
    renoise.song().selected_track_index_observable:add_notifier(PakettiMixerParameterExposer_track_notifier)
  end
  
  -- Reset keyboard focus to Renoise
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Public function to show/toggle the dialog
function PakettiMixerParameterExposerShowDialog()
  -- Toggle behavior: if dialog is open and visible, close it and return
  if PakettiMixerParameterExposer_dialog and PakettiMixerParameterExposer_dialog.visible then
    -- Remove track notifier when closing
    if PakettiMixerParameterExposer_track_notifier then
      if renoise.song().selected_track_index_observable:has_notifier(PakettiMixerParameterExposer_track_notifier) then
        renoise.song().selected_track_index_observable:remove_notifier(PakettiMixerParameterExposer_track_notifier)
      end
      PakettiMixerParameterExposer_track_notifier = nil
    end
    
    PakettiMixerParameterExposer_dialog:close()
    PakettiMixerParameterExposer_dialog = nil
    return
  end
  
  -- Open new dialog
  PakettiMixerParameterExposerOpenDialog()
end

renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti Gadgets:Mixer Parameter Exposer...", invoke = PakettiMixerParameterExposerShowDialog}
renoise.tool():add_menu_entry{name = "Mixer:Paketti Gadgets:Mixer Parameter Exposer...", invoke = PakettiMixerParameterExposerShowDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Mixer Parameter Exposer", invoke = PakettiMixerParameterExposerShowDialog}
