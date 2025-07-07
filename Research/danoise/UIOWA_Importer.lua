--[[

Import samples from uiowa

]]

local translate = {
  {source = "C", target = "C"},
  {source = "Db", target = "C#"},
  {source = "D", target = "D"},
  {source = "Eb", target = "D#"},
  {source = "E", target = "E"},
  {source = "F", target = "F"},
  {source = "Gb", target = "F#"},
  {source = "G", target = "G"},
  {source = "Ab", target = "G#"},
  {source = "A", target = "A"},
  {source = "Bb", target = "A#"},
  {source = "B", target = "B"},  
}

local instr = renoise.song().selected_instrument

for idx = 1,#instr.samples do

  local sample = instr.samples[idx]
  local smap = sample.sample_mapping

  for oct = 1,10 do
  
    for semi = 1,12 do
      local needle = string.format("%s%d",
        translate[semi].source,oct)
        
      --print("needle",needle)
      if string.find(sample.name,needle) then
        smap.base_note = oct*12 + semi - 1
        smap.note_range = {smap.base_note,smap.base_note}
        
      end
      
      
    end
  
  end


end


