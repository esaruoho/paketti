local vb = renoise.ViewBuilder()
local dialog = nil

-- Function to create a vertical ruler that matches the height of the columns
function trackOutputRoutingsGUI_vertical_rule(height)
  return vb:vertical_aligner{
    mode="center",
    vb:space{height=2},
    vb:column{
      width=2,
      style="panel",
      height=height
    },
    vb:space{height=2}
  }
end

-- Function to create a horizontal rule
function trackOutputRoutingsGUI_horizontal_rule()
  return vb:horizontal_aligner{
    mode="justify", 
    width="100%", 
    vb:space{width=2}, 
    vb:row{
      height=2, 
      style="panel", 
      width="100%"
    }, 
    vb:space{width=2}
  }
end

-- Function to create the GUI
function pakettiTrackOutputRoutingsDialog()
if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end


  -- Get the number of tracks
  local num_tracks = #renoise.song().tracks
  local tracks_per_column = 18
  local num_columns = math.ceil(num_tracks / tracks_per_column)
  local track_row_height = 24 -- Approximate height of each track row
  local column_height = tracks_per_column * track_row_height

  -- Create a view for the dialog content
  local content = vb:row{
   -- margin=10,
   -- spacing=10
  }

  -- Table to store dropdown elements
  local dropdowns = {}

  -- Loop through each column
  for col = 1, num_columns do
    -- Create a column to hold up to 18 tracks
    local column_content = vb:column{
      --margin=5,
      --spacing=5,
      width=200 -- Set column width to accommodate track name and dropdown
    }

    -- Add tracks to the column
    for i = 1, tracks_per_column do
      local track_index = (col - 1) * tracks_per_column + i
      if track_index > num_tracks then break end

      local track = renoise.song().tracks[track_index]
      local track_name = track.name
      local available_output_routings = track.available_output_routings
      local current_output_routing = track.output_routing

      -- Determine if the track is a group
      local is_group = track.type == renoise.Track.TRACK_TYPE_GROUP

      -- Create the dropdown
      local dropdown = vb:popup{
        items = available_output_routings,
        value = table.find(available_output_routings, current_output_routing),
        width=220 -- Set width to 200% of 60 to be 120
      }
      
      -- Store the dropdown element
      table.insert(dropdowns, {dropdown = dropdown, track_index = track_index})

      -- Add the track name and dropdown in the same row, align dropdown to the right
      column_content:add_child(vb:row{
        vb:text{
          text = track_name,
          font = is_group and "bold" or "normal",
          style = is_group and "strong" or "normal",
          width=140 -- Allocate 70% width for track name
        },
        dropdown
      })
    end

    -- Add the column to the content
    content:add_child(column_content)

    -- Add a vertical rule between columns, but not after the last column
    if col < num_columns then
      content:add_child(trackOutputRoutingsGUI_vertical_rule(column_height))
    end
  end

  -- Add a horizontal rule
  content:add_child(trackOutputRoutingsGUI_horizontal_rule())

  -- OK and Cancel buttons
  content:add_child(vb:row{
    --spacing=5,
    vb:button{
      text="OK",
      width="50%", -- Set OK button width to 50%
      notifier=function()
        -- Apply changes to the output routings
        for _, entry in ipairs(dropdowns) do
          local dropdown = entry.dropdown
          local track_index = entry.track_index
          local track = renoise.song().tracks[track_index]
          local selected_routing = dropdown.items[dropdown.value]
          if selected_routing ~= track.output_routing then
            track.output_routing = selected_routing
          end
        end
        dialog:close()
      end
    },
  vb:button{
    text="Refresh",
    width="33%", -- Equal width for all buttons
    notifier=function()
      dialog:close()
      pakettiTrackOutputRoutingsDialog()
    end
  },

    vb:button{
      text="Cancel",
      width="50%", -- Set Cancel button width to 50%
      notifier=function()
        dialog:close()
      end
    }
  })

  -- Show the dialog
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Track Output Routings", content, keyhandler)
end

---
function PakettiSerialOutputRoutings(is_non_continual, noMaster, includeMaster)
  local availOut = renoise.song().selected_track.available_output_routings
  local seq_count = renoise.song().sequencer_track_count
  local send_count = renoise.song().send_track_count

  -- Determine the valid range of output routings based on noMaster flag
  local start_index = noMaster and 2 or 1
  local num_routings = #availOut - start_index + 1

  -- Ensure there are enough routings based on the configuration
  if num_routings < 1 then
    renoise.app():show_status("Not enough available output routings to apply the configuration!")
    return
  end

  local track_index = 1

  -- Function to assign output routings in sequence
  local function assign_routing(i)
    local routing_index
    if is_non_continual then
      -- Non-Continual mode: assign the last routing after exceeding available outputs
      routing_index = track_index + start_index - 1
      if routing_index > #availOut then routing_index = #availOut end
    else
      -- Continual mode: wrap around with modulo
      routing_index = ((track_index - 1) % num_routings) + start_index
    end
    renoise.song().tracks[i].output_routing = availOut[routing_index]
    track_index = track_index + 1
  end

  -- Loop through the sequencer tracks (normal tracks)
  for i = 1, seq_count do
    assign_routing(i)
  end

  -- Handle the Master track
  if includeMaster then
    assign_routing(seq_count + 1)
  else
    -- Assign Master track to the last available routing if not part of the sequence
    renoise.song().tracks[seq_count + 1].output_routing = availOut[#availOut]
  end

  -- Loop through the send tracks
  for i = 1, send_count do
    assign_routing(seq_count + 1 + i)
  end

  -- Print the output routings for all tracks (for debugging)
  for i = 1, seq_count + send_count + 1 do oprint(renoise.song().tracks[i].output_routing) end
end

renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Non-Continual, Skip Master, Exclude Master)",invoke=function() PakettiSerialOutputRoutings(true, true, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Continual, Skip Master, Exclude Master)",invoke=function() PakettiSerialOutputRoutings(false, true, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Non-Continual, Include Master, Exclude Master)",invoke=function() PakettiSerialOutputRoutings(true, false, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Continual, Include Master, Exclude Master)",invoke=function() PakettiSerialOutputRoutings(false, false, false) end}
renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Non-Continual, Skip Master, Include Master in Cycle)",invoke=function() PakettiSerialOutputRoutings(true, true, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Continual, Skip Master, Include Master in Cycle)",invoke=function() PakettiSerialOutputRoutings(false, true, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Non-Continual, Include Master, Include Master in Cycle)",invoke=function() PakettiSerialOutputRoutings(true, false, true) end}
renoise.tool():add_keybinding{name="Global:Paketti:Output Routing (Continual, Include Master, Include Master in Cycle)",invoke=function() PakettiSerialOutputRoutings(false, false, true) end}
------
function resetOutputRoutings()
local calculation = renoise.song().sequencer_track_count + 1
local calculationSends = calculation + renoise.song().send_track_count

for i=1,renoise.song().sequencer_track_count do
renoise.song().tracks[i].output_routing="Master"
end

for i=calculation+1,calculationSends do
renoise.song().tracks[i].output_routing="Master"
end
rprint (renoise.song().tracks[calculation].available_output_routings)
renoise.song().tracks[calculation].output_routing=renoise.song().tracks[calculation].available_output_routings[1]

end

renoise.tool():add_keybinding{name="Global:Paketti:Reset Output Routings to Master",invoke=function() resetOutputRoutings() end}




--------
function pakettiMidiSimpleOutputRoute(output)
  local track=renoise.song().selected_track
  if output<=#track.available_output_routings then
    track.output_routing=track.available_output_routings[output]
    renoise.app():show_status("Selected Track Output Routing set to "..output)
  else
    renoise.app():show_status("Selected Track Output Routing value out of range.")
  end
end

function pakettiMidiMasterOutputRoutings(output)
  local song=renoise.song()
  local masterTrack=song:track(song.sequencer_track_count+1)
  if output<=#masterTrack.available_output_routings then
    masterTrack.output_routing=masterTrack.available_output_routings[output]
    renoise.app():show_status("Master Track Output Routing set to "..output)
  else
    renoise.app():show_status("Master Track Output Routing value out of range.")
  end
end

for i=0,63 do 
  renoise.tool():add_midi_mapping{name="Paketti:Midi Set Selected Track Output Routing "..string.format("%02d",i),invoke=function(midi_message) pakettiMidiSimpleOutputRoute(i+1) end}
  renoise.tool():add_midi_mapping{name="Paketti:Midi Set Master Track Output Routing "..string.format("%02d",i),invoke=function(midi_message) pakettiMidiMasterOutputRoutings(i+1) end}
end

function AutoAssignOutputs()
  local song=renoise.song()
  local instrument = song.selected_instrument
  local samples = instrument.samples
  local sample_device_chains = instrument.sample_device_chains
  local available_outputs = sample_device_chains[1] 
    and sample_device_chains[1].available_output_routings 
    or {}

  -- Ensure sufficient output routings exist
  if #available_outputs < 2 then
    renoise.app():show_status("Not enough available output routings.")
    return
  end

  -- Determine the starting chain index based on pre-existing chains
  local pre_existing_chains = #sample_device_chains
  local start_chain_index = math.max(pre_existing_chains + 1, 1)
  if pre_existing_chains >= 2 then
    start_chain_index = 3
  elseif pre_existing_chains == 1 then
    start_chain_index = 2
  end

  -- Calculate the required number of chains (one per sample)
  local required_chains = start_chain_index + #samples - 1

  -- Add new chains if necessary
  for i = pre_existing_chains + 1, required_chains do
    instrument:insert_sample_device_chain_at(i)
  end

  -- Assign output routings and name the chains
  for i = 1, #samples do
    local chain_index = start_chain_index + i - 1
    local routing_index = (i - 1) % (#available_outputs - 1) + 2 -- Skip "Current Track"

    -- Fetch the chain
    local chain = sample_device_chains[chain_index]
    if not chain then
      renoise.app():show_status("Failed to fetch FX chain at index: " .. tostring(chain_index))
      return
    end

    -- Assign output routing and name the chain
    local routing_name = available_outputs[routing_index]
    chain.output_routing = routing_name
    chain.name = routing_name
  end

  renoise.app():show_status("FX chains assigned and outputs routed successfully.")
end

--------
-- Track-Based Output Calculator Functions
--------

-- Helper function to calculate next power of 2 >= n
local function nextPowerOf2(n)
  if n <= 0 then
    return 1
  end
  local power = 1
  while power < n do
    power = power * 2
  end
  return power
end

-- Calculate optimal number of outputs based on track count
-- includeMasterInCount: if true, count Master track; if false, exclude Master from count
-- Returns a table with calculation details
function PakettiCalculateOptimalOutputs(includeMasterInCount)
  local song = renoise.song()
  local seq_count = song.sequencer_track_count
  local send_count = song.send_track_count
  
  local track_count
  if includeMasterInCount then
    track_count = seq_count + 1 + send_count  -- +1 for Master
  else
    track_count = seq_count + send_count      -- exclude Master from count
  end
  
  local stereo_pairs = nextPowerOf2(track_count)
  local total_outputs = stereo_pairs * 2
  
  return {
    track_count = track_count,
    stereo_pairs = stereo_pairs,
    total_outputs = total_outputs,
    seq_count = seq_count,
    send_count = send_count,
    include_master = includeMasterInCount
  }
end

-- Apply sequential output routing to all tracks
-- includeMasterInRouting: if true, include Master in the sequential routing
-- Returns true on success, false if not enough outputs available
function PakettiApplySequentialOutputRouting(includeMasterInRouting)
  local song = renoise.song()
  local seq_count = song.sequencer_track_count
  local send_count = song.send_track_count
  local master_index = seq_count + 1
  
  -- Get available output routings from first track
  local available_outputs = song.tracks[1].available_output_routings
  
  -- Count how many tracks we need to route
  local total_tracks_to_route
  if includeMasterInRouting then
    total_tracks_to_route = seq_count + 1 + send_count  -- sequencer + master + sends
  else
    total_tracks_to_route = seq_count + send_count  -- sequencer + sends (master excluded)
  end
  
  -- Check if we have enough output buses (skip "Master" which is usually index 1)
  -- Available routings typically: "Master", "Bus 01", "Bus 02", etc.
  local available_buses = #available_outputs - 1  -- subtract 1 for "Master" routing
  
  if available_buses < total_tracks_to_route then
    local message = string.format(
      "Not enough output buses! Need %d buses, but only %d available. " ..
      "Please configure more outputs in Renoise plugin preferences.",
      total_tracks_to_route, available_buses
    )
    renoise.app():show_warning(message)
    return false
  end
  
  local bus_index = 2  -- Start at index 2 (first bus after "Master")
  
  -- Route sequencer tracks
  for i = 1, seq_count do
    if bus_index <= #available_outputs then
      song.tracks[i].output_routing = available_outputs[bus_index]
      print(string.format("Track %d (%s) -> %s", i, song.tracks[i].name, available_outputs[bus_index]))
      bus_index = bus_index + 1
    end
  end
  
  -- Route Master track (if included)
  if includeMasterInRouting then
    if bus_index <= #available_outputs then
      song.tracks[master_index].output_routing = available_outputs[bus_index]
      print(string.format("Master Track -> %s", available_outputs[bus_index]))
      bus_index = bus_index + 1
    end
  else
    -- If Master not in routing, set it to the last available output
    song.tracks[master_index].output_routing = available_outputs[#available_outputs]
    print(string.format("Master Track -> %s (last output)", available_outputs[#available_outputs]))
  end
  
  -- Route send tracks
  for i = 1, send_count do
    local send_track_index = master_index + i
    if bus_index <= #available_outputs then
      song.tracks[send_track_index].output_routing = available_outputs[bus_index]
      print(string.format("Send %d (%s) -> %s", i, song.tracks[send_track_index].name, available_outputs[bus_index]))
      bus_index = bus_index + 1
    end
  end
  
  return true
end

-- Dialog variable for output calculator
local output_calc_dialog = nil

-- Calculate, Ask (show dialog), then Set if user confirms
function PakettiOutputsCalculateAskSet(includeMasterInCount)
  -- Close existing dialog if open
  if output_calc_dialog and output_calc_dialog.visible then
    output_calc_dialog:close()
    output_calc_dialog = nil
    return
  end
  
  local calc = PakettiCalculateOptimalOutputs(includeMasterInCount)
  local song = renoise.song()
  local available_outputs = song.tracks[1].available_output_routings
  local available_buses = #available_outputs - 1
  
  local master_text = includeMasterInCount and "Yes" or "No"
  local has_enough_buses = available_buses >= calc.track_count
  
  local dialog_vb = renoise.ViewBuilder()
  
  local content = dialog_vb:column{
    margin = 10,
    spacing = 5,
    
    dialog_vb:text{
      text = "Track-Based Output Calculator",
      font = "bold",
      style = "strong"
    },
    
    dialog_vb:space{height = 5},
    
    dialog_vb:row{
      dialog_vb:text{text = "Sequencer Tracks:", width = 150},
      dialog_vb:text{text = tostring(calc.seq_count), font = "bold"}
    },
    
    dialog_vb:row{
      dialog_vb:text{text = "Send Tracks:", width = 150},
      dialog_vb:text{text = tostring(calc.send_count), font = "bold"}
    },
    
    dialog_vb:row{
      dialog_vb:text{text = "Include Master in Count:", width = 150},
      dialog_vb:text{text = master_text, font = "bold"}
    },
    
    dialog_vb:space{height = 15},
    
    dialog_vb:column{
      background = "panel",
      margin = 10,
      spacing = 8,
      dialog_vb:row{
        dialog_vb:text{text = "Total Tracks to Route:", width = 180},
        dialog_vb:text{text = tostring(calc.track_count), font = "big", style = "strong"}
      },
      dialog_vb:row{
        dialog_vb:text{text = "Recommended Stereo Pairs:", width = 180},
        dialog_vb:text{text = tostring(calc.stereo_pairs), font = "big", style = "strong"}
      },
      dialog_vb:space{height = 5},
      dialog_vb:row{
        dialog_vb:text{text = "Recommended Total Outputs:", width = 180, font = "bold", style = "strong"},
        dialog_vb:text{text = tostring(calc.total_outputs), font = "big", style = "strong"}
      }
    },
    
    dialog_vb:space{height = 15},
    
    dialog_vb:row{
      dialog_vb:text{text = "Available Output Buses:", width = 150},
      dialog_vb:text{
        text = tostring(available_buses),
        font = "bold",
        style = has_enough_buses and "normal" or "strong"
      }
    },
    
    dialog_vb:text{
      text = has_enough_buses 
        and "Status: Sufficient buses available" 
        or "Warning: Not enough buses! Configure more outputs in Renoise plugin preferences.",
      style = has_enough_buses and "normal" or "strong"
    },
    
    dialog_vb:space{height = 10},
    
    dialog_vb:row{
      spacing = 5,
      dialog_vb:button{
        text = "Apply Routing",
        width = 120,
        active = has_enough_buses,
        notifier = function()
          local success = PakettiApplySequentialOutputRouting(includeMasterInCount)
          if success then
            renoise.app():show_status(string.format(
              "Output routing applied: %d tracks -> %d stereo pairs (%d outputs)",
              calc.track_count, calc.stereo_pairs, calc.total_outputs
            ))
          end
          output_calc_dialog:close()
          output_calc_dialog = nil
        end
      },
      dialog_vb:button{
        text = "Cancel",
        width = 80,
        notifier = function()
          output_calc_dialog:close()
          output_calc_dialog = nil
        end
      }
    }
  }
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return output_calc_dialog end,
    function(value) output_calc_dialog = value end
  )
  
  local title = includeMasterInCount 
    and "Calculate Outputs (Include Master)" 
    or "Calculate Outputs (Exclude Master)"
  
  output_calc_dialog = renoise.app():show_custom_dialog(title, content, keyhandler)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Calculate and Set directly (no dialog)
function PakettiOutputsCalculateSet(includeMasterInCount)
  local calc = PakettiCalculateOptimalOutputs(includeMasterInCount)
  
  local success = PakettiApplySequentialOutputRouting(includeMasterInCount)
  
  if success then
    local master_text = includeMasterInCount and "incl. Master" or "excl. Master"
    renoise.app():show_status(string.format(
      "Routed %d tracks (%d seq + %d sends, %s) to %d stereo pairs (%d outputs)",
      calc.track_count, calc.seq_count, calc.send_count, master_text, calc.stereo_pairs, calc.total_outputs
    ))
  end
end

-- Keybindings for the new functions
renoise.tool():add_keybinding{
  name = "Global:Paketti:Calculate Outputs (Ask, Exclude Master)",
  invoke = function() PakettiOutputsCalculateAskSet(false) end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Calculate Outputs (Ask, Include Master)",
  invoke = function() PakettiOutputsCalculateAskSet(true) end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Calculate Outputs (Direct, Exclude Master)",
  invoke = function() PakettiOutputsCalculateSet(false) end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Calculate Outputs (Direct, Include Master)",
  invoke = function() PakettiOutputsCalculateSet(true) end
}
