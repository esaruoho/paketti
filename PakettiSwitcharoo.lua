-- PakettiSwitcharoo.lua
-- Advanced Chord Progression Reharmonization Tool
-- Lua 5.1 only. All functions GLOBAL and defined before first use.
-- Uses my_keyhandler_func as fallback. After dialog opens, reactivate middle frame for key passthrough.

-- State Variables
PakettiSwitcharoo_dialog = nil
PakettiSwitcharoo_vb = nil
PakettiSwitcharoo_sequences = {} -- Original chord progressions
PakettiSwitcharoo_transformed_sequences = {} -- After all transformations
PakettiSwitcharoo_original_line_positions = {} -- Store where each chord was read from
PakettiSwitcharoo_selected_slot = 1
PakettiSwitcharoo_current_audition_slot = nil
PakettiSwitcharoo_current_audition_type = nil -- "original" or "transformed"
PakettiSwitcharoo_audition_notes = {}
PakettiSwitcharoo_MAX_ROWS = 16
PakettiSwitcharoo_DEBUG = true

-- Per-slot transformation values
PakettiSwitcharoo_voicing_values = {}
PakettiSwitcharoo_inversion_values = {}
PakettiSwitcharoo_circle_of_fifths_values = {}
PakettiSwitcharoo_complexity_values = {}
PakettiSwitcharoo_min_octave_values = {}
PakettiSwitcharoo_max_octave_values = {}

-- UI References
PakettiSwitcharoo_original_texts = {}
PakettiSwitcharoo_resultant_texts = {}
PakettiSwitcharoo_voicing_controls = {}
PakettiSwitcharoo_inversion_controls = {}
PakettiSwitcharoo_cof_controls = {}
PakettiSwitcharoo_complexity_controls = {}
PakettiSwitcharoo_min_octave_controls = {}
PakettiSwitcharoo_max_octave_controls = {}
PakettiSwitcharoo_audition_buttons = {}
PakettiSwitcharoo_switcharoo_buttons = {}

-- Constants
PakettiSwitcharoo_BUTTON_HEIGHT = 20
PakettiSwitcharoo_DIALOG_WIDTH = 900
PakettiSwitcharoo_CONTROL_WIDTH = 60

-- Circle of Fifths mapping (C=0, G=7, D=2, A=9, etc.)
PakettiSwitcharoo_CIRCLE_OF_FIFTHS = {0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5} -- C G D A E B F# C# G# D# A# F
PakettiSwitcharoo_NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

-- Initialize transformation values for all slots
function PakettiSwitcharoo_InitializeSlot(index)
  PakettiSwitcharoo_voicing_values[index] = 0
  PakettiSwitcharoo_inversion_values[index] = 0
  PakettiSwitcharoo_circle_of_fifths_values[index] = 0
  PakettiSwitcharoo_complexity_values[index] = 0
  PakettiSwitcharoo_min_octave_values[index] = 0  -- C-0
  PakettiSwitcharoo_max_octave_values[index] = 7  -- C-7
end

-- Helper: convert note string to value (0-119) - reuse from PakettiCapture
function PakettiSwitcharoo_NoteStringToValue(note_string)
  if not note_string or note_string == "" or note_string == "OFF" then return nil end
  local name = string.sub(note_string, 1, 2)
  local octave_char = string.sub(note_string, 3, 3)
  local names = { ["C-"] = 0, ["C#"] = 1, ["D-"] = 2, ["D#"] = 3, ["E-"] = 4, ["F-"] = 5, ["F#"] = 6, ["G-"] = 7, ["G#"] = 8, ["A-"] = 9, ["A#"] = 10, ["B-"] = 11 }
  local base = names[name]
  local octave = tonumber(octave_char)
  if base == nil or octave == nil then return nil end
  local value = (octave * 12) + base
  return math.max(0, math.min(119, value))
end

-- Helper: convert 0..119 to note string C-0..B-9
function PakettiSwitcharoo_NoteValueToString(value)
  local names = {"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}
  local v = math.max(0, math.min(119, value))
  local octave = math.floor(v / 12)
  local name = names[(v % 12) + 1]
  return name .. tostring(octave)
end

-- Music Theory Functions

-- Apply voicing transformation with octave range limits
function PakettiSwitcharoo_ApplyVoicing(notes, voicing_level, min_octave, max_octave)
  if voicing_level == 0 then return notes end
  
  -- Default octave range if not provided
  min_octave = min_octave or 0
  max_octave = max_octave or 7
  
  local result = {}
  local adjustments = {-24, -12, 12, 24} -- Octave shifts: -2, -1, +1, +2
  
  -- Use voicing_level as seed for consistent randomization per slot
  math.randomseed(voicing_level * 1000)
  
  for i, note_str in ipairs(notes) do
    local note_val = PakettiSwitcharoo_NoteStringToValue(note_str)
    if note_val then
      local adjustment = adjustments[math.random(#adjustments)]
      local new_val = note_val + adjustment
      
      -- Calculate octave of the new note value
      local new_octave = math.floor(new_val / 12)
      
      -- If outside octave range, try to find a valid octave for this note
      if new_octave < min_octave or new_octave > max_octave then
        local pitch_class = new_val % 12  -- Get the note within the octave (C, C#, D, etc.)
        
        -- Try to place the note in a valid octave range
        local found_valid = false
        for octave = min_octave, max_octave do
          local test_val = octave * 12 + pitch_class
          if test_val >= 0 and test_val <= 119 then
            new_val = test_val
            found_valid = true
            break
          end
        end
        
        -- If no valid octave found, keep original note
        if not found_valid then
          new_val = note_val
        end
      end
      
      -- Final clamp to MIDI range (redundant but safe)
      new_val = math.max(0, math.min(119, new_val))
      table.insert(result, PakettiSwitcharoo_NoteValueToString(new_val))
    else
      table.insert(result, note_str) -- Keep original if conversion fails
    end
  end
  
  -- Reset random seed to avoid affecting other random operations
  math.randomseed(os.time())
  
  return result
end

-- Apply chord inversion (preserves note identity, fully reversible)
function PakettiSwitcharoo_ApplyInversion(notes, inversion_steps)
  if inversion_steps == 0 or #notes < 2 then return notes end
  
  -- Create note objects with identity preservation
  local note_objects = {}
  for i, note_str in ipairs(notes) do
    local val = PakettiSwitcharoo_NoteStringToValue(note_str)
    if val then
      table.insert(note_objects, {
        value = val,
        pitch_class = val % 12,  -- 0-11 (C, C#, D, ...)
        octave = math.floor(val / 12),  -- 0-9
        original_index = i  -- Preserve original position
      })
    end
  end
  
  if #note_objects < 2 then return notes end
  
  -- Sort by current pitch value
  table.sort(note_objects, function(a, b) return a.value < b.value end)
  
  -- Apply inversions (positive = up, negative = down)
  local steps = math.abs(inversion_steps)
  local direction = inversion_steps > 0 and 1 or -1
  
  for step = 1, steps do
    if direction > 0 then
      -- Move lowest note up an octave
      local lowest = note_objects[1]
      table.remove(note_objects, 1)
      lowest.octave = lowest.octave + 1
      lowest.value = (lowest.octave * 12) + lowest.pitch_class
      
      -- If out of range, try different octave positions
      if lowest.value > 119 then
        -- Find a valid octave for this pitch class
        for oct = 9, 0, -1 do
          local test_val = (oct * 12) + lowest.pitch_class
          if test_val <= 119 then
            lowest.octave = oct
            lowest.value = test_val
            break
          end
        end
      end
      
      table.insert(note_objects, lowest)
      table.sort(note_objects, function(a, b) return a.value < b.value end)
    else
      -- Move highest note down an octave
      local highest = note_objects[#note_objects]
      table.remove(note_objects, #note_objects)
      highest.octave = highest.octave - 1
      highest.value = (highest.octave * 12) + highest.pitch_class
      
      -- If out of range, try different octave positions
      if highest.value < 0 then
        -- Find a valid octave for this pitch class
        for oct = 0, 9 do
          local test_val = (oct * 12) + highest.pitch_class
          if test_val >= 0 then
            highest.octave = oct
            highest.value = test_val
            break
          end
        end
      end
      
      table.insert(note_objects, 1, highest)
      table.sort(note_objects, function(a, b) return a.value < b.value end)
    end
  end
  
  -- Convert back to note strings
  local result = {}
  for _, obj in ipairs(note_objects) do
    local final_val = math.max(0, math.min(119, obj.value))
    table.insert(result, PakettiSwitcharoo_NoteValueToString(final_val))
  end
  
  return result
end

-- Apply Circle of Fifths transposition
function PakettiSwitcharoo_ApplyCircleOfFifths(notes, cof_steps)
  if cof_steps == 0 then return notes end
  
  -- Calculate semitone offset (each step = 7 semitones = perfect fifth)
  local semitone_offset = cof_steps * 7
  
  local result = {}
  for _, note_str in ipairs(notes) do
    local note_val = PakettiSwitcharoo_NoteStringToValue(note_str)
    if note_val then
      local new_val = note_val + semitone_offset
      -- Clamp to valid MIDI range
      new_val = math.max(0, math.min(119, new_val))
      table.insert(result, PakettiSwitcharoo_NoteValueToString(new_val))
    else
      table.insert(result, note_str) -- Keep original if conversion fails
    end
  end
  
  return result
end

-- Find the most likely harmonic root of a chord
function PakettiSwitcharoo_FindChordRoot(note_values)
  if #note_values < 2 then return note_values[1] end
  
  -- Get unique pitch classes
  local pitch_classes = {}
  local pc_to_note = {}
  for _, note_val in ipairs(note_values) do
    local pc = note_val % 12
    pitch_classes[pc] = true
    if not pc_to_note[pc] then
      pc_to_note[pc] = note_val -- Store first occurrence of this pitch class
    end
  end
  
  -- Convert to sorted array
  local pc_array = {}
  for pc, _ in pairs(pitch_classes) do
    table.insert(pc_array, pc)
  end
  table.sort(pc_array)
  
  -- Try each pitch class as potential root and score it
  local best_root = nil
  local best_score = -1
  
  for _, potential_root in ipairs(pc_array) do
    local score = 0
    local intervals = {}
    
    -- Calculate intervals from this potential root
    for _, pc in ipairs(pc_array) do
      local interval = (pc - potential_root + 12) % 12
      intervals[interval] = true
    end
    
    -- Score based on presence of chord tones
    if intervals[0] then score = score + 10 end  -- Root (always present)
    if intervals[4] then score = score + 8 end   -- Major 3rd
    if intervals[3] then score = score + 8 end   -- Minor 3rd  
    if intervals[7] then score = score + 6 end   -- Perfect 5th
    if intervals[10] then score = score + 4 end  -- Minor 7th
    if intervals[11] then score = score + 4 end  -- Major 7th
    
    -- Penalty for weird intervals that suggest this isn't the root
    if intervals[1] then score = score - 2 end   -- b2 (avoid)
    if intervals[6] then score = score - 1 end   -- b5 (diminished)
    
    if score > best_score then
      best_score = score
      best_root = potential_root
    end
  end
  
  -- Return the actual note value for the best root (prefer higher octave for extensions)
  return pc_to_note[best_root] or note_values[1]
end

-- Analyze chord intervals from root to determine chord quality
function PakettiSwitcharoo_AnalyzeChord(note_values, root_val)
  if #note_values < 2 then return "unknown", root_val end
  
  -- Convert to intervals from the given root (mod 12)
  local root = root_val % 12
  local intervals = {}
  for i = 1, #note_values do
    local interval = (note_values[i] % 12 - root + 12) % 12
    intervals[interval] = true
  end
  
  -- Analyze chord quality based on 3rd and other intervals
  local has_minor_3rd = intervals[3]
  local has_major_3rd = intervals[4] 
  local has_perfect_5th = intervals[7]
  local has_dim_5th = intervals[6]
  local has_aug_5th = intervals[8]
  local has_minor_7th = intervals[10]
  local has_major_7th = intervals[11]
  
  -- Determine chord type based on interval analysis
  if has_minor_3rd and has_dim_5th then
    return "diminished", root_val    -- 1 b3 b5 (+ bb7)
  elseif has_minor_3rd and has_minor_7th then
    return "minor7", root_val        -- 1 b3 5 b7
  elseif has_minor_3rd then
    return "minor", root_val         -- 1 b3 5
  elseif has_major_3rd and has_minor_7th then
    return "dominant7", root_val     -- 1 3 5 b7 (classic V7 chord)
  elseif has_major_3rd and has_major_7th then
    return "major7", root_val        -- 1 3 5 7 (jazz major chord)
  elseif has_major_3rd and has_aug_5th then
    return "augmented", root_val     -- 1 3 #5
  elseif has_major_3rd then
    return "major", root_val         -- 1 3 5
  else
    return "unknown", root_val       -- No clear 3rd or unrecognized intervals
  end
end

-- Apply complexity transformation (proper chord extensions based on chord quality)
function PakettiSwitcharoo_ApplyComplexity(notes, complexity_level)
  if complexity_level == 0 then return notes end
  
  local result = {}
  for _, note_str in ipairs(notes) do
    table.insert(result, note_str)
  end
  
  if #result < 2 then return result end -- Need at least 2 notes for complexity
  
  -- Sort notes by pitch for analysis
  local note_values = {}
  for _, note_str in ipairs(result) do
    local note_val = PakettiSwitcharoo_NoteStringToValue(note_str)
    if note_val then
      table.insert(note_values, note_val)
    end
  end
  table.sort(note_values)
  
  -- Find the actual harmonic root (not just lowest note)
  local root_val = PakettiSwitcharoo_FindChordRoot(note_values)
  local chord_type, _ = PakettiSwitcharoo_AnalyzeChord(note_values, root_val)
  
  -- Find a good octave for extensions (higher than existing notes)
  local highest_note = note_values[#note_values]
  local extension_base_octave = math.floor(highest_note / 12) + 1 -- One octave above highest note
  local extension_root = (root_val % 12) + (extension_base_octave * 12)
  
  if PakettiSwitcharoo_DEBUG then
    print("PakettiSwitcharoo DEBUG: Root=" .. PakettiSwitcharoo_NoteValueToString(root_val) .. ", Type=" .. tostring(chord_type) .. ", Extensions from=" .. PakettiSwitcharoo_NoteValueToString(extension_root))
  end
  
  -- Add extensions based on chord type and complexity level
  local extensions_to_add = {}
  
  if complexity_level >= 1 then
    -- Level 1: Add appropriate 7th
    if chord_type == "major" or chord_type == "augmented" then
      table.insert(extensions_to_add, 11) -- Major 7th for major chords
    elseif chord_type == "minor" then
      table.insert(extensions_to_add, 10) -- Minor 7th for minor chords  
    elseif chord_type == "diminished" then
      table.insert(extensions_to_add, 9)  -- dim7 (actually 6th)
    else -- dominant7, major7, minor7, unknown
      table.insert(extensions_to_add, 10) -- Minor 7th (dominant sound)
    end
  end
  
  if complexity_level >= 2 then  
    -- Level 2: Add 9th
    table.insert(extensions_to_add, 14) -- Major 9th
  end
  
  if complexity_level >= 3 then
    -- Level 3: Add 11th or #11
    if chord_type == "major" or chord_type == "major7" or chord_type == "dominant7" then
      table.insert(extensions_to_add, 18) -- #11 (avoid clash with major 3rd)
    else
      table.insert(extensions_to_add, 17) -- Perfect 11th for minor chords
    end
  end
  
  if complexity_level >= 4 then
    -- Level 4: Add alterations for dominant chords, 13th for others
    if chord_type == "dominant7" then
      table.insert(extensions_to_add, 15) -- #9 (classic altered dominant)
    else
      table.insert(extensions_to_add, 21) -- 13th (6th up octave)
    end
  end
  
  if complexity_level >= 5 then
    -- Level 5: More alterations or extensions
    if chord_type == "dominant7" then
      table.insert(extensions_to_add, 6)  -- b5 (tritone sub flavor)
    else
      table.insert(extensions_to_add, 16) -- b9 for tension
    end
  end
  
  if complexity_level >= 6 then
    -- Level 6: Add #5 (augmented 5th) or b13
    if chord_type == "dominant7" or chord_type == "major7" then
      table.insert(extensions_to_add, 8)  -- #5 (augmented 5th)
    else
      table.insert(extensions_to_add, 20) -- b13
    end
  end
  
  if complexity_level >= 7 then
    -- Level 7: Add #13 or b11 alterations
    if chord_type == "dominant7" then
      table.insert(extensions_to_add, 22) -- #13 (classic altered dominant)
    else
      table.insert(extensions_to_add, 16) -- b11 for minor chords
    end
  end
  
  if complexity_level >= 8 then
    -- Level 8: Upper structure triads - add major triad from b7
    local b7_from_root = extension_root + 10 -- b7
    table.insert(extensions_to_add, 10) -- b7 itself
    table.insert(extensions_to_add, 14) -- 9th (major 2nd from b7)  
    table.insert(extensions_to_add, 17) -- 11th (perfect 4th from b7)
  end
  
  if complexity_level >= 9 then
    -- Level 9: Polychordal elements - tritone substitution chord tones
    table.insert(extensions_to_add, 1)  -- b2 (very dissonant)
    table.insert(extensions_to_add, 7)  -- b6
  end
  
  if complexity_level >= 10 then
    -- Level 10: Maximum alterations - all chromatic neighbors
    table.insert(extensions_to_add, 13) -- b9 (if not already added)
    table.insert(extensions_to_add, 15) -- #9 (if not already added)
    table.insert(extensions_to_add, 19) -- b13 alternate octave
  end
  
  if complexity_level >= 11 then
    -- Level 11: Extreme extensions - double alterations
    table.insert(extensions_to_add, 2)  -- major 2nd (very close)
    table.insert(extensions_to_add, 5)  -- perfect 4th in lower register
    table.insert(extensions_to_add, 23) -- b7 up an octave
  end
  
  if complexity_level >= 12 then
    -- Level 12: Chromatic saturation - fill remaining chromatic spaces
    table.insert(extensions_to_add, 3)  -- minor 3rd variation
    table.insert(extensions_to_add, 9)  -- major 6th
    table.insert(extensions_to_add, 12) -- octave (reinforcement)
  end
  
  -- Add the extensions from the higher octave root, avoiding duplicates  
  for _, semitones in ipairs(extensions_to_add) do
    local new_val = extension_root + semitones
    -- If too high, try one octave lower
    if new_val > 119 then
      new_val = new_val - 12
    end
    
    if new_val >= 0 and new_val <= 119 then
      local new_note_str = PakettiSwitcharoo_NoteValueToString(new_val)
      -- Check if this note (mod 12) is already present
      local new_pitch_class = new_val % 12
      local already_present = false
      for _, existing_note in ipairs(result) do
        local existing_val = PakettiSwitcharoo_NoteStringToValue(existing_note)
        if existing_val and (existing_val % 12) == new_pitch_class then
          already_present = true
          break
        end
      end
      if not already_present then
        table.insert(result, new_note_str)
        if PakettiSwitcharoo_DEBUG then
          print("PakettiSwitcharoo DEBUG: Added extension: " .. new_note_str)
        end
      end
    end
  end
  
  return result
end

-- Helper: clamp all notes to octave range, preserving pitch classes
function PakettiSwitcharoo_ClampToOctaveRange(notes, min_octave, max_octave)
  if min_octave == 0 and max_octave == 7 then return notes end -- No clamping needed
  
  local result = {}
  for _, note_str in ipairs(notes) do
    local note_val = PakettiSwitcharoo_NoteStringToValue(note_str)
    if note_val then
      local current_octave = math.floor(note_val / 12)
      
      -- If note is outside range, find best octave for this pitch class
      if current_octave < min_octave or current_octave > max_octave then
        local pitch_class = note_val % 12
        local best_octave = nil
        local best_distance = 999
        
        -- Find octave within range that's closest to current octave
        for octave = min_octave, max_octave do
          local distance = math.abs(octave - current_octave)
          if distance < best_distance then
            best_distance = distance
            best_octave = octave
          end
        end
        
        if best_octave then
          local new_val = best_octave * 12 + pitch_class
          if new_val >= 0 and new_val <= 119 then
            table.insert(result, PakettiSwitcharoo_NoteValueToString(new_val))
          else
            table.insert(result, note_str) -- Keep original if calculation fails
          end
        else
          table.insert(result, note_str) -- Keep original if no valid octave found
        end
      else
        table.insert(result, note_str) -- Note is already in range
      end
    else
      table.insert(result, note_str) -- Keep original if conversion fails
    end
  end
  
  return result
end

-- Transform a chord sequence through all transformations
function PakettiSwitcharoo_TransformSequence(index)
  if not PakettiSwitcharoo_sequences[index] then return end
  
  local original = PakettiSwitcharoo_sequences[index]
  local result = {}
  
  -- Copy original notes
  for _, note in ipairs(original) do
    table.insert(result, note)
  end
  
  local min_octave = PakettiSwitcharoo_min_octave_values[index] or 0
  local max_octave = PakettiSwitcharoo_max_octave_values[index] or 7
  
  -- Apply transformations in order
  result = PakettiSwitcharoo_ApplyVoicing(result, PakettiSwitcharoo_voicing_values[index] or 0, min_octave, max_octave)
  result = PakettiSwitcharoo_ApplyInversion(result, PakettiSwitcharoo_inversion_values[index] or 0)
  result = PakettiSwitcharoo_ApplyCircleOfFifths(result, PakettiSwitcharoo_circle_of_fifths_values[index] or 0)
  result = PakettiSwitcharoo_ApplyComplexity(result, PakettiSwitcharoo_complexity_values[index] or 0)
  
  -- Apply octave clamping to all final notes (including complexity extensions)
  result = PakettiSwitcharoo_ClampToOctaveRange(result, min_octave, max_octave)
  
  -- Remove duplicate notes from final result
  local unique_result = {}
  local seen = {}
  for _, note_str in ipairs(result) do
    if not seen[note_str] then
      seen[note_str] = true
      table.insert(unique_result, note_str)
    end
  end
  
  PakettiSwitcharoo_transformed_sequences[index] = unique_result
end

-- Transform all sequences
function PakettiSwitcharoo_TransformAllSequences()
  for i = 1, #PakettiSwitcharoo_sequences do
    PakettiSwitcharoo_TransformSequence(i)
  end
  PakettiSwitcharoo_UpdateUI()
end

-- Read chords from pattern (similar to PakettiCapture_PickupFromPattern)
function PakettiSwitcharoo_ReadChordsFromPattern()
  local song = renoise.song()
  local track = song.selected_track
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("PakettiSwitcharoo: Not a sequencer track")
    return
  end
  
  -- Stop any current audition
  PakettiSwitcharoo_AuditionStop()
  
  -- Clear existing sequences
  PakettiSwitcharoo_sequences = {}
  PakettiSwitcharoo_transformed_sequences = {}
  PakettiSwitcharoo_original_line_positions = {}
  local slot_count = 0
  
  local patt = song:pattern(song.selected_pattern_index)
  local ptrack = patt:track(song.selected_track_index)
  local num_lines = patt.number_of_lines
  
  if PakettiSwitcharoo_DEBUG then
    print("PakettiSwitcharoo DEBUG: Scanning pattern with " .. tostring(num_lines) .. " lines")
  end
  
  for line_idx = 1, num_lines do
    if slot_count >= PakettiSwitcharoo_MAX_ROWS then break end
    
    local line = ptrack:line(line_idx)
    local notes_in_line = {}
    
    -- Scan all note columns in this line
    local max_cols = math.min(12, #line.note_columns)
    for col_idx = 1, max_cols do
      local ncol = line:note_column(col_idx)
      if not ncol.is_empty and ncol.note_string ~= "OFF" and ncol.note_string ~= "" then
        table.insert(notes_in_line, ncol.note_string)
      end
    end
    
    -- If we found notes (preferably chords = 2+ notes), create a slot
    if #notes_in_line > 0 then
      slot_count = slot_count + 1
      table.insert(PakettiSwitcharoo_sequences, notes_in_line)
      table.insert(PakettiSwitcharoo_original_line_positions, line_idx) -- Store original line position
      PakettiSwitcharoo_InitializeSlot(slot_count)
      PakettiSwitcharoo_TransformSequence(slot_count)
      
      if PakettiSwitcharoo_DEBUG then
        print("PakettiSwitcharoo DEBUG: Line " .. tostring(line_idx) .. " -> Slot " .. tostring(slot_count) .. ": " .. table.concat(notes_in_line, " "))
      end
    end
  end
  
  PakettiSwitcharoo_selected_slot = 1
  PakettiSwitcharoo_UpdateUI()
  renoise.app():show_status("PakettiSwitcharoo: Read " .. tostring(slot_count) .. " chord progressions from pattern")
end

-- Stop any currently playing audition
function PakettiSwitcharoo_AuditionStop()
  if PakettiSwitcharoo_current_audition_slot == nil then return end
  
  local song = renoise.song()
  local selected_track_index = song.selected_track_index
  local selected_instrument_index = song.selected_instrument_index
  
  -- Stop all notes that were triggered for this slot - but make sure they're unique
  if #PakettiSwitcharoo_audition_notes > 0 then
    -- Remove duplicates from audition_notes to avoid "notes must be unique" error
    local unique_notes = {}
    local seen = {}
    for _, note_value in ipairs(PakettiSwitcharoo_audition_notes) do
      if not seen[note_value] then
        seen[note_value] = true
        table.insert(unique_notes, note_value)
      end
    end
    
    if #unique_notes > 0 then
      song:trigger_instrument_note_off(selected_instrument_index, selected_track_index, unique_notes)
    end
  end
  
  PakettiSwitcharoo_current_audition_slot = nil
  PakettiSwitcharoo_current_audition_type = nil
  PakettiSwitcharoo_audition_notes = {}
  PakettiSwitcharoo_UpdateUI()
end

-- Start audition for original notes
function PakettiSwitcharoo_AuditionOriginal(slot_index)
  if slot_index < 1 or slot_index > #PakettiSwitcharoo_sequences then return end
  
  PakettiSwitcharoo_AuditionStop()
  
  local song = renoise.song()
  local selected_track_index = song.selected_track_index
  local selected_instrument_index = song.selected_instrument_index
  local instrument = song:instrument(selected_instrument_index)
  
  if not instrument then return end
  
  local seq = PakettiSwitcharoo_sequences[slot_index]
  if not seq or #seq == 0 then return end
  
  PakettiSwitcharoo_current_audition_slot = slot_index
  PakettiSwitcharoo_current_audition_type = "original"
  PakettiSwitcharoo_audition_notes = {}
  
  -- Convert note strings to values and trigger (remove duplicates)
  local note_values = {}
  local seen = {}
  for _, note_string in ipairs(seq) do
    local note_value = PakettiSwitcharoo_NoteStringToValue(note_string)
    if note_value and not seen[note_value] then
      seen[note_value] = true
      table.insert(note_values, note_value)
      table.insert(PakettiSwitcharoo_audition_notes, note_value)
    end
  end
  
  if #note_values > 0 then
    song:trigger_instrument_note_on(selected_instrument_index, selected_track_index, note_values, 1.0)
  end
  
  PakettiSwitcharoo_UpdateUI()
end

-- Start audition for transformed notes
function PakettiSwitcharoo_AuditionTransformed(slot_index)
  if slot_index < 1 or slot_index > #PakettiSwitcharoo_transformed_sequences then return end
  
  PakettiSwitcharoo_AuditionStop()
  
  local song = renoise.song()
  local selected_track_index = song.selected_track_index
  local selected_instrument_index = song.selected_instrument_index
  local instrument = song:instrument(selected_instrument_index)
  
  if not instrument then return end
  
  local seq = PakettiSwitcharoo_transformed_sequences[slot_index]
  if not seq or #seq == 0 then return end
  
  PakettiSwitcharoo_current_audition_slot = slot_index
  PakettiSwitcharoo_current_audition_type = "transformed"
  PakettiSwitcharoo_audition_notes = {}
  
  -- Convert note strings to values and trigger (remove duplicates)
  local note_values = {}
  local seen = {}
  for _, note_string in ipairs(seq) do
    local note_value = PakettiSwitcharoo_NoteStringToValue(note_string)
    if note_value and not seen[note_value] then
      seen[note_value] = true
      table.insert(note_values, note_value)
      table.insert(PakettiSwitcharoo_audition_notes, note_value)
    end
  end
  
  if #note_values > 0 then
    song:trigger_instrument_note_on(selected_instrument_index, selected_track_index, note_values, 1.0)
  end
  
  PakettiSwitcharoo_UpdateUI()
end

-- Helper: place note-offs in all note columns of specified line
function PakettiSwitcharoo_PlaceNoteOffsAllColumns(line)
  -- Place note-offs in all visible note columns
  local max_cols = 12 -- Renoise max
  for i = 1, max_cols do
    local ncol = line:note_column(i)
    if not ncol.is_empty then -- Only clear non-empty columns
      ncol.note_string = "OFF"
      ncol.instrument_value = 255  -- Clear instrument
    end
  end
end

-- Switcharoo: Replace original chord with transformed version at original position
function PakettiSwitcharoo_DoSwitcharoo(slot_index)
  if slot_index < 1 or slot_index > #PakettiSwitcharoo_sequences then return end
  
  local song = renoise.song()
  local track = song.selected_track
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    renoise.app():show_status("PakettiSwitcharoo: Not a sequencer track")
    return
  end
  
  local transformed = PakettiSwitcharoo_transformed_sequences[slot_index]
  if not transformed or #transformed == 0 then return end
  
  -- Get the original line position where this chord was read from
  local original_line_index = PakettiSwitcharoo_original_line_positions[slot_index]
  if not original_line_index then
    renoise.app():show_status("PakettiSwitcharoo: No original position stored for slot " .. string.format("%02d", slot_index))
    return
  end
  
  -- Replace chord at its original position
  local patt = song:pattern(song.selected_pattern_index)
  local ptrack = patt:track(song.selected_track_index)
  local line = ptrack:line(original_line_index)
  
  -- Get original and new note counts for smart note-off logic
  local original_notes = PakettiSwitcharoo_sequences[slot_index]
  local original_count = original_notes and #original_notes or 0
  local transformed_count = #transformed
  
  -- Place note-offs in the line BEFORE if we're adding more notes than original
  if transformed_count > original_count and original_line_index > 1 then
    local prev_line = ptrack:line(original_line_index - 1)
    PakettiSwitcharoo_PlaceNoteOffsAllColumns(prev_line)
  end
  
  -- Clear existing notes in the original line
  local max_cols = math.min(12, #line.note_columns)
  for col_idx = 1, max_cols do
    line:note_column(col_idx):clear()
  end
  
  -- Ensure we have enough visible columns
  if track.visible_note_columns < transformed_count then
    track.visible_note_columns = math.min(12, transformed_count)
  end
  
  -- Write transformed notes to the original line
  for i, note_str in ipairs(transformed) do
    if i <= 12 then -- Renoise limit
      local ncol = line:note_column(i)
      ncol.note_string = note_str
      ncol.instrument_value = song.selected_instrument_index - 1
    end
  end
  
  -- Also place note-offs on the last pattern line to prevent endless sustain
  local last_line_index = patt.number_of_lines
  if last_line_index and last_line_index >= 1 and last_line_index ~= original_line_index then
    local last_line = ptrack:line(last_line_index)
    PakettiSwitcharoo_PlaceNoteOffsAllColumns(last_line)
  end
  
  renoise.app():show_status("PakettiSwitcharoo: Replaced chord in slot " .. string.format("%02d", slot_index) .. " at original line " .. tostring(original_line_index) .. " (" .. tostring(transformed_count) .. " notes)")
end

-- Update UI display
function PakettiSwitcharoo_UpdateUI()
  if not PakettiSwitcharoo_vb then return end
  
  -- Update all slot displays
  for i = 1, PakettiSwitcharoo_MAX_ROWS do
    -- Update original notes text
    if PakettiSwitcharoo_original_texts[i] then
      if i <= #PakettiSwitcharoo_sequences then
        local seq = PakettiSwitcharoo_sequences[i]
        PakettiSwitcharoo_original_texts[i].text = table.concat(seq, " ")
        if PakettiSwitcharoo_selected_slot == i then
          PakettiSwitcharoo_original_texts[i].style = "strong"
        else
          PakettiSwitcharoo_original_texts[i].style = "normal"
        end
      else
        PakettiSwitcharoo_original_texts[i].text = ""
        PakettiSwitcharoo_original_texts[i].style = "normal"
      end
    end
    
    -- Update resultant notes text
    if PakettiSwitcharoo_resultant_texts[i] then
      if i <= #PakettiSwitcharoo_transformed_sequences then
        local seq = PakettiSwitcharoo_transformed_sequences[i]
        PakettiSwitcharoo_resultant_texts[i].text = table.concat(seq, " ")
        if PakettiSwitcharoo_selected_slot == i then
          PakettiSwitcharoo_resultant_texts[i].style = "strong"
        else
          PakettiSwitcharoo_resultant_texts[i].style = "normal"
        end
      else
        PakettiSwitcharoo_resultant_texts[i].text = ""
        PakettiSwitcharoo_resultant_texts[i].style = "normal"
      end
    end
    
    -- Update control values
    if PakettiSwitcharoo_voicing_controls[i] then
      PakettiSwitcharoo_voicing_controls[i].value = PakettiSwitcharoo_voicing_values[i] or 0
    end
    if PakettiSwitcharoo_inversion_controls[i] then
      PakettiSwitcharoo_inversion_controls[i].value = PakettiSwitcharoo_inversion_values[i] or 0
    end
    if PakettiSwitcharoo_cof_controls[i] then
      PakettiSwitcharoo_cof_controls[i].value = PakettiSwitcharoo_circle_of_fifths_values[i] or 0
    end
    if PakettiSwitcharoo_complexity_controls[i] then
      PakettiSwitcharoo_complexity_controls[i].value = PakettiSwitcharoo_complexity_values[i] or 0
    end
    if PakettiSwitcharoo_min_octave_controls[i] then
      PakettiSwitcharoo_min_octave_controls[i].value = PakettiSwitcharoo_min_octave_values[i] or 0
    end
    if PakettiSwitcharoo_max_octave_controls[i] then
      PakettiSwitcharoo_max_octave_controls[i].value = PakettiSwitcharoo_max_octave_values[i] or 7
    end
    
    -- Update button states
    local has_content = (i <= #PakettiSwitcharoo_sequences)
    if PakettiSwitcharoo_audition_buttons[i] then
      PakettiSwitcharoo_audition_buttons[i].active = has_content
      if has_content then
        if PakettiSwitcharoo_current_audition_slot == i then
          PakettiSwitcharoo_audition_buttons[i].text = "Stop"
        else
          PakettiSwitcharoo_audition_buttons[i].text = "Aud"
        end
      else
        PakettiSwitcharoo_audition_buttons[i].text = "Aud"
      end
    end
    if PakettiSwitcharoo_switcharoo_buttons[i] then
      PakettiSwitcharoo_switcharoo_buttons[i].active = has_content
    end
  end
end

-- Key handler for navigation and control
function PakettiSwitcharoo_KeyHandler(dialog, key)
  if key and key.name == "up" then
    if PakettiSwitcharoo_selected_slot > 1 then
      PakettiSwitcharoo_selected_slot = PakettiSwitcharoo_selected_slot - 1
    end
    PakettiSwitcharoo_UpdateUI()
    return nil
  elseif key and key.name == "down" then
    local max_slot = math.min(PakettiSwitcharoo_MAX_ROWS, #PakettiSwitcharoo_sequences)
    if PakettiSwitcharoo_selected_slot < max_slot then
      PakettiSwitcharoo_selected_slot = PakettiSwitcharoo_selected_slot + 1
    end
    PakettiSwitcharoo_UpdateUI()
    return nil
  elseif key and key.name == "left" then
    -- Left arrow = always audition original (stop anything playing first)
    if PakettiSwitcharoo_selected_slot <= #PakettiSwitcharoo_sequences then
      -- If currently playing original for this slot, stop it
      if PakettiSwitcharoo_current_audition_slot == PakettiSwitcharoo_selected_slot and PakettiSwitcharoo_current_audition_type == "original" then
        PakettiSwitcharoo_AuditionStop()
      else
        -- Always play original (this will stop anything else first)
        PakettiSwitcharoo_AuditionOriginal(PakettiSwitcharoo_selected_slot)
      end
    end
    return nil
  elseif key and key.name == "right" then
    -- Right arrow = always audition transformed (stop anything playing first)
    if PakettiSwitcharoo_selected_slot <= #PakettiSwitcharoo_transformed_sequences then
      -- If currently playing transformed for this slot, stop it
      if PakettiSwitcharoo_current_audition_slot == PakettiSwitcharoo_selected_slot and PakettiSwitcharoo_current_audition_type == "transformed" then
        PakettiSwitcharoo_AuditionStop()
      else
        -- Always play transformed (this will stop anything else first)
        PakettiSwitcharoo_AuditionTransformed(PakettiSwitcharoo_selected_slot)
      end
    end
    return nil
  elseif key and key.name == "return" then
    -- Enter = switcharoo (replace)
    PakettiSwitcharoo_DoSwitcharoo(PakettiSwitcharoo_selected_slot)
    return nil
  elseif key and key.name == "escape" then
    PakettiSwitcharoo_AuditionStop()
    return nil
  elseif key and key.modifiers == "control" and key.name == "r" then
    -- Ctrl+R = Read from pattern
    PakettiSwitcharoo_ReadChordsFromPattern()
    return nil
  end
  
  -- Fallback to global handler
  return my_keyhandler_func(dialog, key)
end

-- Build UI row for a single slot
function PakettiSwitcharoo_BuildSlotRow(index)
  -- Slot number button
  local slot_btn = PakettiSwitcharoo_vb:button{
    text = string.format("%02d", index),
    width = 30,
    height = PakettiSwitcharoo_BUTTON_HEIGHT,
    notifier = function()
      PakettiSwitcharoo_selected_slot = index
      PakettiSwitcharoo_UpdateUI()
    end
  }
  
  -- Original notes display
  local original_text = PakettiSwitcharoo_vb:text{
    text = "",
    width = 300,
    style = "normal"
  }
  PakettiSwitcharoo_original_texts[index] = original_text
  
  -- Voicing control
  local voicing_control = PakettiSwitcharoo_vb:valuebox{
    min = -5,
    max = 5,
    value = 0,
    width = PakettiSwitcharoo_CONTROL_WIDTH,
    notifier = function(value)
      PakettiSwitcharoo_voicing_values[index] = value
      PakettiSwitcharoo_TransformSequence(index)
      PakettiSwitcharoo_UpdateUI()
    end
  }
  PakettiSwitcharoo_voicing_controls[index] = voicing_control
  
  -- Inversion control
  local inversion_control = PakettiSwitcharoo_vb:valuebox{
    min = -6,
    max = 6,
    value = 0,
    width = PakettiSwitcharoo_CONTROL_WIDTH,
    notifier = function(value)
      PakettiSwitcharoo_inversion_values[index] = value
      PakettiSwitcharoo_TransformSequence(index)
      PakettiSwitcharoo_UpdateUI()
    end
  }
  PakettiSwitcharoo_inversion_controls[index] = inversion_control
  
  -- Circle of Fifths control
  local cof_control = PakettiSwitcharoo_vb:valuebox{
    min = -6,
    max = 6,
    value = 0,
    width = PakettiSwitcharoo_CONTROL_WIDTH,
    notifier = function(value)
      PakettiSwitcharoo_circle_of_fifths_values[index] = value
      PakettiSwitcharoo_TransformSequence(index)
      PakettiSwitcharoo_UpdateUI()
    end
  }
  PakettiSwitcharoo_cof_controls[index] = cof_control
  
  -- Complexity control (intelligent chord extensions based on chord type)
  local complexity_control = PakettiSwitcharoo_vb:valuebox{
    min = 0,
    max = 12,
    value = 0,
    width = PakettiSwitcharoo_CONTROL_WIDTH,
    notifier = function(value)
      PakettiSwitcharoo_complexity_values[index] = value
      PakettiSwitcharoo_TransformSequence(index)
      PakettiSwitcharoo_UpdateUI()
    end
  }
  PakettiSwitcharoo_complexity_controls[index] = complexity_control
  
  -- Min Octave control
  local min_octave_control = PakettiSwitcharoo_vb:valuebox{
    min = 0,
    max = 9,
    value = 0,
    width = PakettiSwitcharoo_CONTROL_WIDTH,
    notifier = function(value)
      -- Ensure min <= max
      if value > (PakettiSwitcharoo_max_octave_values[index] or 7) then
        value = PakettiSwitcharoo_max_octave_values[index] or 7
        min_octave_control.value = value
      end
      PakettiSwitcharoo_min_octave_values[index] = value
      PakettiSwitcharoo_TransformSequence(index)
      PakettiSwitcharoo_UpdateUI()
    end
  }
  PakettiSwitcharoo_min_octave_controls[index] = min_octave_control
  
  -- Max Octave control
  local max_octave_control = PakettiSwitcharoo_vb:valuebox{
    min = 0,
    max = 9,
    value = 7,
    width = PakettiSwitcharoo_CONTROL_WIDTH,
    notifier = function(value)
      -- Ensure max >= min
      if value < (PakettiSwitcharoo_min_octave_values[index] or 0) then
        value = PakettiSwitcharoo_min_octave_values[index] or 0
        max_octave_control.value = value
      end
      PakettiSwitcharoo_max_octave_values[index] = value
      PakettiSwitcharoo_TransformSequence(index)
      PakettiSwitcharoo_UpdateUI()
    end
  }
  PakettiSwitcharoo_max_octave_controls[index] = max_octave_control
  
  -- Resultant notes display
  local resultant_text = PakettiSwitcharoo_vb:text{
    text = "",
    width = 300,
    style = "normal"
  }
  PakettiSwitcharoo_resultant_texts[index] = resultant_text
  
  -- Audition button
  local audition_btn = PakettiSwitcharoo_vb:button{
    text = "Aud",
    width = 35,
    height = PakettiSwitcharoo_BUTTON_HEIGHT,
    active = false,
    notifier = function()
      -- Toggle audition - if current slot is playing, stop; otherwise start transformed
      if PakettiSwitcharoo_current_audition_slot == index then
        PakettiSwitcharoo_AuditionStop()
      else
        PakettiSwitcharoo_AuditionTransformed(index)
      end
    end
  }
  PakettiSwitcharoo_audition_buttons[index] = audition_btn
  
  -- Switcharoo button
  local switcharoo_btn = PakettiSwitcharoo_vb:button{
    text = "Switch",
    width = 45,
    height = PakettiSwitcharoo_BUTTON_HEIGHT,
    active = false,
    notifier = function()
      PakettiSwitcharoo_DoSwitcharoo(index)
    end
  }
  PakettiSwitcharoo_switcharoo_buttons[index] = switcharoo_btn
  
  return PakettiSwitcharoo_vb:row{
    height = PakettiSwitcharoo_BUTTON_HEIGHT,
    slot_btn,
    PakettiSwitcharoo_vb:space{ width = 4 },
    original_text,
    PakettiSwitcharoo_vb:space{ width = 4 },
    voicing_control,
    PakettiSwitcharoo_vb:space{ width = 4 },
    inversion_control,
    PakettiSwitcharoo_vb:space{ width = 4 },
    cof_control,
    PakettiSwitcharoo_vb:space{ width = 4 },
    complexity_control,
    PakettiSwitcharoo_vb:space{ width = 4 },
    min_octave_control,
    PakettiSwitcharoo_vb:space{ width = 2 },
    max_octave_control,
    PakettiSwitcharoo_vb:space{ width = 4 },
    resultant_text,
    PakettiSwitcharoo_vb:space{ width = 4 },
    audition_btn,
    PakettiSwitcharoo_vb:space{ width = 2 },
    switcharoo_btn
  }
end

-- Create main dialog
function PakettiSwitcharoo_CreateDialog()
  if PakettiSwitcharoo_dialog and PakettiSwitcharoo_dialog.visible then
    PakettiSwitcharoo_dialog:close()
    PakettiSwitcharoo_dialog = nil
  end
  
  PakettiSwitcharoo_vb = renoise.ViewBuilder()
  
  -- Build all slot rows
  local slot_rows = {}
  for i = 1, PakettiSwitcharoo_MAX_ROWS do
    table.insert(slot_rows, PakettiSwitcharoo_BuildSlotRow(i))
  end
  
  -- Header row
  local header_row = PakettiSwitcharoo_vb:row{
    PakettiSwitcharoo_vb:text{ text = "Slot", width = 30, style = "strong", font = "bold" },
    PakettiSwitcharoo_vb:space{ width = 4 },
    PakettiSwitcharoo_vb:text{ text = "Original Notes", width = 300, style = "strong", font = "bold" },
    PakettiSwitcharoo_vb:space{ width = 4 },
    PakettiSwitcharoo_vb:text{ text = "Voice", width = PakettiSwitcharoo_CONTROL_WIDTH, style = "strong", font = "bold" },
    PakettiSwitcharoo_vb:space{ width = 4 },
    PakettiSwitcharoo_vb:text{ text = "Invert", width = PakettiSwitcharoo_CONTROL_WIDTH, style = "strong", font = "bold" },
    PakettiSwitcharoo_vb:space{ width = 4 },
    PakettiSwitcharoo_vb:text{ text = "CoF", width = PakettiSwitcharoo_CONTROL_WIDTH, style = "strong", font = "bold" },
    PakettiSwitcharoo_vb:space{ width = 4 },
    PakettiSwitcharoo_vb:text{ text = "Complex", width = PakettiSwitcharoo_CONTROL_WIDTH, style = "strong", font = "bold" },
    PakettiSwitcharoo_vb:space{ width = 4 },
    PakettiSwitcharoo_vb:text{ text = "Min", width = PakettiSwitcharoo_CONTROL_WIDTH, style = "strong", font = "bold" },
    PakettiSwitcharoo_vb:space{ width = 2 },
    PakettiSwitcharoo_vb:text{ text = "Max", width = PakettiSwitcharoo_CONTROL_WIDTH, style = "strong", font = "bold" },
    PakettiSwitcharoo_vb:space{ width = 4 },
    PakettiSwitcharoo_vb:text{ text = "Resultant Notes", width = 300, style = "strong", font = "bold" },
    PakettiSwitcharoo_vb:space{ width = 4 },
    PakettiSwitcharoo_vb:text{ text = "Actions", width = 82, style = "strong", font = "bold" }
  }
  
  local content = PakettiSwitcharoo_vb:column{
    PakettiSwitcharoo_vb:row{
      PakettiSwitcharoo_vb:button{
        text = "Read from Pattern (Ctrl+R)",
        width = 150,
        notifier = PakettiSwitcharoo_ReadChordsFromPattern
      },
      PakettiSwitcharoo_vb:button{
        text = "Reset All",
        width = 70,
        notifier = function()
          for i = 1, PakettiSwitcharoo_MAX_ROWS do
            PakettiSwitcharoo_InitializeSlot(i)
          end
          PakettiSwitcharoo_TransformAllSequences()
        end
      },
      PakettiSwitcharoo_vb:button{
        text = "Close",
        width = 50,
        notifier = function()
          PakettiSwitcharoo_AuditionStop()
          if PakettiSwitcharoo_dialog and PakettiSwitcharoo_dialog.visible then
            PakettiSwitcharoo_dialog:close()
          end
        end
      }
    },
    PakettiSwitcharoo_vb:space{ height = 4 },
    PakettiSwitcharoo_vb:text{
      text = "Navigation: Up/Down=select slot, Left=play original, Right=play processed, Enter=switcharoo, Esc=stop",
      style = "disabled"
    },
    PakettiSwitcharoo_vb:space{ height = 4 },
    header_row,
    PakettiSwitcharoo_vb:space{ height = 2 },
    unpack(slot_rows)
  }
  
  PakettiSwitcharoo_dialog = renoise.app():show_custom_dialog("Paketti Switcharoo - Advanced Chord Reharmonization", content, PakettiSwitcharoo_KeyHandler)
  PakettiSwitcharoo_UpdateUI()
  
  -- Ensure Renoise keeps focus for keyboard
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  -- Auto-grab chords if preference is enabled
  if preferences and preferences.pakettiSwitcharooAutoGrab and preferences.pakettiSwitcharooAutoGrab.value then
    PakettiSwitcharoo_ReadChordsFromPattern()
  end
  
  -- Show help info
  renoise.app():show_status("PakettiSwitcharoo: Ctrl+R=read pattern, Up/Down=navigate, Left=play original, Right=play processed")
end

-- Toggle dialog
function PakettiSwitcharoo_Toggle()
  if PakettiSwitcharoo_dialog and PakettiSwitcharoo_dialog.visible then
    PakettiSwitcharoo_AuditionStop()
    PakettiSwitcharoo_dialog:close()
    PakettiSwitcharoo_dialog = nil
  else
    PakettiSwitcharoo_CreateDialog()
  end
end

-- Initialize all transformation values on startup
for i = 1, PakettiSwitcharoo_MAX_ROWS do
  PakettiSwitcharoo_InitializeSlot(i)
end

-- Menu entries and keybinding
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti Switcharoo...", invoke = PakettiSwitcharoo_Toggle}
renoise.tool():add_menu_entry{name = "--Pattern Editor:Paketti Gadgets:Paketti Switcharoo...", invoke = PakettiSwitcharoo_Toggle}
renoise.tool():add_keybinding{name = "Global:Paketti:Paketti Switcharoo...", invoke = PakettiSwitcharoo_Toggle}
