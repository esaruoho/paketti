function JalexAdd(number)
    if renoise.song().selected_note_column_index == renoise.song().selected_track.visible_note_columns then 
    if renoise.song().selected_track.visible_note_columns == 12 then 
    renoise.song().selected_line_index=renoise.song().selected_line_index+1
    renoise.song().selected_note_column_index = 1
    renoise.song()
    return
    end
    
    renoise.song().selected_track.visible_note_columns = renoise.song().selected_track.visible_note_columns+1 
    end
    
    local originalNote=renoise.song().selected_note_column.note_value
    local originalInstrument=renoise.song().selected_note_column.instrument_value
    local originalVolume = renoise.song().selected_note_column.volume_value
    
    if originalNote >= 120 then 
        renoise.app():show_status("You are not on a note.")
        return 
    end
    
    if originalNote + number > 119 then
        renoise.app():show_status("Cannot go higher than B-9.") 
        return 
    end
    
    if originalNote + number < 0 then
        renoise.app():show_status("Cannot go lower than C-0.") 
        return 
    end

    renoise.song().selected_pattern.tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[renoise.song().selected_note_column_index + 1].note_value = originalNote + number
    renoise.song().selected_pattern.tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[renoise.song().selected_note_column_index + 1].instrument_value = originalInstrument
    renoise.song().selected_pattern.tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[renoise.song().selected_note_column_index + 1].volume_value = originalVolume
    
    renoise.song().selected_note_column_index = renoise.song().selected_note_column_index +1
    end
    
    for i=1,12 do
      renoise.tool():add_keybinding{name=string.format("Pattern Editor:Paketti:Chordsplus (Add %02d)", i),invoke=function() JalexAdd(i) end}
      renoise.tool():add_keybinding{name=string.format("Pattern Editor:Paketti:ChordsPlus (Sub %02d)", i),invoke=function() JalexAdd(-i) end}
    end
    

    function chordsplus(number1, number2, number3, number4, number5, number6)
        -- Check if there's a valid note (notes are 0-119, 120 is OFF, 121 is ---)
        if renoise.song().selected_note_column.note_value >= 120 then
            renoise.app():show_status("There is no basenote to start with, doing nothing.")
            return
        end

        -- Get the base note information
        local basenote = renoise.song().selected_note_column.note_value
        local basenote_name = renoise.song().selected_note_column.note_string
        local status_msg = string.format("Basenote: %s (%d)", basenote_name, basenote)
        
        -- Process number1 using JalexAdd
        JalexAdd(number1)
        local note1_col = renoise.song().selected_pattern.tracks[renoise.song().selected_track_index]
                     .lines[renoise.song().selected_line_index].note_columns[2]
        if note1_col.note_value < 120 then
            status_msg = status_msg .. string.format(" → +%d %s (%d)", number1, note1_col.note_string, note1_col.note_value)
        end
        
        -- Process number2
        if number2 == nil then
            wipeNoteColumn(3)
            wipeNoteColumn(4)
            wipeNoteColumn(5)
            wipeNoteColumn(6)
            wipeNoteColumn(7)
            renoise.song().selected_note_column_index = 1
            renoise.app():show_status(status_msg)
            return
        else
            JalexAdd(number2)
            local note2_col = renoise.song().selected_pattern.tracks[renoise.song().selected_track_index]
                         .lines[renoise.song().selected_line_index].note_columns[3]
            if note2_col.note_value < 120 then
                status_msg = status_msg .. string.format(" → +%d %s (%d)", number2, note2_col.note_string, note2_col.note_value)
            end
        end
        
        -- Process number3
        if number3 == nil then
            wipeNoteColumn(4)
            wipeNoteColumn(5)
            wipeNoteColumn(6)
            wipeNoteColumn(7)
            renoise.song().selected_note_column_index = 1
            renoise.app():show_status(status_msg)
            return
        else
            JalexAdd(number3)
            local note3_col = renoise.song().selected_pattern.tracks[renoise.song().selected_track_index]
                         .lines[renoise.song().selected_line_index].note_columns[4]
            if note3_col.note_value < 120 then
                status_msg = status_msg .. string.format(" → +%d %s (%d)", number3, note3_col.note_string, note3_col.note_value)
            end
        end
        
        -- Process number4
        if number4 == nil then
            wipeNoteColumn(5)
            wipeNoteColumn(6)
            wipeNoteColumn(7)
            renoise.song().selected_note_column_index = 1
            renoise.app():show_status(status_msg)
            return
        else
            JalexAdd(number4)
            local note4_col = renoise.song().selected_pattern.tracks[renoise.song().selected_track_index]
                         .lines[renoise.song().selected_line_index].note_columns[5]
            if note4_col.note_value < 120 then
                status_msg = status_msg .. string.format(" → +%d %s (%d)", number4, note4_col.note_string, note4_col.note_value)
            end
        end
        
        -- Process number5
        if number5 == nil then
            wipeNoteColumn(6)
            wipeNoteColumn(7)
            renoise.song().selected_note_column_index = 1
            renoise.app():show_status(status_msg)
            return
        else
            JalexAdd(number5)
            local note5_col = renoise.song().selected_pattern.tracks[renoise.song().selected_track_index]
                         .lines[renoise.song().selected_line_index].note_columns[6]
            if note5_col.note_value < 120 then
                status_msg = status_msg .. string.format(" → +%d %s (%d)", number5, note5_col.note_string, note5_col.note_value)
            end
        end
        
        -- Process number6
        if number6 == nil then
            wipeNoteColumn(7)
            wipeNoteColumn(8)
            renoise.song().selected_note_column_index = 1
            renoise.app():show_status(status_msg)
            return
        else
            JalexAdd(number6)
            local note6_col = renoise.song().selected_pattern.tracks[renoise.song().selected_track_index]
                         .lines[renoise.song().selected_line_index].note_columns[7]
            if note6_col.note_value < 120 then
                status_msg = status_msg .. string.format(" → +%d %s (%d)", number6, note6_col.note_string, note6_col.note_value)
            end
        end
        
        -- Show the final status message and reset column index
        renoise.app():show_status(status_msg)
        renoise.song().selected_note_column_index = 1
    end
      
    -- List of chord progressions, reordered logically
    local chord_list = {
        {name="ChordsPlus 3-4 (Maj)", fn=function() chordsplus(4,3) end},
        {name="ChordsPlus 4-3 (Min)", fn=function() chordsplus(3,4) end},
        {name="ChordsPlus 4-3-4 (Maj7)", fn=function() chordsplus(4,3,4) end},
        {name="ChordsPlus 3-4-3 (Min7)", fn=function() chordsplus(3,4,3) end},
        {name="ChordsPlus 4-4-3 (Maj7+5)", fn=function() chordsplus(4,4,3) end},
        {name="ChordsPlus 3-5-2 (Min7+5)", fn=function() chordsplus(3,5,2) end},
        {name="ChordsPlus 4-3-3 (Maj Dominant 7th)", fn=function() chordsplus(4,3,3) end}, -- MajMajor7
        {name="ChordsPlus 3-4-4 (MinMaj7)", fn=function() chordsplus(3,4,4) end}, -- MinorMajor7
        {name="ChordsPlus 4-3-4-3 (Maj9)", fn=function() chordsplus(4,3,4,3) end},
        {name="ChordsPlus 3-4-3-3 (Min9)", fn=function() chordsplus(3,4,3,3) end},
        {name="ChordsPlus 4-3-7 (Maj Added 9th)", fn=function() chordsplus(4,3,7) end},
        {name="ChordsPlus 3-4-7 (Min Added 9th)", fn=function() chordsplus(3,4,7) end},
        {name="ChordsPlus 4-7-3 (Maj9 Simplified)", fn=function() chordsplus(4,7,3) end}, -- Maj9 without 5th
        {name="ChordsPlus 3-7-4 (Min9 Simplified)", fn=function() chordsplus(3,7,4) end}, -- Min9 without 5th
        {name="ChordsPlus 3-8-3 (mM9 Simplified)", fn=function() chordsplus(3,8,3) end}, -- MinorMajor9 without 5th
        {name="ChordsPlus 4-3-4-4 (MM9)", fn=function() chordsplus(4,3,4,4) end}, -- MajorMajor9 with Augmented 9th
        {name="ChordsPlus 3-4-4-3 (mM9)", fn=function() chordsplus(3,4,4,3) end}, -- MinorMajor9
        {name="ChordsPlus 4-3-2-5 (Maj6 Add9)", fn=function() chordsplus(4,3,2,5) end}, -- Maj6 Add9
        {name="ChordsPlus 3-4-2-5 (Min6 Add9)", fn=function() chordsplus(3,4,2,5) end}, -- Min6 Add9
        {name="ChordsPlus 4-3-4-3-3 (Maj9 Add11)", fn=function() chordsplus(4,3,4,3,3) end},
        {name="ChordsPlus 2-5 (Sus2)", fn=function() chordsplus(2,5) end},
        {name="ChordsPlus 5-2 (Sus4)", fn=function() chordsplus(5,2) end},
        {name="ChordsPlus 5-2-3 (7Sus4)", fn=function() chordsplus(5,2,3) end},
        {name="ChordsPlus 4-4 (Aug5)", fn=function() chordsplus(4,4) end},
        {name="ChordsPlus 4-4-2 (Aug6)", fn=function() chordsplus(4,4,2) end},
        {name="ChordsPlus 4-4-3 (Aug7)", fn=function() chordsplus(4,4,3) end},
        {name="ChordsPlus 4-4-4 (Aug8)", fn=function() chordsplus(4,4,4) end},  
        {name="ChordsPlus 4-3-3-5 (Aug9)", fn=function() chordsplus(4,3,3,5) end},
        {name="ChordsPlus 4-4-7 (Aug10)", fn=function() chordsplus(4,4,7) end},
        {name="ChordsPlus 4-3-3-4-4 (Aug11)", fn=function() chordsplus(4,3,3,4,4) end},
        {name="ChordsPlus 12-12-12 (Octaves)", fn=function() chordsplus(12,12,12) end}
    }
    
    local current_chord_index = 1 -- Start at the first chord
    
    -- Function to advance to the next chord in the list
    function next_chord()
        chord_list[current_chord_index].fn() -- Invoke the current chord function
        renoise.app():show_status("Played: " .. chord_list[current_chord_index].name)
        current_chord_index = current_chord_index + 1
        if current_chord_index > #chord_list then
            current_chord_index = 1 -- Wrap back to the first chord
        end
    end
    
    function previous_chord()
        current_chord_index = current_chord_index - 2 -- Go back two steps since next_chord() will add one
        if current_chord_index < 0 then
            current_chord_index = #chord_list - 1 -- Wrap to end of list
        end
        next_chord() -- Use existing next_chord to play and advance
    end

    function midi_chord_mapping(value)
        if renoise.song().selected_track.visible_note_columns ~=  0 then
            local chord_index = math.floor((value / 127) * (#chord_list - 1)) + 1
            if renoise.song().selected_pattern.tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[renoise.song().selected_note_column_index].is_empty
            then renoise.app():show_status("There was no note, doing nothing.")
            return
            end
          
            chord_list[chord_index].fn()
            renoise.app():show_status("Set Basenote and Intervals to: " .. chord_list[chord_index].name)
        else
            renoise.app():show_status("This track does not have a Note Column. Doing nothing.")
        end
        
    end
    
  
    for i, chord in ipairs(chord_list) do
        renoise.tool():add_keybinding{name="Pattern Editor:Paketti:" .. chord.name,invoke=chord.fn}
    end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Next Chord in List",invoke=next_chord}
renoise.tool():add_midi_mapping{name="Paketti:Chord Selector [0-127]",invoke=function(midi_message) midi_chord_mapping(midi_message.int_value) end}

-------

-- Helper function to get all notes from a row and sort them
function GetAndSortNotes(line, ascending)
  local notes = {}
  local song=renoise.song()
  local track = song.selected_track
  
  -- First, detect if we have a delay pattern
  local has_delay_pattern = false
  local first_delay = line.note_columns[1].delay_value
  for col_idx = 2, track.visible_note_columns do
      local note_col = line.note_columns[col_idx]
      if not note_col.is_empty and note_col.delay_value ~= first_delay then
          has_delay_pattern = true
          break
      end
  end
  
  -- Collect all non-empty notes from the row
  for col_idx = 1, track.visible_note_columns do
      local note_col = line.note_columns[col_idx]
      if not note_col.is_empty then
          table.insert(notes, {
              note_value = note_col.note_value,
              instrument_value = note_col.instrument_value,
              volume_value = note_col.volume_value,
              panning_value = note_col.panning_value,
              delay_value = note_col.delay_value,
              original_column = col_idx,
              is_noteoff = (note_col.note_value == 120)
          })
      end
  end

  -- Separate notes and NOTE_OFFs
  local regular_notes = {}
  local noteoffs = {}
  for _, note in ipairs(notes) do
      if note.is_noteoff then
          table.insert(noteoffs, note)
      else
          table.insert(regular_notes, note)
      end
  end

  -- If we have a delay pattern, sort notes but keep original delay values
  if has_delay_pattern then
      -- Create a mapping of original positions to delay values
      local delay_map = {}
      for _, note in ipairs(notes) do
          if not note.is_noteoff then
              delay_map[#delay_map + 1] = note.delay_value
          end
      end

      -- Sort only the regular notes
      if ascending then
          table.sort(regular_notes, function(a, b) return a.note_value < b.note_value end)
      else
          table.sort(regular_notes, function(a, b) return a.note_value > b.note_value end)
      end

      -- Reassign delay values in original order
      for i, note in ipairs(regular_notes) do
          note.delay_value = delay_map[i]
      end
  else
      -- Normal sorting without delay consideration
      if ascending then
          table.sort(regular_notes, function(a, b) return a.note_value < b.note_value end)
      else
          table.sort(regular_notes, function(a, b) return a.note_value > b.note_value end)
      end
  end

  -- Put NOTE_OFFs back in their original positions
  local result = {}
  local note_idx = 1
  for i = 1, #notes do
      local found_noteoff = false
      for _, noteoff in ipairs(noteoffs) do
          if noteoff.original_column == i then
              table.insert(result, noteoff)
              found_noteoff = true
              break
          end
      end
      if not found_noteoff and note_idx <= #regular_notes then
          table.insert(result, regular_notes[note_idx])
          note_idx = note_idx + 1
      end
  end

  return result
end

  
  -- Function to sort notes in ascending order (lowest to highest)
function NoteSorterAscending()
  local song=renoise.song()
  local track = song.selected_track
  local pattern = song.selected_pattern
  local selection = song.selection_in_pattern
  
  -- Determine start and end lines
  local start_line, end_line
  if selection then
      start_line = selection.start_line
      end_line = selection.end_line
  else
      start_line = song.selected_line_index
      end_line = song.selected_line_index
  end
  
  -- Process each line in the range
  for line_idx = start_line, end_line do
      local line = pattern.tracks[song.selected_track_index]:line(line_idx)
      
      -- Get sorted notes for this line
      local sorted_notes = GetAndSortNotes(line, true)
      
      -- Only process if there are notes to sort
      if #sorted_notes > 0 then
          -- Clear all note columns first
          for col_idx = 1, track.visible_note_columns do
              line.note_columns[col_idx]:clear()
          end
          
          -- Place sorted notes back into columns
          for i, note in ipairs(sorted_notes) do
              local target_col = line.note_columns[i]
              target_col.note_value = note.note_value
              target_col.instrument_value = note.instrument_value
              target_col.volume_value = note.volume_value
              target_col.panning_value = note.panning_value
              target_col.delay_value = note.delay_value
          end
      end
  end
  
  renoise.app():show_status(selection and "Selection sorted in ascending order" or "Notes sorted in ascending order")
end

-- Function to sort notes in descending order (highest to lowest)
function NoteSorterDescending()
  local song=renoise.song()
  local track = song.selected_track
  local pattern = song.selected_pattern
  local selection = song.selection_in_pattern
  
  -- Determine start and end lines
  local start_line, end_line
  if selection then
      start_line = selection.start_line
      end_line = selection.end_line
  else
      start_line = song.selected_line_index
      end_line = song.selected_line_index
  end
  
  -- Process each line in the range
  for line_idx = start_line, end_line do
      local line = pattern.tracks[song.selected_track_index]:line(line_idx)
      
      -- Get sorted notes for this line
      local sorted_notes = GetAndSortNotes(line, false)
      
      -- Only process if there are notes to sort
      if #sorted_notes > 0 then
          -- Clear all note columns first
          for col_idx = 1, track.visible_note_columns do
              line.note_columns[col_idx]:clear()
          end
          
          -- Place sorted notes back into columns
          for i, note in ipairs(sorted_notes) do
              local target_col = line.note_columns[i]
              target_col.note_value = note.note_value
              target_col.instrument_value = note.instrument_value
              target_col.volume_value = note.volume_value
              target_col.panning_value = note.panning_value
              target_col.delay_value = note.delay_value
          end
      end
  end
  
  renoise.app():show_status(selection and "Selection sorted in descending order" or "Notes sorted in descending order")
end

  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Note Sorter (Ascending)",invoke=NoteSorterAscending}
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Note Sorter (Descending)",invoke=NoteSorterDescending}
---  
  function RandomizeVoicing()
    local song=renoise.song()
    local track = song.selected_track
    local pattern = song.selected_pattern
    local selection = song.selection_in_pattern
    local adjustments = {-24, -12, 12, 24} -- Octave shifts:  -2, -1, +1, +2

    -- Determine start and end lines
    local start_line, end_line
    if selection then
        start_line = selection.start_line
        end_line = selection.end_line
    else
        start_line = song.selected_line_index
        end_line = song.selected_line_index
    end

    -- Process each line in the range
    for line_idx = start_line, end_line do
        local line = pattern.tracks[song.selected_track_index]:line(line_idx)
        local count = track.visible_note_columns
        local found_notes = false
        local note_changes = {}

        for i = 1, count do
            local note = line.note_columns[i]
            if not note.is_empty and note.note_string ~= "OFF" and note.note_string ~= "---" then
                found_notes = true
                -- Store original note
                local original_note = note.note_string
                
                -- Pick a random adjustment and apply it to the note_value
                local adjustment = adjustments[math.random(#adjustments)]
                local new_value = note.note_value + adjustment
                
                -- Ensure new_value is within the valid note range (C-1 to B-9)
                new_value = math.max(0, math.min(119, new_value))
                
                -- Update the note value
                note.note_value = new_value
                                
                -- Store the change
                table.insert(note_changes, {
                    original = original_note,
                    new = note.note_string
                })
            end
        end

        -- Show status message for the current line if notes were found
        if found_notes then
            -- Build status message
            local original_notes = {}
            local new_notes = {}
            for _, change in ipairs(note_changes) do
                table.insert(original_notes, change.original)
                table.insert(new_notes, change.new)
            end
            
            local msg
            if selection then
                msg = string.format("Line %d: (%s) → (%s)", 
                    line_idx,
                    table.concat(original_notes, " "),
                    table.concat(new_notes, " "))
            else
                msg = string.format("Original Notes (%s) Randomized to (%s)",
                    table.concat(original_notes, " "),
                    table.concat(new_notes, " "))
            end
            renoise.app():show_status(msg)
        elseif not selection then
            -- Only show "no notes" message if working on a single line
            renoise.app():show_status("There were no notes on this row, doing nothing.")
        end
    end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Randomize Voicing for Notes in Row/Selection",invoke=function() RandomizeVoicing() end}
renoise.tool():add_midi_mapping{name="Paketti:Randomize Voicing for Notes in Row/Selection",invoke=function() RandomizeVoicing() end}

---
  -- Function to shift notes left or right
  function ShiftNotes(direction)
    local song=renoise.song()
    local track = song.selected_track
    local pattern = song.selected_pattern
    local selection = song.selection_in_pattern
    
    -- Determine if we're working with a selection or single line
    local start_line, end_line
    if selection then
      start_line = selection.start_line
      end_line = selection.end_line
  
      -- For selections moving left, check ALL rows first
      if direction < 0 then
        for line_idx = start_line, end_line do
          local line = pattern.tracks[song.selected_track_index]:line(line_idx)
          -- Check if any notes exist in the first column
          if not line.note_columns[1].is_empty then
            renoise.app():show_status("Cannot shift selection left: notes present in first column")
            return
          end
        end
      end
    else
      start_line = song.selected_line_index
      end_line = song.selected_line_index
    end
  
    -- Process each line in the range
    for line_idx = start_line, end_line do
      local line = pattern.tracks[song.selected_track_index]:line(line_idx)
      
      -- Find the leftmost and rightmost used note columns
      local leftmost_used = nil
      local rightmost_used = 0
      for col_idx = 1, track.visible_note_columns do
        if not line.note_columns[col_idx].is_empty then
          if not leftmost_used then leftmost_used = col_idx end
          rightmost_used = col_idx
        end
      end
  
      -- Only process lines that have notes
      if leftmost_used then
        -- Check shift direction constraints
        if direction < 0 then -- Shifting left
          if not selection and leftmost_used == 1 then
            -- For single line, check if we can't move left
            renoise.app():show_status("Cannot shift notes left: notes present in first column")
            return
          end
        else -- Shifting right
          if rightmost_used == 12 then
            renoise.app():show_status("Cannot shift notes right: all columns used")
            return
          end
          -- If we need more visible columns and we're not at max
          if rightmost_used == track.visible_note_columns and track.visible_note_columns < 12 then
            track.visible_note_columns = track.visible_note_columns + 1
          end
        end
  
        -- Perform the shift
        if direction < 0 then
          -- Shift left: start from leftmost used column
          for col_idx = leftmost_used, rightmost_used do
            local source_col = line.note_columns[col_idx]
            local target_col = line.note_columns[col_idx - 1]
            
            target_col.note_value = source_col.note_value
            target_col.instrument_value = source_col.instrument_value
            target_col.volume_value = source_col.volume_value
            target_col.panning_value = source_col.panning_value
            target_col.delay_value = source_col.delay_value
  
            -- Debug print to verify NOTE OFF handling
            if source_col.note_value == 120 then
              print(string.format("Line %d: Shifting NOTE OFF from column %d to %d", 
                line_idx, col_idx, col_idx - 1))
            end
          end
          -- Clear the rightmost used column
          line.note_columns[rightmost_used]:clear()
          
        else
          -- Shift right: start from rightmost used column
          for col_idx = rightmost_used, leftmost_used, -1 do
            local source_col = line.note_columns[col_idx]
            local target_col = line.note_columns[col_idx + 1]
            
            target_col.note_value = source_col.note_value
            target_col.instrument_value = source_col.instrument_value
            target_col.volume_value = source_col.volume_value
            target_col.panning_value = source_col.panning_value
            target_col.delay_value = source_col.delay_value
  
            -- Debug print to verify NOTE OFF handling
            if source_col.note_value == 120 then
              print(string.format("Line %d: Shifting NOTE OFF from column %d to %d", 
                line_idx, col_idx, col_idx + 1))
            end
          end
          -- Clear the first column
          line.note_columns[leftmost_used]:clear()
        end
      end
    end
  
    -- Set cursor position and show status
    if direction < 0 then
      song.selected_note_column_index = 1
      renoise.app():show_status(selection and "Selection shifted left" or "Notes shifted left")
    else
      song.selected_note_column_index = 1
      renoise.app():show_status(selection and "Selection shifted right" or "Notes shifted right")
    end
  end
  
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Shift Notes Right",invoke=function() ShiftNotes(1) end}
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Shift Notes Left",invoke=function() ShiftNotes(-1) end}
  
  

--------

function cycle_inversion(direction)
  local song=renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.tracks[track_index]
  local selection = song.selection_in_pattern

  if selection then
    -- If there is a selection, process each row separately
    for line_index = selection.start_line, selection.end_line do
      process_row_inversion(pattern, track_index, line_index, selection.start_column, selection.end_column, direction)
    end
  else
    -- No selection? Process only the current row at the cursor position
    local line_index = song.selected_line_index
    process_row_inversion(pattern, track_index, line_index, 1, track.visible_note_columns, direction)
  end

  -- Return focus to pattern editor
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  renoise.app():show_status("Chord inversion cycled.")
end

function process_row_inversion(pattern, track_index, line_index, start_col, end_col, direction)
  local line = pattern:track(track_index):line(line_index)
  local notes = {}

  -- Collect all valid notes in the given column range
  for col = start_col, end_col do
    local note_column = line:note_column(col)
    if note_column and note_column.note_value < 120 then -- Ignore empty or OFF notes
      table.insert(notes, {value=note_column.note_value, column=col})
    end
  end

  if #notes < 2 or #notes > 12 then
    return -- Skip rows that don't have enough notes
  end

  -- Sort notes by pitch
  table.sort(notes, function(a, b) return a.value < b.value end)

  if direction == "up" then
    -- Move the lowest note up an octave
    local lowest_note = notes[1]
    lowest_note.value = lowest_note.value + 12

    if lowest_note.value > 119 then
      return -- Skip inversion if out of MIDI range
    end
  elseif direction == "down" then
    -- Move the highest note down an octave
    local highest_note = notes[#notes]
    highest_note.value = highest_note.value - 12

    if highest_note.value < 0 then
      return -- Skip inversion if out of MIDI range
    end
  end

  -- Apply the inversion for this row
  for _, note in ipairs(notes) do
    line:note_column(note.column).note_value = note.value
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Cycle Chord Inversion Up",invoke=function() cycle_inversion("up") NoteSorterAscending() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Cycle Chord Inversion Down",invoke=function() cycle_inversion("down") NoteSorterAscending() end}
  -- Function to apply a random chord from the chord_list
function RandomChord()
  local song=renoise.song()
  
  -- Check if we have a selected note column
  if not song.selected_note_column then
      renoise.app():show_status("No note column selected, doing nothing.")
      return
  end
  
  -- Check if we're on a valid note
  if song.selected_note_column.note_value >= 120 then
      renoise.app():show_status("There is no basenote to start with, doing nothing.")
      return
  end
  
  -- Check if track has note columns
  if song.selected_track.visible_note_columns == 0 then
      renoise.app():show_status("This track does not have a Note Column. Doing nothing.")
      return
  end
  
  -- Select a random chord from chord_list
  local random_index = math.random(#chord_list)
  local selected_chord = chord_list[random_index]
  
  -- Apply the chord
  selected_chord.fn()
  
  -- Show what chord was selected
  renoise.app():show_status("Random Chord: " .. selected_chord.name)
  print("Random Chord: " .. selected_chord.name)
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Random Chord",invoke=function() RandomChord() end}
renoise.tool():add_midi_mapping{name="Paketti:ChordsPlus Random Chord",invoke=function(message) if message:is_trigger() then RandomChord() end end}


function ExtractBassline()
  local song=renoise.song()
  local pattern = song.selected_pattern
  local source_track_index = song.selected_track_index
  
  -- Create a new track after the current one
  song:insert_track_at(source_track_index + 1)
  local dest_track_index = source_track_index + 1
  
  -- Set up the new track
  local dest_track = song:track(dest_track_index)
  dest_track.name = song:track(source_track_index).name .. " Bass"
  dest_track.visible_note_columns = 1  -- Only need one column for bassline
  
  local source_track = pattern:track(source_track_index)
  local dest_pattern_track = pattern:track(dest_track_index)
  local visible_note_columns = song:track(source_track_index).visible_note_columns
  local changes_made = false
  
  -- Process each line in the pattern
  for line_index = 1, pattern.number_of_lines do
    local line = source_track:line(line_index)
    local lowest_note = nil
    local lowest_note_data = nil
    
    -- Find lowest note in this row across all note columns
    for column_index = 1, visible_note_columns do
      local note_column = line:note_column(column_index)
      
      -- Only process actual notes (skip empty notes and note-offs)
      if not note_column.is_empty and note_column.note_string ~= "OFF" then
        if lowest_note == nil or note_column.note_value < lowest_note then
          lowest_note = note_column.note_value
          lowest_note_data = {
            note_value = note_column.note_value,
            instrument_value = note_column.instrument_value,
            volume_value = note_column.volume_value,
            panning_value = note_column.panning_value,
            delay_value = note_column.delay_value
          }
        end
      end
    end
    
    -- If we found a lowest note, copy it to the destination track
    if lowest_note_data then
      local dest_note_column = dest_pattern_track:line(line_index):note_column(1)
      dest_note_column.note_value = lowest_note_data.note_value
      dest_note_column.instrument_value = lowest_note_data.instrument_value
      dest_note_column.volume_value = lowest_note_data.volume_value
      dest_note_column.panning_value = lowest_note_data.panning_value
      dest_note_column.delay_value = lowest_note_data.delay_value
      changes_made = true
    end
  end
  
  if changes_made then
    renoise.app():show_status("Bassline extracted to new track " .. dest_track_index)
  else
    renoise.app():show_status("No notes found to extract")
  end
  renoise.song().selected_track_index = dest_track_index
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Extract Bassline to New Track",invoke=function() ExtractBassline() end}

  function ExtractHighestNote()
    local song=renoise.song()
    local pattern = song.selected_pattern
    local source_track_index = song.selected_track_index
    
    -- Create a new track after the current one
    song:insert_track_at(source_track_index + 1)
    local dest_track_index = source_track_index + 1
    
    -- Set up the new track
    local dest_track = song:track(dest_track_index)
    dest_track.name = song:track(source_track_index).name .. " High"
    dest_track.visible_note_columns = 1  -- Only need one column for highest notes
    
    local source_track = pattern:track(source_track_index)
    local dest_pattern_track = pattern:track(dest_track_index)
    local visible_note_columns = song:track(source_track_index).visible_note_columns
    local changes_made = false
    
    -- Process each line in the pattern
    for line_index = 1, pattern.number_of_lines do
      local line = source_track:line(line_index)
      local highest_note = nil
      local highest_note_data = nil
      
      -- Find highest note in this row across all note columns
      for column_index = 1, visible_note_columns do
        local note_column = line:note_column(column_index)
        
        -- Only process actual notes (skip empty notes and note-offs)
        if not note_column.is_empty and note_column.note_string ~= "OFF" then
          if highest_note == nil or note_column.note_value > highest_note then
            highest_note = note_column.note_value
            highest_note_data = {
              note_value = note_column.note_value,
              instrument_value = note_column.instrument_value,
              volume_value = note_column.volume_value,
              panning_value = note_column.panning_value,
              delay_value = note_column.delay_value
            }
          end
        end
      end
      
      -- If we found a highest note, copy it to the destination track
      if highest_note_data then
        local dest_note_column = dest_pattern_track:line(line_index):note_column(1)
        dest_note_column.note_value = highest_note_data.note_value
        dest_note_column.instrument_value = highest_note_data.instrument_value
        dest_note_column.volume_value = highest_note_data.volume_value
        dest_note_column.panning_value = highest_note_data.panning_value
        dest_note_column.delay_value = highest_note_data.delay_value
        changes_made = true
      end
    end
    
    if changes_made then
      renoise.app():show_status("Highest notes extracted to new track " .. dest_track_index)
    else
      renoise.app():show_status("No notes found to extract")
    end
    renoise.song().selected_track_index = dest_track_index
  end
  
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Extract Highest Note to New Track",invoke=function() ExtractHighestNote() end}
--------------------------------------------------------------------------------
-- DuplicateSpecificNotesToNewTrack(note_type, instrument_mode)
--
-- note_type: one of "highest" or "lowest"
-- instrument_mode: one of "duplicate", "selected", or "original"
--
-- The function duplicates the current track and its instrument (or uses the
-- selected/original instrument), copies all DSP devices (using your clean-duplication
-- code that starts at device index 2 to avoid the vol/pan device), handles the 
-- special *Instr. Automation device by updating its XML, and then in the duplicated 
-- track extracts either the highest or lowest note from each line.
--------------------------------------------------------------------------------
function DuplicateSpecificNotesToNewTrack(note_type, instrument_mode)
  local song=renoise.song()
  local pattern = song.selected_pattern
  local source_track_index = song.selected_track_index
  local source_track = song:track(source_track_index)

  ------------------------------------------------------------------------------
  -- PART 1: Determine which instrument to use
  ------------------------------------------------------------------------------
  local final_instrument_index = nil  -- 1-based instrument index that will be used
  local external_editor_open = false
  local instrument_was_duplicated = false

  if instrument_mode == "duplicate" then
    -- Duplicate the currently selected instrument.
    local instrument_index = song.selected_instrument_index or 1
    local original_instrument = song.instruments[instrument_index]
    if original_instrument.plugin_properties 
       and original_instrument.plugin_properties.plugin_device then
      if original_instrument.plugin_properties.plugin_device.external_editor_visible then
        external_editor_open = true
        original_instrument.plugin_properties.plugin_device.external_editor_visible = false
      end
    end
    if not safeInsertInstrumentAt(song, instrument_index + 1) then return end
    final_instrument_index = instrument_index + 1
    local new_instrument = song.instruments[final_instrument_index]
    new_instrument:copy_from(original_instrument)
    if #original_instrument.phrases > 0 then
      for phrase_index = 1, #original_instrument.phrases do
        new_instrument:insert_phrase_at(phrase_index)
        new_instrument.phrases[phrase_index]:copy_from(original_instrument.phrases[phrase_index])
      end
    end
    instrument_was_duplicated = true

  elseif instrument_mode == "selected" then
    final_instrument_index = song.selected_instrument_index or 1

  elseif instrument_mode == "original" then
    local found_instrument_index = nil
    for _, line in ipairs(pattern.tracks[source_track_index].lines) do
      for _, note_column in ipairs(line.note_columns) do
        if note_column.instrument_value ~= 255 then
          found_instrument_index = note_column.instrument_value + 1
          break
        end
      end
      if found_instrument_index then break end
    end
    final_instrument_index = found_instrument_index or 1
  end

  ------------------------------------------------------------------------------
  -- PART 2: Duplicate the track using your clean DSP/device–copy code
  ------------------------------------------------------------------------------
  local original_track_index = source_track_index
  song:insert_track_at(original_track_index + 1)
  local new_track = song:track(original_track_index + 1)

  -- Copy track settings
  new_track.visible_note_columns          = source_track.visible_note_columns
  new_track.visible_effect_columns        = source_track.visible_effect_columns
  new_track.volume_column_visible         = source_track.volume_column_visible
  new_track.panning_column_visible        = source_track.panning_column_visible
  new_track.delay_column_visible          = source_track.delay_column_visible
  new_track.sample_effects_column_visible = source_track.sample_effects_column_visible
  new_track.collapsed                     = source_track.collapsed

  -- Copy DSP devices starting from device index 2 so we don't interfere with the vol/pan device.
  for device_index = 2, #source_track.devices do
    local old_device = source_track.devices[device_index]
    local new_device = new_track:insert_device_at(old_device.device_path, device_index)
    for param_index = 1, #old_device.parameters do
      new_device.parameters[param_index].value = old_device.parameters[param_index].value
    end
    new_device.is_maximized = old_device.is_maximized
    -- Special handling for *Instr. Automation device
    if old_device.device_path:find("Instr. Automation") then
      local old_xml = old_device.active_preset_data
      local new_xml = old_xml:gsub("<instrument>(%d+)</instrument>", 
        function(instr_index)
          -- In duplicate/selected mode, update the XML to refer to the instrument we want.
          if instrument_mode == "duplicate" or instrument_mode == "selected" then
            return string.format("<instrument>%d</instrument>", final_instrument_index)
          else
            -- In "original" mode, leave the reference as is.
            return string.format("<instrument>%d</instrument>", tonumber(instr_index))
          end
        end)
      new_device.active_preset_data = new_xml
    end
  end

  ------------------------------------------------------------------------------
  -- PART 3: Copy pattern data and update instrument references in new track
  ------------------------------------------------------------------------------
  for pat_index = 1, #song.patterns do
    local pat = song:pattern(pat_index)
    local source_pat_track = pat:track(original_track_index)
    local dest_pat_track   = pat:track(original_track_index + 1)
    for line_index = 1, pat.number_of_lines do
      dest_pat_track:line(line_index):copy_from(source_pat_track:line(line_index))
      for _, note_column in ipairs(dest_pat_track:line(line_index).note_columns) do
        if note_column.instrument_value ~= 255 then
          if instrument_mode == "duplicate" or instrument_mode == "selected" then
            note_column.instrument_value = final_instrument_index - 1  -- 0-based
          end
          -- "original" mode leaves the note's instrument as in the original pattern.
        end
      end
    end
    for _, automation in ipairs(source_pat_track.automation) do
      local new_automation = dest_pat_track:create_automation(automation.dest_parameter)
      new_automation:copy_from(automation)
    end
  end

-- PART 4: Extract the specific note (highest or lowest) for every line in the new track's pattern.
-- For each pattern, we work on the duplicated track only.
local new_track_index = original_track_index + 1
for pat_index = 1, #song.patterns do
  local pat = song:pattern(pat_index)
  -- Get the duplicated pattern track (do not use properties of a PatternTrack, so use the SongTrack instead)
  local dest_pat_track = pat:track(new_track_index)
  -- Get the number of note columns from the duplicated track (a property of the SongTrack)
  local num_columns = song:track(new_track_index).visible_note_columns
  
  for line_index = 1, pat.number_of_lines do
    local line = dest_pat_track:line(line_index)
    local chosen_note, chosen_volume, chosen_panning, chosen_delay, chosen_instrument = nil, nil, nil, nil, nil

    -- Use the number of note columns from the original source track to examine all columns.
    for col = 1, source_track.visible_note_columns do
      local nc = line:note_column(col)
      if (not nc.is_empty) and (nc.note_string ~= "OFF") then
        local n_val = nc.note_value
        if chosen_note == nil then
          chosen_note = n_val
          chosen_volume = nc.volume_value
          chosen_panning = nc.panning_value
          chosen_delay = nc.delay_value
          chosen_instrument = nc.instrument_value
        else
          if note_type == "highest" and n_val > chosen_note then
            chosen_note = n_val
            chosen_volume = nc.volume_value
            chosen_panning = nc.panning_value
            chosen_delay = nc.delay_value
            chosen_instrument = nc.instrument_value
          elseif note_type == "lowest" and n_val < chosen_note then
            chosen_note = n_val
            chosen_volume = nc.volume_value
            chosen_panning = nc.panning_value
            chosen_delay = nc.delay_value
            chosen_instrument = nc.instrument_value
          end
        end
      end
    end

    if chosen_note then
      -- Clear all columns in the new track's line using the correct number
      for col = 1, num_columns do
        line:note_column(col):clear()
      end
      -- Write the chosen note in column 1
      local nc = line:note_column(1)
      nc.note_value    = chosen_note
      nc.volume_value  = chosen_volume
      nc.panning_value = chosen_panning
      nc.delay_value   = chosen_delay
      if instrument_mode == "duplicate" or instrument_mode == "selected" then
        nc.instrument_value = final_instrument_index - 1  -- convert to 0-based index
      else
        nc.instrument_value = chosen_instrument
      end
    end
  end
end

-- Finally, set the duplicated track to display only one note column.
song:track(new_track_index).visible_note_columns = 1
  ------------------------------------------------------------------------------
  -- PART 5: Final touches – select the new track, update instrument selection,
  -- and restore the external editor if needed.
  ------------------------------------------------------------------------------
  song.selected_track_index = original_track_index + 1
  if instrument_mode == "duplicate" then
    song.selected_instrument_index = final_instrument_index
  end
  if instrument_was_duplicated and external_editor_open then
    local new_instrument = song.instruments[final_instrument_index]
    if new_instrument.plugin_properties and new_instrument.plugin_properties.plugin_device then
      new_instrument.plugin_properties.plugin_device.external_editor_visible = true
    end
  end

  local mode_msg = instrument_mode == "duplicate" and "with duplicated instrument" or
                   instrument_mode == "selected" and "using selected instrument" or
                   "using original instrument"
  renoise.app():show_status(string.format("%s notes extracted to new track (%s, instrument %d)",
    note_type == "highest" and "Highest" or "Lowest",
    mode_msg, final_instrument_index))
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate Highest Notes to New Track & Duplicate Instrument",invoke=function() DuplicateSpecificNotesToNewTrack("highest", "duplicate") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate Highest Notes to New Track (Selected Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("highest", "selected") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate Highest Notes to New Track (Original Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("highest", "original") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate Lowest Notes to New Track & Duplicate Instrument",invoke=function() DuplicateSpecificNotesToNewTrack("lowest", "duplicate") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate Lowest Notes to New Track (Selected Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("lowest", "selected") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate Lowest Notes to New Track (Original Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("lowest", "original") end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Duplicate Highest Notes to New Track & Duplicate Instrument",invoke=function() DuplicateSpecificNotesToNewTrack("highest", "duplicate") end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Duplicate Highest Notes to New Track (Selected Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("highest", "selected") end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Duplicate Highest Notes to New Track (Original Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("highest", "original") end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Duplicate Lowest Notes to New Track & Duplicate Instrument",invoke=function() DuplicateSpecificNotesToNewTrack("lowest", "duplicate") end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Duplicate Lowest Notes to New Track (Selected Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("lowest", "selected") end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Duplicate Lowest Notes to New Track (Original Instrument)",invoke=function() DuplicateSpecificNotesToNewTrack("lowest", "original") end}



-- Function to distribute notes from a row into an arpeggio pattern
function DistributeNotes(pattern_type)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track = song.selected_track
  local track_index = song.selected_track_index
  local selection = song.selection_in_pattern
  
  -- Get the current line index
  local current_line = song.selected_line_index
  
  -- Store original number of visible columns
  local visible_columns = track.visible_note_columns
  
  -- Collect notes from the current row with their column information
  local notes = {}
  for col_idx = 1, visible_columns do
    local note_col = pattern.tracks[track_index]:line(current_line):note_column(col_idx)
    if not note_col.is_empty and note_col.note_value < 120 then -- Skip empty notes and note-offs
      table.insert(notes, {
        note_value = note_col.note_value,
        instrument_value = note_col.instrument_value,
        volume_value = note_col.volume_value,
        panning_value = note_col.panning_value,
        delay_value = note_col.delay_value,
        column = col_idx -- Store original column
      })
    end
  end
  
  -- If no notes or only one note found, exit
  if #notes == 0 then
    renoise.app():show_status("No notes found to distribute")
    return
  elseif #notes == 1 then
    renoise.app():show_status("Nothing to distribute, doing nothing")
    return
  end
  
  -- Clear the original row
  for col_idx = 1, visible_columns do
    pattern.tracks[track_index]:line(current_line):note_column(col_idx):clear()
  end
  
  -- Calculate spacing based on pattern type
  local function get_next_spacing(index)
    if pattern_type == "even2" then
      return 2
    elseif pattern_type == "even4" then
      return 4
    elseif pattern_type == "uneven" then
      -- Alternate between 1 and 2 rows
      return (index % 2 == 1) and 1 or 2
    else -- "nextrow"
      return 1
    end
  end
  
  -- Place notes according to the pattern
  local current_pos = current_line
  local max_pattern_lines = pattern.number_of_lines
  
  for i, note in ipairs(notes) do
    -- Check if we're still within pattern bounds
    if current_pos <= max_pattern_lines then
      local target_line = pattern.tracks[track_index]:line(current_pos)
      local note_col = target_line:note_column(note.column)
      
      -- Copy note data
      note_col.note_value = note.note_value
      note_col.instrument_value = note.instrument_value
      note_col.volume_value = note.volume_value
      note_col.panning_value = note.panning_value
      note_col.delay_value = note.delay_value
      
      -- Calculate next position
      local spacing = get_next_spacing(i)
      current_pos = current_pos + spacing
    else
      renoise.app():show_status("Pattern end reached - some notes not placed")
      break
    end
  end
  
  -- Show status message
  local pattern_name = pattern_type == "even2" and "2 rows" or
                      pattern_type == "even4" and "4 rows" or
                      pattern_type == "uneven" and "uneven spacing" or
                      "next row"
  renoise.app():show_status(string.format("Notes distributed with %s spacing", pattern_name))
end


-- Function to distribute notes across a selection range
function DistributeAcrossSelection(pattern_type)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track = song.selected_track
  local track_index = song.selected_track_index
  local selection = song.selection_in_pattern
  
  -- Check if we have a valid selection
  if not selection then
    renoise.app():show_status("Please make a selection first")
    return
  end
  
  local start_line = selection.start_line
  local end_line = selection.end_line
  local selection_length = end_line - start_line + 1
  
  -- Need at least 2 lines selected
  if selection_length < 2 then
    renoise.app():show_status("Please select at least 2 lines")
    return
  end
  
  -- Store original number of visible columns
  local visible_columns = track.visible_note_columns
  
  -- Collect notes from the first row of selection with their column information
  local notes = {}
  local first_line = pattern.tracks[track_index]:line(start_line)
  for col_idx = 1, visible_columns do
    local note_col = first_line:note_column(col_idx)
    if not note_col.is_empty and note_col.note_value < 120 then -- Skip empty notes and note-offs
      table.insert(notes, {
        note_value = note_col.note_value,
        instrument_value = note_col.instrument_value,
        volume_value = note_col.volume_value,
        panning_value = note_col.panning_value,
        delay_value = note_col.delay_value,
        column = col_idx -- Store original column
      })
    end
  end
  
  -- If no notes or only one note found, exit
  if #notes == 0 then
    renoise.app():show_status("No notes found in first line to distribute")
    return
  elseif #notes == 1 then
    renoise.app():show_status("Nothing to distribute, doing nothing")
    return
  end
  
  -- Clear all lines in the selection
  for line_idx = start_line, end_line do
    local line = pattern.tracks[track_index]:line(line_idx)
    for col_idx = 1, visible_columns do
      line:note_column(col_idx):clear()
    end
  end
  
  -- Calculate positions based on pattern type
  local positions = {}
  if pattern_type == "even" then
    -- First note always at start
    positions[1] = start_line
    
    -- Distribute remaining notes evenly
    local step = (selection_length - 1) / (#notes - 1)
    for i = 2, #notes do
      local pos = start_line + math.floor((i - 1) * step + 0.5)
      -- Ensure position is within valid range
      positions[i] = math.max(start_line, math.min(end_line, pos))
    end
  elseif pattern_type == "even2" then
    -- Distribute with 2-line spacing
    for i = 1, #notes do
      local pos = start_line + ((i - 1) * 2)
      if pos <= end_line then
        positions[i] = pos
      else
        break
      end
    end
  elseif pattern_type == "even4" then
    -- Distribute with 4-line spacing
    for i = 1, #notes do
      local pos = start_line + ((i - 1) * 4)
      if pos <= end_line then
        positions[i] = pos
      else
        break
      end
    end
  elseif pattern_type == "uneven" then
    -- First note always at start
    positions[1] = start_line
    
    local remaining_space = selection_length - 1
    local remaining_notes = #notes - 1
    local pos = start_line
    
    for i = 2, #notes do
      if i == #notes then
        positions[i] = end_line -- Last note always at end
      else
        -- Add some randomness but ensure we leave room for remaining notes
        local max_step = math.floor(remaining_space / remaining_notes * 1.5)
        local min_step = math.max(1, math.floor(remaining_space / remaining_notes * 0.5))
        local step = math.random(min_step, max_step)
        pos = pos + step
        -- Ensure position is within valid range
        positions[i] = math.max(start_line, math.min(end_line, pos))
        remaining_space = end_line - pos
        remaining_notes = remaining_notes - 1
      end
    end
  end
  
  -- Place notes according to calculated positions, maintaining their original columns
  for i, note in ipairs(notes) do
    if positions[i] then -- Only place notes that have valid positions
      local target_line = pattern.tracks[track_index]:line(positions[i])
      local note_col = target_line:note_column(note.column)
      
      note_col.note_value = note.note_value
      note_col.instrument_value = note.instrument_value
      note_col.volume_value = note.volume_value
      note_col.panning_value = note.panning_value
      note_col.delay_value = note.delay_value
    end
  end
  
  -- Show status message
  local pattern_name = pattern_type == "even" and "evenly" or
                      pattern_type == "even2" and "2 rows" or
                      pattern_type == "even4" and "4 rows" or
                      "unevenly"
  renoise.app():show_status(string.format("Notes distributed with %s spacing across selection (%d lines)", 
    pattern_name, selection_length))
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Distribute (Even 2)",invoke=function() DistributeNotes("even2") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Distribute (Even 4)",invoke=function() DistributeNotes("even4") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Distribute (Uneven)",invoke=function() DistributeNotes("uneven") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Distribute (Always Next Row)",invoke=function() DistributeNotes("nextrow") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Distribute Across Selection (Even)",invoke=function() DistributeAcrossSelection("even") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Distribute Across Selection (Even 2)",invoke=function() DistributeAcrossSelection("even2") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Distribute Across Selection (Even 4)",invoke=function() DistributeAcrossSelection("even4") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Distribute Across Selection (Uneven)",invoke=function() DistributeAcrossSelection("uneven") end}

-- Function to spread notes from current row vertically with specified spacing
function SpreadNotesVertically(spacing)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track = song.selected_track
  local track_index = song.selected_track_index
  local current_line = song.selected_line_index
  local visible_columns = track.visible_note_columns
  local visible_effect_columns = track.visible_effect_columns
  local selected_column = song.selected_note_column_index
  
  -- Collect all notes from the current row with their column positions, starting from selected column going backwards
  local notes = {}
  local line = pattern.tracks[track_index]:line(current_line)
  
  -- Collect notes from selected column going backwards to column 1
  for col_idx = selected_column, 1, -1 do
    local note_col = line:note_column(col_idx)
    if not note_col.is_empty and note_col.note_value < 120 then
      table.insert(notes, {
        note_value = note_col.note_value,
        instrument_value = note_col.instrument_value,
        volume_value = note_col.volume_value,
        panning_value = note_col.panning_value,
        delay_value = note_col.delay_value,
        column = col_idx
      })
    end
  end
  
  -- Then, wrap around and collect from the rightmost column backwards to after selected column
  for col_idx = visible_columns, selected_column + 1, -1 do
    local note_col = line:note_column(col_idx)
    if not note_col.is_empty and note_col.note_value < 120 then
      table.insert(notes, {
        note_value = note_col.note_value,
        instrument_value = note_col.instrument_value,
        volume_value = note_col.volume_value,
        panning_value = note_col.panning_value,
        delay_value = note_col.delay_value,
        column = col_idx
      })
    end
  end
  
  -- Collect all effect columns from the current row
  local effects = {}
  for col_idx = 1, visible_effect_columns do
    local effect_col = line:effect_column(col_idx)
    if not effect_col.is_empty then
      table.insert(effects, {
        number_string = effect_col.number_string,
        amount_value = effect_col.amount_value,
        column = col_idx
      })
    end
  end
  
  -- Check if we have notes to spread
  if #notes == 0 then
    renoise.app():show_status("No notes found on current row")
    return
  end
  
  if #notes == 1 then
    renoise.app():show_status("Only one note found, nothing to spread")
    return
  end
  
  -- Calculate if we have enough space in the pattern
  local required_lines = current_line + ((#notes - 1) * spacing)
  local max_lines = pattern.number_of_lines
  
  if required_lines > max_lines then
    renoise.app():show_status(string.format("Not enough space in pattern (need %d lines, have %d)", 
      required_lines, max_lines))
    return
  end
  
  -- Clear the current row
  for col_idx = 1, visible_columns do
    line:note_column(col_idx):clear()
  end
  for col_idx = 1, visible_effect_columns do
    line:effect_column(col_idx):clear()
  end
  
  -- Place notes on new rows with specified spacing
  for i, note in ipairs(notes) do
    local target_row = current_line + ((i - 1) * spacing)
    local target_line = pattern.tracks[track_index]:line(target_row)
    local note_col = target_line:note_column(note.column)
    
    note_col.note_value = note.note_value
    note_col.instrument_value = note.instrument_value
    note_col.volume_value = note.volume_value
    note_col.panning_value = note.panning_value
    note_col.delay_value = note.delay_value
  end
  
  -- Place effect columns on ALL new rows (they apply to all spread notes)
  for i = 1, #notes do
    local target_row = current_line + ((i - 1) * spacing)
    local target_line = pattern.tracks[track_index]:line(target_row)
    
    for _, effect in ipairs(effects) do
      local effect_col = target_line:effect_column(effect.column)
      effect_col.number_string = effect.number_string
      effect_col.amount_value = effect.amount_value
    end
  end
  
  -- Show status message with effect column info
  local status_msg = string.format("Spread %d notes vertically with +%d row spacing", 
    #notes, spacing)
  if #effects > 0 then
    status_msg = status_msg .. string.format(" (with %d effect column%s)", 
      #effects, #effects == 1 and "" or "s")
  end
  renoise.app():show_status(status_msg)
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Spread Notes Vertically (+1 Row)",invoke=function() SpreadNotesVertically(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Spread Notes Vertically (+2 Rows)",invoke=function() SpreadNotesVertically(2) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Spread Notes Vertically (+3 Rows)",invoke=function() SpreadNotesVertically(3) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Spread Notes Vertically (+4 Rows)",invoke=function() SpreadNotesVertically(4) end}

-- Function to create arpeggio patterns from current row notes
function CreateArpeggioPattern(pattern_type, num_rows)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track = song.selected_track
  local track_index = song.selected_track_index
  local current_line = song.selected_line_index
  local visible_columns = track.visible_note_columns
  local visible_effect_columns = track.visible_effect_columns
  
  -- Collect all notes from the current row
  local notes = {}
  local line = pattern.tracks[track_index]:line(current_line)
  
  for col_idx = 1, visible_columns do
    local note_col = line:note_column(col_idx)
    if not note_col.is_empty and note_col.note_value < 120 then
      table.insert(notes, {
        note_value = note_col.note_value,
        instrument_value = note_col.instrument_value,
        volume_value = note_col.volume_value,
        panning_value = note_col.panning_value,
        delay_value = note_col.delay_value
      })
    end
  end
  
  -- Collect effect columns
  local effects = {}
  for col_idx = 1, visible_effect_columns do
    local effect_col = line:effect_column(col_idx)
    if not effect_col.is_empty then
      table.insert(effects, {
        number_string = effect_col.number_string,
        amount_value = effect_col.amount_value,
        column = col_idx
      })
    end
  end
  
  -- Check if we have notes
  if #notes == 0 then
    renoise.app():show_status("No notes found on current row")
    return
  end
  
  if #notes == 1 then
    renoise.app():show_status("Only one note found, cannot create arpeggio")
    return
  end
  
  -- Sort notes by pitch (ascending)
  table.sort(notes, function(a, b) return a.note_value < b.note_value end)
  
  -- Check if we have enough space
  local required_lines = current_line + num_rows - 1
  if required_lines > pattern.number_of_lines then
    renoise.app():show_status(string.format("Not enough space in pattern (need %d lines)", required_lines))
    return
  end
  
  -- Generate arpeggio pattern based on type
  local arpeggio_sequence = {}
  
  if pattern_type == "up" then
    -- Ascending: 1-2-3-4-1-2-3-4...
    for i = 1, num_rows do
      local idx = ((i - 1) % #notes) + 1
      table.insert(arpeggio_sequence, notes[idx])
    end
    
  elseif pattern_type == "down" then
    -- Descending: 4-3-2-1-4-3-2-1...
    for i = 1, num_rows do
      local idx = #notes - ((i - 1) % #notes)
      table.insert(arpeggio_sequence, notes[idx])
    end
    
  elseif pattern_type == "updown" then
    -- Up then down: 1-2-3-4-3-2-1-2-3-4...
    local forward = {}
    local backward = {}
    for i = 1, #notes do
      table.insert(forward, notes[i])
    end
    for i = #notes - 1, 2, -1 do
      table.insert(backward, notes[i])
    end
    local full_pattern = {}
    for _, n in ipairs(forward) do table.insert(full_pattern, n) end
    for _, n in ipairs(backward) do table.insert(full_pattern, n) end
    
    for i = 1, num_rows do
      local idx = ((i - 1) % #full_pattern) + 1
      table.insert(arpeggio_sequence, full_pattern[idx])
    end
    
  elseif pattern_type == "downup" then
    -- Down then up: 4-3-2-1-2-3-4-3-2-1...
    local forward = {}
    local backward = {}
    for i = #notes, 1, -1 do
      table.insert(forward, notes[i])
    end
    for i = 2, #notes - 1 do
      table.insert(backward, notes[i])
    end
    local full_pattern = {}
    for _, n in ipairs(forward) do table.insert(full_pattern, n) end
    for _, n in ipairs(backward) do table.insert(full_pattern, n) end
    
    for i = 1, num_rows do
      local idx = ((i - 1) % #full_pattern) + 1
      table.insert(arpeggio_sequence, full_pattern[idx])
    end
    
  elseif pattern_type == "upupdown" then
    -- Up-up-down: 1-2-3-2-1-2-3-2...
    for i = 1, num_rows do
      local cycle_pos = ((i - 1) % (#notes * 2 - 1))
      local idx
      if cycle_pos < #notes then
        idx = cycle_pos + 1
      else
        idx = #notes - (cycle_pos - #notes + 1)
      end
      table.insert(arpeggio_sequence, notes[idx])
    end
    
  elseif pattern_type == "updownup" then
    -- Up-down-up variant: focuses on extremes
    local pattern_seq = {1, #notes, 1}
    if #notes > 2 then
      pattern_seq = {1, math.ceil(#notes/2), #notes, math.ceil(#notes/2)}
    end
    for i = 1, num_rows do
      local idx = pattern_seq[((i - 1) % #pattern_seq) + 1]
      table.insert(arpeggio_sequence, notes[idx])
    end
    
  elseif pattern_type == "random" then
    -- Random selection
    for i = 1, num_rows do
      local idx = math.random(1, #notes)
      table.insert(arpeggio_sequence, notes[idx])
    end
    
  elseif pattern_type == "outin" then
    -- Outside to inside: 1-4-2-3-1-4-2-3...
    local pattern_seq = {}
    local left_idx = 1
    local right_idx = #notes
    while left_idx <= right_idx do
      table.insert(pattern_seq, notes[left_idx])
      if left_idx < right_idx then
        table.insert(pattern_seq, notes[right_idx])
      end
      left_idx = left_idx + 1
      right_idx = right_idx - 1
    end
    for i = 1, num_rows do
      local idx = ((i - 1) % #pattern_seq) + 1
      table.insert(arpeggio_sequence, pattern_seq[idx])
    end
    
  elseif pattern_type == "inout" then
    -- Inside to outside (for chords with 4+ notes)
    local pattern_seq = {}
    local left_idx = math.ceil(#notes / 2)
    local right_idx = math.ceil(#notes / 2) + 1
    if #notes % 2 == 1 then
      table.insert(pattern_seq, notes[left_idx])
      left_idx = left_idx - 1
    else
      right_idx = left_idx + 1
      left_idx = left_idx
    end
    while left_idx >= 1 and right_idx <= #notes do
      table.insert(pattern_seq, notes[left_idx])
      table.insert(pattern_seq, notes[right_idx])
      left_idx = left_idx - 1
      right_idx = right_idx + 1
    end
    for i = 1, num_rows do
      local idx = ((i - 1) % #pattern_seq) + 1
      table.insert(arpeggio_sequence, pattern_seq[idx])
    end
  end
  
  -- Clear the original row
  for col_idx = 1, visible_columns do
    line:note_column(col_idx):clear()
  end
  for col_idx = 1, visible_effect_columns do
    line:effect_column(col_idx):clear()
  end
  
  -- Write arpeggio pattern to rows
  for i, note_data in ipairs(arpeggio_sequence) do
    local target_row = current_line + i - 1
    local target_line = pattern.tracks[track_index]:line(target_row)
    local note_col = target_line:note_column(1)
    
    note_col.note_value = note_data.note_value
    note_col.instrument_value = note_data.instrument_value
    note_col.volume_value = note_data.volume_value
    note_col.panning_value = note_data.panning_value
    note_col.delay_value = note_data.delay_value
    
    -- Copy effect columns to each row
    for _, effect in ipairs(effects) do
      local effect_col = target_line:effect_column(effect.column)
      effect_col.number_string = effect.number_string
      effect_col.amount_value = effect.amount_value
    end
  end
  
  -- Set visible columns to 1 since we're writing arpeggios
  track.visible_note_columns = 1
  
  -- Status message
  local pattern_names = {
    up = "Up (Ascending)",
    down = "Down (Descending)",
    updown = "Up-Down",
    downup = "Down-Up",
    upupdown = "Up-Up-Down",
    updownup = "Up-Down-Up",
    random = "Random",
    outin = "Outside-In",
    inout = "Inside-Out"
  }
  
  renoise.app():show_status(string.format("Created %s arpeggio pattern (%d notes, %d rows)", 
    pattern_names[pattern_type] or pattern_type, #notes, num_rows))
end

-- Keybindings for arpeggio patterns (16 rows by default)
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Up (16 rows)",invoke=function() CreateArpeggioPattern("up", 16) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Down (16 rows)",invoke=function() CreateArpeggioPattern("down", 16) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Up-Down (16 rows)",invoke=function() CreateArpeggioPattern("updown", 16) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Down-Up (16 rows)",invoke=function() CreateArpeggioPattern("downup", 16) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Up-Up-Down (16 rows)",invoke=function() CreateArpeggioPattern("upupdown", 16) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Random (16 rows)",invoke=function() CreateArpeggioPattern("random", 16) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Outside-In (16 rows)",invoke=function() CreateArpeggioPattern("outin", 16) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Inside-Out (16 rows)",invoke=function() CreateArpeggioPattern("inout", 16) end}

-- 8-row versions for faster arpeggios
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Up (8 rows)",invoke=function() CreateArpeggioPattern("up", 8) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Down (8 rows)",invoke=function() CreateArpeggioPattern("down", 8) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Up-Down (8 rows)",invoke=function() CreateArpeggioPattern("updown", 8) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Down-Up (8 rows)",invoke=function() CreateArpeggioPattern("downup", 8) end}

-- 4-row versions for very fast arpeggios
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Up (4 rows)",invoke=function() CreateArpeggioPattern("up", 4) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Down (4 rows)",invoke=function() CreateArpeggioPattern("down", 4) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Up-Down (4 rows)",invoke=function() CreateArpeggioPattern("updown", 4) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Down-Up (4 rows)",invoke=function() CreateArpeggioPattern("downup", 4) end}

-- Helper function to find next note or note-off in track
function FindNextNoteOrOff(pattern, track_index, start_line, visible_columns)
  local max_lines = pattern.number_of_lines
  
  -- Search from start_line + 1 onwards
  for line_idx = start_line + 1, max_lines do
    local line = pattern.tracks[track_index]:line(line_idx)
    -- Check all visible note columns
    for col_idx = 1, visible_columns do
      local note_col = line:note_column(col_idx)
      if not note_col.is_empty then
        -- Found either a note or note-off
        return line_idx
      end
    end
  end
  
  -- No note found, return end of pattern
  return max_lines + 1
end

-- Function to create arpeggio that continues until next note or note-off
function CreateArpeggioUntilNext(pattern_type)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track = song.selected_track
  local track_index = song.selected_track_index
  local current_line = song.selected_line_index
  local visible_columns = track.visible_note_columns
  local visible_effect_columns = track.visible_effect_columns
  
  -- Store original visible columns to restore later
  local original_visible_columns = visible_columns
  
  -- Collect all notes from the current row
  local notes = {}
  local line = pattern.tracks[track_index]:line(current_line)
  
  for col_idx = 1, visible_columns do
    local note_col = line:note_column(col_idx)
    if not note_col.is_empty and note_col.note_value < 120 then
      table.insert(notes, {
        note_value = note_col.note_value,
        instrument_value = note_col.instrument_value,
        volume_value = note_col.volume_value,
        panning_value = note_col.panning_value,
        delay_value = note_col.delay_value
      })
    end
  end
  
  -- Collect effect columns
  local effects = {}
  for col_idx = 1, visible_effect_columns do
    local effect_col = line:effect_column(col_idx)
    if not effect_col.is_empty then
      table.insert(effects, {
        number_string = effect_col.number_string,
        amount_value = effect_col.amount_value,
        column = col_idx
      })
    end
  end
  
  -- Check if we have notes
  if #notes == 0 then
    renoise.app():show_status("No notes found on current row")
    return
  end
  
  if #notes == 1 then
    renoise.app():show_status("Only one note found, cannot create arpeggio")
    return
  end
  
  -- Sort notes by pitch (ascending)
  table.sort(notes, function(a, b) return a.note_value < b.note_value end)
  
  -- Find next note or note-off
  local next_note_line = FindNextNoteOrOff(pattern, track_index, current_line, visible_columns)
  local num_rows = next_note_line - current_line
  
  -- Check if we have space for at least one arpeggio cycle
  if num_rows < 2 then
    renoise.app():show_status("Not enough space to create arpeggio (next note is too close)")
    return
  end
  
  -- Generate arpeggio pattern based on type
  local arpeggio_sequence = {}
  
  if pattern_type == "up" then
    -- Ascending: 1-2-3-4-1-2-3-4...
    for i = 1, num_rows do
      local idx = ((i - 1) % #notes) + 1
      table.insert(arpeggio_sequence, notes[idx])
    end
    
  elseif pattern_type == "down" then
    -- Descending: 4-3-2-1-4-3-2-1...
    for i = 1, num_rows do
      local idx = #notes - ((i - 1) % #notes)
      table.insert(arpeggio_sequence, notes[idx])
    end
    
  elseif pattern_type == "updown" then
    -- Up then down: 1-2-3-4-3-2-1-2-3-4...
    local forward = {}
    local backward = {}
    for i = 1, #notes do
      table.insert(forward, notes[i])
    end
    for i = #notes - 1, 2, -1 do
      table.insert(backward, notes[i])
    end
    local full_pattern = {}
    for _, n in ipairs(forward) do table.insert(full_pattern, n) end
    for _, n in ipairs(backward) do table.insert(full_pattern, n) end
    
    for i = 1, num_rows do
      local idx = ((i - 1) % #full_pattern) + 1
      table.insert(arpeggio_sequence, full_pattern[idx])
    end
    
  elseif pattern_type == "downup" then
    -- Down then up: 4-3-2-1-2-3-4-3-2-1...
    local forward = {}
    local backward = {}
    for i = #notes, 1, -1 do
      table.insert(forward, notes[i])
    end
    for i = 2, #notes - 1 do
      table.insert(backward, notes[i])
    end
    local full_pattern = {}
    for _, n in ipairs(forward) do table.insert(full_pattern, n) end
    for _, n in ipairs(backward) do table.insert(full_pattern, n) end
    
    for i = 1, num_rows do
      local idx = ((i - 1) % #full_pattern) + 1
      table.insert(arpeggio_sequence, full_pattern[idx])
    end
    
  elseif pattern_type == "random" then
    -- Random selection
    for i = 1, num_rows do
      local idx = math.random(1, #notes)
      table.insert(arpeggio_sequence, notes[idx])
    end
  end
  
  -- Clear the original row
  for col_idx = 1, visible_columns do
    line:note_column(col_idx):clear()
  end
  for col_idx = 1, visible_effect_columns do
    line:effect_column(col_idx):clear()
  end
  
  -- Write arpeggio pattern to rows
  for i, note_data in ipairs(arpeggio_sequence) do
    local target_row = current_line + i - 1
    local target_line = pattern.tracks[track_index]:line(target_row)
    local note_col = target_line:note_column(1)
    
    note_col.note_value = note_data.note_value
    note_col.instrument_value = note_data.instrument_value
    note_col.volume_value = note_data.volume_value
    note_col.panning_value = note_data.panning_value
    note_col.delay_value = note_data.delay_value
    
    -- Copy effect columns to each row
    for _, effect in ipairs(effects) do
      local effect_col = target_line:effect_column(effect.column)
      effect_col.number_string = effect.number_string
      effect_col.amount_value = effect.amount_value
    end
  end
  
  -- Keep the original visible columns (don't reduce to 1)
  track.visible_note_columns = math.max(1, original_visible_columns)
  
  -- Status message
  local pattern_names = {
    up = "Up",
    down = "Down",
    updown = "Up-Down",
    downup = "Down-Up",
    random = "Random"
  }
  
  renoise.app():show_status(string.format("Created %s arpeggio (%d notes, %d rows until next note)", 
    pattern_names[pattern_type] or pattern_type, #notes, num_rows))
end

-- Function to process all chord rows in pattern or selection
function CreateArpeggioAllChords(pattern_type)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track = song.selected_track
  local track_index = song.selected_track_index
  local selection = song.selection_in_pattern
  local visible_columns = track.visible_note_columns
  local original_visible_columns = visible_columns
  
  -- Determine range to process
  local start_line, end_line
  if selection then
    start_line = selection.start_line
    end_line = selection.end_line
  else
    start_line = 1
    end_line = pattern.number_of_lines
  end
  
  -- Find all rows with multiple notes (chords)
  local chord_rows = {}
  for line_idx = start_line, end_line do
    local line = pattern.tracks[track_index]:line(line_idx)
    local note_count = 0
    
    for col_idx = 1, visible_columns do
      local note_col = line:note_column(col_idx)
      if not note_col.is_empty and note_col.note_value < 120 then
        note_count = note_count + 1
      end
    end
    
    if note_count > 1 then
      table.insert(chord_rows, line_idx)
    end
  end
  
  if #chord_rows == 0 then
    renoise.app():show_status("No chord rows found to process")
    return
  end
  
  -- Process each chord row
  local processed_count = 0
  for _, chord_line_idx in ipairs(chord_rows) do
    local line = pattern.tracks[track_index]:line(chord_line_idx)
    
    -- Collect notes from this chord row
    local notes = {}
    for col_idx = 1, visible_columns do
      local note_col = line:note_column(col_idx)
      if not note_col.is_empty and note_col.note_value < 120 then
        table.insert(notes, {
          note_value = note_col.note_value,
          instrument_value = note_col.instrument_value,
          volume_value = note_col.volume_value,
          panning_value = note_col.panning_value,
          delay_value = note_col.delay_value
        })
      end
    end
    
    -- Collect effect columns
    local effects = {}
    for col_idx = 1, track.visible_effect_columns do
      local effect_col = line:effect_column(col_idx)
      if not effect_col.is_empty then
        table.insert(effects, {
          number_string = effect_col.number_string,
          amount_value = effect_col.amount_value,
          column = col_idx
        })
      end
    end
    
    if #notes > 1 then
      -- Sort notes by pitch
      table.sort(notes, function(a, b) return a.note_value < b.note_value end)
      
      -- Find next note or note-off
      local next_note_line = FindNextNoteOrOff(pattern, track_index, chord_line_idx, visible_columns)
      local num_rows = next_note_line - chord_line_idx
      
      if num_rows >= 2 then
        -- Generate arpeggio pattern
        local arpeggio_sequence = {}
        
        if pattern_type == "up" then
          for i = 1, num_rows do
            local idx = ((i - 1) % #notes) + 1
            table.insert(arpeggio_sequence, notes[idx])
          end
        elseif pattern_type == "down" then
          for i = 1, num_rows do
            local idx = #notes - ((i - 1) % #notes)
            table.insert(arpeggio_sequence, notes[idx])
          end
        elseif pattern_type == "updown" then
          local forward = {}
          local backward = {}
          for i = 1, #notes do
            table.insert(forward, notes[i])
          end
          for i = #notes - 1, 2, -1 do
            table.insert(backward, notes[i])
          end
          local full_pattern = {}
          for _, n in ipairs(forward) do table.insert(full_pattern, n) end
          for _, n in ipairs(backward) do table.insert(full_pattern, n) end
          
          for i = 1, num_rows do
            local idx = ((i - 1) % #full_pattern) + 1
            table.insert(arpeggio_sequence, full_pattern[idx])
          end
        elseif pattern_type == "downup" then
          local forward = {}
          local backward = {}
          for i = #notes, 1, -1 do
            table.insert(forward, notes[i])
          end
          for i = 2, #notes - 1 do
            table.insert(backward, notes[i])
          end
          local full_pattern = {}
          for _, n in ipairs(forward) do table.insert(full_pattern, n) end
          for _, n in ipairs(backward) do table.insert(full_pattern, n) end
          
          for i = 1, num_rows do
            local idx = ((i - 1) % #full_pattern) + 1
            table.insert(arpeggio_sequence, full_pattern[idx])
          end
        elseif pattern_type == "random" then
          for i = 1, num_rows do
            local idx = math.random(1, #notes)
            table.insert(arpeggio_sequence, notes[idx])
          end
        end
        
        -- Clear the chord row
        for col_idx = 1, visible_columns do
          line:note_column(col_idx):clear()
        end
        for col_idx = 1, track.visible_effect_columns do
          line:effect_column(col_idx):clear()
        end
        
        -- Write arpeggio pattern
        for i, note_data in ipairs(arpeggio_sequence) do
          local target_row = chord_line_idx + i - 1
          local target_line = pattern.tracks[track_index]:line(target_row)
          local note_col = target_line:note_column(1)
          
          note_col.note_value = note_data.note_value
          note_col.instrument_value = note_data.instrument_value
          note_col.volume_value = note_data.volume_value
          note_col.panning_value = note_data.panning_value
          note_col.delay_value = note_data.delay_value
          
          -- Copy effect columns to each row
          for _, effect in ipairs(effects) do
            local effect_col = target_line:effect_column(effect.column)
            effect_col.number_string = effect.number_string
            effect_col.amount_value = effect.amount_value
          end
        end
        
        processed_count = processed_count + 1
      end
    end
  end
  
  -- Keep the original visible columns
  track.visible_note_columns = math.max(1, original_visible_columns)
  
  -- Status message
  local pattern_names = {
    up = "Up",
    down = "Down",
    updown = "Up-Down",
    downup = "Down-Up",
    random = "Random"
  }
  
  local range_msg = selection and "in selection" or "in pattern"
  renoise.app():show_status(string.format("Processed %d chord row%s %s with %s arpeggio", 
    processed_count, processed_count == 1 and "" or "s", range_msg, pattern_names[pattern_type] or pattern_type))
end

-- Keybindings for arpeggio until next note (single chord row)
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Up (Until Next Note)",invoke=function() CreateArpeggioUntilNext("up") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Down (Until Next Note)",invoke=function() CreateArpeggioUntilNext("down") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Up-Down (Until Next Note)",invoke=function() CreateArpeggioUntilNext("updown") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Down-Up (Until Next Note)",invoke=function() CreateArpeggioUntilNext("downup") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Random (Until Next Note)",invoke=function() CreateArpeggioUntilNext("random") end}

-- Keybindings for processing all chord rows
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Up (All Chords)",invoke=function() CreateArpeggioAllChords("up") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Down (All Chords)",invoke=function() CreateArpeggioAllChords("down") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Up-Down (All Chords)",invoke=function() CreateArpeggioAllChords("updown") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Down-Up (All Chords)",invoke=function() CreateArpeggioAllChords("downup") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Arpeggio Random (All Chords)",invoke=function() CreateArpeggioAllChords("random") end}

--------------------------------------------------------------------------------
-- Order Notes - Voice Separation and Polyphonic Organization
--------------------------------------------------------------------------------

-- Helper function to copy note data
function PakettiCopyNoteData(note_column)
  return {
    note_value = note_column.note_value,
    instrument_value = note_column.instrument_value,
    volume_value = note_column.volume_value,
    panning_value = note_column.panning_value,
    delay_value = note_column.delay_value
  }
end

-- Helper function to write note data
function PakettiWriteNoteData(note_column, note_data)
  note_column.note_value = note_data.note_value
  note_column.instrument_value = note_data.instrument_value
  note_column.volume_value = note_data.volume_value
  note_column.panning_value = note_data.panning_value
  note_column.delay_value = note_data.delay_value
end

-- Helper function to compare note blocks for sorting
function PakettiCompareNoteBlocks(a, b)
  -- First compare by line number
  if a[1][1] ~= b[1][1] then
    return a[1][1] < b[1][1]
  end
  -- Then by pitch (note value)
  return a[1][2][1] < b[1][2][1]
end

-- Main function to order notes across a track in patterns
function PakettiOrderNotesInTrack(track_index, pattern_indices)
  local song = renoise.song()
  local start_time = os.clock()
  
  -- Track note blocks across all columns
  local columns = {}
  local blocks = {}
  local max_columns = 1
  
  -- Process each pattern
  for _, pattern_index in ipairs(pattern_indices) do
    local pattern = song.patterns[pattern_index]
    local pattern_track = pattern.tracks[track_index]
    local lines = pattern_track.lines
    local num_lines = #lines
    
    -- Process each line in the pattern
    for line_index = 1, num_lines do
      local line = lines[line_index]
      
      if not line.is_empty then
        local note_columns = line.note_columns
        
        -- Process each note column
        for col, note_column in ipairs(note_columns) do
          if not note_column.is_empty then
            -- Initialize column array if needed
            if not columns[col] then
              columns[col] = {}
            end
            
            local note_value = note_column.note_value
            local column_notes = columns[col]
            local num_notes = #column_notes
            
            -- Process notes and note-offs (value < 121)
            if note_value < 121 then
              -- Start a new note block
              if num_notes == 0 and note_value < 120 then
                table.insert(column_notes, {line_index, PakettiCopyNoteData(note_column)})
              
              -- Handle existing note blocks
              elseif num_notes > 0 then
                -- End current block with note-off
                if note_value == 120 then
                  table.insert(column_notes, {line_index, PakettiCopyNoteData(note_column)})
                  table.insert(blocks, column_notes)
                  columns[col] = {}
                
                -- End current block and start new one
                else
                  table.insert(column_notes, {line_index - 1})
                  table.insert(blocks, column_notes)
                  columns[col] = {{line_index, PakettiCopyNoteData(note_column)}}
                end
              end
            
            -- Collect note data for ongoing blocks
            elseif num_notes > 0 then
              table.insert(column_notes, {line_index, PakettiCopyNoteData(note_column)})
            end
            
            -- Clear the note (we'll rewrite it later)
            note_column:clear()
          end
        end
      end
    end
    
    -- Finalize any open blocks at end of pattern
    for col, block in pairs(columns) do
      if block[1] then
        table.insert(block, {num_lines})
        table.insert(blocks, block)
      end
    end
    columns = {}
    
    -- Sort all blocks by starting line and pitch
    table.sort(blocks, PakettiCompareNoteBlocks)
    
    -- Write sorted blocks back to pattern
    local last_line = -1
    local column_index = 1
    
    for _, block in ipairs(blocks) do
      -- Check if we're on the same line as previous block
      if last_line == block[1][1] then
        column_index = column_index + 1
        if column_index > max_columns then
          max_columns = column_index
        end
      else
        column_index = 1
        last_line = block[1][1]
      end
      
      -- Clear the column range for this block
      local block_start = block[1][1]
      local block_end = block[#block][1]
      for line_index = block_start, block_end do
        lines[line_index].note_columns[column_index]:clear()
      end
      
      -- Write all notes in the block
      for i, note_entry in ipairs(block) do
        if note_entry[2] then
          local line_index = note_entry[1]
          local note_data = note_entry[2]
          local note_column = lines[line_index].note_columns[column_index]
          PakettiWriteNoteData(note_column, note_data)
        end
      end
    end
    
    blocks = {}
  end
  
  -- Set visible columns to accommodate all voices
  song.tracks[track_index].visible_note_columns = max_columns
  
  local elapsed = os.clock() - start_time
  return max_columns, elapsed
end

-- Order notes in current pattern only
function PakettiOrderNotesAcrossTrack()
  local song = renoise.song()
  local track_index = song.selected_track_index
  local pattern_index = song.selected_pattern_index
  
  local max_columns, elapsed = PakettiOrderNotesInTrack(track_index, {pattern_index})
  
  renoise.app():show_status(string.format(
    "Ordered notes in pattern %d (track %d) → %d voice%s (%.2fs)",
    pattern_index,
    track_index,
    max_columns,
    max_columns == 1 and "" or "s",
    elapsed
  ))
end

-- Order notes across all patterns in track
function PakettiOrderNotesCurrentTrackAllPatterns()
  local song = renoise.song()
  local track_index = song.selected_track_index
  
  -- Build list of all pattern indices
  local pattern_indices = {}
  for i = 1, #song.patterns do
    table.insert(pattern_indices, i)
  end
  
  local max_columns, elapsed = PakettiOrderNotesInTrack(track_index, pattern_indices)
  
  renoise.app():show_status(string.format(
    "Ordered notes across %d patterns (track %d) → %d voice%s (%.2fs)",
    #pattern_indices,
    track_index,
    max_columns,
    max_columns == 1 and "" or "s",
    elapsed
  ))
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Order Notes Across Track",invoke=function() PakettiOrderNotesAcrossTrack() end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Order Notes Current Track All Patterns",invoke=function() PakettiOrderNotesCurrentTrackAllPatterns() end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Order Notes Across Track",invoke=function() PakettiOrderNotesAcrossTrack() end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Order Notes Current Track All Patterns",invoke=function() PakettiOrderNotesCurrentTrackAllPatterns() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Order Notes:Order Notes Across Track",invoke=function() PakettiOrderNotesAcrossTrack() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Order Notes:Order Notes Current Track All Patterns",invoke=function() PakettiOrderNotesCurrentTrackAllPatterns() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Order Notes:Order Notes Across Track",invoke=function() PakettiOrderNotesAcrossTrack() end}
renoise.tool():add_menu_entry{name="Mixer:Paketti:Order Notes:Order Notes Current Track All Patterns",invoke=function() PakettiOrderNotesCurrentTrackAllPatterns() end}