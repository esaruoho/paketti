local TRANSPOSE_MIN=-120
local TRANSPOSE_MAX=120
local is_switching_instrument=false

-- Future-proof variables for phrase script syntax
local PHRASE_RETURN_TYPE = "pattern"
local PHRASE_PATTERN_FIELD = "pulse"
local PHRASE_EVENT_FIELD = "event"
local PHRASE_UNIT_FIELD = "unit"

local function set_transpose_safely(instrument, new_value)
  if not instrument then return end
  -- Clamp value between min and max
  new_value = math.max(TRANSPOSE_MIN, math.min(TRANSPOSE_MAX, new_value))
  instrument.transpose = new_value
  return new_value
end
  
 -- Constants for configuration
 local NOTE_RANGES = {
  full = {"c-4", "c#4", "d-4", "d#4", "e-4", "f-4", "f#4", "g-4", "g#4", "a-4", "a#4", "b-4", "c-5"},
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
   algerian = {"c-4", "db4", "e-4", "f-4", "gb4", "ab4", "b-4", "c-5"},
   blue1 = {"c-4", "d-4", "d#4", "f-4", "g-4", "a#4", "c-5"},
   blue2 = {"c-4", "d-4", "d#4", "f-4", "g-4", "g#4", "a#4", "c-5"}
 }
 
 local SCALE_NAMES = {
   "full", "minimal", "pentatonic", "chromatic", "blues",
   "major", "natural_minor", "harmonic_minor", "melodic_minor",
   "dorian", "phrygian", "lydian", "mixolydian", "locrian",
   "whole_tone", "diminished", "persian", "japanese", "gamelan",
   "hungarian", "romanian", "spanish", "enigmatic", "neapolitan",
   "prometheus", "algerian", "blue1", "blue2"
 }
 
 local SCALE_DISPLAY_NAMES = {
   full = "All Notes",
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
   algerian = "Algerian (C)",
   blue1 = "Blue1 (C D D# F G A# C)",
   blue2 = "Blue2 (C D D# F G G# A# C)"
 }
 
 local RHYTHM_UNITS = {"1/1", "1/2", "1/4", "1/8", "1/16", "1/32", "1/64"}

-- Status text constants for note ordering operations
local STATUS_TEXT = {
  random = "Random Order",
  ascending = "Ascending",
  descending = "Descending",
  same = "All C-4",
  dedupe = nil  -- This will be set dynamically based on had_duplicates
}

-- Stepper device types and their colors
local STEPPER_TYPES = {
  {name = "Pitch Stepper", color = {0.9, 0.3, 0.3}},
  {name = "Volume Stepper", color = {0.3, 0.9, 0.3}},
  {name = "Panning Stepper", color = {0.3, 0.3, 0.9}},
  {name = "Cutoff Stepper", color = {0.9, 0.9, 0.3}},
  {name = "Resonance Stepper", color = {0.9, 0.3, 0.9}},
  {name = "Drive Stepper", color = {0.3, 0.9, 0.9}}
}

-- Helper function to check if a device is a stepper
local function isStepperDevice(deviceName)
  for _, stepper in ipairs(STEPPER_TYPES) do
    if stepper.name == deviceName then
      return true
    end
  end
  return false
end

-- Function to set length for all steppers
function set_all_stepper_lengths(length)
  local song = renoise.song()
  local count = 0
  local stepperTypes = {"Pitch Stepper", "Volume Stepper", "Panning Stepper", 
                       "Cutoff Stepper", "Resonance Stepper", "Drive Stepper"}
  
  for inst_idx, instrument in ipairs(song.instruments) do
    if instrument.samples[1] and instrument.sample_modulation_sets[1] then
      local devices = instrument.sample_modulation_sets[1].devices
      for dev_idx, device in ipairs(devices) do
        for _, stepperType in ipairs(stepperTypes) do
          if device.name == stepperType then
            -- Set the length
            device.length = length
            count = count + 1
          end
        end
      end
    end
  end
  
  if count > 0 then
    renoise.app():show_status(string.format("Set length to %d for %d Stepper device(s)", length, count))
  else 
    renoise.app():show_status("No Stepper devices found")
  end
end

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
   transpose = 0,  -- Default transpose value
   play_until_end = false,  -- Setting for 0G01 effect
   shuffle = 0.0  -- Default shuffle value (0.0 = no shuffle)
 }
 
 local dialog = nil
 local vb = nil  -- ViewBuilder instance
 local current_settings = table.copy(DEFAULT_SETTINGS)
 
 -- Create scale display items array
 local scale_display_items = {}
 for _, scale_name in ipairs(SCALE_NAMES) do
   table.insert(scale_display_items, SCALE_DISPLAY_NAMES[scale_name])
 end
 
 -- Add at the top with other globals
 local instrument_observer = nil
 local phrase_observer = nil
 local observers = {}
 local current_visible_stepper = nil  -- Track which stepper type is currently visible
 _G.selectedStepper = nil  -- Make this a true module-level variable
 local visible_steppers = {}  -- Track which steppers are visible
 local stepper_settings = {}  -- Store stepper settings per instrument

 -- Add these at the top with other globals
 local last_instrument_settings = {}  -- Store settings per instrument
 local is_reading_settings = false    -- Flag to prevent recursive reads

 -- Add function to store settings for an instrument
 function store_instrument_settings(instrument_index)
   if not instrument_index then return end
   
   -- Deep copy current settings
   last_instrument_settings[instrument_index] = table.copy(current_settings)
   print(string.format("DEBUG: Stored settings for instrument %d", instrument_index))
 end

 -- Add function to restore settings for an instrument
 function restore_instrument_settings(instrument_index)
   if not instrument_index or not last_instrument_settings[instrument_index] then return end
   
   -- Deep copy stored settings
   for k, v in pairs(last_instrument_settings[instrument_index]) do
     current_settings[k] = v
   end
   print(string.format("DEBUG: Restored settings for instrument %d", instrument_index))
 end

 -- Function to store stepper settings for an instrument
 function store_stepper_settings(instrument_index)
   if not instrument_index then return end
   
   local song = renoise.song()
   local instr = song.instruments[instrument_index]
   if not instr or not instr.sample_modulation_sets[1] then return end
   
   -- Initialize settings for this instrument if not exists
   stepper_settings[instrument_index] = stepper_settings[instrument_index] or {}
   
   -- Store settings for each stepper
   local devices = instr.sample_modulation_sets[1].devices
   for _, device in ipairs(devices) do
     if isStepperDevice(device.name) then
       stepper_settings[instrument_index][device.name] = {
         length = device.length,
         visible = device.external_editor_visible
       }
       -- Track visibility state
       visible_steppers[device.name] = device.external_editor_visible
     end
   end
   print(string.format("DEBUG: Stored stepper settings for instrument %d", instrument_index))
 end

 -- Function to restore stepper settings for an instrument
 function restore_stepper_settings(instrument_index)
   if not instrument_index or not stepper_settings[instrument_index] then return end
   
   local song = renoise.song()
   local instr = song.instruments[instrument_index]
   if not instr or not instr.sample_modulation_sets[1] then return end
   
   local devices = instr.sample_modulation_sets[1].devices
   for _, device in ipairs(devices) do
     if isStepperDevice(device.name) and stepper_settings[instrument_index][device.name] then
       -- Restore length
       device.length = stepper_settings[instrument_index][device.name].length
       -- Restore visibility
       device.external_editor_visible = stepper_settings[instrument_index][device.name].visible
     end
   end
   print(string.format("DEBUG: Restored stepper settings for instrument %d", instrument_index))
 end

 -- Add this function to handle instrument switching and stepper visibility
 function update_stepper_visibility()
   local song = renoise.song()
   local instr = song.selected_instrument
   
   -- If no instrument or no modulation devices, return
   if not instr or not instr.sample_modulation_sets[1] then
     visible_steppers = {}  -- Clear tracking
     return
   end
   
   -- Get current instrument's devices
   local devices = instr.sample_modulation_sets[1].devices
   
   -- For each stepper type
   for _, stepper in ipairs(STEPPER_TYPES) do
     -- If this type was visible in previous instrument
     if visible_steppers[stepper.name] then
       -- Find this stepper type in new instrument
       for _, device in ipairs(devices) do
         if device.name == stepper.name then
           -- Make it visible
           device.external_editor_visible = true
           break
         end
       end
     end
   end
 end
 
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
 
 -- Store notifier functions
 local note_count_slider_notifier = nil
 local min_octave_box_notifier = nil
 local max_octave_box_notifier = nil

 function min_octave_box_notifier(value)
  if not value then return end
  -- Store old value for comparison
  local old_min = current_settings.min_octave
  current_settings.min_octave = value
  
  -- Ensure min doesn't exceed max
  if value > current_settings.max_octave then
    current_settings.max_octave = value
    vb.views.max_octave_box.value = value
  end
  
  -- Only update if value actually changed
  if old_min ~= value then
    local instr = renoise.song().selected_instrument
    if not instr or #instr.phrases == 0 then return end
    
    local phrase = instr.phrases[current_settings.current_phrase_index]
    if not phrase or not phrase.script then return end
    
    -- Extract current pattern and notes
    local current_pattern = {}
    local current_unit = ""
    local notes = {}
    
    for _, line in ipairs(phrase.script.paragraphs) do
      local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
      local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
      local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
      
      if pattern_str then
        for num in pattern_str:gmatch("[01]") do
          table.insert(current_pattern, tonumber(num))
        end
      end
      if unit_str then current_unit = unit_str end
      if emit_str then
        -- Extract notes and volumes
        for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
          -- Extract note name and current octave
          local note_name = key:match("([a-g][#%-]?)")
          local current_octave = tonumber(key:match("%d+"))
          if note_name and current_octave then
            -- Clean up note name
            note_name = note_name:gsub("%-$", "")
            -- Randomly assign new octave within range
            local new_octave = math.random(current_settings.min_octave, current_settings.max_octave)
            local new_key = note_name .. new_octave
            table.insert(notes, {key=new_key, volume=tonumber(vol)})
          end
        end
      end
    end
    
    -- Convert notes to emit strings
    local emit_strings = {}
    for _, note in ipairs(notes) do
      table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', note.key, note.volume))
    end
    
    -- Rebuild script with new notes
    phrase.script.paragraphs = {
      "return " .. PHRASE_RETURN_TYPE .. " {",
      string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', current_unit),
      string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(current_pattern, ",")),
      format_emit_line(emit_strings),
      "}",
      build_comment_line(current_settings)
    }
    phrase.script:commit()
    
    if phrase.script.compile_error ~= "" then
      local msg = "Compile error: " .. phrase.script.compile_error
      print(msg)
      renoise.app():show_status(msg)
      return
    end
    
    -- Show status with updated notes
    renoise.app():show_status(format_note_status(notes, current_unit))
    
    -- Render if auto-render is enabled
    if current_settings.always_render then
      render_to_pattern(phrase.script, current_settings, false)
    end
  end
end

function max_octave_box_notifier(value)
  if not value then return end
  -- Store old value for comparison
  local old_max = current_settings.max_octave
  current_settings.max_octave = value
  
  -- Ensure max doesn't go below min
  if value < current_settings.min_octave then
    current_settings.min_octave = value
    vb.views.min_octave_box.value = value
  end
  
  -- Only update if value actually changed
  if old_max ~= value then
    local instr = renoise.song().selected_instrument
    if not instr or #instr.phrases == 0 then return end
    
    local phrase = instr.phrases[current_settings.current_phrase_index]
    if not phrase or not phrase.script then return end
    
    -- Extract current pattern and notes
    local current_pattern = {}
    local current_unit = ""
    local notes = {}
    
    for _, line in ipairs(phrase.script.paragraphs) do
      local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
      local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
      local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
      
      if pattern_str then
        for num in pattern_str:gmatch("[01]") do
          table.insert(current_pattern, tonumber(num))
        end
      end
      if unit_str then current_unit = unit_str end
      if emit_str then
        -- Extract notes and volumes
        for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
          -- Extract note name and current octave
          local note_name = key:match("([a-g][#%-]?)")
          local current_octave = tonumber(key:match("%d+"))
          if note_name and current_octave then
            -- Clean up note name
            note_name = note_name:gsub("%-$", "")
            -- Randomly assign new octave within range
            local new_octave = math.random(current_settings.min_octave, current_settings.max_octave)
            local new_key = note_name .. new_octave
            table.insert(notes, {key=new_key, volume=tonumber(vol)})
          end
        end
      end
    end
    
    -- Convert notes to emit strings
    local emit_strings = {}
    for _, note in ipairs(notes) do
      table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', note.key, note.volume))
    end
    
    -- Rebuild script with new notes
    phrase.script.paragraphs = {
      "return " .. PHRASE_RETURN_TYPE .. " {",
      string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', current_unit),
      string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(current_pattern, ",")),
      format_emit_line(emit_strings),
      "}",
      build_comment_line(current_settings)
    }
    phrase.script:commit()
    
    if phrase.script.compile_error ~= "" then
      local msg = "Compile error: " .. phrase.script.compile_error
      print(msg)
      renoise.app():show_status(msg)
      return
    end
    
    -- Show status with updated notes
    renoise.app():show_status(format_note_status(notes, current_unit))
    
    -- Render if auto-render is enabled
    if current_settings.always_render then
      render_to_pattern(phrase.script, current_settings, false)
    end
  end
end


 -- Initialize notifier functions
 function init_notifiers()
  
end

function note_count_slider_notifier(value)
  if not value then return end
  value = math.floor(value)  -- Ensure integer value
  local old_count = current_settings.note_count
  current_settings.note_count = value
  if vb.views.note_count_text then
    vb.views.note_count_text.text = string.format("%02d notes", value)
  end
  update_note_count(current_settings, old_count)
end

function setup_instrument_observer()
  local song = renoise.song()
  if not song then return end

  if instrument_observer then
    song.selected_instrument_observable:remove_notifier(instrument_observer)
    instrument_observer = nil
  end

  instrument_observer = function()
    if not (dialog and dialog.visible) then return end

    is_switching_instrument = true
    print("DEBUG: Starting instrument switch")

    local previous_always_render = current_settings.always_render
    current_settings.always_render = false

    local song = renoise.song()

    -- Update instrument selector and name
    if vb.views.instrument_selector then
      vb.views.instrument_selector.value = song.selected_instrument_index - 1
    end
    if vb.views.instrument_name and song.selected_instrument then
      vb.views.instrument_name.text = song.selected_instrument.name ~= "" and song.selected_instrument.name or "<No Name>"
    end
    
    -- Update transpose display with current instrument's transpose value
    if vb.views.transpose_display and song.selected_instrument then
      local current_transpose = song.selected_instrument.transpose
      vb.views.transpose_display.text = tostring(current_transpose)
      current_settings.transpose = current_transpose
      print("DEBUG: Updated transpose display to:", current_transpose)
    end

    -- Remove notifiers to prevent feedback
    if vb.views.note_count_slider then
      vb.views.note_count_slider:remove_notifier(note_count_slider_notifier)
    end
    if vb.views.min_octave_box then
      vb.views.min_octave_box:remove_notifier(min_octave_box_notifier)
    end
    if vb.views.max_octave_box then
      vb.views.max_octave_box:remove_notifier(max_octave_box_notifier)
    end
    if vb.views.shuffle_slider then
      vb.views.shuffle_slider.notifier = nil
    end
    if vb.views.min_volume_slider then
      vb.views.min_volume_slider.notifier = nil
    end
    if vb.views.max_volume_slider then
      vb.views.max_volume_slider.notifier = nil
    end
    if vb.views.pattern_length_slider then
      vb.views.pattern_length_slider.notifier = nil
    end
    


    -- Load phrase settings and update UI safely
    is_reading_settings = true
    read_phrase_settings()
    update_ui_from_settings()
    is_reading_settings = false

    -- Restore notifiers
    if vb.views.note_count_slider then
      vb.views.note_count_slider.notifier = note_count_slider_notifier
    end
    if vb.views.min_octave_box then
      vb.views.min_octave_box.notifier = min_octave_box_notifier
    end
    if vb.views.max_octave_box then
      vb.views.max_octave_box.notifier = max_octave_box_notifier
    end
    if vb.views.shuffle_slider then
      vb.views.shuffle_slider.notifier = shuffle_slider_notifier
    end
    if vb.views.min_volume_slider then
      vb.views.min_volume_slider.notifier = min_volume_slider_notifier
    end
    if vb.views.max_volume_slider then
      vb.views.max_volume_slider.notifier = max_volume_slider_notifier
    end
    if vb.views.pattern_length_slider then
      vb.views.pattern_length_slider.notifier = pattern_length_slider_notifier
    end
    

    current_settings.always_render = previous_always_render
    is_switching_instrument = false
    print("DEBUG: Finished instrument switch")
  end

  song.selected_instrument_observable:add_notifier(instrument_observer)
end

 
 -- Store our observer function reference so we can remove it later
local instrument_observer = nil

function close_dialog()
   if dialog and dialog.visible then
     if renoise.song() and renoise.song().selected_instrument_observable and instrument_observer then
       renoise.song().selected_instrument_observable:remove_notifier(instrument_observer)
     end
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
   
   -- If we have an old pattern and it's a valid table, preserve its content
   if old_pattern and type(old_pattern) == "table" then
     -- Copy existing pattern values
     local old_length = #old_pattern
     for i = 1, math.min(old_length, length) do
       pattern[i] = old_pattern[i]
     end
     
     -- If increasing length, add new steps with musical probability
     if length > old_length then
       local last_val = pattern[old_length] or 1
       for i = old_length + 1, length do
         -- Create more musical patterns by favoring alternating patterns
         if last_val == 0 then
           last_val = (math.random() < 0.7) and 1 or 0
         else
           last_val = (math.random() < 0.4) and 0 or 1
         end
         pattern[i] = last_val
       end
     end
     -- If decreasing length, the last steps are automatically removed
   else
     -- Generate new pattern if no old pattern exists or if it's invalid
     local last_val = 1
     for i = 1, length do
       -- Create more musical patterns by favoring alternating patterns
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
   
   return format_emit_line(emit)
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
 function generate_valid_script_paragraphs(settings, preserve_existing, pattern_override)
  local notes = NOTE_RANGES[settings.scale]
  local emit = {}
  
  -- If we should preserve existing notes, get them first
  if preserve_existing then
    local instr = renoise.song().selected_instrument
    if instr and #instr.phrases > 0 then
      local phrase = instr.phrases[current_settings.current_phrase_index]
      local script = phrase.script
      if script then
        -- Parse existing emit section to preserve notes
        for _, line in ipairs(script.paragraphs) do
          local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
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

  -- Use provided pattern or generate a new one
  local pattern = pattern_override or generate_musical_pattern(settings.pattern_length)

  return {
    "return " .. PHRASE_RETURN_TYPE .. " {",
    string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', current_settings.unit),
    string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(pattern, ",")),
    format_emit_line(emit_strings),
    "}",
    build_comment_line(current_settings)
  }
end
 
 -- Functions to handle standardized phrase comments
 function build_comment_line(settings)
  -- Format: --scale --unit --octaves min-max --velocity min-max
  local comment_parts = {
    settings.scale or "major",
    string.format(PHRASE_UNIT_FIELD .. " %s", settings.unit or "1/16"),
    string.format("octRange %d %d", settings.min_octave or 3, settings.max_octave or 6),
    string.format("volRange %d %d", math.floor((settings.min_volume or 0.6) * 100), math.floor((settings.max_volume or 1.0) * 100))
  }
  
  -- Combine all parts with -- prefix
  return "--" .. table.concat(comment_parts, " --")
end

function parse_phrase_comment(comment)
  if not comment then return nil end
  
  local settings = table.copy(DEFAULT_SETTINGS)  -- Start with defaults
  
  -- Remove any leading/trailing whitespace
  comment = comment:match("^%s*(.-)%s*$")
  
  -- Split by -- and remove empty strings
  local parts = {}
  for part in comment:gmatch("%-%-([^%-]+)") do
    table.insert(parts, part:match("^%s*(.-)%s*$"))
  end
  
  for _, part in ipairs(parts) do
    -- Parse scale (first part without spaces)
    if not part:find("%s") and table.find(SCALE_NAMES, part) then
      settings.scale = part
    -- Parse unit
    elseif part:match("^" .. PHRASE_UNIT_FIELD .. "%s+") then
      local unit = part:match(PHRASE_UNIT_FIELD .. "%s+([^%s]+)")
      if table.find(RHYTHM_UNITS, unit) then
        settings.unit = unit
      end
    -- Parse octaves
    elseif part:match("^octRange%s+") then
      local min, max = part:match("octRange%s+(%d+)%s+(%d+)")
      if min and max then
        min = tonumber(min)
        max = tonumber(max)
        if min and max and min >= 0 and max <= 9 and min <= max then
          settings.min_octave = min
          settings.max_octave = max
        end
      end
    -- Parse velocity
    elseif part:match("^volRange%s+") then
      local min, max = part:match("volRange%s+(%d+)%s+(%d+)")
      if min and max then
        min = tonumber(min)
        max = tonumber(max)
        if min and max and min >= 0 and max <= 100 and min <= max then
          settings.min_volume = min / 100
          settings.max_volume = max / 100
        end
      end
    -- Parse shuffle
    elseif part:match("^shuffle%s+") then
      local value = part:match("shuffle%s+([%d%.]+)")
      if value then
        value = tonumber(value)
        if value and value >= 0 and value <= 1 then
          settings.shuffle = value
        end
      end
    -- Parse LPB
    elseif part:match("^LPB%s+") then
      local value = part:match("LPB%s+(%d+)")
      if value then
        value = tonumber(value)
        if value and value >= 1 and value <= 32 then
          settings.lpb = value
        end
      end
    end
  end
  
  return settings
end

 -- Function to read current values from the script
 function read_current_script_values()
   local instr = renoise.song().selected_instrument
   if not instr or #instr.phrases == 0 then return false end
   
   local phrase = instr.phrases[current_settings.current_phrase_index]
   if not phrase then return false end
   
   -- Get LPB from phrase
   current_settings.lpb = phrase.lpb
   print("Reading LPB from phrase:", current_settings.lpb)
   
   -- Get unit and other values from script
   local script = phrase.script
   if script then
     -- First look for unit value
     for _, line in ipairs(script.paragraphs) do
       local unit_match = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
       if unit_match then
         current_settings.unit = unit_match
         print("Reading unit from script:", current_settings.unit)
         -- Update unit switch if it exists
         if vb and vb.views.unit_switch then
           local unit_idx = table.find(RHYTHM_UNITS, current_settings.unit)
           if unit_idx then
             vb.views.unit_switch.value = unit_idx
             print("Updated unit switch to:", unit_idx, current_settings.unit)
           end
         end
         break -- Stop after finding unit
       end
     end
     
     -- Look for settings comment in the last line
     if #script.paragraphs > 0 then
       local last_line = script.paragraphs[#script.paragraphs]
       -- Check if it's a comment line
       if last_line:match("^%-%-") then
         -- Parse settings from comment
         local scale_match = last_line:match("%-%-%s*([^%s%-]+)")
         local vol_min, vol_max = last_line:match("volRange%s*(%d+)%s*(%d+)")
         local oct_min, oct_max = last_line:match("octRange%s*(%d+)%s*(%d+)")
         
         if scale_match then
           current_settings.scale = scale_match
           print("Reading scale from comment:", current_settings.scale)
           -- Update scale popup if it exists
           if vb and vb.views.scale_popup then
             local scale_idx = table.find(SCALE_NAMES, current_settings.scale)
             if scale_idx then
               vb.views.scale_popup.value = scale_idx
               print("Updated scale popup to:", scale_idx, current_settings.scale)
             end
           end
         end
         
         -- Update volume range if found
         if vol_min and vol_max then
           current_settings.min_volume = tonumber(vol_min) / 100
           current_settings.max_volume = tonumber(vol_max) / 100
           print(string.format("Reading volume range from comment: %d%% - %d%%", vol_min, vol_max))
           
           -- Update volume sliders if they exist
           if vb then
             if vb.views.min_volume_slider then
               vb.views.min_volume_slider.value = current_settings.min_volume
             end
             if vb.views.max_volume_slider then
               vb.views.max_volume_slider.value = current_settings.max_volume
             end
             -- Update volume text displays
             if vb.views.min_volume_text then
               vb.views.min_volume_text.text = string.format("%d%%", vol_min)
             end
             if vb.views.max_volume_text then
               vb.views.max_volume_text.text = string.format("%d%%", vol_max)
             end
           end
         end
         
         -- Update octave range if found
         if oct_min and oct_max then
           current_settings.min_octave = tonumber(oct_min)
           current_settings.max_octave = tonumber(oct_max)
           print(string.format("Reading octave range from comment: %d - %d", oct_min, oct_max))
           
           -- Update octave boxes if they exist
           if vb then
             if vb.views.min_octave_box then
               vb.views.min_octave_box.value = current_settings.min_octave
             end
             if vb.views.max_octave_box then
               vb.views.max_octave_box.value = current_settings.max_octave
             end
           end
         end
       end
     end
   end
   
   return true
 end

 -- Modify save_current_script_values to use the comment system
 function save_current_script_values()
   if not (dialog and dialog.visible) then return end
   
   local instr = renoise.song().selected_instrument
   if not instr then return end
   
   local phrase = instr.phrases[current_settings.current_phrase_index]
   if not phrase then return end
   
   -- Create standardized comment from current settings
   local comment = create_phrase_comment(current_settings)
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
     if line:match("^%s*" .. PHRASE_EVENT_FIELD .. "%s*=") then
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
 function format_pattern_status(pattern, unit, text)
  local boxes = {}
  local trigger_count = 0
  for _, v in ipairs(pattern) do
    if v == 1 then 
      trigger_count = trigger_count + 1
      table.insert(boxes, "■")
    else
      table.insert(boxes, "□")
    end
  end
  
  local status = string.format("Pattern (%s) (%02d): %s", 
    unit or current_settings.unit, #pattern, table.concat(boxes, ""))
  
  if text then
    status = status .. " " .. text
  end
  
  return status
end

  -- Helper function to ensure phrase exists
 function ensure_phrase_exists(instr)
   if not instr then return false end
   
   -- Create a phrase if none exists
   if #instr.phrases == 0 then
     print("DEBUG: Creating new phrase with LPB:", current_settings.lpb, "and unit:", current_settings.unit)
     instr:insert_phrase_at(1)
     current_settings.current_phrase_index = 1
     -- Select the newly created phrase using the correct API
     renoise.song().selected_phrase_index = 1
     
     -- Set name with extPhrase prefix
     local phrase = instr.phrases[1]
     phrase.name = string.format("extPhrase_%02d", 1)
     print("DEBUG: Set new phrase name to", phrase.name)
     -- Set initial LPB
     phrase.lpb = current_settings.lpb
     print("DEBUG: Set new phrase LPB to", current_settings.lpb)
     -- Create initial script with default values
     local script = phrase.script
     local pattern = generate_musical_pattern(current_settings.pattern_length)
     local emit_strings = {}
     script = rebuild_script(script, current_settings, pattern, emit_strings)
     script:commit()
     -- Update UI
     if dialog and dialog.visible then
       update_phrase_display()
     end
     
     -- Add phrase trigger to pattern if first line is empty
     local s = renoise.song()
     local currPatt = s.selected_pattern_index
     local currTrak = s.selected_track_index
     local line = s.patterns[currPatt].tracks[currTrak].lines[1]
     local note_col = line.note_columns[s.selected_note_column_index]
     
     if note_col.is_empty then
       note_col.note_string = "C-4"
       note_col.instrument_value = s.selected_instrument_index - 1  -- -1 because Renoise uses 0-based indexing for instrument_value
       -- Only add 0G01 if Play Until End is enabled
       if current_settings.play_until_end then
         line.effect_columns[1].number_string = "0G"
         line.effect_columns[1].amount_string = "01"
       end
     end
     
     return true
   else
     -- If we have phrases but none is selected, select the first one
     if renoise.song().selected_phrase_index == 0 or not renoise.song().selected_phrase then
       renoise.song().selected_phrase_index = 1
       current_settings.current_phrase_index = 1
     end
   end
   return true
 end
 
 -- Add this function for velocity randomization
 function randomize_velocity(settings)
   local instr = renoise.song().selected_instrument
   if not instr or #instr.phrases == 0 then return end
  
   -- Check if min and max velocities are the same
   if settings.min_volume == settings.max_volume then
     renoise.app():show_status(string.format("Velocity Range Min & Max are the same (%.0f%%), doing nothing", settings.min_volume * 100))
     return
   end
  
   local phrase = instr.phrases[current_settings.current_phrase_index]
   local script = phrase.script
   if not script then return end
  
   -- Find current pattern, unit and existing notes
   local current_pattern = {}
   local current_unit = ""
   local existing_notes = {}
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
     local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
     local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
     
     if pattern_str then
       for num in pattern_str:gmatch("[01]") do
         table.insert(current_pattern, tonumber(num))
       end
     end
     if unit_str then current_unit = unit_str end
     if emit_str then
       -- Extract existing notes with their keys and volumes
       for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
         table.insert(existing_notes, {key=key, volume=tonumber(vol)})
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
   
   -- Use rebuild_script helper to rebuild the script
   script = rebuild_script(script, settings, current_pattern, emit_strings)
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
         local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
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
     local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
     local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
     local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
    
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
  
   -- Rebuild script with comment
   script.paragraphs = {
     "return " .. PHRASE_RETURN_TYPE .. " {",
     string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', current_unit),
     string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(current_pattern, ",")),
     format_emit_line(existing_notes),
     "}",
     build_comment_line(current_settings)
   }
   script:commit()
  
   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
  
   -- Show status with updated notes
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
   if vb.views.instrument_name then
     vb.views.instrument_name.text = current_name ~= "" and current_name or "<No Name>"
   end
   
   -- Update transpose display with current instrument's transpose value
   if vb.views.transpose_display then
     local instr = song.instruments[current_index]
     current_settings.transpose = instr.transpose
     vb.views.transpose_display.text = tostring(current_settings.transpose or 0)
   end
   
   -- First read current values from the phrase
   -- This will update current_settings.lpb and current_settings.unit
   print("DEBUG: Reading current script values...")
   read_current_script_values()
   
   -- Update shuffle slider and text with current phrase's shuffle value
   if vb.views.shuffle_slider then
     vb.views.shuffle_slider.value = current_settings.shuffle or 0.0
   end
   if vb.views.shuffle_text then
     -- Round to nearest percent
     vb.views.shuffle_text.text = string.format("%d%%", math.floor((current_settings.shuffle or 0.0) * 100 + 0.5))
   end
   
   -- Now update all UI elements with current settings
   print(string.format("DEBUG: Updating UI - LPB: %d, Unit: %s", current_settings.lpb, current_settings.unit))
   
   -- Update LPB switch
   if vb.views.lpb_switch then
     local lpb_values = {"1", "2", "3", "4", "6", "8", "12", "16"}
     local lpb_index = table.find(lpb_values, tostring(current_settings.lpb)) or 4
     vb.views.lpb_switch.value = lpb_index
     print(string.format("DEBUG: Set LPB switch to index %d (value %s)", lpb_index, lpb_values[lpb_index]))
   end
   
   -- Update unit switch
   if vb.views.unit_switch then
     local unit_index = table.find(RHYTHM_UNITS, current_settings.unit) or 1
     vb.views.unit_switch.value = unit_index
     print(string.format("DEBUG: Set unit switch to index %d (value %s)", unit_index, RHYTHM_UNITS[unit_index]))
   end
   
   -- Update other UI elements
   vb.views.note_count_slider.value = current_settings.note_count
   vb.views.pattern_length_slider.value = current_settings.pattern_length
   vb.views.min_volume_slider.value = current_settings.min_volume
   vb.views.max_volume_slider.value = current_settings.max_volume
   vb.views.min_octave_box.value = current_settings.min_octave
   vb.views.max_octave_box.value = current_settings.max_octave
   
   -- Update text displays
   if vb.views.pattern_length_text then
     vb.views.pattern_length_text.text = string.format("%2d steps", current_settings.pattern_length)
   end
   if vb.views.note_count_text then
     vb.views.note_count_text.text = string.format("%02d notes", current_settings.note_count)
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
   
   -- Update phrase selector
   update_phrase_display()
 end
 
 function pakettiPhraseGeneratorDialog_content()
   -- Create text labels first with consistent style and width
   local pattern_length_text = vb:text { 
     text = string.format("%2d steps", current_settings.pattern_length),
     font = "bold",
     style = "strong"
   }
   local note_count_text = vb:text { 
     text = string.format("%02d notes", current_settings.note_count),
     font = "bold",
     style = "strong"
   }
   local min_volume_text = vb:text { 
     text = string.format("%d%%", math.floor(current_settings.min_volume * 100)),
     font = "bold",
     width=40,
     style = "strong"
   }
   local max_volume_text = vb:text { 
     text = string.format("%d%%", math.floor(current_settings.max_volume * 100)),
     font = "bold",
     width=40,
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
     vb:row {
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
         tostring = function(value) return string.format("%02X", value) end,
         tonumber = function(str) return tonumber(str, 16) end,
         notifier=function(value)
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
         text = renoise.song().instruments[renoise.song().selected_instrument_index].name ~= "" 
           and renoise.song().instruments[renoise.song().selected_instrument_index].name 
           or "<No Name>",
         font = "bold",
         style = "strong"
       },
       vb:button {
         text = "Unison",
         tooltip = "Generate unison samples for the current instrument",
         notifier=function()
           PakettiCreateUnisonSamples()
           update_instrument_display()
         end
       },
       vb:button {
         text = "Pakettify",
         tooltip = "Convert the current instrument to Paketti format",
         notifier=function()
           PakettiInjectDefaultXRNI()
           update_instrument_display()
         end
       }
     },

     -- Instrument transpose row
     vb:row {
       vb:text { 
         text = "Transpose",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:text {
         id = "transpose_display",
         text = tostring(renoise.song().selected_instrument.transpose),
         width = 30,
         font = "bold",
         style = "strong"
       },
       vb:row {
         vb:button {
           text = "-36",
           width = 40,
           notifier=function()
             local instr = renoise.song().selected_instrument
             if instr then
               local new_value = set_transpose_safely(instr, instr.transpose - 36)
               if vb.views.transpose_display then
                 vb.views.transpose_display.text = tostring(new_value)
               end
             end
           end
         },
         vb:button {
           text = "-24",
           width = 40,
           notifier=function() 
             local instr = renoise.song().selected_instrument
             if instr then
               local new_value = set_transpose_safely(instr, instr.transpose - 24)
               if vb.views.transpose_display then
                 vb.views.transpose_display.text = tostring(new_value)
               end
             end
         end
       },
       vb:button {
           text = "-12",
           width = 40,
           notifier=function()
             local instr = renoise.song().selected_instrument
             if instr then
               local new_value = set_transpose_safely(instr, instr.transpose - 12)
               if vb.views.transpose_display then
                 vb.views.transpose_display.text = tostring(new_value)
               end
             end
           end
         },
         vb:button {
           text = "0",
           width = 40,
           notifier=function()
             local instr = renoise.song().selected_instrument
             if instr then
               -- Always reset to 0
               local new_value = set_transpose_safely(instr, 0)
               if vb.views.transpose_display then
                 vb.views.transpose_display.text = tostring(new_value)
               end
             end
           end
         },
         vb:button {
           text = "+12",
           width = 40,
           notifier=function()
             local instr = renoise.song().selected_instrument
             if instr then
               local new_value = set_transpose_safely(instr, instr.transpose + 12)
               if vb.views.transpose_display then
                 vb.views.transpose_display.text = tostring(new_value)
               end
             end
           end
         },
         vb:button {
           text = "+24",
           width = 40,
           notifier=function()
             local instr = renoise.song().selected_instrument
             if instr then
               local new_value = set_transpose_safely(instr, instr.transpose + 24)
               if vb.views.transpose_display then
                 vb.views.transpose_display.text = tostring(new_value)
               end
             end
           end
         },
         vb:button {
           text = "+36",
           width = 40,
           notifier=function()
             local instr = renoise.song().selected_instrument
             if instr then
               local new_value = set_transpose_safely(instr, instr.transpose + 36)
               if vb.views.transpose_display then
                 vb.views.transpose_display.text = tostring(new_value)
               end
             end
           end
         }
       }
     },

     -- Phrase selector row
     vb:row {
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
         notifier=function(idx)
           current_settings.current_phrase_index = idx
           update_phrase_display()
         end
       },
       vb:button {
         text = "Duplicate",
         tooltip = "Create a copy of the current track and instrument and start playing it",
         notifier=function()
           -- Wrap in pcall to catch phrase limit errors
           local success, error_msg = pcall(function()
             duplicateTrackAndInstrument()
           end)
           
           if not success then
             -- Check if it's the phrase limit error
             if error_msg and error_msg:find("can only have up to 126 phrase per instrument") then
               renoise.app():show_status("Cannot duplicate: Instrument already has maximum number of phrases (126)")
             else
               -- Show other errors as-is
               renoise.app():show_status("Duplication failed: " .. tostring(error_msg))
             end
             return
           end
           
           -- After successful duplication, update the UI to reflect the new instrument
           local song = renoise.song()
           if vb.views.instrument_selector then
             vb.views.instrument_selector.value = song.selected_instrument_index - 1
           end
           
           -- Update all displays and settings
           update_instrument_display()
           
           -- Update phrase selector and display
           update_phrase_display()
         end
       },
       vb:button {
         text = "Reverse Triggers",
         tooltip = "Reverse the current trigger pattern",
         notifier=function()
           local instr = renoise.song().selected_instrument
           if not instr or #instr.phrases == 0 then return end
           
           local phrase = instr.phrases[current_settings.current_phrase_index]
           local script = phrase.script
           if not script then return end
           
           -- Find and reverse the pattern
           local new_paragraphs = {}
           local current_unit = ""
           local reversed_pattern = {}
           local current_emit = ""
           
           for _, line in ipairs(script.paragraphs) do
             local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
             local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
             local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
             
             if pattern_str then
               -- Extract and reverse the pattern
               for num in pattern_str:gmatch("[01]") do
                 table.insert(reversed_pattern, 1, tonumber(num))  -- Insert at beginning to reverse
               end
               table.insert(new_paragraphs, string.format('  ' .. PHRASE_PATTERN_FIELD .. ' = {%s},', table.concat(reversed_pattern, ",")))
             elseif unit_str then
               -- Keep track of the current unit
               current_unit = unit_str
               table.insert(new_paragraphs, line)
             elseif emit_str then
               -- Keep emit section unchanged
               current_emit = line
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
           
           -- Show pattern status with visualization and current unit
           renoise.app():show_status(format_pattern_status(reversed_pattern, current_unit, "(Reversed Triggers)"))
           
           -- Render if auto-render is enabled
           if current_settings.always_render then
             render_to_pattern(script, current_settings, false)
           end
         end
       },
       
     },

     -- Always Render checkbox
     vb:row {
       vb:text { 
         text = "Always Render",
         width = 90,
         font = "bold",
         style = "strong",
         tooltip = "When enabled, any change will automatically render to pattern"
       },
       vb:checkbox {
         value = current_settings.always_render,
         notifier=function(value)
           current_settings.always_render = value
         end,
         tooltip = "Enable to automatically render changes to pattern"
       }
     },

     -- Play Until End checkbox
     vb:row {
       vb:text { 
         text = "Play Until End",
         width = 90,
         font = "bold",
         style = "strong",
         tooltip = "When enabled, adds 0G01 effect to make phrase play until end"
       },
       vb:checkbox {
         value = current_settings.play_until_end,
         notifier=function(value)
           current_settings.play_until_end = value
           local s = renoise.song()
           local currPatt = s.selected_pattern_index
           local currTrak = s.selected_track_index
           local currLine = s.selected_line_index
           local line = s.patterns[currPatt].tracks[currTrak].lines[1]
           
           if value then
             -- Add 0G01 effect
             line.effect_columns[1].number_string = "0G"
             line.effect_columns[1].amount_string = "01"
           else
             -- Remove 0G01 effect
             line.effect_columns[1].number_string = "00"
             line.effect_columns[1].amount_string = "00"
           end
           
           -- Restore cursor position
           s.selected_line_index = currLine
         end,
         tooltip = "Enable to make phrase play until end"
       }
     },

     -- Randomize and render controls
     vb:row {
       vb:button {
         text = "Randomize All",
         tooltip = "Randomize all settings",
         notifier=function()
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
         notifier=function()
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
         notifier=function()
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
         notifier=function()
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
     vb:row {
       vb:text { 
         text = "Length",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:slider {
         id = "pattern_length_slider",
         min = 1,
         max = 32,
         width = 150,
         steps = {1, 4},  -- Small step: 1, Big step: 4
         value = current_settings.pattern_length,
         notifier=function(value) pattern_length_notifier(value) end
       },
       pattern_length_text
     },

     -- Pattern type buttons
     vb:row {
       vb:text { 
         text = "Pattern",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:button {
         text = "Full",
         width = 60,
         tooltip = "Set all steps to trigger (1,1,1,1) with 32 steps",
         notifier=function() handle_pattern_button("full") end
       },
       vb:button {
         text = "Every 2nd",
         width = 60,
         tooltip = "Set pattern to trigger every 2nd step (1,0,1,0) with 32 steps",
         notifier=function() handle_pattern_button("every2nd") end
       },
       vb:button {
         text = "Every 3rd",
         width = 60,
         tooltip = "Set pattern to trigger every 3rd step (1,0,0,1,0,0) with 24 steps",
         notifier=function() handle_pattern_button("every3rd") end
       },
       vb:button {
         text = "Every 4th",
         width = 60,
         tooltip = "Set pattern to trigger every 4th step (1,0,0,0,1,0,0,0) with 32 steps",
         notifier=function() handle_pattern_button("every4th") end
       },
       vb:button {
         text = "Every 5th",
         width = 60,
         tooltip = "Set pattern to trigger every 5th step (1,0,0,0,0) with 30 steps",
         notifier=function() handle_pattern_button("every5th") end
       },
       vb:button {
         text = "Every 6th",
         width = 60,
         tooltip = "Set pattern to trigger every 6th step (1,0,0,0,0,0) with 30 steps",
         notifier=function() handle_pattern_button("every6th") end
       }
     },

     -- Note count controls
     vb:row {
       vb:text { 
         text = "Note Count",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:slider {
         id = "note_count_slider",
         min = 0,
         max = 32,
         value = math.floor(current_settings.note_count),
         width = 250,
         steps = {1, 4},  -- Small step: 1, Big step: 4
         notifier=function(value) note_count_slider_notifier(value)
         end
       
       },
       note_count_text
     },

     -- Note ordering buttons
     vb:row {
       vb:text { 
         text = "Note Order",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:button {
        text = "Reverse",
        tooltip = "Reverse the order of notes in the phrase",
        notifier=function()
          local instr = renoise.song().selected_instrument
          if not instr or #instr.phrases == 0 then return end
          
          local phrase = instr.phrases[current_settings.current_phrase_index]
          local script = phrase.script
          if not script then return end
          
          -- Find current pattern and notes
          local current_pattern = {}
          local current_unit = ""
          local notes = {}
          
          for _, line in ipairs(script.paragraphs) do
            local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
            local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
            local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
            
            if pattern_str then
              -- Keep pattern unchanged
              for num in pattern_str:gmatch("[01]") do
                table.insert(current_pattern, tonumber(num))
              end
            end
            if unit_str then 
              current_unit = unit_str
            end
            if emit_str then
              -- Extract notes and volumes
              for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
                table.insert(notes, {key=key, volume=tonumber(vol)})
              end
            end
          end
          
          -- Reverse the notes array
          local reversed_notes = {}
          for i = #notes, 1, -1 do
            table.insert(reversed_notes, notes[i])
          end
          
          -- Convert reversed notes to emit string format
          local emit_strings = {}
          for _, note in ipairs(reversed_notes) do
            table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', note.key, note.volume))
          end
          
          -- Use rebuild_script helper with reversed notes
          script = rebuild_script(script, current_settings, current_pattern, emit_strings)
          script:commit()
          
          if script.compile_error ~= "" then
            local msg = "Compile error: " .. script.compile_error
            print(msg)
            renoise.app():show_status(msg)
            return
          end
          
          -- Show note status with reversed notes
          renoise.app():show_status(format_note_status(reversed_notes, current_unit, "(Reversed Notes)"))
          
          -- Render if auto-render is enabled
          if current_settings.always_render then
            render_to_pattern(script, current_settings, false)
          end
        end
      },



       vb:button {
         text = "Random",
         width = 60,
         tooltip = "Randomize note order",
         notifier=function() handle_note_order("random") end
       },
       vb:button {
         text = "Ascending",
         width = 60,
         tooltip = "Sort notes in ascending order",
         notifier=function() handle_note_order("ascending") end
       },
       vb:button {
         text = "Descending",
         width = 60,
         tooltip = "Sort notes in descending order",
         notifier=function() handle_note_order("descending") end
       },
       vb:button {
         text = "Same",
         width = 60,
         tooltip = "Set all notes to C-4",
         notifier=function() handle_note_order("same") end
       },
       vb:button {
         text = "Dedupe",
         width = 60,
         tooltip = "Remove duplicate notes",
         notifier=function() handle_note_order("dedupe") end
       }
     },

     -- Volume range controls
     vb:row {
       vb:text { 
         text = "Volume Range",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:slider {
         id = "min_volume_slider",
         min = 0,
         max = 1,
         value = current_settings.min_volume,
         width = 120,
         steps = {0.05, 0.1},  -- Small step: 5%, Big step: 10%
         notifier=function(value)
           if not value then return end
           current_settings.min_volume = value
           min_volume_text.text = string.format("%d%%", math.floor(value * 100))
           update_volume_only(current_settings)
         end
       },
       min_volume_text,
       vb:slider {
         id = "max_volume_slider",
         min = 0,
         max = 1,
         value = current_settings.max_volume,
         width = 120,
         steps = {0.05, 0.1},  -- Small step: 5%, Big step: 10%
         notifier=function(value)
           if not value then return end
           current_settings.max_volume = value
           max_volume_text.text = string.format("%d%%", math.floor(value * 100))
           update_volume_only(current_settings)
         end
       },
       max_volume_text
     },

     -- Octave range controls
     vb:row {
       vb:text { 
         text = "Octave Range",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:valuebox {
         id = "min_octave_box",
         min = 0,
         max = 9,
         value = current_settings.min_octave,
         width = 50,
         notifier=function(value) min_octave_box_notifier(value) end
       },
       vb:valuebox {
         id = "max_octave_box",
         min = 0,
         max = 9,
         value = current_settings.max_octave,
         width = 55,
         notifier=function(value) max_octave_box_notifier(value) end
       },
       vb:button {text = "-1",width = 30,notifier=function() shift_phrase_octaves(-1) end},
       vb:button {text = "+1",width=30,notifier=function() shift_phrase_octaves(1) end}},
     
     vb:row {
       vb:text { 
         text = "Scale",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:popup {
         id = "scale_popup",
         width = 150,
         items = scale_display_items,
         value = table.find(SCALE_NAMES, current_settings.scale),
         notifier=function(idx)
           local new_scale = SCALE_NAMES[idx]
           if new_scale then
             current_settings.scale = new_scale
             handle_scale_change(new_scale)
           end
         end
       }
     },
     vb:row {
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
         notifier=function(value)
           current_settings.unit = RHYTHM_UNITS[value]
           update_unit_only(current_settings)
           if current_settings.always_render then
             local instr = renoise.song().selected_instrument
             if instr and #instr.phrases > 0 then
               local phrase = instr.phrases[current_settings.current_phrase_index]
               if phrase and phrase.script then
                 render_to_pattern(phrase.script, current_settings, false)
               end end end end}},

     vb:row {
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
         notifier=function(value)
           local lpb_values = {"1", "2", "3", "4", "6", "8", "12", "16"}
           current_settings.lpb = tonumber(lpb_values[value])
           local instr = renoise.song().selected_instrument
           if instr and #instr.phrases > 0 then
             instr.phrases[current_settings.current_phrase_index].lpb = current_settings.lpb
           end
         end
       }
     },

     -- Add shuffle slider
     vb:row {
       vb:text { 
         text = "Shuffle",
         width = 90,
         font = "bold",
         style = "strong",
         tooltip = "Shuffle groove amount (0% = no shuffle, 100% = full shuffle)"
       },
       vb:slider {
         id = "shuffle_slider",
         min = 0,
         max = 1,
         value = current_settings.shuffle,
         width = 250,
         steps = {0.01, 0.1},  -- Small step: 1%, Big step: 10%
         notifier=function(value)
           if not value then return end
           current_settings.shuffle = value
           local instr = renoise.song().selected_instrument
           if instr and #instr.phrases > 0 then
             local phrase = instr.phrases[current_settings.current_phrase_index]
             phrase.shuffle = value
             
             -- Update script with new shuffle value in comment
             if phrase.script then
               -- Extract current pattern and notes
               local current_pattern = {}
               local current_unit = current_settings.unit
               local notes = {}
               
               for _, line in ipairs(phrase.script.paragraphs) do
                 local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
                 local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
                 local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
                 
                 if pattern_str then
                   for num in pattern_str:gmatch("[01]") do
                     table.insert(current_pattern, tonumber(num))
                   end
                 end
                 if unit_str then current_unit = unit_str end
                 if emit_str then
                   for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
                     table.insert(notes, {key=key, volume=tonumber(vol)})
                   end
                 end
               end
               
               phrase.script.paragraphs = {
                 "return " .. PHRASE_RETURN_TYPE .. " {",
                 string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', current_unit),
                 string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(current_pattern, ",")),
                 format_emit_line(notes),
                 "}",
                 build_comment_line(current_settings)
               }
               phrase.script:commit()
             end
           end
           
           if vb.views.shuffle_text then
             -- Round to nearest percent
             vb.views.shuffle_text.text = string.format("%d%%", math.floor(value * 100 + 0.5))
           end
         end
       },
       vb:text{id="shuffle_text",
         text=string.format("%d%%", math.floor((current_settings.shuffle or 0.0) * 100 + 0.5)),
         font="bold",style="strong"}},

     -- Stepper buttons row
     vb:row {
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
               notifier=function()
                 toggle_stepper(stepper.name)
               end
             }
           end
           return unpack(buttons)
         end)()
       }
     },

     -- Add stepper length controls
     vb:row {
       vb:text {
         text = "Step Length",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:button {
         text = "2",
         width = 50,
         notifier=function()
           set_all_stepper_lengths(2)
         end
       },
       vb:button {
         text = "4",
         width = 50,
         notifier=function()
           set_all_stepper_lengths(4)
         end
       },
       vb:button {
         text = "8",
         width = 50,
         notifier=function()
           set_all_stepper_lengths(8)
         end
       },
       vb:button {
         text = "16",
         width = 50,
         notifier=function()
           set_all_stepper_lengths(16)
         end
       },
       vb:button {
         text = "32",
         width = 50,
         notifier=function()
           set_all_stepper_lengths(32)
         end
       },
       vb:button {
         text = "64",
         width = 50,
         notifier=function()
           set_all_stepper_lengths(64)
         end
       },
       vb:button {
         text = "128",
         width = 50,
         notifier=function()
           set_all_stepper_lengths(128)
         end
       },
       vb:button {
         text = "256",
         width = 50,
         notifier=function()
           set_all_stepper_lengths(256)
         end
       }
     },

     -- Add playback control with stepper reset
     vb:row {
       vb:text {
         text = "Playback",
         width = 90,
         font = "bold",
         style = "strong"
       },
       vb:button {
         text = "Play (Reset Steppers)",
         width = 200,
         notifier=function()
           -- First reset all steppers
           ResetAllSteppers()
           -- Then start playback
           renoise.song().transport:start(renoise.Transport.PLAYMODE_RESTART_PATTERN)
         end
       }
     },

     -- Add this at the end of pakettiPhraseGeneratorDialog_content(), just before the final closing brace
-- Global scale controls
vb:row {
  vb:text { 
    text = "Global Scale",
    width = 90,
    font = "bold",
    style = "strong",
    tooltip = "Change scale for all extPhrases in all instruments"
  },
  vb:popup {
    id = "global_scale_popup",
    items = SCALE_NAMES,
    value = table.find(SCALE_NAMES, current_settings.scale) or 1,
    width = 250,
    notifier=function(value)
      local new_scale = SCALE_NAMES[value]
      apply_global_scale(new_scale)
    end
  }
}

   }
 end
 
 -- Add this helper function for note mapping
 function get_closest_scale_note(note_str, scale_notes)
   -- Note value mapping for comparison
   local note_values = {
     ["c"] = 0, ["c#"] = 1, ["d"] = 2, ["d#"] = 3,
     ["e"] = 4, ["f"] = 5, ["f#"] = 6, ["g"] = 7,
     ["g#"] = 8, ["a"] = 9, ["a#"] = 10, ["b"] = 11
   }
   
   -- Parse the input note
   local note_name = note_str:match("([a-g][#%-]?)")
   local octave = tonumber(note_str:match("%d+"))
   if not note_name or not octave then return note_str end
   
   -- Clean up note name
   note_name = note_name:gsub("%-$", ""):lower()
   
   local note_value = note_values[note_name]
   if not note_value then return note_str end
   
   -- Parse scale notes to get their values
   local scale_values = {}
   for _, scale_note in ipairs(scale_notes) do
     local scale_name = scale_note:match("([a-g][#%-]?)")
     if scale_name then
       scale_name = scale_name:gsub("%-$", ""):lower()
       local value = note_values[scale_name]
       if value then
         table.insert(scale_values, value)
       end
     end
   end
   
   -- Find closest note in scale
   local min_distance = 12
   local closest_value = note_value
   for _, scale_value in ipairs(scale_values) do
     local distance = math.abs(note_value - scale_value)
     if distance < min_distance then
       min_distance = distance
       closest_value = scale_value
     end
   end
   
   -- Find the corresponding note name from the scale
   for note, value in pairs(note_values) do
     if value == closest_value then
       -- Return the note in the same format as input
       return note .. octave
     end
   end
   
   return note_str -- fallback
 end

function live_code(settings)
  local instr = renoise.song().selected_instrument
  if not instr then
    local msg = "No instrument selected."
    print(msg)
    renoise.app():show_status(msg)
    return
  end
  
  -- Ensure we have a phrase
  if not ensure_phrase_exists(instr) then return end
  
  local phrase = instr.phrases[current_settings.current_phrase_index]
  local script = phrase.script
  if not script then return end
  
  -- Find current pattern and notes
  local current_pattern = {}
  local existing_notes = {}
  
  for _, line in ipairs(script.paragraphs) do
    local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
    local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
    local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
    
    if pattern_str then
      for num in pattern_str:gmatch("[01]") do
        table.insert(current_pattern, tonumber(num))
      end
    end
    if unit_str then current_settings.unit = unit_str end
    if emit_str then
      -- Extract existing notes with their volumes
      for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
        table.insert(existing_notes, {key=key, volume=tonumber(vol)})
      end
    end
  end

  -- Map existing notes to new scale
  local notes = NOTE_RANGES[settings.scale]
  local mapped_notes = {}
  for _, note in ipairs(existing_notes) do
    local new_key = get_closest_scale_note(note.key, notes)
    table.insert(mapped_notes, {key=new_key, volume=note.volume})
  end

  -- Convert mapped notes to emit strings
  local emit_strings = {}
  for _, note in ipairs(mapped_notes) do
    table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', note.key, note.volume))
  end

  -- Use rebuild_script helper instead of manual script rebuilding
  script = rebuild_script(script, current_settings, current_pattern, emit_strings)

  script:commit()

  if script.compile_error ~= "" then
    local msg = "Compile error: " .. script.compile_error
    print(msg)
    renoise.app():show_status(msg)
    return
  end
  
  -- Show status with both scale change and mapped notes
  local note_status = format_note_status(mapped_notes)
  renoise.app():show_status(note_status)
  
  -- Add auto-render if enabled
  if settings.always_render then
    render_to_pattern(script, settings, false)
  end
end
 
 function pakettiPhraseGeneratorDialog()
  -- Read current phrase settings before creating dialog
  read_phrase_settings()
  
  -- If dialog exists and is visible, close it and return
  if dialog and dialog.visible then
    close_dialog()
    return
  end
  
  -- Create ViewBuilder
  vb = renoise.ViewBuilder()
  
  -- Create dialog content
  local dialog_content = pakettiPhraseGeneratorDialog_content(vb)
  
  -- Create dialog
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog(
    "Paketti Phrase Generator",
    dialog_content,
    keyhandler
  )
  
  -- Only set up observers if we have a valid song and dialog
  if renoise.song() and dialog and dialog.visible then
    setup_observers()
  end
end
 
 if renoise.API_VERSION >= 6.2 then 
 renoise.tool():add_menu_entry{name="Main Menu:Tools:Enhanced Phrase Generator",invoke=function() pakettiPhraseGeneratorDialog() end}
 renoise.tool():add_keybinding{name="Global:Tools:Enhanced Phrase Generator",invoke=function() pakettiPhraseGeneratorDialog() end}
 renoise.tool():add_menu_entry{name="Phrase Script Editor:Paketti:Enhanced Phrase Generator",invoke=function() pakettiPhraseGeneratorDialog() end}
 end
 
 -- Helper function to update only volume values
 function update_volume_only(settings)
   local instr = renoise.song().selected_instrument
   if not instr then return end
   
   -- Ensure we have a phrase
   if not ensure_phrase_exists(instr) then return end
   
   local phrase = instr.phrases[current_settings.current_phrase_index]
   local script = phrase.script
   if not script then return end
   
   -- Find and preserve current pattern and emit structure
   local current_pattern = {}
   local existing_notes = {}
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
     local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
     local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
     
     if pattern_str then
       for num in pattern_str:gmatch("[01]") do
         table.insert(current_pattern, tonumber(num))
       end
     end
     if unit_str then current_settings.unit = unit_str end
     if emit_str then
       for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
         table.insert(existing_notes, {key=key, volume=tonumber(vol)})
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
   
   -- Use rebuild_script helper instead of manual script rebuilding
   script = rebuild_script(script, current_settings, current_pattern, emit_strings)
   script:commit()
   
   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   -- Show status with updated velocities
   renoise.app():show_status(format_note_status(updated_notes))

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
   local current_scale = settings.scale
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
     local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
     
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
   
   -- Update current_settings.unit from the settings parameter
   current_settings.unit = settings.unit
   
   -- Convert emit table to strings with compact formatting
   local emit_strings = {}
   for _, note in ipairs(existing_notes) do
     table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', note.key, note.volume))
   end
   
   -- Use rebuild_script helper instead of manual script rebuilding
   script = rebuild_script(script, current_settings, current_pattern, emit_strings)
   script:commit()
   
   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   -- Show both pattern and note content with new step size
   local pattern_status = format_pattern_status(current_pattern)
   local note_status = format_note_status(existing_notes)
   renoise.app():show_status(note_status)

   -- Add auto-render if enabled
   if settings.always_render then
     render_to_pattern(script, settings, false)
   end
 end
 
 -- Helper function to format emit entries consistently with no extra spaces
 function format_emit_entry(key, volume)
   return string.format('{key="%s",volume=%.2f}', key, volume)
 end
 
 -- Helper function to format emit string consistently with no extra spaces
 function format_emit_string(emit_entries)
   return table.concat(emit_entries, ",")
 end
 
 -- Helper function to update octave range
 function update_octave_range(settings)
   local instr = renoise.song().selected_instrument
   if not instr then return end
   
   -- Ensure we have a phrase
   if not ensure_phrase_exists(instr) then return end
   
   local phrase = instr.phrases[current_settings.current_phrase_index]
   local script = phrase.script
   if not script then return end
   
   -- Find current pattern and existing notes
   local current_pattern = {}
   local existing_notes = {}
   
   -- Look for existing settings in the last line comment
   local existing_comment = nil
   if #script.paragraphs > 0 then
     local last_line = script.paragraphs[#script.paragraphs]
     if last_line:match("^%-%-") then
       existing_comment = last_line
       -- Extract scale from comment if it exists
       local scale_str = last_line:match("%-%-%s*([^%s%-]+)")
       if scale_str then current_scale = scale_str end
     end
   end
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
     local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
     local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
     
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
      
   -- Use rebuild_script helper instead of manual script rebuilding
   script = rebuild_script(script, current_settings, current_pattern, emit_strings)
   script:commit()
   
   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   -- Show status with updated notes
   renoise.app():show_status(format_note_status(existing_notes, current_unit))

   -- Add auto-render if enabled
   if settings.always_render then
     render_to_pattern(script, settings, false)
   end
 end
 
 -- Helper function to update note count
 function update_note_count(settings, old_count)
   local instr = renoise.song().selected_instrument
   if not instr then return end
   
   -- Ensure we have a phrase
   if not ensure_phrase_exists(instr) then return end
   
   local phrase = instr.phrases[current_settings.current_phrase_index]
   -- Ensure phrase has extPhrase prefix
   update_phrase_name(phrase, current_settings.current_phrase_index)
   
   local script = phrase.script
   if not script then return end
   
   -- Find current pattern and existing notes
   local current_pattern = {}
   local existing_notes = {}
   local current_unit = current_settings.unit
   
   for _, line in ipairs(script.paragraphs) do
     local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
     local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
     local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
     
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
   
   -- Rebuild script with preserved pattern and compact emit formatting
   local new_paragraphs = {
     "return " .. PHRASE_RETURN_TYPE .. " {",
     string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', current_unit),
     string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(current_pattern, ",")),
     format_emit_line(emit),
     "}",
     build_comment_line(current_settings)
   }
   
   script.paragraphs = new_paragraphs
   script:commit()

   if script.compile_error ~= "" then
     local msg = "Compile error: " .. script.compile_error
     print(msg)
     renoise.app():show_status(msg)
     return
   end
   
   -- Show status without direction indicators
   renoise.app():show_status(format_note_status(emit, current_unit))

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
   
 -- Add function to update UI from settings
 function update_ui_from_settings()
   if not vb then return end
   
   -- Use the switching flag to prevent renders
   local was_always_render = current_settings.always_render
   if is_switching_instrument then
     current_settings.always_render = false
   end
   
   -- Update pattern length and note count
   if vb.views.pattern_length_slider then
     vb.views.pattern_length_slider.value = current_settings.pattern_length
   end
   if vb.views.pattern_length_text then
     vb.views.pattern_length_text.text = string.format("%2d steps", current_settings.pattern_length)
   end
   
   if vb.views.note_count_slider then
     vb.views.note_count_slider.value = current_settings.note_count
   end
   if vb.views.note_count_text then
     vb.views.note_count_text.text = string.format("%02d notes", current_settings.note_count)
   end
   
   -- Update shuffle slider and text with consistent percentage calculation
   if vb.views.shuffle_slider then
     vb.views.shuffle_slider.value = current_settings.shuffle or 0.0
   end
   if vb.views.shuffle_text then
     vb.views.shuffle_text.text = string.format("%d%%", math.floor((current_settings.shuffle or 0.0) * 100))
   end
   
   -- Update octave boxes
   if vb.views.min_octave_box then
     vb.views.min_octave_box.value = current_settings.min_octave
   end
   if vb.views.max_octave_box then
     vb.views.max_octave_box.value = current_settings.max_octave
   end
   
   -- Update scale popup
   if vb.views.scale_popup then
     local scale_idx = table.find(SCALE_NAMES, current_settings.scale)
     if scale_idx then
       vb.views.scale_popup.value = scale_idx
     end
   end
   
   -- Update unit switch
   if vb.views.unit_switch then
     local unit_idx = table.find(RHYTHM_UNITS, current_settings.unit)
     if unit_idx then
       vb.views.unit_switch.value = unit_idx
     end
   end
   
   -- Update LPB switch - directly use the LPB value
   if vb.views.lpb_switch then
     local lpb_values = {1, 2, 3, 4, 6, 8, 12, 16}
     local lpb_index = table.find(lpb_values, current_settings.lpb) or 4 -- Default to 4 if not found
     vb.views.lpb_switch.value = lpb_index
     print("DEBUG: Setting LPB switch to index", lpb_index, "for LPB value", current_settings.lpb)
   end
   
   -- Restore always_render state
   current_settings.always_render = was_always_render
 end
 
 -- Add this near the top with other constants
 local STEPPER_TYPES = {
   {name = "Pitch Stepper", color = {0.9, 0.3, 0.3}},
   {name = "Volume Stepper", color = {0.3, 0.9, 0.3}},
   {name = "Panning Stepper", color = {0.3, 0.3, 0.9}},
   {name = "Cutoff Stepper", color = {0.9, 0.9, 0.3}},
   {name = "Resonance Stepper", color = {0.9, 0.3, 0.9}},
   {name = "Drive Stepper", color = {0.3, 0.9, 0.9}}
 }
 
 -- Add this function to show/hide steppers
 function toggle_stepper(deviceName)
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
     if dev.name == deviceName then
       device = dev
       break
     end
   end
   
   if not device then
     renoise.app():show_status(string.format("No %s device found", deviceName))
     return
   end
   
   -- Only proceed if this is actually a stepper device
   if not isStepperDevice(deviceName) then
     renoise.app():show_status("Not a valid stepper device")
     return
   end
   
   -- If we're opening this stepper, close any other visible steppers first
   local was_visible = device.external_editor_visible
   if not was_visible then
     -- Close any other visible steppers
     for _, dev in ipairs(devices) do
       -- Compare device names instead of device objects
       if isStepperDevice(dev.name) and dev.external_editor_visible and dev.name ~= deviceName then
         print("Closing previously visible stepper:", dev.name)
         dev.external_editor_visible = false
         visible_steppers[dev.name] = false
       end
     end
   end
   
   -- Toggle visibility
   device.external_editor_visible = not was_visible
   visible_steppers[deviceName] = device.external_editor_visible
   
   -- Store settings immediately
   store_stepper_settings(renoise.song().selected_instrument_index)
   
   -- Update global state based on new visibility
   if device.external_editor_visible then
     -- When making visible, set selectedStepper so we can find it in other instruments
     _G.selectedStepper = deviceName
     current_visible_stepper = deviceName
   else
     -- When hiding, clear both states
     _G.selectedStepper = nil
     current_visible_stepper = nil
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
     local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
     local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
     local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
     
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
     "return " .. PHRASE_RETURN_TYPE .. " {",
     string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', current_unit),
     string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(reversed_pattern, ",")),
     format_emit_line(notes),
     "}",
     build_comment_line(current_settings)
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
   if not vb or not vb.views.phrase_selector then return end
   
   local instr = renoise.song().selected_instrument
   if not instr then return end
   
   local phrases = {}
   for i = 1, #instr.phrases do
     phrases[i] = string.format("%02d: %s", i, instr.phrases[i].name)
   end
   
   vb.views.phrase_selector.items = #phrases > 0 and phrases or {"None"}
   vb.views.phrase_selector.value = current_settings.current_phrase_index
 end

-- Add this function near other helper functions
function apply_global_scale(new_scale)
  local song = renoise.song()
  local changes_made = 0
  
  -- Update current_settings.scale to match global scale
  current_settings.scale = new_scale
  
  -- Update UI scale popup if it exists
  if dialog and dialog.visible and vb.views.scale_popup then
    local scale_index = table.find(SCALE_NAMES, new_scale)
    if scale_index then
      vb.views.scale_popup.value = scale_index
    end
  end
  
  -- Iterate through all instruments
  for instr_idx, instr in ipairs(song.instruments) do
    -- Check each phrase in the instrument
    for phrase_idx, phrase in ipairs(instr.phrases) do
      -- Only process phrases that start with "extPhrase"
      if phrase.name:match("^extPhrase") then
        local script = phrase.script
        if script then
          -- Find current pattern and notes
          local current_pattern = {}
          local existing_notes = {}
          
          for _, line in ipairs(script.paragraphs) do
            local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
            local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
            local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
            
            if pattern_str then
              for num in pattern_str:gmatch("[01]") do
                table.insert(current_pattern, tonumber(num))
              end
            end
            if unit_str then current_settings.unit = unit_str end
            if emit_str then
              -- Extract existing notes with their volumes
              for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
                -- Extract note name and octave
                local note_name = key:match("([a-g][#%-]?)")
                local octave = key:match("%d+$")
                if note_name and octave then
                  table.insert(existing_notes, {
                    note_name = note_name:gsub("%-$", ""), -- Clean up note name
                    octave = octave,
                    volume = tonumber(vol)
                  })
                end
              end
            end
          end
          
          -- Generate new notes in the new scale while preserving octaves and volumes
          local notes = NOTE_RANGES[new_scale]
          local emit_strings = {}
          local note_objects = {}  -- Keep track of note objects for status display
          
          for _, note in ipairs(existing_notes) do
            -- Find closest note in new scale
            local closest_note = get_closest_scale_note(note.note_name .. note.octave, notes)
            table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', closest_note, note.volume))
            table.insert(note_objects, {key=closest_note, volume=note.volume})
          end
          
          -- Rebuild script with comment
          script = rebuild_script(script, current_settings, current_pattern, emit_strings)
          script:commit()
          changes_made = changes_made + 1
          
          -- Auto-render if enabled
          if current_settings.always_render and 
             instr_idx == song.selected_instrument_index and
             phrase_idx == current_settings.current_phrase_index then
            render_to_pattern(script, current_settings, false)
          end
        end -- end of if script
      end -- end of if phrase.name:match
    end -- end of for phrase_idx
  end -- end of for instr_idx
  
  -- Show status message
  if changes_made > 0 then
    renoise.app():show_status(string.format("Applied %s scale to %d extPhrase(s)", 
      SCALE_DISPLAY_NAMES[new_scale], changes_made))
  else
    renoise.app():show_status("No extPhrases found to update")
  end
end

-- Add these pattern generation functions
function generate_full_pattern(length)
  local pattern = {}
  for i = 1, length do
    pattern[i] = 1
  end
  return pattern
end

function generate_every_n_pattern(length, n)
  local pattern = {}
  for i = 1, length do
    pattern[i] = (i - 1) % n == 0 and 1 or 0
  end
  return pattern
end

-- Add these helper functions at the end of the file

-- Helper function to compare notes for sorting
function compare_notes(a, b, order)
  -- Extract note and octave information
  local function parse_note(note_str)
    local note_name = note_str:match("([a-g][#%-]?)")
    local octave = tonumber(note_str:match("%d+"))
    return note_name, octave
  end
  
  -- Note value mapping for comparison
  local note_values = {
    ["c"] = 0, ["c#"] = 1, ["d"] = 2, ["d#"] = 3,
    ["e"] = 4, ["f"] = 5, ["f#"] = 6, ["g"] = 7,
    ["g#"] = 8, ["a"] = 9, ["a#"] = 10, ["b"] = 11
  }
  
  local a_note, a_oct = parse_note(a.key:lower())
  local b_note, b_oct = parse_note(b.key:lower())
  
  -- Clean up note names (remove trailing -)
  a_note = a_note:gsub("%-$", "")
  b_note = b_note:gsub("%-$", "")
  
  -- Calculate total semitones for comparison
  local a_value = (a_oct * 12) + note_values[a_note]
  local b_value = (b_oct * 12) + note_values[b_note]
  
  if order == "ascending" then
    return a_value < b_value
  else
    return a_value > b_value
  end
end

-- Function to reorder notes
function reorder_notes(order_type)
  local instr = renoise.song().selected_instrument
  if not instr or #instr.phrases == 0 then return end
  
  local phrase = instr.phrases[current_settings.current_phrase_index]
  local script = phrase.script
  if not script then return end
  
  -- Find current pattern, unit and notes
  local current_pattern = {}
  local current_unit = current_settings.unit
  local notes = {}
  local had_duplicates = false  -- Moved declaration here
  
  for _, line in ipairs(phrase.script.paragraphs) do
    local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
    local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
    local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
    
    if pattern_str then
      for num in pattern_str:gmatch("[01]") do
        table.insert(current_pattern, tonumber(num))
      end
    end
    if unit_str then current_unit = unit_str end
    if emit_str then
      for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
        table.insert(notes, {key=key,volume=tonumber(vol)})
      end
    end
  end
  
  if #notes == 0 then return end
  
  -- Handle different ordering types
  if order_type == "random" then
    -- Fisher-Yates shuffle
    for i = #notes, 2, -1 do
      local j = math.random(i)
      notes[i], notes[j] = notes[j], notes[i]
    end
  elseif order_type == "ascending" or order_type == "descending" then
    table.sort(notes, function(a, b)
      -- Extract note and octave for comparison
      local a_note, a_oct = a.key:match("([a-g][#%-]?)([0-9])")
      local b_note, b_oct = b.key:match("([a-g][#%-]?)([0-9])")
      
      -- Clean up note names (remove trailing -)
      a_note = a_note:gsub("%-$", "")
      b_note = b_note:gsub("%-$", "")
      
      -- Note order mapping
      local note_values = {
        ["c"] = 0, ["c#"] = 1, ["d"] = 2, ["d#"] = 3,
        ["e"] = 4, ["f"] = 5, ["f#"] = 6, ["g"] = 7,
        ["g#"] = 8, ["a"] = 9, ["a#"] = 10, ["b"] = 11
      }
      
      -- Calculate total semitones for comparison
      local a_value = (tonumber(a_oct) * 12) + note_values[a_note]
      local b_value = (tonumber(b_oct) * 12) + note_values[b_note]
      
      if order_type == "ascending" then
        return a_value < b_value
      else
        return a_value > b_value
      end
    end)
  elseif order_type == "same" then
    -- Set all notes to C4 while preserving velocities
    for i = 1, #notes do
      notes[i].key = "c4"
    end
  elseif order_type == "dedupe" then
    -- Remove duplicates while preserving order
    local seen = {}
    local unique_notes = {}
    
    for _, note in ipairs(notes) do
      if not seen[note.key] then
        seen[note.key] = true
        table.insert(unique_notes, note)
      else
        had_duplicates = true
      end
    end
    
    if had_duplicates then
      notes = unique_notes
      -- Update note count setting
      current_settings.note_count = #unique_notes
      if vb.views.note_count_slider then
        vb.views.note_count_slider.value = current_settings.note_count
      end
      if vb.views.note_count_text then
        vb.views.note_count_text.text = string.format("%02d notes", current_settings.note_count)
      end
    end
  end
  
  -- Update script with new note order but preserve pattern
  local new_paragraphs = {
    "return " .. PHRASE_RETURN_TYPE .. " {",
    string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', current_unit),
    string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(current_pattern, ",")),
    format_emit_line(notes),
    "}",
    build_comment_line(current_settings)
  }
  
  phrase.script.paragraphs = new_paragraphs
  phrase.script:commit()
  

  STATUS_TEXT.dedupe = had_duplicates and "Deduped" or "Nothing to dedupe"
  
  renoise.app():show_status(format_note_status(notes, current_unit, "(" .. STATUS_TEXT[order_type] .. ")"))
  
  -- Render if auto-render is enabled
  if current_settings.always_render then
    render_to_pattern(phrase.script, current_settings, false)
  end
end

-- Add at the top with other globals
local is_switching_instrument = false

-- Modify render_to_pattern to respect the switching flag
function render_to_pattern(script, settings, show_status)
  -- Don't render if we're in the middle of switching instruments
  if is_switching_instrument then
    print("DEBUG: Skipping render due to instrument switch in progress")
    return
  end
  
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

-- Function to set up observers
function setup_observers()
  if not (renoise.song() and dialog and dialog.visible) then return end
  
  -- Create the observer function
  instrument_observer = function()
    if not (dialog and dialog.visible) then return end
    
    -- Set flag to indicate we're switching instruments
    is_switching_instrument = true
    print("DEBUG: Starting instrument switch")
    
    -- Store current always_render state and temporarily disable it
    local previous_always_render = current_settings.always_render
    current_settings.always_render = false
    
    -- Store settings for the previous instrument
    store_stepper_settings(renoise.song().selected_instrument_index)
    
    -- Update instrument selector and name
    if vb.views.instrument_selector then
      vb.views.instrument_selector.value = renoise.song().selected_instrument_index - 1
    end
    
    -- Update all displays and settings
    local instr = renoise.song().selected_instrument
    if instr and vb.views.instrument_name then
      vb.views.instrument_name.text = instr.name ~= "" and instr.name or "<No Name>"
    end
    
    -- Restore settings for the new instrument
    restore_stepper_settings(renoise.song().selected_instrument_index)
    
    -- Read and update values from the phrase without triggering renders
    if read_current_script_values() then
      update_ui_from_settings()
    end
    
    -- Restore the always_render setting
    current_settings.always_render = previous_always_render
    
    -- Clear the flag after everything is read and updated
    is_switching_instrument = false
    print("DEBUG: Finished instrument switch")
  end
  
  -- Add the observer
  add_observer(renoise.song().selected_instrument_observable, instrument_observer)
end

-- Function to clean up observers
local function cleanup_observers()
  if renoise.song() and renoise.song().selected_instrument_observable then
    renoise.song().selected_instrument_observable:remove_all_notifiers()
  end
end

-- Function to check if current track has 0G01 command
function has_0G01_in_track()
  local s = renoise.song()
  local pattern = s.patterns[s.selected_pattern_index]
  local track = pattern:track(s.selected_track_index)
  
  -- Check first line for 0G01
  local line = track:line(1)
  if line.effect_columns[1].number_string == "0G" and 
     line.effect_columns[1].amount_string == "01" then
    return true
  end
  
  return false
end

-- Helper function to get existing comment from script
function get_existing_comment(script)
  if not script or #script.paragraphs == 0 then return nil end
  
  -- Look for comment in the last line
  local last_line = script.paragraphs[#script.paragraphs]
  if last_line:match("^%-%-") then
    return last_line
  end
  return nil
end

-- Helper function to rebuild script with comment
function rebuild_script(script, settings, pattern, emit_strings)
  script.paragraphs = {
    "return " .. PHRASE_RETURN_TYPE .. " {",
    string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', settings.unit),
    string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(pattern, ",")),
    format_emit_line(emit_strings),
    "}",
    build_comment_line(settings)
  }
  return script
end

-- Function to handle pattern button clicks
function handle_pattern_button(pattern_type)
  local instr = renoise.song().selected_instrument
  if not instr or #instr.phrases == 0 then return end
  
  local phrase = instr.phrases[current_settings.current_phrase_index]
  local script = phrase.script
  if not script then return end
  
  -- First set the length based on pattern type
  local length
  if pattern_type == "full" then
    length = 32
  elseif pattern_type == "every2nd" then
    length = 32
  elseif pattern_type == "every3rd" then
    length = 24
  elseif pattern_type == "every4th" then
    length = 32
  elseif pattern_type == "every5th" then
    length = 30
  elseif pattern_type == "every6th" then
    length = 30
  end
  
  -- Update current settings pattern length
  current_settings.pattern_length = length
  
  -- Update pattern length text if it exists
  if vb.views.pattern_length_text then
    vb.views.pattern_length_text.text = string.format("%2d steps", length)
  end
  
  -- Update pattern length slider if it exists
  if vb.views.pattern_length_slider then
    vb.views.pattern_length_slider.value = length
  end
  
  -- Now generate the pattern based on type
  local new_pattern = {}
  
  if pattern_type == "full" then
    -- Fill with all 1's: 1,1,1,1,1,1,1,1,1,1... (32 steps)
    for i = 1, 32 do
      new_pattern[i] = 1
    end
  elseif pattern_type == "every2nd" then
    -- Fill with 1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0... (32 steps)
    for i = 1, 32 do
      new_pattern[i] = (i % 2 == 1) and 1 or 0
    end
  elseif pattern_type == "every3rd" then
    -- Fill with 1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0 (24 steps)
    for i = 1, 24 do
      new_pattern[i] = (i % 3 == 1) and 1 or 0
    end
  elseif pattern_type == "every4th" then
    -- Fill with 1,0,0,0,1,0,0,0,1,0,0,0... (32 steps)
    for i = 1, 32 do
      new_pattern[i] = (i % 4 == 1) and 1 or 0
    end
  elseif pattern_type == "every5th" then
    -- Fill with 1,0,0,0,0,1,0,0,0,0... (30 steps)
    for i = 1, 30 do
      new_pattern[i] = (i % 5 == 1) and 1 or 0
    end
  elseif pattern_type == "every6th" then
    -- Fill with 1,0,0,0,0,0,1,0,0,0,0,0... (32 steps)
    for i = 1, 32 do
      new_pattern[i] = (i % 6 == 1) and 1 or 0
    end
  end
  
  -- Extract existing notes and unit from current script
  local existing_notes = {}
  local current_unit = current_settings.unit
  
  for _, line in ipairs(script.paragraphs) do
    local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
    local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
    
    if unit_str then
      current_unit = unit_str
    end
    
    if emit_str then
      for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
        table.insert(existing_notes, {key = key, volume = tonumber(vol)})
      end
    end
  end
  
  -- Generate new script with updated pattern
  local new_paragraphs = {
    "return " .. PHRASE_RETURN_TYPE .. " {",
    string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', current_unit),
    string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(new_pattern, ",")),
    format_emit_line(existing_notes),
    "}",
    build_comment_line(current_settings)
  }
  
  -- Update script
  phrase.script.paragraphs = new_paragraphs
  phrase.script:commit()
  
  -- Update pattern visualization if it exists
  if vb and vb.views.pattern_display then
    local pattern_str = ""
    for i, val in ipairs(new_pattern) do
      pattern_str = pattern_str .. (val == 1 and "■" or "□")
      if i < #new_pattern then
        pattern_str = pattern_str .. " "
      end
    end
    vb.views.pattern_display.text = pattern_str
  end
  
  -- Show status message in the same format as length slider
  local trigger_boxes = ""
  for i = 1, #new_pattern do
    trigger_boxes = trigger_boxes .. (new_pattern[i] == 1 and "■" or "□")
  end
  renoise.app():show_status(string.format("Pattern (%s) (%02d): %s", current_unit, #new_pattern, trigger_boxes))
  
  -- Render if auto-render is enabled
  if current_settings.always_render then
    render_to_pattern(phrase.script, current_settings, false)
  end
end

-- Function to handle scale changes
function handle_scale_change(new_scale)
  local instr = renoise.song().selected_instrument
  if not instr or #instr.phrases == 0 then return end
  
  local phrase = instr.phrases[current_settings.current_phrase_index]
  local script = phrase.script
  if not script then return end
  
  -- Find current pattern and notes
  local current_pattern = {}
  local existing_notes = {}
  
  for _, line in ipairs(script.paragraphs) do
    local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
    local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
    local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
    
    if pattern_str then
      for num in pattern_str:gmatch("[01]") do
        table.insert(current_pattern, tonumber(num))
      end
    end
    if unit_str then current_settings.unit = unit_str end
    if emit_str then
      -- Extract existing notes with their volumes
      for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
        -- Extract note name and octave
        local note_name = key:match("([a-g][#%-]?)")
        local octave = key:match("%d+$")
        if note_name and octave then
          table.insert(existing_notes, {
            note_name = note_name:gsub("%-$", ""), -- Clean up note name
            octave = octave,
            volume = tonumber(vol)
          })
        end
      end
    end
  end
  
  -- Generate new notes in the new scale while preserving octaves and volumes
  local notes = NOTE_RANGES[new_scale]
  local emit_strings = {}
  local note_objects = {}  -- Keep track of note objects for status display
  
  for _, note in ipairs(existing_notes) do
    -- Find closest note in new scale
    local closest_note = get_closest_scale_note(note.note_name .. note.octave, notes)
    table.insert(emit_strings, string.format('{key="%s",volume=%.2f}', closest_note, note.volume))
    table.insert(note_objects, {key=closest_note, volume=note.volume})
  end
  
  -- Rebuild script with comment
  script = rebuild_script(script, current_settings, current_pattern, emit_strings)
  script:commit()
  
  if script.compile_error ~= "" then
    local msg = "Compile error: " .. script.compile_error
    print(msg)
    renoise.app():show_status(msg)
    return
  end
  
  -- Show status with scale name
  renoise.app():show_status(format_note_status(note_objects, current_settings.unit, string.format("[%s]", SCALE_DISPLAY_NAMES[new_scale])))

  -- Add auto-render if enabled
  if current_settings.always_render then
    render_to_pattern(script, current_settings, false)
  end
end

-- Function to handle note ordering operations
function handle_note_order(order_type)
  local instr = renoise.song().selected_instrument
  if not instr or #instr.phrases == 0 then return end
  
  local phrase = instr.phrases[current_settings.current_phrase_index]
  if not phrase or not phrase.script then return end
  
  -- Extract current pattern, unit, and notes
  local current_pattern = {}
  local current_unit = current_settings.unit
  local notes = {}
  local had_duplicates = false  -- Moved declaration here
  
  for _, line in ipairs(phrase.script.paragraphs) do
    local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
    local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
    local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
    
    if pattern_str then
      for num in pattern_str:gmatch("[01]") do
        table.insert(current_pattern, tonumber(num))
      end
    end
    if unit_str then current_unit = unit_str end
    if emit_str then
      for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
        table.insert(notes, {key=key,volume=tonumber(vol)})
      end
    end
  end
  
  if #notes == 0 then return end
  
  -- Handle different ordering types
  if order_type == "random" then
    -- Fisher-Yates shuffle
    for i = #notes, 2, -1 do
      local j = math.random(i)
      notes[i], notes[j] = notes[j], notes[i]
    end
  elseif order_type == "ascending" or order_type == "descending" then
    table.sort(notes, function(a, b)
      -- Extract note and octave for comparison
      local a_note, a_oct = a.key:match("([a-g][#%-]?)([0-9])")
      local b_note, b_oct = b.key:match("([a-g][#%-]?)([0-9])")
      
      -- Clean up note names (remove trailing -)
      a_note = a_note:gsub("%-$", "")
      b_note = b_note:gsub("%-$", "")
      
      -- Note order mapping
      local note_values = {
        ["c"] = 0, ["c#"] = 1, ["d"] = 2, ["d#"] = 3,
        ["e"] = 4, ["f"] = 5, ["f#"] = 6, ["g"] = 7,
        ["g#"] = 8, ["a"] = 9, ["a#"] = 10, ["b"] = 11
      }
      
      -- Calculate total semitones for comparison
      local a_value = (tonumber(a_oct) * 12) + note_values[a_note]
      local b_value = (tonumber(b_oct) * 12) + note_values[b_note]
      
      if order_type == "ascending" then
        return a_value < b_value
      else
        return a_value > b_value
      end
    end)
  elseif order_type == "same" then
    -- Set all notes to C-4 while preserving velocities
    for i = 1, #notes do
      notes[i].key = "c4"
    end
  elseif order_type == "dedupe" then
    -- Remove duplicates while preserving order
    local seen = {}
    local unique_notes = {}
    
    for _, note in ipairs(notes) do
      if not seen[note.key] then
        seen[note.key] = true
        table.insert(unique_notes, note)
      else
        had_duplicates = true
      end
    end
    
    if had_duplicates then
      notes = unique_notes
      -- Update note count setting
      current_settings.note_count = #unique_notes
      if vb.views.note_count_slider then
        vb.views.note_count_slider.value = current_settings.note_count
      end
      if vb.views.note_count_text then
        vb.views.note_count_text.text = string.format("%02d notes", current_settings.note_count)
      end
    end
  end
  
  -- Update script with new note order but preserve pattern
  local new_paragraphs = {
    "return " .. PHRASE_RETURN_TYPE .. " {",
    string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', current_unit),
    string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(current_pattern, ",")),
    format_emit_line(notes),
    "}",
    build_comment_line(current_settings)
  }
  
  phrase.script.paragraphs = new_paragraphs
  phrase.script:commit()
  
  STATUS_TEXT.dedupe = had_duplicates and "Deduped" or "Nothing to dedupe"
  renoise.app():show_status(format_note_status(notes, current_unit, "(" .. STATUS_TEXT[order_type] .. ")"))

  -- Render if auto-render is enabled
  if current_settings.always_render then
    render_to_pattern(phrase.script, current_settings, false)
  end
end

-- Helper function to update phrase name - now only maintains the extPhrase prefix
function update_phrase_name(phrase, index) 
  if not phrase.name:match("^extPhrase") then
    phrase.name = string.format("extPhrase_%02d", index)
    return true
  end
  return false
end

-- Function to read pattern length from script
function read_pattern_length_from_script(script)
  if not script then return nil end
  
  for _, line in ipairs(script.paragraphs) do
    local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
    if pattern_str then
      local count = 0
      for num in pattern_str:gmatch("[01]") do
        count = count + 1
      end
      return count
    end
  end
  return nil
end

-- Helper function to parse note from emit string
function parse_note(note_str)
  local key = note_str:match('key%s*=%s*"([^"]+)"')
  local volume = note_str:match('volume%s*=%s*([%d%.]+)')
  return {key = key, volume = tonumber(volume)}
end

-- Modify the pattern length slider notifier
function pattern_length_notifier(value)
  if not value then return end
  
  -- Ensure integer value
  value = math.floor(tonumber(value) or 1)
  if value < 1 then value = 1 end
  if value > 32 then value = 32 end
  
  -- Store old length and update current settings
  local old_length = current_settings.pattern_length
  current_settings.pattern_length = value
  
  -- Update text display
  if vb.views.pattern_length_text then
    vb.views.pattern_length_text.text = string.format("%02d steps", value)
  end
  
  -- Update pattern length using the robust implementation
  update_pattern_length(current_settings, old_length)
end

-- Helper function to create pattern with specific interval
function create_interval_pattern(length, interval)
  local pattern = {}
  for i = 1, length do
    pattern[i] = (i % interval == 1) and 1 or 0
  end
  return pattern
end

-- Function to update pattern with specific interval
function update_pattern_interval(interval)
  local instr = renoise.song().selected_instrument
  if not instr or #instr.phrases == 0 then return end
  
  local phrase = instr.phrases[current_settings.current_phrase_index]
  if not phrase then return end
  
  -- Generate new pattern with interval
  local new_pattern = create_interval_pattern(current_settings.pattern_length, interval)
  
  -- Update script with new pattern
  local new_paragraphs = generate_valid_script_paragraphs({
    pattern_length = current_settings.pattern_length,
    note_count = current_settings.note_count,
    scale = current_settings.scale,
    min_volume = current_settings.min_volume,
    max_volume = current_settings.max_volume,
    min_octave = current_settings.min_octave,
    max_octave = current_settings.max_octave,
    unit = current_settings.unit,
    lpb = current_settings.lpb,
    shuffle = current_settings.shuffle
  }, true, new_pattern)  -- Pass the new pattern as third argument
  
  -- Update phrase name if needed
  local base_name = phrase.name:match("^extPhrase_%d+") or "extPhrase_01"
  phrase.name = base_name
  
  -- Update script
  phrase.script.paragraphs = new_paragraphs
  
  -- Update pattern visualization
  if vb and vb.views.pattern_display then
    local pattern_str = ""
    for i, val in ipairs(new_pattern) do
      pattern_str = pattern_str .. (val == 1 and "■" or "□")
      if i < #new_pattern then
        pattern_str = pattern_str .. " "
      end
    end
    vb.views.pattern_display.text = pattern_str
  end
  
  -- Render if Always Render is enabled
  if current_settings.always_render then
    render_to_pattern(phrase.script, current_settings, false)
  end
end

-- Pattern button handlers
function handle_full_pattern()
  -- Set pattern length to 32 and fill with 1's
  current_settings.pattern_length = 32
  local new_pattern = {}
  for i = 1, 32 do
    new_pattern[i] = 1
  end
  update_pattern_with_values(new_pattern)
end

function handle_every_second()
  -- Set pattern length to 32 with alternating triggers
  current_settings.pattern_length = 32
  local new_pattern = {}
  for i = 1, 32 do
    new_pattern[i] = (i % 2 == 1) and 1 or 0
  end
  update_pattern_with_values(new_pattern)
end

function handle_every_third()
  -- Set pattern length to 24 with every third trigger
  current_settings.pattern_length = 24
  local new_pattern = {}
  for i = 1, 24 do
    new_pattern[i] = (i % 3 == 1) and 1 or 0
  end
  update_pattern_with_values(new_pattern)
end

function handle_every_fourth()
  -- Set pattern length to 32 with every fourth trigger
  current_settings.pattern_length = 32
  local new_pattern = {}
  for i = 1, 32 do
    new_pattern[i] = (i % 4 == 1) and 1 or 0
  end
  update_pattern_with_values(new_pattern)
end

function handle_every_fifth()
  -- Set pattern length to 30 with every fifth trigger
  current_settings.pattern_length = 30
  local new_pattern = {}
  for i = 1, 30 do
    new_pattern[i] = (i % 5 == 1) and 1 or 0
  end
  update_pattern_with_values(new_pattern)
end

function handle_every_sixth()
  -- Set pattern length to 30 with every sixth trigger
  current_settings.pattern_length = 32
  local new_pattern = {}
  for i = 1, 32 do
    new_pattern[i] = (i % 6 == 1) and 1 or 0
  end
  update_pattern_with_values(new_pattern)
end

-- Helper function to update pattern with specific values
function update_pattern_with_values(pattern)
  local instr = renoise.song().selected_instrument
  if not instr or #instr.phrases == 0 then return end
  
  local phrase = instr.phrases[current_settings.current_phrase_index]
  if not phrase then return end
  
  -- Update script with new pattern
  local new_paragraphs = generate_valid_script_paragraphs({
    pattern_length = current_settings.pattern_length,
    note_count = current_settings.note_count,
    scale = current_settings.scale,
    min_volume = current_settings.min_volume,
    max_volume = current_settings.max_volume,
    min_octave = current_settings.min_octave,
    max_octave = current_settings.max_octave,
    unit = current_settings.unit,
    lpb = current_settings.lpb,
    shuffle = current_settings.shuffle
  }, true, pattern)  -- Pass the new pattern as third argument
  
  -- Update phrase name if needed
  local base_name = phrase.name:match("^extPhrase_%d+") or "extPhrase_01"
  phrase.name = base_name
  
  -- Update script
  phrase.script.paragraphs = new_paragraphs
  
  -- Update pattern visualization
  if vb and vb.views.pattern_display then
    local pattern_str = ""
    for i, val in ipairs(pattern) do
      pattern_str = pattern_str .. (val == 1 and "■" or "□")
    end
    vb.views.pattern_display.text = pattern_str
  end
  
  -- Render if Always Render is enabled
  if current_settings.always_render then
    render_to_pattern(phrase.script, current_settings, false)
  end
end

-- Helper function to format note status messages
function format_note_status(notes, unit, text)
  if not notes or #notes == 0 then
    return "No notes to display"
  end
  
  local note_str = {}
  for _, note in ipairs(notes) do
    if type(note) == "string" then
      table.insert(note_str, note)
    elseif type(note) == "table" and note.key and note.volume then
      table.insert(note_str, string.format("%s:%d", note.key, math.floor(note.volume * 100)))
    end
  end
  
  -- Convert note strings to uppercase
  local upper_note_str = {}
  for _, note in ipairs(note_str) do
    upper_note_str[#upper_note_str + 1] = note:upper()
  end
  
  local status = string.format("Note (%s) (%02d): %s", 
    unit or current_settings.unit, #notes, table.concat(upper_note_str, ", "))
  
  if text then
    status = status .. " " .. text
  end
  
  return status
end

-- Function to read all settings from current phrase
function read_phrase_settings()
  local instr = renoise.song().selected_instrument
  if not instr or #instr.phrases == 0 then return false end
  
  local phrase = instr.phrases[current_settings.current_phrase_index]
  if not phrase then return false end
  
  -- Read LPB from phrase - ensure it's a valid value
  local lpb_values = {1, 2, 3, 4, 6, 8, 12, 16}
  current_settings.lpb = phrase.lpb
  if not table.find(lpb_values, current_settings.lpb) then
    current_settings.lpb = 4 -- Default to 4 if invalid value
  end
  
  -- Read shuffle from phrase - ensure it's between 0 and 1
  current_settings.shuffle = phrase.shuffle or 0.0
  current_settings.shuffle = math.max(0.0, math.min(1.0, current_settings.shuffle))
  
  print("DEBUG: Read from phrase - LPB:", current_settings.lpb, "Shuffle:", current_settings.shuffle)
  
  -- Read script settings
  if phrase.script then
    for _, line in ipairs(phrase.script.paragraphs) do
      local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
      local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
      local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
      
      if pattern_str then
        -- Count pattern length from existing pattern
        local count = 0
        for num in pattern_str:gmatch("[01]") do
          count = count + 1
        end
        current_settings.pattern_length = count
      end
      
      if unit_str then
        current_settings.unit = unit_str
      end
      
      if emit_str then
        -- Count notes
        local note_count = 0
        for _ in emit_str:gmatch('key%s*=%s*"[^"]+"') do
          note_count = note_count + 1
        end
        current_settings.note_count = note_count
      end
    end
    
    -- Read settings from comment line (last line)
    if #phrase.script.paragraphs > 0 then
      local last_line = phrase.script.paragraphs[#phrase.script.paragraphs]
      if last_line:match("^%-%-") then
        -- Parse octave range
        local oct_min, oct_max = last_line:match("octRange%s*(%d+)%s*(%d+)")
        if oct_min and oct_max then
          current_settings.min_octave = tonumber(oct_min)
          current_settings.max_octave = tonumber(oct_max)
        end
        
        -- Parse volume range
        local vol_min, vol_max = last_line:match("volRange%s*(%d+)%s*(%d+)")
        if vol_min and vol_max then
          current_settings.min_volume = tonumber(vol_min) / 100
          current_settings.max_volume = tonumber(vol_max) / 100
        end
        
        -- Parse scale
        local scale = last_line:match("^%-%-([^%s%-]+)")
        if scale and table.find(SCALE_NAMES, scale) then
          current_settings.scale = scale
        end
        
        -- Parse unit
        local unit = last_line:match(PHRASE_UNIT_FIELD .. "%s+([^%s%-]+)")
        if unit and table.find(RHYTHM_UNITS, unit) then
          current_settings.unit = unit
        end
      end
    end
  end
  
  return true
end

-- Helper function to update pattern length - combines both implementations
function update_pattern_length(settings_or_length, old_length)
  -- Handle both parameter styles for backward compatibility
  local settings = type(settings_or_length) == "table" and settings_or_length or current_settings
  local new_length = type(settings_or_length) == "number" and settings_or_length or settings.pattern_length
  
  -- Ensure new_length is a valid integer
  new_length = math.floor(tonumber(new_length) or 1)
  if new_length < 1 then new_length = 1 end
  if new_length > 32 then new_length = 32 end
  
  local instr = renoise.song().selected_instrument
  if not instr or #instr.phrases == 0 then return end
  
  local phrase = instr.phrases[settings.current_phrase_index]
  local script = phrase.script
  if not script then return end
  
  -- Get current pattern values
  local current_pattern = {}
  local current_unit = ""
  local emit_strings = {}
  
  for _, line in ipairs(script.paragraphs) do
    local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
    local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
    local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
    
    if pattern_str then
      for num in pattern_str:gmatch("[01]") do
        table.insert(current_pattern, tonumber(num))
      end
    end
    if unit_str then current_unit = unit_str end
    if emit_str then
      emit_strings = {emit_str}  -- Keep emit section as is
    end
  end
  
  -- Generate new pattern preserving existing values
  local new_pattern = {}
  if #current_pattern > 0 then
    -- If we have existing pattern values, preserve them up to their length
    for i = 1, new_length do
      if i <= #current_pattern then
        -- Keep existing values
        new_pattern[i] = current_pattern[i]
      else
        -- Randomize new values
        new_pattern[i] = math.random(0, 1)
      end
    end
  else
    -- If no existing pattern, initialize with random values
    for i = 1, new_length do
      new_pattern[i] = math.random(0, 1)
    end
  end
  
  -- Rebuild script with new pattern length
  script.paragraphs = {
    "return " .. PHRASE_RETURN_TYPE .. " {",
    string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', current_unit),
    string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(new_pattern, ",")),
    format_emit_line(emit_strings),
    "}",
    build_comment_line(current_settings)
  }
  script:commit()
  
  if script.compile_error ~= "" then
    local msg = "Compile error: " .. script.compile_error
    print(msg)
    renoise.app():show_status(msg)
    return
  end
  
  -- Update pattern display
  if vb and vb.views.pattern_display then
    local pattern_str = ""
    for i, val in ipairs(new_pattern) do
      pattern_str = pattern_str .. (val == 1 and "■" or "□")
      if i < #new_pattern then
        pattern_str = pattern_str .. " "
      end
    end
    vb.views.pattern_display.text = pattern_str
  end
  
  -- Show status message in the same format as length slider
  local trigger_boxes = ""
  for i = 1, #new_pattern do
    trigger_boxes = trigger_boxes .. (new_pattern[i] == 1 and "■" or "□")
  end
  renoise.app():show_status(string.format("Pattern (%s) (%02d): %s", current_unit, #new_pattern, trigger_boxes))
  
  -- Render if auto-render is enabled
  if current_settings.always_render then
    render_to_pattern(phrase.script, current_settings, false)
  end
end

-- Helper function to update comment line only
function update_comment_line_only()
  local instr = renoise.song().selected_instrument
  if instr and #instr.phrases > 0 then
    local phrase = instr.phrases[current_settings.current_phrase_index]
    if phrase and phrase.script then
      -- Get the last line (comment)
      local paragraphs = phrase.script.paragraphs
      if #paragraphs > 0 then
        -- Update only the comment line
        paragraphs[#paragraphs] = build_comment_line(current_settings)
        phrase.script.paragraphs = paragraphs
        phrase.script:commit()
      end
    end
  end
end

-- Helper function to adjust note to fit within octave range
function adjust_note_to_octave_range(note_key, min_oct, max_oct)
  -- Extract note name and current octave
  local note_name = note_key:match("([a-g][#%-]?)")
  local current_octave = tonumber(note_key:match("%d+"))
  
  if not note_name or not current_octave then
    return note_key -- Return original if we can't parse it
  end
  
  -- Clean up note name (remove trailing dash if not a flat note)
  note_name = note_name:gsub("%-$", "")
  
  -- Clamp octave to new range
  local new_octave = math.max(min_oct, math.min(max_oct, current_octave))
  
  return note_name .. new_octave
end

-- Function to update notes to fit new octave range
function update_notes_for_octave_range(settings)
  local instr = renoise.song().selected_instrument
  if not instr or #instr.phrases == 0 then return end
  
  local phrase = instr.phrases[settings.current_phrase_index]
  if not phrase or not phrase.script then return end
  
  -- Extract existing notes and other script components
  local current_pattern = {}
  local current_unit = settings.unit
  local notes = {}
  local existing_comment = ""
  
  for _, line in ipairs(phrase.script.paragraphs) do
    local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
    local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
    local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
    
    if pattern_str then
      for num in pattern_str:gmatch("[01]") do
        table.insert(current_pattern, tonumber(num))
      end
    end
    if unit_str then current_unit = unit_str end
    if emit_str then
      -- Extract existing notes and adjust their octaves to fit within range
      for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
        -- Extract note name and current octave
        local note_name = key:match("([a-g][#%-]?)")
        local current_octave = tonumber(key:match("%d+"))
        
        if note_name and current_octave then
          -- Clean up note name - remove trailing - if not a flat
          note_name = note_name:gsub("%-$", "")
          -- Keep the same note but clamp its octave to the new range
          local new_octave = math.max(settings.min_octave, math.min(settings.max_octave, current_octave))
          local new_key = note_name .. new_octave
          table.insert(notes, {key=new_key, volume=tonumber(vol)})
        end
      end
    end
  end
  
  -- Build new comment line with updated octave range
  local comment = build_comment_line(settings)
  
  -- Update script with adjusted notes and comment
  local new_paragraphs = {
    "return " .. PHRASE_RETURN_TYPE .. " {",
    string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', current_unit),
    string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(current_pattern, ",")),
    format_emit_line(notes),
    "}",
    comment
  }
  
  phrase.script.paragraphs = new_paragraphs
  phrase.script:commit()
  
  if phrase.script.compile_error ~= "" then
    local msg = "Compile error: " .. phrase.script.compile_error
    print(msg)
    renoise.app():show_status(msg)
    return
  end
  
  -- Show status with updated notes
  renoise.app():show_status(format_note_status(notes, current_unit))
  
  -- Add auto-render if enabled
  if settings.always_render then
    render_to_pattern(phrase.script, settings, false)
  end
end

-- Helper function to adjust note octaves to fit within range
function adjust_note_octaves(script, min_oct, max_oct)
  -- Extract existing notes and other components
  local emit_strings = {}
  local current_pattern = {}
  local current_unit = current_settings.unit
  local notes = {}
  
  for _, line in ipairs(script.paragraphs) do
    local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
    local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
    local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
    
    if pattern_str then
      for num in pattern_str:gmatch("[01]") do
        table.insert(current_pattern, tonumber(num))
      end
    end
    if unit_str then current_unit = unit_str end
    if emit_str then
      -- Extract and adjust each note's octave
      for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
        local note_name = key:match("([a-g][#%-]?)")
        local octave = tonumber(key:match("%d+"))
        
        if note_name and octave then
          -- Clean up note name
          note_name = note_name:gsub("%-$", "")
          -- Clamp octave to new range
          octave = math.max(min_oct, math.min(max_oct, octave))
          -- Create new note with adjusted octave
          table.insert(notes, {key=note_name..octave,volume=tonumber(vol)})
        else
          -- If we can't parse the note, keep it as is
          table.insert(notes, {key=key,volume=tonumber(vol)})
        end
      end
    end
  end
  
  -- Update script paragraphs through proper methods
  local new_paragraphs = {
    "return " .. PHRASE_RETURN_TYPE .. " {",
    string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', current_unit),
    string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(current_pattern, ",")),
    format_emit_line(notes),
    "}",
    build_comment_line(current_settings)
  }
  
  script.paragraphs = new_paragraphs
  return script
end

-- Single source of truth for emit line formatting
function format_emit_line(notes)
  -- If notes is empty, return empty event line
  if not notes or #notes == 0 then
    return "  " .. PHRASE_EVENT_FIELD .. " = {}"
  end

  -- Format each note entry without spaces
  local emit_entries = {}
  for _, note in ipairs(notes) do
    if type(note) == "string" then
      -- If note is already a formatted string, use it directly
      table.insert(emit_entries, note)
    elseif type(note) == "table" and note.key and note.volume then
      -- If note is a table with key and volume, format it
      table.insert(emit_entries, string.format('{key="%s",volume=%.2f}', note.key, note.volume))
    else
      print("Warning: Invalid note format in format_emit_line:", note)
    end
  end
  
  -- Join all entries without spaces
  return string.format("  " .. PHRASE_EVENT_FIELD .. "={%s}", table.concat(emit_entries, ","))
end

-- Helper function to shift all notes in phrase by octaves
function shift_phrase_octaves(octave_shift)
  local instr = renoise.song().selected_instrument
  if not instr or #instr.phrases == 0 then return end
  
  local phrase = instr.phrases[current_settings.current_phrase_index]
  if not phrase or not phrase.script then return end
  
  -- Extract current pattern and notes
  local current_pattern = {}
  local current_unit = current_settings.unit
  local notes = {}
  
  for _, line in ipairs(phrase.script.paragraphs) do
    local pattern_str = line:match(PHRASE_PATTERN_FIELD .. '%s*=%s*{([^}]+)}')
    local unit_str = line:match(PHRASE_UNIT_FIELD .. '%s*=%s*"([^"]+)"')
    local emit_str = line:match(PHRASE_EVENT_FIELD .. '%s*=%s*{(.+)}')
    
    if pattern_str then
      for num in pattern_str:gmatch("[01]") do
        table.insert(current_pattern, tonumber(num))
      end
    end
    if unit_str then current_unit = unit_str end
    if emit_str then
      for key, vol in emit_str:gmatch('key%s*=%s*"([^"]+)",?%s*volume%s*=%s*([%d%.]+)') do
        -- Extract note name and current octave
        local note_name = key:match("([a-g][#%-]?)")
        local current_octave = tonumber(key:match("%d+"))
        
        if note_name and current_octave then
          -- Clean up note name
          note_name = note_name:gsub("%-$", "")
          -- Shift octave and clamp to valid range (0-9)
          local new_octave = math.max(0, math.min(9, current_octave + octave_shift))
          local new_key = note_name .. new_octave
          table.insert(notes, {key=new_key, volume=tonumber(vol)})
        end
      end
    end
  end
  
  -- Update settings with new octave range
  current_settings.min_octave = math.max(0, math.min(9, current_settings.min_octave + octave_shift))
  current_settings.max_octave = math.max(0, math.min(9, current_settings.max_octave + octave_shift))
  
  -- Update UI if it exists
  if vb then
    if vb.views.min_octave_box then
      vb.views.min_octave_box.value = current_settings.min_octave
    end
    if vb.views.max_octave_box then
      vb.views.max_octave_box.value = current_settings.max_octave
    end
  end
  
  -- Rebuild script with shifted notes and updated comment
  local new_paragraphs = {
    "return " .. PHRASE_RETURN_TYPE .. " {",
    string.format('  ' .. PHRASE_UNIT_FIELD .. ' = "%s",', current_unit),
    string.format("  " .. PHRASE_PATTERN_FIELD .. " = {%s},", table.concat(current_pattern, ",")),
    format_emit_line(notes),
    "}",
    build_comment_line(current_settings)
  }
  
  phrase.script.paragraphs = new_paragraphs
  phrase.script:commit()
  
  if phrase.script.compile_error ~= "" then
    local msg = "Compile error: " .. phrase.script.compile_error
    print(msg)
    renoise.app():show_status(msg)
    return
  end
  
  renoise.app():show_status(format_note_status(notes, current_unit))
  
  -- Render if auto-render is enabled
  if current_settings.always_render then
    render_to_pattern(phrase.script, current_settings, false)
  end
end
