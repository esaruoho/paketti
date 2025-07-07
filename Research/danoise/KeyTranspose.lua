--[[
Transpose keyzones in the current instrument
Unlike the keyzone editor, this function will 
move the basenote along with the sample..

]]

----------------------------------------------
-- RUN THE SCRIPT
----------------------------------------------

local transpose_by = 12

-- run on selected instrument
local instr = renoise.song().selected_instrument
if instr then
  for k,v in ipairs(instr.samples) do
    --oprint(v)
    --oprint(v.sample_mapping)
    rprint(v.sample_mapping.note_range)
    
    local basenote = v.sample_mapping.base_note + transpose_by
    local note_range_start = v.sample_mapping.note_range[1] + transpose_by
    local note_range_end = v.sample_mapping.note_range[2] + transpose_by
    
    -- check if within bounds
    local within_bounds = function(val)
      print("within_bounds",val)
      return (val > 0 and val < 120) 
    end
    
    if within_bounds(basenote) and
       within_bounds(note_range_start) and
       within_bounds(note_range_end)
    then
      v.sample_mapping.base_note = basenote
      v.sample_mapping.note_range = {note_range_start,note_range_end}
    else
      print("Keyzone exceed the valid range - sample name:",v.name)
    end
  end
end



