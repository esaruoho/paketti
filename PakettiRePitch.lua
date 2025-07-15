local dialog=nil

local function round(x)
  if x>=0 then return math.floor(x+0.5)
  else return math.ceil(x-0.5) end
end

-- =========================================
-- FREQUENCY TO NOTE ANALYSIS
-- =========================================
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
-- ANALYSIS FUNCTION
-- =========================================
function analyze_sample(cycles)
  local s=renoise.song()
  if not s then return nil,"No song loaded." end
  
  local smp=s.selected_sample
  if not smp then return nil,"No sample selected." end
  
  local buf=smp.sample_buffer
  if not buf then return nil,"Sample has no buffer." end
  if not buf.has_sample_data then return nil,"No sample data." end
  local sel_start=buf.selection_start
  local sel_end=buf.selection_end
  if sel_end<=sel_start then return nil,"Invalid selection." end
  local frames=1+(sel_end-sel_start)
  local rate=buf.sample_rate
  local freq=rate/(frames/cycles)
  
  -- Use frequency to note analysis
  local result = frequency_to_note_analysis(freq)
  return {
    frames=frames,
    freq=freq,
    midi=result.midi_note + 12, -- Convert to standard MIDI system (C4=60)
    nearest=result.midi_note + 12,
    cents=result.cents,
    letter=result.note_name,
    cent_direction=result.side == 0 and "minus" or "plus"
  }
end

-- =========================================
-- BATCH ANALYSIS FUNCTIONS
-- =========================================

local function batch_analyze_instrument(cycles)
  local song = renoise.song()
  if not song then 
    return {
      samples = {},
      total_samples = 0,
      needs_tuning = 0,
      well_tuned = 0,
      error = "No song loaded"
    }
  end
  
  local instrument = song.selected_instrument
  if not instrument then
    return {
      samples = {},
      total_samples = 0,
      needs_tuning = 0,
      well_tuned = 0,
      error = "No instrument selected"
    }
  end
  
  local results = {
    samples = {},
    total_samples = 0,
    needs_tuning = 0,
    well_tuned = 0
  }
  
  if #instrument.samples == 0 then
    results.error = "No samples in instrument"
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
        
        print(string.format("-- Batch Analysis: Sample %d (%s): %s, %+.0f cents", 
          i, sample.name, analysis.letter, analysis.cents))
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
  
  -- We always want to CORRECT the pitch, so negate the detected deviation
  local cents_value = -data.cents  -- Negate to correct the detected deviation
  
  -- Convert cents to fine tune steps (Renoise: -128 to 127 = 255 steps for 200 cents)
  local fine_tune_steps = round(cents_value * 1.275)  -- Scale: 255 steps / 200 cents = 1.275
  -- Clamp to valid range (-128 to 127)
  fine_tune_steps = math.max(-128, math.min(127, fine_tune_steps))
  smp.fine_tune = fine_tune_steps
  
  -- Show feedback about what was set
  local status = string.format("Set transpose: %d, fine tune: %d", 
    transpose_value, fine_tune_steps)
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
    width=250,style="strong",font="bold",
    text="Note: \nFinetune: \nMIDI: "
  }
  
  -- Function to perform calculation
  local function perform_calculation()
    -- Check if there's a song and sample first
    local song = renoise.song()
    if not song then
      txt.text = "Error: No song loaded."
      renoise.app():show_status("There is no song loaded, not calculating anything.")
      return
    end
    
    if not song.selected_sample then
      txt.text = "Error: No sample selected.\nPlease select a sample first."
      renoise.app():show_status("There is no sample, not calculating anything.")
      return
    end
    
    local cycles=tonumber(vb.views.cycles.text)
    if not cycles or cycles<=0 then
      txt.text = "Error: Invalid cycle count.\nPlease enter a valid number."
      renoise.app():show_status("Enter valid number of cycles.")
      return
    end
    
    local is_batch = vb.views.batch_checkbox.value
    if is_batch then
      -- Batch process all samples in instrument
      batch_results = batch_analyze_instrument(cycles)
      if batch_results.error then
        txt.text = "Batch Error: " .. batch_results.error
        renoise.app():show_status(batch_results.error)
        return
      end
      if batch_results.total_samples > 0 then
        analysis = nil  -- Clear single analysis
        local summary = string.format("Batch Analysis Complete:\n%d samples analyzed\n%d need tuning (>2 cents)\n%d already well-tuned", 
          batch_results.total_samples, batch_results.needs_tuning, batch_results.well_tuned)
        
        -- Add details about samples that need tuning
        if batch_results.needs_tuning > 0 then
          summary = summary .. "\n\nSamples needing tuning:"
          for _, sample_result in ipairs(batch_results.samples) do
            if sample_result.needs_tuning then
                             local cents_text = string.format("%+.1f", sample_result.analysis.cents)
              summary = summary .. string.format("\n%d. %s: %s (%s cents)", 
                sample_result.index, sample_result.name, sample_result.analysis.letter, cents_text)
            end
          end
        end
        
        txt.text = summary
      else
        txt.text = "No samples found in instrument"
        renoise.app():show_status("No samples found in instrument")
      end
    else
      -- Single sample analysis
      local res,err=analyze_sample(cycles)
      if not res then
        local error_msg = err or "Analysis failed"
        txt.text = "Error: " .. error_msg
        renoise.app():show_status(error_msg)
        return
      end
      analysis=res
      batch_results = {}  -- Clear batch results
      
      -- Display analysis results
      local display_text = "Note: "..res.letter.." ("..string.format("%.2f",res.freq).." Hz)"
      
      -- Display cents with proper +/- notation
      display_text = display_text .. 
        "\nFinetune: " .. string.format("%+.0f", res.cents) .. " cents"
      
      display_text = display_text .. "\nMIDI: "..string.format("%.2f",res.midi)
        
      txt.text = display_text
    end
  end
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog=renoise.app():show_custom_dialog(
    "Paketti Sample Cycle Tuning Calculator",
    vb:column{
      margin=10,
      vb:row{
        vb:text{text="Cycle Count", width=80,style="strong",font="bold"},
        vb:textfield{
          width=40,
          text="1",
          id="cycles"
        },
        vb:button{
          text="Calculate",
          notifier=perform_calculation
        },
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
              
              -- Always apply the tuning - no safeguards for single-cycle work
              set_pitch(analysis)
              --renoise.app().window.active_middle_frame=renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
            end
          end
        },
        vb:button{
          text="Close",
          notifier=function() dialog:close() end
        }
      },
      vb:row{
        vb:checkbox{
          value=false,
          id="batch_checkbox"
        },
        vb:text{text="Batch / All Samples in Instrument",style="strong"}
      },
      vb:row{txt}
    },
    keyhandler
  )
  
  -- Automatically perform 1-cycle calculation when dialog opens
  perform_calculation()
end

-- Quick Selected Sample Tuning (1 cycle, no dialog)
function pakettiQuickSelectedSampleTuning()
  -- Check if there's a song and sample first
  local song = renoise.song()
  if not song then
    renoise.app():show_status("There is no song loaded, not calculating anything.")
    return
  end
  
  if not song.selected_sample then
    renoise.app():show_status("There is no sample, not calculating anything.")
    return
  end
  
  -- Analyze with 1 cycle
  local res, err = analyze_sample(1)
  if not res then
    local error_msg = err or "Analysis failed"
    renoise.app():show_status("Quick tuning failed: " .. error_msg)
    return
  end
  
  -- Apply the tuning immediately
  set_pitch(res)
  
  -- Show feedback about what was applied
  local status = string.format("Quick tuned sample to %s (%+.0f cents) - T:%d, F:%d", 
    res.letter, res.cents, -round(res.midi - 60), 
    round(-res.cents * 1.275))
  renoise.app():show_status(status)
  
  -- Focus sample editor
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

-- Quick Instrument Tuning (all samples, 1 cycle each, no dialog)
function pakettiQuickInstrumentTuning()
  -- Check if there's a song first
  local song = renoise.song()
  if not song then
    renoise.app():show_status("There is no song loaded, not calculating anything.")
    return
  end
  
  -- Run batch analysis with 1 cycle
  local batch_results = batch_analyze_instrument(1)
  if batch_results.error then
    renoise.app():show_status("Quick instrument tuning failed: " .. batch_results.error)
    return
  end
  
  if batch_results.total_samples == 0 then
    renoise.app():show_status("No samples found in instrument")
    return
  end
  
  -- Apply corrections to samples that need tuning
  local original_sample_index = song.selected_sample_index
  local corrected_count = 0
  local skipped_count = 0
  
  for _, sample_result in ipairs(batch_results.samples) do
    if sample_result.needs_tuning then
      -- Select the sample and apply correction
      song.selected_sample_index = sample_result.index
      set_pitch(sample_result.analysis)
      corrected_count = corrected_count + 1
    else
      skipped_count = skipped_count + 1
    end
  end
  
  -- Restore original sample selection
  song.selected_sample_index = original_sample_index
  
  local status = string.format("Quick instrument tuning: %d samples corrected, %d skipped (well-tuned)", 
    corrected_count, skipped_count)
  renoise.app():show_status(status)
  
  -- Focus sample editor
  --enoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
end

renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Sample Cycle Tuning Calculator...",invoke = pakettiSimpleSampleTuningDialog}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Selected Sample 1 Cycle Tuning",invoke = pakettiQuickSelectedSampleTuning}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Selected Instrument 1 Cycle Tuning",invoke = pakettiQuickInstrumentTuning}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Samples:Sample Cycle Tuning Calculator...",invoke = pakettiSimpleSampleTuningDialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Samples:Selected Sample 1 Cycle Tuning",invoke = pakettiQuickSelectedSampleTuning}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Samples:Selected Instrument 1 Cycle Tuning",invoke = pakettiQuickInstrumentTuning}
renoise.tool():add_keybinding{name="Global:Paketti:Sample Cycle Tuning Calculator...",invoke = pakettiSimpleSampleTuningDialog}
renoise.tool():add_keybinding{name="Global:Paketti:Selected Sample 1 Cycle Tuning",invoke = pakettiQuickSelectedSampleTuning}
renoise.tool():add_keybinding{name="Global:Paketti:Selected Instrument 1 Cycle Tuning",invoke = pakettiQuickInstrumentTuning}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Sample Cycle Tuning Calculator...",invoke = pakettiSimpleSampleTuningDialog}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Selected Sample 1 Cycle Tuning",invoke = pakettiQuickSelectedSampleTuning}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Selected Instrument 1 Cycle Tuning",invoke = pakettiQuickInstrumentTuning}
