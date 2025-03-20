-- from Jalex
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

    renoise.song().selected_pattern.tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[renoise.song().selected_note_column_index + 1].note_value = originalNote + number
    renoise.song().selected_pattern.tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[renoise.song().selected_note_column_index + 1].instrument_value = originalInstrument
    renoise.song().selected_pattern.tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index].note_columns[renoise.song().selected_note_column_index + 1].volume_value = originalVolume
    
    renoise.song().selected_note_column_index = renoise.song().selected_note_column_index +1
    end
    
    for i=1,12 do
      renoise.tool():add_keybinding{name=string.format("Pattern Editor:Paketti:ChordPplus (Add %02d)", i),
        invoke=function() JalexAdd(i) end
      }
    end
    
    for i=1,12 do
      renoise.tool():add_keybinding{name=string.format("Pattern Editor:Paketti:ChordsPlus (Sub %02d)", i),
        invoke=function() JalexAdd(-i) end
      }
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
    
    -- Add Previous Chord function and menu entry
    function previous_chord()
        current_chord_index = current_chord_index - 2 -- Go back two steps since next_chord() will add one
        if current_chord_index < 0 then
            current_chord_index = #chord_list - 1 -- Wrap to end of list
        end
        next_chord() -- Use existing next_chord to play and advance
    end

    

    -- MIDI mapping handler, maps values 0-127 to the list of chords
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
    
    -- Add keybindings dynamically based on the chord list
    for i, chord in ipairs(chord_list) do
        renoise.tool():add_keybinding{name="Pattern Editor:Paketti:" .. chord.name,
            invoke=chord.fn
        }
    end
    

    -- Add keybinding for cycling through chords
    renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Next Chord in List",
        invoke=next_chord
    }
    
    renoise.tool():add_midi_mapping{name="Paketti:Chord Selector [0-127]",invoke=function(midi_message) midi_chord_mapping(midi_message.int_value) end}
    
    -- Add menu entries for all chord functions
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Basic Triads - Major (3-4)",invoke=function() chordsplus(4,3) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Basic Triads - Minor (4-3)",invoke=function() chordsplus(3,4) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Basic Triads - Augmented (4-4)",invoke=function() chordsplus(4,4) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Basic Triads - Sus2 (2-5)",invoke=function() chordsplus(2,5) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Basic Triads - Sus4 (5-2)",invoke=function() chordsplus(5,2) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Seventh - Major 7 (4-3-4)",invoke=function() chordsplus(4,3,4) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Seventh - Minor 7 (3-4-3)",invoke=function() chordsplus(3,4,3) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Seventh - Dominant 7 (4-3-3)",invoke=function() chordsplus(4,3,3) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Seventh - Minor-Major 7 (3-4-4)",invoke=function() chordsplus(3,4,4) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Ninth - Major 9 (4-3-4-3)",invoke=function() chordsplus(4,3,4,3) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Ninth - Minor 9 (3-4-3-3)",invoke=function() chordsplus(3,4,3,3) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Ninth - Major 9 Simple (4-7-3)",invoke=function() chordsplus(4,7,3) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Ninth - Minor 9 Simple (3-7-4)",invoke=function() chordsplus(3,7,4) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Added - Major Add 9 (4-3-7)",invoke=function() chordsplus(4,3,7) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Added - Minor Add 9 (3-4-7)",invoke=function() chordsplus(3,4,7) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Added - Major 6 Add 9 (4-3-2-5)",invoke=function() chordsplus(4,3,2,5) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Added - Minor 6 Add 9 (3-4-2-5)",invoke=function() chordsplus(3,4,2,5) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Added - Major 9 Add 11 (4-3-4-3-3)",invoke=function() chordsplus(4,3,4,3,3) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Augmented - Aug6 (4-4-2)",invoke=function() chordsplus(4,4,2) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Augmented - Aug7 (4-4-3)",invoke=function() chordsplus(4,4,3) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Augmented - Aug8 (4-4-4)",invoke=function() chordsplus(4,4,4) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Augmented - Aug9 (4-3-3-5)",invoke=function() chordsplus(4,3,3,5) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Augmented - Aug10 (4-4-7)",invoke=function() chordsplus(4,4,7) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Augmented - Aug11 (4-3-3-4-4)",invoke=function() chordsplus(4,3,3,4,4) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Special - Octaves (12-12-12)",invoke=function() chordsplus(12,12,12) end }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Special - Next Chord",invoke=next_chord }
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Special - Previous Chord",invoke=previous_chord }
    
    -- Add menu entries for intervals 1-12 and their negative counterparts
    for i=1,12 do
        renoise.tool():add_menu_entry{name=string.format("Pattern Editor:Paketti ChordsPlus..:Add Intervals..:Add %d", i), 
            invoke=function() JalexAdd(i) end}
    end

    for i=1,12 do
        renoise.tool():add_menu_entry{name=string.format("Pattern Editor:Paketti ChordsPlus..:Sub Intervals..:Sub %d", i), 
            invoke=function() JalexAdd(-i) end}
    end
-------

-- Helper function to get all notes from a row and sort them
function GetAndSortNotes(line, ascending)
  local notes = {}
  local song = renoise.song()
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
  local song = renoise.song()
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
  local song = renoise.song()
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
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Note Sorter (Ascending)",invoke=NoteSorterAscending}
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Note Sorter (Descending)",invoke=NoteSorterDescending}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Note Sorter (Descending)",invoke=NoteSorterDescending}
---  
  function RandomizeVoicing()
    local song = renoise.song()
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
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti ChordsPlus..:Randomize Voicing for Notes in Row/Selection",invoke=function() RandomizeVoicing() end}
---
  -- Function to shift notes left or right
  function ShiftNotes(direction)
    local song = renoise.song()
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
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Shift Notes Right",invoke=function() ShiftNotes(1) end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Shift Notes Left",invoke=function() ShiftNotes(-1) end}
  
  

--------

function cycle_inversion(direction)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track_index = song.selected_track_index
  local track = song.tracks[track_index]
  local selection = song.selection_in_pattern

  if selection then
    -- 🚀 If there is a selection, process each row separately
    for line_index = selection.start_line, selection.end_line do
      process_row_inversion(pattern, track_index, line_index, selection.start_column, selection.end_column, direction)
    end
  else
    -- 🚀 No selection? Process only the current row at the cursor position
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



      
renoise.tool():add_keybinding {name="Pattern Editor:Paketti:Cycle Chord Inversion Up",invoke=function() cycle_inversion("up")
NoteSorterAscending() end}
renoise.tool():add_keybinding {name="Pattern Editor:Paketti:Cycle Chord Inversion Down",invoke=function() cycle_inversion("down")
NoteSorterAscending() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti ChordsPlus..:Cycle Chord Inversion Up",invoke=function() cycle_inversion("up")
NoteSorterAscending() end}  
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Cycle Chord Inversion Down",invoke=function() cycle_inversion("down")
NoteSorterAscending() end}
  


-- Function to apply a random chord from the chord_list
function RandomChord()
  local song = renoise.song()
  
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
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti ChordsPlus..:Random - Apply Random Chord",invoke=function() RandomChord() end}
renoise.tool():add_midi_mapping{name="Paketti:ChordsPlus Random Chord",invoke=function(message) if message:is_trigger() then RandomChord() end end}


function ExtractBassline()
  local song = renoise.song()
  local pattern = song.selected_pattern
  local source_track_index = song.selected_track_index
  local dest_track_index = source_track_index + 1
  
  -- Check if destination track exists
  if dest_track_index > song.sequencer_track_count then
    renoise.app():show_status("No track available after the current track")
    return
  end
  
  local source_track = pattern:track(source_track_index)
  local dest_track = pattern:track(dest_track_index)
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
      local dest_note_column = dest_track:line(line_index):note_column(1)
      dest_note_column.note_value = lowest_note_data.note_value
      dest_note_column.instrument_value = lowest_note_data.instrument_value
      dest_note_column.volume_value = lowest_note_data.volume_value
      dest_note_column.panning_value = lowest_note_data.panning_value
      dest_note_column.delay_value = lowest_note_data.delay_value
      changes_made = true
    end
  end
  
  if changes_made then
    renoise.app():show_status("Bassline extracted to track " .. dest_track_index)
  else
    renoise.app():show_status("No notes found to extract")
  end
end

-- Add menu entry and keybinding
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:ChordsPlus Extract Bassline to Next Track",
  invoke=function() ExtractBassline() end}
renoise.tool():add_menu_entry{name="--Pattern Editor:Paketti ChordsPlus..:Extract Bassline to Next Track",
  invoke=function() ExtractBassline() end}

  function ExtractHighestNote()
    local song = renoise.song()
    local pattern = song.selected_pattern
    local source_track_index = song.selected_track_index
    local dest_track_index = source_track_index + 1
    
    -- Check if destination track exists
    if dest_track_index > song.sequencer_track_count then
      renoise.app():show_status("No track available after the current track")
      return
    end
    
    local source_track = pattern:track(source_track_index)
    local dest_track = pattern:track(dest_track_index)
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
        local dest_note_column = dest_track:line(line_index):note_column(1)
        dest_note_column.note_value = highest_note_data.note_value
        dest_note_column.instrument_value = highest_note_data.instrument_value
        dest_note_column.volume_value = highest_note_data.volume_value
        dest_note_column.panning_value = highest_note_data.panning_value
        dest_note_column.delay_value = highest_note_data.delay_value
        changes_made = true
      end
    end
    
    if changes_made then
      renoise.app():show_status("Highest notes extracted to track " .. dest_track_index)
    else
      renoise.app():show_status("No notes found to extract")
    end
  end
  
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Extract Highest Note to Next Track",
    invoke=function() ExtractHighestNote() end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti ChordsPlus..:Extract Highest Note to Next Track",
    invoke=function() ExtractHighestNote() end}