--[[

Copies loop markers from one instrument into another
(assuming the instruments have an equal sample count)

]]

function copy_loop_markers(src_idx,target_idx)

  local src_instr = renoise.song().instruments[src_idx]
  local target_instr = renoise.song().instruments[target_idx]
  
  print(src_instr.name,"-->",target_instr.name)
  
  for k,sample in ipairs(src_instr.samples) do
  
    local target_sample = target_instr.samples[k]
    
    if (sample and target_sample) then
      
      print(k,sample.name,"-->",target_sample.name)
    
      target_sample.loop_mode = sample.loop_mode
      target_sample.loop_start = sample.loop_start
      target_sample.loop_end = sample.loop_end
        
    else
      print("Can't copy, source or target is missing...")  
    end
  
  end
end
  
local src_idx = 0x3A
for i = 3,src_idx do
  copy_loop_markers(src_idx,i)
end


