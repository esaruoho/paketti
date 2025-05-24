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
local updating_switch = false
local updating_stepper_switch = false

function pakettiPitchStepperDemo()
  if dialog and dialog.visible then
    dialog:close()
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
    local step_sizes = {16, 32, 64, 128, 256}
    
    for i, size in ipairs(step_sizes) do
      if size == current_size then
        stepsize_switch.value = i
        break
      end
    end
    updating_switch = false
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
    items={"16","32","64","128","256"},
    width=300,
    value = 3, -- default to 64
    notifier = function(value)
      if not updating_switch then
        local step_sizes = {16, 32, 64, 128, 256}
        PakettiChangeVisibleStepperStepSize(step_sizes[value])
      end
    end
  }

  -- Update switches to current state
  PakettiUpdateStepperSwitch()
  PakettiUpdateStepSizeSwitch()

  dialog = renoise.app():show_custom_dialog("Paketti Steppers",
    vb:column{
      vb:row{
        vb:text{text = "Stepper", style="strong", font="Bold", width=70},
        stepper_switch
      },
      vb:row{
        vb:text{text = "Step Size", style="strong", font="Bold", width=70},
        stepsize_switch
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



