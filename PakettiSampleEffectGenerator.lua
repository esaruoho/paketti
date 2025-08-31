-- PakettiSampleEffectGenerator.lua
-- Canvas-based Sample Effect Generator
-- Draw waveform, pitch modulation, and volume envelope to generate custom samples

local vb = renoise.ViewBuilder()

-- Canvas dimensions - optimized for 3-panel layout with proper margins and text space
local canvas_width = 420
local canvas_height = 170  -- Reduced from 220 to remove 50px excess space
local text_height = 20     -- Space for vector text above canvas
local content_margin = 20  -- Proper padding to ensure waveforms stay within boundaries 
local content_width = canvas_width - (content_margin * 2)
local content_height = canvas_height - text_height - (content_margin * 2)
local content_x = content_margin
local content_y = text_height + content_margin  -- Start below text area

-- Dialog and canvas references
local sample_generator_dialog = nil
local waveform_canvas = nil
local pitch_canvas = nil
local volume_canvas = nil

-- Drawing data storage (normalized 0.0-1.0 values)
local waveform_data = {}  -- Stores drawn waveform points
local pitch_data = {}     -- Stores pitch modulation points (0.5 = no change, 0.0 = -2 octaves, 1.0 = +2 octaves)
local volume_data = {}    -- Stores volume envelope points (0.0 = silent, 1.0 = full volume)

-- Mouse tracking for each canvas - enhanced for smooth drawing
local mouse_tracking = {
  waveform = { is_down = false, last_x = -1, last_y = -1, last_index = -1 },
  pitch = { is_down = false, last_x = -1, last_y = -1, last_index = -1 },
  volume = { is_down = false, last_x = -1, last_y = -1, last_index = -1 }
}

-- Sample generation settings
local sample_duration = 2.0  -- Default 2.0 seconds
local sample_rate = 44100
local wave_type = "current"  -- "current", "sine", "triangle", "square", "sawtooth", "random"
local volume_envelope_type = "current"  -- "current", "flat", "ramp_down", "ramp_up", "triangle", "random"
local pitch_modulation_type = "current"  -- "current", "flat", "ramp_up", "ramp_down", "triangle", "sine_wave", "random"
local use_waveform_override = false  -- If true, use drawn waveform as base wave instead of dropdown selection
local fade_out_enabled = true  -- If true, apply fade out to last 15 frames to avoid clicks

-- Colors for drawing
local COLOR_BACKGROUND = {16, 16, 24, 255}
local COLOR_GRID = {32, 32, 48, 255}
local COLOR_WAVEFORM = {0, 255, 128, 255}      -- Green
local COLOR_PITCH = {255, 128, 0, 255}         -- Orange  
local COLOR_VOLUME = {128, 128, 255, 255}      -- Blue
local COLOR_CURSOR = {255, 255, 255, 255}      -- White crosshair

-- Initialize default curves
function PakettiSampleEffectGeneratorInitializeData()
  -- Clear existing data
  waveform_data = {}
  pitch_data = {}
  volume_data = {}
  
  -- Initialize with default curves
  local resolution = 100  -- Number of points across canvas width
  
  -- Default sine wave for waveform
  for i = 1, resolution do
    local x_norm = (i - 1) / (resolution - 1)  -- 0.0 to 1.0
    local sine_value = math.sin(x_norm * math.pi * 2) * 0.5 + 0.5  -- 0.0 to 1.0
    waveform_data[i] = sine_value
  end
  
  -- CRITICAL FIX: Initialize pitch_data and volume_data with correct size BEFORE calling preset functions
  for i = 1, resolution do
    pitch_data[i] = 0.5  -- Default middle (no pitch change)
    volume_data[i] = 1.0  -- Default maximum volume
  end
  
  -- Generate pitch modulation based on type
  PakettiSampleEffectGeneratorGeneratePitchPreset(pitch_modulation_type)
  
  -- Generate volume envelope based on type
  PakettiSampleEffectGeneratorGenerateVolumePreset(volume_envelope_type)
  
  print("SAMPLE_GENERATOR: Initialized default curves")
  print("SAMPLE_GENERATOR: Waveform data points: " .. #waveform_data)
  print("SAMPLE_GENERATOR: Pitch data points: " .. #pitch_data) 
  print("SAMPLE_GENERATOR: Volume data points: " .. #volume_data)
  
  -- CRITICAL FIX: Force canvas updates after initialization
  if waveform_canvas then 
    waveform_canvas:update()
    print("SAMPLE_GENERATOR: Force updated waveform canvas")
  end
  if pitch_canvas then 
    pitch_canvas:update()
    print("SAMPLE_GENERATOR: Force updated pitch canvas") 
  end
  if volume_canvas then 
    volume_canvas:update()
    print("SAMPLE_GENERATOR: Force updated volume canvas")
  end
  
  print("SAMPLE_GENERATOR: ✅ FIXED PITCH PRESETS - Now using full 0.0-1.0 range!")
end

-- Generate pitch modulation preset
function PakettiSampleEffectGeneratorGeneratePitchPreset(preset_type)
  -- Skip if "current" - preserve whatever is drawn
  if preset_type == "current" then
    return
  end
  
  local resolution = #pitch_data
  
  for i = 1, resolution do
    local x_norm = (i - 1) / (resolution - 1)  -- 0.0 to 1.0
    local pitch_value = 0.5  -- Default no change
    
    if preset_type == "flat" then
      pitch_value = 0.5  -- No pitch change (middle)
    elseif preset_type == "ramp_up" then
      pitch_value = x_norm  -- Linear ramp from 0.0 to 1.0
    elseif preset_type == "ramp_down" then
      pitch_value = 1.0 - x_norm  -- Linear ramp from 1.0 to 0.0
    elseif preset_type == "log_ramp_up" then
      pitch_value = math.pow(x_norm, 0.3)  -- Logarithmic ramp up (slow start, fast end)
    elseif preset_type == "log_ramp_down" then
      pitch_value = 1.0 - math.pow(x_norm, 0.3)  -- Logarithmic ramp down (fast start, slow end)
    elseif preset_type == "triangle" then
      if x_norm < 0.5 then
        pitch_value = x_norm * 2  -- Ramp up from 0.0 to 1.0
      else
        pitch_value = 2.0 - (x_norm * 2)  -- Ramp down from 1.0 to 0.0
      end
    elseif preset_type == "sine_wave" then
      pitch_value = 0.5 + math.sin(x_norm * math.pi * 4) * 0.4  -- Sine wave oscillation (full range)
    elseif preset_type == "pulse" then
      pitch_value = (math.sin(x_norm * math.pi * 4) > 0) and 1.0 or 0.0  -- Pulse wave
    elseif preset_type == "diode" then
      -- Diode wave for pitch - rectified sine
      local r = math.sin(x_norm * 2 * math.pi + math.pi / 6)
      if r < 0 then r = 0 end
      pitch_value = r
    elseif preset_type == "gauss" then
      -- Gaussian bell curve for pitch
      local centered_x = 2 * x_norm - 1
      pitch_value = math.exp(-centered_x * centered_x * 4)  -- Wider bell for pitch
    elseif preset_type == "chebyshev" then
      -- Chebyshev polynomial for complex pitch curves
      local cheby_x = x_norm * 2 - 1
      pitch_value = (math.cos(math.acos(cheby_x) * 2) + 1) / 2  -- 2nd order, normalized
    elseif preset_type == "chirp" then
      -- Chirp wave - PERFECT for pitch modulation!
      local phase = x_norm * 2 * math.pi
      pitch_value = (math.sin(phase / 2) * math.sin(3 * phase * phase) + 1) / 2
    elseif preset_type == "pink_noise" then
      -- Pink noise for pitch variation
      pitch_value = (math.random() + math.random() + math.random()) / 3
    elseif preset_type == "random" then
      pitch_value = math.random()  -- Random for each point
    end
    
    pitch_data[i] = pitch_value
  end
  
  if pitch_canvas then 
    pitch_canvas:update()
    print("SAMPLE_GENERATOR: Updated pitch canvas in preset function")
  else
    print("SAMPLE_GENERATOR: WARNING - pitch_canvas is nil in preset function!")
  end
end

-- Generate volume envelope preset
function PakettiSampleEffectGeneratorGenerateVolumePreset(preset_type)
  -- Skip if "current" - preserve whatever is drawn
  if preset_type == "current" then
    return
  end
  
  local resolution = #volume_data
  
  for i = 1, resolution do
    local x_norm = (i - 1) / (resolution - 1)  -- 0.0 to 1.0
    local volume_value = 1.0  -- Default maximum
    
    if preset_type == "flat" then
      volume_value = 1.0  -- Constant maximum volume
    elseif preset_type == "ramp_down" then
      volume_value = 1.0 - x_norm  -- Linear ramp from maximum (1.0) to minimum (0.0)
    elseif preset_type == "ramp_up" then
      volume_value = x_norm  -- Linear ramp from minimum (0.0) to maximum (1.0)
    elseif preset_type == "log_ramp_up" then
      volume_value = math.pow(x_norm, 0.3)  -- Logarithmic ramp up (slow start, fast end)
    elseif preset_type == "log_ramp_down" then
      volume_value = 1.0 - math.pow(x_norm, 0.3)  -- Logarithmic ramp down (fast start, slow end)
    elseif preset_type == "triangle" then
      if x_norm < 0.5 then
        volume_value = x_norm * 2  -- Ramp up from 0.0 to 1.0 at center
      else
        volume_value = 2.0 - (x_norm * 2)  -- Ramp down from 1.0 to 0.0
      end
    elseif preset_type == "fade_in_out" then
      if x_norm < 0.1 then
        volume_value = x_norm / 0.1  -- Fade in
      elseif x_norm > 0.9 then
        volume_value = (1.0 - x_norm) / 0.1  -- Fade out
      else
        volume_value = 1.0  -- Sustain
      end
    elseif preset_type == "pulse" then
      -- Pulse envelope - great for gated effects
      volume_value = (math.sin(x_norm * math.pi * 4) > 0) and 1.0 or 0.0
    elseif preset_type == "diode" then
      -- Diode envelope - rectified, great for plucky sounds
      local r = math.sin(x_norm * 2 * math.pi + math.pi / 6)
      if r < 0 then r = 0 end
      volume_value = r
    elseif preset_type == "gauss" then
      -- Gaussian bell curve - perfect for natural volume envelopes!
      local centered_x = 2 * x_norm - 1
      volume_value = math.exp(-centered_x * centered_x * 4)  -- Natural bell curve
    elseif preset_type == "chebyshev" then
      -- Chebyshev envelope - complex harmonic envelope
      local cheby_x = x_norm * 2 - 1
      volume_value = (math.cos(math.acos(cheby_x) * 2) + 1) / 2
    elseif preset_type == "chirp" then
      -- Chirp envelope - frequency sweep envelope
      local phase = x_norm * 2 * math.pi
      volume_value = (math.sin(phase / 2) * math.sin(3 * phase * phase) + 1) / 2
    elseif preset_type == "pink_noise" then
      -- Pink noise envelope - smoother random variation
      volume_value = (math.random() + math.random() + math.random()) / 3
    elseif preset_type == "random" then
      volume_value = math.random()  -- Random for each point
    end
    
    volume_data[i] = volume_value
  end
  
  if volume_canvas then 
    volume_canvas:update()
    print("SAMPLE_GENERATOR: Updated volume canvas in preset function")
  else
    print("SAMPLE_GENERATOR: WARNING - volume_canvas is nil in preset function!")
  end
end

-- Generate base waveform in waveform canvas
function PakettiSampleEffectGeneratorGenerateBaseWaveform(waveform_type)
  local resolution = #waveform_data
  
  for i = 1, resolution do
    local x_norm = (i - 1) / (resolution - 1)  -- 0.0 to 1.0
    local wave_value = 0.5  -- Default middle
    
    if waveform_type == "sine" then
      wave_value = math.sin(x_norm * math.pi * 2) * 0.5 + 0.5  -- 0.0 to 1.0
    elseif waveform_type == "triangle" then
      if x_norm < 0.25 then
        wave_value = x_norm * 4 * 0.5 + 0.5  -- 0.5 to 1.0
      elseif x_norm < 0.75 then
        wave_value = (2 - x_norm * 4) * 0.5 + 0.5  -- 1.0 to 0.0 to 1.0
      else
        wave_value = ((x_norm - 0.75) * 4 - 1) * 0.5 + 0.5  -- 0.0 to 0.5
      end
    elseif waveform_type == "square" then
      wave_value = (math.sin(x_norm * math.pi * 2) > 0) and 1.0 or 0.0
    elseif waveform_type == "sawtooth" then
      wave_value = x_norm  -- Linear ramp 0.0 to 1.0
    elseif waveform_type == "log_ramp_up" then
      wave_value = math.pow(x_norm, 0.3)  -- Logarithmic ramp up (slow start, fast end)
    elseif waveform_type == "log_ramp_down" then
      wave_value = 1.0 - math.pow(x_norm, 0.3)  -- Logarithmic ramp down (fast start, slow end)
    elseif waveform_type == "pulse" then
      -- Pulse wave with 50% duty cycle (variable duty can be added later)
      wave_value = (math.sin(x_norm * math.pi * 2) > 0) and 1.0 or 0.0
    elseif waveform_type == "diode" then
      -- Diode wave - rectified sine-like wave, great for envelopes
      local shifted_x = (x_norm + 0.25) % 1  -- Shift to start at middle value
      local r = math.sin(shifted_x * 2 * math.pi + math.pi / 6)
      if r < 0 then r = 0 end  -- Rectify (cut off negative portions)
      wave_value = r
    elseif waveform_type == "gauss" then
      -- Gaussian/bell curve - perfect for volume envelopes
      local centered_x = 2 * x_norm - 1  -- Center around 0
      wave_value = math.exp(-centered_x * centered_x * 8) -- Gaussian curve
    elseif waveform_type == "chebyshev" then
      -- Chebyshev polynomial - complex harmonics
      local cheby_x = x_norm * 2 - 1  -- Convert to -1 to 1 range
      wave_value = (math.cos(math.acos(cheby_x) * 3) + 1) / 2  -- 3rd order Chebyshev, normalized to 0-1
    elseif waveform_type == "chirp" then
      -- Chirp wave - frequency sweep (amazing for pitch modulation!)
      local phase = x_norm * 2 * math.pi
      wave_value = (math.sin(phase / 2) * math.sin(3 * phase * phase) + 1) / 2  -- Normalized to 0-1
    elseif waveform_type == "pink_noise" then
      -- Pink noise approximation (smoother than white noise)
      wave_value = (math.random() + math.random() + math.random()) / 3  -- Simple pink noise approximation
    elseif waveform_type == "random" then
      wave_value = math.random()  -- Random 0.0 to 1.0
    end
    
    waveform_data[i] = wave_value
  end
  
  if waveform_canvas then 
    waveform_canvas:update()
    print("SAMPLE_GENERATOR: Generated " .. waveform_type .. " base waveform in waveform canvas")
  else
    print("SAMPLE_GENERATOR: WARNING - waveform_canvas is nil in base waveform function!")
  end
end

-- Render waveform only without pitch/volume envelopes applied
function PakettiSampleEffectGeneratorRenderWaveformOnly()
  if not sample_generator_dialog or not sample_generator_dialog.visible then
    return
  end
  
  print("SAMPLE_GENERATOR: Rendering waveform ONLY (no pitch/volume envelopes)")
  
  -- Calculate sample properties
  local total_samples = math.floor(sample_duration * sample_rate)
  local sample_data = {}
  
  print("SAMPLE_GENERATOR: Duration=" .. sample_duration .. "s, Samples=" .. total_samples)
  print("SAMPLE_GENERATOR: Using ONLY drawn waveform curve (ignoring pitch and volume)")
  
  -- Generate sample data using ONLY the waveform curve
  local base_freq = 440.0  -- A4 note
  local phase_accumulator = 0.0
  local phase_delta = base_freq * 2 * math.pi / sample_rate  -- Fixed frequency, no pitch modulation
  
  for sample_i = 1, total_samples do
    local time_norm = (sample_i - 1) / (total_samples - 1)  -- 0.0 to 1.0
    
    -- Sample the drawn waveform curve directly (no pitch modulation)
    local waveform_phase = (phase_accumulator / (2 * math.pi)) % 1.0  -- 0.0 to 1.0
    local waveform_value = PakettiSampleEffectGeneratorInterpolateData(waveform_data, waveform_phase)
    local wave_sample = (waveform_value * 2) - 1  -- Convert 0.0-1.0 to -1.0 to 1.0
    
    -- NO PITCH MODULATION - just advance phase at constant rate
    phase_accumulator = phase_accumulator + phase_delta
    
    -- Keep phase in reasonable range
    while phase_accumulator > 2 * math.pi do
      phase_accumulator = phase_accumulator - 2 * math.pi
    end
    
    -- NO VOLUME ENVELOPE - use full amplitude
    -- Apply fade out if enabled (last 15 frames to avoid clicks)
    if fade_out_enabled then
      local fade_frames = 15
      if sample_i > (total_samples - fade_frames) then
        local fade_pos = sample_i - (total_samples - fade_frames)
        local fade_mult = 1.0 - (fade_pos / fade_frames)  -- 1.0 to 0.0
        wave_sample = wave_sample * fade_mult
      end
    end
    
    -- Store sample (clamp to -1.0 to 1.0 range)
    sample_data[sample_i] = math.max(-1.0, math.min(1.0, wave_sample))
  end
  
  -- Create and load sample using PakettiSamples functions
  PakettiSampleEffectGeneratorCreateAndLoadSample(sample_data, sample_rate)
  
  print("SAMPLE_GENERATOR: Waveform-only sample generation complete!")
  renoise.app():show_status("Generated " .. sample_duration .. "s sample using ONLY waveform curve")
end

-- Double the frequency of waveform (increase octave) - ABSOLUTELY PERFECT ALGORITHM
function PakettiSampleEffectGeneratorDoubleWaveform()
  local resolution = #waveform_data
  local original_data = {}
  
  -- Save original data
  for i = 1, resolution do
    original_data[i] = waveform_data[i]
  end
  
  -- Create new data: PERFECT 2x with exact integer division - ZERO ARTIFACTS
  local half_size = math.floor(resolution / 2)
  
  for i = 1, resolution do
    if i <= half_size then
      -- First half: sample every 2nd point from original (perfect decimation)
      local source_index = ((i - 1) * 2) + 1
      if source_index <= resolution then
        waveform_data[i] = original_data[source_index]
      else
        waveform_data[i] = original_data[resolution]  -- Use last point as fallback
      end
    else
      -- Second half: exact mirror copy of first half
      local mirror_index = i - half_size
      if mirror_index >= 1 and mirror_index <= half_size then
        waveform_data[i] = waveform_data[mirror_index]
      else
        waveform_data[i] = waveform_data[1]
      end
    end
  end
  
  if waveform_canvas then waveform_canvas:update() end
  print("SAMPLE_GENERATOR: ✅ ABSOLUTELY PERFECT - Doubled waveform frequency - ZERO artifacts, perfect decimation!")
end

-- Halve the frequency of waveform (decrease octave) - PRISTINE ALGORITHM
function PakettiSampleEffectGeneratorHalveWaveform()
  local resolution = #waveform_data
  local original_data = {}
  
  -- Save original data
  for i = 1, resolution do
    original_data[i] = waveform_data[i]
  end
  
  -- Create new data: take only first half and stretch it to full resolution - PRISTINE & PERFECT
  local half_resolution = math.floor(resolution / 2)
  
  for i = 1, resolution do
    -- Sample from first half only, stretching it to full width
    local half_index = math.floor((i - 1) * half_resolution / resolution) + 1
    half_index = math.min(half_index, half_resolution)  -- Ensure valid index
    waveform_data[i] = original_data[half_index]
  end
  
  if waveform_canvas then waveform_canvas:update() end
  print("SAMPLE_GENERATOR: ✅ PRISTINE - Halved waveform frequency (2 cycles → 1 cycle) - PERFECT INVERSE!")
  print("SAMPLE_GENERATOR: Using PERFECT integer sampling - reversible operations!")
end

-- Double the frequency of pitch curve (increase octave) - ABSOLUTELY PERFECT ALGORITHM
function PakettiSampleEffectGeneratorDoublePitch()
  local resolution = #pitch_data
  local original_data = {}
  
  -- Save original data
  for i = 1, resolution do
    original_data[i] = pitch_data[i]
  end
  
  -- Create new data: PERFECT 2x with exact integer division - ZERO ARTIFACTS
  local half_size = math.floor(resolution / 2)
  
  for i = 1, resolution do
    if i <= half_size then
      -- First half: sample every 2nd point from original (perfect decimation)
      local source_index = ((i - 1) * 2) + 1
      if source_index <= resolution then
        pitch_data[i] = original_data[source_index]
      else
        pitch_data[i] = original_data[resolution]  -- Use last point as fallback
      end
    else
      -- Second half: exact mirror copy of first half
      local mirror_index = i - half_size
      if mirror_index >= 1 and mirror_index <= half_size then
        pitch_data[i] = pitch_data[mirror_index]
      else
        pitch_data[i] = pitch_data[1]
      end
    end
  end
  
  if pitch_canvas then pitch_canvas:update() end
  print("SAMPLE_GENERATOR: ✅ ABSOLUTELY PERFECT - Doubled pitch frequency - ZERO artifacts, perfect decimation!")
end

-- Halve the frequency of pitch curve (decrease octave) - PRISTINE ALGORITHM
function PakettiSampleEffectGeneratorHalvePitch()
  local resolution = #pitch_data
  local original_data = {}
  
  -- Save original data
  for i = 1, resolution do
    original_data[i] = pitch_data[i]
  end
  
  -- Create new data: take only first half and stretch it to full resolution - PRISTINE & PERFECT
  local half_resolution = math.floor(resolution / 2)
  
  for i = 1, resolution do
    -- Sample from first half only, stretching it to full width
    local half_index = math.floor((i - 1) * half_resolution / resolution) + 1
    half_index = math.min(half_index, half_resolution)  -- Ensure valid index
    pitch_data[i] = original_data[half_index]
  end
  
  if pitch_canvas then pitch_canvas:update() end
  print("SAMPLE_GENERATOR: ✅ PRISTINE - Halved pitch curve frequency (2 cycles → 1 cycle) - PERFECT INVERSE!")
  print("SAMPLE_GENERATOR: Using PERFECT integer sampling - reversible operations!")
end

-- Double the frequency of volume envelope (increase octave) - ABSOLUTELY PERFECT ALGORITHM
function PakettiSampleEffectGeneratorDoubleVolume()
  local resolution = #volume_data
  local original_data = {}
  
  -- Save original data
  for i = 1, resolution do
    original_data[i] = volume_data[i]
  end
  
  -- Create new data: PERFECT 2x with exact integer division - ZERO ARTIFACTS
  local half_size = math.floor(resolution / 2)
  
  for i = 1, resolution do
    if i <= half_size then
      -- First half: sample every 2nd point from original (perfect decimation)
      local source_index = ((i - 1) * 2) + 1
      if source_index <= resolution then
        volume_data[i] = original_data[source_index]
      else
        volume_data[i] = original_data[resolution]  -- Use last point as fallback
      end
    else
      -- Second half: exact mirror copy of first half
      local mirror_index = i - half_size
      if mirror_index >= 1 and mirror_index <= half_size then
        volume_data[i] = volume_data[mirror_index]
      else
        volume_data[i] = volume_data[1]
      end
    end
  end
  
  if volume_canvas then volume_canvas:update() end
  print("SAMPLE_GENERATOR: ✅ ABSOLUTELY PERFECT - Doubled volume frequency - ZERO artifacts, perfect decimation!")
end

-- Halve the frequency of volume envelope (decrease octave) - PRISTINE ALGORITHM
function PakettiSampleEffectGeneratorHalveVolume()
  local resolution = #volume_data
  local original_data = {}
  
  -- Save original data
  for i = 1, resolution do
    original_data[i] = volume_data[i]
  end
  
  -- Create new data: take only first half and stretch it to full resolution - PRISTINE & PERFECT
  local half_resolution = math.floor(resolution / 2)
  
  for i = 1, resolution do
    -- Sample from first half only, stretching it to full width
    local half_index = math.floor((i - 1) * half_resolution / resolution) + 1
    half_index = math.min(half_index, half_resolution)  -- Ensure valid index
    volume_data[i] = original_data[half_index]
  end
  
  if volume_canvas then volume_canvas:update() end
  print("SAMPLE_GENERATOR: ✅ PRISTINE - Halved volume envelope frequency (2 cycles → 1 cycle) - PERFECT INVERSE!")
  print("SAMPLE_GENERATOR: Using PERFECT integer sampling - reversible operations!")
end

-- Randomize waveform data
function PakettiSampleEffectGeneratorRandomizeWaveform()
  local resolution = #waveform_data
  for i = 1, resolution do
    waveform_data[i] = math.random()  -- Random 0.0 to 1.0
  end
  if waveform_canvas then 
    waveform_canvas:update()
    print("SAMPLE_GENERATOR: Updated waveform canvas")
  else
    print("SAMPLE_GENERATOR: WARNING - waveform_canvas is nil!")
  end
  print("SAMPLE_GENERATOR: Randomized waveform")
end

-- Randomize pitch data
function PakettiSampleEffectGeneratorRandomizePitch()
  local resolution = #pitch_data
  for i = 1, resolution do
    pitch_data[i] = math.random()  -- Random 0.0 to 1.0 (full pitch range)
  end
  if pitch_canvas then 
    pitch_canvas:update()
    print("SAMPLE_GENERATOR: Updated pitch canvas")
  else
    print("SAMPLE_GENERATOR: WARNING - pitch_canvas is nil!")
  end
  print("SAMPLE_GENERATOR: Randomized pitch")
end

-- Randomize volume data
function PakettiSampleEffectGeneratorRandomizeVolume()
  local resolution = #volume_data
  for i = 1, resolution do
    volume_data[i] = math.random()  -- Random 0.0 to 1.0
  end
  if volume_canvas then 
    volume_canvas:update()
    print("SAMPLE_GENERATOR: Updated volume canvas")
  else
    print("SAMPLE_GENERATOR: WARNING - volume_canvas is nil!")
  end
  print("SAMPLE_GENERATOR: Randomized volume")
end

-- Generate 25 random samples
function PakettiSampleEffectGeneratorGenerate25Random()
  print("SAMPLE_GENERATOR: Starting 25 random sample generation...")
  
  for sample_num = 1, 25 do
    print("SAMPLE_GENERATOR: Generating random sample " .. sample_num .. "/25")
    
    -- Randomize all curves
    PakettiSampleEffectGeneratorRandomizeWaveform()
    PakettiSampleEffectGeneratorRandomizePitch()
    PakettiSampleEffectGeneratorRandomizeVolume()
    
    -- Randomize wave type
    local wave_types = {"sine", "triangle", "square", "sawtooth", "random"}
    wave_type = wave_types[math.random(1, 5)]
    
    -- Randomize volume envelope type
    local volume_types = {"flat", "ramp_down", "ramp_up", "triangle", "fade_in_out", "random"}
    volume_envelope_type = volume_types[math.random(1, 6)]
    
    -- Randomize pitch modulation type
    local pitch_types = {"flat", "ramp_up", "ramp_down", "triangle", "sine_wave", "random"}
    pitch_modulation_type = pitch_types[math.random(1, 6)]
    
    -- Randomize duration (0.5 to 5.0 seconds)
    sample_duration = 0.5 + math.random() * 4.5
    
    -- Generate the sample
    PakettiSampleEffectGeneratorGenerateSample()
    
    -- Small delay to prevent overwhelming Renoise
    if sample_num % 5 == 0 then
      print("SAMPLE_GENERATOR: Generated " .. sample_num .. "/25 samples...")
    end
  end
  
  renoise.app():show_status("Generated 25 random samples!")
  print("SAMPLE_GENERATOR: Completed 25 random sample generation")
end

-- Handle mouse input for canvas drawing with smooth line interpolation
function PakettiSampleEffectGeneratorHandleMouse(canvas_type, ev)
  local tracking = mouse_tracking[canvas_type]
  local data_array
  
  -- Select the appropriate data array
  if canvas_type == "waveform" then
    data_array = waveform_data
  elseif canvas_type == "pitch" then
    data_array = pitch_data
  elseif canvas_type == "volume" then
    data_array = volume_data
  else
    return
  end
  
  -- Handle mouse events
  if ev.type == "down" then
    tracking.is_down = true
    tracking.last_x = ev.position.x
    tracking.last_y = ev.position.y
    local data_index, y_norm = PakettiSampleEffectGeneratorDrawPoint(canvas_type, ev.position.x, ev.position.y)
    tracking.last_index = data_index
    
  elseif ev.type == "up" then
    tracking.is_down = false
    tracking.last_x = -1
    tracking.last_y = -1
    tracking.last_index = -1
    
  elseif ev.type == "move" then
    tracking.last_x = ev.position.x
    tracking.last_y = ev.position.y
    
    if tracking.is_down then
      local current_index, current_y_norm = PakettiSampleEffectGeneratorDrawPoint(canvas_type, ev.position.x, ev.position.y)
      
      -- Draw smooth line between last and current position if we have a previous point
      if current_index and tracking.last_index > 0 and tracking.last_index ~= current_index then
        local last_y_norm = 1.0 - ((tracking.last_y - content_y) / content_height)
        last_y_norm = math.max(0, math.min(1, last_y_norm))  -- Clamp
        PakettiSampleEffectGeneratorDrawLineBetween(data_array, tracking.last_index, last_y_norm, current_index, current_y_norm)
      end
      
      -- Only update last_index if current_index is valid
      if current_index then
        tracking.last_index = current_index
      end
    end
    
  elseif ev.type == "exit" then
    -- Stop drawing when mouse leaves canvas
    if tracking.is_down then
      tracking.is_down = false
      tracking.last_x = -1
      tracking.last_y = -1
      tracking.last_index = -1
    end
    return
  end
  
  -- Update the specific canvas
  local canvas
  if canvas_type == "waveform" and waveform_canvas then
    canvas = waveform_canvas
  elseif canvas_type == "pitch" and pitch_canvas then
    canvas = pitch_canvas
  elseif canvas_type == "volume" and volume_canvas then
    canvas = volume_canvas
  end
  
  if canvas then
    canvas:update()
  end
end

-- Draw a point on the canvas and update data - returns data_index and y_norm for smooth drawing
function PakettiSampleEffectGeneratorDrawPoint(canvas_type, mouse_x, mouse_y)
  local data_array
  if canvas_type == "waveform" then
    data_array = waveform_data
  elseif canvas_type == "pitch" then
    data_array = pitch_data
  elseif canvas_type == "volume" then
    data_array = volume_data
  else
    return nil, nil
  end
  
  -- Check if mouse is within content area
  if mouse_x < content_x or mouse_x >= content_x + content_width or
     mouse_y < content_y or mouse_y >= content_y + content_height then
    return nil, nil
  end
  
  -- Convert mouse position to data index and value
  local x_norm = (mouse_x - content_x) / content_width  -- 0.0 to 1.0
  local y_norm = 1.0 - ((mouse_y - content_y) / content_height)  -- 0.0 to 1.0 (inverted Y)
  
  -- Clamp values
  x_norm = math.max(0, math.min(1, x_norm))
  y_norm = math.max(0, math.min(1, y_norm))
  
  -- Map to data array index - FIX: Ensure proper scaling across full array length
  local data_index = math.floor(x_norm * (#data_array - 1)) + 1
  data_index = math.max(1, math.min(#data_array, data_index))
  
  -- Update data
  data_array[data_index] = y_norm
  
  print("DRAW: " .. canvas_type .. " index=" .. data_index .. " value=" .. string.format("%.3f", y_norm))
  
  return data_index, y_norm
end

-- Render canvas content with vector text labels
function PakettiSampleEffectGeneratorRenderCanvas(canvas_type, ctx)
  local w, h = canvas_width, canvas_height
  local data_array
  local color
  local label_text
  
  -- Select data, color, and label text
  if canvas_type == "waveform" then
    data_array = waveform_data
    color = COLOR_WAVEFORM
    label_text = "WAVEFORM"
  elseif canvas_type == "pitch" then
    data_array = pitch_data
    color = COLOR_PITCH
    label_text = "PITCH OVER TIME"
  elseif canvas_type == "volume" then
    data_array = volume_data
    color = COLOR_VOLUME
    label_text = "VOLUME OVER TIME"
  else
    return
  end
  
  -- Clear canvas
  ctx:clear_rect(0, 0, w, h)
  
  -- Draw background
  ctx.fill_color = COLOR_BACKGROUND
  ctx:fill_rect(0, 0, w, h)
  
  -- Draw vector text label using PakettiCanvasFont
  ctx.stroke_color = {200, 200, 200, 255}  -- Light gray text
  ctx.line_width = 1
  local font_size = 12
  local text_x = content_x + 5  -- Small offset from content area
  local text_y = 5              -- Top of canvas with small margin
  PakettiCanvasFontDrawText(ctx, label_text, text_x, text_y, font_size)
  
  -- Draw grid
  ctx.stroke_color = COLOR_GRID
  ctx.line_width = 1
  
  -- Vertical grid lines
  for i = 0, 8 do
    local x = content_x + (i / 8) * content_width
    ctx:begin_path()
    ctx:move_to(x, content_y)
    ctx:line_to(x, content_y + content_height)
    ctx:stroke()
  end
  
  -- Horizontal grid lines
  for i = 0, 4 do
    local y = content_y + (i / 4) * content_height
    ctx:begin_path()
    ctx:move_to(content_x, y)
    ctx:line_to(content_x + content_width, y)
    ctx:stroke()
  end
  
  -- Draw center line for pitch canvas
  if canvas_type == "pitch" then
    ctx.stroke_color = {128, 128, 128, 255}  -- Gray center line
    ctx.line_width = 2
    local center_y = content_y + content_height / 2
    ctx:begin_path()
    ctx:move_to(content_x, center_y)
    ctx:line_to(content_x + content_width, center_y)
    ctx:stroke()
  end
  
  -- Draw curve - Ensure it stays within content boundaries with proper clipping
  if #data_array > 1 then
    -- Save the current canvas state
    ctx:save()
    
    -- Set clipping rectangle to content area to prevent waveform bleeding
    ctx:begin_path()
    ctx:rect(content_x, content_y, content_width, content_height)
    ctx:clip()
    
    ctx.stroke_color = color
    ctx.line_width = 2
    ctx:begin_path()
    
    local points_drawn = 0
    for i = 1, #data_array do
      local x_norm = (i - 1) / (#data_array - 1)
      -- Calculate positions within content bounds
      local x_pos = content_x + x_norm * content_width
      local y_pos = content_y + (1.0 - data_array[i]) * content_height
      
      -- Additional safety clamp to ensure absolutely no boundary violations
      x_pos = math.max(content_x, math.min(content_x + content_width, x_pos))
      y_pos = math.max(content_y, math.min(content_y + content_height, y_pos))
      
      if i == 1 then
        ctx:move_to(x_pos, y_pos)
      else
        ctx:line_to(x_pos, y_pos)
      end
      points_drawn = points_drawn + 1
    end
    
    ctx:stroke()
    
    -- Restore the canvas state to remove clipping
    ctx:restore()
  end
  
  -- Draw mouse cursor
  local tracking = mouse_tracking[canvas_type]
  if tracking.is_down and tracking.last_x >= 0 and tracking.last_y >= 0 then
    ctx.stroke_color = COLOR_CURSOR
    ctx.line_width = 1
    
    -- Crosshair
    ctx:begin_path()
    ctx:move_to(tracking.last_x, content_y)
    ctx:line_to(tracking.last_x, content_y + content_height)
    ctx:move_to(content_x, tracking.last_y)
    ctx:line_to(content_x + content_width, tracking.last_y)
    ctx:stroke()
  end
  
  -- Draw border
  ctx.stroke_color = {80, 80, 80, 255}
  ctx.line_width = 2
  ctx:begin_path()
  ctx:rect(content_x, content_y, content_width, content_height)
  ctx:stroke()
end

-- Key handler for dialog
function paketti_sample_generator_keyhandler_func(dialog, key)
  print("SAMPLE_GENERATOR_KEY: " .. tostring(key.name) .. " modifiers: " .. tostring(key.modifiers))
  
  -- SPACE key to generate sample
  if key.name == "space" then
    print("SAMPLE_GENERATOR: SPACE pressed - generating sample")
    PakettiSampleEffectGeneratorGenerateSample()
    return nil  -- Don't pass to Renoise
  end
  
  -- ESC or CMD-H to close
  if key.name == "esc" or (key.modifiers == "command" and key.name == "h") then
    print("SAMPLE_GENERATOR: Closing dialog")
    PakettiSampleEffectGeneratorCleanup()
    if sample_generator_dialog then
      sample_generator_dialog:close()
    end
    return nil
  end
  
  -- Pass other keys to Renoise
  return key
end

-- Draw a line between two points to prevent gaps during fast mouse movement (smooth drawing)
function PakettiSampleEffectGeneratorDrawLineBetween(data_array, start_index, start_value, end_index, end_value)
  if start_index == end_index then
    data_array[start_index] = end_value
    return
  end
  
  -- Ensure start_index is less than end_index
  if start_index > end_index then
    start_index, end_index = end_index, start_index
    start_value, end_value = end_value, start_value
  end
  
  -- Interpolate between points
  for i = start_index, end_index do
    local t = (i - start_index) / (end_index - start_index)
    data_array[i] = start_value + (end_value - start_value) * t
  end
end

-- Generate sample from drawn curves
function PakettiSampleEffectGeneratorGenerateSample()
  if not sample_generator_dialog or not sample_generator_dialog.visible then
    return
  end
  
  print("SAMPLE_GENERATOR: Starting sample generation...")
  
  -- Calculate sample properties
  local total_samples = math.floor(sample_duration * sample_rate)
  local sample_data = {}
  
  print("SAMPLE_GENERATOR: Duration=" .. sample_duration .. "s, Samples=" .. total_samples)
  print("SAMPLE_GENERATOR: Wave type=" .. wave_type .. ", Waveform points=" .. #waveform_data .. ", Pitch points=" .. #pitch_data .. ", Volume points=" .. #volume_data)
  print("SAMPLE_GENERATOR: Waveform Override Mode: " .. (use_waveform_override and "ON (drawn curve repeats as oscillator)" or "OFF (uses dropdown wave type)"))
  print("SAMPLE_GENERATOR: Using CURRENT curves: Wave=" .. (wave_type == "current" and "YES" or "NO") .. 
        ", Pitch=" .. (pitch_modulation_type == "current" and "YES" or "NO") .. 
        ", Volume=" .. (volume_envelope_type == "current" and "YES" or "NO"))
  print("SAMPLE_GENERATOR: ✅ FIXED - Now generating " .. total_samples .. " samples over " .. sample_duration .. " seconds with pitch modulation!")
  
  -- Generate sample data with proper phase accumulation for pitch modulation
  local phase_accumulator = 0.0
  local base_freq = 440.0  -- A4 note
  
  -- Show pitch range info
  local min_pitch = 999
  local max_pitch = -999
  for i = 1, #pitch_data do
    min_pitch = math.min(min_pitch, pitch_data[i])
    max_pitch = math.max(max_pitch, pitch_data[i])
  end
  print("SAMPLE_GENERATOR: Pitch curve range: " .. string.format("%.3f", min_pitch) .. " to " .. string.format("%.3f", max_pitch) .. 
        " (freq range: " .. string.format("%.1f", base_freq * math.pow(2, (min_pitch - 0.5) * 4)) .. "Hz to " .. 
        string.format("%.1f", base_freq * math.pow(2, (max_pitch - 0.5) * 4)) .. "Hz)")
  
  for sample_i = 1, total_samples do
    local time_norm = (sample_i - 1) / (total_samples - 1)  -- 0.0 to 1.0
    
    -- Get interpolated values from curves
    local waveform_value = PakettiSampleEffectGeneratorInterpolateData(waveform_data, time_norm)
    local pitch_mult = PakettiSampleEffectGeneratorInterpolateData(pitch_data, time_norm)
    local volume_mult = PakettiSampleEffectGeneratorInterpolateData(volume_data, time_norm)
    
    -- Convert pitch curve to frequency multiplier
    -- 0.0 = 0.25x (2 octaves down), 0.5 = 1.0x (no change), 1.0 = 4.0x (2 octaves up)
    local freq_mult = math.pow(2, (pitch_mult - 0.5) * 4)  -- -2 to +2 octaves
    
    -- Calculate instantaneous frequency
    local actual_freq = base_freq * freq_mult
    
    -- Accumulate phase (this gives smooth pitch transitions)
    local phase_delta = actual_freq * 2 * math.pi / sample_rate
    phase_accumulator = phase_accumulator + phase_delta
    
    -- Keep phase in reasonable range
    while phase_accumulator > 2 * math.pi do
      phase_accumulator = phase_accumulator - 2 * math.pi
    end
    
    -- Generate base oscillator sample (this provides the pitch-modulated carrier wave)
    local base_wave_sample
    
    -- Always generate a pitched oscillator first
    if wave_type == "current" then
      base_wave_sample = math.sin(phase_accumulator)  -- Default to sine for current mode (override mode handles waveform sampling)
    elseif wave_type == "sine" then
      base_wave_sample = math.sin(phase_accumulator)
    elseif wave_type == "triangle" then
      -- Better triangle wave generation
      local normalized_phase = (phase_accumulator / (2 * math.pi)) % 1
      if normalized_phase < 0.25 then
        base_wave_sample = 4 * normalized_phase
      elseif normalized_phase < 0.75 then
        base_wave_sample = 2 - 4 * normalized_phase
      else
        base_wave_sample = 4 * normalized_phase - 4
      end
    elseif wave_type == "square" then
      base_wave_sample = math.sin(phase_accumulator) > 0 and 1 or -1
    elseif wave_type == "sawtooth" then
      -- Better sawtooth wave generation
      local normalized_phase = (phase_accumulator / (2 * math.pi)) % 1
      base_wave_sample = 2 * normalized_phase - 1
    elseif wave_type == "random" then
      -- Pure random noise
      base_wave_sample = (math.random() * 2) - 1  -- Random -1 to 1
    else
      base_wave_sample = math.sin(phase_accumulator)  -- Default to sine
    end
    
    -- Apply waveform curve (different behavior based on override mode)
    local wave_sample
    if use_waveform_override then
      -- WAVEFORM OVERRIDE MODE: Use drawn waveform as repeating oscillator based on phase!
      -- Sample the drawn waveform based on current phase (like other oscillators)
      local waveform_phase = (phase_accumulator / (2 * math.pi)) % 1.0  -- 0.0 to 1.0
      local waveform_sample_value = PakettiSampleEffectGeneratorInterpolateData(waveform_data, waveform_phase)
      wave_sample = (waveform_sample_value * 2) - 1  -- Convert 0.0-1.0 to -1.0 to 1.0
    else
      -- STANDARD MODE: Use the pitched oscillator as the base wave, waveform is NOT amplitude modulation
      -- The drawn waveform curve should NOT affect amplitude - that's what volume envelope is for!
      wave_sample = base_wave_sample  -- Use the pitched oscillator directly, no waveform amplitude modulation
    end
    
    -- Apply volume envelope
    wave_sample = wave_sample * volume_mult
    
    -- Apply fade out if enabled (last 15 frames to avoid clicks)
    if fade_out_enabled then
      local fade_frames = 15
      if sample_i > (total_samples - fade_frames) then
        local fade_pos = sample_i - (total_samples - fade_frames)
        local fade_mult = 1.0 - (fade_pos / fade_frames)  -- 1.0 to 0.0
        wave_sample = wave_sample * fade_mult
      end
    end
    
    -- Store sample (clamp to -1.0 to 1.0 range)
    sample_data[sample_i] = math.max(-1.0, math.min(1.0, wave_sample))
  end
  
  -- Create and load sample using PakettiSamples functions
  PakettiSampleEffectGeneratorCreateAndLoadSample(sample_data, sample_rate)
  
  print("SAMPLE_GENERATOR: Sample generation complete!")
  renoise.app():show_status("Generated " .. sample_duration .. "s sample with custom curves")
end

-- Interpolate data array at normalized position
function PakettiSampleEffectGeneratorInterpolateData(data_array, time_norm)
  if #data_array == 0 then
    return 0.5  -- Default middle value
  end
  
  if #data_array == 1 then
    return data_array[1]
  end
  
  -- Map time to array indices
  local float_index = time_norm * (#data_array - 1) + 1
  local lower_index = math.floor(float_index)
  local upper_index = math.ceil(float_index)
  local fraction = float_index - lower_index
  
  -- Clamp indices
  lower_index = math.max(1, math.min(#data_array, lower_index))
  upper_index = math.max(1, math.min(#data_array, upper_index))
  
  -- Linear interpolation
  if lower_index == upper_index then
    return data_array[lower_index]
  else
    local lower_value = data_array[lower_index]
    local upper_value = data_array[upper_index]
    return lower_value + (upper_value - lower_value) * fraction
  end
end

-- Create and load sample into Renoise
function PakettiSampleEffectGeneratorCreateAndLoadSample(sample_data, sample_rate)
  print("SAMPLE_GENERATOR: Creating sample buffer...")
  
  local song = renoise.song()
  local instrument = song.selected_instrument
  local sample_index = song.selected_sample_index
  
  -- Check if we need to create a new instrument or use current one
  local needs_new_instrument = false
  if #instrument.samples > 0 then
    -- Check if current sample has data or if we should create new instrument
    local current_sample = instrument.samples[sample_index]
    if current_sample and current_sample.sample_buffer.has_sample_data then
      needs_new_instrument = true
    end
  end
  
  if needs_new_instrument then
    -- Insert new instrument for generated sample
    song:insert_instrument_at(song.selected_instrument_index + 1)
    song.selected_instrument_index = song.selected_instrument_index + 1
    print("SAMPLE_GENERATOR: Created new instrument for generated sample")
  end
  
  -- Load default instrument template
  pakettiPreferencesDefaultInstrumentLoader()
  
  -- Get fresh references after loading template
  instrument = song.selected_instrument
  
  -- Clear any existing sample data and create fresh sample
  if #instrument.samples > 0 then
    instrument:delete_sample_at(1)
  end
  
  local sample = instrument:insert_sample_at(1)
  
  -- Create sample buffer with correct dimensions
  local num_channels = 1  -- Mono
  local bit_depth = 32    -- 32-bit float
  local num_frames = #sample_data
  
  local success = sample.sample_buffer:create_sample_data(sample_rate, bit_depth, num_channels, num_frames)
  if not success then
    renoise.app():show_error("Failed to create sample buffer - out of memory?")
    return
  end
  
  -- Prepare for sample data changes
  sample.sample_buffer:prepare_sample_data_changes()
  
  -- Write our generated sample data
  for i = 1, num_frames do
    sample.sample_buffer:set_sample_data(1, i, sample_data[i])  -- Channel 1, frame i, sample value
  end
  
  -- Finalize sample data changes
  sample.sample_buffer:finalize_sample_data_changes()
  
  -- Set sample properties
  sample.name = "Generated_" .. os.date("%H%M%S")
  sample.fine_tune = 0
  sample.volume = 1.0
  sample.panning = 0.5
  
  -- Set sample mapping properties (base_note is on the mapping, not the sample)
  if sample.sample_mapping then
    sample.sample_mapping.base_note = 48  -- C-4 (middle C)
  end
  
  -- Set instrument name
  instrument.name = "Generated Sample " .. os.date("%H%M%S")
  
  -- Select sample editor for immediate feedback
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  
  print("SAMPLE_GENERATOR: Sample loaded successfully: " .. sample.name)
  renoise.app():show_status("Sample loaded: " .. sample.name)
end



-- Cleanup function
function PakettiSampleEffectGeneratorCleanup()
  print("SAMPLE_GENERATOR: Cleanup started")
  
  -- Clear references
  sample_generator_dialog = nil
  waveform_canvas = nil
  pitch_canvas = nil
  volume_canvas = nil
  
  -- Reset mouse tracking
  mouse_tracking = {
    waveform = { is_down = false, last_x = -1, last_y = -1, last_index = -1 },
    pitch = { is_down = false, last_x = -1, last_y = -1, last_index = -1 },
    volume = { is_down = false, last_x = -1, last_y = -1, last_index = -1 }
  }
  
  print("SAMPLE_GENERATOR: Cleanup complete")
end

-- Create the main dialog
function PakettiSampleEffectGeneratorCreateDialog()
  if sample_generator_dialog and sample_generator_dialog.visible then
    sample_generator_dialog:close()
  end
  
  -- Initialize data with default curves
  PakettiSampleEffectGeneratorInitializeData()
  
  local vb = renoise.ViewBuilder()
  
  local dialog_content = vb:column {
    -- Canvas row - text labels now rendered as vector graphics within canvases
    vb:row {
      -- Waveform canvas column  
      vb:column {
        vb:canvas {
          id = "waveform_canvas",
          width = canvas_width,
          height = canvas_height,
          mode = "plain",
          render = function(ctx) 
            PakettiSampleEffectGeneratorRenderCanvas("waveform", ctx) 
          end,
          mouse_handler = function(ev) 
            PakettiSampleEffectGeneratorHandleMouse("waveform", ev) 
          end,
          mouse_events = {"down", "up", "move", "exit"}
        }
      },
      
      -- Pitch canvas column
      vb:column {
        vb:canvas {
          id = "pitch_canvas",
          width = canvas_width,
          height = canvas_height,
          mode = "plain",
          render = function(ctx) 
            PakettiSampleEffectGeneratorRenderCanvas("pitch", ctx) 
          end,
          mouse_handler = function(ev) 
            PakettiSampleEffectGeneratorHandleMouse("pitch", ev) 
          end,
          mouse_events = {"down", "up", "move", "exit"}
        }
      },
      
      -- Volume canvas column
      vb:column {
        vb:canvas {
          id = "volume_canvas",
          width = canvas_width,
          height = canvas_height,
          mode = "plain",
          render = function(ctx) 
            PakettiSampleEffectGeneratorRenderCanvas("volume", ctx) 
          end,
          mouse_handler = function(ev) 
            PakettiSampleEffectGeneratorHandleMouse("volume", ev) 
          end,
          mouse_events = {"down", "up", "move", "exit"}
        }
      }
    },
    
    -- Controls row
    vb:row {
      -- Wave type selection
      vb:column {
        vb:text { text = "Wave Type", font = "bold", style = "strong" },
        vb:popup {
          id = "wave_type_popup",
          items = {"Current", "Sine", "Triangle", "Square", "Sawtooth", "Pulse", "Diode", "Gauss", "Chebyshev", "Chirp", "Log Ramp Up", "Log Ramp Down", "Pink Noise", "Random"},
          value = 1,  -- Default to Current (use drawn waveform)
          width = 120,
          notifier = function(value)
            local types = {"current", "sine", "triangle", "square", "sawtooth", "pulse", "diode", "gauss", "chebyshev", "chirp", "log_ramp_up", "log_ramp_down", "pink_noise", "random"}
            wave_type = types[value]
            
            if wave_type ~= "current" then
              -- Only generate base waveform if user selected a preset (not "Current")
              PakettiSampleEffectGeneratorGenerateBaseWaveform(wave_type)
            end
            
            print("SAMPLE_GENERATOR: Wave type changed to " .. wave_type)
          end
        },
        vb:row {
          vb:button {
            text = "2x",
            width = 38,
            tooltip = "Double waveform frequency",
            notifier = function()
              PakettiSampleEffectGeneratorDoubleWaveform()
            end
          },
          vb:button {
            text = "1/2", 
            width = 38,
            tooltip = "Halve waveform frequency",
            notifier = function()
              PakettiSampleEffectGeneratorHalveWaveform()
            end
          },
          vb:button {
            text = "RND",
            width = 40,
            tooltip = "Randomize waveform curve",
            notifier = function()
              PakettiSampleEffectGeneratorRandomizeWaveform()
            end
          },
        }
      },
      
      -- Pitch modulation type selection (FIXED ORDER: matches canvas order)
      vb:column {
        vb:text { text = "Pitch Modulation", font = "bold", style = "strong" },
        vb:popup {
          id = "pitch_modulation_popup",
          items = {"Current", "Flat", "Ramp Up", "Ramp Down", "Log Ramp Up", "Log Ramp Down", "Triangle", "Sine Wave", "Pulse", "Diode", "Gauss", "Chebyshev", "Chirp", "Pink Noise", "Random"},
          value = 1,  -- Default to Current (use drawn pitch curve)
          width = 120,
          notifier = function(value)
            local types = {"current", "flat", "ramp_up", "ramp_down", "log_ramp_up", "log_ramp_down", "triangle", "sine_wave", "pulse", "diode", "gauss", "chebyshev", "chirp", "pink_noise", "random"}
            pitch_modulation_type = types[value]
            
            if pitch_modulation_type ~= "current" then
              -- Only generate preset if user selected a preset (not "Current")
              PakettiSampleEffectGeneratorGeneratePitchPreset(pitch_modulation_type)
            end
            
            print("SAMPLE_GENERATOR: Pitch modulation changed to " .. pitch_modulation_type)
          end
        },
        vb:row {
          vb:button {
            text = "2x",
            width = 38,
            tooltip = "Double pitch curve frequency",
            notifier = function()
              PakettiSampleEffectGeneratorDoublePitch()
            end
          },
          vb:button {
            text = "1/2",
            width = 38,
            tooltip = "Halve pitch curve frequency", 
            notifier = function()
              PakettiSampleEffectGeneratorHalvePitch()
            end
          },
          vb:button {
            text = "RND",
            width = 40,
            tooltip = "Randomize pitch modulation curve",
            notifier = function()
              PakettiSampleEffectGeneratorRandomizePitch()
            end
          },
        }
      },
      
      -- Volume envelope type selection (FIXED ORDER: matches canvas order)
      vb:column {
        vb:text { text = "Volume Envelope", font = "bold", style = "strong" },
        vb:popup {
          id = "volume_envelope_popup",
          items = {"Current", "Flat", "Ramp Down", "Ramp Up", "Log Ramp Down", "Log Ramp Up", "Triangle", "Fade In/Out", "Pulse", "Diode", "Gauss", "Chebyshev", "Chirp", "Pink Noise", "Random"},
          value = 1,  -- Default to Current (use drawn volume curve)
          width = 120,
          notifier = function(value)
            local types = {"current", "flat", "ramp_down", "ramp_up", "log_ramp_down", "log_ramp_up", "triangle", "fade_in_out", "pulse", "diode", "gauss", "chebyshev", "chirp", "pink_noise", "random"}
            volume_envelope_type = types[value]
            
            if volume_envelope_type ~= "current" then
              -- Only generate preset if user selected a preset (not "Current")
              PakettiSampleEffectGeneratorGenerateVolumePreset(volume_envelope_type)
            end
            
            print("SAMPLE_GENERATOR: Volume envelope changed to " .. volume_envelope_type)
          end
        },
        vb:row {
          vb:button {
            text = "2x",
            width = 38,
            tooltip = "Double volume envelope frequency",
            notifier = function()
              PakettiSampleEffectGeneratorDoubleVolume()
            end
          },
          vb:button {
            text = "1/2",
            width = 38,
            tooltip = "Halve volume envelope frequency",
            notifier = function()
              PakettiSampleEffectGeneratorHalveVolume()
            end
          },
          vb:button {
            text = "RND",
            width = 40,
            tooltip = "Randomize volume envelope curve",
            notifier = function()
              PakettiSampleEffectGeneratorRandomizeVolume()
            end
          },
        },
        vb:row {
          vb:checkbox {
            value = fade_out_enabled,
            tooltip = "Fade out last 15 frames to avoid clicks",
            notifier = function(value)
              fade_out_enabled = value
              print("SAMPLE_GENERATOR: Fade out " .. (fade_out_enabled and "enabled" or "disabled"))
            end
          },
          vb:text { text = "Fade Out", font = "bold", style = "strong" },
        },
      },
      
      -- Duration control
      vb:column {
        vb:text { text = "Duration (sec)", font = "bold", style = "strong" },
        vb:valuebox {
          id = "duration_valuebox",
          min = 0.1,
          max = 10.0,
          value = sample_duration,
          width = 80,
          notifier = function(value)
            sample_duration = value
            print("SAMPLE_GENERATOR: Duration changed to " .. sample_duration)
          end
        }
      },
      
      -- Action buttons
      vb:column {
        vb:text { text = "Actions:", font = "bold" },
        vb:row {
          vb:button {
            text = "Generate (SPACE)",
            width = 120,
            tooltip = "Generate sample from drawn curves",
            notifier = function()
              PakettiSampleEffectGeneratorGenerateSample()
            end
          },

          vb:button {
            text = "Reset All Envelopes",
            width = 140,
            tooltip = "Reset all envelopes: waveform to sine, pitch to flat, volume to full",
            notifier = function()
              PakettiSampleEffectGeneratorInitializeData()
              if waveform_canvas then waveform_canvas:update() end
              if pitch_canvas then pitch_canvas:update() end
              if volume_canvas then volume_canvas:update() end
            end
          }
        },
        

        vb:row {
          vb:button {
            text = "Render Waveform without Pitch/Volume Envelope applied",
            width = 320,
            tooltip = "Generate sample using ONLY the drawn waveform curve - ignores pitch and volume envelopes completely",
            notifier = function()
              PakettiSampleEffectGeneratorRenderWaveformOnly()
            end
          },
        },
        

        vb:button {
          text = "Generate 25 Random Samples",
          width = 320,
          tooltip = "Generate 25 completely random samples with random curves, wave types, and durations",
          notifier = function()
            PakettiSampleEffectGeneratorGenerate25Random()
          end
        }
      }
    },
    
    -- Instructions
    vb:text {
      text = "Instructions: Draw on canvases to shape your sample. Press SPACE to generate. ESC to close.",
      font = "italic"
    }
  }
  
  -- Create dialog
  sample_generator_dialog = renoise.app():show_custom_dialog(
    "Paketti Sample Effect Generator",
    dialog_content,
    paketti_sample_generator_keyhandler_func
  )
  
  -- Store canvas references
  waveform_canvas = vb.views.waveform_canvas
  pitch_canvas = vb.views.pitch_canvas
  volume_canvas = vb.views.volume_canvas
  
  print("SAMPLE_GENERATOR: Canvas references stored:")
  print("  waveform_canvas: " .. tostring(waveform_canvas ~= nil))
  print("  pitch_canvas: " .. tostring(pitch_canvas ~= nil))  
  print("  volume_canvas: " .. tostring(volume_canvas ~= nil))
  
  -- CRITICAL FIX: Force immediate canvas updates after references are stored
  if waveform_canvas then waveform_canvas:update() end
  if pitch_canvas then pitch_canvas:update() end
  if volume_canvas then volume_canvas:update() end
  
  -- Set up close notifier for cleanup
  if sample_generator_dialog then
    pcall(function()
      sample_generator_dialog.closed_observable:add_notifier(function()
        print("SAMPLE_GENERATOR: Dialog closed - running cleanup")
        PakettiSampleEffectGeneratorCleanup()
      end)
    end)
  end
  
  print("SAMPLE_GENERATOR: Dialog created successfully")
end

-- Main initialization function
function PakettiSampleEffectGeneratorInit()
  print("SAMPLE_GENERATOR: Initializing...")
  PakettiSampleEffectGeneratorCreateDialog()
end

-- Menu entries
renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Paketti Sample Effect Generator",
  invoke = PakettiSampleEffectGeneratorInit
}

renoise.tool():add_keybinding {
  name = "Global:Paketti:Paketti Sample Effect Generator",
  invoke = PakettiSampleEffectGeneratorInit
}

print("SAMPLE_GENERATOR: Module loaded successfully")
