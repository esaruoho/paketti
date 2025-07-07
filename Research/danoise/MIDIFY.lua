--[[

MIDIFY

Instantiate chosen MIDI output port for all instruments

--]]


local port_name = "Microsoft GS Wavetable Synth"

for k,v in ipairs(renoise.song().instruments) do

  --print(v.midi_output_properties.device_name)
  v.midi_output_properties.device_name = port_name
  

end





