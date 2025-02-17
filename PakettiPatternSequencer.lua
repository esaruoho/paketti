renoise.tool():add_menu_entry{name="--Pattern Sequencer:Paketti..:Show/Hide Pattern Matrix",invoke=function() showhidepatternmatrix() end}

-- Function to clone the currently selected pattern sequence row
function clone_current_sequence()
  -- Access the Renoise song
  local song = renoise.song()
  
  -- Retrieve the currently selected sequence index
  local current_sequence_pos = song.selected_sequence_index
  -- Get the total number of sequences
  local total_sequences = #song.sequencer.pattern_sequence

  -- Debug information
  print("Current Sequence Index:", current_sequence_pos)
  print("Total Sequences:", total_sequences)

  -- Clone the sequence range, appending it right after the current position
  if current_sequence_pos <= total_sequences then
    song.sequencer:clone_range(current_sequence_pos, current_sequence_pos)
    -- Debug information
    print("Cloned Sequence Index:", current_sequence_pos)
    -- Select the newly created sequence
    song.selected_sequence_index = current_sequence_pos + 1
  else
    renoise.app():show_status("Cannot clone the sequence: The current sequence is the last one.")
  end
end

renoise.tool():add_menu_entry{name="Pattern Sequencer:Paketti..:Clone Current Sequence",invoke=clone_current_sequence}
renoise.tool():add_menu_entry{name="Pattern Matrix:Paketti..:Clone Current Sequence",invoke=clone_current_sequence}
renoise.tool():add_keybinding{name="Global:Paketti:Clone Current Sequence",invoke=clone_current_sequence}
renoise.tool():add_midi_mapping{name="Paketti:Clone Current Sequence",invoke=clone_current_sequence}

---------
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Keep Sequence Sorted False",invoke=function() renoise.song().sequencer.keep_sequence_sorted=false end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Keep Sequence Sorted True",invoke=function() renoise.song().sequencer.keep_sequence_sorted=true end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Keep Sequence Sorted Toggle",invoke=function() 
if renoise.song().sequencer.keep_sequence_sorted==false then renoise.song().sequencer.keep_sequence_sorted=true else
renoise.song().sequencer.keep_sequence_sorted=false end end}

renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Keep Sequence Sorted False",invoke=function() renoise.song().sequencer.keep_sequence_sorted=false end}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Keep Sequence Sorted True",invoke=function() renoise.song().sequencer.keep_sequence_sorted=true end}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Keep Sequence Sorted Toggle",invoke=function() 
if renoise.song().sequencer.keep_sequence_sorted==false then renoise.song().sequencer.keep_sequence_sorted=true else
renoise.song().sequencer.keep_sequence_sorted=false end end}


