local vb = renoise.ViewBuilder()
local dialog = nil
local slider1_value_text
local slider2_value_text
local xy_value_text
local position
local reopen_dialog_flag = false

-- Key handler function
local function PakettiPluginEditorPositionControlKeyHandlerFunc(dialog, key)
  if key.modifiers == "" and key.name == "exclamation" then
    print("Exclamation key pressed, closing dialog.")
    dialog:close()
  else
    return key
  end
end


-- Check if selected instrument has a plugin loaded
local function PakettiPluginEditorPositionControlGetPluginEditorPosition()
  local song = renoise.song()
  local instr = song.selected_instrument
  if not instr.plugin_properties.plugin_loaded then
    return nil
  end
  local xml_data = instr.plugin_properties.plugin_device.active_preset_data
  local pos = xml_data:match("<PluginEditorWindowPosition>%d+,%d+</PluginEditorWindowPosition>")
  return pos and {x = tonumber(pos:match("(%d+),")), y = tonumber(pos:match(",(%d+)"))} or {x = 0, y = 0}
end

-- Update XML data with new position
local function PakettiPluginEditorPositionControlSetPluginEditorPosition(x, y)
  local song = renoise.song()
  local instr = song.selected_instrument
  local xml_data = instr.plugin_properties.plugin_device.active_preset_data

  -- Clamp the values to the maximum limits
  x = math.min(math.floor(x or 0), 1500)
  y = math.min(math.floor(y or 0), 850)

  -- Extract and print the relevant line
  local position_line = xml_data:match("<PluginEditorWindowPosition>%d+,%d+</PluginEditorWindowPosition>")
  print("Current XML Data: ", position_line)
  print("Setting new position: x = " .. tostring(x) .. ", y = " .. tostring(y))

  local new_xml = xml_data:gsub("<PluginEditorWindowPosition>%d+,%d+</PluginEditorWindowPosition>",
    ("<PluginEditorWindowPosition>%d,%d</PluginEditorWindowPosition>"):format(x, y))

  -- Extract and print the relevant line from the new XML
  local new_position_line = new_xml:match("<PluginEditorWindowPosition>%d+,%d+</PluginEditorWindowPosition>")
  print("New XML Data: ", new_position_line)

  instr.plugin_properties.plugin_device.active_preset_data = new_xml
end

-- Timer function to update the external editor position
local function update_external_editor_position()
  local song = renoise.song()
  local instr = song.selected_instrument
  instr.plugin_properties.plugin_device.external_editor_visible = true
  if renoise.tool():has_timer(update_external_editor_position) then
    renoise.tool():remove_timer(update_external_editor_position)
  end
  reopen_dialog_flag = true
end

-- Function to set position and update external editor
local function set_position_and_update(x, y)
  local song = renoise.song()
  local instr = song.selected_instrument
  instr.plugin_properties.plugin_device.external_editor_visible = false

  if renoise.tool():has_timer(update_external_editor_position) then
    renoise.tool():remove_timer(update_external_editor_position)
  end

  PakettiPluginEditorPositionControlSetPluginEditorPosition(x, y)

  renoise.tool():add_timer(update_external_editor_position, 250)
  print("Set position to: x = " .. tostring(math.floor(x)) .. ", y = " .. tostring(math.floor(y)))
end

-- Function to dump the current position from sliders and update external editor
local function dump_position(sliders)
  local new_x = sliders[1].value
  local new_y = sliders[2].value
  local song = renoise.song()
  local instr = song.selected_instrument
  instr.plugin_properties.plugin_device.external_editor_visible = false

  if renoise.tool():has_timer(update_external_editor_position) then
    renoise.tool():remove_timer(update_external_editor_position)
  end

  PakettiPluginEditorPositionControlSetPluginEditorPosition(new_x, new_y)

  renoise.tool():add_timer(update_external_editor_position, 250)
  print("Dumped position from sliders: x = " .. tostring(math.floor(new_x)) .. ", y = " .. tostring(math.floor(new_y)))
end

-- Function to dump the current position from XY pad and update external editor
local function dump_position_xy(xypad)
  local value = xypad.value
  local new_x = value.x * 1500
  local new_y = (1 - value.y) * 850
  local song = renoise.song()
  local instr = song.selected_instrument
  instr.plugin_properties.plugin_device.external_editor_visible = false

  if renoise.tool():has_timer(update_external_editor_position) then
    renoise.tool():remove_timer(update_external_editor_position)
  end

  PakettiPluginEditorPositionControlSetPluginEditorPosition(new_x, new_y)

  renoise.tool():add_timer(update_external_editor_position, 250)
  print("Dumped position from XY pad: x = " .. tostring(math.floor(new_x)) .. ", y = " .. tostring(math.floor(new_y)))
end

-- Function to create the dialog
local function PakettiPluginEditorPositionControlCreateDialog()
  local sliders
  local xypad = vb:xypad{
    min = {x = 0, y = 0},
    max = {x = 1, y = 1},
    value = {x = 0.75, y = 0.75},
    notifier = function(value)
      local x = math.floor(value.x * 1500)
      local y = math.floor((1 - value.y) * 850)
      xy_value_text.text = "XY Value: x = " .. tostring(x) .. ", y = " .. tostring(y)
    end
  }

  sliders = {
    vb:slider{
      min = 0,
      max = 1500,
      value = position.x,
      width = 200,
      notifier = function(value)
        slider1_value_text.text = "Slider1 Value: " .. tostring(math.floor(value))
        print("Slider 1 Value: " .. tostring(math.floor(value)))
      end
    },
    vb:slider{
      min = 0,
      max = 850,
      value = position.y,
      width = 200,
      notifier = function(value)
        slider2_value_text.text = "Slider2 Value: " .. tostring(math.floor(value))
        print("Slider 2 Value: " .. tostring(math.floor(value)))
      end
    }
  }

  slider1_value_text = vb:text{
    text = "Slider1 Value: " .. tostring(position.x)
  }
  
  slider2_value_text = vb:text{
    text = "Slider2 Value: " .. tostring(position.y)
  }
  
  xy_value_text = vb:text{
    text = "XY Value: x = " .. tostring(xypad.value.x * 1500) .. ", y = " .. tostring((1 - xypad.value.y) * 850)
  }

  local dump_button = vb:button{
    text = "Slider Dump to External Editor Position",
    notifier = function()
      dump_position(sliders)
    end
  }

  local dump_xy_button = vb:button{
    text = "XY Dump to External Editor Position",
    notifier = function()
      dump_position_xy(xypad)
    end
  }

  local set_button_200 = vb:button{
    text = "Set Position to 200",
    notifier = function()
      set_position_and_update(200, 200)
    end
  }

  local set_button_500 = vb:button{
    text = "Set Position to 500",
    notifier = function()
      set_position_and_update(500, 500)
    end
  }

  local position_text = vb:text{
    text = "Current Position: x = " .. tostring(position.x) .. ", y = " .. tostring(position.y)
  }

  return vb:column{
    vb:row{
      vb:column{
        style = "border",
        margin = 4,
        xypad
      },
      xy_value_text
    },
    vb:row{
      vb:column{
        sliders[1],
        slider1_value_text
      },
      vb:column{
        sliders[2],
        slider2_value_text
      }
    },
    vb:row{dump_button, dump_xy_button, set_button_200, set_button_500},
    vb:row{position_text}
  }
end

-- Function to show the dialog
local function PakettiPluginEditorPositionControlShowDialog()
  if dialog and dialog.visible then
    dialog:close()
  end
  
  position = PakettiPluginEditorPositionControlGetPluginEditorPosition() or {x = 0, y = 0}

  dialog = renoise.app():show_custom_dialog("Plugin Editor Position", PakettiPluginEditorPositionControlCreateDialog(), PakettiPluginEditorPositionControlKeyHandlerFunc)
end

local function PakettiPluginEditorPositionControlShowInitialDialog()
  local song = renoise.song()
  local instr = song.selected_instrument
  if instr.plugin_properties.plugin_loaded and not instr.plugin_properties.plugin_device.external_editor_visible then
    instr.plugin_properties.plugin_device.external_editor_visible = true
  end

  PakettiPluginEditorPositionControlShowDialog()
end

-- Add a periodic timer to handle reopening the dialog if needed
local function periodic_check()
  if reopen_dialog_flag then
    reopen_dialog_flag = false
    PakettiPluginEditorPositionControlShowDialog()
  end
end

renoise.tool():add_timer(periodic_check, 100)

PakettiPluginEditorPositionControlShowInitialDialog()



------


-------------------------
--------
--[[
function Experimental()
    function read_file(path)
        local file = io.open(path, "r")  -- Open the file in read mode
        if not file then
            print("Failed to open file")
            return nil
        end
        local content = file:read("*a")  -- Read the entire content
        file:close()
        return content
    end

    function check_and_execute(xml_path, bash_script)
        local xml_content = read_file(xml_path)
        if not xml_content then
            return
        end

        local pattern = "<ShowScriptingDevelopmentTools>(.-)</ShowScriptingDevelopmentTools>"
        local current_value = xml_content:match(pattern)

        if current_value == "false" then  -- Check if the value is false
            print("Scripting tools are disabled. Executing the bash script to enable...")
            local command = 'open -a Terminal "' .. bash_script .. '"'
            os.execute(command)
        elseif current_value == "true" then
            print("Scripting tools are already enabled. No need to execute the bash script.")
          local bash_script = "/Users/esaruoho/macOS_DisableScriptingTools.sh"
            local command = 'open -a Terminal "' .. bash_script .. '"'
            os.execute(command)
        else
            print("Could not find the <ShowScriptingDevelopmentTools> tag in the XML.")
        end
    end

    local config_path = "/Users/esaruoho/Library/Preferences/Renoise/V3.4.3/Config.xml"
    local bash_script = "/Users/esaruoho/macOS_EnableScriptingTools.sh" -- Ensure this path is correct

    check_and_execute(config_path, bash_script)
end

--renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Experimental (macOS Only) Config.XML overwriter (Destructive)",invoke=function() Experimental() end}
]]--

--renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:writeToClipboard",invoke=function() 
--writeToClipboard(for key, value in ipairs (devices) do  print(key, value)
--end}

--renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Dump VST/AU/Native Effects to Clipboard",invoke=function() 
--) end}


--------
---------------------------------------------------------------------------------------------------
--Set the next ReWire channel - shortcut. If you have a pre-configured 32 input ReWire master host
--running, you can just press a shortcut and get it to play in the track of your choice (on your
--master host that is). This is a really simple thing, but it works after a fashion and does
--what I wanted it to do.
--[[function next_rewire()
local s=renoise.song()
local current=s.selected_track.output_routing
local st=s.selected_track
if current=="Master Track" then st.output_routing="Bus 01 L/R"
elseif current=="Bus 01 L/R" then st.output_routing="Bus 02 L/R"
elseif current=="Bus 02 L/R" then st.output_routing="Bus 03 L/R"
elseif current=="Bus 03 L/R" then st.output_routing="Bus 04 L/R"
elseif current=="Bus 04 L/R" then st.output_routing="Bus 05 L/R"
elseif current=="Bus 05 L/R" then st.output_routing="Bus 06 L/R"
elseif current=="Bus 06 L/R" then st.output_routing="Bus 07 L/R"
elseif current=="Bus 07 L/R" then st.output_routing="Bus 08 L/R"
elseif current=="Bus 08 L/R" then st.output_routing="Bus 09 L/R"
elseif current=="Bus 09 L/R" then st.output_routing="Bus 10 L/R"
elseif current=="Bus 10 L/R" then st.output_routing="Bus 11 L/R"
elseif current=="Bus 11 L/R" then st.output_routing="Bus 12 L/R"
elseif current=="Bus 12 L/R" then st.output_routing="Bus 13 L/R"
elseif current=="Bus 13 L/R" then st.output_routing="Bus 14 L/R"
elseif current=="Bus 14 L/R" then st.output_routing="Bus 15 L/R"
elseif current=="Bus 15 L/R" then st.output_routing="Bus 16 L/R"
elseif current=="Bus 16 L/R" then st.output_routing="Bus 17 L/R"
elseif current=="Bus 17 L/R" then st.output_routing="Bus 18 L/R"
elseif current=="Bus 18 L/R" then st.output_routing="Bus 19 L/R"
elseif current=="Bus 19 L/R" then st.output_routing="Bus 20 L/R"
elseif current=="Bus 20 L/R" then st.output_routing="Bus 21 L/R"
elseif current=="Bus 21 L/R" then st.output_routing="Bus 22 L/R"
elseif current=="Bus 22 L/R" then st.output_routing="Bus 23 L/R"
elseif current=="Bus 23 L/R" then st.output_routing="Bus 24 L/R"
elseif current=="Bus 24 L/R" then st.output_routing="Bus 25 L/R"
elseif current=="Bus 25 L/R" then st.output_routing="Bus 26 L/R"
elseif current=="Bus 26 L/R" then st.output_routing="Bus 27 L/R"
elseif current=="Bus 27 L/R" then st.output_routing="Bus 28 L/R"
elseif current=="Bus 28 L/R" then st.output_routing="Bus 29 L/R"
elseif current=="Bus 29 L/R" then st.output_routing="Bus 30 L/R"
elseif current=="Bus 30 L/R" then st.output_routing="Bus 31 L/R"
elseif current=="Bus 31 L/R" then st.output_routing="Master Track"
end
renoise.app():show_status("Current Track output set to: " .. st.output_routing) 
end

renoise.tool():add_keybinding{name="Global:Paketti:Set ReWire Channel (Next)",invoke=function() next_rewire() end  }
----------------------------------------------------------------------------------------------------------
]]--

------

--renoise.tool():add_keybinding{name="Global:Paketti:Stair RecordToCurrent",invoke=function() 
--if renoise.song().transport.playing==false then
    --renoise.song().transport.playing=true end
--start_stop_sample_and_loop_oh_my() end}
--
--function stairs()
--local currCol=nil
--local addCol=nil
--currCol=renoise.song().selected_note_column_index
---
--if renoise.song().selected_track.visibile_note_columns and renoise.song().selected_note_column_index == 12   then 
--renoise.song().selected_note_column_index = 1
--end
--
--
--if currCol == renoise.song().selected_track.visible_note_columns
--then renoise.song().selected_track.visible_note_columns = addCol end
--
--renoise.song().selected_note_column_index=currCol+1
--
--end
--renoise.tool():add_keybinding{name="Global:Paketti:Stair",invoke=function() stairs() end}

-------
--[[
function launchApp(appName)
os.execute(appName)
end

function terminalApp(scriptPath)
 local command = 'open -a Terminal "' .. scriptPath .. '"'
    os.execute(command)
end

renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti..:Run Experimental Script",invoke=function() terminalApp("/Users/esaruoho/macOS_EnableScriptingTools.sh") end}
renoise.tool():add_menu_entry{name="Disk Browser Files:Paketti..:Open macOS Terminal",invoke=function() launchApp("open -a Terminal.app") end}
]]--







------
--[[


local key_hold_start = nil
local held_note = nil
local is_filling = false
local mode_active = false
local dialog = nil

-- Timer function to handle note filling
local function check_key_hold()
  if not key_hold_start or not held_note then
    print("DEBUG: Timer running, but no key is being held.")
    return
  end

  local hold_duration = os.clock() - key_hold_start
  if hold_duration >= 1 and not is_filling then
    print("DEBUG: Hold detected. Filling column...")

    is_filling = true
    local song = renoise.song()
    local track_idx = song.selected_track_index
    local line_idx = song.selected_line_index
    local column_idx = song.selected_note_column_index

    if track_idx and line_idx and column_idx then
      local track = song:track(track_idx)
      local note_column = track:line(line_idx):note_column(column_idx)

      if not note_column.is_empty then
        local note_value = note_column.note_value
        local instrument_value = note_column.instrument_value
        local volume_value = note_column.volume_value
        local panning_value = note_column.panning_value
        local delay_value = note_column.delay_value

        print("DEBUG: Filling column with Note Value:", note_value)

        -- Fill the rest of the column
        local pattern = song.selected_pattern
        local num_lines = pattern.number_of_lines
        for i = line_idx + 1, num_lines do
          local target_line = track:line(i)
          local target_column = target_line:note_column(column_idx)
          if target_column then
            target_column.note_value = note_value
            target_column.instrument_value = instrument_value
            target_column.volume_value = volume_value
            target_column.panning_value = panning_value
            target_column.delay_value = delay_value
          end
        end
        print("DEBUG: Filling complete.")
      else
        print("DEBUG: Note column is empty.")
      end
    else
      print("DEBUG: Invalid pattern editor position.")
    end

    -- Reset state
    is_filling = false
    key_hold_start = nil
    held_note = nil
  end
end

-- Key handler for dialog
local function key_handler(dialog, key)
  if key.note then
    if key.state == "pressed" then
      key_hold_start = os.clock()
      held_note = key.note
      print("DEBUG: Key pressed. Note:", key.note, "Start Time:", key_hold_start)
    elseif key.state == "released" then
      key_hold_start = nil
      held_note = nil
      print("DEBUG: Key released.")
    end
  elseif key.name == "esc" then
    dialog:close()
    renoise.tool():remove_timer(check_key_hold)
    print("DEBUG: Dialog closed. Timer stopped.")
  end
end

-- Show dialog to enable key capture
local function show_dialog()
  if dialog and dialog.visible then
    dialog:close()
    renoise.tool():remove_timer(check_key_hold)
    print("DEBUG: Dialog already open. Closing.")
  else
    local vb = renoise.ViewBuilder()
    dialog = renoise.app():show_custom_dialog(
      "Hold-to-Fill Mode",
      vb:text{text="Hold a note to fill the column"},
      key_handler
    )
    renoise.tool():add_timer(check_key_hold, 50)
    print("DEBUG: Dialog opened. Timer started.")
  end
end

-- Add menu entry to toggle the tool
renoise.tool():add_menu_entry{name="Main Menu:Tools:Toggle Hold-to-Fill Mode",invoke=show_dialog}



[[--
local vb = renoise.ViewBuilder()
local dialog = nil

-- Parameters for the wacky filter
local filter_params = {
  chaos = 0.5,
  cutoff = 2000,
  resonance = 0.7
}

-- Function to close dialog with '!'
local function my_keyhandler_func(dialog_key)
  if dialog_key.name == "exclamation" and
     not (dialog_key.modifiers == "shift" or dialog_key.modifiers == "control" or dialog_key.modifiers == "alt") then
    dialog:close()
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end
end

-- Function to export, process, and reimport audio
local function process_audio()
  local song = renoise.song()
  local selection = song.selection_in_pattern
  if not selection then
    renoise.app():show_status("No audio selection found")
    return
  end

  -- Export selected audio to a WAV file
  local sample = song.instruments[1].samples[1]
  local output_path = os.tmpname() .. ".wav"
  sample.sample_buffer:save_as(output_path, "wav")

  -- Run Csound with the wacky filter
  local csound_command = string.format(
    "csound wacky_filter.csd -o %s -i %s -kcutoff %f -kresonance %f -kchaos %f",
    output_path,
    output_path,
    filter_params.cutoff,
    filter_params.resonance,
    filter_params.chaos
  )
  os.execute(csound_command)

  -- Load processed file back into Renoise
  sample.sample_buffer:load_from(output_path)
  renoise.app():show_status("Audio processed and reloaded")
end

-- Create GUI
local function show_dialog()
  if dialog and dialog.visible then
    dialog:close()
    return
  end

  dialog = renoise.app():show_custom_dialog("Wacky Filter", vb:row {
    vb:column {
      vb:slider { min = 0, max = 1, value = filter_params.chaos, notifier = function(v) filter_params.chaos = v end },
      vb:text { text = "Chaos" },
      vb:slider { min = 20, max = 20000, value = filter_params.cutoff, notifier = function(v) filter_params.cutoff = v end },
      vb:text { text = "Cutoff" },
      vb:slider { min = 0.1, max = 10, value = filter_params.resonance, notifier = function(v) filter_params.resonance = v end },
      vb:text { text = "Resonance" },
      vb:button { text = "Process Audio", notifier = process_audio }
    }
  }, keyhandler_wackyfilter)
end

-- Add menu entry to show the dialog
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Xperimental/Work in Progress:Wacky Filter",invoke=show_dialog}

function keyhandler_wackyfilter(dialog,key)
  local closer = preferences.pakettiDialogClose.value
  if key.name == closer then
    dialog:close()
  end
  return key
end


--[[
local sample_buffer_notifier = nil
local is_processing = false
local auto_settings_enabled = true
local last_buffer_size = nil

-- Function to temporarily disable auto settings
function disable_auto_settings()
    auto_settings_enabled = false
    renoise.app():show_status("Paketti Auto Sample Settings: Disabled")
end

-- Function to re-enable auto settings
function enable_auto_settings()
    auto_settings_enabled = true
    renoise.app():show_status("Paketti Auto Sample Settings: Enabled")
end

local function on_sample_buffer_changed()
    local song = renoise.song()
    if not song then return end
    
    local sample = song.selected_sample
    if not sample or not sample.sample_buffer then return end
    
    -- Skip if auto settings are disabled or we're currently processing
    if not auto_settings_enabled or is_processing then
        return
    end
    
    -- Only apply settings when a new sample is loaded (buffer size changes)
    local current_buffer_size = sample.sample_buffer.number_of_frames
    if sample.sample_buffer.has_sample_data and current_buffer_size ~= last_buffer_size then
        is_processing = true
        
        print(string.format("Sample %d - Before: loop_mode=%s, loop_release=%s", 
            song.selected_sample_index, tostring(sample.loop_mode), tostring(sample.loop_release)))
        
        sample.autofade = preferences.pakettiLoaderAutofade.value
        sample.autoseek = preferences.pakettiLoaderAutoseek.value
        sample.loop_mode = preferences.pakettiLoaderLoopMode.value
        sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
        sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
        sample.oneshot = preferences.pakettiLoaderOneshot.value
        sample.new_note_action = preferences.pakettiLoaderNNA.value
        sample.loop_release = preferences.pakettiLoaderLoopExit.value
        
        print(string.format("Sample %d - After: loop_mode=%s, loop_release=%s", 
            song.selected_sample_index, tostring(sample.loop_mode), tostring(sample.loop_release)))
        
        last_buffer_size = current_buffer_size
        is_processing = false
    end
end

local function on_selected_sample_changed()
    local song = renoise.song()
    if not song or not song.selected_sample then
        return
    end

    -- Reset last_buffer_size when changing samples
    last_buffer_size = nil

    -- Handle sample buffer notifier
    if song.selected_sample.sample_buffer_observable:has_notifier(on_sample_buffer_changed) then
        song.selected_sample.sample_buffer_observable:remove_notifier(on_sample_buffer_changed)
    end
    sample_buffer_notifier = song.selected_sample.sample_buffer_observable:add_notifier(on_sample_buffer_changed)
end

-- Setup initial notifiers only when a document is available
local function setup_notifiers()
    local song = renoise.song()
    if not song then return end
    
    -- Handle instrument selection notifier
    if not song.selected_instrument_observable:has_notifier(on_selected_sample_changed) then
        song.selected_instrument_observable:add_notifier(on_selected_sample_changed)
    end
    
    -- Handle sample selection notifier
    if not song.selected_sample_observable:has_notifier(on_selected_sample_changed) then
        song.selected_sample_observable:add_notifier(on_selected_sample_changed)
    end
    
    -- Initial setup of sample buffer notifier
    on_selected_sample_changed()
end

-- Add notifier for when a new document becomes available
renoise.tool().app_new_document_observable:add_notifier(setup_notifiers)

-- Cleanup when tool is unloaded
renoise.tool().app_release_document_observable:add_notifier(function()
    local song = renoise.song()
    if not song then return end
    
    if song.selected_sample and 
       song.selected_sample.sample_buffer_observable:has_notifier(on_sample_buffer_changed) then
        song.selected_sample.sample_buffer_observable:remove_notifier(on_sample_buffer_changed)
    end
    
    if song.selected_instrument_observable:has_notifier(on_selected_sample_changed) then
        song.selected_instrument_observable:remove_notifier(on_selected_sample_changed)
    end
    
    if song.selected_sample_observable:has_notifier(on_selected_sample_changed) then
        song.selected_sample_observable:remove_notifier(on_selected_sample_changed)
    end
    
    last_buffer_size = nil
end)

-- Add menu entries to enable/disable auto settings
renoise.tool():add_menu_entry{
    name = "Main Menu:Tools:Paketti..:Sample Settings:Enable Auto Settings",
    invoke = enable_auto_settings
}

renoise.tool():add_menu_entry{
    name = "Main Menu:Tools:Paketti..:Sample Settings:Disable Auto Settings",
    invoke = disable_auto_settings
}
    ]]--

    --[[renoise.tool():add_keybinding{name="Global:Paketti:Hide EditStep Dialog",
  invoke = function(repeated)
    if not repeated then
      key_handler({name="key_up", modifiers = "alt"})
    end
  end
} ]]--