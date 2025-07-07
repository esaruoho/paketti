--[[

Reset basenotes
Align with the note range

]]

local instr = renoise.song().selected_instrument

for idx = 1, #instr.samples do


  local sample = instr.samples[idx]
  local smap = sample.sample_mapping
  
  smap.base_note = smap.note_range[1]

end


