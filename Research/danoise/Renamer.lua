--[[
Assign the instrument name to its samples,
using the following naming convention:

[YourTitle]_[BaseNote]

Alternatively, if run on a MIDI drumkit, 
the drum name is inserted instead of the note
[NameOfDrum]_[YourTitle]


]]

NOTE_ARRAY = { "C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-" }

GMKIT_ARRAY = {
  [35]="Acoustic_Bass_Drum",
  [36]="Bass_Drum_1",
  [37]="Side_Stick",
  [38]="Acoustic_Snare",
  [39]="Hand_Clap",
  [40]="Electric_Snare",
  [41]="Low_Floor_Tom",
  [42]="Closed_Hi_Hat",
  [43]="High_Floor_Tom",
  [44]="Pedal_Hi-Hat",
  [45]="Low_Tom",
  [46]="Open_Hi-Hat",
  [47]="Low-Mid_Tom",
  [48]="Hi-Mid_Tom",
  [49]="Crash_Cymbal_1",
  [50]="High_Tom",
  [51]="Ride_Cymbal_1",
  [52]="Chinese_Cymbal",
  [53]="Ride_Bell",
  [54]="Tambourine",
  [55]="Splash_Cymbal",
  [56]="Cowbell",
  [57]="Crash_Cymbal_2",
  [58]="Vibraslap",
  [59]="Ride_Cymbal_2",
  [60]="Hi_Bongo",
  [61]="Low_Bongo",
  [62]="Mute_Hi_Conga",
  [63]="Open_Hi_Conga",
  [64]="Low_Conga",
  [65]="High_Timbale",
  [66]="Low_Timbale",
  [67]="High_Agogo",
  [68]="Low_Agogo",
  [69]="Cabasa",
  [70]="Maracas",
  [71]="Short_Whistle",
  [72]="Long_Whistle",
  [73]="Short_Guiro",
  [74]="Long_Guiro",
  [75]="Claves",
  [76]="Hi_Wood_Block",
  [77]="Low_Wood_Block",
  [78]="Mute_Cuica",
  [79]="Open_Cuica",
  [80]="Mute_Triangle",
  [81]="Open_Triangle",
}

function note_pitch_to_value(val)
  if not val then
    return nil
  elseif (val==120) then
    return "OFF"
  elseif(val==121) then
    return "---"
  elseif(val==0) then
    return "C-0"
  else
    local oct = math.floor(val/12)
    local note = NOTE_ARRAY[(val%12)+1]
    return string.format("%s%s",note,oct)
  end
end

function rename_samples(instr,name,use_note_names,sample_start,sample_end)
  local s_layer = renoise.Instrument.LAYER_NOTE_ON
  for k,s_map in ipairs(instr.sample_mappings[s_layer]) do
    local basenote = s_map.base_note
    --[[
    if use_note_names then
      s_map.sample.name = string.format("%s_%s",
        name,note_pitch_to_value(basenote))
    else
      local drum_name = "Unknown"
      if GMKIT_ARRAY[basenote] then
        drum_name = GMKIT_ARRAY[basenote]
      end
      s_map.sample.name = string.format("%s_%s",
        drum_name,name)    
    end
    ]]

    if (k >= sample_start) and (k <= sample_end) then
      s_map.sample.name = string.format("%s_%s",
        name,note_pitch_to_value(basenote))
    end


  end
end
  

----------------------------------------------
-- RUN THE SCRIPT
----------------------------------------------

-- running the script on notes or drums?
local use_note_names = true

-- run on selected instrument or range?
local scope = "instrument"
local range_start = 0x61
local range_end = 0x0ff

local sample_start = 1
local sample_end = 120


if (scope == "instrument") then
  local name = "ModPercOsc1"
  local instr = renoise.song().selected_instrument
  rename_samples(instr,name,use_note_names,sample_start,sample_end)
elseif (scope == "range") then  
  for idx = range_start,range_end do
    instr = renoise.song().instruments[idx]
    if instr then
      local name = instr.name
      rename_samples(instr,name,use_note_names,sample_start,sample_end)
    end
  
  end
end



