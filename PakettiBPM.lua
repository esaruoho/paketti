local vb = renoise.ViewBuilder()
local dialog

function pakettiBPMMSCalculator()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  local song = renoise.song()
  local bpm = song.transport.bpm

  local function msPerFraction(frac)
    return math.floor((60000 / bpm) * frac + 0.5)
  end

  local text_views = {}

  local note_factors = {
    {div=1, label="1/1"}, {div=2, label="1/2"}, {div=4, label="1/4"}, {div=8, label="1/8"},
    {div=16, label="1/16"}, {div=32, label="1/32"}, {div=64, label="1/64"}, {div=128, label="1/128"}
  }

  local original_labels = {
    {id="whole_note", label="Whole-note delay (1/1)", frac=4.0},
    {id="whole_note_dotted", label="Whole-note dotted", frac=4.0 * 1.5},
    {id="whole_note_triplet", label="Whole-note triplet", frac=4.0 * 2/3},
    {id="half_note", label="Half-note delay (1/2)", frac=2.0},
    {id="half_note_dotted", label="Half-note dotted", frac=2.0 * 1.5},
    {id="half_note_triplet", label="Half-note triplet", frac=2.0 * 2/3},
    {id="quarter_note", label="Quarter-note delay (1/4)", frac=1.0},
    {id="quarter_note_dotted", label="Quarter-note dotted", frac=1.0 * 1.5},
    {id="quarter_note_triplet", label="Quarter-note triplet", frac=2/3},
    {id="eighth_note", label="Eighth-note delay (1/8)", frac=0.5},
    {id="eighth_note_dotted", label="Eighth-note dotted", frac=0.5 * 1.5},
    {id="eighth_note_triplet", label="Eighth-note triplet", frac=1/3},
    {id="sixteenth_note", label="Sixteenth-note delay (1/16)", frac=0.25},
    {id="sixteenth_note_dotted", label="Sixteenth-note dotted", frac=0.25 * 1.5},
    {id="sixteenth_note_triplet", label="Sixteenth-note triplet", frac=1/6},
    {id="three_sixteenth", label="3/16-note delay", frac=0.75}
  }

  for _, entry in ipairs(original_labels) do
    text_views[entry.id] = vb:text{ text = "", font = "bold", style = "strong", width = 80 }
  end

  for _, item in ipairs(note_factors) do
    local base = 1 / item.div
    text_views[item.label.." Even"] = vb:text{ text = "", font = "bold", style = "strong", width = 80 }
    text_views[item.label.." Dotted"] = vb:text{ text = "", font = "bold", style = "strong", width = 80 }
    text_views[item.label.." Triplet"] = vb:text{ text = "", font = "bold", style = "strong", width = 80 }
  end

  local function updateDelayTexts()
    for _, entry in ipairs(original_labels) do
      text_views[entry.id].text = string.format("%d ms", msPerFraction(entry.frac))
    end
    for _, item in ipairs(note_factors) do
      local base = 1 / item.div
      text_views[item.label.." Even"].text = string.format("%d ms", msPerFraction(base))
      text_views[item.label.." Dotted"].text = string.format("%d ms", msPerFraction(base * 1.5))
      text_views[item.label.." Triplet"].text = string.format("%d ms", msPerFraction(base * 2/3))
    end
  end

  local function buildContent()
    local rows = {}

    table.insert(rows, vb:row {
      vb:text{ text = "Tempo", font = "bold", style = "strong" },
      vb:valuebox {
        value = bpm, min = 20, max = 999,
        notifier=function(val)
          bpm = val
          updateDelayTexts()
        end
      },
      vb:text{ text = "BPM", font = "bold", style = "strong" }
    })

    table.insert(rows, vb:space{ height = 8 })
    table.insert(rows, vb:text{ text = "Base Note Delays", font = "bold", style = "strong" })

    for _, entry in ipairs(original_labels) do
      table.insert(rows, vb:row {
        vb:text{ text = entry.label, font = "bold", style = "strong", width = 150 },
        text_views[entry.id]
      })
    end

    table.insert(rows, vb:space{ height = 8 })
    table.insert(rows, vb:text{ text = "Extended Delay Times", font = "bold", style = "strong" })

    for _, item in ipairs(note_factors) do
      table.insert(rows, vb:row {
        vb:text{ text = item.label.." Even", font = "bold", style = "strong", width = 150 },
        text_views[item.label.." Even"]
      })
      table.insert(rows, vb:row {
        vb:text{ text = item.label.." Dotted", font = "bold", style = "strong", width = 150 },
        text_views[item.label.." Dotted"]
      })
      table.insert(rows, vb:row {
        vb:text{ text = item.label.." Triplet", font = "bold", style = "strong", width = 150 },
        text_views[item.label.." Triplet"]
      })
    end

    updateDelayTexts()

    return vb:column { margin = 5, unpack(rows) }
  end

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti BPM to MS Delay Calculator Dialog", buildContent(), keyhandler)
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti BPM to MS Delay Calculator Dialog...", invoke = pakettiBPMMSCalculator}

-- CONSOLIDATED BPM DETECTION KEYBINDINGS & MENU ENTRIES (moved from PakettiRender.lua)

-- Basic BPM analysis keybindings  
renoise.tool():add_keybinding{name="Global:Paketti:Analyze Sample BPM (4 beats)", invoke = pakettiBPMTestCalculation}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Analyze Sample BPM (4 beats)", invoke = pakettiBPMTestCalculation}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Analyze Sample BPM (1 beat)", invoke = function() 
    local bpm = pakettiBPMAnalyzeSample(1)
    if bpm then renoise.app():show_status("Sample BPM (1 beat): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Analyze Sample BPM (2 beats)", invoke = function() 
    local bpm = pakettiBPMAnalyzeSample(2)
    if bpm then renoise.app():show_status("Sample BPM (2 beats): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Analyze Sample BPM (8 beats)", invoke = function() 
    local bpm = pakettiBPMAnalyzeSample(8)
    if bpm then renoise.app():show_status("Sample BPM (8 beats): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Analyze Sample BPM (16 beats)", invoke = function() 
    local bpm = pakettiBPMAnalyzeSample(16)
    if bpm then renoise.app():show_status("Sample BPM (16 beats): " .. string.format("%.1f", bpm)) end
end}

-- Intelligent BPM detection keybinding
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Intelligent BPM Detection", invoke = function() 
    local song = renoise.song()
    if not song.selected_sample or not song.selected_sample.sample_buffer or not song.selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample has no data")
        return
    end
    
    local sample_buffer = song.selected_sample.sample_buffer
    local detected_bpm, beat_count = pakettiBPMDetectFromSample(sample_buffer.number_of_frames, sample_buffer.sample_rate)
    renoise.app():show_status(string.format("Intelligent Detection: %.1f BPM (%d beats)", detected_bpm, beat_count))
end}

-- Sample Editor menu entries
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Analyze Sample BPM (4 beats)", invoke = pakettiBPMTestCalculation}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Analyze Sample BPM (1 beat)", invoke = function() 
    local bpm = pakettiBPMAnalyzeSample(1)
    if bpm then renoise.app():show_status("Sample BPM (1 beat): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Analyze Sample BPM (8 beats)", invoke = function() 
    local bpm = pakettiBPMAnalyzeSample(8)
    if bpm then renoise.app():show_status("Sample BPM (8 beats): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Intelligent BPM Detection", invoke = function() 
    local song = renoise.song()
    if not song.selected_sample or not song.selected_sample.sample_buffer or not song.selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample has no data")
        return
    end
    
    local sample_buffer = song.selected_sample.sample_buffer
    local detected_bpm, beat_count = pakettiBPMDetectFromSample(sample_buffer.number_of_frames, sample_buffer.sample_rate)
    renoise.app():show_status(string.format("Intelligent Detection: %.1f BPM (%d beats)", detected_bpm, beat_count))
end}

-- Sample Editor Ruler menu entries
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Paketti:Analyze Sample BPM (1 beat)", invoke = function() 
    local bpm = pakettiBPMAnalyzeSample(1)
    if bpm then renoise.app():show_status("Sample BPM (1 beat): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Paketti:Analyze Sample BPM (2 beats)", invoke = function() 
    local bpm = pakettiBPMAnalyzeSample(2)
    if bpm then renoise.app():show_status("Sample BPM (2 beats): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Paketti:Analyze Sample BPM (4 beats)", invoke = pakettiBPMTestCalculation}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Paketti:Analyze Sample BPM (8 beats)", invoke = function() 
    local bpm = pakettiBPMAnalyzeSample(8)
    if bpm then renoise.app():show_status("Sample BPM (8 beats): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Paketti:Analyze Sample BPM (16 beats)", invoke = function() 
    local bpm = pakettiBPMAnalyzeSample(16)
    if bpm then renoise.app():show_status("Sample BPM (16 beats): " .. string.format("%.1f", bpm)) end
end}
renoise.tool():add_menu_entry{name="Sample Editor Ruler:Paketti:Intelligent BPM Detection", invoke = function() 
    local song = renoise.song()
    if not song.selected_sample or not song.selected_sample.sample_buffer or not song.selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample has no data")
        return
    end
    
    local sample_buffer = song.selected_sample.sample_buffer
    local detected_bpm, beat_count = pakettiBPMDetectFromSample(sample_buffer.number_of_frames, sample_buffer.sample_rate)
    renoise.app():show_status(string.format("Intelligent Detection: %.1f BPM (%d beats)", detected_bpm, beat_count))
end}



-----------

-- CONSOLIDATED BPM DETECTION & ANALYSIS FUNCTIONS
-- Moved from PakettiRender.lua, PakettiOldschoolSlicePitch.lua, PakettiPitchControl.lua, PakettiSandbox.lua

-- Basic BPM calculation from sample data (from PakettiRender.lua)
function pakettiBPMCountFromSample(sample_length_frames, sample_rate, beats_in_sample)
    -- Calculate sample length in seconds
    -- samples / samplerate = time
    local time_in_seconds = sample_length_frames / sample_rate
    
    -- Calculate time per beat
    -- time / beats = time factor (time per beat)
    local time_per_beat = time_in_seconds / beats_in_sample
    
    -- Calculate BPM
    -- 60 / time factor = bpm
    local bpm = 60 / time_per_beat
    
    print("DEBUG BPM: Sample length:", sample_length_frames, "frames")
    print("DEBUG BPM: Sample rate:", sample_rate, "Hz") 
    print("DEBUG BPM: Time in seconds:", time_in_seconds)
    print("DEBUG BPM: Beats in sample:", beats_in_sample)
    print("DEBUG BPM: Time per beat:", time_per_beat, "seconds")
    print("DEBUG BPM: Calculated BPM:", bpm)
    
    return bpm
end

-- Test function that analyzes the currently selected sample (from PakettiRender.lua)
function pakettiBPMTestCalculation()
    local song = renoise.song()
    
    -- Check if we have a selected sample
    if not song.selected_sample or not song.selected_sample.sample_buffer or not song.selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample has no data")
        return
    end
    
    local sample = song.selected_sample
    local sample_buffer = sample.sample_buffer
    
    -- Get real sample data from Renoise
    local sample_length_frames = sample_buffer.number_of_frames
    local sample_rate = sample_buffer.sample_rate
    local bit_depth = sample_buffer.bit_depth or 16
    local num_channels = sample_buffer.number_of_channels
    
    -- Calculate sample length in seconds
    local sample_length_seconds = sample_length_frames / sample_rate
    
    print("=== REAL SAMPLE ANALYSIS ===")
    print("Sample name:", sample.name)
    print("Sample length:", sample_length_frames, "frames")
    print("Sample rate:", sample_rate, "Hz")
    print("Bit depth:", bit_depth, "bits")
    print("Channels:", num_channels)
    print("Duration:", sample_length_seconds, "seconds")
    
    -- Assume it's a 4-beat loop for testing (user can modify this)
    local assumed_beats = 4
    local calculated_bpm = pakettiBPMCountFromSample(sample_length_frames, sample_rate, assumed_beats)
    
    renoise.app():show_status(string.format("Sample: %s | %d frames @ %dHz = %.2fs | Assuming %d beats = %.1f BPM", 
        sample.name, sample_length_frames, sample_rate, sample_length_seconds, assumed_beats, calculated_bpm))
end

-- Function to analyze sample with custom beat count (from PakettiRender.lua)
function pakettiBPMAnalyzeSample(beats_in_sample)
    local song = renoise.song()
    
    if not song.selected_sample or not song.selected_sample.sample_buffer or not song.selected_sample.sample_buffer.has_sample_data then
        renoise.app():show_status("No sample selected or sample has no data")
        return nil
    end
    
    local sample = song.selected_sample
    local sample_buffer = sample.sample_buffer
    
    local sample_length_frames = sample_buffer.number_of_frames
    local sample_rate = sample_buffer.sample_rate
    
    return pakettiBPMCountFromSample(sample_length_frames, sample_rate, beats_in_sample)
end

-- Intelligent BPM detection - finds the beat count that gives reasonable BPM (from PakettiRender.lua)
function pakettiBPMDetectFromSample(sample_length_frames, sample_rate)
    local beat_counts = {1, 2, 4, 8, 16, 32}
    local reasonable_bpm_min = 80
    local reasonable_bpm_max = 180
    
    print("=== INTELLIGENT BPM DETECTION ===")
    print("Sample:", sample_length_frames, "frames @", sample_rate, "Hz")
    
    for _, beat_count in ipairs(beat_counts) do
        local bpm = pakettiBPMCountFromSample(sample_length_frames, sample_rate, beat_count)
        print("Testing", beat_count, "beats:", string.format("%.1f", bpm), "BPM")
        
        if bpm >= reasonable_bpm_min and bpm <= reasonable_bpm_max then
            print("*** FOUND REASONABLE BPM:", string.format("%.1f", bpm), "with", beat_count, "beats ***")
            return bpm, beat_count
        end
    end
    
    -- If no reasonable BPM found, use 4 beats as fallback
    local fallback_bpm = pakettiBPMCountFromSample(sample_length_frames, sample_rate, 4)
    print("No reasonable BPM found, using 4-beat fallback:", string.format("%.1f", fallback_bpm), "BPM")
    return fallback_bpm, 4
end

-- Advanced transient-based BPM detection (from PakettiOldschoolSlicePitch.lua)
function pakettiBPMDetectFromTransients(buffer, estimated_beats)
  estimated_beats = estimated_beats or 4 -- Default assumption
  local frames = buffer.number_of_frames
  local sample_rate = buffer.sample_rate
  local channel = 1
  
  -- BALANCED: Smaller window for accuracy, 25% overlap for speed compromise  
  local window_size = math.floor(sample_rate * 0.025) -- 25ms window (compromise)
  local hop_size = math.floor(window_size * 0.75) -- 25% overlap (vs 50% overlap)
  local energy_threshold = 0.52
  local min_spacing = (150 / 1000) * sample_rate -- 150ms minimum spacing (back to original)
  
  local num_windows = math.floor((frames - window_size) / hop_size) + 1
  
  -- OPTIMIZED: Pre-allocate arrays with known size (vs table.insert)
  local flux_values = {}
  local prev_sum = 0
  local max_energy = 0
  local window_count = 0

  -- OPTIMIZED: Single loop combines flux, energy, and max calculation
  for pos = 1, frames - window_size, hop_size do
    local sum = 0
    local energy = 0
    -- Inner loop optimized with less function calls
    for i = 0, window_size - 1 do
      local val = math.abs(buffer:sample_data(channel, pos + i))
      sum = sum + val
      energy = energy + (val * val) -- Faster than val^2
    end
    
    local flux = math.max(0, sum - prev_sum)
    window_count = window_count + 1
    flux_values[window_count] = { pos = pos, flux = flux, energy = energy }
    
    -- Track max energy in same loop
    if energy > max_energy then 
      max_energy = energy 
    end
    prev_sum = sum
  end

  local local_energy_threshold = max_energy * energy_threshold
  
  -- BALANCED: Use proper median for accuracy, but optimize the sorting
  local fluxes = {}
  for i = 1, window_count do
    fluxes[i] = flux_values[i].flux
  end
  table.sort(fluxes)
  local median_flux = fluxes[math.floor(window_count / 2)]
  local flux_threshold = median_flux * 1.3

  -- ACCURATE: Process all transients (no early termination to preserve accuracy)
  local transients = {}
  local transient_count = 0
  local last_transient = -min_spacing
  
  for i = 1, window_count do
    local v = flux_values[i]
    local spacing = v.pos - last_transient
    if v.flux > flux_threshold and v.energy > local_energy_threshold and spacing > min_spacing then
      transient_count = transient_count + 1
      transients[transient_count] = v.pos
      last_transient = v.pos
    end
  end

  if transient_count < 2 then
    print("Debug: Not enough transients detected, using project BPM")
    return nil
  end

  local sample_duration_secs = frames / sample_rate
  
  -- INTELLIGENT: Analyze timing intervals + use user-specified beats for accuracy
  local intervals = {}
  for i = 2, transient_count do
    local interval_frames = transients[i] - transients[i-1]
    local interval_seconds = interval_frames / sample_rate
    table.insert(intervals, interval_seconds)
  end
  
  local detected_bpm
  
  if #intervals == 0 then
    -- Fallback: use user-specified beats if no intervals
    detected_bpm = (estimated_beats * 60) / sample_duration_secs
  else
    -- Method 1: Use user-specified beats (most accurate when user knows)
    local user_bpm = (estimated_beats * 60) / sample_duration_secs
    
    -- Method 2: Analyze intervals to find subdivision pattern
    table.sort(intervals)
    local median_interval = intervals[math.floor(#intervals / 2)]
    local interval_bpm = 60 / median_interval
    
    -- Test common subdivisions based on user's beat count
    local candidate_bpms = {
      user_bpm,         -- User-specified (most trusted)
      interval_bpm,     -- 1:1 (each transient is a beat)
      interval_bpm / 2, -- 1:2 (every other transient is a beat)  
      interval_bpm / 3, -- 1:3 (triplets)
      interval_bpm / 4, -- 1:4 (every 4th transient is a beat)
      interval_bpm * 2, -- 2:1 (half-time feel)
    }
    
    -- Prefer user BPM, but validate against interval analysis
    detected_bpm = user_bpm
    local best_score = 0 -- Start with user BPM as best
    
    -- Only override user BPM if interval analysis suggests something much more reasonable
    for i, candidate in ipairs(candidate_bpms) do
      if candidate >= 60 and candidate <= 200 then
        local score = 1 / math.abs(candidate - user_bpm) -- Prefer candidates close to user BPM
        if i == 1 then score = score * 2 end -- Boost user BPM preference
        if score > best_score then
          detected_bpm = candidate
          best_score = score
        end
      end
    end
  end
  
  -- Constrain BPM to reasonable range
  if detected_bpm < 30 then
    detected_bpm = detected_bpm * 4
  elseif detected_bpm < 60 then
    detected_bpm = detected_bpm * 2
  elseif detected_bpm > 400 then
    detected_bpm = detected_bpm / 4
  elseif detected_bpm > 200 then
    detected_bpm = detected_bpm / 2
  end

  -- Calculate estimated beat count based on final BPM
  local final_estimated_beats = math.floor((detected_bpm * sample_duration_secs) / 60)
  
  print(string.format("Debug: Detected %d transients, user specified %d beats, calculated BPM: %.2f", transient_count, estimated_beats, detected_bpm))
  return detected_bpm, final_estimated_beats, transients
end

-- BPM MANIPULATION FUNCTIONS (moved from PakettiTkna.lua, PakettiRequests.lua, PakettiEightOneTwenty.lua, etc.)

-- Basic BPM manipulation (from PakettiTkna.lua)
function pakettiBPMHalve()
  local song = renoise.song()
  local current_bpm = song.transport.bpm
  local new_bpm = math.max(current_bpm / 2, 20)
  song.transport.bpm = new_bpm
  renoise.app():show_status("BPM halved from " .. current_bpm .. " to " .. new_bpm)
end

function pakettiBPMDouble()
  local song = renoise.song()
  local current_bpm = song.transport.bpm
  local new_bpm = math.min(current_bpm * 2, 999)
  song.transport.bpm = new_bpm
  renoise.app():show_status("BPM doubled from " .. current_bpm .. " to " .. new_bpm)
end

-- BPM multiplication (from PakettiEightOneTwenty.lua) 
function pakettiBPMMultiply()
  local new_bpm = renoise.song().transport.bpm * 2
  if new_bpm > 999 then new_bpm = 999 end
  renoise.song().transport.bpm = new_bpm
end

-- BPM + LPB combined operations (from PakettiRequests.lua)
function pakettiBPMMultiplyHalveLPB()
  local song = renoise.song()
  local current_bpm = song.transport.bpm
  local current_lpb = song.transport.lpb
  
  -- Check if BPM can be doubled
  if current_bpm * 2 > 999 then
    renoise.app():show_status(string.format(
      "Cannot multiply BPM: %.2f * 2 would exceed maximum of 999", current_bpm))
    return
  end
  
  -- Check if LPB can be halved
  if current_lpb / 2 < 1 then
    renoise.app():show_status(string.format(
      "Cannot halve LPB: %d / 2 would be less than minimum of 1", current_lpb))
    return
  end
  
  -- Apply changes
  song.transport.bpm = current_bpm * 2
  song.transport.lpb = current_lpb / 2
  
  renoise.app():show_status(string.format(
    "BPM: %.2f -> %.2f, LPB: %d -> %d", 
    current_bpm, song.transport.bpm,
    current_lpb, song.transport.lpb))
end

function pakettiBPMHalveMultiplyLPB()
  local song = renoise.song()
  local current_bpm = song.transport.bpm
  local current_lpb = song.transport.lpb
  
  -- Check if BPM can be halved
  if current_bpm / 2 < 20 then
    renoise.app():show_status(string.format(
      "Cannot halve BPM: %.2f / 2 would be less than minimum of 20", current_bpm))
    return
  end
  
  -- Check if LPB can be doubled
  if current_lpb * 2 > 256 then
    renoise.app():show_status(string.format(
      "Cannot multiply LPB: %d * 2 would exceed maximum of 256", current_lpb))
    return
  end
  
  -- Apply changes
  song.transport.bpm = current_bpm / 2
  song.transport.lpb = current_lpb * 2
  
  renoise.app():show_status(string.format(
    "BPM: %.2f -> %.2f, LPB: %d -> %d", 
    current_bpm, song.transport.bpm,
    current_lpb, song.transport.lpb))
end

renoise.tool():add_keybinding{name="Global:Paketti:Halve BPM", invoke = pakettiBPMHalve}
renoise.tool():add_keybinding{name="Global:Paketti:Double BPM", invoke = pakettiBPMDouble}
renoise.tool():add_keybinding{name="Global:Paketti:Halve Halve BPM", invoke = function() pakettiBPMHalve() pakettiBPMHalve() end}
renoise.tool():add_keybinding{name="Global:Paketti:Double Double BPM", invoke = function() pakettiBPMDouble() pakettiBPMDouble() end}
renoise.tool():add_keybinding{name="Global:Paketti:Multiply BPM & Halve LPB", invoke = pakettiBPMMultiplyHalveLPB}
renoise.tool():add_keybinding{name="Global:Paketti:Halve BPM & Multiply LPB", invoke = pakettiBPMHalveMultiplyLPB}
