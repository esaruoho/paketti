-- PakettiMetaSynth.lua
-- Instrument Architecture Generator for Paketti
-- Builds complex synthesis architectures using Renoise's sampler, FX chains, and modulation system

-- ============================================================================
-- SECTION 1: DATA MODEL AND VALIDATION
-- ============================================================================

-- Global architecture storage
PakettiMetaSynthCurrentArchitecture = nil

-- AKWF file list cache for performance
PakettiMetaSynthAKWFCache = nil

-- Last used folder path for sample loading
PakettiMetaSynthLastFolderPath = nil

-- Default architecture template
function PakettiMetaSynthCreateDefaultArchitecture()
  return {
    name = "New MetaSynth Instrument",
    oscillator_groups = {
      {
        name = "Group A",
        crossfade_mode = "linear",
        -- Group-level crossfade settings (wavetable scanning between oscillators)
        group_crossfade_enabled = false,
        group_crossfade_curve = "equal_power",
        -- Group LFO rate settings
        group_lfo_rate_mode = "preset",  -- "free", "tempo_sync", "preset"
        group_lfo_rate_free = 0.5,       -- Hz when mode = "free"
        group_lfo_rate_sync = "1 bar",   -- Beat division when mode = "tempo_sync"
        group_lfo_rate_preset = "medium", -- "slow", "medium", "fast" when mode = "preset"
        -- Group Master FX settings (glue FX per wavetable group)
        group_master_fx_enabled = false,
        group_master_fx_mode = "random",
        group_master_fx_count = 3,
        group_master_fx_types = {},
        oscillators = {
          {
            name = "Osc 1",
            sample_count = 1,
            unison_voices = 1,
            frame_count = 1,
            sample_source = "akwf",
            sample_folder = nil,
            detune_spread = 10,
            pan_spread = 0.8,
            -- Oscillator FX settings (processing after frame morphing, before group morphing)
            osc_fx_enabled = false,
            osc_fx_mode = "random",
            osc_fx_count = 2,
            osc_fx_types = {}
          }
        }
      }
    },
    crossfade = {
      curve_type = "equal_power",
      control_source = "lfo",  -- LFO mode works; macro mode not fully implemented
      macro_index = 1,
      -- Frame LFO rate settings
      lfo_rate_mode = "preset",    -- "free", "tempo_sync", "preset"
      lfo_rate_free = 0.5,         -- Hz when mode = "free"
      lfo_rate_sync = "1/4",       -- Beat division when mode = "tempo_sync"
      lfo_rate_preset = "medium"   -- "slow", "medium", "fast" when mode = "preset"
    },
    fx_randomization = {
      enabled = false,
      device_pool = {"Analog Filter", "Chorus 2"},
      param_randomization = 0.3
    },
    modulation = {
      random_phase_offsets = true,
      lfo_rate_range = {0.1, 2.0},
      envelope_attack_range = {0.0, 0.5}
    },
    -- Stacked Master FX settings (final processing across all groups)
    stacked_master_fx_enabled = false,
    stacked_master_fx_mode = "random",
    stacked_master_fx_count = 3,
    stacked_master_fx_types = {},
    -- Master routing mode: "output_routing" (chain property) or "send_device" (#Send devices)
    master_routing_mode = "output_routing"
  }
end

-- Calculate total sample count across the entire architecture
function PakettiMetaSynthCalculateTotalSamples(architecture)
  local total = 0
  for _, group in ipairs(architecture.oscillator_groups) do
    for _, osc in ipairs(group.oscillators) do
      total = total + (osc.sample_count * osc.unison_voices)
    end
  end
  return total
end

-- Calculate total FX chains needed
function PakettiMetaSynthCalculateTotalFXChains(architecture)
  local total = 0
  for _, group in ipairs(architecture.oscillator_groups) do
    for _, osc in ipairs(group.oscillators) do
      -- Each frame needs its own FX chain
      total = total + osc.frame_count
      -- Add 1 chain per oscillator when Oscillator FX is enabled
      if osc.osc_fx_enabled then
        total = total + 1
      end
    end
    -- Add 1 chain per group when Group Master FX is enabled
    if group.group_master_fx_enabled then
      total = total + 1
    end
  end
  -- Add 1 chain for Stacked Master FX when enabled
  if architecture.stacked_master_fx_enabled then
    total = total + 1
  end
  return total
end

-- Validate architecture against Renoise limits
function PakettiMetaSynthValidateArchitecture(architecture)
  local errors = {}
  local warnings = {}
  
  local total_samples = PakettiMetaSynthCalculateTotalSamples(architecture)
  local total_fx_chains = PakettiMetaSynthCalculateTotalFXChains(architecture)
  
  -- Hard limit: 12 samples per note
  if total_samples > 12 then
    table.insert(errors, string.format("Total samples (%d) exceeds Renoise limit of 12 samples per note", total_samples))
  end
  
  -- Soft limit: warn if approaching limit
  if total_samples > 8 and total_samples <= 12 then
    table.insert(warnings, string.format("Total samples (%d) is approaching the 12-sample limit", total_samples))
  end
  
  -- FX chain limit (256 max)
  if total_fx_chains > 256 then
    table.insert(errors, string.format("Total FX chains (%d) exceeds Renoise limit of 256", total_fx_chains))
  end
  
  -- Validate each oscillator group
  for gi, group in ipairs(architecture.oscillator_groups) do
    if #group.oscillators == 0 then
      table.insert(errors, string.format("Group '%s' has no oscillators", group.name))
    end
    
    -- Validate Group Master FX settings
    if group.group_master_fx_enabled then
      if group.group_master_fx_count < 1 or group.group_master_fx_count > 5 then
        table.insert(errors, string.format("Group '%s' master FX count must be 1-5", group.name))
      end
      if group.group_master_fx_mode == "selective" and #group.group_master_fx_types == 0 then
        table.insert(warnings, string.format("Group '%s' has selective FX mode but no FX types selected", group.name))
      end
    end
    
    for oi, osc in ipairs(group.oscillators) do
      if osc.sample_count < 1 or osc.sample_count > 12 then
        table.insert(errors, string.format("Oscillator '%s' sample_count must be 1-12", osc.name))
      end
      if osc.unison_voices < 1 or osc.unison_voices > 8 then
        table.insert(errors, string.format("Oscillator '%s' unison_voices must be 1-8", osc.name))
      end
      if osc.frame_count < 1 or osc.frame_count > 16 then
        table.insert(errors, string.format("Oscillator '%s' frame_count must be 1-16", osc.name))
      end
      
      -- Validate Oscillator FX settings
      if osc.osc_fx_enabled then
        if osc.osc_fx_count < 1 or osc.osc_fx_count > 5 then
          table.insert(errors, string.format("Oscillator '%s' FX count must be 1-5", osc.name))
        end
        if osc.osc_fx_mode ~= "random" and osc.osc_fx_mode ~= "selective" then
          table.insert(errors, string.format("Oscillator '%s' FX mode must be 'random' or 'selective'", osc.name))
        end
        if osc.osc_fx_mode == "selective" and (not osc.osc_fx_types or #osc.osc_fx_types == 0) then
          table.insert(warnings, string.format("Oscillator '%s' has selective FX mode but no FX types selected", osc.name))
        end
      end
    end
  end
  
  -- Validate Stacked Master FX settings
  if architecture.stacked_master_fx_enabled then
    if architecture.stacked_master_fx_count < 1 or architecture.stacked_master_fx_count > 5 then
      table.insert(errors, "Stacked Master FX count must be 1-5")
    end
    if architecture.stacked_master_fx_mode == "selective" and #architecture.stacked_master_fx_types == 0 then
      table.insert(warnings, "Stacked Master FX has selective mode but no FX types selected")
    end
  end
  
  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings,
    total_samples = total_samples,
    total_fx_chains = total_fx_chains
  }
end

-- ============================================================================
-- SECTION 2: FX CHAIN BUILDER
-- ============================================================================

-- Available native devices for FX randomization (safe, CPU-friendly choices)
PakettiMetaSynthSafeFXDevices = {
  "Analog Filter",
  "Chorus 2",
  "Comb Filter 2",
  "Delay",
  "Digital Filter",
  "Distortion 2",
  "EQ 5",
  "Flanger 2",
  "Gainer",
  "LofiMat 2",
  "Phaser 2",
  "RingMod 2",
  "Stereo Expander"
}

-- Heavy devices (excluded by default for CPU-aware mode)
PakettiMetaSynthHeavyFXDevices = {
  "Convolver",
  "mpReverb 2",
  "Reverb",
  "Cabinet Simulator"
}

-- Create a new FX chain in the instrument
function PakettiMetaSynthCreateFXChain(instrument, chain_name)
  local chain_index = #instrument.sample_device_chains + 1
  instrument:insert_sample_device_chain_at(chain_index)
  local chain = instrument.sample_device_chains[chain_index]
  chain.name = chain_name
  PakettiMetaSynthAddDCOffset(chain)
  return chain, chain_index
end

-- Add DC Offset device (Automatic mode) to a chain right after Mixer
function PakettiMetaSynthAddDCOffset(chain)
  local success, err = pcall(function()
    chain:insert_device_at("Audio/Effects/Native/DC Offset", 2)
  end)
  if success then
    local device = chain.devices[2]
    device.parameters[2].value = 1  -- Automatic mode
    device.display_name = "DC Offset"
  end
end

-- Insert a native device into an FX chain
function PakettiMetaSynthInsertDevice(chain, device_name, position)
  position = position or (#chain.devices + 1)
  local device_path = "Audio/Effects/Native/" .. device_name
  
  local success, err = pcall(function()
    chain:insert_device_at(device_path, position)
  end)
  
  if success then
    return chain.devices[position]
  else
    print("PakettiMetaSynth: Failed to insert device '" .. device_name .. "': " .. tostring(err))
    return nil
  end
end

-- Randomize device parameters within safe ranges
function PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
  if not device or not device.parameters then return end
  
  randomization_amount = randomization_amount or 0.3
  
  for i, param in ipairs(device.parameters) do
    -- Skip the first parameter (usually bypass/active)
    if i > 1 and param.value_quantum == 0 then
      -- Continuous parameter - randomize within full range
      local range = param.value_max - param.value_min
      local new_value = param.value_min + math.random() * range * randomization_amount
      -- Ensure we stay within bounds
      new_value = math.max(param.value_min, math.min(param.value_max, new_value))
      param.value = new_value
    end
  end
end

-- Create a Gainer device with specific gain value
function PakettiMetaSynthCreateGainer(chain, gain_value, display_name)
  local position = #chain.devices + 1
  local device = PakettiMetaSynthInsertDevice(chain, "Gainer", position)
  
  if device then
    device.display_name = display_name or "Frame Gainer"
    -- Gainer parameter 1 is Gain (0.0 = -INF dB, 1.0 = 0 dB, higher = boost)
    device.parameters[1].value = gain_value or 1.0
    -- Gainer parameter 2 is Panning (0.5 = center)
    device.parameters[2].value = 0.5
  end
  
  return device, position
end

-- LFO Rate Presets (in Hz)
PakettiMetaSynthLFORatePresets = {
  slow = 0.1,     -- 10 second cycle
  medium = 0.5,   -- 2 second cycle
  fast = 2.0      -- 0.5 second cycle
}

-- Tempo-sync divisions mapped to LPB-relative values
-- These are based on lines-per-beat and need song tempo to calculate actual Hz
PakettiMetaSynthLFOSyncDivisions = {
  ["1/16"] = 0.25,   -- 1/16 of a beat
  ["1/8"] = 0.5,     -- 1/8 of a beat (half beat)
  ["1/4"] = 1,       -- 1 beat
  ["1/2"] = 2,       -- 2 beats (half bar in 4/4)
  ["1 bar"] = 4,     -- 4 beats (1 bar in 4/4)
  ["2 bars"] = 8,    -- 8 beats (2 bars)
  ["4 bars"] = 16    -- 16 beats (4 bars)
}

-- Calculate LFO frequency from rate settings
-- Returns frequency in Hz (Renoise LFO frequency parameter, 0-1 maps to Hz range)
function PakettiMetaSynthCalculateLFOFrequency(rate_mode, rate_free, rate_sync, rate_preset)
  rate_mode = rate_mode or "preset"
  rate_preset = rate_preset or "medium"
  rate_free = rate_free or 0.5
  rate_sync = rate_sync or "1 bar"
  
  local frequency_hz = 0.5  -- Default
  
  if rate_mode == "free" then
    -- Direct Hz value
    frequency_hz = rate_free
    
  elseif rate_mode == "preset" then
    -- Use preset values
    frequency_hz = PakettiMetaSynthLFORatePresets[rate_preset] or 0.5
    
  elseif rate_mode == "tempo_sync" then
    -- Calculate from song tempo
    local song = renoise.song()
    local bpm = song.transport.bpm
    local lpb = song.transport.lpb
    
    -- Get beat multiplier for this sync division
    local beat_multiplier = PakettiMetaSynthLFOSyncDivisions[rate_sync] or 4
    
    -- Calculate cycle duration in seconds
    -- beats_per_second = bpm / 60
    -- cycle_duration = beat_multiplier / beats_per_second = beat_multiplier * 60 / bpm
    local cycle_duration = beat_multiplier * 60 / bpm
    
    -- Frequency = 1 / cycle_duration
    frequency_hz = 1 / cycle_duration
  end
  
  -- Clamp to reasonable range (0.01 Hz to 10 Hz)
  frequency_hz = math.max(0.01, math.min(10, frequency_hz))
  
  -- Convert Hz to Renoise LFO frequency parameter (0-1 range, logarithmic)
  -- Renoise LFO frequency: 0 = 0.001 Hz, 1 = ~16 Hz (approximately log scale)
  -- Using approximation: param = log10(hz * 1000) / 4.2
  local param_value = math.log10(frequency_hz * 1000) / 4.2
  param_value = math.max(0, math.min(1, param_value))
  
  return param_value, frequency_hz
end

-- Create an LFO device with custom envelope for crossfade control, routed to a specific destination
-- Now accepts optional lfo_frequency parameter (Renoise param value 0-1)
function PakettiMetaSynthCreateCrossfadeLFO(chain, envelope_points, display_name, dest_device_index, dest_param_index, lfo_frequency)
  local position = #chain.devices + 1
  local device = PakettiMetaSynthInsertDevice(chain, "*LFO", position)
  
  if device then
    device.display_name = display_name or "Crossfade LFO"
    
    -- Build XML for custom envelope (NO routing in XML - done via parameters)
    local points_xml = {}
    for i, point in ipairs(envelope_points) do
      table.insert(points_xml, string.format('<Point>%d,%.6f,0.0</Point>', point.time, point.value))
    end
    
    -- DEBUG: Print routing info
    print(string.format("DEBUG LFO '%s': chain='%s', LFO position=%d, dest_device_index=%s, dest_param_index=%s",
      display_name or "Crossfade LFO",
      chain.name,
      position,
      tostring(dest_device_index),
      tostring(dest_param_index)))
    
    -- DEBUG: List all devices in chain
    print(string.format("DEBUG LFO '%s': Chain devices:", display_name))
    for di = 1, #chain.devices do
      local d = chain.devices[di]
      print(string.format("  Device %d: %s", di, d.display_name or d.name))
    end
    
    -- Use provided frequency or default
    local freq_value = lfo_frequency or 0.9375
    
    -- XML for custom envelope only (routing done via parameters after)
    local lfo_xml = string.format([=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="LfoDevice">
    <IsMaximized>true</IsMaximized>
    <Amplitude>
      <Value>0.5</Value>
    </Amplitude>
    <Offset>
      <Value>0.0</Value>
    </Offset>
    <Frequency>
      <Value>%.6f</Value>
    </Frequency>
    <Type>
      <Value>0.0</Value>
    </Type>
    <CustomEnvelope>
      <PlayMode>Lines</PlayMode>
      <Length>%d</Length>
      <ValueQuantum>0.0</ValueQuantum>
      <Polarity>Unipolar</Polarity>
      <Points>
        %s
      </Points>
    </CustomEnvelope>
    <CustomEnvelopeOneShot>false</CustomEnvelopeOneShot>
    <UseAdjustedEnvelopeLength>true</UseAdjustedEnvelopeLength>
  </DeviceSlot>
</FilterDevicePreset>]=], freq_value, #envelope_points, table.concat(points_xml, "\n        "))
    
    device.active_preset_data = lfo_xml
    
    -- Set routing via parameters (the correct way!)
    -- parameters[1] = Dest. Track (-1 = "Cur" = current chain)
    -- parameters[2] = Dest. Effect (0-based device index in dropdown)
    -- parameters[3] = Dest. Parameter (0=None, 1=Gain, 2=Panning for Gainer)
    if dest_device_index and dest_param_index then
      local effect_index = dest_device_index - 1  -- Convert 1-based position to 0-based dropdown index
      local param_index = dest_param_index        -- 1 = Gain (no conversion needed)
      
      device.parameters[1].value = -1          -- Current chain ("Cur")
      device.parameters[2].value = effect_index  -- Target device (0-based)
      device.parameters[3].value = param_index   -- Target parameter (1 = Gain)
      
      print(string.format("DEBUG LFO '%s': Set routing params[1]=-1, params[2]=%d (device %d), params[3]=%d (Gain)",
        display_name, effect_index, dest_device_index, param_index))
    end
  end
  
  return device
end

-- Create a Hydra device for multi-target modulation
function PakettiMetaSynthCreateHydra(chain, display_name)
  local position = #chain.devices + 1
  local device = PakettiMetaSynthInsertDevice(chain, "*Hydra", position)
  
  if device then
    device.display_name = display_name or "Crossfade Hydra"
  end
  
  return device
end

-- Build a complete FX chain with random devices
function PakettiMetaSynthBuildRandomFXChain(chain, device_pool, device_count, randomization_amount)
  device_count = device_count or 2
  randomization_amount = randomization_amount or 0.3
  
  local inserted_devices = {}
  
  for i = 1, device_count do
    local random_device = device_pool[math.random(1, #device_pool)]
    local device = PakettiMetaSynthInsertDevice(chain, random_device)
    
    if device then
      PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
      table.insert(inserted_devices, device)
    end
  end
  
  return inserted_devices
end

-- Selectable FX types for Group Master and Stacked Master (glue-appropriate FX)
PakettiMetaSynthSelectableFXTypes = {
  { name = "Filter", device = "Analog Filter" },
  { name = "Digital Filter", device = "Digital Filter" },
  { name = "EQ", device = "EQ 5" },
  { name = "Saturation", device = "Distortion 2" },
  { name = "LoFi", device = "LofiMat 2" },
  { name = "Chorus", device = "Chorus 2" },
  { name = "Phaser", device = "Phaser 2" },
  { name = "Flanger", device = "Flanger 2" },
  { name = "Comb Filter", device = "Comb Filter 2" },
  { name = "Delay", device = "Delay" },
  { name = "Ring Mod", device = "RingMod 2" },
  { name = "Stereo Expander", device = "Stereo Expander" }
}

-- Get list of selectable FX type names (for GUI)
function PakettiMetaSynthGetSelectableFXTypeNames()
  local names = {}
  for _, fx in ipairs(PakettiMetaSynthSelectableFXTypes) do
    table.insert(names, fx.name)
  end
  return names
end

-- Get device name from FX type name
function PakettiMetaSynthGetDeviceForFXType(fx_type_name)
  for _, fx in ipairs(PakettiMetaSynthSelectableFXTypes) do
    if fx.name == fx_type_name then
      return fx.device
    end
  end
  return nil
end

-- Build a specific FX device by type name
function PakettiMetaSynthBuildFXByType(chain, fx_type_name, randomization_amount)
  local device_name = PakettiMetaSynthGetDeviceForFXType(fx_type_name)
  if not device_name then
    print("PakettiMetaSynth: Unknown FX type '" .. tostring(fx_type_name) .. "'")
    return nil
  end
  
  local device = PakettiMetaSynthInsertDevice(chain, device_name)
  if device then
    PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount or 0.3)
  end
  return device
end

-- Build FX devices based on mode (random or selective)
function PakettiMetaSynthBuildMasterFXDevices(chain, mode, device_count, fx_types, randomization_amount, display_prefix)
  randomization_amount = randomization_amount or 0.3
  display_prefix = display_prefix or "Master"
  
  local inserted_devices = {}
  
  if mode == "selective" and fx_types and #fx_types > 0 then
    -- Selective mode: use specified FX types
    for i = 1, device_count do
      -- Cycle through the selected types
      local type_index = ((i - 1) % #fx_types) + 1
      local fx_type_name = fx_types[type_index]
      local device = PakettiMetaSynthBuildFXByType(chain, fx_type_name, randomization_amount)
      if device then
        device.display_name = string.format("%s %s %d", display_prefix, fx_type_name, i)
        table.insert(inserted_devices, device)
      end
    end
  else
    -- Random mode: use the safe FX device pool
    for i = 1, device_count do
      local random_device = PakettiMetaSynthSafeFXDevices[math.random(1, #PakettiMetaSynthSafeFXDevices)]
      local device = PakettiMetaSynthInsertDevice(chain, random_device)
      if device then
        PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
        device.display_name = string.format("%s FX %d", display_prefix, i)
        table.insert(inserted_devices, device)
      end
    end
  end
  
  return inserted_devices
end

-- ============================================================================
-- SECTION 3: CROSSFADE CURVE ENGINE
-- ============================================================================

-- Generate linear crossfade curve points (with division by zero protection)
function PakettiMetaSynthGenerateLinearCrossfade(num_points, frame_index, total_frames)
  local points = {}
  
  -- Handle edge case: single frame = full gain
  if total_frames <= 1 then
    for i = 1, num_points do
      table.insert(points, {time = i, value = 1.0})
    end
    return points
  end
  
  -- Handle edge case: single point
  if num_points <= 1 then
    table.insert(points, {time = 1, value = frame_index == 1 and 1.0 or 0.0})
    return points
  end
  
  for i = 1, num_points do
    local position = (i - 1) / (num_points - 1)
    local value
    
    if total_frames == 2 then
      -- Simple A/B crossfade
      if frame_index == 1 then
        value = 1.0 - position
      else
        value = position
      end
    else
      -- Multi-frame crossfade
      local frame_width = 1.0 / (total_frames - 1)
      local frame_center = (frame_index - 1) * frame_width
      local distance = math.abs(position - frame_center)
      
      if distance <= frame_width then
        value = 1.0 - (distance / frame_width)
      else
        value = 0.0
      end
    end
    
    table.insert(points, {time = i, value = value})
  end
  
  return points
end

-- Generate equal power crossfade curve points (with division by zero protection)
function PakettiMetaSynthGenerateEqualPowerCrossfade(num_points, frame_index, total_frames)
  local points = {}
  
  -- Handle edge case: single frame = full gain
  if total_frames <= 1 then
    for i = 1, num_points do
      table.insert(points, {time = i, value = 1.0})
    end
    return points
  end
  
  -- Handle edge case: single point
  if num_points <= 1 then
    table.insert(points, {time = 1, value = frame_index == 1 and 1.0 or 0.0})
    return points
  end
  
  for i = 1, num_points do
    local position = (i - 1) / (num_points - 1)
    local value
    
    if total_frames == 2 then
      -- Simple A/B equal power crossfade
      if frame_index == 1 then
        value = math.cos(position * math.pi / 2)
      else
        value = math.sin(position * math.pi / 2)
      end
    else
      -- Multi-frame equal power crossfade
      local frame_width = 1.0 / (total_frames - 1)
      local frame_center = (frame_index - 1) * frame_width
      local distance = math.abs(position - frame_center)
      
      if distance <= frame_width then
        local normalized = distance / frame_width
        value = math.cos(normalized * math.pi / 2)
      else
        value = 0.0
      end
    end
    
    table.insert(points, {time = i, value = value})
  end
  
  return points
end

-- Generate S-curve crossfade (smooth transitions) (with division by zero protection)
function PakettiMetaSynthGenerateSCurveCrossfade(num_points, frame_index, total_frames)
  local points = {}
  
  -- Handle edge case: single frame = full gain
  if total_frames <= 1 then
    for i = 1, num_points do
      table.insert(points, {time = i, value = 1.0})
    end
    return points
  end
  
  -- Handle edge case: single point
  if num_points <= 1 then
    table.insert(points, {time = 1, value = frame_index == 1 and 1.0 or 0.0})
    return points
  end
  
  for i = 1, num_points do
    local position = (i - 1) / (num_points - 1)
    local value
    
    if total_frames == 2 then
      -- S-curve using smoothstep
      local t = position
      local smooth_t = t * t * (3 - 2 * t)
      
      if frame_index == 1 then
        value = 1.0 - smooth_t
      else
        value = smooth_t
      end
    else
      -- Multi-frame S-curve
      local frame_width = 1.0 / (total_frames - 1)
      local frame_center = (frame_index - 1) * frame_width
      local distance = math.abs(position - frame_center)
      
      if distance <= frame_width then
        local normalized = distance / frame_width
        local smooth_t = normalized * normalized * (3 - 2 * normalized)
        value = 1.0 - smooth_t
      else
        value = 0.0
      end
    end
    
    table.insert(points, {time = i, value = value})
  end
  
  return points
end

-- Master function to generate crossfade curves
function PakettiMetaSynthGenerateCrossfadeCurve(curve_type, num_points, frame_index, total_frames)
  num_points = num_points or 128
  
  if curve_type == "linear" then
    return PakettiMetaSynthGenerateLinearCrossfade(num_points, frame_index, total_frames)
  elseif curve_type == "equal_power" then
    return PakettiMetaSynthGenerateEqualPowerCrossfade(num_points, frame_index, total_frames)
  elseif curve_type == "s_curve" then
    return PakettiMetaSynthGenerateSCurveCrossfade(num_points, frame_index, total_frames)
  else
    -- Default to equal power
    return PakettiMetaSynthGenerateEqualPowerCrossfade(num_points, frame_index, total_frames)
  end
end

-- ============================================================================
-- SECTION 4: SAMPLE FOLDER LOADER
-- ============================================================================

-- Supported audio file extensions
PakettiMetaSynthAudioExtensions = {
  ".wav", ".aiff", ".aif", ".flac", ".ogg", ".mp3"
}

-- Check if a file has a supported audio extension
function PakettiMetaSynthIsSupportedAudioFile(filename)
  local lower_filename = filename:lower()
  for _, ext in ipairs(PakettiMetaSynthAudioExtensions) do
    if lower_filename:sub(-#ext) == ext then
      return true
    end
  end
  return false
end

-- Scan a folder for audio files
function PakettiMetaSynthScanFolder(folder_path)
  local files = {}
  
  -- Use the getfiles function from main.lua if available
  if getfiles then
    local all_files = getfiles(folder_path)
    for _, filepath in ipairs(all_files) do
      if PakettiMetaSynthIsSupportedAudioFile(filepath) then
        table.insert(files, filepath)
      end
    end
  else
    -- Fallback: try to use io.popen (may not work on all platforms)
    local cmd
    if os.platform() == "WINDOWS" then
      cmd = 'dir /b "' .. folder_path .. '"'
    else
      cmd = 'ls "' .. folder_path .. '"'
    end
    
    local handle = io.popen(cmd)
    if handle then
      for line in handle:lines() do
        if PakettiMetaSynthIsSupportedAudioFile(line) then
          local filepath = folder_path .. package.config:sub(1,1) .. line
          table.insert(files, filepath)
        end
      end
      handle:close()
    end
  end
  
  return files
end

-- Get AKWF file list (cached for performance)
function PakettiMetaSynthGetAKWFList()
  -- Return cached list if available
  if PakettiMetaSynthAKWFCache then
    return PakettiMetaSynthAKWFCache
  end
  
  local tool_path = renoise.tool().bundle_path
  local akwf_path = tool_path .. "AKWF/"
  local akwf_list_path = akwf_path .. "akwf.txt"
  
  local akwf_file = io.open(akwf_list_path, "r")
  if not akwf_file then
    print("PakettiMetaSynth: Could not find AKWF sample list at " .. akwf_list_path)
    return {}
  end
  
  local wav_files = {}
  for line in akwf_file:lines() do
    table.insert(wav_files, akwf_path .. line)
  end
  akwf_file:close()
  
  -- Cache the list
  PakettiMetaSynthAKWFCache = wav_files
  
  return wav_files
end

-- Get random samples from AKWF folder (uses cached list)
function PakettiMetaSynthGetRandomAKWFSamples(count)
  local wav_files = PakettiMetaSynthGetAKWFList()
  
  if #wav_files == 0 then
    return {}
  end
  
  -- Random selection
  local selected = {}
  for i = 1, count do
    local random_index = math.random(1, #wav_files)
    table.insert(selected, wav_files[random_index])
  end
  
  return selected
end

-- Get random samples from a user folder
function PakettiMetaSynthGetRandomSamplesFromFolder(folder_path, count)
  local files = PakettiMetaSynthScanFolder(folder_path)
  
  if #files == 0 then
    return {}
  end
  
  local selected = {}
  for i = 1, count do
    local random_index = math.random(1, #files)
    table.insert(selected, files[random_index])
  end
  
  return selected
end

-- Load a sample file into an instrument sample slot
function PakettiMetaSynthLoadSampleIntoSlot(instrument, sample_index, filepath)
  -- Ensure sample slot exists
  while #instrument.samples < sample_index do
    instrument:insert_sample_at(#instrument.samples + 1)
  end
  
  local sample = instrument.samples[sample_index]
  local success = sample.sample_buffer:load_from(filepath)
  
  if success then
    -- Extract filename for sample name
    local filename = filepath:match("([^/\\]+)$") or "Sample"
    sample.name = filename:gsub("%.[^%.]+$", "")
  end
  
  return success
end

-- ============================================================================
-- SECTION 5: MODULATION BUILDER
-- ============================================================================

-- Create a new modulation set in the instrument
function PakettiMetaSynthCreateModulationSet(instrument, set_name)
  local set_index = #instrument.sample_modulation_sets + 1
  instrument:insert_sample_modulation_set_at(set_index)
  local mod_set = instrument.sample_modulation_sets[set_index]
  mod_set.name = set_name
  return mod_set, set_index
end

-- Add an AHDSR device to a modulation set
function PakettiMetaSynthAddAHDSRToModSet(mod_set, target_type, params)
  params = params or {}
  
  -- Get available devices
  local available = mod_set.available_devices
  local ahdsr_path = nil
  
  for _, device_path in ipairs(available) do
    if device_path:find("AHDSR") then
      ahdsr_path = device_path
      break
    end
  end
  
  if not ahdsr_path then
    print("PakettiMetaSynth: AHDSR device not found in available modulation devices")
    return nil
  end
  
  local device_index = #mod_set.devices + 1
  mod_set:insert_device_at(ahdsr_path, target_type, device_index)
  local device = mod_set.devices[device_index]
  
  if device then
    -- Set AHDSR parameters
    if params.attack and device.attack then
      device.attack.value = params.attack
    end
    if params.hold and device.hold then
      device.hold.value = params.hold
    end
    if params.decay and device.decay then
      device.decay.value = params.decay
    end
    if params.sustain and device.sustain then
      device.sustain.value = params.sustain
    end
    if params.release and device.release then
      device.release.value = params.release
    end
  end
  
  return device
end

-- Add an LFO device to a modulation set
function PakettiMetaSynthAddLFOToModSet(mod_set, target_type, params)
  params = params or {}
  
  local available = mod_set.available_devices
  local lfo_path = nil
  
  for _, device_path in ipairs(available) do
    if device_path:find("LFO") then
      lfo_path = device_path
      break
    end
  end
  
  if not lfo_path then
    print("PakettiMetaSynth: LFO device not found in available modulation devices")
    return nil
  end
  
  local device_index = #mod_set.devices + 1
  mod_set:insert_device_at(lfo_path, target_type, device_index)
  local device = mod_set.devices[device_index]
  
  if device then
    if params.frequency and device.frequency then
      device.frequency.value = params.frequency
    end
    if params.amount and device.amplitude then
      device.amplitude.value = params.amount
    end
    -- Note: SampleLfoModulationDevice does not have a 'phase' property in the API
    -- Phase offset would require XML injection if needed
    if params.mode and device.mode then
      device.mode = params.mode
    end
  end
  
  return device
end

-- Map a macro to a device parameter
function PakettiMetaSynthMapMacroToParameter(instrument, macro_index, parameter)
  if macro_index < 1 or macro_index > 8 then
    print("PakettiMetaSynth: Invalid macro index " .. tostring(macro_index))
    return false
  end
  
  local macro = instrument.macros[macro_index]
  
  -- Note: Direct mapping creation requires using the GUI or XML injection
  -- The API provides read access to mappings but not direct creation
  -- For now, we'll just set up the macro value
  macro.value = 0.5
  
  return true
end

-- ============================================================================
-- SECTION 6: FRAME-BASED FX ROUTING
-- ============================================================================

-- Assign a sample to a specific FX chain
function PakettiMetaSynthAssignSampleToFXChain(sample, chain_index)
  sample.device_chain_index = chain_index
end

-- Assign a sample to a specific modulation set
function PakettiMetaSynthAssignSampleToModSet(sample, mod_set_index)
  sample.modulation_set_index = mod_set_index
end

-- Build frame-based FX routing for an oscillator
function PakettiMetaSynthBuildFrameRouting(instrument, osc_config, base_chain_index, crossfade_config)
  local chains_created = {}
  local frame_count = osc_config.frame_count
  
  for frame = 1, frame_count do
    local chain_name = string.format("%s Frame %d", osc_config.name, frame)
    local chain, chain_index = PakettiMetaSynthCreateFXChain(instrument, chain_name)
    
    -- Add random FX if enabled
    if osc_config.fx_randomization and osc_config.fx_randomization.enabled then
      PakettiMetaSynthBuildRandomFXChain(
        chain, 
        osc_config.fx_randomization.device_pool or PakettiMetaSynthSafeFXDevices,
        2,
        osc_config.fx_randomization.param_randomization or 0.3
      )
    end
    
    -- Add crossfade gainer at the end
    local crossfade_curve = PakettiMetaSynthGenerateCrossfadeCurve(
      crossfade_config.curve_type,
      128,
      frame,
      frame_count
    )
    
    -- Create gainer with initial gain based on frame position
    local initial_gain = crossfade_curve[1].value
    local gainer, gainer_position = PakettiMetaSynthCreateGainer(chain, initial_gain, "Crossfade Gain")
    
    -- DEBUG: Print gainer info
    print(string.format("DEBUG Frame %d: Created Gainer at position %d, chain has %d devices total",
      frame, gainer_position, #chain.devices))
    
    -- If using LFO control, create LFO with crossfade envelope and route to gainer
    local lfo = nil
    if crossfade_config.control_source == "lfo" and frame_count > 1 then
      print(string.format("DEBUG Frame %d: Creating LFO to route to Gainer at position %d, param 1 (Gain)",
        frame, gainer_position))
      
      -- Calculate LFO frequency from rate settings
      local lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
        crossfade_config.lfo_rate_mode,
        crossfade_config.lfo_rate_free,
        crossfade_config.lfo_rate_sync,
        crossfade_config.lfo_rate_preset
      )
      
      -- Route LFO to the Gainer's gain parameter (parameter 1)
      lfo = PakettiMetaSynthCreateCrossfadeLFO(
        chain, 
        crossfade_curve, 
        "Frame " .. frame .. " Crossfade",
        gainer_position,  -- Destination device index
        1,                -- Destination parameter index (Gain)
        lfo_freq          -- LFO frequency
      )
    end
    
    table.insert(chains_created, {
      chain = chain,
      chain_index = chain_index,
      frame = frame,
      gainer = gainer,
      gainer_position = gainer_position,
      lfo = lfo,
      crossfade_curve = crossfade_curve
    })
  end
  
  return chains_created
end

-- Build group-level crossfade routing for oscillator-to-oscillator morphing (wavetable scanning)
-- This adds a Group Gainer and Group LFO to each frame chain of an oscillator
function PakettiMetaSynthBuildGroupCrossfadeRouting(chains_created, osc_index, total_oscs, group_config)
  -- Skip if only one oscillator (nothing to crossfade between)
  if total_oscs <= 1 then
    return chains_created
  end
  
  -- Skip if group crossfade is disabled
  if not group_config.group_crossfade_enabled then
    return chains_created
  end
  
  local curve_type = group_config.group_crossfade_curve or "equal_power"
  local crossfade_time = group_config.group_crossfade_time or 4.0
  
  -- Generate crossfade curve for this oscillator's position within the group
  local group_crossfade_curve = PakettiMetaSynthGenerateCrossfadeCurve(
    curve_type,
    128,
    osc_index,
    total_oscs
  )
  
  -- Add Group Gainer and LFO to each frame chain
  for _, chain_info in ipairs(chains_created) do
    local chain = chain_info.chain
    
    -- Create Group Gainer at the end of the chain
    local initial_gain = group_crossfade_curve[1].value
    local group_gainer, group_gainer_position = PakettiMetaSynthCreateGainer(
      chain, 
      initial_gain, 
      string.format("Group XFade Osc %d/%d", osc_index, total_oscs)
    )
    
    -- Create Group LFO with crossfade envelope routed to the Group Gainer
    -- Scale envelope points by crossfade time
    local scaled_curve = {}
    for i, point in ipairs(group_crossfade_curve) do
      table.insert(scaled_curve, {
        time = point.time,
        value = point.value
      })
    end
    
    -- Calculate Group LFO frequency from rate settings
    local group_lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
      group_config.group_lfo_rate_mode,
      group_config.group_lfo_rate_free,
      group_config.group_lfo_rate_sync,
      group_config.group_lfo_rate_preset
    )
    
    local group_lfo = PakettiMetaSynthCreateCrossfadeLFO(
      chain,
      scaled_curve,
      string.format("Group LFO Osc %d", osc_index),
      group_gainer_position,  -- Destination device index
      1,                      -- Destination parameter index (Gain)
      group_lfo_freq          -- LFO frequency
    )
    
    -- Store group crossfade info in chain_info
    chain_info.group_gainer = group_gainer
    chain_info.group_gainer_position = group_gainer_position
    chain_info.group_lfo = group_lfo
    chain_info.group_crossfade_curve = group_crossfade_curve
    chain_info.osc_position = osc_index
    chain_info.total_oscs = total_oscs
  end
  
  return chains_created
end

-- Add group-level crossfade to a single chain (typically the Oscillator FX chain)
-- This is used when Oscillator FX is enabled, so Group Gainer goes on the Osc FX chain instead of every frame chain
function PakettiMetaSynthAddGroupCrossfadeToChain(chain, chain_info, osc_index, total_oscs, group_config)
  -- Skip if only one oscillator (nothing to crossfade between)
  if total_oscs <= 1 then
    return chain_info
  end
  
  -- Skip if group crossfade is disabled
  if not group_config.group_crossfade_enabled then
    return chain_info
  end
  
  local curve_type = group_config.group_crossfade_curve or "equal_power"
  local crossfade_time = group_config.group_crossfade_time or 4.0
  
  -- Generate crossfade curve for this oscillator's position within the group
  local group_crossfade_curve = PakettiMetaSynthGenerateCrossfadeCurve(
    curve_type,
    128,
    osc_index,
    total_oscs
  )
  
  -- Create Group Gainer at the end of the chain
  local initial_gain = group_crossfade_curve[1].value
  local group_gainer, group_gainer_position = PakettiMetaSynthCreateGainer(
    chain, 
    initial_gain, 
    string.format("Group XFade Osc %d/%d", osc_index, total_oscs)
  )
  
  -- Create Group LFO with crossfade envelope routed to the Group Gainer
  local scaled_curve = {}
  for i, point in ipairs(group_crossfade_curve) do
    table.insert(scaled_curve, {
      time = point.time,
      value = point.value
    })
  end
  
  -- Calculate Group LFO frequency from rate settings
  local group_lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
    group_config.group_lfo_rate_mode,
    group_config.group_lfo_rate_free,
    group_config.group_lfo_rate_sync,
    group_config.group_lfo_rate_preset
  )
  
  local group_lfo = PakettiMetaSynthCreateCrossfadeLFO(
    chain,
    scaled_curve,
    string.format("Group LFO Osc %d", osc_index),
    group_gainer_position,  -- Destination device index
    1,                      -- Destination parameter index (Gain)
    group_lfo_freq          -- LFO frequency
  )
  
  -- Store group crossfade info in chain_info
  chain_info.group_gainer = group_gainer
  chain_info.group_gainer_position = group_gainer_position
  chain_info.group_lfo = group_lfo
  chain_info.group_crossfade_curve = group_crossfade_curve
  chain_info.osc_position = osc_index
  chain_info.total_oscs = total_oscs
  
  return chain_info
end

-- Helper function to add a #Send device to a chain that routes to a destination chain
-- NOTE: dest_chain_index is 1-based (Lua convention), but #Send Receiver is 0-based
function PakettiMetaSynthAddSendDevice(chain, dest_chain_index, display_name)
  local position = #chain.devices + 1
  local success, err = pcall(function()
    chain:insert_device_at("Audio/Effects/Native/#Send", position)
  end)
  
  if not success then
    print("PakettiMetaSynth: Failed to insert #Send device: " .. tostring(err))
    return nil
  end
  
  local send_device = chain.devices[position]
  if send_device then
    -- Convert 1-based chain index to 0-based Receiver index
    local receiver_index = dest_chain_index - 1
    
    -- Apply Send device configuration via XML
    local send_xml = string.format([=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="SendDevice">
    <IsMaximized>true</IsMaximized>
    <SendAmount>
      <Value>1.0</Value>
    </SendAmount>
    <SendPan>
      <Value>0.5</Value>
    </SendPan>
    <DestSendTrack>
      <Value>%d</Value>
    </DestSendTrack>
    <MuteSource>true</MuteSource>
    <SmoothParameterChanges>true</SmoothParameterChanges>
    <ApplyPostVolume>true</ApplyPostVolume>
  </DeviceSlot>
</FilterDevicePreset>]=], receiver_index)
    
    send_device.active_preset_data = send_xml
    send_device.display_name = display_name or "#Send"
    send_device.parameters[1].value = 1.0   -- Amount = 100%
    send_device.parameters[2].value = 0.5   -- Panning = center
    send_device.parameters[3].value = receiver_index  -- Receiver = 0-based index
    send_device.parameters[1].show_in_mixer = true
  end
  
  return send_device
end

-- Create Oscillator FX chain (NO routing - chain creation only)
-- ALWAYS creates ONE dedicated FX chain per oscillator as a summing bus
-- This sits between frame morphing and group morphing in the signal flow
-- Structure: [Osc FX devices (0+)] → [Osc Gainer + LFO added later]
-- Routing is done separately in Phase 2
function PakettiMetaSynthCreateOscillatorFXChain(instrument, osc_config, randomization_amount)
  -- ALWAYS create the Osc FX chain as a summing bus (even with 0 FX devices)
  randomization_amount = randomization_amount or 0.3
  
  -- Create a dedicated Oscillator FX chain
  local osc_fx_chain_name = osc_config.name .. " FX"
  local osc_fx_chain_index = #instrument.sample_device_chains + 1
  instrument:insert_sample_device_chain_at(osc_fx_chain_index)
  local osc_fx_chain = instrument.sample_device_chains[osc_fx_chain_index]
  osc_fx_chain.name = osc_fx_chain_name
  PakettiMetaSynthAddDCOffset(osc_fx_chain)
  
  -- Add FX devices to the Oscillator FX chain ONLY if FX is enabled
  local osc_fx_devices = {}
  
  if osc_config.osc_fx_enabled then
    local mode = osc_config.osc_fx_mode or "random"
    local device_count = osc_config.osc_fx_count or 2
    local fx_types = osc_config.osc_fx_types or {}
    
    if mode == "selective" and #fx_types > 0 then
      -- Selective mode: use specified FX types
      for i = 1, device_count do
        local type_index = ((i - 1) % #fx_types) + 1
        local fx_type_name = fx_types[type_index]
        local device = PakettiMetaSynthBuildFXByType(osc_fx_chain, fx_type_name, randomization_amount)
        if device then
          device.display_name = string.format("OscFX %s %d", fx_type_name, i)
          table.insert(osc_fx_devices, device)
        end
      end
    else
      -- Random mode: use random devices from the safe pool
      for i = 1, device_count do
        local random_device = PakettiMetaSynthSafeFXDevices[math.random(1, #PakettiMetaSynthSafeFXDevices)]
        local device = PakettiMetaSynthInsertDevice(osc_fx_chain, random_device)
        if device then
          PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
          device.display_name = string.format("OscFX %d", i)
          table.insert(osc_fx_devices, device)
        end
      end
    end
  end
  
  print(string.format("PakettiMetaSynth: Created Oscillator FX bus '%s' with %d FX devices", 
    osc_fx_chain_name, #osc_fx_devices))
  
  -- Return the oscillator FX chain info (Osc Gainer added later, routing in Phase 2)
  return {
    chain = osc_fx_chain,
    chain_index = osc_fx_chain_index,
    chain_name = osc_fx_chain_name,
    devices = osc_fx_devices,
    osc_name = osc_config.name
  }
end

-- Create Group Master FX chain (NO routing - chain creation only)
-- ALWAYS creates ONE dedicated FX chain per group as a summing bus
-- Structure: [Group FX devices (0+)] → [Group Gainer + LFO]
-- Routing is done separately in Phase 2
function PakettiMetaSynthCreateGroupMasterChain(instrument, group_config, group_name, group_index, total_groups, randomization_amount)
  -- ALWAYS create the Group Master chain as a summing bus (even with 0 FX devices)
  randomization_amount = randomization_amount or 0.3
  
  -- Create a dedicated Group Master FX chain
  local master_chain_name = group_name .. " Master"
  local master_chain_index = #instrument.sample_device_chains + 1
  instrument:insert_sample_device_chain_at(master_chain_index)
  local master_chain = instrument.sample_device_chains[master_chain_index]
  master_chain.name = master_chain_name
  PakettiMetaSynthAddDCOffset(master_chain)
  
  -- Add FX devices to the Group Master chain ONLY if FX is enabled
  local group_master_devices = {}
  
  if group_config.group_master_fx_enabled then
    local mode = group_config.group_master_fx_mode or "random"
    local device_count = group_config.group_master_fx_count or 3
    local fx_types = group_config.group_master_fx_types or {}
    
    if mode == "selective" and #fx_types > 0 then
      -- Selective mode: use specified FX types
      for i = 1, device_count do
        local type_index = ((i - 1) % #fx_types) + 1
        local fx_type_name = fx_types[type_index]
        local device = PakettiMetaSynthBuildFXByType(master_chain, fx_type_name, randomization_amount)
        if device then
          device.display_name = string.format("GrpMaster %s %d", fx_type_name, i)
          table.insert(group_master_devices, device)
        end
      end
    else
      -- Random mode: use random devices from the safe pool
      for i = 1, device_count do
        local random_device = PakettiMetaSynthSafeFXDevices[math.random(1, #PakettiMetaSynthSafeFXDevices)]
        local device = PakettiMetaSynthInsertDevice(master_chain, random_device)
        if device then
          PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
          device.display_name = string.format("GrpMaster FX %d", i)
          table.insert(group_master_devices, device)
        end
      end
    end
  end
  
  -- ALWAYS add Group Gainer for group-level morphing/volume control
  -- Generate crossfade curve for this group's position
  local curve_type = group_config.group_crossfade_curve or "equal_power"
  local group_crossfade_curve = PakettiMetaSynthGenerateCrossfadeCurve(
    curve_type,
    128,
    group_index,
    total_groups
  )
  
  -- Create Group Gainer at the end of the chain
  local initial_gain = (total_groups > 1) and group_crossfade_curve[1].value or 1.0
  local group_gainer, group_gainer_position = PakettiMetaSynthCreateGainer(
    master_chain, 
    initial_gain, 
    string.format("Group Gainer %s", group_name)
  )
  
  -- Create Group LFO for group-level morphing (only if multiple groups)
  local group_lfo = nil
  if total_groups > 1 then
    local scaled_curve = {}
    for i, point in ipairs(group_crossfade_curve) do
      table.insert(scaled_curve, {
        time = point.time,
        value = point.value
      })
    end
    
    -- Calculate Group LFO frequency from rate settings
    local group_lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
      group_config.group_lfo_rate_mode,
      group_config.group_lfo_rate_free,
      group_config.group_lfo_rate_sync,
      group_config.group_lfo_rate_preset
    )
    
    group_lfo = PakettiMetaSynthCreateCrossfadeLFO(
      master_chain,
      scaled_curve,
      string.format("Group LFO %s", group_name),
      group_gainer_position,
      1,              -- Gain parameter
      group_lfo_freq  -- LFO frequency
    )
  end
  
  print(string.format("PakettiMetaSynth: Created Group Master bus '%s' with %d FX devices + Gainer", 
    master_chain_name, #group_master_devices))
  
  -- Return the group master chain info (routing in Phase 2)
  return {
    chain = master_chain,
    chain_index = master_chain_index,
    chain_name = master_chain_name,
    devices = group_master_devices,
    group_name = group_name,
    group_gainer = group_gainer,
    group_gainer_position = group_gainer_position,
    group_lfo = group_lfo,
    group_crossfade_curve = group_crossfade_curve
  }
end

-- Create Stacked Master FX chain (NO routing - chain creation only)
-- ALWAYS creates ONE dedicated FX chain for the entire instrument as final summing bus
-- Structure: [Stack FX devices (0+)]
-- Routing is done separately in Phase 2
function PakettiMetaSynthCreateStackedMasterChain(instrument, architecture, randomization_amount)
  -- ALWAYS create the Stacked Master chain as a summing bus (even with 0 FX devices)
  randomization_amount = randomization_amount or 0.3
  
  -- Create a dedicated Stacked Master FX chain
  local stacked_chain_name = "Stacked Master"
  local stacked_chain_index = #instrument.sample_device_chains + 1
  instrument:insert_sample_device_chain_at(stacked_chain_index)
  local stacked_chain = instrument.sample_device_chains[stacked_chain_index]
  stacked_chain.name = stacked_chain_name
  PakettiMetaSynthAddDCOffset(stacked_chain)
  
  -- Add FX devices to the Stacked Master chain ONLY if FX is enabled
  local stacked_master_devices = {}
  
  if architecture.stacked_master_fx_enabled then
    local mode = architecture.stacked_master_fx_mode or "random"
    local device_count = architecture.stacked_master_fx_count or 3
    local fx_types = architecture.stacked_master_fx_types or {}
    
    if mode == "selective" and #fx_types > 0 then
      -- Selective mode: use specified FX types
      for i = 1, device_count do
        local type_index = ((i - 1) % #fx_types) + 1
        local fx_type_name = fx_types[type_index]
        local device = PakettiMetaSynthBuildFXByType(stacked_chain, fx_type_name, randomization_amount)
        if device then
          device.display_name = string.format("StackMaster %s %d", fx_type_name, i)
          table.insert(stacked_master_devices, device)
        end
      end
    else
      -- Random mode: use random devices from the safe pool
      for i = 1, device_count do
        local random_device = PakettiMetaSynthSafeFXDevices[math.random(1, #PakettiMetaSynthSafeFXDevices)]
        local device = PakettiMetaSynthInsertDevice(stacked_chain, random_device)
        if device then
          PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
          device.display_name = string.format("StackMaster FX %d", i)
          table.insert(stacked_master_devices, device)
        end
      end
    end
  end
  
  print(string.format("PakettiMetaSynth: Created Stacked Master bus with %d FX devices", #stacked_master_devices))
  
  -- Return the stacked master chain info (routing in Phase 2)
  return {
    chain = stacked_chain,
    chain_index = stacked_chain_index,
    chain_name = stacked_chain_name,
    devices = stacked_master_devices
  }
end

-- ============================================================================
-- PHASE 2: ROUTING FUNCTIONS (Add sends AFTER all chains are created)
-- ============================================================================

-- Route all frame chains to their Oscillator FX chain using #Send devices
function PakettiMetaSynthRouteFramesToOscFX(frame_chains, osc_fx_info)
  if not osc_fx_info then return end
  
  local dest_chain_index = osc_fx_info.chain_index
  local dest_chain_name = osc_fx_info.chain_name
  
  for _, chain_info in ipairs(frame_chains) do
    local chain = chain_info.chain
    local send_device = PakettiMetaSynthAddSendDevice(
      chain, 
      dest_chain_index, 
      string.format("Send to %s", dest_chain_name)
    )
    chain_info.send_to_osc_fx = send_device
    chain_info.routed_to_osc_fx = dest_chain_name
  end
  
  print(string.format("PakettiMetaSynth: Routed %d frame chains -> %s (index %d)", 
    #frame_chains, dest_chain_name, dest_chain_index))
end

-- Route chains to their Group Master chain using #Send devices
-- source_chains: either Osc FX chains or frame chains (if no Osc FX)
function PakettiMetaSynthRouteChainsToGroupMaster(source_chains, group_master_info)
  if not group_master_info then return end
  
  local dest_chain_index = group_master_info.chain_index
  local dest_chain_name = group_master_info.chain_name
  
  for _, chain_info in ipairs(source_chains) do
    local chain = chain_info.chain
    local send_device = PakettiMetaSynthAddSendDevice(
      chain, 
      dest_chain_index, 
      string.format("Send to %s", dest_chain_name)
    )
    chain_info.send_to_group_master = send_device
    chain_info.routed_to_group_master = dest_chain_name
  end
  
  print(string.format("PakettiMetaSynth: Routed %d chains -> %s (index %d)", 
    #source_chains, dest_chain_name, dest_chain_index))
end

-- Route all Group Master chains to the Stacked Master chain using #Send devices
function PakettiMetaSynthRouteGroupMastersToStackedMaster(group_master_chains, stacked_master_info)
  if not stacked_master_info then return end
  if #group_master_chains == 0 then return end
  
  local dest_chain_index = stacked_master_info.chain_index
  local dest_chain_name = stacked_master_info.chain_name
  
  for _, group_master_info_item in ipairs(group_master_chains) do
    local chain = group_master_info_item.chain
    local send_device = PakettiMetaSynthAddSendDevice(
      chain,
      dest_chain_index,
      "Send to Stacked Master"
    )
    group_master_info_item.send_to_stacked_master = send_device
    print(string.format("PakettiMetaSynth: Routed '%s' -> Stacked Master (index %d)", 
      group_master_info_item.chain_name, dest_chain_index))
  end
end

-- ============================================================================
-- SECTION 7: INSTRUMENT GENERATION (TWO-PHASE APPROACH)
-- ============================================================================

-- Generate a complete instrument from an architecture
-- Uses two-phase approach: 
--   Phase 1: Create ALL chains first (no sends)
--   Phase 2: Add ALL sends using stable indices
function PakettiMetaSynthGenerateInstrument(architecture)
  -- Safety check: ensure song is loaded
  local song = renoise.song()
  if not song then
    renoise.app():show_status("PakettiMetaSynth: No song loaded")
    return nil
  end
  
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = nil
  if PakettiTemporarilyDisableNewSampleMonitoring then
    AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  end
  
  trueRandomSeed()
  
  -- Validate architecture first
  local validation = PakettiMetaSynthValidateArchitecture(architecture)
  if not validation.valid then
    for _, err in ipairs(validation.errors) do
      print("PakettiMetaSynth Error: " .. err)
    end
    renoise.app():show_status("PakettiMetaSynth: Architecture validation failed - check console")
    -- Restore AutoSamplify monitoring
    if PakettiRestoreNewSampleMonitoring and AutoSamplifyMonitoringState then
      PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    end
    return nil
  end
  
  -- Show warnings
  for _, warn in ipairs(validation.warnings) do
    print("PakettiMetaSynth Warning: " .. warn)
  end
  
  -- Create or reset instrument
  local instrument = song.selected_instrument
  instrument:clear()
  instrument.name = architecture.name
  
  local sample_index = 1
  local mod_set_index = 0
  local randomization_amount = architecture.fx_randomization and architecture.fx_randomization.param_randomization or 0.3
  
  -- ========================================================================
  -- CHAIN REGISTRY: Stores all chain info for Phase 2 routing
  -- ========================================================================
  local chain_registry = {
    -- Per-group data
    groups = {},  -- [group_index] = { frame_chains = {}, osc_fx_chains = {}, group_master = nil }
    -- Global
    stacked_master = nil
  }
  
  print("PakettiMetaSynth: === PHASE 1: Creating all chains (no sends) ===")
  
  -- ========================================================================
  -- PHASE 1: CREATE ALL CHAINS (NO ROUTING/SENDS)
  -- ========================================================================
  
  for gi, group in ipairs(architecture.oscillator_groups) do
    print(string.format("PakettiMetaSynth: Building Group '%s'", group.name))
    
    -- Initialize registry for this group
    chain_registry.groups[gi] = {
      group_name = group.name,
      oscillators = {},  -- [osc_index] = { frame_chains = {}, osc_fx = nil }
      group_master = nil
    }
    
    local total_oscs_in_group = #group.oscillators
    
    -- Process each oscillator in the group
    for oi, osc in ipairs(group.oscillators) do
      print(string.format("PakettiMetaSynth: Building Oscillator '%s' (%d samples, %d unison, %d frames)",
        osc.name, osc.sample_count, osc.unison_voices, osc.frame_count))
      
      -- Initialize registry for this oscillator
      chain_registry.groups[gi].oscillators[oi] = {
        osc_name = osc.name,
        frame_chains = {},
        osc_fx = nil
      }
      
      -- Get sample files based on source
      local sample_files = {}
      local total_samples_needed = osc.sample_count * osc.unison_voices
      
      if osc.sample_source == "akwf" then
        sample_files = PakettiMetaSynthGetRandomAKWFSamples(total_samples_needed)
      elseif osc.sample_source == "folder" and osc.sample_folder then
        sample_files = PakettiMetaSynthGetRandomSamplesFromFolder(osc.sample_folder, total_samples_needed)
      end
      
      -- Get current chain index before creating frame chains
      local starting_chain_index = #instrument.sample_device_chains
      
      -- Build frame chains for this oscillator (creates chains, adds FX, no sends)
      local frame_routing = PakettiMetaSynthBuildFrameRouting(
        instrument, 
        {
          name = osc.name,
          frame_count = osc.frame_count,
          fx_randomization = architecture.fx_randomization
        },
        starting_chain_index,
        architecture.crossfade
      )
      
      -- Store frame chains in registry
      for fi, frame_info in ipairs(frame_routing) do
        table.insert(chain_registry.groups[gi].oscillators[oi].frame_chains, frame_info)
      end
      
      -- ALWAYS create Oscillator FX chain as summing bus - NO ROUTING YET
      local osc_fx_info = PakettiMetaSynthCreateOscillatorFXChain(
        instrument,
        osc,
        randomization_amount
      )
      
      -- Store Osc FX chain in registry (always exists now)
      chain_registry.groups[gi].oscillators[oi].osc_fx = osc_fx_info
      
      -- Add Osc Gainer (for oscillator crossfade) to the Oscillator FX chain
      PakettiMetaSynthAddGroupCrossfadeToChain(
        osc_fx_info.chain,
        osc_fx_info,
        oi,
        total_oscs_in_group,
        group
      )
      
      -- Create modulation set for this oscillator
      local mod_set, mod_set_idx = PakettiMetaSynthCreateModulationSet(instrument, osc.name .. " Mod")
      mod_set_index = mod_set_idx
      
      -- Add AHDSR for volume
      PakettiMetaSynthAddAHDSRToModSet(mod_set, renoise.SampleModulationDevice.TARGET_VOLUME, {
        attack = 0.0,
        hold = 0.0,
        decay = 0.5,
        sustain = 0.8,
        release = 0.3
      })
      
      -- Add LFO for pitch vibrato if random phase offsets enabled
      if architecture.modulation and architecture.modulation.random_phase_offsets then
        PakettiMetaSynthAddLFOToModSet(mod_set, renoise.SampleModulationDevice.TARGET_PITCH, {
          frequency = 0.3 + math.random() * 0.3,
          amount = 0.02
        })
      end
      
      -- Get detune and pan spread values (with defaults)
      local detune_spread = osc.detune_spread or 10
      local pan_spread = osc.pan_spread or 0.8
      
      -- Load samples and assign to frames
      local file_index = 1
      for si = 1, osc.sample_count do
        for ui = 1, osc.unison_voices do
          -- Ensure sample slot exists
          while #instrument.samples < sample_index do
            instrument:insert_sample_at(#instrument.samples + 1)
          end
          
          local sample = instrument.samples[sample_index]
          
          -- Load sample if we have files
          if file_index <= #sample_files then
            local success = sample.sample_buffer:load_from(sample_files[file_index])
            if success then
              sample.name = string.format("%s S%d U%d", osc.name, si, ui)
            else
              sample.name = string.format("%s S%d U%d (load failed)", osc.name, si, ui)
            end
            file_index = file_index + 1
          else
            -- No file available, create silent sample
            sample.name = string.format("%s S%d U%d (empty)", osc.name, si, ui)
          end
          
          -- Apply unison detuning (with division by zero protection)
          if osc.unison_voices > 1 then
            local detune_offset = ((ui - 1) / (osc.unison_voices - 1) - 0.5) * 2 * detune_spread
            sample.fine_tune = math.floor(detune_offset * 1.28) -- Convert cents to Renoise fine tune
            
            -- Pan spread for unison
            local pan_offset = ((ui - 1) / (osc.unison_voices - 1) - 0.5) * 2 * pan_spread
            sample.panning = 0.5 + pan_offset * 0.5
          else
            -- Single voice: center pan, no detune
            sample.fine_tune = 0
            sample.panning = 0.5
          end
          
          -- Assign to frame (cycle through frames)
          local frame_for_sample = ((si - 1) % osc.frame_count) + 1
          local frame_chains = chain_registry.groups[gi].oscillators[oi].frame_chains
          if frame_chains[frame_for_sample] then
            PakettiMetaSynthAssignSampleToFXChain(sample, frame_chains[frame_for_sample].chain_index)
          end
          
          -- Assign to modulation set
          PakettiMetaSynthAssignSampleToModSet(sample, mod_set_index)
          
          -- Set loop mode for single-cycle waveforms
          if osc.sample_source == "akwf" then
            sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
          end
          
          sample_index = sample_index + 1
        end
      end
    end
    
    -- ALWAYS create Group Master chain as summing bus - NO ROUTING YET
    local total_groups = #architecture.oscillator_groups
    local group_master_info = PakettiMetaSynthCreateGroupMasterChain(
      instrument,
      group,
      group.name,
      gi,              -- group_index for Group Gainer crossfade position
      total_groups,    -- total_groups for Group Gainer crossfade calculation
      randomization_amount
    )
    
    -- Store Group Master in registry (always exists now)
    chain_registry.groups[gi].group_master = group_master_info
  end
  
  -- ALWAYS create Stacked Master chain as final summing bus - NO ROUTING YET
  local stacked_master_info = PakettiMetaSynthCreateStackedMasterChain(
    instrument,
    architecture,
    randomization_amount
  )
  
  -- Store Stacked Master in registry (always exists now)
  chain_registry.stacked_master = stacked_master_info
  
  -- ========================================================================
  -- PHASE 2: ADD ALL SENDS (using stable indices from registry)
  -- All buses now always exist, so routing is deterministic
  -- ========================================================================
  
  print("PakettiMetaSynth: === PHASE 2: Adding sends with stable indices ===")
  
  -- Collect all group master chains for Stacked Master routing
  local all_group_master_chains = {}
  
  for gi, group_data in ipairs(chain_registry.groups) do
    -- Collect Osc FX chains that need to route to Group Master
    local osc_fx_chains_for_group_master = {}
    
    for oi, osc_data in ipairs(group_data.oscillators) do
      -- Route Frame chains -> Osc FX chain (Osc FX always exists now)
      PakettiMetaSynthRouteFramesToOscFX(osc_data.frame_chains, osc_data.osc_fx)
      -- Osc FX chain goes to Group Master
      table.insert(osc_fx_chains_for_group_master, osc_data.osc_fx)
    end
    
    -- Route Osc FX chains -> Group Master (Group Master always exists now)
    PakettiMetaSynthRouteChainsToGroupMaster(osc_fx_chains_for_group_master, group_data.group_master)
    table.insert(all_group_master_chains, group_data.group_master)
  end
  
  -- Route Group Masters -> Stacked Master (Stacked Master always exists now)
  PakettiMetaSynthRouteGroupMastersToStackedMaster(all_group_master_chains, chain_registry.stacked_master)
  
  -- ========================================================================
  -- FINALIZATION
  -- ========================================================================
  
  -- Set up macros
  if architecture.crossfade.control_source == "macro" then
    local macro_idx = architecture.crossfade.macro_index
    if macro_idx >= 1 and macro_idx <= 8 then
      instrument.macros[macro_idx].name = "Crossfade"
      instrument.macros[macro_idx].value = 0.5
    end
  end
  
  -- Name additional macros
  instrument.macros[2].name = "Filter Cutoff"
  instrument.macros[3].name = "Filter Resonance"
  instrument.macros[4].name = "Attack"
  instrument.macros[5].name = "Release"
  
  -- Restore AutoSamplify monitoring
  if PakettiRestoreNewSampleMonitoring and AutoSamplifyMonitoringState then
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  end
  
  -- Calculate total chains
  local total_chains = #instrument.sample_device_chains
  
  renoise.app():show_status(string.format(
    "PakettiMetaSynth: Generated '%s' with %d samples, %d FX chains",
    architecture.name,
    sample_index - 1,
    total_chains
  ))
  
  return instrument
end

-- ============================================================================
-- SECTION 7B: WAVETABLE ARCHITECTURE GENERATOR
-- ============================================================================
-- This implements the "true wavetable" conceptual model where:
-- - All samples go to a SOURCE CHAIN (Frame 1)
-- - #Send devices split the signal to parallel FRAME FX chains
-- - Each frame applies different FX to the SAME source
-- - Frame Gainers + Frame Morph LFO blend between FX treatments
-- - Oscillator Groups provide wavetable-style scanning between oscillators

-- Generate a wavetable-style instrument from an architecture
function PakettiMetaSynthGenerateWavetableInstrument(architecture)
  -- Temporarily disable AutoSamplify monitoring
  local AutoSamplifyMonitoringState = nil
  if rawget(_G, "PakettiTemporarilyDisableNewSampleMonitoring") then
    AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  end
  
  -- Create new instrument
  local song = renoise.song()
  song:insert_instrument_at(song.selected_instrument_index + 1)
  local instrument = song.instruments[song.selected_instrument_index + 1]
  instrument.name = architecture.name or "MetaSynth Wavetable"
  song.selected_instrument_index = song.selected_instrument_index + 1
  
  local randomization_amount = architecture.fx_randomization and architecture.fx_randomization.param_randomization or 0.3
  local sample_index = 1
  
  -- Registry to track all chains for routing
  local chain_registry = {
    groups = {},
    stacked_master = nil
  }
  
  print("PakettiMetaSynth Wavetable: === PHASE 1: Creating all chains ===")
  
  -- ========================================================================
  -- PHASE 1: CREATE ALL CHAINS
  -- ========================================================================
  
  for gi, group in ipairs(architecture.oscillator_groups) do
    print(string.format("PakettiMetaSynth Wavetable: Building Group '%s'", group.name))
    
    chain_registry.groups[gi] = {
      group_name = group.name,
      oscillators = {},
      group_master = nil
    }
    
    local total_oscs_in_group = #group.oscillators
    
    for oi, osc in ipairs(group.oscillators) do
      print(string.format("PakettiMetaSynth Wavetable: Building Oscillator '%s' (%d samples, %d unison, %d frames)",
        osc.name, osc.sample_count, osc.unison_voices, osc.frame_count))
      
      chain_registry.groups[gi].oscillators[oi] = {
        osc_name = osc.name,
        source_chain = nil,
        frame_chains = {},
        osc_fx = nil
      }
      
      -- Get sample files
      local sample_files = {}
      local total_samples_needed = osc.sample_count * osc.unison_voices
      
      if osc.sample_source == "akwf" then
        sample_files = PakettiMetaSynthGetRandomAKWFSamples(total_samples_needed)
      elseif osc.sample_source == "folder" and osc.sample_folder then
        sample_files = PakettiMetaSynthGetRandomSamplesFromFolder(osc.sample_folder, total_samples_needed)
      end
      
      -- ================================================================
      -- CREATE SOURCE CHAIN (Frame 1) - All samples go here
      -- ================================================================
      local source_chain_name = string.format("%s Source", osc.name)
      local source_chain, source_chain_index = PakettiMetaSynthCreateFXChain(instrument, source_chain_name)
      
      chain_registry.groups[gi].oscillators[oi].source_chain = {
        chain = source_chain,
        chain_index = source_chain_index,
        chain_name = source_chain_name
      }
      
      -- ================================================================
      -- CREATE FRAME FX CHAINS (Frame 2, 3, N) - Receive via #Send
      -- ================================================================
      local frame_count = osc.frame_count
      
      for frame = 1, frame_count do
        local frame_chain_name = string.format("%s Frame %d", osc.name, frame)
        local frame_chain, frame_chain_index = PakettiMetaSynthCreateFXChain(instrument, frame_chain_name)
        
        -- Add random FX to each frame chain
        if architecture.fx_randomization and architecture.fx_randomization.enabled then
          PakettiMetaSynthBuildRandomFXChain(
            frame_chain,
            architecture.fx_randomization.device_pool or PakettiMetaSynthSafeFXDevices,
            2,
            randomization_amount
          )
        end
        
        -- Generate crossfade curve for this frame position
        local crossfade_curve = PakettiMetaSynthGenerateCrossfadeCurve(
          architecture.crossfade.curve_type or "equal_power",
          128,
          frame,
          frame_count
        )
        
        -- Add Frame Gainer at the end
        local initial_gain = crossfade_curve[1].value
        local gainer, gainer_position = PakettiMetaSynthCreateGainer(frame_chain, initial_gain, 
          string.format("Frame %d Gainer", frame))
        
        -- Add Frame Morph LFO (controls this frame's gainer)
        local lfo = nil
        if frame_count > 1 then
          -- Calculate Frame LFO frequency from rate settings
          local frame_lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
            architecture.crossfade.lfo_rate_mode,
            architecture.crossfade.lfo_rate_free,
            architecture.crossfade.lfo_rate_sync,
            architecture.crossfade.lfo_rate_preset
          )
          
          lfo = PakettiMetaSynthCreateCrossfadeLFO(
            frame_chain,
            crossfade_curve,
            string.format("Frame %d Morph LFO", frame),
            gainer_position,
            1,              -- Gain parameter
            frame_lfo_freq  -- LFO frequency
          )
        end
        
        table.insert(chain_registry.groups[gi].oscillators[oi].frame_chains, {
          chain = frame_chain,
          chain_index = frame_chain_index,
          chain_name = frame_chain_name,
          frame_number = frame,
          gainer = gainer,
          gainer_position = gainer_position,
          lfo = lfo,
          crossfade_curve = crossfade_curve
        })
      end
      
      -- ================================================================
      -- CREATE OSC FX CHAIN (summing bus for all frames)
      -- ================================================================
      local osc_fx_chain_name = osc.name .. " FX"
      local osc_fx_chain, osc_fx_chain_index = PakettiMetaSynthCreateFXChain(instrument, osc_fx_chain_name)
      
      -- Add Osc FX devices if enabled
      local osc_fx_devices = {}
      if osc.osc_fx_enabled then
        local device_count = osc.osc_fx_count or 2
        for i = 1, device_count do
          local random_device = PakettiMetaSynthSafeFXDevices[math.random(1, #PakettiMetaSynthSafeFXDevices)]
          local device = PakettiMetaSynthInsertDevice(osc_fx_chain, random_device)
          if device then
            PakettiMetaSynthRandomizeDeviceParams(device, randomization_amount)
            device.display_name = string.format("OscFX %d", i)
            table.insert(osc_fx_devices, device)
          end
        end
      end
      
      -- Add Osc Gainer for group crossfade (oscillator morphing within group)
      local osc_gainer = nil
      local osc_gainer_position = nil
      local osc_lfo = nil
      
      if total_oscs_in_group > 1 and group.group_crossfade_enabled then
        local osc_curve = PakettiMetaSynthGenerateCrossfadeCurve(
          group.group_crossfade_curve or "equal_power",
          128,
          oi,
          total_oscs_in_group
        )
        
        local osc_initial_gain = osc_curve[1].value
        osc_gainer, osc_gainer_position = PakettiMetaSynthCreateGainer(
          osc_fx_chain,
          osc_initial_gain,
          string.format("Osc %d/%d Gainer", oi, total_oscs_in_group)
        )
        
        -- Calculate Group LFO frequency from rate settings
        local group_lfo_freq = PakettiMetaSynthCalculateLFOFrequency(
          group.group_lfo_rate_mode,
          group.group_lfo_rate_free,
          group.group_lfo_rate_sync,
          group.group_lfo_rate_preset
        )
        
        osc_lfo = PakettiMetaSynthCreateCrossfadeLFO(
          osc_fx_chain,
          osc_curve,
          string.format("Osc %d Morph LFO", oi),
          osc_gainer_position,
          1,              -- Gain parameter
          group_lfo_freq  -- LFO frequency
        )
      end
      
      chain_registry.groups[gi].oscillators[oi].osc_fx = {
        chain = osc_fx_chain,
        chain_index = osc_fx_chain_index,
        chain_name = osc_fx_chain_name,
        devices = osc_fx_devices,
        osc_gainer = osc_gainer,
        osc_gainer_position = osc_gainer_position,
        osc_lfo = osc_lfo
      }
      
      print(string.format("PakettiMetaSynth Wavetable: Created Osc FX '%s' with %d devices", 
        osc_fx_chain_name, #osc_fx_devices))
      
      -- ================================================================
      -- CREATE MODULATION SET
      -- ================================================================
      local mod_set, mod_set_idx = PakettiMetaSynthCreateModulationSet(instrument, osc.name .. " Mod")
      
      PakettiMetaSynthAddAHDSRToModSet(mod_set, renoise.SampleModulationDevice.TARGET_VOLUME, {
        attack = 0.0,
        hold = 0.0,
        decay = 0.5,
        sustain = 0.8,
        release = 0.3
      })
      
      if architecture.modulation and architecture.modulation.random_phase_offsets then
        PakettiMetaSynthAddLFOToModSet(mod_set, renoise.SampleModulationDevice.TARGET_PITCH, {
          frequency = 0.3 + math.random() * 0.3,
          amount = 0.02
        })
      end
      
      -- ================================================================
      -- LOAD SAMPLES - ALL go to SOURCE CHAIN
      -- ================================================================
      local detune_spread = osc.detune_spread or 10
      local pan_spread = osc.pan_spread or 0.8
      local file_index = 1
      
      for si = 1, osc.sample_count do
        for ui = 1, osc.unison_voices do
          while #instrument.samples < sample_index do
            instrument:insert_sample_at(#instrument.samples + 1)
          end
          
          local sample = instrument.samples[sample_index]
          
          if file_index <= #sample_files then
            local success = sample.sample_buffer:load_from(sample_files[file_index])
            if success then
              sample.name = string.format("%s S%d U%d", osc.name, si, ui)
            else
              sample.name = string.format("%s S%d U%d (load failed)", osc.name, si, ui)
            end
            file_index = file_index + 1
          else
            sample.name = string.format("%s S%d U%d (empty)", osc.name, si, ui)
          end
          
          -- Unison detuning
          if osc.unison_voices > 1 then
            local detune_offset = ((ui - 1) / (osc.unison_voices - 1) - 0.5) * 2 * detune_spread
            sample.fine_tune = math.floor(detune_offset * 1.28)
            local pan_offset = ((ui - 1) / (osc.unison_voices - 1) - 0.5) * 2 * pan_spread
            sample.panning = 0.5 + pan_offset * 0.5
          else
            sample.fine_tune = 0
            sample.panning = 0.5
          end
          
          -- ALL samples go to SOURCE CHAIN (this is the key difference!)
          PakettiMetaSynthAssignSampleToFXChain(sample, source_chain_index)
          PakettiMetaSynthAssignSampleToModSet(sample, mod_set_idx)
          
          if osc.sample_source == "akwf" then
            sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
          end
          
          sample_index = sample_index + 1
        end
      end
    end
    
    -- ================================================================
    -- CREATE GROUP MASTER CHAIN
    -- ================================================================
    local total_groups = #architecture.oscillator_groups
    local group_master_info = PakettiMetaSynthCreateGroupMasterChain(
      instrument,
      group,
      group.name,
      gi,
      total_groups,
      randomization_amount
    )
    
    chain_registry.groups[gi].group_master = group_master_info
  end
  
  -- ================================================================
  -- CREATE STACKED MASTER CHAIN
  -- ================================================================
  local stacked_master_info = PakettiMetaSynthCreateStackedMasterChain(
    instrument,
    architecture,
    randomization_amount
  )
  chain_registry.stacked_master = stacked_master_info
  
  -- ========================================================================
  -- PHASE 2: ADD ALL ROUTING (#Send devices)
  -- ========================================================================
  
  print("PakettiMetaSynth Wavetable: === PHASE 2: Adding routing ===")
  
  local all_group_master_chains = {}
  
  for gi, group_data in ipairs(chain_registry.groups) do
    local osc_fx_chains_for_group = {}
    
    for oi, osc_data in ipairs(group_data.oscillators) do
      local source_chain = osc_data.source_chain.chain
      local frame_chains = osc_data.frame_chains
      local osc_fx = osc_data.osc_fx
      
      -- Route SOURCE CHAIN -> all FRAME CHAINS via #Send
      -- Frame 1 gets the dry signal (no send needed, just route output)
      -- Frames 2+ get signal via #Send from source
      
      for fi, frame_info in ipairs(frame_chains) do
        if fi == 1 then
          -- Frame 1: Route source chain output directly to Frame 1
          -- Add #Send from source to Frame 1
          PakettiMetaSynthAddSendDevice(
            source_chain,
            frame_info.chain_index,
            "Send to Frame 1"
          )
        else
          -- Frames 2+: Add #Send from source chain
          PakettiMetaSynthAddSendDevice(
            source_chain,
            frame_info.chain_index,
            string.format("Send to Frame %d", fi)
          )
        end
        
        -- Route each Frame chain -> Osc FX chain
        PakettiMetaSynthAddSendDevice(
          frame_info.chain,
          osc_fx.chain_index,
          "Send to Osc FX"
        )
      end
      
      print(string.format("PakettiMetaSynth Wavetable: Routed %s Source -> %d Frames -> Osc FX",
        osc_data.osc_name, #frame_chains))
      
      table.insert(osc_fx_chains_for_group, osc_fx)
    end
    
    -- Route all Osc FX chains -> Group Master
    PakettiMetaSynthRouteChainsToGroupMaster(osc_fx_chains_for_group, group_data.group_master)
    table.insert(all_group_master_chains, group_data.group_master)
  end
  
  -- Route Group Masters -> Stacked Master
  PakettiMetaSynthRouteGroupMastersToStackedMaster(all_group_master_chains, chain_registry.stacked_master)
  
  -- ========================================================================
  -- FINALIZATION
  -- ========================================================================
  
  if architecture.crossfade.control_source == "macro" then
    local macro_idx = architecture.crossfade.macro_index
    if macro_idx >= 1 and macro_idx <= 8 then
      instrument.macros[macro_idx].name = "Frame Morph"
      instrument.macros[macro_idx].value = 0.5
    end
  end
  
  instrument.macros[2].name = "Osc Morph"
  instrument.macros[3].name = "Filter Cutoff"
  instrument.macros[4].name = "Attack"
  instrument.macros[5].name = "Release"
  
  if rawget(_G, "PakettiRestoreNewSampleMonitoring") and AutoSamplifyMonitoringState then
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  end
  
  local total_chains = #instrument.sample_device_chains
  
  renoise.app():show_status(string.format(
    "PakettiMetaSynth Wavetable: Generated '%s' with %d samples, %d FX chains",
    architecture.name,
    sample_index - 1,
    total_chains
  ))
  
  return instrument
end

-- ============================================================================
-- SECTION 8: RANDOMIZATION SYSTEM
-- ============================================================================

-- Randomize oscillator configuration
function PakettiMetaSynthRandomizeOscillator(osc, max_samples_remaining)
  max_samples_remaining = max_samples_remaining or 12
  
  -- Random frame count FIRST (1-4) - determines minimum samples needed
  osc.frame_count = math.random(1, 4)
  
  -- Sample count must be >= frame_count so each frame has at least one sample
  -- Limited by remaining budget
  local min_samples = osc.frame_count
  local max_samples = math.min(4, max_samples_remaining)
  if min_samples > max_samples then
    -- Not enough budget for this many frames, reduce frame count
    osc.frame_count = max_samples
    min_samples = max_samples
  end
  osc.sample_count = math.max(min_samples, math.min(math.random(min_samples, 4), max_samples_remaining))
  
  -- Random unison (1-4), limited by remaining budget after samples
  local samples_used = osc.sample_count
  local max_unison = math.max(1, math.floor(max_samples_remaining / samples_used))
  osc.unison_voices = math.min(math.random(1, 4), max_unison)
  
  -- Check if a custom sample folder is configured
  if PakettiMetaSynthLastFolderPath and PakettiMetaSynthLastFolderPath ~= "" then
    -- Folder path is configured - allow random selection between akwf and folder
    local sources = {"akwf", "akwf", "akwf", "folder"}
    osc.sample_source = sources[math.random(1, #sources)]
    if osc.sample_source == "folder" then
      osc.sample_folder = PakettiMetaSynthLastFolderPath
    end
  else
    -- No folder path configured - always use AKWF
    osc.sample_source = "akwf"
  end
  
  -- Random spread values
  osc.detune_spread = 5 + math.random() * 20  -- 5-25 cents
  osc.pan_spread = 0.3 + math.random() * 0.7  -- 0.3-1.0
  
  -- Oscillator FX settings - always enabled to ensure full architecture
  osc.osc_fx_enabled = true
  osc.osc_fx_mode = math.random() > 0.5 and "random" or "selective"
  osc.osc_fx_count = math.random(1, 4)
  osc.osc_fx_types = {}
  
  -- If selective mode, randomly pick some FX types
  if osc.osc_fx_mode == "selective" then
    local fx_names = PakettiMetaSynthGetSelectableFXTypeNames()
    local num_types = math.random(1, math.min(3, #fx_names))
    local shuffled_types = {}
    for _, name in ipairs(fx_names) do table.insert(shuffled_types, name) end
    for i = #shuffled_types, 2, -1 do
      local j = math.random(1, i)
      shuffled_types[i], shuffled_types[j] = shuffled_types[j], shuffled_types[i]
    end
    for i = 1, num_types do
      table.insert(osc.osc_fx_types, shuffled_types[i])
    end
  end
  
  return osc
end

-- Randomize entire architecture
function PakettiMetaSynthRandomizeArchitecture(architecture)
  trueRandomSeed()
  
  -- Random number of oscillator groups (1-2)
  local num_groups = math.random(1, 2)
  architecture.oscillator_groups = {}
  
  local samples_remaining = 12
  
  -- LFO rate mode options
  local rate_modes = {"free", "tempo_sync", "preset"}
  local rate_presets = {"slow", "medium", "fast"}
  local rate_syncs = {"1/16", "1/8", "1/4", "1/2", "1 bar", "2 bars", "4 bars"}
  
  for gi = 1, num_groups do
    -- Randomize Group LFO rate settings
    local group_rate_mode = rate_modes[math.random(1, #rate_modes)]
    
    local group = {
      name = "Group " .. string.char(64 + gi), -- A, B, C...
      crossfade_mode = ({"linear", "xy", "stack"})[math.random(1, 3)],
      -- Group crossfade settings (wavetable scanning) - always enabled for full architecture
      group_crossfade_enabled = true,
      group_crossfade_curve = ({"linear", "equal_power", "s_curve"})[math.random(1, 3)],
      -- Group LFO rate settings
      group_lfo_rate_mode = group_rate_mode,
      group_lfo_rate_free = 0.1 + math.random() * 1.9,  -- 0.1-2.0 Hz
      group_lfo_rate_sync = rate_syncs[math.random(1, #rate_syncs)],
      group_lfo_rate_preset = rate_presets[math.random(1, #rate_presets)],
      -- Group Master FX settings - always enabled for full architecture
      group_master_fx_enabled = true,
      group_master_fx_mode = math.random() > 0.5 and "random" or "selective",
      group_master_fx_count = math.random(1, 4),
      group_master_fx_types = {},
      oscillators = {}
    }
    
    -- If selective mode, randomly pick some FX types
    if group.group_master_fx_mode == "selective" then
      local fx_names = PakettiMetaSynthGetSelectableFXTypeNames()
      local num_types = math.random(1, math.min(3, #fx_names))
      local shuffled_types = {}
      for _, name in ipairs(fx_names) do table.insert(shuffled_types, name) end
      for i = #shuffled_types, 2, -1 do
        local j = math.random(1, i)
        shuffled_types[i], shuffled_types[j] = shuffled_types[j], shuffled_types[i]
      end
      for i = 1, num_types do
        table.insert(group.group_master_fx_types, shuffled_types[i])
      end
    end
    
    -- Skip creating this group if no samples remaining
    if samples_remaining <= 0 then
      break
    end
    
    -- Random number of oscillators per group (1-3), minimum 1
    local max_oscs = math.min(3, samples_remaining)
    if max_oscs < 1 then max_oscs = 1 end
    local num_oscs = math.random(1, max_oscs)
    
    for oi = 1, num_oscs do
      if samples_remaining <= 0 then break end
      
      local osc = {
        name = "Osc " .. oi,
        sample_count = 1,
        unison_voices = 1,
        frame_count = 1,
        sample_source = "akwf",
        detune_spread = 10,
        pan_spread = 0.8
      }
      
      PakettiMetaSynthRandomizeOscillator(osc, samples_remaining)
      samples_remaining = samples_remaining - (osc.sample_count * osc.unison_voices)
      
      table.insert(group.oscillators, osc)
    end
    
    -- Only add group if it has at least one oscillator
    if #group.oscillators > 0 then
      table.insert(architecture.oscillator_groups, group)
    end
  end
  
  -- Random crossfade settings
  architecture.crossfade.curve_type = ({"linear", "equal_power", "s_curve"})[math.random(1, 3)]
  -- Always use LFO for now - macro mode routing is not fully implemented
  architecture.crossfade.control_source = "lfo"
  architecture.crossfade.macro_index = math.random(1, 4)
  
  -- Randomize Frame LFO rate settings
  local frame_rate_mode = rate_modes[math.random(1, #rate_modes)]
  architecture.crossfade.lfo_rate_mode = frame_rate_mode
  architecture.crossfade.lfo_rate_free = 0.1 + math.random() * 1.9  -- 0.1-2.0 Hz
  architecture.crossfade.lfo_rate_sync = rate_syncs[math.random(1, #rate_syncs)]
  architecture.crossfade.lfo_rate_preset = rate_presets[math.random(1, #rate_presets)]
  
  -- Random FX settings
  architecture.fx_randomization.enabled = math.random() > 0.3
  architecture.fx_randomization.param_randomization = 0.2 + math.random() * 0.4
  
  -- Randomly select 2-4 devices from the pool
  local pool = {}
  local shuffled = {}
  for _, d in ipairs(PakettiMetaSynthSafeFXDevices) do table.insert(shuffled, d) end
  for i = #shuffled, 2, -1 do
    local j = math.random(1, i)
    shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
  end
  for i = 1, math.random(2, 4) do
    table.insert(pool, shuffled[i])
  end
  architecture.fx_randomization.device_pool = pool
  
  -- Stacked Master FX settings - always enabled for full architecture
  architecture.stacked_master_fx_enabled = true
  architecture.stacked_master_fx_mode = math.random() > 0.5 and "random" or "selective"
  architecture.stacked_master_fx_count = math.random(1, 4)
  architecture.stacked_master_fx_types = {}
  
  -- If selective mode, randomly pick some FX types for stacked master
  if architecture.stacked_master_fx_mode == "selective" then
    local fx_names = PakettiMetaSynthGetSelectableFXTypeNames()
    local num_types = math.random(1, math.min(3, #fx_names))
    local shuffled_types = {}
    for _, name in ipairs(fx_names) do table.insert(shuffled_types, name) end
    for i = #shuffled_types, 2, -1 do
      local j = math.random(1, i)
      shuffled_types[i], shuffled_types[j] = shuffled_types[j], shuffled_types[i]
    end
    for i = 1, num_types do
      table.insert(architecture.stacked_master_fx_types, shuffled_types[i])
    end
  end
  
  -- Default to output_routing (safer, no sends) - can be overridden by caller
  architecture.master_routing_mode = "output_routing"
  
  return architecture
end

-- Quick random instrument generation with specified routing mode
-- routing_mode: "output_routing" (chain routing, no sends) or "send_device" (#Send devices)
function PakettiMetaSynthGenerateRandomInstrumentWithRouting(routing_mode)
  -- Safety check: ensure song is loaded
  if not renoise.song() then
    renoise.app():show_status("PakettiMetaSynth: No song loaded")
    return nil
  end
  
  local architecture = PakettiMetaSynthCreateDefaultArchitecture()
  PakettiMetaSynthRandomizeArchitecture(architecture)
  -- Override the routing mode with specified value
  architecture.master_routing_mode = routing_mode or "output_routing"
  architecture.name = "MetaSynth Random " .. os.date("%H%M%S")
  return PakettiMetaSynthGenerateInstrument(architecture)
end

-- Quick random instrument generation (uses output_routing - no sends, more reliable)
function PakettiMetaSynthGenerateRandomInstrument()
  return PakettiMetaSynthGenerateRandomInstrumentWithRouting("output_routing")
end

-- Quick random instrument generation with #Send devices
function PakettiMetaSynthGenerateRandomInstrumentWithSends()
  return PakettiMetaSynthGenerateRandomInstrumentWithRouting("send_device")
end

-- Batch generate multiple randomized instruments for quick auditioning
function PakettiMetaSynthGenerateBatchInstruments(use_sends, count)
  count = count or 20
  local song = renoise.song()
  
  if not song then
    renoise.app():show_status("PakettiMetaSynth: No song loaded")
    return
  end
  
  for i = 1, count do
    -- Insert new instrument after current
    local insert_index = song.selected_instrument_index + 1
    song:insert_instrument_at(insert_index)
    song.selected_instrument_index = insert_index
    
    -- Generate randomized instrument
    if use_sends then
      PakettiMetaSynthGenerateRandomInstrumentWithSends()
    else
      PakettiMetaSynthGenerateRandomInstrument()
    end
    
    renoise.app():show_status(string.format("PakettiMetaSynth: Generated instrument %d of %d", i, count))
  end
  
  renoise.app():show_status(string.format("PakettiMetaSynth: Batch complete - %d instruments created", count))
end

-- Randomize architecture for wavetable mode
-- Key difference: frames are parallel FX paths for the SAME source, not different samples
function PakettiMetaSynthRandomizeWavetableArchitecture(architecture)
  trueRandomSeed()
  
  -- LFO rate mode options
  local rate_modes = {"free", "tempo_sync", "preset"}
  local rate_presets = {"slow", "medium", "fast"}
  local rate_syncs = {"1/16", "1/8", "1/4", "1/2", "1 bar", "2 bars", "4 bars"}
  
  -- Wavetable mode: typically 1 group with multiple oscillators for scanning
  local num_groups = 1  -- Keep it simple for wavetable
  architecture.oscillator_groups = {}
  
  local samples_remaining = 12
  
  for gi = 1, num_groups do
    -- Randomize Group LFO rate settings
    local group_rate_mode = rate_modes[math.random(1, #rate_modes)]
    
    local group = {
      name = "Group " .. string.char(64 + gi),
      crossfade_mode = "linear",
      -- Group crossfade = wavetable scanning between oscillators
      group_crossfade_enabled = true,
      group_crossfade_curve = ({"linear", "equal_power", "s_curve"})[math.random(1, 3)],
      -- Group LFO rate settings (wavetable scanning speed)
      group_lfo_rate_mode = group_rate_mode,
      group_lfo_rate_free = 0.1 + math.random() * 0.9,  -- 0.1-1.0 Hz (slower for wavetable)
      group_lfo_rate_sync = rate_syncs[math.random(4, #rate_syncs)],  -- Prefer slower syncs (1/2 to 4 bars)
      group_lfo_rate_preset = rate_presets[math.random(1, 2)],  -- Prefer slow/medium for wavetable
      -- Group Master FX for glue
      group_master_fx_enabled = true,
      group_master_fx_mode = "random",
      group_master_fx_count = math.random(1, 3),
      group_master_fx_types = {},
      oscillators = {}
    }
    
    if samples_remaining <= 0 then break end
    
    -- Wavetable mode: 2-4 oscillators for scanning between different waveforms
    local num_oscs = math.random(2, math.min(4, samples_remaining))
    
    for oi = 1, num_oscs do
      if samples_remaining <= 0 then break end
      
      local osc = {
        name = "Osc " .. oi,
        sample_count = 1,  -- Wavetable: 1 sample per oscillator
        unison_voices = math.random(1, 3),  -- Unison for thickness
        frame_count = math.random(2, 4),  -- 2-4 parallel FX frames
        sample_source = "akwf",
        detune_spread = 5 + math.random() * 15,  -- 5-20 cents
        pan_spread = 0.3 + math.random() * 0.5,  -- 0.3-0.8
        -- Osc FX enabled for summing
        osc_fx_enabled = math.random() > 0.3,  -- 70% chance
        osc_fx_mode = "random",
        osc_fx_count = math.random(1, 3)
      }
      
      -- Check if custom folder is configured
      if PakettiMetaSynthLastFolderPath and PakettiMetaSynthLastFolderPath ~= "" then
        if math.random() > 0.75 then
          osc.sample_source = "folder"
          osc.sample_folder = PakettiMetaSynthLastFolderPath
        end
      end
      
      samples_remaining = samples_remaining - (osc.sample_count * osc.unison_voices)
      table.insert(group.oscillators, osc)
    end
    
    if #group.oscillators > 0 then
      table.insert(architecture.oscillator_groups, group)
    end
  end
  
  -- Crossfade settings for frame morphing
  architecture.crossfade.curve_type = ({"linear", "equal_power", "s_curve"})[math.random(1, 3)]
  architecture.crossfade.control_source = "lfo"  -- LFO for frame morphing
  architecture.crossfade.macro_index = 1
  
  -- Randomize Frame LFO rate settings (frame morphing speed)
  local frame_rate_mode = rate_modes[math.random(1, #rate_modes)]
  architecture.crossfade.lfo_rate_mode = frame_rate_mode
  architecture.crossfade.lfo_rate_free = 0.2 + math.random() * 1.3  -- 0.2-1.5 Hz
  architecture.crossfade.lfo_rate_sync = rate_syncs[math.random(3, #rate_syncs)]  -- 1/4 to 4 bars
  architecture.crossfade.lfo_rate_preset = rate_presets[math.random(1, #rate_presets)]
  
  -- FX randomization enabled for frame variation
  architecture.fx_randomization.enabled = true
  architecture.fx_randomization.param_randomization = 0.2 + math.random() * 0.3  -- 0.2-0.5
  
  -- Stacked Master FX (global polish)
  architecture.stacked_master_fx_enabled = true
  architecture.stacked_master_fx_mode = "random"
  architecture.stacked_master_fx_count = math.random(2, 4)
  
  -- Modulation
  architecture.modulation.random_phase_offsets = math.random() > 0.5
  
  return architecture
end

-- Quick wavetable instrument generation
function PakettiMetaSynthGenerateRandomWavetableInstrument()
  local architecture = PakettiMetaSynthCreateDefaultArchitecture()
  PakettiMetaSynthRandomizeWavetableArchitecture(architecture)
  architecture.name = "MetaSynth Wavetable " .. os.date("%H%M%S")
  return PakettiMetaSynthGenerateWavetableInstrument(architecture)
end

-- ============================================================================
-- SECTION 9: ARCHITECTURE PRESET SAVE/LOAD
-- ============================================================================

-- Serialize architecture to string
function PakettiMetaSynthSerializeArchitecture(architecture)
  local function serialize_value(val, indent)
    indent = indent or 0
    local spaces = string.rep("  ", indent)
    
    if type(val) == "string" then
      return '"' .. val:gsub('"', '\\"') .. '"'
    elseif type(val) == "number" then
      return tostring(val)
    elseif type(val) == "boolean" then
      return tostring(val)
    elseif type(val) == "nil" then
      return "nil"
    elseif type(val) == "table" then
      local result = "{\n"
      local is_array = #val > 0
      
      if is_array then
        for i, v in ipairs(val) do
          result = result .. spaces .. "  " .. serialize_value(v, indent + 1) .. ",\n"
        end
      else
        for k, v in pairs(val) do
          local key_str
          if type(k) == "string" then
            key_str = k
          else
            key_str = "[" .. tostring(k) .. "]"
          end
          result = result .. spaces .. "  " .. key_str .. " = " .. serialize_value(v, indent + 1) .. ",\n"
        end
      end
      
      result = result .. spaces .. "}"
      return result
    else
      return '"<unsupported type>"'
    end
  end
  
  return "return " .. serialize_value(architecture)
end

-- Save architecture to file
function PakettiMetaSynthSaveArchitecture(architecture, filepath)
  local content = PakettiMetaSynthSerializeArchitecture(architecture)
  local file = io.open(filepath, "w")
  if file then
    file:write(content)
    file:close()
    renoise.app():show_status("PakettiMetaSynth: Architecture saved to " .. filepath)
    return true
  else
    renoise.app():show_status("PakettiMetaSynth: Failed to save architecture")
    return false
  end
end

-- Load architecture from file
function PakettiMetaSynthLoadArchitecture(filepath)
  local file = io.open(filepath, "r")
  if not file then
    renoise.app():show_status("PakettiMetaSynth: Could not open file " .. filepath)
    return nil
  end
  
  local content = file:read("*all")
  file:close()
  
  local loader, err = loadstring(content)
  if not loader then
    renoise.app():show_status("PakettiMetaSynth: Failed to parse architecture file")
    print("PakettiMetaSynth parse error: " .. tostring(err))
    return nil
  end
  
  local success, result = pcall(loader)
  if success and type(result) == "table" then
    renoise.app():show_status("PakettiMetaSynth: Architecture loaded from " .. filepath)
    return result
  else
    renoise.app():show_status("PakettiMetaSynth: Invalid architecture file")
    return nil
  end
end

-- ============================================================================
-- SECTION 10: GUI - VISUAL ARCHITECTURE DESIGNER
-- ============================================================================

-- GUI state
PakettiMetaSynthDialog = nil
PakettiMetaSynthDialogContent = nil
PakettiMetaSynthVB = nil

-- Initialize ViewBuilder
function PakettiMetaSynthInitVB()
  if not PakettiMetaSynthVB then
    PakettiMetaSynthVB = renoise.ViewBuilder()
  end
  return PakettiMetaSynthVB
end

-- Custom key handler for dialog
function PakettiMetaSynthKeyHandler(dialog, key)
  -- Let my_keyhandler_func handle it first if available
  if my_keyhandler_func then
    local handled = my_keyhandler_func(dialog, key)
    if handled then return end
  end
  
  -- Handle our own shortcuts
  if key.modifiers == "" then
    if key.name == "return" then
      -- Enter = Generate
      PakettiMetaSynthGenerateInstrument(PakettiMetaSynthCurrentArchitecture)
      return
    elseif key.name == "r" then
      -- R = Randomize
      PakettiMetaSynthRandomizeArchitecture(PakettiMetaSynthCurrentArchitecture)
      PakettiMetaSynthRebuildDialog()
      return
    elseif key.name == "esc" then
      -- Escape = Close
      if PakettiMetaSynthDialog and PakettiMetaSynthDialog.visible then
        PakettiMetaSynthDialog:close()
      end
      return
    end
  end
end

-- Build oscillator row for GUI (with folder browse button and Oscillator FX controls)
function PakettiMetaSynthBuildOscillatorRow(vb, group_index, osc_index, osc)
  local row_id = string.format("osc_%d_%d", group_index, osc_index)
  
  -- Get oscillator FX values with defaults
  local osc_fx_enabled = osc.osc_fx_enabled or false
  local osc_fx_mode = osc.osc_fx_mode or "random"
  local osc_fx_count = osc.osc_fx_count or 2
  local osc_fx_mode_index = osc_fx_mode == "selective" and 2 or 1
  
  return vb:column {
    id = row_id,
    spacing = 2,
    
    -- Main oscillator controls row
    vb:row {
      spacing = 4,
      
      vb:text {
        text = osc.name,
        width = 50
      },
      
      vb:text { text = "S:" },
      vb:valuebox {
        id = row_id .. "_samples",
        min = 1,
        max = 12,
        value = osc.sample_count,
        width = 40,
        notifier = function(value)
          osc.sample_count = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      
      vb:text { text = "U:" },
      vb:valuebox {
        id = row_id .. "_unison",
        min = 1,
        max = 8,
        value = osc.unison_voices,
        width = 40,
        notifier = function(value)
          osc.unison_voices = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      
      vb:text { text = "F:" },
      vb:valuebox {
        id = row_id .. "_frames",
        min = 1,
        max = 16,
        value = osc.frame_count,
        width = 40,
        notifier = function(value)
          osc.frame_count = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      
      vb:popup {
        id = row_id .. "_source",
        items = {"AKWF", "Folder"},
        value = osc.sample_source == "akwf" and 1 or 2,
        width = 60,
        notifier = function(value)
          osc.sample_source = value == 1 and "akwf" or "folder"
        end
      },
      
      vb:button {
        id = row_id .. "_browse",
        text = "...",
        width = 24,
        notifier = function()
          local folder = renoise.app():prompt_for_path("Select Sample Folder")
          if folder then
            osc.sample_folder = folder
            osc.sample_source = "folder"
            PakettiMetaSynthLastFolderPath = folder
            -- Update the source popup
            local source_popup = vb.views[row_id .. "_source"]
            if source_popup then
              source_popup.value = 2
            end
            renoise.app():show_status("PakettiMetaSynth: Folder set to " .. folder)
          end
        end
      },
      
      vb:button {
        text = "X",
        width = 20,
        notifier = function()
          PakettiMetaSynthRemoveOscillator(group_index, osc_index)
        end
      }
    },
    
    -- Oscillator FX controls row
    vb:row {
      spacing = 4,
      
      vb:space { width = 50 },  -- Align with oscillator name
      
      vb:checkbox {
        id = row_id .. "_fx_enabled",
        value = osc_fx_enabled,
        notifier = function(value)
          osc.osc_fx_enabled = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      vb:text { text = "Osc FX", width = 40 },
      vb:popup {
        id = row_id .. "_fx_mode",
        items = {"Random", "Selective"},
        value = osc_fx_mode_index,
        width = 70,
        notifier = function(value)
          osc.osc_fx_mode = value == 1 and "random" or "selective"
        end
      },
      vb:text { text = "Count:" },
      vb:valuebox {
        id = row_id .. "_fx_count",
        min = 1,
        max = 5,
        value = osc_fx_count,
        width = 40,
        notifier = function(value)
          osc.osc_fx_count = value
          PakettiMetaSynthUpdatePreview()
        end
      }
    }
  }
end

-- Build group section for GUI
function PakettiMetaSynthBuildGroupSection(vb, group_index, group)
  local group_id = string.format("group_%d", group_index)
  local osc_rows = vb:column { spacing = 2 }
  
  for oi, osc in ipairs(group.oscillators) do
    osc_rows:add_child(PakettiMetaSynthBuildOscillatorRow(vb, group_index, oi, osc))
  end
  
  -- Determine initial values for group crossfade controls (with defaults for legacy data)
  local group_xfade_enabled = group.group_crossfade_enabled or false
  local group_xfade_curve = group.group_crossfade_curve or "equal_power"
  local group_xfade_time = group.group_crossfade_time or 4.0
  
  -- Map curve type to popup index
  local curve_index = 2  -- Default to equal_power
  if group_xfade_curve == "linear" then
    curve_index = 1
  elseif group_xfade_curve == "equal_power" then
    curve_index = 2
  elseif group_xfade_curve == "s_curve" then
    curve_index = 3
  end
  
  -- Determine initial values for Group Master FX controls (with defaults)
  local group_master_fx_enabled = group.group_master_fx_enabled or false
  local group_master_fx_mode = group.group_master_fx_mode or "random"
  local group_master_fx_count = group.group_master_fx_count or 3
  local group_master_fx_types = group.group_master_fx_types or {}
  
  -- Map mode to popup index (Random=1, Selective=2)
  local master_fx_mode_index = group_master_fx_mode == "selective" and 2 or 1
  
  return vb:column {
    id = group_id,
    style = "group",
    margin = 4,
    spacing = 4,
    
    vb:row {
      vb:text {
        text = group.name,
        font = "bold",
        width = 80
      },
      vb:popup {
        id = group_id .. "_mode",
        items = {"Linear", "XY", "Stack"},
        value = group.crossfade_mode == "linear" and 1 or (group.crossfade_mode == "xy" and 2 or 3),
        width = 70,
        notifier = function(value)
          group.crossfade_mode = ({"linear", "xy", "stack"})[value]
        end
      },
      vb:button {
        text = "+Osc",
        width = 40,
        notifier = function()
          PakettiMetaSynthAddOscillator(group_index)
        end
      },
      vb:button {
        text = "X",
        width = 20,
        notifier = function()
          PakettiMetaSynthRemoveGroup(group_index)
        end
      }
    },
    
    -- Group Crossfade Controls (Wavetable Scanning)
    vb:row {
      spacing = 4,
      vb:checkbox {
        id = group_id .. "_xfade_enabled",
        value = group_xfade_enabled,
        notifier = function(value)
          group.group_crossfade_enabled = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      vb:text { text = "Group Morph", width = 65 },
      vb:popup {
        id = group_id .. "_xfade_curve",
        items = {"Linear", "Equal Power", "S-Curve"},
        value = curve_index,
        width = 85,
        notifier = function(value)
          group.group_crossfade_curve = ({"linear", "equal_power", "s_curve"})[value]
        end
      },
      vb:text { text = "LFO:" },
      vb:popup {
        id = group_id .. "_lfo_rate_mode",
        items = {"Free", "Sync", "Preset"},
        value = group.group_lfo_rate_mode == "free" and 1 or 
               (group.group_lfo_rate_mode == "tempo_sync" and 2 or 3),
        width = 55,
        notifier = function(value)
          group.group_lfo_rate_mode = ({"free", "tempo_sync", "preset"})[value]
        end
      }
    },
    
    -- Group LFO Rate Details Row
    vb:row {
      spacing = 4,
      vb:text { text = "Hz:", width = 25 },
      vb:valuefield {
        id = group_id .. "_lfo_rate_free",
        min = 0.01,
        max = 10,
        value = group.group_lfo_rate_free or 0.5,
        width = 45,
        notifier = function(value)
          group.group_lfo_rate_free = value
        end
      },
      vb:text { text = "Sync:" },
      vb:popup {
        id = group_id .. "_lfo_rate_sync",
        items = {"1/16", "1/8", "1/4", "1/2", "1bar", "2bar", "4bar"},
        value = ({["1/16"]=1, ["1/8"]=2, ["1/4"]=3, ["1/2"]=4, ["1 bar"]=5, ["2 bars"]=6, ["4 bars"]=7})[group.group_lfo_rate_sync or "1 bar"] or 5,
        width = 50,
        notifier = function(value)
          group.group_lfo_rate_sync = ({"1/16", "1/8", "1/4", "1/2", "1 bar", "2 bars", "4 bars"})[value]
        end
      },
      vb:text { text = "Pre:" },
      vb:popup {
        id = group_id .. "_lfo_rate_preset",
        items = {"Slow", "Med", "Fast"},
        value = group.group_lfo_rate_preset == "slow" and 1 or 
               (group.group_lfo_rate_preset == "medium" and 2 or 3),
        width = 50,
        notifier = function(value)
          group.group_lfo_rate_preset = ({"slow", "medium", "fast"})[value]
        end
      }
    },
    
    -- Group Master FX Controls
    vb:row {
      spacing = 4,
      vb:checkbox {
        id = group_id .. "_master_fx_enabled",
        value = group_master_fx_enabled,
        notifier = function(value)
          group.group_master_fx_enabled = value
          PakettiMetaSynthUpdatePreview()
        end
      },
      vb:text { text = "Grp Master FX", width = 75 },
      vb:popup {
        id = group_id .. "_master_fx_mode",
        items = {"Random", "Selective"},
        value = master_fx_mode_index,
        width = 70,
        notifier = function(value)
          group.group_master_fx_mode = value == 1 and "random" or "selective"
        end
      },
      vb:text { text = "Count:" },
      vb:valuebox {
        id = group_id .. "_master_fx_count",
        min = 1,
        max = 5,
        value = group_master_fx_count,
        width = 40,
        notifier = function(value)
          group.group_master_fx_count = value
        end
      }
    },
    
    osc_rows
  }
end

-- Update preview display
function PakettiMetaSynthUpdatePreview()
  if not PakettiMetaSynthCurrentArchitecture or not PakettiMetaSynthVB then return end
  
  local validation = PakettiMetaSynthValidateArchitecture(PakettiMetaSynthCurrentArchitecture)
  
  local vb = PakettiMetaSynthVB
  
  -- Update sample count display
  local sample_text = vb.views["preview_samples"]
  if sample_text then
    sample_text.text = string.format("Samples: %d/12", validation.total_samples)
    sample_text.style = validation.total_samples > 12 and "disabled" or "normal"
  end
  
  -- Update FX chains display
  local fx_text = vb.views["preview_fx_chains"]
  if fx_text then
    fx_text.text = string.format("FX Chains: %d", validation.total_fx_chains)
  end
  
  -- Update group morph display
  local group_morph_text = vb.views["preview_group_morph"]
  if group_morph_text then
    local morph_count = 0
    local morph_info = {}
    for gi, group in ipairs(PakettiMetaSynthCurrentArchitecture.oscillator_groups) do
      if group.group_crossfade_enabled and #group.oscillators > 1 then
        morph_count = morph_count + 1
        table.insert(morph_info, string.format("%s:%d", group.name, #group.oscillators))
      end
    end
    if morph_count > 0 then
      group_morph_text.text = string.format("Group Morph: %s", table.concat(morph_info, ", "))
    else
      group_morph_text.text = "Group Morph: Off"
    end
  end
  
  -- Update oscillator FX display
  local osc_fx_text = vb.views["preview_osc_fx"]
  if osc_fx_text then
    local osc_fx_count = 0
    local osc_fx_info = {}
    for gi, group in ipairs(PakettiMetaSynthCurrentArchitecture.oscillator_groups) do
      for oi, osc in ipairs(group.oscillators) do
        if osc.osc_fx_enabled then
          osc_fx_count = osc_fx_count + 1
          table.insert(osc_fx_info, osc.name)
        end
      end
    end
    if osc_fx_count > 0 then
      osc_fx_text.text = string.format("Osc FX: %d (%s)", osc_fx_count, table.concat(osc_fx_info, ", "))
    else
      osc_fx_text.text = "Osc FX: Off"
    end
  end
  
  -- Update master FX display
  local master_fx_text = vb.views["preview_master_fx"]
  if master_fx_text then
    local master_info = {}
    -- Count groups with Group Master FX enabled
    local group_master_count = 0
    for gi, group in ipairs(PakettiMetaSynthCurrentArchitecture.oscillator_groups) do
      if group.group_master_fx_enabled then
        group_master_count = group_master_count + 1
      end
    end
    if group_master_count > 0 then
      table.insert(master_info, string.format("Grp:%d", group_master_count))
    end
    -- Check Stacked Master FX
    if PakettiMetaSynthCurrentArchitecture.stacked_master_fx_enabled then
      table.insert(master_info, "Stack")
    end
    
    if #master_info > 0 then
      master_fx_text.text = string.format("Master FX: %s", table.concat(master_info, "+"))
    else
      master_fx_text.text = "Master FX: Off"
    end
  end
  
  -- Update warning display
  local warning_text = vb.views["preview_warning"]
  if warning_text then
    if #validation.errors > 0 then
      warning_text.text = validation.errors[1]
      warning_text.style = "disabled"
    elseif #validation.warnings > 0 then
      warning_text.text = validation.warnings[1]
      warning_text.style = "normal"
    else
      warning_text.text = "Ready to generate"
      warning_text.style = "normal"
    end
  end
end

-- Add oscillator to a group
function PakettiMetaSynthAddOscillator(group_index)
  if not PakettiMetaSynthCurrentArchitecture then return end
  
  local group = PakettiMetaSynthCurrentArchitecture.oscillator_groups[group_index]
  if not group then return end
  
  local new_osc = {
    name = "Osc " .. (#group.oscillators + 1),
    sample_count = 1,
    unison_voices = 1,
    frame_count = 1,
    sample_source = "akwf",
    sample_folder = PakettiMetaSynthLastFolderPath,
    detune_spread = 10,
    pan_spread = 0.8,
    -- Oscillator FX settings (processing after frame morphing, before group morphing)
    osc_fx_enabled = false,
    osc_fx_mode = "random",
    osc_fx_count = 2,
    osc_fx_types = {}
  }
  
  table.insert(group.oscillators, new_osc)
  PakettiMetaSynthRebuildDialog()
end

-- Remove oscillator from a group
function PakettiMetaSynthRemoveOscillator(group_index, osc_index)
  if not PakettiMetaSynthCurrentArchitecture then return end
  
  local group = PakettiMetaSynthCurrentArchitecture.oscillator_groups[group_index]
  if not group or #group.oscillators <= 1 then return end
  
  table.remove(group.oscillators, osc_index)
  PakettiMetaSynthRebuildDialog()
end

-- Add a new group
function PakettiMetaSynthAddGroup()
  if not PakettiMetaSynthCurrentArchitecture then return end
  
  local new_group = {
    name = "Group " .. string.char(64 + #PakettiMetaSynthCurrentArchitecture.oscillator_groups + 1),
    crossfade_mode = "linear",
    -- Group-level crossfade settings (wavetable scanning between oscillators)
    group_crossfade_enabled = false,
    group_crossfade_curve = "equal_power",
    group_crossfade_time = 4.0,
    -- Group Master FX settings (glue FX per wavetable group)
    group_master_fx_enabled = false,
    group_master_fx_mode = "random",
    group_master_fx_count = 3,
    group_master_fx_types = {},
    oscillators = {
      {
        name = "Osc 1",
        sample_count = 1,
        unison_voices = 1,
        frame_count = 1,
        sample_source = "akwf",
        sample_folder = PakettiMetaSynthLastFolderPath,
        detune_spread = 10,
        pan_spread = 0.8
      }
    }
  }
  
  table.insert(PakettiMetaSynthCurrentArchitecture.oscillator_groups, new_group)
  PakettiMetaSynthRebuildDialog()
end

-- Remove a group
function PakettiMetaSynthRemoveGroup(group_index)
  if not PakettiMetaSynthCurrentArchitecture then return end
  if #PakettiMetaSynthCurrentArchitecture.oscillator_groups <= 1 then return end
  
  table.remove(PakettiMetaSynthCurrentArchitecture.oscillator_groups, group_index)
  PakettiMetaSynthRebuildDialog()
end

-- Build the main dialog content
function PakettiMetaSynthBuildDialogContent()
  local vb = PakettiMetaSynthInitVB()
  local arch = PakettiMetaSynthCurrentArchitecture
  
  -- Build oscillator groups section
  local groups_column = vb:column {
    id = "groups_container",
    spacing = 4
  }
  
  for gi, group in ipairs(arch.oscillator_groups) do
    groups_column:add_child(PakettiMetaSynthBuildGroupSection(vb, gi, group))
  end
  
  -- Main content
  local content = vb:column {
    margin = 8,
    spacing = 8,
    
    -- Instrument name
    vb:row {
      vb:text { text = "Instrument Name:", width = 100 },
      vb:textfield {
        id = "inst_name",
        text = arch.name,
        width = 200,
        notifier = function(value)
          arch.name = value
        end
      }
    },
    
    -- Two-column layout
    vb:row {
      spacing = 16,
      
      -- Left column: Oscillator Groups
      vb:column {
        style = "panel",
        margin = 4,
        width = 460,
        
        vb:row {
          vb:text { text = "Oscillator Groups", font = "bold" },
          vb:button {
            text = "+ Add Group",
            width = 80,
            notifier = function()
              PakettiMetaSynthAddGroup()
            end
          }
        },
        
        groups_column
      },
      
      -- Right column: Preview and Settings
      vb:column {
        spacing = 8,
        width = 180,
        
        -- Preview section
        vb:column {
          style = "group",
          margin = 4,
          
          vb:text { text = "Preview", font = "bold" },
          vb:text { id = "preview_samples", text = "Samples: 0/12" },
          vb:text { id = "preview_fx_chains", text = "FX Chains: 0" },
          vb:text { id = "preview_group_morph", text = "Group Morph: Off" },
          vb:text { id = "preview_osc_fx", text = "Osc FX: Off" },
          vb:text { id = "preview_master_fx", text = "Master FX: Off" },
          vb:text { id = "preview_warning", text = "" }
        },
        
        -- Crossfade Settings
        vb:column {
          style = "group",
          margin = 4,
          
          vb:text { text = "Crossfade", font = "bold" },
          
          vb:row {
            vb:text { text = "Curve:", width = 45 },
            vb:popup {
              id = "crossfade_curve",
              items = {"Linear", "Equal Power", "S-Curve"},
              value = arch.crossfade.curve_type == "linear" and 1 or 
                     (arch.crossfade.curve_type == "equal_power" and 2 or 3),
              width = 90,
              notifier = function(value)
                arch.crossfade.curve_type = ({"linear", "equal_power", "s_curve"})[value]
              end
            }
          },
          
          vb:row {
            vb:text { text = "Ctrl:", width = 45 },
            vb:popup {
              id = "crossfade_control",
              items = {"Macro", "LFO"},
              value = arch.crossfade.control_source == "macro" and 1 or 2,
              width = 90,
              notifier = function(value)
                arch.crossfade.control_source = value == 1 and "macro" or "lfo"
              end
            }
          },
          
          vb:row {
            vb:text { text = "Macro:", width = 45 },
            vb:valuebox {
              id = "crossfade_macro",
              min = 1,
              max = 8,
              value = arch.crossfade.macro_index,
              width = 50,
              notifier = function(value)
                arch.crossfade.macro_index = value
              end
            }
          },
          
          -- Frame LFO Rate Mode
          vb:row {
            vb:text { text = "LFO Mode:", width = 55 },
            vb:popup {
              id = "frame_lfo_rate_mode",
              items = {"Free", "Tempo Sync", "Preset"},
              value = arch.crossfade.lfo_rate_mode == "free" and 1 or 
                     (arch.crossfade.lfo_rate_mode == "tempo_sync" and 2 or 3),
              width = 80,
              notifier = function(value)
                arch.crossfade.lfo_rate_mode = ({"free", "tempo_sync", "preset"})[value]
              end
            }
          },
          
          vb:row {
            vb:text { text = "Free Hz:", width = 55 },
            vb:valuefield {
              id = "frame_lfo_rate_free",
              min = 0.01,
              max = 10,
              value = arch.crossfade.lfo_rate_free or 0.5,
              width = 60,
              notifier = function(value)
                arch.crossfade.lfo_rate_free = value
              end
            }
          },
          
          vb:row {
            vb:text { text = "Sync:", width = 55 },
            vb:popup {
              id = "frame_lfo_rate_sync",
              items = {"1/16", "1/8", "1/4", "1/2", "1 bar", "2 bars", "4 bars"},
              value = ({["1/16"]=1, ["1/8"]=2, ["1/4"]=3, ["1/2"]=4, ["1 bar"]=5, ["2 bars"]=6, ["4 bars"]=7})[arch.crossfade.lfo_rate_sync or "1 bar"] or 5,
              width = 80,
              notifier = function(value)
                arch.crossfade.lfo_rate_sync = ({"1/16", "1/8", "1/4", "1/2", "1 bar", "2 bars", "4 bars"})[value]
              end
            }
          },
          
          vb:row {
            vb:text { text = "Preset:", width = 55 },
            vb:popup {
              id = "frame_lfo_rate_preset",
              items = {"Slow", "Medium", "Fast"},
              value = arch.crossfade.lfo_rate_preset == "slow" and 1 or 
                     (arch.crossfade.lfo_rate_preset == "medium" and 2 or 3),
              width = 80,
              notifier = function(value)
                arch.crossfade.lfo_rate_preset = ({"slow", "medium", "fast"})[value]
              end
            }
          }
        },
        
        -- FX Randomization
        vb:column {
          style = "group",
          margin = 4,
          
          vb:text { text = "FX Randomization", font = "bold" },
          
          vb:row {
            vb:checkbox {
              id = "fx_enabled",
              value = arch.fx_randomization.enabled,
              notifier = function(value)
                arch.fx_randomization.enabled = value
              end
            },
            vb:text { text = "Enable" }
          },
          
          vb:row {
            vb:text { text = "Amt:", width = 30 },
            vb:slider {
              id = "fx_amount",
              min = 0,
              max = 1,
              value = arch.fx_randomization.param_randomization,
              width = 100,
              notifier = function(value)
                arch.fx_randomization.param_randomization = value
              end
            }
          }
        },
        
        -- Stacked Master FX (global settings)
        vb:column {
          style = "group",
          margin = 4,
          
          vb:text { text = "Stacked Master FX", font = "bold" },
          
          vb:row {
            vb:checkbox {
              id = "stacked_master_enabled",
              value = arch.stacked_master_fx_enabled or false,
              notifier = function(value)
                arch.stacked_master_fx_enabled = value
                PakettiMetaSynthUpdatePreview()
              end
            },
            vb:text { text = "Enable" }
          },
          
          vb:row {
            vb:text { text = "Mode:", width = 35 },
            vb:popup {
              id = "stacked_master_mode",
              items = {"Random", "Selective"},
              value = (arch.stacked_master_fx_mode or "random") == "selective" and 2 or 1,
              width = 80,
              notifier = function(value)
                arch.stacked_master_fx_mode = value == 1 and "random" or "selective"
              end
            }
          },
          
          vb:row {
            vb:text { text = "Count:", width = 35 },
            vb:valuebox {
              id = "stacked_master_count",
              min = 1,
              max = 5,
              value = arch.stacked_master_fx_count or 3,
              width = 50,
              notifier = function(value)
                arch.stacked_master_fx_count = value
              end
            }
          },
          
          vb:row {
            vb:text { text = "Route:", width = 35 },
            vb:popup {
              id = "master_routing_mode",
              items = {"Chain Output", "#Send Device"},
              value = (arch.master_routing_mode or "output_routing") == "send_device" and 2 or 1,
              width = 90,
              tooltip = "Chain Output: uses output_routing property\n#Send Device: adds #Send device to each chain",
              notifier = function(value)
                arch.master_routing_mode = value == 1 and "output_routing" or "send_device"
              end
            }
          }
        },
        
        -- Shortcuts hint
        vb:column {
          style = "group",
          margin = 4,
          
          vb:text { text = "Shortcuts", font = "bold" },
          vb:text { text = "Enter: Generate" },
          vb:text { text = "R: Randomize" },
          vb:text { text = "Esc: Close" }
        }
      }
    },
    
    -- Bottom buttons
    vb:row {
      spacing = 8,
      
      vb:button {
        text = "Generate",
        width = 100,
        height = 28,
        notifier = function()
          PakettiMetaSynthGenerateInstrument(PakettiMetaSynthCurrentArchitecture)
        end
      },
      
      vb:button {
        text = "Randomize",
        width = 80,
        height = 28,
        notifier = function()
          PakettiMetaSynthRandomizeArchitecture(PakettiMetaSynthCurrentArchitecture)
          PakettiMetaSynthRebuildDialog()
        end
      },
      
      vb:button {
        text = "Quick Random",
        width = 90,
        height = 28,
        notifier = function()
          PakettiMetaSynthGenerateRandomInstrument()
        end
      },
      
      vb:button {
        text = "Save",
        width = 50,
        height = 28,
        notifier = function()
          local filename = renoise.app():prompt_for_filename_to_write("lua", "Save MetaSynth Architecture")
          if filename then
            PakettiMetaSynthSaveArchitecture(PakettiMetaSynthCurrentArchitecture, filename)
          end
        end
      },
      
      vb:button {
        text = "Load",
        width = 50,
        height = 28,
        notifier = function()
          local filename = renoise.app():prompt_for_filename_to_read({"lua"}, "Load MetaSynth Architecture")
          if filename then
            local loaded = PakettiMetaSynthLoadArchitecture(filename)
            if loaded then
              PakettiMetaSynthCurrentArchitecture = loaded
              PakettiMetaSynthRebuildDialog()
            end
          end
        end
      },
      
      vb:button {
        text = "Reset",
        width = 50,
        height = 28,
        notifier = function()
          PakettiMetaSynthCurrentArchitecture = PakettiMetaSynthCreateDefaultArchitecture()
          PakettiMetaSynthRebuildDialog()
        end
      },
      
      vb:button {
        text = "Close",
        width = 50,
        height = 28,
        notifier = function()
          if PakettiMetaSynthDialog and PakettiMetaSynthDialog.visible then
            PakettiMetaSynthDialog:close()
          end
        end
      }
    }
  }
  
  return content
end

-- Rebuild the dialog (for dynamic updates)
function PakettiMetaSynthRebuildDialog()
  if not PakettiMetaSynthDialog or not PakettiMetaSynthDialog.visible then return end
  
  -- Close and reopen with new content
  PakettiMetaSynthDialog:close()
  PakettiMetaSynthVB = nil
  PakettiMetaSynthShowDialog()
end

-- Show the main MetaSynth dialog
function PakettiMetaSynthShowDialog()
  -- Safety check: ensure song is loaded
  if not renoise.song() then
    renoise.app():show_status("PakettiMetaSynth: No song loaded")
    return
  end
  
  -- Initialize architecture if needed
  if not PakettiMetaSynthCurrentArchitecture then
    PakettiMetaSynthCurrentArchitecture = PakettiMetaSynthCreateDefaultArchitecture()
  end
  
  -- Close existing dialog
  if PakettiMetaSynthDialog and PakettiMetaSynthDialog.visible then
    PakettiMetaSynthDialog:close()
  end
  
  -- Reset ViewBuilder
  PakettiMetaSynthVB = nil
  
  -- Build content
  local content = PakettiMetaSynthBuildDialogContent()
  
  -- Create dialog with custom key handler
  PakettiMetaSynthDialog = renoise.app():show_custom_dialog(
    "PakettiMetaSynth - Architecture Designer",
    content,
    PakettiMetaSynthKeyHandler
  )
  
  -- Update preview
  PakettiMetaSynthUpdatePreview()
  
  -- Restore keyboard focus
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- ============================================================================
-- SECTION 11: MENU ENTRIES, KEYBINDINGS, AND MIDI MAPPINGS
-- ============================================================================

-- Menu entries
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Open Architecture Designer...",
  invoke = function()
    PakettiMetaSynthShowDialog()
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Generate Random Instrument",
  invoke = function()
    PakettiMetaSynthGenerateRandomInstrument()
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Generate Random Instrument (with Sends)",
  invoke = function()
    PakettiMetaSynthGenerateRandomInstrumentWithSends()
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Generate Random Instrument (Wavetable)",
  invoke = function()
    PakettiMetaSynthGenerateRandomWavetableInstrument()
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Generate 20 Random Instruments",
  invoke = function()
    PakettiMetaSynthGenerateBatchInstruments(false, 20)
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti:MetaSynth:Generate 20 Random Instruments (with Sends)",
  invoke = function()
    PakettiMetaSynthGenerateBatchInstruments(true, 20)
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Open Architecture Designer...",
  invoke = function()
    PakettiMetaSynthShowDialog()
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Generate Random Instrument",
  invoke = function()
    PakettiMetaSynthGenerateRandomInstrument()
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Generate Random Instrument (with Sends)",
  invoke = function()
    PakettiMetaSynthGenerateRandomInstrumentWithSends()
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Generate Random Instrument (Wavetable)",
  invoke = function()
    PakettiMetaSynthGenerateRandomWavetableInstrument()
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Generate 20 Random Instruments",
  invoke = function()
    PakettiMetaSynthGenerateBatchInstruments(false, 20)
  end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Paketti:MetaSynth:Generate 20 Random Instruments (with Sends)",
  invoke = function()
    PakettiMetaSynthGenerateBatchInstruments(true, 20)
  end
}

renoise.tool():add_menu_entry {
  name = "Sample Editor:Paketti:MetaSynth:Open Architecture Designer...",
  invoke = function()
    PakettiMetaSynthShowDialog()
  end
}

renoise.tool():add_menu_entry {
  name = "Sample FX Mixer:Paketti:MetaSynth:Open Architecture Designer...",
  invoke = function()
    PakettiMetaSynthShowDialog()
  end
}

-- Keybindings
renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Open Architecture Designer",
  invoke = function()
    PakettiMetaSynthShowDialog()
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Generate Random Instrument",
  invoke = function()
    PakettiMetaSynthGenerateRandomInstrument()
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Generate Random Instrument (with Sends)",
  invoke = function()
    PakettiMetaSynthGenerateRandomInstrumentWithSends()
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Generate 20 Random Instruments",
  invoke = function()
    PakettiMetaSynthGenerateBatchInstruments(false, 20)
  end
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:MetaSynth Generate 20 Random Instruments (with Sends)",
  invoke = function()
    PakettiMetaSynthGenerateBatchInstruments(true, 20)
  end
}

-- MIDI mappings
renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Generate Random Instrument",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthGenerateRandomInstrument()
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Generate Random Instrument (with Sends)",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthGenerateRandomInstrumentWithSends()
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Generate 20 Random Instruments",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthGenerateBatchInstruments(false, 20)
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Generate 20 Random Instruments (with Sends)",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthGenerateBatchInstruments(true, 20)
    end
  end
}

renoise.tool():add_midi_mapping {
  name = "Paketti:MetaSynth Open Architecture Designer",
  invoke = function(message)
    if message:is_trigger() then
      PakettiMetaSynthShowDialog()
    end
  end
}

print("PakettiMetaSynth loaded successfully")
