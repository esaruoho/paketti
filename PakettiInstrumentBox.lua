function DuplicateInstrumentAndSelectNewInstrument()
local rs=renoise.song()
if renoise.app().window.active_middle_frame==3 then 
local i=rs.selected_instrument_index;rs:insert_instrument_at(i+1):copy_from(rs.selected_instrument);rs.selected_instrument_index=i+1
renoise.app().window.active_middle_frame=3
else
if renoise.app().window.active_middle_frame == 9 then
local i=rs.selected_instrument_index;rs:insert_instrument_at(i+1):copy_from(rs.selected_instrument);rs.selected_instrument_index=i+1
renoise.app().window.active_middle_frame=9
else
local i=rs.selected_instrument_index;rs:insert_instrument_at(i+1):copy_from(rs.selected_instrument);rs.selected_instrument_index=i+1
end
end
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Instrument and Select New Instrument",invoke=function() DuplicateInstrumentAndSelectNewInstrument() end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Instrument and Select New Instrument (2nd)",invoke=function() DuplicateInstrumentAndSelectNewInstrument() end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Instrument and Select New Instrument (3rd)",invoke=function() DuplicateInstrumentAndSelectNewInstrument() end}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:Duplicate Instrument and Select New Instrument",invoke=function() DuplicateInstrumentAndSelectNewInstrument() end}

function duplicateSelectInstrumentToLastInstrument()
local rs=renoise.song()
local n_instruments = #rs.instruments
local src_inst_i = rs.selected_instrument_index
local src_inst = rs:instrument(src_inst_i)

rs:insert_instrument_at(n_instruments)
rs.selected_instrument_index = n_instruments

rs.selected_instrument:copy_from(src_inst)
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Instrument and Select Last Instrument",invoke=function() duplicateSelectInstrumentToLastInstrument() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Duplicate Instrument and Select Last Instrument",invoke=function() duplicateSelectInstrumentToLastInstrument() end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Duplicate and Reverse Instrument",invoke=function() PakettiDuplicateAndReverseInstrument() end}

-- auto-suspend plugin off:
function autosuspendOFF()
renoise.song().instruments[renoise.song().selected_instrument_index].plugin_properties.auto_suspend=false
end

renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:Switch Plugin AutoSuspend Off",invoke=function() autosuspendOFF() end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:Plugins/Devices..:Switch Plugin AutoSuspend Off",invoke=function() autosuspendOFF() end}

-------------------------
function selectplay(number)
local s=renoise.song()
local currPatt=renoise.song().selected_pattern_index
local currTrak=renoise.song().selected_track_index
local currColumn=renoise.song().selected_note_column_index
local currLine=renoise.song().selected_line_index
local currSample=nil 
local resultant=nil

    s.selected_instrument_index=number+1

if renoise.song().transport.edit_mode==false then return end

-- Check if a note column is selected
if currColumn==0 then
    renoise.app():show_status("Please Select a Note Column.")
    return
end

    currSample=s.selected_instrument_index-1
    s.patterns[currPatt].tracks[currTrak].lines[currLine].note_columns[currColumn].note_string="C-4"
    s.patterns[currPatt].tracks[currTrak].lines[currLine].note_columns[currColumn].instrument_value=currSample

  if renoise.song().transport.follow_player==false 
    then 
resultant=renoise.song().selected_line_index+renoise.song().transport.edit_step
    if renoise.song().selected_pattern.number_of_lines<resultant
    then renoise.song().selected_line_index=renoise.song().selected_pattern.number_of_lines
    else renoise.song().selected_line_index=renoise.song().selected_line_index+renoise.song().transport.edit_step
    end
  else return
  end

end

for i = 0,9 do
renoise.tool():add_keybinding{name="Global:Paketti:Numpad SelectPlay " .. i,invoke=function() selectPlay(i) end}
end

------------------------------------------------------------------------------------------------------
--cortex.scripts.CaptureOctave v1.1 by cortex
renoise.tool():add_keybinding{name="Global:Paketti:Capture Nearest Instrument and Octave (nojump)",invoke=function(repeated) capture_ins_oct("no") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Capture Nearest Instrument and Octave (nojump)",invoke=function(repeated) capture_ins_oct("no") end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Capture Nearest Instrument and Octave (nojump)",invoke=function(repeated) capture_ins_oct("no") end}
renoise.tool():add_keybinding{name="Global:Paketti:Capture Nearest Instrument and Octave (jump)",invoke=function(repeated) capture_ins_oct("yes") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Capture Nearest Instrument and Octave (jump)",invoke=function(repeated) capture_ins_oct("yes") end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Capture Nearest Instrument and Octave (jump)",invoke=function(repeated) capture_ins_oct("yes") end}

function capture_ins_oct(state)
   local closest_note = {}  
   local current_track = renoise.song().selected_track_index
   local current_pattern = renoise.song().selected_pattern_index
   
   for pos, line in renoise.song().pattern_iterator:lines_in_pattern_track(current_pattern, current_track) do
      if (not line.is_empty) then
         local t = {}
         if (renoise.song().selected_note_column_index == 0) then
            for i = 1, renoise.song().tracks[current_track].visible_note_columns do
               table.insert(t, i)
            end
         else 
            table.insert(t, renoise.song().selected_note_column_index)
         end  
         
         for _, v in ipairs(t) do 
            local notecol = line.note_columns[v]
            
            if (not notecol.is_empty and notecol.note_string ~= "OFF") then
               if (closest_note.oct == nil) then
                  closest_note.oct = math.min(math.floor(notecol.note_value / 12), 8)
                  closest_note.line = pos.line
                  closest_note.ins = notecol.instrument_value + 1
                  closest_note.note = notecol.note_value
               elseif (math.abs(pos.line - renoise.song().transport.edit_pos.line) < math.abs(closest_note.line - renoise.song().transport.edit_pos.line)) then
                  closest_note.oct = math.min(math.floor(notecol.note_value / 12), 8)
                  closest_note.line = pos.line
                  closest_note.ins = notecol.instrument_value + 1
                  closest_note.note = notecol.note_value
               end         
            end 
         end 
      end 
   end
   
   if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR and renoise.song().selected_phrase == nil and #renoise.song().selected_instrument.phrases == 0 then 
      pakettiInitPhraseSettingsCreateNewPhrase()
      
      
--      renoise.song().instruments[renoise.song().selected_instrument_index]:insert_phrase_at(1)
      renoise.song().selected_phrase_index = 1
   return end

   if not closest_note.ins then
      renoise.app():show_status("No nearby instrument found.")
      return
   end

   -- Step 1: If the nearest instrument is not selected, select it
   if renoise.song().selected_instrument_index ~= closest_note.ins then
      renoise.song().selected_instrument_index = closest_note.ins
      renoise.song().transport.octave = closest_note.oct
      renoise.app():show_status("Instrument captured. Run the script again to jump to the sample.")
      return
   end

   -- Step 2: If in the Sample Editor, toggle back to the Pattern Editor
   if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      renoise.app():show_status("Back to Pattern Editor.")
      return
   end

   -- Step 3: If instrument is selected, jump to the nearest sample in the Sample Editor
   if state == "yes" then
      local instrument = renoise.song().instruments[closest_note.ins]
      if instrument and #instrument.samples > 0 then
         -- Determine the first sample's root note using sample_mappings
         local sample_mapping = instrument.sample_mappings[1][1] -- First sample mapping
         local first_sample_note = sample_mapping and sample_mapping.note_range[1] or 0 -- Default to C-0 (0)
         
         -- Calculate the sample index based on the closest note
         local sample_index = 1
         for i, sample_map in ipairs(instrument.sample_mappings[1]) do
            if closest_note.note >= sample_map.note_range[1] and closest_note.note <= sample_map.note_range[2] then
               sample_index = i
               break
            end
         end

         -- Set the selected sample index and switch to the sample editor
         renoise.song().selected_sample_index = sample_index
         renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
         renoise.app():show_status("Instrument and sample captured, jumping to Sample Editor.")
         return
      else
         renoise.app():show_status("No samples available in the instrument.")
         return
      end
   end
end


-----------------------------------------------------------------------------------------------------------
function emptyslices()
local w=renoise.app().window
local si=renoise.song().selected_instrument
local ss=renoise.song().selected_sample
local ssi=renoise.song().selected_sample_index
  ssi=1
   for i=1,64 do si:insert_sample_at(i) end

   for i=1,64 do renoise.song().selected_instrument.samples[i].name="empty_sampleslot" .. i end

 renoise.song().selected_instrument.name=("Empty Sample Slices" .. renoise.song().selected_instrument_index)
 w.active_middle_frame= 3 end

renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:Initialize..:Create 64 Empty Sample Slots",invoke=function() emptyslices() end}
renoise.tool():add_menu_entry{name="Sample List:Paketti..:Create 64 Empty Sample Slots",invoke=function() emptyslices() end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti..:Create 64 Empty Sample Slots",invoke=function() emptyslices() end}
--------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helper function to ensure the required number of instruments exist, with a max limit of 255 (FE)
local function ensure_instruments_count(count)
  local song = renoise.song()
  local max_instruments = 255  -- Allow creation up to 255 instruments (FE in hex)

  while #song.instruments < count and #song.instruments <= max_instruments do
    song:insert_instrument_at(#song.instruments + 1)
  end
end

-- Function to select the next chunk, properly handling the maximum chunk of FE
local function select_next_chunk()
  local song = renoise.song()
  local current_index = song.selected_instrument_index
  local next_chunk_index = math.floor((current_index - 1) / 16) * 16 + 16 + 1  -- Calculate the next chunk, ensuring alignment

  -- Ensure the next chunk index does not exceed the maximum of 256 (index 255)
  next_chunk_index = math.min(next_chunk_index, 255)

  ensure_instruments_count(next_chunk_index)
  song.selected_instrument_index = next_chunk_index
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Function to select the previous chunk, properly handling lower bounds and correct chunk stepping
local function select_previous_chunk()
  local song = renoise.song()
  local current_index = song.selected_instrument_index

  -- Correctly calculate the previous chunk, ensuring it does not get stuck or fail to decrement
  local previous_chunk_index = math.max(1, math.floor((current_index - 2) / 16) * 16 + 1)

  song.selected_instrument_index = previous_chunk_index
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Function to directly select a specific chunk, limited to FE as the maximum chunk
local function select_chunk(chunk_index)
  local target_index = chunk_index + 1
  ensure_instruments_count(target_index)
  renoise.song().selected_instrument_index = target_index
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Keybindings and MIDI mappings for chunk navigation with your exact naming convention
renoise.tool():add_keybinding{name="Global:Paketti:Select Next Chunk (00..F0)",invoke=select_next_chunk }
renoise.tool():add_keybinding{name="Global:Paketti:Select Previous Chunk (00..F0)",invoke=select_previous_chunk }

renoise.tool():add_midi_mapping{name="Paketti:Select Next Chunk (00..FE)",
  invoke=function(message) if message:is_trigger() then select_next_chunk() end end
}

renoise.tool():add_midi_mapping{name="Paketti:Select Previous Chunk (00..FE)",
  invoke=function(message) if message:is_trigger() then select_previous_chunk() end end
}

-- Keybindings and MIDI mappings for selecting specific chunks (00 to F0), with FE as the max chunk
for i = 0, 15 do
  local chunk_hex = string.format("%02X", i * 16)
  local chunk_index = i * 16

  renoise.tool():add_keybinding{name="Global:Paketti:Select Chunk " .. chunk_hex,
    invoke=function() select_chunk(chunk_index) end}

  renoise.tool():add_midi_mapping{name="Paketti:Select Chunk " .. chunk_hex,
    invoke=function(message) if message:is_trigger() then select_chunk(chunk_index) end end}
end


