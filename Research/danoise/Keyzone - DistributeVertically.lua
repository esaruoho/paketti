--[[

Distribute samples vertically

Takes all samples and distribute them equally along
the vertical axis (velocity).


]]

--- scale_value: scale a value to a range within a range
function scale_value(value,in_min,in_max,out_min,out_max)
  return(((value-in_min)*(out_max/(in_max-in_min)-(out_min/(in_max-in_min))))+out_min)
end


-- ===============================
-- RUN THE SCRIPT
-- ===============================

local scope = "instrument"

-- first sample is loudest?
local first_is_loudest = true

-- define to "wrap" around when reaching a certain #samples,
-- or leave undefined to use all samples in instrument
local custom_count = 23

-- custom minimum/maximum values 
local min_velocity = 0x00
local max_velocity = 0x80



if (scope == "instrument") then

  local instr = renoise.song().selected_instrument
  if not custom_count then
    custom_count = #instr.samples
  end
  
  for idx = 1,#instr.samples do
  
    local idx_custom = idx
    local num_samples = #instr.samples
    if custom_count then
      idx_custom = idx % custom_count
      if (idx_custom == 0) then
        idx_custom = custom_count
      end
      num_samples = custom_count
    end
    --print("idx,idx_custom",idx,idx_custom)
        
    local sample = instr.samples[idx]
    local smap = sample.sample_mapping
    --print("sample.sample_mapping",oprint(sample.sample_mapping))
    
    local vel_from,vel_to
    if first_is_loudest then
      vel_from = (0x80/custom_count) * (idx_custom-1)   
      vel_to   = ((0x80/custom_count) * idx_custom) - 1
    else
      vel_from = (0x80/custom_count) * (custom_count-idx_custom)
      vel_to   = (0x80/custom_count) * (custom_count-(idx_custom-1)) - 1
    end
    --print("PRE  idx,vel_from/to",string.format("%d,%x/%x",idx,vel_from,vel_to))
    
    vel_from = scale_value(vel_from,0x00,0x80,min_velocity,max_velocity)
    vel_to = scale_value(vel_to,0x00,0x80,min_velocity,max_velocity)

    --print("POST idx,vel_from/to",string.format("%d,%x/%x",idx,vel_from,vel_to))
    
    smap.velocity_range = {vel_from,vel_to}
    
  
  end

end







