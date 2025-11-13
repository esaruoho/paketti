-- PakettiDigitakt.lua
-- Comprehensive Digitakt sample chain export tool
-- Combines Paketti's sophisticated infrastructure with Digitakt-specific optimizations
-- Supports both Digitakt 1 (mono) and Digitakt 2 (stereo) with multiple export modes

local dialog = nil
local separator = package.config:sub(1,1)

-- Digitakt configurations for different hardware versions
local digitakt_configs = {
  digitakt1 = {
    sample_rate = 48000,
    bit_depth = 16,
    channels = 1,
    name = "Digitakt (Mono)",
    description = "Original Digitakt - mono samples only"
  },
  digitakt2 = {
    sample_rate = 48000, 
    bit_depth = 16,
    channels = 2,
    name = "Digitakt 2 (Stereo)",
    description = "Digitakt 2 - stereo samples supported"
  }
}

-- Export mode configurations
local export_modes = {
  chain = {
    name = "Chain (Direct Concatenation)",
    description = "Samples joined end-to-end without padding"
  },
  spaced = {
    name = "Spaced (Fixed Slots)",
    description = "Samples placed in fixed-length slots with padding"
  }
}

-- Slot count options for spaced mode
local slot_options = {
  {name = "Auto", value = nil, description = "Calculate optimal slot count"},
  {name = "4", value = 4, description = "4 fixed slots"},
  {name = "8", value = 8, description = "8 fixed slots"},
  {name = "16", value = 16, description = "16 fixed slots"},
  {name = "32", value = 32, description = "32 fixed slots"},
  {name = "64", value = 64, description = "64 fixed slots"}
}

-- Mono conversion methods
local mono_methods = {
  average = {name = "Average (Sum)", description = "Mix left and right channels"},
  left = {name = "Left Channel", description = "Use left channel only"},
  right = {name = "Right Channel", description = "Use right channel only"}
}

-- Export statistics (global for dialog updates)
local last_export_info = {
  slot_duration = 0,
  total_duration = 0,
  sample_count = 0,
  channels = 1,
  sample_rate = 48000
}

-- Round function for Lua 5.1 compatibility
local function round(x)
  return math.floor(x + 0.5)
end

-- Convert stereo sample to mono using specified method
local function convert_to_mono(sample_data_left, sample_data_right, method)
  print("PakettiDigitakt: Converting stereo to mono using method: " .. method)
  
  local mono_data = {}
  local frames = #sample_data_left
  
  for i = 1, frames do
    local left_val = sample_data_left[i] or 0
    local right_val = sample_data_right[i] or 0
    local mono_val
    
    if method == "left" then
      mono_val = left_val
    elseif method == "right" then
      mono_val = right_val
    else -- average (default)
      mono_val = (left_val + right_val) * 0.5
    end
    
    mono_data[i] = mono_val
  end
  
  print("PakettiDigitakt: Converted " .. frames .. " frames to mono")
  return mono_data
end

-- Extract sample data from Renoise sample
local function extract_sample_data(sample, target_channels, mono_method)
  local buffer = sample.sample_buffer
  if not buffer.has_sample_data then 
    print("PakettiDigitakt: Sample has no data: " .. (sample.name or "Unnamed"))
    return nil 
  end

  local frames = buffer.number_of_frames
  local source_channels = buffer.number_of_channels
  
  print(string.format("PakettiDigitakt: Extracting sample '%s' - %d frames, %d→%d channels", 
    sample.name or "Unnamed", frames, source_channels, target_channels))
  
  if target_channels == 1 then
    -- Mono output
    if source_channels == 1 then
      -- Mono to mono - direct copy
      local data = {}
      for i = 1, frames do
        data[i] = buffer:sample_data(1, i)
      end
      return {data}
    else
      -- Stereo to mono - convert
      local left_data = {}
      local right_data = {}
      for i = 1, frames do
        left_data[i] = buffer:sample_data(1, i)
        right_data[i] = buffer:sample_data(2, i)
      end
      local mono_data = convert_to_mono(left_data, right_data, mono_method)
      return {mono_data}
    end
  else
    -- Stereo output
    if source_channels == 1 then
      -- Mono to stereo - duplicate
      local data = {}
      for i = 1, frames do
        data[i] = buffer:sample_data(1, i)
      end
      return {data, data} -- Same data for both channels
    else
      -- Stereo to stereo - direct copy
      local left_data = {}
      local right_data = {}
      for i = 1, frames do
        left_data[i] = buffer:sample_data(1, i)
        right_data[i] = buffer:sample_data(2, i)
      end
      return {left_data, right_data}
    end
  end
end

-- Apply fade-out to sample data
local function apply_fade_out(data, fade_ms, sample_rate)
  if not data or #data == 0 then return data end
  
  local fade_samples = math.floor(sample_rate * (fade_ms / 1000))
  if fade_samples <= 0 or fade_samples >= #data then return data end
  
  print("PakettiDigitakt: Applying " .. fade_ms .. "ms fade-out (" .. fade_samples .. " samples)")
  
  for i = #data - fade_samples + 1, #data do
    local fade_factor = (i - (#data - fade_samples)) / fade_samples
    data[i] = data[i] * (1.0 - fade_factor)
  end
  
  return data
end

-- Apply TPDF dither to sample data
local function apply_tpdf_dither(data)
  if not data or #data == 0 then return data end
  
  print("PakettiDigitakt: Applying TPDF dither")
  math.randomseed(os.time())
  
  for i = 1, #data do
    local r1 = math.random() - 0.5
    local r2 = math.random() - 0.5
    data[i] = data[i] + (r1 + r2) / 65536 -- TPDF dither
  end
  
  return data
end

-- Pad sample to target length with zeros, optionally adding zero padding
local function pad_sample_to_length(data, target_length, add_zero_padding)
  local padded = {}
  
  -- Copy original data
  for i = 1, math.min(#data, target_length) do
    padded[i] = data[i]
  end
  
  -- Pad with zeros if needed
  for i = #data + 1, target_length do
    padded[i] = 0.0
  end
  
  -- Add zero padding at start and end if requested
  if add_zero_padding then
    local zeros = {}
    for i = 1, 64 do zeros[i] = 0.0 end -- 64 samples of silence
    
    local extended = {}
    -- Add leading zeros
    for _, z in ipairs(zeros) do table.insert(extended, z) end
    -- Add padded data
    for _, v in ipairs(padded) do table.insert(extended, v) end
    -- Add trailing zeros
    for _, z in ipairs(zeros) do table.insert(extended, z) end
    
    return extended
  end
  
  return padded
end

-- Process samples for chain mode (direct concatenation)
local function process_chain_mode(processed_samples, options)
  print("PakettiDigitakt: Processing chain mode - direct concatenation")
  
  local output_channels = {}
  for ch = 1, options.target_channels do
    output_channels[ch] = {}
  end
  
  local total_frames = 0
  
  for sample_idx, sample_data in ipairs(processed_samples) do
    -- Apply fade-out if enabled
    if options.apply_fadeout then
      for ch = 1, options.target_channels do
        sample_data[ch] = apply_fade_out(sample_data[ch], 20, options.sample_rate)
      end
    end
    
    -- Concatenate to output
    for ch = 1, options.target_channels do
      for _, value in ipairs(sample_data[ch]) do
        table.insert(output_channels[ch], value)
      end
    end
    
    total_frames = total_frames + #sample_data[1]
    print("PakettiDigitakt: Added sample " .. sample_idx .. " (" .. #sample_data[1] .. " frames)")
  end
  
  -- Calculate statistics
  local avg_sample_length = math.floor(total_frames / #processed_samples)
  last_export_info.slot_duration = avg_sample_length / options.sample_rate
  last_export_info.total_duration = total_frames / options.sample_rate
  last_export_info.sample_count = #processed_samples
  
  print(string.format("PakettiDigitakt: Chain mode complete - %d total frames, %.2f seconds", 
    total_frames, last_export_info.total_duration))
  
  return output_channels
end

-- Process samples for spaced mode (fixed-length slots)
local function process_spaced_mode(processed_samples, options)
  print("PakettiDigitakt: Processing spaced mode - fixed-length slots")
  
  -- Calculate slot length
  local max_sample_length = 0
  local total_samples_length = 0
  
  for _, sample_data in ipairs(processed_samples) do
    local sample_length = #sample_data[1]
    if sample_length > max_sample_length then
      max_sample_length = sample_length
    end
    total_samples_length = total_samples_length + sample_length
  end
  
  local slot_length = max_sample_length
  local target_slot_count = #processed_samples
  
  if options.fixed_slot_count then
    -- Calculate ideal slot length to fit all samples
    local ideal_slot_length = math.ceil(total_samples_length / options.fixed_slot_count)
    slot_length = math.max(max_sample_length, ideal_slot_length)
    target_slot_count = options.fixed_slot_count
    
    print(string.format("PakettiDigitakt: Fixed slot count %d, calculated slot length: %d", 
      options.fixed_slot_count, slot_length))
  else
    -- Auto mode: round up to next valid Digitakt slot count
    local valid_slot_counts = {4, 8, 16, 32, 64, 128}
    target_slot_count = #processed_samples
    
    for _, count in ipairs(valid_slot_counts) do
      if count >= #processed_samples then
        target_slot_count = count
        break
      end
    end
    
    -- If we still don't have a valid count (more than 128 samples), use the sample count
    if target_slot_count < #processed_samples then
      target_slot_count = #processed_samples
    end
    
    print(string.format("PakettiDigitakt: Auto slot count %d (from %d samples), max sample length: %d", 
      target_slot_count, #processed_samples, slot_length))
  end
  
  -- Account for zero padding in slot length
  if options.pad_with_zero then
    slot_length = slot_length + (64 * 2) -- 64 samples at start and end
  end
  
  local output_channels = {}
  for ch = 1, options.target_channels do
    output_channels[ch] = {}
  end
  
  -- Process each slot
  for slot = 1, target_slot_count do
    local sample_data = processed_samples[slot]
    
    if sample_data then
      print("PakettiDigitakt: Processing slot " .. slot .. " (" .. #sample_data[1] .. " frames)")
      
      -- Apply fade-out if enabled
      if options.apply_fadeout then
        for ch = 1, options.target_channels do
          sample_data[ch] = apply_fade_out(sample_data[ch], 20, options.sample_rate)
        end
      end
      
      -- Pad to slot length
      for ch = 1, options.target_channels do
        local padded = pad_sample_to_length(sample_data[ch], slot_length, options.pad_with_zero)
        for _, value in ipairs(padded) do
          table.insert(output_channels[ch], value)
        end
      end
    else
      print("PakettiDigitakt: Filling empty slot " .. slot .. " with silence")
      -- Fill empty slot with silence
      for ch = 1, options.target_channels do
        for i = 1, slot_length do
          table.insert(output_channels[ch], 0.0)
        end
      end
    end
  end
  
  -- Calculate statistics
  last_export_info.slot_duration = slot_length / options.sample_rate
  last_export_info.total_duration = (target_slot_count * slot_length) / options.sample_rate
  last_export_info.sample_count = #processed_samples
  
  print(string.format("PakettiDigitakt: Spaced mode complete - %d slots, %.3f sec/slot, %.2f sec total", 
    target_slot_count, last_export_info.slot_duration, last_export_info.total_duration))
  
  return output_channels
end

-- Write WAV file with proper Digitakt-compatible format
local function write_digitakt_wav(filename, sample_data, sample_rate, bit_depth, apply_dither)
  local channels = #sample_data
  local frames = #sample_data[1]
  
  print(string.format("PakettiDigitakt: Writing WAV file - %d channels, %d frames, %dHz, %d-bit", 
    channels, frames, sample_rate, bit_depth))
  
  local f = io.open(filename, "wb")
  if not f then
    renoise.app():show_error("Could not create file: " .. filename)
    return false
  end
  
  -- Helper functions for little-endian writing
  local function write_le_16(x)
    f:write(string.char(x % 256, math.floor(x / 256) % 256))
  end
  
  local function write_le_32(x)
    write_le_16(x % 65536)
    write_le_16(math.floor(x / 65536))
  end
  
  -- Calculate file sizes
  local bytes_per_sample = bit_depth / 8
  local block_align = channels * bytes_per_sample
  local data_size = frames * block_align
  local file_size = 36 + data_size
  
  -- Write WAV header
  f:write("RIFF")
  write_le_32(file_size)
  f:write("WAVE")
  f:write("fmt ")
  write_le_32(16) -- fmt chunk size
  write_le_16(1)  -- PCM format
  write_le_16(channels)
  write_le_32(sample_rate)
  write_le_32(sample_rate * block_align) -- byte rate
  write_le_16(block_align)
  write_le_16(bit_depth)
  
  f:write("data")
  write_le_32(data_size)
  
  -- Prepare for dithering if enabled
  if apply_dither then
    print("PakettiDigitakt: Applying dither during write")
    math.randomseed(os.time())
  end
  
  -- Write sample data
  for frame = 1, frames do
    for ch = 1, channels do
      local value = sample_data[ch][frame] or 0
      
      -- Apply dither if enabled
      if apply_dither then
        local r1 = math.random() - 0.5
        local r2 = math.random() - 0.5
        value = value + (r1 + r2) / 65536
      end
      
      -- Convert to integer and clamp
      local clipped = math.max(-1, math.min(1, value))
      local int_val = round(clipped * 32767)
      
      -- Handle negative values for unsigned write
      if int_val < 0 then int_val = int_val + 65536 end
      write_le_16(int_val)
    end
  end
  
  f:close()
  print("PakettiDigitakt: WAV file written successfully: " .. filename)
  return true
end

-- Main export function
local function export_digitakt_chain(params)
  local song = renoise.song()
  local instrument = song.selected_instrument
  
  if #instrument.samples == 0 then
    renoise.app():show_error("Selected instrument has no samples")
    return false
  end
  
  local config = digitakt_configs[params.digitakt_version]
  print("PakettiDigitakt: Starting export for " .. config.name)
  print(string.format("PakettiDigitakt: Target format - %dHz, %d-bit, %d channels", 
    config.sample_rate, config.bit_depth, config.channels))
  
  -- Process all samples
  local processed_samples = {}
  local skipped_count = 0
  
  for i = 1, #instrument.samples do
    local sample = instrument.samples[i]
    if sample and sample.sample_buffer.has_sample_data then
      -- Convert sample rate and bit depth if needed
      local needs_conversion = (sample.sample_buffer.sample_rate ~= config.sample_rate) or 
                              (sample.sample_buffer.bit_depth ~= config.bit_depth)
      
      if needs_conversion then
        print(string.format("PakettiDigitakt: Converting sample %d from %dHz/%dbit to %dHz/%dbit", 
          i, sample.sample_buffer.sample_rate, sample.sample_buffer.bit_depth,
          config.sample_rate, config.bit_depth))
        
        -- Use Paketti's conversion function if available
        if RenderSampleAtNewRate then
          local old_index = song.selected_sample_index
          song.selected_sample_index = i
          local success = pcall(function()
            RenderSampleAtNewRate(config.sample_rate, config.bit_depth)
          end)
          song.selected_sample_index = old_index
          
          if not success then
            print("PakettiDigitakt: Conversion failed for sample " .. i .. ", using original")
          end
        end
      end
      
      -- Extract sample data
      local sample_data = extract_sample_data(sample, config.channels, params.mono_method)
      if sample_data then
        table.insert(processed_samples, sample_data)
        print(string.format("PakettiDigitakt: Processed sample %d: '%s' (%d frames)", 
          #processed_samples, sample.name or "Unnamed", #sample_data[1]))
      else
        skipped_count = skipped_count + 1
      end
    else
      skipped_count = skipped_count + 1
    end
  end
  
  if #processed_samples == 0 then
    renoise.app():show_error("No valid samples found to export")
    return false
  end
  
  print(string.format("PakettiDigitakt: Processed %d samples, skipped %d", 
    #processed_samples, skipped_count))
  
  -- Set up processing options
  local options = {
    target_channels = config.channels,
    sample_rate = config.sample_rate,
    export_mode = params.export_mode,
    fixed_slot_count = params.slot_count,
    apply_fadeout = params.apply_fadeout,
    apply_dither = params.apply_dither,
    pad_with_zero = params.pad_with_zero
  }
  
  -- Process samples according to mode
  local output_data
  if params.export_mode == "chain" then
    output_data = process_chain_mode(processed_samples, options)
  else
    output_data = process_spaced_mode(processed_samples, options)
  end
  
  -- Store format info for dialog updates
  last_export_info.channels = config.channels
  last_export_info.sample_rate = config.sample_rate
  
  -- Prompt for filename
  local filename = renoise.app():prompt_for_filename_to_write("WAV", "digitakt_chain.wav")
  if not filename or filename == "" then
    renoise.app():show_status("Export cancelled")
    return false
  end
  
  -- Write WAV file
  local success = write_digitakt_wav(filename, output_data, config.sample_rate, 
                                   config.bit_depth, params.apply_dither)
  
  if success then
    -- Create metadata string for sample naming
    local metadata = string.format("DT[V%s:S%d:C%d:M=%s:SC=%s:F=%d:D=%d:P=%d]",
      params.digitakt_version == "digitakt2" and "2" or "1",
      config.sample_rate,
      config.channels,
      params.export_mode,
      params.slot_count or "auto",
      params.apply_fadeout and 1 or 0,
      params.apply_dither and 1 or 0,
      params.pad_with_zero and 1 or 0)
    
    local status_msg = string.format("Digitakt chain exported: %d samples, %.2fs total %s", 
      last_export_info.sample_count, last_export_info.total_duration, metadata)
    renoise.app():show_status(status_msg)
    print("PakettiDigitakt: Export completed successfully")
    return true
  else
    return false
  end
end

-- Create export dialog
local selected_instrument_notifier = nil

function PakettiDigitaktDialog()
  if dialog and dialog.visible then
    -- Clean up observable notifier before closing
    local song = renoise.song()
    if selected_instrument_notifier then
      if song.selected_instrument_index_observable:has_notifier(selected_instrument_notifier) then
        song.selected_instrument_index_observable:remove_notifier(selected_instrument_notifier)
      end
      selected_instrument_notifier = nil
    end
    dialog:close()
    dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  local song = renoise.song()
  
  -- Default parameters
  local params = {
    digitakt_version = "digitakt2", -- Default to stereo-capable version
    export_mode = "spaced",
    slot_count = nil, -- Auto
    mono_method = "average",
    apply_fadeout = false,
    apply_dither = false,
    pad_with_zero = false
  }
  
  -- Create UI elements
  local version_items = {"Digitakt (Mono)", "Digitakt 2 (Stereo)"}
  local version_keys = {"digitakt1", "digitakt2"}
  
  local mode_items = {"Spaced (Fixed Slots)", "Chain (Direct Concatenation)"}
  local mode_keys = {"spaced", "chain"}
  
  local slot_items = {}
  for _, option in ipairs(slot_options) do
    table.insert(slot_items, option.name)
  end
  
  local mono_items = {"Average (Sum)", "Left Channel", "Right Channel"}
  local mono_keys = {"average", "left", "right"}
  
  -- Info display elements
  local export_info = vb:text{
    text = "Ready to export",
    width = 350,style="strong",font="bold"
  }
  
  local current_instrument_info = vb:text{
    text = "",
    width = 350,
    style = "strong",font="bold"
  }
  
  local function update_current_instrument_display()
    local instrument = song.selected_instrument
    local instrument_name = instrument.name
    if instrument_name == "" then
      instrument_name = "Unnamed"
    end
    local sample_count = #instrument.samples
    current_instrument_info.text = string.format("Current: [%02X] %s (%d samples)", 
      song.selected_instrument_index - 1, instrument_name, sample_count)
  end
  
  local function update_export_info()
    if last_export_info.sample_count > 0 then
      local info_text = string.format("Last export: %d samples, %.3f sec/slot, %.2f sec total (%s, %dHz)",
        last_export_info.sample_count,
        last_export_info.slot_duration,
        last_export_info.total_duration,
        last_export_info.channels == 2 and "Stereo" or "Mono",
        last_export_info.sample_rate)
      export_info.text = info_text
    end
  end
  
  -- Observable for tracking instrument changes
  selected_instrument_notifier = update_current_instrument_display
  if not song.selected_instrument_index_observable:has_notifier(selected_instrument_notifier) then
    song.selected_instrument_index_observable:add_notifier(selected_instrument_notifier)
  end
  
  -- Initialize the current instrument display
  update_current_instrument_display()
  
  local content = vb:column{
   -- Current instrument display
    current_instrument_info,
    
    -- Digitakt version selection
    vb:row{
      vb:text{text = "Target Device", width = 120,style="strong",font="bold"},
      vb:popup{
        items = version_items,
        value = 2, -- Default to Digitakt 2
        width = 200,
        notifier = function(value)
          params.digitakt_version = version_keys[value]
          print("PakettiDigitakt: Selected version: " .. params.digitakt_version)
        end
      }
    },
    
    -- Export mode selection
    vb:row{
      vb:text{text = "Export Mode", width = 120,style="strong",font="bold"},
      vb:popup{
        items = mode_items,
        value = 1, -- Default to spaced
        width = 200,
        notifier = function(value)
          params.export_mode = mode_keys[value]
          print("PakettiDigitakt: Selected mode: " .. params.export_mode)
        end
      }
    },
    
    -- Slot count selection (for spaced mode)
    vb:row{
      vb:text{text = "Slot Count", width = 120,style="strong",font="bold"},
      vb:popup{
        items = slot_items,
        value = 1, -- Default to Auto
        width = 200,
        notifier = function(value)
          params.slot_count = slot_options[value].value
          print("PakettiDigitakt: Selected slot count: " .. tostring(params.slot_count or "auto"))
        end
      }
    },
    
    -- Mono conversion method
    vb:row{
      vb:text{text = "Mono Conversion", width = 120,style="strong",font="bold"},
      vb:popup{
        items = mono_items,
        value = 1, -- Default to average
        width = 200,
        notifier = function(value)
          params.mono_method = mono_keys[value]
          print("PakettiDigitakt: Selected mono method: " .. params.mono_method)
        end
      }
    },
    
    -- Audio processing options
    vb:column{
      width="100%",
      
      vb:text{text = "Audio Processing Options", style = "strong",font="bold"},
      
      vb:row{
        vb:checkbox{
          value = false,
          notifier = function(value)
            params.apply_fadeout = value
            print("PakettiDigitakt: Fadeout enabled: " .. tostring(value))
          end
        },
        vb:text{text = "Apply short fade-out to each sample (20ms)"}
      },
      
      vb:row{
        vb:checkbox{
          value = false,
          notifier = function(value)
            params.apply_dither = value
            print("PakettiDigitakt: Dither enabled: " .. tostring(value))
          end
        },
        vb:text{text = "Apply TPDF dither when converting to 16-bit"}
      },
      
      vb:row{
        vb:checkbox{
          value = false,
          notifier = function(value)
            params.pad_with_zero = value
            print("PakettiDigitakt: Zero padding enabled: " .. tostring(value))
          end
        },
        vb:text{text = "Pad each slot with 64 samples of silence"}
      }
    },
    
    -- Export info display
    export_info,
    
    -- Action buttons
    vb:horizontal_aligner{
      mode = "distribute",      
      vb:button{
        text = "Export Chain",
        width = 120,
        notifier = function()
          if export_digitakt_chain(params) then
            update_export_info()
          end
        end
      },
      
      vb:button{
        text = "Close",
        width = 80,
        notifier = function()
          -- Clean up observable notifier
          if selected_instrument_notifier then
            if song.selected_instrument_index_observable:has_notifier(selected_instrument_notifier) then
              song.selected_instrument_index_observable:remove_notifier(selected_instrument_notifier)
            end
            selected_instrument_notifier = nil
          end
          dialog:close()
          dialog = nil
        end
      }
    },
    

    
    -- Help text
    vb:multiline_text{
      text = "- Digitakt: Mono samples only (48kHz)\n" ..
             "- Digitakt 2: Stereo sample support\n" ..
             "- Spaced mode: Fixed-length slots for consistent timing\n" ..
             "- Chain mode: Direct concatenation for maximum efficiency\n" ..
             "- Samples are automatically converted to 48kHz/16-bit format",
      width = 350,
      height = 80
    }
  }
  
  dialog = renoise.app():show_custom_dialog("Digitakt Sample Chain Exporter", content)
end

-- Quick export functions for menu integration
function PakettiDigitaktExportMono()
  print("PakettiDigitakt: Quick export - Digitakt mono")
  local params = {
    digitakt_version = "digitakt1",
    export_mode = "spaced",
    slot_count = nil,
    mono_method = "average",
    apply_fadeout = false,
    apply_dither = false,
    pad_with_zero = false
  }
  export_digitakt_chain(params)
end

function PakettiDigitaktExportStereo()
  print("PakettiDigitakt: Quick export - Digitakt 2 stereo")
  local params = {
    digitakt_version = "digitakt2",
    export_mode = "spaced",
    slot_count = nil,
    mono_method = "average",
    apply_fadeout = false,
    apply_dither = false,
    pad_with_zero = false
  }
  export_digitakt_chain(params)
end

function PakettiDigitaktExportChain()
  print("PakettiDigitakt: Quick export - Chain mode")
  local params = {
    digitakt_version = "digitakt2",
    export_mode = "chain",
    slot_count = nil,
    mono_method = "average",
    apply_fadeout = true,
    apply_dither = false,
    pad_with_zero = false
  }
  export_digitakt_chain(params)
end



renoise.tool():add_keybinding{name = "Global:Paketti:Export Digitakt Sample Chain...", invoke = PakettiDigitaktDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Export Digitakt Quick Export (Digitakt Mono)", invoke = PakettiDigitaktExportMono}
renoise.tool():add_keybinding{name = "Global:Paketti:Export Digitakt Quick Export (Digitakt 2 Stereo)", invoke = PakettiDigitaktExportStereo}
renoise.tool():add_keybinding{name = "Global:Paketti:Export Digitakt Quick Export (Chain Mode)", invoke = PakettiDigitaktExportChain}


--[[
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Digitakt:Export Sample Chain...", invoke = PakettiDigitaktDialog}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Digitakt:Quick Export (Digitakt Mono)", invoke = PakettiDigitaktExportMono}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Digitakt:Quick Export (Digitakt 2 Stereo)", invoke = PakettiDigitaktExportStereo}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti:Digitakt:Quick Export (Chain Mode)", invoke = PakettiDigitaktExportChain}
renoise.tool():add_menu_entry{name = "Instrument Box:Paketti:Digitakt:Export Sample Chain...", invoke = PakettiDigitaktDialog}
renoise.tool():add_menu_entry{name = "DSP Device:Paketti:Digitakt:Export Sample Chain...", invoke = PakettiDigitaktDialog}
renoise.tool():add_menu_entry{name = "Mixer:Paketti:Digitakt:Export Sample Chain...", invoke = PakettiDigitaktDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Digitakt Export Sample Chain...", invoke = PakettiDigitaktDialog}
renoise.tool():add_keybinding{name = "Sample Editor:Paketti:Digitakt Export Sample Chain...", invoke = PakettiDigitaktDialog}
renoise.tool():add_keybinding{name = "Sample Editor:Paketti:Digitakt Quick Export Mono", invoke = PakettiDigitaktExportMono}
renoise.tool():add_keybinding{name = "Sample Editor:Paketti:Digitakt Quick Export Stereo", invoke = PakettiDigitaktExportStereo}
renoise.tool():add_keybinding{name = "Sample Editor:Paketti:Digitakt Quick Export Chain", invoke = PakettiDigitaktExportChain}
]]--
--[[
print("PakettiDigitakt: Digitakt sample chain export tool loaded")
print("PakettiDigitakt: Supports Digitakt 1 (mono) and Digitakt 2 (stereo)")
print("PakettiDigitakt: Export modes: Spaced (fixed slots) and Chain (concatenation)")
print("PakettiDigitakt: Access via Main Menu > Tools > Paketti > Digitakt") 
]]--