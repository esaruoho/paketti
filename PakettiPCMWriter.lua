local vb = renoise.ViewBuilder()
local DIALOG_TITLE = "Paketti Single Cycle Waveform Writer"

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
  if #wavetable_waves == 0 then
    renoise.app():show_status("No waves in wavetable to export")
    return
  end
  
  local song = renoise.song()
  local inst = song.selected_instrument
  
  -- Check if instrument has samples or plugins, if so create new instrument
  if #inst.samples > 0 or inst.plugin_properties.plugin_loaded then
    song:insert_instrument_at(song.selected_instrument_index + 1)
    song.selected_instrument_index = song.selected_instrument_index + 1
    inst = song.selected_instrument
    -- Apply Paketti default instrument configuration
    pakettiPreferencesDefaultInstrumentLoader()
  end
  
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
    sample.name = string.format("PCM Wave %02d (%d frames)", wave_idx, wave_size)
    
    -- Enable loop mode for each sample
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
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
  end
  
  inst.name = string.format("PCM Wavetable (%d waves, %d frames) + Auto-Pitch", #wavetable_waves, wave_size)
  
  -- Select the first sample
  song.selected_sample_index = 1
  
  renoise.app():show_status(string.format("Wavetable exported: %d waves as separate sample slots with %s interpolation, auto-pitch correction", #wavetable_waves, sample_interpolation_mode))
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
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
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
end

function PCMWriterCreate12ChebyshevInstrument()
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
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
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
  
  -- Enable loop mode (forward loop) and set loop points
  sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
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
  
  -- Remove all placeholder samples if they exist
  PCMWriterRemovePlaceholderSamples(inst, sample_slot)
  
  print("DEBUG: Export completed successfully")
  renoise.app():show_status(string.format("Crossfaded wave exported (X%.0f%%) with %s interpolation, oversampling %s, auto-pitch correction", crossfade_amount * 100, sample_interpolation_mode, sample_oversample_enabled and "enabled" or "disabled"))
end

function PCMWriterRandomExportToSlot()
  -- Generate a random waveform first
  PCMWriterGenerateRandomWaveform()
  
  -- Then export it to a sample slot
  PCMWriterExportToSample()
  
  renoise.app():show_status("Random waveform generated and exported to sample slot")
end

function PCMWriterExportWaveAToSample()
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
  sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
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
  
  -- Remove all placeholder samples if they exist
  PCMWriterRemovePlaceholderSamples(inst, sample_slot)
  
  renoise.app():show_status(string.format("Wave A exported with %s interpolation, oversampling %s, auto-pitch correction", sample_interpolation_mode, sample_oversample_enabled and "enabled" or "disabled"))
end

function PCMWriterExportWaveBToSample()
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
  sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
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
  
  -- Remove all placeholder samples if they exist
  PCMWriterRemovePlaceholderSamples(inst, sample_slot)
  
  renoise.app():show_status(string.format("Wave B exported with %s interpolation, oversampling %s, auto-pitch correction", sample_interpolation_mode, sample_oversample_enabled and "enabled" or "disabled"))
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

-- Live Pickup Mode - Load current sample into editor
local live_pickup_mode = false
local live_pickup_sample = nil
local live_pickup_instrument = nil
local live_pickup_sample_index = -1
local live_pickup_instrument_index = -1

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
  
  -- Load the new sample into the PCM Writer
  print("-- Live Pickup Mode: Auto-loading new sample: " .. new_sample.name)
  PCMWriterLoadSampleToWaveform()
  
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
    sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
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
    
    renoise.app():show_status("Live Pickup Mode: No samples found, created new " .. wave_size .. " frame sample for live editing (Wave " .. current_wave_edit .. "). Start drawing!")
    
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
  
  -- Load sample data into currently selected wave
  for i = 1, num_frames do
    local sample_value = buffer:sample_data(1, i)  -- Assuming mono
    -- Convert from -1..1 to 0..65535
    local converted_value = math.floor((sample_value + 1) * 32767.5)
    converted_value = math.max(0, math.min(65535, converted_value))
    
    if current_wave_edit == "A" then
      -- Load into Wave A, set Wave B to silence
      wave_data_a[i] = converted_value
      wave_data_b[i] = 32768
    else
      -- Load into Wave B, set Wave A to silence
      wave_data_b[i] = converted_value
      wave_data_a[i] = 32768
    end
  end
  
  -- Set crossfade to show the loaded wave
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
  
  -- Rebuild dialog if needed to show new wave size
  if pcm_dialog then
    pcm_dialog:close()
    PCMWriterShowPcmDialog()
  end
  
  renoise.app():show_status("Live Pickup Mode: Loaded " .. num_frames .. " frame sample for live editing (Wave " .. current_wave_edit .. ")")
  
  -- Focus back to sample editor
  --   renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

function PCMWriterUpdateLiveSample()
  if not live_pickup_mode or not live_pickup_sample then
    return
  end
  
  -- Protected call to handle any sample access errors gracefully
  local success, error_msg = pcall(function()
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
  
  -- Load hex editor visibility preference
  if preferences and preferences.singlewaveformwriterhex then
    hide_hex_editor = not preferences.singlewaveformwriterhex.value
  end
  
  -- Set flag to prevent dropdown from triggering during rebuild
  dialog_rebuilding = true
  
  -- Create fresh ViewBuilder instance to avoid ID conflicts
  local vb = renoise.ViewBuilder()
  
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
      vb:checkbox{
        value = hide_hex_editor,
        notifier = function(value)
          hide_hex_editor = value
          -- Save preference (inverted because checkbox is "Hide Hex")
          if preferences and preferences.singlewaveformwriterhex then
            preferences.singlewaveformwriterhex.value = not value
          end
          -- Rebuild dialog to show/hide hex editor
          if pcm_dialog then
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
          renoise.app():show_status("Now editing Wave A")
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
          renoise.app():show_status("Now editing Wave B")
        end,
        id = "edit_b_btn"
      },
      vb:text{ text = "Crossfade:", style = "normal" },
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
      }
    }, -- WAVE_AB_ROW ENDS
    
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
      } -- WAVETABLE_COLUMN ENDS
    } -- TOOLS_ALIGNER ENDS
  } -- DIALOG_CONTENT ENDS


  
  pcm_dialog = renoise.app():show_custom_dialog(DIALOG_TITLE, dialog_content, PCMWriterHandleKeyboard)
  
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





renoise.tool():add_menu_entry{name = "--Main Menu:Tools:Paketti:Xperimental/Work in Progress:Paketti Single Cycle Waveform Writer...",invoke = PCMWriterShowPcmDialog}
renoise.tool():add_menu_entry{name = "--Sample Editor:Paketti Gadgets:Paketti Single Cycle Waveform Writer...",invoke = PCMWriterShowPcmDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Show Paketti Single Cycle Waveform Writer...",invoke = PCMWriterShowPcmDialog}

