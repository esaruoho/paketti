local f = assert(io.open("PakettiSamples.lua")); local source = f:read("*a"); f:close()
local helper = assert(source:match("(function PakettiCopyDuplicatedInstrumentDevice.-)\n%-%- Core function"))
assert(load(helper))()
local function check(path, name)
  local old = {device_path=path, display_name=name, is_maximized=false,
    active_preset_data='<FilterDevicePreset><DeviceSlot type="InstrumentMacroDevice"><instrument>11</instrument><routing>2</routing><wave>custom</wave></DeviceSlot></FilterDevicePreset>',
    parameters={{value=0.5, show_in_mixer=false},{value=0.75, show_in_mixer=true}}}
  local function parameter()
    local values = {}
    return setmetatable({}, {__index=values, __newindex=function(_, key, value)
      if key == "value" then assert(value >= 0 and value <= 1, "parameter range exceeded") end
      values[key] = value
    end})
  end
  local new = {parameters={parameter(),parameter()}}
  PakettiCopyDuplicatedInstrumentDevice(old, new, 13)
  assert(new.display_name == name and new.is_maximized == false)
  assert(new.parameters[2].value == 0.75 and new.parameters[2].show_in_mixer == true)
  assert(new.active_preset_data:find('<routing>2</routing>',1,true))
  assert(new.active_preset_data:find('<wave>custom</wave>',1,true))
  assert(old.parameters[1].value == 0.5 and old.active_preset_data:find('<instrument>11</instrument>',1,true))
  return new
end
local macros = check("Audio/Effects/Native/*Instr. Macros", "My Macros")
assert(macros.parameters[1].value == 0.5)
assert(macros.active_preset_data:find('<LinkedInstrument>',1,true) == nil)
-- Both callers must select the duplicate before inserting its DSP chain.
local core = assert(source:match('(function duplicateTrackAndInstrumentCore.-)\nrenoise.tool'))
assert(core:find('song.selected_instrument_index = instrument_index + 1',1,true) < core:find('new_track:insert_device_at',1,true))
local requests_file = assert(io.open("PakettiRequests.lua"))
local requests = requests_file:read("*a"); requests_file:close()
local alternate = assert(requests:match('(function duplicateTrackDuplicateInstrument.-)\nrenoise.tool'))
assert(alternate:find('song.selected_instrument_index = new_instrument_index',1,true) < alternate:find('new_track:insert_device_at',1,true))
assert(check("Audio/Effects/Native/*LFO", "Wavetable Mod *LFO").parameters[1].value == 0.5)
assert(check("Audio/Effects/Native/*Instr. Automation", "My Automation").active_preset_data:find('<instrument>12</instrument>',1,true))
print("PASS: selection-before-insertion, normalized macro range, custom names, LFO preset/routing, mixer flags and source preservation")
