local STEPPER_TYPES = {
    PITCH = "Pitch Stepper",
    VOLUME = "Volume Stepper",
    PAN = "Panning Stepper",
    CUTOFF = "Cutoff Stepper",
    RESONANCE = "Resonance Stepper",
    DRIVE = "Drive Stepper"
}

local vb=renoise.ViewBuilder()
local dialog=nil

local stepsize_switch = nil
local stepper_switch = nil
local stepcount_text = nil
local updating_switch = false
local updating_stepper_switch = false
local copied_stepper_data = nil
local offset_slider = nil
local updating_offset_slider = false

function pakettiPitchStepperDemo()
  if dialog and dialog.visible then
    dialog:close()
    dialog=nil
    return
  end

  PakettiShowStepper("Pitch Stepper")

  dialog=renoise.app():show_custom_dialog("PitchStepper Demo",
    vb:column{
      vb:button{text="Show PitchStepper",pressed=function() PakettiShowStepper("Pitch Stepper") end},
      vb:button{text="Fill Two Octaves",pressed=function() PakettiFillPitchStepperTwoOctaves() end},
      vb:button{text="Fill with Random Steps",pressed=function() PakettiFillStepperRandom("Pitch Stepper") end},
      vb:button{text="Fill Octave Up/Down",pressed=function() PakettiFillPitchStepper() end},
      vb:button{text="Clear Pitch Stepper",pressed=function() PakettiClearStepper("Pitch Stepper") end},
      vb:button{text="Fill with Digits (0.05, 64)",pressed=function() PakettiFillPitchStepperDigits(0.05,64) end},
      vb:button{text="Fill with Digits (0.015, 64)",pressed=function() PakettiFillPitchStepperDigits(0.015,64) end},
    },my_keyhandler_func)
end

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments..:PitchStepper Demo",invoke=function() pakettiPitchStepperDemo() end}
renoise.tool():add_menu_entry{name="--Sample Modulation Matrix:Paketti..:PitchStepper Demo",invoke=function() pakettiPitchStepperDemo() end}
renoise.tool():add_keybinding{name="Global:Paketti:PitchStepper Demo",invoke=function() pakettiPitchStepperDemo() end}
---
function ResetAllSteppers(clear)
    local song = renoise.song()
    local count = 0
    local stepperTypes = {"Pitch Stepper", "Volume Stepper", "Panning Stepper", 
                         "Cutoff Stepper", "Resonance Stepper", "Drive Stepper"}
    
    for inst_idx, instrument in ipairs(song.instruments) do
        if instrument.samples[1] and instrument.sample_modulation_sets[1] then
            local devices = instrument.sample_modulation_sets[1].devices
            for dev_idx, device in ipairs(devices) do
                for _, stepperType in ipairs(stepperTypes) do
                    if device.name == stepperType then
                        -- Reset the device parameter
                        device.parameters[1].value = 1
                        
                        -- Only clear data if clear parameter is true
                        if clear then
                            -- Clear existing points first
                            device:clear_points()
                            
                            -- Get the total number of steps from device length
                            local total_steps = device.length
                            local default_value = 0.5  -- Default for most steppers
                            
                            -- Set specific default values based on stepper type
                            if device.name == "Volume Stepper" then
                                default_value = 1
                            elseif device.name == "Cutoff Stepper" then
                                default_value = 1
                            elseif device.name == "Resonance Stepper" then
                                default_value = 0
                            elseif device.name == "Drive Stepper" then
                                default_value = 0
                            end
                            
                            local points_data = {}
                            -- Reset ALL steps from 1 to device.length
                            for step = 1, total_steps do
                                table.insert(points_data, {
                                    scaling = 0,
                                    time = step,
                                    value = default_value
                                })
                            end
                            
                            device.points = points_data
                        end
                        
                        count = count + 1
                    end
                end
            end
        end
    end
    
    if count > 0 then
        if clear then
            renoise.app():show_status(string.format("Reset data and parameters for %d Stepper device(s)", count))
        else
            renoise.app():show_status(string.format("Reset parameters for %d Stepper device(s)", count))
        end
    else 
        renoise.app():show_status("No Stepper devices found")
    end
end
---
renoise.tool():add_keybinding{name="Global:Paketti:Reset All Steppers",invoke = ResetAllSteppers}
renoise.tool():add_menu_entry{name="--Sample Modulation Matrix:Paketti..:Reset All Steppers",invoke = ResetAllSteppers}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments..:Reset All Steppers",invoke = ResetAllSteppers}
----
local function findStepperDeviceIndex(deviceName)
    local instrument = renoise.song().selected_instrument
    if not instrument or not instrument.sample_modulation_sets[1] then return nil end
    
    local devices = instrument.sample_modulation_sets[1].devices
    for i = 1, #devices do
        if devices[i].name == deviceName then
            return i
        end
    end
    return nil
end
---
function PakettiFillStepperRandom(deviceName)
    local instrument = renoise.song().selected_instrument
    
    -- Check if there's a valid instrument with modulation devices
    if not instrument or not instrument.sample_modulation_sets[1] then
        renoise.app():show_status("No valid instrument or modulation devices found.")
        return
    end
    
    local deviceIndex = findStepperDeviceIndex(deviceName)
    if not deviceIndex then
        renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
        return
    end
    
    local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
    
    -- Set range (this might need to be configurable per device type)
    if deviceName == "Pitch Stepper" then
        instrument.sample_modulation_sets[1].pitch_range = 12
    end
    
    -- Clear existing points and fill with random values
    device:clear_points()
    local points_data = {}
    for i = 1, device.length do
        table.insert(points_data, {
            scaling = 0,
            time = i,
            value = math.random()
        })
    end

    -- Assign the random points data
    device.points = points_data
    renoise.app():show_status(string.format("%s random points filled successfully.", deviceName))
end

function PakettiFillPitchStepperTwoOctaves()
local instrument = renoise.song().selected_instrument

-- Check if there's a valid instrument with modulation devices
if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
end

-- Search through all devices for Pitch Stepper
local devices = instrument.sample_modulation_sets[1].devices
local device = nil

for i = 1, #devices do
    if devices[i].name == "Pitch Stepper" then
        device = devices[i]
        break
    end
end

if not device then
    renoise.app():show_status("There is no Pitch Stepper modulation device in this instrument, doing nothing.")
    return
end

if device.name == "Pitch Stepper" then
    device.length = 17
    device:clear_points()  
    instrument.sample_modulation_sets[1].pitch_range = 24  
    local points_data = {
        {scaling=0, time=1, value=0.5},
        {scaling=0, time=2, value=0.25},
        {scaling=0, time=3, value=0},
        {scaling=0, time=4, value=0.25},
        {scaling=0, time=5, value=0.5},
        {scaling=0, time=6, value=0.75},
        {scaling=0, time=7, value=1},
        {scaling=0, time=8, value=0.75},
        {scaling=0, time=9, value=0.5},
        {scaling=0, time=10, value=0.25},
        {scaling=0, time=11, value=0},
        {scaling=0, time=12, value=0.25},
        {scaling=0, time=13, value=0.5},
        {scaling=0, time=14, value=0.75},
        {scaling=0, time=15, value=1},
        {scaling=0, time=16, value=0.75},
        {scaling=0, time=17, value=0.5},
    }

    device.points = points_data
    renoise.app():show_status("Pitch Stepper points filled successfully.")
else 
    renoise.app():show_status("Selected device is not a Pitch Stepper.") 
end
end

function PakettiFillPitchStepper()
local instrument = renoise.song().selected_instrument
  
-- Check if there's a valid instrument with modulation devices
if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
end

-- Search through all devices for Pitch Stepper
local devices = instrument.sample_modulation_sets[1].devices
local device = nil

for i = 1, #devices do
    if devices[i].name == "Pitch Stepper" then
        device = devices[i]
        break
    end
end

if not device then
    renoise.app():show_status("There is no Pitch Stepper modulation device in this instrument, doing nothing.")
    return
end

  if device.name == "Pitch Stepper" then
      device.length=17
      device:clear_points()    
      local points_data = {
          {scaling=0, time=1, value=0.5},
          {scaling=0, time=2, value=0},
          {scaling=0, time=3, value=1},
          {scaling=0, time=4, value=0},
          {scaling=0, time=5, value=1},
          {scaling=0, time=6, value=0},
          {scaling=0, time=7, value=1},
          {scaling=0, time=8, value=0},
          {scaling=0, time=9, value=1},
          {scaling=0, time=10, value=0},
          {scaling=0, time=11, value=1},
          {scaling=0, time=12, value=0},
          {scaling=0, time=13, value=1},
          {scaling=0, time=14, value=0},
          {scaling=0, time=15, value=1},
          {scaling=0, time=16, value=0},
      }

          device.points=points_data
       renoise.song().selected_instrument.sample_modulation_sets[1].pitch_range=12

      renoise.app():show_status("Pitch Stepper points filled successfully.")
  else renoise.app():show_status("Selected device is not a Pitch Stepper.") end
end

function PakettiClearStepper(deviceName)
    local instrument = renoise.song().selected_instrument
    
    -- Check if there's a valid instrument with modulation devices
    if not instrument or not instrument.sample_modulation_sets[1] then
        renoise.app():show_status("No valid instrument or modulation devices found.")
        return
    end
    
    local deviceIndex = findStepperDeviceIndex(deviceName)
    if not deviceIndex then
        renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
        return
    end
    
    local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
    device:clear_points()
    renoise.app():show_status(string.format("%s points cleared successfully.", deviceName))
end

-- Create menu entries and keybindings for each stepper type
for _, stepperType in pairs(STEPPER_TYPES) do
    local baseText = stepperType:gsub(" Stepper", "")
    renoise.tool():add_keybinding{name=string.format("Global:Paketti:Clear %s Steps", baseText),
        invoke=function() PakettiClearStepper(stepperType) end
    }
    renoise.tool():add_menu_entry{name=string.format("Sample Modulation Matrix:Paketti..:Clear %s Steps", baseText),invoke=function() PakettiClearStepper(stepperType) end
    }
end

renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti..:Show/Hide PitchStep on Selected Instrument",invoke=function() PakettiShowStepper("Pitch Stepper") end}
renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti..:Show/Hide VolumeStep on Selected Instrument",invoke=function() PakettiShowStepper("Volume Stepper") end}

renoise.tool():add_keybinding{name="Global:Paketti:Modify PitchStep Steps (Random)",invoke=function() PakettiFillStepperRandom("Pitch Stepper") end}
renoise.tool():add_keybinding{name="Global:Paketti:Modify PitchStep Steps (Octave Up, Octave Down)",invoke=function() PakettiFillPitchStepper() end}
renoise.tool():add_keybinding{name="Global:Paketti:Modify PitchStep Steps (Hard Detune)",invoke=function() PakettiFillPitchStepperDigits(0.05,64) end}
renoise.tool():add_keybinding{name="Global:Paketti:Clear PitchStep Steps",invoke=function() PakettiClearStepper("Pitch Stepper") end}

renoise.tool():add_keybinding{name="Global:Paketti:Modify PitchStep Steps (Octave Up+2, Octave Down-2)",invoke=function() PakettiFillPitchStepperTwoOctaves() end}
renoise.tool():add_keybinding{name="Global:Paketti:Modify PitchStep Steps (Minor Flurry)",invoke=function() PakettiFillPitchStepperDigits(0.015,64) end}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Modify PitchStep Steps (Minor Flurry)",invoke=function() PakettiFillPitchStepperDigits(0.015,64) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:Modify PitchStep Steps (Minor Flurry)",invoke=function() PakettiFillPitchStepperDigits(0.015,64) end}    
renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti..:Clear PitchStep Steps",invoke=function() PakettiClearStepper("Pitch Stepper") end}

renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti..:Modify PitchStep Steps (Random)",invoke=function() PakettiFillStepperRandom("Pitch Stepper") end}
renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti..:Modify PitchStep Steps (Octave Up, Octave Down)",invoke=function() PakettiFillPitchStepper() end}
renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti..:Modify PitchStep Steps (Octave Up+2, Octave Down-2)",invoke=function() PakettiFillPitchStepperTwoOctaves() end}
renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti..:Modify PitchStep Steps (Minor Flurry)",invoke=function() PakettiFillPitchStepperDigits(0.015,64) end}
renoise.tool():add_menu_entry{name="Sample Modulation Matrix:Paketti..:Modify PitchStep Steps (Hard Detune)",invoke=function() PakettiFillPitchStepperDigits(0.05,64) end}

function PakettiFillPitchStepperDigits(detune_amount, step_count)
  local instrument = renoise.song().selected_instrument
  
  -- Check if there's a valid instrument with modulation devices
  if not instrument or not instrument.sample_modulation_sets[1] then
      renoise.app():show_status("No valid instrument or modulation devices found.")
      return
  end
  
  -- Search through all devices for Pitch Stepper
  local devices = instrument.sample_modulation_sets[1].devices
  local device = nil
  
  for i = 1, #devices do
      if devices[i].name == "Pitch Stepper" then
          device = devices[i]
          break
      end
  end
  
  if not device then
      renoise.app():show_status("There is no Pitch Stepper modulation device in this instrument, doing nothing.")
      return
  end

if device.name == "Pitch Stepper" then
  device.length = step_count
  device:clear_points()
  
  local points_data = {}
  -- First point starts at center
  table.insert(points_data, {scaling=0, time=1, value=0.5})
  
  -- Generate random detune values within the range
  for i = 2, device.length do
    local random_detune = math.random() * detune_amount
    local up_or_down = math.random() < 0.5 and -1 or 1
    table.insert(points_data, {
      scaling = 0,
      time = i,
      value = 0.5 + (random_detune * up_or_down)
    })
  end

  device.points = points_data
  renoise.song().selected_instrument.sample_modulation_sets[1].pitch_range = 2

  renoise.app():show_status("Pitch Stepper random detune points filled successfully.")
else 
  renoise.app():show_status("Selected device is not a Pitch Stepper.") 
end
end
-----

local isPitchStepSomewhere

function PakettiGetVisibleStepperStepSize()
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    return 64 -- default
  end
  
  local devices = instrument.sample_modulation_sets[1].devices
  local stepperTypes = {"Pitch Stepper", "Volume Stepper", "Panning Stepper", 
                       "Cutoff Stepper", "Resonance Stepper", "Drive Stepper"}
  
  for _, device in ipairs(devices) do
    for _, stepperType in ipairs(stepperTypes) do
      if device.name == stepperType and device.external_editor_visible then
        return device.length
      end
    end
  end
  
  return 64 -- default if no visible stepper
end

function PakettiGetVisibleStepperType()
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    return 0 -- no selection
  end
  
  local devices = instrument.sample_modulation_sets[1].devices
  local stepperTypes = {"Volume Stepper", "Panning Stepper", "Pitch Stepper", 
                       "Cutoff Stepper", "Resonance Stepper", "Drive Stepper"}
  
  for _, device in ipairs(devices) do
    for i, stepperType in ipairs(stepperTypes) do
      if device.name == stepperType and device.external_editor_visible then
        return i
      end
    end
  end
  
  return 0 -- no visible stepper
end

function PakettiUpdateStepSizeSwitch()
  if stepsize_switch and not updating_switch then
    updating_switch = true
    local current_size = PakettiGetVisibleStepperStepSize()
    local step_sizes = {4, 8, 16, 32, 64, 128, 256}
    
    for i, size in ipairs(step_sizes) do
      if size == current_size then
        stepsize_switch.value = i
        break
      end
    end
    updating_switch = false
  end
  -- Update step count display
  PakettiUpdateStepCountText()
end

function PakettiUpdateStepCountText()
  if stepcount_text then
    local current_size = PakettiGetVisibleStepperStepSize()
    stepcount_text.text = tostring(current_size)
  end
end

function PakettiUpdateStepperSwitch()
  if stepper_switch and not updating_stepper_switch then
    updating_stepper_switch = true
    local current_stepper = PakettiGetVisibleStepperType()
    -- Convert 0-based to 1-based indexing (0 = no stepper = index 1 "Off")
    stepper_switch.value = current_stepper + 1
    updating_stepper_switch = false
  end
  -- Update step count display when stepper changes
  PakettiUpdateStepCountText()
end

function PakettiChangeVisibleStepperStepSize(step_size)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local devices = instrument.sample_modulation_sets[1].devices
  local changed_count = 0
  local stepperTypes = {"Pitch Stepper", "Volume Stepper", "Panning Stepper", 
                       "Cutoff Stepper", "Resonance Stepper", "Drive Stepper"}
  
  for _, device in ipairs(devices) do
    for _, stepperType in ipairs(stepperTypes) do
      if device.name == stepperType and device.external_editor_visible then
        -- Only change the length, preserve existing data!
        device.length = step_size
        changed_count = changed_count + 1
      end
    end
  end
  
  if changed_count > 0 then
    renoise.app():show_status(string.format("Changed %d visible stepper(s) to %d steps", changed_count, step_size))
  else
    renoise.app():show_status("No visible steppers found")
  end
end

function PakettiShowStepper(deviceName)
    local instrument = renoise.song().selected_instrument
    
    if not instrument or not instrument.samples[1] then
        renoise.app():show_status("No valid Instrument/Sample selected, doing nothing.")
        return
    end
    
    if not instrument.sample_modulation_sets[1] then
        renoise.app():show_status("This Instrument has no modulation devices, doing nothing.")
        return
    end
    
    local deviceIndex = findStepperDeviceIndex(deviceName)
    if not deviceIndex then
        renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
        return
    end
    
    local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
    local was_visible = device.external_editor_visible
    device.external_editor_visible = not was_visible
    
    -- Lock keyboard focus when opening the editor
    if not was_visible then
        renoise.app().window.lock_keyboard_focus = true
    end
    
    isPitchStepSomewhere = renoise.song().selected_track_index
    renoise.app():show_status(string.format("%s visibility toggled.", deviceName))
    
    -- Update both switches to reflect the current state
    PakettiUpdateStepSizeSwitch()
    PakettiUpdateStepperSwitch()
end
renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide PitchStep on Selected Instrument",invoke=function() PakettiShowStepper("Pitch Stepper") end}
renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide VolumeStep on Selected Instrument",invoke=function() PakettiShowStepper("Volume Stepper") end}
renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide CutoffStep on Selected Instrument",invoke=function() PakettiShowStepper("Cutoff Stepper") end}
renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide ResonanceStep on Selected Instrument",invoke=function() PakettiShowStepper("Resonance Stepper") end}
renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide DriveStep on Selected Instrument",invoke=function() PakettiShowStepper("Drive Stepper") end}
renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide PanningStep on Selected Instrument",invoke=function() PakettiShowStepper("Panning Stepper") end}

--------

function PakettiSetStepperVisible(deviceName, visible, skip_switch_update)
    local instrument = renoise.song().selected_instrument
    
    if not instrument or not instrument.samples[1] then
        if visible then
            renoise.app():show_status("No valid Instrument/Sample selected, doing nothing.")
        end
        return
    end
    
    if not instrument.sample_modulation_sets[1] then
        if visible then
            renoise.app():show_status("This Instrument has no modulation devices, doing nothing.")
        end
        return
    end
    
    local deviceIndex = findStepperDeviceIndex(deviceName)
    if not deviceIndex then
        if visible then
            renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
        end
        return
    end
    
    local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
    device.external_editor_visible = visible
    
    -- Lock keyboard focus when opening the editor
    if visible then
        renoise.app().window.lock_keyboard_focus = true
        isPitchStepSomewhere = renoise.song().selected_track_index
    end
    
    -- Only update switches if not called from switch notifier
    if not skip_switch_update then
        PakettiUpdateStepSizeSwitch()
        PakettiUpdateStepperSwitch()
    else
        -- Still update step size switch since that's independent
        PakettiUpdateStepSizeSwitch()
    end
end

function PakettiSteppersDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog=nil
    return
  end

  -- Create stepper type switch
  stepper_switch = vb:switch{
    items = {"Off", "Volume", "Panning", "Pitch", "Cutoff", "Resonance", "Drive"},
    width = 453,
    value = 1, -- default to Off
    notifier = function(value)
      if not updating_stepper_switch then
        local stepperTypes = {"Volume Stepper", "Panning Stepper", "Pitch Stepper", 
                             "Cutoff Stepper", "Resonance Stepper", "Drive Stepper"}
        
        -- First hide all visible steppers
        local instrument = renoise.song().selected_instrument
        if instrument and instrument.sample_modulation_sets[1] then
          local devices = instrument.sample_modulation_sets[1].devices
          for _, device in ipairs(devices) do
            for _, stepperType in ipairs(stepperTypes) do
              if device.name == stepperType then
                device.external_editor_visible = false
              end
            end
          end
        end
        
        -- Then show the selected stepper (if not "Off")
        if value > 1 then
          PakettiSetStepperVisible(stepperTypes[value - 1], true, true) -- skip_switch_update = true
        else
          PakettiUpdateStepSizeSwitch()
        end
      end
    end
  }

  -- Create step size switch
  stepsize_switch = vb:switch{
    items={"4","8","16","32","64","128","256"},
    width=300,
    value = 5, -- default to 64 (now at index 5)
    notifier = function(value)
      if not updating_switch then
        local step_sizes = {4, 8, 16, 32, 64, 128, 256}
        PakettiChangeVisibleStepperStepSize(step_sizes[value])
        PakettiUpdateStepCountText()
      end
    end
  }

  -- Update switches to current state
  PakettiUpdateStepperSwitch()
  PakettiUpdateStepSizeSwitch()

  -- Create step count text view
  stepcount_text = vb:text{text = "64", style="strong", width=40}

  -- Create offset slider
  offset_slider = vb:slider{
    min = -0.5,
    max = 0.5,
    value = 0,
    width = 200,
    notifier = function(value)
      if not updating_offset_slider then
        PakettiOffsetVisibleStepperValues(value)
        -- Reset slider to center after applying offset
        updating_offset_slider = true
        offset_slider.value = 0
        updating_offset_slider = false
      end
    end
  }

  dialog = renoise.app():show_custom_dialog("Paketti Steppers",
    vb:column{
      vb:row{
        vb:text{text = "Stepper", style="strong", font="Bold", width=70},
        stepper_switch
      },
      vb:row{
        vb:text{text = "Step Size", style="strong", font="Bold", width=70},
        stepsize_switch,
        vb:button{text = "Random Size", width=85, pressed = function() PakettiRandomizeVisibleStepperStepSize() end},
        vb:text{text = "Steps: ", width=50},
        stepcount_text
      },
      vb:row{
        vb:text{text = "Offset", style="strong", font="Bold", width=70},
        offset_slider,
        vb:text{text = "← Down | Up →", width=100}
      },
      vb:row{
        vb:text{text = "Actions", style="strong", font="Bold", width=70},
        vb:button{text = "Clear", width=75, pressed = function() PakettiClearVisibleStepper() end},
        vb:button{text = "0.0 (Off)", width=75, pressed = function() PakettiFillVisibleStepperOff() end},
        vb:button{text = "0.5 (Center)", width=85, pressed = function() PakettiFillVisibleStepperMiddle() end},
        vb:button{text = "1.0 (Full)", width=75, pressed = function() PakettiFillVisibleStepperFull() end},
        vb:button{text = "Fluctuate", width=75, pressed = function() PakettiFillVisibleStepperFluctuate() end},
        vb:button{text = "Humanize", width=75, pressed = function() PakettiApplyToVisibleStepper(PakettiFillStepperHumanize) end},
        vb:button{text = "Random", width=75, pressed = function() PakettiApplyToVisibleStepper(PakettiFillStepperRandom) end}
      },
      vb:row{
        vb:text{text = "Waveforms", style="strong", font="Bold", width=70},
        vb:button{text = "Ramp Up", width=75, pressed = function() PakettiFillVisibleStepperRampUp() end},
        vb:button{text = "Ramp Down", width=85, pressed = function() PakettiFillVisibleStepperRampDown() end},
        vb:button{text = "Sinewave", width=75, pressed = function() PakettiFillVisibleStepperSinewave() end},
        vb:button{text = "Squarewave", width=85, pressed = function() PakettiFillVisibleStepperSquarewave() end},
        vb:button{text = "Triangle", width=75, pressed = function() PakettiApplyToVisibleStepper(PakettiFillStepperTriangle) end},
        vb:button{text = "Sawtooth", width=75, pressed = function() PakettiApplyToVisibleStepper(PakettiFillStepperSawtooth) end}
      },
      vb:row{
        vb:text{text = "Modifiers", style="strong", font="Bold", width=70},
        vb:button{text = "Steps", width=75, pressed = function() PakettiApplyToVisibleStepper(PakettiFillStepperSteps) end},
        vb:button{text = "Smooth", width=75, pressed = function() PakettiApplyToVisibleStepper(PakettiSmoothStepperValues) end},
        vb:button{text = "Scale 50%", width=75, pressed = function() PakettiScaleVisibleStepperValues(0.5) end},
        vb:button{text = "Scale 150%", width=85, pressed = function() PakettiScaleVisibleStepperValues(1.5) end},
        vb:button{text = "Quantize", width=75, pressed = function() PakettiApplyToVisibleStepper(PakettiQuantizeStepperValues) end}
      },
      vb:row{
        vb:text{text = "", width=70},
        vb:button{text = "Scale 200%", width=75, pressed = function() PakettiScaleVisibleStepperValues(2.0) end},
        vb:button{text = "Mirror", width=75, pressed = function() PakettiApplyToVisibleStepper(PakettiFillStepperMirror) end},
        vb:button{text = "Flip", width=75, pressed = function() PakettiApplyToVisibleStepper(PakettiFillStepperFlip) end},
        vb:button{text = "Copy", width=75, pressed = function() PakettiCopyStepperData() end},
        vb:button{text = "Paste", width=75, pressed = function() PakettiPasteStepperData() end}
      }
    }, my_keyhandler_func
  )
end

-- Add menu entries and keybinding for the steppers dialog
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:Instruments..:Steppers Dialog", invoke=function() PakettiSteppersDialog() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:Steppers Dialog", invoke=function() PakettiSteppersDialog() end}
renoise.tool():add_keybinding{name="Global:Paketti:Steppers Dialog", invoke=function() PakettiSteppersDialog() end}

-- Add individual stepper show/hide menu entries for instrument box
for _, stepperType in pairs(STEPPER_TYPES) do
    local baseText = stepperType:gsub(" Stepper", "")
    renoise.tool():add_menu_entry{
        name = string.format("--Instrument Box:Paketti..:Show Selected Instrument %s Stepper", baseText),
        invoke = function() PakettiShowStepper(stepperType) end
    }
end

function PakettiGetVisibleStepperName()
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    return nil
  end
  
  local devices = instrument.sample_modulation_sets[1].devices
  local stepperTypes = {"Pitch Stepper", "Volume Stepper", "Panning Stepper", 
                       "Cutoff Stepper", "Resonance Stepper", "Drive Stepper"}
  
  for _, device in ipairs(devices) do
    for _, stepperType in ipairs(stepperTypes) do
      if device.name == stepperType and device.external_editor_visible then
        return stepperType
      end
    end
  end
  
  return nil
end

function PakettiApplyToVisibleStepper(operation_func, ...)
  local visible_stepper = PakettiGetVisibleStepperName()
  print("=== PakettiApplyToVisibleStepper DEBUG ===")
  print("visible_stepper found:", tostring(visible_stepper))
  print("operation_func:", tostring(operation_func))
  
  if not visible_stepper then
    print("ERROR: No stepper is currently visible")
    renoise.app():show_status("No stepper is currently visible")
    return
  end
  
  print("About to call operation_func with:", visible_stepper)
  operation_func(visible_stepper, ...)
  print("=== PakettiApplyToVisibleStepper END ===")
end

function PakettiFillVisibleStepperFluctuate()
  local visible_stepper = PakettiGetVisibleStepperName()
  if not visible_stepper then
    renoise.app():show_status("No stepper is currently visible")
    return
  end
  
  -- For Pitch Stepper, use minor flurry but preserve current step count
  -- For other steppers, use gentle random variation
  if visible_stepper == "Pitch Stepper" then
    local instrument = renoise.song().selected_instrument
    if instrument and instrument.sample_modulation_sets[1] then
      local deviceIndex = findStepperDeviceIndex(visible_stepper)
      if deviceIndex then
        local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
        local current_step_count = device.length
        PakettiFillPitchStepperDigits(0.015, current_step_count)
      end
    end
  else
    -- Apply gentle fluctuation for other stepper types
    PakettiApplyToVisibleStepper(PakettiFillStepperGentleFluctuation)
  end
end

function PakettiFillStepperGentleFluctuation(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Clear existing points and fill with gentle fluctuation around center values
  device:clear_points()
  local points_data = {}
  local center_value = 0.5
  
  -- Set appropriate center value for different stepper types
  if deviceName == "Volume Stepper" then
    center_value = 0.8
  elseif deviceName == "Cutoff Stepper" then
    center_value = 0.7
  elseif deviceName == "Resonance Stepper" then
    center_value = 0.3
  elseif deviceName == "Drive Stepper" then
    center_value = 0.2
  end
  
  for i = 1, device.length do
    local fluctuation = (math.random() - 0.5) * 0.3 -- ±15% fluctuation
    local value = math.max(0, math.min(1, center_value + fluctuation))
    table.insert(points_data, {
      scaling = 0,
      time = i,
      value = value
    })
  end

  device.points = points_data
  renoise.app():show_status(string.format("%s gentle fluctuation applied successfully.", deviceName))
end

function PakettiClearVisibleStepper()
  PakettiApplyToVisibleStepper(PakettiClearStepper)
end

function PakettiFillVisibleStepperFull()
  PakettiApplyToVisibleStepper(PakettiFillStepperFull)
end

function PakettiFillStepperFull(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Clear existing points and fill with 1.0 for all steps
  device:clear_points()
  local points_data = {}
  
  for i = 1, device.length do
    table.insert(points_data, {
      scaling = 0,
      time = i,
      value = 1.0
    })
  end

  device.points = points_data
  renoise.app():show_status(string.format("%s filled with 1.0 for all steps.", deviceName))
end

function PakettiFillVisibleStepperRampUp()
  PakettiApplyToVisibleStepper(PakettiFillStepperRampUp)
end

function PakettiFillStepperRampUp(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Clear existing points and fill with ramp from 0 to 1
  device:clear_points()
  local points_data = {}
  
  for i = 1, device.length do
    local value = (i - 1) / (device.length - 1)
    table.insert(points_data, {
      scaling = 0,
      time = i,
      value = value
    })
  end

  device.points = points_data
  renoise.app():show_status(string.format("%s filled with ramp up (0→1).", deviceName))
end

function PakettiFillVisibleStepperRampDown()
  PakettiApplyToVisibleStepper(PakettiFillStepperRampDown)
end

function PakettiFillStepperRampDown(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Clear existing points and fill with ramp from 1 to 0
  device:clear_points()
  local points_data = {}
  
  for i = 1, device.length do
    local value = 1.0 - ((i - 1) / (device.length - 1))
    table.insert(points_data, {
      scaling = 0,
      time = i,
      value = value
    })
  end

  device.points = points_data
  renoise.app():show_status(string.format("%s filled with ramp down (1→0).", deviceName))
end

function PakettiFillVisibleStepperMiddle()
  PakettiApplyToVisibleStepper(PakettiFillStepperMiddle)
end

function PakettiFillStepperMiddle(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Clear existing points and fill with 0.5 for all steps
  device:clear_points()
  local points_data = {}
  
  for i = 1, device.length do
    table.insert(points_data, {
      scaling = 0,
      time = i,
      value = 0.5
    })
  end

  device.points = points_data
  renoise.app():show_status(string.format("%s filled with middle (0.5) for all steps.", deviceName))
end

function PakettiFillVisibleStepperSinewave()
  PakettiApplyToVisibleStepper(PakettiFillStepperSinewave)
end

function PakettiFillStepperSinewave(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Clear existing points and fill with sine wave
  device:clear_points()
  local points_data = {}
  
  for i = 1, device.length do
    -- Create sine wave: 0.5 + 0.5 * sin(2π * (i-1) / device.length)
    local angle = 2 * math.pi * (i - 1) / device.length
    local value = 0.5 + 0.5 * math.sin(angle)
    table.insert(points_data, {
      scaling = 0,
      time = i,
      value = value
    })
  end

  device.points = points_data
  renoise.app():show_status(string.format("%s filled with sine wave pattern.", deviceName))
end

function PakettiFillVisibleStepperSquarewave()
  PakettiApplyToVisibleStepper(PakettiFillStepperSquarewave)
end

function PakettiFillStepperSquarewave(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Clear existing points and fill with square wave (0→1 switching at midpoint)
  device:clear_points()
  local points_data = {}
  local midpoint = math.ceil(device.length / 2)
  
  for i = 1, device.length do
    local value = (i <= midpoint) and 0.0 or 1.0
    table.insert(points_data, {
      scaling = 0,
      time = i,
      value = value
    })
  end

  device.points = points_data
  renoise.app():show_status(string.format("%s filled with square wave (0→1 at midpoint).", deviceName))
end

function PakettiFillVisibleStepperOff()
  PakettiApplyToVisibleStepper(PakettiFillStepperOff)
end

function PakettiFillStepperOff(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Clear existing points and fill with 0.0 for all steps
  device:clear_points()
  local points_data = {}
  
  for i = 1, device.length do
    table.insert(points_data, {
      scaling = 0,
      time = i,
      value = 0.0
    })
  end

  device.points = points_data
  renoise.app():show_status(string.format("%s filled with 0.0 for all steps.", deviceName))
end

function PakettiFillStepperMirror(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  print("=== MIRROR DEBUG START ===")
  print("Device name:", deviceName)
  print("Device length:", device.length)
  print("Current points count:", #device.points)
  
  -- Read current points and mirror all values
  local current_points = {}
  for i = 1, #device.points do
    print(string.format("Original point %d: time=%s, value=%s, scaling=%s", 
          i, tostring(device.points[i].time), tostring(device.points[i].value), tostring(device.points[i].scaling)))
    table.insert(current_points, {
      time = device.points[i].time,
      value = device.points[i].value,
      scaling = device.points[i].scaling
    })
  end
  
  print("Copied points count:", #current_points)
  
  -- Clear and rebuild with mirrored values
  device:clear_points()
  local points_data = {}
  
  for i = 1, #current_points do
    local mirrored_value = 1.0 - current_points[i].value
    local new_point = {
      scaling = current_points[i].scaling,
      time = current_points[i].time,
      value = mirrored_value
    }
    print(string.format("Mirror point %d: time=%s, value=%s (was %s), scaling=%s", 
          i, tostring(new_point.time), tostring(new_point.value), tostring(current_points[i].value), tostring(new_point.scaling)))
    
    -- Validate time before adding
    if new_point.time and new_point.time >= 1 and new_point.time <= device.length then
      table.insert(points_data, new_point)
    else
      print(string.format("ERROR: Invalid time %s for point %d (device.length=%d)", tostring(new_point.time), i, device.length))
    end
  end

  print("Final points_data count:", #points_data)
  print("About to set device.points...")
  
  device.points = points_data
  print("=== MIRROR DEBUG END ===")
  renoise.app():show_status(string.format("%s values mirrored (flipped around center).", deviceName))
end

function PakettiFillStepperFlip(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  print("=== FLIP DEBUG START ===")
  print("Device name:", deviceName)
  print("Device length:", device.length)
  print("Current points count:", #device.points)
  
  -- Read current points and flip their order
  local current_points = {}
  for i = 1, #device.points do
    print(string.format("Original point %d: time=%s, value=%s, scaling=%s", 
          i, tostring(device.points[i].time), tostring(device.points[i].value), tostring(device.points[i].scaling)))
    table.insert(current_points, {
      time = device.points[i].time,
      value = device.points[i].value,
      scaling = device.points[i].scaling
    })
  end
  
  print("Copied points count:", #current_points)
  
  -- Clear and rebuild with flipped values
  device:clear_points()
  local points_data = {}
  
  for i = 1, #current_points do
    -- Keep time sequential, but use values in reverse order
    local flipped_value = current_points[#current_points - i + 1].value
    local new_point = {
      scaling = current_points[i].scaling,
      time = current_points[i].time,
      value = flipped_value
    }
    print(string.format("Flip point %d: time=%s, value=%s (was point %d value %s), scaling=%s", 
          i, tostring(new_point.time), tostring(new_point.value), 
          #current_points - i + 1, tostring(current_points[#current_points - i + 1].value), tostring(new_point.scaling)))
    
    -- Validate time before adding
    if new_point.time and new_point.time >= 1 and new_point.time <= device.length then
      table.insert(points_data, new_point)
    else
      print(string.format("ERROR: Invalid time %s for point %d (device.length=%d)", tostring(new_point.time), i, device.length))
    end
  end

  print("Final points_data count:", #points_data)
  print("About to set device.points...")
  
  device.points = points_data
  print("=== FLIP DEBUG END ===")
  renoise.app():show_status(string.format("%s step order flipped.", deviceName))
end

function PakettiFillStepperHumanize(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Check if there are points to humanize
  if #device.points == 0 then
    renoise.app():show_status(string.format("No existing points to humanize in %s.", deviceName))
    return
  end
  
  -- Store existing valid points before clearing
  local existing_points = {}
  for _, point in ipairs(device.points) do
    -- Only keep points with valid time values
    if point.time >= 1 and point.time <= device.length then
      table.insert(existing_points, {
        time = point.time,
        value = point.value,
        scaling = point.scaling
      })
    end
  end
  
  if #existing_points == 0 then
    renoise.app():show_status(string.format("No valid points to humanize in %s.", deviceName))
    return
  end
  
  -- Apply ±2% humanization to existing points only
  device:clear_points()
  local points_data = {}
  
  for _, point in ipairs(existing_points) do
    local original_value = point.value
    local variation = (math.random() - 0.5) * 0.04  -- ±2% variation
    local humanized_value = math.max(0, math.min(1, original_value + variation))
    
    table.insert(points_data, {
      scaling = point.scaling,
      time = point.time,  -- Preserve original time position
      value = humanized_value
    })
  end

  device.points = points_data
  renoise.app():show_status(string.format("%s humanized %d existing points with ±2%% variation.", deviceName, #points_data))
end

function PakettiRandomizeVisibleStepperStepSize()
  local visible_stepper = PakettiGetVisibleStepperName()
  if not visible_stepper then
    renoise.app():show_status("No stepper is currently visible")
    return
  end
  
  local step_size = math.random(1, 256)
  PakettiChangeVisibleStepperStepSize(step_size)
  PakettiUpdateStepCountText()
  renoise.app():show_status(string.format("Changed %s to %d steps", visible_stepper, step_size))
end

function PakettiFillStepperTriangle(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Clear existing points and fill with triangle wave (0.5 → 1.0 → 0.0 → 0.5)
  device:clear_points()
  local points_data = {}
  
  for i = 1, device.length do
    local phase = (i - 1) / device.length  -- 0 to 1 progress through pattern
    local value
    
    if phase <= 0.25 then
      -- First quarter: 0.5 → 1.0
      value = 0.5 + 2 * phase
    elseif phase <= 0.75 then
      -- Middle half: 1.0 → 0.0
      value = 1.0 - 2 * (phase - 0.25)
    else
      -- Last quarter: 0.0 → 0.5
      value = 0.0 + 2 * (phase - 0.75)
    end
    
    table.insert(points_data, {
      scaling = 0,
      time = i,
      value = math.max(0, math.min(1, value))
    })
  end

  device.points = points_data
  renoise.app():show_status(string.format("%s filled with triangle wave (0.5→1.0→0.0→0.5).", deviceName))
end

function PakettiFillStepperSawtooth(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Clear existing points and fill with sawtooth wave (0.5 → 1.0 → 0.0 → 0.5)
  device:clear_points()
  local points_data = {}
  local midpoint = math.ceil(device.length / 2)
  
  for i = 1, device.length do
    local value
    
    if i <= midpoint then
      -- First half: 0.5 → 1.0
      value = 0.5 + 0.5 * ((i - 1) / (midpoint - 1))
    else
      -- Second half: 0.0 → 0.5
      value = 0.0 + 0.5 * ((i - midpoint) / (device.length - midpoint))
    end
    
    table.insert(points_data, {
      scaling = 0,
      time = i,
      value = math.max(0, math.min(1, value))
    })
  end

  device.points = points_data
  renoise.app():show_status(string.format("%s filled with sawtooth wave (0.5→1.0→0.0→0.5).", deviceName))
end

function PakettiFillStepperSteps(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Clear existing points and fill with discrete steps
  device:clear_points()
  local points_data = {}
  local step_values = {0, 0.25, 0.5, 0.75, 1.0}
  local steps_per_level = math.max(1, math.floor(device.length / #step_values))
  
  for i = 1, device.length do
    local level_index = math.min(#step_values, math.ceil(i / steps_per_level))
    table.insert(points_data, {
      scaling = 0,
      time = i,
      value = step_values[level_index]
    })
  end

  device.points = points_data
  renoise.app():show_status(string.format("%s filled with discrete steps pattern.", deviceName))
end

function PakettiSmoothStepperValues(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Check if there are points to smooth
  if #device.points == 0 then
    renoise.app():show_status(string.format("No existing points to smooth in %s.", deviceName))
    return
  end
  
  -- Store existing valid points before clearing
  local existing_points = {}
  for _, point in ipairs(device.points) do
    -- Only keep points with valid time values
    if point.time >= 1 and point.time <= device.length then
      table.insert(existing_points, {
        time = point.time,
        value = point.value,
        scaling = point.scaling
      })
    end
  end
  
  if #existing_points == 0 then
    renoise.app():show_status(string.format("No valid points to smooth in %s.", deviceName))
    return
  end
  
  -- Sort points by time to ensure proper order
  table.sort(existing_points, function(a, b) return a.time < b.time end)
  
  -- Apply smoothing by averaging with actual neighboring points in the array
  device:clear_points()
  local points_data = {}
  
  for i, point in ipairs(existing_points) do
    local current_value = point.value
    -- Find actual previous and next points in the array
    local prev_value = (i > 1) and existing_points[i-1].value or current_value
    local next_value = (i < #existing_points) and existing_points[i+1].value or current_value
    
    -- Smooth by averaging with neighbors
    local smoothed_value = (prev_value + current_value + next_value) / 3
    
    table.insert(points_data, {
      scaling = point.scaling,
      time = point.time,  -- Preserve original time position
      value = math.max(0, math.min(1, smoothed_value))
    })
  end

  device.points = points_data
  renoise.app():show_status(string.format("%s smoothed %d existing points with neighbor averaging.", deviceName, #points_data))
end

function PakettiScaleStepperValues(deviceName, scale_factor)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Check if there are points to scale
  if #device.points == 0 then
    renoise.app():show_status(string.format("No existing points to scale in %s.", deviceName))
    return
  end
  
  -- Store existing points before clearing, but only valid ones
  local existing_points = {}
  for _, point in ipairs(device.points) do
    -- Only keep points with valid time values
    if point.time >= 1 and point.time <= device.length then
      table.insert(existing_points, {
        time = point.time,
        value = point.value,
        scaling = point.scaling
      })
    end
  end
  
  if #existing_points == 0 then
    renoise.app():show_status(string.format("No valid points to scale in %s.", deviceName))
    return
  end
  
  -- Clear and recreate with scaled values - only valid time positions
  device:clear_points()
  local points_data = {}
  
  for _, point in ipairs(existing_points) do
    local original_value = point.value
    -- Scale relative to center: new_value = center + (original - center) * scale_factor
    local scaled_value = 0.5 + (original_value - 0.5) * scale_factor
    scaled_value = math.max(0, math.min(1, scaled_value))
    
    table.insert(points_data, {
      scaling = point.scaling,
      time = point.time,  -- Already validated as valid
      value = scaled_value
    })
  end
  
  device.points = points_data
  renoise.app():show_status(string.format("%s scaled %d existing points by %d%%.", deviceName, #points_data, math.floor(scale_factor * 100)))
end

function PakettiQuantizeStepperValues(deviceName)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Get existing points
  local existing_points = {}
  if #device.points > 0 then
    for _, point in ipairs(device.points) do
      existing_points[point.time] = point.value
    end
  else
    for i = 1, device.length do
      existing_points[i] = 0.5
    end
  end
  
  -- Quantize to discrete levels
  device:clear_points()
  local points_data = {}
  local quantize_levels = {0, 0.25, 0.5, 0.75, 1.0}
  
  for i = 1, device.length do
    local original_value = existing_points[i] or 0.5
    
    -- Find closest quantize level
    local closest_level = quantize_levels[1]
    local closest_distance = math.abs(original_value - closest_level)
    
    for _, level in ipairs(quantize_levels) do
      local distance = math.abs(original_value - level)
      if distance < closest_distance then
        closest_distance = distance
        closest_level = level
      end
    end
    
    table.insert(points_data, {
      scaling = 0,
      time = i,
      value = closest_level
    })
  end

  device.points = points_data
  renoise.app():show_status(string.format("%s values quantized to discrete levels.", deviceName))
end

function PakettiOffsetStepperValues(deviceName, offset_amount)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(deviceName)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", deviceName))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Check if there are points to offset
  if #device.points == 0 then
    renoise.app():show_status(string.format("No existing points to offset in %s.", deviceName))
    return
  end
  
  -- Check if values are already at extremes (only check existing points with valid times)
  local valid_points = {}
  for _, point in ipairs(device.points) do
    if point.time >= 1 and point.time <= device.length then
      table.insert(valid_points, point)
    end
  end
  
  if #valid_points == 0 then
    renoise.app():show_status(string.format("No valid points to offset in %s.", deviceName))
    return
  end
  
  if offset_amount > 0 then
    local all_at_max = true
    for _, point in ipairs(valid_points) do
      if point.value < 1.0 then
        all_at_max = false
        break
      end
    end
    if all_at_max then
      renoise.app():show_status(string.format("%s already at max, doing nothing.", deviceName))
      return
    end
  elseif offset_amount < 0 then
    local all_at_min = true
    for _, point in ipairs(valid_points) do
      if point.value > 0.0 then
        all_at_min = false
        break
      end
    end
    if all_at_min then
      renoise.app():show_status(string.format("%s already at min, doing nothing.", deviceName))
      return
    end
  end
  
  -- Store existing valid points before clearing
  local existing_points = {}
  for _, point in ipairs(valid_points) do
    table.insert(existing_points, {
      time = point.time,
      value = point.value,
      scaling = point.scaling
    })
  end
  
  -- Clear and recreate with offset values - only valid time positions
  device:clear_points()
  local points_data = {}
  
  for _, point in ipairs(existing_points) do
    local original_value = point.value
    local offset_value = math.max(0, math.min(1, original_value + offset_amount))
    
    table.insert(points_data, {
      scaling = point.scaling,
      time = point.time,  -- Already validated as valid
      value = offset_value
    })
  end
  
  device.points = points_data
  renoise.app():show_status(string.format("%s offset %d existing points.", deviceName, #points_data))
end

function PakettiOffsetVisibleStepperValues(offset_amount)
  local visible_stepper = PakettiGetVisibleStepperName()
  if not visible_stepper then
    return
  end
  PakettiOffsetStepperValues(visible_stepper, offset_amount)
end

function PakettiCopyStepperData()
  local visible_stepper = PakettiGetVisibleStepperName()
  if not visible_stepper then
    renoise.app():show_status("No stepper is currently visible")
    return
  end
  
  local instrument = renoise.song().selected_instrument
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(visible_stepper)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", visible_stepper))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  
  -- Copy exactly what exists - no filling in missing steps
  copied_stepper_data = {}
  for _, point in ipairs(device.points) do
    table.insert(copied_stepper_data, {
      time = point.time,
      value = point.value,
      scaling = point.scaling
    })
  end
  
  renoise.app():show_status(string.format("Copied %d points from %s (device.length: %d)", #copied_stepper_data, visible_stepper, device.length))
end

function PakettiPasteStepperData()
  if not copied_stepper_data then
    renoise.app():show_status("No stepper data copied")
    return
  end
  
  local visible_stepper = PakettiGetVisibleStepperName()
  if not visible_stepper then
    renoise.app():show_status("No stepper is currently visible")
    return
  end
  
  local instrument = renoise.song().selected_instrument
  if not instrument or not instrument.sample_modulation_sets[1] then
    renoise.app():show_status("No valid instrument or modulation devices found.")
    return
  end
  
  local deviceIndex = findStepperDeviceIndex(visible_stepper)
  if not deviceIndex then
    renoise.app():show_status(string.format("There is no %s device in this instrument.", visible_stepper))
    return
  end
  
  local device = instrument.sample_modulation_sets[1].devices[deviceIndex]
  local copied_length = #copied_stepper_data
  
  -- FIRST: Clear the visible stepper completely
  print(string.format("Clearing %s before pasting", visible_stepper))
  device:clear_points()
  
  -- SECOND: Resize stepper to match copied data length
  if copied_length ~= device.length then
    print(string.format("Resizing %s from %d to %d steps to match copied data", visible_stepper, device.length, copied_length))
    device.length = copied_length
  end
  
  -- THIRD: Paste the copied data with sequential time values
  local points_data = {}
  for i = 1, copied_length do
    local copied_point = copied_stepper_data[i]
    if copied_point then
      table.insert(points_data, {
        scaling = copied_point.scaling,
        time = i,  -- Use sequential time values starting from 1
        value = copied_point.value
      })
    end
  end
  
  device.points = points_data
  
  -- Update UI to reflect new step count
  PakettiUpdateStepCountText()
  
  renoise.app():show_status(string.format("Pasted %d points to %s (cleared and resized to %d steps)", copied_length, visible_stepper, device.length))
end

function PakettiScaleVisibleStepperValues(scale_factor)
  local visible_stepper = PakettiGetVisibleStepperName()
  if not visible_stepper then
    renoise.app():show_status("No stepper is currently visible")
    return
  end
  PakettiScaleStepperValues(visible_stepper, scale_factor)
end

