-- PakettiSampleEffectGenerator.lua
-- Canvas-based Sample Effect Generator
-- Draw waveform, pitch modulation, and volume envelope to generate custom samples

local vb = renoise.ViewBuilder()

-- Canvas dimensions - 3 pixels wider and taller for better rendering
local canvas_width = 463   -- 3 pixels wider
local canvas_height = 183  -- 3 pixels taller
local text_height = 14     -- Space for vector text with proper spacing
local text_margin = 6      -- Space between text and drawing area (lifted by 2 pixels as requested)
local border_margin = 6    -- Grey rectangle border margin  
local internal_padding = 10 -- INTERNAL padding so waveforms don't get clipped at edges
local content_width = canvas_width - (border_margin * 2) - (internal_padding * 2)  -- Smaller drawing area
local content_height = canvas_height - text_height - text_margin - border_margin - (internal_padding * 2)  -- Smaller drawing area
local content_x = border_margin + internal_padding  -- Start inside the border + padding
local content_y = text_height + text_margin + internal_padding  -- Start below text + padding

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

-- Unified dropdown items for all canvases (DRY principle)
local UNIFIED_DROPDOWN_ITEMS = {"Current", "Sine", "Triangle", "Square", "Sawtooth", "Flat", "Ramp Up", "Ramp Down", "Log Ramp Up", "Log Ramp Down", "Pulse", "Diode", "Gauss", "Chebyshev", "Chirp", "Pink Noise", "Random", "Random Stairs"}
local UNIFIED_DROPDOWN_TYPES = {"current", "sine", "triangle", "square", "sawtooth", "flat", "ramp_up", "ramp_down", "log_ramp_up", "log_ramp_down", "pulse", "diode", "gauss", "chebyshev", "chirp", "pink_noise", "random", "random_stairs"}

-- Pitch-specific dropdown items (includes octave steps)
local PITCH_DROPDOWN_ITEMS = {"Current", "Sine", "Triangle", "Square", "Sawtooth", "Flat", "Ramp Up", "Ramp Down", "Log Ramp Up", "Log Ramp Down", "1 Octave Steps", "2 Octave Steps", "Pulse", "Diode", "Gauss", "Chebyshev", "Chirp", "Pink Noise", "Random", "Random Stairs"}
local PITCH_DROPDOWN_TYPES = {"current", "sine", "triangle", "square", "sawtooth", "flat", "ramp_up", "ramp_down", "log_ramp_up", "log_ramp_down", "octave_steps_1", "octave_steps_2", "pulse", "diode", "gauss", "chebyshev", "chirp", "pink_noise", "random", "random_stairs"}

-- Sample generation settings
local sample_duration = 2.0  -- Default 2.0 seconds
local sample_rate = 44100
local wave_type = "current"
local volume_envelope_type = "current"
local pitch_modulation_type = "current"

-- Live pickup mode settings (similar to PakettiPCMWriter)
local live_pickup_mode = false
local live_pickup_sample = nil
local live_pickup_instrument = nil
local live_pickup_sample_index = -1
local live_pickup_instrument_index = -1
local use_waveform_override = false  -- If true, use drawn waveform as base wave instead of dropdown selection
local fade_out_enabled = true  -- If true, apply fade out to last 1000 frames (0.023s) to avoid clicks - ends at ZERO
local beatsync_enabled = true  -- If true, enable beatsync with 32 lines and Stretch-Texture mode

-- Tuning settings (from PakettiPCMWriter.lua)
local A4_FREQ = 440.0  -- A4 reference frequency
local tuned_resolution = 100  -- Auto-calculated for perfect A440 tuning

-- Normalize waveform curve to full 0.0-1.0 range
function PakettiSampleEffectGeneratorNormalizeWaveform()
  local min_val = 999
  local max_val = -999
  
  -- Find min and max values
  for i = 1, #waveform_data do
    min_val = math.min(min_val, waveform_data[i])
    max_val = math.max(max_val, waveform_data[i])
  end
  
  -- Avoid division by zero
  if max_val == min_val then
    print("WAVEFORM_NORMALIZE: All values are the same (" .. string.format("%.3f", min_val) .. "), nothing to normalize")
    return
  end
  
  local range = max_val - min_val
  print("WAVEFORM_NORMALIZE: Original range: " .. string.format("%.3f", min_val) .. " to " .. string.format("%.3f", max_val) .. " (range: " .. string.format("%.3f", range) .. ")")
  
  -- Normalize to 0.0-1.0 range
  for i = 1, #waveform_data do
    waveform_data[i] = (waveform_data[i] - min_val) / range
  end
  
  if waveform_canvas then waveform_canvas:update() end
  if live_pickup_mode then
    PakettiSampleEffectGeneratorUpdateLiveSample()
  end
  print("WAVEFORM_NORMALIZE: Normalized to full 0.0-1.0 range")
end

-- Normalize pitch curve to full 0.0-1.0 range
function PakettiSampleEffectGeneratorNormalizePitch()
  local min_val = 999
  local max_val = -999
  
  -- Find min and max values
  for i = 1, #pitch_data do
    min_val = math.min(min_val, pitch_data[i])
    max_val = math.max(max_val, pitch_data[i])
  end
  
  -- Avoid division by zero
  if max_val == min_val then
    print("PITCH_NORMALIZE: All values are the same (" .. string.format("%.3f", min_val) .. "), nothing to normalize")
    return
  end
  
  local range = max_val - min_val
  print("PITCH_NORMALIZE: Original range: " .. string.format("%.3f", min_val) .. " to " .. string.format("%.3f", max_val) .. " (range: " .. string.format("%.3f", range) .. ")")
  
  -- Normalize to 0.0-1.0 range
  for i = 1, #pitch_data do
    pitch_data[i] = (pitch_data[i] - min_val) / range
  end
  
  if pitch_canvas then pitch_canvas:update() end
  if live_pickup_mode then
    PakettiSampleEffectGeneratorUpdateLiveSample()
  end
  print("PITCH_NORMALIZE: Normalized to full 0.0-1.0 range")
end

-- Normalize volume curve to full 0.0-1.0 range
function PakettiSampleEffectGeneratorNormalizeVolume()
  local min_val = 999
  local max_val = -999
  
  -- Find min and max values
  for i = 1, #volume_data do
    min_val = math.min(min_val, volume_data[i])
    max_val = math.max(max_val, volume_data[i])
  end
  
  -- Avoid division by zero
  if max_val == min_val then
    print("VOLUME_NORMALIZE: All values are the same (" .. string.format("%.3f", min_val) .. "), nothing to normalize")
    return
  end
  
  local range = max_val - min_val
  print("VOLUME_NORMALIZE: Original range: " .. string.format("%.3f", min_val) .. " to " .. string.format("%.3f", max_val) .. " (range: " .. string.format("%.3f", range) .. ")")
  
  -- Normalize to 0.0-1.0 range
  for i = 1, #volume_data do
    volume_data[i] = (volume_data[i] - min_val) / range
  end
  
  if volume_canvas then volume_canvas:update() end
  if live_pickup_mode then
    PakettiSampleEffectGeneratorUpdateLiveSample()
  end
  print("VOLUME_NORMALIZE: Normalized to full 0.0-1.0 range")
end

-- Debug function to diagnose pitch canvas issues
function PakettiSampleEffectGeneratorDebugPitchCanvas()
  print("PITCH DEBUG: ======== PITCH CANVAS DIAGNOSTIC ========")
  print("PITCH DEBUG: pitch_canvas reference: " .. tostring(pitch_canvas ~= nil))
  print("PITCH DEBUG: pitch_data array length: " .. #pitch_data)
  print("PITCH DEBUG: pitch_modulation_type: " .. tostring(pitch_modulation_type))
  print("PITCH DEBUG: pitch_frequency_multiplier: " .. tostring(pitch_frequency_multiplier))
  
  -- Show first few values of pitch_data
  print("PITCH DEBUG: First 5 pitch_data values:")
  for i = 1, math.min(5, #pitch_data) do
    print("  pitch_data[" .. i .. "] = " .. string.format("%.3f", pitch_data[i]))
  end
  
  -- Check mouse tracking state
  local tracking = mouse_tracking["pitch"]
  print("PITCH DEBUG: Mouse tracking state:")
  print("  is_down: " .. tostring(tracking.is_down))
  print("  last_x: " .. tostring(tracking.last_x))
  print("  last_y: " .. tostring(tracking.last_y))
  print("  last_index: " .. tostring(tracking.last_index))
  
  -- Force canvas update
  if pitch_canvas then
    print("PITCH DEBUG: Forcing pitch canvas update...")
    pitch_canvas:update()
    print("PITCH DEBUG: Canvas update complete")
  else
    print("PITCH DEBUG: ERROR - pitch_canvas is nil!")
  end
  
  -- Try to regenerate pitch preset
  print("PITCH DEBUG: Regenerating current pitch preset: " .. tostring(pitch_modulation_type))
  PakettiSampleEffectGeneratorGeneratePitchPreset(pitch_modulation_type)
  
  print("PITCH DEBUG: ======== END DIAGNOSTIC ========")
end

-- Turn off beatsync for the currently selected sample
function PakettiSampleEffectGeneratorTurnOffBeatSync()
  local song = renoise.song()
  local inst = song.selected_instrument
  
  if not inst or song.selected_sample_index == 0 then
    renoise.app():show_status("No sample selected")
    return
  end
  
  local sample = inst:sample(song.selected_sample_index)
  if not sample then
    renoise.app():show_status("No sample found at selected index")
    return
  end
  
  -- Turn off beatsync
  sample.beat_sync_enabled = false
  
  renoise.app():show_status("Beatsync disabled for selected sample")
  print("SAMPLE_GENERATOR: Beatsync disabled for sample " .. song.selected_sample_index .. " in instrument " .. song.selected_instrument_index)
end

-- Calculate perfect waveform resolution for A440Hz tuning
function PakettiSampleEffectGeneratorCalculateTunedResolution()
  -- Calculate samples per cycle at A440Hz
  local samples_per_cycle = sample_rate / A4_FREQ  -- ~100.227 samples at 44100Hz/440Hz
  
  -- Round to nearest integer for waveform resolution
  tuned_resolution = math.floor(samples_per_cycle + 0.5)
  
  -- Clamp to reasonable range (50-200 points)
  tuned_resolution = math.max(50, math.min(200, tuned_resolution))
  
  print("TUNING: Calculated tuned resolution for A440Hz: " .. tuned_resolution .. " points (exact: " .. string.format("%.3f", samples_per_cycle) .. ")")
  
  -- Update UI display if it exists
  PakettiSampleEffectGeneratorUpdateTuningDisplay()
  
  return tuned_resolution
end

-- Update the tuning display in the UI
function PakettiSampleEffectGeneratorUpdateTuningDisplay()
  if vb and vb.views.tuning_text then
    vb.views.tuning_text.text = tuned_resolution .. " pts"
  end
end

-- Frequency to note analysis (from PakettiPCMWriter.lua)
function PakettiSampleEffectGeneratorFrequencyToNoteAnalysis(frequency)
  local A4 = 440.0
  local A4_INDEX = 57
  
  local notes = {
    "C0","C#0","D0","D#0","E0","F0","F#0","G0","G#0","A0","A#0","B0",
    "C1","C#1","D1","D#1","E1","F1","F#1","G1","G#1","A1","A#1","B1",
    "C2","C#2","D2","D#2","E2","F2","F#2","G2","G#2","A2","A#2","B2",
    "C3","C#3","D3","D#3","E3","F3","F#3","G3","G#3","A3","A#3","B3",
    "C4","C#4","D4","D#4","E4","F4","F#4","G4","G#4","A4","A#4","B4",
    "C5","C#5","D5","D#5","E5","F5","F#5","G5","G#5","A5","A#5","B5",
    "C6","C#6","D6","D#6","E6","F6","F#6","G6","G#6","A6","A#6","B6",
    "C7","C#7","D7","D#7","E7","F7","F#7","G7","G#7","A7","A#7","B7",
    "C8","C#8","D8","D#8","E8","F8","F#8","G8","G#8","A8","A#8","B8",
    "C9","C#9","D9","D#9","E9","F9","F#9","G9","G#9","A9","A#9","B9"
  }
  
  local r = 1.059463094359295264  -- 2^(1/12)
  local cent = 1.0005777895065549  -- 2^(1/1200)
  local MINUS, PLUS = 0, 1
  
  local r_index = 1
  local cent_index = 0
  local side
  local working_freq = A4
  
  if frequency >= working_freq then
    -- Higher than or equal to A4
    while frequency >= r * working_freq do
      working_freq = r * working_freq
      r_index = r_index + 1
    end
    while frequency > cent * working_freq do
      working_freq = cent * working_freq
      cent_index = cent_index + 1
    end
    if (cent * working_freq - frequency) < (frequency - working_freq) then
      cent_index = cent_index + 1
    end
    if cent_index > 50 then
      cent_index = cent_index - 100
      r_index = r_index + 1
    end
    side = PLUS
  else
    -- Lower than A4
    while frequency <= working_freq / r do
      working_freq = working_freq / r
      r_index = r_index - 1
    end
    while frequency < working_freq / cent do
      working_freq = working_freq / cent
      cent_index = cent_index + 1
    end
    if (frequency - working_freq / cent) < (working_freq - frequency) then
      cent_index = cent_index + 1
    end
    if cent_index >= 50 then
      cent_index = cent_index - 100
      r_index = r_index - 1
    end
    side = MINUS
  end
  
  -- Calculate MIDI note number
  local midi_note = A4_INDEX + r_index - 1
  
  -- Get note name
  local note_name = "C4"
  if midi_note >= 0 and midi_note < #notes then
    note_name = notes[midi_note + 1]
  end
  
  return {
    midi_note = midi_note,
    note_name = note_name,
    cents = cent_index,
    side = side
  }
end

-- Calculate pitch correction (from PakettiPCMWriter.lua)  
function PakettiSampleEffectGeneratorCalculatePitchCorrection(sample_rate, wave_length_frames, cycles)
  cycles = cycles or 1
  
  -- Calculate frequency from wave data
  local freq = sample_rate / (wave_length_frames / cycles)
  
  -- Analyze the frequency
  local result = PakettiSampleEffectGeneratorFrequencyToNoteAnalysis(freq)
  
  -- Calculate pitch correction values
  local midi_note = result.midi_note + 12  -- Convert to standard MIDI system (C4=60)
  local target_note = 60  -- C4
  local diff = midi_note - target_note
  local transpose_value = -diff
  transpose_value = math.max(-120, math.min(120, transpose_value))
  
  -- Calculate fine tune correction (negate to correct the detected deviation)
  local cents_value = -result.cents
  local fine_tune_steps = math.floor(cents_value * 1.275 + 0.5)  -- Scale: 255 steps / 200 cents = 1.275
  fine_tune_steps = math.max(-128, math.min(127, fine_tune_steps))
  
  return {
    frequency = freq,
    note_name = result.note_name,
    midi_note = midi_note,
    cents = result.cents,
    transpose = transpose_value,
    fine_tune = fine_tune_steps,
    cent_direction = result.side == 0 and "minus" or "plus"
  }
end

-- Frequency multipliers for mathematical regeneration
local volume_frequency_multiplier = 1
local pitch_frequency_multiplier = 1
local waveform_frequency_multiplier = 1

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
  
  -- Calculate tuned resolution for perfect A440Hz
  local resolution = PakettiSampleEffectGeneratorCalculateTunedResolution()
  
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
  
  print("SAMPLE_GENERATOR: FIXED PITCH PRESETS - Now using full 0.0-1.0 range!")
end

-- Generate pitch modulation preset
function PakettiSampleEffectGeneratorGeneratePitchPreset(preset_type)
  -- ALWAYS reset frequency multiplier when changing dropdown selection (including "current")
  pitch_frequency_multiplier = 1
  print("PITCH PRESET: Reset frequency multiplier to 1x")
  
  -- Skip if "current" - preserve whatever is drawn
  if preset_type == "current" then
    return
  end
  
  print("PITCH PRESET: Generating '" .. preset_type .. "' preset")
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
      if i <= 5 or i >= resolution - 4 then
        print("  ORIGINAL pitch[" .. i .. "] = " .. string.format("%.3f", pitch_value) .. " (x_norm=" .. string.format("%.3f", x_norm) .. ")")
      end
    elseif preset_type == "octave_steps_1" then
      -- 1 Octave steps: 0, +12, 0, -12, 0, +12, 0, -12 (±1 octave range)
      local step_count = math.floor(x_norm * 4) % 4  -- 4-step pattern repeating
      if step_count == 0 then
        pitch_value = 0.5   -- 0 semitones (no change)
      elseif step_count == 1 then
        pitch_value = 0.75  -- +12 semitones (+1 octave)
      elseif step_count == 2 then
        pitch_value = 0.5   -- 0 semitones (no change)
      else  -- step_count == 3
        pitch_value = 0.25  -- -12 semitones (-1 octave)
      end
    elseif preset_type == "octave_steps_2" then
      -- 2 Octave steps: 0, +12, +24, +12, 0, -12, -24, -12 (±2 octave range)
      local step_count = math.floor(x_norm * 8) % 8  -- 8-step pattern repeating
      if step_count == 0 then
        pitch_value = 0.5   -- 0 semitones (no change)
      elseif step_count == 1 then
        pitch_value = 0.75  -- +12 semitones (+1 octave)
      elseif step_count == 2 then
        pitch_value = 1.0   -- +24 semitones (+2 octaves)
      elseif step_count == 3 then
        pitch_value = 0.75  -- +12 semitones (+1 octave)
      elseif step_count == 4 then
        pitch_value = 0.5   -- 0 semitones (no change)
      elseif step_count == 5 then
        pitch_value = 0.25  -- -12 semitones (-1 octave)
      elseif step_count == 6 then
        pitch_value = 0.0   -- -24 semitones (-2 octaves)
      else  -- step_count == 7
        pitch_value = 0.25  -- -12 semitones (-1 octave)
      end
    elseif preset_type == "triangle" then
      if x_norm < 0.5 then
        pitch_value = x_norm * 2  -- Ramp up from 0.0 to 1.0
      else
        pitch_value = 2.0 - (x_norm * 2)  -- Ramp down from 1.0 to 0.0
      end
    elseif preset_type == "square" then
      pitch_value = (math.sin(x_norm * math.pi * 2) > 0) and 1.0 or 0.0  -- Square wave
    elseif preset_type == "sawtooth" then
      pitch_value = x_norm  -- Linear ramp 0.0 to 1.0
    elseif preset_type == "sine" then
      pitch_value = 0.5 + math.sin(x_norm * math.pi * 2) * 0.5  -- Sine wave oscillation (1 cycle, full range)
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
    elseif preset_type == "random_stairs" then
      -- Random stairs - every 10 steps has the same random value
      local step_size = 10
      local step_index = math.floor((i - 1) / step_size)
      -- Generate consistent random value for this step group
      math.randomseed(12345 + step_index)  -- Simple seed per step group
      pitch_value = math.random()
      math.randomseed(os.time())  -- Reset to time-based seed
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
  -- ALWAYS reset frequency multiplier when changing dropdown selection (including "current")
  volume_frequency_multiplier = 1
  print("VOLUME PRESET: Reset frequency multiplier to 1x")
  
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
    elseif preset_type == "square" then
      volume_value = (math.sin(x_norm * math.pi * 2) > 0) and 1.0 or 0.0  -- Square wave
    elseif preset_type == "sawtooth" then
      volume_value = x_norm  -- Linear ramp 0.0 to 1.0
    elseif preset_type == "sine" then
      volume_value = 0.5 + math.sin(x_norm * math.pi * 2) * 0.5  -- Sine wave oscillation (1 cycle, full range)
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
    elseif preset_type == "random_stairs" then
      -- Random stairs - every 10 steps has the same random value
      local step_size = 10
      local step_index = math.floor((i - 1) / step_size)
      -- Generate consistent random value for this step group
      math.randomseed(54321 + step_index)  -- Different base seed for volume
      volume_value = math.random()
      math.randomseed(os.time())  -- Reset to time-based seed
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
  -- Reset frequency multiplier when generating new preset
  waveform_frequency_multiplier = 1
  
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
    elseif waveform_type == "random_stairs" then
      -- Random stairs - every 10 steps has the same random value
      local step_size = 10
      local step_index = math.floor((i - 1) / step_size)
      -- Generate consistent random value for this step group
      math.randomseed(98765 + step_index)  -- Different base seed for waveform
      wave_value = math.random()
      math.randomseed(os.time())  -- Reset to time-based seed
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
  
  print("SAMPLE_GENERATOR: Rendering waveform ONLY (no pitch/volume envelopes) with A440Hz tuning")
  
  -- Calculate sample properties
  local total_samples = math.floor(sample_duration * sample_rate)
  local sample_data = {}
  
  print("SAMPLE_GENERATOR: Duration=" .. sample_duration .. "s, Samples=" .. total_samples)
  print("SAMPLE_GENERATOR: Using ONLY drawn waveform curve (ignoring pitch and volume)")
  print("SAMPLE_GENERATOR: Waveform resolution: " .. tuned_resolution .. " points (A440Hz tuned)")
  
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
    -- Apply fade out if enabled (proper fadeout to zero) - always apply in waveform-only mode
    if fade_out_enabled then
      local fade_frames = 1000  -- Longer fade to zero (about 0.023 seconds)
      if sample_i > (total_samples - fade_frames) then
        local fade_pos = sample_i - (total_samples - fade_frames)
        local fade_mult = 1.0 - (fade_pos / fade_frames)  -- 1.0 to 0.0
        wave_sample = wave_sample * fade_mult
        -- Ensure the very last sample is exactly zero
        if sample_i == total_samples then
          wave_sample = 0.0
        end
      end
    end
    
    -- Store sample (clamp to -1.0 to 1.0 range)
    sample_data[sample_i] = math.max(-1.0, math.min(1.0, wave_sample))
  end
  
  -- Create and load sample using PakettiSamples functions
  PakettiSampleEffectGeneratorCreateAndLoadSample(sample_data, sample_rate)
  
  print("SAMPLE_GENERATOR: A440Hz tuned waveform-only sample generation complete!")
  renoise.app():show_status("Generated " .. sample_duration .. "s A440Hz tuned sample using ONLY waveform curve")
end

-- UNIFIED 2X DOUBLING FUNCTION - TRUE "GENERATE ONCE + FLOOD FILL" FOR PERFECT PRECISION!
function PakettiSampleEffectGeneratorDouble2X(preset_type, data_array, frequency_multiplier, envelope_name)
  local resolution = #data_array
  
  print(envelope_name .. "_DOUBLE: FLOOD FILL APPROACH at " .. frequency_multiplier .. "x frequency")
  
  -- ALWAYS treat current data as custom curve to preserve user drawings
  -- This ensures that if user drew on top of a preset, we double the drawn curve, not regenerate the preset
  print("  ALWAYS using custom curve approach to preserve user drawings")
  
  if true then
    -- CUSTOM CURVE: Compress the full curve and repeat it at higher frequency
    print("  Custom curve '" .. preset_type .. "' - compressing full curve and repeating")
    
    if #data_array > 0 then
      -- Save the original full curve (this is one complete cycle as drawn by user)
      local original_curve = {}
      for i = 1, #data_array do
        original_curve[i] = data_array[i]
      end
      
      -- Now generate the new frequency by treating the original as one cycle
      for i = 1, resolution do
        local x_norm = (i - 1) / resolution  -- 0.0 to just before 1.0
        local cycle_pos = (x_norm * frequency_multiplier) % 1  -- Apply frequency multiplication
        
        -- Interpolate from the original curve at this cycle position
        local original_index = cycle_pos * (#original_curve - 1) + 1
        local lower_index = math.floor(original_index)
        local upper_index = math.ceil(original_index)
        local fraction = original_index - lower_index
        
        -- Clamp indices
        lower_index = math.max(1, math.min(#original_curve, lower_index))
        upper_index = math.max(1, math.min(#original_curve, upper_index))
        
        -- Linear interpolation
        local value
        if lower_index == upper_index then
          value = original_curve[lower_index]
        else
          local val1 = original_curve[lower_index]
          local val2 = original_curve[upper_index]
          value = val1 + (val2 - val1) * fraction
        end
        
        data_array[i] = value
      end
    else
      -- If no data exists, create a flat line
      for i = 1, resolution do
        data_array[i] = 0.5
      end
    end
  -- REMOVED: Old mathematical preset regeneration code (was causing loss of user drawings)
  end
  
  return true  -- Signal successful regeneration
end

-- Double the frequency of waveform (increase octave) - REFACTORED FOR DRY
function PakettiSampleEffectGeneratorDoubleWaveform()
  -- Prevent frequency multiplier from becoming too extreme
  if waveform_frequency_multiplier >= 32 then
    print("WAVEFORM_DOUBLE: WARNING - Frequency multiplier limit reached (" .. waveform_frequency_multiplier .. "x) - ignoring 2X request")
    renoise.app():show_status("Waveform frequency limit reached!")
    return
  end
  
  waveform_frequency_multiplier = waveform_frequency_multiplier * 2
  
  -- ALWAYS treat as custom curve to preserve user drawings (ignore preset_type variable)
  PakettiSampleEffectGeneratorDouble2X("current", waveform_data, waveform_frequency_multiplier, "WAVEFORM")
  
  if waveform_canvas then waveform_canvas:update() end
  if live_pickup_mode then
    PakettiSampleEffectGeneratorUpdateLiveSample()
  end
  print("SAMPLE_GENERATOR: DRY - Waveform frequency now " .. waveform_frequency_multiplier .. "x!")
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
  print("SAMPLE_GENERATOR: PRISTINE - Halved waveform frequency (2 cycles → 1 cycle) - PERFECT INVERSE!")
  print("SAMPLE_GENERATOR: Using PERFECT integer sampling - reversible operations!")
end

-- Double the frequency of pitch curve (increase octave) - MATHEMATICAL REGENERATION
function PakettiSampleEffectGeneratorDoublePitch()
  -- Prevent frequency multiplier from becoming too extreme
  if pitch_frequency_multiplier >= 32 then
    print("PITCH_DOUBLE: WARNING - Frequency multiplier limit reached (" .. pitch_frequency_multiplier .. "x) - ignoring 2X request")
    renoise.app():show_status("Pitch frequency limit reached!")
    return
  end
  
  pitch_frequency_multiplier = pitch_frequency_multiplier * 2
  
  -- ALWAYS treat as custom curve to preserve user drawings (ignore preset_type variable)
  PakettiSampleEffectGeneratorDouble2X("current", pitch_data, pitch_frequency_multiplier, "PITCH")
  
  if pitch_canvas then pitch_canvas:update() end
  if live_pickup_mode then
    PakettiSampleEffectGeneratorUpdateLiveSample()
  end
  print("SAMPLE_GENERATOR: DRY - Pitch frequency now " .. pitch_frequency_multiplier .. "x!")
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
  print("SAMPLE_GENERATOR: PRISTINE - Halved pitch curve frequency (2 cycles → 1 cycle) - PERFECT INVERSE!")
  print("SAMPLE_GENERATOR: Using PERFECT integer sampling - reversible operations!")
end

-- Double the frequency of volume envelope (increase octave) - MATHEMATICAL REGENERATION
function PakettiSampleEffectGeneratorDoubleVolume()
  -- Prevent frequency multiplier from becoming too extreme
  if volume_frequency_multiplier >= 32 then
    print("VOLUME_DOUBLE: WARNING - Frequency multiplier limit reached (" .. volume_frequency_multiplier .. "x) - ignoring 2X request")
    renoise.app():show_status("Volume frequency limit reached!")
    return
  end
  
  volume_frequency_multiplier = volume_frequency_multiplier * 2
  
  -- ALWAYS treat as custom curve to preserve user drawings (ignore preset_type variable)
  PakettiSampleEffectGeneratorDouble2X("current", volume_data, volume_frequency_multiplier, "VOLUME")
  
  if volume_canvas then volume_canvas:update() end
  if live_pickup_mode then
    PakettiSampleEffectGeneratorUpdateLiveSample()
  end
  print("SAMPLE_GENERATOR: DRY - Volume frequency now " .. volume_frequency_multiplier .. "x!")
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
  print("SAMPLE_GENERATOR: PRISTINE - Halved volume envelope frequency (2 cycles → 1 cycle) - PERFECT INVERSE!")
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

-- Invert waveform data
function PakettiSampleEffectGeneratorInvertWaveform()
  local resolution = #waveform_data
  for i = 1, resolution do
    waveform_data[i] = 1.0 - waveform_data[i]  -- Invert 0.0 to 1.0
  end
  if waveform_canvas then 
    waveform_canvas:update()
    print("SAMPLE_GENERATOR: Updated waveform canvas")
  else
    print("SAMPLE_GENERATOR: WARNING - waveform_canvas is nil!")
  end
  print("SAMPLE_GENERATOR: Inverted waveform")
  -- Update live sample if live audition is enabled
  if live_pickup_mode then
    PakettiSampleEffectGeneratorUpdateLiveSample()
  end
end

-- Invert pitch data
function PakettiSampleEffectGeneratorInvertPitch()
  local resolution = #pitch_data
  for i = 1, resolution do
    pitch_data[i] = 1.0 - pitch_data[i]  -- Invert 0.0 to 1.0
  end
  if pitch_canvas then 
    pitch_canvas:update()
    print("SAMPLE_GENERATOR: Updated pitch canvas")
  else
    print("SAMPLE_GENERATOR: WARNING - pitch_canvas is nil!")
  end
  print("SAMPLE_GENERATOR: Inverted pitch")
  -- Update live sample if live audition is enabled
  if live_pickup_mode then
    PakettiSampleEffectGeneratorUpdateLiveSample()
  end
end

-- Invert volume data
function PakettiSampleEffectGeneratorInvertVolume()
  local resolution = #volume_data
  for i = 1, resolution do
    volume_data[i] = 1.0 - volume_data[i]  -- Invert 0.0 to 1.0
  end
  if volume_canvas then 
    volume_canvas:update()
    print("SAMPLE_GENERATOR: Updated volume canvas")
  else
    print("SAMPLE_GENERATOR: WARNING - volume_canvas is nil!")
  end
  print("SAMPLE_GENERATOR: Inverted volume")
  -- Update live sample if live audition is enabled
  if live_pickup_mode then
    PakettiSampleEffectGeneratorUpdateLiveSample()
  end
end

-- Global slicer reference for 25 random samples
local random_samples_slicer = nil

-- Generate 25 random samples using ProcessSlicer
function PakettiSampleEffectGeneratorGenerate25Random()
  print("SAMPLE_GENERATOR: Starting 25 random sample generation with A440Hz tuning...")
  
  -- Create and start the process slicer
  random_samples_slicer = ProcessSlicer(PakettiSampleEffectGeneratorGenerate25RandomProcess)
  random_samples_slicer:start()
end

-- ProcessSlicer function for generating 25 random samples
function PakettiSampleEffectGeneratorGenerate25RandomProcess()
  local dialog, vb = random_samples_slicer:create_dialog("Generating 25 Random Samples")
  
  -- Sensible dropdown options (excluding "current" and limiting "random")
  local waveform_options = {"sine", "triangle", "square", "sawtooth", "flat", "ramp_up", "ramp_down", "log_ramp_up", "log_ramp_down", "pulse", "diode", "gauss", "chebyshev", "chirp", "pink_noise", "random_stairs"}
  local pitch_options = {"sine", "triangle", "square", "sawtooth", "flat", "ramp_up", "ramp_down", "log_ramp_up", "log_ramp_down", "octave_steps_1", "octave_steps_2", "pulse", "diode", "gauss", "chebyshev", "chirp", "pink_noise", "random_stairs"}
  local volume_options = {"sine", "triangle", "square", "sawtooth", "flat", "ramp_up", "ramp_down", "log_ramp_up", "log_ramp_down", "pulse", "diode", "gauss", "chebyshev", "chirp", "pink_noise", "random_stairs"}
  
  local random_count = 0  -- Track how many "random random random" we've used
  local max_random = 5    -- Maximum allowed random chaos samples
  
  for sample_num = 1, 25 do
    -- Check for cancellation
    if random_samples_slicer:was_cancelled() then
      print("SAMPLE_GENERATOR: Generation cancelled by user")
      break
    end
    
    -- Update progress
    vb.views.progress_text.text = "Generating sample " .. sample_num .. "/25..."
    print("SAMPLE_GENERATOR: Generating sample " .. sample_num .. "/25 (tuned resolution: " .. tuned_resolution .. " pts)")
    
    -- Decide if this should be a "random chaos" sample (max 5 out of 25)
    local use_random_chaos = (random_count < max_random) and (math.random() < 0.3)  -- 30% chance if under limit
    
    if use_random_chaos then
      -- RANDOM CHAOS mode - completely random curves
      print("SAMPLE_GENERATOR: Using RANDOM CHAOS mode for sample " .. sample_num)
      PakettiSampleEffectGeneratorRandomizeWaveform()
      PakettiSampleEffectGeneratorRandomizePitch() 
      PakettiSampleEffectGeneratorRandomizeVolume()
      wave_type = "random"
      pitch_modulation_type = "random"
      volume_envelope_type = "random"
      random_count = random_count + 1
    else
      -- SENSIBLE mode - pick from dropdown presets
      local wave_choice = waveform_options[math.random(1, #waveform_options)]
      local pitch_choice = pitch_options[math.random(1, #pitch_options)]
      local volume_choice = volume_options[math.random(1, #volume_options)]
      
      print("SAMPLE_GENERATOR: Using SENSIBLE mode: " .. wave_choice .. " + " .. pitch_choice .. " + " .. volume_choice)
      
      -- Generate presets instead of random curves
      wave_type = wave_choice
      pitch_modulation_type = pitch_choice  
      volume_envelope_type = volume_choice
      
      PakettiSampleEffectGeneratorGenerateBaseWaveform(wave_choice)
      PakettiSampleEffectGeneratorGeneratePitchPreset(pitch_choice)
      PakettiSampleEffectGeneratorGenerateVolumePreset(volume_choice)
    end
    
    -- Randomize duration (0.5 to 5.0 seconds)
    sample_duration = 0.5 + math.random() * 4.5
    
    -- Generate the sample
    PakettiSampleEffectGeneratorGenerateSample()
    
    -- Yield control back to Renoise every sample to maintain responsiveness
    coroutine.yield()
  end
  
  -- Close dialog when done
  if dialog and dialog.visible then
    dialog:close()
  end
  
  renoise.app():show_status("Generated 25 A440Hz tuned samples! (" .. random_count .. " random chaos, " .. (25 - random_count) .. " sensible)")
  print("SAMPLE_GENERATOR: Completed 25 sample generation - " .. random_count .. " random chaos, " .. (25 - random_count) .. " sensible combinations")
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
    
    -- Reset frequency multiplier when user starts drawing (manual drawing = new curve)
    if canvas_type == "waveform" then
      waveform_frequency_multiplier = 1
      print("DRAW: Reset waveform frequency multiplier to 1x (manual drawing)")
    elseif canvas_type == "pitch" then
      pitch_frequency_multiplier = 1
      print("DRAW: Reset pitch frequency multiplier to 1x (manual drawing)")
    elseif canvas_type == "volume" then
      volume_frequency_multiplier = 1
      print("DRAW: Reset volume frequency multiplier to 1x (manual drawing)")
    end
    
    local data_index, y_norm = PakettiSampleEffectGeneratorDrawPoint(canvas_type, ev.position.x, ev.position.y)
    tracking.last_index = data_index
    
  elseif ev.type == "up" then
    tracking.is_down = false
    tracking.last_x = -1
    tracking.last_y = -1
    tracking.last_index = -1
    
    -- Update live sample when mouse is released (live pickup mode)
    if live_pickup_mode then
      print("LIVE_PICKUP: Mouse released on " .. canvas_type .. " canvas, updating live sample...")
      PakettiSampleEffectGeneratorUpdateLiveSample()
    end
    
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
  
  -- Convert mouse position to data index and value (allow drawing outside bounds for easier dragging to min/max)
  local x_norm = (mouse_x - content_x) / content_width  -- 0.0 to 1.0
  local y_norm = 1.0 - ((mouse_y - content_y) / content_height)  -- 0.0 to 1.0 (inverted Y)
  
  -- Clamp values to valid range (allows dragging outside bounds to hit min/max easily)
  x_norm = math.max(0, math.min(1, x_norm))
  y_norm = math.max(0, math.min(1, y_norm))
  
  -- Only allow X within canvas bounds (prevent drawing outside horizontal range)
  if mouse_x < content_x or mouse_x > content_x + content_width then
    return nil, nil
  end
  
  -- Map to data array index - FIX: Ensure proper scaling across full array length
  local data_index = math.floor(x_norm * (#data_array - 1)) + 1
  data_index = math.max(1, math.min(#data_array, data_index))
  
  -- Update data
  data_array[data_index] = y_norm
  
  print("DRAW: " .. canvas_type .. " index=" .. data_index .. " value=" .. string.format("%.3f", y_norm))
  
  return data_index, y_norm
end

-- Live pickup mode functions
function PakettiSampleEffectGeneratorEnterLivePickupMode()
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- If no samples exist, create one automatically for Live Audition with current envelopes
  if not inst or not inst.samples or #inst.samples == 0 then
    print("LIVE_PICKUP: No samples exist, generating sample with current envelopes for Live Audition mode...")
    
    -- Generate a proper sample with current envelope settings first
    PakettiSampleEffectGeneratorGenerateSample()
    
    -- Get fresh references after sample generation
    inst = song.selected_instrument
    print("LIVE_PICKUP: Generated initial sample with current envelopes for Live Audition mode")
  end
  
  local sample = inst:sample(song.selected_sample_index)
  if not sample.sample_buffer then
    renoise.app():show_status("Live Pickup Mode: Sample buffer unavailable")
    return false
  end
  
  live_pickup_mode = true
  live_pickup_sample = sample
  live_pickup_instrument = inst
  live_pickup_sample_index = song.selected_sample_index
  live_pickup_instrument_index = song.selected_instrument_index
  
  -- Switch to sample editor so user can see what's happening
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  
  renoise.app():show_status("Live Audition Mode: Enabled - sample editor opened")
  print("LIVE_PICKUP: Mode enabled for instrument " .. live_pickup_instrument_index .. ", sample " .. live_pickup_sample_index)
  
  -- Immediately generate sample with current envelope settings
  print("LIVE_PICKUP: Generating initial sample with current envelopes...")
  PakettiSampleEffectGeneratorUpdateLiveSample()
  
  return true
end

function PakettiSampleEffectGeneratorExitLivePickupMode()
  -- Generate one final sample with current envelope settings before disabling
  if live_pickup_mode and live_pickup_sample then
    print("LIVE_PICKUP: Generating final sample before disabling...")
    PakettiSampleEffectGeneratorUpdateLiveSample()
  end
  
  live_pickup_mode = false
  live_pickup_sample = nil
  live_pickup_instrument = nil
  live_pickup_sample_index = -1
  live_pickup_instrument_index = -1
  
  renoise.app():show_status("Live Audition: Disabled - final sample rendered")
  print("LIVE_PICKUP: Mode disabled with final render")
end

-- PERFORMANCE OPTIMIZATIONS - Pre-calculated lookup tables
local sin_lookup = {}
local pow2_lookup = {}
local lookup_resolution = 4096  -- High resolution lookup tables

-- Initialize lookup tables on first use
function PakettiSampleEffectGeneratorInitLookupTables()
  if #sin_lookup == 0 then
    print("OPTIMIZATION: Building lookup tables...")
    for i = 0, lookup_resolution - 1 do
      local phase = (i / lookup_resolution) * 2 * math.pi
      sin_lookup[i + 1] = math.sin(phase)
    end
    
    -- Pitch lookup: -2 to +2 octaves mapped to 0-4096
    for i = 0, lookup_resolution - 1 do
      local pitch_norm = i / (lookup_resolution - 1)  -- 0.0 to 1.0
      local octave_offset = (pitch_norm - 0.5) * 4  -- -2 to +2 octaves
      pow2_lookup[i + 1] = math.pow(2, octave_offset)
    end
    print("OPTIMIZATION: Lookup tables ready (sin: " .. #sin_lookup .. ", pow2: " .. #pow2_lookup .. ")")
  end
end

-- Fast sine lookup with linear interpolation
function PakettiSampleEffectGeneratorFastSin(phase)
  local normalized_phase = (phase / (2 * math.pi)) % 1.0
  local float_index = normalized_phase * (lookup_resolution - 1) + 1
  local lower_index = math.floor(float_index)
  local fraction = float_index - lower_index
  
  local val1 = sin_lookup[lower_index] or 0
  local val2 = sin_lookup[lower_index + 1] or sin_lookup[1]
  
  return val1 + (val2 - val1) * fraction
end

-- Fast power-of-2 lookup
function PakettiSampleEffectGeneratorFastPow2(pitch_norm)
  local clamped_norm = math.max(0, math.min(1, pitch_norm))
  local float_index = clamped_norm * (lookup_resolution - 1) + 1
  local lower_index = math.floor(float_index)
  local fraction = float_index - lower_index
  
  local val1 = pow2_lookup[lower_index] or 1
  local val2 = pow2_lookup[lower_index + 1] or pow2_lookup[lookup_resolution]
  
  return val1 + (val2 - val1) * fraction
end

-- PRE-CALCULATE ENVELOPES: Convert 100-point envelopes to exact sample-frame arrays
function PakettiSampleEffectGeneratorPrecalculateEnvelopes(sample_frames)
  local waveform_envelope = {}
  local pitch_envelope = {}  
  local volume_envelope = {}
  
  print("OPTIMIZATION: Pre-calculating " .. sample_frames .. " envelope points...")
  
  for sample_i = 1, sample_frames do
    local time_norm = (sample_i - 1) / (sample_frames - 1)
    waveform_envelope[sample_i] = PakettiSampleEffectGeneratorInterpolateData(waveform_data, time_norm)
    pitch_envelope[sample_i] = PakettiSampleEffectGeneratorInterpolateData(pitch_data, time_norm)
    volume_envelope[sample_i] = PakettiSampleEffectGeneratorInterpolateData(volume_data, time_norm)
  end
  
  print("OPTIMIZATION: Envelope pre-calculation complete!")
  return waveform_envelope, pitch_envelope, volume_envelope
end

function PakettiSampleEffectGeneratorUpdateLiveSample()
  if not live_pickup_mode or not live_pickup_sample then
    return
  end
  
  -- Show status that we're writing the sample
  renoise.app():show_status("Writing Sample...")
  
  -- Initialize lookup tables for performance
  PakettiSampleEffectGeneratorInitLookupTables()
  
  -- Protected call to handle any sample access errors gracefully
  local success, error_msg = pcall(function()
    -- Additional safety check - ensure the sample object is still valid
    if not live_pickup_sample.sample_buffer or not live_pickup_sample.sample_buffer.has_sample_data then
      live_pickup_mode = false
      live_pickup_sample = nil
      live_pickup_instrument = nil
      renoise.app():show_status("Live Pickup Mode: Sample became invalid")
      return
    end
    
    local buffer = live_pickup_sample.sample_buffer
    
    -- Generate the sample data based on current effect settings (using proper phase accumulation)
    local sample_frames = math.floor(sample_duration * sample_rate)
    local generated_data = {}
    
    -- Initialize phase accumulation for proper pitch modulation
    local phase_accumulator = 0.0
    local base_freq = 440.0  -- A4 note
    
    -- Auto-detect if user has drawn meaningful waveform data
    local has_custom_waveform = false
    if #waveform_data > 1 then
      -- Check if waveform differs significantly from a flat line
      local first_val = waveform_data[1]
      local variation = 0
      for i = 2, #waveform_data do
        variation = variation + math.abs(waveform_data[i] - first_val)
      end
      has_custom_waveform = (variation > 0.1)  -- If there's noticeable variation, use custom waveform
    end
    
    print("LIVE_PICKUP: Generating " .. sample_frames .. " frames (" .. string.format("%.2f", sample_duration) .. "s)")
    print("LIVE_PICKUP: Custom waveform detected: " .. (has_custom_waveform and "YES - using drawn waveform" or "NO - using " .. wave_type .. " oscillator"))
    
    -- Debug volume data at the end to see what's happening
    if #volume_data > 0 then
      local num_points = #volume_data
      local end_points = math.min(10, num_points)  -- Show last 10 points
      print("LIVE_PICKUP: Volume data end points (" .. num_points .. " total):")
      for i = num_points - end_points + 1, num_points do
        print("  volume_data[" .. i .. "] = " .. string.format("%.3f", volume_data[i]))
      end
    end
    
    -- Check if user has drawn their own fade at the end
    local user_has_custom_fade = false
    if #volume_data > 0 then
      local end_volume = volume_data[#volume_data]
      if end_volume < 0.1 then
        user_has_custom_fade = true
        print("LIVE_PICKUP: User drew fade to silence (end volume: " .. string.format("%.3f", end_volume) .. ") - disabling auto-fade")
      else
        print("LIVE_PICKUP: End volume is " .. string.format("%.3f", end_volume) .. " - keeping auto-fade enabled")
      end
    end
    
    -- DEBUG: Check fade out settings
    print("LIVE_PICKUP: fade_out_enabled=" .. tostring(fade_out_enabled) .. ", user_has_custom_fade=" .. tostring(user_has_custom_fade))
    
    -- OPTIMIZATION: Pre-calculate all envelope values at once (3 interpolations → 3 arrays)
    local waveform_envelope, pitch_envelope, volume_envelope = PakettiSampleEffectGeneratorPrecalculateEnvelopes(sample_frames)
    
    -- OPTIMIZATION: Pre-select waveform generation function (remove if/elseif from tight loop)
    local waveform_generator
    if wave_type == "current" or wave_type == "sine" then
      waveform_generator = function(phase) return PakettiSampleEffectGeneratorFastSin(phase) end
    elseif wave_type == "triangle" then
      waveform_generator = function(phase)
        local normalized_phase = (phase / (2 * math.pi)) % 1
        if normalized_phase < 0.25 then
          return 4 * normalized_phase
        elseif normalized_phase < 0.75 then
          return 2 - 4 * normalized_phase
        else
          return 4 * normalized_phase - 4
        end
      end
    elseif wave_type == "square" then
      waveform_generator = function(phase) return PakettiSampleEffectGeneratorFastSin(phase) > 0 and 1 or -1 end
    elseif wave_type == "sawtooth" then
      waveform_generator = function(phase)
        local normalized_phase = (phase / (2 * math.pi)) % 1
        return 2 * normalized_phase - 1
      end
    elseif wave_type == "random" then
      waveform_generator = function(phase) return (math.random() * 2) - 1 end
    else
      waveform_generator = function(phase) return PakettiSampleEffectGeneratorFastSin(phase) end
    end
    
    print("OPTIMIZATION: Entering optimized main loop with pre-calculated envelopes...")
    local two_pi = 2 * math.pi
    
    for sample_i = 1, sample_frames do
      -- OPTIMIZATION: Get pre-calculated envelope values (no interpolation!)
      local waveform_value = waveform_envelope[sample_i]
      local pitch_mult = pitch_envelope[sample_i] 
      local volume_mult = volume_envelope[sample_i]
      
      -- OPTIMIZATION: Use fast lookup table instead of math.pow()
      local freq_mult = PakettiSampleEffectGeneratorFastPow2(pitch_mult)
      
      -- Calculate instantaneous frequency
      local actual_freq = base_freq * freq_mult
      
      -- Accumulate phase (this gives smooth pitch transitions)
      local phase_delta = actual_freq * two_pi / sample_rate
      phase_accumulator = phase_accumulator + phase_delta
      
      -- OPTIMIZATION: Use modulo instead of while loop for phase normalization
      phase_accumulator = phase_accumulator % two_pi
      
      -- OPTIMIZATION: Use pre-selected waveform generator function
      local base_wave_sample = waveform_generator(phase_accumulator)
      
      -- Apply waveform curve (different behavior based on custom waveform detection)
      local wave_sample
      if has_custom_waveform then
        -- CUSTOM WAVEFORM MODE: Use drawn waveform as repeating oscillator based on phase!
        local waveform_phase_norm = (phase_accumulator / two_pi) % 1.0  -- 0.0 to 1.0
        -- OPTIMIZATION OPPORTUNITY: This could be pre-calculated too for specific frequencies
        local waveform_sample_value = PakettiSampleEffectGeneratorInterpolateData(waveform_data, waveform_phase_norm)
        wave_sample = (waveform_sample_value * 2) - 1  -- Convert 0.0-1.0 to -1.0 to 1.0
      else
        -- STANDARD MODE: Use the pitched oscillator as the base wave
        wave_sample = base_wave_sample
      end
      
      -- Apply volume envelope
      wave_sample = wave_sample * volume_mult
      
      -- Apply fade out to avoid clicks ONLY if user hasn't drawn their own fade
      local should_auto_fade = fade_out_enabled and not user_has_custom_fade
      
      if should_auto_fade and sample_i > sample_frames - 1000 then
        local fade_pos = sample_i - (sample_frames - 1000)
        local fade_mult = 1.0 - (fade_pos / 1000.0)  -- 1.0 to 0.0
        wave_sample = wave_sample * fade_mult
        -- Debug only first and last fade samples to avoid spam
        if sample_i == sample_frames - 999 then  -- First fade sample
          print("LIVE_PICKUP: FADE OUT STARTED! fade_mult=" .. string.format("%.6f", fade_mult))
        elseif sample_i == sample_frames then
          wave_sample = 0.0
          print("LIVE_PICKUP: FINAL SAMPLE SET TO ZERO!")
        end
      end
      
      generated_data[sample_i] = wave_sample
    end
    
    -- Recreate the sample buffer with the correct duration
    local num_channels = 1  -- Mono
    local bit_depth = 32    -- 32-bit float
    local success = buffer:create_sample_data(sample_rate, bit_depth, num_channels, sample_frames)
    
    if not success then
      renoise.app():show_status("Live Pickup Mode: Failed to resize sample buffer")
      return
    end
    
    -- Update the sample buffer with generated data
    buffer:prepare_sample_data_changes()
    for i = 1, sample_frames do
      local normalized_value = math.max(-1, math.min(1, generated_data[i]))
      buffer:set_sample_data(1, i, normalized_value)
    end
    buffer:finalize_sample_data_changes()
    
    -- Apply A440Hz tuning correction to Live Pickup Mode sample (same as main generation)
    local pitch_correction = PakettiSampleEffectGeneratorCalculatePitchCorrection(sample_rate, tuned_resolution, 1)
    
    -- Only apply correction if deviation is significant (>2 cents)
    local cents_deviation = math.abs(pitch_correction.cents)
    if cents_deviation > 2 then
      live_pickup_sample.transpose = pitch_correction.transpose
      live_pickup_sample.fine_tune = pitch_correction.fine_tune
      print("LIVE_PICKUP: Applied tuning correction - Transpose: " .. pitch_correction.transpose .. ", Fine: " .. pitch_correction.fine_tune .. " (was " .. string.format("%.1f", cents_deviation) .. " cents off)")
    else
      live_pickup_sample.transpose = 0
      live_pickup_sample.fine_tune = 0
      print("LIVE_PICKUP: Sample well-tuned (" .. string.format("%.1f", cents_deviation) .. " cents) - no correction needed")
    end
    
    -- Apply beatsync settings if enabled (same as main generation)
    if beatsync_enabled then
      live_pickup_sample.beat_sync_enabled = true
      live_pickup_sample.beat_sync_lines = 32
      live_pickup_sample.beat_sync_mode = renoise.Sample.BEAT_SYNC_TEXTURE
      print("LIVE_PICKUP: Applied beatsync - 32 lines, Stretch-Texture mode")
    else
      live_pickup_sample.beat_sync_enabled = false
      print("LIVE_PICKUP: Beatsync disabled")
    end
    
    print("LIVE_PICKUP: Updated sample with " .. sample_frames .. " frames (" .. string.format("%.2f", sample_duration) .. " seconds)")
    renoise.app():show_status("Sample writing finished.")
  end)
  
  if not success then
    print("LIVE_PICKUP: Error updating sample - " .. tostring(error_msg))
    renoise.app():show_status("Live Pickup Mode: Update failed")
    -- Disable live pickup mode if there was an error
    PakettiSampleEffectGeneratorExitLivePickupMode()
  end
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
      -- Calculate positions within content bounds - account for line thickness (2px) to prevent clipping
      local line_thickness = 2
      local x_pos = content_x + x_norm * content_width
      local y_pos = content_y + line_thickness/2 + (1.0 - data_array[i]) * (content_height - line_thickness)
      
      -- Additional safety clamp to ensure absolutely no boundary violations
      x_pos = math.max(content_x, math.min(content_x + content_width, x_pos))
      y_pos = math.max(content_y + line_thickness/2, math.min(content_y + content_height - line_thickness/2, y_pos))
      
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
  
  -- Draw border (grey rectangle around the FULL area including padding)
  ctx.stroke_color = {80, 80, 80, 255}
  ctx.line_width = 2
  ctx:begin_path()
  ctx:rect(border_margin, text_height + text_margin, canvas_width - (border_margin * 2), canvas_height - text_height - text_margin - border_margin)
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
  print("SAMPLE_GENERATOR: FIXED - Now generating " .. total_samples .. " samples over " .. sample_duration .. " seconds with pitch modulation!")
  
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
      -- CURRENT mode: Use the drawn waveform directly as oscillator
      local waveform_phase = (phase_accumulator / (2 * math.pi)) % 1.0  -- 0.0 to 1.0
      local waveform_sample_value = PakettiSampleEffectGeneratorInterpolateData(waveform_data, waveform_phase)
      base_wave_sample = (waveform_sample_value * 2) - 1  -- Convert 0.0-1.0 to -1.0 to 1.0
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
    
    -- Apply fade out if enabled (last 15 frames to avoid clicks) ONLY if user hasn't drawn their own fade
    local should_auto_fade = fade_out_enabled
    if #volume_data > 0 then
      -- Check if user has drawn their own fade to silence at the end
      local end_volume = volume_data[#volume_data]  -- Last volume point
      if end_volume < 0.1 then  -- If user ended near silence, don't auto-fade
        should_auto_fade = false
      end
    end
    
    if should_auto_fade then
      local fade_frames = 1000  -- Longer fade to zero (about 0.023 seconds)
      if sample_i > (total_samples - fade_frames) then
        local fade_pos = sample_i - (total_samples - fade_frames)
        local fade_mult = 1.0 - (fade_pos / fade_frames)  -- 1.0 to 0.0
        wave_sample = wave_sample * fade_mult
        -- Ensure the very last sample is exactly zero
        if sample_i == total_samples then
          wave_sample = 0.0
        end
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
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
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
  
  -- Set sample properties with Paketti loader settings
  sample.name = "Generated_" .. os.date("%H%M%S")
  
  -- Apply A440Hz tuning correction (from PakettiPCMWriter.lua)
  local pitch_correction = PakettiSampleEffectGeneratorCalculatePitchCorrection(sample_rate, tuned_resolution, 1)
  
  -- Only apply correction if deviation is significant (>2 cents)
  local cents_deviation = math.abs(pitch_correction.cents)
  if cents_deviation > 2 then
    sample.transpose = pitch_correction.transpose
    sample.fine_tune = pitch_correction.fine_tune
    print("TUNING: Applied pitch correction - Transpose: " .. pitch_correction.transpose .. ", Fine: " .. pitch_correction.fine_tune .. " (was " .. string.format("%.1f", cents_deviation) .. " cents off)")
    sample.name = sample.name .. " -> " .. pitch_correction.note_name
  else
    sample.transpose = 0
    sample.fine_tune = 0
    print("TUNING: Sample well-tuned (" .. string.format("%.1f", cents_deviation) .. " cents) - no correction needed")
  end
  
  sample.volume = 1.0
  sample.panning = 0.5
  
  -- Apply Paketti loader preferences (same as PakettiSamples.lua)
  sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value
  sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value
  sample.autofade = preferences.pakettiLoaderAutofade.value
  sample.autoseek = preferences.pakettiLoaderAutoseek.value
  sample.oneshot = preferences.pakettiLoaderOneshot.value
  
  -- Apply beatsync settings if enabled
  if beatsync_enabled then
    sample.beat_sync_enabled = true
    sample.beat_sync_lines = 32
    sample.beat_sync_mode = renoise.Sample.BEAT_SYNC_TEXTURE
    print("SAMPLE_GENERATOR: Applied beatsync - 32 lines, Stretch-Texture mode")
  else
    sample.beat_sync_enabled = false
    print("SAMPLE_GENERATOR: Beatsync disabled")
  end
  
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
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
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
  -- Toggle behavior: if dialog is open and visible, close it and return
  print("SAMPLE_GENERATOR: Checking dialog state...")
  print("  sample_generator_dialog exists: " .. tostring(sample_generator_dialog ~= nil))
  if sample_generator_dialog then
    print("  sample_generator_dialog.visible: " .. tostring(sample_generator_dialog.visible))
  end
  
  if sample_generator_dialog and sample_generator_dialog.visible then
    print("SAMPLE_GENERATOR: Closing existing dialog")
    sample_generator_dialog:close()
    sample_generator_dialog = nil
    print("SAMPLE_GENERATOR: Dialog closed and set to nil")
    return
  end
  
  print("SAMPLE_GENERATOR: Creating new dialog")
  
  -- Set beatsync checkbox based on currently selected sample's state
  local song = renoise.song()
  local inst = song.selected_instrument
  
  if inst and song.selected_sample_index > 0 then
    local sample = inst:sample(song.selected_sample_index)
    if sample then
      beatsync_enabled = sample.beat_sync_enabled
      print("SAMPLE_GENERATOR: Dialog opened - beatsync checkbox set to " .. (beatsync_enabled and "ON" or "OFF") .. " based on current sample")
    end
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
        width = 120,  -- Column width to fit 120px invert button perfectly
        vb:text { text = "Wave Type", font = "bold", style = "strong" },
        vb:popup {
          id = "wave_type_popup",
          items = UNIFIED_DROPDOWN_ITEMS,
          value = 1,  -- Default to Current (use drawn waveform)
          width = 120,
          notifier = function(value)
            wave_type = UNIFIED_DROPDOWN_TYPES[value]
            
            -- ALWAYS reset frequency multiplier when changing dropdown selection (including "current")
            waveform_frequency_multiplier = 1
            print("WAVEFORM PRESET: Reset frequency multiplier to 1x")
            
            if wave_type ~= "current" then
              -- Only generate base waveform if user selected a preset (not "Current")
              PakettiSampleEffectGeneratorGenerateBaseWaveform(wave_type)
            end
            
            print("SAMPLE_GENERATOR: Wave type changed to " .. wave_type)
            -- Update live sample if live audition is enabled
            if live_pickup_mode then
              PakettiSampleEffectGeneratorUpdateLiveSample()
            end
          end
        },
        vb:row {
          vb:button {
            text = "2x",
            width = 40,
            tooltip = "Double waveform frequency",
            notifier = function()
              PakettiSampleEffectGeneratorDoubleWaveform()
              -- Note: DoubleWaveform() already handles Live Audition updates internally
            end
          },
          vb:button {
            text = "1/2", 
            width = 40,
            tooltip = "Halve waveform frequency",
            notifier = function()
              PakettiSampleEffectGeneratorHalveWaveform()
              -- Update live sample if live audition is enabled
              if live_pickup_mode then
                PakettiSampleEffectGeneratorUpdateLiveSample()
              end
            end
          },
          vb:button {
            text = "RND",
            width = 40,
            tooltip = "Randomize waveform curve",
            notifier = function()
              PakettiSampleEffectGeneratorRandomizeWaveform()
              -- Update live sample if live audition is enabled
              if live_pickup_mode then
                PakettiSampleEffectGeneratorUpdateLiveSample()
              end
            end
          },
        },
        vb:row {
          vb:button {
            text = "Invert",
            width = 120,
            tooltip = "Invert waveform curve",
            notifier = function()
              PakettiSampleEffectGeneratorInvertWaveform()
            end
          },
        },
        vb:row {
          vb:button {
            text = "Normalize",
            width = 120,
            tooltip = "Normalize waveform curve to full 0.0-1.0 range",
            notifier = function()
              PakettiSampleEffectGeneratorNormalizeWaveform()
            end
          },
        },
      },
      
      -- Pitch modulation type selection (FIXED ORDER: matches canvas order)
      vb:column {
        width = 120,  -- Column width to fit 120px invert button perfectly
        vb:text { text = "Pitch Modulation", font = "bold", style = "strong" },
        vb:popup {
          id = "pitch_modulation_popup",
          items = PITCH_DROPDOWN_ITEMS,
          value = 1,  -- Default to Current (use drawn pitch curve)
          width = 120,
          notifier = function(value)
            pitch_modulation_type = PITCH_DROPDOWN_TYPES[value]
            
            -- ALWAYS reset frequency multiplier and call preset function (even for "current")
            PakettiSampleEffectGeneratorGeneratePitchPreset(pitch_modulation_type)
            
            print("SAMPLE_GENERATOR: Pitch modulation changed to " .. pitch_modulation_type)
            -- Update live sample if live audition is enabled
            if live_pickup_mode then
              PakettiSampleEffectGeneratorUpdateLiveSample()
            end
          end
        },
        vb:row {
          vb:button {
            text = "2x",
            width = 40,
            tooltip = "Double pitch curve frequency",
            notifier = function()
              PakettiSampleEffectGeneratorDoublePitch()
              -- Note: DoublePitch() already handles Live Audition updates internally
            end
          },
          vb:button {
            text = "1/2",
            width = 38,
            tooltip = "Halve pitch curve frequency", 
            notifier = function()
              PakettiSampleEffectGeneratorHalvePitch()
              -- Update live sample if live audition is enabled
              if live_pickup_mode then
                PakettiSampleEffectGeneratorUpdateLiveSample()
              end
            end
          },
          vb:button {
            text = "RND",
            width = 40,
            tooltip = "Randomize pitch modulation curve",
            notifier = function()
              PakettiSampleEffectGeneratorRandomizePitch()
              -- Update live sample if live audition is enabled
              if live_pickup_mode then
                PakettiSampleEffectGeneratorUpdateLiveSample()
              end
            end
          },
        },
        vb:row {
          vb:button {
            text = "Invert",
            width = 120,
            tooltip = "Invert pitch modulation curve",
            notifier = function()
              PakettiSampleEffectGeneratorInvertPitch()
            end
          },
        },
        vb:row {
          vb:button {
            text = "Normalize",
            width = 120,
            tooltip = "Normalize pitch curve to full 0.0-1.0 range",
            notifier = function()
              PakettiSampleEffectGeneratorNormalizePitch()
            end
          },
        },
        vb:row {
          vb:button {
            text = "Debug Pitch",
            width = 120,
            tooltip = "Debug pitch canvas drawing issues",
            notifier = function()
              PakettiSampleEffectGeneratorDebugPitchCanvas()
            end
          },
        },
      },
      
      -- Volume envelope type selection (FIXED ORDER: matches canvas order)
      vb:column {
        width = 120,  -- Column width to fit 120px invert button perfectly
        vb:text { text = "Volume Envelope", font = "bold", style = "strong" },
        vb:popup {
          id = "volume_envelope_popup",
          items = UNIFIED_DROPDOWN_ITEMS,
          value = 1,  -- Default to Current (use drawn volume curve)
          width = 120,
          notifier = function(value)
            volume_envelope_type = UNIFIED_DROPDOWN_TYPES[value]
            
            -- ALWAYS reset frequency multiplier and call preset function (even for "current")
            PakettiSampleEffectGeneratorGenerateVolumePreset(volume_envelope_type)
            
            print("SAMPLE_GENERATOR: Volume envelope changed to " .. volume_envelope_type)
            -- Update live sample if live audition is enabled
            if live_pickup_mode then
              PakettiSampleEffectGeneratorUpdateLiveSample()
            end
          end
        },
        vb:row {
          vb:button {
            text = "2x",
            width = 40,
            tooltip = "Double volume envelope frequency",
            notifier = function()
              PakettiSampleEffectGeneratorDoubleVolume()
              -- Note: DoubleVolume() already handles Live Audition updates internally
            end
          },
          vb:button {
            text = "1/2",
            width = 40,
            tooltip = "Halve volume envelope frequency",
            notifier = function()
              PakettiSampleEffectGeneratorHalveVolume()
              -- Update live sample if live audition is enabled
              if live_pickup_mode then
                PakettiSampleEffectGeneratorUpdateLiveSample()
              end              
            end
          },
          vb:button {
            text = "RND",
            width = 40,
            tooltip = "Randomize volume envelope curve",
            notifier = function()
              PakettiSampleEffectGeneratorRandomizeVolume()
              -- Update live sample if live audition is enabled
              if live_pickup_mode then
                PakettiSampleEffectGeneratorUpdateLiveSample()
              end              
            end
          },
        },
        vb:row {
          vb:button {
            text = "Invert",
            width = 120,
            tooltip = "Invert volume envelope curve",
            notifier = function()
              PakettiSampleEffectGeneratorInvertVolume()
            end
          },
        },
        vb:row {
          vb:button {
            text = "Normalize",
            width = 120,
            tooltip = "Normalize volume curve to full 0.0-1.0 range",
            notifier = function()
              PakettiSampleEffectGeneratorNormalizeVolume()
            end
          },
        },
        vb:row {
          vb:checkbox {
            value = fade_out_enabled,
            tooltip = "Fade out last 1000 frames (0.023s) to avoid clicks - ends at ZERO",
            notifier = function(value)
              fade_out_enabled = value
              print("SAMPLE_GENERATOR: Fade out " .. (fade_out_enabled and "enabled" or "disabled"))
            end
          },
          vb:text { text = "Fade Out", font = "bold", style = "strong" },
        },
        vb:row {
          vb:checkbox {
            value = beatsync_enabled,
            tooltip = "Enable beatsync with 32 lines and Stretch-Texture mode for all generated samples",
            notifier = function(value)
              beatsync_enabled = value
              
              -- Also affect the currently selected sample immediately
              local song = renoise.song()
              local inst = song.selected_instrument
              
              if inst and song.selected_sample_index > 0 then
                local sample = inst:sample(song.selected_sample_index)
                if sample then
                  if beatsync_enabled then
                    -- Turn ON beatsync for current sample
                    sample.beat_sync_enabled = true
                    sample.beat_sync_lines = 32
                    sample.beat_sync_mode = renoise.Sample.BEAT_SYNC_TEXTURE
                    print("SAMPLE_GENERATOR: Beatsync enabled for current sample " .. song.selected_sample_index .. " (32 lines, Stretch-Texture)")
                  else
                    -- Turn OFF beatsync for current sample
                    sample.beat_sync_enabled = false
                    print("SAMPLE_GENERATOR: Beatsync disabled for current sample " .. song.selected_sample_index)
                  end
                end
              end
              
              print("SAMPLE_GENERATOR: Beatsync " .. (beatsync_enabled and "enabled (32 lines, Stretch-Texture)" or "disabled") .. " for future generated samples")
            end
          },
          vb:text { text = "Beatsync", font = "bold", style = "strong" },
        },
      },
      
      -- Duration control
      vb:column {
        width = 90,  -- Column width to fit 120px invert button perfectly
        vb:text { width=90,text = "Duration (sec)", font = "bold", style = "strong" },
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
      
      -- Tuning info display
      vb:column {
        width = 90,
        vb:text { width=90, text = "A440 Tuning", font = "bold", style = "strong" },
        vb:text { 
          id = "tuning_text",
          width = 90,
          text = tuned_resolution .. " pts",
          style = "normal"
        }
      },
      
      -- Action buttons
      vb:column {
        vb:row {
          vb:button {
            text = "Generate (SPACE)",
            width = 160,
            tooltip = "Generate sample from drawn curves",
            notifier = function()
              PakettiSampleEffectGeneratorGenerateSample()
            end
          },

          vb:button {
            text = "Reset All Envelopes",
            width = 160,
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
        },
        vb:row {
          vb:checkbox {
            id = "live_pickup_checkbox",
            value = false,
            tooltip = "Enable/disable live audition mode - updates current sample when mouse is released",
            notifier = function()
              local checkbox = vb.views.live_pickup_checkbox
              if checkbox.value then
                -- User checked the box - enable live pickup
                if not PakettiSampleEffectGeneratorEnterLivePickupMode() then
                  -- Failed to enable, uncheck the box
                  checkbox.value = false
                end
              else
                -- User unchecked the box - disable live pickup
                PakettiSampleEffectGeneratorExitLivePickupMode()
              end
            end
          },
          vb:text { 
            text = "Live Audition",style="strong",font="bold",
            tooltip = "When enabled, the current sample will be updated every time you release the mouse after drawing"
          }
        }
      }
    },
    
    -- Instructions
    vb:text {
      text = "Instructions: Draw on the canvas to shape your sound. Press SPACE to generate. ESC to close. Enable Live Audition to update current sample on mouse release.",
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

-- Main toggle function (matches pattern from PakettiMainMenuEntries.lua)
function PakettiSampleEffectGeneratorInit()
  print("SAMPLE_GENERATOR: Toggling dialog...")
  PakettiSampleEffectGeneratorCreateDialog()
end

renoise.tool():add_menu_entry {name = "Main Menu:Tools:Paketti Sample Effect Generator",invoke = PakettiSampleEffectGeneratorInit}
renoise.tool():add_keybinding {name = "Global:Paketti:Paketti Sample Effect Generator",invoke = PakettiSampleEffectGeneratorInit}


