local dialog = nil
local view_builder = nil
local debug_mode = true -- Set to true to see what's happening

-- Base note calculation modes
local BASE_NOTE_MODES = {
  ORIGINAL = 1,
  LOWEST = 2,
  MIDDLE = 3,
  HIGHEST = 4
}

local function debug_print(...)
  if debug_mode then
    print(...)
  end
end

-- Helper function to ensure we're in the right view and handle dialog state
local function setup_environment()
  -- If dialog is already open, close it and return false
  if dialog and dialog.visible then
    debug_print("Dialog already open, closing...")
    dialog:close()
    dialog = nil
    return false
  end
  
  -- Ensure we're in the keyzone view
  if renoise.app().window.active_middle_frame ~= 
     renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES then
    renoise.app().window.active_middle_frame = 
      renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES
    debug_print("Switched to keyzone view")
  end
  
  return true
end

-- Function to get base note based on mode
local function get_base_note(start_note, end_note, original_base_note, base_note_mode)
  if base_note_mode == BASE_NOTE_MODES.ORIGINAL then
    return original_base_note
  elseif base_note_mode == BASE_NOTE_MODES.LOWEST then
    return start_note
  elseif base_note_mode == BASE_NOTE_MODES.MIDDLE then
    return math.floor(start_note + (end_note - start_note) / 2)
  else -- BASE_NOTE_MODES.HIGHEST
    return end_note
  end
end

-- Store original positions for transpose calculation
local original_positions = {}

-- Function to store original keyzone positions
local function store_original_positions()
  local instrument = renoise.song().selected_instrument
  if not instrument or #instrument.samples == 0 then
    return
  end
  
  original_positions = {}
  for idx, sample in ipairs(instrument.samples) do
    local smap = sample.sample_mapping
    original_positions[idx] = {
      base_note = smap.base_note,
      note_range = {smap.note_range[1], smap.note_range[2]}
    }
  end
  debug_print("Stored original positions for " .. #original_positions .. " samples")
end

-- Function to transpose from original positions (not cumulative)
local function transpose_keyzones(transpose_by)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    return
  end
  
  if #original_positions == 0 then
    store_original_positions()
  end
  
  debug_print(string.format("Transposing %d samples by %d semitones from original", #instrument.samples, transpose_by))
  
  local samples_transposed = 0
  local samples_clamped = 0
  local clamp_info = {}
  
  for idx, sample in ipairs(instrument.samples) do
    if original_positions[idx] then
      local smap = sample.sample_mapping
      local orig = original_positions[idx]
      
      local new_base_note = orig.base_note + transpose_by
      local new_note_range_start = orig.note_range[1] + transpose_by
      local new_note_range_end = orig.note_range[2] + transpose_by
      
      -- Clamp to MIDI range (0-119) instead of skipping
      local clamped_base_note = math.max(0, math.min(119, new_base_note))
      local clamped_range_start = math.max(0, math.min(119, new_note_range_start))
      local clamped_range_end = math.max(0, math.min(119, new_note_range_end))
      
      -- Ensure range is valid (start <= end)
      if clamped_range_start > clamped_range_end then
        clamped_range_end = clamped_range_start
      end
      
      -- Track if any clamping occurred
      local was_clamped = (clamped_base_note ~= new_base_note) or 
                         (clamped_range_start ~= new_note_range_start) or 
                         (clamped_range_end ~= new_note_range_end)
      
      -- Apply the (possibly clamped) values
      smap.base_note = clamped_base_note
      smap.note_range = {clamped_range_start, clamped_range_end}
      samples_transposed = samples_transposed + 1
      
      if was_clamped then
        samples_clamped = samples_clamped + 1
        table.insert(clamp_info, string.format("Sample %d clamped to %d-%d", idx, clamped_range_start, clamped_range_end))
        debug_print(string.format("Sample %d clamped to notes %d-%d (base: %d)", idx, clamped_range_start, clamped_range_end, clamped_base_note))
      else
        debug_print(string.format("Sample %d transposed to notes %d-%d (base: %d)", idx, clamped_range_start, clamped_range_end, clamped_base_note))
      end
    end
  end
  
  -- Show meaningful status message
  if samples_clamped > 0 then
    renoise.app():show_status(string.format("Transposed %d samples by %d semitones (%d clamped to MIDI limits)", 
      samples_transposed, transpose_by, samples_clamped))
    print(string.format("-- Paketti Transpose: %d samples clamped to MIDI range (0-119)", samples_clamped))
  elseif samples_transposed > 0 then
    renoise.app():show_status(string.format("Transposed %d samples by %d semitones", samples_transposed, transpose_by))
  else
    renoise.app():show_status("No samples to transpose")
  end
end

-- Function to distribute samples across velocity layers
local function distribute_velocity_layers(first_is_loudest, min_velocity, max_velocity, layer_count)
  local instrument = renoise.song().selected_instrument
  
  if not instrument or #instrument.samples == 0 then
    return
  end
  
  local custom_count = layer_count or #instrument.samples
  debug_print(string.format("Distributing %d samples across velocity layers (count: %d)", #instrument.samples, custom_count))
  
  -- Scale function for velocity ranges
  local function scale_value(value, in_min, in_max, out_min, out_max)
    return (((value - in_min) * (out_max / (in_max - in_min) - (out_min / (in_max - in_min)))) + out_min)
  end
  
  for idx = 1, #instrument.samples do
    local idx_custom = idx
    if custom_count then
      idx_custom = idx % custom_count
      if idx_custom == 0 then
        idx_custom = custom_count
      end
    end
    
    local sample = instrument.samples[idx]
    local smap = sample.sample_mapping
    
    local vel_from, vel_to
    if first_is_loudest then
      vel_from = (128 / custom_count) * (idx_custom - 1)   
      vel_to = ((128 / custom_count) * idx_custom) - 1
    else
      vel_from = (128 / custom_count) * (custom_count - idx_custom)
      vel_to = (128 / custom_count) * (custom_count - (idx_custom - 1)) - 1
    end
    
    vel_from = scale_value(vel_from, 0, 128, min_velocity, max_velocity)
    vel_to = scale_value(vel_to, 0, 128, min_velocity, max_velocity)
    
    -- Clamp to valid velocity range
    vel_from = math.max(0, math.min(127, math.floor(vel_from)))
    vel_to = math.max(0, math.min(127, math.floor(vel_to)))
    
    smap.velocity_range = {vel_from, vel_to}
    
    debug_print(string.format("Sample %d velocity range: %d-%d", idx, vel_from, vel_to))
  end
  
  renoise.app():show_status(string.format("Distributed %d samples across velocity layers", #instrument.samples))
end

-- Function to distribute samples across keyzones
local function distribute_samples(keys_per_sample, base_note_mode)
  local instrument = renoise.song().selected_instrument
  
  if not instrument then
    renoise.app():show_warning("No instrument selected!")
    return
  end
  
  -- Get fresh sample count
  local num_samples = #instrument.samples
  
  if num_samples == 0 then
    renoise.app():show_warning("No samples in instrument!")
    return
  end
  
  -- Clear original positions when distributing fresh
  original_positions = {}
  
  debug_print(string.format("Distributing %d samples with %d keys each", num_samples, keys_per_sample))
  
  -- For each sample, update its mapping to the new range
  local mapped_samples = 0
  local reached_limit = false
  
  for sample_idx = 1, num_samples do
    local sample = instrument.samples[sample_idx]
    if sample then
      -- Calculate the new note range (starting from C-0 which is note 0)
      local start_note = (sample_idx - 1) * keys_per_sample
      local end_note = start_note + (keys_per_sample - 1)
      
      -- Check if we would exceed the MIDI range
      if start_note > 119 then
        -- We've reached the limit, stop mapping
        debug_print(string.format("Sample %d would start at note %d (>119), stopping", sample_idx, start_note))
        break
      end
      
      -- Clamp end_note to valid range
      if end_note > 119 then
        end_note = 119
        reached_limit = true
        debug_print(string.format("Sample %d end note clamped from %d to 119", sample_idx, start_note + (keys_per_sample - 1)))
      end
      
      -- Ensure start_note is also within valid range (safety check)
      start_note = math.max(0, math.min(119, start_note))
      end_note = math.max(0, math.min(119, end_note))
      
      -- Ensure start_note <= end_note
      if start_note > end_note then
        debug_print(string.format("Sample %d: start_note (%d) > end_note (%d), skipping", sample_idx, start_note, end_note))
        break
      end
      
      -- Get the original base note before we change anything
      local original_base_note = sample.sample_mapping.base_note
      
      -- Update the mapping range
      sample.sample_mapping.note_range = {
        start_note,  -- Start note (C-0 based)
        end_note     -- End note
      }
      
      -- Set base note according to selected mode
      local new_base_note = get_base_note(start_note, end_note, original_base_note, base_note_mode)
      -- Clamp base note to valid range
      new_base_note = math.max(0, math.min(119, new_base_note))
      sample.sample_mapping.base_note = new_base_note
      
      mapped_samples = mapped_samples + 1
      
      debug_print(string.format(
        "Sample %d mapped to notes %d-%d with base note %d",
        sample_idx, start_note, end_note, new_base_note
      ))
      
      -- If we reached the limit, stop processing more samples
      if reached_limit then
        debug_print(string.format("Reached MIDI range limit at sample %d", sample_idx))
        break
      end
    else
      debug_print(string.format("Sample %d no longer exists, skipping", sample_idx))
    end
  end
  
  -- Store the new positions as original for transpose
  store_original_positions()
  
  -- Show appropriate status message
  if reached_limit then
    renoise.app():show_status(string.format(
      "Mapped %d samples (%d keys each, last sample fit to maximum)",
      mapped_samples, keys_per_sample
    ))
  else
    renoise.app():show_status(string.format(
      "Distributed %d samples across %d keys each",
      mapped_samples, keys_per_sample
    ))
  end
end

-- Show or toggle the Keyzone Distributor dialog
function pakettiKeyzoneDistributorDialog()
  -- Check environment and handle dialog state
  if not setup_environment() then return end
  
  debug_print("Creating new Keyzone Distributor dialog")
  
  -- Build the UI
  view_builder = renoise.ViewBuilder()
  
  local base_note_mode = BASE_NOTE_MODES.MIDDLE -- Default mode
  local enhanced_mode = false -- Default to simple mode
  
  -- Enhanced mode variables
  local transpose_value = 0
  local velocity_enabled = false
  local first_is_loudest = true
  local min_velocity = 0
  local max_velocity = 127
  local layer_count = nil -- nil means use all samples
  
  -- Function to update velocity layers automatically
  local function update_velocity_layers()
    if velocity_enabled then
      distribute_velocity_layers(first_is_loudest, min_velocity, max_velocity, layer_count)
    end
  end
  
  local keys_valuebox = view_builder:valuebox {
    min = 1,
    max = 120, -- Allow full MIDI range per sample
    value = 1, -- Default to single key per sample
    width=50,
    notifier=function(new_value)
      distribute_samples(new_value, base_note_mode)
    end
  }
  
  -- Create quick set buttons
  local function create_quick_set_button(value)
    return view_builder:button {
      text = tostring(value),
      width=35,
      notifier=function()
        keys_valuebox.value = value
        distribute_samples(value, base_note_mode)
      end
    }
  end
  
  local base_note_switch = view_builder:switch {
    width=300,
    items = {"Original", "Lowest Note", "Middle Note", "Highest Note"},
    value = base_note_mode,
    notifier=function(new_mode)
      base_note_mode = new_mode
      -- Redistribute with current keys value but new base note mode
      distribute_samples(keys_valuebox.value, new_mode)
    end
  }
  
  -- Enhanced controls (initially hidden)
  local enhanced_controls = view_builder:column {
    id = "enhanced_section",
    visible = false,
    
    view_builder:row {
      view_builder:text {
        text = "─── Transpose ───",
        style = "strong",
        width = 200
      }
    },
    
    view_builder:row {
      view_builder:text {
        width = 140,
        text = "Transpose by",
        font = "bold",
        style = "strong",
      },
              view_builder:valuebox {
          min = -60,
          max = 60,
          value = 0,
          width = 50,
          id = "transpose_valuebox",
          notifier = function(new_value)
            transpose_value = new_value
          end
        },
        view_builder:button {
          text = "Apply",
          width = 60,
          notifier = function()
            transpose_keyzones(transpose_value)
          end
        },
      view_builder:text {
        text = "semitones"
      }
    },
    
    view_builder:row {
      view_builder:text {
        text = "─── Velocity Layers ───",
        style = "strong",
        width = 200
      }
    },
    
    view_builder:row {
      view_builder:checkbox {
        value = false,
        id = "velocity_checkbox",
        notifier = function(value)
          velocity_enabled = value
          update_velocity_layers()
        end
      },
      view_builder:text {
        text = "Enable velocity distribution"
      }
    },
    
    view_builder:row {
      view_builder:text {
        width = 140,
        text = "Direction",
        font = "bold",
        style = "strong",
      },
      view_builder:switch {
        items = {"First Loudest", "First Softest"},
        value = 1,
        width = 200,
        notifier = function(value)
          first_is_loudest = (value == 1)
          update_velocity_layers()
        end
      }
    },
    
    view_builder:row {
      view_builder:text {
        width = 140,
        text = "Velocity range",
        font = "bold", 
        style = "strong",
      },
      view_builder:valuebox {
        min = 0,
        max = 127,
        value = 0,
        width = 50,
        notifier = function(value)
          min_velocity = value
          update_velocity_layers()
        end
      },
      view_builder:text { text = "to" },
      view_builder:valuebox {
        min = 0,
        max = 127,
        value = 127,
        width = 50,
        notifier = function(value)
          max_velocity = value
          update_velocity_layers()
        end
      }
    },
    
    view_builder:row {
      view_builder:text {
        width = 140,
        text = "Layer count",
        font = "bold",
        style = "strong",
      },
      view_builder:switch {
        items = {"All Samples", "Custom"},
        value = 1,
        width = 150,
        notifier = function(value)
          layer_count = (value == 1) and nil or 4
          update_velocity_layers()
        end
      },
      view_builder:valuebox {
        min = 1,
        max = 16,
        value = 4,
        width = 50,
        visible = false,
        id = "layer_count_valuebox",
        notifier = function(value)
          if layer_count then
            layer_count = value
            update_velocity_layers()
          end
        end
      }
    },

  }
  
  -- Enhanced mode toggle
  local enhanced_checkbox = view_builder:checkbox {
    value = false,
    notifier = function(value)
      enhanced_mode = value
      enhanced_controls.visible = value
      debug_print("Enhanced mode: " .. tostring(value))
    end
  }
  
  -- Create the dialog
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti Keyzone Distributor",
    view_builder:column {
      -- Original interface (always visible)
      view_builder:row {
        view_builder:text {
          width=140,
          text="Distribute Samples by",
          font = "bold",
          style="strong",
        },
        keys_valuebox,
        view_builder:text {
          font="bold",
          style="strong",
          text="keys per sample"
        }
      },
      view_builder:row {
        view_builder:text {
            width=140,
          text="Quick Set",
          font = "bold",
          style="strong",
        },
        create_quick_set_button(1),
        create_quick_set_button(12),
        create_quick_set_button(24)
      },
      view_builder:row {
        view_builder:text {
            width=140,
          text="Base Note",
          font = "bold",
          style="strong",
        },
        base_note_switch
      },
      
      -- Enhanced mode toggle
      view_builder:row {
        enhanced_checkbox,
        view_builder:text {
          text = "Enhanced Mode (Transpose & Velocity)",
          style = "strong"
        }
      },
      
      -- Enhanced controls (hidden by default)
      enhanced_controls
    }, keyhandler
  )
end

renoise.tool():add_keybinding{name="Global:Paketti:Show Keyzone Distributor Dialog...",invoke=function() pakettiKeyzoneDistributorDialog() end}
renoise.tool():add_midi_mapping{name="Paketti:Show Keyzone Distributor Dialog...",invoke=function(message) if message:is_trigger() then pakettiKeyzoneDistributorDialog() end end}
