local vb = renoise.ViewBuilder()
local DIALOG_TITLE = "Paketti Single Cycle Waveform Writer"
local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix

-- Live Pickup Mode - Load current sample into editor
local live_pickup_mode = false
local live_pickup_sample = nil
local live_pickup_instrument = nil
local live_pickup_sample_index = -1
local live_pickup_instrument_index = -1


-- Debug print function
local _DEBUG = true
local function dprint(...) if _DEBUG then print("PCM Debug:", ...) end end

-- AUTOMATIC PITCH CORRECTION FEATURE:
-- All sample exports now include automatic pitch correction using danoise's frequency analysis algorithm.
-- Single-cycle waveforms are analyzed for their fundamental frequency and automatically corrected
-- to the nearest musical note with proper transpose and fine-tune values.
-- Correction is only applied if deviation is >2 cents to avoid unnecessary micro-adjustments.

-- ========================================
-- HEADLESS PITCH CORRECTION (danoise algorithm)
-- ========================================

local function round(x)
  if x>=0 then return math.floor(x+0.5)
  else return math.ceil(x-0.5) end
end

-- Headless frequency to note analysis (extracted from PakettiRePitch)
local function frequency_to_note_analysis(frequency)
  local A4 = 440.0
  local A4_INDEX = 57
  
  -- Full MIDI range C0-B9
  local notes = {
    "C0","C#0","D0","D#0","E0","F0","F#0","G0","G#0","A0","A#0","B0",
    "C1","C#1","D1","D#1","E1","F1","F#1","G1","G#1","A1","A#1","B1",
    "C2","C#2","D2","D#2","E2","F2","F#2","G2","G#2","A2","A#2","B2",
    "C3","C#3","D3","D#3","E3","F3","F#3","G3","G#3","A3","A#3","B3",
    "C4","C#4","D4","D#4","E4","F4","F#4","G4","G#4","A4","A#4","B4",
    "C5","C#5","D5","D#5","E5","F5","F5","G5","G#5","A5","A#5","B5",
    "C6","C#6","D6","D#6","E6","F6","F#6","G6","G#6","A6","A#6","B6",
    "C7","C#7","D7","D#7","E7","F7","F#7","G7","G#7","A7","A#7","B7",
    "C8","C#8","D8","D#8","E8","F8","F#8","G8","G#8","A8","A#8","B8",
    "C9","C#9","D9","D#9","E9","F9","F#9","G9","G#9","A9","A#9","B9"
  }
  
  local pow = function(a,b) return a ^ b end
  
  local MINUS = 0
  local PLUS = 1
  
  local r = pow(2.0, 1.0/12.0)  -- More precise semitone ratio
  local cent = pow(2.0, 1.0/1200.0)  -- Precise cent calculations
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
    if cent_index > 50 then  -- Use 50 cents as threshold for rounding to next semitone
      r_index = r_index + 1
      cent_index = 100 - cent_index
      side = MINUS
    else
      side = PLUS
    end
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
    if cent_index >= 50 then  -- Use 50 cents as threshold for rounding to next semitone
      r_index = r_index - 1
      cent_index = 100 - cent_index
      side = PLUS
    else
      side = MINUS
    end
  end
  
  -- Calculate MIDI note number
  local midi_note = A4_INDEX + r_index - 1  -- Convert to 0-based indexing
  
  -- Get note name
  local note_name = "C4"  -- Default fallback
  if midi_note >= 0 and midi_note < #notes then
    note_name = notes[midi_note + 1]  -- Convert back to 1-based indexing
  end
  
  -- Calculate signed cents
  local signed_cents = cent_index
  if side == MINUS then
    signed_cents = -signed_cents
  end
  
  return {
    note_name = note_name,
    midi_note = midi_note,
    cents = signed_cents,
    side = side
  }
end

-- Headless pitch correction calculator
local function calculate_pitch_correction(sample_rate, wave_length_frames, cycles)
  cycles = cycles or 1  -- Default to 1 cycle
  
  -- Calculate frequency from wave data
  local freq = sample_rate / (wave_length_frames / cycles)
  
  -- Analyze the frequency
  local result = frequency_to_note_analysis(freq)
  
  -- Calculate pitch correction values
  local midi_note = result.midi_note + 12  -- Convert to standard MIDI system (C4=60)
  local diff = round(midi_note) - 60  -- Difference from C4
  
  -- Calculate transpose (clamp to valid range)
  local transpose_value = -diff
  transpose_value = math.max(-120, math.min(120, transpose_value))
  
  -- Calculate fine tune correction (negate to correct the detected deviation)
  local cents_value = -result.cents
  local fine_tune_steps = round(cents_value * 1.275)  -- Scale: 255 steps / 200 cents = 1.275
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

-- Apply pitch correction to a specific sample for standard single-cycle lengths
function PCMWriterApplyPitchCorrectionToSample(sample, wave_length_frames)
  if not sample then return end
  local standard_cycle_lengths = {32, 64, 128, 256, 512, 1024}
  local is_standard_length = false
  for _, length in ipairs(standard_cycle_lengths) do
    if wave_length_frames == length then
      is_standard_length = true
      break
    end
  end
  if not is_standard_length then return end
  local pitch_correction = calculate_pitch_correction(44100, wave_length_frames, 1)
  local cents_deviation = math.abs(pitch_correction.cents)
  if cents_deviation > 2 then
    sample.transpose = pitch_correction.transpose
    sample.fine_tune = pitch_correction.fine_tune
  end
end

-- ========================================
-- COLOR CONSTANTS - All canvas colors organized in one place
-- ========================================
-- Format: {red, green, blue, alpha} where values are 0-255

-- Canvas grid and reference lines
local COLOR_GRID_LINES = {0, 64, 0, 255}           -- Dark green grid lines
local COLOR_ZERO_LINE = {128, 128, 128, 255}       -- Gray center line

-- Wave A colors (Red theme)
local COLOR_WAVE_A_ACTIVE = {255, 0, 0, 255}       -- Bright red when editing Wave A
local COLOR_WAVE_A_INACTIVE = {255, 0, 0, 180}     -- Transparent red when not editing Wave A

-- Wave B colors (Blue theme)
local COLOR_WAVE_B_ACTIVE = {0, 100, 255, 255}     -- Bright blue when editing Wave B
local COLOR_WAVE_B_INACTIVE = {0, 100, 255, 180}   -- Transparent blue when not editing Wave B

-- Crossfaded result waveform (Purple theme) - MAIN RESULT LINE
local COLOR_CROSSFADED_WAVEFORM = {255, 64, 255, 200}  -- Bright pink-purple (was {128, 0, 255, 200})

-- Sample point visualization
local COLOR_SAMPLE_POINTS = {0, 200, 0, 255}       -- Bright green sample dots

-- Selected sample highlighting
local COLOR_SELECTED_LINE = {255, 0, 0, 180}       -- Red line for selected sample
local COLOR_SELECTED_POINT = {255, 0, 0, 255}      -- Red dot for selected sample

-- Selection overlay
local COLOR_SELECTION_BACKGROUND = {0, 150, 255, 60}   -- Light blue selection background
local COLOR_SELECTION_BORDERS = {0, 150, 255, 200}     -- Blue selection borders

-- UI info display
local COLOR_ZOOM_INFO = {255, 255, 255, 200}       -- White text for zoom info

-- Button colors (Wave A/B edit buttons)
local COLOR_BUTTON_ACTIVE = {0, 255, 0}            -- Green when active
local COLOR_BUTTON_INACTIVE = {128, 128, 128}      -- Gray when inactive

-- Editor state
local wave_size_options = {16, 32, 64, 128, 256, 512, 1024}
local wave_size = 512
local wave_data = table.create()
for i = 1, wave_size do wave_data[i] = 32768 end

-- Wave A/B system
local wave_data_a = table.create()  -- Wave A buffer
local wave_data_b = table.create()  -- Wave B buffer
for i = 1, wave_size do 
  wave_data_a[i] = 32768 
  wave_data_b[i] = 32768 
end
local current_wave_edit = "A"  -- Which wave we're editing ("A" or "B")
local crossfade_amount = 0.0  -- 0.0 = Wave A, 1.0 = Wave B
local chebyshev_mix = 0.0     -- 0.0 = no Chebyshev, 1.0 = full Chebyshev
local chebyshev_order = 1     -- T1 to T8

-- Geometric shape parameters
local geometric_shapes = {"diamond", "double_diamond", "asym_diamond", "pentagon", "hexagon", "exp_diamond", 
                         "log_diamond", "fractal_diamond", "recursive_triangle", "star_5", "star_8", "spiral", 
                         "bezier_diamond", "harmonic_diamond", "crystal", "zigzag", "staircase", "heart", "butterfly"}
local current_geometric_index = 1
local shape_asymmetry = 0.5  -- 0.0 to 1.0 (peak position for asymmetric shapes)
local current_waveform_type = "sine"  -- Track current waveform type for real-time updates
local shape_segments = 6     -- Number of segments for polygon shapes
local shape_curve = 1.0      -- Curve amount for exponential/logarithmic shapes
local shape_recursion = 3    -- Recursion depth for fractal shapes

local selected_sample_index = -1
local is_drawing = false
local hex_buttons = {}
local pcm_dialog = nil
local waveform_canvas = nil
local dialog_initialized = false
local selection_info_view = nil
local dialog_rebuilding = false  -- Flag to prevent dropdown from triggering during rebuild
local hex_field_has_focus = false  -- Track if a hex field has focus
local updating_hex_display = false  -- Flag to prevent cascading cursor updates
local hide_hex_editor = false  -- Flag to hide/show hex editor (will be loaded from preferences)
local hideChebyshev = true  -- Flag to hide/show Chebyshev controls

-- UI element references for dynamic updates
local wavetable_count_text = nil
local cursor_step_slider = nil
local cursor_step_text = nil

-- Cursor control settings
local cursor_width = 1  -- Default width of cursor (number of samples to affect)
local cursor_step_size = 1000  -- Default step size for arrow keys

-- Mouse and selection state
local selection_start = -1
local selection_end = -1
local selection_dragging = false
local selection_info_view = nil

-- Mouse tracking for smooth drawing
local last_mouse_x = -1
local last_mouse_y = -1
local last_sample_index = -1

-- Zoom and pan state
local zoom_factor = 1.0
local pan_offset = 0
local min_zoom = 0.25
local max_zoom = 8.0

-- Canvas display state
local show_sample_points = true
local canvas_interpolation_mode = "linear" -- "linear", "cubic", "bezier" for canvas display

-- Sample export settings (separate from canvas display)
local sample_interpolation_mode = "sinc" -- "none", "linear", "cubic", "sinc"
local sample_oversample_enabled = true

-- Loop mode setting for created/updated samples (Forward or PingPong)
-- Applied in all creation/export paths before pitch correction
sample_loop_mode = renoise.Sample.LOOP_MODE_FORWARD

-- Flag to prevent AutoSamplify from processing during PCM Writer operations
local pcm_writer_creating_samples = false

-- Function to check if PCM Writer is currently creating samples
function PCMWriterIsCreatingSamples()
  return pcm_writer_creating_samples
end

-- Function to set the PCM Writer creation flag
function PCMWriterSetCreatingSamples(creating)
  pcm_writer_creating_samples = creating
  if creating then
    print("DEBUG: PCM Writer flag set - AutoSamplify will be disabled")
  else
    print("DEBUG: PCM Writer flag cleared - AutoSamplify will be enabled")
  end
end

-- Wavetable state
local wavetable_waves = {}
local current_wave_index = 1
local wavetable_size = 512  -- Match the main wave editor size
local wavetable_canvas_width = 1024
local wt_buttonwidth = 200

-- Hex editor state
local hex_editor_page = 0
local hex_samples_per_page = 128  -- 8 rows × 16 columns = 128 samples per page
local hex_items_per_row = 16
local hex_textfield_width = 32  -- Width of hex editor textfields (matches canvas width)
local tool_button_width = 60   -- Standard width for all tool buttons

  -- Initialize empty wavetable (no default wave)
-- wavetable_waves starts empty - waves are added when user clicks "Add Current to Wavetable"

-- AKWF dropdown will be initialized when dialog is shown

-- Helper function to validate track type for wavetable operations
function PCMWriterValidateTrackForWavetable()
  local song = renoise.song()
  local selected_track = song.selected_track
  
  if selected_track.type == renoise.Track.TRACK_TYPE_MASTER then
    renoise.app():show_status("Cannot create wavetable instrument on Master track. Please select a regular track.")
    return false
  elseif selected_track.type == renoise.Track.TRACK_TYPE_SEND then
    renoise.app():show_status("Cannot create wavetable instrument on Send track. Please select a regular track.")
    return false
  elseif selected_track.type == renoise.Track.TRACK_TYPE_GROUP then
    renoise.app():show_status("Cannot create wavetable instrument on Group track. Please select a regular track.")
    return false
  end
  
  return true
end

-- WaveFunctions class from MorphSynth - Advanced wave generation with morphing capabilities
class "WaveFunctions"

-- Initialize wave function names and static variables
WaveFunctions.names = { "Sine", "Triangle", "Pulse", "Saw", "Diode", "Gauss", "Chebyshev", "Chirp", "White Noise", "Pink Noise", "Brown Noise" }

-- Static variables for noise generation
WaveFunctions.pink_store = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
WaveFunctions.pink = 0
WaveFunctions.pink_count = 0
WaveFunctions.brown = 0

-- Sine wave function with shape parameter
WaveFunctions["Sine"] = function(x, shape)
  x = x % 1
  if shape == 0 then
    return math.sin(2 * x * math.pi)
  else
    shape = shape + 1
    if shape > 1 then
      shape = math.pow(100, shape) / 100
    end
    local s = 1
    if x > 0.5 then
      s = -1
    end
    return s * math.pow(s * math.sin(2 * x * math.pi), shape)
  end
end

-- Triangle wave function with shape parameter
WaveFunctions["Triangle"] = function(x, shape)
  shape = (shape + 1) / 2
  x = (x + 0.5 * shape) % 1
  if x < shape then
    return x / shape * 2 - 1
  else
    return (1 - x) / (1 - shape) * 2 - 1
  end
end

-- Pulse wave function with shape parameter (duty cycle)
WaveFunctions["Pulse"] = function(x, shape)
  if x % 1 < (shape + 1) / 2 then
    return 1
  else
    return -1
  end
end

-- Sawtooth wave function with shape parameter
WaveFunctions["Saw"] = function(x, shape)
  shape = (shape + 1) / 2 - 0.5
  local p = math.pow(0.5, 1 / math.exp(shape * 10))
  x = (x + p) % 1
  return math.pow(x, math.exp(shape * 10)) * 2 - 1
end

-- Diode wave function with shape parameter - start at 0.5
WaveFunctions["Diode"] = function(x, shape)
  local shifted_x = (x + 0.25) % 1  -- Shift to start at middle value (0.5)
  local r = math.sin(shifted_x * 2 * math.pi + (math.pi / 6) * (1 + shape)) - shape
  if r < 0 then r = 0 end
  return r / (1 - shape) * 2 - 1
end

-- Gaussian wave function with shape parameter
WaveFunctions["Gauss"] = function(x, shape)
  shape = (shape + 1) / 2
  local p = (- math.sqrt(- math.log(0.5) / (math.exp(shape * 8) + 5)) + 1) / 2
  x = 2 * ((x + p) % 1) - 1
  return math.exp(-x * x * (math.exp(shape * 8) + 5)) * 2 - 1
end

-- Chebyshev polynomial wave function
WaveFunctions["Chebyshev"] = function(x, shape)
  shape = (shape + 1) / 2
  shape = shape * shape * shape * 25 + 1
  local p = (math.cos(math.pi / (2 * shape)) + 1) / 2
  return math.cos(math.acos(((x + p) % 1) * 2 - 1) * shape)
end

-- Chirp wave function with shape parameter
WaveFunctions["Chirp"] = function(x, shape)
  x = (x % 1) * 2 * math.pi
  shape = shape * 2
  shape = math.pow(3, shape)
  return math.sin(x / 2) * math.sin(shape * x * x)
end

-- White noise function
WaveFunctions["White Noise"] = function(x, shape)
  return math.random() * 2 - 1
end

-- Brown noise function with persistent state
WaveFunctions["Brown Noise"] = function(x, shape)
  local r = math.random() - 0.5
  WaveFunctions.brown = WaveFunctions.brown + r
  if WaveFunctions.brown < -8 or WaveFunctions.brown > 8 then
    WaveFunctions.brown = WaveFunctions.brown - r
  end
  return WaveFunctions.brown / 8
end

-- Pink noise function with sophisticated filtering
WaveFunctions["Pink Noise"] = function(x, shape)
  return WaveFunctions.next_pink()
end

-- Helper function to count trailing zeros for pink noise
function count_trailing_zeros(num)
  local i = 0
  local n = num
  while (n % 2) == 0 and i < 16 do
    n = math.floor(n / 2)
    i = i + 1
  end
  return i
end

-- Initialize random seed and noise states
function WaveFunctions.initialize_random_seed(seed)
  WaveFunctions.pink_store = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
  WaveFunctions.pink = 0
  WaveFunctions.pink_count = 0
  WaveFunctions.brown = 0
  math.randomseed(seed)
end

-- Generate next pink noise sample
function WaveFunctions.next_pink()
  local k = count_trailing_zeros(WaveFunctions.pink_count)
  k = k % 16 + 1
  local prevr = WaveFunctions.pink_store[k]
  local finished = false
  
  repeat
    local r = math.random() - 0.5
    WaveFunctions.pink_store[k] = r
    r = r - prevr
    WaveFunctions.pink = WaveFunctions.pink + r
    
    if WaveFunctions.pink < -4 or WaveFunctions.pink > 4 then
      WaveFunctions.pink = WaveFunctions.pink - r
    else
      finished = true
    end
  until finished
  
  WaveFunctions.pink_count = WaveFunctions.pink_count + 1
  return (math.random() - 0.5 + WaveFunctions.pink) * 0.25
end

-- Enhanced PCMWriter wave generation using MorphSynth wave functions
function PCMWriterGenerateWaveformMorph(wave_type, shape_param, target_data, size)
  target_data = target_data or wave_data
  size = size or wave_size
  shape_param = shape_param or 0
  
  -- Initialize random seed for consistent noise generation
  WaveFunctions.initialize_random_seed(os.time() + size)
  
  -- Generate waveform using MorphSynth wave functions
  for i = 1, size do
    local phase = (i - 1) / size
    local value = 0
    
    if WaveFunctions[wave_type] then
      value = WaveFunctions[wave_type](phase, shape_param)
    else
      -- Fallback to sine if wave type not found
      value = WaveFunctions["Sine"](phase, shape_param)
    end
    
    -- Convert from -1..1 to 0..65535
    target_data[i] = math.floor((value * 32767) + 32768)
    target_data[i] = math.max(0, math.min(65535, target_data[i]))
  end
  
  selected_sample_index = -1
end







-- Centralized function to remove placeholder samples from an instrument
function PCMWriterRemovePlaceholderSamples(instrument, selected_sample_slot)
  if not instrument or #instrument.samples == 0 then
    return
  end
  
  local num_samples = #instrument.samples
  local removed_count = 0
  print("DEBUG: Checking " .. num_samples .. " samples for placeholder removal")
  
  -- Go backwards through samples to avoid index shifting when deleting
  for i = num_samples, 1, -1 do
    local sample = instrument.samples[i]
    local sample_name = sample.name
    print("DEBUG: Sample " .. i .. " name: '" .. sample_name .. "'")
    
    -- Check for various placeholder patterns
    local is_placeholder = sample_name == "Placeholder sample" or 
                          sample_name:match("^Sample %d+$") or  -- Default Renoise sample names like "Sample 01"
                          sample_name == "" or -- Empty name samples
                          (sample.sample_buffer.has_sample_data and sample.sample_buffer.number_of_frames <= 2) -- Very short samples
    
    if is_placeholder then
      print("DEBUG: Removing placeholder/default sample at slot " .. i .. " with name '" .. sample_name .. "'")
      instrument:delete_sample_at(i)
      removed_count = removed_count + 1
      
      -- If we removed a sample before our selected sample, adjust the selected index
      if selected_sample_slot and i < selected_sample_slot then
        local song = renoise.song()
        song.selected_sample_index = selected_sample_slot - 1
        print("DEBUG: Adjusted selected sample index to " .. (selected_sample_slot - 1))
      end
    end
  end
  
  if removed_count > 0 then
    print("DEBUG: Removed " .. removed_count .. " placeholder samples")
  else
    print("DEBUG: No placeholder samples found to remove")
  end
end

-- Generate parametric geometric shape
function PCMWriterGenerateParametricShape()
  local shape_type = geometric_shapes[current_geometric_index]
  local target_data = PCMWriterGetCurrentWaveData()  -- Get current wave (A or B)
  
  for i = 1, wave_size do
    local phase = (i - 1) / wave_size
    -- Phase shift to start at zero-crossing (middle value 0.5 in 16-bit range)
    -- For diamond shapes, we want to start where value = 0 in -1..1 range
    local shifted_phase = phase  -- No phase shift initially - let's see actual shape behavior
    local value = 0
    
    if shape_type == "diamond" then
      -- Use shape_segments for faceting - multiple diamonds across the wave
      local facets = math.max(1, shape_segments)
      local facet_phase = (shifted_phase * facets) % 1
      
      -- Apply asymmetry to peak position (0.25 = centered, asymmetry shifts this)
      local peak_pos = 0.25 + (shape_asymmetry - 1.0) * 0.125  -- Range: 0.125 to 0.375
      local valley_pos = 0.75 + (shape_asymmetry - 1.0) * 0.125  -- Range: 0.625 to 0.875
      
      -- Diamond shape with asymmetric peak position
      if facet_phase < peak_pos then
        -- Rising edge: 0 to 1
        value = facet_phase / peak_pos
      elseif facet_phase < 0.5 then
        -- Falling edge: 1 to 0
        value = 1 - (facet_phase - peak_pos) / (0.5 - peak_pos)
      elseif facet_phase < valley_pos then
        -- Falling edge: 0 to -1
        value = -(facet_phase - 0.5) / (valley_pos - 0.5)
      else
        -- Rising edge: -1 to 0
        value = -1 + (facet_phase - valley_pos) / (1.0 - valley_pos)
      end
      -- Value is already in -1..1 range
      
    elseif shape_type == "double_diamond" then
      -- Use shape_segments for number of peaks across the wave
      local peaks = math.max(1, shape_segments)
      local peak_phase = (shifted_phase * peaks) % 1
      
      -- Apply asymmetry to peak positions  
      local peak1_pos = 0.125 + (shape_asymmetry - 1.0) * 0.0625  -- Range: 0.0625 to 0.1875
      local peak2_pos = 0.375 + (shape_asymmetry - 1.0) * 0.0625  -- Range: 0.3125 to 0.4375
      local valley1_pos = 0.625 + (shape_asymmetry - 1.0) * 0.0625  -- Range: 0.5625 to 0.6875
      local valley2_pos = 0.875 + (shape_asymmetry - 1.0) * 0.0625  -- Range: 0.8125 to 0.9375
      
      -- Double diamond with asymmetric peak positions
      if peak_phase < peak1_pos then
        -- Rising to first peak
        value = peak_phase / peak1_pos
      elseif peak_phase < 0.25 then
        -- Falling from first peak
        value = 1 - (peak_phase - peak1_pos) / (0.25 - peak1_pos)
      elseif peak_phase < peak2_pos then
        -- Rising to second peak  
        value = (peak_phase - 0.25) / (peak2_pos - 0.25)
      elseif peak_phase < 0.5 then
        -- Falling from second peak
        value = 1 - (peak_phase - peak2_pos) / (0.5 - peak2_pos)
      elseif peak_phase < valley1_pos then
        -- Falling to first valley
        value = -(peak_phase - 0.5) / (valley1_pos - 0.5)
      elseif peak_phase < 0.75 then
        -- Rising from first valley
        value = -1 + (peak_phase - valley1_pos) / (0.75 - valley1_pos)
      elseif peak_phase < valley2_pos then
        -- Falling to second valley
        value = -(peak_phase - 0.75) / (valley2_pos - 0.75)
      else
        -- Rising from second valley back to 0
        value = -1 + (peak_phase - valley2_pos) / (1.0 - valley2_pos)
      end
      -- Value is already in -1..1 range
      
    elseif shape_type == "asym_diamond" then
      -- Use shape_segments for faceting while keeping asymmetry for peak position
      local facets = math.max(1, shape_segments)
      local facet_phase = (shifted_phase * facets) % 1
      local peak_pos = shape_asymmetry * 0.5  -- Peak position in first half (0 to 0.5)
      
      -- Asymmetric diamond that starts and ends at 0
      if facet_phase < peak_pos then
        -- Rising edge: 0 to 1
        value = facet_phase / peak_pos
      elseif facet_phase < 0.5 then
        -- Falling edge: 1 to 0
        value = 1 - (facet_phase - peak_pos) / (0.5 - peak_pos)
      elseif facet_phase < (0.5 + peak_pos) then
        -- Falling edge: 0 to -1
        value = -(facet_phase - 0.5) / peak_pos
      else
        -- Rising edge: -1 to 0
        value = -1 + (facet_phase - 0.5 - peak_pos) / (0.5 - peak_pos)
      end
      -- Value is already in -1..1 range
      
    elseif shape_type == "pentagon" or shape_type == "hexagon" then
      -- Use shape_segments parameter for number of repetitions across the wave
      local repetitions = math.max(1, shape_segments)
      local rep_phase = (shifted_phase * repetitions) % 1
      
      -- Base number of sides (5 for pentagon, 6 for hexagon)
      local sides = (shape_type == "pentagon") and 5 or 6
      
      -- Create polygon with asymmetry affecting the vertex positions
      local seg_per_side = 1.0 / sides
      local current_side = math.floor(rep_phase / seg_per_side)
      local side_progress = (rep_phase % seg_per_side) / seg_per_side
      
      -- Apply asymmetry by shifting vertex positions
      local asymmetry_shift = (shape_asymmetry - 1.0) * 0.2  -- Range: -0.2 to +0.2
      
      -- Calculate vertex values with asymmetry
      local vertex_angle = (current_side + asymmetry_shift) * (math.pi * 2 / sides)
      local next_vertex_angle = (current_side + 1 + asymmetry_shift) * (math.pi * 2 / sides)
      
      local vertex_value = math.sin(vertex_angle)
      local next_vertex_value = math.sin(next_vertex_angle)
      
      -- Interpolate between vertices
      value = vertex_value + side_progress * (next_vertex_value - vertex_value)
      
    elseif shape_type == "exp_diamond" then
      -- Use shape_segments for faceting with exponential curve
      local facets = math.max(1, shape_segments)
      local facet_phase = (shifted_phase * facets) % 1
      
      -- Apply asymmetry to peak position
      local peak_pos = 0.5 + (shape_asymmetry - 1.0) * 0.25  -- Range: 0.25 to 0.75
      
      local curved_phase = math.pow(facet_phase, shape_curve)
      if curved_phase < peak_pos then
        value = curved_phase / peak_pos
      else
        value = 1 - (curved_phase - peak_pos) / (1.0 - peak_pos)
      end
      value = value * 2 - 1
      
    elseif shape_type == "log_diamond" then
      -- Use shape_segments for faceting with logarithmic curve
      local facets = math.max(1, shape_segments)
      local facet_phase = (shifted_phase * facets) % 1
      
      -- Apply asymmetry to peak position
      local peak_pos = 0.5 + (shape_asymmetry - 1.0) * 0.25  -- Range: 0.25 to 0.75
      
      local curved_phase = math.log(facet_phase * (math.exp(shape_curve) - 1) + 1) / shape_curve
      if curved_phase < peak_pos then
        value = curved_phase / peak_pos
      else
        value = 1 - (curved_phase - peak_pos) / (1.0 - peak_pos)
      end
      value = value * 2 - 1
      
    elseif shape_type == "fractal_diamond" then
      -- Use shape_segments for fractal iterations
      local iterations = math.max(1, shape_segments)
      
      -- Apply asymmetry to peak position for all fractal layers
      local peak_pos = 0.5 + (shape_asymmetry - 1.0) * 0.25  -- Range: 0.25 to 0.75
      
      value = 0
      for iter = 1, iterations do
        local freq = math.pow(2, iter - 1)
        local amp = 1 / iter
        local fractal_phase = (shifted_phase * freq) % 1
        local diamond_wave
        if fractal_phase < peak_pos then
          diamond_wave = fractal_phase / peak_pos
        else
          diamond_wave = 1 - (fractal_phase - peak_pos) / (1.0 - peak_pos)
        end
        value = value + diamond_wave * amp
      end
      value = (value / iterations) * 2 - 1
      
    elseif shape_type == "recursive_triangle" then
      -- Use shape_segments for complexity levels
      local levels = math.max(1, shape_segments)
      value = 0
      for level = 1, levels do
        local freq = math.pow(2, level - 1)
        local amp = 1 / level
        local triangle_phase = (shifted_phase * freq) % 1
        local triangle_wave
        if triangle_phase < 0.5 then
          triangle_wave = triangle_phase * 4 - 1
        else
          triangle_wave = 3 - triangle_phase * 4
        end
        value = value + triangle_wave * amp
      end
      value = value / levels
      
    elseif shape_type == "star_5" or shape_type == "star_8" then
      -- Use shape_segments for number of star points
      local points = math.max(3, shape_segments)
      local angle = shifted_phase * math.pi * 2
      local star_phase = (angle * points / (math.pi * 2)) % 2
      if star_phase < 1 then
        -- Outer point
        value = 0.5 + 0.5 * math.cos(angle * points)
      else
        -- Inner point  
        value = 0.5 + 0.3 * math.cos(angle * points + math.pi / points)
      end
      value = value * 2 - 1
      
    elseif shape_type == "spiral" then
      -- Use shape_segments for number of spiral turns
      local turns = math.max(1, shape_segments)
      local spiral_angle = shifted_phase * math.pi * 2 * turns
      local radius = shifted_phase * shape_asymmetry + (1 - shape_asymmetry) * 0.5
      value = radius * math.sin(spiral_angle)
      
    elseif shape_type == "bezier_diamond" then
      -- Use shape_segments for number of bezier control points
      local control_points = math.max(3, shape_segments)
      local segment = shifted_phase * (control_points - 1)
      local seg_idx = math.floor(segment)
      local seg_t = segment - seg_idx
      
      -- Generate control points for diamond-like shape
      local points = {}
      for p = 1, control_points do
        local p_phase = (p - 1) / (control_points - 1)
        if p_phase < 0.5 then
          points[p] = p_phase * 2
        else
          points[p] = 2 - p_phase * 2
        end
      end
      
      if seg_idx >= control_points - 1 then
        value = points[control_points]
      else
        value = points[seg_idx + 1] + seg_t * (points[seg_idx + 2] - points[seg_idx + 1])
      end
      value = value * 2 - 1
      
    elseif shape_type == "harmonic_diamond" then
      -- Use shape_segments for number of harmonics
      local harmonics = math.max(1, shape_segments)
      value = 0
      for h = 1, harmonics do
        local harmonic_amp = 1 / h
        local harmonic_freq = h
        local harmonic_phase = (shifted_phase * harmonic_freq) % 1
        local diamond_wave
        if harmonic_phase < 0.5 then
          diamond_wave = harmonic_phase * 2
        else
          diamond_wave = 2 - harmonic_phase * 2
        end
        value = value + diamond_wave * harmonic_amp
      end
      value = (value / harmonics) * 2 - 1
      
    elseif shape_type == "crystal" then
      -- Use shape_segments parameter for number of facets
      local facets = shape_segments
      local facet_phase = (shifted_phase * facets) % 1
      local facet_value
      local facet_sharpness = shape_asymmetry * 0.4 + 0.1  -- 0.1 to 0.5
      if facet_phase < facet_sharpness then
        facet_value = facet_phase / facet_sharpness
      elseif facet_phase < (1 - facet_sharpness) then
        facet_value = 1
      else
        facet_value = (1 - facet_phase) / facet_sharpness
      end
      value = facet_value * 2 - 1
      
    elseif shape_type == "zigzag" then
      -- Use shape_segments for number of zigs
      local zigs = math.max(1, shape_segments)
      local zig_phase = (shifted_phase * zigs) % 1
      local zig_sharpness = shape_asymmetry
      if zig_phase < zig_sharpness then
        value = zig_phase / zig_sharpness
      else
        value = (1 - zig_phase) / (1 - zig_sharpness)
      end
      value = value * 2 - 1
      
    elseif shape_type == "staircase" then
      -- Use shape_segments for number of steps
      local steps = math.max(1, shape_segments)
      local step_phase = math.floor(shifted_phase * steps) / steps
      value = step_phase * 2 - 1
      
    elseif shape_type == "heart" then
      -- Use shape_segments for heart detail/complexity
      local complexity = math.max(1, shape_segments)
      local t = shifted_phase * math.pi * 2
      local heart_x = 16 * math.pow(math.sin(t), 3)
      local heart_y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
      
      -- Add complexity with higher harmonics
      for c = 2, complexity do
        heart_y = heart_y + math.sin(t * c) / c
      end
      
      value = heart_y / 20  -- Normalize
      
    elseif shape_type == "butterfly" then
      -- Use shape_segments for butterfly wing detail
      local wing_detail = math.max(1, shape_segments)
      local t = shifted_phase * math.pi * 2
      local butterfly_r = math.exp(math.cos(t)) - 2 * math.cos(4 * t) + math.pow(math.sin(t / 12), 5)
      
      -- Add wing detail with higher harmonics
      for w = 2, wing_detail do
        butterfly_r = butterfly_r + math.sin(t * w) / w
      end
      
      value = math.sin(t) * butterfly_r / 5  -- Convert polar to y-value
      
    else
      -- Default to regular diamond: starts at 0, peaks at 0.25, back to 0 at 0.5, valley at 0.75, back to 0 at 1.0
      if shifted_phase < 0.25 then
        -- Rising edge: 0 to 1
        value = shifted_phase * 4
      elseif shifted_phase < 0.5 then
        -- Falling edge: 1 to 0
        value = 1 - (shifted_phase - 0.25) * 4
      elseif shifted_phase < 0.75 then
        -- Falling edge: 0 to -1
        value = -(shifted_phase - 0.5) * 4
      else
        -- Rising edge: -1 to 0
        value = -1 + (shifted_phase - 0.75) * 4
      end
      -- Value is already in -1..1 range
    end
    
    -- Convert from -1..1 to 0..65535
    target_data[i] = math.floor((value * 32767) + 32768)
    target_data[i] = math.max(0, math.min(65535, target_data[i]))
  end
  
  selected_sample_index = -1
  selection_start = -1
  selection_end = -1
  
  -- Update crossfaded wave
  PCMWriterUpdateCrossfadedWave()
  PCMWriterUpdateLiveSample()  -- Live update sample when generating geometric shape
  
  renoise.app():show_status(string.format("Generated %s (asym:%.1f, segs:%d, curve:%.1f, rec:%d) to Wave %s", 
    shape_type, shape_asymmetry, shape_segments, shape_curve, shape_recursion, current_wave_edit))
end

function PCMWriterCycleGeometricShape()
  current_geometric_index = current_geometric_index + 1
  if current_geometric_index > #geometric_shapes then
    current_geometric_index = 1
  end
  
  -- Update current_waveform_type to indicate geometric mode
  current_waveform_type = "geometric"
  
  -- Update the shape name display with parameters
  if pcm_dialog and pcm_dialog.visible then
    local vb = renoise.ViewBuilder()
    if vb.views.current_shape_text then
      vb.views.current_shape_text.text = string.format("%s (%.2f/%.0f)", geometric_shapes[current_geometric_index], shape_asymmetry, shape_segments)
    end
  end
  
  PCMWriterGenerateParametricShape()
end

-- Chebyshev polynomial functions (T0 to T8)
function PCMWriterChebyshevT(n, x)
  if n == 0 then
    return 1
  elseif n == 1 then
    return x
  elseif n == 2 then
    return 2 * x * x - 1
  elseif n == 3 then
    return 4 * x * x * x - 3 * x
  elseif n == 4 then
    return 8 * x * x * x * x - 8 * x * x + 1
  elseif n == 5 then
    return 16 * x * x * x * x * x - 20 * x * x * x + 5 * x
  elseif n == 6 then
    return 32 * x * x * x * x * x * x - 48 * x * x * x * x + 18 * x * x - 1
  elseif n == 7 then
    return 64 * x * x * x * x * x * x * x - 112 * x * x * x * x * x + 56 * x * x * x - 7 * x
  elseif n == 8 then
    return 128 * x * x * x * x * x * x * x * x - 256 * x * x * x * x * x * x + 160 * x * x * x * x - 32 * x * x + 1
  else
    return 0
  end
end

-- Generate Chebyshev polynomial waveform
function PCMWriterGenerateChebyshev(order, target_data, size)
  target_data = target_data or wave_data
  size = size or wave_size
  
  -- Find max value for normalization
  local max_value = 0
  local test_points = 1000
  for i = 0, test_points - 1 do
    local x = (i / test_points) * 2 - 1
    local value = math.abs(PCMWriterChebyshevT(order, x))
    if value > max_value then
      max_value = value
    end
  end
  
  if max_value == 0 then max_value = 1 end  -- Avoid division by zero
  
  -- Generate the waveform
  for i = 1, size do
    local x = math.cos(((i - 1) / size) * math.pi)  -- Chebyshev nodes
    local value = PCMWriterChebyshevT(order, x) / max_value
    target_data[i] = math.floor((value * 32767) + 32768)
    target_data[i] = math.max(0, math.min(65535, target_data[i]))
  end
  
  selected_sample_index = -1
  selection_start = -1
  selection_end = -1
  
  if waveform_canvas then
    waveform_canvas:update()
  end
  PCMWriterUpdateHexDisplay()
end

-- Mix Chebyshev polynomial into target wave
function PCMWriterMixChebyshev(order, mix_amount, target_data, size)
  target_data = target_data or wave_data
  size = size or wave_size
  
  -- Generate Chebyshev into temporary buffer
  local chebyshev_data = table.create()
  for i = 1, size do chebyshev_data[i] = 32768 end
  PCMWriterGenerateChebyshev(order, chebyshev_data, size)
  
  -- Mix into target
  for i = 1, size do
    local original = target_data[i]
    local chebyshev = chebyshev_data[i]
    target_data[i] = math.floor(original * (1 - mix_amount) + chebyshev * mix_amount)
    target_data[i] = math.max(0, math.min(65535, target_data[i]))
  end
  
  selected_sample_index = -1
  selection_start = -1
  selection_end = -1
  
  if waveform_canvas then
    waveform_canvas:update()
  end
  PCMWriterUpdateHexDisplay()
end

-- Wave A/B management functions
function PCMWriterGetCurrentWaveData()
  if current_wave_edit == "A" then
    return wave_data_a
  else
    return wave_data_b
  end
end

function PCMWriterSetCurrentWaveData(data)
  if current_wave_edit == "A" then
    wave_data_a = data
  else
    wave_data_b = data
  end
end

-- Update main wave_data with crossfaded result
function PCMWriterUpdateCrossfadedWave()
  for i = 1, wave_size do
    local value_a = wave_data_a[i]
    local value_b = wave_data_b[i]
    wave_data[i] = math.floor(value_a * (1 - crossfade_amount) + value_b * crossfade_amount)
    wave_data[i] = math.max(0, math.min(65535, wave_data[i]))
  end
  
  if waveform_canvas then
    waveform_canvas:update()
  end
  PCMWriterUpdateHexDisplay()
end

-- Swap Wave A and B
function PCMWriterSwapWaves()
  local temp = wave_data_a
  wave_data_a = wave_data_b
  wave_data_b = temp
  
  -- Invert crossfade amount
  crossfade_amount = 1.0 - crossfade_amount
  
  PCMWriterUpdateCrossfadedWave()
  renoise.app():show_status("Swapped Wave A and Wave B")
end

-- Generate basic waveforms
function PCMWriterGenerateWaveform(type, target_data, size)
  target_data = target_data or PCMWriterGetCurrentWaveData()
  size = size or wave_size
  
  -- Check if this is a MorphSynth wave type first
  if type == "morph_sine" then
    PCMWriterGenerateWaveformMorph("Sine", shape_asymmetry, target_data, size)
    return
  elseif type == "morph_triangle" then
    PCMWriterGenerateWaveformMorph("Triangle", shape_asymmetry, target_data, size)
    return
  elseif type == "morph_pulse" then
    PCMWriterGenerateWaveformMorph("Pulse", shape_asymmetry, target_data, size)
    return
  elseif type == "morph_saw" then
    PCMWriterGenerateWaveformMorph("Saw", shape_asymmetry, target_data, size)
    return
  elseif type == "morph_diode" then
    PCMWriterGenerateWaveformMorph("Diode", shape_asymmetry, target_data, size)
    return
  elseif type == "morph_gauss" then
    PCMWriterGenerateWaveformMorph("Gauss", shape_asymmetry, target_data, size)
    return
  elseif type == "morph_chebyshev" then
    PCMWriterGenerateWaveformMorph("Chebyshev", shape_asymmetry, target_data, size)
    return
  elseif type == "morph_chirp" then
    PCMWriterGenerateWaveformMorph("Chirp", shape_asymmetry, target_data, size)
    return
  elseif type == "morph_white_noise" then
    PCMWriterGenerateWaveformMorph("White Noise", shape_asymmetry, target_data, size)
    return
  elseif type == "morph_pink_noise" then
    PCMWriterGenerateWaveformMorph("Pink Noise", shape_asymmetry, target_data, size)
    return
  elseif type == "morph_brown_noise" then
    PCMWriterGenerateWaveformMorph("Brown Noise", shape_asymmetry, target_data, size)
    return
  end
  
  -- Original wave generation for backward compatibility
  for i = 1, size do
    local phase = (i - 1) / size
    local value = 0
    
    if type == "sine" then
      value = math.sin(phase * math.pi * 2)
    elseif type == "square" then
      value = phase < 0.5 and 1 or -1
    elseif type == "saw" then
      -- Saw wave starting from 0.5 (center)
      local shifted_phase = (phase + 0.5) % 1
      value = shifted_phase * 2 - 1  -- -1 to 1 ramp, but starting from center
    elseif type == "triangle" then
      if phase < 0.25 then
        value = phase * 4  -- 0 to 1
      elseif phase < 0.75 then
        value = 1 - (phase - 0.25) * 4  -- 1 to -1
      else
        value = -1 + (phase - 0.75) * 4  -- -1 to 0
      end
    elseif type == "saw_reverse" then
      -- Reverse saw wave starting from 0.5 (center)
      local shifted_phase = (phase + 0.5) % 1
      value = 1 - shifted_phase * 2  -- Linear ramp from 1 to -1, but starting from center
    elseif type == "pulse_25" then
      value = phase < 0.25 and 1 or -1  -- 25% duty cycle pulse
    elseif type == "pulse_10" then
      value = phase < 0.1 and 1 or -1  -- 10% duty cycle pulse
    elseif type == "double_sine" then
      value = math.sin(phase * math.pi * 4)  -- Double frequency sine
    elseif type == "half_sine" then
      value = phase < 0.5 and math.sin(phase * math.pi * 2) or 0  -- Half-wave rectified sine
    elseif type == "abs_sine" then
      value = math.abs(math.sin(phase * math.pi * 2))  -- Full-wave rectified sine
    elseif type == "exp_curve" then
      value = (math.exp(phase * 3) - 1) / (math.exp(3) - 1) * 2 - 1  -- Exponential curve
    elseif type == "log_curve" then
      value = math.log(phase * (math.exp(1) - 1) + 1) * 2 - 1  -- Logarithmic curve
    elseif type == "stepped" then
      -- Stepped wave starting from 0.5 (center)
      local shifted_phase = (phase + 0.5) % 1
      local steps = 8
      local step_phase = math.floor(shifted_phase * steps) / steps
      value = step_phase * 2 - 1  -- 8-step quantized ramp
    elseif type == "ziggurat" then
      -- Ziggurat/pyramid wave - triangle with flat top starting from 0.5
      local shifted_phase = (phase + 0.1) % 1  -- Shift to start at middle of ramp (0.5 value)
      if shifted_phase < 0.2 then
        value = shifted_phase * 5  -- 0 to 1 (ramp up)
      elseif shifted_phase < 0.8 then
        value = 1  -- flat top
      else
        value = 1 - (shifted_phase - 0.8) * 5  -- 1 to 0 (ramp down)
      end
      value = value * 2 - 1  -- Convert to -1 to 1
    elseif type == "trapezoid" then
      -- Trapezoid wave - shift to start at 0.5
      local shifted_phase = (phase + 0.125) % 1  -- Shift to start at middle of ramp (0.5 value)
      if shifted_phase < 0.25 then
        value = shifted_phase * 4  -- 0 to 1
      elseif shifted_phase < 0.75 then
        value = 1  -- flat top
      else
        value = 1 - (shifted_phase - 0.75) * 4  -- 1 to 0
      end
      value = value * 2 - 1  -- Convert to -1 to 1
    elseif type == "chirp" then
      -- Frequency sweep (chirp) starting from 0.5
      local shifted_phase = (phase + 0.5) % 1  -- Start at 0.5 like other waveforms
      local freq = 1 + shifted_phase * 8  -- Frequency sweeps from 1 to 9
      value = math.sin(shifted_phase * shifted_phase * math.pi * 2 * freq * 4)
    elseif type == "morph" then
      -- Morphing wave (sine to square) - starts at 0 (center value)
      local morph_amount = phase
      local sine_val = math.sin(phase * math.pi * 2)
      local square_val = phase < 0.5 and 1 or -1
      value = sine_val * (1 - morph_amount) + square_val * morph_amount
    elseif type == "harmonic_5th" then
      -- Sine with 5th harmonic starting from 0.5
      local shifted_phase = (phase + 0.5) % 1  -- Start at 0.5 like other waveforms
      value = math.sin(shifted_phase * math.pi * 2) + 0.3 * math.sin(shifted_phase * math.pi * 2 * 5)
    elseif type == "harmonic_3rd" then
      -- Sine with 3rd harmonic (more organic) starting from 0.5
      local shifted_phase = (phase + 0.5) % 1  -- Start at 0.5 like other waveforms
      value = math.sin(shifted_phase * math.pi * 2) + 0.33 * math.sin(shifted_phase * math.pi * 2 * 3)
    elseif type == "organ" then
      -- Organ-like (multiple harmonics) starting from 0.5
      local shifted_phase = (phase + 0.5) % 1  -- Start at 0.5 like other waveforms
      value = math.sin(shifted_phase * math.pi * 2) + 
              0.5 * math.sin(shifted_phase * math.pi * 2 * 2) +
              0.25 * math.sin(shifted_phase * math.pi * 2 * 3) +
              0.125 * math.sin(shifted_phase * math.pi * 2 * 4)
    elseif type == "metallic" then
      -- Metallic/bell-like (inharmonic) starting from 0.5
      local shifted_phase = (phase + 0.5) % 1  -- Start at 0.5 like other waveforms
      value = math.sin(shifted_phase * math.pi * 2) + 
              0.3 * math.sin(shifted_phase * math.pi * 2 * 2.1) +
              0.2 * math.sin(shifted_phase * math.pi * 2 * 3.3) +
              0.1 * math.sin(shifted_phase * math.pi * 2 * 4.7)
    elseif type == "vocal" then
      -- Vocal-like formants starting from 0.5
      local shifted_phase = (phase + 0.5) % 1  -- Start at 0.5 like other waveforms
      value = math.sin(shifted_phase * math.pi * 2) + 
              0.4 * math.sin(shifted_phase * math.pi * 2 * 2) +
              0.2 * math.sin(shifted_phase * math.pi * 2 * 3) +
              0.3 * math.sin(shifted_phase * math.pi * 2 * 5)
    elseif type == "digital" then
      -- Digital/bitcrushed sound - start at 0.5
      local bits = 4
      local levels = math.pow(2, bits)
      local shifted_phase = (phase + 0.5) % 1
      local quantized = math.floor((shifted_phase * 2 - 1) * levels) / levels
      value = quantized
    elseif type == "wobble" then
      -- Wobble bass-style starting from 0.5
      local shifted_phase = (phase + 0.5) % 1  -- Start at 0.5 like other waveforms
      local lfo_freq = 0.25
      local lfo = math.sin(shifted_phase * math.pi * 2 * lfo_freq)
      local carrier_freq = 1 + lfo * 2
      value = math.sin(shifted_phase * math.pi * 2 * carrier_freq)
    
    -- GEOMETRIC SHAPES
    elseif type == "doubletriangle" then
      -- Double triangle (two peaks) starting from 0.5
      local shifted_phase = (phase + 0.25) % 1  -- Shift to start at middle value (0.5)
      local local_phase = (shifted_phase * 2) % 1
      if local_phase < 0.5 then
        value = local_phase * 2
      else
        value = 2 - local_phase * 2
      end
      value = value * 2 - 1
    
    elseif type == "asym_diamond" then
      -- Asymmetric diamond - use shape_asymmetry for peak position, starting from 0.5
      local shifted_phase = (phase + 0.25) % 1  -- Shift to start at middle value (0.5)
      local peak_pos = shape_asymmetry  -- Use shape parameter
      if shifted_phase < peak_pos then
        value = shifted_phase / peak_pos
      else
        value = (1 - shifted_phase) / (1 - peak_pos)
      end
      value = value * 2 - 1
    
    elseif type == "pentagon" then
      -- Pentagon wave - use shape_segments for number of sides
      local shifted_phase = (phase + 0.5) % 1
      local segments = {}
      for seg = 0, shape_segments do
        local seg_phase = seg / shape_segments
        local seg_value = math.sin(seg_phase * math.pi * 2) * (seg % 2 == 0 and 1 or shape_asymmetry)
        table.insert(segments, {seg_phase, seg_value})
      end
      
      -- Find which segment we're in
      for seg = 1, #segments - 1 do
        local start_phase = segments[seg][1]
        local end_phase = segments[seg + 1][1]
        if shifted_phase >= start_phase and shifted_phase <= end_phase then
          local seg_progress = (shifted_phase - start_phase) / (end_phase - start_phase)
          local start_val = segments[seg][2]
          local end_val = segments[seg + 1][2]
          value = start_val + seg_progress * (end_val - start_val)
          break
        end
      end
    
    elseif type == "hexagon" then
      -- Hexagon wave - use shape_segments for number of sides
      local segments = {}
      for seg = 0, shape_segments do
        local seg_phase = seg / shape_segments
        local seg_value = math.sin(seg_phase * math.pi * 2) * (seg % 2 == 0 and 1 or shape_asymmetry)
        table.insert(segments, {seg_phase, seg_value})
      end
      
      -- Find which segment we're in
      for seg = 1, #segments - 1 do
        local start_phase = segments[seg][1]
        local end_phase = segments[seg + 1][1]
        if phase >= start_phase and phase <= end_phase then
          local seg_progress = (phase - start_phase) / (end_phase - start_phase)
          local start_val = segments[seg][2]
          local end_val = segments[seg + 1][2]
          value = start_val + seg_progress * (end_val - start_val)
          break
        end
      end
    
    elseif type == "exp_diamond" then
      -- Exponential phase diamond - start at 0.5
      local shifted_phase = (phase + 0.5) % 1
      local curved_phase = math.pow(shifted_phase, 2)  -- Exponential curve
      if curved_phase < 0.5 then
        value = curved_phase * 2
      else
        value = 2 - curved_phase * 2
      end
      value = value * 2 - 1
    
    elseif type == "log_diamond" then
      -- Logarithmic phase diamond starting from 0.5
      local shifted_phase = (phase + 0.25) % 1  -- Shift to start at middle value (0.5)
      local curved_phase = math.log(shifted_phase * (math.exp(1) - 1) + 1)
      if curved_phase < 0.5 then
        value = curved_phase * 2
      else
        value = 2 - curved_phase * 2
      end
      value = value * 2 - 1
    
    elseif type == "fractal_diamond" then
      -- Fractal diamond (diamond within diamond) starting from 0.5
      local shifted_phase = (phase + 0.25) % 1  -- Shift to start at middle value (0.5)
      local main_diamond
      if shifted_phase < 0.5 then
        main_diamond = shifted_phase * 2
      else
        main_diamond = 2 - shifted_phase * 2
      end
      main_diamond = main_diamond * 2 - 1
      
      -- Add smaller diamond at 3x frequency
      local sub_phase = (shifted_phase * 3) % 1
      local sub_diamond
      if sub_phase < 0.5 then
        sub_diamond = sub_phase * 2
      else
        sub_diamond = 2 - sub_phase * 2
      end
      sub_diamond = sub_diamond * 2 - 1
      
      value = main_diamond + sub_diamond * 0.3  -- Mix them
    
    elseif type == "recursive_triangle" then
      -- Recursive triangles - use shape_segments for recursion levels
      local shifted_phase = (phase + 0.5) % 1
      local levels = math.max(1, math.floor(shape_segments / 2))  -- 1 to 8 levels
      value = 0
      for level = 1, levels do
        local freq = math.pow(2, level - 1)
        local amp = 1 / level
        local triangle_phase = (shifted_phase * freq) % 1
        local triangle_wave
        local peak_pos = shape_asymmetry  -- Use asymmetry for triangle shape
        if triangle_phase < peak_pos then
          triangle_wave = triangle_phase / peak_pos * 2 - 1  -- -1 to 1
        else
          triangle_wave = 1 - (triangle_phase - peak_pos) / (1 - peak_pos) * 2  -- 1 to -1
        end
        value = value + triangle_wave * amp
      end
      value = value / levels  -- Normalize
    
    elseif type == "star_5" then
      -- 5-pointed star shape (using polar coordinates)
      local angle = phase * math.pi * 2
      local points = 5
      local radius = 0.5 + 0.5 * math.cos(angle * points)
      value = radius * math.sin(angle)
    
    elseif type == "star_8" then
      -- 8-pointed star shape
      local angle = phase * math.pi * 2
      local points = 8
      local radius = 0.5 + 0.5 * math.cos(angle * points)
      value = radius * math.sin(angle)
    
    elseif type == "spiral" then
      -- Spiral shapes
      local angle = phase * math.pi * 8  -- Multiple rotations
      local radius = phase  -- Expanding radius
      value = radius * math.sin(angle)
    
    elseif type == "bezier_diamond" then
      -- Bezier diamond starting from 0.5
      local shifted_phase = (phase + 0.25) % 1  -- Shift to start at middle value (0.5)
      local t = shifted_phase
      local p0, p1, p2, p3 = 0, 1.5, 1.5, 0  -- Control points for diamond shape
      value = math.pow(1-t, 3) * p0 + 3 * math.pow(1-t, 2) * t * p1 + 
              3 * (1-t) * math.pow(t, 2) * p2 + math.pow(t, 3) * p3
      value = value * 2 - 1  -- Normalize to -1 to 1
    
    elseif type == "harmonic_diamond" then
      -- Diamond harmonics starting from 0.5
      local shifted_phase = (phase + 0.25) % 1  -- Shift to start at middle value (0.5)
      value = 0
      for h = 1, 9, 2 do  -- Odd harmonics only
        local phase_offset = (h == 1) and 0 or math.pi/2
        local harmonic_amp = 1 / h  -- Decreasing amplitude
        value = value + math.sin(shifted_phase * math.pi * 2 * h + phase_offset) * harmonic_amp
      end
      value = value / 3  -- Normalize
    
    elseif type == "crystal" then
      -- Crystal/gem shape - use shape_segments for facets and shape_asymmetry for sharpness
      local shifted_phase = (phase + 0.25) % 1  -- Shift to start at middle value (0.5)
      local facets = shape_segments
      local facet_phase = (shifted_phase * facets) % 1
      local facet_value
      local facet_sharpness = shape_asymmetry * 0.4 + 0.1  -- 0.1 to 0.5
      if facet_phase < facet_sharpness then
        facet_value = facet_phase / facet_sharpness  -- Rise
      elseif facet_phase < (1 - facet_sharpness) then
        facet_value = 1  -- Flat top
      else
        facet_value = (1 - facet_phase) / facet_sharpness  -- Fall
      end
      value = facet_value * 2 - 1
    
    elseif type == "zigzag" then
      -- Zigzag pattern - use shape_segments for number of zigzags
      local shifted_phase = (phase + 0.25) % 1  -- Shift to start at middle value (0.5)
      local zigzags = shape_segments
      local zig_phase = (shifted_phase * zigzags) % 1
      local steepness = shape_asymmetry * 0.8 + 0.2  -- 0.2 to 1.0
      if zig_phase < steepness then
        value = zig_phase * (2 / steepness) - 1  -- -1 to 1
      else
        value = 1 - (zig_phase - steepness) * (2 / (1 - steepness))  -- 1 to -1
      end
    
    elseif type == "staircase" then
      -- Staircase/stepped diamond - use shape_segments for number of steps
      local shifted_phase = (phase + 0.25) % 1  -- Shift to start at middle value (0.5)
      local steps = shape_segments
      local step_size = 1 / steps
      local step_phase = math.floor(shifted_phase / step_size) * step_size
      local peak_pos = shape_asymmetry  -- Use asymmetry for peak position
      if step_phase < peak_pos then
        value = step_phase / peak_pos
      else
        value = (1 - step_phase) / (1 - peak_pos)
      end
      value = value * 2 - 1
    
    elseif type == "heart" then
      -- Heart shape starting from 0.5
      local shifted_phase = (phase + 0.25) % 1  -- Shift to start at middle value (0.5)
      local t = shifted_phase * math.pi * 2
      local x = 16 * math.pow(math.sin(t), 3)
      local y = 13 * math.cos(t) - 5 * math.cos(2*t) - 2 * math.cos(3*t) - math.cos(4*t)
      value = y / 20  -- Normalize heart shape
    
    elseif type == "butterfly" then
      -- Butterfly shape
      local t = phase * math.pi * 2
      local r = math.exp(math.cos(t)) - 2 * math.cos(4*t) + math.pow(math.sin(t/12), 5)
      value = r * math.sin(t) / 3  -- Normalize
    
    -- NOISE WAVEFORMS (moved to end)
    elseif type == "noise" then
      value = math.random() * 2 - 1  -- White noise
    elseif type == "pink_noise" then
      -- Approximation of pink noise using multiple octaves
      value = (math.random() * 2 - 1) * 1.0 +
              (math.random() * 2 - 1) * 0.5 +
              (math.random() * 2 - 1) * 0.25 +
              (math.random() * 2 - 1) * 0.125
      value = value / 1.875  -- Normalize
    
    else
      -- Default to sine
      value = math.sin(phase * math.pi * 2)
    end
    
    -- Convert from -1..1 to 0..65535
    target_data[i] = math.floor((value * 32767) + 32768)
    target_data[i] = math.max(0, math.min(65535, target_data[i]))
  end
  selected_sample_index = -1
  
  -- Update crossfaded wave if we're working with Wave A/B system
  if target_data == wave_data_a or target_data == wave_data_b then
    PCMWriterUpdateCrossfadedWave()
  end
end

-- Cubic interpolation function
function PCMWriterCubicInterpolate(y0, y1, y2, y3, mu)
  local mu2 = mu * mu
  local a0 = y3 - y2 - y0 + y1
  local a1 = y0 - y1 - a0
  local a2 = y2 - y0
  local a3 = y1
  return a0 * mu * mu2 + a1 * mu2 + a2 * mu + a3
end

-- Bezier curve interpolation
function PCMWriterBezierInterpolate(p0, p1, p2, p3, t)
  local t2 = t * t
  local t3 = t2 * t
  local mt = 1 - t
  local mt2 = mt * mt
  local mt3 = mt2 * mt
  return mt3 * p0 + 3 * mt2 * t * p1 + 3 * mt * t2 * p2 + t3 * p3
end

-- Hex editor functions (need to be defined before mouse handler)
function PCMWriterUpdateHexDisplay()
  if not hex_buttons then return end
  
  -- Set flag to prevent cascading updates
  updating_hex_display = true
  
  -- Save cursor position to prevent it from being changed by notifiers
  local saved_cursor_position = selected_sample_index
  
  -- Only update buttons that exist on current page - selective updates only
  local current_page = hex_editor_page
  local start_sample = current_page * hex_samples_per_page + 1
  local end_sample = math.min(start_sample + hex_samples_per_page - 1, wave_size)
  
  for idx = start_sample, end_sample do
    if hex_buttons[idx] then
      local target_data = PCMWriterGetCurrentWaveData()
      hex_buttons[idx].text = string.format("%04X", target_data[idx])
    end
  end
  
  -- Restore cursor position to prevent cascading cursor changes
  selected_sample_index = saved_cursor_position
  
  -- Clear flag
  updating_hex_display = false
end

function PCMWriterHighlightSample(idx)
  -- Note: TextFields don't have a color property according to the API,
  -- so we only track the selected sample index for waveform visualization
  
  -- Don't change cursor position if we're updating hex display to prevent cascading updates
  if updating_hex_display then
    return
  end
  
  if idx >= 1 and idx <= wave_size then
    selected_sample_index = idx
    
    -- No automatic page navigation - let user navigate manually
    -- This improves performance significantly
  end
end

-- Canvas rendering function with zoom, pan, and interpolation
function PCMWriterRenderWaveform(ctx)
  local w, h = wavetable_canvas_width, ctx.size.height  -- Use configurable width
  ctx:clear_rect(0, 0, w, h)

  -- Calculate visible range based on zoom and pan
  local visible_start = math.max(1, math.floor(pan_offset + 1))
  local visible_end = math.min(wave_size, math.floor(pan_offset + wave_size / zoom_factor))
  local visible_samples = visible_end - visible_start + 1

  if visible_samples <= 0 then return end



  -- Draw grid
  ctx.stroke_color = COLOR_GRID_LINES
  ctx.line_width = 1
  for i = 0, 10 do
    local x = (i / 10) * w
    ctx:begin_path()
    ctx:move_to(x, 0)
    ctx:line_to(x, h)
    ctx:stroke()
  end
  for i = 0, 10 do
    local y = (i / 10) * h
    ctx:begin_path()
    ctx:move_to(0, y)
    ctx:line_to(w, y)
    ctx:stroke()
  end

  -- Draw zero line (center)
  ctx.stroke_color = COLOR_ZERO_LINE
  ctx.line_width = 1
  local center_y = h / 2
  ctx:begin_path()
  ctx:move_to(0, center_y)
  ctx:line_to(w, center_y)
  ctx:stroke()

  -- Draw waves with current editing wave highlighted with thick lines
  -- Wave A (always RED)
  if current_wave_edit == "A" then
    -- Currently editing Wave A - draw it thick red
    ctx.stroke_color = COLOR_WAVE_A_ACTIVE
    ctx.line_width = 2
  else
    -- Not editing Wave A - draw it thin red
    ctx.stroke_color = COLOR_WAVE_A_INACTIVE
    ctx.line_width = 1
  end
  ctx:begin_path()
  for pixel = 0, w - 1 do
    local sample_pos = visible_start + (pixel / (w - 1)) * (visible_samples - 1)
    local i = math.floor(sample_pos)
    local frac = sample_pos - i
    local i1 = math.max(1, math.min(wave_size, i))
    local i2 = math.max(1, math.min(wave_size, i + 1))
    local interp_value = wave_data_a[i1] + frac * (wave_data_a[i2] - wave_data_a[i1])
    local x = pixel
    local y = h - (interp_value / 65535 * h)
    if pixel == 0 then
      ctx:move_to(x, y)
    else
      ctx:line_to(x, y)
    end
  end
  ctx:stroke()
  
  -- Wave B (always BLUE)
  if current_wave_edit == "B" then
    -- Currently editing Wave B - draw it thick blue
    ctx.stroke_color = COLOR_WAVE_B_ACTIVE
    ctx.line_width = 2
  else
    -- Not editing Wave B - draw it thin blue
    ctx.stroke_color = COLOR_WAVE_B_INACTIVE
    ctx.line_width = 1
  end
  ctx:begin_path()
  for pixel = 0, w - 1 do
    local sample_pos = visible_start + (pixel / (w - 1)) * (visible_samples - 1)
    local i = math.floor(sample_pos)
    local frac = sample_pos - i
    local i1 = math.max(1, math.min(wave_size, i))
    local i2 = math.max(1, math.min(wave_size, i + 1))
    local interp_value = wave_data_b[i1] + frac * (wave_data_b[i2] - wave_data_b[i1])
    local x = pixel
    local y = h - (interp_value / 65535 * h)
    if pixel == 0 then
      ctx:move_to(x, y)
    else
      ctx:line_to(x, y)
    end
  end
  ctx:stroke()
  
  -- Draw crossfaded waveform (PURPLE for crossfade result)
  ctx.stroke_color = COLOR_CROSSFADED_WAVEFORM
  ctx.line_width = 4  -- Twice as thick to emphasize the final result
  ctx:begin_path()

  -- Draw waveform across full canvas width with selected interpolation
  if canvas_interpolation_mode == "linear" then
    -- Linear interpolation across full canvas width
    for pixel = 0, w - 1 do
      local sample_pos = visible_start + (pixel / (w - 1)) * (visible_samples - 1)
      local i = math.floor(sample_pos)
      local frac = sample_pos - i
      local i1 = math.max(1, math.min(wave_size, i))
      local i2 = math.max(1, math.min(wave_size, i + 1))
      
      -- Linear interpolation between samples
      local interp_value = wave_data[i1] + frac * (wave_data[i2] - wave_data[i1])
      
      local x = pixel
      local y = h - (interp_value / 65535 * h)
      
      if pixel == 0 then
        ctx:move_to(x, y)
      else
        ctx:line_to(x, y)
      end
    end
  else
    -- Advanced interpolation modes for canvas display
    for pixel = 0, w - 1 do
      local sample_pos = visible_start + (pixel / (w - 1)) * (visible_samples - 1)
      local x = pixel
      local y
      
      if canvas_interpolation_mode == "cubic" then
        -- Cubic interpolation
        local i = math.floor(sample_pos)
        local frac = sample_pos - i
        local i0 = math.max(1, math.min(wave_size, i - 1))
        local i1 = math.max(1, math.min(wave_size, i))
        local i2 = math.max(1, math.min(wave_size, i + 1))
        local i3 = math.max(1, math.min(wave_size, i + 2))
        local interp_value = PCMWriterCubicInterpolate(wave_data[i0], wave_data[i1], wave_data[i2], wave_data[i3], frac)
        y = h - (math.max(0, math.min(65535, interp_value)) / 65535 * h)
        
      elseif canvas_interpolation_mode == "bezier" then
        -- Bezier interpolation
        local i = math.floor(sample_pos)
        local frac = sample_pos - i
        local i1 = math.max(1, math.min(wave_size, i))
        local i2 = math.max(1, math.min(wave_size, i + 1))
        local control1 = wave_data[i1] + (i1 > 1 and (wave_data[i1] - wave_data[i1-1]) * 0.3 or 0)
        local control2 = wave_data[i2] - (i2 < wave_size and (wave_data[i2+1] - wave_data[i2]) * 0.3 or 0)
        local interp_value = PCMWriterBezierInterpolate(wave_data[i1], control1, control2, wave_data[i2], frac)
        y = h - (math.max(0, math.min(65535, interp_value)) / 65535 * h)
      else
        -- Fallback to linear if unknown mode
        local i = math.floor(sample_pos)
        local frac = sample_pos - i
        local i1 = math.max(1, math.min(wave_size, i))
        local i2 = math.max(1, math.min(wave_size, i + 1))
        local interp_value = wave_data[i1] + frac * (wave_data[i2] - wave_data[i1])
        y = h - (interp_value / 65535 * h)
      end
      
      if pixel == 0 then
        ctx:move_to(x, y)
      else
        ctx:line_to(x, y)
      end
    end
  end
  ctx:stroke()

  -- Draw sample points if enabled and zoomed in enough
  if show_sample_points and zoom_factor >= 2.0 then
    ctx.fill_color = COLOR_SAMPLE_POINTS
    for i = visible_start, visible_end do
      local sample_in_visible = i - visible_start
      local x = (sample_in_visible / (visible_samples - 1)) * w
      local y = h - (wave_data[i] / 65535 * h)
      ctx:begin_path()
      ctx:arc(x, y, 3, 0, math.pi * 2, false)
      ctx:fill()
    end
  end

  -- Selected sample highlight
  if selected_sample_index > 0 and selected_sample_index >= visible_start and selected_sample_index <= visible_end then
    local sample_in_visible = selected_sample_index - visible_start
    local x = (sample_in_visible / (visible_samples - 1)) * w
    
    -- Get Y position from the currently selected wave (A or B)
    local target_data = PCMWriterGetCurrentWaveData()
    local y = h - (target_data[selected_sample_index] / 65535 * h)
    
    -- Draw vertical line
    ctx.stroke_color = COLOR_SELECTED_LINE
    ctx.line_width = 2
    ctx:begin_path()
    ctx:move_to(x, 0)
    ctx:line_to(x, h)
    ctx:stroke()
    
    -- Draw selected point
    ctx.fill_color = COLOR_SELECTED_POINT
    ctx:begin_path()
    ctx:arc(x, y, 5, 0, math.pi * 2, false)
    ctx:fill()
  end

  -- Draw selection overlay
  if selection_start > 0 and selection_end > 0 and selection_start <= selection_end then
    local sel_start = math.max(visible_start, selection_start)
    local sel_end = math.min(visible_end, selection_end)
    
    if sel_start <= sel_end then
      local start_in_visible = sel_start - visible_start
      local end_in_visible = sel_end - visible_start
      local start_x = (start_in_visible / (visible_samples - 1)) * w
      local end_x = (end_in_visible / (visible_samples - 1)) * w
      
      -- Draw selection background
      ctx.fill_color = COLOR_SELECTION_BACKGROUND
      ctx:begin_path()
      ctx:rect(start_x, 0, end_x - start_x, h)
      ctx:fill()
      
      -- Draw selection borders
      ctx.stroke_color = COLOR_SELECTION_BORDERS
      ctx.line_width = 2
      ctx:begin_path()
      ctx:move_to(start_x, 0)
      ctx:line_to(start_x, h)
      ctx:move_to(end_x, 0)
      ctx:line_to(end_x, h)
      ctx:stroke()
    end
  end

  -- Draw zoom info
  ctx.fill_color = COLOR_ZOOM_INFO
  local zoom_text = string.format("Zoom: %.1fx | Samples: %d-%d", zoom_factor, visible_start, visible_end)
  -- Note: Canvas doesn't support text, so we'll show this in status instead
end

-- Draw a line between two sample points to prevent gaps during fast mouse movement
function PCMWriterDrawLineBetweenSamples(start_idx, start_value, end_idx, end_value, target_data)
  target_data = target_data or PCMWriterGetCurrentWaveData()
  
  if start_idx == end_idx then
    target_data[start_idx] = end_value
    return
  end
  
  -- Ensure start_idx is less than end_idx
  if start_idx > end_idx then
    start_idx, end_idx = end_idx, start_idx
    start_value, end_value = end_value, start_value
  end
  
  -- Interpolate between the two points
  local distance = end_idx - start_idx
  for i = start_idx, end_idx do
    local progress = (i - start_idx) / distance
    local interpolated_value = math.floor(start_value + progress * (end_value - start_value))
    target_data[i] = math.max(0, math.min(65535, interpolated_value))
  end
end

-- Mouse handler with zoom and pan support
function PCMWriterHandleMouse(ev)
  local w = wavetable_canvas_width  -- Use configurable width
  local h = waveform_canvas.height
  local visible_start = math.max(1, math.floor(pan_offset + 1))
  local visible_end = math.min(wave_size, math.floor(pan_offset + wave_size / zoom_factor))
  local visible_samples = visible_end - visible_start + 1
  
  -- Handle mouse leave event - immediately stop drawing when mouse leaves canvas
  if ev.type == "exit" then
    if is_drawing then
      is_drawing = false
      last_sample_index = -1
      last_mouse_x = -1
      last_mouse_y = -1
      print("Drawing stopped: mouse left canvas")
    end
    return
  end
  
  -- Extended dragging area: 20 pixels above and below the canvas for safe drawing
  local drag_margin = 20
  local mouse_in_extended_bounds = ev.position.x >= 0 and ev.position.x < w and 
                                   ev.position.y >= -drag_margin and ev.position.y < h + drag_margin
  
  -- Handle mouse outside extended bounds - reset drawing state
  if not mouse_in_extended_bounds then
    if is_drawing then
      is_drawing = false
      last_sample_index = -1
      last_mouse_x = -1
      last_mouse_y = -1
      print("Drawing stopped: mouse outside extended canvas bounds")
    end
    
    -- Always handle mouse up, even outside bounds
    if ev.type == "up" and ev.button == "left" then
      is_drawing = false
      last_sample_index = -1
      last_mouse_x = -1
      last_mouse_y = -1
    end
    
    return  -- Exit early if mouse is outside extended canvas
  end
  
  -- Mouse is within extended bounds - continue processing
  local rel_x = ev.position.x / w
  
  -- Always clamp Y position to canvas bounds for drawing calculations
  -- This ensures drawing values stay valid even when mouse is in safe area
  local clamped_y = math.max(0, math.min(h, ev.position.y))
  local rel_y = clamped_y / h
  
  -- Fixed calculation to properly map mouse position to sample index
  -- Map the full canvas width to the full range of visible samples
  local sample_in_visible_range = math.floor(rel_x * visible_samples) + 1
  
  -- Ensure we can reach the last sample when clicking at the right edge
  if sample_in_visible_range > visible_samples then
    sample_in_visible_range = visible_samples
  end
  
  local idx = visible_start + sample_in_visible_range - 1
  
  -- Debug output for troubleshooting last frame issue
  if ev.type == "down" and ev.button == "left" then
    print(string.format("DEBUG: Mouse click - x=%d, rel_x=%.3f, visible_range=%d-%d, sample_in_range=%d, final_idx=%d, wave_size=%d", 
      ev.position.x, rel_x, visible_start, visible_end, sample_in_visible_range, idx, wave_size))
  end
  
  -- Clamp idx to valid range (this should not be needed but keeping as safety)
  idx = math.max(1, math.min(wave_size, idx))
  
  -- Calculate current value based on clamped Y position
  local current_value = math.floor((1 - rel_y) * 65535)
  current_value = math.max(0, math.min(65535, current_value))  -- Clamp value
  
  -- Handle drawing events - now works in extended bounds with clamped Y values
  if ev.type == "down" and ev.button == "left" then
    hex_field_has_focus = false  -- Reset hex focus when clicking canvas
    selected_sample_index = idx  -- Move red cursor to click position
    print("DEBUG: Canvas clicked - forcing hex_field_has_focus to false")
    is_drawing = true
    local target_data = PCMWriterGetCurrentWaveData()
    target_data[idx] = current_value
    PCMWriterUpdateCrossfadedWave()
    last_sample_index = idx
    last_mouse_x = ev.position.x
    last_mouse_y = clamped_y  -- Store clamped Y for interpolation
    waveform_canvas:update()
    PCMWriterUpdateHexDisplay()
    PCMWriterUpdateLiveSample()  -- Update live sample when drawing
    PCMWriterHighlightSample(idx)
  elseif ev.type == "move" and is_drawing then
    -- Continue drawing while dragging with interpolation to prevent gaps
    local target_data = PCMWriterGetCurrentWaveData()
    if last_sample_index > 0 and last_sample_index ~= idx then
      -- Draw line between last position and current position
      local last_value = math.floor((1 - (last_mouse_y / h)) * 65535)
      last_value = math.max(0, math.min(65535, last_value))  -- Clamp last value
      PCMWriterDrawLineBetweenSamples(last_sample_index, last_value, idx, current_value, target_data)
    else
      -- Just set current sample if no previous position or same position
      target_data[idx] = current_value
    end
    PCMWriterUpdateCrossfadedWave()
    
    last_sample_index = idx
    last_mouse_x = ev.position.x
    last_mouse_y = clamped_y  -- Store clamped Y for interpolation
    selected_sample_index = idx  -- Move red cursor while dragging
    waveform_canvas:update()
    PCMWriterUpdateHexDisplay()
    PCMWriterUpdateLiveSample()  -- Update live sample when dragging
    PCMWriterHighlightSample(idx)
  elseif ev.type == "up" and ev.button == "left" then
    is_drawing = false
    last_sample_index = -1
    last_mouse_x = -1
    last_mouse_y = -1
  elseif ev.type == "move" and not is_drawing then
    -- Don't change selected_sample_index when just hovering
    -- Just update the canvas to show hover position visually if needed
  end
  
  -- Always handle mouse up to ensure drawing state is reset
  if ev.type == "up" and ev.button == "left" then
    is_drawing = false
    last_sample_index = -1
    last_mouse_x = -1
    last_mouse_y = -1
  end
end

-- Keyboard handler for arrow key controls
function PCMWriterHandleKeyboard(dialog, key)
  -- Debug output for the specific issue
  if key.name == "up" and key.modifiers == "shift" then
    print("DEBUG: Shift+UP pressed at position " .. tostring(selected_sample_index) .. " (hex_focus=" .. tostring(hex_field_has_focus) .. ")")
  end

  -- Hex editor navigation mode removed - canvas navigation always takes priority
  
  -- Always prioritize canvas navigation - reset hex focus on any arrow key usage
  if key.name == "up" or key.name == "down" or key.name == "left" or key.name == "right" then
    hex_field_has_focus = false
    print("DEBUG: Arrow key detected - forcing hex_field_has_focus to false")
  end
  
  -- Check if cursor position is valid first
  if selected_sample_index <= 0 then
    print("DEBUG: WARNING - selected_sample_index is " .. tostring(selected_sample_index) .. " which is invalid! Setting to 1")
    selected_sample_index = 1
  end
  
  -- Waveform canvas navigation mode (always active when sample is selected)
  if selected_sample_index > 0 and selected_sample_index <= wave_size then
    print("DEBUG: In waveform canvas mode, processing key: " .. tostring(key.name) .. " (hex_focus=" .. tostring(hex_field_has_focus) .. ") - selected_sample_index = " .. tostring(selected_sample_index))
    if key.name == "up" then
      print("DEBUG: Processing UP key - before change, position = " .. tostring(selected_sample_index))
      -- UP = Increase value at current position
      local step = cursor_step_size
      if key.modifiers == "shift" then
        step = step * 10  -- 10x faster with Shift
        print("DEBUG: UP with Shift - step = " .. tostring(step))
      end
      
      local half_width = math.floor(cursor_width / 2)
      local start_idx = math.max(1, selected_sample_index - half_width)
      local end_idx = math.min(wave_size, selected_sample_index + half_width)
      local target_data = PCMWriterGetCurrentWaveData()
      
      for i = start_idx, end_idx do
        target_data[i] = math.min(65535, target_data[i] + step)
      end
      
      PCMWriterUpdateCrossfadedWave()
      waveform_canvas:update()
      PCMWriterUpdateHexDisplay()
      PCMWriterUpdateLiveSample()  -- Update live sample when using keyboard
      return nil  -- Consume the key
    elseif key.name == "down" then
      -- DOWN = Decrease value at current position
      local step = cursor_step_size
      if key.modifiers == "shift" then
        step = step * 10  -- 10x faster with Shift
        print("DEBUG: DOWN with Shift - step = " .. tostring(step))
      end
      
      local half_width = math.floor(cursor_width / 2)
      local start_idx = math.max(1, selected_sample_index - half_width)
      local end_idx = math.min(wave_size, selected_sample_index + half_width)
      local target_data = PCMWriterGetCurrentWaveData()
      
      for i = start_idx, end_idx do
        target_data[i] = math.max(0, target_data[i] - step)
      end
      
      PCMWriterUpdateCrossfadedWave()
      waveform_canvas:update()
      PCMWriterUpdateHexDisplay()
      PCMWriterUpdateLiveSample()  -- Update live sample when using keyboard
      return nil  -- Consume the key
    elseif key.name == "left" then
      print("DEBUG: Processing LEFT key - before change, position = " .. tostring(selected_sample_index))
      -- LEFT = Move cursor position left
      local step = 1
      if key.modifiers == "shift" then
        step = 10  -- 10x faster with Shift
        print("DEBUG: LEFT with Shift - step = " .. tostring(step))
      end
      local old_pos = selected_sample_index
      selected_sample_index = math.max(1, selected_sample_index - step)
      print("DEBUG: LEFT key moved cursor from " .. tostring(old_pos) .. " to " .. tostring(selected_sample_index))
      waveform_canvas:update()
      PCMWriterUpdateHexDisplay()
      PCMWriterHighlightSample(selected_sample_index)
      return nil  -- Consume the key
    elseif key.name == "right" then
      print("DEBUG: Processing RIGHT key - before change, position = " .. tostring(selected_sample_index))
      -- RIGHT = Move cursor position right
      local step = 1
      if key.modifiers == "shift" then
        step = 10  -- 10x faster with Shift
        print("DEBUG: RIGHT with Shift - step = " .. tostring(step))
      end
      local old_pos = selected_sample_index
      selected_sample_index = math.min(wave_size, selected_sample_index + step)
      print("DEBUG: RIGHT key moved cursor from " .. tostring(old_pos) .. " to " .. tostring(selected_sample_index))
      waveform_canvas:update()
      PCMWriterUpdateHexDisplay()
      PCMWriterHighlightSample(selected_sample_index)
      return nil  -- Consume the key
    end
  end
  
  -- Default key handling
  local closer = "esc"
  if preferences and preferences.pakettiDialogClose then
    closer = preferences.pakettiDialogClose.value
  end
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    pcm_dialog = nil
    return nil
  else
    return key
  end
end

-- Selection operation functions
function PCMWriterHasSelection()
  return selection_start > 0 and selection_end > 0 and selection_start <= selection_end
end

function PCMWriterGetSelectionInfo()
  if not PCMWriterHasSelection() then
    return "No selection"
  end
  local count = selection_end - selection_start + 1
  return string.format("Selected: %d-%d (%d samples)", selection_start, selection_end, count)
end

-- Update all displays function (moved before functions that use it)
function PCMWriterUpdateAllDisplays()
  if waveform_canvas then
    waveform_canvas:update()
  end
  PCMWriterUpdateHexDisplay()
  PCMWriterUpdateLiveSample()  -- Update live sample if in pickup mode
  -- Note: No longer updating selection info since we removed selection UI
end

function PCMWriterClearSelection()
  selection_start = -1
  selection_end = -1
  PCMWriterUpdateAllDisplays()
end

function PCMWriterSelectAll()
  selection_start = 1
  selection_end = wave_size
  PCMWriterUpdateAllDisplays()
end

-- Zoom functions
function PCMWriterZoomIn()
  zoom_factor = math.min(max_zoom, zoom_factor * 1.5)
  pan_offset = math.max(0, math.min(wave_size - wave_size/zoom_factor, pan_offset))
  PCMWriterUpdateAllDisplays()
end

function PCMWriterZoomOut()
  zoom_factor = math.max(min_zoom, zoom_factor / 1.5)
  pan_offset = math.max(0, math.min(wave_size - wave_size/zoom_factor, pan_offset))
  PCMWriterUpdateAllDisplays()
end

function PCMWriterZoomFit()
  zoom_factor = 1.0
  pan_offset = 0
  PCMWriterUpdateAllDisplays()
end

-- Pan functions
function PCMWriterPanLeft()
  pan_offset = math.max(0, pan_offset - wave_size / zoom_factor * 0.1)
  PCMWriterUpdateAllDisplays()
end

function PCMWriterPanRight()
  pan_offset = math.min(wave_size - wave_size/zoom_factor, pan_offset + wave_size / zoom_factor * 0.1)
  PCMWriterUpdateAllDisplays()
end

function PCMWriterEditHexSample(idx, new_value)
  -- Don't process if we're in the middle of updating hex display to prevent cascading updates
  if updating_hex_display then
    return
  end
  
  -- Don't process empty or invalid input
  if not new_value or new_value == "" then
    return
  end
  
  local target_data = PCMWriterGetCurrentWaveData()
  local value = tonumber(new_value, 16)
  
  -- If not a valid hex number, try to extract valid hex characters
  if not value then
    -- Remove any non-hex characters and try again
    local cleaned = new_value:upper():gsub("[^0-9A-F]", "")
    if cleaned == "" then
      -- If no valid hex characters, restore original value
      if hex_buttons[idx] then
        hex_buttons[idx].text = string.format("%04X", target_data[idx])
      end
      return
    else
      value = tonumber(cleaned, 16)
      if not value then
        -- If still invalid, restore original value
        if hex_buttons[idx] then
          hex_buttons[idx].text = string.format("%04X", target_data[idx])
        end
        return
      end
    end
  end
  
  -- Clamp to valid range (0000-FFFF)
  value = math.max(0, math.min(65535, value))
  
  target_data[idx] = value
  selected_sample_index = idx
  
  -- Update the textfield to show the properly formatted value
  if hex_buttons[idx] then
    hex_buttons[idx].text = string.format("%04X", value)
  end
  
  PCMWriterUpdateCrossfadedWave()
  waveform_canvas:update()
  PCMWriterUpdateHexDisplay()
  PCMWriterUpdateLiveSample()  -- Update live sample when editing hex
  PCMWriterHighlightSample(idx)
end

-- WAV file format functions
function PCMWriterCreateWavHeader(sample_rate, num_channels, num_samples, bits_per_sample)
  local byte_rate = sample_rate * num_channels * bits_per_sample / 8
  local block_align = num_channels * bits_per_sample / 8
  local data_size = num_samples * num_channels * bits_per_sample / 8
  local file_size = 36 + data_size
  
  local header = {}
  
  -- RIFF header
  table.insert(header, string.char(0x52, 0x49, 0x46, 0x46)) -- "RIFF"
  table.insert(header, string.char(file_size % 256, math.floor(file_size / 256) % 256, 
                                  math.floor(file_size / 65536) % 256, math.floor(file_size / 16777216) % 256))
  table.insert(header, string.char(0x57, 0x41, 0x56, 0x45)) -- "WAVE"
  
  -- fmt chunk
  table.insert(header, string.char(0x66, 0x6D, 0x74, 0x20)) -- "fmt "
  table.insert(header, string.char(16, 0, 0, 0)) -- chunk size
  table.insert(header, string.char(1, 0)) -- PCM format
  table.insert(header, string.char(num_channels, 0)) -- mono
  
  -- Sample rate (32-bit little-endian)
  table.insert(header, string.char(sample_rate % 256, math.floor(sample_rate / 256) % 256,
                                  math.floor(sample_rate / 65536) % 256, math.floor(sample_rate / 16777216) % 256))
  
  -- Byte rate (32-bit little-endian)
  table.insert(header, string.char(byte_rate % 256, math.floor(byte_rate / 256) % 256,
                                  math.floor(byte_rate / 65536) % 256, math.floor(byte_rate / 16777216) % 256))
  
  table.insert(header, string.char(block_align, 0)) -- block align
  table.insert(header, string.char(bits_per_sample, 0)) -- bits per sample
  
  -- data chunk
  table.insert(header, string.char(0x64, 0x61, 0x74, 0x61)) -- "data"
  table.insert(header, string.char(data_size % 256, math.floor(data_size / 256) % 256,
                                  math.floor(data_size / 65536) % 256, math.floor(data_size / 16777216) % 256))
  
  return table.concat(header)
end

-- AKWF Integration Functions
local akwf_dropdown_files = {}  -- Cache for dropdown selection
local akwf_dropdown_filenames = {}  -- Display names for dropdown

function PCMWriterInitializeAKWFDropdown()
  -- Get full AKWF file list
  local full_akwf_list = PCMWriterGetAKWFFileList()
  
  -- Include ALL AKWF files in dropdown (user requested all files)
  akwf_dropdown_files = {}
  akwf_dropdown_filenames = {"Pick a AKWF"}  -- First item is always random
  
  if #full_akwf_list > 0 then
    -- Add ALL AKWF files to dropdown
    for i = 1, #full_akwf_list do
      local file_path = full_akwf_list[i]
      local filename = file_path:match("([^/]+)%.wav$") or "AKWF"
      table.insert(akwf_dropdown_files, file_path)
      table.insert(akwf_dropdown_filenames, filename)
    end
    
    print("DEBUG: AKWF dropdown initialized with ALL " .. #akwf_dropdown_filenames .. " items")
  else
    print("DEBUG: No AKWF files found for dropdown")
  end
end

function PCMWriterLoadAKWFFromDropdown(dropdown_index, target_wave)
  target_wave = target_wave or current_wave_edit
  
  if dropdown_index == 1 then
    -- First item is just a placeholder "Pick a AKWF" - do nothing
    return
  end
  
  -- Get the actual file from our cached list
  local file_index = dropdown_index - 1  -- Subtract 1 because first item is placeholder
  if file_index > 0 and file_index <= #akwf_dropdown_files then
    local file_path = akwf_dropdown_files[file_index]
    local target_wave_data = (target_wave == "A") and wave_data_a or wave_data_b
    
    local success = PCMWriterLoadAKWFToWaveData(file_path, target_wave_data, wave_size)
    if success then
      local filename = file_path:match("([^/]+)%.wav$") or "AKWF"
      renoise.app():show_status("Loaded AKWF: " .. filename .. " to Wave " .. target_wave)
      
      -- Update displays
      PCMWriterUpdateCrossfadedWave()
      PCMWriterUpdateAllDisplays()
    else
      renoise.app():show_status("Failed to load AKWF file")
    end
  end
end

function PCMWriterGetAKWFFileList()
  -- Ultra-random seeding using multiple entropy sources
  math.randomseed(os.time())
  math.random(); math.random(); math.random()
  local extra_random = math.random(1, 999999)
  math.randomseed(os.time() + os.clock() * 1000000 + extra_random)
  math.random(); math.random(); math.random(); math.random(); math.random()
  
  local tool_folder = renoise.tool().bundle_path .. "AKWF/"
  local file_path = tool_folder .. "akwf.txt"
  local wav_files = {}

  -- Load .wav file paths from akwf.txt
  local file = io.open(file_path, "r")
  if file then
    for line in file:lines() do
      table.insert(wav_files, tool_folder .. line)  -- Combine relative path with tool_folder
    end
    file:close()
  else
    renoise.app():show_status("akwf.txt not found in " .. tool_folder)
    return {}
  end

  -- Shuffle the wav_files array for even more randomness
  for i = #wav_files, 2, -1 do
    local j = math.random(1, i)
    wav_files[i], wav_files[j] = wav_files[j], wav_files[i]
  end
  
  return wav_files
end

function PCMWriterLoadAKWFToWaveData(file_path, target_wave_data, target_size)
  target_wave_data = target_wave_data or wave_data
  target_size = target_size or wave_size
  
  print("DEBUG: Loading AKWF file: " .. file_path)
  print("DEBUG: Target size: " .. target_size)
  
  local song = renoise.song()
  
  -- Create a temporary instrument to load the AKWF sample
  local temp_inst_index = #song.instruments + 1
  song:insert_instrument_at(temp_inst_index)
  local temp_inst = song:instrument(temp_inst_index)
  
  -- Load the AKWF file
  local temp_sample = temp_inst:insert_sample_at(1)
  temp_sample.sample_buffer:load_from(file_path)
  
  local buffer = temp_sample.sample_buffer
  if not buffer.has_sample_data then
    print("DEBUG: ERROR - No sample data in buffer!")
    -- Clean up and return failure
    song:delete_instrument_at(temp_inst_index)
    return false
  end
  
  local akwf_frames = buffer.number_of_frames
  print("DEBUG: AKWF has " .. akwf_frames .. " frames")
  
  -- Convert AKWF sample data to PCM Writer wave data format
  for i = 1, target_size do
    local sample_pos = ((i - 1) / (target_size - 1)) * (akwf_frames - 1) + 1
    local frame_index = math.floor(sample_pos)
    frame_index = math.max(1, math.min(akwf_frames, frame_index))
    
    -- Get sample value and convert from -1..1 to 0..65535
    local sample_value = buffer:sample_data(1, frame_index)
    local pcm_value = math.floor((sample_value + 1) * 32767.5)
    pcm_value = math.max(0, math.min(65535, pcm_value))
    
    target_wave_data[i] = pcm_value
  end
  
  print("DEBUG: Successfully loaded AKWF data, first 3 values: " .. target_wave_data[1] .. ", " .. target_wave_data[2] .. ", " .. target_wave_data[3])
  
  -- Clean up temporary instrument
  song:delete_instrument_at(temp_inst_index)
  
  return true
end

function PCMWriterLoadRandomAKWFToCurrentWave()
  local akwf_files = PCMWriterGetAKWFFileList()
  if #akwf_files == 0 then
    renoise.app():show_status("No AKWF files found")
    return false
  end
  
  local random_file = akwf_files[math.random(1, #akwf_files)]
  local target_wave_data = PCMWriterGetCurrentWaveData()
  
  local success = PCMWriterLoadAKWFToWaveData(random_file, target_wave_data, wave_size)
  if success then
    local filename = random_file:match("([^/]+)%.wav$") or "AKWF"
    renoise.app():show_status("Loaded random AKWF: " .. filename .. " to Wave " .. current_wave_edit)
    
    -- Update displays
    PCMWriterUpdateCrossfadedWave()
    PCMWriterUpdateAllDisplays()
    return true
  else
    renoise.app():show_status("Failed to load AKWF file")
    return false
  end
end

function PCMWriterLoad2RandomAKWFAndExport()
  -- Validate track type before proceeding
  if not PCMWriterValidateTrackForWavetable() then
    return
  end
  
  print("DEBUG: Starting PCMWriterLoad2RandomAKWFAndExport")
  
  -- TEMPORARILY DISABLE Live Pickup Mode to prevent interference
  local was_live_pickup_active = live_pickup_mode
  if live_pickup_mode then
    print("DEBUG: Temporarily disabling Live Pickup Mode")
    live_pickup_mode = false
    live_pickup_sample = nil
    live_pickup_instrument = nil
  end
  
  local akwf_files = PCMWriterGetAKWFFileList()
  print("DEBUG: Found " .. #akwf_files .. " AKWF files")
  
  if #akwf_files < 2 then
    renoise.app():show_status("Need at least 2 AKWF files")
    return
  end
  
  -- Get two random different AKWF files
  local file_a = akwf_files[math.random(1, #akwf_files)]
  local file_b
  repeat
    file_b = akwf_files[math.random(1, #akwf_files)]
  until file_b ~= file_a or #akwf_files == 1
  
  print("DEBUG: Selected files:")
  print("DEBUG: File A: " .. file_a)
  print("DEBUG: File B: " .. file_b)
  
  -- Load files into Wave A and Wave B
  print("DEBUG: Loading AKWF files into wave data...")
  local success_a = PCMWriterLoadAKWFToWaveData(file_a, wave_data_a, wave_size)
  local success_b = PCMWriterLoadAKWFToWaveData(file_b, wave_data_b, wave_size)
  
  print("DEBUG: Load results - A: " .. tostring(success_a) .. ", B: " .. tostring(success_b))
  
  if success_a and success_b then
    -- Verify wave data was actually loaded
    print("DEBUG: Verifying wave data loaded correctly...")
    print("DEBUG: Wave A first 5 samples: " .. wave_data_a[1] .. ", " .. wave_data_a[2] .. ", " .. wave_data_a[3] .. ", " .. wave_data_a[4] .. ", " .. wave_data_a[5])
    print("DEBUG: Wave B first 5 samples: " .. wave_data_b[1] .. ", " .. wave_data_b[2] .. ", " .. wave_data_b[3] .. ", " .. wave_data_b[4] .. ", " .. wave_data_b[5])
    
    -- Update crossfaded wave
    PCMWriterUpdateCrossfadedWave()
    PCMWriterUpdateAllDisplays()
    
    local filename_a = file_a:match("([^/]+)%.wav$") or "AKWF_A"
    local filename_b = file_b:match("([^/]+)%.wav$") or "AKWF_B"
    
    print("DEBUG: About to call PCMWriterExportWaveAAndBToSample...")
    print("DEBUG: Current wave_size: " .. wave_size)
    renoise.app():show_status("Loaded " .. filename_a .. " → Wave A, " .. filename_b .. " → Wave B")
    
    -- Now call the Write A&B function to create 12st_WT.xrni setup
    PCMWriterExportWaveAAndBToSample()
    print("DEBUG: PCMWriterExportWaveAAndBToSample completed")
    
    -- RE-ENABLE Live Pickup Mode after successful export
    if was_live_pickup_active or PCMWriterDetect12stWTSetup() then
      print("DEBUG: Re-enabling Live Pickup Mode")
      PCMWriterEnterLivePickupMode()
    end
    
  else
    renoise.app():show_status("Failed to load AKWF files - A: " .. tostring(success_a) .. ", B: " .. tostring(success_b))
    
    -- RE-ENABLE Live Pickup Mode even on failure
    if was_live_pickup_active then
      print("DEBUG: Re-enabling Live Pickup Mode after failure")
      live_pickup_mode = true
    end
  end
end

-- Safe wrapper function for menu/keybinding access (doesn't require PCM Writer dialog to be open)
function PCMWriterSafeAKWFWavetableExport()
  -- Initialize AKWF data first
  PCMWriterInitializeAKWFDropdown()
  
  -- Call the main function
  PCMWriterLoad2RandomAKWFAndExport()
end

-- Enhanced save functions
function PCMWriterSaveWaveBin()
  local suggested_name = string.format("waveform_%dsamples.bin", wave_size)
  local filename = renoise.app():prompt_for_filename_to_write(".bin", suggested_name)
  
  if filename then
    local file = io.open(filename, "wb")
    if file then
      for i = 1, wave_size do
        local value = wave_data[i]
        file:write(string.char(value % 256))
        file:write(string.char(math.floor(value / 256)))
      end
      file:close()
      renoise.app():show_status("Wave saved as BIN: " .. filename)
    else
      renoise.app():show_status("Could not save BIN file")
    end
  else
    renoise.app():show_status("Save BIN cancelled")
  end
end

function PCMWriterSaveWaveWav()
  local suggested_name = string.format("waveform_%dsamples.wav", wave_size)
  local filename = renoise.app():prompt_for_filename_to_write(".wav", suggested_name)
  
  if filename then
    local file = io.open(filename, "wb")
    if file then
      -- Write WAV header
      local header = PCMWriterCreateWavHeader(44100, 1, wave_size, 16)
      file:write(header)
      
      -- Write PCM data (convert from unsigned 16-bit to signed 16-bit)
      for i = 1, wave_size do
        local value = wave_data[i] - 32768 -- Convert to signed
        value = math.max(-32768, math.min(32767, value))
        if value < 0 then value = value + 65536 end
        file:write(string.char(value % 256))
        file:write(string.char(math.floor(value / 256)))
      end
      file:close()
      renoise.app():show_status("Wave saved as WAV: " .. filename)
    else
      renoise.app():show_status("Could not save WAV file")
    end
  else
    renoise.app():show_status("Save WAV cancelled")
  end
end

function PCMWriterLoadWave()
  local filename = renoise.app():prompt_for_filename_to_read({"*.raw", "*.bin", "*.wav"}, "Load Wave File")
  
  if filename then
    local file = io.open(filename, "rb")
    if file then
      local content = file:read("*a")
      file:close()
      
      local is_wav = filename:lower():match("%.wav$")
      local data_offset = 0
      local expected_size = wave_size * 2
      
      if is_wav then
        -- Find data chunk in WAV file
        local data_pos = content:find("data")
        if data_pos then
          data_offset = data_pos + 7 -- Skip "data" + 4-byte size
          local available_data = #content - data_offset
          expected_size = math.min(expected_size, available_data)
        else
          renoise.app():show_status("Invalid WAV file: no data chunk found")
          return
        end
      end
      
      if #content - data_offset >= expected_size then
        local target_data = PCMWriterGetCurrentWaveData()
        for i = 1, wave_size do
          local pos = data_offset + (i - 1) * 2 + 1
          if pos + 1 <= #content then
            local low = string.byte(content, pos)
            local high = string.byte(content, pos + 1)
            local value = low + (high * 256)
            
            if is_wav then
              -- Convert from signed to unsigned
              if value > 32767 then value = value - 65536 end
              value = value + 32768
            end
            
            target_data[i] = math.max(0, math.min(65535, value))
          end
        end
        selected_sample_index = -1
        PCMWriterUpdateCrossfadedWave()
        PCMWriterZoomFit()
        renoise.app():show_status("Wave loaded: " .. filename .. " to Wave " .. current_wave_edit)
      else
        renoise.app():show_status(string.format("Invalid file size! Expected at least %d bytes, got %d", 
          expected_size, #content - data_offset))
      end
    else
      renoise.app():show_status("Could not read file")
    end
  else
    renoise.app():show_status("Load wave cancelled")
  end
end

function PCMWriterLoadCSV()
  local filename = renoise.app():prompt_for_filename_to_read({"*.csv"}, "Load CSV File")
  
  if filename then
    local file = io.open(filename, "r")
    if file then
      local content = file:read("*a")
      file:close()
      
      -- Check if this is the new format (has "Complete State" in header)
      local is_new_format = content:match("Complete State") ~= nil
      
      if is_new_format then
        -- Parse new format with Wave A, Wave B, and crossfade amount
        local wave_a_values = {}
        local wave_b_values = {}
        local loaded_crossfade = 0.5
        local loaded_current_edit = "A"
        
        -- Extract Wave A data
        local wave_a_section = content:match("-- Wave A Data:.-\n(.-)\n%-%- Wave B Data:")
        if wave_a_section then
          for value in wave_a_section:gmatch("[^,;%s\t\n]+") do
            local hex_value = tonumber(value, 16)
            if hex_value then
              hex_value = math.max(0, math.min(65535, hex_value))
              table.insert(wave_a_values, hex_value)
            end
          end
        end
        
        -- Extract Wave B data
        local wave_b_section = content:match("-- Wave B Data:.-\n(.-)\n%-%- Crossfade Amount:")
        if wave_b_section then
          for value in wave_b_section:gmatch("[^,;%s\t\n]+") do
            local hex_value = tonumber(value, 16)
            if hex_value then
              hex_value = math.max(0, math.min(65535, hex_value))
              table.insert(wave_b_values, hex_value)
            end
          end
        end
        
        -- Extract crossfade amount
        local crossfade_section = content:match("-- Crossfade Amount:.-\n([%d%.]+)")
        if crossfade_section then
          loaded_crossfade = tonumber(crossfade_section) or 0.5
          loaded_crossfade = math.max(0, math.min(1, loaded_crossfade))
        end
        
        -- Extract current wave edit
        local current_edit_section = content:match("-- Current Wave Edit:.-\n([AB])")
        if current_edit_section then
          loaded_current_edit = current_edit_section
        end
        
        -- Validate data
        if #wave_a_values == 0 or #wave_b_values == 0 or #wave_a_values ~= #wave_b_values then
          renoise.app():show_status("Invalid CSV format: missing or mismatched wave data")
          return
        end
        
        local csv_size = #wave_a_values
        local valid_sizes = {16, 32, 64, 128, 256, 512, 1024}
        local size_match = false
        
        for _, size in ipairs(valid_sizes) do
          if csv_size == size then
            size_match = true
            break
          end
        end
        
        if not size_match then
          local size_list = table.concat(valid_sizes, ", ")
          renoise.app():show_status(string.format("CSV contains %d values. Supported sizes: %s", csv_size, size_list))
          return
        end
        
        -- Store current dialog state
        local dialog_was_visible = pcm_dialog and pcm_dialog.visible
        
        -- If CSV size doesn't match current wave size, change wave size
        if csv_size ~= wave_size then
          wave_size = csv_size
          wave_data = table.create()
          wave_data_a = table.create()
          wave_data_b = table.create()
          
          -- Initialize arrays with proper size
          for i = 1, wave_size do
            wave_data[i] = 32768
            wave_data_a[i] = 32768
            wave_data_b[i] = 32768
          end
          
          -- Rebuild dialog with new size
          if pcm_dialog then
            pcm_dialog:close()
          end
        end
        
        -- Load the complete state
        for i = 1, csv_size do
          wave_data_a[i] = wave_a_values[i]
          wave_data_b[i] = wave_b_values[i]
        end
        
        -- Restore crossfade amount and current wave edit
        crossfade_amount = loaded_crossfade
        current_wave_edit = loaded_current_edit
        
        -- Update crossfaded wave
        PCMWriterUpdateCrossfadedWave()
        
        -- Update UI crossfade slider if dialog is open
        if pcm_dialog and pcm_dialog.visible then
          local crossfade_slider = vb.views.crossfade_slider
          local crossfade_display = vb.views.crossfade_value
          if crossfade_slider then crossfade_slider.value = crossfade_amount end
          if crossfade_display then crossfade_display.text = string.format("%.1f%%", crossfade_amount * 100) end
        end
        
        -- Reset editor state
        selected_sample_index = -1
        selection_start = -1
        selection_end = -1
        PCMWriterZoomFit()
        
        -- Show dialog if it was closed due to size change
        if not pcm_dialog or not pcm_dialog.visible then
          if dialog_was_visible then
            PCMWriterShowPcmDialog()
          end
        end
        
        -- Force canvas update with delay to ensure proper initialization
        if waveform_canvas then
          waveform_canvas:update()
        end
        
        -- Update all displays
        PCMWriterUpdateAllDisplays()
        
        -- Additional forced update after a brief delay to ensure canvas is properly refreshed
        renoise.tool():add_timer(function()
          if waveform_canvas then
            waveform_canvas:update()
          end
          PCMWriterUpdateHexDisplay()
        end, 100)  -- 100ms delay
        
        renoise.app():show_status(string.format("Complete wave state loaded: %d samples, %.1f%% crossfade, Wave %s", csv_size, loaded_crossfade * 100, loaded_current_edit))
        
      else
        -- Handle old format (backwards compatibility)
        local values = {}
        
        -- Split by lines and process each line
        for line in content:gmatch("[^\r\n]+") do
          -- Skip empty lines and comments
          if line:match("%S") and not line:match("^%s*%-%-") then
            -- Split by comma, semicolon, or tab
            for value in line:gmatch("[^,;%s\t]+") do
              -- Clean up the value (remove quotes, spaces)
              value = value:gsub("^%s*[\"']?", ""):gsub("[\"']?%s*$", "")
              
              -- Try to parse as hex first (with or without 0x prefix)
              local hex_value = nil
              if value:match("^0[xX]") then
                -- Has 0x prefix
                hex_value = tonumber(value, 16)
              elseif value:match("^[0-9A-Fa-f]+$") then
                -- Pure hex digits
                hex_value = tonumber(value, 16)
              else
                -- Try as decimal
                hex_value = tonumber(value)
              end
              
              if hex_value then
                -- Clamp to valid range (0000-FFFF)
                hex_value = math.max(0, math.min(65535, hex_value))
                table.insert(values, hex_value)
              end
            end
          end
        end
        
        -- Check if we have valid data
        if #values == 0 then
          renoise.app():show_status("No valid numeric values found in CSV file")
          return
        end
        
        -- Check if the number of values matches supported wave sizes
        local valid_sizes = {16, 32, 64, 128, 256, 512, 1024}
        local csv_size = #values
        local size_match = false
        
        for _, size in ipairs(valid_sizes) do
          if csv_size == size then
            size_match = true
            break
          end
        end
        
        if not size_match then
          local size_list = table.concat(valid_sizes, ", ")
          renoise.app():show_status(string.format("CSV contains %d values. Supported sizes: %s", csv_size, size_list))
          return
        end
        
        -- Load old format into current wave
        local target_data = PCMWriterGetCurrentWaveData()
        for i = 1, csv_size do
          target_data[i] = values[i]
        end
        
        -- Update crossfaded wave
        PCMWriterUpdateCrossfadedWave()
        
        renoise.app():show_status(string.format("Legacy CSV loaded into Wave %s: %d values", current_wave_edit, csv_size))
      end
      
    else
      renoise.app():show_status("Could not read CSV file")
    end
  else
    renoise.app():show_status("Load CSV cancelled")
  end
end

-- .WT Import functions for PCM Writer
-- Based on PakettiWTImport.lua parsing logic

local function PCMWriterReadUint32LE(file)
  local b1, b2, b3, b4 = file:read(1), file:read(1), file:read(1), file:read(1)
  if not b1 or not b2 or not b3 or not b4 then
    error("Unexpected end of file while reading uint32")
  end
  local bytes = {b1:byte(), b2:byte(), b3:byte(), b4:byte()}
  return bytes[1] + (bytes[2] * 256) + (bytes[3] * 65536) + (bytes[4] * 16777216)
end

local function PCMWriterReadUint16LE(file)
  local b1, b2 = file:read(1), file:read(1)
  if not b1 or not b2 then
    error("Unexpected end of file while reading uint16")
  end
  local bytes = {b1:byte(), b2:byte()}
  return bytes[1] + (bytes[2] * 256)
end

local function PCMWriterReadInt16LE(file)
  local value = PCMWriterReadUint16LE(file)
  if value >= 32768 then
    return value - 65536
  end
  return value
end

-- Bit operations for Lua 5.1 compatibility
local function PCMWriterBand(a, b)
  local result = 0
  local bitval = 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then
      result = result + bitval
    end
    bitval = bitval * 2
    a = math.floor(a / 2)
    b = math.floor(b / 2)
  end
  return result
end

local function PCMWriterBor(a, b)
  local result = 0
  local bitval = 1
  while a > 0 or b > 0 do
    if a % 2 == 1 or b % 2 == 1 then
      result = result + bitval
    end
    bitval = bitval * 2
    a = math.floor(a / 2)
    b = math.floor(b / 2)
  end
  return result
end

local function PCMWriterLshift(a, b)
  return a * (2 ^ b)
end

local function PCMWriterRshift(a, b)
  return math.floor(a / (2 ^ b))
end

local function PCMWriterReadFloat32LE(file)
  local b1, b2, b3, b4 = file:read(1), file:read(1), file:read(1), file:read(1)
  if not b1 or not b2 or not b3 or not b4 then
    error("Unexpected end of file while reading float32")
  end
  local bytes = {b1:byte(), b2:byte(), b3:byte(), b4:byte()}
  
  -- Convert bytes to float32 (IEEE 754) - simplified approach
  local sign = PCMWriterBand(bytes[4], 0x80) ~= 0
  local exponent = PCMWriterBor(PCMWriterLshift(PCMWriterBand(bytes[4], 0x7F), 1), PCMWriterRshift(bytes[3], 7))
  local mantissa = PCMWriterBor(PCMWriterBor(PCMWriterLshift(PCMWriterBand(bytes[3], 0x7F), 16), PCMWriterLshift(bytes[2], 8)), bytes[1])
  
  if exponent == 0 then
    if mantissa == 0 then
      return sign and -0.0 or 0.0
    else
      -- Denormalized number
      local value = mantissa * math.pow(2, -149)
      return sign and -value or value
    end
  elseif exponent == 255 then
    if mantissa == 0 then
      return sign and -math.huge or math.huge
    else
      return 0/0 -- NaN
    end
  else
    -- Normalized number
    local value = (1 + mantissa * math.pow(2, -23)) * math.pow(2, exponent - 127)
    return sign and -value or value
  end
end

function PCMWriterParseWavetableFile(filepath)
  local file = io.open(filepath, "rb")
  if not file then
    print("ERROR: Could not open .WT file: " .. filepath)
    return nil
  end
  
  print("DEBUG: Parsing .WT file for PCM Writer: " .. filepath)
  
  -- Wrap parsing in pcall for error handling
  local success, result = pcall(function()
    -- Read header: 'vawt' as big-endian
    local header = file:read(4)
    if header ~= "vawt" then
      file:close()
      print("ERROR: Invalid .WT file: missing 'vawt' header")
      return nil
    end
    print("DEBUG: Valid 'vawt' header found")
    
    -- Read wave_size (little-endian uint32)
    local wt_wave_size = PCMWriterReadUint32LE(file)
    print("DEBUG: WT Wave size: " .. wt_wave_size)
    
    -- Read wave_count (little-endian uint16)
    local wave_count = PCMWriterReadUint16LE(file)
    print("DEBUG: WT Wave count: " .. wave_count)
    
    -- Read flags (little-endian uint16)
    local flags = PCMWriterReadUint16LE(file)
    print("DEBUG: WT Flags: " .. string.format("0x%04X", flags))
    
    local is_sample = PCMWriterBand(flags, 0x0001) ~= 0
    local is_looped = PCMWriterBand(flags, 0x0002) ~= 0
    local is_int16 = PCMWriterBand(flags, 0x0004) ~= 0
    local use_full_range = PCMWriterBand(flags, 0x0008) ~= 0
    local has_metadata = PCMWriterBand(flags, 0x0010) ~= 0
    
    print("DEBUG: WT Format: " .. (is_int16 and "int16" or "float32"))
    
    -- Read wave data - we only need first and last waves
    local waves = {}
    
    for wave = 1, wave_count do
      waves[wave] = {}
      for sample = 1, wt_wave_size do
        if is_int16 then
          local value = PCMWriterReadInt16LE(file)
          if use_full_range then
            -- Full 16-bit range: -32768 to 32767 maps to -1.0 to ~1.0
            waves[wave][sample] = value / 32768.0
          else
            -- 15-bit range (-6 dBFS peak): -16384 to 16383 maps to -0.5 to ~0.5
            waves[wave][sample] = value / 32768.0
          end
        else
          -- Float32 format
          waves[wave][sample] = PCMWriterReadFloat32LE(file)
        end
      end
    end
    
    return {
      wave_size = wt_wave_size,
      wave_count = wave_count,
      waves = waves
    }
  end)
  
  file:close()
  
  if not success then
    print("ERROR: Error parsing .WT file: " .. tostring(result))
    return nil
  end
  
  return result
end

function PCMWriterImportWTToWaves()
  local file_path = renoise.app():prompt_for_filename_to_read({"*.wt", "*.*"}, "Import .WT for PCM Writer")
  
  if file_path == "" then
    return
  end
  
  local wt_data = PCMWriterParseWavetableFile(file_path)
  if not wt_data then
    renoise.app():show_status("Failed to parse .WT file")
    return
  end
  
  print("DEBUG: Importing .WT - " .. wt_data.wave_count .. " waves, " .. wt_data.wave_size .. " samples each")
  
  -- Check if WT wave size matches any of our supported sizes
  local valid_sizes = {16, 32, 64, 128, 256, 512, 1024}
  local size_match = false
  for _, size in ipairs(valid_sizes) do
    if wt_data.wave_size == size then
      size_match = true
      break
    end
  end
  
  if not size_match then
    local size_list = table.concat(valid_sizes, ", ")
    renoise.app():show_status(string.format("WT wave size %d not supported. Use: %s", wt_data.wave_size, size_list))
    return
  end
  
  -- Change PCM Writer wave size if needed
  local dialog_was_visible = pcm_dialog and pcm_dialog.visible
  local wave_size_changed = false
  if wt_data.wave_size ~= wave_size then
    print("DEBUG: Changing PCM Writer wave size from " .. wave_size .. " to " .. wt_data.wave_size)
    wave_size_changed = true
    -- Manually change wave size without calling PCMWriterChangeWaveSize to avoid dialog rebuild
    wave_size = wt_data.wave_size
    wave_data = table.create()
    wave_data_a = table.create()
    wave_data_b = table.create()
    
    -- Initialize arrays with proper size (we'll overwrite them with WT data)
    for i = 1, wave_size do
      wave_data[i] = 32768
      wave_data_a[i] = 32768
      wave_data_b[i] = 32768
    end
    
    print("DEBUG: Wave size changed to " .. wave_size .. ", continuing with WT import")
  end
  
  -- Get first and last waves
  local first_wave = wt_data.waves[1]
  local last_wave = wt_data.waves[wt_data.wave_count]
  
  -- Convert and load first wave to Wave A
  print("DEBUG: Loading first wave (wave 1) to Wave A")
  for i = 1, wave_size do
    -- Convert from float (-1.0 to 1.0) to PCM Writer format (0-65535)
    local value = first_wave[i]
    local pcm_value = math.floor((value + 1.0) * 32767.5)
    pcm_value = math.max(0, math.min(65535, pcm_value))
    wave_data_a[i] = pcm_value
  end
  print("DEBUG: Wave A loaded - sample 1 value: " .. wave_data_a[1] .. ", sample " .. wave_size .. " value: " .. wave_data_a[wave_size])
  
  -- Convert and load last wave to Wave B  
  print("DEBUG: Loading last wave (wave " .. wt_data.wave_count .. ") to Wave B")
  for i = 1, wave_size do
    -- Convert from float (-1.0 to 1.0) to PCM Writer format (0-65535)
    local value = last_wave[i]
    local pcm_value = math.floor((value + 1.0) * 32767.5)
    pcm_value = math.max(0, math.min(65535, pcm_value))
    wave_data_b[i] = pcm_value
  end
  print("DEBUG: Wave B loaded - sample 1 value: " .. wave_data_b[1] .. ", sample " .. wave_size .. " value: " .. wave_data_b[wave_size])
  
  -- Update crossfaded wave
  PCMWriterUpdateCrossfadedWave()
  
  -- Reset editor state
  selected_sample_index = -1
  selection_start = -1
  selection_end = -1
  
  -- Rebuild dialog if wave size changed (required for proper hex editor and UI updates)
  if wave_size_changed and dialog_was_visible then
    print("DEBUG: Rebuilding dialog due to wave size change")
    if pcm_dialog then
      pcm_dialog:close()
      PCMWriterShowPcmDialog()
    end
  else
    -- Update displays only if dialog wasn't rebuilt
    print("DEBUG: Updating displays without rebuilding dialog")
    PCMWriterZoomFit()
    PCMWriterUpdateAllDisplays()
  end
  
  -- Extract filename for status
  local filename = file_path:match("([^/\\]+)$") or "Wavetable"
  
  print("STATUS: Imported .WT to PCM Writer")
  renoise.app():show_status(string.format("Imported %s: Wave 1→A, Wave %d→B (%d samples)", 
    filename, wt_data.wave_count, wt_data.wave_size))
end

function PCMWriterImportWTAndLivePickup()
  local file_path = renoise.app():prompt_for_filename_to_read({"*.wt", "*.*"}, "Import .WT and Enable Live Pickup")
  
  if file_path == "" then
    return
  end
  
  print("DEBUG: Starting .WT and Live Pickup import")
  
  -- Import the full wavetable to instrument using existing function
  local success = wt_loadsample(file_path)
  if not success then
    renoise.app():show_status("Failed to import .WT file to instrument")
    return
  end
  
  -- Get the newly created instrument and sample
  local song = renoise.song()
  local instrument = song.selected_instrument
  local sample = song.selected_sample
  
  if not instrument or not sample or #instrument.samples == 0 then
    renoise.app():show_status("No instrument or sample found after .WT import")
    return
  end
  
  print("DEBUG: .WT imported successfully, enabling live pickup mode")
  
  -- Open PCM Writer dialog if not already open
  if not pcm_dialog or not pcm_dialog.visible then
    print("DEBUG: Opening PCM Writer dialog")
    PCMWriterShowPcmDialog()
  end
  
  -- Load the first sample into PCM Writer using live pickup
  PCMWriterLoadSampleToWaveform()
  
  -- Extract filename for status
  local filename = file_path:match("([^/\\]+)$") or "Wavetable"
  
  print("STATUS: .WT imported and Live Pickup enabled")
  renoise.app():show_status(string.format("Imported %s to instrument + Live Pickup on first sample", filename))
end

-- Morph export functions
function PCMWriterGenerateMorphSequence(wave_a, wave_b, steps)
  local morph_waves = {}
  
  print("DEBUG: Generating " .. steps .. " morph steps between Wave A and Wave B")
  
  for step = 1, steps do
    -- Calculate crossfade amount (0.0 to 1.0)
    local crossfade = (step - 1) / (steps - 1)
    
    local morph_wave = {}
    for i = 1, wave_size do
      -- Crossfade between Wave A and Wave B
      local value_a = wave_a[i]
      local value_b = wave_b[i]
      local morphed_value = math.floor(value_a * (1 - crossfade) + value_b * crossfade)
      morphed_value = math.max(0, math.min(65535, morphed_value))
      morph_wave[i] = morphed_value
    end
    
    morph_waves[step] = {
      data = morph_wave,
      crossfade = crossfade,
      name = string.format("Morph %03d (%.1f%%)", step, crossfade * 100)
    }
  end
  
  print("DEBUG: Generated " .. #morph_waves .. " morph waves")
  return morph_waves
end

function PCMWriterExportMorphToInstrument()
  -- Disable live pickup mode to prevent data loss
  if live_pickup_mode then
    live_pickup_mode = false
    live_pickup_sample = nil
    live_pickup_instrument = nil
    live_pickup_sample_index = -1
    live_pickup_instrument_index = -1
    renoise.app():show_status("Live pickup mode disabled for safe export")
  end
  
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- Check if instrument has samples or plugins, if so create new instrument
  if #inst.samples > 0 or inst.plugin_properties.plugin_loaded then
    song:insert_instrument_at(song.selected_instrument_index + 1)
    song.selected_instrument_index = song.selected_instrument_index + 1
    inst = song.selected_instrument
    -- Apply Paketti default instrument configuration
    if pakettiPreferencesDefaultInstrumentLoader then
      pakettiPreferencesDefaultInstrumentLoader()
      inst = song.selected_instrument
    end
  elseif #inst.samples == 0 and not inst.plugin_properties.plugin_loaded then
    print("DEBUG: Empty instrument - applying pakettiPreferencesDefaultInstrumentLoader")
    if pakettiPreferencesDefaultInstrumentLoader then
      pakettiPreferencesDefaultInstrumentLoader()
      inst = song.selected_instrument
    end
  end
  
  -- Generate 127 morph steps
  local morph_waves = PCMWriterGenerateMorphSequence(wave_data_a, wave_data_b, 127)
  
  print("DEBUG: Creating instrument with " .. #morph_waves .. " morphed samples")
  
  -- Create sample slots for each morph step
  for wave_idx, wave in ipairs(morph_waves) do
    -- Create sample slot
    if #inst.samples < wave_idx then
      inst:insert_sample_at(wave_idx)
    end
    
    local sample = inst:sample(wave_idx)
    local buffer = sample.sample_buffer
    
    -- Create sample data for this morph step
    buffer:create_sample_data(44100, 16, 1, wave_size)
    buffer:prepare_sample_data_changes()
    
    -- Write this wave's data
    for i = 1, wave_size do
      buffer:set_sample_data(1, i, (wave.data[i] - 32768) / 32768)
    end
    buffer:finalize_sample_data_changes()
    
    -- Set sample properties
    sample.name = wave.name
    
    -- Enable loop mode for each sample
    sample.loop_mode = sample_loop_mode
    sample.loop_start = 1
    sample.loop_end = wave_size
    
    -- Set interpolation
    if sample_interpolation_mode == "linear" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
    elseif sample_interpolation_mode == "cubic" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC
    elseif sample_interpolation_mode == "sinc" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
    elseif sample_interpolation_mode == "none" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_NONE
    else
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR -- default
    end
    
    sample.oversample_enabled = sample_oversample_enabled
    sample.autofade = preferences.pakettiLoaderAutofade.value
    
    -- AUTOMATIC PITCH CORRECTION using danoise algorithm
    local pitch_correction = calculate_pitch_correction(44100, wave_size, 1)
    
    -- Only apply correction if deviation is significant (>2 cents)
    local cents_deviation = math.abs(pitch_correction.cents)
    if cents_deviation > 2 then
      sample.fine_tune = pitch_correction.fine_tune
      sample.transpose = pitch_correction.transpose
      print("DEBUG: Applied pitch correction to sample " .. wave_idx .. " - Fine: " .. pitch_correction.fine_tune .. ", Transpose: " .. pitch_correction.transpose)
    end
  end
  
  inst.name = string.format("PCM Morph A→B (%d waves, %d frames)", #morph_waves, wave_size)
  
  -- Select the first sample
  song.selected_sample_index = 1
  
  print("STATUS: Exported morph to instrument")
  renoise.app():show_status("Created morph instrument with " .. #morph_waves .. " samples (A→B transition)")
end

-- Helper function for .WT export (reusing logic from PakettiWTImport.lua)
local function PCMWriterWriteUint32LE(file, value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  local b3 = math.floor(value / 65536) % 256
  local b4 = math.floor(value / 16777216) % 256
  file:write(string.char(b1, b2, b3, b4))
end

local function PCMWriterWriteUint16LE(file, value)
  local b1 = value % 256
  local b2 = math.floor(value / 256) % 256
  file:write(string.char(b1, b2))
end

local function PCMWriterWriteFloat32LE(file, value)
  -- Convert float32 to bytes (simplified IEEE 754)
  if value == 0.0 then
    file:write(string.char(0, 0, 0, 0))
    return
  end
  
  local sign = value < 0 and 1 or 0
  value = math.abs(value)
  
  if value == math.huge then
    -- Infinity
    local b4 = sign == 1 and 0xFF or 0x7F
    file:write(string.char(0, 0, 0x80, b4))
    return
  end
  
  -- Normalize to get exponent and mantissa
  local exponent = 127
  while value >= 2.0 do
    value = value / 2.0
    exponent = exponent + 1
  end
  while value < 1.0 and value > 0.0 do
    value = value * 2.0
    exponent = exponent - 1
  end
  
  -- Clamp exponent
  if exponent < 0 then
    exponent = 0
    value = 0
  elseif exponent > 255 then
    exponent = 255
    value = 0
  end
  
  local mantissa = math.floor((value - 1.0) * 8388608) -- 2^23
  mantissa = math.max(0, math.min(8388607, mantissa))
  
  local b1 = mantissa % 256
  local b2 = math.floor(mantissa / 256) % 256
  local b3 = math.floor(mantissa / 65536) % 128 + (exponent % 2) * 128
  local b4 = math.floor(exponent / 2) + sign * 128
  
  file:write(string.char(b1, b2, b3, b4))
end

function PCMWriterExportMorphToWT(morph_waves, filepath)
  local file = io.open(filepath, "wb")
  if not file then
    print("ERROR: Could not create .WT file: " .. filepath)
    return false
  end
  
  print("DEBUG: Exporting " .. #morph_waves .. " morph waves to .WT format")
  
  -- Write header: 'vawt' as big-endian
  file:write("vawt")
  
  -- Write wave_size (little-endian uint32)
  PCMWriterWriteUint32LE(file, wave_size)
  
  -- Write wave_count (little-endian uint16)
  PCMWriterWriteUint16LE(file, #morph_waves)
  
  -- Write flags (little-endian uint16)
  local flags = 0
  -- flags = flags + 0x0001 -- is_sample (usually false for wavetables)
  flags = flags + 0x0002 -- is_looped (wavetables should be looped)
  -- flags = flags + 0x0004 -- is_int16 (we'll use float32)
  -- flags = flags + 0x0008 -- use_full_range (can be enabled if needed)
  flags = flags + 0x0010 -- has_metadata
  
  PCMWriterWriteUint16LE(file, flags)
  print("DEBUG: WT Flags: " .. string.format("0x%04X", flags))
  
  -- Write wave data (float32 format)
  print("DEBUG: Writing wave data (float32 format)")
  for wave_idx = 1, #morph_waves do
    for sample_idx = 1, wave_size do
      -- Convert from PCM Writer format (0-65535) to float32 (-1.0 to 1.0)
      local pcm_value = morph_waves[wave_idx].data[sample_idx]
      local float_value = (pcm_value - 32768) / 32768
      PCMWriterWriteFloat32LE(file, float_value)
    end
  end
  
  -- Write metadata
  local metadata = string.format("PCM Writer Morph A→B (%d waves, %d samples)", #morph_waves, wave_size)
  file:write(metadata)
  file:write(string.char(0)) -- Null terminator
  print("DEBUG: Wrote metadata: " .. metadata)
  
  file:close()
  
  print("STATUS: Exported morph to .WT format")
  return true
end

function PCMWriterExportMorphToWTFile()
  -- Generate 127 morph steps
  local morph_waves = PCMWriterGenerateMorphSequence(wave_data_a, wave_data_b, 127)
  
  -- Prompt for filename
  local suggested_name = string.format("pcm_morph_%dsamples.wt", wave_size)
  local file_path = renoise.app():prompt_for_filename_to_write("wt", suggested_name)
  
  if file_path == "" then
    return
  end
  
  -- Add .wt extension if not present
  if not file_path:match("%.wt$") then
    file_path = file_path .. ".wt"
  end
  
  local success = PCMWriterExportMorphToWT(morph_waves, file_path)
  
  if success then
    renoise.app():show_status("Exported morph to .WT: " .. file_path)
  else
    renoise.app():show_status("Failed to export morph to .WT")
  end
end

function PCMWriterExportMorphToInstrumentAndWT()
  -- Disable live pickup mode to prevent data loss
  if live_pickup_mode then
    live_pickup_mode = false
    live_pickup_sample = nil
    live_pickup_instrument = nil
    live_pickup_sample_index = -1
    live_pickup_instrument_index = -1
    renoise.app():show_status("Live pickup mode disabled for safe export")
  end
  
  -- First export to instrument
  PCMWriterExportMorphToInstrument()
  
  -- Then export to .WT
  local morph_waves = PCMWriterGenerateMorphSequence(wave_data_a, wave_data_b, 127)
  
  -- Prompt for .WT filename
  local suggested_name = string.format("pcm_morph_%dsamples.wt", wave_size)
  local file_path = renoise.app():prompt_for_filename_to_write("wt", suggested_name)
  
  if file_path == "" then
    renoise.app():show_status("Instrument created, .WT export cancelled")
    return
  end
  
  -- Add .wt extension if not present
  if not file_path:match("%.wt$") then
    file_path = file_path .. ".wt"
  end
  
  local success = PCMWriterExportMorphToWT(morph_waves, file_path)
  
  if success then
    renoise.app():show_status("Exported morph to instrument + .WT: " .. file_path)
  else
    renoise.app():show_status("Exported morph to instrument, .WT export failed")
  end
end

function PCMWriterSaveCSV()
  local suggested_name = string.format("waveform_%dsamples.csv", wave_size)
  local filename = renoise.app():prompt_for_filename_to_write(".csv", suggested_name)
  
  if filename then
    local file = io.open(filename, "w")
    if file then
      -- Write CSV header with complete state info
      file:write("-- PCM Wave Data (Complete State)\n")
      file:write("-- Wave Size: " .. wave_size .. " samples\n")
      file:write("-- Crossfade Amount: " .. crossfade_amount .. " (" .. string.format("%.1f%% A + %.1f%% B", (1-crossfade_amount)*100, crossfade_amount*100) .. ")\n")
      file:write("-- Current Wave Edit: " .. current_wave_edit .. "\n")
      file:write("--\n")
      
      -- Write Wave A data
      file:write("-- Wave A Data:\n")
      for i = 1, wave_size do
        file:write(string.format("%04X", wave_data_a[i]))
        
        if i % 16 == 0 then
          file:write("\n")  -- New line every 16 values
        elseif i < wave_size then
          file:write(",")  -- Comma separator
        end
      end
      
      -- Add final newline if needed
      if wave_size % 16 ~= 0 then
        file:write("\n")
      end
      
      -- Write Wave B data
      file:write("-- Wave B Data:\n")
      for i = 1, wave_size do
        file:write(string.format("%04X", wave_data_b[i]))
        
        if i % 16 == 0 then
          file:write("\n")  -- New line every 16 values
        elseif i < wave_size then
          file:write(",")  -- Comma separator
        end
      end
      
      -- Add final newline if needed
      if wave_size % 16 ~= 0 then
        file:write("\n")
      end
      
      -- Write crossfade amount
      file:write("-- Crossfade Amount:\n")
      file:write(string.format("%.6f\n", crossfade_amount))
      
      -- Write current wave edit
      file:write("-- Current Wave Edit:\n")
      file:write(current_wave_edit .. "\n")
      
      file:close()
      renoise.app():show_status("Complete wave state saved as CSV: " .. filename)
    else
      renoise.app():show_status("Could not save CSV file")
    end
  else
    renoise.app():show_status("Save CSV cancelled")
  end
end

-- Wavetable functions
function PCMWriterExportWavetableToSample()
  -- Disable live pickup mode to prevent data loss/crashes
  if live_pickup_mode then
    live_pickup_mode = false
    live_pickup_sample = nil
    live_pickup_instrument = nil
    live_pickup_sample_index = -1
    live_pickup_instrument_index = -1
    renoise.app():show_status("Live pickup mode disabled for safe export")
  end
  
  if #wavetable_waves == 0 then
    renoise.app():show_status("No waves in wavetable to export")
    return
  end
  
  -- Validate wave_size to prevent crashes
  if not wave_size or wave_size <= 0 or wave_size > 1048576 then
    renoise.app():show_status("Invalid wave size: " .. tostring(wave_size) .. ". Cannot export.")
    return
  end
  
  -- User feedback: Starting export
  renoise.app():show_status("Exporting wavetable to samples...")
  
  -- Debug info for developers
  print("DEBUG: Starting wavetable export - waves:", #wavetable_waves, "wave_size:", wave_size)
  
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- CRITICAL: Clear sample buffer state to prevent conflicts with new sample creation
  local original_instrument_index = song.selected_instrument_index
  local original_sample_index = song.selected_sample_index
  
  print("DEBUG: Original instrument index:", original_instrument_index, "sample index:", original_sample_index)
  print("DEBUG: Original instrument has", #inst.samples, "samples")
  
  -- Check if instrument has samples or plugins, if so create new instrument
  if #inst.samples > 0 or inst.plugin_properties.plugin_loaded then
    -- Clear any sample editor selection before creating new instrument
    if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      print("DEBUG: Switched away from sample editor to prevent state conflicts")
    end
    
    -- Create new instrument and switch to it
    song:insert_instrument_at(song.selected_instrument_index + 1)
    song.selected_instrument_index = song.selected_instrument_index + 1
    inst = song.selected_instrument
    
    print("DEBUG: Created new instrument at index:", song.selected_instrument_index)
    
    -- Apply Paketti default instrument configuration
    pakettiPreferencesDefaultInstrumentLoader()
  else
    print("DEBUG: Using existing empty instrument")
  end
  
  -- Force garbage collection to clear any lingering references
  collectgarbage("collect")
  
  -- Refresh instrument reference after all changes
  inst = song.selected_instrument
  print("DEBUG: Final instrument validation - index:", song.selected_instrument_index, "samples:", #inst.samples)
  
  -- Create separate sample slots for each wave (up to 12)
  for wave_idx, wave in ipairs(wavetable_waves) do
    -- Safety check: don't exceed reasonable sample slot limits
    if wave_idx > 255 then
      print("DEBUG: Stopping at wave", wave_idx, "- too many samples")
      break
    end
    
    -- User feedback: show progress
    if wave_idx == 1 or wave_idx % 3 == 0 or wave_idx == #wavetable_waves then
      renoise.app():show_status(string.format("Processing wave %d/%d...", wave_idx, #wavetable_waves))
    end
    
    print("DEBUG: Processing wave", wave_idx, "of", #wavetable_waves)
    
    -- Validate wave data before processing
    if wave and wave.data and #wave.data == wave_size then
             -- Create sample slot with error handling
       local sample_creation_success, sample_error = pcall(function()
         if #inst.samples < wave_idx then
           inst:insert_sample_at(wave_idx)
         end
       end)
       
       if not sample_creation_success then
         print("DEBUG: Failed to create sample slot", wave_idx, ":", tostring(sample_error))
       else
         -- Get fresh references to avoid stale state
         inst = song.selected_instrument  -- Refresh instrument reference
         local sample = inst:sample(wave_idx)
         
         -- Validate sample exists and is accessible
         if not sample then
           print("DEBUG: Sample slot", wave_idx, "not accessible after creation")
         else
           local buffer = sample.sample_buffer
           
           -- Extra validation: ensure this sample slot is properly initialized
           if not buffer then
             print("DEBUG: Sample buffer not available for slot", wave_idx)
           else
             print("DEBUG: Sample slot", wave_idx, "created successfully")
             
             -- Create sample data for this single wave with additional error handling
             local success, error_msg = pcall(function()
               -- Validate parameters before calling create_sample_data
               local sample_rate = 44100
               local bit_depth = 16
               local channels = 1
               local frames = wave_size
               
               print("DEBUG: About to call create_sample_data - rate:", sample_rate, "bits:", bit_depth, "channels:", channels, "frames:", frames)
               
               -- Extra validation
               if frames <= 0 or frames > 1048576 then
                 error("Invalid frame count: " .. tostring(frames))
               end
               if sample_rate <= 0 or sample_rate > 192000 then
                 error("Invalid sample rate: " .. tostring(sample_rate))
               end
               
               buffer:create_sample_data(sample_rate, bit_depth, channels, frames)
               buffer:prepare_sample_data_changes()
               
               -- Write this wave's data
               for i = 1, wave_size do
                 local sample_value = wave.data[i]
                 if sample_value and type(sample_value) == "number" then
                   local normalized_value = (sample_value - 32768) / 32768
                   -- Clamp to valid range
                   normalized_value = math.max(-1.0, math.min(1.0, normalized_value))
                   buffer:set_sample_data(1, i, normalized_value)
                 else
                   buffer:set_sample_data(1, i, 0) -- Default to silence for missing data
                 end
               end
               buffer:finalize_sample_data_changes()
             end)
             
             if success then
               -- Double-check that sample is still valid before setting properties
               if sample and sample.sample_buffer and sample.sample_buffer.has_sample_data then
                 -- Set sample properties
                 sample.name = string.format("PCM Wave %02d (%d frames)", wave_idx, wave_size)
                 
                 -- Enable loop mode for each sample
                 sample.loop_mode = sample_loop_mode
                 sample.loop_start = 1
                 sample.loop_end = wave_size
                 
                 -- Set interpolation
                 if sample_interpolation_mode == "linear" then
                   sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
                 elseif sample_interpolation_mode == "cubic" then
                   sample.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC
                 elseif sample_interpolation_mode == "sinc" then
                   sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
                 elseif sample_interpolation_mode == "none" then
                   sample.interpolation_mode = renoise.Sample.INTERPOLATE_NONE
                 else
                   sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR -- default
                 end
                 
                 sample.oversample_enabled = sample_oversample_enabled
                 sample.autofade = preferences.pakettiLoaderAutofade.value
                 
                 -- AUTOMATIC PITCH CORRECTION using danoise algorithm
                 local pitch_correction = calculate_pitch_correction(44100, wave_size, 1)
                 
                 -- Only apply correction if deviation is significant (>2 cents)
                 local cents_deviation = math.abs(pitch_correction.cents)
                 if cents_deviation > 2 then
                   sample.transpose = pitch_correction.transpose
                   sample.fine_tune = pitch_correction.fine_tune
                   
                   -- Update sample name to include pitch correction info
                   local correction_status = string.format(" -> Auto-tuned to %s (T:%d, F:%d)", 
                     pitch_correction.note_name, pitch_correction.transpose, pitch_correction.fine_tune)
                   
                   sample.name = sample.name .. correction_status
                 end
               else
                 print("DEBUG: Sample became invalid after creation for wave", wave_idx)
               end
               
               print("DEBUG: Completed wave", wave_idx, "of", #wavetable_waves)
               
               -- Force garbage collection between samples to free memory
               collectgarbage("collect")
             else
               print("DEBUG: Failed to create sample", wave_idx, ":", tostring(error_msg))
             end
           end
         end
       end
    else
      print("DEBUG: Invalid wave data at index", wave_idx, "- skipping")
    end
  end
  
  inst.name = string.format("PCM Wavetable (%d waves, %d frames) + Auto-Pitch", #wavetable_waves, wave_size)
  
  -- Select the first sample only if samples were created
  if #inst.samples > 0 then
    song.selected_sample_index = 1
    print("DEBUG: Selected first sample")
  else
    print("DEBUG: No samples were created - cannot select sample index")
  end
  
  renoise.app():show_status(string.format("Wavetable exported: %d waves created", #wavetable_waves))
  print("DEBUG: Export completed with", sample_interpolation_mode, "interpolation and auto-pitch correction")
end

function PCMWriterAddWavetableWave()
  -- Check if we've reached the maximum of 12 waves
  if #wavetable_waves >= 12 then
    renoise.app():show_status("Maximum wavetable size reached (12 waves)")
    return
  end
  
  -- Preserve the current selection position
  local saved_selected_index = selected_sample_index
  
  local new_wave = {data = table.create(), name = string.format("Wave %d", #wavetable_waves + 1)}
  
  -- Copy current editor wave to new wavetable wave
  -- Both should now be the same size (512 samples)
  for i = 1, wave_size do
    new_wave.data[i] = wave_data[i]
  end
  
  table.insert(wavetable_waves, new_wave)
  current_wave_index = #wavetable_waves
  
  -- Restore the selection position
  selected_sample_index = saved_selected_index
  
  renoise.app():show_status(string.format("Added %s to wavetable (%d/12 waves)", new_wave.name, #wavetable_waves))
  
  -- Update the wavetable count display without rebuilding the entire dialog
  if wavetable_count_text then
    wavetable_count_text.text = string.format("Wavetable Tools (%d/12)", #wavetable_waves)
  end
end

function PCMWriterGenerateRandomWaveform()
  local max_attempts = 5  -- Maximum attempts to generate a good waveform
  local attempt = 1
  local status_text = ""  -- Declare status_text outside the loop
  local target_data = PCMWriterGetCurrentWaveData()  -- Get current wave (A or B)
  
  while attempt <= max_attempts do
    -- MAXIMUM RANDOMNESS - Multiple entropy sources and chaos
    local chaos_seed = os.time() + math.floor(os.clock() * 1000000) + wave_size + (selected_sample_index or 0) + attempt * 54321
    
    -- Add more entropy from system state
    chaos_seed = chaos_seed + #wavetable_waves * 1337 + cursor_width * 42 + cursor_step_size
    
    -- Random seed the seed with itself (recursive randomness)
    for chaos_round = 1, math.random(3, 8) do
      math.randomseed(chaos_seed + chaos_round * 12345)
      chaos_seed = chaos_seed + math.random(1, 999999)
    end
    
    -- Final seed with accumulated chaos
    math.randomseed(chaos_seed)
    
    -- Warm up with random number of calls
    for i = 1, math.random(5, 15) do math.random() end
  
  -- Randomly choose generation method (now with 8 methods, including complex synthesis)
  local method = math.random(1, 8)
  
  if method == 1 then --if starts
    -- Method 1: CHAOTIC mix of basic waveforms with random frequencies
    local num_oscillators = math.random(1, 8)  -- Multiple oscillators per waveform type
    local sine_amp = math.random() > math.random() and (math.random() * math.random(0.5, 2.0)) or 0
    local square_amp = math.random() > math.random() and (math.random() * math.random(0.3, 1.5)) or 0
    local triangle_amp = math.random() > math.random() and (math.random() * math.random(0.4, 1.8)) or 0
    local saw_amp = math.random() > math.random() and (math.random() * math.random(0.2, 1.2)) or 0
    local noise_amp = math.random() > math.random() and (math.random() * math.random(0.1, 0.8)) or 0
    
    -- Random frequency multipliers for each waveform
    local sine_freq = math.random() * 4 + 0.5
    local square_freq = math.random() * 6 + 0.25
    local triangle_freq = math.random() * 5 + 0.33
    local saw_freq = math.random() * 7 + 0.1
    
    local total_amp = sine_amp + square_amp + triangle_amp + saw_amp + noise_amp
    if total_amp == 0 then sine_amp = 0.5 end -- Fallback
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      
      if sine_amp > 0 then
        -- Multiple sine waves with random phase shifts
        for osc = 1, num_oscillators do
          local freq = sine_freq * math.random(0.5, 2.0)
          local phase_shift = math.random() * math.pi * 2
          value = value + math.sin(phase * math.pi * 2 * freq + phase_shift) * (sine_amp / num_oscillators)
        end
      end
      if square_amp > 0 then
        local square_phase = phase * square_freq
        local square = (square_phase % 1 < math.random(0.2, 0.8)) and 1 or -1
        value = value + square * square_amp
      end
      if triangle_amp > 0 then
        local tri_phase = (phase * triangle_freq) % 1
        local triangle
        local peak_pos = math.random(0.2, 0.8)  -- Random peak position
        if tri_phase < peak_pos then
          triangle = (tri_phase / peak_pos) * 2 - 1
        else
          triangle = 1 - ((tri_phase - peak_pos) / (1 - peak_pos)) * 2
        end
        value = value + triangle * triangle_amp
      end
      if saw_amp > 0 then
        local saw_phase = (phase * saw_freq) % 1
        local saw = (saw_phase * 2 - 1)
        -- Random saw direction
        if math.random() > 0.5 then saw = -saw end
        value = value + saw * saw_amp
      end
      if noise_amp > 0 then
        -- Colored noise with random filtering
        local noise = (math.random() * 2 - 1)
        if math.random() > 0.5 then
          -- Low-pass filtered noise
          noise = noise * (1 - phase * math.random(0.5, 1.0))
        end
        value = value + noise * noise_amp
      end
      
      if total_amp > 0 then
        value = value / total_amp
      end
      target_data[i] = math.floor((value * 32767) + 32768)
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    status_text = string.format("Random mix (s:%.1f sq:%.1f tri:%.1f saw:%.1f n:%.1f)", 
      sine_amp, square_amp, triangle_amp, saw_amp, noise_amp)
  
  elseif method == 2 then
    -- Method 2: Harmonic series with random harmonics
    local fundamental = math.random(1, 6)
    local harmonics = {}
    for h = 1, 12 do
      local prob = math.random(0.4, 0.8) - (h * 0.05)  -- Decreasing probability for higher harmonics
      harmonics[h] = math.random() > prob and (math.random() * (1.2 - h * 0.08) / h) or 0
    end
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      for h = 1, 12 do
        if harmonics[h] > 0 then
          value = value + math.sin(phase * math.pi * 2 * h * fundamental) * harmonics[h]
        end
      end
      target_data[i] = math.floor((value * 32767) + 32768)
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    
    -- Count active harmonics
    local active_harmonics = 0
    for h = 1, 12 do
      if harmonics[h] > 0 then active_harmonics = active_harmonics + 1 end
    end
    status_text = string.format("Harmonic series (fund:%d, %d harmonics)", fundamental, active_harmonics)
  
  elseif method == 3 then
    -- Method 3: Bezier curve with random control points
    local control_points = {}
    local num_points = math.random(3, 15)
    for p = 1, num_points do
      -- More varied control point distribution
      local range = math.random(0.5, 2.0)
      control_points[p] = (math.random() * 2 - 1) * range
    end
    
    for i = 1, wave_size do
      local t = (i - 1) / (wave_size - 1)
      local segment = t * (num_points - 1)
      local seg_idx = math.floor(segment)
      local seg_t = segment - seg_idx
      
      local value
      if seg_idx >= num_points - 1 then
        value = control_points[num_points]
      else
        -- Linear interpolation between control points
        value = control_points[seg_idx + 1] + seg_t * (control_points[seg_idx + 2] - control_points[seg_idx + 1])
      end
      
      target_data[i] = math.floor((value * 32767) + 32768)
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    status_text = string.format("Bezier curve (%d control points)", num_points)
  
  elseif method == 4 then
    -- Method 4: Fractal/chaos waveform
    local chaos_factor = math.random() * 1.2 + 0.05
    local seed_value = (math.random() * 2 - 1) * math.random(0.5, 2.0)
    local feedback = math.random() * 1.2 + 0.05
    local chaos_type = math.random(1, 3)  -- Different chaos equations
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      
      -- Different chaotic equations for variety
      if chaos_type == 1 then
        -- Logistic map variation
        seed_value = chaos_factor * seed_value * (1 - seed_value) + feedback * math.sin(phase * math.pi * 2)
      elseif chaos_type == 2 then
        -- Sine map variation
        seed_value = math.sin(seed_value * chaos_factor * math.pi) + feedback * math.cos(phase * math.pi * 4)
      else
        -- Tent map variation
        if seed_value < 0.5 then
          seed_value = chaos_factor * seed_value + feedback * math.sin(phase * math.pi * 6)
        else
          seed_value = chaos_factor * (1 - seed_value) + feedback * math.cos(phase * math.pi * 3)
        end
      end
      
      -- Clamp to prevent overflow
      seed_value = math.max(-2, math.min(2, seed_value))
      
      local value = seed_value
      target_data[i] = math.floor((value * 32767) + 32768)
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    
    local chaos_names = {"Logistic", "Sine", "Tent"}
    status_text = string.format("Chaotic waveform (%s, chaos:%.2f, feedback:%.2f)", 
      chaos_names[chaos_type], chaos_factor, feedback)
  
  elseif method == 5 then
    -- Method 5: ULTIMATE CHAOS - Hybrid of all methods with random switching
    local method_switches = {}
    for i = 1, wave_size do
      method_switches[i] = math.random(1, 4)  -- Random method per sample
    end
    
    -- Pre-generate parameters for all methods
    local sine_amp = math.random() * 2
    local square_amp = math.random() * 1.5
    local triangle_amp = math.random() * 1.8
    local saw_amp = math.random() * 1.2
    local noise_amp = math.random() * 0.8
    
    local fundamental = math.random(1, 8)
    local harmonics = {}
    for h = 1, 16 do
      harmonics[h] = math.random() > 0.5 and (math.random() * 2 / h) or 0
    end
    
    local control_points = {}
    local num_points = math.random(5, 20)
    for p = 1, num_points do
      control_points[p] = (math.random() * 4 - 2)
    end
    
    local chaos_factor = math.random() * 2 + 0.1
    local seed_value = math.random() * 4 - 2
    local feedback = math.random() * 2 + 0.1
    
    -- Generate with method-switching chaos
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      local current_method = method_switches[i]
      
      if current_method == 1 then
        -- Random mix method
        value = math.sin(phase * math.pi * 2 * math.random(0.5, 8)) * sine_amp * math.random(0.5, 1.5)
        value = value + ((phase * math.random(2, 10)) % 1 < 0.5 and 1 or -1) * square_amp * math.random(0.3, 1.2)
        value = value + (math.random() * 2 - 1) * noise_amp * math.random(0.1, 0.9)
      elseif current_method == 2 then
        -- Harmonic method
        for h = 1, math.random(3, 12) do
          if harmonics[h] and harmonics[h] > 0 then
            value = value + math.sin(phase * math.pi * 2 * h * fundamental * math.random(0.8, 1.2)) * harmonics[h]
          end
        end
      elseif current_method == 3 then
        -- Bezier method
        local t = phase
        local segment = t * (num_points - 1)
        local seg_idx = math.floor(segment)
        local seg_t = segment - seg_idx
        if seg_idx >= num_points - 1 then
          value = control_points[num_points] or 0
        else
          local p1 = control_points[seg_idx + 1] or 0
          local p2 = control_points[seg_idx + 2] or 0
          value = p1 + seg_t * (p2 - p1)
        end
        value = value * math.random(0.5, 2.0)  -- Random amplitude scaling
      else
        -- Chaos method
        seed_value = math.sin(seed_value * chaos_factor * math.pi * math.random(0.5, 2.0)) + 
                    feedback * math.cos(phase * math.pi * math.random(2, 12))
        seed_value = math.max(-3, math.min(3, seed_value))
        value = seed_value
      end
      
      -- Add random cross-contamination between methods
      if math.random() > 0.7 then
        local contamination = math.sin(phase * math.pi * math.random(4, 32)) * math.random(0.1, 0.5)
        value = value + contamination
      end
      
      target_data[i] = math.floor((value * 16383) + 32768)  -- Different scaling for more chaos
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    status_text = string.format("ULTIMATE CHAOS (hybrid switching, %d methods)", num_points)
  
  elseif method == 6 then
    -- Method 6: Advanced FM synthesis with multiple operators
    local num_operators = math.random(2, 4)
    local carrier_freq = math.random(0.5, 3.0)
    local operators = {}
    
    -- Create operators with random parameters
    for op = 1, num_operators do
      operators[op] = {
        freq_ratio = math.random(0.25, 8.0),
        amplitude = math.random(0.1, 1.0) / num_operators,
        phase_offset = math.random() * math.pi * 2
      }
    end
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      
      -- FM synthesis with multiple operators
      for op = 1, num_operators do
        local op_phase = phase * math.pi * 2 * carrier_freq * operators[op].freq_ratio + operators[op].phase_offset
        local op_value = math.sin(op_phase) * operators[op].amplitude
        
        -- Apply FM modulation from previous operators
        if op > 1 then
          local mod_amount = math.random(0.5, 3.0)
          op_value = math.sin(op_phase + value * mod_amount) * operators[op].amplitude
        end
        
        value = value + op_value
      end
      
      target_data[i] = math.floor((value * 32767) + 32768)
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    status_text = string.format("FM synthesis (%d operators, carrier:%.1f)", num_operators, carrier_freq)
  
  elseif method == 7 then
    -- Method 7: Geometric shapes with random parameters
    local shape_idx = math.random(1, #geometric_shapes)
    local old_shape_index = current_geometric_index
    local old_asymmetry = shape_asymmetry
    local old_segments = shape_segments
    local old_curve = shape_curve
    local old_recursion = shape_recursion
    
    -- Randomize shape parameters
    current_geometric_index = shape_idx
    shape_asymmetry = math.random(20, 80) / 100  -- 0.2 to 0.8
    shape_segments = math.random(3, 12)          -- 3 to 12 segments
    shape_curve = math.random(50, 300) / 100     -- 0.5 to 3.0 curve
    shape_recursion = math.random(2, 6)          -- 2 to 6 recursion levels
    
    -- Generate the geometric shape directly into wave_data
    local shape_type = geometric_shapes[shape_idx]
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      
      if shape_type == "asym_diamond" then
        local peak_pos = shape_asymmetry
        if phase < peak_pos then
          value = phase / peak_pos
        else
          value = (1 - phase) / (1 - peak_pos)
        end
        value = value * 2 - 1
      elseif shape_type == "crystal" then
        local facets = shape_segments
        local facet_phase = (phase * facets) % 1
        local facet_sharpness = shape_asymmetry * 0.4 + 0.1
        if facet_phase < facet_sharpness then
          value = facet_phase / facet_sharpness
        elseif facet_phase < (1 - facet_sharpness) then
          value = 1
        else
          value = (1 - facet_phase) / facet_sharpness
        end
        value = value * 2 - 1
      else
        -- Default geometric shape (diamond)
        if phase < 0.5 then
          value = phase * 2
        else
          value = 2 - phase * 2
        end
        value = value * 2 - 1
      end
      
      target_data[i] = math.floor((value * 32767) + 32768)
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    
    -- Restore original parameters
    current_geometric_index = old_shape_index
    shape_asymmetry = old_asymmetry
    shape_segments = old_segments
    shape_curve = old_curve
    shape_recursion = old_recursion
    
    status_text = string.format("Geometric %s (asym:%.1f, segs:%d)", 
      geometric_shapes[shape_idx], shape_asymmetry, shape_segments)
  
  elseif method == 8 then
    -- Method 8: COMPLEX SYNTHESIS CHAINS - "sine with 3rd and 5th harmonics FM'd by half-sine ring modulated 8-bit tri wave"
    local carrier_freqs = {1, 2, 3, 4, 6, 8}  -- Random carrier frequencies
    local modulator_freqs = {0.25, 0.5, 1, 1.5, 2, 3, 4, 8}  -- Random modulator frequencies
    local bit_depths = {3, 4, 5, 6, 7, 8}  -- Random bit depths for quantization
    
    -- Random synthesis chain parameters
    local base_waveform = math.random(1, 4)  -- 1=sine, 2=tri, 3=saw, 4=square
    local num_harmonics = math.random(2, 8)  -- Number of harmonics to add
    local fm_freq = modulator_freqs[math.random(#modulator_freqs)]
    local fm_depth = math.random(0.5, 8.0)
    local ring_freq = modulator_freqs[math.random(#modulator_freqs)]
    local ring_waveform = math.random(1, 3)  -- 1=sine, 2=tri, 3=half-sine
    local bit_depth = bit_depths[math.random(#bit_depths)]
    local distortion_amt = math.random(0.1, 3.0)
    
    -- Harmonic amplitudes (random but decreasing)
    local harmonics = {}
    for h = 1, num_harmonics do
      harmonics[h] = math.random(0.1, 0.8) / math.pow(h, math.random(0.5, 1.5))
    end
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      
      -- Step 1: Generate base waveform with harmonics
      if base_waveform == 1 then  -- Sine base
        value = math.sin(phase * math.pi * 2)
        -- Add harmonics
        for h = 1, num_harmonics do
          local harmonic_num = h + 1  -- 2nd, 3rd, 4th harmonics etc
          value = value + math.sin(phase * math.pi * 2 * harmonic_num) * harmonics[h]
        end
      elseif base_waveform == 2 then  -- Triangle base
        local tri_phase = phase
        if tri_phase < 0.5 then
          value = tri_phase * 4 - 1
        else
          value = 3 - tri_phase * 4
        end
        -- Add harmonics
        for h = 1, num_harmonics do
          local harmonic_num = h * 2 + 1  -- Odd harmonics for triangle
          value = value + math.sin(phase * math.pi * 2 * harmonic_num) * harmonics[h]
        end
      elseif base_waveform == 3 then  -- Sawtooth base
        value = phase * 2 - 1
        -- Add harmonics
        for h = 1, num_harmonics do
          value = value + math.sin(phase * math.pi * 2 * (h + 1)) * harmonics[h]
        end
      else  -- Square base
        value = phase < 0.5 and 1 or -1
        -- Add odd harmonics
        for h = 1, num_harmonics do
          local harmonic_num = h * 2 + 1
          value = value + math.sin(phase * math.pi * 2 * harmonic_num) * harmonics[h]
        end
      end
      
      -- Step 2: Apply FM (Frequency Modulation)
      local fm_modulator
      if math.random() > 0.5 then
        -- Half-sine FM modulator
        local fm_phase = (phase * fm_freq) % 1
        fm_modulator = fm_phase < 0.5 and math.sin(fm_phase * math.pi * 2) or 0
      else
        -- Full sine FM modulator
        fm_modulator = math.sin(phase * math.pi * 2 * fm_freq)
      end
      
      -- Apply FM by modulating the phase
      local fm_modulated_phase = phase + (fm_modulator * fm_depth * 0.1)
      if base_waveform == 1 then
        value = math.sin(fm_modulated_phase * math.pi * 2)
        for h = 1, num_harmonics do
          value = value + math.sin(fm_modulated_phase * math.pi * 2 * (h + 1)) * harmonics[h]
        end
      end
      
      -- Step 3: Ring Modulation
      local ring_modulator
      if ring_waveform == 1 then  -- Sine ring mod
        ring_modulator = math.sin(phase * math.pi * 2 * ring_freq)
      elseif ring_waveform == 2 then  -- Triangle ring mod
        local ring_phase = (phase * ring_freq) % 1
        if ring_phase < 0.5 then
          ring_modulator = ring_phase * 4 - 1
        else
          ring_modulator = 3 - ring_phase * 4
        end
      else  -- Half-sine ring mod
        local ring_phase = (phase * ring_freq) % 1
        ring_modulator = ring_phase < 0.5 and math.sin(ring_phase * math.pi * 2) or 0
      end
      
      -- Apply ring modulation (multiply)
      value = value * (0.5 + ring_modulator * 0.5)
      
      -- Step 4: Bit reduction/quantization
      local levels = math.pow(2, bit_depth)
      value = math.floor(value * levels) / levels
      
      -- Step 5: Optional distortion/waveshaping
      if math.random() > 0.3 then
        value = math.tanh(value * distortion_amt) / distortion_amt
      end
      
      -- Convert to sample range
      target_data[i] = math.floor((value * 32767) + 32768)
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    
    local waveform_names = {"sine", "triangle", "saw", "square"}
    local ring_names = {"sine", "triangle", "half-sine"}
    status_text = string.format("Complex: %s+%dH FM(%.1fx) Ring(%s %.1fx) %dbit", 
      waveform_names[base_waveform], num_harmonics, fm_freq, ring_names[ring_waveform], ring_freq, bit_depth)
  
  else
    -- Fallback: Spectral/Additive synthesis with random partials
    local num_partials = math.random(3, 16)
    local fundamental_freq = math.random(0.5, 4.0)
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      
      -- Generate random partials with varying amplitudes and frequencies
      for partial = 1, num_partials do
        local freq_ratio = partial * math.random(0.8, 1.2)  -- Slightly detuned harmonics
        local amplitude = math.random(0.1, 1.0) / partial  -- Decreasing amplitude
        local phase_offset = math.random() * math.pi * 2
        
        value = value + math.sin(phase * math.pi * 2 * fundamental_freq * freq_ratio + phase_offset) * amplitude
      end
      
      target_data[i] = math.floor((value * 32767 / num_partials) + 32768)
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    status_text = string.format("Spectral synthesis (%d partials, fund:%.1f)", num_partials, fundamental_freq)
  end
  
  -- RANDOM POST-PROCESSING CHAOS
  local post_fx = math.random(1, 7)
  if post_fx == 1 then
    -- Random bit crushing
    local bit_crush = math.random(8, 15)
    local crush_factor = math.pow(2, 16 - bit_crush)
    for i = 1, wave_size do
      target_data[i] = math.floor(target_data[i] / crush_factor) * crush_factor
    end
    status_text = status_text .. " + BitCrush"
  elseif post_fx == 2 then
    -- Random waveshaping distortion
    local drive = math.random(1.5, 4.0)
    for i = 1, wave_size do
      local normalized = (target_data[i] - 32768) / 32768
      normalized = math.tanh(normalized * drive) / drive
      target_data[i] = math.floor(normalized * 32768 + 32768)
    end
    status_text = status_text .. " + Distortion"
  elseif post_fx == 3 then
    -- Random frequency modulation
    local fm_freq = math.random(0.5, 8.0)
    local fm_depth = math.random(0.1, 0.8)
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local fm_mod = math.sin(phase * math.pi * 2 * fm_freq) * fm_depth
      local mod_phase = phase + fm_mod
      if mod_phase >= 0 and mod_phase <= 1 then
        local mod_idx = math.floor(mod_phase * (wave_size - 1)) + 1
        if mod_idx >= 1 and mod_idx <= wave_size then
          target_data[i] = (target_data[i] + target_data[mod_idx]) / 2
        end
      end
    end
    status_text = status_text .. " + FM"
  elseif post_fx == 4 then
    -- Random ring modulation
    local ring_freq = math.random(0.25, 12.0)
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local ring_mod = math.sin(phase * math.pi * 2 * ring_freq)
      local normalized = (target_data[i] - 32768) / 32768
      normalized = normalized * ring_mod
      target_data[i] = math.floor(normalized * 32768 + 32768)
    end
    status_text = status_text .. " + RingMod"
  elseif post_fx == 5 then
    -- Random phase distortion
    local phase_amt = math.random(0.2, 2.0)
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local distorted_phase = math.sin(phase * math.pi * phase_amt)
      local new_idx = math.floor(math.abs(distorted_phase) * (wave_size - 1)) + 1
      if new_idx >= 1 and new_idx <= wave_size then
        target_data[i] = target_data[new_idx]
      end
    end
    status_text = status_text .. " + PhaseDistort"
  elseif post_fx == 6 then
    -- Chebyshev polynomial waveshaping
    local order = math.random(2, 6)  -- Use 2nd to 6th order Chebyshev polynomials
    local drive = math.random(0.5, 2.0)
    for i = 1, wave_size do
      local normalized = (target_data[i] - 32768) / 32768  -- Convert to -1 to 1 range
      normalized = math.max(-1, math.min(1, normalized * drive))  -- Apply drive and clamp
      
      local shaped
      if order == 2 then
        -- T2(x) = 2x^2 - 1
        shaped = 2 * normalized * normalized - 1
      elseif order == 3 then
        -- T3(x) = 4x^3 - 3x
        shaped = 4 * normalized * normalized * normalized - 3 * normalized
      elseif order == 4 then
        -- T4(x) = 8x^4 - 8x^2 + 1
        local x2 = normalized * normalized
        shaped = 8 * x2 * x2 - 8 * x2 + 1
      elseif order == 5 then
        -- T5(x) = 16x^5 - 20x^3 + 5x
        local x2 = normalized * normalized
        local x3 = x2 * normalized
        shaped = 16 * x3 * x2 - 20 * x3 + 5 * normalized
      else -- order == 6
        -- T6(x) = 32x^6 - 48x^4 + 18x^2 - 1
        local x2 = normalized * normalized
        local x4 = x2 * x2
        shaped = 32 * x4 * x2 - 48 * x4 + 18 * x2 - 1
      end
      
      -- Clamp result and convert back to 0-65535 range
      shaped = math.max(-1, math.min(1, shaped))
      target_data[i] = math.floor(shaped * 32768 + 32768)
    end
    status_text = status_text .. string.format(" + Chebyshev T%d", order)
  end
  -- post_fx == 7 means no post-processing (clean)
  
  -- Debug: Check waveform energy before click-free processing
  local energy_before = 0
  local min_val = 65535
  local max_val = 0
  for i = 1, wave_size do
    local deviation = math.abs(target_data[i] - 32768)
    energy_before = energy_before + deviation
    min_val = math.min(min_val, target_data[i])
    max_val = math.max(max_val, target_data[i])
  end
  local range_before = max_val - min_val
  local avg_energy_before = energy_before / wave_size
  
  -- Post-process to ensure click-free looping: force first and last samples to center (0.5)
  local center_value = 32768  -- Center value (0.5 in normalized range)
  
  -- Only apply click-free processing if waveform has sufficient energy
  if avg_energy_before > 1000 and range_before > 2000 then
    -- Store original first and last values for gentler processing
    local original_first = target_data[1]
    local original_last = target_data[wave_size]
    
    -- Gentle click-free: blend towards center instead of forcing to center
    local blend_factor = 0.3  -- Only blend 30% towards center
    target_data[1] = math.floor(original_first + (center_value - original_first) * blend_factor)
    target_data[wave_size] = math.floor(original_last + (center_value - original_last) * blend_factor)
    
    -- Much gentler smoothing - only 2-3 samples maximum
    local smooth_samples = math.min(2, math.floor(wave_size / 64))  -- Much less aggressive
    
    if smooth_samples > 0 then
      -- Gentle smooth start
      for i = 2, smooth_samples + 1 do
        local blend = (i - 1) / smooth_samples * 0.2  -- Very gentle blending
        local original_value = target_data[i]
        target_data[i] = math.floor(original_value + (center_value - original_value) * blend)
      end
      
      -- Gentle smooth end
      for i = wave_size - smooth_samples, wave_size - 1 do
        local blend = (wave_size - i) / smooth_samples * 0.2  -- Very gentle blending
        local original_value = target_data[i]
        target_data[i] = math.floor(original_value + (center_value - original_value) * blend)
      end
    end
  end
  
  -- Debug: Check waveform energy after processing
  local energy_after = 0
  local min_val_after = 65535
  local max_val_after = 0
  for i = 1, wave_size do
    local deviation = math.abs(target_data[i] - 32768)
    energy_after = energy_after + deviation
    min_val_after = math.min(min_val_after, target_data[i])
    max_val_after = math.max(max_val_after, target_data[i])
  end
  local range_after = max_val_after - min_val_after
  local avg_energy_after = energy_after / wave_size
  
  -- Debug output for boring waveforms
  -- Check for "envelope-only" waveforms (mostly flat with just edge fades)
  local middle_start = math.floor(wave_size * 0.2)  -- Skip first 20%
  local middle_end = math.floor(wave_size * 0.8)    -- Skip last 20%
  local middle_variation = 0
  local middle_samples = middle_end - middle_start + 1
  
  -- Check variation in the middle 60% of the waveform
  for i = middle_start, middle_end do
    local deviation = math.abs(target_data[i] - 32768)
    middle_variation = middle_variation + deviation
  end
  local avg_middle_variation = middle_variation / middle_samples
  
  -- Check if waveform is mostly flat in the middle (boring envelope-only shape)
  local is_boring = avg_middle_variation < 200 or range_after < 1000
  
  if is_boring or avg_energy_after < 500 then
    print("DEBUG: BORING/DEAD WAVEFORM DETECTED!")
    print("  Attempt:", attempt)
    print("  Method:", method)
    print("  Post-FX:", post_fx)
    print("  Energy before:", string.format("%.1f", avg_energy_before))
    print("  Energy after:", string.format("%.1f", avg_energy_after))
    print("  Range before:", range_before)
    print("  Range after:", range_after)
    print("  Middle variation:", string.format("%.1f", avg_middle_variation))
    print("  Status:", status_text)
    print("  First 10 samples:", wave_data[1], wave_data[2], wave_data[3], wave_data[4], wave_data[5], wave_data[6], wave_data[7], wave_data[8], wave_data[9], wave_data[10])
    print("  Middle 10 samples:", wave_data[math.floor(wave_size*0.4)], wave_data[math.floor(wave_size*0.45)], wave_data[math.floor(wave_size*0.5)], wave_data[math.floor(wave_size*0.55)], wave_data[math.floor(wave_size*0.6)])
    print("  Last 10 samples:", wave_data[wave_size-9], wave_data[wave_size-8], wave_data[wave_size-7], wave_data[wave_size-6], wave_data[wave_size-5], wave_data[wave_size-4], wave_data[wave_size-3], wave_data[wave_size-2], wave_data[wave_size-1], wave_data[wave_size])
    
    -- If this is a boring waveform and we haven't reached max attempts, try again
    if attempt < max_attempts then
      print("  Retrying generation... (attempt " .. (attempt + 1) .. "/" .. max_attempts .. ")")
      attempt = attempt + 1
      -- Continue the while loop to try again
    else
      print("  Max attempts reached, keeping this waveform")
      break  -- Exit the while loop
    end
  else
    -- Good waveform generated, exit the while loop
    if attempt > 1 then
      print("DEBUG: Good waveform generated on attempt " .. attempt)
    end
    break
  end
  
  end  -- End of while loop
  
  -- Apply DC offset correction to center the waveform
  PCMWriterRemoveDCOffset()
  
  selected_sample_index = -1
  selection_start = -1
  selection_end = -1
  
  -- Update crossfaded wave
  PCMWriterUpdateCrossfadedWave()
  PCMWriterUpdateLiveSample()  -- Live update sample when generating random waveform
  
  -- Set current waveform type to indicate random waveform is active
  current_waveform_type = "random"
  renoise.app():show_status("Generated " .. status_text .. " (click-free, DC centered) to Wave " .. current_wave_edit)
end

-- Enhanced version with entropy control and forced method selection for wavetable generation
function PCMWriterGenerateRandomWaveformWithEntropy(entropy_seed, forced_method)
  -- Get current wave data (A or B)
  local target_data = PCMWriterGetCurrentWaveData()
  
  -- Use provided entropy seed for consistent but diverse randomization
  math.randomseed(entropy_seed)
  
  -- Warm up with entropy-specific number of calls
  for i = 1, (entropy_seed % 20) + 5 do 
    math.random() 
  end
  
  -- Use forced method to ensure diversity across wavetable
  local method = forced_method or math.random(1, 6)
  local status_text = ""
  
  if method == 1 then
    -- Method 1: CHAOTIC mix of basic waveforms with random frequencies
    local num_oscillators = math.random(1, 8)
    local sine_amp = math.random() > math.random() and (math.random() * math.random(0.5, 2.0)) or 0
    local square_amp = math.random() > math.random() and (math.random() * math.random(0.3, 1.5)) or 0
    local triangle_amp = math.random() > math.random() and (math.random() * math.random(0.4, 1.8)) or 0
    local saw_amp = math.random() > math.random() and (math.random() * math.random(0.2, 1.2)) or 0
    local noise_amp = math.random() > math.random() and (math.random() * math.random(0.1, 0.8)) or 0
    
    local sine_freq = math.random() * 4 + 0.5
    local square_freq = math.random() * 6 + 0.25
    local triangle_freq = math.random() * 5 + 0.33
    local saw_freq = math.random() * 7 + 0.1
    
    local total_amp = sine_amp + square_amp + triangle_amp + saw_amp + noise_amp
    if total_amp == 0 then sine_amp = 0.5 end
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      
      if sine_amp > 0 then
        for osc = 1, num_oscillators do
          local freq = sine_freq * math.random(0.5, 2.0)
          local phase_shift = math.random() * math.pi * 2
          value = value + math.sin(phase * math.pi * 2 * freq + phase_shift) * (sine_amp / num_oscillators)
        end
      end
      if square_amp > 0 then
        local square_phase = phase * square_freq
        local square = (square_phase % 1 < math.random(0.2, 0.8)) and 1 or -1
        value = value + square * square_amp
      end
      if triangle_amp > 0 then
        local tri_phase = (phase * triangle_freq) % 1
        local triangle
        local peak_pos = math.random(0.2, 0.8)
        if tri_phase < peak_pos then
          triangle = (tri_phase / peak_pos) * 2 - 1
        else
          triangle = 1 - ((tri_phase - peak_pos) / (1 - peak_pos)) * 2
        end
        value = value + triangle * triangle_amp
      end
      if saw_amp > 0 then
        local saw_phase = (phase * saw_freq) % 1
        local saw = (saw_phase * 2 - 1)
        if math.random() > 0.5 then saw = -saw end
        value = value + saw * saw_amp
      end
      if noise_amp > 0 then
        local noise = (math.random() * 2 - 1)
        if math.random() > 0.5 then
          noise = noise * (1 - phase * math.random(0.5, 1.0))
        end
        value = value + noise * noise_amp
      end
      
      if total_amp > 0 then
        value = value / total_amp
      end
      target_data[i] = math.floor((value * 32767) + 32768)
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    status_text = string.format("Random mix (s:%.1f sq:%.1f tri:%.1f saw:%.1f n:%.1f)", 
      sine_amp, square_amp, triangle_amp, saw_amp, noise_amp)
  
  elseif method == 2 then
    -- Method 2: Harmonic series with random harmonics
    local fundamental = math.random(1, 6)
    local harmonics = {}
    for h = 1, 12 do
      local prob = math.random(0.4, 0.8) - (h * 0.05)
      harmonics[h] = math.random() > prob and (math.random() * (1.2 - h * 0.08) / h) or 0
    end
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      for h = 1, 12 do
        if harmonics[h] > 0 then
          value = value + math.sin(phase * math.pi * 2 * h * fundamental) * harmonics[h]
        end
      end
      target_data[i] = math.floor((value * 32767) + 32768)
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    
    local active_harmonics = 0
    for h = 1, 12 do
      if harmonics[h] > 0 then active_harmonics = active_harmonics + 1 end
    end
    status_text = string.format("Harmonic series (fund:%d, %d harmonics)", fundamental, active_harmonics)
  
  elseif method == 3 then
    -- Method 3: Bezier curve with random control points
    local control_points = {}
    local num_points = math.random(3, 15)
    for p = 1, num_points do
      local range = math.random(0.5, 2.0)
      control_points[p] = (math.random() * 2 - 1) * range
    end
    
    for i = 1, wave_size do
      local t = (i - 1) / (wave_size - 1)
      local segment = t * (num_points - 1)
      local seg_idx = math.floor(segment)
      local seg_t = segment - seg_idx
      
      local value
      if seg_idx >= num_points - 1 then
        value = control_points[num_points]
      else
        value = control_points[seg_idx + 1] + seg_t * (control_points[seg_idx + 2] - control_points[seg_idx + 1])
      end
      
      target_data[i] = math.floor((value * 32767) + 32768)
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    status_text = string.format("Bezier curve (%d control points)", num_points)
  
  elseif method == 4 then
    -- Method 4: Fractal/chaos waveform
    local chaos_factor = math.random() * 1.2 + 0.05
    local seed_value = (math.random() * 2 - 1) * math.random(0.5, 2.0)
    local feedback = math.random() * 1.2 + 0.05
    local chaos_type = math.random(1, 3)
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      
      if chaos_type == 1 then
        seed_value = chaos_factor * seed_value * (1 - seed_value) + feedback * math.sin(phase * math.pi * 2)
      elseif chaos_type == 2 then
        seed_value = math.sin(seed_value * chaos_factor * math.pi) + feedback * math.cos(phase * math.pi * 4)
      else
        if seed_value < 0.5 then
          seed_value = chaos_factor * seed_value + feedback * math.sin(phase * math.pi * 6)
        else
          seed_value = chaos_factor * (1 - seed_value) + feedback * math.cos(phase * math.pi * 3)
        end
      end
      
      seed_value = math.max(-2, math.min(2, seed_value))
      
      local value = seed_value
      target_data[i] = math.floor((value * 32767) + 32768)
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    
    local chaos_names = {"Logistic", "Sine", "Tent"}
    status_text = string.format("Chaotic waveform (%s, chaos:%.2f, feedback:%.2f)", 
      chaos_names[chaos_type], chaos_factor, feedback)
  
  elseif method == 5 then
    -- Method 5: ULTIMATE CHAOS - Hybrid of all methods with random switching
    local method_switches = {}
    for i = 1, wave_size do
      method_switches[i] = math.random(1, 4)
    end
    
    local sine_amp = math.random() * 2
    local square_amp = math.random() * 1.5
    local triangle_amp = math.random() * 1.8
    local saw_amp = math.random() * 1.2
    local noise_amp = math.random() * 0.8
    
    local fundamental = math.random(1, 8)
    local harmonics = {}
    for h = 1, 16 do
      harmonics[h] = math.random() > 0.5 and (math.random() * 2 / h) or 0
    end
    
    local control_points = {}
    local num_points = math.random(5, 20)
    for p = 1, num_points do
      control_points[p] = (math.random() * 4 - 2)
    end
    
    local chaos_factor = math.random() * 2 + 0.1
    local seed_value = math.random() * 4 - 2
    local feedback = math.random() * 2 + 0.1
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      local current_method = method_switches[i]
      
      if current_method == 1 then
        value = math.sin(phase * math.pi * 2 * math.random(0.5, 8)) * sine_amp * math.random(0.5, 1.5)
        value = value + ((phase * math.random(2, 10)) % 1 < 0.5 and 1 or -1) * square_amp * math.random(0.3, 1.2)
        value = value + (math.random() * 2 - 1) * noise_amp * math.random(0.1, 0.9)
      elseif current_method == 2 then
        for h = 1, math.random(3, 12) do
          if harmonics[h] and harmonics[h] > 0 then
            value = value + math.sin(phase * math.pi * 2 * h * fundamental * math.random(0.8, 1.2)) * harmonics[h]
          end
        end
      elseif current_method == 3 then
        local t = phase
        local segment = t * (num_points - 1)
        local seg_idx = math.floor(segment)
        local seg_t = segment - seg_idx
        if seg_idx >= num_points - 1 then
          value = control_points[num_points] or 0
        else
          local p1 = control_points[seg_idx + 1] or 0
          local p2 = control_points[seg_idx + 2] or 0
          value = p1 + seg_t * (p2 - p1)
        end
        value = value * math.random(0.5, 2.0)
      else
        seed_value = math.sin(seed_value * chaos_factor * math.pi * math.random(0.5, 2.0)) + 
                    feedback * math.cos(phase * math.pi * math.random(2, 12))
        seed_value = math.max(-3, math.min(3, seed_value))
        value = seed_value
      end
      
      if math.random() > 0.7 then
        local contamination = math.sin(phase * math.pi * math.random(4, 32)) * math.random(0.1, 0.5)
        value = value + contamination
      end
      
      target_data[i] = math.floor((value * 16383) + 32768)
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    status_text = string.format("ULTIMATE CHAOS (hybrid switching, %d methods)", num_points)
  
  else
    -- Method 6: Spectral/Additive synthesis with random partials
    local num_partials = math.random(3, 16)
    local fundamental_freq = math.random(0.5, 4.0)
    
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local value = 0
      
      for partial = 1, num_partials do
        local freq_ratio = partial * math.random(0.8, 1.2)
        local amplitude = math.random(0.1, 1.0) / partial
        local phase_offset = math.random() * math.pi * 2
        
        value = value + math.sin(phase * math.pi * 2 * fundamental_freq * freq_ratio + phase_offset) * amplitude
      end
      
      target_data[i] = math.floor((value * 32767 / num_partials) + 32768)
      target_data[i] = math.max(0, math.min(65535, target_data[i]))
    end
    status_text = string.format("Spectral synthesis (%d partials, fund:%.1f)", num_partials, fundamental_freq)
  end
  
  -- Reduced post-processing for wavetables (less aggressive smoothing)
  local post_fx = math.random(1, 9)  -- Increased chance of no post-processing
  if post_fx == 1 then
    local bit_crush = math.random(8, 15)
    local crush_factor = math.pow(2, 16 - bit_crush)
    for i = 1, wave_size do
      target_data[i] = math.floor(target_data[i] / crush_factor) * crush_factor
    end
    status_text = status_text .. " + BitCrush"
  elseif post_fx == 2 then
    local drive = math.random(1.5, 4.0)
    for i = 1, wave_size do
      local normalized = (target_data[i] - 32768) / 32768
      normalized = math.tanh(normalized * drive) / drive
      target_data[i] = math.floor(normalized * 32768 + 32768)
    end
    status_text = status_text .. " + Distortion"
  elseif post_fx == 3 then
    local fm_freq = math.random(0.5, 8.0)
    local fm_depth = math.random(0.1, 0.8)
    for i = 1, wave_size do
      local phase = (i - 1) / wave_size
      local fm_mod = math.sin(phase * math.pi * 2 * fm_freq) * fm_depth
      local mod_phase = phase + fm_mod
      if mod_phase >= 0 and mod_phase <= 1 then
        local mod_idx = math.floor(mod_phase * (wave_size - 1)) + 1
        if mod_idx >= 1 and mod_idx <= wave_size then
          target_data[i] = (target_data[i] + target_data[mod_idx]) / 2
        end
      end
    end
    status_text = status_text .. " + FM"
  elseif post_fx == 4 then
    -- Chebyshev polynomial waveshaping
    local order = math.random(2, 6)  -- Use 2nd to 6th order Chebyshev polynomials
    local drive = math.random(0.5, 2.0)
    for i = 1, wave_size do
      local normalized = (target_data[i] - 32768) / 32768  -- Convert to -1 to 1 range
      normalized = math.max(-1, math.min(1, normalized * drive))  -- Apply drive and clamp
      
      local shaped
      if order == 2 then
        -- T2(x) = 2x^2 - 1
        shaped = 2 * normalized * normalized - 1
      elseif order == 3 then
        -- T3(x) = 4x^3 - 3x
        shaped = 4 * normalized * normalized * normalized - 3 * normalized
      elseif order == 4 then
        -- T4(x) = 8x^4 - 8x^2 + 1
        local x2 = normalized * normalized
        shaped = 8 * x2 * x2 - 8 * x2 + 1
      elseif order == 5 then
        -- T5(x) = 16x^5 - 20x^3 + 5x
        local x2 = normalized * normalized
        local x3 = x2 * normalized
        shaped = 16 * x3 * x2 - 20 * x3 + 5 * normalized
      else -- order == 6
        -- T6(x) = 32x^6 - 48x^4 + 18x^2 - 1
        local x2 = normalized * normalized
        local x4 = x2 * x2
        shaped = 32 * x4 * x2 - 48 * x4 + 18 * x2 - 1
      end
      
      -- Clamp result and convert back to 0-65535 range
      shaped = math.max(-1, math.min(1, shaped))
      target_data[i] = math.floor(shaped * 32768 + 32768)
    end
    status_text = status_text .. string.format(" + Chebyshev T%d", order)
  end
  -- post_fx 5-9 means no post-processing (higher chance of clean waveforms)
  
  -- Less aggressive click-free processing for wavetables
  local center_value = 32768
  
  -- Check waveform energy before processing
  local energy_check = 0
  local min_check = 65535
  local max_check = 0
  for i = 1, wave_size do
    local deviation = math.abs(target_data[i] - 32768)
    energy_check = energy_check + deviation
    min_check = math.min(min_check, target_data[i])
    max_check = math.max(max_check, target_data[i])
  end
  local range_check = max_check - min_check
  local avg_energy_check = energy_check / wave_size
  
  -- Only apply click-free processing if waveform has sufficient energy
  if avg_energy_check > 1000 and range_check > 2000 then
    -- Store original values
    local original_first = target_data[1]
    local original_last = target_data[wave_size]
    
    -- Very gentle click-free: only blend 20% towards center for wavetables
    local blend_factor = 0.2
    target_data[1] = math.floor(original_first + (center_value - original_first) * blend_factor)
    target_data[wave_size] = math.floor(original_last + (center_value - original_last) * blend_factor)
    
    -- Ultra-minimal smoothing (only 1-2 samples)
    local smooth_samples = math.min(1, math.floor(wave_size / 128))
    
    if smooth_samples > 0 then
      for i = 2, smooth_samples + 1 do
        local blend = (i - 1) / smooth_samples * 0.1  -- Ultra-gentle blending
        local original_value = target_data[i]
        target_data[i] = math.floor(original_value + (center_value - original_value) * blend)
      end
      
      for i = wave_size - smooth_samples, wave_size - 1 do
        local blend = (wave_size - i) / smooth_samples * 0.1  -- Ultra-gentle blending
        local original_value = target_data[i]
        target_data[i] = math.floor(original_value + (center_value - original_value) * blend)
      end
    end
  end
  
  -- Apply DC offset correction to center the waveform
  PCMWriterRemoveDCOffset()
  
  selected_sample_index = -1
  selection_start = -1
  selection_end = -1
  
  -- Update crossfaded wave if we're working with Wave A/B system
  PCMWriterUpdateCrossfadedWave()
  PCMWriterUpdateLiveSample()  -- Live update sample when generating random waveform
  
  if waveform_canvas then
    waveform_canvas:update()
  end
  PCMWriterUpdateHexDisplay()
  
  -- Set current waveform type to indicate random waveform is active
  current_waveform_type = "random"
  renoise.app():show_status("Generated " .. status_text .. " (entropy: " .. tostring(entropy_seed % 10000) .. ", DC centered) to Wave " .. current_wave_edit)
end

function PCMWriterCreate12RandomInstrument()
  -- Store current AutoSamplify Pakettify state and temporarily disable it to preserve loop settings
  local AutoSamplifyPakettifyState = preferences.pakettiAutoSamplifyPakettify.value
  if preferences.pakettiAutoSamplifyPakettify.value == true or preferences.pakettiAutoSamplifyPakettify.value == false 
  then preferences.pakettiAutoSamplifyPakettify.value = false
  end
  
  -- Clear existing wavetable
  wavetable_waves = {}
  
  -- Preserve the current selection position
  local saved_selected_index = selected_sample_index
  local saved_current_wave_edit = current_wave_edit
  
  -- Create new instrument first
  local song = renoise.song()
  song:insert_instrument_at(song.selected_instrument_index + 1)
  song.selected_instrument_index = song.selected_instrument_index + 1
  -- Apply Paketti default instrument configuration
  pakettiPreferencesDefaultInstrumentLoader()
  local inst = song.selected_instrument
  
  -- Create a base entropy pool for this batch to ensure diversity
  local base_entropy = os.time() * 1000 + math.floor(os.clock() * 1000000)
  
  -- Generate 12 crossfaded random waveforms using Wave A/B system
  for wave_num = 1, 12 do
    -- Add significant entropy per wave to ensure diversity
    local wave_entropy_a = base_entropy + (wave_num * 98765) + math.random(1, 999999)
    local wave_entropy_b = base_entropy + (wave_num * 123456) + math.random(1, 999999)
    
    -- Force different method selection per wave for guaranteed diversity
    local forced_method_a = ((wave_num - 1) % 6) + 1  -- Cycle through methods 1-6
    local forced_method_b = ((wave_num - 1 + 3) % 6) + 1  -- Offset methods for Wave B
    
    -- Generate random Wave A
    current_wave_edit = "A"
    PCMWriterGenerateRandomWaveformWithEntropy(wave_entropy_a, forced_method_a)
    
    -- Generate random Wave B
    current_wave_edit = "B"
    PCMWriterGenerateRandomWaveformWithEntropy(wave_entropy_b, forced_method_b)
    
    -- Set random crossfade amount (0.0 to 1.0)
    crossfade_amount = math.random() * 1.0
    
    -- Update the crossfaded result
    PCMWriterUpdateCrossfadedWave()
    
    -- Create sample slot and export crossfaded result
    if #inst.samples < wave_num then
      inst:insert_sample_at(wave_num)
    end
    
    local sample = inst:sample(wave_num)
    local buffer = sample.sample_buffer
    
    -- Create sample data for crossfaded wave
    buffer:create_sample_data(44100, 16, 1, wave_size)
    buffer:prepare_sample_data_changes()
    
    -- Write crossfaded wave data (wave_data contains the crossfaded result)
    for i = 1, wave_size do
      buffer:set_sample_data(1, i, (wave_data[i] - 32768) / 32768)
    end
    buffer:finalize_sample_data_changes()
    
    -- Set sample properties with crossfade info
    sample.name = string.format("PCM A+B X%.0f%% %02d (%d frames)", crossfade_amount * 100, wave_num, wave_size)
    
    -- Enable loop mode for each sample
    sample.loop_mode = sample_loop_mode
    sample.loop_start = 1
    sample.loop_end = wave_size
    
    -- Set interpolation
    if sample_interpolation_mode == "linear" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
    elseif sample_interpolation_mode == "cubic" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC
    elseif sample_interpolation_mode == "sinc" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
    elseif sample_interpolation_mode == "none" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_NONE
    else
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR -- default
    end
    
    sample.oversample_enabled = sample_oversample_enabled
    sample.autofade = preferences.pakettiLoaderAutofade.value
    
    -- AUTOMATIC PITCH CORRECTION using danoise algorithm
    local pitch_correction = calculate_pitch_correction(44100, wave_size, 1)
    
    -- Only apply correction if deviation is significant (>2 cents)
    local cents_deviation = math.abs(pitch_correction.cents)
    if cents_deviation > 2 then
      sample.transpose = pitch_correction.transpose
      sample.fine_tune = pitch_correction.fine_tune
      
      -- Update sample name to include pitch correction info
      local correction_status = string.format(" -> Auto-tuned to %s (T:%d, F:%d)", 
        pitch_correction.note_name, pitch_correction.transpose, pitch_correction.fine_tune)
      
      sample.name = sample.name .. correction_status
    end
    
    -- Update progress with crossfade info
    renoise.app():show_status(string.format("Random A+B crossfade %d/12 (X%.0f%%), auto-pitch correction", wave_num, crossfade_amount * 100))
    
    -- Small delay to ensure entropy changes between iterations
    for delay = 1, 1000 do
      math.random() -- Burn some cycles and advance RNG state
    end
  end
  
  -- Restore the selection position and current wave edit mode
  selected_sample_index = saved_selected_index
  current_wave_edit = saved_current_wave_edit
  
  -- Update displays
  if waveform_canvas then
    waveform_canvas:update()
  end
  PCMWriterUpdateHexDisplay()
  
  inst.name = string.format("PCM Random A+B Crossfade (%d waves, %d frames) + Auto-Pitch", 12, wave_size)
  
  -- Select the first sample
  song.selected_sample_index = 1
  
  renoise.app():show_status("Created 12 Random A+B Crossfade Instrument (12 crossfaded waves) with auto-pitch correction")
  
  -- Return focus to Renoise main window
--  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  -- Restore AutoSamplify Pakettify state
  preferences.pakettiAutoSamplifyPakettify.value = AutoSamplifyPakettifyState
end

function PCMWriterCreate12ChebyshevInstrument()
  -- Store current AutoSamplify Pakettify state and temporarily disable it to preserve loop settings
  local AutoSamplifyPakettifyState = preferences.pakettiAutoSamplifyPakettify.value
  if preferences.pakettiAutoSamplifyPakettify.value == true or preferences.pakettiAutoSamplifyPakettify.value == false 
  then preferences.pakettiAutoSamplifyPakettify.value = false
  end
  
  -- Clear existing wavetable
  wavetable_waves = {}
  
  -- Preserve the current selection position
  local saved_selected_index = selected_sample_index
  
  -- Create new instrument first
  local song = renoise.song()
  song:insert_instrument_at(song.selected_instrument_index + 1)
  song.selected_instrument_index = song.selected_instrument_index + 1
  -- Apply Paketti default instrument configuration
  pakettiPreferencesDefaultInstrumentLoader()
  
  -- Base waveforms to apply Chebyshev polynomials to
  local base_waveforms = {"sine", "triangle", "saw", "square"}
  
  -- Generate 12 Chebyshev-processed waveforms
  for wave_num = 1, 12 do
    -- Select base waveform (cycle through the 4 base types)
    local base_waveform = base_waveforms[((wave_num - 1) % 4) + 1]
    
    -- Generate base waveform
    PCMWriterGenerateWaveform(base_waveform)
    
    -- Apply random Chebyshev polynomial (T2-T8)
    local chebyshev_order = math.random(2, 8)
    local drive_amount = math.random(50, 200) / 100  -- 0.5 to 2.0 drive
    
    PCMWriterApplyChebyshevWaveshaping(chebyshev_order, drive_amount)
    
    -- Apply DC offset removal to center the waveform
    PCMWriterRemoveDCOffset()
    
    -- Update crossfaded wave and live sample
    PCMWriterUpdateCrossfadedWave()
    PCMWriterUpdateLiveSample()
    
    -- Set current waveform type
    current_waveform_type = "chebyshev"
    
    -- Add current waveform to wavetable
    local new_wave = {data = table.create(), name = string.format("Cheby_%s_T%d", base_waveform:sub(1,3), chebyshev_order)}
    
    -- Get current wave data (A or B)
    local target_data = PCMWriterGetCurrentWaveData()
    
    -- Copy current editor wave to new wavetable wave
    for i = 1, wave_size do
      new_wave.data[i] = target_data[i]
    end
    
    table.insert(wavetable_waves, new_wave)
    current_wave_index = #wavetable_waves
    
    -- Update progress
    renoise.app():show_status(string.format("Generating Chebyshev wavetable... %d/12 (T%d on %s)", wave_num, chebyshev_order, base_waveform))
    
    -- Small delay to ensure randomness changes between iterations
    for delay = 1, 500 do
      math.random()
    end
  end
  
  -- Reset editor state 
  selected_sample_index = -1
  selection_start = -1
  selection_end = -1
  
  -- Update the wavetable count display
  if wavetable_count_text then
    wavetable_count_text.text = string.format("Wavetable Tools (%d/12)", #wavetable_waves)
  end
  
  -- Export the wavetable to instrument
  local inst = song.selected_instrument
  
  -- Create separate sample slots for each wave (up to 12)
  for wave_idx, wave in ipairs(wavetable_waves) do
    -- Create sample slot
    if #inst.samples < wave_idx then
      inst:insert_sample_at(wave_idx)
    end
    
    local sample = inst:sample(wave_idx)
    local buffer = sample.sample_buffer
    
    -- Create sample data for this single wave
    buffer:create_sample_data(44100, 16, 1, wave_size)
    buffer:prepare_sample_data_changes()
    
    -- Write this wave's data
    for i = 1, wave_size do
      buffer:set_sample_data(1, i, (wave.data[i] - 32768) / 32768)
    end
    buffer:finalize_sample_data_changes()
    
    -- Set sample properties
    sample.name = string.format("PCM %s (%d frames)", wave.name, wave_size)
    
    -- Enable loop mode for each sample
    sample.loop_mode = sample_loop_mode
    sample.loop_start = 1
    sample.loop_end = wave_size
    
    -- Set interpolation
    if sample_interpolation_mode == "linear" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
    elseif sample_interpolation_mode == "cubic" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC
    elseif sample_interpolation_mode == "sinc" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
    elseif sample_interpolation_mode == "none" then
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_NONE
    else
      sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR -- default
    end
    
    sample.oversample_enabled = sample_oversample_enabled
    sample.autofade = preferences.pakettiLoaderAutofade.value
  end
  
  inst.name = string.format("PCM Chebyshev Wavetable (%d waves, %d frames)", #wavetable_waves, wave_size)
  
  -- Select the first sample
  song.selected_sample_index = 1
  
  -- Update displays
  if waveform_canvas then
    waveform_canvas:update()
  end
  PCMWriterUpdateHexDisplay()
  
  renoise.app():show_status("Created 12 Chebyshev Instrument with wavetable (12 waves)")
  
  -- Return focus to Renoise main window
--  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  -- Restore AutoSamplify Pakettify state
  preferences.pakettiAutoSamplifyPakettify.value = AutoSamplifyPakettifyState
end

function PCMWriterSaveWavetable()
  if #wavetable_waves == 0 then
    renoise.app():show_status("No waves in wavetable to save")
    return
  end
  
  local suggested_name = string.format("wavetable_%dwaves_%dsamples.wav", #wavetable_waves, wave_size)
  local filename = renoise.app():prompt_for_filename_to_write(".wav", suggested_name)
  
  if filename then
    local file = io.open(filename, "wb")
    if file then
      local total_samples = #wavetable_waves * wave_size  -- Use wave_size (512) not wavetable_size
      local header = PCMWriterCreateWavHeader(44100, 1, total_samples, 16)
      file:write(header)
      
      -- Write all waves sequentially
      for _, wave in ipairs(wavetable_waves) do
        for i = 1, wave_size do  -- Use wave_size (512) not wavetable_size
          local value = wave.data[i] - 32768 -- Convert to signed
          value = math.max(-32768, math.min(32767, value))
          if value < 0 then value = value + 65536 end
          file:write(string.char(value % 256))
          file:write(string.char(math.floor(value / 256)))
        end
      end
      file:close()
      renoise.app():show_status(string.format("Wavetable saved: %d waves, %s", #wavetable_waves, filename))
    else
      renoise.app():show_status("Could not save wavetable")
    end
  else
    renoise.app():show_status("Save wavetable cancelled")
  end
end

function PCMWriterExportToSample()
  -- Store current AutoSamplify Pakettify state and temporarily disable it to preserve loop settings
  local AutoSamplifyPakettifyState = preferences.pakettiAutoSamplifyPakettify.value
  if preferences.pakettiAutoSamplifyPakettify.value == true or preferences.pakettiAutoSamplifyPakettify.value == false 
  then preferences.pakettiAutoSamplifyPakettify.value = false
  end
  
  local song = renoise.song()
  local inst = song.selected_instrument
  
  print("DEBUG: Starting export to sample")
  print("DEBUG: Current instrument has " .. #inst.samples .. " samples")
  print("DEBUG: Plugin loaded: " .. tostring(inst.plugin_properties.plugin_loaded))
  
  -- Check if instrument has samples or plugins, if so create new instrument
  -- OR if instrument is completely empty, apply paketti defaults
  if #inst.samples > 0 or inst.plugin_properties.plugin_loaded then
    print("DEBUG: Creating new instrument")
    song:insert_instrument_at(song.selected_instrument_index + 1)
    song.selected_instrument_index = song.selected_instrument_index + 1
    inst = song.selected_instrument
    
    -- Apply Paketti default instrument configuration
    print("DEBUG: Applying pakettiPreferencesDefaultInstrumentLoader")
    if pakettiPreferencesDefaultInstrumentLoader then
      pakettiPreferencesDefaultInstrumentLoader()
      print("DEBUG: pakettiPreferencesDefaultInstrumentLoader applied successfully")
      -- Re-get the instrument reference after loading default configuration
      inst = song.selected_instrument
      print("DEBUG: Instrument now has " .. #inst.samples .. " samples after default loader")
    else
      print("DEBUG: pakettiPreferencesDefaultInstrumentLoader not found")
    end
  elseif #inst.samples == 0 and not inst.plugin_properties.plugin_loaded then
    print("DEBUG: Empty instrument - applying pakettiPreferencesDefaultInstrumentLoader")
    if pakettiPreferencesDefaultInstrumentLoader then
      pakettiPreferencesDefaultInstrumentLoader()
      print("DEBUG: pakettiPreferencesDefaultInstrumentLoader applied successfully to empty instrument")
      -- Re-get the instrument reference after loading default configuration
      inst = song.selected_instrument
      print("DEBUG: Instrument now has " .. #inst.samples .. " samples after default loader")
    else
      print("DEBUG: pakettiPreferencesDefaultInstrumentLoader not found")
    end
  end
  
  -- Always create a new sample slot for our PCM data
  print("DEBUG: Creating new sample slot for PCM data")
  local sample_slot = #inst.samples + 1
  inst:insert_sample_at(sample_slot)
  song.selected_sample_index = sample_slot
  
  local sample = inst:sample(sample_slot)
  local buffer = sample.sample_buffer
  
  print("DEBUG: Using sample slot " .. sample_slot .. " in instrument " .. song.selected_instrument_index)
  
  print("DEBUG: Creating sample data with " .. wave_size .. " frames")
  buffer:create_sample_data(44100, 16, 1, wave_size)
  buffer:prepare_sample_data_changes()
  
  print("DEBUG: Writing sample data")
  -- Export the crossfaded result (wave_data) which is the final mixed output
  for i = 1, wave_size do
    local normalized_value = (wave_data[i] - 32768) / 32768
    buffer:set_sample_data(1, i, normalized_value)
  end
  buffer:finalize_sample_data_changes()
  
  print("DEBUG: Setting sample properties")
  sample.name = string.format("PCM Crossfade (X%.0f%%, %d frames)", crossfade_amount * 100, wave_size)
  inst.name = string.format("PCM Crossfade (X%.0f%%, %d frames)", crossfade_amount * 100, wave_size)
  
  -- Sample is already selected (set above)
  
  -- Enable loop mode and set loop points
  sample.loop_mode = sample_loop_mode
  sample.loop_start = 1
  sample.loop_end = wave_size
  
  -- AUTOMATIC PITCH CORRECTION using danoise algorithm
  print("DEBUG: Applying automatic pitch correction...")
  local pitch_correction = calculate_pitch_correction(44100, wave_size, 1)
  
  -- Only apply correction if deviation is significant (>2 cents)
  local cents_deviation = math.abs(pitch_correction.cents)
  if cents_deviation > 2 then
    sample.transpose = pitch_correction.transpose
    sample.fine_tune = pitch_correction.fine_tune
    
    print(string.format("DEBUG: Auto-corrected pitch: %s (%.1f Hz) -> transpose: %d, fine_tune: %d (%.1f cents %s)", 
      pitch_correction.note_name, pitch_correction.frequency, 
      pitch_correction.transpose, pitch_correction.fine_tune,
      cents_deviation, pitch_correction.cent_direction))
    
    -- Update status to include pitch correction info
    local correction_status = string.format(" -> Auto-tuned to %s (T:%d, F:%d)", 
      pitch_correction.note_name, pitch_correction.transpose, pitch_correction.fine_tune)
    
    sample.name = sample.name .. correction_status
    inst.name = inst.name .. correction_status
  else
    print(string.format("DEBUG: Sample already well-tuned: %s (%.1f Hz, %.1f cents %s)", 
      pitch_correction.note_name, pitch_correction.frequency,
      cents_deviation, pitch_correction.cent_direction))
  end
  
  -- Set interpolation mode based on sample export settings
  if sample_interpolation_mode == "linear" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
  elseif sample_interpolation_mode == "cubic" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC
  elseif sample_interpolation_mode == "sinc" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  elseif sample_interpolation_mode == "none" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_NONE
  else
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR -- default
  end
  
  -- Enable oversampling based on setting
  sample.oversample_enabled = sample_oversample_enabled
  sample.autofade = preferences.pakettiLoaderAutofade.value
  
  -- Remove all placeholder samples if they exist
  PCMWriterRemovePlaceholderSamples(inst, sample_slot)
  
  print("DEBUG: Export completed successfully")
  renoise.app():show_status(string.format("Crossfaded wave exported (X%.0f%%) with %s interpolation, oversampling %s, auto-pitch correction", crossfade_amount * 100, sample_interpolation_mode, sample_oversample_enabled and "enabled" or "disabled"))
  
  -- Restore AutoSamplify Pakettify state
  preferences.pakettiAutoSamplifyPakettify.value = AutoSamplifyPakettifyState
end

function PCMWriterRandomExportToSlot()
  -- Generate a random waveform first
  PCMWriterGenerateRandomWaveform()
  
  -- Then export it to a sample slot
  PCMWriterExportToSample()
  
  renoise.app():show_status("Random waveform generated and exported to sample slot")
end

function PCMWriterExportWaveAToSample()
  -- Store current AutoSamplify Pakettify state and temporarily disable it to preserve loop settings
  local AutoSamplifyPakettifyState = preferences.pakettiAutoSamplifyPakettify.value
  if preferences.pakettiAutoSamplifyPakettify.value == true or preferences.pakettiAutoSamplifyPakettify.value == false 
  then preferences.pakettiAutoSamplifyPakettify.value = false
  end
  
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- Check if instrument has samples or plugins, if so create new instrument
  if #inst.samples > 0 or inst.plugin_properties.plugin_loaded then
    song:insert_instrument_at(song.selected_instrument_index + 1)
    song.selected_instrument_index = song.selected_instrument_index + 1
    inst = song.selected_instrument
    -- Apply Paketti default instrument configuration
    if pakettiPreferencesDefaultInstrumentLoader then
      pakettiPreferencesDefaultInstrumentLoader()
      inst = song.selected_instrument
    end
  end
  
  -- Always create a new sample slot for our PCM data
  local sample_slot = #inst.samples + 1
  inst:insert_sample_at(sample_slot)
  song.selected_sample_index = sample_slot
  
  local sample = inst:sample(sample_slot)
  local buffer = sample.sample_buffer
  
  buffer:create_sample_data(44100, 16, 1, wave_size)
  buffer:prepare_sample_data_changes()
  
  -- Export Wave A specifically
  for i = 1, wave_size do
    local normalized_value = (wave_data_a[i] - 32768) / 32768
    buffer:set_sample_data(1, i, normalized_value)
  end
  buffer:finalize_sample_data_changes()
  
  sample.name = string.format("PCM Wave A (%d frames)", wave_size)
  inst.name = string.format("PCM Wave A (%d frames)", wave_size)
  
  -- Enable loop mode and set properties
  sample.loop_mode = sample_loop_mode
  sample.loop_start = 1
  sample.loop_end = wave_size
  
  -- AUTOMATIC PITCH CORRECTION using danoise algorithm
  local pitch_correction = calculate_pitch_correction(44100, wave_size, 1)
  
  -- Only apply correction if deviation is significant (>2 cents)
  local cents_deviation = math.abs(pitch_correction.cents)
  if cents_deviation > 2 then
    sample.transpose = pitch_correction.transpose
    sample.fine_tune = pitch_correction.fine_tune
    
    -- Update status to include pitch correction info
    local correction_status = string.format(" -> Auto-tuned to %s (T:%d, F:%d)", 
      pitch_correction.note_name, pitch_correction.transpose, pitch_correction.fine_tune)
    
    sample.name = sample.name .. correction_status
    inst.name = inst.name .. correction_status
  end
  
  -- Set interpolation mode
  if sample_interpolation_mode == "linear" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
  elseif sample_interpolation_mode == "cubic" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC
  elseif sample_interpolation_mode == "sinc" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  elseif sample_interpolation_mode == "none" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_NONE
  else
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
  end
  
  sample.oversample_enabled = sample_oversample_enabled
  sample.autofade = preferences.pakettiLoaderAutofade.value
  
  -- Remove all placeholder samples if they exist
  PCMWriterRemovePlaceholderSamples(inst, sample_slot)
  
  renoise.app():show_status(string.format("Wave A exported with %s interpolation, oversampling %s, auto-pitch correction", sample_interpolation_mode, sample_oversample_enabled and "enabled" or "disabled"))
  
  -- Restore AutoSamplify Pakettify state
  preferences.pakettiAutoSamplifyPakettify.value = AutoSamplifyPakettifyState
end

function PCMWriterExportWaveBToSample()
  -- Store current AutoSamplify Pakettify state and temporarily disable it to preserve loop settings
  local AutoSamplifyPakettifyState = preferences.pakettiAutoSamplifyPakettify.value
  if preferences.pakettiAutoSamplifyPakettify.value == true or preferences.pakettiAutoSamplifyPakettify.value == false 
  then preferences.pakettiAutoSamplifyPakettify.value = false
  end
  
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- Check if instrument has samples or plugins, if so create new instrument
  if #inst.samples > 0 or inst.plugin_properties.plugin_loaded then
    song:insert_instrument_at(song.selected_instrument_index + 1)
    song.selected_instrument_index = song.selected_instrument_index + 1
    inst = song.selected_instrument
    -- Apply Paketti default instrument configuration
    if pakettiPreferencesDefaultInstrumentLoader then
      pakettiPreferencesDefaultInstrumentLoader()
      inst = song.selected_instrument
    end
  end
  
  -- Always create a new sample slot for our PCM data
  local sample_slot = #inst.samples + 1
  inst:insert_sample_at(sample_slot)
  song.selected_sample_index = sample_slot
  
  local sample = inst:sample(sample_slot)
  local buffer = sample.sample_buffer
  
  buffer:create_sample_data(44100, 16, 1, wave_size)
  buffer:prepare_sample_data_changes()
  
  -- Export Wave B specifically
  for i = 1, wave_size do
    local normalized_value = (wave_data_b[i] - 32768) / 32768
    buffer:set_sample_data(1, i, normalized_value)
  end
  buffer:finalize_sample_data_changes()
  
  sample.name = string.format("PCM Wave B (%d frames)", wave_size)
  inst.name = string.format("PCM Wave B (%d frames)", wave_size)
  
  -- Enable loop mode and set properties
  sample.loop_mode = sample_loop_mode
  sample.loop_start = 1
  sample.loop_end = wave_size
  
  -- AUTOMATIC PITCH CORRECTION using danoise algorithm
  local pitch_correction = calculate_pitch_correction(44100, wave_size, 1)
  
  -- Only apply correction if deviation is significant (>2 cents)
  local cents_deviation = math.abs(pitch_correction.cents)
  if cents_deviation > 2 then
    sample.transpose = pitch_correction.transpose
    sample.fine_tune = pitch_correction.fine_tune
    
    -- Update status to include pitch correction info
    local correction_status = string.format(" -> Auto-tuned to %s (T:%d, F:%d)", 
      pitch_correction.note_name, pitch_correction.transpose, pitch_correction.fine_tune)
    
    sample.name = sample.name .. correction_status
    inst.name = inst.name .. correction_status
  end
  
  -- Set interpolation mode
  if sample_interpolation_mode == "linear" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
  elseif sample_interpolation_mode == "cubic" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC
  elseif sample_interpolation_mode == "sinc" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  elseif sample_interpolation_mode == "none" then
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_NONE
  else
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
  end
  
  sample.oversample_enabled = sample_oversample_enabled
  sample.autofade = preferences.pakettiLoaderAutofade.value
  
  -- Remove all placeholder samples if they exist
  PCMWriterRemovePlaceholderSamples(inst, sample_slot)
  
  renoise.app():show_status(string.format("Wave B exported with %s interpolation, oversampling %s, auto-pitch correction", sample_interpolation_mode, sample_oversample_enabled and "enabled" or "disabled"))
  
  -- Restore AutoSamplify Pakettify state
  preferences.pakettiAutoSamplifyPakettify.value = AutoSamplifyPakettifyState
end

function PCMWriterExportWaveAAndBToSample()
  -- Validate track type before proceeding
  if not PCMWriterValidateTrackForWavetable() then
    return
  end
  
  -- Store current AutoSamplify Pakettify state and temporarily disable it to preserve loop settings
  local AutoSamplifyPakettifyState = preferences.pakettiAutoSamplifyPakettify.value
  if preferences.pakettiAutoSamplifyPakettify.value == true or preferences.pakettiAutoSamplifyPakettify.value == false 
  then preferences.pakettiAutoSamplifyPakettify.value = false
  end
  
  -- Set flag to prevent AutoSamplify from processing during sample creation
  PCMWriterSetCreatingSamples(true)
  
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- Handle Live Pickup Mode collision: Turn off if active to prevent interference
  local was_live_pickup_active = live_pickup_mode
  if live_pickup_mode then
    print("DEBUG: Wave A&B creation - temporarily disabling Live Pickup Mode to prevent interference")
    live_pickup_mode = false
    renoise.app():show_status("Live Pickup Mode disabled temporarily for Wave A&B creation")
  end
  
  -- Always create a new instrument for A&B export
  song:insert_instrument_at(song.selected_instrument_index + 1)
  song.selected_instrument_index = song.selected_instrument_index + 1
  inst = song.selected_instrument
  
  -- Load the pre-configured 12st_WT.xrni instrument
  local preset_path = "Presets" .. separator .. "12st_WT.xrni"
  
  -- Function to check if a file exists
  local function file_exists(file)
    local f = io.open(file, "r")
    if f then f:close() end
    return f ~= nil
  end

  -- Check if the file exists, fallback if needed
  if not file_exists(preset_path) then
    preset_path = "Presets" .. separator .. "12st_Pitchbend.xrni"
    renoise.app():show_status("12st_WT.xrni not found, using fallback 12st_Pitchbend.xrni")
  end

  print("Loading instrument from path: " .. preset_path)
  renoise.app():load_instrument(preset_path)
  inst = song.selected_instrument
  
  -- Create first sample slot for Wave A
  local sample_slot_a = #inst.samples + 1
  inst:insert_sample_at(sample_slot_a)
  
  local sample_a = inst:sample(sample_slot_a)
  local buffer_a = sample_a.sample_buffer
  
  buffer_a:create_sample_data(44100, 16, 1, wave_size)
  buffer_a:prepare_sample_data_changes()
  
  -- Export Wave A to first slot
  for i = 1, wave_size do
    local normalized_value = (wave_data_a[i] - 32768) / 32768
    buffer_a:set_sample_data(1, i, normalized_value)
  end
  buffer_a:finalize_sample_data_changes()
  
  sample_a.name = string.format("PCM Wave A (%d frames)", wave_size)
  
  -- Enable loop mode and set properties for Wave A
  print("DEBUG: Setting Wave A loop mode to: " .. tostring(sample_loop_mode))
  sample_a.loop_mode = sample_loop_mode
  sample_a.loop_start = 1
  sample_a.loop_end = wave_size
  print("DEBUG: Wave A loop mode after setting: " .. tostring(sample_a.loop_mode))
  
  -- AUTOMATIC PITCH CORRECTION for Wave A
  local pitch_correction_a = calculate_pitch_correction(44100, wave_size, 1)
  local correction_status_a = ""
  
  -- Only apply correction if deviation is significant (>2 cents)
  local cents_deviation_a = math.abs(pitch_correction_a.cents)
  if cents_deviation_a > 2 then
    sample_a.transpose = pitch_correction_a.transpose
    sample_a.fine_tune = pitch_correction_a.fine_tune
    correction_status_a = string.format(" -> Auto-tuned to %s (T:%d, F:%d)", 
      pitch_correction_a.note_name, pitch_correction_a.transpose, pitch_correction_a.fine_tune)
    sample_a.name = sample_a.name .. correction_status_a
  end
  
  -- Set interpolation mode for Wave A
  if sample_interpolation_mode == "linear" then
    sample_a.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
  elseif sample_interpolation_mode == "cubic" then
    sample_a.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC
  elseif sample_interpolation_mode == "sinc" then
    sample_a.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  elseif sample_interpolation_mode == "none" then
    sample_a.interpolation_mode = renoise.Sample.INTERPOLATE_NONE
  else
    sample_a.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
  end
  
  sample_a.oversample_enabled = sample_oversample_enabled
  sample_a.autofade = preferences.pakettiLoaderAutofade.value
  
  -- Create second sample slot for Wave B
  local sample_slot_b = #inst.samples + 1
  inst:insert_sample_at(sample_slot_b)
  song.selected_sample_index = sample_slot_b
  
  local sample_b = inst:sample(sample_slot_b)
  local buffer_b = sample_b.sample_buffer
  
  buffer_b:create_sample_data(44100, 16, 1, wave_size)
  buffer_b:prepare_sample_data_changes()
  
  -- Export Wave B to second slot
  for i = 1, wave_size do
    local normalized_value = (wave_data_b[i] - 32768) / 32768
    buffer_b:set_sample_data(1, i, normalized_value)
  end
  buffer_b:finalize_sample_data_changes()
  
  sample_b.name = string.format("PCM Wave B (%d frames)", wave_size)
  
  -- Enable loop mode and set properties for Wave B
  print("DEBUG: Setting Wave B loop mode to: " .. tostring(sample_loop_mode))
  sample_b.loop_mode = sample_loop_mode
  sample_b.loop_start = 1
  sample_b.loop_end = wave_size
  print("DEBUG: Wave B loop mode after setting: " .. tostring(sample_b.loop_mode))
  
  -- AUTOMATIC PITCH CORRECTION for Wave B
  local pitch_correction_b = calculate_pitch_correction(44100, wave_size, 1)
  local correction_status_b = ""
  
  -- Only apply correction if deviation is significant (>2 cents)
  local cents_deviation_b = math.abs(pitch_correction_b.cents)
  if cents_deviation_b > 2 then
    sample_b.transpose = pitch_correction_b.transpose
    sample_b.fine_tune = pitch_correction_b.fine_tune
    correction_status_b = string.format(" -> Auto-tuned to %s (T:%d, F:%d)", 
      pitch_correction_b.note_name, pitch_correction_b.transpose, pitch_correction_b.fine_tune)
    sample_b.name = sample_b.name .. correction_status_b
  end
  
  -- Set interpolation mode for Wave B
  if sample_interpolation_mode == "linear" then
    sample_b.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
  elseif sample_interpolation_mode == "cubic" then
    sample_b.interpolation_mode = renoise.Sample.INTERPOLATE_CUBIC
  elseif sample_interpolation_mode == "sinc" then
    sample_b.interpolation_mode = renoise.Sample.INTERPOLATE_SINC
  elseif sample_interpolation_mode == "none" then
    sample_b.interpolation_mode = renoise.Sample.INTERPOLATE_NONE
  else
    sample_b.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
  end
  
  sample_b.oversample_enabled = sample_oversample_enabled
  sample_b.autofade = preferences.pakettiLoaderAutofade.value
  
  -- Assign each sample to its corresponding FX chain (the 12st_WT.xrni already has chains configured)
  sample_a.device_chain_index = 1
  sample_b.device_chain_index = 2
  
  -- Set FX chain names to match sample names for visual consistency
  if #inst.sample_device_chains >= 1 then
    inst.sample_device_chains[1].name = sample_a.name
  end
  if #inst.sample_device_chains >= 2 then
    inst.sample_device_chains[2].name = sample_b.name
  end
  
  -- Add track device chain setup for controlling the instrument
  -- === TRACK DEVICE CHAIN RECREATION ===
  -- Loading device 2: *Instr. Macros (*Instr. Macros)
  loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, false)
  if renoise.song().selected_device then
    renoise.song().selected_device.display_name = "PAKETTI_PLACEHOLDER_002"
  else
    renoise.app():show_status("Warning: Could not set display name for *Instr. Macros device - no selected device")
  end

  -- Loading device 1: *LFO (*LFO)
  loadnative("Audio/Effects/Native/*LFO", nil, nil, false)
  if renoise.song().selected_device then
    renoise.song().selected_device.display_name = "PAKETTI_PLACEHOLDER_001"
  else
    renoise.app():show_status("Warning: Could not set display name for *LFO device - no selected device")
  end
  -- PHASE 2: Apply XML to ALL devices (Last to First)
  -- Apply XML for device 2: *Instr. Macros
  for i, device in ipairs(renoise.song().selected_track.devices) do
    if device.display_name == "PAKETTI_PLACEHOLDER_002" then
      -- Safely check device type and set preset data with error handling
      local success, device_name = pcall(function() return device.name end)
      if success and device_name == "*Instr. Macros" then
        local success2, err = pcall(function()
          device.active_preset_data = [=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="InstrumentMacroDevice">
    <IsMaximized>false</IsMaximized>
  </DeviceSlot>
</FilterDevicePreset>
]=]
        end)
        if success2 then
          print("DEBUG: Successfully applied preset data to *Instr. Macros device")
        else
          print("DEBUG: Error applying preset data to *Instr. Macros device: " .. tostring(err))
        end
      else
        if success then
          print("DEBUG: Device type mismatch - expected *Instr. Macros, got: " .. tostring(device_name))
          renoise.app():show_status("Warning: Device type mismatch for *Instr. Macros - got " .. tostring(device_name))
        else
          print("DEBUG: Error accessing device name: " .. tostring(device_name))
        end
      end
      break
    end
  end
  -- Apply XML for device 1: *LFO
  for i, device in ipairs(renoise.song().selected_track.devices) do
    if device.display_name == "PAKETTI_PLACEHOLDER_001" then
      -- Safely check device type and set preset data with error handling
      local success, device_name = pcall(function() return device.name end)
      if success and device_name == "*LFO" then
        local success2, err = pcall(function()
          device.active_preset_data = [=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="LfoDevice">
    <IsMaximized>true</IsMaximized>
    <Amplitude>
      <Value>0.0</Value>
    </Amplitude>
    <Offset>
      <Value>0.0</Value>
    </Offset>
    <Frequency>
      <Value>0.93749994</Value>
    </Frequency>
    <Type>
      <Value>0.0</Value>
    </Type>
    <CustomEnvelope>
      <PlayMode>Lines</PlayMode>
      <Length>64</Length>
      <ValueQuantum>0.0</ValueQuantum>
      <Polarity>Unipolar</Polarity>
      <Points>
        <Point>0,0.0,0.0</Point>
        <Point>63,1.0,0.0</Point>
      </Points>
    </CustomEnvelope>
    <CustomEnvelopeOneShot>false</CustomEnvelopeOneShot>
    <UseAdjustedEnvelopeLength>true</UseAdjustedEnvelopeLength>
  </DeviceSlot>
</FilterDevicePreset>
]=]
        end)
        if success2 then
          print("DEBUG: Successfully applied preset data to *LFO device")
        else
          print("DEBUG: Error applying preset data to *LFO device: " .. tostring(err))
        end
      else
        if success then
          print("DEBUG: Device type mismatch - expected *LFO, got: " .. tostring(device_name))
          renoise.app():show_status("Warning: Device type mismatch for *LFO - got " .. tostring(device_name))
        else
          print("DEBUG: Error accessing device name: " .. tostring(device_name))
        end
      end
      break
    end
  end
  -- PHASE 3: Apply Parameters to ALL devices (Last to First)
  -- Apply parameters for device 2: *Instr. Macros
  for i, device in ipairs(renoise.song().selected_track.devices) do
    if device.display_name == "PAKETTI_PLACEHOLDER_002" then
      -- Safely check device type and set parameters with error handling
      local success, device_name = pcall(function() return device.name end)
      if success and device_name == "*Instr. Macros" then
        local success2, err = pcall(function()
          device.parameters[2].value = 1
          device.parameters[3].value = 0
          device.parameters[4].value = 0
          device.parameters[5].value = 0
          device.parameters[6].value = 0
          device.parameters[7].value = 0
          device.parameters[8].value = 0.0
          device.parameters[10].value = 0.5
        end)
        if success2 then
          print("DEBUG: Successfully applied parameters to *Instr. Macros device")
        else
          print("DEBUG: Error applying parameters to *Instr. Macros device: " .. tostring(err))
        end
      else
        if success then
          print("DEBUG: Skipping parameter setting for device type mismatch - expected *Instr. Macros, got: " .. tostring(device_name))
        else
          print("DEBUG: Error accessing device name: " .. tostring(device_name))
        end
      end
      break
    end
  end
  -- Apply parameters for device 1: *LFO
  for i, device in ipairs(renoise.song().selected_track.devices) do
    if device.display_name == "PAKETTI_PLACEHOLDER_001" then
      -- Safely check device type and set parameters with error handling
      local success, device_name = pcall(function() return device.name end)
      if success and device_name == "*LFO" then
        local success2, err = pcall(function()
          device.parameters[2].value = 2
          device.parameters[3].value = 10
          device.parameters[4].value = 0
        end)
        if success2 then
          print("DEBUG: Successfully applied parameters to *LFO device")
        else
          print("DEBUG: Error applying parameters to *LFO device: " .. tostring(err))
        end
      else
        if success then
          print("DEBUG: Skipping parameter setting for device type mismatch - expected *LFO, got: " .. tostring(device_name))
        else
          print("DEBUG: Error accessing device name: " .. tostring(device_name))
        end
      end
      break
    end
  end
  -- PHASE 5: Apply Device Properties to ALL devices (Last to First)
  -- Apply properties for device 2: *Instr. Macros
  for i, device in ipairs(renoise.song().selected_track.devices) do
    if device.display_name == "PAKETTI_PLACEHOLDER_002" then
      -- Safely check device type and properties with error handling
      local success, device_name = pcall(function() return device.name end)
      if success and device_name == "*Instr. Macros" then
        local success2, err = pcall(function()
          device.display_name = "*Instr. Macros"
          device.is_maximized = false
          device.is_active = true
        end)
        if success2 then
          print("DEBUG: Successfully applied properties to *Instr. Macros device")
        else
          print("DEBUG: Error applying properties to *Instr. Macros device: " .. tostring(err))
        end
      else
        if success then
          print("DEBUG: Skipping property setting for device type mismatch - expected *Instr. Macros, got: " .. tostring(device_name))
        else
          print("DEBUG: Error accessing device name: " .. tostring(device_name))
        end
      end
      break
    end
  end
  -- Apply properties for device 1: *LFO
  for i, device in ipairs(renoise.song().selected_track.devices) do
    if device.display_name == "PAKETTI_PLACEHOLDER_001" then
      -- Safely check device type and properties with error handling
      local success, device_name = pcall(function() return device.name end)
      if success and device_name == "*LFO" then
        local success2, err = pcall(function()
          -- Keeping default LFO name "*LFO" - allowing parameter-based renaming
          device.display_name = "Wavetable Mod *LFO"
          device.is_maximized = true
          device.parameters[4].show_in_mixer = true
          device.parameters[5].show_in_mixer = true
          device.parameters[6].show_in_mixer = true      
          device.is_active = true
          if device.external_editor_available then
            device.external_editor_visible = false
          end
        end)
        if success2 then
          print("DEBUG: Successfully applied properties to *LFO device")
        else
          print("DEBUG: Error applying properties to *LFO device: " .. tostring(err))
        end
      else
        if success then
          print("DEBUG: Skipping property setting for device type mismatch - expected *LFO, got: " .. tostring(device_name))
        else
          print("DEBUG: Error accessing device name: " .. tostring(device_name))
        end
      end
      break
    end
  end
  
  -- Set instrument name to reflect both waves
  inst.name = string.format("PCM Waves A&B (%d frames)", wave_size)
  if correction_status_a ~= "" or correction_status_b ~= "" then
    inst.name = inst.name .. " -> Auto-tuned"
  end
  
  -- Remove all placeholder samples if they exist
  PCMWriterRemovePlaceholderSamples(inst, sample_slot_b)
  
  -- Re-enable Live Pickup Mode if it was active OR if 12st_WT setup is detected
  if was_live_pickup_active or PCMWriterDetect12stWTSetup() then
    print("DEBUG: Re-enabling Live Pickup Mode for new Wave A&B instrument")
    PCMWriterEnterLivePickupMode()
    renoise.app():show_status(string.format("Waves A&B exported to new instrument with %s interpolation, oversampling %s, auto-pitch correction - Live Pickup Mode re-enabled", sample_interpolation_mode, sample_oversample_enabled and "enabled" or "disabled"))
  else
    renoise.app():show_status(string.format("Waves A&B exported to new instrument with %s interpolation, oversampling %s, auto-pitch correction", sample_interpolation_mode, sample_oversample_enabled and "enabled" or "disabled"))
  end
  
  -- Clear flag to re-enable AutoSamplify processing (BEFORE restoring auto-pakettify)
  PCMWriterSetCreatingSamples(false)
  
  -- Restore AutoSamplify Pakettify state (AFTER clearing flag)
  preferences.pakettiAutoSamplifyPakettify.value = AutoSamplifyPakettifyState
end

-- Wrapper function for Write A&B followed by Unison processing
function PCMWriterExportWaveAAndBToSampleWithUnison()
  -- Validate track type before proceeding
  if not PCMWriterValidateTrackForWavetable() then
    return
  end
  
  -- Store current AutoSamplify Pakettify state and temporarily disable it to preserve loop settings
  local AutoSamplifyPakettifyState = preferences.pakettiAutoSamplifyPakettify.value
  if preferences.pakettiAutoSamplifyPakettify.value == true or preferences.pakettiAutoSamplifyPakettify.value == false 
  then preferences.pakettiAutoSamplifyPakettify.value = false
  end
  
  -- Set flag to prevent AutoSamplify from processing during sample creation
  PCMWriterSetCreatingSamples(true)
  
  -- Check if Live Pickup Mode was active before Wave A&B creation
  local was_live_pickup_active = live_pickup_mode
  
  -- First call the regular Write A&B function
  PCMWriterExportWaveAAndBToSample()
  
  -- Then call the unison generator
  PakettiCreateUnisonSamples()
  
  -- Update status message to include Live Pickup Mode information if relevant
  if was_live_pickup_active or live_pickup_mode then
    renoise.app():show_status("Waves A&B exported and unison processing applied - Live Pickup Mode enabled")
  else
    renoise.app():show_status("Waves A&B exported and unison processing applied")
  end
  
  -- Clear flag to re-enable AutoSamplify processing (BEFORE restoring auto-pakettify)
  PCMWriterSetCreatingSamples(false)
  
  -- Restore AutoSamplify Pakettify state (AFTER clearing flag)
  preferences.pakettiAutoSamplifyPakettify.value = AutoSamplifyPakettifyState
end

-- Wrapper function for Write AKWF A&B followed by Unison processing
function PCMWriterLoad2RandomAKWFAndExportWithUnison()
  -- Validate track type before proceeding
  if not PCMWriterValidateTrackForWavetable() then
    return
  end
  
  -- Store current AutoSamplify Pakettify state and temporarily disable it to preserve loop settings
  local AutoSamplifyPakettifyState = preferences.pakettiAutoSamplifyPakettify.value
  if preferences.pakettiAutoSamplifyPakettify.value == true or preferences.pakettiAutoSamplifyPakettify.value == false 
  then preferences.pakettiAutoSamplifyPakettify.value = false
  end
  
  -- First call the regular Write AKWF A&B function
  PCMWriterLoad2RandomAKWFAndExport()
  
  -- Then call the unison generator
  PakettiCreateUnisonSamples()
  
  renoise.app():show_status("Random AKWF files loaded as A&B and unison processing applied")
  
  -- Restore AutoSamplify Pakettify state
  preferences.pakettiAutoSamplifyPakettify.value = AutoSamplifyPakettifyState
end

-- Remaining selection operation functions
function PCMWriterInvertSelection()
  -- Preserve cursor position
  local saved_cursor = selected_sample_index
  local target_data = PCMWriterGetCurrentWaveData()
  
  -- Invert entire waveform
  for i = 1, wave_size do
    target_data[i] = 65535 - target_data[i]
  end
  
  -- Restore cursor position
  selected_sample_index = saved_cursor
  
  PCMWriterUpdateCrossfadedWave()
  PCMWriterUpdateAllDisplays()
  renoise.app():show_status("Inverted entire waveform to Wave " .. current_wave_edit)
end

function PCMWriterNormalizeSelection()
  -- Preserve cursor position
  local saved_cursor = selected_sample_index
  local target_data = PCMWriterGetCurrentWaveData()
  
  if not PCMWriterHasSelection() then
    -- Normalize whole waveform if no selection
    local min_val = 65535
    local max_val = 0
    for i = 1, wave_size do
      min_val = math.min(min_val, target_data[i])
      max_val = math.max(max_val, target_data[i])
    end
    
    -- Avoid division by zero
    if max_val == min_val then
      selected_sample_index = saved_cursor
      renoise.app():show_status("Waveform has no dynamic range to normalize")
      return
    end
    
    -- Normalize to full range
    local range = max_val - min_val
    for i = 1, wave_size do
      target_data[i] = math.floor(((target_data[i] - min_val) / range) * 65535)
    end
    
    -- Restore cursor position
    selected_sample_index = saved_cursor
    PCMWriterUpdateCrossfadedWave()
    PCMWriterUpdateAllDisplays()
    renoise.app():show_status("Normalized entire waveform to Wave " .. current_wave_edit)
    return
  end
  
  -- Find min/max in selection
  local min_val = 65535
  local max_val = 0
  for i = selection_start, selection_end do
    min_val = math.min(min_val, target_data[i])
    max_val = math.max(max_val, target_data[i])
  end
  
  -- Avoid division by zero
  if max_val == min_val then
    renoise.app():show_status("Selection has no dynamic range to normalize")
    return
  end
  
  -- Normalize to full range
  local range = max_val - min_val
  for i = selection_start, selection_end do
    target_data[i] = math.floor(((target_data[i] - min_val) / range) * 65535)
  end
  
  PCMWriterUpdateCrossfadedWave()
  PCMWriterUpdateAllDisplays()
  renoise.app():show_status(string.format("Normalized samples %d-%d to Wave %s", selection_start, selection_end, current_wave_edit))
end

function PCMWriterFadeInSelection()
  -- Preserve cursor position
  local saved_cursor = selected_sample_index
  local target_data = PCMWriterGetCurrentWaveData()
  
  -- Fade in entire waveform
  for i = 1, wave_size do
    local progress = (i - 1) / (wave_size - 1)
    local center = 32768
    target_data[i] = math.floor(center + (target_data[i] - center) * progress)
  end
  
  -- Restore cursor position
  selected_sample_index = saved_cursor
  
  PCMWriterUpdateCrossfadedWave()
  PCMWriterUpdateAllDisplays()
  renoise.app():show_status("Fade in applied to entire waveform to Wave " .. current_wave_edit)
end

function PCMWriterFadeOutSelection()
  -- Preserve cursor position
  local saved_cursor = selected_sample_index
  local target_data = PCMWriterGetCurrentWaveData()
  
  -- Fade out entire waveform
  for i = 1, wave_size do
    local progress = 1 - ((i - 1) / (wave_size - 1))
    local center = 32768
    target_data[i] = math.floor(center + (target_data[i] - center) * progress)
  end
  
  -- Restore cursor position
  selected_sample_index = saved_cursor
  
  PCMWriterUpdateCrossfadedWave()
  PCMWriterUpdateAllDisplays()
  renoise.app():show_status("Fade out applied to entire waveform to Wave " .. current_wave_edit)
end

function PCMWriterSilenceSelection()
  -- Preserve cursor position
  local saved_cursor = selected_sample_index
  local target_data = PCMWriterGetCurrentWaveData()
  
  -- Silence entire waveform
  for i = 1, wave_size do
    target_data[i] = 32768  -- Center value (silence)
  end
  
  -- Restore cursor position
  selected_sample_index = saved_cursor
  
  PCMWriterUpdateCrossfadedWave()
  PCMWriterUpdateAllDisplays()
  renoise.app():show_status("Silenced entire waveform to Wave " .. current_wave_edit)
end

function PCMWriterReverseSelection()
  -- Preserve cursor position
  local saved_cursor = selected_sample_index
  local target_data = PCMWriterGetCurrentWaveData()
  
  -- Reverse entire waveform
  for i = 1, math.floor(wave_size / 2) do
    local left_idx = i
    local right_idx = wave_size - i + 1
    local temp = target_data[left_idx]
    target_data[left_idx] = target_data[right_idx]
    target_data[right_idx] = temp
  end
  
  -- Restore cursor position
  selected_sample_index = saved_cursor
  
  PCMWriterUpdateCrossfadedWave()
  PCMWriterUpdateAllDisplays()
  renoise.app():show_status("Reversed entire waveform to Wave " .. current_wave_edit)
end

function PCMWriterRemoveDCOffset()
  -- Preserve cursor position
  local saved_cursor = selected_sample_index
  local target_data = PCMWriterGetCurrentWaveData()
  
  -- Calculate the average (DC offset) of the waveform
  local sum = 0
  for i = 1, wave_size do
    sum = sum + target_data[i]
  end
  local average = sum / wave_size
  local center = 32768  -- Target center value (0.5 in normalized range)
  local dc_offset = average - center
  
  -- Remove DC offset by shifting all samples
  for i = 1, wave_size do
    target_data[i] = math.max(0, math.min(65535, target_data[i] - dc_offset))
  end
  
  -- Restore cursor position
  selected_sample_index = saved_cursor
  
  PCMWriterUpdateCrossfadedWave()
  PCMWriterUpdateAllDisplays()
  renoise.app():show_status(string.format("Removed DC offset: %.1f (centered to 0.5)", dc_offset))
end

-- Chebyshev polynomial functions
function PCMWriterChebyshevT2(x)
  -- T2(x) = 2x^2 - 1
  return 2 * x * x - 1
end

function PCMWriterChebyshevT3(x)
  -- T3(x) = 4x^3 - 3x
  return 4 * x * x * x - 3 * x
end

function PCMWriterChebyshevT4(x)
  -- T4(x) = 8x^4 - 8x^2 + 1
  local x2 = x * x
  return 8 * x2 * x2 - 8 * x2 + 1
end

function PCMWriterChebyshevT5(x)
  -- T5(x) = 16x^5 - 20x^3 + 5x
  local x2 = x * x
  local x3 = x2 * x
  return 16 * x3 * x2 - 20 * x3 + 5 * x
end

function PCMWriterChebyshevT6(x)
  -- T6(x) = 32x^6 - 48x^4 + 18x^2 - 1
  local x2 = x * x
  local x4 = x2 * x2
  return 32 * x4 * x2 - 48 * x4 + 18 * x2 - 1
end

function PCMWriterChebyshevT7(x)
  -- T7(x) = 64x^7 - 112x^5 + 56x^3 - 7x
  local x2 = x * x
  local x3 = x2 * x
  local x5 = x3 * x2
  return 64 * x5 * x2 - 112 * x5 + 56 * x3 - 7 * x
end

function PCMWriterChebyshevT8(x)
  -- T8(x) = 128x^8 - 256x^6 + 160x^4 - 32x^2 + 1
  local x2 = x * x
  local x4 = x2 * x2
  local x6 = x4 * x2
  return 128 * x6 * x2 - 256 * x6 + 160 * x4 - 32 * x2 + 1
end

function PCMWriterApplyChebyshevWaveshaping(order, drive)
  -- Preserve cursor position
  local saved_cursor = selected_sample_index
  local target_data = PCMWriterGetCurrentWaveData()
  
  drive = drive or 1.0
  
  for i = 1, wave_size do
    local normalized = (target_data[i] - 32768) / 32768  -- Convert to -1 to 1 range
    normalized = math.max(-1, math.min(1, normalized * drive))  -- Apply drive and clamp
    
    local shaped
    if order == 2 then
      shaped = PCMWriterChebyshevT2(normalized)
    elseif order == 3 then
      shaped = PCMWriterChebyshevT3(normalized)
    elseif order == 4 then
      shaped = PCMWriterChebyshevT4(normalized)
    elseif order == 5 then
      shaped = PCMWriterChebyshevT5(normalized)
    elseif order == 6 then
      shaped = PCMWriterChebyshevT6(normalized)
    elseif order == 7 then
      shaped = PCMWriterChebyshevT7(normalized)
    elseif order == 8 then
      shaped = PCMWriterChebyshevT8(normalized)
    else
      shaped = normalized  -- No change for invalid orders
    end
    
    -- Handle even-order polynomials to prevent DC bias
    if order % 2 == 0 and normalized ~= 0 then
      -- For even-order polynomials, preserve input sign to avoid DC bias
      shaped = shaped * (normalized >= 0 and 1 or -1)
    end
    
    -- Clamp result and convert back to 0-65535 range
    shaped = math.max(-1, math.min(1, shaped))
    target_data[i] = math.floor(shaped * 32768 + 32768)
  end
  
  -- Restore cursor position
  selected_sample_index = saved_cursor
  
  PCMWriterUpdateCrossfadedWave()
  PCMWriterUpdateAllDisplays()
  renoise.app():show_status(string.format("Applied Chebyshev T%d waveshaping (drive: %.1f) to Wave %s", order, drive, current_wave_edit))
end

-- Rebuild hex editor display (scrollable version for large samples)
function PCMWriterRebuildHexEditor()
  hex_buttons = {}
  local hex_columns = {}
  
  -- Calculate pagination
  local total_pages = math.ceil(wave_size / hex_samples_per_page)
  local current_page = math.min(hex_editor_page, total_pages - 1)
  local start_sample = current_page * hex_samples_per_page + 1
  local end_sample = math.min(start_sample + hex_samples_per_page - 1, wave_size)
  local samples_on_page = end_sample - start_sample + 1
  
  -- Navigation header
  local nav_row = vb:row{
    --spacing = 5,
    vb:text{
      text = string.format("Samples %d-%d of %d", start_sample, end_sample, wave_size),
      width = 180,
      font = "bold"
    },
    vb:button{
      text = "◀◀",
      width = 30,
      tooltip = "First Page",
      notifier = function()
        hex_editor_page = 0
        if pcm_dialog then pcm_dialog:close() end
        PCMWriterShowPcmDialog()
      end
    },
    vb:button{
      text = "◀",
      width = 30,
      tooltip = "Previous Page", 
      notifier = function()
        hex_editor_page = math.max(0, hex_editor_page - 1)
        if pcm_dialog then pcm_dialog:close() end
        PCMWriterShowPcmDialog()
      end
    },
    vb:text{
      text = string.format("Page %d/%d", current_page + 1, total_pages),
      width = 70
    },
    vb:button{
      text = "▶",
      width = 30,
      tooltip = "Next Page",
      notifier = function()
        hex_editor_page = math.min(total_pages - 1, hex_editor_page + 1)
        if pcm_dialog then pcm_dialog:close() end
        PCMWriterShowPcmDialog()
      end
    },
    vb:button{
      text = "▶▶",
      width = 30,
      tooltip = "Last Page",
      notifier = function()
        hex_editor_page = total_pages - 1
        if pcm_dialog then pcm_dialog:close() end
        PCMWriterShowPcmDialog()
      end
    }
  }
  table.insert(hex_columns, nav_row)
  
  -- Build hex grid for current page
  local rows = math.ceil(samples_on_page / hex_items_per_row)
  
  for row = 1, rows do
    local hex_row = vb:row{ spacing = 1 }
    
    local offset = (row - 1) * hex_items_per_row
    local absolute_offset = start_sample + offset - 1
    
    -- Address column with navigation arrows
    hex_row:add_child(vb:row{
      vb:text{
        text = string.format("%03X:", absolute_offset),
        width = 35,
        font = "mono"
      },
      vb:button{
        text = "↑",
        width = 15,
        height = 15,
        tooltip = "Increase all values in this row",
        notifier = function()
          local row_start = absolute_offset + 1
          local row_end = math.min(row_start + hex_items_per_row - 1, wave_size)
          local target_data = PCMWriterGetCurrentWaveData()
          for i = row_start, row_end do
            target_data[i] = math.min(65535, target_data[i] + 1000)
          end
          PCMWriterUpdateCrossfadedWave()
          waveform_canvas:update()
          PCMWriterUpdateHexDisplay()
        end
      },
      vb:button{
        text = "↓",
        width = 15,
        height = 15,
        tooltip = "Decrease all values in this row",
        notifier = function()
          local row_start = absolute_offset + 1
          local row_end = math.min(row_start + hex_items_per_row - 1, wave_size)
          local target_data = PCMWriterGetCurrentWaveData()
          for i = row_start, row_end do
            target_data[i] = math.max(0, target_data[i] - 1000)
          end
          PCMWriterUpdateCrossfadedWave()
          waveform_canvas:update()
          PCMWriterUpdateHexDisplay()
        end
      },
      vb:button{
        text = "←",
        width = 15,
        height = 15,
        tooltip = "Shift row values left (rotate)",
        notifier = function()
          local row_start = absolute_offset + 1
          local row_end = math.min(row_start + hex_items_per_row - 1, wave_size)
          local target_data = PCMWriterGetCurrentWaveData()
          if row_end > row_start then
            local temp = target_data[row_start]
            for i = row_start, row_end - 1 do
              target_data[i] = target_data[i + 1]
            end
            target_data[row_end] = temp
            PCMWriterUpdateCrossfadedWave()
            waveform_canvas:update()
            PCMWriterUpdateHexDisplay()
          end
        end
      },
      vb:button{
        text = "→",
        width = 15,
        height = 15,
        tooltip = "Shift row values right (rotate)",
        notifier = function()
          local row_start = absolute_offset + 1
          local row_end = math.min(row_start + hex_items_per_row - 1, wave_size)
          local target_data = PCMWriterGetCurrentWaveData()
          if row_end > row_start then
            local temp = target_data[row_end]
            for i = row_end, row_start + 1, -1 do
              target_data[i] = target_data[i - 1]
            end
            target_data[row_start] = temp
            PCMWriterUpdateCrossfadedWave()
            waveform_canvas:update()
            PCMWriterUpdateHexDisplay()
          end
        end
      }
    })
    
    -- Hex value columns
    for col = 1, hex_items_per_row do
      local absolute_idx = start_sample + offset + col - 1
      if absolute_idx <= end_sample then
        local target_data = PCMWriterGetCurrentWaveData()
        local hex_field = vb:textfield{
          text = string.format("%04X", target_data[absolute_idx]),
          width = hex_textfield_width,
          notifier = function(new_value) 
            PCMWriterEditHexSample(absolute_idx, new_value) 
          end
        }
        hex_buttons[absolute_idx] = hex_field
        hex_row:add_child(hex_field)
      end
    end
    
    table.insert(hex_columns, hex_row)
  end
  
  return hex_columns
end

function PCMWriterResetWaveEditor()
  dialog_initialized = false
  selection_start = -1
  selection_end = -1
  selected_sample_index = -1
  hex_editor_page = 0
  zoom_factor = 1.0
  pan_offset = 0
  selection_info_view = nil
end



function PCMWriterChangeWaveSize(new_size)
  local old_size = wave_size
  local old_data = wave_data
  local old_data_a = wave_data_a
  local old_data_b = wave_data_b
  wave_size = new_size
  wave_data = table.create()
  wave_data_a = table.create()
  wave_data_b = table.create()
  
  -- Interpolate existing data to fill new size for all three buffers
  for i = 1, wave_size do
    if old_size == 1 then
      -- Special case: if old size was 1, just repeat that value
      wave_data[i] = old_data[1] or 32768
      wave_data_a[i] = old_data_a[1] or 32768
      wave_data_b[i] = old_data_b[1] or 32768
    else
      -- Linear interpolation to stretch/compress existing data
      local old_pos = ((i - 1) / (wave_size - 1)) * (old_size - 1) + 1
      local old_idx = math.floor(old_pos)
      local frac = old_pos - old_idx
      
      if old_idx >= old_size then
        -- At or beyond the end
        wave_data[i] = old_data[old_size] or 32768
        wave_data_a[i] = old_data_a[old_size] or 32768
        wave_data_b[i] = old_data_b[old_size] or 32768
      elseif old_idx < 1 then
        -- Before the start
        wave_data[i] = old_data[1] or 32768
        wave_data_a[i] = old_data_a[1] or 32768
        wave_data_b[i] = old_data_b[1] or 32768
      else
        -- Interpolate between two points
        local val1 = old_data[old_idx] or 32768
        local val2 = old_data[old_idx + 1] or val1
        wave_data[i] = math.floor(val1 + frac * (val2 - val1))
        
        local val1_a = old_data_a[old_idx] or 32768
        local val2_a = old_data_a[old_idx + 1] or val1_a
        wave_data_a[i] = math.floor(val1_a + frac * (val2_a - val1_a))
        
        local val1_b = old_data_b[old_idx] or 32768
        local val2_b = old_data_b[old_idx + 1] or val1_b
        wave_data_b[i] = math.floor(val1_b + frac * (val2_b - val1_b))
      end
    end
  end
  
  selected_sample_index = -1
  
  -- Clear selection if it's outside new range
  if selection_start > wave_size or selection_end > wave_size then
    PCMWriterClearSelection()
  end
  
  PCMWriterZoomFit()
  
  -- Rebuild hex editor and update displays without closing dialog
  if pcm_dialog then
    pcm_dialog:close()
    PCMWriterShowPcmDialog()
  end
  
  renoise.app():show_status(string.format("Wave size changed to %d samples (interpolated)", wave_size))
end


-- Live Pickup Mode sample change notification
local function update_dialog_on_selection_change()
  if not live_pickup_mode or not pcm_dialog or not pcm_dialog.visible then
    return
  end
  
  local song = renoise.song()
  if not song.selected_instrument or not song.selected_sample then
    return
  end
  
  local new_sample = song.selected_sample
  local new_instrument = song.selected_instrument
  
  -- Check if we actually changed to a different sample (using indices instead of object comparison)
  local new_sample_index = song.selected_sample_index
  local new_instrument_index = song.selected_instrument_index
  
  if live_pickup_sample and live_pickup_instrument and 
     new_sample_index == live_pickup_sample_index and 
     new_instrument_index == live_pickup_instrument_index then
    return
  end
  
  -- Only auto-load if the sample has data
  if not new_sample.sample_buffer.has_sample_data then
    return
  end
  
  -- Enhanced logic for 12st_WT setup: switch wave edit mode instead of loading sample
  local is_12st_wt_setup = PCMWriterDetect12stWTSetup()
  
  if is_12st_wt_setup then
    -- In 12st_WT setup, sample slot selection should switch wave edit mode
    if new_sample_index == 1 and current_wave_edit ~= "A" then
      -- Switch to Wave A edit mode
      print("-- Live Pickup Mode (12st_WT): Switching to Wave A edit mode")
      current_wave_edit = "A"
      
      -- Update button colors if dialog is visible
      if pcm_dialog and pcm_dialog.visible then
        local edit_a_btn = vb.views.edit_a_btn
        local edit_b_btn = vb.views.edit_b_btn
        if edit_a_btn then edit_a_btn.color = COLOR_BUTTON_ACTIVE end
        if edit_b_btn then edit_b_btn.color = COLOR_BUTTON_INACTIVE end
      end
      
      -- Update canvas to show Wave A
      if waveform_canvas then
        waveform_canvas:update()
      end
      
      -- Update harmonic drawbars if in harmonic mode [[memory:6653553]]
      if harmonic_drawbar_mode and harmonic_canvas then
        print("-- Live Pickup Mode (12st_WT): Loading Wave A harmonic data into drawbars")
        local restored = PCMWriterRestoreHarmonicLevels()
        if restored then
          harmonic_canvas:update()
          print("-- Live Pickup Mode (12st_WT): Harmonic drawbars updated to show Wave A settings")
        else
          print("-- Live Pickup Mode (12st_WT): No harmonic data found for Wave A")
        end
      end
      
      renoise.app():show_status("Live Pickup: Switched to Wave A edit mode (sample slot 1)")
      
    elseif new_sample_index == 2 and current_wave_edit ~= "B" then
      -- Switch to Wave B edit mode
      print("-- Live Pickup Mode (12st_WT): Switching to Wave B edit mode")
      current_wave_edit = "B"
      
      -- Update button colors if dialog is visible
      if pcm_dialog and pcm_dialog.visible then
        local edit_a_btn = vb.views.edit_a_btn
        local edit_b_btn = vb.views.edit_b_btn
        if edit_a_btn then edit_a_btn.color = COLOR_BUTTON_INACTIVE end
        if edit_b_btn then edit_b_btn.color = COLOR_BUTTON_ACTIVE end
      end
      
      -- Update canvas to show Wave B
      if waveform_canvas then
        waveform_canvas:update()
      end
      
      -- Update harmonic drawbars if in harmonic mode [[memory:6653553]]
      if harmonic_drawbar_mode and harmonic_canvas then
        print("-- Live Pickup Mode (12st_WT): Loading Wave B harmonic data into drawbars")
        local restored = PCMWriterRestoreHarmonicLevels()
        if restored then
          harmonic_canvas:update()
          print("-- Live Pickup Mode (12st_WT): Harmonic drawbars updated to show Wave B settings")
        else
          print("-- Live Pickup Mode (12st_WT): No harmonic data found for Wave B")
        end
      end
      
      renoise.app():show_status("Live Pickup: Switched to Wave B edit mode (sample slot 2)")
      
    else
      -- Same sample slot as current wave edit mode, load the sample normally
      print("-- Live Pickup Mode (12st_WT): Loading sample into current wave: " .. new_sample.name)
      PCMWriterLoadSampleToWaveform()
    end
  else
    -- Non-12st_WT setup: load the new sample into the PCM Writer normally
    print("-- Live Pickup Mode: Auto-loading new sample: " .. new_sample.name)
    PCMWriterLoadSampleToWaveform()
  end
  
  -- Update tracking variables
  live_pickup_sample = new_sample
  live_pickup_instrument = new_instrument
  live_pickup_sample_index = new_sample_index
  live_pickup_instrument_index = new_instrument_index
  
  print("-- Live Pickup Mode: Successfully loaded " .. new_sample.name)
end

-- Helper function to clean up sample change notifier
local function cleanup_sample_notifier()
  local song = renoise.song()
  if song.selected_sample_observable:has_notifier(update_dialog_on_selection_change) then
    song.selected_sample_observable:remove_notifier(update_dialog_on_selection_change)
  end
end

-- Tool idle notifier to clean up sample notifier when dialog is closed by other means
function cleanup_on_dialog_close()
  if not pcm_dialog or not pcm_dialog.visible then
    cleanup_sample_notifier()
    if renoise.tool().app_idle_observable:has_notifier(cleanup_on_dialog_close) then
      renoise.tool().app_idle_observable:remove_notifier(cleanup_on_dialog_close)
    end
  end
end

function PCMWriterLoadSampleToWaveform()
  local song = renoise.song()
  local inst = song.selected_instrument
  local sample = song.selected_sample
  
  if not inst or not sample then
    renoise.app():show_status("No instrument or sample selected")
    return
  end
  
  if not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Selected sample has no data")
    return
  end
  
  local buffer = sample.sample_buffer
  local num_frames = buffer.number_of_frames
  local num_channels = buffer.number_of_channels
  
  -- If sample is longer than wave_size, we'll take the first wave_size samples
  local samples_to_load = math.min(num_frames, wave_size)
  
  print(string.format("-- PCM Writer: Loading %d frames from sample '%s' into current wave %s", 
    samples_to_load, sample.name, current_wave_edit))
  
  -- Get current wave data array
  local target_data = PCMWriterGetCurrentWaveData()
  
  -- Load sample data into current wave
  for i = 1, samples_to_load do
    -- Get sample value (use first channel for mono compatibility)
    local sample_value = buffer:sample_data(1, i)
    
    -- Convert from normalized float (-1.0 to 1.0) to 16-bit unsigned (0-65535)
    local converted_value = math.floor((sample_value + 1.0) * 32767.5)
    converted_value = math.max(0, math.min(65535, converted_value))
    
    target_data[i] = converted_value
  end
  
  -- Fill remaining slots with center value if sample was shorter than wave_size
  if samples_to_load < wave_size then
    for i = samples_to_load + 1, wave_size do
      target_data[i] = 32768  -- Center value (silence)
    end
  end
  
  -- Update displays
  PCMWriterUpdateCrossfadedWave()
  PCMWriterUpdateAllDisplays()
  
  local status_msg = string.format("Loaded %d frames from sample '%s' into Wave %s", 
    samples_to_load, sample.name, current_wave_edit)
  renoise.app():show_status(status_msg)
  print("-- PCM Writer: " .. status_msg)
end

function PCMWriterLoadCurrentSample()
  local song = renoise.song()
  local inst = song.selected_instrument
  local sample_idx = song.selected_sample_index
  
  -- Check if instrument has no samples or no sample is selected
  if #inst.samples == 0 or sample_idx < 1 or sample_idx > #inst.samples then
    print("DEBUG: No samples in instrument or no sample selected - creating new empty sample")
    
    -- Apply default paketti instrument if needed
    if #inst.samples == 0 and not inst.plugin_properties.plugin_loaded then
      print("DEBUG: Applying pakettiPreferencesDefaultInstrumentLoader")
      if pakettiPreferencesDefaultInstrumentLoader then
        pakettiPreferencesDefaultInstrumentLoader()
        inst = song.selected_instrument  -- Re-get instrument reference
        print("DEBUG: Applied default instrument loader")
      end
    end
    
    -- Create new empty sample slot
    local new_sample_slot = #inst.samples + 1
    inst:insert_sample_at(new_sample_slot)
    song.selected_sample_index = new_sample_slot
    
    local sample = inst:sample(new_sample_slot)
    local buffer = sample.sample_buffer
    
    -- Create empty sample data with current canvas size
    buffer:create_sample_data(44100, 16, 1, wave_size)
    buffer:prepare_sample_data_changes()
    
    -- Fill with silence (center value)
    for i = 1, wave_size do
      buffer:set_sample_data(1, i, 0.0)  -- Silence
    end
    buffer:finalize_sample_data_changes()
    
    -- Set sample properties
    sample.name = string.format("PCM Live Edit (%d frames)", wave_size)
    sample.loop_mode = sample_loop_mode
    sample.loop_start = 1
    sample.loop_end = wave_size
    
    -- Fill both waves with silence and setup crossfade system
    for i = 1, wave_size do
      wave_data_a[i] = 32768  -- Center value (silence)
      wave_data_b[i] = 32768  -- Center value (silence)
    end
    
    -- Set crossfade to show the currently selected wave
    if current_wave_edit == "A" then
      crossfade_amount = 0.0  -- 0% = Wave A
    else
      crossfade_amount = 1.0  -- 100% = Wave B
    end
    
    PCMWriterUpdateCrossfadedWave()
    
    -- Update UI crossfade slider if dialog is open
    if pcm_dialog and pcm_dialog.visible then
      local crossfade_slider = vb.views.crossfade_slider
      local crossfade_display = vb.views.crossfade_value
      if crossfade_slider then crossfade_slider.value = crossfade_amount end
      if crossfade_display then crossfade_display.text = string.format("%.1f%%", crossfade_amount * 100) end
    end
    
          -- Remove placeholder samples if they exist (after default instrument loading)
      if #inst.samples > 1 then  -- Only if we have multiple samples
        PCMWriterRemovePlaceholderSamples(inst, new_sample_slot)
        -- Re-get sample reference after potential placeholder removal 
        sample = inst:sample(song.selected_sample_index)
      end
    
    -- AUTO-PITCH DETECTION FOR NEWLY CREATED SAMPLE
    -- Apply automatic pitch correction for standard single-cycle lengths
    local standard_cycle_lengths = {32, 64, 128, 256, 512, 1024}
    local is_standard_length = false
    for _, length in ipairs(standard_cycle_lengths) do
      if wave_size == length then
        is_standard_length = true
        break
      end
    end
    
    if is_standard_length then
      -- Calculate pitch correction for the newly created sample
      local pitch_correction = calculate_pitch_correction(44100, wave_size, 1)
      
      -- Apply pitch correction (no need to check if already tuned since this is a new sample)
      sample.transpose = pitch_correction.transpose
      sample.fine_tune = pitch_correction.fine_tune
      
      print(string.format("Live Pickup Auto-Pitch (New Sample): %s (%.1f Hz) -> transpose: %d, fine_tune: %d", 
        pitch_correction.note_name, pitch_correction.frequency, 
        pitch_correction.transpose, pitch_correction.fine_tune))
      
      -- Update sample name to reflect auto-tuning
      local tuning_info = string.format(" [Auto: %s T:%d F:%d]", 
        pitch_correction.note_name, pitch_correction.transpose, pitch_correction.fine_tune)
      
      sample.name = sample.name .. tuning_info
    end
    
    -- Enable live pickup mode
    live_pickup_mode = true
    live_pickup_sample = sample
    live_pickup_instrument = inst
    live_pickup_sample_index = song.selected_sample_index
    live_pickup_instrument_index = song.selected_instrument_index
    
    -- Reset editor state
    selected_sample_index = -1
    selection_start = -1
    selection_end = -1
    PCMWriterZoomFit()
    
    -- Update displays
    if waveform_canvas then
      waveform_canvas:update()
    end
    PCMWriterUpdateHexDisplay()
    
    -- Create appropriate status message based on whether pitch correction was applied
    local status_msg
    if is_standard_length then
      local pitch_correction = calculate_pitch_correction(44100, wave_size, 1)
      status_msg = "Live Pickup Mode: Created new " .. wave_size .. " frame sample, auto-tuned to " .. pitch_correction.note_name .. " (Wave " .. current_wave_edit .. "). Start drawing!"
    else
      status_msg = "Live Pickup Mode: No samples found, created new " .. wave_size .. " frame sample for live editing (Wave " .. current_wave_edit .. "). Start drawing!"
    end
    
    renoise.app():show_status(status_msg)
    
    -- Focus back to sample editor
  --  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
    return
  end
  
  local sample = inst:sample(sample_idx)
  local buffer = sample.sample_buffer
  
  if not buffer.has_sample_data then
    renoise.app():show_status("Selected sample has no data")
    return
  end
  
  local num_frames = buffer.number_of_frames
  if num_frames > 1024 then
    renoise.app():show_status("Sample too large (max 1024 frames). Selected sample has " .. num_frames .. " frames.")
    return
  end
  
  -- Check if sample size matches our editor sizes
  local valid_sizes = {16, 32, 64, 128, 256, 512, 1024}
  local size_match = false
  for _, size in ipairs(valid_sizes) do
    if num_frames == size then
      size_match = true
      break
    end
  end
  
  if not size_match then
          renoise.app():show_status("Sample size " .. num_frames .. " not supported. Use: 16, 32, 64, 128, 256, 512, or 1024 frames.")
    return
  end
  
  -- Check if wave size needs to change
  local old_wave_size = wave_size
  local wave_size_changed = (num_frames ~= wave_size)
  
  -- Set wave size to match sample
  wave_size = num_frames
  wave_data = table.create()
  
  -- Initialize all wave buffers to new size
  wave_data_a = table.create()
  wave_data_b = table.create()
  for i = 1, wave_size do 
    wave_data_a[i] = 32768 
    wave_data_b[i] = 32768 
  end
  
  -- Enhanced loading for 12st_WT setup vs standard loading
  local is_12st_wt_setup = PCMWriterDetect12stWTSetup()
  
  if is_12st_wt_setup then
    -- Enhanced Live Pickup: Load both samples into both wave arrays
    local sample1 = inst:sample(1)
    local sample2 = inst:sample(2)
    local buffer1 = sample1.sample_buffer
    local buffer2 = sample2.sample_buffer
    
    -- Check if both samples have data and match wave size
    if buffer1.has_sample_data and buffer2.has_sample_data and 
       buffer1.number_of_frames == wave_size and buffer2.number_of_frames == wave_size then
      
      -- Load sample 1 data into Wave A
      for i = 1, wave_size do
        local sample_value = buffer1:sample_data(1, i)
        local converted_value = math.floor((sample_value + 1) * 32767.5)
        converted_value = math.max(0, math.min(65535, converted_value))
        wave_data_a[i] = converted_value
      end
      
      -- Load sample 2 data into Wave B
      for i = 1, wave_size do
        local sample_value = buffer2:sample_data(1, i)
        local converted_value = math.floor((sample_value + 1) * 32767.5)
        converted_value = math.max(0, math.min(65535, converted_value))
        wave_data_b[i] = converted_value
      end
      
      renoise.app():show_status("Enhanced Live Pickup: Loaded sample slot 1 → Wave A, sample slot 2 → Wave B for bidirectional sync")
      
    else
      -- Fallback: Load current sample into current wave only (preserves the other wave)
      for i = 1, num_frames do
        local sample_value = buffer:sample_data(1, i)
        local converted_value = math.floor((sample_value + 1) * 32767.5)
        converted_value = math.max(0, math.min(65535, converted_value))
        
        if current_wave_edit == "A" then
          wave_data_a[i] = converted_value
          -- Leave wave_data_b unchanged to preserve existing data
        else
          wave_data_b[i] = converted_value
          -- Leave wave_data_a unchanged to preserve existing data
        end
      end
      renoise.app():show_status("Enhanced Live Pickup: 12st_WT detected but samples don't match - loaded into Wave " .. current_wave_edit)
    end
    
  else
    -- Standard loading behavior: For single-sample instruments, load into both waves
    -- For multi-sample instruments, only load into current wave to preserve other data
    local load_into_both = (#inst.samples == 1)
    
    for i = 1, num_frames do
      local sample_value = buffer:sample_data(1, i)  -- Assuming mono
      -- Convert from -1..1 to 0..65535
      local converted_value = math.floor((sample_value + 1) * 32767.5)
      converted_value = math.max(0, math.min(65535, converted_value))
      
      if load_into_both then
        -- Single sample: Load into both waves to support Wave A&B export
        wave_data_a[i] = converted_value
        wave_data_b[i] = converted_value
      else
        -- Multi-sample: Only load into current wave to preserve other sample data
        if current_wave_edit == "A" then
          wave_data_a[i] = converted_value
          -- Leave wave_data_b unchanged to preserve existing data
        else
          wave_data_b[i] = converted_value
          -- Leave wave_data_a unchanged to preserve existing data
        end
      end
    end
  end
  
  -- Set crossfade to show the current wave
  if current_wave_edit == "A" then
    crossfade_amount = 0.0  -- 0% = Wave A
  else
    crossfade_amount = 1.0  -- 100% = Wave B
  end
  
  -- Update crossfaded wave (will show the loaded sample in purple)
  PCMWriterUpdateCrossfadedWave()
  
  -- Update UI crossfade slider if dialog is open
  if pcm_dialog and pcm_dialog.visible then
    local crossfade_slider = vb.views.crossfade_slider
    local crossfade_display = vb.views.crossfade_value
    if crossfade_slider then crossfade_slider.value = crossfade_amount end
    if crossfade_display then crossfade_display.text = string.format("%.1f%%", crossfade_amount * 100) end
  end
  
  -- AUTO-PITCH DETECTION FOR LIVE PICKUP MODE
  -- Check if sample is a standard single-cycle length and apply pitch correction if not already tuned
  local standard_cycle_lengths = {32, 64, 128, 256, 512, 1024}
  local is_standard_length = false
  for _, length in ipairs(standard_cycle_lengths) do
    if num_frames == length then
      is_standard_length = true
      break
    end
  end
  
  -- Apply automatic pitch detection if it's a standard length and not already properly tuned
  if is_standard_length then
    -- Check if sample is not already tuned (transpose=0 and fine_tune close to 0)
    local needs_tuning = (sample.transpose == 0 and math.abs(sample.fine_tune) < 10)
    
    if needs_tuning then
      -- Calculate pitch correction using existing algorithm
      local pitch_correction = calculate_pitch_correction(buffer.sample_rate, num_frames, 1)
      
      -- Only apply correction if deviation is significant (>2 cents)
      local cents_deviation = math.abs(pitch_correction.cents)
      if cents_deviation > 2 then
        sample.transpose = pitch_correction.transpose
        sample.fine_tune = pitch_correction.fine_tune
        
        print(string.format("Live Pickup Auto-Pitch: %s (%.1f Hz) -> transpose: %d, fine_tune: %d (%.1f cents %s)", 
          pitch_correction.note_name, pitch_correction.frequency, 
          pitch_correction.transpose, pitch_correction.fine_tune,
          cents_deviation, pitch_correction.cent_direction))
        
        -- Update sample name to reflect auto-tuning
        local tuning_info = string.format(" [Auto: %s T:%d F:%d]", 
          pitch_correction.note_name, pitch_correction.transpose, pitch_correction.fine_tune)
        
        if not string.find(sample.name, "Auto:") then
          sample.name = sample.name .. tuning_info
        end
        
        local status_suffix = (#inst.samples == 1) and " (loaded into both Wave A & B)" or " (Wave " .. current_wave_edit .. ")"
        renoise.app():show_status("Live Pickup Mode: Loaded " .. num_frames .. " frame sample, auto-tuned to " .. pitch_correction.note_name .. status_suffix)
      else
        print(string.format("Live Pickup: Sample already well-tuned: %s (%.1f Hz, %.1f cents %s)", 
          pitch_correction.note_name, pitch_correction.frequency,
          cents_deviation, pitch_correction.cent_direction))
        
        local status_suffix = (#inst.samples == 1) and " (loaded into both Wave A & B)" or " (Wave " .. current_wave_edit .. ")"
        renoise.app():show_status("Live Pickup Mode: Loaded " .. num_frames .. " frame sample for live editing" .. status_suffix .. " - already well-tuned")
      end
    else
      local status_suffix = (#inst.samples == 1) and " (loaded into both Wave A & B)" or " (Wave " .. current_wave_edit .. ")"
      renoise.app():show_status("Live Pickup Mode: Loaded " .. num_frames .. " frame sample for live editing" .. status_suffix .. " - already tuned")
    end
  else
    local status_suffix = (#inst.samples == 1) and " (loaded into both Wave A & B)" or " (Wave " .. current_wave_edit .. ")"
    renoise.app():show_status("Live Pickup Mode: Loaded " .. num_frames .. " frame sample for live editing" .. status_suffix)
  end

  -- Enable live pickup mode
  live_pickup_mode = true
  live_pickup_sample = sample
  live_pickup_instrument = inst
  live_pickup_sample_index = song.selected_sample_index
  live_pickup_instrument_index = song.selected_instrument_index
  
  -- Reset editor state
  selected_sample_index = -1
  selection_start = -1
  selection_end = -1
  PCMWriterZoomFit()
  
  -- Update displays
  if waveform_canvas then
    waveform_canvas:update()
  end
  PCMWriterUpdateHexDisplay()
  
  -- Only rebuild dialog if wave size actually changed
  if wave_size_changed and pcm_dialog then
    pcm_dialog:close()
    PCMWriterShowPcmDialog()
  end
  
  local final_status_suffix = (#inst.samples == 1) and " (loaded into both Wave A & B)" or " (Wave " .. current_wave_edit .. ")"
  renoise.app():show_status("Live Pickup Mode: Loaded " .. num_frames .. " frame sample for live editing" .. final_status_suffix)
  
  -- Focus back to sample editor
  --   renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Function to detect if we're in 12st_WT.xrni setup with dual sample chains
function PCMWriterDetect12stWTSetup()
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- Check if we have at least 2 samples
  if #inst.samples < 2 then
    return false
  end
  
  -- Check if we have at least 2 sample device chains
  if #inst.sample_device_chains < 2 then
    return false
  end
  
  -- Check if sample 1 is assigned to chain 1 and sample 2 is assigned to chain 2
  local sample1 = inst:sample(1)
  local sample2 = inst:sample(2)
  
  if sample1.device_chain_index ~= 1 or sample2.device_chain_index ~= 2 then
    return false
  end
  
  -- Optional: Check if the chains have the expected devices (LFO, Gainer, Send)
  local chain1 = inst.sample_device_chains[1]
  local chain2 = inst.sample_device_chains[2]
  
  -- Basic check: each chain should have at least 3+ devices (including the sample mixer at index 1)
  if #chain1.devices < 4 or #chain2.devices < 4 then
    return false
  end
  
  -- Check if we have LFO, Gainer, Send in expected positions
  local has_lfo1 = chain1.devices[2] and chain1.devices[2].name == "*LFO"
  local has_gainer1 = chain1.devices[3] and chain1.devices[3].name == "Gainer"
  local has_send1 = chain1.devices[4] and chain1.devices[4].name == "#Send"
  
  local has_lfo2 = chain2.devices[2] and chain2.devices[2].name == "*LFO"
  local has_gainer2 = chain2.devices[3] and chain2.devices[3].name == "Gainer"
  local has_send2 = chain2.devices[4] and chain2.devices[4].name == "#Send"
  
  local result = has_lfo1 and has_gainer1 and has_send1 and has_lfo2 and has_gainer2 and has_send2
  
  return result
end

-- Function to find the "Wavetable Mod *LFO" track device
function PCMWriterFindWavetableLFODevice()
  local song = renoise.song()
  local track = song.selected_track
  
  print("DEBUG: Looking for 'Wavetable Mod *LFO' device on track " .. track.name)
  for i, device in ipairs(track.devices) do
    print("DEBUG: Found device " .. i .. ": " .. device.display_name)
    if device.display_name == "Wavetable Mod *LFO" then
      print("DEBUG: Found Wavetable Mod *LFO device!")
      return device
    end
  end
  
  print("DEBUG: Wavetable Mod *LFO device NOT found")
  return nil
end

-- Function to check if we should show enhanced LFO controls
function PCMWriterShouldShowLFOControls()
  local has_setup = PCMWriterDetect12stWTSetup()
  local has_lfo_device = PCMWriterFindWavetableLFODevice() ~= nil
  
  print("DEBUG: has_setup = " .. tostring(has_setup) .. ", has_lfo_device = " .. tostring(has_lfo_device))
  
  return has_setup and has_lfo_device
end

-- Function to initialize LFO controls with current device values
function PCMWriterInitializeLFOControls()
  print("DEBUG: PCMWriterInitializeLFOControls() called")
  if not PCMWriterShouldShowLFOControls() or not pcm_dialog or not pcm_dialog.visible then
    print("DEBUG: Exiting PCMWriterInitializeLFOControls early - conditions not met")
    print("DEBUG: PCMWriterShouldShowLFOControls() = " .. tostring(PCMWriterShouldShowLFOControls()))
    print("DEBUG: pcm_dialog exists = " .. tostring(pcm_dialog ~= nil))
    print("DEBUG: pcm_dialog.visible = " .. tostring(pcm_dialog and pcm_dialog.visible))
    return
  end
  print("DEBUG: Proceeding with LFO controls initialization")
  
  local lfo_device = PCMWriterFindWavetableLFODevice()
  if not lfo_device then
    return
  end
  
  -- Read current LFO parameter values and clamp to slider ranges
  local amplitude = math.max(0.0, math.min(1.0, lfo_device.parameters[4].value))  -- Amplitude (0.0-1.0)
  local offset = math.max(-0.5, math.min(0.5, lfo_device.parameters[5].value))     -- Offset (-0.5-0.5)  
  local frequency = math.max(0.000001, math.min(60, lfo_device.parameters[6].value))  -- Frequency (0.000001-60)
  
  -- Update UI sliders and labels with current values
  if pcm_dialog and pcm_dialog.visible then
    -- Make LFO controls row visible
    local lfo_row = vb.views.lfo_controls_row
    if lfo_row then 
      print("DEBUG: Setting LFO controls row visible = true")
      lfo_row.visible = true
      print("DEBUG: LFO controls row visible is now: " .. tostring(lfo_row.visible))
    else
      print("DEBUG: ERROR - lfo_controls_row view not found!")
      print("DEBUG: Available views in vb.views:")
      for key, view in pairs(vb.views) do
        if key:find("lfo") then
          print("DEBUG:   " .. key .. " = " .. tostring(view))
        end
      end
      print("DEBUG: Attempting workaround - trying to find any LFO row...")
      -- Try alternative approaches to make LFO controls visible
      if vb.views.lfo_amplitude_slider then
        print("DEBUG: Found individual LFO sliders, setting their parent visible")
        local parent = vb.views.lfo_amplitude_slider.parent
        if parent then
          parent.visible = true
          print("DEBUG: Set parent of LFO sliders visible = true")
        end
      end
    end
    
    local amp_slider = vb.views.lfo_amplitude_slider
    local amp_label = vb.views.lfo_amplitude_label
    local offset_slider = vb.views.lfo_offset_slider
    local offset_label = vb.views.lfo_offset_label
    local freq_slider = vb.views.lfo_frequency_slider
    local freq_label = vb.views.lfo_frequency_label
    
    if amp_slider then amp_slider.value = amplitude end
    if amp_label then amp_label.text = string.format("%.2f", amplitude) end
    if offset_slider then offset_slider.value = offset end
    if offset_label then offset_label.text = string.format("%.2f", offset) end
    if freq_slider then freq_slider.value = frequency end
                  if freq_label then 
                -- Convert device value to LPC display (60 = 1 LPC), handle INF case
                local lpc_value = 60 / frequency  -- Inverted: lower freq = higher LPC
                local display_text = (frequency <= 0.000001) and "INF" or string.format("%.2fLPC", lpc_value)
                freq_label.text = display_text
              end
    
    print(string.format("LFO Controls Initialized: Amp=%.2f, Offset=%.2f, Freq=%.2f", amplitude, offset, frequency))
  end
end

-- Function to enter Live Pickup Mode and setup LFO controls for 12st_WT
function PCMWriterEnterLivePickupMode()
  print("DEBUG: *** ENTERING LIVE PICKUP MODE ***")
  local song = renoise.song()
  local inst = song.selected_instrument
  local sample = song.selected_sample
  
  if not sample then
    print("DEBUG: No sample selected, aborting Live Pickup Mode")
    renoise.app():show_status("No sample selected for Live Pickup Mode")
    return
  end
  
  print("DEBUG: Live Pickup Mode - sample and instrument found")
  
  -- Enable live pickup mode
  live_pickup_mode = true
  live_pickup_sample = sample
  live_pickup_instrument = inst
  live_pickup_sample_index = song.selected_sample_index
  live_pickup_instrument_index = song.selected_instrument_index
  
  -- Load current sample data for dual-sample setup if detected
  PCMWriterLoadCurrentSample()
  
  -- If 12st_WT setup is detected, initialize and show LFO controls
  print("DEBUG: Checking if should show LFO controls...")
  if PCMWriterShouldShowLFOControls() then
    print("DEBUG: YES - Calling PCMWriterInitializeLFOControls()")
    PCMWriterInitializeLFOControls()
  else
    print("DEBUG: NO - Not showing LFO controls")
  end
  
  -- Update displays
  PCMWriterUpdateAllDisplays()
  
  -- Check if harmonics are already active and update instrument name accordingly
  if harmonic_drawbar_mode then
    local active_harmonics = {}
    for harmonic = 1, 11 do
      if harmonic_levels[harmonic] > 0.0 then
        table.insert(active_harmonics, string.format("H%d=%.2f", harmonic, harmonic_levels[harmonic]))
      end
    end
    
    if #active_harmonics > 0 then
      inst.name = string.format("%s (%d frames)", table.concat(active_harmonics, ","), wave_size)
      sample.name = string.format("%s (%d frames)", table.concat(active_harmonics, ","), wave_size)
      print("HARMONIC: Updated instrument name on Live Pickup Mode entry: " .. inst.name)
    end
  end
  
  renoise.app():show_status("Live Pickup Mode enabled - waveform updates will sync to sample")
end

function PCMWriterUpdateLiveSample()
  if not live_pickup_mode or not live_pickup_sample then
    return
  end
  
  -- Check if we're in 12st_WT setup for enhanced live pickup
  local is_12st_wt_setup = PCMWriterDetect12stWTSetup()
  
  -- Protected call to handle any sample access errors gracefully
  local success, error_msg = pcall(function()
    if is_12st_wt_setup then
      -- Enhanced live pickup for 12st_WT setup
      local song = renoise.song()
      local inst = song.selected_instrument
      
      -- Determine which sample to update based on current wave edit mode
      local target_sample_index = (current_wave_edit == "A") and 1 or 2
      local target_sample = inst:sample(target_sample_index)
      local target_wave_data = (current_wave_edit == "A") and wave_data_a or wave_data_b
      
      -- Additional safety check
      if not target_sample.sample_buffer or not target_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("Live Pickup Mode: Target sample buffer not available")
        return
      end
      
      local buffer = target_sample.sample_buffer
      
      -- Check if buffer size matches
      if buffer.number_of_frames ~= wave_size then
        renoise.app():show_status("Live Pickup Mode: Sample size mismatch for Wave " .. current_wave_edit)
        return
      end
      
      -- Update the appropriate sample with the current wave data
      buffer:prepare_sample_data_changes()
      for i = 1, wave_size do
        -- Convert from 0..65535 to -1..1
        local normalized_value = (target_wave_data[i] - 32768) / 32768
        normalized_value = math.max(-1, math.min(1, normalized_value))
        buffer:set_sample_data(1, i, normalized_value)
      end
      buffer:finalize_sample_data_changes()
      
      renoise.app():show_status("Live Pickup: Updated Wave " .. current_wave_edit .. " in sample slot " .. target_sample_index)
      
    else
      -- Original live pickup behavior for non-12st_WT setups
      -- Additional safety check - ensure the sample object is still valid
      if not live_pickup_sample.sample_buffer or not live_pickup_sample.sample_buffer.has_sample_data then
        live_pickup_mode = false
        live_pickup_sample = nil
        live_pickup_instrument = nil
        return
      end
      
      local buffer = live_pickup_sample.sample_buffer
      
      -- Check if buffer size still matches
      if buffer.number_of_frames ~= wave_size then
        live_pickup_mode = false
        live_pickup_sample = nil
        live_pickup_instrument = nil
        renoise.app():show_status("Live Pickup Mode disabled: Sample size changed")
        return
      end
      
      -- Update the sample buffer with crossfaded result (purple line)
      -- Note: wave_data contains the crossfaded result from Wave A and Wave B
      buffer:prepare_sample_data_changes()
      for i = 1, wave_size do
        -- Convert crossfaded result from 0..65535 to -1..1
        local normalized_value = (wave_data[i] / 32767.5) - 1
        normalized_value = math.max(-1, math.min(1, normalized_value))
        buffer:set_sample_data(1, i, normalized_value)
      end
      buffer:finalize_sample_data_changes()
    end
  end)
  
  if not success then
    -- Handle any errors by disabling live pickup mode
    live_pickup_mode = false
    live_pickup_sample = nil
    live_pickup_instrument = nil
    print("Live Pickup Mode disabled due to error: " .. tostring(error_msg))
  end
end

-- Main dialog function
function PCMWriterShowPcmDialog()
  -- If dialog is already open, close it (toggle behavior)
  if pcm_dialog and pcm_dialog.visible then
    cleanup_sample_notifier()
    pcm_dialog:close()
    pcm_dialog = nil
    return
  end
  
  -- Initialize AKWF dropdown data
  PCMWriterInitializeAKWFDropdown()
  
  -- Load hex editor visibility preference
  if preferences and preferences.singlewaveformwriterhex then
    hide_hex_editor = not preferences.singlewaveformwriterhex.value
  end
  
  -- Set flag to prevent dropdown from triggering during rebuild
  dialog_rebuilding = true
  
  -- Create fresh ViewBuilder instance to avoid ID conflicts
  vb = renoise.ViewBuilder()  -- Make it global so LFO controls can access it
  
  waveform_canvas = vb:canvas{
    width = wavetable_canvas_width,
    height = 200,
    mode = "plain",
    render = PCMWriterRenderWaveform,
    mouse_handler = PCMWriterHandleMouse,
    mouse_events = {"down", "up", "move", "exit"}
  }

  -- Only generate initial waveform on first dialog opening
  if not dialog_initialized then
    current_waveform_type = "sine"  -- Ensure current_waveform_type is set
    PCMWriterGenerateWaveform("sine")
    dialog_initialized = true
  end
  
  local hex_editor_rows = PCMWriterRebuildHexEditor()
  local hex_editor_content = vb:column{ spacing = 2 }
  for _, row in ipairs(hex_editor_rows) do
    hex_editor_content:add_child(row)
  end

  -- Create selection info view
  selection_info_view = vb:text{
    text = PCMWriterGetSelectionInfo(),
    width = 200,
    height = 20
  }
  
  -- Create wavetable count text element
  wavetable_count_text = vb:text{
    text = string.format("Wavetable Tools (%d/12)", #wavetable_waves),
    width = 180,
    style = "strong",
    font = "bold"
  }
  
  -- Create cursor width slider
  cursor_step_slider = vb:slider{
    min = 1,
    max = 50,
    value = cursor_width,
    width = 100,
    notifier = function(value)
      cursor_width = math.floor(value)
      if cursor_step_text then
        cursor_step_text.text = string.format("%d", cursor_width)
      end
      hex_field_has_focus = false  -- Set focus to canvas when adjusting cursor width
    end
  }
  
  -- Create cursor width text display
  cursor_step_text = vb:text{
    text = string.format("%d", cursor_width),
    width = 50
  }
  
  local dialog_content = vb:column{ -- DIALOG_CONTENT STARTS
    margin = 10,
    --spacing = 10,
        
        -- Main controls row 1: Waveform selection
  vb:row{ -- WAVEFORM_ROW STARTS
    vb:text{ text = "Waveform", style = "strong" },
    vb:button{
      text = "<",
      width = 20,
      tooltip = "Previous waveform",
      notifier = function()
        local popup = vb.views.waveform_popup
        if popup then
          local new_value = popup.value - 1
          if new_value < 1 then
            new_value = #popup.items
          end
          popup.value = new_value
          -- Manually trigger waveform generation
          local types = {"sine", "square", "saw", "saw_reverse", "triangle", "pulse_25", "pulse_10", 
                         "double_sine", "half_sine", "abs_sine", "exp_curve", "log_curve", 
                         "stepped", "ziggurat", "trapezoid", "chirp", "morph", "harmonic_5th", "harmonic_3rd", 
                         "organ", "metallic", "vocal", "digital", "wobble",
                         "doubletriangle", "asym_diamond", "exp_diamond", "log_diamond", "fractal_diamond", 
                         "bezier_diamond", "harmonic_diamond", "pentagon", "hexagon", "crystal", "zigzag", "staircase", 
                         "recursive_triangle", "star_5", "star_8", "spiral", "heart", "butterfly",
                         "morph_sine", "morph_triangle", "morph_pulse", "morph_saw", "morph_diode", "morph_gauss", 
                         "morph_chebyshev", "morph_chirp", "noise", "pink_noise", "morph_white_noise", "morph_pink_noise", "morph_brown_noise"}
          current_waveform_type = types[new_value]
          PCMWriterGenerateWaveform(current_waveform_type, nil, wave_size)
          selected_sample_index = -1
          selection_start = -1
          selection_end = -1
          if waveform_canvas then
            waveform_canvas:update()
          end
          PCMWriterUpdateHexDisplay()
          PCMWriterUpdateLiveSample()  -- Live update sample when generating waveform
        end
      end
    },

    vb:popup{
      items = {"sine", "square", "saw", "saw_reverse", "triangle", "pulse_25", "pulse_10", 
               "double_sine", "half_sine", "abs_sine", "exp_curve", "log_curve", 
               "stepped", "ziggurat", "trapezoid", "chirp", "morph", "harmonic_5th", "harmonic_3rd", 
               "organ", "metallic", "vocal", "digital", "wobble",
               "doubletriangle", "asym_diamond", "exp_diamond", "log_diamond", "fractal_diamond", 
               "bezier_diamond", "harmonic_diamond", "pentagon", "hexagon", "crystal", "zigzag", "staircase", 
               "recursive_triangle", "star_5", "star_8", "spiral", "heart", "butterfly",
               "morph_sine", "morph_triangle", "morph_pulse", "morph_saw", "morph_diode", "morph_gauss", 
               "morph_chebyshev", "morph_chirp", "noise", "pink_noise", "morph_white_noise", "morph_pink_noise", "morph_brown_noise"},
      value = 1,
      width=150,
      id = "waveform_popup",
      notifier = function(idx)
        -- Don't generate waveform if dialog is being rebuilt
        if dialog_rebuilding then
          return
        end
        local types = {"sine", "square", "saw", "saw_reverse", "triangle", "pulse_25", "pulse_10", 
                       "double_sine", "half_sine", "abs_sine", "exp_curve", "log_curve", 
                       "stepped", "ziggurat", "trapezoid", "chirp", "morph", "harmonic_5th", "harmonic_3rd", 
                       "organ", "metallic", "vocal", "digital", "wobble",
                       "doubletriangle", "asym_diamond", "exp_diamond", "log_diamond", "fractal_diamond", 
                       "bezier_diamond", "harmonic_diamond", "pentagon", "hexagon", "crystal", "zigzag", "staircase", 
                       "recursive_triangle", "star_5", "star_8", "spiral", "heart", "butterfly",
                       "morph_sine", "morph_triangle", "morph_pulse", "morph_saw", "morph_diode", "morph_gauss", 
                       "morph_chebyshev", "morph_chirp", "noise", "pink_noise", "morph_white_noise", "morph_pink_noise", "morph_brown_noise"}
        current_waveform_type = types[idx]  -- Track current waveform type
        PCMWriterGenerateWaveform(current_waveform_type, nil, wave_size)
        selected_sample_index = -1
        selection_start = -1
        selection_end = -1
        if waveform_canvas then
          waveform_canvas:update()
        end
        PCMWriterUpdateHexDisplay()
        PCMWriterUpdateLiveSample()  -- Live update sample when generating waveform
      end
    },
    vb:button{
      text = ">",
      width = 20,
      tooltip = "Next waveform",
      notifier = function()
        local popup = vb.views.waveform_popup
        if popup then
          local new_value = popup.value + 1
          if new_value > #popup.items then
            new_value = 1
          end
          popup.value = new_value
          -- Manually trigger waveform generation
          local types = {"sine", "square", "saw", "saw_reverse", "triangle", "pulse_25", "pulse_10", 
                         "double_sine", "half_sine", "abs_sine", "exp_curve", "log_curve", 
                         "stepped", "ziggurat", "trapezoid", "chirp", "morph", "harmonic_5th", "harmonic_3rd", 
                         "organ", "metallic", "vocal", "digital", "wobble",
                         "doubletriangle", "asym_diamond", "exp_diamond", "log_diamond", "fractal_diamond", 
                         "bezier_diamond", "harmonic_diamond", "pentagon", "hexagon", "crystal", "zigzag", "staircase", 
                         "recursive_triangle", "star_5", "star_8", "spiral", "heart", "butterfly",
                         "morph_sine", "morph_triangle", "morph_pulse", "morph_saw", "morph_diode", "morph_gauss", 
                         "morph_chebyshev", "morph_chirp", "noise", "pink_noise", "morph_white_noise", "morph_pink_noise", "morph_brown_noise"}
          current_waveform_type = types[new_value]
          PCMWriterGenerateWaveform(current_waveform_type, nil, wave_size)
          selected_sample_index = -1
          selection_start = -1
          selection_end = -1
          if waveform_canvas then
            waveform_canvas:update()
          end
          PCMWriterUpdateHexDisplay()
          PCMWriterUpdateLiveSample()  -- Live update sample when generating waveform
        end
      end
    },
    vb:button{
      text = "Random",
      width = 60,
      tooltip = "Generate random complex waveform with FM, ring mod, harmonics, etc.",
      notifier = PCMWriterGenerateRandomWaveform
    },
    vb:button{
      text = "Geometric",
      width = 70,
      tooltip = "Cycle through geometric shapes",
      notifier = PCMWriterCycleGeometricShape
    },
    vb:text{ text = "AKWF A:", style = "strong" },
    vb:popup{
      id = "akwf_a_popup",
      items = akwf_dropdown_filenames,
      value = 1,
      width = 150,
      tooltip = "Select AKWF for Wave A",
      notifier = function(idx)
        PCMWriterLoadAKWFFromDropdown(idx, "A")
      end
    },
    vb:text{ text = "AKWF B:", style = "strong" },
    vb:popup{
      id = "akwf_b_popup",
      items = akwf_dropdown_filenames,
      value = 1,
      width = 150,
      tooltip = "Select AKWF for Wave B",
      notifier = function(idx)
        PCMWriterLoadAKWFFromDropdown(idx, "B")
      end
    }
  }, -- WAVEFORM_ROW ENDS

  -- Main controls row 2: Sample settings
  vb:row{ -- SAMPLE_SETTINGS_ROW STARTS
    vb:text{ text = "Samples", style = "strong" },
    vb:popup{
      width=55,
        items = {"16", "32", "64", "128", "256", "512", "1024"},
              value = (function()
        -- Find the current wave_size in the options and return its index
        for i, size in ipairs(wave_size_options) do
          if size == wave_size then
            return i
          end
        end
        return 6 -- Default to 512 if not found (now at index 6)
      end)(),
      notifier = function(idx)
          PCMWriterChangeWaveSize(wave_size_options[idx])
        end
      },
      vb:text{ text = "Sample Interpolation", style = "strong" },
      vb:popup{
        items = {"None", "Linear", "Cubic", "Sinc"},
        value = 4,
        width=66,
        notifier = function(idx)
          local modes = {"none", "linear", "cubic", "sinc"}
          sample_interpolation_mode = modes[idx]
        end
      },
      vb:checkbox{
        value = sample_oversample_enabled,
        notifier = function(value)
          sample_oversample_enabled = value
        end
      },
      vb:text{ text = "Oversampling", style = "strong" },
      vb:switch{
        id = "loop_mode_switch",
        items = {"Forward", "PingPong"},
        width = 200,
        value = (sample_loop_mode == renoise.Sample.LOOP_MODE_PING_PONG) and 2 or 1,
        tooltip = "Loop mode for newly created/updated samples",
        notifier = function(idx)
          local new_mode = (idx == 2) and renoise.Sample.LOOP_MODE_PING_PONG or renoise.Sample.LOOP_MODE_FORWARD
          sample_loop_mode = new_mode
          if live_pickup_mode then
            local song = renoise.song()
            local inst = song.selected_instrument
            if PCMWriterDetect12stWTSetup() then
              if #inst.samples >= 1 then inst:sample(1).loop_mode = new_mode end
              if #inst.samples >= 2 then inst:sample(2).loop_mode = new_mode end
              -- Re-pitch both samples if standard single-cycle size
              if #inst.samples >= 1 then PCMWriterApplyPitchCorrectionToSample(inst:sample(1), wave_size) end
              if #inst.samples >= 2 then PCMWriterApplyPitchCorrectionToSample(inst:sample(2), wave_size) end
            elseif live_pickup_sample then
              live_pickup_sample.loop_mode = new_mode
              -- Re-pitch selected sample if standard single-cycle size
              PCMWriterApplyPitchCorrectionToSample(live_pickup_sample, wave_size)
            end
            renoise.app():show_status("Live Pickup: Loop mode set to " .. ((idx == 2) and "PingPong" or "Forward"))
          end
        end
      },
      vb:checkbox{
        value = hide_hex_editor,
        notifier = function(value)
          hide_hex_editor = value
          -- Save preference (inverted because checkbox is "Hide Hex")
          if preferences and preferences.singlewaveformwriterhex then
            preferences.singlewaveformwriterhex.value = not value
          end
          -- Rebuild dialog to show/hide hex editor (required by Renoise UI limitations)
          if pcm_dialog then
            renoise.app():show_status("Rebuilding dialog to " .. (hide_hex_editor and "hide" or "show") .. " hex editor...")
            pcm_dialog:close()
            PCMWriterShowPcmDialog()
          end
        end
      },
      vb:text{ text = "Hide Hex", style = "strong" },
      vb:text{ text = "| Cursor Width", style = "strong" },
      cursor_step_slider,
      cursor_step_text
    }, -- SAMPLE_SETTINGS_ROW ENDS
    
    -- Shape parameters row 2
    vb:row{ -- SHAPE_PARAMS_ROW STARTS
      vb:text{ text = "Shape Parameters:", style = "strong" },
      vb:text{ text = "Asymmetry", style = "normal" },
      vb:slider{
        min = 0.1,
        max = 0.9,
        value = shape_asymmetry,
        width = 120,  -- Much larger slider
        notifier = function(value)
          shape_asymmetry = value
          hex_field_has_focus = false
          -- Update the numeric display and shape text
          if pcm_dialog and pcm_dialog.visible then
            local asym_display = vb.views.asym_value
            if asym_display then
              asym_display.text = string.format("%.2f", shape_asymmetry)
            end
            local shape_display = vb.views.current_shape_text
            if shape_display then
              shape_display.text = string.format("%s (%.2f/%.0f)", geometric_shapes[current_geometric_index], shape_asymmetry, shape_segments)
            end
          end
          -- Only regenerate if we're in geometric mode
          if current_waveform_type == "geometric" then
            -- Regenerate geometric shape with new parameters
            PCMWriterGenerateParametricShape()
            -- Explicitly update canvas
            if waveform_canvas then
              waveform_canvas:update()
            end
            renoise.app():show_status(string.format("Asymmetry: %.2f (geometric shape: %s)", shape_asymmetry, geometric_shapes[current_geometric_index]))
          else
            -- Don't regenerate - just update parameter and preserve current waveform
            renoise.app():show_status(string.format("Asymmetry: %.2f (current waveform preserved)", shape_asymmetry))
          end
        end
      },
      vb:text{ text = string.format("%.2f", shape_asymmetry), id = "asym_value", width = 40 },
      vb:text{ text = "Segments", style = "normal" },
      vb:slider{
        min = 1,
        max = 64,
        value = shape_segments,
        width = 120,  -- Much larger slider
        steps = {1, -1},  -- Step by 1 for proper integer increments
        notifier = function(value)
          shape_segments = math.floor(value)
          hex_field_has_focus = false
          -- Update the numeric display and shape text
          if pcm_dialog and pcm_dialog.visible then
            local segs_display = vb.views.segs_value
            if segs_display then
              segs_display.text = string.format("%.0f", shape_segments)
            end
            local shape_display = vb.views.current_shape_text
            if shape_display then
              shape_display.text = string.format("%s (%.2f/%.0f)", geometric_shapes[current_geometric_index], shape_asymmetry, shape_segments)
            end
          end
          -- Only regenerate if we're in geometric mode
          if current_waveform_type == "geometric" then
            -- Regenerate geometric shape with new parameters
            PCMWriterGenerateParametricShape()
            renoise.app():show_status(string.format("Segments: %.0f (geometric shape: %s)", shape_segments, geometric_shapes[current_geometric_index]))
          else
            -- Don't regenerate - just update parameter and preserve current waveform
            renoise.app():show_status(string.format("Segments: %.0f (current waveform preserved)", shape_segments))
          end
        end
      },
      vb:text{ text = string.format("%.0f", shape_segments), id = "segs_value", width = 30 },
      vb:button{
        text = "Generate Shape",
        width = 100,
        tooltip = "Generate current geometric shape with current parameters",
        notifier = function()
          current_waveform_type = "geometric"
          PCMWriterGenerateParametricShape()
        end
      },
      vb:text{
        id = "current_shape_text",
        text = string.format("%s (%.2f/%.0f)", geometric_shapes[current_geometric_index], shape_asymmetry, shape_segments),
        width = 150,
        font = "mono",
        tooltip = "Current shape with parameters"
      }
    }, -- SHAPE_PARAMS_ROW ENDS
    
    -- Wave A/B crossfade row
    vb:row{ -- WAVE_AB_ROW STARTS
      vb:text{ text = "Wave A/B:", style = "strong" },
      vb:button{
        text = "Edit A",
        width = 50,
        color = current_wave_edit == "A" and COLOR_BUTTON_ACTIVE or COLOR_BUTTON_INACTIVE,
        tooltip = "Edit Wave A",
        notifier = function()
          local saved_cursor_pos = selected_sample_index
          print("DEBUG: Edit A clicked - cursor before switch: " .. tostring(saved_cursor_pos))
          current_wave_edit = "A"
          
          -- Enhanced: Switch to sample slot 1 if in 12st_WT setup
          local is_12st_wt_setup = PCMWriterDetect12stWTSetup()
          if is_12st_wt_setup then
            local song = renoise.song()
            song.selected_sample_index = 1
            renoise.app():show_status("Now editing Wave A (sample slot 1)")
          else
            renoise.app():show_status("Now editing Wave A")
          end
          
          -- Update harmonic drawbars if in harmonic mode and 12st_WT setup [[memory:6653553]]
          if is_12st_wt_setup and harmonic_drawbar_mode and harmonic_canvas and live_pickup_mode then
            print("HARMONIC: Edit A clicked - loading Wave A harmonic data into drawbars")
            local restored = PCMWriterRestoreHarmonicLevels()
            if restored then
              harmonic_canvas:update()
              print("HARMONIC: Edit A - harmonic drawbars updated to show Wave A settings")
            else
              print("HARMONIC: Edit A - no harmonic data found for Wave A")
            end
          end
          
          -- Update button colors
          if pcm_dialog and pcm_dialog.visible then
            local edit_a_btn = vb.views.edit_a_btn
            local edit_b_btn = vb.views.edit_b_btn
            if edit_a_btn then edit_a_btn.color = COLOR_BUTTON_ACTIVE end
            if edit_b_btn then edit_b_btn.color = COLOR_BUTTON_INACTIVE end
          end
          -- Preserve cursor position during wave switch
          selected_sample_index = saved_cursor_pos
          print("DEBUG: Edit A - cursor after switch: " .. tostring(selected_sample_index))
          -- Update canvas to show new wave colors
          if waveform_canvas then
            waveform_canvas:update()
          end
        end,
        id = "edit_a_btn"
      },
      vb:button{
        text = "Edit B",
        width = 50,
        color = current_wave_edit == "B" and COLOR_BUTTON_ACTIVE or COLOR_BUTTON_INACTIVE,
        tooltip = "Edit Wave B",
        notifier = function()
          local saved_cursor_pos = selected_sample_index
          print("DEBUG: Edit B clicked - cursor before switch: " .. tostring(saved_cursor_pos))
          current_wave_edit = "B"
          
          -- Enhanced: Switch to sample slot 2 if in 12st_WT setup
          local is_12st_wt_setup = PCMWriterDetect12stWTSetup()
          if is_12st_wt_setup then
            local song = renoise.song()
            song.selected_sample_index = 2
            renoise.app():show_status("Now editing Wave B (sample slot 2)")
          else
            renoise.app():show_status("Now editing Wave B")
          end
          
          -- Update harmonic drawbars if in harmonic mode and 12st_WT setup [[memory:6653553]]
          if is_12st_wt_setup and harmonic_drawbar_mode and harmonic_canvas and live_pickup_mode then
            print("HARMONIC: Edit B clicked - loading Wave B harmonic data into drawbars")
            local restored = PCMWriterRestoreHarmonicLevels()
            if restored then
              harmonic_canvas:update()
              print("HARMONIC: Edit B - harmonic drawbars updated to show Wave B settings")
            else
              print("HARMONIC: Edit B - no harmonic data found for Wave B")
            end
          end
          
          -- Update button colors
          if pcm_dialog and pcm_dialog.visible then
            local edit_a_btn = vb.views.edit_a_btn
            local edit_b_btn = vb.views.edit_b_btn
            if edit_a_btn then edit_a_btn.color = COLOR_BUTTON_INACTIVE end
            if edit_b_btn then edit_b_btn.color = COLOR_BUTTON_ACTIVE end
          end
          -- Preserve cursor position during wave switch
          selected_sample_index = saved_cursor_pos
          print("DEBUG: Edit B - cursor after switch: " .. tostring(selected_sample_index))
          -- Update canvas to show new wave colors
          if waveform_canvas then
            waveform_canvas:update()
          end
        end,
        id = "edit_b_btn"
      },
      vb:text{ text = "Crossfade", style = "normal" },
      vb:slider{
        id = "crossfade_slider",
        min = 0.0,
        max = 1.0,
        value = crossfade_amount,
        width = 150,
        tooltip = "Crossfade between Wave A (0%) and Wave B (100%)",
        notifier = function(value)
          crossfade_amount = value
          PCMWriterUpdateCrossfadedWave()
          PCMWriterUpdateLiveSample()  -- Live update sample when crossfade changes
          -- Update the numeric display
          if pcm_dialog and pcm_dialog.visible then
            local crossfade_display = vb.views.crossfade_value
            if crossfade_display then
              crossfade_display.text = string.format("%.1f%%", crossfade_amount * 100)
            end
          end
          renoise.app():show_status(string.format("Crossfade: %.1f%% (A=%.1f%%, B=%.1f%%)", 
            crossfade_amount * 100, (1 - crossfade_amount) * 100, crossfade_amount * 100))
        end
      },
      vb:text{ text = string.format("%.1f%%", crossfade_amount * 100), id = "crossfade_value", width = 40 },
      vb:button{
        text = "Swap A↔B",
        width = 60,
        tooltip = "Swap Wave A and Wave B",
        notifier = PCMWriterSwapWaves
      },
      vb:button{
        text = "Random AKWF",
        width = 80,
        tooltip = "Load random AKWF to currently selected Wave (A or B)",
        notifier = PCMWriterLoadRandomAKWFToCurrentWave
      }
    }, -- WAVE_AB_ROW ENDS
    
    -- Enhanced LFO Controls Row (always created, initially hidden)
    vb:row{ -- LFO_CONTROLS_ROW STARTS
      id = "lfo_controls_row",
      visible = false, -- Initially hidden, shown when entering Live Pickup Mode with 12st_WT setup
      vb:text{ text = "Wavetable LFO:", style = "strong" },
      vb:text{ text = "Amplitude:", style = "normal" },
      vb:slider{
        id = "lfo_amplitude_slider",
        min = 0.0,
        max = 1.0,
        value = 0.0,
        width = 150,
        tooltip = "LFO Amplitude",
        notifier = function(value)
          local lfo_device = PCMWriterFindWavetableLFODevice()
          if lfo_device then
            lfo_device.parameters[4].value = value -- Amplitude parameter
            if pcm_dialog and pcm_dialog.visible then
              local amp_label = vb.views.lfo_amplitude_label
              if amp_label then
                amp_label.text = string.format("%.2f", value)
              end
            end
          end
        end
      },
      vb:text{
        id = "lfo_amplitude_label",
        text = "0.00",
        width = 30
      },
      vb:text{ text = "Offset:", style = "normal" },
      vb:slider{
        id = "lfo_offset_slider",
        min = -0.5,
        max = 0.5,
        value = 0.0,
        width = 150,
        tooltip = "LFO Offset",
        notifier = function(value)
          local lfo_device = PCMWriterFindWavetableLFODevice()
          if lfo_device then
            lfo_device.parameters[5].value = value -- Offset parameter
            if pcm_dialog and pcm_dialog.visible then
              local offset_label = vb.views.lfo_offset_label
              if offset_label then
                offset_label.text = string.format("%.2f", value)
              end
            end
          end
        end
      },
      vb:text{
        id = "lfo_offset_label",
        text = "0.00",
        width = 30
      },
      vb:text{ text = "Frequency:", style = "normal" },
      vb:slider{
        id = "lfo_frequency_slider",
        min = 0.000001,
        max = 60,
        value = 1.0,
        width = 150,
        tooltip = "LFO Frequency",
        notifier = function(value)
          local lfo_device = PCMWriterFindWavetableLFODevice()
          if lfo_device then
            lfo_device.parameters[6].value = value -- Frequency parameter
            if pcm_dialog and pcm_dialog.visible then
              local freq_label = vb.views.lfo_frequency_label
              if freq_label then
                -- Convert device value to LPC display (60 = 1 LPC), handle INF case
                local lpc_value = 60 / value  -- Inverted: lower freq = higher LPC
                local display_text = (value <= 0.000001) and "INF" or string.format("%.2fLPC", lpc_value)
                freq_label.text = display_text
              end
            end
          end
        end
      },
      vb:text{
        id = "lfo_frequency_label",
        text = "1.00",
        width = 30
      },
      vb:button{
        text = "Random",
        width = 50,
        tooltip = "Randomize all LFO parameters",
        notifier = function()
          local amp = math.random() * 0.8 + 0.1 -- 0.1 to 0.9
          local offset = (math.random() - 0.5) * 0.8 -- -0.4 to 0.4 (within -0.5 to 0.5 range)
          local freq = math.random() * 59.9 + 0.1 -- 0.1 to 60 (device value range)
          
          local lfo_device = PCMWriterFindWavetableLFODevice()
          if lfo_device then
            lfo_device.parameters[4].value = amp
            lfo_device.parameters[5].value = offset
            lfo_device.parameters[6].value = freq
            
            -- Update UI sliders and labels
            if pcm_dialog and pcm_dialog.visible then
              local amp_slider = vb.views.lfo_amplitude_slider
              local amp_label = vb.views.lfo_amplitude_label
              local offset_slider = vb.views.lfo_offset_slider
              local offset_label = vb.views.lfo_offset_label
              local freq_slider = vb.views.lfo_frequency_slider
              local freq_label = vb.views.lfo_frequency_label
              
              if amp_slider then amp_slider.value = amp end
              if amp_label then amp_label.text = string.format("%.2f", amp) end
              if offset_slider then offset_slider.value = offset end
              if offset_label then offset_label.text = string.format("%.2f", offset) end
              if freq_slider then freq_slider.value = freq end
              if freq_label then 
                -- Convert device value to LPC display (60 = 1 LPC), handle INF case
                local lpc_value = 60 / freq  -- Inverted: lower freq = higher LPC
                local display_text = (freq <= 0.000001) and "INF" or string.format("%.2fLPC", lpc_value)
                freq_label.text = display_text
              end
            end
            
            -- Convert frequency to LPC for status display
            local freq_lpc = 60 / freq  -- Inverted: lower freq = higher LPC
            local freq_display = (freq <= 0.000001) and "INF" or string.format("%.2fLPC", freq_lpc)
            renoise.app():show_status(string.format("LFO Random: Amp=%.2f, Offset=%.2f, Freq=%s", amp, offset, freq_display))
          end
        end
      }
    }, -- LFO_CONTROLS_ROW ENDS
    
    -- Chebyshev controls row (conditional)
    not hideChebyshev and vb:row{ -- CHEBYSHEV_ROW STARTS
      vb:text{ text = "Chebyshev:", style = "strong" },
      vb:popup{
        items = {"T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8"},
        value = chebyshev_order,
        width = 50,
        tooltip = "Chebyshev polynomial order",
        notifier = function(value)
          chebyshev_order = value
        end
      },
      vb:button{
        text = "Generate",
        width = 70,
        tooltip = "Generate Chebyshev polynomial to current wave",
        notifier = function()
          PCMWriterGenerateChebyshev(chebyshev_order, PCMWriterGetCurrentWaveData(), wave_size)
          PCMWriterUpdateLiveSample()  -- Live update sample when generating Chebyshev
          renoise.app():show_status(string.format("Generated Chebyshev T%d to Wave %s", chebyshev_order, current_wave_edit))
        end
      },
      vb:text{ text = "Mix:", style = "normal" },
      vb:slider{
        min = 0.0,
        max = 1.0,
        value = chebyshev_mix,
        width = 120,
        tooltip = "Mix Chebyshev into current wave (0% = original, 100% = full Chebyshev)",
        notifier = function(value)
          chebyshev_mix = value
          PCMWriterMixChebyshev(chebyshev_order, chebyshev_mix, PCMWriterGetCurrentWaveData(), wave_size)
          PCMWriterUpdateLiveSample()  -- Live update sample when Chebyshev mix changes
          -- Update the numeric display
          if pcm_dialog and pcm_dialog.visible then
            local cheby_mix_display = vb.views.cheby_mix_value
            if cheby_mix_display then
              cheby_mix_display.text = string.format("%.1f%%", chebyshev_mix * 100)
            end
          end
          renoise.app():show_status(string.format("Chebyshev T%d mix: %.1f%% into Wave %s", 
            chebyshev_order, chebyshev_mix * 100, current_wave_edit))
        end
      },
      vb:text{ text = string.format("%.1f%%", chebyshev_mix * 100), id = "cheby_mix_value", width = 40 }
    } or vb:space{}, -- CHEBYSHEV_ROW ENDS
    waveform_canvas,
    vb:text{
      text = "Click/drag to draw • Arrow keys up/down to edit selected frame, shift-up/down for faster, keys left/right to select a different frame, shift-left/right for faster.",
      font = "italic",
      width = 1024
    },
    
    -- Conditionally show hex editor based on hide_hex_editor flag
    not hide_hex_editor and vb:row{ -- HEX_EDITOR_ROW STARTS
      -- Hex editor column
      vb:column{ -- HEX_EDITOR_COLUMN STARTS
        style = "group",
        margin = 5,
        width = wavetable_canvas_width +5,  -- Use same variable as canvas
        vb:horizontal_aligner{ -- HEX_ALIGNER STARTS
          mode = "center",
          vb:column{ -- HEX_INNER_COLUMN STARTS
            vb:text{
              text = "Hex Editor - Wave " .. current_wave_edit .. " (Type to edit)",
              style = "strong"
            },
            hex_editor_content
          } -- HEX_INNER_COLUMN ENDS
        } -- HEX_ALIGNER ENDS
      }, -- HEX_EDITOR_COLUMN ENDS
    } or vb:space{}, -- HEX_EDITOR_ROW ENDS
    
    vb:horizontal_aligner{ -- TOOLS_ALIGNER STARTS
      mode = "distribute",
      vb:column{ -- SAMPLE_TOOLS_COLUMN STARTS
        style = "group",
        margin = 5,
        vb:text{
          text = "Sample Tools",
          style = "strong", font="bold"
        },
        vb:row{
          vb:button{
            text = "Invert",
            width = 70,
            tooltip = "Flip waveform upside down",
            notifier = PCMWriterInvertSelection
          },
          vb:button{
            text = "Normalize",
            width = 70,
            tooltip = "Scale to full range (whole wave if no selection)",
            notifier = PCMWriterNormalizeSelection
          }
        },
        vb:row{
          vb:button{
            text = "Fade In",
            width = 70,
            tooltip = "Fade from silence to full",
            notifier = PCMWriterFadeInSelection
          },
          vb:button{
            text = "Fade Out",
            width = 70,
            tooltip = "Fade from full to silence",
            notifier = PCMWriterFadeOutSelection
          }
        },
        vb:row{
          vb:button{
            text = "Silence",
            width = 70,
            tooltip = "Set to center (silence)",
            notifier = PCMWriterSilenceSelection
          },
          vb:button{
            text = "Reverse",
            width = 70,
            tooltip = "Reverse sample order",
            notifier = PCMWriterReverseSelection
          }
        },
        vb:row{
          vb:button{
            text = "Scale 150%",
            width = 70,
            tooltip = "Scale waveform to 150% amplitude",
            notifier = function()
              local saved_cursor = selected_sample_index
              local target_data = PCMWriterGetCurrentWaveData()
              for i = 1, wave_size do
                local center = 32768
                local deviation = target_data[i] - center
                target_data[i] = math.max(0, math.min(65535, center + math.floor(deviation * 1.5)))
              end
              selected_sample_index = saved_cursor
              PCMWriterUpdateCrossfadedWave()
              PCMWriterUpdateLiveSample()  -- Live update sample when scaling
              PCMWriterUpdateAllDisplays()
              renoise.app():show_status("Scaled waveform to 150% to Wave " .. current_wave_edit)
            end
          },
          vb:button{
            text = "Scale 50%",
            width = 70,
            tooltip = "Scale waveform to 50% amplitude",
            notifier = function()
              local saved_cursor = selected_sample_index
              local target_data = PCMWriterGetCurrentWaveData()
              for i = 1, wave_size do
                local center = 32768
                local deviation = target_data[i] - center
                target_data[i] = center + math.floor(deviation * 0.5)
              end
              selected_sample_index = saved_cursor
              PCMWriterUpdateCrossfadedWave()
              PCMWriterUpdateLiveSample()  -- Live update sample when scaling
              PCMWriterUpdateAllDisplays()
              renoise.app():show_status("Scaled waveform to 50% to Wave " .. current_wave_edit)
            end
          }
        },
        vb:button{
          text = "Pickup Wave",
          width = 140,
          tooltip = "Load current sample into waveform editor",
          notifier = function()
            PCMWriterLoadSampleToWaveform()
          end
        },
        vb:row{
          vb:button{
            text = "Live Pickup Mode",
            width = 140,
            tooltip = "Load current sample into editor for live editing",
            notifier = function()
              PCMWriterLoadCurrentSample()
            end
          }
        },
        vb:row{
          vb:button{
            text = "DoubleFreq",
            width = 140,
            tooltip = "Resample to half length and repeat twice (double frequency)",
            notifier = function()
              local target_data = PCMWriterGetCurrentWaveData()
              local half_length = math.floor(wave_size / 2)
              if half_length < 1 then
                renoise.app():show_status("Wave too short for DoubleFreq processing")
                return
              end
              
              -- Store original data
              local original_data = {}
              for i = 1, wave_size do
                original_data[i] = target_data[i]
              end
              
              -- First half: resample original to half length
              for i = 1, half_length do
                local source_pos = (i - 1) * (wave_size - 1) / (half_length - 1) + 1
                local source_index = math.floor(source_pos)
                local frac = source_pos - source_index
                
                -- Linear interpolation
                local sample1 = original_data[source_index] or 32768
                local sample2 = original_data[math.min(source_index + 1, wave_size)] or 32768
                target_data[i] = math.floor(sample1 + frac * (sample2 - sample1))
              end
              
              -- Second half: repeat the resampled data
              for i = 1, half_length do
                target_data[half_length + i] = target_data[i]
              end
              
              -- Clear any remaining samples if wave_size is not exactly divisible by 2
              for i = half_length * 2 + 1, wave_size do
                target_data[i] = 32768 -- Center/silence value
              end
              
              PCMWriterUpdateCrossfadedWave()
              PCMWriterUpdateLiveSample()  -- Live update sample when processing
              PCMWriterUpdateAllDisplays()
              renoise.app():show_status(string.format("DoubleFreq applied to Wave %s: %d -> %d frames repeated", current_wave_edit, wave_size, half_length))
            end
          }
        },
        vb:row{
          vb:button{
            text = "Harmonic Drawbars",
            width = 140,
            tooltip = "Toggle harmonic drawbar mode - augment current waveform with harmonics",
            notifier = function()
              if harmonic_drawbar_mode then
                PCMWriterExitHarmonicDrawbarMode()
              else
                PCMWriterEnterHarmonicDrawbarMode()
              end
            end
          }
        },
        vb:row{
          vb:canvas{
            id = "harmonic_drawbar_canvas",
            width = 140,
            height = 80,
            mode = "plain",
            render = PCMWriterDrawHarmonicCanvas,
            mouse_handler = PCMWriterHandleHarmonicMouse,
            mouse_events = {"down", "up", "move", "exit"},
            tooltip = "Augment current waveform with harmonics | Left-click: Draw levels | Right-click: Zero harmonic"
          }
        },
        vb:row{
          vb:text{
            text = "Amplitude",
            width = 60
          },
          vb:slider{
            id = "harmonic_amplitude_slider",
            min = 0.0,
            max = 1.0,
            value = 1.0,
            width = 75,
            tooltip = "Overall amplitude control (autogain applied)",
            notifier = function(value)
              harmonic_amplitude = value
              if harmonic_drawbar_mode then
                PCMWriterGenerateHarmonics()
                PCMWriterUpdateAllDisplays()
              end
              renoise.app():show_status(string.format("Amplitude: %.1f%%", value * 100))
            end
          }
        }
      }, -- SAMPLE_TOOLS_COLUMN ENDS
      vb:column{ -- EXPORT_TOOLS_COLUMN STARTS
        style = "group",
        margin = 5,
        vb:text{
          text = "Export Tools",
          style = "strong", font="bold"
        },vb:row{
        vb:button{
          text = "Load Wave File",
          width = 140,
          notifier = PCMWriterLoadWave
        },
        vb:button{
          text = "Load CSV File",
          width = 140,
          tooltip = "Load CSV with hex values (0000-FFFF)",
          notifier = PCMWriterLoadCSV
        },},
        vb:row{
        vb:button{
          text = "Import .WT",
          width = 140,
          tooltip = "Import wavetable: first wave → Wave A, last wave → Wave B",
          notifier = PCMWriterImportWTToWaves
        },
        vb:button{
          text = ".WT and Live Pickup",
          width = 140,
          tooltip = "Import full .WT to instrument, enable live pickup on first sample",
          notifier = PCMWriterImportWTAndLivePickup
        },},
        vb:button{
          text = "Export to Sample Slot",
          width = 140+140,
          tooltip = "Export crossfaded result (purple line)",
          notifier = PCMWriterExportToSample
        },
        vb:row{
        vb:button{
          text = "Export A to Sample Slot",
          width = 140,
          tooltip = "Export Wave A only (red line)",
          notifier = PCMWriterExportWaveAToSample
        },
        vb:button{
          text = "Export B to Sample Slot",
          width = 140,
          tooltip = "Export Wave B only (blue line)",
          notifier = PCMWriterExportWaveBToSample
        }},
        vb:row{
        vb:button{
          text = "Write A&B",
          width = 140,
          tooltip = "Create new instrument with Wave A as slot 1 and Wave B as slot 2",
          notifier = PCMWriterExportWaveAAndBToSample
        },
        vb:button{
          text = "Write A&B (Unison)",
          width = 140,
          tooltip = "Create new instrument with Wave A&B and apply unison processing",
          notifier = PCMWriterExportWaveAAndBToSampleWithUnison
        }},
        vb:row{
        vb:button{
          text = "Write AKWF A&B",
          width = 140,
          tooltip = "Load 2 random AKWF files and create 12st_WT.xrni wavetable instrument",
          notifier = PCMWriterLoad2RandomAKWFAndExport
        },
        vb:button{
          text = "Write AKWF A&B (Unison)",
          width = 140,
          tooltip = "Load 2 random AKWF files, create wavetable instrument and apply unison processing",
          notifier = PCMWriterLoad2RandomAKWFAndExportWithUnison
        }},
        vb:button{
          text = "Random Export to Slot",
          width = 280,
          tooltip = "Generate random waveform and export to sample slot",
          notifier = PCMWriterRandomExportToSlot
        },
        vb:row{
        vb:button{
          text = "Save as .BIN File",
          width = 140,
          notifier = PCMWriterSaveWaveBin
        },
        vb:button{
          text = "Save as .WAV File", 
          width = 140,
          notifier = PCMWriterSaveWaveWav
        },},
        vb:button{
          text = "Save as .CSV File",
          width = 280,
          tooltip = "Save as CSV with hex values",
          notifier = PCMWriterSaveCSV
        }
      }, -- EXPORT_TOOLS_COLUMN ENDS

      vb:column{ -- WAVETABLE_COLUMN STARTS
        style = "group",
        margin = 5,
        wavetable_count_text,
        vb:button{
          text = "Add Current to Wavetable",
          width = wt_buttonwidth,
          notifier = PCMWriterAddWavetableWave
        },
        vb:button{
          text = "Create 12 Random Instrument",
          width = wt_buttonwidth,
          tooltip = "Generate 12 random waveforms and create instrument",
          notifier = PCMWriterCreate12RandomInstrument
        },
        not hideChebyshev and vb:button{
          text = "Random 12 Chebyshev",
          width = wt_buttonwidth,
          tooltip = "Generate 12 Chebyshev-processed waveforms and create instrument",
          notifier = PCMWriterCreate12ChebyshevInstrument
        } or vb:space{},
        vb:button{
          text = "Export Wavetable to Sample",
          width = wt_buttonwidth,
          notifier = PCMWriterExportWavetableToSample
        },
        vb:button{
          text = "Save Wavetable (.WAV)",
          width = wt_buttonwidth,
          notifier = PCMWriterSaveWavetable
        },
        vb:text{
          text = "Morph Export:",
          style = "strong", font="bold"
        },
        vb:button{
          text = "Export Morph to Instrument",
          width = wt_buttonwidth,
          tooltip = "Create 127 samples morphing from Wave A to Wave B",
          notifier = PCMWriterExportMorphToInstrument
        },
        vb:button{
          text = "Export Morph to Instrument & .WT",
          width = wt_buttonwidth,
          tooltip = "Create 127 sample instrument + export as .WT file",
          notifier = PCMWriterExportMorphToInstrumentAndWT
        },
        vb:button{
          text = "Export Morph to .WT",
          width = wt_buttonwidth,
          tooltip = "Export 127 morph steps as .WT wavetable file",
          notifier = PCMWriterExportMorphToWTFile
        },
      } -- WAVETABLE_COLUMN ENDS
    } -- TOOLS_ALIGNER ENDS
  } -- DIALOG_CONTENT ENDS


  
  pcm_dialog = renoise.app():show_custom_dialog(DIALOG_TITLE, dialog_content, PCMWriterHandleKeyboard)
  
  -- Connect canvas references
  harmonic_canvas = vb.views.harmonic_drawbar_canvas
  
  -- Add sample change notifier for Live Pickup Mode (like other working tools)
  local song = renoise.song()
  if song.selected_sample_observable:has_notifier(update_dialog_on_selection_change) then
    song.selected_sample_observable:remove_notifier(update_dialog_on_selection_change)
  end
  song.selected_sample_observable:add_notifier(update_dialog_on_selection_change)
  
  -- Add idle notifier for cleanup when dialog is closed by other means
  if not renoise.tool().app_idle_observable:has_notifier(cleanup_on_dialog_close) then
    renoise.tool().app_idle_observable:add_notifier(cleanup_on_dialog_close)
  end
  
  PCMWriterUpdateAllDisplays()
  
  -- Initialize LFO controls if in enhanced mode
  PCMWriterInitializeLFOControls()
  
  -- Check for existing 12st_WT setup and auto-enter Live Pickup Mode
  print("DEBUG: Checking for existing 12st_WT setup on dialog open...")
  local has_12st_setup = PCMWriterDetect12stWTSetup()
  print("DEBUG: has_12st_setup = " .. tostring(has_12st_setup) .. ", live_pickup_mode = " .. tostring(live_pickup_mode))
  if has_12st_setup and not live_pickup_mode then
    print("DEBUG: Existing 12st_WT setup detected on dialog open, auto-entering Live Pickup Mode")
    PCMWriterEnterLivePickupMode()
  else
    print("DEBUG: Not auto-entering Live Pickup Mode")
  end
  
  -- Try to restore harmonic levels from existing instrument/sample names (if in live pickup mode)
  if live_pickup_mode then
    local restored = PCMWriterRestoreHarmonicLevels()
    if restored then
      print("HARMONIC: Restored harmonic levels from existing names on dialog open")
      -- Update harmonic canvas if it exists
      if harmonic_canvas then
        harmonic_canvas:update()
      end
    end
  end
  
  -- Clear the rebuilding flag after dialog is fully created
  dialog_rebuilding = false
end

-- CSV file hook for PCM Writer
function csv_load_to_pcm_writer(filename)
  -- Check if filename is nil or empty (user cancelled dialog)
  if not filename or filename == "" then
    dprint("CSV import cancelled - no file selected")
    renoise.app():show_status("CSV import cancelled - no file selected")
    return false
  end
  
  dprint("Starting CSV import for PCM Writer, file:", filename)
  
  -- Open PCM Writer dialog if it's not already open
  if not pcm_dialog or not pcm_dialog.visible then
    dprint("Opening PCM Writer dialog")
    PCMWriterShowPcmDialog()
  end
  
  -- Load the CSV file directly (modified version of PCMWriterLoadCSV)
  local file = io.open(filename, "r")
  if not file then
    dprint("ERROR: Cannot open CSV file")
    renoise.app():show_status("CSV Import Error: Cannot open file.")
    return false
  end
  
  local content = file:read("*a")
  file:close()
  dprint("Read CSV file, size:", #content, "bytes")
  
  -- Check if this is the new format (has "Complete State" in header)
  local is_new_format = content:match("Complete State") ~= nil
  
  if is_new_format then
    -- Use the existing new format parsing logic
    dprint("Detected new format CSV with complete state")
    
    -- Parse new format with Wave A, Wave B, and crossfade amount
    local wave_a_values = {}
    local wave_b_values = {}
    local loaded_crossfade = 0.5
    local loaded_current_edit = "A"
    
    -- Extract Wave A data
    local wave_a_section = content:match("-- Wave A Data:.-\n(.-)\n%-%- Wave B Data:")
    if wave_a_section then
      for value in wave_a_section:gmatch("[^,;%s\t\n]+") do
        local hex_value = tonumber(value, 16)
        if hex_value then
          hex_value = math.max(0, math.min(65535, hex_value))
          table.insert(wave_a_values, hex_value)
        end
      end
    end
    
    -- Extract Wave B data
    local wave_b_section = content:match("-- Wave B Data:.-\n(.-)\n%-%- Crossfade Amount:")
    if wave_b_section then
      for value in wave_b_section:gmatch("[^,;%s\t\n]+") do
        local hex_value = tonumber(value, 16)
        if hex_value then
          hex_value = math.max(0, math.min(65535, hex_value))
          table.insert(wave_b_values, hex_value)
        end
      end
    end
    
    -- Extract crossfade amount
    local crossfade_section = content:match("-- Crossfade Amount:.-\n([%d%.]+)")
    if crossfade_section then
      loaded_crossfade = tonumber(crossfade_section) or 0.5
      loaded_crossfade = math.max(0, math.min(1, loaded_crossfade))
    end
    
    -- Extract current wave edit
    local current_edit_section = content:match("-- Current Wave Edit:.-\n([AB])")
    if current_edit_section then
      loaded_current_edit = current_edit_section
    end
    
    -- Validate data
    if #wave_a_values == 0 or #wave_b_values == 0 or #wave_a_values ~= #wave_b_values then
      renoise.app():show_status("Invalid CSV format: missing or mismatched wave data")
      return false
    end
    
    local csv_size = #wave_a_values
    local valid_sizes = {16, 32, 64, 128, 256, 512, 1024}
    local size_match = false
    
    for _, size in ipairs(valid_sizes) do
      if csv_size == size then
        size_match = true
        break
      end
    end
    
    if not size_match then
      local size_list = table.concat(valid_sizes, ", ")
      renoise.app():show_status(string.format("CSV contains %d values. Supported sizes: %s", csv_size, size_list))
      return false
    end
    
    -- Apply the loaded state to PCM Writer
    -- Store current dialog state
    local dialog_was_visible = pcm_dialog and pcm_dialog.visible
    
    -- If CSV size doesn't match current wave size, change wave size
    if csv_size ~= wave_size then
      wave_size = csv_size
      wave_data = table.create()
      wave_data_a = table.create()
      wave_data_b = table.create()
      
      -- Initialize arrays with proper size
      for i = 1, wave_size do
        wave_data[i] = 32768
        wave_data_a[i] = 32768
        wave_data_b[i] = 32768
      end
      
      -- Rebuild dialog with new size
      if pcm_dialog then
        pcm_dialog:close()
      end
    end
    
    -- Load the complete state
    for i = 1, csv_size do
      wave_data_a[i] = wave_a_values[i]
      wave_data_b[i] = wave_b_values[i]
    end
    
    -- Restore crossfade amount and current wave edit
    crossfade_amount = loaded_crossfade
    current_wave_edit = loaded_current_edit
    
    -- Update crossfaded wave
    PCMWriterUpdateCrossfadedWave()
    
    -- Update UI crossfade slider if dialog is open
    if pcm_dialog and pcm_dialog.visible then
      local crossfade_slider = vb.views.crossfade_slider
      local crossfade_display = vb.views.crossfade_value
      if crossfade_slider then crossfade_slider.value = crossfade_amount end
      if crossfade_display then crossfade_display.text = string.format("%.1f%%", crossfade_amount * 100) end
    end
    
    -- Reset editor state
    selected_sample_index = -1
    selection_start = -1
    selection_end = -1
    PCMWriterZoomFit()
    
    -- Show dialog if it was closed due to size change
    if not pcm_dialog or not pcm_dialog.visible then
      if dialog_was_visible then
        PCMWriterShowPcmDialog()
      end
    end
    
    -- Force canvas update with delay to ensure proper initialization
    if waveform_canvas then
      waveform_canvas:update()
    end
    
    -- Update all displays
    PCMWriterUpdateAllDisplays()
    
    -- Additional forced update after a brief delay to ensure canvas is properly refreshed
    renoise.tool():add_timer(function()
      if waveform_canvas then
        waveform_canvas:update()
      end
      PCMWriterUpdateHexDisplay()
    end, 100)  -- 100ms delay
    
    renoise.app():show_status(string.format("Complete wave state loaded: %d samples, %.1f%% crossfade, Wave %s", csv_size, loaded_crossfade * 100, loaded_current_edit))
    
  else
    -- Handle old format (backwards compatibility) - simple hex values
    dprint("Detected legacy format CSV with simple hex values")
    local values = {}
    
    -- Split by lines and process each line
    for line in content:gmatch("[^\r\n]+") do
      -- Skip empty lines and comments
      if line:match("%S") and not line:match("^%s*%-%-") then
        -- Split by comma, semicolon, or tab
        for value in line:gmatch("[^,;%s\t]+") do
          -- Clean up the value (remove quotes, spaces)
          value = value:gsub("^%s*[\"']?", ""):gsub("[\"']?%s*$", "")
          
          -- Try to parse as hex first (with or without 0x prefix)
          local hex_value = nil
          if value:match("^0[xX]") then
            -- Has 0x prefix
            hex_value = tonumber(value, 16)
          elseif value:match("^[0-9A-Fa-f]+$") then
            -- Pure hex digits
            hex_value = tonumber(value, 16)
          else
            -- Try as decimal
            hex_value = tonumber(value)
          end
          
          if hex_value then
            -- Clamp to valid range (0000-FFFF)
            hex_value = math.max(0, math.min(65535, hex_value))
            table.insert(values, hex_value)
          end
        end
      end
    end
    
    -- Check if we have valid data
    if #values == 0 then
      renoise.app():show_status("No valid numeric values found in CSV file")
      return false
    end
    
    -- Check if the number of values matches supported wave sizes
    local valid_sizes = {16, 32, 64, 128, 256, 512, 1024}
    local csv_size = #values
    local size_match = false
    
    for _, size in ipairs(valid_sizes) do
      if csv_size == size then
        size_match = true
        break
      end
    end
    
    if not size_match then
      local size_list = table.concat(valid_sizes, ", ")
      renoise.app():show_status(string.format("CSV contains %d values. Supported sizes: %s", csv_size, size_list))
      return false
    end
    
    -- Load old format into current wave
    local target_data = PCMWriterGetCurrentWaveData()
    for i = 1, csv_size do
      target_data[i] = values[i]
    end
    
    -- Update crossfaded wave
    PCMWriterUpdateCrossfadedWave()
    
    renoise.app():show_status(string.format("Legacy CSV loaded into Wave %s: %d values", current_wave_edit, csv_size))
  end
  
  dprint("CSV import completed successfully")
  return true
end

-- CSV file hook integration
local csv_integration = {
  category = "sample",
  extensions = { "csv" },
  invoke = csv_load_to_pcm_writer
}

if not renoise.tool():has_file_import_hook("sample", { "csv" }) then
  renoise.tool():add_file_import_hook(csv_integration)
end





-- Harmonic Drawbar System Variables (Global scope for UI access)
harmonic_drawbar_mode = false
harmonic_levels = {}  -- H1 to H11 levels (0.0 to 1.0)
harmonic_amplitude = 1.0  -- Amplitude control for autogain (0.0 to 1.0)
harmonic_canvas = nil
harmonic_mouse_down = false
harmonic_last_mouse_x = -1
harmonic_last_mouse_y = -1

-- Initialize harmonic levels (all at 0.0 by default)
for i = 1, 11 do
  harmonic_levels[i] = 0.0
end

-- Enter Harmonic Drawbar Mode
function PCMWriterEnterHarmonicDrawbarMode()
  print("HARMONIC: Entering Harmonic Drawbar Mode")
  print("HARMONIC: Will augment current wave: " .. current_wave_edit)
  
  -- No need to switch waves - work with whatever wave is currently active
  
  -- No UI changes needed - harmonic mode works with current wave settings
  
  -- Enable harmonic drawbar mode
  harmonic_drawbar_mode = true
  
  -- Enable live pickup mode
  live_pickup_mode = true
  
  -- Try to restore harmonic levels from existing instrument/sample names
  local restored = PCMWriterRestoreHarmonicLevels()
  
  if not restored then
    -- No existing harmonics found - set H1 = 1.0, others = 0.0
    print("HARMONIC: No existing harmonics found, setting H1=1.0")
    for i = 1, 11 do
      harmonic_levels[i] = 0.0
    end
    harmonic_levels[1] = 1.0
  end
  
  -- Generate harmonics based on current levels
  PCMWriterGenerateHarmonics()
  
  -- Update displays
  PCMWriterUpdateAllDisplays()
  if harmonic_canvas then
    print("HARMONIC: Updating harmonic canvas")
    harmonic_canvas:update()
  else
    print("HARMONIC: ERROR - harmonic_canvas is nil!")
  end
  
  renoise.app():show_status("Harmonic Drawbar Mode: Augmenting " .. current_wave_edit .. " with harmonics, Live Pickup ON")
end

-- Exit Harmonic Drawbar Mode
function PCMWriterExitHarmonicDrawbarMode()
  print("HARMONIC: Exiting Harmonic Drawbar Mode")
  harmonic_drawbar_mode = false
  
  -- Reset instrument and sample names when exiting harmonic mode in live pickup
  if live_pickup_mode and live_pickup_instrument then
    live_pickup_instrument.name = string.format("PCM Wave %s (%d frames)", current_wave_edit, wave_size)
    if live_pickup_sample then
      live_pickup_sample.name = string.format("PCM Wave %s (%d frames)", current_wave_edit, wave_size)
    end
    print("HARMONIC: Reset instrument name to: " .. live_pickup_instrument.name)
  end
  
  -- Update displays
  PCMWriterUpdateAllDisplays()
  if harmonic_canvas then
    harmonic_canvas:update()
  end
  
  renoise.app():show_status("Harmonic Drawbar Mode: OFF")
end

-- Calculate autogain to prevent clipping while maximizing volume
function PCMWriterCalculateAutogain()
  -- Calculate the theoretical maximum amplitude that could be reached
  local max_theoretical_amplitude = 0.0
  
  -- Add base waveform maximum (assuming worst case of 1.0)
  local base_amplitude = 1.0
  
  -- Add all harmonic contributions
  local harmonic_sum = 0.0
  for harmonic = 1, 11 do
    if harmonic_levels[harmonic] > 0.0 then
      harmonic_sum = harmonic_sum + harmonic_levels[harmonic]
    end
  end
  
  -- Total theoretical maximum (base + all harmonics)
  max_theoretical_amplitude = base_amplitude + harmonic_sum
  
  -- Calculate autogain factor to prevent clipping
  local autogain_factor = 1.0
  if max_theoretical_amplitude > 1.0 then
    autogain_factor = 1.0 / max_theoretical_amplitude
  end
  
  -- Apply user amplitude control
  autogain_factor = autogain_factor * harmonic_amplitude
  
  return autogain_factor
end

-- Parse harmonic levels from instrument/sample name
function PCMWriterParseHarmonicLevels(name)
  if not name then return false end
  
  -- Look for harmonic pattern like "H1=0.50,H2=0.38,H3=0.25... (512 frames)"
  -- Extract everything before " (number frames)"
  local harmonic_data = string.match(name, "^(.+)%s+%(%d+%s+frames%)$")
  
  if not harmonic_data then
    print("HARMONIC: No harmonic data found in name: " .. name)
    return false
  end
  
  print("HARMONIC: Found harmonic data: " .. harmonic_data)
  
  -- Reset all harmonic levels first
  for i = 1, 11 do
    harmonic_levels[i] = 0.0
  end
  
  -- Parse individual harmonic values like "H1=0.50,H2=0.38"
  local count = 0
  for harmonic_str in string.gmatch(harmonic_data, "([^,]+)") do
    local h_num, h_val = string.match(harmonic_str, "H(%d+)=([%d%.]+)")
    if h_num and h_val then
      local harmonic_index = tonumber(h_num)
      local harmonic_value = tonumber(h_val)
      
      if harmonic_index and harmonic_value and harmonic_index >= 1 and harmonic_index <= 11 then
        harmonic_levels[harmonic_index] = harmonic_value
        count = count + 1
        print(string.format("HARMONIC: Parsed H%d = %.2f", harmonic_index, harmonic_value))
      end
    end
  end
  
  if count > 0 then
    print(string.format("HARMONIC: Successfully parsed %d harmonic levels from name", count))
    return true
  else
    print("HARMONIC: No valid harmonic levels found in name")
    return false
  end
end

-- Restore harmonic levels from current instrument/sample names
function PCMWriterRestoreHarmonicLevels()
  if not live_pickup_mode then
    return false
  end
  
  -- In 12st_WT setup, prioritize currently selected sample over tracking variables
  local is_12st_wt_setup = PCMWriterDetect12stWTSetup()
  if is_12st_wt_setup then
    local song = renoise.song()
    local current_sample = song.selected_sample
    if current_sample and PCMWriterParseHarmonicLevels(current_sample.name) then
      print("HARMONIC: Restored harmonic levels from currently selected sample: " .. current_sample.name)
      return true
    end
    
    local current_instrument = song.selected_instrument
    if current_instrument and PCMWriterParseHarmonicLevels(current_instrument.name) then
      print("HARMONIC: Restored harmonic levels from currently selected instrument")
      return true
    end
  else
    -- Standard live pickup mode - use tracking variables
    -- Try instrument name first
    if live_pickup_instrument and PCMWriterParseHarmonicLevels(live_pickup_instrument.name) then
      print("HARMONIC: Restored harmonic levels from instrument name")
      return true
    end
    
    -- Try sample name as fallback
    if live_pickup_sample and PCMWriterParseHarmonicLevels(live_pickup_sample.name) then
      print("HARMONIC: Restored harmonic levels from sample name")
      return true
    end
  end
  
  print("HARMONIC: No harmonic levels found in instrument or sample names")
  return false
end

-- Generate harmonics by augmenting the current waveform
function PCMWriterGenerateHarmonics()
  if not harmonic_drawbar_mode then
    print("HARMONIC: Not in harmonic mode, skipping generation")
    return
  end
  
  print("HARMONIC: Augmenting current waveform with harmonics")
  print("HARMONIC: Wave size = " .. wave_size)
  print("HARMONIC: Current wave edit = " .. current_wave_edit)
  
  -- Get the current wave data as the base to augment
  local current_wave_data = PCMWriterGetCurrentWaveData()
  
  print("HARMONIC: Starting harmonic augmentation of existing waveform")
  
  -- Store the original waveform data for restoration
  local original_data = {}
  for i = 1, wave_size do
    original_data[i] = current_wave_data[i]
  end
  
  -- Calculate autogain factor once (optimization - doesn't change per sample)
  local autogain_factor = PCMWriterCalculateAutogain()
  print("HARMONIC: Using autogain factor = " .. string.format("%.3f", autogain_factor))
  
  -- Start with the original waveform and add harmonics to it
  for i = 1, wave_size do
    -- Convert original sample to -1..1 range
    local mixed = (original_data[i] - 32768) / 32768
    
    -- Add each harmonic sine wave to the original waveform
    for harmonic = 1, 11 do
      local level = harmonic_levels[harmonic]
      if level > 0.0 then
        -- Use slider level directly as maximum amplitude (no additional scaling)
        local scaled_level = level
        
        -- Calculate phase for this harmonic (harmonic 1 = fundamental, 2 = double freq, etc.)
        local phase = ((i - 1) / wave_size) * harmonic * math.pi * 2
        local sine_value = math.sin(phase)
        
        -- Add this harmonic sine wave to the mix
        mixed = mixed + (sine_value * scaled_level)
      end
    end
    
    -- Apply autogain to prevent clipping while maximizing volume
    mixed = mixed * autogain_factor
    
    -- Prevent clipping by normalizing if needed (should be rare with proper autogain)
    if mixed > 1.0 then mixed = 1.0 end
    if mixed < -1.0 then mixed = -1.0 end
    
    -- Convert back to 0-65535 range and write to current wave
    current_wave_data[i] = math.floor((mixed * 32768) + 32768)
  end
  
  -- Log active harmonics (store original levels without scaling for name)
  local active_harmonics = {}
  for harmonic = 1, 11 do
    if harmonic_levels[harmonic] > 0.0 then
      -- Store original harmonic level in sample name without degrading scaling
      table.insert(active_harmonics, string.format("H%d=%.2f", harmonic, harmonic_levels[harmonic]))
    end
  end
  
  if #active_harmonics > 0 then
    print("HARMONIC: Active harmonics: " .. table.concat(active_harmonics, ", "))
  end
  
  -- Update crossfaded wave and live sample
  PCMWriterUpdateCrossfadedWave()
  PCMWriterUpdateLiveSample()
  
  -- Update instrument and sample names to reflect harmonic content when in live pickup mode
  if live_pickup_mode and live_pickup_instrument then
    if #active_harmonics > 0 then
      live_pickup_instrument.name = string.format("%s (%d frames)", table.concat(active_harmonics, ","), wave_size)
      -- Also update sample name if available
      if live_pickup_sample then
        live_pickup_sample.name = string.format("%s (%d frames)", table.concat(active_harmonics, ","), wave_size)
      end
    else
      -- No harmonics active - just base waveform
      live_pickup_instrument.name = string.format("PCM Wave %s (%d frames)", current_wave_edit, wave_size)
      if live_pickup_sample then
        live_pickup_sample.name = string.format("PCM Wave %s (%d frames)", current_wave_edit, wave_size)
      end
    end
    print("HARMONIC: Updated instrument name to: " .. live_pickup_instrument.name)
  end
  
  print("HARMONIC: Augmented " .. current_wave_edit .. " with " .. #active_harmonics .. " harmonics")
end

-- Draw Harmonic Canvas (11 vertical sliders)
function PCMWriterDrawHarmonicCanvas(ctx)
  print("HARMONIC: Drawing harmonic canvas")
  
  -- Debug: Show current harmonic levels
  local level_debug = {}
  for i = 1, 11 do
    if harmonic_levels[i] > 0.0 then
      table.insert(level_debug, string.format("H%d=%.2f", i, harmonic_levels[i]))
    end
  end
  if #level_debug > 0 then
    print("HARMONIC: Canvas drawing with levels: " .. table.concat(level_debug, ","))
  else
    print("HARMONIC: Canvas drawing with all levels at 0.0")
  end
  
  local w = 140
  local h = 80
  local margin = 2
  local slider_width = (w - (margin * 12)) / 11  -- 11 sliders with margins
  
  -- Clear canvas
  ctx:clear_rect(0, 0, w, h)
  
  -- Draw background
  ctx.fill_color = {20, 20, 30, 255}
  ctx:fill_rect(0, 0, w, h)
  
  -- Draw border
  ctx.stroke_color = {100, 100, 100, 255}
  ctx.line_width = 1
  ctx:begin_path()
  ctx:rect(0, 0, w, h)
  ctx:stroke()
  
  -- Draw 11 harmonic sliders
  for i = 1, 11 do
    local x = margin + (i - 1) * (slider_width + margin)
    local level = harmonic_levels[i]
    local slider_height = h - (margin * 2)
    local fill_height = level * slider_height
    local fill_y = h - margin - fill_height
    
    -- Draw slider background (dark)
    ctx.fill_color = {40, 40, 50, 255}
    ctx:fill_rect(x, margin, slider_width, slider_height)
    
    -- Draw slider fill based on level
    if level > 0.0 then
      -- All harmonics use deep purple
      local alpha = harmonic_drawbar_mode and 255 or 128  -- Dimmed when inactive
      ctx.fill_color = {120, 40, 160, alpha}  -- Deep purple for all harmonics
      ctx:fill_rect(x, fill_y, slider_width, fill_height)
    end
    
    -- Draw slider border
    ctx.stroke_color = {80, 80, 90, 255}
    ctx.line_width = 1
    ctx:begin_path()
    ctx:rect(x, margin, slider_width, slider_height)
    ctx:stroke()
    
    -- Draw harmonic number at bottom (simple line representation)
    ctx.stroke_color = {150, 150, 150, 255}
    ctx.line_width = 1
    local text_y = h - margin + 2
    
    -- Draw simple number representation using lines
    if i <= 9 then
      -- Single digit - draw vertical lines
      for j = 1, i do
        local line_x = x + j * (slider_width / (i + 1))
        ctx:begin_path()
        ctx:move_to(line_x, text_y)
        ctx:line_to(line_x, text_y + 4)
        ctx:stroke()
      end
    else
      -- Two digits (10, 11) - draw as "1" + dots
      ctx:begin_path()
      ctx:move_to(x + 2, text_y)
      ctx:line_to(x + 2, text_y + 4)
      ctx:stroke()
      
      -- Add dots for tens
      local dots = i - 9
      for j = 1, dots do
        local dot_x = x + 4 + j * 2
        ctx:begin_path()
        ctx:move_to(dot_x, text_y + 2)
        ctx:line_to(dot_x, text_y + 2)
        ctx:stroke()
      end
    end
  end
  
  -- Draw mode indicator
  if harmonic_drawbar_mode then
    ctx.fill_color = {0, 255, 0, 100}  -- Green overlay when active
    ctx:fill_rect(0, 0, w, 3)
  else
    -- Draw "Click to activate" indicator when inactive
    ctx.fill_color = {100, 100, 100, 80}  -- Gray overlay when inactive
    ctx:fill_rect(0, 0, w, 3)
    
    -- Draw simple "READY" text using lines
    ctx.stroke_color = {150, 150, 150, 200}
    ctx.line_width = 1
    local text_y = h / 2
    
    -- Draw "R" at left
    ctx:begin_path()
    ctx:move_to(5, text_y - 3)
    ctx:line_to(5, text_y + 3)
    ctx:move_to(5, text_y - 3)
    ctx:line_to(8, text_y - 3)
    ctx:move_to(5, text_y)
    ctx:line_to(7, text_y)
    ctx:move_to(7, text_y)
    ctx:line_to(8, text_y + 3)
    ctx:stroke()
  end
  
  -- Draw mouse cursor if dragging
  if harmonic_mouse_down and harmonic_last_mouse_x >= 0 and harmonic_last_mouse_y >= 0 then
    ctx.stroke_color = {255, 255, 255, 255}
    ctx.line_width = 1
    ctx:begin_path()
    ctx:move_to(harmonic_last_mouse_x, 0)
    ctx:line_to(harmonic_last_mouse_x, h)
    ctx:stroke()
  end
end

-- Handle Harmonic Canvas Mouse Input
function PCMWriterHandleHarmonicMouse(ev)
  local w = 140
  local h = 80
  local margin = 2
  local slider_width = (w - (margin * 12)) / 11
  
  if ev.type == "exit" then
    return
  end
  
  -- Check bounds
  if ev.position.x < 0 or ev.position.x >= w or ev.position.y < 0 or ev.position.y >= h then
    if ev.type == "up" and ev.button ~= "right" then
      harmonic_mouse_down = false
      harmonic_last_mouse_x = -1
      harmonic_last_mouse_y = -1
      if harmonic_canvas then
        harmonic_canvas:update()
      end
    end
    return
  end
  
  local x = ev.position.x
  local y = ev.position.y
  
  harmonic_last_mouse_x = x
  harmonic_last_mouse_y = y
  
  if ev.type == "down" then
    if ev.button == "right" then
      -- Right-click: Zero out the clicked slider
      local slider_index = math.floor((x - margin) / (slider_width + margin)) + 1
      slider_index = math.max(1, math.min(11, slider_index))
      
      print(string.format("HARMONIC: Right-click zeroing H%d", slider_index))
      harmonic_levels[slider_index] = 0.0
      
      -- Auto-enter harmonic mode if not already active
      if not harmonic_drawbar_mode then
        print("HARMONIC: Auto-entering harmonic mode due to right-click")
        PCMWriterEnterHarmonicDrawbarMode()
      end
      
      -- Regenerate harmonics and update displays
      if harmonic_drawbar_mode then
        PCMWriterGenerateHarmonics()
        PCMWriterUpdateAllDisplays()
      end
      
      -- Force canvas update
      if harmonic_canvas then
        harmonic_canvas:update()
      end
      
      renoise.app():show_status(string.format("H%d: Zeroed (right-click)", slider_index))
      
    else
      -- Left-click: Normal drawing behavior
      harmonic_mouse_down = true
      
      -- Auto-enter harmonic drawbar mode when user starts drawing
      if not harmonic_drawbar_mode then
        print("HARMONIC: Auto-entering harmonic mode due to canvas interaction")
        PCMWriterEnterHarmonicDrawbarMode()
      end
      
      PCMWriterUpdateHarmonicSlider(x, y, w, h, margin, slider_width)
    end
  elseif ev.type == "up" then
    -- Only reset mouse state for left-click release
    if ev.button ~= "right" then
      harmonic_mouse_down = false
      harmonic_last_mouse_x = -1
      harmonic_last_mouse_y = -1
    end
  elseif ev.type == "move" and harmonic_mouse_down then
    PCMWriterUpdateHarmonicSlider(x, y, w, h, margin, slider_width)
  end
  
  if harmonic_canvas then
    harmonic_canvas:update()
  end
end

-- Update harmonic slider based on mouse position
function PCMWriterUpdateHarmonicSlider(x, y, w, h, margin, slider_width)
  -- Determine which slider (1-11)
  local slider_index = math.floor((x - margin) / (slider_width + margin)) + 1
  slider_index = math.max(1, math.min(11, slider_index))
  
  -- Calculate level (0.0 to 1.0, inverted Y)
  local slider_height = h - (margin * 2)
  local level = 1.0 - ((y - margin) / slider_height)
  level = math.max(0.0, math.min(1.0, level))
  
  -- Update harmonic level
  harmonic_levels[slider_index] = level
  
  print(string.format("HARMONIC: H%d = %.2f", slider_index, level))
  
  -- Regenerate harmonics immediately
  if harmonic_drawbar_mode then
    PCMWriterGenerateHarmonics()
    PCMWriterUpdateAllDisplays()
  end
  
  -- Force canvas update
  if harmonic_canvas then
    print("HARMONIC: Force updating canvas after slider change")
    harmonic_canvas:update()
  else
    print("HARMONIC: ERROR - Cannot update canvas, harmonic_canvas is nil")
  end
  
  renoise.app():show_status(string.format("H%d: %.1f%%", slider_index, level * 100))
end

renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti Gadgets:Paketti Single Cycle Waveform Writer...",invoke = PCMWriterShowPcmDialog}
renoise.tool():add_menu_entry{name = "--Main Menu:Tools:Paketti:Xperimental/WIP:Load 2 Random AKWF as 12st_WT Wavetable",invoke = PCMWriterSafeAKWFWavetableExport}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti Gadgets:Paketti Single Cycle Waveform Writer...",invoke = PCMWriterShowPcmDialog}
renoise.tool():add_menu_entry{name = "Sample Editor:Paketti Gadgets:Load 2 Random AKWF as 12st_WT Wavetable",invoke = PCMWriterSafeAKWFWavetableExport}
renoise.tool():add_keybinding{name = "Global:Paketti:Show Paketti Single Cycle Waveform Writer...",invoke = PCMWriterShowPcmDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Write AKWF A&B to 12st_WT Wavetable",invoke = PCMWriterSafeAKWFWavetableExport}
