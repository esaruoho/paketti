-- PakettiSliceSafely.lua
-- Non-destructive slicing workflow for Renoise
-- Part of the Paketti SlicePro family
--
-- When an instrument has multiple samples, SliceSafely:
-- 1. Slices the selected sample
-- 2. Isolates slices to a new instrument
-- 3. Preserves OTHER samples from the original instrument
-- Result: New instrument with slices + all other samples intact

local vb = renoise.ViewBuilder()
local slicesafely_dialog = nil

--------------------------------------------------------------------------------
-- Core SliceSafely Function
--------------------------------------------------------------------------------

function SliceSafelyWipeAndSlice(slice_count)
  local song = renoise.song()
  local instrument = song.selected_instrument
  local selected_sample_index = song.selected_sample_index
  local original_instrument_index = song.selected_instrument_index
  
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("SliceSafely: No instrument or samples selected")
    return
  end
  
  local sample = instrument.samples[selected_sample_index]
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("SliceSafely: Selected sample has no data")
    return
  end
  
  -- If only 1 sample, just use normal slicerough
  if #instrument.samples == 1 then
    slicerough(slice_count)
    renoise.app():show_status("SliceSafely: Single sample - used normal Wipe&Slice")
    return
  end
  
  -- Remember other samples (not the one being sliced)
  -- We need to copy the sample buffers before slicing destroys them
  local other_samples_info = {}
  for i = 1, #instrument.samples do
    if i ~= selected_sample_index then
      local src_sample = instrument.samples[i]
      if src_sample.sample_buffer and src_sample.sample_buffer.has_sample_data then
        table.insert(other_samples_info, {
          name = src_sample.name,
          sample_ref = src_sample,
          original_index = i
        })
      end
    end
  end
  
  local preserved_count = #other_samples_info
  
  -- Create undo point
  song:describe_undo("SliceSafely Wipe&Slice " .. slice_count)
  
  -- First, make sure the sample to slice is selected
  song.selected_sample_index = selected_sample_index
  
  -- Slice the selected sample using slicerough
  slicerough(slice_count)
  
  -- Now isolate slices to new instrument
  -- This creates a new instrument with the slices as independent samples
  PakettiIsolateSlicesToInstrument()
  
  -- The new instrument should now be selected
  local new_instrument = song.selected_instrument
  local new_instrument_index = song.selected_instrument_index
  
  -- Copy other samples to the new instrument
  -- We need to go back to original instrument and copy from there
  local original_instrument = song.instruments[original_instrument_index]
  
  for _, info in ipairs(other_samples_info) do
    -- Find the sample in the original instrument
    local src_sample = nil
    for i = 1, #original_instrument.samples do
      if original_instrument.samples[i].name == info.name then
        src_sample = original_instrument.samples[i]
        break
      end
    end
    
    if src_sample and src_sample.sample_buffer and src_sample.sample_buffer.has_sample_data then
      new_instrument:insert_sample_at(#new_instrument.samples + 1)
      new_instrument.samples[#new_instrument.samples]:copy_from(src_sample)
    end
  end
  
  renoise.app():show_status(string.format("SliceSafely: Created %d slices + preserved %d other samples", 
    slice_count, preserved_count))
end

--------------------------------------------------------------------------------
-- SliceSafely Dialog
--------------------------------------------------------------------------------

function SliceSafelyDialog()
  -- Close existing dialog if open
  if slicesafely_dialog and slicesafely_dialog.visible then
    slicesafely_dialog:close()
    slicesafely_dialog = nil
  end
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    renoise.app():show_status("SliceSafely: No instrument or samples selected")
    return
  end
  
  local sample_count = #instrument.samples
  local selected_sample = song.selected_sample
  local selected_sample_name = selected_sample and selected_sample.name or "Unknown"
  
  vb = renoise.ViewBuilder()
  
  local dialog_content = vb:column{
    margin = 10,
    spacing = 8,
    
    -- Info section
    vb:row{
      vb:text{text = "Instrument: " .. instrument.name, font = "bold"}
    },
    vb:row{
      vb:text{text = string.format("Samples in instrument: %d", sample_count)}
    },
    vb:row{
      vb:text{text = "Selected sample: " .. selected_sample_name}
    },
    
    vb:space{height = 5},
    
    -- Warning/Info based on sample count
    vb:row{
      vb:text{
        text = sample_count > 1 
          and string.format("Will preserve %d other sample(s) in new instrument", sample_count - 1)
          or "Single sample - will use normal Wipe&Slice",
        style = sample_count > 1 and "strong" or "disabled"
      }
    },
    
    vb:space{height = 10},
    
    -- Slice buttons row 1
    vb:row{
      vb:text{text = "Slice Safely:"},
      vb:button{text = "2", width = 30, notifier = function() 
        SliceSafelyWipeAndSlice(2)
        if slicesafely_dialog then slicesafely_dialog:close() end
      end},
      vb:button{text = "4", width = 30, notifier = function() 
        SliceSafelyWipeAndSlice(4)
        if slicesafely_dialog then slicesafely_dialog:close() end
      end},
      vb:button{text = "8", width = 30, notifier = function() 
        SliceSafelyWipeAndSlice(8)
        if slicesafely_dialog then slicesafely_dialog:close() end
      end},
      vb:button{text = "16", width = 35, notifier = function() 
        SliceSafelyWipeAndSlice(16)
        if slicesafely_dialog then slicesafely_dialog:close() end
      end},
      vb:button{text = "32", width = 35, notifier = function() 
        SliceSafelyWipeAndSlice(32)
        if slicesafely_dialog then slicesafely_dialog:close() end
      end},
      vb:button{text = "64", width = 35, notifier = function() 
        SliceSafelyWipeAndSlice(64)
        if slicesafely_dialog then slicesafely_dialog:close() end
      end},
      vb:button{text = "128", width = 40, notifier = function() 
        SliceSafelyWipeAndSlice(128)
        if slicesafely_dialog then slicesafely_dialog:close() end
      end},
      vb:button{text = "256", width = 40, notifier = function() 
        SliceSafelyWipeAndSlice(256)
        if slicesafely_dialog then slicesafely_dialog:close() end
      end}
    },
    
    vb:space{height = 10},
    
    -- Close button
    vb:row{
      vb:button{
        text = "Close",
        width = 80,
        notifier = function()
          if slicesafely_dialog and slicesafely_dialog.visible then
            slicesafely_dialog:close()
            slicesafely_dialog = nil
          end
        end
      }
    }
  }
  
  slicesafely_dialog = renoise.app():show_custom_dialog("SliceSafely", dialog_content)
end

--------------------------------------------------------------------------------
-- Menu Entries
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:SliceSafely:SliceSafely Dialog...", invoke=SliceSafelyDialog}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti..:SliceSafely:SliceSafely (002)", invoke=function() SliceSafelyWipeAndSlice(2) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:SliceSafely:SliceSafely (004)", invoke=function() SliceSafelyWipeAndSlice(4) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:SliceSafely:SliceSafely (008)", invoke=function() SliceSafelyWipeAndSlice(8) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:SliceSafely:SliceSafely (016)", invoke=function() SliceSafelyWipeAndSlice(16) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:SliceSafely:SliceSafely (032)", invoke=function() SliceSafelyWipeAndSlice(32) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:SliceSafely:SliceSafely (064)", invoke=function() SliceSafelyWipeAndSlice(64) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:SliceSafely:SliceSafely (128)", invoke=function() SliceSafelyWipeAndSlice(128) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti..:SliceSafely:SliceSafely (256)", invoke=function() SliceSafelyWipeAndSlice(256) end}

renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:SliceSafely:SliceSafely Dialog...", invoke=SliceSafelyDialog}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti..:SliceSafely:SliceSafely (002)", invoke=function() SliceSafelyWipeAndSlice(2) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:SliceSafely:SliceSafely (004)", invoke=function() SliceSafelyWipeAndSlice(4) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:SliceSafely:SliceSafely (008)", invoke=function() SliceSafelyWipeAndSlice(8) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:SliceSafely:SliceSafely (016)", invoke=function() SliceSafelyWipeAndSlice(16) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:SliceSafely:SliceSafely (032)", invoke=function() SliceSafelyWipeAndSlice(32) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:SliceSafely:SliceSafely (064)", invoke=function() SliceSafelyWipeAndSlice(64) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:SliceSafely:SliceSafely (128)", invoke=function() SliceSafelyWipeAndSlice(128) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti..:SliceSafely:SliceSafely (256)", invoke=function() SliceSafelyWipeAndSlice(256) end}

--------------------------------------------------------------------------------
-- Keybindings
--------------------------------------------------------------------------------

renoise.tool():add_keybinding{name="Sample Editor:Paketti:SliceSafely Dialog...", invoke=SliceSafelyDialog}
renoise.tool():add_keybinding{name="Global:Paketti:SliceSafely Dialog...", invoke=SliceSafelyDialog}

--------------------------------------------------------------------------------
-- MIDI Mappings
--------------------------------------------------------------------------------

renoise.tool():add_midi_mapping{name="Paketti:SliceSafely Dialog...", invoke=function(message) if message:is_trigger() then SliceSafelyDialog() end end}

print("PakettiSliceSafely.lua loaded")



