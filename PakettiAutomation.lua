groove_master_track = nil
--groove_master_device = nil
paketti_automation1_device = nil
paketti_automation2_device = nil

PakettiAutomationDoofer = false

-- Utility Functions
local function set_edit_mode(value)
  local song = renoise.song()
  local edit_mode = value > 0
  song.transport.edit_mode = edit_mode
  if edit_mode then
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  else
    renoise.song().selected_track_index = renoise.song().sequencer_track_count + 1
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
  end
end

-- Local variable to track recording state
local is_recording_active = false

local function set_sample_record(value)
  if value > 80 then
    if not is_recording_active then
      -- Start recording
      renoise.app().window.sample_record_dialog_is_visible = true
      renoise.song().transport:start_stop_sample_recording()
      is_recording_active = true -- Update the state to indicate recording is active
    end
  else
    if is_recording_active then
      renoise.song().transport:start_stop_sample_recording()
      is_recording_active = false -- Update the state to indicate recording has stopped
    end
  end
  
  renoise.app().window.active_middle_frame = 1
end


local function set_pattern_length(value)
  local song = renoise.song()
  local pattern_length = math.floor((value / 100) * (512 - 1) + 1)
  song.selected_pattern.number_of_lines = pattern_length
end

local function set_instrument_pitch(value)
  local song = renoise.song()
  local transpose_value = math.floor((value / 100) * (12 + 12) - 12)
  for i = 1, #song.selected_instrument.samples do
    song.selected_instrument.samples[i].transpose = transpose_value
  end
end

local function placeholder_notifier(index, value)
  renoise.app():show_status("Placeholder" .. index .. " Value: " .. tostring(value))
end

local function set_groove_amount(index, value)
  local song = renoise.song()
  local groove_amounts = song.transport.groove_amounts
  value = math.max(0, math.min(value, 1))
  groove_amounts[index] = value
  song.transport.groove_amounts = groove_amounts
end

local function set_bpm(value)
  local song = renoise.song()
  value = math.max(32, math.min(value, 187))
  song.transport.bpm = value
end

local function set_lpb(value)
  local song = renoise.song()
  value = math.max(1, math.min(value, 32))
  song.transport.lpb = value
end

local function set_edit_step(value)
  local song = renoise.song()
  value = math.floor(value * 64)
  song.transport.edit_step = value
end

local function set_octave(value)
  local song = renoise.song()
  value = math.floor(value * 8)
  song.transport.octave = value
end

local function inject_xml_to_doofer1(device)
  local song = renoise.song()
  local transport = song.transport

  -- Get current values for Groove, BPM, LPB, EditStep, and Octave
  local groove1 = transport.groove_amounts[1] * 100 
  local groove2 = transport.groove_amounts[2] * 100
  local groove3 = transport.groove_amounts[3] * 100
  local groove4 = transport.groove_amounts[4] * 100

  local bpm_value = ((transport.bpm - 32) / (187 - 32)) * 100
  local lpb_value = ((transport.lpb - 1) / (32 - 1)) * 100
  local edit_step_value = (transport.edit_step / 64) * 100
  local octave_value = (transport.octave / 8) * 100

  -- Construct the XML with the dynamic values injected
  local xml_content = string.format([[
<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="13">
  <DeviceSlot type="DooferDevice">
    <IsMaximized>true</IsMaximized>
    <Macro0>
      <Value>%.12f</Value>
      <Name>Groove#1</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>1</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro0>
    <Macro1>
      <Value>%.12f</Value>
      <Name>Groove#2</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>2</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro1>
    <Macro2>
      <Value>%.12f</Value>
      <Name>Groove#3</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>3</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro2>
    <Macro3>
      <Value>%.12f</Value>
      <Name>Groove#4</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>4</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro3>
    <Macro4>
      <Value>%.12f</Value>
      <Name>BPM</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>5</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro4>
    <Macro5>
      <Value>%.12f</Value>
      <Name>EditStep</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>6</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro5>
    <Macro6>
      <Value>%.12f</Value>
      <Name>Octave 0-8</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>7</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro6>
    <Macro7>
      <Value>%.12f</Value>
      <Name>LPB 1-32</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>8</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro7>
    <NumActiveMacros>8</NumActiveMacros>
    <ShowDevices>false</ShowDevices>
    <DeviceChain>
      <SelectedPresetName>Init</SelectedPresetName>
      <SelectedPresetLibrary>Bundled Content</SelectedPresetLibrary>
      <SelectedPresetIsModified>true</SelectedPresetIsModified>
      <Devices>
        <InstrumentAutomationDevice type="InstrumentAutomationDevice">
          <IsMaximized>true</IsMaximized>
          <IsSelected>false</IsSelected>
          <SelectedPresetName>Init</SelectedPresetName>
          <SelectedPresetLibrary>Bundled Content</SelectedPresetLibrary>
          <SelectedPresetIsModified>true</SelectedPresetIsModified>
          <IsActive>
            <Value>1.0</Value>
            <Visualization>Device only</Visualization>
          </IsActive>
          <ParameterNumber0>0</ParameterNumber0>
          <ParameterValue0>
            <Value>0.740513325</Value>
            <Visualization>Device only</Visualization>
          </ParameterValue0>
          <LinkedInstrument>0</LinkedInstrument>
          <VisiblePages>2</VisiblePages>
        </InstrumentAutomationDevice>
      </Devices>
    </DeviceChain>
  </DeviceSlot>
</FilterDevicePreset>
  ]], groove1, groove2, groove3, groove4, bpm_value, edit_step_value, octave_value, lpb_value)

  -- Inject the XML content into the active preset data of the device
  device.active_preset_data = xml_content
  renoise.app():show_status("Dynamic XML content with precise values injected into Paketti Automation.")
end

-- XML Injection Function for "Paketti Automation 2"
local function inject_xml_to_doofer2(device)
  -- Get current pattern length and set instrument pitch to 50%
  local song = renoise.song()
  local pattern_length = ((song.selected_pattern.number_of_lines - 1) / (512 - 1)) * 100
  local instrument_pitch = 50 -- Start at 50%

  local xml_content = string.format([[
<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="13">
  <DeviceSlot type="DooferDevice">
    <IsMaximized>true</IsMaximized>
    <Macro0>
      <Value>74.0513306</Value>
      <Name>EditMode</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>1</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro0>
    <Macro1>
      <Value>0.0</Value>
      <Name>Recorder</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>2</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro1>
    <Macro2>
      <Value>%.2f</Value>
      <Name>PtnLength</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>3</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro2>
    <Macro3>
      <Value>%.2f</Value>
      <Name>InstPitch</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>4</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro3>
    <Macro4>
      <Value>0.0</Value>
      <Name>LoopEnd</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>5</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro4>
    <Macro5>
      <Value>0.0</Value>
      <Name>Placeholder2</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>6</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro5>
    <Macro6>
      <Value>0.0</Value>
      <Name>Placeholder3</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>7</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro6>
    <Macro7>
      <Value>0.0</Value>
      <Name>Placeholder4</Name>
      <Mappings>
        <Mapping>
          <DestDeviceIndex>0</DestDeviceIndex>
          <DestParameterIndex>8</DestParameterIndex>
          <Min>0.0</Min>
          <Max>1.0</Max>
          <Scaling>Linear</Scaling>
        </Mapping>
      </Mappings>
    </Macro7>
    <NumActiveMacros>8</NumActiveMacros>
    <ShowDevices>false</ShowDevices>
    <DeviceChain>
      <SelectedPresetName>Init</SelectedPresetName>
      <SelectedPresetLibrary>Bundled Content</SelectedPresetLibrary>
      <SelectedPresetIsModified>true</SelectedPresetIsModified>
      <Devices>
        <InstrumentAutomationDevice type="InstrumentAutomationDevice">
          <IsMaximized>true</IsMaximized>
          <IsSelected>false</IsSelected>
          <SelectedPresetName>Init</SelectedPresetName>
          <SelectedPresetLibrary>Bundled Content</SelectedPresetLibrary>
          <SelectedPresetIsModified>true</SelectedPresetIsModified>
          <IsActive>
            <Value>1.0</Value>
            <Visualization>Device only</Visualization>
          </IsActive>
          <ParameterNumber0>0</ParameterNumber0>
          <ParameterValue0>
            <Value>0.740513325</Value>
            <Visualization>Device only</Visualization>
          </ParameterValue0>
          <LinkedInstrument>0</LinkedInstrument>
          <VisiblePages>2</VisiblePages>
        </InstrumentAutomationDevice>
      </Devices>
    </DeviceChain>
  </DeviceSlot>
</FilterDevicePreset>
  ]], pattern_length, instrument_pitch)

  -- Inject the XML content into the active preset data of the device
  device.active_preset_data = xml_content
  renoise.app():show_status("XML content injected into Paketti Automation 2.")
end

-- Monitoring Function for "Paketti Automation" (Doofer 1)
function monitor_doofer1_macros(device)
  -- Macro 1 -> Groove 1
  local function macro1_notifier()
    local value=device.parameters[1].value
    set_groove_amount(1, value/100)
  end

  -- Macro 2 -> Groove 2
  local function macro2_notifier()
    local value=device.parameters[2].value
    set_groove_amount(2, value/100)
  end

  -- Macro 3 -> Groove 3
  local function macro3_notifier()
    local value=device.parameters[3].value
    set_groove_amount(3, value/100)
  end

  -- Macro 4 -> Groove 4
  local function macro4_notifier()
    local value=device.parameters[4].value
    set_groove_amount(4, value/100)
  end

  -- Macro 5 -> BPM
  local function macro5_notifier()
    local value=device.parameters[5].value
    local bpm_value=(value/100)*(260-20)+32
    renoise.song().transport.bpm=bpm_value
  end

  -- Macro 6 -> Edit Step
  local function macro6_notifier()
    local value=device.parameters[6].value
    local edit_step_value=math.floor((value/100)*64)
    renoise.song().transport.edit_step=edit_step_value
  end

  -- Macro 7 -> Octave
  local function macro7_notifier()
    local value=device.parameters[7].value
    local octave_value=math.floor((value/100)*8)
    renoise.song().transport.octave=octave_value
  end

  -- Macro 8 -> LPB
  local function macro8_notifier()
    local value=device.parameters[8].value
    local lpb_value=math.floor((value/100)*(32-1)+1)
    renoise.song().transport.lpb=lpb_value
  end

  -- Set up notifiers for Doofer 1
  local macros={
    {index=1, notifier=macro1_notifier},
    {index=2, notifier=macro2_notifier},
    {index=3, notifier=macro3_notifier},
    {index=4, notifier=macro4_notifier},
    {index=5, notifier=macro5_notifier},
    {index=6, notifier=macro6_notifier},
    {index=7, notifier=macro7_notifier},
    {index=8, notifier=macro8_notifier},
  }

  for _,macro in ipairs(macros) do
    local param=device.parameters[macro.index]
    if param.value_observable:has_notifier(macro.notifier) then
      param.value_observable:remove_notifier(macro.notifier)
    end
    param.value_observable:add_notifier(macro.notifier)
  end

  renoise.app():show_status("Notifiers added for groove, BPM, LPB, Edit Step, and Octave control in Paketti Automation.")
end

-- Monitoring Function for "Paketti Automation 2" (Doofer 2)
function monitor_doofer2_macros(device)
  -- Macro 1 -> EditMode
  local function macro1_notifier()
    local value=device.parameters[1].value
    set_edit_mode(value)
  end

  -- Macro 2 -> Sample Record
  local function macro2_notifier()
    local value=device.parameters[2].value
    set_sample_record(value)
    renoise.song().selected_track_index = 1


      local s=renoise.song()
  local currTrak=s.selected_track_index
  local currPatt=s.selected_pattern_index
  local rightinstrument=nil
  local rightinstrument=renoise.song().selected_instrument_index-1

  if preferences._0G01_Loader.value then
    local new_track_index = currTrak + 1
    s:insert_track_at(new_track_index)
    s.selected_track_index = new_track_index
    currTrak = new_track_index
    local line=s.patterns[currPatt].tracks[currTrak].lines[1]
    line.note_columns[1].note_string="C-4"
    line.note_columns[1].instrument_value=rightinstrument
    line.effect_columns[1].number_string="0G"
    line.effect_columns[1].amount_string="01"
      
  end

    
    
  end

  -- Macro 3 -> Pattern Length
  local function macro3_notifier()
    local value=device.parameters[3].value
    set_pattern_length(value)
  end

  -- Macro 4 -> Instrument Pitch
  local function macro4_notifier()
    local value=device.parameters[4].value
    set_instrument_pitch(value)
  end

  -- Macro 5 -> LoopEnd
local function macro5_notifier()
  local song = renoise.song()
  
  local sample = song.selected_sample
  local buffer = sample.sample_buffer
  -- Ensure there's a sample and a valid buffer
  if not sample or not buffer or not buffer.has_sample_data then
    renoise.app():show_status("No valid sample or sample buffer.")
    return
  end

  local value = device.parameters[5].value
  local num_frames = buffer.number_of_frames

  -- Map the macro value (0-100) to loop end position
  local loop_end_position = math.floor((value / 100) * num_frames)

  -- Ensure loop end does not go below 10 or above the sample length
  loop_end_position = math.max(10, math.min(loop_end_position, num_frames))

  -- Set the loop end point
  sample.loop_end = loop_end_position

  -- Optional: Provide feedback on the loop end position
--  renoise.app():show_status("Loop End set to: " .. loop_end_position .. " / " .. num_frames)
end


  -- Macro 6 -> Placeholder2
  local function macro6_notifier()
    local value=device.parameters[6].value
    placeholder_notifier(2, value)
  end

  -- Macro 7 -> Placeholder3
  local function macro7_notifier()
    local value=device.parameters[7].value
    placeholder_notifier(3, value)
  end

  -- Macro 8 -> Placeholder4
  local function macro8_notifier()
    local value=device.parameters[8].value
    placeholder_notifier(4, value)
  end

  -- Set up notifiers for Doofer 2
  local macros={
    {index=1, notifier=macro1_notifier},
    {index=2, notifier=macro2_notifier},
    {index=3, notifier=macro3_notifier},
    {index=4, notifier=macro4_notifier},
    {index=5, notifier=macro5_notifier},
    {index=6, notifier=macro6_notifier},
    {index=7, notifier=macro7_notifier},
    {index=8, notifier=macro8_notifier},
  }

  for _,macro in ipairs(macros) do
    local param=device.parameters[macro.index]
    if param.value_observable:has_notifier(macro.notifier) then
      param.value_observable:remove_notifier(macro.notifier)
    end
    param.value_observable:add_notifier(macro.notifier)
  end

  renoise.app():show_status("Notifiers added for EditMode, Sample Record, Pattern Length, Instrument Pitch, and Placeholders in Paketti Automation 2.")
end

-- Initialization Function
function initialize_doofer(device_name, device_reference, monitor_function, inject_function)
  local song = renoise.song()
  local track = renoise.song().sequencer_track_count + 1
  renoise.song().selected_track_index = track

  -- Check if the device is already present
  if song.selected_track.devices[device_reference] and song.selected_track.devices[device_reference].display_name == device_name then
    monitor_function(song.selected_track.devices[device_reference])
    return
  end

  -- If not present, add the device
  loadnative("Audio/Effects/Native/Doofer")
  local device = song.selected_track.devices[device_reference]
  device.display_name = device_name
  inject_function(device)
  monitor_function(device)
end

-- Main Initialization Function
function initialize_doofer_monitoring()
PakettiAutomationDoofer = true

  if renoise.song().instruments[1].name~="Used for Paketti Automation" then
    renoise.song():insert_instrument_at(1)
    renoise.song().instruments[1].name="Used for Paketti Automation"
  end
  if renoise.song().tracks[renoise.song().sequencer_track_count+1].devices[2] ~= nil and  renoise.song().tracks[renoise.song().sequencer_track_count+1].devices[3] ~= nil then 
  if renoise.song().tracks[renoise.song().sequencer_track_count+1].devices[2].display_name == "Paketti Automation" and renoise.song().tracks[renoise.song().sequencer_track_count+1].devices[3].display_name == "Paketti Automation 2" then
  
  local masterTrack=renoise.song().sequencer_track_count+1
  monitor_doofer2_macros(renoise.song().tracks[masterTrack].devices[3])
  monitor_doofer1_macros(renoise.song().tracks[masterTrack].devices[2])
  return end
else end
  groove_master_track = renoise.song().sequencer_track_count + 1
  initialize_doofer("Paketti Automation 2", 2, monitor_doofer2_macros, inject_xml_to_doofer2)
  initialize_doofer("Paketti Automation", 2, monitor_doofer1_macros, inject_xml_to_doofer1)


PakettiAutomationDoofer = true
end


-- Keybinding for Initialization
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Automation",
  invoke=function() initialize_doofer_monitoring() end}








---------
-- Helper function to handle volume-specific scaling
local function get_volume_value(normalized_position, curve_type)
  local unity_gain = 0.715  -- 0dB point for volume
  
  if curve_type == "exp_up" then
    return math.pow(normalized_position, 3) * unity_gain
  elseif curve_type == "exp_down" then
    return (1 - math.pow(normalized_position, 3)) * unity_gain
  elseif curve_type == "linear_up" then
    return normalized_position * unity_gain
  elseif curve_type == "linear_down" then
    return (1 - normalized_position) * unity_gain
  end
end

--------
local renoise = renoise
local tool = renoise.tool()


function apply_selection_up_linear()
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope or not envelope.selection_range then
    renoise.app():show_status("No automation selection or envelope found.")
    return
  end

  local selection = envelope.selection_range
  local start_line = selection[1]
  local end_line = selection[2]

  if automation_parameter.name == "Volume" then
    envelope:clear_range(start_line, end_line)
    -- Add points for each line to ensure complete coverage
    for i = start_line, end_line do
      local normalizedPosition = (i - start_line) / (end_line - start_line)
      local value = normalizedPosition * 0.715  -- Linear interpolation to unity gain
      envelope:add_point_at(i, value)
    end
  else
    envelope:clear_range(start_line, end_line)
    for i = start_line, end_line do
      local normalizedPosition = (i - start_line) / (end_line - start_line)
      local value = normalizedPosition
      envelope:add_point_at(i, value)
    end
  end

  print("Selection Up Linear applied:")
  print("Start Line: " .. start_line .. ", Value: " .. automation_parameter.value_min)
  print("End Line: " .. end_line .. ", Value: 1.0")
end

local renoise = renoise
local tool = renoise.tool()



function apply_selection_down_linear()
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope or not envelope.selection_range then
    renoise.app():show_status("No automation selection or envelope found.")
    return
  end

  local selection = envelope.selection_range
  local start_line = selection[1]
  local end_line = selection[2]

  if automation_parameter.name == "Volume" then
    envelope:clear_range(start_line, end_line)
    -- Add points for each line to ensure complete coverage
    for i = start_line, end_line do
      local normalizedPosition = (i - start_line) / (end_line - start_line)
      local value = (1 - normalizedPosition) * 0.715  -- Linear interpolation from unity gain to zero
      envelope:add_point_at(i, value)
    end
  else
    envelope:clear_range(start_line, end_line)
    for i = start_line, end_line do
      local normalizedPosition = (i - start_line) / (end_line - start_line)
      local value = 1 - normalizedPosition
      envelope:add_point_at(i, value)
    end
  end

  print("Selection Down Linear applied:")
  print("Start Line: " .. start_line .. ", Value: 1.0")
  print("End Line: " .. end_line .. ", Value: " .. automation_parameter.value_min)
end

local renoise = renoise
local tool = renoise.tool()

function apply_constant_automation_top_to_top(type)
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope or not envelope.selection_range then
    renoise.app():show_status("No automation selection or envelope found.")
    return
  end

  local selection = envelope.selection_range
  local start_line = selection[1]
  local end_line = selection[2]

  envelope:clear_range(start_line, end_line)
  envelope:add_point_at(start_line, 1.0)
  envelope:add_point_at(start_line + 1, 1.0)  -- A tick after start
  envelope:add_point_at(end_line - 1, 1.0)  -- Just before end
  envelope:add_point_at(end_line, 1.0)
end

local renoise = renoise
local tool = renoise.tool()



function apply_constant_automation_bottom_to_bottom(type)
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope or not envelope.selection_range then
    renoise.app():show_status("No automation selection or envelope found.")
    return
  end

  local selection = envelope.selection_range
  local start_line = selection[1]
  local end_line = selection[2]

  envelope:clear_range(start_line, end_line)
  envelope:add_point_at(start_line, 0.0)
  envelope:add_point_at(start_line + 1, 0.0)  -- A tick after start
  envelope:add_point_at(end_line - 1, 0.0)  -- Just before end
  envelope:add_point_at(end_line, 0.0)
end






local renoise = renoise
local tool = renoise.tool()

function apply_exponential_automation_curve_top_to_center(type)
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter

  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope or not envelope.selection_range then
    renoise.app():show_status("No automation selection or envelope found.")
    return
  end

  local selection = envelope.selection_range
  local start_line = selection[1]
  local end_line = selection[2]

  print("Automation from line " .. start_line .. " to " .. end_line)  -- Debug for range

  envelope:clear_range(start_line, end_line)

  local k = 6  -- Steepness factor
  for i = start_line, end_line do
    local normalizedPosition = (i - start_line) / (end_line - start_line)
    local value = 1.0 - 0.5 * (1 - math.exp(-k * normalizedPosition))  -- Adjusted for decay starting at 1.0
    envelope:add_point_at(i, value)
    print("Adding point at line " .. i .. " with value " .. value)  -- Debug print
  end

  -- Explicitly set the last point at end_line to 0.5
  envelope:add_point_at(end_line, 0.5)
  print("Explicitly setting final point at line " .. end_line .. " with value 0.5")  -- Debug print for the final point
end







local renoise = renoise
local tool = renoise.tool()


function apply_exponential_automation_curve_bottom_to_center(type)
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope or not envelope.selection_range then
    renoise.app():show_status("No automation selection or envelope found.")
    return
  end

  local selection = envelope.selection_range
  local start_line = selection[1]
  local end_line = selection[2]

  print("Automation from line " .. start_line .. " to " .. end_line)  -- Debug for range

  envelope:clear_range(start_line, end_line)

  local k = 6  -- Steepness factor
  -- We make sure to include the last index by going up to end_line
  for i = start_line, end_line do
    local normalizedPosition = (i - start_line) / (end_line - start_line)
    local value = 0.5 * (1 - math.exp(-k * normalizedPosition))
    envelope:add_point_at(i, value)
    print("Adding point at line " .. i .. " with value " .. value)  -- Debug print
  end
  
    -- Explicitly set the last point at end_line to 0.5
  envelope:add_point_at(end_line, 0.5)
  print("Explicitly setting final point at line " .. end_line .. " with value 0.5")  -- Debug print for the final point

end






local renoise = renoise
local tool = renoise.tool()

function apply_exponential_automation_curve_center_to_bottom(type)
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope or not envelope.selection_range then
    renoise.app():show_status("No automation selection or envelope found.")
    return
  end

  local selection = envelope.selection_range
  local start_line = selection[1]
  local end_line = selection[2]

  envelope:clear_range(start_line, end_line)

  local k = 3
  local exp_k = math.exp(k)
  local denominator = exp_k - 1

  for i = start_line, end_line - 1 do  -- Loop until the second last point
    local normalizedPosition = (i - start_line) / (end_line - start_line)
    local exp_value = (math.exp(k * normalizedPosition) - 1) / denominator
    local value = 0.5 - 0.5 * exp_value

    -- Debug print statement
    print(string.format("Line: %d, NormalizedPosition: %.4f, Value: %.4f", i, normalizedPosition, value))

    envelope:add_point_at(i, value)
  end
  envelope:add_point_at(end_line, 0.0)  -- Explicitly set the last point to 0.0
end



local renoise = renoise
local tool = renoise.tool()


local renoise = renoise
local tool = renoise.tool()

function apply_exponential_automation_curve_center_to_top(type)
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope or not envelope.selection_range then
    renoise.app():show_status("No automation selection or envelope found.")
    return
  end

  local selection = envelope.selection_range
  local start_line = selection[1]
  local end_line = selection[2]

  envelope:clear_range(start_line, end_line)

  local k = 3
  local exp_k = math.exp(k)
  local denominator = exp_k - 1

  for i = start_line, end_line - 1 do  -- Loop until the second last point
    local normalizedPosition = (i - start_line) / (end_line - start_line)
    local exp_value = (math.exp(k * normalizedPosition) - 1) / denominator
    local value = 0.5 + 0.5 * exp_value

    -- Debug print statement
    print(string.format("Line: %d, NormalizedPosition: %.4f, Value: %.4f", i, normalizedPosition, value))

    envelope:add_point_at(i, value)
  end
  envelope:add_point_at(end_line, 1.0)  -- Explicitly set the last point to 1.0
end







local renoise = renoise
local tool = renoise.tool()




function apply_exponential_automation_curveDOWN(type)
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope or not envelope.selection_range then
    renoise.app():show_status("No automation selection or envelope found.")
    return
  end

  local selection = envelope.selection_range
  local start_line = selection[1]
  local end_line = selection[2]

  print("Selection start: " .. start_line .. ", end: " .. end_line)  -- Debug for selection range

  envelope:clear_range(start_line, end_line)

  local k = 3  -- Adjust this value to change the steepness of the curve
  if automation_parameter.name == "Volume" then
    for i = start_line, end_line do
      local normalizedPosition = (i - start_line) / (end_line - start_line)
      local value = get_volume_value(normalizedPosition, "exp_down")
      envelope:add_point_at(i, value)
    end
  else

  for i = start_line, end_line do
    local normalizedPosition = (i - start_line) / (end_line - start_line)
    local value = 1 - (math.exp(k * normalizedPosition) / math.exp(k))  -- Using exponential decay
    envelope:add_point_at(i, value)
    print("Adding point at line " .. i .. " with value " .. value)  -- Debug print
  end
end 
  -- Explicitly setting the last point to ensure it hits exactly 0.0
  envelope:add_point_at(end_line, 0.0)
  print("Explicitly setting final point at line " .. end_line .. " with value 0.0")  -- Debug print for the final point
end



-- Selection up EXP
local renoise = renoise
local tool = renoise.tool()

function apply_exponential_automation_curveUP()
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope or not envelope.selection_range then
    renoise.app():show_status("No automation selection or envelope found.")
    return
  end

  local selection = envelope.selection_range
  local start_line = selection[1]
  local end_line = selection[2]

  envelope:clear_range(start_line, end_line)

  local k = 3  -- Adjust this value to change the steepness of the curve
  
  if automation_parameter.name == "Volume" then
    for i = start_line, end_line do
      local normalizedPosition = (i - start_line) / (end_line - start_line)
      local value = get_volume_value(normalizedPosition, "exp_up")
      envelope:add_point_at(i, value)
    end
  else
    for i = start_line, end_line do
      local normalizedPosition = (i - start_line) / (end_line - start_line)
      local value = (math.exp(k * normalizedPosition)) / (math.exp(k))
      envelope:add_point_at(i, value)
    end
  end
end
--------
-------- linear uplocal renoise = renoise
local renoise = renoise
local tool = renoise.tool()



local menu_entries = {
  {"--Track Automation:Paketti..:Automation Curves..:Selection Center->Up (Linear)", "center_up_linear"},
  {"Track Automation:Paketti..:Automation Curves..:Selection Center->Down (Linear)", "center_down_linear"},
  {"Track Automation:Paketti..:Automation Curves..:Selection Up->Center (Linear)", "up_center_linear"},
  {"Track Automation:Paketti..:Automation Curves..:Selection Down->Center (Linear)", "down_center_linear"}
}

renoise.tool():add_menu_entry({name="Track Automation:Paketti..:Automation Curves..:Top to Top",
invoke=function() apply_constant_automation_top_to_top() end})
renoise.tool():add_menu_entry({name="Track Automation:Paketti..:Automation Curves..:Bottom to Bottom",
invoke=function() apply_constant_automation_bottom_to_bottom() end})
renoise.tool():add_menu_entry({name="--Track Automation:Paketti..:Automation Curves..:Selection Up (Exp)",
invoke=function() apply_exponential_automation_curveUP() end})
renoise.tool():add_menu_entry({name="Track Automation:Paketti..:Automation Curves..:Selection Up (Linear)",
invoke=function() apply_selection_up_linear() end})
renoise.tool():add_menu_entry({name="Track Automation:Paketti..:Automation Curves..:Selection Down (Exp)",
invoke=function() apply_exponential_automation_curveDOWN() end})
renoise.tool():add_menu_entry({name="Track Automation:Paketti..:Automation Curves..:Selection Down (Linear)",
invoke=function() apply_selection_down_linear() end})
renoise.tool():add_menu_entry({name="--Track Automation:Paketti..:Automation Curves..:Center to Top (Exp)",
invoke=function() apply_exponential_automation_curve_center_to_top() end})
renoise.tool():add_menu_entry({name="Track Automation:Paketti..:Automation Curves..:Center to Bottom (Exp)",
invoke=function() apply_exponential_automation_curve_center_to_bottom() end})
renoise.tool():add_menu_entry({name="Track Automation:Paketti..:Automation Curves..:Top to Center (Exp)",
invoke=function() apply_exponential_automation_curve_top_to_center() end})
renoise.tool():add_menu_entry({name="Track Automation:Paketti..:Automation Curves..:Bottom to Center (Exp)",
invoke=function() apply_exponential_automation_curve_bottom_to_center() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Top to Top",
invoke=function() apply_constant_automation_top_to_top() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Bottom to Bottom",
invoke=function() apply_constant_automation_bottom_to_bottom() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Selection Up (Exp)",
invoke=function() apply_exponential_automation_curveUP() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Selection Up (Linear)",
invoke=function() apply_selection_up_linear() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Selection Down (Exp)",
invoke=function() apply_exponential_automation_curveDOWN() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Selection Down (Linear)",
invoke=function() apply_selection_down_linear() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Center to Top (Exp)",
invoke=function() apply_exponential_automation_curve_center_to_top() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Center to Bottom (Exp)",
invoke=function() apply_exponential_automation_curve_center_to_bottom() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Top to Center (Exp)",
invoke=function() apply_exponential_automation_curve_top_to_center() end})
renoise.tool():add_menu_entry({name="Pattern Matrix:Paketti..:Automation Curves..:Bottom to Center (Exp)",
invoke=function() apply_exponential_automation_curve_bottom_to_center() end})


for _, entry in ipairs(menu_entries) do tool:add_menu_entry({name=entry[1],invoke=function() apply_linear_automation_curveCenter(entry[2]) end})
end

-- Create the linear automation functions
function center_up_linear()
  apply_linear_automation_curveCenter("center_up_linear")
end

function center_down_linear()
  apply_linear_automation_curveCenter("center_down_linear")
end

function up_center_linear()
  apply_linear_automation_curveCenter("up_center_linear")
end

function down_center_linear()
  apply_linear_automation_curveCenter("down_center_linear")
end



function apply_linear_automation_curveCenter(type)
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope or not envelope.selection_range then
    renoise.app():show_status("No automation selection or envelope found.")
    return
  end

  local selection = envelope.selection_range
  local start_line = selection[1]
  local end_line = selection[2]
  local mid_val = (automation_parameter.value_min + automation_parameter.value_max) / 2

  envelope:clear_range(start_line, end_line)

  if type == "center_up_linear" then
    envelope:add_point_at(start_line, mid_val)
    envelope:add_point_at(end_line, automation_parameter.value_max)
  elseif type == "center_down_linear" then
    envelope:add_point_at(start_line, mid_val)
    envelope:add_point_at(end_line, automation_parameter.value_min)
  elseif type == "up_center_linear" then
    envelope:add_point_at(start_line, automation_parameter.value_max)
    envelope:add_point_at(end_line, mid_val)
  elseif type == "down_center_linear" then
    envelope:add_point_at(start_line, automation_parameter.value_min)
    envelope:add_point_at(end_line, mid_val)
  end
end





--set to center
local renoise = renoise
local tool = renoise.tool()

tool:add_menu_entry({name="--Track Automation:Paketti..:Automation Curves..:Set to Center",
  invoke=function() set_to_center() end
})

function set_to_center()
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope or not envelope.selection_range then
    renoise.app():show_status("No automation selection or envelope found.")
    return
  end

  local selection = envelope.selection_range
  local start_line = selection[1]
  local end_line = selection[2]
  local mid_val = (automation_parameter.value_min + automation_parameter.value_max) / 2

  envelope:clear_range(start_line, end_line)
  envelope:add_point_at(start_line, mid_val)
  envelope:add_point_at(end_line, mid_val)
end

function openExternalInstrumentEditor()
local pd=renoise.song().selected_instrument.plugin_properties.plugin_device
local w=renoise.app().window
    if renoise.song().selected_instrument.plugin_properties.plugin_loaded==false then
    --w.pattern_matrix_is_visible = false
    --w.sample_record_dialog_is_visible = false
    --w.upper_frame_is_visible = true
    --w.lower_frame_is_visible = true
    --w.active_upper_frame = 1
    --w.active_middle_frame= 4
    --w.active_lower_frame = 1 -- TrackDSP
    -- w.lock_keyboard_focus=true
    renoise.app():show_status("There is no Plugin in the Selected Instrument Slot, doing nothing.")
    else
     if pd.external_editor_visible==false then pd.external_editor_visible=true else pd.external_editor_visible=false end
     end
end

renoise.tool():add_menu_entry{name="--Track Automation:Paketti..:Open External Editor for Plugin",invoke=function() openExternalInstrumentEditor() end}



function AutomationDeviceShowUI()
if renoise.song().selected_automation_device.external_editor_available ~= false then
if renoise.song().selected_automation_device.external_editor_visible
then renoise.song().selected_automation_device.external_editor_visible=false
else
renoise.song().selected_automation_device.external_editor_visible=true
end
else 
renoise.app():show_status("The selected automation device does not have an External Editor available, doing nothing.")
end
end

renoise.tool():add_menu_entry{name="Track Automation List:Paketti..:Show/Hide External Editor for Device",invoke=function() AutomationDeviceShowUI() end}
renoise.tool():add_menu_entry{name="Track Automation List:Paketti..:Show/Hide External Editor for Plugin",invoke=function() openExternalInstrumentEditor() end}
renoise.tool():add_menu_entry{name="--Track Automation:Paketti..:Show/Hide External Editor for Device",invoke=function() AutomationDeviceShowUI() end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti..:Show/Hide External Editor for Plugin",invoke=function() openExternalInstrumentEditor() end}






-- 
function showAutomationHard()

if renoise.app().window.active_middle_frame == 5 then renoise.app().window.active_middle_frame = 1
renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
return
end

if renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
then
renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
return
end

if renoise.app().window.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
and renoise.app().window.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_MIXER
then renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
else end
renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
end

renoise.tool():add_keybinding{name="Global:Paketti:Switch to Automation",invoke=function() showAutomationHard() end}





-- Show automation (via Pattern Matrix/Pattern Editor)
function showAutomation()
  local w=renoise.app().window
  local raw=renoise.ApplicationWindow
  local wamf = renoise.app().window.active_middle_frame
  if wamf==1 and renoise.app().window.lower_frame_is_visible==false then w.active_lower_frame = raw.LOWER_FRAME_TRACK_AUTOMATION return else end
 
  if (wamf==raw.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR)
 or (wamf==raw.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR)
 or (wamf==raw.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES)
 or (wamf==raw.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR)
 or (wamf==raw.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION)
 or (wamf==raw.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS)
 or (wamf==raw.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR)
 or (wamf==raw.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR) 
  then renoise.app().window.active_middle_frame=1 
  w.active_lower_frame = raw.LOWER_FRAME_TRACK_AUTOMATION
  return else end
if w.active_lower_frame == raw.LOWER_FRAME_TRACK_AUTOMATION 
then w.active_lower_frame = raw.LOWER_FRAME_TRACK_DSPS return end  
    w.active_lower_frame = raw.LOWER_FRAME_TRACK_AUTOMATION
    w.lock_keyboard_focus=true
    renoise.song().transport.follow_player=false end

renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti..:Switch to Automation",invoke=function() showAutomation() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Switch to Automation",invoke=function() showAutomation() end}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Switch to Automation",invoke=function() showAutomation() end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Switch to Automation",invoke=function() showAutomation() end}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show Automation",invoke=function() renoise.app().window.active_lower_frame=renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
 end}
 renoise.tool():add_keybinding{name="Mixer:Paketti:Show Automation",invoke=function() renoise.app().window.active_lower_frame=renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
 end}
renoise.tool():add_keybinding{name="Instrument Box:Paketti:Show Automation",invoke=function() renoise.app().window.active_lower_frame=renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
 end}
-----------
-- Draw Automation curves, lines, within Automation Selection.

-------------------------------------------------------
-- Function to read the selected slots in the pattern matrix for the currently selected track.
local function read_pattern_matrix_selection()
  local song = renoise.song()
  local sequencer = song.sequencer
  local track_index = song.selected_track_index
  local selected_slots = {}
  local total_patterns = #sequencer.pattern_sequence

  -- Loop through the sequence slots and check selection status for the selected track
  for sequence_index = 1, total_patterns do
    if sequencer:track_sequence_slot_is_selected(track_index, sequence_index) then
      table.insert(selected_slots, sequence_index)
    end
  end

  return selected_slots
end

-- Helper function to get or create automation
local function get_or_create_automation(parameter, pattern_index, track_index)
  local automation = renoise.song().patterns[pattern_index].tracks[track_index]:find_automation(parameter)
  if automation then
    automation:clear()  -- Clear existing automation
  else
    automation = renoise.song().patterns[pattern_index].tracks[track_index]:create_automation(parameter)
  end
  return automation
end

-- Clamp a value to the range [0, 1]
local function clamp(value)
  return math.max(0.0, math.min(1.0, value))
end

-- Function to apply ramp to selected automation
local function apply_ramp(selected_slots, ramp_type, is_exp, is_up)
  local song = renoise.song()
  local track_index = song.selected_track_index
  local selected_parameter = song.selected_automation_parameter

  if not selected_parameter then
    renoise.app():show_status("No automation lane selected.")
    return
  end

  -- Calculate total length of selected patterns
  local total_length = 0
  local pattern_lengths = {}
  for _, sequence_index in ipairs(selected_slots) do
    local pattern_index = song.sequencer.pattern_sequence[sequence_index]
    local pattern_length = song.patterns[pattern_index].number_of_lines
    pattern_lengths[#pattern_lengths + 1] = pattern_length
    total_length = total_length + pattern_length
  end

  -- Set up exponential or linear ramp
  local curve = is_exp and 1.1 or 1.0
  local max_value = math.pow(curve, total_length - 1)
  local unity_gain = 0.715  -- ADD THIS LINE

  -- Apply the ramp to the automation parameter
  local current_position = 0
  for idx, sequence_index in ipairs(selected_slots) do
    local pattern_index = song.sequencer.pattern_sequence[sequence_index]
    local pattern_length = pattern_lengths[idx]
    local envelope = get_or_create_automation(selected_parameter, pattern_index, track_index)

    -- Clear the envelope and apply the ramp
    envelope:clear()

    for line = 0, pattern_length - 1 do
      local global_position = current_position + line
      local normalized_value

  -- Around line 1439, modify the normalized_value calculation:
      if selected_parameter.name == "Volume" then
        if is_exp then
          normalized_value = math.pow(curve, global_position)
          normalized_value = (normalized_value - 1) / (max_value - 1)
          normalized_value = normalized_value * unity_gain  -- Scale to unity gain
        else
          normalized_value = (global_position / (total_length - 1)) * unity_gain
        end
      else
        if is_exp then
          -- Original exponential calculation
          normalized_value = math.pow(curve, global_position)
          normalized_value = (normalized_value - 1) / (max_value - 1)
        else
          -- Original linear calculation
          normalized_value = global_position / (total_length - 1)
        end
      end

      -- Clamp the value to the [0, 1] range
      normalized_value = clamp(is_up and normalized_value or 1 - normalized_value)

      -- Apply the point to the envelope
      envelope:add_point_at(line + 1, normalized_value)
    end

    -- Update position for the next pattern
    current_position = current_position + pattern_length
  end

  renoise.app():show_status(ramp_type .. " ramp applied to selected automation.")
end

-- Wrapper functions for the different ramp operations
function automation_volume_ramp_up_exp()
  local selected_slots = read_pattern_matrix_selection()
  apply_ramp(selected_slots, "Exponential Volume Up", true, true)
end

function automation_volume_ramp_down_exp()
  local selected_slots = read_pattern_matrix_selection()
  apply_ramp(selected_slots, "Exponential Volume Down", true, false)
end

function automation_volume_ramp_up_lin()
  local selected_slots = read_pattern_matrix_selection()
  apply_ramp(selected_slots, "Linear Volume Up", false, true)
end

function automation_volume_ramp_down_lin()
  local selected_slots = read_pattern_matrix_selection()
  apply_ramp(selected_slots, "Linear Volume Down", false, false)
end

-- Automation ramps based on selected automation lane
function automation_ramp_up_exp()
  local selected_slots = read_pattern_matrix_selection()
  apply_ramp(selected_slots, "Exponential Automation Up", true, true)
end

function automation_ramp_down_exp()
  local selected_slots = read_pattern_matrix_selection()
  apply_ramp(selected_slots, "Exponential Automation Down", true, false)
end

function automation_ramp_up_lin()
  local selected_slots = read_pattern_matrix_selection()
  apply_ramp(selected_slots, "Linear Automation Up", false, true)
end

function automation_ramp_down_lin()
  local selected_slots = read_pattern_matrix_selection()
  apply_ramp(selected_slots, "Linear Automation Down", false, false)
end

-- Optimized `menu_entry` and `key_binding` definitions for compactness
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Automation Ramp Up (Exp) for Pattern Matrix Selection",invoke=automation_ramp_up_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Ramp Down (Exp) for Pattern Matrix Selection",invoke=automation_ramp_down_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Ramp Up (Lin) for Pattern Matrix Selection",invoke=automation_ramp_up_lin }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Ramp Down (Lin) for Pattern Matrix Selection",invoke=automation_ramp_down_lin }

renoise.tool():add_keybinding{name="Global:Paketti:Automation Ramp Up (Exp)",invoke=automation_ramp_up_exp }
renoise.tool():add_keybinding{name="Global:Paketti:Automation Ramp Down (Exp)",invoke=automation_ramp_down_exp }
renoise.tool():add_keybinding{name="Global:Paketti:Automation Ramp Up (Lin)",invoke=automation_ramp_up_lin }
renoise.tool():add_keybinding{name="Global:Paketti:Automation Ramp Down (Lin)",invoke=automation_ramp_down_lin }

-- Whitelist of center-based automation parameters
local center_based_parameters = {
  ["X_Pitchbend"] = true,
  ["Panning"] = true,
  ["Pitchbend"] = true
}

-- Function to apply special center-based ramp for certain parameters (linear and exponential)
local function apply_center_based_ramp(selected_slots, ramp_type, is_up, is_exp)
  local song = renoise.song()
  local track_index = song.selected_track_index
  local selected_parameter = song.selected_automation_parameter

  if not selected_parameter then
    renoise.app():show_status("No automation lane selected.")
    return
  end

  -- Check if the selected parameter is in the center-based whitelist
  if not center_based_parameters[selected_parameter.name] then
    renoise.app():show_status("Selected parameter is not center-based.")
    return
  end

  -- Calculate total length of selected patterns
  local total_length = 0
  local pattern_lengths = {}
  for _, sequence_index in ipairs(selected_slots) do
    local pattern_index = song.sequencer.pattern_sequence[sequence_index]
    local pattern_length = song.patterns[pattern_index].number_of_lines
    pattern_lengths[#pattern_lengths + 1] = pattern_length
    total_length = total_length + pattern_length
  end

  -- Set up the exponential or linear ramp (0.5 based)
  local curve = is_exp and 1.1 or 1
  local max_value = math.pow(curve, total_length - 1)

  -- Apply the ramp to the automation parameter
  local current_position = 0
  for idx, sequence_index in ipairs(selected_slots) do
    local pattern_index = song.sequencer.pattern_sequence[sequence_index]
    local pattern_length = pattern_lengths[idx]
    local envelope = get_or_create_automation(selected_parameter, pattern_index, track_index)

    -- Clear the envelope and apply the ramp
    envelope:clear()

    for line = 0, pattern_length - 1 do
      local global_position = current_position + line
      local normalized_value

      -- Linear interpolation
      if not is_exp then
        local t = global_position / (total_length - 1)
        if ramp_type == "Top to Center" then
          normalized_value = 1.0 - (t * 0.5) -- 1.0 to 0.5
        elseif ramp_type == "Bottom to Center" then
          normalized_value = t * 0.5 -- 0.0 to 0.5
        elseif ramp_type == "Center to Top" then
          normalized_value = 0.5 + (t * 0.5) -- 0.5 to 1.0
        elseif ramp_type == "Center to Bottom" then
          normalized_value = 0.5 - (t * 0.5) -- 0.5 to 0.0
        end
      else
        -- Exponential interpolation
        normalized_value = math.pow(curve, global_position)
        normalized_value = (normalized_value - 1) / (max_value - 1)
        if ramp_type == "Top to Center" then
          normalized_value = 1.0 - (normalized_value * 0.5) -- 1.0 to 0.5
        elseif ramp_type == "Bottom to Center" then
          normalized_value = normalized_value * 0.5 -- 0.0 to 0.5
        elseif ramp_type == "Center to Top" then
          normalized_value = 0.5 + (normalized_value * 0.5) -- 0.5 to 1.0
        elseif ramp_type == "Center to Bottom" then
          normalized_value = 0.5 - (normalized_value * 0.5) -- 0.5 to 0.0
        end
      end

      -- Ensure the normalized_value is within valid bounds
      normalized_value = math.max(0, math.min(1, normalized_value))

      -- Apply the point to the envelope
      envelope:add_point_at(line + 1, normalized_value)
    end

    -- Update position for the next pattern
    current_position = current_position + pattern_length
  end

  renoise.app():show_status(ramp_type .. " center-based ramp applied to selected automation.")
end

-- Special center-based ramp operations (Exponential and Linear)
function automation_center_to_top_exp() apply_center_based_ramp(read_pattern_matrix_selection(), "Center to Top", true, true) end
 function automation_top_to_center_exp() apply_center_based_ramp(read_pattern_matrix_selection(), "Top to Center", false, true) end
 function automation_center_to_bottom_exp() apply_center_based_ramp(read_pattern_matrix_selection(), "Center to Bottom", false, true) end
 function automation_bottom_to_center_exp() apply_center_based_ramp(read_pattern_matrix_selection(), "Bottom to Center", true, true) end

 function automation_center_to_top_lin() apply_center_based_ramp(read_pattern_matrix_selection(), "Center to Top", true, false) end
 function automation_top_to_center_lin() apply_center_based_ramp(read_pattern_matrix_selection(), "Top to Center", false, false) end
 function automation_center_to_bottom_lin() apply_center_based_ramp(read_pattern_matrix_selection(), "Center to Bottom", false, false) end
 function automation_bottom_to_center_lin() apply_center_based_ramp(read_pattern_matrix_selection(), "Bottom to Center", true, false) end

-- Register menu entries and keybindings for all 8 center-based automations
renoise.tool():add_menu_entry{name="--Pattern Matrix:Paketti..:Automation Center to Top (Exp) for Pattern Matrix Selection",invoke=automation_center_to_top_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Top to Center (Exp) for Pattern Matrix Selection",invoke=automation_top_to_center_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Center to Bottom (Exp) for Pattern Matrix Selection",invoke=automation_center_to_bottom_exp }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Bottom to Center (Exp) for Pattern Matrix Selection",invoke=automation_bottom_to_center_exp }

renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Center to Top (Lin) for Pattern Matrix Selection",invoke=automation_center_to_top_lin }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Top to Center (Lin) for Pattern Matrix Selection",invoke=automation_top_to_center_lin }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Center to Bottom (Lin) for Pattern Matrix Selection",invoke=automation_center_to_bottom_lin }
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Automation Bottom to Center (Lin) for Pattern Matrix Selection",invoke=automation_bottom_to_center_lin }

renoise.tool():add_keybinding{name="Global:Paketti:Automation Center to Top (Exp)",invoke=automation_center_to_top_exp }
renoise.tool():add_keybinding{name="Global:Paketti:Automation Top to Center (Exp)",invoke=automation_top_to_center_exp }
renoise.tool():add_keybinding{name="Global:Paketti:Automation Center to Bottom (Exp)",invoke=automation_center_to_bottom_exp }
renoise.tool():add_keybinding{name="Global:Paketti:Automation Bottom to Center (Exp)",invoke=automation_bottom_to_center_exp }

renoise.tool():add_keybinding{name="Global:Paketti:Automation Center to Top (Lin)",invoke=automation_center_to_top_lin }
renoise.tool():add_keybinding{name="Global:Paketti:Automation Top to Center (Lin)",invoke=automation_top_to_center_lin }
renoise.tool():add_keybinding{name="Global:Paketti:Automation Center to Bottom (Lin)",invoke=automation_center_to_bottom_lin }
renoise.tool():add_keybinding{name="Global:Paketti:Automation Bottom to Center (Lin)",invoke=automation_bottom_to_center_lin }

function randomize_envelope()
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    print("No automatable parameter selected.")
    return
  end

  local track_automation = song:pattern(song.selected_pattern_index):track(song.selected_track_index)
  local envelope = track_automation:find_automation(automation_parameter)
  local pattern_length = song:pattern(song.selected_pattern_index).number_of_lines
  local selection = envelope and envelope.selection_range

  -- Helper to ensure line is valid
  local function validate_line(line)
    if pattern_length == 512 and line > 512 then
      return 512 -- Cap it at 512 if the pattern length is the maximum allowed
    end
    return math.min(math.max(1, line), pattern_length)
  end

  if not envelope then
    envelope = track_automation:create_automation(automation_parameter)
    print("Created new automation envelope for parameter: " .. automation_parameter.name)
    for line = 1, pattern_length do
      envelope:add_point_at(validate_line(line), math.random())
    end
    renoise.app():show_status("Filled new envelope across entire pattern with random values.")
    print("Randomized entire pattern with random values.")
    return
  end

  if selection then
    local start_line, end_line = selection[1], selection[2]
    start_line = validate_line(start_line)
    end_line = validate_line(end_line)
    for line = start_line, end_line do
      envelope:add_point_at(validate_line(line), math.random())
    end
    renoise.app():show_status("Randomized automation points within selected range.")
    print("Randomized selection range from line " .. start_line .. " to line " .. end_line)
    return
  end

  envelope:clear()
  for line = 1, pattern_length do
    envelope:add_point_at(validate_line(line), math.random())
  end
  renoise.app():show_status("Randomized entire existing envelope across pattern.")
  print("Randomized entire existing envelope across the pattern.")
end

renoise.tool():add_keybinding{name="Global:Paketti:Randomize Automation Envelope",invoke=randomize_envelope}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Automation..:Randomize Automation Envelope",invoke=randomize_envelope}
renoise.tool():add_menu_entry{name="--Track Automation:Paketti..:Randomize Automation Envelope",invoke=randomize_envelope}
renoise.tool():add_midi_mapping{name="Paketti:Randomize Automation Envelope",invoke=randomize_envelope}

---
local function randomize_device_envelopes(start_param)
  local song = renoise.song()
  local selected_device = song.selected_track.devices[song.selected_device_index]

  if not selected_device then
    renoise.app():show_status("Please select a device.")
    print("No device selected.")
    return
  end

  start_param = start_param or 1
  local pattern_length = song:pattern(song.selected_pattern_index).number_of_lines
  local track_automation = song:pattern(song.selected_pattern_index):track(song.selected_track_index)

  for i = start_param, #selected_device.parameters do
    local parameter = selected_device.parameters[i]
    
    if parameter.is_automatable then
      local envelope = track_automation:find_automation(parameter)
      
      -- Create or clear the envelope
      if not envelope then
        envelope = track_automation:create_automation(parameter)
  --      print("Created new automation envelope for parameter: " .. parameter.name)
      else
        envelope:clear()
      end
      
      -- Fill the envelope with random values across the pattern length
      for line = 1, pattern_length do
        envelope:add_point_at(line, math.random())
      end
      
 --     print("Randomized entire envelope for parameter: " .. parameter.name)
    else
 --     print("Parameter " .. parameter.name .. " is not automatable, skipping.")
    end
  end

  renoise.app():show_status("Randomized Automation Envelopes for Each Parameter of Selected Device.")
end

-- Keybinding, menu, and MIDI mapping entries for the tool
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Automation Envelopes for Device",invoke=function() randomize_device_envelopes(1) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Automation..:Randomize Automation Envelopes for Device",invoke=function() randomize_device_envelopes(1) end}
renoise.tool():add_menu_entry{name="DSP Device:Paketti..:Randomize Automation Envelopes for Device",invoke=function() randomize_device_envelopes(1) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Randomize Automation Envelopes for Device",invoke=function() randomize_device_envelopes(1) end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti..:Randomize Automation Envelopes for Device",invoke=function() randomize_device_envelopes(1) end}

renoise.tool():add_midi_mapping{name="Paketti:Randomize Automation Envelopes for Device",invoke=function() randomize_device_envelopes(1) end}
-------


-- To keep track of the last selected automation parameter index
local last_automation_index = 0

function showAutomationHardDynamic()
  local app_window = renoise.app().window
  local song = renoise.song()
  local track = song.selected_track

  -- Set active_middle_frame to 1 if not 1 or 2
  if app_window.active_middle_frame ~= 1 and app_window.active_middle_frame ~= 2 then
    app_window.active_middle_frame = 1
  end

  -- Switch to Automation view if not already active
  if app_window.active_lower_frame ~= renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
    app_window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
    return
  end

  -- Gather all automated parameters in the current track
  local automated_parameters = {}
  local selected_track_index = song.selected_track_index

  for _, automation in ipairs(song.selected_pattern.tracks[selected_track_index].automation) do
    table.insert(automated_parameters, automation.dest_parameter)
  end

  -- Cycle to the next automated parameter if multiple are available
  if #automated_parameters > 0 then
    -- Increment and wrap around the index
    last_automation_index = (last_automation_index % #automated_parameters) + 1
    song.selected_automation_parameter = automated_parameters[last_automation_index]
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Switch to Automation Dynamic",invoke=function() showAutomationHardDynamic() end}
renoise.tool():add_midi_mapping{name="Paketti:Switch to Automation Dynamic",invoke=function(message) if message:is_trigger() then showAutomationHardDynamic() end end}
-----------
local dialog = nil
local vb = nil -- Make vb accessible globally
local suppress_notifier = false -- Flag to suppress the notifier

-- Define the notifier function once to maintain the same reference
local edit_step_notifier_fn = function()
  if dialog and dialog.visible and vb and vb.views.editstep_valuebox then
    vb.views.editstep_valuebox.value = renoise.song().transport.edit_step
    -- Refocus the textfield when edit step changes
    dialog:show()
    vb.views.value_textfield.active = true
    vb.views.value_textfield.edit_mode = true
  end
end

local function apply_textfield_value(value)
  local song = renoise.song()
  local track = song.selected_track
  local parameter = song.selected_automation_parameter
  local line_index = song.selected_line_index
  local pattern_index = song.selected_pattern_index

  if not parameter then
    renoise.app():show_status("Please select a parameter to automate.")
    print("No automation parameter selected.")
    return
  end

  local pattern = song:pattern(pattern_index)
  local pattern_length = pattern.number_of_lines

  if line_index <= 0 or line_index > pattern_length then
    renoise.app():show_status("Invalid line index: must be between 1 and " .. pattern_length)
    print("Line index out of range.")
    return
  end

  -- Clamp the value to the range [0, 1]
  local automation_value = math.min(math.max(tonumber(value) or 0, 0), 1)

  -- Access the current pattern and automation for the parameter
  local track_automation = pattern:track(song.selected_track_index)
  local envelope = track_automation:find_automation(parameter)
  
  -- Create the envelope if it doesn't exist
  if not envelope then
    envelope = track_automation:create_automation(parameter)
    print("Created new automation envelope for parameter: " .. parameter.name)
  end

  -- Set the automation point at the selected line with the specified value
  envelope:add_point_at(line_index, automation_value)

  -- Update status
  renoise.app():show_status("Set automation point at line " .. line_index .. " with value " .. automation_value)
end

local function apply_textfield_value_and_move(value)
  -- Print the new value
  print("New Automation Value: " .. value)
  
  -- Set the automation point in the Renoise pattern editor
  apply_textfield_value(value)
  
  -- Move to next line if "Follow Editstep" is checked
  if dialog and dialog.visible then
    local follow_editstep = vb.views.follow_editstep_checkbox.value
    if follow_editstep then
      local song = renoise.song()
      local edit_step = song.transport.edit_step
      local current_line = song.selected_line_index
      local pattern_length = song.selected_pattern.number_of_lines
      local next_line = current_line + edit_step
      if next_line > pattern_length then
        next_line = ((next_line - 1) % pattern_length) + 1 -- wrap around
        song.selected_line_index = next_line
        renoise.app():show_status("Wrapped to line " .. next_line)
      else
        song.selected_line_index = next_line
      end
      -- Re-focus the textfield and clear its content safely
      suppress_notifier = true
      vb.views.value_textfield.value = ""
      suppress_notifier = false
      vb.views.value_textfield.active = true
      vb.views.value_textfield.edit_mode = true
    else
      -- If not following editstep, close the dialog
      dialog:close()
      dialog = nil
    end
  end
end

local function textfield_notifier(new_value)
  if suppress_notifier then
    return
  end
  local clamped_value = math.min(math.max(tonumber(new_value) or 0, 0), 1)
  apply_textfield_value_and_move(clamped_value)
end

local function show_value_dialog()
  -- If dialog is already open, clean up and close
  if dialog and dialog.visible then
    local edit_step_observable = renoise.song().transport.edit_step_observable
    if edit_step_observable:has_notifier(edit_step_notifier_fn) then
      edit_step_observable:remove_notifier(edit_step_notifier_fn)
    end
    dialog:close()
    dialog = nil
    return
  end

  vb = renoise.ViewBuilder() -- Create vb here and make it global
  local initial_value = "0.93524"

  local textfield = vb:textfield{
    width = 60,
    id = "value_textfield",
    value = initial_value,
    edit_mode = true,
    notifier = textfield_notifier
  }

  local apply_button = vb:button{
    text = "Write Automation to Current Line",
    width = 180,
    notifier = function()
      apply_textfield_value_and_move(vb.views.value_textfield.value)
    end
  }

  local follow_editstep_checkbox = vb:checkbox {
    id = "follow_editstep_checkbox",
    value = false, -- default unchecked
    notifier = function(value)
      print("Follow Editstep checkbox changed to " .. tostring(value))
      -- Re-focus the textfield when the checkbox is clicked
      vb.views.value_textfield.active = true
      vb.views.value_textfield.edit_mode = true
    end
  }

  local editstep_valuebox = vb:valuebox {
    id = "editstep_valuebox",
    value = renoise.song().transport.edit_step,
    min = 0,
    max = 64,
    notifier = function(value)
      print("Edit step value changed to " .. tostring(value))
      renoise.song().transport.edit_step = value
      -- Re-focus the textfield when the valuebox value is changed
      vb.views.value_textfield.active = true
      vb.views.value_textfield.edit_mode = true
    end
  }

  local close_button = vb:button{
    text = "Close",
    notifier = function()
      if dialog and dialog.visible then
        local edit_step_observable = renoise.song().transport.edit_step_observable
        if edit_step_observable:has_notifier(edit_step_notifier_fn) then
          edit_step_observable:remove_notifier(edit_step_notifier_fn)
        end
        dialog:close()
        dialog = nil
      end
    end
  }

  dialog = renoise.app():show_custom_dialog("Set Automation Value",
    vb:column{
      margin=10,
      vb:row{
        textfield,
        apply_button,
      },
      vb:row{
        vb:text{text="Follow Editstep"},
        follow_editstep_checkbox,
        vb:text{text="Editstep"},
        editstep_valuebox,
      },
      vb:row{
        close_button,
      }
    }, keyhandlerfunc_automationvalue )

function keyhandlerfunc_automationvalue(dialog,key)
  local closer = preferences.pakettiDialogClose.value
  if key.name == closer then
    dialog:close()
  end
  return key
end

    -- Add the edit step notifier after dialog is created
    local edit_step_observable = renoise.song().transport.edit_step_observable
    if not edit_step_observable:has_notifier(edit_step_notifier_fn) then
      edit_step_observable:add_notifier(edit_step_notifier_fn)
    end

  renoise.app().window.active_lower_frame = 2
  -- Set initial focus to the textfield
  vb.views.value_textfield.active = true
  vb.views.value_textfield.edit_mode = true
end

renoise.tool():add_keybinding{name="Global:Paketti:Show Automation Value Dialog...",invoke=function() show_value_dialog() end}
renoise.tool():add_midi_mapping{name="Paketti:Show Automation Value Dialog...",invoke=function(message) if message:is_trigger() then show_value_dialog() end end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Paketti Automation Value...",invoke=function() show_value_dialog() end}









local function write_automation_value(value)
  local song = renoise.song()
  local track = song.selected_track
  local parameter = song.selected_automation_parameter
  local line_index = song.selected_line_index
  local pattern_index = song.selected_pattern_index

  if not parameter then
    renoise.app():show_status("Please select a parameter to automate.")
    print("No automation parameter selected.")
    return
  end

  local pattern = song:pattern(pattern_index)
  local pattern_length = pattern.number_of_lines

  if line_index <= 0 or line_index > pattern_length then
    renoise.app():show_status("Invalid line index: must be between 1 and " .. pattern_length)
    print("Line index out of range.")
    return
  end

  -- Access the current pattern and automation for the parameter
  local track_automation = pattern:track(song.selected_track_index)
  local envelope = track_automation:find_automation(parameter)
  
  -- Create the envelope if it doesn't exist
  if not envelope then
    envelope = track_automation:create_automation(parameter)
    print("Created new automation envelope for parameter: " .. parameter.name)
  end

  -- Set the automation point at the selected line with the specified value
  envelope:add_point_at(line_index, value or 0.5)

  -- Update status
  renoise.app():show_status("Set automation point at line " .. line_index .. " with value " .. (value or 0.5))
end

for i = 0, 1, 0.1 do
  local formatted_value = string.format("%.1f", i)
renoise.tool():add_keybinding{name="Global:Paketti:Write Automation Value " .. formatted_value,invoke=function() write_automation_value(tonumber(formatted_value)) end}
if i == 0 then

renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Automation..:Write Automation Value " .. formatted_value,invoke=function() write_automation_value(tonumber(formatted_value)) end}
else
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Automation..:Write Automation Value " .. formatted_value,invoke=function() write_automation_value(tonumber(formatted_value)) end}
end
end
-----------------
function PakettiAutomationSelectionFloodFill()
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter

  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    print("No automatable parameter selected.")
    return
  end

  local track_automation = song:pattern(song.selected_pattern_index):track(song.selected_track_index)
  local envelope = track_automation:find_automation(automation_parameter)
  local pattern_length = song:pattern(song.selected_pattern_index).number_of_lines

  if not envelope then
    renoise.app():show_status("No automation envelope found for the selected parameter.")
    print("No automation envelope found.")
    return
  end

  local selection = envelope.selection_range
  if not selection then
    renoise.app():show_status("Please select a range in the automation envelope.")
    print("No selection range found.")
    return
  end

  local start_line, end_line = selection[1], selection[2]
  if start_line >= end_line then
    renoise.app():show_status("Invalid selection range.")
    print("Invalid selection range.")
    return
  end

  -- Extract points from the selection
  local selected_points = {}
  for _, point in ipairs(envelope.points) do
    if point.time >= start_line and point.time <= end_line then
      table.insert(selected_points, {time = point.time - start_line, value = point.value})
    end
  end

  if #selected_points == 0 then
    renoise.app():show_status("No automation points found in the selection.")
    print("No points in selection range.")
    return
  end

  -- Adjust the last point's timing once
  local last_point = selected_points[#selected_points]
  last_point.time = (end_line - start_line) - 0.01
  selected_points[#selected_points] = last_point

  -- Clear all automation after the selection ends
  envelope:clear_range(end_line + 1, pattern_length)
  print("Cleared automation points after line " .. end_line .. ".")
  print("------")

  -- Debug: Print the adjusted selection points
  print("Adjusted Selection Points (Ready for Repetition):")
  for _, point in ipairs(selected_points) do
    print(string.format("Relative Time: %.2f, Value: %.2f", point.time, point.value))
  end
  print("------")

  -- Flood-fill the rest of the pattern with the selected points
  local repeat_count = math.ceil((pattern_length - start_line + 1) / (end_line - start_line))
  local resultant_points = {}

  for i = 0, repeat_count - 1 do
    local offset = i * (end_line - start_line)
    local segment_points = {}

    for _, point in ipairs(selected_points) do
      local target_time = start_line + offset + point.time
      if target_time > pattern_length then
        break
      end
      envelope:add_point_at(target_time, point.value)
      table.insert(resultant_points, {time = target_time, value = point.value})
      table.insert(segment_points, {time = target_time, value = point.value})
    end

    -- Debug: Print each segment
    print("Applied Points (Segment):")
    for _, point in ipairs(segment_points) do
      print(string.format("Time: %.2f, Value: %.2f", point.time, point.value))
    end
    print("------")
  end

  -- Debug: Group resultant points by segments
  print("Resultant Envelope Points (Grouped by Segments):")
  local grouped_points = {}
  for _, point in ipairs(resultant_points) do
    local group_index = math.floor((point.time - start_line) / (end_line - start_line))
    grouped_points[group_index] = grouped_points[group_index] or {}
    table.insert(grouped_points[group_index], point)
  end

  for segment_index, segment in ipairs(grouped_points) do
    print(string.format("Segment %d:", segment_index + 1))
    for _, point in ipairs(segment) do
      print(string.format("Time: %.2f, Value: %.2f", point.time, point.value))
    end
    print("------")
  end

  renoise.app():show_status("Automation selection flooded successfully.")
  print("Flooded automation values from lines " .. start_line .. " to " .. pattern_length)
end

-- Keybinding and menu registration
renoise.tool():add_keybinding{name="Global:Paketti:Flood Fill Automation Selection",invoke=PakettiAutomationSelectionFloodFill}
renoise.tool():add_midi_mapping{name="Paketti:Flood Fill Automation Selection",invoke=function(message) if message:is_trigger() then PakettiAutomationSelectionFloodFill() end end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Automation..:Flood Fill Automation Selection",invoke=PakettiAutomationSelectionFloodFill}
renoise.tool():add_menu_entry{name="--Track Automation:Paketti..:Flood Fill Automation Selection",invoke=PakettiAutomationSelectionFloodFill}

------
function SetAutomationRangeValue(value)
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter

  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    print("No automatable parameter selected.")
    return
  end

  local track_automation = song:pattern(song.selected_pattern_index):track(song.selected_track_index)
  local envelope = track_automation:find_automation(automation_parameter)
  local selection = nil

  -- Check for selection range
  if envelope then
    selection = envelope.selection_range
  end

  if not envelope then
    -- Create envelope and set to PLAYMODE_POINTS, selection is lost
    envelope = track_automation:create_automation(automation_parameter)
    envelope.playmode = renoise.PatternTrackAutomation.PLAYMODE_POINTS
    renoise.app():show_status("Created automation envelope in PLAYMODE_POINTS.")
    print("Created automation envelope in PLAYMODE_POINTS for parameter: " .. automation_parameter.name)
    return
  end

  if not selection then
    renoise.app():show_status("Please select a valid range in the automation envelope.")
    print("No valid selection range found.")
    return
  end

  -- Apply changes to the selection range
  local start_line, end_line = selection[1], selection[2]
  if start_line >= end_line then
    renoise.app():show_status("Invalid selection range.")
    print("Invalid selection range.")
    return
  end

  -- Set all points in the selection range to the specified value
  envelope:clear_range(start_line, end_line)
  for line = start_line, end_line do
    envelope:add_point_at(line, value)
  end

  renoise.app():show_status("Automation range set to " .. value .. ".")
  print("Set automation range from line " .. start_line .. " to " .. end_line .. " to " .. value .. ".")
end

-- Menu entries, keybindings, and MIDI mappings
renoise.tool():add_menu_entry{name="--Track Automation:Paketti..:Set Automation Range to Max (1.0)",invoke=function() SetAutomationRangeValue(1.0) end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti..:Set Automation Range to Middle (0.5)",invoke=function() SetAutomationRangeValue(0.5) end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti..:Set Automation Range to Min (0.0)",invoke=function() SetAutomationRangeValue(0.0) end}

renoise.tool():add_keybinding{name="Global:Paketti:Set Automation Range to Max (1.0)",invoke=function() SetAutomationRangeValue(1.0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Automation Range to Middle (0.5)",invoke=function() SetAutomationRangeValue(0.5) end}
renoise.tool():add_keybinding{name="Global:Paketti:Set Automation Range to Min (0.0)",invoke=function() SetAutomationRangeValue(0.0) end}

renoise.tool():add_midi_mapping{name="Paketti:Set Automation Range to Max (1.0)",invoke=function(message) if message:is_trigger() then SetAutomationRangeValue(1.0) end end}
renoise.tool():add_midi_mapping{name="Paketti:Set Automation Range to Middle (0.5)",invoke=function(message) if message:is_trigger() then SetAutomationRangeValue(0.5) end end}
renoise.tool():add_midi_mapping{name="Paketti:Set Automation Range to Min (0.0)",invoke=function(message) if message:is_trigger() then SetAutomationRangeValue(0.0) end end}
-------
function FlipAutomationHorizontal()
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter

  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    print("No automatable parameter selected.")
    return
  end

  local track_automation = song:pattern(song.selected_pattern_index):track(song.selected_track_index)
  local envelope = track_automation:find_automation(automation_parameter)

  if not envelope then
    renoise.app():show_status("No automation envelope exists for the selected parameter.")
    print("No automation envelope exists.")
    return
  end

  local selection = envelope.selection_range
  if not selection then
    renoise.app():show_status("Please select a range in the automation envelope.")
    print("No valid selection range found.")
    return
  end

  local start_line, end_line = selection[1], selection[2]
  if start_line >= end_line then
    renoise.app():show_status("Invalid selection range.")
    print("Invalid selection range.")
    return
  end

  -- Collect points within the selection range
  local points = {}
  print("Original Automation Points (Horizontal Flip):")
  for _, point in ipairs(envelope.points) do
    if point.time >= start_line and point.time <= end_line then
      table.insert(points, {time=point.time, value=point.value})
      print(string.format("Row %03d: Value %.2f", point.time, point.value))
    end
  end

  -- Sort points by time for deterministic flipping
  table.sort(points, function(a, b) return a.time < b.time end)

  -- Clear the range before applying flipped points
  envelope:clear_range(start_line, end_line)

  print("Flipping Points Horizontally...")
  local total_points = #points
  for i, point in ipairs(points) do
    local flipped_time = points[total_points - i + 1].time -- Reverse the time order
    envelope:add_point_at(flipped_time, point.value)
    print(string.format("Row %03d: Flipped to Row %03d, Value %.2f (verified as %.2f)",
      point.time, flipped_time, point.value, point.value))
  end

  renoise.app():show_status("Automation selection flipped horizontally.")
  print("Automation selection flipped horizontally from line " .. start_line .. " to " .. end_line .. ".")
end

-----------
-- Define whitelist of center-based parameters
local center_based_parameters = {
  ["Panning"] = true,
  ["Width"] = true,
  ["X_Pitchbend"] = true,
  ["Pitchbend"] = true,
  -- Add other center-based parameters as needed
}

function ScaleAutomation(scale_factor)
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter

  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    print("No automatable parameter selected.")
    return
  end

  local track_automation = song:pattern(song.selected_pattern_index):track(song.selected_track_index)
  local envelope = track_automation:find_automation(automation_parameter)

  if not envelope then
    renoise.app():show_status("No automation envelope exists for the selected parameter.")
    print("No automation envelope exists.")
    return
  end

  local selection = envelope.selection_range
  local start_line, end_line
  if selection then
    start_line, end_line = selection[1], selection[2]
  else
    start_line, end_line = 1, renoise.song().patterns[song.selected_pattern_index].number_of_lines
  end

  if start_line >= end_line then
    renoise.app():show_status("Invalid selection range.")
    print("Invalid selection range.")
    return
  end

  -- Determine if this is a center-based parameter
  local is_center_based = center_based_parameters[automation_parameter.name] or false
  local center_point = is_center_based and 0.5 or 0.0

  -- Scale points
  local points = {}
  for _, point in ipairs(envelope.points) do
    if point.time >= start_line and point.time <= end_line then
      table.insert(points, point)
    end
  end

  if #points == 0 then
    renoise.app():show_status("No automation points found in the specified range.")
    print("No automation points found.")
    return
  end

  print(string.format("Scaling %s parameter (center-based: %s)", 
    automation_parameter.name, is_center_based and "yes" or "no"))
  print("Original Points for Scaling:")
  for _, point in ipairs(points) do
    print(string.format("Row %03d: Value %.2f", point.time, point.value))
  end

  for _, point in ipairs(points) do
    local scaled_value
    if is_center_based then
      -- For center-based parameters, scale relative to center (0.5)
      local distance_from_center = point.value - center_point
      scaled_value = center_point + (distance_from_center * scale_factor)
    else
      -- For regular parameters, scale from 0
      if point.value > center_point then
        scaled_value = center_point + (point.value - center_point) * scale_factor
      else
        scaled_value = center_point - (center_point - point.value) * scale_factor
      end
    end
    
    envelope:add_point_at(point.time, math.max(0.0, math.min(1.0, scaled_value))) -- Clamp between 0 and 1
    print(string.format("Row %03d: Value %.2f scaled to %.2f", point.time, point.value, scaled_value))
  end

  renoise.app():show_status("Automation scaled by " .. (scale_factor * 100) .. "%.")
  print("Scaled automation points in range " .. start_line .. " to " .. end_line .. " by " .. (scale_factor * 100) .. "%.")
end

-- Menu entries, keybindings, and MIDI mappings for scaling
renoise.tool():add_menu_entry{name="--Track Automation:Paketti..:Scale Automation to 90%",invoke=function() ScaleAutomation(0.9) end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti..:Scale Automation to 110%",invoke=function() ScaleAutomation(1.1) end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti..:Scale Automation to 200%",invoke=function() ScaleAutomation(2.0) end}
renoise.tool():add_menu_entry{name="Track Automation:Paketti..:Scale Automation to 50%",invoke=function() ScaleAutomation(0.5) end}

renoise.tool():add_keybinding{name="Global:Paketti:Scale Automation to 90%",invoke=function() ScaleAutomation(0.9) end}
renoise.tool():add_keybinding{name="Global:Paketti:Scale Automation to 110%",invoke=function() ScaleAutomation(1.1) end}
renoise.tool():add_keybinding{name="Globael:Paketti:Scale Automation to 200%",invoke=function() ScaleAutomation(2.0) end}
renoise.tool():add_keybinding{name="Global:Paketti:Scale Automation to 50%",invoke=function() ScaleAutomation(0.5) end}

renoise.tool():add_midi_mapping{name="Paketti:Scale Automation to 90%",invoke=function(message) if message:is_trigger() then ScaleAutomation(0.9) end end}
renoise.tool():add_midi_mapping{name="Paketti:Scale Automation to 110%",invoke=function(message) if message:is_trigger() then ScaleAutomation(1.1) end end}
renoise.tool():add_midi_mapping{name="Paketti:Scale Automation to 200%",invoke=function(message) if message:is_trigger() then ScaleAutomation(2.0) end end}
renoise.tool():add_midi_mapping{name="Paketti:Scale Automation to 50%",invoke=function(message) if message:is_trigger() then ScaleAutomation(0.5) end end}
--------
renoise.tool():add_midi_mapping{name="Paketti:Dynamic Scale Automation",
  invoke=function(message)
    if not message.int_value then
      renoise.app():show_status("Invalid MIDI message for dynamic scaling.")
      print("Invalid MIDI message received.")
      return
    end

    local knob_value = message.int_value -- MIDI knob value (0–127)
    local scale_factor

    if knob_value < 64 then
      -- Reduce scale (10% to 100%)
      scale_factor = 0.1 + (knob_value / 63) * (1.0 - 0.1)
    elseif knob_value == 64 then
      -- Neutral (no change)
      scale_factor = 1.0
    else
      -- Increase scale (100% to 200%)
      scale_factor = 1.0 + ((knob_value - 64) / 63) * (2.0 - 1.0)
    end

    ScaleAutomation(scale_factor)
    renoise.app():show_status("Scaled automation dynamically to " .. (scale_factor * 100) .. "%.")
    print("Dynamic scale factor applied: " .. scale_factor)
  end
}

---

function FlipAutomationVertical()
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter

  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    print("No automatable parameter selected.")
    return
  end

  local track_automation = song:pattern(song.selected_pattern_index):track(song.selected_track_index)
  local envelope = track_automation:find_automation(automation_parameter)

  if not envelope then
    renoise.app():show_status("No automation envelope exists for the selected parameter.")
    print("No automation envelope exists.")
    return
  end

  local selection = envelope.selection_range
  if not selection then
    renoise.app():show_status("Please select a range in the automation envelope.")
    print("No valid selection range found.")
    return
  end

  local start_line, end_line = selection[1], selection[2]
  if start_line >= end_line then
    renoise.app():show_status("Invalid selection range.")
    print("Invalid selection range.")
    return
  end

  -- Flip vertically: Invert the values of points within the selection range
  print("Original Automation Points (Vertical Flip):")
  for _, point in ipairs(envelope.points) do
    if point.time >= start_line and point.time <= end_line then
      print(string.format("Row %03d: Value %.2f", point.time, point.value))
      envelope:add_point_at(point.time, 1.0 - point.value)
      print(string.format("Row %03d: Value %.2f flipped to %.2f (verified as %.2f)",
        point.time, point.value, 1.0 - point.value, 1.0 - point.value))
    end
  end

  renoise.app():show_status("Automation selection flipped vertically.")
  print("Automation selection flipped vertically from line " .. start_line .. " to " .. end_line .. ".")
end

-- Menu entries, keybindings, and MIDI mappings
renoise.tool():add_menu_entry{name="--Track Automation:Paketti..:Flip Automation Selection Horizontally",invoke=FlipAutomationHorizontal}
renoise.tool():add_menu_entry{name="Track Automation:Paketti..:Flip Automation Selection Vertically",invoke=FlipAutomationVertical}

renoise.tool():add_keybinding{name="Global:Paketti:Flip Automation Selection Horizontally",invoke=FlipAutomationHorizontal}
renoise.tool():add_keybinding{name="Global:Paketti:Flip Automation Selection Vertically",invoke=FlipAutomationVertical}

renoise.tool():add_midi_mapping{name="Paketti:Flip Automation Selection Horizontally",invoke=function(message) if message:is_trigger() then FlipAutomationHorizontal() end end}
renoise.tool():add_midi_mapping{name="Paketti:Flip Automation Selection Vertically",invoke=function(message) if message:is_trigger() then FlipAutomationVertical() end end}
-----

function add_automation_points_for_notes()
  local song = renoise.song()

  -- Ensure there's a selected track and automation parameter
  local track = song.selected_track
  local parameter = song.selected_automation_parameter
  local pattern_index = song.selected_pattern_index
  local track_index = song.selected_track_index
  local line_index = song.selected_line_index

  if not parameter then
    renoise.app():show_status("Please select a parameter to automate.")
    print("No automation parameter selected.")
    return
  end

  -- Access the current pattern and the selected track's pattern track
  local pattern = song:pattern(pattern_index)
  local pattern_track = pattern:track(track_index)

  -- Find or create automation envelope for the parameter
  local envelope = pattern_track:find_automation(parameter)
  if not envelope then
    envelope = pattern_track:create_automation(parameter)
    print("Created new automation envelope for parameter: " .. parameter.name)
  end

  -- Iterate through the lines in the pattern track to find notes
  for line_index = 1, pattern.number_of_lines do
    local line = pattern_track:line(line_index)

    if line and line.note_columns then
      -- Check for valid notes in the note columns
      for _, note_column in ipairs(line.note_columns) do
        if note_column.note_value < 120 then -- Valid MIDI note
          -- Set the automation point at the line's position
          local value = 0.5 -- Default automation value (you can adjust this logic as needed)
          envelope:add_point_at(line_index, value)

          renoise.app():show_status(
            "Added automation point at line " .. line_index .. " with value " .. value
          )
          print("Added automation point at line " .. line_index .. " with value " .. value)
        end
      end
    end
  end

  renoise.app():show_status("Finished adding automation points for notes.")
end

-- Execute the function
renoise.tool():add_menu_entry{name="--Track Automation:Paketti..:Generate Automation Points from Notes in Selected Track",invoke=function()
add_automation_points_for_notes() end}
renoise.tool():add_menu_entry{name="--Track Automation List:Paketti..:Generate Automation Points from Notes in Selected Track",invoke=function()
add_automation_points_for_notes() end}

renoise.tool():add_keybinding{name="Global:Paketti:Generate Automation Points from Notes in Selected Track",invoke=function()
add_automation_points_for_notes()
renoise.app().window.active_middle_frame = 1
renoise.app().window.active_lower_frame = 2
 end}
 
renoise.tool():add_midi_mapping{name="Paketti:Generate Automation Points from Notes in Selected Track",invoke=function(message)
if message:is_trigger() then
add_automation_points_for_notes()
renoise.app().window.active_middle_frame = 1
renoise.app().window.active_lower_frame = 2
 end end}


--------

function PakettiAutomationPlayModeChange_SetPlaymode(mode)
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope then
    renoise.app():show_status("No automation envelope found for the selected parameter.")
    return
  end

  envelope.playmode = mode
  renoise.app():show_status("Playmode set to " .. mode)
end

function PakettiAutomationPlayModeChange_Next()
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope then
    renoise.app():show_status("No automation envelope found for the selected parameter.")
    return
  end

  envelope.playmode = (envelope.playmode % 3) + 1
  renoise.app():show_status("Next playmode selected: " .. envelope.playmode)
end

function PakettiAutomationPlayModeChange_Previous()
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    renoise.app():show_status("Please select an automatable parameter.")
    return
  end

  local envelope = song:pattern(song.selected_pattern_index):track(song.selected_track_index):find_automation(automation_parameter)
  if not envelope then
    renoise.app():show_status("No automation envelope found for the selected parameter.")
    return
  end

  envelope.playmode = (envelope.playmode - 2) % 3 + 1
  renoise.app():show_status("Previous playmode selected: " .. envelope.playmode)
end

-- Add Keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Select Automation Playmode (Next)",invoke=PakettiAutomationPlayModeChange_Next}
renoise.tool():add_keybinding{name="Global:Paketti:Select Automation Playmode (Previous)",invoke=PakettiAutomationPlayModeChange_Previous}
renoise.tool():add_keybinding{name="Global:Paketti:Select Automation Playmode 01 Points",invoke=function() PakettiAutomationPlayModeChange_SetPlaymode(renoise.PatternTrackAutomation.PLAYMODE_POINTS) end}
renoise.tool():add_keybinding{name="Global:Paketti:Select Automation Playmode 02 Lines",invoke=function() PakettiAutomationPlayModeChange_SetPlaymode(renoise.PatternTrackAutomation.PLAYMODE_LINES) end}
renoise.tool():add_keybinding{name="Global:Paketti:Select Automation Playmode 03 Curves",invoke=function() PakettiAutomationPlayModeChange_SetPlaymode(renoise.PatternTrackAutomation.PLAYMODE_CURVES) end}

-- Add MIDI Mappings
renoise.tool():add_midi_mapping{name="Paketti:Select Automation Playmode (Next)",invoke=PakettiAutomationPlayModeChange_Next}
renoise.tool():add_midi_mapping{name="Paketti:Select Automation Playmode (Previous)",invoke=PakettiAutomationPlayModeChange_Previous}
renoise.tool():add_midi_mapping{name="Paketti:Select Automation Playmode 01 Points",invoke=function() PakettiAutomationPlayModeChange_SetPlaymode(renoise.PatternTrackAutomation.PLAYMODE_POINTS) end}
renoise.tool():add_midi_mapping{name="Paketti:Select Automation Playmode 02 Lines",invoke=function() PakettiAutomationPlayModeChange_SetPlaymode(renoise.PatternTrackAutomation.PLAYMODE_LINES) end}
renoise.tool():add_midi_mapping{name="Paketti:Select Automation Playmode 03 Curves",invoke=function() PakettiAutomationPlayModeChange_SetPlaymode(renoise.PatternTrackAutomation.PLAYMODE_CURVES) end}



function clone_sequence_with_automation_only()
  local song = renoise.song()
  local sequencer = song.sequencer
  local current_sequence = sequencer.pattern_sequence
  local selected_tracks = {}
  
  -- Step 1: Get selected tracks from pattern matrix
  for track_idx = 1, #song.tracks do
    for seq_idx = 1, #current_sequence do
      if sequencer:track_sequence_slot_is_selected(track_idx, seq_idx) then
        selected_tracks[track_idx] = true
        break
      end
    end
  end
  
  -- Step 2: Clone the sequence
  sequencer:clone_range(1, #current_sequence)
  
  -- Step 3: Process each pattern in the cloned sequence
  for seq_idx = 1, #current_sequence do
    local original_pattern_index = current_sequence[seq_idx]
    local cloned_pattern_index = current_sequence[seq_idx + #current_sequence]
    local original_pattern = song.patterns[original_pattern_index]
    local cloned_pattern = song.patterns[cloned_pattern_index]
    
    -- Step 4: Process selected tracks
    for track_idx, is_selected in pairs(selected_tracks) do
      if is_selected then
        local track = cloned_pattern:track(track_idx)
        
        -- Clear note data
        for line_idx = 1, cloned_pattern.number_of_lines do
          local line = track:line(line_idx)
          for _, note_column in ipairs(line.note_columns) do
            note_column:clear()
          end
          for _, fx_column in ipairs(line.effect_columns) do
            fx_column:clear()
          end
        end
        
        -- Automation is automatically preserved since we cloned the pattern
      end
    end
    
    -- Step 5: Maintain selection in cloned sequence
    for track_idx, is_selected in pairs(selected_tracks) do
      if is_selected then
        sequencer:set_track_sequence_slot_is_selected(track_idx, seq_idx + #current_sequence, true)
      end
    end
  end
  
  renoise.app():show_status("Sequence cloned with automation only in selected tracks")
end

renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Clone Sequence (Automation Only)",invoke=clone_sequence_with_automation_only}
renoise.tool():add_keybinding{name="Global:Paketti:Clone Sequence (Automation Only)",invoke=clone_sequence_with_automation_only}

function clone_pattern_without_automation()
  local song = renoise.song()
  local sequencer = song.sequencer
  local current_sequence_pos = song.selected_sequence_index
  local selected_tracks = {}
  
  -- Step 1: Get selected tracks from pattern matrix
  for track_idx = 1, #song.tracks do
    if sequencer:track_sequence_slot_is_selected(track_idx, current_sequence_pos) then
      selected_tracks[track_idx] = true
    end
  end
  
  -- Step 2: Clone the current sequence position
  if current_sequence_pos <= #sequencer.pattern_sequence then
    sequencer:clone_range(current_sequence_pos, current_sequence_pos)
    
    -- Step 3: Process selected tracks in the cloned pattern
    local cloned_pattern = song.patterns[sequencer.pattern_sequence[current_sequence_pos + 1]]
    for track_idx, is_selected in pairs(selected_tracks) do
      if is_selected then
        local track = cloned_pattern:track(track_idx)
        
        -- Store all automation parameters first (because we'll be modifying the collection)
        local parameters_to_delete = {}
        for _, automation in ipairs(track.automation) do
          table.insert(parameters_to_delete, automation.dest_parameter)
        end
        
        -- Delete each automation envelope
        for _, parameter in ipairs(parameters_to_delete) do
          track:delete_automation(parameter)
        end
      end
    end
    
    -- Step 4: Maintain selections in the new sequence slot
    for track_idx, is_selected in pairs(selected_tracks) do
      if is_selected then
        sequencer:set_track_sequence_slot_is_selected(track_idx, current_sequence_pos + 1, true)
      end
    end
    
    -- Select the newly created sequence
    song.selected_sequence_index = current_sequence_pos + 1
    renoise.app():show_status("Pattern cloned without automation in selected tracks")
  else
    renoise.app():show_status("Cannot clone the sequence: The current sequence is the last one.")
  end
end

renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Clone Pattern (Without Automation)",invoke = clone_pattern_without_automation}
renoise.tool():add_keybinding{name="Global:Paketti:Clone Pattern (Without Automation)",invoke = clone_pattern_without_automation}


--------
-- Global variables for parameter following
local is_following_parameter = false
local follow_timer = nil

function follow_parameter()
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  local master_track = song.tracks[song.sequencer_track_count + 1]
  
  -- Find our devices
  local writer_index = find_device_by_name(master_track, "Paketti LFO Writer")
  
  if not writer_index then
    return
  end
  
  -- Get the actual Amplitude value from the Writer LFO
  local writer_value = master_track.devices[writer_index].parameters[4].value
  
  -- Check if we have a valid automation parameter
  if not automation_parameter or not automation_parameter.is_automatable then
    return
  end

  -- Find or create the automation envelope
  local track_automation = song:pattern(song.selected_pattern_index):track(song.selected_track_index)
  local envelope = track_automation:find_automation(automation_parameter)
  
  if not envelope then
    envelope = track_automation:create_automation(automation_parameter)
  end

  -- Write the value at the current playhead position
  local playhead_line = song.transport.playback_pos.line
  envelope:add_point_at(playhead_line, writer_value)
end

function toggle_parameter_following()
  renoise.app().window.active_middle_frame=2
  renoise.app().window.lower_frame_is_visible=true
  renoise.app().window.active_lower_frame=2
  -- Check if timer is already running
  if renoise.tool():has_timer(follow_parameter) then
    -- Stop and cleanup
    renoise.tool():remove_timer(follow_parameter)
    follow_timer = nil
    is_following_parameter = false
    -- Remove the LFO devices

    if preferences.PakettiLFOWriteDelete.value == true then
    remove_lfo_devices() 
    return
    end
    print("LFO Writer Parameter following stopped")
    renoise.app():show_status("LFO Writer Parameter following stopped")
  else
    -- First remove any existing devices (cleanup)
    if preferences.PakettiLFOWriteDelete.value == true then
    remove_lfo_devices()
    end

    -- Then create fresh devices
    if create_lfo_devices() then
      follow_timer = renoise.tool():add_timer(follow_parameter, 0.001)
      is_following_parameter = true
      print("LFO Writer Parameter following started")
      
      renoise.app():show_status("LFO Writer Parameter following started")
    else
      print("Error: Could not create LFO devices")
      renoise.app():show_status("Error: Could not create LFO devices")
    end
  end
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:LFO Write..:LFO Write to Selected Automation Parameter",invoke = toggle_parameter_following}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:LFO Write..:LFO Write to Selected Automation Parameter",invoke = toggle_parameter_following}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:LFO Write..:LFO Write to Selected Automation Parameter",invoke = toggle_parameter_following}
renoise.tool():add_keybinding{name="Global:Paketti:LFO Write to Selected Automation Parameter",invoke = toggle_parameter_following}


-- Global variables
local is_following_to_fx = false
local follow_fx_timer = nil
local current_fx_command = nil
local last_written_line = nil

function find_device_by_name(track, name)
  for i = 1, #track.devices do
    if track.devices[i].display_name == name then
      return i
    end
  end
  return nil
end

function create_lfo_devices()
  local song = renoise.song()
  local master_track = song.tracks[song.sequencer_track_count + 1]
  
  -- Create Writer first (if doesn't exist)
  local writer_index = find_device_by_name(master_track, "Paketti LFO Writer")
  if not writer_index then
    local writer_device = master_track:insert_device_at("Audio/Effects/Native/*LFO", 2)
    writer_device.display_name = "Paketti LFO Writer"
  end
  
  -- Then create Source (if doesn't exist) and connect to Writer
  local source_index = find_device_by_name(master_track, "Paketti LFO Source")
  if not source_index then
    local source_device = master_track:insert_device_at("Audio/Effects/Native/*LFO", 2)
    source_device.display_name = "Paketti LFO Source"
    
    -- Get fresh Writer index and set up connection
    writer_index = find_device_by_name(master_track, "Paketti LFO Writer")
    source_device.parameters[2].value = writer_index-1
    source_device.parameters[3].value = 4
    source_device.parameters[4].show_in_mixer = true
    source_device.parameters[5].show_in_mixer = true
    source_device.parameters[6].show_in_mixer = true
  end
  
  return true
end

function remove_lfo_devices()
  local song = renoise.song()
  local master_track = song.tracks[song.sequencer_track_count + 1]
  
  -- Find and remove devices by name (search in reverse to handle indices correctly)
  local writer_index = find_device_by_name(master_track, "Paketti LFO Writer")
  local source_index = find_device_by_name(master_track, "Paketti LFO Source")
  
  if writer_index then
    master_track:delete_device_at(writer_index)
  end
  if source_index then
    master_track:delete_device_at(source_index)
  end
end

function follow_to_fx_amount()
  local song = renoise.song()
  local master_track = song.tracks[song.sequencer_track_count + 1]
  
  -- Find our devices
  local source_index = find_device_by_name(master_track, "Paketti LFO Source")
  local writer_index = find_device_by_name(master_track, "Paketti LFO Writer")
  
  if not source_index or not writer_index then
    return
  end
  
  -- Get current line number
  local current_line = song.transport.playback_pos.line
  
  -- Only write if we're on a new line
  if current_line ~= last_written_line then
    local writer_device = master_track.devices[writer_index]
    
    if writer_device and writer_device.parameters[4] then
      -- Get the actual Amplitude value from the Writer LFO
      local writer_value = writer_device.parameters[4].value
      
      -- Convert the value for FX column
      local hex_value = string.format("%02X", math.floor(writer_value * 255))
      
      -- Get current pattern and line
      local pattern = song:pattern(song.selected_pattern_index)
      local line = pattern:track(song.selected_track_index):line(current_line)
      
      -- Write to first effect column (index 1)
      if current_fx_command then
        line.effect_columns[1].number_string = current_fx_command
      end
      line.effect_columns[1].amount_string = hex_value
      
      -- Update last written line
      last_written_line = current_line
    end
  end
end

function toggle_fx_amount_following(fx_command)
  local song = renoise.song()
  
  -- Check if timer is already running
  if renoise.tool():has_timer(follow_to_fx_amount) then
    -- Stop and cleanup
    renoise.tool():remove_timer(follow_to_fx_amount)
    follow_fx_timer = nil
    is_following_to_fx = false
    current_fx_command = nil
    last_written_line = nil
    -- Remove the LFO devices
    if preferences.PakettiLFOWriteDelete.value == true then
    remove_lfo_devices() end
    print("LFO Writer Effect Column following stopped")
    renoise.app():show_status("LFO Writer Effect Column following stopped")
  else
    -- First remove any existing devices (cleanup)
    if preferences.PakettiLFOWriteDelete.value == true then
    remove_lfo_devices() end
    
    -- Then create fresh devices
    if create_lfo_devices() then
      -- Store the command and create timer
      current_fx_command = fx_command
      last_written_line = nil
      follow_fx_timer = renoise.tool():add_timer(follow_to_fx_amount, 0.01)
      is_following_to_fx = true
      local status_msg = "LFO Writer Effect Column following started" .. (fx_command and " with command " .. fx_command or " (amount only)")
      print(status_msg)
      renoise.app():show_status(status_msg)
    else
      print("Error: Could not create LFO devices")
      renoise.app():show_status("Error: Could not create LFO devices")
    end
  end
end

-- Add menu entries
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:LFO Write..:LFO Write to Effect Column 1 (Amount Only)",invoke = function() toggle_fx_amount_following() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Yxx)",invoke = function() toggle_fx_amount_following("0Y") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Sxx)",invoke = function() toggle_fx_amount_following("0S") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Dxx)",invoke = function() toggle_fx_amount_following("0D") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Uxx)",invoke = function() toggle_fx_amount_following("0U") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Gxx)",invoke = function() toggle_fx_amount_following("0G") end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Rxx)",invoke = function() toggle_fx_amount_following("0R") end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti..:LFO Write..:LFO Write to Effect Column 1 (Amount Only)",invoke = function() toggle_fx_amount_following() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Yxx)",invoke = function() toggle_fx_amount_following("0Y") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Sxx)",invoke = function() toggle_fx_amount_following("0S") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Dxx)",invoke = function() toggle_fx_amount_following("0D") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Uxx)",invoke = function() toggle_fx_amount_following("0U") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Gxx)",invoke = function() toggle_fx_amount_following("0G") end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Rxx)",invoke = function() toggle_fx_amount_following("0R") end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti..:LFO Write..:LFO Write to Effect Column 1 (Amount Only)",invoke = function() toggle_fx_amount_following() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Yxx)",invoke = function() toggle_fx_amount_following("0Y") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Sxx)",invoke = function() toggle_fx_amount_following("0S") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Dxx)",invoke = function() toggle_fx_amount_following("0D") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Uxx)",invoke = function() toggle_fx_amount_following("0U") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Gxx)",invoke = function() toggle_fx_amount_following("0G") end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:LFO Write..:LFO Write to Effect Column 1 (0Rxx)",invoke = function() toggle_fx_amount_following("0R") end}


renoise.tool():add_keybinding{name="Global:Paketti:LFO Write to Effect Column 1 (Amount Only)",invoke = function() toggle_fx_amount_following() end}
renoise.tool():add_keybinding{name="Global:Paketti:LFO Write to Effect Column 1 (0Yxx)",invoke = function() toggle_fx_amount_following("0Y") end}
renoise.tool():add_keybinding{name="Global:Paketti:LFO Write to Effect Column 1 (0Sxx)",invoke = function() toggle_fx_amount_following("0S") end}
renoise.tool():add_keybinding{name="Global:Paketti:LFO Write to Effect Column 1 (0Dxx)",invoke = function() toggle_fx_amount_following("0D") end}
renoise.tool():add_keybinding{name="Global:Paketti:LFO Write to Effect Column 1 (0Uxx)",invoke = function() toggle_fx_amount_following("0U") end}
renoise.tool():add_keybinding{name="Global:Paketti:LFO Write to Effect Column 1 (0Gxx)",invoke = function() toggle_fx_amount_following("0G") end}
renoise.tool():add_keybinding{name="Global:Paketti:LFO Write to Effect Column 1 (0Rxx)",invoke = function() toggle_fx_amount_following("0R") end}

------
-- Global variables
local is_following_lpb = false
local follow_lpb_timer = nil
local current_range = 255  -- Default range, can be 255, 127, or 64

function scale_value(value, max_range)
  -- Scale from 0-1 to 1-max_range
  return math.floor(value * (max_range - 1) + 1)
end

function follow_to_lpb()
  local song = renoise.song()
  local master_track = song.tracks[song.sequencer_track_count + 1]
  
  -- Find our devices
  local writer_index = find_device_by_name(master_track, "Paketti LFO Writer")
  
  if not writer_index then
    return
  end
  
  -- Get current phrase
  local phrase = song.selected_phrase
  if not phrase then
    return
  end
  
  -- Get the actual Amplitude value from the Writer LFO
  local writer_value = master_track.devices[writer_index].parameters[4].value
  
  -- Scale the value according to current_range
  local lpb_value = scale_value(writer_value, current_range)
  
  -- Set the LPB value
  phrase.lpb = lpb_value
end

function toggle_lpb_following(range)
  local song = renoise.song()
  
  -- Check if timer is already running
  if renoise.tool():has_timer(follow_to_lpb) then
    -- Stop and cleanup
    renoise.tool():remove_timer(follow_to_lpb)
    follow_lpb_timer = nil
    is_following_lpb = false
    -- Remove the LFO devices
    if preferences.PakettiLFOWriteDelete.value == true then
    remove_lfo_devices()
    end
    print("LFO Writer LPB Phrase following stopped")
    renoise.app():show_status("LFO Writer LPB Phrase following stopped")
  else
    -- First remove any existing devices (cleanup)
    if preferences.PakettiLFOWriteDelete.value == true then
    remove_lfo_devices()
    end

    -- Set the range
    current_range = range or 255
    
    -- Then create fresh devices
    if create_lfo_devices() then
      follow_lpb_timer = renoise.tool():add_timer(follow_to_lpb, 0.01)
      is_following_lpb = true
      print("LFO Writer LPB Phrase following started (Range: 1-" .. current_range .. ")")
      renoise.app():show_status("LFO Writer LPB Phrase following started (Range: 1-" .. current_range .. ")")
    else
      print("Error: Could not create LFO devices")
      renoise.app():show_status("Error: Could not create LFO devices")
    end
  end
end

-- Add menu entries for different ranges
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:LFO Write..:LFO Write to Phrase LPB (1-255)",invoke = function() toggle_lpb_following(255) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:LFO Write..:LFO Write to Phrase LPB (1-127)",invoke = function() toggle_lpb_following(127) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:LFO Write..:LFO Write to Phrase LPB (1-64)",invoke = function() toggle_lpb_following(64) end}
renoise.tool():add_menu_entry{name="--Mixer:Paketti..:LFO Write..:LFO Write to Phrase LPB (1-255)",invoke = function() toggle_lpb_following(255) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:LFO Write..:LFO Write to Phrase LPB (1-127)",invoke = function() toggle_lpb_following(127) end}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:LFO Write..:LFO Write to Phrase LPB (1-64)",invoke = function() toggle_lpb_following(64) end}
renoise.tool():add_keybinding{name="Global:Paketti:LFO Write to Phrase LPB (1-255)",invoke = function() toggle_lpb_following(255) end}
renoise.tool():add_keybinding{name="Global:Paketti:LFO Write to Phrase LPB (1-127)",invoke = function() toggle_lpb_following(127) end}
renoise.tool():add_keybinding{name="Global:Paketti:LFO Write to Phrase LPB (1-64)",invoke = function() toggle_lpb_following(64) end}




-------
-- Global variables for parameter following
local is_following_single_parameter = false
local single_follow_timer = nil

function create_single_lfo_device()
  local song = renoise.song()
  local master_track = song.tracks[song.sequencer_track_count + 1]
  
  -- Find or create the Single Writer device
  local writer_index = find_device_by_name(master_track, "Paketti Single LFO Writer")
  if not writer_index then
    local writer_device = master_track:insert_device_at("Audio/Effects/Native/*LFO", 2)
    writer_device.display_name = "Paketti Single LFO Writer"
    writer_device.parameters[4].show_in_mixer = true
  end
  
  return true
end



function remove_single_lfo_device()
  local song = renoise.song()
  local master_track = song.tracks[song.sequencer_track_count + 1]
  
  -- Find and remove the LFO device
  for i, device in ipairs(master_track.devices) do
    if device.display_name == "Paketti Single LFO Writer" then
      master_track:delete_device_at(i)
      break
    end
  end
end

function find_single_device_by_name(track, name)
  for i, device in ipairs(track.devices) do
    if device.name == name then
      return i
    end
  end
  return nil
end

function follow_single_parameter()
  local song = renoise.song()
  local automation_parameter = song.selected_automation_parameter
  local master_track = song.tracks[song.sequencer_track_count + 1]
  -- Find our device
  local writer_index = find_device_by_name(master_track, "Paketti Single LFO Writer")
  if not writer_index then
    return
  end
  
  -- Get the value from the found device's amplitude
  local writer_value = master_track.devices[writer_index].parameters[4].value
  
  -- Rest of the function remains the same
  if not automation_parameter or not automation_parameter.is_automatable then
    return
  end
  
  local track_automation = song:pattern(song.selected_pattern_index):track(song.selected_track_index)
  local envelope = track_automation:find_automation(automation_parameter)
  
  if not envelope then
    envelope = track_automation:create_automation(automation_parameter)
  end

  local playhead_line = song.transport.playback_pos.line
  envelope:add_point_at(playhead_line, writer_value)
end

function toggle_single_parameter_following()
  -- Check if timer is already running

  if renoise.tool():has_timer(follow_single_parameter) then
    -- Stop and cleanup
    renoise.tool():remove_timer(follow_single_parameter)
    single_follow_timer = nil
    is_following_single_parameter = false
    -- Remove the LFO device
    if preferences.PakettiLFOWriteDelete.value == true then
    remove_single_lfo_device()
    end
    print("LFO Writer Single parameter following stopped")
    renoise.app():show_status("LFO Writer Single Parameter following stopped")
  else
    -- First remove any existing device (cleanup)
    if preferences.PakettiLFOWriteDelete.value == true then
    remove_single_lfo_device()
    end
    -- Then create fresh device
--    renoise.song().selected_track_index=renoise.song().sequencer_track_count+1
    renoise.app().window.active_middle_frame=2
    renoise.app().window.lower_frame_is_visible=true
    renoise.app().window.active_lower_frame=2
  
    if create_single_lfo_device() then
      single_follow_timer = renoise.tool():add_timer(follow_single_parameter, 0.001)
      is_following_single_parameter = true
      print("LFO Writer Single parameter following started")
      renoise.app():show_status("LFO Writer Single Parameter following started")
    else
      print("Error: Could not create LFO device")
      renoise.app():show_status("Error: Could not create LFO device")
    end
  end
end

-- Add menu entries and keybinding
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:LFO Write..:Single Parameter Write to Automation",invoke = toggle_single_parameter_following}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:LFO Write..:Single Parameter Write to Automation",invoke = toggle_single_parameter_following}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:LFO Write..:Single Parameter Write to Automation",invoke = toggle_single_parameter_following}
renoise.tool():add_keybinding{name="Global:Paketti:LFO Write Single Parameter Write to Automation",invoke = toggle_single_parameter_following}
--------------
function read_fx_to_automation()
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track = song.selected_track
  local track_index = song.selected_track_index

  -- Store automations by device number and parameter name
  local automation_cache = {}

  -- Get number of visible effect columns
  local num_effect_columns = track.visible_effect_columns
  print(string.format("Processing %d effect columns in pattern", num_effect_columns))

  -- Helper function to get or create automation for a specific device and parameter
  local function get_or_create_cached_automation(device_num, param)
    if not automation_cache[device_num] then
      automation_cache[device_num] = {}
    end
    
    if not automation_cache[device_num][param.name] then
      local automation = get_or_create_automation(param, song.selected_pattern_index, track_index)
      automation_cache[device_num][param.name] = automation
      print(string.format("Created new automation for device %d parameter: %s", device_num, param.name))
    end
    return automation_cache[device_num][param.name]
  end

  for line_index = 1, pattern.number_of_lines do
    local line = pattern:track(track_index):line(line_index)
    
    for column_index = 1, num_effect_columns do
      local fx_column = line.effect_columns[column_index]
      
      if not fx_column.is_empty then
        local number = fx_column.number_string
        local amount = tonumber(fx_column.amount_string, 16)
        
        if number and amount then
          amount = amount / 255  -- Normalize to 0-1 range
          print(string.format("\nLine %d, Column %d: Found effect %s with value %x (normalized: %.3f)", 
                            line_index, column_index, number, amount * 255, amount))
          
          local param = nil
          local device_num = nil
          
          -- Handle mixer commands (0L, 0P, 0W)
          if number == "0L" then
            param = track.devices[1].parameters[1]  -- Volume
            device_num = 1
            print("Processing Mixer Volume parameter")
          elseif number == "0P" then
            param = track.devices[1].parameters[2]  -- Panning
            device_num = 1
            print("Processing Mixer Panning parameter")
          elseif number == "0W" then
            param = track.devices[1].parameters[3]  -- Width
            device_num = 1
            print("Processing Mixer Width parameter")
          
          -- Handle device parameters (11-1Y, 21-2Y, etc.)
          elseif #number == 2 then
            -- First character can be 1-9 or A-Y
            local device_char = string.sub(number, 1, 1)
            local param_char = string.sub(number, 2, 2)
            
            -- Convert device character to number
            if device_char >= "1" and device_char <= "9" then
              device_num = tonumber(device_char)
            elseif device_char >= "A" and device_char <= "Y" then
              -- A = 10, B = 11, etc.
              device_num = string.byte(device_char) - string.byte("A") + 10
            end
            
            local param_num = tonumber(param_char, 36)  -- Keep base 36 for params
            
            if device_num and param_num then
              print(string.format("Converting effect %s: device %s (%d) parameter %s (%d)", 
                                number, device_char, device_num, param_char, param_num))
              
              if device_num > 0 and device_num <= #track.devices then
                local device = track.devices[device_num + 1]  -- +1 because device 1 in FX is second device
                if device and param_num <= #device.parameters then
                  param = device.parameters[param_num]
                  if param then
                    print(string.format("Line %d: Effect %s -> Device %d, Parameter %d (%s), Value: %.3f", 
                                    line_index, number, device_num, param_num, param.name, amount))
                    
                    if param.is_automatable then
                      local automation = get_or_create_cached_automation(device_num, param)
                      if automation then
                        automation:add_point_at(line_index, amount)
                        -- Set playmode using proper Renoise enum values
                        if preferences.pakettiAutomationFormat.value == 1 then
                          automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_LINES
                        elseif preferences.pakettiAutomationFormat.value == 2 then
                          automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_POINTS
                        else
                          automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_CURVES
                        end
                        print(string.format("Added point to automation for device %d %s at line %d with value %.3f", 
                                        device_num, param.name, line_index, amount))
                      end
                    else
                      print(string.format("WARNING: Parameter %s is not automatable!", param.name))
                    end
                  else
                    print(string.format("WARNING: Invalid parameter %d for device %d", param_num, device_num))
                  end
                else
                  print(string.format("WARNING: Parameter number %d out of range for device %d", param_num, device_num))
                end
              else
                print(string.format("WARNING: Device number %d out of range", device_num))
              end
            else
              print(string.format("WARNING: Could not parse effect command: %s (device: %s, param: %s)", 
                                number, device_char, param_char))
            end
          end
        end
      end
    end
  end

  -- Print changes before final summary
  print("\nChanges made:")
  for device_num, device_automations in pairs(automation_cache) do
    for param_name, automation in pairs(device_automations) do
      print(string.format("\nDevice %d Parameter: %s", device_num, param_name))
      for _, point in ipairs(automation.points) do
        print(string.format("  Line %d: %.3f", point.time, point.value))
      end
    end
  end

  -- Final summary
  print("\nAutomation Summary:")
  for device_num, device_automations in pairs(automation_cache) do
    for param_name, automation in pairs(device_automations) do
      print(string.format("Device %d Parameter '%s' has %d automation points", 
                        device_num, param_name, #automation.points))
    end
  end
end




function snapshot_current_values_to_automation()
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track = song.selected_track
  local track_index = song.selected_track_index

  -- Helper function to normalize value to 0-1 range
  local function normalize_value(param)
    return (param.value - param.value_min) / (param.value_max - param.value_min)
  end

  -- Maximum number of devices (Y = 35 in base 36, since we want to include Y)
  local max_devices = 35

  -- Only process up to max_devices or actual device count, whichever is smaller
  local num_devices = math.min(#track.devices, max_devices)

  for device_index = 1, num_devices do
    local device = track.devices[device_index]
    -- Convert device index to FX notation (1-9, A-Y)
    local device_char
    if device_index <= 9 then
      device_char = tostring(device_index)
    else
      -- Convert 10-35 to A-Y (25 letters)
      device_char = string.char(string.byte("A") + device_index - 10)
    end

    print(string.format("Processing device %s (%d)", device_char, device_index))

    -- Start from 1 (including Active/Bypassed)
    for param_index = 1, #device.parameters do
      local param = device.parameters[param_index]
      if param.is_automatable then
        local automation = get_or_create_automation(param, song.selected_pattern_index, track_index)
        local value = normalize_value(param)
        automation:add_point_at(1, value)
        
        -- Set playmode using proper Renoise enum values
        if preferences.pakettiAutomationFormat.value == 1 then
          automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_LINES
        elseif preferences.pakettiAutomationFormat.value == 2 then
          automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_POINTS
        else
          automation.playmode = renoise.PatternTrackAutomation.PLAYMODE_CURVES
        end
        
        print(string.format("Created automation for device %s parameter %d (%s) with value %.3f", 
                          device_char, param_index, param.name, value))
      end
    end
  end
end


renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Automation..:Snapshot Current Device Values to Automation",invoke = snapshot_current_values_to_automation}
renoise.tool():add_menu_entry{name="--Mixer:Paketti..:Automation..:Snapshot Current Device Values to Automation",invoke = snapshot_current_values_to_automation}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti..:Automation..:Snapshot Current Device Values to Automation",invoke = snapshot_current_values_to_automation}
renoise.tool():add_keybinding{name="Global:Paketti:Snapshot Current Device Values to Automation",invoke = snapshot_current_values_to_automation}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Automation..:Convert FX to Automation",invoke = read_fx_to_automation}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Automation..:Convert FX to Automation",invoke = read_fx_to_automation}
renoise.tool():add_menu_entry{name="Mixer:Paketti..:Automation..:Convert FX to Automation",invoke = read_fx_to_automation}
renoise.tool():add_keybinding{name="Global:Paketti:Convert FX to Automation",invoke = read_fx_to_automation}