local STEPPER_TYPES = {
    PITCH = "Pitch Stepper",
    VOLUME = "Volume Stepper",
    PAN = "Pan Stepper",
    CUTOFF = "Cutoff Stepper",
    RESONANCE = "Resonance Stepper",
    DRIVE = "Drive Stepper"
}

local vb=renoise.ViewBuilder()
local dialog=nil

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
function ResetAllSteppers()
    local song = renoise.song()
    local count = 0
    local stepperTypes = {"Pitch Stepper", "Volume Stepper", "Pan Stepper", 
                         "Cutoff Stepper", "Resonance Stepper", "Drive Stepper"}
    
    for inst_idx, instrument in ipairs(song.instruments) do
        if instrument.samples[1] and instrument.sample_modulation_sets[1] then
            local devices = instrument.sample_modulation_sets[1].devices
            for dev_idx, device in ipairs(devices) do
                for _, stepperType in ipairs(stepperTypes) do
                    if device.name == stepperType then
                        device.parameters[1].value = 1
                        count = count + 1
                        if device.external_editor_visible then
                            device.external_editor_visible = false
                        end
                    end
                end
            end
        end
    end
    
    if count > 0 then
        renoise.app():show_status(string.format("Reset %d Stepper device(s)", count))
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
        invoke = function() PakettiClearStepper(stepperType) end
    }
    renoise.tool():add_menu_entry{name=string.format("Sample Modulation Matrix:Paketti..:Clear %s Steps", baseText),invoke = function() PakettiClearStepper(stepperType) end
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
    device.external_editor_visible = not device.external_editor_visible
    isPitchStepSomewhere = renoise.song().selected_track_index
    renoise.app():show_status(string.format("%s visibility toggled.", deviceName))
end
renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide PitchStep on Selected Instrument",invoke=function() PakettiShowStepper("Pitch Stepper") end}
renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide VolumeStep on Selected Instrument",invoke=function() PakettiShowStepper("Volume Stepper") end}
renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide CutoffStep on Selected Instrument",invoke=function() PakettiShowStepper("Cutoff Stepper") end}
renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide ResonanceStep on Selected Instrument",invoke=function() PakettiShowStepper("Resonance Stepper") end}
renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide DriveStep on Selected Instrument",invoke=function() PakettiShowStepper("Drive Stepper") end}
renoise.tool():add_keybinding{name="Global:Paketti:Show/Hide PanStep on Selected Instrument",invoke=function() PakettiShowStepper("Pan Stepper") end}

--------



