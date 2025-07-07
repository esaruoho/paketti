--[[

Sort Samples

]]


SORT_NAME      = 1
SORT_BASENOTE  = 2
SORT_VELOCITY  = 4
SORT_ASCENDING = 8

local sort_1 = SORT_VELOCITY + SORT_ASCENDING
local sort_2 = SORT_NAME    
local sort_3 = SORT_BASENOTE

local instr = renoise.song().selected_instrument
local num_samples = #instr.samples

local arr_name = {}
local arr_basenote = {}
local arr_velocity = {}

for idx = 1, num_samples do

  local sample = instr.samples[idx]
  local smap = sample.sample_mapping

  -- collect names
  if not arr_name[sample.name] then
    arr_name[sample.name] = {}
  end 
  table.insert(arr_name[sample.name],idx)
  
  -- collect basenote
  if not arr_basenote[smap.base_note] then
    arr_basenote[smap.base_note] = {}
  end 
  table.insert(arr_basenote[smap.base_note],idx)

  -- collect velocity
  local key = smap.velocity_range[1]
  if not arr_velocity[key] then
    arr_velocity[key] = {}
  end 
  table.insert(arr_velocity[key],idx)
    
end

table.sort(arr_name)
table.sort(arr_basenote)
table.sort(arr_velocity)

--rprint(arr_name)
--rprint(arr_basenote)
--rprint(arr_velocity)


-- first sorting criteria
if (bit.band(sort_1,SORT_NAME) > 0) then

  print("SORT_NAME")

elseif (bit.band(sort_1,SORT_BASENOTE) > 0) then

  print("SORT_BASENOTE")

elseif (bit.band(sort_1,SORT_VELOCITY) > 0) then

  print("SORT_VELOCITY)")
  --print("arr_velocity",rprint(arr_velocity))
  
  for idx = 0,0x80 do
    if (arr_velocity[idx] and #arr_velocity[idx] > 1) then
      print("second stage sorting",rprint(arr_velocity[idx]))
      
    end
  end

end


