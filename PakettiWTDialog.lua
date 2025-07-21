-- PakettiWTDialog.lua
-- Simple Wavetable Control Dialog for Paketti

local vb = renoise.ViewBuilder()
local wavetable_dialog = nil
local wavetable_content = nil
local current_sample_count = 0
local ignore_knob_change = false

-- Global function for MIDI mapping
function paketti_wavetable_knob_midi(message)
  if not wavetable_dialog or not wavetable_dialog.visible then
    return
  end
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then
    return
  end
  
  local sample_count = #instrument.samples
  if sample_count <= 1 then
    return
  end
  
  -- Map 0-127 MIDI to 1-sample_count
  local target_sample = math.floor((message.int_value / 127) * (sample_count - 1)) + 1
  target_sample = math.max(1, math.min(sample_count, target_sample))
  
  -- Update knob without triggering change
  ignore_knob_change = true
  wavetable_content.views.wt_knob.value = target_sample
  ignore_knob_change = false
  
  -- Apply velocity choke
  paketti_wt_set_sample(target_sample)
end

-- Set active sample using velocity choke
function paketti_wt_set_sample(sample_index)
  local song = renoise.song()
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then
    return
  end
  
  sample_index = math.max(1, math.min(#instrument.samples, sample_index))
  
  -- Apply velocity range choke (same as import function)
  for i = 1, #instrument.samples do
    local mapping = instrument.sample_mappings[1][i]
    if mapping then
      if i == sample_index then
        mapping.velocity_range = {0, 127} -- Enable selected sample
      else
        mapping.velocity_range = {0, 0} -- Disable all others
      end
    end
  end
  
  song.selected_sample_index = sample_index
  print("STATUS: Wavetable sample " .. sample_index .. " active")
end

-- Update dialog when instrument changes
function update_wavetable_dialog()
  if not wavetable_dialog or not wavetable_dialog.visible then
    return
  end
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if not instrument then
    wavetable_content.views.wt_name.text = "No Instrument"
    wavetable_content.views.wt_knob.active = false
    current_sample_count = 0
    return
  end
  
  local sample_count = #instrument.samples
  wavetable_content.views.wt_name.text = instrument.name
  wavetable_content.views.wt_knob.active = sample_count > 1
  
  if sample_count ~= current_sample_count then
    current_sample_count = sample_count
    if sample_count > 1 then
      wavetable_content.views.wt_knob.min = 1
      wavetable_content.views.wt_knob.max = sample_count
      
      -- Find currently active sample
      local active_sample = 1
      for i = 1, sample_count do
        local mapping = instrument.sample_mappings[1][i]
        if mapping and mapping.velocity_range[1] == 0 and mapping.velocity_range[2] == 127 then
          active_sample = i
          break
        end
      end
      
      ignore_knob_change = true
      wavetable_content.views.wt_knob.value = active_sample
      ignore_knob_change = false
    end
  end
end

-- Browse for wavetable file
function browse_wavetable()
  local file_path = renoise.app():prompt_for_filename_to_read({"*.wt", "*.*"}, "Import Wavetable")
  if file_path == "" then
    return
  end
  
  wt_loadsample(file_path)
  update_wavetable_dialog()
end

-- Create dialog content
function create_wavetable_dialog_content()
  return vb:column {
    margin = 4,
    spacing = 2,
    vb:button {
      text = "Browse for .WT",
      width = 120,
      height = 24,
      notifier = browse_wavetable
    },
    vb:text {
      id = "wt_name",
      text = "No Instrument",
      width = 120,
      style = "strong"
    },
    vb:rotary {
      id = "wt_knob",
      min = 1,
      max = 1,
      value = 1,
      width = 80,
      height = 80,
      active = false,
      notifier = function(value)
        if ignore_knob_change then return end
        paketti_wt_set_sample(value)
      end
    }
  }
end

-- Show wavetable dialog
function show_wavetable_dialog()
  if wavetable_dialog and wavetable_dialog.visible then
    wavetable_dialog:close()
    return
  end
  
  wavetable_content = create_wavetable_dialog_content()
  
  wavetable_dialog = renoise.app():show_custom_dialog("Paketti Wavetable", wavetable_content, my_keyhandler_func)
  
  -- Set focus to Renoise
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  update_wavetable_dialog()
end

-- Add instrument change observer
local function add_wavetable_observers()
  if renoise.song().selected_instrument_index_observable:has_notifier(update_wavetable_dialog) then
    renoise.song().selected_instrument_index_observable:remove_notifier(update_wavetable_dialog)
  end
  renoise.song().selected_instrument_index_observable:add_notifier(update_wavetable_dialog)
  
  if renoise.song().instruments_observable:has_notifier(update_wavetable_dialog) then
    renoise.song().instruments_observable:remove_notifier(update_wavetable_dialog)
  end
  renoise.song().instruments_observable:add_notifier(update_wavetable_dialog)
end

-- Remove observers
local function remove_wavetable_observers()
  pcall(function()
    if renoise.song().selected_instrument_index_observable:has_notifier(update_wavetable_dialog) then
      renoise.song().selected_instrument_index_observable:remove_notifier(update_wavetable_dialog)
    end
    if renoise.song().instruments_observable:has_notifier(update_wavetable_dialog) then
      renoise.song().instruments_observable:remove_notifier(update_wavetable_dialog)
    end
  end)
end

-- Song change handler
renoise.tool().app_new_document_observable:add_notifier(function()
  add_wavetable_observers()
  update_wavetable_dialog()
end)

-- Initialize observers
add_wavetable_observers()

-- Menu entries

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Wavetable Control...", invoke = show_wavetable_dialog}
renoise.tool():add_menu_entry{name="--Instrument Box:Paketti:Wavetable Control...", invoke = show_wavetable_dialog}
renoise.tool():add_keybinding{name="Global:Paketti:Wavetable Control", invoke = show_wavetable_dialog}

-- MIDI mapping for knob control
renoise.tool():add_midi_mapping{name="Paketti:Wavetable Sample Selector x[Knob]", invoke = paketti_wavetable_knob_midi} 