
local instr = renoise.song().selected_instrument
for k,v in ipairs(instr.phrases) do
  --oprint(v.mapping)
  v.mapping.looping = false
end
