local dialog=nil

-- =========================================
-- ORIGINAL ALGORITHM (Simple/Fast)
-- =========================================
local function log2(x) return math.log(x)/math.log(2) end
local function midi2freq(x) return 440*(2^((x-69)/12)) end
local function freq2midi(x) return 69+(12*log2(x/440)) end

local function round(x)
  if x>=0 then return math.floor(x+0.5)
  else return math.ceil(x-0.5) end
end

local function get_note_letter(x)
  local note = round(x)
  -- MIDI note 60 is middle C (C4)
  -- Calculate octave based on this reference point
  local octave = math.floor((note - 12) / 12)
  local letters = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
  -- Get the note name from the letters table
  local note_name = letters[(note % 12) + 1]
  -- Format the octave number without the minus sign
  return note_name .. math.abs(octave)
end

-- =========================================
-- ENHANCED ALGORITHM (Whodis-based/Precise)
-- =========================================
local function enhanced_frequency_to_note_analysis(frequency)
  local A4 = 440.0
  local A4_INDEX = 57
  
  -- Full MIDI range C0-B9
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

-- =========================================
-- ANALYSIS FUNCTION (with algorithm selection)
-- =========================================
function analyze_sample(cycles)
  local s=renoise.song()
  local smp=s.selected_sample
  local buf=smp.sample_buffer
  if not buf.has_sample_data then return nil,"No sample data." end
  local sel_start=buf.selection_start
  local sel_end=buf.selection_end
  if sel_end<=sel_start then return nil,"Invalid selection." end
  local frames=1+(sel_end-sel_start)
  local rate=buf.sample_rate
  local freq=rate/(frames/cycles)
  
  -- Check if enhanced algorithm is enabled (with fallback to original)
  local use_enhanced = false
  if preferences and preferences.pakettiRePitchEnhanced ~= nil then
    use_enhanced = preferences.pakettiRePitchEnhanced
  end
  
  if use_enhanced then
    -- Use enhanced whodis-based algorithm
    local enhanced_result = enhanced_frequency_to_note_analysis(freq)
    return {
      frames=frames,
      freq=freq,
      midi=enhanced_result.midi_note + 12, -- Convert to standard MIDI system (C4=60)
      nearest=enhanced_result.midi_note + 12,
      cents=enhanced_result.cents,
      letter=enhanced_result.note_name,
      algorithm="Enhanced",
      cent_direction=enhanced_result.side == 0 and "minus" or "plus"
    }
  else
    -- Use original simple algorithm
    local midi=freq2midi(freq)
    local nearest=round(midi)
    local cents=(nearest-midi)*100
    return {
      frames=frames,
      freq=freq,
      midi=midi,
      nearest=nearest,
      cents=cents,
      letter=get_note_letter(midi),
      algorithm="Original"
    }
  end
end

-- =========================================
-- BATCH ANALYSIS FUNCTIONS
-- =========================================

local function batch_analyze_instrument(cycles)
  local song = renoise.song()
  local instrument = song.selected_instrument
  local results = {
    samples = {},
    total_samples = 0,
    needs_tuning = 0,
    well_tuned = 0
  }
  
  if not instrument or #instrument.samples == 0 then
    return results
  end
  
  local original_sample_index = song.selected_sample_index
  
  for i = 1, #instrument.samples do
    local sample = instrument.samples[i]
    if sample.sample_buffer.has_sample_data then
      -- Select this sample for analysis
      song.selected_sample_index = i
      
      -- Analyze the entire sample (use full length as selection)
      local buf = sample.sample_buffer
      local original_sel_start = buf.selection_start
      local original_sel_end = buf.selection_end
      
      -- Set selection to entire sample
      buf.selection_start = 1
      buf.selection_end = buf.number_of_frames
      
      -- Perform analysis
      local analysis, err = analyze_sample(cycles)
      
      -- Restore original selection
      buf.selection_start = original_sel_start
      buf.selection_end = original_sel_end
      
      if analysis then
        results.total_samples = results.total_samples + 1
        local cents_deviation = math.abs(analysis.cents)
        
        if cents_deviation > 2 then
          results.needs_tuning = results.needs_tuning + 1
        else
          results.well_tuned = results.well_tuned + 1
        end
        
        table.insert(results.samples, {
          index = i,
          name = sample.name,
          analysis = analysis,
          needs_tuning = cents_deviation > 2
        })
        
        print(string.format("-- Batch Analysis: Sample %d (%s): %s, %s cents", 
          i, sample.name, analysis.letter, 
          analysis.cent_direction and 
            (analysis.cent_direction .. " " .. math.abs(analysis.cents)) or 
            string.format("%.2f", analysis.cents)))
      else
        print(string.format("-- Batch Analysis: Sample %d (%s): Analysis failed - %s", 
          i, sample.name, err or "unknown error"))
      end
    end
  end
  
  -- Restore original sample selection
  song.selected_sample_index = original_sample_index
  
  return results
end

local function set_pitch(data)
  local smp=renoise.song().selected_sample
  local diff=round(data.midi)-60
  -- Clamp transpose to valid range (-120 to 120)
  local transpose_value = -diff
  transpose_value = math.max(-120, math.min(120, transpose_value))
  smp.transpose = transpose_value
  
  -- Handle both original and enhanced algorithm cents
  -- We always want to CORRECT the pitch, so negate the detected deviation
  local cents_value = -data.cents  -- Negate to correct the detected deviation
  
  -- Convert cents to fine tune steps (Renoise: -128 to 127 = 255 steps for 200 cents)
  local fine_tune_steps = round(cents_value * 1.275)  -- Scale: 255 steps / 200 cents = 1.275
  -- Clamp to valid range (-128 to 127)
  fine_tune_steps = math.max(-128, math.min(127, fine_tune_steps))
  smp.fine_tune = fine_tune_steps
  
  -- Show feedback about what was set
  local status = string.format("Set transpose: %d, fine tune: %d (%s algorithm)", 
    transpose_value, fine_tune_steps, data.algorithm or "Unknown")
  renoise.app():show_status(status)
  print("-- Paketti RePitch: " .. status)
  print("-- Paketti RePitch Debug: detected cents = " .. tostring(data.cents) .. 
        ", correction cents = " .. tostring(cents_value) .. 
        ", fine_tune steps = " .. tostring(fine_tune_steps))
end

function pakettiSimpleSampleTuningDialog()
  if dialog and dialog.visible then dialog:close() return end
  local vb=renoise.ViewBuilder()
  local analysis = nil
  local batch_results = {}
  local txt=vb:text{
    width=350,
    text="Note: \nFinetune: \nMIDI: \nAlgorithm: "
  }
  
  -- Function to update algorithm switch
  local function update_algorithm_switch()
    local use_enhanced = preferences and preferences.pakettiRePitchEnhanced or false
    vb.views.algorithm_switch.value = use_enhanced and 2 or 1
  end
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog=renoise.app():show_custom_dialog(
    "Paketti Simple Sample Tuning Calculator",
    vb:column{
      margin=10,
      vb:row{
        vb:text{text="Algorithm:",width=80, font="bold",style="strong"},
        vb:switch{
          items={"Original","Enhanced"},
          value=1,
          width=120,
          id="algorithm_switch",
          notifier=function(value)
            if preferences then
              preferences.pakettiRePitchEnhanced = (value == 2)
              local algorithm_name = preferences.pakettiRePitchEnhanced and "Enhanced" or "Original"
              renoise.app():show_status("Algorithm switched to " .. algorithm_name)
              
              -- Auto-recalculate if we have valid cycles
              local cycles_text = vb.views.cycles.text
              local cycles = tonumber(cycles_text)
              if cycles and cycles > 0 then
                local res, err = analyze_sample(cycles)
                if res then
                  analysis = res
                  
                  -- Update display with new algorithm results
                  local display_text = "Note: "..res.letter.." ("..string.format("%.2f",res.freq).." Hz)"
                  
                  if res.cent_direction then
                    -- Enhanced algorithm with directional cents
                    display_text = display_text .. 
                      "\nFinetune: " .. res.cent_direction .. " " .. string.format("%.0f",math.abs(res.cents)) .. " cents"
                  else
                    -- Original algorithm
                    display_text = display_text .. 
                      "\nFinetune: "..string.format("%.2f",res.cents).." cents"
                  end
                  
                  display_text = display_text .. 
                    "\nMIDI: "..string.format("%.2f",res.midi) ..
                    "\nAlgorithm: " .. (res.algorithm or "Unknown")
                    
                  txt.text = display_text
                else
                  -- Clear analysis if recalculation failed
                  analysis = nil
                  txt.text = "Note: \nFinetune: \nMIDI: \nAlgorithm: "
                end
              else
                -- Clear previous analysis if no valid cycles
                analysis = nil
                txt.text = "Note: \nFinetune: \nMIDI: \nAlgorithm: "
              end
            end
          end
        }
      },
      vb:row{
        vb:text{text="Cycles", width=80,style="strong",font="bold"},
        vb:textfield{
          width=40,
          text="1",
          id="cycles"
        },
        vb:button{
          text="Calculate",
          notifier=function()
            local cycles=tonumber(vb.views.cycles.text)
            if not cycles or cycles<=0 then
              renoise.app():show_status("Enter valid number of cycles.")
              return
            end
            
            local is_batch = vb.views.batch_checkbox.value
            if is_batch then
              -- Batch process all samples in instrument
              batch_results = batch_analyze_instrument(cycles)
              if batch_results.total_samples > 0 then
                analysis = nil  -- Clear single analysis
                local summary = string.format("Batch Analysis Complete:\n%d samples analyzed\n%d need tuning (>2 cents)\n%d already well-tuned", 
                  batch_results.total_samples, batch_results.needs_tuning, batch_results.well_tuned)
                
                -- Add details about samples that need tuning
                if batch_results.needs_tuning > 0 then
                  summary = summary .. "\n\nSamples needing tuning:"
                  for _, sample_result in ipairs(batch_results.samples) do
                    if sample_result.needs_tuning then
                      local cents_text = sample_result.analysis.cent_direction and 
                        (sample_result.analysis.cent_direction .. " " .. math.abs(sample_result.analysis.cents)) or
                        string.format("%.1f", sample_result.analysis.cents)
                      summary = summary .. string.format("\n%d. %s: %s (%s cents)", 
                        sample_result.index, sample_result.name, sample_result.analysis.letter, cents_text)
                    end
                  end
                end
                
                txt.text = summary
              else
                txt.text = "No samples found in instrument"
              end
            else
              -- Single sample analysis
              local res,err=analyze_sample(cycles)
              if not res then
                renoise.app():show_status(err)
                return
              end
              analysis=res
              batch_results = {}  -- Clear batch results
              
              -- Enhanced display for new algorithm
              local display_text = "Note: "..res.letter.." ("..string.format("%.2f",res.freq).." Hz)"
              
              if res.cent_direction then
                -- Enhanced algorithm with directional cents
                display_text = display_text .. 
                  "\nFinetune: " .. res.cent_direction .. " " .. string.format("%.0f",math.abs(res.cents)) .. " cents"
              else
                -- Original algorithm
                display_text = display_text .. 
                  "\nFinetune: "..string.format("%.2f",res.cents).." cents"
              end
              
              display_text = display_text .. 
                "\nMIDI: "..string.format("%.2f",res.midi) ..
                "\nAlgorithm: " .. (res.algorithm or "Unknown")
                
              txt.text = display_text
            end
          end
        }
      },
      vb:row{
        vb:checkbox{
          value=false,
          id="batch_checkbox"
        },
        vb:text{text="Batch / All Samples in Instrument",style="strong"}
      },
      vb:row{txt},
      vb:row{
        vb:button{
          text="Set Pitch",
          id="set_pitch_button",
          notifier=function()
            local is_batch = vb.views.batch_checkbox.value
            
            if is_batch then
              -- Batch mode: automatically analyze all samples and apply corrections
              local cycles = tonumber(vb.views.cycles.text)
              if not cycles or cycles <= 0 then
                renoise.app():show_status("Enter valid number of cycles.")
                return
              end
              
              -- Run batch analysis
              renoise.app():show_status("Analyzing all samples...")
              batch_results = batch_analyze_instrument(cycles)
              
              if batch_results.total_samples == 0 then
                renoise.app():show_status("No samples found in instrument.")
                return
              end
              
              -- Apply corrections to samples that need tuning
              local song = renoise.song()
              local original_sample_index = song.selected_sample_index
              local corrected_count = 0
              local skipped_count = 0
              
              for _, sample_result in ipairs(batch_results.samples) do
                if sample_result.needs_tuning then
                  -- Select the sample and apply correction
                  song.selected_sample_index = sample_result.index
                  set_pitch(sample_result.analysis)
                  corrected_count = corrected_count + 1
                  print(string.format("-- Batch Correction: Applied to sample %d (%s)", 
                    sample_result.index, sample_result.name))
                else
                  skipped_count = skipped_count + 1
                end
              end
              
              -- Restore original sample selection
              song.selected_sample_index = original_sample_index
              
              local status = string.format("Batch Complete: %d samples corrected, %d skipped (well-tuned)", 
                corrected_count, skipped_count)
              renoise.app():show_status(status)
              print("-- Paketti RePitch: " .. status)
              
              -- Update display with batch results
              local summary = string.format("Batch Complete:\n%d samples analyzed\n%d corrected\n%d skipped (well-tuned)", 
                batch_results.total_samples, corrected_count, skipped_count)
              txt.text = summary
              
            else
              -- Single sample pitch correction
              if not analysis then
                renoise.app():show_status("Click 'Calculate' first to analyze the current sample.")
                return
              end
              
              -- Check if sample is actually close to standard pitch (within ±2 cents)
              local cents_deviation = math.abs(analysis.cents)
              if cents_deviation <= 2 then
                renoise.app():show_status("Sample is already well-tuned (within ±2 cents).")
                return
              end
              
              set_pitch(analysis)
              renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
            end
          end
        },
        vb:button{
          text="Close",
          notifier=function() dialog:close() end
        }
      }
    },
    keyhandler
  )
  
  -- Initialize the algorithm switch
  update_algorithm_switch()
end

-- =========================================
-- MENU ENTRIES & KEYBINDINGS
-- =========================================

-- Function to toggle algorithm preference from menu
function pakettiRePitchToggleAlgorithm()
  if preferences then
    preferences.pakettiRePitchEnhanced = not preferences.pakettiRePitchEnhanced
    local algorithm_name = preferences.pakettiRePitchEnhanced and "Enhanced (Whodis-based)" or "Original (Simple)"
    renoise.app():show_status("Paketti RePitch Algorithm: " .. algorithm_name)
    print("-- Paketti RePitch: Algorithm switched to " .. algorithm_name)
  else
    renoise.app():show_warning("Preferences not available")
  end
end

-- Check if algorithm is enhanced (for menu checkmark)
function pakettiRePitchIsEnhanced()
  return preferences and preferences.pakettiRePitchEnhanced or false
end

-- Menu entries
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Sample:Pitch Analysis Algorithm:Enhanced (Whodis-based)",
  invoke = function() 
    if preferences then 
      preferences.pakettiRePitchEnhanced = true
      renoise.app():show_status("Paketti RePitch: Enhanced algorithm enabled")
    end
  end,
  selected = function() return pakettiRePitchIsEnhanced() end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti:Sample:Pitch Analysis Algorithm:Original (Simple)",
  invoke = function() 
    if preferences then 
      preferences.pakettiRePitchEnhanced = false
      renoise.app():show_status("Paketti RePitch: Original algorithm enabled")
    end
  end,
  selected = function() return not pakettiRePitchIsEnhanced() end
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:Paketti:Pitch Analysis Algorithm:Toggle Enhanced/Original",
  invoke = pakettiRePitchToggleAlgorithm
}

-- Keybindings
renoise.tool():add_keybinding{
  name = "Global:Paketti:Toggle RePitch Algorithm (Enhanced/Original)",
  invoke = pakettiRePitchToggleAlgorithm
}

-- MIDI mapping
renoise.tool():add_midi_mapping{
  name = "Paketti:Toggle RePitch Algorithm",
  invoke = function(message) 
    if message:is_trigger() then 
      pakettiRePitchToggleAlgorithm() 
    end 
  end
}



