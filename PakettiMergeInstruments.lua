-- Function to merge samples and keymaps from source to target instrument
function PakettiMergeInstruments(source_index, target_index)
  local song = renoise.song()
  
  -- Validate instrument indices
  if not source_index or not target_index then
    renoise.app():show_error("Please select both source and target instruments")
    return false
  end
  
  -- Get instruments
  local source_instr = song.instruments[source_index]
  local target_instr = song.instruments[target_index]
  
  if not source_instr or not target_instr then
    renoise.app():show_error("Invalid instrument indices")
    return false
  end
  
  -- Check if target has slices
  for _, sample in ipairs(target_instr.samples) do
    if #sample.slice_markers > 0 then
      renoise.app():show_error("Cannot merge - target instrument has slices")
      return false
    end
  end
  
  print(string.format("\nMerging from instrument #%d (%s) to instrument #%d (%s)", 
    source_index, source_instr.name, target_index, target_instr.name))
  print(string.format("Source has %d samples, target has %d samples\n",
    #source_instr.samples, #target_instr.samples))

  for idx, source_sample in ipairs(source_instr.samples) do
    print(string.format("Processing sample #%d in instrument #%d:", idx, source_index))
    print(string.format("  SOURCE SAMPLE:"))
    print(string.format("    - Name: %s", source_sample.name))
    print(string.format("    - Has data: %s", tostring(source_sample.sample_buffer.has_sample_data)))
    print(string.format("    - Frames: %d", source_sample.sample_buffer.number_of_frames))
    print(string.format("    - Channels: %d", source_sample.sample_buffer.number_of_channels))
    print(string.format("    - Sample rate: %d", source_sample.sample_buffer.sample_rate))
    print(string.format("    - Bit depth: %d", source_sample.sample_buffer.bit_depth))
    
    if not source_sample.sample_buffer.has_sample_data then
      print(string.format("WARNING: Skipping empty sample #%d in instrument #%d", idx, source_index))
    else
      -- Select the target instrument
      song.selected_instrument_index = target_index
      
      print(string.format("  Creating new sample in instrument #%d...", target_index))
      local target_slot = #song.selected_instrument.samples + 1
      song.selected_instrument:insert_sample_at(target_slot)
      
      print(string.format("  Copying sample data..."))
      song.selected_instrument.samples[target_slot]:copy_from(song.instruments[source_index].samples[idx])
      
      local new_sample = song.selected_instrument.samples[target_slot]
      print(string.format("  TARGET SAMPLE:"))
      print(string.format("    - Has data: %s", tostring(new_sample.sample_buffer.has_sample_data)))
      print(string.format("    - Frames: %d", new_sample.sample_buffer.number_of_frames))
      print(string.format("    - Channels: %d", new_sample.sample_buffer.number_of_channels))
      print(string.format("    - Sample rate: %d", new_sample.sample_buffer.sample_rate))
      print(string.format("    - Bit depth: %d", new_sample.sample_buffer.bit_depth))
      
      if new_sample.sample_buffer.number_of_frames ~= source_sample.sample_buffer.number_of_frames then
        print(string.format("ERROR: Copy failed - Source: %d frames, Target: %d frames", 
          source_sample.sample_buffer.number_of_frames,
          new_sample.sample_buffer.number_of_frames))
      end
    end
    print("") -- Empty line between samples
  end
  
  -- Copy overlap mode
  target_instr.sample_mapping_overlap_mode = source_instr.sample_mapping_overlap_mode
  
  renoise.app():show_status(string.format("Merged %d samples from instrument %d to %d", 
    #source_instr.samples, source_index, target_index))
  return true
end

-- Function to convert number to hex string (00-FF)
local function toHex(num)
  return string.format("%02X", num-1)
end

-- Function to show the merge instruments dialog
local function show_merge_dialog(initial_source_index, initial_target_index)
  local vb = renoise.ViewBuilder()
  local dialog
  local song = renoise.song()
  
  local source_index = initial_source_index or 1
  local target_index = initial_target_index or 2
  
  -- Create text views first so we can reference them
  local source_name_text = vb:text {
    text = song.instruments[source_index].name,
    font = "italic"
  }
  
  local target_name_text = vb:text {
    text = song.instruments[target_index].name,
    font = "italic"
  }
  
  -- Function to update instrument name displays
  local function update_names()
    source_name_text.text = song.instruments[source_index].name
    target_name_text.text = song.instruments[target_index].name
  end
  
  local content = vb:column {
    vb:text { 
      text = "Merge samples and keymaps from source to target instrument",
      width = "100%"
    },
    vb:space { height = 5 },
    vb:row {
      vb:text { 
        text = "Source Instrument",
        width = 100,
      },
      vb:row {
        vb:valuebox {
          min = 1,
          max = #song.instruments,
          value = source_index,
          tostring = function(value) return toHex(value) end,
          tonumber = function(str) return tonumber(str, 16) + 1 end,
          notifier = function(value)
            source_index = value
            update_names()
          end
        },
        vb:space { width = 5 },
        source_name_text
      }
    },
    vb:space { height = 3 },
    vb:row {
      vb:text { 
        text = "Target Instrument",
        width = 100,
      },
      vb:row {
        vb:valuebox {
          min = 1,
          max = #song.instruments,
          value = target_index,
          tostring = function(value) return toHex(value) end,
          tonumber = function(str) return tonumber(str, 16) + 1 end,
          notifier = function(value)
            target_index = value
            update_names()
          end
        },
        vb:space { width = 5 },
        target_name_text
      }
    },
    vb:space { height = 5 },
    vb:button {
      text = "Merge",
      width = "100%",
      notifier = function()
        if source_index == target_index then
          renoise.app():show_error("Source and target must be different")
          return
        end
        if PakettiMergeInstruments(source_index, target_index) then
          dialog:close()
        end
      end
    }
  }
  
  dialog = renoise.app():show_custom_dialog("Merge Instruments", content)
end

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Instruments..:Merge Instruments...",
  invoke = function()
    local song = renoise.song()
    local target_index = song.selected_instrument_index
    local source_index = target_index - 1
    if source_index < 1 then
      source_index = target_index + 1
    end
    show_merge_dialog(source_index, target_index)
  end
}

renoise.tool():add_menu_entry{
  name = "Instrument Box:Paketti..:Merge Instruments...",
  invoke = function()
    local song = renoise.song()
    local target_index = song.selected_instrument_index
    local source_index = target_index - 1
    if source_index < 1 then
      source_index = target_index + 1
    end
    show_merge_dialog(source_index, target_index)
  end
}



