--[[
Format filenames for export to Kontakt sampler
Removes dash and convert velocity to decimal

Input: e.g. VST: iblit (PwmBass 1)_0x7F_C-3
Output e.g. VST_iblit_PwmBass_1_127_C3

]]

local output_folder = "c:/temp/" -- folder needs to exist
local instr = renoise.song().selected_instrument
for k,sample in ipairs(instr.samples) do
  local filename = sample.name
  filename = string.gsub(filename,"(.*)_(0x%x%x)_([A-Z])-?(#?%d)",function(a,b,c,d)
    a = string.gsub(a,":","")
    a = string.gsub(a,"[%(%)]","")
    a = string.gsub(a,"%s","_")
    return a.."_"..("%d"):format(tonumber(b)).."_"..c..d
  end)
  filename = output_folder .. filename
  renoise.song().selected_sample_index = k
  print("Exporting sample:"..filename)
  renoise.app():save_instrument_sample(filename)
end

