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
      renoise.tool():add_keybinding{
        name=string.format("Pattern Editor:Paketti:Chordsplus (Add %02d)", i),
        invoke=function() JalexAdd(i) end
      }
    end
    
    for i=1,12 do
      renoise.tool():add_keybinding{
        name=string.format("Pattern Editor:Paketti:Chordsplus (Sub %02d)", i),
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
        {name="Chordsplus 3-4 (Maj)", fn=function() chordsplus(4,3) end},
        {name="Chordsplus 4-3 (Min)", fn=function() chordsplus(3,4) end},
        {name="Chordsplus 4-3-4 (Maj7)", fn=function() chordsplus(4,3,4) end},
        {name="Chordsplus 3-4-3 (Min7)", fn=function() chordsplus(3,4,3) end},
        {name="Chordsplus 4-4-3 (Maj7+5)", fn=function() chordsplus(4,4,3) end},
        {name="Chordsplus 3-5-2 (Min7+5)", fn=function() chordsplus(3,5,2) end},
        {name="Chordsplus 4-3-3 (Maj Dominant 7th)", fn=function() chordsplus(4,3,3) end}, -- MajMajor7
        {name="Chordsplus 3-4-4 (MinMaj7)", fn=function() chordsplus(3,4,4) end}, -- MinorMajor7
        {name="Chordsplus 4-3-4-3 (Maj9)", fn=function() chordsplus(4,3,4,3) end},
        {name="Chordsplus 3-4-3-3 (Min9)", fn=function() chordsplus(3,4,3,3) end},
        {name="Chordsplus 4-3-7 (Maj Added 9th)", fn=function() chordsplus(4,3,7) end},
        {name="Chordsplus 3-4-7 (Min Added 9th)", fn=function() chordsplus(3,4,7) end},
        {name="Chordsplus 4-7-3 (Maj9 Simplified)", fn=function() chordsplus(4,7,3) end}, -- Maj9 without 5th
        
        {name="Chordsplus 3-7-4 (Min9 Simplified)", fn=function() chordsplus(3,7,4) end}, -- Min9 without 5th
        {name="Chordsplus 3-8-3 (mM9 Simplified)", fn=function() chordsplus(3,8,3) end}, -- MinorMajor9 without 5th
        {name="Chordsplus 4-3-4-4 (MM9)", fn=function() chordsplus(4,3,4,4) end}, -- MajorMajor9 with Augmented 9th
        {name="Chordsplus 3-4-4-3 (mM9)", fn=function() chordsplus(3,4,4,3) end}, -- MinorMajor9
        {name="Chordsplus 4-3-2-5 (Maj6 Add9)", fn=function() chordsplus(4,3,2,5) end}, -- Maj6 Add9
        {name="Chordsplus 3-4-2-5 (Min6 Add9)", fn=function() chordsplus(3,4,2,5) end}, -- Min6 Add9
        {name="Chordsplus 2-5 (Sus2)", fn=function() chordsplus(2,5) end},
        {name="Chordsplus 5-2 (Sus4)", fn=function() chordsplus(5,2) end},
        {name="Chordsplus 5-2-3 (7Sus4)", fn=function() chordsplus(5,2,3) end},
        {name="Chordsplus 4-4 (Aug5)", fn=function() chordsplus(4,4) end},
        {name="Chordsplus 4-4-2 (Aug6)", fn=function() chordsplus(4,4,2) end},
        {name="Chordsplus 4-4-3 (Aug7)", fn=function() chordsplus(4,4,3) end},
        {name="Chordsplus 4-4-4 (Aug8)", fn=function() chordsplus(4,4,4) end},  
        {name="Chordsplus 4-3-3-5 (Aug9)", fn=function() chordsplus(4,3,3,5) end},
        {name="Chordsplus 4-4-7 (Aug10)", fn=function() chordsplus(4,4,7) end},
        {name="Chordsplus 4-3-3-4-4 (Aug11)", fn=function() chordsplus(4,3,3,4,4) end},
        {name="Chordsplus 12-12-12 (Octaves)", fn=function() chordsplus(12,12,12) end}
    }
    
    local current_chord_index = 1 -- Start at the first chord
    
    -- Function to advance to the next chord in the list
    local function next_chord()
        chord_list[current_chord_index].fn() -- Invoke the current chord function
        renoise.app():show_status("Played: " .. chord_list[current_chord_index].name)
        current_chord_index = current_chord_index + 1
        if current_chord_index > #chord_list then
            current_chord_index = 1 -- Wrap back to the first chord
        end
    end
    
    -- Add Previous Chord function and menu entry
    local function previous_chord()
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
        renoise.tool():add_keybinding{
            name="Pattern Editor:Paketti:" .. chord.name,
            invoke=chord.fn
        }
    end
    

    -- Add keybinding for cycling through chords
    renoise.tool():add_keybinding{
        name="Pattern Editor:Paketti:Next Chord in List",
        invoke=next_chord
    }
    
    renoise.tool():add_midi_mapping{name="Paketti:Chord Selector [0-127]",invoke=function(midi_message) midi_chord_mapping(midi_message.int_value) end}
    
    -- Add menu entries for all chord functions
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Basic Triads - Major (3-4)", invoke = function() chordsplus(4,3) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Basic Triads - Minor (4-3)", invoke = function() chordsplus(3,4) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Basic Triads - Augmented (4-4)", invoke = function() chordsplus(4,4) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Basic Triads - Sus2 (2-5)", invoke = function() chordsplus(2,5) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Basic Triads - Sus4 (5-2)", invoke = function() chordsplus(5,2) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Seventh - Major 7 (4-3-4)", invoke = function() chordsplus(4,3,4) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Seventh - Minor 7 (3-4-3)", invoke = function() chordsplus(3,4,3) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Seventh - Dominant 7 (4-3-3)", invoke = function() chordsplus(4,3,3) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Seventh - Minor-Major 7 (3-4-4)", invoke = function() chordsplus(3,4,4) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Ninth - Major 9 (4-3-4-3)", invoke = function() chordsplus(4,3,4,3) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Ninth - Minor 9 (3-4-3-3)", invoke = function() chordsplus(3,4,3,3) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Ninth - Major 9 Simple (4-7-3)", invoke = function() chordsplus(4,7,3) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Ninth - Minor 9 Simple (3-7-4)", invoke = function() chordsplus(3,7,4) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Added - Major Add 9 (4-3-7)", invoke = function() chordsplus(4,3,7) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Added - Minor Add 9 (3-4-7)", invoke = function() chordsplus(3,4,7) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Added - Major 6 Add 9 (4-3-2-5)", invoke = function() chordsplus(4,3,2,5) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Added - Minor 6 Add 9 (3-4-2-5)", invoke = function() chordsplus(3,4,2,5) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Augmented - Aug6 (4-4-2)", invoke = function() chordsplus(4,4,2) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Augmented - Aug7 (4-4-3)", invoke = function() chordsplus(4,4,3) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Augmented - Aug8 (4-4-4)", invoke = function() chordsplus(4,4,4) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Augmented - Aug9 (4-3-3-5)", invoke = function() chordsplus(4,3,3,5) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Augmented - Aug10 (4-4-7)", invoke = function() chordsplus(4,4,7) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Augmented - Aug11 (4-3-3-4-4)", invoke = function() chordsplus(4,3,3,4,4) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Special - Octaves (12-12-12)", invoke = function() chordsplus(12,12,12) end }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Special - Next Chord", invoke = next_chord }
    renoise.tool():add_menu_entry { name = "Pattern Editor:Paketti ChordsPlus..:Special - Previous Chord", invoke = previous_chord }
    
    -- Add menu entries for intervals 1-12 and their negative counterparts
    for i=1,12 do
        renoise.tool():add_menu_entry { 
            name = string.format("Pattern Editor:Paketti ChordsPlus..:Add Intervals..:Add %d", i), 
            invoke = function() JalexAdd(i) end 
        }
    end

    for i=1,12 do
        renoise.tool():add_menu_entry { 
            name = string.format("Pattern Editor:Paketti ChordsPlus..:Sub Intervals..:Sub %d", i), 
            invoke = function() JalexAdd(-i) end 
        }
    end

