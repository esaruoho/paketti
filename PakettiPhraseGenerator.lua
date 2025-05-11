-- Debug print  
function dbug(msg)  
  local base_types = {  
  ["nil"]=true, ["boolean"]=true, ["number"]=true,  
  ["string"]=true, ["thread"]=true, ["table"]=true  
  }  
  if not base_types[type(msg)] then oprint(msg)  
  elseif type(msg) == 'table' then rprint(msg)  
  else print(msg) end  
 end
 
 _AUTO_RELOAD_DEBUG = true
  
 renoise.tool():add_menu_entry{name="Script Editor:Paketti..:PRINT",invoke=function() print("HEEY") end}
 
 -- Constants for configuration
 local NOTE_RANGES = {
   minimal = {"c-4", "d-4", "e-4", "f-4", "g-4", "a-4", "b-4", "c-5"},
   pentatonic = {"c-4", "d-4", "f-4", "g-4", "a-4", "c-5"},
   chromatic = {"c-4", "c#4", "d-4", "d#4", "e-4", "f-4", "f#4", "g-4", "g#4", "a-4", "a#4", "b-4", "c-5"},
   blues = {"c-4", "eb4", "f-4", "f#4", "g-4", "bb4", "c-5"},
   major = {"c-4", "d-4", "e-4", "f-4", "g-4", "a-4", "b-4", "c-5"},
   natural_minor = {"c-4", "d-4", "eb4", "f-4", "g-4", "ab4", "bb4", "c-5"},
   harmonic_minor = {"c-4", "d-4", "eb4", "f-4", "g-4", "ab4", "b-4", "c-5"},
   melodic_minor = {"c-4", "d-4", "eb4", "f-4", "g-4", "a-4", "b-4", "c-5"},
   dorian = {"c-4", "d-4", "eb4", "f-4", "g-4", "a-4", "bb4", "c-5"},
   phrygian = {"c-4", "db4", "eb4", "f-4", "g-4", "ab4", "bb4", "c-5"},
   lydian = {"c-4", "d-4", "e-4", "f#4", "g-4", "a-4", "b-4", "c-5"},
   mixolydian = {"c-4", "d-4", "e-4", "f-4", "g-4", "a-4", "bb4", "c-5"},
   locrian = {"c-4", "db4", "eb4", "f-4", "gb4", "ab4", "bb4", "c-5"},
   whole_tone = {"c-4", "d-4", "e-4", "f#4", "g#4", "a#4", "c-5"},
   diminished = {"c-4", "d-4", "eb4", "f-4", "gb4", "ab4", "a-4", "b-4", "c-5"},
   persian = {"c-4", "db4", "e-4", "f-4", "gb4", "a-4", "bb4", "c-5"},
   japanese = {"c-4", "db4", "f-4", "g-4", "ab4", "c-5"},
   gamelan = {"c-4", "d-4", "eb4", "g-4", "ab4", "c-5"},
   hungarian = {"c-4", "d#4", "e-4", "f#4", "g-4", "a-4", "bb4", "c-5"},
   romanian = {"c-4", "d-4", "eb4", "f#4", "g-4", "a-4", "bb4", "c-5"},
   spanish = {"c-4", "db4", "e-4", "f-4", "g-4", "ab4", "b-4", "c-5"},
   enigmatic = {"c-4", "db4", "e-4", "f#4", "g#4", "a#4", "b-4", "c-5"},
   neapolitan = {"c-4", "db4", "eb4", "f-4", "g-4", "ab4", "b-4", "c-5"},
   prometheus = {"c-4", "d-4", "e-4", "f#4", "a-4", "bb4", "c-5"},
   algerian = {"c-4", "db4", "e-4", "f-4", "gb4", "ab4", "b-4", "c-5"}
 }
 
 local SCALE_NAMES = {
   "minimal", "pentatonic", "chromatic", "blues",
   "major", "natural_minor", "harmonic_minor", "melodic_minor",
   "dorian", "phrygian", "lydian", "mixolydian", "locrian",
   "whole_tone", "diminished", "persian", "japanese", "gamelan",
   "hungarian", "romanian", "spanish", "enigmatic", "neapolitan",
   "prometheus", "algerian"
 }
 
 local SCALE_DISPLAY_NAMES = {
   minimal = "Minimal (C Major)",
   pentatonic = "Pentatonic (C)",
   chromatic = "Chromatic",
   blues = "Blues (C)",
   major = "Major (C)",
   natural_minor = "Natural Minor (C)",
   harmonic_minor = "Harmonic Minor (C)",
   melodic_minor = "Melodic Minor (C)",
   dorian = "Dorian (C)",
   phrygian = "Phrygian (C)",
   lydian = "Lydian (C)",
   mixolydian = "Mixolydian (C)",
   locrian = "Locrian (C)",
   whole_tone = "Whole Tone (C)",
   diminished = "Diminished (C)",
   persian = "Persian (C)",
   japanese = "Japanese (C)",
   gamelan = "Gamelan/Pelog (C)",
   hungarian = "Hungarian (C)",
   romanian = "Romanian (C)",
   spanish = "Spanish/Phrygian Dominant (C)",
   enigmatic = "Enigmatic (C)",
   neapolitan = "Neapolitan Minor (C)",
   prometheus = "Prometheus (C)",
   algerian = "Algerian (C)"
 }
 
 local RHYTHM_UNITS = {"1/1", "1/2", "1/4", "1/8", "1/16", "1/32", "1/64"}

-- Stepper device types and their colors
local STEPPER_TYPES = {
  {name = "Pitch Stepper", color = {0.9, 0.3, 0.3}},
  {name = "Volume Stepper", color = {0.3, 0.9, 0.3}},
  {name = "Pan Stepper", color = {0.3, 0.3, 0.9}},
  {name = "Cutoff Stepper", color = {0.9, 0.9, 0.3}},
  {name = "Resonance Stepper", color = {0.9, 0.3, 0.9}},
  {name = "Drive Stepper", color = {0.3, 0.9, 0.9}}
}

local DEFAULT_SETTINGS = {
   note_count = 8,
   pattern_length = 8,
   scale = "pentatonic",
   unit = "1/8",  -- Keep default at 1/8
   min_volume = 0.8,
   max_volume = 1.0,
   lpb = 4,
   min_octave = 3,  -- Default lowest octave
   max_octave = 5,   -- Default highest octave
   always_render = false,
   current_phrase_index = 1,
   auto_advance = false,  -- New setting for auto-advancing to next phrase
   transpose = 0  -- Default transpose value
 }
 
 local dialog = nil
 local vb = nil  -- ViewBuilder instance
 local current_settings = table.copy(DEFAULT_SETTINGS)
 
 -- Add at the top with other globals
 local instrument_observer = nil
 local phrase_observer = nil
 local observers = {}
 
 function cleanup_observers()
   for _, observer in ipairs(observers) do
     if observer.subject and observer.subject.has_notifier and 
        observer.subject:has_notifier(observer.func) then
       observer.subject:remove_notifier(observer.func)
     end
   end
   observers = {}
 end
 
 function add_observer(subject, func)
   if subject and subject.has_notifier then
     if subject:has_notifier(func) then
       subject:remove_notifier(func)
     end
     subject:add_notifier(func)
     table.insert(observers, {subject = subject, func = func})
   end
 end
 
 -- Modify the instrument observer setup
 function setup_instrument_observer()
   cleanup_observers()  -- Clean up any existing observers
   
   local song = renoise.song()
   if not song then return end
   
   -- Observer for instrument selection changes
   local instr_observer = function()
     local instr = song.selected_instrument
     if not instr then return end
     
     -- Update instrument name in UI if it exists
     if vb and vb.views.instrument_name then
       vb.views.instrument_name.text = string.format("%02d: %s", 
         song.selected_instrument_index - 1,
         instr.name)
     end
     
     -- Read and update current values from the instrument
     if read_current_script_values() then
       update_ui_from_settings()
     end
   end
   
   add_observer(song, instr_observer)
   
   -- Also observe instrument name changes
   local instr = song.selected_instrument
   if instr then
     add_observer(instr, function()
       if vb and vb.views.instrument_name then
         vb.views.instrument_name.text = string.format("%02d: %s", 
           song.selected_instrument_index - 1,
           instr.name)
       end
     end)
   end
 end
 
 -- Add cleanup call when dialog closes
 function close_dialog()
   if dialog then
     cleanup_observers()
     dialog:close()
     dialog = nil
   end
 end
 
 -- Helper function to generate more musical patterns
 function generate_musical_pattern(length, old_pattern)
   local pattern = {}
   
   -- If pattern length is 1, always return {1}
   if length == 1 then
     return {1}
   end
   
   -- If we have an old pattern, preserve its content
   if old_pattern then
     -- Copy existing pattern values
     for i = 1, math.min(#old_pattern, length) do
       pattern[i] = old_pattern[i]
     end
     
     -- If increasing length, add one random step
     if length > #old_pattern then
       pattern[length] = math.random(0, 1)
     end
     -- If decreasing length, the last steps are automatically removed
   else
     -- Generate new pattern if no old pattern exists
     local last_val = 1
     for i = 1, length do
       -- Create more musical patterns by favoring alternating patterns
       -- and avoiding too many consecutive rests
       if last_val == 0 then
         last_val = (math.random() < 0.7) and 1 or 0
       else
         last_val = (math.random() < 0.4) and 0 or 1
       end
       pattern[i] = last_val
     end
   end
   
   return pattern
 end
 
 function generate_notes_only(settings)
   local notes = NOTE_RANGES[settings.scale]
   local num_notes = math.random(settings.min_notes, settings.max_notes)
   local emit = {}
   
   -- Generate more varied note sequences
   for i = 1, num_notes do
     local key = notes[math.random(#notes)]
     local volume = settings.min_volume + math.random() * (settings.max_volume - settings.min_volume)  -- Use proper 0.0-1.0 range
     table.insert(emit, string.format('{ key = "%s", volume = %.2f }', key, volume))
   end
   
   return "  emit = { " .. table.concat(emit, ", ") .. " }"
 end
 
 -- Helper function to get note with specific octave and proper naming
 local function get_note_in_octave_range(base_note, min_oct, max_oct)
   -- Extract note name and current octave
   local note_name = base_note:match("([a-g][#%-]?)")
   if not note_name then
     print("Error: Could not extract note name from", base_note)
     return base_note -- Return original note if we can't parse it
   end
   
   -- Clean up the note name - only keep "-" if it's a flat note
   note_name = note_name:gsub("%-$", "")
   
   local octave = math.random(min_oct, max_oct)
   return note_name .. octave
 end
 
 -- Modify generate_valid_script_paragraphs to use octave range
 function generate_valid_script_paragraphs(settings, preserve_existing)
   local notes = NOTE_RANGES[settings.scale]
   local emit = {}
   
   -- If we should preserve existing notes, get them first
   if preserve_existing then
     local instr = renoise.song().selected_instrument
     if instr and #instr.phrases > 0 then
       local phrase = instr.phrases[1]
       local script = phrase.script
       if script then
         -- Parse existing emit section to preserve notes
         for _, line in ipairs(script.paragraphs) do
           local emit_str = line:match('emit%s*=%s*{(.+)}')
           if emit_str then
             -- Extract existing notes and volumes
             for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
               table.insert(emit, { key = key, volume = tonumber(vol) })
             end
             break
           end
         end
       end
     end
   end
   
   -- Keep existing notes up to the new note_count
   while #emit > settings.note_count do
     table.remove(emit)
   end
   
   -- If we need more notes, add new random ones with proper octave range
   while #emit < settings.note_count do
     local base_note = notes[math.random(#notes)]
     local key = get_note_in_octave_range(base_note, settings.min_octave, settings.max_octave)
     local volume = settings.min_volume + math.random() * (settings.max_volume - settings.min_volume)
     table.insert(emit, { key = key, volume = volume })
   end
   
   -- Convert emit table to strings with compact formatting
   local emit_strings = {}
   for _, note in ipairs(emit) do
     table.insert(emit_strings, format_emit_entry(note.key, note.volume))
   end
 
   local pattern = generate_musical_pattern(settings.pattern_length)
 
   return {
     "return rhythm {",
     string.format('  unit = "%s",', settings.unit),
     string.format("  pattern = {%s},", table.concat(pattern, ",")),
     string.format("  emit = {%s}", table.concat(emit_strings, ",")),
     "}"
   }
 end
 
 function read_current_script_values()
   local instr = renoise.song().selected_instrument
   if not instr or #instr.phrases == 0 then return end
   
   local phrase = instr.phrases[1]
   local script = phrase.script
   if not script then return end
   
   -- Get LPB from phrase
   current_settings.lpb = phrase.lpb
   
   -- Parse the script content
   for _, line in ipairs(script.paragraphs) do
     -- Find unit
     local unit_match = line:match('unit%s*=%s*"([^"]+)"')
     if unit_match then
       current_settings.unit = unit_match
     end
     
     -- Find pattern length and values
     local pattern_str = line:match('pattern%s*=%s*{([^}]+)}')
     if pattern_str then
       local pattern_values = {}
       for num in pattern_str:gmatch("%d+") do
         table.insert(pattern_values, tonumber(num))
       end
       current_settings.pattern_length = #pattern_values
     end
     
     -- Find notes and volumes - handle both formats:
     -- emit = { "c4" } and emit = { { key = "c-4", volume = 0.8 } }
     local emit_str = line:match('emit%s*=%s*{(.+)}')
     if emit_str then
       local note_count = 0
       local min_vol, max_vol = 1.0, 0.0
       
       -- First try to match the simple string format: "c4"
       for note in emit_str:gmatch('"([^"]+)"') do
         note_count = note_count + 1
         -- For simple format, assume default volumes
         min_vol = 0.8
         max_vol = 1.0
       end
       
       -- If no simple format found, try the complex format
       if note_count == 0 then
         for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
           note_count = note_count + 1
           local volume = tonumber(vol)
           min_vol = math.min(min_vol, volume)
           max_vol = math.max(max_vol, volume)
         end
       end
       
       -- Update settings if we found any notes
       if note_count > 0 then
         current_settings.note_count = note_count
         current_settings.min_volume = min_vol
         current_settings.max_volume = max_vol
       end
     end
   end
   
   return true
 end
 
 function update_notes_only(settings)
   local instr = renoise.song().selected_instrument
   if not instr or #instr.phrases == 0 then return end
   
   local phrase = instr.phrases[1]
   local script = phrase.script
   if not script then return end
   
   -- Keep existing unit and pattern, only update emit
   local new_paragraphs = {}
   local found_emit = false
   
   for _, line in ipairs(script.paragraphs) do
     if line:match("^%s*emit%s*=") then
       table.insert(new_paragraphs, generate_notes_only(settings))
       found_emit = true
     else
       table.insert(new_paragraphs, line)
     end
   end
   
   -- If no emit found, generate full script
   if not found_emit then
     script.paragraphs = generate_valid_script_paragraphs(settings)
   else
     script.paragraphs = new_paragraphs
   end
   
   script:commit()
   
   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   renoise.app():show_status("Updated notes in pattern")
 end
 
 -- Helper function to format pattern status with step size
 function format_pattern_status(pattern, unit, direction)
   local pattern_viz = {}
   for _, val in ipairs(pattern) do
     table.insert(pattern_viz, val == 1 and "■" or "□")
   end
   return string.format("Pattern (%s) (%02d): %s %s", 
     unit, #pattern, table.concat(pattern_viz, ""), direction or "")
 end
 
 -- Modified note status formatter to include step size
 function format_note_status(notes, unit, direction)
   -- Helper function to format notes in a consistent way
   local note_info = {}
   for _, note in ipairs(notes) do
     local note_name = note.key:match("([a-g][#%-]?)")
     local octave = note.key:match("%d+$")
     if note_name and octave then
       -- Capitalize the note name
       note_name = note_name:gsub("^%l", string.upper):gsub("%-$", "") -- Remove trailing - if not a flat
       table.insert(note_info, string.format("%s%s:%.0f", note_name, octave, note.volume * 100))
     end
   end
   return string.format("Note (%s) (%02d): %s %s", 
     unit, #notes, table.concat(note_info, ", "), direction or "")
 end
 
 function update_pattern_length(settings, old_length)
   local instr = renoise.song().selected_instrument
   if not instr or #instr.phrases == 0 then return end
   
   local phrase = instr.phrases[current_settings.current_phrase_index]
   local script = phrase.script
   if not script then return end
   
   -- Find current pattern, unit and emit sections
   local current_pattern = {}
   local current_unit = settings.unit
   local existing_notes = {}
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match('pattern%s*=%s*{([^}]+)}')
     local unit_str = line:match('unit%s*=%s*"([^"]+)"')
     local emit_str = line:match('emit%s*=%s*{(.+)}')
     
     if pattern_str then
       for num in pattern_str:gmatch("[01]") do
         table.insert(current_pattern, tonumber(num))
       end
     end
     if unit_str then
       current_unit = unit_str
     end
     if emit_str then
       for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
         table.insert(existing_notes, {key=key, volume=tonumber(vol)})
       end
     end
   end
   
   -- Generate new pattern preserving existing content
   local new_pattern = {}
   
   -- If length is 1, force trigger to 1
   if settings.pattern_length == 1 then
     new_pattern = {1}
   else
     -- Copy existing pattern values up to new length
     for i = 1, math.min(#current_pattern, settings.pattern_length) do
       new_pattern[i] = current_pattern[i]
     end
     
     -- If increasing length, fill remaining slots with alternating values
     if settings.pattern_length > #current_pattern then
       local last_val = new_pattern[#new_pattern] or 1
       for i = #new_pattern + 1, settings.pattern_length do
         if last_val == 0 then
           last_val = (math.random() < 0.7) and 1 or 0
         else
           last_val = (math.random() < 0.4) and 0 or 1
         end
         new_pattern[i] = last_val
       end
     end
   end
   
   -- Convert emit table to strings with compact formatting
   local emit_strings = {}
   for _, note in ipairs(existing_notes) do
     -- Clean up note name
     local note_name = note.key:match("([a-g][#%-]?)")
     local octave = note.key:match("%d+$")
     if note_name and octave then
       note_name = note_name:gsub("%-$", "") -- Remove trailing - if not a flat
       local clean_key = note_name .. octave
       table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', clean_key, note.volume))
     end
   end
   
   -- Rebuild the script with the modified pattern
   script.paragraphs = {
     "return rhythm {",
     string.format('  unit = "%s",', current_unit),
     string.format("  pattern = {%s},", table.concat(new_pattern, ",")),
     string.format("  emit = {%s}", table.concat(emit_strings, ",")),
     "}"
   }
   
   script:commit()
   
   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   -- More accurate message about pattern length change
   local diff = settings.pattern_length - old_length
   if diff > 0 then
     renoise.app():show_status(format_pattern_status(new_pattern, current_unit, ">"))
   elseif diff < 0 then
     renoise.app():show_status(format_pattern_status(new_pattern, current_unit, "<"))
   end

   -- Add auto-render if enabled
   if settings.always_render then
     render_to_pattern(script, settings, false)
   end
 end
 
 -- Add this function for velocity randomization
 function randomize_velocity(settings)
   local instr = renoise.song().selected_instrument
   if not instr or #instr.phrases == 0 then return end
   
   local phrase = instr.phrases[current_settings.current_phrase_index]
   local script = phrase.script
   if not script then return end
   
   -- Find current pattern, unit and existing notes
   local current_pattern = {}
   local current_unit = ""
   local existing_notes = {}
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match('pattern%s*=%s*{([^}]+)}')
     local unit_str = line:match('unit%s*=%s*"([^"]+)"')
     local emit_str = line:match('emit%s*=%s*{(.+)}')
     
     if pattern_str then
       for num in pattern_str:gmatch("[01]") do
         table.insert(current_pattern, tonumber(num))
       end
     end
     if unit_str then current_unit = unit_str end
     if emit_str then
       -- Extract existing notes with their keys
       for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
         table.insert(existing_notes, {key=key})
       end
     end
   end
   
   -- Generate new random volumes
   local emit_strings = {}
   local updated_notes = {}
   for _, note in ipairs(existing_notes) do
     local volume = settings.min_volume + math.random() * (settings.max_volume - settings.min_volume)
     table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', note.key, volume))
     table.insert(updated_notes, {key=note.key, volume=volume})
   end
   
   -- Rebuild script preserving everything except volumes
   script.paragraphs = {
     "return rhythm {",
     string.format('  unit = "%s",', current_unit),
     string.format("  pattern = {%s},", table.concat(current_pattern, ",")),
     string.format("  emit = {%s}", table.concat(emit_strings, ",")),
     "}"
   }
   
   script:commit()
   
   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   renoise.app():show_status(format_note_status(updated_notes, current_unit))
   
   -- Add auto-render if enabled
   if settings.always_render then
     render_to_pattern(script, settings, false)
   end
 end
 
 -- Update randomize_all_settings function with proper ranges
 function randomize_all_settings()
   -- Store old values to detect changes
   local old_settings = table.copy(current_settings)
   
   -- Randomize scale
   current_settings.scale = SCALE_NAMES[math.random(#SCALE_NAMES)]
   
   -- Randomize unit - simple random choice
   current_settings.unit = RHYTHM_UNITS[math.random(#RHYTHM_UNITS)]
   
   -- Randomize pattern length (1-32)
   current_settings.pattern_length = math.random(1, 32)
   
   -- Randomize note count (1-32)
   current_settings.note_count = math.random(1, 32)
   
   -- Randomize volumes
   current_settings.min_volume = math.random()  -- 0.0 to 1.0
   current_settings.max_volume = math.random()  -- 0.0 to 1.0
   -- Swap if min > max
   if current_settings.min_volume > current_settings.max_volume then
     current_settings.min_volume, current_settings.max_volume = current_settings.max_volume, current_settings.min_volume
   end
   
   -- Randomize LPB within reasonable range (1-16)
   local lpb_values = {1, 2, 3, 4, 6, 8, 12, 16}
   current_settings.lpb = lpb_values[math.random(#lpb_values)]
   
   -- Randomize octave range (1-9 for both)
   current_settings.min_octave = math.random(1, 9)
   current_settings.max_octave = math.random(1, 9)
   -- Swap if min > max
   if current_settings.min_octave > current_settings.max_octave then
     current_settings.min_octave, current_settings.max_octave = current_settings.max_octave, current_settings.min_octave
   end
   
   -- Update phrase LPB
   local instr = renoise.song().selected_instrument
   if instr and #instr.phrases > 0 then
     local phrase = instr.phrases[current_settings.current_phrase_index]
     phrase.lpb = current_settings.lpb
   end
   
   -- Update UI elements
   if dialog and dialog.visible then
     -- Update all view values
     vb.views.note_count_slider.value = current_settings.note_count
     vb.views.pattern_length_slider.value = current_settings.pattern_length
     vb.views.min_volume_slider.value = current_settings.min_volume
     vb.views.max_volume_slider.value = current_settings.max_volume
     vb.views.min_octave_box.value = current_settings.min_octave
     vb.views.max_octave_box.value = current_settings.max_octave
     
     -- Update scale popup
     local scale_index = table.find(SCALE_NAMES, current_settings.scale) or 1
     vb.views.scale_popup.value = scale_index
     
     -- Update unit switch
     local unit_index = table.find(RHYTHM_UNITS, current_settings.unit) or 1
     vb.views.unit_switch.value = unit_index
     
     -- Update LPB switch
     local lpb_values = {"1", "2", "3", "4", "6", "8", "12", "16"}
     local lpb_index = table.find(lpb_values, tostring(current_settings.lpb)) or 4
     vb.views.lpb_switch.value = lpb_index
   end
   
   -- Generate new pattern with new settings
   live_code(current_settings)
   
   -- Get current notes for status display
   local instr = renoise.song().selected_instrument
   if instr and #instr.phrases > 0 then
     local phrase = instr.phrases[current_settings.current_phrase_index]
     local script = phrase.script
     if script then
       local existing_notes = {}
       for _, line in ipairs(script.paragraphs) do
         local emit_str = line:match('emit%s*=%s*{(.+)}')
         if emit_str then
           for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
             table.insert(existing_notes, {key=key, volume=tonumber(vol)})
           end
         end
       end
       
       -- Format note status with scale info
       local note_status = format_note_status(existing_notes, current_settings.unit)
       note_status = note_status .. " [" .. SCALE_DISPLAY_NAMES[current_settings.scale] .. "]"
       renoise.app():show_status(note_status)
       
       -- Add auto-render if enabled
       if current_settings.always_render then
         render_to_pattern(script, current_settings, false)
       end
     end
   end
 end
 
 -- Helper function to randomize only the octaves of existing notes
 function randomize_voicings(settings)
   local instr = renoise.song().selected_instrument
   if not instr or #instr.phrases == 0 then return end
   
   local phrase = instr.phrases[current_settings.current_phrase_index]
   local script = phrase.script
   if not script then return end
   
   -- Find current pattern, unit and existing notes
   local current_pattern = {}
   local current_unit = ""
   local existing_notes = {}
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match('pattern%s*=%s*{([^}]+)}')
     local unit_str = line:match('unit%s*=%s*"([^"]+)"')
     local emit_str = line:match('emit%s*=%s*{(.+)}')
     
     if pattern_str then
       for num in pattern_str:gmatch("[01]") do
         table.insert(current_pattern, tonumber(num))
       end
     end
     if unit_str then current_unit = unit_str end
     if emit_str then
       -- Extract existing notes and randomize their octaves within current range
       for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
         -- Extract note name without octave
         local note_name = key:match("([a-g][#%-]?)")
         if note_name then
           -- Clean up note name - remove trailing - if not a flat
           note_name = note_name:gsub("%-$", "")
           -- Generate new octave within current min/max range
           local new_octave = math.random(settings.min_octave, settings.max_octave)
           local new_key = note_name .. new_octave
           table.insert(existing_notes, {key=new_key, volume=tonumber(vol)})
         end
       end
     end
   end
   
   -- Convert emit table to strings with compact formatting
   local emit_strings = {}
   for _, note in ipairs(existing_notes) do
     table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', note.key, note.volume))
   end
   
   -- Rebuild script preserving pattern and unit
   script.paragraphs = {
     "return rhythm {",
     string.format('  unit = "%s",', current_unit),
     string.format("  pattern = {%s},", table.concat(current_pattern, ",")),
     string.format("  emit = {%s}", table.concat(emit_strings, ",")),
     "}"
   }
   
   script:commit()
   
   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   renoise.app():show_status(format_note_status(existing_notes, current_unit))
   
   -- Add auto-render if enabled
   if settings.always_render then
     render_to_pattern(script, settings, false)
   end
 end
 
 -- Add this function to update the instrument name display
 function update_instrument_display()
   if not (dialog and dialog.visible) then return end
   
   local song = renoise.song()
   local current_index = song.selected_instrument_index
   local current_name = song.instruments[current_index].name
   
   -- Update valuebox (subtract 1 to show 00-based index)
   vb.views.instrument_selector.value = current_index - 1
   -- Update name display
   vb.views.instrument_name.text = current_name
   
   -- Update transpose display
   if vb.views.transpose_display then
     vb.views.transpose_display.text = tostring(song.instruments[current_index].transpose)
   end
   
   -- Read current values from the phrase
   read_current_script_values()
   
   -- Update all UI elements with current settings
   vb.views.note_count_slider.value = current_settings.note_count
   vb.views.pattern_length_slider.value = current_settings.pattern_length
   vb.views.min_volume_slider.value = current_settings.min_volume
   vb.views.max_volume_slider.value = current_settings.max_volume
   vb.views.min_octave_box.value = current_settings.min_octave
   vb.views.max_octave_box.value = current_settings.max_octave
   
   -- Update text displays
   if vb.views.pattern_length_text then
     vb.views.pattern_length_text.text = string.format("%d steps", current_settings.pattern_length)
   end
   if vb.views.note_count_text then
     vb.views.note_count_text.text = string.format("%d", current_settings.note_count)
   end
   if vb.views.min_volume_text then
     vb.views.min_volume_text.text = string.format("%d%%", math.floor(current_settings.min_volume * 100))
   end
   if vb.views.max_volume_text then
     vb.views.max_volume_text.text = string.format("%d%%", math.floor(current_settings.max_volume * 100))
   end
   
   -- Update scale popup
   local scale_index = table.find(SCALE_NAMES, current_settings.scale) or 1
   vb.views.scale_popup.value = scale_index
   
   -- Update unit switch
   local unit_index = table.find(RHYTHM_UNITS, current_settings.unit) or 1
   vb.views.unit_switch.value = unit_index
   
   -- Update LPB switch
   local lpb_values = {"1", "2", "3", "4", "6", "8", "12", "16"}
   local lpb_index = table.find(lpb_values, tostring(current_settings.lpb)) or 4
   vb.views.lpb_switch.value = lpb_index
   
   -- Update phrase selector
   update_phrase_display()
 end
 
 function pakettiPhraseGeneratorDialog_content()
   -- Create text labels first with consistent style and width
   local pattern_length_text = vb:text { 
     text = string.format("%d steps", current_settings.pattern_length),
     font = "bold",
     style = "strong"
   }
   local note_count_text = vb:text { 
     text = string.format("%d", current_settings.note_count),
     font = "bold",
     style = "strong"
   }
   local min_volume_text = vb:text { 
     text = string.format("%d%%", math.floor(current_settings.min_volume * 100)),
     font = "bold",
     style = "strong"
   }
   local max_volume_text = vb:text { 
     text = string.format("%d%%", math.floor(current_settings.max_volume * 100)),
     font = "bold",
     style = "strong"
   }
   local lpb_text = vb:text { 
     text = string.format("%d", current_settings.lpb),
     font = "bold",
     style = "strong"
   }

   -- Make text views accessible to other functions
   vb.views.pattern_length_text = pattern_length_text
   vb.views.note_count_text = note_count_text
   vb.views.min_volume_text = min_volume_text
   vb.views.max_volume_text = max_volume_text

   return vb:column {
     margin = 5,
     
     -- Instrument selector row
     vb:horizontal_aligner {
       vb:text { 
         text = "Instrument",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:valuebox {
         id = "instrument_selector",
         min = 0,
         max = 255,
         value = renoise.song().selected_instrument_index - 1,
         width = 50,
         notifier = function(value)
           local new_index = value + 1
           local song = renoise.song()
           if new_index >= 1 and new_index <= #song.instruments then
             song.selected_instrument_index = new_index
             update_instrument_display()
           end
         end
       },
       vb:text {
         id = "instrument_name",
         text = renoise.song().instruments[renoise.song().selected_instrument_index].name,
         font = "bold"
       },
       vb:button {
         text = "Pakettify",
         tooltip = "Convert the current instrument to Paketti format",
         notifier = function()
           PakettiInjectDefaultXRNI()
           update_instrument_display()
         end
       }
     },

     -- Instrument transpose row
     vb:horizontal_aligner {
       vb:text { 
         text = "Transpose",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:text {
         id = "transpose_display",
         text = "0",
         width = 50,
         font = "bold",
         style = "strong"
       },
       vb:row {
         vb:button {
           text = "-36",
           width = 40,
           notifier = function()
             local instr = renoise.song().selected_instrument
             if instr then
               instr.transpose = -36
               vb.views.transpose_display.text = tostring(-36)
             end
           end
         },
         vb:button {
           text = "-24",
           width = 40,
           notifier = function()
             local instr = renoise.song().selected_instrument
             if instr then
               instr.transpose = -24
               vb.views.transpose_display.text = tostring(-24)
             end
           end
         },
         vb:button {
           text = "-12",
           width = 40,
           notifier = function()
             local instr = renoise.song().selected_instrument
             if instr then
               -- Subtract 12 from current transpose
               instr.transpose = instr.transpose - 12
               vb.views.transpose_display.text = tostring(instr.transpose)
             end
           end
         },
         vb:button {
           text = "0",
           width = 40,
           notifier = function()
             local instr = renoise.song().selected_instrument
             if instr then
               instr.transpose = 0
               vb.views.transpose_display.text = "0"
             end
           end
         },
         vb:button {
           text = "+12",
           width = 40,
           notifier = function()
             local instr = renoise.song().selected_instrument
             if instr then
               -- Add 12 to current transpose
               instr.transpose = instr.transpose + 12
               vb.views.transpose_display.text = tostring(instr.transpose)
             end
           end
         },
         vb:button {
           text = "+24",
           width = 40,
           notifier = function()
             local instr = renoise.song().selected_instrument
             if instr then
               instr.transpose = 24
               vb.views.transpose_display.text = tostring(24)
             end
           end
         },
         vb:button {
           text = "+36",
           width = 40,
           notifier = function()
             local instr = renoise.song().selected_instrument
             if instr then
               instr.transpose = 36
               vb.views.transpose_display.text = tostring(36)
             end
           end
         }
       }
     },

     -- Phrase selector row
     vb:horizontal_aligner {
       vb:text { 
         text = "Phrase",
         width = 90,
         font = "bold",
         style = "strong",
         tooltip = "Select which phrase to edit"
       },
       vb:popup {
         id = "phrase_selector",
         width = 150,
         items = (function()
           local instr = renoise.song().selected_instrument
           if not instr then return {"None"} end
           local phrases = {}
           for i = 1, #instr.phrases do
             phrases[i] = string.format("%02d: %s", i, instr.phrases[i].name)
           end
           return #phrases > 0 and phrases or {"None"}
         end)(),
         value = current_settings.current_phrase_index,
         tooltip = "Select the phrase to edit",
         notifier = function(idx)
           current_settings.current_phrase_index = idx
           update_phrase_display()
         end
       },
       vb:button {
         text = "Duplicate",
         tooltip = "Create a copy of the current phrase and start playing it",
         notifier = function()
           local instr = renoise.song().selected_instrument
           if not instr then return end
           
           local source_phrase = instr.phrases[current_settings.current_phrase_index]
           if not source_phrase then return end
           
           -- Create new phrase
           local new_idx = #instr.phrases + 1
           instr:insert_phrase_at(new_idx)
           local new_phrase = instr.phrases[new_idx]
           
           -- Copy content
           new_phrase.lpb = source_phrase.lpb
           new_phrase.script.paragraphs = table.copy(source_phrase.script.paragraphs)
           new_phrase.script:commit()
           
           -- Select new phrase
           current_settings.current_phrase_index = new_idx
           update_phrase_display()

           -- Select and play the new phrase
           instr.selected_phrase_index = new_idx
           instr.phrase_playback_mode = renoise.Instrument.PHRASES_OFF
           instr.phrase_playback_mode = renoise.Instrument.PHRASES_PLAY_SELECTIVE
           
           renoise.app():show_status(string.format("Duplicated phrase %d to %d", 
             current_settings.current_phrase_index - 1, new_idx))
         end
       },
       vb:button {
         text = "Reverse",
         tooltip = "Reverse the current pattern",
         notifier = function()
           local instr = renoise.song().selected_instrument
           if not instr or #instr.phrases == 0 then return end
           
           local phrase = instr.phrases[current_settings.current_phrase_index]
           local script = phrase.script
           if not script then return end
           
           -- Find and reverse the pattern
           local new_paragraphs = {}
           local current_unit = ""
           local reversed_pattern = {}
           
           for _, line in ipairs(script.paragraphs) do
             local pattern_str = line:match('pattern%s*=%s*{([^}]+)}')
             local unit_str = line:match('unit%s*=%s*"([^"]+)"')
             
             if pattern_str then
               -- Extract and reverse the pattern
               for num in pattern_str:gmatch("[01]") do
                 table.insert(reversed_pattern, 1, tonumber(num))  -- Insert at beginning to reverse
               end
               table.insert(new_paragraphs, string.format('  pattern = {%s},', table.concat(reversed_pattern, ",")))
             elseif unit_str then
               current_unit = unit_str
               table.insert(new_paragraphs, line)
             else
               table.insert(new_paragraphs, line)
             end
           end
           
           script.paragraphs = new_paragraphs
           script:commit()
           
           if script.compile_error ~= "" then
             local msg = "Compile error: " .. script.compile_error
             print(msg)
             renoise.app():show_status(msg)
             return
           end
           
           -- Show pattern status with visualization
           renoise.app():show_status(format_pattern_status(reversed_pattern, current_unit, "(Reversed)"))
           
           -- Render if auto-render is enabled
           if current_settings.always_render then
             render_to_pattern(script, current_settings, false)
           end
         end
       }
     },

     -- Always Render checkbox
     vb:horizontal_aligner {
       vb:text { 
         text = "Always Render",
         width = 90,
         font = "bold",
         style = "strong",
         tooltip = "When enabled, any change will automatically render to pattern"
       },
       vb:checkbox {
         value = current_settings.always_render,
         notifier = function(value)
           current_settings.always_render = value
         end,
         tooltip = "Enable to automatically render changes to pattern"
       }
     },

     -- Randomize and render controls
     vb:horizontal_aligner {
       
       vb:button {
         text = "Randomize All",
         tooltip = "Randomize all settings",
         notifier = function()
           randomize_all_settings()
           if current_settings.always_render then
             local instr = renoise.song().selected_instrument
             if instr and #instr.phrases > 0 then
               local phrase = instr.phrases[current_settings.current_phrase_index]
               if phrase and phrase.script then
                 render_to_pattern(phrase.script, current_settings, false)
               end
             end
           end
         end
       },

       vb:button {
         text = "Randomize Voicings",
         tooltip = "Randomize the octaves of existing notes",
         notifier = function()
           randomize_voicings(current_settings)
           if current_settings.always_render then
             local instr = renoise.song().selected_instrument
             if instr and #instr.phrases > 0 then
               local phrase = instr.phrases[current_settings.current_phrase_index]
               if phrase and phrase.script then
                 render_to_pattern(phrase.script, current_settings, false)
               end
             end
           end
         end
       },
       
       vb:button {
         text = "Randomize Velocity",
         tooltip = "Randomize the velocities of existing notes",
         notifier = function()
           randomize_velocity(current_settings)
           if current_settings.always_render then
             local instr = renoise.song().selected_instrument
             if instr and #instr.phrases > 0 then
               local phrase = instr.phrases[current_settings.current_phrase_index]
               if phrase and phrase.script then
                 render_to_pattern(phrase.script, current_settings, false)
               end
             end
           end
         end
       },
       
       vb:button {
         text = "Render",
         tooltip = "Render the current phrase to pattern",
         notifier = function()
           local instr = renoise.song().selected_instrument
           if not instr or #instr.phrases == 0 then return end
           
           local phrase = instr.phrases[current_settings.current_phrase_index]
           if not phrase or not phrase.script then return end
           
           -- For explicit Render button, always show status
           render_to_pattern(phrase.script, current_settings, true)
         end
       }
     },

     -- Pattern length controls
     vb:horizontal_aligner {
       vb:text { 
         text = "Length",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:minislider {
         id = "pattern_length_slider",
         min = 1,
         max = 32,
         value = math.floor(current_settings.pattern_length),
         width = 250,
         notifier = function(value)
           local old_length = current_settings.pattern_length
           value = math.floor(value)
           current_settings.pattern_length = value
           pattern_length_text.text = string.format("%d steps", value)
           update_pattern_length(current_settings, old_length)
         end
       },
       pattern_length_text
     },

     -- Note count controls
     vb:horizontal_aligner {
       vb:text { 
         text = "Note Count",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:minislider {
         id = "note_count_slider",
         min = 0,
         max = 32,
         value = math.floor(current_settings.note_count),
         width = 250,
         notifier = function(value)
           value = math.floor(value)
           local old_count = current_settings.note_count
           current_settings.note_count = value
           note_count_text.text = string.format("%d", value)
           update_note_count(current_settings, old_count)
         end
       },
       note_count_text
     },

     -- Volume range controls
     vb:horizontal_aligner {
       vb:text { 
         text = "Volume Range",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:minislider {
         id = "min_volume_slider",
         min = 0,
         max = 1,
         value = current_settings.min_volume,
         width = 120,
         notifier = function(value)
           current_settings.min_volume = value
           min_volume_text.text = string.format("%d%%", math.floor(value * 100))
           update_volume_only(current_settings)
         end
       },
       min_volume_text,
       vb:text { text = " - " },
       vb:minislider {
         id = "max_volume_slider",
         min = 0,
         max = 1,
         value = current_settings.max_volume,
         width = 120,
         notifier = function(value)
           current_settings.max_volume = value
           max_volume_text.text = string.format("%d%%", math.floor(value * 100))
           update_volume_only(current_settings)
         end
       },
       max_volume_text
     },

     -- Octave range controls
     vb:horizontal_aligner {
       vb:text { 
         text = "OctVoicings",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:valuebox {
         id = "min_octave_box",
         min = 1,
         max = 9,
         value = current_settings.min_octave,
         width = 120,
         notifier = function(value)
           current_settings.min_octave = value
           update_octave_range(current_settings)
         end
       },
       vb:text { text = " - " },
       vb:valuebox {
         id = "max_octave_box",
         min = 1,
         max = 9,
         value = current_settings.max_octave,
         width = 120,
         notifier = function(value)
           current_settings.max_octave = value
           update_octave_range(current_settings)
         end
       },
       vb:button {
         text = "-1",
         width = 30,
         notifier = function()
           -- Ensure we don't go below 1
           if current_settings.min_octave > 1 and current_settings.max_octave > 1 then
             current_settings.min_octave = current_settings.min_octave - 1
             current_settings.max_octave = current_settings.max_octave - 1
             vb.views.min_octave_box.value = current_settings.min_octave
             vb.views.max_octave_box.value = current_settings.max_octave
             update_octave_range(current_settings)
           end
         end
       },
       vb:button {
         text = "+1",
         width = 30,
         notifier = function()
           -- Ensure we don't go above 9
           if current_settings.min_octave < 9 and current_settings.max_octave < 9 then
             current_settings.min_octave = current_settings.min_octave + 1
             current_settings.max_octave = current_settings.max_octave + 1
             vb.views.min_octave_box.value = current_settings.min_octave
             vb.views.max_octave_box.value = current_settings.max_octave
             update_octave_range(current_settings)
           end
         end
       }
     },

     -- Scale selection
     vb:horizontal_aligner {
       vb:text { 
         text = "Scale",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:popup {
         id = "scale_popup",
         items = SCALE_NAMES,
         value = table.find(SCALE_NAMES, current_settings.scale) or 1,
         width = 250,
         notifier = function(value)
           current_settings.scale = SCALE_NAMES[value]
           live_code(current_settings)
         end
       }
     },

     -- Step size and LPB controls
     vb:horizontal_aligner {
       vb:text { 
         text = "Step Size",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:switch {
         id = "unit_switch",
         items = RHYTHM_UNITS,
         value = table.find(RHYTHM_UNITS, current_settings.unit) or 1,
         width = 250,
         notifier = function(value)
           current_settings.unit = RHYTHM_UNITS[value]
           update_unit_only(current_settings)
           if current_settings.always_render then
             local instr = renoise.song().selected_instrument
             if instr and #instr.phrases > 0 then
               local phrase = instr.phrases[current_settings.current_phrase_index]
               if phrase and phrase.script then
                 render_to_pattern(phrase.script, current_settings, false)
               end
             end
           end
         end
       }
     },

     vb:horizontal_aligner {
       vb:text { 
         text = "LPB",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:switch {
         id = "lpb_switch",
         items = {"1", "2", "3", "4", "6", "8", "12", "16"},
         value = table.find({"1", "2", "3", "4", "6", "8", "12", "16"}, tostring(current_settings.lpb)) or 4,
         width = 250,
         notifier = function(value)
           local lpb_values = {"1", "2", "3", "4", "6", "8", "12", "16"}
           current_settings.lpb = tonumber(lpb_values[value])
           local instr = renoise.song().selected_instrument
           if instr and #instr.phrases > 0 then
             instr.phrases[current_settings.current_phrase_index].lpb = current_settings.lpb
           end
         end
       }
     },

     -- Stepper buttons row
     vb:horizontal_aligner {
       vb:text { 
         text = "Steppers",
         width = 90,
         font = "bold",
         style = "strong"
       },
       
       vb:row {         
         -- Add buttons for each stepper type
         (function()
           local buttons = {}
           for i = 1, #STEPPER_TYPES do
             local stepper = STEPPER_TYPES[i]
             buttons[i] = vb:button {
               text = stepper.name:gsub(" Stepper", ""),
               color = stepper.color,
               width = 70,
               tooltip = string.format("Show/Hide %s editor", stepper.name),
               notifier = function()
                 toggle_stepper(stepper.name)
               end
             }
           end
           return unpack(buttons)
         end)()
       }
     },
   }
 end
 
 function live_code(settings)
   local instr = renoise.song().selected_instrument
   if not instr then
     local msg = "No instrument selected."
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   -- Create a phrase if none exists
   if #instr.phrases == 0 then
     instr:insert_phrase_at(1)
   end
   
   local phrase = instr.phrases[1]
   local script = phrase.script
   if not script then
     local msg = "Phrase script is not available."
     print(msg)
     renoise.app():show_status(msg)
     return
   end

   -- Find current pattern and emit
   local current_pattern = {}
   local current_unit = settings.unit
   local existing_notes = {}
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match('pattern%s*=%s*{([^}]+)}')
     local unit_str = line:match('unit%s*=%s*"([^"]+)"')
     local emit_str = line:match('emit%s*=%s*{(.+)}')
     
     if pattern_str then
       for num in pattern_str:gmatch("[01]") do
         table.insert(current_pattern, tonumber(num))
       end
     end
     if unit_str then
       current_unit = unit_str
     end
     if emit_str then
       -- Extract existing notes to preserve volumes
       for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
         table.insert(existing_notes, {volume=tonumber(vol)})
       end
     end
   end
   
   -- Generate new notes in the new scale while preserving volumes
   local notes = NOTE_RANGES[settings.scale]
   local emit_strings = {}
   for i, note_data in ipairs(existing_notes) do
     local base_note = notes[math.random(#notes)]
     local key = get_note_in_octave_range(base_note, settings.min_octave, settings.max_octave)
     table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', key, note_data.volume))
   end

   -- Rebuild script preserving pattern and unit
   script.paragraphs = {
     "return rhythm {",
     string.format('  unit = "%s",', current_unit),
     string.format("  pattern = {%s},", table.concat(current_pattern, ",")),
     string.format("  emit = {%s}", table.concat(emit_strings, ",")),
     "}"
   }

   script:commit()

   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   renoise.app():show_status(string.format("Changed scale to %s", SCALE_DISPLAY_NAMES[settings.scale]))
 end
 
 function pakettiPhraseGeneratorDialog()
   if dialog and dialog.visible then
     dialog:close()
   end
   
   -- Create a fresh ViewBuilder instance
   vb = renoise.ViewBuilder()
   
   -- Read current values before creating dialog
   read_current_script_values()
   
   -- Read current instrument transpose value
   local instr = renoise.song().selected_instrument
   if instr then
     current_settings.transpose = instr.transpose
   end
   
   -- Show the dialog
   dialog = renoise.app():show_custom_dialog(
     "Enhanced Phrase Generator", 
     pakettiPhraseGeneratorDialog_content(),
     my_keyhandler_func
   )
   
   -- Update transpose display with current value
   if vb.views.transpose_display then
     vb.views.transpose_display.text = tostring(current_settings.transpose or 0)
   end
   
   -- Clean up existing observer if it exists
   if instrument_observer and renoise.song().selected_instrument_observable:has_notifier(instrument_observer) then
     instrument_observer:remove()
     instrument_observer = nil
   end
   
   -- Add new observer only if it doesn't exist
   if not instrument_observer then
     instrument_observer = renoise.song().selected_instrument_observable:add_notifier(
       function()
         update_instrument_display()
       end
     )
   end
   
   -- Add phrase observer
   local song = renoise.song()
   if song.selected_phrase_observable:has_notifier(phrase_observer) then
     phrase_observer:remove()
   end
   phrase_observer = song.selected_phrase_observable:add_notifier(function()
     if song.selected_instrument.selected_phrase_index then
       current_settings.current_phrase_index = song.selected_instrument.selected_phrase_index
       update_phrase_display()
     end
   end)
 end
 
 if renoise.API_VERSION >= 6.2 then 
 renoise.tool():add_menu_entry{name="Main Menu:Tools:Enhanced Phrase Generator",invoke=function() pakettiPhraseGeneratorDialog() end}
 renoise.tool():add_keybinding{name="Global:Tools:Enhanced Phrase Generator",invoke=function() pakettiPhraseGeneratorDialog() end}
 renoise.tool():add_menu_entry{name="Phrase Script Editor:Paketti..:Enhanced Phrase Generator",invoke=function() pakettiPhraseGeneratorDialog() end}
 end
 
 
 
 -- Helper function to update only volume values
 function update_volume_only(settings)
   local instr = renoise.song().selected_instrument
   if not instr or #instr.phrases == 0 then return end
   
   local phrase = instr.phrases[current_settings.current_phrase_index]
   local script = phrase.script
   if not script then return end
   
   -- Find and preserve current pattern, unit, and emit structure
   local current_pattern = {}
   local current_unit = ""
   local existing_notes = {}
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match('pattern%s*=%s*{([^}]+)}')
     local unit_str = line:match('unit%s*=%s*"([^"]+)"')
     local emit_str = line:match('emit%s*=%s*{(.+)}')
     
     if pattern_str then
       for num in pattern_str:gmatch("%d+") do
         table.insert(current_pattern, tonumber(num))
       end
     end
     if unit_str then current_unit = unit_str end
     if emit_str then
       -- Extract existing notes
       for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
         table.insert(existing_notes, {key=key})
       end
     end
   end
   
   -- Update volumes while keeping notes
   local emit_strings = {}
   local updated_notes = {}
   for _, note in ipairs(existing_notes) do
     local volume = settings.min_volume + math.random() * (settings.max_volume - settings.min_volume)
     table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', note.key, volume))
     table.insert(updated_notes, {key=note.key, volume=volume})
   end
   
   -- Rebuild script with compact formatting
   script.paragraphs = {
     "return rhythm {",
     string.format('  unit = "%s",', current_unit),
     string.format("  pattern = {%s},", table.concat(current_pattern, ",")),
     string.format("  emit = {%s}", table.concat(emit_strings, ",")),
     "}"
   }
   
   script:commit()
   
   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   -- Show status with updated velocities
   renoise.app():show_status(format_note_status(updated_notes, current_unit))

   -- Add auto-render if enabled
   if settings.always_render then
     render_to_pattern(script, settings, false)
   end
 end
 
 -- Helper function to update only unit value
 function update_unit_only(settings)
   local instr = renoise.song().selected_instrument
   if not instr or #instr.phrases == 0 then return end
   
   local phrase = instr.phrases[settings.current_phrase_index]
   local script = phrase.script
   if not script then return end
   
   -- Find current pattern and notes
   local current_pattern = {}
   local existing_notes = {}
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match('pattern%s*=%s*{([^}]+)}')
     local emit_str = line:match('emit%s*=%s*{(.+)}')
     
     if pattern_str then
       for num in pattern_str:gmatch("%d+") do
         table.insert(current_pattern, tonumber(num))
       end
     end
     if emit_str then
       -- Extract existing notes with their exact formatting
       for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
         table.insert(existing_notes, {key=key, volume=tonumber(vol)})
       end
     end
   end
   
   -- Convert emit table to strings with compact formatting
   local emit_strings = {}
   for _, note in ipairs(existing_notes) do
     table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', note.key, note.volume))
   end
   
   -- Only update the unit, keep pattern and emit with compact formatting
   script.paragraphs = {
     "return rhythm {",
     string.format('  unit = "%s",', settings.unit),
     string.format("  pattern = {%s},", table.concat(current_pattern, ",")),
     string.format("  emit = {%s}", table.concat(emit_strings, ",")),
     "}"
   }
   
   script:commit()
   
   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   -- Show both pattern and note content with new step size
   local pattern_status = format_pattern_status(current_pattern, settings.unit)
   local note_status = format_note_status(existing_notes, settings.unit)
   renoise.app():show_status(note_status)

   -- Add auto-render if enabled
   if settings.always_render then
     render_to_pattern(script, settings, false)
   end
 end
 
 -- Helper function to format emit entries without extra spaces
 function format_emit_entry(key, volume)
   -- Ensure key is properly formatted (uppercase note name)
   local note_name = key:match("([a-g][#%-]?)")
   local octave = key:match("%d+$")
   
   if note_name and octave then
     -- Capitalize note name and handle flats
     note_name = note_name:gsub("^%l", string.upper):gsub("%-$", "")
     -- Format with proper spacing and rounding of volume
     return string.format('{ key = "%s%s", volume = %.2f }', note_name, octave, volume)
   else
     return string.format('{ key = "%s", volume = %.2f }', key, volume)
   end
 end
 
 -- Helper function to update octave range
 function update_octave_range(settings)
   local instr = renoise.song().selected_instrument
   if not instr or #instr.phrases == 0 then return end
   
   local phrase = instr.phrases[current_settings.current_phrase_index]
   local script = phrase.script
   if not script then return end
   
   -- Find current pattern, unit and existing notes
   local current_pattern = {}
   local current_unit = ""
   local existing_notes = {}
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match('pattern%s*=%s*{([^}]+)}')
     local unit_str = line:match('unit%s*=%s*"([^"]+)"')
     local emit_str = line:match('emit%s*=%s*{(.+)}')
     
     if pattern_str then
       for num in pattern_str:gmatch("[01]") do
         table.insert(current_pattern, tonumber(num))
       end
     end
     if unit_str then current_unit = unit_str end
     if emit_str then
       -- Extract existing notes and update their octaves
       for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
         -- Extract note name without octave
         local note_name = key:match("([a-g][#%-]?)")
         if note_name then
           -- Clean up note name - remove trailing - if not a flat
           note_name = note_name:gsub("%-$", "")
           -- Generate new octave within current min/max range
           local new_octave = math.random(settings.min_octave, settings.max_octave)
           local new_key = note_name .. new_octave
           table.insert(existing_notes, {key=new_key, volume=tonumber(vol)})
         end
       end
     end
   end
   
   -- Convert emit table to strings with compact formatting
   local emit_strings = {}
   for _, note in ipairs(existing_notes) do
     table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', note.key, note.volume))
   end
   
   -- Rebuild script preserving pattern and unit
   script.paragraphs = {
     "return rhythm {",
     string.format('  unit = "%s",', current_unit),
     string.format("  pattern = {%s},", table.concat(current_pattern, ",")),
     string.format("  emit = {%s}", table.concat(emit_strings, ",")),
     "}"
   }
   
   script:commit()
   
   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   renoise.app():show_status(format_note_status(existing_notes, current_unit))

   -- Add auto-render if enabled
   if settings.always_render then
     render_to_pattern(script, settings, false)
   end
 end
 
 -- Helper function to update note count
 function update_note_count(settings, old_count)
   local instr = renoise.song().selected_instrument
   if not instr or #instr.phrases == 0 then return end
   
   local phrase = instr.phrases[current_settings.current_phrase_index]
   local script = phrase.script
   if not script then return end
   
   -- Find current pattern, unit and existing notes
   local current_pattern = {}
   local current_unit = ""
   local existing_notes = {}
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match('pattern%s*=%s*{([^}]+)}')
     local unit_str = line:match('unit%s*=%s*"([^"]+)"')
     local emit_str = line:match('emit%s*=%s*{(.+)}')
     
     if pattern_str then
       for num in pattern_str:gmatch("%d+") do
         table.insert(current_pattern, tonumber(num))
       end
     end
     if unit_str then
       current_unit = unit_str
     end
     if emit_str then
       -- Extract existing notes with their exact formatting
       for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
         table.insert(existing_notes, {key=key, volume=tonumber(vol)})
       end
     end
   end
   
   -- Generate emit section
   local emit = {}
   
   -- Keep existing notes up to the new note count
   for i = 1, math.min(#existing_notes, settings.note_count) do
     table.insert(emit, existing_notes[i])
   end
   
   -- If we need more notes, add new random ones
   local notes = NOTE_RANGES[settings.scale]
   while #emit < settings.note_count do
     local base_note = notes[math.random(#notes)]
     local key = get_note_in_octave_range(base_note, settings.min_octave, settings.max_octave)
     local volume = settings.min_volume + math.random() * (settings.max_volume - settings.min_volume)
     table.insert(emit, {key=key, volume=volume})
   end
   
   -- Convert emit table to strings with compact formatting
   local emit_strings = {}
   for _, note in ipairs(emit) do
     table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', note.key, note.volume))
   end
 
   -- Build script with preserved pattern and compact emit formatting
   script.paragraphs = {
     "return rhythm {",
     string.format('  unit = "%s",', current_unit),
     string.format("  pattern = {%s},", table.concat(current_pattern, ",")),
     string.format("  emit = {%s}", table.concat(emit_strings, ",")),
     "}"
   }
 
   script:commit()
 
   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   -- Show status with direction indicator based on the actual change
   local direction = settings.note_count > old_count and ">" or (settings.note_count < old_count and "<" or "")
   renoise.app():show_status(format_note_status(emit, current_unit, direction))

   -- Add auto-render if enabled
   if settings.always_render then
     render_to_pattern(script, settings, false)
   end
 end
 
 -- Add function to update phrase selector
 function update_phrase_selector()
   if not vb or not vb.views.phrase_selector then return end
   
   local instr = renoise.song().selected_instrument
   if not instr then return end
   
   local phrases = {}
   for i = 1, #instr.phrases do
     local phrase = instr.phrases[i]
     phrases[i] = string.format("%02d: %s", i, phrase.name)
   end
   
   vb.views.phrase_selector.items = phrases
   vb.views.phrase_selector.value = current_settings.current_phrase_index
 end
 
 -- Add function to duplicate current phrase
 function duplicate_current_phrase()
   local instr = renoise.song().selected_instrument
   if not instr then return end
   
   local current_phrase = instr.phrases[current_settings.current_phrase_index]
   if not current_phrase then return end
   
   -- Create new phrase
   local new_phrase = instr:insert_phrase_at(current_settings.current_phrase_index + 1)
   new_phrase.name = current_phrase.name .. " (copy)"
   new_phrase.lpb = current_phrase.lpb
   
   -- Copy script content
   if current_phrase.script then
     new_phrase.script.paragraphs = table.copy(current_phrase.script.paragraphs)
     new_phrase.script:commit()
   end
   
   -- Update UI
   update_phrase_selector()
   current_settings.current_phrase_index = current_settings.current_phrase_index + 1
   vb.views.phrase_selector.value = current_settings.current_phrase_index
   
   renoise.app():show_status(string.format("Duplicated phrase to position %02d", current_settings.current_phrase_index))
 end
 
 -- Add function to reverse current pattern
 function reverse_current_pattern()
   local instr = renoise.song().selected_instrument
   if not instr or #instr.phrases == 0 then return end
   
   local phrase = instr.phrases[current_settings.current_phrase_index]
   local script = phrase.script
   if not script then return end
   
   -- Find and reverse the pattern
   local new_paragraphs = {}
   local current_unit = ""
   local reversed_pattern = {}
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match('pattern%s*=%s*{([^}]+)}')
     local unit_str = line:match('unit%s*=%s*"([^"]+)"')
     
     if pattern_str then
       -- Extract and reverse the pattern
       for num in pattern_str:gmatch("[01]") do
         table.insert(reversed_pattern, 1, tonumber(num))  -- Insert at beginning to reverse
       end
       table.insert(new_paragraphs, string.format('  pattern = {%s},', table.concat(reversed_pattern, ",")))
     elseif unit_str then
       current_unit = unit_str
       table.insert(new_paragraphs, line)
     else
       table.insert(new_paragraphs, line)
     end
   end
   
   script.paragraphs = new_paragraphs
   script:commit()
   
   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   -- Show pattern status with visualization
   renoise.app():show_status(format_pattern_status(reversed_pattern, current_unit, "(Reversed)"))
   
   -- Render if auto-render is enabled
   if current_settings.always_render then
     render_to_pattern(script, current_settings, false)
   end
 end
 
 -- Add helper function for rendering
 function render_to_pattern(script, settings, show_status)
   -- Only show status if explicitly requested and not in always_render mode
   show_status = show_status and not settings.always_render
   
   local options = {
     lpb = settings.lpb,
     max_events = 512
   }
   
   script:render_to_pattern(options, function(error, rendered_events, skipped_events)
     if error then
       print("Render error: " .. error)
       renoise.app():show_status("Render error: " .. error)
       return
     end
     
     -- If auto-advance is enabled and render was successful, move to next phrase
     if settings.auto_advance then
       local instr = renoise.song().selected_instrument
       if instr and settings.current_phrase_index < #instr.phrases then
         settings.current_phrase_index = settings.current_phrase_index + 1
         if vb and vb.views.phrase_selector then
           vb.views.phrase_selector.value = settings.current_phrase_index
         end
         -- Update UI to show new phrase's settings
         read_current_script_values()
         update_ui_from_settings()
       end
     end
     
     -- Only show render status message if explicitly requested and not in always_render mode
     if show_status then
       local msg = string.format("Rendered %d events", rendered_events)
       if skipped_events > 0 then
         msg = msg .. string.format(" (skipped %d)", skipped_events)
       end
       renoise.app():show_status(msg)
     end
   end)
 end
 
 -- Add function to update UI from settings
 function update_ui_from_settings()
   if not vb then return end
   
   -- Update pattern length and note count
   if vb.views.pattern_length then
     vb.views.pattern_length.value = current_settings.pattern_length
   end
   
   if vb.views.note_count then
     vb.views.note_count.value = current_settings.note_count
   end
   
   -- Update scale and unit selectors
   if vb.views.scale_selector then
     local scale_idx = table.find(SCALE_NAMES, current_settings.scale)
     if scale_idx then
       vb.views.scale_selector.value = scale_idx
     end
   end
   
   if vb.views.unit_selector then
     local unit_idx = table.find(RHYTHM_UNITS, current_settings.unit)
     if unit_idx then
       vb.views.unit_selector.value = unit_idx
     end
   end
   
   -- Update volume range
   if vb.views.min_volume then
     vb.views.min_volume.value = current_settings.min_volume
   end
   
   if vb.views.max_volume then
     vb.views.max_volume.value = current_settings.max_volume
   end
   
   -- Update octave range
   if vb.views.min_octave then
     vb.views.min_octave.value = current_settings.min_octave
   end
   
   if vb.views.max_octave then
     vb.views.max_octave.value = current_settings.max_octave
   end
   
   -- Update auto render and advance checkboxes
   if vb.views.always_render then
     vb.views.always_render.value = current_settings.always_render
   end
   
   if vb.views.auto_advance then
     vb.views.auto_advance.value = current_settings.auto_advance
   end
   
   -- Update phrase selector
   update_phrase_selector()
   
   -- Update instrument name
   local instr = renoise.song().selected_instrument
   if instr and vb.views.instrument_name then
     vb.views.instrument_name.text = string.format("%02d: %s", 
       renoise.song().selected_instrument_index - 1,
       instr.name)
   end
   
   if vb.views.instrument_selector then
     vb.views.instrument_selector.value = renoise.song().selected_instrument_index - 1
   end
 end
 
 -- Add this near the top with other constants
 local STEPPER_TYPES = {
   {name = "Pitch Stepper", color = {0.9, 0.3, 0.3}},
   {name = "Volume Stepper", color = {0.3, 0.9, 0.3}},
   {name = "Pan Stepper", color = {0.3, 0.3, 0.9}},
   {name = "Cutoff Stepper", color = {0.9, 0.9, 0.3}},
   {name = "Resonance Stepper", color = {0.9, 0.3, 0.9}},
   {name = "Drive Stepper", color = {0.3, 0.9, 0.9}}
 }
 
 -- Add this function to show/hide steppers
 function toggle_stepper(stepper_name)
   local instr = renoise.song().selected_instrument
   if not instr or not instr.samples[1] then
     renoise.app():show_status("No valid Instrument/Sample selected")
     return
   end
   
   if not instr.sample_modulation_sets[1] then
     renoise.app():show_status("This Instrument has no modulation devices")
     return
   end
   
   -- Find the stepper device
   local devices = instr.sample_modulation_sets[1].devices
   local device = nil
   for _, dev in ipairs(devices) do
     if dev.name == stepper_name then
       device = dev
       break
     end
   end
   
   if not device then
     renoise.app():show_status(string.format("No %s device found", stepper_name))
     return
   end
   
   -- Toggle visibility
   device.external_editor_visible = not device.external_editor_visible
   renoise.app():show_status(string.format("%s visibility toggled", stepper_name))
 end
 
 -- Modify the dialog creation function to add stepper buttons
 function create_dialog()
   if dialog and dialog.visible then
     return
   end
   
   vb = renoise.ViewBuilder()
   
   local DEFAULT_MARGIN = renoise.ViewBuilder.DEFAULT_MARGIN
   local DEFAULT_SPACING = renoise.ViewBuilder.DEFAULT_SPACING
   local DIALOG_MARGIN = DEFAULT_MARGIN * 2
   
   local main_vb = vb:column {
     margin = DIALOG_MARGIN,
     spacing = DEFAULT_SPACING,
     
     -- Instrument selector row
     vb:horizontal_aligner {
       
       vb:text { 
         text = "Instrument",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:valuebox {
         id = "instrument_selector",
         min = 0,
         max = 255,
         value = renoise.song().selected_instrument_index - 1,
         width = 50,
         notifier = function(value)
           local new_index = value + 1
           local song = renoise.song()
           if new_index >= 1 and new_index <= #song.instruments then
             song.selected_instrument_index = new_index
             update_instrument_display()
           end
         end
       },
       vb:text {
         id = "instrument_name",
         text = renoise.song().instruments[renoise.song().selected_instrument_index].name,
         font = "bold"
       },
       vb:button {
         text = "Pakettify",
         tooltip = "Convert the current instrument to Paketti format",
         notifier = function()
           PakettiInjectDefaultXRNI()
           update_instrument_display()
         end
       }
     },
     
     -- Instrument transpose row
     vb:horizontal_aligner {
       vb:text { 
         text = "Transpose",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:text {
         id = "transpose_display",
         text = "0",
         width = 50,
         font = "bold",
         style = "strong"
       },
       vb:row {
         vb:button {
           text = "-36",
           width = 40,
           notifier = function()
             local instr = renoise.song().selected_instrument
             if instr then
               instr.transpose = -36
               vb.views.transpose_display.text = tostring(-36)
             end
           end
         },
         vb:button {
           text = "-24",
           width = 40,
           notifier = function()
             local instr = renoise.song().selected_instrument
             if instr then
               instr.transpose = -24
               vb.views.transpose_display.text = tostring(-24)
             end
           end
         },
         vb:button {
           text = "-12",
           width = 40,
           notifier = function()
             local instr = renoise.song().selected_instrument
             if instr then
               -- Subtract 12 from current transpose
               instr.transpose = instr.transpose - 12
               vb.views.transpose_display.text = tostring(instr.transpose)
             end
           end
         },
         vb:button {
           text = "0",
           width = 40,
           notifier = function()
             local instr = renoise.song().selected_instrument
             if instr then
               instr.transpose = 0
               vb.views.transpose_display.text = "0"
             end
           end
         },
         vb:button {
           text = "+12",
           width = 40,
           notifier = function()
             local instr = renoise.song().selected_instrument
             if instr then
               -- Add 12 to current transpose
               instr.transpose = instr.transpose + 12
               vb.views.transpose_display.text = tostring(instr.transpose)
             end
           end
         },
         vb:button {
           text = "+24",
           width = 40,
           notifier = function()
             local instr = renoise.song().selected_instrument
             if instr then
               instr.transpose = 24
               vb.views.transpose_display.text = tostring(24)
             end
           end
         },
         vb:button {
           text = "+36",
           width = 40,
           notifier = function()
             local instr = renoise.song().selected_instrument
             if instr then
               instr.transpose = 36
               vb.views.transpose_display.text = tostring(36)
             end
           end
         }
       }
     },
     
     -- Stepper buttons row
     vb:horizontal_aligner {
       
       vb:text {
         text = "Steppers:",
         width = 90,
         font = "bold",
         style = "strong"
       }
     },
     
     -- Add Always Render checkbox after stepper buttons
     vb:horizontal_aligner {
       
       vb:text { 
         text = "Always Render",
         width = 90,
         font = "bold",
         style = "strong",
         tooltip = "When enabled, any change will automatically render to pattern"
       },
       vb:checkbox {
         id = "always_render",
         value = current_settings.always_render,
         notifier = function(value)
           current_settings.always_render = value
         end,
         tooltip = "Enable to automatically render changes to pattern"
       }
     },
     
     -- Phrase selector and controls
     vb:horizontal_aligner {
       margin = DEFAULT_MARGIN,
       spacing = DEFAULT_SPACING,
       
       vb:text {
         text = "Phrase:",
         width = 90,
         font = "bold",
         style = "strong"
       },
       
       vb:popup {
         id = "phrase_selector",
         width = 150,
         items = (function()
           local instr = renoise.song().selected_instrument
           if not instr then return {"None"} end
           local phrases = {}
           for i = 1, #instr.phrases do
             phrases[i] = string.format("%02d: %s", i, instr.phrases[i].name)
           end
           return #phrases > 0 and phrases or {"None"}
         end)(),
         value = current_settings.current_phrase_index,
         tooltip = "Select the phrase to edit",
         notifier = function(idx)
           current_settings.current_phrase_index = idx
           update_phrase_display()
         end
       },
       
       vb:button {
         text = "Duplicate",
         tooltip = "Create a copy of the current phrase and start playing it",
         notifier = function()
           local instr = renoise.song().selected_instrument
           if not instr then return end
           
           local source_phrase = instr.phrases[current_settings.current_phrase_index]
           if not source_phrase then return end
           
           -- Create new phrase
           local new_idx = #instr.phrases + 1
           instr:insert_phrase_at(new_idx)
           local new_phrase = instr.phrases[new_idx]
           
           -- Copy content
           new_phrase.lpb = source_phrase.lpb
           new_phrase.script.paragraphs = table.copy(source_phrase.script.paragraphs)
           new_phrase.script:commit()
           
           -- Select new phrase
           current_settings.current_phrase_index = new_idx
           update_phrase_display()

           -- Select and play the new phrase
           instr.selected_phrase_index = new_idx
           instr.phrase_playback_mode = renoise.Instrument.PHRASES_OFF
           instr.phrase_playback_mode = renoise.Instrument.PHRASES_PLAY_SELECTIVE
           
           renoise.app():show_status(string.format("Duplicated phrase %d to %d", 
             current_settings.current_phrase_index - 1, new_idx))
         end
       },
       
       vb:button {
         text = "Reverse",
         tooltip = "Reverse the current pattern",
         notifier = function()
           local instr = renoise.song().selected_instrument
           if not instr or #instr.phrases == 0 then return end
           
           local phrase = instr.phrases[current_settings.current_phrase_index]
           local script = phrase.script
           if not script then return end
           
           -- Find and reverse the pattern
           local new_paragraphs = {}
           local current_unit = ""
           local reversed_pattern = {}
           
           for _, line in ipairs(script.paragraphs) do
             local pattern_str = line:match('pattern%s*=%s*{([^}]+)}')
             local unit_str = line:match('unit%s*=%s*"([^"]+)"')
             
             if pattern_str then
               -- Extract and reverse the pattern
               for num in pattern_str:gmatch("[01]") do
                 table.insert(reversed_pattern, 1, tonumber(num))  -- Insert at beginning to reverse
               end
               table.insert(new_paragraphs, string.format('  pattern = {%s},', table.concat(reversed_pattern, ",")))
             elseif unit_str then
               current_unit = unit_str
               table.insert(new_paragraphs, line)
             else
               table.insert(new_paragraphs, line)
             end
           end
           
           script.paragraphs = new_paragraphs
           script:commit()
           
           if script.compile_error ~= "" then
             local msg = "Compile error: " .. script.compile_error
             print(msg)
             renoise.app():show_status(msg)
             return
           end
           
           -- Show pattern status with visualization
           renoise.app():show_status(format_pattern_status(reversed_pattern, current_unit, "(Reversed)"))
           
           -- Render if auto-render is enabled
           if current_settings.always_render then
             render_to_pattern(script, current_settings, false)
           end
         end
       }
     },
     
     -- Auto render and advance options
     vb:horizontal_aligner {
       margin = DEFAULT_MARGIN,
       spacing = DEFAULT_SPACING,
       
       vb:checkbox {
         id = "auto_advance",
         value = current_settings.auto_advance,
         tooltip = "Automatically advance to next phrase after rendering",
         notifier = function(value)
           current_settings.auto_advance = value
         end
       },
       
       vb:text {
         text = "Auto Advance"
       }
     }
   }
   
   -- Add stepper buttons
   local stepper_row = main_vb:child(2) -- Get the stepper row
   for _, stepper in ipairs(STEPPER_TYPES) do
     stepper_row:add_child(
       vb:button {
         text = stepper.name:gsub(" Stepper", ""),
         color = stepper.color,
         width = 70,
         tooltip = string.format("Show/Hide %s editor", stepper.name),
         notifier = function()
           toggle_stepper(stepper.name)
         end
       }
     )
   end
   
   -- Add the rest of your existing UI elements from pakettiPhraseGeneratorDialog_content()
   main_vb:add_child(pakettiPhraseGeneratorDialog_content())
   
   dialog = renoise.app():show_custom_dialog(
     "Enhanced Phrase Generator",
     main_vb,
     my_keyhandler_func
   )
   
   -- Initialize observers and UI state
   setup_instrument_observer()
   update_phrase_selector()
   
   -- Initialize instrument name
   local instr = renoise.song().selected_instrument
   if instr and vb.views.instrument_name then
     vb.views.instrument_name.text = string.format("%02d: %s", 
       renoise.song().selected_instrument_index - 1,
       instr.name)
   end
 end
 
 -- Function to reverse the current pattern
 function reverse_pattern(settings)
   local instr = renoise.song().selected_instrument
   if not instr or #instr.phrases == 0 then return end
   
   local phrase = instr.phrases[settings.current_phrase_index]
   local script = phrase.script
   if not script then return end
   
   -- Find current pattern, unit and existing notes
   local current_pattern = {}
   local current_unit = ""
   local existing_notes = {}
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match('pattern%s*=%s*{([^}]+)}')
     local unit_str = line:match('unit%s*=%s*"([^"]+)"')
     local emit_str = line:match('emit%s*=%s*{(.+)}')
     
     if pattern_str then
       for num in pattern_str:gmatch("[01]") do
         table.insert(current_pattern, tonumber(num))
       end
     end
     if unit_str then current_unit = unit_str end
     if emit_str then
       for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
         table.insert(existing_notes, {key=key, volume=tonumber(vol)})
       end
     end
   end
   
   -- Reverse the pattern
   local reversed_pattern = {}
   for i = #current_pattern, 1, -1 do
     table.insert(reversed_pattern, current_pattern[i])
   end
   
   -- Convert emit table to strings with compact formatting
   local emit_strings = {}
   for _, note in ipairs(existing_notes) do
     table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', note.key, note.volume))
   end
   
   -- Rebuild script with reversed pattern
   script.paragraphs = {
     "return rhythm {",
     string.format('  unit = "%s",', current_unit),
     string.format("  pattern = {%s},", table.concat(reversed_pattern, ",")),
     string.format("  emit = {%s}", table.concat(emit_strings, ",")),
     "}"
   }
   
   script:commit()
   
   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   -- Show status with reversed pattern visualization
   renoise.app():show_status(format_pattern_status(reversed_pattern, current_unit, "(Reversed)"))
   
   -- Render if auto-render is enabled
   if settings.always_render then
     render_to_pattern(script, settings, false)
   end
 end
 
 function update_phrase_display()
   if not dialog or not dialog.visible then return end
   
   local instr = renoise.song().selected_instrument
   if not instr then 
     vb.views.phrase_selector.items = {"None"}
     vb.views.phrase_selector.value = 1
     return 
   end
   
   -- Update phrase selector items
   local phrases = {}
   for i = 1, #instr.phrases do
     local phrase = instr.phrases[i]
     phrases[i] = string.format("%02d: %s", i, phrase.name)
   end
   
   -- Update phrase selector
   if #phrases == 0 then
     vb.views.phrase_selector.items = {"None"}
     vb.views.phrase_selector.value = 1
     return
   end
   
   vb.views.phrase_selector.items = phrases
   vb.views.phrase_selector.value = current_settings.current_phrase_index
   
   -- Get current phrase
   local phrase = instr.phrases[current_settings.current_phrase_index]
   if not phrase then return end
   
   -- Update LPB switch quietly
   current_settings.lpb = phrase.lpb
   local lpb_values = {"1", "2", "3", "4", "6", "8", "12", "16"}
   local lpb_index = table.find(lpb_values, tostring(phrase.lpb)) or 4
   vb.views.lpb_switch.value = lpb_index
   
   -- Read and update other values from the phrase
   if read_current_script_values() then
     update_ui_from_settings()
   end
 end
 